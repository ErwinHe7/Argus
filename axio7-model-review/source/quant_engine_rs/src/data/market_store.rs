use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, Utc};
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::domain::MarketBar;

const SCHEMA: &str = r#"
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS market_data_batches (
    batch_id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    dataset TEXT NOT NULL,
    source_file_sha256 TEXT NOT NULL,
    source_path TEXT NOT NULL,
    captured_at TEXT NOT NULL,
    availability_policy TEXT NOT NULL,
    availability_delay_seconds INTEGER NOT NULL,
    license_scope TEXT NOT NULL,
    license_reference TEXT NOT NULL,
    input_rows INTEGER NOT NULL,
    accepted_rows INTEGER NOT NULL,
    duplicate_rows INTEGER NOT NULL,
    rejected_rows INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS minute_bars (
    batch_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    event_at TEXT NOT NULL,
    available_at TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    open REAL NOT NULL,
    high REAL NOT NULL,
    low REAL NOT NULL,
    close REAL NOT NULL,
    volume REAL NOT NULL,
    vwap REAL,
    bid REAL,
    ask REAL,
    trade_count INTEGER,
    source TEXT NOT NULL,
    data_quality TEXT NOT NULL,
    PRIMARY KEY (batch_id, symbol, event_at),
    FOREIGN KEY (batch_id) REFERENCES market_data_batches(batch_id)
);

CREATE INDEX IF NOT EXISTS idx_minute_bars_symbol_event
    ON minute_bars(symbol, event_at);
CREATE INDEX IF NOT EXISTS idx_minute_bars_symbol_available
    ON minute_bars(symbol, available_at);

CREATE TRIGGER IF NOT EXISTS market_data_batches_no_update
BEFORE UPDATE ON market_data_batches
BEGIN
    SELECT RAISE(ABORT, 'market data batches are append-only');
END;
CREATE TRIGGER IF NOT EXISTS market_data_batches_no_delete
BEFORE DELETE ON market_data_batches
BEGIN
    SELECT RAISE(ABORT, 'market data batches are append-only');
END;
CREATE TRIGGER IF NOT EXISTS minute_bars_no_update
BEFORE UPDATE ON minute_bars
BEGIN
    SELECT RAISE(ABORT, 'minute bars are append-only');
END;
CREATE TRIGGER IF NOT EXISTS minute_bars_no_delete
BEFORE DELETE ON minute_bars
BEGIN
    SELECT RAISE(ABORT, 'minute bars are append-only');
END;
"#;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AvailabilityPolicy {
    /// Safest policy for a backfill with unknown historical publication time.
    /// The rows cannot be consumed before the actual ingestion timestamp.
    ObservedAtIngestion,
    /// The vendor contract explicitly defines the value as a completed
    /// one-minute aggregate. A non-negative entitlement delay is added.
    CompletedMinuteEndPlusDelay,
}

impl AvailabilityPolicy {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::ObservedAtIngestion => "OBSERVED_AT_INGESTION",
            Self::CompletedMinuteEndPlusDelay => "COMPLETED_MINUTE_END_PLUS_DELAY",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum LicenseScope {
    ResearchOnly,
    InternalDisplay,
    PublicRedistribution,
}

impl LicenseScope {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::ResearchOnly => "RESEARCH_ONLY",
            Self::InternalDisplay => "INTERNAL_DISPLAY",
            Self::PublicRedistribution => "PUBLIC_REDISTRIBUTION",
        }
    }
}

