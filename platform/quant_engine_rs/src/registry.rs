use std::{fs, path::Path, sync::Arc};

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use parking_lot::Mutex;
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};

use crate::engine::ResearchReport;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunRecord {
    pub run_id: String,
    pub profile: String,
    pub status: String,
    pub source_mode: String,
    pub evidence_tier: String,
    pub created_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub report_path: Option<String>,
    pub option_status: Option<String>,
    pub error_message: Option<String>,
    pub data_coverage: Option<serde_json::Value>,
}

pub struct Registry {
    connection: Mutex<Connection>,
}

impl Registry {
    pub fn open(path: &Path) -> Result<Arc<Self>> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("cannot open registry {}", path.display()))?;
        connection.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA synchronous=NORMAL;
             CREATE TABLE IF NOT EXISTS research_runs (
               run_id TEXT PRIMARY KEY,
               profile TEXT NOT NULL,
               status TEXT NOT NULL,
               source_mode TEXT NOT NULL,
               evidence_tier TEXT NOT NULL,
               created_at TEXT NOT NULL,
               completed_at TEXT,
               report_path TEXT,
               option_status TEXT,
               error_message TEXT,
               data_coverage_json TEXT,
               report_json TEXT
             );
             CREATE INDEX IF NOT EXISTS idx_runs_created ON research_runs(created_at DESC);",
        )?;
        Ok(Arc::new(Self {
            connection: Mutex::new(connection),
        }))
    }

    pub fn create(&self, run_id: &str, profile: &str) -> Result<RunRecord> {
        let created_at = Utc::now();
        self.connection.lock().execute(
            "INSERT INTO research_runs
             (run_id, profile, status, source_mode, evidence_tier, created_at, option_status)
             VALUES (?1, ?2, 'queued', 'licensed_csv', 'pending_real_data', ?3, 'not_executed_no_nbbo_join')",
            params![run_id, profile, created_at.to_rfc3339()],
        )?;
        self.get(run_id)?.context("newly created run not found")
    }

    pub fn mark_running(&self, run_id: &str) -> Result<()> {
        self.connection.lock().execute(
            "UPDATE research_runs SET status='running' WHERE run_id=?1",
            params![run_id],
        )?;
        Ok(())
    }

    pub fn complete(&self, run_id: &str, report: &ResearchReport) -> Result<()> {
        let report_json = serde_json::to_string(report)?;
        let coverage = serde_json::to_string(&report.data_coverage)?;
        self.connection.lock().execute(
            "UPDATE research_runs SET status='completed', source_mode=?2, evidence_tier=?3,
             completed_at=?4, data_coverage_json=?5, report_json=?6,
             option_status='not_executed_no_nbbo_join' WHERE run_id=?1",
            params![
                run_id,
                report.source_mode,
                report.evidence_tier,
                Utc::now().to_rfc3339(),
                coverage,
                report_json
            ],
        )?;
        Ok(())
    }

    pub fn fail(&self, run_id: &str, error: &str) -> Result<()> {
        self.connection.lock().execute(
            "UPDATE research_runs SET status='failed', completed_at=?2, error_message=?3 WHERE run_id=?1",
            params![run_id, Utc::now().to_rfc3339(), error],
        )?;
        Ok(())
    }

    pub fn get(&self, run_id: &str) -> Result<Option<RunRecord>> {
        self.connection.lock().query_row(
            "SELECT run_id, profile, status, source_mode, evidence_tier, created_at, completed_at,
             report_path, option_status, error_message, data_coverage_json
             FROM research_runs WHERE run_id=?1",
            params![run_id], row_to_run,
        ).optional().map_err(Into::into)
    }

    pub fn latest_completed(&self) -> Result<Option<(RunRecord, ResearchReport)>> {
        self.connection.lock().query_row(
            "SELECT run_id, profile, status, source_mode, evidence_tier, created_at, completed_at,
             report_path, option_status, error_message, data_coverage_json, report_json
             FROM research_runs WHERE status='completed' ORDER BY created_at DESC LIMIT 1",
            [],
            |row| {
                let run = row_to_run(row)?;
                let report_json: String = row.get(11)?;
                Ok((run, report_json))
            },
        ).optional()?.map(|(run, json)| {
            let report = serde_json::from_str(&json)?;
            Ok((run, report))
        }).transpose()
    }

    pub fn list(&self, limit: usize) -> Result<Vec<RunRecord>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT run_id, profile, status, source_mode, evidence_tier, created_at, completed_at,
             report_path, option_status, error_message, data_coverage_json
             FROM research_runs ORDER BY created_at DESC LIMIT ?1",
        )?;
        let rows = statement.query_map(params![limit as i64], row_to_run)?;
        rows.collect::<rusqlite::Result<Vec<_>>>()
            .map_err(Into::into)
    }
}

fn row_to_run(row: &rusqlite::Row<'_>) -> rusqlite::Result<RunRecord> {
    let parse_time = |value: String| {
        DateTime::parse_from_rfc3339(&value)
            .map(|dt| dt.with_timezone(&Utc))
            .map_err(|error| {
                rusqlite::Error::FromSqlConversionFailure(
                    value.len(),
                    rusqlite::types::Type::Text,
                    Box::new(error),
                )
            })
    };
    let created_at = parse_time(row.get(5)?)?;
    let completed_raw: Option<String> = row.get(6)?;
    let completed_at = completed_raw.map(parse_time).transpose()?;
    let coverage_raw: Option<String> = row.get(10)?;
    let data_coverage = coverage_raw.and_then(|json| serde_json::from_str(&json).ok());
    Ok(RunRecord {
        run_id: row.get(0)?,
        profile: row.get(1)?,
        status: row.get(2)?,
        source_mode: row.get(3)?,
        evidence_tier: row.get(4)?,
        created_at,
        completed_at,
        report_path: row.get(7)?,
        option_status: row.get(8)?,
        error_message: row.get(9)?,
        data_coverage,
    })
}
