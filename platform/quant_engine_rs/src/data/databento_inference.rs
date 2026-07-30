//! Fail-closed Databento live-bar to frozen-model inference.
//!
//! `databento_live` owns the one licensed socket. This module consumes only
//! envelopes emitted by that socket after entitlement, mapping, freshness,
//! and replay checks have passed. It never opens a second provider session and
//! never exposes an execution path.

use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    io::{BufRead, BufReader, Write},
    path::{Component, Path, PathBuf},
    sync::Arc,
    time::Instant,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, Utc};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use tokio::sync::mpsc;

use crate::{
    AppConfig,
    config::{LiveConfig, ResearchConfig},
    data::{
        LicensedFileImporter,
        capability::{self, DataCapabilityReport},
        csv_import::MarketBarCsvImporter,
        databento_live::{
            DatabentoCausalAbsenceEnvelope, DatabentoInferenceEvent, DatabentoRealtimeBarEnvelope,
            realtime_envelope_rejection as envelope_rejection,
        },
    },
    engine::features::{ContextReadiness, IncrementalFeatureEngine},
    frozen_universe::{LoadedFrozenUniverse, canonical_model_symbol, load_frozen_universe},
    prediction_ledger::{
        ForecastSettlement, PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION, PredictionLedger,
        PredictionPublicationBatchRequest, PredictionPublicationBatchTargetSla,
        PredictionPublicationCommit, settlement_content_hash,
    },
    predictor::{
        self, ForecastBundle, ForecastContract, FrozenInferenceCache, FrozenPredictorArtifact,
        RealtimeSourceMetadata,
    },
};

pub const DATABENTO_INFERENCE_STATUS_SCHEMA_VERSION: &str = "databento_inference_status.v3";
pub const DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION: &str = "databento_inference_receipt.v4";
pub const DATABENTO_PUBLICATION_SCHEMA_VERSION: &str = "databento_forecast_publication.v1";
pub const DATABENTO_BATCH_MANIFEST_SCHEMA_VERSION: &str = "databento_forecast_batch.v1";
pub const DATABENTO_FORECAST_DATA_SOURCE: &str = "DATABENTO:EQUS.MINI";

fn bounded_worker_count(job_count: usize, available_parallelism: usize) -> usize {
    job_count.min(available_parallelism.max(1)).clamp(1, 4)
}

fn bounded_worker_partition_sizes(job_count: usize, worker_count: usize) -> Vec<usize> {
    if job_count == 0 {
        return Vec::new();
    }
    let worker_count = worker_count.clamp(1, job_count);
    let mut remaining_jobs = job_count;
    let mut sizes = Vec::with_capacity(worker_count);
    for worker_index in 0..worker_count {
        let remaining_workers = worker_count - worker_index;
        let size = remaining_jobs.div_ceil(remaining_workers);
        sizes.push(size);
        remaining_jobs -= size;
    }
    debug_assert_eq!(remaining_jobs, 0);
    sizes
}

fn state_snapshot_matches_batch_cutoff(
    state_timestamp: Option<DateTime<Utc>>,
    batch_cutoff: DateTime<Utc>,
) -> bool {
    state_timestamp == Some(batch_cutoff)
}

fn validate_atomic_target_bundle(
    bundle: &ForecastBundle,
    target: &str,
    cutoff: DateTime<Utc>,
) -> std::result::Result<(), &'static str> {
    let expected_horizons = BTreeSet::from([5_usize, 15, 30, 60]);
    let actual_horizons = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.horizon_minutes)
        .collect::<BTreeSet<_>>();
    if bundle.prediction_layer.len() != expected_horizons.len()
        || actual_horizons != expected_horizons
        || !bundle.unavailable_horizons.is_empty()
    {
        return Err("BATCH_TARGET_EXACT_FOUR_HORIZONS_REQUIRED");
    }
    if bundle.research_only_policy.personalization_used
        || bundle.research_only_policy.user_portfolio_inputs_used
        || bundle.research_only_policy.investment_advice
        || bundle.research_only_policy.execution_instruction
    {
        return Err("BATCH_TARGET_RESEARCH_ONLY_POLICY_REJECTED");
    }
    if bundle.prediction_layer.iter().any(|contract| {
        !contract.symbol.eq_ignore_ascii_case(target)
            || contract.observation_cutoff > cutoff
            || contract.decision.action != "NO_TRADE"
            || contract.decision.eligible
    }) {
        return Err("BATCH_TARGET_CUTOFF_OR_EXECUTION_CONTRACT_REJECTED");
    }
    Ok(())
}

struct TargetRuntime {
    research: ResearchConfig,
    artifact: FrozenPredictorArtifact,
    inference_cache: FrozenInferenceCache,
    feature_engine: IncrementalFeatureEngine,
    target_events: BTreeMap<i64, DatabentoRealtimeBarEnvelope>,
}