#[derive(Debug, Clone)]
pub struct MaterializeRequest {
    pub database: PathBuf,
    pub source_path: PathBuf,
    pub provider: String,
    pub dataset: String,
    pub captured_at: DateTime<Utc>,
    pub availability_policy: AvailabilityPolicy,
    pub availability_delay_seconds: i64,
    pub license_scope: LicenseScope,
    pub license_reference: String,
    pub input_rows: usize,
    pub accepted_rows: usize,
    pub duplicate_rows: usize,
    pub rejected_rows: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterializeReceipt {
    pub status: String,
    pub database: PathBuf,
    pub batch_id: String,
    pub source_file_sha256: String,
    pub accepted_rows: usize,
    pub inserted_rows: usize,
    pub symbols: Vec<String>,
    pub first_event_at: DateTime<Utc>,
    pub last_event_at: DateTime<Utc>,
    pub captured_at: DateTime<Utc>,
    pub availability_policy: String,
    pub availability_delay_seconds: i64,
    pub license_scope: String,
    pub license_reference: String,
    pub public_product_eligible: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SymbolCoverage {
    pub symbol: String,
    pub rows: u64,
    pub first_event_at: String,
    pub last_event_at: String,
    pub latest_available_at: String,
    pub providers: Vec<String>,
    pub license_scopes: Vec<String>,
    pub public_product_eligible: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarketStoreCoverage {
    pub database: PathBuf,
    pub batches: u64,
    pub rows: u64,
    pub symbols: Vec<SymbolCoverage>,
}

pub struct MarketDataStore {
    path: PathBuf,
    connection: Connection,
}

impl MarketDataStore {
    pub fn open(path: &Path) -> Result<Self> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("cannot open market data store {}", path.display()))?;
        connection.execute_batch(SCHEMA)?;
        Ok(Self {
            path: path.to_path_buf(),
            connection,
        })
    }

    pub fn materialize(
        &mut self,
        request: &MaterializeRequest,
        bars: &[MarketBar],
    ) -> Result<MaterializeReceipt> {
        validate_request(request, bars)?;
        let source_file_sha256 = sha256_file(&request.source_path)?;
        let batch_id = batch_id(request, &source_file_sha256);
        let existing = self
            .connection
            .query_row(
                "SELECT accepted_rows FROM market_data_batches WHERE batch_id = ?1",
                params![batch_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()?;

        let symbols = bars
            .iter()
            .map(|bar| bar.symbol.clone())
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>();
        let first_event_at = bars.first().expect("validated non-empty bars").timestamp;
        let last_event_at = bars.last().expect("validated non-empty bars").timestamp;

        if let Some(accepted_rows) = existing {
            return Ok(MaterializeReceipt {
                status: "ALREADY_MATERIALIZED".to_string(),
                database: self.path.clone(),
                batch_id,
                source_file_sha256,
                accepted_rows: accepted_rows as usize,
                inserted_rows: 0,
                symbols,
                first_event_at,
                last_event_at,
                captured_at: request.captured_at,
                availability_policy: request.availability_policy.as_str().to_string(),
                availability_delay_seconds: request.availability_delay_seconds,
                license_scope: request.license_scope.as_str().to_string(),
                license_reference: request.license_reference.clone(),
                public_product_eligible: request.license_scope
                    == LicenseScope::PublicRedistribution,
            });
        }

        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)?;
        transaction.execute(
            "INSERT INTO market_data_batches (
                batch_id, provider, dataset, source_file_sha256, source_path,
                captured_at, availability_policy, availability_delay_seconds,
                license_scope, license_reference, input_rows, accepted_rows,
                duplicate_rows, rejected_rows
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
            params![
                batch_id,
                request.provider.trim(),
                request.dataset.trim(),
                source_file_sha256,
                request.source_path.display().to_string(),
                request.captured_at.to_rfc3339(),
                request.availability_policy.as_str(),
                request.availability_delay_seconds,
                request.license_scope.as_str(),
                request.license_reference.trim(),
                request.input_rows as i64,
                request.accepted_rows as i64,
                request.duplicate_rows as i64,
                request.rejected_rows as i64,
            ],
        )?;
        {
            let mut insert = transaction.prepare(
                "INSERT INTO minute_bars (
                    batch_id, symbol, event_at, available_at, recorded_at,
                    open, high, low, close, volume, vwap, bid, ask, trade_count,
                    source, data_quality
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16)",
            )?;
            for bar in bars {
                let available_at = match request.availability_policy {
                    AvailabilityPolicy::ObservedAtIngestion => request.captured_at,
                    AvailabilityPolicy::CompletedMinuteEndPlusDelay => {
                        bar.timestamp + Duration::seconds(60 + request.availability_delay_seconds)
                    }
                };
                insert.execute(params![
                    batch_id,
                    bar.symbol,
                    bar.timestamp.to_rfc3339(),
                    available_at.to_rfc3339(),
                    request.captured_at.to_rfc3339(),
                    bar.open,
                    bar.high,
                    bar.low,
                    bar.close,
                    bar.volume,
                    bar.vwap,
                    bar.bid,
                    bar.ask,
                    bar.trade_count.map(|value| value as i64),
                    bar.source,
                    bar.data_quality,
                ])?;
            }
        }
        transaction.commit()?;

        Ok(MaterializeReceipt {
            status: "MATERIALIZED_APPEND_ONLY".to_string(),
            database: self.path.clone(),
            batch_id,
            source_file_sha256,
            accepted_rows: bars.len(),
            inserted_rows: bars.len(),
            symbols,
            first_event_at,
            last_event_at,
            captured_at: request.captured_at,
            availability_policy: request.availability_policy.as_str().to_string(),
            availability_delay_seconds: request.availability_delay_seconds,
            license_scope: request.license_scope.as_str().to_string(),
            license_reference: request.license_reference.clone(),
            public_product_eligible: request.license_scope == LicenseScope::PublicRedistribution,
        })
    }

    pub fn coverage(&self) -> Result<MarketStoreCoverage> {
        let batches =
            (self
                .connection
                .query_row("SELECT COUNT(*) FROM market_data_batches", [], |row| {
                    row.get::<_, i64>(0)
                })?) as u64;
        let rows = (self
            .connection
            .query_row("SELECT COUNT(*) FROM minute_bars", [], |row| {
                row.get::<_, i64>(0)
            })?) as u64;
        let mut statement = self.connection.prepare(
            "SELECT b.symbol, COUNT(*), MIN(b.event_at), MAX(b.event_at),
                    MAX(b.available_at), d.provider, d.license_scope
             FROM minute_bars b
             JOIN market_data_batches d ON d.batch_id = b.batch_id
             GROUP BY b.symbol, d.provider, d.license_scope
             ORDER BY b.symbol, d.provider, d.license_scope",
        )?;
        let mut by_symbol: BTreeMap<String, SymbolCoverage> = BTreeMap::new();
        let raw = statement.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, String>(5)?,
                row.get::<_, String>(6)?,
            ))
        })?;
        for row in raw {
            let (symbol, count, first, last, latest_available, provider, license_scope) = row?;
            let entry = by_symbol
                .entry(symbol.clone())
                .or_insert_with(|| SymbolCoverage {
                    symbol,
                    rows: 0,
                    first_event_at: first.clone(),
                    last_event_at: last.clone(),
                    latest_available_at: latest_available.clone(),
                    providers: Vec::new(),
                    license_scopes: Vec::new(),
                    public_product_eligible: true,
                });
            entry.rows += count as u64;
            entry.first_event_at = entry.first_event_at.clone().min(first);
            entry.last_event_at = entry.last_event_at.clone().max(last);
            entry.latest_available_at = entry.latest_available_at.clone().max(latest_available);
            if !entry.providers.contains(&provider) {
                entry.providers.push(provider);
            }
            if !entry.license_scopes.contains(&license_scope) {
                entry.license_scopes.push(license_scope.clone());
            }
            entry.public_product_eligible &= license_scope == "PUBLIC_REDISTRIBUTION";
        }
        Ok(MarketStoreCoverage {
            database: self.path.clone(),
            batches,
            rows,
            symbols: by_symbol.into_values().collect(),
        })
    }
}

