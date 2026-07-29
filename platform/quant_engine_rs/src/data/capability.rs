use std::{
    collections::BTreeSet,
    env, fs,
    path::{Component, Path, PathBuf},
};

use anyhow::{Context, Result, anyhow, bail};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::{
    config::DataConfig,
    domain::MarketBar,
    production_readiness::{
        MARKET_DATA_RIGHTS_RECEIPT_RELATIVE_PATH, MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV,
        MAX_MARKET_DATA_RIGHTS_RECEIPT_BYTES, MarketDataRightsUseRequirement,
        read_market_data_technical_entitlement_receipt_bytes,
        validate_market_data_rights_receipt_bytes,
    },
};

use super::{
    context,
    csv_import::{ImportReport, MarketBarCsvImporter},
    manifest::sha256_file,
    readiness,
};

pub const TRAINING_BARS_MANIFEST_SCHEMA_VERSION: &str =
    "axio.normalized-market-bars-training-lineage.v1";
const MAX_TRAINING_MANIFEST_BYTES: u64 = 256 * 1024;

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrainingBarsSourceArtifact {
    provider: String,
    product: String,
    path_relative_to_data_root: PathBuf,
    sha256: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrainingBarsManifest {
    schema_version: String,
    output_relative_to_data_root: PathBuf,
    output_bytes: u64,
    output_sha256: String,
    row_count: u64,
    symbols: Vec<String>,
    source_labels: Vec<String>,
    data_quality_labels: Vec<String>,
    adjustment_status: String,
    source_artifacts: Vec<TrainingBarsSourceArtifact>,
    rights_receipt_sha256: String,
    generated_at: DateTime<Utc>,
    synthetic: bool,
}

#[derive(Debug)]
struct VerifiedTrainingBarsLineage {
    manifest_hashes: Vec<String>,
    adjustment_status: String,
    normalized_file_sha256: String,
}

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
    Vec<String>,
    Vec<String>,
);

fn inspect_bar_reader<R: std::io::Read>(mut reader: csv::Reader<R>) -> Result<BarInspection> {
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
    let data_quality = headers.iter().position(|value| value == "data_quality");
    let mut count = 0_u64;
    let mut symbols = BTreeSet::new();
    let mut start: Option<DateTime<Utc>> = None;
    let mut end: Option<DateTime<Utc>> = None;
    let mut sources = BTreeSet::new();
    let mut data_qualities = BTreeSet::new();
    for row in reader.records() {
        let row = row?;
        let time = DateTime::parse_from_rfc3339(&row[timestamp])?.with_timezone(&Utc);
        start = Some(start.map_or(time, |current| current.min(time)));
        end = Some(end.map_or(time, |current| current.max(time)));
        symbols.insert(row[symbol].to_string());
        if let Some(index) = source {
            sources.insert(row[index].to_string());
        }
        if let Some(index) = data_quality {
            data_qualities.insert(row[index].to_string());
        }
        count += 1;
    }
    Ok((
        count,
        symbols.into_iter().collect(),
        start,
        end,
        sources.into_iter().collect(),
        data_qualities.into_iter().collect(),
    ))
}

fn inspect_bars(path: &Path) -> Result<BarInspection> {
    if !path.exists() {
        return Ok((0, Vec::new(), None, None, Vec::new(), Vec::new()));
    }
    inspect_bar_reader(csv::Reader::from_path(path)?)
}

fn inspect_bars_bytes(bytes: &[u8]) -> Result<BarInspection> {
    inspect_bar_reader(csv::Reader::from_reader(bytes))
}

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn safe_metadata_label(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-' | b'/'))
}

fn is_safe_relative_path(path: &Path) -> bool {
    !path.as_os_str().is_empty()
        && !path.is_absolute()
        && path
            .components()
            .all(|component| matches!(component, Component::Normal(_) | Component::CurDir))
}

fn sorted_unique_nonempty(values: &[String]) -> bool {
    !values.is_empty()
        && values
            .windows(2)
            .all(|pair| pair[0].as_str() < pair[1].as_str())
}