struct Runtime {
    config: AppConfig,
    root: PathBuf,
    capability: Option<DataCapabilityReport>,
    ledger: Option<Arc<PredictionLedger>>,
    expected_targets: BTreeSet<String>,
    targets: BTreeMap<String, TargetRuntime>,
    pending_batches: BTreeMap<i64, PendingInferenceBatch>,
    failures: BTreeMap<String, String>,
    settlement_bars: BTreeMap<(i64, String), DatabentoRealtimeBarEnvelope>,
    context_observations: BTreeMap<(i64, String), DatabentoCausalAbsenceEnvelope>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TargetInferenceState {
    WaitingForTarget,
    WaitingForContext,
    CompatibilityRejected,
    Running,
    SlaRejected,
    PublishRejected,
    Published,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TargetInferenceStage {
    ProviderInput,
    FrozenUniverseGate,
    FeatureEngine,
    SourceEnvelopeGate,
    SourceInputManifest,
    FrozenInference,
    SlaGate,
    PredictionLedger,
    PublishStaging,
    PublishCommit,
    Published,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ContextBlockerDiagnostic {
    pub symbol: String,
    pub latest_at_or_before_cutoff: Option<DateTime<Utc>>,
    pub skew_ms: Option<i64>,
    pub expected_intervals: usize,
    pub observed_trade_intervals: usize,
    pub causally_inferred_no_trade_intervals: usize,
    pub unknown_missing_intervals: usize,
    pub continuous_bars: usize,
    pub required_continuous_bars: usize,
    pub reason_codes: Vec<String>,
}

/// Sanitized per-target live-inference state. This contract intentionally
/// excludes paths, hashes, provider payloads, credentials, and raw error
/// strings. The forecast receipt remains the authoritative publication commit
/// marker; this file only explains the producer's current state.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TargetInferenceStatus {
    pub schema_version: String,
    pub observed_at: DateTime<Utc>,
    pub model_symbol: String,
    pub status: TargetInferenceState,
    pub stage: TargetInferenceStage,
    pub reason_code: Option<String>,
    pub cutoff: Option<DateTime<Utc>>,
    pub latest_input_available_at: Option<DateTime<Utc>>,
    pub compute_ms: Option<u64>,
    pub end_to_end_ms: Option<i64>,
    pub budget_ms: i64,
    pub context_blockers: Vec<ContextBlockerDiagnostic>,
    pub forecast_committed: bool,
    pub receipt_committed: bool,
    pub ledger_persisted: bool,
    pub execution_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct InferenceSourceEnvelope {
    symbol: String,
    bar_start: DateTime<Utc>,
    bar_end: DateTime<Utc>,
    provider_available_at: DateTime<Utc>,
    envelope_sha256: String,
    #[serde(default = "default_observed_trade_source_state")]
    observation_state: String,
}

fn default_observed_trade_source_state() -> String {
    "observed_trade_bar".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct InferenceReceipt {
    schema_version: String,
    generated_at: DateTime<Utc>,
    published_at: DateTime<Utc>,
    end_to_end_ms: i64,
    budget_ms: i64,
    provider: String,
    dataset: String,
    data_source: String,
    model_symbol: String,
    model_hash: String,
    forecast_path: String,
    forecast_sha256: String,
    prediction_ids: Vec<String>,
    latest_input_available_at: DateTime<Utc>,
    required_context_symbols: Vec<String>,
    max_context_skew_ms: i64,
    source_envelope_count: usize,
    source_envelopes_sha256: String,
    source_envelopes: Vec<InferenceSourceEnvelope>,
    cutoff_source_envelopes: Vec<DatabentoRealtimeBarEnvelope>,
    #[serde(default)]
    cutoff_context_observations: Vec<DatabentoCausalAbsenceEnvelope>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    batch_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    batch_cutoff: Option<DateTime<Utc>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    batch_committed_at: Option<DateTime<Utc>>,
    ledger_persisted: bool,
    execution_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ImmutableForecastPublication {
    schema_version: String,
    publication_id: String,
    published_at: DateTime<Utc>,
    model_symbol: String,
    forecast_json: String,
    receipt: InferenceReceipt,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct ForecastBatchMember {
    model_symbol: String,
    forecast_sha256: String,
    publication_sha256: String,
    publication_path: String,
    prediction_ids: Vec<String>,
    latest_input_available_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct ImmutableForecastBatchManifest {
    schema_version: String,
    batch_id: String,
    prepared_at: DateTime<Utc>,
    cutoff: DateTime<Utc>,
    symbols: Vec<String>,
    members: Vec<ForecastBatchMember>,
    execution_enabled: bool,
}

#[derive(Debug, Clone)]
pub struct CommittedForecastBatch {
    pub batch_id: String,
    pub cutoff: DateTime<Utc>,
    pub committed_at: DateTime<Utc>,
    pub forecasts: BTreeMap<String, Value>,
}

#[cfg(test)]
#[derive(Debug)]
struct PublishedGeneration {
    end_to_end_ms: i64,
    publication_path: PathBuf,
    publication_sha256: String,
}

#[derive(Debug, Clone)]
struct SourceInputEvidence {
    latest_input_available_at: DateTime<Utc>,
    source_envelopes_sha256: String,
    source_envelopes: Vec<InferenceSourceEnvelope>,
    cutoff_source_envelopes: Vec<DatabentoRealtimeBarEnvelope>,
    cutoff_context_observations: Vec<DatabentoCausalAbsenceEnvelope>,
}

#[derive(Debug)]
struct PendingTargetInference {
    context: ContextReadiness,
    source_input: SourceInputEvidence,
    feature_compute_ms: u128,
}

#[derive(Debug)]
struct PendingInferenceBatch {
    cutoff: DateTime<Utc>,
    targets: BTreeMap<String, PendingTargetInference>,
}

#[derive(Debug)]
struct CompletedTargetInference {
    target: String,
    pending: PendingTargetInference,
    bundle: ForecastBundle,
    compute_ms: u128,
}

struct TargetInferenceWork {
    target: String,
    runtime: TargetRuntime,
    pending: PendingTargetInference,
    result: Option<Result<CompletedTargetInference, String>>,
}

fn write_json_staged(path: &Path, value: &impl Serialize) -> Result<PathBuf> {
    write_bytes_staged(path, &serde_json::to_vec_pretty(value)?)
}

fn write_bytes_staged(path: &Path, bytes: &[u8]) -> Result<PathBuf> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let staged = path.with_extension("json.publish-staged");
    let mut file = fs::File::create(&staged)
        .with_context(|| format!("create staged artifact {}", staged.display()))?;
    file.write_all(bytes)?;
    file.sync_all()?;
    Ok(staged)
}

fn promote_json_staged(staged: &Path, path: &Path) -> Result<()> {
    #[cfg(windows)]
    if path.exists() {
        fs::remove_file(path)
            .with_context(|| format!("replace existing artifact {}", path.display()))?;
    }
    fs::rename(staged, path)
        .with_context(|| format!("promote atomic artifact {}", path.display()))?;
    Ok(())
}

fn write_json_atomic(path: &Path, value: &impl Serialize) -> Result<()> {
    let staged = write_json_staged(path, value)?;
    promote_json_staged(&staged, path)
}

#[cfg(test)]
fn prediction_sla_elapsed_ms(
    source_available_at: DateTime<Utc>,
    prediction_sla_ms: i64,
) -> Result<i64> {
    let elapsed = Utc::now()
        .signed_duration_since(source_available_at)
        .num_milliseconds();
    if prediction_sla_ms <= 0 || elapsed < 0 || elapsed > prediction_sla_ms {
        bail!("PREDICTION_SLA_EXCEEDED:end_to_end_ms={elapsed}:budget_ms={prediction_sla_ms}");
    }
    Ok(elapsed)
}

#[cfg(test)]
fn remove_file_if_present(path: &Path) -> Result<()> {
    if path.exists() {
        fs::remove_file(path)
            .with_context(|| format!("remove publication artifact {}", path.display()))?;
    }
    Ok(())
}

fn sha256_bytes(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn sha256_file(path: &Path) -> Result<String> {
    Ok(sha256_bytes(&fs::read(path).with_context(|| {
        format!("read artifact {}", path.display())
    })?))
}

#[cfg(test)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PublishFailpoint {
    None,
    AfterForecastPromotion,
    BeforeReceiptPromotion,
}

#[cfg(test)]
fn restore_visible_pair(
    forecast_path: &Path,
    receipt_path: &Path,
    previous_forecast: Option<&[u8]>,
    previous_receipt: Option<&[u8]>,
) -> Result<()> {
    // A receipt is the commit marker. Remove it first, restore the forecast,
    // and restore the previous receipt last so readers never accept a new
    // receipt paired with an old forecast.
    remove_file_if_present(receipt_path)?;
    match previous_forecast {
        Some(bytes) => {
            let staged = write_bytes_staged(forecast_path, bytes)?;
            promote_json_staged(&staged, forecast_path)?;
        }
        None => remove_file_if_present(forecast_path)?,
    }
    if let Some(bytes) = previous_receipt {
        let staged = write_bytes_staged(receipt_path, bytes)?;
        promote_json_staged(&staged, receipt_path)?;
    }
    Ok(())
}

#[cfg(test)]
fn publication_error_with_rollback(
    error: anyhow::Error,
    forecast_staged: &Path,
    forecast_path: &Path,
    receipt_path: &Path,
    previous_forecast: Option<&[u8]>,
    previous_receipt: Option<&[u8]>,
) -> anyhow::Error {
    let staged_cleanup = remove_file_if_present(forecast_staged);
    let rollback = restore_visible_pair(
        forecast_path,
        receipt_path,
        previous_forecast,
        previous_receipt,
    );
    match (staged_cleanup, rollback) {
        (Ok(()), Ok(())) => error,
        (cleanup, restore) => anyhow::anyhow!(
            "{error}; PUBLICATION_ROLLBACK_FAILED:staged_cleanup={};restore={}",
            cleanup
                .err()
                .map_or_else(|| "ok".into(), |failure| failure.to_string()),
            restore
                .err()
                .map_or_else(|| "ok".into(), |failure| failure.to_string())
        ),
    }
}

#[cfg(test)]
fn promote_staged_forecast_pair_with_sla_and_failpoint(
    forecast_staged: &Path,
    forecast_path: &Path,
    receipt_path: &Path,
    receipt: &mut InferenceReceipt,
    source_available_at: DateTime<Utc>,
    prediction_sla_ms: i64,
    failpoint: PublishFailpoint,
) -> Result<PublishedGeneration> {
    let previous_forecast = fs::read(forecast_path).ok();
    let previous_receipt = fs::read(receipt_path).ok();
    let fail = |error| {
        publication_error_with_rollback(
            error,
            forecast_staged,
            forecast_path,
            receipt_path,
            previous_forecast.as_deref(),
            previous_receipt.as_deref(),
        )
    };

    prediction_sla_elapsed_ms(source_available_at, prediction_sla_ms).map_err(&fail)?;
    let staged_forecast_sha256 = sha256_file(forecast_staged).map_err(&fail)?;
    receipt.forecast_sha256 = staged_forecast_sha256;
    let published_at = Utc::now();
    let end_to_end_ms = published_at
        .signed_duration_since(source_available_at)
        .num_milliseconds();
    prediction_sla_elapsed_ms(source_available_at, prediction_sla_ms).map_err(&fail)?;
    if end_to_end_ms < 0 || end_to_end_ms > prediction_sla_ms {
        return Err(fail(anyhow::anyhow!(
            "PREDICTION_SLA_EXCEEDED:end_to_end_ms={end_to_end_ms}:budget_ms={prediction_sla_ms}"
        )));
    }
    receipt.published_at = published_at;
    receipt.end_to_end_ms = end_to_end_ms;
    receipt.budget_ms = prediction_sla_ms;
    let forecast_parent = forecast_path
        .parent()
        .context("FORECAST_PUBLICATION_PARENT_MISSING")
        .map_err(&fail)?;
    let publication_root =
        if forecast_parent.file_name().and_then(|value| value.to_str()) == Some("reports") {
            forecast_parent
                .parent()
                .context("FORECAST_PUBLICATION_ROOT_MISSING")
                .map_err(&fail)?
        } else {
            forecast_parent
        };
    let forecast_bytes = fs::read(forecast_staged)
        .map_err(anyhow::Error::from)
        .map_err(&fail)?;
    let (publication_path, publication_sha256) =
        write_immutable_publication(publication_root, &forecast_bytes, receipt).map_err(&fail)?;

    // The immutable, self-contained generation above is the crash-safe
    // canonical record. These latest files remain compatibility projections;
    // a crash between them cannot destroy the previous committed generation.
    promote_json_staged(forecast_staged, forecast_path).map_err(&fail)?;
    if failpoint == PublishFailpoint::AfterForecastPromotion {
        return Err(fail(anyhow::anyhow!(
            "PUBLISH_FAILPOINT_AFTER_FORECAST_PROMOTION"
        )));
    }

    let receipt_staged = write_json_staged(receipt_path, receipt).map_err(&fail)?;

    let commit_result = (|| -> Result<()> {
        prediction_sla_elapsed_ms(source_available_at, prediction_sla_ms)?;
        if sha256_file(forecast_path)? != receipt.forecast_sha256 {
            bail!("PUBLISHED_FORECAST_HASH_MISMATCH");
        }
        if failpoint == PublishFailpoint::BeforeReceiptPromotion {
            bail!("PUBLISH_FAILPOINT_BEFORE_RECEIPT_PROMOTION");
        }
        // The receipt is deliberately the final visible commit marker.
        promote_json_staged(&receipt_staged, receipt_path)?;
        Ok(())
    })();
    if let Err(error) = commit_result {
        let receipt_cleanup = remove_file_if_present(&receipt_staged);
        let error = match receipt_cleanup {
            Ok(()) => error,
            Err(cleanup) => anyhow::anyhow!("{error}; RECEIPT_STAGING_CLEANUP_FAILED:{cleanup}"),
        };
        return Err(fail(error));
    }
    Ok(PublishedGeneration {
        end_to_end_ms,
        publication_path,
        publication_sha256,
    })
}

#[cfg(test)]
fn promote_staged_forecast_pair_with_sla(
    forecast_staged: &Path,
    forecast_path: &Path,
    receipt_path: &Path,
    receipt: &mut InferenceReceipt,
    source_available_at: DateTime<Utc>,
    prediction_sla_ms: i64,
) -> Result<PublishedGeneration> {
    promote_staged_forecast_pair_with_sla_and_failpoint(
        forecast_staged,
        forecast_path,
        receipt_path,
        receipt,
        source_available_at,
        prediction_sla_ms,
        PublishFailpoint::None,
    )
}

fn canonical_live_symbol(raw: &str) -> Result<String> {
    canonical_model_symbol(raw)
}

fn configured_model_symbols(config: &AppConfig) -> BTreeSet<String> {
    config
        .live
        .forecast_symbols
        .iter()
        .filter_map(|symbol| canonical_live_symbol(symbol).ok())
        .collect()
}

pub fn forecast_path(root: &Path, target: &str) -> PathBuf {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    if canonical == "spy" {
        return root.join("reports/forecast_contract_live_latest.json");
    }
    root.join(format!(
        "reports/forecast_contract_live_{canonical}_latest.json"
    ))
}

pub fn status_path(root: &Path, target: &str) -> PathBuf {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    if canonical == "spy" {
        return root.join("live/databento_inference_status.json");
    }
    root.join(format!("live/databento_inference_status_{canonical}.json"))
}

pub fn receipt_path(root: &Path, target: &str) -> PathBuf {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    root.join(format!(
        "live/databento_inference_receipt_{canonical}_latest.json"
    ))
}

fn publication_directory(root: &Path, target: &str) -> PathBuf {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    root.join("live")
        .join("databento_publications")
        .join(canonical)
}

fn batch_publication_directory(root: &Path) -> PathBuf {
    root.join("live").join("databento_batches")
}

fn batch_manifest_path(
    root: &Path,
    cutoff: DateTime<Utc>,
    manifest_sha256: &str,
) -> Result<PathBuf> {
    let cutoff_nanos = cutoff
        .timestamp_nanos_opt()
        .context("DATABENTO_BATCH_CUTOFF_OUT_OF_RANGE")?;
    Ok(batch_publication_directory(root)
        .join(format!("{cutoff_nanos}-{}.json", &manifest_sha256[..16])))
}

fn write_immutable_batch_manifest(
    root: &Path,
    manifest: &ImmutableForecastBatchManifest,
) -> Result<(PathBuf, String)> {
    let bytes = serde_json::to_vec_pretty(manifest)?;
    let sha256 = sha256_bytes(&bytes);
    let path = batch_manifest_path(root, manifest.cutoff, &sha256)?;
    if path.exists() {
        let existing = fs::read(&path)?;
        if existing != bytes {
            bail!("DATABENTO_BATCH_MANIFEST_ID_COLLISION");
        }
        return Ok((path, sha256));
    }
    let staged = write_bytes_staged(&path, &bytes)?;
    promote_json_staged(&staged, &path)?;
    Ok((path, sha256))
}

fn write_immutable_publication(
    root: &Path,
    forecast_bytes: &[u8],
    receipt: &InferenceReceipt,
) -> Result<(PathBuf, String)> {
    serde_json::from_slice::<Value>(forecast_bytes)
        .context("IMMUTABLE_PUBLICATION_FORECAST_JSON_INVALID")?;
    let forecast_sha256 = sha256_bytes(forecast_bytes);
    if receipt.forecast_sha256 != forecast_sha256 {
        bail!("IMMUTABLE_PUBLICATION_FORECAST_HASH_MISMATCH");
    }
    let published_nanos = receipt
        .published_at
        .timestamp_nanos_opt()
        .context("IMMUTABLE_PUBLICATION_TIMESTAMP_OUT_OF_RANGE")?;
    let publication_id = format!(
        "databento:{}:{published_nanos}:{}",
        receipt.model_symbol,
        &forecast_sha256[..16]
    );
    let path = publication_directory(root, &receipt.model_symbol)
        .join(format!("{published_nanos}-{}.json", &forecast_sha256[..16]));
    if path.exists() {
        let bytes = fs::read(&path)?;
        let existing: ImmutableForecastPublication = serde_json::from_slice(&bytes)?;
        if existing.publication_id != publication_id
            || existing.forecast_json.as_bytes() != forecast_bytes
            || serde_json::to_value(&existing.receipt)? != serde_json::to_value(receipt)?
        {
            bail!("IMMUTABLE_PUBLICATION_ID_COLLISION");
        }
        return Ok((path, sha256_bytes(&bytes)));
    }
    let publication = ImmutableForecastPublication {
        schema_version: DATABENTO_PUBLICATION_SCHEMA_VERSION.into(),
        publication_id,
        published_at: receipt.published_at,
        model_symbol: receipt.model_symbol.clone(),
        forecast_json: String::from_utf8(forecast_bytes.to_vec())
            .context("IMMUTABLE_PUBLICATION_FORECAST_NOT_UTF8")?,
        receipt: receipt.clone(),
    };
    let staged = write_json_staged(&path, &publication)?;
    promote_json_staged(&staged, &path)?;
    Ok((path.clone(), sha256_file(&path)?))
}

fn committed_immutable_publication(
    root: &Path,
    target: &str,
) -> Option<(Value, InferenceReceipt, PathBuf, String)> {
    let expected = canonical_live_symbol(target).ok()?;
    let ledger_path = root.join("state/prediction_ledger.sqlite3");
    if !ledger_path.is_file() {
        return None;
    }
    let ledger = PredictionLedger::open(&ledger_path).ok()?;
    let directory = publication_directory(root, target);
    let entries = fs::read_dir(directory).ok()?;
    let mut valid = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|value| value.to_str()) != Some("json") {
            continue;
        }
        let bytes = match fs::read(&path) {
            Ok(bytes) => bytes,
            Err(_) => continue,
        };
        let publication_sha256 = sha256_bytes(&bytes);
        let publication: ImmutableForecastPublication = match serde_json::from_slice(&bytes) {
            Ok(publication) => publication,
            Err(_) => continue,
        };
        let receipt = &publication.receipt;
        if publication.schema_version != DATABENTO_PUBLICATION_SCHEMA_VERSION
            || publication.published_at != receipt.published_at
            || !publication.model_symbol.eq_ignore_ascii_case(&expected)
            || !receipt.model_symbol.eq_ignore_ascii_case(&expected)
            || receipt.forecast_sha256 != sha256_bytes(publication.forecast_json.as_bytes())
            || receipt.prediction_ids.is_empty()
            || receipt.execution_enabled
            || receipt.prediction_ids.iter().any(|prediction_id| {
                ledger
                    .publication_commit(prediction_id)
                    .ok()
                    .flatten()
                    .is_none_or(|commit| {
                        !commit.provider.eq_ignore_ascii_case("DATABENTO")
                            || commit.forecast_sha256 != receipt.forecast_sha256
                            || commit.publication_sha256 != publication_sha256
                            || commit.published_at != receipt.published_at
                            || commit.evidence_kind != "live_forecast_publication_commit"
                    })
            })
        {
            continue;
        }
        let forecast = match serde_json::from_str::<Value>(&publication.forecast_json) {
            Ok(forecast) => forecast,
            Err(_) => continue,
        };
        valid.push((
            receipt.published_at,
            forecast,
            receipt.clone(),
            path,
            publication_sha256,
        ));
    }
    valid.sort_by_key(|row| row.0);
    valid
        .pop()
        .map(|(_, forecast, receipt, path, hash)| (forecast, receipt, path, hash))
}

fn safe_batch_member_path(root: &Path, relative: &str) -> Option<PathBuf> {
    let relative = Path::new(relative);
    if relative.is_absolute()
        || relative
            .components()
            .any(|component| !matches!(component, Component::Normal(_) | Component::CurDir))
    {
        return None;
    }
    Some(root.join(relative))
}

fn validate_committed_batch_manifest(
    root: &Path,
    ledger: &PredictionLedger,
    bytes: &[u8],
    expected_symbols: &BTreeSet<String>,
) -> Option<CommittedForecastBatch> {
    let manifest_sha256 = sha256_bytes(bytes);
    let manifest: ImmutableForecastBatchManifest = serde_json::from_slice(bytes).ok()?;
    if manifest.schema_version != DATABENTO_BATCH_MANIFEST_SCHEMA_VERSION
        || manifest.execution_enabled
        || manifest.symbols.len() != 9
        || manifest.members.len() != 9
        || manifest.symbols.windows(2).any(|pair| pair[0] >= pair[1])
        || manifest.symbols.iter().cloned().collect::<BTreeSet<_>>() != *expected_symbols
        || manifest
            .members
            .iter()
            .map(|member| member.model_symbol.clone())
            .collect::<BTreeSet<_>>()
            != *expected_symbols
    {
        return None;
    }
    let marker = ledger
        .publication_batch_commit(&manifest.batch_id)
        .ok()
        .flatten()?;
    if marker.manifest_sha256 != manifest_sha256
        || marker.cutoff != manifest.cutoff
        || marker.symbols != manifest.symbols
        || !marker.execution_disabled
        || marker.prediction_ids.len() != 36
        || marker.publication_ids.len() != 36
    {
        return None;
    }

    let marker_prediction_ids = marker
        .prediction_ids
        .iter()
        .cloned()
        .collect::<BTreeSet<_>>();
    let target_slas = marker
        .target_slas
        .iter()
        .map(|sla| (sla.symbol.clone(), sla))
        .collect::<BTreeMap<_, _>>();
    if target_slas.len() != 9
        || target_slas.keys().cloned().collect::<BTreeSet<_>>() != *expected_symbols
    {
        return None;
    }
    let mut observed_prediction_ids = BTreeSet::new();
    let mut forecasts = BTreeMap::new();
    for member in &manifest.members {
        if member.prediction_ids.len() != 4
            || member
                .prediction_ids
                .iter()
                .any(|prediction_id| !observed_prediction_ids.insert(prediction_id.clone()))
        {
            return None;
        }
        let path = safe_batch_member_path(root, &member.publication_path)?;
        if !path.starts_with(publication_directory(root, &member.model_symbol)) {
            return None;
        }
        let publication_bytes = fs::read(path).ok()?;
        if sha256_bytes(&publication_bytes) != member.publication_sha256 {
            return None;
        }
        let publication: ImmutableForecastPublication =
            serde_json::from_slice(&publication_bytes).ok()?;
        let receipt = &publication.receipt;
        if publication.schema_version != DATABENTO_PUBLICATION_SCHEMA_VERSION
            || publication.model_symbol != member.model_symbol
            || receipt.schema_version != DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION
            || receipt.model_symbol != member.model_symbol
            || receipt.batch_id.as_deref() != Some(manifest.batch_id.as_str())
            || receipt.batch_cutoff != Some(manifest.cutoff)
            || receipt.batch_committed_at.is_some()
            || receipt.provider != "databento"
            || receipt.dataset != "EQUS.MINI"
            || receipt.data_source != DATABENTO_FORECAST_DATA_SOURCE
            || !receipt.ledger_persisted
            || receipt.execution_enabled
            || receipt.prediction_ids != member.prediction_ids
            || receipt.forecast_sha256 != member.forecast_sha256
            || receipt.latest_input_available_at != member.latest_input_available_at
            || publication.published_at != manifest.prepared_at
            || receipt.published_at != manifest.prepared_at
            || marker.committed_at < manifest.prepared_at
            || sha256_bytes(publication.forecast_json.as_bytes()) != member.forecast_sha256
        {
            return None;
        }
        let target_sla = *target_slas.get(&member.model_symbol)?;
        let prepared_elapsed_ms = manifest
            .prepared_at
            .signed_duration_since(member.latest_input_available_at)
            .num_milliseconds();
        let committed_elapsed_ms = marker
            .committed_at
            .signed_duration_since(member.latest_input_available_at)
            .num_milliseconds();
        if target_sla.source_available_at != member.latest_input_available_at
            || target_sla.budget_ms != receipt.budget_ms
            || receipt.end_to_end_ms != prepared_elapsed_ms
            || prepared_elapsed_ms < 0
            || committed_elapsed_ms < 0
            || committed_elapsed_ms > target_sla.budget_ms
        {
            return None;
        }
        let forecast: Value = serde_json::from_str(&publication.forecast_json).ok()?;
        let forecast_rows = forecast.get("prediction_layer").and_then(Value::as_array)?;
        if forecast_rows.len() != 4 {
            return None;
        }
        let forecast_rows_by_id = forecast_rows
            .iter()
            .filter_map(|row| {
                row.get("prediction_id")
                    .and_then(Value::as_str)
                    .map(|prediction_id| (prediction_id.to_string(), row))
            })
            .collect::<BTreeMap<_, _>>();
        if forecast_rows_by_id.len() != 4 {
            return None;
        }
        for prediction_id in &member.prediction_ids {
            let commit = ledger.publication_commit(prediction_id).ok().flatten()?;
            if commit.prediction_id != *prediction_id
                || commit.provider != "DATABENTO"
                || commit.forecast_sha256 != member.forecast_sha256
                || commit.publication_sha256 != member.publication_sha256
                || commit.published_at != manifest.prepared_at
                || commit.evidence_kind != "live_forecast_publication_commit"
                || !marker.publication_ids.contains(&commit.publication_id)
            {
                return None;
            }
            let canonical_prediction = ledger
                .batch_published_prediction_payload(prediction_id)
                .ok()
                .flatten()?;
            if forecast_rows_by_id.get(prediction_id).copied() != Some(&canonical_prediction) {
                return None;
            }
        }
        let forecast_prediction_ids = forecast
            .get("prediction_layer")
            .and_then(Value::as_array)?
            .iter()
            .filter_map(|row| row.get("prediction_id").and_then(Value::as_str))
            .map(str::to_string)
            .collect::<BTreeSet<_>>();
        if forecast_prediction_ids
            != member
                .prediction_ids
                .iter()
                .cloned()
                .collect::<BTreeSet<_>>()
        {
            return None;
        }
        forecasts.insert(member.model_symbol.clone(), forecast);
    }
    if observed_prediction_ids != marker_prediction_ids {
        return None;
    }
    Some(CommittedForecastBatch {
        batch_id: marker.batch_id,
        cutoff: marker.cutoff,
        committed_at: marker.committed_at,
        forecasts,
    })
}

/// Resolve the newest all-nine generation for which the immutable manifest,
/// all nine member artifacts, all 36 publication bindings, and the single
/// transactional ledger marker agree exactly.
pub fn read_latest_committed_forecast_batch(
    root: &Path,
    expected_symbols: &BTreeSet<String>,
) -> Option<CommittedForecastBatch> {
    if expected_symbols.len() != 9 {
        return None;
    }
    let ledger = PredictionLedger::open(&root.join("state/prediction_ledger.sqlite3")).ok()?;
    let entries = fs::read_dir(batch_publication_directory(root)).ok()?;
    let mut valid = entries
        .flatten()
        .filter_map(|entry| {
            let path = entry.path();
            (path.extension().and_then(|value| value.to_str()) == Some("json"))
                .then(|| fs::read(path).ok())
                .flatten()
        })
        .filter_map(|bytes| {
            validate_committed_batch_manifest(root, &ledger, &bytes, expected_symbols)
        })
        .collect::<Vec<_>>();
    valid.sort_by(|left, right| {
        left.committed_at
            .cmp(&right.committed_at)
            .then_with(|| left.batch_id.cmp(&right.batch_id))
    });
    valid.pop()
}

/// Resolve the newest crash-safe Databento generation whose prediction rows
/// all have append-only publication commits. Orphan generations from a crash
/// or failed ledger commit are skipped, so the previous committed generation
/// remains readable.
pub fn read_latest_committed_forecast(root: &Path, target: &str) -> Option<Value> {
    let canonical = canonical_live_symbol(target).ok()?;
    let batch_symbols = BTreeSet::from([
        "AAPL".to_string(),
        "BE".to_string(),
        "IGV".to_string(),
        "MU".to_string(),
        "NBIS".to_string(),
        "NVDA".to_string(),
        "QQQ".to_string(),
        "SOXX".to_string(),
        "SPY".to_string(),
    ]);
    if let Some(batch) = read_latest_committed_forecast_batch(root, &batch_symbols) {
        return batch.forecasts.get(&canonical).cloned();
    }
    // Legacy per-symbol history remains readable only until the first batch
    // manifest exists. Once batch publication starts, orphan/partial members
    // can never fall back to independently committed generations.
    if fs::read_dir(batch_publication_directory(root))
        .ok()
        .is_some_and(|entries| entries.flatten().any(|entry| entry.path().is_file()))
    {
        return None;
    }
    committed_immutable_publication(root, target).map(|row| row.0)
}

pub fn immutable_publication_history_exists(root: &Path, target: &str) -> bool {
    fs::read_dir(publication_directory(root, target))
        .ok()
        .is_some_and(|entries| {
            entries.flatten().any(|entry| {
                entry.path().extension().and_then(|value| value.to_str()) == Some("json")
            })
        })
}

fn sanitized_context_reason(reason: &str) -> &'static str {
    if reason == "MISSING_AT_OR_BEFORE_CUTOFF" {
        "MISSING_AT_OR_BEFORE_CUTOFF"
    } else if reason == "MISSING_OBSERVED_TRADE_BAR_AT_OR_BEFORE_CUTOFF" {
        "MISSING_OBSERVED_TRADE_BAR_AT_OR_BEFORE_CUTOFF"
    } else if reason == "STALE_OR_FUTURE_CONTEXT" {
        "STALE_OR_FUTURE_CONTEXT"
    } else if reason.starts_with("UNKNOWN_MISSING_INTERVALS:") {
        "UNKNOWN_MISSING_INTERVALS"
    } else if reason
        .starts_with("CAUSALLY_INFERRED_NO_TRADE_NOT_ELIGIBLE_FOR_FROZEN_FEATURE_SCHEMA:")
    {
        "CAUSALLY_INFERRED_NO_TRADE_NOT_ELIGIBLE_FOR_FROZEN_FEATURE_SCHEMA"
    } else if reason.starts_with("INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS:") {
        "INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS"
    } else if reason.starts_with("INSUFFICIENT_CONTIGUOUS_HISTORY:") {
        "INSUFFICIENT_CONTIGUOUS_HISTORY"
    } else if reason == "INELIGIBLE_CONTEXT_OBSERVATION_STATE" {
        "INELIGIBLE_CONTEXT_OBSERVATION_STATE"
    } else if reason.starts_with("DUPLICATE_OBSERVED_TRADE_BAR:") {
        "DUPLICATE_OBSERVED_TRADE_BAR"
    } else if reason.starts_with("INVALID_OR_ZERO_VOLUME_TRADE_BAR:") {
        "INVALID_OR_ZERO_VOLUME_TRADE_BAR"
    } else if reason.starts_with("CONFLICTING_TRADE_AND_CAUSAL_ABSENCE_EVIDENCE:") {
        "CONFLICTING_TRADE_AND_CAUSAL_ABSENCE_EVIDENCE"
    } else if reason.starts_with("INVALID_EXPLICIT_INTERVAL_EVIDENCE:") {
        "INVALID_EXPLICIT_INTERVAL_EVIDENCE"
    } else if reason.starts_with("CONFLICTING_EXPLICIT_INTERVAL_EVIDENCE:") {
        "CONFLICTING_EXPLICIT_INTERVAL_EVIDENCE"
    } else {
        "CONTEXT_INPUT_REJECTED"
    }
}

fn context_blocker_diagnostics(
    context: Option<&ContextReadiness>,
) -> Vec<ContextBlockerDiagnostic> {
    let Some(context) = context else {
        return Vec::new();
    };
    context
        .symbols
        .iter()
        .filter(|row| !row.ready)
        .map(|row| ContextBlockerDiagnostic {
            symbol: row
                .symbol
                .trim()
                .trim_start_matches("US.")
                .to_ascii_uppercase(),
            latest_at_or_before_cutoff: row.latest_at_or_before_cutoff,
            skew_ms: row.skew_ms,
            expected_intervals: row.expected_intervals,
            observed_trade_intervals: row.observed_trade_intervals,
            causally_inferred_no_trade_intervals: row.causally_inferred_no_trade_intervals,
            unknown_missing_intervals: row.unknown_missing_intervals,
            continuous_bars: row.continuous_bars,
            required_continuous_bars: context.minimum_continuous_bars,
            reason_codes: row
                .reasons
                .iter()
                .map(|reason| sanitized_context_reason(reason).to_string())
                .collect(),
        })
        .collect()
}

fn sanitized_runtime_failure(reason: &str) -> &'static str {
    if reason.starts_with("HISTORICAL_BARS_UNAVAILABLE:") {
        "HISTORICAL_STATE_UNAVAILABLE"
    } else if reason.starts_with("UNIVERSE_REGISTRY_UNAVAILABLE:") {
        "MODEL_UNIVERSE_UNAVAILABLE"
    } else if reason.starts_with("DATA_CAPABILITY_UNAVAILABLE:") {
        "DATA_CAPABILITY_UNAVAILABLE"
    } else if reason.starts_with("PREDICTION_LEDGER_UNAVAILABLE:") {
        "PREDICTION_LEDGER_UNAVAILABLE"
    } else if reason.starts_with("FEATURE_ENGINE_INITIALIZATION_FAILED:") {
        "FEATURE_ENGINE_INITIALIZATION_FAILED"
    } else if reason.starts_with("CURRENT_SESSION_RESTORE_FAILED:") {
        "CURRENT_SESSION_RESTORE_FAILED"
    } else if reason == "RESEARCH_TARGET_MAPPING_MISSING" {
        "RESEARCH_TARGET_MAPPING_MISSING"
    } else if reason == "LIVE_FORECAST_SYMBOLS_EMPTY_OR_INVALID" {
        "LIVE_FORECAST_SYMBOLS_EMPTY_OR_INVALID"
    } else {
        "MODEL_ARTIFACT_OR_COMPATIBILITY_REJECTED"
    }
}

fn sanitized_source_input_failure(reason: &str) -> &'static str {
    if reason.contains("DATABENTO_CONTEXT_CUTOFF_MISSING") {
        "CONTEXT_CUTOFF_MISSING"
    } else if reason.contains("DATABENTO_CONTEXT_CUTOFF_OUTSIDE_SKEW") {
        "CONTEXT_CUTOFF_OUTSIDE_SKEW"
    } else if reason.contains("DATABENTO_CONTEXT_ENVELOPE_MISSING") {
        "CONTEXT_SOURCE_ENVELOPE_MISSING"
    } else if reason.contains("DATABENTO_CONTEXT_SOURCE_ENVELOPE_REJECTED") {
        "CONTEXT_SOURCE_ENVELOPE_REJECTED"
    } else if reason.contains("DATABENTO_CONTEXT_SYMBOL_SET_MISMATCH") {
        "CONTEXT_SYMBOL_SET_MISMATCH"
    } else if reason.contains("DATABENTO_SOURCE_MANIFEST_INCOMPLETE") {
        "SOURCE_MANIFEST_INCOMPLETE"
    } else if reason.contains("DATABENTO_SOURCE_MANIFEST_ENVELOPE_REJECTED") {
        "SOURCE_MANIFEST_ENVELOPE_REJECTED"
    } else if reason.contains("DATABENTO_CUTOFF_SOURCE_NOT_IN_MANIFEST") {
        "CUTOFF_SOURCE_NOT_IN_MANIFEST"
    } else {
        "SOURCE_INPUT_CONTEXT_INVALID"
    }
}

fn non_ready_update_state(reason: &str) -> (TargetInferenceState, &'static str) {
    if reason == "TARGET_BAR_NOT_RECEIVED" {
        (TargetInferenceState::WaitingForTarget, "TARGET_BAR_PENDING")
    } else if reason == "CONTEXT_NOT_READY_NO_FORECAST" {
        (TargetInferenceState::WaitingForContext, "CONTEXT_NOT_READY")
    } else if reason.starts_with("SESSION_WARMUP_NO_FORECAST:") {
        (
            TargetInferenceState::WaitingForTarget,
            "TARGET_FEATURE_WARMUP",
        )
    } else {
        (
            TargetInferenceState::CompatibilityRejected,
            "TARGET_FEATURE_STATE_UNAVAILABLE",
        )
    }
}

fn saturated_u64(value: u128) -> u64 {
    u64::try_from(value).unwrap_or(u64::MAX)
}

struct TargetStatusUpdate<'a> {
    target: &'a str,
    status: TargetInferenceState,
    stage: TargetInferenceStage,
    reason_code: Option<&'a str>,
    cutoff: Option<DateTime<Utc>>,
    latest_input_available_at: Option<DateTime<Utc>>,
    compute_ms: Option<u128>,
    end_to_end_ms: Option<i64>,
    budget_ms: i64,
    context: Option<&'a ContextReadiness>,
    forecast_committed: bool,
    receipt_committed: bool,
    ledger_persisted: bool,
}

