//! End-to-end autonomous pattern research runner.
//!
//! This module connects motif discovery to family-wise false-discovery control
//! and an explicit conditional strategy. It produces research and shadow
//! candidates only; replayed history can never make a strategy trade eligible.

use std::collections::{BTreeMap, BTreeSet, HashMap};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::{
    anomaly_research::benjamini_hochberg,
    domain::MarketState,
    motif_discovery::{
        MotifCandidate, MotifDiscoveryConfig, MotifForwardOutcome, MotifPartition, PathValueKind,
        ReturnPathSeries, discover_motifs_approximate, normalize_return_path,
    },
};

pub const PATTERN_FACTORY_SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PatternFactoryConfig {
    pub window_observations: Vec<usize>,
    pub outcome_horizon_minutes: usize,
    pub maximum_normalized_distance: f64,
    pub maximum_candidates_per_window: usize,
    pub projection_count: usize,
    pub projection_neighbor_span: usize,
    pub round_trip_cost_bps: f64,
    pub maximum_fdr_q_value: f64,
    pub permutation_resamples: usize,
    pub random_seed: u64,
}

impl Default for PatternFactoryConfig {
    fn default() -> Self {
        Self {
            window_observations: vec![3, 5, 10, 15, 30, 60],
            outcome_horizon_minutes: 15,
            maximum_normalized_distance: 0.35,
            maximum_candidates_per_window: 3,
            projection_count: 8,
            projection_neighbor_span: 4,
            round_trip_cost_bps: 3.0,
            maximum_fdr_q_value: 0.10,
            permutation_resamples: 2_048,
            random_seed: 7,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AutomaticPartitionPlan {
    pub first_session: NaiveDate,
    pub discovery_end: NaiveDate,
    pub validation_end: NaiveDate,
    pub test_end: NaiveDate,
    pub last_session: NaiveDate,
    pub discovery_sessions: usize,
    pub validation_sessions: usize,
    pub test_sessions: usize,
    pub forward_shadow_sessions: usize,
    pub purge_calendar_days: usize,
    pub assignment_semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ConditionalStrategy {
    pub trigger: String,
    pub conditional_action: String,
    pub current_action: String,
    pub direction: i8,
    pub entry_rule: String,
    pub exit_rule: String,
    pub holding_minutes: usize,
    pub assumed_round_trip_cost_bps: f64,
    pub expected_test_net_bps: f64,
    pub test_win_rate: f64,
    pub current_similarity: Option<f64>,
    pub current_normalized_distance: Option<f64>,
    pub current_match: bool,
    pub guardrails: Vec<String>,
    pub paper_eligible: bool,
    pub trade_eligible: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PatternFactoryCandidate {
    pub motif: MotifCandidate,
    pub occurrence_count_total: usize,
    pub occurrence_rows_persisted: usize,
    pub occurrence_persistence_status: String,
    pub raw_permutation_p_value: f64,
    pub fdr_adjusted_p_value: f64,
    pub fdr_passed: bool,
    pub strategy: ConditionalStrategy,
    pub lifecycle_status: String,
    pub rejection_reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AutonomousPatternReport {
    pub schema_version: u32,
    pub generated_at: DateTime<Utc>,
    pub symbol: String,
    pub evidence_available_as_of: DateTime<Utc>,
    pub partition_plan: AutomaticPartitionPlan,
    pub search_method: String,
    pub windows_evaluated: Vec<usize>,
    pub hypothesis_family_size: usize,
    pub fdr_survivors: usize,
    pub current_matches: usize,
    pub candidates: Vec<PatternFactoryCandidate>,
    pub promotion_ceiling: String,
    pub warnings: Vec<String>,
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
}

fn automatic_partitions(dates: &[NaiveDate]) -> Result<AutomaticPartitionPlan> {
    if dates.len() < 60 {
        bail!("autonomous pattern discovery requires at least 60 independent sessions");
    }
    let discovery_index =
        ((dates.len() as f64 * 0.55).floor() as usize).clamp(10, dates.len().saturating_sub(4));
    let validation_index = ((dates.len() as f64 * 0.72).floor() as usize)
        .clamp(discovery_index + 2, dates.len().saturating_sub(3));
    let test_index = ((dates.len() as f64 * 0.88).floor() as usize)
        .clamp(validation_index + 2, dates.len().saturating_sub(2));
    let discovery_end = dates[discovery_index];
    let validation_end = dates[validation_index];
    let test_end = dates[test_index];
    let purge_calendar_days = 1usize;
    let purge = Duration::days(purge_calendar_days as i64);
    let count = |after: Option<NaiveDate>, through: NaiveDate| {
        dates
            .iter()
            .filter(|date| after.is_none_or(|start| **date > start) && **date <= through)
            .count()
    };
    Ok(AutomaticPartitionPlan {
        first_session: dates[0],
        discovery_end,
        validation_end,
        test_end,
        last_session: *dates.last().context("session dates are absent")?,
        discovery_sessions: count(None, discovery_end),
        validation_sessions: count(Some(discovery_end + purge), validation_end),
        test_sessions: count(Some(validation_end + purge), test_end),
        forward_shadow_sessions: dates.iter().filter(|date| **date > test_end).count(),
        purge_calendar_days,
        assignment_semantics:
            "AUTOMATIC_CHRONOLOGICAL_55_17_16_12_PERCENT_RESEARCH_SPLIT_WITH_PURGE".into(),
    })
}

fn build_series_and_outcomes(
    states: &[MarketState],
    horizon: usize,
) -> Result<(ReturnPathSeries, Vec<MotifForwardOutcome>)> {
    let first = states
        .first()
        .context("pattern factory requires market states")?;
    if states.iter().any(|state| state.symbol != first.symbol)
        || states
            .windows(2)
            .any(|pair| pair[0].timestamp >= pair[1].timestamp)
    {
        bail!("pattern factory requires one strictly ordered symbol series");
    }
    let evidence_available_as_of = states
        .last()
        .context("pattern factory requires market states")?
        .timestamp
        + Duration::minutes(1);
    let series = ReturnPathSeries {
        symbol: first.symbol.clone(),
        resolution_minutes: 1,
        value_kind: PathValueKind::LogReturn,
        timestamps: states.iter().map(|state| state.timestamp).collect(),
        available_at: states
            .iter()
            .map(|state| state.timestamp + Duration::minutes(1))
            .collect(),
        session_dates: states.iter().map(|state| state.session_date).collect(),
        values: states.iter().map(|state| state.ret_1m.ln_1p()).collect(),
    };
    let timestamp_index = states
        .iter()
        .enumerate()
        .map(|(index, state)| (state.timestamp, index))
        .collect::<HashMap<_, _>>();
    let mut outcomes = Vec::new();
    for (anchor, state) in states.iter().enumerate() {
        let entry_timestamp = state.timestamp + Duration::minutes(1);
        let terminal_timestamp = state.timestamp + Duration::minutes(horizon as i64);
        let (Some(entry_index), Some(terminal_index)) = (
            timestamp_index.get(&entry_timestamp).copied(),
            timestamp_index.get(&terminal_timestamp).copied(),
        ) else {
            continue;
        };
        if states[entry_index].session_date != state.session_date
            || states[terminal_index].session_date != state.session_date
            || terminal_index <= anchor
        {
            continue;
        }
        let entry = states[entry_index].open;
        let forward_return = states[terminal_index].close / entry - 1.0;
        let label_available_at = states[terminal_index].timestamp + Duration::minutes(1);
        if entry <= 0.0
            || !forward_return.is_finite()
            || label_available_at > evidence_available_as_of
        {
            continue;
        }
        outcomes.push(MotifForwardOutcome {
            anchor_end_index: anchor,
            horizon_end_index: terminal_index,
            horizon_minutes: horizon,
            forward_return,
            label_available_at,
        });
    }
    Ok((series, outcomes))
}

fn test_day_effects(candidate: &MotifCandidate, cost_bps: f64) -> Vec<(NaiveDate, f64)> {
    let direction = candidate.oos_evidence.selected_direction as f64;
    candidate
        .occurrences
        .iter()
        .filter(|row| row.partition == MotifPartition::Test)
        .filter_map(|row| {
            row.forward_return
                .map(|value| (row.session_date, direction * value * 10_000.0 - cost_bps))
        })
        .collect()
}

fn sign_flip_p_value(effects: &[(NaiveDate, f64)], resamples: usize, seed: u64) -> f64 {
    let mut by_day = BTreeMap::<NaiveDate, Vec<f64>>::new();
    for (date, value) in effects {
        by_day.entry(*date).or_default().push(*value);
    }
    let day_means = by_day
        .into_values()
        .map(|values| values.iter().sum::<f64>() / values.len() as f64)
        .collect::<Vec<_>>();
    if day_means.len() < 2 || resamples == 0 {
        return 1.0;
    }
    let observed = day_means.iter().sum::<f64>() / day_means.len() as f64;
    if observed <= 0.0 {
        return 1.0;
    }
    let mut rng = SplitMix64(seed);
    let mut at_least_as_large = 0usize;
    for _ in 0..resamples {
        let value = day_means
            .iter()
            .map(|effect| {
                if rng.next() & 1 == 0 {
                    *effect
                } else {
                    -*effect
                }
            })
            .sum::<f64>()
            / day_means.len() as f64;
        if value >= observed {
            at_least_as_large += 1;
        }
    }
    (at_least_as_large + 1) as f64 / (resamples + 1) as f64
}

fn current_match(
    series: &ReturnPathSeries,
    candidate: &MotifCandidate,
    maximum_distance: f64,
) -> (Option<f64>, Option<f64>, bool) {
    let window = candidate.metadata.window_observations;
    if series.values.len() < window {
        return (None, None, false);
    }
    let start = series.values.len() - window;
    if series.session_dates[start..]
        .iter()
        .any(|date| *date != series.session_dates[start])
    {
        return (None, None, false);
    }
    let Ok(path) = normalize_return_path(&series.values[start..]) else {
        return (None, None, false);
    };
    let distance = path
        .iter()
        .zip(&candidate.prototype)
        .map(|(left, right)| (left - right).powi(2))
        .sum::<f64>()
        .sqrt()
        / (path.len() as f64).sqrt();
    let similarity = (-0.5 * (distance / maximum_distance.max(1.0e-9)).powi(2)).exp();
    (
        Some(similarity),
        Some(distance),
        distance <= maximum_distance,
    )
}

fn compact_occurrence_lineage(motif: &mut MotifCandidate, maximum_rows: usize) -> usize {
    let total = motif.occurrences.len();
    if total <= maximum_rows || maximum_rows < 2 {
        return total;
    }
    motif.occurrences = (0..maximum_rows)
        .filter_map(|position| {
            let index = position * (total - 1) / (maximum_rows - 1);
            motif.occurrences.get(index).cloned()
        })
        .collect();
    total
}

pub fn run_autonomous_pattern_factory(
    states: &[MarketState],
    config: &PatternFactoryConfig,
) -> Result<AutonomousPatternReport> {
    if config.outcome_horizon_minutes == 0
        || config.window_observations.is_empty()
        || config.projection_count == 0
        || config.projection_neighbor_span == 0
        || config.permutation_resamples < 200
        || !config.maximum_fdr_q_value.is_finite()
        || !(0.0..=1.0).contains(&config.maximum_fdr_q_value)
    {
        bail!("invalid autonomous pattern-factory configuration");
    }
    let (series, outcomes) = build_series_and_outcomes(states, config.outcome_horizon_minutes)?;
    let dates = series
        .session_dates
        .iter()
        .copied()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let partition_plan = automatic_partitions(&dates)?;
    let evidence_available_as_of = *series
        .available_at
        .last()
        .context("return-path availability is absent")?;
    let motif_config = MotifDiscoveryConfig {
        window_observations: config.window_observations.clone(),
        exclusion_zone_observations: 1,
        maximum_normalized_distance: config.maximum_normalized_distance,
        maximum_candidates_per_window: config.maximum_candidates_per_window,
        minimum_occurrences: 6,
        minimum_independent_days: 6,
        maximum_day_concentration: 0.25,
        maximum_month_concentration: 0.50,
        recent_session_window: 20,
        minimum_recent_rate_ratio: 0.20,
        minimum_validation_occurrences: 3,
        minimum_test_occurrences: 3,
        minimum_test_independent_days: 3,
        partition_purge_calendar_days: partition_plan.purge_calendar_days,
        outcome_horizon_minutes: config.outcome_horizon_minutes,
        round_trip_cost_bps: config.round_trip_cost_bps,
        minimum_test_net_mean_bps: 0.5,
        day_block_bootstrap_resamples: 1_024,
        day_block_bootstrap_confidence_level: 0.95,
        minimum_test_net_bootstrap_ci_lower_bps: 0.0,
        discovery_end: partition_plan.discovery_end,
        validation_end: partition_plan.validation_end,
        test_end: partition_plan.test_end,
        evidence_available_as_of,
        change_point_minimum_observations: 4,
        change_point_score_threshold: 4.0,
        negative_control_seed: config.random_seed,
        negative_control_match_tolerance_bps: 0.25,
    };
    let motif_report = discover_motifs_approximate(
        &series,
        &outcomes,
        &motif_config,
        config.projection_count,
        config.projection_neighbor_span,
    )?;
    let raw_p_values = motif_report
        .candidates
        .iter()
        .enumerate()
        .map(|(index, candidate)| {
            sign_flip_p_value(
                &test_day_effects(candidate, config.round_trip_cost_bps),
                config.permutation_resamples,
                config.random_seed ^ index as u64,
            )
        })
        .collect::<Vec<_>>();
    let adjusted = benjamini_hochberg(&raw_p_values)?;
    let mut candidates = Vec::new();
    for (index, mut motif) in motif_report.candidates.into_iter().enumerate() {
        let q_value = adjusted[index];
        let fdr_passed = q_value <= config.maximum_fdr_q_value;
        let (similarity, distance, matches_current) =
            current_match(&series, &motif, config.maximum_normalized_distance);
        let mut rejection_reasons = motif.eligibility.reasons.clone();
        if !fdr_passed {
            rejection_reasons.push("FDR_THRESHOLD_NOT_MET".into());
        }
        let internally_valid = motif.eligibility.reasons.is_empty();
        let shadow_candidate = internally_valid && fdr_passed;
        let direction = motif.oos_evidence.selected_direction;
        let conditional_action = match direction {
            1 => "LONG_UNDERLYING",
            -1 => "SHORT_UNDERLYING",
            _ => "ABSTAIN",
        }
        .to_string();
        let current_action = if shadow_candidate && matches_current {
            format!("SHADOW_{conditional_action}")
        } else {
            "ABSTAIN".into()
        };
        let lifecycle_status = if !internally_valid {
            "REJECTED_INTERNAL_GATES"
        } else if !fdr_passed {
            "REJECTED_FDR"
        } else if matches_current {
            "FORWARD_SHADOW_CURRENT_MATCH"
        } else {
            "FORWARD_SHADOW_WAITING_FOR_MATCH"
        }
        .to_string();
        let strategy = ConditionalStrategy {
            trigger: format!(
                "normalized {}m return path distance <= {:.4}",
                motif.metadata.duration_minutes, config.maximum_normalized_distance
            ),
            conditional_action,
            current_action,
            direction,
            entry_rule: "SIGNAL_AFTER_FINALIZED_BAR; EARLIEST_ENTRY_NEXT_MINUTE_OPEN".into(),
            exit_rule: format!(
                "TIME_EXIT_AFTER_{}_EXECUTABLE_MINUTE_BARS; FORCE_FLAT_AT_SESSION_BOUNDARY",
                config.outcome_horizon_minutes
            ),
            holding_minutes: config.outcome_horizon_minutes,
            assumed_round_trip_cost_bps: config.round_trip_cost_bps,
            expected_test_net_bps: motif.oos_evidence.test_net_mean_bps,
            test_win_rate: motif.oos_evidence.test_net_win_rate,
            current_similarity: similarity,
            current_normalized_distance: distance,
            current_match: matches_current,
            guardrails: vec![
                "RESEARCH_AND_FORWARD_SHADOW_ONLY".into(),
                "ABSTAIN_WHEN_MOTIF_INTERNAL_GATES_OR_FDR_FAIL".into(),
                "NO_OPTION_MAPPING_WITHOUT_HISTORICAL_EXECUTABLE_NBBO".into(),
                "NO_LIVE_ORDER_AUTHORITY".into(),
            ],
            paper_eligible: false,
            trade_eligible: false,
        };
        // Full-run aggregate evidence above remains unchanged. Persist only a
        // deterministic lineage sample so short common motifs do not turn the
        // API artifact into tens of megabytes.
        let occurrence_count_total = compact_occurrence_lineage(&mut motif, 300);
        let occurrence_rows_persisted = motif.occurrences.len();
        candidates.push(PatternFactoryCandidate {
            motif,
            occurrence_count_total,
            occurrence_rows_persisted,
            occurrence_persistence_status: if occurrence_rows_persisted < occurrence_count_total {
                "DETERMINISTIC_EVEN_LINEAGE_SAMPLE_AGGREGATES_USE_FULL_RUN".into()
            } else {
                "FULL_LINEAGE_PERSISTED".into()
            },
            raw_permutation_p_value: raw_p_values[index],
            fdr_adjusted_p_value: q_value,
            fdr_passed,
            strategy,
            lifecycle_status,
            rejection_reasons,
        });
    }
    candidates.sort_by(|left, right| {
        left.fdr_adjusted_p_value
            .total_cmp(&right.fdr_adjusted_p_value)
            .then_with(|| left.motif.motif_id.cmp(&right.motif.motif_id))
    });
    Ok(AutonomousPatternReport {
        schema_version: PATTERN_FACTORY_SCHEMA_VERSION,
        generated_at: Utc::now(),
        symbol: series.symbol,
        evidence_available_as_of,
        partition_plan,
        search_method: "DETERMINISTIC_MULTI_PROJECTION_SEEDS_THEN_EXACT_NORMALIZED_DISTANCE".into(),
        windows_evaluated: motif_report.windows_evaluated,
        hypothesis_family_size: candidates.len(),
        fdr_survivors: candidates.iter().filter(|row| row.fdr_passed).count(),
        current_matches: candidates
            .iter()
            .filter(|row| row.strategy.current_match)
            .count(),
        candidates,
        promotion_ceiling:
            "FORWARD_SHADOW_ONLY_REPLAYED_OR_PREVIOUSLY_INSPECTED_HISTORY_CANNOT_PROMOTE".into(),
        warnings: motif_report
            .warnings
            .into_iter()
            .chain([
                "FEATURE_ENGINE_SIMPLE_RETURNS_ARE_CONVERTED_WITH_LN_1P_BEFORE_MOTIF_SEARCH".into(),
                "AUTOMATIC_SPLITS_ARE_RESEARCH_CONVENIENCE_NOT_A_NEW_UNTOUCHED_HOLDOUT".into(),
                "A DISCOVERED PATTERN IS NOT A CAUSAL LAW OR LIVE TRADING PERMISSION".into(),
            ])
            .collect(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{NaiveDate, TimeZone};

    fn state(day: usize, minute: usize, close: f64) -> MarketState {
        let date = NaiveDate::from_ymd_opt(2025, 1, 1)
            .unwrap()
            .checked_add_signed(Duration::days(day as i64))
            .unwrap();
        let timestamp = Utc.from_utc_datetime(&date.and_hms_opt(14, 30, 0).unwrap())
            + Duration::minutes(minute as i64);
        MarketState {
            timestamp,
            session_date: date,
            symbol: "SPY".into(),
            open: close,
            high: close * 1.0001,
            low: close * 0.9999,
            close,
            atr: 0.1,
            ret_1m: [0.001, -0.0005, 0.0008, -0.0003, 0.0002, -0.0001][minute % 6],
            ret_3m: 0.0,
            ret_5m: 0.0,
            ret_15m: 0.0,
            ret_30m: 0.0,
            ret_60m: 0.0,
            active_5m_return: 0.0,
            last_completed_5m_return: 0.0,
            last_completed_15m_return: 0.0,
            slope_15m: 0.0,
            dist_vwap: 0.0,
            dist_session_open: 0.0,
            rolling_realized_vol: 0.01,
            normalized_range: 1.0,
            upper_wick_ratio: 0.0,
            lower_wick_ratio: 0.0,
            close_location_value: 0.0,
            distance_session_high: 0.0,
            distance_session_low: 0.0,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 0,
            consecutive_down_bars: 0,
            return_acceleration: 0.0,
            volume_zscore: 0.0,
            volume_acceleration: 0.0,
            session_range_position: 0.5,
            cross_asset_breadth_score: 0.0,
            risk_rotation_score: 0.0,
            market_confirmation_score: 0.0,
            cross_asset_context_complete: false,
            cross_asset_context_coverage: 0.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0,
            minutes_from_open: minute as i32,
            minutes_to_close: 390 - minute as i32,
            bucket_5m: minute as i32 / 5,
            bucket_15m: minute as i32 / 15,
            minute_in_5m_bucket: minute as i32 % 5,
            completed_5m_bucket_valid: minute % 5 == 4,
            continuous_minute_count: minute + 1,
        }
    }

    #[test]
    fn runner_assigns_strategy_but_never_trade_permission() {
        let mut states = Vec::new();
        for day in 0..80 {
            for minute in 0..8 {
                states.push(state(
                    day,
                    minute,
                    100.0 + day as f64 + minute as f64 * 0.01,
                ));
            }
        }
        let config = PatternFactoryConfig {
            window_observations: vec![3],
            outcome_horizon_minutes: 1,
            maximum_normalized_distance: 0.08,
            maximum_candidates_per_window: 1,
            projection_count: 3,
            projection_neighbor_span: 2,
            permutation_resamples: 256,
            ..PatternFactoryConfig::default()
        };
        let report = run_autonomous_pattern_factory(&states, &config).unwrap();
        assert_eq!(
            report.promotion_ceiling,
            "FORWARD_SHADOW_ONLY_REPLAYED_OR_PREVIOUSLY_INSPECTED_HISTORY_CANNOT_PROMOTE"
        );
        assert!(report.candidates.iter().all(|row| {
            !row.strategy.paper_eligible
                && !row.strategy.trade_eligible
                && row.strategy.entry_rule.contains("NEXT_MINUTE_OPEN")
        }));
    }
}