fn verify_model_input_rights(
    data_root: &Path,
    provider: &str,
    product: &str,
    now: DateTime<Utc>,
    manifest_receipt_sha256: &str,
    expected_receipt_sha256: Option<&str>,
) -> Result<String> {
    let expected = expected_receipt_sha256
        .map(str::trim)
        .filter(|value| valid_nonzero_sha256(value))
        .context("TRAINING_RIGHTS_RECEIPT_PIN_MISSING_OR_INVALID")?;
    if !expected.eq_ignore_ascii_case(manifest_receipt_sha256) {
        bail!("TRAINING_MANIFEST_RIGHTS_PIN_MISMATCH");
    }
    let rights_path = data_root.join(MARKET_DATA_RIGHTS_RECEIPT_RELATIVE_PATH);
    let canonical_rights = rights_path
        .canonicalize()
        .context("TRAINING_RIGHTS_RECEIPT_UNREADABLE")?;
    if !canonical_rights.starts_with(data_root)
        || fs::metadata(&canonical_rights)
            .map(|metadata| metadata.len() > MAX_MARKET_DATA_RIGHTS_RECEIPT_BYTES)
            .unwrap_or(true)
    {
        bail!("TRAINING_RIGHTS_RECEIPT_UNREADABLE");
    }
    let bytes = fs::read(&canonical_rights).context("TRAINING_RIGHTS_RECEIPT_UNREADABLE")?;
    let technical_entitlement_receipt =
        read_market_data_technical_entitlement_receipt_bytes(data_root);
    validate_market_data_rights_receipt_bytes(
        &bytes,
        expected,
        provider,
        product,
        now,
        MarketDataRightsUseRequirement::ModelInputOnly,
        technical_entitlement_receipt.as_deref(),
    )
    .map(|validated| validated.receipt_sha256)
    .map_err(|reason| anyhow!("TRAINING_RIGHTS_RECEIPT_{}", reason.code()))
}

struct TrainingBarsObserved<'a> {
    canonical_bars: &'a Path,
    output_bytes: u64,
    output_sha256: &'a str,
    row_count: u64,
    symbols: &'a [String],
    source_labels: &'a [String],
    data_quality_labels: &'a [String],
}