fn persist_target_status(root: &Path, update: TargetStatusUpdate<'_>) {
    let model_symbol = match canonical_live_symbol(update.target) {
        Ok(symbol) => symbol,
        Err(_) => update.target.to_ascii_uppercase(),
    };
    let status = TargetInferenceStatus {
        schema_version: DATABENTO_INFERENCE_STATUS_SCHEMA_VERSION.to_string(),
        observed_at: Utc::now(),
        model_symbol,
        status: update.status,
        stage: update.stage,
        reason_code: update.reason_code.map(str::to_string),
        cutoff: update.cutoff,
        latest_input_available_at: update.latest_input_available_at,
        compute_ms: update.compute_ms.map(saturated_u64),
        end_to_end_ms: update.end_to_end_ms,
        budget_ms: update.budget_ms,
        context_blockers: context_blocker_diagnostics(update.context),
        forecast_committed: update.forecast_committed,
        receipt_committed: update.receipt_committed,
        ledger_persisted: update.ledger_persisted,
        execution_enabled: false,
    };
    let path = status_path(root, update.target);
    if let Err(error) = write_json_atomic(&path, &status) {
        tracing::error!(
            %error,
            target = update.target,
            "write sanitized Databento target inference status"
        );
    }
}

/// Read a target status only when it matches the current sanitized contract.
/// Unknown or legacy status files fail closed rather than being interpreted as
/// live forecast readiness.
pub fn read_target_status(root: &Path, target: &str) -> Option<TargetInferenceStatus> {
    let expected = canonical_live_symbol(target).ok()?;
    let status = fs::read(status_path(root, target))
        .ok()
        .and_then(|bytes| serde_json::from_slice::<TargetInferenceStatus>(&bytes).ok())?;
    (status.schema_version == DATABENTO_INFERENCE_STATUS_SCHEMA_VERSION
        && status.model_symbol.eq_ignore_ascii_case(&expected)
        && !status.execution_enabled)
        .then_some(status)
}

fn envelope_sha256(envelope: &DatabentoRealtimeBarEnvelope) -> Result<String> {
    Ok(format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(envelope)?)
    ))
}

fn inference_source_envelope(
    envelope: &DatabentoRealtimeBarEnvelope,
) -> Result<InferenceSourceEnvelope> {
    Ok(InferenceSourceEnvelope {
        symbol: canonical_live_symbol(&envelope.bar.symbol)?,
        bar_start: envelope.bar_start,
        bar_end: envelope.bar_end,
        provider_available_at: envelope.provider_available_at,
        envelope_sha256: envelope_sha256(envelope)?,
        observation_state: "observed_trade_bar".to_string(),
    })
}

fn inference_absence_source_envelope(
    envelope: &DatabentoCausalAbsenceEnvelope,
) -> Result<InferenceSourceEnvelope> {
    if !envelope.validate() {
        bail!("DATABENTO_CAUSAL_ABSENCE_ENVELOPE_INVALID");
    }
    Ok(InferenceSourceEnvelope {
        symbol: canonical_live_symbol(&envelope.observation.symbol)?,
        bar_start: envelope.interval_start,
        bar_end: envelope.interval_end,
        provider_available_at: envelope.received_at,
        envelope_sha256: format!("{:x}", Sha256::digest(serde_json::to_vec(envelope)?)),
        observation_state: "causally_inferred_no_trade".to_string(),
    })
}

fn source_envelopes_sha256(envelopes: &[InferenceSourceEnvelope]) -> Result<String> {
    Ok(format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(envelopes)?)
    ))
}

fn source_input_evidence(
    target: &str,
    cutoff: DateTime<Utc>,
    target_event: &DatabentoRealtimeBarEnvelope,
    context: &ContextReadiness,
    live: &LiveConfig,
    available_envelopes: &BTreeMap<(i64, String), DatabentoRealtimeBarEnvelope>,
    available_context_observations: &BTreeMap<(i64, String), DatabentoCausalAbsenceEnvelope>,
) -> Result<SourceInputEvidence> {
    let target = canonical_live_symbol(target)?;
    if live.max_context_skew_ms <= 0
        || context.cutoff != cutoff
        || !context.ready
        || target_event.bar_start != cutoff
        || !target_event.bar.symbol.eq_ignore_ascii_case(&target)
    {
        bail!("DATABENTO_SOURCE_INPUT_CONTEXT_INVALID");
    }
    if let Some(reason) = envelope_rejection(target_event, live.stale_after_ms) {
        bail!("DATABENTO_TARGET_SOURCE_ENVELOPE_REJECTED:{reason}");
    }

    let required = live
        .required_context_symbols
        .iter()
        .map(|symbol| canonical_live_symbol(symbol))
        .collect::<Result<BTreeSet<_>>>()?;
    let reported = context
        .symbols
        .iter()
        .map(|row| canonical_live_symbol(&row.symbol).map(|symbol| (symbol, row)))
        .collect::<Result<BTreeMap<_, _>>>()?;
    if reported.keys().cloned().collect::<BTreeSet<_>>() != required {
        bail!("DATABENTO_CONTEXT_SYMBOL_SET_MISMATCH");
    }

    let mut cutoff_sources = BTreeMap::<String, DatabentoRealtimeBarEnvelope>::new();
    let mut cutoff_absences = BTreeMap::<String, DatabentoCausalAbsenceEnvelope>::new();
    cutoff_sources.insert(target.clone(), target_event.clone());
    for symbol in &required {
        let row = reported
            .get(symbol)
            .context("DATABENTO_CONTEXT_READINESS_ROW_MISSING")?;
        let timestamp = row
            .latest_at_or_before_cutoff
            .context("DATABENTO_CONTEXT_CUTOFF_MISSING")?;
        let skew_ms = cutoff.signed_duration_since(timestamp).num_milliseconds();
        if !row.ready || skew_ms < 0 || skew_ms > live.max_context_skew_ms {
            bail!("DATABENTO_CONTEXT_CUTOFF_OUTSIDE_SKEW");
        }
        if let Some(envelope) =
            available_envelopes.get(&(timestamp.timestamp_millis(), symbol.clone()))
        {
            if let Some(reason) = envelope_rejection(envelope, live.stale_after_ms) {
                bail!("DATABENTO_CONTEXT_SOURCE_ENVELOPE_REJECTED:{symbol}:{reason}");
            }
            cutoff_sources.insert(symbol.clone(), envelope.clone());
        } else if let Some(absence) =
            available_context_observations.get(&(timestamp.timestamp_millis(), symbol.clone()))
        {
            if !absence.validate() {
                bail!("DATABENTO_CONTEXT_CAUSAL_ABSENCE_REJECTED:{symbol}");
            }
            cutoff_absences.insert(symbol.clone(), absence.clone());
        } else {
            bail!("DATABENTO_CONTEXT_ENVELOPE_MISSING:{symbol}");
        }
    }

    let mut relevant_symbols = required;
    relevant_symbols.insert(target);
    let session_date = cutoff.with_timezone(&New_York).date_naive();
    let mut source_envelopes = available_envelopes
        .values()
        .filter(|envelope| {
            envelope.bar_start <= cutoff
                && envelope.bar_start.with_timezone(&New_York).date_naive() == session_date
                && relevant_symbols.contains(
                    &envelope
                        .bar
                        .symbol
                        .trim()
                        .trim_start_matches("US.")
                        .to_ascii_uppercase(),
                )
        })
        .map(|envelope| {
            if let Some(reason) = envelope_rejection(envelope, live.stale_after_ms) {
                bail!("DATABENTO_SOURCE_MANIFEST_ENVELOPE_REJECTED:{reason}");
            }
            inference_source_envelope(envelope)
        })
        .collect::<Result<Vec<_>>>()?;
    source_envelopes.extend(
        available_context_observations
            .values()
            .filter(|envelope| {
                envelope.interval_start <= cutoff
                    && envelope
                        .interval_start
                        .with_timezone(&New_York)
                        .date_naive()
                        == session_date
                    && relevant_symbols.contains(&envelope.observation.symbol.to_ascii_uppercase())
            })
            .map(inference_absence_source_envelope)
            .collect::<Result<Vec<_>>>()?,
    );
    source_envelopes.sort_by(|left, right| {
        left.bar_start
            .cmp(&right.bar_start)
            .then_with(|| left.symbol.cmp(&right.symbol))
            .then_with(|| left.provider_available_at.cmp(&right.provider_available_at))
    });
    source_envelopes.dedup_by(|right, left| {
        right.bar_start == left.bar_start
            && right.symbol == left.symbol
            && right.observation_state == left.observation_state
    });
    if source_envelopes.is_empty()
        || relevant_symbols.iter().any(|symbol| {
            !source_envelopes
                .iter()
                .any(|envelope| &envelope.symbol == symbol)
        })
    {
        bail!("DATABENTO_SOURCE_MANIFEST_INCOMPLETE");
    }
    for envelope in cutoff_sources.values() {
        let digest = inference_source_envelope(envelope)?;
        if !source_envelopes.contains(&digest) {
            bail!("DATABENTO_CUTOFF_SOURCE_NOT_IN_MANIFEST");
        }
    }
    for envelope in cutoff_absences.values() {
        let digest = inference_absence_source_envelope(envelope)?;
        if !source_envelopes.contains(&digest) {
            bail!("DATABENTO_CUTOFF_CAUSAL_ABSENCE_NOT_IN_MANIFEST");
        }
    }
    let latest_input_available_at = source_envelopes
        .iter()
        .map(|envelope| envelope.provider_available_at)
        .max()
        .context("DATABENTO_SOURCE_MANIFEST_EMPTY")?;
    let source_envelopes_sha256 = source_envelopes_sha256(&source_envelopes)?;
    Ok(SourceInputEvidence {
        latest_input_available_at,
        source_envelopes_sha256,
        source_envelopes,
        cutoff_source_envelopes: cutoff_sources.into_values().collect(),
        cutoff_context_observations: cutoff_absences.into_values().collect(),
    })
}

fn value_datetime(value: Option<&Value>) -> Option<DateTime<Utc>> {
    value
        .and_then(Value::as_str)
        .and_then(|raw| DateTime::parse_from_rfc3339(raw).ok())
        .map(|timestamp| timestamp.with_timezone(&Utc))
}

fn read_current_session_envelopes(
    path: &Path,
    session_date: chrono::NaiveDate,
    maximum_lag_ms: i64,
) -> Vec<DatabentoRealtimeBarEnvelope> {
    let Ok(file) = fs::File::open(path) else {
        return Vec::new();
    };
    let mut envelopes = BufReader::new(file)
        .lines()
        .map_while(std::result::Result::ok)
        .filter_map(|line| serde_json::from_str::<DatabentoRealtimeBarEnvelope>(&line).ok())
        .filter(|envelope| {
            envelope.bar_start.with_timezone(&New_York).date_naive() == session_date
                && envelope_rejection(envelope, maximum_lag_ms).is_none()
        })
        .collect::<Vec<_>>();
    envelopes.sort_by(|left, right| {
        left.bar_start
            .cmp(&right.bar_start)
            .then_with(|| left.bar.symbol.cmp(&right.bar.symbol))
            .then_with(|| left.provider_available_at.cmp(&right.provider_available_at))
    });
    envelopes.dedup_by(|right, left| {
        right.bar_start == left.bar_start && right.bar.symbol.eq_ignore_ascii_case(&left.bar.symbol)
    });
    envelopes
}

fn read_current_session_context_observations(
    path: &Path,
    session_date: chrono::NaiveDate,
) -> Vec<DatabentoCausalAbsenceEnvelope> {
    let Ok(file) = fs::File::open(path) else {
        return Vec::new();
    };
    let mut envelopes = BufReader::new(file)
        .lines()
        .map_while(std::result::Result::ok)
        .filter_map(|line| serde_json::from_str::<DatabentoCausalAbsenceEnvelope>(&line).ok())
        .filter(|envelope| {
            envelope.validate()
                && envelope
                    .interval_start
                    .with_timezone(&New_York)
                    .date_naive()
                    == session_date
        })
        .collect::<Vec<_>>();
    envelopes.sort_by(|left, right| {
        left.interval_start
            .cmp(&right.interval_start)
            .then_with(|| left.observation.symbol.cmp(&right.observation.symbol))
    });
    envelopes
}

fn complete_settlement_window<'a>(
    forecast: &ForecastContract,
    bars: &'a BTreeMap<(i64, String), DatabentoRealtimeBarEnvelope>,
) -> Vec<&'a DatabentoRealtimeBarEnvelope> {
    complete_settlement_window_for(
        &forecast.symbol,
        forecast.label_start,
        forecast.label_end,
        forecast.horizon_minutes,
        bars,
    )
}

fn complete_settlement_window_for<'a>(
    raw_symbol: &str,
    label_start: DateTime<Utc>,
    label_end: DateTime<Utc>,
    horizon_minutes: usize,
    bars: &'a BTreeMap<(i64, String), DatabentoRealtimeBarEnvelope>,
) -> Vec<&'a DatabentoRealtimeBarEnvelope> {
    let symbol = raw_symbol.trim_start_matches("US.").to_ascii_uppercase();
    let mut window = bars
        .values()
        .filter(|envelope| {
            envelope.bar.symbol.eq_ignore_ascii_case(&symbol)
                && envelope.bar_start >= label_start
                && envelope.bar_start < label_end
        })
        .collect::<Vec<_>>();
    window.sort_by_key(|envelope| envelope.bar_start);
    let complete = window.len() == horizon_minutes
        && window
            .first()
            .is_some_and(|envelope| envelope.bar_start == label_start)
        && window
            .last()
            .is_some_and(|envelope| envelope.bar_end == label_end)
        && window
            .windows(2)
            .all(|pair| pair[0].bar_end == pair[1].bar_start)
        && window
            .iter()
            .all(|envelope| envelope_rejection(envelope, 10_000).is_none());
    if complete { window } else { Vec::new() }
}

fn realized_window_statistics(
    reference_price: f64,
    window: &[&DatabentoRealtimeBarEnvelope],
) -> Result<(f64, f64, i8, f64, f64, f64)> {
    if !reference_price.is_finite() || reference_price <= 0.0 || window.is_empty() {
        bail!("INVALID_SETTLEMENT_REFERENCE_OR_WINDOW");
    }
    let exit = window
        .last()
        .context("complete settlement window")?
        .bar
        .close;
    let mut previous_close = reference_price;
    let mut returns = Vec::with_capacity(window.len());
    for envelope in window {
        let close = envelope.bar.close;
        if !close.is_finite() || close <= 0.0 || previous_close <= 0.0 {
            bail!("INVALID_SETTLEMENT_CLOSE");
        }
        returns.push((close / previous_close).ln());
        previous_close = close;
    }
    let mean = returns.iter().sum::<f64>() / returns.len() as f64;
    let realized_volatility = returns
        .iter()
        .map(|value| (value - mean).powi(2))
        .sum::<f64>()
        .sqrt();
    let log_return = (exit / reference_price).ln();
    let direction = if log_return > 0.0 {
        1
    } else if log_return < 0.0 {
        -1
    } else {
        0
    };
    let mfe = window
        .iter()
        .map(|envelope| envelope.bar.high / reference_price - 1.0)
        .fold(f64::NEG_INFINITY, f64::max);
    let mae = window
        .iter()
        .map(|envelope| envelope.bar.low / reference_price - 1.0)
        .fold(f64::INFINITY, f64::min);
    Ok((exit, log_return, direction, mfe, mae, realized_volatility))
}

