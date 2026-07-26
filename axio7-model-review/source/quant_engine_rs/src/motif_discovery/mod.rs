//! Leakage-aware discovery of repeated normalized return paths.
//!
//! The public input type intentionally has no price-level field. Discovery is
//! performed only on returns, volatility-adjusted returns, residual returns,
//! relative-strength returns, or changes in volume/volatility. Candidate
//! prototypes are frozen on the discovery partition, their direction is chosen
//! on validation data, and cost-aware evidence is measured on untouched test
//! occurrences. A passing motif remains a research candidate, never an order.

use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    error::Error,
    fmt,
};

use chrono::{DateTime, Datelike, Duration, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const MOTIF_SCHEMA_VERSION: u32 = 2;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum PathValueKind {
    LogReturn,
    VolatilityAdjustedReturn,
    ResidualReturn,
    RelativeStrengthReturn,
    VolumeLogChange,
    VolatilityChange,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReturnPathSeries {
    pub symbol: String,
    pub resolution_minutes: usize,
    pub value_kind: PathValueKind,
    pub timestamps: Vec<DateTime<Utc>>,
    pub available_at: Vec<DateTime<Utc>>,
    pub session_dates: Vec<NaiveDate>,
    pub values: Vec<f64>,
}

impl ReturnPathSeries {
    pub fn validate(&self) -> Result<(), MotifError> {
        let rows = self.values.len();
        if self.symbol.trim().is_empty()
            || self.resolution_minutes == 0
            || rows < 2
            || self.timestamps.len() != rows
            || self.available_at.len() != rows
            || self.session_dates.len() != rows
        {
            return Err(MotifError::InvalidSeries(
                "series metadata lengths or identity are invalid".into(),
            ));
        }
        if self.values.iter().any(|value| !value.is_finite()) {
            return Err(MotifError::InvalidSeries(
                "return-path values must be finite".into(),
            ));
        }
        for index in 0..rows {
            if self.available_at[index] < self.timestamps[index] {
                return Err(MotifError::InvalidSeries(
                    "availability cannot precede event time".into(),
                ));
            }
            if index > 0 && self.timestamps[index] <= self.timestamps[index - 1] {
                return Err(MotifError::InvalidSeries(
                    "timestamps must be strictly increasing".into(),
                ));
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifForwardOutcome {
    /// Index of the last observation in the matched path. The outcome starts
    /// after this index; it is never part of the motif distance calculation.
    pub anchor_end_index: usize,
    /// Exact terminal observation used to calculate `forward_return`. Its
    /// timestamp must equal anchor timestamp plus `horizon_minutes`, and its
    /// availability must precede the label availability timestamp.
    pub horizon_end_index: usize,
    pub horizon_minutes: usize,
    pub forward_return: f64,
    pub label_available_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifDiscoveryConfig {
    /// Supports the requested 3/5/10/15/30/60-observation research windows.
    pub window_observations: Vec<usize>,
    pub exclusion_zone_observations: usize,
    pub maximum_normalized_distance: f64,
    pub maximum_candidates_per_window: usize,
    pub minimum_occurrences: usize,
    pub minimum_independent_days: usize,
    pub maximum_day_concentration: f64,
    pub maximum_month_concentration: f64,
    pub recent_session_window: usize,
    pub minimum_recent_rate_ratio: f64,
    pub minimum_validation_occurrences: usize,
    pub minimum_test_occurrences: usize,
    pub minimum_test_independent_days: usize,
    /// Calendar-day embargo after both discovery and validation. Occurrences
    /// inside either embargo are retained for audit but never score evidence.
    pub partition_purge_calendar_days: usize,
    pub outcome_horizon_minutes: usize,
    pub round_trip_cost_bps: f64,
    pub minimum_test_net_mean_bps: f64,
    /// Resamples whole test days, preserving same-day dependence rather than
    /// treating every overlapping occurrence as an independent draw.
    pub day_block_bootstrap_resamples: usize,
    pub day_block_bootstrap_confidence_level: f64,
    /// The untouched-test daily-block interval must clear this lower bound.
    pub minimum_test_net_bootstrap_ci_lower_bps: f64,
    pub discovery_end: NaiveDate,
    pub validation_end: NaiveDate,
    pub test_end: NaiveDate,
    /// Hard point-in-time cutoff for every feature value and every outcome label.
    pub evidence_available_as_of: DateTime<Utc>,
    pub change_point_minimum_observations: usize,
    pub change_point_score_threshold: f64,
    pub negative_control_seed: u64,
    pub negative_control_match_tolerance_bps: f64,
}

impl MotifDiscoveryConfig {
    pub fn validate(&self) -> Result<(), MotifError> {
        if self.window_observations.is_empty()
            || self.window_observations.contains(&0)
            || self.maximum_candidates_per_window == 0
            || self.minimum_occurrences < 2
            || self.minimum_independent_days < 2
            || self.recent_session_window == 0
            || self.minimum_validation_occurrences == 0
            || self.minimum_test_occurrences == 0
            || self.minimum_test_independent_days == 0
            || self.partition_purge_calendar_days == 0
            || self.outcome_horizon_minutes == 0
            || self.day_block_bootstrap_resamples < 200
            || self.change_point_minimum_observations == 0
        {
            return Err(MotifError::InvalidConfiguration(
                "window and sample thresholds must be positive".into(),
            ));
        }
        let probabilities = [
            self.maximum_day_concentration,
            self.maximum_month_concentration,
        ];
        if probabilities
            .into_iter()
            .any(|value| !value.is_finite() || !(0.0..=1.0).contains(&value))
            || !self.maximum_normalized_distance.is_finite()
            || self.maximum_normalized_distance <= 0.0
            || !self.minimum_recent_rate_ratio.is_finite()
            || self.minimum_recent_rate_ratio < 0.0
            || !self.round_trip_cost_bps.is_finite()
            || self.round_trip_cost_bps < 0.0
            || !self.minimum_test_net_mean_bps.is_finite()
            || !self.day_block_bootstrap_confidence_level.is_finite()
            || !(0.0..1.0).contains(&self.day_block_bootstrap_confidence_level)
            || !self.minimum_test_net_bootstrap_ci_lower_bps.is_finite()
            || !self.change_point_score_threshold.is_finite()
            || self.change_point_score_threshold <= 0.0
            || !self.negative_control_match_tolerance_bps.is_finite()
            || self.negative_control_match_tolerance_bps < 0.0
        {
            return Err(MotifError::InvalidConfiguration(
                "distance, concentration, cost, or diagnostic threshold is invalid".into(),
            ));
        }
        if !(self.discovery_end < self.validation_end && self.validation_end < self.test_end) {
            return Err(MotifError::InvalidConfiguration(
                "discovery, validation, and test cutoffs must be ordered".into(),
            ));
        }
        let purge_days = i64::try_from(self.partition_purge_calendar_days).map_err(|_| {
            MotifError::InvalidConfiguration("partition purge gap is too large".into())
        })?;
        let discovery_purge_end = self
            .discovery_end
            .checked_add_signed(Duration::days(purge_days))
            .ok_or_else(|| {
                MotifError::InvalidConfiguration("discovery purge gap overflows date".into())
            })?;
        let validation_purge_end = self
            .validation_end
            .checked_add_signed(Duration::days(purge_days))
            .ok_or_else(|| {
                MotifError::InvalidConfiguration("validation purge gap overflows date".into())
            })?;
        if discovery_purge_end >= self.validation_end || validation_purge_end >= self.test_end {
            return Err(MotifError::InvalidConfiguration(
                "partition cutoffs must leave observations after each purge gap".into(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MotifPartition {
    Discovery,
    Purged,
    Validation,
    Test,
    ForwardShadow,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MatrixProfileEntry {
    pub query_start_index: usize,
    pub nearest_neighbor_start_index: usize,
    pub normalized_distance: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifMetadata {
    pub value_kind: PathValueKind,
    pub resolution_minutes: usize,
    pub window_observations: usize,
    pub duration_minutes: usize,
    pub normalization: String,
    pub distance_metric: String,
    pub discovery_cutoff: NaiveDate,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifOccurrence {
    pub start_index: usize,
    pub end_index: usize,
    pub start_timestamp: DateTime<Utc>,
    pub end_timestamp: DateTime<Utc>,
    pub session_date: NaiveDate,
    pub partition: MotifPartition,
    pub normalized_distance: f64,
    pub similarity_weight: f64,
    pub forward_return: Option<f64>,
    pub label_available_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OccurrenceConcentration {
    pub occurrence_count: usize,
    pub independent_days: usize,
    pub independent_months: usize,
    pub maximum_day_share: f64,
    pub maximum_month_share: f64,
    pub effective_day_count: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RecentDecayDiagnostic {
    pub recent_session_window: usize,
    pub recent_sessions: usize,
    pub historical_sessions: usize,
    pub recent_occurrences: usize,
    pub historical_occurrences: usize,
    pub recent_rate: f64,
    pub historical_rate: f64,
    pub recent_to_historical_rate_ratio: f64,
    pub sufficient_history: bool,
    pub decayed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DayBlockBootstrapCi {
    pub complete: bool,
    pub resamples: usize,
    pub confidence_level: f64,
    pub independent_days: usize,
    pub observed_mean_bps: f64,
    pub lower_bps: Option<f64>,
    pub upper_bps: Option<f64>,
    pub minimum_required_lower_bps: f64,
    pub passed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifOosEvidence {
    pub direction_selected_on: String,
    pub selected_direction: i8,
    pub validation_occurrences: usize,
    pub validation_mean_return_bps: f64,
    pub test_occurrences: usize,
    pub test_independent_days: usize,
    pub test_gross_mean_bps: f64,
    pub test_net_mean_bps: f64,
    pub test_net_win_rate: f64,
    pub test_net_day_block_bootstrap: DayBlockBootstrapCi,
    pub forward_shadow_occurrences: usize,
    pub assumed_round_trip_cost_bps: f64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MotifNegativeControl {
    TimestampShuffle,
    ReturnSignShuffle,
    RandomMotif,
    RandomAnalogNeighbor,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifControlEffect {
    pub control: MotifNegativeControl,
    pub effect_bps: f64,
    pub matches_candidate: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifNegativeControlDiagnostics {
    pub candidate_effect_bps: f64,
    pub match_tolerance_bps: f64,
    pub complete: bool,
    pub passed: bool,
    pub effects: Vec<MotifControlEffect>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ChangePointDiagnostic {
    pub split_index: usize,
    pub split_timestamp: Option<DateTime<Utc>>,
    pub left_mean: f64,
    pub right_mean: f64,
    pub mean_shift: f64,
    pub standardized_score: f64,
    pub detected: bool,
    pub interpretation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MotifEligibility {
    pub research_candidate: bool,
    pub eligibility_scope: String,
    pub requires_research_factory_fdr: bool,
    pub paper_eligible: bool,
    pub oos_eligible: bool,
    /// Motifs are hypothesis generators. Even a passing candidate cannot place
    /// an order until the separate Research Factory promotes it.
    pub trade_eligible: bool,
    pub status: String,
    pub reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifCandidate {
    pub schema_version: u32,
    pub motif_id: String,
    pub symbol: String,
    pub metadata: MotifMetadata,
    pub prototype: Vec<f64>,
    pub discovery_seed_starts: [usize; 2],
    pub occurrences: Vec<MotifOccurrence>,
    pub concentration: OccurrenceConcentration,
    pub recent_decay: RecentDecayDiagnostic,
    pub oos_evidence: MotifOosEvidence,
    pub change_point: Option<ChangePointDiagnostic>,
    pub negative_controls: MotifNegativeControlDiagnostics,
    pub eligibility: MotifEligibility,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MotifDiscoveryReport {
    pub schema_version: u32,
    pub symbol: String,
    pub value_kind: PathValueKind,
    pub resolution_minutes: usize,
    pub windows_evaluated: Vec<usize>,
    pub matrix_profile_entries: usize,
    pub candidates: Vec<MotifCandidate>,
    pub warnings: Vec<String>,
}

/// Population z-normalization over returns. A constant path carries no shape
/// information and is rejected rather than converted into a price pattern.
pub fn normalize_return_path(values: &[f64]) -> Result<Vec<f64>, MotifError> {
    if values.len() < 2 || values.iter().any(|value| !value.is_finite()) {
        return Err(MotifError::InvalidPath);
    }
    let mean = values.iter().sum::<f64>() / values.len() as f64;
    let variance = values
        .iter()
        .map(|value| (value - mean).powi(2))
        .sum::<f64>()
        / values.len() as f64;
    let scale = variance.sqrt();
    if scale <= 1e-12 {
        return Err(MotifError::DegeneratePath);
    }
    Ok(values.iter().map(|value| (value - mean) / scale).collect())
}

/// Matrix-profile-style exact nearest neighbors on the discovery partition.
/// Both the query and neighbor windows must stay inside one session and must
/// not overlap, including the configured exclusion zone. Every point in both
/// windows must have been available by `evidence_available_as_of`.
pub fn matrix_profile(
    series: &ReturnPathSeries,
    window_observations: usize,
    maximum_session_date: NaiveDate,
    evidence_available_as_of: DateTime<Utc>,
    exclusion_zone_observations: usize,
) -> Result<Vec<MatrixProfileEntry>, MotifError> {
    series.validate()?;
    if window_observations < 2 || window_observations > series.values.len() {
        return Err(MotifError::InvalidConfiguration(
            "matrix-profile window is outside the series".into(),
        ));
    }
    let starts = valid_starts(series, window_observations)
        .into_iter()
        .filter(|start| {
            series.session_dates[start + window_observations - 1] <= maximum_session_date
                && window_is_available_as_of(
                    series,
                    *start,
                    window_observations,
                    evidence_available_as_of,
                )
        })
        .collect::<Vec<_>>();
    let normalized = starts
        .iter()
        .filter_map(|start| {
            normalize_return_path(&series.values[*start..*start + window_observations])
                .ok()
                .map(|path| (*start, path))
        })
        .collect::<Vec<_>>();
    let mut profile = Vec::new();
    for (query_start, query_path) in &normalized {
        let nearest = normalized
            .iter()
            .filter(|(neighbor_start, _)| {
                windows_are_non_overlapping(
                    *query_start,
                    *neighbor_start,
                    window_observations,
                    exclusion_zone_observations,
                )
            })
            .map(|(neighbor_start, neighbor_path)| {
                (
                    *neighbor_start,
                    normalized_distance(query_path, neighbor_path),
                )
            })
            .min_by(|left, right| {
                left.1
                    .total_cmp(&right.1)
                    .then_with(|| left.0.cmp(&right.0))
            });
        if let Some((nearest_neighbor_start_index, normalized_distance)) = nearest {
            profile.push(MatrixProfileEntry {
                query_start_index: *query_start,
                nearest_neighbor_start_index,
                normalized_distance,
            });
        }
    }
    Ok(profile)
}

/// Runs discovery for every requested window at the series' declared
/// resolution. Use one `ReturnPathSeries` per 1m/5m/15m stream; candidate
/// metadata preserves both resolution and window duration.
pub fn discover_motifs(
    series: &ReturnPathSeries,
    outcomes: &[MotifForwardOutcome],
    config: &MotifDiscoveryConfig,
) -> Result<MotifDiscoveryReport, MotifError> {
    series.validate()?;
    config.validate()?;
    validate_outcomes(
        series,
        outcomes,
        config.outcome_horizon_minutes,
        config.evidence_available_as_of,
    )?;

    let outcome_map = outcomes
        .iter()
        .filter(|outcome| outcome.horizon_minutes == config.outcome_horizon_minutes)
        .map(|outcome| (outcome.anchor_end_index, outcome))
        .collect::<HashMap<_, _>>();
    let mut candidates = Vec::new();
    let mut profile_entries = 0;
    let mut warnings = Vec::new();
    let mut windows = config.window_observations.clone();
    windows.sort_unstable();
    windows.dedup();

    for window in &windows {
        if *window > series.values.len() {
            warnings.push(format!("window_{window}_exceeds_series_length"));
            continue;
        }
        let mut profile = matrix_profile(
            series,
            *window,
            config.discovery_end,
            config.evidence_available_as_of,
            config.exclusion_zone_observations,
        )?;
        profile_entries += profile.len();
        profile.sort_by(|left, right| {
            left.normalized_distance
                .total_cmp(&right.normalized_distance)
                .then_with(|| left.query_start_index.cmp(&right.query_start_index))
                .then_with(|| {
                    left.nearest_neighbor_start_index
                        .cmp(&right.nearest_neighbor_start_index)
                })
        });
        let mut occurrence_signatures = BTreeSet::new();
        let mut accepted_for_window = 0;
        for entry in profile {
            if entry.normalized_distance > config.maximum_normalized_distance
                || accepted_for_window >= config.maximum_candidates_per_window
            {
                break;
            }
            let Some(candidate) = build_candidate(series, &outcome_map, config, *window, &entry)?
            else {
                continue;
            };
            let signature = candidate
                .occurrences
                .iter()
                .filter(|occurrence| occurrence.partition == MotifPartition::Discovery)
                .map(|occurrence| occurrence.start_index)
                .collect::<Vec<_>>();
            if !occurrence_signatures.insert(signature) {
                continue;
            }
            accepted_for_window += 1;
            candidates.push(candidate);
        }
    }
    candidates.sort_by(|left, right| left.motif_id.cmp(&right.motif_id));
    Ok(MotifDiscoveryReport {
        schema_version: MOTIF_SCHEMA_VERSION,
        symbol: series.symbol.clone(),
        value_kind: series.value_kind,
        resolution_minutes: series.resolution_minutes,
        windows_evaluated: windows,
        matrix_profile_entries: profile_entries,
        candidates,
        warnings,
    })
}

/// Scalable deterministic motif discovery for multi-year minute archives.
///
/// The exact matrix profile above is intentionally retained as the reference
/// implementation, but its quadratic cost is unsuitable for a large research
/// catalog. This variant uses several deterministic random-projection orderings
/// to propose a bounded seed pool, then computes the original exact normalized
/// distance and runs the same leakage, partition, concentration, OOS, bootstrap
/// and negative-control gates as `discover_motifs`.
pub fn discover_motifs_approximate(
    series: &ReturnPathSeries,
    outcomes: &[MotifForwardOutcome],
    config: &MotifDiscoveryConfig,
    projection_count: usize,
    neighbor_span: usize,
) -> Result<MotifDiscoveryReport, MotifError> {
    series.validate()?;
    config.validate()?;
    if projection_count == 0 || neighbor_span == 0 {
        return Err(MotifError::InvalidConfiguration(
            "approximate motif search requires projections and a neighbor span".into(),
        ));
    }
    validate_outcomes(
        series,
        outcomes,
        config.outcome_horizon_minutes,
        config.evidence_available_as_of,
    )?;
    let outcome_map = outcomes
        .iter()
        .filter(|outcome| outcome.horizon_minutes == config.outcome_horizon_minutes)
        .map(|outcome| (outcome.anchor_end_index, outcome))
        .collect::<HashMap<_, _>>();
    let mut candidates = Vec::new();
    let mut profile_entries = 0usize;
    let mut warnings =
        vec!["APPROXIMATE_PROJECTION_SEED_SEARCH_EXACT_DISTANCE_AND_OOS_GATES".into()];
    let mut windows = config.window_observations.clone();
    windows.sort_unstable();
    windows.dedup();

    for window in &windows {
        if *window > series.values.len() {
            warnings.push(format!("window_{window}_exceeds_series_length"));
            continue;
        }
        let seed_limit = config
            .maximum_candidates_per_window
            .saturating_mul(16)
            .max(16);
        let profile = approximate_matrix_profile_seeds(
            series,
            *window,
            config.discovery_end,
            config.evidence_available_as_of,
            config.exclusion_zone_observations,
            projection_count,
            neighbor_span,
            seed_limit,
        )?;
        profile_entries += profile.len();
        let mut occurrence_signatures = BTreeSet::new();
        let mut accepted_for_window = 0usize;
        for entry in profile {
            if entry.normalized_distance > config.maximum_normalized_distance
                || accepted_for_window >= config.maximum_candidates_per_window
            {
                break;
            }
            let Some(candidate) = build_candidate(series, &outcome_map, config, *window, &entry)?
            else {
                continue;
            };
            let signature = candidate
                .occurrences
                .iter()
                .filter(|occurrence| occurrence.partition == MotifPartition::Discovery)
                .map(|occurrence| occurrence.start_index)
                .collect::<Vec<_>>();
            if !occurrence_signatures.insert(signature) {
                continue;
            }
            accepted_for_window += 1;
            candidates.push(candidate);
        }
    }
    candidates.sort_by(|left, right| left.motif_id.cmp(&right.motif_id));
    Ok(MotifDiscoveryReport {
        schema_version: MOTIF_SCHEMA_VERSION,
        symbol: series.symbol.clone(),
        value_kind: series.value_kind,
        resolution_minutes: series.resolution_minutes,
        windows_evaluated: windows,
        matrix_profile_entries: profile_entries,
        candidates,
        warnings,
    })
}

#[allow(clippy::too_many_arguments)]
fn approximate_matrix_profile_seeds(
    series: &ReturnPathSeries,
    window_observations: usize,
    maximum_session_date: NaiveDate,
    evidence_available_as_of: DateTime<Utc>,
    exclusion_zone_observations: usize,
    projection_count: usize,
    neighbor_span: usize,
    seed_limit: usize,
) -> Result<Vec<MatrixProfileEntry>, MotifError> {
    let paths = valid_starts(series, window_observations)
        .into_iter()
        .filter(|start| {
            series.session_dates[*start + window_observations - 1] <= maximum_session_date
                && window_is_available_as_of(
                    series,
                    *start,
                    window_observations,
                    evidence_available_as_of,
                )
        })
        .filter_map(|start| {
            normalize_return_path(&series.values[start..start + window_observations])
                .ok()
                .map(|path| (start, path))
        })
        .collect::<Vec<_>>();
    if paths.len() < 2 {
        return Ok(Vec::new());
    }

    let mut seen_pairs = BTreeSet::new();
    let mut seeds = Vec::new();
    for projection in 0..projection_count {
        let mut ordering = paths
            .iter()
            .enumerate()
            .map(|(path_index, (_, path))| {
                // Irrational-looking deterministic phases give independent
                // orderings without introducing a mutable RNG or learned data.
                let score = path
                    .iter()
                    .enumerate()
                    .map(|(offset, value)| {
                        let phase =
                            (offset + 1) as f64 * (projection + 1) as f64 * 0.754_877_666_246_692_7;
                        value * (phase.sin() + 0.5 * (phase * 1.618_033_988_75).cos())
                    })
                    .sum::<f64>()
                    / (path.len() as f64).sqrt();
                (score, path_index)
            })
            .collect::<Vec<_>>();
        ordering.sort_by(|left, right| {
            left.0
                .total_cmp(&right.0)
                .then_with(|| paths[left.1].0.cmp(&paths[right.1].0))
        });
        for position in 0..ordering.len() {
            for offset in 1..=neighbor_span {
                let Some(right) = ordering.get(position + offset) else {
                    break;
                };
                let left_index = ordering[position].1;
                let right_index = right.1;
                let left_start = paths[left_index].0;
                let right_start = paths[right_index].0;
                if !windows_are_non_overlapping(
                    left_start,
                    right_start,
                    window_observations,
                    exclusion_zone_observations,
                ) {
                    continue;
                }
                let pair = if left_start < right_start {
                    (left_start, right_start)
                } else {
                    (right_start, left_start)
                };
                if !seen_pairs.insert(pair) {
                    continue;
                }
                seeds.push(MatrixProfileEntry {
                    query_start_index: pair.0,
                    nearest_neighbor_start_index: pair.1,
                    normalized_distance: normalized_distance(
                        &paths[left_index].1,
                        &paths[right_index].1,
                    ),
                });
            }
        }
    }
    seeds.sort_by(|left, right| {
        left.normalized_distance
            .total_cmp(&right.normalized_distance)
            .then_with(|| left.query_start_index.cmp(&right.query_start_index))
            .then_with(|| {
                left.nearest_neighbor_start_index
                    .cmp(&right.nearest_neighbor_start_index)
            })
    });
    seeds.truncate(seed_limit);
    Ok(seeds)
}

fn build_candidate(
    series: &ReturnPathSeries,
    outcome_map: &HashMap<usize, &MotifForwardOutcome>,
    config: &MotifDiscoveryConfig,
    window: usize,
    seed: &MatrixProfileEntry,
) -> Result<Option<MotifCandidate>, MotifError> {
    let first = normalize_return_path(
        &series.values[seed.query_start_index..seed.query_start_index + window],
    )?;
    let second = normalize_return_path(
        &series.values
            [seed.nearest_neighbor_start_index..seed.nearest_neighbor_start_index + window],
    )?;
    let prototype_values = first
        .iter()
        .zip(&second)
        .map(|(left, right)| (left + right) / 2.0)
        .collect::<Vec<_>>();
    let prototype = normalize_return_path(&prototype_values)?;
    let motif_id = deterministic_motif_id(
        &series.symbol,
        series.value_kind,
        series.resolution_minutes,
        window,
        config.discovery_end,
        &prototype,
    );

    let mut matches = valid_starts(series, window)
        .into_iter()
        .filter(|start| {
            window_is_available_as_of(series, *start, window, config.evidence_available_as_of)
        })
        .filter_map(|start| {
            let path = normalize_return_path(&series.values[start..start + window]).ok()?;
            let distance = normalized_distance(&prototype, &path);
            (distance <= config.maximum_normalized_distance).then_some((start, distance))
        })
        .collect::<Vec<_>>();
    matches.sort_by(|left, right| {
        left.0
            .cmp(&right.0)
            .then_with(|| left.1.total_cmp(&right.1))
    });

    // Greedy chronological thinning makes occurrence counts conservative and
    // prevents overlapping windows from inflating evidence.
    let mut selected = Vec::<(usize, f64)>::new();
    for candidate in matches {
        if selected.iter().all(|(start, _)| {
            windows_are_non_overlapping(
                *start,
                candidate.0,
                window,
                config.exclusion_zone_observations,
            )
        }) {
            selected.push(candidate);
        }
    }
    // Test and forward matches are descriptive only. Candidate existence is
    // decided entirely by frozen discovery observations.
    let discovery_selected = selected
        .iter()
        .filter(|(start, _)| {
            let end = *start + window - 1;
            partition_for(series.session_dates[end], config) == MotifPartition::Discovery
        })
        .collect::<Vec<_>>();
    let discovery_days = discovery_selected
        .iter()
        .map(|(start, _)| series.session_dates[*start + window - 1])
        .collect::<BTreeSet<_>>();
    if discovery_selected.len() < config.minimum_occurrences
        || discovery_days.len() < config.minimum_independent_days
    {
        return Ok(None);
    }

    let bandwidth = config.maximum_normalized_distance.max(1e-9);
    let mut occurrences = selected
        .into_iter()
        .map(|(start, distance)| {
            let end = start + window - 1;
            let outcome = outcome_map
                .get(&end)
                .copied()
                .filter(|outcome| outcome.label_available_at <= config.evidence_available_as_of);
            MotifOccurrence {
                start_index: start,
                end_index: end,
                start_timestamp: series.timestamps[start],
                end_timestamp: series.timestamps[end],
                session_date: series.session_dates[end],
                partition: partition_for(series.session_dates[end], config),
                normalized_distance: distance,
                similarity_weight: (-0.5 * (distance / bandwidth).powi(2)).exp(),
                forward_return: outcome.map(|row| row.forward_return),
                label_available_at: outcome.map(|row| row.label_available_at),
            }
        })
        .collect::<Vec<_>>();
    occurrences.sort_by_key(|occurrence| occurrence.start_index);

    let discovery_occurrences = occurrences
        .iter()
        .filter(|occurrence| occurrence.partition == MotifPartition::Discovery)
        .cloned()
        .collect::<Vec<_>>();
    let concentration = occurrence_concentration(&discovery_occurrences);
    let recent_decay = recent_decay(series, &occurrences, config);
    let bootstrap_seed = config.negative_control_seed
        ^ seed.query_start_index as u64
        ^ (seed.nearest_neighbor_start_index as u64).rotate_left(32);
    let oos_evidence = oos_evidence(&occurrences, config, bootstrap_seed);
    let signed_test = signed_net_test_effects(&occurrences, &oos_evidence, config);
    let candidate_anchors = occurrences
        .iter()
        .filter(|occurrence| occurrence.partition == MotifPartition::Test)
        .map(|occurrence| occurrence.end_index)
        .collect::<BTreeSet<_>>();
    let background = outcome_map
        .iter()
        .filter(|(anchor, outcome)| {
            !candidate_anchors.contains(anchor)
                && outcome.label_available_at <= config.evidence_available_as_of
                && partition_for(series.session_dates[**anchor], config) == MotifPartition::Test
        })
        .map(|(_, outcome)| {
            oos_evidence.selected_direction as f64 * outcome.forward_return * 10_000.0
                - config.round_trip_cost_bps
        })
        .collect::<Vec<_>>();
    let negative_controls = run_motif_negative_controls(
        &signed_test,
        &background,
        config.negative_control_seed,
        config.negative_control_match_tolerance_bps,
    );
    let change_values = occurrences
        .iter()
        .filter(|occurrence| {
            !matches!(
                occurrence.partition,
                MotifPartition::Discovery | MotifPartition::Purged
            ) && occurrence.forward_return.is_some()
        })
        .map(|occurrence| {
            oos_evidence.selected_direction as f64
                * occurrence.forward_return.unwrap_or_default()
                * 10_000.0
                - config.round_trip_cost_bps
        })
        .collect::<Vec<_>>();
    let change_times = occurrences
        .iter()
        .filter(|occurrence| {
            !matches!(
                occurrence.partition,
                MotifPartition::Discovery | MotifPartition::Purged
            ) && occurrence.forward_return.is_some()
        })
        .map(|occurrence| occurrence.end_timestamp)
        .collect::<Vec<_>>();
    let mut change_point = strongest_mean_change(
        &change_values,
        config.change_point_minimum_observations,
        config.change_point_score_threshold,
    );
    if let Some(diagnostic) = &mut change_point {
        diagnostic.split_timestamp = change_times.get(diagnostic.split_index).copied();
    }
    let eligibility = motif_eligibility(
        &concentration,
        &recent_decay,
        &oos_evidence,
        change_point.as_ref(),
        &negative_controls,
        config,
    );

    Ok(Some(MotifCandidate {
        schema_version: MOTIF_SCHEMA_VERSION,
        motif_id,
        symbol: series.symbol.clone(),
        metadata: MotifMetadata {
            value_kind: series.value_kind,
            resolution_minutes: series.resolution_minutes,
            window_observations: window,
            duration_minutes: window * series.resolution_minutes,
            normalization: "RETURN_PATH_Z_SCORE_POPULATION".into(),
            distance_metric: "NORMALIZED_EUCLIDEAN_MATRIX_PROFILE".into(),
            discovery_cutoff: config.discovery_end,
        },
        prototype,
        discovery_seed_starts: [seed.query_start_index, seed.nearest_neighbor_start_index],
        occurrences,
        concentration,
        recent_decay,
        oos_evidence,
        change_point,
        negative_controls,
        eligibility,
    }))
}

fn valid_starts(series: &ReturnPathSeries, window: usize) -> Vec<usize> {
    (0..=series.values.len() - window)
        .filter(|start| {
            let date = series.session_dates[*start];
            series.session_dates[*start..*start + window]
                .iter()
                .all(|candidate| *candidate == date)
        })
        .collect()
}

fn window_is_available_as_of(
    series: &ReturnPathSeries,
    start: usize,
    window: usize,
    evidence_available_as_of: DateTime<Utc>,
) -> bool {
    series.available_at[start..start + window]
        .iter()
        .all(|available_at| *available_at <= evidence_available_as_of)
}

fn windows_are_non_overlapping(
    left: usize,
    right: usize,
    window: usize,
    exclusion_zone: usize,
) -> bool {
    left + window + exclusion_zone <= right || right + window + exclusion_zone <= left
}

fn normalized_distance(left: &[f64], right: &[f64]) -> f64 {
    left.iter()
        .zip(right)
        .map(|(a, b)| (a - b).powi(2))
        .sum::<f64>()
        .sqrt()
        / (left.len() as f64).sqrt()
}

fn deterministic_motif_id(
    symbol: &str,
    value_kind: PathValueKind,
    resolution_minutes: usize,
    window_observations: usize,
    discovery_end: NaiveDate,
    prototype: &[f64],
) -> String {
    let mut hasher = Sha256::new();
    for component in [
        "AXIO7_NORMALIZED_RETURN_MOTIF_V1".to_string(),
        symbol.trim().to_ascii_uppercase(),
        format!("{value_kind:?}"),
        resolution_minutes.to_string(),
        window_observations.to_string(),
        discovery_end.to_string(),
    ] {
        hasher.update((component.len() as u64).to_le_bytes());
        hasher.update(component.as_bytes());
    }
    for value in prototype {
        // Quantization makes the ID stable across inconsequential floating
        // arithmetic differences while retaining the frozen motif shape.
        let quantized = (value * 1_000_000.0).round() as i64;
        hasher.update(quantized.to_le_bytes());
    }
    let digest = hasher.finalize();
    let suffix = digest[..12]
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect::<String>();
    format!("MOTIF-{suffix}")
}

fn partition_for(date: NaiveDate, config: &MotifDiscoveryConfig) -> MotifPartition {
    // Configuration validation guarantees both additions are representable and
    // leave non-empty validation/test intervals after their purge blocks.
    let purge_days = i64::try_from(config.partition_purge_calendar_days)
        .expect("validated motif purge interval fits i64");
    let discovery_purge_end = config
        .discovery_end
        .checked_add_signed(Duration::days(purge_days))
        .expect("validated discovery purge interval");
    let validation_purge_end = config
        .validation_end
        .checked_add_signed(Duration::days(purge_days))
        .expect("validated validation purge interval");
    if date <= config.discovery_end {
        MotifPartition::Discovery
    } else if date <= discovery_purge_end {
        MotifPartition::Purged
    } else if date <= config.validation_end {
        MotifPartition::Validation
    } else if date <= validation_purge_end {
        MotifPartition::Purged
    } else if date <= config.test_end {
        MotifPartition::Test
    } else {
        MotifPartition::ForwardShadow
    }
}

fn occurrence_concentration(occurrences: &[MotifOccurrence]) -> OccurrenceConcentration {
    let mut days = BTreeMap::<NaiveDate, usize>::new();
    let mut months = BTreeMap::<(i32, u32), usize>::new();
    for occurrence in occurrences {
        *days.entry(occurrence.session_date).or_default() += 1;
        *months
            .entry((
                occurrence.session_date.year(),
                occurrence.session_date.month(),
            ))
            .or_default() += 1;
    }
    let total = occurrences.len().max(1) as f64;
    let maximum_day_share = days
        .values()
        .map(|count| *count as f64 / total)
        .fold(0.0, f64::max);
    let maximum_month_share = months
        .values()
        .map(|count| *count as f64 / total)
        .fold(0.0, f64::max);
    let sum_squared_day_shares = days
        .values()
        .map(|count| (*count as f64 / total).powi(2))
        .sum::<f64>();
    OccurrenceConcentration {
        occurrence_count: occurrences.len(),
        independent_days: days.len(),
        independent_months: months.len(),
        maximum_day_share,
        maximum_month_share,
        effective_day_count: if sum_squared_day_shares > 0.0 {
            1.0 / sum_squared_day_shares
        } else {
            0.0
        },
    }
}

fn recent_decay(
    series: &ReturnPathSeries,
    occurrences: &[MotifOccurrence],
    config: &MotifDiscoveryConfig,
) -> RecentDecayDiagnostic {
    let mut sessions = series
        .session_dates
        .iter()
        .copied()
        .filter(|date| {
            *date <= config.test_end && partition_for(*date, config) != MotifPartition::Purged
        })
        .collect::<Vec<_>>();
    sessions.sort_unstable();
    sessions.dedup();
    let recent_start = sessions.len().saturating_sub(config.recent_session_window);
    let recent = sessions[recent_start..]
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    let historical = sessions[..recent_start]
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    let recent_occurrences = occurrences
        .iter()
        .filter(|occurrence| recent.contains(&occurrence.session_date))
        .count();
    let historical_occurrences = occurrences
        .iter()
        .filter(|occurrence| historical.contains(&occurrence.session_date))
        .count();
    let recent_rate = recent_occurrences as f64 / recent.len().max(1) as f64;
    let historical_rate = historical_occurrences as f64 / historical.len().max(1) as f64;
    let sufficient_history = recent.len() == config.recent_session_window
        && historical.len() >= config.recent_session_window;
    let ratio = if historical_rate > 0.0 {
        recent_rate / historical_rate
    } else if recent_rate > 0.0 {
        1.0
    } else {
        0.0
    };
    RecentDecayDiagnostic {
        recent_session_window: config.recent_session_window,
        recent_sessions: recent.len(),
        historical_sessions: historical.len(),
        recent_occurrences,
        historical_occurrences,
        recent_rate,
        historical_rate,
        recent_to_historical_rate_ratio: ratio,
        sufficient_history,
        decayed: sufficient_history && ratio < config.minimum_recent_rate_ratio,
    }
}

fn oos_evidence(
    occurrences: &[MotifOccurrence],
    config: &MotifDiscoveryConfig,
    bootstrap_seed: u64,
) -> MotifOosEvidence {
    let validation = occurrences
        .iter()
        .filter(|occurrence| {
            occurrence.partition == MotifPartition::Validation
                && occurrence.forward_return.is_some()
        })
        .collect::<Vec<_>>();
    let validation_mean = validation
        .iter()
        .filter_map(|occurrence| occurrence.forward_return)
        .sum::<f64>()
        / validation.len().max(1) as f64;
    let direction = if validation_mean > 0.0 {
        1
    } else if validation_mean < 0.0 {
        -1
    } else {
        0
    };
    let test = occurrences
        .iter()
        .filter(|occurrence| {
            occurrence.partition == MotifPartition::Test && occurrence.forward_return.is_some()
        })
        .collect::<Vec<_>>();
    let signed_test_bps = test
        .iter()
        .filter_map(|occurrence| occurrence.forward_return)
        .map(|value| direction as f64 * value * 10_000.0)
        .collect::<Vec<_>>();
    let test_gross_mean_bps = mean(&signed_test_bps);
    let test_net = signed_test_bps
        .iter()
        .map(|value| value - config.round_trip_cost_bps)
        .collect::<Vec<_>>();
    let test_net_by_day = test
        .iter()
        .filter_map(|occurrence| {
            occurrence.forward_return.map(|value| {
                (
                    occurrence.session_date,
                    direction as f64 * value * 10_000.0 - config.round_trip_cost_bps,
                )
            })
        })
        .collect::<Vec<_>>();
    let bootstrap = day_block_bootstrap_ci(&test_net_by_day, config, bootstrap_seed);
    let test_days = test
        .iter()
        .map(|occurrence| occurrence.session_date)
        .collect::<BTreeSet<_>>()
        .len();
    MotifOosEvidence {
        direction_selected_on: "VALIDATION_ONLY".into(),
        selected_direction: direction,
        validation_occurrences: validation.len(),
        validation_mean_return_bps: validation_mean * 10_000.0,
        test_occurrences: test.len(),
        test_independent_days: test_days,
        test_gross_mean_bps,
        test_net_mean_bps: mean(&test_net),
        test_net_win_rate: test_net.iter().filter(|value| **value > 0.0).count() as f64
            / test_net.len().max(1) as f64,
        test_net_day_block_bootstrap: bootstrap,
        forward_shadow_occurrences: occurrences
            .iter()
            .filter(|occurrence| {
                occurrence.partition == MotifPartition::ForwardShadow
                    && occurrence.forward_return.is_some()
            })
            .count(),
        assumed_round_trip_cost_bps: config.round_trip_cost_bps,
    }
}

fn day_block_bootstrap_ci(
    observations: &[(NaiveDate, f64)],
    config: &MotifDiscoveryConfig,
    seed: u64,
) -> DayBlockBootstrapCi {
    let mut observations_by_day = BTreeMap::<NaiveDate, Vec<f64>>::new();
    for (date, value) in observations {
        if value.is_finite() {
            observations_by_day.entry(*date).or_default().push(*value);
        }
    }
    let daily_means = observations_by_day
        .values()
        .map(|values| mean(values))
        .collect::<Vec<_>>();
    let observed_mean_bps = mean(&daily_means);
    let complete = daily_means.len() >= 2
        && config.day_block_bootstrap_resamples >= 200
        && daily_means.iter().all(|value| value.is_finite());
    if !complete {
        return DayBlockBootstrapCi {
            complete: false,
            resamples: config.day_block_bootstrap_resamples,
            confidence_level: config.day_block_bootstrap_confidence_level,
            independent_days: daily_means.len(),
            observed_mean_bps,
            lower_bps: None,
            upper_bps: None,
            minimum_required_lower_bps: config.minimum_test_net_bootstrap_ci_lower_bps,
            passed: false,
        };
    }

    let mut rng = SplitMix64(seed);
    let mut bootstrap_means = Vec::with_capacity(config.day_block_bootstrap_resamples);
    for _ in 0..config.day_block_bootstrap_resamples {
        let resampled_sum = (0..daily_means.len())
            .map(|_| daily_means[rng.index(daily_means.len())])
            .sum::<f64>();
        bootstrap_means.push(resampled_sum / daily_means.len() as f64);
    }
    bootstrap_means.sort_by(f64::total_cmp);
    let alpha = (1.0 - config.day_block_bootstrap_confidence_level) / 2.0;
    let lower_bps = empirical_quantile(&bootstrap_means, alpha);
    let upper_bps = empirical_quantile(&bootstrap_means, 1.0 - alpha);
    DayBlockBootstrapCi {
        complete: true,
        resamples: config.day_block_bootstrap_resamples,
        confidence_level: config.day_block_bootstrap_confidence_level,
        independent_days: daily_means.len(),
        observed_mean_bps,
        lower_bps: Some(lower_bps),
        upper_bps: Some(upper_bps),
        minimum_required_lower_bps: config.minimum_test_net_bootstrap_ci_lower_bps,
        passed: lower_bps >= config.minimum_test_net_bootstrap_ci_lower_bps,
    }
}

fn empirical_quantile(sorted_values: &[f64], probability: f64) -> f64 {
    let position = probability.clamp(0.0, 1.0) * (sorted_values.len() - 1) as f64;
    let lower_index = position.floor() as usize;
    let upper_index = position.ceil() as usize;
    let fraction = position - lower_index as f64;
    sorted_values[lower_index] * (1.0 - fraction) + sorted_values[upper_index] * fraction
}

fn signed_net_test_effects(
    occurrences: &[MotifOccurrence],
    evidence: &MotifOosEvidence,
    config: &MotifDiscoveryConfig,
) -> Vec<(f64, f64)> {
    occurrences
        .iter()
        .filter(|occurrence| {
            occurrence.partition == MotifPartition::Test && occurrence.forward_return.is_some()
        })
        .map(|occurrence| {
            (
                evidence.selected_direction as f64
                    * occurrence.forward_return.unwrap_or_default()
                    * 10_000.0
                    - config.round_trip_cost_bps,
                occurrence.similarity_weight,
            )
        })
        .collect()
}

/// Deterministic motif-specific controls. These diagnostics complement the
/// complete 13-control Research Factory matrix; they do not replace it.
pub fn run_motif_negative_controls(
    observed_effects_bps: &[(f64, f64)],
    background_effects_bps: &[f64],
    seed: u64,
    match_tolerance_bps: f64,
) -> MotifNegativeControlDiagnostics {
    if observed_effects_bps.len() < 2
        || background_effects_bps.len() < observed_effects_bps.len()
        || observed_effects_bps
            .iter()
            .any(|(value, weight)| !value.is_finite() || !weight.is_finite() || *weight < 0.0)
        || background_effects_bps
            .iter()
            .any(|value| !value.is_finite())
        || !match_tolerance_bps.is_finite()
        || match_tolerance_bps < 0.0
    {
        return MotifNegativeControlDiagnostics {
            candidate_effect_bps: weighted_mean(observed_effects_bps),
            match_tolerance_bps,
            complete: false,
            passed: false,
            effects: Vec::new(),
        };
    }
    let candidate = weighted_mean(observed_effects_bps);
    let mut rng = SplitMix64(seed);
    let values = observed_effects_bps
        .iter()
        .map(|(value, _)| *value)
        .collect::<Vec<_>>();
    let weights = observed_effects_bps
        .iter()
        .map(|(_, weight)| *weight)
        .collect::<Vec<_>>();

    let rotation = (rng.index(values.len() - 1) + 1) % values.len();
    let timestamp_shuffle = values
        .iter()
        .cycle()
        .skip(rotation)
        .take(values.len())
        .copied()
        .zip(weights.iter().copied())
        .collect::<Vec<_>>();
    let sign_shuffle = values
        .iter()
        .zip(&weights)
        .map(|(value, weight)| {
            let sign = if rng.next().is_multiple_of(2) {
                1.0
            } else {
                -1.0
            };
            (value * sign, *weight)
        })
        .collect::<Vec<_>>();
    let random_start = rng.index(background_effects_bps.len() - values.len() + 1);
    let random_motif = background_effects_bps[random_start..random_start + values.len()]
        .iter()
        .copied()
        .zip(weights.iter().copied())
        .collect::<Vec<_>>();
    let random_neighbors = (0..values.len())
        .map(|index| {
            (
                background_effects_bps[rng.index(background_effects_bps.len())],
                weights[index],
            )
        })
        .collect::<Vec<_>>();
    let controls = [
        (
            MotifNegativeControl::TimestampShuffle,
            weighted_mean(&timestamp_shuffle),
        ),
        (
            MotifNegativeControl::ReturnSignShuffle,
            weighted_mean(&sign_shuffle),
        ),
        (
            MotifNegativeControl::RandomMotif,
            weighted_mean(&random_motif),
        ),
        (
            MotifNegativeControl::RandomAnalogNeighbor,
            weighted_mean(&random_neighbors),
        ),
    ];
    let effects = controls
        .into_iter()
        .map(|(control, effect_bps)| MotifControlEffect {
            control,
            effect_bps,
            matches_candidate: effect_bps.abs() + match_tolerance_bps >= candidate.abs(),
        })
        .collect::<Vec<_>>();
    MotifNegativeControlDiagnostics {
        candidate_effect_bps: candidate,
        match_tolerance_bps,
        complete: true,
        passed: effects.iter().all(|effect| !effect.matches_candidate),
        effects,
    }
}

fn weighted_mean(values: &[(f64, f64)]) -> f64 {
    let weight_sum = values.iter().map(|(_, weight)| *weight).sum::<f64>();
    if weight_sum <= 0.0 {
        0.0
    } else {
        values
            .iter()
            .map(|(value, weight)| value * weight)
            .sum::<f64>()
            / weight_sum
    }
}

fn mean(values: &[f64]) -> f64 {
    values.iter().sum::<f64>() / values.len().max(1) as f64
}

/// Strongest two-segment mean-shift diagnostic. It is descriptive only and is
/// never allowed to select a motif or its trading direction.
pub fn strongest_mean_change(
    values: &[f64],
    minimum_segment_observations: usize,
    score_threshold: f64,
) -> Option<ChangePointDiagnostic> {
    if minimum_segment_observations == 0
        || values.len() < minimum_segment_observations * 2
        || values.iter().any(|value| !value.is_finite())
        || !score_threshold.is_finite()
        || score_threshold <= 0.0
    {
        return None;
    }
    let mut best: Option<ChangePointDiagnostic> = None;
    for split in minimum_segment_observations..=values.len() - minimum_segment_observations {
        let left = &values[..split];
        let right = &values[split..];
        let left_mean = mean(left);
        let right_mean = mean(right);
        let left_variance = variance(left, left_mean);
        let right_variance = variance(right, right_mean);
        let standard_error =
            (left_variance / left.len() as f64 + right_variance / right.len() as f64).sqrt();
        let score = (right_mean - left_mean).abs() / standard_error.max(1e-12);
        let diagnostic = ChangePointDiagnostic {
            split_index: split,
            split_timestamp: None,
            left_mean,
            right_mean,
            mean_shift: right_mean - left_mean,
            standardized_score: score,
            detected: score >= score_threshold,
            interpretation: "DESCRIPTIVE_ONLY_NOT_A_SELECTION_FEATURE".into(),
        };
        if best
            .as_ref()
            .is_none_or(|current| score > current.standardized_score)
        {
            best = Some(diagnostic);
        }
    }
    best
}

fn variance(values: &[f64], mean: f64) -> f64 {
    if values.len() < 2 {
        0.0
    } else {
        values
            .iter()
            .map(|value| (value - mean).powi(2))
            .sum::<f64>()
            / (values.len() - 1) as f64
    }
}

fn motif_eligibility(
    concentration: &OccurrenceConcentration,
    decay: &RecentDecayDiagnostic,
    evidence: &MotifOosEvidence,
    change_point: Option<&ChangePointDiagnostic>,
    controls: &MotifNegativeControlDiagnostics,
    config: &MotifDiscoveryConfig,
) -> MotifEligibility {
    let mut reasons = Vec::new();
    if concentration.occurrence_count < config.minimum_occurrences {
        reasons.push("insufficient_occurrences".into());
    }
    if concentration.independent_days < config.minimum_independent_days {
        reasons.push("insufficient_independent_days".into());
    }
    if concentration.maximum_day_share > config.maximum_day_concentration {
        reasons.push("single_day_concentration_too_high".into());
    }
    if concentration.maximum_month_share > config.maximum_month_concentration {
        reasons.push("single_month_concentration_too_high".into());
    }
    if decay.decayed {
        reasons.push("recent_occurrence_decay".into());
    }
    if evidence.validation_occurrences < config.minimum_validation_occurrences
        || evidence.selected_direction == 0
    {
        reasons.push("validation_cannot_select_direction".into());
    }
    if evidence.test_occurrences < config.minimum_test_occurrences {
        reasons.push("insufficient_untouched_test_occurrences".into());
    }
    if evidence.test_independent_days < config.minimum_test_independent_days {
        reasons.push("insufficient_untouched_test_days".into());
    }
    if evidence.test_net_mean_bps < config.minimum_test_net_mean_bps {
        reasons.push("cost_adjusted_test_effect_below_threshold".into());
    }
    if !evidence.test_net_day_block_bootstrap.complete {
        reasons.push("test_day_block_bootstrap_incomplete".into());
    } else if !evidence.test_net_day_block_bootstrap.passed {
        reasons.push("test_day_block_bootstrap_ci_below_threshold".into());
    }
    if !controls.complete {
        reasons.push("motif_negative_controls_incomplete".into());
    } else if !controls.passed {
        reasons.push("random_or_shuffled_control_matches_candidate".into());
    }
    if change_point.is_some_and(|change| {
        change.detected && change.mean_shift < 0.0 && change.right_mean <= 0.0
    }) {
        reasons.push("adverse_recent_change_point".into());
    }
    MotifEligibility {
        research_candidate: true,
        eligibility_scope: "RESEARCH_CANDIDATE".into(),
        requires_research_factory_fdr: true,
        paper_eligible: false,
        oos_eligible: false,
        trade_eligible: false,
        status: if reasons.is_empty() {
            "RESEARCH_CANDIDATE_REQUIRES_FACTORY_FDR"
        } else {
            "RESEARCH_CANDIDATE_INTERNAL_GATES_FAILED"
        }
        .into(),
        reasons,
    }
}

fn validate_outcomes(
    series: &ReturnPathSeries,
    outcomes: &[MotifForwardOutcome],
    horizon: usize,
    evidence_available_as_of: DateTime<Utc>,
) -> Result<(), MotifError> {
    let horizon_minutes = i64::try_from(horizon).map_err(|_| MotifError::InvalidOutcome)?;
    let mut keys = BTreeSet::new();
    for outcome in outcomes
        .iter()
        .filter(|outcome| outcome.horizon_minutes == horizon)
    {
        if outcome.anchor_end_index >= series.values.len()
            || outcome.horizon_end_index >= series.values.len()
            || outcome.horizon_end_index <= outcome.anchor_end_index
        {
            return Err(MotifError::InvalidOutcome);
        }
        let expected_terminal = series.timestamps[outcome.anchor_end_index]
            .checked_add_signed(Duration::minutes(horizon_minutes))
            .ok_or(MotifError::InvalidOutcome)?;
        if !outcome.forward_return.is_finite()
            || series.session_dates[outcome.horizon_end_index]
                != series.session_dates[outcome.anchor_end_index]
            || series.timestamps[outcome.horizon_end_index] != expected_terminal
            || outcome.label_available_at < series.available_at[outcome.horizon_end_index]
            || outcome.label_available_at > evidence_available_as_of
        {
            return Err(MotifError::InvalidOutcome);
        }
        if !keys.insert(outcome.anchor_end_index) {
            return Err(MotifError::DuplicateOutcome {
                anchor_end_index: outcome.anchor_end_index,
                horizon_minutes: horizon,
            });
        }
    }
    Ok(())
}

#[derive(Debug, Clone, Copy)]
struct SplitMix64(u64);

impl SplitMix64 {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut value = self.0;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        value ^ (value >> 31)
    }

    fn index(&mut self, upper: usize) -> usize {
        (self.next() % upper as u64) as usize
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MotifError {
    InvalidSeries(String),
    InvalidPath,
    DegeneratePath,
    InvalidConfiguration(String),
    InvalidOutcome,
    DuplicateOutcome {
        anchor_end_index: usize,
        horizon_minutes: usize,
    },
}

impl fmt::Display for MotifError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidSeries(detail) => {
                write!(formatter, "invalid return-path series: {detail}")
            }
            Self::InvalidPath => formatter.write_str("invalid normalized return path"),
            Self::DegeneratePath => formatter.write_str("constant return path has no motif shape"),
            Self::InvalidConfiguration(detail) => {
                write!(formatter, "invalid motif configuration: {detail}")
            }
            Self::InvalidOutcome => formatter.write_str("invalid or non-causal motif outcome"),
            Self::DuplicateOutcome {
                anchor_end_index,
                horizon_minutes,
            } => write!(
                formatter,
                "duplicate motif outcome at index {anchor_end_index} horizon {horizon_minutes}"
            ),
        }
    }
}

impl Error for MotifError {}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, TimeZone};

    fn series(values: Vec<f64>, dates: Vec<NaiveDate>) -> ReturnPathSeries {
        let start = Utc.with_ymd_and_hms(2026, 1, 1, 14, 30, 0).unwrap();
        let timestamps = (0..values.len())
            .map(|index| start + Duration::minutes(index as i64))
            .collect::<Vec<_>>();
        ReturnPathSeries {
            symbol: "SPY".into(),
            resolution_minutes: 1,
            value_kind: PathValueKind::LogReturn,
            available_at: timestamps
                .iter()
                .map(|timestamp| *timestamp + Duration::seconds(2))
                .collect(),
            timestamps,
            session_dates: dates,
            values,
        }
    }

    fn research_config() -> MotifDiscoveryConfig {
        MotifDiscoveryConfig {
            window_observations: vec![3, 5],
            exclusion_zone_observations: 0,
            maximum_normalized_distance: 0.08,
            maximum_candidates_per_window: 2,
            minimum_occurrences: 6,
            minimum_independent_days: 6,
            maximum_day_concentration: 0.20,
            maximum_month_concentration: 1.0,
            recent_session_window: 4,
            minimum_recent_rate_ratio: 0.25,
            minimum_validation_occurrences: 2,
            minimum_test_occurrences: 2,
            minimum_test_independent_days: 2,
            partition_purge_calendar_days: 1,
            outcome_horizon_minutes: 1,
            round_trip_cost_bps: 2.0,
            minimum_test_net_mean_bps: 1.0,
            day_block_bootstrap_resamples: 512,
            day_block_bootstrap_confidence_level: 0.95,
            minimum_test_net_bootstrap_ci_lower_bps: 1.0,
            discovery_end: NaiveDate::from_ymd_opt(2026, 1, 6).unwrap(),
            validation_end: NaiveDate::from_ymd_opt(2026, 1, 9).unwrap(),
            test_end: NaiveDate::from_ymd_opt(2026, 1, 13).unwrap(),
            evidence_available_as_of: Utc.with_ymd_and_hms(2026, 2, 1, 0, 0, 0).unwrap(),
            change_point_minimum_observations: 2,
            change_point_score_threshold: 4.0,
            negative_control_seed: 9,
            negative_control_match_tolerance_bps: 0.25,
        }
    }

    #[test]
    fn normalization_uses_returns_and_rejects_level_like_constant_paths() {
        let normalized = normalize_return_path(&[0.01, -0.02, 0.03]).unwrap();
        assert!(mean(&normalized).abs() < 1e-12);
        assert!((variance(&normalized, 0.0) - 1.5).abs() < 1e-12);
        assert_eq!(
            normalize_return_path(&[100.0, 100.0, 100.0]),
            Err(MotifError::DegeneratePath)
        );
    }

    #[test]
    fn matrix_profile_finds_same_shape_without_overlapping_windows() {
        let date = NaiveDate::from_ymd_opt(2026, 1, 2).unwrap();
        let input = series(
            vec![1.0, -1.0, 0.5, 5.0, 0.0, -4.0, 2.0, -2.0, 1.0],
            vec![date; 9],
        );
        let profile = matrix_profile(&input, 3, date, input.available_at[8], 0).unwrap();
        let first = profile
            .iter()
            .find(|entry| entry.query_start_index == 0)
            .unwrap();
        assert_eq!(first.nearest_neighbor_start_index, 6);
        assert!(first.normalized_distance < 1e-12);
        assert!(windows_are_non_overlapping(
            first.query_start_index,
            first.nearest_neighbor_start_index,
            3,
            0
        ));
    }

    #[test]
    fn matrix_profile_excludes_a_window_when_any_point_is_not_yet_available() {
        let date = NaiveDate::from_ymd_opt(2026, 1, 2).unwrap();
        let mut input = series(
            vec![1.0, -1.0, 0.5, 5.0, 0.0, -4.0, 2.0, -2.0, 1.0],
            vec![date; 9],
        );
        let cutoff = input.available_at[8];
        input.available_at[1] = cutoff + Duration::minutes(1);

        let profile = matrix_profile(&input, 3, date, cutoff, 0).unwrap();
        let contains_late_point = |start: usize| start <= 1 && 1 < start + 3;
        assert!(!profile.is_empty());
        assert!(profile.iter().all(|entry| {
            !contains_late_point(entry.query_start_index)
                && !contains_late_point(entry.nearest_neighbor_start_index)
        }));
    }

    #[test]
    fn forward_outcome_requires_exact_terminal_and_a_mature_label() {
        let date = NaiveDate::from_ymd_opt(2026, 1, 2).unwrap();
        let input = series(vec![0.01; 7], vec![date; 7]);
        let cutoff = input.available_at[5];
        let valid = MotifForwardOutcome {
            anchor_end_index: 0,
            horizon_end_index: 5,
            horizon_minutes: 5,
            forward_return: 0.001,
            label_available_at: cutoff,
        };
        assert_eq!(
            validate_outcomes(&input, std::slice::from_ref(&valid), 5, cutoff),
            Ok(())
        );

        let mut wrong_terminal = valid.clone();
        wrong_terminal.horizon_end_index = 4;
        assert_eq!(
            validate_outcomes(&input, &[wrong_terminal], 5, cutoff),
            Err(MotifError::InvalidOutcome)
        );

        let mut premature = valid.clone();
        premature.label_available_at = input.available_at[5] - Duration::nanoseconds(1);
        assert_eq!(
            validate_outcomes(&input, &[premature], 5, cutoff),
            Err(MotifError::InvalidOutcome)
        );

        let mut unavailable = valid;
        unavailable.label_available_at = cutoff + Duration::seconds(1);
        assert_eq!(
            validate_outcomes(&input, &[unavailable], 5, cutoff),
            Err(MotifError::InvalidOutcome)
        );
    }

    #[test]
    fn purge_days_are_not_assigned_to_validation_or_test() {
        let config = research_config();
        config.validate().unwrap();

        assert_eq!(
            partition_for(NaiveDate::from_ymd_opt(2026, 1, 6).unwrap(), &config),
            MotifPartition::Discovery
        );
        assert_eq!(
            partition_for(NaiveDate::from_ymd_opt(2026, 1, 7).unwrap(), &config),
            MotifPartition::Purged
        );
        assert_eq!(
            partition_for(NaiveDate::from_ymd_opt(2026, 1, 8).unwrap(), &config),
            MotifPartition::Validation
        );
        assert_eq!(
            partition_for(NaiveDate::from_ymd_opt(2026, 1, 10).unwrap(), &config),
            MotifPartition::Purged
        );
        assert_eq!(
            partition_for(NaiveDate::from_ymd_opt(2026, 1, 11).unwrap(), &config),
            MotifPartition::Test
        );
        assert_eq!(
            partition_for(NaiveDate::from_ymd_opt(2026, 1, 14).unwrap(), &config),
            MotifPartition::ForwardShadow
        );
    }

    #[test]
    fn day_block_bootstrap_is_deterministic_and_gates_on_its_lower_bound() {
        let day_one = NaiveDate::from_ymd_opt(2026, 1, 11).unwrap();
        let day_two = NaiveDate::from_ymd_opt(2026, 1, 12).unwrap();
        let day_three = NaiveDate::from_ymd_opt(2026, 1, 13).unwrap();
        let observations = vec![
            (day_one, 10.0),
            (day_one, 14.0),
            (day_two, 12.0),
            (day_three, 16.0),
        ];
        let mut config = research_config();
        config.minimum_test_net_bootstrap_ci_lower_bps = 11.0;
        let first = day_block_bootstrap_ci(&observations, &config, 41);
        let second = day_block_bootstrap_ci(&observations, &config, 41);

        assert_eq!(first, second);
        assert!(first.complete);
        assert_eq!(first.independent_days, 3);
        assert!(first.passed);
        assert!(first.lower_bps.is_some_and(|lower| lower >= 11.0));

        config.minimum_test_net_bootstrap_ci_lower_bps = 13.0;
        let rejected = day_block_bootstrap_ci(&observations, &config, 41);
        assert!(!rejected.passed);

        let incomplete = day_block_bootstrap_ci(&[(day_one, 20.0)], &config, 41);
        assert!(!incomplete.complete);
        assert_eq!(incomplete.lower_bps, None);
    }

    #[test]
    fn change_point_diagnostic_detects_recent_effect_failure() {
        let values = [2.0, 2.2, 1.8, 2.1, -1.0, -1.2, -0.9, -1.1];
        let diagnostic = strongest_mean_change(&values, 3, 3.0).unwrap();
        assert_eq!(diagnostic.split_index, 4);
        assert!(diagnostic.detected);
        assert!(diagnostic.mean_shift < 0.0);
        assert!(diagnostic.right_mean < 0.0);
    }

    #[test]
    fn random_control_matching_candidate_fails_diagnostic() {
        let observed = vec![(5.0, 1.0), (4.8, 0.8), (5.2, 0.7), (5.1, 0.6)];
        let background = vec![5.0, 5.2, 4.9, 5.1, 5.0, 4.8, 5.2, 5.1];
        let controls = run_motif_negative_controls(&observed, &background, 7, 0.25);
        assert!(controls.complete);
        assert!(!controls.passed);
        assert!(controls.effects.iter().any(|effect| {
            matches!(
                effect.control,
                MotifNegativeControl::RandomMotif | MotifNegativeControl::RandomAnalogNeighbor
            ) && effect.matches_candidate
        }));
    }

    #[test]
    fn multi_session_discovery_has_deterministic_ids_and_metadata() {
        let dates = (1..=16)
            .flat_map(|day| vec![NaiveDate::from_ymd_opt(2026, 1, day).unwrap(); 6])
            .collect::<Vec<_>>();
        let values = (0..16)
            .flat_map(|day| {
                let jitter = day as f64 * 1e-5;
                [0.01 + jitter, -0.005, 0.008 - jitter, -0.003, 0.001, -0.002]
            })
            .collect::<Vec<_>>();
        let input = series(values, dates);
        let mut outcomes = Vec::new();
        for day in 0..16 {
            let base = day * 6;
            for offset in [2_usize, 4_usize] {
                let anchor = base + offset;
                let terminal = anchor + 1;
                outcomes.push(MotifForwardOutcome {
                    anchor_end_index: anchor,
                    horizon_end_index: terminal,
                    horizon_minutes: 1,
                    forward_return: if day >= 5 { 0.002 } else { 0.0005 },
                    label_available_at: input.available_at[terminal],
                });
            }
        }
        let config = research_config();
        let first = discover_motifs(&input, &outcomes, &config).unwrap();
        let second = discover_motifs(&input, &outcomes, &config).unwrap();
        assert_eq!(first, second);
        let discovery_identity = |report: &MotifDiscoveryReport| {
            report
                .candidates
                .iter()
                .map(|candidate| {
                    (
                        candidate.motif_id.clone(),
                        candidate
                            .occurrences
                            .iter()
                            .filter(|occurrence| occurrence.partition == MotifPartition::Discovery)
                            .map(|occurrence| occurrence.start_index)
                            .collect::<Vec<_>>(),
                    )
                })
                .collect::<Vec<_>>()
        };
        let baseline_identity = discovery_identity(&first);
        let mut later_paths_changed = input.clone();
        for index in 0..later_paths_changed.values.len() {
            if later_paths_changed.session_dates[index] > config.discovery_end {
                later_paths_changed.values[index] = ((index * 37) % 19) as f64 / 10.0 - 1.0;
            }
        }
        let changed = discover_motifs(&later_paths_changed, &outcomes, &config).unwrap();
        assert_eq!(baseline_identity, discovery_identity(&changed));
        assert_eq!(first.windows_evaluated, vec![3, 5]);
        assert!(!first.candidates.is_empty());
        assert!(
            first
                .candidates
                .iter()
                .all(|candidate| candidate.metadata.resolution_minutes == 1)
        );
        assert!(
            first
                .candidates
                .iter()
                .all(|candidate| candidate.motif_id.starts_with("MOTIF-"))
        );
        assert!(first.candidates.iter().all(|candidate| {
            let eligibility = &candidate.eligibility;
            eligibility.research_candidate
                && eligibility.eligibility_scope == "RESEARCH_CANDIDATE"
                && eligibility.requires_research_factory_fdr
                && !eligibility.paper_eligible
                && !eligibility.oos_eligible
                && !eligibility.trade_eligible
        }));
    }
}