fn verify_training_manifest_candidate(
    manifest_path: &Path,
    config: &DataConfig,
    data_root: &Path,
    now: DateTime<Utc>,
    expected_receipt_sha256: Option<&str>,
    observed: &TrainingBarsObserved<'_>,
) -> Result<VerifiedTrainingBarsLineage> {
    let metadata = fs::metadata(manifest_path).context("TRAINING_MANIFEST_UNREADABLE")?;
    if metadata.len() == 0 || metadata.len() > MAX_TRAINING_MANIFEST_BYTES {
        bail!("TRAINING_MANIFEST_UNREADABLE");
    }
    let bytes = fs::read(manifest_path).context("TRAINING_MANIFEST_UNREADABLE")?;
    let manifest: TrainingBarsManifest =
        serde_json::from_slice(&bytes).context("TRAINING_MANIFEST_INVALID")?;
    if manifest.schema_version != TRAINING_BARS_MANIFEST_SCHEMA_VERSION
        || manifest.synthetic
        || manifest.generated_at > now
        || !is_safe_relative_path(&manifest.output_relative_to_data_root)
        || !valid_nonzero_sha256(&manifest.output_sha256)
        || !valid_nonzero_sha256(&manifest.rights_receipt_sha256)
        || !matches!(
            manifest.adjustment_status.as_str(),
            "RAW_UNADJUSTED" | "VENDOR_ADJUSTED"
        )
    {
        bail!("TRAINING_MANIFEST_CONTRACT_INVALID");
    }
    let manifest_output = data_root
        .join(&manifest.output_relative_to_data_root)
        .canonicalize()
        .context("TRAINING_MANIFEST_OUTPUT_UNREADABLE")?;
    if manifest_output != observed.canonical_bars
        || manifest.output_bytes != observed.output_bytes
        || !manifest
            .output_sha256
            .eq_ignore_ascii_case(observed.output_sha256)
        || manifest.row_count != observed.row_count
        || manifest.symbols != observed.symbols
        || manifest.source_labels != observed.source_labels
        || manifest.data_quality_labels != observed.data_quality_labels
        || !sorted_unique_nonempty(&manifest.symbols)
        || !sorted_unique_nonempty(&manifest.source_labels)
        || !sorted_unique_nonempty(&manifest.data_quality_labels)
        || !manifest
            .source_labels
            .iter()
            .all(|value| safe_metadata_label(value))
        || !manifest
            .data_quality_labels
            .iter()
            .all(|value| safe_metadata_label(value))
    {
        bail!("TRAINING_MANIFEST_OUTPUT_BINDING_MISMATCH");
    }
    if manifest.source_artifacts.is_empty() {
        bail!("TRAINING_MANIFEST_SOURCE_ARTIFACTS_MISSING");
    }
    let canonical_raw_root = config
        .raw_root
        .canonicalize()
        .context("TRAINING_RAW_ROOT_UNREADABLE")?;
    if !canonical_raw_root.starts_with(data_root) {
        bail!("TRAINING_RAW_ROOT_OUTSIDE_DATA_ROOT");
    }
    let mut source_paths = BTreeSet::new();
    let mut source_hashes = BTreeSet::new();
    let mut provider_product = None::<(String, String)>;
    for artifact in &manifest.source_artifacts {
        if !safe_metadata_label(&artifact.provider)
            || !safe_metadata_label(&artifact.product)
            || !is_safe_relative_path(&artifact.path_relative_to_data_root)
            || !valid_nonzero_sha256(&artifact.sha256)
        {
            bail!("TRAINING_SOURCE_ARTIFACT_METADATA_INVALID");
        }
        let identity = (
            artifact.provider.to_ascii_lowercase(),
            artifact.product.to_ascii_uppercase(),
        );
        if provider_product
            .as_ref()
            .is_some_and(|expected| expected != &identity)
        {
            bail!("TRAINING_SOURCE_ARTIFACT_PROVIDER_PRODUCT_MIXED");
        }
        provider_product.get_or_insert(identity);
        let canonical_source = data_root
            .join(&artifact.path_relative_to_data_root)
            .canonicalize()
            .context("TRAINING_SOURCE_ARTIFACT_UNREADABLE")?;
        if !canonical_source.starts_with(&canonical_raw_root)
            || !source_paths.insert(canonical_source.clone())
        {
            bail!("TRAINING_SOURCE_ARTIFACT_PATH_INVALID");
        }
        let actual_sha256 =
            sha256_file(&canonical_source).context("TRAINING_SOURCE_ARTIFACT_UNREADABLE")?;
        if !actual_sha256.eq_ignore_ascii_case(&artifact.sha256)
            || !source_hashes.insert(actual_sha256)
        {
            bail!("TRAINING_SOURCE_ARTIFACT_HASH_MISMATCH");
        }
    }
    let (provider, product) = provider_product.context("TRAINING_SOURCE_ARTIFACTS_MISSING")?;
    let rights_hash = verify_model_input_rights(
        data_root,
        &provider,
        &product,
        now,
        &manifest.rights_receipt_sha256,
        expected_receipt_sha256,
    )?;
    let manifest_sha256 = format!("{:x}", Sha256::digest(&bytes));
    source_hashes.insert(rights_hash);
    source_hashes.insert(manifest_sha256);
    Ok(VerifiedTrainingBarsLineage {
        manifest_hashes: source_hashes.into_iter().collect(),
        adjustment_status: manifest.adjustment_status,
        normalized_file_sha256: observed.output_sha256.to_string(),
    })
}