fn settlement_for_window(
    forecast: &ForecastContract,
    window: &[&DatabentoRealtimeBarEnvelope],
    settlement_available_at: DateTime<Utc>,
) -> Result<ForecastSettlement> {
    let complete = !window.is_empty();
    let (reference, log_return, direction, mfe, mae, volatility, barrier) = if complete {
        let (exit, value, direction, mfe, mae, realized_volatility) =
            realized_window_statistics(forecast.reference_price, window)?;
        (
            exit,
            value,
            direction,
            mfe,
            mae,
            realized_volatility,
            "UNAVAILABLE_ORDERED_BARRIER_THRESHOLDS",
        )
    } else {
        (
            forecast.reference_price,
            0.0,
            0,
            0.0,
            0.0,
            0.0,
            "INVALID_DATA_GAP",
        )
    };
    let source_bar_ids = window
        .iter()
        .map(|envelope| envelope_sha256(envelope))
        .collect::<Result<Vec<_>>>()?;
    let data_status = if complete {
        "POINT_IN_TIME_COMPLETE"
    } else {
        "INVALID_DATA_GAP"
    };
    let mut settlement = ForecastSettlement {
        settlement_id: uuid::Uuid::new_v4().to_string(),
        prediction_id: forecast.prediction_id.clone(),
        settled_at: Utc::now(),
        realized_reference_price: reference,
        realized_log_return: log_return,
        realized_direction: direction,
        realized_mfe: mfe,
        realized_mae: mae,
        realized_volatility: volatility,
        barrier_outcome: barrier.into(),
        data_status: data_status.into(),
        source_bar_ids,
        settlement_available_timestamp: settlement_available_at,
        settlement_hash: String::new(),
        executable_entry: None,
        executable_exit: None,
        spread_cost: None,
        slippage: None,
        fees: None,
        hypothetical_pnl: None,
        evidence_kind: "settled_forward_prediction".into(),
    };
    settlement.settlement_hash = settlement_content_hash(&settlement)?;
    Ok(settlement)
}

impl Runtime {
    fn initialize(config: AppConfig, root: PathBuf, session_date: chrono::NaiveDate) -> Self {
        let configured = configured_model_symbols(&config);
        let mut failures = BTreeMap::new();
        if configured.is_empty() {
            failures.insert(
                "GLOBAL".into(),
                "LIVE_FORECAST_SYMBOLS_EMPTY_OR_INVALID".into(),
            );
        }

        let historical_path = root.join("normalized/market_bars.csv");
        let historical = match MarketBarCsvImporter.import(&historical_path) {
            Ok(report) => Some(report.records),
            Err(error) => {
                for symbol in &configured {
                    failures.insert(
                        symbol.clone(),
                        format!("HISTORICAL_BARS_UNAVAILABLE:{error:#}"),
                    );
                }
                None
            }
        };
        let universe_path = root.join("models/universe/registry.json");
        let universe = match load_frozen_universe(&universe_path, &configured) {
            Ok(universe) => universe,
            Err(error) => LoadedFrozenUniverse::unavailable_for_symbols(
                &configured,
                &format!("UNIVERSE_REGISTRY_UNAVAILABLE:{error:#}"),
            ),
        };
        let (artifacts, artifact_failures) = universe.into_parts();
        failures.extend(artifact_failures);

        let capability = match capability::inspect(&config.data) {
            Ok(report) => Some(report),
            Err(error) => {
                for symbol in &configured {
                    failures
                        .entry(symbol.clone())
                        .or_insert_with(|| format!("DATA_CAPABILITY_UNAVAILABLE:{error:#}"));
                }
                None
            }
        };
        let ledger_path = root.join("state/prediction_ledger.sqlite3");
        let ledger = match PredictionLedger::open(&ledger_path) {
            Ok(ledger) => Some(ledger),
            Err(error) => {
                for symbol in &configured {
                    failures
                        .entry(symbol.clone())
                        .or_insert_with(|| format!("PREDICTION_LEDGER_UNAVAILABLE:{error:#}"));
                }
                None
            }
        };

        let mut targets = BTreeMap::new();
        if let Some(historical) = historical.as_deref()
            && capability.is_some()
            && ledger.is_some()
        {
            for (target, artifact) in artifacts {
                if failures.contains_key(&target) {
                    continue;
                }
                if let Err(error) = predictor::validate_live_feature_contract(
                    &artifact,
                    &config.live.context_observation_policy,
                    &config.live.cross_asset_feature_schema,
                ) {
                    failures.insert(
                        target,
                        format!("LIVE_FEATURE_SCHEMA_ARTIFACT_MISMATCH:{error:#}"),
                    );
                    continue;
                }
                if !config
                    .research
                    .targets
                    .iter()
                    .any(|configured| configured.model_symbol.eq_ignore_ascii_case(&target))
                {
                    failures.insert(target, "RESEARCH_TARGET_MAPPING_MISSING".into());
                    continue;
                }
                let mut research = config.research.clone();
                research.target = target.clone();
                match IncrementalFeatureEngine::new_with_feature_contract(
                    historical,
                    &target,
                    &research,
                    config.live.required_context_symbols.clone(),
                    config.live.max_context_skew_ms,
                    config.live.context_observation_policy.clone(),
                    config.live.cross_asset_feature_schema.clone(),
                ) {
                    Ok(feature_engine) => {
                        targets.insert(
                            target,
                            TargetRuntime {
                                research,
                                artifact,
                                inference_cache: FrozenInferenceCache::default(),
                                feature_engine,
                                target_events: BTreeMap::new(),
                            },
                        );
                    }
                    Err(error) => {
                        failures.insert(
                            target,
                            format!("FEATURE_ENGINE_INITIALIZATION_FAILED:{error:#}"),
                        );
                    }
                }
            }
        }

        let runtime = Self {
            config,
            root,
            capability,
            ledger,
            expected_targets: configured,
            targets,
            pending_batches: BTreeMap::new(),
            failures,
            settlement_bars: BTreeMap::new(),
            context_observations: BTreeMap::new(),
        };
        let mut runtime = runtime;
        runtime.restore_current_session(session_date);
        runtime.persist_global_status();
        runtime.persist_initial_target_statuses();
        runtime
    }

    fn restore_current_session(&mut self, session_date: chrono::NaiveDate) {
        let path = self.root.join("live/databento_stock_bars.jsonl");
        let envelopes =
            read_current_session_envelopes(&path, session_date, self.config.live.stale_after_ms);
        for envelope in envelopes {
            self.remember_settlement_bar(&envelope);
            for (target, runtime) in &mut self.targets {
                if envelope.bar.symbol.eq_ignore_ascii_case(target) {
                    runtime
                        .target_events
                        .insert(envelope.bar_start.timestamp_millis(), envelope.clone());
                }
                // Restore feature state only. A process restart must never
                // retroactively issue a prediction for a pre-start cutoff.
                if let Err(error) = runtime.feature_engine.ingest(envelope.bar.clone()) {
                    self.failures.insert(
                        target.clone(),
                        format!("CURRENT_SESSION_RESTORE_FAILED:{error:#}"),
                    );
                }
            }
        }
        let context_path = self.root.join("live/databento_context_observations.jsonl");
        for envelope in read_current_session_context_observations(&context_path, session_date) {
            let key = (
                envelope.interval_start.timestamp_millis(),
                envelope.observation.symbol.to_ascii_uppercase(),
            );
            self.context_observations.insert(key, envelope.clone());
            for (target, runtime) in &mut self.targets {
                if let Err(error) = runtime
                    .feature_engine
                    .ingest_context_observation(envelope.observation.clone())
                {
                    self.failures.insert(
                        target.clone(),
                        format!("CURRENT_SESSION_CONTEXT_RESTORE_FAILED:{error:#}"),
                    );
                }
            }
        }
        for runtime in self.targets.values_mut() {
            while runtime.target_events.len() > 16 {
                let Some(oldest) = runtime.target_events.keys().next().copied() else {
                    break;
                };
                runtime.target_events.remove(&oldest);
            }
        }
    }

    fn remember_settlement_bar(&mut self, envelope: &DatabentoRealtimeBarEnvelope) {
        let key = (
            envelope.bar_start.timestamp_millis(),
            envelope.bar.symbol.to_ascii_uppercase(),
        );
        self.settlement_bars.insert(key, envelope.clone());
        while self.settlement_bars.len() > 8_000 {
            let Some(oldest) = self.settlement_bars.keys().next().cloned() else {
                break;
            };
            self.settlement_bars.remove(&oldest);
        }
    }

    fn settle_ready_for_trigger(&self, trigger: &DatabentoRealtimeBarEnvelope) {
        let Some(ledger) = self.ledger.as_ref() else {
            return;
        };
        let pending = match ledger.pending_published_forecasts() {
            Ok(pending) => pending,
            Err(error) => {
                tracing::error!(%error, "read pending published Databento forecasts");
                return;
            }
        };
        for forecast in pending {
            if forecast.evidence_kind != "live_shadow_prediction"
                || forecast.data_source != DATABENTO_FORECAST_DATA_SOURCE
                || !forecast
                    .symbol
                    .trim_start_matches("US.")
                    .eq_ignore_ascii_case(&trigger.bar.symbol)
                || forecast.label_end > trigger.bar_end
            {
                continue;
            }
            let window = complete_settlement_window(&forecast, &self.settlement_bars);
            let settlement =
                match settlement_for_window(&forecast, &window, trigger.provider_available_at) {
                    Ok(settlement) => settlement,
                    Err(error) => {
                        tracing::error!(
                            %error,
                            prediction_id = %forecast.prediction_id,
                            "build Databento settlement"
                        );
                        continue;
                    }
                };
            if let Err(error) = ledger.append_settlement(&settlement) {
                tracing::error!(
                    %error,
                    prediction_id = %forecast.prediction_id,
                    "append Databento settlement"
                );
            }
        }
    }

    fn persist_global_status(&self) {
        // The universe summary has its own file. SPY's target status uses the
        // legacy unsuffixed target path, so sharing that path would let a
        // static universe-load message overwrite the live SPY producer state.
        let path = self
            .root
            .join("live/databento_inference_universe_status.json");
        let symbol_failures = self
            .failures
            .iter()
            .map(|(symbol, reason)| {
                (
                    symbol.clone(),
                    sanitized_runtime_failure(reason).to_string(),
                )
            })
            .collect::<BTreeMap<_, _>>();
        let result = write_json_atomic(
            &path,
            &serde_json::json!({
                "schema_version":DATABENTO_INFERENCE_STATUS_SCHEMA_VERSION,
                "as_of":Utc::now(),
                "provider":"databento",
                "dataset":"EQUS.MINI",
                "data_source":DATABENTO_FORECAST_DATA_SOURCE,
                "status":if self.targets.is_empty() {
                    "NO_FORECAST"
                } else if self.failures.is_empty() {
                    "UNIVERSE_READY"
                } else {
                    "PARTIAL_UNIVERSE_READY"
                },
                "stage":"FROZEN_UNIVERSE_GATE",
                "configured_symbols":configured_model_symbols(&self.config),
                "ready_symbols":self.targets.keys().collect::<Vec<_>>(),
                "symbol_failures":symbol_failures,
                "market_data_capture_continues":true,
                "intraday_fit_allowed":false,
                "execution_enabled":false
            }),
        );
        if let Err(error) = result {
            tracing::error!(%error, path = %path.display(), "write Databento inference status");
        }
    }

