/** Offline Python output contract. TypeScript renders values; no quant calculations. */
export type OptionRight = 'call' | 'put';
export type TrendState = 'bullish' | 'bearish' | 'neutral';
export interface TechnicalPoint {
  date: string; close: number; volume: number | null;
  sma20: number | null; bollingerUpper: number | null; bollingerLower: number | null;
  rsi14: number | null; atr14: number | null; k: number | null; d: number | null; j: number | null;
  macd: number | null; macdSignal: number | null; macdHistogram: number | null;
  realizedVol20Percent: number | null; relativeVolume20: number | null;
  return1dPercent: number | null; return5dPercent: number | null;
  priceVsSma20Percent: number | null; trend: TrendState;
}
export interface ScenarioCell {
  spotMovePercent: number; ivShiftPp: number;
  newSpot: number; newIvPercent: number; daysRemaining: number;
  status: 'valid' | 'invalid_iv';
  price: number | null; pnl: number | null; pnlPercent: number | null;
  premiumPerContract: number | null; pnlPerContract: number | null;
  priceOnlyPnl: number | null; ivOnlyPnl: number | null;
  timeOnlyPnl: number | null; interactionPnl: number | null;
}
export interface IvLabConfiguration {
  id: string; tenorDays: number; right: OptionRight; strikeOffsetPercent: number; strike: number;
  baseline: {
    premium: number; premiumPerContract: number; delta: number | null; gamma: number | null;
    vegaPerPp: number; thetaPerDay: number | null;
    breakevenAtExpiry: number; fullPremiumLossPerContract: number;
  };
  scenarios: Array<{ elapsedDays: number; cells: ScenarioCell[] }>;
}
export interface OptionEvidence {
  symbol: string; expirationDate: string; expirationTimestamp: null;
  side: OptionRight; strike: number; description: string; currency: string; exchange: string;
  multiplier: number | null; multiplierNote: string;
  last: number | null; lastTradeTime: string | null; bid: number | null; ask: number | null;
  mid: number | null; midMethod: string; bidAskAsOf: string | null;
  ivAnnual: number | null; ivAsOf: string | null; midpointIv: number | null;
  openInterest: number | null; openInterestAsOf: string | null; volume: number | null; greeks: null;
  executionEligible: false; evidenceStatus: 'incomplete_independent_field_timestamps';
}
export interface IvLabSymbol {
  symbol: string; label: string;
  market: {
    spot: number; currency: 'USD'; observedAt: string; availableAt: string; source: string;
    basis: 'last_trade_reference_may_be_after_hours'; dailyBarLastDate: string;
    dailyBarCloseObservedAt: null; dailyBarTimestampMeaning: string;
    freshness: 'historical_snapshot_not_live'; executionEligible: false;
    coverage: { state: 'observed_sessions_only_calendar_unverified'; observedSessions: number;
      startDate: string; endDate: string; expectedSessions: null; adjustmentPolicy: string;
      sourceSessions: number; validationExcludedPrefixSessions: number; invalidDates: string[]; validationNote: string };
  };
  ivAssumption: {
    annualIv: number; ivPercentilePercent: number | null;
    classification: 'user_scenario_assumption'; observedAt: null; source: string;
    retrievedAt: string; percentileObservedAt: null; percentileLookback: string; units: string;
  };
  technical: { latest: TechnicalPoint; series: TechnicalPoint[]; definitions: Record<string, string>;
    featureVersion: string; predictionModelApplied: false };
  configurations: IvLabConfiguration[];
  optionEvidence: OptionEvidence[];
}
export interface IvLabArtifact {
  schemaVersion: 'leo-iv-lab.v1'; generatedAt: string; inputSha256: string;
  methodology: {
    model: string; modelVersion: string; rateAnnual: number; dividendYieldAnnual: number;
    rateAndDividendSource: string; optionCalendarDaysPerYear: number; realizedVolSessionsPerYear: number;
    assumedContractMultiplier: number; premiumAndPnlUnits: string; vegaUnits: string; thetaUnits: string;
    strikeDefinition: string; pnlPercentDefinition: string; invalidIvPolicy: string; decomposition: string;
    executionEnabled: false; predictionModelPromoted: false; limitations: string[];
  };
  axes: { tenorDays: number[]; rights: OptionRight[]; strikeOffsetPercent: number[];
    elapsedDays: number[]; spotMovePercent: number[]; ivShiftPp: number[] };
  defaults: { symbol: string; tenorDays: number; right: OptionRight; strikeOffsetPercent: number; elapsedDays: number };
  symbols: IvLabSymbol[];
}
