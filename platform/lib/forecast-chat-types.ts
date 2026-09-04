import type { WebForecastDistribution } from '@/lib/quant/web-forecast';
import type { MacroReport } from '@/lib/market-intelligence/macro';
import type { NewsPulseReport } from '@/lib/market-intelligence/news-pulse';

export type DevelopmentReplayReceipt = {
  mode: 'DATABENTO_PIPELINE_REPLAY';
  replayId: string;
  sourceContract: 'quant_engine_rs::data::databento_replay';
  observationCutoff: string;
  inputEnvelopeCount: number;
  contextObservationCount: number;
  sourceMode:
    | 'RECORDED_DATABENTO_ENVELOPES'
    | 'DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK'
    | 'STRICT_INSTALLED_HISTORICAL_REPLAY';
  syntheticContextIntervals: number;
  artifactFeatureIdentityMatchesReplay: boolean;
  replayLocalModelTrained: true;
  productionArtifactUsed: false;
  rustInference: true;
  currentMarketData: false;
  liveStateWritten: false;
};

export type ForecastSourceState =
  | 'real_time'
  | 'delayed'
  | 'historical'
  | 'partial'
  | 'computed'
  | 'unavailable';

export type ForecastSource = {
  id: string;
  name: string;
  state: ForecastSourceState;
  role: string;
  asOf?: string | null;
  note: string;
};

export type ForecastAsset = {
  symbol: string;
  dataSymbol: string;
  name: string;
  price: number | null;
  changePct: number | null;
  change5dPct: number | null;
  change1mPct: number | null;
  rsi14: number | null;
  sma20: number | null;
  sma50: number | null;
  sma200: number | null;
  deviation200Pct: number | null;
  asOf: string | null;
  priceProvider: string;
  historyProvider: string;
  historyObservations: number;
  historyFrom: string | null;
  historyTo: string | null;
  trendLabel: string;
  factors: Record<string, number | null>;
  prediction: WebForecastDistribution | null;
};

export type ForecastEvidence = {
  id: string;
  title: string;
  source: string;
  url?: string;
  publishedAt: string;
  kind: 'news' | 'filing' | 'market_event';
};

export type MarketQueryIntent = 'scan' | 'forecast' | 'backtest';
export type MarketSetupType =
  | 'model_forecast'
  | 'momentum'
  | 'gamma_squeeze'
  | 'vwap_reversal'
  | 'opening_turn'
  | 'closing_short_cover'
  | 'statistical_dislocation';

export type MarketQueryV1 = {
  /**
   * v2 owns neutral core-model forecasts. v1 is retained only so existing
   * stored explicit-rule monitors survive a rolling deployment.
   */
  version: 'axio.market-query.v1' | 'axio.market-query.v2';
  intent: MarketQueryIntent;
  setup_type: MarketSetupType;
  symbols: string[];
  /**
   * Omitted for a neutral model forecast, which requests every configured
   * horizon. Deterministic rule scans and backtests must provide one.
   */
  horizon_minutes?: 5 | 15 | 30 | 60;
  limit: number;
  filters: {
    /**
     * Omitted when the model, rather than the query compiler, determines the
     * directional state. Deterministic rule scans and backtests require it.
     */
    direction?: 'down' | 'up';
    require_realtime: boolean;
    include_historical: boolean;
    max_data_age_seconds: number;
    max_dte: number;
    exclude_earnings_within_days?: number;
    maximum_option_spread_pct?: number;
    minimum_option_quote_coverage?: number;
  };
};

export type MarketMonitorView = {
  id: string;
  title: string;
  source_question: string;
  query: MarketQueryV1;
  status: 'active' | 'paused' | 'disabled';
  cadence_minutes: number;
  next_run_at: string;
  last_run_at: string | null;
  last_result_status: string | null;
  last_error: string | null;
  last_triggered_at: string | null;
  consecutive_failures: number;
  created_at: string;
  updated_at: string;
  latest_event: {
    id: string;
    triggered_at: string;
    title: string;
    summary: string;
    read_at: string | null;
  } | null;
};

export type MarketMonitorAction = {
  requested: true;
  status:
    | 'CREATED'
    | 'ALREADY_ACTIVE'
    | 'AUTHENTICATION_REQUIRED'
    | 'STORAGE_UNAVAILABLE';
  message: string;
  monitor?: MarketMonitorView;
};

export type QuantEvidenceItem = {
  code: string;
  statement: string;
  observed_value?: unknown;
};

export type QuantDataFreshness = {
  source: string;
  observed_at?: string | null;
  available_at?: string | null;
  age_seconds?: number | null;
  realtime: boolean;
  entitlement: string;
  coverage?: number | null;
};

