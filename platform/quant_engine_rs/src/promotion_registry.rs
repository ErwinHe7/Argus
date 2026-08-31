//! Immutable, independently pinned promotion records for the live model universe.
//!
//! A registry-level SHA-256 protects the complete file and an externally supplied
//! SHA-256 protects every canonical `(symbol, model_hash)` entry.  The entry also
//! binds an immutable model artifact and untouched forward-shadow evidence.  A
//! legacy single-record registry is detectable for diagnostics and migration,
//! but it is never accepted by the serving gate.

use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs,
    path::{Component, Path, PathBuf},
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

pub const MODEL_PROMOTION_REGISTRY_SCHEMA_VERSION: &str = "axio.model-promotion-registry.v2";
pub const FORWARD_SHADOW_EVIDENCE_SCHEMA_VERSION: &str =
    "axio.forward-shadow-promotion-evidence.v2";
pub const MODEL_PROMOTION_REGISTRY_FILENAME: &str = "models/predictor_promotion_latest.json";
pub const MODEL_PROMOTION_REGISTRY_SHA256_ENV: &str = "MODEL_PROMOTION_REGISTRY_SHA256";
pub const MODEL_PROMOTION_ENTRY_SHA256_PINS_ENV: &str = "MODEL_PROMOTION_ENTRY_SHA256_PINS";

