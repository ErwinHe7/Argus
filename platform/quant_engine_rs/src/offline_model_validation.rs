//! Bounded, offline-only validation for the frozen HMM + analog predictor.
//!
//! This module deliberately has no production inference or promotion side
//! effects. It constructs chronological expanding folds, selects the HMM state
//! count inside each fold's pre-test data, refits all model transforms on
//! pre-test observations only, and scores fixed models on untouched fold-test
//! labels. Every result remains `CANDIDATE_NOT_PROMOTED`.

use std::collections::{BTreeMap, BTreeSet, HashMap};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::{
    analog_engine::{
        AnalogEngine, AnalogEngineConfig, AnalogForecast, BandwidthRule, DistanceMetric,
        RegimeMatchPolicy,
    },
    config::ResearchConfig,
    domain::{MarketState, Outcome},
    engine::{
        regime::{
            GaussianHmm, HmmCandidateAssessment, select_hmm_candidates,
            validate_hmm_state_occupancy,
        },
        walk_forward,
    },
    predictor::FrozenPredictorArtifact,
};

pub const OFFLINE_MODEL_VALIDATION_SCHEMA_VERSION: &str = "axio.offline-frozen-model-validation.v1";
pub const CANDIDATE_NOT_PROMOTED: &str = "CANDIDATE_NOT_PROMOTED";

const ACTIVE_ANALOG_METRIC: &str = "shrinkage_mahalanobis";
const SUPERVISED_ANALOG_CHALLENGER: &str = "regularized_metric_learning";
const EVIDENCE_GRADE: &str =
    "PURGED_CHRONOLOGICAL_FOLD_TEST_RESEARCH_EVIDENCE_NOT_PROMOTION_EVIDENCE";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OfflineValidationConfig {
    pub horizon_minutes: usize,
    pub initial_train_days: usize,
    pub selection_validation_days: usize,
    pub test_days: usize,
    pub purge_days: usize,
    pub embargo_days: usize,
    pub minimum_required_folds: usize,
    pub maximum_folds: usize,
    pub maximum_test_queries_per_fold: usize,
    pub minimum_paired_test_samples_per_fold: usize,
}

impl OfflineValidationConfig {
    /// Deterministic bounded defaults. The caller may persist a stricter
    /// preregistered config, but may not derive these sizes from test loss.
    pub fn for_session_count(session_count: usize, horizon_minutes: usize) -> Self {
        let block = (session_count / 10).max(2);
        Self {
            horizon_minutes,
            initial_train_days: (session_count / 2).max(1),
            selection_validation_days: block,
            test_days: block,
            purge_days: 1,
            embargo_days: 1,
            minimum_required_folds: 3,
            maximum_folds: 5,
            maximum_test_queries_per_fold: 1_000,
            minimum_paired_test_samples_per_fold: 30,
        }
    }

