use std::{collections::HashSet, fs, path::Path};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::{
    data::LicensedFileImporter,
    domain::{CallPut, MarketBar, OptionQuote},
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportReport<T> {
    pub records: Vec<T>,
    pub input_rows: usize,
    pub accepted_rows: usize,
    pub duplicate_rows: usize,
    pub rejected_rows: usize,
    pub source_path: String,
}

#[derive(Debug, Deserialize)]
struct MarketBarRow {
    timestamp: String,
    symbol: String,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    #[serde(default)]
    vwap: Option<f64>,
    #[serde(default)]
    bid: Option<f64>,
    #[serde(default)]
    ask: Option<f64>,
    #[serde(default)]
    trade_count: Option<u64>,
    source: String,
    #[serde(default = "default_quality")]
    data_quality: String,
}

fn default_quality() -> String {
    "vendor_original".to_string()
}

pub struct MarketBarCsvImporter;

impl LicensedFileImporter for MarketBarCsvImporter {
    type Output = ImportReport<MarketBar>;

    fn import(&self, input: &Path) -> Result<Self::Output> {
        let mut reader = csv::ReaderBuilder::new()
            .flexible(false)
            .from_path(input)
            .with_context(|| format!("cannot open market bar CSV {}", input.display()))?;
        let mut input_rows = 0;
        let mut rejected_rows = 0;
        let mut duplicate_rows = 0;
        let mut seen = HashSet::new();
        let mut records = Vec::new();
        for row in reader.deserialize::<MarketBarRow>() {
            input_rows += 1;
            let row = match row {
                Ok(value) => value,
                Err(_) => {
                    rejected_rows += 1;
                    continue;
                }
            };
            // Offset is mandatory. Naive local timestamps are rejected because DST would be ambiguous.
            let timestamp = match DateTime::parse_from_rfc3339(&row.timestamp) {
                Ok(value) => value.with_timezone(&Utc),
                Err(_) => {
                    rejected_rows += 1;
                    continue;
                }
            };
            let bar = MarketBar {
                timestamp,
                symbol: row.symbol.trim().to_uppercase(),
                open: row.open,
                high: row.high,
                low: row.low,
                close: row.close,
                volume: row.volume,
                vwap: row.vwap,
                bid: row.bid,
                ask: row.ask,
                trade_count: row.trade_count,
                source: row.source,
                data_quality: row.data_quality,
            };
            if !bar.validate() {
                rejected_rows += 1;
                continue;
            }
            let key = (
                bar.symbol.clone(),
                bar.timestamp.timestamp_nanos_opt().unwrap_or_default(),
            );
            if !seen.insert(key) {
                duplicate_rows += 1;
                continue;
            }
            records.push(bar);
        }
        records.sort_by(|a, b| (a.timestamp, &a.symbol).cmp(&(b.timestamp, &b.symbol)));
        let accepted_rows = records.len();
        if accepted_rows == 0 {
            bail!("{} contained no valid market bars", input.display());
        }
        Ok(ImportReport {
            records,
            input_rows,
            accepted_rows,
            duplicate_rows,
            rejected_rows,
            source_path: input.display().to_string(),
        })
    }
}

#[derive(Debug, Deserialize)]
struct OptionQuoteRow {
    timestamp: String,
    underlying: String,
    option_symbol: String,
    expiry: String,
    dte: i32,
    strike: f64,
    call_put: String,
    bid: f64,
    ask: f64,
    bid_size: u32,
    ask_size: u32,
    #[serde(default)]
    last: Option<f64>,
    #[serde(default)]
    volume: Option<u64>,
    #[serde(default)]
    open_interest: Option<u64>,
    #[serde(default)]
    iv: Option<f64>,
    #[serde(default)]
    delta: Option<f64>,
    #[serde(default)]
    gamma: Option<f64>,
    #[serde(default)]
    theta: Option<f64>,
    #[serde(default)]
    vega: Option<f64>,
    underlying_price: f64,
    source: String,
}

pub struct CboeOptionCsvImporter;

impl LicensedFileImporter for CboeOptionCsvImporter {
    type Output = ImportReport<OptionQuote>;

    fn import(&self, input: &Path) -> Result<Self::Output> {
        let mut reader = csv::ReaderBuilder::new()
            .flexible(false)
            .from_path(input)
            .with_context(|| format!("cannot open option quote CSV {}", input.display()))?;
        let mut input_rows = 0;
        let mut rejected_rows = 0;
        let mut duplicate_rows = 0;
        let mut seen = HashSet::new();
        let mut records = Vec::new();
        for row in reader.deserialize::<OptionQuoteRow>() {
            input_rows += 1;
            let row = match row {
                Ok(value) => value,
                Err(_) => {
                    rejected_rows += 1;
                    continue;
                }
            };
            let timestamp = match DateTime::parse_from_rfc3339(&row.timestamp) {
                Ok(value) => value.with_timezone(&Utc),
                Err(_) => {
                    rejected_rows += 1;
                    continue;
                }
            };
            let expiry = match NaiveDate::parse_from_str(&row.expiry, "%Y-%m-%d") {
                Ok(value) => value,
                Err(_) => {
                    rejected_rows += 1;
                    continue;
                }
            };
            let call_put = match row.call_put.to_ascii_uppercase().as_str() {
                "C" | "CALL" => CallPut::Call,
                "P" | "PUT" => CallPut::Put,
                _ => {
                    rejected_rows += 1;
                    continue;
                }
            };
            let quote = OptionQuote {
                timestamp,
                underlying: row.underlying,
                option_symbol: row.option_symbol,
                expiry,
                dte: row.dte,
                strike: row.strike,
                call_put,
                bid: row.bid,
                ask: row.ask,
                bid_size: row.bid_size,
                ask_size: row.ask_size,
                last: row.last,
                volume: row.volume,
                open_interest_at_open: row.open_interest,
                iv: row.iv,
                delta: row.delta,
                gamma: row.gamma,
                theta: row.theta,
                vega: row.vega,
                underlying_price: row.underlying_price,
                source: row.source,
            };
            if quote.bid <= 0.0
                || quote.ask <= quote.bid
                || quote.bid_size == 0
                || quote.ask_size == 0
            {
                rejected_rows += 1;
                continue;
            }
            let key = (
                quote.option_symbol.clone(),
                quote.timestamp.timestamp_nanos_opt().unwrap_or_default(),
            );
            if !seen.insert(key) {
                duplicate_rows += 1;
                continue;
            }
            records.push(quote);
        }
        records
            .sort_by(|a, b| (a.timestamp, &a.option_symbol).cmp(&(b.timestamp, &b.option_symbol)));
        let accepted_rows = records.len();
        if accepted_rows == 0 {
            bail!("{} contained no valid option quotes", input.display());
        }
        Ok(ImportReport {
            records,
            input_rows,
            accepted_rows,
            duplicate_rows,
            rejected_rows,
            source_path: input.display().to_string(),
        })
    }
}

pub fn copy_licensed_input(input: &Path, destination: &Path) -> Result<u64> {
    if destination.exists() {
        bail!("refusing to overwrite {}", destination.display());
    }
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent)?;
    }
    Ok(fs::copy(input, destination)?)
}
