use std::{
    collections::{BTreeMap, BTreeSet, HashSet},
    env, fs,
    fs::{File, OpenOptions},
    io::{BufReader, Read, Write},
    path::{Component, Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result, bail};
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

pub const TRAINING_LINEAGE_SCHEMA_VERSION: &str = "axio.normalized-market-bars-training-lineage.v1";
pub const TRAINING_LINEAGE_SEAL_RECEIPT_SCHEMA_VERSION: &str =
    "axio.training-lineage-seal-receipt.v1";

const MAX_TRAINING_MANIFEST_BYTES: usize = 256 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AdjustmentStatus {
    RawUnadjusted,
    VendorAdjusted,
}

impl AdjustmentStatus {
    pub fn from_cli(value: &str) -> Result<Self> {
        match value {
            "raw-unadjusted" => Ok(Self::RawUnadjusted),
            "vendor-adjusted" => Ok(Self::VendorAdjusted),
            _ => bail!("TRAINING_ADJUSTMENT_STATUS_INVALID"),
        }
    }

    fn as_manifest_value(self) -> &'static str {
        match self {
            Self::RawUnadjusted => "RAW_UNADJUSTED",
            Self::VendorAdjusted => "VENDOR_ADJUSTED",
        }
    }
}

#[derive(Debug, Clone)]
pub struct SealTrainingLineageRequest {
    pub bars: PathBuf,
    pub raw_sources: Vec<PathBuf>,
    pub provider: String,
    pub product: String,
    pub adjustment_status: AdjustmentStatus,
    pub output_manifest: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrainingLineageSealReceipt {
    pub schema_version: String,
    pub status: String,
    pub manifest_path: PathBuf,
    pub manifest_sha256: String,
    pub normalized_bars_sha256: String,
    pub normalized_bars_bytes: u64,
    pub row_count: u64,
    pub symbols: Vec<String>,
    pub source_labels: Vec<String>,
    pub data_quality_labels: Vec<String>,
    pub raw_source_artifact_count: usize,
    pub rights_receipt_sha256: String,
    pub generated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrainingBarsSourceArtifact {
    provider: String,
    product: String,
    path_relative_to_data_root: PathBuf,
    sha256: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
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

#[derive(Debug, Clone)]
struct LineageRoots {
    data_root: PathBuf,
    raw_root: PathBuf,
    normalized_root: PathBuf,
    manifest_root: PathBuf,
}

impl LineageRoots {
    fn from_config(config: &DataConfig) -> Result<Self> {
        Self::from_paths(
            &config.raw_root,
            &config.normalized_root,
            &config.manifest_root,
        )
    }

    fn from_paths(raw_root: &Path, normalized_root: &Path, manifest_root: &Path) -> Result<Self> {
        let raw_root = canonical_directory_without_symlink(raw_root, false)
            .context("TRAINING_RAW_ROOT_UNREADABLE")?;
        let normalized_root = canonical_directory_without_symlink(normalized_root, false)
            .context("TRAINING_NORMALIZED_ROOT_UNREADABLE")?;
        let manifest_root = canonical_directory_without_symlink(manifest_root, true)
            .context("TRAINING_MANIFEST_ROOT_UNREADABLE")?;

        let raw_parent = raw_root.parent().context("TRAINING_DATA_ROOT_INVALID")?;
        let normalized_parent = normalized_root
            .parent()
            .context("TRAINING_DATA_ROOT_INVALID")?;
        let manifest_parent = manifest_root
            .parent()
            .context("TRAINING_DATA_ROOT_INVALID")?;
        if raw_parent != normalized_parent || raw_parent != manifest_parent {
            bail!("TRAINING_DATA_ROOTS_NOT_COHERENT");
        }

        Ok(Self {
            data_root: raw_parent.to_path_buf(),
            raw_root,
            normalized_root,
            manifest_root,
        })
    }
}

#[derive(Debug, PartialEq, Eq)]
struct BarsInspection {
    bytes: u64,
    sha256: String,
    row_count: u64,
    symbols: Vec<String>,
    source_labels: Vec<String>,
    data_quality_labels: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct TrainingBarRow {
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
    data_quality: String,
}

struct HashingReader<R> {
    inner: R,
    hasher: Sha256,
    bytes: u64,
}

impl<R> HashingReader<R> {
    fn new(inner: R) -> Self {
        Self {
            inner,
            hasher: Sha256::new(),
            bytes: 0,
        }
    }

    fn finish(self) -> (u64, String) {
        (self.bytes, format!("{:x}", self.hasher.finalize()))
    }
}

impl<R: Read> Read for HashingReader<R> {
    fn read(&mut self, buffer: &mut [u8]) -> std::io::Result<usize> {
        let read = self.inner.read(buffer)?;
        self.hasher.update(&buffer[..read]);
        self.bytes = self
            .bytes
            .checked_add(read as u64)
            .ok_or_else(|| std::io::Error::other("training bars byte count overflow"))?;
        Ok(read)
    }
}

pub fn seal_training_lineage(
    config: &DataConfig,
    request: &SealTrainingLineageRequest,
) -> Result<TrainingLineageSealReceipt> {
    let expected_receipt_sha256 = env::var(MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV)
        .context("TRAINING_RIGHTS_RECEIPT_PIN_MISSING_OR_INVALID")?;
    seal_training_lineage_with_pin_and_now(
        &LineageRoots::from_config(config)?,
        request,
        &expected_receipt_sha256,
        Utc::now(),
    )
}

fn seal_training_lineage_with_pin_and_now(
    roots: &LineageRoots,
    request: &SealTrainingLineageRequest,
    expected_receipt_sha256: &str,
    now: DateTime<Utc>,
) -> Result<TrainingLineageSealReceipt> {
    validate_identity(&request.provider, &request.product)?;
    if request.raw_sources.is_empty() {
        bail!("TRAINING_SOURCE_ARTIFACTS_MISSING");
    }

    let bars = canonical_regular_file_inside(
        &request.bars,
        &roots.normalized_root,
        "TRAINING_BARS_UNREADABLE",
    )?;
    let rights_receipt_sha256 = validate_rights_receipt(
        roots,
        &request.provider,
        &request.product,
        expected_receipt_sha256,
        now,
    )?;
    let bars_inspection = inspect_and_hash_bars(&bars)?;
    if bars_inspection.source_labels.len() != 1 {
        bail!("TRAINING_SOURCE_IDENTITY_MIXED");
    }
    validate_normalized_source_identity(
        &request.provider,
        &request.product,
        &bars_inspection.source_labels[0],
    )?;
    let output_manifest = resolve_output_manifest(
        &request.output_manifest,
        &roots.manifest_root,
        &bars_inspection.sha256,
    )?;
    reject_existing_exact_lineage(roots, &bars, &bars_inspection)?;

    let raw_files = collect_raw_source_files(&request.raw_sources, &roots.raw_root)?;
    let mut source_artifacts = Vec::with_capacity(raw_files.len());
    let mut source_hashes = BTreeSet::new();
    let mut source_hashes_by_path = BTreeMap::new();
    for path in &raw_files {
        let sha256 = hash_regular_file_stably(path)?;
        if !source_hashes.insert(sha256.clone()) {
            bail!("TRAINING_SOURCE_DUPLICATE_CONTENT");
        }
        source_hashes_by_path.insert(path.clone(), sha256.clone());
        source_artifacts.push(TrainingBarsSourceArtifact {
            provider: request.provider.clone(),
            product: request.product.clone(),
            path_relative_to_data_root: portable_relative_path(&roots.data_root, path)?,
            sha256,
        });
    }
    source_artifacts.sort_by(|left, right| {
        left.path_relative_to_data_root
            .cmp(&right.path_relative_to_data_root)
    });
    verify_seal_inputs_stable(
        roots,
        request,
        &bars,
        &bars_inspection,
        &raw_files,
        &source_hashes_by_path,
        &rights_receipt_sha256,
        now,
    )?;
    reject_existing_exact_lineage(roots, &bars, &bars_inspection)?;

    let generated_at = now;
    let manifest = TrainingBarsManifest {
        schema_version: TRAINING_LINEAGE_SCHEMA_VERSION.to_string(),
        output_relative_to_data_root: portable_relative_path(&roots.data_root, &bars)?,
        output_bytes: bars_inspection.bytes,
        output_sha256: bars_inspection.sha256.clone(),
        row_count: bars_inspection.row_count,
        symbols: bars_inspection.symbols.clone(),
        source_labels: bars_inspection.source_labels.clone(),
        data_quality_labels: bars_inspection.data_quality_labels.clone(),
        adjustment_status: request.adjustment_status.as_manifest_value().to_string(),
        source_artifacts,
        rights_receipt_sha256: rights_receipt_sha256.clone(),
        generated_at,
        synthetic: false,
    };
    let mut payload =
        serde_json::to_vec_pretty(&manifest).context("TRAINING_MANIFEST_SERIALIZATION_FAILED")?;
    payload.push(b'\n');
    if payload.len() > MAX_TRAINING_MANIFEST_BYTES {
        bail!("TRAINING_MANIFEST_TOO_LARGE");
    }
    atomic_write_new(&output_manifest, &payload)?;
    let manifest_sha256 = format!("{:x}", Sha256::digest(&payload));

    Ok(TrainingLineageSealReceipt {
        schema_version: TRAINING_LINEAGE_SEAL_RECEIPT_SCHEMA_VERSION.to_string(),
        status: "SEALED".to_string(),
        manifest_path: output_manifest,
        manifest_sha256,
        normalized_bars_sha256: bars_inspection.sha256,
        normalized_bars_bytes: bars_inspection.bytes,
        row_count: bars_inspection.row_count,
        symbols: bars_inspection.symbols,
        source_labels: bars_inspection.source_labels,
        data_quality_labels: bars_inspection.data_quality_labels,
        raw_source_artifact_count: manifest.source_artifacts.len(),
        rights_receipt_sha256,
        generated_at,
    })
}

fn validate_identity(provider: &str, product: &str) -> Result<()> {
    if provider != provider.trim()
        || product != product.trim()
        || !safe_metadata_label(provider)
        || !safe_metadata_label(product)
    {
        bail!("TRAINING_SOURCE_IDENTITY_INVALID");
    }
    // The existing verifier canonicalizes source identities this way before
    // matching the account-bound receipt. Rejecting alternate casing here
    // prevents emitting a manifest that can never pass that verifier.
    if provider != provider.to_ascii_lowercase() || product != product.to_ascii_uppercase() {
        bail!("TRAINING_SOURCE_IDENTITY_NOT_CANONICAL");
    }
    Ok(())
}

fn validate_normalized_source_identity(
    provider: &str,
    product: &str,
    source_label: &str,
) -> Result<()> {
    let matches = match (provider, product) {
        ("massive", "US_EQUITIES_REALTIME") => source_label == "MASSIVE_STOCKS_AGG_1M",
        ("databento", product) => {
            let legacy_product = product
                .bytes()
                .map(|byte| {
                    if byte.is_ascii_alphanumeric() {
                        char::from(byte)
                    } else {
                        '_'
                    }
                })
                .collect::<String>();
            source_label == format!("DATABENTO_{legacy_product}")
                || source_label == format!("Databento/{product}")
                || source_label == format!("Databento/{product}/ohlcv-1m")
        }
        _ => false,
    };
    if !matches {
        bail!("TRAINING_NORMALIZED_SOURCE_IDENTITY_MISMATCH");
    }
    Ok(())
}

fn validate_rights_receipt(
    roots: &LineageRoots,
    provider: &str,
    product: &str,
    expected_receipt_sha256: &str,
    now: DateTime<Utc>,
) -> Result<String> {
    let expected = expected_receipt_sha256.trim();
    if !valid_nonzero_sha256(expected) {
        bail!("TRAINING_RIGHTS_RECEIPT_PIN_MISSING_OR_INVALID");
    }
    let receipt_path = roots
        .data_root
        .join(MARKET_DATA_RIGHTS_RECEIPT_RELATIVE_PATH);
    reject_parent_components(&receipt_path)?;
    let rights_root = receipt_path
        .parent()
        .context("TRAINING_RIGHTS_RECEIPT_UNREADABLE")?;
    reject_symlink(rights_root, "TRAINING_RIGHTS_RECEIPT_SYMLINK_REJECTED")?;
    reject_symlink(&receipt_path, "TRAINING_RIGHTS_RECEIPT_SYMLINK_REJECTED")?;
    let canonical_receipt = receipt_path
        .canonicalize()
        .context("TRAINING_RIGHTS_RECEIPT_UNREADABLE")?;
    if !canonical_receipt.starts_with(&roots.data_root) {
        bail!("TRAINING_RIGHTS_RECEIPT_PATH_ESCAPE");
    }
    let metadata =
        fs::metadata(&canonical_receipt).context("TRAINING_RIGHTS_RECEIPT_UNREADABLE")?;
    if !metadata.is_file()
        || metadata.len() == 0
        || metadata.len() > MAX_MARKET_DATA_RIGHTS_RECEIPT_BYTES
    {
        bail!("TRAINING_RIGHTS_RECEIPT_UNREADABLE");
    }
    let bytes = fs::read(&canonical_receipt).context("TRAINING_RIGHTS_RECEIPT_UNREADABLE")?;
    let technical_entitlement_receipt =
        read_market_data_technical_entitlement_receipt_bytes(&roots.data_root);
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
    .map_err(|reason| anyhow::anyhow!("TRAINING_RIGHTS_RECEIPT_{}", reason.code()))
}

fn inspect_and_hash_bars(path: &Path) -> Result<BarsInspection> {
    let before = fs::metadata(path).context("TRAINING_BARS_UNREADABLE")?;
    if before.len() == 0 {
        bail!("TRAINING_BARS_EMPTY");
    }
    let file = File::open(path).context("TRAINING_BARS_UNREADABLE")?;
    let hashing_reader = HashingReader::new(BufReader::new(file));
    let mut reader = csv::ReaderBuilder::new()
        .flexible(false)
        .from_reader(hashing_reader);
    let headers = reader
        .headers()
        .context("TRAINING_BARS_HEADER_INVALID")?
        .clone();
    for required in [
        "timestamp",
        "symbol",
        "open",
        "high",
        "low",
        "close",
        "volume",
        "source",
        "data_quality",
    ] {
        unique_header_index(&headers, required)?;
    }
    for optional in ["vwap", "bid", "ask", "trade_count"] {
        optional_unique_header_index(&headers, optional)?;
    }

    let mut row_count = 0_u64;
    let mut symbols = BTreeSet::new();
    let mut source_labels = BTreeSet::new();
    let mut data_quality_labels = BTreeSet::new();
    let mut bar_keys = HashSet::new();
    for row in reader.deserialize::<TrainingBarRow>() {
        let row = row.context("TRAINING_BARS_ROW_INVALID")?;
        let timestamp = DateTime::parse_from_rfc3339(&row.timestamp)
            .context("TRAINING_BARS_TIMESTAMP_INVALID")?
            .with_timezone(&Utc);
        let symbol = row.symbol.trim().to_uppercase();
        if row.symbol != symbol || !safe_metadata_label(&symbol) {
            bail!("TRAINING_BARS_SYMBOL_INVALID");
        }
        let bar = MarketBar {
            timestamp,
            symbol: symbol.clone(),
            open: row.open,
            high: row.high,
            low: row.low,
            close: row.close,
            volume: row.volume,
            vwap: row.vwap,
            bid: row.bid,
            ask: row.ask,
            trade_count: row.trade_count,
            source: row.source.clone(),
            data_quality: row.data_quality.clone(),
        };
        if !bar.validate() {
            bail!("TRAINING_BARS_MARKET_BAR_INVALID");
        }
        if !bar_keys.insert((timestamp, symbol.clone())) {
            bail!("TRAINING_BARS_DUPLICATE");
        }
        symbols.insert(symbol);
        insert_safe_label(
            &mut source_labels,
            &row.source,
            "TRAINING_BARS_SOURCE_INVALID",
        )?;
        insert_safe_label(
            &mut data_quality_labels,
            &row.data_quality,
            "TRAINING_BARS_DATA_QUALITY_INVALID",
        )?;
        row_count = row_count
            .checked_add(1)
            .context("TRAINING_BARS_ROW_COUNT_OVERFLOW")?;
    }
    let hashing_reader = reader.into_inner();
    let (bytes, sha256) = hashing_reader.finish();
    let after = fs::metadata(path).context("TRAINING_BARS_UNREADABLE")?;
    if bytes != before.len()
        || before.len() != after.len()
        || before.modified()? != after.modified()?
    {
        bail!("TRAINING_BARS_CHANGED_DURING_SEAL");
    }
    if row_count == 0
        || symbols.is_empty()
        || source_labels.is_empty()
        || data_quality_labels.is_empty()
    {
        bail!("TRAINING_BARS_SOURCE_METADATA_INCOMPLETE");
    }

    Ok(BarsInspection {
        bytes,
        sha256,
        row_count,
        symbols: symbols.into_iter().collect(),
        source_labels: source_labels.into_iter().collect(),
        data_quality_labels: data_quality_labels.into_iter().collect(),
    })
}

fn unique_header_index(headers: &csv::StringRecord, required: &str) -> Result<usize> {
    let matches = headers
        .iter()
        .enumerate()
        .filter_map(|(index, value)| (value == required).then_some(index))
        .collect::<Vec<_>>();
    if matches.len() != 1 {
        bail!("TRAINING_BARS_REQUIRED_HEADER_INVALID: {required}");
    }
    Ok(matches[0])
}

fn optional_unique_header_index(headers: &csv::StringRecord, optional: &str) -> Result<()> {
    if headers.iter().filter(|value| *value == optional).count() > 1 {
        bail!("TRAINING_BARS_OPTIONAL_HEADER_INVALID: {optional}");
    }
    Ok(())
}

fn insert_safe_label(
    values: &mut BTreeSet<String>,
    value: &str,
    error_code: &'static str,
) -> Result<()> {
    if !safe_metadata_label(value) {
        bail!("{error_code}");
    }
    values.insert(value.to_string());
    Ok(())
}

fn collect_raw_source_files(sources: &[PathBuf], raw_root: &Path) -> Result<Vec<PathBuf>> {
    let mut files = BTreeMap::<PathBuf, PathBuf>::new();
    for source in sources {
        reject_parent_components(source)?;
        reject_symlink(source, "TRAINING_SOURCE_SYMLINK_REJECTED")?;
        let canonical = source
            .canonicalize()
            .with_context(|| format!("TRAINING_SOURCE_UNREADABLE: {}", source.display()))?;
        if !canonical.starts_with(raw_root) {
            bail!("TRAINING_SOURCE_PATH_ESCAPE");
        }
        let before = files.len();
        collect_raw_path(&canonical, raw_root, &mut files)?;
        if files.len() == before {
            bail!("TRAINING_SOURCE_EMPTY");
        }
    }
    if files.is_empty() {
        bail!("TRAINING_SOURCE_ARTIFACTS_MISSING");
    }
    Ok(files.into_values().collect())
}

fn collect_raw_path(
    path: &Path,
    raw_root: &Path,
    files: &mut BTreeMap<PathBuf, PathBuf>,
) -> Result<()> {
    reject_symlink(path, "TRAINING_SOURCE_SYMLINK_REJECTED")?;
    let metadata = fs::metadata(path).context("TRAINING_SOURCE_UNREADABLE")?;
    if metadata.is_file() {
        if metadata.len() == 0 {
            bail!("TRAINING_SOURCE_EMPTY");
        }
        let canonical = path.canonicalize().context("TRAINING_SOURCE_UNREADABLE")?;
        if !canonical.starts_with(raw_root) {
            bail!("TRAINING_SOURCE_PATH_ESCAPE");
        }
        if files.insert(canonical.clone(), canonical).is_some() {
            bail!("TRAINING_SOURCE_DUPLICATE");
        }
        return Ok(());
    }
    if !metadata.is_dir() {
        bail!("TRAINING_SOURCE_TYPE_INVALID");
    }

    let mut children = fs::read_dir(path)
        .context("TRAINING_SOURCE_UNREADABLE")?
        .map(|entry| entry.map(|value| value.path()))
        .collect::<std::io::Result<Vec<_>>>()
        .context("TRAINING_SOURCE_UNREADABLE")?;
    children.sort();
    if children.is_empty() {
        bail!("TRAINING_SOURCE_EMPTY");
    }
    for child in children {
        collect_raw_path(&child, raw_root, files)?;
    }
    Ok(())
}

fn hash_regular_file_stably(path: &Path) -> Result<String> {
    reject_symlink(path, "TRAINING_SOURCE_SYMLINK_REJECTED")?;
    let before = fs::metadata(path).context("TRAINING_SOURCE_UNREADABLE")?;
    if !before.is_file() || before.len() == 0 {
        bail!("TRAINING_SOURCE_EMPTY");
    }
    let file = File::open(path).context("TRAINING_SOURCE_UNREADABLE")?;
    let mut reader = BufReader::new(file);
    let mut hasher = Sha256::new();
    let mut bytes = 0_u64;
    let mut buffer = vec![0_u8; 1024 * 1024];
    loop {
        let read = reader
            .read(&mut buffer)
            .context("TRAINING_SOURCE_UNREADABLE")?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
        bytes = bytes
            .checked_add(read as u64)
            .context("TRAINING_SOURCE_SIZE_OVERFLOW")?;
    }
    let after = fs::metadata(path).context("TRAINING_SOURCE_UNREADABLE")?;
    if bytes != before.len()
        || before.len() != after.len()
        || before.modified()? != after.modified()?
    {
        bail!("TRAINING_SOURCE_CHANGED_DURING_SEAL");
    }
    Ok(format!("{:x}", hasher.finalize()))
}

#[allow(clippy::too_many_arguments)]
fn verify_seal_inputs_stable(
    roots: &LineageRoots,
    request: &SealTrainingLineageRequest,
    bars: &Path,
    expected_bars: &BarsInspection,
    expected_raw_files: &[PathBuf],
    expected_source_hashes: &BTreeMap<PathBuf, String>,
    expected_rights_sha256: &str,
    now: DateTime<Utc>,
) -> Result<()> {
    let observed_bars = inspect_and_hash_bars(bars)?;
    if &observed_bars != expected_bars {
        bail!("TRAINING_BARS_CHANGED_DURING_SEAL");
    }
    let observed_raw_files = collect_raw_source_files(&request.raw_sources, &roots.raw_root)?;
    if observed_raw_files != expected_raw_files {
        bail!("TRAINING_SOURCE_SET_CHANGED_DURING_SEAL");
    }
    for path in expected_raw_files {
        let observed_sha256 = hash_regular_file_stably(path)?;
        if expected_source_hashes.get(path) != Some(&observed_sha256) {
            bail!("TRAINING_SOURCE_CHANGED_DURING_SEAL");
        }
    }
    let observed_rights_sha256 = validate_rights_receipt(
        roots,
        &request.provider,
        &request.product,
        expected_rights_sha256,
        now,
    )?;
    if !observed_rights_sha256.eq_ignore_ascii_case(expected_rights_sha256) {
        bail!("TRAINING_RIGHTS_RECEIPT_CHANGED_DURING_SEAL");
    }
    Ok(())
}

fn reject_existing_exact_lineage(
    roots: &LineageRoots,
    bars: &Path,
    observed: &BarsInspection,
) -> Result<()> {
    let mut entries = fs::read_dir(&roots.manifest_root)
        .context("TRAINING_MANIFEST_ROOT_UNREADABLE")?
        .map(|entry| entry.map(|value| value.path()))
        .collect::<std::io::Result<Vec<_>>>()
        .context("TRAINING_MANIFEST_ROOT_UNREADABLE")?;
    entries.sort();
    for path in entries {
        let eligible_name = path
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| {
                name.starts_with("normalized_market_bars_") && name.ends_with(".json")
            });
        if !eligible_name {
            continue;
        }
        reject_symlink(&path, "TRAINING_MANIFEST_SYMLINK_REJECTED")?;
        let metadata = fs::metadata(&path).context("TRAINING_MANIFEST_UNREADABLE")?;
        if !metadata.is_file()
            || metadata.len() == 0
            || metadata.len() > MAX_TRAINING_MANIFEST_BYTES as u64
        {
            continue;
        }
        let bytes = fs::read(&path).context("TRAINING_MANIFEST_UNREADABLE")?;
        let Ok(manifest) = serde_json::from_slice::<TrainingBarsManifest>(&bytes) else {
            continue;
        };
        let exact_output = is_safe_relative_path(&manifest.output_relative_to_data_root)
            && roots
                .data_root
                .join(&manifest.output_relative_to_data_root)
                .canonicalize()
                .is_ok_and(|candidate| candidate == bars);
        if manifest.schema_version == TRAINING_LINEAGE_SCHEMA_VERSION
            && exact_output
            && manifest.output_bytes == observed.bytes
            && manifest
                .output_sha256
                .eq_ignore_ascii_case(&observed.sha256)
            && manifest.row_count == observed.row_count
            && manifest.symbols == observed.symbols
            && manifest.source_labels == observed.source_labels
            && manifest.data_quality_labels == observed.data_quality_labels
        {
            bail!(
                "TRAINING_LINEAGE_ALREADY_SEALED: {}",
                path.file_name()
                    .and_then(|value| value.to_str())
                    .unwrap_or("<non-UTF8>")
            );
        }
    }
    Ok(())
}

fn resolve_output_manifest(
    output: &Path,
    manifest_root: &Path,
    normalized_bars_sha256: &str,
) -> Result<PathBuf> {
    reject_parent_components(output)?;
    let candidate = if output.is_absolute() {
        output.to_path_buf()
    } else if output
        .parent()
        .is_none_or(|parent| parent.as_os_str().is_empty())
    {
        manifest_root.join(output)
    } else {
        env::current_dir()
            .context("TRAINING_OUTPUT_PATH_INVALID")?
            .join(output)
    };
    let file_name = candidate
        .file_name()
        .and_then(|value| value.to_str())
        .context("TRAINING_OUTPUT_PATH_INVALID")?;
    let expected_file_name = format!("normalized_market_bars_{normalized_bars_sha256}.json");
    if file_name != expected_file_name {
        bail!("TRAINING_OUTPUT_FILENAME_NOT_CONTENT_ADDRESSED: expected {expected_file_name}");
    }
    let parent = candidate.parent().context("TRAINING_OUTPUT_PATH_INVALID")?;
    reject_symlink(parent, "TRAINING_OUTPUT_SYMLINK_REJECTED")?;
    let canonical_parent = parent
        .canonicalize()
        .context("TRAINING_OUTPUT_PATH_INVALID")?;
    if canonical_parent != manifest_root {
        bail!("TRAINING_OUTPUT_PATH_ESCAPE");
    }
    if fs::symlink_metadata(&candidate).is_ok() {
        bail!("TRAINING_MANIFEST_ALREADY_EXISTS");
    }
    Ok(candidate)
}

fn atomic_write_new(path: &Path, payload: &[u8]) -> Result<()> {
    if fs::symlink_metadata(path).is_ok() {
        bail!("TRAINING_MANIFEST_ALREADY_EXISTS");
    }
    let parent = path.parent().context("TRAINING_OUTPUT_PATH_INVALID")?;
    let file_name = path
        .file_name()
        .and_then(|value| value.to_str())
        .context("TRAINING_OUTPUT_PATH_INVALID")?;
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .context("TRAINING_MANIFEST_CLOCK_INVALID")?
        .as_nanos();
    let temporary = parent.join(format!(".{file_name}.tmp-{}-{nonce}", std::process::id()));
    let write_result = (|| -> Result<()> {
        let mut file = OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&temporary)
            .context("TRAINING_MANIFEST_TEMP_CREATE_FAILED")?;
        file.write_all(payload)
            .context("TRAINING_MANIFEST_WRITE_FAILED")?;
        file.sync_all().context("TRAINING_MANIFEST_SYNC_FAILED")?;
        drop(file);
        fs::hard_link(&temporary, path).map_err(|error| {
            if error.kind() == std::io::ErrorKind::AlreadyExists {
                anyhow::anyhow!("TRAINING_MANIFEST_ALREADY_EXISTS")
            } else {
                anyhow::anyhow!("TRAINING_MANIFEST_ATOMIC_PUBLISH_FAILED: {error}")
            }
        })?;
        Ok(())
    })();
    let _ = fs::remove_file(&temporary);
    write_result
}

fn canonical_directory_without_symlink(path: &Path, create: bool) -> Result<PathBuf> {
    reject_parent_components(path)?;
    reject_symlink(path, "TRAINING_ROOT_SYMLINK_REJECTED")?;
    if create && !path.exists() {
        fs::create_dir_all(path)?;
    }
    reject_symlink(path, "TRAINING_ROOT_SYMLINK_REJECTED")?;
    let metadata = fs::metadata(path)?;
    if !metadata.is_dir() {
        bail!("TRAINING_ROOT_TYPE_INVALID");
    }
    path.canonicalize().map_err(Into::into)
}

fn canonical_regular_file_inside(path: &Path, root: &Path, error_code: &str) -> Result<PathBuf> {
    reject_parent_components(path)?;
    reject_symlink(path, "TRAINING_BARS_SYMLINK_REJECTED")?;
    let canonical = path
        .canonicalize()
        .with_context(|| error_code.to_string())?;
    if !canonical.starts_with(root) {
        bail!("TRAINING_BARS_PATH_ESCAPE");
    }
    let metadata = fs::metadata(&canonical).with_context(|| error_code.to_string())?;
    if !metadata.is_file() || metadata.len() == 0 {
        bail!("{error_code}");
    }
    Ok(canonical)
}

fn reject_symlink(path: &Path, error_code: &str) -> Result<()> {
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        env::current_dir()
            .with_context(|| error_code.to_string())?
            .join(path)
    };
    let mut ancestors = absolute.ancestors().collect::<Vec<_>>();
    ancestors.reverse();
    for component_path in ancestors {
        match fs::symlink_metadata(component_path) {
            Ok(metadata) if metadata_is_link_or_reparse_point(&metadata) => bail!("{error_code}"),
            Ok(_) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => break,
            Err(error) => return Err(error).with_context(|| error_code.to_string()),
        }
    }
    Ok(())
}

fn metadata_is_link_or_reparse_point(metadata: &fs::Metadata) -> bool {
    if metadata.file_type().is_symlink() {
        return true;
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;

        const FILE_ATTRIBUTE_REPARSE_POINT: u32 = 0x0400;
        metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0
    }
    #[cfg(not(windows))]
    {
        false
    }
}

fn reject_parent_components(path: &Path) -> Result<()> {
    if path
        .components()
        .any(|component| matches!(component, Component::ParentDir))
    {
        bail!("TRAINING_PATH_PARENT_COMPONENT_REJECTED");
    }
    Ok(())
}

fn portable_relative_path(root: &Path, path: &Path) -> Result<PathBuf> {
    let relative = path
        .strip_prefix(root)
        .context("TRAINING_PATH_OUTSIDE_DATA_ROOT")?;
    if relative.as_os_str().is_empty()
        || relative.is_absolute()
        || relative
            .components()
            .any(|component| !matches!(component, Component::Normal(_)))
    {
        bail!("TRAINING_RELATIVE_PATH_INVALID");
    }
    let portable = relative
        .to_str()
        .context("TRAINING_RELATIVE_PATH_NON_UTF8")?
        .replace('\\', "/");
    Ok(PathBuf::from(portable))
}

fn is_safe_relative_path(path: &Path) -> bool {
    !path.as_os_str().is_empty()
        && !path.is_absolute()
        && path
            .components()
            .all(|component| matches!(component, Component::Normal(_) | Component::CurDir))
}

fn safe_metadata_label(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-' | b'/'))
}

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

#[cfg(test)]
mod tests {
    use std::{fs, path::Path};

