use std::{collections::BTreeMap, fs, path::Path};

use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::config::DataConfig;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ReadinessState {
    Ready,
    Partial,
    Missing,
    Stale,
    Blocked,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CredentialStatus {
    pub variable: String,
    pub present: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataSourceMatrixRow {
    pub source: String,
    pub responsibility: Vec<String>,
    pub prohibited_uses: Vec<String>,
    pub credential: Option<String>,
    pub configured: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArtifactCoverage {
    pub path: String,
    pub bytes: u64,
    pub schema_hint: String,
    pub manifest_hash: Option<String>,
    pub validation_status: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataReadinessReport {
    pub status: String,
    pub definitions_ready: bool,
    pub quotes_ready: bool,
    pub nbbo_consolidated: bool,
    pub sizes_ready: bool,
    pub exact_timestamp_ready: bool,
    pub spx_index_ready: bool,
    pub alignment_ready: bool,
    pub analytics_ready: bool,
    pub execution_model_ready: bool,
    pub definitions_coverage: f64,
    pub quote_coverage: f64,
    pub spx_index_coverage: f64,
    pub bid_ask_completeness: f64,
    pub size_completeness: f64,
    pub timestamp_precision: ReadinessState,
    pub crossed_quote_rate: Option<f64>,
    pub locked_quote_rate: Option<f64>,
    pub stale_quote_rate: Option<f64>,
    pub missing_minute_rate: Option<f64>,
    pub duplicate_rate: Option<f64>,
    pub out_of_order_rate: Option<f64>,
    pub symbol_mapping_failures: Option<u64>,
    pub expiration_mapping_failures: Option<u64>,
    pub underlying_alignment_failures: Option<u64>,
    pub iv_solver_failure_rate: Option<f64>,
    pub market_calendar_consistency: ReadinessState,
    pub date_coverage: Option<String>,
    pub source_hashes: Vec<String>,
    pub missing_requirements: Vec<String>,
}

impl DataReadinessReport {
    pub fn from_artifacts(artifacts: &[ArtifactCoverage]) -> Self {
        let has = |needle: &str| {
            artifacts.iter().any(|artifact| {
                artifact.path.to_ascii_lowercase().contains(needle)
                    || artifact.schema_hint.to_ascii_lowercase().contains(needle)
            })
        };
        let definitions_ready = has("option_definitions") || has("definition");
        let quotes_ready = has("option_quotes") || has("cbbo") || has("cmbp");
        let spx_index_ready = has("spx_index") || has("index_values");
        let exact_timestamp_ready = has("cmbp_1") || has("cmbp-1") || has("tcbbo");
        // File names are discovery hints only. Consolidated provenance and size
        // completeness require a normalized validation report, never inference.
        let validated = artifacts.iter().any(|artifact| {
            artifact.schema_hint == "spxw_readiness"
                && artifact.validation_status.as_deref() == Some("SPXW_BACKTEST_READY")
                && artifact.manifest_hash.is_some()
        });
        let nbbo_consolidated = quotes_ready && validated;
        let sizes_ready = quotes_ready && validated;
        let alignment_ready = definitions_ready && spx_index_ready && quotes_ready && validated;
        let analytics_ready = has("option_analytics") && validated;
        let execution_model_ready = exact_timestamp_ready && validated;
        let mut missing_requirements = Vec::new();
        for (ready, name) in [
            (definitions_ready, "SPXW_POINT_IN_TIME_DEFINITIONS"),
            (quotes_ready, "SPXW_OPTION_QUOTES"),
            (nbbo_consolidated, "CONSOLIDATED_OPRA_NBBO_PROVENANCE"),
            (sizes_ready, "BID_ASK_SIZE"),
            (spx_index_ready, "SPX_INDEX_VALUES"),
            (alignment_ready, "BACKWARD_ASOF_SPX_ALIGNMENT"),
            (execution_model_ready, "EXECUTION_LEVEL_QUOTE_EVENTS"),
        ] {
            if !ready {
                missing_requirements.push(name.to_string());
            }
        }
        let ready = missing_requirements.is_empty();
        Self {
            status: if ready {
                "SPXW_BACKTEST_READY".to_string()
            } else {
                "SPXW_BACKTEST_BLOCKED".to_string()
            },
            definitions_ready,
            quotes_ready,
            nbbo_consolidated,
            sizes_ready,
            exact_timestamp_ready,
            spx_index_ready,
            alignment_ready,
            analytics_ready,
            execution_model_ready,
            definitions_coverage: 0.0,
            quote_coverage: 0.0,
            spx_index_coverage: 0.0,
            bid_ask_completeness: 0.0,
            size_completeness: 0.0,
            timestamp_precision: if exact_timestamp_ready {
                ReadinessState::Partial
            } else {
                ReadinessState::Missing
            },
            crossed_quote_rate: None,
            locked_quote_rate: None,
            stale_quote_rate: None,
            missing_minute_rate: None,
            duplicate_rate: None,
            out_of_order_rate: None,
            symbol_mapping_failures: None,
            expiration_mapping_failures: None,
            underlying_alignment_failures: None,
            iv_solver_failure_rate: None,
            market_calendar_consistency: ReadinessState::Missing,
            date_coverage: None,
            source_hashes: artifacts
                .iter()
                .filter_map(|artifact| artifact.manifest_hash.clone())
                .collect(),
            missing_requirements,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataDoctorReport {
    pub generated_at: chrono::DateTime<chrono::Utc>,
    pub credentials: Vec<CredentialStatus>,
    pub source_matrix: Vec<DataSourceMatrixRow>,
    pub artifacts: Vec<ArtifactCoverage>,
    pub underlying_proxy: String,
    pub readiness: DataReadinessReport,
}

fn files_recursive(root: &Path, output: &mut Vec<ArtifactCoverage>) -> Result<()> {
    if !root.exists() {
        return Ok(());
    }
    for entry in fs::read_dir(root)? {
        let path = entry?.path();
        if path.is_dir() {
            files_recursive(&path, output)?;
            continue;
        }
        let name = path.to_string_lossy().to_string();
        let lowercase = name.to_ascii_lowercase();
        if !(lowercase.contains("spx")
            || lowercase.contains("opra")
            || lowercase.contains("option")
            || lowercase.contains("cbbo")
            || lowercase.contains("cmbp")
            || lowercase.contains("definition")
            || lowercase.contains("manifest"))
        {
            continue;
        }
        let mut manifest_hash = None;
        let mut validation_status = None;
        if path.extension().and_then(|value| value.to_str()) == Some("json")
            && let Ok(value) = serde_json::from_slice::<Value>(&fs::read(&path)?)
        {
            manifest_hash = value
                .get("sha256")
                .or_else(|| value.get("content_sha256"))
                .and_then(Value::as_str)
                .map(str::to_string);
            validation_status = value
                .get("status")
                .and_then(Value::as_str)
                .map(str::to_string);
        }
        let schema_hint = [
            "definition",
            "cbbo-1m",
            "cmbp-1",
            "tcbbo",
            "trades",
            "spx_index",
            "option_analytics",
            "spxw_readiness",
        ]
        .into_iter()
        .find(|hint| lowercase.contains(hint))
        .unwrap_or("unknown")
        .to_string();
        output.push(ArtifactCoverage {
            path: name,
            bytes: fs::metadata(path)?.len(),
            schema_hint,
            manifest_hash,
            validation_status,
        });
    }
    Ok(())
}

pub fn doctor(config: &DataConfig) -> Result<DataDoctorReport> {
    let credential_variables = [
        "DATABENTO_API_KEY",
        "MASSIVE_API_KEY",
        "CBOE_DATA_ROOT",
        "IBKR_HOST",
        "IBKR_PORT",
        "IBKR_CLIENT_ID",
        "IBKR_ACCOUNT",
    ];
    let credentials = credential_variables
        .iter()
        .map(|variable| CredentialStatus {
            variable: (*variable).to_string(),
            present: std::env::var_os(variable).is_some(),
        })
        .collect::<Vec<_>>();
    let present = credentials
        .iter()
        .map(|credential| (credential.variable.as_str(), credential.present))
        .collect::<BTreeMap<_, _>>();
    let source_matrix = vec![
        DataSourceMatrixRow {
            source: "DATABENTO_OPRA_PILLAR".to_string(),
            responsibility: vec![
                "SPXW_DEFINITION".into(),
                "OPRA_CBBO".into(),
                "CMBP_1".into(),
                "TCBBO".into(),
            ],
            prohibited_uses: vec!["SPX_INDEX_VALUE".into()],
            credential: Some("DATABENTO_API_KEY".into()),
            configured: present["DATABENTO_API_KEY"],
        },
        DataSourceMatrixRow {
            source: "CBOE_CGIF_DATASHOP".to_string(),
            responsibility: vec![
                "SPX_INDEX_VALUE".into(),
                "OPTION_QUOTE_INTERVAL_IMPORT".into(),
            ],
            prohibited_uses: vec!["SILENT_VENDOR_INTERNAL_GREEKS_MIX".into()],
            credential: Some("CBOE_DATA_ROOT".into()),
            configured: present["CBOE_DATA_ROOT"],
        },
        DataSourceMatrixRow {
            source: "MASSIVE".to_string(),
            responsibility: vec![
                "SPY_QQQ_IWM_BARS".into(),
                "OPTION_OPRA_ALTERNATIVE_IF_ENTITLED".into(),
            ],
            prohibited_uses: vec!["SPY_AS_SPX".into()],
            credential: Some("MASSIVE_API_KEY".into()),
            configured: present["MASSIVE_API_KEY"],
        },
        DataSourceMatrixRow {
            source: "IBKR".to_string(),
            responsibility: vec!["FORWARD_LIVE_ARCHIVE".into(), "PAPER_EXECUTION".into()],
            prohibited_uses: vec!["EXPIRED_SPXW_HISTORY_BACKFILL".into()],
            credential: Some("IBKR_HOST+PORT+CLIENT_ID+ACCOUNT".into()),
            configured: present["IBKR_HOST"]
                && present["IBKR_PORT"]
                && present["IBKR_CLIENT_ID"]
                && present["IBKR_ACCOUNT"],
        },
        DataSourceMatrixRow {
            source: "NASDAQ_QBBO".to_string(),
            responsibility: vec!["SINGLE_VENUE_ETF_BBO_FEATURES".into()],
            prohibited_uses: vec![
                "CONSOLIDATED_NBBO".into(),
                "SPX".into(),
                "SPXW".into(),
                "OPRA".into(),
            ],
            credential: None,
            configured: false,
        },
    ];
    let mut artifacts = Vec::new();
    files_recursive(&config.raw_root, &mut artifacts)?;
    files_recursive(&config.normalized_root, &mut artifacts)?;
    files_recursive(&config.manifest_root, &mut artifacts)?;
    if let Some(root) = config.raw_root.parent() {
        files_recursive(&root.join("quality"), &mut artifacts)?;
    }
    artifacts.sort_by(|left, right| left.path.cmp(&right.path));
    artifacts.dedup_by(|left, right| left.path == right.path);
    let readiness = DataReadinessReport::from_artifacts(&artifacts);
    Ok(DataDoctorReport {
        generated_at: chrono::Utc::now(),
        credentials,
        source_matrix,
        artifacts,
        underlying_proxy: "SPY data is UNDERLYING_PROXY_ONLY and is never SPX".to_string(),
        readiness,
    })
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use crate::config::{
        BrokerConfig, CboeConfig, ContextFeedConfig, DataConfig, DatabentoConfig, MassiveConfig,
    };

    use super::doctor;

    #[test]
    fn missing_real_option_data_blocks_spxw_backtest() {
        let root = tempdir().unwrap();
        let config = DataConfig {
            raw_root: root.path().join("raw"),
            normalized_root: root.path().join("normalized"),
            manifest_root: root.path().join("manifests"),
            required_symbols: vec![],
            massive: MassiveConfig::default(),
            context: ContextFeedConfig::default(),
            databento: DatabentoConfig {
                enabled: false,
                requests: vec![],
            },
            cboe: CboeConfig {
                licensed_csv_root: root.path().join("cboe"),
                spx_index_history_from: "".into(),
                option_quote_history_from: "".into(),
            },
            broker: BrokerConfig {
                provider: "ibkr".into(),
                execution_only: true,
                mode: "paper".into(),
            },
        };
        let report = doctor(&config).unwrap();
        assert_eq!(report.readiness.status, "SPXW_BACKTEST_BLOCKED");
        assert!(!report.readiness.spx_index_ready);
        assert!(!report.readiness.quotes_ready);
    }
}
