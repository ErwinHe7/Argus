//! Licensed real-time Massive adapters.
//!
//! This module deliberately separates vendor transport from model inference:
//! it authenticates the real-time WebSocket, normalizes finalized SIP minute
//! bars, downloads every page of an OPRA chain snapshot, and persists explicit
//! readiness metadata. Delayed, stale, truncated, or unauthorized data is
//! never silently promoted to a model input.

use std::{
    collections::{BTreeMap, BTreeSet},
    fs::{self, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
    time::Duration,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Utc};
use futures_util::{SinkExt, StreamExt};
use reqwest::{Client, StatusCode, Url};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio_tungstenite::{connect_async, tungstenite::Message};

use crate::{
    config::{LiveConfig, MassiveConfig},
    domain::{CallPut, MarketBar, OptionQuote},
};

pub const REALTIME_READINESS_SCHEMA_VERSION: &str = "massive_realtime_readiness.v1";
pub const STOCK_EVENT_SCHEMA_VERSION: &str = "normalized_realtime_stock_bar.v1";
pub const STOCK_TAPE_SCHEMA_VERSION: &str = "normalized_realtime_stock_tape.v1";
pub const OPTION_CHAIN_SCHEMA_VERSION: &str = "massive_full_option_chain.v2";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ProbeState {
    Ready,
    NotEntitled,
    MissingCredential,
    DelayedEndpoint,
    ProviderError,
    InvalidResponse,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EndpointProbe {
    pub capability: String,
    pub state: ProbeState,
    pub checked_at: DateTime<Utc>,
    pub endpoint: String,
    pub http_status: Option<u16>,
    pub provider_status: Option<String>,
    pub detail: String,
}

impl EndpointProbe {
    fn ready(&self) -> bool {
        self.state == ProbeState::Ready
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveRealtimeReadiness {
    pub schema_version: String,
    pub checked_at: DateTime<Utc>,
    pub provider: String,
    pub realtime_required: bool,
    pub api_key_env: String,
    pub api_key_present: bool,
    pub stock_websocket: EndpointProbe,
    pub stock_snapshot: EndpointProbe,
    pub option_chains: Vec<EndpointProbe>,
    pub production_ready: bool,
    pub blockers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RealtimeMarketBarEnvelope {
    pub schema_version: String,
    pub provider: String,
    pub provider_event: String,
    pub received_at: DateTime<Utc>,
    pub provider_available_at: DateTime<Utc>,
    pub bar_start: DateTime<Utc>,
    pub bar_end: DateTime<Utc>,
    pub finalized_at: DateTime<Utc>,
    pub entitlement: String,
    pub delayed: bool,
    pub stale: bool,
    pub bar: MarketBar,
}

/// Lossless, provider-timestamped stock event used for replay and future
/// microstructure features. `raw` is the complete vendor event after transport
/// authentication; no API key or auth message is ever written.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RealtimeStockTapeEvent {
    pub schema_version: String,
    pub provider: String,
    pub event_type: String,
    pub symbol: String,
    pub provider_timestamp: Option<DateTime<Utc>>,
    pub received_at: DateTime<Utc>,
    pub sequence: Option<u64>,
    pub trade_price: Option<f64>,
    pub trade_size_provider_units: Option<f64>,
    pub bid: Option<f64>,
    pub bid_size_provider_units: Option<f64>,
    pub ask: Option<f64>,
    pub ask_size_provider_units: Option<f64>,
    pub open: Option<f64>,
    pub high: Option<f64>,
    pub low: Option<f64>,
    pub close: Option<f64>,
    pub volume: Option<f64>,
    pub size_semantics: String,
    pub entitlement: String,
    pub delayed: bool,
    pub stale: bool,
    pub future_timestamp: bool,
    pub model_eligible: bool,
    pub payload_sha256: String,
    pub raw: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveStreamStatus {
    pub schema_version: String,
    pub updated_at: DateTime<Utc>,
    pub provider: String,
    pub state: String,
    pub endpoint: String,
    pub authenticated: bool,
    pub realtime_required: bool,
    pub subscribed_symbols: Vec<String>,
    pub last_provider_event_at: Option<DateTime<Utc>>,
    pub last_finalized_bar_at: Option<DateTime<Utc>>,
    pub finalized_bars: u64,
    pub tape_events: u64,
    pub trade_events: u64,
    pub quote_events: u64,
    pub aggregate_second_events: u64,
    pub reconnects: u64,
    pub blocker: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveOptionContract {
    pub option_symbol: String,
    pub underlying: String,
    pub expiry: NaiveDate,
    pub dte: i32,
    pub strike: f64,
    pub call_put: CallPut,
    pub quote_timestamp: Option<DateTime<Utc>>,
    pub bid: Option<f64>,
    pub ask: Option<f64>,
    pub bid_size: Option<u32>,
    pub ask_size: Option<u32>,
    pub last: Option<f64>,
    pub volume: Option<u64>,
    pub open_interest: Option<u64>,
    pub iv: Option<f64>,
    pub delta: Option<f64>,
    pub gamma: Option<f64>,
    pub theta: Option<f64>,
    pub vega: Option<f64>,
    pub underlying_price: Option<f64>,
    pub provider_timeframe: Option<String>,
    pub model_eligible: bool,
    pub ineligibility_reasons: Vec<String>,
}

impl MassiveOptionContract {
    pub fn as_option_quote(&self) -> Option<OptionQuote> {
        if !self.model_eligible {
            return None;
        }
        Some(OptionQuote {
            timestamp: self.quote_timestamp?,
            underlying: self.underlying.clone(),
            option_symbol: self.option_symbol.clone(),
            expiry: self.expiry,
            dte: self.dte,
            strike: self.strike,
            call_put: self.call_put,
            bid: self.bid?,
            ask: self.ask?,
            bid_size: self.bid_size?,
            ask_size: self.ask_size?,
            last: self.last,
            volume: self.volume,
            open_interest_at_open: self.open_interest,
            iv: self.iv,
            delta: self.delta,
            gamma: self.gamma,
            theta: self.theta,
            vega: self.vega,
            underlying_price: self.underlying_price?,
            source: "MASSIVE_OPRA_FULL_CHAIN".to_string(),
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptionChainCoverage {
    pub contracts_received: usize,
    pub contracts_parsed: usize,
    pub identity_parse_failures: usize,
    pub quote_coverage: f64,
    pub fresh_quote_coverage: f64,
    pub open_interest_coverage: f64,
    pub greeks_coverage: f64,
    pub underlying_price_coverage: f64,
    pub model_eligible_contracts: usize,
    pub pages_fetched: usize,
    pub pagination_complete: bool,
    pub truncated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveFullOptionChain {
    pub schema_version: String,
    pub provider: String,
    pub source: String,
    pub underlying: String,
    pub captured_at: DateTime<Utc>,
    pub earliest_quote_at: Option<DateTime<Utc>>,
    pub latest_quote_at: Option<DateTime<Utc>>,
    /// Massive exposes OI as a daily snapshot. This is the time at which that
    /// snapshot became available to this process, not a claim of intraday OI.
    pub oi_available_at: DateTime<Utc>,
    pub open_interest_semantics: String,
    /// Provider-computed Greeks became available with this captured response.
    pub greeks_available_at: DateTime<Utc>,
    pub realtime_required: bool,
    pub chain_complete: bool,
    pub model_ready: bool,
    pub blockers: Vec<String>,
    pub coverage: OptionChainCoverage,
    pub contracts_sha256: String,
    pub contracts: Vec<MassiveOptionContract>,
}

#[derive(Debug, Clone)]
struct PendingAggregate {
    envelope: RealtimeMarketBarEnvelope,
}

fn normalize_symbol(symbol: &str) -> String {
    symbol.trim().trim_start_matches("US.").to_ascii_uppercase()
}

fn redact_url(raw: &str) -> String {
    let Ok(mut url) = Url::parse(raw) else {
        return raw.to_string();
    };
    if url.query().is_some() {
        let retained = url
            .query_pairs()
            .filter(|(key, _)| !key.eq_ignore_ascii_case("apikey"))
            .map(|(key, value)| (key.into_owned(), value.into_owned()))
            .collect::<Vec<_>>();
        url.set_query(None);
        for (key, value) in retained {
            url.query_pairs_mut().append_pair(&key, &value);
        }
    }
    url.to_string()
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

fn append_jsonl(path: &Path, value: &impl Serialize) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut file = OpenOptions::new().create(true).append(true).open(path)?;
    serde_json::to_writer(&mut file, value)?;
    file.write_all(b"\n")?;
    file.flush()?;
    Ok(())
}

fn endpoint_is_delayed(raw: &str) -> bool {
    Url::parse(raw)
        .ok()
        .and_then(|url| url.host_str().map(str::to_ascii_lowercase))
        .is_some_and(|host| host.contains("delayed"))
}

fn provider_detail(value: &Value) -> String {
    value
        .get("error")
        .or_else(|| value.get("message"))
        .and_then(Value::as_str)
        .unwrap_or("provider did not return a diagnostic")
        .chars()
        .take(400)
        .collect()
}

async fn rest_probe(client: &Client, url: Url, capability: &str, api_key: &str) -> EndpointProbe {
    let checked_at = Utc::now();
    let endpoint = redact_url(url.as_str());
    let response = match client.get(url).query(&[("apiKey", api_key)]).send().await {
        Ok(response) => response,
        Err(error) => {
            return EndpointProbe {
                capability: capability.to_string(),
                state: ProbeState::ProviderError,
                checked_at,
                endpoint,
                http_status: None,
                provider_status: None,
                detail: format!("transport error: {error}"),
            };
        }
    };
    let status = response.status();
    let body = response.bytes().await.unwrap_or_default();
    let parsed = serde_json::from_slice::<Value>(&body).unwrap_or(Value::Null);
    let provider_status = parsed
        .get("status")
        .and_then(Value::as_str)
        .map(str::to_string);
    let (state, detail) = if status.is_success() {
        (
            ProbeState::Ready,
            "licensed endpoint returned a successful response".to_string(),
        )
    } else if matches!(status, StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN) {
        (ProbeState::NotEntitled, provider_detail(&parsed))
    } else {
        (
            ProbeState::ProviderError,
            format!("HTTP {status}: {}", provider_detail(&parsed)),
        )
    };
    EndpointProbe {
        capability: capability.to_string(),
        state,
        checked_at,
        endpoint,
        http_status: Some(status.as_u16()),
        provider_status,
        detail,
    }
}

async fn websocket_auth_probe(
    config: &MassiveConfig,
    live: &LiveConfig,
    api_key: &str,
) -> EndpointProbe {
    let checked_at = Utc::now();
    let endpoint = redact_url(&config.stock_websocket_url);
    if live.require_realtime && endpoint_is_delayed(&config.stock_websocket_url) {
        return EndpointProbe {
            capability: "sip_stock_websocket".to_string(),
            state: ProbeState::DelayedEndpoint,
            checked_at,
            endpoint,
            http_status: None,
            provider_status: None,
            detail: "delayed WebSocket endpoint is prohibited by live.require_realtime".to_string(),
        };
    }
    let connection = tokio::time::timeout(
        Duration::from_secs(10),
        connect_async(&config.stock_websocket_url),
    )
    .await;
    let Ok(Ok((mut socket, _))) = connection else {
        return EndpointProbe {
            capability: "sip_stock_websocket".to_string(),
            state: ProbeState::ProviderError,
            checked_at,
            endpoint,
            http_status: None,
            provider_status: None,
            detail: "WebSocket connection failed or timed out".to_string(),
        };
    };
    if socket
        .send(Message::Text(
            json!({"action":"auth","params":api_key}).to_string().into(),
        ))
        .await
        .is_err()
    {
        return EndpointProbe {
            capability: "sip_stock_websocket".to_string(),
            state: ProbeState::ProviderError,
            checked_at,
            endpoint,
            http_status: None,
            provider_status: None,
            detail: "WebSocket authentication message could not be sent".to_string(),
        };
    }
    let auth = tokio::time::timeout(Duration::from_secs(10), async {
        loop {
            let message = socket
                .next()
                .await
                .context("WebSocket closed before authentication")??;
            let text = message.into_text().unwrap_or_default();
            let values = serde_json::from_str::<Vec<Value>>(&text)
                .or_else(|_| serde_json::from_str::<Value>(&text).map(|value| vec![value]))
                .unwrap_or_default();
            if values
                .iter()
                .any(|value| value.get("status").and_then(Value::as_str) == Some("auth_success"))
            {
                return Ok::<_, anyhow::Error>((
                    ProbeState::Ready,
                    Some("auth_success".to_string()),
                    "real-time stock WebSocket authentication succeeded".to_string(),
                ));
            }
            if let Some((status, detail)) = values.iter().find_map(|value| {
                let status = value.get("status").and_then(Value::as_str)?;
                if matches!(status, "connected" | "auth_success") {
                    return None;
                }
                Some((
                    status.to_string(),
                    value
                        .get("message")
                        .and_then(Value::as_str)
                        .unwrap_or("WebSocket authentication rejected")
                        .to_string(),
                ))
            }) {
                return Ok((ProbeState::NotEntitled, Some(status), detail));
            }
        }
    })
    .await;
    let (state, provider_status, detail) = match auth {
        Ok(Ok(result)) => result,
        Ok(Err(error)) => (
            ProbeState::ProviderError,
            None,
            format!("WebSocket authentication failed: {error}"),
        ),
        Err(_) => (
            ProbeState::ProviderError,
            None,
            "WebSocket authentication response timed out".to_string(),
        ),
    };
    let _ = socket.close(None).await;
    EndpointProbe {
        capability: "sip_stock_websocket".to_string(),
        state,
        checked_at,
        endpoint,
        http_status: None,
        provider_status,
        detail,
    }
}

pub async fn check_realtime_entitlements(
    config: &MassiveConfig,
    live: &LiveConfig,
) -> Result<MassiveRealtimeReadiness> {
    let checked_at = Utc::now();
    let key = match std::env::var(&config.api_key_env) {
        Ok(value) if !value.trim().is_empty() => value,
        _ => {
            let missing = |capability: &str, endpoint: String| EndpointProbe {
                capability: capability.to_string(),
                state: ProbeState::MissingCredential,
                checked_at,
                endpoint,
                http_status: None,
                provider_status: None,
                detail: format!("{} is missing", config.api_key_env),
            };
            let stock_ws = missing(
                "sip_stock_websocket",
                redact_url(&config.stock_websocket_url),
            );
            let stock_snapshot = missing(
                "sip_stock_snapshot",
                format!(
                    "{}/v2/snapshot/locale/us/markets/stocks/tickers/SPY",
                    config.base_url
                ),
            );
            let option_chains = config
                .option_underlyings
                .iter()
                .map(|underlying| {
                    missing(
                        &format!("opra_full_chain_{underlying}"),
                        format!("{}/v3/snapshot/options/{underlying}", config.base_url),
                    )
                })
                .collect();
            return Ok(MassiveRealtimeReadiness {
                schema_version: REALTIME_READINESS_SCHEMA_VERSION.to_string(),
                checked_at,
                provider: "massive".to_string(),
                realtime_required: live.require_realtime,
                api_key_env: config.api_key_env.clone(),
                api_key_present: false,
                stock_websocket: stock_ws,
                stock_snapshot,
                option_chains,
                production_ready: false,
                blockers: vec![format!("missing credential {}", config.api_key_env)],
            });
        }
    };
    let client = Client::builder()
        .user_agent("AXIO7-Quant/0.1")
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(8))
        .build()?;
    let stock_ws = websocket_auth_probe(config, live, &key).await;
    let stock_url = Url::parse(&format!(
        "{}/v2/snapshot/locale/us/markets/stocks/tickers/SPY",
        config.base_url.trim_end_matches('/')
    ))?;
    let option_futures = config
        .option_underlyings
        .iter()
        .map(|underlying| {
            let client = client.clone();
            let key = key.clone();
            let canonical = normalize_symbol(underlying);
            let base_url = config.base_url.trim_end_matches('/').to_string();
            async move {
                let mut url =
                    match Url::parse(&format!("{base_url}/v3/snapshot/options/{canonical}")) {
                        Ok(url) => url,
                        Err(error) => {
                            return EndpointProbe {
                                capability: format!("opra_full_chain_{canonical}"),
                                state: ProbeState::InvalidResponse,
                                checked_at: Utc::now(),
                                endpoint: base_url,
                                http_status: None,
                                provider_status: None,
                                detail: format!("invalid configured endpoint: {error}"),
                            };
                        }
                    };
                url.query_pairs_mut().append_pair("limit", "1");
                rest_probe(&client, url, &format!("opra_full_chain_{canonical}"), &key).await
            }
        })
        .collect::<Vec<_>>();
    let (stock_snapshot, option_chains) = tokio::join!(
        rest_probe(&client, stock_url, "sip_stock_snapshot", &key),
        futures_util::future::join_all(option_futures)
    );
    let mut blockers = Vec::new();
    if !stock_ws.ready() {
        blockers.push(format!("stock websocket: {}", stock_ws.detail));
    }
    if !stock_snapshot.ready() {
        blockers.push(format!("stock snapshot: {}", stock_snapshot.detail));
    }
    for probe in &option_chains {
        if !probe.ready() {
            blockers.push(format!("{}: {}", probe.capability, probe.detail));
        }
    }
    let production_ready = blockers.is_empty();
    Ok(MassiveRealtimeReadiness {
        schema_version: REALTIME_READINESS_SCHEMA_VERSION.to_string(),
        checked_at,
        provider: "massive".to_string(),
        realtime_required: live.require_realtime,
        api_key_env: config.api_key_env.clone(),
        api_key_present: true,
        stock_websocket: stock_ws,
        stock_snapshot,
        option_chains,
        production_ready,
        blockers,
    })
}

fn epoch_value(value: Option<&Value>) -> Option<DateTime<Utc>> {
    let raw = value?.as_i64()?;
    let absolute = raw.unsigned_abs();
    if absolute >= 1_000_000_000_000_000_000 {
        DateTime::<Utc>::from_timestamp(raw / 1_000_000_000, (raw % 1_000_000_000) as u32)
    } else if absolute >= 1_000_000_000_000_000 {
        DateTime::<Utc>::from_timestamp_micros(raw)
    } else if absolute >= 1_000_000_000_000 {
        DateTime::<Utc>::from_timestamp_millis(raw)
    } else {
        DateTime::<Utc>::from_timestamp(raw, 0)
    }
}

fn numeric_value(value: Option<&Value>) -> Option<f64> {
    match value? {
        Value::Number(number) => number.as_f64(),
        Value::String(raw) => raw.parse::<f64>().ok(),
        _ => None,
    }
}

fn parse_stock_tape_event(
    value: &Value,
    received_at: DateTime<Utc>,
    live: &LiveConfig,
    websocket_url: &str,
) -> Option<RealtimeStockTapeEvent> {
    let event_type = value.get("ev")?.as_str()?;
    if !matches!(event_type, "T" | "Q" | "A" | "AM") {
        return None;
    }
    let symbol = normalize_symbol(value.get("sym")?.as_str()?);
    let provider_timestamp = match event_type {
        "T" | "Q" => epoch_value(value.get("t")),
        "A" | "AM" => epoch_value(value.get("e")),
        _ => None,
    };
    let age_ms = provider_timestamp.map(|timestamp| {
        received_at
            .signed_duration_since(timestamp)
            .num_milliseconds()
    });
    let delayed = endpoint_is_delayed(websocket_url);
    let stale = age_ms.is_none_or(|age| age > live.stale_after_ms);
    let future_timestamp =
        age_ms.is_some_and(|age| age < live.max_context_skew_ms.saturating_neg());
    let raw_bytes = serde_json::to_vec(value).ok()?;
    Some(RealtimeStockTapeEvent {
        schema_version: STOCK_TAPE_SCHEMA_VERSION.to_string(),
        provider: "massive".to_string(),
        event_type: event_type.to_string(),
        symbol,
        provider_timestamp,
        received_at,
        sequence: value.get("q").and_then(Value::as_u64),
        trade_price: (event_type == "T")
            .then(|| numeric_value(value.get("p")))
            .flatten(),
        trade_size_provider_units: (event_type == "T")
            .then(|| numeric_value(value.get("ds").or_else(|| value.get("s"))))
            .flatten(),
        bid: (event_type == "Q")
            .then(|| numeric_value(value.get("bp")))
            .flatten(),
        bid_size_provider_units: (event_type == "Q")
            .then(|| numeric_value(value.get("bs")))
            .flatten(),
        ask: (event_type == "Q")
            .then(|| numeric_value(value.get("ap")))
            .flatten(),
        ask_size_provider_units: (event_type == "Q")
            .then(|| numeric_value(value.get("as")))
            .flatten(),
        open: matches!(event_type, "A" | "AM")
            .then(|| numeric_value(value.get("o")))
            .flatten(),
        high: matches!(event_type, "A" | "AM")
            .then(|| numeric_value(value.get("h")))
            .flatten(),
        low: matches!(event_type, "A" | "AM")
            .then(|| numeric_value(value.get("l")))
            .flatten(),
        close: matches!(event_type, "A" | "AM")
            .then(|| numeric_value(value.get("c")))
            .flatten(),
        volume: matches!(event_type, "A" | "AM")
            .then(|| numeric_value(value.get("dv").or_else(|| value.get("v"))))
            .flatten(),
        size_semantics: match event_type {
            "Q" => "PROVIDER_ROUND_LOT_UNITS",
            "T" => "PROVIDER_SHARE_UNITS",
            "A" | "AM" => "PROVIDER_AGGREGATE_VOLUME_UNITS",
            _ => "UNKNOWN",
        }
        .to_string(),
        entitlement: "REALTIME_AUTHENTICATED".to_string(),
        delayed,
        stale,
        future_timestamp,
        model_eligible: !delayed && !stale && !future_timestamp,
        payload_sha256: format!("{:x}", Sha256::digest(raw_bytes)),
        raw: value.clone(),
    })
}

fn nested_f64(value: &Value, pointer: &str) -> Option<f64> {
    value.pointer(pointer).and_then(Value::as_f64)
}

fn nested_u64(value: &Value, pointer: &str) -> Option<u64> {
    value.pointer(pointer).and_then(Value::as_u64)
}

fn parse_contract(
    value: &Value,
    underlying: &str,
    captured_at: DateTime<Utc>,
) -> Result<MassiveOptionContract> {
    let details = value
        .get("details")
        .context("option result missing details")?;
    let option_symbol = details
        .get("ticker")
        .and_then(Value::as_str)
        .context("option details missing ticker")?
        .to_string();
    let expiry = NaiveDate::parse_from_str(
        details
            .get("expiration_date")
            .and_then(Value::as_str)
            .context("option details missing expiration_date")?,
        "%Y-%m-%d",
    )?;
    let strike = details
        .get("strike_price")
        .and_then(Value::as_f64)
        .context("option details missing strike_price")?;
    let call_put = match details
        .get("contract_type")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_ascii_lowercase()
        .as_str()
    {
        "call" => CallPut::Call,
        "put" => CallPut::Put,
        other => bail!("unsupported contract type {other}"),
    };
    let quote_timestamp = epoch_value(value.pointer("/last_quote/last_updated"))
        .or_else(|| epoch_value(value.pointer("/last_quote/sip_timestamp")));
    let bid = nested_f64(value, "/last_quote/bid");
    let ask = nested_f64(value, "/last_quote/ask");
    let bid_size = nested_u64(value, "/last_quote/bid_size").and_then(|v| u32::try_from(v).ok());
    let ask_size = nested_u64(value, "/last_quote/ask_size").and_then(|v| u32::try_from(v).ok());
    let last = nested_f64(value, "/last_trade/price").or_else(|| nested_f64(value, "/day/close"));
    let volume = nested_u64(value, "/day/volume");
    let open_interest = value.get("open_interest").and_then(Value::as_u64);
    let iv = value.get("implied_volatility").and_then(Value::as_f64);
    let delta = nested_f64(value, "/greeks/delta");
    let gamma = nested_f64(value, "/greeks/gamma");
    let theta = nested_f64(value, "/greeks/theta");
    let vega = nested_f64(value, "/greeks/vega");
    let underlying_price = nested_f64(value, "/underlying_asset/price");
    let provider_timeframe = value
        .get("timeframe")
        .or_else(|| value.pointer("/last_quote/timeframe"))
        .and_then(Value::as_str)
        .map(str::to_string);
    let mut reasons = Vec::new();
    if quote_timestamp.is_none() {
        reasons.push("MISSING_QUOTE_TIMESTAMP".to_string());
    }
    if bid.is_none() || ask.is_none() || bid_size.is_none() || ask_size.is_none() {
        reasons.push("MISSING_NBBO".to_string());
    } else if bid.unwrap_or(-1.0) < 0.0 || ask.unwrap_or(-1.0) < bid.unwrap_or(f64::INFINITY) {
        reasons.push("INVALID_NBBO".to_string());
    }
    if open_interest.is_none() {
        reasons.push("MISSING_OPEN_INTEREST".to_string());
    }
    if iv.is_none() || delta.is_none() || gamma.is_none() || theta.is_none() || vega.is_none() {
        reasons.push("MISSING_GREEKS_OR_IV".to_string());
    }
    if underlying_price.is_none_or(|price| !price.is_finite() || price <= 0.0) {
        reasons.push("MISSING_UNDERLYING_PRICE".to_string());
    }
    if provider_timeframe
        .as_deref()
        .is_some_and(|timeframe| timeframe.to_ascii_lowercase().contains("delay"))
    {
        reasons.push("DELAYED_PROVIDER_TIMEFRAME".to_string());
    }
    let dte = (expiry - captured_at.date_naive()).num_days() as i32;
    Ok(MassiveOptionContract {
        option_symbol,
        underlying: normalize_symbol(underlying),
        expiry,
        dte,
        strike,
        call_put,
        quote_timestamp,
        bid,
        ask,
        bid_size,
        ask_size,
        last,
        volume,
        open_interest,
        iv,
        delta,
        gamma,
        theta,
        vega,
        underlying_price,
        provider_timeframe,
        model_eligible: reasons.is_empty(),
        ineligibility_reasons: reasons,
    })
}

fn ratio(numerator: usize, denominator: usize) -> f64 {
    if denominator == 0 {
        0.0
    } else {
        numerator as f64 / denominator as f64
    }
}

pub async fn fetch_full_option_chain(
    config: &MassiveConfig,
    live: &LiveConfig,
    underlying: &str,
) -> Result<MassiveFullOptionChain> {
    let key = std::env::var(&config.api_key_env)
        .with_context(|| format!("missing {} environment variable", config.api_key_env))?;
    let underlying = normalize_symbol(underlying);
    if !config
        .option_underlyings
        .iter()
        .map(|value| normalize_symbol(value))
        .any(|value| value == underlying)
    {
        bail!("underlying {underlying} is not in data.massive.option_underlyings");
    }
    let client = Client::builder()
        .user_agent("AXIO7-Quant/0.1")
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(15))
        .build()?;
    let captured_at = Utc::now();
    let mut url = Url::parse(&format!(
        "{}/v3/snapshot/options/{underlying}",
        config.base_url.trim_end_matches('/')
    ))?;
    url.query_pairs_mut().append_pair("limit", "250");
    let mut contracts = Vec::new();
    let mut pages_fetched = 0usize;
    let mut received = 0usize;
    let mut parse_failures = 0usize;
    let mut pagination_complete = false;
    let mut truncated = false;
    loop {
        if pages_fetched >= config.option_chain_max_pages
            || received >= config.option_chain_max_contracts
        {
            truncated = true;
            break;
        }
        let response = client
            .get(url.clone())
            .query(&[("apiKey", key.as_str())])
            .send()
            .await
            .context("Massive option-chain request failed")?;
        let status = response.status();
        let body = response.bytes().await?;
        if !status.is_success() {
            let parsed = serde_json::from_slice::<Value>(&body).unwrap_or(Value::Null);
            bail!(
                "Massive option chain {underlying} rejected with HTTP {status}: {}",
                provider_detail(&parsed)
            );
        }
        let parsed: Value =
            serde_json::from_slice(&body).context("invalid Massive option-chain JSON")?;
        let results = parsed
            .get("results")
            .and_then(Value::as_array)
            .context("Massive option-chain response missing results")?;
        pages_fetched += 1;
        received += results.len();
        for result in results {
            match parse_contract(result, &underlying, captured_at) {
                Ok(mut contract) => {
                    let quote_age_ms = contract.quote_timestamp.map(|timestamp| {
                        captured_at
                            .signed_duration_since(timestamp)
                            .num_milliseconds()
                    });
                    if quote_age_ms.is_some_and(|age| age > live.stale_after_ms) {
                        contract
                            .ineligibility_reasons
                            .push("STALE_QUOTE_AT_CAPTURE".to_string());
                    }
                    if quote_age_ms
                        .is_some_and(|age| age < live.max_context_skew_ms.saturating_neg())
                    {
                        contract
                            .ineligibility_reasons
                            .push("FUTURE_QUOTE_AT_CAPTURE".to_string());
                    }
                    contract.ineligibility_reasons.sort();
                    contract.ineligibility_reasons.dedup();
                    contract.model_eligible = contract.ineligibility_reasons.is_empty();
                    contracts.push(contract);
                }
                Err(_) => parse_failures += 1,
            }
        }
        let Some(next) = parsed.get("next_url").and_then(Value::as_str) else {
            pagination_complete = true;
            break;
        };
        url = Url::parse(next).context("Massive returned invalid next_url")?;
    }
    contracts.sort_by(|a, b| {
        (
            a.expiry,
            a.strike.to_bits(),
            format!("{:?}", a.call_put),
            &a.option_symbol,
        )
            .cmp(&(
                b.expiry,
                b.strike.to_bits(),
                format!("{:?}", b.call_put),
                &b.option_symbol,
            ))
    });
    let denominator = contracts.len();
    let quote_count = contracts
        .iter()
        .filter(|row| {
            row.quote_timestamp.is_some()
                && row.bid.is_some()
                && row.ask.is_some()
                && row.bid_size.is_some()
                && row.ask_size.is_some()
        })
        .count();
    let fresh_quote_count = contracts
        .iter()
        .filter(|row| {
            row.quote_timestamp.is_some_and(|timestamp| {
                let age = captured_at
                    .signed_duration_since(timestamp)
                    .num_milliseconds();
                age >= live.max_context_skew_ms.saturating_neg() && age <= live.stale_after_ms
            })
        })
        .count();
    let oi_count = contracts
        .iter()
        .filter(|row| row.open_interest.is_some())
        .count();
    let greeks_count = contracts
        .iter()
        .filter(|row| {
            row.iv.is_some()
                && row.delta.is_some()
                && row.gamma.is_some()
                && row.theta.is_some()
                && row.vega.is_some()
        })
        .count();
    let underlying_count = contracts
        .iter()
        .filter(|row| row.underlying_price.is_some())
        .count();
    let eligible = contracts.iter().filter(|row| row.model_eligible).count();
    let coverage = OptionChainCoverage {
        contracts_received: received,
        contracts_parsed: contracts.len(),
        identity_parse_failures: parse_failures,
        quote_coverage: ratio(quote_count, denominator),
        fresh_quote_coverage: ratio(fresh_quote_count, denominator),
        open_interest_coverage: ratio(oi_count, denominator),
        greeks_coverage: ratio(greeks_count, denominator),
        underlying_price_coverage: ratio(underlying_count, denominator),
        model_eligible_contracts: eligible,
        pages_fetched,
        pagination_complete,
        truncated,
    };
    let earliest_quote_at = contracts.iter().filter_map(|row| row.quote_timestamp).min();
    let latest_quote_at = contracts.iter().filter_map(|row| row.quote_timestamp).max();
    let chain_complete =
        pagination_complete && !truncated && parse_failures == 0 && received == contracts.len();
    let stale = fresh_quote_count == 0;
    let delayed = contracts.iter().any(|row| {
        row.provider_timeframe
            .as_deref()
            .is_some_and(|timeframe| timeframe.to_ascii_lowercase().contains("delay"))
    });
    let mut blockers = Vec::new();
    if !chain_complete {
        blockers.push("FULL_CHAIN_PAGINATION_OR_IDENTITY_INCOMPLETE".to_string());
    }
    if stale {
        blockers.push("OPTION_QUOTES_STALE_AT_CAPTURE".to_string());
    }
    if live.require_realtime && delayed {
        blockers.push("PROVIDER_MARKED_OPTION_DATA_DELAYED".to_string());
    }
    if eligible < config.option_chain_min_eligible_contracts {
        blockers.push(format!(
            "INSUFFICIENT_STRICT_MODEL_CONTRACTS:{eligible}/{}<{}",
            contracts.len(),
            config.option_chain_min_eligible_contracts
        ));
    }
    if coverage.fresh_quote_coverage < config.option_chain_min_quote_coverage {
        blockers.push(format!(
            "FRESH_NBBO_COVERAGE_BELOW_GATE:{:.6}<{:.6}",
            coverage.fresh_quote_coverage, config.option_chain_min_quote_coverage
        ));
    }
    if coverage.open_interest_coverage < config.option_chain_min_open_interest_coverage {
        blockers.push(format!(
            "OPEN_INTEREST_COVERAGE_BELOW_GATE:{:.6}<{:.6}",
            coverage.open_interest_coverage, config.option_chain_min_open_interest_coverage
        ));
    }
    if coverage.greeks_coverage < config.option_chain_min_greeks_coverage {
        blockers.push(format!(
            "GREEKS_COVERAGE_BELOW_GATE:{:.6}<{:.6}",
            coverage.greeks_coverage, config.option_chain_min_greeks_coverage
        ));
    }
    let model_ready = blockers.is_empty() && !contracts.is_empty();
    let contracts_bytes = serde_json::to_vec(&contracts)?;
    let contracts_sha256 = format!("{:x}", Sha256::digest(&contracts_bytes));
    Ok(MassiveFullOptionChain {
        schema_version: OPTION_CHAIN_SCHEMA_VERSION.to_string(),
        provider: "massive".to_string(),
        source: "MASSIVE_OPRA_FULL_CHAIN".to_string(),
        underlying,
        captured_at,
        earliest_quote_at,
        latest_quote_at,
        oi_available_at: captured_at,
        open_interest_semantics:
            "PROVIDER_DAILY_OPEN_INTEREST_AS_AVAILABLE_AT_CAPTURE; NOT_INTRADAY_OI".to_string(),
        greeks_available_at: captured_at,
        realtime_required: live.require_realtime,
        chain_complete,
        model_ready,
        blockers,
        coverage,
        contracts_sha256,
        contracts,
    })
}

pub fn persist_full_option_chain(
    config: &MassiveConfig,
    snapshot: &MassiveFullOptionChain,
) -> Result<PathBuf> {
    let root = &config.option_chain_output_root;
    let path = root.join(format!(
        "{}_full_chain_latest.json",
        snapshot.underlying.to_ascii_lowercase()
    ));
    write_json_atomic(&path, snapshot)?;
    Ok(path)
}

fn parse_stock_aggregate(
    value: &Value,
    received_at: DateTime<Utc>,
    live: &LiveConfig,
) -> Result<Option<RealtimeMarketBarEnvelope>> {
    if value.get("ev").and_then(Value::as_str) != Some("AM") {
        return Ok(None);
    }
    let symbol = value
        .get("sym")
        .and_then(Value::as_str)
        .context("AM event missing sym")?
        .to_ascii_uppercase();
    let bar_start = epoch_value(value.get("s")).context("AM event missing start timestamp")?;
    let bar_end =
        epoch_value(value.get("e")).unwrap_or_else(|| bar_start + chrono::Duration::minutes(1));
    let provider_available_at = bar_end;
    let open = value
        .get("o")
        .and_then(Value::as_f64)
        .context("AM missing o")?;
    let high = value
        .get("h")
        .and_then(Value::as_f64)
        .context("AM missing h")?;
    let low = value
        .get("l")
        .and_then(Value::as_f64)
        .context("AM missing l")?;
    let close = value
        .get("c")
        .and_then(Value::as_f64)
        .context("AM missing c")?;
    let volume = value.get("v").and_then(Value::as_f64).unwrap_or(0.0);
    let stale = received_at
        .signed_duration_since(provider_available_at)
        .num_milliseconds()
        > live.stale_after_ms;
    let delayed = false;
    let bar = MarketBar {
        timestamp: bar_start,
        symbol,
        open,
        high,
        low,
        close,
        volume,
        vwap: value.get("vw").and_then(Value::as_f64),
        bid: None,
        ask: None,
        trade_count: value.get("n").and_then(Value::as_u64),
        source: "MASSIVE_SIP_STOCKS_WEBSOCKET".to_string(),
        data_quality: "provider_realtime_sip_aggregate".to_string(),
    };
    if !bar.validate() {
        bail!("Massive AM event produced an invalid OHLCV bar");
    }
    Ok(Some(RealtimeMarketBarEnvelope {
        schema_version: STOCK_EVENT_SCHEMA_VERSION.to_string(),
        provider: "massive".to_string(),
        provider_event: "AM".to_string(),
        received_at,
        provider_available_at,
        bar_start,
        bar_end,
        finalized_at: received_at,
        entitlement: "REALTIME_AUTHENTICATED".to_string(),
        delayed,
        stale,
        bar,
    }))
}

fn parse_message_values(message: Message) -> Result<Vec<Value>> {
    let text = message.into_text().context("non-text Massive message")?;
    if let Ok(values) = serde_json::from_str::<Vec<Value>>(&text) {
        return Ok(values);
    }
    Ok(vec![serde_json::from_str(&text)?])
}

fn auth_succeeded(values: &[Value]) -> bool {
    values
        .iter()
        .any(|value| value.get("status").and_then(Value::as_str) == Some("auth_success"))
}

fn auth_rejected(values: &[Value]) -> Option<String> {
    values.iter().find_map(|value| {
        let status = value.get("status").and_then(Value::as_str)?;
        if status == "auth_success" || status == "connected" {
            return None;
        }
        value
            .get("message")
            .and_then(Value::as_str)
            .map(str::to_string)
            .or_else(|| Some(status.to_string()))
    })
}

fn due_envelopes(
    pending: &mut BTreeMap<(String, i64), PendingAggregate>,
    now: DateTime<Utc>,
    grace_ms: i64,
) -> Vec<RealtimeMarketBarEnvelope> {
    let due = pending
        .iter()
        .filter(|(_, aggregate)| {
            now >= aggregate.envelope.bar_end + chrono::Duration::milliseconds(grace_ms)
        })
        .map(|(key, _)| key.clone())
        .collect::<Vec<_>>();
    due.into_iter()
        .filter_map(|key| pending.remove(&key).map(|item| item.envelope))
        .map(|mut envelope| {
            envelope.finalized_at = now;
            envelope
        })
        .collect()
}

struct StockStreamPaths<'a> {
    bars: &'a Path,
    status: &'a Path,
}

async fn stream_once(
    config: &MassiveConfig,
    live: &LiveConfig,
    api_key: &str,
    paths: &StockStreamPaths<'_>,
    max_finalized: Option<u64>,
    sender: Option<&tokio::sync::mpsc::Sender<RealtimeMarketBarEnvelope>>,
    status: &mut MassiveStreamStatus,
) -> Result<bool> {
    if live.require_realtime && endpoint_is_delayed(&config.stock_websocket_url) {
        bail!("delayed WebSocket endpoint prohibited by live.require_realtime");
    }
    let (mut socket, _) = connect_async(&config.stock_websocket_url)
        .await
        .context("connect Massive stock WebSocket")?;
    socket
        .send(Message::Text(
            json!({"action":"auth","params":api_key}).to_string().into(),
        ))
        .await?;
    tokio::time::timeout(Duration::from_secs(10), async {
        loop {
            let auth_message = socket
                .next()
                .await
                .context("Massive closed before authentication")??;
            let auth_values = parse_message_values(auth_message)?;
            if auth_succeeded(&auth_values) {
                return Ok::<_, anyhow::Error>(());
            }
            if let Some(reason) = auth_rejected(&auth_values) {
                bail!("Massive real-time authentication rejected: {reason}");
            }
        }
    })
    .await
    .context("Massive authentication timed out")??;
    status.authenticated = true;
    status.state = "AUTHENTICATED_SUBSCRIBING".to_string();
    status.blocker = None;
    status.updated_at = Utc::now();
    write_json_atomic(paths.status, status)?;
    let params = status
        .subscribed_symbols
        .iter()
        .flat_map(|symbol| {
            ["T", "Q", "A", "AM"]
                .into_iter()
                .map(move |event| format!("{event}.{symbol}"))
        })
        .collect::<Vec<_>>()
        .join(",");
    socket
        .send(Message::Text(
            json!({"action":"subscribe","params":params})
                .to_string()
                .into(),
        ))
        .await?;
    status.state = "STREAMING_REALTIME".to_string();
    status.updated_at = Utc::now();
    write_json_atomic(paths.status, status)?;
    let mut pending = BTreeMap::<(String, i64), PendingAggregate>::new();
    loop {
        let next = tokio::time::timeout(Duration::from_millis(250), socket.next()).await;
        let received_at = Utc::now();
        match next {
            Ok(Some(Ok(Message::Ping(payload)))) => {
                socket.send(Message::Pong(payload)).await?;
            }
            Ok(Some(Ok(Message::Close(_)))) | Ok(None) => {
                bail!("Massive stock WebSocket closed");
            }
            Ok(Some(Ok(message))) => {
                for value in parse_message_values(message)? {
                    if let Some(tape_event) = parse_stock_tape_event(
                        &value,
                        received_at,
                        live,
                        &config.stock_websocket_url,
                    ) {
                        crate::live::append_jsonl_rotating(
                            &config.stock_tape_output,
                            &tape_event,
                            live.raw_log_max_bytes,
                            live.raw_log_archive_count,
                        )?;
                        status.tape_events += 1;
                        match tape_event.event_type.as_str() {
                            "T" => status.trade_events += 1,
                            "Q" => status.quote_events += 1,
                            "A" => status.aggregate_second_events += 1,
                            _ => {}
                        }
                    }
                    if let Some(envelope) = parse_stock_aggregate(&value, received_at, live)? {
                        status.last_provider_event_at = Some(received_at);
                        let key = (
                            envelope.bar.symbol.clone(),
                            envelope.bar_start.timestamp_millis(),
                        );
                        pending.insert(key, PendingAggregate { envelope });
                    } else if let Some(reason) = auth_rejected(std::slice::from_ref(&value)) {
                        bail!("Massive provider status rejected stream: {reason}");
                    }
                }
            }
            Ok(Some(Err(error))) => return Err(error.into()),
            Err(_) => {}
        }
        for envelope in due_envelopes(&mut pending, received_at, live.finalize_grace_ms) {
            if live.require_realtime && (envelope.delayed || envelope.stale) {
                status.blocker = Some(if envelope.delayed {
                    "DELAYED_STOCK_BAR_REJECTED".to_string()
                } else {
                    "STALE_STOCK_BAR_REJECTED".to_string()
                });
                continue;
            }
            append_jsonl(paths.bars, &envelope)?;
            if let Some(sender) = sender {
                sender
                    .send(envelope.clone())
                    .await
                    .context("real-time model consumer stopped")?;
            }
            status.last_finalized_bar_at = Some(envelope.bar_end);
            status.finalized_bars += 1;
            status.updated_at = Utc::now();
            write_json_atomic(paths.status, status)?;
            if max_finalized.is_some_and(|limit| status.finalized_bars >= limit) {
                let _ = socket.close(None).await;
                return Ok(true);
            }
        }
    }
}

pub async fn run_stock_stream(
    config: &MassiveConfig,
    live: &LiveConfig,
    output: &Path,
    status_output: &Path,
    max_finalized: Option<u64>,
    sender: Option<tokio::sync::mpsc::Sender<RealtimeMarketBarEnvelope>>,
) -> Result<()> {
    let api_key = std::env::var(&config.api_key_env)
        .with_context(|| format!("missing {} environment variable", config.api_key_env))?;
    if live.provider != "massive" {
        bail!("run_stock_stream requires live.provider=massive");
    }
    let symbols = live
        .symbols
        .iter()
        .map(|symbol| normalize_symbol(symbol))
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    if symbols.is_empty() {
        bail!("Massive live stream requires at least one symbol");
    }
    let mut status = MassiveStreamStatus {
        schema_version: "massive_stock_stream_status.v1".to_string(),
        updated_at: Utc::now(),
        provider: "massive".to_string(),
        state: "STARTING".to_string(),
        endpoint: redact_url(&config.stock_websocket_url),
        authenticated: false,
        realtime_required: live.require_realtime,
        subscribed_symbols: symbols,
        last_provider_event_at: None,
        last_finalized_bar_at: None,
        finalized_bars: 0,
        tape_events: 0,
        trade_events: 0,
        quote_events: 0,
        aggregate_second_events: 0,
        reconnects: 0,
        blocker: None,
    };
    write_json_atomic(status_output, &status)?;
    let paths = StockStreamPaths {
        bars: output,
        status: status_output,
    };
    let mut reconnect_ms = live.reconnect_min_ms;
    loop {
        match stream_once(
            config,
            live,
            &api_key,
            &paths,
            max_finalized,
            sender.as_ref(),
            &mut status,
        )
        .await
        {
            Ok(true) => {
                status.state = "COMPLETE".to_string();
                status.updated_at = Utc::now();
                write_json_atomic(status_output, &status)?;
                return Ok(());
            }
            Ok(false) => {}
            Err(error) => {
                status.authenticated = false;
                status.state = "FAIL_CLOSED_RECONNECTING".to_string();
                status.blocker = Some(error.to_string());
                status.reconnects += 1;
                status.updated_at = Utc::now();
                write_json_atomic(status_output, &status)?;
                if max_finalized.is_some() {
                    return Err(error);
                }
            }
        }
        tokio::time::sleep(Duration::from_millis(reconnect_ms)).await;
        reconnect_ms = reconnect_ms.saturating_mul(2).min(live.reconnect_max_ms);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn delayed_endpoint_is_detected() {
        assert!(endpoint_is_delayed("wss://delayed.massive.com/stocks"));
        assert!(!endpoint_is_delayed("wss://socket.massive.com/stocks"));
    }

    #[test]
    fn parses_realtime_minute_aggregate() {
        let start = 1_721_053_800_000i64;
        let value = json!({
            "ev":"AM","sym":"SPY","v":1200.0,"op":550.0,"vw":550.2,
            "o":550.0,"c":550.5,"h":551.0,"l":549.8,"n":42,
            "s":start,"e":start + 60_000
        });
        let received = DateTime::<Utc>::from_timestamp_millis(start + 60_200).unwrap();
        let parsed = parse_stock_aggregate(&value, received, &LiveConfig::default())
            .unwrap()
            .unwrap();
        assert_eq!(parsed.bar.symbol, "SPY");
        assert_eq!(parsed.bar.close, 550.5);
        assert!(!parsed.delayed);
        assert!(!parsed.stale);
    }

    #[test]
    fn normalizes_full_stock_quote_and_preserves_raw_payload() {
        let timestamp = 1_721_053_860_000i64;
        let received =
            DateTime::<Utc>::from_timestamp_millis(timestamp + 20).expect("valid timestamp");
        let value = json!({
            "ev":"Q","sym":"SPY","bp":550.10,"bs":2,
            "ap":550.12,"as":3,"t":timestamp,"q":50385480,"z":3
        });
        let event = parse_stock_tape_event(
            &value,
            received,
            &LiveConfig::default(),
            "wss://socket.massive.com/stocks",
        )
        .expect("quote event");
        assert_eq!(event.event_type, "Q");
        assert_eq!(event.bid, Some(550.10));
        assert_eq!(event.ask, Some(550.12));
        assert_eq!(event.sequence, Some(50_385_480));
        assert!(event.model_eligible);
        assert_eq!(event.raw, value);
    }

    #[test]
    fn contract_missing_opra_fields_is_not_model_eligible() {
        let row = json!({
            "details":{
                "ticker":"O:SPY260724C00550000",
                "expiration_date":"2026-07-24",
                "strike_price":550.0,
                "contract_type":"call"
            },
            "last_quote":{"last_updated":1_721_053_860_000_000_000i64,"bid":1.0,"ask":1.1}
        });
        let contract = parse_contract(
            &row,
            "SPY",
            DateTime::parse_from_rfc3339("2026-07-23T20:00:00Z")
                .unwrap()
                .with_timezone(&Utc),
        )
        .unwrap();
        assert!(!contract.model_eligible);
        assert!(
            contract
                .ineligibility_reasons
                .contains(&"MISSING_OPEN_INTEREST".to_string())
        );
    }

    #[test]
    fn due_finalizer_keeps_latest_update_per_symbol_minute() {
        let start = DateTime::parse_from_rfc3339("2026-07-23T19:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let end = start + chrono::Duration::minutes(1);
        let envelope = RealtimeMarketBarEnvelope {
            schema_version: STOCK_EVENT_SCHEMA_VERSION.to_string(),
            provider: "massive".to_string(),
            provider_event: "AM".to_string(),
            received_at: end,
            provider_available_at: end,
            bar_start: start,
            bar_end: end,
            finalized_at: end,
            entitlement: "REALTIME_AUTHENTICATED".to_string(),
            delayed: false,
            stale: false,
            bar: MarketBar {
                timestamp: start,
                symbol: "SPY".to_string(),
                open: 1.0,
                high: 1.2,
                low: 0.9,
                close: 1.1,
                volume: 10.0,
                vwap: None,
                bid: None,
                ask: None,
                trade_count: None,
                source: "test".to_string(),
                data_quality: "test".to_string(),
            },
        };
        let mut pending = BTreeMap::new();
        pending.insert(
            ("SPY".to_string(), start.timestamp_millis()),
            PendingAggregate { envelope },
        );
        assert!(due_envelopes(&mut pending, end, 2_000).is_empty());
        assert_eq!(
            due_envelopes(
                &mut pending,
                end + chrono::Duration::milliseconds(2_001),
                2_000
            )
            .len(),
            1
        );
    }
}
