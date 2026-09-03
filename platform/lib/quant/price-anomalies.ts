import { buildOrderFlowReport, type OrderFlowReport } from '@/lib/market-intelligence/order-flow';

export type PriceAnomalyLevel = 'GREEN' | 'LIGHT_YELLOW' | 'YELLOW' | 'ORANGE' | 'RED';
export type PriceAnomalyDirection = 'up' | 'down' | 'mixed';
export type PriceAnomalyProviderStatus = 'ready' | 'missing' | 'adapter_pending' | 'disabled';
export type PriceAnomalyAction = 'NO_TRADE' | 'WATCH' | 'PAPER_REDUCE_RISK' | 'PAPER_HEDGE' | 'PAPER_LONG_WATCH' | 'PAPER_SHORT_WATCH';

export type PriceAnomalyProvider = {
  id: string;
  name: string;
  tier: 'T0' | 'T1' | 'T2';
  status: PriceAnomalyProviderStatus;
  latencyTargetMs: number;
  env: string[];
  role: string;
};

export type PriceAnomalyEventInput = {
  id: string;
  title: string;
  summary: string;
  sourceTier: string;
  confirmationStatus: string;
  severity: number;
  confidence: number;
  affectedAssets: string[];
  publishedAt: string;
  impactAssessment?: {
    bias: 'bullish' | 'bearish' | 'mixed' | 'neutral';
    horizon: 'intraday' | '1-3d' | 'multi-week';
  };
};

export type PriceAnomalyFeature = {
  label: string;
  value: string;
  score: number;
  note: string;
};

export type PriceAnomalyHistoricalAnalog = {
  label: string;
  setup: string;
  observedPattern: string;
  nextChecks: string[];
};

export type ManualExecutionTicket = {
  platform: 'moomoo' | 'ibkr' | 'external';
  mode: 'manual_only' | 'paper_api' | 'live_api_locked';
  ticker: string;
  side: 'BUY' | 'SELL' | 'HEDGE' | 'WATCH';
  orderStyle: 'LIMIT_ONLY' | 'NO_MARKET_ORDER' | 'DEFINED_RISK_OPTIONS_ONLY' | 'WATCH_ONLY';
  trigger: string;
  invalidation: string;
  sizeHint: string;
  checklist: string[];
  warnings: string[];
};

export type PriceAnomalySignal = {
  id: string;
  ticker: string;
  level: PriceAnomalyLevel;
  direction: PriceAnomalyDirection;
  score: number;
  confidence: number;
  provider: OrderFlowReport['provider'] | 'replay';
  mode: 'live' | 'replay' | 'provider_missing';
  spot: number | null;
  previousClose: number | null;
  changePct: number | null;
  benchmarkRelativePct: number | null;
  reason: string;
  likelyCause: string;
  matchedEvents: PriceAnomalyEventInput[];
  features: PriceAnomalyFeature[];
  analogs: PriceAnomalyHistoricalAnalog[];
  execution: {
    action: PriceAnomalyAction;
    mode: 'paper_only' | 'recommendation_only' | 'live_locked';
    rationale: string;
    liveOrderAllowed: boolean;
  };
  manualExecution: ManualExecutionTicket;
  generatedAt: string;
};

export type PriceAnomalyReport = {
  generatedAt: string;
  enabled: boolean;
  mode: 'live' | 'live_plus_replay' | 'provider_missing';
  universe: string[];
  providers: PriceAnomalyProvider[];
  sourceSummary: {
    ready: number;
    missing: number;
    adapterPending: number;
    primaryTapeReady: boolean;
    liveOrderLocked: boolean;
    paperAutomationEnabled: boolean;
  };
  executionPreference: {
    primaryPlatform: 'moomoo' | 'ibkr' | 'external';
    mode: 'manual_first' | 'paper_first' | 'live_api_locked';
    moomooOpenApiConfigured: boolean;
    ibkrConfigured: boolean;
    note: string;
  };
  signals: PriceAnomalySignal[];
  rules: string[];
  disclaimer: string;
};

