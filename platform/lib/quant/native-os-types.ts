export type NativeJsonPrimitive = string | number | boolean | null;

export type NativeJsonValue =
  | NativeJsonPrimitive
  | NativeJsonValue[]
  | { [key: string]: NativeJsonValue };

export type NativeJsonRecord = { [key: string]: NativeJsonValue | undefined };

export type NativeResourceStatus =
  | 'READY'
  | 'AVAILABLE'
  | 'OK'
  | 'DEGRADED'
  | 'BLOCKED'
  | 'UNAVAILABLE'
  | 'EMPTY'
  | 'PENDING'
  | 'UNKNOWN'
  | 'NO_TRADE'
  | 'ERROR'
  | 'RUNNING'
  | 'STOPPED'
  | `CONNECTED_${string}`
  | `DISCONNECTED${string}`
  | `AWAITING_${string}`
  | (string & {});

export type NativeResourceEnvelope = NativeJsonRecord & {
  status?: NativeResourceStatus;
  message?: string;
  reason?: string;
  detail?: string;
  generated_at?: string;
  as_of?: string;
  schema_version?: string;
};

export type NativeProbabilityEstimateInterval = NativeJsonRecord & {
  estimate?: number | null;
  lower?: number | null;
  upper?: number | null;
  confidence_level?: number | null;
  effective_sample_size?: number | null;
  method?: string;
  status?: string;
  semantics?: string;
};

export type NativeDirectionProbabilityIntervals = NativeJsonRecord & {
  up?: NativeProbabilityEstimateInterval;
  flat?: NativeProbabilityEstimateInterval;
  down?: NativeProbabilityEstimateInterval;
};

export type NativeKernelRegression = NativeJsonRecord & {
  status?: string;
  feature_dimension_count?: number | null;
  selected_dimensions?: string[];
  metric?: string;
  kernel?: string;
  bandwidth?: number | null;
  neighbor_count?: number | null;
  effective_sample_size?: number | null;
  minimum_effective_sample_size?: number | null;
  nadaraya_watson_expected_return?: number | null;
  local_linear_intercept?: number | null;
  direction_event_threshold_return?: number | null;
  direction_probability_intervals?: NativeDirectionProbabilityIntervals;
  probability_status?: string;
  probability_semantics?: string;
};

export type NativeOutcomePredictionInterval = NativeJsonRecord & {
  probability_mass?: number | null;
  lower_return?: number | null;
  upper_return?: number | null;
  lower_price?: number | null;
  upper_price?: number | null;
  current_close_reference_scenario_lower_price?: number | null;
  current_close_reference_scenario_upper_price?: number | null;
  current_close_reference_scenario_basis?: string;
  current_close_reference_scenario_status?: string;
  current_close_reference_scenario_semantics?: string;
  method?: string;
  status?: string;
  semantics?: string;
};

export type NativeSdeDirectionProbabilities = NativeJsonRecord & {
  p_up?: number | null;
  p_flat?: number | null;
  p_down?: number | null;
  material_move_lower_threshold_log_return?: number | null;
  material_move_upper_threshold_log_return?: number | null;
  method?: string;
  status?: string;
  semantics?: string;
};

export type NativeSdeCentralPredictionInterval = NativeJsonRecord & {
  probability_mass?: number | null;
  lower_log_return?: number | null;
  upper_log_return?: number | null;
  method?: string;
  status?: string;
  semantics?: string;
};

export type NativeSdeHorizonForecast = NativeJsonRecord & {
  horizon_minutes?: number | null;
  direction_probabilities?: NativeSdeDirectionProbabilities;
  central_prediction_intervals?: NativeSdeCentralPredictionInterval[];
};

export type NativeStochasticResearchLayer = NativeJsonRecord & {
  status?: string;
  model_family?: string;
  affects_decision?: boolean;
  probability_semantics?: string;
  research_policy?: string;
  martingale_audit_status?: string;
  horizon_forecast?: NativeSdeHorizonForecast | null;
};