const ACTIVE: &str = "ACTIVE";
const PROMOTED: &str = "PROMOTED_UNTOUCHED_FORWARD_SHADOW";
const EVIDENCE_KIND: &str = "untouched_forward_shadow_promotion";
const MINIMUM_SETTLED_PREDICTIONS_FLOOR: u64 = 250;
const REQUIRED_PROMOTION_HORIZONS: [u32; 4] = [5, 15, 30, 60];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ModelPromotionRegistry {
    pub schema_version: String,
    pub artifact_kind: String,
    pub generated_at: DateTime<Utc>,
    pub status: String,
    pub execution_enabled: bool,
    pub entries: Vec<ModelPromotionEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ModelPromotionEntry {
    pub symbol: String,
    pub model_id: String,
    pub model_hash: String,
    pub feature_hash: String,
    pub data_manifest_hash: String,
    pub model_artifact: PinnedArtifact,
    pub horizons: BTreeMap<u32, HorizonPromotion>,
    #[serde(default)]
    pub allocation_distribution_status: Option<String>,
    #[serde(default)]
    pub tail_model_status: Option<String>,
    #[serde(default)]
    pub cost_model_status: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct HorizonPromotion {
    pub horizon_minutes: u32,
    pub status: String,
    pub promotion: String,
    pub evidence_kind: String,
    pub forward_shadow: ForwardShadowReference,
    pub approval: ManualPromotionApproval,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct PinnedArtifact {
    pub path: String,
    pub sha256: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ForwardShadowReference {
    pub evidence_path: String,
    pub evidence_sha256: String,
    pub minimum_settled_predictions: u64,
    pub settled_predictions: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ManualPromotionApproval {
    pub approval_id: String,
    pub reviewer: String,
    pub approved_at: DateTime<Utc>,
    pub valid_until: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ForwardShadowPromotionEvidence {
    pub schema_version: String,
    pub evidence_kind: String,
    pub horizon_minutes: u32,
    pub generated_at: DateTime<Utc>,
    pub observation_start: DateTime<Utc>,
    pub observation_end: DateTime<Utc>,
    pub symbol: String,
    pub model_id: String,
    pub model_hash: String,
    pub feature_hash: String,
    pub data_manifest_hash: String,
    #[serde(default)]
    pub allocation_distribution_status: Option<String>,
    #[serde(default)]
    pub tail_model_status: Option<String>,
    #[serde(default)]
    pub cost_model_status: Option<String>,
    pub settled_predictions: u64,
    pub append_only_prediction_ledger: bool,
    pub replay_predictions_excluded: bool,
    pub untouched: bool,
    pub execution_enabled: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ExternalPromotionPins {
    pub registry_sha256: Option<String>,
    pub entry_sha256: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PromotionRegistryInspectionStatus {
    ActivePinned,
    Invalid,
    HashMismatch,
    Unpinned,
    LegacySingleMigrationRequired,
    Absent,
}

#[derive(Debug, Clone)]
pub struct PromotionRegistryInspection {
    pub present: bool,
    pub status: PromotionRegistryInspectionStatus,
    pub registry: Option<ModelPromotionRegistry>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct PromotionPinManifest {
    pub registry_sha256: String,
    pub entry_sha256: BTreeMap<String, String>,
    pub entry_count: usize,
}

impl ExternalPromotionPins {
    pub fn from_environment() -> Result<Self> {
        let registry_sha256 = env::var(MODEL_PROMOTION_REGISTRY_SHA256_ENV)
            .ok()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty());
        if registry_sha256
            .as_deref()
            .is_some_and(|value| !valid_nonzero_sha256(value))
        {
            bail!("{MODEL_PROMOTION_REGISTRY_SHA256_ENV} is not a nonzero SHA-256");
        }

        let entry_sha256 = match env::var(MODEL_PROMOTION_ENTRY_SHA256_PINS_ENV) {
            Ok(raw) if !raw.trim().is_empty() => {
                let pins: BTreeMap<String, String> =
                    serde_json::from_str(&raw).with_context(|| {
                        format!("parse {MODEL_PROMOTION_ENTRY_SHA256_PINS_ENV} as a JSON object")
                    })?;
                if pins.is_empty()
                    || pins.iter().any(|(key, hash)| {
                        key.trim().is_empty() || !valid_nonzero_sha256(hash.trim())
                    })
                {
                    bail!(
                        "{MODEL_PROMOTION_ENTRY_SHA256_PINS_ENV} contains an invalid identity or SHA-256"
                    );
                }
                pins.into_iter()
                    .map(|(key, hash)| (key, hash.to_ascii_lowercase()))
                    .collect()
            }
            _ => BTreeMap::new(),
        };
        Ok(Self {
            registry_sha256: registry_sha256.map(|value| value.to_ascii_lowercase()),
            entry_sha256,
        })
    }
}

impl ModelPromotionEntry {
    pub fn identity_key(&self) -> String {
        promotion_identity_key(&self.symbol, &self.model_hash)
    }

    pub fn canonical_sha256(&self) -> Result<String> {
        Ok(sha256_hex(&serde_json::to_vec(self)?))
    }

    fn validate_structure(&self) -> Result<()> {
        if canonical_symbol(&self.symbol).as_deref() != Some(self.symbol.as_str()) {
            bail!("promotion entry symbol is not canonical");
        }
        if self.model_id.trim().is_empty()
            || !valid_nonzero_sha256(&self.model_hash)
            || !valid_nonzero_sha256(&self.feature_hash)
            || !valid_nonzero_sha256(&self.data_manifest_hash)
        {
            bail!("promotion entry model identity is invalid");
        }
        if !valid_nonzero_sha256(&self.model_artifact.sha256)
            || scoped_relative_path(&self.model_artifact.path).is_none()
        {
            bail!("promotion entry model artifact pin is invalid");
        }
        let configured_horizons = self.horizons.keys().copied().collect::<BTreeSet<_>>();
        let required_horizons = REQUIRED_PROMOTION_HORIZONS
            .into_iter()
            .collect::<BTreeSet<_>>();
        if configured_horizons != required_horizons {
            bail!("promotion entry must contain exactly the required horizon evidence");
        }
        for (horizon_minutes, promotion) in &self.horizons {
            promotion.validate_structure(*horizon_minutes)?;
        }
        for status in [
            self.allocation_distribution_status.as_deref(),
            self.tail_model_status.as_deref(),
            self.cost_model_status.as_deref(),
        ]
        .into_iter()
        .flatten()
        {
            if status.trim().is_empty() {
                bail!("promotion entry contains an empty pinned status");
            }
        }
        Ok(())
    }

    fn validate_bound_artifacts(&self, root: &Path) -> Result<()> {
        verify_scoped_sha256(root, &self.model_artifact.path, &self.model_artifact.sha256)
            .context("model artifact SHA-256 mismatch")?;
        for promotion in self.horizons.values() {
            let evidence_bytes = verify_scoped_sha256(
                root,
                &promotion.forward_shadow.evidence_path,
                &promotion.forward_shadow.evidence_sha256,
            )
            .with_context(|| {
                format!(
                    "{}-minute forward-shadow evidence SHA-256 mismatch",
                    promotion.horizon_minutes
                )
            })?;
            let evidence: ForwardShadowPromotionEvidence = serde_json::from_slice(&evidence_bytes)
                .with_context(|| {
                    format!(
                        "parse {}-minute forward-shadow evidence",
                        promotion.horizon_minutes
                    )
                })?;
            evidence.validate_for(self, promotion).with_context(|| {
                format!(
                    "validate {}-minute forward-shadow evidence",
                    promotion.horizon_minutes
                )
            })?;
        }
        Ok(())
    }

    pub fn matches_forecast_row(
        &self,
        row: &Value,
        forecast_as_of: DateTime<Utc>,
        evaluation_as_of: DateTime<Utc>,
    ) -> bool {
        let row_symbol = row
            .get("symbol")
            .and_then(Value::as_str)
            .and_then(canonical_symbol);
        let row_model_hash = row.get("model_hash").and_then(Value::as_str);
        let horizon_promotion = row
            .get("horizon_minutes")
            .and_then(Value::as_u64)
            .and_then(|value| u32::try_from(value).ok())
            .and_then(|horizon_minutes| {
                self.horizons
                    .get(&horizon_minutes)
                    .filter(|promotion| promotion.horizon_minutes == horizon_minutes)
            });
        row_symbol.as_deref() == Some(self.symbol.as_str())
            && row.get("model_id").and_then(Value::as_str) == Some(self.model_id.as_str())
            && row_model_hash == Some(self.model_hash.as_str())
            && row_model_hash.is_some_and(valid_nonzero_sha256)
            && row.get("feature_hash").and_then(Value::as_str) == Some(self.feature_hash.as_str())
            && row.get("data_manifest_hash").and_then(Value::as_str)
                == Some(self.data_manifest_hash.as_str())
            && self.allocation_distribution_status.as_deref()
                == row
                    .get("allocation_distribution_status")
                    .and_then(Value::as_str)
            && self.tail_model_status.as_deref()
                == row.get("tail_model_status").and_then(Value::as_str)
            && self.cost_model_status.as_deref()
                == row
                    .pointer("/decision/cost_model_status")
                    .and_then(Value::as_str)
            && horizon_promotion.is_some_and(|promotion| {
                promotion.approval.approved_at <= forecast_as_of
                    && promotion.approval.valid_until >= evaluation_as_of
            })
    }
}

impl HorizonPromotion {
    fn validate_structure(&self, map_key: u32) -> Result<()> {
        if self.horizon_minutes != map_key
            || !REQUIRED_PROMOTION_HORIZONS.contains(&self.horizon_minutes)
            || self.status != ACTIVE
            || self.promotion != PROMOTED
            || self.evidence_kind != EVIDENCE_KIND
        {
            bail!("horizon promotion is not active or is bound to the wrong horizon");
        }
        if self.approval.approval_id.trim().is_empty()
            || self.approval.reviewer.trim().is_empty()
            || self.approval.approved_at >= self.approval.valid_until
        {
            bail!("horizon promotion manual approval is invalid");
        }
        if !valid_nonzero_sha256(&self.forward_shadow.evidence_sha256)
            || scoped_relative_path(&self.forward_shadow.evidence_path).is_none()
        {
            bail!("horizon promotion forward-shadow evidence pin is invalid");
        }
        if self.forward_shadow.minimum_settled_predictions < MINIMUM_SETTLED_PREDICTIONS_FLOOR
            || self.forward_shadow.settled_predictions
                < self.forward_shadow.minimum_settled_predictions
        {
            bail!("horizon promotion has insufficient settled forward-shadow predictions");
        }
        Ok(())
    }
}

impl ForwardShadowPromotionEvidence {
    fn validate_for(
        &self,
        entry: &ModelPromotionEntry,
        promotion: &HorizonPromotion,
    ) -> Result<()> {
        if self.schema_version != FORWARD_SHADOW_EVIDENCE_SCHEMA_VERSION
            || self.evidence_kind != EVIDENCE_KIND
            || self.horizon_minutes != promotion.horizon_minutes
            || self.symbol != entry.symbol
            || self.model_id != entry.model_id
            || self.model_hash != entry.model_hash
            || self.feature_hash != entry.feature_hash
            || self.data_manifest_hash != entry.data_manifest_hash
            || self.allocation_distribution_status != entry.allocation_distribution_status
            || self.tail_model_status != entry.tail_model_status
            || self.cost_model_status != entry.cost_model_status
            || self.settled_predictions != promotion.forward_shadow.settled_predictions
            || !self.append_only_prediction_ledger
            || !self.replay_predictions_excluded
            || !self.untouched
            || self.execution_enabled
        {
            bail!("forward-shadow evidence contract does not match the promotion entry");
        }
        if self.observation_start >= self.observation_end
            || self.observation_end > self.generated_at
            || self.generated_at > promotion.approval.approved_at
        {
            bail!("forward-shadow evidence timestamps are invalid");
        }
        Ok(())
    }
}

impl ModelPromotionRegistry {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
        let registry: Self =
            serde_json::from_slice(bytes).context("parse multi-model promotion registry")?;
        registry.validate_structure()?;
        Ok(registry)
    }

    pub fn from_path(path: &Path) -> Result<Self> {
        Self::from_bytes(&fs::read(path).with_context(|| format!("read {}", path.display()))?)
    }

    fn validate_structure(&self) -> Result<()> {
        if self.schema_version != MODEL_PROMOTION_REGISTRY_SCHEMA_VERSION
            || self.artifact_kind != "model_promotion_registry"
            || self.status != ACTIVE
            || self.execution_enabled
            || self.entries.is_empty()
        {
            bail!("multi-model promotion registry header is invalid");
        }
        let mut identities = BTreeSet::new();
        let mut symbols = BTreeSet::new();
        for entry in &self.entries {
            entry.validate_structure()?;
            if entry
                .horizons
                .values()
                .any(|promotion| promotion.approval.approved_at > self.generated_at)
            {
                bail!("registry was generated before an entry was manually approved");
            }
            if !identities.insert(entry.identity_key()) || !symbols.insert(entry.symbol.clone()) {
                bail!("promotion registry contains a duplicate active symbol/model identity");
            }
        }
        Ok(())
    }

    fn validate_bound_artifacts(&self, root: &Path) -> Result<()> {
        for entry in &self.entries {
            entry.validate_bound_artifacts(root)?;
        }
        Ok(())
    }

    pub fn entry_for_row(&self, row: &Value) -> Option<&ModelPromotionEntry> {
        let symbol = row
            .get("symbol")
            .and_then(Value::as_str)
            .and_then(canonical_symbol)?;
        let model_hash = row.get("model_hash").and_then(Value::as_str)?;
        self.entries
            .iter()
            .find(|entry| entry.symbol == symbol && entry.model_hash == model_hash)
    }

    pub fn matches_forecast_row(
        &self,
        row: &Value,
        forecast_as_of: DateTime<Utc>,
        evaluation_as_of: DateTime<Utc>,
    ) -> bool {
        self.entry_for_row(row)
            .is_some_and(|entry| entry.matches_forecast_row(row, forecast_as_of, evaluation_as_of))
    }
}

pub fn inspect_from_environment(root: &Path) -> PromotionRegistryInspection {
    let pins = match ExternalPromotionPins::from_environment() {
        Ok(pins) => pins,
        Err(_) => {
            return PromotionRegistryInspection {
                present: root.join(MODEL_PROMOTION_REGISTRY_FILENAME).is_file(),
                status: PromotionRegistryInspectionStatus::Invalid,
                registry: None,
            };
        }
    };
    inspect_with_pins(root, &pins)
}

pub fn inspect_with_pins(root: &Path, pins: &ExternalPromotionPins) -> PromotionRegistryInspection {
    let path = root.join(MODEL_PROMOTION_REGISTRY_FILENAME);
    let Ok(bytes) = fs::read(&path) else {
        return PromotionRegistryInspection {
            present: false,
            status: PromotionRegistryInspectionStatus::Absent,
            registry: None,
        };
    };
    if is_legacy_single_registry(&bytes) {
        return PromotionRegistryInspection {
            present: true,
            status: PromotionRegistryInspectionStatus::LegacySingleMigrationRequired,
            registry: None,
        };
    }
    let Some(expected_registry_hash) = pins.registry_sha256.as_deref() else {
        return PromotionRegistryInspection {
            present: true,
            status: PromotionRegistryInspectionStatus::Unpinned,
            registry: None,
        };
    };
    if !sha256_hex(&bytes).eq_ignore_ascii_case(expected_registry_hash) {
        return PromotionRegistryInspection {
            present: true,
            status: PromotionRegistryInspectionStatus::HashMismatch,
            registry: None,
        };
    }
    let Ok(registry) = ModelPromotionRegistry::from_bytes(&bytes) else {
        return PromotionRegistryInspection {
            present: true,
            status: PromotionRegistryInspectionStatus::Invalid,
            registry: None,
        };
    };
    for entry in &registry.entries {
        let Some(expected_entry_hash) = pins.entry_sha256.get(&entry.identity_key()) else {
            return PromotionRegistryInspection {
                present: true,
                status: PromotionRegistryInspectionStatus::Unpinned,
                registry: None,
            };
        };
        let Ok(observed_entry_hash) = entry.canonical_sha256() else {
            return PromotionRegistryInspection {
                present: true,
                status: PromotionRegistryInspectionStatus::Invalid,
                registry: None,
            };
        };
        if !observed_entry_hash.eq_ignore_ascii_case(expected_entry_hash) {
            return PromotionRegistryInspection {
                present: true,
                status: PromotionRegistryInspectionStatus::HashMismatch,
                registry: None,
            };
        }
    }
    if registry.validate_bound_artifacts(root).is_err() {
        return PromotionRegistryInspection {
            present: true,
            status: PromotionRegistryInspectionStatus::HashMismatch,
            registry: None,
        };
    }
    PromotionRegistryInspection {
        present: true,
        status: PromotionRegistryInspectionStatus::ActivePinned,
        registry: Some(registry),
    }
}

pub fn pin_manifest(root: &Path, registry_path: &Path) -> Result<PromotionPinManifest> {
    let bytes =
        fs::read(registry_path).with_context(|| format!("read {}", registry_path.display()))?;
    if is_legacy_single_registry(&bytes) {
        bail!("legacy single-record promotion registry must be explicitly migrated");
    }
    let registry = ModelPromotionRegistry::from_bytes(&bytes)?;
    registry.validate_bound_artifacts(root)?;
    let entry_sha256 = registry
        .entries
        .iter()
        .map(|entry| Ok((entry.identity_key(), entry.canonical_sha256()?)))
        .collect::<Result<BTreeMap<_, _>>>()?;
    Ok(PromotionPinManifest {
        registry_sha256: sha256_hex(&bytes),
        entry_count: entry_sha256.len(),
        entry_sha256,
    })
}

/// Produce a non-serving migration draft from the legacy top-level tuple.
///
/// The draft intentionally remains `MIGRATION_REQUIRED`; a reviewer must bind
/// the immutable model artifact and per-symbol forward-shadow evidence before
/// authoring an ACTIVE v2 entry and externally pinning it.
pub fn legacy_migration_draft(bytes: &[u8], symbol: &str) -> Result<Value> {
    let legacy: Value = serde_json::from_slice(bytes).context("parse legacy promotion registry")?;
    if !is_legacy_single_value(&legacy) {
        bail!("input is not a legacy single-record promotion registry");
    }
    let symbol = canonical_symbol(symbol).context("migration symbol is invalid")?;
    let field = |name: &str| legacy.get(name).cloned().unwrap_or(Value::Null);
    Ok(serde_json::json!({
        "schema_version": MODEL_PROMOTION_REGISTRY_SCHEMA_VERSION,
        "artifact_kind": "model_promotion_registry",
        "generated_at": Utc::now(),
        "status": "MIGRATION_REQUIRED",
        "execution_enabled": false,
        "entries": [{
            "symbol": symbol,
            "model_id": field("model_id"),
            "model_hash": field("model_hash"),
            "feature_hash": field("feature_hash"),
            "data_manifest_hash": field("data_manifest_hash"),
            "status": "MIGRATION_REQUIRED",
            "horizons": {},
            "legacy_single_horizon_evidence": {
                "horizon_minutes": field("horizon_minutes"),
                "promotion": field("promotion"),
                "evidence_kind": field("evidence_kind"),
                "approval_id": field("approval_id"),
                "reviewer": field("reviewer"),
                "approved_at": field("approved_at"),
                "valid_until": field("valid_until")
            },
            "legacy_registry_sha256": sha256_hex(bytes),
            "required_horizons_minutes": REQUIRED_PROMOTION_HORIZONS,
            "required_actions": [
                "BIND_IMMUTABLE_MODEL_ARTIFACT_SHA256",
                "BIND_PER_SYMBOL_AND_HORIZON_UNTOUCHED_FORWARD_SHADOW_EVIDENCE_SHA256",
                "ISSUE_NEW_MANUAL_APPROVAL_FOR_EACH_REQUIRED_HORIZON",
                "PIN_REGISTRY_AND_ENTRY_SHA256_OUTSIDE_THE_ARTIFACT"
            ]
        }],
        "migration": {
            "source_format": "legacy_single_top_level_tuple",
            "serving_eligible": false
        }
    }))
}

fn promotion_identity_key(symbol: &str, model_hash: &str) -> String {
    format!(
        "{}@{}",
        canonical_symbol(symbol).unwrap_or_default(),
        model_hash.to_ascii_lowercase()
    )
}

fn canonical_symbol(raw: &str) -> Option<String> {
    let symbol = raw
        .trim()
        .strip_prefix("US.")
        .unwrap_or(raw.trim())
        .to_ascii_uppercase();
    (!symbol.is_empty()
        && symbol
            .chars()
            .all(|character| character.is_ascii_alphanumeric()))
    .then_some(symbol)
}

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn scoped_relative_path(raw: &str) -> Option<PathBuf> {
    let normalized = raw.trim().replace('\\', "/");
    let path = PathBuf::from(normalized);
    if path.as_os_str().is_empty()
        || path.is_absolute()
        || path.components().any(|component| {
            matches!(
                component,
                Component::ParentDir | Component::RootDir | Component::Prefix(_)
            )
        })
    {
        return None;
    }
    Some(path)
}

fn verify_scoped_sha256(root: &Path, raw_path: &str, expected: &str) -> Result<Vec<u8>> {
    let relative = scoped_relative_path(raw_path).context("artifact path escapes the data root")?;
    let bytes = fs::read(root.join(relative)).context("read pinned artifact")?;
    if !sha256_hex(&bytes).eq_ignore_ascii_case(expected) {
        bail!("pinned artifact SHA-256 mismatch");
    }
    Ok(bytes)
}

fn is_legacy_single_registry(bytes: &[u8]) -> bool {
    serde_json::from_slice::<Value>(bytes)
        .ok()
        .is_some_and(|value| is_legacy_single_value(&value))
}

fn is_legacy_single_value(value: &Value) -> bool {
    value.get("artifact_kind").and_then(Value::as_str) == Some("model_promotion_registry")
        && value.get("entries").is_none()
        && value.get("model_hash").and_then(Value::as_str).is_some()
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;
    use serde_json::json;
    use tempfile::tempdir;

    fn timestamp(hour: u32) -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 7, 27, hour, 0, 0)
            .single()
            .unwrap()
    }

    fn write_bound_entry(root: &Path, symbol: &str, digit: char) -> ModelPromotionEntry {
        let model_hash = digit.to_string().repeat(64);
        let model_path = format!("models/universe/{symbol}.frozen.json");
        let model_bytes = format!("immutable-{symbol}-{model_hash}").into_bytes();
        fs::create_dir_all(root.join("models/universe")).unwrap();
        fs::write(root.join(&model_path), &model_bytes).unwrap();

        fs::create_dir_all(root.join("reports")).unwrap();
        let horizons = REQUIRED_PROMOTION_HORIZONS
            .into_iter()
            .map(|horizon_minutes| {
                let evidence_path =
                    format!("reports/{symbol}.{horizon_minutes}m.forward-shadow.json");
                let evidence = ForwardShadowPromotionEvidence {
                    schema_version: FORWARD_SHADOW_EVIDENCE_SCHEMA_VERSION.to_string(),
                    evidence_kind: EVIDENCE_KIND.to_string(),
                    horizon_minutes,
                    generated_at: timestamp(10),
                    observation_start: timestamp(8),
                    observation_end: timestamp(9),
                    symbol: symbol.to_string(),
                    model_id: format!("{symbol}-model-v1"),
                    model_hash: model_hash.clone(),
                    feature_hash: "c".repeat(64),
                    data_manifest_hash: "d".repeat(64),
                    allocation_distribution_status: Some(
                        "OOS_VALIDATED_FULL_DISTRIBUTION".to_string(),
                    ),
                    tail_model_status: Some("OOS_VALIDATED".to_string()),
                    cost_model_status: Some("OOS_VALIDATED".to_string()),
                    settled_predictions: 300,
                    append_only_prediction_ledger: true,
                    replay_predictions_excluded: true,
                    untouched: true,
                    execution_enabled: false,
                };
                let evidence_bytes = serde_json::to_vec_pretty(&evidence).unwrap();
                fs::write(root.join(&evidence_path), &evidence_bytes).unwrap();
                (
                    horizon_minutes,
                    HorizonPromotion {
                        horizon_minutes,
                        status: ACTIVE.to_string(),
                        promotion: PROMOTED.to_string(),
                        evidence_kind: EVIDENCE_KIND.to_string(),
                        forward_shadow: ForwardShadowReference {
                            evidence_path,
                            evidence_sha256: sha256_hex(&evidence_bytes),
                            minimum_settled_predictions: 250,
                            settled_predictions: 300,
                        },
                        approval: ManualPromotionApproval {
                            approval_id: format!("approval-{symbol}-{horizon_minutes}m"),
                            reviewer: "independent-reviewer".to_string(),
                            approved_at: timestamp(11),
                            valid_until: timestamp(20),
                        },
                    },
                )
            })
            .collect();

        ModelPromotionEntry {
            symbol: symbol.to_string(),
            model_id: format!("{symbol}-model-v1"),
            model_hash,
            feature_hash: "c".repeat(64),
            data_manifest_hash: "d".repeat(64),
            model_artifact: PinnedArtifact {
                path: model_path,
                sha256: sha256_hex(&model_bytes),
            },
            horizons,
            allocation_distribution_status: Some("OOS_VALIDATED_FULL_DISTRIBUTION".to_string()),
            tail_model_status: Some("OOS_VALIDATED".to_string()),
            cost_model_status: Some("OOS_VALIDATED".to_string()),
        }
    }

    fn row(entry: &ModelPromotionEntry) -> Value {
        row_at(entry, 15)
    }

    fn row_at(entry: &ModelPromotionEntry, horizon_minutes: u32) -> Value {
        json!({
            "symbol": entry.symbol,
            "horizon_minutes": horizon_minutes,
            "model_id": entry.model_id,
            "model_hash": entry.model_hash,
            "feature_hash": entry.feature_hash,
            "data_manifest_hash": entry.data_manifest_hash,
            "allocation_distribution_status": entry.allocation_distribution_status,
            "tail_model_status": entry.tail_model_status,
            "decision": {
                "cost_model_status": entry.cost_model_status
            }
        })
    }

    fn registry(entries: Vec<ModelPromotionEntry>) -> ModelPromotionRegistry {
        ModelPromotionRegistry {
            schema_version: MODEL_PROMOTION_REGISTRY_SCHEMA_VERSION.to_string(),
            artifact_kind: "model_promotion_registry".to_string(),
            generated_at: timestamp(12),
            status: ACTIVE.to_string(),
            execution_enabled: false,
            entries,
        }
    }

    fn persist_registry(root: &Path, registry: &ModelPromotionRegistry) -> Vec<u8> {
        let bytes = serde_json::to_vec_pretty(registry).unwrap();
        fs::create_dir_all(root.join("models")).unwrap();
        fs::write(root.join(MODEL_PROMOTION_REGISTRY_FILENAME), &bytes).unwrap();
        bytes
    }

    fn pins(registry: &ModelPromotionRegistry, bytes: &[u8]) -> ExternalPromotionPins {
        ExternalPromotionPins {
            registry_sha256: Some(sha256_hex(bytes)),
            entry_sha256: registry
                .entries
                .iter()
                .map(|entry| (entry.identity_key(), entry.canonical_sha256().unwrap()))
                .collect(),
        }
    }

    #[test]
    fn independently_pinned_entries_match_only_their_symbol_and_model_hash() {
        let directory = tempdir().unwrap();
        let spy = write_bound_entry(directory.path(), "SPY", 'a');
        let nvda = write_bound_entry(directory.path(), "NVDA", 'b');
        let registry = registry(vec![spy.clone(), nvda.clone()]);
        let bytes = persist_registry(directory.path(), &registry);
        let inspection = inspect_with_pins(directory.path(), &pins(&registry, &bytes));

        assert_eq!(
            inspection.status,
            PromotionRegistryInspectionStatus::ActivePinned
        );
        let loaded = inspection.registry.unwrap();
        assert!(loaded.matches_forecast_row(&row(&spy), timestamp(12), timestamp(13)));
        assert!(loaded.matches_forecast_row(&row(&nvda), timestamp(12), timestamp(13)));

        let mut crossed = row(&spy);
        crossed["model_hash"] = json!(nvda.model_hash);
        assert!(!loaded.matches_forecast_row(&crossed, timestamp(12), timestamp(13)));

        let mut wrong_feature = row(&spy);
        wrong_feature["feature_hash"] = json!("e".repeat(64));
        assert!(!loaded.matches_forecast_row(&wrong_feature, timestamp(12), timestamp(13)));

        let mut wrong_manifest = row(&spy);
        wrong_manifest["data_manifest_hash"] = json!("f".repeat(64));
        assert!(!loaded.matches_forecast_row(&wrong_manifest, timestamp(12), timestamp(13)));
    }

    #[test]
    fn every_active_entry_requires_its_own_external_pin() {
        let directory = tempdir().unwrap();
        let spy = write_bound_entry(directory.path(), "SPY", 'a');
        let nvda = write_bound_entry(directory.path(), "NVDA", 'b');
        let registry = registry(vec![spy, nvda]);
        let bytes = persist_registry(directory.path(), &registry);
        let mut external = pins(&registry, &bytes);
        external
            .entry_sha256
            .remove(&registry.entries[1].identity_key());

        assert_eq!(
            inspect_with_pins(directory.path(), &external).status,
            PromotionRegistryInspectionStatus::Unpinned
        );
    }

    #[test]
    fn nine_model_universe_is_pinned_and_resolved_per_identity() {
        let directory = tempdir().unwrap();
        let symbols = [
            "SPY", "QQQ", "NVDA", "AAPL", "MU", "SOXX", "NBIS", "BE", "IGV",
        ];
        let entries = symbols
            .iter()
            .zip('1'..='9')
            .map(|(symbol, digit)| write_bound_entry(directory.path(), symbol, digit))
            .collect::<Vec<_>>();
        let registry = registry(entries.clone());
        let bytes = persist_registry(directory.path(), &registry);
        let external = pins(&registry, &bytes);
        let manifest = pin_manifest(
            directory.path(),
            &directory.path().join(MODEL_PROMOTION_REGISTRY_FILENAME),
        )
        .unwrap();

        assert_eq!(external.entry_sha256.len(), 9);
        assert_eq!(manifest.entry_count, 9);
        assert_eq!(manifest.entry_sha256, external.entry_sha256);
        let inspection = inspect_with_pins(directory.path(), &external);
        assert_eq!(
            inspection.status,
            PromotionRegistryInspectionStatus::ActivePinned
        );
        let loaded = inspection.registry.unwrap();
        assert_eq!(loaded.entries.len(), 9);
        assert!(entries.iter().all(|entry| loaded.matches_forecast_row(
            &row(entry),
            timestamp(12),
            timestamp(13)
        )));
    }

    #[test]
    fn tampered_forward_shadow_evidence_fails_closed() {
        let directory = tempdir().unwrap();
        let spy = write_bound_entry(directory.path(), "SPY", 'a');
        let evidence_path = spy.horizons[&15].forward_shadow.evidence_path.clone();
        let registry = registry(vec![spy]);
        let bytes = persist_registry(directory.path(), &registry);
        fs::write(directory.path().join(evidence_path), b"tampered").unwrap();

        assert_eq!(
            inspect_with_pins(directory.path(), &pins(&registry, &bytes)).status,
            PromotionRegistryInspectionStatus::HashMismatch
        );
    }

    #[test]
    fn duplicate_active_symbol_is_invalid() {
        let directory = tempdir().unwrap();
        let first = write_bound_entry(directory.path(), "SPY", 'a');
        let second = write_bound_entry(directory.path(), "SPY", 'b');
        let registry = registry(vec![first, second]);
        let bytes = persist_registry(directory.path(), &registry);

        assert_eq!(
            inspect_with_pins(directory.path(), &pins(&registry, &bytes)).status,
            PromotionRegistryInspectionStatus::Invalid
        );
    }

    #[test]
    fn legacy_single_record_is_diagnostic_only_and_migrates_to_a_blocked_draft() {
        let directory = tempdir().unwrap();
        let legacy = serde_json::to_vec_pretty(&json!({
            "artifact_kind": "model_promotion_registry",
            "status": "ACTIVE",
            "model_id": "legacy-model",
            "model_hash": "a".repeat(64),
            "feature_hash": "c".repeat(64),
            "data_manifest_hash": "d".repeat(64),
            "horizon_minutes": 15,
            "promotion": PROMOTED,
            "evidence_kind": EVIDENCE_KIND,
            "approval_id": "legacy-approval",
            "reviewer": "legacy-reviewer",
            "approved_at": timestamp(10),
            "valid_until": timestamp(20)
        }))
        .unwrap();
        fs::create_dir_all(directory.path().join("models")).unwrap();
        fs::write(
            directory.path().join(MODEL_PROMOTION_REGISTRY_FILENAME),
            &legacy,
        )
        .unwrap();
        let external = ExternalPromotionPins {
            registry_sha256: Some(sha256_hex(&legacy)),
            entry_sha256: BTreeMap::new(),
        };

        assert_eq!(
            inspect_with_pins(directory.path(), &external).status,
            PromotionRegistryInspectionStatus::LegacySingleMigrationRequired
        );
        let draft = legacy_migration_draft(&legacy, "SPY").unwrap();
        assert_eq!(draft["status"], "MIGRATION_REQUIRED");
        assert_eq!(draft["execution_enabled"], false);
        assert_eq!(draft["entries"][0]["feature_hash"], "c".repeat(64));
        assert_eq!(draft["entries"][0]["data_manifest_hash"], "d".repeat(64));
        assert_eq!(
            draft["entries"][0]["required_horizons_minutes"],
            json!([5, 15, 30, 60])
        );
        assert_eq!(
            draft["entries"][0]["legacy_single_horizon_evidence"]["horizon_minutes"],
            15
        );
        assert!(ModelPromotionRegistry::from_bytes(&serde_json::to_vec(&draft).unwrap()).is_err());
    }

    #[test]
    fn fifteen_minute_evidence_cannot_authorize_a_five_minute_forecast() {
        let directory = tempdir().unwrap();
        let spy = write_bound_entry(directory.path(), "SPY", 'a');
        assert!(spy.matches_forecast_row(&row_at(&spy, 5), timestamp(12), timestamp(13)));

        let mut crossed = spy.clone();
        crossed.horizons.insert(5, crossed.horizons[&15].clone());
        assert!(!crossed.matches_forecast_row(&row_at(&crossed, 5), timestamp(12), timestamp(13)));

        let mut missing = row_at(&spy, 5);
        missing.as_object_mut().unwrap().remove("horizon_minutes");
        assert!(!spy.matches_forecast_row(&missing, timestamp(12), timestamp(13)));
        let mut unsupported = row_at(&spy, 5);
        unsupported["horizon_minutes"] = json!(10);
        assert!(!spy.matches_forecast_row(&unsupported, timestamp(12), timestamp(13)));
    }

    #[test]
    fn evidence_document_horizon_must_match_its_reference() {
        let directory = tempdir().unwrap();
        let mut spy = write_bound_entry(directory.path(), "SPY", 'a');
        let fifteen_path = spy.horizons[&15].forward_shadow.evidence_path.clone();
        let fifteen_bytes = fs::read(directory.path().join(&fifteen_path)).unwrap();
        let five = spy.horizons.get_mut(&5).unwrap();
        five.forward_shadow.evidence_path = fifteen_path;
        five.forward_shadow.evidence_sha256 = sha256_hex(&fifteen_bytes);
        let registry = registry(vec![spy]);
        let bytes = persist_registry(directory.path(), &registry);

        assert_eq!(
            inspect_with_pins(directory.path(), &pins(&registry, &bytes)).status,
            PromotionRegistryInspectionStatus::HashMismatch
        );
    }

    #[test]
    fn repinned_evidence_with_a_different_approved_tuple_is_invalid() {
        let mutations = [
            ("model_id", json!("different-model")),
            ("feature_hash", json!("e".repeat(64))),
            ("data_manifest_hash", json!("f".repeat(64))),
            ("allocation_distribution_status", json!("DIFFERENT")),
            ("tail_model_status", json!("DIFFERENT")),
            ("cost_model_status", json!("DIFFERENT")),
        ];
        for (field, replacement) in mutations {
            let directory = tempdir().unwrap();
            let mut spy = write_bound_entry(directory.path(), "SPY", 'a');
            let evidence_path = spy.horizons[&15].forward_shadow.evidence_path.clone();
            let mut evidence: Value =
                serde_json::from_slice(&fs::read(directory.path().join(&evidence_path)).unwrap())
                    .unwrap();
            evidence[field] = replacement;
            let evidence_bytes = serde_json::to_vec_pretty(&evidence).unwrap();
            fs::write(directory.path().join(&evidence_path), &evidence_bytes).unwrap();
            spy.horizons
                .get_mut(&15)
                .unwrap()
                .forward_shadow
                .evidence_sha256 = sha256_hex(&evidence_bytes);
            let registry = registry(vec![spy]);
            let registry_bytes = persist_registry(directory.path(), &registry);

            assert_eq!(
                inspect_with_pins(directory.path(), &pins(&registry, &registry_bytes)).status,
                PromotionRegistryInspectionStatus::HashMismatch,
                "re-pinned evidence field {field} must not cross an approval tuple"
            );
        }
    }

    #[test]
    fn approval_validity_is_evaluated_for_only_the_requested_horizon() {
        let directory = tempdir().unwrap();
        let mut spy = write_bound_entry(directory.path(), "SPY", 'a');
        spy.horizons.get_mut(&5).unwrap().approval.valid_until = timestamp(12);

        assert!(!spy.matches_forecast_row(&row_at(&spy, 5), timestamp(11), timestamp(13)));
        assert!(spy.matches_forecast_row(&row_at(&spy, 15), timestamp(12), timestamp(13)));
    }

    #[test]
    fn registry_missing_any_required_horizon_is_invalid() {
        let directory = tempdir().unwrap();
        let mut spy = write_bound_entry(directory.path(), "SPY", 'a');
        spy.horizons.remove(&60);
        let registry = registry(vec![spy]);
        let bytes = persist_registry(directory.path(), &registry);

        assert_eq!(
            inspect_with_pins(directory.path(), &pins(&registry, &bytes)).status,
            PromotionRegistryInspectionStatus::Invalid
        );
    }

    #[test]
    fn every_horizon_independently_requires_the_minimum_settled_sample() {
        let directory = tempdir().unwrap();
        let mut spy = write_bound_entry(directory.path(), "SPY", 'a');
        spy.horizons
            .get_mut(&5)
            .unwrap()
            .forward_shadow
            .minimum_settled_predictions = 249;
        let registry = registry(vec![spy]);
        let bytes = persist_registry(directory.path(), &registry);

        assert_eq!(
            inspect_with_pins(directory.path(), &pins(&registry, &bytes)).status,
            PromotionRegistryInspectionStatus::Invalid
        );
    }

    #[test]
    fn v2_registry_rejects_missing_or_non_sha_feature_and_manifest_bindings() {
        let directory = tempdir().unwrap();
        let spy = write_bound_entry(directory.path(), "SPY", 'a');
        let valid_bytes = serde_json::to_vec(&registry(vec![spy])).unwrap();
        let mut missing_feature: Value = serde_json::from_slice(&valid_bytes).unwrap();
        missing_feature["entries"][0]
            .as_object_mut()
            .unwrap()
            .remove("feature_hash");
        assert!(
            ModelPromotionRegistry::from_bytes(&serde_json::to_vec(&missing_feature).unwrap())
                .is_err()
        );

        let mut zero_manifest: Value = serde_json::from_slice(&valid_bytes).unwrap();
        zero_manifest["entries"][0]["data_manifest_hash"] = json!("0".repeat(64));
        assert!(
            ModelPromotionRegistry::from_bytes(&serde_json::to_vec(&zero_manifest).unwrap())
                .is_err()
        );
    }

    #[test]
    fn expired_or_not_yet_approved_entry_does_not_match_a_forecast() {
        let directory = tempdir().unwrap();
        let spy = write_bound_entry(directory.path(), "SPY", 'a');
        assert!(!spy.matches_forecast_row(&row(&spy), timestamp(10), timestamp(13)));
        assert!(!spy.matches_forecast_row(&row(&spy), timestamp(12), timestamp(21)));
    }
}
