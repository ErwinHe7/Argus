use std::{collections::BTreeSet, fs, path::Path};

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::config::DataConfig;

use super::{context, manifest::sha256_file, readiness};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CapabilityItem {
    pub capability: String,
    pub status: String,
    pub evidence: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MissingDataRow {
    pub field: String,
    pub present: bool,
    pub source: String,
    pub coverage: Option<String>,
    pub precision: String,
    pub capability_level: String,
    pub required_by: Vec<String>,
    pub impact: String,
    pub acquisition: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataCapabilityReport {
    pub generated_at: DateTime<Utc>,
    pub highest_level: String,
    pub d0_underlying_bars: bool,
    pub d1_trades_quotes: bool,
    pub d2_option_nbbo: bool,
    pub d3_option_analytics: bool,
    pub symbols: Vec<String>,
    pub coverage_start: Option<DateTime<Utc>>,
    pub coverage_end: Option<DateTime<Utc>>,
    pub row_count: u64,
    pub timestamp_precision: String,
    pub source: String,
    pub adjusted_status: String,
    pub context_status: String,
    pub context_observation_count: usize,
    pub context_model_eligible_fields: Vec<String>,
    pub normalized_file_sha256: Option<String>,
    pub manifest_hashes: Vec<String>,
    pub evidence_grade: String,
    pub allowed_claims: Vec<String>,
    pub prohibited_claims: Vec<String>,
    pub missing_data: Vec<MissingDataRow>,
}

type BarInspection = (
    u64,
    Vec<String>,
    Option<DateTime<Utc>>,
    Option<DateTime<Utc>>,
    String,
);

fn inspect_bars(path: &Path) -> Result<BarInspection> {
    if !path.exists() {
        return Ok((0, Vec::new(), None, None, "ABSENT".into()));
    }
    let mut reader = csv::Reader::from_path(path)?;
    let headers = reader.headers()?.clone();
    let timestamp = headers
        .iter()
        .position(|value| value == "timestamp")
        .context("timestamp column missing")?;
    let symbol = headers
        .iter()
        .position(|value| value == "symbol")
        .context("symbol column missing")?;
    let source = headers.iter().position(|value| value == "source");
    let mut count = 0_u64;
    let mut symbols = BTreeSet::new();
    let mut start: Option<DateTime<Utc>> = None;
    let mut end: Option<DateTime<Utc>> = None;
    let mut sources = BTreeSet::new();
    for row in reader.records() {
        let row = row?;
        let time = DateTime::parse_from_rfc3339(&row[timestamp])?.with_timezone(&Utc);
        start = Some(start.map_or(time, |current| current.min(time)));
        end = Some(end.map_or(time, |current| current.max(time)));
        symbols.insert(row[symbol].to_string());
        if let Some(index) = source {
            sources.insert(row[index].to_string());
        }
        count += 1;
    }
    Ok((
        count,
        symbols.into_iter().collect(),
        start,
        end,
        sources.into_iter().collect::<Vec<_>>().join(","),
    ))
}

pub fn inspect(config: &DataConfig) -> Result<DataCapabilityReport> {
    let bars = config.normalized_root.join("market_bars.csv");
    let (row_count, symbols, coverage_start, coverage_end, source) = inspect_bars(&bars)?;
    let doctor = readiness::doctor(config)?;
    let d0 = row_count > 0 && !symbols.is_empty();
    let d1 = false; // Aggregated OHLCV is never promoted to tick trades/quotes.
    let d2 = doctor.readiness.status == "SPXW_BACKTEST_READY";
    let d3 = d2 && doctor.readiness.analytics_ready;
    let (context_status, context_observation_count, context_model_eligible_fields) =
        if !config.context.enabled {
            ("DISABLED".to_string(), 0, Vec::new())
        } else if !config.context.input_path.exists() {
            ("MISSING_INPUT".to_string(), 0, Vec::new())
        } else {
            let report = context::audit(&config.context.input_path, &config.context, Utc::now())?;
            (
                report.status,
                report.accepted_observations,
                report.model_eligible_fields,
            )
        };
    let highest_level = if d3 {
        "D3"
    } else if d2 {
        "D2"
    } else if d1 {
        "D1"
    } else if d0 {
        "D0"
    } else {
        "NONE"
    };
    let missing = vec![
        MissingDataRow {
            field: "underlying_1m_ohlcv".into(),
            present: d0,
            source: source.clone(),
            coverage: coverage_start
                .zip(coverage_end)
                .map(|(a, b)| format!("{a}..{b}")),
            precision: "1 minute aggregate".into(),
            capability_level: "D0".into(),
            required_by: vec![
                "underlying_distribution".into(),
                "HMM".into(),
                "Kernel Analog".into(),
            ],
            impact: if d0 {
                "available for contaminated exploratory research"
            } else {
                "underlying forecasting blocked"
            }
            .into(),
            acquisition: "Massive licensed/account-entitled aggregates or licensed equivalent"
                .into(),
        },
        MissingDataRow {
            field: "consolidated_equity_trades_quotes".into(),
            present: d1,
            source: "NONE".into(),
            coverage: None,
            precision: "event".into(),
            capability_level: "D1".into(),
            required_by: vec!["microprice".into(), "order imbalance".into()],
            impact: "microstructure features disabled".into(),
            acquisition: "licensed SIP trades and NBBO".into(),
        },
        MissingDataRow {
            field: "point_in_time_macro_and_daily_context".into(),
            present: !context_model_eligible_fields.is_empty(),
            source: config.context.provider.clone(),
            coverage: None,
            precision: "snapshot/minute/daily with explicit availability timestamp".into(),
            capability_level: "D0-CONTEXT".into(),
            required_by: vec!["regime context".into(), "daily technical context".into()],
            impact: if context_model_eligible_fields.is_empty() {
                "context remains display/research-only and is excluded from model features"
            } else {
                "eligible as challenger features; walk-forward ablation still required"
            }
            .into(),
            acquisition:
                "archive Alva/exported observations point-in-time with event_time, available_time, and upstream vendor"
                    .into(),
        },
        MissingDataRow {
            field: "spx_index_values".into(),
            present: doctor.readiness.spx_index_ready,
            source: "CBOE_CGIF_OR_LICENSED_EQUIVALENT".into(),
            coverage: doctor.readiness.date_coverage.clone(),
            precision: "event/interval unknown until supplied".into(),
            capability_level: "D2".into(),
            required_by: vec!["SPX forecast".into(), "SPXW alignment".into()],
            impact: "SPY remains proxy; SPX claims prohibited".into(),
            acquisition: "licensed Cboe index history".into(),
        },
        MissingDataRow {
            field: "spxw_point_in_time_definitions".into(),
            present: doctor.readiness.definitions_ready,
            source: "DATABENTO_OPRA_OR_CBOE".into(),
            coverage: None,
            precision: "definition event".into(),
            capability_level: "D2".into(),
            required_by: vec!["contract lifecycle".into(), "strike selection".into()],
            impact: "SPXW contract selection blocked".into(),
            acquisition: "OPRA definitions after cost/entitlement confirmation".into(),
        },
        MissingDataRow {
            field: "spxw_consolidated_nbbo_with_size".into(),
            present: d2,
            source: "DATABENTO_OPRA_OR_CBOE".into(),
            coverage: None,
            precision: "event preferred; minute sample must be labeled".into(),
            capability_level: "D2".into(),
            required_by: vec!["tradable option return".into(), "execution".into()],
            impact: "real SPXW PnL prohibited".into(),
            acquisition: "licensed OPRA historical quote data".into(),
        },
        MissingDataRow {
            field: "iv_greeks_oi_surface".into(),
            present: d3,
            source: "NONE".into(),
            coverage: None,
            precision: "point-in-time".into(),
            capability_level: "D3".into(),
            required_by: vec!["IV surface forecast".into(), "option attribution".into()],
            impact: "IV/skew/GEX claims prohibited".into(),
            acquisition:
                "licensed point-in-time D3 dataset or auditable internal calculation over D2".into(),
        },
    ];
    let hashes = doctor.readiness.source_hashes.clone();
    Ok(DataCapabilityReport {
        generated_at: Utc::now(),
        highest_level: highest_level.into(),
        d0_underlying_bars: d0,
        d1_trades_quotes: d1,
        d2_option_nbbo: d2,
        d3_option_analytics: d3,
        symbols,
        coverage_start,
        coverage_end,
        row_count,
        timestamp_precision: if d0 { "1_MINUTE_AGGREGATE" } else { "MISSING" }.into(),
        source,
        adjusted_status: if d0 { "VENDOR_ADJUSTED" } else { "UNKNOWN" }.into(),
        context_status,
        context_observation_count,
        context_model_eligible_fields,
        normalized_file_sha256: d0.then(|| sha256_file(&bars)).transpose()?,
        manifest_hashes: hashes,
        evidence_grade: if d0 {
            "CONTAMINATED_EXPLORATORY"
        } else {
            "NO_EVIDENCE"
        }
        .into(),
        allowed_claims: if d0 {
            vec![
                "underlying return/distribution engineering research".into(),
                "bar-level causal regime diagnostics".into(),
            ]
        } else {
            vec![]
        },
        prohibited_claims: vec![
            "untouched OOS edge".into(),
            "SPX equals SPY".into(),
            "order flow from OHLCV".into(),
            "real SPXW PnL without D2".into(),
            "IV/GEX without D3".into(),
        ],
        missing_data: missing,
    })
}

pub fn capability_audit(config: &DataConfig) -> Result<Vec<CapabilityItem>> {
    let data = inspect(config)?;
    let present = |capability: &str, status: &str, evidence: &str| CapabilityItem {
        capability: capability.into(),
        status: status.into(),
        evidence: evidence.into(),
    };
    Ok(vec![
        present(
            "external_context_point_in_time",
            if data.context_model_eligible_fields.is_empty() {
                "BLOCKED_BY_PROVENANCE_OR_HISTORY"
            } else {
                "CHALLENGER_READY"
            },
            &format!(
                "{}; eligible_fields={}",
                data.context_status,
                data.context_model_eligible_fields.len()
            ),
        ),
        present(
            "point_in_time_feature_pipeline",
            "PRESENT",
            "Rust feature tests reject future mutation and unfinished 5m bars",
        ),
        present(
            "multi_horizon_executable_labels",
            "PARTIAL",
            "independent horizons exist; richer distribution/path labels pending",
        ),
        present(
            "purged_walk_forward",
            "PARTIAL",
            "day folds exist; four-way calibration fold added separately",
        ),
        present(
            "logistic_platt_hgb",
            "PRESENT",
            "native Rust implementations and tests",
        ),
        present(
            "kernel_analog",
            "PRESENT",
            "train-past-only, MAD, adaptive bandwidth, one neighbor/day, effective N",
        ),
        present(
            "hmm_math_toolbox",
            "PRESENT",
            "scaled forward/backward, gamma/xi, Viterbi, soft EM, causal filtering",
        ),
        present(
            "ar_hmm_gated_experts",
            "MISSING",
            "no independent OOS promotion evidence",
        ),
        present("sticky_hmm_hsmm", "MISSING", "challenger not implemented"),
        present(
            "kalman_change_point_har_rv",
            "MISSING",
            "challengers not implemented",
        ),
        present(
            "prediction_ledger",
            "PRESENT",
            "append-only SQLite predictions and settlements",
        ),
        present(
            "real_quote_execution",
            if data.d2_option_nbbo {
                "PRESENT"
            } else {
                "BLOCKED_BY_DATA"
            },
            "D2 hard gate",
        ),
        present(
            "spxw_definitions_opra",
            if data.d2_option_nbbo {
                "PRESENT"
            } else {
                "BLOCKED_BY_DATA"
            },
            "Data Doctor",
        ),
        present(
            "ibkr_live_archive",
            "BLOCKED_BY_CREDENTIAL",
            "IBKR variables absent",
        ),
        present(
            "append_only_double_entry_ledger",
            "PRESENT",
            "SQLite balance/idempotency tests",
        ),
        present("risk_oms", "PRESENT", "paper-only runtime and kill switch"),
        present(
            "evidence",
            "CONTAMINATED",
            "Massive history has been repeatedly inspected; not untouched holdout",
        ),
    ])
}

pub fn report_hash<T: Serialize>(value: &T) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

pub fn write_report(path: &Path, value: &impl Serialize) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_vec_pretty(value)?)?;
    Ok(())
}