const DEFAULT_WATCHLIST = ['META', 'NVDA', 'AVGO', 'MU', 'SNDK', 'SMH', 'SOXX', 'QQQ'];
const BENCHMARKS = new Set(['QQQ', 'SMH', 'SOXX', 'SPY']);

export async function buildPriceAnomalyReport({
  universe,
  events = [],
  includeReplay = true,
}: {
  universe?: string[];
  events?: PriceAnomalyEventInput[];
  includeReplay?: boolean;
} = {}): Promise<PriceAnomalyReport> {
  const enabled = process.env.PRICE_ANOMALY_ENABLED !== 'false';
  const providers = getPriceAnomalyProviders();
  const ready = providers.filter((provider) => provider.status === 'ready');
  const universeSymbols = normalizeWatchlist(universe);
  const primaryTapeReady = ready.some((provider) => provider.tier === 'T0' || provider.tier === 'T1');
  const reports = enabled && primaryTapeReady ? await fetchOrderFlowReports(universeSymbols) : [];
  const benchmarkMove = computeBenchmarkMove(reports);
  const liveSignals = reports
    .filter((report) => report.provider !== 'unavailable' && report.provider !== 'yahoo')
    .map((report) => scoreOrderFlowReport(report, benchmarkMove, events))
    .filter((signal) => signal.score >= 20)
    .sort((a, b) => b.score - a.score);

  const replaySignals = includeReplay && liveSignals.length === 0 ? buildReplaySignals(events) : [];
  const mode = liveSignals.length ? 'live' : replaySignals.length ? 'live_plus_replay' : 'provider_missing';

  return {
    generatedAt: new Date().toISOString(),
    enabled,
    mode,
    universe: universeSymbols,
    providers,
    sourceSummary: {
      ready: ready.length,
      missing: providers.filter((provider) => provider.status === 'missing').length,
      adapterPending: providers.filter((provider) => provider.status === 'adapter_pending').length,
      primaryTapeReady,
      liveOrderLocked: process.env.ANOMALY_LIVE_ORDER_ENABLED !== 'true' || process.env.LIVE_EXECUTION_ENABLED !== 'true',
      paperAutomationEnabled: process.env.ANOMALY_AUTO_PAPER_ENABLED === 'true',
    },
    executionPreference: getExecutionPreference(),
    signals: [...liveSignals, ...replaySignals].slice(0, 12),
    rules: [
      'Price/flow anomaly comes first; headlines are used to explain or confirm, not to replace tape.',
      'Nasdaq TotalView / Databento / Polygon / Massive / Moomoo OpenAPI / IBKR can trigger this engine; Yahoo-style delayed data cannot.',
      'If price moves hard before a confirmed headline, mark the cause as unconfirmed and keep checking SEC, company wires, Benzinga/newswire, and macro feeds.',
      'Moomoo manual execution is the default human workflow. Paper automation can be enabled separately. Live broker API orders remain locked unless credentials, risk limits, compliance gates, and user confirmation are present.',
    ],
    disclaimer:
      'Research and risk-control tooling only. This detector surfaces abnormal tape and possible causes; it does not guarantee next-day direction.',
  };
}

