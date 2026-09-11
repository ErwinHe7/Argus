export type Bar = { date: string; close: number; high: number; low: number; sma20: number | null; sma50: number | null; rsi14: number | null };
export type Asset = {
  symbol: string; name: string; source: string; observedAt: string; retrievedAt: string;
  dailyBarLastDate: string; spot: number; iv: number | null; ivPercentile: number | null;
  coverage: Record<string, unknown>; changeBasis?: string;
  latest: { rsi14: number | null; sma20: number | null; sma50: number | null; atr14: number | null; realizedVol20Percent: number | null; priceVsSma20Percent: number | null; changePercent: number | null; high20: number | null; low20: number | null };
  series: Bar[];
};
export type DeskData = { schemaVersion: string; retrievedAt: string; dataMode: string; symbols: Asset[] };
/** Deterministic Python descriptions of completed daily observations. */
export type MarketRead = {
  symbol: string; asOf: string; source: string; sourceRetrievedAt: string;
  trend: 'Uptrend' | 'Downtrend' | 'Mixed' | 'Unavailable';
  momentum: 'Overbought' | 'Oversold' | 'Neutral' | 'Unavailable';
  summary: string; watch: string; basis: string[];
};
export type MarketAnalysis = {
  schemaVersion: string; generatedAt: string; dataMode: string;
  methodology: Record<string, string | boolean>; symbols: MarketRead[];
};
export type JournalRecord = { id: string; kind: 'algo' | 'positions' | 'earnings'; symbol: string; date: string; session: string; thesis: string; source: string; reference: string; status: 'open' | 'closed'; review: string };