fn validate_request(request: &MaterializeRequest, bars: &[MarketBar]) -> Result<()> {
    if bars.is_empty() || request.accepted_rows != bars.len() {
        bail!("accepted row count must match a non-empty validated bar set");
    }
    if request.provider.trim().is_empty()
        || request.dataset.trim().is_empty()
        || request.license_reference.trim().is_empty()
    {
        bail!("provider, dataset, and license_reference are required");
    }
    if request.availability_delay_seconds < 0 {
        bail!("availability delay must be non-negative");
    }
    if request.license_scope == LicenseScope::PublicRedistribution
        && !request
            .license_reference
            .to_ascii_lowercase()
            .starts_with("https://")
    {
        bail!("public redistribution requires an HTTPS license reference");
    }
    if bars.iter().any(|bar| {
        !bar.validate()
            || bar.symbol.trim().is_empty()
            || bar.timestamp > request.captured_at
            || bar.source.trim().is_empty()
            || bar.data_quality.trim().is_empty()
    }) {
        bail!("bars must be valid, sourced, and observed no later than captured_at");
    }
    Ok(())
}

fn sha256_file(path: &Path) -> Result<String> {
    let bytes = fs::read(path).with_context(|| format!("cannot read {}", path.display()))?;
    Ok(format!("{:x}", Sha256::digest(bytes)))
}

