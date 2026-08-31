//! Owner-only forecast relay for a loopback Moomoo OpenD runtime.
//!
//! The local Rust runtime remains the inference authority. This module accepts
//! only already-labelled, no-execution shadow or deterministic-replay bundles,
//! verifies their exact symbol/model contract, and atomically stores a copy for
//! the administrator UI. It does not grant public redistribution rights.

use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
    sync::{Mutex, OnceLock},
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::predictor::{
    ForecastBundle, ForecastContract, MOOMOO_LIVE_AVAILABILITY_SEMANTICS,
    MOOMOO_REPLAY_AVAILABILITY_SEMANTICS, MOOMOO_REPLAY_DATA_CAPABILITY,
};

pub const RECEIPT_SCHEMA_VERSION: &str = "axio.moomoo-owner-forecast-receipt.v1";
pub const SOURCE_PREFIX: &str = "MOOMOO_OPEND:moomoo-opend-";

static WRITE_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum OwnerForecastMode {
    LiveForwardShadow,
    DeterministicReplay,
}

#[derive(Debug, Clone)]
pub struct OwnerForecastPolicy {
    pub allowed_model_hashes: BTreeMap<String, String>,
    pub allowed_horizons: BTreeSet<usize>,
    pub maximum_live_age_seconds: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OwnerForecastReceipt {
    pub schema_version: String,
    pub status: String,
    pub provider: String,
    pub symbol: String,
    pub mode: OwnerForecastMode,
    pub received_at: DateTime<Utc>,
    pub generated_at: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub prediction_count: usize,
    pub forecast_contract_version: String,
    pub model_hash: String,
    pub payload_sha256: String,
    pub owner_only: bool,
    pub public_redistribution_authorized: bool,
    pub execution_enabled: bool,
    pub probability_publication_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredOwnerForecast {
    pub receipt: OwnerForecastReceipt,
    pub forecast: ForecastBundle,
}

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn serialized_sha256<T: Serialize>(value: &T) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

/// Compute the hash that validation will observe after the pretty JSON owner
/// forecast has been read back from disk. Some legacy serde_json float parsing
/// can move an IEEE-754 value by one ULP during that read, so hashing the
/// pre-write in-memory value would reject an otherwise unchanged stored file.
fn persisted_decoded_sha256<T>(value: &T) -> Result<String>
where
    T: Serialize + DeserializeOwned,
{
    let encoded = serde_json::to_vec_pretty(value)?;
    let decoded: T = serde_json::from_slice(&encoded)?;
    serialized_sha256(&decoded)
}

fn canonical_symbol(value: &str) -> Result<String> {
    let symbol = value
        .trim()
        .strip_prefix("US.")
        .unwrap_or(value.trim())
        .to_ascii_uppercase();
    if symbol.is_empty()
        || symbol.len() > 16
        || !symbol.chars().all(|value| value.is_ascii_alphanumeric())
    {
        bail!("invalid Moomoo owner forecast symbol");
    }
    Ok(symbol)
}

fn row_mode(row: &ForecastContract) -> Result<OwnerForecastMode> {
    match row.evidence_kind.as_str() {
        "live_shadow_prediction" if row.evidence_grade == "FORWARD_SHADOW" => {
            Ok(OwnerForecastMode::LiveForwardShadow)
        }
        "deterministic_replay_prediction" if row.evidence_grade == "DETERMINISTIC_REPLAY" => {
            Ok(OwnerForecastMode::DeterministicReplay)
        }
        _ => bail!("unsupported Moomoo owner forecast evidence kind"),
    }
}

fn expected_mode_metadata(mode: OwnerForecastMode) -> (&'static str, &'static str) {
    match mode {
        OwnerForecastMode::LiveForwardShadow => {
            (MOOMOO_LIVE_AVAILABILITY_SEMANTICS, "D1_REALTIME_UNDERLYING")
        }
        OwnerForecastMode::DeterministicReplay => (
            MOOMOO_REPLAY_AVAILABILITY_SEMANTICS,
            MOOMOO_REPLAY_DATA_CAPABILITY,
        ),
    }
}

fn calibration_runtime_is_withheld(
    runtime: &crate::probability_calibration::ProbabilityCalibrationRuntime,
) -> bool {
    !runtime.eligible_for_probability_use
        && runtime.calibrated_probability_up.is_none()
        && runtime.calibrated_probability_up_interval.is_none()
        && runtime.oos_metrics.is_none()
}

pub fn validate_owner_forecast(
    bundle: &ForecastBundle,
    received_at: DateTime<Utc>,
    policy: &OwnerForecastPolicy,
) -> Result<OwnerForecastReceipt> {
    if !matches!(
        bundle.forecast_contract_version.as_str(),
        "4.1" | "4.2" | "4.3" | "4.4"
    ) {
        bail!("unsupported Moomoo owner forecast contract version");
    }
    if bundle.prediction_layer.is_empty() || bundle.prediction_layer.len() > 16 {
        bail!("Moomoo owner forecast prediction coverage is invalid");
    }
    if policy.allowed_horizons.is_empty() || policy.maximum_live_age_seconds <= 0 {
        bail!("Moomoo owner forecast policy is invalid");
    }
    if bundle.research_only_policy.product_scope != "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH"
        || bundle.research_only_policy.personalization_used
        || bundle.research_only_policy.user_portfolio_inputs_used
        || bundle.research_only_policy.investment_advice
        || bundle.research_only_policy.execution_instruction
    {
        bail!("Moomoo owner forecast research-only policy is invalid");
    }
    if bundle.generated_at > received_at + chrono::Duration::seconds(5) {
        bail!("Moomoo owner forecast generation time is in the future");
    }

    let symbol = canonical_symbol(&bundle.prediction_layer[0].symbol)?;
    let expected_model_hash = policy
        .allowed_model_hashes
        .get(&symbol)
        .context("exact-symbol frozen model is not allow-listed")?;
    let mode = row_mode(&bundle.prediction_layer[0])?;
    let mut horizons = BTreeSet::new();
    let mut observation_cutoff = bundle.prediction_layer[0].observation_cutoff;
    for row in &bundle.prediction_layer {
        if canonical_symbol(&row.symbol)? != symbol {
            bail!("Moomoo owner forecast mixes symbols");
        }
        let current_mode = row_mode(row)?;
        if current_mode != mode {
            bail!("Moomoo owner forecast mixes live and replay evidence");
        }
        let (expected_availability, expected_capability) = expected_mode_metadata(current_mode);
        if row.availability_semantics != expected_availability
            || row.data_capability_level != expected_capability
        {
            bail!("Moomoo owner forecast mode metadata is inconsistent");
        }
        if !policy.allowed_horizons.contains(&row.horizon_minutes)
            || !horizons.insert(row.horizon_minutes)
        {
            bail!("Moomoo owner forecast has unsupported or duplicate horizons");
        }
        if row.timeframe != "1m"
            || !row.data_source.starts_with(SOURCE_PREFIX)
            || row.data_source.to_ascii_lowercase().contains("fixture")
        {
            bail!("Moomoo owner forecast source is not the pinned official OpenD bridge");
        }
        if row.model_hash != *expected_model_hash
            || !valid_nonzero_sha256(&row.model_hash)
            || !valid_nonzero_sha256(&row.feature_hash)
            || !valid_nonzero_sha256(&row.data_manifest_hash)
        {
            bail!("Moomoo owner forecast model or lineage hash mismatch");
        }
        if row.as_of != row.observation_cutoff
            || row.label_start != row.observation_cutoff
            || row.label_end
                != row.observation_cutoff + chrono::Duration::minutes(row.horizon_minutes as i64)
            || row.latest_input_available_at != row.decision_as_of
            || row.latest_input_available_at < row.observation_cutoff
            || row.latest_input_available_at
                >= row.observation_cutoff + chrono::Duration::minutes(1)
        {
            bail!("Moomoo owner forecast clocks are non-causal or misaligned");
        }
        if row.decision.eligible
            || row.decision.action != "NO_TRADE"
            || row.probability_calibration.eligible_for_probability_use
            || !calibration_runtime_is_withheld(&row.probability_calibration)
            || row.calibrated_probability_up.is_some()
            || row.strategy_win_probability.is_some()
            || row.p_up.is_some()
            || row.p_down.is_some()
            || row.p_flat.is_some()
        {
            bail!(
                "Moomoo owner forecast attempts to publish an unpromoted decision or probability"
            );
        }
        observation_cutoff = observation_cutoff.max(row.observation_cutoff);
    }

    if mode == OwnerForecastMode::LiveForwardShadow {
        let age = received_at
            .signed_duration_since(observation_cutoff)
            .num_seconds();
        if age < 0 || age > policy.maximum_live_age_seconds {
            bail!("Moomoo owner live forecast is stale or future-dated");
        }
    }

    Ok(OwnerForecastReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION.into(),
        status: match mode {
            OwnerForecastMode::LiveForwardShadow => "OWNER_LIVE_FORWARD_SHADOW_READY",
            OwnerForecastMode::DeterministicReplay => "OWNER_HISTORICAL_REPLAY_READY",
        }
        .into(),
        provider: "MOOMOO_OPEND".into(),
        symbol,
        mode,
        received_at,
        generated_at: bundle.generated_at,
        observation_cutoff,
        prediction_count: bundle.prediction_layer.len(),
        forecast_contract_version: bundle.forecast_contract_version.clone(),
        model_hash: expected_model_hash.clone(),
        payload_sha256: serialized_sha256(bundle)?,
        owner_only: true,
        public_redistribution_authorized: false,
        execution_enabled: false,
        probability_publication_status: "WITHHELD_UNPROMOTED_OOS_CALIBRATION".into(),
    })
}

fn preview_filename(symbol: &str) -> String {
    format!("owner_forecast_{}_latest.json", symbol.to_ascii_lowercase())
}

fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    let parent = path.parent().unwrap_or(Path::new("."));
    fs::create_dir_all(parent)?;
    let temporary = parent.join(format!(
        ".{}.{}.tmp",
        path.file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("owner-forecast"),
        Uuid::new_v4()
    ));
    fs::write(&temporary, bytes)
        .with_context(|| format!("write temporary owner forecast {}", temporary.display()))?;
    if let Err(error) = fs::rename(&temporary, path) {
        let _ = fs::remove_file(&temporary);
        return Err(error).with_context(|| format!("publish owner forecast {}", path.display()));
    }
    Ok(())
}

