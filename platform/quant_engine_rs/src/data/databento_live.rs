//! Licensed Databento live-equities adapter.
//!
//! The adapter authenticates with Databento's official Rust client, subscribes
//! to the configured `EQUS.MINI` one-minute OHLCV universe, and persists only
//! normalized observations plus explicit session/readiness metadata. It never
//! logs the API key, requests replay, or enables broker execution.

use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
    time::Duration,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration as ChronoDuration, Timelike, Utc};
use chrono_tz::America::New_York;
use databento::{
    LiveClient,
    dbn::{
        ErrorMsg, OhlcvMsg, PitSymbolMap, SType, Schema, SymbolIndex, SymbolMappingMsg, SystemCode,
        SystemMsg,
    },
    live::Subscription,
};
use serde::{Deserialize, Serialize};
use time::Duration as TimeDuration;

use crate::{
    config::{DataConfig, DataRequest, LiveConfig},
    domain::{
        CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION, CausalMinuteObservation, MarketBar,
        MinuteObservationState,
    },
};

const FIXED_PRICE_SCALE: f64 = 1_000_000_000.0;
pub const DATABENTO_LIVE_STATUS_SCHEMA_VERSION: &str = "databento_live_status.v3";
pub const DATABENTO_LIVE_BAR_SCHEMA_VERSION: &str = "databento_ohlcv_1m.v1";
pub const DATABENTO_CAUSAL_ABSENCE_SCHEMA_VERSION: &str = "databento_causal_absence.v1";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoSymbolCoverage {
    pub symbol: String,
    pub latest_observation_state: MinuteObservationState,
    pub latest_observed_interval_start: Option<DateTime<Utc>>,
    pub latest_observed_interval_end: Option<DateTime<Utc>>,
    pub latest_received_at: Option<DateTime<Utc>>,
    pub observed_trade_intervals: u64,
    pub causally_inferred_no_trade_intervals: u64,
    pub unknown_missing_intervals: u64,
    pub invalid_intervals_rejected: u64,
    pub duplicate_intervals_rejected: u64,
    pub out_of_order_intervals_rejected: u64,
    pub current_contiguous_observed_trade_intervals: usize,
    #[serde(default)]
    pub current_contiguous_eligible_context_intervals: usize,
    pub last_unknown_gap_start: Option<DateTime<Utc>>,
    pub last_unknown_gap_end: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoLiveStatus {
    pub schema_version: String,
    pub updated_at: DateTime<Utc>,
    pub provider: String,
    pub dataset: String,
    pub schema: String,
    pub state: String,
    pub authenticated: bool,
    pub entitlement_verified: bool,
    pub realtime_required: bool,
    pub replay_requested: bool,
    pub subscribed_symbols: Vec<String>,
    pub required_context_symbols: Vec<String>,
    pub context_observation_policy_schema_version: String,
    pub absence_semantics: String,
    pub causal_absence_inference_supported: bool,
    pub symbol_coverage: BTreeMap<String, DatabentoSymbolCoverage>,
    pub context_coverage_blockers: Vec<String>,
    pub last_heartbeat_at: Option<DateTime<Utc>>,
    pub last_provider_event_at: Option<DateTime<Utc>>,
    pub last_finalized_bar_at: Option<DateTime<Utc>>,
    pub finalized_bars: u64,
    pub symbol_mappings: u64,
    pub reconnects: u64,
    pub blocker: Option<String>,
    pub execution_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoRealtimeBarEnvelope {
    pub schema_version: String,
    pub provider: String,
    pub dataset: String,
    pub provider_schema: String,
    pub received_at: DateTime<Utc>,
    /// The first time AXIO7 could observe this record. Databento `ts_out` is
    /// not requested, so this is intentionally the local receipt time.
    pub provider_available_at: DateTime<Utc>,
    pub bar_start: DateTime<Utc>,
    pub bar_end: DateTime<Utc>,
    pub finalized_at: DateTime<Utc>,
    pub entitlement: String,
    pub delayed: bool,
    pub stale: bool,
    pub replay: bool,
    pub symbol_mapping_verified: bool,
    pub bar: MarketBar,
    pub caveats: Vec<String>,
}

impl DatabentoRealtimeBarEnvelope {
    pub fn causal_observation(&self) -> CausalMinuteObservation {
        CausalMinuteObservation {
            schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
            symbol: self.bar.symbol.clone(),
            interval_start: self.bar_start,
            interval_end: self.bar_end,
            state: MinuteObservationState::ObservedTradeBar,
            evidence_available_at: Some(self.provider_available_at),
            evidence_source: Some(format!(
                "{}/{}/{}",
                self.provider, self.dataset, self.provider_schema
            )),
            evidence_reference: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DatabentoCausalAbsenceEnvelope {
    pub schema_version: String,
    pub provider: String,
    pub dataset: String,
    pub provider_schema: String,
    pub received_at: DateTime<Utc>,
    pub interval_start: DateTime<Utc>,
    pub interval_end: DateTime<Utc>,
    pub finalize_grace_ms: i64,
    pub subscription_acknowledged_at: DateTime<Utc>,
    pub symbol_mapping_verified_at: DateTime<Utc>,
    pub continuous_health_started_at: DateTime<Utc>,
    pub continuous_health_observed_through: DateTime<Utc>,
    pub prior_real_trade_interval_start: DateTime<Utc>,
    pub derivation: String,
    pub observation: CausalMinuteObservation,
}

impl DatabentoCausalAbsenceEnvelope {
    pub fn validate(&self) -> bool {
        self.schema_version == DATABENTO_CAUSAL_ABSENCE_SCHEMA_VERSION
            && self.provider.eq_ignore_ascii_case("databento")
            && self.dataset.eq_ignore_ascii_case("EQUS.MINI")
            && self.provider_schema.eq_ignore_ascii_case("ohlcv-1m")
            && self.derivation == "CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH"
            && self.interval_end == self.interval_start + ChronoDuration::minutes(1)
            && self.finalize_grace_ms >= 0
            && self.subscription_acknowledged_at <= self.interval_start
            && self.symbol_mapping_verified_at <= self.interval_start
            && self.continuous_health_started_at <= self.interval_start
            && self.continuous_health_observed_through
                >= self.interval_end + ChronoDuration::milliseconds(self.finalize_grace_ms)
            && self.continuous_health_observed_through <= self.received_at
            && self.prior_real_trade_interval_start < self.interval_start
            && self.observation.interval_start == self.interval_start
            && self.observation.interval_end == self.interval_end
            && self.observation.state == MinuteObservationState::CausallyInferredNoTrade
            && self.observation.evidence_available_at == Some(self.received_at)
            && self.observation.evidence_source.as_deref()
                == Some("Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH")
            && self.observation.validate()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "event_type", rename_all = "snake_case")]
pub enum DatabentoInferenceEvent {
    TradeBar {
        envelope: DatabentoRealtimeBarEnvelope,
    },
    ContextObservation {
        envelope: DatabentoCausalAbsenceEnvelope,
    },
}

pub(crate) fn realtime_envelope_rejection(
    envelope: &DatabentoRealtimeBarEnvelope,
    maximum_lag_ms: i64,
) -> Option<String> {
    if envelope.schema_version != DATABENTO_LIVE_BAR_SCHEMA_VERSION {
        return Some("DATABENTO_ENVELOPE_SCHEMA_MISMATCH".into());
    }
    if !envelope.provider.eq_ignore_ascii_case("databento")
        || !envelope.dataset.eq_ignore_ascii_case("EQUS.MINI")
        || !envelope.provider_schema.eq_ignore_ascii_case("ohlcv-1m")
    {
        return Some("DATABENTO_SOURCE_IDENTITY_MISMATCH".into());
    }
    if envelope.entitlement != "REALTIME_SUBSCRIPTION_ACKNOWLEDGED"
        || envelope.delayed
        || envelope.stale
        || envelope.replay
        || !envelope.symbol_mapping_verified
    {
        return Some("DATABENTO_REALTIME_ENTITLEMENT_GATE_REJECTED".into());
    }
    if !envelope.bar.is_observed_trade_bar()
        || envelope.bar.timestamp != envelope.bar_start
        || envelope.bar_end != envelope.bar_start + ChronoDuration::minutes(1)
        || !envelope
            .bar
            .source
            .eq_ignore_ascii_case("Databento/EQUS.MINI/ohlcv-1m")
        || envelope.bar.data_quality != "licensed_vendor_original_dbn_realtime"
    {
        return Some("DATABENTO_BAR_CONTRACT_INVALID".into());
    }
    let availability_lag = envelope
        .provider_available_at
        .signed_duration_since(envelope.bar_end)
        .num_milliseconds();
    if maximum_lag_ms <= 0
        || availability_lag < 0
        || availability_lag > maximum_lag_ms
        || envelope.received_at != envelope.provider_available_at
        || envelope.finalized_at != envelope.provider_available_at
    {
        return Some("DATABENTO_AVAILABILITY_CLOCK_INVALID".into());
    }
    if !envelope.causal_observation().validate() {
        return Some("DATABENTO_CAUSAL_OBSERVATION_INVALID".into());
    }
    None
}

fn normalize_symbol(symbol: &str) -> String {
    symbol.trim().trim_start_matches("US.").to_ascii_uppercase()
}

fn configured_live_request(data: &DataConfig) -> Result<&DataRequest> {
    data.databento
        .requests
        .iter()
        .find(|request| {
            request.dataset.eq_ignore_ascii_case("EQUS.MINI")
                && request.schema.eq_ignore_ascii_case("ohlcv-1m")
                && request.stype_in.eq_ignore_ascii_case("raw_symbol")
        })
        .context(
            "Databento live requires an EQUS.MINI/ohlcv-1m/raw_symbol request in configuration",
        )
}

pub(crate) fn utc_from_nanos(value: u64) -> Result<DateTime<Utc>> {
    let nanos: i64 = value
        .try_into()
        .context("Databento timestamp exceeds signed nanosecond range")?;
    Ok(DateTime::<Utc>::from_timestamp_nanos(nanos))
}

fn early_bar_finalize_delay(
    row: &OhlcvMsg,
    observed_at: DateTime<Utc>,
    maximum_clock_skew_ms: i64,
) -> Result<Option<Duration>> {
    if maximum_clock_skew_ms <= 0 {
        return Ok(None);
    }
    let bar_end = utc_from_nanos(row.hd.ts_event)? + ChronoDuration::minutes(1);
    let early_by = bar_end.signed_duration_since(observed_at);
    if early_by <= ChronoDuration::zero()
        || early_by > ChronoDuration::milliseconds(maximum_clock_skew_ms)
    {
        return Ok(None);
    }
    Ok(early_by.to_std().ok())
}

fn write_json_atomic(path: &Path, value: &impl Serialize) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let temporary = path.with_extension("json.partial");
    fs::write(&temporary, serde_json::to_vec_pretty(value)?)?;
    if path.exists() {
        fs::remove_file(path)
            .with_context(|| format!("replace existing artifact {}", path.display()))?;
    }
    fs::rename(&temporary, path)
        .with_context(|| format!("promote atomic artifact {}", path.display()))?;
    Ok(())
}

fn redact_error(error: &anyhow::Error) -> String {
    let mut message = format!("{error:#}");
    if let Ok(api_key) = std::env::var("DATABENTO_API_KEY")
        && !api_key.is_empty()
    {
        message = message.replace(&api_key, "[REDACTED]");
    }
    message
        .split_whitespace()
        .map(|part| {
            if part
                .trim_matches(|character: char| {
                    character == '"' || character == '\'' || character == '(' || character == '['
                })
                .starts_with("db-")
            {
                "[REDACTED]"
            } else {
                part
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
        .chars()
        .take(600)
        .collect()
}

pub(crate) fn normalize_bar(
    row: &OhlcvMsg,
    symbol: &str,
    dataset: &str,
    received_at: DateTime<Utc>,
    stale_after_ms: i64,
) -> Result<DatabentoRealtimeBarEnvelope> {
    let bar_start = utc_from_nanos(row.hd.ts_event)?;
    let bar_end = bar_start + chrono::Duration::minutes(1);
    let availability_lag_ms = received_at
        .signed_duration_since(bar_end)
        .num_milliseconds();
    let stale = availability_lag_ms < 0 || availability_lag_ms > stale_after_ms;
    let bar = MarketBar {
        timestamp: bar_start,
        symbol: normalize_symbol(symbol),
        open: row.open as f64 / FIXED_PRICE_SCALE,
        high: row.high as f64 / FIXED_PRICE_SCALE,
        low: row.low as f64 / FIXED_PRICE_SCALE,
        close: row.close as f64 / FIXED_PRICE_SCALE,
        volume: row.volume as f64,
        vwap: None,
        bid: None,
        ask: None,
        trade_count: None,
        source: format!("Databento/{dataset}/ohlcv-1m"),
        data_quality: if stale {
            "licensed_vendor_original_dbn_stale"
        } else {
            "licensed_vendor_original_dbn_realtime"
        }
        .to_string(),
    };
    if !bar.is_observed_trade_bar() {
        bail!(
            "Databento OHLCV record is not positive-volume observed-trade evidence; no-trade cannot be inferred from OHLCV"
        );
    }
    Ok(DatabentoRealtimeBarEnvelope {
        schema_version: DATABENTO_LIVE_BAR_SCHEMA_VERSION.to_string(),
        provider: "databento".to_string(),
        dataset: dataset.to_string(),
        provider_schema: "ohlcv-1m".to_string(),
        received_at,
        provider_available_at: received_at,
        bar_start,
        bar_end,
        finalized_at: received_at,
        entitlement: "REALTIME_SUBSCRIPTION_ACKNOWLEDGED".to_string(),
        delayed: false,
        stale,
        replay: false,
        symbol_mapping_verified: true,
        bar,
        caveats: vec![
            "The provider send timestamp was not requested; availability is the causal AXIO7 receipt time after any bounded clock-skew hold through interval end.".to_string(),
            "OHLCV-1m contains only completed vendor bars and does not expose order-book depth."
                .to_string(),
            "Licensed access does not imply public redistribution rights.".to_string(),
        ],
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CoverageDisposition {
    Accepted,
    DuplicateRejected,
    OutOfOrderRejected,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum OhlcvProcessingDisposition {
    Accepted,
    StaleRejected,
    InvalidRejected,
    DuplicateRejected,
    OutOfOrderRejected,
}

#[derive(Debug)]
struct CausalAbsenceTracker {
    // Databento documents that OHLCV emits no record for a no-trade interval
    // and that EndOfInterval means all interval records were published. The
    // combination below is still an AXIO7 causal inference, never a
    // per-symbol vendor assertion:
    // https://databento.com/docs/schemas-and-data-formats/ohlcv
    // https://databento.com/docs/api-reference-live
    context_symbols: std::collections::BTreeSet<String>,
    target_symbols: std::collections::BTreeSet<String>,
    subscription_acknowledged_at: Option<DateTime<Utc>>,
    continuous_health_started_at: Option<DateTime<Utc>>,
    last_progress_at: Option<DateTime<Utc>>,
    mapped_at: BTreeMap<String, DateTime<Utc>>,
    prior_real_trade: BTreeMap<String, DateTime<Utc>>,
    observed_intervals: std::collections::BTreeSet<(String, i64)>,
    unknown_intervals: std::collections::BTreeSet<(String, i64)>,
    pending_end_of_interval: std::collections::BTreeSet<i64>,
    emitted_absences: std::collections::BTreeSet<(String, i64)>,
}

impl CausalAbsenceTracker {
    fn new(live: &LiveConfig) -> Self {
        Self {
            context_symbols: live
                .required_context_symbols
                .iter()
                .map(|symbol| normalize_symbol(symbol))
                .collect(),
            target_symbols: live
                .forecast_symbols
                .iter()
                .map(|symbol| normalize_symbol(symbol))
                .collect(),
            subscription_acknowledged_at: None,
            continuous_health_started_at: None,
            last_progress_at: None,
            mapped_at: BTreeMap::new(),
            prior_real_trade: BTreeMap::new(),
            observed_intervals: std::collections::BTreeSet::new(),
            unknown_intervals: std::collections::BTreeSet::new(),
            pending_end_of_interval: std::collections::BTreeSet::new(),
            emitted_absences: std::collections::BTreeSet::new(),
        }
    }

    fn acknowledge_subscription(&mut self, at: DateTime<Utc>) {
        self.subscription_acknowledged_at = Some(at);
        self.continuous_health_started_at = Some(at);
        self.last_progress_at = Some(at);
    }

    fn record_progress(&mut self, at: DateTime<Utc>) {
        self.last_progress_at = Some(at);
    }

    fn record_mapping(&mut self, symbol: &str, at: DateTime<Utc>) {
        self.mapped_at.entry(normalize_symbol(symbol)).or_insert(at);
    }

    fn record_trade(&mut self, symbol: &str, interval_start: DateTime<Utc>) -> bool {
        let symbol = normalize_symbol(symbol);
        let key = (symbol.clone(), interval_start.timestamp_millis());
        let conflicts_with_absence = self.emitted_absences.contains(&key);
        if conflicts_with_absence {
            self.unknown_intervals.insert(key.clone());
        }
        self.observed_intervals.insert(key);
        self.prior_real_trade
            .entry(symbol)
            .and_modify(|current| *current = (*current).max(interval_start))
            .or_insert(interval_start);
        conflicts_with_absence
    }

    fn record_unknown(&mut self, symbol: &str, interval_start: DateTime<Utc>) {
        self.unknown_intervals
            .insert((normalize_symbol(symbol), interval_start.timestamp_millis()));
    }

    fn record_end_of_interval(&mut self, interval_start: DateTime<Utc>) {
        self.pending_end_of_interval
            .insert(interval_start.timestamp_millis());
    }

    fn finalize_ready(
        &mut self,
        now: DateTime<Utc>,
        finalize_grace_ms: i64,
    ) -> Vec<DatabentoCausalAbsenceEnvelope> {
        let (Some(subscription_acknowledged_at), Some(health_started), Some(progress)) = (
            self.subscription_acknowledged_at,
            self.continuous_health_started_at,
            self.last_progress_at,
        ) else {
            return Vec::new();
        };
        let ready_intervals = self
            .pending_end_of_interval
            .iter()
            .copied()
            .filter(|millis| {
                DateTime::<Utc>::from_timestamp_millis(*millis).is_some_and(|start| {
                    progress
                        >= start
                            + ChronoDuration::minutes(1)
                            + ChronoDuration::milliseconds(finalize_grace_ms)
                })
            })
            .collect::<Vec<_>>();
        let mut output = Vec::new();
        for millis in ready_intervals {
            self.pending_end_of_interval.remove(&millis);
            let Some(interval_start) = DateTime::<Utc>::from_timestamp_millis(millis) else {
                continue;
            };
            if !is_regular_session_minute(interval_start)
                || subscription_acknowledged_at > interval_start
                || health_started > interval_start
            {
                continue;
            }
            for symbol in &self.context_symbols {
                if self.target_symbols.contains(symbol)
                    || self.observed_intervals.contains(&(symbol.clone(), millis))
                    || self.unknown_intervals.contains(&(symbol.clone(), millis))
                    || self.emitted_absences.contains(&(symbol.clone(), millis))
                {
                    continue;
                }
                let (Some(mapping_at), Some(prior_trade)) = (
                    self.mapped_at.get(symbol).copied(),
                    self.prior_real_trade.get(symbol).copied(),
                ) else {
                    continue;
                };
                if mapping_at > interval_start || prior_trade >= interval_start {
                    continue;
                }
                let interval_end = interval_start + ChronoDuration::minutes(1);
                let reference = format!(
                    "EQUS.MINI:ohlcv-1m:end-of-interval:{}:{}",
                    interval_start.to_rfc3339(),
                    symbol
                );
                let observation = CausalMinuteObservation {
                    schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
                    symbol: symbol.clone(),
                    interval_start,
                    interval_end,
                    state: MinuteObservationState::CausallyInferredNoTrade,
                    evidence_available_at: Some(now),
                    evidence_source: Some(
                        "Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH"
                            .to_string(),
                    ),
                    evidence_reference: Some(reference),
                };
                let envelope = DatabentoCausalAbsenceEnvelope {
                    schema_version: DATABENTO_CAUSAL_ABSENCE_SCHEMA_VERSION.to_string(),
                    provider: "databento".to_string(),
                    dataset: "EQUS.MINI".to_string(),
                    provider_schema: "ohlcv-1m".to_string(),
                    received_at: now,
                    interval_start,
                    interval_end,
                    finalize_grace_ms,
                    subscription_acknowledged_at,
                    symbol_mapping_verified_at: mapping_at,
                    continuous_health_started_at: health_started,
                    continuous_health_observed_through: progress,
                    prior_real_trade_interval_start: prior_trade,
                    derivation: "CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH".to_string(),
                    observation,
                };
                if envelope.validate() {
                    self.emitted_absences.insert((symbol.clone(), millis));
                    output.push(envelope);
                }
            }
        }
        output
    }
}

fn initial_symbol_coverage(symbol: String) -> DatabentoSymbolCoverage {
    DatabentoSymbolCoverage {
        symbol,
        latest_observation_state: MinuteObservationState::UnknownMissing,
        latest_observed_interval_start: None,
        latest_observed_interval_end: None,
        latest_received_at: None,
        observed_trade_intervals: 0,
        causally_inferred_no_trade_intervals: 0,
        unknown_missing_intervals: 0,
        invalid_intervals_rejected: 0,
        duplicate_intervals_rejected: 0,
        out_of_order_intervals_rejected: 0,
        current_contiguous_observed_trade_intervals: 0,
        current_contiguous_eligible_context_intervals: 0,
        last_unknown_gap_start: None,
        last_unknown_gap_end: None,
    }
}

fn is_regular_session_minute(timestamp: DateTime<Utc>) -> bool {
    let local = timestamp.with_timezone(&New_York);
    let minute = local.hour() * 60 + local.minute();
    (570..960).contains(&minute)
}

fn refresh_context_coverage_blockers(
    status: &mut DatabentoLiveStatus,
    minimum_continuous_intervals: usize,
) {
    status.context_coverage_blockers = status
        .required_context_symbols
        .iter()
        .filter_map(|symbol| {
            let coverage = status.symbol_coverage.get(symbol)?;
            let v2 = status
                .context_observation_policy_schema_version
                .contains(".v2-");
            let contiguous = if v2 {
                coverage.current_contiguous_eligible_context_intervals
            } else {
                coverage.current_contiguous_observed_trade_intervals
            };
            if coverage.latest_observed_interval_start.is_none()
                && coverage.causally_inferred_no_trade_intervals == 0
            {
                Some(format!("{symbol}:AWAITING_FIRST_OBSERVED_TRADE_BAR"))
            } else if contiguous < minimum_continuous_intervals {
                Some(if v2 {
                    format!(
                        "{symbol}:INSUFFICIENT_CONTIGUOUS_ELIGIBLE_CONTEXT_INTERVALS:{}/{}",
                        contiguous, minimum_continuous_intervals
                    )
                } else {
                    format!(
                        "{symbol}:INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS:{}/{}",
                        contiguous, minimum_continuous_intervals
                    )
                })
            } else {
                None
            }
        })
        .collect();
}

fn update_symbol_coverage(
    status: &mut DatabentoLiveStatus,
    envelope: &DatabentoRealtimeBarEnvelope,
    minimum_continuous_intervals: usize,
) -> CoverageDisposition {
    let symbol = normalize_symbol(&envelope.bar.symbol);
    let coverage = status
        .symbol_coverage
        .entry(symbol.clone())
        .or_insert_with(|| initial_symbol_coverage(symbol.clone()));
    if let Some(latest_start) = coverage.latest_observed_interval_start {
        if envelope.bar_start == latest_start {
            coverage.duplicate_intervals_rejected += 1;
            refresh_context_coverage_blockers(status, minimum_continuous_intervals);
            return CoverageDisposition::DuplicateRejected;
        }
        if envelope.bar_start < latest_start {
            coverage.out_of_order_intervals_rejected += 1;
            refresh_context_coverage_blockers(status, minimum_continuous_intervals);
            return CoverageDisposition::OutOfOrderRejected;
        }
        let same_session = latest_start.with_timezone(&New_York).date_naive()
            == envelope.bar_start.with_timezone(&New_York).date_naive()
            && is_regular_session_minute(latest_start)
            && is_regular_session_minute(envelope.bar_start);
        let elapsed_minutes = envelope
            .bar_start
            .signed_duration_since(latest_start)
            .num_minutes();
        if same_session && elapsed_minutes > 1 {
            let unknown = (elapsed_minutes - 1) as u64;
            coverage.unknown_missing_intervals += unknown;
            coverage.last_unknown_gap_start = Some(latest_start + ChronoDuration::minutes(1));
            coverage.last_unknown_gap_end = Some(envelope.bar_start);
            coverage.current_contiguous_observed_trade_intervals = 1;
            coverage.current_contiguous_eligible_context_intervals = 1;
        } else if same_session && elapsed_minutes == 1 {
            coverage.current_contiguous_observed_trade_intervals += 1;
            coverage.current_contiguous_eligible_context_intervals += 1;
        } else {
            coverage.current_contiguous_observed_trade_intervals = 1;
            coverage.current_contiguous_eligible_context_intervals = 1;
        }
    } else {
        coverage.current_contiguous_observed_trade_intervals = 1;
        coverage.current_contiguous_eligible_context_intervals = 1;
    }
    coverage.latest_observation_state = MinuteObservationState::ObservedTradeBar;
    coverage.latest_observed_interval_start = Some(envelope.bar_start);
    coverage.latest_observed_interval_end = Some(envelope.bar_end);
    coverage.latest_received_at = Some(envelope.received_at);
    coverage.observed_trade_intervals += 1;
    refresh_context_coverage_blockers(status, minimum_continuous_intervals);
    CoverageDisposition::Accepted
}

fn quarantine_invalid_ohlcv_row(
    status: &mut DatabentoLiveStatus,
    symbol: &str,
    row: &OhlcvMsg,
    received_at: DateTime<Utc>,
    minimum_continuous_intervals: usize,
) {
    let symbol = normalize_symbol(symbol);
    let interval_start = utc_from_nanos(row.hd.ts_event).ok();
    let coverage = status
        .symbol_coverage
        .entry(symbol.clone())
        .or_insert_with(|| initial_symbol_coverage(symbol.clone()));
    coverage.invalid_intervals_rejected += 1;
    coverage.latest_received_at = Some(received_at);

    if interval_start.is_none_or(|rejected| {
        coverage
            .latest_observed_interval_start
            .is_none_or(|latest| rejected >= latest)
    }) {
        coverage.latest_observation_state = MinuteObservationState::UnknownMissing;
        coverage.current_contiguous_observed_trade_intervals = 0;
        coverage.current_contiguous_eligible_context_intervals = 0;
        if let Some(interval_start) = interval_start {
            let interval_end = interval_start + ChronoDuration::minutes(1);
            if coverage.last_unknown_gap_start != Some(interval_start)
                || coverage.last_unknown_gap_end != Some(interval_end)
            {
                coverage.unknown_missing_intervals += 1;
            }
            coverage.last_unknown_gap_start = Some(interval_start);
            coverage.last_unknown_gap_end = Some(interval_end);
        }
    }
    refresh_context_coverage_blockers(status, minimum_continuous_intervals);
}

fn record_causal_absence_coverage(
    status: &mut DatabentoLiveStatus,
    envelope: &DatabentoCausalAbsenceEnvelope,
    minimum_continuous_intervals: usize,
) {
    let symbol = normalize_symbol(&envelope.observation.symbol);
    let coverage = status
        .symbol_coverage
        .entry(symbol.clone())
        .or_insert_with(|| initial_symbol_coverage(symbol));
    coverage.latest_observation_state = MinuteObservationState::CausallyInferredNoTrade;
    coverage.latest_received_at = Some(envelope.received_at);
    coverage.causally_inferred_no_trade_intervals += 1;
    coverage.current_contiguous_observed_trade_intervals = 0;
    coverage.current_contiguous_eligible_context_intervals += 1;
    refresh_context_coverage_blockers(status, minimum_continuous_intervals);
}

fn record_late_trade_conflict(
    status: &mut DatabentoLiveStatus,
    symbol: &str,
    interval_start: DateTime<Utc>,
    minimum_continuous_intervals: usize,
) {
    let symbol = normalize_symbol(symbol);
    let coverage = status
        .symbol_coverage
        .entry(symbol.clone())
        .or_insert_with(|| initial_symbol_coverage(symbol.clone()));
    coverage.latest_observation_state = MinuteObservationState::UnknownMissing;
    coverage.unknown_missing_intervals += 1;
    coverage.current_contiguous_observed_trade_intervals = 0;
    coverage.current_contiguous_eligible_context_intervals = 0;
    coverage.last_unknown_gap_start = Some(interval_start);
    coverage.last_unknown_gap_end = Some(interval_start + ChronoDuration::minutes(1));
    status.blocker = Some(format!(
        "LATE_TRADE_CONFLICTS_WITH_CAUSAL_ABSENCE:{symbol}:{}",
        interval_start.to_rfc3339()
    ));
    refresh_context_coverage_blockers(status, minimum_continuous_intervals);
}

fn initial_status(
    request: &DataRequest,
    symbols: Vec<String>,
    live: &LiveConfig,
) -> DatabentoLiveStatus {
    let required_context_symbols = live
        .required_context_symbols
        .iter()
        .map(|symbol| normalize_symbol(symbol))
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let symbol_coverage = symbols
        .iter()
        .cloned()
        .map(|symbol| (symbol.clone(), initial_symbol_coverage(symbol)))
        .collect::<BTreeMap<_, _>>();
    let context_coverage_blockers = required_context_symbols
        .iter()
        .map(|symbol| format!("{symbol}:AWAITING_FIRST_OBSERVED_TRADE_BAR"))
        .collect();
    DatabentoLiveStatus {
        schema_version: DATABENTO_LIVE_STATUS_SCHEMA_VERSION.to_string(),
        updated_at: Utc::now(),
        provider: "databento".to_string(),
        dataset: request.dataset.clone(),
        schema: request.schema.clone(),
        state: "STARTING".to_string(),
        authenticated: false,
        entitlement_verified: false,
        realtime_required: live.require_realtime,
        replay_requested: false,
        subscribed_symbols: symbols,
        required_context_symbols,
        context_observation_policy_schema_version: live
            .context_observation_policy
            .schema_version
            .clone(),
        absence_semantics: "OHLCV_ABSENCE_BECOMES_CAUSALLY_INFERRED_NO_TRADE_ONLY_AFTER_END_OF_INTERVAL_PLUS_GRACE_WITH_PRE_INTERVAL_SUBSCRIPTION_MAPPING_CONTINUOUS_HEALTH_AND_PRIOR_REAL_TRADE;THIS_IS_AN_AXIO7_INFERENCE_NOT_A_VENDOR ASSERTION;ALL_OTHER_SILENCE_IS_UNKNOWN_MISSING".to_string(),
        causal_absence_inference_supported: true,
        symbol_coverage,
        context_coverage_blockers,
        last_heartbeat_at: None,
        last_provider_event_at: None,
        last_finalized_bar_at: None,
        finalized_bars: 0,
        symbol_mappings: 0,
        reconnects: 0,
        blocker: None,
        execution_enabled: false,
    }
}

struct StreamPaths<'a> {
    status: &'a Path,
    bars: &'a Path,
    context_observations: &'a Path,
}

struct OhlcvProcessingContext<'a, 'b> {
    request: &'a DataRequest,
    live: &'a LiveConfig,
    paths: &'a StreamPaths<'b>,
    inference_sender: Option<&'a tokio::sync::mpsc::Sender<DatabentoInferenceEvent>>,
}

fn dispatch_inference_event(
    sender: Option<&tokio::sync::mpsc::Sender<DatabentoInferenceEvent>>,
    event: DatabentoInferenceEvent,
) -> Result<()> {
    let Some(sender) = sender else {
        return Ok(());
    };
    sender.try_send(event).map_err(|error| {
        anyhow::anyhow!(
            "DATABENTO_INFERENCE_CHANNEL_UNAVAILABLE:{}",
            match error {
                tokio::sync::mpsc::error::TrySendError::Full(_) => "FULL",
                tokio::sync::mpsc::error::TrySendError::Closed(_) => "CLOSED",
            }
        )
    })
}

fn process_ohlcv_row(
    row: &OhlcvMsg,
    symbol: &str,
    context: &OhlcvProcessingContext<'_, '_>,
    status: &mut DatabentoLiveStatus,
    received_at: DateTime<Utc>,
) -> Result<OhlcvProcessingDisposition> {
    status.entitlement_verified = true;
    status.state = "STREAMING_REALTIME".to_string();
    status.last_provider_event_at = Some(received_at);
    let envelope = match normalize_bar(
        row,
        symbol,
        &context.request.dataset,
        received_at,
        context.live.stale_after_ms,
    ) {
        Ok(envelope) => envelope,
        Err(error) => {
            quarantine_invalid_ohlcv_row(
                status,
                symbol,
                row,
                received_at,
                context
                    .live
                    .context_observation_policy
                    .minimum_continuous_intervals,
            );
            let interval = utc_from_nanos(row.hd.ts_event)
                .map(|timestamp| timestamp.to_rfc3339())
                .unwrap_or_else(|_| "INVALID_TIMESTAMP".to_string());
            status.blocker = Some(format!(
                "INVALID_FINALIZED_BAR_REJECTED:{}:{interval}",
                normalize_symbol(symbol)
            ));
            status.updated_at = received_at;
            write_json_atomic(context.paths.status, status)?;
            tracing::warn!(
                reason = %error,
                symbol = %normalize_symbol(symbol),
                interval,
                "rejected one invalid Databento OHLCV row without restarting the feed"
            );
            return Ok(OhlcvProcessingDisposition::InvalidRejected);
        }
    };
    if context.live.require_realtime && envelope.stale {
        status.blocker = Some("STALE_DATABENTO_BAR_REJECTED".to_string());
        status.updated_at = received_at;
        write_json_atomic(context.paths.status, status)?;
        return Ok(OhlcvProcessingDisposition::StaleRejected);
    }

    let disposition = match update_symbol_coverage(
        status,
        &envelope,
        context
            .live
            .context_observation_policy
            .minimum_continuous_intervals,
    ) {
        CoverageDisposition::Accepted => {
            crate::live::append_jsonl_rotating(
                context.paths.bars,
                &envelope,
                context.live.raw_log_max_bytes,
                context.live.raw_log_archive_count,
            )?;
            dispatch_inference_event(
                context.inference_sender,
                DatabentoInferenceEvent::TradeBar {
                    envelope: envelope.clone(),
                },
            )?;
            status.last_finalized_bar_at = Some(envelope.bar_end);
            status.finalized_bars += 1;
            status.blocker = None;
            OhlcvProcessingDisposition::Accepted
        }
        CoverageDisposition::DuplicateRejected => {
            status.blocker = Some(format!(
                "DUPLICATE_FINALIZED_BAR_REJECTED:{}:{}",
                envelope.bar.symbol,
                envelope.bar_start.to_rfc3339()
            ));
            OhlcvProcessingDisposition::DuplicateRejected
        }
        CoverageDisposition::OutOfOrderRejected => {
            status.blocker = Some(format!(
                "OUT_OF_ORDER_FINALIZED_BAR_REJECTED:{}:{}",
                envelope.bar.symbol,
                envelope.bar_start.to_rfc3339()
            ));
            OhlcvProcessingDisposition::OutOfOrderRejected
        }
    };
    status.updated_at = received_at;
    write_json_atomic(context.paths.status, status)?;
    Ok(disposition)
}

async fn stream_once(
    request: &DataRequest,
    live: &LiveConfig,
    paths: &StreamPaths<'_>,
    status: &mut DatabentoLiveStatus,
    inference_sender: Option<&tokio::sync::mpsc::Sender<DatabentoInferenceEvent>>,
) -> Result<()> {
    let mut client = LiveClient::builder()
        .key_from_env()
        .context("missing or invalid DATABENTO_API_KEY")?
        .dataset(request.dataset.as_str())
        .heartbeat_interval(TimeDuration::seconds(5))
        .build()
        .await
        .context("authenticate Databento Live session")?;
    status.authenticated = true;
    status.state = "CONNECTED_AUTHENTICATED".to_string();
    status.blocker = None;
    status.updated_at = Utc::now();
    write_json_atomic(paths.status, status)?;

    client
        .subscribe(
            Subscription::builder()
                .symbols(status.subscribed_symbols.clone())
                .schema(Schema::Ohlcv1M)
                .stype_in(SType::RawSymbol)
                .build(),
        )
        .await
        .context("submit Databento EQUS.MINI subscription")?;
    let metadata = client
        .start()
        .await
        .context("start Databento Live session")?;
    if !metadata.dataset.eq_ignore_ascii_case(&request.dataset) {
        bail!(
            "Databento metadata dataset mismatch: expected {}, received {}",
            request.dataset,
            metadata.dataset
        );
    }
    status.state = "STREAMING_AWAITING_SUBSCRIPTION_ACK".to_string();
    status.updated_at = Utc::now();
    write_json_atomic(paths.status, status)?;

    let mut symbol_map = PitSymbolMap::new();
    let processing_context = OhlcvProcessingContext {
        request,
        live,
        paths,
        inference_sender,
    };
    let mut absence_tracker = CausalAbsenceTracker::new(live);
    loop {
        let record = tokio::time::timeout(Duration::from_secs(7), client.next_record())
            .await
            .context("Databento live connection made no progress within heartbeat deadline")??
            .context("Databento Live gateway closed the stream")?;
        let received_at = Utc::now();
        absence_tracker.record_progress(received_at);
        if let Some(error) = record.get::<ErrorMsg>() {
            bail!(
                "Databento Live rejected the session: {}",
                error.err().unwrap_or("provider error")
            );
        }
        if let Some(system) = record.get::<SystemMsg>() {
            if system.is_heartbeat() {
                status.last_heartbeat_at = Some(received_at);
            } else if system.code().ok() == Some(SystemCode::SubscriptionAck) {
                status.entitlement_verified = true;
                status.state = "STREAMING_REALTIME".to_string();
                status.blocker = None;
                absence_tracker.acknowledge_subscription(received_at);
            } else if system.code().ok() == Some(SystemCode::SlowReaderWarning) {
                bail!("Databento slow-reader warning invalidated continuous stream health");
            } else if system.code().ok() == Some(SystemCode::EndOfInterval) {
                absence_tracker.record_end_of_interval(utc_from_nanos(system.hd.ts_event)?);
            }
            status.updated_at = received_at;
            write_json_atomic(paths.status, status)?;
        }
        if let Some(mapping) = record.get::<SymbolMappingMsg>() {
            status.symbol_mappings += 1;
            absence_tracker.record_mapping(mapping.stype_in_symbol()?, received_at);
        }
        if let Some(row) = record.get::<OhlcvMsg>() {
            let symbol = symbol_map
                .get_for_rec(row)
                .cloned()
                .context("Databento OHLCV record arrived without a point-in-time symbol mapping")?;
            // Databento can publish a completed aggregate a few hundred
            // milliseconds before this host's nominal interval boundary when
            // the workstation clock trails the provider clock. Hold only
            // bounded early arrivals through the local bar end so downstream
            // inference remains causal. Larger future timestamps still fail
            // closed in normalize_bar.
            let mut causal_received_at = received_at;
            if let Some(delay) = early_bar_finalize_delay(row, received_at, live.stale_after_ms)? {
                tokio::time::sleep(delay).await;
                causal_received_at = Utc::now();
            }
            let disposition = process_ohlcv_row(
                row,
                &symbol,
                &processing_context,
                status,
                causal_received_at,
            )?;
            if disposition == OhlcvProcessingDisposition::Accepted {
                let interval_start = utc_from_nanos(row.hd.ts_event)?;
                if absence_tracker.record_trade(&symbol, interval_start) {
                    record_late_trade_conflict(
                        status,
                        &symbol,
                        interval_start,
                        live.context_observation_policy.minimum_continuous_intervals,
                    );
                    status.updated_at = received_at;
                    write_json_atomic(paths.status, status)?;
                }
            } else if let Ok(interval_start) = utc_from_nanos(row.hd.ts_event) {
                absence_tracker.record_unknown(&symbol, interval_start);
            }
        }
        symbol_map.on_record(record)?;
        for envelope in absence_tracker.finalize_ready(received_at, live.finalize_grace_ms) {
            crate::live::append_jsonl_rotating(
                paths.context_observations,
                &envelope,
                live.raw_log_max_bytes,
                live.raw_log_archive_count,
            )?;
            record_causal_absence_coverage(
                status,
                &envelope,
                live.context_observation_policy.minimum_continuous_intervals,
            );
            dispatch_inference_event(
                inference_sender,
                DatabentoInferenceEvent::ContextObservation {
                    envelope: envelope.clone(),
                },
            )?;
            status.updated_at = received_at;
            write_json_atomic(paths.status, status)?;
        }
    }
}

/// Runs the fail-closed Databento live supervisor until the process exits.
pub async fn run_equities_stream(
    data: &DataConfig,
    live: &LiveConfig,
    status_output: PathBuf,
    bars_output: PathBuf,
    inference_sender: Option<tokio::sync::mpsc::Sender<DatabentoInferenceEvent>>,
) -> Result<()> {
    if !live.provider.eq_ignore_ascii_case("databento") {
        bail!("run_equities_stream requires live.provider=databento");
    }
    if !data.databento.enabled {
        bail!("Databento data configuration is disabled");
    }
    let request = configured_live_request(data)?.clone();
    let symbols = live
        .symbols
        .iter()
        .map(|symbol| normalize_symbol(symbol))
        .filter(|symbol| !symbol.is_empty())
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    if symbols.is_empty() {
        bail!("Databento live stream requires at least one symbol");
    }
    let configured = request
        .symbols
        .iter()
        .map(|symbol| normalize_symbol(symbol))
        .collect::<std::collections::BTreeSet<_>>();
    if symbols.iter().any(|symbol| !configured.contains(symbol)) {
        bail!("Databento live symbols must be a subset of the audited EQUS.MINI request");
    }

    let mut status = initial_status(&request, symbols, live);
    write_json_atomic(&status_output, &status)?;
    let context_observations_output =
        bars_output.with_file_name("databento_context_observations.jsonl");
    let paths = StreamPaths {
        status: &status_output,
        bars: &bars_output,
        context_observations: &context_observations_output,
    };
    let mut reconnect_ms = live.reconnect_min_ms;
    loop {
        match stream_once(
            &request,
            live,
            &paths,
            &mut status,
            inference_sender.as_ref(),
        )
        .await
        {
            Ok(()) => unreachable!("Databento stream loop exits only through an error"),
            Err(error) => {
                status.authenticated = false;
                status.entitlement_verified = false;
                status.state = "FAIL_CLOSED_RECONNECTING".to_string();
                status.blocker = Some(redact_error(&error));
                status.reconnects += 1;
                status.updated_at = Utc::now();
                write_json_atomic(&status_output, &status)?;
                tracing::error!(
                    error = %status.blocker.as_deref().unwrap_or("Databento stream error"),
                    "Databento Live stream failed closed; reconnecting"
                );
            }
        }
        tokio::time::sleep(Duration::from_millis(reconnect_ms)).await;
        reconnect_ms = reconnect_ms.saturating_mul(2).min(live.reconnect_max_ms);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use databento::dbn::{RecordHeader, rtype};

    #[test]
    fn strips_only_the_provider_prefix_from_symbols() {
        assert_eq!(normalize_symbol("US.NVDA"), "NVDA");
        assert_eq!(normalize_symbol("SPY"), "SPY");
    }

    #[test]
    fn normalizes_a_fresh_completed_minute_bar() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 200_000_000_000,
            high: 201_000_000_000,
            low: 199_500_000_000,
            close: 200_500_000_000,
            volume: 1_250,
        };
        let received = start + chrono::Duration::minutes(1) + chrono::Duration::seconds(1);
        let envelope = normalize_bar(&row, "NVDA", "EQUS.MINI", received, 10_000).unwrap();
        assert_eq!(envelope.bar.close, 200.5);
        assert_eq!(envelope.bar.symbol, "NVDA");
        assert!(!envelope.stale);
        assert!(!envelope.replay);
        assert_eq!(envelope.entitlement, "REALTIME_SUBSCRIPTION_ACKNOWLEDGED");
        assert!(envelope.causal_observation().validate());
    }

    #[test]
    fn delays_only_small_early_arrivals_until_the_bar_is_complete() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 200_000_000_000,
            high: 201_000_000_000,
            low: 199_500_000_000,
            close: 200_500_000_000,
            volume: 1_250,
        };

        let small_skew = start + ChronoDuration::milliseconds(59_700);
        let delay = early_bar_finalize_delay(&row, small_skew, 2_000)
            .unwrap()
            .unwrap();
        assert_eq!(delay, Duration::from_millis(300));

        let excessive_skew = start + ChronoDuration::seconds(55);
        assert!(
            early_bar_finalize_delay(&row, excessive_skew, 2_000)
                .unwrap()
                .is_none()
        );

        let after_bar_end = start + ChronoDuration::seconds(61);
        assert!(
            early_bar_finalize_delay(&row, after_bar_end, 2_000)
                .unwrap()
                .is_none()
        );
    }

    #[test]
    fn rejects_zero_volume_ohlcv_as_unproven_trade_or_no_trade_evidence() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 200_000_000_000,
            high: 201_000_000_000,
            low: 199_500_000_000,
            close: 200_500_000_000,
            volume: 0,
        };
        let received = start + chrono::Duration::minutes(1) + chrono::Duration::seconds(1);
        assert!(
            normalize_bar(&row, "UUP", "EQUS.MINI", received, 10_000)
                .unwrap_err()
                .to_string()
                .contains("not positive-volume observed-trade evidence")
        );
    }

    fn causal_tracker_live(context: &[&str], targets: &[&str]) -> LiveConfig {
        LiveConfig {
            required_context_symbols: context.iter().map(|value| value.to_string()).collect(),
            forecast_symbols: targets.iter().map(|value| value.to_string()).collect(),
            finalize_grace_ms: 2_000,
            ..LiveConfig::default()
        }
    }

    #[test]
    fn healthy_mapped_absence_after_end_of_interval_and_grace_is_causal_not_vendor_proof() {
        let interval = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let mut tracker = CausalAbsenceTracker::new(&causal_tracker_live(&["UUP"], &["SPY"]));
        tracker.acknowledge_subscription(interval - ChronoDuration::minutes(1));
        tracker.record_mapping("UUP", interval - ChronoDuration::seconds(30));
        tracker.record_trade("UUP", interval - ChronoDuration::minutes(1));
        tracker.record_end_of_interval(interval);
        tracker.record_progress(interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2));

        let output = tracker.finalize_ready(
            interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2),
            2_000,
        );

        assert_eq!(output.len(), 1);
        assert!(output[0].validate());
        assert_eq!(
            output[0].observation.state,
            MinuteObservationState::CausallyInferredNoTrade
        );
        assert_eq!(
            output[0].derivation,
            "CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH"
        );
    }

    #[test]
    fn reconnect_mapping_after_interval_start_and_missing_anchor_remain_unknown() {
        let interval = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let mut reconnected = CausalAbsenceTracker::new(&causal_tracker_live(&["UUP"], &["SPY"]));
        reconnected.acknowledge_subscription(interval + ChronoDuration::seconds(1));
        reconnected.record_mapping("UUP", interval + ChronoDuration::seconds(1));
        reconnected.record_end_of_interval(interval);
        reconnected
            .record_progress(interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2));
        assert!(
            reconnected
                .finalize_ready(
                    interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2),
                    2_000,
                )
                .is_empty()
        );

        let mut no_anchor = CausalAbsenceTracker::new(&causal_tracker_live(&["UUP"], &["SPY"]));
        no_anchor.acknowledge_subscription(interval - ChronoDuration::minutes(1));
        no_anchor.record_mapping("UUP", interval - ChronoDuration::seconds(30));
        no_anchor.record_end_of_interval(interval);
        no_anchor
            .record_progress(interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2));
        assert!(
            no_anchor
                .finalize_ready(
                    interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2),
                    2_000,
                )
                .is_empty()
        );
    }

    #[test]
    fn target_absence_and_unclosed_unknown_interval_are_never_synthesized() {
        let interval = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let mut tracker = CausalAbsenceTracker::new(&causal_tracker_live(&["QQQ"], &["QQQ"]));
        tracker.acknowledge_subscription(interval - ChronoDuration::minutes(1));
        tracker.record_mapping("QQQ", interval - ChronoDuration::seconds(30));
        tracker.record_trade("QQQ", interval - ChronoDuration::minutes(1));
        tracker.record_progress(interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2));
        assert!(
            tracker
                .finalize_ready(
                    interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2),
                    2_000,
                )
                .is_empty(),
            "no end-of-interval marker means unknown, and targets are always excluded"
        );
    }

    #[test]
    fn a_late_real_trade_conflicts_with_emitted_causal_absence() {
        let interval = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let mut tracker = CausalAbsenceTracker::new(&causal_tracker_live(&["UUP"], &["SPY"]));
        tracker.acknowledge_subscription(interval - ChronoDuration::minutes(1));
        tracker.record_mapping("UUP", interval - ChronoDuration::seconds(30));
        tracker.record_trade("UUP", interval - ChronoDuration::minutes(1));
        tracker.record_end_of_interval(interval);
        tracker.record_progress(interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2));
        assert_eq!(
            tracker
                .finalize_ready(
                    interval + ChronoDuration::minutes(1) + ChronoDuration::seconds(2),
                    2_000,
                )
                .len(),
            1
        );
        assert!(tracker.record_trade("UUP", interval));
    }

    #[tokio::test]
    async fn quarantines_invalid_row_and_dispatches_the_following_valid_row() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let mut invalid = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 20_000_000_000,
            high: 20_100_000_000,
            low: 19_900_000_000,
            close: 20_050_000_000,
            volume: 0,
        };
        let request = DataRequest {
            name: "live".to_string(),
            dataset: "EQUS.MINI".to_string(),
            schema: "ohlcv-1m".to_string(),
            stype_in: "raw_symbol".to_string(),
            symbols: vec!["UUP".to_string()],
            start: "2026-01-01".to_string(),
            end: "2026-12-31".to_string(),
        };
        let live = LiveConfig {
            required_context_symbols: vec!["UUP".to_string()],
            ..LiveConfig::default()
        };
        let mut status = initial_status(&request, vec!["UUP".to_string()], &live);
        let directory = tempfile::tempdir().unwrap();
        let status_path = directory.path().join("status.json");
        let bars_path = directory.path().join("bars.jsonl");
        let context_path = directory.path().join("context.jsonl");
        let paths = StreamPaths {
            status: &status_path,
            bars: &bars_path,
            context_observations: &context_path,
        };
        let (sender, mut receiver) = tokio::sync::mpsc::channel(1);
        let processing_context = OhlcvProcessingContext {
            request: &request,
            live: &live,
            paths: &paths,
            inference_sender: Some(&sender),
        };
        let invalid_received = start + ChronoDuration::minutes(1) + ChronoDuration::seconds(1);

        assert_eq!(
            process_ohlcv_row(
                &invalid,
                "UUP",
                &processing_context,
                &mut status,
                invalid_received,
            )
            .unwrap(),
            OhlcvProcessingDisposition::InvalidRejected
        );
        assert!(matches!(
            receiver.try_recv(),
            Err(tokio::sync::mpsc::error::TryRecvError::Empty)
        ));
        assert_eq!(status.symbol_coverage["UUP"].invalid_intervals_rejected, 1);
        assert_eq!(status.symbol_coverage["UUP"].unknown_missing_intervals, 1);
        assert_eq!(
            status.symbol_coverage["UUP"].latest_observation_state,
            MinuteObservationState::UnknownMissing
        );
        assert_eq!(status.finalized_bars, 0);
        assert!(!bars_path.exists());

        let valid_start = start + ChronoDuration::minutes(1);
        invalid.hd.ts_event = valid_start.timestamp_nanos_opt().unwrap() as u64;
        invalid.volume = 100;
        let valid_received = valid_start + ChronoDuration::minutes(1) + ChronoDuration::seconds(1);
        assert_eq!(
            process_ohlcv_row(
                &invalid,
                "UUP",
                &processing_context,
                &mut status,
                valid_received,
            )
            .unwrap(),
            OhlcvProcessingDisposition::Accepted
        );
        let dispatched = receiver.recv().await.unwrap();
        let DatabentoInferenceEvent::TradeBar {
            envelope: dispatched,
        } = dispatched
        else {
            panic!("expected trade-bar event");
        };
        assert_eq!(dispatched.bar.symbol, "UUP");
        assert_eq!(dispatched.bar_start, valid_start);
        assert_eq!(status.symbol_coverage["UUP"].observed_trade_intervals, 1);
        assert_eq!(
            status.symbol_coverage["UUP"].latest_observation_state,
            MinuteObservationState::ObservedTradeBar
        );
        assert_eq!(status.finalized_bars, 1);
        assert!(status.blocker.is_none());
        assert_eq!(
            std::fs::read_to_string(&bars_path).unwrap().lines().count(),
            1
        );
    }

    #[test]
    fn coverage_reports_unknown_gaps_and_rejects_duplicates() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 20_000_000_000,
            high: 20_100_000_000,
            low: 19_900_000_000,
            close: 20_050_000_000,
            volume: 100,
        };
        let first_received = start + ChronoDuration::minutes(1) + ChronoDuration::seconds(1);
        let first = normalize_bar(&row, "UUP", "EQUS.MINI", first_received, 10_000).unwrap();
        let request = DataRequest {
            name: "live".to_string(),
            dataset: "EQUS.MINI".to_string(),
            schema: "ohlcv-1m".to_string(),
            stype_in: "raw_symbol".to_string(),
            symbols: vec!["UUP".to_string()],
            start: "2026-01-01".to_string(),
            end: "2026-12-31".to_string(),
        };
        let live = LiveConfig {
            required_context_symbols: vec!["UUP".to_string()],
            ..LiveConfig::default()
        };
        let mut status = initial_status(&request, vec!["UUP".to_string()], &live);
        assert_eq!(
            update_symbol_coverage(&mut status, &first, 6),
            CoverageDisposition::Accepted
        );

        let mut third = first.clone();
        third.bar_start += ChronoDuration::minutes(2);
        third.bar_end += ChronoDuration::minutes(2);
        third.bar.timestamp += ChronoDuration::minutes(2);
        third.received_at += ChronoDuration::minutes(2);
        third.provider_available_at += ChronoDuration::minutes(2);
        third.finalized_at += ChronoDuration::minutes(2);
        assert_eq!(
            update_symbol_coverage(&mut status, &third, 6),
            CoverageDisposition::Accepted
        );
        let coverage = &status.symbol_coverage["UUP"];
        assert_eq!(coverage.unknown_missing_intervals, 1);
        assert_eq!(coverage.current_contiguous_observed_trade_intervals, 1);
        assert_eq!(
            coverage.last_unknown_gap_start,
            Some(start + ChronoDuration::minutes(1))
        );

        assert_eq!(
            update_symbol_coverage(&mut status, &third, 6),
            CoverageDisposition::DuplicateRejected
        );
        assert_eq!(
            status.symbol_coverage["UUP"].duplicate_intervals_rejected,
            1
        );
        assert!(
            status.context_coverage_blockers[0]
                .contains("INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS:1/6")
        );
    }

    #[test]
    fn marks_late_or_future_availability_as_stale() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 200_000_000_000,
            high: 201_000_000_000,
            low: 199_500_000_000,
            close: 200_500_000_000,
            volume: 1_250,
        };
        let received = start + chrono::Duration::minutes(2);
        assert!(
            normalize_bar(&row, "NVDA", "EQUS.MINI", received, 10_000)
                .unwrap()
                .stale
        );
    }

    #[tokio::test]
    async fn sends_each_accepted_envelope_to_the_bounded_inference_channel() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 200_000_000_000,
            high: 201_000_000_000,
            low: 199_500_000_000,
            close: 200_500_000_000,
            volume: 1_250,
        };
        let received = start + chrono::Duration::minutes(1) + chrono::Duration::seconds(1);
        let envelope = normalize_bar(&row, "NVDA", "EQUS.MINI", received, 10_000).unwrap();
        let (sender, mut receiver) = tokio::sync::mpsc::channel(1);
        dispatch_inference_event(
            Some(&sender),
            DatabentoInferenceEvent::TradeBar {
                envelope: envelope.clone(),
            },
        )
        .unwrap();
        let DatabentoInferenceEvent::TradeBar { envelope: received } =
            receiver.recv().await.unwrap()
        else {
            panic!("expected trade bar");
        };
        assert_eq!(received.bar.symbol, envelope.bar.symbol);
    }

    #[test]
    fn fails_closed_when_the_inference_channel_is_full_or_closed() {
        let start = DateTime::parse_from_rfc3339("2026-07-24T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let row = OhlcvMsg {
            hd: RecordHeader::new::<OhlcvMsg>(
                rtype::OHLCV_1M,
                1,
                42,
                start.timestamp_nanos_opt().unwrap() as u64,
            ),
            open: 200_000_000_000,
            high: 201_000_000_000,
            low: 199_500_000_000,
            close: 200_500_000_000,
            volume: 1_250,
        };
        let received = start + chrono::Duration::minutes(1) + chrono::Duration::seconds(1);
        let envelope = normalize_bar(&row, "NVDA", "EQUS.MINI", received, 10_000).unwrap();
        let (sender, receiver) = tokio::sync::mpsc::channel(1);
        sender
            .try_send(DatabentoInferenceEvent::TradeBar {
                envelope: envelope.clone(),
            })
            .unwrap();
        assert!(
            dispatch_inference_event(
                Some(&sender),
                DatabentoInferenceEvent::TradeBar {
                    envelope: envelope.clone(),
                },
            )
            .unwrap_err()
            .to_string()
            .ends_with(":FULL")
        );
        drop(receiver);
        assert!(
            dispatch_inference_event(
                Some(&sender),
                DatabentoInferenceEvent::TradeBar { envelope },
            )
            .unwrap_err()
            .to_string()
            .ends_with(":CLOSED")
        );
    }
}
