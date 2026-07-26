//! Deterministic, research-only natural-language query execution contracts.
//!
//! This module owns no language-model behavior. A caller may translate prose
//! into [`MarketQuery`], but only the allow-listed, versioned contract below is
//! executable. Market observations, statistics, gamma aggregation, freshness
//! checks, and hashes remain native Rust responsibilities.

use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{
    data::massive_live::{
        MassiveFullOptionChain, OPTION_CHAIN_SCHEMA_VERSION, RealtimeMarketBarEnvelope,
    },
    domain::{CallPut, MarketBar},
    engine::gamma_convexity::{
        GammaConvexityAvailability, GammaConvexityRequest, gamma_convexity_feedback_risk,
    },
    live::FinalizedLiveBar,
};

pub const MARKET_QUERY_SCHEMA_VERSION: &str = "axio.market-query.v1";
pub const EVIDENCE_ENVELOPE_SCHEMA_VERSION: &str = "axio.evidence-envelope.v1";
pub const OPENING_EXHAUSTION_METHOD_VERSION: &str = "opening-buy-exhaustion-5m.v1";
pub const VWAP_REVERSAL_METHOD_VERSION: &str = "causal-session-vwap-cross-5m.v1";
pub const GAMMA_STRUCTURE_METHOD_VERSION: &str = "unsigned-gamma-structure-score.v1";
pub const MOMENTUM_METHOD_VERSION: &str = "causal-multi-bar-momentum-5m.v1";

fn default_query_version() -> String {
    MARKET_QUERY_SCHEMA_VERSION.to_string()
}

fn default_horizon_minutes() -> usize {
    15
}

fn default_limit() -> usize {
    10
}

fn default_true() -> bool {
    true
}

fn default_max_data_age_seconds() -> i64 {
    120
}

