//! Deterministic, research-only natural-language query execution contracts.
//!
//! This module owns no language-model behavior. A caller may translate prose
//! into [`MarketQuery`], but only the allow-listed, versioned contract below is
//! executable. Market observations, statistics, gamma aggregation, freshness
//! checks, and hashes remain native Rust responsibilities.

use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs,
    path::Path,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{
    data::{
        databento_live::{DatabentoRealtimeBarEnvelope, realtime_envelope_rejection},
        massive_live::{
            MassiveFullOptionChain, OPTION_CHAIN_SCHEMA_VERSION, RealtimeMarketBarEnvelope,
        },
    },
    domain::{CallPut, MarketBar},
    engine::gamma_convexity::{
        GammaConvexityAvailability, GammaConvexityRequest, gamma_convexity_feedback_risk,
    },
    live::FinalizedLiveBar,
    production_readiness::{
        MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV, pinned_market_data_rights_receipt_is_verified,
    },
};

pub const MARKET_QUERY_SCHEMA_VERSION: &str = "axio.market-query.v2";
pub const LEGACY_MARKET_QUERY_SCHEMA_VERSION: &str = "axio.market-query.v1";
pub const EVIDENCE_ENVELOPE_SCHEMA_VERSION: &str = "axio.evidence-envelope.v1";
pub const OPENING_EXHAUSTION_METHOD_VERSION: &str = "opening-buy-exhaustion-5m.v1";
pub const VWAP_REVERSAL_METHOD_VERSION: &str = "causal-session-vwap-cross-5m.v1";
pub const GAMMA_STRUCTURE_METHOD_VERSION: &str = "unsigned-gamma-structure-score.v1";
pub const MOMENTUM_METHOD_VERSION: &str = "causal-multi-bar-momentum-5m.v1";
pub const STATISTICAL_DISLOCATION_METHOD_VERSION: &str = "causal-vwap-dislocation-5m.v2";

const REGULAR_SESSION_MINUTES: usize = 390;
const FIVE_MINUTE_INTERVAL_MINUTES: i64 = 5;
const MINIMUM_DISLOCATION_PRIOR_DISTANCES: usize = 12;
const HISTORICAL_VWAP_POLICY: &str =
    "SESSION_ATOMIC_AUTHORIZED_VENDOR_MINUTE_VWAP_OR_RECONSTRUCTED_CLOSE_VOLUME_PROXY";
const LATE_EVENT_EXCLUSION: &str = "EVENT_TOO_LATE_FOR_EXACT_CLOCK_HORIZON";
const MISSING_ENTRY_EXCLUSION: &str = "MISSING_EXACT_NEXT_BAR_ENTRY";
const MISSING_HORIZON_EXCLUSION: &str = "MISSING_CONTIGUOUS_EXACT_CLOCK_HORIZON";

fn default_query_version() -> String {
    MARKET_QUERY_SCHEMA_VERSION.to_string()
}

fn default_limit() -> usize {
    10
}

fn default_true() -> bool {
    true
}

fn default_max_data_age_seconds() -> i64 {
    120
}

