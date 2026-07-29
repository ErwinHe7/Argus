use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::config::ContextFeedConfig;

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ContextFrequency {
    Snapshot,
    Minute,
    Daily,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum ContextDomain {
    Market,
    Macro,
    Fundamental,
    EarningsActual,
    EarningsConsensus,
    Filing,
    News,
    Positioning,
    #[default]
    Unknown,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum AvailabilityPrecision {
    ExactTimestamp,
    ConservativeDateClose,
    IngestionTimeOnly,
    #[default]
    Unknown,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum LicenseClass {
    Public,
    LicensedInternalModel,
    LicensedDisplayOnly,
    Restricted,
    #[default]
    Unknown,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum FeatureUse {
    ModelCandidate,
    #[default]
    ResearchOnly,
    DisplayOnly,
    Prohibited,
}

/// Normalized contract for external context such as Alva macro/index routes.
/// `event_time` is when the market fact occurred; `available_time` is the first
/// instant at which this exact value could have been observed by the strategy.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ContextObservation {
    pub symbol: String,
    pub field: String,
    pub value: f64,
    pub event_time: DateTime<Utc>,
    pub available_time: DateTime<Utc>,
    #[serde(default)]
    pub received_time: Option<DateTime<Utc>>,
    pub provider: String,
    pub route: String,
    #[serde(default)]
    pub upstream_vendor: Option<String>,
    pub frequency: ContextFrequency,
    #[serde(default)]
    pub units: Option<String>,
    #[serde(default)]
    pub adjusted: Option<bool>,
    #[serde(default)]
    pub revision_id: Option<String>,
    #[serde(default)]
    pub supersedes_revision_id: Option<String>,
    #[serde(default)]
    pub domain: ContextDomain,
    #[serde(default)]
    pub availability_precision: AvailabilityPrecision,
    #[serde(default)]
    pub source_record_id: Option<String>,
    #[serde(default)]
    pub payload_sha256: Option<String>,
    #[serde(default)]
    pub license_class: LicenseClass,
    #[serde(default)]
    pub feature_use: FeatureUse,
}

impl ContextObservation {
    fn validate_auditable(&self) -> Result<()> {
        if self.symbol.trim().is_empty()
            || self.field.trim().is_empty()
            || self.provider.trim().is_empty()
            || self.route.trim().is_empty()
        {
            bail!("symbol, field, provider, and route are required");
        }
        if !self.value.is_finite() {
            bail!("context value must be finite");
        }
        if self.available_time < self.event_time {
            bail!("available_time cannot precede event_time");
        }
        if self
            .received_time
            .is_some_and(|received| received < self.event_time)
        {
            bail!("received_time cannot precede event_time");
        }
        if self
            .received_time
            .is_some_and(|received| received < self.available_time)
        {
            bail!("received_time cannot precede available_time");
        }
        if self
            .revision_id
            .as_ref()
            .is_some_and(|value| value.trim().is_empty())
            || self
                .supersedes_revision_id
                .as_ref()
                .is_some_and(|value| value.trim().is_empty())
        {
            bail!("revision identifiers cannot be empty");
        }
        if self.revision_id.is_some()
            && self.revision_id.as_ref() == self.supersedes_revision_id.as_ref()
        {
            bail!("a revision cannot supersede itself");
        }
        if let Some(hash) = &self.payload_sha256
            && !valid_nonzero_sha256(hash)
        {
            bail!("payload_sha256 must be a nonzero 64-character hexadecimal digest");
        }
        Ok(())
    }

    /// True only when this exact row is both structurally auditable and
    /// contractually permitted to cross the model/UI feature boundary.
    pub fn is_model_input_authorized(&self) -> bool {
        self.validate_auditable().is_ok()
            && self.feature_use == FeatureUse::ModelCandidate
            && matches!(
                self.license_class,
                LicenseClass::Public | LicenseClass::LicensedInternalModel
            )
            && matches!(
                self.availability_precision,
                AvailabilityPrecision::ExactTimestamp
                    | AvailabilityPrecision::ConservativeDateClose
            )
            && self
                .upstream_vendor
                .as_deref()
                .is_some_and(|value| !value.trim().is_empty())
            && self
                .source_record_id
                .as_deref()
                .is_some_and(|value| !value.trim().is_empty())
            && self.payload_sha256.is_some()
            && self
                .revision_id
                .as_deref()
                .is_some_and(|value| !value.trim().is_empty())
            && self.domain != ContextDomain::Unknown
    }

    pub fn validate(&self) -> Result<()> {
        self.validate_auditable()?;
        if self.feature_use == FeatureUse::ModelCandidate && !self.is_model_input_authorized() {
            bail!("model candidate is not authorized as model input");
        }
        Ok(())
    }

    pub fn key(&self) -> String {
        format!(
            "{}:{}",
            self.symbol.trim().to_ascii_uppercase(),
            self.field.trim().to_ascii_lowercase()
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ContextFieldAudit {
    pub key: String,
    pub route: String,
    pub domain: ContextDomain,
    pub frequency: ContextFrequency,
    pub observations_available_as_of: usize,
    pub unique_event_dates: usize,
    pub first_event_time: Option<DateTime<Utc>>,
    pub last_event_time: Option<DateTime<Utc>>,
    pub last_available_time: Option<DateTime<Utc>>,
    pub upstream_vendor_disclosed: bool,
    pub point_in_time_joinable: bool,
    pub revision_chain_valid: bool,
    pub model_use_authorized: bool,
    pub exact_or_conservative_availability: bool,
    pub model_feature_eligible: bool,
    pub reason_codes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ContextAuditReport {
    pub generated_at: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub provider: String,
    pub input_path: String,
    pub status: String,
    pub input_observations: usize,
    pub accepted_observations: usize,
    pub rejected_observations: usize,
    pub unavailable_at_cutoff: usize,
    pub auditable_observations_as_of: usize,
    pub model_input_authorized_observations_as_of: usize,
    pub policy_excluded_observations_as_of: usize,
    pub revision_count: usize,
    pub domain_counts: BTreeMap<String, usize>,
    pub model_eligible_fields: Vec<String>,
    pub fields: Vec<ContextFieldAudit>,
    pub allowed_uses: Vec<String>,
    pub prohibited_uses: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ContextFusionFeature {
    pub key: String,
    pub domain: ContextDomain,
    pub value: f64,
    pub units: Option<String>,
    pub event_time: DateTime<Utc>,
    pub available_time: DateTime<Utc>,
    pub received_time: Option<DateTime<Utc>>,
    pub provider: String,
    pub upstream_vendor: Option<String>,
    pub source_record_id: Option<String>,
    pub revision_id: Option<String>,
    pub availability_precision: AvailabilityPrecision,
    pub model_feature_eligible: bool,
    pub reason_codes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ContextFusionSnapshot {
    pub status: String,
    pub as_of: DateTime<Utc>,
    pub provider: String,
    pub input_path: String,
    pub point_in_time_ready: bool,
    /// Backward-compatible count of structurally auditable rows in the feed.
    pub observation_count: usize,
    /// Rows that were causally available at `as_of`, including policy-excluded rows.
    pub audited_observation_count: usize,
    pub model_input_authorized_observation_count: usize,
    pub policy_excluded_observation_count: usize,
    /// Only these values may be represented in `latest_features`.
    pub model_eligible_feature_count: usize,
    pub model_eligible_fields: Vec<String>,
    pub latest_features: Vec<ContextFusionFeature>,
    /// Domains represented by model-authorized, point-in-time-audited features only.
    /// Production readiness must use this map, never the broader audit counts.
    pub model_eligible_domain_counts: BTreeMap<String, usize>,
    /// All structurally auditable rows, including rows excluded by model-use policy.
    pub domain_counts: BTreeMap<String, usize>,
    pub reason_codes: Vec<String>,
    pub prohibited_uses: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OfficialContextArchiveVerification {
    pub verified: bool,
    pub schema_version: Option<String>,
    pub manifest_path: Option<String>,
    pub normalized_sha256: Option<String>,
    pub raw_artifacts_verified: usize,
    pub reason_codes: Vec<String>,
    pub truth: String,
}

fn verified_manifest_candidate(
    manifest_path: &Path,
    canonical_data_root: &Path,
    canonical_input: &Path,
    normalized_sha256: &str,
) -> Option<(String, usize)> {
    let manifest =
        serde_json::from_slice::<serde_json::Value>(&fs::read(manifest_path).ok()?).ok()?;
    let schema = manifest.get("schemaVersion")?.as_str()?;
    if schema != "official-context-sync-v2"
        || manifest.get("outputSha256")?.as_str()? != normalized_sha256
    {
        return None;
    }
    let sources = manifest.get("sources")?.as_array()?;
    if !["sec", "fred"].iter().all(|required| {
        sources
            .iter()
            .any(|source| source.as_str() == Some(required))
    }) {
        return None;
    }
    let relative_output = Path::new(manifest.get("outputRelativeToDataRoot")?.as_str()?);
    if relative_output.is_absolute() {
        return None;
    }
    let manifest_output = fs::canonicalize(canonical_data_root.join(relative_output)).ok()?;
    if manifest_output != canonical_input || !manifest_output.starts_with(canonical_data_root) {
        return None;
    }
    let canonical_raw_root =
        fs::canonicalize(canonical_data_root.join("raw/official_context")).ok()?;
    if !canonical_raw_root.starts_with(canonical_data_root) {
        return None;
    }
    let artifacts = manifest.get("rawArtifacts")?.as_array()?;
    if artifacts.is_empty() {
        return None;
    }
    let mut providers = BTreeSet::new();
    for artifact in artifacts {
        let provider = artifact.get("provider")?.as_str()?;
        let expected = artifact.get("sha256")?.as_str()?;
        let relative = Path::new(artifact.get("pathRelativeToDataRoot")?.as_str()?);
        if !matches!(provider, "sec" | "fred")
            || !valid_nonzero_sha256(expected)
            || relative.is_absolute()
        {
            return None;
        }
        let file = fs::canonicalize(canonical_data_root.join(relative)).ok()?;
        if !file.starts_with(&canonical_raw_root)
            || !sha256_hex(&fs::read(file).ok()?).eq_ignore_ascii_case(expected)
        {
            return None;
        }
        providers.insert(provider);
    }
    if !["sec", "fred"]
        .iter()
        .all(|provider| providers.contains(provider))
    {
        return None;
    }
    Some((schema.to_string(), artifacts.len()))
}

/// Verifies the normalized SEC/ALFRED archive against a v2 sync manifest and
/// every content-addressed raw response. Model readiness must remain false
/// when this chain cannot be reproduced from disk.
pub fn verify_official_archive(
    input_path: &Path,
    manifest_root: &Path,
) -> OfficialContextArchiveVerification {
    let blocked = |reason: &str| {
        OfficialContextArchiveVerification {
        verified: false,
        schema_version: None,
        manifest_path: None,
        normalized_sha256: None,
        raw_artifacts_verified: 0,
        reason_codes: vec![reason.to_string()],
        truth: "Context rows are not model-ready until normalized output and every referenced raw official response reproduce a v2 manifest.".to_string(),
    }
    };
    let Ok(normalized_bytes) = fs::read(input_path) else {
        return blocked("OFFICIAL_CONTEXT_NORMALIZED_ARCHIVE_ABSENT");
    };
    let normalized_sha256 = sha256_hex(&normalized_bytes);
    let (Ok(canonical_input), Ok(canonical_manifest_root)) = (
        fs::canonicalize(input_path),
        fs::canonicalize(manifest_root),
    ) else {
        return blocked("OFFICIAL_CONTEXT_MANIFEST_ROOT_ABSENT");
    };
    let Some(data_root) = canonical_manifest_root.parent() else {
        return blocked("OFFICIAL_CONTEXT_DATA_ROOT_INVALID");
    };
    let canonical_data_root = data_root.to_path_buf();
    if !canonical_input.starts_with(&canonical_data_root) {
        return blocked("OFFICIAL_CONTEXT_OUTPUT_OUTSIDE_DATA_ROOT");
    }
    let Ok(entries) = fs::read_dir(&canonical_manifest_root) else {
        return blocked("OFFICIAL_CONTEXT_MANIFEST_DIRECTORY_UNREADABLE");
    };
    let mut candidates = entries
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| {
                    name.starts_with("official_context_sync_") && name.ends_with(".json")
                })
        })
        .collect::<Vec<_>>();
    candidates.sort();
    candidates.reverse();
    for manifest_path in candidates {
        if let Some((schema_version, raw_artifacts_verified)) = verified_manifest_candidate(
            &manifest_path,
            &canonical_data_root,
            &canonical_input,
            &normalized_sha256,
        ) {
            return OfficialContextArchiveVerification {
                verified: true,
                schema_version: Some(schema_version),
                manifest_path: Some(manifest_path.display().to_string()),
                normalized_sha256: Some(normalized_sha256),
                raw_artifacts_verified,
                reason_codes: Vec::new(),
                truth: "Normalized context and all referenced raw SEC/ALFRED responses reproduce the selected immutable manifest.".to_string(),
            };
        }
    }
    let mut report = blocked("NO_MATCHING_VERIFIED_OFFICIAL_CONTEXT_MANIFEST");
    report.normalized_sha256 = Some(normalized_sha256);
    report
}

fn parse_observations(text: &str) -> Result<Vec<ContextObservation>> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Ok(Vec::new());
    }
    if trimmed.starts_with('[') {
        return serde_json::from_str(trimmed).context("invalid context JSON array");
    }
    trimmed
        .lines()
        .enumerate()
        .filter(|(_, line)| !line.trim().is_empty())
        .map(|(index, line)| {
            serde_json::from_str(line)
                .with_context(|| format!("invalid context JSONL at line {}", index + 1))
        })
        .collect()
}

pub fn load(path: &Path) -> Result<Vec<ContextObservation>> {
    let text = fs::read_to_string(path)
        .with_context(|| format!("failed reading context feed {}", path.display()))?;
    parse_observations(&text)
}

/// Raw point-in-time selection used only for auditing and policy decisions.
/// Values from this map must never be serialized as fusion features.
fn latest_auditable_by_field_as_of(
    observations: &[ContextObservation],
    cutoff: DateTime<Utc>,
) -> BTreeMap<String, ContextObservation> {
    let mut latest = BTreeMap::<String, ContextObservation>::new();
    let mut ambiguous_keys = BTreeSet::new();
    for row in observations.iter().filter(|row| {
        row.validate_auditable().is_ok() && row.event_time <= cutoff && row.available_time <= cutoff
    }) {
        let key = row.key();
        if let Some(current) = latest.get(&key) {
            let row_order = (row.event_time, row.available_time);
            let current_order = (current.event_time, current.available_time);
            if row_order == current_order && row != current {
                ambiguous_keys.insert(key.clone());
                continue;
            }
        }
        let replace = latest.get(&key).is_none_or(|current: &ContextObservation| {
            (row.event_time, row.available_time) > (current.event_time, current.available_time)
        });
        if replace {
            latest.insert(key, row.clone());
        }
    }
    for key in ambiguous_keys {
        latest.remove(&key);
    }
    latest
}

/// Sole join primitive exposed to model and UI feature consumers. Selection
/// happens before authorization so a newer denial/restriction suppresses an
/// older permitted value instead of silently falling back to stale data.
pub fn latest_by_field_as_of(
    observations: &[ContextObservation],
    cutoff: DateTime<Utc>,
) -> BTreeMap<String, ContextObservation> {
    let mut history_by_key = BTreeMap::<String, Vec<&ContextObservation>>::new();
    for row in observations.iter().filter(|row| {
        row.validate_auditable().is_ok() && row.event_time <= cutoff && row.available_time <= cutoff
    }) {
        history_by_key.entry(row.key()).or_default().push(row);
    }
    latest_auditable_by_field_as_of(observations, cutoff)
        .into_iter()
        .filter(|(key, row)| {
            row.is_model_input_authorized()
                && history_by_key.get(key).is_some_and(|history| {
                    revision_chain_is_valid(history)
                        && history
                            .iter()
                            .all(|observation| observation.is_model_input_authorized())
                })
        })
        .collect()
}

fn revision_chain_is_valid(values: &[&ContextObservation]) -> bool {
    let mut revisions = BTreeMap::<String, &ContextObservation>::new();
    for row in values {
        let Some(revision_id) = row.revision_id.as_ref() else {
            return false;
        };
        if revisions.insert(revision_id.clone(), row).is_some() {
            return false;
        }
    }
    for row in values {
        if let Some(parent_id) = &row.supersedes_revision_id {
            let Some(parent) = revisions.get(parent_id) else {
                return false;
            };
            if parent.event_time != row.event_time || parent.available_time >= row.available_time {
                return false;
            }
        } else if values.iter().any(|candidate| {
            candidate.event_time == row.event_time && candidate.available_time < row.available_time
        }) {
            return false;
        }
    }
    true
}

pub fn audit(
    path: &Path,
    config: &ContextFeedConfig,
    cutoff: DateTime<Utc>,
) -> Result<ContextAuditReport> {
    let rows = load(path)?;
    let input_observations = rows.len();
    let accepted = rows
        .iter()
        .filter(|row| row.validate_auditable().is_ok())
        .cloned()
        .collect::<Vec<_>>();
    let rejected_observations = input_observations - accepted.len();
    let unavailable_at_cutoff = accepted
        .iter()
        .filter(|row| row.event_time > cutoff || row.available_time > cutoff)
        .count();
    let auditable_observations_as_of = accepted
        .iter()
        .filter(|row| row.event_time <= cutoff && row.available_time <= cutoff)
        .count();
    let model_input_authorized_observations_as_of = accepted
        .iter()
        .filter(|row| {
            row.event_time <= cutoff
                && row.available_time <= cutoff
                && row.is_model_input_authorized()
        })
        .count();
    let policy_excluded_observations_as_of =
        auditable_observations_as_of - model_input_authorized_observations_as_of;
    let mut grouped: BTreeMap<String, Vec<&ContextObservation>> = BTreeMap::new();
    for row in accepted
        .iter()
        .filter(|row| row.event_time <= cutoff && row.available_time <= cutoff)
    {
        grouped.entry(row.key()).or_default().push(row);
    }

    let revision_count = accepted
        .iter()
        .filter(|row| {
            row.event_time <= cutoff
                && row.available_time <= cutoff
                && row.supersedes_revision_id.is_some()
        })
        .count();
    let mut domain_counts = BTreeMap::<String, usize>::new();
    for row in accepted
        .iter()
        .filter(|row| row.event_time <= cutoff && row.available_time <= cutoff)
    {
        *domain_counts
            .entry(format!("{:?}", row.domain).to_ascii_uppercase())
            .or_default() += 1;
    }

    let mut fields = Vec::new();
    for (key, mut values) in grouped {
        values.sort_by_key(|row| (row.event_time, row.available_time));
        let dates = values
            .iter()
            .map(|row| row.event_time.date_naive())
            .collect::<BTreeSet<NaiveDate>>();
        let upstream_vendor_disclosed = values.iter().all(|row| {
            row.upstream_vendor
                .as_deref()
                .is_some_and(|vendor| !vendor.trim().is_empty())
        });
        let point_in_time_joinable = values
            .iter()
            .all(|row| row.available_time >= row.event_time);
        let revision_chain_valid = revision_chain_is_valid(&values);
        let model_use_authorized = values.iter().all(|row| row.is_model_input_authorized());
        let exact_or_conservative_availability = values.iter().all(|row| {
            matches!(
                row.availability_precision,
                AvailabilityPrecision::ExactTimestamp
                    | AvailabilityPrecision::ConservativeDateClose
            )
        });
        let mut reason_codes = Vec::new();
        if dates.len() < config.minimum_history_days {
            reason_codes.push("INSUFFICIENT_POINT_IN_TIME_HISTORY".to_string());
        }
        if config.require_upstream_vendor && !upstream_vendor_disclosed {
            reason_codes.push("UPSTREAM_VENDOR_UNDISCLOSED".to_string());
        }
        if !point_in_time_joinable {
            reason_codes.push("AVAILABILITY_SEMANTICS_INVALID".to_string());
        }
        if !revision_chain_valid {
            reason_codes.push("REVISION_CHAIN_INCOMPLETE".to_string());
        }
        if !model_use_authorized {
            reason_codes.push("MODEL_USE_NOT_AUTHORIZED".to_string());
        }
        if !exact_or_conservative_availability {
            reason_codes.push("AVAILABILITY_PRECISION_NOT_MODEL_SAFE".to_string());
        }
        let model_feature_eligible = reason_codes.is_empty();
        let first = values.first().copied();
        let last = values.last().copied();
        fields.push(ContextFieldAudit {
            key,
            route: last.map_or_else(String::new, |row| row.route.clone()),
            domain: last.map_or(ContextDomain::Unknown, |row| row.domain),
            frequency: last.map_or(ContextFrequency::Snapshot, |row| row.frequency),
            observations_available_as_of: values.len(),
            unique_event_dates: dates.len(),
            first_event_time: first.map(|row| row.event_time),
            last_event_time: last.map(|row| row.event_time),
            last_available_time: last.map(|row| row.available_time),
            upstream_vendor_disclosed,
            point_in_time_joinable,
            revision_chain_valid,
            model_use_authorized,
            exact_or_conservative_availability,
            model_feature_eligible,
            reason_codes,
        });
    }
    let model_eligible_fields = fields
        .iter()
        .filter(|field| field.model_feature_eligible)
        .map(|field| field.key.clone())
        .collect::<Vec<_>>();
    let status = if accepted.is_empty() {
        "NO_CONTEXT_DATA"
    } else if model_eligible_fields.is_empty() {
        "CONTEXT_RESEARCH_ONLY"
    } else {
        "CONTEXT_MODEL_ELIGIBLE"
    };
    Ok(ContextAuditReport {
        generated_at: Utc::now(),
        observation_cutoff: cutoff,
        provider: config.provider.clone(),
        input_path: path.display().to_string(),
        status: status.to_string(),
        input_observations,
        accepted_observations: accepted.len(),
        rejected_observations,
        unavailable_at_cutoff,
        auditable_observations_as_of,
        model_input_authorized_observations_as_of,
        policy_excluded_observations_as_of,
        revision_count,
        domain_counts,
        model_eligible_fields,
        fields,
        allowed_uses: vec![
            "display with explicit as-of timestamps only when the row license permits display"
                .to_string(),
            "regime research after a point-in-time audit".to_string(),
            "lagged daily features using only values available before the forecast cutoff"
                .to_string(),
        ],
        prohibited_uses: vec![
            "execution pricing or NBBO claims".to_string(),
            "historical backtesting from a current-only snapshot".to_string(),
            "same-day final RSI/SMA before that daily bar was complete".to_string(),
            "model promotion without walk-forward ablation".to_string(),
            "serialization of policy-excluded values into model or UI fusion features".to_string(),
        ],
    })
}

pub fn fusion_snapshot(
    path: &Path,
    config: &ContextFeedConfig,
    cutoff: DateTime<Utc>,
) -> Result<ContextFusionSnapshot> {
    let rows = load(path)?;
    let report = audit(path, config, cutoff)?;
    let auditable_latest_field_count = latest_auditable_by_field_as_of(&rows, cutoff).len();
    let latest = latest_by_field_as_of(&rows, cutoff);
    let model_join_latest_field_count = latest.len();
    let audit_by_key = report
        .fields
        .iter()
        .map(|field| (field.key.clone(), field))
        .collect::<BTreeMap<_, _>>();
    let mut latest_features = latest
        .into_iter()
        .filter_map(|(key, row)| {
            let field_audit = audit_by_key.get(&key)?;
            if !field_audit.model_feature_eligible {
                return None;
            }
            Some(ContextFusionFeature {
                key,
                domain: row.domain,
                value: row.value,
                units: row.units,
                event_time: row.event_time,
                available_time: row.available_time,
                received_time: row.received_time,
                provider: row.provider,
                upstream_vendor: row.upstream_vendor,
                source_record_id: row.source_record_id,
                revision_id: row.revision_id,
                availability_precision: row.availability_precision,
                model_feature_eligible: true,
                reason_codes: Vec::new(),
            })
        })
        .collect::<Vec<_>>();
    latest_features.sort_by(|left, right| left.key.cmp(&right.key));
    let mut model_eligible_domain_counts = BTreeMap::<String, usize>::new();
    for feature in &latest_features {
        *model_eligible_domain_counts
            .entry(format!("{:?}", feature.domain).to_ascii_uppercase())
            .or_default() += 1;
    }
    let model_eligible_fields = latest_features
        .iter()
        .map(|feature| feature.key.clone())
        .collect::<Vec<_>>();
    let model_eligible_feature_count = latest_features.len();
    let point_in_time_ready =
        report.status == "CONTEXT_MODEL_ELIGIBLE" && model_eligible_feature_count > 0;
    let mut reason_codes = Vec::new();
    if report.auditable_observations_as_of == 0 {
        reason_codes.push("NO_CONTEXT_OBSERVATIONS_AS_OF_CUTOFF".to_string());
    }
    if model_eligible_feature_count == 0 {
        reason_codes.push("NO_MODEL_ELIGIBLE_CONTEXT_FIELDS".to_string());
    }
    if report.policy_excluded_observations_as_of > 0 {
        reason_codes.push("NON_MODEL_INPUT_CONTEXT_ROWS_EXCLUDED".to_string());
    }
    if auditable_latest_field_count > model_join_latest_field_count {
        reason_codes.push("LATEST_FIELDS_EXCLUDED_BY_MODEL_INPUT_POLICY".to_string());
    }
    if model_join_latest_field_count > model_eligible_feature_count {
        reason_codes.push("MODEL_INPUT_FIELDS_FAILED_CONTEXT_AUDIT".to_string());
    }
    if report.rejected_observations > 0 {
        reason_codes.push("INVALID_CONTEXT_ROWS_REJECTED".to_string());
    }
    Ok(ContextFusionSnapshot {
        status: if point_in_time_ready {
            "READY"
        } else if report.auditable_observations_as_of > 0 {
            "RESEARCH_ONLY"
        } else {
            "BLOCKED"
        }
        .to_string(),
        as_of: cutoff,
        provider: report.provider,
        input_path: report.input_path,
        point_in_time_ready,
        observation_count: report.auditable_observations_as_of,
        audited_observation_count: report.auditable_observations_as_of,
        model_input_authorized_observation_count: report.model_input_authorized_observations_as_of,
        policy_excluded_observation_count: report.policy_excluded_observations_as_of,
        model_eligible_feature_count,
        model_eligible_fields,
        latest_features,
        model_eligible_domain_counts,
        domain_counts: report.domain_counts,
        reason_codes,
        prohibited_uses: report.prohibited_uses,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Datelike, TimeZone};

    fn row(day: u32, available_hour: u32) -> ContextObservation {
        ContextObservation {
            symbol: "^VIX".into(),
            field: "close".into(),
            value: 17.9,
            event_time: Utc.with_ymd_and_hms(2026, 7, day, 20, 0, 0).unwrap(),
            available_time: Utc
                .with_ymd_and_hms(2026, 7, day, available_hour, 1, 0)
                .unwrap(),
            received_time: None,
            provider: "alva".into(),
            route: "macro-and-economics".into(),
            upstream_vendor: Some("DISCLOSED_TEST_VENDOR".into()),
            frequency: ContextFrequency::Daily,
            units: Some("index_points".into()),
            adjusted: None,
            revision_id: Some(format!("rev-{day}-{available_hour}")),
            supersedes_revision_id: None,
            domain: ContextDomain::Market,
            availability_precision: AvailabilityPrecision::ExactTimestamp,
            source_record_id: Some(format!("record-{day}-{available_hour}")),
            payload_sha256: Some("a".repeat(64)),
            license_class: LicenseClass::LicensedInternalModel,
            feature_use: FeatureUse::ModelCandidate,
        }
    }

    #[test]
    fn causal_join_excludes_values_not_yet_available() {
        let rows = vec![row(1, 20), row(2, 21)];
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 2, 20, 30, 0).unwrap();
        let joined = latest_by_field_as_of(&rows, cutoff);
        assert_eq!(joined["^VIX:close"].event_time.day(), 1);
    }

    #[test]
    fn validation_rejects_available_before_event() {
        let mut invalid = row(1, 20);
        invalid.available_time = invalid.event_time - chrono::Duration::seconds(1);
        assert!(invalid.validate().is_err());
    }

    #[test]
    fn current_snapshot_cannot_be_promoted_without_history() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("context.json");
        fs::write(&path, serde_json::to_vec(&vec![row(1, 20)]).unwrap()).unwrap();
        let config = ContextFeedConfig {
            minimum_history_days: 2,
            ..ContextFeedConfig::default()
        };
        let report = audit(
            &path,
            &config,
            Utc.with_ymd_and_hms(2026, 7, 3, 0, 0, 0).unwrap(),
        )
        .unwrap();
        assert_eq!(report.status, "CONTEXT_RESEARCH_ONLY");
        assert!(report.model_eligible_fields.is_empty());
    }

    #[test]
    fn ingestion_time_only_cannot_be_a_model_candidate() {
        let mut invalid = row(1, 20);
        invalid.availability_precision = AvailabilityPrecision::IngestionTimeOnly;
        assert!(invalid.validate().is_err());
    }

    #[test]
    fn later_revision_is_visible_only_after_its_availability() {
        let original = row(1, 20);
        let mut revision = row(1, 21);
        revision.value = 18.5;
        revision.supersedes_revision_id = original.revision_id.clone();
        let rows = vec![original, revision];
        let before_revision =
            latest_by_field_as_of(&rows, Utc.with_ymd_and_hms(2026, 7, 1, 20, 30, 0).unwrap());
        assert_eq!(before_revision["^VIX:close"].value, 17.9);
        let after_revision =
            latest_by_field_as_of(&rows, Utc.with_ymd_and_hms(2026, 7, 1, 21, 30, 0).unwrap());
        assert_eq!(after_revision["^VIX:close"].value, 18.5);
    }

    #[test]
    fn complete_history_can_create_ready_fusion_snapshot() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("context.json");
        fs::write(
            &path,
            serde_json::to_vec(&vec![row(1, 20), row(2, 20)]).unwrap(),
        )
        .unwrap();
        let config = ContextFeedConfig {
            minimum_history_days: 2,
            ..ContextFeedConfig::default()
        };
        let snapshot = fusion_snapshot(
            &path,
            &config,
            Utc.with_ymd_and_hms(2026, 7, 3, 0, 0, 0).unwrap(),
        )
        .unwrap();
        assert_eq!(snapshot.status, "READY");
        assert!(snapshot.point_in_time_ready);
        assert_eq!(snapshot.latest_features.len(), 1);
    }

    #[test]
    fn restricted_and_display_only_values_never_cross_fusion_boundary() {
        let mut allowed = row(1, 20);
        allowed.symbol = "ALLOWED".into();
        let mut restricted = row(1, 20);
        restricted.symbol = "RESTRICTED".into();
        restricted.value = 987_654.321;
        restricted.license_class = LicenseClass::Restricted;
        let mut display_only = row(1, 20);
        display_only.symbol = "DISPLAY_ONLY".into();
        display_only.value = 123_456.789;
        display_only.license_class = LicenseClass::LicensedDisplayOnly;
        display_only.feature_use = FeatureUse::DisplayOnly;

        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("context.json");
        fs::write(
            &path,
            serde_json::to_vec(&vec![allowed, restricted, display_only]).unwrap(),
        )
        .unwrap();
        let config = ContextFeedConfig {
            minimum_history_days: 1,
            ..ContextFeedConfig::default()
        };
        let snapshot = fusion_snapshot(
            &path,
            &config,
            Utc.with_ymd_and_hms(2026, 7, 2, 0, 0, 0).unwrap(),
        )
        .unwrap();

        assert_eq!(snapshot.audited_observation_count, 3);
        assert_eq!(snapshot.model_input_authorized_observation_count, 1);
        assert_eq!(snapshot.policy_excluded_observation_count, 2);
        assert_eq!(snapshot.model_eligible_feature_count, 1);
        assert_eq!(snapshot.latest_features[0].key, "ALLOWED:close");
        assert_eq!(
            snapshot.model_eligible_domain_counts.get("MARKET"),
            Some(&1)
        );
        assert_eq!(
            snapshot
                .model_eligible_domain_counts
                .values()
                .sum::<usize>(),
            1
        );
        let encoded = serde_json::to_string(&snapshot).unwrap();
        assert!(!encoded.contains("987654.321"));
        assert!(!encoded.contains("123456.789"));
        assert!(!encoded.contains("RESTRICTED:close"));
        assert!(!encoded.contains("DISPLAY_ONLY:close"));
    }

    #[test]
    fn newer_policy_denial_suppresses_older_permitted_value() {
        let original = row(1, 20);
        let mut denied_revision = row(1, 21);
        denied_revision.value = 999_999.0;
        denied_revision.supersedes_revision_id = original.revision_id.clone();
        denied_revision.license_class = LicenseClass::Restricted;
        denied_revision.feature_use = FeatureUse::Prohibited;
        let joined = latest_by_field_as_of(
            &[original, denied_revision],
            Utc.with_ymd_and_hms(2026, 7, 1, 22, 0, 0).unwrap(),
        );
        assert!(!joined.contains_key("^VIX:close"));
    }

    #[test]
    fn zero_placeholder_hash_is_not_valid_lineage() {
        let mut invalid = row(1, 20);
        invalid.payload_sha256 = Some("0".repeat(64));
        assert!(invalid.validate_auditable().is_err());
        assert!(!invalid.is_model_input_authorized());
    }

    #[test]
    fn context_keys_are_canonical_across_symbol_and_field_case() {
        let mut mixed = row(1, 20);
        mixed.symbol = " spy ".into();
        mixed.field = " Close ".into();
        assert_eq!(mixed.key(), "SPY:close");
    }

    #[test]
    fn official_archive_requires_matching_output_and_raw_artifact_hashes() {
        let dir = tempfile::tempdir().unwrap();
        let data_root = dir.path().join("data");
        let context_root = data_root.join("context");
        let manifest_root = data_root.join("manifests");
        let raw_root = data_root.join("raw/official_context");
        fs::create_dir_all(&context_root).unwrap();
        fs::create_dir_all(&manifest_root).unwrap();
        fs::create_dir_all(raw_root.join("sec")).unwrap();
        fs::create_dir_all(raw_root.join("fred")).unwrap();

        let input_path = context_root.join("official_observations.jsonl");
        let normalized = b"{\"verified\":true}\n";
        fs::write(&input_path, normalized).unwrap();
        let sec_raw = b"{\"sec\":true}";
        let fred_raw = b"{\"fred\":true}";
        let sec_hash = sha256_hex(sec_raw);
        let fred_hash = sha256_hex(fred_raw);
        fs::write(
            raw_root.join("sec").join(format!("{sec_hash}.json")),
            sec_raw,
        )
        .unwrap();
        fs::write(
            raw_root.join("fred").join(format!("{fred_hash}.json")),
            fred_raw,
        )
        .unwrap();
        let manifest = serde_json::json!({
            "schemaVersion":"official-context-sync-v2",
            "sources":["fred","sec"],
            "outputSha256":sha256_hex(normalized),
            "outputRelativeToDataRoot":"context/official_observations.jsonl",
            "rawArtifacts":[
                {"provider":"sec","sha256":sec_hash,"pathRelativeToDataRoot":format!("raw/official_context/sec/{sec_hash}.json")},
                {"provider":"fred","sha256":fred_hash,"pathRelativeToDataRoot":format!("raw/official_context/fred/{fred_hash}.json")}
            ]
        });
        fs::write(
            manifest_root.join("official_context_sync_test.json"),
            serde_json::to_vec(&manifest).unwrap(),
        )
        .unwrap();

        let verified = verify_official_archive(&input_path, &manifest_root);
        assert!(verified.verified);
        assert_eq!(verified.raw_artifacts_verified, 2);

        fs::write(&input_path, b"tampered\n").unwrap();
        let rejected = verify_official_archive(&input_path, &manifest_root);
        assert!(!rejected.verified);
        assert!(
            rejected
                .reason_codes
                .contains(&"NO_MATCHING_VERIFIED_OFFICIAL_CONTEXT_MANIFEST".to_string())
        );
    }
}
