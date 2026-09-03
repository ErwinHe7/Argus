//! Sanitized, fail-closed production-readiness receipt.
//!
//! This module only summarizes existing runtime configuration and immutable
//! artifacts. It never probes a secret-bearing provider, recomputes a
//! forecast, or exposes paths, hashes, credentials, URLs, provider messages,
//! model outputs, or raw blocker strings.

use std::{
    collections::BTreeSet,
    env, fs,
    io::{Read, Seek, SeekFrom},
    path::Path,
};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::{
    AppConfig,
    data::{
        databento_inference::{
            CommittedForecastBatch, ContextBlockerDiagnostic, TargetInferenceStage,
            TargetInferenceState, read_latest_committed_forecast_batch, read_target_status,
        },
        massive_live::readiness_scopes_from_receipt,
    },
    probability_calibration::{
        CalibrationArtifactBinding, CalibrationLifecycle, CalibrationRegistryInspectionStatus,
        ProbabilityCalibrationRegistry, inspect_from_environment as inspect_calibration_registry,
    },
    promotion_registry::{
        PromotionRegistryInspectionStatus, inspect_from_environment as inspect_promotion_registry,
    },
};

pub const PRODUCTION_READINESS_SCHEMA_VERSION: &str = "axio.production_readiness.v2";
pub const MARKET_DATA_RIGHTS_RECEIPT_SCHEMA_VERSION: &str = "axio.market_data_rights.v2";
pub const MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV: &str = "AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256";
pub(crate) const MARKET_DATA_RIGHTS_RECEIPT_RELATIVE_PATH: &str =
    "rights/market_data_rights_receipt.json";
pub(crate) const MAX_MARKET_DATA_RIGHTS_RECEIPT_BYTES: u64 = 64 * 1024;
pub(crate) const MARKET_DATA_TECHNICAL_ENTITLEMENT_RECEIPT_RELATIVE_PATH: &str =
    "evidence/databento_technical_entitlement_latest.json";
pub(crate) const MAX_MARKET_DATA_TECHNICAL_ENTITLEMENT_RECEIPT_BYTES: u64 = 64 * 1024;
const MARKET_DATA_TECHNICAL_ENTITLEMENT_SCHEMA_VERSION: &str =
    "axio.databento_technical_entitlement.v1";
