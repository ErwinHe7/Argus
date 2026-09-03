use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
    sync::Arc,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
use parking_lot::Mutex;
use rusqlite::{Connection, OptionalExtension, Params, TransactionBehavior, params};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

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

#[derive(Debug, Deserialize)]
struct SettlementForecastBinding {
    prediction_id: String,
    horizon_minutes: usize,
    label_end: DateTime<Utc>,
}

/// Hash the immutable settlement outcome. Retry-local identifiers and the
/// database write clock are deliberately excluded, while every realized
/// value, source-bar identity, availability clock, cost, and evidence label is
/// bound into the digest.
pub fn settlement_content_hash(settlement: &ForecastSettlement) -> Result<String> {
    let payload = serde_json::json!({
        "prediction_id": settlement.prediction_id,
        "realized_reference_price": settlement.realized_reference_price,
        "realized_log_return": settlement.realized_log_return,
        "realized_direction": settlement.realized_direction,
        "realized_mfe": settlement.realized_mfe,
        "realized_mae": settlement.realized_mae,
        "realized_volatility": settlement.realized_volatility,
        "barrier_outcome": settlement.barrier_outcome,
        "data_status": settlement.data_status,
        "source_bar_ids": settlement.source_bar_ids,
        "settlement_available_timestamp": settlement.settlement_available_timestamp,
        "executable_entry": settlement.executable_entry,
        "executable_exit": settlement.executable_exit,
        "spread_cost": settlement.spread_cost,
        "slippage": settlement.slippage,
        "fees": settlement.fees,
        "hypothetical_pnl": settlement.hypothetical_pnl,
        "evidence_kind": settlement.evidence_kind
    });
    Ok(format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(&payload)?)
    ))
}

fn validate_optional_finite(value: Option<f64>, field: &str, require_positive: bool) -> Result<()> {
    if let Some(value) = value
        && (!value.is_finite() || (require_positive && value <= 0.0))
    {
        bail!("PREDICTION_SETTLEMENT_INVALID_{field}");
    }
    Ok(())
}

fn validate_settlement(
    settlement: &ForecastSettlement,
    forecast: &SettlementForecastBinding,
) -> Result<()> {
    if settlement.settlement_id.trim().is_empty()
        || settlement.prediction_id.trim().is_empty()
        || settlement.prediction_id != forecast.prediction_id
        || settlement.barrier_outcome.trim().is_empty()
        || settlement.data_status.trim().is_empty()
    {
        bail!("PREDICTION_SETTLEMENT_IDENTITY_INVALID");
    }
    if !matches!(
        settlement.evidence_kind.as_str(),
        "walk_forward_simulation" | "settled_forward_prediction" | "manual_settlement_observation"
    ) {
        bail!("PREDICTION_SETTLEMENT_EVIDENCE_KIND_INVALID");
    }
    if !matches!(
        settlement.data_status.as_str(),
        "COMPLETE"
            | "POINT_IN_TIME_COMPLETE"
            | "INVALID_DATA_GAP"
            | "MANUAL_SETTLEMENT"
            | "WALK_FORWARD_SIMULATION_COMPLETE"
    ) || (settlement.evidence_kind == "manual_settlement_observation"
        && settlement.data_status != "MANUAL_SETTLEMENT")
        || (settlement.evidence_kind == "walk_forward_simulation"
            && settlement.data_status != "WALK_FORWARD_SIMULATION_COMPLETE")
    {
        bail!("PREDICTION_SETTLEMENT_DATA_STATUS_INVALID");
    }
    if settlement.settled_at < settlement.settlement_available_timestamp
        || settlement.settlement_available_timestamp < forecast.label_end
    {
        bail!("PREDICTION_SETTLEMENT_CLOCK_INVALID");
    }
    if !settlement.realized_reference_price.is_finite()
        || settlement.realized_reference_price <= 0.0
        || !settlement.realized_log_return.is_finite()
        || !settlement.realized_mfe.is_finite()
        || !settlement.realized_mae.is_finite()
        || !settlement.realized_volatility.is_finite()
        || settlement.realized_volatility < 0.0
        || settlement.realized_mfe < settlement.realized_mae
        || !matches!(settlement.realized_direction, -1..=1)
        || (settlement.realized_log_return > 0.0 && settlement.realized_direction != 1)
        || (settlement.realized_log_return < 0.0 && settlement.realized_direction != -1)
        || (settlement.realized_log_return == 0.0 && settlement.realized_direction != 0)
    {
        bail!("PREDICTION_SETTLEMENT_REALIZED_VALUES_INVALID");
    }
    validate_optional_finite(settlement.executable_entry, "EXECUTABLE_ENTRY", true)?;
    validate_optional_finite(settlement.executable_exit, "EXECUTABLE_EXIT", true)?;
    validate_optional_finite(settlement.spread_cost, "SPREAD_COST", false)?;
    validate_optional_finite(settlement.slippage, "SLIPPAGE", false)?;
    validate_optional_finite(settlement.fees, "FEES", false)?;
    validate_optional_finite(settlement.hypothetical_pnl, "HYPOTHETICAL_PNL", false)?;
    if settlement.spread_cost.is_some_and(|value| value < 0.0)
        || settlement.slippage.is_some_and(|value| value < 0.0)
        || settlement.fees.is_some_and(|value| value < 0.0)
    {
        bail!("PREDICTION_SETTLEMENT_EXECUTION_COST_INVALID");
    }
    if settlement
        .source_bar_ids
        .iter()
        .any(|identifier| identifier.trim().is_empty())
    {
        bail!("PREDICTION_SETTLEMENT_SOURCE_BAR_ID_INVALID");
    }
    let unique_source_bars = settlement
        .source_bar_ids
        .iter()
        .collect::<std::collections::BTreeSet<_>>();
    if unique_source_bars.len() != settlement.source_bar_ids.len() {
        bail!("PREDICTION_SETTLEMENT_SOURCE_BAR_IDS_DUPLICATE");
    }
    if matches!(
        settlement.data_status.as_str(),
        "COMPLETE" | "POINT_IN_TIME_COMPLETE"
    ) && (settlement.evidence_kind != "settled_forward_prediction"
        || settlement.source_bar_ids.len() != forecast.horizon_minutes)
    {
        bail!("PREDICTION_SETTLEMENT_COMPLETE_SOURCE_COVERAGE_INVALID");
    }
    let expected_hash = settlement_content_hash(settlement)?;
    if settlement.settlement_hash != expected_hash {
        bail!("PREDICTION_SETTLEMENT_HASH_MISMATCH");
    }
    Ok(())
}

fn is_verified_forward_settlement(
    settlement: &ForecastSettlement,
    forecast: &SettlementForecastBinding,
) -> bool {
    settlement.evidence_kind == "settled_forward_prediction"
        && matches!(
            settlement.data_status.as_str(),
            "COMPLETE" | "POINT_IN_TIME_COMPLETE"
        )
        && validate_settlement(settlement, forecast).is_ok()
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PredictionPublicationCommit {
    pub publication_id: String,
    pub prediction_id: String,
    pub published_at: DateTime<Utc>,
    pub provider: String,
    pub forecast_sha256: String,
    pub publication_sha256: String,
    pub evidence_kind: String,
}

pub const PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION: &str = "prediction_publication_batch.v1";
pub const PREDICTION_PUBLICATION_BATCH_SYMBOL_COUNT: usize = 9;
pub const PREDICTION_PUBLICATION_BATCH_HORIZONS: [usize; 4] = [5, 15, 30, 60];
pub const PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT: usize =
    PREDICTION_PUBLICATION_BATCH_SYMBOL_COUNT * PREDICTION_PUBLICATION_BATCH_HORIZONS.len();

/// Append-only visibility marker for one complete nine-symbol Databento
/// generation. The immutable member artifacts and manifest must already exist
/// before this marker is submitted. Inserting the marker and all member
/// publication bindings in one SQLite transaction is the sole ledger
/// visibility switch for the batch.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PredictionPublicationBatchTargetSla {
    pub symbol: String,
    pub source_available_at: DateTime<Utc>,
    pub budget_ms: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PredictionPublicationBatchRequest {
    pub schema_version: String,
    pub batch_id: String,
    pub cutoff: DateTime<Utc>,
    pub symbols: Vec<String>,
    pub manifest_sha256: String,
    pub execution_disabled: bool,
    pub prediction_ids: Vec<String>,
    pub publication_ids: Vec<String>,
    pub target_slas: Vec<PredictionPublicationBatchTargetSla>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PredictionPublicationBatchCommit {
    pub schema_version: String,
    pub batch_id: String,
    pub cutoff: DateTime<Utc>,
    pub symbols: Vec<String>,
    pub manifest_sha256: String,
    pub committed_at: DateTime<Utc>,
    pub execution_disabled: bool,
    pub prediction_ids: Vec<String>,
    pub publication_ids: Vec<String>,
    pub target_slas: Vec<PredictionPublicationBatchTargetSla>,
}

pub struct PredictionLedger {
    connection: Mutex<Connection>,
}

const PREDICTION_LEDGER_SCHEMA_VERSION: i64 = 4;

fn payloads_match_except(
    existing_payload: &str,
    candidate_payload: &str,
    ignored_fields: &[&str],
) -> Result<bool> {
    if ignored_fields.is_empty() {
        return Ok(existing_payload == candidate_payload);
    }
    let normalize = |payload: &str| -> Result<Value> {
        let mut value: Value = serde_json::from_str(payload)
            .context("parse immutable ledger payload for semantic retry comparison")?;
        let object = value
            .as_object_mut()
            .context("immutable ledger payload must be a JSON object")?;
        for field in ignored_fields {
            object.remove(*field);
        }
        Ok(value)
    };
    Ok(normalize(existing_payload)? == normalize(candidate_payload)?)
}

struct CanonicalRetryPolicy<'a> {
    lookup_sql: &'a str,
    semantic_key: &'a str,
    ignored_fields: &'a [&'a str],
    conflict_code: &'a str,
}