fn verify_training_bars_lineage(
    config: &DataConfig,
    canonical_bars: &Path,
    output_bytes: u64,
    output_sha256: &str,
    now: DateTime<Utc>,
    expected_receipt_sha256: Option<&str>,
    inspection: &BarInspection,
) -> Result<VerifiedTrainingBarsLineage> {
    let canonical_manifest_root = config
        .manifest_root
        .canonicalize()
        .context("TRAINING_MANIFEST_ROOT_UNREADABLE")?;
    let data_root = canonical_manifest_root
        .parent()
        .context("TRAINING_DATA_ROOT_INVALID")?;
    if !canonical_bars.starts_with(data_root) {
        bail!("TRAINING_BARS_OUTSIDE_MANIFEST_DATA_ROOT");
    }
    let (row_count, symbols, _, _, source_labels, data_quality_labels) = inspection;
    if *row_count == 0
        || symbols.is_empty()
        || source_labels.is_empty()
        || data_quality_labels.is_empty()
    {
        bail!("TRAINING_BARS_SOURCE_METADATA_INCOMPLETE");
    }
    let observed = TrainingBarsObserved {
        canonical_bars,
        output_bytes,
        output_sha256,
        row_count: *row_count,
        symbols,
        source_labels,
        data_quality_labels,
    };
    let mut verified = Vec::new();
    for entry in
        fs::read_dir(&canonical_manifest_root).context("TRAINING_MANIFEST_ROOT_UNREADABLE")?
    {
        let path = entry?.path();
        let eligible_name = path
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| {
                name.starts_with("normalized_market_bars_") && name.ends_with(".json")
            });
        if !eligible_name || !path.is_file() {
            continue;
        }
        if let Ok(lineage) = verify_training_manifest_candidate(
            &path,
            config,
            data_root,
            now,
            expected_receipt_sha256,
            &observed,
        ) {
            verified.push(lineage);
        }
    }
    match verified.len() {
        1 => Ok(verified.remove(0)),
        0 => bail!("NO_EXACT_VERIFIED_TRAINING_BARS_MANIFEST"),
        _ => bail!("AMBIGUOUS_EXACT_TRAINING_BARS_MANIFEST"),
    }
}

pub fn inspect(config: &DataConfig) -> Result<DataCapabilityReport> {
    let bars = config.normalized_root.join("market_bars.csv");
    let inspection = inspect_bars(&bars)?;
    build_report(config, &bars, inspection, None)
}

/// Inspect one exact training file and require a reproducible normalized-data
/// manifest, raw-source hashes, and a pinned model-input rights receipt.
pub fn inspect_training_bars(config: &DataConfig, bars: &Path) -> Result<DataCapabilityReport> {
    let expected_rights_pin = env::var(MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV).ok();
    inspect_training_bars_with_pin(config, bars, Utc::now(), expected_rights_pin.as_deref())
}

struct VerifiedTrainingBarsSnapshot {
    canonical_path: PathBuf,
    bytes: Vec<u8>,
    inspection: BarInspection,
    lineage: VerifiedTrainingBarsLineage,
}

fn verified_training_bars_snapshot(
    config: &DataConfig,
    bars: &Path,
    now: DateTime<Utc>,
    expected_rights_pin: Option<&str>,
) -> Result<VerifiedTrainingBarsSnapshot> {
    let canonical_path = bars
        .canonicalize()
        .context("TRAINING_BARS_FILE_UNREADABLE")?;
    if !canonical_path.is_file() {
        bail!("TRAINING_BARS_FILE_UNREADABLE");
    }
    // The manifest and importer consume this one immutable byte snapshot.
    // A later pathname replacement cannot change the states being trained.
    let bytes = fs::read(&canonical_path).context("TRAINING_BARS_FILE_UNREADABLE")?;
    let output_bytes =
        u64::try_from(bytes.len()).context("TRAINING_BARS_FILE_SIZE_UNREPRESENTABLE")?;
    let output_sha256 = format!("{:x}", Sha256::digest(&bytes));
    let inspection = inspect_bars_bytes(&bytes)?;
    let lineage = verify_training_bars_lineage(
        config,
        &canonical_path,
        output_bytes,
        &output_sha256,
        now,
        expected_rights_pin,
        &inspection,
    )?;
    Ok(VerifiedTrainingBarsSnapshot {
        canonical_path,
        bytes,
        inspection,
        lineage,
    })
}

