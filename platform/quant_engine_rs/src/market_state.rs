use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::engine::regime::GaussianHmm;

pub const STATE_FEATURE_SCHEMA: [&str; 4] = [
    "standardized_return",
    "standardized_vwap_distance",
    "standardized_volatility",
    "standardized_activity",
];

/// Stable, human-readable state names. The raw HMM state id is always kept
/// alongside this label because labels are interpretations of train-only
/// emission statistics, not ground truth.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum StandardStateName {
    #[serde(alias = "OPENING_PRICE_DISCOVERY")]
    UnclassifiedPriceFlowState,
    LowVolTrendUp,
    LowVolTrendDown,
    HighVolSellOff,
    HighVolRecovery,
    MeanReversion,
    #[serde(alias = "LIQUIDITY_STRESS")]
    HighActivityHighVolatility,
    RangeCompression,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StateProfile {
    pub raw_state_id: usize,
    pub name: StandardStateName,
    pub standardized_return_mean: f64,
    pub standardized_vwap_distance_mean: f64,
    pub standardized_volatility_mean: f64,
    pub standardized_activity_mean: f64,
    pub self_transition_probability: f64,
    /// Geometric-HMM spell length including the current observation. `None`
    /// denotes an absorbing state rather than a fabricated large finite value.
    pub expected_duration_observations: Option<f64>,
    /// Expected additional self-transitions before exit under the memoryless
    /// geometric duration implied by a homogeneous HMM.
    pub expected_future_self_transitions: Option<f64>,
    pub duration_model: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RawStateCertainty {
    pub top_probability: f64,
    pub top_two_probability_margin: f64,
    pub normalized_entropy: f64,
    pub calibration_status: String,
    /// Compatibility summary: `true` records any direct decision impact;
    /// explicit fields distinguish a hard veto from continuous sizing.
    pub direct_allocation_impact: bool,
    pub continuous_sizing_impact: bool,
    pub hard_no_trade_veto_impact: bool,
    pub semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StateHorizonForecast {
    pub transitions_ahead: usize,
    pub status: String,
    pub endpoint_state_probabilities: Option<Vec<f64>>,
    pub dominant_raw_state_id: Option<usize>,
    pub dominant_probability: Option<f64>,
    pub endpoint_entropy: Option<f64>,
    pub normalized_endpoint_entropy: Option<f64>,
    /// Probability that the latent state never changes during the requested
    /// transitions, posterior-weighted over the uncertain current state.
    pub posterior_weighted_no_state_change_probability: Option<f64>,
    pub probability_semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StateTransitionAuditCell {
    pub from_raw_state_id: usize,
    pub to_raw_state_id: usize,
    pub transition_probability: f64,
    /// Fractional Baum-Welch expected count from train-only smoothed xi. This
    /// is a fit diagnostic, never a live state feature or an observed tally.
    pub train_expected_transition_count: f64,
    pub train_expected_origin_count: f64,
    pub count_semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketStateEngineOutput {
    pub filtered_state_probabilities: Vec<f64>,
    pub next_state_probabilities: Vec<f64>,
    pub regime_entropy: f64,
    pub normalized_regime_entropy: f64,
    pub expected_regime_duration_observations: Option<f64>,
    pub expected_future_self_transitions: Option<f64>,
    pub duration_model: String,
    pub duration_semantics: String,
    /// The reported geometric expectation is not truncated or censored by the
    /// number of buckets remaining in the current session.
    pub untruncated_geometric_diagnostic: bool,
    /// Consumers must not project the untruncated diagnostic across the close.
    pub must_not_extrapolate_past_session_close: bool,
    /// Deprecated compatibility alias for transition_row_normalized_entropy.
    pub state_transition_instability: f64,
    pub transition_row_normalized_entropy: f64,
    pub probability_of_regime_change: f64,
    pub raw_state_certainty: RawStateCertainty,
    pub dominant_raw_state_id: usize,
    pub dominant_state_name: StandardStateName,
    pub profiles: Vec<StateProfile>,
    pub state_feature_schema: Vec<String>,
    pub state_feature_schema_sha256: String,
    pub model_artifact_sha256: String,
    pub completed_observation_count: usize,
    pub model_validation_status: String,
    pub state_mapping_semantics: String,
    pub probability_semantics: String,
    /// Compatibility summary: `true` records the entropy hard veto; the
    /// explicit continuous-sizing field remains false.
    pub direct_allocation_impact: bool,
    pub continuous_sizing_impact: bool,
    pub hard_no_trade_veto_impact: bool,
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn validate_probability_vector(values: &[f64], expected: usize, label: &str) -> Result<()> {
    ensure!(
        values.len() == expected,
        "{label} has {} entries; expected {expected}",
        values.len()
    );
    ensure!(
        values
            .iter()
            .all(|value| value.is_finite() && *value >= 0.0),
        "{label} contains a non-finite or negative probability"
    );
    let sum = values.iter().sum::<f64>();
    ensure!(
        (sum - 1.0).abs() <= 1.0e-8,
        "{label} sums to {sum}; expected 1"
    );
    Ok(())
}

/// Validates the persisted HMM artifact before any state label or probability
/// is exposed. Invalid artifacts fail closed instead of receiving zero-filled
/// dimensions or silently normalized transition rows.
pub fn validate_model_artifact(model: &GaussianHmm) -> Result<()> {
    ensure!(
        model.states >= 2,
        "market-state HMM requires at least two states"
    );
    ensure!(
        model.dimensions == STATE_FEATURE_SCHEMA.len(),
        "market-state HMM has {} dimensions; the registered schema requires {}",
        model.dimensions,
        STATE_FEATURE_SCHEMA.len()
    );
    validate_probability_vector(&model.initial, model.states, "initial distribution")?;
    ensure!(
        model.transition.len() == model.states,
        "transition matrix row count does not match states"
    );
    for (state, row) in model.transition.iter().enumerate() {
        validate_probability_vector(row, model.states, &format!("transition row {state}"))?;
    }
    ensure!(
        model.means.len() == model.states,
        "emission mean row count mismatch"
    );
    ensure!(
        model.variances.len() == model.states,
        "emission variance row count mismatch"
    );
    for state in 0..model.states {
        ensure!(
            model.means[state].len() == model.dimensions,
            "emission mean dimensions mismatch for state {state}"
        );
        ensure!(
            model.means[state].iter().all(|value| value.is_finite()),
            "emission mean contains a non-finite value for state {state}"
        );
        ensure!(
            model.variances[state].len() == model.dimensions,
            "emission variance dimensions mismatch for state {state}"
        );
        ensure!(
            model.variances[state]
                .iter()
                .all(|value| value.is_finite() && *value > 0.0),
            "emission variance is non-finite or non-positive for state {state}"
        );
    }
    ensure!(
        model.center.len() == model.dimensions,
        "center dimensions mismatch"
    );
    ensure!(
        model.scale.len() == model.dimensions,
        "scale dimensions mismatch"
    );
    ensure!(
        model.center.iter().all(|value| value.is_finite()),
        "standardization center contains a non-finite value"
    );
    ensure!(
        model
            .scale
            .iter()
            .all(|value| value.is_finite() && *value > 0.0),
        "standardization scale is non-finite or non-positive"
    );
    ensure!(
        model.log_likelihood.is_finite() && model.bic.is_finite(),
        "model score metadata is non-finite"
    );
    ensure!(
        model
            .training_likelihoods
            .iter()
            .all(|value| value.is_finite()),
        "training likelihood history contains a non-finite value"
    );
    let mut permutation = model.state_permutation.clone();
    permutation.sort_unstable();
    ensure!(
        permutation == (0..model.states).collect::<Vec<_>>(),
        "state permutation is not a complete one-to-one state mapping"
    );
    Ok(())
}

fn validate_observations(model: &GaussianHmm, observations: &[Vec<f64>]) -> Result<()> {
    ensure!(
        !observations.is_empty(),
        "market-state inference requires a completed observation"
    );
    for (row, observation) in observations.iter().enumerate() {
        ensure!(
            observation.len() == model.dimensions,
            "observation {row} has {} dimensions; expected {}",
            observation.len(),
            model.dimensions
        );
        ensure!(
            observation.iter().all(|value| value.is_finite()),
            "observation {row} contains a non-finite value"
        );
    }
    Ok(())
}

fn geometric_duration(self_transition_probability: f64) -> (Option<f64>, Option<f64>) {
    let exit_probability = 1.0 - self_transition_probability;
    if exit_probability <= 1.0e-12 {
        (None, None)
    } else {
        (
            Some(1.0 / exit_probability),
            Some(self_transition_probability / exit_probability),
        )
    }
}

/// Maps state identities from train-only standardized emissions. Thresholds
/// are fixed and the model artifact is validated before direct indexing.
pub fn map_state_profiles(model: &GaussianHmm) -> Result<Vec<StateProfile>> {
    validate_model_artifact(model)?;
    Ok((0..model.states)
        .map(|state| {
            let return_mean = model.means[state][0];
            let vwap_mean = model.means[state][1];
            let volatility_mean = model.means[state][2];
            let activity_mean = model.means[state][3];
            let self_transition_probability = model.transition[state][state];
            let name = if volatility_mean >= 0.75 && return_mean <= -0.35 {
                StandardStateName::HighVolSellOff
            } else if volatility_mean >= 0.75 && return_mean >= 0.35 {
                StandardStateName::HighVolRecovery
            } else if activity_mean >= 1.0 && volatility_mean >= 0.25 {
                StandardStateName::HighActivityHighVolatility
            } else if volatility_mean <= -0.65 && return_mean >= 0.25 {
                StandardStateName::LowVolTrendUp
            } else if volatility_mean <= -0.65 && return_mean <= -0.25 {
                StandardStateName::LowVolTrendDown
            } else if volatility_mean <= -0.55 && return_mean.abs() < 0.25 {
                StandardStateName::RangeCompression
            } else if return_mean * vwap_mean < 0.0 || vwap_mean.abs() >= 0.75 {
                StandardStateName::MeanReversion
            } else {
                StandardStateName::UnclassifiedPriceFlowState
            };
            StateProfile {
                raw_state_id: state,
                name,
                standardized_return_mean: return_mean,
                standardized_vwap_distance_mean: vwap_mean,
                standardized_volatility_mean: volatility_mean,
                standardized_activity_mean: activity_mean,
                self_transition_probability,
                expected_duration_observations: geometric_duration(self_transition_probability).0,
                expected_future_self_transitions: geometric_duration(self_transition_probability).1,
                duration_model: "GEOMETRIC_MEMORYLESS_HMM".to_string(),
            }
        })
        .collect())
}

/// Returns train-only fractional transition counts from the smoothed xi used by
/// Baum-Welch. These counts are fit diagnostics and must never be joined into a
/// validation, test, or live feature row.
pub fn transition_audit(
    model: &GaussianHmm,
    training_sequences: &[Vec<Vec<f64>>],
) -> Result<Vec<StateTransitionAuditCell>> {
    validate_model_artifact(model)?;
    ensure!(
        training_sequences
            .iter()
            .any(|sequence| sequence.len() >= 2),
        "transition audit requires a training sequence with at least two observations"
    );
    let mut counts = vec![vec![0.0; model.states]; model.states];
    for sequence in training_sequences
        .iter()
        .filter(|sequence| !sequence.is_empty())
    {
        validate_observations(model, sequence)?;
        let diagnostics = model.posterior_diagnostics(sequence)?;
        for xi_time in diagnostics.xi {
            for (from, row) in xi_time.into_iter().enumerate() {
                for (to, value) in row.into_iter().enumerate() {
                    counts[from][to] += value;
                }
            }
        }
    }
    let total = counts.iter().flatten().sum::<f64>();
    ensure!(
        total.is_finite() && total > 0.0,
        "transition audit produced no finite expected transition mass"
    );
    let origin_counts = counts
        .iter()
        .map(|row| row.iter().sum::<f64>())
        .collect::<Vec<_>>();
    Ok((0..model.states)
        .flat_map(|from| {
            let counts = &counts;
            let origin_counts = &origin_counts;
            (0..model.states).map(move |to| StateTransitionAuditCell {
                from_raw_state_id: from,
                to_raw_state_id: to,
                transition_probability: model.transition[from][to],
                train_expected_transition_count: counts[from][to],
                train_expected_origin_count: origin_counts[from],
                count_semantics: "TRAIN_ONLY_SMOOTHED_XI_EXPECTED_MASS_NOT_HARD_OBSERVED_COUNT"
                    .to_string(),
            })
        })
        .collect())
}

/// Computes correct terminal-state distributions q_t A^h for requested
/// same-session horizons. The separate survival value is the probability of
/// never changing state along the path; it is not an endpoint probability.
pub fn forecast_same_session_horizons(
    model: &GaussianHmm,
    filtered: &[f64],
    transitions_ahead: &[usize],
    maximum_same_session_transitions: usize,
) -> Result<Vec<StateHorizonForecast>> {
    validate_model_artifact(model)?;
    validate_probability_vector(filtered, model.states, "filtered state probabilities")?;
    ensure!(
        transitions_ahead.iter().all(|steps| *steps > 0),
        "state forecast horizons must be positive"
    );
    let normalizer = (model.states as f64).ln();
    transitions_ahead
        .iter()
        .map(|steps| {
            if *steps > maximum_same_session_transitions {
                return Ok(StateHorizonForecast {
                    transitions_ahead: *steps,
                    status:
                        "UNAVAILABLE_CROSSES_SESSION_BOUNDARY_REQUIRES_OVERNIGHT_MODEL"
                            .to_string(),
                    endpoint_state_probabilities: None,
                    dominant_raw_state_id: None,
                    dominant_probability: None,
                    endpoint_entropy: None,
                    normalized_endpoint_entropy: None,
                    posterior_weighted_no_state_change_probability: None,
                    probability_semantics:
                        "NO_CROSS_SESSION_EXTRAPOLATION_FROM_SESSION_RESET_INTRADAY_HMM"
                            .to_string(),
                });
            }
            let endpoint = model.horizon_state_probabilities(filtered, *steps, false)?;
            validate_probability_vector(
                &endpoint,
                model.states,
                "horizon endpoint state probabilities",
            )?;
            let entropy = GaussianHmm::state_entropy(&endpoint)?;
            let (dominant_raw_state_id, dominant_probability) = endpoint
                .iter()
                .copied()
                .enumerate()
                .max_by(|left, right| left.1.total_cmp(&right.1))
                .context("horizon state probabilities are empty")?;
            let survival = filtered
                .iter()
                .enumerate()
                .map(|(state, probability)| {
                    probability * model.transition[state][state].powf(*steps as f64)
                })
                .sum::<f64>()
                .clamp(0.0, 1.0);
            Ok(StateHorizonForecast {
                transitions_ahead: *steps,
                status: "AVAILABLE_MODEL_IMPLIED_UNCALIBRATED".to_string(),
                endpoint_state_probabilities: Some(endpoint),
                dominant_raw_state_id: Some(dominant_raw_state_id),
                dominant_probability: Some(dominant_probability),
                endpoint_entropy: Some(entropy),
                normalized_endpoint_entropy: Some((entropy / normalizer).clamp(0.0, 1.0)),
                posterior_weighted_no_state_change_probability: Some(survival),
                probability_semantics:
                    "ENDPOINT_IS_Q_T_TIMES_A_POWER_H; SURVIVAL_IS_NO_STATE_CHANGE_PATH"
                        .to_string(),
            })
        })
        .collect()
}

/// Produces causal state diagnostics from the final forward-filtered vector.
/// Smoothing and Viterbi are intentionally not called here.
pub fn infer_filtered(
    model: &GaussianHmm,
    completed_observations: &[Vec<f64>],
) -> Result<MarketStateEngineOutput> {
    validate_model_artifact(model).context("invalid market-state model artifact")?;
    validate_observations(model, completed_observations)?;
    let filtered_history = model.filtered_probabilities(completed_observations)?;
    let filtered = filtered_history
        .last()
        .cloned()
        .context("market-state inference produced no filtered probability vector")?;
    validate_probability_vector(&filtered, model.states, "filtered state probabilities")?;
    let next = model.next_state_probabilities(&filtered)?;
    validate_probability_vector(&next, model.states, "next-state probabilities")?;
    let entropy = GaussianHmm::state_entropy(&filtered)?;
    ensure!(
        entropy.is_finite() && entropy >= 0.0,
        "state entropy is invalid"
    );
    let profiles = map_state_profiles(model)?;
    let expected_duration =
        filtered
            .iter()
            .zip(&profiles)
            .try_fold(0.0, |total, (probability, profile)| {
                if *probability <= 1.0e-12 {
                    Some(total)
                } else {
                    Some(total + probability * profile.expected_duration_observations?)
                }
            });
    let expected_future_self_transitions =
        filtered
            .iter()
            .zip(&profiles)
            .try_fold(0.0, |total, (probability, profile)| {
                if *probability <= 1.0e-12 {
                    Some(total)
                } else {
                    Some(total + probability * profile.expected_future_self_transitions?)
                }
            });
    let stay_probability = filtered
        .iter()
        .enumerate()
        .map(|(state, probability)| probability * model.transition[state][state])
        .sum::<f64>()
        .clamp(0.0, 1.0);
    let transition_instability = filtered
        .iter()
        .enumerate()
        .map(|(state, probability)| {
            let row_entropy = model.transition[state]
                .iter()
                .filter(|value| **value > 0.0)
                .map(|value| -value * value.ln())
                .sum::<f64>();
            probability * row_entropy
        })
        .sum::<f64>()
        / (model.states as f64).ln();
    let dominant_raw_state_id = filtered
        .iter()
        .enumerate()
        .max_by(|left, right| left.1.total_cmp(right.1))
        .map(|(state, _)| state)
        .context("filtered state probability vector is empty")?;
    let dominant_state_name = profiles
        .get(dominant_raw_state_id)
        .map(|profile| profile.name)
        .context("dominant state has no validated profile")?;
    let schema = STATE_FEATURE_SCHEMA.map(str::to_string).to_vec();
    let model_json = serde_json::to_vec(model).context("serialize market-state model for hash")?;
    let normalized_entropy = (entropy / (model.states as f64).ln()).clamp(0.0, 1.0);
    ensure!(
        transition_instability.is_finite(),
        "market-state transition entropy is non-finite"
    );
    let mut ranked_probabilities = filtered.clone();
    ranked_probabilities.sort_by(|left, right| right.total_cmp(left));
    let top_probability = ranked_probabilities.first().copied().unwrap_or_default();
    let runner_up_probability = ranked_probabilities.get(1).copied().unwrap_or_default();
    let raw_state_certainty = RawStateCertainty {
        top_probability,
        top_two_probability_margin: (top_probability - runner_up_probability).clamp(0.0, 1.0),
        normalized_entropy,
        calibration_status: "UNCALIBRATED_LATENT_STATE_POSTERIOR".to_string(),
        direct_allocation_impact: true,
        continuous_sizing_impact: false,
        hard_no_trade_veto_impact: true,
        semantics: "STATE_CERTAINTY_DIAGNOSTIC_NOT_FORECAST_ACCURACY_OR_RETURN_CONFIDENCE; ENTROPY_THRESHOLD_IS_HARD_VETO_ONLY"
            .to_string(),
    };
    let transition_row_normalized_entropy = transition_instability.clamp(0.0, 1.0);

    Ok(MarketStateEngineOutput {
        filtered_state_probabilities: filtered,
        next_state_probabilities: next,
        regime_entropy: entropy,
        normalized_regime_entropy: normalized_entropy,
        expected_regime_duration_observations: expected_duration,
        expected_future_self_transitions,
        duration_model: "GEOMETRIC_MEMORYLESS_HMM".to_string(),
        duration_semantics:
            "UNTRUNCATED_POSTERIOR_WEIGHTED_GEOMETRIC_SPELL_INCLUDING_CURRENT; FUTURE_SELF_TRANSITIONS_EXCLUDE_CURRENT; MUST_NOT_EXTRAPOLATE_PAST_SESSION_CLOSE"
                .to_string(),
        untruncated_geometric_diagnostic: true,
        must_not_extrapolate_past_session_close: true,
        state_transition_instability: transition_row_normalized_entropy,
        transition_row_normalized_entropy,
        probability_of_regime_change: 1.0 - stay_probability,
        raw_state_certainty,
        dominant_raw_state_id,
        dominant_state_name,
        profiles,
        state_feature_schema: schema,
        state_feature_schema_sha256: sha256_hex(STATE_FEATURE_SCHEMA.join("\u{1f}").as_bytes()),
        model_artifact_sha256: sha256_hex(&model_json),
        completed_observation_count: completed_observations.len(),
        model_validation_status: "ARTIFACT_SCHEMA_VALID_PREDICTIVE_VALIDATION_SEPARATE".to_string(),
        state_mapping_semantics: "FIXED_THRESHOLDS_ON_TRAIN_ONLY_STANDARDIZED_EMISSIONS"
            .to_string(),
        probability_semantics:
            "FORWARD_FILTERED_LATENT_STATE_MODEL_PROBABILITY_NO_SMOOTHING_UNCALIBRATED".to_string(),
        direct_allocation_impact: true,
        continuous_sizing_impact: false,
        hard_no_trade_veto_impact: true,
    })
}

#[cfg(test)]
mod tests {
    use super::{
        StandardStateName, forecast_same_session_horizons, infer_filtered, map_state_profiles,
        transition_audit, validate_model_artifact,
    };
    use crate::engine::regime::GaussianHmm;

    fn model() -> GaussianHmm {
        GaussianHmm {
            states: 2,
            dimensions: 4,
            initial: vec![0.5, 0.5],
            transition: vec![vec![0.9, 0.1], vec![0.2, 0.8]],
            means: vec![vec![-1.0, -0.5, 1.2, 0.3], vec![0.6, 0.2, -0.8, 0.0]],
            variances: vec![vec![1.0; 4], vec![1.0; 4]],
            center: vec![0.0; 4],
            scale: vec![1.0; 4],
            log_likelihood: -1.0,
            bic: 1.0,
            training_likelihoods: vec![-1.0],
            state_permutation: vec![0, 1],
        }
    }

    #[test]
    fn profile_names_are_train_statistic_mappings() {
        let profiles = map_state_profiles(&model()).unwrap();
        assert_eq!(profiles[0].name, StandardStateName::HighVolSellOff);
        assert_eq!(profiles[1].name, StandardStateName::LowVolTrendUp);
        assert_eq!(profiles[0].raw_state_id, 0);
    }

    #[test]
    fn neutral_names_describe_only_observed_price_flow_statistics() {
        let mut neutral = model();
        neutral.means[0] = vec![0.0, 0.0, 0.0, 0.0];
        neutral.means[1] = vec![0.0, 0.0, 0.3, 1.2];
        let profiles = map_state_profiles(&neutral).unwrap();
        assert_eq!(
            profiles[0].name,
            StandardStateName::UnclassifiedPriceFlowState
        );
        assert_eq!(
            profiles[1].name,
            StandardStateName::HighActivityHighVolatility
        );
        let legacy: StandardStateName =
            serde_json::from_str("\"OPENING_PRICE_DISCOVERY\"").unwrap();
        assert_eq!(legacy, StandardStateName::UnclassifiedPriceFlowState);
    }

    #[test]
    fn live_output_is_filtered_normalized_and_hashed() {
        let output = infer_filtered(&model(), &[vec![0.1, 0.0, 0.2, 0.1]]).unwrap();
        assert!((output.filtered_state_probabilities.iter().sum::<f64>() - 1.0).abs() < 1e-9);
        assert!((output.next_state_probabilities.iter().sum::<f64>() - 1.0).abs() < 1e-9);
        assert!(output.probability_of_regime_change >= 0.0);
        assert!(output.probability_semantics.contains("NO_SMOOTHING"));
        assert_eq!(output.state_feature_schema.len(), 4);
        assert_eq!(output.state_feature_schema_sha256.len(), 64);
        assert_eq!(output.model_artifact_sha256.len(), 64);
        assert_eq!(
            output.model_validation_status,
            "ARTIFACT_SCHEMA_VALID_PREDICTIVE_VALIDATION_SEPARATE"
        );
        assert!(output.direct_allocation_impact);
        assert!(!output.continuous_sizing_impact);
        assert!(output.hard_no_trade_veto_impact);
        assert!(output.raw_state_certainty.direct_allocation_impact);
        assert!(!output.raw_state_certainty.continuous_sizing_impact);
        assert!(output.raw_state_certainty.hard_no_trade_veto_impact);
        assert!(output.untruncated_geometric_diagnostic);
        assert!(output.must_not_extrapolate_past_session_close);
        assert!(output.duration_semantics.contains("UNTRUNCATED"));
        assert!(output.duration_semantics.contains("MUST_NOT_EXTRAPOLATE"));
    }

    #[test]
    fn invalid_model_dimensions_and_transition_rows_fail_closed() {
        let mut bad_dimensions = model();
        bad_dimensions.dimensions = 3;
        assert!(validate_model_artifact(&bad_dimensions).is_err());
        assert!(infer_filtered(&bad_dimensions, &[vec![0.1, 0.2, 0.3]]).is_err());

        let mut bad_transition = model();
        bad_transition.transition[0] = vec![0.9, 0.2];
        assert!(validate_model_artifact(&bad_transition).is_err());
    }

    #[test]
    fn non_finite_or_wrong_width_observations_are_rejected() {
        assert!(infer_filtered(&model(), &[vec![0.1, 0.2, f64::NAN, 0.4]]).is_err());
        assert!(infer_filtered(&model(), &[vec![0.1, 0.2, 0.3]]).is_err());
    }

    #[test]
    fn multi_step_endpoint_uses_matrix_power_not_scalar_probability_power() {
        let forecasts = forecast_same_session_horizons(&model(), &[0.0, 1.0], &[1, 2], 2).unwrap();
        let one = forecasts[0].endpoint_state_probabilities.as_ref().unwrap();
        let two = forecasts[1].endpoint_state_probabilities.as_ref().unwrap();
        assert!((one[0] - 0.2).abs() < 1.0e-12);
        assert!((one[1] - 0.8).abs() < 1.0e-12);
        assert!((two[0] - 0.34).abs() < 1.0e-12);
        assert!((two[1] - 0.66).abs() < 1.0e-12);
        assert!(
            (forecasts[1]
                .posterior_weighted_no_state_change_probability
                .unwrap()
                - 0.64)
                .abs()
                < 1.0e-12
        );
        assert_ne!(two[1], 0.8_f64.powi(2));
    }

    #[test]
    fn same_session_horizons_fail_closed_at_the_boundary() {
        let forecasts =
            forecast_same_session_horizons(&model(), &[0.25, 0.75], &[1, 2], 1).unwrap();
        assert!(forecasts[0].endpoint_state_probabilities.is_some());
        assert!(forecasts[1].endpoint_state_probabilities.is_none());
        assert!(forecasts[1].status.contains("CROSSES_SESSION_BOUNDARY"));
    }

    #[test]
    fn train_transition_audit_uses_fractional_expected_mass() {
        let sequences = vec![vec![
            vec![-0.8, -0.4, 1.0, 0.2],
            vec![0.7, 0.3, -0.7, 0.0],
            vec![0.8, 0.4, -0.8, 0.1],
        ]];
        let cells = transition_audit(&model(), &sequences).unwrap();
        assert_eq!(cells.len(), 4);
        let total = cells
            .iter()
            .map(|cell| cell.train_expected_transition_count)
            .sum::<f64>();
        assert!((total - 2.0).abs() < 1.0e-9);
        assert!(cells.iter().all(|cell| cell.count_semantics.contains("XI")));
    }

    #[test]
    fn absorbing_state_duration_is_unbounded_not_a_large_finite_number() {
        let mut absorbing = model();
        absorbing.transition[0] = vec![1.0, 0.0];
        let profiles = map_state_profiles(&absorbing).unwrap();
        assert_eq!(profiles[0].expected_duration_observations, None);
        assert_eq!(profiles[0].expected_future_self_transitions, None);
    }
}
