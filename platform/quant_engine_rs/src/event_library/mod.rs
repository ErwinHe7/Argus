use std::collections::{BTreeMap, BTreeSet};

use anyhow::{Result, bail};
use chrono::{DateTime, Datelike, Duration, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::domain::MarketState;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    OpeningGap,
    OpeningRangeBreakout,
    OpeningRangeFailure,
    AbnormalVolume,
    VolatilityExpansion,
    VolatilityCompression,
    VwapReclaim,
    VwapRejection,
    PriorDayHighBreak,
    PriorDayLowBreak,
    IntradayDrawdownThreshold,
    RapidSellOff,
    RapidRebound,
    PriceVolumeDivergence,
    RelativeStrengthDivergence,
    CrossAssetCorrelationBreakdown,
    RepeatedSameDirectionBars,
    FailedBreakout,
    LiquiditySpreadShock,
    PowerHourAcceleration,
    ClosingImbalanceProxy,
    Cpi,
    Ppi,
    Nfp,
    Fomc,
    Opex,
    MonthlyExpiration,
    QuarterlyExpiration,
    MonthEnd,
    QuarterEnd,
    EarlyClose,
    MajorEarnings,
    ScheduledTreasuryFed,
}

impl EventKind {
    pub fn is_scheduled(self) -> bool {
        matches!(
            self,
            Self::Cpi
                | Self::Ppi
                | Self::Nfp
                | Self::Fomc
                | Self::Opex
                | Self::MonthlyExpiration
                | Self::QuarterlyExpiration
                | Self::MonthEnd
                | Self::QuarterEnd
                | Self::EarlyClose
                | Self::MajorEarnings
                | Self::ScheduledTreasuryFed
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EventProvenance {
    pub source: String,
    pub source_record_id: String,
    pub calendar_version: Option<String>,
    pub source_published_at: DateTime<Utc>,
    pub source_available_at: DateTime<Utc>,
    pub content_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketEventRecord {
    pub event_id: String,
    pub event_kind: EventKind,
    pub symbol: String,
    pub event_start_time: DateTime<Utc>,
    pub detection_time: DateTime<Utc>,
    pub information_available_at: DateTime<Utc>,
    pub event_severity: f64,
    pub reference_price: f64,
    pub pre_event_snapshot_id: Option<String>,
    pub pre_event_state: BTreeMap<String, f64>,
    pub hmm_regime: Option<String>,
    pub liquidity_state: String,
    pub cross_asset_state: String,
    pub scheduled: bool,
    pub provenance: EventProvenance,
}

impl MarketEventRecord {
    pub fn validate(&self) -> Result<()> {
        if self.event_start_time > self.detection_time
            || self.information_available_at > self.detection_time
        {
            bail!("event information is not point-in-time available at detection");
        }
        if self.scheduled != self.event_kind.is_scheduled() {
            bail!("event scheduled flag disagrees with taxonomy");
        }
        if self.provenance.source.is_empty()
            || self.provenance.source_record_id.is_empty()
            || self.provenance.content_hash.is_empty()
        {
            bail!("event provenance is incomplete");
        }
        if self.provenance.source_available_at > self.information_available_at {
            bail!("source availability is later than event availability");
        }
        if self.provenance.source_published_at > self.provenance.source_available_at {
            bail!("event source cannot be available before it was published");
        }
        if self.provenance.source == "POINT_IN_TIME_MARKET_STATE_DETECTOR" {
            let earliest_bar_availability = self.event_start_time + Duration::minutes(1);
            if self.detection_time < earliest_bar_availability
                || self.information_available_at < earliest_bar_availability
                || self.provenance.source_available_at < earliest_bar_availability
            {
                bail!("aggregate 1m-bar event cannot be detected before the bar closes");
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReactionFeatures {
    pub event_surprise_normalized_by_recent_volatility: Option<f64>,
    pub first_1m_reaction: Option<f64>,
    pub first_3m_reaction: Option<f64>,
    pub first_5m_reaction: Option<f64>,
    pub reaction_volume: Option<f64>,
    pub reaction_breadth: Option<f64>,
    pub reaction_relative_strength: Option<f64>,
    pub follow_through_ratio: Option<f64>,
    pub reversal_ratio: Option<f64>,
    pub price_impact_per_unit_volume: Option<f64>,
    pub time_to_peak_reaction_minutes: Option<usize>,
    pub cross_asset_confirmation: Option<f64>,
    pub reaction_disagreement: Option<f64>,
    pub reaction_decay_rate: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EventHorizonResponse {
    pub horizon_minutes: usize,
    pub terminal_return: f64,
    pub maximum_favorable_excursion: f64,
    pub maximum_adverse_excursion: f64,
    pub recovery_time_minutes: Option<usize>,
    pub exceeded_contemporary_realized_range: bool,
    pub label_available_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EventResponseRecord {
    pub event: MarketEventRecord,
    pub reaction: ReactionFeatures,
    pub responses: Vec<EventHorizonResponse>,
    pub settled_through: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DistributionStats {
    pub mean: f64,
    pub median: f64,
    pub quantiles: BTreeMap<String, f64>,
    pub probability_up: f64,
    pub tail_probability: Option<f64>,
    pub tail_absolute_return_threshold: Option<f64>,
    pub tail_sample_size: usize,
    pub tail_probability_status: String,
    pub average_mfe: f64,
    pub average_mae: f64,
    pub sample_size: usize,
    pub effective_independent_sample_size: usize,
    pub block_bootstrap_mean_ci_95: Option<[f64; 2]>,
}

/// Tail probabilities require a threshold fixed before the evaluation sample.
/// A percentile estimated from the same response rows is not pre-registration.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PreRegisteredTailThreshold {
    pub absolute_return_threshold: f64,
    pub registered_at: DateTime<Utc>,
    pub evaluation_start: DateTime<Utc>,
    pub provenance_sha256: String,
}

impl PreRegisteredTailThreshold {
    fn validate(&self) -> Result<()> {
        if !self.absolute_return_threshold.is_finite()
            || self.absolute_return_threshold <= 0.0
            || self.registered_at > self.evaluation_start
            || self.provenance_sha256.len() != 64
            || !self
                .provenance_sha256
                .bytes()
                .all(|byte| byte.is_ascii_hexdigit())
        {
            bail!("tail threshold must be positive, pre-registered, and content-addressed");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ConditionalBreakdown {
    pub key: String,
    pub sample_size: usize,
    pub mean_return: f64,
    pub probability_up: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EventAtlasQueryResult {
    pub event_kind: EventKind,
    pub horizon_minutes: usize,
    pub distribution: DistributionStats,
    pub by_year: Vec<ConditionalBreakdown>,
    pub by_regime: Vec<ConditionalBreakdown>,
    pub by_time_bucket: Vec<ConditionalBreakdown>,
    pub stability_score: f64,
    pub recent_decay_score: f64,
    pub status: String,
    pub limitations: Vec<String>,
}

fn deterministic_id(parts: &[String]) -> String {
    let mut hash = Sha256::new();
    for part in parts {
        hash.update(part.as_bytes());
        hash.update([0]);
    }
    format!("evt_{:x}", hash.finalize())[..28].to_string()
}

fn aggregate_bar_available_at(state: &MarketState) -> DateTime<Utc> {
    state.timestamp + Duration::minutes(1)
}

fn endogenous_event(
    state: &MarketState,
    kind: EventKind,
    severity: f64,
    sequence: usize,
) -> MarketEventRecord {
    let source_record_id = format!(
        "{}:{}:{}:{sequence}",
        state.symbol,
        state.timestamp.to_rfc3339(),
        serde_json::to_string(&kind).unwrap_or_default()
    );
    let content_hash = format!("{:x}", Sha256::digest(source_record_id.as_bytes()));
    let mut pre_event_state = BTreeMap::new();
    pre_event_state.insert("ret_5m".into(), state.ret_5m);
    pre_event_state.insert("realized_volatility".into(), state.rolling_realized_vol);
    pre_event_state.insert("vwap_distance".into(), state.dist_vwap);
    pre_event_state.insert("rvol".into(), state.rvol_same_minute);
    pre_event_state.insert("breadth".into(), state.cross_asset_breadth_score);
    pre_event_state.insert(
        "minute_of_session".into(),
        f64::from(state.minutes_from_open),
    );
    pre_event_state.insert(
        "time_bucket_30m".into(),
        f64::from(state.minutes_from_open / 30),
    );
    let event_id = deterministic_id(&[
        state.symbol.clone(),
        state.timestamp.to_rfc3339(),
        format!("{kind:?}"),
        sequence.to_string(),
    ]);
    let available_at = aggregate_bar_available_at(state);
    MarketEventRecord {
        event_id,
        event_kind: kind,
        symbol: state.symbol.clone(),
        event_start_time: state.timestamp,
        detection_time: available_at,
        information_available_at: available_at,
        event_severity: severity.max(0.0),
        reference_price: state.close,
        pre_event_snapshot_id: None,
        pre_event_state,
        hmm_regime: None,
        liquidity_state: "SPREAD_STATE_UNAVAILABLE_FROM_AGGREGATE_BARS".into(),
        cross_asset_state: if state.market_confirmation_score < -0.5 {
            "DISAGREEMENT"
        } else if state.market_confirmation_score > 0.5 {
            "CONFIRMED"
        } else {
            "MIXED"
        }
        .into(),
        scheduled: false,
        provenance: EventProvenance {
            source: "POINT_IN_TIME_MARKET_STATE_DETECTOR".into(),
            source_record_id,
            calendar_version: None,
            source_published_at: available_at,
            source_available_at: available_at,
            content_hash,
        },
    }
}

fn push_event(
    output: &mut Vec<MarketEventRecord>,
    state: &MarketState,
    kind: EventKind,
    severity: f64,
) {
    let sequence = output.len();
    output.push(endogenous_event(state, kind, severity, sequence));
}

fn group_states_by_symbol<'a>(
    states: &'a [MarketState],
) -> Result<BTreeMap<&'a str, Vec<&'a MarketState>>> {
    let mut grouped = BTreeMap::<&'a str, Vec<&'a MarketState>>::new();
    for state in states {
        if state.symbol.trim().is_empty() {
            bail!("market state symbol cannot be empty");
        }
        if !(0..390).contains(&state.minutes_from_open) {
            bail!("market state minute_of_session must be in 0..390");
        }
        let series = grouped.entry(state.symbol.as_str()).or_default();
        if let Some(previous) = series.last() {
            if state.timestamp <= previous.timestamp {
                bail!(
                    "market states for {} must be strictly increasing by timestamp",
                    state.symbol
                );
            }
            if state.session_date < previous.session_date {
                bail!(
                    "market states for {} move backward by session date",
                    state.symbol
                );
            }
            if state.session_date == previous.session_date
                && state.minutes_from_open <= previous.minutes_from_open
            {
                bail!(
                    "market states for {} must advance minute_of_session within a session",
                    state.symbol
                );
            }
        }
        series.push(state);
    }
    Ok(grouped)
}

/// Detects only events derivable from observations at or before each state.
/// Calendar events are intentionally handled by `register_scheduled_event`.
pub fn detect_endogenous(states: &[MarketState]) -> Result<Vec<MarketEventRecord>> {
    let grouped = group_states_by_symbol(states)?;
    let mut output = Vec::new();
    for series in grouped.values() {
        output.extend(detect_symbol(series));
    }
    output.sort_by(|left, right| {
        left.detection_time
            .cmp(&right.detection_time)
            .then_with(|| left.symbol.cmp(&right.symbol))
            .then_with(|| left.event_kind.cmp(&right.event_kind))
            .then_with(|| left.event_id.cmp(&right.event_id))
    });
    for event in &output {
        event.validate()?;
    }
    Ok(output)
}

fn detect_symbol(states: &[&MarketState]) -> Vec<MarketEventRecord> {
    let mut output = Vec::new();
    let mut prior_session_close = None;
    let mut prior_session_high = None;
    let mut prior_session_low = None;
    let mut current_session: Option<NaiveDate> = None;
    let mut current_high = f64::NEG_INFINITY;
    let mut current_low = f64::INFINITY;
    let mut current_close = 0.0;
    for (index, state) in states.iter().copied().enumerate() {
        if current_session != Some(state.session_date) {
            if current_session.is_some() {
                prior_session_close = Some(current_close);
                prior_session_high = current_high.is_finite().then_some(current_high);
                prior_session_low = current_low.is_finite().then_some(current_low);
            }
            current_session = Some(state.session_date);
            current_high = state.high;
            current_low = state.low;
            if let Some(close) = prior_session_close {
                let gap = state.open / close - 1.0;
                if gap.abs() >= 0.0025 {
                    push_event(&mut output, state, EventKind::OpeningGap, gap.abs());
                }
            }
        }
        let previous = index
            .checked_sub(1)
            .and_then(|idx| states.get(idx))
            .copied()
            .filter(|row| row.session_date == state.session_date && row.symbol == state.symbol);
        if state.volume_zscore >= 2.0 || state.rvol_same_minute >= 2.0 {
            push_event(
                &mut output,
                state,
                EventKind::AbnormalVolume,
                state.volume_zscore.max(state.rvol_same_minute - 1.0),
            );
        }
        if let Some(previous) = previous {
            if state.rolling_realized_vol > previous.rolling_realized_vol * 1.5
                && state.rolling_realized_vol > 1.0e-6
            {
                push_event(
                    &mut output,
                    state,
                    EventKind::VolatilityExpansion,
                    state.rolling_realized_vol / previous.rolling_realized_vol.max(1.0e-9) - 1.0,
                );
            }
            if state.rolling_realized_vol < previous.rolling_realized_vol * 0.65
                && previous.rolling_realized_vol > 1.0e-6
            {
                push_event(
                    &mut output,
                    state,
                    EventKind::VolatilityCompression,
                    1.0 - state.rolling_realized_vol / previous.rolling_realized_vol,
                );
            }
            if previous.dist_vwap <= 0.0 && state.dist_vwap > 0.0 {
                push_event(
                    &mut output,
                    state,
                    EventKind::VwapReclaim,
                    state.dist_vwap.abs(),
                );
            }
            if previous.dist_vwap >= 0.0 && state.dist_vwap < 0.0 {
                push_event(
                    &mut output,
                    state,
                    EventKind::VwapRejection,
                    state.dist_vwap.abs(),
                );
            }
        }
        if prior_session_high.is_some_and(|level| state.high > level) {
            push_event(
                &mut output,
                state,
                EventKind::PriorDayHighBreak,
                prior_session_high
                    .map(|level| state.high / level - 1.0)
                    .unwrap_or_default(),
            );
            prior_session_high = None;
        }
        if prior_session_low.is_some_and(|level| state.low < level) {
            push_event(
                &mut output,
                state,
                EventKind::PriorDayLowBreak,
                prior_session_low
                    .map(|level| 1.0 - state.low / level)
                    .unwrap_or_default(),
            );
            prior_session_low = None;
        }
        if state.dist_session_open <= -0.01 {
            push_event(
                &mut output,
                state,
                EventKind::IntradayDrawdownThreshold,
                -state.dist_session_open,
            );
        }
        if state.ret_5m <= -0.005 {
            push_event(&mut output, state, EventKind::RapidSellOff, -state.ret_5m);
        } else if state.ret_5m >= 0.005 {
            push_event(&mut output, state, EventKind::RapidRebound, state.ret_5m);
        }
        if state.ret_5m.signum() * state.volume_acceleration.signum() < 0.0
            && state.volume_acceleration.abs() >= 0.5
        {
            push_event(
                &mut output,
                state,
                EventKind::PriceVolumeDivergence,
                state.volume_acceleration.abs(),
            );
        }
        if state.ret_5m.signum() * state.risk_rotation_score.signum() < 0.0
            && state.risk_rotation_score.abs() >= 0.001
        {
            push_event(
                &mut output,
                state,
                EventKind::RelativeStrengthDivergence,
                state.risk_rotation_score.abs(),
            );
        }
        if state.market_confirmation_score <= -0.5 {
            push_event(
                &mut output,
                state,
                EventKind::CrossAssetCorrelationBreakdown,
                -state.market_confirmation_score,
            );
        }
        if state.consecutive_up_bars >= 5 || state.consecutive_down_bars >= 5 {
            push_event(
                &mut output,
                state,
                EventKind::RepeatedSameDirectionBars,
                state.consecutive_up_bars.max(state.consecutive_down_bars) as f64 / 5.0,
            );
        }
        if state.failed_opening_breakout != 0.0 {
            push_event(
                &mut output,
                state,
                EventKind::FailedBreakout,
                state.failed_opening_breakout.abs(),
            );
            push_event(
                &mut output,
                state,
                EventKind::OpeningRangeFailure,
                state.failed_opening_breakout.abs(),
            );
        }
        if state.minutes_to_close <= 60 && state.return_acceleration.abs() >= 0.001 {
            push_event(
                &mut output,
                state,
                EventKind::PowerHourAcceleration,
                state.return_acceleration.abs(),
            );
        }
        if state.minutes_to_close <= 30 && state.closing_short_cover_score >= 2.0 {
            push_event(
                &mut output,
                state,
                EventKind::ClosingImbalanceProxy,
                state.closing_short_cover_score,
            );
        }
        current_high = current_high.max(state.high);
        current_low = current_low.min(state.low);
        current_close = state.close;
    }
    output
}

pub fn register_scheduled_event(event: MarketEventRecord) -> Result<MarketEventRecord> {
    event.validate()?;
    if !event.event_kind.is_scheduled() {
        bail!("scheduled-event registry accepts only calendar taxonomy entries");
    }
    if event.provenance.calendar_version.is_none() {
        bail!("scheduled events require a point-in-time calendar version");
    }
    Ok(event)
}

fn reaction_at(states: &[&MarketState], index: usize, reference: f64) -> Option<f64> {
    states.get(index).map(|state| state.close / reference - 1.0)
}

pub fn settle_responses(
    events: &[MarketEventRecord],
    states: &[MarketState],
    knowledge_as_of: DateTime<Utc>,
) -> Result<Vec<EventResponseRecord>> {
    let grouped = group_states_by_symbol(states)?;
    for event in events {
        event.validate()?;
    }
    let output = events
        .iter()
        .filter_map(|event| {
            if event.information_available_at > knowledge_as_of {
                return None;
            }
            let series = grouped.get(event.symbol.as_str())?;
            let index = series
                .binary_search_by_key(&event.event_start_time, |state| state.timestamp)
                .ok()?;
            let reference_state = series[index];
            let session = reference_state.session_date;
            let available_future = series[index + 1..]
                .iter()
                .copied()
                .take_while(|state| state.session_date == session)
                .take_while(|state| aggregate_bar_available_at(state) <= knowledge_as_of)
                .collect::<Vec<_>>();
            let mut responses = Vec::new();
            for horizon in [1_usize, 5, 15, 30, 60] {
                let Some(end) = available_future.get(horizon - 1) else {
                    continue;
                };
                let label_available_at = aggregate_bar_available_at(end);
                let window = &available_future[..horizon];
                let terminal = end.close / event.reference_price - 1.0;
                let mfe = window
                    .iter()
                    .map(|state| state.high / event.reference_price - 1.0)
                    .fold(f64::NEG_INFINITY, f64::max);
                let mae = -window
                    .iter()
                    .map(|state| state.low / event.reference_price - 1.0)
                    .fold(f64::INFINITY, f64::min)
                    .min(0.0);
                let initial_sign = reaction_at(&available_future, 0, event.reference_price)
                    .unwrap_or_default()
                    .signum();
                let recovery_time = window.iter().position(|state| {
                    let value = state.close / event.reference_price - 1.0;
                    initial_sign != 0.0 && value.signum() != initial_sign
                });
                responses.push(EventHorizonResponse {
                    horizon_minutes: horizon,
                    terminal_return: terminal,
                    maximum_favorable_excursion: mfe,
                    maximum_adverse_excursion: mae,
                    recovery_time_minutes: recovery_time.map(|value| value + 1),
                    exceeded_contemporary_realized_range: terminal.abs()
                        > reference_state.rolling_realized_vol * (horizon as f64).sqrt(),
                    label_available_at,
                });
            }
            if responses.is_empty() {
                return None;
            }
            let first_1 = reaction_at(&available_future, 0, event.reference_price);
            let first_3 = reaction_at(&available_future, 2, event.reference_price);
            let first_5 = reaction_at(&available_future, 4, event.reference_price);
            let peak = (available_future.len() >= 5)
                .then(|| {
                    available_future
                        .iter()
                        .take(5)
                        .enumerate()
                        .map(|(offset, state)| {
                            (
                                offset + 1,
                                (state.close / event.reference_price - 1.0).abs(),
                            )
                        })
                        .max_by(|left, right| left.1.total_cmp(&right.1))
                })
                .flatten();
            let follow_through = match (first_1, first_5) {
                (Some(first), Some(last)) if first.abs() > 1.0e-12 => Some(last / first),
                _ => None,
            };
            let reversal = match (first_1, first_5) {
                (Some(first), Some(last)) if first.abs() > 1.0e-12 => {
                    Some(((first - last) / first.abs()).max(0.0))
                }
                _ => None,
            };
            let reaction = ReactionFeatures {
                event_surprise_normalized_by_recent_volatility: (reference_state
                    .rolling_realized_vol
                    > 0.0)
                    .then_some(event.event_severity / reference_state.rolling_realized_vol),
                first_1m_reaction: first_1,
                first_3m_reaction: first_3,
                first_5m_reaction: first_5,
                reaction_volume: available_future.first().map(|state| state.rvol_same_minute),
                reaction_breadth: available_future
                    .first()
                    .map(|state| state.cross_asset_breadth_score),
                reaction_relative_strength: available_future
                    .first()
                    .map(|state| state.risk_rotation_score),
                follow_through_ratio: follow_through,
                reversal_ratio: reversal,
                price_impact_per_unit_volume: match (first_1, available_future.first()) {
                    (Some(value), Some(state)) if state.rvol_same_minute.abs() > 1.0e-12 => {
                        Some(value / state.rvol_same_minute)
                    }
                    _ => None,
                },
                time_to_peak_reaction_minutes: peak.map(|row| row.0),
                cross_asset_confirmation: available_future
                    .first()
                    .map(|state| state.market_confirmation_score),
                reaction_disagreement: available_future.first().map(|state| {
                    (state.ret_5m.signum() - state.risk_rotation_score.signum()).abs() / 2.0
                }),
                reaction_decay_rate: match (first_1, first_5) {
                    (Some(first), Some(last)) => Some((first.abs() - last.abs()) / 4.0),
                    _ => None,
                },
            };
            Some(EventResponseRecord {
                event: event.clone(),
                reaction,
                settled_through: responses
                    .iter()
                    .map(|row| row.label_available_at)
                    .max()
                    .unwrap_or(knowledge_as_of),
                responses,
            })
        })
        .collect();
    Ok(output)
}

fn quantile(values: &[f64], probability: f64) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(f64::total_cmp);
    let position = probability.clamp(0.0, 1.0) * (sorted.len() - 1) as f64;
    let left = position.floor() as usize;
    let right = position.ceil() as usize;
    sorted[left] * (right as f64 - position) + sorted[right] * (position - left as f64)
}

fn block_bootstrap_ci(day_returns: &BTreeMap<NaiveDate, Vec<f64>>) -> Option<[f64; 2]> {
    if day_returns.len() < 5 {
        return None;
    }
    let days = day_returns.values().collect::<Vec<_>>();
    let mut seed = 0x9e37_79b9_7f4a_7c15_u64;
    let mut means = Vec::with_capacity(512);
    for _ in 0..512 {
        let mut sum = 0.0;
        let mut count = 0;
        for _ in 0..days.len() {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let block = days[(seed as usize) % days.len()];
            sum += block.iter().sum::<f64>();
            count += block.len();
        }
        means.push(sum / count.max(1) as f64);
    }
    Some([quantile(&means, 0.025), quantile(&means, 0.975)])
}

fn breakdown<K: Ord + ToString>(rows: &[(K, f64)]) -> Vec<ConditionalBreakdown> {
    let mut grouped = BTreeMap::<String, Vec<f64>>::new();
    for (key, value) in rows {
        grouped.entry(key.to_string()).or_default().push(*value);
    }
    grouped
        .into_iter()
        .map(|(key, values)| ConditionalBreakdown {
            key,
            sample_size: values.len(),
            mean_return: values.iter().sum::<f64>() / values.len() as f64,
            probability_up: values.iter().filter(|value| **value > 0.0).count() as f64
                / values.len() as f64,
        })
        .collect()
}

pub fn query_atlas(
    records: &[EventResponseRecord],
    kind: EventKind,
    horizon_minutes: usize,
) -> EventAtlasQueryResult {
    query_atlas_with_tail_threshold(records, kind, horizon_minutes, None)
}

pub fn query_atlas_with_tail_threshold(
    records: &[EventResponseRecord],
    kind: EventKind,
    horizon_minutes: usize,
    tail_threshold: Option<&PreRegisteredTailThreshold>,
) -> EventAtlasQueryResult {
    let mut selected = records
        .iter()
        .filter(|record| record.event.event_kind == kind)
        .filter_map(|record| {
            record
                .responses
                .iter()
                .find(|response| response.horizon_minutes == horizon_minutes)
                .map(|response| (record, response))
        })
        .collect::<Vec<_>>();
    selected.sort_by(|left, right| {
        left.0
            .event
            .detection_time
            .cmp(&right.0.event.detection_time)
    });
    let returns = selected
        .iter()
        .map(|(_, response)| response.terminal_return)
        .collect::<Vec<_>>();
    let unique_days = selected
        .iter()
        .map(|(record, _)| record.event.detection_time.date_naive())
        .collect::<BTreeSet<_>>();
    let mut by_day = BTreeMap::<NaiveDate, Vec<f64>>::new();
    for (record, response) in &selected {
        by_day
            .entry(record.event.detection_time.date_naive())
            .or_default()
            .push(response.terminal_return);
    }
    let mean = returns.iter().sum::<f64>() / returns.len().max(1) as f64;
    let (tail_probability, tail_absolute_return_threshold, tail_sample_size, tail_status) =
        match tail_threshold {
            None => (
                None,
                None,
                0,
                "UNAVAILABLE_PRE_REGISTERED_TAIL_THRESHOLD_REQUIRED".to_string(),
            ),
            Some(threshold) if threshold.validate().is_err() => (
                None,
                None,
                0,
                "UNAVAILABLE_INVALID_PRE_REGISTERED_TAIL_THRESHOLD".to_string(),
            ),
            Some(threshold) => {
                let evaluation_returns = selected
                    .iter()
                    .filter(|(record, _)| record.event.detection_time >= threshold.evaluation_start)
                    .map(|(_, response)| response.terminal_return)
                    .collect::<Vec<_>>();
                let probability = (!evaluation_returns.is_empty()).then(|| {
                    evaluation_returns
                        .iter()
                        .filter(|value| value.abs() >= threshold.absolute_return_threshold)
                        .count() as f64
                        / evaluation_returns.len() as f64
                });
                (
                    probability,
                    Some(threshold.absolute_return_threshold),
                    evaluation_returns.len(),
                    if probability.is_some() {
                        "AVAILABLE_PRE_REGISTERED_ABSOLUTE_RETURN_THRESHOLD"
                    } else {
                        "UNAVAILABLE_NO_POST_REGISTRATION_EVALUATION_SAMPLE"
                    }
                    .to_string(),
                )
            }
        };
    let distribution = DistributionStats {
        mean,
        median: quantile(&returns, 0.50),
        quantiles: [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]
            .into_iter()
            .map(|probability| {
                (
                    format!("q{:02}", (probability * 100.0) as u8),
                    quantile(&returns, probability),
                )
            })
            .collect(),
        probability_up: returns.iter().filter(|value| **value > 0.0).count() as f64
            / returns.len().max(1) as f64,
        tail_probability,
        tail_absolute_return_threshold,
        tail_sample_size,
        tail_probability_status: tail_status.clone(),
        average_mfe: selected
            .iter()
            .map(|(_, response)| response.maximum_favorable_excursion)
            .sum::<f64>()
            / selected.len().max(1) as f64,
        average_mae: selected
            .iter()
            .map(|(_, response)| response.maximum_adverse_excursion)
            .sum::<f64>()
            / selected.len().max(1) as f64,
        sample_size: returns.len(),
        effective_independent_sample_size: unique_days.len(),
        block_bootstrap_mean_ci_95: block_bootstrap_ci(&by_day),
    };
    let by_year_rows = selected
        .iter()
        .map(|(record, response)| (record.event.detection_time.year(), response.terminal_return))
        .collect::<Vec<_>>();
    let by_regime_rows = selected
        .iter()
        .map(|(record, response)| {
            (
                record
                    .event
                    .hmm_regime
                    .as_deref()
                    .unwrap_or("REGIME_UNAVAILABLE"),
                response.terminal_return,
            )
        })
        .collect::<Vec<_>>();
    let by_bucket_rows = selected
        .iter()
        .map(|(record, response)| {
            let bucket = record
                .event
                .pre_event_state
                .get("time_bucket_30m")
                .copied()
                .filter(|value| value.is_finite() && *value >= 0.0)
                .map(|value| value as i32)
                .map(|bucket| {
                    let start = bucket * 30;
                    format!("minute_{start:03}_{:03}", start + 29)
                })
                .unwrap_or_else(|| "TIME_BUCKET_UNAVAILABLE".to_string());
            (bucket, response.terminal_return)
        })
        .collect::<Vec<_>>();
    let by_year = breakdown(&by_year_rows);
    let signs = by_year
        .iter()
        .filter(|row| row.sample_size >= 3)
        .map(|row| row.mean_return.signum())
        .collect::<Vec<_>>();
    let sign_stability = if signs.is_empty() {
        0.0
    } else {
        let positive = signs.iter().filter(|value| **value > 0.0).count();
        positive.max(signs.len() - positive) as f64 / signs.len() as f64
    };
    let split = selected.len() * 2 / 3;
    let old_mean = selected[..split]
        .iter()
        .map(|(_, response)| response.terminal_return)
        .sum::<f64>()
        / split.max(1) as f64;
    let recent_mean = selected[split..]
        .iter()
        .map(|(_, response)| response.terminal_return)
        .sum::<f64>()
        / (selected.len() - split).max(1) as f64;
    let recent_decay_score = if old_mean.abs() > 1.0e-12 {
        (1.0 - recent_mean.abs() / old_mean.abs()).clamp(-1.0, 1.0)
    } else {
        0.0
    };
    let mut limitations = vec![
        "event detection is point-in-time; response labels are attached only after label_available_at".into(),
        "aggregate bars do not provide executable spread or order-book state".into(),
        "calendar events require a versioned external point-in-time calendar".into(),
    ];
    if tail_probability.is_none() {
        limitations.push(format!("tail_probability:{tail_status}"));
    }
    EventAtlasQueryResult {
        event_kind: kind,
        horizon_minutes,
        distribution,
        by_year,
        by_regime: breakdown(&by_regime_rows),
        by_time_bucket: breakdown(&by_bucket_rows),
        stability_score: sign_stability * (1.0 - recent_decay_score.max(0.0)),
        recent_decay_score,
        status: if returns.len() < 20 || unique_days.len() < 10 {
            "INSUFFICIENT_INDEPENDENT_EVENT_SAMPLE"
        } else {
            "RESEARCH_DISTRIBUTION_NOT_TRADING_SIGNAL"
        }
        .to_string(),
        limitations,
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use chrono::{Duration, TimeZone, Utc};

    use super::{
        EventKind, EventProvenance, MarketEventRecord, PreRegisteredTailThreshold,
        aggregate_bar_available_at, detect_endogenous, query_atlas,
        query_atlas_with_tail_threshold, register_scheduled_event, settle_responses,
    };
    use crate::domain::MarketState;

    fn state(index: usize) -> MarketState {
        let timestamp =
            Utc.with_ymd_and_hms(2026, 7, 1, 13, 30, 0).unwrap() + Duration::minutes(index as i64);
        MarketState {
            timestamp,
            session_date: timestamp.date_naive(),
            symbol: "SPY".into(),
            open: 100.0 + index as f64,
            high: 100.5 + index as f64,
            low: 99.5 + index as f64,
            close: 100.0 + index as f64,
            atr: 1.0,
            ret_1m: 0.001,
            ret_3m: 0.002,
            ret_5m: if index == 5 { -0.01 } else { 0.003 },
            ret_15m: 0.0,
            ret_30m: 0.0,
            ret_60m: 0.0,
            active_5m_return: 0.0,
            last_completed_5m_return: 0.0,
            last_completed_15m_return: 0.0,
            slope_15m: 0.0,
            dist_vwap: if index < 3 { -0.001 } else { 0.001 },
            dist_session_open: 0.0,
            rolling_realized_vol: 0.002,
            normalized_range: 0.01,
            upper_wick_ratio: 0.2,
            lower_wick_ratio: 0.2,
            close_location_value: 0.0,
            distance_session_high: 0.0,
            distance_session_low: 0.0,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 0,
            consecutive_down_bars: 0,
            return_acceleration: 0.0,
            volume_zscore: if index == 2 { 3.0 } else { 0.0 },
            volume_acceleration: 0.0,
            session_range_position: 0.5,
            cross_asset_breadth_score: 0.0,
            risk_rotation_score: 0.0,
            market_confirmation_score: 0.0,
            cross_asset_context_complete: false,
            cross_asset_context_coverage: 0.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0,
            minutes_from_open: index as i32,
            minutes_to_close: 390 - index as i32,
            bucket_5m: index as i32 / 5,
            bucket_15m: index as i32 / 15,
            minute_in_5m_bucket: index as i32 % 5,
            completed_5m_bucket_valid: index % 5 == 4,
            continuous_minute_count: index + 1,
        }
    }

    #[test]
    fn event_detection_is_prefix_causal_and_labels_wait_for_availability() {
        let states = (0..80).map(state).collect::<Vec<_>>();
        let prefix = detect_endogenous(&states[..10]).unwrap();
        let full = detect_endogenous(&states).unwrap();
        assert!(prefix.iter().all(|event| {
            event.detection_time >= event.event_start_time + Duration::minutes(1)
                && event.information_available_at == event.detection_time
                && event.provenance.source_available_at == event.detection_time
        }));
        assert_eq!(
            prefix,
            full.into_iter()
                .filter(|row| row.detection_time <= aggregate_bar_available_at(&states[9]))
                .collect::<Vec<_>>()
        );

        let event = prefix
            .iter()
            .find(|event| event.event_kind == EventKind::AbnormalVolume)
            .unwrap()
            .clone();
        let early_cutoff = aggregate_bar_available_at(&states[4]);
        let early = settle_responses(std::slice::from_ref(&event), &states, early_cutoff).unwrap();
        assert_eq!(early.len(), 1);
        assert!(early[0].reaction.first_1m_reaction.is_some());
        assert!(early[0].reaction.first_3m_reaction.is_none());
        assert!(early[0].reaction.first_5m_reaction.is_none());
        assert!(early[0].reaction.follow_through_ratio.is_none());
        assert!(early[0].reaction.reversal_ratio.is_none());
        assert!(early[0].reaction.reaction_decay_rate.is_none());
        assert!(early[0].reaction.time_to_peak_reaction_minutes.is_none());
        assert!(early.iter().all(|row| {
            row.responses
                .iter()
                .all(|response| response.label_available_at <= early_cutoff)
        }));

        let three_bar_cutoff = aggregate_bar_available_at(&states[5]);
        let three_bar =
            settle_responses(std::slice::from_ref(&event), &states, three_bar_cutoff).unwrap();
        assert!(three_bar[0].reaction.first_3m_reaction.is_some());
        assert!(three_bar[0].reaction.first_5m_reaction.is_none());
        let settled = settle_responses(
            std::slice::from_ref(&event),
            &states,
            aggregate_bar_available_at(&states[79]),
        )
        .unwrap();
        assert!(!settled.is_empty());
        assert!(settled[0].reaction.first_5m_reaction.is_some());
        assert!(settled[0].reaction.time_to_peak_reaction_minutes.is_some());
        let without_threshold = query_atlas(&settled, EventKind::AbnormalVolume, 5);
        assert_eq!(without_threshold.distribution.tail_probability, None);
        assert_eq!(
            without_threshold.distribution.tail_probability_status,
            "UNAVAILABLE_PRE_REGISTERED_TAIL_THRESHOLD_REQUIRED"
        );
        let threshold = PreRegisteredTailThreshold {
            absolute_return_threshold: 0.03,
            registered_at: states[0].timestamp,
            evaluation_start: event.detection_time,
            provenance_sha256: "a".repeat(64),
        };
        let with_threshold = query_atlas_with_tail_threshold(
            &settled,
            EventKind::AbnormalVolume,
            5,
            Some(&threshold),
        );
        assert_eq!(with_threshold.distribution.tail_probability, Some(1.0));
        assert_eq!(with_threshold.distribution.tail_sample_size, 1);
    }

    fn observation(
        symbol: &str,
        timestamp: chrono::DateTime<Utc>,
        minute_of_session: i32,
        price: f64,
    ) -> MarketState {
        let mut row = state(minute_of_session as usize);
        row.symbol = symbol.into();
        row.timestamp = timestamp;
        row.session_date = timestamp.date_naive();
        row.minutes_from_open = minute_of_session;
        row.minutes_to_close = 390 - minute_of_session;
        row.bucket_5m = minute_of_session / 5;
        row.bucket_15m = minute_of_session / 15;
        row.minute_in_5m_bucket = minute_of_session % 5;
        row.open = price;
        row.high = price;
        row.low = price;
        row.close = price;
        row.ret_5m = 0.0;
        row.dist_vwap = 0.0;
        row.volume_zscore = 0.0;
        row.rvol_same_minute = 1.0;
        row
    }

    #[test]
    fn symbol_grouping_prevents_cross_asset_session_memory_and_rejects_time_reversal() {
        let first_day = Utc.with_ymd_and_hms(2026, 7, 1, 13, 30, 0).unwrap();
        let second_day = Utc.with_ymd_and_hms(2026, 7, 2, 13, 30, 0).unwrap();
        let interleaved = vec![
            observation("SPY", first_day, 0, 100.0),
            observation("QQQ", first_day, 0, 200.0),
            observation("SPY", second_day, 0, 100.0),
            observation("QQQ", second_day, 0, 220.0),
        ];
        let events = detect_endogenous(&interleaved).unwrap();
        let opening_gaps = events
            .iter()
            .filter(|event| event.event_kind == EventKind::OpeningGap)
            .collect::<Vec<_>>();
        assert_eq!(opening_gaps.len(), 1);
        assert_eq!(opening_gaps[0].symbol, "QQQ");

        let reversed = vec![
            observation("SPY", second_day, 0, 100.0),
            observation("SPY", first_day, 0, 100.0),
        ];
        assert!(detect_endogenous(&reversed).is_err());
    }

    #[test]
    fn interleaved_symbols_settle_independently_and_preserve_real_time_bucket() {
        let start = Utc.with_ymd_and_hms(2026, 7, 1, 14, 32, 0).unwrap();
        let mut interleaved = Vec::new();
        for offset in 0..=5 {
            let timestamp = start + Duration::minutes(i64::from(offset));
            let mut spy = observation("SPY", timestamp, 62 + offset, 100.0 + f64::from(offset));
            if offset == 0 {
                spy.volume_zscore = 3.0;
            }
            interleaved.push(spy);
            interleaved.push(observation("QQQ", timestamp, 62 + offset, 200.0));
        }
        let events = detect_endogenous(&interleaved).unwrap();
        let event = events
            .into_iter()
            .find(|event| event.symbol == "SPY" && event.event_kind == EventKind::AbnormalVolume)
            .unwrap();
        assert_eq!(event.pre_event_state.get("minute_of_session"), Some(&62.0));
        assert_eq!(event.pre_event_state.get("time_bucket_30m"), Some(&2.0));
        let settled =
            settle_responses(&[event], &interleaved, start + Duration::minutes(6)).unwrap();
        assert!(settled[0].reaction.first_5m_reaction.is_some());
        let atlas = query_atlas(&settled, EventKind::AbnormalVolume, 5);
        assert_eq!(atlas.by_time_bucket[0].key, "minute_060_089");
    }

    #[test]
    fn post_hoc_calendar_label_is_rejected() {
        let detection = Utc.with_ymd_and_hms(2026, 7, 1, 14, 0, 0).unwrap();
        let event = MarketEventRecord {
            event_id: "evt".into(),
            event_kind: EventKind::Cpi,
            symbol: "SPY".into(),
            event_start_time: detection,
            detection_time: detection,
            information_available_at: detection + Duration::minutes(1),
            event_severity: 1.0,
            reference_price: 100.0,
            pre_event_snapshot_id: None,
            pre_event_state: BTreeMap::new(),
            hmm_regime: None,
            liquidity_state: "unknown".into(),
            cross_asset_state: "unknown".into(),
            scheduled: true,
            provenance: EventProvenance {
                source: "calendar".into(),
                source_record_id: "cpi".into(),
                calendar_version: Some("v1".into()),
                source_published_at: detection,
                source_available_at: detection,
                content_hash: "hash".into(),
            },
        };
        assert!(register_scheduled_event(event).is_err());
    }
}
