use std::collections::{BTreeMap, HashMap};

use anyhow::{Result, bail};
use chrono::{DateTime, Datelike, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::domain::{MarketState, Outcome};

const FEATURE_NAMES: [&str; 12] = [
    "ret_1m",
    "ret_5m",
    "ret_15m",
    "vwap_distance",
    "realized_volatility",
    "normalized_range",
    "volume_zscore",
    "rvol",
    "session_range_position",
    "cross_asset_breadth",
    "slope_15m",
    "minute_of_session",
];

fn features(state: &MarketState) -> Vec<f64> {
    vec![
        state.ret_1m,
        state.ret_5m,
        state.ret_15m,
        state.dist_vwap,
        state.rolling_realized_vol,
        state.normalized_range,
        state.volume_zscore,
        state.rvol_same_minute,
        state.session_range_position,
        state.cross_asset_breadth_score,
        state.slope_15m,
        state.minutes_from_open as f64 / 390.0,
    ]
}

fn absolute_pearson(pairs: &[(f64, f64)]) -> Option<f64> {
    if pairs.len() < 3
        || pairs
            .iter()
            .any(|(left, right)| !left.is_finite() || !right.is_finite())
    {
        return None;
    }
    let count = pairs.len() as f64;
    let left_mean = pairs.iter().map(|row| row.0).sum::<f64>() / count;
    let right_mean = pairs.iter().map(|row| row.1).sum::<f64>() / count;
    let covariance = pairs
        .iter()
        .map(|row| (row.0 - left_mean) * (row.1 - right_mean))
        .sum::<f64>();
    let left_variance = pairs
        .iter()
        .map(|row| (row.0 - left_mean).powi(2))
        .sum::<f64>();
    let right_variance = pairs
        .iter()
        .map(|row| (row.1 - right_mean).powi(2))
        .sum::<f64>();
    let denominator = (left_variance * right_variance).sqrt();
    (denominator > 1.0e-12).then_some((covariance / denominator).abs().clamp(0.0, 1.0))
}

fn path_features(state: &MarketState) -> Vec<f64> {
    vec![
        state.ret_1m,
        state.ret_3m,
        state.ret_5m,
        state.ret_15m,
        state.ret_30m,
        state.ret_60m,
    ]
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DistanceMetric {
    StandardizedEuclidean,
    ShrinkageMahalanobis,
    Correlation,
    DynamicTimeWarping,
    RegularizedMetricLearning,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum BandwidthRule {
    AdaptiveKthNeighbor,
    NearestNeighbor,
    Fixed(f64),
}

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum RegimeMatchPolicy {
    /// Compare the full posterior only. Retained as a research baseline.
    PosteriorCosine,
    /// Require the same raw dominant hidden state and a similar full
    /// posterior. This is the fail-closed production research policy.
    #[default]
    SameDominantAndPosteriorCosine,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AnalogEngineConfig {
    pub metric: DistanceMetric,
    pub neighbors: usize,
    pub bandwidth_rule: BandwidthRule,
    pub bandwidth_multiplier: f64,
    pub same_time_bucket: bool,
    pub regime_conditioned: bool,
    #[serde(default)]
    pub regime_match_policy: RegimeMatchPolicy,
    pub minimum_regime_similarity: f64,
    #[serde(default = "default_minimum_dominant_regime_probability")]
    pub minimum_dominant_regime_probability: f64,
    pub minimum_effective_sample_size: f64,
    pub maximum_dimensions: usize,
    pub covariance_shrinkage: f64,
    pub ood_quantile: f64,
    pub sensitivity_k: Vec<usize>,
    pub sensitivity_bandwidth: Vec<f64>,
}

fn default_minimum_dominant_regime_probability() -> f64 {
    0.50
}

impl Default for AnalogEngineConfig {
    fn default() -> Self {
        Self {
            metric: DistanceMetric::ShrinkageMahalanobis,
            neighbors: 50,
            bandwidth_rule: BandwidthRule::AdaptiveKthNeighbor,
            bandwidth_multiplier: 1.0,
            same_time_bucket: true,
            regime_conditioned: true,
            regime_match_policy: RegimeMatchPolicy::SameDominantAndPosteriorCosine,
            minimum_regime_similarity: 0.90,
            minimum_dominant_regime_probability: default_minimum_dominant_regime_probability(),
            minimum_effective_sample_size: 20.0,
            maximum_dimensions: 12,
            covariance_shrinkage: 0.20,
            ood_quantile: 0.95,
            sensitivity_k: vec![20, 35, 50, 75],
            sensitivity_bandwidth: vec![0.5, 0.75, 1.0, 1.5, 2.0],
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FeatureSimilarity {
    pub feature: String,
    pub query_value: f64,
    pub analog_value: f64,
    pub standardized_difference: f64,
    pub similarity: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RetrievedAnalog {
    pub rank: usize,
    pub snapshot_id: String,
    pub analog_timestamp: DateTime<Utc>,
    pub session_date: NaiveDate,
    pub distance: f64,
    pub weight: f64,
    pub regime_similarity: Option<f64>,
    pub feature_similarity: Vec<FeatureSimilarity>,
    pub subsequent_realized_path: Vec<f64>,
    pub terminal_return: f64,
    pub maximum_favorable_excursion: f64,
    pub maximum_adverse_excursion: f64,
    pub label_available_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AnalogDistribution {
    pub kernel_weighted_mean: f64,
    pub locally_weighted_linear_intercept: f64,
    pub weighted_quantiles: BTreeMap<String, f64>,
    pub probability_up: f64,
    pub tail_probability: f64,
    pub average_mfe: f64,
    pub average_mae: f64,
    pub dispersion: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SensitivityPoint {
    pub neighbors: usize,
    pub bandwidth_multiplier: f64,
    pub expected_return: f64,
    pub probability_up: f64,
    pub effective_sample_size: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AnalogDiagnostics {
    pub nearest_neighbor_distance: f64,
    pub ood_distance_threshold: f64,
    pub out_of_distribution_score: f64,
    pub distance_concentration: f64,
    pub effective_sample_size: f64,
    pub analog_age_days_mean: f64,
    pub analog_age_days_quantiles: BTreeMap<String, f64>,
    pub maximum_year_weight: f64,
    pub dominant_year: Option<i32>,
    pub highly_overlapping_neighbors: bool,
    pub selected_dimensions: Vec<String>,
    pub scaler_fit_period_end: DateTime<Utc>,
    pub metric_weights_fit_on_train_only: bool,
    pub sensitivity: Vec<SensitivityPoint>,
    /// Machine-readable description of the rule that produced `bandwidth`.
    #[serde(default)]
    pub bandwidth_rule: String,
    /// The unmultiplied distance/value selected by `bandwidth_rule`.
    #[serde(default)]
    pub bandwidth_reference_distance: f64,
    /// Records whether the requested covariance inverse was used or whether
    /// the engine failed closed to the standardized-Euclidean identity.
    #[serde(default)]
    pub covariance_inverse_status: String,
    #[serde(default)]
    pub same_day_neighbor_count: usize,
    #[serde(default)]
    pub unique_session_day_count: usize,
    /// Regularized metric learning is horizon-specific. `None` means that
    /// the selected distance does not use supervised metric weights.
    #[serde(default)]
    pub metric_fit_horizon_minutes: Option<usize>,
    #[serde(default)]
    pub metric_training_label_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AnalogForecast {
    pub query_snapshot_id: String,
    pub decision_as_of: DateTime<Utc>,
    pub horizon_minutes: usize,
    pub metric: DistanceMetric,
    pub bandwidth: f64,
    pub top_analogs: Vec<RetrievedAnalog>,
    pub distribution: Option<AnalogDistribution>,
    pub diagnostics: Option<AnalogDiagnostics>,
    pub status: String,
    pub no_trade_reasons: Vec<String>,
    pub supported_method_comparison: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalogEngine {
    config: AnalogEngineConfig,
    train_indices: Vec<usize>,
    center: Vec<f64>,
    scale: Vec<f64>,
    inverse_covariance: Vec<Vec<f64>>,
    learned_metric_weights: Vec<f64>,
    ood_distance_threshold: f64,
    train_end: DateTime<Utc>,
    #[serde(default)]
    covariance_inverse_status: String,
    #[serde(default)]
    metric_fit_horizon_minutes: Option<usize>,
    #[serde(default)]
    metric_training_label_count: usize,
}

fn quantile(values: &[f64], probability: f64) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(f64::total_cmp);
    let location = probability.clamp(0.0, 1.0) * (sorted.len() - 1) as f64;
    let left = location.floor() as usize;
    let right = location.ceil() as usize;
    let fraction = location - left as f64;
    sorted[left] * (1.0 - fraction) + sorted[right] * fraction
}

fn weighted_quantile(values: &[(f64, f64)], probability: f64) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(|left, right| left.0.total_cmp(&right.0));
    let total = sorted.iter().map(|row| row.1).sum::<f64>().max(1.0e-12);
    let target = probability.clamp(0.0, 1.0) * total;
    let mut cumulative = 0.0;
    for (value, weight) in &sorted {
        cumulative += *weight;
        if cumulative >= target {
            return *value;
        }
    }
    sorted.last().map(|row| row.0).unwrap_or_default()
}

fn normalize_path(values: &[f64]) -> Vec<f64> {
    if values.is_empty() {
        return Vec::new();
    }
    let mean = values.iter().sum::<f64>() / values.len() as f64;
    let variance = values
        .iter()
        .map(|value| (value - mean).powi(2))
        .sum::<f64>()
        / values.len() as f64;
    let scale = variance.sqrt().max(1.0e-12);
    values.iter().map(|value| (value - mean) / scale).collect()
}

fn dtw(left: &[f64], right: &[f64]) -> f64 {
    let left = normalize_path(left);
    let right = normalize_path(right);
    let mut costs = vec![vec![f64::INFINITY; right.len() + 1]; left.len() + 1];
    costs[0][0] = 0.0;
    for i in 1..=left.len() {
        for j in 1..=right.len() {
            let cost = (left[i - 1] - right[j - 1]).abs();
            costs[i][j] = cost
                + costs[i - 1][j]
                    .min(costs[i][j - 1])
                    .min(costs[i - 1][j - 1]);
        }
    }
    costs[left.len()][right.len()] / left.len().max(right.len()).max(1) as f64
}

fn correlation_distance(left: &[f64], right: &[f64]) -> f64 {
    let left = normalize_path(left);
    let right = normalize_path(right);
    if left.is_empty() || left.len() != right.len() {
        return f64::INFINITY;
    }
    let correlation = left.iter().zip(&right).map(|(a, b)| a * b).sum::<f64>() / left.len() as f64;
    (1.0 - correlation).clamp(0.0, 2.0)
}

fn invert_matrix(mut matrix: Vec<Vec<f64>>) -> Option<Vec<Vec<f64>>> {
    let size = matrix.len();
    if size == 0
        || matrix
            .iter()
            .any(|row| row.len() != size || row.iter().any(|value| !value.is_finite()))
    {
        return None;
    }
    let mut inverse = vec![vec![0.0; size]; size];
    for (index, row) in inverse.iter_mut().enumerate() {
        row[index] = 1.0;
    }
    for column in 0..size {
        let pivot = (column..size)
            .max_by(|left, right| {
                matrix[*left][column]
                    .abs()
                    .total_cmp(&matrix[*right][column].abs())
            })
            .unwrap_or(column);
        if pivot != column {
            matrix.swap(pivot, column);
            inverse.swap(pivot, column);
        }
        let divisor = matrix[column][column];
        if !divisor.is_finite() || divisor.abs() < 1.0e-12 {
            return None;
        }
        for col in 0..size {
            matrix[column][col] /= divisor;
            inverse[column][col] /= divisor;
        }
        for row in 0..size {
            if row == column {
                continue;
            }
            let factor = matrix[row][column];
            for col in 0..size {
                matrix[row][col] -= factor * matrix[column][col];
                inverse[row][col] -= factor * inverse[column][col];
            }
        }
    }
    inverse
        .iter()
        .all(|row| row.iter().all(|value| value.is_finite()))
        .then_some(inverse)
}

fn snapshot_id(state: &MarketState) -> String {
    let value = format!(
        "{}:{}:market_snapshot_v1",
        state.symbol,
        state.timestamp.to_rfc3339()
    );
    format!("snap_{:x}", Sha256::digest(value.as_bytes()))[..29].to_string()
}

fn cosine(left: &[f64], right: &[f64]) -> Option<f64> {
    if left.len() != right.len()
        || left.is_empty()
        || left.iter().chain(right).any(|value| !value.is_finite())
    {
        return None;
    }
    let dot = left.iter().zip(right).map(|(a, b)| a * b).sum::<f64>();
    let norm_left = left.iter().map(|value| value * value).sum::<f64>().sqrt();
    let norm_right = right.iter().map(|value| value * value).sum::<f64>().sqrt();
    (norm_left > 0.0 && norm_right > 0.0)
        .then_some((dot / (norm_left * norm_right)).clamp(-1.0, 1.0))
}

fn valid_probability_vector(values: &[f64], expected_dimensions: Option<usize>) -> bool {
    if values.is_empty()
        || expected_dimensions.is_some_and(|dimensions| values.len() != dimensions)
        || values
            .iter()
            .any(|value| !value.is_finite() || *value < 0.0 || *value > 1.0)
    {
        return false;
    }
    let total = values.iter().sum::<f64>();
    total.is_finite() && (total - 1.0).abs() <= 1.0e-6
}

fn dominant_probability(values: &[f64]) -> Option<(usize, f64)> {
    values
        .iter()
        .copied()
        .enumerate()
        .max_by(|left, right| left.1.total_cmp(&right.1))
}

fn valid_state_features(state: &MarketState, dimensions: usize, metric: DistanceMetric) -> bool {
    let values = features(state);
    dimensions > 0
        && dimensions <= values.len()
        && values[..dimensions].iter().all(|value| value.is_finite())
        && (!matches!(
            metric,
            DistanceMetric::Correlation | DistanceMetric::DynamicTimeWarping
        ) || path_features(state).iter().all(|value| value.is_finite()))
}

fn valid_config(config: &AnalogEngineConfig) -> bool {
    config.neighbors > 0
        && (1..=FEATURE_NAMES.len()).contains(&config.maximum_dimensions)
        && config.bandwidth_multiplier.is_finite()
        && config.bandwidth_multiplier > 0.0
        && config.minimum_regime_similarity.is_finite()
        && (-1.0..=1.0).contains(&config.minimum_regime_similarity)
        && config.minimum_dominant_regime_probability.is_finite()
        && (0.0..=1.0).contains(&config.minimum_dominant_regime_probability)
        && config.minimum_effective_sample_size.is_finite()
        && config.minimum_effective_sample_size >= 0.0
        && config.covariance_shrinkage.is_finite()
        && (0.0..=1.0).contains(&config.covariance_shrinkage)
        && config.ood_quantile.is_finite()
        && config.ood_quantile > 0.0
        && config.ood_quantile <= 1.0
        && config.sensitivity_k.iter().all(|neighbors| *neighbors > 0)
        && config
            .sensitivity_bandwidth
            .iter()
            .all(|value| value.is_finite() && *value > 0.0)
        && match config.bandwidth_rule {
            BandwidthRule::Fixed(value) => value.is_finite() && value > 0.0,
            _ => true,
        }
}

fn valid_outcome_values(outcome: &Outcome) -> bool {
    outcome.horizon_minutes > 0
        && outcome.directional_return.is_finite()
        && outcome.mfe.is_finite()
        && outcome.mae.is_finite()
        && outcome.mfe >= 0.0
        && outcome.mae >= 0.0
}

#[derive(Debug)]
struct RealizedPath {
    returns: Vec<f64>,
    label_available_at: DateTime<Utc>,
}

#[derive(Debug)]
struct StateTimeline {
    by_symbol: HashMap<String, Vec<usize>>,
}

impl StateTimeline {
    fn build(states: &[MarketState]) -> Option<Self> {
        let mut by_symbol = HashMap::<String, Vec<usize>>::new();
        for (index, state) in states.iter().enumerate() {
            by_symbol
                .entry(state.symbol.clone())
                .or_default()
                .push(index);
        }
        for indices in by_symbol.values_mut() {
            indices.sort_by_key(|index| states[*index].timestamp);
            if indices
                .windows(2)
                .any(|pair| states[pair[0]].timestamp >= states[pair[1]].timestamp)
            {
                return None;
            }
        }
        Some(Self { by_symbol })
    }

    fn realized_path(
        &self,
        states: &[MarketState],
        candidate_index: usize,
        outcome: &Outcome,
    ) -> Option<RealizedPath> {
        let candidate = states.get(candidate_index)?;
        if outcome.state_index != candidate_index
            || !valid_outcome_values(outcome)
            || outcome.entry_timestamp != candidate.timestamp + chrono::Duration::minutes(1)
        {
            return None;
        }
        let indices = self.by_symbol.get(&candidate.symbol)?;
        let position = indices
            .binary_search_by_key(&outcome.entry_timestamp, |index| states[*index].timestamp)
            .ok()?;
        let end = position.checked_add(outcome.horizon_minutes)?;
        let window = indices.get(position..end)?;
        if window.len() != outcome.horizon_minutes
            || window.iter().any(|index| {
                let state = &states[*index];
                state.session_date != candidate.session_date
                    || state.symbol != candidate.symbol
                    || !state.open.is_finite()
                    || !state.high.is_finite()
                    || !state.low.is_finite()
                    || !state.close.is_finite()
                    || state.open <= 0.0
                    || state.high <= 0.0
                    || state.low <= 0.0
                    || state.close <= 0.0
            })
            || window.windows(2).any(|pair| {
                states[pair[1]].timestamp - states[pair[0]].timestamp
                    != chrono::Duration::minutes(1)
            })
        {
            return None;
        }
        let entry = states[*window.first()?].open;
        let returns = window
            .iter()
            .map(|index| states[*index].close / entry - 1.0)
            .collect::<Vec<_>>();
        if returns.iter().any(|value| !value.is_finite()) {
            return None;
        }
        let computed_terminal = *returns.last()?;
        let computed_mfe = window
            .iter()
            .map(|index| states[*index].high / entry - 1.0)
            .fold(f64::NEG_INFINITY, f64::max);
        let computed_mae = -window
            .iter()
            .map(|index| states[*index].low / entry - 1.0)
            .fold(f64::INFINITY, f64::min)
            .min(0.0);
        let close_enough = |left: f64, right: f64| {
            (left - right).abs() <= 1.0e-9_f64.max(left.abs().max(right.abs()) * 1.0e-7)
        };
        if !close_enough(computed_terminal, outcome.directional_return)
            || !close_enough(computed_mfe, outcome.mfe)
            || !close_enough(computed_mae, outcome.mae)
        {
            return None;
        }
        Some(RealizedPath {
            returns,
            // Timestamps identify minute-bar starts in the engine. The final
            // close becomes usable only after that bar has completed.
            label_available_at: states[*window.last()?].timestamp + chrono::Duration::minutes(1),
        })
    }
}

#[derive(Debug)]
struct Candidate<'a> {
    state_index: usize,
    outcome: &'a Outcome,
    distance: f64,
    regime_similarity: Option<f64>,
    subsequent_path: Vec<f64>,
    label_available_at: DateTime<Utc>,
}

impl AnalogEngine {
    /// Validates a deserialized, immutable analog artifact against the exact
    /// feature-state prefix on which its transformations and index were fit.
    /// This performs no fitting and never repairs malformed parameters.
    pub fn validate_frozen(
        &self,
        states: &[MarketState],
        training_cutoff: DateTime<Utc>,
    ) -> Result<()> {
        if !valid_config(&self.config) {
            bail!("frozen analog config is invalid");
        }
        if self.train_indices.len() < 20
            || self.center.is_empty()
            || self.center.len() != self.scale.len()
            || self.center.len() > FEATURE_NAMES.len()
            || self.train_indices.windows(2).any(|pair| pair[0] >= pair[1])
            || self
                .train_indices
                .iter()
                .any(|index| *index >= states.len())
        {
            bail!("frozen analog index is invalid");
        }
        if self
            .center
            .iter()
            .chain(&self.scale)
            .any(|value| !value.is_finite())
            || self.scale.iter().any(|value| *value <= 0.0)
            || !self.ood_distance_threshold.is_finite()
            || self.ood_distance_threshold < 0.0
        {
            bail!("frozen analog transform contains invalid values");
        }
        if self.inverse_covariance.len() != self.center.len()
            || self.inverse_covariance.iter().any(|row| {
                row.len() != self.center.len() || row.iter().any(|value| !value.is_finite())
            })
            || self.learned_metric_weights.len() != self.center.len()
            || self
                .learned_metric_weights
                .iter()
                .any(|value| !value.is_finite() || *value < 0.0)
        {
            bail!("frozen analog metric transform is invalid");
        }
        let indexed_end = self
            .train_indices
            .iter()
            .map(|index| states[*index].timestamp)
            .max()
            .ok_or_else(|| anyhow::anyhow!("frozen analog index is empty"))?;
        if indexed_end != self.train_end
            || self.train_end + chrono::Duration::minutes(1) > training_cutoff
        {
            bail!("frozen analog training cutoff does not match its index");
        }
        if self.train_indices.iter().any(|index| {
            states[*index].timestamp + chrono::Duration::minutes(1) > training_cutoff
                || !valid_state_features(&states[*index], self.center.len(), self.config.metric)
        }) {
            bail!("frozen analog index references post-cutoff or invalid states");
        }
        Ok(())
    }

    pub fn frozen_training_index_count(&self) -> usize {
        self.train_indices.len()
    }

    /// Immutable fit lineage exposed for offline validation reports. These
    /// accessors do not refit, mutate, or select a production metric.
    pub fn covariance_inverse_status(&self) -> &str {
        &self.covariance_inverse_status
    }

    pub fn metric_fit_horizon_minutes(&self) -> Option<usize> {
        self.metric_fit_horizon_minutes
    }

    pub fn metric_training_label_count(&self) -> usize {
        self.metric_training_label_count
    }

    /// Fits every transformation on the caller-declared training indices.
    /// No validation/test observation is permitted in scaler, covariance,
    /// metric weights, or the calibrated OOD threshold.
    pub fn fit(
        states: &[MarketState],
        outcomes: &[Outcome],
        train_indices: &[usize],
        config: AnalogEngineConfig,
    ) -> Option<Self> {
        if !valid_config(&config)
            || train_indices.len() < 20
            || train_indices.iter().any(|index| *index >= states.len())
        {
            return None;
        }
        let mut indices = train_indices.to_vec();
        indices.sort_unstable();
        if indices.windows(2).any(|pair| pair[0] == pair[1])
            || indices.iter().any(|index| {
                !valid_state_features(&states[*index], config.maximum_dimensions, config.metric)
            })
        {
            return None;
        }
        let dimensions = config.maximum_dimensions;
        let train_end = indices.iter().map(|index| states[*index].timestamp).max()?;
        let mut center = vec![0.0; dimensions];
        let mut scale = vec![1.0; dimensions];
        for feature in 0..dimensions {
            let values = indices
                .iter()
                .map(|index| features(&states[*index])[feature])
                .collect::<Vec<_>>();
            center[feature] = quantile(&values, 0.5);
            let deviations = values
                .iter()
                .map(|value| (value - center[feature]).abs())
                .collect::<Vec<_>>();
            scale[feature] = (1.4826 * quantile(&deviations, 0.5)).max(1.0e-9);
        }
        let standardized = indices
            .iter()
            .map(|index| {
                features(&states[*index])[..dimensions]
                    .iter()
                    .enumerate()
                    .map(|(feature, value)| (value - center[feature]) / scale[feature])
                    .collect::<Vec<_>>()
            })
            .collect::<Vec<_>>();
        let shrinkage = config.covariance_shrinkage.clamp(0.0, 1.0);
        let standardized_mean = (0..dimensions)
            .map(|feature| {
                standardized.iter().map(|row| row[feature]).sum::<f64>() / standardized.len() as f64
            })
            .collect::<Vec<_>>();
        let mut covariance = vec![vec![0.0; dimensions]; dimensions];
        for row in &standardized {
            for (left, covariance_row) in covariance.iter_mut().enumerate() {
                for (right, covariance_value) in covariance_row.iter_mut().enumerate() {
                    *covariance_value += (row[left] - standardized_mean[left])
                        * (row[right] - standardized_mean[right]);
                }
            }
        }
        let covariance_denominator = (standardized.len() - 1) as f64;
        for covariance_row in &mut covariance {
            for covariance_value in covariance_row {
                *covariance_value /= covariance_denominator;
            }
        }
        let target_variance = (0..dimensions)
            .map(|feature| covariance[feature][feature])
            .sum::<f64>()
            / dimensions as f64;
        for (left, covariance_row) in covariance.iter_mut().enumerate() {
            for (right, covariance_value) in covariance_row.iter_mut().enumerate() {
                if left == right {
                    *covariance_value =
                        (1.0 - shrinkage) * *covariance_value + shrinkage * target_variance;
                } else {
                    *covariance_value *= 1.0 - shrinkage;
                }
            }
        }
        if covariance
            .iter()
            .any(|row| row.iter().any(|value| !value.is_finite()))
        {
            return None;
        }
        let (inverse_covariance, covariance_inverse_status) =
            if let Some(inverse) = invert_matrix(covariance) {
                (inverse, "shrinkage_covariance_inverse".to_string())
            } else {
                (
                    (0..dimensions)
                        .map(|row| {
                            (0..dimensions)
                                .map(|column| f64::from(row == column))
                                .collect::<Vec<_>>()
                        })
                        .collect::<Vec<_>>(),
                    "identity_standardized_euclidean_fallback".to_string(),
                )
            };

        let mut metric_fit_horizon_minutes = None;
        let mut metric_training_label_count = 0;
        let mut learned_metric_weights = vec![1.0 / dimensions as f64; dimensions];
        if config.metric == DistanceMetric::RegularizedMetricLearning {
            let timeline = StateTimeline::build(states)?;
            let mut seen_state_horizon = HashMap::<(usize, usize), ()>::new();
            let mut fit_horizons = BTreeMap::<usize, ()>::new();
            let relevant = outcomes
                .iter()
                .filter(|outcome| indices.binary_search(&outcome.state_index).is_ok())
                .collect::<Vec<_>>();
            for outcome in &relevant {
                if !valid_outcome_values(outcome)
                    || seen_state_horizon
                        .insert((outcome.state_index, outcome.horizon_minutes), ())
                        .is_some()
                {
                    return None;
                }
                fit_horizons.insert(outcome.horizon_minutes, ());
            }
            if fit_horizons.len() != 1 {
                return None;
            }
            let fit_horizon = *fit_horizons.keys().next()?;
            metric_fit_horizon_minutes = Some(fit_horizon);
            let mut target_by_state = HashMap::<usize, f64>::new();
            for outcome in relevant {
                let expected_available_at = outcome.entry_timestamp
                    + chrono::Duration::minutes(outcome.horizon_minutes as i64);
                if expected_available_at > train_end {
                    continue;
                }
                let path = timeline.realized_path(states, outcome.state_index, outcome)?;
                if path.label_available_at > train_end
                    || target_by_state
                        .insert(outcome.state_index, outcome.directional_return)
                        .is_some()
                {
                    return None;
                }
            }
            metric_training_label_count = target_by_state.len();
            if metric_training_label_count < 10 {
                return None;
            }
            learned_metric_weights = (0..dimensions)
                .map(|feature| {
                    let pairs = indices
                        .iter()
                        .filter_map(|index| {
                            target_by_state.get(index).map(|target| {
                                (
                                    (features(&states[*index])[feature] - center[feature])
                                        / scale[feature],
                                    *target,
                                )
                            })
                        })
                        .collect::<Vec<_>>();
                    absolute_pearson(&pairs).unwrap_or(0.0).max(0.05)
                })
                .collect::<Vec<_>>();
        }
        let weight_total = learned_metric_weights.iter().sum::<f64>().max(1.0e-12);
        for weight in &mut learned_metric_weights {
            *weight /= weight_total;
        }
        let mut engine = Self {
            config,
            train_indices: indices,
            center,
            scale,
            inverse_covariance,
            learned_metric_weights,
            ood_distance_threshold: 1.0,
            train_end,
            covariance_inverse_status,
            metric_fit_horizon_minutes,
            metric_training_label_count,
        };
        // Calibrate on a bounded, chronological training subsample to avoid an
        // accidental quadratic explosion on multi-year minute archives.
        let stride = engine.train_indices.len().div_ceil(256).max(1);
        let sampled = engine
            .train_indices
            .iter()
            .step_by(stride)
            .copied()
            .collect::<Vec<_>>();
        let nearest = sampled
            .iter()
            .filter_map(|query| {
                sampled
                    .iter()
                    .filter(|candidate| {
                        *candidate != query
                            && states[**candidate].session_date != states[*query].session_date
                    })
                    .map(|candidate| engine.distance(&states[*query], &states[*candidate]))
                    .filter(|distance| distance.is_finite())
                    .min_by(f64::total_cmp)
            })
            .collect::<Vec<_>>();
        if nearest.is_empty() || nearest.iter().any(|distance| !distance.is_finite()) {
            return None;
        }
        engine.ood_distance_threshold = quantile(&nearest, engine.config.ood_quantile).max(1.0e-6);
        Some(engine)
    }

    fn standardized(&self, state: &MarketState) -> Vec<f64> {
        features(state)[..self.center.len()]
            .iter()
            .enumerate()
            .map(|(feature, value)| (value - self.center[feature]) / self.scale[feature])
            .collect()
    }

    fn distance(&self, query: &MarketState, candidate: &MarketState) -> f64 {
        let left = self.standardized(query);
        let right = self.standardized(candidate);
        let delta = left
            .iter()
            .zip(&right)
            .map(|(a, b)| a - b)
            .collect::<Vec<_>>();
        match self.config.metric {
            DistanceMetric::StandardizedEuclidean => {
                (delta.iter().map(|value| value * value).sum::<f64>() / delta.len() as f64).sqrt()
            }
            DistanceMetric::ShrinkageMahalanobis => {
                let transformed = self
                    .inverse_covariance
                    .iter()
                    .map(|row| {
                        row.iter()
                            .zip(&delta)
                            .map(|(weight, value)| weight * value)
                            .sum::<f64>()
                    })
                    .collect::<Vec<_>>();
                delta
                    .iter()
                    .zip(transformed)
                    .map(|(value, transformed)| value * transformed)
                    .sum::<f64>()
                    .max(0.0)
                    .sqrt()
            }
            DistanceMetric::Correlation => correlation_distance(&left, &right),
            DistanceMetric::DynamicTimeWarping => {
                dtw(&path_features(query), &path_features(candidate))
            }
            DistanceMetric::RegularizedMetricLearning => delta
                .iter()
                .zip(&self.learned_metric_weights)
                .map(|(value, weight)| weight * value * value)
                .sum::<f64>()
                .sqrt(),
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn query(
        &self,
        states: &[MarketState],
        outcomes: &[Outcome],
        query_index: usize,
        horizon_minutes: usize,
        regime_probabilities: Option<&[Vec<f64>]>,
    ) -> AnalogForecast {
        let Some(query) = states.get(query_index) else {
            return unavailable_forecast(
                "QUERY_INDEX_OUT_OF_RANGE",
                horizon_minutes,
                self.config.metric,
            );
        };
        let query_id = snapshot_id(query);
        let unavailable = |reason: &str| {
            let mut forecast = unavailable_forecast(reason, horizon_minutes, self.config.metric);
            forecast.query_snapshot_id = query_id.clone();
            forecast.decision_as_of = query.timestamp;
            forecast
        };
        if horizon_minutes == 0 {
            return unavailable("INVALID_ZERO_HORIZON");
        }
        if !valid_state_features(query, self.center.len(), self.config.metric) {
            return unavailable("INVALID_QUERY_FEATURES");
        }
        if self.train_end >= query.timestamp {
            return unavailable("TRAIN_FIT_PERIOD_NOT_BEFORE_DECISION");
        }
        if self.config.metric == DistanceMetric::RegularizedMetricLearning
            && self.metric_fit_horizon_minutes != Some(horizon_minutes)
        {
            return unavailable("METRIC_LEARNING_HORIZON_MISMATCH");
        }
        let Some(timeline) = StateTimeline::build(states) else {
            return unavailable("DUPLICATE_SYMBOL_TIMESTAMP");
        };
        let mut outcome_map = HashMap::<usize, &Outcome>::new();
        for outcome in outcomes
            .iter()
            .filter(|outcome| outcome.horizon_minutes == horizon_minutes)
        {
            if outcome.state_index >= states.len() || !valid_outcome_values(outcome) {
                return unavailable("INVALID_OUTCOME_LABEL");
            }
            if outcome_map.insert(outcome.state_index, outcome).is_some() {
                return unavailable("DUPLICATE_OUTCOME_LABEL");
            }
        }
        let query_regime = regime_probabilities
            .and_then(|rows| rows.get(query_index))
            .map(Vec::as_slice);
        let regime_dimensions = if self.config.regime_conditioned {
            let Some(values) = query_regime else {
                return unavailable("QUERY_REGIME_PROBABILITIES_MISSING");
            };
            if !valid_probability_vector(values, None) {
                return unavailable("QUERY_REGIME_PROBABILITIES_INVALID");
            }
            if matches!(
                self.config.regime_match_policy,
                RegimeMatchPolicy::SameDominantAndPosteriorCosine
            ) && dominant_probability(values).is_none_or(|(_, probability)| {
                probability < self.config.minimum_dominant_regime_probability
            }) {
                return unavailable("QUERY_REGIME_POSTERIOR_UNCERTAIN");
            }
            Some(values.len())
        } else {
            query_regime
                .filter(|values| valid_probability_vector(values, None))
                .map(<[f64]>::len)
        };
        let mut invalid_regime_candidates = 0usize;
        let mut different_dominant_regime_candidates = 0usize;
        let mut uncertain_regime_candidates = 0usize;
        let mut invalid_path_candidates = 0usize;
        let mut best_by_day = BTreeMap::<NaiveDate, Candidate<'_>>::new();
        for index in &self.train_indices {
            if *index >= states.len() {
                continue;
            }
            let candidate = &states[*index];
            if candidate.timestamp >= query.timestamp
                || candidate.session_date >= query.session_date
                || !valid_state_features(candidate, self.center.len(), self.config.metric)
            {
                continue;
            }
            if self.config.same_time_bucket && candidate.bucket_5m != query.bucket_5m {
                continue;
            }
            let Some(outcome) = outcome_map.get(index).copied() else {
                continue;
            };
            let Some(realized_path) = timeline.realized_path(states, *index, outcome) else {
                invalid_path_candidates += 1;
                continue;
            };
            if realized_path.label_available_at > query.timestamp {
                continue;
            }
            let candidate_regime = regime_probabilities
                .and_then(|rows| rows.get(*index))
                .map(Vec::as_slice);
            let regime_similarity = if self.config.regime_conditioned {
                let Some(candidate_values) = candidate_regime else {
                    invalid_regime_candidates += 1;
                    continue;
                };
                if !valid_probability_vector(candidate_values, regime_dimensions) {
                    invalid_regime_candidates += 1;
                    continue;
                }
                let Some(similarity) =
                    query_regime.and_then(|query_values| cosine(query_values, candidate_values))
                else {
                    invalid_regime_candidates += 1;
                    continue;
                };
                if matches!(
                    self.config.regime_match_policy,
                    RegimeMatchPolicy::SameDominantAndPosteriorCosine
                ) {
                    let Some((query_dominant, _)) = query_regime.and_then(dominant_probability)
                    else {
                        return unavailable("QUERY_REGIME_POSTERIOR_UNCERTAIN");
                    };
                    let Some((candidate_dominant, candidate_probability)) =
                        dominant_probability(candidate_values)
                    else {
                        invalid_regime_candidates += 1;
                        continue;
                    };
                    if candidate_probability < self.config.minimum_dominant_regime_probability {
                        uncertain_regime_candidates += 1;
                        continue;
                    }
                    if candidate_dominant != query_dominant {
                        different_dominant_regime_candidates += 1;
                        continue;
                    }
                }
                if similarity < self.config.minimum_regime_similarity {
                    continue;
                }
                Some(similarity)
            } else {
                match (query_regime, candidate_regime) {
                    (Some(query_values), Some(candidate_values))
                        if valid_probability_vector(candidate_values, regime_dimensions) =>
                    {
                        cosine(query_values, candidate_values)
                    }
                    _ => None,
                }
            };
            let distance = self.distance(query, candidate);
            if !distance.is_finite() {
                continue;
            }
            let row = Candidate {
                state_index: *index,
                outcome,
                distance,
                regime_similarity,
                subsequent_path: realized_path.returns,
                label_available_at: realized_path.label_available_at,
            };
            match best_by_day.entry(candidate.session_date) {
                std::collections::btree_map::Entry::Vacant(entry) => {
                    entry.insert(row);
                }
                std::collections::btree_map::Entry::Occupied(mut entry) => {
                    if distance < entry.get().distance {
                        entry.insert(row);
                    }
                }
            }
        }
        let mut candidates = best_by_day.into_values().collect::<Vec<_>>();
        candidates.sort_by(|left, right| left.distance.total_cmp(&right.distance));
        candidates.truncate(self.config.neighbors.min(candidates.len()));
        if candidates.len() < 10 {
            let mut forecast = unavailable("NO_RELIABLE_ANALOG");
            forecast
                .no_trade_reasons
                .push("INSUFFICIENT_INDEPENDENT_ANALOG_DAYS".into());
            if invalid_regime_candidates > 0 {
                forecast
                    .no_trade_reasons
                    .push("INVALID_OR_MISSING_CANDIDATE_REGIME_PROBABILITIES".into());
            }
            if different_dominant_regime_candidates > 0 {
                forecast
                    .no_trade_reasons
                    .push("DIFFERENT_DOMINANT_REGIME_CANDIDATES_EXCLUDED".into());
            }
            if uncertain_regime_candidates > 0 {
                forecast
                    .no_trade_reasons
                    .push("UNCERTAIN_CANDIDATE_REGIME_POSTERIORS_EXCLUDED".into());
            }
            if invalid_path_candidates > 0 {
                forecast
                    .no_trade_reasons
                    .push("INVALID_OR_INCOMPLETE_SUBSEQUENT_PATH".into());
            }
            return forecast;
        }
        let base_bandwidth = match self.config.bandwidth_rule {
            BandwidthRule::AdaptiveKthNeighbor => {
                candidates.last().map(|row| row.distance).unwrap_or(1.0)
            }
            BandwidthRule::NearestNeighbor => {
                candidates.first().map(|row| row.distance).unwrap_or(1.0)
            }
            BandwidthRule::Fixed(value) => value,
        }
        .max(1.0e-6);
        let bandwidth = base_bandwidth * self.config.bandwidth_multiplier;
        let raw_weights = candidates
            .iter()
            .map(|row| {
                let posterior_overlap = row.regime_similarity.unwrap_or(1.0).clamp(0.0, 1.0);
                posterior_overlap * (-0.5 * (row.distance / bandwidth).powi(2)).exp()
            })
            .collect::<Vec<_>>();
        let sum = raw_weights.iter().sum::<f64>();
        if !sum.is_finite() || sum <= 1.0e-12 {
            return unavailable("INVALID_KERNEL_WEIGHTS");
        }
        let weights = raw_weights
            .iter()
            .map(|weight| weight / sum)
            .collect::<Vec<_>>();
        let analogs = candidates
            .iter()
            .zip(&weights)
            .enumerate()
            .map(|(rank, (row, weight))| {
                let candidate = &states[row.state_index];
                let query_values = features(query);
                let candidate_values = features(candidate);
                let feature_similarity = (0..self.center.len())
                    .map(|feature| {
                        let difference = (query_values[feature] - candidate_values[feature])
                            / self.scale[feature];
                        FeatureSimilarity {
                            feature: FEATURE_NAMES[feature].into(),
                            query_value: query_values[feature],
                            analog_value: candidate_values[feature],
                            standardized_difference: difference,
                            similarity: (-0.5 * difference * difference).exp(),
                        }
                    })
                    .collect::<Vec<_>>();
                RetrievedAnalog {
                    rank: rank + 1,
                    snapshot_id: snapshot_id(candidate),
                    analog_timestamp: candidate.timestamp,
                    session_date: candidate.session_date,
                    distance: row.distance,
                    weight: *weight,
                    regime_similarity: row.regime_similarity,
                    feature_similarity,
                    subsequent_realized_path: row.subsequent_path.clone(),
                    terminal_return: row.outcome.directional_return,
                    maximum_favorable_excursion: row.outcome.mfe,
                    maximum_adverse_excursion: row.outcome.mae,
                    label_available_at: row.label_available_at,
                }
            })
            .collect::<Vec<_>>();
        let weighted_returns = analogs
            .iter()
            .map(|analog| (analog.terminal_return, analog.weight))
            .collect::<Vec<_>>();
        let mean = weighted_returns
            .iter()
            .map(|row| row.0 * row.1)
            .sum::<f64>();
        let dispersion = weighted_returns
            .iter()
            .map(|row| row.1 * (row.0 - mean).powi(2))
            .sum::<f64>()
            .sqrt();
        let (sum_w, sum_wx, sum_wy, sum_wxx, sum_wxy) =
            analogs.iter().fold((0.0, 0.0, 0.0, 0.0, 0.0), |acc, row| {
                (
                    acc.0 + row.weight,
                    acc.1 + row.weight * row.distance,
                    acc.2 + row.weight * row.terminal_return,
                    acc.3 + row.weight * row.distance * row.distance,
                    acc.4 + row.weight * row.distance * row.terminal_return,
                )
            });
        let determinant = sum_w * sum_wxx - sum_wx * sum_wx;
        let local_intercept = if determinant.abs() > 1.0e-12 {
            (sum_wxx * sum_wy - sum_wx * sum_wxy) / determinant
        } else {
            mean
        };
        let tail = weighted_quantile(
            &analogs
                .iter()
                .map(|row| (row.terminal_return.abs(), row.weight))
                .collect::<Vec<_>>(),
            0.90,
        );
        let distribution = AnalogDistribution {
            kernel_weighted_mean: mean,
            locally_weighted_linear_intercept: local_intercept,
            weighted_quantiles: [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]
                .into_iter()
                .map(|probability| {
                    (
                        format!("q{:02}", (probability * 100.0) as u8),
                        weighted_quantile(&weighted_returns, probability),
                    )
                })
                .collect(),
            probability_up: analogs
                .iter()
                .filter(|row| row.terminal_return > 0.0)
                .map(|row| row.weight)
                .sum(),
            tail_probability: analogs
                .iter()
                .filter(|row| row.terminal_return.abs() >= tail)
                .map(|row| row.weight)
                .sum(),
            average_mfe: analogs
                .iter()
                .map(|row| row.maximum_favorable_excursion * row.weight)
                .sum(),
            average_mae: analogs
                .iter()
                .map(|row| row.maximum_adverse_excursion * row.weight)
                .sum(),
            dispersion,
        };
        let effective_sample_size = 1.0
            / weights
                .iter()
                .map(|weight| weight * weight)
                .sum::<f64>()
                .max(1.0e-12);
        let distances = analogs.iter().map(|row| row.distance).collect::<Vec<_>>();
        let distance_mean = distances.iter().sum::<f64>() / distances.len() as f64;
        let distance_concentration = if distance_mean > 0.0 {
            (distances.iter().copied().fold(f64::NEG_INFINITY, f64::max)
                - distances.iter().copied().fold(f64::INFINITY, f64::min))
                / distance_mean
        } else {
            0.0
        };
        let ages = analogs
            .iter()
            .map(|row| (query.session_date - row.session_date).num_days() as f64)
            .collect::<Vec<_>>();
        let mut years = BTreeMap::<i32, f64>::new();
        for row in &analogs {
            *years.entry(row.session_date.year()).or_default() += row.weight;
        }
        let dominant_year = years
            .iter()
            .max_by(|left, right| left.1.total_cmp(right.1))
            .map(|row| *row.0);
        let maximum_year_weight = years.values().copied().fold(0.0, f64::max);
        let mut sensitivity = Vec::new();
        for neighbors in &self.config.sensitivity_k {
            for multiplier in &self.config.sensitivity_bandwidth {
                sensitivity.push(sensitivity_point(
                    &candidates,
                    *neighbors,
                    base_bandwidth,
                    *multiplier,
                ));
            }
        }
        let nearest = distances[0];
        let ood_score = nearest / self.ood_distance_threshold.max(1.0e-9);
        let mut session_day_counts = BTreeMap::<NaiveDate, usize>::new();
        for analog in &analogs {
            *session_day_counts.entry(analog.session_date).or_default() += 1;
        }
        let highly_overlapping_neighbors = session_day_counts.values().any(|count| *count > 1);
        let same_day_neighbor_count = analogs
            .iter()
            .filter(|row| row.session_date == query.session_date)
            .count();
        let diagnostics = AnalogDiagnostics {
            nearest_neighbor_distance: nearest,
            ood_distance_threshold: self.ood_distance_threshold,
            out_of_distribution_score: ood_score,
            distance_concentration,
            effective_sample_size,
            analog_age_days_mean: ages.iter().sum::<f64>() / ages.len() as f64,
            analog_age_days_quantiles: [0.10, 0.50, 0.90]
                .into_iter()
                .map(|probability| {
                    (
                        format!("q{:02}", (probability * 100.0) as u8),
                        quantile(&ages, probability),
                    )
                })
                .collect(),
            maximum_year_weight,
            dominant_year,
            highly_overlapping_neighbors,
            selected_dimensions: FEATURE_NAMES[..self.center.len()]
                .iter()
                .map(|name| (*name).to_string())
                .collect(),
            scaler_fit_period_end: self.train_end,
            metric_weights_fit_on_train_only: true,
            sensitivity,
            bandwidth_rule: match self.config.bandwidth_rule {
                BandwidthRule::AdaptiveKthNeighbor => "adaptive_kth_neighbor",
                BandwidthRule::NearestNeighbor => "nearest_neighbor",
                BandwidthRule::Fixed(_) => "fixed",
            }
            .into(),
            bandwidth_reference_distance: base_bandwidth,
            covariance_inverse_status: self.covariance_inverse_status.clone(),
            same_day_neighbor_count,
            unique_session_day_count: session_day_counts.len(),
            metric_fit_horizon_minutes: self.metric_fit_horizon_minutes,
            metric_training_label_count: self.metric_training_label_count,
        };
        let mut reasons = Vec::new();
        if ood_score > 1.0 {
            reasons.push("OUT_OF_DISTRIBUTION".into());
        }
        if effective_sample_size < self.config.minimum_effective_sample_size {
            reasons.push("NO_RELIABLE_ANALOG_INSUFFICIENT_ESS".into());
        }
        if maximum_year_weight > 0.40 {
            reasons.push("ANALOGS_OVERDEPEND_ON_ONE_PERIOD".into());
        }
        if distance_concentration < 0.05 {
            reasons.push("NEAREST_NEIGHBOR_DISTANCE_CONCENTRATION".into());
        }
        if highly_overlapping_neighbors || same_day_neighbor_count > 0 {
            reasons.push("OVERLAPPING_OR_SAME_DAY_ANALOGS".into());
        }
        if self.config.metric == DistanceMetric::ShrinkageMahalanobis
            && self.covariance_inverse_status == "identity_standardized_euclidean_fallback"
        {
            reasons.push("MAHALANOBIS_IDENTITY_FALLBACK".into());
        }
        AnalogForecast {
            query_snapshot_id: query_id,
            decision_as_of: query.timestamp,
            horizon_minutes,
            metric: self.config.metric,
            bandwidth,
            top_analogs: analogs,
            distribution: Some(distribution),
            diagnostics: Some(diagnostics),
            status: if reasons.is_empty() {
                "AVAILABLE"
            } else {
                "NO_TRADE"
            }
            .into(),
            no_trade_reasons: reasons,
            supported_method_comparison: vec![
                "standardized_euclidean".into(),
                "shrinkage_mahalanobis".into(),
                "correlation".into(),
                "dynamic_time_warping".into(),
                "regularized_metric_learning".into(),
                "gaussian_kernel_distribution".into(),
                "same_dominant_regime_posterior_overlap_weight".into(),
                "adaptive_bandwidth".into(),
                "nearest_neighbor_bandwidth".into(),
                "locally_weighted_linear_regression".into(),
                "kernel_weighted_quantiles".into(),
                "exact_search_ann_deferred_until_scale_requires_it".into(),
            ],
        }
    }
}

fn sensitivity_point(
    candidates: &[Candidate<'_>],
    neighbors: usize,
    base_bandwidth: f64,
    bandwidth_multiplier: f64,
) -> SensitivityPoint {
    let selected = candidates.iter().take(neighbors).collect::<Vec<_>>();
    let bandwidth = (base_bandwidth * bandwidth_multiplier).max(1.0e-9);
    let raw = selected
        .iter()
        .map(|row| {
            let posterior_overlap = row.regime_similarity.unwrap_or(1.0).clamp(0.0, 1.0);
            posterior_overlap * (-0.5 * (row.distance / bandwidth).powi(2)).exp()
        })
        .collect::<Vec<_>>();
    let total = raw.iter().sum::<f64>();
    if !total.is_finite() || total <= 1.0e-12 {
        return SensitivityPoint {
            neighbors: selected.len(),
            bandwidth_multiplier,
            expected_return: 0.0,
            probability_up: 0.0,
            effective_sample_size: 0.0,
        };
    }
    let weights = raw.iter().map(|weight| weight / total).collect::<Vec<_>>();
    SensitivityPoint {
        neighbors: selected.len(),
        bandwidth_multiplier,
        expected_return: selected
            .iter()
            .zip(&weights)
            .map(|(row, weight)| row.outcome.directional_return * weight)
            .sum(),
        probability_up: selected
            .iter()
            .zip(&weights)
            .filter(|(row, _)| row.outcome.directional_return > 0.0)
            .map(|(_, weight)| *weight)
            .sum(),
        effective_sample_size: 1.0
            / weights
                .iter()
                .map(|weight| weight * weight)
                .sum::<f64>()
                .max(1.0e-12),
    }
}

fn unavailable_forecast(reason: &str, horizon: usize, metric: DistanceMetric) -> AnalogForecast {
    AnalogForecast {
        query_snapshot_id: String::new(),
        decision_as_of: DateTime::<Utc>::UNIX_EPOCH,
        horizon_minutes: horizon,
        metric,
        bandwidth: 0.0,
        top_analogs: Vec::new(),
        distribution: None,
        diagnostics: None,
        status: reason.into(),
        no_trade_reasons: vec![reason.into(), "NO_TRADE".into()],
        supported_method_comparison: Vec::new(),
    }
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, NaiveDate, TimeZone, Utc};

    use super::{
        AnalogEngine, AnalogEngineConfig, BandwidthRule, DistanceMetric, RegimeMatchPolicy,
    };
    use crate::domain::{MarketState, Outcome};

    const HORIZON: usize = 5;

    struct Fixture {
        states: Vec<MarketState>,
        outcomes: Vec<Outcome>,
        candidate_indices: Vec<usize>,
        query_index: usize,
    }

    fn state(day: usize, minute: usize, symbol: &str, constant_features: bool) -> MarketState {
        let session_date =
            NaiveDate::from_ymd_opt(2025, 1, 1).unwrap() + Duration::days(day as i64);
        let timestamp = Utc.with_ymd_and_hms(2025, 1, 1, 15, 0, 0).unwrap()
            + Duration::days(day as i64)
            + Duration::minutes(minute as i64);
        let symbol_offset = if symbol == "SPY" { 0.0 } else { 0.7 };
        let value = if constant_features {
            0.01 + symbol_offset
        } else {
            day as f64 / 1000.0 + minute as f64 / 100_000.0 + symbol_offset
        };
        let base = if symbol == "SPY" {
            100.0 + day as f64 / 10.0
        } else {
            1_000.0 + day as f64
        };
        let direction = if day.is_multiple_of(2) { 1.0 } else { -1.0 };
        let move_fraction = direction * minute as f64 * 0.0002;
        let close = base * (1.0 + move_fraction);
        MarketState {
            timestamp,
            session_date,
            symbol: symbol.into(),
            open: base,
            high: base.max(close) * 1.0001,
            low: base.min(close) * 0.9999,
            close,
            atr: 1.0,
            ret_1m: value,
            ret_3m: value,
            ret_5m: value,
            ret_15m: value,
            ret_30m: value,
            ret_60m: value,
            active_5m_return: value,
            last_completed_5m_return: value,
            last_completed_15m_return: value,
            slope_15m: value,
            dist_vwap: value,
            dist_session_open: value,
            rolling_realized_vol: 0.01 + value.abs(),
            normalized_range: 0.01,
            upper_wick_ratio: 0.2,
            lower_wick_ratio: 0.2,
            close_location_value: 0.0,
            distance_session_high: -0.01,
            distance_session_low: 0.01,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 1,
            consecutive_down_bars: 0,
            return_acceleration: 0.0,
            volume_zscore: value,
            volume_acceleration: 0.0,
            session_range_position: 0.5,
            cross_asset_breadth_score: value,
            risk_rotation_score: value,
            market_confirmation_score: 0.0,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0 + value,
            minutes_from_open: 90 + minute as i32,
            minutes_to_close: 300i32.saturating_sub(minute as i32),
            bucket_5m: 18,
            bucket_15m: 6,
            minute_in_5m_bucket: (minute % 5) as i32,
            completed_5m_bucket_valid: minute % 5 == 4,
            continuous_minute_count: minute + 1,
        }
    }

    fn outcome_for(states: &[MarketState], candidate_index: usize) -> Outcome {
        let candidate = &states[candidate_index];
        let mut window = states
            .iter()
            .filter(|state| {
                state.symbol == candidate.symbol
                    && state.session_date == candidate.session_date
                    && state.timestamp > candidate.timestamp
            })
            .collect::<Vec<_>>();
        window.sort_by_key(|state| state.timestamp);
        window.truncate(HORIZON);
        assert_eq!(window.len(), HORIZON);
        let entry = window[0].open;
        Outcome {
            state_index: candidate_index,
            entry_timestamp: window[0].timestamp,
            horizon_minutes: HORIZON,
            directional_return: window.last().unwrap().close / entry - 1.0,
            mfe: window
                .iter()
                .map(|state| state.high / entry - 1.0)
                .fold(f64::NEG_INFINITY, f64::max),
            mae: -window
                .iter()
                .map(|state| state.low / entry - 1.0)
                .fold(f64::INFINITY, f64::min)
                .min(0.0),
        }
    }

    fn fixture(constant_features: bool) -> Fixture {
        let mut states = Vec::new();
        let mut candidate_indices = Vec::new();
        // SPY and QQQ are deliberately interleaved. An index-slice path
        // implementation would accidentally consume QQQ bars.
        for day in 0..50 {
            for minute in 0..=HORIZON {
                if minute == 0 {
                    candidate_indices.push(states.len());
                }
                states.push(state(day, minute, "SPY", constant_features));
                states.push(state(day, minute, "QQQ", constant_features));
            }
        }
        let outcomes = candidate_indices
            .iter()
            .map(|index| outcome_for(&states, *index))
            .collect::<Vec<_>>();
        let query_index = candidate_indices[40];
        Fixture {
            states,
            outcomes,
            candidate_indices,
            query_index,
        }
    }

    fn config(metric: DistanceMetric) -> AnalogEngineConfig {
        AnalogEngineConfig {
            metric,
            regime_conditioned: false,
            neighbors: 20,
            minimum_effective_sample_size: 5.0,
            ..AnalogEngineConfig::default()
        }
    }

    fn train_indices(fixture: &Fixture) -> Vec<usize> {
        fixture.candidate_indices[..30].to_vec()
    }

    #[test]
    fn strict_pit_query_uses_mature_horizon_matched_same_symbol_paths() {
        let fixture = fixture(false);
        let engine = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &train_indices(&fixture),
            config(DistanceMetric::ShrinkageMahalanobis),
        )
        .unwrap();
        let forecast = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            None,
        );
        assert!(!forecast.top_analogs.is_empty());
        let query = &fixture.states[fixture.query_index];
        for analog in &forecast.top_analogs {
            assert!(analog.analog_timestamp < query.timestamp);
            assert!(analog.session_date < query.session_date);
            assert!(analog.label_available_at <= forecast.decision_as_of);
            assert_eq!(analog.subsequent_realized_path.len(), HORIZON);
            assert!(
                analog
                    .subsequent_realized_path
                    .iter()
                    .all(|value| value.abs() < 0.01)
            );
            assert!(
                (analog.subsequent_realized_path[HORIZON - 1] - analog.terminal_return).abs()
                    < 1.0e-10
            );
        }
        let diagnostics = forecast.diagnostics.unwrap();
        assert!(diagnostics.metric_weights_fit_on_train_only);
        assert_eq!(diagnostics.same_day_neighbor_count, 0);
        assert_eq!(
            diagnostics.unique_session_day_count,
            forecast.top_analogs.len()
        );
        assert!(!diagnostics.highly_overlapping_neighbors);
    }

    #[test]
    fn fit_rejects_duplicate_indices_nan_features_and_invalid_bandwidth() {
        let mut data = fixture(false);
        let mut duplicated = train_indices(&data);
        duplicated.push(duplicated[0]);
        assert!(
            AnalogEngine::fit(
                &data.states,
                &data.outcomes,
                &duplicated,
                config(DistanceMetric::StandardizedEuclidean),
            )
            .is_none()
        );

        let bad_index = data.candidate_indices[3];
        data.states[bad_index].ret_1m = f64::NAN;
        assert!(
            AnalogEngine::fit(
                &data.states,
                &data.outcomes,
                &train_indices(&data),
                config(DistanceMetric::StandardizedEuclidean),
            )
            .is_none()
        );

        let clean = fixture(false);
        let invalid_config = AnalogEngineConfig {
            bandwidth_rule: BandwidthRule::Fixed(f64::NAN),
            ..config(DistanceMetric::StandardizedEuclidean)
        };
        assert!(
            AnalogEngine::fit(
                &clean.states,
                &clean.outcomes,
                &train_indices(&clean),
                invalid_config,
            )
            .is_none()
        );
    }

    #[test]
    fn regime_conditioning_requires_complete_normalized_matching_vectors() {
        let fixture = fixture(false);
        let conditioned = AnalogEngineConfig {
            regime_conditioned: true,
            minimum_regime_similarity: 0.0,
            ..config(DistanceMetric::StandardizedEuclidean)
        };
        let engine = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &train_indices(&fixture),
            conditioned,
        )
        .unwrap();
        let missing = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            None,
        );
        assert_eq!(missing.status, "QUERY_REGIME_PROBABILITIES_MISSING");

        let mut probabilities = vec![vec![0.7, 0.3]; fixture.states.len()];
        probabilities[fixture.query_index] = vec![0.7, f64::NAN];
        let invalid_query = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            Some(&probabilities),
        );
        assert_eq!(invalid_query.status, "QUERY_REGIME_PROBABILITIES_INVALID");

        probabilities[fixture.query_index] = vec![0.7, 0.3];
        for index in train_indices(&fixture) {
            probabilities[index] = vec![1.0];
        }
        let invalid_candidates = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            Some(&probabilities),
        );
        assert!(invalid_candidates.top_analogs.is_empty());
        assert!(
            invalid_candidates
                .no_trade_reasons
                .contains(&"INVALID_OR_MISSING_CANDIDATE_REGIME_PROBABILITIES".into())
        );
    }

    #[test]
    fn strict_regime_policy_excludes_different_dominant_states_without_fallback() {
        let fixture = fixture(false);
        let conditioned = AnalogEngineConfig {
            regime_conditioned: true,
            regime_match_policy: RegimeMatchPolicy::SameDominantAndPosteriorCosine,
            minimum_regime_similarity: 0.0,
            minimum_dominant_regime_probability: 0.50,
            ..config(DistanceMetric::StandardizedEuclidean)
        };
        let engine = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &train_indices(&fixture),
            conditioned,
        )
        .unwrap();
        let mut probabilities = vec![vec![0.90, 0.10]; fixture.states.len()];
        for index in train_indices(&fixture) {
            probabilities[index] = vec![0.10, 0.90];
        }
        let excluded = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            Some(&probabilities),
        );
        assert!(excluded.top_analogs.is_empty());
        assert!(
            excluded
                .no_trade_reasons
                .contains(&"DIFFERENT_DOMINANT_REGIME_CANDIDATES_EXCLUDED".into())
        );

        for index in train_indices(&fixture) {
            probabilities[index] = vec![0.85, 0.15];
        }
        let matched = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            Some(&probabilities),
        );
        assert!(!matched.top_analogs.is_empty());
        assert!(
            matched
                .top_analogs
                .iter()
                .all(|row| row.regime_similarity.is_some_and(|value| value > 0.99))
        );
    }

    #[test]
    fn query_rejects_wrong_horizon_duplicate_labels_and_incomplete_paths() {
        let fixture = fixture(false);
        let engine = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &train_indices(&fixture),
            config(DistanceMetric::StandardizedEuclidean),
        )
        .unwrap();
        let wrong_horizon = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            15,
            None,
        );
        assert!(wrong_horizon.top_analogs.is_empty());

        let mut duplicated = fixture.outcomes.clone();
        duplicated.push(duplicated[0].clone());
        let duplicate = engine.query(
            &fixture.states,
            &duplicated,
            fixture.query_index,
            HORIZON,
            None,
        );
        assert_eq!(duplicate.status, "DUPLICATE_OUTCOME_LABEL");

        let mut malformed = fixture.outcomes.clone();
        for outcome in malformed
            .iter_mut()
            .filter(|outcome| train_indices(&fixture).contains(&outcome.state_index))
        {
            outcome.entry_timestamp += Duration::minutes(1);
        }
        let incomplete = engine.query(
            &fixture.states,
            &malformed,
            fixture.query_index,
            HORIZON,
            None,
        );
        assert!(incomplete.top_analogs.is_empty());
        assert!(
            incomplete
                .no_trade_reasons
                .contains(&"INVALID_OR_INCOMPLETE_SUBSEQUENT_PATH".into())
        );
    }

    #[test]
    fn query_rejects_future_fitted_transforms_and_excludes_same_session() {
        let mut fixture = fixture(false);
        let future_fit = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &fixture.candidate_indices[..42],
            config(DistanceMetric::StandardizedEuclidean),
        )
        .unwrap();
        let rejected = future_fit.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            HORIZON,
            None,
        );
        assert_eq!(rejected.status, "TRAIN_FIT_PERIOD_NOT_BEFORE_DECISION");

        let same_day_candidate = fixture.candidate_indices[40];
        let query_state = state(40, 10, "SPY", false);
        fixture.states.push(query_state);
        let later_query_index = fixture.states.len() - 1;
        let mut indices = fixture.candidate_indices[..29].to_vec();
        indices.push(same_day_candidate);
        let engine = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &indices,
            config(DistanceMetric::StandardizedEuclidean),
        )
        .unwrap();
        let forecast = engine.query(
            &fixture.states,
            &fixture.outcomes,
            later_query_index,
            HORIZON,
            None,
        );
        assert!(!forecast.top_analogs.is_empty());
        assert!(
            forecast
                .top_analogs
                .iter()
                .all(|analog| analog.session_date < fixture.states[later_query_index].session_date)
        );
    }

    #[test]
    fn covariance_fallback_and_bandwidth_diagnostics_are_explicit() {
        let constant = fixture(true);
        let fallback_engine = AnalogEngine::fit(
            &constant.states,
            &constant.outcomes,
            &train_indices(&constant),
            config(DistanceMetric::ShrinkageMahalanobis),
        )
        .unwrap();
        assert_eq!(
            fallback_engine.covariance_inverse_status,
            "identity_standardized_euclidean_fallback"
        );
        let fallback = fallback_engine.query(
            &constant.states,
            &constant.outcomes,
            constant.query_index,
            HORIZON,
            None,
        );
        assert!(
            fallback
                .no_trade_reasons
                .contains(&"MAHALANOBIS_IDENTITY_FALLBACK".into())
        );

        let fixture = fixture(false);
        for (rule, expected_label, multiplier) in [
            (
                BandwidthRule::AdaptiveKthNeighbor,
                "adaptive_kth_neighbor",
                1.0,
            ),
            (BandwidthRule::NearestNeighbor, "nearest_neighbor", 1.0),
            (BandwidthRule::Fixed(0.25), "fixed", 1.5),
        ] {
            let configured = AnalogEngineConfig {
                bandwidth_rule: rule,
                bandwidth_multiplier: multiplier,
                ..config(DistanceMetric::StandardizedEuclidean)
            };
            let engine = AnalogEngine::fit(
                &fixture.states,
                &fixture.outcomes,
                &train_indices(&fixture),
                configured,
            )
            .unwrap();
            let forecast = engine.query(
                &fixture.states,
                &fixture.outcomes,
                fixture.query_index,
                HORIZON,
                None,
            );
            let diagnostics = forecast.diagnostics.unwrap();
            assert_eq!(diagnostics.bandwidth_rule, expected_label);
            assert!(
                (forecast.bandwidth - diagnostics.bandwidth_reference_distance * multiplier).abs()
                    < 1.0e-12
            );
            assert!(
                diagnostics
                    .sensitivity
                    .iter()
                    .all(|point| [0.5, 0.75, 1.0, 1.5, 2.0].contains(&point.bandwidth_multiplier))
            );
        }
    }

    #[test]
    fn learned_metric_is_train_only_horizon_specific_and_uses_mature_labels() {
        let fixture = fixture(false);
        let engine = AnalogEngine::fit(
            &fixture.states,
            &fixture.outcomes,
            &train_indices(&fixture),
            config(DistanceMetric::RegularizedMetricLearning),
        )
        .unwrap();
        assert_eq!(engine.metric_fit_horizon_minutes, Some(HORIZON));
        // The last training state's label matures after train_end and must not
        // participate in supervised metric weights.
        assert_eq!(engine.metric_training_label_count, 29);
        assert!((engine.learned_metric_weights.iter().sum::<f64>() - 1.0).abs() < 1.0e-12);

        let mismatch = engine.query(
            &fixture.states,
            &fixture.outcomes,
            fixture.query_index,
            15,
            None,
        );
        assert_eq!(mismatch.status, "METRIC_LEARNING_HORIZON_MISMATCH");

        let mut mixed_horizons = fixture.outcomes.clone();
        let mut extra = mixed_horizons[0].clone();
        extra.horizon_minutes = 3;
        mixed_horizons.push(extra);
        assert!(
            AnalogEngine::fit(
                &fixture.states,
                &mixed_horizons,
                &train_indices(&fixture),
                config(DistanceMetric::RegularizedMetricLearning),
            )
            .is_none()
        );
    }
}
