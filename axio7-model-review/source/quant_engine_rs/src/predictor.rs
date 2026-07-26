use std::collections::{BTreeMap, BTreeSet, HashMap};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::{
    analog_engine::{
        AnalogDiagnostics, AnalogEngine, AnalogEngineConfig, AnalogForecast, BandwidthRule,
        DistanceMetric, FeatureSimilarity, RegimeMatchPolicy, SensitivityPoint,
    },
    config::{QuantOsConfig, RegimeResearchConfig, ResearchConfig},
    data::capability::DataCapabilityReport,
    domain::{MarketState, OptionQuote},
    engine::{
        behavioral_state::{BehavioralStateLayer, derive_price_flow_behavioral_state},
        closing_short_cover::{
            ClosingShortCoverHazardConfig, ClosingShortCoverHazardForecast,
            forecast as forecast_closing_short_cover_hazard,
        },
        gamma_convexity::{
            GammaConvexityFeedbackRisk, GammaConvexityRequest, gamma_convexity_feedback_risk,
        },
        labels,
        regime::GaussianHmm,
        short_horizon::{
            CausalMomentumObservation, CausalRegimeInterval, HorizonDistributionForecast,
            MomentumHeadOutput, MomentumQuery, RegimeConditionedShortHorizonModel,
            ShortHorizonConfig, ShortHorizonForecastRequest, ShortHorizonReason, fit_momentum_head,
            fit_regime_conditioned_model,
        },
    },
    os_domain::stable_id,
    probability_calibration::{
        CalibrationRegistrySource, CalibrationRequest, ProbabilityCalibrationRuntime,
        ProbabilityEstimateInterval, wilson_score_interval_95,
    },
};

pub(crate) const KERNEL_RETURN_DEFINITION: &str = "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN";
pub(crate) const CURRENT_CLOSE_SCENARIO_BASIS: &str =
    "FINALIZED_CURRENT_1M_CLOSE_TIMES_ONE_PLUS_NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN";
pub(crate) const CURRENT_CLOSE_SCENARIO_STATUS: &str =
    "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST";
pub(crate) const CURRENT_CLOSE_SCENARIO_SEMANTICS: &str = "ARITHMETIC_CURRENT_CLOSE_REFERENCE_SCENARIO; LABEL_ENTRY_PRICE_IS_NEXT_MINUTE_OPEN_AND_IS_UNKNOWN_AT_OBSERVATION_CUTOFF; NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct QuantilePoint {
    pub probability: f64,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
