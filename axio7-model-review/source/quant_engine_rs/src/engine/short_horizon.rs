//! Causal, research-only short-horizon statistical components.
//!
//! This module is wired only into the production predictor's stochastic
//! research shadow envelope. It never changes the published forecast,
//! probability, allocation, or decision. It consumes an already-filtered
//! regime posterior and provides:
//!
//! - posterior-weighted Markov transition and diffusion estimates;
//! - an OU model whose API is explicitly limited to VWAP residuals;
//! - a diagnostic-only jump gate;
//! - a residual martingale/e-process auditor that can veto but never approve;
//! - a regime-conditioned momentum continuation/reversal head.
//!
//! No smoother, future observation, immature outcome, personalized position,
//! order, or profit claim is represented by these APIs.

use std::collections::BTreeMap;

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};

pub const STANDARD_HORIZONS_MINUTES: [u32; 4] = [5, 15, 30, 60];
pub const GAUSSIAN_MOMENT_MATCHED_RESEARCH_STATUS: &str =
    "UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED";

const PROBABILITY_TOLERANCE: f64 = 1.0e-6;
const NUMERIC_FLOOR: f64 = 1.0e-12;
const GAUSSIAN_MOMENT_MATCHED_METHOD: &str = "GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS";
const GAUSSIAN_MOMENT_MATCHED_SEMANTICS: &str = "MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS";
const CENTRAL_LOG_RETURN_INTERVALS: [(f64, f64); 3] = [
    (0.80, 1.281_551_565_544_600_4),
    (0.90, 1.644_853_626_951_472_2),
    (0.95, 1.959_963_984_540_054),
];

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ShortHorizonReason {
    EmptyTrainingSet,
    NonFiniteInput,
    InvalidAsOfOrder,
    InputAvailableAfterFitAsOf,
    ObservationOrderInvalid,
    InvalidIntervalMinutes,
    MixedIntervalMinutes,
    UnsupportedHorizon,
    RegimeDimensionMismatch,
    InvalidRegimeProbability,
    InvalidFilteredTransitionPosterior,
    TransitionEstimateUnavailable,
    TransitionStateWeightInsufficient,
    TransitionCountsApproximatedFromFilteredMarginals,
    RegimeEffectiveSampleInsufficient,
    DiffusionVarianceInvalid,
    OuPairSampleInsufficient,
    OuDesignDegenerate,
    OuNotMeanReverting,
    OuModelDisabled,
    ForecastBeforeModelFit,
    ForecastInputFromFuture,
    ForecastRegimeFromFuture,
    InvalidMaterialMoveThreshold,
    GaussianMomentMatchedDistributionInvalid,
    JumpModelUnvalidated,
    JumpValidationEvidenceFromFuture,
    JumpValidationSampleInsufficient,
    JumpValidationNoImprovement,
    JumpEventsInsufficient,
    JumpDiagnosticOnlyNotInForecast,
    ResidualInputNotCausal,
    ResidualOutcomeNotMature,
    ResidualScaleInvalid,
    ResidualBoundViolation,
    ResidualPhaseStreamOverlap,
    MartingaleAuditInputInvalid,
    MartingaleAuditSamplesInsufficient,
    MartingaleEProcessThresholdBreached,
    MomentumHeadUnvalidated,
    MomentumValidationEvidenceFromFuture,
    MomentumValidationSampleInsufficient,
    MomentumValidationNoImprovement,
    MomentumSampleInsufficient,
    MomentumScoreNeutral,
}

fn push_unique(reasons: &mut Vec<ShortHorizonReason>, reason: ShortHorizonReason) {
    if !reasons.contains(&reason) {
        reasons.push(reason);
    }
}

fn is_standard_horizon(horizon_minutes: u32) -> bool {
    STANDARD_HORIZONS_MINUTES.contains(&horizon_minutes)
}

fn valid_probability_vector(values: &[f64], expected: usize) -> bool {
    values.len() == expected
        && !values.is_empty()
        && values
            .iter()
            .all(|value| value.is_finite() && *value >= 0.0 && *value <= 1.0)
        && (values.iter().sum::<f64>() - 1.0).abs() <= PROBABILITY_TOLERANCE
}

fn valid_transition_posterior(values: &[Vec<f64>], states: usize) -> bool {
    values.len() == states
        && values.iter().all(|row| {
            row.len() == states
                && row
                    .iter()
                    .all(|value| value.is_finite() && *value >= 0.0 && *value <= 1.0)
        })
        && (values.iter().flatten().sum::<f64>() - 1.0).abs() <= PROBABILITY_TOLERANCE
}

fn effective_sample_size(sum_weight: f64, sum_squared_weight: f64) -> f64 {
    if sum_weight.is_finite()
        && sum_squared_weight.is_finite()
        && sum_weight > 0.0
        && sum_squared_weight > 0.0
    {
        sum_weight * sum_weight / sum_squared_weight
    } else {
        0.0
    }
}