export function getPriceAnomalyProviders(): PriceAnomalyProvider[] {
  return [
    {
      id: 'nasdaq-totalview',
      name: 'Nasdaq TotalView / direct depth',
      tier: 'T0',
      status:
        process.env.NASDAQ_TOTALVIEW_ENABLED === 'true' && (process.env.NASDAQ_TOTALVIEW_WS_URL || process.env.NASDAQ_TOTALVIEW_API_KEY)
          ? 'ready'
          : process.env.NASDAQ_TOTALVIEW_ENABLED === 'true'
            ? 'missing'
            : 'disabled',
      latencyTargetMs: 50,
      env: ['NASDAQ_TOTALVIEW_ENABLED', 'NASDAQ_TOTALVIEW_WS_URL', 'NASDAQ_TOTALVIEW_API_KEY'],
      role: 'Best source for Nasdaq order-book imbalance, depth pulls, queue depletion, and premarket pressure.',
    },
    {
      id: 'databento',
      name: 'Databento equities/futures/options',
      tier: 'T1',
      status: process.env.DATABENTO_API_KEY ? 'adapter_pending' : 'missing',
      latencyTargetMs: 100,
      env: ['DATABENTO_API_KEY'],
      role: 'Preferred normalized vendor path for equities, NQ futures, and OPRA when direct exchange feeds are not installed.',
    },
    {
      id: 'polygon-massive',
      name: 'Polygon / Massive realtime tape',
      tier: 'T1',
      status: process.env.POLYGON_API_KEY || process.env.MASSIVE_API_KEY ? 'ready' : 'missing',
      latencyTargetMs: 250,
      env: ['POLYGON_API_KEY', 'MASSIVE_API_KEY'],
      role: 'Executable MVP feed for last trade, NBBO, large prints, and premarket US equity pressure.',
    },
    {
      id: 'moomoo-openapi',
      name: 'Moomoo OpenAPI / OpenD',
      tier: 'T2',
      status:
        process.env.MOOMOO_MARKET_DATA_ENABLED === 'true' && process.env.MOOMOO_OPEND_HOST && process.env.MOOMOO_OPEND_PORT
          ? 'adapter_pending'
          : process.env.MOOMOO_MARKET_DATA_ENABLED === 'true'
            ? 'missing'
            : 'disabled',
      latencyTargetMs: 300,
      env: ['MOOMOO_MARKET_DATA_ENABLED', 'MOOMOO_OPEND_HOST', 'MOOMOO_OPEND_PORT', 'MOOMOO_TRADE_ENABLED'],
      role: 'Your familiar execution screen and optional OpenD quote/trade gateway. Default is manual ticket generation, not live API trading.',
    },
    {
      id: 'ibkr-market-data',
      name: 'IBKR market data',
      tier: 'T2',
      status: process.env.IBKR_MARKET_DATA_ENABLED === 'true' && process.env.IBKR_BASE_URL ? 'ready' : 'missing',
      latencyTargetMs: 250,
      env: ['IBKR_MARKET_DATA_ENABLED', 'IBKR_BASE_URL', 'IBKR_ACCOUNT_ID'],
      role: 'Broker-side quote/account/margin confirmation and execution bridge. Useful truth source, not the only signal feed.',
    },
  ];
}

function getExecutionPreference(): PriceAnomalyReport['executionPreference'] {
  const primaryPlatform = (process.env.EXECUTION_PRIMARY_PLATFORM || 'moomoo').toLowerCase();
  const moomooConfigured = Boolean(process.env.MOOMOO_OPEND_HOST && process.env.MOOMOO_OPEND_PORT);
  const ibkrConfigured = Boolean(process.env.IBKR_BASE_URL && process.env.IBKR_ACCOUNT_ID);
  const liveUnlocked = process.env.ANOMALY_LIVE_ORDER_ENABLED === 'true' && process.env.LIVE_EXECUTION_ENABLED === 'true';
  const paperFirst = process.env.ANOMALY_AUTO_PAPER_ENABLED === 'true';
  return {
    primaryPlatform: primaryPlatform === 'ibkr' ? 'ibkr' : primaryPlatform === 'external' ? 'external' : 'moomoo',
    mode: liveUnlocked ? 'live_api_locked' : paperFirst ? 'paper_first' : 'manual_first',
    moomooOpenApiConfigured: moomooConfigured,
    ibkrConfigured,
    note:
      primaryPlatform === 'ibkr'
        ? 'IBKR is selected as the primary platform, but live API execution still requires the user-confirmed broker route.'
        : 'Moomoo is selected as the primary human execution platform. AXIO7 generates tickets/checklists; you place the order manually in Moomoo.',
  };
}

async function fetchOrderFlowReports(symbols: string[]): Promise<OrderFlowReport[]> {
  const results = await Promise.allSettled(symbols.map((symbol) => buildOrderFlowReport(symbol, { allowRetailFallback: false })));
  return results
    .map((result) => (result.status === 'fulfilled' ? result.value : null))
    .filter((report): report is OrderFlowReport => Boolean(report));
}

