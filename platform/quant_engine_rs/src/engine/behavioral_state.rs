use anyhow::{Result, bail, ensure};
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};

use crate::domain::MarketState;

pub const BEHAVIORAL_STATE_SCHEMA_VERSION: &str = "axio.behavioral-state.v3";
pub const BEHAVIORAL_FEATURE_SCHEMA_VERSION: &str = "axio.behavioral-price-flow-features.v2";
pub const BEHAVIORAL_FEATURE_SCHEMA_SHA256: &str =
    "6a6752e68805d98c277b63f6e4ab3cefedcfda63d0d2fefc48f1c2247e021b6c";
pub const MARKET_EMOTION_PROXY_SCHEMA_VERSION: &str = "axio.market-emotion-proxy.v1";

const MINIMUM_PUBLIC_SCORE_MARGIN: f64 = 5.0;

const REQUIRED_EXTERNAL_DOMAINS: [&str; 8] = [
    "VOLATILITY_INDICES_SKEW_AND_TERM_STRUCTURE",
    "OPTION_NBBO_TRADES_OI_GREEKS_AND_PARTICIPANT_FLOW",
    "INTRADAY_BREADTH_TICK_AND_TRIN",
    "CREDIT_SPREAD_AND_FUNDING",
    "CROSS_SECTIONAL_DISPERSION_AND_CORRELATION",
    "ETF_CREATION_REDEMPTION_AND_CLOSING_IMBALANCE",
    "POINT_IN_TIME_NEWS_AND_ATTENTION",
    "SHORT_INTEREST_BORROW_AND_SECURITIES_LENDING",
];
const REQUIRED_DOMAIN_COUNT: usize = 10;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BehavioralAvailability {
    Unavailable,
    PartialPriceFlowOnly,
    FullPointInTime,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BehavioralInputStatus {
    Available,
    Missing,
    Stale,
    Future,
    Incomplete,
    Unentitled,
    UnverifiedLineage,
    UnverifiedAvailability,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BehavioralObservability {
    DirectMarketMeasure,
    DerivedMarketProxy,
    ProviderModelScore,
    ScenarioHypothesis,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CausalInputRef {
    pub source: String,
    pub dataset: String,
    pub source_record_id: String,
    pub event_at: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
    pub recorded_at: Option<DateTime<Utc>>,
    pub license_scope: String,
    pub lineage_sha256: String,
    pub age_seconds: i64,
    pub max_age_seconds: i64,
    pub coverage: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BehavioralFeature {
    /// Deterministic 0..100 research index. It is not a probability.
    pub raw_index: Option<f64>,
    pub status: BehavioralInputStatus,
    pub observability: BehavioralObservability,
    pub units: String,
    pub input_coverage_ratio: f64,
    pub evidence: Vec<String>,
    pub inputs: Vec<CausalInputRef>,
    pub missing_inputs: Vec<String>,
    pub interpretation_hypotheses: Vec<String>,
    pub caveats: Vec<String>,
}

impl BehavioralFeature {
    fn derived(
        raw_index: f64,
        input_coverage_ratio: f64,
        evidence: Vec<String>,
        missing_inputs: Vec<String>,
        interpretation_hypotheses: &[&str],
    ) -> Self {
        Self {
            raw_index: Some(raw_index.clamp(0.0, 100.0)),
            status: BehavioralInputStatus::Available,
            observability: BehavioralObservability::DerivedMarketProxy,
            units: "RAW_INDEX_0_100".into(),
            input_coverage_ratio: input_coverage_ratio.clamp(0.0, 1.0),
            evidence,
            inputs: Vec::new(),
            missing_inputs,
            interpretation_hypotheses: interpretation_hypotheses
                .iter()
                .map(|value| (*value).into())
                .collect(),
            caveats: vec![
                "NOT_A_DIRECT_PSYCHOLOGY_OBSERVATION".into(),
                "NOT_A_CALIBRATED_PROBABILITY".into(),
                "DOES_NOT_IDENTIFY_PARTICIPANT_CLASS_OR_HEADCOUNT".into(),
            ],
        }
    }

    fn unavailable(reason: &str, observability: BehavioralObservability) -> Self {
        Self {
            raw_index: None,
            status: BehavioralInputStatus::Missing,
            observability,
            units: "UNAVAILABLE".into(),
            input_coverage_ratio: 0.0,
            evidence: Vec::new(),
            inputs: Vec::new(),
            missing_inputs: vec![reason.into()],
            interpretation_hypotheses: Vec::new(),
            caveats: vec!["MISSING_VALUES_ARE_NOT_ZERO_FILLED".into()],
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BehavioralProxyComponents {
    pub downside_stress: BehavioralFeature,
    pub upside_chase: BehavioralFeature,
    pub directional_crowding: BehavioralFeature,
    pub attention_intensity: BehavioralFeature,
    pub deleveraging_like: BehavioralFeature,
    pub rebound_squeeze_like: BehavioralFeature,
}

impl BehavioralProxyComponents {
    fn unavailable(reason: &str) -> Self {
        Self {
            downside_stress: BehavioralFeature::unavailable(
                reason,
                BehavioralObservability::DerivedMarketProxy,
            ),
            upside_chase: BehavioralFeature::unavailable(
                reason,
                BehavioralObservability::DerivedMarketProxy,
            ),
            directional_crowding: BehavioralFeature::unavailable(
                reason,
                BehavioralObservability::DerivedMarketProxy,
            ),
            attention_intensity: BehavioralFeature::unavailable(
                reason,
                BehavioralObservability::DerivedMarketProxy,
            ),
            deleveraging_like: BehavioralFeature::unavailable(
                reason,
                BehavioralObservability::ScenarioHypothesis,
            ),
            rebound_squeeze_like: BehavioralFeature::unavailable(
                reason,
                BehavioralObservability::ScenarioHypothesis,
            ),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExternalBehavioralFeatures {
    pub stationary_order_flow: BehavioralFeature,
    pub volatility_risk_state: BehavioralFeature,
    pub option_demand_state: BehavioralFeature,
    pub intraday_breadth_state: BehavioralFeature,
    pub funding_stress: BehavioralFeature,
    pub cross_sectional_herding: BehavioralFeature,
    pub news_tone: BehavioralFeature,
    pub news_attention: BehavioralFeature,
    pub social_attention: BehavioralFeature,
    pub participant_positioning: BehavioralFeature,
}

impl ExternalBehavioralFeatures {
    fn unavailable() -> Self {
        Self {
            stationary_order_flow: BehavioralFeature::unavailable(
                "ENTITLED_ORDER_BOOK_EVENT_STREAM",
                BehavioralObservability::DirectMarketMeasure,
            ),
            volatility_risk_state: BehavioralFeature::unavailable(
                "VIX_VVIX_SKEW_AND_TERM_STRUCTURE",
                BehavioralObservability::DirectMarketMeasure,
            ),
            option_demand_state: BehavioralFeature::unavailable(
                "POINT_IN_TIME_OPTION_NBBO_TRADES_OI_AND_PARTICIPANT_FLOW",
                BehavioralObservability::DerivedMarketProxy,
            ),
            intraday_breadth_state: BehavioralFeature::unavailable(
                "NYSE_TICK_TRIN_AND_ADVANCE_DECLINE",
                BehavioralObservability::DirectMarketMeasure,
            ),
            funding_stress: BehavioralFeature::unavailable(
                "CREDIT_SPREAD_AND_FUNDING",
                BehavioralObservability::DirectMarketMeasure,
            ),
            cross_sectional_herding: BehavioralFeature::unavailable(
                "CSAD_AND_CORRELATION_PANEL",
                BehavioralObservability::DerivedMarketProxy,
            ),
            news_tone: BehavioralFeature::unavailable(
                "POINT_IN_TIME_NEWS_TONE_WITH_LINEAGE",
                BehavioralObservability::ProviderModelScore,
            ),
            news_attention: BehavioralFeature::unavailable(
                "POINT_IN_TIME_NEWS_VELOCITY_AND_DISAGREEMENT",
                BehavioralObservability::DerivedMarketProxy,
            ),
            social_attention: BehavioralFeature::unavailable(
                "POINT_IN_TIME_SEARCH_OR_SOCIAL_ATTENTION",
                BehavioralObservability::DerivedMarketProxy,
            ),
            participant_positioning: BehavioralFeature::unavailable(
                "PARTICIPANT_OPEN_CLOSE_FLOW_SHORT_INTEREST_AND_LENDING",
                BehavioralObservability::ScenarioHypothesis,
            ),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BehavioralRegime {
    MixedOrConflicted,
    StressLike,
    ChaseLike,
    CrowdingLike,
    AttentionShockLike,
    ReboundSqueezeLike,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BehavioralRegimeScore {
    pub regime: BehavioralRegime,
    /// Raw scenario compatibility score, not a probability.
    pub raw_score: f64,
    pub calibrated_probability: Option<f64>,
    pub evidence: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BehavioralRegimeEstimate {
    pub dominant: Option<BehavioralRegime>,
    pub runner_up: Option<BehavioralRegime>,
    pub raw_scores: Vec<BehavioralRegimeScore>,
    pub score_margin: Option<f64>,
    pub status: String,
    pub semantics: String,
}

impl BehavioralRegimeEstimate {
    fn unavailable(reason: &str) -> Self {
        Self {
            dominant: None,
            runner_up: None,
            raw_scores: Vec::new(),
            score_margin: None,
            status: format!("UNAVAILABLE:{reason}"),
            semantics: "NO_BEHAVIORAL_REGIME_WITHOUT_CAUSAL_OBSERVABLE_MARKET_FEATURES".into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketEmotionProxyPublication {
    pub schema_version: String,
    pub publication_status: String,
    pub measurement_target: String,
    pub measurement_semantics: String,
    pub dominant_market_response_pattern: Option<BehavioralRegime>,
    /// Raw 0..100 compatibility index for the published pattern. It is never
    /// a probability or a participant-share estimate.
    pub raw_compatibility_index: Option<f64>,
    pub score_margin: Option<f64>,
    pub units: String,
    pub as_of: Option<DateTime<Utc>>,
    pub source_scope: String,
    pub price_flow_feature_coverage_ratio: f64,
    pub required_domain_coverage_ratio: f64,
    pub calibrated_probability: Option<f64>,
    pub not_probability: bool,
    pub affects_decision: bool,
    pub reason_codes: Vec<String>,
}

impl Default for MarketEmotionProxyPublication {
    fn default() -> Self {
        Self::withheld("MARKET_EMOTION_PROXY_NOT_EVALUATED")
    }
}

impl MarketEmotionProxyPublication {
    fn withheld(reason: &str) -> Self {
        Self {
            schema_version: MARKET_EMOTION_PROXY_SCHEMA_VERSION.into(),
            publication_status: "WITHHELD".into(),
            measurement_target: "AGGREGATE_MARKET_RESPONSE_PATTERNS".into(),
            measurement_semantics: "MARKET_DERIVED_PROXY_NOT_DIRECT_HUMAN_PSYCHOLOGY".into(),
            dominant_market_response_pattern: None,
            raw_compatibility_index: None,
            score_margin: None,
            units: "RAW_COMPATIBILITY_INDEX_0_100".into(),
            as_of: None,
            source_scope: "NONE".into(),
            price_flow_feature_coverage_ratio: 0.0,
            required_domain_coverage_ratio: 0.0,
            calibrated_probability: None,
            not_probability: true,
            affects_decision: false,
            reason_codes: vec![reason.into()],
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BehavioralStateLayer {
    pub schema_version: String,
    pub feature_schema_version: String,
    pub feature_schema_sha256: String,
    pub availability: BehavioralAvailability,
    pub observation_cutoff: Option<DateTime<Utc>>,
    pub decision_as_of: Option<DateTime<Utc>>,
    pub latest_input_available_at: Option<DateTime<Utc>>,
    pub input_availability_status: String,
    pub source_scope: String,
    pub normalized_structural_regime_entropy: Option<f64>,
    pub components: BehavioralProxyComponents,
    pub external_features: ExternalBehavioralFeatures,
    pub behavioral_regime: BehavioralRegimeEstimate,
    #[serde(default)]
    pub market_emotion_proxy: MarketEmotionProxyPublication,
    pub price_flow_feature_coverage_ratio: f64,
    pub required_domain_coverage_ratio: f64,
    pub missing_required_domains: Vec<String>,
    pub warnings: Vec<String>,
    pub combined_sentiment_regime_status: String,
    pub analog_integration_status: String,
    pub artifact_status: String,
    pub affects_decision: bool,
    pub probability_semantics: String,
}
impl Default for BehavioralStateLayer {
    fn default() -> Self {
        Self::unavailable(None, "BEHAVIORAL_STATE_NOT_EVALUATED_LEGACY_PAYLOAD")
    }
}

impl BehavioralStateLayer {
    pub fn unavailable(observation_cutoff: Option<DateTime<Utc>>, reason: &str) -> Self {
        let mut missing_required_domains =
            vec!["TARGET_PRICE_VOLUME".into(), "CROSS_ASSET_CONTEXT".into()];
        missing_required_domains.extend(
            REQUIRED_EXTERNAL_DOMAINS
                .iter()
                .map(|value| (*value).to_string()),
        );
        Self {
            schema_version: BEHAVIORAL_STATE_SCHEMA_VERSION.into(),
            feature_schema_version: BEHAVIORAL_FEATURE_SCHEMA_VERSION.into(),
            feature_schema_sha256: BEHAVIORAL_FEATURE_SCHEMA_SHA256.into(),
            availability: BehavioralAvailability::Unavailable,
            observation_cutoff,
            decision_as_of: None,
            latest_input_available_at: None,
            input_availability_status: "UNAVAILABLE".into(),
            source_scope: "NONE".into(),
            normalized_structural_regime_entropy: None,
            components: BehavioralProxyComponents::unavailable(reason),
            external_features: ExternalBehavioralFeatures::unavailable(),
            behavioral_regime: BehavioralRegimeEstimate::unavailable(reason),
            market_emotion_proxy: MarketEmotionProxyPublication::withheld(reason),
            price_flow_feature_coverage_ratio: 0.0,
            required_domain_coverage_ratio: 0.0,
            missing_required_domains,
            warnings: vec![reason.into()],
            combined_sentiment_regime_status: "UNAVAILABLE_NO_CAUSAL_POINT_IN_TIME_INPUT_SET"
                .into(),
            analog_integration_status:
                "NOT_INCLUDED_IN_FROZEN_ANALOG_DISTANCE_REQUIRES_NEW_ARTIFACT_AND_OOS_VALIDATION"
                    .into(),
            artifact_status: "NO_TRAINED_OR_PROMOTED_BEHAVIORAL_ARTIFACT".into(),
            affects_decision: false,
            probability_semantics:
                "NO_BEHAVIOR_OR_RESPONSE_PROBABILITY_WITHOUT_SEPARATE_CALIBRATION_AND_PROMOTION"
                    .into(),
        }
    }

    /// Attaches provider-observed availability after the live adapter verifies
    /// that it belongs to this layer's finalized one-minute bar.
    pub fn attach_verified_bar_availability(
        &mut self,
        available_at: DateTime<Utc>,
        source_scope: &str,
    ) -> Result<()> {
        let cutoff = self
            .observation_cutoff
            .ok_or_else(|| anyhow::anyhow!("behavioral observation cutoff is unavailable"))?;
        ensure!(
            available_at >= cutoff && available_at < cutoff + Duration::minutes(1),
            "behavioral input availability is not aligned with the observation cutoff"
        );
        ensure!(
            !source_scope.trim().is_empty(),
            "behavioral source scope is required"
        );
        self.latest_input_available_at = Some(available_at);
        self.decision_as_of = Some(available_at);
        self.input_availability_status = "VERIFIED_PROVIDER_AVAILABILITY".into();
        self.source_scope = source_scope.into();
        self.warnings
            .retain(|warning| warning != "PROVIDER_AVAILABILITY_NOT_CARRIED_BY_MARKET_STATE");
        self.refresh_market_emotion_publication();
        Ok(())
    }

    pub fn mark_availability_mismatch(&mut self, reason: &str) {
        self.latest_input_available_at = None;
        self.decision_as_of = None;
        self.input_availability_status = "UNVERIFIED_AVAILABILITY".into();
        self.warnings.push(reason.into());
        self.warnings.sort();
        self.warnings.dedup();
        self.refresh_market_emotion_publication();
    }

    fn refresh_market_emotion_publication(&mut self) {
        let mut reasons = Vec::new();
        if self.availability == BehavioralAvailability::Unavailable {
            reasons.push("BEHAVIORAL_MARKET_INPUTS_UNAVAILABLE".to_string());
        }
        if self.input_availability_status != "VERIFIED_PROVIDER_AVAILABILITY" {
            reasons.push("PROVIDER_AVAILABILITY_NOT_VERIFIED".to_string());
        }
        if self.observation_cutoff.is_none()
            || self.latest_input_available_at.is_none()
            || self.decision_as_of.is_none()
            || self.latest_input_available_at != self.decision_as_of
            || self
                .observation_cutoff
                .zip(self.latest_input_available_at)
                .is_none_or(|(cutoff, available_at)| {
                    available_at < cutoff || available_at >= cutoff + Duration::minutes(1)
                })
        {
            reasons.push("CAUSAL_AVAILABILITY_CLOCK_INVALID".to_string());
        }
        if self.price_flow_feature_coverage_ratio < 1.0 - 1.0e-12 {
            reasons.push("PRICE_FLOW_OR_CROSS_ASSET_COVERAGE_INCOMPLETE".to_string());
        }
        let features = [
            &self.components.downside_stress,
            &self.components.upside_chase,
            &self.components.directional_crowding,
            &self.components.attention_intensity,
            &self.components.deleveraging_like,
            &self.components.rebound_squeeze_like,
        ];
        if features.iter().any(|feature| {
            feature.status != BehavioralInputStatus::Available
                || feature
                    .raw_index
                    .is_none_or(|value| !value.is_finite() || !(0.0..=100.0).contains(&value))
        }) {
            reasons.push("PRICE_FLOW_PROXY_COMPONENTS_INCOMPLETE".to_string());
        }
        if self.affects_decision {
            reasons.push("DECISION_NEUTRALITY_VIOLATED".to_string());
        }
        let dominant = self.behavioral_regime.dominant;
        let dominant_score = dominant.and_then(|regime| {
            self.behavioral_regime
                .raw_scores
                .iter()
                .find(|row| row.regime == regime)
                .map(|row| row.raw_score)
        });
        if dominant.is_none()
            || dominant_score
                .is_none_or(|value| !value.is_finite() || !(0.0..=100.0).contains(&value))
        {
            reasons.push("DOMINANT_MARKET_RESPONSE_PATTERN_UNAVAILABLE".to_string());
        }
        let score_margin = self.behavioral_regime.score_margin;
        if score_margin
            .is_none_or(|value| !value.is_finite() || value < MINIMUM_PUBLIC_SCORE_MARGIN)
        {
            reasons.push("LOW_PATTERN_SEPARATION".to_string());
        }
        if self
            .behavioral_regime
            .raw_scores
            .iter()
            .any(|row| row.calibrated_probability.is_some())
        {
            reasons.push("UNPROMOTED_BEHAVIORAL_PROBABILITY_PRESENT".to_string());
        }

        reasons.sort();
        reasons.dedup();
        if reasons.is_empty() {
            self.market_emotion_proxy = MarketEmotionProxyPublication {
                schema_version: MARKET_EMOTION_PROXY_SCHEMA_VERSION.into(),
                publication_status: "AVAILABLE_PARTIAL_PRICE_FLOW_PROXY".into(),
                measurement_target: "AGGREGATE_MARKET_RESPONSE_PATTERNS".into(),
                measurement_semantics: "MARKET_DERIVED_PROXY_NOT_DIRECT_HUMAN_PSYCHOLOGY".into(),
                dominant_market_response_pattern: dominant,
                raw_compatibility_index: dominant_score,
                score_margin,
                units: "RAW_COMPATIBILITY_INDEX_0_100".into(),
                as_of: self.decision_as_of,
                source_scope: self.source_scope.clone(),
                price_flow_feature_coverage_ratio: self.price_flow_feature_coverage_ratio,
                required_domain_coverage_ratio: self.required_domain_coverage_ratio,
                calibrated_probability: None,
                not_probability: true,
                affects_decision: false,
                reason_codes: Vec::new(),
            };
        } else {
            self.market_emotion_proxy = MarketEmotionProxyPublication {
                schema_version: MARKET_EMOTION_PROXY_SCHEMA_VERSION.into(),
                publication_status: "WITHHELD".into(),
                measurement_target: "AGGREGATE_MARKET_RESPONSE_PATTERNS".into(),
                measurement_semantics: "MARKET_DERIVED_PROXY_NOT_DIRECT_HUMAN_PSYCHOLOGY".into(),
                dominant_market_response_pattern: None,
                raw_compatibility_index: None,
                score_margin,
                units: "RAW_COMPATIBILITY_INDEX_0_100".into(),
                as_of: None,
                source_scope: self.source_scope.clone(),
                price_flow_feature_coverage_ratio: self.price_flow_feature_coverage_ratio,
                required_domain_coverage_ratio: self.required_domain_coverage_ratio,
                calibrated_probability: None,
                not_probability: true,
                affects_decision: false,
                reason_codes: reasons,
            };
        }
    }
}

fn activation(value: f64) -> f64 {
    1.0 / (1.0 + (-value.clamp(-12.0, 12.0)).exp())
}

fn scaled_return(value: f64, volatility: f64) -> f64 {
    (value / volatility.max(1.0e-4)).clamp(-6.0, 6.0)
}

fn weighted_index(parts: &[(Option<f64>, f64)]) -> (f64, f64) {
    let total_weight = parts.iter().map(|(_, weight)| *weight).sum::<f64>();
    let available_weight = parts
        .iter()
        .filter_map(|(value, weight)| value.map(|_| *weight))
        .sum::<f64>();
    let weighted_sum = parts
        .iter()
        .filter_map(|(value, weight)| value.map(|value| value.clamp(0.0, 1.0) * weight))
        .sum::<f64>();
    (
        100.0 * weighted_sum / available_weight.max(1.0e-12),
        available_weight / total_weight.max(1.0e-12),
    )
}

fn feature_evidence(base: &[&str], cross_asset_complete: bool) -> Vec<String> {
    let mut evidence = base
        .iter()
        .map(|value| (*value).to_string())
        .collect::<Vec<_>>();
    if cross_asset_complete {
        evidence.extend([
            "COMPLETE_CROSS_ASSET_BREADTH".into(),
            "COMPLETE_RISK_ROTATION_BASKET".into(),
            "CROSS_ASSET_MARKET_CONFIRMATION".into(),
        ]);
    }
    evidence
}

fn feature_missing(cross_asset_complete: bool, extra: &[&str]) -> Vec<String> {
    let mut missing = extra
        .iter()
        .map(|value| (*value).to_string())
        .collect::<Vec<_>>();
    if !cross_asset_complete {
        missing.push("COMPLETE_CROSS_ASSET_CONTEXT".into());
    }
    missing
}

fn regime_estimate(components: &BehavioralProxyComponents) -> BehavioralRegimeEstimate {
    let downside = components.downside_stress.raw_index.unwrap_or(50.0);
    let upside = components.upside_chase.raw_index.unwrap_or(50.0);
    let crowding = components.directional_crowding.raw_index.unwrap_or(50.0);
    let attention = components.attention_intensity.raw_index.unwrap_or(50.0);
    let deleveraging = components.deleveraging_like.raw_index.unwrap_or(50.0);
    let rebound = components.rebound_squeeze_like.raw_index.unwrap_or(50.0);
    let mixed = (100.0
        - (downside - upside)
            .abs()
            .max((deleveraging - rebound).abs())
            .max(0.5 * (crowding - 50.0).abs())
            .max(0.25 * (attention - 50.0).abs()))
    .clamp(0.0, 100.0);
    let mut scores = vec![
        BehavioralRegimeScore {
            regime: BehavioralRegime::StressLike,
            raw_score: (0.42 * downside + 0.33 * deleveraging + 0.15 * attention + 0.10 * crowding)
                .clamp(0.0, 100.0),
            calibrated_probability: None,
            evidence: vec![
                "DOWNSIDE_STRESS_PROXY".into(),
                "DELEVERAGING_LIKE_PROXY".into(),
            ],
        },
        BehavioralRegimeScore {
            regime: BehavioralRegime::ChaseLike,
            raw_score: (0.50 * upside
                + 0.20 * crowding
                + 0.20 * attention
                + 0.10 * (100.0 - downside))
                .clamp(0.0, 100.0),
            calibrated_probability: None,
            evidence: vec![
                "UPSIDE_CHASE_PROXY".into(),
                "ATTENTION_INTENSITY_PROXY".into(),
            ],
        },
        BehavioralRegimeScore {
            regime: BehavioralRegime::CrowdingLike,
            raw_score: (0.55 * crowding
                + 0.20 * downside.max(upside)
                + 0.15 * attention
                + 0.10 * (downside - upside).abs())
            .clamp(0.0, 100.0),
            calibrated_probability: None,
            evidence: vec!["DIRECTIONAL_CROWDING_PROXY".into()],
        },
        BehavioralRegimeScore {
            regime: BehavioralRegime::AttentionShockLike,
            raw_score: (0.65 * attention + 0.20 * crowding + 0.15 * (downside - upside).abs())
                .clamp(0.0, 100.0),
            calibrated_probability: None,
            evidence: vec!["MARKET_DERIVED_ATTENTION_INTENSITY".into()],
        },
        BehavioralRegimeScore {
            regime: BehavioralRegime::ReboundSqueezeLike,
            raw_score: (0.55 * rebound
                + 0.20 * upside
                + 0.15 * attention
                + 0.10 * (100.0 - deleveraging))
                .clamp(0.0, 100.0),
            calibrated_probability: None,
            evidence: vec!["REBOUND_SQUEEZE_LIKE_PROXY".into()],
        },
        BehavioralRegimeScore {
            regime: BehavioralRegime::MixedOrConflicted,
            raw_score: mixed,
            calibrated_probability: None,
            evidence: vec!["LOW_SEPARATION_ACROSS_MARKET_DERIVED_PROXIES".into()],
        },
    ];
    scores.sort_by(|left, right| right.raw_score.total_cmp(&left.raw_score));
    let dominant = scores.first().map(|row| row.regime);
    let runner_up = scores.get(1).map(|row| row.regime);
    let score_margin = scores
        .first()
        .zip(scores.get(1))
        .map(|(first, second)| first.raw_score - second.raw_score);
    BehavioralRegimeEstimate {
        dominant,
        runner_up,
        raw_scores: scores,
        score_margin,
        status: "RAW_MARKET_RESPONSE_SCENARIO_NOT_CALIBRATED".into(),
        semantics: "DOMINANT_MEANS_HIGHEST_HEURISTIC_COMPATIBILITY_SCORE_NOT_MOST_PEOPLE_NOT_ACTOR_IDENTITY_NOT_A_PROBABILITY".into(),
    }
}
/// Produces a causal, market-derived behavioral research layer from finalized
/// one-minute features. Psychology words are interpretation hypotheses only.
/// No participant identity, headcount, dealer sign, capital weight, or action
/// probability is inferred from OHLCV.
pub fn derive_price_flow_behavioral_state(
    state: &MarketState,
    observation_cutoff: DateTime<Utc>,
    normalized_regime_entropy: f64,
) -> Result<BehavioralStateLayer> {
    ensure!(
        observation_cutoff == state.timestamp + Duration::minutes(1),
        "behavioral observation cutoff must equal the finalized one-minute bar end"
    );
    ensure!(
        normalized_regime_entropy.is_finite() && (0.0..=1.0).contains(&normalized_regime_entropy),
        "normalized regime entropy must be finite and in [0,1]"
    );
    ensure!(
        state.cross_asset_context_coverage.is_finite()
            && (0.0..=1.0).contains(&state.cross_asset_context_coverage),
        "cross-asset context coverage must be finite and in [0,1]"
    );
    ensure!(
        !state.cross_asset_context_complete || state.cross_asset_context_coverage == 1.0,
        "complete cross-asset context must have coverage 1"
    );
    let base_feature_values = [
        state.ret_1m,
        state.ret_5m,
        state.ret_15m,
        state.dist_vwap,
        state.rolling_realized_vol,
        state.normalized_range,
        state.close_location_value,
        state.lower_wick_ratio,
        state.return_acceleration,
        state.volume_zscore,
        state.volume_acceleration,
        state.rvol_same_minute,
        state.closing_short_cover_score,
    ];
    if base_feature_values.iter().any(|value| !value.is_finite()) {
        bail!("behavioral price/volume features contain a non-finite value");
    }
    if state.cross_asset_context_complete
        && [
            state.cross_asset_breadth_score,
            state.risk_rotation_score,
            state.market_confirmation_score,
        ]
        .iter()
        .any(|value| !value.is_finite())
    {
        bail!("complete cross-asset behavioral features contain a non-finite value");
    }

    let ret_5m_z = scaled_return(state.ret_5m, state.rolling_realized_vol);
    let ret_15m_z = scaled_return(state.ret_15m, state.rolling_realized_vol);
    let vwap_z = scaled_return(state.dist_vwap, state.rolling_realized_vol);
    let range_to_vol =
        (state.normalized_range / state.rolling_realized_vol.max(1.0e-4)).clamp(0.0, 8.0);
    let volume_heat = state.volume_zscore.clamp(-5.0, 5.0);
    let relative_volume_heat = state.rvol_same_minute.max(1.0e-6).ln().clamp(-4.0, 4.0);
    let volume_acceleration = state.volume_acceleration.clamp(-5.0, 5.0);
    let close_weakness = -state.close_location_value.clamp(-1.0, 1.0);
    let streak = (state.consecutive_up_bars - state.consecutive_down_bars) as f64 / 4.0;
    let breadth = state
        .cross_asset_context_complete
        .then_some(state.cross_asset_breadth_score.clamp(-4.0, 4.0));
    let risk_rotation = state
        .cross_asset_context_complete
        .then_some(state.risk_rotation_score.clamp(-4.0, 4.0));
    let confirmation = state
        .cross_asset_context_complete
        .then_some(state.market_confirmation_score.clamp(-4.0, 4.0));

    let (downside_stress, downside_coverage) = weighted_index(&[
        (Some(activation(-ret_5m_z)), 0.24),
        (Some(activation(-ret_15m_z)), 0.14),
        (breadth.map(|value| activation(-value)), 0.14),
        (risk_rotation.map(|value| activation(-value)), 0.10),
        (Some(activation(volume_heat)), 0.12),
        (Some(activation(range_to_vol - 1.5)), 0.10),
        (Some(activation(close_weakness)), 0.10),
        (Some(activation(-vwap_z)), 0.06),
    ]);
    let (upside_chase, upside_coverage) = weighted_index(&[
        (Some(activation(ret_5m_z)), 0.25),
        (Some(activation(ret_15m_z)), 0.13),
        (Some(activation(vwap_z)), 0.12),
        (breadth.map(activation), 0.13),
        (risk_rotation.map(activation), 0.08),
        (Some(activation(volume_heat)), 0.10),
        (Some(activation(relative_volume_heat)), 0.10),
        (Some(activation(streak)), 0.09),
    ]);
    let (directional_crowding, crowding_coverage) = weighted_index(&[
        (breadth.map(|value| activation(value.abs() - 0.5)), 0.22),
        (
            confirmation.map(|value| activation(value.abs() - 0.5)),
            0.18,
        ),
        (
            risk_rotation.map(|value| activation(value.abs() - 0.5)),
            0.12,
        ),
        (Some(activation(streak.abs() - 0.5)), 0.18),
        (Some(activation(volume_heat)), 0.15),
        (Some(activation(ret_5m_z.abs() - 1.0)), 0.15),
    ]);
    let (attention_intensity, attention_coverage) = weighted_index(&[
        (Some(activation(volume_heat)), 0.30),
        (Some(activation(relative_volume_heat)), 0.25),
        (Some(activation(range_to_vol - 1.5)), 0.20),
        (Some(activation(volume_acceleration)), 0.15),
        (Some(activation(ret_5m_z.abs() - 1.0)), 0.10),
    ]);
    let (deleveraging_like, deleveraging_coverage) = weighted_index(&[
        (Some(activation(-ret_5m_z)), 0.25),
        (breadth.map(|value| activation(-value)), 0.16),
        (risk_rotation.map(|value| activation(-value)), 0.14),
        (Some(activation(volume_heat)), 0.14),
        (Some(activation(range_to_vol - 1.5)), 0.12),
        (Some(activation(close_weakness)), 0.11),
        (Some(activation(-state.return_acceleration)), 0.08),
    ]);
    let (rebound_squeeze_like, rebound_coverage) = weighted_index(&[
        (
            Some(activation(state.closing_short_cover_score.clamp(-5.0, 5.0))),
            0.30,
        ),
        (Some(activation(state.return_acceleration)), 0.17),
        (Some(activation(ret_5m_z)), 0.17),
        (Some(activation(state.lower_wick_ratio * 4.0 - 1.0)), 0.13),
        (
            Some(activation(state.consecutive_down_bars as f64 / 3.0)),
            0.10,
        ),
        (breadth.map(activation), 0.13),
    ]);
    let cross_complete = state.cross_asset_context_complete;
    let components = BehavioralProxyComponents {
        downside_stress: BehavioralFeature::derived(
            downside_stress,
            downside_coverage,
            feature_evidence(
                &[
                    "DOWNSIDE_MOMENTUM",
                    "VWAP",
                    "VOLUME",
                    "RANGE",
                    "CLOSE_LOCATION",
                ],
                cross_complete,
            ),
            feature_missing(cross_complete, &["VOLATILITY_INDICES", "CREDIT_STRESS"]),
            &[
                "FEAR_CONSISTENT_MARKET_PATTERN",
                "RISK_REDUCTION_CONSISTENT_PATTERN",
            ],
        ),
        upside_chase: BehavioralFeature::derived(
            upside_chase,
            upside_coverage,
            feature_evidence(
                &[
                    "UPSIDE_MOMENTUM",
                    "VWAP",
                    "RELATIVE_VOLUME",
                    "DIRECTIONAL_STREAK",
                ],
                cross_complete,
            ),
            feature_missing(
                cross_complete,
                &["OTM_CALL_DEMAND", "POINT_IN_TIME_ATTENTION"],
            ),
            &[
                "FOMO_CONSISTENT_MARKET_PATTERN",
                "RISK_SEEKING_CONSISTENT_PATTERN",
            ],
        ),
        directional_crowding: BehavioralFeature::derived(
            directional_crowding,
            crowding_coverage,
            feature_evidence(
                &["DIRECTIONAL_STREAK", "VOLUME", "VOLATILITY_SCALED_RETURN"],
                cross_complete,
            ),
            feature_missing(cross_complete, &["CSAD", "CORRELATION_PANEL"]),
            &["HERDING_CONSISTENT_MARKET_PATTERN"],
        ),
        attention_intensity: BehavioralFeature::derived(
            attention_intensity,
            attention_coverage,
            feature_evidence(
                &["RELATIVE_VOLUME", "VOLUME_ACCELERATION", "RANGE_EXPANSION"],
                false,
            ),
            vec!["NEWS_SEARCH_AND_SOCIAL_ATTENTION".into()],
            &["MARKET_ATTENTION_CONSISTENT_PATTERN"],
        ),
        deleveraging_like: BehavioralFeature::derived(
            deleveraging_like,
            deleveraging_coverage,
            feature_evidence(
                &["DOWNSIDE_MOMENTUM", "VOLUME", "RANGE", "CLOSE_LOCATION"],
                cross_complete,
            ),
            feature_missing(
                cross_complete,
                &["VOL_CONTROL_TARGETS", "FUND_FLOW", "DEALER_SIGN"],
            ),
            &["FORCED_SELLING_CONSISTENT_PATTERN"],
        ),
        rebound_squeeze_like: BehavioralFeature::derived(
            rebound_squeeze_like,
            rebound_coverage,
            feature_evidence(
                &["RETURN_ACCELERATION", "LOWER_WICK", "CLOSING_REBOUND_PROXY"],
                cross_complete,
            ),
            feature_missing(
                cross_complete,
                &["SHORT_INTEREST", "BORROW_COST", "SECURITIES_LENDING"],
            ),
            &[
                "SHORT_COVERING_CONSISTENT_PATTERN",
                "DIP_BUYING_CONSISTENT_PATTERN",
            ],
        ),
    };
    let behavioral_regime = regime_estimate(&components);
    let mut missing_required_domains = REQUIRED_EXTERNAL_DOMAINS
        .iter()
        .map(|value| (*value).to_string())
        .collect::<Vec<_>>();
    if !cross_complete {
        missing_required_domains.insert(0, "CROSS_ASSET_CONTEXT".into());
    }
    let observed_domain_count = 1 + usize::from(cross_complete);
    let required_domain_coverage_ratio =
        observed_domain_count as f64 / REQUIRED_DOMAIN_COUNT as f64;
    let price_flow_feature_coverage_ratio =
        (0.70 + 0.30 * state.cross_asset_context_coverage).clamp(0.0, 1.0);
    let mut warnings = vec![
        "PRICE_FLOW_DERIVED_PROXY_ONLY".into(),
        "PROVIDER_AVAILABILITY_NOT_CARRIED_BY_MARKET_STATE".into(),
        "NO_DIRECT_HUMAN_PSYCHOLOGY_OBSERVATION".into(),
        "NO_ACTOR_IDENTITY_HEADCOUNT_OR_CAPITAL_ATTRIBUTION".into(),
        "RAW_INDICES_AND_REGIME_SCORES_ARE_NOT_CALIBRATED_PROBABILITIES".into(),
        "EXTERNAL_SENTIMENT_ORDER_FLOW_AND_POSITIONING_FEATURES_UNAVAILABLE".into(),
    ];
    if !cross_complete {
        warnings.push(format!(
            "CROSS_ASSET_CONTEXT_INCOMPLETE:{:.3}",
            state.cross_asset_context_coverage
        ));
    }
    if normalized_regime_entropy > 0.75 {
        warnings.push("HIGH_STRUCTURAL_REGIME_UNCERTAINTY".into());
    }

    let mut layer = BehavioralStateLayer {
        schema_version: BEHAVIORAL_STATE_SCHEMA_VERSION.into(),
        feature_schema_version: BEHAVIORAL_FEATURE_SCHEMA_VERSION.into(),
        feature_schema_sha256: BEHAVIORAL_FEATURE_SCHEMA_SHA256.into(),
        availability: BehavioralAvailability::PartialPriceFlowOnly,
        observation_cutoff: Some(observation_cutoff),
        decision_as_of: None,
        latest_input_available_at: None,
        input_availability_status: "UNVERIFIED_MARKET_STATE_DOES_NOT_CARRY_PROVIDER_AVAILABILITY".into(),
        source_scope: "FINALIZED_1M_MARKET_DERIVED_FEATURES".into(),
        normalized_structural_regime_entropy: Some(normalized_regime_entropy),
        components,
        external_features: ExternalBehavioralFeatures::unavailable(),
        behavioral_regime,
        market_emotion_proxy: MarketEmotionProxyPublication::default(),
        price_flow_feature_coverage_ratio,
        required_domain_coverage_ratio,
        missing_required_domains,
        warnings,
        combined_sentiment_regime_status: "BLOCKED_NO_POINT_IN_TIME_EXTERNAL_SENTIMENT_AND_NO_PROMOTED_FUSION_ARTIFACT".into(),
        analog_integration_status: "NOT_INCLUDED_IN_FROZEN_ANALOG_DISTANCE_REQUIRES_HISTORICAL_MATERIALIZATION_NEW_ARTIFACT_PURGED_WALK_FORWARD_AND_FORWARD_SHADOW".into(),
        artifact_status: "HEURISTIC_RESEARCH_LAYER_NO_TRAINED_OR_PROMOTED_ARTIFACT".into(),
        affects_decision: false,
        probability_semantics: "CALIBRATED_BEHAVIOR_OR_AGGREGATE_RESPONSE_PROBABILITIES_UNAVAILABLE".into(),
    };
    layer.refresh_market_emotion_publication();
    Ok(layer)
}
#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{NaiveDate, TimeZone};

    fn state() -> MarketState {
        MarketState {
            timestamp: Utc.with_ymd_and_hms(2026, 7, 24, 19, 0, 0).unwrap(),
            session_date: NaiveDate::from_ymd_opt(2026, 7, 24).unwrap(),
            symbol: "SPY".into(),
            open: 100.0,
            high: 101.0,
            low: 98.0,
            close: 99.0,
            atr: 0.01,
            ret_1m: -0.003,
            ret_3m: -0.006,
            ret_5m: -0.012,
            ret_15m: -0.018,
            ret_30m: -0.015,
            ret_60m: -0.010,
            active_5m_return: -0.012,
            last_completed_5m_return: -0.008,
            last_completed_15m_return: -0.012,
            slope_15m: -0.002,
            dist_vwap: -0.008,
            dist_session_open: -0.01,
            rolling_realized_vol: 0.004,
            normalized_range: 0.012,
            upper_wick_ratio: 0.1,
            lower_wick_ratio: 0.2,
            close_location_value: -0.7,
            distance_session_high: -0.02,
            distance_session_low: 0.002,
            failed_opening_breakout: 1.0,
            consecutive_up_bars: 0,
            consecutive_down_bars: 4,
            return_acceleration: -1.0,
            volume_zscore: 2.2,
            volume_acceleration: 1.2,
            session_range_position: 0.15,
            cross_asset_breadth_score: -2.0,
            risk_rotation_score: -1.5,
            market_confirmation_score: -1.8,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: 0.1,
            rvol_same_minute: 2.0,
            minutes_from_open: 330,
            minutes_to_close: 60,
            bucket_5m: 66,
            bucket_15m: 22,
            minute_in_5m_bucket: 0,
            completed_5m_bucket_valid: true,
            continuous_minute_count: 330,
        }
    }

    #[test]
    fn selloff_shape_raises_stress_without_actor_or_probability_claims() {
        let state = state();
        let layer =
            derive_price_flow_behavioral_state(&state, state.timestamp + Duration::minutes(1), 0.2)
                .unwrap();
        assert_eq!(
            layer.availability,
            BehavioralAvailability::PartialPriceFlowOnly
        );
        assert!(
            layer.components.downside_stress.raw_index.unwrap()
                > layer.components.upside_chase.raw_index.unwrap()
        );
        assert!(layer.components.deleveraging_like.raw_index.unwrap() > 50.0);
        assert!(!layer.affects_decision);
        assert!(
            layer
                .behavioral_regime
                .raw_scores
                .iter()
                .all(|row| row.calibrated_probability.is_none())
        );
        assert_eq!(layer.market_emotion_proxy.publication_status, "WITHHELD");
        assert!(
            layer
                .market_emotion_proxy
                .reason_codes
                .contains(&"PROVIDER_AVAILABILITY_NOT_VERIFIED".to_string())
        );
        let encoded = serde_json::to_string(&layer).unwrap().to_ascii_lowercase();
        assert!(!encoded.contains("dominant_actor"));
        assert!(!encoded.contains("actor_pressures"));
        assert!(!encoded.contains("dealer_position"));
    }

    #[test]
    fn missing_cross_asset_context_is_not_treated_as_observed_zero() {
        let mut first = state();
        first.cross_asset_context_complete = false;
        first.cross_asset_context_coverage = 5.0 / 6.0;
        first.cross_asset_breadth_score = -4.0;
        first.risk_rotation_score = -4.0;
        first.market_confirmation_score = -4.0;
        let mut second = first.clone();
        second.cross_asset_breadth_score = 4.0;
        second.risk_rotation_score = 4.0;
        second.market_confirmation_score = 4.0;
        let cutoff = first.timestamp + Duration::minutes(1);
        let first_layer = derive_price_flow_behavioral_state(&first, cutoff, 0.2).unwrap();
        let second_layer = derive_price_flow_behavioral_state(&second, cutoff, 0.2).unwrap();
        assert_eq!(first_layer.components, second_layer.components);
        assert!(
            first_layer
                .missing_required_domains
                .contains(&"CROSS_ASSET_CONTEXT".to_string())
        );
        assert!(first_layer.price_flow_feature_coverage_ratio < 1.0);
    }

    #[test]
    fn actual_provider_availability_must_align_with_bar_cutoff() {
        let state = state();
        let cutoff = state.timestamp + Duration::minutes(1);
        let mut layer = derive_price_flow_behavioral_state(&state, cutoff, 0.2).unwrap();
        assert!(layer.latest_input_available_at.is_none());
        assert!(
            layer
                .attach_verified_bar_availability(
                    cutoff + Duration::seconds(2),
                    "MASSIVE_SIP:stocks-ws-am-v1",
                )
                .is_ok()
        );
        assert_eq!(
            layer.latest_input_available_at,
            Some(cutoff + Duration::seconds(2))
        );
        assert_eq!(
            layer.market_emotion_proxy.publication_status,
            "AVAILABLE_PARTIAL_PRICE_FLOW_PROXY"
        );
        assert!(
            layer
                .market_emotion_proxy
                .raw_compatibility_index
                .is_some_and(|value| (0.0..=100.0).contains(&value))
        );
        assert!(layer.market_emotion_proxy.calibrated_probability.is_none());
        assert!(layer.market_emotion_proxy.not_probability);
        assert!(!layer.market_emotion_proxy.affects_decision);
        assert!(
            layer
                .attach_verified_bar_availability(
                    cutoff + Duration::minutes(1),
                    "MASSIVE_SIP:stocks-ws-am-v1",
                )
                .is_err()
        );
    }

    #[test]
    fn noncausal_nonfinite_and_false_complete_coverage_fail_closed() {
        let mut state = state();
        assert!(derive_price_flow_behavioral_state(&state, state.timestamp, 0.2).is_err());
        state.volume_zscore = f64::NAN;
        assert!(
            derive_price_flow_behavioral_state(
                &state,
                state.timestamp + Duration::minutes(1),
                0.2,
            )
            .is_err()
        );
        state.volume_zscore = 0.0;
        state.cross_asset_context_coverage = 0.5;
        assert!(
            derive_price_flow_behavioral_state(
                &state,
                state.timestamp + Duration::minutes(1),
                0.2,
            )
            .is_err()
        );
    }

    #[test]
    fn incomplete_cross_asset_context_withholds_public_emotion_value() {
        let mut state = state();
        state.cross_asset_context_complete = false;
        state.cross_asset_context_coverage = 5.0 / 6.0;
        let cutoff = state.timestamp + Duration::minutes(1);
        let mut layer = derive_price_flow_behavioral_state(&state, cutoff, 0.2).unwrap();
        layer
            .attach_verified_bar_availability(
                cutoff + Duration::seconds(2),
                "MASSIVE_SIP:stocks-ws-am-v1",
            )
            .unwrap();
        assert_eq!(layer.market_emotion_proxy.publication_status, "WITHHELD");
        assert!(
            layer
                .market_emotion_proxy
                .reason_codes
                .contains(&"PRICE_FLOW_OR_CROSS_ASSET_COVERAGE_INCOMPLETE".to_string())
        );
        assert!(
            layer
                .market_emotion_proxy
                .dominant_market_response_pattern
                .is_none()
        );
        assert!(layer.market_emotion_proxy.raw_compatibility_index.is_none());
    }

    #[test]
    fn low_pattern_separation_is_not_published_as_a_dominant_emotion() {
        let state = state();
        let cutoff = state.timestamp + Duration::minutes(1);
        let mut layer = derive_price_flow_behavioral_state(&state, cutoff, 0.2).unwrap();
        layer.behavioral_regime.score_margin = Some(MINIMUM_PUBLIC_SCORE_MARGIN - 0.01);
        layer
            .attach_verified_bar_availability(
                cutoff + Duration::seconds(2),
                "MASSIVE_SIP:stocks-ws-am-v1",
            )
            .unwrap();
        assert_eq!(layer.market_emotion_proxy.publication_status, "WITHHELD");
        assert!(
            layer
                .market_emotion_proxy
                .reason_codes
                .contains(&"LOW_PATTERN_SEPARATION".to_string())
        );
        assert!(
            layer
                .market_emotion_proxy
                .dominant_market_response_pattern
                .is_none()
        );
    }

    #[test]
    fn legacy_payload_default_is_unavailable_and_decision_neutral() {
        let layer = BehavioralStateLayer::default();
        assert_eq!(layer.availability, BehavioralAvailability::Unavailable);
        assert!(layer.latest_input_available_at.is_none());
        assert!(!layer.affects_decision);
        assert_eq!(layer.required_domain_coverage_ratio, 0.0);
        assert_eq!(layer.market_emotion_proxy.publication_status, "WITHHELD");
        assert!(layer.market_emotion_proxy.not_probability);
    }
}