export type QuantResearchCandidate = {
  symbol: string;
  setup_type: MarketSetupType;
  status: string;
  heuristic_structure_score?: number | null;
  score_semantics: string;
  supporting_evidence: QuantEvidenceItem[];
  contrary_evidence: QuantEvidenceItem[];
  metrics: Record<string, unknown>;
  freshness: QuantDataFreshness[];
};

export type QuantHistoricalStats = {
  symbol: string;
  setup_type: MarketSetupType;
  method_version: string;
  event_definition: string;
  source: string;
  dataset_start?: string | null;
  dataset_end?: string | null;
  sessions: number;
  event_sessions: number;
  event_rate?: number | null;
  event_bar_q25?: number | null;
  event_bar_median?: number | null;
  event_bar_q75?: number | null;
  median_clock_et?: string | null;
  top_event_bars: Array<Record<string, unknown>>;
  forward_label_minutes: number;
  completed_backtests: number;
  session_integrity: {
    target_rows: number;
    unique_regular_session_rows: number;
    exact_duplicate_rows: number;
    conflicting_duplicate_rows: number;
    observed_sessions: number;
    complete_sessions: number;
    excluded_sessions: number;
    session_exclusion_counts: Record<string, number>;
  };
  label_integrity: {
    detected_events: number;
    completed_labels: number;
    excluded_events: number;
    event_exclusion_counts: Record<string, number>;
  };
  vwap_status: {
    policy: string;
    eligible_minute_rows: number;
    authorized_vendor_vwap_rows: number;
    reported_but_unauthorized_vendor_vwap_rows: number;
    authorized_vendor_minute_coverage: number;
    sessions_using_authorized_vendor_vwap: number;
    sessions_using_reconstructed_proxy: number;
    parity_observations: number;
    median_absolute_parity_bps?: number | null;
    maximum_absolute_parity_bps?: number | null;
  };
  entry_semantics: string;
  assumed_round_trip_cost_bps: number;
  raw_forward_direction_frequency?: number | null;
  median_forward_return?: number | null;
  forward_return_q05?: number | null;
  forward_return_q95?: number | null;
  median_mfe?: number | null;
  median_mae?: number | null;
  net_win_rate?: number | null;
  mean_net_return?: number | null;
  median_net_return?: number | null;
  cumulative_net_return?: number | null;
  max_drawdown?: number | null;
  edge_classification:
    | 'INSUFFICIENT_EVIDENCE'
    | 'NO_DEMONSTRATED_EDGE'
    | 'POSITIVE_AFTER_COST_DESCRIPTIVE';
  edge_classification_detail: string;
  performance_scope: string;
  data_manifest_hash?: string | null;
  evidence_grade: string;
  caveats: string[];
};

export type QuantReadinessStage = {
  state: 'ready' | 'waiting' | 'blocked' | 'not_checked' | string;
  code?: string | null;
  detail?: string | null;
  observed_at?: string | null;
};

export type QuantPipelineReadiness = Partial<
  Record<
    'model' | 'feed' | 'context' | 'inference' | 'publication',
    QuantReadinessStage
  >
>;

export type QuantEvidenceEnvelope = {
  schema_version: 'axio.evidence-envelope.v1';
  evidence_mode?:
    | 'deterministic_historical_replay'
    | 'local_uncalibrated_live_research';
  request_id: string;
  query_sha256: string;
  response_sha256?: string | null;
  generated_at: string;
  observation_cutoff: string;
  status: 'AVAILABLE' | 'PARTIAL' | 'DATA_UNAVAILABLE' | string;
  query: MarketQueryV1;
  candidates: QuantResearchCandidate[];
  exclusions: Array<Record<string, unknown>>;
  historical: QuantHistoricalStats[];
  data_blockers: string[];
  model_contract: Record<string, unknown>;
  research_only_policy: Record<string, unknown>;
  caveats: string[];
  /**
   * Newer Rust services may emit explicit pipeline stages. The web client
   * treats the field as optional so an older fail-closed service remains
   * readable while never being mistaken for live-ready.
   */
  readiness?: QuantPipelineReadiness;
};

export type QuantSessionFiveMinuteBar = {
  bar_number: number;
  window_start: string;
  window_end: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  return_pct: number;
  minute_rows: number;
};

