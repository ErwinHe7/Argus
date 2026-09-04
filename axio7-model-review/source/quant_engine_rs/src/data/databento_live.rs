//! Licensed Databento live-equities adapter.
//!
//! The adapter authenticates with Databento's official Rust client, subscribes
//! to the configured `EQUS.MINI` one-minute OHLCV universe, and persists only
//! normalized observations plus explicit session/readiness metadata. It never
//! logs the API key, requests replay, or enables broker execution.

use std::{
    fs,
    path::{Path, PathBuf},
    time::Duration,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
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
    domain::MarketBar,
};

const FIXED_PRICE_SCALE: f64 = 1_000_000_000.0;
pub const DATABENTO_LIVE_STATUS_SCHEMA_VERSION: &str = "databento_live_status.v1";
pub const DATABENTO_LIVE_BAR_SCHEMA_VERSION: &str = "databento_ohlcv_1m.v1";

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

fn utc_from_nanos(value: u64) -> Result<DateTime<Utc>> {
    let nanos: i64 = value
        .try_into()
        .context("Databento timestamp exceeds signed nanosecond range")?;
    Ok(DateTime::<Utc>::from_timestamp_nanos(nanos))
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

fn normalize_bar(
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
    if !bar.validate() {
        bail!("Databento OHLCV record failed numeric validation");
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
            "The provider send timestamp was not requested; availability is the AXIO7 receipt time."
                .to_string(),
            "OHLCV-1m contains only completed vendor bars and does not expose order-book depth."
                .to_string(),
            "Licensed access does not imply public redistribution rights.".to_string(),
        ],
    })
}

fn initial_status(
    request: &DataRequest,
    symbols: Vec<String>,
    live: &LiveConfig,
) -> DatabentoLiveStatus {
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
}

async fn stream_once(
    request: &DataRequest,
    live: &LiveConfig,
    paths: &StreamPaths<'_>,
    status: &mut DatabentoLiveStatus,
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
    while let Some(record) = client.next_record().await? {
        let received_at = Utc::now();
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
            }
            status.updated_at = received_at;
            write_json_atomic(paths.status, status)?;
        }
        if record.get::<SymbolMappingMsg>().is_some() {
            status.symbol_mappings += 1;
        }
        if let Some(row) = record.get::<OhlcvMsg>() {
            let symbol = symbol_map
                .get_for_rec(row)
                .cloned()
                .context("Databento OHLCV record arrived without a point-in-time symbol mapping")?;
            status.entitlement_verified = true;
            status.state = "STREAMING_REALTIME".to_string();
            status.last_provider_event_at = Some(received_at);
            let envelope = normalize_bar(
                row,
                &symbol,
                &request.dataset,
                received_at,
                live.stale_after_ms,
            )?;
            if live.require_realtime && envelope.stale {
                status.blocker = Some("STALE_DATABENTO_BAR_REJECTED".to_string());
                status.updated_at = received_at;
                write_json_atomic(paths.status, status)?;
            } else {
                crate::live::append_jsonl_rotating(
                    paths.bars,
                    &envelope,
                    live.raw_log_max_bytes,
                    live.raw_log_archive_count,
                )?;
                status.last_finalized_bar_at = Some(envelope.bar_end);
                status.finalized_bars += 1;
                status.blocker = None;
                status.updated_at = received_at;
                write_json_atomic(paths.status, status)?;
            }
        }
        symbol_map.on_record(record)?;
    }
    bail!("Databento Live gateway closed the stream")
}

/// Runs the fail-closed Databento live supervisor until the process exits.
pub async fn run_equities_stream(
    data: &DataConfig,
    live: &LiveConfig,
    status_output: PathBuf,
    bars_output: PathBuf,
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
    let paths = StreamPaths {
        status: &status_output,
        bars: &bars_output,
    };
    let mut reconnect_ms = live.reconnect_min_ms;
    loop {
        match stream_once(&request, live, &paths, &mut status).await {
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
}