    use chrono::{Duration, TimeZone, Utc};
    use serde_json::json;
    use sha2::{Digest, Sha256};
    use tempfile::TempDir;

    use crate::data::{LicensedFileImporter, csv_import::MarketBarCsvImporter};

    use super::{
        AdjustmentStatus, LineageRoots, SealTrainingLineageRequest,
        TRAINING_LINEAGE_SCHEMA_VERSION, seal_training_lineage_with_pin_and_now,
    };

    struct Fixture {
        _root: TempDir,
        roots: LineageRoots,
        bars: std::path::PathBuf,
        raw_dir: std::path::PathBuf,
        output: std::path::PathBuf,
        rights_sha256: String,
        now: chrono::DateTime<Utc>,
    }

    fn fixture() -> Fixture {
        let root = tempfile::tempdir().unwrap();
        let data = root.path().join("data");
        let raw = data.join("raw");
        let normalized = data.join("normalized");
        let manifests = data.join("manifests");
        let rights = data.join("rights");
        fs::create_dir_all(&raw).unwrap();
        fs::create_dir_all(&normalized).unwrap();
        fs::create_dir_all(&manifests).unwrap();
        fs::create_dir_all(&rights).unwrap();

        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 16, 0, 0)
            .single()
            .unwrap();
        let receipt = json!({
            "schema_version": "axio.market_data_rights.v2",
            "provider": "databento",
            "product": "EQUS.MINI",
            "legal_entity": "AXIO7 Research LLC",
            "plan_name": "Databento Standard",
            "plan_status": "ACTIVE",
            "permitted_uses": {
                "model_input": true,
                "customer_external_display": false,
                "derived_output_publication": false,
                "raw_data_redistribution": false
            },
            "evidence_kind": "EXECUTED_AGREEMENT",
            "evidence_artifact_sha256": "a".repeat(64),
            "account_license_reference_sha256": "b".repeat(64),
            "official_terms_url": "https://databento.com/legal/terms",
            "official_product_url": "https://databento.com/stocks",
            "official_evidence_url": "https://contracts.databento.com/agreements/model-input",
            "valid_from": (now - Duration::days(30)).to_rfc3339(),
            "valid_until": (now + Duration::days(30)).to_rfc3339(),
            "issuer": "Databento",
            "reviewer": "AXIO7 Authorized Rights Reviewer",
            "issued_at": (now - Duration::days(31)).to_rfc3339(),
            "reviewed_at": (now - Duration::hours(1)).to_rfc3339(),
            "review_due_at": (now + Duration::days(7)).to_rfc3339()
        });
        let receipt_bytes = serde_json::to_vec(&receipt).unwrap();
        let rights_sha256 = format!("{:x}", Sha256::digest(&receipt_bytes));
        fs::write(
            rights.join("market_data_rights_receipt.json"),
            receipt_bytes,
        )
        .unwrap();