fn finite_moments(mean: f64, variance: f64) -> Option<DistributionMoments> {
    if !mean.is_finite() || !variance.is_finite() {
        return None;
    }
    let variance = variance.max(0.0);
    Some(DistributionMoments {
        mean,
        variance,
        standard_deviation: variance.sqrt(),
    })
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ShortHorizonConfig {
    pub minimum_regime_effective_observations: f64,
    pub minimum_transition_weight_per_state: f64,
    pub transition_dirichlet_prior: f64,
    pub diffusion_variance_floor_per_minute: f64,
    pub minimum_ou_effective_pairs: f64,
    pub minimum_ou_phi: f64,
    pub maximum_ou_phi: f64,
    pub jump_z_threshold: f64,
    pub minimum_jump_events: usize,
    pub minimum_jump_validation_samples: usize,
    pub minimum_jump_log_score_improvement: f64,
    pub momentum_neutral_threshold: f64,
    pub momentum_beta_prior_alpha: f64,
    pub momentum_beta_prior_beta: f64,
    pub minimum_momentum_effective_samples: f64,
    pub minimum_momentum_validation_samples: usize,
    pub minimum_momentum_brier_improvement: f64,
}

impl Default for ShortHorizonConfig {
    fn default() -> Self {
        Self {
            minimum_regime_effective_observations: 30.0,
            minimum_transition_weight_per_state: 10.0,
            transition_dirichlet_prior: 0.5,
            diffusion_variance_floor_per_minute: 1.0e-10,
            minimum_ou_effective_pairs: 30.0,
            minimum_ou_phi: 0.01,
            maximum_ou_phi: 0.999,
            jump_z_threshold: 4.0,
            minimum_jump_events: 20,
            minimum_jump_validation_samples: 200,
            minimum_jump_log_score_improvement: 0.0,
            momentum_neutral_threshold: 1.0e-8,
            momentum_beta_prior_alpha: 1.0,
            momentum_beta_prior_beta: 1.0,
            minimum_momentum_effective_samples: 30.0,
            minimum_momentum_validation_samples: 200,
            minimum_momentum_brier_improvement: 0.0,
        }
    }
}

impl ShortHorizonConfig {
    fn valid(&self) -> bool {
        self.minimum_regime_effective_observations.is_finite()
            && self.minimum_regime_effective_observations > 0.0
            && self.minimum_transition_weight_per_state.is_finite()
            && self.minimum_transition_weight_per_state > 0.0
            && self.transition_dirichlet_prior.is_finite()
            && self.transition_dirichlet_prior > 0.0
            && self.diffusion_variance_floor_per_minute.is_finite()
            && self.diffusion_variance_floor_per_minute > 0.0
            && self.minimum_ou_effective_pairs.is_finite()
            && self.minimum_ou_effective_pairs > 0.0
            && self.minimum_ou_phi.is_finite()
            && self.maximum_ou_phi.is_finite()
            && self.minimum_ou_phi > 0.0
            && self.minimum_ou_phi < self.maximum_ou_phi
            && self.maximum_ou_phi < 1.0
            && self.jump_z_threshold.is_finite()
            && self.jump_z_threshold > 0.0
            && self.minimum_jump_events > 0
            && self.minimum_jump_validation_samples > 0
            && self.minimum_jump_log_score_improvement.is_finite()
            && self.momentum_neutral_threshold.is_finite()
            && self.momentum_neutral_threshold >= 0.0
            && self.momentum_beta_prior_alpha.is_finite()
            && self.momentum_beta_prior_alpha > 0.0
            && self.momentum_beta_prior_beta.is_finite()
            && self.momentum_beta_prior_beta > 0.0
            && self.minimum_momentum_effective_samples.is_finite()
            && self.minimum_momentum_effective_samples > 0.0
            && self.minimum_momentum_validation_samples > 0
            && self.minimum_momentum_brier_improvement.is_finite()
    }
}

/// A completed interval. `filtered_regime_probabilities` must be computed
/// using information through `as_of`, never a full-sample smoother.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CausalRegimeInterval {
    pub interval_start: DateTime<Utc>,
    pub as_of: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
    pub session_id: String,
    pub log_return: f64,
    /// The only process accepted by the OU estimator.
    pub vwap_residual: f64,
    pub filtered_regime_probabilities: Vec<f64>,
    /// Optional causal P(S[t-1]=i,S[t]=j | information through t).
    /// If absent, the transition estimate uses the outer product of adjacent
    /// filtered marginals and records an explicit warning.
    pub filtered_transition_from_previous: Option<Vec<Vec<f64>>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct JumpValidationEvidence {
    pub as_of: DateTime<Utc>,
    pub independently_validated: bool,
    pub validation_sample_count: usize,
    pub out_of_sample_log_score_improvement: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DiffusionStateParameters {
    pub state: usize,
    pub drift_per_minute: f64,
    pub variance_rate_per_minute: f64,
    pub volatility_per_sqrt_minute: f64,
    pub posterior_weight: f64,
    pub effective_observations: f64,
}

/// Discrete exact-transition representation of a continuous OU process for a
/// VWAP residual. There is deliberately no constructor accepting raw price.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct VwapResidualOuParameters {
    pub state: usize,
    pub intercept_per_base_interval: f64,
    pub autoregressive_phi: f64,
    pub long_run_vwap_residual: f64,
    pub kappa_per_minute: f64,
    pub diffusion_variance_rate_per_minute: f64,
    pub innovation_variance_per_base_interval: f64,
    pub posterior_weight: f64,
    pub effective_pairs: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct JumpStateDiagnostic {
    pub state: usize,
    pub posterior_weighted_events: f64,
    pub posterior_weighted_minutes: f64,
    pub event_rate_per_minute: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct JumpDiagnostic {
    /// This means eligible for shadow diagnostic comparison only.
    pub enabled: bool,
    pub affects_forecast_moments: bool,
    pub z_threshold: f64,
    pub hard_event_count: usize,
    pub weighted_event_count: f64,
    pub event_rate_per_minute: f64,
    pub states: Vec<JumpStateDiagnostic>,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub usage_policy: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RegimeConditionedShortHorizonModel {
    pub fit_as_of: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub base_interval_minutes: u32,
    pub state_count: usize,
    pub training_observation_count: usize,
    pub transition_pair_count: usize,
    pub transition_matrix: Vec<Vec<f64>>,
    pub transition_row_weights: Vec<f64>,
    pub diffusion_states: Vec<DiffusionStateParameters>,
    pub vwap_residual_ou_states: Vec<Option<VwapResidualOuParameters>>,
    pub vwap_residual_ou_enabled: bool,
    pub vwap_residual_ou_rejection_reasons: Vec<ShortHorizonReason>,
    pub jump_diagnostic: JumpDiagnostic,
    pub probability_semantics: String,
    pub research_policy: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ShortHorizonFitResult {
    pub model: Option<RegimeConditionedShortHorizonModel>,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub warnings: Vec<ShortHorizonReason>,
}

#[derive(Debug, Clone, Copy, Default)]
struct WeightedMoments {
    sum_weight: f64,
    sum_squared_weight: f64,
    sum_weighted_value: f64,
}

impl WeightedMoments {
    fn add(&mut self, weight: f64, value: f64) {
        self.sum_weight += weight;
        self.sum_squared_weight += weight * weight;
        self.sum_weighted_value += weight * value;
    }

    fn effective_sample_size(&self) -> f64 {
        effective_sample_size(self.sum_weight, self.sum_squared_weight)
    }
}

fn validate_regime_intervals(
    observations: &[CausalRegimeInterval],
    fit_as_of: DateTime<Utc>,
    config: &ShortHorizonConfig,
) -> Result<(usize, u32), Vec<ShortHorizonReason>> {
    let mut reasons = Vec::new();
    if observations.is_empty() {
        reasons.push(ShortHorizonReason::EmptyTrainingSet);
        return Err(reasons);
    }
    if !config.valid() {
        reasons.push(ShortHorizonReason::NonFiniteInput);
        return Err(reasons);
    }
    let states = observations[0].filtered_regime_probabilities.len();
    if states == 0 {
        reasons.push(ShortHorizonReason::RegimeDimensionMismatch);
        return Err(reasons);
    }
    let interval_seconds = observations[0]
        .as_of
        .signed_duration_since(observations[0].interval_start)
        .num_seconds();
    if interval_seconds <= 0 || interval_seconds % 60 != 0 {
        reasons.push(ShortHorizonReason::InvalidIntervalMinutes);
        return Err(reasons);
    }
    let interval_minutes = (interval_seconds / 60) as u32;
    if !STANDARD_HORIZONS_MINUTES
        .iter()
        .all(|horizon| horizon % interval_minutes == 0)
    {
        reasons.push(ShortHorizonReason::InvalidIntervalMinutes);
    }
    let mut previous_as_of = None;
    for observation in observations {
        if observation.session_id.is_empty()
            || !observation.log_return.is_finite()
            || !observation.vwap_residual.is_finite()
        {
            push_unique(&mut reasons, ShortHorizonReason::NonFiniteInput);
        }
        if observation.interval_start >= observation.as_of
            || observation.as_of > observation.available_at
        {
            push_unique(&mut reasons, ShortHorizonReason::InvalidAsOfOrder);
        }
        if observation.as_of > fit_as_of || observation.available_at > fit_as_of {
            push_unique(&mut reasons, ShortHorizonReason::InputAvailableAfterFitAsOf);
        }
        if previous_as_of.is_some_and(|previous| observation.as_of <= previous) {
            push_unique(&mut reasons, ShortHorizonReason::ObservationOrderInvalid);
        }
        previous_as_of = Some(observation.as_of);
        let seconds = observation
            .as_of
            .signed_duration_since(observation.interval_start)
            .num_seconds();
        if seconds <= 0 || seconds % 60 != 0 {
            push_unique(&mut reasons, ShortHorizonReason::InvalidIntervalMinutes);
        } else if seconds / 60 != i64::from(interval_minutes) {
            push_unique(&mut reasons, ShortHorizonReason::MixedIntervalMinutes);
        }
        if observation.filtered_regime_probabilities.len() != states {
            push_unique(&mut reasons, ShortHorizonReason::RegimeDimensionMismatch);
        } else if !valid_probability_vector(&observation.filtered_regime_probabilities, states) {
            push_unique(&mut reasons, ShortHorizonReason::InvalidRegimeProbability);
        }
        if observation
            .filtered_transition_from_previous
            .as_ref()
            .is_some_and(|matrix| !valid_transition_posterior(matrix, states))
        {
            push_unique(
                &mut reasons,
                ShortHorizonReason::InvalidFilteredTransitionPosterior,
            );
        }
    }
    if reasons.is_empty() {
        Ok((states, interval_minutes))
    } else {
        Err(reasons)
    }
}

fn estimate_diffusion_states(
    observations: &[CausalRegimeInterval],
    states: usize,
    interval_minutes: u32,
    config: &ShortHorizonConfig,
) -> Result<Vec<DiffusionStateParameters>, Vec<ShortHorizonReason>> {
    let dt = f64::from(interval_minutes);
    let mut first_pass = vec![WeightedMoments::default(); states];
    for observation in observations {
        for (state, weight) in observation
            .filtered_regime_probabilities
            .iter()
            .copied()
            .enumerate()
        {
            first_pass[state].add(weight, observation.log_return);
        }
    }
    let mut reasons = Vec::new();
    let mut output = Vec::with_capacity(states);
    for (state, accumulator) in first_pass.iter().copied().enumerate().take(states) {
        let effective = accumulator.effective_sample_size();
        if effective < config.minimum_regime_effective_observations
            || accumulator.sum_weight <= NUMERIC_FLOOR
        {
            push_unique(
                &mut reasons,
                ShortHorizonReason::RegimeEffectiveSampleInsufficient,
            );
            continue;
        }
        let drift = accumulator.sum_weighted_value / (accumulator.sum_weight * dt);
        let mut squared_error = 0.0;
        for observation in observations {
            let weight = observation.filtered_regime_probabilities[state];
            let residual = observation.log_return - drift * dt;
            squared_error += weight * residual * residual;
        }
        let variance_rate = (squared_error / (accumulator.sum_weight * dt))
            .max(config.diffusion_variance_floor_per_minute);
        if !drift.is_finite() || !variance_rate.is_finite() || variance_rate <= 0.0 {
            push_unique(&mut reasons, ShortHorizonReason::DiffusionVarianceInvalid);
            continue;
        }
        output.push(DiffusionStateParameters {
            state,
            drift_per_minute: drift,
            variance_rate_per_minute: variance_rate,
            volatility_per_sqrt_minute: variance_rate.sqrt(),
            posterior_weight: accumulator.sum_weight,
            effective_observations: effective,
        });
    }
    if reasons.is_empty() && output.len() == states {
        Ok(output)
    } else {
        Err(reasons)
    }
}

#[derive(Debug, Clone, Copy, Default)]
struct WeightedRegression {
    sum_weight: f64,
    sum_squared_weight: f64,
    sum_x: f64,
    sum_y: f64,
    sum_xx: f64,
    sum_xy: f64,
}

impl WeightedRegression {
    fn add(&mut self, weight: f64, x: f64, y: f64) {
        self.sum_weight += weight;
        self.sum_squared_weight += weight * weight;
        self.sum_x += weight * x;
        self.sum_y += weight * y;
        self.sum_xx += weight * x * x;
        self.sum_xy += weight * x * y;
    }

    fn effective_sample_size(&self) -> f64 {
        effective_sample_size(self.sum_weight, self.sum_squared_weight)
    }
}

fn estimate_vwap_residual_ou(
    observations: &[CausalRegimeInterval],
    states: usize,
    interval_minutes: u32,
    config: &ShortHorizonConfig,
) -> (
    Vec<Option<VwapResidualOuParameters>>,
    Vec<ShortHorizonReason>,
) {
    let mut regressions = vec![WeightedRegression::default(); states];
    for pair in observations.windows(2) {
        let previous = &pair[0];
        let current = &pair[1];
        if previous.session_id != current.session_id || previous.as_of != current.interval_start {
            continue;
        }
        for (state, weight) in current
            .filtered_regime_probabilities
            .iter()
            .copied()
            .enumerate()
        {
            regressions[state].add(weight, previous.vwap_residual, current.vwap_residual);
        }
    }
    let mut output = vec![None; states];
    let mut reasons = Vec::new();
    let dt = f64::from(interval_minutes);
    for state in 0..states {
        let regression = regressions[state];
        let effective = regression.effective_sample_size();
        if effective < config.minimum_ou_effective_pairs || regression.sum_weight <= NUMERIC_FLOOR {
            push_unique(&mut reasons, ShortHorizonReason::OuPairSampleInsufficient);
            continue;
        }
        let centered_xx =
            regression.sum_xx - regression.sum_x * regression.sum_x / regression.sum_weight;
        let centered_xy =
            regression.sum_xy - regression.sum_x * regression.sum_y / regression.sum_weight;
        if !centered_xx.is_finite() || centered_xx <= NUMERIC_FLOOR {
            push_unique(&mut reasons, ShortHorizonReason::OuDesignDegenerate);
            continue;
        }
        let phi = centered_xy / centered_xx;
        if !phi.is_finite() || phi <= config.minimum_ou_phi || phi >= config.maximum_ou_phi {
            push_unique(&mut reasons, ShortHorizonReason::OuNotMeanReverting);
            continue;
        }
        let intercept = (regression.sum_y - phi * regression.sum_x) / regression.sum_weight;
        let theta = intercept / (1.0 - phi);
        let kappa = -phi.ln() / dt;
        let mut weighted_squared_error = 0.0;
        for pair in observations.windows(2) {
            let previous = &pair[0];
            let current = &pair[1];
            if previous.session_id != current.session_id || previous.as_of != current.interval_start
            {
                continue;
            }
            let weight = current.filtered_regime_probabilities[state];
            let residual = current.vwap_residual - intercept - phi * previous.vwap_residual;
            weighted_squared_error += weight * residual * residual;
        }
        let innovation_variance = (weighted_squared_error / regression.sum_weight)
            .max(config.diffusion_variance_floor_per_minute * dt);
        let denominator = 1.0 - phi * phi;
        let diffusion_variance_rate = innovation_variance * 2.0 * kappa / denominator;
        if !intercept.is_finite()
            || !theta.is_finite()
            || !kappa.is_finite()
            || !diffusion_variance_rate.is_finite()
            || diffusion_variance_rate <= 0.0
        {
            push_unique(&mut reasons, ShortHorizonReason::OuDesignDegenerate);
            continue;
        }
        output[state] = Some(VwapResidualOuParameters {
            state,
            intercept_per_base_interval: intercept,
            autoregressive_phi: phi,
            long_run_vwap_residual: theta,
            kappa_per_minute: kappa,
            diffusion_variance_rate_per_minute: diffusion_variance_rate,
            innovation_variance_per_base_interval: innovation_variance,
            posterior_weight: regression.sum_weight,
            effective_pairs: effective,
        });
    }
    if output.iter().any(Option::is_none) {
        push_unique(&mut reasons, ShortHorizonReason::OuModelDisabled);
    }
    (output, reasons)
}

type TransitionEstimate = (Vec<Vec<f64>>, Vec<f64>, usize, bool);

fn estimate_transition_matrix(
    observations: &[CausalRegimeInterval],
    states: usize,
    config: &ShortHorizonConfig,
) -> Result<TransitionEstimate, Vec<ShortHorizonReason>> {
    let mut counts = vec![vec![config.transition_dirichlet_prior; states]; states];
    let mut row_weights = vec![0.0; states];
    let mut pair_count = 0usize;
    let mut used_marginal_approximation = false;
    for pair in observations.windows(2) {
        let previous = &pair[0];
        let current = &pair[1];
        if previous.session_id != current.session_id || previous.as_of != current.interval_start {
            continue;
        }
        pair_count += 1;
        if let Some(pair_posterior) = &current.filtered_transition_from_previous {
            for ((count_row, row_weight), posterior_row) in
                counts.iter_mut().zip(&mut row_weights).zip(pair_posterior)
            {
                for (count, posterior_weight) in count_row.iter_mut().zip(posterior_row) {
                    *count += *posterior_weight;
                    *row_weight += *posterior_weight;
                }
            }
        } else {
            used_marginal_approximation = true;
            for ((count_row, row_weight), from_probability) in counts
                .iter_mut()
                .zip(&mut row_weights)
                .zip(&previous.filtered_regime_probabilities)
            {
                for (count, to_probability) in count_row
                    .iter_mut()
                    .zip(&current.filtered_regime_probabilities)
                {
                    let weight = from_probability * to_probability;
                    *count += weight;
                    *row_weight += weight;
                }
            }
        }
    }
    let mut reasons = Vec::new();
    if pair_count == 0 {
        reasons.push(ShortHorizonReason::TransitionEstimateUnavailable);
        return Err(reasons);
    }
    if row_weights
        .iter()
        .any(|weight| *weight < config.minimum_transition_weight_per_state)
    {
        reasons.push(ShortHorizonReason::TransitionStateWeightInsufficient);
        return Err(reasons);
    }
    for row in &mut counts {
        let total = row.iter().sum::<f64>();
        if !total.is_finite() || total <= NUMERIC_FLOOR {
            reasons.push(ShortHorizonReason::TransitionEstimateUnavailable);
            return Err(reasons);
        }
        for value in row {
            *value /= total;
        }
    }
    Ok((counts, row_weights, pair_count, used_marginal_approximation))
}

fn jump_diagnostic(
    observations: &[CausalRegimeInterval],
    diffusion_states: &[DiffusionStateParameters],
    interval_minutes: u32,
    fit_as_of: DateTime<Utc>,
    validation: Option<&JumpValidationEvidence>,
    config: &ShortHorizonConfig,
) -> JumpDiagnostic {
    let states = diffusion_states.len();
    let dt = f64::from(interval_minutes);
    let mut state_events = vec![0.0; states];
    let mut state_minutes = vec![0.0; states];
    let mut hard_events = 0usize;
    let mut weighted_events = 0.0;
    for observation in observations {
        let mut mean = 0.0;
        let mut second = 0.0;
        for (state, probability) in observation
            .filtered_regime_probabilities
            .iter()
            .copied()
            .enumerate()
        {
            let conditional_mean = diffusion_states[state].drift_per_minute * dt;
            let conditional_variance = diffusion_states[state].variance_rate_per_minute * dt;
            mean += probability * conditional_mean;
            second += probability * (conditional_variance + conditional_mean * conditional_mean);
            state_minutes[state] += probability * dt;
        }
        let variance = (second - mean * mean).max(config.diffusion_variance_floor_per_minute * dt);
        let z = (observation.log_return - mean) / variance.sqrt();
        if z.abs() >= config.jump_z_threshold {
            hard_events += 1;
            weighted_events += 1.0;
            for (state, probability) in observation
                .filtered_regime_probabilities
                .iter()
                .copied()
                .enumerate()
            {
                state_events[state] += probability;
            }
        }
    }
    let total_minutes = state_minutes.iter().sum::<f64>();
    let mut rejection_reasons = Vec::new();
    match validation {
        None => rejection_reasons.push(ShortHorizonReason::JumpModelUnvalidated),
        Some(evidence) => {
            if evidence.as_of > fit_as_of {
                rejection_reasons.push(ShortHorizonReason::JumpValidationEvidenceFromFuture);
            }
            if !evidence.independently_validated {
                rejection_reasons.push(ShortHorizonReason::JumpModelUnvalidated);
            }
            if evidence.validation_sample_count < config.minimum_jump_validation_samples {
                rejection_reasons.push(ShortHorizonReason::JumpValidationSampleInsufficient);
            }
            if !evidence.out_of_sample_log_score_improvement.is_finite()
                || evidence.out_of_sample_log_score_improvement
                    <= config.minimum_jump_log_score_improvement
            {
                rejection_reasons.push(ShortHorizonReason::JumpValidationNoImprovement);
            }
        }
    }
    if hard_events < config.minimum_jump_events {
        rejection_reasons.push(ShortHorizonReason::JumpEventsInsufficient);
    }
    let enabled = rejection_reasons.is_empty();
    let state_rows = (0..states)
        .map(|state| JumpStateDiagnostic {
            state,
            posterior_weighted_events: state_events[state],
            posterior_weighted_minutes: state_minutes[state],
            event_rate_per_minute: if state_minutes[state] > 0.0 {
                state_events[state] / state_minutes[state]
            } else {
                0.0
            },
        })
        .collect();
    JumpDiagnostic {
        enabled,
        affects_forecast_moments: false,
        z_threshold: config.jump_z_threshold,
        hard_event_count: hard_events,
        weighted_event_count: weighted_events,
        event_rate_per_minute: if total_minutes > 0.0 {
            weighted_events / total_minutes
        } else {
            0.0
        },
        states: state_rows,
        rejection_reasons,
        usage_policy: "SHADOW_DIAGNOSTIC_ONLY; NEVER_ALTERS_FORECAST_MOMENTS_OR_IMPLIES_A_TRADE"
            .into(),
    }
}

pub fn fit_regime_conditioned_model(
    observations: &[CausalRegimeInterval],
    fit_as_of: DateTime<Utc>,
    jump_validation: Option<&JumpValidationEvidence>,
    config: &ShortHorizonConfig,
) -> ShortHorizonFitResult {
    let mut warnings = Vec::new();
    let (states, interval_minutes) =
        match validate_regime_intervals(observations, fit_as_of, config) {
            Ok(value) => value,
            Err(rejection_reasons) => {
                return ShortHorizonFitResult {
                    model: None,
                    rejection_reasons,
                    warnings,
                };
            }
        };
    let diffusion_states =
        match estimate_diffusion_states(observations, states, interval_minutes, config) {
            Ok(value) => value,
            Err(rejection_reasons) => {
                return ShortHorizonFitResult {
                    model: None,
                    rejection_reasons,
                    warnings,
                };
            }
        };
    let (transition_matrix, transition_row_weights, pair_count, approximated) =
        match estimate_transition_matrix(observations, states, config) {
            Ok(value) => value,
            Err(rejection_reasons) => {
                return ShortHorizonFitResult {
                    model: None,
                    rejection_reasons,
                    warnings,
                };
            }
        };
    if approximated {
        warnings.push(ShortHorizonReason::TransitionCountsApproximatedFromFilteredMarginals);
    }
    let (ou_states, ou_reasons) =
        estimate_vwap_residual_ou(observations, states, interval_minutes, config);
    warnings.extend(ou_reasons.iter().copied());
    let jump = jump_diagnostic(
        observations,
        &diffusion_states,
        interval_minutes,
        fit_as_of,
        jump_validation,
        config,
    );
    warnings.extend(jump.rejection_reasons.iter().copied());
    warnings.push(ShortHorizonReason::JumpDiagnosticOnlyNotInForecast);
    warnings.sort();
    warnings.dedup();
    let observation_cutoff = observations
        .last()
        .map(|row| row.as_of)
        .unwrap_or(fit_as_of);
    ShortHorizonFitResult {
        model: Some(RegimeConditionedShortHorizonModel {
            fit_as_of,
            observation_cutoff,
            base_interval_minutes: interval_minutes,
            state_count: states,
            training_observation_count: observations.len(),
            transition_pair_count: pair_count,
            transition_matrix,
            transition_row_weights,
            diffusion_states,
            vwap_residual_ou_enabled: ou_states.iter().all(Option::is_some),
            vwap_residual_ou_states: ou_states,
            vwap_residual_ou_rejection_reasons: ou_reasons,
            jump_diagnostic: jump,
            probability_semantics:
                "INPUT_IS_FILTERED_P_STATE_GIVEN_INFORMATION_THROUGH_AS_OF; NO_SMOOTHING".into(),
            research_policy:
                "RESEARCH_ONLY_SHADOW_LAYER; NO_ORDER_OR_PROFIT_CLAIM; NO_DECISION_AUTHORITY".into(),
        }),
        rejection_reasons: Vec::new(),
        warnings,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DistributionMoments {
    pub mean: f64,
    pub variance: f64,
    pub standard_deviation: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DirectionProbabilities {
    pub p_up: f64,
    pub p_flat: f64,
    pub p_down: f64,
    pub material_move_lower_threshold_log_return: f64,
    pub material_move_upper_threshold_log_return: f64,
    pub method: String,
    pub status: String,
    pub semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CentralPredictionInterval {
    pub probability_mass: f64,
    pub lower_log_return: f64,
    pub upper_log_return: f64,
    pub method: String,
    pub status: String,
    pub semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ShortHorizonForecastRequest {
    pub as_of: DateTime<Utc>,
    pub latest_input_as_of: DateTime<Utc>,
    pub latest_input_available_at: DateTime<Utc>,
    pub regime_probabilities_as_of: DateTime<Utc>,
    pub regime_probabilities_available_at: DateTime<Utc>,
    pub filtered_regime_probabilities: Vec<f64>,
    pub current_vwap_residual: f64,
    pub material_move_lower_threshold_log_return: f64,
    pub material_move_upper_threshold_log_return: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HorizonDistributionForecast {
    pub horizon_minutes: u32,
    pub terminal_state_probabilities: Vec<f64>,
    pub trend_log_return: DistributionMoments,
    pub direction_probabilities: DirectionProbabilities,
    pub central_prediction_intervals: Vec<CentralPredictionInterval>,
    pub terminal_vwap_residual: Option<DistributionMoments>,
    pub vwap_residual_change: Option<DistributionMoments>,
    pub jump_diagnostic_active: bool,
    pub jump_affects_moments: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ShortHorizonForecast {
    pub as_of: DateTime<Utc>,
    pub model_fit_as_of: DateTime<Utc>,
    pub forecasts: Vec<HorizonDistributionForecast>,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub warnings: Vec<ShortHorizonReason>,
    pub status: String,
    pub research_policy: String,
}
fn standard_normal_cdf(value: f64) -> f64 {
    // Abramowitz-Stegun 7.1.26. This deterministic approximation is used only
    // for the explicitly uncalibrated Gaussian moment-matched shadow output.
    let absolute = value.abs();
    let scale = 1.0 / (1.0 + 0.231_641_9 * absolute);
    let density = 0.398_942_280_4 * (-0.5 * absolute * absolute).exp();
    let polynomial = scale
        * (0.319_381_530
            + scale
                * (-0.356_563_782
                    + scale * (1.781_477_937 + scale * (-1.821_255_978 + scale * 1.330_274_429))));
    let positive = (1.0 - density * polynomial).clamp(0.0, 1.0);
    if value >= 0.0 {
        positive
    } else {
        1.0 - positive
    }
}

fn gaussian_moment_matched_metadata_valid(method: &str, status: &str, semantics: &str) -> bool {
    method == GAUSSIAN_MOMENT_MATCHED_METHOD
        && status == GAUSSIAN_MOMENT_MATCHED_RESEARCH_STATUS
        && semantics == GAUSSIAN_MOMENT_MATCHED_SEMANTICS
}

fn valid_direction_probabilities(probabilities: &DirectionProbabilities) -> bool {
    probabilities
        .material_move_lower_threshold_log_return
        .is_finite()
        && probabilities
            .material_move_upper_threshold_log_return
            .is_finite()
        && probabilities.material_move_lower_threshold_log_return <= 0.0
        && probabilities.material_move_upper_threshold_log_return >= 0.0
        && probabilities.material_move_lower_threshold_log_return
            <= probabilities.material_move_upper_threshold_log_return
        && valid_probability_vector(
            &[
                probabilities.p_up,
                probabilities.p_flat,
                probabilities.p_down,
            ],
            3,
        )
        && gaussian_moment_matched_metadata_valid(
            &probabilities.method,
            &probabilities.status,
            &probabilities.semantics,
        )
}

fn valid_central_prediction_intervals(intervals: &[CentralPredictionInterval]) -> bool {
    if intervals.len() != CENTRAL_LOG_RETURN_INTERVALS.len() {
        return false;
    }
    for (interval, (expected_mass, _)) in intervals.iter().zip(CENTRAL_LOG_RETURN_INTERVALS) {
        if !interval.probability_mass.is_finite()
            || (interval.probability_mass - expected_mass).abs() > PROBABILITY_TOLERANCE
            || !interval.lower_log_return.is_finite()
            || !interval.upper_log_return.is_finite()
            || interval.lower_log_return > interval.upper_log_return
            || !gaussian_moment_matched_metadata_valid(
                &interval.method,
                &interval.status,
                &interval.semantics,
            )
        {
            return false;
        }
    }
    intervals.windows(2).all(|pair| {
        pair[1].probability_mass > pair[0].probability_mass
            && pair[1].lower_log_return <= pair[0].lower_log_return
            && pair[1].upper_log_return >= pair[0].upper_log_return
    })
}

fn gaussian_moment_matched_outputs(
    moments: &DistributionMoments,
    material_move_lower_threshold_log_return: f64,
    material_move_upper_threshold_log_return: f64,
) -> Option<(DirectionProbabilities, Vec<CentralPredictionInterval>)> {
    if !moments.mean.is_finite()
        || !moments.variance.is_finite()
        || moments.variance < 0.0
        || !moments.standard_deviation.is_finite()
        || moments.standard_deviation < 0.0
        || !material_move_lower_threshold_log_return.is_finite()
        || !material_move_upper_threshold_log_return.is_finite()
        || material_move_lower_threshold_log_return > 0.0
        || material_move_upper_threshold_log_return < 0.0
        || material_move_lower_threshold_log_return > material_move_upper_threshold_log_return
    {
        return None;
    }

    let (p_up, p_flat, p_down) = if moments.standard_deviation == 0.0 {
        if moments.mean < material_move_lower_threshold_log_return {
            (0.0, 0.0, 1.0)
        } else if moments.mean > material_move_upper_threshold_log_return {
            (1.0, 0.0, 0.0)
        } else {
            (0.0, 1.0, 0.0)
        }
    } else {
        let lower_cdf = standard_normal_cdf(
            (material_move_lower_threshold_log_return - moments.mean) / moments.standard_deviation,
        );
        let upper_cdf = standard_normal_cdf(
            (material_move_upper_threshold_log_return - moments.mean) / moments.standard_deviation,
        );
        (
            (1.0 - upper_cdf).clamp(0.0, 1.0),
            (upper_cdf - lower_cdf).clamp(0.0, 1.0),
            lower_cdf.clamp(0.0, 1.0),
        )
    };
    let direction_probabilities = DirectionProbabilities {
        p_up,
        p_flat,
        p_down,
        material_move_lower_threshold_log_return,
        material_move_upper_threshold_log_return,
        method: GAUSSIAN_MOMENT_MATCHED_METHOD.into(),
        status: GAUSSIAN_MOMENT_MATCHED_RESEARCH_STATUS.into(),
        semantics: GAUSSIAN_MOMENT_MATCHED_SEMANTICS.into(),
    };
    let central_prediction_intervals = CENTRAL_LOG_RETURN_INTERVALS
        .iter()
        .map(|(probability_mass, z_score)| CentralPredictionInterval {
            probability_mass: *probability_mass,
            lower_log_return: moments.mean - z_score * moments.standard_deviation,
            upper_log_return: moments.mean + z_score * moments.standard_deviation,
            method: GAUSSIAN_MOMENT_MATCHED_METHOD.into(),
            status: GAUSSIAN_MOMENT_MATCHED_RESEARCH_STATUS.into(),
            semantics: GAUSSIAN_MOMENT_MATCHED_SEMANTICS.into(),
        })
        .collect::<Vec<_>>();

    (valid_direction_probabilities(&direction_probabilities)
        && valid_central_prediction_intervals(&central_prediction_intervals))
    .then_some((direction_probabilities, central_prediction_intervals))
}

fn additive_diffusion_moments(
    model: &RegimeConditionedShortHorizonModel,
    initial_probabilities: &[f64],
    steps: usize,
) -> Option<(Vec<f64>, DistributionMoments)> {
    let states = model.state_count;
    let dt = f64::from(model.base_interval_minutes);
    let mut probabilities = initial_probabilities.to_vec();
    let mut first = vec![0.0; states];
    let mut second = vec![0.0; states];
    for _ in 0..steps {
        let mut next_probability = vec![0.0; states];
        let mut next_first = vec![0.0; states];
        let mut next_second = vec![0.0; states];
        for from in 0..states {
            for to in 0..states {
                let transition = model.transition_matrix[from][to];
                let increment_mean = model.diffusion_states[to].drift_per_minute * dt;
                let increment_variance = model.diffusion_states[to].variance_rate_per_minute * dt;
                next_probability[to] += probabilities[from] * transition;
                next_first[to] += transition * (first[from] + probabilities[from] * increment_mean);
                next_second[to] += transition
                    * (second[from]
                        + 2.0 * increment_mean * first[from]
                        + probabilities[from]
                            * (increment_variance + increment_mean * increment_mean));
            }
        }
        probabilities = next_probability;
        first = next_first;
        second = next_second;
    }
    let mean = first.iter().sum::<f64>();
    let raw_second = second.iter().sum::<f64>();
    finite_moments(mean, raw_second - mean * mean).map(|moments| (probabilities, moments))
}

fn vwap_residual_ou_moments(
    model: &RegimeConditionedShortHorizonModel,
    initial_probabilities: &[f64],
    initial_vwap_residual: f64,
    steps: usize,
) -> Option<(DistributionMoments, DistributionMoments)> {
    if !model.vwap_residual_ou_enabled {
        return None;
    }
    let states = model.state_count;
    let mut probabilities = initial_probabilities.to_vec();
    let mut first = probabilities
        .iter()
        .map(|probability| probability * initial_vwap_residual)
        .collect::<Vec<_>>();
    let mut second = probabilities
        .iter()
        .map(|probability| probability * initial_vwap_residual.powi(2))
        .collect::<Vec<_>>();
    for _ in 0..steps {
        let mut next_probability = vec![0.0; states];
        let mut next_first = vec![0.0; states];
        let mut next_second = vec![0.0; states];
        for from in 0..states {
            for to in 0..states {
                let transition = model.transition_matrix[from][to];
                let parameters = model.vwap_residual_ou_states[to].as_ref()?;
                let intercept = parameters.intercept_per_base_interval;
                let phi = parameters.autoregressive_phi;
                let innovation_variance = parameters.innovation_variance_per_base_interval;
                next_probability[to] += probabilities[from] * transition;
                next_first[to] +=
                    transition * (intercept * probabilities[from] + phi * first[from]);
                next_second[to] += transition
                    * (intercept * intercept * probabilities[from]
                        + 2.0 * intercept * phi * first[from]
                        + phi * phi * second[from]
                        + innovation_variance * probabilities[from]);
            }
        }
        probabilities = next_probability;
        first = next_first;
        second = next_second;
    }
    let mean = first.iter().sum::<f64>();
    let raw_second = second.iter().sum::<f64>();
    let terminal = finite_moments(mean, raw_second - mean * mean)?;
    let change = finite_moments(mean - initial_vwap_residual, terminal.variance)?;
    Some((terminal, change))
}

impl RegimeConditionedShortHorizonModel {
    pub fn forecast_standard_horizons(
        &self,
        request: &ShortHorizonForecastRequest,
    ) -> ShortHorizonForecast {
        let mut rejection_reasons = Vec::new();
        let mut warnings = Vec::new();
        if request.as_of < self.fit_as_of {
            rejection_reasons.push(ShortHorizonReason::ForecastBeforeModelFit);
        }
        if request.latest_input_as_of > request.latest_input_available_at
            || request.latest_input_available_at > request.as_of
            || request.latest_input_as_of > request.as_of
        {
            rejection_reasons.push(ShortHorizonReason::ForecastInputFromFuture);
        }
        if request.regime_probabilities_as_of > request.regime_probabilities_available_at
            || request.regime_probabilities_available_at > request.as_of
            || request.regime_probabilities_as_of > request.as_of
        {
            rejection_reasons.push(ShortHorizonReason::ForecastRegimeFromFuture);
        }
        if !request.current_vwap_residual.is_finite() {
            rejection_reasons.push(ShortHorizonReason::NonFiniteInput);
        }
        if !request.material_move_lower_threshold_log_return.is_finite()
            || !request.material_move_upper_threshold_log_return.is_finite()
            || request.material_move_lower_threshold_log_return > 0.0
            || request.material_move_upper_threshold_log_return < 0.0
            || request.material_move_lower_threshold_log_return
                > request.material_move_upper_threshold_log_return
        {
            rejection_reasons.push(ShortHorizonReason::InvalidMaterialMoveThreshold);
        }
        if request.filtered_regime_probabilities.len() != self.state_count {
            rejection_reasons.push(ShortHorizonReason::RegimeDimensionMismatch);
        } else if !valid_probability_vector(
            &request.filtered_regime_probabilities,
            self.state_count,
        ) {
            rejection_reasons.push(ShortHorizonReason::InvalidRegimeProbability);
        }
        if !self.vwap_residual_ou_enabled {
            warnings.push(ShortHorizonReason::OuModelDisabled);
        }
        warnings.extend(self.jump_diagnostic.rejection_reasons.iter().copied());
        warnings.push(ShortHorizonReason::JumpDiagnosticOnlyNotInForecast);
        if !rejection_reasons.is_empty() {
            return ShortHorizonForecast {
                as_of: request.as_of,
                model_fit_as_of: self.fit_as_of,
                forecasts: Vec::new(),
                rejection_reasons,
                warnings,
                status: "REJECTED".into(),
                research_policy: self.research_policy.clone(),
            };
        }
        let mut forecasts = Vec::with_capacity(STANDARD_HORIZONS_MINUTES.len());
        for horizon_minutes in STANDARD_HORIZONS_MINUTES {
            if horizon_minutes % self.base_interval_minutes != 0 {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::UnsupportedHorizon,
                );
                continue;
            }
            let steps = (horizon_minutes / self.base_interval_minutes) as usize;
            let Some((terminal_state_probabilities, trend_log_return)) =
                additive_diffusion_moments(self, &request.filtered_regime_probabilities, steps)
            else {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::DiffusionVarianceInvalid,
                );
                continue;
            };
            let Some((direction_probabilities, central_prediction_intervals)) =
                gaussian_moment_matched_outputs(
                    &trend_log_return,
                    request.material_move_lower_threshold_log_return,
                    request.material_move_upper_threshold_log_return,
                )
            else {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::GaussianMomentMatchedDistributionInvalid,
                );
                forecasts.clear();
                break;
            };
            let ou = vwap_residual_ou_moments(
                self,
                &request.filtered_regime_probabilities,
                request.current_vwap_residual,
                steps,
            );
            forecasts.push(HorizonDistributionForecast {
                horizon_minutes,
                terminal_state_probabilities,
                trend_log_return,
                direction_probabilities,
                central_prediction_intervals,
                terminal_vwap_residual: ou.as_ref().map(|value| value.0.clone()),
                vwap_residual_change: ou.map(|value| value.1),
                jump_diagnostic_active: self.jump_diagnostic.enabled,
                jump_affects_moments: false,
            });
        }
        warnings.sort();
        warnings.dedup();
        ShortHorizonForecast {
            as_of: request.as_of,
            model_fit_as_of: self.fit_as_of,
            forecasts,
            status: if rejection_reasons.is_empty() {
                "AVAILABLE_RESEARCH_ONLY"
            } else {
                "REJECTED"
            }
            .into(),
            rejection_reasons,
            warnings,
            research_policy: self.research_policy.clone(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MartingaleAuditConfig {
    /// Ville threshold is 1 / alpha for the predeclared mixture e-process.
    pub alpha: f64,
    /// Standardized residuals outside this predeclared bound are rejected,
    /// never clipped, because clipping can destroy the martingale condition.
    pub maximum_absolute_standardized_residual: f64,
    /// Fixed predictable bet fraction. It is not tuned on audit outcomes.
    pub fixed_bet_fraction: f64,
    pub minimum_total_observations: usize,
}

impl Default for MartingaleAuditConfig {
    fn default() -> Self {
        Self {
            alpha: 0.05,
            maximum_absolute_standardized_residual: 8.0,
            fixed_bet_fraction: 0.25,
            minimum_total_observations: 100,
        }
    }
}

impl MartingaleAuditConfig {
    fn valid(&self) -> bool {
        self.alpha.is_finite()
            && self.alpha > 0.0
            && self.alpha < 1.0
            && self.maximum_absolute_standardized_residual.is_finite()
            && self.maximum_absolute_standardized_residual > 0.0
            && self.fixed_bet_fraction.is_finite()
            && self.fixed_bet_fraction > 0.0
            && self.fixed_bet_fraction < 1.0
            && self.minimum_total_observations > 0
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CausalForecastResidual {
    pub session_id: String,
    pub horizon_minutes: u32,
    pub forecast_input_cutoff: DateTime<Utc>,
    pub forecast_as_of: DateTime<Utc>,
    pub forecast_available_at: DateTime<Utc>,
    pub conditional_scale_as_of: DateTime<Utc>,
    pub conditional_scale_available_at: DateTime<Utc>,
    pub predicted_mean: f64,
    pub conditional_scale: f64,
    pub outcome_as_of: DateTime<Utc>,
    pub outcome_available_at: DateTime<Utc>,
    pub realized_value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PhaseStreamAudit {
    pub horizon_minutes: u32,
    pub phase: u32,
    pub observation_count: usize,
    pub standardized_residual_mean: Option<f64>,
    pub positive_bet_e_value: f64,
    pub negative_bet_e_value: f64,
    pub two_sided_mixture_e_value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HorizonMartingaleAudit {
    pub horizon_minutes: u32,
    pub observation_count: usize,
    /// Uniform mixture over all predeclared phase streams for the horizon.
    pub phase_mixture_e_value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MartingaleAudit {
    pub audit_as_of: DateTime<Utc>,
    pub status: String,
    pub veto: bool,
    pub approval_granted: bool,
    pub aggregate_e_value: f64,
    pub veto_threshold: f64,
    pub total_valid_observations: usize,
    pub streams: Vec<PhaseStreamAudit>,
    pub horizons: Vec<HorizonMartingaleAudit>,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub warnings: Vec<ShortHorizonReason>,
    pub veto_reasons: Vec<ShortHorizonReason>,
    pub policy: String,
}

#[derive(Debug, Clone, Copy, Default)]
struct EProcessStream {
    observations: usize,
    standardized_residual_sum: f64,
    log_positive_e: f64,
    log_negative_e: f64,
}

fn log_two_sided_mixture(positive: f64, negative: f64) -> f64 {
    let maximum = positive.max(negative);
    if maximum.is_infinite() && maximum.is_sign_positive() {
        return maximum;
    }
    maximum + ((positive - maximum).exp() + (negative - maximum).exp()).ln() - 2.0_f64.ln()
}

fn log_average(values: &[f64]) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    let maximum = values.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if maximum.is_infinite() && maximum.is_sign_positive() {
        return maximum;
    }
    maximum
        + values
            .iter()
            .map(|value| (*value - maximum).exp())
            .sum::<f64>()
            .ln()
        - (values.len() as f64).ln()
}

fn exp_for_report(log_value: f64) -> f64 {
    if log_value >= f64::MAX.ln() {
        f64::MAX
    } else {
        log_value.exp()
    }
}

fn residual_phase(timestamp: DateTime<Utc>, horizon_minutes: u32) -> u32 {
    timestamp
        .timestamp()
        .div_euclid(60)
        .rem_euclid(i64::from(horizon_minutes)) as u32
}

fn residual_is_causal(
    row: &CausalForecastResidual,
    audit_as_of: DateTime<Utc>,
) -> Result<(), ShortHorizonReason> {
    if row.session_id.is_empty()
        || !row.predicted_mean.is_finite()
        || !row.realized_value.is_finite()
    {
        return Err(ShortHorizonReason::NonFiniteInput);
    }
    if !is_standard_horizon(row.horizon_minutes) {
        return Err(ShortHorizonReason::UnsupportedHorizon);
    }
    if row.forecast_input_cutoff > row.forecast_as_of
        || row.forecast_as_of > row.forecast_available_at
        || row.forecast_available_at > row.outcome_as_of
        || row.conditional_scale_as_of > row.forecast_as_of
        || row.conditional_scale_as_of > row.conditional_scale_available_at
        || row.conditional_scale_available_at > row.forecast_as_of
        || row.forecast_as_of > audit_as_of
    {
        return Err(ShortHorizonReason::ResidualInputNotCausal);
    }
    let earliest_mature_outcome =
        row.forecast_as_of + Duration::minutes(i64::from(row.horizon_minutes));
    if row.outcome_as_of < earliest_mature_outcome
        || row.outcome_as_of > row.outcome_available_at
        || row.outcome_available_at > audit_as_of
    {
        return Err(ShortHorizonReason::ResidualOutcomeNotMature);
    }
    if !row.conditional_scale.is_finite() || row.conditional_scale <= 0.0 {
        return Err(ShortHorizonReason::ResidualScaleInvalid);
    }
    Ok(())
}

/// Audits forecast residuals with a predeclared mixture of bounded,
/// two-sided betting martingales. Overlapping horizons are separated into
/// `horizon_minutes` phase streams. The result can veto; it never approves a
/// model or emits a directional signal.
pub fn audit_residual_martingale(
    residuals: &[CausalForecastResidual],
    audit_as_of: DateTime<Utc>,
    config: &MartingaleAuditConfig,
) -> MartingaleAudit {
    let mut rejection_reasons = Vec::new();
    let mut warnings = Vec::new();
    let mut veto_reasons = Vec::new();
    if !config.valid() {
        rejection_reasons.push(ShortHorizonReason::NonFiniteInput);
    }
    let mut streams = BTreeMap::<(u32, u32), EProcessStream>::new();
    let mut last_outcome = BTreeMap::<(u32, u32), DateTime<Utc>>::new();
    for horizon in STANDARD_HORIZONS_MINUTES {
        for phase in 0..horizon {
            streams.insert((horizon, phase), EProcessStream::default());
        }
    }
    let mut ordered = residuals.to_vec();
    ordered.sort_by_key(|row| (row.forecast_as_of, row.outcome_as_of));
    let mut valid_observations = 0usize;
    if config.valid() {
        for row in &ordered {
            if let Err(reason) = residual_is_causal(row, audit_as_of) {
                push_unique(&mut rejection_reasons, reason);
                continue;
            }
            let phase = residual_phase(row.forecast_as_of, row.horizon_minutes);
            let key = (row.horizon_minutes, phase);
            if last_outcome
                .get(&key)
                .is_some_and(|previous_outcome| row.forecast_as_of < *previous_outcome)
            {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::ResidualPhaseStreamOverlap,
                );
                continue;
            }
            let standardized = (row.realized_value - row.predicted_mean) / row.conditional_scale;
            if !standardized.is_finite() {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::ResidualScaleInvalid,
                );
                continue;
            }
            if standardized.abs() > config.maximum_absolute_standardized_residual {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::ResidualBoundViolation,
                );
                continue;
            }
            let bounded = standardized / config.maximum_absolute_standardized_residual;
            let positive_factor = 1.0 + config.fixed_bet_fraction * bounded;
            let negative_factor = 1.0 - config.fixed_bet_fraction * bounded;
            if positive_factor <= 0.0
                || negative_factor <= 0.0
                || !positive_factor.is_finite()
                || !negative_factor.is_finite()
            {
                push_unique(
                    &mut rejection_reasons,
                    ShortHorizonReason::MartingaleAuditInputInvalid,
                );
                continue;
            }
            if let Some(stream) = streams.get_mut(&key) {
                stream.observations += 1;
                stream.standardized_residual_sum += standardized;
                stream.log_positive_e += positive_factor.ln();
                stream.log_negative_e += negative_factor.ln();
                valid_observations += 1;
                last_outcome.insert(key, row.outcome_as_of);
            }
        }
    }
    let mut stream_rows = Vec::with_capacity(streams.len());
    let mut horizon_rows = Vec::with_capacity(STANDARD_HORIZONS_MINUTES.len());
    let mut horizon_log_mixtures = Vec::with_capacity(STANDARD_HORIZONS_MINUTES.len());
    for horizon in STANDARD_HORIZONS_MINUTES {
        let mut phase_logs = Vec::with_capacity(horizon as usize);
        let mut horizon_observations = 0usize;
        for phase in 0..horizon {
            let stream = streams.get(&(horizon, phase)).copied().unwrap_or_default();
            let mixture_log = log_two_sided_mixture(stream.log_positive_e, stream.log_negative_e);
            phase_logs.push(mixture_log);
            horizon_observations += stream.observations;
            stream_rows.push(PhaseStreamAudit {
                horizon_minutes: horizon,
                phase,
                observation_count: stream.observations,
                standardized_residual_mean: (stream.observations > 0)
                    .then(|| stream.standardized_residual_sum / stream.observations as f64),
                positive_bet_e_value: exp_for_report(stream.log_positive_e),
                negative_bet_e_value: exp_for_report(stream.log_negative_e),
                two_sided_mixture_e_value: exp_for_report(mixture_log),
            });
        }
        let horizon_log = log_average(&phase_logs);
        horizon_log_mixtures.push(horizon_log);
        horizon_rows.push(HorizonMartingaleAudit {
            horizon_minutes: horizon,
            observation_count: horizon_observations,
            phase_mixture_e_value: exp_for_report(horizon_log),
        });
    }
    let aggregate_log = log_average(&horizon_log_mixtures);
    let aggregate_e_value = exp_for_report(aggregate_log);
    let threshold = if config.valid() {
        1.0 / config.alpha
    } else {
        f64::INFINITY
    };
    if valid_observations < config.minimum_total_observations {
        warnings.push(ShortHorizonReason::MartingaleAuditSamplesInsufficient);
    }
    if aggregate_e_value >= threshold {
        veto_reasons.push(ShortHorizonReason::MartingaleEProcessThresholdBreached);
    }
    if !rejection_reasons.is_empty() {
        veto_reasons.push(ShortHorizonReason::MartingaleAuditInputInvalid);
    }
    rejection_reasons.sort();
    rejection_reasons.dedup();
    veto_reasons.sort();
    veto_reasons.dedup();
    let veto = !veto_reasons.is_empty();
    MartingaleAudit {
        audit_as_of,
        status: if veto {
            "VETO"
        } else if valid_observations < config.minimum_total_observations {
            "INSUFFICIENT_DATA_NO_APPROVAL"
        } else {
            "NO_VETO_NOT_APPROVAL"
        }
        .into(),
        veto,
        approval_granted: false,
        aggregate_e_value,
        veto_threshold: threshold,
        total_valid_observations: valid_observations,
        streams: stream_rows,
        horizons: horizon_rows,
        rejection_reasons,
        warnings,
        veto_reasons,
        policy:
            "VETO_ONLY; NULL_REQUIRES_BOUNDED_CONDITIONAL_MEAN_ZERO_RESIDUALS; NO_SIGNAL_OR_APPROVAL"
                .into(),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MomentumValidationEvidence {
    pub as_of: DateTime<Utc>,
    pub independently_validated: bool,
    pub validation_sample_count: usize,
    pub out_of_sample_brier_improvement: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CausalMomentumObservation {
    pub session_id: String,
    pub horizon_minutes: u32,
    pub feature_as_of: DateTime<Utc>,
    pub feature_available_at: DateTime<Utc>,
    pub outcome_as_of: DateTime<Utc>,
    pub outcome_available_at: DateTime<Utc>,
    pub filtered_regime_probabilities: Vec<f64>,
    /// A predeclared signed momentum statistic known at `feature_as_of`.
    pub momentum_score: f64,
    pub realized_log_return: f64,
}

#[derive(Debug, Clone, Copy, Default)]
struct MomentumAccumulator {
    continuation_weight: f64,
    reversal_weight: f64,
    sum_weight: f64,
    sum_squared_weight: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MomentumStateStatistics {
    pub horizon_minutes: u32,
    pub state: usize,
    pub continuation_weight: f64,
    pub reversal_weight: f64,
    pub effective_samples: f64,
    pub posterior_continuation_probability: f64,
    pub posterior_variance: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MomentumHeadModel {
    pub fit_as_of: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub state_count: usize,
    pub non_neutral_observation_count: usize,
    pub statistics: Vec<MomentumStateStatistics>,
    pub neutral_threshold: f64,
    pub minimum_effective_samples: f64,
    /// Eligibility is only for later shadow comparison; this module is not
    /// connected to a production committee.
    pub independently_validated_for_shadow: bool,
    pub validation_reasons: Vec<ShortHorizonReason>,
    pub probability_semantics: String,
    pub research_policy: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MomentumFitResult {
    pub model: Option<MomentumHeadModel>,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub warnings: Vec<ShortHorizonReason>,
}

fn momentum_validation_reasons(
    fit_as_of: DateTime<Utc>,
    evidence: Option<&MomentumValidationEvidence>,
    config: &ShortHorizonConfig,
) -> Vec<ShortHorizonReason> {
    let mut reasons = Vec::new();
    match evidence {
        None => reasons.push(ShortHorizonReason::MomentumHeadUnvalidated),
        Some(value) => {
            if value.as_of > fit_as_of {
                reasons.push(ShortHorizonReason::MomentumValidationEvidenceFromFuture);
            }
            if !value.independently_validated {
                reasons.push(ShortHorizonReason::MomentumHeadUnvalidated);
            }
            if value.validation_sample_count < config.minimum_momentum_validation_samples {
                reasons.push(ShortHorizonReason::MomentumValidationSampleInsufficient);
            }
            if !value.out_of_sample_brier_improvement.is_finite()
                || value.out_of_sample_brier_improvement
                    <= config.minimum_momentum_brier_improvement
            {
                reasons.push(ShortHorizonReason::MomentumValidationNoImprovement);
            }
        }
    }
    reasons
}

fn validate_momentum_observation(
    row: &CausalMomentumObservation,
    fit_as_of: DateTime<Utc>,
    states: usize,
) -> Result<(), ShortHorizonReason> {
    if row.session_id.is_empty()
        || !row.momentum_score.is_finite()
        || !row.realized_log_return.is_finite()
    {
        return Err(ShortHorizonReason::NonFiniteInput);
    }
    if !is_standard_horizon(row.horizon_minutes) {
        return Err(ShortHorizonReason::UnsupportedHorizon);
    }
    if row.filtered_regime_probabilities.len() != states {
        return Err(ShortHorizonReason::RegimeDimensionMismatch);
    }
    if !valid_probability_vector(&row.filtered_regime_probabilities, states) {
        return Err(ShortHorizonReason::InvalidRegimeProbability);
    }
    if row.feature_as_of > row.feature_available_at || row.feature_available_at > row.outcome_as_of
    {
        return Err(ShortHorizonReason::InvalidAsOfOrder);
    }
    let earliest_outcome = row.feature_as_of + Duration::minutes(i64::from(row.horizon_minutes));
    if row.outcome_as_of < earliest_outcome
        || row.outcome_as_of > row.outcome_available_at
        || row.outcome_available_at > fit_as_of
    {
        return Err(ShortHorizonReason::InputAvailableAfterFitAsOf);
    }
    Ok(())
}

/// Fits a posterior-weighted beta-binomial continuation/reversal head. It
/// describes conditional frequencies; it does not produce an order or claim
/// that continuation is profitable after costs.
pub fn fit_momentum_head(
    observations: &[CausalMomentumObservation],
    fit_as_of: DateTime<Utc>,
    validation: Option<&MomentumValidationEvidence>,
    config: &ShortHorizonConfig,
) -> MomentumFitResult {
    let mut rejection_reasons = Vec::new();
    let mut warnings = Vec::new();
    if observations.is_empty() {
        rejection_reasons.push(ShortHorizonReason::EmptyTrainingSet);
        return MomentumFitResult {
            model: None,
            rejection_reasons,
            warnings,
        };
    }
    if !config.valid() {
        rejection_reasons.push(ShortHorizonReason::NonFiniteInput);
        return MomentumFitResult {
            model: None,
            rejection_reasons,
            warnings,
        };
    }
    let states = observations[0].filtered_regime_probabilities.len();
    if states == 0 {
        rejection_reasons.push(ShortHorizonReason::RegimeDimensionMismatch);
        return MomentumFitResult {
            model: None,
            rejection_reasons,
            warnings,
        };
    }
    let mut previous_feature_as_of = None;
    for row in observations {
        if let Err(reason) = validate_momentum_observation(row, fit_as_of, states) {
            push_unique(&mut rejection_reasons, reason);
        }
        if previous_feature_as_of.is_some_and(|previous| row.feature_as_of < previous) {
            push_unique(
                &mut rejection_reasons,
                ShortHorizonReason::ObservationOrderInvalid,
            );
        }
        previous_feature_as_of = Some(row.feature_as_of);
    }
    if !rejection_reasons.is_empty() {
        return MomentumFitResult {
            model: None,
            rejection_reasons,
            warnings,
        };
    }
    let mut accumulators = BTreeMap::<(u32, usize), MomentumAccumulator>::new();
    for horizon in STANDARD_HORIZONS_MINUTES {
        for state in 0..states {
            accumulators.insert((horizon, state), MomentumAccumulator::default());
        }
    }
    let mut non_neutral = 0usize;
    for row in observations {
        if row.momentum_score.abs() <= config.momentum_neutral_threshold
            || row.realized_log_return.abs() <= NUMERIC_FLOOR
        {
            continue;
        }
        non_neutral += 1;
        let continuation = row.momentum_score.signum() == row.realized_log_return.signum();
        for (state, weight) in row
            .filtered_regime_probabilities
            .iter()
            .copied()
            .enumerate()
        {
            if let Some(accumulator) = accumulators.get_mut(&(row.horizon_minutes, state)) {
                accumulator.sum_weight += weight;
                accumulator.sum_squared_weight += weight * weight;
                if continuation {
                    accumulator.continuation_weight += weight;
                } else {
                    accumulator.reversal_weight += weight;
                }
            }
        }
    }
    if non_neutral == 0 {
        rejection_reasons.push(ShortHorizonReason::MomentumSampleInsufficient);
        return MomentumFitResult {
            model: None,
            rejection_reasons,
            warnings,
        };
    }
    let statistics = accumulators
        .into_iter()
        .map(|((horizon_minutes, state), accumulator)| {
            let alpha = config.momentum_beta_prior_alpha + accumulator.continuation_weight;
            let beta = config.momentum_beta_prior_beta + accumulator.reversal_weight;
            let total = alpha + beta;
            MomentumStateStatistics {
                horizon_minutes,
                state,
                continuation_weight: accumulator.continuation_weight,
                reversal_weight: accumulator.reversal_weight,
                effective_samples: effective_sample_size(
                    accumulator.sum_weight,
                    accumulator.sum_squared_weight,
                ),
                posterior_continuation_probability: alpha / total,
                posterior_variance: alpha * beta / (total * total * (total + 1.0)),
            }
        })
        .collect::<Vec<_>>();
    if statistics
        .iter()
        .any(|row| row.effective_samples < config.minimum_momentum_effective_samples)
    {
        warnings.push(ShortHorizonReason::MomentumSampleInsufficient);
    }
    let validation_reasons = momentum_validation_reasons(fit_as_of, validation, config);
    warnings.extend(validation_reasons.iter().copied());
    warnings.sort();
    warnings.dedup();
    MomentumFitResult {
        model: Some(MomentumHeadModel {
            fit_as_of,
            observation_cutoff: observations
                .iter()
                .map(|row| row.outcome_available_at)
                .max()
                .unwrap_or(fit_as_of),
            state_count: states,
            non_neutral_observation_count: non_neutral,
            statistics,
            neutral_threshold: config.momentum_neutral_threshold,
            minimum_effective_samples: config.minimum_momentum_effective_samples,
            independently_validated_for_shadow: validation_reasons.is_empty(),
            validation_reasons,
            probability_semantics:
                "POSTERIOR_WEIGHTED_BETA_BINOMIAL_P_CONTINUATION_GIVEN_FILTERED_REGIME".into(),
            research_policy:
                "RESEARCH_ONLY_SHADOW_LAYER; NO_POSITION_OR_PROFIT_CLAIM; NO_DECISION_AUTHORITY"
                    .into(),
        }),
        rejection_reasons,
        warnings,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MomentumQuery {
    pub as_of: DateTime<Utc>,
    pub input_as_of: DateTime<Utc>,
    pub input_available_at: DateTime<Utc>,
    pub regime_probabilities_as_of: DateTime<Utc>,
    pub regime_probabilities_available_at: DateTime<Utc>,
    pub horizon_minutes: u32,
    pub momentum_score: f64,
    pub filtered_regime_probabilities: Vec<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MomentumHeadOutput {
    pub as_of: DateTime<Utc>,
    pub horizon_minutes: u32,
    pub momentum_direction: Option<i8>,
    pub continuation_probability: Option<f64>,
    pub reversal_probability: Option<f64>,
    pub posterior_standard_deviation: Option<f64>,
    pub effective_samples: f64,
    pub eligible_for_shadow_comparison: bool,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub warnings: Vec<ShortHorizonReason>,
    pub status: String,
    pub research_policy: String,
}

impl MomentumHeadModel {
    pub fn evaluate(&self, query: &MomentumQuery) -> MomentumHeadOutput {
        let mut rejection_reasons = Vec::new();
        let mut warnings = self.validation_reasons.clone();
        if query.as_of < self.fit_as_of {
            rejection_reasons.push(ShortHorizonReason::ForecastBeforeModelFit);
        }
        if query.input_as_of > query.input_available_at || query.input_available_at > query.as_of {
            rejection_reasons.push(ShortHorizonReason::ForecastInputFromFuture);
        }
        if query.regime_probabilities_as_of > query.regime_probabilities_available_at
            || query.regime_probabilities_available_at > query.as_of
        {
            rejection_reasons.push(ShortHorizonReason::ForecastRegimeFromFuture);
        }
        if !is_standard_horizon(query.horizon_minutes) {
            rejection_reasons.push(ShortHorizonReason::UnsupportedHorizon);
        }
        if !query.momentum_score.is_finite() {
            rejection_reasons.push(ShortHorizonReason::NonFiniteInput);
        } else if query.momentum_score.abs() <= self.neutral_threshold {
            rejection_reasons.push(ShortHorizonReason::MomentumScoreNeutral);
        }
        if query.filtered_regime_probabilities.len() != self.state_count {
            rejection_reasons.push(ShortHorizonReason::RegimeDimensionMismatch);
        } else if !valid_probability_vector(&query.filtered_regime_probabilities, self.state_count)
        {
            rejection_reasons.push(ShortHorizonReason::InvalidRegimeProbability);
        }
        if !rejection_reasons.is_empty() {
            return MomentumHeadOutput {
                as_of: query.as_of,
                horizon_minutes: query.horizon_minutes,
                momentum_direction: None,
                continuation_probability: None,
                reversal_probability: None,
                posterior_standard_deviation: None,
                effective_samples: 0.0,
                eligible_for_shadow_comparison: false,
                rejection_reasons,
                warnings,
                status: "REJECTED".into(),
                research_policy: self.research_policy.clone(),
            };
        }
        let mut probability = 0.0;
        let mut second = 0.0;
        let mut inverse_effective = 0.0;
        for state in 0..self.state_count {
            let Some(statistic) = self
                .statistics
                .iter()
                .find(|row| row.horizon_minutes == query.horizon_minutes && row.state == state)
            else {
                rejection_reasons.push(ShortHorizonReason::MomentumSampleInsufficient);
                continue;
            };
            let regime_probability = query.filtered_regime_probabilities[state];
            probability += regime_probability * statistic.posterior_continuation_probability;
            second += regime_probability
                * (statistic.posterior_variance
                    + statistic.posterior_continuation_probability.powi(2));
            if statistic.effective_samples > 0.0 {
                inverse_effective += regime_probability.powi(2) / statistic.effective_samples;
            } else if regime_probability > NUMERIC_FLOOR {
                inverse_effective = f64::INFINITY;
            }
        }
        let effective = if inverse_effective.is_finite() && inverse_effective > 0.0 {
            1.0 / inverse_effective
        } else {
            0.0
        };
        if effective < self.minimum_effective_samples {
            rejection_reasons.push(ShortHorizonReason::MomentumSampleInsufficient);
        }
        let posterior_variance = (second - probability * probability).max(0.0);
        warnings.sort();
        warnings.dedup();
        let eligible = rejection_reasons.is_empty() && self.independently_validated_for_shadow;
        MomentumHeadOutput {
            as_of: query.as_of,
            horizon_minutes: query.horizon_minutes,
            momentum_direction: Some(if query.momentum_score > 0.0 { 1 } else { -1 }),
            continuation_probability: rejection_reasons.is_empty().then_some(probability),
            reversal_probability: rejection_reasons.is_empty().then_some(1.0 - probability),
            posterior_standard_deviation: rejection_reasons
                .is_empty()
                .then_some(posterior_variance.sqrt()),
            effective_samples: effective,
            eligible_for_shadow_comparison: eligible,
            status: if rejection_reasons.is_empty() {
                "AVAILABLE_RESEARCH_ONLY"
            } else {
                "REJECTED"
            }
            .into(),
            rejection_reasons,
            warnings,
            research_policy: self.research_policy.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn timestamp(minute: i64) -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2025, 1, 2, 14, 30, 0)
            .single()
            .unwrap()
            + Duration::minutes(minute)
    }

    fn permissive_config() -> ShortHorizonConfig {
        ShortHorizonConfig {
            minimum_regime_effective_observations: 5.0,
            minimum_transition_weight_per_state: 2.0,
            transition_dirichlet_prior: 0.01,
            diffusion_variance_floor_per_minute: 1.0e-12,
            minimum_ou_effective_pairs: 5.0,
            minimum_ou_phi: 0.001,
            maximum_ou_phi: 0.9999,
            jump_z_threshold: 4.0,
            minimum_jump_events: 3,
            minimum_jump_validation_samples: 10,
            minimum_jump_log_score_improvement: 0.0,
            momentum_neutral_threshold: 1.0e-8,
            momentum_beta_prior_alpha: 1.0,
            momentum_beta_prior_beta: 1.0,
            minimum_momentum_effective_samples: 5.0,
            minimum_momentum_validation_samples: 10,
            minimum_momentum_brier_improvement: 0.0,
        }
    }

    fn mean_reverting_intervals(count: usize, posterior: [f64; 2]) -> Vec<CausalRegimeInterval> {
        let mut residual = 0.7;
        let mut rows = Vec::new();
        for index in 0..count {
            let noise = if index % 2 == 0 { 0.002 } else { -0.002 };
            residual = 0.02 + 0.75 * residual + noise;
            let interval_start = timestamp(index as i64);
            let as_of = interval_start + Duration::minutes(1);
            rows.push(CausalRegimeInterval {
                interval_start,
                as_of,
                available_at: as_of,
                session_id: "2025-01-02".into(),
                log_return: 0.0001 + if index % 2 == 0 { 0.0002 } else { -0.0002 },
                vwap_residual: residual,
                filtered_regime_probabilities: posterior.to_vec(),
                filtered_transition_from_previous: (index > 0).then(|| {
                    vec![
                        vec![posterior[0] * posterior[0], posterior[0] * posterior[1]],
                        vec![posterior[1] * posterior[0], posterior[1] * posterior[1]],
                    ]
                }),
            });
        }
        rows
    }

    fn fitted_model() -> RegimeConditionedShortHorizonModel {
        let rows = mean_reverting_intervals(120, [0.5, 0.5]);
        fit_regime_conditioned_model(&rows, timestamp(130), None, &permissive_config())
            .model
            .unwrap()
    }

    #[test]
    fn fit_rejects_training_data_not_available_as_of_cutoff() {
        let mut rows = mean_reverting_intervals(20, [0.5, 0.5]);
        rows[19].available_at = timestamp(100);
        let result = fit_regime_conditioned_model(&rows, timestamp(30), None, &permissive_config());
        assert!(result.model.is_none());
        assert!(
            result
                .rejection_reasons
                .contains(&ShortHorizonReason::InputAvailableAfterFitAsOf)
        );
    }

    #[test]
    fn fit_estimates_diffusion_transition_and_vwap_residual_ou() {
        let rows = mean_reverting_intervals(160, [0.5, 0.5]);
        let result =
            fit_regime_conditioned_model(&rows, timestamp(170), None, &permissive_config());
        assert!(result.rejection_reasons.is_empty());
        let model = result.model.unwrap();
        assert_eq!(model.state_count, 2);
        assert_eq!(model.diffusion_states.len(), 2);
        assert!(model.vwap_residual_ou_enabled);
        for parameters in model.vwap_residual_ou_states.into_iter().flatten() {
            assert!((parameters.autoregressive_phi - 0.75).abs() < 0.08);
            assert!(parameters.kappa_per_minute > 0.0);
            assert!(parameters.diffusion_variance_rate_per_minute > 0.0);
        }
        assert!(
            result
                .warnings
                .contains(&ShortHorizonReason::JumpModelUnvalidated)
        );
        assert!(!model.jump_diagnostic.affects_forecast_moments);
    }

    #[test]
    fn causal_pair_posteriors_drive_markov_transition_estimate() {
        let mut rows = Vec::new();
        let mut residual = 0.4;
        for index in 0..120 {
            residual = 0.8 * residual + if index % 2 == 0 { 0.01 } else { -0.01 };
            let state = index % 2;
            let previous_state = (index + 1) % 2;
            let mut transition = vec![vec![0.0; 2]; 2];
            if index > 0 {
                transition[previous_state][state] = 1.0;
            }
            let mut probabilities = vec![0.0; 2];
            probabilities[state] = 1.0;
            rows.push(CausalRegimeInterval {
                interval_start: timestamp(index as i64),
                as_of: timestamp(index as i64 + 1),
                available_at: timestamp(index as i64 + 1),
                session_id: "alternating".into(),
                log_return: if state == 0 { -0.001 } else { 0.001 },
                vwap_residual: residual,
                filtered_regime_probabilities: probabilities,
                filtered_transition_from_previous: (index > 0).then_some(transition),
            });
        }
        let model = fit_regime_conditioned_model(&rows, timestamp(130), None, &permissive_config())
            .model
            .unwrap();
        assert!(model.transition_matrix[0][1] > 0.99);
        assert!(model.transition_matrix[1][0] > 0.99);
        assert!(model.transition_matrix[0][0] < 0.01);
        assert!(model.transition_matrix[1][1] < 0.01);
    }

    #[test]
    fn forecast_returns_all_standard_horizons_and_never_adds_jump_moments() {
        let model = fitted_model();
        let request = ShortHorizonForecastRequest {
            as_of: timestamp(140),
            latest_input_as_of: timestamp(140),
            latest_input_available_at: timestamp(140),
            regime_probabilities_as_of: timestamp(140),
            regime_probabilities_available_at: timestamp(140),
            filtered_regime_probabilities: vec![0.5, 0.5],
            current_vwap_residual: 0.25,
            material_move_lower_threshold_log_return: (-0.001_f64).ln_1p(),
            material_move_upper_threshold_log_return: 0.001_f64.ln_1p(),
        };
        let output = model.forecast_standard_horizons(&request);
        assert_eq!(output.status, "AVAILABLE_RESEARCH_ONLY");
        assert_eq!(output.forecasts.len(), 4);
        assert_eq!(
            output
                .forecasts
                .iter()
                .map(|row| row.horizon_minutes)
                .collect::<Vec<_>>(),
            STANDARD_HORIZONS_MINUTES
        );
        assert!(
            output.forecasts[3].trend_log_return.variance
                > output.forecasts[0].trend_log_return.variance
        );
        assert!(
            output
                .forecasts
                .iter()
                .all(|row| row.terminal_vwap_residual.is_some())
        );
        assert!(output.forecasts.iter().all(|row| !row.jump_affects_moments));
        for forecast in &output.forecasts {
            let probabilities = &forecast.direction_probabilities;
            assert!(valid_direction_probabilities(probabilities));
            assert_eq!(
                probabilities.status,
                GAUSSIAN_MOMENT_MATCHED_RESEARCH_STATUS
            );
            assert_eq!(probabilities.method, GAUSSIAN_MOMENT_MATCHED_METHOD);
            assert!(
                probabilities
                    .semantics
                    .contains("NOT_A_CONFIDENCE_GUARANTEE")
            );
            assert!(
                probabilities
                    .semantics
                    .contains("JUMP_COMPONENT_EXCLUDED_FROM_TAILS")
            );
            assert!(
                (probabilities.p_up + probabilities.p_flat + probabilities.p_down - 1.0).abs()
                    <= PROBABILITY_TOLERANCE
            );

            let intervals = &forecast.central_prediction_intervals;
            assert!(valid_central_prediction_intervals(intervals));
            assert_eq!(
                intervals
                    .iter()
                    .map(|interval| interval.probability_mass)
                    .collect::<Vec<_>>(),
                vec![0.80, 0.90, 0.95]
            );
            assert!(intervals.iter().all(|interval| {
                interval.status == GAUSSIAN_MOMENT_MATCHED_RESEARCH_STATUS
                    && interval.method == GAUSSIAN_MOMENT_MATCHED_METHOD
                    && interval.semantics.contains("NOT_A_CONFIDENCE_GUARANTEE")
                    && interval
                        .semantics
                        .contains("JUMP_COMPONENT_EXCLUDED_FROM_TAILS")
            }));
        }
    }

    #[test]
    fn gaussian_output_invariant_guards_reject_non_simplex_and_non_nested_intervals() {
        let moments = DistributionMoments {
            mean: 0.0,
            variance: 0.000_1,
            standard_deviation: 0.01,
        };
        let (mut probabilities, mut intervals) =
            gaussian_moment_matched_outputs(&moments, (-0.001_f64).ln_1p(), 0.001_f64.ln_1p())
                .unwrap();

        probabilities.p_up += 0.1;
        assert!(!valid_direction_probabilities(&probabilities));

        intervals[1].lower_log_return = intervals[0].lower_log_return + 1.0e-6;
        assert!(intervals[1].lower_log_return <= intervals[1].upper_log_return);
        assert!(!valid_central_prediction_intervals(&intervals));
    }

    #[test]
    fn forecast_rejects_future_inputs() {
        let model = fitted_model();
        let request = ShortHorizonForecastRequest {
            as_of: timestamp(140),
            latest_input_as_of: timestamp(141),
            latest_input_available_at: timestamp(141),
            regime_probabilities_as_of: timestamp(140),
            regime_probabilities_available_at: timestamp(140),
            filtered_regime_probabilities: vec![0.5, 0.5],
            current_vwap_residual: 0.0,
            material_move_lower_threshold_log_return: (-0.001_f64).ln_1p(),
            material_move_upper_threshold_log_return: 0.001_f64.ln_1p(),
        };
        let output = model.forecast_standard_horizons(&request);
        assert!(output.forecasts.is_empty());
        assert!(
            output
                .rejection_reasons
                .contains(&ShortHorizonReason::ForecastInputFromFuture)
        );
    }

    #[test]
    fn forecast_rejects_invalid_asymmetric_material_move_thresholds() {
        let model = fitted_model();
        for (lower, upper) in [
            (0.001, 0.002),
            (-0.001, -0.0005),
            (0.001, -0.001),
            (f64::NAN, 0.001),
            (-0.001, f64::INFINITY),
        ] {
            let request = ShortHorizonForecastRequest {
                as_of: timestamp(140),
                latest_input_as_of: timestamp(140),
                latest_input_available_at: timestamp(140),
                regime_probabilities_as_of: timestamp(140),
                regime_probabilities_available_at: timestamp(140),
                filtered_regime_probabilities: vec![0.5, 0.5],
                current_vwap_residual: 0.0,
                material_move_lower_threshold_log_return: lower,
                material_move_upper_threshold_log_return: upper,
            };
            let output = model.forecast_standard_horizons(&request);
            assert_eq!(output.status, "REJECTED");
            assert!(output.forecasts.is_empty());
            assert!(
                output
                    .rejection_reasons
                    .contains(&ShortHorizonReason::InvalidMaterialMoveThreshold)
            );
        }
    }

    #[test]
    fn asymmetric_log_thresholds_match_symmetric_simple_return_cost_band() {
        let cost_return: f64 = 0.10;
        let lower = (-cost_return).ln_1p();
        let upper = cost_return.ln_1p();
        assert!(lower < -upper);

        let zero_variance = |mean| DistributionMoments {
            mean,
            variance: 0.0,
            standard_deviation: 0.0,
        };
        let (down, _) =
            gaussian_moment_matched_outputs(&zero_variance(lower - 1.0e-6), lower, upper).unwrap();
        let (flat, _) = gaussian_moment_matched_outputs(&zero_variance(0.0), lower, upper).unwrap();
        let (up, _) =
            gaussian_moment_matched_outputs(&zero_variance(upper + 1.0e-6), lower, upper).unwrap();
        assert_eq!((down.p_up, down.p_flat, down.p_down), (0.0, 0.0, 1.0));
        assert_eq!((flat.p_up, flat.p_flat, flat.p_down), (0.0, 1.0, 0.0));
        assert_eq!((up.p_up, up.p_flat, up.p_down), (1.0, 0.0, 0.0));
    }

    #[test]
    fn jump_diagnostic_requires_both_oos_evidence_and_events() {
        let mut rows = mean_reverting_intervals(160, [0.5, 0.5]);
        for index in [20usize, 50, 80, 110, 140] {
            rows[index].log_return = if index % 2 == 0 { 0.08 } else { -0.08 };
        }
        let evidence = JumpValidationEvidence {
            as_of: timestamp(165),
            independently_validated: true,
            validation_sample_count: 500,
            out_of_sample_log_score_improvement: 0.01,
        };
        let model = fit_regime_conditioned_model(
            &rows,
            timestamp(170),
            Some(&evidence),
            &permissive_config(),
        )
        .model
        .unwrap();
        assert!(model.jump_diagnostic.hard_event_count >= 3);
        assert!(model.jump_diagnostic.enabled);
        assert!(!model.jump_diagnostic.affects_forecast_moments);

        let without_evidence =
            fit_regime_conditioned_model(&rows, timestamp(170), None, &permissive_config())
                .model
                .unwrap();
        assert!(!without_evidence.jump_diagnostic.enabled);
        assert!(
            without_evidence
                .jump_diagnostic
                .rejection_reasons
                .contains(&ShortHorizonReason::JumpModelUnvalidated)
        );
    }

    #[test]
    fn future_jump_validation_evidence_is_disabled() {
        let rows = mean_reverting_intervals(120, [0.5, 0.5]);
        let evidence = JumpValidationEvidence {
            as_of: timestamp(999),
            independently_validated: true,
            validation_sample_count: 500,
            out_of_sample_log_score_improvement: 1.0,
        };
        let model = fit_regime_conditioned_model(
            &rows,
            timestamp(130),
            Some(&evidence),
            &permissive_config(),
        )
        .model
        .unwrap();
        assert!(!model.jump_diagnostic.enabled);
        assert!(
            model
                .jump_diagnostic
                .rejection_reasons
                .contains(&ShortHorizonReason::JumpValidationEvidenceFromFuture)
        );
    }

    fn residual(
        forecast_minute: i64,
        horizon_minutes: u32,
        standardized_residual: f64,
    ) -> CausalForecastResidual {
        let forecast_as_of = timestamp(forecast_minute);
        let outcome_as_of = forecast_as_of + Duration::minutes(i64::from(horizon_minutes));
        CausalForecastResidual {
            session_id: "audit".into(),
            horizon_minutes,
            forecast_input_cutoff: forecast_as_of,
            forecast_as_of,
            forecast_available_at: forecast_as_of,
            conditional_scale_as_of: forecast_as_of,
            conditional_scale_available_at: forecast_as_of,
            predicted_mean: 0.0,
            conditional_scale: 1.0,
            outcome_as_of,
            outcome_available_at: outcome_as_of,
            realized_value: standardized_residual,
        }
    }

    #[test]
    fn phase_stream_martingale_audit_is_veto_only_and_accepts_zero_residuals() {
        let residuals = (0..120)
            .map(|index| residual(index * 5, 5, 0.0))
            .collect::<Vec<_>>();
        let config = MartingaleAuditConfig {
            minimum_total_observations: 20,
            ..MartingaleAuditConfig::default()
        };
        let audit = audit_residual_martingale(&residuals, timestamp(700), &config);
        assert!(!audit.veto);
        assert!(!audit.approval_granted);
        assert_eq!(audit.status, "NO_VETO_NOT_APPROVAL");
        assert_eq!(audit.total_valid_observations, 120);
        assert!((audit.aggregate_e_value - 1.0).abs() < 1.0e-10);
        assert_eq!(
            audit.streams.len(),
            STANDARD_HORIZONS_MINUTES.iter().sum::<u32>() as usize
        );
    }

    #[test]
    fn persistent_one_sided_residuals_trigger_e_process_veto() {
        let residuals = (0..80)
            .map(|index| residual(index * 5, 5, 8.0))
            .collect::<Vec<_>>();
        let config = MartingaleAuditConfig {
            fixed_bet_fraction: 0.5,
            minimum_total_observations: 10,
            ..MartingaleAuditConfig::default()
        };
        let audit = audit_residual_martingale(&residuals, timestamp(500), &config);
        assert!(audit.veto);
        assert!(!audit.approval_granted);
        assert!(
            audit
                .veto_reasons
                .contains(&ShortHorizonReason::MartingaleEProcessThresholdBreached)
        );
        assert!(audit.aggregate_e_value >= audit.veto_threshold);
    }

    #[test]
    fn residual_bound_violation_fails_closed_without_clipping() {
        let audit = audit_residual_martingale(
            &[residual(0, 5, 9.0)],
            timestamp(20),
            &MartingaleAuditConfig::default(),
        );
        assert!(audit.veto);
        assert!(
            audit
                .rejection_reasons
                .contains(&ShortHorizonReason::ResidualBoundViolation)
        );
        assert_eq!(audit.total_valid_observations, 0);
    }

    #[test]
    fn phase_stream_overlap_is_rejected() {
        let first = residual(0, 5, 0.0);
        let mut second = residual(5, 5, 0.0);
        second.outcome_as_of = timestamp(15);
        second.outcome_available_at = timestamp(15);
        let audit = audit_residual_martingale(
            &[first, second],
            timestamp(20),
            &MartingaleAuditConfig::default(),
        );
        // The first outcome is at minute 5, so the second interval touches it
        // and is valid. Make the first label span past the second forecast.
        assert!(
            !audit
                .rejection_reasons
                .contains(&ShortHorizonReason::ResidualPhaseStreamOverlap)
        );

        let mut long_first = residual(0, 5, 0.0);
        long_first.outcome_as_of = timestamp(10);
        long_first.outcome_available_at = timestamp(10);
        let overlapping = audit_residual_martingale(
            &[long_first, residual(5, 5, 0.0)],
            timestamp(20),
            &MartingaleAuditConfig::default(),
        );
        assert!(overlapping.veto);
        assert!(
            overlapping
                .rejection_reasons
                .contains(&ShortHorizonReason::ResidualPhaseStreamOverlap)
        );
    }

    fn momentum_rows() -> Vec<CausalMomentumObservation> {
        let mut rows = Vec::new();
        for index in 0..200 {
            let state = usize::from(index >= 100);
            let continuation = if state == 0 {
                index % 10 != 0
            } else {
                index % 5 == 0
            };
            let mut probabilities = vec![0.0; 2];
            probabilities[state] = 1.0;
            let feature_as_of = timestamp(index as i64);
            let outcome_as_of = feature_as_of + Duration::minutes(5);
            rows.push(CausalMomentumObservation {
                session_id: "momentum".into(),
                horizon_minutes: 5,
                feature_as_of,
                feature_available_at: feature_as_of,
                outcome_as_of,
                outcome_available_at: outcome_as_of,
                filtered_regime_probabilities: probabilities,
                momentum_score: 1.0,
                realized_log_return: if continuation { 0.001 } else { -0.001 },
            });
        }
        rows
    }

    #[test]
    fn momentum_head_learns_regime_conditioned_continuation_and_reversal() {
        let rows = momentum_rows();
        let validation = MomentumValidationEvidence {
            as_of: timestamp(210),
            independently_validated: true,
            validation_sample_count: 500,
            out_of_sample_brier_improvement: 0.01,
        };
        let model = fit_momentum_head(
            &rows,
            timestamp(220),
            Some(&validation),
            &permissive_config(),
        )
        .model
        .unwrap();
        assert!(model.independently_validated_for_shadow);
        let query = MomentumQuery {
            as_of: timestamp(230),
            input_as_of: timestamp(230),
            input_available_at: timestamp(230),
            regime_probabilities_as_of: timestamp(230),
            regime_probabilities_available_at: timestamp(230),
            horizon_minutes: 5,
            momentum_score: 1.0,
            filtered_regime_probabilities: vec![1.0, 0.0],
        };
        let continuation = model.evaluate(&query);
        assert_eq!(continuation.status, "AVAILABLE_RESEARCH_ONLY");
        assert!(continuation.eligible_for_shadow_comparison);
        assert!(
            continuation
                .continuation_probability
                .is_some_and(|value| value > 0.85)
        );

        let reversal = model.evaluate(&MomentumQuery {
            filtered_regime_probabilities: vec![0.0, 1.0],
            ..query
        });
        assert!(
            reversal
                .reversal_probability
                .is_some_and(|value| value > 0.70)
        );
    }

    #[test]
    fn momentum_head_rejects_neutral_query_and_future_training_label() {
        let rows = momentum_rows();
        let model = fit_momentum_head(&rows, timestamp(220), None, &permissive_config())
            .model
            .unwrap();
        let neutral = model.evaluate(&MomentumQuery {
            as_of: timestamp(230),
            input_as_of: timestamp(230),
            input_available_at: timestamp(230),
            regime_probabilities_as_of: timestamp(230),
            regime_probabilities_available_at: timestamp(230),
            horizon_minutes: 5,
            momentum_score: 0.0,
            filtered_regime_probabilities: vec![1.0, 0.0],
        });
        assert!(
            neutral
                .rejection_reasons
                .contains(&ShortHorizonReason::MomentumScoreNeutral)
        );
        assert!(!neutral.eligible_for_shadow_comparison);

        let mut future_rows = rows;
        future_rows[199].outcome_available_at = timestamp(999);
        let fit = fit_momentum_head(&future_rows, timestamp(220), None, &permissive_config());
        assert!(fit.model.is_none());
        assert!(
            fit.rejection_reasons
                .contains(&ShortHorizonReason::InputAvailableAfterFitAsOf)
        );
    }

    #[test]
    fn public_models_are_serde_round_trip_safe() {
        let model = fitted_model();
        let encoded = serde_json::to_string(&model).unwrap();
        let decoded: RegimeConditionedShortHorizonModel = serde_json::from_str(&encoded).unwrap();
        assert_eq!(decoded.fit_as_of, model.fit_as_of);
        assert_eq!(decoded.state_count, model.state_count);
        assert_eq!(decoded.transition_matrix, model.transition_matrix);
        assert!(
            (decoded.diffusion_states[0].variance_rate_per_minute
                - model.diffusion_states[0].variance_rate_per_minute)
                .abs()
                < 1.0e-20
        );
        assert_eq!(
            decoded.jump_diagnostic.rejection_reasons,
            model.jump_diagnostic.rejection_reasons
        );

        let audit = audit_residual_martingale(
            &[residual(0, 5, 0.0)],
            timestamp(20),
            &MartingaleAuditConfig::default(),
        );
        let encoded = serde_json::to_string(&audit).unwrap();
        let decoded: MartingaleAudit = serde_json::from_str(&encoded).unwrap();
        assert_eq!(decoded, audit);
    }
}