    fn validate(&self) -> Result<()> {
        if self.horizon_minutes == 0
            || self.initial_train_days == 0
            || self.selection_validation_days == 0
            || self.test_days == 0
            || self.purge_days == 0
            || self.embargo_days == 0
            || self.minimum_required_folds < 2
            || self.maximum_folds < self.minimum_required_folds
            || self.maximum_test_queries_per_fold == 0
            || self.minimum_paired_test_samples_per_fold == 0
        {
            bail!(
                "offline validation requires non-zero chronological partitions, at least two folds, and bounded test samples"
            );
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NamedEvaluationInterval {
    pub name: String,
    pub role: String,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
}

impl NamedEvaluationInterval {
    fn validate(&self) -> Result<()> {
        if self.name.trim().is_empty() || self.role.trim().is_empty() || self.start > self.end {
            bail!("evaluation intervals require a name, role, and ordered timestamps");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OfflineValidationLineage {
    pub generated_at: DateTime<Utc>,
    pub source_path: String,
    pub source_sha256: String,
    pub code_commit_hash: String,
    #[serde(default)]
    pub displayed_replay_or_external_test_intervals: Vec<NamedEvaluationInterval>,
}

impl OfflineValidationLineage {
    fn validate(&self) -> Result<()> {
        let valid_sha256 =
            |value: &str| value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit());
        if self.source_path.trim().is_empty()
            || !valid_sha256(&self.source_sha256)
            || self.code_commit_hash.trim().is_empty()
        {
            bail!(
                "offline validation lineage requires an exact source path/hash and code identity"
            );
        }
        for interval in &self.displayed_replay_or_external_test_intervals {
            interval.validate()?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct IntervalBounds {
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ArtifactIntervalAudit {
    pub artifact_identity: String,
    pub artifact_training_bounds: IntervalBounds,
    pub evidence_name: String,
    pub evidence_role: String,
    pub evaluation_bounds: IntervalBounds,
    pub overlaps_artifact_training_bounds: bool,
    pub strictly_post_training: bool,
    pub oos_claim_permitted: bool,
    pub evidence_label: String,
}

/// Centralized interval labeling. In particular, an interval that overlaps the
/// artifact's training bounds can never be serialized with an OOS label.
pub fn audit_artifact_interval(
    artifact_identity: impl Into<String>,
    artifact_training_bounds: IntervalBounds,
    evidence: &NamedEvaluationInterval,
) -> ArtifactIntervalAudit {
    let overlaps = evidence.start <= artifact_training_bounds.end
        && evidence.end >= artifact_training_bounds.start;
    let strictly_post_training = evidence.start > artifact_training_bounds.end;
    let evidence_label = if overlaps {
        "NOT_OUT_OF_SAMPLE_OVERLAPS_ARTIFACT_TRAINING"
    } else if strictly_post_training {
        "POST_TRAINING_CHRONOLOGICAL_EVALUATION"
    } else {
        "NOT_OUT_OF_SAMPLE_ARTIFACT_FIT_USES_FUTURE_OBSERVATIONS"
    };
    ArtifactIntervalAudit {
        artifact_identity: artifact_identity.into(),
        artifact_training_bounds,
        evidence_name: evidence.name.clone(),
        evidence_role: evidence.role.clone(),
        evaluation_bounds: IntervalBounds {
            start: evidence.start,
            end: evidence.end,
        },
        overlaps_artifact_training_bounds: overlaps,
        strictly_post_training,
        oos_claim_permitted: strictly_post_training,
        evidence_label: evidence_label.into(),
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct StrictLabelAccounting {
    pub candidate_state_count: usize,
    pub valid_label_count: usize,
    pub excluded_insufficient_remaining_bars: usize,
    pub excluded_cross_session_or_symbol: usize,
    pub excluded_non_contiguous_timestamps: usize,
    pub excluded_invalid_prices_or_returns: usize,
}

impl StrictLabelAccounting {
    fn excluded_total(&self) -> usize {
        self.excluded_insufficient_remaining_bars
            + self.excluded_cross_session_or_symbol
            + self.excluded_non_contiguous_timestamps
            + self.excluded_invalid_prices_or_returns
    }

    fn validate(&self) -> Result<()> {
        if self.candidate_state_count != self.valid_label_count + self.excluded_total() {
            bail!("strict label accounting does not reconcile to candidate states");
        }
        Ok(())
    }
}

/// Exact-clock labels for `t+1 .. t+horizon`. Unlike a positional shortcut,
/// this fails each candidate closed when any minute is absent or crosses a
/// session/symbol boundary.
pub fn strict_forward_outcomes(
    states: &[MarketState],
    horizon_minutes: usize,
) -> Result<(Vec<Outcome>, StrictLabelAccounting)> {
    if horizon_minutes == 0 {
        bail!("strict forward outcomes require a non-zero horizon");
    }
    let mut accounting = StrictLabelAccounting {
        candidate_state_count: states.len(),
        ..StrictLabelAccounting::default()
    };
    let mut outcomes = Vec::new();
    for (index, state) in states.iter().enumerate() {
        let Some(end_exclusive) = index
            .checked_add(1)
            .and_then(|entry| entry.checked_add(horizon_minutes))
        else {
            accounting.excluded_insufficient_remaining_bars += 1;
            continue;
        };
        let Some(window) = states.get(index + 1..end_exclusive) else {
            accounting.excluded_insufficient_remaining_bars += 1;
            continue;
        };
        if window.iter().any(|row| {
            row.session_date != state.session_date
                || !row.symbol.eq_ignore_ascii_case(&state.symbol)
        }) {
            accounting.excluded_cross_session_or_symbol += 1;
            continue;
        }
        if window.iter().enumerate().any(|(offset, row)| {
            row.timestamp != state.timestamp + Duration::minutes((offset + 1) as i64)
        }) {
            accounting.excluded_non_contiguous_timestamps += 1;
            continue;
        }
        if window.iter().any(|row| {
            !row.open.is_finite()
                || !row.high.is_finite()
                || !row.low.is_finite()
                || !row.close.is_finite()
                || row.open <= 0.0
                || row.high <= 0.0
                || row.low <= 0.0
                || row.close <= 0.0
        }) {
            accounting.excluded_invalid_prices_or_returns += 1;
            continue;
        }
        let entry = window[0].open;
        let directional_return =
            window.last().expect("non-empty horizon window").close / entry - 1.0;
        let mfe = window
            .iter()
            .map(|row| row.high / entry - 1.0)
            .fold(f64::NEG_INFINITY, f64::max);
        let mae = -window
            .iter()
            .map(|row| row.low / entry - 1.0)
            .fold(f64::INFINITY, f64::min)
            .min(0.0);
        if !directional_return.is_finite() || !mfe.is_finite() || !mae.is_finite() {
            accounting.excluded_invalid_prices_or_returns += 1;
            continue;
        }
        outcomes.push(Outcome {
            state_index: index,
            entry_timestamp: window[0].timestamp,
            horizon_minutes,
            directional_return,
            mfe,
            mae,
        });
    }
    accounting.valid_label_count = outcomes.len();
    accounting.validate()?;
    Ok((outcomes, accounting))
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct FoldPartition {
    pub train_days: Vec<NaiveDate>,
    pub purged_days: Vec<NaiveDate>,
    pub selection_validation_days: Vec<NaiveDate>,
    pub embargoed_days: Vec<NaiveDate>,
    pub test_days: Vec<NaiveDate>,
    pub partition_sha256: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct FoldSampleAccounting {
    pub detected_test_states: usize,
    pub excluded_fold_fit_or_scoring_failure: usize,
    pub excluded_not_on_non_overlapping_horizon_grid: usize,
    pub excluded_missing_strict_label: usize,
    pub excluded_missing_causal_regime_posterior: usize,
    pub eligible_before_budget: usize,
    pub excluded_by_preregistered_sample_budget: usize,
    pub evaluated_queries: usize,
    pub paired_scored_queries: usize,
    pub excluded_unpaired_distribution: usize,
    pub excluded_causal_contract_violation: usize,
    pub mahalanobis_distribution_missing: usize,
    pub supervised_distribution_missing: usize,
}

impl FoldSampleAccounting {
    fn validate(&self) -> Result<()> {
        if self.detected_test_states
            != self.excluded_fold_fit_or_scoring_failure
                + self.excluded_not_on_non_overlapping_horizon_grid
                + self.excluded_missing_strict_label
                + self.excluded_missing_causal_regime_posterior
                + self.eligible_before_budget
            || self.eligible_before_budget
                != self.excluded_by_preregistered_sample_budget + self.evaluated_queries
            || self.evaluated_queries
                != self.paired_scored_queries
                    + self.excluded_unpaired_distribution
                    + self.excluded_causal_contract_violation
        {
            bail!("fold sample/exclusion accounting does not reconcile");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct FutureReturnLoss {
    pub sample_count: usize,
    pub mean_squared_error: f64,
    pub mean_absolute_error: f64,
    pub directional_error_rate: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HmmFoldValidation {
    pub candidate_state_counts: Vec<usize>,
    pub selection_method: String,
    pub selection_fit_session_count: usize,
    pub selection_validation_session_count: usize,
    pub selection_fit_observation_count: usize,
    pub selection_validation_observation_count: usize,
    pub selected_state_count: usize,
    pub selected_at_maximum_candidate_boundary: bool,
    pub state_count_resolution: String,
    pub candidate_assessments: Vec<HmmCandidateAssessment>,
    pub test_used_for_state_or_k_selection: bool,
    pub refit_session_count: usize,
    pub refit_observation_count: usize,
    pub untouched_test_average_log_likelihood: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AnalogFoldValidation {
    pub active_metric: String,
    pub supervised_challenger_metric: String,
    pub active_covariance_inverse_status: String,
    pub supervised_metric_fit_horizon_minutes: Option<usize>,
    pub supervised_metric_training_label_count: usize,
    pub same_session_neighbors_observed: usize,
    pub lookahead_neighbor_violations: usize,
    pub score_population: String,
    pub unconditional_train_mean_loss: FutureReturnLoss,
    pub active_mahalanobis_loss: FutureReturnLoss,
    pub supervised_challenger_loss: FutureReturnLoss,
    pub supervised_minus_active_mse: f64,
    pub active_forecast_status_counts: BTreeMap<String, usize>,
    pub supervised_forecast_status_counts: BTreeMap<String, usize>,
    pub active_no_trade_reason_counts: BTreeMap<String, usize>,
    pub supervised_no_trade_reason_counts: BTreeMap<String, usize>,
    pub promotion_status: String,
    pub production_metric_after_comparison: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FoldValidationReport {
    pub fold: usize,
    pub status: String,
    pub partition: FoldPartition,
    pub fold_model_training_bounds: Option<IntervalBounds>,
    pub fit_inputs_sha256: Option<String>,
    pub fitted_model_sha256: Option<String>,
    pub untouched_test_evidence_sha256: Option<String>,
    pub training_state_count: usize,
    pub mature_training_label_count: usize,
    pub sample_accounting: FoldSampleAccounting,
    pub hmm: Option<HmmFoldValidation>,
    pub analog: Option<AnalogFoldValidation>,
    pub blockers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AggregateAnalogComparison {
    pub paired_test_sample_count: usize,
    pub successful_fold_count: usize,
    pub folds_meeting_minimum_paired_sample: usize,
    pub active_mahalanobis_loss: FutureReturnLoss,
    pub supervised_challenger_loss: FutureReturnLoss,
    pub unconditional_train_mean_loss: FutureReturnLoss,
    pub supervised_minus_active_mse: f64,
    pub challenger_lower_mse_fold_count: usize,
    pub conclusion: String,
    pub promotion_status: String,
    pub automatic_promotion_permitted: bool,
    pub production_metric_after_comparison: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReferenceArtifactAudit {
    pub artifact_sha256: String,
    pub model_hash: String,
    pub target: String,
    pub training_start: Option<DateTime<Utc>>,
    pub training_cutoff: DateTime<Utc>,
    pub expected_training_state_count: usize,
    pub observed_training_state_count: usize,
    pub expected_training_prefix_sha256: String,
    pub observed_training_prefix_sha256: Option<String>,
    pub exact_training_prefix_match: bool,
    pub selected_state_count: usize,
    pub selected_at_maximum_candidate_boundary: bool,
    pub state_count_resolution: String,
    pub interval_audits: Vec<ArtifactIntervalAudit>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OfflineModelValidationReport {
    pub schema_version: String,
    pub generated_at: DateTime<Utc>,
    pub status: String,
    pub evidence_grade: String,
    pub promotion_status: String,
    pub automatic_promotion_permitted: bool,
    pub production_artifact_or_config_mutated: bool,
    pub execution_enabled: bool,
    pub target: String,
    pub horizon_minutes: usize,
    pub source_path: String,
    pub source_sha256: String,
    pub code_commit_hash: String,
    pub states_sha256: String,
    pub strict_outcomes_sha256: String,
    pub research_config_sha256: String,
    pub validation_config_sha256: String,
    pub input_state_count: usize,
    pub input_session_count: usize,
    pub strict_label_accounting: StrictLabelAccounting,
    pub planned_fold_count: usize,
    pub successful_fold_count: usize,
    pub folds: Vec<FoldValidationReport>,
    pub fold_model_interval_audits: Vec<ArtifactIntervalAudit>,
    pub reference_artifact: Option<ReferenceArtifactAudit>,
    pub hmm_state_count_resolution: String,
    pub boundary_selected_folds: Vec<usize>,
    pub required_hmm_follow_up: Vec<String>,
    pub analog_comparison: AggregateAnalogComparison,
    pub blockers: Vec<String>,
    pub report_sha256: String,
}

impl OfflineModelValidationReport {
    fn unsigned_sha256(&self) -> Result<String> {
        let mut unsigned = self.clone();
        unsigned.report_sha256.clear();
        sha256_serialized(&unsigned)
    }

    pub fn validate_seal(&self) -> Result<()> {
        if self.report_sha256 != self.unsigned_sha256()? {
            bail!("offline validation report hash mismatch");
        }
        if self.promotion_status != CANDIDATE_NOT_PROMOTED
            || self.automatic_promotion_permitted
            || self.production_artifact_or_config_mutated
            || self.execution_enabled
        {
            bail!("offline validation report violates the fail-closed promotion contract");
        }
        for audit in self.fold_model_interval_audits.iter().chain(
            self.reference_artifact
                .iter()
                .flat_map(|artifact| artifact.interval_audits.iter()),
        ) {
            if audit.overlaps_artifact_training_bounds
                && (audit.oos_claim_permitted
                    || audit.evidence_label.starts_with("POST_TRAINING")
                    || (audit.evidence_label.contains("OUT_OF_SAMPLE")
                        && !audit.evidence_label.starts_with("NOT_OUT_OF_SAMPLE")))
            {
                bail!("overlapping artifact evidence was mislabeled as OOS");
            }
        }
        Ok(())
    }
}

fn sha256_serialized(value: &impl Serialize) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

fn day_set(days: &[NaiveDate]) -> BTreeSet<NaiveDate> {
    days.iter().copied().collect()
}

fn bounds_for_days(states: &[MarketState], days: &BTreeSet<NaiveDate>) -> Option<IntervalBounds> {
    let mut timestamps = states
        .iter()
        .filter(|state| days.contains(&state.session_date))
        .map(|state| state.timestamp);
    let start = timestamps.next()?;
    let mut end = start;
    for timestamp in timestamps {
        end = end.max(timestamp);
    }
    Some(IntervalBounds {
        start,
        end: end + Duration::minutes(1),
    })
}

fn observation(state: &MarketState) -> Vec<f64> {
    vec![
        state.active_5m_return,
        state.dist_vwap,
        state.rolling_realized_vol,
        state.volume_zscore,
    ]
}

fn hmm_sequences(states: &[MarketState], days: &BTreeSet<NaiveDate>) -> Vec<Vec<Vec<f64>>> {
    let mut sessions = BTreeMap::<NaiveDate, Vec<Vec<f64>>>::new();
    for state in states.iter().filter(|state| {
        days.contains(&state.session_date)
            && state.minute_in_5m_bucket == 4
            && state.completed_5m_bucket_valid
    }) {
        sessions
            .entry(state.session_date)
            .or_default()
            .push(observation(state));
    }
    sessions
        .into_values()
        .filter(|rows| !rows.is_empty())
        .collect()
}

fn observation_count(sequences: &[Vec<Vec<f64>>]) -> usize {
    sequences.iter().map(Vec::len).sum()
}

fn causal_regime_history(states: &[MarketState], model: &GaussianHmm) -> Result<Vec<Vec<f64>>> {
    let mut sessions = BTreeMap::<NaiveDate, Vec<(usize, Vec<f64>)>>::new();
    for (index, state) in states
        .iter()
        .enumerate()
        .filter(|(_, state)| state.minute_in_5m_bucket == 4 && state.completed_5m_bucket_valid)
    {
        sessions
            .entry(state.session_date)
            .or_default()
            .push((index, observation(state)));
    }
    let mut finalized = HashMap::<usize, Vec<f64>>::new();
    for rows in sessions.values() {
        let sequence = rows.iter().map(|(_, row)| row.clone()).collect::<Vec<_>>();
        for ((index, _), probabilities) in rows.iter().zip(model.filtered_probabilities(&sequence)?)
        {
            finalized.insert(*index, probabilities);
        }
    }
    let mut history = vec![Vec::new(); states.len()];
    let mut active_session = None;
    let mut latest = Vec::new();
    for (index, state) in states.iter().enumerate() {
        if active_session != Some(state.session_date) {
            active_session = Some(state.session_date);
            latest.clear();
        }
        if let Some(probabilities) = finalized.get(&index) {
            latest = probabilities.clone();
        }
        if !latest.is_empty() {
            history[index] = latest.clone();
        }
    }
    Ok(history)
}

fn analog_config(research: &ResearchConfig, metric: DistanceMetric) -> AnalogEngineConfig {
    AnalogEngineConfig {
        metric,
        neighbors: research.analog_neighbors,
        bandwidth_rule: BandwidthRule::AdaptiveKthNeighbor,
        bandwidth_multiplier: research.analog_bandwidth,
        regime_conditioned: true,
        regime_match_policy: if research.regime.require_same_dominant_state {
            RegimeMatchPolicy::SameDominantAndPosteriorCosine
        } else {
            RegimeMatchPolicy::PosteriorCosine
        },
        minimum_regime_similarity: research.regime.minimum_posterior_cosine_similarity,
        minimum_dominant_regime_probability: research.regime.minimum_dominant_probability,
        minimum_effective_sample_size: research.regime.minimum_effective_sample_size,
        ..AnalogEngineConfig::default()
    }
}

fn evenly_bounded(indices: &[usize], maximum: usize) -> Vec<usize> {
    if indices.len() <= maximum {
        return indices.to_vec();
    }
    (0..maximum)
        .map(|position| indices[position * indices.len() / maximum])
        .collect()
}

fn causal_forecast_violations(forecast: &AnalogForecast, query: &MarketState) -> (usize, usize) {
    let same_session = forecast
        .top_analogs
        .iter()
        .filter(|analog| analog.session_date >= query.session_date)
        .count();
    let lookahead = forecast
        .top_analogs
        .iter()
        .filter(|analog| {
            analog.analog_timestamp >= query.timestamp
                || analog.label_available_at > query.timestamp
        })
        .count();
    (same_session, lookahead)
}

fn increment(map: &mut BTreeMap<String, usize>, key: &str) {
    *map.entry(key.to_string()).or_default() += 1;
}

fn record_forecast_diagnostics(
    forecast: &AnalogForecast,
    statuses: &mut BTreeMap<String, usize>,
    reasons: &mut BTreeMap<String, usize>,
) {
    increment(statuses, &forecast.status);
    for reason in &forecast.no_trade_reasons {
        increment(reasons, reason);
    }
}

fn loss(predictions: &[f64], actuals: &[f64]) -> FutureReturnLoss {
    if predictions.is_empty() || predictions.len() != actuals.len() {
        return FutureReturnLoss::default();
    }
    let count = predictions.len() as f64;
    FutureReturnLoss {
        sample_count: predictions.len(),
        mean_squared_error: predictions
            .iter()
            .zip(actuals)
            .map(|(prediction, actual)| (prediction - actual).powi(2))
            .sum::<f64>()
            / count,
        mean_absolute_error: predictions
            .iter()
            .zip(actuals)
            .map(|(prediction, actual)| (prediction - actual).abs())
            .sum::<f64>()
            / count,
        directional_error_rate: predictions
            .iter()
            .zip(actuals)
            .map(|(prediction, actual)| {
                let probability: f64 = if *prediction > 0.0 { 1.0 } else { 0.0 };
                let label: f64 = if *actual > 0.0 { 1.0 } else { 0.0 };
                (probability - label).powi(2)
            })
            .sum::<f64>()
            / count,
    }
}

fn weighted_loss(rows: impl Iterator<Item = FutureReturnLoss>) -> FutureReturnLoss {
    let rows = rows.filter(|row| row.sample_count > 0).collect::<Vec<_>>();
    let samples = rows.iter().map(|row| row.sample_count).sum::<usize>();
    if samples == 0 {
        return FutureReturnLoss::default();
    }
    let weighted = |extract: fn(&FutureReturnLoss) -> f64| {
        rows.iter()
            .map(|row| extract(row) * row.sample_count as f64)
            .sum::<f64>()
            / samples as f64
    };
    FutureReturnLoss {
        sample_count: samples,
        mean_squared_error: weighted(|row| row.mean_squared_error),
        mean_absolute_error: weighted(|row| row.mean_absolute_error),
        directional_error_rate: weighted(|row| row.directional_error_rate),
    }
}

fn interval_for_days(
    name: String,
    role: &str,
    states: &[MarketState],
    days: &[NaiveDate],
) -> Option<NamedEvaluationInterval> {
    let bounds = bounds_for_days(states, &day_set(days))?;
    Some(NamedEvaluationInterval {
        name,
        role: role.into(),
        start: bounds.start,
        end: bounds.end,
    })
}

fn fold_partition(fold: &walk_forward::PurgedDayFold) -> Result<FoldPartition> {
    let mut partition = FoldPartition {
        train_days: fold.train_days.clone(),
        purged_days: fold.purged_days.clone(),
        selection_validation_days: fold.validation_days.clone(),
        embargoed_days: fold.embargoed_days.clone(),
        test_days: fold.test_days.clone(),
        partition_sha256: String::new(),
    };
    partition.partition_sha256 = sha256_serialized(&serde_json::json!({
        "train_days": partition.train_days,
        "purged_days": partition.purged_days,
        "selection_validation_days": partition.selection_validation_days,
        "embargoed_days": partition.embargoed_days,
        "test_days": partition.test_days,
    }))?;
    Ok(partition)
}

fn failed_fold(
    fold: usize,
    partition: FoldPartition,
    states: &[MarketState],
    outcomes: &[Outcome],
    blocker: impl Into<String>,
) -> FoldValidationReport {
    let mut training_days = day_set(&partition.train_days);
    training_days.extend(partition.selection_validation_days.iter().copied());
    let training_bounds = bounds_for_days(states, &training_days);
    let training_indices = states
        .iter()
        .enumerate()
        .filter(|(_, state)| training_days.contains(&state.session_date))
        .map(|(index, _)| index)
        .collect::<BTreeSet<_>>();
    let mature_training_label_count = training_bounds
        .as_ref()
        .map(|bounds| bounds.end - Duration::minutes(1))
        .map(|cutoff| {
            outcomes
                .iter()
                .filter(|outcome| {
                    training_indices.contains(&outcome.state_index)
                        && outcome.entry_timestamp
                            + Duration::minutes(outcome.horizon_minutes as i64)
                            <= cutoff
                })
                .count()
        })
        .unwrap_or_default();
    let detected_test_states = states
        .iter()
        .filter(|state| partition.test_days.contains(&state.session_date))
        .count();
    let sample_accounting = FoldSampleAccounting {
        detected_test_states,
        excluded_fold_fit_or_scoring_failure: detected_test_states,
        ..FoldSampleAccounting::default()
    };
    debug_assert!(sample_accounting.validate().is_ok());
    FoldValidationReport {
        fold,
        status: "FAIL_CLOSED_FOLD_NOT_SCORED".into(),
        partition,
        fold_model_training_bounds: training_bounds,
        fit_inputs_sha256: None,
        fitted_model_sha256: None,
        untouched_test_evidence_sha256: None,
        training_state_count: training_indices.len(),
        mature_training_label_count,
        sample_accounting,
        hmm: None,
        analog: None,
        blockers: vec![blocker.into()],
    }
}

fn evaluate_fold(
    fold_number: usize,
    partition: FoldPartition,
    states: &[MarketState],
    outcomes: &[Outcome],
    research: &ResearchConfig,
    validation: &OfflineValidationConfig,
) -> Result<FoldValidationReport> {
    let fit_days = day_set(&partition.train_days);
    let selection_days = day_set(&partition.selection_validation_days);
    let test_days = day_set(&partition.test_days);
    let mut model_train_days = fit_days.clone();
    model_train_days.extend(selection_days.iter().copied());
    let model_training_bounds =
        bounds_for_days(states, &model_train_days).context("fold training bounds are empty")?;

    let fit_sequences = hmm_sequences(states, &fit_days);
    let selection_sequences = hmm_sequences(states, &selection_days);
    let test_sequences = hmm_sequences(states, &test_days);
    if fit_sequences.is_empty() || selection_sequences.is_empty() || test_sequences.is_empty() {
        bail!("fold HMM partitions require completed five-minute observations");
    }
    let selected = select_hmm_candidates(
        &fit_sequences,
        Some(&selection_sequences),
        &research.regime.state_candidates,
        research.regime.max_iterations,
        research.regime.restarts,
        research.regime.minimum_state_occupancy_fraction,
        research.regime.minimum_state_expected_observations,
    )
    .context("train-only HMM state/K selection failed")?;
    let selected_state_count = selected.selected_state_count;
    let selected_at_boundary = selected.selected_at_candidate_boundary;
    let selection_method = selected.selection_method.to_string();
    let candidate_assessments = selected.candidate_assessments;

    let combined_sequences = hmm_sequences(states, &model_train_days);
    let refit = GaussianHmm::fit(
        &combined_sequences,
        selected_state_count,
        research.regime.max_iterations,
        research.regime.restarts,
    )
    .context("selected HMM could not be refit on all pre-test sessions")?;
    validate_hmm_state_occupancy(
        &refit,
        &combined_sequences,
        research.regime.minimum_state_occupancy_fraction,
        research.regime.minimum_state_expected_observations,
    )
    .context("pre-test HMM refit failed occupancy")?;
    let (hmm, _) = refit.canonicalized();
    let test_average_log_likelihood = hmm
        .average_log_likelihood(&test_sequences)
        .context("untouched fold-test HMM scoring failed")?;
    let regime_history = causal_regime_history(states, &hmm)?;

    let training_indices = states
        .iter()
        .enumerate()
        .filter(|(_, state)| model_train_days.contains(&state.session_date))
        .map(|(index, _)| index)
        .collect::<Vec<_>>();
    let training_index_set = training_indices.iter().copied().collect::<BTreeSet<_>>();
    // AnalogEngine's immutable fit clock is the latest indexed state
    // timestamp. A response that becomes available one minute later is not a
    // train label for this fit, even though that final bar itself is complete.
    let analog_metric_fit_cutoff = model_training_bounds.end - Duration::minutes(1);
    let mature_training_outcomes = outcomes
        .iter()
        .filter(|outcome| {
            training_index_set.contains(&outcome.state_index)
                && outcome.entry_timestamp + Duration::minutes(outcome.horizon_minutes as i64)
                    <= analog_metric_fit_cutoff
        })
        .cloned()
        .collect::<Vec<_>>();
    if mature_training_outcomes.len() < 10 {
        bail!("fold has fewer than ten mature train-only analog labels");
    }
    let active_engine = AnalogEngine::fit(
        states,
        &mature_training_outcomes,
        &training_indices,
        analog_config(research, DistanceMetric::ShrinkageMahalanobis),
    )
    .context("train-only shrinkage Mahalanobis fit failed")?;
    let supervised_engine = AnalogEngine::fit(
        states,
        &mature_training_outcomes,
        &training_indices,
        analog_config(research, DistanceMetric::RegularizedMetricLearning),
    )
    .context("train-label-only regularized metric fit failed")?;

    let fit_inputs_sha256 = sha256_serialized(&serde_json::json!({
        "partition_sha256": partition.partition_sha256,
        "training_indices": training_indices,
        "mature_training_outcomes": mature_training_outcomes,
        "state_candidates": research.regime.state_candidates,
        "hmm_max_iterations": research.regime.max_iterations,
        "hmm_restarts": research.regime.restarts,
        "minimum_state_occupancy_fraction": research.regime.minimum_state_occupancy_fraction,
        "minimum_state_expected_observations": research.regime.minimum_state_expected_observations,
        "analog_active_config": analog_config(research, DistanceMetric::ShrinkageMahalanobis),
        "analog_supervised_config": analog_config(research, DistanceMetric::RegularizedMetricLearning),
    }))?;
    let fitted_model_sha256 = sha256_serialized(&serde_json::json!({
        "hmm": hmm,
        "active_analog": active_engine,
        "supervised_analog": supervised_engine,
    }))?;

    let outcome_map = outcomes
        .iter()
        .map(|outcome| (outcome.state_index, outcome))
        .collect::<HashMap<_, _>>();
    let mut accounting = FoldSampleAccounting::default();
    let mut eligible = Vec::new();
    for (index, state) in states
        .iter()
        .enumerate()
        .filter(|(_, state)| test_days.contains(&state.session_date))
    {
        accounting.detected_test_states += 1;
        if state.minutes_from_open < 0
            || !(state.minutes_from_open as usize).is_multiple_of(validation.horizon_minutes)
        {
            accounting.excluded_not_on_non_overlapping_horizon_grid += 1;
        } else if !outcome_map.contains_key(&index) {
            accounting.excluded_missing_strict_label += 1;
        } else if regime_history
            .get(index)
            .is_none_or(|probabilities| probabilities.len() != hmm.states)
        {
            accounting.excluded_missing_causal_regime_posterior += 1;
        } else {
            eligible.push(index);
        }
    }
    accounting.eligible_before_budget = eligible.len();
    let selected_queries = evenly_bounded(&eligible, validation.maximum_test_queries_per_fold);
    accounting.excluded_by_preregistered_sample_budget = eligible.len() - selected_queries.len();
    accounting.evaluated_queries = selected_queries.len();

    let unconditional_train_mean = mature_training_outcomes
        .iter()
        .map(|outcome| outcome.directional_return)
        .sum::<f64>()
        / mature_training_outcomes.len() as f64;
    let mut actuals = Vec::new();
    let mut active_predictions = Vec::new();
    let mut supervised_predictions = Vec::new();
    let mut baseline_predictions = Vec::new();
    let mut scored_rows = Vec::new();
    let mut active_statuses = BTreeMap::new();
    let mut supervised_statuses = BTreeMap::new();
    let mut active_reasons = BTreeMap::new();
    let mut supervised_reasons = BTreeMap::new();
    let mut same_session_neighbors = 0usize;
    let mut lookahead_violations = 0usize;
    for query_index in selected_queries {
        let query = &states[query_index];
        let active = active_engine.query(
            states,
            &mature_training_outcomes,
            query_index,
            validation.horizon_minutes,
            Some(&regime_history),
        );
        let supervised = supervised_engine.query(
            states,
            &mature_training_outcomes,
            query_index,
            validation.horizon_minutes,
            Some(&regime_history),
        );
        record_forecast_diagnostics(&active, &mut active_statuses, &mut active_reasons);
        record_forecast_diagnostics(
            &supervised,
            &mut supervised_statuses,
            &mut supervised_reasons,
        );
        let (active_same_session, active_lookahead) = causal_forecast_violations(&active, query);
        let (supervised_same_session, supervised_lookahead) =
            causal_forecast_violations(&supervised, query);
        same_session_neighbors += active_same_session + supervised_same_session;
        lookahead_violations += active_lookahead + supervised_lookahead;
        if active_same_session + supervised_same_session + active_lookahead + supervised_lookahead
            > 0
        {
            accounting.excluded_causal_contract_violation += 1;
            continue;
        }
        let active_prediction = active
            .distribution
            .as_ref()
            .map(|distribution| distribution.kernel_weighted_mean);
        let supervised_prediction = supervised
            .distribution
            .as_ref()
            .map(|distribution| distribution.kernel_weighted_mean);
        if active_prediction.is_none() {
            accounting.mahalanobis_distribution_missing += 1;
        }
        if supervised_prediction.is_none() {
            accounting.supervised_distribution_missing += 1;
        }
        let (Some(active_prediction), Some(supervised_prediction)) =
            (active_prediction, supervised_prediction)
        else {
            accounting.excluded_unpaired_distribution += 1;
            continue;
        };
        let actual = outcome_map[&query_index].directional_return;
        actuals.push(actual);
        active_predictions.push(active_prediction);
        supervised_predictions.push(supervised_prediction);
        baseline_predictions.push(unconditional_train_mean);
        scored_rows.push(serde_json::json!({
            "query_index": query_index,
            "query_timestamp": query.timestamp,
            "label_available_at": outcome_map[&query_index].entry_timestamp
                + Duration::minutes(validation.horizon_minutes as i64),
            "actual_future_return": actual,
            "active_prediction": active_prediction,
            "supervised_prediction": supervised_prediction,
            "active_status": active.status,
            "supervised_status": supervised.status,
        }));
        accounting.paired_scored_queries += 1;
    }
    accounting.validate()?;

    let active_loss = loss(&active_predictions, &actuals);
    let supervised_loss = loss(&supervised_predictions, &actuals);
    let baseline_loss = loss(&baseline_predictions, &actuals);
    let untouched_test_evidence_sha256 = sha256_serialized(&serde_json::json!({
        "fold": fold_number,
        "test_days": partition.test_days,
        "horizon_minutes": validation.horizon_minutes,
        "score_population": "ALL_PAIRED_DISTRIBUTIONS_INCLUDING_MODEL_ABSTENTIONS",
        "rows": scored_rows,
    }))?;
    let active_covariance_status = active_engine.covariance_inverse_status().to_string();
    let supervised_horizon = supervised_engine.metric_fit_horizon_minutes();
    let supervised_label_count = supervised_engine.metric_training_label_count();
    if supervised_horizon != Some(validation.horizon_minutes)
        || supervised_label_count != mature_training_outcomes.len()
    {
        bail!("supervised metric fit lineage does not match the exact train-label contract");
    }

    let mut blockers = Vec::new();
    if accounting.paired_scored_queries < validation.minimum_paired_test_samples_per_fold {
        blockers.push("INSUFFICIENT_PAIRED_UNTOUCHED_TEST_SAMPLES".into());
    }
    if selected_at_boundary {
        blockers.push("HMM_STATE_COUNT_OPTIMUM_UNRESOLVED_AT_MAXIMUM_CANDIDATE_BOUNDARY".into());
    }
    if active_covariance_status != "shrinkage_covariance_inverse" {
        blockers.push("ACTIVE_MAHALANOBIS_COVARIANCE_INVERSE_UNAVAILABLE".into());
    }
    if same_session_neighbors > 0 || lookahead_violations > 0 {
        blockers.push("ANALOG_CAUSALITY_CONTRACT_VIOLATION".into());
    }
    let fold_status = if accounting.paired_scored_queries == 0 {
        "FAIL_CLOSED_NO_PAIRED_TEST_METRICS"
    } else if blockers.is_empty() {
        "PURGED_FOLD_TEST_METRICS_COMPLETE_RESEARCH_ONLY"
    } else {
        "PURGED_FOLD_TEST_METRICS_COMPLETE_WITH_PROMOTION_BLOCKERS"
    };
    Ok(FoldValidationReport {
        fold: fold_number,
        status: fold_status.into(),
        partition,
        fold_model_training_bounds: Some(model_training_bounds),
        fit_inputs_sha256: Some(fit_inputs_sha256),
        fitted_model_sha256: Some(fitted_model_sha256),
        untouched_test_evidence_sha256: Some(untouched_test_evidence_sha256),
        training_state_count: training_indices.len(),
        mature_training_label_count: mature_training_outcomes.len(),
        sample_accounting: accounting,
        hmm: Some(HmmFoldValidation {
            candidate_state_counts: research.regime.state_candidates.clone(),
            selection_method,
            selection_fit_session_count: fit_sequences.len(),
            selection_validation_session_count: selection_sequences.len(),
            selection_fit_observation_count: observation_count(&fit_sequences),
            selection_validation_observation_count: observation_count(&selection_sequences),
            selected_state_count,
            selected_at_maximum_candidate_boundary: selected_at_boundary,
            state_count_resolution: if selected_at_boundary {
                "OPTIMUM_UNRESOLVED_AT_MAXIMUM_CANDIDATE_BOUNDARY"
            } else {
                "INTERIOR_TRAIN_ONLY_SELECTION_RESEARCH_CANDIDATE"
            }
            .into(),
            candidate_assessments,
            test_used_for_state_or_k_selection: false,
            refit_session_count: combined_sequences.len(),
            refit_observation_count: observation_count(&combined_sequences),
            untouched_test_average_log_likelihood: test_average_log_likelihood,
        }),
        analog: Some(AnalogFoldValidation {
            active_metric: ACTIVE_ANALOG_METRIC.into(),
            supervised_challenger_metric: SUPERVISED_ANALOG_CHALLENGER.into(),
            active_covariance_inverse_status: active_covariance_status,
            supervised_metric_fit_horizon_minutes: supervised_horizon,
            supervised_metric_training_label_count: supervised_label_count,
            same_session_neighbors_observed: same_session_neighbors,
            lookahead_neighbor_violations: lookahead_violations,
            score_population: "ALL_PAIRED_DISTRIBUTIONS_INCLUDING_MODEL_ABSTENTIONS".into(),
            unconditional_train_mean_loss: baseline_loss,
            active_mahalanobis_loss: active_loss.clone(),
            supervised_challenger_loss: supervised_loss.clone(),
            supervised_minus_active_mse: supervised_loss.mean_squared_error
                - active_loss.mean_squared_error,
            active_forecast_status_counts: active_statuses,
            supervised_forecast_status_counts: supervised_statuses,
            active_no_trade_reason_counts: active_reasons,
            supervised_no_trade_reason_counts: supervised_reasons,
            promotion_status: CANDIDATE_NOT_PROMOTED.into(),
            production_metric_after_comparison: ACTIVE_ANALOG_METRIC.into(),
        }),
        blockers,
    })
}

fn reference_artifact_audit(
    artifact: &FrozenPredictorArtifact,
    states: &[MarketState],
    intervals: &[NamedEvaluationInterval],
) -> Result<ReferenceArtifactAudit> {
    artifact
        .validate_static()
        .context("reference frozen artifact failed immutable static validation")?;
    let prefix = states
        .iter()
        .filter(|state| {
            state.symbol.eq_ignore_ascii_case(&artifact.target)
                && state.timestamp + Duration::minutes(1) <= artifact.training_cutoff
        })
        .collect::<Vec<_>>();
    let training_start = prefix.first().map(|state| state.timestamp);
    let observed_prefix_sha256 = (!prefix.is_empty())
        .then(|| sha256_serialized(&prefix))
        .transpose()?;
    let exact_prefix = prefix.len() == artifact.training_state_count
        && observed_prefix_sha256.as_deref() == Some(&artifact.training_state_prefix_sha256);
    let interval_audits = training_start
        .map(|start| IntervalBounds {
            start,
            end: artifact.training_cutoff,
        })
        .map(|bounds| {
            intervals
                .iter()
                .map(|interval| {
                    audit_artifact_interval(
                        artifact.artifact_sha256.clone(),
                        bounds.clone(),
                        interval,
                    )
                })
                .collect()
        })
        .unwrap_or_default();
    let selected_at_boundary = artifact.regime_selection.selected_at_candidate_boundary;
    Ok(ReferenceArtifactAudit {
        artifact_sha256: artifact.artifact_sha256.clone(),
        model_hash: artifact.model_hash.clone(),
        target: artifact.target.clone(),
        training_start,
        training_cutoff: artifact.training_cutoff,
        expected_training_state_count: artifact.training_state_count,
        observed_training_state_count: prefix.len(),
        expected_training_prefix_sha256: artifact.training_state_prefix_sha256.clone(),
        observed_training_prefix_sha256: observed_prefix_sha256,
        exact_training_prefix_match: exact_prefix,
        selected_state_count: artifact.regime_selection.selected_state_count,
        selected_at_maximum_candidate_boundary: selected_at_boundary,
        state_count_resolution: if selected_at_boundary {
            "OPTIMUM_UNRESOLVED_AT_MAXIMUM_CANDIDATE_BOUNDARY"
        } else {
            "NOT_AT_MAXIMUM_CANDIDATE_BOUNDARY"
        }
        .into(),
        interval_audits,
        status: if training_start.is_none() {
            "TRAINING_BOUNDS_UNAVAILABLE_FAIL_CLOSED"
        } else if exact_prefix {
            "EXACT_TRAINING_PREFIX_VERIFIED"
        } else {
            "TRAINING_PREFIX_MISMATCH_FAIL_CLOSED"
        }
        .into(),
    })
}

#[allow(clippy::too_many_arguments)]
pub fn evaluate_offline_frozen_model(
    states: &[MarketState],
    research: &ResearchConfig,
    validation: &OfflineValidationConfig,
    lineage: &OfflineValidationLineage,
    reference_artifact: Option<&FrozenPredictorArtifact>,
) -> Result<OfflineModelValidationReport> {
    validation.validate()?;
    lineage.validate()?;
    if states.is_empty()
        || states
            .iter()
            .any(|state| !state.symbol.eq_ignore_ascii_case(&research.target))
    {
        bail!("offline validation requires non-empty, target-only feature states");
    }
    if states
        .windows(2)
        .any(|pair| pair[0].timestamp >= pair[1].timestamp)
    {
        bail!("offline validation states must be strictly chronological");
    }
    let (outcomes, strict_label_accounting) =
        strict_forward_outcomes(states, validation.horizon_minutes)?;
    let session_dates = states
        .iter()
        .map(|state| state.session_date)
        .collect::<Vec<_>>();
    let input_sessions = session_dates.iter().copied().collect::<BTreeSet<_>>();
    let folds = walk_forward::expanding_day_folds(
        &session_dates,
        validation.initial_train_days,
        validation.selection_validation_days,
        validation.test_days,
        validation.purge_days,
        validation.embargo_days,
    )
    .into_iter()
    .take(validation.maximum_folds)
    .collect::<Vec<_>>();

    let mut fold_reports = Vec::with_capacity(folds.len());
    let mut fold_intervals = Vec::new();
    let mut evaluation_intervals = lineage.displayed_replay_or_external_test_intervals.clone();
    for (index, fold) in folds.iter().enumerate() {
        let partition = fold_partition(fold)?;
        let fold_number = index + 1;
        if let Some(selection_interval) = interval_for_days(
            format!("fold_{fold_number}_state_selection_validation"),
            "HMM_STATE_AND_K_SELECTION_VALIDATION_NOT_FOLD_TEST",
            states,
            &partition.selection_validation_days,
        ) {
            evaluation_intervals.push(selection_interval.clone());
        }
        if let Some(test_interval) = interval_for_days(
            format!("fold_{fold_number}_untouched_test"),
            "PURGED_UNTOUCHED_FOLD_TEST",
            states,
            &partition.test_days,
        ) {
            evaluation_intervals.push(test_interval.clone());
        }
        match evaluate_fold(
            fold_number,
            partition.clone(),
            states,
            &outcomes,
            research,
            validation,
        ) {
            Ok(report) => {
                if let Some(training_bounds) = report.fold_model_training_bounds.clone() {
                    if let Some(selection_interval) = interval_for_days(
                        format!("fold_{fold_number}_state_selection_validation"),
                        "HMM_STATE_AND_K_SELECTION_VALIDATION_NOT_FOLD_TEST",
                        states,
                        &partition.selection_validation_days,
                    ) {
                        fold_intervals.push(audit_artifact_interval(
                            format!("offline_fold_{fold_number}_refit_model"),
                            training_bounds.clone(),
                            &selection_interval,
                        ));
                    }
                    if let Some(test_interval) = interval_for_days(
                        format!("fold_{fold_number}_untouched_test"),
                        "PURGED_UNTOUCHED_FOLD_TEST",
                        states,
                        &partition.test_days,
                    ) {
                        fold_intervals.push(audit_artifact_interval(
                            format!("offline_fold_{fold_number}_refit_model"),
                            training_bounds,
                            &test_interval,
                        ));
                    }
                }
                fold_reports.push(report);
            }
            Err(error) => fold_reports.push(failed_fold(
                fold_number,
                partition,
                states,
                &outcomes,
                format!("{error:#}"),
            )),
        }
    }

    let reference_artifact = reference_artifact
        .map(|artifact| reference_artifact_audit(artifact, states, &evaluation_intervals))
        .transpose()?;
    let successful = fold_reports
        .iter()
        .filter(|fold| fold.analog.is_some() && fold.hmm.is_some())
        .count();
    let boundary_folds = fold_reports
        .iter()
        .filter(|fold| {
            fold.hmm
                .as_ref()
                .is_some_and(|hmm| hmm.selected_at_maximum_candidate_boundary)
        })
        .map(|fold| fold.fold)
        .collect::<Vec<_>>();
    let reference_boundary = reference_artifact
        .as_ref()
        .is_some_and(|artifact| artifact.selected_at_maximum_candidate_boundary);
    let active_aggregate = weighted_loss(
        fold_reports
            .iter()
            .filter_map(|fold| fold.analog.as_ref())
            .map(|analog| analog.active_mahalanobis_loss.clone()),
    );
    let supervised_aggregate = weighted_loss(
        fold_reports
            .iter()
            .filter_map(|fold| fold.analog.as_ref())
            .map(|analog| analog.supervised_challenger_loss.clone()),
    );
    let baseline_aggregate = weighted_loss(
        fold_reports
            .iter()
            .filter_map(|fold| fold.analog.as_ref())
            .map(|analog| analog.unconditional_train_mean_loss.clone()),
    );
    let folds_meeting_sample = fold_reports
        .iter()
        .filter(|fold| {
            fold.sample_accounting.paired_scored_queries
                >= validation.minimum_paired_test_samples_per_fold
        })
        .count();
    let challenger_lower_mse_folds = fold_reports
        .iter()
        .filter_map(|fold| fold.analog.as_ref())
        .filter(|analog| {
            analog.supervised_challenger_loss.sample_count > 0
                && analog.supervised_challenger_loss.mean_squared_error
                    < analog.active_mahalanobis_loss.mean_squared_error
        })
        .count();
    let comparison_conclusion = if supervised_aggregate.sample_count == 0 {
        "INSUFFICIENT_PAIRED_TEST_METRICS_FAIL_CLOSED"
    } else if supervised_aggregate.mean_squared_error < active_aggregate.mean_squared_error {
        "SUPERVISED_CHALLENGER_LOWER_TEST_MSE_RESEARCH_ONLY_NOT_SELECTED"
    } else {
        "SUPERVISED_CHALLENGER_DID_NOT_LOWER_TEST_MSE"
    };
    let analog_comparison = AggregateAnalogComparison {
        paired_test_sample_count: supervised_aggregate.sample_count,
        successful_fold_count: successful,
        folds_meeting_minimum_paired_sample: folds_meeting_sample,
        active_mahalanobis_loss: active_aggregate.clone(),
        supervised_challenger_loss: supervised_aggregate.clone(),
        unconditional_train_mean_loss: baseline_aggregate,
        supervised_minus_active_mse: supervised_aggregate.mean_squared_error
            - active_aggregate.mean_squared_error,
        challenger_lower_mse_fold_count: challenger_lower_mse_folds,
        conclusion: comparison_conclusion.into(),
        promotion_status: CANDIDATE_NOT_PROMOTED.into(),
        automatic_promotion_permitted: false,
        production_metric_after_comparison: ACTIVE_ANALOG_METRIC.into(),
    };

    let mut blockers = Vec::new();
    if folds.len() < validation.minimum_required_folds {
        blockers.push("INSUFFICIENT_PLANNED_CHRONOLOGICAL_FOLDS".into());
    }
    if successful < validation.minimum_required_folds {
        blockers.push("INSUFFICIENT_SUCCESSFULLY_SCORED_CHRONOLOGICAL_FOLDS".into());
    }
    if folds_meeting_sample < validation.minimum_required_folds {
        blockers.push("INSUFFICIENT_PAIRED_TEST_SAMPLE_ACROSS_REQUIRED_FOLDS".into());
    }
    if !boundary_folds.is_empty() || reference_boundary {
        blockers.push("HMM_STATE_COUNT_OPTIMUM_UNRESOLVED_AT_MAXIMUM_CANDIDATE_BOUNDARY".into());
    }
    if fold_reports.iter().any(|fold| {
        fold.analog.as_ref().is_some_and(|analog| {
            analog.active_covariance_inverse_status != "shrinkage_covariance_inverse"
        })
    }) {
        blockers.push("ACTIVE_MAHALANOBIS_FELL_BACK_IN_AT_LEAST_ONE_FOLD".into());
    }
    if reference_artifact
        .as_ref()
        .is_some_and(|artifact| !artifact.exact_training_prefix_match)
    {
        blockers.push("REFERENCE_ARTIFACT_TRAINING_PREFIX_NOT_VERIFIED".into());
    }
    if reference_artifact.as_ref().is_some_and(|artifact| {
        artifact
            .interval_audits
            .iter()
            .any(|audit| !audit.oos_claim_permitted)
    }) {
        blockers.push("REFERENCE_ARTIFACT_EVIDENCE_INTERVAL_NOT_STRICTLY_POST_TRAINING".into());
    }
    blockers.push("FORWARD_SHADOW_AND_MANUAL_PROMOTION_GOVERNANCE_NOT_SATISFIED".into());
    blockers.sort();
    blockers.dedup();

    let boundary_unresolved = !boundary_folds.is_empty() || reference_boundary;
    let required_hmm_follow_up = if boundary_unresolved {
        vec![
            "Run an offline nested selection with an expanded preregistered candidate family, without changing the current production artifact or configuration.".into(),
            "Alternatively compare a preregistered simpler regime challenger on new untouched folds; never choose K from fold-test scores.".into(),
            "Require an interior, stable train-only optimum before any separate promotion review.".into(),
        ]
    } else {
        vec![
            "Retain train-only K selection and confirm stability on new untouched forward folds before promotion review.".into(),
        ]
    };
    let status = if successful < validation.minimum_required_folds
        || supervised_aggregate.sample_count == 0
    {
        "OFFLINE_VALIDATION_INSUFFICIENT_FAIL_CLOSED"
    } else if boundary_unresolved {
        "OFFLINE_VALIDATION_COMPLETE_HMM_OPTIMUM_UNRESOLVED"
    } else {
        "OFFLINE_VALIDATION_COMPLETE_RESEARCH_ONLY"
    };

    let mut report = OfflineModelValidationReport {
        schema_version: OFFLINE_MODEL_VALIDATION_SCHEMA_VERSION.into(),
        generated_at: lineage.generated_at,
        status: status.into(),
        evidence_grade: EVIDENCE_GRADE.into(),
        promotion_status: CANDIDATE_NOT_PROMOTED.into(),
        automatic_promotion_permitted: false,
        production_artifact_or_config_mutated: false,
        execution_enabled: false,
        target: research.target.to_ascii_uppercase(),
        horizon_minutes: validation.horizon_minutes,
        source_path: lineage.source_path.clone(),
        source_sha256: lineage.source_sha256.to_ascii_lowercase(),
        code_commit_hash: lineage.code_commit_hash.clone(),
        states_sha256: sha256_serialized(&states)?,
        strict_outcomes_sha256: sha256_serialized(&outcomes)?,
        research_config_sha256: sha256_serialized(research)?,
        validation_config_sha256: sha256_serialized(validation)?,
        input_state_count: states.len(),
        input_session_count: input_sessions.len(),
        strict_label_accounting,
        planned_fold_count: folds.len(),
        successful_fold_count: successful,
        folds: fold_reports,
        fold_model_interval_audits: fold_intervals,
        reference_artifact,
        hmm_state_count_resolution: if boundary_unresolved {
            "OPTIMUM_UNRESOLVED_AT_MAXIMUM_CANDIDATE_BOUNDARY"
        } else {
            "NO_MAXIMUM_BOUNDARY_SELECTION_OBSERVED_RESEARCH_ONLY"
        }
        .into(),
        boundary_selected_folds: boundary_folds,
        required_hmm_follow_up,
        analog_comparison,
        blockers,
        report_sha256: String::new(),
    };
    report.report_sha256 = report.unsigned_sha256()?;
    report.validate_seal()?;
    Ok(report)
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, NaiveDate, TimeZone, Utc};

    use super::{
        CANDIDATE_NOT_PROMOTED, FoldSampleAccounting, IntervalBounds, NamedEvaluationInterval,
        OfflineValidationConfig, OfflineValidationLineage, audit_artifact_interval,
        evaluate_offline_frozen_model, strict_forward_outcomes,
    };
    use crate::{
        config::{RegimeResearchConfig, ResearchConfig},
        domain::MarketState,
    };

    fn state(day: usize, minute: usize) -> MarketState {
        let session_date =
            NaiveDate::from_ymd_opt(2025, 1, 1).unwrap() + Duration::days(day as i64);
        let timestamp = Utc.with_ymd_and_hms(2025, 1, 1, 14, 30, 0).unwrap()
            + Duration::days(day as i64)
            + Duration::minutes(minute as i64);
        let regime = if (day / 3).is_multiple_of(2) {
            1.0
        } else {
            -1.0
        };
        let noise = (day as f64 * 0.31 + minute as f64 * 0.17).sin() * 0.0004;
        let feature = regime * 0.002 + noise;
        let open = 100.0 * (1.0 + day as f64 * 0.0005 + regime * minute as f64 * 0.00008);
        let close = open * (1.0 + regime * 0.0003 + noise * 0.1);
        MarketState {
            timestamp,
            session_date,
            symbol: "SPY".into(),
            open,
            high: open.max(close) * 1.0001,
            low: open.min(close) * 0.9999,
            close,
            atr: 0.5,
            ret_1m: feature + minute as f64 * 0.00001,
            ret_3m: feature * 1.2,
            ret_5m: feature * 1.4,
            ret_15m: feature * 1.6,
            ret_30m: feature * 1.8,
            ret_60m: feature * 2.0,
            active_5m_return: feature,
            last_completed_5m_return: feature * 0.9,
            last_completed_15m_return: feature * 0.8,
            slope_15m: feature * 0.7 + day as f64 * 0.00001,
            dist_vwap: feature * 0.6 + minute as f64 * 0.00002,
            dist_session_open: feature * 0.5,
            rolling_realized_vol: 0.005 + feature.abs() + minute as f64 * 0.000001,
            normalized_range: 0.004 + noise.abs(),
            upper_wick_ratio: 0.2 + noise.abs(),
            lower_wick_ratio: 0.2 + noise.abs() * 0.5,
            close_location_value: regime * 0.5,
            distance_session_high: -0.002 - noise.abs(),
            distance_session_low: 0.002 + noise.abs(),
            failed_opening_breakout: 0.0,
            consecutive_up_bars: usize::from(regime > 0.0) as i32,
            consecutive_down_bars: usize::from(regime < 0.0) as i32,
            return_acceleration: noise,
            volume_zscore: regime * 0.8 + noise * 100.0 + day as f64 * 0.001,
            volume_acceleration: noise * 10.0,
            session_range_position: (0.5 + regime * 0.2 + noise * 10.0).clamp(0.0, 1.0),
            cross_asset_breadth_score: regime * 0.6 + noise * 20.0,
            risk_rotation_score: regime * 0.4 + noise * 10.0,
            market_confirmation_score: regime * 0.3,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0 + day as f64 * 0.002 + noise.abs(),
            minutes_from_open: minute as i32,
            minutes_to_close: 390 - minute as i32,
            bucket_5m: (minute / 5) as i32,
            bucket_15m: (minute / 15) as i32,
            minute_in_5m_bucket: (minute % 5) as i32,
            completed_5m_bucket_valid: minute % 5 == 4,
            continuous_minute_count: minute + 1,
        }
    }

    fn states(session_count: usize, minutes_per_session: usize) -> Vec<MarketState> {
        (0..session_count)
            .flat_map(|day| (0..minutes_per_session).map(move |minute| state(day, minute)))
            .collect()
    }

    fn research() -> ResearchConfig {
        ResearchConfig {
            target: "SPY".into(),
            targets: Vec::new(),
            timezone: "America/New_York".into(),
            session_open: "09:30".into(),
            session_close: "16:00".into(),
            horizons: vec![5],
            max_trades_per_day: 2,
            cooldown_minutes: 30,
            analog_neighbors: 20,
            analog_bandwidth: 1.0,
            validation_score_threshold: 0.0,
            stop_bps: 10.0,
            take_profit_bps: 20.0,
            max_holding_minutes: 5,
            underlying_slippage_bps: 0.5,
            commission_per_trade: 0.0,
            option_slippage: 0.05,
            option_max_spread_pct: 0.20,
            option_max_staleness_seconds: 60,
            regime: RegimeResearchConfig {
                state_candidates: vec![2],
                validation_fraction: 0.20,
                minimum_validation_sessions: 2,
                max_iterations: 8,
                restarts: 1,
                require_same_dominant_state: false,
                minimum_dominant_probability: 0.0,
                minimum_posterior_cosine_similarity: -1.0,
                maximum_normalized_entropy: 1.0,
                minimum_effective_sample_size: 0.0,
                minimum_state_occupancy_fraction: 0.000_001,
                minimum_state_expected_observations: 0.01,
            },
        }
    }

    #[test]
    fn overlapping_artifact_interval_is_never_labeled_oos() {
        let training = IntervalBounds {
            start: Utc.with_ymd_and_hms(2025, 1, 1, 14, 30, 0).unwrap(),
            end: Utc.with_ymd_and_hms(2025, 1, 10, 21, 0, 0).unwrap(),
        };
        let overlap = NamedEvaluationInterval {
            name: "displayed_replay".into(),
            role: "DISPLAYED_REPLAY".into(),
            start: Utc.with_ymd_and_hms(2025, 1, 5, 14, 30, 0).unwrap(),
            end: Utc.with_ymd_and_hms(2025, 1, 12, 21, 0, 0).unwrap(),
        };
        let audit = audit_artifact_interval("artifact", training.clone(), &overlap);
        assert!(audit.overlaps_artifact_training_bounds);
        assert!(!audit.oos_claim_permitted);
        assert_eq!(
            audit.evidence_label,
            "NOT_OUT_OF_SAMPLE_OVERLAPS_ARTIFACT_TRAINING"
        );

        let post = NamedEvaluationInterval {
            name: "future_test".into(),
            role: "UNTOUCHED_TEST".into(),
            start: training.end + Duration::seconds(1),
            end: training.end + Duration::days(1),
        };
        let audit = audit_artifact_interval("artifact", training, &post);
        assert!(audit.oos_claim_permitted);
        assert_eq!(
            audit.evidence_label,
            "POST_TRAINING_CHRONOLOGICAL_EVALUATION"
        );
    }

    #[test]
    fn strict_labels_reject_missing_minutes_and_reconcile_every_candidate() {
        let mut rows = states(2, 12);
        rows[5].timestamp += Duration::minutes(1);
        let (outcomes, accounting) = strict_forward_outcomes(&rows, 5).unwrap();
        assert!(!outcomes.is_empty());
        assert!(accounting.excluded_non_contiguous_timestamps > 0);
        assert_eq!(
            accounting.candidate_state_count,
            accounting.valid_label_count
                + accounting.excluded_insufficient_remaining_bars
                + accounting.excluded_cross_session_or_symbol
                + accounting.excluded_non_contiguous_timestamps
                + accounting.excluded_invalid_prices_or_returns
        );
    }

    #[test]
    fn sample_accounting_rejects_a_missing_exclusion() {
        let accounting = FoldSampleAccounting {
            detected_test_states: 10,
            excluded_not_on_non_overlapping_horizon_grid: 2,
            excluded_missing_strict_label: 1,
            excluded_missing_causal_regime_posterior: 1,
            eligible_before_budget: 5,
            ..FoldSampleAccounting::default()
        };
        assert!(accounting.validate().is_err());
    }

    #[test]
    fn offline_comparison_computes_real_fold_test_losses_but_never_promotes() {
        let states = states(36, 31);
        let validation = OfflineValidationConfig {
            horizon_minutes: 5,
            initial_train_days: 14,
            selection_validation_days: 4,
            test_days: 4,
            purge_days: 1,
            embargo_days: 1,
            minimum_required_folds: 2,
            maximum_folds: 3,
            maximum_test_queries_per_fold: 100,
            minimum_paired_test_samples_per_fold: 5,
        };
        let lineage = OfflineValidationLineage {
            generated_at: Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap(),
            source_path: "fixture://strict-minute-states".into(),
            source_sha256: "a".repeat(64),
            code_commit_hash: "test-commit".into(),
            displayed_replay_or_external_test_intervals: Vec::new(),
        };
        let report =
            evaluate_offline_frozen_model(&states, &research(), &validation, &lineage, None)
                .unwrap();
        report.validate_seal().unwrap();
        assert_eq!(report.successful_fold_count, 3);
        assert!(report.analog_comparison.paired_test_sample_count > 0);
        assert_eq!(
            report
                .analog_comparison
                .active_mahalanobis_loss
                .sample_count,
            report
                .analog_comparison
                .supervised_challenger_loss
                .sample_count
        );
        assert_eq!(report.promotion_status, CANDIDATE_NOT_PROMOTED);
        assert!(!report.automatic_promotion_permitted);
        assert_eq!(
            report.hmm_state_count_resolution,
            "OPTIMUM_UNRESOLVED_AT_MAXIMUM_CANDIDATE_BOUNDARY"
        );
        assert!(report.folds.iter().all(|fold| {
            fold.hmm
                .as_ref()
                .is_some_and(|hmm| !hmm.test_used_for_state_or_k_selection)
        }));
        assert!(report.folds.iter().all(|fold| {
            fold.analog.as_ref().is_some_and(|analog| {
                analog.same_session_neighbors_observed == 0
                    && analog.lookahead_neighbor_violations == 0
                    && analog.promotion_status == CANDIDATE_NOT_PROMOTED
            })
        }));
    }
}