function scoreOrderFlowReport(
  report: OrderFlowReport,
  benchmarkMove: number | null,
  events: PriceAnomalyEventInput[]
): PriceAnomalySignal {
  const changePct =
    report.previousClose && report.previousClose > 0 && report.spot > 0 ? ((report.spot - report.previousClose) / report.previousClose) * 100 : null;
  const vwapDistancePct = report.vwap && report.vwap > 0 && report.spot > 0 ? ((report.spot - report.vwap) / report.vwap) * 100 : null;
  const quote = report.quote;
  const midpoint = quote?.midpoint || (quote?.bid && quote?.ask ? (quote.bid + quote.ask) / 2 : null);
  const spreadBps = quote?.spread && midpoint ? (quote.spread / midpoint) * 10_000 : null;
  const depthImbalancePct =
    quote?.bidSize && quote.askSize && quote.bidSize + quote.askSize > 0
      ? ((quote.bidSize - quote.askSize) / (quote.bidSize + quote.askSize)) * 100
      : null;
  const benchmarkRelativePct = changePct !== null && benchmarkMove !== null && !BENCHMARKS.has(report.ticker) ? changePct - benchmarkMove : null;
  const matchedEvents = matchEvents(report.ticker, events);
  const headlineBoost = matchedEvents[0] ? (matchedEvents[0].severity * matchedEvents[0].confidence) / 100 : 0;

  const priceScore = Math.min(45, Math.abs(changePct || 0) * 10 + Math.abs(vwapDistancePct || 0) * 3);
  const relativeScore = Math.min(20, Math.abs(benchmarkRelativePct || 0) * 5);
  const flowScore =
    Math.min(15, report.notable.length * 4) +
    (spreadBps !== null && spreadBps > 25 ? 5 : 0) +
    (depthImbalancePct !== null && Math.abs(depthImbalancePct) > 45 ? 8 : 0) +
    (report.buyPressurePct !== null && (report.buyPressurePct >= 75 || report.buyPressurePct <= 25) ? 6 : 0);
  const newsScore = Math.min(20, headlineBoost / 5);
  const score = clamp(Math.round(priceScore + relativeScore + flowScore + newsScore), 0, 100);
  const direction = inferDirection(changePct, vwapDistancePct, depthImbalancePct, report.buyPressurePct);
  const level = levelForScore(score, matchedEvents);
  const confidence = confidenceFor(report, score, matchedEvents);
  const likelyCause = explainCause(report.ticker, direction, matchedEvents, changePct, benchmarkRelativePct);

  return {
    id: `price-anomaly-${report.ticker}-${report.generatedAt}`,
    ticker: report.ticker,
    level,
    direction,
    score,
    confidence,
    provider: report.provider,
    mode: 'live',
    spot: report.spot || null,
    previousClose: report.previousClose || null,
    changePct,
    benchmarkRelativePct,
    reason: summarizeMove(report.ticker, direction, score, changePct, benchmarkRelativePct),
    likelyCause,
    matchedEvents,
    features: [
      feature('1D / premarket move', pct(changePct), priceScore, 'Raw price displacement versus previous close.'),
      feature('VWAP distance', pct(vwapDistancePct), Math.min(20, Math.abs(vwapDistancePct || 0) * 4), 'Large distance from VWAP can mean chasing or forced flow.'),
      feature('Relative vs QQQ/SMH/SOXX', pct(benchmarkRelativePct), relativeScore, 'Separates single-name shock from broad beta move.'),
      feature('NBBO spread', spreadBps === null ? 'n/a' : `${spreadBps.toFixed(1)} bps`, spreadBps && spreadBps > 25 ? 10 : 0, 'Wide spread means liquidity is thinning.'),
      feature(
        'Depth / tape pressure',
        `${depthImbalancePct === null ? 'n/a' : `${depthImbalancePct.toFixed(0)}% depth`} / ${
          report.buyPressurePct === null ? 'n/a' : `${report.buyPressurePct}% buy prints`
        }`,
        flowScore,
        'Uses quote imbalance, print direction, and large prints.'
      ),
      feature('Headline match', matchedEvents[0]?.title || 'not confirmed', newsScore, 'If absent, this is price-led and cause remains unconfirmed.'),
    ],
    analogs: analogsFor(report.ticker, matchedEvents, direction),
    execution: planExecution(level, direction, matchedEvents),
    manualExecution: buildManualExecutionTicket(report.ticker, direction, level, changePct, benchmarkRelativePct, matchedEvents),
    generatedAt: new Date().toISOString(),
  };
}