fn import_snapshot(snapshot: &VerifiedTrainingBarsSnapshot) -> Result<ImportReport<MarketBar>> {
    let imported = MarketBarCsvImporter.import_bytes(&snapshot.bytes, &snapshot.canonical_path)?;
    if imported.rejected_rows != 0
        || imported.duplicate_rows != 0
        || imported.input_rows != imported.accepted_rows
        || imported.input_rows as u64 != snapshot.inspection.0
    {
        bail!(
            "TRAINING_BARS_IMPORT_NOT_LOSSLESS: input={} accepted={} rejected={} duplicate={}",
            imported.input_rows,
            imported.accepted_rows,
            imported.rejected_rows,
            imported.duplicate_rows
        );
    }
    Ok(imported)
}

/// Verify lineage and parse exactly one immutable byte snapshot. Callers must
/// use the returned records; re-opening `bars` would reintroduce a race.
pub fn import_verified_training_bars(
    config: &DataConfig,
    bars: &Path,
) -> Result<(ImportReport<MarketBar>, DataCapabilityReport)> {
    let expected_rights_pin = env::var(MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV).ok();
    let snapshot =
        verified_training_bars_snapshot(config, bars, Utc::now(), expected_rights_pin.as_deref())?;
    let imported = import_snapshot(&snapshot)?;
    let report = build_report(
        config,
        &snapshot.canonical_path,
        snapshot.inspection,
        Some(snapshot.lineage),
    )?;
    Ok((imported, report))
}

fn inspect_training_bars_with_pin(
    config: &DataConfig,
    bars: &Path,
    now: DateTime<Utc>,
    expected_rights_pin: Option<&str>,
) -> Result<DataCapabilityReport> {
    let snapshot = verified_training_bars_snapshot(config, bars, now, expected_rights_pin)?;
    import_snapshot(&snapshot)?;
    build_report(
        config,
        &snapshot.canonical_path,
        snapshot.inspection,
        Some(snapshot.lineage),
    )
}

