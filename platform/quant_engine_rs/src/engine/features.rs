use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    time::Instant,
};

use anyhow::{Result, bail};
use chrono::{DateTime, Duration, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;

use crate::{
    config::{
        CROSS_ASSET_FEATURE_SCHEMA_V2_CANDIDATE, CROSS_ASSET_FEATURE_SCHEMA_V3_LIQUID_CANDIDATE,
        ContextObservationPolicyConfig, CrossAssetFeatureSchemaConfig,
        OfflineFeatureTrainingContractConfig, ResearchConfig,
    },
    domain::{
        CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION, CausalMinuteObservation, MarketBar, MarketState,
        MinuteObservationState,
    },
};

fn ret(current: f64, previous: f64) -> f64 {
    if previous > 0.0 {
        current / previous - 1.0
    } else {
        0.0
    }
}

fn mean(values: &[f64]) -> f64 {
    if values.is_empty() {
        0.0
    } else {
        values.iter().sum::<f64>() / values.len() as f64
    }
}

fn std(values: &[f64]) -> f64 {
    if values.len() < 2 {
        return 0.0;
    }
    let m = mean(values);
    (values.iter().map(|x| (x - m).powi(2)).sum::<f64>() / (values.len() - 1) as f64).sqrt()
}

fn normalized_slope(values: &[f64]) -> f64 {
    if values.len() < 2 || *values.last().unwrap_or(&0.0) <= 0.0 {
        return 0.0;
    }
    let x_mean = (values.len() - 1) as f64 * 0.5;
    let y_mean = mean(values);
    let numerator = values
        .iter()
        .enumerate()
        .map(|(idx, value)| (idx as f64 - x_mean) * (value - y_mean))
        .sum::<f64>();
    let denominator = (0..values.len())
        .map(|idx| (idx as f64 - x_mean).powi(2))
        .sum::<f64>();
    if denominator > 0.0 {
        numerator / denominator / values[values.len() - 1]
    } else {
        0.0
    }
}

fn exact_bucket_return(
    rows: &[&MarketBar],
    minute_to_index: &HashMap<i32, usize>,
    start_minute: i32,
    end_minute: i32,
) -> f64 {
    let (Some(&start), Some(&end)) = (
        minute_to_index.get(&start_minute),
        minute_to_index.get(&end_minute),
    ) else {
        return 0.0;
    };
    if end < start
        || (end - start) as i32 != end_minute - start_minute
        || !rows[start..=end]
            .windows(2)
            .all(|pair| pair[1].timestamp == pair[0].timestamp + Duration::minutes(1))
    {
        return 0.0;
    }
    ret(rows[end].close, rows[start].open)
}

fn exact_lagged_close_return(
    rows: &[&MarketBar],
    minute_to_index: &HashMap<i32, usize>,
    current_minute: i32,
    lag_minutes: i32,
) -> f64 {
    let (Some(&start), Some(&end)) = (
        minute_to_index.get(&(current_minute - lag_minutes)),
        minute_to_index.get(&current_minute),
    ) else {
        return 0.0;
    };
    if end < start
        || (end - start) as i32 != lag_minutes
        || !rows[start..=end]
            .windows(2)
            .all(|pair| pair[1].timestamp == pair[0].timestamp + Duration::minutes(1))
    {
        return 0.0;
    }
    ret(rows[end].close, rows[start].close)
}

fn contiguous_tail_start(rows: &[&MarketBar], end: usize, maximum_lookback: usize) -> usize {
    let minimum = end.saturating_sub(maximum_lookback);
    let mut start = end;
    while start > minimum
        && rows[start].timestamp == rows[start - 1].timestamp + Duration::minutes(1)
    {
        start -= 1;
    }
    start
}

struct BuiltStates {
    states: Vec<MarketState>,
    excluded_incomplete_context_states: usize,
}

#[derive(Clone, Copy)]
struct StateBuildSemantics {
    observed_trade_bars_only: bool,
    require_complete_cross_asset_context: bool,
    include_target_cross_asset_member: bool,
}

impl StateBuildSemantics {
    const LEGACY_V1: Self = Self {
        observed_trade_bars_only: false,
        require_complete_cross_asset_context: false,
        include_target_cross_asset_member: false,
    };

    const NO_UUP_CANDIDATE: Self = Self {
        observed_trade_bars_only: true,
        require_complete_cross_asset_context: true,
        include_target_cross_asset_member: true,
    };
}

fn runtime_state_build_semantics(
    policy: &ContextObservationPolicyConfig,
    cross_asset_schema: &CrossAssetFeatureSchemaConfig,
) -> StateBuildSemantics {
    let candidate = matches!(
        cross_asset_schema.schema_version.as_str(),
        CROSS_ASSET_FEATURE_SCHEMA_V2_CANDIDATE | CROSS_ASSET_FEATURE_SCHEMA_V3_LIQUID_CANDIDATE
    );
    StateBuildSemantics {
        observed_trade_bars_only: candidate && !policy.causal_no_trade_materialization_enabled(),
        require_complete_cross_asset_context: candidate,
        include_target_cross_asset_member: candidate
            || policy.causal_no_trade_materialization_enabled(),
    }
}

fn build_states_internal(
    bars: &[MarketBar],
    target: &str,
    cross_asset_schema: &CrossAssetFeatureSchemaConfig,
    cumulative_volume_history: &mut HashMap<u32, Vec<f64>>,
    extend_volume_history: bool,
    semantics: StateBuildSemantics,
) -> Result<BuiltStates> {
    cross_asset_schema.validate()?;
    let breadth_symbols = cross_asset_schema
        .members
        .iter()
        .map(|member| (canonical_symbol(&member.symbol), member.polarity))
        .collect::<Vec<_>>();
    let target_key = target.to_uppercase();
    let mut by_symbol = HashMap::<String, Vec<&MarketBar>>::new();
    for bar in bars.iter().filter(|bar| {
        bar.validate() && (!semantics.observed_trade_bars_only || bar.is_observed_trade_bar())
    }) {
        let symbol = canonical_symbol_view(&bar.symbol);
        let selected = if symbol.eq_ignore_ascii_case(&target_key) {
            Some(target_key.as_str())
        } else {
            breadth_symbols.iter().find_map(|(required, _)| {
                symbol
                    .eq_ignore_ascii_case(required)
                    .then_some(required.as_str())
            })
        };
        let Some(selected) = selected else {
            continue;
        };
        if let Some(rows) = by_symbol.get_mut(selected) {
            rows.push(bar);
        } else {
            by_symbol.insert(selected.to_string(), vec![bar]);
        }
    }
    for rows in by_symbol.values_mut() {
        rows.sort_by_key(|bar| bar.timestamp);
    }
    let target_rows = by_symbol
        .get(&target_key)
        .ok_or_else(|| anyhow::anyhow!("target symbol {target} is absent"))?;
    if target_rows.len() < 20 {
        bail!("at least 20 target bars are required");
    }

    let mut context_ret5 = HashMap::<(String, i64), f64>::new();
    for (symbol, _) in &breadth_symbols {
        if symbol == &target_key && !semantics.include_target_cross_asset_member {
            continue;
        }
        let Some(rows) = by_symbol.get(symbol) else {
            continue;
        };
        for idx in 5..rows.len() {
            if rows[idx].timestamp.with_timezone(&New_York).date_naive()
                != rows[idx - 5]
                    .timestamp
                    .with_timezone(&New_York)
                    .date_naive()
                || !rows[idx - 5..=idx]
                    .windows(2)
                    .all(|pair| pair[1].timestamp == pair[0].timestamp + Duration::minutes(1))
            {
                continue;
            }
            context_ret5.insert(
                (symbol.clone(), rows[idx].timestamp.timestamp()),
                ret(rows[idx].close, rows[idx - 5].close),
            );
        }
    }

    let mut sessions = BTreeMap::<NaiveDate, Vec<&MarketBar>>::new();
    for bar in target_rows {
        let local = bar.timestamp.with_timezone(&New_York);
        let minute = local.hour() * 60 + local.minute();
        if (570..960).contains(&minute) {
            sessions.entry(local.date_naive()).or_default().push(*bar);
        }
    }

    let target_state_capacity = sessions.values().map(Vec::len).sum();
    let mut states = Vec::with_capacity(target_state_capacity);
    let mut excluded_incomplete_context_states = 0;
    for (session_date, rows) in sessions {
        let minute_to_index: HashMap<i32, usize> = rows
            .iter()
            .enumerate()
            .map(|(idx, bar)| {
                let local = bar.timestamp.with_timezone(&New_York);
                ((local.hour() * 60 + local.minute()) as i32 - 570, idx)
            })
            .collect();
        let mut cumulative_pv = 0.0;
        let mut cumulative_volume = 0.0;
        let session_open = rows[0].open;
        let mut session_high = rows[0].high;
        let mut session_low = rows[0].low;
        let mut opening_range_high = rows[0].high;
        let mut opening_range_low = rows[0].low;
        let mut consecutive_up = 0_i32;
        let mut consecutive_down = 0_i32;
        let mut previous_return = 0.0;
        let mut daily_cumulative = Vec::<(u32, f64)>::new();
        for (idx, bar) in rows.iter().enumerate() {
            let local = bar.timestamp.with_timezone(&New_York);
            let minute_clock = local.hour() * 60 + local.minute();
            let minutes_from_open = minute_clock as i32 - 570;
            let minutes_to_close = 960_i32 - minute_clock as i32;
            session_high = session_high.max(bar.high);
            session_low = session_low.min(bar.low);
            if idx < 15 {
                opening_range_high = opening_range_high.max(bar.high);
                opening_range_low = opening_range_low.min(bar.low);
            }
            cumulative_volume += bar.volume;
            cumulative_pv += bar.close * bar.volume;
            daily_cumulative.push((minute_clock, cumulative_volume));
            let computed_vwap = if cumulative_volume > 0.0 {
                cumulative_pv / cumulative_volume
            } else {
                bar.close
            };
            // Vendor aggregate `vw` is the VWAP of this one-minute bar, not
            // the point-in-time session VWAP used by the research features.
            // Always derive the latter from bars observed through `timestamp`.
            let vwap = computed_vwap;
            let r1 = exact_lagged_close_return(&rows, &minute_to_index, minutes_from_open, 1);
            if bar.close > bar.open {
                consecutive_up += 1;
                consecutive_down = 0;
            } else if bar.close < bar.open {
                consecutive_down += 1;
                consecutive_up = 0;
            } else {
                consecutive_up = 0;
                consecutive_down = 0;
            }
            let return_acceleration = r1 - previous_return;
            previous_return = r1;
            let r3 = exact_lagged_close_return(&rows, &minute_to_index, minutes_from_open, 3);
            let r5 = exact_lagged_close_return(&rows, &minute_to_index, minutes_from_open, 5);
            let r15 = exact_lagged_close_return(&rows, &minute_to_index, minutes_from_open, 15);
            let r30 = exact_lagged_close_return(&rows, &minute_to_index, minutes_from_open, 30);
            let r60 = exact_lagged_close_return(&rows, &minute_to_index, minutes_from_open, 60);
            let bucket_5m = minutes_from_open.div_euclid(5);
            let bucket_15m = minutes_from_open.div_euclid(15);
            let minute_in_5m_bucket = minutes_from_open.rem_euclid(5);
            let active_5m_return =
                exact_bucket_return(&rows, &minute_to_index, bucket_5m * 5, minutes_from_open);
            let completed_5m_bucket_valid = minute_in_5m_bucket == 4
                && (bucket_5m * 5..=minutes_from_open).all(|minute| {
                    minute_to_index.get(&minute).is_some_and(|row_index| {
                        let expected = rows[*row_index].timestamp
                            - Duration::minutes((minute - bucket_5m * 5) as i64);
                        minute_to_index
                            .get(&(bucket_5m * 5))
                            .is_some_and(|start_index| rows[*start_index].timestamp == expected)
                    })
                });
            let last_completed_5m_return = if bucket_5m > 0 {
                exact_bucket_return(
                    &rows,
                    &minute_to_index,
                    (bucket_5m - 1) * 5,
                    bucket_5m * 5 - 1,
                )
            } else {
                0.0
            };
            let last_completed_15m_return = if bucket_15m > 0 {
                exact_bucket_return(
                    &rows,
                    &minute_to_index,
                    (bucket_15m - 1) * 15,
                    bucket_15m * 15 - 1,
                )
            } else {
                0.0
            };
            let contiguous_start = contiguous_tail_start(&rows, idx, 60);
            let slope_start = contiguous_start.max(idx.saturating_sub(14));
            let slope_values: Vec<f64> = rows[slope_start..=idx].iter().map(|b| b.close).collect();
            let return_start = contiguous_start.max(idx.saturating_sub(15));
            let return_window: Vec<f64> = (return_start..=idx)
                .filter(|i| *i > 0)
                .map(|i| ret(rows[i].close, rows[i - 1].close))
                .collect();
            let range_start = contiguous_start.max(idx.saturating_sub(13));
            let true_ranges: Vec<f64> = (range_start..=idx)
                .map(|i| rows[i].high - rows[i].low)
                .collect();
            let volume_start = contiguous_start.max(idx.saturating_sub(30));
            let volume_window: Vec<f64> =
                rows[volume_start..=idx].iter().map(|b| b.volume).collect();
            let volume_sd = std(&volume_window);
            let volume_zscore = if volume_sd > 0.0 {
                (bar.volume - mean(&volume_window)) / volume_sd
            } else {
                0.0
            };
            let previous_volume = if idx >= 1 {
                rows[idx - 1].volume
            } else {
                bar.volume
            };
            let volume_acceleration = if previous_volume > 0.0 {
                bar.volume / previous_volume - 1.0
            } else {
                0.0
            };
            let range = session_high - session_low;
            let session_range_position = if range > 0.0 {
                (bar.close - session_low) / range
            } else {
                0.5
            };
            let bar_range = (bar.high - bar.low).max(0.0);
            let normalized_range = bar_range / bar.close;
            let upper_wick_ratio = if bar_range > 0.0 {
                (bar.high - bar.open.max(bar.close)) / bar_range
            } else {
                0.0
            };
            let lower_wick_ratio = if bar_range > 0.0 {
                (bar.open.min(bar.close) - bar.low) / bar_range
            } else {
                0.0
            };
            let close_location_value = if bar_range > 0.0 {
                ((bar.close - bar.low) - (bar.high - bar.close)) / bar_range
            } else {
                0.0
            };
            let failed_opening_breakout =
                if idx >= 15 && bar.high > opening_range_high && bar.close < opening_range_high {
                    -1.0
                } else if idx >= 15 && bar.low < opening_range_low && bar.close > opening_range_low
                {
                    1.0
                } else {
                    0.0
                };
            // Missing cross-asset inputs are not averaged away. All members
            // must exist at this exact point-in-time cutoff; the live runtime
            // additionally blocks inference with an explicit readiness report.
            let cross_asset_context_count = breadth_symbols
                .iter()
                .filter(|(symbol, _)| {
                    context_ret5.contains_key(&(symbol.clone(), bar.timestamp.timestamp()))
                })
                .count();
            let breadth_values: Vec<f64> = breadth_symbols
                .iter()
                .map(|(symbol, polarity)| {
                    context_ret5
                        .get(&(symbol.clone(), bar.timestamp.timestamp()))
                        .copied()
                        .map(|value| value * polarity)
                })
                .collect::<Option<Vec<_>>>()
                .map(|values| {
                    values
                        .into_iter()
                        .map(|value| {
                            if value > 0.0 {
                                1.0
                            } else if value < 0.0 {
                                -1.0
                            } else {
                                0.0
                            }
                        })
                        .collect()
                })
                .unwrap_or_default();
            let cross_asset_context_coverage =
                cross_asset_context_count as f64 / breadth_symbols.len() as f64;
            let cross_asset_context_complete = cross_asset_context_count == breadth_symbols.len();
            let breadth = if breadth_values.len() == breadth_symbols.len() {
                mean(&breadth_values)
            } else {
                0.0
            };
            let risk_rotation_values = breadth_symbols
                .iter()
                .map(|(symbol, polarity)| {
                    context_ret5
                        .get(&(symbol.clone(), bar.timestamp.timestamp()))
                        .copied()
                        .map(|value| value * polarity)
                })
                .collect::<Option<Vec<_>>>()
                .unwrap_or_default();
            let risk_rotation = if risk_rotation_values.len() == breadth_symbols.len() {
                mean(&risk_rotation_values)
            } else {
                0.0
            };
            let confirmation = if r5 == 0.0 {
                0.0
            } else {
                breadth * r5.signum()
            };
            let prior_same_minute = cumulative_volume_history
                .get(&minute_clock)
                .map(Vec::as_slice)
                .unwrap_or(&[]);
            let rvol = if !prior_same_minute.is_empty() && mean(prior_same_minute) > 0.0 {
                cumulative_volume / mean(prior_same_minute)
            } else {
                1.0
            };
            let closing_short_cover_score = if minutes_to_close <= 30 {
                (r5.max(0.0) * 1000.0
                    + r15.max(0.0) * 500.0
                    + volume_zscore.max(0.0)
                    + volume_acceleration.max(0.0)
                    + (session_range_position - 0.5).max(0.0) * 2.0
                    + breadth.max(0.0)
                    + (rvol - 1.0).max(0.0))
                .max(0.0)
            } else {
                0.0
            };
            let state = MarketState {
                timestamp: bar.timestamp,
                session_date,
                symbol: target_key.clone(),
                open: bar.open,
                high: bar.high,
                low: bar.low,
                close: bar.close,
                atr: mean(&true_ranges),
                ret_1m: r1,
                ret_3m: r3,
                ret_5m: r5,
                ret_15m: r15,
                ret_30m: r30,
                ret_60m: r60,
                active_5m_return,
                last_completed_5m_return,
                last_completed_15m_return,
                slope_15m: normalized_slope(&slope_values),
                dist_vwap: ret(bar.close, vwap),
                dist_session_open: ret(bar.close, session_open),
                rolling_realized_vol: std(&return_window),
                normalized_range,
                upper_wick_ratio,
                lower_wick_ratio,
                close_location_value,
                distance_session_high: ret(bar.close, session_high),
                distance_session_low: ret(bar.close, session_low),
                failed_opening_breakout,
                consecutive_up_bars: consecutive_up,
                consecutive_down_bars: consecutive_down,
                return_acceleration,
                volume_zscore,
                volume_acceleration,
                session_range_position,
                cross_asset_breadth_score: breadth,
                risk_rotation_score: risk_rotation,
                market_confirmation_score: confirmation,
                cross_asset_context_complete,
                cross_asset_context_coverage,
                closing_short_cover_score,
                rvol_same_minute: rvol,
                minutes_from_open,
                minutes_to_close,
                bucket_5m,
                bucket_15m,
                minute_in_5m_bucket,
                completed_5m_bucket_valid,
                continuous_minute_count: idx - contiguous_start + 1,
            };
            if semantics.require_complete_cross_asset_context && !state.cross_asset_context_complete
            {
                excluded_incomplete_context_states += 1;
            } else {
                states.push(state);
            }
        }
        if extend_volume_history {
            for (minute, cumulative) in daily_cumulative {
                cumulative_volume_history
                    .entry(minute)
                    .or_default()
                    .push(cumulative);
            }
        }
    }
    states.sort_by_key(|state| state.timestamp);
    Ok(BuiltStates {
        states,
        excluded_incomplete_context_states,
    })
}

pub fn build_states(
    bars: &[MarketBar],
    target: &str,
    _config: &ResearchConfig,
) -> Result<Vec<MarketState>> {
    let mut cumulative_volume_history = HashMap::new();
    Ok(build_states_internal(
        bars,
        target,
        &CrossAssetFeatureSchemaConfig::default(),
        &mut cumulative_volume_history,
        true,
        StateBuildSemantics::LEGACY_V1,
    )?
    .states)
}

#[derive(Debug, Clone)]
pub struct OfflineFeatureStateSet {
    states: Vec<MarketState>,
    contract: OfflineFeatureTrainingContractConfig,
    excluded_incomplete_context_states: usize,
}

impl OfflineFeatureStateSet {
    pub fn states(&self) -> &[MarketState] {
        &self.states
    }

    pub fn contract(&self) -> &OfflineFeatureTrainingContractConfig {
        &self.contract
    }

    pub fn excluded_incomplete_context_states(&self) -> usize {
        self.excluded_incomplete_context_states
    }

    #[cfg(test)]
    pub(crate) fn from_states_for_test(
        states: Vec<MarketState>,
        contract: OfflineFeatureTrainingContractConfig,
    ) -> Result<Self> {
        contract.validate()?;
        Ok(Self {
            states,
            contract,
            excluded_incomplete_context_states: 0,
        })
    }
}

/// Build an offline candidate state matrix under one exact, immutable feature
/// contract. Unlike the legacy research helper, this path accepts only real,
/// positive-volume observed trade bars. Causal-absence materializations are
/// live shadow evidence and can never enter offline candidate fitting.
pub fn build_states_for_offline_feature_contract(
    bars: &[MarketBar],
    target: &str,
    _config: &ResearchConfig,
    contract: &OfflineFeatureTrainingContractConfig,
) -> Result<OfflineFeatureStateSet> {
    contract.validate()?;
    let mut cumulative_volume_history = HashMap::new();
    let built = build_states_internal(
        bars,
        target,
        &contract.cross_asset_feature_schema,
        &mut cumulative_volume_history,
        true,
        StateBuildSemantics::NO_UUP_CANDIDATE,
    )?;
    Ok(OfflineFeatureStateSet {
        states: built.states,
        contract: contract.clone(),
        excluded_incomplete_context_states: built.excluded_incomplete_context_states,
    })
}

/// Build live/replay states under an exact observed-trade-only feature
/// contract. Quote-only runtimes cannot satisfy causal-absence semantics and
/// must fail closed instead of silently reverting to the default schema.
pub fn build_states_for_observed_feature_contract(
    bars: &[MarketBar],
    target: &str,
    _config: &ResearchConfig,
    policy: &ContextObservationPolicyConfig,
    cross_asset_schema: &CrossAssetFeatureSchemaConfig,
) -> Result<Vec<MarketState>> {
    policy.validate()?;
    cross_asset_schema.validate()?;
    if policy.causal_no_trade_materialization_enabled() {
        bail!("observed-bar feature builder cannot satisfy causal no-trade policy");
    }
    let mut cumulative_volume_history = HashMap::new();
    let semantics = if matches!(
        cross_asset_schema.schema_version.as_str(),
        CROSS_ASSET_FEATURE_SCHEMA_V2_CANDIDATE | CROSS_ASSET_FEATURE_SCHEMA_V3_LIQUID_CANDIDATE
    ) {
        StateBuildSemantics::NO_UUP_CANDIDATE
    } else {
        StateBuildSemantics::LEGACY_V1
    };
    Ok(build_states_internal(
        bars,
        target,
        cross_asset_schema,
        &mut cumulative_volume_history,
        true,
        semantics,
    )?
    .states)
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ContextSymbolReadiness {
    pub symbol: String,
    pub latest_at_or_before_cutoff: Option<DateTime<Utc>>,
    pub skew_ms: Option<i64>,
    #[serde(default)]
    pub expected_intervals: usize,
    #[serde(default)]
    pub observed_trade_intervals: usize,
    #[serde(default)]
    pub causally_inferred_no_trade_intervals: usize,
    #[serde(default)]
    pub unknown_missing_intervals: usize,
    pub continuous_bars: usize,
    pub ready: bool,
    pub reasons: Vec<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ContextReadiness {
    pub schema_version: String,
    pub cutoff: DateTime<Utc>,
    pub max_skew_ms: i64,
    pub minimum_continuous_bars: usize,
    pub ready: bool,
    pub symbols: Vec<ContextSymbolReadiness>,
    pub blockers: Vec<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ContextMinuteObservationDiagnostic {
    pub interval_start: DateTime<Utc>,
    pub interval_end: DateTime<Utc>,
    pub state: MinuteObservationState,
    pub evidence_available_at: Option<DateTime<Utc>>,
    pub evidence_source: Option<String>,
    pub evidence_reference: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub materialization: Option<CausalNoTradeMaterialization>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CausalNoTradeMaterialization {
    pub internal_only: bool,
    pub missingness_state: MinuteObservationState,
    pub last_sale_interval_start: DateTime<Utc>,
    pub last_sale_age_ms: i64,
    pub last_sale_price: f64,
    pub last_sale_source: String,
    pub proof_source: String,
    pub proof_reference: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ContextObservationSymbolReadiness {
    pub symbol: String,
    pub feature_consumed: bool,
    pub latest_observed_trade_bar_at_or_before_cutoff: Option<DateTime<Utc>>,
    #[serde(default)]
    pub latest_eligible_interval_at_or_before_cutoff: Option<DateTime<Utc>>,
    pub skew_ms: Option<i64>,
    pub expected_intervals: usize,
    pub observed_trade_intervals: usize,
    pub causally_inferred_no_trade_intervals: usize,
    pub unknown_missing_intervals: usize,
    pub continuous_observed_trade_intervals: usize,
    #[serde(default)]
    pub continuous_eligible_intervals: usize,
    pub ready: bool,
    pub reasons: Vec<String>,
    pub warnings: Vec<String>,
    pub observations: Vec<ContextMinuteObservationDiagnostic>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ContextObservationReadiness {
    pub schema_version: String,
    pub policy_schema_version: String,
    pub cutoff: DateTime<Utc>,
    pub max_skew_ms: i64,
    pub minimum_continuous_intervals: usize,
    pub eligible_states: Vec<MinuteObservationState>,
    pub ready: bool,
    pub symbols: Vec<ContextObservationSymbolReadiness>,
    pub blockers: Vec<String>,
    pub warnings: Vec<String>,
}

impl ContextObservationReadiness {
    fn legacy_projection(&self) -> ContextReadiness {
        ContextReadiness {
            schema_version: "point_in_time_context_readiness.v2".to_string(),
            cutoff: self.cutoff,
            max_skew_ms: self.max_skew_ms,
            minimum_continuous_bars: self.minimum_continuous_intervals,
            ready: self.ready,
            symbols: self
                .symbols
                .iter()
                .map(|symbol| ContextSymbolReadiness {
                    symbol: symbol.symbol.clone(),
                    latest_at_or_before_cutoff: symbol.latest_eligible_interval_at_or_before_cutoff,
                    skew_ms: symbol.skew_ms,
                    expected_intervals: symbol.expected_intervals,
                    observed_trade_intervals: symbol.observed_trade_intervals,
                    causally_inferred_no_trade_intervals: symbol
                        .causally_inferred_no_trade_intervals,
                    unknown_missing_intervals: symbol.unknown_missing_intervals,
                    continuous_bars: symbol.continuous_eligible_intervals,
                    ready: symbol.ready,
                    reasons: symbol.reasons.clone(),
                })
                .collect(),
            blockers: self.blockers.clone(),
        }
    }
}

fn canonical_symbol(symbol: &str) -> String {
    canonical_symbol_view(symbol).to_ascii_uppercase()
}

fn canonical_symbol_view(symbol: &str) -> &str {
    symbol.trim().trim_start_matches("US.")
}

pub fn context_observation_readiness_at_cutoff(
    bars: &[MarketBar],
    explicit_observations: &[CausalMinuteObservation],
    cutoff: DateTime<Utc>,
    required_symbols: &[String],
    max_skew_ms: i64,
    policy: &ContextObservationPolicyConfig,
) -> ContextObservationReadiness {
    context_observation_readiness_with_schema_at_cutoff(
        bars,
        explicit_observations,
        cutoff,
        required_symbols,
        max_skew_ms,
        policy,
        &CrossAssetFeatureSchemaConfig::default(),
    )
}

pub fn context_observation_readiness_with_schema_at_cutoff(
    bars: &[MarketBar],
    explicit_observations: &[CausalMinuteObservation],
    cutoff: DateTime<Utc>,
    required_symbols: &[String],
    max_skew_ms: i64,
    policy: &ContextObservationPolicyConfig,
    cross_asset_schema: &CrossAssetFeatureSchemaConfig,
) -> ContextObservationReadiness {
    let required = required_symbols
        .iter()
        .map(|symbol| canonical_symbol(symbol))
        .collect::<BTreeSet<_>>();
    let mut global_blockers = Vec::new();
    if policy.validate().is_err() {
        global_blockers.push("INVALID_CONTEXT_OBSERVATION_POLICY".to_string());
    }
    if cross_asset_schema.validate().is_err() {
        global_blockers.push("INVALID_CROSS_ASSET_FEATURE_SCHEMA".to_string());
    }
    if cutoff.second() != 0 || cutoff.nanosecond() != 0 {
        global_blockers.push("CUTOFF_NOT_EXCHANGE_MINUTE_ALIGNED".to_string());
    }
    if max_skew_ms <= 0 {
        global_blockers.push("INVALID_MAX_CONTEXT_SKEW".to_string());
    }

    let minimum_intervals = policy.minimum_continuous_intervals.max(1);
    let first_expected = cutoff - Duration::minutes(minimum_intervals.saturating_sub(1) as i64);
    let mut bars_by_interval = HashMap::<(String, i64), Vec<&MarketBar>>::new();
    let mut latest_observed = HashMap::<String, DateTime<Utc>>::new();
    for bar in bars.iter().filter(|bar| bar.timestamp <= cutoff) {
        let symbol = canonical_symbol(&bar.symbol);
        if !required.contains(&symbol) {
            continue;
        }
        bars_by_interval
            .entry((symbol.clone(), bar.timestamp.timestamp()))
            .or_default()
            .push(bar);
        if bar.is_observed_trade_bar() {
            latest_observed
                .entry(symbol)
                .and_modify(|latest| *latest = (*latest).max(bar.timestamp))
                .or_insert(bar.timestamp);
        }
    }
    let mut evidence_by_interval = HashMap::<(String, i64), Vec<&CausalMinuteObservation>>::new();
    for observation in explicit_observations
        .iter()
        .filter(|observation| observation.interval_start <= cutoff)
    {
        let symbol = canonical_symbol(&observation.symbol);
        if required.contains(&symbol) {
            evidence_by_interval
                .entry((symbol, observation.interval_start.timestamp()))
                .or_default()
                .push(observation);
        }
    }

    let mut symbol_reports = Vec::new();
    let mut blockers = global_blockers.clone();
    let mut warnings = Vec::new();
    for symbol in required {
        let latest_observed_trade = latest_observed.get(&symbol).copied();
        let feature_consumed = cross_asset_schema
            .members
            .iter()
            .any(|member| member.symbol.eq_ignore_ascii_case(&symbol));
        let mut symbol_warnings = Vec::new();
        if !feature_consumed {
            symbol_warnings
                .push("CONTEXT_SYMBOL_NOT_CONSUMED_BY_CROSS_ASSET_FEATURE_SCHEMA".to_string());
            warnings.push(format!(
                "{symbol}:CONTEXT_SYMBOL_NOT_CONSUMED_BY_CROSS_ASSET_FEATURE_SCHEMA"
            ));
        }

        let mut observations = Vec::with_capacity(minimum_intervals);
        let mut reasons = BTreeSet::new();
        for offset in 0..minimum_intervals {
            let interval_start = first_expected + Duration::minutes(offset as i64);
            let key = (symbol.clone(), interval_start.timestamp());
            let interval_bars = bars_by_interval.get(&key).map(Vec::as_slice).unwrap_or(&[]);
            let interval_evidence = evidence_by_interval
                .get(&key)
                .map(Vec::as_slice)
                .unwrap_or(&[]);
            let valid_evidence = interval_evidence
                .iter()
                .copied()
                .filter(|observation| observation.validate())
                .collect::<Vec<_>>();
            let has_causal_absence = valid_evidence.iter().any(|observation| {
                observation.state == MinuteObservationState::CausallyInferredNoTrade
            });

            let diagnostic = if interval_bars.len() > 1 {
                reasons.insert(format!(
                    "DUPLICATE_OBSERVED_TRADE_BAR:{}",
                    interval_start.to_rfc3339()
                ));
                ContextMinuteObservationDiagnostic {
                    interval_start,
                    interval_end: interval_start + Duration::minutes(1),
                    state: MinuteObservationState::UnknownMissing,
                    evidence_available_at: None,
                    evidence_source: None,
                    evidence_reference: None,
                    materialization: None,
                }
            } else if let Some(bar) = interval_bars.first() {
                if !bar.is_observed_trade_bar() {
                    reasons.insert(format!(
                        "INVALID_OR_ZERO_VOLUME_TRADE_BAR:{}",
                        interval_start.to_rfc3339()
                    ));
                    ContextMinuteObservationDiagnostic {
                        interval_start,
                        interval_end: interval_start + Duration::minutes(1),
                        state: MinuteObservationState::UnknownMissing,
                        evidence_available_at: None,
                        evidence_source: Some(bar.source.clone()),
                        evidence_reference: None,
                        materialization: None,
                    }
                } else if has_causal_absence {
                    reasons.insert(format!(
                        "CONFLICTING_TRADE_AND_CAUSAL_ABSENCE_EVIDENCE:{}",
                        interval_start.to_rfc3339()
                    ));
                    ContextMinuteObservationDiagnostic {
                        interval_start,
                        interval_end: interval_start + Duration::minutes(1),
                        state: MinuteObservationState::UnknownMissing,
                        evidence_available_at: None,
                        evidence_source: Some(bar.source.clone()),
                        evidence_reference: None,
                        materialization: None,
                    }
                } else {
                    ContextMinuteObservationDiagnostic {
                        interval_start,
                        interval_end: interval_start + Duration::minutes(1),
                        state: MinuteObservationState::ObservedTradeBar,
                        evidence_available_at: None,
                        evidence_source: Some(bar.source.clone()),
                        evidence_reference: None,
                        materialization: None,
                    }
                }
            } else if interval_evidence.len() != valid_evidence.len() {
                reasons.insert(format!(
                    "INVALID_EXPLICIT_INTERVAL_EVIDENCE:{}",
                    interval_start.to_rfc3339()
                ));
                ContextMinuteObservationDiagnostic {
                    interval_start,
                    interval_end: interval_start + Duration::minutes(1),
                    state: MinuteObservationState::UnknownMissing,
                    evidence_available_at: None,
                    evidence_source: None,
                    evidence_reference: None,
                    materialization: None,
                }
            } else if valid_evidence.len() > 1 {
                reasons.insert(format!(
                    "CONFLICTING_EXPLICIT_INTERVAL_EVIDENCE:{}",
                    interval_start.to_rfc3339()
                ));
                ContextMinuteObservationDiagnostic {
                    interval_start,
                    interval_end: interval_start + Duration::minutes(1),
                    state: MinuteObservationState::UnknownMissing,
                    evidence_available_at: None,
                    evidence_source: None,
                    evidence_reference: None,
                    materialization: None,
                }
            } else if let Some(observation) = valid_evidence.first() {
                ContextMinuteObservationDiagnostic {
                    interval_start,
                    interval_end: interval_start + Duration::minutes(1),
                    state: observation.state,
                    evidence_available_at: observation.evidence_available_at,
                    evidence_source: observation.evidence_source.clone(),
                    evidence_reference: observation.evidence_reference.clone(),
                    materialization: None,
                }
            } else {
                ContextMinuteObservationDiagnostic {
                    interval_start,
                    interval_end: interval_start + Duration::minutes(1),
                    state: MinuteObservationState::UnknownMissing,
                    evidence_available_at: None,
                    evidence_source: None,
                    evidence_reference: None,
                    materialization: None,
                }
            };
            observations.push(diagnostic);
        }

        if policy.causal_no_trade_materialization_enabled() {
            for observation in &mut observations {
                if observation.state != MinuteObservationState::CausallyInferredNoTrade {
                    continue;
                }
                let proof_source = observation.evidence_source.as_deref().unwrap_or_default();
                let proof_reference = observation
                    .evidence_reference
                    .as_deref()
                    .unwrap_or_default();
                if !proof_source.eq_ignore_ascii_case(
                    "Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH",
                ) {
                    reasons.insert(format!(
                        "CAUSALLY_INFERRED_NO_TRADE_SOURCE_INVALID:{}",
                        observation.interval_start.to_rfc3339()
                    ));
                    continue;
                }
                let last_sale = bars
                    .iter()
                    .filter(|bar| {
                        canonical_symbol(&bar.symbol) == symbol
                            && bar.is_observed_trade_bar()
                            && bar.timestamp < observation.interval_start
                            && bar.timestamp.with_timezone(&New_York).date_naive()
                                == observation
                                    .interval_start
                                    .with_timezone(&New_York)
                                    .date_naive()
                    })
                    .max_by_key(|bar| bar.timestamp);
                let Some(last_sale) = last_sale else {
                    reasons.insert(format!(
                        "CAUSALLY_INFERRED_NO_TRADE_LAST_SALE_UNAVAILABLE:{}",
                        observation.interval_start.to_rfc3339()
                    ));
                    continue;
                };
                observation.materialization = Some(CausalNoTradeMaterialization {
                    internal_only: true,
                    missingness_state: MinuteObservationState::CausallyInferredNoTrade,
                    last_sale_interval_start: last_sale.timestamp,
                    last_sale_age_ms: observation
                        .interval_start
                        .signed_duration_since(last_sale.timestamp)
                        .num_milliseconds(),
                    last_sale_price: last_sale.close,
                    last_sale_source: last_sale.source.clone(),
                    proof_source: proof_source.to_string(),
                    proof_reference: proof_reference.to_string(),
                });
            }
        }

        let observed_trade_intervals = observations
            .iter()
            .filter(|observation| observation.state == MinuteObservationState::ObservedTradeBar)
            .count();
        let causally_inferred_no_trade_intervals = observations
            .iter()
            .filter(|observation| {
                observation.state == MinuteObservationState::CausallyInferredNoTrade
            })
            .count();
        let unknown_missing_intervals = observations
            .iter()
            .filter(|observation| observation.state == MinuteObservationState::UnknownMissing)
            .count();
        let continuous_observed_trade_intervals = observations
            .iter()
            .rev()
            .take_while(|observation| observation.state == MinuteObservationState::ObservedTradeBar)
            .count();
        let continuous_eligible_intervals = observations
            .iter()
            .rev()
            .take_while(|observation| {
                observation.state == MinuteObservationState::ObservedTradeBar
                    || (observation.state == MinuteObservationState::CausallyInferredNoTrade
                        && observation.materialization.is_some()
                        && policy
                            .eligible_states
                            .contains(&MinuteObservationState::CausallyInferredNoTrade))
            })
            .count();
        let latest_eligible = observations
            .iter()
            .rev()
            .find(|observation| {
                observation.state == MinuteObservationState::ObservedTradeBar
                    || (observation.state == MinuteObservationState::CausallyInferredNoTrade
                        && observation.materialization.is_some()
                        && policy
                            .eligible_states
                            .contains(&MinuteObservationState::CausallyInferredNoTrade))
            })
            .map(|observation| observation.interval_start)
            .or(latest_observed_trade);
        let skew_ms = latest_eligible
            .map(|timestamp| cutoff.signed_duration_since(timestamp).num_milliseconds());

        if latest_eligible.is_none() {
            reasons.insert("MISSING_OBSERVED_TRADE_BAR_AT_OR_BEFORE_CUTOFF".to_string());
        }
        if skew_ms.is_some_and(|skew| skew < 0 || skew > max_skew_ms) {
            reasons.insert("STALE_OR_FUTURE_CONTEXT".to_string());
        }
        if causally_inferred_no_trade_intervals > 0
            && !policy.causal_no_trade_materialization_enabled()
        {
            reasons.insert(format!(
                "CAUSALLY_INFERRED_NO_TRADE_NOT_ELIGIBLE_FOR_FROZEN_FEATURE_SCHEMA:{causally_inferred_no_trade_intervals}"
            ));
        }
        if unknown_missing_intervals > 0 {
            reasons.insert(format!(
                "UNKNOWN_MISSING_INTERVALS:{unknown_missing_intervals}"
            ));
        }
        if continuous_eligible_intervals < minimum_intervals {
            if policy.causal_no_trade_materialization_enabled() {
                reasons.insert(format!(
                    "INSUFFICIENT_CONTIGUOUS_ELIGIBLE_CONTEXT_INTERVALS:{continuous_eligible_intervals}/{minimum_intervals}"
                ));
            } else {
                reasons.insert(format!(
                    "INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS:{continuous_observed_trade_intervals}/{minimum_intervals}"
                ));
            }
        }
        if observations.iter().any(|observation| {
            !policy.eligible_states.contains(&observation.state)
                || (observation.state == MinuteObservationState::CausallyInferredNoTrade
                    && observation.materialization.is_none())
        }) {
            reasons.insert("INELIGIBLE_CONTEXT_OBSERVATION_STATE".to_string());
        }

        let reasons = reasons.into_iter().collect::<Vec<_>>();
        // `required_context_symbols` may intentionally be a transport-level
        // superset (for example SOXX/USO or UUP during a no-UUP ablation).
        // Only members of this exact feature schema can block its inference.
        let ready = !feature_consumed || (global_blockers.is_empty() && reasons.is_empty());
        if feature_consumed && !ready {
            blockers.push(format!("{symbol}:{}", reasons.join("|")));
        }
        symbol_reports.push(ContextObservationSymbolReadiness {
            symbol,
            feature_consumed,
            latest_observed_trade_bar_at_or_before_cutoff: latest_observed_trade,
            latest_eligible_interval_at_or_before_cutoff: latest_eligible,
            skew_ms,
            expected_intervals: minimum_intervals,
            observed_trade_intervals,
            causally_inferred_no_trade_intervals,
            unknown_missing_intervals,
            continuous_observed_trade_intervals,
            continuous_eligible_intervals,
            ready,
            reasons,
            warnings: symbol_warnings,
            observations,
        });
    }

    ContextObservationReadiness {
        schema_version: "point_in_time_context_observation_readiness.v2".to_string(),
        policy_schema_version: policy.schema_version.clone(),
        cutoff,
        max_skew_ms,
        minimum_continuous_intervals: minimum_intervals,
        eligible_states: policy.eligible_states.clone(),
        ready: blockers.is_empty(),
        symbols: symbol_reports,
        blockers,
        warnings,
    }
}

fn materialize_causal_no_trade_context(
    readiness: &mut ContextObservationReadiness,
    target: &str,
    policy: &ContextObservationPolicyConfig,
) -> Vec<MarketBar> {
    if !policy.causal_no_trade_materialization_enabled() {
        return Vec::new();
    }
    let target = canonical_symbol(target);
    let mut materialized = Vec::new();
    for symbol in &mut readiness.symbols {
        for observation in &symbol.observations {
            if observation.state != MinuteObservationState::CausallyInferredNoTrade {
                continue;
            }
            if symbol.symbol == target {
                let reason = format!(
                    "TARGET_CAUSAL_ABSENCE_MATERIALIZATION_FORBIDDEN:{}",
                    observation.interval_start.to_rfc3339()
                );
                if !symbol.reasons.contains(&reason) {
                    symbol.reasons.push(reason);
                }
                symbol.ready = false;
                continue;
            }
            let Some(metadata) = observation.materialization.as_ref() else {
                continue;
            };
            materialized.push(MarketBar {
                timestamp: observation.interval_start,
                symbol: symbol.symbol.clone(),
                open: metadata.last_sale_price,
                high: metadata.last_sale_price,
                low: metadata.last_sale_price,
                close: metadata.last_sale_price,
                volume: 0.0,
                vwap: Some(metadata.last_sale_price),
                bid: None,
                ask: None,
                trade_count: Some(0),
                source: format!("AXIO7_INTERNAL_CONTEXT_ONLY/{}", metadata.proof_source),
                data_quality: format!(
                    "causally_inferred_no_trade_flat:last_sale_age_ms={}:last_sale_source={}",
                    metadata.last_sale_age_ms, metadata.last_sale_source
                ),
            });
        }
    }
    readiness.blockers = readiness
        .symbols
        .iter()
        .filter(|symbol| !symbol.ready)
        .map(|symbol| format!("{}:{}", symbol.symbol, symbol.reasons.join("|")))
        .collect();
    readiness.ready = readiness.blockers.is_empty();
    materialized
}

pub fn context_readiness_at_cutoff(
    bars: &[MarketBar],
    cutoff: DateTime<Utc>,
    required_symbols: &[String],
    max_skew_ms: i64,
    minimum_continuous_bars: usize,
) -> ContextReadiness {
    let policy = ContextObservationPolicyConfig {
        minimum_continuous_intervals: minimum_continuous_bars,
        ..ContextObservationPolicyConfig::default()
    };
    context_observation_readiness_at_cutoff(
        bars,
        &[],
        cutoff,
        required_symbols,
        max_skew_ms,
        &policy,
    )
    .legacy_projection()
}

fn historical_cumulative_volume_profile(
    bars: &[MarketBar],
    target: &str,
    observed_trade_bars_only: bool,
) -> HashMap<u32, Vec<f64>> {
    let target = canonical_symbol(target);
    let mut sessions = BTreeMap::<NaiveDate, Vec<&MarketBar>>::new();
    for bar in bars.iter().filter(|bar| {
        bar.validate()
            && (!observed_trade_bars_only || bar.is_observed_trade_bar())
            && canonical_symbol_view(&bar.symbol).eq_ignore_ascii_case(&target)
    }) {
        let local = bar.timestamp.with_timezone(&New_York);
        let minute = local.hour() * 60 + local.minute();
        if (570..960).contains(&minute) {
            sessions.entry(local.date_naive()).or_default().push(bar);
        }
    }
    let mut profile = HashMap::<u32, Vec<f64>>::new();
    for rows in sessions.values_mut() {
        rows.sort_by_key(|bar| bar.timestamp);
        let mut cumulative = 0.0;
        for bar in rows {
            cumulative += bar.volume;
            let local = bar.timestamp.with_timezone(&New_York);
            profile
                .entry(local.hour() * 60 + local.minute())
                .or_default()
                .push(cumulative);
        }
    }
    profile
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct IncrementalFeatureUpdate {
    pub schema_version: String,
    pub cutoff: Option<DateTime<Utc>>,
    pub state_ready: bool,
    pub reason: String,
    pub compute_ms: u128,
    pub historical_states_reused: usize,
    pub current_session_states_rebuilt: usize,
    pub context: Option<ContextReadiness>,
    pub context_observations: Option<ContextObservationReadiness>,
    pub latest_state: Option<MarketState>,
}

/// Bounded live feature engine. Historical states and same-minute volume
/// profiles are built once. Each event only rebuilds the current regular
/// session (at most 390 bars per symbol), never the full history.
pub struct IncrementalFeatureEngine {
    target: String,
    required_context_symbols: Vec<String>,
    max_context_skew_ms: i64,
    context_observation_policy: ContextObservationPolicyConfig,
    cross_asset_feature_schema: CrossAssetFeatureSchemaConfig,
    historical_state_count: usize,
    volume_profile: HashMap<u32, Vec<f64>>,
    combined_states: Vec<MarketState>,
    session_date: Option<NaiveDate>,
    session_bars: BTreeMap<(i64, String), MarketBar>,
    explicit_context_observations: BTreeMap<(i64, String), CausalMinuteObservation>,
    emitted_cutoffs: BTreeSet<i64>,
}

impl IncrementalFeatureEngine {
    pub fn new(
        historical_bars: &[MarketBar],
        target: &str,
        research: &ResearchConfig,
        required_context_symbols: Vec<String>,
        max_context_skew_ms: i64,
    ) -> Result<Self> {
        Self::new_with_context_policy(
            historical_bars,
            target,
            research,
            required_context_symbols,
            max_context_skew_ms,
            ContextObservationPolicyConfig::default(),
        )
    }

    pub fn new_with_context_policy(
        historical_bars: &[MarketBar],
        target: &str,
        research: &ResearchConfig,
        required_context_symbols: Vec<String>,
        max_context_skew_ms: i64,
        context_observation_policy: ContextObservationPolicyConfig,
    ) -> Result<Self> {
        Self::new_with_feature_contract(
            historical_bars,
            target,
            research,
            required_context_symbols,
            max_context_skew_ms,
            context_observation_policy,
            CrossAssetFeatureSchemaConfig::default(),
        )
    }

    pub fn new_with_feature_contract(
        historical_bars: &[MarketBar],
        target: &str,
        _research: &ResearchConfig,
        required_context_symbols: Vec<String>,
        max_context_skew_ms: i64,
        context_observation_policy: ContextObservationPolicyConfig,
        cross_asset_feature_schema: CrossAssetFeatureSchemaConfig,
    ) -> Result<Self> {
        if max_context_skew_ms <= 0 {
            bail!("max_context_skew_ms must be positive");
        }
        context_observation_policy.validate()?;
        cross_asset_feature_schema.validate()?;
        let target = canonical_symbol(target);
        let build_semantics =
            runtime_state_build_semantics(&context_observation_policy, &cross_asset_feature_schema);
        let historical_states = {
            let mut cumulative_volume_history = HashMap::new();
            build_states_internal(
                historical_bars,
                &target,
                &cross_asset_feature_schema,
                &mut cumulative_volume_history,
                true,
                build_semantics,
            )?
            .states
        };
        let historical_state_count = historical_states.len();
        let volume_profile = historical_cumulative_volume_profile(
            historical_bars,
            &target,
            build_semantics.observed_trade_bars_only,
        );
        Ok(Self {
            target,
            required_context_symbols,
            max_context_skew_ms,
            context_observation_policy,
            cross_asset_feature_schema,
            historical_state_count,
            combined_states: historical_states,
            volume_profile,
            session_date: None,
            session_bars: BTreeMap::new(),
            explicit_context_observations: BTreeMap::new(),
            emitted_cutoffs: BTreeSet::new(),
        })
    }

    /// Records explicit causal context evidence. V1 preserves it for
    /// diagnostics and fails closed. The separately versioned V2 policy may
    /// materialize an internal context-only flat observation after all gates.
    pub fn ingest_context_observation(
        &mut self,
        observation: CausalMinuteObservation,
    ) -> Result<()> {
        if !observation.validate() {
            bail!(
                "invalid {} evidence",
                CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION
            );
        }
        if observation.state == MinuteObservationState::ObservedTradeBar {
            bail!("observed_trade_bar evidence must include and ingest the original MarketBar");
        }
        let symbol = canonical_symbol(&observation.symbol);
        if !self
            .required_context_symbols
            .iter()
            .any(|required| canonical_symbol(required) == symbol)
        {
            bail!("context observation symbol {symbol} is not required by this feature engine");
        }
        let local = observation.interval_start.with_timezone(&New_York);
        let minute = local.hour() * 60 + local.minute();
        if !(570..960).contains(&minute) {
            bail!("context observation is outside the regular session");
        }
        let date = local.date_naive();
        if self.session_date != Some(date) {
            self.session_date = Some(date);
            self.session_bars.clear();
            self.explicit_context_observations.clear();
            self.emitted_cutoffs.clear();
            self.combined_states.truncate(self.historical_state_count);
        }
        let key = (observation.interval_start.timestamp_millis(), symbol);
        if let Some(existing) = self.explicit_context_observations.get(&key)
            && existing != &observation
        {
            bail!("conflicting context evidence for the same symbol and interval");
        }
        self.explicit_context_observations.insert(key, observation);
        Ok(())
    }

    pub fn ingest(&mut self, bar: MarketBar) -> Result<IncrementalFeatureUpdate> {
        let started = Instant::now();
        if !bar.validate() {
            bail!("incremental feature engine rejected invalid bar");
        }
        let local = bar.timestamp.with_timezone(&New_York);
        let date = local.date_naive();
        if self.session_date != Some(date) {
            self.session_date = Some(date);
            self.session_bars.clear();
            self.explicit_context_observations.clear();
            self.emitted_cutoffs.clear();
            self.combined_states.truncate(self.historical_state_count);
        }
        let symbol = canonical_symbol(&bar.symbol);
        self.session_bars
            .insert((bar.timestamp.timestamp_millis(), symbol), bar);
        let latest_target = self
            .session_bars
            .values()
            .filter(|row| canonical_symbol(&row.symbol) == self.target)
            .max_by_key(|row| row.timestamp)
            .map(|row| row.timestamp);
        let Some(cutoff) = latest_target else {
            return Ok(IncrementalFeatureUpdate {
                schema_version: "incremental_feature_update.v2".to_string(),
                cutoff: None,
                state_ready: false,
                reason: "TARGET_BAR_NOT_RECEIVED".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_state_count,
                current_session_states_rebuilt: 0,
                context: None,
                context_observations: None,
                latest_state: None,
            });
        };
        if self.emitted_cutoffs.contains(&cutoff.timestamp_millis()) {
            return Ok(IncrementalFeatureUpdate {
                schema_version: "incremental_feature_update.v2".to_string(),
                cutoff: Some(cutoff),
                state_ready: false,
                reason: "CUTOFF_ALREADY_EMITTED".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_state_count,
                current_session_states_rebuilt: self
                    .combined_states
                    .len()
                    .saturating_sub(self.historical_state_count),
                context: None,
                context_observations: None,
                latest_state: None,
            });
        }
        let session_rows = self.session_bars.values().cloned().collect::<Vec<_>>();
        let explicit_observations = self
            .explicit_context_observations
            .values()
            .cloned()
            .collect::<Vec<_>>();
        let mut context_observations = context_observation_readiness_with_schema_at_cutoff(
            &session_rows,
            &explicit_observations,
            cutoff,
            &self.required_context_symbols,
            self.max_context_skew_ms,
            &self.context_observation_policy,
            &self.cross_asset_feature_schema,
        );
        let materialized_context = materialize_causal_no_trade_context(
            &mut context_observations,
            &self.target,
            &self.context_observation_policy,
        );
        let context = context_observations.legacy_projection();
        if !context.ready {
            return Ok(IncrementalFeatureUpdate {
                schema_version: "incremental_feature_update.v2".to_string(),
                cutoff: Some(cutoff),
                state_ready: false,
                reason: "CONTEXT_NOT_READY_NO_FORECAST".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_state_count,
                current_session_states_rebuilt: 0,
                context: Some(context),
                context_observations: Some(context_observations),
                latest_state: None,
            });
        }
        let mut feature_rows = session_rows;
        feature_rows.extend(materialized_context);
        let current_states = match build_states_internal(
            &feature_rows,
            &self.target,
            &self.cross_asset_feature_schema,
            &mut self.volume_profile,
            false,
            runtime_state_build_semantics(
                &self.context_observation_policy,
                &self.cross_asset_feature_schema,
            ),
        ) {
            Ok(built) => built.states,
            Err(error) => {
                return Ok(IncrementalFeatureUpdate {
                    schema_version: "incremental_feature_update.v2".to_string(),
                    cutoff: Some(cutoff),
                    state_ready: false,
                    reason: format!("SESSION_WARMUP_NO_FORECAST:{error}"),
                    compute_ms: started.elapsed().as_millis(),
                    historical_states_reused: self.historical_state_count,
                    current_session_states_rebuilt: 0,
                    context: Some(context),
                    context_observations: Some(context_observations),
                    latest_state: None,
                });
            }
        };
        let latest_state = current_states
            .iter()
            .find(|state| state.timestamp == cutoff)
            .cloned();
        let Some(latest_state) = latest_state else {
            return Ok(IncrementalFeatureUpdate {
                schema_version: "incremental_feature_update.v2".to_string(),
                cutoff: Some(cutoff),
                state_ready: false,
                reason: "TARGET_STATE_NOT_BUILT".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_state_count,
                current_session_states_rebuilt: current_states.len(),
                context: Some(context),
                context_observations: Some(context_observations),
                latest_state: None,
            });
        };
        self.combined_states.truncate(self.historical_state_count);
        self.combined_states.extend(current_states.iter().cloned());
        self.emitted_cutoffs.insert(cutoff.timestamp_millis());
        Ok(IncrementalFeatureUpdate {
            schema_version: "incremental_feature_update.v2".to_string(),
            cutoff: Some(cutoff),
            state_ready: true,
            reason: "READY".to_string(),
            compute_ms: started.elapsed().as_millis(),
            historical_states_reused: self.historical_state_count,
            current_session_states_rebuilt: current_states.len(),
            context: Some(context),
            context_observations: Some(context_observations),
            latest_state: Some(latest_state),
        })
    }

    pub fn states(&self) -> &[MarketState] {
        &self.combined_states
    }
}

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};

    use super::*;

    fn bar(minute_from_open: i64) -> MarketBar {
        let timestamp = Utc.with_ymd_and_hms(2026, 7, 22, 13, 30, 0).unwrap()
            + Duration::minutes(minute_from_open);
        let open = 500.0 + minute_from_open as f64 * 0.1;
        MarketBar {
            timestamp,
            symbol: "SPY".into(),
            open,
            high: open + 0.2,
            low: open - 0.2,
            close: open + 0.1,
            volume: 1_000.0,
            vwap: Some(open + 0.05),
            bid: None,
            ask: None,
            trade_count: Some(10),
            source: "TEST".into(),
            data_quality: "COMPLETE".into(),
        }
    }

    fn symbol_bar(symbol: &str, day: u32, minute_from_open: i64) -> MarketBar {
        let mut value = bar(minute_from_open);
        value.timestamp = Utc.with_ymd_and_hms(2026, 7, day, 13, 30, 0).unwrap()
            + Duration::minutes(minute_from_open);
        value.symbol = symbol.to_string();
        value
    }

    fn research_config() -> ResearchConfig {
        ResearchConfig {
            target: "SPY".into(),
            targets: Vec::new(),
            timezone: "America/New_York".into(),
            session_open: "09:30".into(),
            session_close: "16:00".into(),
            horizons: vec![5, 15, 30, 60],
            max_trades_per_day: 0,
            cooldown_minutes: 0,
            analog_neighbors: 10,
            analog_bandwidth: 1.0,
            validation_score_threshold: 0.0,
            stop_bps: 0.0,
            take_profit_bps: 0.0,
            max_holding_minutes: 60,
            underlying_slippage_bps: 0.0,
            commission_per_trade: 0.0,
            option_slippage: 0.0,
            option_max_spread_pct: 0.2,
            option_max_staleness_seconds: 60,
            regime: Default::default(),
        }
    }

    #[test]
    fn missing_minute_invalidates_clock_returns_and_completed_bucket() {
        let bars: Vec<_> = (0..25).filter(|minute| *minute != 22).map(bar).collect();
        let states = build_states(&bars, "SPY", &research_config()).unwrap();

        let complete = states
            .iter()
            .find(|state| state.minutes_from_open == 19)
            .unwrap();
        assert!(complete.completed_5m_bucket_valid);

        let gapped = states
            .iter()
            .find(|state| state.minutes_from_open == 24)
            .unwrap();
        assert!(!gapped.completed_5m_bucket_valid);
        assert_eq!(gapped.active_5m_return, 0.0);
        assert_eq!(gapped.ret_5m, 0.0);
        assert_eq!(gapped.continuous_minute_count, 2);
    }

    #[test]
    fn missing_cross_asset_member_is_explicitly_unavailable_not_observed_zero() {
        let mut incomplete = (0..25)
            .map(|minute| symbol_bar("SPY", 22, minute))
            .collect::<Vec<_>>();
        for symbol in ["QQQ", "IWM", "HYG", "TLT", "UUP"] {
            incomplete.extend((0..25).map(|minute| symbol_bar(symbol, 22, minute)));
        }
        let incomplete_states = build_states(&incomplete, "SPY", &research_config()).unwrap();
        let incomplete_latest = incomplete_states.last().unwrap();
        assert!(!incomplete_latest.cross_asset_context_complete);
        assert_eq!(incomplete_latest.cross_asset_context_coverage, 5.0 / 6.0);
        assert_eq!(incomplete_latest.cross_asset_breadth_score, 0.0);

        let mut complete = incomplete;
        complete.extend((0..25).map(|minute| symbol_bar("VXX", 22, minute)));
        let complete_states = build_states(&complete, "SPY", &research_config()).unwrap();
        let complete_latest = complete_states.last().unwrap();
        assert!(complete_latest.cross_asset_context_complete);
        assert_eq!(complete_latest.cross_asset_context_coverage, 1.0);
    }

    #[test]
    fn offline_no_uup_contract_builds_exact_observed_only_candidate_states() {
        let mut bars = (0..25)
            .map(|minute| symbol_bar("SPY", 22, minute))
            .collect::<Vec<_>>();
        for symbol in ["QQQ", "IWM", "HYG", "TLT", "VXX"] {
            bars.extend((0..25).map(|minute| symbol_bar(symbol, 22, minute)));
        }
        let contract = OfflineFeatureTrainingContractConfig::v2_no_uup_candidate();
        let candidate =
            build_states_for_offline_feature_contract(&bars, "SPY", &research_config(), &contract)
                .unwrap();
        assert!(
            candidate
                .states()
                .last()
                .unwrap()
                .cross_asset_context_complete
        );
        assert_eq!(
            candidate
                .states()
                .last()
                .unwrap()
                .cross_asset_context_coverage,
            1.0
        );

        let legacy = build_states(&bars, "SPY", &research_config()).unwrap();
        assert!(!legacy.last().unwrap().cross_asset_context_complete);
        assert_eq!(
            legacy.last().unwrap().cross_asset_context_coverage,
            5.0 / 6.0
        );

        bars.iter_mut()
            .find(|bar| bar.symbol == "QQQ" && bar.timestamp.minute() == 54)
            .unwrap()
            .volume = 0.0;
        let candidate_with_zero_volume =
            build_states_for_offline_feature_contract(&bars, "SPY", &research_config(), &contract)
                .unwrap();
        assert!(
            candidate_with_zero_volume
                .states()
                .iter()
                .all(|state| state.cross_asset_context_complete)
        );
        assert_eq!(
            candidate_with_zero_volume
                .states()
                .last()
                .unwrap()
                .minutes_from_open,
            23,
            "the target state at the missing exact context cutoff must be excluded"
        );
        assert_eq!(
            candidate_with_zero_volume.excluded_incomplete_context_states(),
            6
        );
        let legacy_with_zero_volume = build_states(&bars, "SPY", &research_config()).unwrap();
        assert_eq!(legacy_with_zero_volume.len(), 25);
        assert_eq!(
            legacy_with_zero_volume
                .last()
                .unwrap()
                .cross_asset_context_coverage,
            5.0 / 6.0,
            "unchanged v1 identity still counts the zero-volume QQQ row; only absent UUP is missing"
        );
        let live_engine = IncrementalFeatureEngine::new_with_feature_contract(
            &bars,
            "SPY",
            &research_config(),
            ["QQQ", "IWM", "HYG", "TLT", "VXX", "UUP"]
                .into_iter()
                .map(str::to_string)
                .collect(),
            5_000,
            contract.context_observation_policy.clone(),
            contract.cross_asset_feature_schema.clone(),
        )
        .unwrap();
        assert_eq!(
            live_engine.states(),
            candidate_with_zero_volume.states(),
            "offline candidate and live historical prefix must apply identical observed-bar semantics"
        );
    }

    #[test]
    fn qqq_self_member_fix_is_candidate_only_and_legacy_v1_is_unchanged() {
        let mut bars = Vec::new();
        for symbol in ["QQQ", "IWM", "HYG", "VXX", "TLT", "UUP"] {
            bars.extend((0..25).map(|minute| symbol_bar(symbol, 22, minute)));
        }
        let legacy = build_states(&bars, "QQQ", &research_config()).unwrap();
        assert!(!legacy.last().unwrap().cross_asset_context_complete);
        assert_eq!(
            legacy.last().unwrap().cross_asset_context_coverage,
            5.0 / 6.0
        );

        let contract = OfflineFeatureTrainingContractConfig::v2_no_uup_candidate();
        let candidate =
            build_states_for_offline_feature_contract(&bars, "QQQ", &research_config(), &contract)
                .unwrap();
        assert!(
            candidate
                .states()
                .last()
                .unwrap()
                .cross_asset_context_complete
        );
        assert_eq!(
            candidate
                .states()
                .last()
                .unwrap()
                .cross_asset_context_coverage,
            1.0
        );
    }

    #[test]
    fn context_readiness_requires_every_symbol_without_future_fill() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let mut bars = (0..=5)
            .map(|minute| symbol_bar("QQQ", 22, minute))
            .collect::<Vec<_>>();
        bars.extend((0..=4).map(|minute| symbol_bar("VXX", 22, minute)));
        let required = vec!["QQQ".to_string(), "VXX".to_string()];
        let report = context_readiness_at_cutoff(&bars, cutoff, &required, 5_000, 6);
        assert!(!report.ready);
        assert_eq!(report.blockers.len(), 1);
        assert!(report.blockers[0].contains("VXX"));

        bars.push(symbol_bar("VXX", 22, 5));
        assert!(context_readiness_at_cutoff(&bars, cutoff, &required, 5_000, 6).ready);
    }

    #[test]
    fn absent_context_minute_is_unknown_missing_not_a_zero_return() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let bars = (0..=4)
            .map(|minute| symbol_bar("UUP", 22, minute))
            .collect::<Vec<_>>();
        let report = context_observation_readiness_at_cutoff(
            &bars,
            &[],
            cutoff,
            &["UUP".to_string()],
            5_000,
            &ContextObservationPolicyConfig::default(),
        );
        let uup = &report.symbols[0];
        assert!(!report.ready);
        assert_eq!(uup.observed_trade_intervals, 5);
        assert_eq!(uup.causally_inferred_no_trade_intervals, 0);
        assert_eq!(uup.unknown_missing_intervals, 1);
        assert_eq!(
            uup.observations.last().unwrap().state,
            MinuteObservationState::UnknownMissing
        );
        assert!(
            uup.reasons
                .iter()
                .any(|reason| reason == "UNKNOWN_MISSING_INTERVALS:1")
        );
    }

    #[test]
    fn causal_no_trade_diagnostic_is_preserved_but_v1_does_not_materialize_it() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let bars = (0..=4)
            .map(|minute| symbol_bar("UUP", 22, minute))
            .collect::<Vec<_>>();
        let causal_absence = CausalMinuteObservation {
            schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
            symbol: "UUP".to_string(),
            interval_start: cutoff,
            interval_end: cutoff + Duration::minutes(1),
            state: MinuteObservationState::CausallyInferredNoTrade,
            evidence_available_at: Some(cutoff + Duration::minutes(1) + Duration::seconds(1)),
            evidence_source: Some("PROVIDER_SESSION_SUMMARY".to_string()),
            evidence_reference: Some("signed-proof-1".to_string()),
        };
        let report = context_observation_readiness_at_cutoff(
            &bars,
            &[causal_absence],
            cutoff,
            &["UUP".to_string()],
            5_000,
            &ContextObservationPolicyConfig::default(),
        );
        let uup = &report.symbols[0];
        assert!(!report.ready);
        assert_eq!(uup.causally_inferred_no_trade_intervals, 1);
        assert_eq!(uup.unknown_missing_intervals, 0);
        assert_eq!(uup.observed_trade_intervals, 5);
        assert!(uup.reasons.iter().any(|reason| {
            reason == "CAUSALLY_INFERRED_NO_TRADE_NOT_ELIGIBLE_FOR_FROZEN_FEATURE_SCHEMA:1"
        }));
    }

    #[test]
    fn v2_materializes_only_causal_databento_context_with_last_sale_metadata() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let bars = (0..=4)
            .map(|minute| symbol_bar("UUP", 22, minute))
            .collect::<Vec<_>>();
        let observation = CausalMinuteObservation {
            schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
            symbol: "UUP".to_string(),
            interval_start: cutoff,
            interval_end: cutoff + Duration::minutes(1),
            state: MinuteObservationState::CausallyInferredNoTrade,
            evidence_available_at: Some(cutoff + Duration::minutes(1) + Duration::seconds(2)),
            evidence_source: Some(
                "Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH".to_string(),
            ),
            evidence_reference: Some("continuous-health-eoi:UUP".to_string()),
        };
        let policy = ContextObservationPolicyConfig::v2_candidate();
        let mut report = context_observation_readiness_with_schema_at_cutoff(
            &bars,
            &[observation],
            cutoff,
            &["UUP".to_string()],
            5_000,
            &policy,
            &CrossAssetFeatureSchemaConfig::default(),
        );
        assert!(report.ready);
        assert_eq!(report.symbols[0].continuous_eligible_intervals, 6);
        let metadata = report.symbols[0]
            .observations
            .last()
            .unwrap()
            .materialization
            .as_ref()
            .unwrap();
        assert_eq!(
            metadata.missingness_state,
            MinuteObservationState::CausallyInferredNoTrade
        );
        assert_eq!(metadata.last_sale_age_ms, 60_000);

        let internal = materialize_causal_no_trade_context(&mut report, "SPY", &policy);
        assert_eq!(internal.len(), 1);
        assert_eq!(internal[0].volume, 0.0);
        assert_eq!(internal[0].trade_count, Some(0));
        assert!(
            internal[0]
                .source
                .starts_with("AXIO7_INTERNAL_CONTEXT_ONLY/")
        );

        let mut target_report = report;
        assert!(materialize_causal_no_trade_context(&mut target_report, "UUP", &policy).is_empty());
        assert!(!target_report.ready);
        assert!(target_report.symbols[0].reasons.iter().any(|reason| {
            reason.starts_with("TARGET_CAUSAL_ABSENCE_MATERIALIZATION_FORBIDDEN:")
        }));
    }

    #[test]
    fn v2_never_materializes_unknown_gap_or_absence_without_prior_sale() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let policy = ContextObservationPolicyConfig::v2_candidate();
        let missing = context_observation_readiness_with_schema_at_cutoff(
            &[],
            &[],
            cutoff,
            &["UUP".to_string()],
            5_000,
            &policy,
            &CrossAssetFeatureSchemaConfig::default(),
        );
        assert!(!missing.ready);
        assert_eq!(missing.symbols[0].unknown_missing_intervals, 6);

        let causal = CausalMinuteObservation {
            schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
            symbol: "UUP".to_string(),
            interval_start: cutoff,
            interval_end: cutoff + Duration::minutes(1),
            state: MinuteObservationState::CausallyInferredNoTrade,
            evidence_available_at: Some(cutoff + Duration::minutes(1) + Duration::seconds(2)),
            evidence_source: Some(
                "Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH".to_string(),
            ),
            evidence_reference: Some("continuous-health-eoi:UUP".to_string()),
        };
        let no_anchor = context_observation_readiness_with_schema_at_cutoff(
            &[],
            &[causal],
            cutoff,
            &["UUP".to_string()],
            5_000,
            &policy,
            &CrossAssetFeatureSchemaConfig::default(),
        );
        assert!(!no_anchor.ready);
        assert!(no_anchor.symbols[0].reasons.iter().any(|reason| {
            reason.starts_with("CAUSALLY_INFERRED_NO_TRADE_LAST_SALE_UNAVAILABLE:")
        }));
    }

    #[test]
    fn late_real_trade_conflicting_with_causal_absence_fails_closed() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let bars = (0..=5)
            .map(|minute| symbol_bar("UUP", 22, minute))
            .collect::<Vec<_>>();
        let causal = CausalMinuteObservation {
            schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
            symbol: "UUP".to_string(),
            interval_start: cutoff,
            interval_end: cutoff + Duration::minutes(1),
            state: MinuteObservationState::CausallyInferredNoTrade,
            evidence_available_at: Some(cutoff + Duration::minutes(1) + Duration::seconds(2)),
            evidence_source: Some(
                "Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH".to_string(),
            ),
            evidence_reference: Some("continuous-health-eoi:UUP".to_string()),
        };
        let report = context_observation_readiness_with_schema_at_cutoff(
            &bars,
            &[causal],
            cutoff,
            &["UUP".to_string()],
            5_000,
            &ContextObservationPolicyConfig::v2_candidate(),
            &CrossAssetFeatureSchemaConfig::default(),
        );
        assert!(!report.ready);
        assert_eq!(
            report.symbols[0].observations.last().unwrap().state,
            MinuteObservationState::UnknownMissing
        );
        assert!(report.symbols[0].reasons.iter().any(|reason| {
            reason.starts_with("CONFLICTING_TRADE_AND_CAUSAL_ABSENCE_EVIDENCE:")
        }));
    }

    #[test]
    fn duplicate_and_zero_volume_context_rows_fail_closed_with_exact_intervals() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let mut bars = (0..=5)
            .map(|minute| symbol_bar("QQQ", 22, minute))
            .collect::<Vec<_>>();
        bars.push(symbol_bar("QQQ", 22, 4));
        bars.last_mut().unwrap().volume = 0.0;
        let report = context_observation_readiness_at_cutoff(
            &bars,
            &[],
            cutoff,
            &["QQQ".to_string()],
            5_000,
            &ContextObservationPolicyConfig::default(),
        );
        assert!(!report.ready);
        assert!(report.symbols[0].reasons.iter().any(|reason| {
            reason.starts_with("DUPLICATE_OBSERVED_TRADE_BAR:2026-07-22T13:34:00")
        }));
    }

    #[test]
    fn unused_required_context_symbol_is_visible_as_a_non_blocking_warning() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let report = context_observation_readiness_at_cutoff(
            &[],
            &[],
            cutoff,
            &["SOXX".to_string()],
            5_000,
            &ContextObservationPolicyConfig::default(),
        );
        assert!(report.ready);
        assert!(!report.symbols[0].feature_consumed);
        assert_eq!(report.symbols[0].unknown_missing_intervals, 6);
        assert_eq!(
            report.symbols[0].warnings,
            ["CONTEXT_SYMBOL_NOT_CONSUMED_BY_CROSS_ASSET_FEATURE_SCHEMA"]
        );
    }

    #[test]
    fn no_uup_schema_does_not_gate_on_transport_superset_uup() {
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 22, 13, 35, 0).unwrap();
        let mut bars = Vec::new();
        for symbol in ["QQQ", "IWM", "HYG", "TLT", "VXX"] {
            bars.extend((0..=5).map(|minute| symbol_bar(symbol, 22, minute)));
        }
        let required = ["QQQ", "IWM", "HYG", "TLT", "VXX", "UUP"]
            .into_iter()
            .map(str::to_string)
            .collect::<Vec<_>>();
        let report = context_observation_readiness_with_schema_at_cutoff(
            &bars,
            &[],
            cutoff,
            &required,
            5_000,
            &ContextObservationPolicyConfig::default(),
            &CrossAssetFeatureSchemaConfig::v2_candidate_without_uup(),
        );
        assert!(report.ready);
        let uup = report
            .symbols
            .iter()
            .find(|symbol| symbol.symbol == "UUP")
            .unwrap();
        assert!(!uup.feature_consumed);
        assert!(uup.ready);
        assert_eq!(uup.unknown_missing_intervals, 6);
        assert!(report.blockers.is_empty());
    }

    #[test]
    fn incremental_engine_reuses_history_and_builds_only_current_session() {
        let mut historical = Vec::new();
        for day in 20..=21 {
            historical.extend((0..30).map(|minute| symbol_bar("SPY", day, minute)));
        }
        let mut engine = IncrementalFeatureEngine::new(
            &historical,
            "SPY",
            &research_config(),
            vec!["QQQ".to_string()],
            5_000,
        )
        .unwrap();
        let historical_count = engine.states().len();
        let mut ready = None;
        for minute in 0..25 {
            let target = engine.ingest(symbol_bar("SPY", 22, minute)).unwrap();
            assert!(!target.state_ready);
            let context = engine.ingest(symbol_bar("QQQ", 22, minute)).unwrap();
            if context.state_ready {
                ready = Some(context);
            }
        }
        let ready = ready.expect("current session should leave warm-up");
        assert_eq!(
            ready.latest_state.as_ref().map(|state| state.timestamp),
            ready.cutoff
        );
        assert!(
            ready
                .context_observations
                .as_ref()
                .is_some_and(|context| context.ready)
        );
        assert_eq!(ready.historical_states_reused, historical_count);
        assert!(ready.current_session_states_rebuilt <= 390);
        assert_eq!(
            engine.states().len(),
            historical_count + ready.current_session_states_rebuilt
        );
    }
}