function buildReplaySignals(events: PriceAnomalyEventInput[]): PriceAnomalySignal[] {
  const matchedMeta = events.filter((event) => event.affectedAssets.includes('META')).slice(0, 2);
  const now = new Date().toISOString();
  return [
    {
      id: `price-anomaly-replay-meta-${now}`,
      ticker: 'META',
      level: 'ORANGE',
      direction: 'down',
      score: 78,
      confidence: 72,
      provider: 'replay',
      mode: 'replay',
      spot: null,
      previousClose: null,
      changePct: -3.8,
      benchmarkRelativePct: -2.4,
      reason: 'Replay template: issuer trades sharply below QQQ while supply/financing headline risk is active.',
      likelyCause:
        'Likely dilution/supply shock if confirmed by SEC 8-K/S-3/424B5, company wire, or Benzinga/newswire. If no headline appears, treat as price-led unknown and wait for confirmation.',
      matchedEvents: matchedMeta,
      features: [
        feature('Price first', '-3.8%', 38, 'Move is large enough to demand attribution before trading.'),
        feature('Relative beta', '-2.4%', 12, 'Underperforms QQQ, pointing to single-name pressure.'),
        feature('Headline match', matchedMeta[0]?.title || 'financing watch', 16, 'Financing-style events usually pressure issuer first.'),
      ],
      analogs: [
        {
          label: 'Mega-cap equity financing / offering',
          setup: 'Issuer-specific supply or dilution headline while broad beta is weak.',
          observedPattern: 'Issuer often gaps down first; market stabilizes only if proceeds reduce balance-sheet risk or index beta repairs.',
          nextChecks: ['SEC 8-K/S-3/424B5', 'company IR wire', 'QQQ relative reclaim', 'put skew mean reversion'],
        },
      ],
      execution: {
        action: 'PAPER_REDUCE_RISK',
        mode: 'recommendation_only',
        rationale: 'Replay only. No live order can be routed from simulated tape.',
        liveOrderAllowed: false,
      },
      manualExecution: buildManualExecutionTicket('META', 'down', 'ORANGE', -3.8, -2.4, matchedMeta),
      generatedAt: now,
    },
    {
      id: `price-anomaly-replay-semis-${now}`,
      ticker: 'SMH',
      level: 'YELLOW',
      direction: 'mixed',
      score: 62,
      confidence: 65,
      provider: 'replay',
      mode: 'replay',
      spot: null,
      previousClose: null,
      changePct: -1.6,
      benchmarkRelativePct: -0.9,
      reason: 'Replay template: Korea memory stress transmits into US semis, but repair is possible if NQ and SMH reclaim VWAP.',
      likelyCause: 'Global lead-lag contagion from Hynix/Samsung/KRW into MU/AVGO/NVDA/SMH.',
      matchedEvents: [],
      features: [
        feature('Korea lead-lag', 'watch', 22, 'Start with SK Hynix, Samsung, KOSPI/KOSDAQ, and KRW.'),
        feature('US transmission', 'watch', 20, 'Confirm with NQ futures and SMH/SOXX premarket.'),
      ],
      analogs: [
        {
          label: 'Asia semiconductor liquidation into US premarket',
          setup: 'Korea memory names break first, NQ and US semis follow.',
          observedPattern: 'First wave can overshoot. Better short entries come after failed rebound; dip buys need no second-leg liquidation.',
          nextChecks: ['Hynix/Samsung low retest', 'USDKRW', 'NQ overnight VWAP', 'SMH/SOXX put skew'],
        },
      ],
      execution: {
        action: 'WATCH',
        mode: 'recommendation_only',
        rationale: 'Replay only. Wait for live tape confirmation.',
        liveOrderAllowed: false,
      },
      manualExecution: buildManualExecutionTicket('SMH', 'mixed', 'YELLOW', -1.6, -0.9, []),
      generatedAt: now,
    },
  ];
}