pub fn persist_owner_forecast(
    data_root: &Path,
    bundle: ForecastBundle,
    mut receipt: OwnerForecastReceipt,
) -> Result<OwnerForecastReceipt> {
    let _guard = WRITE_LOCK
        .get_or_init(|| Mutex::new(()))
        .lock()
        .map_err(|_| anyhow::anyhow!("Moomoo owner forecast writer lock poisoned"))?;
    let reports = data_root.join("reports");
    let live = data_root.join("live");
    fs::create_dir_all(&reports)?;
    fs::create_dir_all(&live)?;
    receipt.payload_sha256 = persisted_decoded_sha256(&bundle)?;
    let stored = StoredOwnerForecast {
        receipt: receipt.clone(),
        forecast: bundle,
    };
    atomic_write(
        &reports.join(preview_filename(&receipt.symbol)),
        &serde_json::to_vec_pretty(&stored)?,
    )?;
    atomic_write(
        &live.join("moomoo_owner_forecast_status.json"),
        &serde_json::to_vec_pretty(&receipt)?,
    )?;
    Ok(receipt)
}

pub fn read_owner_forecast(data_root: &Path, symbol: &str) -> Result<Option<StoredOwnerForecast>> {
    let symbol = canonical_symbol(symbol)?;
    let path = data_root.join("reports").join(preview_filename(&symbol));
    if !path.exists() {
        return Ok(None);
    }
    let bytes = fs::read(&path)
        .with_context(|| format!("read Moomoo owner forecast {}", path.display()))?;
    let stored: StoredOwnerForecast = serde_json::from_slice(&bytes)
        .with_context(|| format!("deserialize Moomoo owner forecast {}", path.display()))?;
    if stored.receipt.symbol != symbol {
        bail!("stored Moomoo owner forecast symbol mismatch");
    }
    Ok(Some(stored))
}