        let bars = normalized.join("market_bars.csv");
        let bars_bytes = concat!(
            "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
            "2026-07-27T13:30:00Z,QQQ,1,2,1,2,10,1.5,,,1,DATABENTO_EQUS_MINI,VENDOR_ADJUSTED\n",
            "2026-07-27T13:30:00Z,AAPL,1,2,1,2,10,1.5,,,1,DATABENTO_EQUS_MINI,VENDOR_ADJUSTED\n"
        )
        .as_bytes();
        fs::write(&bars, bars_bytes).unwrap();
        let raw_dir = raw.join("EQUS.MINI").join("ohlcv-1m");
        fs::create_dir_all(&raw_dir).unwrap();
        fs::write(raw_dir.join("part-000.dbn.zst"), b"immutable raw bytes 0").unwrap();
        fs::write(raw_dir.join("part-001.dbn.zst"), b"immutable raw bytes 1").unwrap();
        let bars_sha256 = format!("{:x}", Sha256::digest(bars_bytes));
        let output = manifests.join(format!("normalized_market_bars_{bars_sha256}.json"));
        let roots = LineageRoots::from_paths(&raw, &normalized, &manifests).unwrap();
        Fixture {
            _root: root,
            roots,
            bars,
            raw_dir,
            output,
            rights_sha256,
            now,
        }
    }