export type NativeProbabilityCalibrationRuntime = NativeJsonRecord & {
  status?: string;
  artifact_id?: string | null;
  method?: string | null;
  raw_analog_up_frequency?: number | null;
  calibrated_probability_up?: number | null;
  calibrated_probability_up_interval?: NativeProbabilityEstimateInterval | null;
  eligible_for_probability_use?: boolean;
  probability_semantics?: string;
  reasons?: string[];
};

export type NativeBehavioralRegimeScore = NativeJsonRecord & {
  regime?: string;
  raw_score?: number | null;
  calibrated_probability?: number | null;
  evidence?: string[];
};

export type NativeBehavioralFeature = NativeJsonRecord & {
  raw_index?: number | null;
  status?: string;
  observability?: string;
  units?: string;
  input_coverage_ratio?: number | null;
  evidence?: string[];
  missing_inputs?: string[];
  caveats?: string[];
};

export type NativeMarketEmotionProxy = NativeJsonRecord & {
  schema_version?: string;
  publication_status?: string;
  measurement_target?: string;
  measurement_semantics?: string;
  dominant_market_response_pattern?: string | null;
  raw_compatibility_index?: number | null;
  score_margin?: number | null;
  units?: string;
  as_of?: string | null;
  source_scope?: string;
  price_flow_feature_coverage_ratio?: number | null;
  required_domain_coverage_ratio?: number | null;
  calibrated_probability?: number | null;
  not_probability?: boolean;
  affects_decision?: boolean;
  reason_codes?: string[];
};

export type NativeBehavioralStateLayer = NativeJsonRecord & {
  schema_version?: string;
  availability?: string;
  observation_cutoff?: string | null;
  decision_as_of?: string | null;
  latest_input_available_at?: string | null;
  input_availability_status?: string;
  source_scope?: string;
  normalized_structural_regime_entropy?: number | null;
  components?: NativeJsonRecord & {
    downside_stress?: NativeBehavioralFeature;
    upside_chase?: NativeBehavioralFeature;
    directional_crowding?: NativeBehavioralFeature;
    attention_intensity?: NativeBehavioralFeature;
    deleveraging_like?: NativeBehavioralFeature;
    rebound_squeeze_like?: NativeBehavioralFeature;
  };
  behavioral_regime?: NativeJsonRecord & {
    dominant?: string | null;
    runner_up?: string | null;
    raw_scores?: NativeBehavioralRegimeScore[];
    score_margin?: number | null;
    status?: string;
    semantics?: string;
  };
  market_emotion_proxy?: NativeMarketEmotionProxy;
  price_flow_feature_coverage_ratio?: number | null;
  required_domain_coverage_ratio?: number | null;
  missing_required_domains?: string[];
  warnings?: string[];
  combined_sentiment_regime_status?: string;
  analog_integration_status?: string;
  artifact_status?: string;
  affects_decision?: boolean;
  probability_semantics?: string;
};

export type NativeForecastRow = NativeJsonRecord & {
  prediction_id?: string;
  symbol?: string;
  horizon_minutes?: number | null;
  label_end?: string;
  reference_price?: number | null;
  expected_price?: number | null;
  current_close_reference_scenario_expected_price?: number | null;
  current_close_reference_scenario_basis?: string;
  current_close_reference_scenario_status?: string;
  current_close_reference_scenario_semantics?: string;
  expected_return?: number | null;
  median_return?: number | null;
  return_definition?: string;
  p_up?: number | null;
  p_flat?: number | null;
  p_down?: number | null;
  raw_analog_up_frequency?: number | null;
  raw_analog_flat_frequency?: number | null;
  raw_analog_down_frequency?: number | null;
  calibrated_probability_up?: number | null;
  published_probability_status?: string;
  probability_calibration?: NativeProbabilityCalibrationRuntime;
  kernel_regression?: NativeKernelRegression;
  outcome_prediction_intervals?: NativeOutcomePredictionInterval[];
  stochastic_research_layer?: NativeStochasticResearchLayer;
  research_status?: string;
  statistical_condition?: string;
  calibration_status?: string;
  evidence_grade?: string;
  sample_size?: number | null;
  epistemic_uncertainty?: number | null;
  ood_score?: number | null;
  filtered_state_probabilities?: number[];
  predicted_state_probabilities?: number[];
  state_entropy?: number | null;
  decision?: NativeJsonValue;
};