const MAX_OWNER_TECHNICAL_ENTITLEMENT_AGE_SECONDS: i64 = 24 * 60 * 60;
const MAX_OWNER_TECHNICAL_ENTITLEMENT_FUTURE_SKEW_SECONDS: i64 = 5 * 60;
const REQUIRED_PRODUCTION_HORIZONS: [usize; 4] = [5, 15, 30, 60];
const REQUIRED_PRODUCTION_MODEL_SYMBOLS: [&str; 9] = [
    "SPY", "QQQ", "NVDA", "AAPL", "MU", "SOXX", "NBIS", "BE", "IGV",
];

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum OverallReadiness {
    Ready,
    Blocked,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum LlmAuthStatus {
    /// The LLM is owned by the Next.js runtime. Quantd receives neither the
    /// credential nor a trusted auth-probe receipt, so it must not claim that
    /// the external service is authenticated.
    ExternalUnknown,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum EvidenceStatus {
    Ready,
    Blocked,
    Unavailable,
    Disabled,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum FreshnessStatus {
    Fresh,
    Stale,
    Future,
    Blocked,
    Unavailable,
    Disabled,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum PromotionRegistryStatus {
    ActivePinned,
    Invalid,
    HashMismatch,
    Unpinned,
    LegacySingleMigrationRequired,
    Absent,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum CalibrationRegistryStatus {
    Promoted,
    ValidUnpromoted,
    Invalid,
    HashMismatch,
    Unpinned,
    LegacyV1MigrationRequired,
    Absent,
    NotConfigured,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ForecastValidationStatus {
    Passed,
    Rejected,
    NotEvaluated,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ForecastCoverageStatus {
    Complete,
    Partial,
    None,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ForecastCalibrationStatus {
    Promoted,
    Partial,
    Unpromoted,
    Unavailable,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MarketDataRightsStatus {
    Ready,
    Blocked,
    Unavailable,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MarketDataRightsReason {
    Verified,
    OwnerAttestedWithTechnicalEntitlement,
    SelectedProductUnavailable,
    ReceiptMissing,
    ReceiptUnreadable,
    PinMissing,
    PinInvalid,
    HashMismatch,
    ReceiptInvalid,
    SchemaUnsupported,
    ProviderMismatch,
    ProductMismatch,
    LegalEntityInvalid,
    PlanInvalid,
    PlanNotActive,
    EvidenceKindUnsupported,
    EvidenceArtifactHashInvalid,
    AccountLicenseReferenceHashInvalid,
    ModelInputNotPermitted,
    CustomerExternalDisplayNotPermitted,
    DerivedOutputPublicationNotPermitted,
    RawDataRedistributionUnsupported,
    ValidityNotStarted,
    ValidityExpired,
    ReviewExpired,
    TemporalBindingInvalid,
    IssuerInvalid,
    ReviewerInvalid,
    OfficialTermsReferenceInvalid,
    OfficialProductReferenceInvalid,
    EvidenceReferenceInvalid,
    OwnerAttestationInvalid,
    TechnicalEntitlementReceiptMissing,
    TechnicalEntitlementReceiptHashMismatch,
    TechnicalEntitlementReceiptInvalid,
    TechnicalEntitlementReceiptStale,
}

impl MarketDataRightsReason {
    pub const fn code(self) -> &'static str {
        match self {
            Self::Verified => "VERIFIED",
            Self::OwnerAttestedWithTechnicalEntitlement => {
                "OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT"
            }
            Self::SelectedProductUnavailable => "SELECTED_PRODUCT_UNAVAILABLE",
            Self::ReceiptMissing => "RECEIPT_MISSING",
            Self::ReceiptUnreadable => "RECEIPT_UNREADABLE",
            Self::PinMissing => "PIN_MISSING",
            Self::PinInvalid => "PIN_INVALID",
            Self::HashMismatch => "HASH_MISMATCH",
            Self::ReceiptInvalid => "RECEIPT_INVALID",
            Self::SchemaUnsupported => "SCHEMA_UNSUPPORTED",
            Self::ProviderMismatch => "PROVIDER_MISMATCH",
            Self::ProductMismatch => "PRODUCT_MISMATCH",
            Self::LegalEntityInvalid => "LEGAL_ENTITY_INVALID",
            Self::PlanInvalid => "PLAN_INVALID",
            Self::PlanNotActive => "PLAN_NOT_ACTIVE",
            Self::EvidenceKindUnsupported => "EVIDENCE_KIND_UNSUPPORTED",
            Self::EvidenceArtifactHashInvalid => "EVIDENCE_ARTIFACT_HASH_INVALID",
            Self::AccountLicenseReferenceHashInvalid => "ACCOUNT_LICENSE_REFERENCE_HASH_INVALID",
            Self::ModelInputNotPermitted => "MODEL_INPUT_NOT_PERMITTED",
            Self::CustomerExternalDisplayNotPermitted => "CUSTOMER_EXTERNAL_DISPLAY_NOT_PERMITTED",
            Self::DerivedOutputPublicationNotPermitted => {
                "DERIVED_OUTPUT_PUBLICATION_NOT_PERMITTED"
            }
            Self::RawDataRedistributionUnsupported => "RAW_DATA_REDISTRIBUTION_UNSUPPORTED",
            Self::ValidityNotStarted => "VALIDITY_NOT_STARTED",
            Self::ValidityExpired => "VALIDITY_EXPIRED",
            Self::ReviewExpired => "REVIEW_EXPIRED",
            Self::TemporalBindingInvalid => "TEMPORAL_BINDING_INVALID",
            Self::IssuerInvalid => "ISSUER_INVALID",
            Self::ReviewerInvalid => "REVIEWER_INVALID",
            Self::OfficialTermsReferenceInvalid => "OFFICIAL_TERMS_REFERENCE_INVALID",
            Self::OfficialProductReferenceInvalid => "OFFICIAL_PRODUCT_REFERENCE_INVALID",
            Self::EvidenceReferenceInvalid => "EVIDENCE_REFERENCE_INVALID",
            Self::OwnerAttestationInvalid => "OWNER_ATTESTATION_INVALID",
            Self::TechnicalEntitlementReceiptMissing => "TECHNICAL_ENTITLEMENT_RECEIPT_MISSING",
            Self::TechnicalEntitlementReceiptHashMismatch => {
                "TECHNICAL_ENTITLEMENT_RECEIPT_HASH_MISMATCH"
            }
            Self::TechnicalEntitlementReceiptInvalid => "TECHNICAL_ENTITLEMENT_RECEIPT_INVALID",
            Self::TechnicalEntitlementReceiptStale => "TECHNICAL_ENTITLEMENT_RECEIPT_STALE",
        }
    }

    const fn is_ready_basis(self) -> bool {
        matches!(
            self,
            Self::Verified | Self::OwnerAttestedWithTechnicalEntitlement
        )
    }
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum LegacyMarketDataRightsStatus {
    NotConfigured,
    ValidButNonAuthoritative,
    InvalidButNonAuthoritative,
}

#[derive(Debug, Serialize)]
pub struct MarketDataRightsReadinessReceipt {
    pub status: MarketDataRightsStatus,
    pub reason: MarketDataRightsReason,
    pub legacy_environment_status: LegacyMarketDataRightsStatus,
}

#[derive(Debug, Serialize)]
pub struct LlmReadinessReceipt {
    pub auth_status: LlmAuthStatus,
}

#[derive(Debug, Serialize)]
pub struct MarketDataReadinessReceipt {
    pub selected_provider: String,
    pub selected_product: Option<String>,
    pub live_enabled: bool,
    pub public_use_rights: MarketDataRightsReadinessReceipt,
    pub provider_entitlement: EvidenceStatus,
    pub stream_freshness: FreshnessStatus,
    pub feed_freshness: FreshnessStatus,
}

#[derive(Debug, Serialize)]
pub struct ArtifactReadinessReceipt {
    pub promotion_registry_present: bool,
    pub promotion_registry_status: PromotionRegistryStatus,
    pub calibration_registry_present: bool,
    pub calibration_registry_status: CalibrationRegistryStatus,
    pub prediction_ledger_present: bool,
}

#[derive(Debug, Serialize)]
pub struct LiveInferenceReadinessReceipt {
    pub required: bool,
    pub status_available: bool,
    pub status: Option<TargetInferenceState>,
    pub stage: Option<TargetInferenceStage>,
    pub reason_code: Option<String>,
    pub status_freshness: FreshnessStatus,
    pub cutoff: Option<DateTime<Utc>>,
    pub latest_input_available_at: Option<DateTime<Utc>>,
    pub compute_ms: Option<u64>,
    pub end_to_end_ms: Option<i64>,
    pub budget_ms: Option<i64>,
    pub context_blockers: Vec<ContextBlockerDiagnostic>,
    pub forecast_committed: bool,
    pub receipt_committed: bool,
    pub ledger_persisted: bool,
    pub ready: bool,
}

#[derive(Debug, Serialize)]
pub struct SymbolForecastReadiness {
    pub symbol: String,
    pub live_inference: LiveInferenceReadinessReceipt,
    pub artifact_present: bool,
    pub validation_status: ForecastValidationStatus,
    pub freshness: FreshnessStatus,
    pub horizon_coverage: ForecastCoverageStatus,
    pub calibration: ForecastCalibrationStatus,
    pub promotion_registry_matches: bool,
    pub ledger_backed: bool,
    pub ready: bool,
}

#[derive(Debug, Serialize)]
pub struct ProductionReadinessReceipt {
    pub schema_version: &'static str,
    pub status: OverallReadiness,
    pub public_realtime_research_ready: bool,
    pub llm: LlmReadinessReceipt,
    pub market_data: MarketDataReadinessReceipt,
    pub artifacts: ArtifactReadinessReceipt,
    pub forecasts: Vec<SymbolForecastReadiness>,
}

#[derive(Debug, Clone, Copy)]
struct PromotionRegistryEvidence {
    present: bool,
    status: PromotionRegistryStatus,
}

#[derive(Debug, Clone)]
struct CalibrationRegistryEvidence {
    present: bool,
    status: CalibrationRegistryStatus,
    registry: Option<ProbabilityCalibrationRegistry>,
}

fn root_for(config: &AppConfig) -> &Path {
    config.data.raw_root.parent().unwrap_or(Path::new("data"))
}

fn normalized_symbol(symbol: &str) -> String {
    symbol.trim().trim_start_matches("US.").to_ascii_uppercase()
}

fn selected_market_data_product(config: &AppConfig) -> Option<String> {
    match config.live.provider.trim().to_ascii_lowercase().as_str() {
        "databento" => config
            .data
            .databento
            .requests
            .iter()
            .find(|request| {
                request.schema.eq_ignore_ascii_case("ohlcv-1m")
                    && request.stype_in.eq_ignore_ascii_case("raw_symbol")
                    && request.dataset.eq_ignore_ascii_case("EQUS.MINI")
            })
            .map(|request| request.dataset.trim().to_ascii_uppercase()),
        "massive" => Some("US_EQUITIES_REALTIME".to_string()),
        "moomoo" => Some("US_EQUITIES_K_1M".to_string()),
        _ => None,
    }
}

fn production_forecast_contract_configured(config: &AppConfig) -> bool {
    let horizons = config
        .research
        .horizons
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    let required_horizons = REQUIRED_PRODUCTION_HORIZONS
        .into_iter()
        .collect::<BTreeSet<_>>();
    let live_symbols = config
        .live
        .forecast_symbols
        .iter()
        .map(|symbol| normalized_symbol(symbol))
        .collect::<BTreeSet<_>>();
    let research_symbols = config
        .research
        .targets
        .iter()
        .map(|target| normalized_symbol(&target.model_symbol))
        .collect::<BTreeSet<_>>();
    let required_symbols = REQUIRED_PRODUCTION_MODEL_SYMBOLS
        .into_iter()
        .map(str::to_string)
        .collect::<BTreeSet<_>>();
    horizons == required_horizons
        && config.research.horizons.len() == REQUIRED_PRODUCTION_HORIZONS.len()
        && config.live.forecast_symbols.len() == REQUIRED_PRODUCTION_MODEL_SYMBOLS.len()
        && config.research.targets.len() == REQUIRED_PRODUCTION_MODEL_SYMBOLS.len()
        && live_symbols == required_symbols
        && research_symbols == required_symbols
}

fn live_forecast_filename(symbol: &str) -> String {
    if symbol.eq_ignore_ascii_case("SPY") {
        "forecast_contract_live_latest.json".to_string()
    } else {
        format!(
            "forecast_contract_live_{}_latest.json",
            symbol.to_ascii_lowercase()
        )
    }
}

fn legacy_license_values_match(
    selected_provider: &str,
    licensed_provider: &str,
    reference: &str,
) -> bool {
    if licensed_provider.trim().is_empty()
        || !licensed_provider
            .trim()
            .eq_ignore_ascii_case(selected_provider.trim())
    {
        return false;
    }
    let Ok(reference) = reqwest::Url::parse(reference.trim()) else {
        return false;
    };
    if reference.scheme() != "https"
        || !reference.username().is_empty()
        || reference.password().is_some()
        || reference.query().is_some()
        || reference.fragment().is_some()
        || reference.port_or_known_default() != Some(443)
    {
        return false;
    }
    let Some(host) = reference.host_str().map(str::to_ascii_lowercase) else {
        return false;
    };
    let approved_host = match selected_provider.trim().to_ascii_lowercase().as_str() {
        "databento" => "databento.com",
        "massive" => "massive.com",
        _ => return false,
    };
    host == approved_host || host.ends_with(&format!(".{approved_host}"))
}

fn legacy_market_data_rights_status(selected_provider: &str) -> LegacyMarketDataRightsStatus {
    let provider = env::var("AXIO7_PUBLIC_MARKET_DATA_PROVIDER")
        .ok()
        .map(|value| value.trim().to_string())
        .unwrap_or_default();
    let reference = env::var("AXIO7_PUBLIC_MARKET_DATA_LICENSE_REFERENCE")
        .ok()
        .map(|value| value.trim().to_string())
        .unwrap_or_default();
    if provider.is_empty() && reference.is_empty() {
        LegacyMarketDataRightsStatus::NotConfigured
    } else if legacy_license_values_match(selected_provider, &provider, &reference) {
        LegacyMarketDataRightsStatus::ValidButNonAuthoritative
    } else {
        LegacyMarketDataRightsStatus::InvalidButNonAuthoritative
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MarketDataPermittedUses {
    model_input: bool,
    customer_external_display: bool,
    derived_output_publication: bool,
    raw_data_redistribution: bool,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MarketDataRawRedistributionSupport {
    evidence_kind: String,
    evidence_artifact_sha256: String,
    official_evidence_url: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MarketDataOwnerAttestation {
    issuer_role: String,
    signed_at: DateTime<Utc>,
    account_identity_sha256: String,
    subscription_reference_kind: String,
    subscription_identity_sha256: String,
    technical_entitlement_receipt_sha256: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MarketDataRightsReceipt {
    schema_version: String,
    provider: String,
    product: String,
    legal_entity: String,
    plan_name: String,
    plan_status: String,
    permitted_uses: MarketDataPermittedUses,
    evidence_kind: String,
    evidence_artifact_sha256: String,
    account_license_reference_sha256: String,
    official_terms_url: String,
    official_product_url: String,
    #[serde(default)]
    official_evidence_url: Option<String>,
    #[serde(default)]
    owner_attestation: Option<MarketDataOwnerAttestation>,
    #[serde(default)]
    raw_data_redistribution_support: Option<MarketDataRawRedistributionSupport>,
    valid_from: DateTime<Utc>,
    valid_until: DateTime<Utc>,
    issuer: String,
    reviewer: String,
    issued_at: DateTime<Utc>,
    reviewed_at: DateTime<Utc>,
    review_due_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct DatabentoTechnicalEntitlementEndpoint {
    host: String,
    path: String,
    status: u16,
    response_sha256: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct DatabentoTechnicalEntitlementRange {
    dataset_start: DateTime<Utc>,
    dataset_end: DateTime<Utc>,
    schema: String,
    schema_start: DateTime<Utc>,
    schema_end: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct DatabentoTechnicalEntitlementReceipt {
    schema_version: String,
    status: String,
    provider: String,
    product: String,
    dataset: String,
    captured_at: DateTime<Utc>,
    endpoints: Vec<DatabentoTechnicalEntitlementEndpoint>,
    entitled: bool,
    range: DatabentoTechnicalEntitlementRange,
}

fn market_data_rights_result(
    status: MarketDataRightsStatus,
    reason: MarketDataRightsReason,
    legacy_environment_status: LegacyMarketDataRightsStatus,
) -> MarketDataRightsReadinessReceipt {
    MarketDataRightsReadinessReceipt {
        status,
        reason,
        legacy_environment_status,
    }
}

fn valid_sha256_pin(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn safe_receipt_label(value: &str, maximum_length: usize) -> bool {
    value.trim() == value
        && !value.is_empty()
        && value.len() <= maximum_length
        && !value.chars().any(char::is_control)
}

fn allowed_vendor_rights_evidence_kind(value: &str) -> bool {
    matches!(
        value,
        "EXECUTED_AGREEMENT" | "ORDER_CONFIRMATION" | "VENDOR_WRITTEN_CONFIRMATION"
    )
}

fn allowed_rights_evidence_kind(value: &str) -> bool {
    allowed_vendor_rights_evidence_kind(value) || value == "ACCOUNT_OWNER_ATTESTATION"
}

fn official_provider_domain(provider: &str) -> Option<&'static str> {
    match provider {
        "databento" => Some("databento.com"),
        "massive" => Some("massive.com"),
        _ => None,
    }
}

fn safe_official_https_url(raw: &str, provider: &str) -> Option<reqwest::Url> {
    if raw.trim() != raw || raw.len() > 2_048 {
        return None;
    }
    let Ok(reference) = reqwest::Url::parse(raw) else {
        return None;
    };
    if reference.scheme() != "https"
        || !reference.username().is_empty()
        || reference.password().is_some()
        || reference.query().is_some()
        || reference.fragment().is_some()
        || reference.port_or_known_default() != Some(443)
        || matches!(reference.path(), "" | "/")
    {
        return None;
    }
    let host = reference.host_str().map(str::to_ascii_lowercase)?;
    let approved_host = official_provider_domain(provider)?;
    let host_is_official = host == approved_host || host.ends_with(&format!(".{approved_host}"));
    (host != "localhost"
        && !host.ends_with(".localhost")
        && host.contains('.')
        && host.parse::<std::net::IpAddr>().is_err()
        && host_is_official)
        .then_some(reference)
}

fn url_has_any_path_segment(reference: &reqwest::Url, allowed: &[&str]) -> bool {
    reference
        .path()
        .split('/')
        .filter(|segment| !segment.is_empty())
        .map(str::to_ascii_lowercase)
        .any(|segment| allowed.contains(&segment.as_str()))
}

fn safe_official_terms_reference(raw: &str, provider: &str) -> bool {
    safe_official_https_url(raw, provider).is_some_and(|reference| {
        url_has_any_path_segment(
            &reference,
            &[
                "agreement",
                "agreements",
                "legal",
                "license",
                "licenses",
                "licensing",
                "policies",
                "policy",
                "terms",
            ],
        )
    })
}

fn safe_official_product_reference(raw: &str, provider: &str) -> bool {
    safe_official_https_url(raw, provider).is_some_and(|reference| {
        url_has_any_path_segment(
            &reference,
            &[
                "dataset", "datasets", "equities", "product", "products", "stocks",
            ],
        )
    })
}

fn safe_official_evidence_reference(raw: &str, provider: &str) -> bool {
    safe_official_https_url(raw, provider).is_some_and(|reference| {
        url_has_any_path_segment(
            &reference,
            &[
                "agreement",
                "agreements",
                "case",
                "cases",
                "confirmation",
                "confirmations",
                "contract",
                "contracts",
                "entitlement",
                "entitlements",
                "license",
                "licenses",
                "order",
                "orders",
                "receipt",
                "receipts",
                "rights",
                "support",
                "ticket",
                "tickets",
            ],
        )
    })
}

fn owner_issuer_implies_vendor(issuer: &str, provider: &str) -> bool {
    let normalized_issuer = issuer.trim().to_ascii_lowercase();
    let normalized_provider = provider.trim().to_ascii_lowercase();
    let Some(official_domain) = official_provider_domain(provider) else {
        return true;
    };
    normalized_provider.is_empty()
        || normalized_issuer.contains(&normalized_provider)
        || normalized_issuer.contains(official_domain)
}

fn all_hashes_are_distinct(values: &[&str]) -> bool {
    values.iter().enumerate().all(|(index, value)| {
        values[index + 1..]
            .iter()
            .all(|other| !value.eq_ignore_ascii_case(other))
    })
}

fn validate_databento_technical_entitlement_receipt(
    bytes: Option<&[u8]>,
    expected_sha256: &str,
    selected_provider: &str,
    selected_product: &str,
    attestation_signed_at: DateTime<Utc>,
) -> std::result::Result<(), MarketDataRightsReason> {
    let bytes = bytes.ok_or(MarketDataRightsReason::TechnicalEntitlementReceiptMissing)?;
    if bytes.is_empty() || bytes.len() as u64 > MAX_MARKET_DATA_TECHNICAL_ENTITLEMENT_RECEIPT_BYTES
    {
        return Err(MarketDataRightsReason::TechnicalEntitlementReceiptInvalid);
    }
    if !valid_sha256_pin(expected_sha256)
        || !format!("{:x}", Sha256::digest(bytes)).eq_ignore_ascii_case(expected_sha256)
    {
        return Err(MarketDataRightsReason::TechnicalEntitlementReceiptHashMismatch);
    }
    let receipt = serde_json::from_slice::<DatabentoTechnicalEntitlementReceipt>(bytes)
        .map_err(|_| MarketDataRightsReason::TechnicalEntitlementReceiptInvalid)?;
    if receipt.schema_version != MARKET_DATA_TECHNICAL_ENTITLEMENT_SCHEMA_VERSION
        || receipt.status != "TECHNICAL_ENTITLEMENT_VERIFIED"
        || receipt.provider != "databento"
        || receipt.provider != selected_provider
        || receipt.product != "Databento US Equities Mini"
        || receipt.dataset != "EQUS.MINI"
        || receipt.dataset != selected_product
        || !receipt.entitled
    {
        return Err(MarketDataRightsReason::TechnicalEntitlementReceiptInvalid);
    }
    let expected_endpoints = [
        "/v0/metadata.list_datasets",
        "/v0/metadata.list_schemas",
        "/v0/metadata.get_dataset_range",
    ];
    if receipt.endpoints.len() != expected_endpoints.len()
        || receipt
            .endpoints
            .iter()
            .zip(expected_endpoints)
            .any(|(endpoint, expected_path)| {
                endpoint.host != "hist.databento.com"
                    || endpoint.path != expected_path
                    || !(200..300).contains(&endpoint.status)
                    || !valid_sha256_pin(&endpoint.response_sha256)
            })
        || receipt.range.schema != "ohlcv-1m"
        || receipt.range.dataset_start >= receipt.range.dataset_end
        || receipt.range.schema_start >= receipt.range.schema_end
        || receipt.range.schema_start < receipt.range.dataset_start
        || receipt.range.schema_end > receipt.range.dataset_end
    {
        return Err(MarketDataRightsReason::TechnicalEntitlementReceiptInvalid);
    }
    // This receipt is point-in-time evidence supporting the owner's signature,
    // not a rolling live-feed heartbeat. Current rights/review clocks and live
    // provider/feed freshness are enforced independently.
    let age_at_signing_seconds = attestation_signed_at
        .signed_duration_since(receipt.captured_at)
        .num_seconds();
    if !(-MAX_OWNER_TECHNICAL_ENTITLEMENT_FUTURE_SKEW_SECONDS
        ..=MAX_OWNER_TECHNICAL_ENTITLEMENT_AGE_SECONDS)
        .contains(&age_at_signing_seconds)
    {
        return Err(MarketDataRightsReason::TechnicalEntitlementReceiptStale);
    }
    Ok(())
}

pub(crate) fn read_market_data_technical_entitlement_receipt_bytes(root: &Path) -> Option<Vec<u8>> {
    let path = root.join(MARKET_DATA_TECHNICAL_ENTITLEMENT_RECEIPT_RELATIVE_PATH);
    let canonical_root = fs::canonicalize(root).ok()?;
    let canonical_path = fs::canonicalize(path).ok()?;
    let metadata = fs::metadata(&canonical_path).ok()?;
    if !canonical_path.starts_with(canonical_root)
        || !metadata.is_file()
        || metadata.len() == 0
        || metadata.len() > MAX_MARKET_DATA_TECHNICAL_ENTITLEMENT_RECEIPT_BYTES
    {
        return None;
    }
    fs::read(canonical_path).ok()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum MarketDataRightsUseRequirement {
    ModelInputOnly,
    ProductionPublication,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum MarketDataRightsEvidenceBasis {
    VendorOrVenueEvidence,
    OwnerAttestedWithTechnicalEntitlement,
}

pub(crate) struct ValidatedMarketDataRightsReceipt {
    pub(crate) receipt_sha256: String,
    pub(crate) evidence_basis: MarketDataRightsEvidenceBasis,
}

pub(crate) fn validate_market_data_rights_receipt_bytes(
    bytes: &[u8],
    expected_sha256: &str,
    selected_provider: &str,
    selected_product: &str,
    now: DateTime<Utc>,
    use_requirement: MarketDataRightsUseRequirement,
    technical_entitlement_receipt_bytes: Option<&[u8]>,
) -> std::result::Result<ValidatedMarketDataRightsReceipt, MarketDataRightsReason> {
    if !valid_sha256_pin(expected_sha256) {
        return Err(MarketDataRightsReason::PinInvalid);
    }
    let observed_sha256 = format!("{:x}", Sha256::digest(bytes));
    if !observed_sha256.eq_ignore_ascii_case(expected_sha256) {
        return Err(MarketDataRightsReason::HashMismatch);
    }
    let receipt = serde_json::from_slice::<MarketDataRightsReceipt>(bytes)
        .map_err(|_| MarketDataRightsReason::ReceiptInvalid)?;
    if receipt.schema_version != MARKET_DATA_RIGHTS_RECEIPT_SCHEMA_VERSION {
        return Err(MarketDataRightsReason::SchemaUnsupported);
    }
    if receipt.provider != selected_provider.trim() {
        return Err(MarketDataRightsReason::ProviderMismatch);
    }
    if receipt.product != selected_product.trim() {
        return Err(MarketDataRightsReason::ProductMismatch);
    }
    if !safe_receipt_label(&receipt.legal_entity, 256) {
        return Err(MarketDataRightsReason::LegalEntityInvalid);
    }
    if !safe_receipt_label(&receipt.plan_name, 128) || !safe_receipt_label(&receipt.plan_status, 32)
    {
        return Err(MarketDataRightsReason::PlanInvalid);
    }
    if receipt.plan_status != "ACTIVE" {
        return Err(MarketDataRightsReason::PlanNotActive);
    }
    if !allowed_rights_evidence_kind(&receipt.evidence_kind) {
        return Err(MarketDataRightsReason::EvidenceKindUnsupported);
    }
    if !valid_sha256_pin(&receipt.evidence_artifact_sha256)
        || receipt
            .evidence_artifact_sha256
            .eq_ignore_ascii_case(expected_sha256)
    {
        return Err(MarketDataRightsReason::EvidenceArtifactHashInvalid);
    }
    if !valid_sha256_pin(&receipt.account_license_reference_sha256)
        || receipt
            .account_license_reference_sha256
            .eq_ignore_ascii_case(&receipt.evidence_artifact_sha256)
        || receipt
            .account_license_reference_sha256
            .eq_ignore_ascii_case(expected_sha256)
    {
        return Err(MarketDataRightsReason::AccountLicenseReferenceHashInvalid);
    }
    let is_owner_attestation = receipt.evidence_kind == "ACCOUNT_OWNER_ATTESTATION";
    if !receipt.permitted_uses.model_input {
        return Err(MarketDataRightsReason::ModelInputNotPermitted);
    }
    if (use_requirement == MarketDataRightsUseRequirement::ProductionPublication
        || is_owner_attestation)
        && !receipt.permitted_uses.customer_external_display
    {
        return Err(MarketDataRightsReason::CustomerExternalDisplayNotPermitted);
    }
    if (use_requirement == MarketDataRightsUseRequirement::ProductionPublication
        || is_owner_attestation)
        && !receipt.permitted_uses.derived_output_publication
    {
        return Err(MarketDataRightsReason::DerivedOutputPublicationNotPermitted);
    }
    if is_owner_attestation
        && (receipt.permitted_uses.raw_data_redistribution
            || receipt.raw_data_redistribution_support.is_some())
    {
        return Err(MarketDataRightsReason::RawDataRedistributionUnsupported);
    }
    let raw_redistribution_support_is_valid = receipt
        .raw_data_redistribution_support
        .as_ref()
        .is_some_and(|support| {
            allowed_vendor_rights_evidence_kind(&support.evidence_kind)
                && valid_sha256_pin(&support.evidence_artifact_sha256)
                && !support
                    .evidence_artifact_sha256
                    .eq_ignore_ascii_case(&receipt.evidence_artifact_sha256)
                && !support
                    .evidence_artifact_sha256
                    .eq_ignore_ascii_case(&receipt.account_license_reference_sha256)
                && !support
                    .evidence_artifact_sha256
                    .eq_ignore_ascii_case(expected_sha256)
                && receipt.official_evidence_url.as_deref()
                    != Some(support.official_evidence_url.as_str())
                && safe_official_evidence_reference(
                    &support.official_evidence_url,
                    &receipt.provider,
                )
        });
    if (receipt.permitted_uses.raw_data_redistribution && !raw_redistribution_support_is_valid)
        || (!receipt.permitted_uses.raw_data_redistribution
            && receipt.raw_data_redistribution_support.is_some())
    {
        return Err(MarketDataRightsReason::RawDataRedistributionUnsupported);
    }
    if receipt.valid_from >= receipt.valid_until {
        return Err(MarketDataRightsReason::TemporalBindingInvalid);
    }
    if now < receipt.valid_from {
        return Err(MarketDataRightsReason::ValidityNotStarted);
    }
    if now > receipt.valid_until {
        return Err(MarketDataRightsReason::ValidityExpired);
    }
    if receipt.issued_at > receipt.reviewed_at
        || receipt.reviewed_at > now
        || receipt.reviewed_at < receipt.valid_from
        || receipt.reviewed_at > receipt.valid_until
        || receipt.review_due_at <= receipt.reviewed_at
        || receipt.review_due_at > receipt.valid_until
    {
        return Err(MarketDataRightsReason::TemporalBindingInvalid);
    }
    if now > receipt.review_due_at {
        return Err(MarketDataRightsReason::ReviewExpired);
    }
    if !safe_receipt_label(&receipt.issuer, 128) {
        return Err(MarketDataRightsReason::IssuerInvalid);
    }
    if !safe_receipt_label(&receipt.reviewer, 128) {
        return Err(MarketDataRightsReason::ReviewerInvalid);
    }
    if !safe_official_terms_reference(&receipt.official_terms_url, &receipt.provider) {
        return Err(MarketDataRightsReason::OfficialTermsReferenceInvalid);
    }
    if !safe_official_product_reference(&receipt.official_product_url, &receipt.provider)
        || receipt.official_product_url == receipt.official_terms_url
    {
        return Err(MarketDataRightsReason::OfficialProductReferenceInvalid);
    }
    let evidence_basis = if is_owner_attestation {
        let owner = receipt
            .owner_attestation
            .as_ref()
            .ok_or(MarketDataRightsReason::OwnerAttestationInvalid)?;
        if receipt.official_evidence_url.is_some()
            || owner.issuer_role != "ACCOUNT_OWNER"
            || owner_issuer_implies_vendor(&receipt.issuer, &receipt.provider)
            || owner.signed_at != receipt.issued_at
            || owner.signed_at < receipt.valid_from
            || owner.signed_at > receipt.reviewed_at
            || !valid_sha256_pin(&owner.account_identity_sha256)
            || !matches!(
                owner.subscription_reference_kind.as_str(),
                "VENDOR_SUBSCRIPTION_ID" | "OWNER_DEFINED_NOT_VENDOR_ID"
            )
            || !valid_sha256_pin(&owner.subscription_identity_sha256)
            || !valid_sha256_pin(&owner.technical_entitlement_receipt_sha256)
            || !all_hashes_are_distinct(&[
                expected_sha256,
                &receipt.evidence_artifact_sha256,
                &receipt.account_license_reference_sha256,
                &owner.account_identity_sha256,
                &owner.subscription_identity_sha256,
                &owner.technical_entitlement_receipt_sha256,
            ])
        {
            return Err(MarketDataRightsReason::OwnerAttestationInvalid);
        }
        validate_databento_technical_entitlement_receipt(
            technical_entitlement_receipt_bytes,
            &owner.technical_entitlement_receipt_sha256,
            &receipt.provider,
            &receipt.product,
            owner.signed_at,
        )?;
        MarketDataRightsEvidenceBasis::OwnerAttestedWithTechnicalEntitlement
    } else {
        if receipt.owner_attestation.is_some() {
            return Err(MarketDataRightsReason::OwnerAttestationInvalid);
        }
        let evidence_url = receipt
            .official_evidence_url
            .as_deref()
            .ok_or(MarketDataRightsReason::EvidenceReferenceInvalid)?;
        if evidence_url == receipt.official_terms_url
            || evidence_url == receipt.official_product_url
            || !safe_official_evidence_reference(evidence_url, &receipt.provider)
        {
            return Err(MarketDataRightsReason::EvidenceReferenceInvalid);
        }
        MarketDataRightsEvidenceBasis::VendorOrVenueEvidence
    };
    Ok(ValidatedMarketDataRightsReceipt {
        receipt_sha256: observed_sha256,
        evidence_basis,
    })
}

fn inspect_market_data_rights(
    root: &Path,
    selected_provider: &str,
    selected_product: Option<&str>,
    now: DateTime<Utc>,
    expected_sha256: Option<&str>,
    legacy_environment_status: LegacyMarketDataRightsStatus,
) -> MarketDataRightsReadinessReceipt {
    let Some(selected_product) = selected_product.filter(|value| !value.trim().is_empty()) else {
        return market_data_rights_result(
            MarketDataRightsStatus::Blocked,
            MarketDataRightsReason::SelectedProductUnavailable,
            legacy_environment_status,
        );
    };
    let path = root.join(MARKET_DATA_RIGHTS_RECEIPT_RELATIVE_PATH);
    if !path.is_file() {
        return market_data_rights_result(
            MarketDataRightsStatus::Unavailable,
            MarketDataRightsReason::ReceiptMissing,
            legacy_environment_status,
        );
    }
    let Some(expected_sha256) = expected_sha256
        .map(str::trim)
        .filter(|value| !value.is_empty())
    else {
        return market_data_rights_result(
            MarketDataRightsStatus::Blocked,
            MarketDataRightsReason::PinMissing,
            legacy_environment_status,
        );
    };
    if !valid_sha256_pin(expected_sha256) {
        return market_data_rights_result(
            MarketDataRightsStatus::Blocked,
            MarketDataRightsReason::PinInvalid,
            legacy_environment_status,
        );
    }
    let path_is_scoped = fs::canonicalize(root)
        .ok()
        .zip(fs::canonicalize(&path).ok())
        .is_some_and(|(canonical_root, canonical_path)| canonical_path.starts_with(canonical_root));
    let size_is_bounded = fs::metadata(&path)
        .ok()
        .is_some_and(|metadata| metadata.len() <= MAX_MARKET_DATA_RIGHTS_RECEIPT_BYTES);
    if !path_is_scoped || !size_is_bounded {
        return market_data_rights_result(
            MarketDataRightsStatus::Blocked,
            MarketDataRightsReason::ReceiptUnreadable,
            legacy_environment_status,
        );
    }
    let Ok(bytes) = fs::read(&path) else {
        return market_data_rights_result(
            MarketDataRightsStatus::Blocked,
            MarketDataRightsReason::ReceiptUnreadable,
            legacy_environment_status,
        );
    };
    let technical_entitlement_receipt = read_market_data_technical_entitlement_receipt_bytes(root);
    match validate_market_data_rights_receipt_bytes(
        &bytes,
        expected_sha256,
        selected_provider,
        selected_product,
        now,
        MarketDataRightsUseRequirement::ProductionPublication,
        technical_entitlement_receipt.as_deref(),
    ) {
        Ok(validated) => {
            let reason = match validated.evidence_basis {
                MarketDataRightsEvidenceBasis::VendorOrVenueEvidence => {
                    MarketDataRightsReason::Verified
                }
                MarketDataRightsEvidenceBasis::OwnerAttestedWithTechnicalEntitlement => {
                    MarketDataRightsReason::OwnerAttestedWithTechnicalEntitlement
                }
            };
            market_data_rights_result(
                MarketDataRightsStatus::Ready,
                reason,
                legacy_environment_status,
            )
        }
        Err(reason) => market_data_rights_result(
            MarketDataRightsStatus::Blocked,
            reason,
            legacy_environment_status,
        ),
    }
}

pub(crate) fn pinned_market_data_rights_receipt_is_verified(
    root: &Path,
    provider: &str,
    product: &str,
    now: DateTime<Utc>,
    expected_sha256: Option<&str>,
) -> bool {
    let receipt = inspect_market_data_rights(
        root,
        provider,
        Some(product),
        now,
        expected_sha256,
        LegacyMarketDataRightsStatus::NotConfigured,
    );
    receipt.status == MarketDataRightsStatus::Ready && receipt.reason.is_ready_basis()
}

/// Validate the fixed private rights and technical-entitlement receipt paths
/// using the same parser and fail-closed rules as production readiness.
///
/// The returned value is sanitized: it contains no paths, hashes, identities,
/// URLs, signatures, account references, or provider response content.
pub fn validate_pinned_market_data_rights_receipt(
    root: &Path,
    provider: &str,
    product: &str,
    now: DateTime<Utc>,
    expected_sha256: &str,
) -> MarketDataRightsReadinessReceipt {
    inspect_market_data_rights(
        root,
        provider,
        Some(product),
        now,
        Some(expected_sha256),
        LegacyMarketDataRightsStatus::NotConfigured,
    )
}

fn market_data_rights_readiness(
    root: &Path,
    selected_provider: &str,
    selected_product: Option<&str>,
    now: DateTime<Utc>,
) -> MarketDataRightsReadinessReceipt {
    let expected_sha256 = env::var(MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV).ok();
    inspect_market_data_rights(
        root,
        selected_provider,
        selected_product,
        now,
        expected_sha256.as_deref(),
        legacy_market_data_rights_status(selected_provider),
    )
}

fn promotion_registry_evidence(root: &Path) -> PromotionRegistryEvidence {
    let inspection = inspect_promotion_registry(root);
    PromotionRegistryEvidence {
        present: inspection.present,
        status: public_promotion_registry_status(inspection.status),
    }
}

fn public_promotion_registry_status(
    status: PromotionRegistryInspectionStatus,
) -> PromotionRegistryStatus {
    match status {
        PromotionRegistryInspectionStatus::ActivePinned => PromotionRegistryStatus::ActivePinned,
        PromotionRegistryInspectionStatus::Invalid => PromotionRegistryStatus::Invalid,
        PromotionRegistryInspectionStatus::HashMismatch => PromotionRegistryStatus::HashMismatch,
        PromotionRegistryInspectionStatus::Unpinned => PromotionRegistryStatus::Unpinned,
        PromotionRegistryInspectionStatus::LegacySingleMigrationRequired => {
            PromotionRegistryStatus::LegacySingleMigrationRequired
        }
        PromotionRegistryInspectionStatus::Absent => PromotionRegistryStatus::Absent,
    }
}

fn calibration_registry_evidence() -> CalibrationRegistryEvidence {
    let inspection = inspect_calibration_registry();
    let status = match inspection.status {
        CalibrationRegistryInspectionStatus::PinnedV2 => {
            let fully_promoted = inspection.registry.as_ref().is_some_and(|registry| {
                !registry.artifacts.is_empty()
                    && registry
                        .artifacts
                        .iter()
                        .all(|artifact| artifact.lifecycle == CalibrationLifecycle::PromotedOos)
            });
            if fully_promoted {
                CalibrationRegistryStatus::Promoted
            } else {
                CalibrationRegistryStatus::ValidUnpromoted
            }
        }
        CalibrationRegistryInspectionStatus::LegacyV1MigrationRequired => {
            CalibrationRegistryStatus::LegacyV1MigrationRequired
        }
        CalibrationRegistryInspectionStatus::ArtifactNotConfigured => {
            CalibrationRegistryStatus::NotConfigured
        }
        CalibrationRegistryInspectionStatus::ArtifactAbsent => CalibrationRegistryStatus::Absent,
        CalibrationRegistryInspectionStatus::PinNotConfigured
        | CalibrationRegistryInspectionStatus::PinInvalid => CalibrationRegistryStatus::Unpinned,
        CalibrationRegistryInspectionStatus::HashMismatch => {
            CalibrationRegistryStatus::HashMismatch
        }
        CalibrationRegistryInspectionStatus::Invalid => CalibrationRegistryStatus::Invalid,
    };
    CalibrationRegistryEvidence {
        present: inspection.present,
        status,
        registry: inspection
            .registry
            .filter(ProbabilityCalibrationRegistry::is_serving_schema),
    }
}

fn parse_timestamp(value: Option<&Value>) -> Option<DateTime<Utc>> {
    value
        .and_then(Value::as_str)
        .and_then(|raw| DateTime::parse_from_rfc3339(raw).ok())
        .map(|timestamp| timestamp.with_timezone(&Utc))
}

fn freshness_at(
    timestamp: Option<DateTime<Utc>>,
    now: DateTime<Utc>,
    maximum_age_seconds: i64,
) -> FreshnessStatus {
    let Some(timestamp) = timestamp else {
        return FreshnessStatus::Unavailable;
    };
    if maximum_age_seconds <= 0 {
        return FreshnessStatus::Blocked;
    }
    let age = now.signed_duration_since(timestamp).num_seconds();
    if age < 0 {
        FreshnessStatus::Future
    } else if age <= maximum_age_seconds {
        FreshnessStatus::Fresh
    } else {
        FreshnessStatus::Stale
    }
}

fn read_json(path: &Path) -> Option<Value> {
    fs::read(path)
        .ok()
        .and_then(|bytes| serde_json::from_slice(&bytes).ok())
}

fn read_last_json_line(path: &Path) -> Option<Value> {
    const TAIL_BYTES: u64 = 64 * 1024;
    let mut file = fs::File::open(path).ok()?;
    let length = file.metadata().ok()?.len();
    let start = length.saturating_sub(TAIL_BYTES);
    file.seek(SeekFrom::Start(start)).ok()?;
    let mut bytes = Vec::with_capacity((length - start) as usize);
    file.read_to_end(&mut bytes).ok()?;
    let text = String::from_utf8_lossy(&bytes);
    text.lines()
        .rev()
        .find(|line| !line.trim().is_empty())
        .and_then(|line| serde_json::from_str(line).ok())
}

fn provider_entitlement(root: &Path, provider: &str, enabled: bool) -> EvidenceStatus {
    if !enabled {
        return EvidenceStatus::Disabled;
    }
    if provider.eq_ignore_ascii_case("massive") {
        return match read_json(&root.join("live/massive_readiness.json")) {
            Some(value) if readiness_scopes_from_receipt(&value).equity_realtime_ready => {
                EvidenceStatus::Ready
            }
            Some(_) => EvidenceStatus::Blocked,
            None => EvidenceStatus::Unavailable,
        };
    }
    if provider.eq_ignore_ascii_case("databento") {
        return match read_json(&root.join("live/databento_stream_status.json")) {
            Some(value)
                if value.get("authenticated").and_then(Value::as_bool) == Some(true)
                    && value.get("entitlement_verified").and_then(Value::as_bool) == Some(true)
                    && value.get("replay_requested").and_then(Value::as_bool) == Some(false)
                    && value.get("execution_enabled").and_then(Value::as_bool) == Some(false) =>
            {
                EvidenceStatus::Ready
            }
            Some(_) => EvidenceStatus::Blocked,
            None => EvidenceStatus::Unavailable,
        };
    }
    match read_json(&root.join("live/status.json")) {
        Some(value)
            if value.get("tcp_connected").and_then(Value::as_bool) == Some(true)
                && value.get("login_status").and_then(Value::as_str)
                    == Some("VERIFIED_BY_OFFICIAL_SDK_CALLBACK")
                && value
                    .get("quote_rights")
                    .and_then(Value::as_str)
                    .is_some_and(|status| status.contains("VERIFIED")) =>
        {
            EvidenceStatus::Ready
        }
        Some(_) => EvidenceStatus::Blocked,
        None => EvidenceStatus::Unavailable,
    }
}

fn stream_freshness(
    root: &Path,
    provider: &str,
    enabled: bool,
    now: DateTime<Utc>,
    maximum_age_seconds: i64,
) -> FreshnessStatus {
    if !enabled {
        return FreshnessStatus::Disabled;
    }
    if provider.eq_ignore_ascii_case("massive") {
        let Some(value) = read_json(&root.join("live/massive_stream_status.json")) else {
            return FreshnessStatus::Unavailable;
        };
        let streaming = value.get("authenticated").and_then(Value::as_bool) == Some(true)
            && matches!(
                value.get("state").and_then(Value::as_str),
                Some("STREAMING_REALTIME" | "COMPLETE")
            )
            && value.get("blocker").is_none_or(Value::is_null);
        if !streaming {
            return FreshnessStatus::Blocked;
        }
        return freshness_at(
            parse_timestamp(value.get("updated_at")),
            now,
            maximum_age_seconds,
        );
    }
    if provider.eq_ignore_ascii_case("databento") {
        let Some(value) = read_json(&root.join("live/databento_stream_status.json")) else {
            return FreshnessStatus::Unavailable;
        };
        let streaming = value.get("authenticated").and_then(Value::as_bool) == Some(true)
            && value.get("entitlement_verified").and_then(Value::as_bool) == Some(true)
            && value.get("state").and_then(Value::as_str) == Some("STREAMING_REALTIME")
            && value.get("blocker").is_none_or(Value::is_null);
        if !streaming {
            return FreshnessStatus::Blocked;
        }
        return freshness_at(
            parse_timestamp(value.get("updated_at")),
            now,
            maximum_age_seconds,
        );
    }
    let Some(value) = read_json(&root.join("live/status.json")) else {
        return FreshnessStatus::Unavailable;
    };
    if value.get("tcp_connected").and_then(Value::as_bool) != Some(true)
        || value.get("login_status").and_then(Value::as_str)
            != Some("VERIFIED_BY_OFFICIAL_SDK_CALLBACK")
    {
        return FreshnessStatus::Blocked;
    }
    freshness_at(
        parse_timestamp(value.get("checked_at")),
        now,
        maximum_age_seconds,
    )
}

fn feed_freshness(
    root: &Path,
    provider: &str,
    enabled: bool,
    required_symbols: &[String],
    now: DateTime<Utc>,
    maximum_age_seconds: i64,
) -> FreshnessStatus {
    if !enabled {
        return FreshnessStatus::Disabled;
    }
    if provider.eq_ignore_ascii_case("databento")
        && let Some(status) = read_json(&root.join("live/databento_stream_status.json"))
        && status.get("schema_version").and_then(Value::as_str)
            == Some(crate::data::databento_live::DATABENTO_LIVE_STATUS_SCHEMA_VERSION)
    {
        let Some(coverage) = status.get("symbol_coverage").and_then(Value::as_object) else {
            return FreshnessStatus::Unavailable;
        };
        if required_symbols.is_empty() {
            return FreshnessStatus::Unavailable;
        }
        let mut aggregate = FreshnessStatus::Fresh;
        for raw_symbol in required_symbols {
            let symbol = normalized_symbol(raw_symbol);
            let Some(row) = coverage.get(&symbol).and_then(Value::as_object) else {
                return FreshnessStatus::Unavailable;
            };
            if row.get("latest_observation_state").and_then(Value::as_str)
                != Some("observed_trade_bar")
            {
                return FreshnessStatus::Blocked;
            }
            let freshness = freshness_at(
                parse_timestamp(
                    row.get("latest_received_at")
                        .or_else(|| row.get("latest_observed_interval_end")),
                ),
                now,
                maximum_age_seconds,
            );
            aggregate = match (aggregate, freshness) {
                (_, FreshnessStatus::Blocked) => FreshnessStatus::Blocked,
                (_, FreshnessStatus::Unavailable) => FreshnessStatus::Unavailable,
                (_, FreshnessStatus::Future) => FreshnessStatus::Future,
                (FreshnessStatus::Fresh, FreshnessStatus::Stale) => FreshnessStatus::Stale,
                (current, _) => current,
            };
        }
        return aggregate;
    }
    let filename = if provider.eq_ignore_ascii_case("massive") {
        "massive_stock_bars.jsonl"
    } else if provider.eq_ignore_ascii_case("databento") {
        "databento_stock_bars.jsonl"
    } else {
        "finalized_bars.jsonl"
    };
    let Some(value) = read_last_json_line(&root.join("live").join(filename)) else {
        return FreshnessStatus::Unavailable;
    };
    if provider.eq_ignore_ascii_case("massive") {
        if value.get("delayed").and_then(Value::as_bool) == Some(true)
            || value.get("stale").and_then(Value::as_bool) == Some(true)
            || value.get("entitlement").and_then(Value::as_str) != Some("REALTIME_AUTHENTICATED")
        {
            return FreshnessStatus::Blocked;
        }
    } else if provider.eq_ignore_ascii_case("databento") {
        if value.get("replay").and_then(Value::as_bool) != Some(false)
            || value.get("delayed").and_then(Value::as_bool) != Some(false)
            || value.get("stale").and_then(Value::as_bool) != Some(false)
            || value
                .get("symbol_mapping_verified")
                .and_then(Value::as_bool)
                != Some(true)
            || value.get("entitlement").and_then(Value::as_str)
                != Some("REALTIME_SUBSCRIPTION_ACKNOWLEDGED")
        {
            return FreshnessStatus::Blocked;
        }
    } else if value.get("is_replay").and_then(Value::as_bool) == Some(true)
        || value.get("is_cached_push").and_then(Value::as_bool) == Some(true)
    {
        return FreshnessStatus::Blocked;
    }
    let timestamp = [
        value.get("bar_end"),
        value.get("finalized_at"),
        value.get("finalized_timestamp"),
        value.get("available_timestamp"),
        value.get("receive_timestamp"),
        value.pointer("/bar/timestamp"),
    ]
    .into_iter()
    .find_map(parse_timestamp);
    freshness_at(timestamp, now, maximum_age_seconds)
}

fn horizon_coverage(
    payload: &Value,
    symbol: &str,
    configured_horizons: &[usize],
) -> ForecastCoverageStatus {
    let configured = configured_horizons.iter().copied().collect::<BTreeSet<_>>();
    let observed = payload
        .get("prediction_layer")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter(|row| row.get("symbol").and_then(Value::as_str) == Some(symbol))
        .filter_map(|row| {
            row.get("horizon_minutes")
                .and_then(Value::as_u64)
                .and_then(|value| usize::try_from(value).ok())
        })
        .collect::<BTreeSet<_>>();
    if observed.is_empty() {
        ForecastCoverageStatus::None
    } else if observed == configured {
        ForecastCoverageStatus::Complete
    } else {
        ForecastCoverageStatus::Partial
    }
}

fn row_matches_pinned_calibration(row: &Value, registry: &ProbabilityCalibrationRegistry) -> bool {
    let Some(artifact_id) = row
        .pointer("/probability_calibration/artifact_id")
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
    else {
        return false;
    };
    let Some(horizon_minutes) = row
        .get("horizon_minutes")
        .and_then(Value::as_u64)
        .and_then(|value| usize::try_from(value).ok())
    else {
        return false;
    };
    let Some(observation_cutoff) = parse_timestamp(row.get("observation_cutoff")) else {
        return false;
    };
    let Some(model_id) = row
        .get("model_id")
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
    else {
        return false;
    };
    let Some(model_hash) = row
        .get("model_hash")
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
    else {
        return false;
    };
    let Some(feature_version) = row
        .get("feature_version")
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
    else {
        return false;
    };
    row.pointer("/probability_calibration/eligible_for_probability_use")
        .and_then(Value::as_bool)
        == Some(true)
        && row
            .pointer("/probability_calibration/status")
            .and_then(Value::as_str)
            == Some("PROMOTED_OOS_CALIBRATION_APPLIED")
        && row
            .pointer("/probability_calibration/calibrated_probability_up")
            .and_then(Value::as_f64)
            .is_some_and(|value| value.is_finite() && (0.0..=1.0).contains(&value))
        && registry.matches_promoted_artifact(&CalibrationArtifactBinding {
            artifact_id,
            horizon_minutes,
            observation_cutoff,
            model_id,
            model_hash,
            feature_version,
        })
}

fn forecast_calibration(
    payload: &Value,
    symbol: &str,
    configured_horizons: &[usize],
    registry: Option<&ProbabilityCalibrationRegistry>,
) -> ForecastCalibrationStatus {
    let Some(registry) = registry else {
        return ForecastCalibrationStatus::Unavailable;
    };
    let Some(rows) = payload.get("prediction_layer").and_then(Value::as_array) else {
        return ForecastCalibrationStatus::Unavailable;
    };
    let configured = configured_horizons.iter().copied().collect::<BTreeSet<_>>();
    if configured.is_empty() {
        return ForecastCalibrationStatus::Unavailable;
    }
    let symbol_rows = rows
        .iter()
        .filter(|row| row.get("symbol").and_then(Value::as_str) == Some(symbol))
        .collect::<Vec<_>>();
    if symbol_rows.is_empty() {
        return ForecastCalibrationStatus::Unavailable;
    }
    let mut observed = BTreeSet::new();
    let mut shape_valid = symbol_rows.len() == configured.len();
    let mut promoted = 0_usize;
    for row in symbol_rows {
        let horizon = row
            .get("horizon_minutes")
            .and_then(Value::as_u64)
            .and_then(|value| usize::try_from(value).ok());
        let horizon_is_unique_and_configured =
            horizon.is_some_and(|value| configured.contains(&value) && observed.insert(value));
        if !horizon_is_unique_and_configured {
            shape_valid = false;
        }
        if horizon_is_unique_and_configured && row_matches_pinned_calibration(row, registry) {
            promoted += 1;
        }
    }
    shape_valid &= observed == configured;
    if shape_valid && promoted == configured.len() {
        ForecastCalibrationStatus::Promoted
    } else if promoted > 0 {
        ForecastCalibrationStatus::Partial
    } else {
        ForecastCalibrationStatus::Unpromoted
    }
}

struct ForecastEvaluation<'a> {
    configured_horizons: &'a [usize],
    calibration_registry: Option<&'a ProbabilityCalibrationRegistry>,
    provider: &'a str,
    databento_batch_cutoff: Option<DateTime<Utc>>,
    databento_batch_committed_at: Option<DateTime<Utc>>,
    now: DateTime<Utc>,
    maximum_age_seconds: i64,
}

fn live_inference_readiness(
    root: &Path,
    symbol: &str,
    evaluation: &ForecastEvaluation<'_>,
) -> LiveInferenceReadinessReceipt {
    let required = evaluation.provider.eq_ignore_ascii_case("databento");
    if !required {
        return LiveInferenceReadinessReceipt {
            required: false,
            status_available: false,
            status: None,
            stage: None,
            reason_code: None,
            status_freshness: FreshnessStatus::Unavailable,
            cutoff: None,
            latest_input_available_at: None,
            compute_ms: None,
            end_to_end_ms: None,
            budget_ms: None,
            context_blockers: Vec::new(),
            forecast_committed: false,
            receipt_committed: false,
            ledger_persisted: false,
            ready: true,
        };
    }
    let Some(status) = read_target_status(root, symbol) else {
        return LiveInferenceReadinessReceipt {
            required: true,
            status_available: false,
            status: None,
            stage: None,
            reason_code: Some("TARGET_INFERENCE_STATUS_UNAVAILABLE".to_string()),
            status_freshness: FreshnessStatus::Unavailable,
            cutoff: None,
            latest_input_available_at: None,
            compute_ms: None,
            end_to_end_ms: None,
            budget_ms: None,
            context_blockers: Vec::new(),
            forecast_committed: false,
            receipt_committed: false,
            ledger_persisted: false,
            ready: false,
        };
    };
    let status_freshness = freshness_at(
        Some(status.observed_at),
        evaluation.now,
        evaluation.maximum_age_seconds,
    );
    let status_matches_atomic_batch = evaluation
        .databento_batch_cutoff
        .is_some_and(|cutoff| status.cutoff == Some(cutoff))
        && evaluation
            .databento_batch_committed_at
            .is_some_and(|committed_at| status.observed_at >= committed_at);
    let ready = status_freshness == FreshnessStatus::Fresh
        && status_matches_atomic_batch
        && status.status == TargetInferenceState::Published
        && status.forecast_committed
        && status.receipt_committed
        && status.ledger_persisted
        && !status.execution_enabled;
    LiveInferenceReadinessReceipt {
        required: true,
        status_available: true,
        status: Some(status.status),
        stage: Some(status.stage),
        reason_code: status.reason_code,
        status_freshness,
        cutoff: status.cutoff,
        latest_input_available_at: status.latest_input_available_at,
        compute_ms: status.compute_ms,
        end_to_end_ms: status.end_to_end_ms,
        budget_ms: Some(status.budget_ms),
        context_blockers: status.context_blockers,
        forecast_committed: status.forecast_committed,
        receipt_committed: status.receipt_committed,
        ledger_persisted: status.ledger_persisted,
        ready,
    }
}

fn symbol_forecast_readiness<V, P, L>(
    root: &Path,
    symbol: String,
    evaluation: &ForecastEvaluation<'_>,
    databento_payload: Option<&Value>,
    validate_bundle: &V,
    promotion_matches: &P,
    ledger_backed: &L,
) -> SymbolForecastReadiness
where
    V: Fn(&Value, &str, DateTime<Utc>, i64) -> bool,
    P: Fn(&Value) -> bool,
    L: Fn(&Value) -> bool,
{
    let live_inference = live_inference_readiness(root, &symbol, evaluation);
    let is_databento = evaluation.provider.eq_ignore_ascii_case("databento");
    let path = root.join("reports").join(live_forecast_filename(&symbol));
    let standalone_payload = if is_databento { None } else { read_json(&path) };
    let payload = if is_databento {
        databento_payload
    } else {
        standalone_payload.as_ref()
    };
    let Some(payload) = payload else {
        return SymbolForecastReadiness {
            symbol,
            live_inference,
            artifact_present: false,
            validation_status: ForecastValidationStatus::NotEvaluated,
            freshness: FreshnessStatus::Unavailable,
            horizon_coverage: ForecastCoverageStatus::None,
            calibration: ForecastCalibrationStatus::Unavailable,
            promotion_registry_matches: false,
            ledger_backed: false,
            ready: false,
        };
    };
    let validated = validate_bundle(
        payload,
        &symbol,
        evaluation.now,
        evaluation.maximum_age_seconds,
    );
    let artifact_freshness = if is_databento {
        freshness_at(
            evaluation.databento_batch_committed_at,
            evaluation.now,
            evaluation.maximum_age_seconds,
        )
    } else {
        freshness_at(
            parse_timestamp(payload.get("generated_at")),
            evaluation.now,
            evaluation.maximum_age_seconds,
        )
    };
    let atomic_batch_fresh = !is_databento || artifact_freshness == FreshnessStatus::Fresh;
    let rows = payload
        .get("prediction_layer")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let promotion_registry_matches =
        validated && !rows.is_empty() && rows.iter().all(promotion_matches);
    let ledger_backed =
        promotion_registry_matches && !rows.is_empty() && rows.iter().all(ledger_backed);
    let horizon_coverage = horizon_coverage(payload, &symbol, evaluation.configured_horizons);
    let calibration = forecast_calibration(
        payload,
        &symbol,
        evaluation.configured_horizons,
        evaluation.calibration_registry,
    );
    let ready = validated
        && atomic_batch_fresh
        && live_inference.ready
        && horizon_coverage == ForecastCoverageStatus::Complete
        && calibration == ForecastCalibrationStatus::Promoted
        && promotion_registry_matches
        && ledger_backed;
    SymbolForecastReadiness {
        symbol,
        live_inference,
        artifact_present: true,
        validation_status: if validated {
            ForecastValidationStatus::Passed
        } else {
            ForecastValidationStatus::Rejected
        },
        freshness: if validated && atomic_batch_fresh {
            FreshnessStatus::Fresh
        } else if validated {
            artifact_freshness
        } else if artifact_freshness == FreshnessStatus::Fresh {
            FreshnessStatus::Blocked
        } else {
            artifact_freshness
        },
        horizon_coverage,
        calibration,
        promotion_registry_matches,
        ledger_backed,
        ready,
    }
}

/// Build a sanitized receipt using the existing authoritative forecast,
/// promotion, and ledger validators supplied by the API module.
pub fn build<V, P, L>(
    config: &AppConfig,
    now: DateTime<Utc>,
    validate_bundle: V,
    promotion_matches: P,
    ledger_backed: L,
) -> ProductionReadinessReceipt
where
    V: Fn(&Value, &str, DateTime<Utc>, i64) -> bool,
    P: Fn(&Value) -> bool,
    L: Fn(&Value) -> bool,
{
    let root = root_for(config);
    let promotion_registry = promotion_registry_evidence(root);
    let calibration_registry = calibration_registry_evidence();
    let prediction_ledger_present = root.join("state/prediction_ledger.sqlite3").is_file();
    let selected_product = selected_market_data_product(config);
    let public_use_rights = market_data_rights_readiness(
        root,
        &config.live.provider,
        selected_product.as_deref(),
        now,
    );
    let provider_entitlement =
        provider_entitlement(root, &config.live.provider, config.live.enabled);
    let stream_freshness = stream_freshness(
        root,
        &config.live.provider,
        config.live.enabled,
        now,
        config.os.freshness_limit_seconds,
    );
    let feed_freshness = feed_freshness(
        root,
        &config.live.provider,
        config.live.enabled,
        &config
            .live
            .forecast_symbols
            .iter()
            .chain(config.live.required_context_symbols.iter())
            .cloned()
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>(),
        now,
        config.os.freshness_limit_seconds,
    );
    let production_forecast_contract_configured = production_forecast_contract_configured(config);
    let configured_forecast_symbols = config
        .live
        .forecast_symbols
        .iter()
        .map(|symbol| normalized_symbol(symbol))
        .collect::<BTreeSet<_>>();
    let symbols = REQUIRED_PRODUCTION_MODEL_SYMBOLS
        .into_iter()
        .map(str::to_string)
        .collect::<BTreeSet<_>>();
    // Resolve one ledger-backed manifest for the whole readiness evaluation.
    // Individual symbol reads could otherwise straddle two publications and
    // report a generation mix that never existed as an atomic batch.
    let databento_batch: Option<CommittedForecastBatch> =
        if config.live.provider.eq_ignore_ascii_case("databento")
            && production_forecast_contract_configured
        {
            read_latest_committed_forecast_batch(root, &configured_forecast_symbols)
        } else {
            None
        };
    let forecast_evaluation = ForecastEvaluation {
        configured_horizons: &REQUIRED_PRODUCTION_HORIZONS,
        calibration_registry: calibration_registry.registry.as_ref(),
        provider: &config.live.provider,
        databento_batch_cutoff: databento_batch.as_ref().map(|batch| batch.cutoff),
        databento_batch_committed_at: databento_batch.as_ref().map(|batch| batch.committed_at),
        now,
        maximum_age_seconds: config.os.freshness_limit_seconds,
    };
    let forecasts = symbols
        .into_iter()
        .map(|symbol| {
            let databento_payload = databento_batch
                .as_ref()
                .and_then(|batch| batch.forecasts.get(&symbol));
            symbol_forecast_readiness(
                root,
                symbol,
                &forecast_evaluation,
                databento_payload,
                &validate_bundle,
                &promotion_matches,
                &ledger_backed,
            )
        })
        .collect::<Vec<_>>();
    let all_forecasts_ready = !forecasts.is_empty() && forecasts.iter().all(|item| item.ready);
    let public_realtime_research_ready = config.live.enabled
        && public_use_rights.status == MarketDataRightsStatus::Ready
        && provider_entitlement == EvidenceStatus::Ready
        && stream_freshness == FreshnessStatus::Fresh
        && feed_freshness == FreshnessStatus::Fresh
        && promotion_registry.status == PromotionRegistryStatus::ActivePinned
        && calibration_registry.status == CalibrationRegistryStatus::Promoted
        && prediction_ledger_present
        && production_forecast_contract_configured
        && all_forecasts_ready;
    ProductionReadinessReceipt {
        schema_version: PRODUCTION_READINESS_SCHEMA_VERSION,
        status: if public_realtime_research_ready {
            OverallReadiness::Ready
        } else {
            OverallReadiness::Blocked
        },
        public_realtime_research_ready,
        llm: LlmReadinessReceipt {
            auth_status: LlmAuthStatus::ExternalUnknown,
        },
        market_data: MarketDataReadinessReceipt {
            selected_provider: config.live.provider.clone(),
            selected_product,
            live_enabled: config.live.enabled,
            public_use_rights,
            provider_entitlement,
            stream_freshness,
            feed_freshness,
        },
        artifacts: ArtifactReadinessReceipt {
            promotion_registry_present: promotion_registry.present,
            promotion_registry_status: promotion_registry.status,
            calibration_registry_present: calibration_registry.present,
            calibration_registry_status: calibration_registry.status,
            prediction_ledger_present,
        },
        forecasts,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::databento_inference::{
        DATABENTO_INFERENCE_STATUS_SCHEMA_VERSION, TargetInferenceStatus, status_path,
    };
    use crate::probability_calibration::{
        CALIBRATION_SCHEMA_VERSION, CalibrationMethod, OosCalibrationMetrics,
        ProbabilityCalibrationArtifact, ReliabilityBin, TimePartition,
    };
    use chrono::Duration;
    use chrono::TimeZone;
    use serde_json::json;
    use tempfile::tempdir;

    fn promoted_calibration_registry(now: DateTime<Utc>) -> ProbabilityCalibrationRegistry {
        let artifacts = [5, 15, 30, 60]
            .into_iter()
            .map(|horizon_minutes| ProbabilityCalibrationArtifact {
                artifact_id: format!("cal-{horizon_minutes}m"),
                created_at: now - Duration::days(9),
                horizon_minutes,
                target_model_id: "model-v2".into(),
                target_model_hash: "model-hash-v2".into(),
                feature_version: "features-v2".into(),
                calibrator_fit_window: TimePartition {
                    start: now - Duration::days(40),
                    end_exclusive: now - Duration::days(30),
                },
                untouched_oos_evaluation_window: TimePartition {
                    start: now - Duration::days(20),
                    end_exclusive: now - Duration::days(10),
                },
                valid_from: now - Duration::days(8),
                valid_until: None,
                method: CalibrationMethod::Isotonic {
                    thresholds: vec![1.0],
                    values: vec![0.55],
                },
                oos_metrics: OosCalibrationMetrics {
                    sample_count: 100,
                    positive_count: 50,
                    brier_score: 0.2,
                    log_loss: 0.6,
                    expected_calibration_error: 0.0,
                    reliability_bins: vec![ReliabilityBin {
                        lower_bound: 0.0,
                        upper_bound: 1.0,
                        sample_count: 100,
                        mean_predicted_probability: 0.5,
                        observed_frequency: 0.5,
                    }],
                },
                lifecycle: CalibrationLifecycle::PromotedOos,
            })
            .collect();
        let registry = ProbabilityCalibrationRegistry {
            schema_version: CALIBRATION_SCHEMA_VERSION.into(),
            generated_at: now - Duration::days(7),
            artifacts,
        };
        registry.validate().unwrap();
        registry
    }

    #[test]
    fn databento_feed_freshness_requires_every_target_and_context_symbol() {
        let directory = tempdir().unwrap();
        fs::create_dir_all(directory.path().join("live")).unwrap();
        let now = Utc.with_ymd_and_hms(2026, 7, 28, 14, 31, 0).unwrap();
        let status_path = directory.path().join("live/databento_stream_status.json");
        let write_status = |uup_state: &str, uup_received: Option<DateTime<Utc>>| {
            fs::write(
                &status_path,
                serde_json::to_vec(&json!({
                    "schema_version":crate::data::databento_live::DATABENTO_LIVE_STATUS_SCHEMA_VERSION,
                    "symbol_coverage":{
                        "SPY":{
                            "latest_observation_state":"observed_trade_bar",
                            "latest_received_at":now - Duration::seconds(1)
                        },
                        "UUP":{
                            "latest_observation_state":uup_state,
                            "latest_received_at":uup_received
                        }
                    }
                }))
                .unwrap(),
            )
            .unwrap();
        };
        write_status("unknown_missing", None);
        assert_eq!(
            feed_freshness(
                directory.path(),
                "databento",
                true,
                &["SPY".into(), "UUP".into()],
                now,
                120,
            ),
            FreshnessStatus::Blocked
        );
        write_status("observed_trade_bar", Some(now - Duration::seconds(2)));
        assert_eq!(
            feed_freshness(
                directory.path(),
                "databento",
                true,
                &["SPY".into(), "UUP".into()],
                now,
                120,
            ),
            FreshnessStatus::Fresh
        );
    }

    fn promoted_calibration_row(
        now: DateTime<Utc>,
        horizon_minutes: usize,
        artifact_id: &str,
    ) -> Value {
        json!({
            "symbol":"SPY",
            "horizon_minutes":horizon_minutes,
            "observation_cutoff":now - Duration::seconds(30),
            "model_id":"model-v2",
            "model_hash":"model-hash-v2",
            "feature_version":"features-v2",
            "probability_calibration":{
                "artifact_id":artifact_id,
                "eligible_for_probability_use":true,
                "status":"PROMOTED_OOS_CALIBRATION_APPLIED",
                "calibrated_probability_up":0.55
            }
        })
    }

    #[test]
    fn freshness_fails_closed_for_missing_future_and_stale_timestamps() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 26, 12, 0, 0)
            .single()
            .unwrap();
        assert_eq!(freshness_at(None, now, 120), FreshnessStatus::Unavailable);
        assert_eq!(
            freshness_at(Some(now + chrono::Duration::seconds(1)), now, 120),
            FreshnessStatus::Future
        );
        assert_eq!(
            freshness_at(Some(now - chrono::Duration::seconds(121)), now, 120),
            FreshnessStatus::Stale
        );
        assert_eq!(
            freshness_at(Some(now - chrono::Duration::seconds(120)), now, 120),
            FreshnessStatus::Fresh
        );
    }

    #[test]
    fn production_contract_requires_all_nine_models_and_all_four_horizons() {
        let config = AppConfig::load("configs/production.yaml").unwrap();
        assert!(production_forecast_contract_configured(&config));

        let mut missing_horizon = config.clone();
        missing_horizon.research.horizons.pop();
        assert!(!production_forecast_contract_configured(&missing_horizon));

        let mut missing_live_symbol = config.clone();
        missing_live_symbol.live.forecast_symbols.pop();
        assert!(!production_forecast_contract_configured(
            &missing_live_symbol
        ));

        let mut additional_live_symbol = config.clone();
        additional_live_symbol
            .live
            .forecast_symbols
            .push("US.IWM".into());
        assert!(!production_forecast_contract_configured(
            &additional_live_symbol
        ));

        let mut duplicate_live_symbol = config.clone();
        duplicate_live_symbol.live.forecast_symbols[0] = "US.QQQ".into();
        assert!(!production_forecast_contract_configured(
            &duplicate_live_symbol
        ));

        let mut additional_research_target = config.clone();
        let mut additional_target = additional_research_target.research.targets[0].clone();
        additional_target.model_symbol = "IWM".into();
        additional_research_target
            .research
            .targets
            .push(additional_target);
        assert!(!production_forecast_contract_configured(
            &additional_research_target
        ));

        let mut missing_research_target = config;
        missing_research_target.research.targets.pop();
        assert!(!production_forecast_contract_configured(
            &missing_research_target
        ));
    }

    #[test]
    fn legacy_single_promotion_registry_is_exposed_as_migration_required_not_active() {
        assert_eq!(
            public_promotion_registry_status(
                PromotionRegistryInspectionStatus::LegacySingleMigrationRequired
            ),
            PromotionRegistryStatus::LegacySingleMigrationRequired
        );
        assert_ne!(
            public_promotion_registry_status(
                PromotionRegistryInspectionStatus::LegacySingleMigrationRequired
            ),
            PromotionRegistryStatus::ActivePinned
        );
    }

    fn rights_now() -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 7, 28, 16, 0, 0)
            .single()
            .unwrap()
    }

    fn valid_rights_receipt(now: DateTime<Utc>) -> MarketDataRightsReceipt {
        MarketDataRightsReceipt {
            schema_version: MARKET_DATA_RIGHTS_RECEIPT_SCHEMA_VERSION.to_string(),
            provider: "databento".to_string(),
            product: "EQUS.MINI".to_string(),
            legal_entity: "TEST LEGAL ENTITY".to_string(),
            plan_name: "TEST ACTIVE PLAN".to_string(),
            plan_status: "ACTIVE".to_string(),
            permitted_uses: MarketDataPermittedUses {
                model_input: true,
                customer_external_display: true,
                derived_output_publication: true,
                raw_data_redistribution: false,
            },
            evidence_kind: "EXECUTED_AGREEMENT".to_string(),
            evidence_artifact_sha256: "a".repeat(64),
            account_license_reference_sha256: "b".repeat(64),
            official_terms_url: "https://databento.com/legal/terms".to_string(),
            official_product_url: "https://databento.com/stocks".to_string(),
            official_evidence_url: Some(
                "https://contracts.databento.com/agreements/customer-external-display".to_string(),
            ),
            owner_attestation: None,
            raw_data_redistribution_support: None,
            valid_from: now - Duration::days(30),
            valid_until: now + Duration::days(30),
            issuer: "TEST VENDOR ISSUER".to_string(),
            reviewer: "TEST AUTHORIZED RIGHTS REVIEWER".to_string(),
            issued_at: now - Duration::days(31),
            reviewed_at: now - Duration::hours(1),
            review_due_at: now + Duration::days(7),
        }
    }

    fn write_rights_receipt(
        root: &Path,
        receipt: &MarketDataRightsReceipt,
    ) -> (std::path::PathBuf, String) {
        let path = root.join(MARKET_DATA_RIGHTS_RECEIPT_RELATIVE_PATH);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        let bytes = serde_json::to_vec(receipt).unwrap();
        let sha256 = format!("{:x}", Sha256::digest(&bytes));
        fs::write(&path, bytes).unwrap();
        (path, sha256)
    }

    fn write_technical_entitlement_receipt(
        root: &Path,
        captured_at: DateTime<Utc>,
    ) -> (std::path::PathBuf, String) {
        let path = root.join(MARKET_DATA_TECHNICAL_ENTITLEMENT_RECEIPT_RELATIVE_PATH);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        let bytes = serde_json::to_vec(&json!({
            "schema_version": MARKET_DATA_TECHNICAL_ENTITLEMENT_SCHEMA_VERSION,
            "status": "TECHNICAL_ENTITLEMENT_VERIFIED",
            "provider": "databento",
            "product": "Databento US Equities Mini",
            "dataset": "EQUS.MINI",
            "captured_at": captured_at.to_rfc3339(),
            "endpoints": [
                {
                    "host": "hist.databento.com",
                    "path": "/v0/metadata.list_datasets",
                    "status": 200,
                    "response_sha256": "e".repeat(64)
                },
                {
                    "host": "hist.databento.com",
                    "path": "/v0/metadata.list_schemas",
                    "status": 200,
                    "response_sha256": "f".repeat(64)
                },
                {
                    "host": "hist.databento.com",
                    "path": "/v0/metadata.get_dataset_range",
                    "status": 200,
                    "response_sha256": "9".repeat(64)
                }
            ],
            "entitled": true,
            "range": {
                "dataset_start": "2018-05-01T00:00:00Z",
                "dataset_end": "2026-07-28T15:59:00Z",
                "schema": "ohlcv-1m",
                "schema_start": "2018-05-01T00:00:00Z",
                "schema_end": "2026-07-28T15:59:00Z"
            }
        }))
        .unwrap();
        let sha256 = format!("{:x}", Sha256::digest(&bytes));
        fs::write(&path, bytes).unwrap();
        (path, sha256)
    }

    fn owner_attestation_signed_at(now: DateTime<Utc>) -> DateTime<Utc> {
        now - Duration::hours(2)
    }

    fn owner_attested_rights_receipt(
        now: DateTime<Utc>,
        technical_entitlement_receipt_sha256: String,
    ) -> MarketDataRightsReceipt {
        let signed_at = owner_attestation_signed_at(now);
        MarketDataRightsReceipt {
            schema_version: MARKET_DATA_RIGHTS_RECEIPT_SCHEMA_VERSION.to_string(),
            provider: "databento".to_string(),
            product: "EQUS.MINI".to_string(),
            legal_entity: "TEST ACCOUNT HOLDER".to_string(),
            plan_name: "TEST ACTIVE PLAN".to_string(),
            plan_status: "ACTIVE".to_string(),
            permitted_uses: MarketDataPermittedUses {
                model_input: true,
                customer_external_display: true,
                derived_output_publication: true,
                raw_data_redistribution: false,
            },
            evidence_kind: "ACCOUNT_OWNER_ATTESTATION".to_string(),
            evidence_artifact_sha256: "a".repeat(64),
            account_license_reference_sha256: "b".repeat(64),
            official_terms_url: "https://databento.com/legal/terms-of-use".to_string(),
            official_product_url: "https://databento.com/stocks".to_string(),
            official_evidence_url: None,
            owner_attestation: Some(MarketDataOwnerAttestation {
                issuer_role: "ACCOUNT_OWNER".to_string(),
                signed_at,
                account_identity_sha256: "c".repeat(64),
                subscription_reference_kind: "OWNER_DEFINED_NOT_VENDOR_ID".to_string(),
                subscription_identity_sha256: "d".repeat(64),
                technical_entitlement_receipt_sha256,
            }),
            raw_data_redistribution_support: None,
            valid_from: now - Duration::days(30),
            valid_until: now + Duration::days(30),
            issuer: "TEST ACCOUNT OWNER".to_string(),
            reviewer: "TEST AUTHORIZED RIGHTS REVIEWER".to_string(),
            issued_at: signed_at,
            reviewed_at: now - Duration::hours(1),
            review_due_at: now + Duration::days(7),
        }
    }

    fn inspect_test_rights(
        root: &Path,
        now: DateTime<Utc>,
        pin: Option<&str>,
    ) -> MarketDataRightsReadinessReceipt {
        inspect_market_data_rights(
            root,
            "databento",
            Some("EQUS.MINI"),
            now,
            pin,
            LegacyMarketDataRightsStatus::ValidButNonAuthoritative,
        )
    }

    #[test]
    fn market_data_rights_receipt_missing_and_unpinned_fail_closed() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let missing = inspect_test_rights(directory.path(), now, None);
        assert_eq!(missing.status, MarketDataRightsStatus::Unavailable);
        assert_eq!(missing.reason, MarketDataRightsReason::ReceiptMissing);
        assert_eq!(
            missing.legacy_environment_status,
            LegacyMarketDataRightsStatus::ValidButNonAuthoritative
        );

        write_rights_receipt(directory.path(), &valid_rights_receipt(now));
        let unpinned = inspect_test_rights(directory.path(), now, None);
        assert_eq!(unpinned.status, MarketDataRightsStatus::Blocked);
        assert_eq!(unpinned.reason, MarketDataRightsReason::PinMissing);
    }

    #[test]
    fn market_data_rights_receipt_rejects_expired_and_future_validity() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let mut expired = valid_rights_receipt(now);
        expired.valid_from = now - Duration::days(60);
        expired.valid_until = now - Duration::seconds(1);
        let (_, pin) = write_rights_receipt(directory.path(), &expired);
        let result = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(result.reason, MarketDataRightsReason::ValidityExpired);

        let mut future = valid_rights_receipt(now);
        future.valid_from = now + Duration::seconds(1);
        future.valid_until = now + Duration::days(60);
        let (_, pin) = write_rights_receipt(directory.path(), &future);
        let result = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(result.reason, MarketDataRightsReason::ValidityNotStarted);
    }

    #[test]
    fn market_data_rights_receipt_requires_exact_provider_and_product() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let mut receipt = valid_rights_receipt(now);
        receipt.provider = "massive".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        let wrong_provider = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(
            wrong_provider.reason,
            MarketDataRightsReason::ProviderMismatch
        );

        receipt = valid_rights_receipt(now);
        receipt.product = "OPRA.PILLAR".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        let wrong_product = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(
            wrong_product.reason,
            MarketDataRightsReason::ProductMismatch
        );
    }

    #[test]
    fn market_data_rights_receipt_rejects_unsafe_evidence_urls() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        for unsafe_reference in [
            "http://contracts.databento.com/agreement",
            "https://user:secret@contracts.databento.com/agreement",
            "https://contracts.databento.com/agreement?token=secret",
            "https://contracts.databento.com/agreement#account-secret",
            "https://example.com/agreement",
            "https://localhost/agreement",
            "https://127.0.0.1/agreement",
        ] {
            let mut receipt = valid_rights_receipt(now);
            receipt.official_evidence_url = Some(unsafe_reference.to_string());
            let (_, pin) = write_rights_receipt(directory.path(), &receipt);
            let result = inspect_test_rights(directory.path(), now, Some(&pin));
            assert_eq!(
                result.reason,
                MarketDataRightsReason::EvidenceReferenceInvalid,
                "unsafe reference passed: {unsafe_reference}"
            );
        }

        let mut unsafe_terms = valid_rights_receipt(now);
        unsafe_terms.official_terms_url = "https://example.com/legal/terms".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &unsafe_terms);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::OfficialTermsReferenceInvalid
        );
    }

    #[test]
    fn market_data_rights_receipt_requires_public_use_classes_and_separate_raw_rights() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let mut receipt = valid_rights_receipt(now);
        receipt.permitted_uses.model_input = false;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::ModelInputNotPermitted
        );

        receipt = valid_rights_receipt(now);
        receipt.permitted_uses.customer_external_display = false;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::CustomerExternalDisplayNotPermitted
        );

        receipt = valid_rights_receipt(now);
        receipt.permitted_uses.derived_output_publication = false;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::DerivedOutputPublicationNotPermitted
        );

        receipt = valid_rights_receipt(now);
        receipt.permitted_uses.raw_data_redistribution = true;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::RawDataRedistributionUnsupported
        );

        receipt.raw_data_redistribution_support = Some(MarketDataRawRedistributionSupport {
            evidence_kind: "VENDOR_WRITTEN_CONFIRMATION".to_string(),
            evidence_artifact_sha256: "c".repeat(64),
            official_evidence_url:
                "https://support.databento.com/tickets/raw-redistribution-rights".to_string(),
        });
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).status,
            MarketDataRightsStatus::Ready
        );
    }

    #[test]
    fn market_data_rights_receipt_requires_account_specific_active_evidence() {
        let directory = tempdir().unwrap();
        let now = rights_now();

        let mut receipt = valid_rights_receipt(now);
        receipt.legal_entity.clear();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::LegalEntityInvalid
        );

        receipt = valid_rights_receipt(now);
        receipt.plan_status = "CANCELLED".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::PlanNotActive
        );

        receipt = valid_rights_receipt(now);
        receipt.evidence_kind = "GENERIC_PRODUCT_PAGE".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::EvidenceKindUnsupported
        );

        receipt = valid_rights_receipt(now);
        receipt.evidence_artifact_sha256 = "0".repeat(64);
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::EvidenceArtifactHashInvalid
        );

        receipt = valid_rights_receipt(now);
        receipt.account_license_reference_sha256 = receipt.evidence_artifact_sha256.clone();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::AccountLicenseReferenceHashInvalid
        );

        receipt = valid_rights_receipt(now);
        receipt.issuer.clear();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::IssuerInvalid
        );

        receipt = valid_rights_receipt(now);
        receipt.reviewer.clear();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::ReviewerInvalid
        );
    }

    #[test]
    fn market_data_rights_receipt_rejects_v1_and_generic_product_page_evidence() {
        let directory = tempdir().unwrap();
        let now = rights_now();

        let mut receipt = valid_rights_receipt(now);
        receipt.schema_version = "axio.market_data_rights.v1".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::SchemaUnsupported
        );

        receipt = valid_rights_receipt(now);
        receipt.official_evidence_url =
            Some("https://databento.com/datasets/EQUS.MINI".to_string());
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::EvidenceReferenceInvalid
        );
    }

    #[test]
    fn market_data_rights_receipt_requires_current_review_clock() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let mut receipt = valid_rights_receipt(now);
        receipt.review_due_at = now - Duration::seconds(1);
        receipt.reviewed_at = now - Duration::days(1);
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::ReviewExpired
        );
    }

    #[test]
    fn market_data_rights_receipt_rejects_hash_tamper_and_secret_fields() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let receipt = valid_rights_receipt(now);
        let (path, pin) = write_rights_receipt(directory.path(), &receipt);
        let mut tampered = fs::read(&path).unwrap();
        tampered.push(b' ');
        fs::write(&path, tampered).unwrap();
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::HashMismatch
        );

        let mut value = serde_json::to_value(receipt).unwrap();
        value["account_secret"] = json!("must-not-be-accepted");
        let bytes = serde_json::to_vec(&value).unwrap();
        let pin = format!("{:x}", Sha256::digest(&bytes));
        fs::write(&path, bytes).unwrap();
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::ReceiptInvalid
        );
    }

    #[test]
    fn valid_pinned_market_data_rights_receipt_is_ready() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let (_, pin) = write_rights_receipt(directory.path(), &valid_rights_receipt(now));
        let result = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(result.status, MarketDataRightsStatus::Ready);
        assert_eq!(result.reason, MarketDataRightsReason::Verified);
        assert_eq!(
            result.legacy_environment_status,
            LegacyMarketDataRightsStatus::ValidButNonAuthoritative
        );
        let public = serde_json::to_string(&result).unwrap();
        for private_field in [
            "legal_entity",
            "plan_name",
            "evidence_artifact_sha256",
            "account_license_reference_sha256",
            "official_evidence_url",
            "issuer",
            "reviewer",
        ] {
            assert!(
                !public.contains(private_field),
                "private receipt field leaked into readiness: {private_field}"
            );
        }
    }

    #[test]
    fn owner_attestation_with_fresh_hash_bound_technical_entitlement_is_ready() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let captured_at = owner_attestation_signed_at(now) - Duration::seconds(30);
        let (_, technical_sha256) =
            write_technical_entitlement_receipt(directory.path(), captured_at);
        let receipt = owner_attested_rights_receipt(now, technical_sha256);
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);

        let result = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(result.status, MarketDataRightsStatus::Ready);
        assert_eq!(
            result.reason,
            MarketDataRightsReason::OwnerAttestedWithTechnicalEntitlement
        );
        assert!(pinned_market_data_rights_receipt_is_verified(
            directory.path(),
            "databento",
            "EQUS.MINI",
            now,
            Some(&pin)
        ));

        let public = serde_json::to_string(&result).unwrap();
        assert!(public.contains("OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT"));
        for private_value in [
            "TEST ACCOUNT HOLDER",
            "TEST ACTIVE PLAN",
            "TEST ACCOUNT OWNER",
            &"a".repeat(64),
            &"b".repeat(64),
            &"c".repeat(64),
            &"d".repeat(64),
        ] {
            assert!(
                !public.contains(private_value),
                "owner-attestation evidence leaked into public readiness"
            );
        }
    }

    #[test]
    fn owner_technical_entitlement_is_fresh_at_signing_not_a_rolling_runtime_clock() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let signed_at = now - Duration::days(5);
        let captured_at = signed_at - Duration::seconds(30);
        assert!(
            now.signed_duration_since(captured_at).num_seconds()
                > MAX_OWNER_TECHNICAL_ENTITLEMENT_AGE_SECONDS
        );
        let (_, technical_sha256) =
            write_technical_entitlement_receipt(directory.path(), captured_at);
        let mut receipt = owner_attested_rights_receipt(now, technical_sha256);
        receipt.owner_attestation.as_mut().unwrap().signed_at = signed_at;
        receipt.issued_at = signed_at;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);

        let result = inspect_test_rights(directory.path(), now, Some(&pin));
        assert_eq!(result.status, MarketDataRightsStatus::Ready);
        assert_eq!(
            result.reason,
            MarketDataRightsReason::OwnerAttestedWithTechnicalEntitlement
        );

        assert_eq!(
            provider_entitlement(directory.path(), "databento", true),
            EvidenceStatus::Unavailable
        );
        assert_eq!(
            stream_freshness(directory.path(), "databento", true, now, 120),
            FreshnessStatus::Unavailable
        );
    }

    #[test]
    fn owner_attestation_fails_closed_without_matching_technical_receipt() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let captured_at = owner_attestation_signed_at(now) - Duration::seconds(30);
        let receipt = owner_attested_rights_receipt(now, "8".repeat(64));
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::TechnicalEntitlementReceiptMissing
        );

        let (technical_path, technical_sha256) =
            write_technical_entitlement_receipt(directory.path(), captured_at);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::TechnicalEntitlementReceiptHashMismatch
        );

        let matching_receipt = owner_attested_rights_receipt(now, technical_sha256);
        let (_, matching_pin) = write_rights_receipt(directory.path(), &matching_receipt);
        let mut tampered_bytes = fs::read(&technical_path).unwrap();
        tampered_bytes.push(b'\n');
        fs::write(technical_path, tampered_bytes).unwrap();
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&matching_pin)).reason,
            MarketDataRightsReason::TechnicalEntitlementReceiptHashMismatch
        );
    }

    #[test]
    fn owner_attestation_rejects_stale_future_and_wrong_identity_technical_receipts() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let signed_at = owner_attestation_signed_at(now);

        let (_, stale_sha256) = write_technical_entitlement_receipt(
            directory.path(),
            signed_at - Duration::seconds(MAX_OWNER_TECHNICAL_ENTITLEMENT_AGE_SECONDS + 1),
        );
        let (_, stale_pin) = write_rights_receipt(
            directory.path(),
            &owner_attested_rights_receipt(now, stale_sha256),
        );
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&stale_pin)).reason,
            MarketDataRightsReason::TechnicalEntitlementReceiptStale
        );

        let (_, future_sha256) = write_technical_entitlement_receipt(
            directory.path(),
            signed_at + Duration::seconds(MAX_OWNER_TECHNICAL_ENTITLEMENT_FUTURE_SKEW_SECONDS + 1),
        );
        let (_, future_pin) = write_rights_receipt(
            directory.path(),
            &owner_attested_rights_receipt(now, future_sha256),
        );
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&future_pin)).reason,
            MarketDataRightsReason::TechnicalEntitlementReceiptStale
        );

        let (technical_path, _) = write_technical_entitlement_receipt(
            directory.path(),
            signed_at - Duration::seconds(30),
        );
        let mut technical: Value =
            serde_json::from_slice(&fs::read(&technical_path).unwrap()).unwrap();
        technical["dataset"] = json!("OPRA.PILLAR");
        let bytes = serde_json::to_vec(&technical).unwrap();
        let identity_mismatch_sha256 = format!("{:x}", Sha256::digest(&bytes));
        fs::write(technical_path, bytes).unwrap();
        let (_, identity_pin) = write_rights_receipt(
            directory.path(),
            &owner_attested_rights_receipt(now, identity_mismatch_sha256),
        );
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&identity_pin)).reason,
            MarketDataRightsReason::TechnicalEntitlementReceiptInvalid
        );
    }

    #[test]
    fn owner_attestation_requires_owner_identity_exact_scopes_and_no_vendor_claim() {
        let directory = tempdir().unwrap();
        let now = rights_now();
        let captured_at = owner_attestation_signed_at(now) - Duration::seconds(30);
        let (_, technical_sha256) =
            write_technical_entitlement_receipt(directory.path(), captured_at);

        let mut receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt.issuer = "Databento licensing desk".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::OwnerAttestationInvalid
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt.official_evidence_url =
            Some("https://databento.com/support/tickets/test".to_string());
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::OwnerAttestationInvalid
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt.plan_status = "CANCELLED".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::PlanNotActive
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt.review_due_at = now - Duration::seconds(1);
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::ReviewExpired
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt
            .owner_attestation
            .as_mut()
            .unwrap()
            .subscription_identity_sha256 = "c".repeat(64);
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::OwnerAttestationInvalid
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt
            .owner_attestation
            .as_mut()
            .unwrap()
            .subscription_reference_kind = "UNLABELED_REFERENCE".to_string();
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::OwnerAttestationInvalid
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256.clone());
        receipt.permitted_uses.customer_external_display = false;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::CustomerExternalDisplayNotPermitted
        );

        receipt = owner_attested_rights_receipt(now, technical_sha256);
        receipt.permitted_uses.raw_data_redistribution = true;
        let (_, pin) = write_rights_receipt(directory.path(), &receipt);
        assert_eq!(
            inspect_test_rights(directory.path(), now, Some(&pin)).reason,
            MarketDataRightsReason::RawDataRedistributionUnsupported
        );
    }

    #[test]
    fn massive_equity_entitlement_is_not_blocked_by_opra_in_v2() {
        let directory = tempdir().unwrap();
        fs::create_dir_all(directory.path().join("live")).unwrap();
        let receipt_path = directory.path().join("live/massive_readiness.json");
        fs::write(
            &receipt_path,
            serde_json::to_vec(&json!({
                "schema_version":"massive_realtime_readiness.v2",
                "equity_realtime_ready":true,
                "options_realtime_ready":false,
                "production_ready":false
            }))
            .unwrap(),
        )
        .unwrap();
        assert_eq!(
            provider_entitlement(directory.path(), "massive", true),
            EvidenceStatus::Ready
        );

        fs::write(
            &receipt_path,
            serde_json::to_vec(&json!({
                "schema_version":"massive_realtime_readiness.v2",
                "equity_realtime_ready":false,
                "options_realtime_ready":true,
                "production_ready":false
            }))
            .unwrap(),
        )
        .unwrap();
        assert_eq!(
            provider_entitlement(directory.path(), "massive", true),
            EvidenceStatus::Blocked
        );

        fs::write(
            &receipt_path,
            serde_json::to_vec(&json!({
                "schema_version":"massive_realtime_readiness.v1",
                "production_ready":true
            }))
            .unwrap(),
        )
        .unwrap();
        assert_eq!(
            provider_entitlement(directory.path(), "massive", true),
            EvidenceStatus::Ready
        );
    }

    #[test]
    fn coverage_requires_every_configured_horizon_for_the_same_symbol() {
        let complete = json!({
            "prediction_layer":[
                {"symbol":"SPY","horizon_minutes":5},
                {"symbol":"SPY","horizon_minutes":15},
                {"symbol":"SPY","horizon_minutes":30},
                {"symbol":"SPY","horizon_minutes":60}
            ]
        });
        assert_eq!(
            horizon_coverage(&complete, "SPY", &[5, 15, 30, 60]),
            ForecastCoverageStatus::Complete
        );
        let partial = json!({
            "prediction_layer":[
                {"symbol":"SPY","horizon_minutes":5},
                {"symbol":"QQQ","horizon_minutes":15}
            ]
        });
        assert_eq!(
            horizon_coverage(&partial, "SPY", &[5, 15, 30, 60]),
            ForecastCoverageStatus::Partial
        );
        assert_eq!(
            horizon_coverage(&json!({"prediction_layer":[]}), "SPY", &[5, 15]),
            ForecastCoverageStatus::None
        );
    }

    #[test]
    fn calibration_is_promoted_only_when_every_row_matches_the_pinned_registry() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 26, 12, 0, 0)
            .single()
            .unwrap();
        let registry = promoted_calibration_registry(now);
        let rows = [5, 15, 30, 60]
            .into_iter()
            .map(|horizon| promoted_calibration_row(now, horizon, &format!("cal-{horizon}m")))
            .collect::<Vec<_>>();
        assert_eq!(
            forecast_calibration(
                &json!({"prediction_layer":rows}),
                "SPY",
                &[5, 15, 30, 60],
                Some(&registry)
            ),
            ForecastCalibrationStatus::Promoted
        );
        let mut partial_rows = [5, 15, 30, 60]
            .into_iter()
            .map(|horizon| promoted_calibration_row(now, horizon, &format!("cal-{horizon}m")))
            .collect::<Vec<_>>();
        partial_rows[3]["probability_calibration"]["eligible_for_probability_use"] = json!(false);
        assert_eq!(
            forecast_calibration(
                &json!({"prediction_layer":partial_rows}),
                "SPY",
                &[5, 15, 30, 60],
                Some(&registry)
            ),
            ForecastCalibrationStatus::Partial
        );
        assert_eq!(
            forecast_calibration(
                &json!({"prediction_layer":[]}),
                "SPY",
                &[5, 15, 30, 60],
                Some(&registry)
            ),
            ForecastCalibrationStatus::Unavailable
        );
        assert_eq!(
            forecast_calibration(
                &json!({"prediction_layer":[promoted_calibration_row(now, 5, "cal-5m")]}),
                "SPY",
                &[5],
                None
            ),
            ForecastCalibrationStatus::Unavailable
        );
    }

    #[test]
    fn wrong_calibration_artifact_id_cannot_pass_readiness() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 26, 12, 0, 0)
            .single()
            .unwrap();
        let registry = promoted_calibration_registry(now);
        let mut rows = [5, 15, 30, 60]
            .into_iter()
            .map(|horizon| promoted_calibration_row(now, horizon, &format!("cal-{horizon}m")))
            .collect::<Vec<_>>();
        rows[1]["probability_calibration"]["artifact_id"] = json!("cal-5m");
        assert_eq!(
            forecast_calibration(
                &json!({"prediction_layer":rows}),
                "SPY",
                &[5, 15, 30, 60],
                Some(&registry)
            ),
            ForecastCalibrationStatus::Partial
        );
    }

    #[test]
    fn live_inference_readiness_requires_a_fresh_fully_committed_published_status() {
        let directory = tempdir().unwrap();
        fs::create_dir_all(directory.path().join("live")).unwrap();
        let status_path = status_path(directory.path(), "SPY");
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 14, 30, 30)
            .single()
            .unwrap();
        let evaluation = ForecastEvaluation {
            configured_horizons: &REQUIRED_PRODUCTION_HORIZONS,
            calibration_registry: None,
            provider: "databento",
            databento_batch_cutoff: Some(now - Duration::minutes(1)),
            databento_batch_committed_at: Some(now - Duration::seconds(2)),
            now,
            maximum_age_seconds: 120,
        };
        let write_status = |status: &TargetInferenceStatus| {
            fs::write(&status_path, serde_json::to_vec(status).unwrap()).unwrap();
        };

        let missing = live_inference_readiness(directory.path(), "SPY", &evaluation);
        assert!(missing.required);
        assert!(!missing.status_available);
        assert!(!missing.ready);
        assert_eq!(
            missing.reason_code.as_deref(),
            Some("TARGET_INFERENCE_STATUS_UNAVAILABLE")
        );

        let published = TargetInferenceStatus {
            schema_version: DATABENTO_INFERENCE_STATUS_SCHEMA_VERSION.into(),
            observed_at: now - Duration::seconds(1),
            model_symbol: "SPY".into(),
            status: TargetInferenceState::Published,
            stage: TargetInferenceStage::Published,
            reason_code: None,
            cutoff: Some(now - Duration::minutes(1)),
            latest_input_available_at: Some(now - Duration::seconds(2)),
            compute_ms: Some(4),
            end_to_end_ms: Some(5),
            budget_ms: 5_000,
            context_blockers: Vec::new(),
            forecast_committed: true,
            receipt_committed: true,
            ledger_persisted: true,
            execution_enabled: false,
        };

        for (status, stage) in [
            (
                TargetInferenceState::WaitingForTarget,
                TargetInferenceStage::ProviderInput,
            ),
            (
                TargetInferenceState::WaitingForContext,
                TargetInferenceStage::FeatureEngine,
            ),
            (
                TargetInferenceState::CompatibilityRejected,
                TargetInferenceStage::FrozenUniverseGate,
            ),
            (
                TargetInferenceState::Running,
                TargetInferenceStage::FrozenInference,
            ),
            (
                TargetInferenceState::SlaRejected,
                TargetInferenceStage::SlaGate,
            ),
            (
                TargetInferenceState::PublishRejected,
                TargetInferenceStage::PublishCommit,
            ),
        ] {
            let mut row = published.clone();
            row.status = status;
            row.stage = stage;
            write_status(&row);
            let readiness = live_inference_readiness(directory.path(), "SPY", &evaluation);
            assert!(
                !readiness.ready,
                "non-published lifecycle state {status:?} passed readiness"
            );
        }

        for missing_commit in ["forecast", "receipt", "ledger"] {
            let mut row = published.clone();
            match missing_commit {
                "forecast" => row.forecast_committed = false,
                "receipt" => row.receipt_committed = false,
                "ledger" => row.ledger_persisted = false,
                _ => unreachable!(),
            }
            write_status(&row);
            assert!(
                !live_inference_readiness(directory.path(), "SPY", &evaluation).ready,
                "published status passed without {missing_commit} commit"
            );
        }

        let mut stale = published.clone();
        stale.observed_at = now - Duration::seconds(121);
        write_status(&stale);
        let stale_readiness = live_inference_readiness(directory.path(), "SPY", &evaluation);
        assert_eq!(stale_readiness.status_freshness, FreshnessStatus::Stale);
        assert!(!stale_readiness.ready);

        let mut future = published.clone();
        future.observed_at = now + Duration::seconds(1);
        write_status(&future);
        let future_readiness = live_inference_readiness(directory.path(), "SPY", &evaluation);
        assert_eq!(future_readiness.status_freshness, FreshnessStatus::Future);
        assert!(!future_readiness.ready);

        let mut execution_enabled = published.clone();
        execution_enabled.execution_enabled = true;
        write_status(&execution_enabled);
        let unsafe_readiness = live_inference_readiness(directory.path(), "SPY", &evaluation);
        assert!(!unsafe_readiness.status_available);
        assert!(!unsafe_readiness.ready);

        let mut wrong_batch_cutoff = published.clone();
        wrong_batch_cutoff.cutoff = Some(now - Duration::minutes(2));
        write_status(&wrong_batch_cutoff);
        assert!(
            !live_inference_readiness(directory.path(), "SPY", &evaluation).ready,
            "a status from a different batch cutoff passed readiness"
        );

        let not_yet_committed_evaluation = ForecastEvaluation {
            configured_horizons: &REQUIRED_PRODUCTION_HORIZONS,
            calibration_registry: None,
            provider: "databento",
            databento_batch_cutoff: published.cutoff,
            databento_batch_committed_at: Some(now),
            now,
            maximum_age_seconds: 120,
        };
        write_status(&published);
        assert!(
            !live_inference_readiness(directory.path(), "SPY", &not_yet_committed_evaluation).ready,
            "a status predating the atomic batch commit passed readiness"
        );

        write_status(&published);
        let ready = live_inference_readiness(directory.path(), "SPY", &evaluation);
        assert!(ready.status_available);
        assert_eq!(ready.status, Some(TargetInferenceState::Published));
        assert_eq!(ready.status_freshness, FreshnessStatus::Fresh);
        assert!(ready.ready);
    }

    #[test]
    fn databento_readiness_never_falls_back_to_an_independent_latest_file() {
        let directory = tempdir().unwrap();
        fs::create_dir_all(directory.path().join("reports")).unwrap();
        fs::write(
            directory
                .path()
                .join("reports")
                .join(live_forecast_filename("SPY")),
            serde_json::to_vec(&json!({
                "generated_at":"2026-07-28T14:30:00Z",
                "prediction_layer":[]
            }))
            .unwrap(),
        )
        .unwrap();
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 14, 30, 30)
            .single()
            .unwrap();
        let evaluation = ForecastEvaluation {
            configured_horizons: &REQUIRED_PRODUCTION_HORIZONS,
            calibration_registry: None,
            provider: "databento",
            databento_batch_cutoff: None,
            databento_batch_committed_at: None,
            now,
            maximum_age_seconds: 120,
        };

        let readiness = symbol_forecast_readiness(
            directory.path(),
            "SPY".into(),
            &evaluation,
            None,
            &|_, _, _, _| true,
            &|_| true,
            &|_| true,
        );

        assert!(!readiness.artifact_present);
        assert_eq!(
            readiness.validation_status,
            ForecastValidationStatus::NotEvaluated
        );
        assert!(!readiness.ready);
    }

    #[test]
    fn serialized_receipt_contains_no_secret_bearing_fields() {
        let receipt = ProductionReadinessReceipt {
            schema_version: PRODUCTION_READINESS_SCHEMA_VERSION,
            status: OverallReadiness::Blocked,
            public_realtime_research_ready: false,
            llm: LlmReadinessReceipt {
                auth_status: LlmAuthStatus::ExternalUnknown,
            },
            market_data: MarketDataReadinessReceipt {
                selected_provider: "massive".into(),
                selected_product: Some("US_EQUITIES_REALTIME".into()),
                live_enabled: true,
                public_use_rights: MarketDataRightsReadinessReceipt {
                    status: MarketDataRightsStatus::Blocked,
                    reason: MarketDataRightsReason::ReceiptMissing,
                    legacy_environment_status:
                        LegacyMarketDataRightsStatus::InvalidButNonAuthoritative,
                },
                provider_entitlement: EvidenceStatus::Blocked,
                stream_freshness: FreshnessStatus::Blocked,
                feed_freshness: FreshnessStatus::Unavailable,
            },
            artifacts: ArtifactReadinessReceipt {
                promotion_registry_present: false,
                promotion_registry_status: PromotionRegistryStatus::Absent,
                calibration_registry_present: false,
                calibration_registry_status: CalibrationRegistryStatus::NotConfigured,
                prediction_ledger_present: false,
            },
            forecasts: Vec::new(),
        };
        let text = serde_json::to_string(&receipt)
            .unwrap()
            .to_ascii_lowercase();
        for prohibited in [
            "api_key",
            "account_secret",
            "credential",
            "token",
            "license_reference",
            "evidence_reference",
            "issuer",
            "endpoint",
            "provider_message",
            "filesystem_path",
            "sha256",
        ] {
            assert!(!text.contains(prohibited), "leaked field: {prohibited}");
        }
        assert!(text.contains("\"auth_status\":\"external_unknown\""));
    }
}