pub struct DirectionProbabilityIntervals {
    pub up: Option<ProbabilityEstimateInterval>,
    pub flat: Option<ProbabilityEstimateInterval>,
    pub down: Option<ProbabilityEstimateInterval>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OutcomePredictionInterval {
    pub probability_mass: f64,
    pub lower_return: f64,
    pub upper_return: f64,
    /// Legacy ambiguous price projection. Withheld in contract v4.4.
    #[serde(default)]
    pub lower_price: Option<f64>,
    /// Legacy ambiguous price projection. Withheld in contract v4.4.
    #[serde(default)]
    pub upper_price: Option<f64>,
    #[serde(default)]
    pub current_close_reference_scenario_lower_price: f64,
    #[serde(default)]
    pub current_close_reference_scenario_upper_price: f64,
    #[serde(default)]
    pub current_close_reference_scenario_basis: String,
    #[serde(default)]
    pub current_close_reference_scenario_status: String,
    #[serde(default)]
    pub current_close_reference_scenario_semantics: String,
    pub method: String,
    pub status: String,
    pub semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KernelRegressionEvidence {
    pub status: String,
    pub feature_dimension_count: usize,
    pub selected_dimensions: Vec<String>,
    pub metric: String,
    pub kernel: String,
    pub bandwidth: f64,
    pub neighbor_count: usize,
    pub effective_sample_size: f64,
    pub minimum_effective_sample_size: f64,
    pub nadaraya_watson_expected_return: f64,
    pub local_linear_intercept: f64,
    pub direction_event_threshold_return: f64,
    pub direction_probability_intervals: DirectionProbabilityIntervals,
    pub probability_status: String,
    pub probability_semantics: String,
}

impl Default for KernelRegressionEvidence {
    fn default() -> Self {
        Self {
            status: "NOT_EVALUATED_LEGACY_PAYLOAD".into(),
            feature_dimension_count: 0,
            selected_dimensions: Vec::new(),
            metric: "UNAVAILABLE".into(),
            kernel: "UNAVAILABLE".into(),
            bandwidth: 0.0,
            neighbor_count: 0,
            effective_sample_size: 0.0,
            minimum_effective_sample_size: 0.0,
            nadaraya_watson_expected_return: 0.0,
            local_linear_intercept: 0.0,
            direction_event_threshold_return: 0.0,
            direction_probability_intervals: DirectionProbabilityIntervals::default(),
            probability_status: "UNAVAILABLE".into(),
            probability_semantics: "NO_PROBABILITY_ESTIMATE_INTERVAL_AVAILABLE".into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BarrierProbabilities {
    pub upper_first: Option<f64>,
    pub lower_first: Option<f64>,
    pub neither: Option<f64>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForecastAnalogEvidence {
    /// Canonical Market Memory identity. It remains None until the analog row
    /// has been resolved against the immutable Market Memory store.
    #[serde(default)]
    pub market_snapshot_id: Option<String>,
    /// Deterministic identity emitted by the retrieval engine. This remains
    /// distinct from a canonical immutable Market Memory foreign key.
    #[serde(default)]
    pub retrieval_snapshot_id: Option<String>,
    /// Deterministic trace identity for legacy analog rows. This is explicitly
    /// not a MarketSnapshot ID and must never be used as a foreign key.
    pub derived_trace_id: String,
    pub rank: usize,
    pub analog_timestamp: DateTime<Utc>,
    #[serde(default)]
    pub session_date: Option<NaiveDate>,
    pub distance: f64,
    pub weight: f64,
    #[serde(default)]
    pub regime_similarity: Option<f64>,
    #[serde(default)]
    pub feature_similarity: Vec<FeatureSimilarity>,
    #[serde(default)]
    pub subsequent_realized_path: Vec<f64>,
    pub forward_return: f64,
    pub mfe: f64,
    pub mae: f64,
    #[serde(default)]
    pub label_available_at: Option<DateTime<Utc>>,
    pub path_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DecisionPolicyResult {
    pub action: String,
    pub eligible: bool,
    pub expected_edge_after_cost: f64,
    pub no_trade_reasons: Vec<String>,
    pub policy_version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RegimeCandidateScore {
    pub state_count: usize,
    pub training_bic: Option<f64>,
    pub validation_average_log_likelihood: Option<f64>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RegimeModelSelection {
    pub candidate_state_counts: Vec<usize>,
    pub selected_state_count: usize,
    pub selection_criterion: String,
    pub fit_session_count: usize,
    pub validation_session_count: usize,
    pub candidate_scores: Vec<RegimeCandidateScore>,
    pub eight_state_challenger_status: String,
    pub selected_at_candidate_boundary: bool,
    pub selection_warning: Option<String>,
    pub probability_semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResearchOnlyPolicy {
    pub product_scope: String,
    pub personalization_used: bool,
    pub user_portfolio_inputs_used: bool,
    pub investment_advice: bool,
    pub execution_instruction: bool,
    pub disclaimer: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct UnavailableResearchHorizon {
    pub horizon_minutes: usize,
    pub status: String,
    pub validation_flags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForecastRegimeContext {
    pub as_of: DateTime<Utc>,
    /// Root context is descriptive context at the newest actual feature query.
    /// Each forecast contract has its own horizon-safe query cutoff.
    #[serde(default)]
    pub query_semantics: String,
    #[serde(default)]
    pub observation_cadence_minutes: usize,
    #[serde(default)]
    pub session_reset: bool,
    pub filtered_state_probabilities: Vec<f64>,
    pub next_state_probabilities: Vec<f64>,
    #[serde(default)]
    pub next_state_probability_status: String,
    #[serde(default)]
    pub cross_session_state_forecast_status: String,
    /// Compatibility summary: `true` records the raw-entropy hard veto;
    /// the explicit continuous-sizing field remains false.
    #[serde(default)]
    pub direct_allocation_impact: bool,
    #[serde(default)]
    pub continuous_sizing_impact: bool,
    #[serde(default)]
    pub hard_no_trade_veto_impact: bool,
    pub state_entropy: f64,
    pub normalized_state_entropy: f64,
    pub dominant_raw_state: usize,
    pub dominant_probability: f64,
    pub model_selection: RegimeModelSelection,
    pub probability_semantics: String,
}

impl Default for ResearchOnlyPolicy {
    fn default() -> Self {
        Self {
            product_scope: "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH".into(),
            personalization_used: false,
            user_portfolio_inputs_used: false,
            investment_advice: false,
            execution_instruction: false,
            disclaimer: "Mathematical market research only; not personalized investment advice, an order, or an execution instruction.".into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForecastContract {
    pub prediction_id: String,
    pub created_at: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub as_of: DateTime<Utc>,
    pub decision_as_of: DateTime<Utc>,
    pub latest_input_available_at: DateTime<Utc>,
    pub earliest_executable_time: DateTime<Utc>,
    pub symbol: String,
    pub timeframe: String,
    pub horizon_minutes: usize,
    pub label_start: DateTime<Utc>,
    pub label_end: DateTime<Utc>,
    pub session: String,
    pub timezone: String,
    pub reference_price: f64,
    pub reference_price_source: String,
    /// Raw underlying expectation. Strategy direction is stored separately so
    /// a short forecast cannot be mistaken for an upward price forecast.
    pub expected_return: f64,
    /// Legacy label-aligned price expectation. Withheld in contract v4.4
    /// because the next-minute entry open is unknown at the observation cutoff.
    #[serde(default)]
    pub expected_price: Option<f64>,
    #[serde(default)]
    pub return_definition: String,
    /// Arithmetic reference scenario only. This is deliberately not described
    /// as an expected executable or label-aligned price.
    #[serde(default)]
    pub current_close_reference_scenario_expected_price: f64,
    #[serde(default)]
    pub current_close_reference_scenario_price_quantiles: Vec<QuantilePoint>,
    #[serde(default)]
    pub current_close_reference_scenario_basis: String,
    #[serde(default)]
    pub current_close_reference_scenario_status: String,
    #[serde(default)]
    pub current_close_reference_scenario_semantics: String,
    pub median_return: f64,
    pub return_quantiles: Vec<QuantilePoint>,
    /// Legacy ambiguous price quantiles. Empty in contract v4.4.
    pub price_quantiles: Vec<QuantilePoint>,
    /// Published only when a matching promoted OOS binary-up calibrator exists.
    /// A binary-up calibrator does not establish calibrated down/flat values.
    #[serde(default)]
    pub p_up: Option<f64>,
    #[serde(default)]
    pub p_down: Option<f64>,
    #[serde(default)]
    pub p_flat: Option<f64>,
    /// Uncalibrated kernel-weighted historical frequency above the
    /// cost-adjusted positive-return threshold.
    #[serde(default)]
    pub raw_analog_up_frequency: f64,
    #[serde(default)]
    pub raw_analog_down_frequency: f64,
    #[serde(default)]
    pub raw_analog_flat_frequency: f64,
    /// Present only when a separately materialized, lifecycle-promoted OOS
    /// artifact exactly matches this horizon/model/feature contract.
    #[serde(default)]
    pub calibrated_probability_up: Option<f64>,
    #[serde(default)]
    pub probability_calibration: ProbabilityCalibrationRuntime,
    #[serde(default)]
    pub suggested_direction: i8,
    #[serde(default)]
    pub strategy_win_probability: Option<f64>,
    #[serde(default)]
    pub kernel_regression: KernelRegressionEvidence,
    #[serde(default)]
    pub outcome_prediction_intervals: Vec<OutcomePredictionInterval>,
    pub expected_volatility: f64,
    pub expected_absolute_move: f64,
    pub mfe_distribution: Vec<QuantilePoint>,
    pub mae_distribution: Vec<QuantilePoint>,
    pub barrier_probabilities: BarrierProbabilities,
    pub filtered_state_probabilities: Vec<f64>,
    pub predicted_state_probabilities: Vec<f64>,
    pub state_entropy: Option<f64>,
    #[serde(default)]
    pub dominant_regime_state: Option<usize>,
    #[serde(default)]
    pub dominant_regime_probability: Option<f64>,
    #[serde(default)]
    pub regime_model_selection: Option<RegimeModelSelection>,
    #[serde(default)]
    pub stochastic_research_layer: StochasticResearchLayer,
    pub epistemic_uncertainty: f64,
    pub ood_score: f64,
    #[serde(default)]
    pub market_snapshot_id: Option<String>,
    #[serde(default)]
    pub snapshot_link_status: String,
    #[serde(default)]
    pub top_analogs: Vec<ForecastAnalogEvidence>,
    #[serde(default)]
    pub analog_effective_sample_size: f64,
    #[serde(default)]
    pub analog_similarity_score: f64,
    #[serde(default)]
    pub analog_max_day_weight: f64,
    #[serde(default)]
    pub analog_concentration_penalty: f64,
    #[serde(default)]
    pub analog_engine_status: String,
    #[serde(default)]
    pub analog_metric: String,
    #[serde(default)]
    pub analog_bandwidth: f64,
    #[serde(default)]
    pub analog_diagnostics: Option<AnalogDiagnostics>,
    #[serde(default)]
    pub analog_sensitivity: Vec<SensitivityPoint>,
    pub model_id: String,
    pub model_hash: String,
    pub feature_version: String,
    pub feature_hash: String,
    pub data_source: String,
    pub data_capability_level: String,
    #[serde(default)]
    pub market_coverage: String,
    #[serde(default)]
    pub model_trained_through: String,
    #[serde(default)]
    pub target_status: String,
    pub data_manifest_hash: String,
    pub evidence_grade: String,
    pub evidence_kind: String,
    pub sample_size: usize,
    pub calibration_status: String,
    pub availability_semantics: String,
    pub decision: DecisionPolicyResult,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StochasticResearchLayer {
    pub status: String,
    pub model_family: String,
    pub fit_as_of: Option<DateTime<Utc>>,
    pub observation_cutoff: Option<DateTime<Utc>>,
    pub training_window_sessions: usize,
    pub training_observation_count: usize,
    pub base_interval_minutes: Option<u32>,
    pub horizon_forecast: Option<HorizonDistributionForecast>,
    pub momentum_head: Option<MomentumHeadOutput>,
    #[serde(default)]
    pub closing_short_cover_hazard: ClosingShortCoverHazardForecast,
    pub warnings: Vec<ShortHorizonReason>,
    pub rejection_reasons: Vec<ShortHorizonReason>,
    pub martingale_audit_status: String,
    pub affects_decision: bool,
    pub probability_semantics: String,
    pub research_policy: String,
}

impl Default for StochasticResearchLayer {
    fn default() -> Self {
        Self {
            status: "NOT_EVALUATED_LEGACY_PAYLOAD".into(),
            model_family: "MARKOV_SWITCHING_LOG_RETURN_DIFFUSION+VWAP_RESIDUAL_OU+MOMENTUM_SHADOW"
                .into(),
            fit_as_of: None,
            observation_cutoff: None,
            training_window_sessions: 0,
            training_observation_count: 0,
            base_interval_minutes: None,
            horizon_forecast: None,
            momentum_head: None,
            closing_short_cover_hazard: ClosingShortCoverHazardForecast::default(),
            warnings: Vec::new(),
            rejection_reasons: Vec::new(),
            martingale_audit_status: "NOT_RUN_UNTIL_APPEND_ONLY_SETTLED_FORWARD_RESIDUALS".into(),
            affects_decision: false,
            probability_semantics: "FILTERED_REGIME_POSTERIORS_ONLY; NO_FULL_SAMPLE_SMOOTHING"
                .into(),
            research_policy: "RESEARCH_ONLY_SHADOW_COMPARISON; NEVER_AUTHORIZES_AN_ORDER".into(),
        }
    }
}

fn default_gamma_convexity_layer() -> GammaConvexityFeedbackRisk {
    let as_of = DateTime::<Utc>::UNIX_EPOCH;
    gamma_convexity_feedback_risk(
        &[],
        &GammaConvexityRequest {
            as_of,
            underlying: "UNAVAILABLE".into(),
            spot: 0.0,
            contract_multiplier: 1.0,
            oi_as_of: None,
            greeks_as_of: None,
            max_quote_age_seconds: 0,
            max_oi_age_seconds: 0,
            max_greeks_age_seconds: 0,
        },
    )
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForecastBundle {
    pub generated_at: DateTime<Utc>,
    pub status: String,
    pub forecast_contract_version: String,
    pub prediction_layer: Vec<ForecastContract>,
    #[serde(default)]
    pub unavailable_horizons: Vec<UnavailableResearchHorizon>,
    #[serde(default)]
    pub regime_context: Option<ForecastRegimeContext>,
    #[serde(default = "default_gamma_convexity_layer")]
    pub gamma_convexity_layer: GammaConvexityFeedbackRisk,
    #[serde(default)]
    pub behavioral_state_layer: BehavioralStateLayer,
    pub option_surface_layer: serde_json::Value,
    pub option_execution_layer: serde_json::Value,
    #[serde(default)]
    pub research_only_policy: ResearchOnlyPolicy,
    pub conclusions: Vec<String>,
}

#[derive(Debug)]
struct HmmContext {
    model: GaussianHmm,
    filtered: Vec<f64>,
    filtered_history: Vec<Vec<f64>>,
    entropy: f64,
    model_hash: String,
    selection: RegimeModelSelection,
}

pub const FROZEN_PREDICTOR_ARTIFACT_VERSION: &str = "axio.frozen-predictor.v1";
pub const LEGACY_FROZEN_PREDICTOR_MODEL_VERSION: &str =
    "same-regime-kernel+cv-selected-hmm-frozen-v1";
pub const FROZEN_PREDICTOR_MODEL_VERSION: &str =
    "same-regime-kernel+cv-selected-hmm+regime-sde-shadow-frozen-v2";
pub const FROZEN_FEATURE_SCHEMA_VERSION: &str =
    "point-in-time-v4-strict-context+frozen-hmm+analog12";

const FROZEN_FEATURE_SCHEMA: [&str; 16] = [
    "hmm.active_5m_return",
    "hmm.dist_vwap",
    "hmm.rolling_realized_vol",
    "hmm.volume_zscore",
    "analog.ret_1m",
    "analog.ret_5m",
    "analog.ret_15m",
    "analog.vwap_distance",
    "analog.realized_volatility",
    "analog.normalized_range",
    "analog.volume_zscore",
    "analog.rvol",
    "analog.session_range_position",
    "analog.cross_asset_breadth",
    "analog.slope_15m",
    "analog.minute_of_session",
];

/// Immutable model package written only by the offline training command.
/// Every field required for inference is materialized; live code must never
/// call an estimator's `fit` method to repair or complete this artifact.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrozenPredictorArtifact {
    pub artifact_version: String,
    pub artifact_sha256: String,
    pub model_version: String,
    pub model_hash: String,
    pub created_at: DateTime<Utc>,
    pub training_cutoff: DateTime<Utc>,
    pub target: String,
    pub feature_schema_version: String,
    pub feature_schema_sha256: String,
    pub research_model_config_sha256: String,
    pub calibration_version: String,
    pub calibration_ref: Option<String>,
    pub training_dataset_manifest: Vec<String>,
    pub training_dataset_hash: String,
    pub code_commit_hash: String,
    pub training_state_count: usize,
    pub training_state_prefix_sha256: String,
    pub hmm: GaussianHmm,
    pub regime_selection: RegimeModelSelection,
    pub analog_engine: AnalogEngine,
    /// Frozen, causally fitted stochastic-distribution head. Legacy v1
    /// artifacts omit this field and remain readable, but expose no SDE
    /// forecast. The head is research-only and cannot affect the decision
    /// policy without a separately promoted validation artifact.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub short_horizon_model: Option<RegimeConditionedShortHorizonModel>,
}

fn sha256_serialized(value: &impl Serialize) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

fn frozen_feature_schema_hash() -> Result<String> {
    sha256_serialized(&FROZEN_FEATURE_SCHEMA)
}

fn research_model_config_hash(research: &ResearchConfig) -> Result<String> {
    sha256_serialized(&serde_json::json!({
        "target": research.target.to_ascii_uppercase(),
        "analog_neighbors": research.analog_neighbors,
        "analog_bandwidth": research.analog_bandwidth,
        "regime": research.regime,
        "feature_schema_version": FROZEN_FEATURE_SCHEMA_VERSION,
    }))
}

fn training_prefix<'a>(
    states: &'a [MarketState],
    target: &str,
    cutoff: DateTime<Utc>,
) -> Vec<&'a MarketState> {
    states
        .iter()
        .filter(|state| {
            state.symbol.eq_ignore_ascii_case(target)
                && state.timestamp + Duration::minutes(1) <= cutoff
        })
        .collect()
}

fn training_prefix_hash(
    states: &[MarketState],
    target: &str,
    cutoff: DateTime<Utc>,
) -> Result<String> {
    sha256_serialized(&training_prefix(states, target, cutoff))
}

fn analog_engine_config(research: &ResearchConfig) -> AnalogEngineConfig {
    AnalogEngineConfig {
        metric: DistanceMetric::ShrinkageMahalanobis,
        neighbors: research.analog_neighbors,
        bandwidth_rule: BandwidthRule::AdaptiveKthNeighbor,
        bandwidth_multiplier: research.analog_bandwidth,
        regime_conditioned: true,
        regime_match_policy: if research.regime.require_same_dominant_state {
            RegimeMatchPolicy::SameDominantAndPosteriorCosine
        } else {
            RegimeMatchPolicy::PosteriorCosine
        },
        minimum_regime_similarity: research.regime.minimum_posterior_cosine_similarity,
        minimum_dominant_regime_probability: research.regime.minimum_dominant_probability,
        minimum_effective_sample_size: research.regime.minimum_effective_sample_size,
        ..AnalogEngineConfig::default()
    }
}

impl FrozenPredictorArtifact {
    fn unsigned_sha256(&self) -> Result<String> {
        let mut unsigned = self.clone();
        unsigned.artifact_sha256.clear();
        let canonical: serde_json::Value = serde_json::from_slice(&serde_json::to_vec(&unsigned)?)?;
        sha256_serialized(&canonical)
    }

    pub fn validate_static(&self) -> Result<()> {
        if self.artifact_version != FROZEN_PREDICTOR_ARTIFACT_VERSION {
            bail!("unsupported frozen predictor artifact version");
        }
        if !matches!(
            self.model_version.as_str(),
            FROZEN_PREDICTOR_MODEL_VERSION | LEGACY_FROZEN_PREDICTOR_MODEL_VERSION
        ) || self.target.trim().is_empty()
            || self.code_commit_hash.trim().is_empty()
            || self.training_dataset_hash.trim().is_empty()
            || self.training_dataset_manifest.is_empty()
            || self.training_state_count < 20
        {
            bail!("frozen predictor identity or lineage is incomplete");
        }
        if self.feature_schema_version != FROZEN_FEATURE_SCHEMA_VERSION
            || self.feature_schema_sha256 != frozen_feature_schema_hash()?
        {
            bail!("frozen predictor feature schema mismatch");
        }
        crate::market_state::validate_model_artifact(&self.hmm)?;
        if self.hmm.states != self.regime_selection.selected_state_count {
            bail!("frozen HMM does not match persisted regime selection");
        }
        if self.analog_engine.frozen_training_index_count() != self.training_state_count {
            bail!("frozen analog index count does not match training state count");
        }
        if self.model_version == FROZEN_PREDICTOR_MODEL_VERSION {
            let model = self
                .short_horizon_model
                .as_ref()
                .context("v2 frozen predictor is missing its stochastic distribution head")?;
            if model.fit_as_of > self.training_cutoff
                || model.observation_cutoff > self.training_cutoff
                || model.base_interval_minutes != 1
                || model.training_observation_count < 100
            {
                bail!("frozen stochastic distribution head has invalid causal lineage");
            }
        }
        if self.artifact_sha256 != self.unsigned_sha256()? {
            bail!("frozen predictor artifact hash mismatch");
        }
        Ok(())
    }

    pub fn validate_for_inference(
        &self,
        states: &[MarketState],
        research: &ResearchConfig,
        capability: &DataCapabilityReport,
        query_cutoff: DateTime<Utc>,
    ) -> Result<()> {
        self.validate_static()?;
        if !self.target.eq_ignore_ascii_case(&research.target) {
            bail!("frozen predictor target mismatch");
        }
        if self.research_model_config_sha256 != research_model_config_hash(research)? {
            bail!("frozen predictor research model config mismatch");
        }
        let current_dataset_hash = capability
            .normalized_file_sha256
            .as_deref()
            .or_else(|| capability.manifest_hashes.last().map(String::as_str))
            .context("runtime data manifest hash is missing")?;
        if current_dataset_hash != self.training_dataset_hash {
            bail!("runtime data manifest does not match frozen training dataset");
        }
        if query_cutoff <= self.training_cutoff {
            bail!("frozen predictor cutoff is not before the inference query");
        }
        let prefix = training_prefix(states, &self.target, self.training_cutoff);
        if prefix.len() != self.training_state_count
            || training_prefix_hash(states, &self.target, self.training_cutoff)?
                != self.training_state_prefix_sha256
        {
            bail!("runtime feature-state prefix does not match frozen training prefix");
        }
        self.analog_engine
            .validate_frozen(states, self.training_cutoff)?;
        Ok(())
    }
}

fn weighted_quantile(mut values: Vec<(f64, f64)>, probability: f64) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    values.sort_by(|a, b| a.0.total_cmp(&b.0));
    let total = values.iter().map(|(_, w)| *w).sum::<f64>().max(1e-12);
    let mut cumulative = 0.0;
    for (value, weight) in &values {
        cumulative += *weight / total;
        if cumulative >= probability {
            return *value;
        }
    }
    values.last().unwrap().0
}

fn quantiles(values: &[(f64, f64)]) -> Vec<QuantilePoint> {
    [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]
        .into_iter()
        .map(|probability| QuantilePoint {
            probability,
            value: weighted_quantile(values.to_vec(), probability),
        })
        .collect()
}

fn raw_kernel_probability_interval(
    estimate: f64,
    effective_sample_size: f64,
) -> Option<ProbabilityEstimateInterval> {
    wilson_score_interval_95(estimate, effective_sample_size)
        .ok()
        .map(|mut interval| {
            interval.status = "EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON".into();
            interval.semantics =
                "UNCALIBRATED_KERNEL_WEIGHTED_HISTORICAL_FREQUENCY_95_PERCENT_ESTIMATE_INTERVAL_USING_KISH_EFFECTIVE_SAMPLE_SIZE; NOT_AN_OOS_CALIBRATED_PROBABILITY; SERIAL_DEPENDENCE_MODEL_SELECTION_AND_DRIFT_UNCERTAINTY_EXCLUDED"
                    .into();
            interval
        })
}

fn empirical_outcome_prediction_intervals(
    weighted_quantiles: &BTreeMap<String, f64>,
    reference_price: f64,
) -> Vec<OutcomePredictionInterval> {
    [(0.80, "q10", "q90"), (0.90, "q05", "q95")]
        .into_iter()
        .filter_map(|(probability_mass, lower_key, upper_key)| {
            let lower_return = *weighted_quantiles.get(lower_key)?;
            let upper_return = *weighted_quantiles.get(upper_key)?;
            let lower_price = reference_price * (1.0 + lower_return);
            let upper_price = reference_price * (1.0 + upper_return);
            if !lower_return.is_finite()
                || !upper_return.is_finite()
                || lower_return > upper_return
                || !lower_price.is_finite()
                || !upper_price.is_finite()
                || lower_price <= 0.0
                || lower_price > upper_price
            {
                return None;
            }
            Some(OutcomePredictionInterval {
                probability_mass,
                lower_return,
                upper_return,
                lower_price: None,
                upper_price: None,
                current_close_reference_scenario_lower_price: lower_price,
                current_close_reference_scenario_upper_price: upper_price,
                current_close_reference_scenario_basis: CURRENT_CLOSE_SCENARIO_BASIS.into(),
                current_close_reference_scenario_status: CURRENT_CLOSE_SCENARIO_STATUS.into(),
                current_close_reference_scenario_semantics:
                    CURRENT_CLOSE_SCENARIO_SEMANTICS.into(),
                method: "KERNEL_WEIGHTED_HISTORICAL_ANALOG_QUANTILES".into(),
                status: "UNCALIBRATED_EMPIRICAL_CONDITIONAL_RANGE".into(),
                semantics:
                    "CENTRAL_HISTORICAL_ANALOG_OUTCOME_MASS_CONDITIONAL_ON_CURRENT_RETRIEVAL; NOT_A_CONFORMAL_INTERVAL_OR_FREQUENTIST_COVERAGE_GUARANTEE"
                        .into(),
            })
        })
        .collect()
}

fn normalized_regime_entropy(entropy: f64, state_count: usize) -> Option<f64> {
    if !entropy.is_finite() || state_count < 2 {
        return None;
    }
    Some((entropy / (state_count as f64).ln()).clamp(0.0, 1.0))
}

fn select_hmm_model(
    train: &[Vec<Vec<f64>>],
    config: &RegimeResearchConfig,
) -> Result<(GaussianHmm, RegimeModelSelection)> {
    if train.is_empty() {
        bail!("HMM model selection requires completed prior sessions");
    }
    let requested_validation = ((train.len() as f64) * config.validation_fraction).ceil() as usize;
    let validation_sessions = requested_validation
        .max(config.minimum_validation_sessions)
        .min(train.len().saturating_sub(1));
    let use_validation = validation_sessions >= config.minimum_validation_sessions
        && train.len() > validation_sessions;
    let fit_end = if use_validation {
        train.len() - validation_sessions
    } else {
        train.len()
    };
    let fit_sequences = &train[..fit_end];
    let validation_sequences = if use_validation {
        &train[fit_end..]
    } else {
        &[][..]
    };
    let mut scores = Vec::new();
    let mut selected: Option<(usize, f64)> = None;
    for state_count in &config.state_candidates {
        let result = GaussianHmm::fit(
            fit_sequences,
            *state_count,
            config.max_iterations,
            config.restarts,
        );
        match result {
            Ok(model) => {
                let validation_score = if use_validation {
                    model.average_log_likelihood(validation_sequences).ok()
                } else {
                    None
                };
                let criterion = validation_score.unwrap_or(-model.bic);
                let replace = selected
                    .as_ref()
                    .is_none_or(|(current_states, current_score)| {
                        criterion > *current_score + 1.0e-12
                            || ((criterion - *current_score).abs() <= 1.0e-12
                                && *state_count < *current_states)
                    });
                if replace {
                    selected = Some((*state_count, criterion));
                }
                scores.push(RegimeCandidateScore {
                    state_count: *state_count,
                    training_bic: model.bic.is_finite().then_some(model.bic),
                    validation_average_log_likelihood: validation_score,
                    status: if use_validation && validation_score.is_none() {
                        "VALIDATION_SCORING_FAILED".into()
                    } else if use_validation {
                        "CHRONOLOGICAL_VALIDATION_SCORED".into()
                    } else {
                        "INSUFFICIENT_VALIDATION_SESSIONS_BIC_FALLBACK".into()
                    },
                });
            }
            Err(_) => scores.push(RegimeCandidateScore {
                state_count: *state_count,
                training_bic: None,
                validation_average_log_likelihood: None,
                status: "FIT_FAILED_OR_INSUFFICIENT_OBSERVATIONS".into(),
            }),
        }
    }
    let selected_state_count = selected
        .map(|(states, _)| states)
        .context("no HMM state-count candidate produced a finite model")?;
    let model = GaussianHmm::fit(
        train,
        selected_state_count,
        config.max_iterations,
        config.restarts,
    )
    .context("selected HMM could not be refit on all prior sessions")?;
    let (model, _) = model.canonicalized();
    let eight_score = scores.iter().find(|score| score.state_count == 8);
    let eight_state_challenger_status = if selected_state_count == 8 {
        "SELECTED_BY_CHRONOLOGICAL_MODEL_SELECTION"
    } else if eight_score.is_some_and(|score| {
        score.validation_average_log_likelihood.is_some() || score.training_bic.is_some()
    }) {
        "EVALUATED_NOT_SELECTED"
    } else {
        "FIT_FAILED_OR_INSUFFICIENT_OBSERVATIONS"
    };
    let selected_at_candidate_boundary = config
        .state_candidates
        .iter()
        .max()
        .is_some_and(|maximum| *maximum == selected_state_count);
    Ok((
        model,
        RegimeModelSelection {
            candidate_state_counts: config.state_candidates.clone(),
            selected_state_count,
            selection_criterion: if use_validation {
                "MAX_CHRONOLOGICAL_HELD_OUT_AVERAGE_LOG_LIKELIHOOD"
            } else {
                "MIN_TRAINING_BIC_FALLBACK_INSUFFICIENT_VALIDATION_SESSIONS"
            }
            .into(),
            fit_session_count: fit_end,
            validation_session_count: if use_validation {
                validation_sessions
            } else {
                0
            },
            candidate_scores: scores,
            eight_state_challenger_status: eight_state_challenger_status.into(),
            selected_at_candidate_boundary,
            selection_warning: selected_at_candidate_boundary.then(|| {
                "BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K; STATE_COUNT_OPTIMUM_IS_NOT_ESTABLISHED"
                    .into()
            }),
            probability_semantics: "FORWARD_FILTERED_P_ZT_GIVEN_X_1_TO_T; NO_FULL_SAMPLE_SMOOTHING"
                .into(),
        },
    ))
}

fn causal_filtered_history_for_frozen_hmm(
    states: &[MarketState],
    target: &str,
    hmm: &GaussianHmm,
) -> Result<Vec<Vec<f64>>> {
    let mut sessions = BTreeMap::<NaiveDate, Vec<(usize, Vec<f64>)>>::new();
    for (index, state) in states.iter().enumerate().filter(|(_, state)| {
        state.symbol.eq_ignore_ascii_case(target)
            && state.minute_in_5m_bucket == 4
            && state.completed_5m_bucket_valid
    }) {
        sessions.entry(state.session_date).or_default().push((
            index,
            vec![
                state.active_5m_return,
                state.dist_vwap,
                state.rolling_realized_vol,
                state.volume_zscore,
            ],
        ));
    }
    let mut finalized_probabilities = HashMap::<usize, Vec<f64>>::new();
    for rows in sessions.values() {
        let sequence = rows
            .iter()
            .map(|(_, observation)| observation.clone())
            .collect::<Vec<_>>();
        let filtered = hmm.filtered_probabilities(&sequence)?;
        for ((index, _), probabilities) in rows.iter().zip(filtered) {
            finalized_probabilities.insert(*index, probabilities);
        }
    }
    let mut history = vec![Vec::new(); states.len()];
    let mut active_session = None;
    let mut latest_filtered = Vec::new();
    for (index, state) in states.iter().enumerate() {
        if !state.symbol.eq_ignore_ascii_case(target) {
            continue;
        }
        if active_session != Some(state.session_date) {
            active_session = Some(state.session_date);
            latest_filtered.clear();
        }
        if let Some(probabilities) = finalized_probabilities.get(&index) {
            latest_filtered = probabilities.clone();
        }
        if !latest_filtered.is_empty() {
            history[index] = latest_filtered.clone();
        }
    }
    Ok(history)
}

fn fit_frozen_short_horizon_model(
    states: &[MarketState],
    target: &str,
    training_cutoff: DateTime<Utc>,
    hmm: &GaussianHmm,
) -> Result<RegimeConditionedShortHorizonModel> {
    let filtered_history = causal_filtered_history_for_frozen_hmm(states, target, hmm)?;
    let completed_sessions = states
        .iter()
        .filter(|state| {
            state.symbol.eq_ignore_ascii_case(target)
                && state.timestamp + Duration::minutes(1) <= training_cutoff
        })
        .map(|state| state.session_date)
        .collect::<BTreeSet<_>>();
    let earliest_session = completed_sessions
        .iter()
        .rev()
        .nth(SHORT_HORIZON_TRAINING_SESSIONS.saturating_sub(1))
        .copied()
        .or_else(|| completed_sessions.first().copied())
        .context("stochastic artifact has no completed training session")?;
    let mut intervals = Vec::new();
    for index in 1..states.len() {
        let previous = &states[index - 1];
        let current = &states[index];
        if !current.symbol.eq_ignore_ascii_case(target)
            || !previous.symbol.eq_ignore_ascii_case(target)
            || current.session_date != previous.session_date
            || current.session_date < earliest_session
            || current.timestamp + Duration::minutes(1) > training_cutoff
            || current.timestamp != previous.timestamp + Duration::minutes(1)
        {
            continue;
        }
        let Some(filtered) = filtered_history
            .get(index)
            .filter(|probabilities| !probabilities.is_empty())
        else {
            continue;
        };
        let gross_return = current.close / previous.close;
        let gross_vwap_residual = 1.0 + current.dist_vwap;
        if !gross_return.is_finite()
            || gross_return <= 0.0
            || !gross_vwap_residual.is_finite()
            || gross_vwap_residual <= 0.0
        {
            continue;
        }
        intervals.push(CausalRegimeInterval {
            interval_start: current.timestamp,
            as_of: current.timestamp + Duration::minutes(1),
            available_at: current.timestamp + Duration::minutes(1),
            session_id: current.session_date.to_string(),
            log_return: gross_return.ln(),
            vwap_residual: gross_vwap_residual.ln(),
            filtered_regime_probabilities: filtered.clone(),
            filtered_transition_from_previous: None,
        });
    }
    let fit = fit_regime_conditioned_model(
        &intervals,
        training_cutoff,
        None,
        &ShortHorizonConfig::default(),
    );
    fit.model.with_context(|| {
        format!(
            "frozen stochastic distribution head rejected: {:?}",
            fit.rejection_reasons
        )
    })
}

pub fn train_frozen_artifact(
    states: &[MarketState],
    research: &ResearchConfig,
    capability: &DataCapabilityReport,
    created_at: DateTime<Utc>,
    code_commit_hash: &str,
) -> Result<FrozenPredictorArtifact> {
    if states.is_empty() || code_commit_hash.trim().is_empty() {
        bail!("frozen predictor training requires states and a code commit identity");
    }
    let target = research.target.to_ascii_uppercase();
    let completed_sessions = states
        .iter()
        .filter(|state| state.symbol.eq_ignore_ascii_case(&target))
        .fold(BTreeMap::<NaiveDate, i32>::new(), |mut sessions, state| {
            sessions
                .entry(state.session_date)
                .and_modify(|minimum| *minimum = (*minimum).min(state.minutes_to_close))
                .or_insert(state.minutes_to_close);
            sessions
        })
        .into_iter()
        .filter(|(_, minimum_minutes_to_close)| *minimum_minutes_to_close <= 1)
        .map(|(date, _)| date)
        .collect::<BTreeSet<_>>();
    if completed_sessions.len() < 2 {
        bail!("frozen predictor requires at least two completed sessions");
    }
    let completed_training_indices = states
        .iter()
        .enumerate()
        .filter(|(_, state)| {
            state.symbol.eq_ignore_ascii_case(&target)
                && completed_sessions.contains(&state.session_date)
        })
        .map(|(index, _)| index)
        .collect::<Vec<_>>();
    let training_cutoff = completed_training_indices
        .iter()
        .map(|index| states[*index].timestamp + Duration::minutes(1))
        .max()
        .context("completed sessions contain no training states")?;
    let training_indices = states
        .iter()
        .enumerate()
        .filter(|(_, state)| {
            state.symbol.eq_ignore_ascii_case(&target)
                && state.timestamp + Duration::minutes(1) <= training_cutoff
        })
        .map(|(index, _)| index)
        .collect::<Vec<_>>();
    let mut sequences_by_session = BTreeMap::<NaiveDate, Vec<Vec<f64>>>::new();
    for state in training_indices
        .iter()
        .map(|index| &states[*index])
        .filter(|state| {
            completed_sessions.contains(&state.session_date)
                && state.minute_in_5m_bucket == 4
                && state.completed_5m_bucket_valid
        })
    {
        sequences_by_session
            .entry(state.session_date)
            .or_default()
            .push(vec![
                state.active_5m_return,
                state.dist_vwap,
                state.rolling_realized_vol,
                state.volume_zscore,
            ]);
    }
    let sequences = sequences_by_session.into_values().collect::<Vec<_>>();
    let (hmm, regime_selection) = select_hmm_model(&sequences, &research.regime)?;
    let short_horizon_model =
        fit_frozen_short_horizon_model(states, &target, training_cutoff, &hmm)?;
    let analog_engine = AnalogEngine::fit(
        states,
        &[],
        &training_indices,
        analog_engine_config(research),
    )
    .context("offline analog transform/index fit failed")?;
    let training_dataset_hash = capability
        .normalized_file_sha256
        .clone()
        .or_else(|| capability.manifest_hashes.last().cloned())
        .context("frozen predictor requires a training dataset hash")?;
    let mut training_dataset_manifest = capability.manifest_hashes.clone();
    training_dataset_manifest.push(training_dataset_hash.clone());
    training_dataset_manifest.sort();
    training_dataset_manifest.dedup();
    let model_hash = sha256_serialized(&serde_json::json!({
        "model_version": FROZEN_PREDICTOR_MODEL_VERSION,
        "hmm": hmm,
        "regime_selection": regime_selection,
        "analog_engine": analog_engine,
        "short_horizon_model": short_horizon_model,
    }))?;
    let calibration_ref = std::env::var("AXIO_PROBABILITY_CALIBRATION_ARTIFACT")
        .ok()
        .filter(|value| !value.trim().is_empty());
    let mut artifact = FrozenPredictorArtifact {
        artifact_version: FROZEN_PREDICTOR_ARTIFACT_VERSION.into(),
        artifact_sha256: String::new(),
        model_version: FROZEN_PREDICTOR_MODEL_VERSION.into(),
        model_hash,
        created_at,
        training_cutoff,
        target: target.clone(),
        feature_schema_version: FROZEN_FEATURE_SCHEMA_VERSION.into(),
        feature_schema_sha256: frozen_feature_schema_hash()?,
        research_model_config_sha256: research_model_config_hash(research)?,
        calibration_version: if calibration_ref.is_some() {
            "external-oos-calibration-artifact-v1"
        } else {
            "UNAVAILABLE_FAIL_CLOSED"
        }
        .into(),
        calibration_ref,
        training_dataset_manifest,
        training_dataset_hash,
        code_commit_hash: code_commit_hash.into(),
        training_state_count: training_indices.len(),
        training_state_prefix_sha256: training_prefix_hash(states, &target, training_cutoff)?,
        hmm,
        regime_selection,
        analog_engine,
        short_horizon_model: Some(short_horizon_model),
    };
    artifact.artifact_sha256 = artifact.unsigned_sha256()?;
    artifact.validate_static()?;
    artifact
        .analog_engine
        .validate_frozen(states, training_cutoff)?;
    Ok(artifact)
}

fn frozen_hmm_context(
    states: &[MarketState],
    query_index: usize,
    artifact: &FrozenPredictorArtifact,
) -> Result<HmmContext> {
    let latest = states.get(query_index).context("query state is absent")?;
    let model = artifact.hmm.clone();
    let mut sessions = BTreeMap::<NaiveDate, Vec<(usize, Vec<f64>)>>::new();
    for (index, state) in states[..=query_index]
        .iter()
        .enumerate()
        .filter(|(_, state)| {
            state.symbol == latest.symbol
                && state.minute_in_5m_bucket == 4
                && state.completed_5m_bucket_valid
        })
    {
        sessions.entry(state.session_date).or_default().push((
            index,
            vec![
                state.active_5m_return,
                state.dist_vwap,
                state.rolling_realized_vol,
                state.volume_zscore,
            ],
        ));
    }
    let mut finalized_probabilities = HashMap::<usize, Vec<f64>>::new();
    for rows in sessions.values() {
        let sequence = rows
            .iter()
            .map(|(_, observation)| observation.clone())
            .collect::<Vec<_>>();
        let filtered = model.filtered_probabilities(&sequence)?;
        for ((index, _), probabilities) in rows.iter().zip(filtered) {
            finalized_probabilities.insert(*index, probabilities);
        }
    }
    let mut filtered_history = vec![Vec::new(); states.len()];
    let mut active_session = None;
    let mut latest_filtered = Vec::new();
    for (index, state) in states[..=query_index].iter().enumerate() {
        if active_session != Some(state.session_date) {
            active_session = Some(state.session_date);
            latest_filtered.clear();
        }
        if let Some(probabilities) = finalized_probabilities.get(&index) {
            latest_filtered = probabilities.clone();
        }
        if state.symbol == latest.symbol && !latest_filtered.is_empty() {
            filtered_history[index] = latest_filtered.clone();
        }
    }
    let filtered = filtered_history
        .get(query_index)
        .filter(|probabilities| !probabilities.is_empty())
        .cloned()
        .context("query has no completed causal frozen-HMM posterior")?;
    let entropy = GaussianHmm::state_entropy(&filtered)?;
    Ok(HmmContext {
        model,
        filtered,
        filtered_history,
        entropy,
        model_hash: sha256_serialized(&artifact.hmm)?,
        selection: artifact.regime_selection.clone(),
    })
}

fn hmm_context(
    states: &[MarketState],
    query_index: usize,
    research: &ResearchConfig,
) -> Result<HmmContext> {
    let latest = states.get(query_index).context("query state is absent")?;
    let mut sessions = BTreeMap::<NaiveDate, Vec<(usize, Vec<f64>)>>::new();
    for (index, state) in states[..=query_index]
        .iter()
        .enumerate()
        .filter(|(_, state)| {
            state.symbol == latest.symbol
                && state.minute_in_5m_bucket == 4
                && state.completed_5m_bucket_valid
        })
    {
        sessions.entry(state.session_date).or_default().push((
            index,
            vec![
                state.active_5m_return,
                state.dist_vwap,
                state.rolling_realized_vol,
                state.volume_zscore,
            ],
        ));
    }
    let train = sessions
        .iter()
        .filter(|(date, _)| **date < latest.session_date)
        .map(|(_, rows)| {
            rows.iter()
                .map(|(_, observation)| observation.clone())
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    let current = sessions
        .get(&latest.session_date)
        .context("latest session has no finalized 5m observation")?;
    let (model, selection) = select_hmm_model(&train, &research.regime)?;

    // Materialize a causal, index-aligned probability history. Each posterior
    // is produced only when its five-minute bucket is complete and is then
    // carried forward within that session. No smoothed probability is used.
    let mut finalized_probabilities = HashMap::<usize, Vec<f64>>::new();
    for rows in sessions.values() {
        let sequence = rows
            .iter()
            .map(|(_, observation)| observation.clone())
            .collect::<Vec<_>>();
        let filtered = model.filtered_probabilities(&sequence)?;
        for ((index, _), probabilities) in rows.iter().zip(filtered) {
            finalized_probabilities.insert(*index, probabilities);
        }
    }
    let mut filtered_history = vec![Vec::new(); states.len()];
    let mut active_session = None;
    let mut latest_filtered = Vec::new();
    for (index, state) in states[..=query_index].iter().enumerate() {
        if active_session != Some(state.session_date) {
            active_session = Some(state.session_date);
            latest_filtered.clear();
        }
        if let Some(probabilities) = finalized_probabilities.get(&index) {
            latest_filtered = probabilities.clone();
        }
        if state.symbol == latest.symbol && !latest_filtered.is_empty() {
            filtered_history[index] = latest_filtered.clone();
        }
    }
    let filtered = filtered_history
        .get(query_index)
        .filter(|probabilities| !probabilities.is_empty())
        .cloned()
        .context("query has no completed causal HMM posterior")?;
    let expected_current_observations = current
        .iter()
        .filter(|(index, _)| *index <= query_index)
        .count();
    if expected_current_observations == 0 {
        bail!("query session has no completed HMM observation");
    }
    let entropy = GaussianHmm::state_entropy(&filtered)?;
    let model_hash = format!("{:x}", Sha256::digest(serde_json::to_vec(&model)?));
    Ok(HmmContext {
        model,
        filtered,
        filtered_history,
        entropy,
        model_hash,
        selection,
    })
}

const SHORT_HORIZON_TRAINING_SESSIONS: usize = 60;

#[derive(Debug, Clone, Copy)]
struct MaterialMoveLogReturnThresholds {
    lower: f64,
    upper: f64,
}

fn frozen_short_horizon_research_layer(
    states: &[MarketState],
    query_index: usize,
    horizon_minutes: usize,
    observation_cutoff: DateTime<Utc>,
    material_move_thresholds: MaterialMoveLogReturnThresholds,
    hmm: &HmmContext,
    artifact: &FrozenPredictorArtifact,
) -> StochasticResearchLayer {
    let closing_short_cover_hazard = forecast_closing_short_cover_hazard(
        states,
        query_index,
        observation_cutoff,
        &ClosingShortCoverHazardConfig::default(),
    );
    let Some(query) = states.get(query_index) else {
        return StochasticResearchLayer {
            status: "REJECTED".into(),
            observation_cutoff: Some(observation_cutoff),
            rejection_reasons: vec![ShortHorizonReason::EmptyTrainingSet],
            closing_short_cover_hazard,
            ..StochasticResearchLayer::default()
        };
    };
    let Some(model) = artifact.short_horizon_model.as_ref() else {
        return StochasticResearchLayer {
            status: "FROZEN_ARTIFACT_SDE_UNAVAILABLE".into(),
            observation_cutoff: Some(observation_cutoff),
            rejection_reasons: vec![ShortHorizonReason::EmptyTrainingSet],
            closing_short_cover_hazard,
            research_policy:
                "LEGACY_FROZEN_ARTIFACT_HAS_NO_STOCHASTIC_HEAD; RETRAIN_V2; NO_DECISION_IMPACT"
                    .into(),
            ..StochasticResearchLayer::default()
        };
    };
    let forecast = model.forecast_standard_horizons(&ShortHorizonForecastRequest {
        as_of: observation_cutoff,
        latest_input_as_of: observation_cutoff,
        latest_input_available_at: observation_cutoff,
        regime_probabilities_as_of: observation_cutoff,
        regime_probabilities_available_at: observation_cutoff,
        filtered_regime_probabilities: hmm.filtered.clone(),
        current_vwap_residual: (1.0 + query.dist_vwap).ln(),
        material_move_lower_threshold_log_return: material_move_thresholds.lower,
        material_move_upper_threshold_log_return: material_move_thresholds.upper,
    });
    let horizon_forecast = forecast
        .forecasts
        .into_iter()
        .find(|row| row.horizon_minutes == horizon_minutes as u32);
    let mut warnings = forecast.warnings;
    warnings.push(ShortHorizonReason::MomentumHeadUnvalidated);
    warnings.sort();
    warnings.dedup();
    let mut rejection_reasons = forecast.rejection_reasons;
    if horizon_forecast.is_none() {
        rejection_reasons.push(ShortHorizonReason::UnsupportedHorizon);
    }
    rejection_reasons.sort();
    rejection_reasons.dedup();
    let training_window_sessions = states
        .iter()
        .filter(|state| {
            state.symbol == query.symbol
                && state.timestamp + Duration::minutes(1) <= artifact.training_cutoff
        })
        .map(|state| state.session_date)
        .collect::<BTreeSet<_>>()
        .len()
        .min(SHORT_HORIZON_TRAINING_SESSIONS);
    StochasticResearchLayer {
        status: if horizon_forecast.is_some() && rejection_reasons.is_empty() {
            "AVAILABLE_RESEARCH_ONLY_SHADOW_FROZEN_SDE"
        } else {
            "REJECTED"
        }
        .into(),
        fit_as_of: Some(model.fit_as_of),
        observation_cutoff: Some(observation_cutoff),
        training_window_sessions,
        training_observation_count: model.training_observation_count,
        base_interval_minutes: Some(model.base_interval_minutes),
        horizon_forecast,
        momentum_head: None,
        closing_short_cover_hazard,
        warnings,
        rejection_reasons,
        martingale_audit_status: "NOT_RUN_UNTIL_APPEND_ONLY_SETTLED_FORWARD_RESIDUALS".into(),
        affects_decision: false,
        probability_semantics:
            "FROZEN_MARKOV_SWITCHING_LOG_RETURN_DIFFUSION_MOMENTS; VWAP_RESIDUAL_OU; UNCALIBRATED_SHADOW_DISTRIBUTION"
                .into(),
        research_policy:
            "RESEARCH_ONLY_FROZEN_SDE_SHADOW; REQUIRES_SEPARATE_OOS_PROMOTION; NEVER_AUTHORIZES_AN_ORDER"
                .into(),
        ..StochasticResearchLayer::default()
    }
}

fn short_horizon_research_layer(
    states: &[MarketState],
    query_index: usize,
    horizon_minutes: usize,
    observation_cutoff: DateTime<Utc>,
    material_move_thresholds: MaterialMoveLogReturnThresholds,
    hmm: &HmmContext,
) -> StochasticResearchLayer {
    let closing_short_cover_hazard = forecast_closing_short_cover_hazard(
        states,
        query_index,
        observation_cutoff,
        &ClosingShortCoverHazardConfig::default(),
    );
    let mut layer = StochasticResearchLayer {
        status: "REJECTED".into(),
        observation_cutoff: Some(observation_cutoff),
        closing_short_cover_hazard,
        ..StochasticResearchLayer::default()
    };
    let Some(query) = states.get(query_index) else {
        return layer;
    };
    let session_dates = states[..=query_index]
        .iter()
        .filter(|state| state.symbol == query.symbol)
        .map(|state| state.session_date)
        .collect::<BTreeSet<_>>();
    let earliest_session = session_dates
        .iter()
        .rev()
        .nth(SHORT_HORIZON_TRAINING_SESSIONS.saturating_sub(1))
        .copied()
        .or_else(|| session_dates.first().copied());
    layer.training_window_sessions = session_dates
        .iter()
        .filter(|date| earliest_session.is_none_or(|earliest| **date >= earliest))
        .count();

    let mut intervals = Vec::new();
    for index in 1..=query_index {
        let previous = &states[index - 1];
        let current = &states[index];
        if current.symbol != query.symbol
            || previous.symbol != query.symbol
            || current.session_date != previous.session_date
            || earliest_session.is_some_and(|earliest| current.session_date < earliest)
            || current.timestamp != previous.timestamp + Duration::minutes(1)
        {
            continue;
        }
        let Some(filtered) = hmm
            .filtered_history
            .get(index)
            .filter(|probabilities| !probabilities.is_empty())
        else {
            continue;
        };
        let gross_return = current.close / previous.close;
        let gross_vwap_residual = 1.0 + current.dist_vwap;
        if !gross_return.is_finite()
            || gross_return <= 0.0
            || !gross_vwap_residual.is_finite()
            || gross_vwap_residual <= 0.0
        {
            continue;
        }
        intervals.push(CausalRegimeInterval {
            interval_start: current.timestamp,
            as_of: current.timestamp + Duration::minutes(1),
            available_at: current.timestamp + Duration::minutes(1),
            session_id: current.session_date.to_string(),
            log_return: gross_return.ln(),
            vwap_residual: gross_vwap_residual.ln(),
            filtered_regime_probabilities: filtered.clone(),
            filtered_transition_from_previous: None,
        });
    }
    layer.training_observation_count = intervals.len();
    let config = ShortHorizonConfig::default();
    let fit = fit_regime_conditioned_model(&intervals, observation_cutoff, None, &config);
    layer.warnings = fit.warnings.clone();
    layer.rejection_reasons = fit.rejection_reasons.clone();
    let Some(model) = fit.model else {
        return layer;
    };
    layer.fit_as_of = Some(model.fit_as_of);
    layer.base_interval_minutes = Some(model.base_interval_minutes);
    let current_vwap_residual = (1.0 + query.dist_vwap).ln();
    let forecast = model.forecast_standard_horizons(&ShortHorizonForecastRequest {
        as_of: observation_cutoff,
        latest_input_as_of: observation_cutoff,
        latest_input_available_at: observation_cutoff,
        regime_probabilities_as_of: observation_cutoff,
        regime_probabilities_available_at: observation_cutoff,
        filtered_regime_probabilities: hmm.filtered.clone(),
        current_vwap_residual,
        material_move_lower_threshold_log_return: material_move_thresholds.lower,
        material_move_upper_threshold_log_return: material_move_thresholds.upper,
    });
    layer.warnings.extend(forecast.warnings.iter().copied());
    layer
        .rejection_reasons
        .extend(forecast.rejection_reasons.iter().copied());
    layer.horizon_forecast = forecast
        .forecasts
        .into_iter()
        .find(|row| row.horizon_minutes == horizon_minutes as u32);

    let mut momentum_observations = Vec::new();
    for index in 0..=query_index {
        let feature = &states[index];
        if feature.symbol != query.symbol
            || earliest_session.is_some_and(|earliest| feature.session_date < earliest)
        {
            continue;
        }
        let Some(outcome_index) = index.checked_add(horizon_minutes) else {
            continue;
        };
        let Some(outcome) = states.get(outcome_index).filter(|outcome| {
            outcome_index <= query_index
                && outcome.symbol == feature.symbol
                && outcome.session_date == feature.session_date
                && outcome.timestamp
                    == feature.timestamp + Duration::minutes(horizon_minutes as i64)
        }) else {
            continue;
        };
        let Some(filtered) = hmm
            .filtered_history
            .get(index)
            .filter(|probabilities| !probabilities.is_empty())
        else {
            continue;
        };
        let gross_return = outcome.close / feature.close;
        if !gross_return.is_finite() || gross_return <= 0.0 {
            continue;
        }
        let feature_as_of = feature.timestamp + Duration::minutes(1);
        let outcome_as_of = outcome.timestamp + Duration::minutes(1);
        momentum_observations.push(CausalMomentumObservation {
            session_id: feature.session_date.to_string(),
            horizon_minutes: horizon_minutes as u32,
            feature_as_of,
            feature_available_at: feature_as_of,
            outcome_as_of,
            outcome_available_at: outcome_as_of,
            filtered_regime_probabilities: filtered.clone(),
            momentum_score: feature.ret_5m,
            realized_log_return: gross_return.ln(),
        });
    }
    let momentum_fit = fit_momentum_head(&momentum_observations, observation_cutoff, None, &config);
    layer.warnings.extend(momentum_fit.warnings.iter().copied());
    layer
        .rejection_reasons
        .extend(momentum_fit.rejection_reasons.iter().copied());
    if let Some(momentum_model) = momentum_fit.model {
        layer.momentum_head = Some(momentum_model.evaluate(&MomentumQuery {
            as_of: observation_cutoff,
            input_as_of: observation_cutoff,
            input_available_at: observation_cutoff,
            regime_probabilities_as_of: observation_cutoff,
            regime_probabilities_available_at: observation_cutoff,
            horizon_minutes: horizon_minutes as u32,
            momentum_score: query.ret_5m,
            filtered_regime_probabilities: hmm.filtered.clone(),
        }));
    }
    layer.warnings.sort();
    layer.warnings.dedup();
    layer.rejection_reasons.sort();
    layer.rejection_reasons.dedup();
    layer.status = if layer.horizon_forecast.is_some() {
        "AVAILABLE_RESEARCH_ONLY_SHADOW"
    } else {
        "REJECTED"
    }
    .into();
    layer
}

fn fit_analog_engine(
    states: &[MarketState],
    query_index: usize,
    research: &ResearchConfig,
) -> Option<AnalogEngine> {
    let query = states.get(query_index)?;
    // Transformations and the OOD threshold are fit only on completed prior
    // sessions. The current day is never allowed into the scaler or covariance.
    let train_indices = states
        .iter()
        .enumerate()
        .filter(|(_, state)| {
            state.symbol == query.symbol
                && state.session_date < query.session_date
                && state.timestamp < query.timestamp
        })
        .map(|(index, _)| index)
        .collect::<Vec<_>>();
    let config = AnalogEngineConfig {
        metric: DistanceMetric::ShrinkageMahalanobis,
        neighbors: research.analog_neighbors,
        bandwidth_rule: BandwidthRule::AdaptiveKthNeighbor,
        bandwidth_multiplier: research.analog_bandwidth,
        regime_conditioned: true,
        regime_match_policy: if research.regime.require_same_dominant_state {
            RegimeMatchPolicy::SameDominantAndPosteriorCosine
        } else {
            RegimeMatchPolicy::PosteriorCosine
        },
        minimum_regime_similarity: research.regime.minimum_posterior_cosine_similarity,
        minimum_dominant_regime_probability: research.regime.minimum_dominant_probability,
        minimum_effective_sample_size: research.regime.minimum_effective_sample_size,
        ..AnalogEngineConfig::default()
    };
    AnalogEngine::fit(states, &[], &train_indices, config)
}

fn analog_prediction(
    forecast: &AnalogForecast,
) -> Option<(i8, &crate::analog_engine::AnalogDistribution)> {
    let distribution = forecast.distribution.as_ref()?;
    let direction = if distribution.kernel_weighted_mean < 0.0 {
        -1
    } else {
        1
    };
    Some((direction, distribution))
}

fn latest_completed_regime_observation(
    states: &[MarketState],
    latest_actual_query_index: usize,
) -> Option<(&MarketState, DateTime<Utc>)> {
    let latest = states.get(latest_actual_query_index)?;
    let completed = states[..=latest_actual_query_index].iter().rfind(|state| {
        state.symbol == latest.symbol
            && state.session_date == latest.session_date
            && state.minute_in_5m_bucket == 4
            && state.completed_5m_bucket_valid
    })?;
    Some((completed, completed.timestamp + Duration::minutes(1)))
}

fn latest_legal_horizon_query_index(
    states: &[MarketState],
    latest_actual_query_index: usize,
    horizon_minutes: usize,
) -> Option<usize> {
    let latest = states.get(latest_actual_query_index)?;
    let horizon_minutes = i32::try_from(horizon_minutes).ok()?;
    states[..=latest_actual_query_index]
        .iter()
        .rposition(|state| {
            state.symbol == latest.symbol
                && state.session_date == latest.session_date
                && state.minutes_to_close > horizon_minutes
        })
}

fn feature_hash(state: &MarketState) -> Result<String> {
    Ok(format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(&state.feature_vector().to_vec())?)
    ))
}

const FORECAST_MODEL_ID: &str = "same-regime-kernel+cv-selected-hmm-v4";
const FORECAST_FEATURE_VERSION: &str = "point-in-time-v4-strict-context";

fn deterministic_prediction_id(
    symbol: &str,
    observation_cutoff: DateTime<Utc>,
    horizon_minutes: usize,
    model_hash: &str,
    feature_hash: &str,
    manifest_hash: &str,
) -> String {
    let cutoff = observation_cutoff.to_rfc3339();
    let horizon = horizon_minutes.to_string();
    stable_id(&[
        "forecast_contract_v4",
        symbol,
        &cutoff,
        &horizon,
        model_hash,
        feature_hash,
        manifest_hash,
    ])
}

fn boundary_unavailable_horizon(horizon_minutes: usize) -> UnavailableResearchHorizon {
    UnavailableResearchHorizon {
        horizon_minutes,
        status: "HORIZON_CROSSES_SESSION_BOUNDARY".into(),
        validation_flags: vec!["HORIZON_CROSSES_SESSION_BOUNDARY".into()],
    }
}

fn gamma_convexity_layer_for_root(
    latest: &MarketState,
    observation_cutoff: DateTime<Utc>,
    max_staleness_seconds: i64,
    option_chain: Option<&PointInTimeOptionChainInput>,
) -> GammaConvexityFeedbackRisk {
    let complete = option_chain.filter(|input| input.full_chain_complete);
    let quotes = complete.map_or(&[][..], |input| input.quotes.as_slice());
    gamma_convexity_feedback_risk(
        quotes,
        &GammaConvexityRequest {
            as_of: observation_cutoff,
            underlying: latest.symbol.clone(),
            spot: latest.close,
            contract_multiplier: 100.0,
            oi_as_of: complete.and_then(|input| input.oi_available_at),
            greeks_as_of: complete.and_then(|input| input.greeks_available_at),
            max_quote_age_seconds: max_staleness_seconds.max(0),
            max_oi_age_seconds: max_staleness_seconds.max(0),
            max_greeks_age_seconds: max_staleness_seconds.max(0),
        },
    )
}

#[derive(Debug, Clone)]
pub struct PointInTimeOptionChainInput {
    pub quotes: Vec<OptionQuote>,
    pub full_chain_complete: bool,
    /// Availability timestamp of the provider's daily OI snapshot, not an
    /// invented intraday OI observation timestamp.
    pub oi_available_at: Option<DateTime<Utc>>,
    /// Availability timestamp of the provider-computed Greeks snapshot.
    pub greeks_available_at: Option<DateTime<Utc>>,
}

pub fn forecast(
    states: &[MarketState],
    research: &ResearchConfig,
    policy: &QuantOsConfig,
    capability: &DataCapabilityReport,
    now: DateTime<Utc>,
) -> Result<ForecastBundle> {
    forecast_internal(states, research, policy, capability, now, None, None)
}

pub fn forecast_with_frozen_artifact(
    states: &[MarketState],
    research: &ResearchConfig,
    policy: &QuantOsConfig,
    capability: &DataCapabilityReport,
    now: DateTime<Utc>,
    artifact: &FrozenPredictorArtifact,
) -> Result<ForecastBundle> {
    let query_cutoff = states
        .last()
        .map(|state| state.timestamp + Duration::minutes(1))
        .context("frozen forecast requires market states")?;
    artifact.validate_for_inference(states, research, capability, query_cutoff)?;
    forecast_internal(
        states,
        research,
        policy,
        capability,
        now,
        Some(artifact),
        None,
    )
}

pub fn forecast_with_frozen_artifact_and_options(
    states: &[MarketState],
    research: &ResearchConfig,
    policy: &QuantOsConfig,
    capability: &DataCapabilityReport,
    now: DateTime<Utc>,
    artifact: &FrozenPredictorArtifact,
    option_chain: &PointInTimeOptionChainInput,
) -> Result<ForecastBundle> {
    let query_cutoff = states
        .last()
        .map(|state| state.timestamp + Duration::minutes(1))
        .context("frozen forecast requires market states")?;
    artifact.validate_for_inference(states, research, capability, query_cutoff)?;
    forecast_internal(
        states,
        research,
        policy,
        capability,
        now,
        Some(artifact),
        Some(option_chain),
    )
}

fn validated_round_trip_cost_return(policy: &QuantOsConfig) -> Result<f64> {
    if !policy.spread_bps.is_finite() || policy.spread_bps < 0.0 {
        bail!("spread_bps must be finite and nonnegative");
    }
    if !policy.slippage_bps.is_finite() || policy.slippage_bps < 0.0 {
        bail!("slippage_bps must be finite and nonnegative");
    }
    let cost_return = (2.0 * policy.spread_bps + 2.0 * policy.slippage_bps) / 10_000.0;
    if !cost_return.is_finite() || !(0.0..1.0).contains(&cost_return) {
        bail!("round-trip spread/slippage cost return must be finite and in [0, 1)");
    }
    Ok(cost_return)
}

fn forecast_internal(
    states: &[MarketState],
    research: &ResearchConfig,
    policy: &QuantOsConfig,
    capability: &DataCapabilityReport,
    now: DateTime<Utc>,
    frozen: Option<&FrozenPredictorArtifact>,
    option_chain: Option<&PointInTimeOptionChainInput>,
) -> Result<ForecastBundle> {
    let direction_event_threshold_return = validated_round_trip_cost_return(policy)?;
    let material_move_log_return_thresholds = MaterialMoveLogReturnThresholds {
        lower: (-direction_event_threshold_return).ln_1p(),
        upper: direction_event_threshold_return.ln_1p(),
    };
    let final_state = states.last().context("forecast requires market states")?;
    let latest_actual_query_index = states.len() - 1;
    let latest_actual_observation_cutoff = final_state.timestamp + Duration::minutes(1);
    let manifest_hash = capability
        .normalized_file_sha256
        .clone()
        .or_else(|| capability.manifest_hashes.last().cloned())
        .unwrap_or_else(|| "MISSING".into());
    let gamma_convexity_layer = gamma_convexity_layer_for_root(
        final_state,
        latest_actual_observation_cutoff,
        policy.freshness_limit_seconds,
        option_chain,
    );
    // Calibrators are never fit inside a forecast request. If the environment
    // does not point to a valid, promoted, horizon-specific OOS artifact,
    // every contract explicitly fails closed and preserves the raw frequency.
    let calibration_registry = CalibrationRegistrySource::from_environment();

    // Root regime context is descriptive context at the newest actual feature
    // query. It is not the query input for every horizon: each contract below
    // independently selects its latest session-safe cutoff and refits its
    // causal HMM/analog context at that cutoff.
    let latest_actual_hmm = match frozen {
        Some(artifact) => frozen_hmm_context(states, latest_actual_query_index, artifact),
        None => hmm_context(states, latest_actual_query_index, research),
    }
    .context("latest causal regime context is required for root context")?;
    let (query_dominant_state, query_dominant_probability) = latest_actual_hmm
        .filtered
        .iter()
        .copied()
        .enumerate()
        .max_by(|left, right| left.1.total_cmp(&right.1))
        .context("query HMM posterior is empty")?;
    let root_normalized_regime_entropy =
        normalized_regime_entropy(latest_actual_hmm.entropy, latest_actual_hmm.filtered.len())
            .unwrap_or(1.0);
    let behavioral_state_layer = derive_price_flow_behavioral_state(
        final_state,
        latest_actual_observation_cutoff,
        root_normalized_regime_entropy,
    )
    .unwrap_or_else(|error| {
        BehavioralStateLayer::unavailable(
            Some(latest_actual_observation_cutoff),
            &format!("BEHAVIORAL_STATE_REJECTED:{error}"),
        )
    });
    let (latest_completed_regime_state, regime_context_as_of) =
        latest_completed_regime_observation(states, latest_actual_query_index)
            .context("root regime context has no finalized five-minute state")?;
    let next_state_is_same_session = latest_completed_regime_state.minutes_to_close >= 5;
    let regime_context = ForecastRegimeContext {
        as_of: regime_context_as_of,
        query_semantics:
            "LATEST_COMPLETED_FIVE_MINUTE_STATE_CONTEXT; EACH_HORIZON_HAS_INDEPENDENT_SESSION_SAFE_CUTOFF"
                .into(),
        observation_cadence_minutes: 5,
        session_reset: true,
        filtered_state_probabilities: latest_actual_hmm.filtered.clone(),
        next_state_probabilities: latest_actual_hmm
            .model
            .next_state_probabilities(&latest_actual_hmm.filtered)?,
        next_state_probability_status: if next_state_is_same_session {
            "AVAILABLE_SAME_SESSION_MODEL_IMPLIED"
        } else {
            "MODEL_IMPLIED_ONLY_CROSS_SESSION_FORECAST_UNAVAILABLE"
        }
        .into(),
        cross_session_state_forecast_status:
            "UNAVAILABLE_REQUIRES_SEPARATELY_VALIDATED_OVERNIGHT_MODEL".into(),
        direct_allocation_impact: true,
        continuous_sizing_impact: false,
        hard_no_trade_veto_impact: true,
        state_entropy: latest_actual_hmm.entropy,
        normalized_state_entropy: root_normalized_regime_entropy,
        dominant_raw_state: query_dominant_state,
        dominant_probability: query_dominant_probability,
        model_selection: latest_actual_hmm.selection.clone(),
        probability_semantics:
            "ROOT_IS_LATEST_COMPLETED_FIVE_MINUTE_FORWARD_FILTERED_CONTEXT; CONTRACT_POSTERIORS_USE_THEIR_OWN_HORIZON_SAFE_QUERY"
                .into(),
    };
    let mut contracts = Vec::new();
    let mut unavailable_horizons = Vec::new();
    for horizon in &research.horizons {
        let Some(query_index) =
            latest_legal_horizon_query_index(states, latest_actual_query_index, *horizon)
        else {
            unavailable_horizons.push(boundary_unavailable_horizon(*horizon));
            continue;
        };
        let latest = &states[query_index];
        let observation_cutoff = latest.timestamp + Duration::minutes(1);
        let model_trained_through = if let Some(artifact) = frozen {
            artifact.training_cutoff.date_naive()
        } else {
            states[..=query_index]
                .iter()
                .filter(|state| state.session_date < latest.session_date)
                .map(|state| state.session_date)
                .max()
                .context("forecast model requires at least one prior training session")?
        };
        let feature_hash = feature_hash(latest)?;
        let hmm_result = match frozen {
            Some(artifact) => frozen_hmm_context(states, query_index, artifact),
            None => hmm_context(states, query_index, research),
        };
        let hmm = match hmm_result {
            Ok(context) => context,
            Err(_) => {
                unavailable_horizons.push(UnavailableResearchHorizon {
                    horizon_minutes: *horizon,
                    status: "REGIME_CONTEXT_UNAVAILABLE".into(),
                    validation_flags: vec!["REGIME_CONTEXT_UNAVAILABLE".into()],
                });
                continue;
            }
        };
        let flat = direction_event_threshold_return;
        let stochastic_research_layer = match frozen {
            Some(artifact) => frozen_short_horizon_research_layer(
                states,
                query_index,
                *horizon,
                observation_cutoff,
                material_move_log_return_thresholds,
                &hmm,
                artifact,
            ),
            None => short_horizon_research_layer(
                states,
                query_index,
                *horizon,
                observation_cutoff,
                material_move_log_return_thresholds,
                &hmm,
            ),
        };
        let analog_engine = frozen
            .map(|artifact| artifact.analog_engine.clone())
            .or_else(|| fit_analog_engine(states, query_index, research));
        let Some(analog_engine) = analog_engine else {
            unavailable_horizons.push(UnavailableResearchHorizon {
                horizon_minutes: *horizon,
                status: "ANALOG_ENGINE_UNAVAILABLE".into(),
                validation_flags: vec!["ANALOG_ENGINE_UNAVAILABLE".into()],
            });
            continue;
        };
        let outcomes = labels::forward_outcomes(states, *horizon);
        let analog_forecast = analog_engine.query(
            states,
            &outcomes,
            query_index,
            *horizon,
            Some(&hmm.filtered_history),
        );
        let Some((direction, distribution)) = analog_prediction(&analog_forecast) else {
            unavailable_horizons.push(UnavailableResearchHorizon {
                horizon_minutes: *horizon,
                status: analog_forecast.status.clone(),
                validation_flags: analog_forecast.no_trade_reasons.clone(),
            });
            continue;
        };
        let weights = analog_forecast
            .top_analogs
            .iter()
            .map(|row| (row.terminal_return, row.weight))
            .collect::<Vec<_>>();
        let mfe = analog_forecast
            .top_analogs
            .iter()
            .map(|row| (row.maximum_favorable_excursion, row.weight))
            .collect::<Vec<_>>();
        let mae = analog_forecast
            .top_analogs
            .iter()
            .map(|row| (row.maximum_adverse_excursion, row.weight))
            .collect::<Vec<_>>();
        let total = weights.iter().map(|(_, w)| *w).sum::<f64>().max(1e-12);
        let probability = |test: &dyn Fn(f64) -> bool| {
            weights
                .iter()
                .filter(|(value, _)| test(*value))
                .map(|(_, w)| *w)
                .sum::<f64>()
                / total
        };
        let raw_analog_up_frequency = probability(&|value| value > flat);
        let raw_analog_down_frequency = probability(&|value| value < -flat);
        let raw_analog_flat_frequency =
            (1.0 - raw_analog_up_frequency - raw_analog_down_frequency).clamp(0.0, 1.0);
        let return_quantiles = quantiles(&weights);
        let current_close_reference_scenario_price_quantiles = return_quantiles
            .iter()
            .map(|row| QuantilePoint {
                probability: row.probability,
                value: latest.close * (1.0 + row.value),
            })
            .collect();
        let current_close_reference_scenario_expected_price =
            latest.close * (1.0 + distribution.kernel_weighted_mean);
        let outcome_prediction_intervals =
            empirical_outcome_prediction_intervals(&distribution.weighted_quantiles, latest.close);
        let diagnostics = analog_forecast.diagnostics.as_ref();
        let effective_sample_size = diagnostics
            .map(|row| row.effective_sample_size)
            .unwrap_or_default();
        let direction_probability_intervals = DirectionProbabilityIntervals {
            up: raw_kernel_probability_interval(raw_analog_up_frequency, effective_sample_size),
            flat: raw_kernel_probability_interval(raw_analog_flat_frequency, effective_sample_size),
            down: raw_kernel_probability_interval(raw_analog_down_frequency, effective_sample_size),
        };
        let filtered = hmm.filtered.clone();
        let predicted = hmm
            .model
            .horizon_state_probabilities(&filtered, horizon.div_ceil(5), false)
            .unwrap_or_default();
        let entropy = Some(hmm.entropy);
        let hmm_hash = hmm.model_hash.clone();
        let model_hash = frozen.map_or_else(
            || {
                format!(
                    "{:x}",
                    Sha256::digest(format!(
                        "analog-v4-same-regime-kernel:{hmm_hash}:{}:{}:{}:{}:{}",
                        research.analog_neighbors,
                        research.analog_bandwidth,
                        research.regime.minimum_posterior_cosine_similarity,
                        research.regime.minimum_dominant_probability,
                        research.regime.minimum_effective_sample_size
                    ))
                )
            },
            |artifact| artifact.model_hash.clone(),
        );
        let probability_calibration = calibration_registry.evaluate(&CalibrationRequest {
            horizon_minutes: *horizon,
            observation_cutoff,
            raw_analog_up_frequency,
            model_id: FORECAST_MODEL_ID,
            model_hash: &model_hash,
            feature_version: FORECAST_FEATURE_VERSION,
        });
        let p_up = probability_calibration.calibrated_probability_up;
        let p_down = None;
        let p_flat = None;
        let strategy_win_probability = if direction > 0 { p_up } else { None };
        let dominant_regime = filtered
            .iter()
            .copied()
            .enumerate()
            .max_by(|left, right| left.1.total_cmp(&right.1));
        let expected_cost = (2.0 * policy.spread_bps + 2.0 * policy.slippage_bps) / 10_000.0
            + policy.fee_per_order / latest.close.max(1.0);
        let expected_edge = direction as f64 * distribution.kernel_weighted_mean - expected_cost;
        let ood_score = diagnostics
            .map(|row| row.out_of_distribution_score)
            .unwrap_or(f64::INFINITY);
        let mut reasons = analog_forecast.no_trade_reasons.clone();
        if capability.highest_level == "NONE" {
            reasons.push("MISSING_D0_DATA".into());
        }
        if now - observation_cutoff > Duration::seconds(policy.freshness_limit_seconds) {
            reasons.push("STALE_INPUT".into());
        }
        if effective_sample_size < research.regime.minimum_effective_sample_size {
            reasons.push("INSUFFICIENT_EFFECTIVE_SAMPLE".into());
        }
        if strategy_win_probability
            .is_none_or(|probability| probability < policy.confidence_threshold)
        {
            reasons.push("CONFIDENCE_BELOW_POLICY".into());
        }
        if expected_edge < policy.minimum_expected_return_bps / 10_000.0 {
            reasons.push("EDGE_BELOW_COST_AND_POLICY".into());
        }
        if entropy
            .and_then(|value| normalized_regime_entropy(value, filtered.len()))
            .is_some_and(|value| value > research.regime.maximum_normalized_entropy)
        {
            reasons.push("EXCESSIVE_STATE_ENTROPY".into());
        }
        if dominant_regime.is_none_or(|(_, probability)| {
            probability < research.regime.minimum_dominant_probability
        }) {
            reasons.push("REGIME_POSTERIOR_UNCERTAIN".into());
        }
        if hmm.selection.selected_at_candidate_boundary {
            reasons.push("REGIME_STATE_COUNT_OPTIMUM_UNRESOLVED".into());
        }
        if ood_score > 1.0 {
            reasons.push("ANALOG_OOD".into());
        }
        if predicted.is_empty() {
            reasons.push("STATE_FORECAST_UNAVAILABLE".into());
        }
        if !probability_calibration.eligible_for_probability_use {
            reasons.push("OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED".into());
            reasons.extend(
                probability_calibration
                    .reasons
                    .iter()
                    .map(|reason| format!("CALIBRATION:{reason}")),
            );
        }
        reasons.push("RESEARCH_ONLY_NO_TRADE".into());
        reasons.sort();
        reasons.dedup();
        let horizon_text = horizon.to_string();
        let query_cutoff_text = observation_cutoff.to_rfc3339();
        let top_analogs = analog_forecast
            .top_analogs
            .iter()
            .map(|row| {
                let timestamp = row.analog_timestamp.to_rfc3339();
                ForecastAnalogEvidence {
                    market_snapshot_id: None,
                    retrieval_snapshot_id: Some(row.snapshot_id.clone()),
                    derived_trace_id: stable_id(&[
                        "modern_analog_trace",
                        &latest.symbol,
                        &query_cutoff_text,
                        &timestamp,
                        &horizon_text,
                    ]),
                    rank: row.rank,
                    analog_timestamp: row.analog_timestamp,
                    session_date: Some(row.session_date),
                    distance: row.distance,
                    weight: row.weight,
                    regime_similarity: row.regime_similarity,
                    feature_similarity: row.feature_similarity.clone(),
                    subsequent_realized_path: row.subsequent_realized_path.clone(),
                    forward_return: row.terminal_return,
                    mfe: row.maximum_favorable_excursion,
                    mae: row.maximum_adverse_excursion,
                    label_available_at: Some(row.label_available_at),
                    path_status: "COMPLETE_CAUSAL_REALIZED_PATH".into(),
                }
            })
            .collect::<Vec<_>>();
        let maximum_weight = analog_forecast
            .top_analogs
            .iter()
            .map(|row| row.weight)
            .fold(0.0, f64::max);
        let concentration_penalty = if top_analogs.is_empty() {
            1.0
        } else {
            (1.0 - effective_sample_size / top_analogs.len() as f64).clamp(0.0, 1.0)
        };
        let analog_similarity_score = if ood_score.is_finite() {
            (-0.5 * ood_score * ood_score).exp()
        } else {
            0.0
        };
        let analog_metric = serde_json::to_value(analog_forecast.metric)
            .ok()
            .and_then(|value| value.as_str().map(str::to_string))
            .unwrap_or_else(|| "unknown".into());
        let analog_sensitivity = diagnostics
            .map(|row| row.sensitivity.clone())
            .unwrap_or_default();
        let selected_dimensions = diagnostics
            .map(|row| row.selected_dimensions.clone())
            .unwrap_or_default();
        let probability_interval_available = direction_probability_intervals.up.is_some()
            && direction_probability_intervals.flat.is_some()
            && direction_probability_intervals.down.is_some();
        let kernel_regression = KernelRegressionEvidence {
            status: analog_forecast.status.clone(),
            feature_dimension_count: selected_dimensions.len(),
            selected_dimensions,
            metric: analog_metric.clone(),
            kernel: "GAUSSIAN_RBF_ADAPTIVE_BANDWIDTH_NADARAYA_WATSON".into(),
            bandwidth: analog_forecast.bandwidth,
            neighbor_count: analog_forecast.top_analogs.len(),
            effective_sample_size,
            minimum_effective_sample_size: research.regime.minimum_effective_sample_size,
            nadaraya_watson_expected_return: distribution.kernel_weighted_mean,
            local_linear_intercept: distribution.locally_weighted_linear_intercept,
            direction_event_threshold_return: flat,
            direction_probability_intervals,
            probability_status: if probability_interval_available {
                "EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON"
            } else {
                "UNAVAILABLE_EFFECTIVE_SAMPLE_SIZE_BELOW_ONE"
            }
            .into(),
            probability_semantics:
                "UP_FLAT_DOWN_ARE_KERNEL_WEIGHTED_HISTORICAL_EVENT_FREQUENCIES_WITH_95_PERCENT_EFFECTIVE_SAMPLE_WILSON_ESTIMATE_INTERVALS; NOT_PROMOTED_OOS_CALIBRATED_MULTICLASS_PROBABILITIES"
                    .into(),
        };
        let prediction_id = deterministic_prediction_id(
            &latest.symbol,
            observation_cutoff,
            *horizon,
            &model_hash,
            &feature_hash,
            &manifest_hash,
        );
        contracts.push(ForecastContract {
            prediction_id,
            created_at: now,
            observation_cutoff,
            as_of: observation_cutoff,
            decision_as_of: observation_cutoff,
            latest_input_available_at: observation_cutoff,
            earliest_executable_time: observation_cutoff
                + Duration::milliseconds(policy.latency_ms as i64),
            symbol: latest.symbol.clone(),
            timeframe: "1m".into(),
            horizon_minutes: *horizon,
            label_start: observation_cutoff,
            label_end: observation_cutoff + Duration::minutes(*horizon as i64),
            session: latest.session_date.to_string(),
            timezone: research.timezone.clone(),
            reference_price: latest.close,
            reference_price_source: "FINALIZED_1M_CLOSE_REFERENCE_ONLY".into(),
            expected_return: distribution.kernel_weighted_mean,
            expected_price: None,
            return_definition: KERNEL_RETURN_DEFINITION.into(),
            current_close_reference_scenario_expected_price,
            current_close_reference_scenario_price_quantiles,
            current_close_reference_scenario_basis: CURRENT_CLOSE_SCENARIO_BASIS.into(),
            current_close_reference_scenario_status: CURRENT_CLOSE_SCENARIO_STATUS.into(),
            current_close_reference_scenario_semantics: CURRENT_CLOSE_SCENARIO_SEMANTICS.into(),
            median_return: distribution
                .weighted_quantiles
                .get("q50")
                .copied()
                .unwrap_or_default(),
            return_quantiles,
            price_quantiles: Vec::new(),
            p_up,
            p_down,
            p_flat,
            raw_analog_up_frequency,
            raw_analog_down_frequency,
            raw_analog_flat_frequency,
            calibrated_probability_up: probability_calibration.calibrated_probability_up,
            probability_calibration: probability_calibration.clone(),
            suggested_direction: direction,
            strategy_win_probability,
            kernel_regression,
            outcome_prediction_intervals,
            expected_volatility: distribution.dispersion,
            expected_absolute_move: weights.iter().map(|(v, w)| v.abs() * w).sum::<f64>() / total,
            mfe_distribution: quantiles(&mfe),
            mae_distribution: quantiles(&mae),
            barrier_probabilities: BarrierProbabilities {
                upper_first: None,
                lower_first: None,
                neither: None,
                status: "UNAVAILABLE_ORDERED_PATH_LABEL_REQUIRED".into(),
            },
            filtered_state_probabilities: filtered,
            predicted_state_probabilities: predicted,
            state_entropy: entropy,
            dominant_regime_state: dominant_regime.map(|(state, _)| state),
            dominant_regime_probability: dominant_regime.map(|(_, probability)| probability),
            regime_model_selection: Some(hmm.selection.clone()),
            stochastic_research_layer,
            epistemic_uncertainty: distribution.dispersion / effective_sample_size.max(1.0).sqrt(),
            ood_score,
            market_snapshot_id: None,
            snapshot_link_status: "MARKET_MEMORY_NOT_MATERIALIZED".into(),
            top_analogs,
            analog_effective_sample_size: effective_sample_size,
            analog_similarity_score,
            analog_max_day_weight: maximum_weight,
            analog_concentration_penalty: concentration_penalty,
            analog_engine_status: analog_forecast.status.clone(),
            analog_metric,
            analog_bandwidth: analog_forecast.bandwidth,
            analog_diagnostics: diagnostics.cloned(),
            analog_sensitivity,
            model_id: frozen
                .map(|artifact| artifact.model_version.clone())
                .unwrap_or_else(|| FORECAST_MODEL_ID.into()),
            model_hash,
            feature_version: FORECAST_FEATURE_VERSION.into(),
            feature_hash: feature_hash.clone(),
            data_source: capability.source.clone(),
            data_capability_level: capability.highest_level.clone(),
            market_coverage: "HISTORICAL_VENDOR_AGGREGATES".into(),
            model_trained_through: model_trained_through.to_string(),
            target_status: "UNDERLYING_PROXY_ONLY".into(),
            data_manifest_hash: manifest_hash.clone(),
            evidence_grade: capability.evidence_grade.clone(),
            evidence_kind: "batch_research_prediction".into(),
            sample_size: analog_forecast.top_analogs.len(),
            calibration_status: probability_calibration.status.clone(),
            availability_semantics: "D0_VENDOR_BAR_END_PROXY_NO_RECEIVE_TIMESTAMP".into(),
            decision: DecisionPolicyResult {
                action: "NO_TRADE".into(),
                eligible: false,
                expected_edge_after_cost: expected_edge,
                no_trade_reasons: reasons,
                policy_version: "research-only-no-trade-v2".into(),
            },
        });
    }
    Ok(ForecastBundle {
        generated_at: now,
        status: if contracts.is_empty() {
            "NO_VALIDATED_EDGE"
        } else {
            "NO_TRADE"
        }
        .into(),
        forecast_contract_version: "4.4".into(),
        prediction_layer: contracts,
        unavailable_horizons,
        regime_context: Some(regime_context),
        gamma_convexity_layer,
        behavioral_state_layer,
        option_surface_layer: serde_json::json!({"status":if capability.d3_option_analytics{"AVAILABLE"}else{"BLOCKED_BY_D3_DATA"},"alpha_claim":false}),
        option_execution_layer: serde_json::json!({"status":if capability.d2_option_nbbo{"REQUIRES_SEPARATE_DECISION_POLICY"}else{"SPXW_BACKTEST_BLOCKED"},"real_option_pnl_generated":false}),
        research_only_policy: ResearchOnlyPolicy::default(),
        conclusions: vec![
            "IMPERSONAL WHOLE-MARKET STATISTICAL RESEARCH ONLY".into(),
            "NOT PERSONALIZED INVESTMENT ADVICE OR AN EXECUTION INSTRUCTION".into(),
            "UNDERLYING EDGE NOT YET CONFIRMED".into(),
            if capability.d2_option_nbbo {
                "OPTION DATA PRESENT REQUIRES VALIDATION"
            } else {
                "OPTION BACKTEST BLOCKED BY D2 DATA"
            }
            .into(),
        ],
    })
}

const FORWARD_SHADOW_CUTOFF_MISMATCH_REASON: &str =
    "AVAILABLE_AT_NOT_ALIGNED_WITH_OBSERVATION_CUTOFF";

pub struct RealtimeSourceMetadata<'a> {
    pub source_version: &'a str,
    pub provider: &'a str,
    pub market_coverage: &'a str,
    pub availability_semantics: &'a str,
}

fn available_at_belongs_to_observation_cutoff(
    observation_cutoff: DateTime<Utc>,
    available_at: DateTime<Utc>,
) -> bool {
    available_at >= observation_cutoff && available_at < observation_cutoff + Duration::minutes(1)
}

pub fn enforce_realtime_forward_shadow(
    bundle: &mut ForecastBundle,
    available_at: DateTime<Utc>,
    execution_latency_ms: i64,
    is_replay: bool,
    source: &RealtimeSourceMetadata<'_>,
) {
    let contract_count = bundle.prediction_layer.len();
    let mut aligned_contract_count = 0_usize;
    for contract in &mut bundle.prediction_layer {
        // `available_at` is the receive/availability time for one finalized
        // minute bar. It can only enrich a contract whose feature bar ended at
        // that contract's observation cutoff. A later bar must never make an
        // older horizon fallback look like a newly observed input.
        if available_at_belongs_to_observation_cutoff(contract.observation_cutoff, available_at) {
            aligned_contract_count += 1;
            contract.latest_input_available_at = available_at;
            contract.decision_as_of = available_at;
            contract.as_of = contract.observation_cutoff;
            contract.earliest_executable_time =
                available_at + Duration::milliseconds(execution_latency_ms.max(1));
            contract.data_source = format!(
                "{}:{}",
                source.provider.trim().to_ascii_uppercase(),
                source.source_version
            );
            contract.data_capability_level = "D1_REALTIME_UNDERLYING".into();
            contract.market_coverage = source.market_coverage.to_string();
            let canonical_symbol = contract
                .symbol
                .trim_start_matches("US.")
                .to_ascii_uppercase();
            contract.target_status = if canonical_symbol == "SPY" {
                "UNDERLYING_PROXY_ONLY:US.SPY->SPX_PROXY".into()
            } else {
                format!("UNDERLYING_ETF_ONLY:US.{canonical_symbol}")
            };
            contract.evidence_grade = if is_replay {
                "DETERMINISTIC_REPLAY"
            } else {
                "FORWARD_SHADOW"
            }
            .into();
            contract.evidence_kind = if is_replay {
                "deterministic_replay_prediction"
            } else {
                "live_shadow_prediction"
            }
            .into();
            contract.availability_semantics = source.availability_semantics.to_string();
            contract.calibration_status = if contract
                .probability_calibration
                .eligible_for_probability_use
            {
                contract.probability_calibration.status.clone()
            } else {
                format!(
                    "FORWARD_SHADOW_FAIL_CLOSED:{}",
                    contract.probability_calibration.status
                )
            };
        } else {
            contract.as_of = contract.observation_cutoff;
            contract.decision_as_of = contract.observation_cutoff;
            contract.latest_input_available_at = contract.observation_cutoff;
            contract
                .decision
                .no_trade_reasons
                .push(FORWARD_SHADOW_CUTOFF_MISMATCH_REASON.into());
        }
        contract.decision.action = "NO_TRADE".into();
        contract.decision.eligible = false;
        contract
            .decision
            .no_trade_reasons
            .push("MODEL_NOT_PROMOTED_NO_OOS_EDGE".into());
        contract.decision.no_trade_reasons.sort();
        contract.decision.no_trade_reasons.dedup();
    }
    let behavioral_source_scope = format!(
        "{}:{}",
        source.provider.trim().to_ascii_uppercase(),
        source.source_version
    );
    if bundle
        .behavioral_state_layer
        .observation_cutoff
        .is_some_and(|cutoff| available_at_belongs_to_observation_cutoff(cutoff, available_at))
    {
        if let Err(error) = bundle
            .behavioral_state_layer
            .attach_verified_bar_availability(available_at, &behavioral_source_scope)
        {
            bundle
                .behavioral_state_layer
                .mark_availability_mismatch(&format!("BEHAVIORAL_AVAILABILITY_REJECTED:{error}"));
        }
    } else {
        bundle.behavioral_state_layer.mark_availability_mismatch(
            "BEHAVIORAL_AVAILABLE_AT_NOT_ALIGNED_WITH_ROOT_OBSERVATION_CUTOFF",
        );
    }
    bundle.status = "NO_TRADE".into();
    bundle.conclusions = vec![
        "RESEARCH ONLY".into(),
        "NO EDGE".into(),
        if is_replay {
            "DETERMINISTIC REPLAY IS NOT FORWARD EVIDENCE"
        } else if contract_count > 0 && aligned_contract_count == contract_count {
            "ALL CONTRACT INPUTS ALIGNED FOR FORWARD SHADOW"
        } else if aligned_contract_count == 0 {
            "FORWARD SHADOW AVAILABLE_AT NOT ALIGNED WITH CONTRACT CUTOFFS"
        } else {
            "PARTIAL FORWARD SHADOW ALIGNMENT; UNALIGNED CONTRACTS RETAIN ORIGINAL CUTOFFS"
        }
        .into(),
        "OPTION BACKTEST BLOCKED BY HISTORICAL D2 DATA".into(),
    ];
}

pub fn enforce_moomoo_forward_shadow(
    bundle: &mut ForecastBundle,
    available_at: DateTime<Utc>,
    source_version: &str,
    execution_latency_ms: i64,
    is_replay: bool,
) {
    enforce_realtime_forward_shadow(
        bundle,
        available_at,
        execution_latency_ms,
        is_replay,
        &RealtimeSourceMetadata {
            source_version,
            provider: "MOOMOO_OPEND",
            market_coverage: "NASDAQ_BASIC_TOTALVIEW_PLUS_ARCABOOK",
            availability_semantics: "MOOMOO_EVENT_RECEIVE_AVAILABLE_FINALIZED_TIMESTAMPS",
        },
    );
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};

    use super::*;
    use crate::config::RegimeResearchConfig;
    use crate::engine::gamma_convexity::{
        GammaConvexityAvailability, GammaConvexityUnavailableReason,
    };

    fn state_at(
        timestamp: DateTime<Utc>,
        session_date: NaiveDate,
        minutes_to_close: i32,
        seed: f64,
    ) -> MarketState {
        MarketState {
            timestamp,
            session_date,
            symbol: "SPY".into(),
            open: 100.0,
            high: 101.0,
            low: 99.0,
            close: 100.0 + seed,
            atr: 1.0,
            ret_1m: seed * 0.001,
            ret_3m: seed * 0.002,
            ret_5m: seed * 0.003,
            ret_15m: seed * 0.004,
            ret_30m: seed * 0.005,
            ret_60m: seed * 0.006,
            active_5m_return: seed * 0.007,
            last_completed_5m_return: seed * 0.008,
            last_completed_15m_return: seed * 0.009,
            slope_15m: seed * 0.01,
            dist_vwap: seed * 0.011,
            dist_session_open: seed * 0.012,
            rolling_realized_vol: 0.01 + seed.abs() * 0.001,
            normalized_range: 1.0,
            upper_wick_ratio: 0.2,
            lower_wick_ratio: 0.2,
            close_location_value: 0.5,
            distance_session_high: -0.005,
            distance_session_low: 0.005,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 0,
            consecutive_down_bars: 0,
            return_acceleration: seed * 0.001,
            volume_zscore: seed * 0.1,
            volume_acceleration: seed * 0.01,
            session_range_position: 0.5,
            cross_asset_breadth_score: 0.0,
            risk_rotation_score: 0.0,
            market_confirmation_score: 0.0,
            cross_asset_context_complete: false,
            cross_asset_context_coverage: 0.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0,
            minutes_from_open: 390 - minutes_to_close,
            minutes_to_close,
            bucket_5m: (390 - minutes_to_close) / 5,
            bucket_15m: (390 - minutes_to_close) / 15,
            minute_in_5m_bucket: 4,
            completed_5m_bucket_valid: true,
            continuous_minute_count: (390 - minutes_to_close).max(1) as usize,
        }
    }

    fn contract_at(observation_cutoff: DateTime<Utc>) -> ForecastContract {
        ForecastContract {
            prediction_id: "prediction".into(),
            created_at: observation_cutoff,
            observation_cutoff,
            as_of: observation_cutoff,
            decision_as_of: observation_cutoff,
            latest_input_available_at: observation_cutoff,
            earliest_executable_time: observation_cutoff + Duration::milliseconds(250),
            symbol: "SPY".into(),
            timeframe: "1m".into(),
            horizon_minutes: 60,
            label_start: observation_cutoff,
            label_end: observation_cutoff + Duration::minutes(60),
            session: observation_cutoff.date_naive().to_string(),
            timezone: "America/New_York".into(),
            reference_price: 100.0,
            reference_price_source: "FINALIZED_1M_CLOSE_REFERENCE_ONLY".into(),
            expected_return: 0.0,
            expected_price: Some(100.0),
            return_definition: "SIMPLE_RETURN".into(),
            current_close_reference_scenario_expected_price: 0.0,
            current_close_reference_scenario_price_quantiles: Vec::new(),
            current_close_reference_scenario_basis: String::new(),
            current_close_reference_scenario_status: String::new(),
            current_close_reference_scenario_semantics: String::new(),
            median_return: 0.0,
            return_quantiles: Vec::new(),
            price_quantiles: Vec::new(),
            p_up: None,
            p_down: None,
            p_flat: None,
            raw_analog_up_frequency: 0.0,
            raw_analog_down_frequency: 0.0,
            raw_analog_flat_frequency: 1.0,
            calibrated_probability_up: None,
            probability_calibration: Default::default(),
            suggested_direction: 0,
            strategy_win_probability: None,
            kernel_regression: Default::default(),
            outcome_prediction_intervals: Vec::new(),
            expected_volatility: 0.0,
            expected_absolute_move: 0.0,
            mfe_distribution: Vec::new(),
            mae_distribution: Vec::new(),
            barrier_probabilities: BarrierProbabilities {
                upper_first: None,
                lower_first: None,
                neither: None,
                status: "UNAVAILABLE".into(),
            },
            filtered_state_probabilities: Vec::new(),
            predicted_state_probabilities: Vec::new(),
            state_entropy: None,
            dominant_regime_state: None,
            dominant_regime_probability: None,
            regime_model_selection: None,
            stochastic_research_layer: Default::default(),
            epistemic_uncertainty: 0.0,
            ood_score: 0.0,
            market_snapshot_id: None,
            snapshot_link_status: "UNAVAILABLE".into(),
            top_analogs: Vec::new(),
            analog_effective_sample_size: 0.0,
            analog_similarity_score: 0.0,
            analog_max_day_weight: 0.0,
            analog_concentration_penalty: 0.0,
            analog_engine_status: "UNAVAILABLE".into(),
            analog_metric: "UNAVAILABLE".into(),
            analog_bandwidth: 0.0,
            analog_diagnostics: None,
            analog_sensitivity: Vec::new(),
            model_id: "model".into(),
            model_hash: "model-hash".into(),
            feature_version: "feature".into(),
            feature_hash: "feature-hash".into(),
            data_source: "ORIGINAL_FEATURE_SOURCE".into(),
            data_capability_level: "D0".into(),
            market_coverage: "ORIGINAL_COVERAGE".into(),
            model_trained_through: observation_cutoff.date_naive().to_string(),
            target_status: "UNDERLYING_PROXY_ONLY".into(),
            data_manifest_hash: "manifest-hash".into(),
            evidence_grade: "RESEARCH".into(),
            evidence_kind: "research_prediction".into(),
            sample_size: 0,
            calibration_status: "UNVALIDATED".into(),
            availability_semantics: "ORIGINAL_FEATURE_CUTOFF".into(),
            decision: DecisionPolicyResult {
                action: "NO_TRADE".into(),
                eligible: false,
                expected_edge_after_cost: 0.0,
                no_trade_reasons: vec!["RESEARCH_ONLY_NO_TRADE".into()],
                policy_version: "research-only".into(),
            },
        }
    }

    fn bundle_with(contract: ForecastContract) -> ForecastBundle {
        ForecastBundle {
            generated_at: contract.created_at,
            status: "NO_TRADE".into(),
            forecast_contract_version: "4.1".into(),
            prediction_layer: vec![contract],
            unavailable_horizons: Vec::new(),
            regime_context: None,
            gamma_convexity_layer: default_gamma_convexity_layer(),
            behavioral_state_layer: BehavioralStateLayer::default(),
            option_surface_layer: serde_json::json!({"status":"UNAVAILABLE"}),
            option_execution_layer: serde_json::json!({"status":"UNAVAILABLE"}),
            research_only_policy: ResearchOnlyPolicy::default(),
            conclusions: vec!["RESEARCH ONLY".into()],
        }
    }

    #[test]
    fn weighted_quantiles_are_monotone() {
        let values = vec![
            (-0.02, 0.1),
            (-0.01, 0.2),
            (0.0, 0.4),
            (0.01, 0.2),
            (0.03, 0.1),
        ];
        let rows = quantiles(&values);
        assert!(rows.windows(2).all(|pair| pair[0].value <= pair[1].value));
        assert_eq!(weighted_quantile(values, 0.5), 0.0);
    }

    #[test]
    fn kernel_probability_interval_contains_estimate_and_tightens_with_ess() {
        let small = raw_kernel_probability_interval(0.60, 10.0).unwrap();
        let large = raw_kernel_probability_interval(0.60, 100.0).unwrap();
        assert!(small.lower <= small.estimate && small.estimate <= small.upper);
        assert!(large.lower <= large.estimate && large.estimate <= large.upper);
        assert!(large.upper - large.lower < small.upper - small.lower);
        assert_eq!(
            large.status,
            "EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON"
        );
        assert!(
            large
                .semantics
                .contains("NOT_AN_OOS_CALIBRATED_PROBABILITY")
        );
        assert!(raw_kernel_probability_interval(0.60, 0.9).is_none());
    }

    #[test]
    fn empirical_outcome_intervals_are_nested_and_label_prices_are_withheld() {
        let quantiles = BTreeMap::from([
            ("q05".into(), -0.03),
            ("q10".into(), -0.02),
            ("q90".into(), 0.04),
            ("q95".into(), 0.06),
        ]);
        let intervals = empirical_outcome_prediction_intervals(&quantiles, 100.0);
        assert_eq!(intervals.len(), 2);
        let middle_80 = &intervals[0];
        let middle_90 = &intervals[1];
        assert_eq!(middle_80.probability_mass, 0.80);
        assert_eq!(middle_80.lower_price, None);
        assert_eq!(middle_80.upper_price, None);
        assert_eq!(middle_80.current_close_reference_scenario_lower_price, 98.0);
        assert_eq!(
            middle_80.current_close_reference_scenario_upper_price,
            104.0
        );
        assert_eq!(
            middle_80.current_close_reference_scenario_status,
            CURRENT_CLOSE_SCENARIO_STATUS
        );
        assert!(
            middle_80
                .current_close_reference_scenario_semantics
                .contains("NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE")
        );
        assert!(middle_90.lower_return <= middle_80.lower_return);
        assert!(middle_90.upper_return >= middle_80.upper_return);
        assert!(middle_80.semantics.contains("NOT_A_CONFORMAL_INTERVAL"));
    }

    #[test]
    fn spread_and_slippage_cost_band_fails_closed_and_requires_less_than_one() {
        let mut policy = QuantOsConfig::default();
        assert_eq!(validated_round_trip_cost_return(&policy).unwrap(), 0.0003);

        for invalid in [-1.0, f64::NAN, f64::INFINITY] {
            policy.spread_bps = invalid;
            assert!(validated_round_trip_cost_return(&policy).is_err());
            policy = QuantOsConfig::default();
            policy.slippage_bps = invalid;
            assert!(validated_round_trip_cost_return(&policy).is_err());
            policy = QuantOsConfig::default();
        }

        policy.spread_bps = 5_000.0;
        policy.slippage_bps = 0.0;
        assert!(validated_round_trip_cost_return(&policy).is_err());
    }

    #[test]
    fn entropy_normalization_uses_selected_state_count() {
        let uniform_eight_state_entropy = (8.0_f64).ln();
        assert_eq!(
            normalized_regime_entropy(uniform_eight_state_entropy, 8),
            Some(1.0)
        );
        assert_eq!(normalized_regime_entropy(0.0, 8), Some(0.0));
        assert_eq!(normalized_regime_entropy(0.0, 1), None);
    }

    #[test]
    fn frozen_artifact_round_trip_validates_and_preserves_hmm_inference() {
        let research = ResearchConfig {
            target: "SPY".into(),
            targets: Vec::new(),
            timezone: "America/New_York".into(),
            session_open: "09:30".into(),
            session_close: "16:00".into(),
            horizons: vec![5, 15, 30, 60],
            max_trades_per_day: 1,
            cooldown_minutes: 30,
            analog_neighbors: 20,
            analog_bandwidth: 1.0,
            validation_score_threshold: 0.0,
            stop_bps: 10.0,
            take_profit_bps: 20.0,
            max_holding_minutes: 60,
            underlying_slippage_bps: 1.0,
            commission_per_trade: 0.0,
            option_slippage: 0.0,
            option_max_spread_pct: 0.1,
            option_max_staleness_seconds: 120,
            regime: RegimeResearchConfig {
                state_candidates: vec![2],
                validation_fraction: 0.2,
                minimum_validation_sessions: 1,
                max_iterations: 10,
                restarts: 1,
                ..RegimeResearchConfig::default()
            },
        };
        let capability = DataCapabilityReport {
            generated_at: Utc::now(),
            highest_level: "D0".into(),
            d0_underlying_bars: true,
            d1_trades_quotes: false,
            d2_option_nbbo: false,
            d3_option_analytics: false,
            symbols: vec!["SPY".into()],
            coverage_start: None,
            coverage_end: None,
            row_count: 320,
            timestamp_precision: "1m".into(),
            source: "TEST".into(),
            adjusted_status: "RAW".into(),
            context_status: "UNAVAILABLE".into(),
            context_observation_count: 0,
            context_model_eligible_fields: Vec::new(),
            normalized_file_sha256: Some("dataset-sha256".into()),
            manifest_hashes: vec!["manifest-sha256".into()],
            evidence_grade: "TEST".into(),
            allowed_claims: Vec::new(),
            prohibited_claims: Vec::new(),
            missing_data: Vec::new(),
        };
        let mut states = Vec::new();
        for day in 0..8_i64 {
            let date = NaiveDate::from_ymd_opt(2026, 6, 1).unwrap() + chrono::Days::new(day as u64);
            let start =
                Utc.with_ymd_and_hms(2026, 6, 1, 14, 0, 0).single().unwrap() + Duration::days(day);
            for minute in 0..40_i64 {
                states.push(state_at(
                    start + Duration::minutes(minute),
                    date,
                    40 - minute as i32,
                    day as f64 * 0.1 + minute as f64 * 0.01,
                ));
            }
        }
        let artifact =
            train_frozen_artifact(&states, &research, &capability, Utc::now(), "test-commit")
                .unwrap();
        let encoded = serde_json::to_vec(&artifact).unwrap();
        let decoded: FrozenPredictorArtifact = serde_json::from_slice(&encoded).unwrap();
        decoded.validate_static().unwrap();
        assert!(decoded.short_horizon_model.is_some());

        let query_date = NaiveDate::from_ymd_opt(2026, 6, 9).unwrap();
        let query_start = Utc.with_ymd_and_hms(2026, 6, 9, 14, 0, 0).single().unwrap();
        for minute in 0..10_i64 {
            states.push(state_at(
                query_start + Duration::minutes(minute),
                query_date,
                390 - minute as i32,
                1.0 + minute as f64 * 0.01,
            ));
        }
        let query_index = states.len() - 1;
        decoded
            .validate_for_inference(
                &states,
                &research,
                &capability,
                states[query_index].timestamp + Duration::minutes(1),
            )
            .unwrap();
        let context = frozen_hmm_context(&states, query_index, &decoded).unwrap();
        let current_observations = states[320..]
            .iter()
            .map(|state| {
                vec![
                    state.active_5m_return,
                    state.dist_vwap,
                    state.rolling_realized_vol,
                    state.volume_zscore,
                ]
            })
            .collect::<Vec<_>>();
        let direct = decoded
            .hmm
            .filtered_probabilities(&current_observations)
            .unwrap();
        assert_eq!(context.filtered, *direct.last().unwrap());
        let stochastic = frozen_short_horizon_research_layer(
            &states,
            query_index,
            5,
            states[query_index].timestamp + Duration::minutes(1),
            MaterialMoveLogReturnThresholds {
                lower: (-0.000_3_f64).ln_1p(),
                upper: 0.000_3_f64.ln_1p(),
            },
            &context,
            &decoded,
        );
        assert_eq!(
            stochastic.status,
            "AVAILABLE_RESEARCH_ONLY_SHADOW_FROZEN_SDE"
        );
        assert!(
            stochastic
                .horizon_forecast
                .as_ref()
                .is_some_and(|row| row.horizon_minutes == 5)
        );
        assert!(!stochastic.affects_decision);

        let mut tampered = decoded;
        tampered.model_hash.push('x');
        assert!(tampered.validate_static().is_err());
    }

    #[test]
    fn stochastic_layer_emits_shadow_distribution_without_changing_decision_policy() {
        let mut states = Vec::new();
        for day in 0..2_i64 {
            let session_date = NaiveDate::from_ymd_opt(2026, 7, 20 + day as u32).unwrap();
            let session_start = Utc
                .with_ymd_and_hms(2026, 7, 20 + day as u32, 13, 30, 0)
                .single()
                .unwrap();
            for minute in 0..100_i64 {
                let seed = ((minute % 11) as f64 - 5.0) * 0.01;
                states.push(state_at(
                    session_start + Duration::minutes(minute),
                    session_date,
                    390 - minute as i32,
                    seed,
                ));
            }
        }
        let filtered_history = (0..states.len())
            .map(|index| {
                if index % 2 == 0 {
                    vec![0.8, 0.2]
                } else {
                    vec![0.2, 0.8]
                }
            })
            .collect::<Vec<_>>();
        let hmm = HmmContext {
            model: GaussianHmm {
                states: 2,
                dimensions: 1,
                initial: vec![0.5, 0.5],
                transition: vec![vec![0.9, 0.1], vec![0.1, 0.9]],
                means: vec![vec![-0.1], vec![0.1]],
                variances: vec![vec![1.0], vec![1.0]],
                center: vec![0.0],
                scale: vec![1.0],
                log_likelihood: 0.0,
                bic: 0.0,
                training_likelihoods: Vec::new(),
                state_permutation: vec![0, 1],
            },
            filtered: filtered_history.last().unwrap().clone(),
            filtered_history,
            entropy: (2.0_f64).ln(),
            model_hash: "test-hmm".into(),
            selection: RegimeModelSelection {
                candidate_state_counts: vec![2],
                selected_state_count: 2,
                selection_criterion: "TEST".into(),
                fit_session_count: 1,
                validation_session_count: 1,
                candidate_scores: Vec::new(),
                eight_state_challenger_status: "NOT_IN_TEST_CANDIDATES".into(),
                selected_at_candidate_boundary: false,
                selection_warning: None,
                probability_semantics: "FILTERED_TEST_POSTERIOR".into(),
            },
        };
        let query_index = states.len() - 1;
        let cutoff = states[query_index].timestamp + Duration::minutes(1);
        let layer = short_horizon_research_layer(
            &states,
            query_index,
            5,
            cutoff,
            MaterialMoveLogReturnThresholds {
                lower: (-0.000_3_f64).ln_1p(),
                upper: 0.000_3_f64.ln_1p(),
            },
            &hmm,
        );

        assert_eq!(layer.status, "AVAILABLE_RESEARCH_ONLY_SHADOW");
        assert_eq!(layer.fit_as_of, Some(cutoff));
        assert_eq!(layer.base_interval_minutes, Some(1));
        assert!(
            layer
                .horizon_forecast
                .as_ref()
                .is_some_and(|row| row.horizon_minutes == 5)
        );
        assert!(!layer.affects_decision);
        assert_eq!(
            layer.martingale_audit_status,
            "NOT_RUN_UNTIL_APPEND_ONLY_SETTLED_FORWARD_RESIDUALS"
        );
        assert!(
            layer
                .momentum_head
                .as_ref()
                .is_some_and(|row| !row.eligible_for_shadow_comparison)
        );
    }

    #[test]
    fn gamma_convexity_layer_is_typed_fail_closed_and_decision_neutral() {
        let session_date = NaiveDate::from_ymd_opt(2026, 7, 23).unwrap();
        let timestamp = Utc
            .with_ymd_and_hms(2026, 7, 23, 19, 29, 0)
            .single()
            .unwrap();
        let root = state_at(timestamp, session_date, 31, 2.0);
        let cutoff = timestamp + Duration::minutes(1);
        let layer = gamma_convexity_layer_for_root(&root, cutoff, 120, None);

        assert_eq!(layer.availability, GammaConvexityAvailability::Unavailable);
        assert_eq!(layer.as_of, cutoff);
        assert_eq!(layer.underlying, "SPY");
        assert_eq!(layer.spot, Some(root.close));
        assert!(
            layer
                .unavailable_reasons
                .contains(&GammaConvexityUnavailableReason::EmptyChain)
        );
        assert!(
            layer
                .unavailable_reasons
                .contains(&GammaConvexityUnavailableReason::MissingOiAsOf)
        );
        assert!(
            layer
                .unavailable_reasons
                .contains(&GammaConvexityUnavailableReason::MissingGreeksAsOf)
        );
        assert_eq!(layer.coverage.total_contracts, 0);
        assert_eq!(layer.coverage.usable_contracts, 0);
        assert!(layer.exposure.is_none());
        assert!(layer.expiry_concentration.is_none());
        assert!(layer.strike_concentration.is_none());
        assert!(layer.atm_distance.is_none());
        assert!(layer.sign_scenarios.is_empty());
        assert!(!layer.research_only_policy.participant_identity_inferred);
        assert!(
            !layer
                .research_only_policy
                .participant_position_sign_observed
        );

        let contract = contract_at(cutoff);
        let original_decision = contract.decision.clone();
        let mut bundle = bundle_with(contract);
        bundle.gamma_convexity_layer = layer;
        assert_eq!(bundle.prediction_layer[0].decision, original_decision);
        assert_eq!(bundle.prediction_layer[0].decision.action, "NO_TRADE");
        assert!(!bundle.prediction_layer[0].decision.eligible);

        let serialized = serde_json::to_value(&bundle).unwrap();
        assert!(serialized.get("gamma_convexity_layer").is_some());
        let gamma_lower = serde_json::to_string(&serialized["gamma_convexity_layer"])
            .unwrap()
            .to_lowercase();
        assert!(!gamma_lower.contains("dealer"));
        assert!(!gamma_lower.contains("squeeze"));

        let mut legacy_payload = serialized;
        legacy_payload
            .as_object_mut()
            .unwrap()
            .remove("gamma_convexity_layer");
        let decoded: ForecastBundle = serde_json::from_value(legacy_payload).unwrap();
        assert_eq!(
            decoded.gamma_convexity_layer.availability,
            GammaConvexityAvailability::Unavailable
        );
        assert!(
            decoded
                .gamma_convexity_layer
                .unavailable_reasons
                .contains(&GammaConvexityUnavailableReason::EmptyChain)
        );
        assert!(decoded.gamma_convexity_layer.exposure.is_none());
        assert!(decoded.gamma_convexity_layer.sign_scenarios.is_empty());
        assert_eq!(decoded.prediction_layer[0].decision, original_decision);
    }

    #[test]
    fn regime_context_as_of_uses_latest_completed_five_minute_state() {
        let session_date = NaiveDate::from_ymd_opt(2026, 7, 23).unwrap();
        let start = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 0)
            .single()
            .unwrap();
        let completed = state_at(start, session_date, 300, 1.0);
        let mut newer_incomplete = state_at(start + Duration::minutes(2), session_date, 298, 2.0);
        newer_incomplete.minute_in_5m_bucket = 1;
        newer_incomplete.completed_5m_bucket_valid = false;
        let states = vec![completed, newer_incomplete];

        let (regime_state, regime_as_of) =
            latest_completed_regime_observation(&states, states.len() - 1).unwrap();

        assert_eq!(regime_state.timestamp, start);
        assert_eq!(regime_as_of, start + Duration::minutes(1));
        assert_ne!(
            regime_as_of,
            states.last().unwrap().timestamp + Duration::minutes(1)
        );
    }

    #[test]
    fn near_close_horizons_choose_independent_latest_legal_queries() {
        let session_date = NaiveDate::from_ymd_opt(2026, 7, 23).unwrap();
        let start = Utc
            .with_ymd_and_hms(2026, 7, 23, 18, 50, 0)
            .single()
            .unwrap();
        let states = vec![
            state_at(start, session_date, 70, 1.0),
            state_at(start + Duration::minutes(9), session_date, 61, 2.0),
            state_at(start + Duration::minutes(10), session_date, 60, 3.0),
            state_at(start + Duration::minutes(40), session_date, 30, 4.0),
        ];
        let latest = states.len() - 1;

        assert_eq!(
            latest_legal_horizon_query_index(&states, latest, 5),
            Some(3)
        );
        assert_eq!(
            latest_legal_horizon_query_index(&states, latest, 15),
            Some(3)
        );
        assert_eq!(
            latest_legal_horizon_query_index(&states, latest, 30),
            Some(2)
        );
        assert_eq!(
            latest_legal_horizon_query_index(&states, latest, 60),
            Some(1)
        );

        let short_feature_hash = feature_hash(&states[3]).unwrap();
        let long_feature_hash = feature_hash(&states[1]).unwrap();
        assert_ne!(short_feature_hash, long_feature_hash);
        assert_eq!(
            states[3].timestamp + Duration::minutes(1),
            start + Duration::minutes(41)
        );
        assert_eq!(
            states[1].timestamp + Duration::minutes(1),
            start + Duration::minutes(10)
        );
    }

    #[test]
    fn unavailable_long_horizon_never_falls_back_to_another_session() {
        let prior_date = NaiveDate::from_ymd_opt(2026, 7, 22).unwrap();
        let current_date = NaiveDate::from_ymd_opt(2026, 7, 23).unwrap();
        let start = Utc
            .with_ymd_and_hms(2026, 7, 22, 14, 30, 0)
            .single()
            .unwrap();
        let states = vec![
            state_at(start, prior_date, 300, 1.0),
            state_at(start + Duration::days(1), current_date, 30, 2.0),
        ];
        let latest = states.len() - 1;
        assert_eq!(
            latest_legal_horizon_query_index(&states, latest, 5),
            Some(1)
        );
        assert_eq!(
            latest_legal_horizon_query_index(&states, latest, 15),
            Some(1)
        );
        assert_eq!(latest_legal_horizon_query_index(&states, latest, 60), None);
        let unavailable = boundary_unavailable_horizon(60);
        assert_eq!(unavailable.status, "HORIZON_CROSSES_SESSION_BOUNDARY");
        assert_eq!(
            unavailable.validation_flags,
            vec!["HORIZON_CROSSES_SESSION_BOUNDARY"]
        );
    }

    #[test]
    fn prediction_identity_is_repeatable_and_excludes_issue_time() {
        let cutoff = Utc
            .with_ymd_and_hms(2026, 7, 23, 19, 31, 0)
            .single()
            .unwrap();
        let first = deterministic_prediction_id(
            "SPY",
            cutoff,
            15,
            "model-hash",
            "feature-hash",
            "manifest-hash",
        );
        let repeated = deterministic_prediction_id(
            "SPY",
            cutoff,
            15,
            "model-hash",
            "feature-hash",
            "manifest-hash",
        );
        assert_eq!(first, repeated);
        assert_ne!(
            first,
            deterministic_prediction_id(
                "SPY",
                cutoff + Duration::minutes(1),
                15,
                "model-hash",
                "feature-hash",
                "manifest-hash",
            )
        );
        assert_ne!(
            first,
            deterministic_prediction_id(
                "SPY",
                cutoff,
                60,
                "model-hash",
                "feature-hash",
                "manifest-hash",
            )
        );
        assert_ne!(
            first,
            deterministic_prediction_id(
                "SPY",
                cutoff,
                15,
                "model-hash",
                "different-feature-hash",
                "manifest-hash",
            )
        );
    }

    #[test]
    fn forward_shadow_does_not_relabel_an_old_horizon_cutoff_as_new_input() {
        let cutoff = Utc
            .with_ymd_and_hms(2026, 7, 23, 19, 0, 0)
            .single()
            .unwrap();
        let mut bundle = bundle_with(contract_at(cutoff));
        enforce_moomoo_forward_shadow(
            &mut bundle,
            cutoff + Duration::minutes(30),
            "test-v1",
            250,
            false,
        );
        let contract = &bundle.prediction_layer[0];
        assert_eq!(contract.observation_cutoff, cutoff);
        assert_eq!(contract.as_of, cutoff);
        assert_eq!(contract.decision_as_of, cutoff);
        assert_eq!(contract.latest_input_available_at, cutoff);
        assert_eq!(
            contract.earliest_executable_time,
            cutoff + Duration::milliseconds(250)
        );
        assert_eq!(contract.data_source, "ORIGINAL_FEATURE_SOURCE");
        assert_eq!(contract.data_capability_level, "D0");
        assert_eq!(contract.availability_semantics, "ORIGINAL_FEATURE_CUTOFF");
        assert_eq!(contract.calibration_status, "UNVALIDATED");
        assert!(
            contract
                .decision
                .no_trade_reasons
                .contains(&FORWARD_SHADOW_CUTOFF_MISMATCH_REASON.to_string())
        );
        assert_eq!(contract.decision.action, "NO_TRADE");
        assert!(!contract.decision.eligible);
        assert!(
            bundle
                .conclusions
                .iter()
                .any(|row| row == "FORWARD SHADOW AVAILABLE_AT NOT ALIGNED WITH CONTRACT CUTOFFS")
        );
    }

    #[test]
    fn aligned_forward_shadow_records_availability_but_preserves_feature_as_of() {
        let cutoff = Utc
            .with_ymd_and_hms(2026, 7, 23, 19, 30, 0)
            .single()
            .unwrap();
        let available_at = cutoff + Duration::seconds(2);
        let mut bundle = bundle_with(contract_at(cutoff));
        bundle.behavioral_state_layer =
            BehavioralStateLayer::unavailable(Some(cutoff), "TEST_FIXTURE");
        enforce_moomoo_forward_shadow(&mut bundle, available_at, "test-v1", 250, false);
        let contract = &bundle.prediction_layer[0];
        assert_eq!(contract.observation_cutoff, cutoff);
        assert_eq!(contract.as_of, cutoff);
        assert_eq!(contract.decision_as_of, available_at);
        assert_eq!(contract.latest_input_available_at, available_at);
        assert_eq!(
            contract.earliest_executable_time,
            available_at + Duration::milliseconds(250)
        );
        assert_eq!(contract.data_source, "MOOMOO_OPEND:test-v1");
        assert_eq!(contract.data_capability_level, "D1_REALTIME_UNDERLYING");
        assert_eq!(
            contract.calibration_status,
            "FORWARD_SHADOW_FAIL_CLOSED:CALIBRATION_NOT_EVALUATED"
        );
        assert!(
            !contract
                .decision
                .no_trade_reasons
                .contains(&FORWARD_SHADOW_CUTOFF_MISMATCH_REASON.to_string())
        );
        assert_eq!(contract.decision.action, "NO_TRADE");
        assert!(!contract.decision.eligible);
        assert_eq!(
            bundle.behavioral_state_layer.latest_input_available_at,
            Some(available_at)
        );
        assert_eq!(
            bundle.behavioral_state_layer.input_availability_status,
            "VERIFIED_PROVIDER_AVAILABILITY"
        );
        assert!(
            bundle
                .conclusions
                .iter()
                .any(|row| row == "ALL CONTRACT INPUTS ALIGNED FOR FORWARD SHADOW")
        );
    }

    #[test]
    fn chronological_hmm_selection_scores_the_eight_state_challenger() {
        let sessions = (0..14)
            .map(|session| {
                (0..60)
                    .map(|bucket| {
                        let regime: f64 = match bucket % 4 {
                            0 => -1.5,
                            1 => -0.4,
                            2 => 0.5,
                            _ => 1.6,
                        };
                        vec![
                            regime + session as f64 * 0.001,
                            0.5 * regime,
                            regime.abs() + (bucket % 3) as f64 * 0.01,
                            (bucket % 5) as f64 * 0.1,
                        ]
                    })
                    .collect::<Vec<_>>()
            })
            .collect::<Vec<_>>();
        let config = RegimeResearchConfig {
            state_candidates: vec![2, 8],
            validation_fraction: 0.20,
            minimum_validation_sessions: 2,
            max_iterations: 12,
            restarts: 1,
            ..RegimeResearchConfig::default()
        };
        let (model, report) = select_hmm_model(&sessions, &config).unwrap();
        assert_eq!(model.states, report.selected_state_count);
        assert_eq!(report.candidate_scores.len(), 2);
        assert!(report.candidate_scores.iter().any(|score| {
            score.state_count == 8 && score.validation_average_log_likelihood.is_some()
        }));
        assert!(
            report
                .probability_semantics
                .contains("NO_FULL_SAMPLE_SMOOTHING")
        );
    }
}