export type NativeForecastResource = NativeResourceEnvelope & {
  prediction_layer?: NativeForecastRow[];
  behavioral_state_layer?: NativeBehavioralStateLayer;
  unavailable_horizons?: NativeJsonValue[];
  freshness_status?: string;
  validation_flags?: string[];
};
export type NativeMarketMemoryResource = NativeResourceEnvelope & {
  snapshot_count?: number;
  session_count?: number;
  symbol_count?: number;
  latest_decision_as_of?: string;
  current_snapshot?: NativeJsonValue;
  coverage_by_symbol?: NativeJsonValue[];
  storage_format?: string;
  export_status?: string;
  append_only?: boolean;
};

export type NativeEventAtlasResource = NativeResourceEnvelope & {
  event_count?: number;
  event_type_count?: number;
  effective_sample_size?: number;
  last_detection_at?: string | null;
  taxonomy?: NativeJsonValue;
  responses?: NativeJsonValue[];
  legacy_time_bucket_controls?: NativeJsonValue[];
};

export type NativeAnalogResource = NativeResourceEnvelope & {
  analog_status?: string;
  decision_as_of?: string;
  symbol?: string;
  horizon_label?: string;
  neighbor_count?: number;
  effective_sample_size?: number;
  ood_score?: number;
  expected_return?: number | null;
  expected_price?: number | null;
  current_close_reference_scenario_expected_price?: number | null;
  current_close_reference_scenario_basis?: string;
  current_close_reference_scenario_status?: string;
  current_close_reference_scenario_semantics?: string;
  median_return?: number | null;
  return_definition?: string;
  raw_analog_up_frequency?: number | null;
  calibrated_probability_up?: number | null;
  probability_calibration?: NativeProbabilityCalibrationRuntime;
  kernel_regression?: NativeKernelRegression;
  outcome_prediction_intervals?: NativeOutcomePredictionInterval[];
  analogs?: NativeJsonValue[];
  diagnostics?: NativeJsonValue;
  no_trade_reasons?: string[];
};

export type NativeRawStateCertainty = NativeJsonRecord & {
  direct_allocation_impact?: boolean;
  continuous_sizing_impact?: boolean;
  hard_no_trade_veto_impact?: boolean;
};

export type NativeStateDurationDiagnostics = NativeJsonRecord & {
  duration_model?: string;
  semantics?: string;
  untruncated_geometric_diagnostic?: boolean;
  must_not_extrapolate_past_session_close?: boolean;
};

export type NativeStateDecisionBoundary = NativeJsonRecord & {
  direct_allocation_impact?: boolean;
  continuous_sizing_impact?: boolean;
  hard_no_trade_veto_impact?: boolean;
  execution_eligible?: boolean;
};

export type NativeStateResource = NativeResourceEnvelope & {
  artifact_schema_version?: string;
  observation_cutoff?: string | null;
  latest_input_available_at?: string | null;
  input_availability_status?: string;
  freshness?: NativeJsonValue;
  coverage?: NativeJsonValue;
  state_definition?: NativeJsonValue;
  current_state?: NativeJsonValue;
  raw_state_certainty?: NativeRawStateCertainty;
  duration_diagnostics?: NativeStateDurationDiagnostics;
  decision_boundary?: NativeStateDecisionBoundary;
  cross_session_state_forecast?: NativeJsonValue;
  state_names?: string[];
  state_profiles?: NativeJsonValue[];
  horizon_state_forecasts?: NativeJsonValue[];
  transition_audit?: NativeJsonValue[];
  transition_matrix?: NativeJsonValue[];
  model_comparisons?: NativeJsonValue[];
  caveats?: string[];
};

export type NativeResearchFactoryResource = NativeResourceEnvelope & {
  hypothesis_count?: number;
  variant_count?: number;
  promoted_count?: number;
  motif_count?: number;
  anomaly_count?: number;
  pipeline_stages?: NativeJsonValue[];
  hypotheses?: NativeJsonValue[];
  motifs?: NativeJsonValue[];
  anomalies?: NativeJsonValue[];
  negative_controls?: NativeJsonValue[];
};

