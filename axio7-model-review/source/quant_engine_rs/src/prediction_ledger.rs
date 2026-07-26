use std::{collections::BTreeMap, fs, path::Path, sync::Arc};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
use parking_lot::Mutex;
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};

use crate::predictor::ForecastContract;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForecastSettlement {
    pub settlement_id: String,
    pub prediction_id: String,
    pub settled_at: DateTime<Utc>,
    pub realized_reference_price: f64,
    pub realized_log_return: f64,
    pub realized_direction: i8,
    pub realized_mfe: f64,
    pub realized_mae: f64,
    pub realized_volatility: f64,
    pub barrier_outcome: String,
    pub data_status: String,
    pub source_bar_ids: Vec<String>,
    pub settlement_available_timestamp: DateTime<Utc>,
    pub settlement_hash: String,
    pub executable_entry: Option<f64>,
    pub executable_exit: Option<f64>,
    pub spread_cost: Option<f64>,
    pub slippage: Option<f64>,
    pub fees: Option<f64>,
    pub hypothetical_pnl: Option<f64>,
    pub evidence_kind: String,
}

pub struct PredictionLedger {
    connection: Mutex<Connection>,
}

impl PredictionLedger {
    pub fn open(path: &Path) -> Result<Arc<Self>> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("open prediction ledger {}", path.display()))?;
        connection.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA synchronous=FULL;
             CREATE TABLE IF NOT EXISTS predictions (
               prediction_id TEXT PRIMARY KEY,
               created_at TEXT NOT NULL,
               as_of TEXT NOT NULL,
               symbol TEXT NOT NULL,
               horizon_minutes INTEGER NOT NULL,
               evidence_kind TEXT NOT NULL,
               feature_hash TEXT NOT NULL,
               model_hash TEXT NOT NULL,
               data_manifest_hash TEXT NOT NULL,
               payload_json TEXT NOT NULL
             );
             CREATE TABLE IF NOT EXISTS prediction_settlements (
               settlement_id TEXT PRIMARY KEY,
               prediction_id TEXT NOT NULL REFERENCES predictions(prediction_id),
               settled_at TEXT NOT NULL,
               payload_json TEXT NOT NULL
             );
             CREATE TRIGGER IF NOT EXISTS predictions_no_update BEFORE UPDATE ON predictions BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
             CREATE TRIGGER IF NOT EXISTS predictions_no_delete BEFORE DELETE ON predictions BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
             CREATE TRIGGER IF NOT EXISTS settlements_no_update BEFORE UPDATE ON prediction_settlements BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
             CREATE TRIGGER IF NOT EXISTS settlements_no_delete BEFORE DELETE ON prediction_settlements BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;"
        )?;
        Ok(Arc::new(Self {
            connection: Mutex::new(connection),
        }))
    }

    pub fn append_prediction(&self, forecast: &ForecastContract) -> Result<()> {
        self.connection.lock().execute(
            "INSERT INTO predictions (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)",
            params![forecast.prediction_id, forecast.created_at.to_rfc3339(), forecast.as_of.to_rfc3339(), forecast.symbol, forecast.horizon_minutes as i64, forecast.evidence_kind, forecast.feature_hash, forecast.model_hash, forecast.data_manifest_hash, serde_json::to_string(forecast)?]
        )?;
        Ok(())
    }

    pub fn append_settlement(&self, settlement: &ForecastSettlement) -> Result<()> {
        if !matches!(
            settlement.evidence_kind.as_str(),
            "walk_forward_simulation" | "settled_forward_prediction"
        ) {
            bail!(
                "settlement evidence kind must be walk_forward_simulation or settled_forward_prediction"
            );
        }
        self.connection.lock().execute(
            "INSERT INTO prediction_settlements (settlement_id,prediction_id,settled_at,payload_json) VALUES (?1,?2,?3,?4)",
            params![settlement.settlement_id, settlement.prediction_id, settlement.settled_at.to_rfc3339(), serde_json::to_string(settlement)?]
        )?;
        Ok(())
    }

    pub fn shadow_status(&self) -> Result<serde_json::Value> {
        let connection = self.connection.lock();
        let predictions: i64 =
            connection.query_row("SELECT COUNT(*) FROM predictions", [], |row| row.get(0))?;
        let settlements: i64 =
            connection.query_row("SELECT COUNT(*) FROM prediction_settlements", [], |row| {
                row.get(0)
            })?;
        let live_predictions: i64 = connection.query_row(
            "SELECT COUNT(*) FROM predictions WHERE json_extract(payload_json,'$.data_source') NOT LIKE '%fixture%' AND evidence_kind='live_shadow_prediction'",
            [],
            |row| row.get(0),
        )?;
        let replay_predictions: i64 = connection.query_row(
            "SELECT COUNT(*) FROM predictions WHERE evidence_kind='deterministic_replay_prediction' OR json_extract(payload_json,'$.data_source') LIKE '%fixture%'",
            [],
            |row| row.get(0),
        )?;
        let settled_forward: i64 = connection.query_row(
            "SELECT COUNT(*) FROM prediction_settlements s JOIN predictions p ON p.prediction_id=s.prediction_id WHERE json_extract(p.payload_json,'$.data_source') NOT LIKE '%fixture%' AND p.evidence_kind='live_shadow_prediction' AND json_extract(s.payload_json,'$.evidence_kind')='settled_forward_prediction'",
            [],
            |row| row.get(0),
        )?;
        let first: Option<String> = connection.query_row(
            "SELECT MIN(created_at) FROM predictions WHERE json_extract(payload_json,'$.data_source') NOT LIKE '%fixture%' AND evidence_kind='live_shadow_prediction'",
            [],
            |row| row.get(0),
        )?;
        Ok(serde_json::json!({
            "predictions": predictions,
            "verified_realtime_forward_predictions": live_predictions,
            // Compatibility alias for older dashboards. New code must use the
            // provider-neutral field above.
            "verified_moomoo_forward_predictions": live_predictions,
            "replay_predictions_excluded": replay_predictions,
            "settlements": settlements,
            "settled_forward_predictions": settled_forward,
            "forward_shadow_start": first,
            "evidence_status": if settled_forward == 0 { "INSUFFICIENT_VERIFIED_REALTIME_SAMPLE" } else { "FORWARD_EVIDENCE_ACCUMULATING" },
            "append_only": true
        }))
    }

    pub fn pending_forecasts(&self) -> Result<Vec<ForecastContract>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT p.payload_json FROM predictions p LEFT JOIN prediction_settlements s ON s.prediction_id=p.prediction_id WHERE s.prediction_id IS NULL ORDER BY p.as_of,p.horizon_minutes",
        )?;
        let rows = statement.query_map([], |row| row.get::<_, String>(0))?;
        let mut forecasts = Vec::new();
        for row in rows {
            forecasts.push(serde_json::from_str(&row?)?);
        }
        Ok(forecasts)
    }

    /// Returns the exact append-only payload recorded at forecast issuance.
    /// API consumers use this to reject a mutable latest-file row that differs
    /// from the ledger copy, even when its declared hashes look plausible.
    pub fn prediction_payload(&self, prediction_id: &str) -> Result<Option<serde_json::Value>> {
        let connection = self.connection.lock();
        let mut statement =
            connection.prepare("SELECT payload_json FROM predictions WHERE prediction_id=?1")?;
        let mut rows = statement.query(params![prediction_id])?;
        let Some(row) = rows.next()? else {
            return Ok(None);
        };
        let payload = row.get::<_, String>(0)?;
        Ok(Some(serde_json::from_str(&payload)?))
    }

    /// Lightweight ledger lookup for API/audit surfaces. Unlike the full
    /// pending-forecast reader, this never deserializes forecast payload blobs.
    pub fn settlement_status_by_prediction_id(&self) -> Result<BTreeMap<String, String>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT p.prediction_id,
                    CASE WHEN EXISTS (
                      SELECT 1 FROM prediction_settlements s
                      WHERE s.prediction_id=p.prediction_id
                    ) THEN 'SETTLED' ELSE 'PENDING' END
             FROM predictions p
             ORDER BY p.prediction_id",
        )?;
        let rows = statement.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        rows.collect::<rusqlite::Result<BTreeMap<_, _>>>()
            .map_err(Into::into)
    }

    #[cfg(test)]
    pub fn attempt_mutation_for_test(&self, prediction_id: &str) -> Result<()> {
        self.connection.lock().execute(
            "UPDATE predictions SET symbol='MUTATED' WHERE prediction_id=?1",
            params![prediction_id],
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use rusqlite::params;
    use tempfile::tempdir;

    use super::PredictionLedger;

    #[test]
    fn database_rejects_prediction_update_and_delete() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        ledger.connection.lock().execute("INSERT INTO predictions (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json) VALUES ('p1','2026-07-21T00:00:00Z','2026-07-21T00:00:00Z','SPY',5,'live_shadow_prediction','f','m','d','{}')",[]).unwrap();
        assert_eq!(
            ledger.prediction_payload("p1").unwrap(),
            Some(serde_json::json!({}))
        );
        assert!(
            ledger
                .connection
                .lock()
                .execute(
                    "UPDATE predictions SET symbol='QQQ' WHERE prediction_id=?1",
                    params!["p1"]
                )
                .is_err()
        );
        assert!(
            ledger
                .connection
                .lock()
                .execute(
                    "DELETE FROM predictions WHERE prediction_id=?1",
                    params!["p1"]
                )
                .is_err()
        );
    }
}
