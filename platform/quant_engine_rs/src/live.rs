use std::{
    collections::{BTreeMap, BTreeSet, HashSet},
    fs::{self, OpenOptions},
    io::{BufRead, BufReader, Write},
    net::{IpAddr, SocketAddr, TcpStream},
    path::{Path, PathBuf},
    str::FromStr,
    time::Duration as StdDuration,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, NaiveDateTime, TimeZone, Utc};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::{
    config::LiveConfig,
    domain::MarketBar,
    prediction_ledger::{ForecastSettlement, PredictionLedger, settlement_content_hash},
};

pub const PROVIDER: &str = "MOOMOO_OPEND";
pub const MARKET_COVERAGE: &str = "NASDAQ_BASIC_TOTALVIEW_PLUS_ARCABOOK";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SdkKlineEvent {
    pub event: String,
    pub symbol: String,
    pub event_timestamp_et: String,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub turnover: Option<f64>,
    pub source_version: String,
}

pub fn parse_sdk_kline(line: &str, received_at: DateTime<Utc>) -> Result<Option<LiveBarUpdate>> {
    let event: serde_json::Value = match serde_json::from_str(line) {
        Ok(value) => value,
        Err(_) => return Ok(None),
    };
    if event.get("event").and_then(|value| value.as_str()) != Some("k_1m") {
        return Ok(None);
    }
    let row: SdkKlineEvent = serde_json::from_value(event)?;
    let local = NaiveDateTime::parse_from_str(&row.event_timestamp_et, "%Y-%m-%d %H:%M:%S")
        .with_context(|| {
            format!(
                "invalid Moomoo exchange timestamp {}",
                row.event_timestamp_et
            )
        })?;
    // The official Moomoo bridge labels K_1M with the bucket end. The first
    // 09:30 bucket is therefore reported as 09:31:00 and can be pushed while
    // it is still forming. Treating that label as a bar start both shifts the
    // market state by one minute and falsely makes a valid update look like a
    // future event.
    let bar_end = New_York
        .from_local_datetime(&local)
        .single()
        .context("ambiguous/nonexistent New York timestamp from Moomoo")?
        .with_timezone(&Utc);
    let bar_start = bar_end - Duration::minutes(1);
    let raw_payload_hash = payload_hash(line.as_bytes());
    Ok(Some(LiveBarUpdate {
        symbol: row.symbol,
        // The raw provider bucket label remains in the immutable JSONL. This
        // timestamp records when this particular forming-bar update arrived.
        event_timestamp: received_at,
        receive_timestamp: received_at,
        available_timestamp: received_at,
        bar_start,
        bar_end,
        open: row.open,
        high: row.high,
        low: row.low,
        close: row.close,
        volume: row.volume,
        turnover: row.turnover,
        session: "regular_or_extended_as_reported_by_opend".into(),
        source_version: row.source_version,
        subscription_id: "MOOMOO_US_BASIC_TICKER_K1M".into(),
        sequence_or_dedup_key: raw_payload_hash.clone(),
        is_cached_push: bar_end + Duration::minutes(1) < received_at,
        is_replay: false,
        raw_payload_hash,
    }))
}

