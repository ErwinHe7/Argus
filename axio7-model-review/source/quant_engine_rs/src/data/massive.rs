use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
    time::{Duration, Instant},
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Days, NaiveDate, Utc};
use chrono_tz::America::New_York;
use reqwest::{Client, Url};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::{
    config::{DataConfig, MassiveConfig},
    domain::MarketBar,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveStatus {
    pub enabled: bool,
    pub api_key_env: String,
    pub api_key_present: bool,
    pub symbols: Vec<String>,
    pub index_symbols: Vec<String>,
    pub history_transport: String,
    pub live_transport: String,
    pub entitlement_note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveSyncReceipt {
    pub output: PathBuf,
    pub rows: usize,
    pub symbols: Vec<String>,
    pub start: NaiveDate,
    pub end: NaiveDate,
    pub raw_files_created: usize,
    #[serde(default)]
    pub raw_files_refreshed: usize,
    pub raw_files_reused: usize,
    pub sha256: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ChunkCacheOutcome {
    Created,
    Refreshed,
    Reused,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AggregateResponse {
    #[serde(default)]
    status: String,
    #[serde(default)]
    ticker: String,
    #[serde(default)]
    results: Vec<Aggregate>,
    #[serde(default)]
    error: Option<String>,
    #[serde(default)]
    message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Aggregate {
    t: i64,
    o: f64,
    h: f64,
    l: f64,
    c: f64,
    #[serde(default)]
    v: f64,
    #[serde(default)]
    vw: Option<f64>,
    #[serde(default)]
    n: Option<u64>,
}

pub fn status(config: &MassiveConfig) -> MassiveStatus {
    MassiveStatus {
        enabled: config.enabled,
        api_key_env: config.api_key_env.clone(),
        api_key_present: std::env::var_os(&config.api_key_env).is_some(),
        symbols: config.symbols.clone(),
        index_symbols: config.index_symbols.clone(),
        history_transport: "REST custom 1-minute aggregates".to_string(),
        live_transport: format!(
            "licensed SIP WebSocket {} plus paginated OPRA full-chain snapshots; historical REST remains a separate offline path",
            config.stock_websocket_url
        ),
        entitlement_note: "The runtime authenticates and probes stock/option entitlements before streaming. Delayed, unauthorized, stale, truncated, or field-incomplete responses are persisted as blockers and never replaced with synthetic rows.".to_string(),
    }
}

fn is_index_symbol(symbol: &str) -> bool {
    symbol.starts_with("I:")
}

fn canonical_symbol(symbol: &str) -> String {
    symbol
        .strip_prefix("I:")
        .unwrap_or(symbol)
        .to_ascii_uppercase()
}

fn raw_path(root: &Path, symbol: &str, start: NaiveDate, end: NaiveDate) -> PathBuf {
    root.join("massive")
        .join(if is_index_symbol(symbol) {
            "indices_1m"
        } else {
            "stocks_1m"
        })
        .join(canonical_symbol(symbol))
        .join(format!("{start}_{end}.json"))
}

fn should_refresh_chunk(end: NaiveDate, now: DateTime<Utc>) -> bool {
    end >= now.with_timezone(&New_York).date_naive()
}

fn response_to_bars(response: AggregateResponse, requested_symbol: &str) -> Result<Vec<MarketBar>> {
    if response.status.eq_ignore_ascii_case("ERROR") || response.error.is_some() {
        bail!(
            "Massive rejected {requested_symbol}: {}",
            response
                .error
                .or(response.message)
                .unwrap_or_else(|| "unknown provider error".into())
        );
    }
    let provider_symbol = if response.ticker.is_empty() {
        requested_symbol
    } else {
        &response.ticker
    };
    let index = is_index_symbol(requested_symbol) || is_index_symbol(provider_symbol);
    let symbol = canonical_symbol(provider_symbol);
    let mut bars = Vec::with_capacity(response.results.len());
    for row in response.results {
        let Some(timestamp) = DateTime::<Utc>::from_timestamp_millis(row.t) else {
            continue;
        };
        let bar = MarketBar {
            timestamp,
            symbol: symbol.clone(),
            open: row.o,
            high: row.h,
            low: row.l,
            close: row.c,
            volume: row.v,
            vwap: row.vw,
            bid: None,
            ask: None,
            trade_count: row.n,
            source: if index {
                "MASSIVE_INDICES_AGG_1M"
            } else {
                "MASSIVE_STOCKS_AGG_1M"
            }
            .to_string(),
            data_quality: if index {
                "vendor_index_value_aggregate_no_consolidated_volume"
            } else {
                "vendor_aggregate_adjusted_full_market"
            }
            .to_string(),
        };
        if bar.validate() {
            bars.push(bar);
        }
    }
    Ok(bars)
}

async fn get_chunk(
    client: &Client,
    config: &MassiveConfig,
    data: &DataConfig,
    key: &str,
    symbol: &str,
    start: NaiveDate,
    end: NaiveDate,
) -> Result<(Vec<MarketBar>, ChunkCacheOutcome)> {
    let path = raw_path(&data.raw_root, symbol, start, end);
    let existed = path.exists();
    let refresh = should_refresh_chunk(end, Utc::now());
    let (bytes, outcome) = if existed && !refresh {
        (fs::read(&path)?, ChunkCacheOutcome::Reused)
    } else {
        let mut url = Url::parse(&format!(
            "{}/v2/aggs/ticker/{symbol}/range/1/minute/{start}/{end}",
            config.base_url.trim_end_matches('/')
        ))?;
        url.query_pairs_mut()
            .append_pair("adjusted", "true")
            .append_pair("sort", "asc")
            .append_pair("limit", "50000")
            .append_pair("apiKey", key);
        let mut attempt = 0_u32;
        let body = loop {
            let response = client
                .get(url.clone())
                .send()
                .await
                .context("Massive request failed")?;
            let status = response.status();
            let retry_after = response
                .headers()
                .get(reqwest::header::RETRY_AFTER)
                .and_then(|value| value.to_str().ok())
                .and_then(|value| value.parse::<u64>().ok());
            let body = response.bytes().await?;
            if status.is_success() {
                break body;
            }
            if status == reqwest::StatusCode::TOO_MANY_REQUESTS && attempt < 6 {
                let delay_seconds = retry_after.unwrap_or(13 + 7 * u64::from(attempt));
                attempt += 1;
                tokio::time::sleep(Duration::from_secs(delay_seconds)).await;
                continue;
            }
            let detail = String::from_utf8_lossy(&body);
            bail!("Massive HTTP {status} for {symbol} {start}..{end}: {detail}");
        };
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let temporary = path.with_extension("json.partial");
        fs::write(&temporary, &body)?;
        if path.exists() {
            fs::remove_file(&path).with_context(|| format!("cannot replace {}", path.display()))?;
        }
        fs::rename(temporary, &path)?;
        (
            body.to_vec(),
            if existed {
                ChunkCacheOutcome::Refreshed
            } else {
                ChunkCacheOutcome::Created
            },
        )
    };
    let parsed: AggregateResponse = serde_json::from_slice(&bytes)
        .with_context(|| format!("invalid Massive JSON in {}", path.display()))?;
    Ok((response_to_bars(parsed, symbol)?, outcome))
}

pub async fn sync(
    data: &DataConfig,
    start: NaiveDate,
    end: NaiveDate,
    symbols_override: Option<Vec<String>>,
    output: &Path,
) -> Result<MassiveSyncReceipt> {
    let config = &data.massive;
    if !config.enabled {
        bail!("Massive adapter is disabled");
    }
    if start > end {
        bail!("start must be <= end");
    }
    let key = std::env::var(&config.api_key_env)
        .with_context(|| format!("missing {} environment variable", config.api_key_env))?;
    let symbols = symbols_override.unwrap_or_else(|| {
        let mut symbols = config.symbols.clone();
        symbols.extend(config.index_symbols.iter().cloned());
        symbols
    });
    if symbols.is_empty() {
        bail!("no Massive symbols requested");
    }
    let client = Client::builder().user_agent("AXIO7-Quant/0.1").build()?;
    let mut merged = BTreeMap::<(i64, String), MarketBar>::new();
    if output.exists() {
        let imported = crate::data::csv_import::MarketBarCsvImporter;
        use crate::data::LicensedFileImporter;
        for bar in imported.import(output)?.records {
            merged.insert((bar.timestamp.timestamp_millis(), bar.symbol.clone()), bar);
        }
    }
    let mut created = 0;
    let mut refreshed = 0;
    let mut reused = 0;
    let mut last_network_call: Option<Instant> = None;
    for symbol in &symbols {
        let mut chunk_start = start;
        while chunk_start <= end {
            let chunk_end = chunk_start
                .checked_add_days(Days::new((config.chunk_days - 1) as u64))
                .unwrap_or(end)
                .min(end);
            let cached = raw_path(&data.raw_root, symbol, chunk_start, chunk_end).exists()
                && !should_refresh_chunk(chunk_end, Utc::now());
            if !cached {
                if let Some(last) = last_network_call {
                    let required = Duration::from_millis(config.request_interval_ms);
                    if let Some(wait) = required.checked_sub(last.elapsed()) {
                        tokio::time::sleep(wait).await;
                    }
                }
                last_network_call = Some(Instant::now());
            }
            let (bars, cache_outcome) =
                get_chunk(&client, config, data, &key, symbol, chunk_start, chunk_end).await?;
            match cache_outcome {
                ChunkCacheOutcome::Created => created += 1,
                ChunkCacheOutcome::Refreshed => refreshed += 1,
                ChunkCacheOutcome::Reused => reused += 1,
            }
            for bar in bars {
                merged.insert((bar.timestamp.timestamp_millis(), bar.symbol.clone()), bar);
            }
            chunk_start = chunk_end
                .checked_add_days(Days::new(1))
                .context("date overflow")?;
        }
    }
    if merged.is_empty() {
        bail!("Massive sync produced no valid bars");
    }
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }
    let temporary = output.with_extension("csv.partial");
    let mut writer = csv::Writer::from_path(&temporary)?;
    writer.write_record([
        "timestamp",
        "symbol",
        "open",
        "high",
        "low",
        "close",
        "volume",
        "vwap",
        "bid",
        "ask",
        "trade_count",
        "source",
        "data_quality",
    ])?;
    for bar in merged.values() {
        writer.serialize((
            bar.timestamp.to_rfc3339(),
            &bar.symbol,
            bar.open,
            bar.high,
            bar.low,
            bar.close,
            bar.volume,
            bar.vwap,
            bar.bid,
            bar.ask,
            bar.trade_count,
            &bar.source,
            &bar.data_quality,
        ))?;
    }
    writer.flush()?;
    if output.exists() {
        fs::remove_file(output).with_context(|| format!("cannot replace {}", output.display()))?;
    }
    fs::rename(&temporary, output)?;
    let content = fs::read(output)?;
    let sha256 = format!("{:x}", Sha256::digest(&content));
    let receipt = MassiveSyncReceipt {
        output: output.to_path_buf(),
        rows: merged.len(),
        symbols: symbols.clone(),
        start,
        end,
        raw_files_created: created,
        raw_files_refreshed: refreshed,
        raw_files_reused: reused,
        sha256,
    };
    let manifest = data
        .manifest_root
        .join(format!("massive_sync_{start}_{end}.json"));
    if let Some(parent) = manifest.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(manifest, serde_json::to_vec_pretty(&receipt)?)?;
    Ok(receipt)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn massive_response_maps_only_valid_bars() {
        let response = AggregateResponse {
            status: "OK".into(),
            ticker: "SPY".into(),
            error: None,
            message: None,
            results: vec![
                Aggregate {
                    t: 1_720_000_000_000,
                    o: 500.0,
                    h: 501.0,
                    l: 499.0,
                    c: 500.5,
                    v: 10.0,
                    vw: Some(500.2),
                    n: Some(4),
                },
                Aggregate {
                    t: 1_720_000_060_000,
                    o: 0.0,
                    h: 0.0,
                    l: 0.0,
                    c: 0.0,
                    v: 0.0,
                    vw: None,
                    n: None,
                },
            ],
        };
        let bars = response_to_bars(response, "SPY").unwrap();
        assert_eq!(bars.len(), 1);
        assert_eq!(bars[0].source, "MASSIVE_STOCKS_AGG_1M");
    }

    #[test]
    fn index_response_preserves_asset_class_and_does_not_invent_volume() {
        let response = AggregateResponse {
            status: "OK".into(),
            ticker: "I:SPX".into(),
            error: None,
            message: None,
            results: vec![Aggregate {
                t: 1_720_000_000_000,
                o: 5_500.0,
                h: 5_501.0,
                l: 5_499.0,
                c: 5_500.5,
                v: 0.0,
                vw: None,
                n: None,
            }],
        };
        let bars = response_to_bars(response, "I:SPX").unwrap();
        assert_eq!(bars.len(), 1);
        assert_eq!(bars[0].symbol, "SPX");
        assert_eq!(bars[0].volume, 0.0);
        assert_eq!(bars[0].source, "MASSIVE_INDICES_AGG_1M");
        assert!(bars[0].data_quality.contains("no_consolidated_volume"));
    }

    #[test]
    fn only_chunks_ending_before_the_market_date_are_immutable_cache() {
        let now = DateTime::parse_from_rfc3339("2026-07-23T13:15:00Z")
            .unwrap()
            .with_timezone(&Utc);
        assert!(!should_refresh_chunk(
            NaiveDate::from_ymd_opt(2026, 7, 22).unwrap(),
            now
        ));
        assert!(should_refresh_chunk(
            NaiveDate::from_ymd_opt(2026, 7, 23).unwrap(),
            now
        ));
        assert!(should_refresh_chunk(
            NaiveDate::from_ymd_opt(2026, 7, 24).unwrap(),
            now
        ));
    }
}
