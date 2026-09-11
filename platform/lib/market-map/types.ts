/** Engine serialization contract. Explicit types keep Zod inference out of the UI. */
export type MarketMapHorizon = '5d' | '10d' | '20d' | '60d';
type TimeValue = { observed_at: string; value: number };
type PricePoint = { observed_at: string; price: number };
type ProjectionPoint = { session_offset: number; projected_at: string; price: number };
type EvidenceRefs = { evidence_refs: string[] };
export type MarketMapSnapshot = {
  snapshot_id: string;
  asset: { asset_id: string; symbol: string; name: string; asset_type: 'equity' | 'etf' | 'market_index'; exchange: string; currency: string; market_timezone: string };
  horizon: MarketMapHorizon;
  timeframe: '1d';
  state: 'bull' | 'neutral' | 'bear';
  last_price: number;
  bars: { observed_at: string; open: number; high: number; low: number; close: number; volume: number; session: 'regular' }[];
  technical_indicators: {
    sma20: { period_sessions: 20; points: PricePoint[] };
    bollinger20: { period_sessions: 20; standard_deviations: number; points: { observed_at: string; lower: number; middle: number; upper: number }[] };
    rsi14: { period_sessions: 14; points: TimeValue[]; latest: number };
    atr14: { period_sessions: 14; points: TimeValue[]; latest: number };
    momentum: { lookback_sessions: number; signal_sessions: number; state: 'knife' | 'falling' | 'flat' | 'rising' | 'spike'; points: { observed_at: string; value: number; signal: number; velocity_percent_per_session: number; acceleration_percent_per_session_squared: number }[] };
  };
  zigzag: {
    reversal_threshold_percent: number;
    confirmed_pivots: { id: string; observed_at: string; confirmed_at: string; price: number; kind: 'high' | 'low'; confirmed: true }[];
    provisional_leg: { from_observed_at: string; from_price: number; to_observed_at: string; to_price: number; direction: 'up' | 'down'; confirmed: false } | null;
  };
  levels: (EvidenceRefs & { id: string; role: 'stretch' | 'resistance' | 'last' | 'sma20' | 'support' | 'down'; label: string; price: number; distance_from_last_percent: number; method: string })[];
  scenarios: (EvidenceRefs & { id: string; kind: 'bull' | 'base' | 'bear'; label: string; interpretation: string; is_forecast: false; points: ProjectionPoint[] })[];
  monte_carlo: EvidenceRefs & {
    as_of: string; horizon_sessions: number; trial_count: number; input_sha256: string; seed_sha256: string;
    model: 'historical_block_bootstrap'; calibration_status: 'uncalibrated'; sample_window_sessions: number;
    block_length_sessions: number; return_basis: 'log_close_to_close'; path_sampling_method: 'deterministic_stratified';
    sampled_paths: { sample_id: number; points: ProjectionPoint[] }[];
    terminal_particles: { sample_id: number; terminal_price: number; terminal_return_percent: number }[];
    terminal_density: { lower_price: number; upper_price: number; sample_count: number; probability_mass: number; density: number }[];
    terminal_quantiles: { p01: number; p05: number; p25: number; p50: number; p75: number; p95: number; p99: number };
    assumptions: string[]; interpretation: 'uncalibrated_simulation_not_forecast';
  };
  panels: {
    volume: EvidenceRefs & {
      latest_volume: number; average_volume: number; average_window_sessions: number; relative_volume: number;
      series: { observed_at: string; volume: number }[];
      volume_at_price?: { method: 'observed_trade_volume'; source_id: string; bins: { lower_price: number; upper_price: number; volume: number; recent_volume: number; side: 'supply' | 'demand' | 'at_last' }[]; point_of_control_price: number };
    };
    implied_volatility: EvidenceRefs & { source_observed_at: string; tenor_days: number; moneyness: 'atm'; current_percent: number; change_5d_percentage_points: number; series: { observed_at: string; percent: number }[] };
    sector: EvidenceRefs & { sector_id: string; sector_name: string; benchmark_symbol: string; return_5d_percent: number; asset_relative_5d_percent: number; state: 'defensive' | 'neutral' | 'offensive'; series: TimeValue[] };
  };
  evidence: { id: string; kind: 'bar' | 'indicator' | 'pivot' | 'level' | 'simulation' | 'volume' | 'options' | 'sector'; label: string; source_id: string; observed_at: string; field_path: string }[];
  read: {
    as_of: string; language: string; title: string; summary: string;
    items: (EvidenceRefs & { id: string; kind: 'range' | 'trend' | 'momentum' | 'volatility' | 'volume' | 'sector' | 'simulation' | 'limitation'; text: string })[];
    disclosure: string;
  };
  provenance: {
    sources: { id: string; provider: string; dataset: string; observed_at: string; available_at: string; retrieved_at: string; delay_minutes: number }[];
    observation_cutoff: string; available_at: string; generated_at: string;
    freshness: { state: 'fresh' | 'stale' | 'expired'; max_age_seconds: number; expires_at: string };
    coverage: { state: 'complete' | 'partial' | 'insufficient'; completeness_ratio: number; start_at: string; end_at: string; expected_sessions: number; observed_sessions: number; required_inputs: { name: 'ohlcv' | 'corporate_actions' | 'options_iv' | 'sector_benchmark' | 'simulation_artifact'; state: 'available' | 'missing' | 'stale' | 'partial' | 'unentitled'; observed_at: string }[]; regular_session_only: true; corporate_actions_adjusted: boolean };
    rights: { entitlement: 'member_research' | 'none'; display_authorized: boolean; redistribution_authorized: false };
    versions: { schema: 'market-map-snapshot-v1'; market_data: string; features: string; monte_carlo_model: string; methodology: string };
    caveats: string[];
  };
};