fn parse_sdk_kline_replay(line: &str) -> Result<Option<LiveBarUpdate>> {
    let event: serde_json::Value = match serde_json::from_str(line) {
        Ok(value) => value,
        Err(_) => return Ok(None),
    };
    if event.get("event").and_then(|value| value.as_str()) != Some("k_1m") {
        return Ok(None);
    }
    let row: SdkKlineEvent = serde_json::from_value(event)?;
    let local = NaiveDateTime::parse_from_str(&row.event_timestamp_et, "%Y-%m-%d %H:%M:%S")
        .with_context(|| {
            format!(
                "invalid Moomoo replay exchange timestamp {}",
                row.event_timestamp_et
            )
        })?;
    let replay_available_at = New_York
        .from_local_datetime(&local)
        .single()
        .context("ambiguous/nonexistent New York replay timestamp from Moomoo")?
        .with_timezone(&Utc);
    let mut update = parse_sdk_kline(line, replay_available_at)?
        .context("Moomoo replay K_1M event did not produce a bar update")?;
    // Raw bridge archives predate receipt-clock persistence. In deterministic
    // replay, make the bar usable only at its provider-labelled bucket end.
    update.event_timestamp = update.bar_start;
    update.receive_timestamp = update.bar_start;
    update.available_timestamp = update.bar_end;
    update.is_cached_push = false;
    update.is_replay = true;
    Ok(Some(update))
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LiveBarUpdate {
    pub symbol: String,
    pub event_timestamp: DateTime<Utc>,
    pub receive_timestamp: DateTime<Utc>,
    pub available_timestamp: DateTime<Utc>,
    pub bar_start: DateTime<Utc>,
    pub bar_end: DateTime<Utc>,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub turnover: Option<f64>,
    pub session: String,
    pub source_version: String,
    pub subscription_id: String,
    pub sequence_or_dedup_key: String,
    pub is_cached_push: bool,
    pub is_replay: bool,
    pub raw_payload_hash: String,
}

impl LiveBarUpdate {
    pub fn validate(&self) -> bool {
        self.symbol.starts_with("US.")
            && self.bar_end == self.bar_start + Duration::minutes(1)
            && self.event_timestamp <= self.receive_timestamp
            && self.receive_timestamp <= self.available_timestamp
            && self.open > 0.0
            && self.low > 0.0
            && self.high >= self.open.max(self.close)
            && self.low <= self.open.min(self.close)
            && self.volume >= 0.0
            && !self.raw_payload_hash.is_empty()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FinalizedLiveBar {
    #[serde(flatten)]
    pub update: LiveBarUpdate,
    pub finalized_timestamp: DateTime<Utc>,
    pub is_final: bool,
    pub gap_status: String,
    pub correction_of: Option<String>,
}

impl FinalizedLiveBar {
    pub fn as_market_bar(&self) -> MarketBar {
        MarketBar {
            timestamp: self.update.bar_start,
            symbol: self.update.symbol.trim_start_matches("US.").to_string(),
            open: self.update.open,
            high: self.update.high,
            low: self.update.low,
            close: self.update.close,
            volume: self.update.volume,
            vwap: None,
            bid: None,
            ask: None,
            trade_count: None,
            source: PROVIDER.into(),
            data_quality: match self.gap_status.as_str() {
                "GAPPED" => "gapped_finalized".into(),
                "STALE_OR_CACHED" => "stale_or_cached_finalized".into(),
                "GAPPED_AND_STALE" => "gapped_and_stale_finalized".into(),
                "COMPLETE" if self.update.is_replay => "deterministic_replay".into(),
                "COMPLETE" => "realtime_finalized".into(),
                _ => "invalid_finalization_status".into(),
            },
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LiveGapRecord {
    pub gap_id: String,
    pub symbol: String,
    pub expected: DateTime<Utc>,
    pub observed: DateTime<Utc>,
    pub detected_at: DateTime<Utc>,
    pub missing_minutes: i64,
    pub status: String,
}

impl LiveGapRecord {
    fn new(
        symbol: &str,
        expected: DateTime<Utc>,
        observed: DateTime<Utc>,
        detected_at: DateTime<Utc>,
    ) -> Self {
        let identity = format!(
            "{}|{}|{}",
            symbol,
            expected.to_rfc3339(),
            observed.to_rfc3339()
        );
        Self {
            gap_id: payload_hash(identity.as_bytes()),
            symbol: symbol.into(),
            expected,
            observed,
            detected_at,
            missing_minutes: (observed - expected).num_minutes().max(0),
            status: "MISSING_MINUTE_INTERVAL".into(),
        }
    }
}

#[derive(Debug)]
pub struct MinuteBarFinalizer {
    working: BTreeMap<String, LiveBarUpdate>,
    seen_payloads: HashSet<String>,
    finalized_keys: BTreeSet<(String, DateTime<Utc>)>,
    last_finalized_end: BTreeMap<String, DateTime<Utc>>,
    gapped_before: BTreeSet<(String, DateTime<Utc>)>,
    gap_ids: BTreeSet<String>,
    stale_after_ms: i64,
    pub gaps: Vec<LiveGapRecord>,
    pub corrections: Vec<FinalizedLiveBar>,
}

impl Default for MinuteBarFinalizer {
    fn default() -> Self {
        Self::new(10_000).expect("positive default stale threshold")
    }
}

impl MinuteBarFinalizer {
    pub fn new(stale_after_ms: i64) -> Result<Self> {
        if stale_after_ms <= 0 {
            bail!("live stale_after_ms must be positive");
        }
        Ok(Self {
            working: BTreeMap::new(),
            seen_payloads: HashSet::new(),
            finalized_keys: BTreeSet::new(),
            last_finalized_end: BTreeMap::new(),
            gapped_before: BTreeSet::new(),
            gap_ids: BTreeSet::new(),
            stale_after_ms,
            gaps: Vec::new(),
            corrections: Vec::new(),
        })
    }

    pub fn ingest(&mut self, update: LiveBarUpdate) -> Result<Vec<FinalizedLiveBar>> {
        if !update.validate() {
            bail!("invalid Moomoo K_1M update");
        }
        if !self.seen_payloads.insert(update.raw_payload_hash.clone()) {
            return Ok(Vec::new());
        }
        let key = (update.symbol.clone(), update.bar_start);
        if self.finalized_keys.contains(&key) {
            let correction = FinalizedLiveBar {
                update,
                finalized_timestamp: Utc::now(),
                is_final: false,
                gap_status: "LATE_CORRECTION_NOT_APPLIED".into(),
                correction_of: Some(format!("{}@{}", key.0, key.1)),
            };
            self.corrections.push(correction);
            return Ok(Vec::new());
        }

        if !self.working.contains_key(&update.symbol)
            && let Some(previous_end) = self.last_finalized_end.get(&update.symbol).copied()
            && update.bar_start > previous_end
        {
            self.record_gap(
                &update.symbol,
                previous_end,
                update.bar_start,
                update.receive_timestamp,
            );
            self.gapped_before.insert(key.clone());
        }

        let mut output = Vec::new();
        if let Some(previous) = self.working.get(&update.symbol).cloned() {
            if update.bar_start == previous.bar_start {
                self.working.insert(update.symbol.clone(), update);
                return Ok(output);
            }
            if update.bar_start < previous.bar_start {
                self.corrections.push(FinalizedLiveBar {
                    update,
                    finalized_timestamp: Utc::now(),
                    is_final: false,
                    gap_status: "OUT_OF_ORDER_NOT_APPLIED".into(),
                    correction_of: None,
                });
                return Ok(output);
            }
            if update.bar_start > previous.bar_end {
                self.record_gap(
                    &update.symbol,
                    previous.bar_end,
                    update.bar_start,
                    update.receive_timestamp,
                );
                self.gapped_before.insert(key.clone());
            }
            let previous_key = (previous.symbol.clone(), previous.bar_start);
            let gap_before = self.gapped_before.remove(&previous_key);
            output.push(self.finalize(previous, update.receive_timestamp, gap_before));
        }
        self.working.insert(update.symbol.clone(), update);
        Ok(output)
    }

    pub fn finalize_due(&mut self, now: DateTime<Utc>, grace_ms: i64) -> Vec<FinalizedLiveBar> {
        let due = self
            .working
            .iter()
            .filter(|(_, row)| now >= row.bar_end + Duration::milliseconds(grace_ms))
            .map(|(symbol, _)| symbol.clone())
            .collect::<Vec<_>>();
        let mut finalized = Vec::new();
        for symbol in due {
            if let Some(row) = self.working.remove(&symbol) {
                let key = (row.symbol.clone(), row.bar_start);
                let gap_before = self.gapped_before.remove(&key);
                finalized.push(self.finalize(row, now, gap_before));
            }
        }
        finalized
    }

    fn record_gap(
        &mut self,
        symbol: &str,
        expected: DateTime<Utc>,
        observed: DateTime<Utc>,
        detected_at: DateTime<Utc>,
    ) {
        let gap = LiveGapRecord::new(symbol, expected, observed, detected_at);
        if !self.gap_ids.insert(gap.gap_id.clone()) {
            return;
        }
        self.gaps.push(gap);
    }

    fn finalize(
        &mut self,
        update: LiveBarUpdate,
        finalized_timestamp: DateTime<Utc>,
        gap: bool,
    ) -> FinalizedLiveBar {
        let stale_threshold = Duration::milliseconds(self.stale_after_ms);
        let stale_or_cached = update.is_cached_push
            || finalized_timestamp - update.available_timestamp > stale_threshold
            || update.available_timestamp - update.bar_end > stale_threshold;
        self.finalized_keys
            .insert((update.symbol.clone(), update.bar_start));
        self.last_finalized_end
            .insert(update.symbol.clone(), update.bar_end);
        FinalizedLiveBar {
            update,
            finalized_timestamp,
            is_final: true,
            gap_status: match (gap, stale_or_cached) {
                (false, false) => "COMPLETE",
                (true, false) => "GAPPED",
                (false, true) => "STALE_OR_CACHED",
                (true, true) => "GAPPED_AND_STALE",
            }
            .into(),
            correction_of: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenDCheck {
    pub status: String,
    pub tcp_connected: bool,
    pub host: String,
    pub port: u16,
    pub checked_at: DateTime<Utc>,
    pub opend_version: Option<String>,
    pub login_status: String,
    pub quote_rights: String,
    pub subscription_quota: Option<usize>,
    pub spy_snapshot: String,
    pub k_1m_subscription: String,
    pub consolidated_nbbo: bool,
    pub provider: String,
    pub market_coverage: String,
    pub capability_level: String,
    pub blocker: Option<String>,
}

pub fn check(_config: &LiveConfig, host: &str, port: u16) -> OpenDCheck {
    let local_only = IpAddr::from_str(host).is_ok_and(|ip| ip.is_loopback()) || host == "localhost";
    let connected = local_only
        && (host, port)
            .to_socket_addrs_safe()
            .and_then(|address| {
                TcpStream::connect_timeout(&address, StdDuration::from_secs(2)).ok()
            })
            .is_some();
    OpenDCheck {
        status: if connected {
            "CONNECTED_PROTOCOL_CHECK_REQUIRED"
        } else {
            "DISCONNECTED"
        }
        .into(),
        tcp_connected: connected,
        host: host.into(),
        port,
        checked_at: Utc::now(),
        opend_version: None,
        login_status: if connected {
            "UNVERIFIED"
        } else {
            "UNAVAILABLE"
        }
        .into(),
        quote_rights: if connected {
            "UNVERIFIED"
        } else {
            "UNAVAILABLE"
        }
        .into(),
        subscription_quota: None,
        spy_snapshot: "NOT_REQUESTED_WITHOUT_VERIFIED_QUOTE_SDK".into(),
        k_1m_subscription: "NOT_STARTED".into(),
        consolidated_nbbo: false,
        provider: PROVIDER.into(),
        market_coverage: MARKET_COVERAGE.into(),
        capability_level: if connected {
            "D1_REALTIME_UNDERLYING_PENDING_PROTOCOL"
        } else {
            "NONE"
        }
        .into(),
        blocker: (!connected).then(|| {
            format!(
                "OpenD is not listening on {host}:{port}; start OpenD and log in through its GUI"
            )
        }),
    }
}

pub fn verified_check(config: &LiveConfig, first_symbol: &str, first_event: &str) -> OpenDCheck {
    OpenDCheck {
        status: "CONNECTED_QUOTE_PROTOCOL_VERIFIED".into(),
        tcp_connected: true,
        host: config.host.clone(),
        port: config.port,
        checked_at: Utc::now(),
        opend_version: Some("10.9.6908".into()),
        login_status: "VERIFIED_BY_OFFICIAL_SDK_CALLBACK".into(),
        quote_rights: "US_QUOTES_VERIFIED".into(),
        subscription_quota: None,
        spy_snapshot: format!("RECEIVED {first_symbol} {first_event}"),
        k_1m_subscription: if first_event == "k_1m" {
            "VERIFIED".into()
        } else {
            "SUBSCRIBED_AWAITING_FIRST_BAR".into()
        },
        consolidated_nbbo: false,
        provider: PROVIDER.into(),
        market_coverage: MARKET_COVERAGE.into(),
        capability_level: "D1_REALTIME_UNDERLYING_VERIFIED".into(),
        blocker: None,
    }
}

trait SocketAddressSafe {
    fn to_socket_addrs_safe(&self) -> Option<SocketAddr>;
}

impl SocketAddressSafe for (&str, u16) {
    fn to_socket_addrs_safe(&self) -> Option<SocketAddr> {
        let ip = IpAddr::from_str(self.0).ok()?;
        ip.is_loopback().then_some(SocketAddr::new(ip, self.1))
    }
}

pub fn capability(config: &LiveConfig) -> serde_json::Value {
    serde_json::json!({
        "enabled": config.enabled,
        "provider": PROVIDER,
        "quote_only": config.quote_only,
        "allow_trade_api": config.allow_trade_api,
        "asset_class": "US_EQUITY_ETF",
        "reference_symbol": "US.SPY",
        "target_symbol": "SPX_PROXY",
        "target_status": "UNDERLYING_PROXY_ONLY",
        "market_coverage": MARKET_COVERAGE,
        "consolidated_nbbo": false,
        "capability_level": "D1_REALTIME_UNDERLYING_WHEN_VERIFIED",
        "symbols": config.symbols,
        "forecast_symbols": config.forecast_symbols,
        "forecast_targets": config.forecast_symbols.iter().map(|symbol| {
            let canonical = symbol.trim_start_matches("US.");
            serde_json::json!({
                "live_symbol": symbol,
                "model_symbol": canonical,
                "target_status": if canonical == "SPY" {
                    "UNDERLYING_PROXY_ONLY:US.SPY->SPX_PROXY"
                } else {
                    "UNDERLYING_ETF_ONLY"
                }
            })
        }).collect::<Vec<_>>(),
        "subscriptions": {
            "QUOTE": config.subscribe_quote,
            "K_1M": config.subscribe_k_1m,
            "TICKER": config.subscribe_ticker,
            "ORDER_BOOK": config.subscribe_order_book
        },
        "spxw_realtime_experimental": config.enable_spxw_recorder,
        "historical_option_backtest_unblocked": false
    })
}

pub fn append_jsonl(path: &Path, value: &impl Serialize) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut file = OpenOptions::new().create(true).append(true).open(path)?;
    serde_json::to_writer(&mut file, value)?;
    file.write_all(b"\n")?;
    file.sync_data()?;
    Ok(())
}

/// Append-only, restart-safe gap ledger. Existing identities are loaded once;
/// a repeated gap is never appended again by this writer or after reopening.
#[derive(Debug)]
pub struct GapJsonlWriter {
    path: PathBuf,
    seen_gap_ids: HashSet<String>,
}

impl GapJsonlWriter {
    pub fn open(path: &Path) -> Result<Self> {
        let mut seen_gap_ids = HashSet::new();
        if path.exists() {
            let file = fs::File::open(path)
                .with_context(|| format!("open live gap ledger {}", path.display()))?;
            for (line_number, line) in BufReader::new(file).lines().enumerate() {
                let line = line?;
                if line.trim().is_empty() {
                    continue;
                }
                let record: LiveGapRecord = serde_json::from_str(&line).with_context(|| {
                    format!(
                        "invalid append-only gap record {}:{}",
                        path.display(),
                        line_number + 1
                    )
                })?;
                seen_gap_ids.insert(record.gap_id);
            }
        }
        Ok(Self {
            path: path.to_path_buf(),
            seen_gap_ids,
        })
    }

    pub fn append_new(&mut self, records: &[LiveGapRecord]) -> Result<usize> {
        let mut pending_ids = HashSet::new();
        let pending = records
            .iter()
            .filter(|record| {
                !self.seen_gap_ids.contains(&record.gap_id)
                    && pending_ids.insert(record.gap_id.clone())
            })
            .collect::<Vec<_>>();
        if pending.is_empty() {
            return Ok(0);
        }
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)
            .with_context(|| format!("append live gap ledger {}", self.path.display()))?;
        for record in &pending {
            serde_json::to_writer(&mut file, record)?;
            file.write_all(b"\n")?;
        }
        file.sync_data()?;
        for record in &pending {
            self.seen_gap_ids.insert(record.gap_id.clone());
        }
        Ok(pending.len())
    }
}

fn rotated_path(path: &Path, index: usize) -> PathBuf {
    let mut value = path.as_os_str().to_os_string();
    value.push(format!(".{index}"));
    PathBuf::from(value)
}

/// Append one immutable JSON line while bounding the active raw-callback log.
///
/// Rotation occurs before the new record would exceed `maximum_bytes`. The
/// newest closed segment is `.1`; older segments shift upward. The configured
/// oldest segment is removed only as part of this explicit retention policy.
pub fn append_jsonl_rotating(
    path: &Path,
    value: &impl Serialize,
    maximum_bytes: u64,
    archive_count: usize,
) -> Result<()> {
    if maximum_bytes < 1024 * 1024 || archive_count == 0 {
        bail!("JSONL rotation requires at least 1 MiB and one archive");
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut payload = serde_json::to_vec(value)?;
    payload.push(b'\n');
    let current_size = path.metadata().map(|metadata| metadata.len()).unwrap_or(0);
    if current_size > 0 && current_size.saturating_add(payload.len() as u64) > maximum_bytes {
        let oldest = rotated_path(path, archive_count);
        if oldest.exists() {
            fs::remove_file(&oldest)
                .with_context(|| format!("remove oldest rotated log {}", oldest.display()))?;
        }
        for index in (1..archive_count).rev() {
            let source = rotated_path(path, index);
            if source.exists() {
                let destination = rotated_path(path, index + 1);
                fs::rename(&source, &destination).with_context(|| {
                    format!(
                        "rotate JSONL log {} -> {}",
                        source.display(),
                        destination.display()
                    )
                })?;
            }
        }
        fs::rename(path, rotated_path(path, 1))
            .with_context(|| format!("rotate active JSONL log {}", path.display()))?;
    }
    let mut file = OpenOptions::new().create(true).append(true).open(path)?;
    file.write_all(&payload)?;
    file.sync_data()?;
    Ok(())
}

pub fn replay(input: &Path, grace_ms: i64, stale_after_ms: i64) -> Result<Vec<FinalizedLiveBar>> {
    let file = fs::File::open(input)
        .with_context(|| format!("open Moomoo replay fixture {}", input.display()))?;
    let mut finalizer = MinuteBarFinalizer::new(stale_after_ms)?;
    let mut output = Vec::new();
    let mut latest = None;
    for line in BufReader::new(file).lines() {
        let line = line?;
        let mut row = match serde_json::from_str::<LiveBarUpdate>(&line) {
            Ok(row) => row,
            Err(_) => {
                let Some(row) = parse_sdk_kline_replay(&line)? else {
                    continue;
                };
                row
            }
        };
        row.is_replay = true;
        latest = Some(row.receive_timestamp);
        output.extend(finalizer.ingest(row)?);
    }
    if let Some(latest) = latest {
        output.extend(finalizer.finalize_due(latest + Duration::minutes(2), grace_ms));
    }
    Ok(output)
}

pub fn payload_hash(payload: &[u8]) -> String {
    format!("{:x}", Sha256::digest(payload))
}

pub fn settle_pending(
    ledger: &PredictionLedger,
    finalized_archive: &Path,
) -> Result<Vec<ForecastSettlement>> {
    if !finalized_archive.exists() {
        return Ok(Vec::new());
    }
    let file = fs::File::open(finalized_archive)?;
    let mut bars = Vec::<FinalizedLiveBar>::new();
    for line in BufReader::new(file).lines() {
        bars.push(serde_json::from_str(&line?)?);
    }
    bars.sort_by_key(|row| row.update.bar_start);
    let latest_available = bars
        .iter()
        .map(|row| row.finalized_timestamp)
        .max()
        .unwrap_or_else(Utc::now);
    let mut settled = Vec::new();
    for forecast in ledger.pending_forecasts()? {
        if forecast.evidence_kind != "live_shadow_prediction"
            || forecast.label_end > latest_available
        {
            continue;
        }
        let symbol = format!("US.{}", forecast.symbol.trim_start_matches("US."));
        let window = bars
            .iter()
            .filter(|row| {
                row.update.symbol == symbol
                    && row.update.bar_start >= forecast.label_start
                    && row.update.bar_start < forecast.label_end
            })
            .collect::<Vec<_>>();
        let complete = window.len() == forecast.horizon_minutes
            && window
                .windows(2)
                .all(|pair| pair[0].update.bar_end == pair[1].update.bar_start)
            && window.iter().all(|row| row.gap_status == "COMPLETE");
        let (reference, log_return, direction, mfe, mae, volatility, barrier) = if complete {
            let entry = window[0].update.open;
            let exit = window.last().unwrap().update.close;
            let returns = window
                .windows(2)
                .map(|pair| (pair[1].update.close / pair[0].update.close).ln())
                .collect::<Vec<_>>();
            let mean = if returns.is_empty() {
                0.0
            } else {
                returns.iter().sum::<f64>() / returns.len() as f64
            };
            let rv = returns
                .iter()
                .map(|value| (value - mean).powi(2))
                .sum::<f64>()
                .sqrt();
            let value = (exit / entry).ln();
            (
                exit,
                value,
                if value > 0.0 {
                    1
                } else if value < 0.0 {
                    -1
                } else {
                    0
                },
                window
                    .iter()
                    .map(|row| row.update.high / entry - 1.0)
                    .fold(f64::NEG_INFINITY, f64::max),
                window
                    .iter()
                    .map(|row| row.update.low / entry - 1.0)
                    .fold(f64::INFINITY, f64::min),
                rv,
                "UNAVAILABLE_ORDERED_BARRIER_THRESHOLDS",
            )
        } else {
            (
                forecast.reference_price,
                0.0,
                0,
                0.0,
                0.0,
                0.0,
                "INVALID_DATA_GAP",
            )
        };
        let source_bar_ids = window
            .iter()
            .map(|row| row.update.raw_payload_hash.clone())
            .collect::<Vec<_>>();
        let mut settlement = ForecastSettlement {
            settlement_id: uuid::Uuid::new_v4().to_string(),
            prediction_id: forecast.prediction_id,
            settled_at: Utc::now(),
            realized_reference_price: reference,
            realized_log_return: log_return,
            realized_direction: direction,
            realized_mfe: mfe,
            realized_mae: mae,
            realized_volatility: volatility,
            barrier_outcome: barrier.into(),
            data_status: if complete {
                "COMPLETE"
            } else {
                "INVALID_DATA_GAP"
            }
            .into(),
            source_bar_ids,
            settlement_available_timestamp: latest_available,
            settlement_hash: String::new(),
            executable_entry: None,
            executable_exit: None,
            spread_cost: None,
            slippage: None,
            fees: None,
            hypothetical_pnl: None,
            evidence_kind: "settled_forward_prediction".into(),
        };
        settlement.settlement_hash = settlement_content_hash(&settlement)?;
        let canonical_settlement = ledger.append_settlement(&settlement)?;
        settled.push(canonical_settlement);
    }
    Ok(settled)
}

#[cfg(test)]
mod tests {
    use std::{fs, path::Path};

    use chrono::{DateTime, Duration, TimeZone, Utc};
    use tempfile::tempdir;

    use super::{
        FinalizedLiveBar, GapJsonlWriter, LiveBarUpdate, LiveGapRecord, MinuteBarFinalizer,
        append_jsonl_rotating, parse_sdk_kline, replay, settle_pending,
    };
    use crate::{
        prediction_ledger::PredictionLedger,
        predictor::{BarrierProbabilities, DecisionPolicyResult, ForecastContract},
    };

    fn update(minute: i64, receive_seconds: i64, cached: bool, hash: &str) -> LiveBarUpdate {
        let start =
            Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap() + Duration::minutes(minute);
        LiveBarUpdate {
            symbol: "US.SPY".into(),
            event_timestamp: start + Duration::seconds(receive_seconds.min(59)),
            receive_timestamp: start + Duration::seconds(receive_seconds),
            available_timestamp: start
                + Duration::seconds(receive_seconds)
                + Duration::milliseconds(1),
            bar_start: start,
            bar_end: start + Duration::minutes(1),
            open: 600.0,
            high: 601.0,
            low: 599.0,
            close: 600.5,
            volume: 1000.0,
            turnover: Some(600_500.0),
            session: "REGULAR".into(),
            source_version: "fixture".into(),
            subscription_id: "fixture".into(),
            sequence_or_dedup_key: hash.into(),
            is_cached_push: cached,
            is_replay: true,
            raw_payload_hash: hash.into(),
        }
    }

    fn timestamp_for_test(minute: i64, seconds: i64) -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap()
            + Duration::minutes(minute)
            + Duration::seconds(seconds)
    }

    fn forecast_fixture(prediction_id: &str, horizon_minutes: usize) -> ForecastContract {
        let label_start = Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap();
        let decision_as_of = label_start - Duration::minutes(1);
        ForecastContract {
            prediction_id: prediction_id.into(),
            created_at: decision_as_of,
            observation_cutoff: decision_as_of,
            as_of: decision_as_of,
            decision_as_of,
            latest_input_available_at: decision_as_of,
            earliest_executable_time: label_start,
            symbol: "SPY".into(),
            timeframe: "1m".into(),
            horizon_minutes,
            label_start,
            label_end: label_start + Duration::minutes(horizon_minutes as i64),
            session: "2026-07-20".into(),
            timezone: "America/New_York".into(),
            reference_price: 600.0,
            reference_price_source: "TEST_FINALIZED_CLOSE".into(),
            expected_return: 0.0,
            expected_price: Some(600.0),
            return_definition: "SIMPLE_RETURN".into(),
            current_close_reference_scenario_expected_price: 0.0,
            current_close_reference_scenario_price_quantiles: Vec::new(),
            current_close_reference_scenario_basis: String::new(),
            current_close_reference_scenario_status: String::new(),
            current_close_reference_scenario_semantics: String::new(),
            median_return: 0.0,
            return_quantiles: Vec::new(),
            price_quantiles: Vec::new(),
            p_up: None,
            p_down: None,
            p_flat: None,
            raw_analog_up_frequency: 0.5,
            raw_analog_down_frequency: 0.5,
            raw_analog_flat_frequency: 0.0,
            calibrated_probability_up: None,
            probability_calibration: Default::default(),
            suggested_direction: 0,
            strategy_win_probability: None,
            kernel_regression: Default::default(),
            outcome_prediction_intervals: Vec::new(),
            expected_volatility: 0.0,
            expected_absolute_move: 0.0,
            mfe_distribution: Vec::new(),
            mae_distribution: Vec::new(),
            barrier_probabilities: BarrierProbabilities {
                upper_first: None,
                lower_first: None,
                neither: None,
                status: "UNAVAILABLE_ORDERED_BARRIER_THRESHOLDS".into(),
            },
            filtered_state_probabilities: vec![1.0],
            predicted_state_probabilities: vec![1.0],
            state_entropy: Some(0.0),
            dominant_regime_state: Some(0),
            dominant_regime_probability: Some(1.0),
            regime_model_selection: None,
            stochastic_research_layer: Default::default(),
            epistemic_uncertainty: 0.0,
            ood_score: 0.0,
            market_snapshot_id: None,
            snapshot_link_status: "NOT_MATERIALIZED_TEST_FIXTURE".into(),
            top_analogs: Vec::new(),
            analog_effective_sample_size: 0.0,
            analog_similarity_score: 0.0,
            analog_max_day_weight: 0.0,
            analog_concentration_penalty: 0.0,
            analog_engine_status: "TEST_FIXTURE".into(),
            analog_metric: "none".into(),
            analog_bandwidth: 0.0,
            analog_diagnostics: None,
            analog_sensitivity: Vec::new(),
            model_id: "test-model".into(),
            model_hash: "test-model-hash".into(),
            feature_version: "test-feature-v1".into(),
            feature_hash: "test-feature-hash".into(),
            data_source: "MOOMOO_OPEND:test-fixture".into(),
            data_capability_level: "D1_TEST".into(),
            market_coverage: "TEST".into(),
            model_trained_through: "2026-07-17".into(),
            target_status: "UNDERLYING_TEST".into(),
            data_manifest_hash: "test-manifest-hash".into(),
            evidence_grade: "FORWARD_SHADOW".into(),
            evidence_kind: "live_shadow_prediction".into(),
            sample_size: 1,
            calibration_status: "TEST_NOT_PROMOTED".into(),
            availability_semantics: "TEST_POINT_IN_TIME".into(),
            decision: DecisionPolicyResult {
                action: "NO_TRADE".into(),
                eligible: false,
                expected_edge_after_cost: 0.0,
                no_trade_reasons: vec!["TEST_FIXTURE".into()],
                policy_version: "test-policy".into(),
            },
        }
    }

    fn finalized(minute: i64, gap_status: &str) -> FinalizedLiveBar {
        let row = update(minute, 59, false, &format!("bar-{minute}"));
        let finalized_timestamp = row.bar_end + Duration::seconds(2);
        FinalizedLiveBar {
            update: row,
            finalized_timestamp,
            is_final: true,
            gap_status: gap_status.into(),
            correction_of: None,
        }
    }

    fn write_archive(path: &Path, bars: &[FinalizedLiveBar]) {
        let payload = bars
            .iter()
            .map(serde_json::to_string)
            .collect::<Result<Vec<_>, _>>()
            .unwrap()
            .join("\n")
            + "\n";
        fs::write(path, payload).unwrap();
    }

    #[test]
    fn duplicate_current_bar_does_not_finalize_twice() {
        let mut f = MinuteBarFinalizer::default();
        assert!(f.ingest(update(0, 10, false, "a")).unwrap().is_empty());
        assert!(f.ingest(update(0, 20, false, "b")).unwrap().is_empty());
        let finalized = f.ingest(update(1, 5, false, "c")).unwrap();
        assert_eq!(finalized.len(), 1);
        assert_eq!(finalized[0].update.raw_payload_hash, "b");
    }

    #[test]
    fn grace_finalizes_and_late_update_becomes_correction() {
        let mut f = MinuteBarFinalizer::default();
        let row = update(0, 10, false, "a");
        let due = row.bar_end + Duration::seconds(3);
        f.ingest(row).unwrap();
        assert_eq!(f.finalize_due(due, 2_000).len(), 1);
        assert!(f.ingest(update(0, 50, false, "late")).unwrap().is_empty());
        assert_eq!(f.corrections.len(), 1);
    }

    #[test]
    fn gap_is_explicit_and_cached_duplicate_is_suppressed() {
        let mut f = MinuteBarFinalizer::default();
        f.ingest(update(0, 5, true, "cached")).unwrap();
        assert!(f.ingest(update(0, 5, true, "cached")).unwrap().is_empty());
        let finalized = f.ingest(update(2, 5, false, "next")).unwrap();
        assert_eq!(finalized[0].gap_status, "STALE_OR_CACHED");
        assert_eq!(f.gaps.len(), 1);
        let due = finalized[0].update.bar_end + Duration::minutes(3);
        let next = f.finalize_due(due, 2_000);
        assert_eq!(next.len(), 1);
        assert_eq!(next[0].gap_status, "GAPPED_AND_STALE");
    }

    #[test]
    fn stale_threshold_produces_all_four_finalized_quality_states() {
        assert!(MinuteBarFinalizer::new(0).is_err());

        let mut complete = MinuteBarFinalizer::new(10_000).unwrap();
        complete.ingest(update(0, 59, false, "complete")).unwrap();
        let complete_bar = complete.finalize_due(timestamp_for_test(0, 62), 2_000);
        assert_eq!(complete_bar[0].gap_status, "COMPLETE");

        let mut stale = MinuteBarFinalizer::new(10_000).unwrap();
        stale.ingest(update(0, 5, false, "stale")).unwrap();
        let stale_bar = stale.finalize_due(timestamp_for_test(0, 62), 2_000);
        assert_eq!(stale_bar[0].gap_status, "STALE_OR_CACHED");

        let mut gapped = MinuteBarFinalizer::new(10_000).unwrap();
        gapped.ingest(update(0, 59, false, "gap-base")).unwrap();
        gapped.ingest(update(2, 59, false, "gap-next")).unwrap();
        let gapped_bar = gapped.finalize_due(timestamp_for_test(2, 62), 2_000);
        assert_eq!(gapped_bar[0].gap_status, "GAPPED");

        let mut both = MinuteBarFinalizer::new(10_000).unwrap();
        both.ingest(update(0, 59, false, "both-base")).unwrap();
        both.ingest(update(2, 5, false, "both-next")).unwrap();
        let both_bar = both.finalize_due(timestamp_for_test(2, 62), 2_000);
        assert_eq!(both_bar[0].gap_status, "GAPPED_AND_STALE");
    }

    #[test]
    fn gap_flag_survives_finalization_triggered_by_next_bar() {
        let mut finalizer = MinuteBarFinalizer::new(120_000).unwrap();
        finalizer
            .ingest(update(0, 59, false, "next-trigger-base"))
            .unwrap();
        finalizer
            .ingest(update(2, 59, false, "next-trigger-gap"))
            .unwrap();
        let completed = finalizer
            .ingest(update(3, 59, false, "next-trigger-finalizer"))
            .unwrap();
        assert_eq!(completed.len(), 1);
        assert_eq!(
            completed[0].update.bar_start,
            update(2, 59, false, "x").bar_start
        );
        assert_eq!(completed[0].gap_status, "GAPPED");
    }

    #[test]
    fn working_bar_prevents_a_broader_duplicate_gap_record() {
        let mut finalizer = MinuteBarFinalizer::new(120_000).unwrap();
        finalizer
            .ingest(update(0, 59, false, "precise-gap-zero"))
            .unwrap();
        finalizer
            .ingest(update(1, 59, false, "precise-gap-one"))
            .unwrap();
        finalizer
            .ingest(update(3, 59, false, "precise-gap-three"))
            .unwrap();
        assert_eq!(finalizer.gaps.len(), 1);
        assert_eq!(finalizer.gaps[0].missing_minutes, 1);
        assert_eq!(
            finalizer.gaps[0].expected,
            update(1, 59, false, "x").bar_end
        );
        assert_eq!(
            finalizer.gaps[0].observed,
            update(3, 59, false, "y").bar_start
        );
    }

    #[test]
    fn gap_jsonl_is_append_only_and_deduplicated_after_restart() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("gaps.jsonl");
        let mut finalizer = MinuteBarFinalizer::new(10_000).unwrap();
        finalizer
            .ingest(update(0, 59, false, "ledger-base"))
            .unwrap();
        finalizer
            .ingest(update(2, 59, false, "ledger-gap"))
            .unwrap();
        assert_eq!(finalizer.gaps.len(), 1);

        let mut writer = GapJsonlWriter::open(&path).unwrap();
        assert_eq!(writer.append_new(&finalizer.gaps).unwrap(), 1);
        assert_eq!(writer.append_new(&finalizer.gaps).unwrap(), 0);
        drop(writer);

        let mut reopened = GapJsonlWriter::open(&path).unwrap();
        assert_eq!(reopened.append_new(&finalizer.gaps).unwrap(), 0);
        let lines = fs::read_to_string(&path).unwrap();
        assert_eq!(lines.lines().count(), 1);
        let persisted: LiveGapRecord = serde_json::from_str(lines.trim()).unwrap();
        assert_eq!(persisted.gap_id, finalizer.gaps[0].gap_id);
    }

    #[test]
    fn raw_jsonl_rotation_bounds_the_active_segment() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("raw.jsonl");
        let payload = serde_json::json!({"event":"test","payload":"x".repeat(700_000)});
        append_jsonl_rotating(&path, &payload, 1024 * 1024, 2).unwrap();
        append_jsonl_rotating(&path, &payload, 1024 * 1024, 2).unwrap();
        assert!(path.exists());
        assert!(directory.path().join("raw.jsonl.1").exists());
        assert!(path.metadata().unwrap().len() < 1024 * 1024);
    }

    #[test]
    fn official_sdk_kline_is_dst_aware_and_causal() {
        let received = Utc.with_ymd_and_hms(2026, 7, 21, 13, 30, 2).unwrap();
        let line = r#"{"event":"k_1m","symbol":"US.SPY","event_timestamp_et":"2026-07-21 09:31:00","open":742.0,"high":742.5,"low":741.8,"close":742.2,"volume":12000.0,"turnover":8900000.0,"source_version":"moomoo-opend-10.9.6908"}"#;
        let row = parse_sdk_kline(line, received).unwrap().unwrap();
        assert_eq!(
            row.bar_start,
            Utc.with_ymd_and_hms(2026, 7, 21, 13, 30, 0).unwrap()
        );
        assert_eq!(
            row.bar_end,
            Utc.with_ymd_and_hms(2026, 7, 21, 13, 31, 0).unwrap()
        );
        assert_eq!(row.event_timestamp, received);
        assert!(row.validate());
        assert!(!row.is_replay);
    }

    #[test]
    fn raw_sdk_jsonl_replays_kline_events_and_ignores_non_bar_events() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("raw_sdk_events.jsonl");
        fs::write(
            &path,
            concat!(
                "{\"event\":\"basic\",\"symbol\":\"US.SPY\",\"event_timestamp_et\":\"2026-07-21 09:30:59\",\"price\":742.0,\"source_version\":\"moomoo-opend-10.9.6908\"}\n",
                "{\"event\":\"k_1m\",\"symbol\":\"US.SPY\",\"event_timestamp_et\":\"2026-07-21 09:31:00\",\"open\":742.0,\"high\":742.5,\"low\":741.8,\"close\":742.2,\"volume\":12000.0,\"turnover\":8900000.0,\"source_version\":\"moomoo-opend-10.9.6908\"}\n",
                "{\"event\":\"k_1m\",\"symbol\":\"US.SPY\",\"event_timestamp_et\":\"2026-07-21 09:32:00\",\"open\":742.2,\"high\":742.8,\"low\":742.0,\"close\":742.7,\"volume\":14000.0,\"turnover\":10400000.0,\"source_version\":\"moomoo-opend-10.9.6908\"}\n",
            ),
        )
        .unwrap();

        let rows = replay(&path, 500, 10_000).unwrap();
        assert_eq!(rows.len(), 2);
        assert!(rows.iter().all(|row| row.update.is_replay));
        assert_eq!(
            rows[0].update.available_timestamp,
            Utc.with_ymd_and_hms(2026, 7, 21, 13, 31, 0).unwrap()
        );
        assert_eq!(rows[0].gap_status, "COMPLETE");
        assert_eq!(rows[1].gap_status, "STALE_OR_CACHED");
    }

    #[test]
    fn forward_shadow_settlement_is_complete_and_idempotent() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("ledger.sqlite3")).unwrap();
        let forecast = forecast_fixture("complete-prediction", 3);
        ledger.append_prediction(&forecast).unwrap();
        let archive = directory.path().join("finalized.jsonl");
        write_archive(
            &archive,
            &[
                finalized(0, "COMPLETE"),
                finalized(1, "COMPLETE"),
                finalized(2, "COMPLETE"),
            ],
        );

        let settlements = settle_pending(&ledger, &archive).unwrap();
        assert_eq!(settlements.len(), 1);
        assert_eq!(settlements[0].prediction_id, forecast.prediction_id);
        assert_eq!(settlements[0].data_status, "COMPLETE");
        assert_eq!(settlements[0].realized_direction, 1);
        assert_eq!(settlements[0].source_bar_ids.len(), 3);
        assert_eq!(
            ledger
                .settlement_status_by_prediction_id()
                .unwrap()
                .get("complete-prediction")
                .map(String::as_str),
            Some("SETTLED")
        );
        assert!(settle_pending(&ledger, &archive).unwrap().is_empty());
    }

    #[test]
    fn forward_shadow_gap_settles_as_invalid_instead_of_becoming_a_label() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("ledger.sqlite3")).unwrap();
        ledger
            .append_prediction(&forecast_fixture("gap-prediction", 3))
            .unwrap();
        let archive = directory.path().join("finalized.jsonl");
        write_archive(
            &archive,
            &[
                finalized(0, "COMPLETE"),
                finalized(1, "GAPPED"),
                finalized(2, "COMPLETE"),
            ],
        );

        let settlements = settle_pending(&ledger, &archive).unwrap();
        assert_eq!(settlements.len(), 1);
        assert_eq!(settlements[0].data_status, "INVALID_DATA_GAP");
        assert_eq!(settlements[0].realized_log_return, 0.0);
        assert_eq!(settlements[0].barrier_outcome, "INVALID_DATA_GAP");
    }
}
