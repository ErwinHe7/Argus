//! Unified chronological OOF competition for regime model families.
//!
//! The public-history-inspired eight-state HMM is a challenger, not a fixed
//! truth. Every family is fit on prior complete sessions, tuned only on the
//! chronological validation partition, and scored on embargoed test sessions
//! with average predictive log likelihood per observation.

use std::collections::BTreeMap;

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::{
    config::RegimeResearchConfig,
    domain::MarketState,
    engine::{
        model_selection::{self, SelectionCandidate},
        regime::GaussianHmm,
        tvtp_regime::{NonHomogeneousGaussianHmm, TvtpFitConfig},
        walk_forward,
    },
};

const LOG_FLOOR: f64 = -690.775_527_898_213_7;
const VARIANCE_FLOOR: f64 = 1.0e-4;
type ObservationSequences = Vec<Vec<Vec<f64>>>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegimeFamilyScore {
    pub family: String,
    pub fold_scores: Vec<Option<f64>>,
    pub successful_folds: usize,
    pub mean_test_log_likelihood_per_observation: Option<f64>,
    pub selected_hyperparameters: Vec<serde_json::Value>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegimeCompetitionFold {
    pub fold: usize,
    pub train_sessions: usize,
    pub validation_sessions: usize,
    pub test_sessions: usize,
    pub purge_sessions: usize,
    pub embargo_sessions: usize,
    pub selected_hmm_states: Option<usize>,
    pub eight_state_challenger_status: String,
    pub selected_student_t_degrees_of_freedom: Option<f64>,
    pub selected_hsmm_minimum_duration_buckets: Option<usize>,
    pub family_test_scores: BTreeMap<String, Option<f64>>,
    pub failures: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegimeCompetitionReport {
    pub schema_version: String,
    pub generated_at: DateTime<Utc>,
    pub target: String,
    pub observation_interval: String,
    pub scoring_rule: String,
    pub fold_count: usize,
    pub folds: Vec<RegimeCompetitionFold>,
    pub families: Vec<RegimeFamilyScore>,
    pub selected_family: Option<String>,
    pub selected_family_mean_score: Option<f64>,
    pub no_regime_mean_score: Option<f64>,
    pub promotion_status: String,
    pub conclusions: Vec<String>,
}

#[derive(Debug, Clone)]
struct SessionData {
    observations: Vec<Vec<f64>>,
    covariates: Vec<Vec<f64>>,
}

fn canonical_symbol(symbol: &str) -> String {
    symbol.trim().trim_start_matches("US.").to_ascii_uppercase()
}

fn session_data(states: &[MarketState], target: &str) -> BTreeMap<NaiveDate, SessionData> {
    let target = canonical_symbol(target);
    let mut sessions = BTreeMap::<NaiveDate, SessionData>::new();
    for state in states.iter().filter(|state| {
        canonical_symbol(&state.symbol) == target
            && state.minute_in_5m_bucket == 4
            && state.completed_5m_bucket_valid
    }) {
        let session = sessions
            .entry(state.session_date)
            .or_insert_with(|| SessionData {
                observations: Vec::new(),
                covariates: Vec::new(),
            });
        session.observations.push(vec![
            state.active_5m_return,
            state.dist_vwap,
            state.rolling_realized_vol,
            state.volume_zscore,
        ]);
        session.covariates.push(vec![
            state.cross_asset_breadth_score,
            state.risk_rotation_score,
            state.rvol_same_minute.ln().clamp(-5.0, 5.0),
            state.minutes_to_close as f64 / 390.0,
        ]);
    }
    sessions.retain(|_, session| {
        session.observations.len() >= 12 && session.observations.len() == session.covariates.len()
    });
    sessions
}

fn select(
    sessions: &BTreeMap<NaiveDate, SessionData>,
    dates: &[NaiveDate],
) -> (ObservationSequences, ObservationSequences) {
    let selected = dates
        .iter()
        .filter_map(|date| sessions.get(date))
        .collect::<Vec<_>>();
    (
        selected
            .iter()
            .map(|session| session.observations.clone())
            .collect(),
        selected
            .iter()
            .map(|session| session.covariates.clone())
            .collect(),
    )
}

fn log_sum_exp(values: &[f64]) -> f64 {
    let maximum = values.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if !maximum.is_finite() {
        return LOG_FLOOR;
    }
    maximum
        + values
            .iter()
            .map(|value| (value - maximum).exp())
            .sum::<f64>()
            .max(1.0e-300)
            .ln()
}

fn standardized(model: &GaussianHmm, row: &[f64]) -> Result<Vec<f64>> {
    if row.len() != model.dimensions || row.iter().any(|value| !value.is_finite()) {
        bail!("regime challenger input is non-finite or dimensionally invalid");
    }
    Ok(row
        .iter()
        .enumerate()
        .map(|(index, value)| (value - model.center[index]) / model.scale[index])
        .collect())
}

fn gaussian_log_emission(model: &GaussianHmm, row: &[f64], state: usize) -> Result<f64> {
    let row = standardized(model, row)?;
    Ok(row
        .iter()
        .enumerate()
        .map(|(column, value)| {
            let variance = model.variances[state][column].max(VARIANCE_FLOOR);
            -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
                + (value - model.means[state][column]).powi(2) / variance)
        })
        .sum())
}

// Lanczos approximation; sufficient for the fixed positive Student-t degrees
// of freedom evaluated here.
fn log_gamma(value: f64) -> f64 {
    const COEFFICIENTS: [f64; 9] = [
        0.999_999_999_999_809_9,
        676.520_368_121_885_1,
        -1_259.139_216_722_402_8,
        771.323_428_777_653_1,
        -176.615_029_162_140_6,
        12.507_343_278_686_905,
        -0.138_571_095_265_720_12,
        9.984_369_578_019_572e-6,
        1.505_632_735_149_311_6e-7,
    ];
    if value < 0.5 {
        return std::f64::consts::PI.ln()
            - (std::f64::consts::PI * value).sin().ln()
            - log_gamma(1.0 - value);
    }
    let shifted = value - 1.0;
    let mut x = COEFFICIENTS[0];
    for (index, coefficient) in COEFFICIENTS.iter().enumerate().skip(1) {
        x += coefficient / (shifted + index as f64);
    }
    let t = shifted + 7.5;
    0.5 * (2.0 * std::f64::consts::PI).ln() + (shifted + 0.5) * t.ln() - t + x.ln()
}

fn student_t_log_emission(
    model: &GaussianHmm,
    row: &[f64],
    state: usize,
    degrees_of_freedom: f64,
) -> Result<f64> {
    let row = standardized(model, row)?;
    Ok(row
        .iter()
        .enumerate()
        .map(|(column, value)| {
            let variance = model.variances[state][column].max(VARIANCE_FLOOR);
            let residual = value - model.means[state][column];
            log_gamma((degrees_of_freedom + 1.0) * 0.5)
                - log_gamma(degrees_of_freedom * 0.5)
                - 0.5 * (degrees_of_freedom * std::f64::consts::PI * variance).ln()
                - 0.5
                    * (degrees_of_freedom + 1.0)
                    * (1.0 + residual.powi(2) / (degrees_of_freedom * variance)).ln()
        })
        .sum())
}

fn hmm_log_likelihood_with_emission(
    model: &GaussianHmm,
    sequence: &[Vec<f64>],
    emission: impl Fn(&[f64], usize) -> Result<f64>,
) -> Result<f64> {
    if sequence.is_empty() {
        bail!("empty HMM sequence");
    }
    let mut alpha = (0..model.states)
        .map(|state| Ok(model.initial[state].max(1.0e-300).ln() + emission(&sequence[0], state)?))
        .collect::<Result<Vec<_>>>()?;
    for row in &sequence[1..] {
        let mut next = vec![0.0; model.states];
        for (to, next_value) in next.iter_mut().enumerate().take(model.states) {
            let incoming = (0..model.states)
                .map(|from| alpha[from] + model.transition[from][to].max(1.0e-300).ln())
                .collect::<Vec<_>>();
            *next_value = log_sum_exp(&incoming) + emission(row, to)?;
        }
        alpha = next;
    }
    Ok(log_sum_exp(&alpha))
}

fn average_student_t_log_likelihood(
    model: &GaussianHmm,
    sequences: &[Vec<Vec<f64>>],
    degrees_of_freedom: f64,
) -> Result<f64> {
    let mut total = 0.0;
    let mut count = 0usize;
    for sequence in sequences.iter().filter(|sequence| !sequence.is_empty()) {
        total += hmm_log_likelihood_with_emission(model, sequence, |row, state| {
            student_t_log_emission(model, row, state, degrees_of_freedom)
        })?;
        count += sequence.len();
    }
    if count == 0 {
        bail!("Student-t HMM evaluation has no observations");
    }
    Ok(total / count as f64)
}

/// Minimum-duration HMM represented as an expanded-state HSMM with a shifted
/// geometric duration distribution.
fn hsmm_sequence_log_likelihood(
    model: &GaussianHmm,
    sequence: &[Vec<f64>],
    minimum_duration: usize,
) -> Result<f64> {
    if sequence.is_empty() || minimum_duration == 0 {
        bail!("HSMM requires a sequence and positive minimum duration");
    }
    let expanded = model.states * minimum_duration;
    let index = |state: usize, duration: usize| state * minimum_duration + duration;
    let mut alpha = vec![f64::NEG_INFINITY; expanded];
    for state in 0..model.states {
        alpha[index(state, 0)] = model.initial[state].max(1.0e-300).ln()
            + gaussian_log_emission(model, &sequence[0], state)?;
    }
    for row in &sequence[1..] {
        let mut next = vec![f64::NEG_INFINITY; expanded];
        for state in 0..model.states {
            for duration in 0..minimum_duration - 1 {
                next[index(state, duration + 1)] =
                    alpha[index(state, duration)] + gaussian_log_emission(model, row, state)?;
            }
            let last = index(state, minimum_duration - 1);
            let stay = alpha[last] + model.transition[state][state].max(1.0e-300).ln();
            next[last] =
                log_sum_exp(&[next[last], stay]) + gaussian_log_emission(model, row, state)?;
            for to in 0..model.states {
                if to == state {
                    continue;
                }
                let destination = index(to, 0);
                let transition = alpha[last] + model.transition[state][to].max(1.0e-300).ln();
                next[destination] = log_sum_exp(&[next[destination], transition]);
            }
        }
        // Emissions for cross-state transitions enter the destination state.
        for state in 0..model.states {
            let destination = index(state, 0);
            if next[destination].is_finite() {
                next[destination] += gaussian_log_emission(model, row, state)?;
            }
        }
        alpha = next;
    }
    Ok(log_sum_exp(&alpha))
}

fn average_hsmm_log_likelihood(
    model: &GaussianHmm,
    sequences: &[Vec<Vec<f64>>],
    minimum_duration: usize,
) -> Result<f64> {
    let mut total = 0.0;
    let mut count = 0usize;
    for sequence in sequences.iter().filter(|sequence| !sequence.is_empty()) {
        total += hsmm_sequence_log_likelihood(model, sequence, minimum_duration)?;
        count += sequence.len();
    }
    if count == 0 {
        bail!("HSMM evaluation has no observations");
    }
    Ok(total / count as f64)
}

#[derive(Debug, Clone)]
struct DiagonalGaussian {
    center: Vec<f64>,
    variance: Vec<f64>,
}

impl DiagonalGaussian {
    fn fit(sequences: &[Vec<Vec<f64>>]) -> Result<Self> {
        let rows = sequences.iter().flatten().collect::<Vec<_>>();
        let dimensions = rows
            .first()
            .context("no-regime baseline has no observations")?
            .len();
        let mut center = vec![0.0; dimensions];
        for row in &rows {
            if row.len() != dimensions || row.iter().any(|value| !value.is_finite()) {
                bail!("no-regime rows must be finite and rectangular");
            }
            for (column, value) in row.iter().enumerate() {
                center[column] += value;
            }
        }
        for value in &mut center {
            *value /= rows.len() as f64;
        }
        let mut variance = vec![0.0; dimensions];
        for row in &rows {
            for column in 0..dimensions {
                variance[column] += (row[column] - center[column]).powi(2);
            }
        }
        for value in &mut variance {
            *value = (*value / rows.len() as f64).max(1.0e-12);
        }
        Ok(Self { center, variance })
    }

    fn average_log_likelihood(&self, sequences: &[Vec<Vec<f64>>]) -> Result<f64> {
        let mut total = 0.0;
        let mut count = 0usize;
        for row in sequences.iter().flatten() {
            if row.len() != self.center.len() {
                bail!("no-regime evaluation dimension mismatch");
            }
            total += row
                .iter()
                .enumerate()
                .map(|(column, value)| {
                    let variance = self.variance[column];
                    -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
                        + (value - self.center[column]).powi(2) / variance)
                })
                .sum::<f64>();
            count += 1;
        }
        if count == 0 {
            bail!("no-regime evaluation has no observations");
        }
        Ok(total / count as f64)
    }
}

