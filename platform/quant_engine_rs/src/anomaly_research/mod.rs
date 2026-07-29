//! Durable research-candidate records and anti-overfitting controls.
//!
//! This module deliberately separates discovery metadata from evidence. A
//! deterministic hypothesis identity is derived only from the predeclared
//! research question; observed performance can never change that identity.
//! All dataset roles are explicit, failed candidates remain representable, and
//! paper eligibility is impossible while the negative-control matrix is
//! incomplete or while a placebo/random control reproduces the candidate.

use std::{
    collections::{BTreeMap, BTreeSet},
    error::Error,
    fmt,
    path::Path,
};

use anyhow::{Context, Result as AnyResult, bail};
use chrono::{DateTime, NaiveDate, Utc};
use parking_lot::Mutex;
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const RESEARCH_HYPOTHESIS_SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum HypothesisStatus {
    Discovered,
    Screened,
    ValidationFailed,
    TestFailed,
    ExperimentalSignal,
    ForwardShadow,
    Decayed,
    Rejected,
    PaperEligible,
}

impl HypothesisStatus {
    fn can_transition_to(self, next: Self) -> bool {
        use HypothesisStatus::{
            Decayed, Discovered, ExperimentalSignal, ForwardShadow, PaperEligible, Rejected,
            Screened, TestFailed, ValidationFailed,
        };
        matches!(
            (self, next),
            (Discovered, Screened | Rejected)
                | (Screened, ValidationFailed | ExperimentalSignal | Rejected)
                | (ExperimentalSignal, TestFailed | ForwardShadow | Rejected)
                | (ForwardShadow, PaperEligible | Decayed | Rejected)
                | (PaperEligible, Decayed | Rejected)
        )
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DatasetPartition {
    Discovery,
    Train,
    Validation,
    Calibration,
    Test,
    ForwardShadow,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DatasetReference {
    pub dataset_id: String,
    pub dataset_version: String,
    pub sha256: String,
    pub partition: DatasetPartition,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub sample_count: usize,
    pub point_in_time: bool,
    pub untouched_when_assigned: bool,
}

/// Explicit partition assignment prevents a discovery set from being silently
/// relabeled as an untouched test set after its results have been inspected.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DatasetAssignments {
    pub discovery: DatasetReference,
    pub train: DatasetReference,
    pub validation: DatasetReference,
    pub calibration: Option<DatasetReference>,
    pub test: DatasetReference,
    pub forward_shadow: Option<DatasetReference>,
}

impl DatasetAssignments {
    pub fn validate(&self) -> Result<(), AnomalyResearchError> {
        let required = [
            (&self.discovery, DatasetPartition::Discovery),
            (&self.train, DatasetPartition::Train),
            (&self.validation, DatasetPartition::Validation),
            (&self.test, DatasetPartition::Test),
        ];
        for (dataset, expected) in required {
            validate_dataset(dataset, expected)?;
        }
        if let Some(dataset) = &self.calibration {
            validate_dataset(dataset, DatasetPartition::Calibration)?;
        }
        if let Some(dataset) = &self.forward_shadow {
            validate_dataset(dataset, DatasetPartition::ForwardShadow)?;
        }
        if !self.test.untouched_when_assigned {
            return Err(AnomalyResearchError::InvalidDataset(
                "test partition must be untouched when assigned".into(),
            ));
        }
        if self
            .forward_shadow
            .as_ref()
            .is_some_and(|dataset| !dataset.untouched_when_assigned)
        {
            return Err(AnomalyResearchError::InvalidDataset(
                "forward-shadow partition must be untouched when assigned".into(),
            ));
        }

        validate_partition_order(&self.discovery, &self.train)?;
        validate_partition_order(&self.train, &self.validation)?;
        if let Some(calibration) = &self.calibration {
            validate_partition_order(&self.validation, calibration)?;
            validate_partition_order(calibration, &self.test)?;
        } else {
            validate_partition_order(&self.validation, &self.test)?;
        }
        if let Some(forward_shadow) = &self.forward_shadow {
            validate_partition_order(&self.test, forward_shadow)?;
        }
        Ok(())
    }
}

fn validate_partition_order(
    earlier: &DatasetReference,
    later: &DatasetReference,
) -> Result<(), AnomalyResearchError> {
    if earlier.end_date >= later.start_date {
        return Err(AnomalyResearchError::InvalidDataset(format!(
            "{:?} must end before {:?} starts; ranges overlap or are out of order",
            earlier.partition, later.partition
        )));
    }
    Ok(())
}

fn validate_dataset(
    dataset: &DatasetReference,
    expected: DatasetPartition,
) -> Result<(), AnomalyResearchError> {
    if dataset.partition != expected {
        return Err(AnomalyResearchError::InvalidDataset(format!(
            "expected {expected:?}, found {:?}",
            dataset.partition
        )));
    }
    if dataset.dataset_id.trim().is_empty()
        || dataset.dataset_version.trim().is_empty()
        || dataset.sha256.len() != 64
        || !dataset.sha256.bytes().all(|byte| byte.is_ascii_hexdigit())
        || dataset.start_date > dataset.end_date
        || dataset.sample_count == 0
        || !dataset.point_in_time
    {
        return Err(AnomalyResearchError::InvalidDataset(format!(
            "invalid dataset reference {}",
            dataset.dataset_id
        )));
    }
    Ok(())
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HypothesisIdentity {
    pub feature_specification: Vec<String>,
    pub target: String,
    pub symbol: String,
    pub horizon_minutes: usize,
    pub regime_filter: Option<String>,
    pub sample_eligibility: String,
    pub multiple_testing_family: String,
}

impl HypothesisIdentity {
    pub fn validate(&self) -> Result<(), AnomalyResearchError> {
        if self.feature_specification.is_empty()
            || self.target.trim().is_empty()
            || self.symbol.trim().is_empty()
            || self.horizon_minutes == 0
            || self.sample_eligibility.trim().is_empty()
            || self.multiple_testing_family.trim().is_empty()
        {
            return Err(AnomalyResearchError::InvalidIdentity);
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ConfidenceInterval {
    pub lower: f64,
    pub upper: f64,
    pub confidence_level: f64,
}

impl ConfidenceInterval {
    pub fn excludes_zero_in_effect_direction(&self, effect: f64) -> bool {
        (effect > 0.0 && self.lower > 0.0) || (effect < 0.0 && self.upper < 0.0)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StatusTransition {
    pub from: Option<HypothesisStatus>,
    pub to: HypothesisStatus,
    pub changed_at: DateTime<Utc>,
    pub reason: String,
    pub evidence_hash: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResearchHypothesisRecord {
    pub schema_version: u32,
    pub hypothesis_id: String,
    pub dedup_key: String,
    pub discovery_timestamp: DateTime<Utc>,
    pub identity: HypothesisIdentity,
    pub datasets: DatasetAssignments,
    pub number_of_variants_tried: usize,
    pub raw_p_value: Option<f64>,
    pub fdr_adjusted_p_value: Option<f64>,
    pub effect_size: Option<f64>,
    pub block_bootstrap_ci: Option<ConfidenceInterval>,
    pub expected_turnover: Option<f64>,
    pub assumed_cost_bps: f64,
    pub current_status: HypothesisStatus,
    pub status_history: Vec<StatusTransition>,
    pub notes: Vec<String>,
}

impl ResearchHypothesisRecord {
    pub fn new(
        identity: HypothesisIdentity,
        datasets: DatasetAssignments,
        discovery_timestamp: DateTime<Utc>,
        assumed_cost_bps: f64,
    ) -> Result<Self, AnomalyResearchError> {
        identity.validate()?;
        datasets.validate()?;
        if !assumed_cost_bps.is_finite() || assumed_cost_bps < 0.0 {
            return Err(AnomalyResearchError::InvalidNumericValue(
                "assumed_cost_bps".into(),
            ));
        }
        let hypothesis_id = deterministic_hypothesis_id(&identity)?;
        let dedup_key = deterministic_dedup_key(&identity)?;
        Ok(Self {
            schema_version: RESEARCH_HYPOTHESIS_SCHEMA_VERSION,
            hypothesis_id,
            dedup_key,
            discovery_timestamp,
            identity,
            datasets,
            number_of_variants_tried: 1,
            raw_p_value: None,
            fdr_adjusted_p_value: None,
            effect_size: None,
            block_bootstrap_ci: None,
            expected_turnover: None,
            assumed_cost_bps,
            current_status: HypothesisStatus::Discovered,
            status_history: vec![StatusTransition {
                from: None,
                to: HypothesisStatus::Discovered,
                changed_at: discovery_timestamp,
                reason: "candidate_registered_before_screening".into(),
                evidence_hash: None,
            }],
            notes: Vec::new(),
        })
    }

    pub fn validate(&self) -> Result<(), AnomalyResearchError> {
        if self.schema_version != RESEARCH_HYPOTHESIS_SCHEMA_VERSION {
            return Err(AnomalyResearchError::InvalidRecord(
                "unsupported hypothesis schema version".into(),
            ));
        }
        self.identity.validate()?;
        self.datasets.validate()?;
        if self.hypothesis_id != deterministic_hypothesis_id(&self.identity)?
            || self.dedup_key != deterministic_dedup_key(&self.identity)?
        {
            return Err(AnomalyResearchError::InvalidRecord(
                "deterministic hypothesis identity mismatch".into(),
            ));
        }
        if self.number_of_variants_tried == 0
            || !self.assumed_cost_bps.is_finite()
            || self.assumed_cost_bps < 0.0
        {
            return Err(AnomalyResearchError::InvalidRecord(
                "variant count and assumed costs must be valid".into(),
            ));
        }
        for (name, value) in [
            ("raw_p_value", self.raw_p_value),
            ("fdr_adjusted_p_value", self.fdr_adjusted_p_value),
        ] {
            if value.is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value)) {
                return Err(AnomalyResearchError::InvalidRecord(format!(
                    "{name} must be a probability"
                )));
            }
        }
        for (name, value) in [
            ("effect_size", self.effect_size),
            ("expected_turnover", self.expected_turnover),
        ] {
            if value.is_some_and(|value| !value.is_finite()) {
                return Err(AnomalyResearchError::InvalidRecord(format!(
                    "{name} must be finite"
                )));
            }
        }
        if self.expected_turnover.is_some_and(|value| value < 0.0) {
            return Err(AnomalyResearchError::InvalidRecord(
                "expected_turnover cannot be negative".into(),
            ));
        }
        if self.block_bootstrap_ci.as_ref().is_some_and(|interval| {
            !interval.lower.is_finite()
                || !interval.upper.is_finite()
                || interval.lower > interval.upper
                || !interval.confidence_level.is_finite()
                || !(0.0..=1.0).contains(&interval.confidence_level)
                || interval.confidence_level == 0.0
        }) {
            return Err(AnomalyResearchError::InvalidRecord(
                "block-bootstrap confidence interval is invalid".into(),
            ));
        }
        let first = self.status_history.first().ok_or_else(|| {
            AnomalyResearchError::InvalidRecord("status history cannot be empty".into())
        })?;
        if first.from.is_some()
            || first.to != HypothesisStatus::Discovered
            || first.changed_at != self.discovery_timestamp
        {
            return Err(AnomalyResearchError::InvalidRecord(
                "status history must begin with discovery at discovery_timestamp".into(),
            ));
        }
        for (index, transition) in self.status_history.iter().enumerate() {
            if transition.reason.trim().is_empty()
                || transition.evidence_hash.as_ref().is_some_and(|hash| {
                    hash.len() != 64 || !hash.bytes().all(|byte| byte.is_ascii_hexdigit())
                })
            {
                return Err(AnomalyResearchError::InvalidRecord(format!(
                    "status transition {index} has invalid provenance"
                )));
            }
            if let Some(previous) = index
                .checked_sub(1)
                .and_then(|row| self.status_history.get(row))
                && (transition.from != Some(previous.to)
                    || !previous.to.can_transition_to(transition.to)
                    || transition.changed_at <= previous.changed_at)
            {
                return Err(AnomalyResearchError::InvalidRecord(format!(
                    "status transition {index} is not a valid chronological continuation"
                )));
            }
        }
        if self.status_history.last().map(|row| row.to) != Some(self.current_status) {
            return Err(AnomalyResearchError::InvalidRecord(
                "current status does not match status-history tail".into(),
            ));
        }
        Ok(())
    }

    /// Appends, rather than rewrites, lifecycle state. Terminal failures remain
    /// durable records; a materially changed experiment must receive a new ID.
    pub fn transition(
        &mut self,
        next: HypothesisStatus,
        changed_at: DateTime<Utc>,
        reason: impl Into<String>,
        evidence_hash: Option<String>,
    ) -> Result<(), AnomalyResearchError> {
        self.validate()?;
        let reason = reason.into();
        if reason.trim().is_empty() {
            return Err(AnomalyResearchError::InvalidRecord(
                "status transition reason cannot be empty".into(),
            ));
        }
        if evidence_hash.as_ref().is_some_and(|hash| {
            hash.len() != 64 || !hash.bytes().all(|byte| byte.is_ascii_hexdigit())
        }) {
            return Err(AnomalyResearchError::InvalidRecord(
                "status transition evidence hash must be a SHA-256 hex digest".into(),
            ));
        }
        if self
            .status_history
            .last()
            .is_some_and(|previous| changed_at <= previous.changed_at)
        {
            return Err(AnomalyResearchError::InvalidRecord(
                "status transition timestamps must be strictly increasing".into(),
            ));
        }
        if !self.current_status.can_transition_to(next) {
            return Err(AnomalyResearchError::InvalidStatusTransition {
                from: self.current_status,
                to: next,
            });
        }
        self.status_history.push(StatusTransition {
            from: Some(self.current_status),
            to: next,
            changed_at,
            reason,
            evidence_hash,
        });
        self.current_status = next;
        self.validate()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DeduplicationEntry {
    pub candidate_index: usize,
    pub hypothesis_id: String,
    pub first_seen_index: usize,
    pub duplicate: bool,
}

pub fn deduplicate_identities(
    identities: &[HypothesisIdentity],
) -> Result<Vec<DeduplicationEntry>, AnomalyResearchError> {
    let mut first_seen = BTreeMap::<String, usize>::new();
    identities
        .iter()
        .enumerate()
        .map(|(candidate_index, identity)| {
            let hypothesis_id = deterministic_hypothesis_id(identity)?;
            let first_seen_index = *first_seen
                .entry(hypothesis_id.clone())
                .or_insert(candidate_index);
            Ok(DeduplicationEntry {
                candidate_index,
                hypothesis_id,
                first_seen_index,
                duplicate: first_seen_index != candidate_index,
            })
        })
        .collect()
}

pub fn deterministic_hypothesis_id(
    identity: &HypothesisIdentity,
) -> Result<String, AnomalyResearchError> {
    let digest = identity_digest(identity)?;
    Ok(format!("HYP-{}", hex(&digest[..12]).to_ascii_uppercase()))
}

pub fn deterministic_dedup_key(
    identity: &HypothesisIdentity,
) -> Result<String, AnomalyResearchError> {
    Ok(hex(&identity_digest(identity)?))
}

fn identity_digest(identity: &HypothesisIdentity) -> Result<Vec<u8>, AnomalyResearchError> {
    identity.validate()?;
    let mut features = identity
        .feature_specification
        .iter()
        .map(|feature| normalize_token(feature))
        .collect::<Vec<_>>();
    features.sort();
    features.dedup();

    let mut hasher = Sha256::new();
    hash_component(&mut hasher, "AXIO7_RESEARCH_HYPOTHESIS_V1");
    for feature in features {
        hash_component(&mut hasher, &feature);
    }
    hash_component(&mut hasher, &normalize_token(&identity.target));
    hash_component(&mut hasher, &identity.symbol.trim().to_ascii_uppercase());
    hash_component(&mut hasher, &identity.horizon_minutes.to_string());
    hash_component(
        &mut hasher,
        &identity
            .regime_filter
            .as_deref()
            .map(normalize_token)
            .unwrap_or_else(|| "ALL_REGIMES".into()),
    );
    hash_component(&mut hasher, &normalize_token(&identity.sample_eligibility));
    hash_component(
        &mut hasher,
        &normalize_token(&identity.multiple_testing_family),
    );
    Ok(hasher.finalize().to_vec())
}

fn normalize_token(value: &str) -> String {
    value
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

fn hash_component(hasher: &mut Sha256, value: &str) {
    hasher.update((value.len() as u64).to_le_bytes());
    hasher.update(value.as_bytes());
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

pub const HYPOTHESIS_REGISTRY_SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum RegistryAppendDisposition {
    Appended,
    Duplicate,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RegistryAppendOutcome {
    pub hypothesis_id: String,
    pub version_id: String,
    pub version_sequence: usize,
    pub current_status: HypothesisStatus,
    pub disposition: RegistryAppendDisposition,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StoredHypothesisVersion {
    pub version_id: String,
    pub hypothesis_id: String,
    pub dedup_key: String,
    pub version_sequence: usize,
    pub previous_version_id: Option<String>,
    pub current_status: HypothesisStatus,
    pub content_sha256: String,
    pub record: ResearchHypothesisRecord,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HypothesisRegistryAudit {
    pub schema_version: u32,
    pub hypothesis_count: usize,
    pub version_count: usize,
    pub status_transition_count: usize,
    pub terminal_failure_count: usize,
    pub duplicate_append_attempts: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HypothesisRegistryReconstruction {
    pub versions: Vec<StoredHypothesisVersion>,
    pub latest_records: Vec<ResearchHypothesisRecord>,
    pub chain_sha256: String,
    pub audit: HypothesisRegistryAudit,
}

#[derive(Debug)]
struct RawRegistryVersion {
    version_id: String,
    hypothesis_id: String,
    dedup_key: String,
    version_sequence: i64,
    previous_version_id: Option<String>,
    current_status: String,
    content_sha256: String,
    record_json: String,
}

/// Append-only durable registry for research hypotheses.
///
/// Each change is a new immutable version. SQLite triggers reject UPDATE and
/// DELETE, while reconstruction revalidates deterministic IDs, payload hashes,
/// sequence links, immutable research identity, and the status-history prefix.
pub struct DurableHypothesisRegistry {
    connection: Mutex<Connection>,
}

impl DurableHypothesisRegistry {
    pub fn open(path: &Path) -> AnyResult<Self> {
        if let Some(parent) = path
            .parent()
            .filter(|parent| !parent.as_os_str().is_empty())
        {
            std::fs::create_dir_all(parent).with_context(|| {
                format!("create hypothesis registry directory {}", parent.display())
            })?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("open hypothesis registry {}", path.display()))?;
        connection.execute_batch(
            "PRAGMA foreign_keys=ON;
             PRAGMA journal_mode=WAL;
             PRAGMA synchronous=FULL;
             CREATE TABLE IF NOT EXISTS research_hypothesis_versions (
               version_id TEXT PRIMARY KEY,
               hypothesis_id TEXT NOT NULL,
               dedup_key TEXT NOT NULL,
               version_sequence INTEGER NOT NULL CHECK(version_sequence > 0),
               previous_version_id TEXT REFERENCES research_hypothesis_versions(version_id),
               current_status TEXT NOT NULL,
               discovery_timestamp TEXT NOT NULL,
               appended_at TEXT NOT NULL,
               content_sha256 TEXT NOT NULL UNIQUE,
               record_json TEXT NOT NULL,
               UNIQUE(hypothesis_id, version_sequence)
             );
             CREATE INDEX IF NOT EXISTS idx_research_hypothesis_latest
               ON research_hypothesis_versions(hypothesis_id, version_sequence DESC);
             CREATE INDEX IF NOT EXISTS idx_research_hypothesis_dedup
               ON research_hypothesis_versions(dedup_key, version_sequence DESC);
             CREATE TABLE IF NOT EXISTS research_hypothesis_append_audit (
               audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
               occurred_at TEXT NOT NULL,
               hypothesis_id TEXT NOT NULL,
               version_id TEXT NOT NULL,
               outcome TEXT NOT NULL,
               detail TEXT NOT NULL
             );
             CREATE TRIGGER IF NOT EXISTS research_hypothesis_versions_no_update
               BEFORE UPDATE ON research_hypothesis_versions BEGIN
                 SELECT RAISE(ABORT, 'RESEARCH_HYPOTHESIS_REGISTRY_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS research_hypothesis_versions_no_delete
               BEFORE DELETE ON research_hypothesis_versions BEGIN
                 SELECT RAISE(ABORT, 'RESEARCH_HYPOTHESIS_REGISTRY_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS research_hypothesis_audit_no_update
               BEFORE UPDATE ON research_hypothesis_append_audit BEGIN
                 SELECT RAISE(ABORT, 'RESEARCH_HYPOTHESIS_AUDIT_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS research_hypothesis_audit_no_delete
               BEFORE DELETE ON research_hypothesis_append_audit BEGIN
                 SELECT RAISE(ABORT, 'RESEARCH_HYPOTHESIS_AUDIT_APPEND_ONLY');
               END;",
        )?;
        Ok(Self {
            connection: Mutex::new(connection),
        })
    }

    pub fn append(&self, record: &ResearchHypothesisRecord) -> AnyResult<RegistryAppendOutcome> {
        record
            .validate()
            .context("validate research hypothesis before durable append")?;
        let (record_json, content_sha256) = hypothesis_record_payload(record)?;
        let version_id = deterministic_version_id(&content_sha256);
        let mut connection = self.connection.lock();
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;

        let duplicate = transaction
            .query_row(
                "SELECT version_id,hypothesis_id,dedup_key,version_sequence,
                        previous_version_id,current_status,content_sha256,record_json
                 FROM research_hypothesis_versions WHERE content_sha256=?1 LIMIT 1",
                params![content_sha256],
                raw_registry_version,
            )
            .optional()?;
        if let Some(raw) = duplicate {
            let stored = decode_registry_version(raw)?;
            append_registry_audit(
                &transaction,
                &stored.hypothesis_id,
                &stored.version_id,
                "DUPLICATE",
                "identical content hash already exists",
            )?;
            transaction.commit()?;
            return Ok(RegistryAppendOutcome {
                hypothesis_id: stored.hypothesis_id,
                version_id: stored.version_id,
                version_sequence: stored.version_sequence,
                current_status: stored.current_status,
                disposition: RegistryAppendDisposition::Duplicate,
            });
        }

        let previous = transaction
            .query_row(
                "SELECT version_id,hypothesis_id,dedup_key,version_sequence,
                        previous_version_id,current_status,content_sha256,record_json
                 FROM research_hypothesis_versions
                 WHERE dedup_key=?1 OR hypothesis_id=?2
                 ORDER BY version_sequence DESC LIMIT 1",
                params![record.dedup_key, record.hypothesis_id],
                raw_registry_version,
            )
            .optional()?
            .map(decode_registry_version)
            .transpose()?;
        let (version_sequence, previous_version_id) = if let Some(previous) = previous {
            if previous.hypothesis_id != record.hypothesis_id
                || previous.dedup_key != record.dedup_key
            {
                bail!("deterministic hypothesis ID/dedup collision in durable registry");
            }
            validate_registry_successor(&previous.record, record)?;
            (previous.version_sequence + 1, Some(previous.version_id))
        } else {
            if record.current_status != HypothesisStatus::Discovered
                || record.status_history.len() != 1
            {
                bail!("first durable version must be the original DISCOVERED record");
            }
            (1, None)
        };
        transaction.execute(
            "INSERT INTO research_hypothesis_versions
             (version_id,hypothesis_id,dedup_key,version_sequence,previous_version_id,
              current_status,discovery_timestamp,appended_at,content_sha256,record_json)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)",
            params![
                version_id,
                record.hypothesis_id,
                record.dedup_key,
                i64::try_from(version_sequence).context("hypothesis version sequence overflow")?,
                previous_version_id,
                status_text(record.current_status),
                record.discovery_timestamp.to_rfc3339(),
                Utc::now().to_rfc3339(),
                content_sha256,
                record_json,
            ],
        )?;
        append_registry_audit(
            &transaction,
            &record.hypothesis_id,
            &version_id,
            "APPENDED",
            &format!("version_sequence={version_sequence}"),
        )?;
        transaction.commit()?;
        Ok(RegistryAppendOutcome {
            hypothesis_id: record.hypothesis_id.clone(),
            version_id,
            version_sequence,
            current_status: record.current_status,
            disposition: RegistryAppendDisposition::Appended,
        })
    }

    pub fn transition(
        &self,
        hypothesis_id: &str,
        next: HypothesisStatus,
        changed_at: DateTime<Utc>,
        reason: impl Into<String>,
        evidence_hash: Option<String>,
    ) -> AnyResult<RegistryAppendOutcome> {
        let mut record = self
            .latest(hypothesis_id)?
            .with_context(|| format!("unknown hypothesis {hypothesis_id}"))?;
        record.transition(next, changed_at, reason, evidence_hash)?;
        self.append(&record)
    }

    pub fn latest(&self, hypothesis_id: &str) -> AnyResult<Option<ResearchHypothesisRecord>> {
        let raw = self
            .connection
            .lock()
            .query_row(
                "SELECT version_id,hypothesis_id,dedup_key,version_sequence,
                        previous_version_id,current_status,content_sha256,record_json
                 FROM research_hypothesis_versions
                 WHERE hypothesis_id=?1 ORDER BY version_sequence DESC LIMIT 1",
                params![hypothesis_id],
                raw_registry_version,
            )
            .optional()?;
        raw.map(decode_registry_version)
            .transpose()
            .map(|row| row.map(|version| version.record))
    }

    pub fn versions(&self, hypothesis_id: &str) -> AnyResult<Vec<StoredHypothesisVersion>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT version_id,hypothesis_id,dedup_key,version_sequence,
                    previous_version_id,current_status,content_sha256,record_json
             FROM research_hypothesis_versions
             WHERE hypothesis_id=?1 ORDER BY version_sequence",
        )?;
        let raw = statement
            .query_map(params![hypothesis_id], raw_registry_version)?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        drop(statement);
        drop(connection);
        raw.into_iter().map(decode_registry_version).collect()
    }

    pub fn latest_records(&self) -> AnyResult<Vec<ResearchHypothesisRecord>> {
        Ok(self.reconstruct()?.latest_records)
    }

    pub fn audit(&self) -> AnyResult<HypothesisRegistryAudit> {
        Ok(self.reconstruct()?.audit)
    }

    pub fn reconstruct(&self) -> AnyResult<HypothesisRegistryReconstruction> {
        let versions = self.load_all_versions()?;
        let mut latest = BTreeMap::<String, StoredHypothesisVersion>::new();
        let mut root_dedup = BTreeMap::<String, String>::new();
        let mut chain = Sha256::new();
        for version in &versions {
            hash_component(&mut chain, &version.version_id);
            hash_component(&mut chain, &version.content_sha256);
            if version.version_sequence == 1 {
                if version.previous_version_id.is_some()
                    || version.record.current_status != HypothesisStatus::Discovered
                    || version.record.status_history.len() != 1
                {
                    bail!("invalid root version for {}", version.hypothesis_id);
                }
                if let Some(other) =
                    root_dedup.insert(version.dedup_key.clone(), version.hypothesis_id.clone())
                    && other != version.hypothesis_id
                {
                    bail!("dedup key is shared by distinct hypotheses");
                }
            } else {
                let previous = latest
                    .get(&version.hypothesis_id)
                    .context("registry version chain starts after sequence one")?;
                if version.version_sequence != previous.version_sequence + 1
                    || version.previous_version_id.as_deref() != Some(previous.version_id.as_str())
                {
                    bail!("registry version sequence/link mismatch");
                }
                validate_registry_successor(&previous.record, &version.record)?;
            }
            latest.insert(version.hypothesis_id.clone(), version.clone());
        }
        let latest_records = latest
            .into_values()
            .map(|version| version.record)
            .collect::<Vec<_>>();
        let duplicate_append_attempts = self.duplicate_attempt_count()?;
        let audit = HypothesisRegistryAudit {
            schema_version: HYPOTHESIS_REGISTRY_SCHEMA_VERSION,
            hypothesis_count: latest_records.len(),
            version_count: versions.len(),
            status_transition_count: latest_records
                .iter()
                .map(|record| record.status_history.len().saturating_sub(1))
                .sum(),
            terminal_failure_count: latest_records
                .iter()
                .filter(|record| {
                    matches!(
                        record.current_status,
                        HypothesisStatus::ValidationFailed
                            | HypothesisStatus::TestFailed
                            | HypothesisStatus::Decayed
                            | HypothesisStatus::Rejected
                    )
                })
                .count(),
            duplicate_append_attempts,
        };
        Ok(HypothesisRegistryReconstruction {
            versions,
            latest_records,
            chain_sha256: hex(&chain.finalize()),
            audit,
        })
    }

    fn load_all_versions(&self) -> AnyResult<Vec<StoredHypothesisVersion>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT version_id,hypothesis_id,dedup_key,version_sequence,
                    previous_version_id,current_status,content_sha256,record_json
             FROM research_hypothesis_versions
             ORDER BY hypothesis_id,version_sequence",
        )?;
        let raw = statement
            .query_map([], raw_registry_version)?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        drop(statement);
        drop(connection);
        raw.into_iter().map(decode_registry_version).collect()
    }

    fn duplicate_attempt_count(&self) -> AnyResult<usize> {
        let count: i64 = self.connection.lock().query_row(
            "SELECT COUNT(*) FROM research_hypothesis_append_audit WHERE outcome='DUPLICATE'",
            [],
            |row| row.get(0),
        )?;
        usize::try_from(count).context("negative registry audit count")
    }
}

fn raw_registry_version(row: &rusqlite::Row<'_>) -> rusqlite::Result<RawRegistryVersion> {
    Ok(RawRegistryVersion {
        version_id: row.get(0)?,
        hypothesis_id: row.get(1)?,
        dedup_key: row.get(2)?,
        version_sequence: row.get(3)?,
        previous_version_id: row.get(4)?,
        current_status: row.get(5)?,
        content_sha256: row.get(6)?,
        record_json: row.get(7)?,
    })
}

fn decode_registry_version(raw: RawRegistryVersion) -> AnyResult<StoredHypothesisVersion> {
    let record: ResearchHypothesisRecord =
        serde_json::from_str(&raw.record_json).context("decode stored research hypothesis")?;
    record
        .validate()
        .context("validate stored research hypothesis")?;
    let (_, expected_content_sha256) = hypothesis_record_payload(&record)?;
    if raw.content_sha256 != expected_content_sha256
        || raw.version_id != deterministic_version_id(&expected_content_sha256)
        || raw.hypothesis_id != record.hypothesis_id
        || raw.dedup_key != record.dedup_key
        || raw.current_status != status_text(record.current_status)
    {
        bail!("stored hypothesis version failed deterministic integrity validation");
    }
    let version_sequence =
        usize::try_from(raw.version_sequence).context("invalid hypothesis version sequence")?;
    if version_sequence == 0 {
        bail!("hypothesis version sequence cannot be zero");
    }
    Ok(StoredHypothesisVersion {
        version_id: raw.version_id,
        hypothesis_id: raw.hypothesis_id,
        dedup_key: raw.dedup_key,
        version_sequence,
        previous_version_id: raw.previous_version_id,
        current_status: record.current_status,
        content_sha256: raw.content_sha256,
        record,
    })
}

fn validate_registry_successor(
    previous: &ResearchHypothesisRecord,
    candidate: &ResearchHypothesisRecord,
) -> AnyResult<()> {
    previous.validate()?;
    candidate.validate()?;
    if previous.schema_version != candidate.schema_version
        || previous.hypothesis_id != candidate.hypothesis_id
        || previous.dedup_key != candidate.dedup_key
        || previous.discovery_timestamp != candidate.discovery_timestamp
        || previous.identity != candidate.identity
        || previous.datasets != candidate.datasets
        || previous.assumed_cost_bps.to_bits() != candidate.assumed_cost_bps.to_bits()
    {
        bail!("immutable hypothesis identity, datasets, or discovery contract changed");
    }
    if candidate.number_of_variants_tried < previous.number_of_variants_tried {
        bail!("number_of_variants_tried cannot decrease");
    }
    if !candidate
        .status_history
        .starts_with(&previous.status_history)
        || candidate.status_history.len() > previous.status_history.len() + 1
    {
        bail!("status history must be an exact append-only prefix extension");
    }
    if !candidate.notes.starts_with(&previous.notes) {
        bail!("research notes must be append-only");
    }
    if candidate == previous {
        bail!("identical hypothesis content should have been handled as a duplicate");
    }
    Ok(())
}

fn hypothesis_record_payload(record: &ResearchHypothesisRecord) -> AnyResult<(String, String)> {
    record.validate()?;
    let record_json = serde_json::to_string(record)?;
    let content_sha256 = hex(&Sha256::digest(record_json.as_bytes()));
    Ok((record_json, content_sha256))
}

fn deterministic_version_id(content_sha256: &str) -> String {
    format!("RHV-{}", content_sha256.to_ascii_uppercase())
}

fn status_text(status: HypothesisStatus) -> &'static str {
    match status {
        HypothesisStatus::Discovered => "DISCOVERED",
        HypothesisStatus::Screened => "SCREENED",
        HypothesisStatus::ValidationFailed => "VALIDATION_FAILED",
        HypothesisStatus::TestFailed => "TEST_FAILED",
        HypothesisStatus::ExperimentalSignal => "EXPERIMENTAL_SIGNAL",
        HypothesisStatus::ForwardShadow => "FORWARD_SHADOW",
        HypothesisStatus::Decayed => "DECAYED",
        HypothesisStatus::Rejected => "REJECTED",
        HypothesisStatus::PaperEligible => "PAPER_ELIGIBLE",
    }
}

fn append_registry_audit(
    transaction: &rusqlite::Transaction<'_>,
    hypothesis_id: &str,
    version_id: &str,
    outcome: &str,
    detail: &str,
) -> AnyResult<()> {
    transaction.execute(
        "INSERT INTO research_hypothesis_append_audit
         (occurred_at,hypothesis_id,version_id,outcome,detail) VALUES (?1,?2,?3,?4,?5)",
        params![
            Utc::now().to_rfc3339(),
            hypothesis_id,
            version_id,
            outcome,
            detail,
        ],
    )?;
    Ok(())
}

/// Benjamini-Hochberg adjusted p-values in the original input order.
pub fn benjamini_hochberg(p_values: &[f64]) -> Result<Vec<f64>, AnomalyResearchError> {
    for &p_value in p_values {
        if !p_value.is_finite() || !(0.0..=1.0).contains(&p_value) {
            return Err(AnomalyResearchError::InvalidProbability(p_value));
        }
    }
    let mut order = (0..p_values.len()).collect::<Vec<_>>();
    order.sort_by(|left, right| p_values[*left].total_cmp(&p_values[*right]));
    let mut adjusted = vec![1.0; p_values.len()];
    let hypotheses = p_values.len().max(1) as f64;
    let mut running_min: f64 = 1.0;
    for sorted_index in (0..order.len()).rev() {
        let original_index = order[sorted_index];
        let rank = sorted_index + 1;
        running_min = running_min.min(p_values[original_index] * hypotheses / rank as f64);
        adjusted[original_index] = running_min.clamp(0.0, 1.0);
    }
    Ok(adjusted)
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct DatedEffect {
    pub session_date: NaiveDate,
    pub value: f64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct BlockBootstrapConfig {
    pub iterations: usize,
    pub confidence_level: f64,
    pub block_length_days: usize,
    pub seed: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BlockBootstrapResult {
    pub estimate: f64,
    pub interval: ConfidenceInterval,
    pub iterations: usize,
    pub block_length_days: usize,
    pub independent_days: usize,
    pub observations: usize,
    pub seed: u64,
}

/// Circular moving-block bootstrap over whole trading-day clusters. Every row
/// from a selected day moves together, so overlapping intraday observations do
/// not masquerade as independent evidence.
pub fn block_bootstrap_mean(
    effects: &[DatedEffect],
    config: BlockBootstrapConfig,
) -> Result<BlockBootstrapResult, AnomalyResearchError> {
    if effects.is_empty()
        || config.iterations == 0
        || config.block_length_days == 0
        || !config.confidence_level.is_finite()
        || !(0.0..1.0).contains(&config.confidence_level)
    {
        return Err(AnomalyResearchError::InvalidBootstrapConfiguration);
    }
    if effects.iter().any(|effect| !effect.value.is_finite()) {
        return Err(AnomalyResearchError::InvalidNumericValue(
            "block_bootstrap_effect".into(),
        ));
    }
    let mut grouped = BTreeMap::<NaiveDate, Vec<f64>>::new();
    for effect in effects {
        grouped
            .entry(effect.session_date)
            .or_default()
            .push(effect.value);
    }
    let days = grouped.into_values().collect::<Vec<_>>();
    let independent_days = days.len();
    let estimate = effects.iter().map(|effect| effect.value).sum::<f64>() / effects.len() as f64;
    let mut rng = SplitMix64(config.seed);
    let mut means = Vec::with_capacity(config.iterations);
    for _ in 0..config.iterations {
        let mut sampled_days = 0;
        let mut total = 0.0;
        let mut observations = 0;
        while sampled_days < independent_days {
            let start = rng.index(independent_days);
            for offset in 0..config.block_length_days {
                if sampled_days == independent_days {
                    break;
                }
                let day = &days[(start + offset) % independent_days];
                total += day.iter().sum::<f64>();
                observations += day.len();
                sampled_days += 1;
            }
        }
        means.push(total / observations.max(1) as f64);
    }
    means.sort_by(f64::total_cmp);
    let alpha = (1.0 - config.confidence_level) / 2.0;
    let interval = ConfidenceInterval {
        lower: quantile_sorted(&means, alpha),
        upper: quantile_sorted(&means, 1.0 - alpha),
        confidence_level: config.confidence_level,
    };
    Ok(BlockBootstrapResult {
        estimate,
        interval,
        iterations: config.iterations,
        block_length_days: config.block_length_days,
        independent_days,
        observations: effects.len(),
        seed: config.seed,
    })
}

fn quantile_sorted(values: &[f64], probability: f64) -> f64 {
    let location = probability.clamp(0.0, 1.0) * (values.len() - 1) as f64;
    let left = location.floor() as usize;
    let right = location.ceil() as usize;
    let fraction = location - left as f64;
    values[left] * (1.0 - fraction) + values[right] * fraction
}

#[derive(Debug, Clone, Copy)]
struct SplitMix64(u64);

impl SplitMix64 {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut value = self.0;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        value ^ (value >> 31)
    }

    fn index(&mut self, upper: usize) -> usize {
        (self.next() % upper as u64) as usize
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum NegativeControl {
    LabelShuffle,
    TimestampShuffle,
    ReturnSignShuffle,
    WithinDayBlockPermutation,
    CrossSymbolPlacebo,
    FutureFeatureTrap,
    RandomMotif,
    RandomAnalogNeighbor,
    WrongRegimePlacebo,
    ReversedLeadLag,
    DelayedAvailability,
    DuplicatedRow,
    SyntheticGap,
}

impl NegativeControl {
    pub const ALL: [Self; 13] = [
        Self::LabelShuffle,
        Self::TimestampShuffle,
        Self::ReturnSignShuffle,
        Self::WithinDayBlockPermutation,
        Self::CrossSymbolPlacebo,
        Self::FutureFeatureTrap,
        Self::RandomMotif,
        Self::RandomAnalogNeighbor,
        Self::WrongRegimePlacebo,
        Self::ReversedLeadLag,
        Self::DelayedAvailability,
        Self::DuplicatedRow,
        Self::SyntheticGap,
    ];

    pub fn is_placebo_or_random(self) -> bool {
        matches!(
            self,
            Self::CrossSymbolPlacebo
                | Self::RandomMotif
                | Self::RandomAnalogNeighbor
                | Self::WrongRegimePlacebo
                | Self::ReversedLeadLag
        )
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum NegativeControlStatus {
    Passed,
    MatchedCandidate,
    NotRun,
    InfrastructureFailure,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NegativeControlResult {
    pub control: NegativeControl,
    pub status: NegativeControlStatus,
    pub candidate_effect: Option<f64>,
    pub control_effect: Option<f64>,
    pub match_tolerance: Option<f64>,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NegativeControlCompleteness {
    pub complete: bool,
    pub missing: Vec<NegativeControl>,
    pub duplicates: Vec<NegativeControl>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NegativeControlMatrix {
    pub schema_version: u32,
    pub hypothesis_id: String,
    pub evaluated_at: DateTime<Utc>,
    pub primary_metric: String,
    pub results: Vec<NegativeControlResult>,
}

impl NegativeControlMatrix {
    pub fn completeness(&self) -> NegativeControlCompleteness {
        let mut seen = BTreeSet::new();
        let mut duplicates = BTreeSet::new();
        for result in &self.results {
            if !seen.insert(result.control) {
                duplicates.insert(result.control);
            }
        }
        let missing = NegativeControl::ALL
            .into_iter()
            .filter(|control| !seen.contains(control))
            .collect::<Vec<_>>();
        let every_control_finished = self.results.iter().all(|result| {
            matches!(
                result.status,
                NegativeControlStatus::Passed | NegativeControlStatus::MatchedCandidate
            )
        });
        NegativeControlCompleteness {
            complete: missing.is_empty() && duplicates.is_empty() && every_control_finished,
            missing,
            duplicates: duplicates.into_iter().collect(),
        }
    }

    pub fn matched_controls(&self) -> Vec<NegativeControl> {
        self.results
            .iter()
            .filter(|result| result.status == NegativeControlStatus::MatchedCandidate)
            .map(|result| result.control)
            .collect()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PromotionThresholds {
    pub maximum_fdr_q_value: f64,
    pub minimum_effect_size: f64,
    pub minimum_cost_adjusted_effect: f64,
    pub minimum_independent_days: usize,
    pub minimum_test_samples: usize,
    pub minimum_forward_shadow_samples: usize,
    pub require_ci_excludes_zero: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PromotionEvidence {
    pub current_status: HypothesisStatus,
    pub fdr_adjusted_p_value: f64,
    pub effect_size: f64,
    pub cost_adjusted_effect: f64,
    pub block_bootstrap_ci: ConfidenceInterval,
    pub independent_days: usize,
    pub test_samples: usize,
    pub forward_shadow_samples: usize,
    pub untouched_test: bool,
    pub decayed: bool,
    pub negative_controls: NegativeControlMatrix,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PromotionDecision {
    pub paper_eligible: bool,
    pub next_status: HypothesisStatus,
    pub reasons: Vec<String>,
}

/// Applies hard promotion gates. A completed random/placebo control that
/// reproduces the candidate is an immediate `REJECTED`, not a warning.
pub fn promotion_decision(
    evidence: &PromotionEvidence,
    thresholds: &PromotionThresholds,
) -> PromotionDecision {
    let matched = evidence.negative_controls.matched_controls();
    let matched_placebo = matched
        .iter()
        .copied()
        .filter(|control| control.is_placebo_or_random())
        .collect::<Vec<_>>();
    if !matched_placebo.is_empty() {
        return PromotionDecision {
            paper_eligible: false,
            next_status: HypothesisStatus::Rejected,
            reasons: vec![format!(
                "placebo_or_random_control_matched_candidate:{matched_placebo:?}"
            )],
        };
    }
    if !matched.is_empty() {
        return PromotionDecision {
            paper_eligible: false,
            next_status: HypothesisStatus::Rejected,
            reasons: vec![format!("negative_control_matched_candidate:{matched:?}")],
        };
    }
    if evidence.decayed {
        return PromotionDecision {
            paper_eligible: false,
            next_status: HypothesisStatus::Decayed,
            reasons: vec!["recent_effect_decay".into()],
        };
    }

    let completeness = evidence.negative_controls.completeness();
    let mut reasons = Vec::new();
    if !completeness.complete {
        reasons.push(format!(
            "negative_control_matrix_incomplete:missing={:?}:duplicates={:?}",
            completeness.missing, completeness.duplicates
        ));
    }
    if !evidence.untouched_test {
        reasons.push("test_partition_was_not_untouched".into());
    }
    if !evidence.fdr_adjusted_p_value.is_finite()
        || evidence.fdr_adjusted_p_value > thresholds.maximum_fdr_q_value
    {
        reasons.push("fdr_threshold_not_met".into());
    }
    if !evidence.effect_size.is_finite()
        || evidence.effect_size.abs() < thresholds.minimum_effect_size
    {
        reasons.push("effect_size_threshold_not_met".into());
    }
    if !evidence.cost_adjusted_effect.is_finite()
        || evidence.cost_adjusted_effect < thresholds.minimum_cost_adjusted_effect
    {
        reasons.push("cost_adjusted_effect_not_positive_enough".into());
    }
    if evidence.independent_days < thresholds.minimum_independent_days {
        reasons.push("insufficient_independent_days".into());
    }
    if evidence.test_samples < thresholds.minimum_test_samples {
        reasons.push("insufficient_untouched_test_samples".into());
    }
    if thresholds.require_ci_excludes_zero
        && !evidence
            .block_bootstrap_ci
            .excludes_zero_in_effect_direction(evidence.cost_adjusted_effect)
    {
        reasons.push("block_bootstrap_interval_includes_zero".into());
    }
    if !reasons.is_empty() {
        return PromotionDecision {
            paper_eligible: false,
            next_status: HypothesisStatus::TestFailed,
            reasons,
        };
    }
    if evidence.forward_shadow_samples < thresholds.minimum_forward_shadow_samples {
        return PromotionDecision {
            paper_eligible: false,
            next_status: HypothesisStatus::ForwardShadow,
            reasons: vec!["forward_shadow_minimum_sample_not_met".into()],
        };
    }
    PromotionDecision {
        paper_eligible: true,
        next_status: HypothesisStatus::PaperEligible,
        reasons: vec!["all_predeclared_promotion_gates_passed".into()],
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum AnomalyResearchError {
    InvalidIdentity,
    InvalidDataset(String),
    InvalidRecord(String),
    InvalidProbability(f64),
    InvalidNumericValue(String),
    InvalidBootstrapConfiguration,
    InvalidStatusTransition {
        from: HypothesisStatus,
        to: HypothesisStatus,
    },
}

impl fmt::Display for AnomalyResearchError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidIdentity => formatter.write_str("invalid hypothesis identity"),
            Self::InvalidDataset(detail) => write!(formatter, "invalid dataset: {detail}"),
            Self::InvalidRecord(detail) => write!(formatter, "invalid hypothesis record: {detail}"),
            Self::InvalidProbability(value) => write!(formatter, "invalid probability: {value}"),
            Self::InvalidNumericValue(field) => write!(formatter, "invalid numeric value: {field}"),
            Self::InvalidBootstrapConfiguration => {
                formatter.write_str("invalid block-bootstrap configuration")
            }
            Self::InvalidStatusTransition { from, to } => {
                write!(formatter, "invalid status transition {from:?} -> {to:?}")
            }
        }
    }
}

impl Error for AnomalyResearchError {}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn identity() -> HypothesisIdentity {
        HypothesisIdentity {
            feature_specification: vec!["ret_5m".into(), " RVOL ".into()],
            target: "forward return".into(),
            symbol: "spy".into(),
            horizon_minutes: 30,
            regime_filter: Some("high vol recovery".into()),
            sample_eligibility: "regular session finalized bars".into(),
            multiple_testing_family: "motif-window-30m".into(),
        }
    }

    fn dataset(
        partition: DatasetPartition,
        start: (i32, u32, u32),
        end: (i32, u32, u32),
        untouched_when_assigned: bool,
    ) -> DatasetReference {
        let hash_character = match partition {
            DatasetPartition::Discovery => "1",
            DatasetPartition::Train => "2",
            DatasetPartition::Validation => "3",
            DatasetPartition::Calibration => "4",
            DatasetPartition::Test => "5",
            DatasetPartition::ForwardShadow => "6",
        };
        DatasetReference {
            dataset_id: format!("{partition:?}-dataset"),
            dataset_version: "v1".into(),
            sha256: hash_character.repeat(64),
            partition,
            start_date: NaiveDate::from_ymd_opt(start.0, start.1, start.2).unwrap(),
            end_date: NaiveDate::from_ymd_opt(end.0, end.1, end.2).unwrap(),
            sample_count: 100,
            point_in_time: true,
            untouched_when_assigned,
        }
    }

    fn assignments() -> DatasetAssignments {
        DatasetAssignments {
            discovery: dataset(
                DatasetPartition::Discovery,
                (2025, 1, 2),
                (2025, 1, 10),
                false,
            ),
            train: dataset(DatasetPartition::Train, (2025, 1, 13), (2025, 3, 31), false),
            validation: dataset(
                DatasetPartition::Validation,
                (2025, 4, 1),
                (2025, 4, 30),
                true,
            ),
            calibration: Some(dataset(
                DatasetPartition::Calibration,
                (2025, 5, 1),
                (2025, 5, 15),
                true,
            )),
            test: dataset(DatasetPartition::Test, (2025, 5, 16), (2025, 6, 30), true),
            forward_shadow: Some(dataset(
                DatasetPartition::ForwardShadow,
                (2025, 7, 1),
                (2025, 7, 31),
                true,
            )),
        }
    }

    fn hypothesis_record() -> ResearchHypothesisRecord {
        ResearchHypothesisRecord::new(
            identity(),
            assignments(),
            Utc.with_ymd_and_hms(2026, 1, 2, 12, 0, 0).unwrap(),
            1.5,
        )
        .unwrap()
    }

    #[test]
    fn dataset_assignments_require_strict_order_and_untouched_test() {
        assert!(assignments().validate().is_ok());

        let mut overlap = assignments();
        overlap.train.start_date = overlap.discovery.end_date;
        let error = overlap.validate().unwrap_err().to_string();
        assert!(error.contains("overlap or are out of order"));

        let mut touched_test = assignments();
        touched_test.test.untouched_when_assigned = false;
        let error = touched_test.validate().unwrap_err().to_string();
        assert!(error.contains("test partition must be untouched"));

        let mut touched_forward = assignments();
        touched_forward
            .forward_shadow
            .as_mut()
            .unwrap()
            .untouched_when_assigned = false;
        let error = touched_forward.validate().unwrap_err().to_string();
        assert!(error.contains("forward-shadow partition must be untouched"));

        let mut calibration_overlap = assignments();
        calibration_overlap.calibration.as_mut().unwrap().start_date =
            calibration_overlap.validation.end_date;
        assert!(calibration_overlap.validate().is_err());
    }

    #[test]
    fn durable_registry_deduplicates_reconstructs_and_blocks_sql_mutation() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("hypotheses.sqlite3");
        let registry = DurableHypothesisRegistry::open(&path).unwrap();
        let record = hypothesis_record();

        let first = registry.append(&record).unwrap();
        assert_eq!(first.disposition, RegistryAppendDisposition::Appended);
        assert_eq!(first.version_sequence, 1);
        let duplicate = registry.append(&record).unwrap();
        assert_eq!(duplicate.disposition, RegistryAppendDisposition::Duplicate);
        assert_eq!(duplicate.version_id, first.version_id);

        let second = registry
            .transition(
                &record.hypothesis_id,
                HypothesisStatus::Screened,
                record.discovery_timestamp + chrono::Duration::hours(1),
                "train-only screening completed",
                Some("a".repeat(64)),
            )
            .unwrap();
        assert_eq!(second.version_sequence, 2);
        let versions = registry.versions(&record.hypothesis_id).unwrap();
        assert_eq!(versions.len(), 2);
        assert_eq!(
            versions[1].previous_version_id.as_deref(),
            Some(first.version_id.as_str())
        );

        let update_error = registry
            .connection
            .lock()
            .execute(
                "UPDATE research_hypothesis_versions SET current_status='REJECTED' WHERE version_id=?1",
                params![second.version_id],
            )
            .unwrap_err();
        assert!(update_error.to_string().contains("APPEND_ONLY"));
        let delete_error = registry
            .connection
            .lock()
            .execute(
                "DELETE FROM research_hypothesis_versions WHERE version_id=?1",
                params![second.version_id],
            )
            .unwrap_err();
        assert!(delete_error.to_string().contains("APPEND_ONLY"));

        drop(registry);
        let reopened = DurableHypothesisRegistry::open(&path).unwrap();
        let reconstruction = reopened.reconstruct().unwrap();
        assert_eq!(reconstruction.audit.hypothesis_count, 1);
        assert_eq!(reconstruction.audit.version_count, 2);
        assert_eq!(reconstruction.audit.status_transition_count, 1);
        assert_eq!(reconstruction.audit.duplicate_append_attempts, 1);
        assert_eq!(reconstruction.chain_sha256.len(), 64);
        assert_eq!(
            reconstruction.latest_records[0].current_status,
            HypothesisStatus::Screened
        );
    }

    #[test]
    fn durable_registry_rejects_history_rewrite_and_dataset_mutation() {
        let directory = tempfile::tempdir().unwrap();
        let registry =
            DurableHypothesisRegistry::open(&directory.path().join("hypotheses.sqlite3")).unwrap();
        let record = hypothesis_record();
        registry.append(&record).unwrap();
        registry
            .transition(
                &record.hypothesis_id,
                HypothesisStatus::Screened,
                record.discovery_timestamp + chrono::Duration::minutes(1),
                "screened",
                None,
            )
            .unwrap();

        let mut rewritten = registry.latest(&record.hypothesis_id).unwrap().unwrap();
        rewritten.status_history[0].reason = "rewritten discovery rationale".into();
        let error = registry.append(&rewritten).unwrap_err().to_string();
        assert!(error.contains("status history must be an exact append-only prefix"));

        let mut invalid_evidence = registry.latest(&record.hypothesis_id).unwrap().unwrap();
        let status_before = invalid_evidence.current_status;
        let history_before = invalid_evidence.status_history.clone();
        let error = invalid_evidence
            .transition(
                HypothesisStatus::ExperimentalSignal,
                record.discovery_timestamp + chrono::Duration::minutes(2),
                "invalid evidence must not mutate the record",
                Some("not-a-sha256".into()),
            )
            .unwrap_err();
        assert!(error.to_string().contains("SHA-256"));
        assert_eq!(invalid_evidence.current_status, status_before);
        assert_eq!(invalid_evidence.status_history, history_before);

        let mut changed_dataset = registry.latest(&record.hypothesis_id).unwrap().unwrap();
        changed_dataset.datasets.train.dataset_version = "silently-reassigned-v2".into();
        let error = registry.append(&changed_dataset).unwrap_err().to_string();
        assert!(error.contains("immutable hypothesis identity, datasets"));
        assert_eq!(registry.audit().unwrap().version_count, 2);
    }

    fn complete_control_matrix(status_override: Option<NegativeControl>) -> NegativeControlMatrix {
        NegativeControlMatrix {
            schema_version: 1,
            hypothesis_id: deterministic_hypothesis_id(&identity()).unwrap(),
            evaluated_at: Utc.with_ymd_and_hms(2026, 7, 21, 12, 0, 0).unwrap(),
            primary_metric: "cost_adjusted_effect".into(),
            results: NegativeControl::ALL
                .into_iter()
                .map(|control| NegativeControlResult {
                    control,
                    status: if Some(control) == status_override {
                        NegativeControlStatus::MatchedCandidate
                    } else {
                        NegativeControlStatus::Passed
                    },
                    candidate_effect: Some(0.001),
                    control_effect: Some(0.0),
                    match_tolerance: Some(0.0001),
                    detail: "deterministic fixture".into(),
                })
                .collect(),
        }
    }

    #[test]
    fn deterministic_identity_deduplicates_formatting_and_feature_order() {
        let first = identity();
        let mut second = identity();
        second.feature_specification.reverse();
        second.symbol = " SPY ".into();
        second.target = "Forward   Return".into();
        assert_eq!(
            deterministic_hypothesis_id(&first).unwrap(),
            deterministic_hypothesis_id(&second).unwrap()
        );
        second.horizon_minutes = 60;
        assert_ne!(
            deterministic_hypothesis_id(&first).unwrap(),
            deterministic_hypothesis_id(&second).unwrap()
        );
        let report = deduplicate_identities(&[first.clone(), first]).unwrap();
        assert!(!report[0].duplicate);
        assert!(report[1].duplicate);
        assert_eq!(report[1].first_seen_index, 0);
    }

    #[test]
    fn bh_adjustment_is_monotone_in_rank_and_restores_input_order() {
        let adjusted = benjamini_hochberg(&[0.01, 0.04, 0.03, 0.002]).unwrap();
        assert_eq!(adjusted, vec![0.02, 0.04, 0.04, 0.008]);
        assert!(benjamini_hochberg(&[f64::NAN]).is_err());
    }

    #[test]
    fn block_bootstrap_is_deterministic_and_resamples_whole_days() {
        let effects = (1..=12)
            .flat_map(|day| {
                let date = NaiveDate::from_ymd_opt(2026, 1, day).unwrap();
                [
                    DatedEffect {
                        session_date: date,
                        value: day as f64,
                    },
                    DatedEffect {
                        session_date: date,
                        value: day as f64 + 0.5,
                    },
                ]
            })
            .collect::<Vec<_>>();
        let config = BlockBootstrapConfig {
            iterations: 500,
            confidence_level: 0.95,
            block_length_days: 3,
            seed: 17,
        };
        let first = block_bootstrap_mean(&effects, config).unwrap();
        let second = block_bootstrap_mean(&effects, config).unwrap();
        assert_eq!(first, second);
        assert_eq!(first.independent_days, 12);
        assert_eq!(first.observations, 24);
        assert!(first.interval.lower < first.estimate);
        assert!(first.interval.upper > first.estimate);
    }

    #[test]
    fn all_thirteen_controls_are_required_and_placebo_match_rejects() {
        let matrix = complete_control_matrix(None);
        assert_eq!(NegativeControl::ALL.len(), 13);
        assert!(matrix.completeness().complete);

        let evidence = PromotionEvidence {
            current_status: HypothesisStatus::ForwardShadow,
            fdr_adjusted_p_value: 0.01,
            effect_size: 0.002,
            cost_adjusted_effect: 0.001,
            block_bootstrap_ci: ConfidenceInterval {
                lower: 0.0002,
                upper: 0.002,
                confidence_level: 0.95,
            },
            independent_days: 80,
            test_samples: 150,
            forward_shadow_samples: 100,
            untouched_test: true,
            decayed: false,
            negative_controls: complete_control_matrix(Some(NegativeControl::RandomMotif)),
        };
        let thresholds = PromotionThresholds {
            maximum_fdr_q_value: 0.05,
            minimum_effect_size: 0.0005,
            minimum_cost_adjusted_effect: 0.0001,
            minimum_independent_days: 30,
            minimum_test_samples: 100,
            minimum_forward_shadow_samples: 60,
            require_ci_excludes_zero: true,
        };
        let decision = promotion_decision(&evidence, &thresholds);
        assert_eq!(decision.next_status, HypothesisStatus::Rejected);
        assert!(!decision.paper_eligible);
        assert!(decision.reasons[0].contains("placebo_or_random"));
    }

    #[test]
    fn passing_controls_still_require_forward_shadow_minimum() {
        let evidence = PromotionEvidence {
            current_status: HypothesisStatus::ExperimentalSignal,
            fdr_adjusted_p_value: 0.01,
            effect_size: 0.002,
            cost_adjusted_effect: 0.001,
            block_bootstrap_ci: ConfidenceInterval {
                lower: 0.0001,
                upper: 0.002,
                confidence_level: 0.95,
            },
            independent_days: 80,
            test_samples: 150,
            forward_shadow_samples: 12,
            untouched_test: true,
            decayed: false,
            negative_controls: complete_control_matrix(None),
        };
        let thresholds = PromotionThresholds {
            maximum_fdr_q_value: 0.05,
            minimum_effect_size: 0.0005,
            minimum_cost_adjusted_effect: 0.0001,
            minimum_independent_days: 30,
            minimum_test_samples: 100,
            minimum_forward_shadow_samples: 60,
            require_ci_excludes_zero: true,
        };
        let decision = promotion_decision(&evidence, &thresholds);
        assert_eq!(decision.next_status, HypothesisStatus::ForwardShadow);
        assert!(!decision.paper_eligible);
    }

    #[test]
    fn failed_lifecycle_records_cannot_be_rewritten_into_winners() {
        assert!(HypothesisStatus::Discovered.can_transition_to(HypothesisStatus::Screened));
        assert!(HypothesisStatus::Screened.can_transition_to(HypothesisStatus::ValidationFailed));
        assert!(
            !HypothesisStatus::ValidationFailed.can_transition_to(HypothesisStatus::PaperEligible)
        );
        assert!(!HypothesisStatus::Rejected.can_transition_to(HypothesisStatus::Discovered));
    }
}