    fn request(fixture: &Fixture) -> SealTrainingLineageRequest {
        SealTrainingLineageRequest {
            bars: fixture.bars.clone(),
            raw_sources: vec![fixture.raw_dir.clone()],
            provider: "databento".to_string(),
            product: "EQUS.MINI".to_string(),
            adjustment_status: AdjustmentStatus::VendorAdjusted,
            output_manifest: fixture.output.clone(),
        }
    }

    #[test]
    fn seals_exact_bytes_with_model_input_only_rights() {
        let fixture = fixture();
        let receipt = seal_training_lineage_with_pin_and_now(
            &fixture.roots,
            &request(&fixture),
            &fixture.rights_sha256,
            fixture.now,
        )
        .unwrap();

        assert_eq!(receipt.status, "SEALED");
        assert_eq!(receipt.row_count, 2);
        assert_eq!(receipt.symbols, vec!["AAPL".to_string(), "QQQ".to_string()]);
        assert_eq!(receipt.raw_source_artifact_count, 2);
        assert_eq!(receipt.rights_receipt_sha256, fixture.rights_sha256);
        let manifest: serde_json::Value =
            serde_json::from_slice(&fs::read(&fixture.output).unwrap()).unwrap();
        assert_eq!(manifest["schema_version"], TRAINING_LINEAGE_SCHEMA_VERSION);
        assert_eq!(manifest["synthetic"], false);
        assert_eq!(manifest["symbols"], json!(["AAPL", "QQQ"]));
        assert_eq!(manifest["source_artifacts"].as_array().unwrap().len(), 2);
        assert_eq!(
            manifest["output_relative_to_data_root"],
            "normalized/market_bars.csv"
        );
        let imported = MarketBarCsvImporter.import(&fixture.bars).unwrap();
        assert_eq!(imported.input_rows, imported.accepted_rows);
        assert_eq!(imported.rejected_rows, 0);
        assert_eq!(imported.duplicate_rows, 0);
        assert_eq!(imported.accepted_rows as u64, receipt.row_count);
    }