fn insert_or_get_canonical_payload<P: Params>(
    connection: &Connection,
    insert_sql: &str,
    insert_params: P,
    payload_json: &str,
    policy: CanonicalRetryPolicy<'_>,
) -> Result<String> {
    let inserted = connection.execute(insert_sql, insert_params)?;
    if inserted == 1 {
        return Ok(payload_json.to_string());
    }
    let existing = connection
        .query_row(policy.lookup_sql, params![policy.semantic_key], |row| {
            row.get::<_, String>(0)
        })
        .with_context(|| format!("verify immutable ledger retry for {}", policy.semantic_key))?;
    if !payloads_match_except(&existing, payload_json, policy.ignored_fields)? {
        bail!(
            "{}: semantic key {} already has a different payload",
            policy.conflict_code,
            policy.semantic_key
        );
    }
    Ok(existing)
}

fn valid_sha256(value: &str) -> bool {
    valid_sha256_shape(value) && value.bytes().any(|byte| byte != b'0')
}

fn valid_sha256_shape(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn canonical_batch_symbol(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    let canonical = trimmed.trim_start_matches("US.").to_ascii_uppercase();
    (!canonical.is_empty()
        && canonical.len() <= 16
        && canonical
            .bytes()
            .all(|byte| byte.is_ascii_uppercase() || byte.is_ascii_digit()))
    .then_some(canonical)
}

fn strictly_sorted_unique(values: &[String]) -> bool {
    !values.is_empty() && values.windows(2).all(|pair| pair[0] < pair[1])
}

#[derive(Debug)]
struct PredictionBatchIdentity {
    cutoff: DateTime<Utc>,
    symbols: Vec<String>,
    members: BTreeMap<String, (String, usize)>,
}

fn validate_prediction_batch_contracts(
    trigger_cutoff: DateTime<Utc>,
    forecasts: &[ForecastContract],
) -> Result<PredictionBatchIdentity> {
    if forecasts.len() != PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT {
        bail!(
            "PREDICTION_BATCH_REQUIRES_EXACTLY_{}_PREDICTIONS",
            PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT
        );
    }
    let required_horizons = PREDICTION_PUBLICATION_BATCH_HORIZONS
        .into_iter()
        .collect::<BTreeSet<_>>();
    let mut symbol_horizons = BTreeMap::<String, BTreeSet<usize>>::new();
    let mut members = BTreeMap::new();
    for forecast in forecasts {
        let symbol =
            canonical_batch_symbol(&forecast.symbol).context("PREDICTION_BATCH_SYMBOL_INVALID")?;
        let live_shadow = forecast.evidence_kind == "live_shadow_prediction";
        let horizon_safe_batch = forecast.evidence_kind == "batch_research_prediction";
        if forecast.symbol != symbol
            || forecast.prediction_id.trim().is_empty()
            || forecast.prediction_id.trim() != forecast.prediction_id
            || forecast.observation_cutoff > trigger_cutoff
            || forecast.as_of != forecast.observation_cutoff
            || forecast.label_start != forecast.observation_cutoff
            || forecast.label_end
                != forecast.observation_cutoff
                    + chrono::Duration::minutes(forecast.horizon_minutes as i64)
            || forecast.timeframe != "1m"
            || (!live_shadow && !horizon_safe_batch)
            || (live_shadow
                && (forecast.data_source != "DATABENTO:EQUS.MINI"
                    || forecast.decision_as_of != forecast.latest_input_available_at
                    || forecast.latest_input_available_at < forecast.observation_cutoff
                    || forecast.latest_input_available_at
                        >= forecast.observation_cutoff + chrono::Duration::minutes(1)))
            || (horizon_safe_batch
                && (forecast.decision_as_of != forecast.observation_cutoff
                    || forecast.latest_input_available_at != forecast.observation_cutoff
                    || forecast.data_source.trim().is_empty()))
            || forecast.decision.eligible
            || forecast.decision.action != "NO_TRADE"
            || !required_horizons.contains(&forecast.horizon_minutes)
            || !valid_sha256(&forecast.feature_hash)
            || !valid_sha256(&forecast.model_hash)
            || !valid_sha256(&forecast.data_manifest_hash)
        {
            bail!(
                "PREDICTION_BATCH_CONTRACT_INVALID:{}",
                forecast.prediction_id
            );
        }
        if members
            .insert(
                forecast.prediction_id.clone(),
                (symbol.clone(), forecast.horizon_minutes),
            )
            .is_some()
        {
            bail!(
                "PREDICTION_BATCH_PREDICTION_ID_DUPLICATE:{}",
                forecast.prediction_id
            );
        }
        if !symbol_horizons
            .entry(symbol)
            .or_default()
            .insert(forecast.horizon_minutes)
        {
            bail!("PREDICTION_BATCH_SYMBOL_HORIZON_DUPLICATE");
        }
    }
    if symbol_horizons.len() != PREDICTION_PUBLICATION_BATCH_SYMBOL_COUNT
        || symbol_horizons
            .values()
            .any(|horizons| horizons != &required_horizons)
    {
        bail!("PREDICTION_BATCH_REQUIRES_NINE_SYMBOLS_WITH_FOUR_EXACT_HORIZONS");
    }
    Ok(PredictionBatchIdentity {
        cutoff: trigger_cutoff,
        symbols: symbol_horizons.into_keys().collect(),
        members,
    })
}

fn validate_publication(publication: &PredictionPublicationCommit) -> Result<()> {
    if publication.evidence_kind != "live_forecast_publication_commit"
        || publication.publication_id.trim().is_empty()
        || publication.publication_id.trim() != publication.publication_id
        || publication.prediction_id.trim().is_empty()
        || publication.prediction_id.trim() != publication.prediction_id
        || publication.provider.trim().is_empty()
        || publication.provider.trim() != publication.provider
        || !valid_sha256_shape(&publication.forecast_sha256)
        || !valid_sha256_shape(&publication.publication_sha256)
    {
        bail!("PREDICTION_PUBLICATION_COMMIT_INVALID");
    }
    Ok(())
}

fn validate_batch_request(request: &PredictionPublicationBatchRequest) -> Result<()> {
    let sla_symbols = request
        .target_slas
        .iter()
        .map(|sla| sla.symbol.clone())
        .collect::<Vec<_>>();
    if request.schema_version != PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION
        || request.batch_id.trim().is_empty()
        || request.batch_id.trim() != request.batch_id
        || request.batch_id.len() > 512
        || !valid_sha256(&request.manifest_sha256)
        || !request.execution_disabled
        || request.symbols.len() != PREDICTION_PUBLICATION_BATCH_SYMBOL_COUNT
        || request.prediction_ids.len() != PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT
        || request.publication_ids.len() != PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT
        || request.target_slas.len() != PREDICTION_PUBLICATION_BATCH_SYMBOL_COUNT
        || !strictly_sorted_unique(&request.symbols)
        || !strictly_sorted_unique(&request.prediction_ids)
        || !strictly_sorted_unique(&request.publication_ids)
        || !strictly_sorted_unique(&sla_symbols)
        || sla_symbols != request.symbols
        || request
            .symbols
            .iter()
            .any(|symbol| canonical_batch_symbol(symbol).as_deref() != Some(symbol.as_str()))
        || request.target_slas.iter().any(|sla| {
            sla.budget_ms <= 0
                || sla.source_available_at < request.cutoff
                || sla.source_available_at >= request.cutoff + chrono::Duration::minutes(1)
        })
    {
        bail!("PREDICTION_PUBLICATION_BATCH_REQUEST_INVALID");
    }
    Ok(())
}

fn request_from_marker(
    marker: &PredictionPublicationBatchCommit,
) -> PredictionPublicationBatchRequest {
    PredictionPublicationBatchRequest {
        schema_version: marker.schema_version.clone(),
        batch_id: marker.batch_id.clone(),
        cutoff: marker.cutoff,
        symbols: marker.symbols.clone(),
        manifest_sha256: marker.manifest_sha256.clone(),
        execution_disabled: marker.execution_disabled,
        prediction_ids: marker.prediction_ids.clone(),
        publication_ids: marker.publication_ids.clone(),
        target_slas: marker.target_slas.clone(),
    }
}

fn validate_batch_marker(marker: &PredictionPublicationBatchCommit) -> Result<()> {
    let request = request_from_marker(marker);
    validate_batch_request(&request)?;
    if marker.committed_at < marker.cutoff
        || marker.target_slas.iter().any(|sla| {
            let elapsed = marker
                .committed_at
                .signed_duration_since(sla.source_available_at)
                .num_milliseconds();
            elapsed < 0 || elapsed > sla.budget_ms
        })
    {
        bail!("PREDICTION_PUBLICATION_BATCH_MARKER_INVALID");
    }
    Ok(())
}

fn append_prediction_on(
    connection: &Connection,
    forecast: &ForecastContract,
) -> Result<ForecastContract> {
    let payload_json = serde_json::to_string(forecast)?;
    let canonical_payload = insert_or_get_canonical_payload(
        connection,
        "INSERT OR IGNORE INTO predictions (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)",
        params![
            forecast.prediction_id,
            forecast.created_at.to_rfc3339(),
            forecast.as_of.to_rfc3339(),
            forecast.symbol,
            forecast.horizon_minutes as i64,
            forecast.evidence_kind,
            forecast.feature_hash,
            forecast.model_hash,
            forecast.data_manifest_hash,
            payload_json
        ],
        &payload_json,
        CanonicalRetryPolicy {
            lookup_sql: "SELECT payload_json FROM predictions WHERE prediction_id=?1",
            semantic_key: &forecast.prediction_id,
            ignored_fields: &[
                "created_at",
                "decision_as_of",
                "latest_input_available_at",
                "earliest_executable_time",
            ],
            conflict_code: "PREDICTION_ID_COLLISION_IMMUTABLE_PAYLOAD_MISMATCH",
        },
    )?;
    serde_json::from_str(&canonical_payload)
        .context("deserialize canonical immutable prediction payload")
}

fn append_publication_on(
    connection: &Connection,
    publication: &PredictionPublicationCommit,
) -> Result<PredictionPublicationCommit> {
    validate_publication(publication)?;
    let payload_json = serde_json::to_string(publication)?;
    let canonical_payload = insert_or_get_canonical_payload(
        connection,
        "INSERT OR IGNORE INTO prediction_publications (publication_id,prediction_id,published_at,payload_json) VALUES (?1,?2,?3,?4)",
        params![
            publication.publication_id,
            publication.prediction_id,
            publication.published_at.to_rfc3339(),
            payload_json
        ],
        &payload_json,
        CanonicalRetryPolicy {
            lookup_sql: "SELECT payload_json FROM prediction_publications WHERE prediction_id=?1",
            semantic_key: &publication.prediction_id,
            ignored_fields: &[],
            conflict_code: "PREDICTION_PUBLICATION_COLLISION_IMMUTABLE_PAYLOAD_MISMATCH",
        },
    )?;
    serde_json::from_str(&canonical_payload)
        .context("deserialize canonical immutable publication payload")
}

fn load_valid_batch_marker(
    connection: &Connection,
    batch_id: &str,
) -> Result<Option<PredictionPublicationBatchCommit>> {
    let row = connection
        .query_row(
            "SELECT schema_version,cutoff,committed_at,manifest_sha256,
                    symbol_count,prediction_count,publication_count,
                    execution_disabled,payload_json
             FROM prediction_publication_batches
             WHERE batch_id=?1",
            params![batch_id],
            |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, i64>(4)?,
                    row.get::<_, i64>(5)?,
                    row.get::<_, i64>(6)?,
                    row.get::<_, i64>(7)?,
                    row.get::<_, String>(8)?,
                ))
            },
        )
        .optional()?;
    let Some((
        schema_version,
        cutoff,
        committed_at,
        manifest_sha256,
        symbol_count,
        prediction_count,
        publication_count,
        execution_disabled,
        payload,
    )) = row
    else {
        return Ok(None);
    };
    let marker: PredictionPublicationBatchCommit = serde_json::from_str(&payload)
        .context("deserialize prediction publication batch marker")?;
    validate_batch_marker(&marker)?;
    let stored_cutoff = DateTime::parse_from_rfc3339(&cutoff)
        .context("parse stored prediction publication batch cutoff")?
        .with_timezone(&Utc);
    let stored_committed_at = DateTime::parse_from_rfc3339(&committed_at)
        .context("parse stored prediction publication batch commit clock")?
        .with_timezone(&Utc);
    if marker.batch_id != batch_id
        || schema_version != marker.schema_version
        || stored_cutoff != marker.cutoff
        || stored_committed_at != marker.committed_at
        || manifest_sha256 != marker.manifest_sha256
        || symbol_count != PREDICTION_PUBLICATION_BATCH_SYMBOL_COUNT as i64
        || prediction_count != PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT as i64
        || publication_count != PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT as i64
        || execution_disabled != 1
    {
        bail!("PREDICTION_PUBLICATION_BATCH_STORAGE_BINDING_MISMATCH");
    }

    let mut statement = connection.prepare(
        "SELECT symbol,horizon_minutes,prediction_id,publication_id
         FROM prediction_publication_batch_members
         WHERE batch_id=?1
         ORDER BY prediction_id",
    )?;
    let rows = statement.query_map(params![batch_id], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, i64>(1)?,
            row.get::<_, String>(2)?,
            row.get::<_, String>(3)?,
        ))
    })?;
    let mut symbols = BTreeMap::<String, BTreeSet<usize>>::new();
    let mut prediction_ids = Vec::new();
    let mut publication_ids = Vec::new();
    for row in rows {
        let (symbol, horizon_minutes, prediction_id, publication_id) = row?;
        let horizon_minutes = usize::try_from(horizon_minutes)
            .context("prediction publication batch member horizon out of range")?;
        symbols.entry(symbol).or_default().insert(horizon_minutes);
        prediction_ids.push(prediction_id);
        publication_ids.push(publication_id);
    }
    publication_ids.sort();
    let required_horizons = PREDICTION_PUBLICATION_BATCH_HORIZONS
        .into_iter()
        .collect::<BTreeSet<_>>();
    if prediction_ids != marker.prediction_ids
        || publication_ids != marker.publication_ids
        || symbols.keys().cloned().collect::<Vec<_>>() != marker.symbols
        || symbols
            .values()
            .any(|horizons| horizons != &required_horizons)
    {
        return Ok(None);
    }
    Ok(Some(marker))
}