function buildManualExecutionTicket(
  ticker: string,
  direction: PriceAnomalyDirection,
  level: PriceAnomalyLevel,
  changePct: number | null,
  benchmarkRelativePct: number | null,
  matchedEvents: PriceAnomalyEventInput[]
): ManualExecutionTicket {
  const platform = (process.env.EXECUTION_PRIMARY_PLATFORM || 'moomoo').toLowerCase() === 'ibkr' ? 'ibkr' : 'moomoo';
  const side: ManualExecutionTicket['side'] =
    level === 'GREEN' || level === 'LIGHT_YELLOW'
      ? 'WATCH'
      : direction === 'up'
        ? 'BUY'
        : direction === 'down'
          ? 'HEDGE'
          : 'WATCH';
  const eventConfirmed = matchedEvents.some((event) => event.sourceTier === 'T0' || event.sourceTier === 'T1');
  const moveText = changePct === null ? 'abnormal tape' : `${changePct > 0 ? '+' : ''}${changePct.toFixed(2)}% move`;
  const relativeText =
    benchmarkRelativePct === null ? 'relative confirmation unavailable' : `${benchmarkRelativePct > 0 ? '+' : ''}${benchmarkRelativePct.toFixed(2)}% vs benchmark basket`;

  return {
    platform,
    mode: process.env.MOOMOO_TRADE_ENABLED === 'true' ? 'live_api_locked' : 'manual_only',
    ticker,
    side,
    orderStyle:
      side === 'HEDGE'
        ? 'DEFINED_RISK_OPTIONS_ONLY'
        : side === 'BUY'
          ? 'LIMIT_ONLY'
          : 'WATCH_ONLY',
    trigger:
      side === 'BUY'
        ? `Only consider if ${ticker} reclaims VWAP/opening range and the cause is not bearish. Current context: ${moveText}, ${relativeText}.`
        : side === 'HEDGE'
          ? `Only hedge/reduce risk after failed reclaim or second-leg breakdown. Current context: ${moveText}, ${relativeText}.`
          : `Watch only until live tape and cause attribution improve. Current context: ${moveText}, ${relativeText}.`,
    invalidation:
      side === 'BUY'
        ? 'Cancel the idea if the event is confirmed bearish, QQQ/SMH make lower lows, or spread/depth worsens.'
        : side === 'HEDGE'
          ? 'Do not chase if IV/spread already expanded and price is far below VWAP; wait for failed bounce or use defined risk.'
          : 'No trade until a clean trigger appears.',
    sizeHint:
      side === 'WATCH'
        ? '0% risk. Observation only.'
        : 'Start tiny. Default max idea risk 0.25%-0.50% account until live slippage, spread, and confirmation quality are measured.',
    checklist: [
      'Confirm ticker, route, buying power, and extended-hours setting in Moomoo before touching the order ticket.',
      eventConfirmed ? 'T0/T1 event matched. Read the original filing/wire before order entry.' : 'No T0/T1 event match yet. Treat cause as unconfirmed.',
      'Compare against QQQ/SMH/SOXX and closest peers. Avoid single-name interpretation if the whole basket is moving.',
      'Use limit orders for shares. For options, prefer defined-risk structures after checking bid/ask and IV.',
      'Write the thesis in one sentence before entry; if you cannot, do not trade.',
    ],
    warnings: [
      'AXIO7 is not sending this to the broker. You are manually deciding and entering any Moomoo order.',
      'Do not use market orders in thin premarket/after-hours tape.',
      'If you are unfamiliar with IBKR, do not switch execution platforms during a live stress event.',
    ],
  };
}

function normalizeWatchlist(universe?: string[]): string[] {
  const fromEnv = parseSymbols(process.env.PRICE_ANOMALY_WATCHLIST);
  const base = fromEnv.length ? fromEnv : DEFAULT_WATCHLIST;
  const allowed = universe?.length ? new Set(universe.map(cleanSymbol)) : null;
  const symbols = base.map(cleanSymbol).filter(Boolean);
  return Array.from(new Set(symbols.filter((symbol) => !allowed || allowed.has(symbol)))).slice(0, 20);
}