    #[test]
    fn refuses_to_overwrite_an_immutable_manifest() {
        let fixture = fixture();
        let request = request(&fixture);
        seal_training_lineage_with_pin_and_now(
            &fixture.roots,
            &request,
            &fixture.rights_sha256,
            fixture.now,
        )
        .unwrap();
        let error = seal_training_lineage_with_pin_and_now(
            &fixture.roots,
            &request,
            &fixture.rights_sha256,
            fixture.now,
        )
        .unwrap_err();

        assert!(
            error
                .to_string()
                .contains("TRAINING_MANIFEST_ALREADY_EXISTS")
        );
    }

    #[test]
    fn rejects_an_existing_exact_lineage_under_an_older_alternate_name() {
        let fixture = fixture();
        let request = request(&fixture);
        seal_training_lineage_with_pin_and_now(
            &fixture.roots,
            &request,
            &fixture.rights_sha256,
            fixture.now,
        )
        .unwrap();
        let older_name = fixture
            .roots
            .manifest_root
            .join("normalized_market_bars_legacy-name.json");
        fs::rename(&fixture.output, &older_name).unwrap();

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_LINEAGE_ALREADY_SEALED")
        );
        assert!(!fixture.output.exists());
    }

    #[test]
    fn rejects_raw_source_path_escape_and_duplicate_files() {
        let fixture = fixture();
        let outside = fixture._root.path().join("outside.raw");
        fs::write(&outside, b"outside").unwrap();
        let mut escaped = request(&fixture);
        escaped.raw_sources = vec![outside];
        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &escaped,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_PATH_ESCAPE")
        );

        let file = fixture.raw_dir.join("part-000.dbn.zst");
        let mut duplicate = request(&fixture);
        duplicate.raw_sources = vec![file.clone(), file];
        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &duplicate,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_DUPLICATE")
        );
    }

    #[test]
    fn rejects_duplicate_raw_source_content() {
        let fixture = fixture();
        fs::write(
            fixture.raw_dir.join("part-002.dbn.zst"),
            b"immutable raw bytes 0",
        )
        .unwrap();

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request(&fixture),
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_DUPLICATE_CONTENT")
        );
        assert!(!fixture.output.exists());
    }

    #[test]
    fn rejects_mixed_source_identity_in_normalized_bars() {
        let fixture = fixture();
        fs::write(
            &fixture.bars,
            concat!(
                "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
                "2026-07-27T13:30:00Z,QQQ,1,2,1,2,10,1.5,,,1,DATABENTO_EQUS_MINI,VENDOR_ADJUSTED\n",
                "2026-07-27T13:31:00Z,QQQ,1,2,1,2,10,1.5,,,1,MASSIVE_STOCKS_1M,VENDOR_ADJUSTED\n"
            ),
        )
        .unwrap();

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request(&fixture),
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_IDENTITY_MIXED")
        );
        assert!(!fixture.output.exists());
    }

    #[test]
    fn rejects_single_source_label_that_does_not_match_provider_product() {
        let fixture = fixture();
        fs::write(
            &fixture.bars,
            concat!(
                "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
                "2026-07-27T13:30:00Z,QQQ,1,2,1,2,10,1.5,,,1,MASSIVE_STOCKS_AGG_1M,VENDOR_ADJUSTED\n"
            ),
        )
        .unwrap();

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request(&fixture),
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_NORMALIZED_SOURCE_IDENTITY_MISMATCH")
        );
        assert!(!fixture.output.exists());
    }

    #[test]
    fn rejects_invalid_or_duplicate_normalized_market_bars() {
        let fixture = fixture();
        fs::write(
            &fixture.bars,
            concat!(
                "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
                "2026-07-27T13:30:00Z,QQQ,1,2,1,2,10,1.5,,,1,DATABENTO_EQUS_MINI,VENDOR_ADJUSTED\n",
                "2026-07-27T13:30:00Z,QQQ,1,2,1,2,10,1.5,,,1,DATABENTO_EQUS_MINI,VENDOR_ADJUSTED\n"
            ),
        )
        .unwrap();

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request(&fixture),
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_BARS_DUPLICATE")
        );

        fs::write(
            &fixture.bars,
            concat!(
                "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality\n",
                "2026-07-27T13:30:00Z,QQQ,3,2,1,2,10,1.5,,,1,DATABENTO_EQUS_MINI,VENDOR_ADJUSTED\n"
            ),
        )
        .unwrap();
        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request(&fixture),
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_BARS_MARKET_BAR_INVALID")
        );
        assert!(!fixture.output.exists());
    }

    #[test]
    fn rejects_noncanonical_provider_product_identity() {
        let fixture = fixture();
        let mut request = request(&fixture);
        request.provider = "Databento".to_string();

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_IDENTITY_NOT_CANONICAL")
        );
        assert!(!fixture.output.exists());
    }

    #[test]
    fn rejects_wrong_rights_pin_without_writing_manifest() {
        let fixture = fixture();
        let error = seal_training_lineage_with_pin_and_now(
            &fixture.roots,
            &request(&fixture),
            &"c".repeat(64),
            fixture.now,
        )
        .unwrap_err();

        assert!(
            error
                .to_string()
                .contains("TRAINING_RIGHTS_RECEIPT_HASH_MISMATCH")
        );
        assert!(!fixture.output.exists());
    }

    #[cfg(unix)]
    #[test]
    fn rejects_symlinked_raw_source() {
        use std::os::unix::fs::symlink;

        let fixture = fixture();
        let target = fixture.raw_dir.join("part-000.dbn.zst");
        let link = fixture.roots.raw_root.join("linked.dbn.zst");
        symlink(target, &link).unwrap();
        let mut request = request(&fixture);
        request.raw_sources = vec![link];

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_SYMLINK_REJECTED")
        );
    }

    #[cfg(unix)]
    #[test]
    fn rejects_raw_source_reached_through_symlinked_directory() {
        use std::os::unix::fs::symlink;

        let fixture = fixture();
        let link = fixture.roots.raw_root.join("linked-directory");
        symlink(&fixture.raw_dir, &link).unwrap();
        let mut request = request(&fixture);
        request.raw_sources = vec![link.join("part-000.dbn.zst")];

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_SYMLINK_REJECTED")
        );
    }

    #[cfg(windows)]
    #[test]
    fn rejects_raw_source_reached_through_windows_symlinked_directory_when_supported() {
        use std::os::windows::fs::symlink_dir;

        let fixture = fixture();
        let link = fixture.roots.raw_root.join("linked-directory");
        if let Err(error) = symlink_dir(&fixture.raw_dir, &link) {
            if error.kind() == std::io::ErrorKind::PermissionDenied
                || error.raw_os_error() == Some(1314)
            {
                return;
            }
            panic!("failed creating Windows test symlink: {error}");
        }
        let mut request = request(&fixture);
        request.raw_sources = vec![link.join("part-000.dbn.zst")];

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_SOURCE_SYMLINK_REJECTED")
        );
    }

    #[test]
    fn rejects_non_content_addressed_output_name() {
        let fixture = fixture();
        let mut request = request(&fixture);
        request.output_manifest = fixture
            .roots
            .manifest_root
            .join("normalized_market_bars_second-name.json");

        assert!(
            seal_training_lineage_with_pin_and_now(
                &fixture.roots,
                &request,
                &fixture.rights_sha256,
                fixture.now,
            )
            .unwrap_err()
            .to_string()
            .contains("TRAINING_OUTPUT_FILENAME_NOT_CONTENT_ADDRESSED")
        );
        assert!(!request.output_manifest.exists());
    }

    #[test]
    fn bare_output_filename_resolves_inside_manifest_root() {
        let fixture = fixture();
        let mut request = request(&fixture);
        let file_name = fixture.output.file_name().unwrap().to_owned();
        request.output_manifest = Path::new(&file_name).to_path_buf();
        let receipt = seal_training_lineage_with_pin_and_now(
            &fixture.roots,
            &request,
            &fixture.rights_sha256,
            fixture.now,
        )
        .unwrap();

        assert_eq!(
            receipt.manifest_path,
            fixture.roots.manifest_root.join(file_name)
        );
    }
}