export type NativePredictionAuditResource = NativeResourceEnvelope & {
  prediction_count?: number;
  predictions?: NativeJsonValue[];
  checks?: NativeJsonValue;
  reproducibility?: NativeJsonValue;
  ledger?: NativeJsonValue;
};

export type NativeContextFusionResource = NativeResourceEnvelope & {
  provider?: string;
  input_path?: string;
  point_in_time_ready?: boolean | null;
  observation_count?: number | null;
  model_eligible_fields?: string[];
  latest_features?: NativeJsonValue[];
  required_sources?: NativeJsonValue[];
  prohibited_uses?: string[];
  reason_codes?: string[];
};

export type NativeBettingAllocationResource = NativeResourceEnvelope & {
  policy_version?: string;
  symbol?: string;
  horizon_minutes?: number | null;
  forecast_as_of?: string | null;
  evidence_status?: string;
  action?: string;
  executable?: boolean | null;
  target_weight?: number | null;
  raw_kelly_fraction?: number | null;
  fractional_kelly?: number | null;
  net_edge_bps?: number | null;
  shrinkage_factor?: number | null;
  pretrade_checks?: NativeJsonValue;
  reason_codes?: string[];
  truth?: string;
};

export type NativePortfolioAnalyticsResource = NativeResourceEnvelope & {
  new_risk_allowed?: boolean | null;
  kill_switch_recommended?: boolean | null;
  gross_exposure?: number | null;
  net_exposure?: number | null;
  max_position_weight?: number | null;
  historical_var_fraction?: number | null;
  expected_shortfall_fraction?: number | null;
  worst_stress_loss_fraction?: number | null;
  drawdown_fraction?: number | null;
  daily_loss_fraction?: number | null;
  liquidity?: NativeJsonValue[];
  factor_exposures?: NativeJsonValue;
  checks?: NativeJsonValue;
  reason_codes?: string[];
  truth?: string;
};

export type NativeOsStore = {
  system?: NativeResourceEnvelope;
  signal?: NativeResourceEnvelope;
  models?: NativeResourceEnvelope;
  overview?: NativeResourceEnvelope;
  liveStatus?: NativeResourceEnvelope;
  liveCapabilities?: NativeResourceEnvelope;
  liveBars?: NativeResourceEnvelope;
  forecast?: NativeForecastResource;
  forecastQqq?: NativeForecastResource;
  forecastSoxx?: NativeForecastResource;
  forecastNvda?: NativeForecastResource;
  forecastMu?: NativeForecastResource;
  forecastAapl?: NativeForecastResource;
  ownerForecast?: NativeForecastResource;
  ownerForecastQqq?: NativeForecastResource;
  ownerForecastSoxx?: NativeForecastResource;
  ownerForecastNvda?: NativeForecastResource;
  ownerForecastMu?: NativeForecastResource;
  ownerForecastAapl?: NativeForecastResource;
  opportunities?: NativeResourceEnvelope;
  shadow?: NativeResourceEnvelope;
  settlements?: NativeResourceEnvelope;
  dataCapabilities?: NativeResourceEnvelope;
  dataCoverage?: NativeResourceEnvelope;
  memorySummary?: NativeMarketMemoryResource;
  eventAtlas?: NativeEventAtlasResource;
  analogsCurrent?: NativeAnalogResource;
  stateCurrent?: NativeStateResource;
  researchFactory?: NativeResearchFactoryResource;
  auditPredictions?: NativePredictionAuditResource;
  contextFusion?: NativeContextFusionResource;
  bettingAllocation?: NativeBettingAllocationResource;
  portfolioAnalytics?: NativePortfolioAnalyticsResource;
  predictorModel?: NativeResourceEnvelope;
  walkForward?: NativeResourceEnvelope;
  calibration?: NativeResourceEnvelope;
};

export type NativeOsTab =
  | 'overview'
  | 'memory'
  | 'events'
  | 'analogs'
  | 'state'
  | 'motifs'
  | 'strategyRisk'
  | 'research'
  | 'audit';

export type NativeRequestKey = keyof NativeOsStore;

export type NativeRequestDefinition = {
  key: NativeRequestKey;
  path: string;
};
