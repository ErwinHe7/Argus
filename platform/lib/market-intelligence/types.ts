export type MarketSourceKind =
  | 'sec_edgar'
  | 'reuters_lseg'
  | 'news_api'
  | 'x_api'
  | 'truth_social'
  | 'market_tape'
  | 'options_flow'
  | 'earnings'
  | 'polygon'
  | 'reddit'
  | 'manual'
  | 'demo';

export type MarketSourceAccess = 'public' | 'authorized' | 'vendor' | 'demo';

export type MarketSentiment = 'bullish' | 'bearish' | 'neutral' | 'mixed';

export type MarketVerification = 'official' | 'reported' | 'social' | 'rumor' | 'market_data' | 'demo';

export type MarketHorizon = 'intraday' | 'swing' | 'long_term';

export type StrategyMode = 'paper' | 'live_signal';

export type SignalAction = 'WATCH' | 'RISK_OFF' | 'PAPER_LONG' | 'PAPER_SHORT' | 'NO_TRADE';

export type SourceStatus = {
  id: string;
  name: string;
  kind: MarketSourceKind;
  access: MarketSourceAccess;
  enabled: boolean;
  latencyTargetMs: number;
  coverage: string;
  setup: string;
  productionReady: boolean;
};

export type InfluencerMonitor = {
  id: string;
  displayName: string;
  xHandle?: string;
  truthHandle?: string;
  weight: number;
  enabled: boolean;
  notes: string;
};

export type MarketEvidence = {
  label: string;
  value: string;
  url?: string;
};

export type MarketEvent = {
  id: string;
  title: string;
  summary: string;
  sourceName: string;
  sourceKind: MarketSourceKind;
  sourceAccess: MarketSourceAccess;
  url?: string;
  publishedAt: string;
  /** First instant the strategy could legally and technically observe it. */
  availableAt?: string;
  /** Local ingestion timestamp; never substitutes for historical availability. */
  receivedAt?: string;
  sourceRecordId?: string;
  revisionId?: string;
  supersedesRevisionId?: string;
  payloadSha256?: string;
  availabilityPrecision?: 'exact_timestamp' | 'conservative_date_close' | 'ingestion_time_only';
  tickers: string[];
  sentiment: MarketSentiment;
  confidence: number;
  materiality: number;
  verification: MarketVerification;
  influencer?: string;
  marketMoveBps?: number;
  riskFlags: string[];
  evidence: MarketEvidence[];
};

export type StrategySignal = {
  id: string;
  action: SignalAction;
  ticker: string;
  score: number;
  confidence: number;
  horizon: MarketHorizon;
  mode: StrategyMode;
  thesis: string;
  invalidation: string;
  sourceEventIds: string[];
  riskFlags: string[];
  generatedAt: string;
};

export type ComplianceAssessment = {
  allowed: boolean;
  severity: 'clear' | 'caution' | 'blocked';
  reasons: string[];
  guardrails: string[];
};

export type MarketAgentFinding = {
  id: string;
  name: string;
  role: string;
  status: 'pass' | 'watch' | 'blocked';
  summary: string;
  bullets: string[];
};

export type MarketDecisionFrame = {
  stance: 'Monitor' | 'Investigate' | 'Stand down';
  confidence: number;
  rationale: string[];
  nextChecks: string[];
};

export type MarketResearchRequest = {
  query: string;
  watchlist: string[];
  horizon: MarketHorizon;
  mode?: StrategyMode;
};

export type MarketResearchReport = {
  generatedAt: string;
  query: string;
  watchlist: string[];
  horizon: MarketHorizon;
  mode: StrategyMode;
  compliance: ComplianceAssessment;
  brief: string;
  decisionFrame: MarketDecisionFrame;
  agents: MarketAgentFinding[];
  events: MarketEvent[];
  signals: StrategySignal[];
  sources: SourceStatus[];
  influencers: InfluencerMonitor[];
  audit: string[];
  disclaimer: string;
};