    fn persist_initial_target_statuses(&self) {
        for target in configured_model_symbols(&self.config) {
            if let Some(reason) = self.failures.get(&target) {
                persist_target_status(
                    &self.root,
                    TargetStatusUpdate {
                        target: &target,
                        status: TargetInferenceState::CompatibilityRejected,
                        stage: TargetInferenceStage::FrozenUniverseGate,
                        reason_code: Some(sanitized_runtime_failure(reason)),
                        cutoff: None,
                        latest_input_available_at: None,
                        compute_ms: None,
                        end_to_end_ms: None,
                        budget_ms: self.config.live.prediction_sla_ms,
                        context: None,
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
            } else if self.targets.contains_key(&target) {
                persist_target_status(
                    &self.root,
                    TargetStatusUpdate {
                        target: &target,
                        status: TargetInferenceState::WaitingForTarget,
                        stage: TargetInferenceStage::ProviderInput,
                        reason_code: Some("TARGET_BAR_PENDING"),
                        cutoff: None,
                        latest_input_available_at: None,
                        compute_ms: None,
                        end_to_end_ms: None,
                        budget_ms: self.config.live.prediction_sla_ms,
                        context: None,
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
            }
        }
    }

    fn handle_event(&mut self, event: DatabentoInferenceEvent) {
        match event {
            DatabentoInferenceEvent::TradeBar { envelope } => self.handle(envelope),
            DatabentoInferenceEvent::ContextObservation { envelope } => {
                if !envelope.validate()
                    || self.config.live.forecast_symbols.iter().any(|target| {
                        target
                            .trim_start_matches("US.")
                            .eq_ignore_ascii_case(&envelope.observation.symbol)
                    })
                {
                    tracing::error!(
                        symbol = %envelope.observation.symbol,
                        "rejected invalid or target-scoped causal absence evidence"
                    );
                    return;
                }
                let key = (
                    envelope.interval_start.timestamp_millis(),
                    envelope.observation.symbol.to_ascii_uppercase(),
                );
                self.context_observations.insert(key, envelope.clone());
                for runtime in self.targets.values_mut() {
                    if let Err(error) = runtime
                        .feature_engine
                        .ingest_context_observation(envelope.observation.clone())
                    {
                        tracing::error!(
                            reason = %error,
                            symbol = %envelope.observation.symbol,
                            "feature engine rejected causal absence evidence"
                        );
                    }
                }
                // The target bar normally arrived before the provider's
                // end-of-interval marker. Re-submit the newest target envelope
                // so a previously blocked cutoff can be evaluated once the
                // causal absence evidence has been ingested.
                let trigger = self
                    .targets
                    .values()
                    .flat_map(|runtime| runtime.target_events.values())
                    .filter(|target| target.bar_start == envelope.interval_start)
                    .max_by_key(|target| target.provider_available_at)
                    .cloned();
                if let Some(trigger) = trigger {
                    self.handle(trigger);
                }
            }
        }
    }

    fn enqueue_ready_targets(
        &mut self,
        ready_targets: Vec<(String, DateTime<Utc>, PendingTargetInference)>,
        capability: &DataCapabilityReport,
        ledger: &PredictionLedger,
        os: &crate::config::QuantOsConfig,
        live: &LiveConfig,
    ) {
        for (target, cutoff, pending) in ready_targets {
            let cutoff_key = cutoff.timestamp_millis();
            let stale_keys = self
                .pending_batches
                .keys()
                .copied()
                .filter(|key| *key < cutoff_key)
                .collect::<Vec<_>>();
            for stale_key in stale_keys {
                if let Some(stale) = self.pending_batches.remove(&stale_key) {
                    self.reject_pending_batch(
                        stale,
                        "BATCH_ABORTED_INCOMPLETE_TARGET_SET_AT_NEXT_CUTOFF",
                    );
                }
            }
            let batch =
                self.pending_batches
                    .entry(cutoff_key)
                    .or_insert_with(|| PendingInferenceBatch {
                        cutoff,
                        targets: BTreeMap::new(),
                    });
            if batch.cutoff != cutoff || batch.targets.insert(target.clone(), pending).is_some() {
                let invalid = self
                    .pending_batches
                    .remove(&cutoff_key)
                    .expect("pending batch exists");
                self.reject_pending_batch(invalid, "BATCH_ABORTED_DUPLICATE_OR_MISMATCHED_TARGET");
                continue;
            }
        }

        let complete_keys = self
            .pending_batches
            .iter()
            .filter_map(|(key, batch)| {
                (batch.targets.keys().cloned().collect::<BTreeSet<_>>() == self.expected_targets)
                    .then_some(*key)
            })
            .collect::<Vec<_>>();
        for key in complete_keys {
            if let Some(batch) = self.pending_batches.remove(&key) {
                self.infer_complete_batch(batch, capability, ledger, os, live);
            }
        }
    }

    fn reject_pending_batch(&self, batch: PendingInferenceBatch, reason_code: &'static str) {
        for target in &self.expected_targets {
            let pending = batch.targets.get(target);
            let source_available_at = pending.map(|row| row.source_input.latest_input_available_at);
            let end_to_end_ms = source_available_at.map(|available_at| {
                Utc::now()
                    .signed_duration_since(available_at)
                    .num_milliseconds()
            });
            persist_target_status(
                &self.root,
                TargetStatusUpdate {
                    target,
                    status: TargetInferenceState::PublishRejected,
                    stage: TargetInferenceStage::FrozenInference,
                    reason_code: Some(reason_code),
                    cutoff: Some(batch.cutoff),
                    latest_input_available_at: source_available_at,
                    compute_ms: pending.map(|row| row.feature_compute_ms),
                    end_to_end_ms,
                    budget_ms: self.config.live.prediction_sla_ms,
                    context: pending.map(|row| &row.context),
                    forecast_committed: false,
                    receipt_committed: false,
                    ledger_persisted: false,
                },
            );
        }
    }

    fn infer_complete_batch(
        &mut self,
        mut batch: PendingInferenceBatch,
        capability: &DataCapabilityReport,
        ledger: &PredictionLedger,
        os: &crate::config::QuantOsConfig,
        live: &LiveConfig,
    ) {
        if self.expected_targets.len() != 9
            || self.targets.keys().cloned().collect::<BTreeSet<_>>() != self.expected_targets
        {
            self.reject_pending_batch(batch, "BATCH_ABORTED_EXACT_NINE_TARGET_UNIVERSE_REQUIRED");
            return;
        }
        if batch.targets.keys().cloned().collect::<BTreeSet<_>>() != self.expected_targets {
            self.reject_pending_batch(batch, "BATCH_ABORTED_TARGET_INPUT_MISSING");
            return;
        }
        if self.expected_targets.iter().any(|target| {
            !state_snapshot_matches_batch_cutoff(
                self.targets
                    .get(target)
                    .and_then(|runtime| runtime.feature_engine.states().last())
                    .map(|state| state.timestamp),
                batch.cutoff,
            )
        }) {
            self.reject_pending_batch(batch, "BATCH_ABORTED_STATE_SNAPSHOT_CUTOFF_MISMATCH");
            return;
        }
        let inference_as_of = Utc::now();
        let mut work: Vec<TargetInferenceWork> = Vec::with_capacity(self.expected_targets.len());
        for target in &self.expected_targets {
            let runtime = self
                .targets
                .remove(target)
                .expect("exact target runtime set prevalidated");
            let pending = batch
                .targets
                .remove(target)
                .expect("exact pending target set prevalidated");
            work.push(TargetInferenceWork {
                target: target.clone(),
                runtime,
                pending,
                result: None,
            });
        }

        let worker_count = bounded_worker_count(
            work.len(),
            std::thread::available_parallelism()
                .map(std::num::NonZeroUsize::get)
                .unwrap_or(1),
        );
        let partition_sizes = bounded_worker_partition_sizes(work.len(), worker_count);
        std::thread::scope(|scope| {
            let mut remaining_work = work.as_mut_slice();
            for partition_size in partition_sizes {
                let (chunk, rest) = remaining_work.split_at_mut(partition_size);
                remaining_work = rest;
                scope.spawn(move || {
                    for item in chunk {
                        let started = Instant::now();
                        let result = (|| -> Result<CompletedTargetInference, String> {
                            let mut bundle = predictor::forecast_with_frozen_artifact_cached(
                                item.runtime.feature_engine.states(),
                                &item.runtime.research,
                                os,
                                capability,
                                inference_as_of,
                                &item.runtime.artifact,
                                &mut item.runtime.inference_cache,
                            )
                            .map_err(|_| "FROZEN_MODEL_INFERENCE_REJECTED".to_string())?;
                            let compute_ms = started.elapsed().as_millis();
                            let elapsed = Utc::now()
                                .signed_duration_since(
                                    item.pending.source_input.latest_input_available_at,
                                )
                                .num_milliseconds();
                            if elapsed < 0 || elapsed > live.prediction_sla_ms {
                                return Err("PREDICTION_SLA_EXCEEDED".into());
                            }
                            predictor::enforce_realtime_forward_shadow(
                                &mut bundle,
                                item.pending.source_input.latest_input_available_at,
                                live.execution_latency_ms,
                                false,
                                &RealtimeSourceMetadata {
                                    source_version: "EQUS.MINI",
                                    provider: "DATABENTO",
                                    market_coverage:
                                        "LICENSED_DATABENTO_EQUS_MINI_US_EQUITIES",
                                    availability_semantics:
                                        "DATABENTO_FINALIZED_OHLCV_1M_LOCAL_RECEIPT_TIMESTAMP",
                                },
                            );
                            validate_atomic_target_bundle(
                                &bundle,
                                &item.target,
                                batch.cutoff,
                            )
                            .map_err(str::to_string)?;
                            Ok(CompletedTargetInference {
                                target: item.target.clone(),
                                pending: PendingTargetInference {
                                    context: item.pending.context.clone(),
                                    source_input: item.pending.source_input.clone(),
                                    feature_compute_ms: item.pending.feature_compute_ms,
                                },
                                bundle,
                                compute_ms,
                            })
                        })();
                        item.result = Some(result);
                    }
                });
            }
        });

        let mut completed = BTreeMap::new();
        let mut failures = BTreeMap::new();
        for mut item in work {
            let result = item
                .result
                .take()
                .expect("every bounded inference job writes a result");
            self.targets.insert(item.target.clone(), item.runtime);
            match result {
                Ok(result) => {
                    completed.insert(result.target.clone(), result);
                }
                Err(reason) => {
                    failures.insert(item.target, (reason, item.pending));
                }
            }
        }
        if !failures.is_empty() {
            for target in &self.expected_targets {
                let completed_row = completed.get(target);
                let failed_row = failures.get(target);
                let source_available_at = completed_row
                    .map(|row| row.pending.source_input.latest_input_available_at)
                    .or_else(|| {
                        failed_row
                            .map(|(_, pending)| pending.source_input.latest_input_available_at)
                    });
                let reason = failures
                    .get(target)
                    .map(|(reason, _)| reason.as_str())
                    .unwrap_or("BATCH_ABORTED_PEER_TARGET_FAILED");
                persist_target_status(
                    &self.root,
                    TargetStatusUpdate {
                        target,
                        status: if reason == "PREDICTION_SLA_EXCEEDED" {
                            TargetInferenceState::SlaRejected
                        } else {
                            TargetInferenceState::PublishRejected
                        },
                        stage: if reason == "PREDICTION_SLA_EXCEEDED" {
                            TargetInferenceStage::SlaGate
                        } else {
                            TargetInferenceStage::FrozenInference
                        },
                        reason_code: Some(reason),
                        cutoff: Some(batch.cutoff),
                        latest_input_available_at: source_available_at,
                        compute_ms: completed_row.map(|row| row.compute_ms),
                        end_to_end_ms: source_available_at.map(|available_at| {
                            Utc::now()
                                .signed_duration_since(available_at)
                                .num_milliseconds()
                        }),
                        budget_ms: live.prediction_sla_ms,
                        context: completed_row
                            .map(|row| &row.pending.context)
                            .or_else(|| failed_row.map(|(_, pending)| &pending.context)),
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
            }
            return;
        }
        self.publish_atomic_batch(batch.cutoff, completed, ledger, live);
    }

    fn publish_atomic_batch(
        &self,
        cutoff: DateTime<Utc>,
        mut completed: BTreeMap<String, CompletedTargetInference>,
        ledger: &PredictionLedger,
        live: &LiveConfig,
    ) {
        let mut submitted = completed
            .values()
            .flat_map(|row| row.bundle.prediction_layer.iter().cloned())
            .collect::<Vec<_>>();
        submitted.sort_by(|left, right| {
            left.symbol
                .cmp(&right.symbol)
                .then_with(|| left.horizon_minutes.cmp(&right.horizon_minutes))
        });
        let canonical = match ledger.append_prediction_batch(cutoff, &submitted) {
            Ok(canonical) => canonical,
            Err(error) => {
                tracing::error!(reason = %error, "atomic Databento prediction batch rejected");
                self.reject_completed_batch(
                    cutoff,
                    &completed,
                    "PREDICTION_LEDGER_BATCH_PERSIST_FAILED",
                    TargetInferenceStage::PredictionLedger,
                );
                return;
            }
        };
        let mut canonical_by_id = canonical
            .into_iter()
            .map(|contract| (contract.prediction_id.clone(), contract))
            .collect::<BTreeMap<_, _>>();
        let mut canonical_mismatch = false;
        for row in completed.values_mut() {
            for contract in &mut row.bundle.prediction_layer {
                let Some(canonical) = canonical_by_id.remove(&contract.prediction_id) else {
                    canonical_mismatch = true;
                    break;
                };
                *contract = canonical;
            }
            if let Some(generated_at) = row
                .bundle
                .prediction_layer
                .iter()
                .map(|contract| contract.created_at)
                .min()
            {
                row.bundle.generated_at = generated_at;
            }
        }
        if canonical_mismatch || !canonical_by_id.is_empty() {
            self.reject_completed_batch(
                cutoff,
                &completed,
                "PREDICTION_LEDGER_BATCH_CANONICAL_SET_MISMATCH",
                TargetInferenceStage::PredictionLedger,
            );
            return;
        }

        let prediction_ids = completed
            .values()
            .flat_map(|row| {
                row.bundle
                    .prediction_layer
                    .iter()
                    .map(|contract| contract.prediction_id.clone())
            })
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>();
        let batch_symbols = self.expected_targets.iter().cloned().collect::<Vec<_>>();
        let batch_identity = sha256_bytes(
            &serde_json::to_vec(&serde_json::json!({
                "cutoff": cutoff,
                "symbols": batch_symbols.clone(),
                "prediction_ids": prediction_ids.clone(),
                "execution_enabled": false
            }))
            .expect("batch identity is serializable"),
        );
        let batch_id = format!("databento-batch:{batch_identity}");
        let prepared_at = Utc::now();
        let mut manifest_members = Vec::with_capacity(completed.len());
        let mut publication_commits = Vec::with_capacity(prediction_ids.len());
        let mut compatibility = BTreeMap::<String, (ForecastBundle, InferenceReceipt)>::new();

        for (target, row) in &completed {
            let forecast_bytes = match serde_json::to_vec_pretty(&row.bundle) {
                Ok(bytes) => bytes,
                Err(error) => {
                    tracing::error!(target, reason = %error, "serialize Databento batch member");
                    self.reject_completed_batch(
                        cutoff,
                        &completed,
                        "FORECAST_BATCH_MEMBER_SERIALIZATION_FAILED",
                        TargetInferenceStage::PublishStaging,
                    );
                    return;
                }
            };
            let forecast_sha256 = sha256_bytes(&forecast_bytes);
            let output = forecast_path(&self.root, target);
            let member_prediction_ids = row
                .bundle
                .prediction_layer
                .iter()
                .map(|contract| contract.prediction_id.clone())
                .collect::<Vec<_>>();
            let mut receipt = InferenceReceipt {
                schema_version: DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION.into(),
                generated_at: row.bundle.generated_at,
                published_at: prepared_at,
                end_to_end_ms: prepared_at
                    .signed_duration_since(row.pending.source_input.latest_input_available_at)
                    .num_milliseconds(),
                budget_ms: live.prediction_sla_ms,
                provider: "databento".into(),
                dataset: "EQUS.MINI".into(),
                data_source: DATABENTO_FORECAST_DATA_SOURCE.into(),
                model_symbol: target.clone(),
                model_hash: self
                    .targets
                    .get(target)
                    .map(|runtime| runtime.artifact.model_hash.clone())
                    .unwrap_or_default(),
                forecast_path: output.display().to_string(),
                forecast_sha256,
                prediction_ids: member_prediction_ids.clone(),
                latest_input_available_at: row.pending.source_input.latest_input_available_at,
                required_context_symbols: live.required_context_symbols.clone(),
                max_context_skew_ms: live.max_context_skew_ms,
                source_envelope_count: row.pending.source_input.source_envelopes.len(),
                source_envelopes_sha256: row.pending.source_input.source_envelopes_sha256.clone(),
                source_envelopes: row.pending.source_input.source_envelopes.clone(),
                cutoff_source_envelopes: row.pending.source_input.cutoff_source_envelopes.clone(),
                cutoff_context_observations: row
                    .pending
                    .source_input
                    .cutoff_context_observations
                    .clone(),
                batch_id: Some(batch_id.clone()),
                batch_cutoff: Some(cutoff),
                batch_committed_at: None,
                ledger_persisted: true,
                execution_enabled: false,
            };
            let (publication_path, publication_sha256) =
                match write_immutable_publication(&self.root, &forecast_bytes, &receipt) {
                    Ok(published) => published,
                    Err(error) => {
                        tracing::error!(target, reason = %error, "write immutable batch member");
                        self.reject_completed_batch(
                            cutoff,
                            &completed,
                            "FORECAST_BATCH_MEMBER_STAGING_FAILED",
                            TargetInferenceStage::PublishStaging,
                        );
                        return;
                    }
                };
            let relative_publication_path = publication_path
                .strip_prefix(&self.root)
                .map(|path| path.to_string_lossy().replace('\\', "/"))
                .unwrap_or_else(|_| publication_path.to_string_lossy().replace('\\', "/"));
            manifest_members.push(ForecastBatchMember {
                model_symbol: target.clone(),
                forecast_sha256: receipt.forecast_sha256.clone(),
                publication_sha256: publication_sha256.clone(),
                publication_path: relative_publication_path,
                prediction_ids: member_prediction_ids.clone(),
                latest_input_available_at: receipt.latest_input_available_at,
            });
            for prediction_id in member_prediction_ids {
                publication_commits.push(PredictionPublicationCommit {
                    publication_id: format!("{batch_id}:{prediction_id}"),
                    prediction_id,
                    published_at: prepared_at,
                    provider: "DATABENTO".into(),
                    forecast_sha256: receipt.forecast_sha256.clone(),
                    publication_sha256: publication_sha256.clone(),
                    evidence_kind: "live_forecast_publication_commit".into(),
                });
            }
            receipt.batch_committed_at = None;
            compatibility.insert(target.clone(), (row.bundle.clone(), receipt));
        }
        manifest_members.sort_by(|left, right| left.model_symbol.cmp(&right.model_symbol));
        publication_commits.sort_by(|left, right| left.publication_id.cmp(&right.publication_id));
        let manifest = ImmutableForecastBatchManifest {
            schema_version: DATABENTO_BATCH_MANIFEST_SCHEMA_VERSION.into(),
            batch_id: batch_id.clone(),
            prepared_at,
            cutoff,
            symbols: batch_symbols.clone(),
            members: manifest_members,
            execution_enabled: false,
        };
        let (manifest_path, manifest_sha256) =
            match write_immutable_batch_manifest(&self.root, &manifest) {
                Ok(written) => written,
                Err(error) => {
                    tracing::error!(reason = %error, "write immutable Databento batch manifest");
                    self.reject_completed_batch(
                        cutoff,
                        &completed,
                        "FORECAST_BATCH_MANIFEST_STAGING_FAILED",
                        TargetInferenceStage::PublishStaging,
                    );
                    return;
                }
            };
        let mut publication_ids = publication_commits
            .iter()
            .map(|publication| publication.publication_id.clone())
            .collect::<Vec<_>>();
        publication_ids.sort();
        let request = PredictionPublicationBatchRequest {
            schema_version: PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION.into(),
            batch_id: batch_id.clone(),
            cutoff,
            symbols: batch_symbols,
            manifest_sha256,
            execution_disabled: true,
            prediction_ids,
            publication_ids,
            target_slas: completed
                .iter()
                .map(|(target, row)| PredictionPublicationBatchTargetSla {
                    symbol: target.clone(),
                    source_available_at: row.pending.source_input.latest_input_available_at,
                    budget_ms: live.prediction_sla_ms,
                })
                .collect(),
        };
        let marker = match ledger.append_publication_batch(&publication_commits, &request) {
            Ok(marker) => marker,
            Err(error) => {
                tracing::error!(
                    reason = %error,
                    manifest = %manifest_path.display(),
                    "atomic Databento batch commit rejected"
                );
                let sla_failure = error.to_string().contains("BATCH_SLA_EXCEEDED");
                self.reject_completed_batch(
                    cutoff,
                    &completed,
                    if sla_failure {
                        "PREDICTION_SLA_EXCEEDED_DURING_BATCH_COMMIT"
                    } else {
                        "FORECAST_BATCH_LEDGER_COMMIT_FAILED"
                    },
                    if sla_failure {
                        TargetInferenceStage::SlaGate
                    } else {
                        TargetInferenceStage::PredictionLedger
                    },
                );
                return;
            }
        };

        for (target, (bundle, mut receipt)) in compatibility {
            receipt.batch_committed_at = Some(marker.committed_at);
            receipt.end_to_end_ms = marker
                .committed_at
                .signed_duration_since(receipt.latest_input_available_at)
                .num_milliseconds();
            let forecast_committed =
                write_json_atomic(&forecast_path(&self.root, &target), &bundle).is_ok();
            let receipt_committed =
                write_json_atomic(&receipt_path(&self.root, &target), &receipt).is_ok();
            persist_target_status(
                &self.root,
                TargetStatusUpdate {
                    target: &target,
                    status: TargetInferenceState::Published,
                    stage: TargetInferenceStage::Published,
                    reason_code: None,
                    cutoff: Some(cutoff),
                    latest_input_available_at: Some(receipt.latest_input_available_at),
                    compute_ms: completed.get(&target).map(|row| row.compute_ms),
                    end_to_end_ms: Some(receipt.end_to_end_ms),
                    budget_ms: live.prediction_sla_ms,
                    context: completed.get(&target).map(|row| &row.pending.context),
                    forecast_committed,
                    receipt_committed,
                    ledger_persisted: true,
                },
            );
        }
        tracing::info!(
            batch_id,
            manifest = %manifest_path.display(),
            committed_at = %marker.committed_at,
            "committed atomic nine-symbol Databento forecast batch"
        );
    }

    fn reject_completed_batch(
        &self,
        cutoff: DateTime<Utc>,
        completed: &BTreeMap<String, CompletedTargetInference>,
        reason_code: &'static str,
        stage: TargetInferenceStage,
    ) {
        for (target, row) in completed {
            let end_to_end_ms = Utc::now()
                .signed_duration_since(row.pending.source_input.latest_input_available_at)
                .num_milliseconds();
            persist_target_status(
                &self.root,
                TargetStatusUpdate {
                    target,
                    status: if reason_code.contains("SLA_EXCEEDED") {
                        TargetInferenceState::SlaRejected
                    } else {
                        TargetInferenceState::PublishRejected
                    },
                    stage,
                    reason_code: Some(reason_code),
                    cutoff: Some(cutoff),
                    latest_input_available_at: Some(
                        row.pending.source_input.latest_input_available_at,
                    ),
                    compute_ms: Some(row.compute_ms),
                    end_to_end_ms: Some(end_to_end_ms),
                    budget_ms: self.config.live.prediction_sla_ms,
                    context: Some(&row.pending.context),
                    forecast_committed: false,
                    receipt_committed: false,
                    ledger_persisted: stage == TargetInferenceStage::PublishStaging,
                },
            );
        }
    }

    fn handle(&mut self, envelope: DatabentoRealtimeBarEnvelope) {
        if let Some(reason) = envelope_rejection(&envelope, self.config.live.stale_after_ms) {
            tracing::error!(
                reason,
                symbol = %envelope.bar.symbol,
                "Databento envelope rejected before inference"
            );
            if let Ok(symbol) = canonical_live_symbol(&envelope.bar.symbol)
                && self.targets.contains_key(&symbol)
            {
                persist_target_status(
                    &self.root,
                    TargetStatusUpdate {
                        target: &symbol,
                        status: TargetInferenceState::WaitingForTarget,
                        stage: TargetInferenceStage::SourceEnvelopeGate,
                        reason_code: Some("TARGET_SOURCE_ENVELOPE_REJECTED"),
                        cutoff: Some(envelope.bar_start),
                        latest_input_available_at: Some(envelope.provider_available_at),
                        compute_ms: None,
                        end_to_end_ms: None,
                        budget_ms: self.config.live.prediction_sla_ms,
                        context: None,
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
            }
            return;
        }
        self.remember_settlement_bar(&envelope);
        let Some(capability) = self.capability.clone() else {
            return;
        };
        let Some(ledger) = self.ledger.clone() else {
            return;
        };
        let root = self.root.clone();
        let os = self.config.os.clone();
        let live = self.config.live.clone();
        let available_envelopes = &self.settlement_bars;
        let available_context_observations = &self.context_observations;
        let mut ready_targets = Vec::new();

        for (target, runtime) in &mut self.targets {
            if envelope.bar.symbol.eq_ignore_ascii_case(target) {
                runtime
                    .target_events
                    .insert(envelope.bar_start.timestamp_millis(), envelope.clone());
                while runtime.target_events.len() > 16 {
                    let Some(oldest) = runtime.target_events.keys().next().copied() else {
                        break;
                    };
                    runtime.target_events.remove(&oldest);
                }
            }
            let update = match runtime.feature_engine.ingest(envelope.bar.clone()) {
                Ok(update) => update,
                Err(_) => {
                    persist_target_status(
                        &root,
                        TargetStatusUpdate {
                            target,
                            status: TargetInferenceState::CompatibilityRejected,
                            stage: TargetInferenceStage::FeatureEngine,
                            reason_code: Some("FEATURE_ENGINE_REJECTED_INPUT"),
                            cutoff: Some(envelope.bar_start),
                            latest_input_available_at: Some(envelope.provider_available_at),
                            compute_ms: None,
                            end_to_end_ms: None,
                            budget_ms: live.prediction_sla_ms,
                            context: None,
                            forecast_committed: false,
                            receipt_committed: false,
                            ledger_persisted: false,
                        },
                    );
                    continue;
                }
            };
            if !update.state_ready {
                // A context envelope arriving after this cutoff was already
                // emitted must not overwrite the authoritative published state.
                if update.reason == "CUTOFF_ALREADY_EMITTED" {
                    continue;
                }
                let (status, reason_code) = non_ready_update_state(&update.reason);
                persist_target_status(
                    &root,
                    TargetStatusUpdate {
                        target,
                        status,
                        stage: TargetInferenceStage::FeatureEngine,
                        reason_code: Some(reason_code),
                        cutoff: update.cutoff,
                        latest_input_available_at: None,
                        compute_ms: Some(update.compute_ms),
                        end_to_end_ms: None,
                        budget_ms: live.prediction_sla_ms,
                        context: update.context.as_ref(),
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
                continue;
            }
            let Some(cutoff) = update.cutoff else {
                persist_target_status(
                    &root,
                    TargetStatusUpdate {
                        target,
                        status: TargetInferenceState::CompatibilityRejected,
                        stage: TargetInferenceStage::FeatureEngine,
                        reason_code: Some("READY_FEATURE_UPDATE_CUTOFF_MISSING"),
                        cutoff: None,
                        latest_input_available_at: None,
                        compute_ms: Some(update.compute_ms),
                        end_to_end_ms: None,
                        budget_ms: live.prediction_sla_ms,
                        context: update.context.as_ref(),
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
                continue;
            };
            let Some(target_event) = runtime
                .target_events
                .get(&cutoff.timestamp_millis())
                .cloned()
            else {
                persist_target_status(
                    &root,
                    TargetStatusUpdate {
                        target,
                        status: TargetInferenceState::WaitingForTarget,
                        stage: TargetInferenceStage::SourceEnvelopeGate,
                        reason_code: Some("TARGET_SOURCE_ENVELOPE_MISSING"),
                        cutoff: Some(cutoff),
                        latest_input_available_at: None,
                        compute_ms: Some(update.compute_ms),
                        end_to_end_ms: None,
                        budget_ms: live.prediction_sla_ms,
                        context: update.context.as_ref(),
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
                continue;
            };
            if envelope_rejection(&target_event, live.stale_after_ms).is_some() {
                persist_target_status(
                    &root,
                    TargetStatusUpdate {
                        target,
                        status: TargetInferenceState::WaitingForTarget,
                        stage: TargetInferenceStage::SourceEnvelopeGate,
                        reason_code: Some("TARGET_SOURCE_ENVELOPE_REJECTED"),
                        cutoff: Some(cutoff),
                        latest_input_available_at: Some(target_event.provider_available_at),
                        compute_ms: Some(update.compute_ms),
                        end_to_end_ms: None,
                        budget_ms: live.prediction_sla_ms,
                        context: update.context.as_ref(),
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
                continue;
            }
            let Some(context) = update.context.as_ref() else {
                persist_target_status(
                    &root,
                    TargetStatusUpdate {
                        target,
                        status: TargetInferenceState::WaitingForContext,
                        stage: TargetInferenceStage::SourceInputManifest,
                        reason_code: Some("CONTEXT_READINESS_MISSING"),
                        cutoff: Some(cutoff),
                        latest_input_available_at: Some(target_event.provider_available_at),
                        compute_ms: Some(update.compute_ms),
                        end_to_end_ms: None,
                        budget_ms: live.prediction_sla_ms,
                        context: None,
                        forecast_committed: false,
                        receipt_committed: false,
                        ledger_persisted: false,
                    },
                );
                continue;
            };
            let source_input = match source_input_evidence(
                target,
                cutoff,
                &target_event,
                context,
                &live,
                available_envelopes,
                available_context_observations,
            ) {
                Ok(source_input) => source_input,
                Err(error) => {
                    let reason = sanitized_source_input_failure(&error.to_string());
                    persist_target_status(
                        &root,
                        TargetStatusUpdate {
                            target,
                            status: TargetInferenceState::WaitingForContext,
                            stage: TargetInferenceStage::SourceInputManifest,
                            reason_code: Some(reason),
                            cutoff: Some(cutoff),
                            latest_input_available_at: Some(target_event.provider_available_at),
                            compute_ms: Some(update.compute_ms),
                            end_to_end_ms: None,
                            budget_ms: live.prediction_sla_ms,
                            context: Some(context),
                            forecast_committed: false,
                            receipt_committed: false,
                            ledger_persisted: false,
                        },
                    );
                    continue;
                }
            };

            persist_target_status(
                &root,
                TargetStatusUpdate {
                    target,
                    status: TargetInferenceState::Running,
                    stage: TargetInferenceStage::FrozenInference,
                    reason_code: None,
                    cutoff: Some(cutoff),
                    latest_input_available_at: Some(source_input.latest_input_available_at),
                    compute_ms: None,
                    end_to_end_ms: Some(
                        Utc::now()
                            .signed_duration_since(source_input.latest_input_available_at)
                            .num_milliseconds(),
                    ),
                    budget_ms: live.prediction_sla_ms,
                    context: Some(context),
                    forecast_committed: false,
                    receipt_committed: false,
                    ledger_persisted: false,
                },
            );
            ready_targets.push((
                target.clone(),
                cutoff,
                PendingTargetInference {
                    context: context.clone(),
                    source_input,
                    feature_compute_ms: update.compute_ms,
                },
            ));
        }
        self.enqueue_ready_targets(ready_targets, &capability, &ledger, &os, &live);
        self.settle_ready_for_trigger(&envelope);
    }
}

/// Consume the verified envelopes emitted by the one Databento socket.
pub async fn run(
    config: AppConfig,
    root: PathBuf,
    receiver: mpsc::Receiver<DatabentoInferenceEvent>,
) -> Result<()> {
    if !config.live.enabled || !config.live.provider.eq_ignore_ascii_case("databento") {
        bail!("Databento inference requires the enabled Databento live provider");
    }
    if !config.live.quote_only
        || !config.live.shadow_only
        || config.live.allow_trade_api
        || config.execution.enabled
        || config.execution.allow_real_orders
    {
        bail!("Databento inference is research-only and refuses every execution path");
    }
    for target in configured_model_symbols(&config) {
        persist_target_status(
            &root,
            TargetStatusUpdate {
                target: &target,
                status: TargetInferenceState::WaitingForTarget,
                stage: TargetInferenceStage::ProviderInput,
                reason_code: Some("FIRST_VERIFIED_PROVIDER_ENVELOPE_PENDING"),
                cutoff: None,
                latest_input_available_at: None,
                compute_ms: None,
                end_to_end_ms: None,
                budget_ms: config.live.prediction_sla_ms,
                context: None,
                forecast_committed: false,
                receipt_committed: false,
                ledger_persisted: false,
            },
        );
    }
    // Loading the historical feature state and running all frozen models are
    // intentionally synchronous. Keep that work on one dedicated blocking
    // worker so API liveness/readiness requests remain responsive while the
    // immutable universe warms up and while each finalized bar is inferred.
    // The bounded Tokio channel still preserves ordering and applies
    // backpressure at the single licensed Databento socket.
    tokio::task::spawn_blocking(move || -> Result<()> {
        let mut receiver = receiver;
        // Do not allocate the multi-model historical state while the provider
        // is unlicensed or disconnected. The first accepted realtime envelope
        // is the initialization trigger.
        let first_event = receiver
            .blocking_recv()
            .context("DATABENTO_INFERENCE_CHANNEL_CLOSED_BEFORE_FIRST_ENVELOPE")?;
        let first_bar = match &first_event {
            DatabentoInferenceEvent::TradeBar { envelope } => envelope,
            DatabentoInferenceEvent::ContextObservation { .. } => {
                bail!("DATABENTO_INFERENCE_FIRST_EVENT_MUST_BE_TRADE_BAR")
            }
        };
        let session_date = first_bar.bar_start.with_timezone(&New_York).date_naive();
        let mut runtime = Runtime::initialize(config, root, session_date);
        runtime.handle_event(first_event);
        while let Some(event) = receiver.blocking_recv() {
            runtime.handle_event(event);
        }
        bail!("DATABENTO_INFERENCE_CHANNEL_CLOSED")
    })
    .await
    .context("DATABENTO_INFERENCE_WORKER_JOIN_FAILED")?
}

/// Bind a Databento forecast row to the exact verified source envelope receipt
/// written only after the same bundle was committed to the prediction ledger.
fn verified_receipt(root: &Path, row: &Value) -> Option<InferenceReceipt> {
    if row.get("data_source").and_then(Value::as_str) != Some(DATABENTO_FORECAST_DATA_SOURCE)
        || row.get("evidence_kind").and_then(Value::as_str) != Some("live_shadow_prediction")
    {
        return None;
    }
    let symbol = row.get("symbol").and_then(Value::as_str)?;
    let prediction_id = row.get("prediction_id").and_then(Value::as_str)?;
    let row_model_hash = row.get("model_hash").and_then(Value::as_str)?;
    let immutable = committed_immutable_publication(root, symbol);
    let (receipt, immutable_forecast) = if let Some((forecast, receipt, _, _)) = immutable {
        (receipt, Some(forecast))
    } else if immutable_publication_history_exists(root, symbol) {
        return None;
    } else {
        let receipt = fs::read(receipt_path(root, symbol))
            .ok()
            .and_then(|bytes| serde_json::from_slice::<InferenceReceipt>(&bytes).ok())?;
        (receipt, None)
    };
    let Ok(model_symbol) = canonical_live_symbol(symbol) else {
        return None;
    };
    let expected_forecast_path = forecast_path(root, symbol);
    let published_elapsed_ms = receipt
        .published_at
        .signed_duration_since(receipt.latest_input_available_at)
        .num_milliseconds();
    if receipt.schema_version != DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION
        || !receipt.provider.eq_ignore_ascii_case("databento")
        || !receipt.dataset.eq_ignore_ascii_case("EQUS.MINI")
        || receipt.data_source != DATABENTO_FORECAST_DATA_SOURCE
        || !receipt.model_symbol.eq_ignore_ascii_case(&model_symbol)
        || receipt.model_hash != row_model_hash
        || receipt.forecast_path != expected_forecast_path.display().to_string()
        || receipt.forecast_sha256.len() != 64
        || !receipt
            .forecast_sha256
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit())
        || receipt.budget_ms <= 0
        || receipt.end_to_end_ms < 0
        || receipt.end_to_end_ms > receipt.budget_ms
        || receipt.end_to_end_ms != published_elapsed_ms
        || receipt.generated_at < receipt.latest_input_available_at
        || receipt.generated_at > receipt.published_at
        || !receipt.ledger_persisted
        || receipt.execution_enabled
        || !receipt.prediction_ids.iter().any(|id| id == prediction_id)
        || receipt.max_context_skew_ms <= 0
        || receipt.source_envelope_count == 0
        || receipt.source_envelope_count != receipt.source_envelopes.len()
        || receipt.cutoff_source_envelopes.is_empty()
    {
        return None;
    }

    let forecast_value = if let Some(forecast) = immutable_forecast {
        forecast
    } else {
        let forecast_bytes = fs::read(&expected_forecast_path).ok()?;
        if !sha256_bytes(&forecast_bytes).eq_ignore_ascii_case(&receipt.forecast_sha256) {
            return None;
        }
        serde_json::from_slice::<Value>(&forecast_bytes).ok()?
    };
    if forecast_value
        .get("prediction_layer")
        .and_then(Value::as_array)
        .is_none_or(|contracts| {
            !contracts.iter().any(|contract| {
                contract.get("prediction_id").and_then(Value::as_str) == Some(prediction_id)
                    && contract.get("model_hash").and_then(Value::as_str) == Some(row_model_hash)
            })
        })
    {
        return None;
    }

    let required_context = receipt
        .required_context_symbols
        .iter()
        .map(|context_symbol| canonical_live_symbol(context_symbol))
        .collect::<Result<BTreeSet<_>>>();
    let Ok(required_context) = required_context else {
        return None;
    };
    if required_context.len() != receipt.required_context_symbols.len() {
        return None;
    }
    let mut expected_symbols = required_context.clone();
    expected_symbols.insert(model_symbol.clone());

    let mut canonical_manifest = receipt.source_envelopes.clone();
    canonical_manifest.sort_by(|left, right| {
        left.bar_start
            .cmp(&right.bar_start)
            .then_with(|| left.symbol.cmp(&right.symbol))
            .then_with(|| left.provider_available_at.cmp(&right.provider_available_at))
    });
    let manifest_unique = canonical_manifest
        .windows(2)
        .all(|pair| pair[0].bar_start != pair[1].bar_start || pair[0].symbol != pair[1].symbol);
    if !manifest_unique
        || canonical_manifest != receipt.source_envelopes
        || source_envelopes_sha256(&canonical_manifest)
            .ok()
            .is_none_or(|actual| !actual.eq_ignore_ascii_case(&receipt.source_envelopes_sha256))
        || canonical_manifest.iter().any(|source| {
            canonical_live_symbol(&source.symbol).ok().as_deref() != Some(source.symbol.as_str())
                || !expected_symbols.contains(&source.symbol)
                || source.bar_end != source.bar_start + Duration::minutes(1)
                || source.provider_available_at < source.bar_end
                || source
                    .provider_available_at
                    .signed_duration_since(source.bar_end)
                    .num_milliseconds()
                    > 10_000
                || source.envelope_sha256.len() != 64
                || !source
                    .envelope_sha256
                    .bytes()
                    .all(|byte| byte.is_ascii_hexdigit())
        })
        || expected_symbols.iter().any(|expected| {
            !canonical_manifest
                .iter()
                .any(|source| &source.symbol == expected)
        })
    {
        return None;
    }

    let mut cutoff_symbols = BTreeSet::new();
    let mut target_envelope = None;
    for envelope in &receipt.cutoff_source_envelopes {
        let Ok(source) = inference_source_envelope(envelope) else {
            return None;
        };
        if envelope_rejection(envelope, 10_000).is_some()
            || !expected_symbols.contains(&source.symbol)
            || !canonical_manifest.contains(&source)
            || !cutoff_symbols.insert(source.symbol.clone())
        {
            return None;
        }
        if source.symbol == model_symbol {
            target_envelope = Some(envelope);
        }
    }
    for envelope in &receipt.cutoff_context_observations {
        let Ok(source) = inference_absence_source_envelope(envelope) else {
            return None;
        };
        if source.symbol == model_symbol
            || !required_context.contains(&source.symbol)
            || !canonical_manifest.contains(&source)
            || !cutoff_symbols.insert(source.symbol)
        {
            return None;
        }
    }
    let target_envelope = target_envelope?;
    if cutoff_symbols != expected_symbols
        || canonical_manifest.iter().any(|source| {
            source.bar_start > target_envelope.bar_start
                || source.bar_start.with_timezone(&New_York).date_naive()
                    != target_envelope
                        .bar_start
                        .with_timezone(&New_York)
                        .date_naive()
        })
        || receipt
            .cutoff_source_envelopes
            .iter()
            .filter(|envelope| !envelope.bar.symbol.eq_ignore_ascii_case(&model_symbol))
            .any(|envelope| {
                let skew_ms = target_envelope
                    .bar_start
                    .signed_duration_since(envelope.bar_start)
                    .num_milliseconds();
                skew_ms < 0 || skew_ms > receipt.max_context_skew_ms
            })
        || receipt.cutoff_context_observations.iter().any(|envelope| {
            let skew_ms = target_envelope
                .bar_start
                .signed_duration_since(envelope.interval_start)
                .num_milliseconds();
            skew_ms < 0 || skew_ms > receipt.max_context_skew_ms
        })
    {
        return None;
    }

    let latest_input_available_at = canonical_manifest
        .iter()
        .map(|source| source.provider_available_at)
        .max();
    let observation_cutoff = value_datetime(row.get("observation_cutoff"))?;
    let reference_price = row.get("reference_price").and_then(Value::as_f64)?;
    let reference_matches = reference_price.is_finite()
        && (reference_price - target_envelope.bar.close).abs()
            <= f64::EPSILON
                * reference_price
                    .abs()
                    .max(target_envelope.bar.close.abs())
                    .max(1.0);
    (observation_cutoff == target_envelope.bar_end
        && reference_matches
        && latest_input_available_at == Some(receipt.latest_input_available_at)
        && value_datetime(row.get("decision_as_of")) == Some(receipt.latest_input_available_at)
        && value_datetime(row.get("latest_input_available_at"))
            == Some(receipt.latest_input_available_at))
    .then_some(receipt)
}

/// Return whether a candidate is bound to a fully validated receipt and exact
/// forecast artifact.
pub fn receipt_matches_forecast_row(root: &Path, row: &Value) -> bool {
    verified_receipt(root, row).is_some()
}

/// Return only non-secret receipt lineage after the complete receipt, source,
/// clock, model, and forecast-hash validation contract passes.
pub fn verified_receipt_lineage(root: &Path, row: &Value) -> Option<Value> {
    let receipt = verified_receipt(root, row)?;
    Some(serde_json::json!({
        "schema_version": receipt.schema_version,
        "source_envelopes_sha256": receipt.source_envelopes_sha256,
        "forecast_sha256": receipt.forecast_sha256,
        "published_at": receipt.published_at,
        "end_to_end_ms": receipt.end_to_end_ms,
        "budget_ms": receipt.budget_ms
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::databento_live::DATABENTO_LIVE_BAR_SCHEMA_VERSION;
    use crate::domain::MarketBar;
    use crate::predictor::{BarrierProbabilities, DecisionPolicyResult};

    const BATCH_SYMBOLS: [&str; 9] = [
        "AAPL", "BE", "IGV", "MU", "NBIS", "NVDA", "QQQ", "SOXX", "SPY",
    ];

    fn valid_envelope() -> DatabentoRealtimeBarEnvelope {
        let start = DateTime::parse_from_rfc3339("2026-07-27T13:30:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let available = start + Duration::minutes(1) + Duration::seconds(1);
        DatabentoRealtimeBarEnvelope {
            schema_version: DATABENTO_LIVE_BAR_SCHEMA_VERSION.into(),
            provider: "databento".into(),
            dataset: "EQUS.MINI".into(),
            provider_schema: "ohlcv-1m".into(),
            received_at: available,
            provider_available_at: available,
            bar_start: start,
            bar_end: start + Duration::minutes(1),
            finalized_at: available,
            entitlement: "REALTIME_SUBSCRIPTION_ACKNOWLEDGED".into(),
            delayed: false,
            stale: false,
            replay: false,
            symbol_mapping_verified: true,
            bar: MarketBar {
                timestamp: start,
                symbol: "NVDA".into(),
                open: 200.0,
                high: 201.0,
                low: 199.0,
                close: 200.5,
                volume: 10_000.0,
                vwap: None,
                bid: None,
                ask: None,
                trade_count: None,
                source: "Databento/EQUS.MINI/ohlcv-1m".into(),
                data_quality: "licensed_vendor_original_dbn_realtime".into(),
            },
            caveats: Vec::new(),
        }
    }

    fn envelope_at(offset_minutes: i64) -> DatabentoRealtimeBarEnvelope {
        let mut envelope = valid_envelope();
        let shift = Duration::minutes(offset_minutes);
        envelope.received_at += shift;
        envelope.provider_available_at += shift;
        envelope.bar_start += shift;
        envelope.bar_end += shift;
        envelope.finalized_at += shift;
        envelope.bar.timestamp += shift;
        envelope
    }

    fn causal_absence_at(
        symbol: &str,
        interval_start: DateTime<Utc>,
    ) -> DatabentoCausalAbsenceEnvelope {
        let received_at = interval_start + Duration::minutes(1) + Duration::seconds(2);
        let observation = crate::domain::CausalMinuteObservation {
            schema_version: crate::domain::CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.into(),
            symbol: symbol.into(),
            interval_start,
            interval_end: interval_start + Duration::minutes(1),
            state: crate::domain::MinuteObservationState::CausallyInferredNoTrade,
            evidence_available_at: Some(received_at),
            evidence_source: Some(
                "Databento/EQUS.MINI/ohlcv-1m/CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH".into(),
            ),
            evidence_reference: Some(format!("eoi:{symbol}:{}", interval_start.to_rfc3339())),
        };
        DatabentoCausalAbsenceEnvelope {
            schema_version: crate::data::databento_live::DATABENTO_CAUSAL_ABSENCE_SCHEMA_VERSION
                .into(),
            provider: "databento".into(),
            dataset: "EQUS.MINI".into(),
            provider_schema: "ohlcv-1m".into(),
            received_at,
            interval_start,
            interval_end: interval_start + Duration::minutes(1),
            finalize_grace_ms: 2_000,
            subscription_acknowledged_at: interval_start - Duration::minutes(2),
            symbol_mapping_verified_at: interval_start - Duration::minutes(2),
            continuous_health_started_at: interval_start - Duration::minutes(2),
            continuous_health_observed_through: received_at,
            prior_real_trade_interval_start: interval_start - Duration::minutes(1),
            derivation: "CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH".into(),
            observation,
        }
    }

    #[test]
    fn source_manifest_accepts_valid_causal_absence_without_fabricating_vendor_bar() {
        let mut target = valid_envelope();
        target.bar.symbol = "NVDA".into();
        let cutoff = target.bar_start;
        let mut prior_context = envelope_at(-1);
        prior_context.bar.symbol = "QQQ".into();
        let absence = causal_absence_at("QQQ", cutoff);
        assert!(absence.validate());
        let available_bars = BTreeMap::from([
            ((cutoff.timestamp_millis(), "NVDA".into()), target.clone()),
            (
                (prior_context.bar_start.timestamp_millis(), "QQQ".into()),
                prior_context,
            ),
        ]);
        let available_absences =
            BTreeMap::from([((cutoff.timestamp_millis(), "QQQ".into()), absence.clone())]);
        let context = ContextReadiness {
            schema_version: "point_in_time_context_readiness.v2".into(),
            cutoff,
            max_skew_ms: 5_000,
            minimum_continuous_bars: 6,
            ready: true,
            symbols: vec![crate::engine::features::ContextSymbolReadiness {
                symbol: "QQQ".into(),
                latest_at_or_before_cutoff: Some(cutoff),
                skew_ms: Some(0),
                expected_intervals: 6,
                observed_trade_intervals: 5,
                causally_inferred_no_trade_intervals: 1,
                unknown_missing_intervals: 0,
                continuous_bars: 6,
                ready: true,
                reasons: Vec::new(),
            }],
            blockers: Vec::new(),
        };
        let live = LiveConfig {
            required_context_symbols: vec!["QQQ".into()],
            max_context_skew_ms: 5_000,
            stale_after_ms: 10_000,
            ..LiveConfig::default()
        };

        let evidence = source_input_evidence(
            "NVDA",
            cutoff,
            &target,
            &context,
            &live,
            &available_bars,
            &available_absences,
        )
        .unwrap();

        assert_eq!(evidence.cutoff_context_observations, vec![absence]);
        assert_eq!(evidence.cutoff_source_envelopes.len(), 1);
        assert!(
            evidence
                .source_envelopes
                .iter()
                .any(|source| source.observation_state == "causally_inferred_no_trade")
        );
    }

    fn publication_receipt(forecast: &Path) -> InferenceReceipt {
        let now = Utc::now();
        InferenceReceipt {
            schema_version: DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION.into(),
            generated_at: now,
            published_at: now,
            end_to_end_ms: 0,
            budget_ms: 60_000,
            provider: "databento".into(),
            dataset: "EQUS.MINI".into(),
            data_source: DATABENTO_FORECAST_DATA_SOURCE.into(),
            model_symbol: "NVDA".into(),
            model_hash: "a".repeat(64),
            forecast_path: forecast.display().to_string(),
            forecast_sha256: String::new(),
            prediction_ids: vec!["prediction-1".into()],
            latest_input_available_at: now,
            required_context_symbols: vec![],
            max_context_skew_ms: 5_000,
            source_envelope_count: 0,
            source_envelopes_sha256: "b".repeat(64),
            source_envelopes: vec![],
            cutoff_source_envelopes: vec![],
            cutoff_context_observations: vec![],
            batch_id: None,
            batch_cutoff: None,
            batch_committed_at: None,
            ledger_persisted: true,
            execution_enabled: false,
        }
    }

    fn batch_contract(
        generation: &str,
        symbol: &str,
        horizon_minutes: usize,
        cutoff: DateTime<Utc>,
    ) -> ForecastContract {
        let source_available_at = cutoff + Duration::milliseconds(50);
        ForecastContract {
            prediction_id: format!("{generation}-{symbol}-h{horizon_minutes:02}"),
            created_at: source_available_at,
            observation_cutoff: cutoff,
            as_of: cutoff,
            decision_as_of: source_available_at,
            latest_input_available_at: source_available_at,
            earliest_executable_time: source_available_at + Duration::milliseconds(250),
            symbol: symbol.into(),
            timeframe: "1m".into(),
            horizon_minutes,
            label_start: cutoff,
            label_end: cutoff + Duration::minutes(horizon_minutes as i64),
            session: cutoff.date_naive().to_string(),
            timezone: "America/New_York".into(),
            reference_price: 100.0,
            reference_price_source: "FINALIZED_1M_CLOSE_REFERENCE_ONLY".into(),
            expected_return: 0.0001,
            expected_price: None,
            return_definition: "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN".into(),
            current_close_reference_scenario_expected_price: 100.01,
            current_close_reference_scenario_price_quantiles: Vec::new(),
            current_close_reference_scenario_basis: "FINALIZED_CURRENT_1M_CLOSE_REFERENCE_SCENARIO"
                .into(),
            current_close_reference_scenario_status:
                "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST".into(),
            current_close_reference_scenario_semantics:
                "NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE".into(),
            median_return: 0.0001,
            return_quantiles: Vec::new(),
            price_quantiles: Vec::new(),
            p_up: None,
            p_down: None,
            p_flat: None,
            raw_analog_up_frequency: 0.5,
            raw_analog_down_frequency: 0.5,
            raw_analog_flat_frequency: 0.0,
            calibrated_probability_up: None,
            probability_calibration: Default::default(),
            suggested_direction: 1,
            strategy_win_probability: None,
            kernel_regression: Default::default(),
            outcome_prediction_intervals: Vec::new(),
            expected_volatility: 0.002,
            expected_absolute_move: 0.001,
            mfe_distribution: Vec::new(),
            mae_distribution: Vec::new(),
            barrier_probabilities: BarrierProbabilities {
                upper_first: None,
                lower_first: None,
                neither: None,
                status: "WITHHELD_UNPROMOTED_RESEARCH_OUTPUT".into(),
            },
            filtered_state_probabilities: vec![0.55, 0.45],
            predicted_state_probabilities: vec![0.52, 0.48],
            state_entropy: Some(0.69),
            dominant_regime_state: Some(0),
            dominant_regime_probability: Some(0.55),
            regime_model_selection: None,
            stochastic_research_layer: Default::default(),
            epistemic_uncertainty: 0.4,
            ood_score: 0.2,
            market_snapshot_id: None,
            snapshot_link_status: "NOT_MATERIALIZED_TEST".into(),
            top_analogs: Vec::new(),
            analog_effective_sample_size: 32.0,
            analog_similarity_score: 0.74,
            analog_max_day_weight: 0.08,
            analog_concentration_penalty: 0.0,
            analog_engine_status: "TEST_UNCALIBRATED".into(),
            analog_metric: "SHRINKAGE_MAHALANOBIS".into(),
            analog_bandwidth: 1.0,
            analog_diagnostics: None,
            analog_sensitivity: Vec::new(),
            model_id: "frozen-test-model".into(),
            model_hash: "a".repeat(64),
            feature_version: "point-in-time-test".into(),
            feature_hash: "b".repeat(64),
            data_source: DATABENTO_FORECAST_DATA_SOURCE.into(),
            data_capability_level: "D1_REALTIME_UNDERLYING".into(),
            market_coverage: "TEST_NINE_SYMBOL_BATCH".into(),
            model_trained_through: "2026-07-17".into(),
            target_status: "DIRECT_UNDERLYING_ONLY".into(),
            data_manifest_hash: "c".repeat(64),
            evidence_grade: "FORWARD_SHADOW".into(),
            evidence_kind: "live_shadow_prediction".into(),
            sample_size: 32,
            calibration_status: "CANDIDATE_NOT_PROMOTED".into(),
            availability_semantics: "DATABENTO_FINALIZED_OHLCV_1M_LOCAL_RECEIPT_TIMESTAMP".into(),
            decision: DecisionPolicyResult {
                action: "NO_TRADE".into(),
                eligible: false,
                expected_edge_after_cost: 0.0,
                no_trade_reasons: vec!["UNPROMOTED_RESEARCH_OUTPUT".into()],
                policy_version: "research-only-no-execution.v1".into(),
            },
        }
    }

    struct StagedBatchFixture {
        manifest_path: PathBuf,
        member_paths: BTreeMap<String, PathBuf>,
        publications: Vec<PredictionPublicationCommit>,
        request: PredictionPublicationBatchRequest,
    }

    fn stage_batch_fixture(
        root: &Path,
        ledger: &PredictionLedger,
        generation: &str,
        cutoff: DateTime<Utc>,
    ) -> StagedBatchFixture {
        let predictions = BATCH_SYMBOLS
            .iter()
            .flat_map(|symbol| {
                [5_usize, 15, 30, 60]
                    .into_iter()
                    .map(move |horizon| batch_contract(generation, symbol, horizon, cutoff))
            })
            .collect::<Vec<_>>();
        let canonical = ledger
            .append_prediction_batch(cutoff, &predictions)
            .unwrap();
        let batch_id = format!("batch-{generation}");
        let prepared_at = Utc::now();
        let mut manifest_members = Vec::new();
        let mut member_paths = BTreeMap::new();
        let mut publications = Vec::new();
        for symbol in BATCH_SYMBOLS {
            let contracts = canonical
                .iter()
                .filter(|contract| contract.symbol == symbol)
                .cloned()
                .collect::<Vec<_>>();
            let prediction_ids = contracts
                .iter()
                .map(|contract| contract.prediction_id.clone())
                .collect::<Vec<_>>();
            let forecast = serde_json::json!({
                "generation": generation,
                "prediction_layer": contracts
            });
            let forecast_bytes = serde_json::to_vec_pretty(&forecast).unwrap();
            let forecast_sha256 = sha256_bytes(&forecast_bytes);
            let source_available_at = cutoff + Duration::milliseconds(50);
            let receipt = InferenceReceipt {
                schema_version: DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION.into(),
                generated_at: source_available_at,
                published_at: prepared_at,
                end_to_end_ms: prepared_at
                    .signed_duration_since(source_available_at)
                    .num_milliseconds(),
                budget_ms: 60_000,
                provider: "databento".into(),
                dataset: "EQUS.MINI".into(),
                data_source: DATABENTO_FORECAST_DATA_SOURCE.into(),
                model_symbol: symbol.into(),
                model_hash: "a".repeat(64),
                forecast_path: forecast_path(root, symbol).display().to_string(),
                forecast_sha256: forecast_sha256.clone(),
                prediction_ids: prediction_ids.clone(),
                latest_input_available_at: source_available_at,
                required_context_symbols: Vec::new(),
                max_context_skew_ms: 5_000,
                source_envelope_count: 0,
                source_envelopes_sha256: "b".repeat(64),
                source_envelopes: Vec::new(),
                cutoff_source_envelopes: Vec::new(),
                cutoff_context_observations: Vec::new(),
                batch_id: Some(batch_id.clone()),
                batch_cutoff: Some(cutoff),
                batch_committed_at: None,
                ledger_persisted: true,
                execution_enabled: false,
            };
            let (publication_path, publication_sha256) =
                write_immutable_publication(root, &forecast_bytes, &receipt).unwrap();
            let relative_path = publication_path
                .strip_prefix(root)
                .unwrap()
                .to_string_lossy()
                .replace('\\', "/");
            manifest_members.push(ForecastBatchMember {
                model_symbol: symbol.into(),
                forecast_sha256: forecast_sha256.clone(),
                publication_sha256: publication_sha256.clone(),
                publication_path: relative_path,
                prediction_ids: prediction_ids.clone(),
                latest_input_available_at: source_available_at,
            });
            member_paths.insert(symbol.into(), publication_path);
            publications.extend(prediction_ids.into_iter().map(|prediction_id| {
                PredictionPublicationCommit {
                    publication_id: format!("{batch_id}:{prediction_id}"),
                    prediction_id,
                    published_at: prepared_at,
                    provider: "DATABENTO".into(),
                    forecast_sha256: forecast_sha256.clone(),
                    publication_sha256: publication_sha256.clone(),
                    evidence_kind: "live_forecast_publication_commit".into(),
                }
            }));
        }
        manifest_members.sort_by(|left, right| left.model_symbol.cmp(&right.model_symbol));
        publications.sort_by(|left, right| left.publication_id.cmp(&right.publication_id));
        let symbols = BATCH_SYMBOLS
            .iter()
            .map(|symbol| (*symbol).to_string())
            .collect::<Vec<_>>();
        let manifest = ImmutableForecastBatchManifest {
            schema_version: DATABENTO_BATCH_MANIFEST_SCHEMA_VERSION.into(),
            batch_id: batch_id.clone(),
            prepared_at,
            cutoff,
            symbols: symbols.clone(),
            members: manifest_members,
            execution_enabled: false,
        };
        let (manifest_path, manifest_sha256) =
            write_immutable_batch_manifest(root, &manifest).unwrap();
        let mut prediction_ids = canonical
            .iter()
            .map(|contract| contract.prediction_id.clone())
            .collect::<Vec<_>>();
        prediction_ids.sort();
        let mut publication_ids = publications
            .iter()
            .map(|publication| publication.publication_id.clone())
            .collect::<Vec<_>>();
        publication_ids.sort();
        let request = PredictionPublicationBatchRequest {
            schema_version: PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION.into(),
            batch_id,
            cutoff,
            symbols,
            manifest_sha256,
            execution_disabled: true,
            prediction_ids,
            publication_ids,
            target_slas: BATCH_SYMBOLS
                .iter()
                .map(|symbol| PredictionPublicationBatchTargetSla {
                    symbol: (*symbol).into(),
                    source_available_at: cutoff + Duration::milliseconds(50),
                    budget_ms: 60_000,
                })
                .collect(),
        };
        StagedBatchFixture {
            manifest_path,
            member_paths,
            publications,
            request,
        }
    }

    #[test]
    fn bounded_scheduler_never_exceeds_four_workers() {
        assert_eq!(bounded_worker_count(9, 64), 4);
        assert_eq!(bounded_worker_count(9, 2), 2);
        assert_eq!(bounded_worker_count(1, 64), 1);
        assert_eq!(bounded_worker_count(0, 0), 1);
    }

    #[test]
    fn bounded_scheduler_uses_every_selected_worker() {
        assert_eq!(bounded_worker_partition_sizes(9, 4), vec![3, 2, 2, 2]);
        assert_eq!(bounded_worker_partition_sizes(9, 2), vec![5, 4]);
        assert_eq!(bounded_worker_partition_sizes(3, 4), vec![1, 1, 1]);
        assert!(bounded_worker_partition_sizes(0, 4).is_empty());
    }

    #[test]
    fn batch_reader_hides_staged_members_until_the_single_ledger_marker_commits() {
        let directory = tempfile::tempdir().unwrap();
        let root = directory.path();
        let ledger = PredictionLedger::open(&root.join("state/prediction_ledger.sqlite3")).unwrap();
        let expected_symbols = BATCH_SYMBOLS
            .iter()
            .map(|symbol| (*symbol).to_string())
            .collect::<BTreeSet<_>>();
        let staged =
            stage_batch_fixture(root, &ledger, "staged", Utc::now() - Duration::seconds(1));

        assert!(staged.manifest_path.is_file());
        assert_eq!(staged.member_paths.len(), 9);
        assert!(
            read_latest_committed_forecast_batch(root, &expected_symbols).is_none(),
            "prediction rows and durable artifacts without the final marker are not visible"
        );

        let marker = ledger
            .append_publication_batch(&staged.publications, &staged.request)
            .unwrap();
        let batch = read_latest_committed_forecast_batch(root, &expected_symbols).unwrap();
        assert_eq!(batch.batch_id, marker.batch_id);
        assert_eq!(batch.cutoff, marker.cutoff);
        assert_eq!(batch.committed_at, marker.committed_at);
        assert_eq!(batch.forecasts.len(), 9);
        assert!(batch.forecasts.values().all(|forecast| {
            forecast.get("generation").and_then(Value::as_str) == Some("staged")
                && forecast
                    .get("prediction_layer")
                    .and_then(Value::as_array)
                    .is_some_and(|rows| rows.len() == 4)
        }));
        assert_eq!(
            read_latest_committed_forecast(root, "NVDA")
                .and_then(|forecast| forecast.get("generation").cloned()),
            Some(Value::String("staged".into()))
        );
    }

    #[test]
    fn corrupt_new_batch_member_falls_back_to_the_previous_complete_generation() {
        let directory = tempfile::tempdir().unwrap();
        let root = directory.path();
        let ledger = PredictionLedger::open(&root.join("state/prediction_ledger.sqlite3")).unwrap();
        let expected_symbols = BATCH_SYMBOLS
            .iter()
            .map(|symbol| (*symbol).to_string())
            .collect::<BTreeSet<_>>();
        let old = stage_batch_fixture(root, &ledger, "old", Utc::now() - Duration::seconds(2));
        ledger
            .append_publication_batch(&old.publications, &old.request)
            .unwrap();
        let new = stage_batch_fixture(root, &ledger, "new", Utc::now() - Duration::seconds(1));
        ledger
            .append_publication_batch(&new.publications, &new.request)
            .unwrap();
        assert!(
            read_latest_committed_forecast_batch(root, &expected_symbols)
                .unwrap()
                .forecasts
                .values()
                .all(|forecast| forecast.get("generation").and_then(Value::as_str) == Some("new"))
        );

        fs::write(
            new.member_paths.get("NVDA").unwrap(),
            b"{\"corrupted\":true}",
        )
        .unwrap();
        let recovered = read_latest_committed_forecast_batch(root, &expected_symbols).unwrap();
        assert_eq!(recovered.batch_id, old.request.batch_id);
        assert!(
            recovered
                .forecasts
                .values()
                .all(|forecast| forecast.get("generation").and_then(Value::as_str) == Some("old"))
        );
    }

    #[test]
    fn incomplete_new_batch_never_replaces_the_previous_complete_generation() {
        let directory = tempfile::tempdir().unwrap();
        let root = directory.path();
        let ledger = PredictionLedger::open(&root.join("state/prediction_ledger.sqlite3")).unwrap();
        let expected_symbols = BATCH_SYMBOLS
            .iter()
            .map(|symbol| (*symbol).to_string())
            .collect::<BTreeSet<_>>();
        let old = stage_batch_fixture(root, &ledger, "old", Utc::now() - Duration::seconds(2));
        ledger
            .append_publication_batch(&old.publications, &old.request)
            .unwrap();
        let staged = stage_batch_fixture(
            root,
            &ledger,
            "uncommitted",
            Utc::now() - Duration::seconds(1),
        );
        assert!(staged.manifest_path.is_file());

        let recovered = read_latest_committed_forecast_batch(root, &expected_symbols).unwrap();
        assert_eq!(recovered.batch_id, old.request.batch_id);
        assert!(
            recovered
                .forecasts
                .values()
                .all(|forecast| forecast.get("generation").and_then(Value::as_str) == Some("old"))
        );
    }

    #[test]
    fn accepts_only_exact_fresh_entitled_databento_envelope() {
        assert!(envelope_rejection(&valid_envelope(), 10_000).is_none());

        let mut replay = valid_envelope();
        replay.replay = true;
        assert_eq!(
            envelope_rejection(&replay, 10_000).as_deref(),
            Some("DATABENTO_REALTIME_ENTITLEMENT_GATE_REJECTED")
        );

        let mut delayed = valid_envelope();
        delayed.delayed = true;
        assert!(envelope_rejection(&delayed, 10_000).is_some());

        let mut wrong_dataset = valid_envelope();
        wrong_dataset.dataset = "EQUS.FULL".into();
        assert_eq!(
            envelope_rejection(&wrong_dataset, 10_000).as_deref(),
            Some("DATABENTO_SOURCE_IDENTITY_MISMATCH")
        );
    }

    #[test]
    fn rejects_misaligned_availability_and_bar_clocks() {
        let mut envelope = valid_envelope();
        envelope.provider_available_at = envelope.bar_end - Duration::milliseconds(1);
        envelope.received_at = envelope.provider_available_at;
        envelope.finalized_at = envelope.provider_available_at;
        assert_eq!(
            envelope_rejection(&envelope, 10_000).as_deref(),
            Some("DATABENTO_AVAILABILITY_CLOCK_INVALID")
        );

        let mut envelope = valid_envelope();
        envelope.bar.timestamp += Duration::minutes(1);
        assert_eq!(
            envelope_rejection(&envelope, 10_000).as_deref(),
            Some("DATABENTO_BAR_CONTRACT_INVALID")
        );
    }

    #[test]
    fn publish_pair_sla_rejects_staged_outputs_without_replacing_latest() {
        let directory = tempfile::tempdir().unwrap();
        let forecast = directory.path().join("forecast_latest.json");
        let receipt_path = directory.path().join("receipt_latest.json");
        write_json_atomic(&forecast, &serde_json::json!({"generation":"old"})).unwrap();
        write_json_atomic(&receipt_path, &serde_json::json!({"generation":"old"})).unwrap();
        let forecast_staged =
            write_json_staged(&forecast, &serde_json::json!({"generation":"new"})).unwrap();
        let mut receipt = publication_receipt(&forecast);

        let error = promote_staged_forecast_pair_with_sla(
            &forecast_staged,
            &forecast,
            &receipt_path,
            &mut receipt,
            Utc::now() - Duration::seconds(2),
            1,
        )
        .unwrap_err();

        assert!(error.to_string().contains("PREDICTION_SLA_EXCEEDED"));
        assert_eq!(
            serde_json::from_slice::<Value>(&fs::read(&forecast).unwrap()).unwrap(),
            serde_json::json!({"generation":"old"})
        );
        assert_eq!(
            serde_json::from_slice::<Value>(&fs::read(&receipt_path).unwrap()).unwrap(),
            serde_json::json!({"generation":"old"})
        );
        assert!(!forecast_staged.exists());
    }

    #[test]
    fn publish_pair_sla_promotes_forecast_then_exact_receipt_marker() {
        let directory = tempfile::tempdir().unwrap();
        let forecast = directory.path().join("forecast_latest.json");
        let receipt_path = directory.path().join("receipt_latest.json");
        let forecast_staged =
            write_json_staged(&forecast, &serde_json::json!({"generation":"new"})).unwrap();
        let mut receipt = publication_receipt(&forecast);

        let published = promote_staged_forecast_pair_with_sla(
            &forecast_staged,
            &forecast,
            &receipt_path,
            &mut receipt,
            Utc::now(),
            60_000,
        )
        .unwrap();

        assert!((0..=60_000).contains(&published.end_to_end_ms));
        assert!(published.publication_path.is_file());
        assert_eq!(
            sha256_file(&published.publication_path).unwrap(),
            published.publication_sha256
        );
        assert_eq!(
            serde_json::from_slice::<Value>(&fs::read(&forecast).unwrap()).unwrap(),
            serde_json::json!({"generation":"new"})
        );
        let persisted: InferenceReceipt =
            serde_json::from_slice(&fs::read(&receipt_path).unwrap()).unwrap();
        assert_eq!(persisted.forecast_sha256, sha256_file(&forecast).unwrap());
        assert_eq!(persisted.end_to_end_ms, published.end_to_end_ms);
        assert_eq!(persisted.budget_ms, 60_000);
    }

    #[test]
    fn immutable_publication_skips_orphan_generation_and_preserves_previous_commit() {
        let directory = tempfile::tempdir().unwrap();
        let root = directory.path();
        let forecast = forecast_path(root, "NVDA");
        let receipt_output = receipt_path(root, "NVDA");
        let ledger = PredictionLedger::open(&root.join("state/prediction_ledger.sqlite3")).unwrap();

        let publish = |generation: &str,
                       prediction_id: &str,
                       ledger: &PredictionLedger|
         -> (PublishedGeneration, InferenceReceipt) {
            let value = serde_json::json!({
                "generation":generation,
                "prediction_layer":[{
                    "prediction_id":prediction_id,
                    "model_hash":"a".repeat(64)
                }]
            });
            let staged = write_json_staged(&forecast, &value).unwrap();
            let mut receipt = publication_receipt(&forecast);
            receipt.prediction_ids = vec![prediction_id.to_string()];
            let published = promote_staged_forecast_pair_with_sla(
                &staged,
                &forecast,
                &receipt_output,
                &mut receipt,
                Utc::now(),
                60_000,
            )
            .unwrap();
            ledger
                .append_raw_prediction_for_test(
                    prediction_id,
                    &serde_json::json!({
                        "prediction_id":prediction_id,
                        "data_source":DATABENTO_FORECAST_DATA_SOURCE
                    }),
                )
                .unwrap();
            (published, receipt)
        };

        let (old_generation, old_receipt) = publish("old", "old-prediction", &ledger);
        ledger
            .append_publication_commit(&PredictionPublicationCommit {
                publication_id: "old-publication".into(),
                prediction_id: "old-prediction".into(),
                published_at: old_receipt.published_at,
                provider: "DATABENTO".into(),
                forecast_sha256: old_receipt.forecast_sha256.clone(),
                publication_sha256: old_generation.publication_sha256.clone(),
                evidence_kind: "live_forecast_publication_commit".into(),
            })
            .unwrap();
        assert_eq!(
            read_latest_committed_forecast(root, "NVDA")
                .unwrap()
                .get("generation")
                .and_then(Value::as_str),
            Some("old")
        );

        let (new_generation, new_receipt) = publish("new", "new-prediction", &ledger);
        assert_eq!(
            serde_json::from_slice::<Value>(&fs::read(&forecast).unwrap())
                .unwrap()
                .get("generation")
                .and_then(Value::as_str),
            Some("new")
        );
        assert_eq!(
            read_latest_committed_forecast(root, "NVDA")
                .unwrap()
                .get("generation")
                .and_then(Value::as_str),
            Some("old"),
            "an immutable generation without a ledger publication commit is an orphan"
        );

        ledger
            .append_publication_commit(&PredictionPublicationCommit {
                publication_id: "new-publication".into(),
                prediction_id: "new-prediction".into(),
                published_at: new_receipt.published_at,
                provider: "DATABENTO".into(),
                forecast_sha256: new_receipt.forecast_sha256,
                publication_sha256: new_generation.publication_sha256,
                evidence_kind: "live_forecast_publication_commit".into(),
            })
            .unwrap();
        assert_eq!(
            read_latest_committed_forecast(root, "NVDA")
                .unwrap()
                .get("generation")
                .and_then(Value::as_str),
            Some("new")
        );
    }

    #[test]
    fn publish_failpoint_restores_previous_pair_without_new_commit_marker() {
        for failpoint in [
            PublishFailpoint::AfterForecastPromotion,
            PublishFailpoint::BeforeReceiptPromotion,
        ] {
            let directory = tempfile::tempdir().unwrap();
            let forecast = directory.path().join("forecast_latest.json");
            let receipt_path = directory.path().join("receipt_latest.json");
            let old_forecast =
                serde_json::to_vec(&serde_json::json!({"generation":"old"})).unwrap();
            let old_receipt = serde_json::to_vec(&serde_json::json!({"generation":"old"})).unwrap();
            fs::write(&forecast, &old_forecast).unwrap();
            fs::write(&receipt_path, &old_receipt).unwrap();
            let forecast_staged =
                write_json_staged(&forecast, &serde_json::json!({"generation":"new"})).unwrap();
            let mut receipt = publication_receipt(&forecast);

            let error = promote_staged_forecast_pair_with_sla_and_failpoint(
                &forecast_staged,
                &forecast,
                &receipt_path,
                &mut receipt,
                Utc::now(),
                60_000,
                failpoint,
            )
            .unwrap_err();

            assert!(error.to_string().contains("PUBLISH_FAILPOINT"));
            assert_eq!(fs::read(&forecast).unwrap(), old_forecast);
            assert_eq!(fs::read(&receipt_path).unwrap(), old_receipt);
        }
    }

    #[test]
    fn target_status_round_trip_preserves_sparse_context_and_fails_closed() {
        let directory = tempfile::tempdir().unwrap();
        let cutoff = DateTime::parse_from_rfc3339("2026-07-27T13:35:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let context = ContextReadiness {
            schema_version: "point_in_time_context_readiness.v2".into(),
            cutoff,
            max_skew_ms: 5_000,
            minimum_continuous_bars: 6,
            ready: false,
            symbols: vec![crate::engine::features::ContextSymbolReadiness {
                symbol: "US.UUP".into(),
                latest_at_or_before_cutoff: Some(cutoff - Duration::minutes(1)),
                skew_ms: Some(60_000),
                expected_intervals: 6,
                observed_trade_intervals: 5,
                causally_inferred_no_trade_intervals: 0,
                unknown_missing_intervals: 1,
                continuous_bars: 5,
                ready: false,
                reasons: vec![
                    "UNKNOWN_MISSING_INTERVALS:1".into(),
                    "INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS:5/6".into(),
                    "INELIGIBLE_CONTEXT_OBSERVATION_STATE".into(),
                ],
            }],
            blockers: vec!["UUP:SPARSE_CONTEXT".into()],
        };
        persist_target_status(
            directory.path(),
            TargetStatusUpdate {
                target: "US.SPY",
                status: TargetInferenceState::WaitingForContext,
                stage: TargetInferenceStage::FeatureEngine,
                reason_code: Some("CONTEXT_NOT_READY"),
                cutoff: Some(cutoff),
                latest_input_available_at: Some(cutoff + Duration::seconds(1)),
                compute_ms: Some(7),
                end_to_end_ms: None,
                budget_ms: 5_000,
                context: Some(&context),
                forecast_committed: false,
                receipt_committed: false,
                ledger_persisted: false,
            },
        );

        let status = read_target_status(directory.path(), "SPY").unwrap();
        assert_eq!(status.model_symbol, "SPY");
        assert_eq!(status.status, TargetInferenceState::WaitingForContext);
        assert_eq!(status.stage, TargetInferenceStage::FeatureEngine);
        assert_eq!(status.reason_code.as_deref(), Some("CONTEXT_NOT_READY"));
        assert_eq!(status.compute_ms, Some(7));
        assert!(!status.forecast_committed);
        assert!(!status.receipt_committed);
        assert!(!status.ledger_persisted);
        assert!(!status.execution_enabled);
        assert_eq!(status.context_blockers.len(), 1);
        let blocker = &status.context_blockers[0];
        assert_eq!(blocker.symbol, "UUP");
        assert_eq!(
            blocker.latest_at_or_before_cutoff,
            Some(cutoff - Duration::minutes(1))
        );
        assert_eq!(blocker.skew_ms, Some(60_000));
        assert_eq!(blocker.expected_intervals, 6);
        assert_eq!(blocker.observed_trade_intervals, 5);
        assert_eq!(blocker.causally_inferred_no_trade_intervals, 0);
        assert_eq!(blocker.unknown_missing_intervals, 1);
        assert_eq!(blocker.continuous_bars, 5);
        assert_eq!(blocker.required_continuous_bars, 6);
        assert_eq!(
            blocker.reason_codes,
            [
                "UNKNOWN_MISSING_INTERVALS",
                "INSUFFICIENT_CONTIGUOUS_OBSERVED_TRADE_BARS",
                "INELIGIBLE_CONTEXT_OBSERVATION_STATE",
            ]
        );

        let path = status_path(directory.path(), "SPY");
        let mut invalid = status.clone();
        invalid.schema_version = "databento_inference_status.v1".into();
        write_json_atomic(&path, &invalid).unwrap();
        assert!(read_target_status(directory.path(), "SPY").is_none());

        invalid = status.clone();
        invalid.model_symbol = "QQQ".into();
        write_json_atomic(&path, &invalid).unwrap();
        assert!(read_target_status(directory.path(), "SPY").is_none());

        invalid = status;
        invalid.execution_enabled = true;
        write_json_atomic(&path, &invalid).unwrap();
        assert!(read_target_status(directory.path(), "SPY").is_none());
    }

    #[test]
    fn receipt_path_is_symbol_specific() {
        let root = Path::new("data");
        assert_eq!(
            receipt_path(root, "US.NVDA"),
            root.join("live/databento_inference_receipt_nvda_latest.json")
        );
        assert_ne!(receipt_path(root, "SPY"), receipt_path(root, "QQQ"));
    }

    #[test]
    fn receipt_binds_prediction_to_all_context_and_latest_availability() {
        let directory = tempfile::tempdir().unwrap();
        let envelope = valid_envelope();
        let mut context_envelope = valid_envelope();
        context_envelope.bar.symbol = "QQQ".into();
        context_envelope.received_at += Duration::seconds(1);
        context_envelope.provider_available_at += Duration::seconds(1);
        context_envelope.finalized_at += Duration::seconds(1);
        let mut available_envelopes = BTreeMap::new();
        for source in [&envelope, &context_envelope] {
            available_envelopes.insert(
                (
                    source.bar_start.timestamp_millis(),
                    source.bar.symbol.clone(),
                ),
                source.clone(),
            );
        }
        let context = ContextReadiness {
            schema_version: "point_in_time_context_readiness.v1".into(),
            cutoff: envelope.bar_start,
            max_skew_ms: 5_000,
            minimum_continuous_bars: 6,
            ready: true,
            symbols: vec![crate::engine::features::ContextSymbolReadiness {
                symbol: "QQQ".into(),
                latest_at_or_before_cutoff: Some(context_envelope.bar_start),
                skew_ms: Some(0),
                expected_intervals: 6,
                observed_trade_intervals: 6,
                causally_inferred_no_trade_intervals: 0,
                unknown_missing_intervals: 0,
                continuous_bars: 6,
                ready: true,
                reasons: Vec::new(),
            }],
            blockers: Vec::new(),
        };
        let live = LiveConfig {
            required_context_symbols: vec!["QQQ".into()],
            max_context_skew_ms: 5_000,
            stale_after_ms: 10_000,
            ..LiveConfig::default()
        };
        let source_input = source_input_evidence(
            "NVDA",
            envelope.bar_start,
            &envelope,
            &context,
            &live,
            &available_envelopes,
            &BTreeMap::new(),
        )
        .unwrap();
        assert_eq!(
            source_input.latest_input_available_at,
            context_envelope.provider_available_at
        );
        let model_hash = "a".repeat(64);
        let output = forecast_path(directory.path(), "NVDA");
        let forecast_value = serde_json::json!({
            "prediction_layer":[{
                "prediction_id":"prediction-1",
                "model_hash":model_hash
            }]
        });
        write_json_atomic(&output, &forecast_value).unwrap();
        let published_at = source_input.latest_input_available_at + Duration::milliseconds(1);
        let receipt = InferenceReceipt {
            schema_version: DATABENTO_INFERENCE_RECEIPT_SCHEMA_VERSION.into(),
            generated_at: source_input.latest_input_available_at,
            published_at,
            end_to_end_ms: 1,
            budget_ms: 5_000,
            provider: "databento".into(),
            dataset: "EQUS.MINI".into(),
            data_source: DATABENTO_FORECAST_DATA_SOURCE.into(),
            model_symbol: "NVDA".into(),
            model_hash: model_hash.clone(),
            forecast_path: output.display().to_string(),
            forecast_sha256: sha256_file(&output).unwrap(),
            prediction_ids: vec!["prediction-1".into()],
            latest_input_available_at: source_input.latest_input_available_at,
            required_context_symbols: vec!["QQQ".into()],
            max_context_skew_ms: 5_000,
            source_envelope_count: source_input.source_envelopes.len(),
            source_envelopes_sha256: source_input.source_envelopes_sha256,
            source_envelopes: source_input.source_envelopes,
            cutoff_source_envelopes: source_input.cutoff_source_envelopes,
            cutoff_context_observations: source_input.cutoff_context_observations,
            batch_id: None,
            batch_cutoff: None,
            batch_committed_at: None,
            ledger_persisted: true,
            execution_enabled: false,
        };
        write_json_atomic(&receipt_path(directory.path(), "NVDA"), &receipt).unwrap();
        let row = serde_json::json!({
            "prediction_id":"prediction-1",
            "symbol":"NVDA",
            "evidence_kind":"live_shadow_prediction",
            "data_source":DATABENTO_FORECAST_DATA_SOURCE,
            "model_hash":model_hash,
            "observation_cutoff":envelope.bar_end,
            "decision_as_of":context_envelope.provider_available_at,
            "latest_input_available_at":context_envelope.provider_available_at,
            "reference_price":envelope.bar.close
        });
        assert!(receipt_matches_forecast_row(directory.path(), &row));
        let lineage = verified_receipt_lineage(directory.path(), &row).unwrap();
        assert_eq!(
            lineage.get("forecast_sha256").and_then(Value::as_str),
            Some(receipt.forecast_sha256.as_str())
        );

        let original_forecast = fs::read(&output).unwrap();
        fs::write(&output, b"{\"prediction_layer\":[]}").unwrap();
        assert!(!receipt_matches_forecast_row(directory.path(), &row));
        fs::write(&output, original_forecast).unwrap();

        let mut wrong_model_hash = row.clone();
        wrong_model_hash["model_hash"] = serde_json::json!("c".repeat(64));
        assert!(!receipt_matches_forecast_row(
            directory.path(),
            &wrong_model_hash
        ));

        let mut backdated = row.clone();
        backdated["decision_as_of"] = serde_json::json!(envelope.provider_available_at);
        backdated["latest_input_available_at"] = serde_json::json!(envelope.provider_available_at);
        assert!(!receipt_matches_forecast_row(directory.path(), &backdated));

        let mut incomplete_receipt = receipt.clone();
        incomplete_receipt
            .cutoff_source_envelopes
            .retain(|source| !source.bar.symbol.eq_ignore_ascii_case("QQQ"));
        write_json_atomic(&receipt_path(directory.path(), "NVDA"), &incomplete_receipt).unwrap();
        assert!(!receipt_matches_forecast_row(directory.path(), &row));
        write_json_atomic(&receipt_path(directory.path(), "NVDA"), &receipt).unwrap();

        let mut wrong_cutoff = row.clone();
        wrong_cutoff["observation_cutoff"] =
            serde_json::json!(envelope.bar_end + Duration::minutes(1));
        assert!(!receipt_matches_forecast_row(
            directory.path(),
            &wrong_cutoff
        ));

        let mut wrong_source = row;
        wrong_source["data_source"] = serde_json::json!("DATABENTO:EQUS.FULL");
        assert!(!receipt_matches_forecast_row(
            directory.path(),
            &wrong_source
        ));
    }

    #[test]
    fn settlement_statistics_use_forecast_reference_not_unknown_forward_open() {
        let mut first = envelope_at(1);
        first.bar.open = 80.0;
        first.bar.high = 112.0;
        first.bar.low = 79.0;
        first.bar.close = 110.0;
        let mut second = envelope_at(2);
        second.bar.open = 110.0;
        second.bar.high = 111.0;
        second.bar.low = 109.0;
        second.bar.close = 110.0;
        let window = vec![&first, &second];

        let (exit, log_return, direction, mfe, mae, volatility) =
            realized_window_statistics(100.0, &window).unwrap();

        assert_eq!(exit, 110.0);
        assert!((log_return - 1.1_f64.ln()).abs() < 1e-12);
        assert_eq!(direction, 1);
        assert!((mfe - 0.12).abs() < 1e-12);
        assert!((mae - (-0.21)).abs() < 1e-12);
        assert!((volatility - (1.1_f64.ln() / 2.0_f64.sqrt())).abs() < 1e-12);
        assert!((log_return - (second.bar.close / first.bar.open).ln()).abs() > 0.1);
    }

    #[test]
    fn settlement_window_requires_every_exact_forward_minute() {
        let mut bars = BTreeMap::new();
        for minute in 1..=5 {
            let envelope = envelope_at(minute);
            bars.insert(
                (
                    envelope.bar_start.timestamp_millis(),
                    envelope.bar.symbol.clone(),
                ),
                envelope,
            );
        }
        let label_start = envelope_at(1).bar_start;
        let label_end = label_start + Duration::minutes(5);
        assert_eq!(
            complete_settlement_window_for("NVDA", label_start, label_end, 5, &bars).len(),
            5
        );
        bars.remove(&(
            (label_start + Duration::minutes(2)).timestamp_millis(),
            "NVDA".into(),
        ));
        assert!(
            complete_settlement_window_for("NVDA", label_start, label_end, 5, &bars).is_empty()
        );
    }
}