fn batch_id(request: &MaterializeRequest, source_file_sha256: &str) -> String {
    let payload = format!(
        "{}|{}|{}|{}|{}|{}|{}|{}",
        request.provider.trim(),
        request.dataset.trim(),
        source_file_sha256,
        request.captured_at.to_rfc3339(),
        request.availability_policy.as_str(),
        request.availability_delay_seconds,
        request.license_scope.as_str(),
        request.license_reference.trim()
    );
    format!("{:x}", Sha256::digest(payload.as_bytes()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn bar(timestamp: DateTime<Utc>, symbol: &str) -> MarketBar {
        MarketBar {
            timestamp,
            symbol: symbol.to_string(),
            open: 100.0,
            high: 101.0,
            low: 99.0,
            close: 100.5,
            volume: 10.0,
            vwap: Some(100.2),
            bid: None,
            ask: None,
            trade_count: Some(2),
            source: "TEST_VENDOR".to_string(),
            data_quality: "vendor_original".to_string(),
        }
    }

    #[test]
    fn materialization_is_idempotent_append_only_and_preserves_availability() {
        let root = tempdir().unwrap();
        let source_path = root.path().join("bars.csv");
        fs::write(&source_path, b"immutable vendor bytes").unwrap();
        let event_at = DateTime::parse_from_rfc3339("2026-07-24T13:30:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let captured_at = DateTime::parse_from_rfc3339("2026-07-24T14:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let request = MaterializeRequest {
            database: root.path().join("market.sqlite3"),
            source_path,
            provider: "TEST".to_string(),
            dataset: "TEST.MINI".to_string(),
            captured_at,
            availability_policy: AvailabilityPolicy::CompletedMinuteEndPlusDelay,
            availability_delay_seconds: 900,
            license_scope: LicenseScope::ResearchOnly,
            license_reference: "vendor-contract:test-only".to_string(),
            input_rows: 1,
            accepted_rows: 1,
            duplicate_rows: 0,
            rejected_rows: 0,
        };
        let mut store = MarketDataStore::open(&request.database).unwrap();
        let first = store
            .materialize(&request, &[bar(event_at, "QQQ")])
            .unwrap();
        assert_eq!(first.inserted_rows, 1);
        let second = store
            .materialize(&request, &[bar(event_at, "QQQ")])
            .unwrap();
        assert_eq!(second.status, "ALREADY_MATERIALIZED");
        assert_eq!(second.inserted_rows, 0);
        let available_at: String = store
            .connection
            .query_row("SELECT available_at FROM minute_bars", [], |row| row.get(0))
            .unwrap();
        assert_eq!(available_at, "2026-07-24T13:46:00+00:00");
        assert!(
            store
                .connection
                .execute("DELETE FROM minute_bars", [])
                .is_err()
        );
    }

    #[test]
    fn research_license_never_becomes_public_product_eligible() {
        let root = tempdir().unwrap();
        let source_path = root.path().join("bars.csv");
        fs::write(&source_path, b"vendor bytes").unwrap();
        let event_at = DateTime::parse_from_rfc3339("2026-07-24T13:30:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let captured_at = event_at + Duration::hours(1);
        let request = MaterializeRequest {
            database: root.path().join("market.sqlite3"),
            source_path,
            provider: "PERSONAL_VENDOR".to_string(),
            dataset: "STOCKS".to_string(),
            captured_at,
            availability_policy: AvailabilityPolicy::ObservedAtIngestion,
            availability_delay_seconds: 0,
            license_scope: LicenseScope::ResearchOnly,
            license_reference: "https://example.test/personal-license".to_string(),
            input_rows: 1,
            accepted_rows: 1,
            duplicate_rows: 0,
            rejected_rows: 0,
        };
        let mut store = MarketDataStore::open(&request.database).unwrap();
        let receipt = store
            .materialize(&request, &[bar(event_at, "NVDA")])
            .unwrap();
        assert!(!receipt.public_product_eligible);
        assert!(!store.coverage().unwrap().symbols[0].public_product_eligible);
    }
}