fn default_max_dte() -> i32 {
    14
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MarketQueryIntent {
    Scan,
    Forecast,
    Backtest,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MarketSetupType {
    ModelForecast,
    Momentum,
    GammaSqueeze,
    VwapReversal,
    OpeningTurn,
    ClosingShortCover,
    StatisticalDislocation,
}

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TurnDirection {
    #[default]
    Down,
    Up,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct MarketQueryFilters {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub direction: Option<TurnDirection>,
    #[serde(default = "default_true")]
    pub require_realtime: bool,
    #[serde(default)]
    pub include_historical: bool,
    #[serde(default = "default_max_data_age_seconds")]
    pub max_data_age_seconds: i64,
    #[serde(default = "default_max_dte")]
    pub max_dte: i32,
    #[serde(default)]
    pub exclude_earnings_within_days: Option<u16>,
    #[serde(default)]
    pub maximum_option_spread_pct: Option<f64>,
    #[serde(default)]
    pub minimum_option_quote_coverage: Option<f64>,
}

impl Default for MarketQueryFilters {
    fn default() -> Self {
        Self {
            direction: None,
            require_realtime: true,
            include_historical: false,
            max_data_age_seconds: default_max_data_age_seconds(),
            max_dte: default_max_dte(),
            exclude_earnings_within_days: None,
            maximum_option_spread_pct: None,
            minimum_option_quote_coverage: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct MarketQuery {
    #[serde(default = "default_query_version")]
    pub version: String,
    pub intent: MarketQueryIntent,
    pub setup_type: MarketSetupType,
    pub symbols: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub horizon_minutes: Option<usize>,
    #[serde(default = "default_limit")]
    pub limit: usize,
    #[serde(default)]
    pub as_of: Option<DateTime<Utc>>,
    #[serde(default)]
    pub filters: MarketQueryFilters,
}

impl MarketQuery {
    pub fn normalize_and_validate(mut self) -> std::result::Result<Self, String> {
        if self.version != MARKET_QUERY_SCHEMA_VERSION
            && self.version != LEGACY_MARKET_QUERY_SCHEMA_VERSION
        {
            return Err(format!(
                "unsupported query version {}; expected {MARKET_QUERY_SCHEMA_VERSION} or legacy {LEGACY_MARKET_QUERY_SCHEMA_VERSION}",
                self.version
            ));
        }
        if self.version == LEGACY_MARKET_QUERY_SCHEMA_VERSION
            && self.setup_type == MarketSetupType::ModelForecast
        {
            return Err(
                "model_forecast requires axio.market-query.v2; v1 remains available only for stored explicit-rule monitors"
                    .to_string(),
            );
        }
        if self.symbols.is_empty() || self.symbols.len() > 30 {
            return Err("symbols must contain between 1 and 30 values".to_string());
        }
        let mut symbols = BTreeSet::new();
        for raw in &self.symbols {
            let symbol = raw
                .trim()
                .trim_start_matches("US.")
                .trim_start_matches('$')
                .to_ascii_uppercase();
            if symbol.is_empty()
                || symbol.len() > 10
                || !symbol
                    .chars()
                    .all(|character| character.is_ascii_alphanumeric() || character == '.')
            {
                return Err(format!("invalid US market symbol: {raw}"));
            }
            symbols.insert(symbol);
        }
        self.symbols = symbols.into_iter().collect();
        if self
            .horizon_minutes
            .is_some_and(|horizon| ![5, 15, 30, 60].contains(&horizon))
        {
            return Err(
                "horizon_minutes, when provided, must be one of 5, 15, 30, or 60".to_string(),
            );
        }
        if self.setup_type == MarketSetupType::ModelForecast {
            if self.intent == MarketQueryIntent::Backtest {
                return Err(
                    "model_forecast is a live frozen-model query; use an explicit setup for a historical rule replay"
                        .to_string(),
                );
            }
            if self.filters.direction.is_some() {
                return Err(
                    "direction must be omitted for model_forecast because direction is inferred by the frozen model"
                        .to_string(),
                );
            }
            if self.filters.include_historical {
                return Err(
                    "model_forecast cannot include an unrelated historical rule replay".to_string(),
                );
            }
        } else {
            if self.horizon_minutes.is_none() {
                return Err(
                    "horizon_minutes is required for an explicit setup or backtest".to_string(),
                );
            }
            if self.filters.direction.is_none() {
                return Err(
                    "direction is required for an explicit directional setup or backtest"
                        .to_string(),
                );
            }
        }
        if !(1..=20).contains(&self.limit) {
            return Err("limit must be between 1 and 20".to_string());
        }
        if !(1..=3_600).contains(&self.filters.max_data_age_seconds) {
            return Err("max_data_age_seconds must be between 1 and 3600".to_string());
        }
        if !(0..=60).contains(&self.filters.max_dte) {
            return Err("max_dte must be between 0 and 60".to_string());
        }
        if self
            .filters
            .maximum_option_spread_pct
            .is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value))
        {
            return Err("maximum_option_spread_pct must be finite and between 0 and 1".to_string());
        }
        if self
            .filters
            .minimum_option_quote_coverage
            .is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value))
        {
            return Err(
                "minimum_option_quote_coverage must be finite and between 0 and 1".to_string(),
            );
        }
        if self.intent != MarketQueryIntent::Backtest && self.as_of.is_some() {
            return Err(
                "as_of is accepted only for backtest queries; live freshness is evaluated against the server clock"
                    .to_string(),
            );
        }
        if self
            .as_of
            .is_some_and(|cutoff| cutoff > Utc::now() + chrono::Duration::seconds(5))
        {
            return Err("as_of cannot be in the future".to_string());
        }
        Ok(self)
    }

    pub fn canonical_sha256(&self) -> Result<String> {
        Ok(sha256_hex(&serde_json::to_vec(self)?))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvidenceItem {
    pub code: String,
    pub statement: String,
    pub observed_value: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DataFreshness {
    pub source: String,
    pub observed_at: Option<DateTime<Utc>>,
    pub available_at: Option<DateTime<Utc>>,
    pub age_seconds: Option<i64>,
    pub realtime: bool,
    pub entitlement: String,
    pub coverage: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResearchCandidate {
    pub symbol: String,
    pub setup_type: MarketSetupType,
    pub status: String,
    pub heuristic_structure_score: Option<f64>,
    pub score_semantics: String,
    pub supporting_evidence: Vec<EvidenceItem>,
    pub contrary_evidence: Vec<EvidenceItem>,
    pub metrics: Value,
    pub freshness: Vec<DataFreshness>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum HistoricalEdgeClassification {
    InsufficientEvidence,
    NoDemonstratedEdge,
    PositiveAfterCostDescriptive,
}

fn classify_historical_edge(
    completed_backtests: usize,
    mean_net_return: Option<f64>,
    median_net_return: Option<f64>,
    cumulative_net_return: Option<f64>,
) -> (HistoricalEdgeClassification, &'static str) {
    let (Some(mean), Some(median), Some(cumulative)) =
        (mean_net_return, median_net_return, cumulative_net_return)
    else {
        return (
            HistoricalEdgeClassification::InsufficientEvidence,
            "Insufficient complete after-cost return metrics; no edge conclusion is supported.",
        );
    };
    if completed_backtests == 0 {
        return (
            HistoricalEdgeClassification::InsufficientEvidence,
            "Insufficient complete after-cost return metrics; no edge conclusion is supported.",
        );
    }
    if mean > 0.0 && median > 0.0 && cumulative > 0.0 {
        return (
            HistoricalEdgeClassification::PositiveAfterCostDescriptive,
            "Mean, median, and cumulative returns are positive after stated costs in this exploratory sample; this descriptive result does not establish a statistically validated edge.",
        );
    }
    if cumulative < 0.0 {
        return (
            HistoricalEdgeClassification::NoDemonstratedEdge,
            "This exploratory rule lost money after the stated costs and does not demonstrate an edge.",
        );
    }
    (
        HistoricalEdgeClassification::NoDemonstratedEdge,
        "At least one after-cost mean, median, or cumulative return is non-positive; this exploratory rule does not demonstrate an edge.",
    )
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HistoricalSetupStats {
    pub symbol: String,
    pub setup_type: MarketSetupType,
    pub method_version: String,
    pub event_definition: String,
    pub source: String,
    pub dataset_start: Option<NaiveDate>,
    pub dataset_end: Option<NaiveDate>,
    pub sessions: usize,
    pub event_sessions: usize,
    pub event_rate: Option<f64>,
    pub event_bar_q25: Option<f64>,
    pub event_bar_median: Option<f64>,
    pub event_bar_q75: Option<f64>,
    pub median_clock_et: Option<String>,
    pub top_event_bars: Vec<Value>,
    pub forward_label_minutes: usize,
    pub completed_backtests: usize,
    pub session_integrity: HistoricalSessionIntegrity,
    pub label_integrity: HistoricalLabelIntegrity,
    pub vwap_status: HistoricalVwapStatus,
    pub entry_semantics: String,
    pub assumed_round_trip_cost_bps: f64,
    pub raw_forward_direction_frequency: Option<f64>,
    pub median_forward_return: Option<f64>,
    pub forward_return_q05: Option<f64>,
    pub forward_return_q95: Option<f64>,
    pub median_mfe: Option<f64>,
    pub median_mae: Option<f64>,
    pub net_win_rate: Option<f64>,
    pub mean_net_return: Option<f64>,
    pub median_net_return: Option<f64>,
    pub cumulative_net_return: Option<f64>,
    pub max_drawdown: Option<f64>,
    pub edge_classification: HistoricalEdgeClassification,
    pub edge_classification_detail: String,
    pub performance_scope: String,
    pub data_manifest_hash: Option<String>,
    pub evidence_grade: String,
    pub caveats: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HistoricalSessionIntegrity {
    pub target_rows: usize,
    pub unique_regular_session_rows: usize,
    pub exact_duplicate_rows: usize,
    pub conflicting_duplicate_rows: usize,
    pub observed_sessions: usize,
    pub complete_sessions: usize,
    pub excluded_sessions: usize,
    pub session_exclusion_counts: BTreeMap<String, usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HistoricalLabelIntegrity {
    pub detected_events: usize,
    pub completed_labels: usize,
    pub excluded_events: usize,
    pub event_exclusion_counts: BTreeMap<String, usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HistoricalVwapStatus {
    pub policy: String,
    pub eligible_minute_rows: usize,
    pub authorized_vendor_vwap_rows: usize,
    pub reported_but_unauthorized_vendor_vwap_rows: usize,
    pub authorized_vendor_minute_coverage: f64,
    pub sessions_using_authorized_vendor_vwap: usize,
    pub sessions_using_reconstructed_proxy: usize,
    pub parity_observations: usize,
    pub median_absolute_parity_bps: Option<f64>,
    pub maximum_absolute_parity_bps: Option<f64>,
}

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PipelineReadinessState {
    Ready,
    Waiting,
    Blocked,
    #[default]
    NotChecked,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct PipelineReadinessStage {
    pub state: PipelineReadinessState,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub code: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub observed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct PipelineReadiness {
    pub model: PipelineReadinessStage,
    pub feed: PipelineReadinessStage,
    pub context: PipelineReadinessStage,
    pub inference: PipelineReadinessStage,
    pub publication: PipelineReadinessStage,
}

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum EvidenceMode {
    #[default]
    Live,
    /// Licensed realtime evidence rendered only by an explicitly enabled
    /// loopback research runtime. This mode may expose uncalibrated descriptive
    /// model moments, but it never claims public redistribution authorization,
    /// OOS calibration, promotion, ranking, or execution eligibility.
    LocalUncalibratedLiveResearch,
    DeterministicHistoricalReplay,
}

impl EvidenceMode {
    fn is_live(mode: &Self) -> bool {
        *mode == Self::Live
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvidenceEnvelope {
    pub schema_version: String,
    #[serde(default, skip_serializing_if = "EvidenceMode::is_live")]
    pub evidence_mode: EvidenceMode,
    pub request_id: String,
    pub query_sha256: String,
    pub response_sha256: Option<String>,
    pub generated_at: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub status: String,
    pub query: MarketQuery,
    pub candidates: Vec<ResearchCandidate>,
    pub exclusions: Vec<Value>,
    pub historical: Vec<HistoricalSetupStats>,
    pub data_blockers: Vec<String>,
    pub readiness: PipelineReadiness,
    pub model_contract: Value,
    pub research_only_policy: Value,
    pub caveats: Vec<String>,
}

impl EvidenceEnvelope {
    fn validate_publication_contract(&self) -> Result<()> {
        let deterministic_replay =
            self.evidence_mode == EvidenceMode::DeterministicHistoricalReplay;
        let local_uncalibrated_live =
            self.evidence_mode == EvidenceMode::LocalUncalibratedLiveResearch;
        if self.schema_version != EVIDENCE_ENVELOPE_SCHEMA_VERSION
            || self.request_id.trim().is_empty()
            || self.query_sha256 != self.query.canonical_sha256()?
        {
            bail!("PUBLIC_EVIDENCE_ENVELOPE_IDENTITY_INVALID");
        }
        if !matches!(
            self.status.as_str(),
            "AVAILABLE" | "PARTIAL" | "DATA_UNAVAILABLE" | "UNCALIBRATED_RESEARCH_OUTPUT"
        ) {
            bail!("PUBLIC_EVIDENCE_ENVELOPE_STATUS_INVALID");
        }
        if !self.data_blockers.is_empty() {
            let valid_live_failure = self.status == "DATA_UNAVAILABLE"
                && self.candidates.is_empty()
                && self.historical.is_empty();
            let valid_historical_only_partial = self.status == "PARTIAL"
                && self.candidates.is_empty()
                && !self.historical.is_empty();
            if !valid_live_failure && !valid_historical_only_partial {
                bail!("PUBLIC_EVIDENCE_ENVELOPE_DID_NOT_FAIL_CLOSED");
            }
        }
        if self.status == "DATA_UNAVAILABLE"
            && (!self.candidates.is_empty() || !self.historical.is_empty())
        {
            bail!("DATA_UNAVAILABLE_ENVELOPE_CONTAINS_RESULTS");
        }
        if self.status == "AVAILABLE" && self.candidates.is_empty() && self.historical.is_empty() {
            bail!("AVAILABLE_ENVELOPE_HAS_NO_RESULT");
        }
        if self.status == "PARTIAL"
            && (self.data_blockers.is_empty()
                || !self.candidates.is_empty()
                || self.historical.is_empty())
        {
            bail!("PARTIAL_ENVELOPE_MUST_BE_HISTORICAL_ONLY_WITH_LIVE_BLOCKERS");
        }
        if self.status == "UNCALIBRATED_RESEARCH_OUTPUT" && self.candidates.is_empty() {
            bail!("UNCALIBRATED_ENVELOPE_HAS_NO_CANDIDATE");
        }
        if self.readiness.publication.state == PipelineReadinessState::Ready
            && self.candidates.is_empty()
        {
            bail!("PUBLICATION_READY_WITHOUT_VISIBLE_CANDIDATE");
        }
        if self.query.setup_type == MarketSetupType::ModelForecast
            && !self.candidates.is_empty()
            && self.readiness.publication.state != PipelineReadinessState::Ready
        {
            bail!("MODEL_FORECAST_CANDIDATE_WITHOUT_PUBLICATION_READINESS");
        }

        for candidate in &self.candidates {
            if candidate.freshness.is_empty() {
                bail!("PUBLIC_CANDIDATE_FRESHNESS_MISSING");
            }
            for freshness in &candidate.freshness {
                let (Some(observed_at), Some(available_at), Some(age_seconds)) = (
                    freshness.observed_at,
                    freshness.available_at,
                    freshness.age_seconds,
                ) else {
                    bail!("PUBLIC_CANDIDATE_CLOCKS_MISSING");
                };
                let computed_age = self
                    .generated_at
                    .signed_duration_since(available_at)
                    .num_seconds();
                if freshness.source.trim().is_empty()
                    || freshness.entitlement.trim().is_empty()
                    || freshness.realtime == deterministic_replay
                    || available_at < observed_at
                    || computed_age < 0
                    || (computed_age - age_seconds).abs() > 1
                    || freshness.coverage.is_some_and(|coverage| {
                        !coverage.is_finite() || !(0.0..=1.0).contains(&coverage)
                    })
                {
                    bail!("PUBLIC_CANDIDATE_FRESHNESS_INVALID");
                }
                if deterministic_replay
                    && (!(freshness.source.starts_with("DATABENTO_REPLAY:")
                        || freshness.source.starts_with("HISTORICAL_REPLAY:"))
                        || freshness.entitlement != "DETERMINISTIC_REPLAY_NOT_CURRENT_MARKET_DATA")
                {
                    bail!("PUBLIC_REPLAY_CANDIDATE_IDENTITY_INVALID");
                }
            }

            if candidate.status != "UNCALIBRATED_RESEARCH_OUTPUT" {
                continue;
            }
            if candidate.heuristic_structure_score.is_some() {
                bail!("UNCALIBRATED_CANDIDATE_RANK_PRESENT");
            }
            let Some(metrics) = candidate.metrics.as_object() else {
                bail!("UNCALIBRATED_CANDIDATE_METRICS_INVALID");
            };
            let strict_historical_replay = deterministic_replay
                && candidate
                    .freshness
                    .iter()
                    .all(|freshness| freshness.source.starts_with("HISTORICAL_REPLAY:"));
            let mut allowed = BTreeSet::from([
                "horizon_minutes",
                "statistical_orientation",
                "observation_cutoff",
                "latest_input_available_at",
                "data_age_seconds",
                "data_source",
                "coverage",
                "coverage_semantics",
                "caveats",
                "published_probability_status",
                "validation",
                "interpretation",
            ]);
            if strict_historical_replay || local_uncalibrated_live {
                allowed.extend([
                    "expected_return",
                    "median_return",
                    "return_quantiles",
                    "raw_analog_up_frequency",
                    "raw_analog_down_frequency",
                    "raw_analog_flat_frequency",
                    "analog_effective_sample_size",
                    "analog_similarity_score",
                    "dominant_regime_state",
                    "dominant_regime_probability",
                    "top_analogs",
                ]);
            }
            if strict_historical_replay {
                allowed.insert("realized_outcome");
            }
            let coverage = metrics.get("coverage").and_then(Value::as_f64);
            let coverage_valid = if strict_historical_replay {
                coverage.is_some_and(|value| value.is_finite() && (value - 1.0).abs() <= 1.0e-12)
            } else {
                coverage == Some(1.0)
            };
            if metrics.keys().any(|key| !allowed.contains(key.as_str()))
                || metrics
                    .get("published_probability_status")
                    .and_then(Value::as_str)
                    != Some("WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION")
                || !coverage_valid
                || metrics
                    .get("coverage_semantics")
                    .and_then(Value::as_str)
                    .is_none_or(str::is_empty)
                || metrics
                    .get("caveats")
                    .and_then(Value::as_array)
                    .is_none_or(Vec::is_empty)
            {
                bail!("UNCALIBRATED_CANDIDATE_WHITELIST_VIOLATION");
            }
            let validation = metrics.get("validation").and_then(Value::as_object);
            let valid_lineage = validation.is_some_and(|lineage| {
                ["model_version", "feature_version"].iter().all(|key| {
                    lineage
                        .get(*key)
                        .and_then(Value::as_str)
                        .is_some_and(|v| !v.is_empty())
                }) && ["model_hash", "feature_hash", "data_manifest_hash"]
                    .iter()
                    .all(|key| {
                        lineage
                            .get(*key)
                            .and_then(Value::as_str)
                            .is_some_and(is_sha256_hex)
                    })
            });
            if !valid_lineage {
                bail!("UNCALIBRATED_CANDIDATE_LINEAGE_INVALID");
            }
            let uses_databento = candidate
                .freshness
                .iter()
                .any(|freshness| freshness.source == "DATABENTO:EQUS.MINI");
            if uses_databento {
                let Some(lineage) = validation else {
                    bail!("UNCALIBRATED_DATABENTO_SOURCE_RECEIPT_MISSING");
                };
                let end_to_end_ms = lineage.get("end_to_end_ms").and_then(Value::as_i64);
                let budget_ms = lineage.get("budget_ms").and_then(Value::as_i64);
                if lineage.get("schema_version").and_then(Value::as_str)
                    != Some("databento_inference_receipt.v3")
                    || ["source_envelopes_sha256", "forecast_sha256"]
                        .iter()
                        .any(|key| {
                            lineage
                                .get(*key)
                                .and_then(Value::as_str)
                                .is_none_or(|hash| !is_sha256_hex(hash))
                        })
                    || lineage
                        .get("published_at")
                        .and_then(Value::as_str)
                        .and_then(|raw| DateTime::parse_from_rfc3339(raw).ok())
                        .is_none()
                    || !matches!((end_to_end_ms, budget_ms), (Some(elapsed), Some(budget)) if elapsed >= 0 && budget > 0 && elapsed <= budget)
                {
                    bail!("UNCALIBRATED_DATABENTO_SOURCE_RECEIPT_MISSING");
                }
            }
        }
        for historical in &self.historical {
            let invalid_optional =
                |value: Option<f64>| value.is_some_and(|value| !value.is_finite());
            let session_exclusion_total = historical
                .session_integrity
                .session_exclusion_counts
                .values()
                .try_fold(0_usize, |total, count| total.checked_add(*count));
            let invalid_session_exclusion = historical
                .session_integrity
                .session_exclusion_counts
                .iter()
                .any(|(reason, count)| reason.trim().is_empty() || *count == 0);
            let event_exclusion_total = historical
                .label_integrity
                .event_exclusion_counts
                .values()
                .try_fold(0_usize, |total, count| total.checked_add(*count));
            let invalid_event_exclusion = historical
                .label_integrity
                .event_exclusion_counts
                .iter()
                .any(|(reason, count)| reason.trim().is_empty() || *count == 0);
            let expected_vendor_coverage = if historical.vwap_status.eligible_minute_rows == 0 {
                0.0
            } else {
                historical.vwap_status.authorized_vendor_vwap_rows as f64
                    / historical.vwap_status.eligible_minute_rows as f64
            };
            let valid_parity = match historical.vwap_status.parity_observations {
                0 => {
                    historical.vwap_status.median_absolute_parity_bps.is_none()
                        && historical.vwap_status.maximum_absolute_parity_bps.is_none()
                }
                _ => matches!(
                    (
                        historical.vwap_status.median_absolute_parity_bps,
                        historical.vwap_status.maximum_absolute_parity_bps,
                    ),
                    (Some(median), Some(maximum))
                        if median.is_finite()
                            && maximum.is_finite()
                            && median >= 0.0
                            && maximum >= median
                ),
            };
            let (expected_edge_classification, expected_edge_classification_detail) =
                classify_historical_edge(
                    historical.completed_backtests,
                    historical.mean_net_return,
                    historical.median_net_return,
                    historical.cumulative_net_return,
                );
            if historical.symbol.trim().is_empty()
                || historical.method_version.trim().is_empty()
                || historical.event_definition.trim().is_empty()
                || historical.source.trim().is_empty()
                || historical.dataset_start.is_none()
                || historical.dataset_end.is_none()
                || historical.entry_semantics.trim().is_empty()
                || historical.performance_scope
                    != "HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE"
                || historical.event_sessions > historical.sessions
                || historical.completed_backtests > historical.event_sessions
                || historical.session_integrity.conflicting_duplicate_rows != 0
                || historical
                    .session_integrity
                    .unique_regular_session_rows
                    .checked_add(historical.session_integrity.exact_duplicate_rows)
                    != Some(historical.session_integrity.target_rows)
                || historical
                    .session_integrity
                    .complete_sessions
                    .checked_add(historical.session_integrity.excluded_sessions)
                    != Some(historical.session_integrity.observed_sessions)
                || historical.session_integrity.complete_sessions != historical.sessions
                || session_exclusion_total != Some(historical.session_integrity.excluded_sessions)
                || invalid_session_exclusion
                || historical.label_integrity.detected_events != historical.event_sessions
                || historical.label_integrity.completed_labels != historical.completed_backtests
                || historical.label_integrity.excluded_events
                    != historical
                        .label_integrity
                        .detected_events
                        .saturating_sub(historical.label_integrity.completed_labels)
                || event_exclusion_total != Some(historical.label_integrity.excluded_events)
                || invalid_event_exclusion
                || historical.vwap_status.policy != HISTORICAL_VWAP_POLICY
                || historical.sessions.checked_mul(REGULAR_SESSION_MINUTES)
                    != Some(historical.vwap_status.eligible_minute_rows)
                || historical.vwap_status.authorized_vendor_vwap_rows
                    > historical.vwap_status.eligible_minute_rows
                || historical
                    .vwap_status
                    .reported_but_unauthorized_vendor_vwap_rows
                    > historical.vwap_status.eligible_minute_rows
                || historical
                    .vwap_status
                    .authorized_vendor_vwap_rows
                    .checked_add(
                        historical
                            .vwap_status
                            .reported_but_unauthorized_vendor_vwap_rows,
                    )
                    .is_none_or(|total| total > historical.vwap_status.eligible_minute_rows)
                || historical
                    .vwap_status
                    .sessions_using_authorized_vendor_vwap
                    .checked_add(historical.vwap_status.sessions_using_reconstructed_proxy)
                    != Some(historical.sessions)
                || historical
                    .vwap_status
                    .sessions_using_authorized_vendor_vwap
                    .checked_mul(REGULAR_SESSION_MINUTES)
                    .is_none_or(|minimum| {
                        historical.vwap_status.authorized_vendor_vwap_rows < minimum
                    })
                || !historical
                    .vwap_status
                    .authorized_vendor_minute_coverage
                    .is_finite()
                || !(0.0..=1.0).contains(&historical.vwap_status.authorized_vendor_minute_coverage)
                || (historical.vwap_status.authorized_vendor_minute_coverage
                    - expected_vendor_coverage)
                    .abs()
                    > f64::EPSILON
                || historical
                    .vwap_status
                    .sessions_using_authorized_vendor_vwap
                    .checked_mul(REGULAR_SESSION_MINUTES / 5)
                    != Some(historical.vwap_status.parity_observations)
                || !valid_parity
                || !historical.assumed_round_trip_cost_bps.is_finite()
                || historical.assumed_round_trip_cost_bps < 0.0
                || historical
                    .net_win_rate
                    .is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value))
                || invalid_optional(historical.mean_net_return)
                || invalid_optional(historical.median_net_return)
                || historical
                    .cumulative_net_return
                    .is_some_and(|value| !value.is_finite() || value <= -1.0)
                || historical
                    .max_drawdown
                    .is_some_and(|value| !value.is_finite() || !(-1.0..=0.0).contains(&value))
                || historical.edge_classification != expected_edge_classification
                || historical.edge_classification_detail != expected_edge_classification_detail
                || historical
                    .data_manifest_hash
                    .as_deref()
                    .is_none_or(|hash| !is_sha256_hex(hash))
                || historical.caveats.is_empty()
                || historical
                    .caveats
                    .iter()
                    .any(|caveat| caveat.trim().is_empty())
            {
                bail!("PUBLIC_HISTORICAL_EVIDENCE_INVALID");
            }
        }
        Ok(())
    }

    pub fn seal(&mut self) -> Result<()> {
        self.response_sha256 = None;
        self.validate_publication_contract()?;
        self.response_sha256 = Some(sha256_hex(&serde_json::to_vec(self)?));
        Ok(())
    }
}

fn is_sha256_hex(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

#[derive(Debug, Deserialize)]
struct HistoricalBarRow {
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
    vwap_authorized: bool,
    source: String,
    data_quality: String,
}

#[derive(Debug, Clone, PartialEq)]
struct MinuteBar {
    interval_start: DateTime<Utc>,
    interval_end: DateTime<Utc>,
    minute_from_open: i32,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    vendor_vwap: Option<f64>,
    vendor_vwap_authorized: bool,
    source: String,
    data_quality: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SessionVwapMethod {
    AuthorizedVendorMinuteVwap,
    ReconstructedCloseVolumeProxy,
}

impl SessionVwapMethod {
    fn as_str(self) -> &'static str {
        match self {
            Self::AuthorizedVendorMinuteVwap => "AUTHORIZED_VENDOR_MINUTE_VWAP",
            Self::ReconstructedCloseVolumeProxy => "RECONSTRUCTED_CLOSE_VOLUME_PROXY",
        }
    }
}

#[derive(Debug, Clone)]
struct FiveMinuteBar {
    number: usize,
    interval_start: DateTime<Utc>,
    interval_end: DateTime<Utc>,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    session_vwap: f64,
    session_vwap_method: SessionVwapMethod,
}

#[derive(Debug)]
struct AggregatedSession {
    bars: Vec<FiveMinuteBar>,
    vwap_method: SessionVwapMethod,
    absolute_parity_bps: Vec<f64>,
}

#[derive(Debug, Clone, Copy)]
struct MomentumObservation {
    matched: bool,
    lookback_bars: usize,
    cumulative_return: f64,
    directional_bars: usize,
    recent_volume_ratio: Option<f64>,
    threshold_return: f64,
}

#[derive(Debug)]
struct EventObservation {
    bar_number: usize,
    forward_return: Option<f64>,
    mfe: Option<f64>,
    mae: Option<f64>,
    label_exclusion_reason: Option<String>,
}

#[derive(Debug)]
struct HistoricalSessionLoad {
    sessions: BTreeMap<NaiveDate, Vec<MinuteBar>>,
    sources: BTreeSet<String>,
    manifest_hash: Option<String>,
    dataset_start: Option<NaiveDate>,
    dataset_end: Option<NaiveDate>,
    integrity: HistoricalSessionIntegrity,
}

#[derive(Debug, Default)]
struct HistoricalManifestLineage {
    manifest_hash: Option<String>,
    vendor_minute_vwap_authorized: bool,
}

fn load_regular_sessions(
    path: &Path,
    symbol: &str,
    cutoff: Option<DateTime<Utc>>,
) -> Result<HistoricalSessionLoad> {
    let mut reader = csv::ReaderBuilder::new()
        .flexible(false)
        .from_path(path)
        .with_context(|| format!("open historical market bars {}", path.display()))?;
    let headers = reader
        .headers()
        .with_context(|| format!("read historical market-bar header {}", path.display()))?
        .clone();
    let symbol_index = headers
        .iter()
        .position(|header| header.trim().eq_ignore_ascii_case("symbol"))
        .context("historical market-bar file is missing the symbol column")?;
    let mut rows_by_timestamp = BTreeMap::<DateTime<Utc>, MinuteBar>::new();
    let mut sources = BTreeSet::new();
    let mut dates_after_cutoff = BTreeSet::<NaiveDate>::new();
    let mut target_rows = 0_usize;
    let mut exact_duplicate_rows = 0_usize;
    for (row_index, raw_record) in reader.records().enumerate() {
        let raw_record = raw_record.with_context(|| {
            format!(
                "read historical market-bar record {} from {}",
                row_index + 2,
                path.display()
            )
        })?;
        if !raw_record
            .get(symbol_index)
            .unwrap_or_default()
            .trim()
            .eq_ignore_ascii_case(symbol)
        {
            continue;
        }
        let row = raw_record
            .deserialize::<HistoricalBarRow>(Some(&headers))
            .with_context(|| {
                format!(
                    "malformed target row for {symbol} at CSV record {}",
                    row_index + 2
                )
            })?;
        if !row.symbol.trim().eq_ignore_ascii_case(symbol) {
            bail!(
                "target symbol changed during CSV deserialization at record {}",
                row_index + 2
            );
        }
        let timestamp = DateTime::parse_from_rfc3339(&row.timestamp)
            .with_context(|| {
                format!(
                    "invalid target timestamp for {symbol} at CSV record {}",
                    row_index + 2
                )
            })?
            .with_timezone(&Utc);
        if !row.open.is_finite()
            || !row.high.is_finite()
            || !row.low.is_finite()
            || !row.close.is_finite()
            || !row.volume.is_finite()
            || row
                .vwap
                .is_some_and(|value| !value.is_finite() || value <= 0.0)
            || row.open <= 0.0
            || row.low <= 0.0
            || row.high < row.low
            || row.high < row.open.max(row.close)
            || row.low > row.open.min(row.close)
            || row.volume < 0.0
            || row.source.trim().is_empty()
            || row.data_quality.trim().is_empty()
        {
            bail!(
                "invalid target OHLCV/VWAP row for {symbol} at CSV record {}",
                row_index + 2
            );
        }
        let local = timestamp.with_timezone(&New_York);
        let minute = (local.hour() * 60 + local.minute()) as i32;
        if !(570..960).contains(&minute) {
            continue;
        }
        if local.second() != 0 || timestamp.timestamp_subsec_nanos() != 0 {
            bail!(
                "target row for {symbol} is not aligned to an exact exchange-clock minute at CSV record {}",
                row_index + 2
            );
        }
        if cutoff.is_some_and(|value| timestamp > value) {
            dates_after_cutoff.insert(local.date_naive());
            continue;
        }
        target_rows += 1;
        let candidate = MinuteBar {
            interval_start: timestamp,
            interval_end: timestamp + chrono::Duration::minutes(1),
            minute_from_open: minute - 570,
            open: row.open,
            high: row.high,
            low: row.low,
            close: row.close,
            volume: row.volume,
            vendor_vwap: row.vwap,
            vendor_vwap_authorized: row.vwap_authorized,
            source: row.source,
            data_quality: row.data_quality,
        };
        if let Some(existing) = rows_by_timestamp.get(&timestamp) {
            if existing == &candidate {
                exact_duplicate_rows += 1;
                continue;
            }
            bail!(
                "conflicting duplicate target timestamp for {symbol} at {}",
                timestamp.to_rfc3339()
            );
        }
        sources.insert(candidate.source.clone());
        rows_by_timestamp.insert(timestamp, candidate);
    }

    let lineage = historical_manifest_lineage(path, &sources);
    for row in rows_by_timestamp.values_mut() {
        row.vendor_vwap_authorized &=
            lineage.vendor_minute_vwap_authorized && row.vendor_vwap.is_some();
    }
    let mut observed_sessions = BTreeMap::<NaiveDate, Vec<MinuteBar>>::new();
    for row in rows_by_timestamp.into_values() {
        observed_sessions
            .entry(row.interval_start.with_timezone(&New_York).date_naive())
            .or_default()
            .push(row);
    }
    for rows in observed_sessions.values_mut() {
        rows.sort_by_key(|row| row.minute_from_open);
    }
    let dataset_start = observed_sessions.keys().next().copied();
    let dataset_end = observed_sessions.keys().next_back().copied();
    let unique_regular_session_rows = observed_sessions.values().map(Vec::len).sum();
    let observed_session_count = observed_sessions.len();
    let mut session_exclusion_counts = BTreeMap::<String, usize>::new();
    let mut sessions = BTreeMap::<NaiveDate, Vec<MinuteBar>>::new();
    for (date, rows) in observed_sessions {
        let complete_clock = rows.len() == REGULAR_SESSION_MINUTES
            && rows
                .iter()
                .enumerate()
                .all(|(index, row)| row.minute_from_open == index as i32);
        if !complete_clock {
            let reason = if dates_after_cutoff.contains(&date) {
                "CUTOFF_TRUNCATED_REGULAR_SESSION"
            } else {
                "INCOMPLETE_REGULAR_SESSION"
            };
            *session_exclusion_counts
                .entry(reason.to_string())
                .or_default() += 1;
            continue;
        }
        if rows.iter().map(|row| row.volume).sum::<f64>() <= 0.0 {
            *session_exclusion_counts
                .entry("ZERO_TOTAL_SESSION_VOLUME".to_string())
                .or_default() += 1;
            continue;
        }
        if rows.iter().take(5).map(|row| row.volume).sum::<f64>() <= 0.0 {
            *session_exclusion_counts
                .entry("ZERO_OPENING_FIVE_MINUTE_VOLUME".to_string())
                .or_default() += 1;
            continue;
        }
        sessions.insert(date, rows);
    }
    Ok(HistoricalSessionLoad {
        integrity: HistoricalSessionIntegrity {
            target_rows,
            unique_regular_session_rows,
            exact_duplicate_rows,
            conflicting_duplicate_rows: 0,
            observed_sessions: observed_session_count,
            complete_sessions: sessions.len(),
            excluded_sessions: observed_session_count.saturating_sub(sessions.len()),
            session_exclusion_counts,
        },
        sessions,
        sources,
        manifest_hash: lineage.manifest_hash,
        dataset_start,
        dataset_end,
    })
}

fn historical_manifest_lineage(
    bars_path: &Path,
    observed_sources: &BTreeSet<String>,
) -> HistoricalManifestLineage {
    let expected_rights_pin = env::var(MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV).ok();
    historical_manifest_lineage_with_pin(
        bars_path,
        observed_sources,
        Utc::now(),
        expected_rights_pin.as_deref(),
    )
}

fn historical_manifest_lineage_with_pin(
    bars_path: &Path,
    observed_sources: &BTreeSet<String>,
    now: DateTime<Utc>,
    expected_rights_pin: Option<&str>,
) -> HistoricalManifestLineage {
    let Ok(output_bytes) = fs::read(bars_path) else {
        return HistoricalManifestLineage::default();
    };
    let output_sha256 = sha256_hex(&output_bytes);
    let Some(output_file) = bars_path.file_name().and_then(|value| value.to_str()) else {
        return HistoricalManifestLineage::default();
    };
    let mut manifest_roots = Vec::new();
    if let Some(parent) = bars_path.parent() {
        manifest_roots.push(parent.join("manifests"));
        if let Some(grandparent) = parent.parent() {
            manifest_roots.push(grandparent.join("manifests"));
        }
    }
    manifest_roots.sort();
    manifest_roots.dedup();
    let mut paths = manifest_roots
        .into_iter()
        .filter_map(|root| fs::read_dir(root).ok())
        .flatten()
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| {
            let metadata = entry.metadata().ok()?;
            metadata
                .is_file()
                .then_some((metadata.modified().ok()?, entry.path()))
        })
        .collect::<Vec<_>>();
    paths.sort_by_key(|row| std::cmp::Reverse(row.0));
    for (_, manifest_path) in paths {
        let Ok(manifest_bytes) = fs::read(&manifest_path) else {
            continue;
        };
        let Ok(value) = serde_json::from_slice::<Value>(&manifest_bytes) else {
            continue;
        };
        let sources = value
            .get("sources")
            .and_then(Value::as_array)
            .map(|values| {
                values
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::to_string)
                    .collect::<BTreeSet<_>>()
            })
            .unwrap_or_default();
        if value.get("schema_version").and_then(Value::as_str)
            != Some("axio.historical-bars-manifest.v1")
            || value.get("output_file").and_then(Value::as_str) != Some(output_file)
            || value.get("output_sha256").and_then(Value::as_str) != Some(output_sha256.as_str())
            || !observed_sources.is_subset(&sources)
        {
            continue;
        }
        let authorized_fields = value
            .get("authorized_fields")
            .and_then(Value::as_array)
            .is_some_and(|fields| {
                fields
                    .iter()
                    .any(|field| field.as_str() == Some("minute_vwap"))
            });
        let capability = value
            .pointer("/capabilities/vendor_minute_vwap")
            .and_then(Value::as_bool)
            == Some(true);
        let rights_receipt_sha256 = value
            .get("rights_receipt_sha256")
            .and_then(Value::as_str)
            .filter(|value| is_sha256_hex(value));
        let provider = value.get("provider").and_then(Value::as_str);
        let product = value.get("product").and_then(Value::as_str);
        let receipt_root = manifest_path.parent().and_then(Path::parent);
        let rights_receipt_verified = provider
            .zip(product)
            .zip(receipt_root)
            .zip(rights_receipt_sha256)
            .is_some_and(|(((provider, product), root), manifest_pin)| {
                expected_rights_pin.is_some_and(|external_pin| {
                    external_pin.eq_ignore_ascii_case(manifest_pin)
                        && pinned_market_data_rights_receipt_is_verified(
                            root,
                            provider,
                            product,
                            now,
                            Some(external_pin),
                        )
                })
            });
        return HistoricalManifestLineage {
            manifest_hash: Some(sha256_hex(&manifest_bytes)),
            vendor_minute_vwap_authorized: authorized_fields
                && capability
                && rights_receipt_verified,
        };
    }
    HistoricalManifestLineage::default()
}

fn aggregate_five_minutes(rows: &[MinuteBar]) -> Result<AggregatedSession> {
    let vwap_method = if !rows.is_empty()
        && rows
            .iter()
            .all(|row| row.vendor_vwap_authorized && row.vendor_vwap.is_some())
    {
        SessionVwapMethod::AuthorizedVendorMinuteVwap
    } else {
        SessionVwapMethod::ReconstructedCloseVolumeProxy
    };
    let mut by_minute = BTreeMap::<i32, &MinuteBar>::new();
    for row in rows {
        if row.interval_end != row.interval_start + chrono::Duration::minutes(1)
            || !(0..REGULAR_SESSION_MINUTES as i32).contains(&row.minute_from_open)
            || row
                .vendor_vwap
                .is_some_and(|value| !value.is_finite() || value <= 0.0)
        {
            bail!("minute row has an invalid exchange-clock interval or VWAP");
        }
        if let Some(existing) = by_minute.insert(row.minute_from_open, row)
            && existing != row
        {
            bail!("conflicting duplicate exchange-clock minute");
        }
    }
    let mut output = Vec::new();
    let mut cumulative_pv = 0.0;
    let mut cumulative_proxy_pv = 0.0;
    let mut cumulative_volume = 0.0;
    let mut absolute_parity_bps = Vec::new();
    let session_open = rows
        .first()
        .map(|row| row.interval_start - chrono::Duration::minutes(i64::from(row.minute_from_open)));
    for bucket in 0..78 {
        let start = bucket * 5;
        let Some(bucket_rows) = (start..start + 5)
            .map(|minute| by_minute.get(&minute).copied())
            .collect::<Option<Vec<_>>>()
        else {
            break;
        };
        let Some(expected_session_open) = session_open else {
            break;
        };
        if bucket_rows.iter().enumerate().any(|(offset, row)| {
            let expected_start =
                expected_session_open + chrono::Duration::minutes(i64::from(start + offset as i32));
            row.interval_start != expected_start
                || row.interval_end != expected_start + chrono::Duration::minutes(1)
        }) {
            bail!("five-minute bar does not contain five unique contiguous real minutes");
        }
        for row in &bucket_rows {
            cumulative_proxy_pv += row.close * row.volume;
            cumulative_pv += match vwap_method {
                SessionVwapMethod::AuthorizedVendorMinuteVwap => {
                    row.vendor_vwap
                        .context("authorized vendor VWAP coverage changed within a session")?
                        * row.volume
                }
                SessionVwapMethod::ReconstructedCloseVolumeProxy => row.close * row.volume,
            };
            cumulative_volume += row.volume;
        }
        if cumulative_volume <= 0.0 {
            bail!("five-minute aggregation has zero cumulative traded volume");
        }
        let Some(first) = bucket_rows.first() else {
            continue;
        };
        let Some(last) = bucket_rows.last() else {
            continue;
        };
        output.push(FiveMinuteBar {
            number: bucket as usize + 1,
            interval_start: first.interval_start,
            interval_end: last.interval_end,
            open: first.open,
            high: bucket_rows
                .iter()
                .map(|row| row.high)
                .fold(f64::NEG_INFINITY, f64::max),
            low: bucket_rows
                .iter()
                .map(|row| row.low)
                .fold(f64::INFINITY, f64::min),
            close: last.close,
            volume: bucket_rows.iter().map(|row| row.volume).sum(),
            session_vwap: cumulative_pv / cumulative_volume,
            session_vwap_method: vwap_method,
        });
        if vwap_method == SessionVwapMethod::AuthorizedVendorMinuteVwap {
            let vendor = cumulative_pv / cumulative_volume;
            let proxy = cumulative_proxy_pv / cumulative_volume;
            absolute_parity_bps.push(((vendor / proxy) - 1.0).abs() * 10_000.0);
        }
    }
    Ok(AggregatedSession {
        bars: output,
        vwap_method,
        absolute_parity_bps,
    })
}

fn momentum_observation(
    bars: &[FiveMinuteBar],
    direction: TurnDirection,
    horizon_minutes: usize,
) -> Option<MomentumObservation> {
    let requested_bars = horizon_minutes.div_ceil(5).clamp(2, 12);
    if bars.len() < requested_bars {
        return None;
    }
    let window = &bars[bars.len() - requested_bars..];
    let first = window.first()?;
    let latest = window.last()?;
    let previous = window.get(window.len().saturating_sub(2))?;
    let cumulative_return = latest.close / first.open - 1.0;
    let directional_bars = window
        .iter()
        .filter(|bar| match direction {
            TurnDirection::Up => bar.close > bar.open,
            TurnDirection::Down => bar.close < bar.open,
        })
        .count();
    let previous_average_volume = bars
        .iter()
        .take(bars.len().saturating_sub(1))
        .map(|bar| bar.volume)
        .filter(|volume| volume.is_finite() && *volume >= 0.0)
        .sum::<f64>()
        / bars.len().saturating_sub(1).max(1) as f64;
    let recent_volume_ratio = (previous_average_volume > 0.0)
        .then_some(latest.volume / previous_average_volume)
        .filter(|value| value.is_finite());
    let threshold_return = 0.00075 * (requested_bars as f64).sqrt();
    let required_directional_bars = requested_bars.div_ceil(2);
    let matched = match direction {
        TurnDirection::Up => {
            cumulative_return >= threshold_return
                && directional_bars >= required_directional_bars
                && latest.close > latest.session_vwap
                && latest.close > previous.close
                && recent_volume_ratio.is_some_and(|value| value >= 0.90)
        }
        TurnDirection::Down => {
            cumulative_return <= -threshold_return
                && directional_bars >= required_directional_bars
                && latest.close < latest.session_vwap
                && latest.close < previous.close
                && recent_volume_ratio.is_some_and(|value| value >= 0.90)
        }
    };
    Some(MomentumObservation {
        matched,
        lookback_bars: requested_bars,
        cumulative_return,
        directional_bars,
        recent_volume_ratio,
        threshold_return,
    })
}

fn detect_event(
    bars: &[FiveMinuteBar],
    setup_type: MarketSetupType,
    direction: TurnDirection,
    horizon_minutes: usize,
) -> Option<EventObservation> {
    if bars.len() < 4 {
        return None;
    }
    let session_open = bars.first()?.open;
    let mut running_high = bars[0].high;
    let mut running_low = bars[0].low;
    for index in 1..bars.len() {
        let current = &bars[index];
        let previous = &bars[index - 1];
        let down = match setup_type {
            MarketSetupType::OpeningTurn => {
                let prior_positive_progress =
                    running_high / session_open - 1.0 >= 0.001 || previous.close > session_open;
                current.number <= 24
                    && prior_positive_progress
                    && current.close < current.open
                    && current.close < previous.close
                    && current.high < running_high
                    && (current.close < current.session_vwap || current.close < previous.low)
            }
            MarketSetupType::VwapReversal => {
                current.number >= 3
                    && previous.close >= previous.session_vwap
                    && current.close < current.session_vwap
                    && current.close < current.open
                    && current.close < previous.close
            }
            MarketSetupType::Momentum => {
                momentum_observation(&bars[..=index], TurnDirection::Down, horizon_minutes)
                    .is_some_and(|observation| observation.matched)
            }
            MarketSetupType::StatisticalDislocation => {
                statistical_dislocation_matched(&bars[..=index], TurnDirection::Down)
            }
            _ => false,
        };
        let up = match setup_type {
            MarketSetupType::OpeningTurn => {
                let prior_negative_progress =
                    running_low / session_open - 1.0 <= -0.001 || previous.close < session_open;
                current.number <= 24
                    && prior_negative_progress
                    && current.close > current.open
                    && current.close > previous.close
                    && current.low > running_low
                    && (current.close > current.session_vwap || current.close > previous.high)
            }
            MarketSetupType::VwapReversal => {
                current.number >= 3
                    && previous.close <= previous.session_vwap
                    && current.close > current.session_vwap
                    && current.close > current.open
                    && current.close > previous.close
            }
            MarketSetupType::Momentum => {
                momentum_observation(&bars[..=index], TurnDirection::Up, horizon_minutes)
                    .is_some_and(|observation| observation.matched)
            }
            MarketSetupType::StatisticalDislocation => {
                statistical_dislocation_matched(&bars[..=index], TurnDirection::Up)
            }
            _ => false,
        };
        running_high = running_high.max(current.high);
        running_low = running_low.min(current.low);
        let matched = match direction {
            TurnDirection::Down => down,
            TurnDirection::Up => up,
        };
        if !matched {
            continue;
        }
        return Some(exact_clock_event_label(bars, index, horizon_minutes));
    }
    None
}

fn exact_clock_event_label(
    bars: &[FiveMinuteBar],
    event_index: usize,
    horizon_minutes: usize,
) -> EventObservation {
    let current = &bars[event_index];
    let excluded = |reason: &str| EventObservation {
        bar_number: current.number,
        forward_return: None,
        mfe: None,
        mae: None,
        label_exclusion_reason: Some(reason.to_string()),
    };
    if horizon_minutes == 0 || !horizon_minutes.is_multiple_of(5) {
        return excluded(MISSING_HORIZON_EXCLUSION);
    }
    let entry_clock = current.interval_end;
    let exit_clock = entry_clock + chrono::Duration::minutes(horizon_minutes as i64);
    let regular_session_open = current.interval_start
        - chrono::Duration::minutes(
            current.number.saturating_sub(1) as i64 * FIVE_MINUTE_INTERVAL_MINUTES,
        );
    let regular_session_close =
        regular_session_open + chrono::Duration::minutes(REGULAR_SESSION_MINUTES as i64);
    if exit_clock > regular_session_close {
        return excluded(LATE_EVENT_EXCLUSION);
    }
    let Some(entry_index) = bars
        .iter()
        .position(|bar| bar.interval_start == entry_clock)
    else {
        return excluded(MISSING_ENTRY_EXCLUSION);
    };
    let required_bars = horizon_minutes / 5;
    let mut future = Vec::with_capacity(required_bars);
    for offset in 0..required_bars {
        let expected_start =
            entry_clock + chrono::Duration::minutes((offset as i64) * FIVE_MINUTE_INTERVAL_MINUTES);
        let expected_end = expected_start + chrono::Duration::minutes(FIVE_MINUTE_INTERVAL_MINUTES);
        let Some(bar) = bars.get(entry_index + offset) else {
            return excluded(MISSING_HORIZON_EXCLUSION);
        };
        if bar.interval_start != expected_start || bar.interval_end != expected_end {
            return excluded(MISSING_HORIZON_EXCLUSION);
        }
        future.push(bar);
    }
    if future
        .last()
        .is_none_or(|bar| bar.interval_end != exit_clock)
    {
        return excluded(MISSING_HORIZON_EXCLUSION);
    }
    let entry = future[0].open;
    EventObservation {
        bar_number: current.number,
        forward_return: Some(future.last().expect("future is nonempty").close / entry - 1.0),
        mfe: Some(
            future
                .iter()
                .map(|bar| bar.high / entry - 1.0)
                .fold(f64::NEG_INFINITY, f64::max),
        ),
        mae: Some(
            future
                .iter()
                .map(|bar| bar.low / entry - 1.0)
                .fold(f64::INFINITY, f64::min),
        ),
        label_exclusion_reason: None,
    }
}

fn statistical_dislocation_matched(bars: &[FiveMinuteBar], direction: TurnDirection) -> bool {
    if bars.len() < MINIMUM_DISLOCATION_PRIOR_DISTANCES + 1 {
        return false;
    }
    let latest = &bars[bars.len() - 1];
    let previous = &bars[bars.len() - 2];
    let prior_vwap_distances = bars[..bars.len() - 1]
        .iter()
        .map(|bar| bar.close / bar.session_vwap - 1.0)
        .filter(|value| value.is_finite())
        .collect::<Vec<_>>();
    if prior_vwap_distances.len() < MINIMUM_DISLOCATION_PRIOR_DISTANCES {
        return false;
    }
    let mean = prior_vwap_distances.iter().sum::<f64>() / prior_vwap_distances.len() as f64;
    let variance = prior_vwap_distances
        .iter()
        .map(|value| (value - mean).powi(2))
        .sum::<f64>()
        / prior_vwap_distances.len() as f64;
    let two_sigma = 2.0 * variance.sqrt();
    let distance_from_vwap = latest.close / latest.session_vwap - 1.0;
    match direction {
        TurnDirection::Down => {
            distance_from_vwap <= -0.0015
                && distance_from_vwap <= mean - two_sigma
                && latest.close < latest.open
                && latest.close < previous.close
        }
        TurnDirection::Up => {
            distance_from_vwap >= 0.0015
                && distance_from_vwap >= mean + two_sigma
                && latest.close > latest.open
                && latest.close > previous.close
        }
    }
}

fn quantile(values: &[f64], probability: f64) -> Option<f64> {
    if values.is_empty() || !probability.is_finite() {
        return None;
    }
    let mut sorted = values
        .iter()
        .copied()
        .filter(|value| value.is_finite())
        .collect::<Vec<_>>();
    if sorted.is_empty() {
        return None;
    }
    sorted.sort_by(f64::total_cmp);
    let position = probability.clamp(0.0, 1.0) * (sorted.len() - 1) as f64;
    let lower = position.floor() as usize;
    let upper = position.ceil() as usize;
    if lower == upper {
        Some(sorted[lower])
    } else {
        let weight = position - lower as f64;
        Some(sorted[lower] * (1.0 - weight) + sorted[upper] * weight)
    }
}

fn bar_clock_et(bar_number: f64) -> String {
    let rounded = bar_number.round().max(1.0) as i64;
    let start_minutes = 570 + (rounded - 1) * 5;
    format!(
        "{:02}:{:02}-{:02}:{:02}",
        start_minutes / 60,
        start_minutes % 60,
        (start_minutes + 5) / 60,
        (start_minutes + 5) % 60
    )
}

pub fn historical_setup_stats(
    bars_path: &Path,
    symbol: &str,
    setup_type: MarketSetupType,
    direction: TurnDirection,
    horizon_minutes: usize,
    cutoff: Option<DateTime<Utc>>,
    assumed_round_trip_cost_bps: f64,
) -> Result<HistoricalSetupStats> {
    if !matches!(
        setup_type,
        MarketSetupType::OpeningTurn
            | MarketSetupType::VwapReversal
            | MarketSetupType::Momentum
            | MarketSetupType::StatisticalDislocation
    ) {
        bail!("historical setup method is not implemented for {setup_type:?}");
    }
    if !assumed_round_trip_cost_bps.is_finite() || assumed_round_trip_cost_bps < 0.0 {
        bail!("assumed round-trip cost must be finite and nonnegative");
    }
    let HistoricalSessionLoad {
        sessions,
        sources,
        manifest_hash,
        dataset_start,
        dataset_end,
        integrity: session_integrity,
    } = load_regular_sessions(bars_path, symbol, cutoff)?;
    let mut observations = Vec::new();
    let eligible_minute_rows = sessions.values().map(Vec::len).sum::<usize>();
    let authorized_vendor_vwap_rows = sessions
        .values()
        .flatten()
        .filter(|row| row.vendor_vwap_authorized && row.vendor_vwap.is_some())
        .count();
    let reported_but_unauthorized_vendor_vwap_rows = sessions
        .values()
        .flatten()
        .filter(|row| !row.vendor_vwap_authorized && row.vendor_vwap.is_some())
        .count();
    let mut sessions_using_authorized_vendor_vwap = 0_usize;
    let mut sessions_using_reconstructed_proxy = 0_usize;
    let mut absolute_parity_bps = Vec::new();
    for rows in sessions.values() {
        let aggregated = aggregate_five_minutes(rows)?;
        if aggregated.bars.len() != REGULAR_SESSION_MINUTES / 5 {
            bail!("complete historical session did not produce 78 exact five-minute bars");
        }
        match aggregated.vwap_method {
            SessionVwapMethod::AuthorizedVendorMinuteVwap => {
                sessions_using_authorized_vendor_vwap += 1;
                absolute_parity_bps.extend(aggregated.absolute_parity_bps);
            }
            SessionVwapMethod::ReconstructedCloseVolumeProxy => {
                sessions_using_reconstructed_proxy += 1;
            }
        }
        if let Some(event) = detect_event(&aggregated.bars, setup_type, direction, horizon_minutes)
        {
            observations.push(event);
        }
    }
    let event_bars = observations
        .iter()
        .map(|row| row.bar_number as f64)
        .collect::<Vec<_>>();
    let forward = observations
        .iter()
        .filter_map(|row| row.forward_return)
        .collect::<Vec<_>>();
    let mfe = observations
        .iter()
        .filter_map(|row| row.mfe)
        .collect::<Vec<_>>();
    let mae = observations
        .iter()
        .filter_map(|row| row.mae)
        .collect::<Vec<_>>();
    let mut event_exclusion_counts = BTreeMap::<String, usize>::new();
    for reason in observations
        .iter()
        .filter_map(|row| row.label_exclusion_reason.as_deref())
    {
        *event_exclusion_counts
            .entry(reason.to_string())
            .or_default() += 1;
    }
    let label_integrity = HistoricalLabelIntegrity {
        detected_events: observations.len(),
        completed_labels: forward.len(),
        excluded_events: observations.len().saturating_sub(forward.len()),
        event_exclusion_counts,
    };
    let vwap_status = HistoricalVwapStatus {
        policy: HISTORICAL_VWAP_POLICY.to_string(),
        eligible_minute_rows,
        authorized_vendor_vwap_rows,
        reported_but_unauthorized_vendor_vwap_rows,
        authorized_vendor_minute_coverage: if eligible_minute_rows == 0 {
            0.0
        } else {
            authorized_vendor_vwap_rows as f64 / eligible_minute_rows as f64
        },
        sessions_using_authorized_vendor_vwap,
        sessions_using_reconstructed_proxy,
        parity_observations: absolute_parity_bps.len(),
        median_absolute_parity_bps: quantile(&absolute_parity_bps, 0.50),
        maximum_absolute_parity_bps: absolute_parity_bps.iter().copied().max_by(f64::total_cmp),
    };
    let direction_multiplier = match direction {
        TurnDirection::Down => -1.0,
        TurnDirection::Up => 1.0,
    };
    let cost_return = assumed_round_trip_cost_bps / 10_000.0;
    let net_returns = forward
        .iter()
        .map(|value| direction_multiplier * value - cost_return)
        .collect::<Vec<_>>();
    let net_win_rate = (!net_returns.is_empty()).then(|| {
        net_returns.iter().filter(|value| **value > 0.0).count() as f64 / net_returns.len() as f64
    });
    let mean_net_return = (!net_returns.is_empty())
        .then(|| net_returns.iter().sum::<f64>() / net_returns.len() as f64);
    let median_net_return = quantile(&net_returns, 0.50);
    let mut equity = 1.0_f64;
    let mut peak = 1.0_f64;
    let mut worst_drawdown = 0.0_f64;
    for value in &net_returns {
        equity *= 1.0 + value;
        peak = peak.max(equity);
        if peak > 0.0 {
            worst_drawdown = worst_drawdown.min(equity / peak - 1.0);
        }
    }
    let cumulative_net_return = (!net_returns.is_empty()).then_some(equity - 1.0);
    let (edge_classification, edge_classification_detail) = classify_historical_edge(
        forward.len(),
        mean_net_return,
        median_net_return,
        cumulative_net_return,
    );
    let mut bar_counts = BTreeMap::<usize, usize>::new();
    for event in &observations {
        *bar_counts.entry(event.bar_number).or_default() += 1;
    }
    let mut top_event_bars = bar_counts.into_iter().collect::<Vec<_>>();
    top_event_bars.sort_by(|left, right| right.1.cmp(&left.1).then_with(|| left.0.cmp(&right.0)));
    let top_event_bars = top_event_bars
        .into_iter()
        .take(10)
        .map(|(bar_number, count)| {
            json!({
                "bar_number":bar_number,
                "clock_et":bar_clock_et(bar_number as f64),
                "count":count,
                "share_of_events":count as f64 / observations.len().max(1) as f64
            })
        })
        .collect();
    let direction_frequency = if forward.is_empty() {
        None
    } else {
        Some(
            forward
                .iter()
                .filter(|value| match direction {
                    TurnDirection::Down => **value < 0.0,
                    TurnDirection::Up => **value > 0.0,
                })
                .count() as f64
                / forward.len() as f64,
        )
    };
    let median_bar = quantile(&event_bars, 0.50);
    Ok(HistoricalSetupStats {
        symbol: symbol.to_string(),
        setup_type,
        method_version: match setup_type {
            MarketSetupType::OpeningTurn => OPENING_EXHAUSTION_METHOD_VERSION,
            MarketSetupType::VwapReversal => VWAP_REVERSAL_METHOD_VERSION,
            MarketSetupType::Momentum => MOMENTUM_METHOD_VERSION,
            MarketSetupType::StatisticalDislocation => {
                STATISTICAL_DISLOCATION_METHOD_VERSION
            }
            _ => unreachable!(),
        }
        .to_string(),
        event_definition: match (setup_type, direction) {
            (MarketSetupType::OpeningTurn, TurnDirection::Down) =>
                "First completed 5-minute bar in the first two hours that follows measurable upside progress, closes bearish below the prior close, fails to extend the session high, and closes below causal session VWAP or the prior low.",
            (MarketSetupType::OpeningTurn, TurnDirection::Up) =>
                "First completed 5-minute bar in the first two hours that follows measurable downside progress, closes bullish above the prior close, fails to extend the session low, and closes above causal session VWAP or the prior high.",
            (MarketSetupType::VwapReversal, TurnDirection::Down) =>
                "First completed 5-minute bearish cross from at/above the causally accumulated session VWAP to below it.",
            (MarketSetupType::VwapReversal, TurnDirection::Up) =>
                "First completed 5-minute bullish cross from at/below the causally accumulated session VWAP to above it.",
            (MarketSetupType::Momentum, TurnDirection::Down) =>
                "First completed 5-minute bar whose causal multi-bar window clears the direction, return, session-VWAP, and volume-confirmation rules for downside momentum.",
            (MarketSetupType::Momentum, TurnDirection::Up) =>
                "First completed 5-minute bar whose causal multi-bar window clears the direction, return, session-VWAP, and volume-confirmation rules for upside momentum.",
            (MarketSetupType::StatisticalDislocation, TurnDirection::Down) =>
                "First completed bearish 5-minute bar at least 15 bps below causal session VWAP and at least two standard deviations below the mean of 12 or more prior same-session VWAP distances.",
            (MarketSetupType::StatisticalDislocation, TurnDirection::Up) =>
                "First completed bullish 5-minute bar at least 15 bps above causal session VWAP and at least two standard deviations above the mean of 12 or more prior same-session VWAP distances.",
            _ => unreachable!(),
        }.to_string(),
        source: sources.into_iter().collect::<Vec<_>>().join("+"),
        dataset_start,
        dataset_end,
        sessions: sessions.len(),
        event_sessions: observations.len(),
        event_rate: (!sessions.is_empty()).then(|| observations.len() as f64 / sessions.len() as f64),
        event_bar_q25: quantile(&event_bars, 0.25),
        event_bar_median: median_bar,
        event_bar_q75: quantile(&event_bars, 0.75),
        median_clock_et: median_bar.map(bar_clock_et),
        top_event_bars,
        forward_label_minutes: horizon_minutes,
        completed_backtests: forward.len(),
        session_integrity,
        label_integrity,
        vwap_status,
        entry_semantics:
            "Hypothetical entry at the next exact exchange-clock 5-minute interval open after the causal signal; exit only at the exact requested exchange-clock horizon after a fully contiguous forward window."
                .to_string(),
        assumed_round_trip_cost_bps,
        raw_forward_direction_frequency: direction_frequency,
        median_forward_return: quantile(&forward, 0.50),
        forward_return_q05: quantile(&forward, 0.05),
        forward_return_q95: quantile(&forward, 0.95),
        median_mfe: quantile(&mfe, 0.50),
        median_mae: quantile(&mae, 0.50),
        net_win_rate,
        mean_net_return,
        median_net_return,
        cumulative_net_return,
        max_drawdown: (!net_returns.is_empty()).then_some(worst_drawdown),
        edge_classification,
        edge_classification_detail: edge_classification_detail.to_string(),
        performance_scope:
            "HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE".to_string(),
        data_manifest_hash: manifest_hash,
        evidence_grade: "CONTAMINATED_EXPLORATORY_DESCRIPTIVE".to_string(),
        caveats: vec![
            "The event rule is causal at the completed-bar timestamp; the forward return, MFE, and MAE are exact-clock evaluation labels only, and detected events without a complete horizon remain counted with an explicit exclusion reason.".to_string(),
            "Incomplete regular sessions are excluded and counted by reason. Exact duplicate rows are deduplicated and counted; malformed or conflicting target rows fail closed.".to_string(),
            "Authorized minute VWAP is used only when every minute in a session has an authorized value. Otherwise the entire session uses a disclosed close-times-volume proxy; vendor and proxy values are never mixed within a session.".to_string(),
            "Backtest entries use the next exact five-minute interval open and subtract the configured round-trip spread and slippage assumption; commissions, borrow, taxes, market impact, and capacity are not modeled.".to_string(),
            "This is a deterministic historical condition replay on data also available during research. It is not the frozen model's result, not a calibrated probability, and not an untouched out-of-sample result.".to_string(),
            "SPY is a tradable proxy for broad US equity direction; it is not SPX index volume.".to_string(),
        ],
    })
}

type EligibleLiveBar = (MarketBar, DateTime<Utc>, String, String);

fn live_bar_from_value_result(
    value: &Value,
    maximum_databento_lag_ms: i64,
) -> std::result::Result<EligibleLiveBar, String> {
    let provider_hint = value
        .get("provider")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let schema_hint = value
        .get("schema_version")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let is_databento = provider_hint.eq_ignore_ascii_case("databento")
        || schema_hint.to_ascii_lowercase().starts_with("databento_")
        || value.get("dataset").is_some();
    if is_databento {
        let envelope = serde_json::from_value::<DatabentoRealtimeBarEnvelope>(value.clone())
            .map_err(|_| "DATABENTO_ENVELOPE_MALFORMED".to_string())?;
        if let Some(reason) = realtime_envelope_rejection(&envelope, maximum_databento_lag_ms) {
            return Err(reason);
        }
        return Ok((
            envelope.bar,
            envelope.finalized_at,
            envelope.provider,
            envelope.entitlement,
        ));
    }
    let is_massive = provider_hint.eq_ignore_ascii_case("massive")
        || schema_hint.to_ascii_lowercase().starts_with("massive_");
    if is_massive {
        let envelope = serde_json::from_value::<RealtimeMarketBarEnvelope>(value.clone())
            .map_err(|_| "MASSIVE_ENVELOPE_MALFORMED".to_string())?;
        if envelope.delayed
            || envelope.stale
            || !envelope
                .entitlement
                .to_ascii_uppercase()
                .contains("REALTIME")
        {
            return Err("MASSIVE_REALTIME_ENTITLEMENT_GATE_REJECTED".to_string());
        }
        return Ok((
            envelope.bar,
            envelope.finalized_at,
            envelope.provider,
            envelope.entitlement,
        ));
    }
    if value.get("symbol").is_some() || value.get("gap_status").is_some() {
        let finalized = serde_json::from_value::<FinalizedLiveBar>(value.clone())
            .map_err(|_| "MOOMOO_FINALIZED_BAR_MALFORMED".to_string())?;
        if !finalized.is_final
            || finalized.gap_status != "COMPLETE"
            || finalized.update.is_cached_push
            || finalized.update.is_replay
            || !finalized.update.validate()
            || finalized.finalized_timestamp < finalized.update.bar_end
            || finalized.finalized_timestamp < finalized.update.available_timestamp
        {
            return Err("MOOMOO_FINALIZED_BAR_GATE_REJECTED".to_string());
        }
        return Ok((
            finalized.as_market_bar(),
            finalized.finalized_timestamp,
            finalized.update.source_version,
            "NASDAQ_BASIC_NON_CONSOLIDATED".to_string(),
        ));
    }
    Err("LIVE_BAR_ENVELOPE_MALFORMED_OR_UNSUPPORTED".to_string())
}

#[cfg(test)]
fn live_bar_from_value(value: &Value, maximum_databento_lag_ms: i64) -> Option<EligibleLiveBar> {
    live_bar_from_value_result(value, maximum_databento_lag_ms).ok()
}

fn live_record_symbol(value: &Value) -> Option<&str> {
    value
        .pointer("/bar/symbol")
        .and_then(Value::as_str)
        .or_else(|| value.get("symbol").and_then(Value::as_str))
        .or_else(|| value.pointer("/update/symbol").and_then(Value::as_str))
}

fn live_symbols_match(left: &str, right: &str) -> bool {
    left.trim()
        .trim_start_matches("US.")
        .eq_ignore_ascii_case(right.trim().trim_start_matches("US."))
}

fn vendor_vwap_is_authorized(entitlement: &str) -> bool {
    let entitlement = entitlement.trim().to_ascii_uppercase();
    matches!(
        entitlement.as_str(),
        "REALTIME_SUBSCRIPTION_ACKNOWLEDGED"
            | "REALTIME_AUTHENTICATED"
            | "NASDAQ_SIP_REALTIME"
            | "LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED"
    ) || entitlement.starts_with("LICENSED_")
}

pub fn live_vwap_candidate(
    path: &Path,
    query: &MarketQuery,
    symbol: &str,
    now: DateTime<Utc>,
    maximum_databento_lag_ms: i64,
) -> std::result::Result<ResearchCandidate, String> {
    let direction = query
        .filters
        .direction
        .ok_or_else(|| "EXPLICIT_SETUP_DIRECTION_REQUIRED".to_string())?;
    let horizon_minutes = query
        .horizon_minutes
        .ok_or_else(|| "EXPLICIT_SETUP_HORIZON_REQUIRED".to_string())?;
    let text = fs::read_to_string(path)
        .map_err(|error| format!("LIVE_BAR_ARTIFACT_UNAVAILABLE:{error}"))?;
    let mut rows = Vec::<EligibleLiveBar>::new();
    let mut latest_relevant_outcome = None::<std::result::Result<(), String>>;
    for (line_index, line) in text.lines().enumerate() {
        if line.trim().is_empty() {
            continue;
        }
        let value = match serde_json::from_str::<Value>(line) {
            Ok(value) => value,
            Err(_) => {
                latest_relevant_outcome = Some(Err(format!(
                    "LIVE_BAR_ARTIFACT_TAIL_MALFORMED:line={}",
                    line_index + 1
                )));
                continue;
            }
        };
        let symbol_hint = live_record_symbol(&value);
        if symbol_hint.is_some_and(|value| !live_symbols_match(value, symbol)) {
            continue;
        }
        match live_bar_from_value_result(&value, maximum_databento_lag_ms) {
            Ok(row) if live_symbols_match(&row.0.symbol, symbol) => {
                if row.0.timestamp > now || row.1 > now {
                    latest_relevant_outcome = Some(Err(
                        "NEWEST_REQUESTED_SYMBOL_RECORD_REJECTED:FUTURE_LIVE_BAR".to_string(),
                    ));
                } else {
                    latest_relevant_outcome = Some(Ok(()));
                    rows.push(row);
                }
            }
            Ok(_) => {}
            Err(reason) if symbol_hint.is_some() => {
                latest_relevant_outcome = Some(Err(format!(
                    "NEWEST_REQUESTED_SYMBOL_RECORD_REJECTED:{reason}"
                )));
            }
            Err(reason) => {
                latest_relevant_outcome = Some(Err(format!(
                    "LIVE_BAR_ARTIFACT_TAIL_MALFORMED:line={}:{}",
                    line_index + 1,
                    reason
                )));
            }
        }
    }
    if let Some(Err(reason)) = latest_relevant_outcome {
        return Err(reason);
    }
    rows.sort_by_key(|row| row.0.timestamp);
    let Some((latest_minute, _, _, _)) = rows.last() else {
        return Err("NO_ELIGIBLE_REALTIME_FINALIZED_BARS".to_string());
    };
    let latest_date = latest_minute
        .timestamp
        .with_timezone(&New_York)
        .date_naive();
    let mut session = rows
        .into_iter()
        .filter(|row| {
            let local = row.0.timestamp.with_timezone(&New_York);
            let minute = local.hour() * 60 + local.minute();
            local.date_naive() == latest_date && (570..960).contains(&minute)
        })
        .collect::<Vec<_>>();
    session.sort_by_key(|row| row.0.timestamp);
    let minute_rows = session
        .iter()
        .map(|(bar, _, _, row_entitlement)| {
            let local = bar.timestamp.with_timezone(&New_York);
            MinuteBar {
                interval_start: bar.timestamp,
                interval_end: bar.timestamp + chrono::Duration::minutes(1),
                minute_from_open: (local.hour() * 60 + local.minute()) as i32 - 570,
                open: bar.open,
                high: bar.high,
                low: bar.low,
                close: bar.close,
                volume: bar.volume,
                vendor_vwap: bar.vwap,
                vendor_vwap_authorized: vendor_vwap_is_authorized(row_entitlement),
                source: bar.source.clone(),
                data_quality: bar.data_quality.clone(),
            }
        })
        .collect::<Vec<_>>();
    let aggregated = aggregate_five_minutes(&minute_rows)
        .map_err(|error| format!("INVALID_EXCHANGE_CLOCK_MINUTE_SEQUENCE:{error}"))?;
    let vwap_method = aggregated.vwap_method;
    let bars = aggregated.bars;
    let Some(latest) = bars.last() else {
        return Err("AWAITING_FIRST_COMPLETE_FIVE_MINUTE_BAR".to_string());
    };
    let observation_cutoff = latest.interval_end;
    let Some((_, latest_available_at, provider, entitlement)) = session
        .iter()
        .filter(|row| row.0.timestamp + chrono::Duration::minutes(1) == observation_cutoff)
        .max_by_key(|row| row.1)
        .cloned()
    else {
        return Err("LATEST_COMPLETED_FIVE_MINUTE_SOURCE_CLOCK_MISSING".to_string());
    };
    if latest_available_at < observation_cutoff {
        return Err("LATEST_COMPLETED_FIVE_MINUTE_AVAILABILITY_PRECEDES_CUTOFF".to_string());
    }
    let age_seconds = now.signed_duration_since(latest_available_at).num_seconds();
    if age_seconds < 0 || age_seconds > query.filters.max_data_age_seconds {
        return Err(format!(
            "STALE_OR_FUTURE_LIVE_BAR:age_seconds={age_seconds}:maximum={}",
            query.filters.max_data_age_seconds
        ));
    }
    let previous = bars.get(bars.len().saturating_sub(2));
    let distance_vwap = latest.close / latest.session_vwap - 1.0;
    let five_minute_return = latest.close / latest.open - 1.0;
    let momentum = momentum_observation(&bars, direction, horizon_minutes);
    let matched = match (query.setup_type, direction, previous) {
        (MarketSetupType::Momentum, _, _) => {
            momentum.is_some_and(|observation| observation.matched)
        }
        (MarketSetupType::VwapReversal, TurnDirection::Down, Some(previous)) => {
            previous.close >= previous.session_vwap
                && latest.close < latest.session_vwap
                && latest.close < latest.open
        }
        (MarketSetupType::VwapReversal, TurnDirection::Up, Some(previous)) => {
            previous.close <= previous.session_vwap
                && latest.close > latest.session_vwap
                && latest.close > latest.open
        }
        (MarketSetupType::OpeningTurn, _, _) => detect_event(
            &bars,
            MarketSetupType::OpeningTurn,
            direction,
            horizon_minutes,
        )
        .is_some_and(|event| event.bar_number == latest.number),
        _ => false,
    };
    let condition = if matched {
        "TRIGGERED_ON_LATEST_COMPLETED_BAR"
    } else {
        "NOT_TRIGGERED_ON_LATEST_COMPLETED_BAR"
    };
    let mut supporting = vec![
        EvidenceItem {
            code: "FINALIZED_5M_BAR".to_string(),
            statement: format!(
                "Latest completed bar is number {} ({})",
                latest.number,
                bar_clock_et(latest.number as f64)
            ),
            observed_value: Some(json!(latest.number)),
        },
        EvidenceItem {
            code: "CAUSAL_SESSION_VWAP".to_string(),
            statement: format!(
                "Session VWAP uses only finalized minute bars available through the cutoff; method={}.",
                vwap_method.as_str()
            ),
            observed_value: Some(json!({
                "value":latest.session_vwap,
                "method":vwap_method.as_str()
            })),
        },
    ];
    let mut contrary = Vec::new();
    if query.setup_type == MarketSetupType::Momentum {
        if let Some(observation) = momentum {
            supporting.push(EvidenceItem {
                code: "CAUSAL_MOMENTUM_WINDOW".to_string(),
                statement: format!(
                    "{} finalized five-minute bars were evaluated for directional persistence.",
                    observation.lookback_bars
                ),
                observed_value: Some(json!({
                    "method_version":MOMENTUM_METHOD_VERSION,
                    "lookback_bars":observation.lookback_bars,
                    "cumulative_return":observation.cumulative_return,
                    "directional_bars":observation.directional_bars,
                    "recent_volume_ratio":observation.recent_volume_ratio,
                    "threshold_return":observation.threshold_return
                })),
            });
        } else {
            contrary.push(EvidenceItem {
                code: "INSUFFICIENT_FINALIZED_MOMENTUM_BARS".to_string(),
                statement:
                    "The session does not yet contain the configured causal momentum window."
                        .to_string(),
                observed_value: None,
            });
        }
    }
    if matched {
        supporting.push(EvidenceItem {
            code: "SETUP_RULE_MATCH".to_string(),
            statement: "The configured completed-bar rule is satisfied.".to_string(),
            observed_value: Some(json!(true)),
        });
    } else {
        contrary.push(EvidenceItem {
            code: "SETUP_RULE_NOT_MATCHED".to_string(),
            statement: "The configured completed-bar rule is not satisfied on the latest bar."
                .to_string(),
            observed_value: Some(json!(false)),
        });
    }
    if !entitlement.to_ascii_uppercase().contains("SIP") {
        contrary.push(EvidenceItem {
            code: "NON_CONSOLIDATED_EQUITY_FEED".to_string(),
            statement: "The equity feed is realtime but is not verified as consolidated SIP NBBO."
                .to_string(),
            observed_value: Some(json!(entitlement)),
        });
    }
    Ok(ResearchCandidate {
        symbol: symbol.to_string(),
        setup_type: query.setup_type,
        status: condition.to_string(),
        heuristic_structure_score: None,
        score_semantics: "No composite score is emitted for a deterministic bar-rule state."
            .to_string(),
        supporting_evidence: supporting,
        contrary_evidence: contrary,
        metrics: json!({
            "bar_number":latest.number,
            "clock_et":bar_clock_et(latest.number as f64),
            "open":latest.open,
            "high":latest.high,
            "low":latest.low,
            "close":latest.close,
            "session_vwap":latest.session_vwap,
            "session_vwap_method":latest.session_vwap_method.as_str(),
            "distance_from_vwap":distance_vwap,
            "five_minute_return":five_minute_return,
            "momentum_method_version":(query.setup_type == MarketSetupType::Momentum)
                .then_some(MOMENTUM_METHOD_VERSION),
            "momentum_lookback_bars":momentum.map(|value| value.lookback_bars),
            "momentum_cumulative_return":momentum.map(|value| value.cumulative_return),
            "momentum_directional_bars":momentum.map(|value| value.directional_bars),
            "momentum_recent_volume_ratio":momentum.and_then(|value| value.recent_volume_ratio),
            "momentum_threshold_return":momentum.map(|value| value.threshold_return),
            "observation_cutoff":observation_cutoff,
            "rule_state":condition
        }),
        freshness: vec![DataFreshness {
            source: provider,
            observed_at: Some(observation_cutoff),
            available_at: Some(latest_available_at),
            age_seconds: Some(age_seconds),
            realtime: true,
            entitlement,
            coverage: Some(1.0),
        }],
    })
}

fn median(values: &mut [f64]) -> Option<f64> {
    values.sort_by(f64::total_cmp);
    quantile(values, 0.50)
}

pub fn gamma_structure_candidate(
    path: &Path,
    query: &MarketQuery,
    symbol: &str,
    now: DateTime<Utc>,
    configured_minimum_quote_coverage: f64,
) -> std::result::Result<ResearchCandidate, String> {
    if !path.exists() {
        return Err("FULL_OPRA_CHAIN_ARTIFACT_ABSENT".to_string());
    }
    let bytes =
        fs::read(path).map_err(|error| format!("OPTION_CHAIN_ARTIFACT_UNAVAILABLE:{error}"))?;
    let snapshot = serde_json::from_slice::<MassiveFullOptionChain>(&bytes)
        .map_err(|error| format!("OPTION_CHAIN_ARTIFACT_INVALID:{error}"))?;
    if snapshot.schema_version != OPTION_CHAIN_SCHEMA_VERSION {
        return Err("OPTION_CHAIN_SCHEMA_INCOMPATIBLE".to_string());
    }
    let observed_hash = sha256_hex(
        &serde_json::to_vec(&snapshot.contracts)
            .map_err(|error| format!("OPTION_CHAIN_HASH_SERIALIZATION_FAILED:{error}"))?,
    );
    if observed_hash != snapshot.contracts_sha256 {
        return Err("OPTION_CHAIN_ARTIFACT_HASH_MISMATCH".to_string());
    }
    if !snapshot.chain_complete || !snapshot.model_ready {
        return Err(format!(
            "OPTION_CHAIN_NOT_MODEL_READY:{}",
            snapshot.blockers.join("|")
        ));
    }
    let age_seconds = now
        .signed_duration_since(snapshot.captured_at)
        .num_seconds();
    if age_seconds < 0 || age_seconds > query.filters.max_data_age_seconds {
        return Err(format!(
            "STALE_OR_FUTURE_OPTION_CHAIN:age_seconds={age_seconds}:maximum={}",
            query.filters.max_data_age_seconds
        ));
    }
    let required_coverage = query
        .filters
        .minimum_option_quote_coverage
        .unwrap_or(configured_minimum_quote_coverage);
    if snapshot.coverage.fresh_quote_coverage < required_coverage {
        return Err(format!(
            "OPTION_QUOTE_COVERAGE_BELOW_REQUIREMENT:observed={}:required={required_coverage}",
            snapshot.coverage.fresh_quote_coverage
        ));
    }
    let contracts = snapshot
        .contracts
        .iter()
        .filter(|contract| (0..=query.filters.max_dte).contains(&contract.dte))
        .collect::<Vec<_>>();
    if contracts.is_empty() {
        return Err("NO_CONTRACTS_IN_REQUESTED_DTE_WINDOW".to_string());
    }
    let spot = contracts
        .iter()
        .filter_map(|contract| contract.underlying_price)
        .find(|price| price.is_finite() && *price > 0.0)
        .ok_or_else(|| "UNDERLYING_SPOT_UNAVAILABLE".to_string())?;
    let quotes = contracts
        .iter()
        .filter_map(|contract| contract.as_option_quote())
        .collect::<Vec<_>>();
    if quotes.len() != contracts.len() {
        return Err(format!(
            "INCOMPLETE_ELIGIBLE_CONTRACT_COVERAGE:eligible_quotes={}:contracts={}",
            quotes.len(),
            contracts.len()
        ));
    }
    let gamma = gamma_convexity_feedback_risk(
        &quotes,
        &GammaConvexityRequest {
            as_of: now,
            underlying: symbol.to_string(),
            spot,
            contract_multiplier: 100.0,
            oi_as_of: Some(snapshot.oi_available_at),
            greeks_as_of: Some(snapshot.greeks_available_at),
            max_quote_age_seconds: query.filters.max_data_age_seconds,
            max_oi_age_seconds: query.filters.max_data_age_seconds,
            max_greeks_age_seconds: query.filters.max_data_age_seconds,
        },
    );
    if gamma.availability != GammaConvexityAvailability::Available {
        return Err(format!(
            "GAMMA_CONVEXITY_UNAVAILABLE:{:?}",
            gamma.unavailable_reasons
        ));
    }
    let exposure = gamma
        .exposure
        .as_ref()
        .ok_or_else(|| "GAMMA_EXPOSURE_ABSENT".to_string())?;
    let atm = gamma
        .atm_distance
        .as_ref()
        .ok_or_else(|| "GAMMA_ATM_CONCENTRATION_ABSENT".to_string())?;
    let strike = gamma
        .strike_concentration
        .as_ref()
        .ok_or_else(|| "GAMMA_STRIKE_CONCENTRATION_ABSENT".to_string())?;
    let call_volume = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Call)
        .filter_map(|contract| contract.volume)
        .sum::<u64>();
    let put_volume = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Put)
        .filter_map(|contract| contract.volume)
        .sum::<u64>();
    let call_oi = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Call)
        .filter_map(|contract| contract.open_interest)
        .sum::<u64>();
    let put_oi = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Put)
        .filter_map(|contract| contract.open_interest)
        .sum::<u64>();
    let call_volume_share = call_volume as f64 / (call_volume + put_volume).max(1) as f64;
    let call_gamma_share = exposure.call_share_of_unsigned_exposure.unwrap_or(0.0);
    let near_atm_share = atm.unsigned_exposure_share_within_two_pct.unwrap_or(0.0);
    let dominant_distance = strike.dominant_strike_abs_distance_pct.unwrap_or(1.0).abs();
    let strike_proximity = (1.0 - dominant_distance / 0.10).clamp(0.0, 1.0);
    let call_volume_oi = call_volume as f64 / call_oi.max(1) as f64;
    let flow_anomaly = (call_volume_oi / 2.0).clamp(0.0, 1.0);
    let mut spreads = contracts
        .iter()
        .filter_map(|contract| {
            let bid = contract.bid?;
            let ask = contract.ask?;
            let mid = (bid + ask) * 0.5;
            (mid > 0.0 && ask >= bid).then_some((ask - bid) / mid)
        })
        .filter(|spread| spread.is_finite())
        .collect::<Vec<_>>();
    let median_spread = median(&mut spreads);
    let maximum_spread = query.filters.maximum_option_spread_pct.unwrap_or(0.15);
    let spread_quality = median_spread
        .map(|value| (1.0 - value / maximum_spread.max(1.0e-6)).clamp(0.0, 1.0))
        .unwrap_or(0.0);
    let score = 100.0
        * (0.25 * near_atm_share
            + 0.20 * call_gamma_share
            + 0.20 * call_volume_share
            + 0.15 * strike_proximity
            + 0.10 * flow_anomaly
            + 0.10 * spread_quality);
    let mut supporting = Vec::new();
    let mut contrary = Vec::new();
    let evidence = [
        (
            near_atm_share >= 0.50,
            "NEAR_ATM_GAMMA_CONCENTRATION",
            "Unsigned gamma exposure within 2% of spot",
            json!(near_atm_share),
        ),
        (
            call_gamma_share >= 0.55,
            "CALL_GAMMA_SHARE",
            "Call share of unsigned gamma exposure",
            json!(call_gamma_share),
        ),
        (
            call_volume_share >= 0.60,
            "CALL_VOLUME_SHARE",
            "Call share of observed option volume",
            json!(call_volume_share),
        ),
        (
            call_volume_oi >= 1.0,
            "CALL_VOLUME_OPEN_INTEREST",
            "Aggregate call volume/open-interest ratio",
            json!(call_volume_oi),
        ),
        (
            dominant_distance <= 0.02,
            "DOMINANT_STRIKE_PROXIMITY",
            "Dominant unsigned-gamma strike distance from spot",
            json!(dominant_distance),
        ),
    ];
    for (supports, code, statement, observed_value) in evidence {
        let item = EvidenceItem {
            code: code.to_string(),
            statement: statement.to_string(),
            observed_value: Some(observed_value),
        };
        if supports {
            supporting.push(item);
        } else {
            contrary.push(item);
        }
    }
    if median_spread.is_some_and(|spread| spread > maximum_spread) {
        contrary.push(EvidenceItem {
            code: "OPTION_SPREAD_TOO_WIDE".to_string(),
            statement: "Median option spread exceeds the configured liquidity limit.".to_string(),
            observed_value: median_spread.map(|value| json!(value)),
        });
    }
    contrary.push(EvidenceItem {
        code: "DEALER_SIGN_UNOBSERVED".to_string(),
        statement: "Open interest and public trades do not reveal dealer inventory sign."
            .to_string(),
        observed_value: None,
    });
    if query.filters.exclude_earnings_within_days.is_some() {
        contrary.push(EvidenceItem {
            code: "EARNINGS_CALENDAR_NOT_CONNECTED".to_string(),
            statement: "The requested earnings exclusion cannot be verified from the current point-in-time data contract.".to_string(),
            observed_value: query
                .filters
                .exclude_earnings_within_days
                .map(|value| json!(value)),
        });
    }
    let status = if score >= 65.0 {
        "RESEARCH_CANDIDATE"
    } else {
        "OBSERVED_STRUCTURE_BELOW_RESEARCH_THRESHOLD"
    };
    Ok(ResearchCandidate {
        symbol: symbol.to_string(),
        setup_type: MarketSetupType::GammaSqueeze,
        status: status.to_string(),
        heuristic_structure_score: Some(score),
        score_semantics: "0–100 deterministic structure score, not a probability. Weights: near-ATM unsigned gamma 25%, call unsigned-gamma share 20%, call-volume share 20%, dominant-strike proximity 15%, call volume/OI 10%, spread quality 10%.".to_string(),
        supporting_evidence: supporting,
        contrary_evidence: contrary,
        metrics: json!({
            "method_version":GAMMA_STRUCTURE_METHOD_VERSION,
            "spot":spot,
            "max_dte":query.filters.max_dte,
            "contracts":contracts.len(),
            "call_volume":call_volume,
            "put_volume":put_volume,
            "call_open_interest":call_oi,
            "put_open_interest":put_oi,
            "call_volume_share":call_volume_share,
            "call_volume_open_interest_ratio":call_volume_oi,
            "call_share_unsigned_gamma":call_gamma_share,
            "unsigned_gamma_share_within_two_pct":near_atm_share,
            "dominant_gamma_strike":strike.dominant_strike,
            "dominant_gamma_strike_distance_pct":dominant_distance,
            "median_option_spread_pct":median_spread,
            "gamma_convexity":gamma,
            "dealer_position_sign":"UNOBSERVED",
            "probability":null
        }),
        freshness: vec![
            DataFreshness {
                source: snapshot.source,
                observed_at: snapshot.latest_quote_at,
                available_at: Some(snapshot.captured_at),
                age_seconds: Some(age_seconds),
                realtime: snapshot.realtime_required,
                entitlement: "OPRA_FULL_CHAIN_REQUIRED".to_string(),
                coverage: Some(snapshot.coverage.fresh_quote_coverage),
            },
            DataFreshness {
                source: "DAILY_OPEN_INTEREST_SNAPSHOT".to_string(),
                observed_at: Some(snapshot.oi_available_at),
                available_at: Some(snapshot.oi_available_at),
                age_seconds: Some(now.signed_duration_since(snapshot.oi_available_at).num_seconds()),
                realtime: false,
                entitlement: snapshot.open_interest_semantics,
                coverage: Some(snapshot.coverage.open_interest_coverage),
            },
        ],
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::databento_live::DATABENTO_LIVE_BAR_SCHEMA_VERSION;
    use chrono::{Datelike, Duration, TimeZone};
    use std::io::Write;
    use std::sync::{LazyLock, Mutex};

    static RIGHTS_ENV_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));

    struct ScopedEnvironment {
        key: &'static str,
        prior: Option<std::ffi::OsString>,
    }

    impl ScopedEnvironment {
        fn set(key: &'static str, value: &str) -> Self {
            let prior = std::env::var_os(key);
            // SAFETY: tests that mutate this process variable hold
            // RIGHTS_ENV_LOCK for the lifetime of the guard.
            unsafe { std::env::set_var(key, value) };
            Self { key, prior }
        }
    }

    impl Drop for ScopedEnvironment {
        fn drop(&mut self) {
            // SAFETY: the same test still holds RIGHTS_ENV_LOCK while the
            // guard restores the previous process environment.
            unsafe {
                if let Some(value) = &self.prior {
                    std::env::set_var(self.key, value);
                } else {
                    std::env::remove_var(self.key);
                }
            }
        }
    }

    fn test_five_minute_bar(
        number: usize,
        open: f64,
        high: f64,
        low: f64,
        close: f64,
        volume: f64,
        session_vwap: f64,
    ) -> FiveMinuteBar {
        let session_open = Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap();
        let interval_start =
            session_open + Duration::minutes((number.saturating_sub(1) * 5) as i64);
        FiveMinuteBar {
            number,
            interval_start,
            interval_end: interval_start + Duration::minutes(5),
            open,
            high,
            low,
            close,
            volume,
            session_vwap,
            session_vwap_method: SessionVwapMethod::ReconstructedCloseVolumeProxy,
        }
    }

    fn test_minute_bar(minute_from_open: i32) -> MinuteBar {
        let session_open = Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap();
        let interval_start = session_open + Duration::minutes(i64::from(minute_from_open));
        MinuteBar {
            interval_start,
            interval_end: interval_start + Duration::minutes(1),
            minute_from_open,
            open: 100.0,
            high: 100.1,
            low: 99.9,
            close: 100.0,
            volume: 1_000.0,
            vendor_vwap: None,
            vendor_vwap_authorized: false,
            source: "TEST".to_string(),
            data_quality: "test".to_string(),
        }
    }

    fn write_historical_header(file: &mut fs::File) {
        writeln!(
            file,
            "timestamp,symbol,open,high,low,close,volume,vwap,vwap_authorized,bid,ask,trade_count,source,data_quality"
        )
        .unwrap();
    }

    #[allow(clippy::too_many_arguments)]
    fn write_historical_minute(
        file: &mut fs::File,
        timestamp: DateTime<Utc>,
        symbol: &str,
        open: f64,
        close: f64,
        volume: f64,
        vwap: Option<f64>,
        vwap_authorized: bool,
    ) {
        let vwap = vwap.map(|value| value.to_string()).unwrap_or_default();
        writeln!(
            file,
            "{timestamp},{symbol},{open},{high},{low},{close},{volume},{vwap},{vwap_authorized},,,10,DATABENTO_EQUS_MINI,licensed",
            timestamp = timestamp.to_rfc3339(),
            high = open.max(close) + 0.02,
            low = open.min(close) - 0.02,
        )
        .unwrap();
    }

    #[test]
    fn historical_edge_classification_is_conservative_and_serialized() {
        let (insufficient, insufficient_detail) = classify_historical_edge(0, None, None, None);
        assert_eq!(
            insufficient,
            HistoricalEdgeClassification::InsufficientEvidence
        );
        assert!(insufficient_detail.contains("no edge conclusion"));

        let (losing, losing_detail) =
            classify_historical_edge(80, Some(-0.0002), Some(-0.0001), Some(-0.016));
        assert_eq!(losing, HistoricalEdgeClassification::NoDemonstratedEdge);
        assert!(losing_detail.contains("lost money after the stated costs"));

        let (mixed, mixed_detail) =
            classify_historical_edge(80, Some(0.0002), Some(0.0), Some(0.016));
        assert_eq!(mixed, HistoricalEdgeClassification::NoDemonstratedEdge);
        assert!(mixed_detail.contains("non-positive"));

        let (positive, positive_detail) =
            classify_historical_edge(1, Some(0.0002), Some(0.0001), Some(0.0002));
        assert_eq!(
            positive,
            HistoricalEdgeClassification::PositiveAfterCostDescriptive
        );
        assert!(positive_detail.contains("does not establish a statistically validated edge"));
        assert_eq!(
            serde_json::to_value(positive).unwrap(),
            json!("POSITIVE_AFTER_COST_DESCRIPTIVE")
        );
    }

    fn databento_bar_value_at(bar_start: DateTime<Utc>, symbol: &str) -> Value {
        let available_at = bar_start + Duration::minutes(1) + Duration::milliseconds(250);
        serde_json::to_value(DatabentoRealtimeBarEnvelope {
            schema_version: DATABENTO_LIVE_BAR_SCHEMA_VERSION.to_string(),
            provider: "databento".to_string(),
            dataset: "EQUS.MINI".to_string(),
            provider_schema: "ohlcv-1m".to_string(),
            received_at: available_at,
            provider_available_at: available_at,
            bar_start,
            bar_end: bar_start + Duration::minutes(1),
            finalized_at: available_at,
            entitlement: "REALTIME_SUBSCRIPTION_ACKNOWLEDGED".to_string(),
            delayed: false,
            stale: false,
            replay: false,
            symbol_mapping_verified: true,
            bar: MarketBar {
                timestamp: bar_start,
                symbol: symbol.to_string(),
                open: 638.0,
                high: 638.5,
                low: 637.75,
                close: 638.25,
                volume: 10_000.0,
                vwap: None,
                bid: None,
                ask: None,
                trade_count: None,
                source: "Databento/EQUS.MINI/ohlcv-1m".to_string(),
                data_quality: "licensed_vendor_original_dbn_realtime".to_string(),
            },
            caveats: Vec::new(),
        })
        .unwrap()
    }

    fn databento_bar_value() -> Value {
        databento_bar_value_at(Utc.with_ymd_and_hms(2026, 7, 27, 13, 30, 0).unwrap(), "SPY")
    }

    fn explicit_live_query() -> MarketQuery {
        MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Scan,
            setup_type: MarketSetupType::Momentum,
            symbols: vec!["SPY".to_string()],
            horizon_minutes: Some(5),
            limit: 1,
            as_of: None,
            filters: MarketQueryFilters {
                direction: Some(TurnDirection::Down),
                include_historical: false,
                max_data_age_seconds: 300,
                ..MarketQueryFilters::default()
            },
        }
    }

    fn write_live_databento_minutes(
        file: &mut fs::File,
        session_open: DateTime<Utc>,
        minute_count: usize,
    ) {
        for minute in 0..minute_count {
            writeln!(
                file,
                "{}",
                databento_bar_value_at(session_open + Duration::minutes(minute as i64), "SPY")
            )
            .unwrap();
        }
    }

    #[test]
    fn live_bar_accepts_strict_databento_realtime_envelope() {
        let value = databento_bar_value();
        let (bar, available_at, provider, entitlement) =
            live_bar_from_value(&value, 10_000).expect("eligible Databento bar");

        assert_eq!(bar.symbol, "SPY");
        assert_eq!(
            bar.timestamp,
            value["bar_start"]
                .as_str()
                .unwrap()
                .parse::<DateTime<Utc>>()
                .unwrap()
        );
        assert_eq!(
            available_at,
            value["finalized_at"]
                .as_str()
                .unwrap()
                .parse::<DateTime<Utc>>()
                .unwrap()
        );
        assert_eq!(provider, "databento");
        assert_eq!(entitlement, "REALTIME_SUBSCRIPTION_ACKNOWLEDGED");
    }

    #[test]
    fn live_bar_rejects_each_databento_identity_and_entitlement_violation() {
        let violations = [
            ("schema_version", json!("databento_ohlcv_1m.v0")),
            ("provider", json!("massive")),
            ("dataset", json!("EQUS.PLUS")),
            ("provider_schema", json!("trades")),
            ("entitlement", json!("REALTIME")),
            ("replay", json!(true)),
            ("delayed", json!(true)),
            ("stale", json!(true)),
            ("symbol_mapping_verified", json!(false)),
        ];

        for (field, invalid_value) in violations {
            let mut value = databento_bar_value();
            value[field] = invalid_value;
            assert!(
                live_bar_from_value(&value, 10_000).is_none(),
                "Databento safety field {field} must fail closed"
            );
        }
    }

    #[test]
    fn live_bar_rejects_invalid_databento_interval_and_bar_payload() {
        let mut wrong_interval = databento_bar_value();
        let start: DateTime<Utc> = wrong_interval["bar_start"]
            .as_str()
            .unwrap()
            .parse()
            .unwrap();
        wrong_interval["bar_end"] = json!(start + Duration::seconds(59));
        assert!(live_bar_from_value(&wrong_interval, 10_000).is_none());

        let mut mismatched_timestamp = databento_bar_value();
        mismatched_timestamp["bar"]["timestamp"] = json!(start + Duration::minutes(1));
        assert!(live_bar_from_value(&mismatched_timestamp, 10_000).is_none());

        let mut invalid_numeric_bar = databento_bar_value();
        invalid_numeric_bar["bar"]["high"] = json!(637.0);
        assert!(live_bar_from_value(&invalid_numeric_bar, 10_000).is_none());

        let mut wrong_source = databento_bar_value();
        wrong_source["bar"]["source"] = json!("Databento/EQUS.FULL/ohlcv-1m");
        assert!(live_bar_from_value(&wrong_source, 10_000).is_none());

        let mut wrong_quality = databento_bar_value();
        wrong_quality["bar"]["data_quality"] = json!("licensed_vendor_original_dbn_stale");
        assert!(live_bar_from_value(&wrong_quality, 10_000).is_none());
    }

    #[test]
    fn live_bar_rejects_each_noncausal_databento_availability_clock() {
        let valid = databento_bar_value();
        let bar_end: DateTime<Utc> = valid["bar_end"].as_str().unwrap().parse().unwrap();
        let available_at: DateTime<Utc> = valid["provider_available_at"]
            .as_str()
            .unwrap()
            .parse()
            .unwrap();

        let mut available_before_close = valid.clone();
        let noncausal = bar_end - Duration::milliseconds(1);
        available_before_close["provider_available_at"] = json!(noncausal);
        available_before_close["received_at"] = json!(noncausal);
        available_before_close["finalized_at"] = json!(noncausal);
        assert!(live_bar_from_value(&available_before_close, 10_000).is_none());

        let mut excessive_lag = valid.clone();
        let late = bar_end + Duration::milliseconds(10_001);
        excessive_lag["provider_available_at"] = json!(late);
        excessive_lag["received_at"] = json!(late);
        excessive_lag["finalized_at"] = json!(late);
        assert!(live_bar_from_value(&excessive_lag, 10_000).is_none());

        let mut receipt_clock_mismatch = valid.clone();
        receipt_clock_mismatch["received_at"] = json!(available_at + Duration::milliseconds(1));
        assert!(live_bar_from_value(&receipt_clock_mismatch, 10_000).is_none());

        let mut finalization_clock_mismatch = valid;
        finalization_clock_mismatch["finalized_at"] =
            json!(available_at + Duration::milliseconds(1));
        assert!(live_bar_from_value(&finalization_clock_mismatch, 10_000).is_none());
    }

    #[test]
    fn live_bar_keeps_massive_and_moomoo_formats_compatible() {
        let bar_start = Utc.with_ymd_and_hms(2026, 7, 27, 13, 30, 0).unwrap();
        let bar_end = bar_start + Duration::minutes(1);
        let finalized_at = bar_end + Duration::milliseconds(250);
        let bar = MarketBar {
            timestamp: bar_start,
            symbol: "SPY".to_string(),
            open: 638.0,
            high: 638.5,
            low: 637.75,
            close: 638.25,
            volume: 10_000.0,
            vwap: None,
            bid: None,
            ask: None,
            trade_count: None,
            source: "MASSIVE_STOCKS_AGG_1M".to_string(),
            data_quality: "licensed_vendor_original_realtime".to_string(),
        };
        let massive = serde_json::to_value(RealtimeMarketBarEnvelope {
            schema_version: "massive_realtime_bar.v1".to_string(),
            provider: "massive".to_string(),
            provider_event: "AM".to_string(),
            received_at: finalized_at,
            provider_available_at: bar_end,
            bar_start,
            bar_end,
            finalized_at,
            entitlement: "NASDAQ_SIP_REALTIME".to_string(),
            delayed: false,
            stale: false,
            bar,
        })
        .unwrap();
        assert!(live_bar_from_value(&massive, 10_000).is_some());

        let moomoo = json!({
            "symbol": "US.SPY",
            "event_timestamp": bar_start,
            "receive_timestamp": finalized_at,
            "available_timestamp": finalized_at,
            "bar_start": bar_start,
            "bar_end": bar_end,
            "open": 638.0,
            "high": 638.5,
            "low": 637.75,
            "close": 638.25,
            "volume": 10_000.0,
            "turnover": 6_382_500.0,
            "session": "REGULAR",
            "source_version": "moomoo-opend-v1",
            "subscription_id": "test",
            "sequence_or_dedup_key": "test-1",
            "is_cached_push": false,
            "is_replay": false,
            "raw_payload_hash": "abc123",
            "finalized_timestamp": finalized_at,
            "is_final": true,
            "gap_status": "COMPLETE",
            "correction_of": null
        });
        assert!(live_bar_from_value(&moomoo, 10_000).is_some());
    }

    #[test]
    fn live_rule_candidate_uses_completed_bar_cutoff_and_numeric_coverage() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("live.jsonl");
        let mut file = fs::File::create(&path).unwrap();
        let session_open = Utc.with_ymd_and_hms(2026, 7, 27, 13, 30, 0).unwrap();
        // The final two minutes are valid, finalized trailing minutes. They
        // must not move the candidate beyond the most recent complete 5m bar.
        write_live_databento_minutes(&mut file, session_open, 12);
        drop(file);

        let candidate = live_vwap_candidate(
            &path,
            &explicit_live_query(),
            "SPY",
            session_open + Duration::minutes(12) + Duration::milliseconds(500),
            10_000,
        )
        .unwrap();
        let expected_cutoff = session_open + Duration::minutes(10);
        let expected_available_at = expected_cutoff + Duration::milliseconds(250);
        assert_eq!(
            candidate.metrics["observation_cutoff"],
            json!(expected_cutoff)
        );
        assert_eq!(candidate.freshness.len(), 1);
        assert_eq!(candidate.freshness[0].observed_at, Some(expected_cutoff));
        assert_eq!(
            candidate.freshness[0].available_at,
            Some(expected_available_at)
        );
        assert_eq!(candidate.freshness[0].coverage, Some(1.0));
    }

    #[test]
    fn newest_requested_live_record_rejection_blocks_older_valid_data() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("live.jsonl");
        let mut file = fs::File::create(&path).unwrap();
        let session_open = Utc.with_ymd_and_hms(2026, 7, 27, 13, 30, 0).unwrap();
        write_live_databento_minutes(&mut file, session_open, 10);
        let mut rejected = databento_bar_value_at(session_open + Duration::minutes(10), "SPY");
        rejected["entitlement"] = json!("REALTIME");
        writeln!(file, "{rejected}").unwrap();
        drop(file);

        let error = live_vwap_candidate(
            &path,
            &explicit_live_query(),
            "SPY",
            session_open + Duration::minutes(12),
            10_000,
        )
        .unwrap_err();
        assert_eq!(
            error,
            "NEWEST_REQUESTED_SYMBOL_RECORD_REJECTED:DATABENTO_REALTIME_ENTITLEMENT_GATE_REJECTED"
        );
    }

    #[test]
    fn malformed_newest_requested_live_record_fails_closed() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("live.jsonl");
        let mut file = fs::File::create(&path).unwrap();
        let session_open = Utc.with_ymd_and_hms(2026, 7, 27, 13, 30, 0).unwrap();
        write_live_databento_minutes(&mut file, session_open, 10);
        let mut malformed = databento_bar_value_at(session_open + Duration::minutes(10), "SPY");
        malformed.as_object_mut().unwrap().remove("provider_schema");
        writeln!(file, "{malformed}").unwrap();
        drop(file);

        let error = live_vwap_candidate(
            &path,
            &explicit_live_query(),
            "SPY",
            session_open + Duration::minutes(12),
            10_000,
        )
        .unwrap_err();
        assert_eq!(
            error,
            "NEWEST_REQUESTED_SYMBOL_RECORD_REJECTED:DATABENTO_ENVELOPE_MALFORMED"
        );
    }

    #[test]
    fn query_rejects_unknown_or_execution_shaped_fields() {
        let payload = json!({
            "intent":"scan",
            "setup_type":"gamma_squeeze",
            "symbols":["SPY"],
            "order":{"side":"buy"}
        });
        assert!(serde_json::from_value::<MarketQuery>(payload).is_err());
    }

    #[test]
    fn model_forecast_query_keeps_direction_and_horizon_model_owned() {
        let query = serde_json::from_value::<MarketQuery>(json!({
            "version": MARKET_QUERY_SCHEMA_VERSION,
            "intent": "forecast",
            "setup_type": "model_forecast",
            "symbols": ["spx"],
            "limit": 1,
            "filters": {
                "require_realtime": true,
                "include_historical": false,
                "max_data_age_seconds": 120,
                "max_dte": 14
            }
        }))
        .unwrap()
        .normalize_and_validate()
        .unwrap();
        assert_eq!(query.symbols, vec!["SPX"]);
        assert_eq!(query.setup_type, MarketSetupType::ModelForecast);
        assert_eq!(query.horizon_minutes, None);
        assert_eq!(query.filters.direction, None);
        assert!(!query.filters.include_historical);
        let serialized = serde_json::to_value(query).unwrap();
        assert!(serialized.get("horizon_minutes").is_none());
        assert!(serialized.pointer("/filters/direction").is_none());
    }

    #[test]
    fn v2_adds_model_forecast_while_legacy_v1_explicit_monitors_remain_valid() {
        let legacy = serde_json::from_value::<MarketQuery>(json!({
            "version": LEGACY_MARKET_QUERY_SCHEMA_VERSION,
            "intent": "scan",
            "setup_type": "opening_turn",
            "symbols": ["SPX"],
            "horizon_minutes": 5,
            "limit": 1,
            "filters": {
                "direction": "down",
                "require_realtime": true,
                "include_historical": false,
                "max_data_age_seconds": 120,
                "max_dte": 14
            }
        }))
        .unwrap()
        .normalize_and_validate()
        .unwrap();
        assert_eq!(legacy.version, LEGACY_MARKET_QUERY_SCHEMA_VERSION);

        let invalid_legacy_model = serde_json::from_value::<MarketQuery>(json!({
            "version": LEGACY_MARKET_QUERY_SCHEMA_VERSION,
            "intent": "forecast",
            "setup_type": "model_forecast",
            "symbols": ["SPX"],
            "limit": 1,
            "filters": {}
        }))
        .unwrap();
        assert!(invalid_legacy_model.normalize_and_validate().is_err());
    }

    #[test]
    fn explicit_directional_setup_rejects_implicit_direction_or_horizon() {
        let missing = serde_json::from_value::<MarketQuery>(json!({
            "version": MARKET_QUERY_SCHEMA_VERSION,
            "intent": "scan",
            "setup_type": "opening_turn",
            "symbols": ["SPX"],
            "limit": 1,
            "filters": {
                "require_realtime": true,
                "include_historical": false,
                "max_data_age_seconds": 120,
                "max_dte": 14
            }
        }))
        .unwrap();
        assert!(missing.normalize_and_validate().is_err());
    }

    #[test]
    fn query_normalization_is_deterministic() {
        let query = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Scan,
            setup_type: MarketSetupType::OpeningTurn,
            symbols: vec!["$spy".to_string(), "US.QQQ".to_string(), "SPY".to_string()],
            horizon_minutes: Some(15),
            limit: 10,
            as_of: None,
            filters: MarketQueryFilters {
                direction: Some(TurnDirection::Down),
                ..MarketQueryFilters::default()
            },
        }
        .normalize_and_validate()
        .unwrap();
        assert_eq!(query.symbols, vec!["QQQ", "SPY"]);
        assert_eq!(query.canonical_sha256().unwrap().len(), 64);
        assert_eq!(
            query.canonical_sha256().unwrap(),
            query.canonical_sha256().unwrap()
        );
    }

    #[test]
    fn live_query_rejects_client_supplied_as_of_freshness_clock() {
        let stale_cutoff = Utc.with_ymd_and_hms(2026, 7, 1, 14, 30, 0).unwrap();
        let live = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Forecast,
            setup_type: MarketSetupType::StatisticalDislocation,
            symbols: vec!["NVDA".to_string()],
            horizon_minutes: Some(15),
            limit: 1,
            as_of: Some(stale_cutoff),
            filters: MarketQueryFilters {
                direction: Some(TurnDirection::Down),
                ..MarketQueryFilters::default()
            },
        };
        assert!(live.clone().normalize_and_validate().is_err());

        let backtest = MarketQuery {
            intent: MarketQueryIntent::Backtest,
            as_of: Some(stale_cutoff),
            ..live
        };
        assert_eq!(
            backtest.normalize_and_validate().unwrap().as_of,
            Some(stale_cutoff)
        );
    }

    #[test]
    fn momentum_rule_uses_only_finalized_window_and_requires_confirmation() {
        let bars = vec![
            test_five_minute_bar(1, 100.00, 100.10, 99.98, 100.08, 1_000.0, 100.04),
            test_five_minute_bar(2, 100.08, 100.22, 100.06, 100.19, 1_100.0, 100.09),
            test_five_minute_bar(3, 100.19, 100.34, 100.17, 100.31, 1_250.0, 100.15),
        ];
        let up = momentum_observation(&bars, TurnDirection::Up, 15).unwrap();
        let down = momentum_observation(&bars, TurnDirection::Down, 15).unwrap();
        assert!(up.matched);
        assert!(!down.matched);
        assert_eq!(up.directional_bars, 3);
        assert!(up.recent_volume_ratio.is_some_and(|value| value > 1.0));
    }

    #[test]
    fn five_minute_bar_requires_five_unique_contiguous_exchange_clock_minutes() {
        let complete = (0..5).map(test_minute_bar).collect::<Vec<_>>();
        let aggregated = aggregate_five_minutes(&complete).unwrap();
        assert_eq!(aggregated.bars.len(), 1);
        assert_eq!(
            aggregated.bars[0].interval_start,
            complete[0].interval_start
        );
        assert_eq!(aggregated.bars[0].interval_end, complete[4].interval_end);

        let gapped = [0, 1, 2, 4, 5, 6, 7, 8, 9]
            .into_iter()
            .map(test_minute_bar)
            .collect::<Vec<_>>();
        assert!(aggregate_five_minutes(&gapped).unwrap().bars.is_empty());

        let mut conflicting = complete;
        let mut conflict = test_minute_bar(0);
        conflict.close = 99.5;
        conflicting.push(conflict);
        assert!(aggregate_five_minutes(&conflicting).is_err());
    }

    #[test]
    fn malformed_target_row_fails_closed() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("malformed.csv");
        let mut file = fs::File::create(&path).unwrap();
        write_historical_header(&mut file);
        writeln!(
            file,
            "2026-07-20T13:30:00Z,SPY,not-a-price,100.1,99.9,100,1000,,false,,,10,DATABENTO_EQUS_MINI,licensed"
        )
        .unwrap();
        let error = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::OpeningTurn,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap_err();
        assert!(error.to_string().contains("malformed target row"));
    }

    #[test]
    fn exact_duplicate_is_counted_but_conflicting_duplicate_fails_closed() {
        let temporary = tempfile::tempdir().unwrap();
        let exact_path = temporary.path().join("exact.csv");
        let mut exact_file = fs::File::create(&exact_path).unwrap();
        write_historical_header(&mut exact_file);
        let start = Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap();
        for minute in 0..REGULAR_SESSION_MINUTES {
            write_historical_minute(
                &mut exact_file,
                start + Duration::minutes(minute as i64),
                "SPY",
                100.0,
                100.0,
                1_000.0,
                None,
                false,
            );
        }
        write_historical_minute(
            &mut exact_file,
            start,
            "SPY",
            100.0,
            100.0,
            1_000.0,
            None,
            false,
        );
        drop(exact_file);
        let exact = historical_setup_stats(
            &exact_path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(exact.sessions, 1);
        assert_eq!(exact.session_integrity.target_rows, 391);
        assert_eq!(exact.session_integrity.unique_regular_session_rows, 390);
        assert_eq!(exact.session_integrity.exact_duplicate_rows, 1);
        assert_eq!(exact.session_integrity.conflicting_duplicate_rows, 0);

        let conflicting_path = temporary.path().join("conflicting.csv");
        let mut conflicting_file = fs::File::create(&conflicting_path).unwrap();
        write_historical_header(&mut conflicting_file);
        write_historical_minute(
            &mut conflicting_file,
            start,
            "SPY",
            100.0,
            100.0,
            1_000.0,
            None,
            false,
        );
        write_historical_minute(
            &mut conflicting_file,
            start,
            "SPY",
            100.0,
            99.9,
            1_000.0,
            None,
            false,
        );
        drop(conflicting_file);
        let error = historical_setup_stats(
            &conflicting_path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap_err();
        assert!(error.to_string().contains("conflicting duplicate"));
    }

    #[test]
    fn incomplete_regular_session_is_excluded_with_reason() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("incomplete.csv");
        let mut file = fs::File::create(&path).unwrap();
        write_historical_header(&mut file);
        let start = Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap();
        for minute in 0..REGULAR_SESSION_MINUTES - 1 {
            write_historical_minute(
                &mut file,
                start + Duration::minutes(minute as i64),
                "SPY",
                100.0,
                100.0,
                1_000.0,
                None,
                false,
            );
        }
        drop(file);
        let stats = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(stats.sessions, 0);
        assert_eq!(stats.session_integrity.observed_sessions, 1);
        assert_eq!(stats.session_integrity.excluded_sessions, 1);
        assert_eq!(
            stats
                .session_integrity
                .session_exclusion_counts
                .get("INCOMPLETE_REGULAR_SESSION"),
            Some(&1)
        );
    }

    #[test]
    fn fifteen_minute_label_never_uses_three_noncontiguous_vector_rows() {
        let bars = vec![
            test_five_minute_bar(1, 100.0, 100.1, 99.9, 100.0, 1_000.0, 100.0),
            test_five_minute_bar(2, 100.0, 100.2, 99.9, 100.1, 1_000.0, 100.0),
            test_five_minute_bar(3, 100.1, 100.1, 99.6, 99.7, 1_000.0, 99.9),
            test_five_minute_bar(4, 99.7, 99.8, 99.5, 99.6, 1_000.0, 99.8),
            test_five_minute_bar(6, 99.6, 99.7, 99.4, 99.5, 1_000.0, 99.7),
            test_five_minute_bar(7, 99.5, 99.6, 99.3, 99.4, 1_000.0, 99.6),
        ];
        let event = detect_event(
            &bars,
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
        )
        .unwrap();
        assert_eq!(event.bar_number, 3);
        assert!(event.forward_return.is_none());
        assert_eq!(
            event.label_exclusion_reason.as_deref(),
            Some(MISSING_HORIZON_EXCLUSION)
        );
    }

    #[test]
    fn late_event_is_retained_and_counted_by_exclusion_reason() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("late.csv");
        let mut file = fs::File::create(&path).unwrap();
        write_historical_header(&mut file);
        let start = Utc.with_ymd_and_hms(2026, 7, 20, 13, 30, 0).unwrap();
        for minute in 0..REGULAR_SESSION_MINUTES {
            let (open, close) = if (375..380).contains(&minute) {
                (100.0, 99.0)
            } else if minute >= 380 {
                (99.0, 99.0)
            } else {
                (100.0, 100.0)
            };
            write_historical_minute(
                &mut file,
                start + Duration::minutes(minute as i64),
                "SPY",
                open,
                close,
                1_000.0,
                None,
                false,
            );
        }
        drop(file);
        let stats = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(stats.event_sessions, 1);
        assert_eq!(stats.completed_backtests, 0);
        assert_eq!(stats.label_integrity.detected_events, 1);
        assert_eq!(stats.label_integrity.excluded_events, 1);
        assert_eq!(
            stats
                .label_integrity
                .event_exclusion_counts
                .get(LATE_EVENT_EXCLUSION),
            Some(&1)
        );
    }

    #[test]
    fn vendor_vwap_is_session_atomic_and_reports_proxy_parity_and_coverage() {
        let temporary = tempfile::tempdir().unwrap();
        let normalized = temporary.path().join("normalized");
        fs::create_dir_all(&normalized).unwrap();
        let path = normalized.join("vwap.csv");
        let mut file = fs::File::create(&path).unwrap();
        write_historical_header(&mut file);
        for (day, one_unauthorized_row) in [(20, false), (21, true)] {
            let start = Utc.with_ymd_and_hms(2026, 7, day, 13, 30, 0).unwrap();
            for minute in 0..REGULAR_SESSION_MINUTES {
                write_historical_minute(
                    &mut file,
                    start + Duration::minutes(minute as i64),
                    "SPY",
                    100.0,
                    100.0,
                    1_000.0,
                    Some(99.9),
                    !(one_unauthorized_row && minute == 42),
                );
            }
        }
        drop(file);
        let manifests = temporary.path().join("manifests");
        fs::create_dir_all(&manifests).unwrap();
        let manifest_path = manifests.join("vwap-lineage.json");
        fs::write(
            &manifest_path,
            serde_json::to_vec(&json!({
                "schema_version":"axio.historical-bars-manifest.v1",
                "output_file":"vwap.csv",
                "output_sha256":"0".repeat(64),
                "sources":["DATABENTO_EQUS_MINI"],
                "authorized_fields":["minute_vwap"],
                "capabilities":{"vendor_minute_vwap":true},
                "rights_receipt_sha256":"a".repeat(64)
            }))
            .unwrap(),
        )
        .unwrap();
        let unverified = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(
            unverified.vwap_status.sessions_using_authorized_vendor_vwap,
            0
        );
        assert_eq!(unverified.vwap_status.sessions_using_reconstructed_proxy, 2);
        assert_eq!(
            unverified
                .vwap_status
                .reported_but_unauthorized_vendor_vwap_rows,
            780
        );

        let output_sha256 = sha256_hex(&fs::read(&path).unwrap());
        let rights_now = Utc::now();
        let rights_bytes = serde_json::to_vec(&json!({
            "schema_version":"axio.market_data_rights.v2",
            "provider":"databento",
            "product":"EQUS.MINI",
            "legal_entity":"AXIO7 Research LLC",
            "plan_name":"Databento Standard",
            "plan_status":"ACTIVE",
            "permitted_uses":{
                "model_input":true,
                "customer_external_display":true,
                "derived_output_publication":true,
                "raw_data_redistribution":false
            },
            "evidence_kind":"EXECUTED_AGREEMENT",
            "evidence_artifact_sha256":"b".repeat(64),
            "account_license_reference_sha256":"c".repeat(64),
            "official_terms_url":"https://databento.com/legal/terms",
            "official_product_url":"https://databento.com/stocks",
            "official_evidence_url":"https://contracts.databento.com/agreements/customer-external-display",
            "valid_from":rights_now - Duration::days(30),
            "valid_until":rights_now + Duration::days(30),
            "issuer":"Databento",
            "reviewer":"AXIO7 Authorized Rights Reviewer",
            "issued_at":rights_now - Duration::days(31),
            "reviewed_at":rights_now - Duration::hours(1),
            "review_due_at":rights_now + Duration::days(7)
        }))
        .unwrap();
        let rights_sha256 = sha256_hex(&rights_bytes);
        let rights_path = temporary
            .path()
            .join("rights/market_data_rights_receipt.json");
        fs::create_dir_all(rights_path.parent().unwrap()).unwrap();
        fs::write(&rights_path, rights_bytes).unwrap();
        fs::write(
            manifest_path,
            serde_json::to_vec(&json!({
                "schema_version":"axio.historical-bars-manifest.v1",
                "output_file":"vwap.csv",
                "output_sha256":output_sha256,
                "provider":"databento",
                "product":"EQUS.MINI",
                "sources":["DATABENTO_EQUS_MINI"],
                "authorized_fields":["minute_vwap"],
                "capabilities":{"vendor_minute_vwap":true},
                "rights_receipt_sha256":rights_sha256
            }))
            .unwrap(),
        )
        .unwrap();
        let _rights_lock = RIGHTS_ENV_LOCK.lock().unwrap();
        let _rights_environment =
            ScopedEnvironment::set(MARKET_DATA_RIGHTS_RECEIPT_SHA256_ENV, &rights_sha256);
        let stats = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(stats.sessions, 2);
        assert_eq!(stats.vwap_status.eligible_minute_rows, 780);
        assert_eq!(stats.vwap_status.authorized_vendor_vwap_rows, 779);
        assert_eq!(
            stats.vwap_status.reported_but_unauthorized_vendor_vwap_rows,
            1
        );
        assert_eq!(stats.vwap_status.sessions_using_authorized_vendor_vwap, 1);
        assert_eq!(stats.vwap_status.sessions_using_reconstructed_proxy, 1);
        assert_eq!(stats.vwap_status.parity_observations, 78);
        assert!(
            stats
                .vwap_status
                .median_absolute_parity_bps
                .is_some_and(|value| value > 0.0)
        );

        fs::write(&rights_path, b"{\"tampered\":true}").unwrap();
        let tampered = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::VwapReversal,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(
            tampered.vwap_status.sessions_using_authorized_vendor_vwap,
            0
        );
        assert_eq!(tampered.vwap_status.sessions_using_reconstructed_proxy, 2);
    }

    #[test]
    fn statistical_dislocation_uses_twelve_prior_vwap_distances() {
        let prior = (1..=12)
            .map(|number| {
                let distance = if number % 2 == 0 { 0.0001 } else { -0.0001 };
                let close = 100.0;
                test_five_minute_bar(
                    number,
                    close,
                    close + 0.1,
                    close - 0.1,
                    close,
                    1_000.0,
                    close / (1.0 + distance),
                )
            })
            .collect::<Vec<_>>();
        let mut selective = prior.clone();
        selective.push(test_five_minute_bar(
            13, 100.0, 100.1, 99.7, 99.8, 1_000.0, 100.0,
        ));
        assert!(statistical_dislocation_matched(
            &selective,
            TurnDirection::Down
        ));

        let mut below_absolute_floor = prior.clone();
        below_absolute_floor.push(test_five_minute_bar(
            13, 100.0, 100.1, 99.8, 99.9, 1_000.0, 100.0,
        ));
        assert!(!statistical_dislocation_matched(
            &below_absolute_floor,
            TurnDirection::Down
        ));

        let mut too_few = prior[..11].to_vec();
        too_few.push(test_five_minute_bar(
            12, 100.0, 100.1, 99.7, 99.8, 1_000.0, 100.0,
        ));
        assert!(!statistical_dislocation_matched(
            &too_few,
            TurnDirection::Down
        ));
        assert_eq!(
            STATISTICAL_DISLOCATION_METHOD_VERSION,
            "causal-vwap-dislocation-5m.v2"
        );
    }

    #[test]
    fn historical_opening_turn_is_causal_and_reports_forward_labels() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("bars.csv");
        let mut file = fs::File::create(&path).unwrap();
        writeln!(
            file,
            "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality"
        )
        .unwrap();
        let date = NaiveDate::from_ymd_opt(2026, 7, 20).unwrap();
        let start = New_York
            .with_ymd_and_hms(date.year(), date.month(), date.day(), 9, 30, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);
        for minute in 0..REGULAR_SESSION_MINUTES {
            let (open, close) = if minute < 10 {
                (100.0 + minute as f64 * 0.02, 100.03 + minute as f64 * 0.02)
            } else if minute < 15 {
                (100.20, 100.04)
            } else {
                (100.04, 99.95)
            };
            let timestamp = start + chrono::Duration::minutes(minute as i64);
            writeln!(
                file,
                "{timestamp},SPY,{open},{},{},{close},1000,,,,10,MASSIVE_STOCKS_AGG_1M,vendor",
                open.max(close) + 0.02,
                open.min(close) - 0.02,
                timestamp = timestamp.to_rfc3339()
            )
            .unwrap();
        }
        let stats = historical_setup_stats(
            &path,
            "SPY",
            MarketSetupType::OpeningTurn,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(stats.sessions, 1);
        assert_eq!(stats.event_sessions, 1);
        assert_eq!(stats.completed_backtests, 1);
        assert_eq!(stats.assumed_round_trip_cost_bps, 3.0);
        assert!(stats.event_bar_median.is_some());
        assert!(stats.median_forward_return.is_some());
        assert!(stats.median_net_return.is_some());
        assert!(stats.max_drawdown.is_some());
    }

    #[test]
    fn historical_statistical_dislocation_uses_next_bar_entry_and_explicit_costs() {
        let temporary = tempfile::tempdir().unwrap();
        let path = temporary.path().join("bars.csv");
        let mut file = fs::File::create(&path).unwrap();
        writeln!(
            file,
            "timestamp,symbol,open,high,low,close,volume,vwap,bid,ask,trade_count,source,data_quality"
        )
        .unwrap();
        let date = NaiveDate::from_ymd_opt(2026, 7, 21).unwrap();
        let start = New_York
            .with_ymd_and_hms(date.year(), date.month(), date.day(), 9, 30, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);
        for minute in 0..REGULAR_SESSION_MINUTES {
            let (open, close) = if minute < 60 {
                let open = 100.0 + minute as f64 * 0.001;
                (open, open + 0.002)
            } else if minute < 65 {
                let open = 99.95 - (minute - 60) as f64 * 0.08;
                (open, open - 0.04)
            } else {
                let open = 99.50 - (minute - 65) as f64 * 0.002;
                (open, open - 0.015)
            };
            let timestamp = start + chrono::Duration::minutes(minute as i64);
            writeln!(
                file,
                "{timestamp},NVDA,{open},{},{},{close},1500,,,,10,DATABENTO_EQUS_MINI,licensed",
                open.max(close) + 0.01,
                open.min(close) - 0.01,
                timestamp = timestamp.to_rfc3339()
            )
            .unwrap();
        }
        let mut stats = historical_setup_stats(
            &path,
            "NVDA",
            MarketSetupType::StatisticalDislocation,
            TurnDirection::Down,
            15,
            None,
            3.0,
        )
        .unwrap();
        assert_eq!(stats.event_sessions, 1);
        assert_eq!(stats.completed_backtests, 1);
        assert!(stats.net_win_rate.is_some_and(|value| value == 1.0));
        assert!(stats.median_net_return.is_some_and(|value| value > 0.0));
        assert_eq!(
            stats.performance_scope,
            "HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE"
        );
        stats.data_manifest_hash = Some("9".repeat(64));

        let query = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Scan,
            setup_type: MarketSetupType::StatisticalDislocation,
            symbols: vec!["NVDA".to_string()],
            horizon_minutes: Some(15),
            limit: 1,
            as_of: None,
            filters: MarketQueryFilters {
                direction: Some(TurnDirection::Down),
                include_historical: true,
                ..MarketQueryFilters::default()
            },
        };
        let mut partial = EvidenceEnvelope {
            schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
            evidence_mode: Default::default(),
            request_id: "historical-while-live-stale".to_string(),
            query_sha256: query.canonical_sha256().unwrap(),
            response_sha256: None,
            generated_at: Utc.with_ymd_and_hms(2026, 7, 28, 13, 32, 0).unwrap(),
            observation_cutoff: Utc.with_ymd_and_hms(2026, 7, 28, 13, 32, 0).unwrap(),
            status: "PARTIAL".to_string(),
            query,
            candidates: Vec::new(),
            exclusions: Vec::new(),
            historical: vec![stats],
            data_blockers: vec!["PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH".to_string()],
            readiness: PipelineReadiness::default(),
            model_contract: json!({}),
            research_only_policy: json!({}),
            caveats: Vec::new(),
        };
        let mut invalid_partial = partial.clone();
        partial.seal().unwrap();
        invalid_partial.historical[0].max_drawdown = Some(0.01);
        assert!(invalid_partial.seal().is_err());

        let mut overstated_edge = partial;
        overstated_edge.historical[0].edge_classification =
            HistoricalEdgeClassification::NoDemonstratedEdge;
        assert!(overstated_edge.seal().is_err());
    }

    #[test]
    fn envelope_hash_is_over_payload_without_hash_field() {
        let query = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Scan,
            setup_type: MarketSetupType::OpeningTurn,
            symbols: vec!["SPY".to_string()],
            horizon_minutes: Some(15),
            limit: 10,
            as_of: None,
            filters: MarketQueryFilters {
                direction: Some(TurnDirection::Down),
                ..MarketQueryFilters::default()
            },
        };
        let mut envelope = EvidenceEnvelope {
            schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
            evidence_mode: Default::default(),
            request_id: "request".to_string(),
            query_sha256: query.canonical_sha256().unwrap(),
            response_sha256: None,
            generated_at: DateTime::<Utc>::UNIX_EPOCH,
            observation_cutoff: DateTime::<Utc>::UNIX_EPOCH,
            status: "DATA_UNAVAILABLE".to_string(),
            query,
            candidates: Vec::new(),
            exclusions: Vec::new(),
            historical: Vec::new(),
            data_blockers: Vec::new(),
            readiness: PipelineReadiness::default(),
            model_contract: json!({}),
            research_only_policy: json!({}),
            caveats: Vec::new(),
        };
        envelope.seal().unwrap();
        assert_eq!(envelope.response_sha256.as_deref().unwrap().len(), 64);
    }

    #[test]
    fn envelope_seal_enforces_uncalibrated_whitelist_and_fail_closed_status() {
        let generated_at = Utc.with_ymd_and_hms(2026, 7, 27, 14, 31, 0).unwrap();
        let observed_at = generated_at - Duration::seconds(61);
        let available_at = generated_at - Duration::seconds(60);
        let query = MarketQuery {
            version: MARKET_QUERY_SCHEMA_VERSION.to_string(),
            intent: MarketQueryIntent::Forecast,
            setup_type: MarketSetupType::StatisticalDislocation,
            symbols: vec!["NVDA".to_string()],
            horizon_minutes: Some(15),
            limit: 1,
            as_of: None,
            filters: MarketQueryFilters {
                direction: Some(TurnDirection::Down),
                ..MarketQueryFilters::default()
            },
        };
        let candidate = ResearchCandidate {
            symbol: "NVDA".to_string(),
            setup_type: MarketSetupType::StatisticalDislocation,
            status: "UNCALIBRATED_RESEARCH_OUTPUT".to_string(),
            heuristic_structure_score: None,
            score_semantics: "No public rank.".to_string(),
            supporting_evidence: vec![EvidenceItem {
                code: "FRESH_NATIVE_FORECAST_CONTRACT".to_string(),
                statement: "Fresh model condition.".to_string(),
                observed_value: None,
            }],
            contrary_evidence: vec![EvidenceItem {
                code: "MATERIAL_DATA_CAVEAT".to_string(),
                statement: "No probability is published.".to_string(),
                observed_value: None,
            }],
            metrics: json!({
                "horizon_minutes":15,
                "statistical_orientation":"POSITIVE_CONDITIONAL_MEAN",
                "observation_cutoff":observed_at,
                "latest_input_available_at":available_at,
                "data_age_seconds":60,
                "data_source":"MOOMOO_OPEND",
                "coverage":1.0,
                "coverage_semantics":"ALL_REQUIRED_TARGET_AND_CONTEXT_SYMBOLS_PRESENT_AT_THE_DECISION_CUTOFF",
                "caveats":["No probability is published."],
                "published_probability_status":"WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION",
                "validation":{
                    "model_version":"model-v3",
                    "feature_version":"feature-v4",
                    "model_hash":"a".repeat(64),
                    "feature_hash":"b".repeat(64),
                    "data_manifest_hash":"c".repeat(64)
                },
                "interpretation":"Direction only."
            }),
            freshness: vec![DataFreshness {
                source: "MOOMOO_OPEND".to_string(),
                observed_at: Some(observed_at),
                available_at: Some(available_at),
                age_seconds: Some(60),
                realtime: true,
                entitlement: "LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED".to_string(),
                coverage: Some(1.0),
            }],
        };
        let base = EvidenceEnvelope {
            schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
            evidence_mode: Default::default(),
            request_id: "request".to_string(),
            query_sha256: query.canonical_sha256().unwrap(),
            response_sha256: None,
            generated_at,
            observation_cutoff: generated_at,
            status: "UNCALIBRATED_RESEARCH_OUTPUT".to_string(),
            query,
            candidates: vec![candidate],
            exclusions: Vec::new(),
            historical: Vec::new(),
            data_blockers: Vec::new(),
            readiness: PipelineReadiness::default(),
            model_contract: json!({}),
            research_only_policy: json!({}),
            caveats: vec!["Research only.".to_string()],
        };
        let mut valid = base.clone();
        valid.seal().unwrap();

        let mut leaked = base.clone();
        leaked.candidates[0].metrics["expected_move_percent"] = json!(1.2);
        assert!(leaked.seal().is_err());

        let mut partial = base;
        partial.data_blockers.push("NVDA:STALE".to_string());
        assert!(partial.seal().is_err());
    }
}
