use std::path::Path;

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use databento::dbn::{
    CbboMsg, OhlcvMsg,
    decode::{DbnDecoder, DbnMetadata, DecodeRecordRef},
    symbol_map::SymbolIndex,
};

use crate::domain::{MarketBar, RawOptionNbbo};

const FIXED_PRICE_SCALE: f64 = 1_000_000_000.0;

fn utc_from_nanos(value: u64) -> Result<DateTime<Utc>> {
    let nanos: i64 = value
        .try_into()
        .context("timestamp exceeds signed nanosecond range")?;
    Ok(DateTime::<Utc>::from_timestamp_nanos(nanos))
}

pub fn read_ohlcv(path: &Path, symbol_alias: Option<&str>) -> Result<Vec<MarketBar>> {
    let mut decoder = DbnDecoder::from_zstd_file(path)
        .with_context(|| format!("failed opening DBN OHLCV file {}", path.display()))?;
    let symbol_map = decoder.metadata().symbol_map()?;
    let dataset = decoder.metadata().dataset.clone();
    let mut output = Vec::new();
    while let Some(record) = decoder.decode_record_ref()? {
        let Some(bar) = record.get::<OhlcvMsg>() else {
            continue;
        };
        let mapped = symbol_map
            .get_for_rec(bar)
            .cloned()
            .unwrap_or_else(|| format!("instrument_id:{}", bar.hd.instrument_id));
        let symbol = symbol_alias.map(str::to_string).unwrap_or(mapped);
        let row = MarketBar {
            timestamp: utc_from_nanos(bar.hd.ts_event)?,
            symbol,
            open: bar.open as f64 / FIXED_PRICE_SCALE,
            high: bar.high as f64 / FIXED_PRICE_SCALE,
            low: bar.low as f64 / FIXED_PRICE_SCALE,
            close: bar.close as f64 / FIXED_PRICE_SCALE,
            volume: bar.volume as f64,
            vwap: None,
            bid: None,
            ask: None,
            trade_count: None,
            source: format!("Databento/{dataset}"),
            data_quality: "vendor_original_dbn".to_string(),
        };
        if row.validate() {
            output.push(row);
        }
    }
    output.sort_by_key(|row| row.timestamp);
    Ok(output)
}

pub fn read_cbbo(path: &Path) -> Result<Vec<RawOptionNbbo>> {
    let mut decoder = DbnDecoder::from_zstd_file(path)
        .with_context(|| format!("failed opening DBN CBBO file {}", path.display()))?;
    let symbol_map = decoder.metadata().symbol_map()?;
    let dataset = decoder.metadata().dataset.clone();
    let mut output = Vec::new();
    while let Some(record) = decoder.decode_record_ref()? {
        let Some(quote) = record.get::<CbboMsg>() else {
            continue;
        };
        let level = &quote.levels[0];
        let bid = level.bid_px as f64 / FIXED_PRICE_SCALE;
        let ask = level.ask_px as f64 / FIXED_PRICE_SCALE;
        if bid <= 0.0 || ask <= bid || level.bid_sz == 0 || level.ask_sz == 0 {
            continue;
        }
        output.push(RawOptionNbbo {
            timestamp: utc_from_nanos(quote.ts_recv)?,
            instrument_id: quote.hd.instrument_id,
            option_symbol: symbol_map
                .get_for_rec(quote)
                .cloned()
                .unwrap_or_else(|| format!("instrument_id:{}", quote.hd.instrument_id)),
            bid,
            ask,
            bid_size: level.bid_sz,
            ask_size: level.ask_sz,
            last: (quote.price > 0).then_some(quote.price as f64 / FIXED_PRICE_SCALE),
            source: format!("Databento/{dataset}"),
        });
    }
    output.sort_by_key(|row| row.timestamp);
    Ok(output)
}

pub fn write_ohlcv_csv(input: &Path, output: &Path, symbol_alias: Option<&str>) -> Result<usize> {
    let records = read_ohlcv(input, symbol_alias)?;
    if let Some(parent) = output.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut writer = csv::Writer::from_path(output)?;
    for row in &records {
        writer.serialize(row)?;
    }
    writer.flush()?;
    Ok(records.len())
}

pub fn write_cbbo_csv(input: &Path, output: &Path) -> Result<usize> {
    let records = read_cbbo(input)?;
    if let Some(parent) = output.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut writer = csv::Writer::from_path(output)?;
    for row in &records {
        writer.serialize(row)?;
    }
    writer.flush()?;
    Ok(records.len())
}