fn build_report(
    config: &DataConfig,
    bars: &Path,
    inspection: BarInspection,
    training_lineage: Option<VerifiedTrainingBarsLineage>,
) -> Result<DataCapabilityReport> {
    let (row_count, symbols, coverage_start, coverage_end, sources, _data_qualities) = inspection;
    let source = sources.join(",");
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
    let (hashes, adjusted_status, evidence_grade, normalized_file_sha256) = match training_lineage {
        Some(lineage) => (
            lineage.manifest_hashes,
            lineage.adjustment_status,
            "LICENSED_EXACT_FILE_MANIFEST",
            Some(lineage.normalized_file_sha256),
        ),
        None => (
            doctor.readiness.source_hashes.clone(),
            if d0 {
                "VENDOR_ADJUSTED".to_string()
            } else {
                "UNKNOWN".to_string()
            },
            if d0 {
                "CONTAMINATED_EXPLORATORY"
            } else {
                "NO_EVIDENCE"
            },
            d0.then(|| sha256_file(bars)).transpose()?,
        ),
    };
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
        adjusted_status,
        context_status,
        context_observation_count,
        context_model_eligible_fields,
        normalized_file_sha256,
        manifest_hashes: hashes,
        evidence_grade: evidence_grade.into(),
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

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};
    use tempfile::TempDir;

    use crate::config::{
        BrokerConfig, CboeConfig, ContextFeedConfig, DatabentoConfig, MassiveConfig,
    };

    use super::*;

    struct TrainingLineageFixture {
        _root: TempDir,
        config: DataConfig,
        bars: PathBuf,
        manifest: PathBuf,
        rights_sha256: String,
        raw_sha256: String,
        manifest_sha256: String,
        now: DateTime<Utc>,
    }

    fn write_training_lineage_fixture() -> TrainingLineageFixture {
        let root = tempfile::tempdir().unwrap();
        let data_root = root.path().join("data");
        let raw_root = data_root.join("raw");
        let normalized_root = data_root.join("normalized");
        let manifest_root = data_root.join("manifests");
        let rights_root = data_root.join("rights");
        for directory in [&raw_root, &normalized_root, &manifest_root, &rights_root] {
            fs::create_dir_all(directory).unwrap();
        }
        let raw = raw_root.join("massive_source.json");
        fs::write(&raw, br#"{"licensed":"source"}"#).unwrap();
        let raw_sha256 = sha256_file(&raw).unwrap();

        let bars = normalized_root.join("training.csv");
        let csv = concat!(
            "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
            "2026-07-22T13:30:00Z,SPY,500,501,499,500.5,1000,500.4,,,10,MASSIVE_STOCKS_AGG_1M,COMPLETE\n",
            "2026-07-22T13:31:00Z,SPY,500.5,501.5,500,501,1100,500.9,,,11,MASSIVE_STOCKS_AGG_1M,COMPLETE\n",
        );
        fs::write(&bars, csv.as_bytes()).unwrap();
        let bars_sha256 = sha256_file(&bars).unwrap();

        let now = Utc.with_ymd_and_hms(2026, 7, 28, 16, 0, 0).unwrap();
        let rights = rights_root.join("market_data_rights_receipt.json");
        fs::write(
            &rights,
            serde_json::to_vec_pretty(&serde_json::json!({
                "schema_version":
                    crate::production_readiness::MARKET_DATA_RIGHTS_RECEIPT_SCHEMA_VERSION,
                "provider": "massive",
                "product": "US_EQUITIES_REALTIME",
                "legal_entity": "AXIO7 Research LLC",
                "plan_name": "Massive Business",
                "plan_status": "ACTIVE",
                "permitted_uses": {
                    "model_input": true,
                    "customer_external_display": false,
                    "derived_output_publication": false,
                    "raw_data_redistribution": false
                },
                "evidence_kind": "ORDER_CONFIRMATION",
                "evidence_artifact_sha256": "a".repeat(64),
                "account_license_reference_sha256": "b".repeat(64),
                "official_terms_url": "https://massive.com/legal/terms",
                "official_product_url": "https://massive.com/stocks",
                "official_evidence_url": "https://massive.com/support/tickets/training-rights",
                "valid_from": now - Duration::days(30),
                "valid_until": now + Duration::days(30),
                "issuer": "Massive Licensed Account",
                "reviewer": "AXIO7 Authorized Rights Reviewer",
                "issued_at": now - Duration::days(2),
                "reviewed_at": now - Duration::days(1),
                "review_due_at": now + Duration::days(7)
            }))
            .unwrap(),
        )
        .unwrap();
        let rights_sha256 = sha256_file(&rights).unwrap();

        let manifest = manifest_root.join("normalized_market_bars_training.json");
        let manifest_value = serde_json::json!({
            "schema_version": TRAINING_BARS_MANIFEST_SCHEMA_VERSION,
            "output_relative_to_data_root": "normalized/training.csv",
            "output_bytes": fs::metadata(&bars).unwrap().len(),
            "output_sha256": bars_sha256,
            "row_count": 2,
            "symbols": ["SPY"],
            "source_labels": ["MASSIVE_STOCKS_AGG_1M"],
            "data_quality_labels": ["COMPLETE"],
            "adjustment_status": "VENDOR_ADJUSTED",
            "source_artifacts": [{
                "provider": "massive",
                "product": "US_EQUITIES_REALTIME",
                "path_relative_to_data_root": "raw/massive_source.json",
                "sha256": raw_sha256
            }],
            "rights_receipt_sha256": rights_sha256,
            "generated_at": now - Duration::hours(1),
            "synthetic": false
        });
        let manifest_bytes = serde_json::to_vec_pretty(&manifest_value).unwrap();
        fs::write(&manifest, &manifest_bytes).unwrap();
        let manifest_sha256 = format!("{:x}", Sha256::digest(&manifest_bytes));

        let config = DataConfig {
            raw_root,
            normalized_root,
            manifest_root,
            required_symbols: vec!["SPY".into()],
            massive: MassiveConfig::default(),
            context: ContextFeedConfig {
                input_path: data_root.join("context/official_observations.jsonl"),
                ..ContextFeedConfig::default()
            },
            databento: DatabentoConfig {
                enabled: false,
                requests: Vec::new(),
            },
            cboe: CboeConfig {
                licensed_csv_root: data_root.join("cboe"),
                spx_index_history_from: String::new(),
                option_quote_history_from: String::new(),
            },
            broker: BrokerConfig {
                provider: "none".into(),
                execution_only: true,
                mode: "paper".into(),
            },
        };
        TrainingLineageFixture {
            _root: root,
            config,
            bars,
            manifest,
            rights_sha256,
            raw_sha256,
            manifest_sha256,
            now,
        }
    }

    #[test]
    fn exact_training_snapshot_binds_manifest_sources_and_model_input_rights() {
        let fixture = write_training_lineage_fixture();
        let snapshot = verified_training_bars_snapshot(
            &fixture.config,
            &fixture.bars,
            fixture.now,
            Some(&fixture.rights_sha256),
        )
        .unwrap();
        let imported = import_snapshot(&snapshot).unwrap();
        assert_eq!(imported.accepted_rows, 2);
        let report = build_report(
            &fixture.config,
            &snapshot.canonical_path,
            snapshot.inspection,
            Some(snapshot.lineage),
        )
        .unwrap();
        assert_eq!(
            report.normalized_file_sha256.as_deref(),
            Some(sha256_file(&fixture.bars).unwrap().as_str())
        );
        assert_eq!(report.evidence_grade, "LICENSED_EXACT_FILE_MANIFEST");
        assert_eq!(report.adjusted_status, "VENDOR_ADJUSTED");
        assert!(report.manifest_hashes.contains(&fixture.raw_sha256));
        assert!(report.manifest_hashes.contains(&fixture.rights_sha256));
        assert!(report.manifest_hashes.contains(&fixture.manifest_sha256));

        let serialized = serde_json::to_string(&report).unwrap();
        assert!(!serialized.contains("massive.com/legal/terms"));
        assert!(!serialized.contains("massive.com/support/tickets"));
        assert!(!serialized.contains("Massive Licensed Account"));
        assert!(!serialized.contains("AXIO7 Research LLC"));
        assert!(!serialized.contains(&"a".repeat(64)));
        assert!(!serialized.contains(&"b".repeat(64)));
        assert!(!serialized.contains("massive_source.json"));
    }

    #[test]
    fn training_lineage_fails_closed_on_tamper_missing_manifest_or_wrong_pin() {
        let tampered = write_training_lineage_fixture();
        fs::write(
            &tampered.bars,
            concat!(
                "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
                "2026-07-22T13:30:00Z,SPY,500,501,499,499.5,1000,500.4,,,10,MASSIVE_STOCKS_AGG_1M,COMPLETE\n",
                "2026-07-22T13:31:00Z,SPY,500.5,501.5,500,501,1100,500.9,,,11,MASSIVE_STOCKS_AGG_1M,COMPLETE\n",
            ),
        )
        .unwrap();
        assert!(
            inspect_training_bars_with_pin(
                &tampered.config,
                &tampered.bars,
                tampered.now,
                Some(&tampered.rights_sha256),
            )
            .unwrap_err()
            .to_string()
            .contains("NO_EXACT_VERIFIED_TRAINING_BARS_MANIFEST")
        );

        let wrong_pin = write_training_lineage_fixture();
        assert!(
            inspect_training_bars_with_pin(
                &wrong_pin.config,
                &wrong_pin.bars,
                wrong_pin.now,
                Some(&"f".repeat(64)),
            )
            .unwrap_err()
            .to_string()
            .contains("NO_EXACT_VERIFIED_TRAINING_BARS_MANIFEST")
        );

        let missing = write_training_lineage_fixture();
        fs::remove_file(&missing.manifest).unwrap();
        assert!(
            inspect_training_bars_with_pin(
                &missing.config,
                &missing.bars,
                missing.now,
                Some(&missing.rights_sha256),
            )
            .unwrap_err()
            .to_string()
            .contains("NO_EXACT_VERIFIED_TRAINING_BARS_MANIFEST")
        );
    }
}
