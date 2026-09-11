/** Python-derived historical observations. Client code renders these numbers. */
export interface DeskPoint {
  date: string; close: number; high: number; low: number;
  sma20: number | null; sma50: number | null; rsi14: number | null;
}
export interface DeskLatest {
  rsi14: number | null; sma20: number | null; sma50: number | null;
  atr14: number | null; realizedVol20Percent: number | null;
  priceVsSma20Percent: number | null; changePercent: number | null;
  high20: number | null; low20: number | null;
}
export interface DeskSymbol {
  symbol: string; name: string; assetType: 'stock' | 'etf' | 'closed_end_fund';
  role: 'research_watchlist' | 'market_proxy'; source: string; retrievedAt: string;
  observedAt: string; dailyBarLastDate: string; dailyBarCloseObservedAt: null;
  dailyBarTimestampMeaning: string; spot: number; spotBasis: string; currency: 'USD';
  /** Both fields are percent values: 35.8 means 35.8%, not 0.358. */
  iv: number | null; ivPercentile: number | null; ivObservedAt: null; ivPercentileObservedAt: null;
  ivBasis: string; ivPercentileLookback: string; freshness: 'historical_snapshot_not_live';
  coverage: {
    state: 'observed_sessions_only_calendar_unverified'; observedSessions: number; sourceSessions: number;
    validationExcludedPrefixSessions: number; startDate: string; endDate: string;
    expectedSessions: null; invalidDates: string[]; validationNote: string; adjustmentPolicy: string;
  };
  latest: DeskLatest; series: DeskPoint[]; changeBasis: string; rangeBasis: string; executionEnabled: false;
}
export interface DeskData {
  schemaVersion: 'leo-research-desk.v1'; retrievedAt: string;
  dataMode: 'historical_snapshot_not_live'; sourceRetrievals: string[];
  units: Record<string, string>;
  methodology: { featureVersion: string; baseIndicators: string; sma50: string; high20Low20: string;
    changePercent: string; projectionEnabled: false; executionEnabled: false };
  indexContext: { state: 'etf_proxies_only' | 'unavailable'; symbols: string[]; indicesObserved: false;
    exclusions: { symbol: string; reason: string }[]; note: string };
  symbols: DeskSymbol[]; limitations: string[];
}