/** Real public-source research has its own contract; it never enters member gates. */
export type PublicMarketMapSnapshot = Omit<MarketMapSnapshot, 'asset' | 'bars' | 'panels' | 'provenance'> & {
  mode: 'public_market';
  calendar: 'continuous' | 'exchange';
  price_adjustment: 'unadjusted' | 'split_adjusted' | 'split_dividend_adjusted' | 'source_adjusted_unverified';
  asset: Omit<MarketMapSnapshot['asset'], 'asset_type'> & { asset_type: 'crypto' | 'equity' | 'etf' };
  bars: (Omit<MarketMapSnapshot['bars'][number], 'session'> & { session: 'continuous' | 'regular' | 'exchange_daily' })[];
  panels: Omit<MarketMapSnapshot['panels'], 'implied_volatility'> & { implied_volatility: null };
  provenance: Omit<MarketMapSnapshot['provenance'], 'coverage' | 'rights' | 'versions'> & {
    coverage: Omit<MarketMapSnapshot['provenance']['coverage'], 'required_inputs' | 'regular_session_only'> & {
      required_inputs: { name: 'ohlcv' | 'benchmark' | 'simulation_artifact'; state: 'available'; observed_at: string }[];
      missing_inputs: ('options_iv' | 'trade_volume_profile')[];
      regular_session_only: boolean;
    };
    rights: { access: 'government_open_data' | 'unauthenticated_public_api' | 'public_market_data'; terms_url: string; usage_note: string };
    versions: Omit<MarketMapSnapshot['provenance']['versions'], 'schema'> & { schema: 'market-map-public-snapshot-v1' };
  };
};

export type PublicMarketMapReceipt = {
  url: string;
  retrieved_at: string;
  sha256: string;
  record_count: number;
};

export type PublicMarketMapBundle = {
  mode: 'public_market';
  generated_at: string;
  expires_at: string;
  snapshots: PublicMarketMapSnapshot[];
  receipts: PublicMarketMapReceipt[];
};