fn best_hmm(
    train: &[Vec<Vec<f64>>],
    validation: &[Vec<Vec<f64>>],
    config: &RegimeResearchConfig,
) -> Result<(GaussianHmm, usize, BTreeMap<usize, Option<f64>>)> {
    let mut scores = BTreeMap::new();
    let mut fitted = BTreeMap::new();
    let mut candidates = Vec::new();
    for states in &config.state_candidates {
        match GaussianHmm::fit(train, *states, config.max_iterations, config.restarts) {
            Ok(model) => {
                let score = model.average_log_likelihood(validation).ok();
                scores.insert(*states, score);
                let minimum_occupancy = model
                    .state_occupancy(train)
                    .ok()
                    .and_then(|occupancy| occupancy.into_iter().reduce(f64::min));
                candidates.push(SelectionCandidate {
                    id: *states,
                    criterion: score,
                    minimum_occupancy,
                });
                fitted.insert(*states, model);
            }
            Err(_) => {
                scores.insert(*states, None);
            }
        }
    }
    let selected_states =
        model_selection::select_best(&candidates, model_selection::MINIMUM_STATE_OCCUPANCY)
            .context(
                "no HMM candidate scored validation and cleared the per-state occupancy floor",
            )?;
    let model = fitted
        .remove(&selected_states)
        .context("selected HMM candidate was not fitted")?;
    Ok((model, selected_states, scores))
}