pub fn read_status(data_root: &Path) -> Result<Option<OwnerForecastReceipt>> {
    let path = data_root
        .join("live")
        .join("moomoo_owner_forecast_status.json");
    if !path.exists() {
        return Ok(None);
    }
    Ok(Some(serde_json::from_slice(&fs::read(path)?)?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::probability_calibration::ProbabilityCalibrationRuntime;

    #[test]
    fn nested_calibrated_probability_must_be_fully_withheld() {
        let mut runtime = ProbabilityCalibrationRuntime::default();
        assert!(calibration_runtime_is_withheld(&runtime));
        runtime.calibrated_probability_up = Some(0.55);
        assert!(!calibration_runtime_is_withheld(&runtime));
        runtime = ProbabilityCalibrationRuntime::default();
        runtime.eligible_for_probability_use = true;
        assert!(!calibration_runtime_is_withheld(&runtime));
    }

    #[test]
    fn live_and_replay_require_distinct_capability_metadata() {
        assert_eq!(
            expected_mode_metadata(OwnerForecastMode::LiveForwardShadow),
            (MOOMOO_LIVE_AVAILABILITY_SEMANTICS, "D1_REALTIME_UNDERLYING")
        );
        assert_eq!(
            expected_mode_metadata(OwnerForecastMode::DeterministicReplay),
            (
                MOOMOO_REPLAY_AVAILABILITY_SEMANTICS,
                MOOMOO_REPLAY_DATA_CAPABILITY
            )
        );
    }

    #[test]
    fn owner_payload_receipt_matches_the_persisted_decode() {
        #[derive(Debug, Serialize, Deserialize)]
        struct FloatPayload {
            filtered_state_probabilities: Vec<f64>,
        }

        let payload = FloatPayload {
            // This production value exposed the one-ULP parser drift that made
            // an unchanged persisted owner forecast fail its SHA-256 receipt.
            filtered_state_probabilities: vec![5.530_432_456_843_088_4e-14],
        };
        let expected = persisted_decoded_sha256(&payload).unwrap();
        let persisted = serde_json::to_vec_pretty(&payload).unwrap();
        let restored: FloatPayload = serde_json::from_slice(&persisted).unwrap();
        assert_eq!(serialized_sha256(&restored).unwrap(), expected);
    }
}
