use std::collections::{BTreeMap, BTreeSet};

use chrono::{DateTime, Datelike, Duration, Utc};
use serde::{Deserialize, Serialize};

pub const RESEARCH_UNIVERSE: [&str; 12] = [
    "SPY", "QQQ", "IWM", "SOXX", "TLT", "HYG", "UUP", "GLD", "NVDA", "AMD", "AVGO", "MU",
];

const MIN_PARTITION_SAMPLES: usize = 20;
const MIN_STABILITY_YEAR_SAMPLES: usize = 20;
const NUMERIC_TOLERANCE: f64 = 1.0e-15;
const MAX_RESIDUAL_ADJACENCY_GAP_MINUTES: i64 = 30;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AssetReturnObservation {
    pub symbol: String,
    pub event_time: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
    pub return_value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LeadLagPoint {
    pub lag_minutes: i32,
    /// Discovery-only correlation used to select the lag.
    pub correlation: Option<f64>,
    /// Discovery-only aligned sample count.
    pub samples: usize,
    #[serde(default)]
    pub partition: String,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PeriodStability {
    pub period: String,
    /// Untouched-evaluation correlation. Under-sampled years report `None`.
    pub correlation: Option<f64>,
    pub samples: usize,
    #[serde(default)]
    pub partition: String,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct LeadLagPartitionAudit {
    pub partition: String,
    pub start_inclusive: Option<DateTime<Utc>>,
    pub end_inclusive: Option<DateTime<Utc>>,
    pub selected_lag_samples: usize,
    pub minimum_samples_required: usize,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CrossAssetLeadLagAudit {
    pub leader: String,
    pub follower: String,
    /// Selected exclusively on the earlier discovery partition.
    pub selected_lag_minutes: Option<i32>,
    #[serde(default)]
    pub selected_discovery_correlation: Option<f64>,
    /// Correlation for the selected lag on the later evaluation partition.
    pub selected_correlation: Option<f64>,
    /// Reversed-direction placebo on the same later evaluation partition.
    pub reversed_placebo_correlation: Option<f64>,
    pub lag_curve: Vec<LeadLagPoint>,
    pub stability_by_year: Vec<PeriodStability>,
    pub residual_momentum_correlation: Option<f64>,
    pub residual_mean_reversion_correlation: Option<f64>,
    #[serde(default)]
    pub residual_adjacent_samples: usize,
    #[serde(default)]
    /// Evaluation residual transitions excluded for session or time gaps.
    pub residual_transitions_skipped: usize,
    #[serde(default)]
    /// Maximum elapsed minutes allowed for an adjacent residual pair.
    pub residual_maximum_gap_minutes: i64,
    #[serde(default)]
    pub residual_diagnostic_status: String,
    #[serde(default)]
    pub discovery_partition: LeadLagPartitionAudit,
    #[serde(default)]
    pub evaluation_partition: LeadLagPartitionAudit,
    #[serde(default)]
    pub reversed_placebo_evaluation_samples: usize,
    #[serde(default)]
    pub valid_stability_years: usize,
    #[serde(default)]
    pub stable_across_time: bool,
    #[serde(default)]
    pub valid_point_in_time_rows: usize,
    pub point_in_time_rows_rejected: usize,
    #[serde(default)]
    pub duplicate_rows_rejected: usize,
    #[serde(default)]
    pub non_finite_rows_rejected: usize,
    #[serde(default)]
    pub delayed_rows_rejected: usize,
    #[serde(default)]
    pub unrelated_rows_ignored: usize,
    #[serde(default)]
    pub candidate_lags_rejected: usize,
    pub status: String,
    pub causality_claim: String,
    #[serde(default)]
    pub edge_claim: String,
}

#[derive(Debug, Clone, Default)]
struct ValidatedSeries {
    values: BTreeMap<DateTime<Utc>, f64>,
}

#[derive(Debug, Clone, Default)]
struct ObservationValidation {
    by_symbol: BTreeMap<String, ValidatedSeries>,
    valid_rows: usize,
    duplicate_rows_rejected: usize,
    non_finite_rows_rejected: usize,
    delayed_rows_rejected: usize,
    unrelated_rows_ignored: usize,
}

impl ObservationValidation {
    fn rejected_rows(&self) -> usize {
        self.duplicate_rows_rejected + self.non_finite_rows_rejected + self.delayed_rows_rejected
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct AlignedPair {
    target_time: DateTime<Utc>,
    leader_return: f64,
    follower_return: f64,
}

fn normalized_symbol(symbol: &str) -> String {
    symbol.trim().to_ascii_uppercase()
}

/// Builds unique, finite, point-in-time series. If a symbol/timestamp key is
/// duplicated, every row for that key is rejected so input ordering can never
/// choose which value survives.
fn validate_observations(
    observations: &[AssetReturnObservation],
    included_symbols: &BTreeSet<String>,
) -> ObservationValidation {
    let mut grouped = BTreeMap::<(String, DateTime<Utc>), Vec<&AssetReturnObservation>>::new();
    let mut validation = ObservationValidation::default();
    for row in observations {
        let symbol = normalized_symbol(&row.symbol);
        if !included_symbols.contains(&symbol) {
            validation.unrelated_rows_ignored += 1;
            continue;
        }
        grouped
            .entry((symbol, row.event_time))
            .or_default()
            .push(row);
    }

    for ((symbol, event_time), rows) in grouped {
        if rows.len() != 1 {
            validation.duplicate_rows_rejected += rows.len();
            continue;
        }
        let row = rows[0];
        if !row.return_value.is_finite() {
            validation.non_finite_rows_rejected += 1;
            continue;
        }
        if row.available_at > row.event_time {
            validation.delayed_rows_rejected += 1;
            continue;
        }
        validation
            .by_symbol
            .entry(symbol)
            .or_default()
            .values
            .insert(event_time, row.return_value);
        validation.valid_rows += 1;
    }
    validation
}

fn correlation(pairs: &[(f64, f64)]) -> Option<f64> {
    if pairs.len() < 3
        || pairs
            .iter()
            .any(|(left, right)| !left.is_finite() || !right.is_finite())
    {
        return None;
    }
    let n = pairs.len() as f64;
    let mean_x = pairs.iter().map(|pair| pair.0 / n).sum::<f64>();
    let mean_y = pairs.iter().map(|pair| pair.1 / n).sum::<f64>();
    if !mean_x.is_finite() || !mean_y.is_finite() {
        return None;
    }
    let covariance = pairs
        .iter()
        .map(|pair| (pair.0 - mean_x) * (pair.1 - mean_y))
        .sum::<f64>();
    let x_variance = pairs
        .iter()
        .map(|pair| (pair.0 - mean_x).powi(2))
        .sum::<f64>();
    let y_variance = pairs
        .iter()
        .map(|pair| (pair.1 - mean_y).powi(2))
        .sum::<f64>();
    let denominator = (x_variance * y_variance).sqrt();
    if !covariance.is_finite() || !denominator.is_finite() || denominator <= NUMERIC_TOLERANCE {
        return None;
    }
    let value = covariance / denominator;
    value.is_finite().then_some(value.clamp(-1.0, 1.0))
}

/// Aligns already validated series and returns pairs in deterministic target
/// time order. The `ValidatedSeries` type prevents duplicate, non-finite, or
/// delayed observations from reaching alignment.
fn aligned_pairs(
    leader: &ValidatedSeries,
    follower: &ValidatedSeries,
    lag_minutes: i32,
) -> Vec<AlignedPair> {
    if lag_minutes <= 0 {
        return Vec::new();
    }
    let lag = Duration::minutes(i64::from(lag_minutes));
    let mut pairs = leader
        .values
        .iter()
        .filter_map(|(timestamp, leader_return)| {
            let target_time = timestamp.checked_add_signed(lag)?;
            let follower_return = follower.values.get(&target_time)?;
            Some(AlignedPair {
                target_time,
                leader_return: *leader_return,
                follower_return: *follower_return,
            })
        })
        .collect::<Vec<_>>();
    pairs.sort_by_key(|row| row.target_time);
    pairs
}

fn pair_values(pairs: &[AlignedPair]) -> Vec<(f64, f64)> {
    pairs
        .iter()
        .map(|row| (row.leader_return, row.follower_return))
        .collect()
}

fn partition_cutoff(series: &ValidatedSeries) -> Option<DateTime<Utc>> {
    if series.values.len() < 2 {
        return None;
    }
    series.values.keys().nth(series.values.len() / 2).copied()
}

fn discovery_pairs(pairs: &[AlignedPair], cutoff: DateTime<Utc>) -> Vec<AlignedPair> {
    pairs
        .iter()
        .copied()
        .filter(|row| row.target_time < cutoff)
        .collect()
}

fn evaluation_pairs(pairs: &[AlignedPair], cutoff: DateTime<Utc>) -> Vec<AlignedPair> {
    pairs
        .iter()
        .copied()
        .filter(|row| row.target_time >= cutoff)
        .collect()
}

fn partition_bounds(
    follower: &ValidatedSeries,
    cutoff: Option<DateTime<Utc>>,
    discovery: bool,
) -> (Option<DateTime<Utc>>, Option<DateTime<Utc>>) {
    let mut times = follower
        .values
        .keys()
        .copied()
        .filter(|timestamp| match cutoff {
            Some(cutoff) if discovery => *timestamp < cutoff,
            Some(cutoff) => *timestamp >= cutoff,
            None => false,
        });
    let start = times.next();
    let end = times.next_back().or(start);
    (start, end)
}

fn fit_discovery_linear_model(pairs: &[AlignedPair]) -> Option<(f64, f64)> {
    if pairs.len() < 3 {
        return None;
    }
    let n = pairs.len() as f64;
    let mean_x = pairs.iter().map(|row| row.leader_return / n).sum::<f64>();
    let mean_y = pairs.iter().map(|row| row.follower_return / n).sum::<f64>();
    let covariance = pairs
        .iter()
        .map(|row| (row.leader_return - mean_x) * (row.follower_return - mean_y))
        .sum::<f64>();
    let variance = pairs
        .iter()
        .map(|row| (row.leader_return - mean_x).powi(2))
        .sum::<f64>();
    if !mean_x.is_finite()
        || !mean_y.is_finite()
        || !covariance.is_finite()
        || !variance.is_finite()
        || variance <= NUMERIC_TOLERANCE
    {
        return None;
    }
    let beta = covariance / variance;
    let intercept = mean_y - beta * mean_x;
    (beta.is_finite() && intercept.is_finite()).then_some((intercept, beta))
}

fn residual_autocorrelations(
    discovery: &[AlignedPair],
    evaluation: &[AlignedPair],
) -> (Option<f64>, Option<f64>, usize, usize, String) {
    let Some((intercept, beta)) = fit_discovery_linear_model(discovery) else {
        return (
            None,
            None,
            0,
            0,
            "DISCOVERY_LINEAR_FIT_UNAVAILABLE".to_string(),
        );
    };
    let residuals = evaluation
        .iter()
        .map(|row| {
            (
                row.target_time,
                row.follower_return - (intercept + beta * row.leader_return),
            )
        })
        .collect::<Vec<_>>();
    if residuals.iter().any(|(_, value)| !value.is_finite()) {
        return (
            None,
            None,
            0,
            0,
            "NON_FINITE_EVALUATION_RESIDUAL".to_string(),
        );
    }
    let maximum_gap = Duration::minutes(MAX_RESIDUAL_ADJACENCY_GAP_MINUTES);
    let mut adjacent = Vec::new();
    let mut transitions_skipped = 0;
    for window in residuals.windows(2) {
        let elapsed = window[1].0.signed_duration_since(window[0].0);
        let same_utc_date = window[0].0.date_naive() == window[1].0.date_naive();
        if same_utc_date && elapsed > Duration::zero() && elapsed <= maximum_gap {
            adjacent.push((window[0].1, window[1].1));
        } else {
            transitions_skipped += 1;
        }
    }
    let momentum = correlation(&adjacent);
    let mean_reversion_pairs = adjacent
        .iter()
        .map(|(current, next)| (*current, -*next))
        .collect::<Vec<_>>();
    let mean_reversion = correlation(&mean_reversion_pairs);
    let status = if adjacent.len() < 3 {
        "INSUFFICIENT_ADJACENT_EVALUATION_RESIDUALS"
    } else if momentum.is_none() || mean_reversion.is_none() {
        "RESIDUAL_AUTOCORRELATION_UNAVAILABLE"
    } else {
        "EVALUATION_ADJACENT_RESIDUAL_AUTOCORRELATION"
    };
    (
        momentum,
        mean_reversion,
        adjacent.len(),
        transitions_skipped,
        status.to_string(),
    )
}

fn direction(value: f64) -> i8 {
    if value > NUMERIC_TOLERANCE {
        1
    } else if value < -NUMERIC_TOLERANCE {
        -1
    } else {
        0
    }
}

fn yearly_stability(pairs: &[AlignedPair]) -> (Vec<PeriodStability>, usize, bool) {
    let mut by_year = BTreeMap::<i32, Vec<(f64, f64)>>::new();
    for row in pairs {
        by_year
            .entry(row.target_time.year())
            .or_default()
            .push((row.leader_return, row.follower_return));
    }
    let rows = by_year
        .into_iter()
        .map(|(year, pairs)| {
            let raw_correlation = correlation(&pairs);
            let valid = pairs.len() >= MIN_STABILITY_YEAR_SAMPLES
                && raw_correlation.is_some_and(|value| direction(value) != 0);
            PeriodStability {
                period: year.to_string(),
                correlation: valid.then_some(raw_correlation).flatten(),
                samples: pairs.len(),
                partition: "EVALUATION_ONLY".to_string(),
                status: if pairs.len() < MIN_STABILITY_YEAR_SAMPLES {
                    "INSUFFICIENT_YEAR_SAMPLES"
                } else if raw_correlation.is_none() {
                    "CORRELATION_UNAVAILABLE"
                } else if raw_correlation.is_some_and(|value| direction(value) == 0) {
                    "ZERO_DIRECTION"
                } else {
                    "VALID_DIRECTIONAL_YEAR"
                }
                .to_string(),
            }
        })
        .collect::<Vec<_>>();
    let valid = rows
        .iter()
        .filter_map(|row| row.correlation)
        .collect::<Vec<_>>();
    let stable = valid.len() >= 2
        && valid
            .iter()
            .all(|value| direction(*value) == direction(valid[0]));
    (rows, valid.len(), stable)
}

/// Audits descriptive predictive timing, never causality or a trading edge.
/// Candidate lag selection is confined to the earlier chronological half;
/// all reported selected-lag diagnostics use the untouched later half.
pub fn audit_lead_lag(
    observations: &[AssetReturnObservation],
    leader_symbol: &str,
    follower_symbol: &str,
    candidate_lags_minutes: &[i32],
) -> CrossAssetLeadLagAudit {
    let leader_symbol = normalized_symbol(leader_symbol);
    let follower_symbol = normalized_symbol(follower_symbol);
    let included_symbols = [leader_symbol.clone(), follower_symbol.clone()]
        .into_iter()
        .collect::<BTreeSet<_>>();
    let validation = validate_observations(observations, &included_symbols);
    let empty = ValidatedSeries::default();
    let leader = validation.by_symbol.get(&leader_symbol).unwrap_or(&empty);
    let follower = validation.by_symbol.get(&follower_symbol).unwrap_or(&empty);
    let cutoff = partition_cutoff(follower);

    let valid_lags = candidate_lags_minutes
        .iter()
        .copied()
        .filter(|lag| *lag > 0)
        .collect::<BTreeSet<_>>();
    let candidate_lags_rejected = candidate_lags_minutes
        .len()
        .saturating_sub(valid_lags.len());
    let mut lag_curve = valid_lags
        .iter()
        .copied()
        .map(|lag| {
            let discovery = cutoff
                .map(|cutoff| discovery_pairs(&aligned_pairs(leader, follower, lag), cutoff))
                .unwrap_or_default();
            let correlation = correlation(&pair_values(&discovery));
            LeadLagPoint {
                lag_minutes: lag,
                correlation,
                samples: discovery.len(),
                partition: "DISCOVERY_ONLY".to_string(),
                status: if discovery.len() < MIN_PARTITION_SAMPLES {
                    "INSUFFICIENT_DISCOVERY_SAMPLES"
                } else if correlation.is_none() {
                    "DISCOVERY_CORRELATION_UNAVAILABLE"
                } else {
                    "VALID_FOR_LAG_SELECTION"
                }
                .to_string(),
            }
        })
        .collect::<Vec<_>>();
    lag_curve.sort_by_key(|row| row.lag_minutes);

    let mut selectable_lags = lag_curve
        .iter()
        .filter_map(|row| {
            (row.samples >= MIN_PARTITION_SAMPLES)
                .then_some(row.correlation)
                .flatten()
                .map(|correlation| (row.lag_minutes, correlation, row.samples))
        })
        .collect::<Vec<_>>();
    selectable_lags.sort_by(|left, right| {
        right
            .1
            .abs()
            .total_cmp(&left.1.abs())
            .then_with(|| left.0.cmp(&right.0))
    });
    let selected = selectable_lags.first().copied();
    let selected_lag = selected.map(|row| row.0);
    let selected_discovery_correlation = selected.map(|row| row.1);

    let selected_all_pairs = selected_lag
        .map(|lag| aligned_pairs(leader, follower, lag))
        .unwrap_or_default();
    let selected_discovery_pairs = cutoff
        .map(|cutoff| discovery_pairs(&selected_all_pairs, cutoff))
        .unwrap_or_default();
    let selected_evaluation_pairs = cutoff
        .map(|cutoff| evaluation_pairs(&selected_all_pairs, cutoff))
        .unwrap_or_default();
    let selected_correlation = (selected_evaluation_pairs.len() >= MIN_PARTITION_SAMPLES)
        .then(|| correlation(&pair_values(&selected_evaluation_pairs)))
        .flatten();

    let reversed_evaluation_pairs = match (selected_lag, cutoff) {
        (Some(lag), Some(cutoff)) => {
            evaluation_pairs(&aligned_pairs(follower, leader, lag), cutoff)
        }
        _ => Vec::new(),
    };
    let reversed = (reversed_evaluation_pairs.len() >= MIN_PARTITION_SAMPLES)
        .then(|| correlation(&pair_values(&reversed_evaluation_pairs)))
        .flatten();

    let (stability_by_year, valid_stability_years, stable_across_time) =
        yearly_stability(&selected_evaluation_pairs);
    let (
        residual_momentum,
        residual_mean_reversion,
        residual_adjacent_samples,
        residual_transitions_skipped,
        residual_status,
    ) = residual_autocorrelations(&selected_discovery_pairs, &selected_evaluation_pairs);

    let (discovery_start, discovery_end) = partition_bounds(follower, cutoff, true);
    let (evaluation_start, evaluation_end) = partition_bounds(follower, cutoff, false);
    let discovery_samples = selected
        .map(|row| row.2)
        .or_else(|| lag_curve.iter().map(|row| row.samples).max())
        .unwrap_or_default();
    let discovery_partition = LeadLagPartitionAudit {
        partition: "DISCOVERY_LAG_SELECTION_ONLY".to_string(),
        start_inclusive: discovery_start,
        end_inclusive: discovery_end,
        selected_lag_samples: discovery_samples,
        minimum_samples_required: MIN_PARTITION_SAMPLES,
        status: if cutoff.is_none() {
            "CHRONOLOGICAL_PARTITION_UNAVAILABLE"
        } else if selected_lag.is_none() {
            "NO_LAG_PASSED_DISCOVERY_REQUIREMENTS"
        } else {
            "LAG_SELECTED"
        }
        .to_string(),
    };
    let evaluation_partition = LeadLagPartitionAudit {
        partition: "UNTOUCHED_EVALUATION_ONLY".to_string(),
        start_inclusive: evaluation_start,
        end_inclusive: evaluation_end,
        selected_lag_samples: selected_evaluation_pairs.len(),
        minimum_samples_required: MIN_PARTITION_SAMPLES,
        status: if selected_lag.is_none() {
            "NO_DISCOVERY_SELECTED_LAG"
        } else if selected_evaluation_pairs.len() < MIN_PARTITION_SAMPLES {
            "INSUFFICIENT_EVALUATION_SAMPLES"
        } else if selected_correlation.is_none() {
            "EVALUATION_CORRELATION_UNAVAILABLE"
        } else {
            "VALID_UNTOUCHED_EVALUATION"
        }
        .to_string(),
    };

    let invalid_symbol_pair =
        leader_symbol.is_empty() || follower_symbol.is_empty() || leader_symbol == follower_symbol;
    let placebo_weaker = match (selected_correlation, reversed) {
        (Some(selected), Some(placebo)) => selected.abs() > placebo.abs(),
        _ => false,
    };
    let status = if invalid_symbol_pair {
        "INVALID_LEADER_FOLLOWER_PAIR"
    } else if valid_lags.is_empty() {
        "NO_UNIQUE_POSITIVE_CANDIDATE_LAGS"
    } else if cutoff.is_none() {
        "CHRONOLOGICAL_PARTITION_UNAVAILABLE"
    } else if selected_lag.is_none() {
        "INSUFFICIENT_DISCOVERY_SAMPLES"
    } else if selected_evaluation_pairs.len() < MIN_PARTITION_SAMPLES {
        "INSUFFICIENT_EVALUATION_SAMPLES"
    } else if selected_correlation.is_none() {
        "EVALUATION_CORRELATION_UNAVAILABLE"
    } else if valid_stability_years < 2 {
        "UNSTABLE_ACROSS_TIME_INSUFFICIENT_VALID_YEARS"
    } else if !stable_across_time {
        "UNSTABLE_ACROSS_TIME_DIRECTION_CHANGED"
    } else if reversed_evaluation_pairs.len() < MIN_PARTITION_SAMPLES || reversed.is_none() {
        "REVERSED_DIRECTION_PLACEBO_UNAVAILABLE"
    } else if !placebo_weaker {
        "REVERSED_DIRECTION_PLACEBO_NOT_WEAKER"
    } else {
        "DESCRIPTIVE_RELATIONSHIP_ONLY"
    };

    CrossAssetLeadLagAudit {
        leader: leader_symbol,
        follower: follower_symbol,
        selected_lag_minutes: selected_lag,
        selected_discovery_correlation,
        selected_correlation,
        reversed_placebo_correlation: reversed,
        lag_curve,
        stability_by_year,
        residual_momentum_correlation: residual_momentum,
        residual_mean_reversion_correlation: residual_mean_reversion,
        residual_adjacent_samples,
        residual_diagnostic_status: residual_status,
        discovery_partition,
        residual_transitions_skipped,
        residual_maximum_gap_minutes: MAX_RESIDUAL_ADJACENCY_GAP_MINUTES,
        evaluation_partition,
        reversed_placebo_evaluation_samples: reversed_evaluation_pairs.len(),
        valid_stability_years,
        stable_across_time,
        valid_point_in_time_rows: validation.valid_rows,
        point_in_time_rows_rejected: validation.rejected_rows(),
        duplicate_rows_rejected: validation.duplicate_rows_rejected,
        non_finite_rows_rejected: validation.non_finite_rows_rejected,
        delayed_rows_rejected: validation.delayed_rows_rejected,
        unrelated_rows_ignored: validation.unrelated_rows_ignored,
        candidate_lags_rejected,
        status: status.to_string(),
        causality_claim: "NONE_DESCRIPTIVE_LEAD_LAG_IS_NOT_CAUSAL_IDENTIFICATION".to_string(),
        edge_claim: "NONE_DESCRIPTIVE_DIAGNOSTIC_IS_NOT_A_TRADING_EDGE".to_string(),
    }
}

pub fn coverage_status(observations: &[AssetReturnObservation]) -> BTreeMap<String, String> {
    let universe = RESEARCH_UNIVERSE
        .iter()
        .map(|symbol| (*symbol).to_string())
        .collect::<BTreeSet<_>>();
    let validation = validate_observations(observations, &universe);
    RESEARCH_UNIVERSE
        .iter()
        .map(|symbol| {
            let available = validation
                .by_symbol
                .get(*symbol)
                .is_some_and(|series| !series.values.is_empty());
            (
                (*symbol).to_string(),
                if available {
                    "AVAILABLE_VALID_POINT_IN_TIME"
                } else {
                    "MISSING_NO_VALID_POINT_IN_TIME_ROWS"
                }
                .to_string(),
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone, Utc};

    use super::{AssetReturnObservation, audit_lead_lag, coverage_status};

    fn observation(
        symbol: &str,
        event_time: chrono::DateTime<Utc>,
        return_value: f64,
    ) -> AssetReturnObservation {
        AssetReturnObservation {
            symbol: symbol.to_string(),
            event_time,
            available_at: event_time,
            return_value,
        }
    }

    fn one_year_rows() -> Vec<AssetReturnObservation> {
        let start = Utc.with_ymd_and_hms(2024, 1, 2, 14, 30, 0).unwrap();
        let mut rows = Vec::new();
        for index in 0..80 {
            let timestamp = start + Duration::minutes(index);
            let signal = ((index * 7 % 13) as f64 - 6.0) / 1000.0;
            rows.push(observation("SOXX", timestamp, signal));
            rows.push(observation(
                "QQQ",
                timestamp + Duration::minutes(1),
                signal * 0.8,
            ));
        }
        rows
    }

    fn partition_shift_rows() -> Vec<AssetReturnObservation> {
        let mut rows = Vec::new();
        for year in 2021..=2024 {
            let start = Utc.with_ymd_and_hms(year, 1, 4, 14, 30, 0).unwrap();
            for index in 0..30 {
                let timestamp = start + Duration::minutes(index * 10);
                let signal = (((index * 7 + year as i64) % 31) as f64 - 15.0) / 1000.0;
                let noise = (((index * 11 + year as i64 * 3) % 29) as f64 - 14.0) / 1000.0;
                rows.push(observation("SOXX", timestamp, signal));
                let (lag_one, lag_two) = if year <= 2022 {
                    (signal, noise)
                } else {
                    (noise, signal)
                };
                rows.push(observation(
                    "QQQ",
                    timestamp + Duration::minutes(1),
                    lag_one,
                ));
                rows.push(observation(
                    "QQQ",
                    timestamp + Duration::minutes(2),
                    lag_two,
                ));
            }
        }
        rows
    }

    fn stable_residual_rows() -> Vec<AssetReturnObservation> {
        let mut rows = Vec::new();
        for year in 2021..=2024 {
            let start = Utc.with_ymd_and_hms(year, 2, 1, 14, 30, 0).unwrap();
            for index in 0..30 {
                let gap_offset = if index >= 15 { 60 } else { 0 };
                let timestamp = start + Duration::minutes(index * 10 + gap_offset);
                let signal = (((index * 13 + year as i64) % 37) as f64 - 18.0) / 1000.0;
                let residual = (index as f64 / 4.0).sin() * 0.002;
                rows.push(observation("SOXX", timestamp, signal));
                rows.push(observation(
                    "QQQ",
                    timestamp + Duration::minutes(1),
                    0.8 * signal + residual,
                ));
            }
        }
        rows
    }

    #[test]
    fn alignment_is_deterministic_and_rejects_bad_point_in_time_rows() {
        let mut rows = one_year_rows();
        let duplicate = rows[10].clone();
        rows.push(duplicate);
        let bad_time = Utc.with_ymd_and_hms(2024, 1, 3, 14, 30, 0).unwrap();
        rows.push(observation("SOXX", bad_time, f64::NAN));
        rows.push(AssetReturnObservation {
            symbol: "QQQ".into(),
            event_time: bad_time + Duration::minutes(1),
            available_at: bad_time + Duration::minutes(2),
            return_value: 0.1,
        });
        rows.push(observation("SPY", bad_time, 0.01));

        let first = audit_lead_lag(&rows, "SOXX", "QQQ", &[3, 1, 2, 1, 0, -1]);
        rows.reverse();
        let reversed_input = audit_lead_lag(&rows, "SOXX", "QQQ", &[1, -1, 3, 2, 0, 1]);
        assert_eq!(first, reversed_input);
        assert_eq!(first.selected_lag_minutes, Some(1));
        assert_eq!(first.duplicate_rows_rejected, 2);
        assert_eq!(first.non_finite_rows_rejected, 1);
        assert_eq!(first.delayed_rows_rejected, 1);
        assert_eq!(first.point_in_time_rows_rejected, 4);
        assert_eq!(first.unrelated_rows_ignored, 1);
        assert_eq!(first.candidate_lags_rejected, 3);
        assert_eq!(
            first.causality_claim,
            "NONE_DESCRIPTIVE_LEAD_LAG_IS_NOT_CAUSAL_IDENTIFICATION"
        );
        assert_eq!(
            first.edge_claim,
            "NONE_DESCRIPTIVE_DIAGNOSTIC_IS_NOT_A_TRADING_EDGE"
        );
    }

    #[test]
    fn discovery_selects_lag_and_evaluation_reports_it_without_reselection() {
        let rows = partition_shift_rows();
        let audit = audit_lead_lag(&rows, "SOXX", "QQQ", &[1, 2]);
        assert_eq!(audit.selected_lag_minutes, Some(1));
        assert!(audit.selected_discovery_correlation.unwrap() > 0.99);
        assert!(audit.selected_correlation.unwrap().abs() < 0.5);
        assert_eq!(audit.discovery_partition.status, "LAG_SELECTED");
        assert_eq!(
            audit.evaluation_partition.status,
            "VALID_UNTOUCHED_EVALUATION"
        );
        assert!(
            audit.discovery_partition.end_inclusive.unwrap()
                < audit.evaluation_partition.start_inclusive.unwrap()
        );
        let lag_two = audit
            .lag_curve
            .iter()
            .find(|row| row.lag_minutes == 2)
            .unwrap();
        assert_eq!(lag_two.partition, "DISCOVERY_ONLY");
    }

    #[test]
    fn residual_diagnostics_use_sorted_adjacent_evaluation_residuals() {
        let rows = stable_residual_rows();
        let audit = audit_lead_lag(&rows, "SOXX", "QQQ", &[1]);
        assert_eq!(audit.selected_lag_minutes, Some(1));
        assert_eq!(audit.valid_stability_years, 2);
        assert!(audit.stable_across_time);
        assert_eq!(audit.residual_adjacent_samples, 56);
        assert_eq!(audit.residual_transitions_skipped, 3);
        assert_eq!(audit.residual_maximum_gap_minutes, 30);
        assert!(audit.residual_momentum_correlation.unwrap() > 0.7);
        assert!(audit.residual_mean_reversion_correlation.unwrap() < -0.7);
        assert_eq!(
            audit.residual_diagnostic_status,
            "EVALUATION_ADJACENT_RESIDUAL_AUTOCORRELATION"
        );
    }

    #[test]
    fn stable_across_time_requires_two_valid_evaluation_years() {
        let audit = audit_lead_lag(&one_year_rows(), "SOXX", "QQQ", &[1, 2, 3]);
        assert_eq!(audit.selected_lag_minutes, Some(1));
        assert_eq!(audit.valid_stability_years, 1);
        assert!(!audit.stable_across_time);
        assert_eq!(
            audit.status,
            "UNSTABLE_ACROSS_TIME_INSUFFICIENT_VALID_YEARS"
        );
    }

    #[test]
    fn coverage_requires_a_unique_finite_timely_row() {
        let start = Utc.with_ymd_and_hms(2024, 1, 2, 14, 30, 0).unwrap();
        let mut rows = vec![
            observation("SPY", start, f64::NAN),
            observation("QQQ", start, 0.01),
            observation("IWM", start, 0.02),
            observation("IWM", start, 0.03),
            AssetReturnObservation {
                symbol: "TLT".into(),
                event_time: start,
                available_at: start + Duration::seconds(1),
                return_value: 0.01,
            },
        ];
        rows.push(observation("NOT_IN_UNIVERSE", start, 0.01));
        let coverage = coverage_status(&rows);
        assert_eq!(coverage["QQQ"], "AVAILABLE_VALID_POINT_IN_TIME");
        assert_eq!(coverage["SPY"], "MISSING_NO_VALID_POINT_IN_TIME_ROWS");
        assert_eq!(coverage["IWM"], "MISSING_NO_VALID_POINT_IN_TIME_ROWS");
        assert_eq!(coverage["TLT"], "MISSING_NO_VALID_POINT_IN_TIME_ROWS");
    }
}