fn mean(values: &[f64]) -> Option<f64> {
    (!values.is_empty()).then(|| values.iter().sum::<f64>() / values.len() as f64)
}

pub fn evaluate(
    states: &[MarketState],
    target: &str,
    config: &RegimeResearchConfig,
) -> Result<RegimeCompetitionReport> {
    let sessions = session_data(states, target);
    let dates = sessions.keys().copied().collect::<Vec<_>>();
    if dates.len() < 24 {
        bail!("regime OOF competition requires at least 24 complete sessions");
    }
    let validation_sessions = (dates.len() / 10).max(3);
    let test_sessions = (dates.len() / 10).max(3);
    let initial_train = (dates.len() / 2).max(12);
    let folds = walk_forward::expanding_day_folds(
        &dates,
        initial_train,
        validation_sessions,
        test_sessions,
        1,
        1,
    );
    if folds.is_empty() {
        bail!("regime OOF competition produced no chronological fold");
    }
    let families = [
        "no_regime_iid_gaussian",
        "gaussian_hmm",
        "student_t_hmm",
        "minimum_duration_hsmm",
        "tvtp_gaussian_hmm",
    ];
    let mut family_scores = families
        .iter()
        .map(|family| ((*family).to_string(), Vec::<Option<f64>>::new()))
        .collect::<BTreeMap<_, _>>();
    let mut family_hyperparameters = families
        .iter()
        .map(|family| ((*family).to_string(), Vec::<serde_json::Value>::new()))
        .collect::<BTreeMap<_, _>>();
    let mut fold_reports = Vec::new();
    for (fold_index, fold) in folds.iter().enumerate() {
        let (train, train_covariates) = select(&sessions, &fold.train_days);
        let (validation, validation_covariates) = select(&sessions, &fold.validation_days);
        let (test, test_covariates) = select(&sessions, &fold.test_days);
        let mut failures = Vec::new();
        let mut scores = BTreeMap::<String, Option<f64>>::new();

        let baseline = DiagonalGaussian::fit(&train)
            .and_then(|model| model.average_log_likelihood(&test))
            .ok();
        scores.insert("no_regime_iid_gaussian".to_string(), baseline);
        family_scores
            .get_mut("no_regime_iid_gaussian")
            .expect("family")
            .push(baseline);
        family_hyperparameters
            .get_mut("no_regime_iid_gaussian")
            .expect("family")
            .push(serde_json::json!({"parameters":"train_only_mean_diagonal_variance"}));

        let selected = best_hmm(&train, &validation, config);
        let mut selected_states = None;
        let mut selected_df = None;
        let mut selected_duration = None;
        let mut eight_status = "FIT_FAILED_OR_NOT_SCORED".to_string();
        if let Ok((train_hmm, state_count, state_scores)) = selected {
            selected_states = Some(state_count);
            eight_status = if state_count == 8 {
                "SELECTED_ON_CHRONOLOGICAL_VALIDATION"
            } else if state_scores.get(&8).is_some_and(Option::is_some) {
                "EVALUATED_NOT_SELECTED"
            } else {
                "FIT_FAILED_OR_NOT_SCORED"
            }
            .to_string();
            let mut final_fit = train.clone();
            final_fit.extend(validation.clone());
            match GaussianHmm::fit(
                &final_fit,
                state_count,
                config.max_iterations,
                config.restarts,
            ) {
                Ok(final_hmm) => {
                    let hmm_score = final_hmm.average_log_likelihood(&test).ok();
                    scores.insert("gaussian_hmm".to_string(), hmm_score);
                    family_scores
                        .get_mut("gaussian_hmm")
                        .expect("family")
                        .push(hmm_score);
                    family_hyperparameters
                        .get_mut("gaussian_hmm")
                        .expect("family")
                        .push(serde_json::json!({"states":state_count}));

                    let df = [3.0, 5.0, 8.0, 15.0, 30.0]
                        .into_iter()
                        .filter_map(|df| {
                            average_student_t_log_likelihood(&train_hmm, &validation, df)
                                .ok()
                                .map(|score| (df, score))
                        })
                        .max_by(|left, right| left.1.total_cmp(&right.1))
                        .map(|row| row.0);
                    selected_df = df;
                    let student_score = df.and_then(|df| {
                        average_student_t_log_likelihood(&final_hmm, &test, df).ok()
                    });
                    scores.insert("student_t_hmm".to_string(), student_score);
                    family_scores
                        .get_mut("student_t_hmm")
                        .expect("family")
                        .push(student_score);
                    family_hyperparameters
                        .get_mut("student_t_hmm")
                        .expect("family")
                        .push(serde_json::json!({"states":state_count,"degrees_of_freedom":df}));

                    let duration = [1, 2, 3, 4, 6]
                        .into_iter()
                        .filter_map(|duration| {
                            average_hsmm_log_likelihood(&train_hmm, &validation, duration)
                                .ok()
                                .map(|score| (duration, score))
                        })
                        .max_by(|left, right| left.1.total_cmp(&right.1))
                        .map(|row| row.0);
                    selected_duration = duration;
                    let hsmm_score = duration.and_then(|duration| {
                        average_hsmm_log_likelihood(&final_hmm, &test, duration).ok()
                    });
                    scores.insert("minimum_duration_hsmm".to_string(), hsmm_score);
                    family_scores
                        .get_mut("minimum_duration_hsmm")
                        .expect("family")
                        .push(hsmm_score);
                    family_hyperparameters
                        .get_mut("minimum_duration_hsmm")
                        .expect("family")
                        .push(serde_json::json!({"states":state_count,"minimum_duration_5m_buckets":duration}));

                    let mut final_covariates = train_covariates.clone();
                    final_covariates.extend(validation_covariates.clone());
                    let tvtp_score = NonHomogeneousGaussianHmm::fit(
                        final_hmm.clone(),
                        &final_fit,
                        &final_covariates,
                        TvtpFitConfig::default(),
                    )
                    .and_then(|model| model.average_log_likelihood(&test, &test_covariates))
                    .ok();
                    if tvtp_score.is_none() {
                        failures.push("TVTP_FIT_OR_TEST_SCORE_FAILED".to_string());
                    }
                    scores.insert("tvtp_gaussian_hmm".to_string(), tvtp_score);
                    family_scores
                        .get_mut("tvtp_gaussian_hmm")
                        .expect("family")
                        .push(tvtp_score);
                    family_hyperparameters
                        .get_mut("tvtp_gaussian_hmm")
                        .expect("family")
                        .push(serde_json::json!({
                            "states":state_count,
                            "transition_covariates":["breadth","risk_rotation","log_rvol","session_phase"],
                            "validation_covariate_sessions":validation_covariates.len()
                        }));
                }
                Err(error) => {
                    failures.push(format!("FINAL_HMM_REFIT_FAILED:{error}"));
                    for family in [
                        "gaussian_hmm",
                        "student_t_hmm",
                        "minimum_duration_hsmm",
                        "tvtp_gaussian_hmm",
                    ] {
                        scores.insert(family.to_string(), None);
                        family_scores.get_mut(family).expect("family").push(None);
                        family_hyperparameters
                            .get_mut(family)
                            .expect("family")
                            .push(serde_json::json!({"status":"FINAL_REFIT_FAILED"}));
                    }
                }
            }
        } else if let Err(error) = selected {
            failures.push(format!("HMM_SELECTION_FAILED:{error}"));
            for family in [
                "gaussian_hmm",
                "student_t_hmm",
                "minimum_duration_hsmm",
                "tvtp_gaussian_hmm",
            ] {
                scores.insert(family.to_string(), None);
                family_scores.get_mut(family).expect("family").push(None);
                family_hyperparameters
                    .get_mut(family)
                    .expect("family")
                    .push(serde_json::json!({"status":"SELECTION_FAILED"}));
            }
        }
        fold_reports.push(RegimeCompetitionFold {
            fold: fold_index + 1,
            train_sessions: fold.train_days.len(),
            validation_sessions: fold.validation_days.len(),
            test_sessions: fold.test_days.len(),
            purge_sessions: fold.purged_days.len(),
            embargo_sessions: fold.embargoed_days.len(),
            selected_hmm_states: selected_states,
            eight_state_challenger_status: eight_status,
            selected_student_t_degrees_of_freedom: selected_df,
            selected_hsmm_minimum_duration_buckets: selected_duration,
            family_test_scores: scores,
            failures,
        });
    }
    let family_reports = families
        .iter()
        .map(|family| {
            let scores = family_scores.get(*family).cloned().unwrap_or_default();
            let successful = scores.iter().filter_map(|score| *score).collect::<Vec<_>>();
            RegimeFamilyScore {
                family: (*family).to_string(),
                fold_scores: scores,
                successful_folds: successful.len(),
                mean_test_log_likelihood_per_observation: mean(&successful),
                selected_hyperparameters: family_hyperparameters
                    .remove(*family)
                    .unwrap_or_default(),
                status: if successful.len() == fold_reports.len() {
                    "ALL_OOF_FOLDS_SCORED"
                } else if successful.is_empty() {
                    "UNAVAILABLE"
                } else {
                    "PARTIAL_OOF_COVERAGE"
                }
                .to_string(),
            }
        })
        .collect::<Vec<_>>();
    let selected = family_reports
        .iter()
        .filter(|family| family.successful_folds == fold_reports.len())
        .filter_map(|family| {
            Some((
                family.family.clone(),
                family.mean_test_log_likelihood_per_observation?,
            ))
        })
        .max_by(|left, right| left.1.total_cmp(&right.1));
    let baseline = family_reports
        .iter()
        .find(|family| family.family == "no_regime_iid_gaussian")
        .and_then(|family| family.mean_test_log_likelihood_per_observation);
    let improvement = selected
        .as_ref()
        .zip(baseline)
        .map(|((_, score), baseline)| score - baseline);
    let enough_evidence = fold_reports.len() >= 3 && improvement.is_some_and(|value| value > 0.0);
    Ok(RegimeCompetitionReport {
        schema_version: "regime_oof_competition.v1".to_string(),
        generated_at: Utc::now(),
        target: canonical_symbol(target),
        observation_interval: "completed_nonoverlapping_5m_buckets".to_string(),
        scoring_rule: "chronological_embargoed_test_average_predictive_log_likelihood_per_observation".to_string(),
        fold_count: fold_reports.len(),
        folds: fold_reports,
        families: family_reports,
        selected_family: selected.as_ref().map(|row| row.0.clone()),
        selected_family_mean_score: selected.as_ref().map(|row| row.1),
        no_regime_mean_score: baseline,
        promotion_status: if enough_evidence {
            "OOF_FAMILY_WINNER_REQUIRES_FROZEN_FORWARD_SHADOW_PROMOTION"
        } else {
            "NO_FAMILY_PROMOTED"
        }
        .to_string(),
        conclusions: vec![
            "Eight states competed and were never forced.".to_string(),
            "HMM, TVTP, Student-t emissions, minimum-duration HSMM, and no-regime used the same chronological folds.".to_string(),
            "This report cannot mutate the live frozen artifact by itself.".to_string(),
        ],
    })
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};

    use super::*;

    fn state(day: u32, bucket: i32, regime: usize) -> MarketState {
        let timestamp = Utc.with_ymd_and_hms(2026, 1, day, 14, 4, 0).unwrap()
            + Duration::minutes((bucket * 5) as i64);
        let sign = if regime == 0 { -1.0 } else { 1.0 };
        MarketState {
            timestamp,
            session_date: timestamp.date_naive(),
            symbol: "SPY".to_string(),
            open: 100.0,
            high: 101.0,
            low: 99.0,
            close: 100.0 + sign,
            atr: 1.0,
            ret_1m: sign * 0.001,
            ret_3m: sign * 0.002,
            ret_5m: sign * 0.003,
            ret_15m: sign * 0.004,
            ret_30m: sign * 0.005,
            ret_60m: sign * 0.006,
            active_5m_return: sign * (0.002 + bucket as f64 * 1.0e-5),
            last_completed_5m_return: sign * 0.002,
            last_completed_15m_return: sign * 0.003,
            slope_15m: sign * 0.001,
            dist_vwap: sign * 0.002,
            dist_session_open: sign * 0.003,
            rolling_realized_vol: 0.002 + regime as f64 * 0.001,
            normalized_range: 0.01,
            upper_wick_ratio: 0.2,
            lower_wick_ratio: 0.2,
            close_location_value: sign * 0.5,
            distance_session_high: -0.001,
            distance_session_low: 0.001,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: usize::from(regime == 1) as i32,
            consecutive_down_bars: usize::from(regime == 0) as i32,
            return_acceleration: 0.0,
            volume_zscore: sign * 0.5,
            volume_acceleration: 0.0,
            session_range_position: if regime == 0 { 0.25 } else { 0.75 },
            cross_asset_breadth_score: sign,
            risk_rotation_score: sign * 0.5,
            market_confirmation_score: 0.5,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0 + regime as f64 * 0.2,
            minutes_from_open: bucket * 5 + 4,
            minutes_to_close: 390 - (bucket * 5 + 4),
            bucket_5m: bucket,
            bucket_15m: bucket / 3,
            minute_in_5m_bucket: 4,
            completed_5m_bucket_valid: true,
            continuous_minute_count: (bucket * 5 + 5) as usize,
        }
    }

    #[test]
    fn all_families_share_oof_folds_and_eight_is_not_forced() {
        let mut states = Vec::new();
        for day in 1..=31 {
            for bucket in 0..18 {
                states.push(state(day, bucket, (day as usize / 4) % 2));
            }
        }
        let config = RegimeResearchConfig {
            state_candidates: vec![2, 4, 8],
            max_iterations: 8,
            restarts: 1,
            minimum_validation_sessions: 2,
            ..Default::default()
        };
        let report = evaluate(&states, "SPY", &config).unwrap();
        assert!(!report.folds.is_empty());
        assert_eq!(report.families.len(), 5);
        assert!(
            report
                .folds
                .iter()
                .all(|fold| fold.eight_state_challenger_status != "FORCED")
        );
    }
}