fn default_max_dte() -> i32 {
    14
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MarketQueryIntent {
    Scan,
    Forecast,
    Backtest,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MarketSetupType {
    Momentum,
    GammaSqueeze,
    VwapReversal,
    OpeningTurn,
    ClosingShortCover,
    StatisticalDislocation,
}

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TurnDirection {
    #[default]
    Down,
    Up,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct MarketQueryFilters {
    #[serde(default)]
    pub direction: TurnDirection,
    #[serde(default = "default_true")]
    pub require_realtime: bool,
    #[serde(default = "default_true")]
    pub include_historical: bool,
    #[serde(default = "default_max_data_age_seconds")]
    pub max_data_age_seconds: i64,
    #[serde(default = "default_max_dte")]
    pub max_dte: i32,
    #[serde(default)]
    pub exclude_earnings_within_days: Option<u16>,
    #[serde(default)]
    pub maximum_option_spread_pct: Option<f64>,
    #[serde(default)]
    pub minimum_option_quote_coverage: Option<f64>,
}

impl Default for MarketQueryFilters {
    fn default() -> Self {
        Self {
            direction: TurnDirection::Down,
            require_realtime: true,
            include_historical: true,
            max_data_age_seconds: default_max_data_age_seconds(),
            max_dte: default_max_dte(),
            exclude_earnings_within_days: None,
            maximum_option_spread_pct: None,
            minimum_option_quote_coverage: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct MarketQuery {
    #[serde(default = "default_query_version")]
    pub version: String,
    pub intent: MarketQueryIntent,
    pub setup_type: MarketSetupType,
    pub symbols: Vec<String>,
    #[serde(default = "default_horizon_minutes")]
    pub horizon_minutes: usize,
    #[serde(default = "default_limit")]
    pub limit: usize,
    #[serde(default)]
    pub as_of: Option<DateTime<Utc>>,
    #[serde(default)]
    pub filters: MarketQueryFilters,
}

impl MarketQuery {
    pub fn normalize_and_validate(mut self) -> std::result::Result<Self, String> {
        if self.version != MARKET_QUERY_SCHEMA_VERSION {
            return Err(format!(
                "unsupported query version {}; expected {MARKET_QUERY_SCHEMA_VERSION}",
                self.version
            ));
        }
        if self.symbols.is_empty() || self.symbols.len() > 30 {
            return Err("symbols must contain between 1 and 30 values".to_string());
        }
        let mut symbols = BTreeSet::new();
        for raw in &self.symbols {
            let symbol = raw
                .trim()
                .trim_start_matches("US.")
                .trim_start_matches('$')
                .to_ascii_uppercase();
            if symbol.is_empty()
                || symbol.len() > 10
                || !symbol
                    .chars()
                    .all(|character| character.is_ascii_alphanumeric() || character == '.')
            {
                return Err(format!("invalid US market symbol: {raw}"));
            }
            symbols.insert(symbol);
        }
        self.symbols = symbols.into_iter().collect();
        if ![5, 15, 30, 60].contains(&self.horizon_minutes) {
            return Err("horizon_minutes must be one of 5, 15, 30, or 60".to_string());
        }
        if !(1..=20).contains(&self.limit) {
            return Err("limit must be between 1 and 20".to_string());
        }
        if !(1..=3_600).contains(&self.filters.max_data_age_seconds) {
            return Err("max_data_age_seconds must be between 1 and 3600".to_string());
        }
        if !(0..=60).contains(&self.filters.max_dte) {
            return Err("max_dte must be between 0 and 60".to_string());
        }
        if self
            .filters
            .maximum_option_spread_pct
            .is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value))
        {
            return Err("maximum_option_spread_pct must be finite and between 0 and 1".to_string());
        }
        if self
            .filters
            .minimum_option_quote_coverage
            .is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value))
        {
            return Err(
                "minimum_option_quote_coverage must be finite and between 0 and 1".to_string(),
            );
        }
        if self
            .as_of
            .is_some_and(|cutoff| cutoff > Utc::now() + chrono::Duration::seconds(5))
        {
            return Err("as_of cannot be in the future".to_string());
        }
        Ok(self)
    }

    pub fn canonical_sha256(&self) -> Result<String> {
        Ok(sha256_hex(&serde_json::to_vec(self)?))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvidenceItem {
    pub code: String,
    pub statement: String,
    pub observed_value: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DataFreshness {
    pub source: String,
    pub observed_at: Option<DateTime<Utc>>,
    pub available_at: Option<DateTime<Utc>>,
    pub age_seconds: Option<i64>,
    pub realtime: bool,
    pub entitlement: String,
    pub coverage: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResearchCandidate {
    pub symbol: String,
    pub setup_type: MarketSetupType,
    pub status: String,
    pub heuristic_structure_score: Option<f64>,
    pub score_semantics: String,
    pub supporting_evidence: Vec<EvidenceItem>,
    pub contrary_evidence: Vec<EvidenceItem>,
    pub metrics: Value,
    pub freshness: Vec<DataFreshness>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HistoricalSetupStats {
    pub symbol: String,
    pub setup_type: MarketSetupType,
    pub method_version: String,
    pub event_definition: String,
    pub source: String,
    pub dataset_start: Option<NaiveDate>,
    pub dataset_end: Option<NaiveDate>,
    pub sessions: usize,
    pub event_sessions: usize,
    pub event_rate: Option<f64>,
    pub event_bar_q25: Option<f64>,
    pub event_bar_median: Option<f64>,
    pub event_bar_q75: Option<f64>,
    pub median_clock_et: Option<String>,
    pub top_event_bars: Vec<Value>,
    pub forward_label_minutes: usize,
    pub raw_forward_direction_frequency: Option<f64>,
    pub median_forward_return: Option<f64>,
    pub forward_return_q05: Option<f64>,
    pub forward_return_q95: Option<f64>,
    pub median_mfe: Option<f64>,
    pub median_mae: Option<f64>,
    pub data_manifest_hash: Option<String>,
    pub evidence_grade: String,
    pub caveats: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvidenceEnvelope {
    pub schema_version: String,
    pub request_id: String,
    pub query_sha256: String,
    pub response_sha256: Option<String>,
    pub generated_at: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub status: String,
    pub query: MarketQuery,
    pub candidates: Vec<ResearchCandidate>,
    pub exclusions: Vec<Value>,
    pub historical: Vec<HistoricalSetupStats>,
    pub data_blockers: Vec<String>,
    pub model_contract: Value,
    pub research_only_policy: Value,
    pub caveats: Vec<String>,
}

impl EvidenceEnvelope {
    pub fn seal(&mut self) -> Result<()> {
        self.response_sha256 = None;
        self.response_sha256 = Some(sha256_hex(&serde_json::to_vec(self)?));
        Ok(())
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

#[derive(Debug, Deserialize)]
struct HistoricalBarRow {
    timestamp: String,
    symbol: String,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    source: String,
}

#[derive(Debug, Clone)]
struct MinuteBar {
    minute_from_open: i32,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
}

#[derive(Debug, Clone)]
struct FiveMinuteBar {
    number: usize,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    session_vwap: f64,
}

#[derive(Debug, Clone, Copy)]
struct MomentumObservation {
    matched: bool,
    lookback_bars: usize,
    cumulative_return: f64,
    directional_bars: usize,
    recent_volume_ratio: Option<f64>,
    threshold_return: f64,
}

#[derive(Debug)]
struct EventObservation {
    bar_number: usize,
    forward_return: Option<f64>,
    mfe: Option<f64>,
    mae: Option<f64>,
}

type HistoricalSessionLoad = (
    BTreeMap<NaiveDate, Vec<MinuteBar>>,
    BTreeSet<String>,
    Option<String>,
);

fn load_regular_sessions(
    path: &Path,
    symbol: &str,
    cutoff: Option<DateTime<Utc>>,
) -> Result<HistoricalSessionLoad> {
    let mut reader = csv::ReaderBuilder::new()
        .flexible(false)
        .from_path(path)
        .with_context(|| format!("open historical market bars {}", path.display()))?;
    let mut sessions = BTreeMap::<NaiveDate, Vec<MinuteBar>>::new();
    let mut sources = BTreeSet::new();
    for row in reader.deserialize::<HistoricalBarRow>() {
        let row = match row {
            Ok(value) => value,
            Err(_) => continue,
        };
        if !row.symbol.trim().eq_ignore_ascii_case(symbol) {
            continue;
        }
        let Ok(timestamp) = DateTime::parse_from_rfc3339(&row.timestamp) else {
            continue;
        };
        let timestamp = timestamp.with_timezone(&Utc);
        if cutoff.is_some_and(|value| timestamp > value) {
            continue;
        }
        let local = timestamp.with_timezone(&New_York);
        let minute = (local.hour() * 60 + local.minute()) as i32;
        if !(570..960).contains(&minute)
            || !row.open.is_finite()
            || !row.high.is_finite()
            || !row.low.is_finite()
            || !row.close.is_finite()
            || !row.volume.is_finite()
            || row.open <= 0.0
            || row.low <= 0.0
            || row.high < row.open.max(row.close)
            || row.low > row.open.min(row.close)
            || row.volume < 0.0
        {
            continue;
        }
        sources.insert(row.source);
        sessions
            .entry(local.date_naive())
            .or_default()
            .push(MinuteBar {
                minute_from_open: minute - 570,
                open: row.open,
                high: row.high,
                low: row.low,
                close: row.close,
                volume: row.volume,
            });
    }
    for rows in sessions.values_mut() {
        rows.sort_by_key(|row| row.minute_from_open);
    }
    let manifest_hash = latest_manifest_hash(path.parent().and_then(Path::parent));
    Ok((sessions, sources, manifest_hash))
}

fn latest_manifest_hash(data_root: Option<&Path>) -> Option<String> {
    let root = data_root?.join("manifests");
    let mut paths = fs::read_dir(root)
        .ok()?
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| {
            let metadata = entry.metadata().ok()?;
            metadata
                .is_file()
                .then_some((metadata.modified().ok()?, entry.path()))
        })
        .collect::<Vec<_>>();
    paths.sort_by_key(|row| std::cmp::Reverse(row.0));
    for (_, path) in paths {
        let value = fs::read(&path)
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())?;
        if let Some(hash) = value
            .get("sha256")
            .and_then(Value::as_str)
            .filter(|hash| hash.len() == 64 && hash.bytes().all(|byte| byte.is_ascii_hexdigit()))
        {
            return Some(hash.to_string());
        }
    }
    None
}

fn aggregate_five_minutes(rows: &[MinuteBar]) -> Vec<FiveMinuteBar> {
    let mut by_minute = BTreeMap::new();
    for row in rows {
        by_minute.insert(row.minute_from_open, row);
    }
    let mut output = Vec::new();
    let mut cumulative_pv = 0.0;
    let mut cumulative_volume = 0.0;
    for bucket in 0..78 {
        let start = bucket * 5;
        let Some(bucket_rows) = (start..start + 5)
            .map(|minute| by_minute.get(&minute).copied())
            .collect::<Option<Vec<_>>>()
        else {
            continue;
        };
        for row in &bucket_rows {
            cumulative_pv += row.close * row.volume;
            cumulative_volume += row.volume;
        }
        let Some(first) = bucket_rows.first() else {
            continue;
        };
        let Some(last) = bucket_rows.last() else {
            continue;
        };
        output.push(FiveMinuteBar {
            number: bucket as usize + 1,
            open: first.open,
            high: bucket_rows
                .iter()
                .map(|row| row.high)
                .fold(f64::NEG_INFINITY, f64::max),
            low: bucket_rows
                .iter()
                .map(|row| row.low)
                .fold(f64::INFINITY, f64::min),
            close: last.close,
            volume: bucket_rows.iter().map(|row| row.volume).sum(),
            session_vwap: if cumulative_volume > 0.0 {
                cumulative_pv / cumulative_volume
            } else {
                last.close
            },
        });
    }
    output
}

fn momentum_observation(
    bars: &[FiveMinuteBar],
    direction: TurnDirection,
    horizon_minutes: usize,
) -> Option<MomentumObservation> {
    let requested_bars = horizon_minutes.div_ceil(5).clamp(2, 12);
    if bars.len() < requested_bars {
        return None;
    }
    let window = &bars[bars.len() - requested_bars..];
    let first = window.first()?;
    let latest = window.last()?;
    let previous = window.get(window.len().saturating_sub(2))?;
    let cumulative_return = latest.close / first.open - 1.0;
    let directional_bars = window
        .iter()
        .filter(|bar| match direction {
            TurnDirection::Up => bar.close > bar.open,
            TurnDirection::Down => bar.close < bar.open,
        })
        .count();
    let previous_average_volume = bars
        .iter()
        .take(bars.len().saturating_sub(1))
        .map(|bar| bar.volume)
        .filter(|volume| volume.is_finite() && *volume >= 0.0)
        .sum::<f64>()
        / bars.len().saturating_sub(1).max(1) as f64;
    let recent_volume_ratio = (previous_average_volume > 0.0)
        .then_some(latest.volume / previous_average_volume)
        .filter(|value| value.is_finite());
    let threshold_return = 0.00075 * (requested_bars as f64).sqrt();
    let required_directional_bars = requested_bars.div_ceil(2);
    let matched = match direction {
        TurnDirection::Up => {
            cumulative_return >= threshold_return
                && directional_bars >= required_directional_bars
                && latest.close > latest.session_vwap
                && latest.close > previous.close
                && recent_volume_ratio.is_some_and(|value| value >= 0.90)
        }
        TurnDirection::Down => {
            cumulative_return <= -threshold_return
                && directional_bars >= required_directional_bars
                && latest.close < latest.session_vwap
                && latest.close < previous.close
                && recent_volume_ratio.is_some_and(|value| value >= 0.90)
        }
    };
    Some(MomentumObservation {
        matched,
        lookback_bars: requested_bars,
        cumulative_return,
        directional_bars,
        recent_volume_ratio,
        threshold_return,
    })
}

fn detect_event(
    bars: &[FiveMinuteBar],
    setup_type: MarketSetupType,
    direction: TurnDirection,
    horizon_minutes: usize,
) -> Option<EventObservation> {
    if bars.len() < 4 {
        return None;
    }
    let horizon_bars = horizon_minutes.div_ceil(5);
    let session_open = bars.first()?.open;
    let mut running_high = bars[0].high;
    let mut running_low = bars[0].low;
    for index in 1..bars.len() {
        let current = &bars[index];
        let previous = &bars[index - 1];
        let down = match setup_type {
            MarketSetupType::OpeningTurn => {
                let prior_positive_progress =
                    running_high / session_open - 1.0 >= 0.001 || previous.close > session_open;
                current.number <= 24
                    && prior_positive_progress
                    && current.close < current.open
                    && current.close < previous.close
                    && current.high < running_high
                    && (current.close < current.session_vwap || current.close < previous.low)
            }
            MarketSetupType::VwapReversal => {
                current.number >= 3
                    && previous.close >= previous.session_vwap
                    && current.close < current.session_vwap
                    && current.close < current.open
                    && current.close < previous.close
            }
            _ => false,
        };
        let up = match setup_type {
            MarketSetupType::OpeningTurn => {
                let prior_negative_progress =
                    running_low / session_open - 1.0 <= -0.001 || previous.close < session_open;
                current.number <= 24
                    && prior_negative_progress
                    && current.close > current.open
                    && current.close > previous.close
                    && current.low > running_low
                    && (current.close > current.session_vwap || current.close > previous.high)
            }
            MarketSetupType::VwapReversal => {
                current.number >= 3
                    && previous.close <= previous.session_vwap
                    && current.close > current.session_vwap
                    && current.close > current.open
                    && current.close > previous.close
            }
            _ => false,
        };
        running_high = running_high.max(current.high);
        running_low = running_low.min(current.low);
        let matched = match direction {
            TurnDirection::Down => down,
            TurnDirection::Up => up,
        };
        if !matched {
            continue;
        }
        let future = bars
            .iter()
            .skip(index + 1)
            .take(horizon_bars)
            .collect::<Vec<_>>();
        let forward_return = future.last().map(|last| last.close / current.close - 1.0);
        let mfe = (!future.is_empty()).then(|| {
            future
                .iter()
                .map(|bar| bar.high / current.close - 1.0)
                .fold(f64::NEG_INFINITY, f64::max)
        });
        let mae = (!future.is_empty()).then(|| {
            future
                .iter()
                .map(|bar| bar.low / current.close - 1.0)
                .fold(f64::INFINITY, f64::min)
        });
        return Some(EventObservation {
            bar_number: current.number,
            forward_return,
            mfe,
            mae,
        });
    }
    None
}

fn quantile(values: &[f64], probability: f64) -> Option<f64> {
    if values.is_empty() || !probability.is_finite() {
        return None;
    }
    let mut sorted = values
        .iter()
        .copied()
        .filter(|value| value.is_finite())
        .collect::<Vec<_>>();
    if sorted.is_empty() {
        return None;
    }
    sorted.sort_by(f64::total_cmp);
    let position = probability.clamp(0.0, 1.0) * (sorted.len() - 1) as f64;
    let lower = position.floor() as usize;
    let upper = position.ceil() as usize;
    if lower == upper {
        Some(sorted[lower])
    } else {
        let weight = position - lower as f64;
        Some(sorted[lower] * (1.0 - weight) + sorted[upper] * weight)
    }
}

fn bar_clock_et(bar_number: f64) -> String {
    let rounded = bar_number.round().max(1.0) as i64;
    let start_minutes = 570 + (rounded - 1) * 5;
    format!(
        "{:02}:{:02}-{:02}:{:02}",
        start_minutes / 60,
        start_minutes % 60,
        (start_minutes + 5) / 60,
        (start_minutes + 5) % 60
    )
}

pub fn historical_setup_stats(
    bars_path: &Path,
    symbol: &str,
    setup_type: MarketSetupType,
    direction: TurnDirection,
    horizon_minutes: usize,
    cutoff: Option<DateTime<Utc>>,
) -> Result<HistoricalSetupStats> {
    if !matches!(
        setup_type,
        MarketSetupType::OpeningTurn | MarketSetupType::VwapReversal
    ) {
        bail!("historical setup method is not implemented for {setup_type:?}");
    }
    let (sessions, sources, manifest_hash) = load_regular_sessions(bars_path, symbol, cutoff)?;
    let dataset_start = sessions.keys().next().copied();
    let dataset_end = sessions.keys().next_back().copied();
    let mut observations = Vec::new();
    for rows in sessions.values() {
        let bars = aggregate_five_minutes(rows);
        if let Some(event) = detect_event(&bars, setup_type, direction, horizon_minutes) {
            observations.push(event);
        }
    }
    let event_bars = observations
        .iter()
        .map(|row| row.bar_number as f64)
        .collect::<Vec<_>>();
    let forward = observations
        .iter()
        .filter_map(|row| row.forward_return)
        .collect::<Vec<_>>();
    let mfe = observations
        .iter()
        .filter_map(|row| row.mfe)
        .collect::<Vec<_>>();
    let mae = observations
        .iter()
        .filter_map(|row| row.mae)
        .collect::<Vec<_>>();
    let mut bar_counts = BTreeMap::<usize, usize>::new();
    for event in &observations {
        *bar_counts.entry(event.bar_number).or_default() += 1;
    }
    let mut top_event_bars = bar_counts.into_iter().collect::<Vec<_>>();
    top_event_bars.sort_by(|left, right| right.1.cmp(&left.1).then_with(|| left.0.cmp(&right.0)));
    let top_event_bars = top_event_bars
        .into_iter()
        .take(10)
        .map(|(bar_number, count)| {
            json!({
                "bar_number":bar_number,
                "clock_et":bar_clock_et(bar_number as f64),
                "count":count,
                "share_of_events":count as f64 / observations.len().max(1) as f64
            })
        })
        .collect();
    let direction_frequency = if forward.is_empty() {
        None
    } else {
        Some(
            forward
                .iter()
                .filter(|value| match direction {
                    TurnDirection::Down => **value < 0.0,
                    TurnDirection::Up => **value > 0.0,
                })
                .count() as f64
                / forward.len() as f64,
        )
    };
    let median_bar = quantile(&event_bars, 0.50);
    Ok(HistoricalSetupStats {
        symbol: symbol.to_string(),
        setup_type,
        method_version: match setup_type {
            MarketSetupType::OpeningTurn => OPENING_EXHAUSTION_METHOD_VERSION,
            MarketSetupType::VwapReversal => VWAP_REVERSAL_METHOD_VERSION,
            _ => unreachable!(),
        }
        .to_string(),
        event_definition: match (setup_type, direction) {
            (MarketSetupType::OpeningTurn, TurnDirection::Down) =>
                "First completed 5-minute bar in the first two hours that follows measurable upside progress, closes bearish below the prior close, fails to extend the session high, and closes below causal session VWAP or the prior low.",
            (MarketSetupType::OpeningTurn, TurnDirection::Up) =>
                "First completed 5-minute bar in the first two hours that follows measurable downside progress, closes bullish above the prior close, fails to extend the session low, and closes above causal session VWAP or the prior high.",
            (MarketSetupType::VwapReversal, TurnDirection::Down) =>
                "First completed 5-minute bearish cross from at/above the causally accumulated session VWAP to below it.",
            (MarketSetupType::VwapReversal, TurnDirection::Up) =>
                "First completed 5-minute bullish cross from at/below the causally accumulated session VWAP to above it.",
            _ => unreachable!(),
        }.to_string(),
        source: sources.into_iter().collect::<Vec<_>>().join("+"),
        dataset_start,
        dataset_end,
        sessions: sessions.len(),
        event_sessions: observations.len(),
        event_rate: (!sessions.is_empty()).then(|| observations.len() as f64 / sessions.len() as f64),
        event_bar_q25: quantile(&event_bars, 0.25),
        event_bar_median: median_bar,
        event_bar_q75: quantile(&event_bars, 0.75),
        median_clock_et: median_bar.map(bar_clock_et),
        top_event_bars,
        forward_label_minutes: horizon_minutes,
        raw_forward_direction_frequency: direction_frequency,
        median_forward_return: quantile(&forward, 0.50),
        forward_return_q05: quantile(&forward, 0.05),
        forward_return_q95: quantile(&forward, 0.95),
        median_mfe: quantile(&mfe, 0.50),
        median_mae: quantile(&mae, 0.50),
        data_manifest_hash: manifest_hash,
        evidence_grade: "CONTAMINATED_EXPLORATORY_DESCRIPTIVE".to_string(),
        caveats: vec![
            "The event rule is causal at the completed-bar timestamp; the forward return, MFE, and MAE are evaluation labels only.".to_string(),
            "This is an unconditional descriptive distribution, not a calibrated probability and not an untouched out-of-sample result.".to_string(),
            "SPY is a tradable proxy for broad US equity direction; it is not SPX index volume.".to_string(),
        ],
    })
}

fn live_bar_from_value(value: &Value) -> Option<(MarketBar, DateTime<Utc>, String, String)> {
    if let Ok(envelope) = serde_json::from_value::<RealtimeMarketBarEnvelope>(value.clone()) {
        if envelope.delayed
            || envelope.stale
            || !envelope
                .entitlement
                .to_ascii_uppercase()
                .contains("REALTIME")
        {
            return None;
        }
        return Some((
            envelope.bar,
            envelope.finalized_at,
            envelope.provider,
            envelope.entitlement,
        ));
    }
    if let Ok(finalized) = serde_json::from_value::<FinalizedLiveBar>(value.clone()) {
        if !finalized.is_final
            || finalized.gap_status != "COMPLETE"
            || finalized.update.is_cached_push
            || finalized.update.is_replay
        {
            return None;
        }
        return Some((
            finalized.as_market_bar(),
            finalized.finalized_timestamp,
            finalized.update.source_version,
            "NASDAQ_BASIC_NON_CONSOLIDATED".to_string(),
        ));
    }
    None
}

pub fn live_vwap_candidate(
    path: &Path,
    query: &MarketQuery,
    symbol: &str,
    now: DateTime<Utc>,
) -> std::result::Result<ResearchCandidate, String> {
    let text = fs::read_to_string(path)
        .map_err(|error| format!("LIVE_BAR_ARTIFACT_UNAVAILABLE:{error}"))?;
    let mut rows = Vec::<(MarketBar, DateTime<Utc>, String, String)>::new();
    for line in text.lines() {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let Some(row) = live_bar_from_value(&value) else {
            continue;
        };
        if row.0.symbol.trim().eq_ignore_ascii_case(symbol)
            && row.0.timestamp <= now
            && row.1 <= now
        {
            rows.push(row);
        }
    }
    rows.sort_by_key(|row| row.0.timestamp);
    let Some((latest_bar, latest_available_at, provider, entitlement)) = rows.last().cloned()
    else {
        return Err("NO_ELIGIBLE_REALTIME_FINALIZED_BARS".to_string());
    };
    let age_seconds = now.signed_duration_since(latest_available_at).num_seconds();
    if age_seconds < 0 || age_seconds > query.filters.max_data_age_seconds {
        return Err(format!(
            "STALE_OR_FUTURE_LIVE_BAR:age_seconds={age_seconds}:maximum={}",
            query.filters.max_data_age_seconds
        ));
    }
    let latest_date = latest_bar.timestamp.with_timezone(&New_York).date_naive();
    let mut session = rows
        .into_iter()
        .filter(|row| {
            let local = row.0.timestamp.with_timezone(&New_York);
            let minute = local.hour() * 60 + local.minute();
            local.date_naive() == latest_date && (570..960).contains(&minute)
        })
        .map(|row| row.0)
        .collect::<Vec<_>>();
    session.sort_by_key(|bar| bar.timestamp);
    let minute_rows = session
        .iter()
        .map(|bar| {
            let local = bar.timestamp.with_timezone(&New_York);
            MinuteBar {
                minute_from_open: (local.hour() * 60 + local.minute()) as i32 - 570,
                open: bar.open,
                high: bar.high,
                low: bar.low,
                close: bar.close,
                volume: bar.volume,
            }
        })
        .collect::<Vec<_>>();
    let bars = aggregate_five_minutes(&minute_rows);
    let Some(latest) = bars.last() else {
        return Err("AWAITING_FIRST_COMPLETE_FIVE_MINUTE_BAR".to_string());
    };
    let previous = bars.get(bars.len().saturating_sub(2));
    let distance_vwap = latest.close / latest.session_vwap - 1.0;
    let five_minute_return = latest.close / latest.open - 1.0;
    let momentum = momentum_observation(&bars, query.filters.direction, query.horizon_minutes);
    let matched = match (query.setup_type, query.filters.direction, previous) {
        (MarketSetupType::Momentum, _, _) => {
            momentum.is_some_and(|observation| observation.matched)
        }
        (MarketSetupType::VwapReversal, TurnDirection::Down, Some(previous)) => {
            previous.close >= previous.session_vwap
                && latest.close < latest.session_vwap
                && latest.close < latest.open
        }
        (MarketSetupType::VwapReversal, TurnDirection::Up, Some(previous)) => {
            previous.close <= previous.session_vwap
                && latest.close > latest.session_vwap
                && latest.close > latest.open
        }
        (MarketSetupType::OpeningTurn, _, _) => detect_event(
            &bars,
            MarketSetupType::OpeningTurn,
            query.filters.direction,
            query.horizon_minutes,
        )
        .is_some_and(|event| event.bar_number == latest.number),
        _ => false,
    };
    let condition = if matched {
        "TRIGGERED_ON_LATEST_COMPLETED_BAR"
    } else {
        "NOT_TRIGGERED_ON_LATEST_COMPLETED_BAR"
    };
    let mut supporting = vec![
        EvidenceItem {
            code: "FINALIZED_5M_BAR".to_string(),
            statement: format!(
                "Latest completed bar is number {} ({})",
                latest.number,
                bar_clock_et(latest.number as f64)
            ),
            observed_value: Some(json!(latest.number)),
        },
        EvidenceItem {
            code: "CAUSAL_SESSION_VWAP".to_string(),
            statement: "Session VWAP uses only finalized minute bars available through the cutoff."
                .to_string(),
            observed_value: Some(json!(latest.session_vwap)),
        },
    ];
    let mut contrary = Vec::new();
    if query.setup_type == MarketSetupType::Momentum {
        if let Some(observation) = momentum {
            supporting.push(EvidenceItem {
                code: "CAUSAL_MOMENTUM_WINDOW".to_string(),
                statement: format!(
                    "{} finalized five-minute bars were evaluated for directional persistence.",
                    observation.lookback_bars
                ),
                observed_value: Some(json!({
                    "method_version":MOMENTUM_METHOD_VERSION,
                    "lookback_bars":observation.lookback_bars,
                    "cumulative_return":observation.cumulative_return,
                    "directional_bars":observation.directional_bars,
                    "recent_volume_ratio":observation.recent_volume_ratio,
                    "threshold_return":observation.threshold_return
                })),
            });
        } else {
            contrary.push(EvidenceItem {
                code: "INSUFFICIENT_FINALIZED_MOMENTUM_BARS".to_string(),
                statement:
                    "The session does not yet contain the configured causal momentum window."
                        .to_string(),
                observed_value: None,
            });
        }
    }
    if matched {
        supporting.push(EvidenceItem {
            code: "SETUP_RULE_MATCH".to_string(),
            statement: "The configured completed-bar rule is satisfied.".to_string(),
            observed_value: Some(json!(true)),
        });
    } else {
        contrary.push(EvidenceItem {
            code: "SETUP_RULE_NOT_MATCHED".to_string(),
            statement: "The configured completed-bar rule is not satisfied on the latest bar."
                .to_string(),
            observed_value: Some(json!(false)),
        });
    }
    if !entitlement.to_ascii_uppercase().contains("SIP") {
        contrary.push(EvidenceItem {
            code: "NON_CONSOLIDATED_EQUITY_FEED".to_string(),
            statement: "The equity feed is realtime but is not verified as consolidated SIP NBBO."
                .to_string(),
            observed_value: Some(json!(entitlement)),
        });
    }
    Ok(ResearchCandidate {
        symbol: symbol.to_string(),
        setup_type: query.setup_type,
        status: condition.to_string(),
        heuristic_structure_score: None,
        score_semantics: "No composite score is emitted for a deterministic bar-rule state."
            .to_string(),
        supporting_evidence: supporting,
        contrary_evidence: contrary,
        metrics: json!({
            "bar_number":latest.number,
            "clock_et":bar_clock_et(latest.number as f64),
            "open":latest.open,
            "high":latest.high,
            "low":latest.low,
            "close":latest.close,
            "session_vwap":latest.session_vwap,
            "distance_from_vwap":distance_vwap,
            "five_minute_return":five_minute_return,
            "momentum_method_version":(query.setup_type == MarketSetupType::Momentum)
                .then_some(MOMENTUM_METHOD_VERSION),
            "momentum_lookback_bars":momentum.map(|value| value.lookback_bars),
            "momentum_cumulative_return":momentum.map(|value| value.cumulative_return),
            "momentum_directional_bars":momentum.map(|value| value.directional_bars),
            "momentum_recent_volume_ratio":momentum.and_then(|value| value.recent_volume_ratio),
            "momentum_threshold_return":momentum.map(|value| value.threshold_return),
            "observation_cutoff":latest_bar.timestamp + chrono::Duration::minutes(1),
            "rule_state":condition
        }),
        freshness: vec![DataFreshness {
            source: provider,
            observed_at: Some(latest_bar.timestamp),
            available_at: Some(latest_available_at),
            age_seconds: Some(age_seconds),
            realtime: true,
            entitlement,
            coverage: None,
        }],
    })
}

fn median(values: &mut [f64]) -> Option<f64> {
    values.sort_by(f64::total_cmp);
    quantile(values, 0.50)
}

pub fn gamma_structure_candidate(
    path: &Path,
    query: &MarketQuery,
    symbol: &str,
    now: DateTime<Utc>,
    configured_minimum_quote_coverage: f64,
) -> std::result::Result<ResearchCandidate, String> {
    if !path.exists() {
        return Err("FULL_OPRA_CHAIN_ARTIFACT_ABSENT".to_string());
    }
    let bytes =
        fs::read(path).map_err(|error| format!("OPTION_CHAIN_ARTIFACT_UNAVAILABLE:{error}"))?;
    let snapshot = serde_json::from_slice::<MassiveFullOptionChain>(&bytes)
        .map_err(|error| format!("OPTION_CHAIN_ARTIFACT_INVALID:{error}"))?;
    if snapshot.schema_version != OPTION_CHAIN_SCHEMA_VERSION {
        return Err("OPTION_CHAIN_SCHEMA_INCOMPATIBLE".to_string());
    }
    let observed_hash = sha256_hex(
        &serde_json::to_vec(&snapshot.contracts)
            .map_err(|error| format!("OPTION_CHAIN_HASH_SERIALIZATION_FAILED:{error}"))?,
    );
    if observed_hash != snapshot.contracts_sha256 {
        return Err("OPTION_CHAIN_ARTIFACT_HASH_MISMATCH".to_string());
    }
    if !snapshot.chain_complete || !snapshot.model_ready {
        return Err(format!(
            "OPTION_CHAIN_NOT_MODEL_READY:{}",
            snapshot.blockers.join("|")
        ));
    }
    let age_seconds = now
        .signed_duration_since(snapshot.captured_at)
        .num_seconds();
    if age_seconds < 0 || age_seconds > query.filters.max_data_age_seconds {
        return Err(format!(
            "STALE_OR_FUTURE_OPTION_CHAIN:age_seconds={age_seconds}:maximum={}",
            query.filters.max_data_age_seconds
        ));
    }
    let required_coverage = query
        .filters
        .minimum_option_quote_coverage
        .unwrap_or(configured_minimum_quote_coverage);
    if snapshot.coverage.fresh_quote_coverage < required_coverage {
        return Err(format!(
            "OPTION_QUOTE_COVERAGE_BELOW_REQUIREMENT:observed={}:required={required_coverage}",
            snapshot.coverage.fresh_quote_coverage
        ));
    }
    let contracts = snapshot
        .contracts
        .iter()
        .filter(|contract| (0..=query.filters.max_dte).contains(&contract.dte))
        .collect::<Vec<_>>();
    if contracts.is_empty() {
        return Err("NO_CONTRACTS_IN_REQUESTED_DTE_WINDOW".to_string());
    }
    let spot = contracts
        .iter()
        .filter_map(|contract| contract.underlying_price)
        .find(|price| price.is_finite() && *price > 0.0)
        .ok_or_else(|| "UNDERLYING_SPOT_UNAVAILABLE".to_string())?;
    let quotes = contracts
        .iter()
        .filter_map(|contract| contract.as_option_quote())
        .collect::<Vec<_>>();
    if quotes.len() != contracts.len() {
        return Err(format!(
            "INCOMPLETE_ELIGIBLE_CONTRACT_COVERAGE:eligible_quotes={}:contracts={}",
            quotes.len(),
            contracts.len()
        ));
    }
    let gamma = gamma_convexity_feedback_risk(
        &quotes,
        &GammaConvexityRequest {
            as_of: now,
            underlying: symbol.to_string(),
            spot,
            contract_multiplier: 100.0,
            oi_as_of: Some(snapshot.oi_available_at),
            greeks_as_of: Some(snapshot.greeks_available_at),
            max_quote_age_seconds: query.filters.max_data_age_seconds,
            max_oi_age_seconds: query.filters.max_data_age_seconds,
            max_greeks_age_seconds: query.filters.max_data_age_seconds,
        },
    );
    if gamma.availability != GammaConvexityAvailability::Available {
        return Err(format!(
            "GAMMA_CONVEXITY_UNAVAILABLE:{:?}",
            gamma.unavailable_reasons
        ));
    }
    let exposure = gamma
        .exposure
        .as_ref()
        .ok_or_else(|| "GAMMA_EXPOSURE_ABSENT".to_string())?;
    let atm = gamma
        .atm_distance
        .as_ref()
        .ok_or_else(|| "GAMMA_ATM_CONCENTRATION_ABSENT".to_string())?;
    let strike = gamma
        .strike_concentration
        .as_ref()
        .ok_or_else(|| "GAMMA_STRIKE_CONCENTRATION_ABSENT".to_string())?;
    let call_volume = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Call)
        .filter_map(|contract| contract.volume)
        .sum::<u64>();
    let put_volume = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Put)
        .filter_map(|contract| contract.volume)
        .sum::<u64>();
    let call_oi = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Call)
        .filter_map(|contract| contract.open_interest)
        .sum::<u64>();
    let put_oi = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Put)
        .filter_map(|contract| contract.open_interest)
        .sum::<u64>();
    let call_volume_share = call_volume as f64 / (call_volume + put_volume).max(1) as f64;
    let call_gamma_share = exposure.call_share_of_unsigned_exposure.unwrap_or(0.0);
    let near_atm_share = atm.unsigned_exposure_share_within_two_pct.unwrap_or(0.0);
    let dominant_distance = strike.dominant_strike_abs_distance_pct.unwrap_or(1.0).abs();
    let strike_proximity = (1.0 - dominant_distance / 0.10).clamp(0.0, 1.0);
    let call_volume_oi = call_volume as f64 / call_oi.max(1) as f64;
    let flow_anomaly = (call_volume_oi / 2.0).clamp(0.0, 1.0);
    let mut spreads = contracts
        .iter()
        .filter_map(|contract| {
            let bid = contract.bid?;
            let ask = contract.ask?;
            let mid = (bid + ask) * 0.5;
            (mid > 0.0 && ask >= bid).then_some((ask - bid) / mid)
        })
        .filter(|spread| spread.is_finite())
        .collect::<Vec<_>>();
    let median_spread = median(&mut spreads);
    let maximum_spread = query.filters.maximum_option_spread_pct.unwrap_or(0.15);
    let spread_quality = median_spread
        .map(|value| (1.0 - value / maximum_spread.max(1.0e-6)).clamp(0.0, 1.0))
        .unwrap_or(0.0);
    let score = 100.0
        * (0.25 * near_atm_share
            + 0.20 * call_gamma_share
            + 0.20 * call_volume_share
            + 0.15 * strike_proximity
            + 0.10 * flow_anomaly
            + 0.10 * spread_quality);
    let mut supporting = Vec::new();
    let mut contrary = Vec::new();
    let evidence = [
        (
            near_atm_share >= 0.50,
            "NEAR_ATM_GAMMA_CONCENTRATION",
            "Unsigned gamma exposure within 2% of spot",
            json!(near_atm_share),
        ),
        (
            call_gamma_share >= 0.55,
            "CALL_GAMMA_SHARE",
            "Call share of unsigned gamma exposure",
            json!(call_gamma_share),
        ),
        (
            call_volume_share >= 0.60,
            "CALL_VOLUME_SHARE",
            "Call share of observed option volume",
            json!(call_volume_share),
        ),
        (
            call_volume_oi >= 1.0,
            "CALL_VOLUME_OPEN_INTEREST",
            "Aggregate call volume/open-interest ratio",
            json!(call_volume_oi),
        ),
        (
            dominant_distance <= 0.02,
            "DOMINANT_STRIKE_PROXIMITY",
            "Dominant unsigned-gamma strike distance from spot",
            json!(dominant_distance),
        ),
    ];
    for (supports, code, statement, observed_value) in evidence {
        let item = EvidenceItem {
            code: code.to_string(),
            statement: statement.to_string(),
            observed_value: Some(observed_value),
        };
        if supports {
            supporting.push(item);
        } else {
            contrary.push(item);
        }
    }
    if median_spread.is_some_and(|spread| spread > maximum_spread) {
        contrary.push(EvidenceItem {
            code: "OPTION_SPREAD_TOO_WIDE".to_string(),
            statement: "Median option spread exceeds the configured liquidity limit.".to_string(),
            observed_value: median_spread.map(|value| json!(value)),
        });
    }
    contrary.push(EvidenceItem {
        code: "DEALER_SIGN_UNOBSERVED".to_string(),
        statement: "Open interest and public trades do not reveal dealer inventory sign."
            .to_string(),
        observed_value: None,
    });
    if query.filters.exclude_earnings_within_days.is_some() {
        contrary.push(EvidenceItem {
            code: "EARNINGS_CALENDAR_NOT_CONNECTED".to_string(),
            statement: "The requested earnings exclusion cannot be verified from the current point-in-time data contract.".to_string(),
            observed_value: query
                .filters
                .exclude_earnings_within_days
                .map(|value| json!(value)),
        });
    }
    let status = if score >= 65.0 {
        "RESEARCH_CANDIDATE"
    } else {
        "OBSERVED_STRUCTURE_BELOW_RESEARCH_THRESHOLD"
    };
    Ok(ResearchCandidate {
        symbol: symbol.to_string(),
        setup_type: MarketSetupType::GammaSqueeze,
        status: status.to_string(),
        heuristic_structure_score: Some(score),
        score_semantics: "0–100 deterministic structure score, not a probability. Weights: near-ATM unsigned gamma 25%, call unsigned-gamma share 20%, call-volume share 20%, dominant-strike proximity 15%, call volume/OI 10%, spread quality 10%.".to_string(),
        supporting_evidence: supporting,
        contrary_evidence: contrary,
        metrics: json!({
            "method_version":GAMMA_STRUCTURE_METHOD_VERSION,
            "spot":spot,
            "max_dte":query.filters.max_dte,
            "contracts":contracts.len(),
            "call_volume":call_volume,
            "put_volume":put_volume,
            "call_open_interest":call_oi,
            "put_open_interest":put_oi,
            "call_volume_share":call_volume_share,
            "call_volume_open_interest_ratio":call_volume_oi,
            "call_share_unsigned_gamma":call_gamma_share,
            "unsigned_gamma_share_within_two_pct":near_atm_share,
            "dominant_gamma_strike":strike.dominant_strike,
            "dominant_gamma_strike_distance_pct":dominant_distance,
            "median_option_spread_pct":median_spread,
            "gamma_convexity":gamma,
            "dealer_position_sign":"UNOBSERVED",
            "probability":null
        }),
        freshness: vec![
            DataFreshness {
                source: snapshot.source,
                observed_at: snapshot.latest_quote_at,
                available_at: Some(snapshot.captured_at),
                age_seconds: Some(age_seconds),
                realtime: snapshot.realtime_required,
                entitlement: "OPRA_FULL_CHAIN_REQUIRED".to_string(),
                coverage: Some(snapshot.coverage.fresh_quote_coverage),
            },
            DataFreshness {
                source: "DAILY_OPEN_INTEREST_SNAPSHOT".to_string(),
                observed_at: Some(snapshot.oi_available_at),
                available_at: Some(snapshot.oi_available_at),
                age_seconds: Some(now.signed_duration_since(snapshot.oi_available_at).num_seconds()),
                realtime: false,
                entitlement: snapshot.open_interest_semantics,
                coverage: Some(snapshot.coverage.open_interest_coverage),
            },
        ],
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Datelike, TimeZone};
    use std::io::Write;

    #[test]
    fn query_rejects_unknown_or_execution_shaped_fields() {
        let payload = json!({
            "intent":"scan",
            "setup_type":"gamma_squeeze",
            "symbols":["SPY"],
            "order":{"side":"buy"}
        });
        assert!(serde_json::from_value::<MarketQuery>(payload).is_err());
    }

    #[test]
    fn query_normalization_is_deterministic() {
        let query = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Scan,
            setup_type: MarketSetupType::OpeningTurn,
            symbols: vec!["$spy".to_string(), "US.QQQ".to_string(), "SPY".to_string()],
            horizon_minutes: 15,
            limit: 10,
            as_of: None,
            filters: MarketQueryFilters::default(),
        }
        .normalize_and_validate()
        .unwrap();
        assert_eq!(query.symbols, vec!["QQQ", "SPY"]);
        assert_eq!(query.canonical_sha256().unwrap().len(), 64);
        assert_eq!(
            query.canonical_sha256().unwrap(),
            query.canonical_sha256().unwrap()
        );
    }

    #[test]
    fn momentum_rule_uses_only_finalized_window_and_requires_confirmation() {
        let bars = vec![
            FiveMinuteBar {
                number: 1,
                open: 100.00,
                high: 100.10,
                low: 99.98,
                close: 100.08,
                volume: 1_000.0,
                session_vwap: 100.04,
            },
            FiveMinuteBar {
                number: 2,
                open: 100.08,
                high: 100.22,
                low: 100.06,
                close: 100.19,
                volume: 1_100.0,
                session_vwap: 100.09,
            },
            FiveMinuteBar {
                number: 3,
                open: 100.19,
                high: 100.34,
                low: 100.17,
                close: 100.31,
                volume: 1_250.0,
                session_vwap: 100.15,
            },
        ];
        let up = momentum_observation(&bars, TurnDirection::Up, 15).unwrap();
        let down = momentum_observation(&bars, TurnDirection::Down, 15).unwrap();
        assert!(up.matched);
        assert!(!down.matched);
        assert_eq!(up.directional_bars, 3);
        assert!(up.recent_volume_ratio.is_some_and(|value| value > 1.0));
    }

    #[test]
    fn historical_opening_turn_is_causal_and_reports_forward_labels() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("bars.csv");
        let mut file = fs::File::create(&path).unwrap();
        writeln!(
            file,
            "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality"
        )
        .unwrap();
        let date = NaiveDate::from_ymd_opt(2026, 7, 20).unwrap();
        let start = New_York
            .with_ymd_and_hms(date.year(), date.month(), date.day(), 9, 30, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);
        for minute in 0..25 {
            let (open, close) = if minute < 10 {
                (100.0 + minute as f64 * 0.02, 100.03 + minute as f64 * 0.02)
            } else if minute < 15 {
                (100.20, 100.04)
            } else {
                (100.04, 99.95)
            };
            let timestamp = start + chrono::Duration::minutes(minute);
            writeln!(
                file,
                "{timestamp},SPY,{open},{},{},{close},1000,,,,10,MASSIVE_STOCKS_AGG_1M,vendor",
                open.max(close) + 0.02,
                open.min(close) - 0.02,
                timestamp = timestamp.to_rfc3339()
            )
            .unwrap();
        }
        let stats = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::OpeningTurn,
            TurnDirection::Down,
            15,
            None,
        )
        .unwrap();
        assert_eq!(stats.sessions, 1);
        assert_eq!(stats.event_sessions, 1);
        assert!(stats.event_bar_median.is_some());
        assert!(stats.median_forward_return.is_some());
    }

    #[test]
    fn envelope_hash_is_over_payload_without_hash_field() {
        let query = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Scan,
            setup_type: MarketSetupType::OpeningTurn,
            symbols: vec!["SPY".to_string()],
            horizon_minutes: 15,
            limit: 10,
            as_of: None,
            filters: MarketQueryFilters::default(),
        };
        let mut envelope = EvidenceEnvelope {
            schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
            request_id: "request".to_string(),
            query_sha256: query.canonical_sha256().unwrap(),
            response_sha256: None,
            generated_at: DateTime::<Utc>::UNIX_EPOCH,
            observation_cutoff: DateTime::<Utc>::UNIX_EPOCH,
            status: "DATA_UNAVAILABLE".to_string(),
            query,
            candidates: Vec::new(),
            exclusions: Vec::new(),
            historical: Vec::new(),
            data_blockers: Vec::new(),
            model_contract: json!({}),
            research_only_policy: json!({}),
            caveats: Vec::new(),
        };
        envelope.seal().unwrap();
        assert_eq!(envelope.response_sha256.as_deref().unwrap().len(), 64);
    }
}