export type QuantSessionSummary = {
  schema_version: 'axio.session-summary.v1';
  status: 'COMPLETE_78_BAR_SESSION' | 'SESSION_TO_DATE';
  result_kind: 'OBSERVED_SESSION_TREND';
  scope:
    | 'LAST_COMPLETED_REGULAR_SESSION'
    | 'CURRENT_REGULAR_SESSION_TO_DATE';
  public_symbol: string;
  data_symbol: string;
  proxy_disclosure: string;
  session_date_et: string;
  trend_state: 'UP_SESSION' | 'DOWN_SESSION' | 'FLAT_SESSION';
  session_return_pct: number;
  session_open: number;
  session_high: number;
  session_low: number;
  session_close: number;
  session_range_pct: number;
  close_location_pct: number;
  total_volume: number;
  close_volume_proxy: number | null;
  close_vs_close_volume_proxy_bps: number | null;
  minute_rows: number;
  five_minute_bar_count: number;
  latest_completed_bar: QuantSessionFiveMinuteBar | null;
  peak_windows: QuantSessionFiveMinuteBar[];
  five_minute_bars: QuantSessionFiveMinuteBar[];
  source: {
    provider: 'databento';
    dataset: 'EQUS.MINI';
    schema: 'ohlcv-1m';
    storage: 'APPEND_ONLY_SQLITE';
    first_observed_at: string;
    last_observed_at: string;
    last_available_at: string;
    entitlements: string[];
  };
  freshness: {
    status: 'NOT_EVALUATED_FOR_LIVE_USE';
    observation_cutoff: string;
    available_at: string;
  };
  coverage: {
    expected_regular_session_minutes: 390;
    observed_regular_session_minutes: number;
    ratio: number;
  };
  model_status: 'LIVE_FROZEN_MODEL_RESULT_NOT_AVAILABLE_FOR_THIS_CUTOFF';
  model_version: null;
  feature_version: null;
  probability_published: false;
  automatic_execution_enabled: false;
  caveats: string[];
};

export type QuantTickerRagResult = {
  requested_symbol: string;
  canonical_symbol: string;
  data_symbol: string;
  status:
    | 'RETRIEVED'
    | 'NO_STORED_OBSERVATIONS'
    | 'INSUFFICIENT_DATA'
    | 'RETRIEVAL_FAILED';
  reason_code: string | null;
  reason: string | null;
  summary: QuantSessionSummary | null;
};

export type QuantTickerRagBundle = {
  schema_version: 'axio.ticker-rag.v1';
  generated_at: string;
  requested_count: number;
  result_count: number;
  retrieval_policy: 'EXACT_SYMBOL_POINT_IN_TIME_DATABASE_LOOKUP';
  storage: 'APPEND_ONLY_SQLITE_WITH_POSTGRES_ARCHIVE';
  results: QuantTickerRagResult[];
  probability_published: false;
  automatic_execution_enabled: false;
  caveats: string[];
};

export type QuantDailyRegimeLabel =
  | 'HIGH_VOL_SELL_OFF'
  | 'HIGH_VOL_RECOVERY'
  | 'LOW_VOL_BREAKOUT'
  | 'RISK_ON_TREND'
  | 'RISK_OFF_TREND'
  | 'HIGH_VOL_RANGE'
  | 'LOW_VOL_RANGE'
  | 'MIXED_TRANSITION';

export type QuantDailyHistoricalSession = {
  rank: number;
  session_date_et: string;
  regime: QuantDailyRegimeLabel;
  standardized_euclidean_distance: number;
  session_return_pct: number;
  next_session_date_et: string;
  next_session_return_pct: number;
  next_session_direction: 'UP' | 'DOWN' | 'FLAT';
};