function parseSymbols(value?: string): string[] {
  return (value || '')
    .split(/[\s,;]+/)
    .map(cleanSymbol)
    .filter(Boolean);
}

function cleanSymbol(symbol: string): string {
  return symbol.replace(/^\$/, '').trim().toUpperCase();
}

function computeBenchmarkMove(reports: OrderFlowReport[]): number | null {
  const moves = reports
    .filter((report) => BENCHMARKS.has(report.ticker) && report.previousClose && report.spot > 0)
    .map((report) => ((report.spot - report.previousClose!) / report.previousClose!) * 100)
    .filter(Number.isFinite);
  if (!moves.length) return null;
  return moves.reduce((sum, move) => sum + move, 0) / moves.length;
}

function matchEvents(ticker: string, events: PriceAnomalyEventInput[]): PriceAnomalyEventInput[] {
  return events
    .filter((event) => event.affectedAssets.includes(ticker) || event.title.toUpperCase().includes(ticker))
    .sort((a, b) => b.severity * b.confidence - a.severity * a.confidence)
    .slice(0, 3);
}

function inferDirection(
  changePct: number | null,
  vwapDistancePct: number | null,
  depthImbalancePct: number | null,
  buyPressurePct: number | null
): PriceAnomalyDirection {
  const votes = [changePct, vwapDistancePct, depthImbalancePct ? depthImbalancePct / 25 : null, buyPressurePct === null ? null : buyPressurePct - 50]
    .filter((value): value is number => value !== null && Number.isFinite(value))
    .reduce((sum, value) => sum + Math.sign(value), 0);
  if (votes >= 2) return 'up';
  if (votes <= -2) return 'down';
  return 'mixed';
}

function levelForScore(score: number, matchedEvents: PriceAnomalyEventInput[]): PriceAnomalyLevel {
  const confirmed = matchedEvents.some((event) => event.sourceTier === 'T0' || event.sourceTier === 'T1');
  if (score >= 85 && confirmed) return 'RED';
  if (score >= 70) return 'ORANGE';
  if (score >= 50) return 'YELLOW';
  if (score >= 30) return 'LIGHT_YELLOW';
  return 'GREEN';
}

function confidenceFor(report: OrderFlowReport, score: number, matchedEvents: PriceAnomalyEventInput[]): number {
  const providerBoost = report.provider === 'ibkr' ? 18 : report.provider === 'polygon' ? 20 : 0;
  const headlineBoost = matchedEvents.some((event) => event.sourceTier === 'T0' || event.sourceTier === 'T1') ? 20 : matchedEvents.length ? 10 : 0;
  return clamp(Math.round(35 + providerBoost + headlineBoost + score * 0.25), 0, 95);
}

function explainCause(
  ticker: string,
  direction: PriceAnomalyDirection,
  matchedEvents: PriceAnomalyEventInput[],
  changePct: number | null,
  benchmarkRelativePct: number | null
): string {
  if (matchedEvents.length) {
    const top = matchedEvents[0];
    const bias = top.impactAssessment ? `${top.impactAssessment.bias}/${top.impactAssessment.horizon}` : 'event-linked';
    return `${top.sourceTier} ${top.confirmationStatus}: ${top.title}. Agent read: ${bias}.`;
  }

  const relative = benchmarkRelativePct !== null && Math.abs(benchmarkRelativePct) >= 1.2 ? 'single-name relative move' : 'broad beta may explain part of it';
  const move = changePct === null ? 'abnormal tape' : `${ticker} ${changePct > 0 ? 'up' : 'down'} ${Math.abs(changePct).toFixed(2)}%`;
  return `${move}; cause not confirmed yet. Treat as price-led ${direction} signal, check SEC/company wires/newswire, options skew, and peer/index confirmation. ${relative}.`;
}

