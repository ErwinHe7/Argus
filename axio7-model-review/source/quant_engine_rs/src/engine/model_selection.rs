//! Shared, occupancy-gated candidate selection for componentwise Gaussian
//! model-order sweeps (HMM state count, GMM component count, ...).
//!
//! This module exists because a bare argmax over validation likelihood (or
//! its train-BIC fallback) is a documented, repeat failure mode in this
//! codebase: validation likelihood for a componentwise Gaussian mixture is
//! structurally close to monotone non-decreasing in complexity on real
//! intraday data (more states/components can only ever subdivide the
//! observation space further), so without a real penalty or a data-support
//! floor, "add one more" is nearly always a good bet. Every one of the four
//! HMM state-count sweeps in this crate independently reimplemented the same
//! bare-argmax comparator, and all nine shipped `universe/*.frozen.json`
//! candidates saturated at the top of whatever grid they were given
//! (`BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K`).
//!
//! `select_best` fixes this in two ways:
//! 1. it is the *one* comparator every sweep calls, so a future change to the
//!    tie-break or selection rule only has to happen once;
//! 2. it requires callers to report each candidate's minimum per-state/
//!    component occupancy and disqualifies (not merely down-weights) any
//!    candidate where a state/component has too little expected data to
//!    support its fitted parameters -- see `MINIMUM_STATE_OCCUPANCY`.

/// One candidate's summary for a model-order sweep.
pub struct SelectionCandidate {
    /// The model order this candidate represents (state count, component
    /// count, ...). Ties break toward the smaller id.
    pub id: usize,
    /// Validation log-likelihood, or the train-BIC fallback (already sign-
    /// flipped by the caller so that higher is always better), or `None` if
    /// fitting/scoring failed. Non-finite values are treated as `None`.
    pub criterion: Option<f64>,
    /// The smallest per-state/component expected occupancy (sum of
    /// posterior responsibility across the fit data) among this candidate's
    /// components. `None` if occupancy could not be computed, which
    /// disqualifies the candidate exactly like a missing criterion does.
    pub minimum_occupancy: Option<f64>,
}

/// Two ties within this tolerance of each other are treated as equal and
/// broken toward the smaller candidate id. Real gaps between adjacent state
/// counts on intraday data run 0.2-0.4 nats/observation -- twelve orders of
/// magnitude above this tolerance -- so it only ever fires for genuine
/// numerical ties, never as a de facto complexity penalty.
pub const SELECTION_TIE_TOLERANCE: f64 = 1.0e-12;

/// Minimum expected observations a state/component must have accumulated
/// (sum of training-only posterior responsibility) to be eligible at all.
/// Matches the same per-state minimum-observations floor `GaussianHmm::fit`
/// already enforces *a priori* (`total_observations >= states * 8`), checked
/// here *post hoc* against what EM actually assigned rather than assumed
/// from a uniform a priori split. A state can satisfy the a priori floor on
/// average and still end up under this floor individually if EM collapses
/// most of the responsibility onto other states.
pub const MINIMUM_STATE_OCCUPANCY: f64 = 8.0;

/// Selects the winning candidate id, or `None` if no candidate both scored
/// and cleared the occupancy floor.
pub fn select_best(candidates: &[SelectionCandidate], minimum_occupancy: f64) -> Option<usize> {
    let mut selected: Option<(usize, f64)> = None;
    for candidate in candidates {
        let Some(criterion) = candidate.criterion.filter(|value| value.is_finite()) else {
            continue;
        };
        let occupancy_ok = candidate
            .minimum_occupancy
            .is_some_and(|value| value >= minimum_occupancy);
        if !occupancy_ok {
            continue;
        }
        let replace = selected.as_ref().is_none_or(|(current_id, current_score)| {
            criterion > *current_score + SELECTION_TIE_TOLERANCE
                || ((criterion - *current_score).abs() <= SELECTION_TIE_TOLERANCE
                    && candidate.id < *current_id)
        });
        if replace {
            selected = Some((candidate.id, criterion));
        }
    }
    selected.map(|(id, _)| id)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn candidate(id: usize, criterion: f64, minimum_occupancy: f64) -> SelectionCandidate {
        SelectionCandidate {
            id,
            criterion: Some(criterion),
            minimum_occupancy: Some(minimum_occupancy),
        }
    }

    #[test]
    fn higher_criterion_wins_when_occupancy_clears_the_floor() {
        let candidates = vec![candidate(2, -1.0, 50.0), candidate(3, -0.5, 50.0)];
        assert_eq!(select_best(&candidates, 8.0), Some(3));
    }

    #[test]
    fn a_higher_scoring_candidate_is_disqualified_by_low_occupancy() {
        // Candidate 5 scores strictly better than candidate 3, but one of its
        // states only ever captured ~2 expected observations -- far short of
        // the floor. This is exactly the "phantom state" failure mode: it
        // must lose regardless of how good its aggregate score looks.
        let candidates = vec![candidate(3, -1.0, 40.0), candidate(5, -0.2, 2.0)];
        assert_eq!(select_best(&candidates, 8.0), Some(3));
    }

    #[test]
    fn all_candidates_below_the_occupancy_floor_selects_nothing() {
        let candidates = vec![candidate(2, -1.0, 1.0), candidate(3, -0.5, 3.0)];
        assert_eq!(select_best(&candidates, 8.0), None);
    }

    #[test]
    fn missing_or_non_finite_criterion_is_skipped() {
        let candidates = vec![
            SelectionCandidate {
                id: 2,
                criterion: None,
                minimum_occupancy: Some(50.0),
            },
            SelectionCandidate {
                id: 3,
                criterion: Some(f64::NAN),
                minimum_occupancy: Some(50.0),
            },
            candidate(4, -1.0, 50.0),
        ];
        assert_eq!(select_best(&candidates, 8.0), Some(4));
    }

    #[test]
    fn near_exact_ties_break_toward_fewer_states() {
        let candidates = vec![candidate(6, -1.0, 50.0), candidate(4, -1.0 + 1.0e-13, 50.0)];
        assert_eq!(select_best(&candidates, 8.0), Some(4));
    }

    #[test]
    fn a_real_gap_below_tolerance_is_never_reached_on_real_data_but_is_not_a_tie() {
        // 1e-6 is already far above SELECTION_TIE_TOLERANCE (1e-12): this is
        // a real difference, not a tie, so the higher scorer wins outright.
        let candidates = vec![candidate(4, -1.0, 50.0), candidate(6, -1.0 + 1.0e-6, 50.0)];
        assert_eq!(select_best(&candidates, 8.0), Some(6));
    }
}