impl PredictionLedger {
    pub fn open(path: &Path) -> Result<Arc<Self>> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let mut connection = Connection::open(path)
            .with_context(|| format!("open prediction ledger {}", path.display()))?;
        connection.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA synchronous=FULL;
             PRAGMA foreign_keys=ON;
             PRAGMA busy_timeout=5000;",
        )?;
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        transaction.execute_batch(
            "CREATE TABLE IF NOT EXISTS predictions (
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
              CREATE TABLE IF NOT EXISTS prediction_publications (
                publication_id TEXT PRIMARY KEY,
                prediction_id TEXT NOT NULL UNIQUE REFERENCES predictions(prediction_id),
                published_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
              );
              CREATE TABLE IF NOT EXISTS prediction_publication_batches (
                batch_id TEXT PRIMARY KEY,
                schema_version TEXT NOT NULL,
                cutoff TEXT NOT NULL,
                committed_at TEXT NOT NULL,
                manifest_sha256 TEXT NOT NULL,
                symbol_count INTEGER NOT NULL CHECK(symbol_count=9),
                prediction_count INTEGER NOT NULL CHECK(prediction_count=36),
                publication_count INTEGER NOT NULL CHECK(publication_count=36),
                execution_disabled INTEGER NOT NULL CHECK(execution_disabled=1),
                payload_json TEXT NOT NULL
              );
              CREATE TABLE IF NOT EXISTS prediction_publication_batch_members (
                batch_id TEXT NOT NULL,
                symbol TEXT NOT NULL,
                horizon_minutes INTEGER NOT NULL,
                prediction_id TEXT NOT NULL UNIQUE REFERENCES predictions(prediction_id),
                publication_id TEXT NOT NULL UNIQUE REFERENCES prediction_publications(publication_id),
                PRIMARY KEY(batch_id,symbol,horizon_minutes),
                UNIQUE(batch_id,prediction_id),
                UNIQUE(batch_id,publication_id),
                FOREIGN KEY(batch_id) REFERENCES prediction_publication_batches(batch_id)
                  DEFERRABLE INITIALLY DEFERRED
              );",
        )?;
        let existing_version: i64 =
            transaction.query_row("PRAGMA user_version", [], |row| row.get(0))?;
        if existing_version > PREDICTION_LEDGER_SCHEMA_VERSION {
            bail!(
                "PREDICTION_LEDGER_MIGRATION_BLOCKED_UNSUPPORTED_FUTURE_VERSION: found {existing_version}, supported {}",
                PREDICTION_LEDGER_SCHEMA_VERSION
            );
        }
        let duplicate_prediction_groups: i64 = transaction.query_row(
            "SELECT COUNT(*) FROM (
               SELECT prediction_id
               FROM prediction_settlements
               GROUP BY prediction_id
               HAVING COUNT(*) > 1
             )",
            [],
            |row| row.get(0),
        )?;
        if duplicate_prediction_groups > 0 {
            let sample_prediction_id: String = transaction.query_row(
                "SELECT prediction_id
                 FROM prediction_settlements
                 GROUP BY prediction_id
                 HAVING COUNT(*) > 1
                 ORDER BY prediction_id
                 LIMIT 1",
                [],
                |row| row.get(0),
            )?;
            bail!(
                "PREDICTION_LEDGER_MIGRATION_BLOCKED_DUPLICATE_SETTLEMENTS: {duplicate_prediction_groups} prediction_id group(s) have multiple settlements; sample={sample_prediction_id}; original rows were preserved"
            );
        }
        transaction.execute_batch(
            "CREATE UNIQUE INDEX IF NOT EXISTS prediction_settlements_one_per_prediction
               ON prediction_settlements(prediction_id);
             CREATE TRIGGER IF NOT EXISTS predictions_no_update BEFORE UPDATE ON predictions BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
             CREATE TRIGGER IF NOT EXISTS predictions_no_delete BEFORE DELETE ON predictions BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
             CREATE TRIGGER IF NOT EXISTS settlements_no_update BEFORE UPDATE ON prediction_settlements BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
             CREATE TRIGGER IF NOT EXISTS settlements_no_delete BEFORE DELETE ON prediction_settlements BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              CREATE TRIGGER IF NOT EXISTS publications_no_update BEFORE UPDATE ON prediction_publications BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              CREATE TRIGGER IF NOT EXISTS publications_no_delete BEFORE DELETE ON prediction_publications BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              CREATE TRIGGER IF NOT EXISTS publication_batches_require_complete_members BEFORE INSERT ON prediction_publication_batches
                WHEN (SELECT COUNT(*) FROM prediction_publication_batch_members WHERE batch_id=NEW.batch_id) != 36
                  OR (SELECT COUNT(DISTINCT symbol) FROM prediction_publication_batch_members WHERE batch_id=NEW.batch_id) != 9
                  OR EXISTS (
                    SELECT 1 FROM prediction_publication_batch_members
                    WHERE batch_id=NEW.batch_id AND horizon_minutes NOT IN (5,15,30,60)
                  )
                BEGIN SELECT RAISE(ABORT, 'PREDICTION_PUBLICATION_BATCH_INCOMPLETE'); END;
              CREATE TRIGGER IF NOT EXISTS publication_batches_no_update BEFORE UPDATE ON prediction_publication_batches BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              CREATE TRIGGER IF NOT EXISTS publication_batches_no_delete BEFORE DELETE ON prediction_publication_batches BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              CREATE TRIGGER IF NOT EXISTS publication_batch_members_no_update BEFORE UPDATE ON prediction_publication_batch_members BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              CREATE TRIGGER IF NOT EXISTS publication_batch_members_no_delete BEFORE DELETE ON prediction_publication_batch_members BEGIN SELECT RAISE(ABORT, 'PREDICTION_LEDGER_APPEND_ONLY'); END;
              PRAGMA user_version=4;",
        )?;
        transaction.commit()?;
        Ok(Arc::new(Self {
            connection: Mutex::new(connection),
        }))
    }

    pub fn append_prediction(&self, forecast: &ForecastContract) -> Result<ForecastContract> {
        let connection = self.connection.lock();
        append_prediction_on(&connection, forecast)
    }

    /// Atomically append the exact 9-symbol by 4-horizon prediction attempt for
    /// an explicit live trigger cutoff. Individual horizon-safe contracts may
    /// use earlier causal cutoffs, including near the regular-session close.
    ///
    /// Canonical persisted contracts are returned in caller order. A retry may
    /// therefore return earlier issue/availability clocks under the existing
    /// semantic-retry policy, allowing immutable member hashes to be built from
    /// the authoritative ledger payloads. No publication visibility is granted
    /// by this phase.
    pub fn append_prediction_batch(
        &self,
        trigger_cutoff: DateTime<Utc>,
        forecasts: &[ForecastContract],
    ) -> Result<Vec<ForecastContract>> {
        self.append_prediction_batch_inner(trigger_cutoff, forecasts, None)
    }

    fn append_prediction_batch_inner(
        &self,
        trigger_cutoff: DateTime<Utc>,
        forecasts: &[ForecastContract],
        fail_after: Option<usize>,
    ) -> Result<Vec<ForecastContract>> {
        validate_prediction_batch_contracts(trigger_cutoff, forecasts)?;
        let mut connection = self.connection.lock();
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        let mut canonical = Vec::with_capacity(forecasts.len());
        for (index, forecast) in forecasts.iter().enumerate() {
            canonical.push(append_prediction_on(&transaction, forecast)?);
            if fail_after == Some(index + 1) {
                bail!(
                    "PREDICTION_BATCH_TEST_FAILPOINT_AFTER_{}_INSERTS",
                    index + 1
                );
            }
        }
        validate_prediction_batch_contracts(trigger_cutoff, &canonical)?;
        transaction.commit()?;
        Ok(canonical)
    }

    pub fn append_settlement(&self, settlement: &ForecastSettlement) -> Result<ForecastSettlement> {
        let payload_json = serde_json::to_string(settlement)?;
        let connection = self.connection.lock();
        let forecast_payload = connection
            .query_row(
                "SELECT payload_json FROM predictions WHERE prediction_id=?1",
                params![settlement.prediction_id],
                |row| row.get::<_, String>(0),
            )
            .with_context(|| {
                format!(
                    "PREDICTION_SETTLEMENT_FORECAST_NOT_FOUND: {}",
                    settlement.prediction_id
                )
            })?;
        let forecast: SettlementForecastBinding = serde_json::from_str(&forecast_payload)
            .context("PREDICTION_SETTLEMENT_FORECAST_PAYLOAD_INVALID")?;
        validate_settlement(settlement, &forecast)?;
        let canonical_payload = insert_or_get_canonical_payload(
            &connection,
            "INSERT OR IGNORE INTO prediction_settlements (settlement_id,prediction_id,settled_at,payload_json) VALUES (?1,?2,?3,?4)",
            params![
                settlement.settlement_id,
                settlement.prediction_id,
                settlement.settled_at.to_rfc3339(),
                payload_json
            ],
            &payload_json,
            CanonicalRetryPolicy {
                lookup_sql: "SELECT payload_json FROM prediction_settlements WHERE prediction_id=?1",
                semantic_key: &settlement.prediction_id,
                ignored_fields: &["settlement_id", "settled_at"],
                conflict_code: "SETTLEMENT_PREDICTION_ID_COLLISION_IMMUTABLE_PAYLOAD_MISMATCH",
            },
        )?;
        serde_json::from_str(&canonical_payload)
            .context("deserialize canonical immutable settlement payload")
    }

    pub fn append_publication_commit(
        &self,
        publication: &PredictionPublicationCommit,
    ) -> Result<PredictionPublicationCommit> {
        let connection = self.connection.lock();
        append_publication_on(&connection, publication)
    }

    /// Atomically bind all 36 canonical prediction attempts to their immutable
    /// member publications and insert the final all-nine batch marker.
    ///
    /// Callers must durably stage the immutable members and manifest before
    /// invoking this method. On any identity conflict, validation failure, or
    /// database error, SQLite rolls back every new publication/member/marker
    /// row and no part of the batch becomes visible.
    pub fn append_publication_batch(
        &self,
        publications: &[PredictionPublicationCommit],
        request: &PredictionPublicationBatchRequest,
    ) -> Result<PredictionPublicationBatchCommit> {
        self.append_publication_batch_inner(publications, request, None, None)
    }

    fn append_publication_batch_inner(
        &self,
        publications: &[PredictionPublicationCommit],
        request: &PredictionPublicationBatchRequest,
        fail_after: Option<usize>,
        committed_at_override: Option<DateTime<Utc>>,
    ) -> Result<PredictionPublicationBatchCommit> {
        validate_batch_request(request)?;
        if publications.len() != PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT {
            bail!(
                "PREDICTION_PUBLICATION_BATCH_REQUIRES_EXACTLY_{}_COMMITS",
                PREDICTION_PUBLICATION_BATCH_PREDICTION_COUNT
            );
        }

        let mut publication_by_prediction = BTreeMap::<String, &PredictionPublicationCommit>::new();
        let mut publication_ids = BTreeSet::new();
        for publication in publications {
            validate_publication(publication)?;
            if publication.provider != "DATABENTO"
                || !valid_sha256(&publication.forecast_sha256)
                || !valid_sha256(&publication.publication_sha256)
            {
                bail!("PREDICTION_PUBLICATION_BATCH_MEMBER_INVALID");
            }
            if publication_by_prediction
                .insert(publication.prediction_id.clone(), publication)
                .is_some()
                || !publication_ids.insert(publication.publication_id.clone())
            {
                bail!("PREDICTION_PUBLICATION_BATCH_MEMBER_ID_DUPLICATE");
            }
        }
        if publication_by_prediction
            .keys()
            .cloned()
            .collect::<Vec<_>>()
            != request.prediction_ids
            || publication_ids.into_iter().collect::<Vec<_>>() != request.publication_ids
        {
            bail!("PREDICTION_PUBLICATION_BATCH_MARKER_MEMBER_SET_MISMATCH");
        }

        let mut connection = self.connection.lock();
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        let mut forecasts = Vec::with_capacity(request.prediction_ids.len());
        for prediction_id in &request.prediction_ids {
            let payload = transaction
                .query_row(
                    "SELECT payload_json FROM predictions WHERE prediction_id=?1",
                    params![prediction_id],
                    |row| row.get::<_, String>(0),
                )
                .with_context(|| {
                    format!("PREDICTION_PUBLICATION_BATCH_PREDICTION_NOT_FOUND:{prediction_id}")
                })?;
            forecasts.push(
                serde_json::from_str::<ForecastContract>(&payload)
                    .context("PREDICTION_PUBLICATION_BATCH_PREDICTION_PAYLOAD_INVALID")?,
            );
        }
        let identity = validate_prediction_batch_contracts(request.cutoff, &forecasts)?;
        if identity.cutoff != request.cutoff
            || identity.symbols != request.symbols
            || identity.members.keys().cloned().collect::<Vec<_>>() != request.prediction_ids
        {
            bail!("PREDICTION_PUBLICATION_BATCH_PREDICTION_SET_MISMATCH");
        }

        let mut symbol_publication_hashes = BTreeMap::<String, (String, String)>::new();
        for (prediction_id, publication) in &publication_by_prediction {
            let (symbol, _) = identity
                .members
                .get(prediction_id)
                .context("PREDICTION_PUBLICATION_BATCH_MEMBER_PREDICTION_MISSING")?;
            let hashes = (
                publication.forecast_sha256.clone(),
                publication.publication_sha256.clone(),
            );
            if symbol_publication_hashes
                .insert(symbol.clone(), hashes.clone())
                .is_some_and(|existing| existing != hashes)
            {
                bail!("PREDICTION_PUBLICATION_BATCH_SYMBOL_PUBLICATION_HASH_MISMATCH");
            }
        }

        for (index, publication) in publications.iter().enumerate() {
            append_publication_on(&transaction, publication)?;
            if fail_after == Some(index + 1) {
                bail!(
                    "PREDICTION_PUBLICATION_BATCH_TEST_FAILPOINT_AFTER_{}_INSERTS",
                    index + 1
                );
            }
        }

        for prediction_id in &request.prediction_ids {
            let publication = publication_by_prediction
                .get(prediction_id)
                .context("PREDICTION_PUBLICATION_BATCH_MEMBER_COMMIT_MISSING")?;
            let (symbol, horizon_minutes) = identity
                .members
                .get(prediction_id)
                .context("PREDICTION_PUBLICATION_BATCH_MEMBER_IDENTITY_MISSING")?;
            let inserted = transaction.execute(
                "INSERT OR IGNORE INTO prediction_publication_batch_members
                 (batch_id,symbol,horizon_minutes,prediction_id,publication_id)
                 VALUES (?1,?2,?3,?4,?5)",
                params![
                    request.batch_id,
                    symbol,
                    *horizon_minutes as i64,
                    prediction_id,
                    publication.publication_id
                ],
            )?;
            if inserted == 0 {
                let existing = transaction
                    .query_row(
                        "SELECT batch_id,symbol,horizon_minutes,publication_id
                         FROM prediction_publication_batch_members
                         WHERE prediction_id=?1",
                        params![prediction_id],
                        |row| {
                            Ok((
                                row.get::<_, String>(0)?,
                                row.get::<_, String>(1)?,
                                row.get::<_, i64>(2)?,
                                row.get::<_, String>(3)?,
                            ))
                        },
                    )
                    .with_context(|| {
                        format!("PREDICTION_PUBLICATION_BATCH_MEMBER_CONFLICT:{prediction_id}")
                    })?;
                if existing
                    != (
                        request.batch_id.clone(),
                        symbol.clone(),
                        *horizon_minutes as i64,
                        publication.publication_id.clone(),
                    )
                {
                    bail!("PREDICTION_PUBLICATION_BATCH_MEMBER_CONFLICT:{prediction_id}");
                }
            }
        }

        if let Some(existing_marker_json) = transaction
            .query_row(
                "SELECT payload_json FROM prediction_publication_batches WHERE batch_id=?1",
                params![request.batch_id],
                |row| row.get::<_, String>(0),
            )
            .optional()?
        {
            let existing_marker: PredictionPublicationBatchCommit =
                serde_json::from_str(&existing_marker_json)
                    .context("deserialize canonical prediction publication batch marker")?;
            validate_batch_marker(&existing_marker)?;
            if request_from_marker(&existing_marker) != *request {
                bail!("PREDICTION_PUBLICATION_BATCH_ID_COLLISION");
            }
            transaction.commit()?;
            return Ok(existing_marker);
        }

        // This is the authoritative logical publication clock. The check is
        // intentionally inside the IMMEDIATE transaction, after all 36
        // publication/member rows have been validated, and immediately before
        // the final marker insert and COMMIT.
        let committed_at = committed_at_override.unwrap_or_else(Utc::now);
        for sla in &request.target_slas {
            let elapsed_ms = committed_at
                .signed_duration_since(sla.source_available_at)
                .num_milliseconds();
            if elapsed_ms < 0 || elapsed_ms > sla.budget_ms {
                bail!(
                    "PREDICTION_PUBLICATION_BATCH_SLA_EXCEEDED:{}:elapsed_ms={}:budget_ms={}",
                    sla.symbol,
                    elapsed_ms,
                    sla.budget_ms
                );
            }
        }
        if publications.iter().any(|publication| {
            publication.published_at < request.cutoff || publication.published_at > committed_at
        }) {
            bail!("PREDICTION_PUBLICATION_BATCH_PREPARED_CLOCK_INVALID");
        }
        let marker = PredictionPublicationBatchCommit {
            schema_version: request.schema_version.clone(),
            batch_id: request.batch_id.clone(),
            cutoff: request.cutoff,
            symbols: request.symbols.clone(),
            manifest_sha256: request.manifest_sha256.clone(),
            committed_at,
            execution_disabled: request.execution_disabled,
            prediction_ids: request.prediction_ids.clone(),
            publication_ids: request.publication_ids.clone(),
            target_slas: request.target_slas.clone(),
        };
        validate_batch_marker(&marker)?;
        let marker_json = serde_json::to_string(&marker)?;
        let canonical_marker = insert_or_get_canonical_payload(
            &transaction,
            "INSERT OR IGNORE INTO prediction_publication_batches
             (batch_id,schema_version,cutoff,committed_at,manifest_sha256,symbol_count,prediction_count,publication_count,execution_disabled,payload_json)
             VALUES (?1,?2,?3,?4,?5,9,36,36,1,?6)",
            params![
                marker.batch_id,
                marker.schema_version,
                marker.cutoff.to_rfc3339(),
                marker.committed_at.to_rfc3339(),
                marker.manifest_sha256,
                marker_json
            ],
            &marker_json,
            CanonicalRetryPolicy {
                lookup_sql:
                    "SELECT payload_json FROM prediction_publication_batches WHERE batch_id=?1",
                semantic_key: &marker.batch_id,
                ignored_fields: &[],
                conflict_code: "PREDICTION_PUBLICATION_BATCH_ID_COLLISION",
            },
        )?;
        let canonical_marker = serde_json::from_str(&canonical_marker)
            .context("deserialize canonical prediction publication batch marker")?;
        transaction.commit()?;
        Ok(canonical_marker)
    }

    /// Read a batch marker only when its stored payload and exact member counts
    /// still satisfy the all-nine contract.
    pub fn publication_batch_commit(
        &self,
        batch_id: &str,
    ) -> Result<Option<PredictionPublicationBatchCommit>> {
        let connection = self.connection.lock();
        load_valid_batch_marker(&connection, batch_id)
    }

    /// Resolve the newest authoritative all-nine marker for crash recovery.
    /// Ties are deterministic by batch ID, and the selected row is returned
    /// only after the marker payload and exact 36-member/9-symbol counts pass.
    pub fn latest_publication_batch_commit(
        &self,
    ) -> Result<Option<PredictionPublicationBatchCommit>> {
        let batch_id = self
            .connection
            .lock()
            .query_row(
                "SELECT batch_id
                 FROM prediction_publication_batches
                 ORDER BY committed_at DESC,batch_id DESC
                 LIMIT 1",
                [],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        match batch_id {
            Some(batch_id) => self.publication_batch_commit(&batch_id),
            None => Ok(None),
        }
    }

    /// Resolve the complete batch marker that makes one prediction public.
    pub fn publication_batch_commit_for_prediction(
        &self,
        prediction_id: &str,
    ) -> Result<Option<PredictionPublicationBatchCommit>> {
        let batch_id = self
            .connection
            .lock()
            .query_row(
                "SELECT batch_id FROM prediction_publication_batch_members WHERE prediction_id=?1",
                params![prediction_id],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        match batch_id {
            Some(batch_id) => self.publication_batch_commit(&batch_id),
            None => Ok(None),
        }
    }

    /// Return a prediction payload only through a fully committed all-nine
    /// marker. This is stricter than the legacy per-prediction publication
    /// reader and prevents cross-symbol partial visibility.
    pub fn batch_published_prediction_payload(
        &self,
        prediction_id: &str,
    ) -> Result<Option<serde_json::Value>> {
        let connection = self.connection.lock();
        let row = connection
            .query_row(
                "SELECT p.payload_json,b.payload_json,b.batch_id
                 FROM predictions p
                 JOIN prediction_publications c ON c.prediction_id=p.prediction_id
                 JOIN prediction_publication_batch_members m
                   ON m.prediction_id=p.prediction_id
                  AND m.publication_id=c.publication_id
                 JOIN prediction_publication_batches b ON b.batch_id=m.batch_id
                 WHERE p.prediction_id=?1",
                params![prediction_id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, String>(2)?,
                    ))
                },
            )
            .optional()?;
        let Some((prediction_payload, marker_payload, batch_id)) = row else {
            return Ok(None);
        };
        let marker: PredictionPublicationBatchCommit = serde_json::from_str(&marker_payload)
            .context("deserialize prediction publication batch marker")?;
        if load_valid_batch_marker(&connection, &batch_id)? != Some(marker) {
            return Ok(None);
        }
        Ok(Some(serde_json::from_str(&prediction_payload)?))
    }

    pub fn shadow_status(&self) -> Result<serde_json::Value> {
        let connection = self.connection.lock();
        let predictions: i64 =
            connection.query_row("SELECT COUNT(*) FROM predictions", [], |row| row.get(0))?;
        let settlements: i64 =
            connection.query_row("SELECT COUNT(*) FROM prediction_settlements", [], |row| {
                row.get(0)
            })?;
        let live_prediction_attempts: i64 = connection.query_row(
            "SELECT COUNT(*) FROM predictions WHERE json_extract(payload_json,'$.data_source') NOT LIKE '%fixture%' AND evidence_kind='live_shadow_prediction'",
            [],
            |row| row.get(0),
        )?;
        let live_predictions: i64 = connection.query_row(
            "SELECT COUNT(*)
             FROM predictions p
             JOIN prediction_publications c ON c.prediction_id=p.prediction_id
             WHERE json_extract(p.payload_json,'$.data_source') NOT LIKE '%fixture%'
               AND p.evidence_kind='live_shadow_prediction'
               AND json_extract(c.payload_json,'$.evidence_kind')='live_forecast_publication_commit'",
            [],
            |row| row.get(0),
        )?;
        let replay_predictions: i64 = connection.query_row(
            "SELECT COUNT(*) FROM predictions WHERE evidence_kind='deterministic_replay_prediction' OR json_extract(payload_json,'$.data_source') LIKE '%fixture%'",
            [],
            |row| row.get(0),
        )?;
        let mut settled_statement = connection.prepare(
            "SELECT s.payload_json,p.payload_json
             FROM prediction_settlements s
             JOIN predictions p ON p.prediction_id=s.prediction_id
             JOIN prediction_publications c ON c.prediction_id=p.prediction_id
             WHERE json_extract(p.payload_json,'$.data_source') NOT LIKE '%fixture%'
               AND p.evidence_kind='live_shadow_prediction'
               AND json_extract(s.payload_json,'$.evidence_kind')='settled_forward_prediction'
               AND json_extract(c.payload_json,'$.evidence_kind')='live_forecast_publication_commit'",
        )?;
        let settled_rows = settled_statement.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let mut settled_forward = 0_i64;
        for row in settled_rows {
            let (settlement_payload, forecast_payload) = row?;
            let Ok(settlement) = serde_json::from_str::<ForecastSettlement>(&settlement_payload)
            else {
                continue;
            };
            let Ok(forecast) = serde_json::from_str::<SettlementForecastBinding>(&forecast_payload)
            else {
                continue;
            };
            if is_verified_forward_settlement(&settlement, &forecast) {
                settled_forward += 1;
            }
        }
        let first: Option<String> = connection.query_row(
            "SELECT MIN(p.created_at)
             FROM predictions p
             JOIN prediction_publications c ON c.prediction_id=p.prediction_id
             WHERE json_extract(p.payload_json,'$.data_source') NOT LIKE '%fixture%'
               AND p.evidence_kind='live_shadow_prediction'
               AND json_extract(c.payload_json,'$.evidence_kind')='live_forecast_publication_commit'",
            [],
            |row| row.get(0),
        )?;
        Ok(serde_json::json!({
            "predictions": predictions,
            "verified_realtime_forward_predictions": live_predictions,
            "realtime_forward_prediction_attempts": live_prediction_attempts,
            "unpublished_realtime_prediction_attempts": live_prediction_attempts - live_predictions,
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

    /// Returns only issued forecasts that also have an immutable publication
    /// commit. Live settlement and promotion evidence must use this reader so
    /// an SLA- or publication-rejected attempt can never become forward
    /// evidence merely because its prediction row was appended first.
    pub fn pending_published_forecasts(&self) -> Result<Vec<ForecastContract>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT p.payload_json
             FROM predictions p
             JOIN prediction_publications c ON c.prediction_id=p.prediction_id
             LEFT JOIN prediction_settlements s ON s.prediction_id=p.prediction_id
             WHERE s.prediction_id IS NULL
               AND json_extract(c.payload_json,'$.evidence_kind')='live_forecast_publication_commit'
             ORDER BY p.as_of,p.horizon_minutes",
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

    /// Returns the immutable prediction payload only when the same prediction
    /// has a publication commit. Customer-facing live APIs use this method.
    pub fn published_prediction_payload(
        &self,
        prediction_id: &str,
    ) -> Result<Option<serde_json::Value>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT p.payload_json
             FROM predictions p
             JOIN prediction_publications c ON c.prediction_id=p.prediction_id
             WHERE p.prediction_id=?1
               AND json_extract(c.payload_json,'$.evidence_kind')='live_forecast_publication_commit'",
        )?;
        let mut rows = statement.query(params![prediction_id])?;
        let Some(row) = rows.next()? else {
            return Ok(None);
        };
        let payload = row.get::<_, String>(0)?;
        Ok(Some(serde_json::from_str(&payload)?))
    }

    pub fn publication_commit(
        &self,
        prediction_id: &str,
    ) -> Result<Option<PredictionPublicationCommit>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT payload_json
             FROM prediction_publications
             WHERE prediction_id=?1",
        )?;
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

    #[cfg(test)]
    pub fn append_raw_prediction_for_test(
        &self,
        prediction_id: &str,
        payload: &serde_json::Value,
    ) -> Result<()> {
        self.connection.lock().execute(
            "INSERT INTO predictions
             (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json)
             VALUES (?1,'2026-07-21T00:00:00Z','2026-07-21T00:00:00Z','NVDA',5,'live_shadow_prediction','f','m','d',?2)",
            params![prediction_id, serde_json::to_string(payload)?],
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone, Utc};
    use rusqlite::{Connection, params};
    use tempfile::tempdir;

    use crate::predictor::{BarrierProbabilities, DecisionPolicyResult, ForecastContract};

    use super::{
        CanonicalRetryPolicy, ForecastSettlement, PREDICTION_LEDGER_SCHEMA_VERSION,
        PREDICTION_PUBLICATION_BATCH_HORIZONS, PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION,
        PredictionLedger, PredictionPublicationBatchRequest, PredictionPublicationBatchTargetSla,
        PredictionPublicationCommit, insert_or_get_canonical_payload, settlement_content_hash,
    };

    const BATCH_SYMBOLS: [&str; 9] = [
        "AAPL", "BE", "IGV", "MU", "NBIS", "NVDA", "QQQ", "SOXX", "SPY",
    ];

    fn batch_contract(
        symbol: &str,
        horizon_minutes: usize,
        cutoff: chrono::DateTime<Utc>,
    ) -> ForecastContract {
        let source_available_at = cutoff + Duration::seconds(1);
        ForecastContract {
            prediction_id: format!("{symbol}-h{horizon_minutes:02}"),
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
            data_source: "DATABENTO:EQUS.MINI".into(),
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

    fn batch_predictions(cutoff: chrono::DateTime<Utc>) -> Vec<ForecastContract> {
        BATCH_SYMBOLS
            .iter()
            .flat_map(|symbol| {
                PREDICTION_PUBLICATION_BATCH_HORIZONS
                    .into_iter()
                    .map(move |horizon| batch_contract(symbol, horizon, cutoff))
            })
            .collect()
    }

    fn batch_publications(
        predictions: &[ForecastContract],
        prepared_at: chrono::DateTime<Utc>,
    ) -> Vec<PredictionPublicationCommit> {
        predictions
            .iter()
            .map(|prediction| PredictionPublicationCommit {
                publication_id: format!("publication-{}", prediction.prediction_id),
                prediction_id: prediction.prediction_id.clone(),
                published_at: prepared_at,
                provider: "DATABENTO".into(),
                forecast_sha256: "d".repeat(64),
                publication_sha256: "e".repeat(64),
                evidence_kind: "live_forecast_publication_commit".into(),
            })
            .collect()
    }

    fn batch_request(
        predictions: &[ForecastContract],
        publications: &[PredictionPublicationCommit],
        cutoff: chrono::DateTime<Utc>,
    ) -> PredictionPublicationBatchRequest {
        let mut prediction_ids = predictions
            .iter()
            .map(|prediction| prediction.prediction_id.clone())
            .collect::<Vec<_>>();
        prediction_ids.sort();
        let mut publication_ids = publications
            .iter()
            .map(|publication| publication.publication_id.clone())
            .collect::<Vec<_>>();
        publication_ids.sort();
        PredictionPublicationBatchRequest {
            schema_version: PREDICTION_PUBLICATION_BATCH_SCHEMA_VERSION.into(),
            batch_id: "databento-nine-symbol-20260728T1335".into(),
            cutoff,
            symbols: BATCH_SYMBOLS
                .iter()
                .map(|symbol| (*symbol).into())
                .collect(),
            manifest_sha256: "f".repeat(64),
            execution_disabled: true,
            prediction_ids,
            publication_ids,
            target_slas: BATCH_SYMBOLS
                .iter()
                .map(|symbol| PredictionPublicationBatchTargetSla {
                    symbol: (*symbol).into(),
                    source_available_at: cutoff + Duration::seconds(1),
                    budget_ms: 5_000,
                })
                .collect(),
        }
    }

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

    #[test]
    fn immutable_prediction_retry_is_idempotent_and_collision_fails_closed() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        let connection = ledger.connection.lock();
        let insert = "INSERT OR IGNORE INTO predictions (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json) VALUES (?1,'2026-07-21T00:00:00Z','2026-07-21T00:00:00Z','SPY',5,'live_shadow_prediction','f','m','d',?2)";
        let lookup = "SELECT payload_json FROM predictions WHERE prediction_id=?1";
        let first_payload = r#"{"created_at":"first","decision_as_of":"first","latest_input_available_at":"first","earliest_executable_time":"first","value":1}"#;
        let retry_payload = r#"{"created_at":"second","decision_as_of":"second","latest_input_available_at":"second","earliest_executable_time":"second","value":1}"#;
        let ignored = [
            "created_at",
            "decision_as_of",
            "latest_input_available_at",
            "earliest_executable_time",
        ];
        let canonical = insert_or_get_canonical_payload(
            &connection,
            insert,
            params!["retry-p1", first_payload],
            first_payload,
            CanonicalRetryPolicy {
                lookup_sql: lookup,
                semantic_key: "retry-p1",
                ignored_fields: &ignored,
                conflict_code: "TEST_COLLISION",
            },
        )
        .unwrap();
        assert_eq!(canonical, first_payload);
        let canonical = insert_or_get_canonical_payload(
            &connection,
            insert,
            params!["retry-p1", retry_payload],
            retry_payload,
            CanonicalRetryPolicy {
                lookup_sql: lookup,
                semantic_key: "retry-p1",
                ignored_fields: &ignored,
                conflict_code: "TEST_COLLISION",
            },
        )
        .unwrap();
        assert_eq!(canonical, first_payload);
        assert!(
            insert_or_get_canonical_payload(
                &connection,
                insert,
                params!["retry-p1", r#"{"created_at":"third","decision_as_of":"third","latest_input_available_at":"third","earliest_executable_time":"third","value":2}"#],
                r#"{"created_at":"third","decision_as_of":"third","latest_input_available_at":"third","earliest_executable_time":"third","value":2}"#,
                CanonicalRetryPolicy {
                    lookup_sql: lookup,
                    semantic_key: "retry-p1",
                    ignored_fields: &ignored,
                    conflict_code: "TEST_COLLISION",
                },
            )
            .is_err()
        );
        let count: i64 = connection
            .query_row("SELECT COUNT(*) FROM predictions", [], |row| row.get(0))
            .unwrap();
        assert_eq!(count, 1);
    }

    #[test]
    fn settlement_retry_is_idempotent_but_second_outcome_is_rejected() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        ledger.connection.lock().execute("INSERT INTO predictions (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json) VALUES ('settle-p1','2026-07-21T00:00:00Z','2026-07-21T00:00:00Z','SPY',1,'live_shadow_prediction','f','m','d','{\"prediction_id\":\"settle-p1\",\"horizon_minutes\":1,\"label_end\":\"2026-07-21T00:05:00Z\"}')",[]).unwrap();
        let settled_at = Utc.with_ymd_and_hms(2026, 7, 21, 0, 5, 0).unwrap();
        let mut settlement = ForecastSettlement {
            settlement_id: "settlement-1".into(),
            prediction_id: "settle-p1".into(),
            settled_at,
            realized_reference_price: 600.0,
            realized_log_return: 0.001,
            realized_direction: 1,
            realized_mfe: 0.002,
            realized_mae: -0.001,
            realized_volatility: 0.01,
            barrier_outcome: "UPPER_FIRST".into(),
            data_status: "POINT_IN_TIME_COMPLETE".into(),
            source_bar_ids: vec!["bar-1".into()],
            settlement_available_timestamp: settled_at,
            settlement_hash: String::new(),
            executable_entry: None,
            executable_exit: None,
            spread_cost: None,
            slippage: None,
            fees: None,
            hypothetical_pnl: None,
            evidence_kind: "settled_forward_prediction".into(),
        };
        settlement.settlement_hash = settlement_content_hash(&settlement).unwrap();
        let canonical = ledger.append_settlement(&settlement).unwrap();
        assert_eq!(canonical.settlement_id, "settlement-1");
        let mut retry = settlement.clone();
        retry.settlement_id = "retry-generated-id".into();
        retry.settled_at += chrono::Duration::seconds(1);
        let canonical = ledger.append_settlement(&retry).unwrap();
        assert_eq!(canonical.settlement_id, "settlement-1");
        assert_eq!(canonical.settled_at, settled_at);
        let count: i64 = ledger
            .connection
            .lock()
            .query_row("SELECT COUNT(*) FROM prediction_settlements", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(count, 1);

        let mut conflicting = settlement.clone();
        conflicting.settlement_id = "settlement-2".into();
        conflicting.realized_log_return = -0.01;
        assert!(ledger.append_settlement(&conflicting).is_err());

        let mut bad_hash = settlement.clone();
        bad_hash.settlement_hash = "0".repeat(64);
        assert!(ledger.append_settlement(&bad_hash).is_err());

        let mut missing_source = settlement.clone();
        missing_source.source_bar_ids.clear();
        missing_source.settlement_hash = settlement_content_hash(&missing_source).unwrap();
        assert!(ledger.append_settlement(&missing_source).is_err());

        let mut bad_clock = settlement.clone();
        bad_clock.settlement_available_timestamp += chrono::Duration::seconds(1);
        bad_clock.settlement_hash = settlement_content_hash(&bad_clock).unwrap();
        assert!(ledger.append_settlement(&bad_clock).is_err());
    }

    #[test]
    fn unpublished_prediction_is_not_customer_visible_until_immutable_commit() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        ledger.connection.lock().execute("INSERT INTO predictions (prediction_id,created_at,as_of,symbol,horizon_minutes,evidence_kind,feature_hash,model_hash,data_manifest_hash,payload_json) VALUES ('publish-p1','2026-07-21T00:00:00Z','2026-07-21T00:00:00Z','SPY',5,'live_shadow_prediction','f','m','d','{\"prediction_id\":\"publish-p1\",\"data_source\":\"DATABENTO:EQUS.MINI\"}')",[]).unwrap();

        assert!(
            ledger
                .published_prediction_payload("publish-p1")
                .unwrap()
                .is_none()
        );
        let status = ledger.shadow_status().unwrap();
        assert_eq!(
            status["verified_realtime_forward_predictions"].as_i64(),
            Some(0)
        );
        assert_eq!(
            status["unpublished_realtime_prediction_attempts"].as_i64(),
            Some(1)
        );

        let commit = PredictionPublicationCommit {
            publication_id: "publication-1".into(),
            prediction_id: "publish-p1".into(),
            published_at: Utc.with_ymd_and_hms(2026, 7, 21, 0, 0, 1).unwrap(),
            provider: "DATABENTO".into(),
            forecast_sha256: "a".repeat(64),
            publication_sha256: "b".repeat(64),
            evidence_kind: "live_forecast_publication_commit".into(),
        };
        assert_eq!(ledger.append_publication_commit(&commit).unwrap(), commit);
        assert_eq!(ledger.append_publication_commit(&commit).unwrap(), commit);
        assert_eq!(
            ledger.published_prediction_payload("publish-p1").unwrap(),
            Some(serde_json::json!({
                "prediction_id":"publish-p1",
                "data_source":"DATABENTO:EQUS.MINI"
            }))
        );
        let status = ledger.shadow_status().unwrap();
        assert_eq!(
            status["verified_realtime_forward_predictions"].as_i64(),
            Some(1)
        );
        assert_eq!(
            status["unpublished_realtime_prediction_attempts"].as_i64(),
            Some(0)
        );

        let mut conflict = commit;
        conflict.publication_sha256 = "c".repeat(64);
        assert!(ledger.append_publication_commit(&conflict).is_err());
        assert!(
            ledger
                .connection
                .lock()
                .execute(
                    "DELETE FROM prediction_publications WHERE prediction_id=?1",
                    params!["publish-p1"]
                )
                .is_err()
        );
    }

    #[test]
    fn all_nine_publication_batch_is_atomic_visible_and_idempotent() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 28, 13, 35, 0).unwrap();
        let predictions = batch_predictions(cutoff);
        let canonical = ledger
            .append_prediction_batch(cutoff, &predictions)
            .unwrap();
        assert_eq!(canonical, predictions);
        assert!(
            ledger
                .batch_published_prediction_payload(&predictions[0].prediction_id)
                .unwrap()
                .is_none(),
            "prediction attempts alone must remain non-public"
        );

        let publications = batch_publications(&canonical, cutoff + Duration::seconds(1));
        let request = batch_request(&canonical, &publications, cutoff);
        let committed_at = cutoff + Duration::seconds(2);
        let marker = ledger
            .append_publication_batch_inner(&publications, &request, None, Some(committed_at))
            .unwrap();
        assert_eq!(marker.committed_at, committed_at);
        assert!(marker.execution_disabled);
        assert_eq!(marker.symbols, request.symbols);
        assert_eq!(
            ledger.publication_batch_commit(&request.batch_id).unwrap(),
            Some(marker.clone())
        );
        assert_eq!(
            ledger.latest_publication_batch_commit().unwrap(),
            Some(marker.clone())
        );
        assert_eq!(
            ledger
                .publication_batch_commit_for_prediction(&predictions[35].prediction_id)
                .unwrap(),
            Some(marker.clone())
        );
        assert_eq!(
            ledger
                .batch_published_prediction_payload(&predictions[0].prediction_id)
                .unwrap(),
            Some(serde_json::to_value(&predictions[0]).unwrap())
        );

        let connection = ledger.connection.lock();
        for (table, expected) in [
            ("predictions", 36_i64),
            ("prediction_publications", 36),
            ("prediction_publication_batch_members", 36),
            ("prediction_publication_batches", 1),
        ] {
            let count: i64 = connection
                .query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |row| {
                    row.get(0)
                })
                .unwrap();
            assert_eq!(count, expected, "unexpected row count for {table}");
        }
        assert!(
            connection
                .execute(
                    "UPDATE prediction_publication_batches
                     SET manifest_sha256='tampered'
                     WHERE batch_id=?1",
                    params![request.batch_id]
                )
                .is_err()
        );
        assert!(
            connection
                .execute(
                    "DELETE FROM prediction_publication_batch_members
                     WHERE prediction_id=?1",
                    params![predictions[0].prediction_id]
                )
                .is_err()
        );
        drop(connection);

        // A canonical retry is accepted even after the original SLA deadline:
        // it does not create a new publication or rewrite committed_at.
        let retry = ledger
            .append_publication_batch_inner(
                &publications,
                &request,
                None,
                Some(cutoff + Duration::seconds(30)),
            )
            .unwrap();
        assert_eq!(retry, marker);
    }

    #[test]
    fn prediction_batch_failpoint_and_late_collision_roll_back_every_new_attempt() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 28, 13, 35, 0).unwrap();
        let predictions = batch_predictions(cutoff);

        assert!(
            ledger
                .append_prediction_batch_inner(cutoff, &predictions, Some(17))
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_BATCH_TEST_FAILPOINT")
        );
        let count: i64 = ledger
            .connection
            .lock()
            .query_row("SELECT COUNT(*) FROM predictions", [], |row| row.get(0))
            .unwrap();
        assert_eq!(count, 0);

        let mut conflicting = predictions.last().unwrap().clone();
        conflicting.expected_return = 0.25;
        ledger.append_prediction(&conflicting).unwrap();
        assert!(
            ledger
                .append_prediction_batch(cutoff, &predictions)
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_ID_COLLISION_IMMUTABLE_PAYLOAD_MISMATCH")
        );
        let count: i64 = ledger
            .connection
            .lock()
            .query_row("SELECT COUNT(*) FROM predictions", [], |row| row.get(0))
            .unwrap();
        assert_eq!(
            count, 1,
            "the 35 inserts preceding the last-row conflict must roll back"
        );
    }

    #[test]
    fn publication_batch_failpoint_conflict_and_sla_miss_never_publish_partially() {
        let directory = tempdir().unwrap();
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 28, 13, 35, 0).unwrap();

        let failpoint_path = directory.path().join("failpoint.sqlite3");
        let failpoint_ledger = PredictionLedger::open(&failpoint_path).unwrap();
        let predictions = batch_predictions(cutoff);
        let canonical = failpoint_ledger
            .append_prediction_batch(cutoff, &predictions)
            .unwrap();
        let publications = batch_publications(&canonical, cutoff + Duration::seconds(1));
        let request = batch_request(&canonical, &publications, cutoff);
        assert!(
            failpoint_ledger
                .append_publication_batch_inner(
                    &publications,
                    &request,
                    Some(17),
                    Some(cutoff + Duration::seconds(2)),
                )
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_PUBLICATION_BATCH_TEST_FAILPOINT")
        );
        {
            let connection = failpoint_ledger.connection.lock();
            for table in [
                "prediction_publications",
                "prediction_publication_batch_members",
                "prediction_publication_batches",
            ] {
                let count: i64 = connection
                    .query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |row| {
                        row.get(0)
                    })
                    .unwrap();
                assert_eq!(count, 0, "{table} retained a failpoint partial");
            }
        }

        assert!(
            failpoint_ledger
                .append_publication_batch_inner(
                    &publications,
                    &request,
                    None,
                    Some(cutoff + Duration::seconds(7)),
                )
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_PUBLICATION_BATCH_SLA_EXCEEDED")
        );
        let publication_count: i64 = failpoint_ledger
            .connection
            .lock()
            .query_row("SELECT COUNT(*) FROM prediction_publications", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(publication_count, 0);

        let conflict_path = directory.path().join("conflict.sqlite3");
        let conflict_ledger = PredictionLedger::open(&conflict_path).unwrap();
        let canonical = conflict_ledger
            .append_prediction_batch(cutoff, &predictions)
            .unwrap();
        let publications = batch_publications(&canonical, cutoff + Duration::seconds(1));
        let request = batch_request(&canonical, &publications, cutoff);
        let mut conflicting = publications.last().unwrap().clone();
        conflicting.publication_sha256 = "1".repeat(64);
        conflict_ledger
            .append_publication_commit(&conflicting)
            .unwrap();
        assert!(
            conflict_ledger
                .append_publication_batch_inner(
                    &publications,
                    &request,
                    None,
                    Some(cutoff + Duration::seconds(2)),
                )
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_PUBLICATION_COLLISION")
        );
        let connection = conflict_ledger.connection.lock();
        let publication_count: i64 = connection
            .query_row("SELECT COUNT(*) FROM prediction_publications", [], |row| {
                row.get(0)
            })
            .unwrap();
        let member_count: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM prediction_publication_batch_members",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let marker_count: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM prediction_publication_batches",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(publication_count, 1);
        assert_eq!(member_count, 0);
        assert_eq!(marker_count, 0);
    }

    #[test]
    fn batch_shape_and_execution_contract_fail_closed_before_writes() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 28, 13, 35, 0).unwrap();
        let predictions = batch_predictions(cutoff);
        assert!(
            ledger
                .append_prediction_batch(cutoff, &predictions[..35])
                .is_err()
        );
        let prediction_count: i64 = ledger
            .connection
            .lock()
            .query_row("SELECT COUNT(*) FROM predictions", [], |row| row.get(0))
            .unwrap();
        assert_eq!(prediction_count, 0);

        let canonical = ledger
            .append_prediction_batch(cutoff, &predictions)
            .unwrap();
        let publications = batch_publications(&canonical, cutoff + Duration::seconds(1));
        let mut wrong_provider = publications.clone();
        wrong_provider[0].provider = "databento".into();
        assert!(
            ledger
                .append_publication_batch_inner(
                    &wrong_provider,
                    &batch_request(&canonical, &wrong_provider, cutoff),
                    None,
                    Some(cutoff + Duration::seconds(2)),
                )
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_PUBLICATION_BATCH_MEMBER_INVALID")
        );
        let mut request = batch_request(&canonical, &publications, cutoff);
        request.execution_disabled = false;
        assert!(
            ledger
                .append_publication_batch_inner(
                    &publications,
                    &request,
                    None,
                    Some(cutoff + Duration::seconds(2)),
                )
                .unwrap_err()
                .to_string()
                .contains("PREDICTION_PUBLICATION_BATCH_REQUEST_INVALID")
        );
        let publication_count: i64 = ledger
            .connection
            .lock()
            .query_row("SELECT COUNT(*) FROM prediction_publications", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(publication_count, 0);
    }

    #[test]
    fn session_safe_horizons_may_precede_the_explicit_trigger_cutoff() {
        let directory = tempdir().unwrap();
        let ledger = PredictionLedger::open(&directory.path().join("predictions.sqlite3")).unwrap();
        let trigger_cutoff = Utc.with_ymd_and_hms(2026, 7, 28, 19, 56, 0).unwrap();
        let mut predictions = batch_predictions(trigger_cutoff - Duration::minutes(1));
        for prediction in &mut predictions {
            prediction.evidence_kind = "batch_research_prediction".into();
            prediction.data_source = "POINT_IN_TIME_HISTORICAL_VENDOR_AGGREGATES".into();
            prediction.decision_as_of = prediction.observation_cutoff;
            prediction.latest_input_available_at = prediction.observation_cutoff;
            prediction.earliest_executable_time = prediction.observation_cutoff;
        }
        assert!(
            predictions
                .iter()
                .all(|prediction| prediction.observation_cutoff < trigger_cutoff)
        );
        let canonical = ledger
            .append_prediction_batch(trigger_cutoff, &predictions)
            .unwrap();
        assert_eq!(canonical, predictions);
    }

    fn create_legacy_ledger(path: &std::path::Path, duplicate_settlement: bool) {
        let connection = Connection::open(path).unwrap();
        connection
            .execute_batch(
                r#"CREATE TABLE predictions (
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
                 CREATE TABLE prediction_settlements (
                   settlement_id TEXT PRIMARY KEY,
                   prediction_id TEXT NOT NULL REFERENCES predictions(prediction_id),
                   settled_at TEXT NOT NULL,
                   payload_json TEXT NOT NULL
                 );
                 INSERT INTO predictions VALUES
                   ('legacy-p1','2026-07-21T00:00:00Z','2026-07-21T00:00:00Z','SPY',5,'live_shadow_prediction','f','m','d','{}');
                 INSERT INTO prediction_settlements VALUES
                   ('legacy-s1','legacy-p1','2026-07-21T00:05:00Z','{"settlement_id":"legacy-s1"}');"#,
            )
            .unwrap();
        if duplicate_settlement {
            connection
                .execute(
                    "INSERT INTO prediction_settlements VALUES
                       ('legacy-s2','legacy-p1','2026-07-21T00:05:01Z','{\"settlement_id\":\"legacy-s2\"}')",
                    [],
                )
                .unwrap();
        }
    }

    #[test]
    fn clean_legacy_database_migrates_to_current_version_without_changing_rows() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("legacy-clean.sqlite3");
        create_legacy_ledger(&path, false);

        let ledger = PredictionLedger::open(&path).unwrap();
        let connection = ledger.connection.lock();
        let version: i64 = connection
            .query_row("PRAGMA user_version", [], |row| row.get(0))
            .unwrap();
        let rows: i64 = connection
            .query_row("SELECT COUNT(*) FROM prediction_settlements", [], |row| {
                row.get(0)
            })
            .unwrap();
        let unique_index: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type='index' AND name='prediction_settlements_one_per_prediction'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let publication_table: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type='table' AND name='prediction_publications'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let publication_batch_tables: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type='table'
                   AND name IN (
                     'prediction_publication_batches',
                     'prediction_publication_batch_members'
                   )",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(version, PREDICTION_LEDGER_SCHEMA_VERSION);
        assert_eq!(rows, 1);
        assert_eq!(unique_index, 1);
        assert_eq!(publication_table, 1);
        assert_eq!(publication_batch_tables, 2);
    }

    #[test]
    fn duplicate_legacy_settlements_block_migration_and_preserve_original_rows() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("legacy-duplicate.sqlite3");
        create_legacy_ledger(&path, true);

        let error = match PredictionLedger::open(&path) {
            Ok(_) => panic!("duplicate legacy settlement migration must fail closed"),
            Err(error) => error,
        };
        assert!(
            format!("{error:#}")
                .contains("PREDICTION_LEDGER_MIGRATION_BLOCKED_DUPLICATE_SETTLEMENTS")
        );
        let connection = Connection::open(&path).unwrap();
        let rows: i64 = connection
            .query_row("SELECT COUNT(*) FROM prediction_settlements", [], |row| {
                row.get(0)
            })
            .unwrap();
        let version: i64 = connection
            .query_row("PRAGMA user_version", [], |row| row.get(0))
            .unwrap();
        let unique_index: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type='index' AND name='prediction_settlements_one_per_prediction'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(rows, 2);
        assert_eq!(version, 0);
        assert_eq!(unique_index, 0);
    }
}