function summarizeMove(
  ticker: string,
  direction: PriceAnomalyDirection,
  score: number,
  changePct: number | null,
  benchmarkRelativePct: number | null
): string {
  const move = changePct === null ? 'no previous-close comparison' : `${changePct > 0 ? '+' : ''}${changePct.toFixed(2)}%`;
  const rel = benchmarkRelativePct === null ? 'relative n/a' : `${benchmarkRelativePct > 0 ? '+' : ''}${benchmarkRelativePct.toFixed(2)}% vs benchmark basket`;
  return `${ticker} ${direction} anomaly score ${score}: ${move}, ${rel}.`;
}

function analogsFor(
  ticker: string,
  matchedEvents: PriceAnomalyEventInput[],
  direction: PriceAnomalyDirection
): PriceAnomalyHistoricalAnalog[] {
  const title = matchedEvents.map((event) => `${event.title} ${event.summary}`).join(' ').toLowerCase();
  if (/offering|financing|convertible|s-3|424b5|dilution|equity/.test(title)) {
    return [
      {
        label: 'Equity financing / shelf / offering shock',
        setup: 'Issuer-specific supply hits while market makers widen spreads and options skew reprices.',
        observedPattern: 'First reaction is often bearish for issuer. Index impact depends on size, liquidity, and whether proceeds reduce risk.',
        nextChecks: ['SEC filing terms', 'use of proceeds', 'relative reclaim vs QQQ', 'put skew after first 30-60 minutes'],
      },
    ];
  }
  if (['MU', 'SNDK', 'AVGO', 'NVDA', 'SMH', 'SOXX'].includes(ticker)) {
    return [
      {
        label: 'Semiconductor lead-lag stress',
        setup: 'Asia memory or AI hardware pressure transmits into US semis and NQ.',
        observedPattern: 'If Korea repairs and NQ reclaims VWAP, first selloff can fade. If Hynix/Samsung make second lows, US semis often stay heavy.',
        nextChecks: ['SK Hynix/Samsung close', 'USDKRW', 'NQ VWAP', 'SMH/SOXX options skew'],
      },
    ];
  }
  return [
    {
      label: `Price-led ${direction} tape with no confirmed headline`,
      setup: 'Tape moves before public attribution is visible.',
      observedPattern: 'Professionals first ask whether this is broad beta, single-name news leakage, forced selling, or options/dealer flow.',
      nextChecks: ['SEC/company wire', 'Benzinga/newswire', 'peer relative move', 'NBBO/depth stability', 'options IV/skew'],
    },
  ];
}

function planExecution(
  level: PriceAnomalyLevel,
  direction: PriceAnomalyDirection,
  matchedEvents: PriceAnomalyEventInput[]
): PriceAnomalySignal['execution'] {
  const liveUnlocked = process.env.ANOMALY_LIVE_ORDER_ENABLED === 'true' && process.env.LIVE_EXECUTION_ENABLED === 'true';
  if (!liveUnlocked) {
    const action: PriceAnomalyAction =
      level === 'RED' || level === 'ORANGE'
        ? direction === 'down'
          ? 'PAPER_REDUCE_RISK'
          : 'PAPER_LONG_WATCH'
        : level === 'YELLOW'
          ? 'WATCH'
          : 'NO_TRADE';
    return {
      action,
      mode: process.env.ANOMALY_AUTO_PAPER_ENABLED === 'true' ? 'paper_only' : 'recommendation_only',
      rationale: matchedEvents.length
        ? 'Tape has event attribution, but live execution is locked behind explicit confirmation.'
        : 'Price moved before confirmed cause; paper or watch only until attribution improves.',
      liveOrderAllowed: false,
    };
  }

  return {
    action: direction === 'down' ? 'PAPER_HEDGE' : 'PAPER_LONG_WATCH',
    mode: 'live_locked',
    rationale: 'Deployment env is live-capable, but this detector still routes through user-confirmed broker execution.',
    liveOrderAllowed: false,
  };
}

function feature(label: string, value: string, score: number, note: string): PriceAnomalyFeature {
  return { label, value, score: clamp(Math.round(score), 0, 100), note };
}

function pct(value: number | null): string {
  if (value === null || !Number.isFinite(value)) return 'n/a';
  return `${value > 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
