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
    path::{Path, PathBuf},
};

use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::{
    AppConfig,
    probability_calibration::{
        CALIBRATION_ARTIFACT_ENV, CalibrationLifecycle, ProbabilityCalibrationRegistry,
    },
};

pub const PRODUCTION_READINESS_SCHEMA_VERSION: &str = "axio.production_readiness.v1";

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
    Absent,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum CalibrationRegistryStatus {
    Promoted,
    ValidUnpromoted,
    Invalid,
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

#[derive(Debug, Serialize)]
pub struct LlmReadinessReceipt {
    pub auth_status: LlmAuthStatus,
}

#[derive(Debug, Serialize)]
pub struct MarketDataReadinessReceipt {
    pub selected_provider: String,
    pub live_enabled: bool,
    pub public_display_license_configured: bool,
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
pub struct SymbolForecastReadiness {
    pub symbol: String,
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

#[derive(Debug, Clone, Copy)]
struct CalibrationRegistryEvidence {
    present: bool,
    status: CalibrationRegistryStatus,
}

fn root_for(config: &AppConfig) -> &Path {
    config.data.raw_root.parent().unwrap_or(Path::new("data"))
}

fn normalized_symbol(symbol: &str) -> String {
    symbol.trim().trim_start_matches("US.").to_ascii_uppercase()
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

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn license_values_match(selected_provider: &str, licensed_provider: &str, reference: &str) -> bool {
    !licensed_provider.trim().is_empty()
        && licensed_provider
            .trim()
            .eq_ignore_ascii_case(selected_provider.trim())
        && reference.trim().starts_with("https://")
}

fn public_display_license_configured(selected_provider: &str) -> bool {
    let provider = env::var("AXIO7_PUBLIC_MARKET_DATA_PROVIDER")
        .ok()
        .map(|value| value.trim().to_string())
        .unwrap_or_default();
    let reference = env::var("AXIO7_PUBLIC_MARKET_DATA_LICENSE_REFERENCE")
        .ok()
        .map(|value| value.trim().to_string())
        .unwrap_or_default();
    license_values_match(selected_provider, &provider, &reference)
}

fn promotion_registry_evidence(root: &Path) -> PromotionRegistryEvidence {
    let path = root.join("models/predictor_promotion_latest.json");
    let Ok(bytes) = fs::read(path) else {
        return PromotionRegistryEvidence {
            present: false,
            status: PromotionRegistryStatus::Absent,
        };
    };
    let Some(expected_hash) = env::var("MODEL_PROMOTION_REGISTRY_SHA256")
        .ok()
        .filter(|value| valid_nonzero_sha256(value.trim()))
    else {
        return PromotionRegistryEvidence {
            present: true,
            status: PromotionRegistryStatus::Unpinned,
        };
    };
    let observed_hash = format!("{:x}", Sha256::digest(&bytes));
    if !observed_hash.eq_ignore_ascii_case(expected_hash.trim()) {
        return PromotionRegistryEvidence {
            present: true,
            status: PromotionRegistryStatus::HashMismatch,
        };
    }
    let Ok(value) = serde_json::from_slice::<Value>(&bytes) else {
        return PromotionRegistryEvidence {
            present: true,
            status: PromotionRegistryStatus::Invalid,
        };
    };
    let active = value.get("artifact_kind").and_then(Value::as_str)
        == Some("model_promotion_registry")
        && value.get("status").and_then(Value::as_str) == Some("ACTIVE")
        && value.get("promotion").and_then(Value::as_str)
            == Some("PROMOTED_UNTOUCHED_FORWARD_SHADOW")
        && value
            .get("approval_id")
            .and_then(Value::as_str)
            .is_some_and(|item| !item.trim().is_empty())
        && value
            .get("reviewer")
            .and_then(Value::as_str)
            .is_some_and(|item| !item.trim().is_empty());
    PromotionRegistryEvidence {
        present: true,
        status: if active {
            PromotionRegistryStatus::ActivePinned
        } else {
            PromotionRegistryStatus::Invalid
        },
    }
}

fn calibration_registry_evidence() -> CalibrationRegistryEvidence {
    let Some(path) = env::var_os(CALIBRATION_ARTIFACT_ENV)
        .filter(|value| !value.to_string_lossy().trim().is_empty())
    else {
        return CalibrationRegistryEvidence {
            present: false,
            status: CalibrationRegistryStatus::NotConfigured,
        };
    };
    let path = PathBuf::from(path);
    if !path.is_file() {
        return CalibrationRegistryEvidence {
            present: false,
            status: CalibrationRegistryStatus::Absent,
        };
    }
    match ProbabilityCalibrationRegistry::load(&path) {
        Ok(registry) => {
            let promoted = registry
                .artifacts
                .iter()
                .any(|artifact| artifact.lifecycle == CalibrationLifecycle::PromotedOos);
            CalibrationRegistryEvidence {
                present: true,
                status: if promoted {
                    CalibrationRegistryStatus::Promoted
                } else {
                    CalibrationRegistryStatus::ValidUnpromoted
                },
            }
        }
        Err(_) => CalibrationRegistryEvidence {
            present: true,
            status: CalibrationRegistryStatus::Invalid,
        },
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
        return match read_json(&root.join("live/massive_readiness.json"))
            .and_then(|value| value.get("production_ready").and_then(Value::as_bool))
        {
            Some(true) => EvidenceStatus::Ready,
            Some(false) => EvidenceStatus::Blocked,
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
    now: DateTime<Utc>,
    maximum_age_seconds: i64,
) -> FreshnessStatus {
    if !enabled {
        return FreshnessStatus::Disabled;
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

fn forecast_calibration(payload: &Value) -> ForecastCalibrationStatus {
    let Some(rows) = payload.get("prediction_layer").and_then(Value::as_array) else {
        return ForecastCalibrationStatus::Unavailable;
    };
    if rows.is_empty() {
        return ForecastCalibrationStatus::Unavailable;
    }
    let promoted = rows
        .iter()
        .filter(|row| {
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
        })
        .count();
    if promoted == rows.len() {
        ForecastCalibrationStatus::Promoted
    } else if promoted > 0 {
        ForecastCalibrationStatus::Partial
    } else {
        ForecastCalibrationStatus::Unpromoted
    }
}

struct ForecastEvaluation<'a> {
    configured_horizons: &'a [usize],
    now: DateTime<Utc>,
    maximum_age_seconds: i64,
}

fn symbol_forecast_readiness<V, P, L>(
    root: &Path,
    symbol: String,
    evaluation: &ForecastEvaluation<'_>,
    validate_bundle: &V,
    promotion_matches: &P,
    ledger_backed: &L,
) -> SymbolForecastReadiness
where
    V: Fn(&Value, &str, DateTime<Utc>, i64) -> bool,
    P: Fn(&Value) -> bool,
    L: Fn(&Value) -> bool,
{
    let path = root.join("reports").join(live_forecast_filename(&symbol));
    let Some(payload) = read_json(&path) else {
        return SymbolForecastReadiness {
            symbol,
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
        &payload,
        &symbol,
        evaluation.now,
        evaluation.maximum_age_seconds,
    );
    let artifact_freshness = freshness_at(
        parse_timestamp(payload.get("generated_at")),
        evaluation.now,
        evaluation.maximum_age_seconds,
    );
    let rows = payload
        .get("prediction_layer")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let promotion_registry_matches =
        validated && !rows.is_empty() && rows.iter().all(promotion_matches);
    let ledger_backed =
        promotion_registry_matches && !rows.is_empty() && rows.iter().all(ledger_backed);
    let horizon_coverage = horizon_coverage(&payload, &symbol, evaluation.configured_horizons);
    let calibration = forecast_calibration(&payload);
    let ready = validated
        && horizon_coverage == ForecastCoverageStatus::Complete
        && calibration == ForecastCalibrationStatus::Promoted
        && promotion_registry_matches
        && ledger_backed;
    SymbolForecastReadiness {
        symbol,
        artifact_present: true,
        validation_status: if validated {
            ForecastValidationStatus::Passed
        } else {
            ForecastValidationStatus::Rejected
        },
        freshness: if validated {
            FreshnessStatus::Fresh
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
    let public_display_license_configured =
        public_display_license_configured(&config.live.provider);
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
        now,
        config.os.freshness_limit_seconds,
    );
    let symbols = config
        .live
        .forecast_symbols
        .iter()
        .map(|symbol| normalized_symbol(symbol))
        .filter(|symbol| !symbol.is_empty())
        .collect::<BTreeSet<_>>();
    let forecast_evaluation = ForecastEvaluation {
        configured_horizons: &config.research.horizons,
        now,
        maximum_age_seconds: config.os.freshness_limit_seconds,
    };
    let forecasts = symbols
        .into_iter()
        .map(|symbol| {
            symbol_forecast_readiness(
                root,
                symbol,
                &forecast_evaluation,
                &validate_bundle,
                &promotion_matches,
                &ledger_backed,
            )
        })
        .collect::<Vec<_>>();
    let all_forecasts_ready = !forecasts.is_empty() && forecasts.iter().all(|item| item.ready);
    let public_realtime_research_ready = config.live.enabled
        && public_display_license_configured
        && provider_entitlement == EvidenceStatus::Ready
        && stream_freshness == FreshnessStatus::Fresh
        && feed_freshness == FreshnessStatus::Fresh
        && promotion_registry.status == PromotionRegistryStatus::ActivePinned
        && calibration_registry.status == CalibrationRegistryStatus::Promoted
        && prediction_ledger_present
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
            live_enabled: config.live.enabled,
            public_display_license_configured,
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
    use chrono::TimeZone;
    use serde_json::json;

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
    fn public_display_license_must_match_the_selected_provider() {
        assert!(license_values_match(
            "massive",
            "MASSIVE",
            "https://vendor.example/contracts/approved"
        ));
        assert!(!license_values_match(
            "massive",
            "databento",
            "https://vendor.example/contracts/approved"
        ));
        assert!(!license_values_match(
            "massive",
            "massive",
            "internal-contract-123"
        ));
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
    fn calibration_is_promoted_only_when_every_row_is_explicitly_eligible() {
        let promoted_row = || {
            json!({
                "probability_calibration":{
                    "eligible_for_probability_use":true,
                    "status":"PROMOTED_OOS_CALIBRATION_APPLIED",
                    "calibrated_probability_up":0.55
                }
            })
        };
        assert_eq!(
            forecast_calibration(&json!({"prediction_layer":[promoted_row(),promoted_row()]})),
            ForecastCalibrationStatus::Promoted
        );
        assert_eq!(
            forecast_calibration(&json!({
                "prediction_layer":[
                    promoted_row(),
                    {"probability_calibration":{"eligible_for_probability_use":false}}
                ]
            })),
            ForecastCalibrationStatus::Partial
        );
        assert_eq!(
            forecast_calibration(&json!({
                "prediction_layer":[
                    {"probability_calibration":{"eligible_for_probability_use":false}}
                ]
            })),
            ForecastCalibrationStatus::Unpromoted
        );
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
                live_enabled: true,
                public_display_license_configured: false,
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
            "credential",
            "token",
            "license_reference",
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
