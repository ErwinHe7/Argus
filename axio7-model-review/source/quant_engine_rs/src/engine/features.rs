use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    time::Instant,
};

use anyhow::{Result, bail};
use chrono::{DateTime, Duration, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;

use crate::{
    config::ResearchConfig,
    domain::{MarketBar, MarketState},
};

const BREADTH_SYMBOLS: [(&str, f64); 6] = [
    ("QQQ", 1.0),
    ("IWM", 1.0),
    ("HYG", 1.0),
    ("VXX", -1.0),
    ("TLT", -1.0),
    ("UUP", -1.0),
];
const RISK_ROTATION_SYMBOLS: [(&str, f64); 6] = BREADTH_SYMBOLS;

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

fn build_states_internal(
    bars: &[MarketBar],
    target: &str,
    _config: &ResearchConfig,
    mut cumulative_volume_history: HashMap<u32, Vec<f64>>,
) -> Result<Vec<MarketState>> {
    let mut by_symbol = HashMap::<String, Vec<&MarketBar>>::new();
    for bar in bars.iter().filter(|bar| bar.validate()) {
        by_symbol
            .entry(bar.symbol.to_uppercase())
            .or_default()
            .push(bar);
    }
    for rows in by_symbol.values_mut() {
        rows.sort_by_key(|bar| bar.timestamp);
    }
    let target_key = target.to_uppercase();
    let target_rows = by_symbol
        .get(&target_key)
        .ok_or_else(|| anyhow::anyhow!("target symbol {target} is absent"))?;
    if target_rows.len() < 20 {
        bail!("at least 20 target bars are required");
    }

    let mut context_ret5 = HashMap::<(String, i64), f64>::new();
    for (symbol, rows) in &by_symbol {
        if symbol == &target_key {
            continue;
        }
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

    let mut states = Vec::new();
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
            let cross_asset_context_count = BREADTH_SYMBOLS
                .iter()
                .filter(|(symbol, _)| {
                    context_ret5.contains_key(&((*symbol).to_string(), bar.timestamp.timestamp()))
                })
                .count();
            let breadth_values: Vec<f64> = BREADTH_SYMBOLS
                .iter()
                .map(|(symbol, polarity)| {
                    context_ret5
                        .get(&(symbol.to_string(), bar.timestamp.timestamp()))
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
                cross_asset_context_count as f64 / BREADTH_SYMBOLS.len() as f64;
            let cross_asset_context_complete = cross_asset_context_count == BREADTH_SYMBOLS.len();
            let breadth = if breadth_values.len() == BREADTH_SYMBOLS.len() {
                mean(&breadth_values)
            } else {
                0.0
            };
            let risk_rotation_values = RISK_ROTATION_SYMBOLS
                .iter()
                .map(|(symbol, polarity)| {
                    context_ret5
                        .get(&(symbol.to_string(), bar.timestamp.timestamp()))
                        .copied()
                        .map(|value| value * polarity)
                })
                .collect::<Option<Vec<_>>>()
                .unwrap_or_default();
            let risk_rotation = if risk_rotation_values.len() == RISK_ROTATION_SYMBOLS.len() {
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
            states.push(MarketState {
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
            });
        }
        for (minute, cumulative) in daily_cumulative {
            cumulative_volume_history
                .entry(minute)
                .or_default()
                .push(cumulative);
        }
    }
    states.sort_by_key(|state| state.timestamp);
    Ok(states)
}

pub fn build_states(
    bars: &[MarketBar],
    target: &str,
    config: &ResearchConfig,
) -> Result<Vec<MarketState>> {
    build_states_internal(bars, target, config, HashMap::new())
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ContextSymbolReadiness {
    pub symbol: String,
    pub latest_at_or_before_cutoff: Option<DateTime<Utc>>,
    pub skew_ms: Option<i64>,
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

fn canonical_symbol(symbol: &str) -> String {
    symbol.trim().trim_start_matches("US.").to_ascii_uppercase()
}

pub fn context_readiness_at_cutoff(
    bars: &[MarketBar],
    cutoff: DateTime<Utc>,
    required_symbols: &[String],
    max_skew_ms: i64,
    minimum_continuous_bars: usize,
) -> ContextReadiness {
    let required = required_symbols
        .iter()
        .map(|symbol| canonical_symbol(symbol))
        .collect::<BTreeSet<_>>();
    let mut rows = HashMap::<String, Vec<&MarketBar>>::new();
    for bar in bars
        .iter()
        .filter(|bar| bar.validate() && bar.timestamp <= cutoff)
    {
        let symbol = canonical_symbol(&bar.symbol);
        if required.contains(&symbol) {
            rows.entry(symbol).or_default().push(bar);
        }
    }
    let mut symbol_reports = Vec::new();
    let mut blockers = Vec::new();
    for symbol in required {
        let mut values = rows.remove(&symbol).unwrap_or_default();
        values.sort_by_key(|bar| bar.timestamp);
        let latest = values.last().copied();
        let mut reasons = Vec::new();
        let skew_ms = latest.map(|bar| {
            cutoff
                .signed_duration_since(bar.timestamp)
                .num_milliseconds()
        });
        if latest.is_none() {
            reasons.push("MISSING_AT_OR_BEFORE_CUTOFF".to_string());
        }
        if skew_ms.is_some_and(|skew| skew < 0 || skew > max_skew_ms) {
            reasons.push("STALE_OR_FUTURE_CONTEXT".to_string());
        }
        let mut continuous = usize::from(latest.is_some());
        for pair in values.windows(2).rev() {
            if pair[1].timestamp == pair[0].timestamp + Duration::minutes(1) {
                continuous += 1;
            } else {
                break;
            }
        }
        if continuous < minimum_continuous_bars {
            reasons.push(format!(
                "INSUFFICIENT_CONTIGUOUS_HISTORY:{continuous}/{minimum_continuous_bars}"
            ));
        }
        let ready = reasons.is_empty();
        if !ready {
            blockers.push(format!("{symbol}:{}", reasons.join("|")));
        }
        symbol_reports.push(ContextSymbolReadiness {
            symbol,
            latest_at_or_before_cutoff: latest.map(|bar| bar.timestamp),
            skew_ms,
            continuous_bars: continuous,
            ready,
            reasons,
        });
    }
    ContextReadiness {
        schema_version: "point_in_time_context_readiness.v1".to_string(),
        cutoff,
        max_skew_ms,
        minimum_continuous_bars,
        ready: blockers.is_empty(),
        symbols: symbol_reports,
        blockers,
    }
}

fn historical_cumulative_volume_profile(
    bars: &[MarketBar],
    target: &str,
) -> HashMap<u32, Vec<f64>> {
    let target = canonical_symbol(target);
    let mut sessions = BTreeMap::<NaiveDate, Vec<&MarketBar>>::new();
    for bar in bars
        .iter()
        .filter(|bar| bar.validate() && canonical_symbol(&bar.symbol) == target)
    {
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
    pub latest_state: Option<MarketState>,
}

/// Bounded live feature engine. Historical states and same-minute volume
/// profiles are built once. Each event only rebuilds the current regular
/// session (at most 390 bars per symbol), never the full history.
pub struct IncrementalFeatureEngine {
    target: String,
    research: ResearchConfig,
    required_context_symbols: Vec<String>,
    max_context_skew_ms: i64,
    historical_states: Vec<MarketState>,
    volume_profile: HashMap<u32, Vec<f64>>,
    combined_states: Vec<MarketState>,
    session_date: Option<NaiveDate>,
    session_bars: BTreeMap<(i64, String), MarketBar>,
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
        if max_context_skew_ms <= 0 {
            bail!("max_context_skew_ms must be positive");
        }
        let target = canonical_symbol(target);
        let historical_states = build_states(historical_bars, &target, research)?;
        let volume_profile = historical_cumulative_volume_profile(historical_bars, &target);
        Ok(Self {
            target,
            research: research.clone(),
            required_context_symbols,
            max_context_skew_ms,
            combined_states: historical_states.clone(),
            historical_states,
            volume_profile,
            session_date: None,
            session_bars: BTreeMap::new(),
            emitted_cutoffs: BTreeSet::new(),
        })
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
            self.emitted_cutoffs.clear();
            self.combined_states.truncate(self.historical_states.len());
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
                schema_version: "incremental_feature_update.v1".to_string(),
                cutoff: None,
                state_ready: false,
                reason: "TARGET_BAR_NOT_RECEIVED".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_states.len(),
                current_session_states_rebuilt: 0,
                context: None,
                latest_state: None,
            });
        };
        if self.emitted_cutoffs.contains(&cutoff.timestamp_millis()) {
            return Ok(IncrementalFeatureUpdate {
                schema_version: "incremental_feature_update.v1".to_string(),
                cutoff: Some(cutoff),
                state_ready: false,
                reason: "CUTOFF_ALREADY_EMITTED".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_states.len(),
                current_session_states_rebuilt: self
                    .combined_states
                    .len()
                    .saturating_sub(self.historical_states.len()),
                context: None,
                latest_state: None,
            });
        }
        let session_rows = self.session_bars.values().cloned().collect::<Vec<_>>();
        let context = context_readiness_at_cutoff(
            &session_rows,
            cutoff,
            &self.required_context_symbols,
            self.max_context_skew_ms,
            6,
        );
        if !context.ready {
            return Ok(IncrementalFeatureUpdate {
                schema_version: "incremental_feature_update.v1".to_string(),
                cutoff: Some(cutoff),
                state_ready: false,
                reason: "CONTEXT_NOT_READY_NO_FORECAST".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_states.len(),
                current_session_states_rebuilt: 0,
                context: Some(context),
                latest_state: None,
            });
        }
        let current_states = match build_states_internal(
            &session_rows,
            &self.target,
            &self.research,
            self.volume_profile.clone(),
        ) {
            Ok(states) => states,
            Err(error) => {
                return Ok(IncrementalFeatureUpdate {
                    schema_version: "incremental_feature_update.v1".to_string(),
                    cutoff: Some(cutoff),
                    state_ready: false,
                    reason: format!("SESSION_WARMUP_NO_FORECAST:{error}"),
                    compute_ms: started.elapsed().as_millis(),
                    historical_states_reused: self.historical_states.len(),
                    current_session_states_rebuilt: 0,
                    context: Some(context),
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
                schema_version: "incremental_feature_update.v1".to_string(),
                cutoff: Some(cutoff),
                state_ready: false,
                reason: "TARGET_STATE_NOT_BUILT".to_string(),
                compute_ms: started.elapsed().as_millis(),
                historical_states_reused: self.historical_states.len(),
                current_session_states_rebuilt: current_states.len(),
                context: Some(context),
                latest_state: None,
            });
        };
        self.combined_states.truncate(self.historical_states.len());
        self.combined_states.extend(current_states.iter().cloned());
        self.emitted_cutoffs.insert(cutoff.timestamp_millis());
        Ok(IncrementalFeatureUpdate {
            schema_version: "incremental_feature_update.v1".to_string(),
            cutoff: Some(cutoff),
            state_ready: true,
            reason: "READY".to_string(),
            compute_ms: started.elapsed().as_millis(),
            historical_states_reused: self.historical_states.len(),
            current_session_states_rebuilt: current_states.len(),
            context: Some(context),
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
        assert_eq!(ready.historical_states_reused, historical_count);
        assert!(ready.current_session_states_rebuilt <= 390);
        assert_eq!(
            engine.states().len(),
            historical_count + ready.current_session_states_rebuilt
        );
    }
}