export type QuantDailyRegimeReport = {
  schema_version: 'axio.daily-regime.v3';
  status: 'AVAILABLE_UNCALIBRATED';
  result_kind: 'NEXT_REGULAR_SESSION_ANALOG_LEAN';
  generated_at: string;
  observation_cutoff: string;
  public_symbol: 'SPX';
  data_symbol: 'SPY';
  proxy_disclosure: string;
  forecast_horizon: 'NEXT_COMPLETE_US_REGULAR_SESSION';
  current_regime: {
    label: QuantDailyRegimeLabel;
    display_name: string;
    definition: string;
    market_summary: string;
    classification_reasons: string[];
    volatility_percentile_prior_252: number;
    cross_asset_breadth: number;
  };
  regime_taxonomy: Array<{
    priority: number;
    label: QuantDailyRegimeLabel;
    display_name: string;
    definition: string;
    selection_rule: string;
    active: boolean;
  }>;
  current_market: {
    session_date_et: string;
    open: number;
    high: number;
    low: number;
    close: number;
    session_return_pct: number;
    twenty_session_return_pct: number;
    twenty_session_annualized_volatility_pct: number;
    close_location_pct: number;
    minute_coverage: Record<string, number>;
  };
  prediction: {
    lean: 'UP' | 'DOWN' | 'MIXED';
    directional_call_status:
      | 'PUBLISHED_RAW_RESEARCH_LEAN'
      | 'WITHHELD_INSUFFICIENT_AGREEMENT';
    target_definition: string;
    analog_sample_size: number;
    raw_up_count: number;
    raw_down_or_flat_count: number;
    raw_up_frequency: number;
    raw_directional_agreement: number;
    minimum_directional_agreement: number;
    reported_evidence_strength: number | null;
    median_next_session_return_pct: number;
    mean_next_session_return_pct: number;
    calibrated_probability: false;
    interpretation: string;
  };
  raw_likelihood: {
    method: 'NEAREST_SAME_REGIME_EMPIRICAL_SIGN_FREQUENCY';
    sample_size: number;
    up_count: number;
    down_or_flat_count: number;
    up_estimate: number;
    down_or_flat_estimate: number;
    confidence_method: 'WILSON_SCORE_INTERVAL';
    confidence_level: number;
    up_lower_bound: number;
    up_upper_bound: number;
    calibrated_probability: false;
    interpretation: string;
  };
  prediction_interval: {
    method: 'PREQUENTIAL_ABSOLUTE_RESIDUAL_CONFORMAL';
    nominal_coverage: number;
    point_estimate_pct: number;
    lower_bound_pct: number;
    upper_bound_pct: number;
    calibration_sessions: number;
    evaluated_sessions: number;
    covered_sessions: number;
    empirical_coverage: number | null;
    directional_probability: false;
    interpretation: string;
  };
  prediction_rationale: {
    conclusion: string;
    supporting_evidence: string[];
    opposing_evidence: string[];
    uncertainty_reasons: string[];
    model_steps: string[];
  };
  similar_historical_sessions: QuantDailyHistoricalSession[];
  same_regime_history: QuantDailyHistoricalSession[];
  walk_forward_validation: {
    method: 'PURGED_EXPANDING_WALK_FORWARD';
    evaluation_window_sessions: number;
    eligible_queries: number;
    directional_calls: number;
    correct_directional_calls: number;
    raw_directional_hit_frequency: number | null;
    probability_interpretation_allowed: false;
    notes: string[];
  };
  feature_snapshot: Array<{
    name: string;
    value: number;
    unit: string;
  }>;
  source: {
    provider: 'Databento';
    dataset: 'EQUS.MINI';
    schema: 'ohlcv-1m';
    session_clock: '09:30-16:00 America/New_York';
    history_start: string;
    history_end: string;
    complete_feature_sessions: number;
    acquired_at: string;
    latest_available_at: string;
    dataset_sha256: string;
    files: Array<{
      request_name: string;
      file_name: string;
      bytes: number;
      sha256: string;
      acquired_at: string;
    }>;
  };
  model_contract: {
    model_id: 'axio7.spx-next-session-regime-analog';
    model_version: string;
    owner: 'quant_engine_rs';
    regime_algorithm: string;
    analog_algorithm: string;
    feature_count: number;
    neighbors: number;
    minimum_analogs: number;
    fit_semantics: string;
    label_semantics: string;
    status: 'UNCALIBRATED_RESEARCH_OUTPUT';
    source_code: 'quant_engine_rs/src/daily_regime.rs';
  };
  macro_news_policy: {
    status: 'DISPLAY_CONTEXT_ONLY_NOT_NUMERICAL_MODEL_INPUT';
    detail: string;
  };
  probability_published: false;
  automatic_execution_enabled: false;
  caveats: string[];
};

export type ModelCodeInventoryItem = {
  id: string;
  name: string;
  layer: 'production_rust' | 'offline_python' | 'native_cpp';
  status: 'active' | 'frozen_candidate' | 'research_only' | 'validation_gate';
  algorithm: string;
  sourcePath: string;
  sourceUrl: string;
};

export type ForecastChatResult = {
  generatedAt: string;
  model: string;
  horizon: string;
  assets: ForecastAsset[];
  sources: ForecastSource[];
  evidence: ForecastEvidence[];
  disclaimer: string;
  research?: QuantEvidenceEnvelope;
  sessionSummary?: QuantSessionSummary;
  tickerRag?: QuantTickerRagBundle;
  dailyRegime?: QuantDailyRegimeReport;
  macroContext?: MacroReport | null;
  newsContext?: NewsPulseReport | null;
  modelCodeInventory?: ModelCodeInventoryItem[];
  compilerNotes?: string[];
  developmentReplay?: DevelopmentReplayReceipt;
};
