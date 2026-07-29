import { checkIbkrHealth } from '@/lib/market-intelligence/ibkr-client-portal';
import { buildPriceAnomalyReport, type PriceAnomalyReport } from '@/lib/quant/price-anomalies';

export type SourceTier = 'T0' | 'T1' | 'T2' | 'T3' | 'T4';

export type SignalCategory =
  | 'macro'
  | 'filing'
  | 'company_event'
  | 'market_tape'
  | 'options'
  | 'leverage'
  | 'global_lead_lag'
  | 'liquidity'
  | 'news'
  | 'provider_health';

export type SignalDirection = 'risk_on' | 'risk_off' | 'mixed' | 'neutral';

export type ConfirmationStatus =
  | 'official_confirmed'
  | 'reported_not_confirmed'
  | 'market_confirmed'
  | 'rumor_unconfirmed'
  | 'provider_missing'
  | 'replay';

export type AlertLevel = 'GREEN' | 'LIGHT_YELLOW' | 'YELLOW' | 'ORANGE' | 'RED';

export type ProfessionalProvider = {
  id: string;
  name: string;
  tier: SourceTier;
  category: SignalCategory;
  enabled: boolean;
  configured: boolean;
  latencyTargetMs: number;
  role: string;
  env: string[];
  setup: string;
  whyItMatters: string;
  status: 'ready' | 'missing' | 'optional' | 'disabled';
};

export type GlobalSignalEvidence = {
  label: string;
  value: string;
  url?: string;
};

export type HistoricalImpactAnalog = {
  label: string;
  setup: string;
  usualMarketImpact: string;
  watchNext: string[];
  confidence: number;
};

export type SignalImpactAssessment = {
  bias: 'bullish' | 'bearish' | 'mixed' | 'neutral';
  horizon: 'intraday' | '1-3d' | 'multi-week';
  affectedAssets: string[];
  reasoning: string[];
  historicalAnalogs: HistoricalImpactAnalog[];
};

export type GlobalSignalEvent = {
  id: string;
  title: string;
  summary: string;
  category: SignalCategory;
  eventType: string;
  sourceId: string;
  sourceName: string;
  sourceTier: SourceTier;
  confirmationStatus: ConfirmationStatus;
  publishedAt: string;
  receivedAt: string;
  latencyMs: number | null;
  affectedAssets: string[];
  direction: SignalDirection;
  severity: number;
  confidence: number;
  canEscalateRed: boolean;
  transmission: string[];
  evidence: GlobalSignalEvidence[];
  impactAssessment?: SignalImpactAssessment;
};

export type SignalScoreCard = {
  macroHawkScore: number;
  leverageUnwindScore: number;
  globalContagionScore: number;
  megaCapShockScore: number;
  optionsStressScore: number;
  liquidityStressScore: number;
  newsVelocityScore: number;
  fragilityScore: number;
  triggerScore: number;
  marketRiskScore: number;
  level: AlertLevel;
  regime: string;
  action: string;
};

export type RegionalWatchItem = {
  id: string;
  label: string;
  market: 'Korea' | 'US premarket' | 'FX' | 'Options';
  requiredSourceIds: string[];
  sourceStatus: 'ready' | 'missing';
  whatToWatch: string;
  riskOffTrigger: string;
  riskOnRepair: string;
  affectedAssets: string[];
  tradingRead: string;
};

export type TacticalPlaybookRule = {
  id: string;
  side: 'dip_buy' | 'short' | 'neutral';
  title: string;
  trigger: string;
  confirmation: string[];
  avoid: string[];
  structures: string[];
};

export type AlertDeliveryConfig = {
  enabled: boolean;
  minLevel: AlertLevel;
  minScore: number;
  cooldownMinutes: number;
  telegramConfigured: boolean;
  webhookConfigured: boolean;
  redisCooldownConfigured: boolean;
  cronPath: string;
  deliveryTargets: string[];
  missingEnv: string[];
};

export type PublicSignalSource = {
  id: string;
  name: string;
  tier: SourceTier;
  kind: 'official_api' | 'official_rss' | 'official_site' | 'company_ir' | 'news_api' | 'aggregator';
  active: boolean;
  configured: boolean;
  url: string;
  env: string[];
  role: string;
  marketUse: string;
  confirmationRole: string;
};

export type GlobalSignalsReport = {
  generatedAt: string;
  mode: 'live' | 'live_plus_replay';
  universe: string[];
  sources: ProfessionalProvider[];
  publicSources: PublicSignalSource[];
  sourceSummary: {
    total: number;
    ready: number;
    missingCritical: number;
    t0Ready: number;
    t1Ready: number;
    t2Ready: number;
  };
  activeEvents: GlobalSignalEvent[];
  replayEvents: GlobalSignalEvent[];
  scores: SignalScoreCard;
  asiaSemiTape: RegionalWatchItem[];
  priceAnomalyReport: PriceAnomalyReport;
  tacticalPlaybook: TacticalPlaybookRule[];
  alertDelivery: AlertDeliveryConfig;
  rules: string[];
  providerWarnings: string[];
  disclaimer: string;
};

const SEC_USER_AGENT =
  process.env.SEC_USER_AGENT ||
  process.env.MARKET_SEC_USER_AGENT ||
  'AXIO7 Global Signal Radar contact@axio7.com';

const CORE_UNIVERSE = [
  'SPY',
  'QQQ',
  'IWM',
  'SOXX',
  'SMH',
  'SNDK',
  'NVDA',
  'AVGO',
  'MU',
  'AMD',
  'MRVL',
  'ARM',
  'META',
  'GOOGL',
  'MSFT',
  'AMZN',
  'ORCL',
  'TSLA',
  'AAPL',
  'KRE',
  'BTC',
  'ETH',
  'NQ',
  'ES',
  'US2Y',
  'US10Y',
  'DXY',
  'VIX',
  'MOVE',
  'SKHYNIX',
  'SAMSUNG',
  'KOSPI',
  'KOSDAQ',
  'KRW',
  'USDKRW',
  'USDJPY',
];

const KNOWN_CIKS: Record<string, string> = {
  AAPL: '0000320193',
  AMD: '0000002488',
  AMZN: '0001018724',
  ARM: '0001973239',
  AVGO: '0001730168',
  GOOGL: '0001652044',
  META: '0001326801',
  MRVL: '0001835632',
  MSFT: '0000789019',
  MU: '0000723125',
  NVDA: '0001045810',
  ORCL: '0001341439',
  TSLA: '0001318605',
};

const MATERIAL_FORMS = new Set(['3', '4', '5', '8-K', 'S-1', 'S-1/A', 'S-3', '424B5', 'FWP', 'SC 13D', 'SC 13G']);

type SecSubmission = {
  name?: string;
  filings?: {
    recent?: {
      accessionNumber?: string[];
      filingDate?: string[];
      reportDate?: string[];
      acceptanceDateTime?: string[];
      form?: string[];
      primaryDocument?: string[];
      primaryDocDescription?: string[];
    };
  };
};

type BenzingaNewsResponse = Array<{
  id?: number | string;
  title?: string;
  teaser?: string;
  body?: string;
  url?: string;
  created?: string;
  updated?: string;
  stocks?: Array<{ name?: string }>;
  channels?: Array<{ name?: string }>;
}>;

type RssItem = {
  title: string;
  summary: string;
  url?: string;
  publishedAt: string;
};

type FederalRegisterResponse = {
  results?: Array<{
    document_number?: string;
    title?: string;
    abstract?: string;
    publication_date?: string;
    html_url?: string;
    type?: string;
    agencies?: Array<{ name?: string }>;
  }>;
};

type NytArticleSearchResponse = {
  response?: {
    docs?: Array<{
      web_url?: string;
      abstract?: string;
      snippet?: string;
      lead_paragraph?: string;
      pub_date?: string;
      source?: string;
      news_desk?: string;
      headline?: { main?: string };
      keywords?: Array<{ value?: string }>;
    }>;
  };
};

export async function buildGlobalSignalsReport({
  includeReplay = true,
  universe = CORE_UNIVERSE,
}: {
  includeReplay?: boolean;
  universe?: string[];
} = {}): Promise<GlobalSignalsReport> {
  const cleanUniverse = normalizeUniverse(universe);
  const sources = await getProfessionalSignalProviders();
  const publicSources = getPublicSignalSources();
  const providerWarnings = buildProviderWarnings(sources);
  const [secEvents, benzingaEvents, publicEvents] = await Promise.all([
    fetchSecSignalEvents(cleanUniverse).catch((err) => providerFailure('sec-edgar-official', err)),
    fetchBenzingaSignalEvents(cleanUniverse).catch((err) => providerFailure('benzinga-news-api', err)),
    fetchPublicSignalEvents(cleanUniverse).catch((err) => providerFailure('public-signal-mesh', err)),
  ]);

  const activeEvents = [...secEvents, ...benzingaEvents, ...publicEvents]
    .map(withImpactAssessment)
    .sort((a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime())
    .slice(0, 120);
  const replayEvents = includeReplay ? buildReplayEvents().map(withImpactAssessment) : [];
  const scores = scoreGlobalSignals(activeEvents);
  const ready = sources.filter((source) => source.status === 'ready');
  const asiaSemiTape = buildAsiaSemiTape(sources);
  const priceAnomalyReport = await buildPriceAnomalyReport({
    universe: cleanUniverse,
    events: includeReplay ? [...activeEvents, ...replayEvents] : activeEvents,
    includeReplay,
  });

  return {
    generatedAt: new Date().toISOString(),
    mode: includeReplay ? 'live_plus_replay' : 'live',
    universe: cleanUniverse,
    sources,
    publicSources,
    sourceSummary: {
      total: sources.length,
      ready: ready.length,
      missingCritical: sources.filter((source) => source.status === 'missing' && (source.tier === 'T0' || source.tier === 'T1')).length,
      t0Ready: ready.filter((source) => source.tier === 'T0').length,
      t1Ready: ready.filter((source) => source.tier === 'T1').length,
      t2Ready: ready.filter((source) => source.tier === 'T2').length,
    },
    activeEvents,
    replayEvents,
    scores,
    asiaSemiTape,
    priceAnomalyReport,
    tacticalPlaybook: buildTacticalPlaybook(),
    alertDelivery: getAlertDeliveryConfig(),
    rules: [
      'T3/T4 sources cannot trigger RED alerts by themselves.',
      'RED requires T0/T1 confirmation or market-confirmed T2 price stress plus another independent source.',
      'Rumor headlines must be marked reported_not_confirmed until an official filing, company wire, or first-tier newswire confirms them.',
      'No delayed retail data is used as the primary source for intraday alerts.',
      'This system emits risk actions and scenario probabilities, not guaranteed price predictions.',
    ],
    providerWarnings,
    disclaimer:
      'Research and risk-control tooling only. It is not investment advice and does not execute trades. Professional feeds require proper licenses and exchange entitlements.',
  };
}

export async function getProfessionalSignalProviders(): Promise<ProfessionalProvider[]> {
  const ibkr = await checkIbkrHealth().catch((err) => ({
    configured: Boolean(process.env.IBKR_BASE_URL),
    enabled: false,
    ok: false,
    reason: err instanceof Error ? err.message : 'IBKR health check failed',
  }));

  return [
    provider({
      id: 'sec-edgar-official',
      name: 'SEC EDGAR official polling',
      tier: 'T0',
      category: 'filing',
      enabled: true,
      configured: true,
      latencyTargetMs: 1500,
      role: 'Official first-party filings: Form 4, 8-K, S-1, S-3, 424B5.',
      env: ['SEC_USER_AGENT'],
      setup: 'Set SEC_USER_AGENT / MARKET_SEC_USER_AGENT for compliant SEC access.',
      whyItMatters: 'Closest legal first-hand source for insider transactions, offerings, and material issuer disclosures.',
    }),
    provider({
      id: 'sec-api-stream',
      name: 'sec-api.io Stream API',
      tier: 'T0',
      category: 'filing',
      enabled: Boolean(process.env.SEC_API_KEY),
      configured: Boolean(process.env.SEC_API_KEY),
      latencyTargetMs: 500,
      role: 'Streaming EDGAR filings with websocket/webhook style ingest.',
      env: ['SEC_API_KEY'],
      setup: 'Add SEC_API_KEY and wire websocket ingestion to cron/queue.',
      whyItMatters: 'Reduces filing detection latency versus polling.',
    }),
    provider({
      id: 'company-wires',
      name: 'Company wire APIs',
      tier: 'T0',
      category: 'company_event',
      enabled: Boolean(process.env.BUSINESSWIRE_API_KEY || process.env.PRNEWSWIRE_API_KEY || process.env.GLOBENEWSWIRE_API_KEY),
      configured: Boolean(process.env.BUSINESSWIRE_API_KEY || process.env.PRNEWSWIRE_API_KEY || process.env.GLOBENEWSWIRE_API_KEY),
      latencyTargetMs: 800,
      role: 'BusinessWire / PRNewswire / GlobeNewswire first-party company releases.',
      env: ['BUSINESSWIRE_API_KEY', 'PRNEWSWIRE_API_KEY', 'GLOBENEWSWIRE_API_KEY'],
      setup: 'Configure at least one licensed company-wire API key.',
      whyItMatters: 'Captures official earnings, offerings, guidance, and M&A releases before secondary articles rewrite them.',
    }),
    provider({
      id: 'nasdaq-totalview',
      name: 'Nasdaq TotalView / exchange direct depth',
      tier: 'T0',
      category: 'market_tape',
      enabled: Boolean(process.env.NASDAQ_TOTALVIEW_API_KEY || process.env.NASDAQ_TOTALVIEW_ENABLED === 'true'),
      configured: Boolean(process.env.NASDAQ_TOTALVIEW_API_KEY || process.env.NASDAQ_TOTALVIEW_ENABLED === 'true'),
      latencyTargetMs: 50,
      role: 'Exchange-level order book depth for Nasdaq names.',
      env: ['NASDAQ_TOTALVIEW_API_KEY', 'NASDAQ_TOTALVIEW_ENABLED'],
      setup: 'Set exchange direct-feed entitlement and adapter endpoint.',
      whyItMatters: 'Lets the radar detect premarket/regular-session pressure before candle aggregates lag.',
    }),
    provider({
      id: 'opra-options-feed',
      name: 'OPRA options feed via vendor',
      tier: 'T0',
      category: 'options',
      enabled: Boolean(process.env.OPRA_VENDOR || process.env.INTRINIO_API_KEY || process.env.CBOE_LIVEVOL_API_KEY || process.env.DATABENTO_API_KEY),
      configured: Boolean(process.env.OPRA_VENDOR || process.env.INTRINIO_API_KEY || process.env.CBOE_LIVEVOL_API_KEY || process.env.DATABENTO_API_KEY),
      latencyTargetMs: 100,
      role: 'US listed options trades/quotes, sweeps, 0DTE, IV/skew inputs.',
      env: ['OPRA_VENDOR', 'INTRINIO_API_KEY', 'CBOE_LIVEVOL_API_KEY', 'DATABENTO_API_KEY'],
      setup: 'Use Intrinio, Cboe DataShop/LiveVol, Databento, or another OPRA-entitled vendor.',
      whyItMatters: 'Options stress, dealer gamma, put/call, and 0DTE flow cannot be trusted from delayed retail pages.',
    }),
    provider({
      id: 'benzinga-news-api',
      name: 'Benzinga News API',
      tier: 'T1',
      category: 'news',
      enabled: Boolean(process.env.BENZINGA_API_KEY),
      configured: Boolean(process.env.BENZINGA_API_KEY),
      latencyTargetMs: 900,
      role: 'Realtime ticker-tagged headlines and why-is-it-moving style events.',
      env: ['BENZINGA_API_KEY'],
      setup: 'Set BENZINGA_API_KEY. Optional BENZINGA_NEWS_CHANNELS / BENZINGA_NEWS_IMPORTANCE.',
      whyItMatters: 'Fast vendor news layer for financing rumors, analyst moves, halts, guidance, and breaking company headlines.',
    }),
    provider({
      id: 'databento',
      name: 'Databento live market data',
      tier: 'T1',
      category: 'market_tape',
      enabled: Boolean(process.env.DATABENTO_API_KEY),
      configured: Boolean(process.env.DATABENTO_API_KEY),
      latencyTargetMs: 100,
      role: 'Realtime equities, futures, OPRA, and normalized market data depending on entitlements.',
      env: ['DATABENTO_API_KEY'],
      setup: 'Set DATABENTO_API_KEY and dataset symbols for equities/futures/options.',
      whyItMatters: 'Professional normalized feed for cross-asset lead-lag and volatility confirmation.',
    }),
    provider({
      id: 'korea-market-feed',
      name: 'KRX / Korea realtime market feed',
      tier: 'T1',
      category: 'global_lead_lag',
      enabled: Boolean(
        process.env.KRX_API_KEY ||
          process.env.KOREA_MARKET_FEED_URL ||
          process.env.IBKR_KOREA_MARKET_DATA_ENABLED === 'true'
      ),
      configured: Boolean(
        process.env.KRX_API_KEY ||
          process.env.KOREA_MARKET_FEED_URL ||
          process.env.IBKR_KOREA_MARKET_DATA_ENABLED === 'true'
      ),
      latencyTargetMs: 500,
      role: 'SK Hynix, Samsung, KOSPI/KOSDAQ, and Korea semiconductor lead-lag tape.',
      env: ['KRX_API_KEY', 'KOREA_MARKET_FEED_URL', 'IBKR_KOREA_MARKET_DATA_ENABLED'],
      setup: 'Use a licensed KRX-capable vendor endpoint, or IBKR Korea market-data entitlement for broker-side confirmation.',
      whyItMatters: 'Korea memory names can lead MU/SMH/SOXX/NQ before US premarket fully prices the stress.',
    }),
    provider({
      id: 'cme-nq-futures',
      name: 'CME Nasdaq futures live feed',
      tier: 'T1',
      category: 'global_lead_lag',
      enabled: Boolean(process.env.CME_FUTURES_FEED_URL || process.env.DATABENTO_API_KEY || process.env.IBKR_MARKET_DATA_ENABLED === 'true'),
      configured: Boolean(process.env.CME_FUTURES_FEED_URL || process.env.DATABENTO_API_KEY || process.env.IBKR_MARKET_DATA_ENABLED === 'true'),
      latencyTargetMs: 100,
      role: 'NQ futures confirmation for Korea-to-US semiconductor contagion.',
      env: ['CME_FUTURES_FEED_URL', 'DATABENTO_API_KEY', 'IBKR_MARKET_DATA_ENABLED'],
      setup: 'Use Databento CME futures entitlement, CME direct/authorized vendor, or IBKR as confirmation.',
      whyItMatters: 'NQ confirms whether Asia semiconductor stress is becoming broad US duration/high-beta pressure.',
    }),
    provider({
      id: 'semi-premarket-feed',
      name: 'US semiconductor premarket feed',
      tier: 'T1',
      category: 'market_tape',
      enabled: Boolean(
        process.env.NASDAQ_TOTALVIEW_API_KEY ||
          process.env.DATABENTO_API_KEY ||
          process.env.POLYGON_API_KEY ||
          process.env.MASSIVE_API_KEY ||
          process.env.IBKR_MARKET_DATA_ENABLED === 'true'
      ),
      configured: Boolean(
        process.env.NASDAQ_TOTALVIEW_API_KEY ||
          process.env.DATABENTO_API_KEY ||
          process.env.POLYGON_API_KEY ||
          process.env.MASSIVE_API_KEY ||
          process.env.IBKR_MARKET_DATA_ENABLED === 'true'
      ),
      latencyTargetMs: 150,
      role: 'Premarket MU/SNDK/AVGO/SMH/SOXX/NVDA tape confirmation.',
      env: ['NASDAQ_TOTALVIEW_API_KEY', 'DATABENTO_API_KEY', 'POLYGON_API_KEY', 'MASSIVE_API_KEY', 'IBKR_MARKET_DATA_ENABLED'],
      setup: 'Prefer exchange/direct or Databento. Broker quotes are useful as a second truth source.',
      whyItMatters: 'US premarket confirms whether the Korea memory signal is spreading or being repaired.',
    }),
    provider({
      id: 'polygon-massive',
      name: 'Polygon / Massive realtime market data',
      tier: 'T1',
      category: 'market_tape',
      enabled: Boolean(process.env.POLYGON_API_KEY || process.env.MASSIVE_API_KEY),
      configured: Boolean(process.env.POLYGON_API_KEY || process.env.MASSIVE_API_KEY),
      latencyTargetMs: 250,
      role: 'Realtime equities, options, FX, crypto depending on plan.',
      env: ['POLYGON_API_KEY', 'MASSIVE_API_KEY'],
      setup: 'Set POLYGON_API_KEY or MASSIVE_API_KEY and use websocket adapter.',
      whyItMatters: 'Primary liquid US tape feed if exchange direct feeds are not yet installed.',
    }),
    provider({
      id: 'trading-economics',
      name: 'Trading Economics / Econoday macro calendar',
      tier: 'T1',
      category: 'macro',
      enabled: Boolean(process.env.TRADING_ECONOMICS_KEY || process.env.ECONODAY_API_KEY),
      configured: Boolean(process.env.TRADING_ECONOMICS_KEY || process.env.ECONODAY_API_KEY),
      latencyTargetMs: 1000,
      role: 'Macro actual/consensus/prior for NFP, CPI, PPI, FOMC, ISM, claims.',
      env: ['TRADING_ECONOMICS_KEY', 'ECONODAY_API_KEY'],
      setup: 'Set a licensed macro calendar feed with consensus and actual values.',
      whyItMatters: 'Macro surprise scoring needs consensus and actual, not just the official release value.',
    }),
    provider({
      id: 'coinglass-liquidations',
      name: 'Coinglass + exchange crypto websockets',
      tier: 'T1',
      category: 'leverage',
      enabled: Boolean(process.env.COINGLASS_API_KEY || process.env.CRYPTO_EXCHANGE_WS_ENABLED === 'true'),
      configured: Boolean(process.env.COINGLASS_API_KEY || process.env.CRYPTO_EXCHANGE_WS_ENABLED === 'true'),
      latencyTargetMs: 1000,
      role: 'Crypto liquidation, funding, open interest, and forced-deleveraging proxy.',
      env: ['COINGLASS_API_KEY', 'CRYPTO_EXCHANGE_WS_ENABLED'],
      setup: 'Set COINGLASS_API_KEY and/or Binance/Bybit/OKX websocket adapters.',
      whyItMatters: 'Crypto often exposes leverage stress before high-beta equities fully reprice.',
    }),
    provider({
      id: 'lseg-reuters-dowjones',
      name: 'Reuters / Dow Jones / Bloomberg style newswire',
      tier: 'T1',
      category: 'news',
      enabled: Boolean(process.env.LSEG_CLIENT_ID || process.env.DOWJONES_API_KEY || process.env.BLOOMBERG_API_KEY),
      configured: Boolean(process.env.LSEG_CLIENT_ID || process.env.DOWJONES_API_KEY || process.env.BLOOMBERG_API_KEY),
      latencyTargetMs: 800,
      role: 'Top-tier market-moving newswire confirmation.',
      env: ['LSEG_CLIENT_ID', 'LSEG_CLIENT_SECRET', 'DOWJONES_API_KEY', 'BLOOMBERG_API_KEY'],
      setup: 'Configure licensed terminal/data-platform API credentials.',
      whyItMatters: 'High-quality confirmation source for rumor-vs-confirmed distinction.',
    }),
    provider({
      id: 'ibkr-client-portal',
      name: 'IBKR Client Portal / TWS API',
      tier: 'T2',
      category: 'market_tape',
      enabled: Boolean((ibkr as any).enabled && (ibkr as any).ok),
      configured: Boolean((ibkr as any).configured),
      latencyTargetMs: 250,
      role: 'Broker quote confirmation, account risk, margin, holdings, execution bridge.',
      env: ['IBKR_BASE_URL', 'IBKR_MARKET_DATA_ENABLED', 'IBKR_ACCOUNT_ID'],
      setup: 'Run IB Gateway/Client Portal, authenticate session, set IBKR_MARKET_DATA_ENABLED=true.',
      whyItMatters: 'Best used for execution and account/margin truth, not as the only news or OPRA feed.',
    }),
    provider({
      id: 'x-api',
      name: 'X API / social firehose',
      tier: 'T3',
      category: 'news',
      enabled: Boolean(process.env.X_BEARER_TOKEN),
      configured: Boolean(process.env.X_BEARER_TOKEN),
      latencyTargetMs: 900,
      role: 'Social early-warning and rumor discovery.',
      env: ['X_BEARER_TOKEN'],
      setup: 'Use only as low-confidence corroboration unless matched by T0/T1.',
      whyItMatters: 'Useful for velocity, but cannot trigger RED alone.',
    }),
    provider({
      id: 'yahoo-disabled',
      name: 'Yahoo Finance delayed fallback',
      tier: 'T4',
      category: 'market_tape',
      enabled: false,
      configured: false,
      latencyTargetMs: 900000,
      role: 'Backtest or last-resort historical data only.',
      env: [],
      setup: 'Intentionally disabled for intraday risk alerts.',
      whyItMatters: 'Retail delayed data is not acceptable as primary alert input.',
    }),
  ];
}

export function getPublicSignalSources(): PublicSignalSource[] {
  const customOfficialFeeds = parseConfiguredFeeds(process.env.PUBLIC_OFFICIAL_RSS_FEEDS);
  return [
    {
      id: 'fed-official-rss',
      name: 'Federal Reserve official RSS',
      tier: 'T0',
      kind: 'official_rss',
      active: true,
      configured: true,
      url: 'https://www.federalreserve.gov/feeds/feeds.htm',
      env: [],
      role: 'FOMC, monetary-policy, supervision, speeches, and official Fed announcements.',
      marketUse: 'Rates, USD, NQ/QQQ duration pressure, bank liquidity, and risk appetite.',
      confirmationRole: 'Official first-hand source for Fed communication.',
    },
    {
      id: 'federal-register-api',
      name: 'Federal Register public API',
      tier: 'T0',
      kind: 'official_api',
      active: true,
      configured: true,
      url: 'https://www.federalregister.gov/developers/documentation/api/v1',
      env: [],
      role: 'Rules, proposed rules, notices, executive orders, public-inspection documents.',
      marketUse: 'Tariffs, export controls, energy rules, healthcare regulation, industrial policy.',
      confirmationRole: 'Official legal/public-record source for US regulatory actions.',
    },
    {
      id: 'bls-public-api',
      name: 'BLS Public Data API',
      tier: 'T0',
      kind: 'official_api',
      active: false,
      configured: Boolean(process.env.BLS_API_KEY || process.env.BLS_PUBLIC_API_ENABLED === 'true'),
      url: 'https://www.bls.gov/developers/',
      env: ['BLS_API_KEY', 'BLS_PUBLIC_API_ENABLED'],
      role: 'CPI, payrolls, unemployment, wages, PPI, claims-adjacent labor series.',
      marketUse: 'Macro surprise baseline for 2Y yields, DXY, QQQ/NQ, cyclicals, gold.',
      confirmationRole: 'Official macro data, but release-time surprise still needs consensus from Econoday/Trading Economics.',
    },
    {
      id: 'bea-api',
      name: 'BEA API',
      tier: 'T0',
      kind: 'official_api',
      active: false,
      configured: Boolean(process.env.BEA_API_KEY),
      url: 'https://www.bea.gov/open-data',
      env: ['BEA_API_KEY'],
      role: 'GDP, PCE, personal income/spending, corporate profits, trade aggregates.',
      marketUse: 'Inflation/growth mix, Fed path, real-yield pressure, consumer strength.',
      confirmationRole: 'Official macro data, not a realtime consensus feed.',
    },
    {
      id: 'eia-api',
      name: 'EIA Open Data API',
      tier: 'T0',
      kind: 'official_api',
      active: false,
      configured: Boolean(process.env.EIA_API_KEY),
      url: 'https://www.eia.gov/opendata/',
      env: ['EIA_API_KEY'],
      role: 'Oil, gas, electricity, inventory, production, and energy balance data.',
      marketUse: 'Crude/oil services, inflation impulse, airline/transport costs, geopolitical energy shocks.',
      confirmationRole: 'Official energy data source.',
    },
    {
      id: 'treasury-ofac-official',
      name: 'Treasury / OFAC official releases',
      tier: 'T0',
      kind: 'official_site',
      active: false,
      configured: Boolean(process.env.TREASURY_OFFICIAL_FEED_URL || process.env.PUBLIC_OFFICIAL_RSS_FEEDS?.includes('treasury.gov')),
      url: 'https://home.treasury.gov/news/press-releases',
      env: ['TREASURY_OFFICIAL_FEED_URL', 'PUBLIC_OFFICIAL_RSS_FEEDS'],
      role: 'Sanctions, debt/financing, Treasury announcements, OFAC designations.',
      marketUse: 'USD liquidity, geopolitics, energy, defense, banks, China/Iran/Russia exposed assets.',
      confirmationRole: 'Official first-hand source; adapter waits for a stable licensed/public feed URL.',
    },
    {
      id: 'white-house-official',
      name: 'White House briefing room',
      tier: 'T0',
      kind: 'official_site',
      active: false,
      configured: Boolean(process.env.WHITE_HOUSE_FEED_URL || process.env.PUBLIC_OFFICIAL_RSS_FEEDS?.includes('whitehouse.gov')),
      url: 'https://www.whitehouse.gov/briefing-room/',
      env: ['WHITE_HOUSE_FEED_URL', 'PUBLIC_OFFICIAL_RSS_FEEDS'],
      role: 'Presidential statements, executive orders, national-security and policy announcements.',
      marketUse: 'Tariff, export-control, defense, energy, healthcare, China/Taiwan/Iran/Russia policy shocks.',
      confirmationRole: 'Official executive-branch communication.',
    },
    {
      id: 'ustr-official',
      name: 'USTR official press office',
      tier: 'T0',
      kind: 'official_site',
      active: false,
      configured: Boolean(process.env.USTR_FEED_URL || process.env.PUBLIC_OFFICIAL_RSS_FEEDS?.includes('ustr.gov')),
      url: 'https://ustr.gov/about-us/policy-offices/press-office',
      env: ['USTR_FEED_URL', 'PUBLIC_OFFICIAL_RSS_FEEDS'],
      role: 'Tariffs, trade negotiations, Section 301/232 style trade actions.',
      marketUse: 'China ADRs, semis, autos, industrials, retailers, solar, steel/aluminum.',
      confirmationRole: 'Official trade-policy source.',
    },
    {
      id: 'company-ir-public-feeds',
      name: 'Company investor-relations public feeds',
      tier: 'T0',
      kind: 'company_ir',
      active: customOfficialFeeds.length > 0,
      configured: customOfficialFeeds.length > 0,
      url: 'env:PUBLIC_OFFICIAL_RSS_FEEDS',
      env: ['PUBLIC_OFFICIAL_RSS_FEEDS'],
      role: 'Issuer press releases and IR feeds supplied explicitly by config.',
      marketUse: 'Offerings, guidance, earnings, product/news releases, buybacks, M&A.',
      confirmationRole: 'Official company source when feed URL belongs to issuer/IR/wire domain.',
    },
    {
      id: 'nyt-api',
      name: 'New York Times API',
      tier: 'T3',
      kind: 'news_api',
      active: Boolean(process.env.NYT_API_KEY),
      configured: Boolean(process.env.NYT_API_KEY),
      url: 'https://developer.nytimes.com/docs',
      env: ['NYT_API_KEY', 'NYT_SIGNAL_QUERY'],
      role: 'High-quality public journalism and geopolitical context.',
      marketUse: 'Context, first reported narratives, policy/geopolitical framing, not official confirmation.',
      confirmationRole: 'Reported context only. Must be corroborated by official releases or market tape before high-severity alerts.',
    },
    {
      id: 'gdelt-public-index',
      name: 'GDELT public global news index',
      tier: 'T3',
      kind: 'news_api',
      active: false,
      configured: true,
      url: 'https://www.gdeltproject.org/',
      env: [],
      role: 'Broad public global-news index for velocity and source discovery.',
      marketUse: 'Narrative velocity, country/sector clustering, cross-source discovery.',
      confirmationRole: 'Discovery layer only.',
    },
    {
      id: 'jin10-public-wire',
      name: 'Jin10 / Chinese fast-news feed',
      tier: 'T3',
      kind: 'aggregator',
      active: Boolean(process.env.JIN10_API_KEY || process.env.JIN10_FEED_URL),
      configured: Boolean(process.env.JIN10_API_KEY || process.env.JIN10_FEED_URL),
      url: 'https://www.jin10.com/',
      env: ['JIN10_API_KEY', 'JIN10_FEED_URL'],
      role: 'Fast Chinese-language market-news aggregation similar to the screenshot.',
      marketUse: 'Early public headline discovery for geopolitics, commodities, FX, China/HK/US macro.',
      confirmationRole: 'Aggregator only. It cannot confirm official actions by itself.',
    },
  ];
}

function provider(input: Omit<ProfessionalProvider, 'status'>): ProfessionalProvider {
  return {
    ...input,
    status: input.enabled && input.configured ? 'ready' : input.configured ? 'disabled' : input.tier === 'T4' ? 'disabled' : 'missing',
  };
}

async function fetchSecSignalEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const tickers = universe.filter((ticker) => KNOWN_CIKS[ticker]).slice(0, 12);
  const results = await Promise.all(tickers.map((ticker) => fetchSecEventsForTicker(ticker)));
  return results.flat().slice(0, 40);
}

async function fetchSecEventsForTicker(ticker: string): Promise<GlobalSignalEvent[]> {
  const cik = KNOWN_CIKS[ticker];
  const url = `https://data.sec.gov/submissions/CIK${cik}.json`;
  const data = await fetchJson<SecSubmission>(url, {
    headers: { 'User-Agent': SEC_USER_AGENT, Accept: 'application/json' },
  });
  const recent = data.filings?.recent;
  if (!recent?.accessionNumber?.length) return [];

  return recent.accessionNumber.slice(0, 18).flatMap((accession, index) => {
    const form = recent.form?.[index] || '';
    if (!MATERIAL_FORMS.has(form)) return [];

    const filingDate = recent.filingDate?.[index] || new Date().toISOString().slice(0, 10);
    const accepted = recent.acceptanceDateTime?.[index];
    const publishedAt = accepted ? secAcceptanceToIso(accepted) : new Date(`${filingDate}T13:30:00.000Z`).toISOString();
    if (Date.now() - new Date(publishedAt).getTime() > 1000 * 60 * 60 * 24 * 14) return [];
    const primaryDoc = recent.primaryDocument?.[index] || '';
    const archiveAccession = accession.replace(/-/g, '');
    const filingUrl = primaryDoc
      ? `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${archiveAccession}/${primaryDoc}`
      : `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${archiveAccession}/`;
    const classification = classifySecForm(form);

    return [
      {
        id: `sec-${ticker}-${accession}`,
        title: `${ticker} filed ${form}`,
        summary: `${ticker} filed ${recent.primaryDocDescription?.[index] || form}. Official EDGAR disclosure.`,
        category: 'filing',
        eventType: classification.eventType,
        sourceId: 'sec-edgar-official',
        sourceName: 'SEC EDGAR',
        sourceTier: 'T0',
        confirmationStatus: 'official_confirmed',
        publishedAt,
        receivedAt: new Date().toISOString(),
        latencyMs: latencyMs(publishedAt),
        affectedAssets: mapAffectedAssets(ticker, classification.eventType),
        direction: classification.direction,
        severity: classification.severity,
        confidence: 96,
        canEscalateRed: true,
        transmission: classification.transmission,
        evidence: [
          { label: 'form', value: form },
          { label: 'accession', value: accession, url: filingUrl },
          { label: 'issuer', value: data.name || ticker },
        ],
      } satisfies GlobalSignalEvent,
    ];
  });
}

async function fetchBenzingaSignalEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const key = process.env.BENZINGA_API_KEY;
  if (!key) return [];

  const url = new URL('https://api.benzinga.com/api/v2/news');
  url.searchParams.set('token', key);
  url.searchParams.set('tickers', universe.filter((ticker) => /^[A-Z]{1,5}$/.test(ticker)).slice(0, 40).join(','));
  url.searchParams.set('pageSize', '30');
  url.searchParams.set('displayOutput', 'full');

  const data = await fetchJson<BenzingaNewsResponse>(url.toString(), {
    headers: { Accept: 'application/json' },
  });

  return data.slice(0, 30).map((item) => {
    const text = `${item.title || ''} ${item.teaser || ''} ${item.body || ''}`;
    const classification = classifyHeadline(text);
    const tickers = normalizeUniverse((item.stocks || []).map((stock) => stock.name || '').filter(Boolean));
    const publishedAt = parseBenzingaDate(item.created || item.updated) || new Date().toISOString();

    return {
      id: `benzinga-${item.id || stableId(text)}`,
      title: item.title || 'Benzinga market headline',
      summary: (item.teaser || stripHtml(item.body || item.title || '')).slice(0, 360),
      category: classification.category,
      eventType: classification.eventType,
      sourceId: 'benzinga-news-api',
      sourceName: 'Benzinga News API',
      sourceTier: 'T1',
      confirmationStatus: classification.confirmationStatus,
      publishedAt,
      receivedAt: new Date().toISOString(),
      latencyMs: latencyMs(publishedAt),
      affectedAssets: mapAffectedAssets(tickers[0] || 'QQQ', classification.eventType, tickers),
      direction: classification.direction,
      severity: classification.severity,
      confidence: classification.confidence,
      canEscalateRed: true,
      transmission: classification.transmission,
      evidence: [
        { label: 'provider', value: 'Benzinga News API' },
        { label: 'channels', value: (item.channels || []).map((channel) => channel.name).filter(Boolean).join(', ') || 'n/a' },
        ...(item.url ? [{ label: 'headline', value: item.title || 'article', url: item.url }] : []),
      ],
    } satisfies GlobalSignalEvent;
  });
}

async function fetchPublicSignalEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const [fed, federalRegister, nyt, customRss] = await Promise.all([
    fetchFedRssEvents(universe).catch((err) => providerFailure('fed-official-rss', err)),
    fetchFederalRegisterEvents(universe).catch((err) => providerFailure('federal-register-api', err)),
    fetchNytSignalEvents(universe).catch((err) => providerFailure('nyt-api', err)),
    fetchConfiguredRssEvents(universe).catch((err) => providerFailure('public-official-rss', err)),
  ]);
  return [...fed, ...federalRegister, ...nyt, ...customRss].slice(0, 60);
}

async function fetchFedRssEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const feeds = [
    ['fed-press-all', 'https://www.federalreserve.gov/feeds/press_all.xml'],
    ['fed-press-monetary', 'https://www.federalreserve.gov/feeds/press_monetary.xml'],
    ['fed-speeches', 'https://www.federalreserve.gov/feeds/speeches.xml'],
  ] as const;
  const results = await Promise.all(
    feeds.map(async ([feedId, url]) => {
      const xml = await fetchText(url);
      return parseRssItems(xml)
        .slice(0, 8)
        .filter(isRecentPublicItem)
        .map((item) => publicItemToEvent(item, {
          sourceId: 'fed-official-rss',
          sourceName: 'Federal Reserve',
          sourceTier: 'T0',
          confirmationStatus: 'official_confirmed',
          defaultCategory: 'macro',
          defaultEventType: feedId.includes('monetary') ? 'Fed Monetary Policy Communication' : 'Fed Official Communication',
          universe,
        }));
    })
  );
  return dedupeEvents(results.flat());
}

async function fetchFederalRegisterEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const terms = [
    'semiconductor export control tariff sanctions Iran China Russia energy nuclear AI chips',
    ...universe.filter((ticker) => ['META', 'NVDA', 'AVGO', 'MU', 'AMD', 'TSLA', 'AAPL'].includes(ticker)).slice(0, 6),
  ].join(' ');
  const url = new URL('https://www.federalregister.gov/api/v1/documents.json');
  url.searchParams.set('per_page', '20');
  url.searchParams.set('order', 'newest');
  url.searchParams.set('conditions[term]', terms);

  const data = await fetchJson<FederalRegisterResponse>(url.toString(), { headers: { Accept: 'application/json' } });
  return (data.results || [])
    .filter((item) => item.title && item.publication_date)
    .filter((item) => isRecentPublicItem({ publishedAt: new Date(`${item.publication_date}T12:00:00.000Z`).toISOString() } as RssItem))
    .slice(0, 12)
    .map((item) => {
      const title = item.title || 'Federal Register document';
      const text = `${title} ${item.abstract || ''} ${(item.agencies || []).map((agency) => agency.name).join(' ')}`;
      const classification = classifyPublicSignalText(text, 'Federal Register document');
      const publishedAt = new Date(`${item.publication_date}T12:00:00.000Z`).toISOString();
      const affectedAssets = mapPublicAffectedAssets(text, universe);
      return {
        id: `federal-register-${item.document_number || stableId(title)}`,
        title,
        summary: stripHtml(item.abstract || `${item.type || 'Document'} from ${(item.agencies || []).map((agency) => agency.name).join(', ') || 'Federal Register'}.`).slice(0, 420),
        category: classification.category,
        eventType: classification.eventType,
        sourceId: 'federal-register-api',
        sourceName: 'Federal Register',
        sourceTier: 'T0',
        confirmationStatus: 'official_confirmed',
        publishedAt,
        receivedAt: new Date().toISOString(),
        latencyMs: latencyMs(publishedAt),
        affectedAssets,
        direction: classification.direction,
        severity: classification.severity,
        confidence: 90,
        canEscalateRed: true,
        transmission: classification.transmission,
        evidence: [
          { label: 'document', value: item.document_number || title, url: item.html_url },
          { label: 'agency', value: (item.agencies || []).map((agency) => agency.name).filter(Boolean).join(', ') || 'n/a' },
        ],
      } satisfies GlobalSignalEvent;
    });
}

async function fetchNytSignalEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const key = process.env.NYT_API_KEY;
  if (!key) return [];
  const url = new URL('https://api.nytimes.com/svc/search/v2/articlesearch.json');
  url.searchParams.set(
    'q',
    process.env.NYT_SIGNAL_QUERY ||
      'Federal Reserve OR Treasury OR sanctions OR tariffs OR Iran OR China OR Nvidia OR Meta OR semiconductors OR oil OR dollar'
  );
  url.searchParams.set('sort', 'newest');
  url.searchParams.set('api-key', key);

  const data = await fetchJson<NytArticleSearchResponse>(url.toString(), { headers: { Accept: 'application/json' } });
  return (data.response?.docs || [])
    .filter((doc) => doc.headline?.main && doc.pub_date)
    .filter((doc) => isRecentPublicItem({ publishedAt: doc.pub_date || '' } as RssItem))
    .slice(0, 10)
    .map((doc, index) => {
      const title = doc.headline?.main || 'NYT article';
      const text = `${title} ${doc.abstract || doc.snippet || doc.lead_paragraph || ''} ${(doc.keywords || []).map((keyword) => keyword.value).join(' ')}`;
      const classification = classifyPublicSignalText(text, 'NYT reported context');
      const affectedAssets = mapPublicAffectedAssets(text, universe);
      const publishedAt = new Date(doc.pub_date || Date.now()).toISOString();
      return {
        id: `nyt-${stableId(doc.web_url || title)}-${index}`,
        title,
        summary: (doc.abstract || doc.snippet || doc.lead_paragraph || 'NYT public article search result.').slice(0, 420),
        category: classification.category,
        eventType: classification.eventType,
        sourceId: 'nyt-api',
        sourceName: 'New York Times API',
        sourceTier: 'T3',
        confirmationStatus: 'reported_not_confirmed',
        publishedAt,
        receivedAt: new Date().toISOString(),
        latencyMs: latencyMs(publishedAt),
        affectedAssets,
        direction: classification.direction,
        severity: Math.min(74, classification.severity),
        confidence: 62,
        canEscalateRed: false,
        transmission: [...classification.transmission, 'NYT context requires official confirmation'],
        evidence: [
          { label: 'article', value: doc.source || 'NYT', url: doc.web_url },
          { label: 'desk', value: doc.news_desk || 'n/a' },
        ],
      } satisfies GlobalSignalEvent;
    });
}

async function fetchConfiguredRssEvents(universe: string[]): Promise<GlobalSignalEvent[]> {
  const feeds = [
    ...parseConfiguredFeeds(process.env.PUBLIC_OFFICIAL_RSS_FEEDS),
    ...parseConfiguredFeeds(process.env.TREASURY_OFFICIAL_FEED_URL),
    ...parseConfiguredFeeds(process.env.WHITE_HOUSE_FEED_URL),
    ...parseConfiguredFeeds(process.env.USTR_FEED_URL),
    ...parseConfiguredFeeds(process.env.JIN10_FEED_URL),
  ];
  if (!feeds.length) return [];

  const results = await Promise.all(
    feeds.slice(0, 12).map(async (feedUrl) => {
      const xml = await fetchText(feedUrl);
      const host = safeHost(feedUrl);
      const isAggregator = host.includes('jin10');
      return parseRssItems(xml)
        .slice(0, 8)
        .filter(isRecentPublicItem)
        .map((item) => publicItemToEvent(item, {
          sourceId: isAggregator ? 'jin10-public-wire' : 'company-ir-public-feeds',
          sourceName: isAggregator ? 'Jin10 configured feed' : host,
          sourceTier: isAggregator ? 'T3' : 'T0',
          confirmationStatus: isAggregator ? 'reported_not_confirmed' : 'official_confirmed',
          defaultCategory: isAggregator ? 'news' : 'company_event',
          defaultEventType: isAggregator ? 'Fast Public Market Headline' : 'Configured Official Public Feed',
          universe,
        }));
    })
  );
  return dedupeEvents(results.flat());
}

function publicItemToEvent(
  item: RssItem,
  config: {
    sourceId: string;
    sourceName: string;
    sourceTier: SourceTier;
    confirmationStatus: ConfirmationStatus;
    defaultCategory: SignalCategory;
    defaultEventType: string;
    universe: string[];
  }
): GlobalSignalEvent {
  const text = `${item.title} ${item.summary}`;
  const classification = classifyPublicSignalText(text, config.defaultEventType, config.defaultCategory);
  const affectedAssets = mapPublicAffectedAssets(text, config.universe);
  return {
    id: `${config.sourceId}-${stableId(item.url || item.title)}`,
    title: item.title,
    summary: item.summary.slice(0, 420) || item.title,
    category: classification.category,
    eventType: classification.eventType,
    sourceId: config.sourceId,
    sourceName: config.sourceName,
    sourceTier: config.sourceTier,
    confirmationStatus: config.confirmationStatus,
    publishedAt: item.publishedAt,
    receivedAt: new Date().toISOString(),
    latencyMs: latencyMs(item.publishedAt),
    affectedAssets,
    direction: classification.direction,
    severity: classification.severity,
    confidence: config.sourceTier === 'T0' ? 88 : 62,
    canEscalateRed: config.sourceTier === 'T0',
    transmission: classification.transmission,
    evidence: [{ label: 'source', value: config.sourceName, url: item.url }],
  };
}

function classifySecForm(form: string): Pick<
  GlobalSignalEvent,
  'eventType' | 'direction' | 'severity' | 'transmission'
> {
  if (form === '4' || form === '3' || form === '5') {
    return {
      eventType: 'Insider Transaction Filing',
      direction: 'mixed',
      severity: 66,
      transmission: ['Insider activity', 'single-name sentiment', 'requires transaction-code parsing'],
    };
  }
  if (form === 'S-3' || form === '424B5' || form === 'FWP') {
    return {
      eventType: 'Offering / Financing Filing',
      direction: 'risk_off',
      severity: 84,
      transmission: ['Potential dilution or debt supply', 'liquidity absorption', 'sector sentiment repricing'],
    };
  }
  if (form === 'S-1' || form === 'S-1/A') {
    return {
      eventType: 'IPO / Registration Filing',
      direction: 'mixed',
      severity: 78,
      transmission: ['IPO valuation anchor', 'sector comps repricing', 'new supply'],
    };
  }
  if (form === '8-K') {
    return {
      eventType: 'Material Corporate Event',
      direction: 'mixed',
      severity: 76,
      transmission: ['Company event', 'guidance/financing/M&A risk', 'requires item-level review'],
    };
  }
  return {
    eventType: 'Ownership / Material Filing',
    direction: 'mixed',
    severity: 62,
    transmission: ['Ownership change', 'positioning signal'],
  };
}

function classifyHeadline(text: string): Pick<
  GlobalSignalEvent,
  'category' | 'eventType' | 'direction' | 'severity' | 'confidence' | 'confirmationStatus' | 'transmission'
> {
  const lower = text.toLowerCase();
  if (containsAny(lower, ['equity raise', 'stock offering', 'share offering', 'atm offering', 'convertible', 'secondary offering'])) {
    return {
      category: 'company_event',
      eventType: 'Equity Financing / Dilution Concern',
      direction: 'risk_off',
      severity: 86,
      confidence: containsAny(lower, ['weighs', 'considering', 'explores', 'report']) ? 74 : 88,
      confirmationStatus: containsAny(lower, ['weighs', 'considering', 'explores', 'report']) ? 'reported_not_confirmed' : 'official_confirmed',
      transmission: ['Dilution risk', 'AI capex funding concern', 'mega-cap sentiment'],
    };
  }
  if (containsAny(lower, ['nfp', 'nonfarm', 'cpi', 'ppi', 'fomc', 'fed', 'payrolls', 'inflation'])) {
    return {
      category: 'macro',
      eventType: 'Macro Policy Shock',
      direction: containsAny(lower, ['hot', 'strong', 'beat', 'higher']) ? 'risk_off' : 'mixed',
      severity: 82,
      confidence: 78,
      confirmationStatus: 'reported_not_confirmed',
      transmission: ['Rate expectations', '2Y yield', 'duration equity valuation'],
    };
  }
  if (containsAny(lower, ['liquidation', 'margin call', 'forced selling', 'deleveraging', 'unwind', 'limit down'])) {
    return {
      category: 'leverage',
      eventType: 'Forced Deleveraging Signal',
      direction: 'risk_off',
      severity: 90,
      confidence: 80,
      confirmationStatus: 'reported_not_confirmed',
      transmission: ['Crowded positioning', 'volatility spike', 'correlation breakdown'],
    };
  }
  if (containsAny(lower, ['downgrade', 'guidance cut', 'misses', 'probe', 'investigation', 'export control', 'sanction'])) {
    return {
      category: 'company_event',
      eventType: 'Negative Corporate Shock',
      direction: 'risk_off',
      severity: 76,
      confidence: 78,
      confirmationStatus: 'reported_not_confirmed',
      transmission: ['Single-name repricing', 'sector sympathy', 'options repricing'],
    };
  }
  return {
    category: 'news',
    eventType: 'Market Headline',
    direction: 'neutral',
    severity: 45,
    confidence: 64,
    confirmationStatus: 'reported_not_confirmed',
    transmission: ['Headline watch', 'requires confirmation'],
  };
}

function classifyPublicSignalText(
  text: string,
  fallbackEventType: string,
  fallbackCategory: SignalCategory = 'news'
): Pick<GlobalSignalEvent, 'category' | 'eventType' | 'direction' | 'severity' | 'transmission'> {
  const lower = text.toLowerCase();
  if (containsAny(lower, ['stock offering', 'share offering', 'equity financing', 'secondary offering', 'convertible', 'atm offering'])) {
    return {
      category: 'company_event',
      eventType: 'Equity Financing / Dilution Concern',
      direction: 'risk_off',
      severity: 86,
      transmission: ['Potential dilution', 'funding pressure', 'single-name beta', 'sector read-through'],
    };
  }
  if (containsAny(lower, ['fomc', 'federal reserve', 'interest rate', 'inflation', 'hawkish', 'higher for longer', 'balance sheet'])) {
    const dovish = containsAny(lower, ['cut', 'cuts', 'easing', 'liquidity facility', 'slower runoff', 'dovish']);
    return {
      category: 'macro',
      eventType: 'Fed / Rate Policy Signal',
      direction: dovish ? 'risk_on' : 'risk_off',
      severity: dovish ? 76 : 84,
      transmission: ['Fed path', '2Y yield', 'real rates', 'DXY', 'duration equity valuation'],
    };
  }
  if (containsAny(lower, ['sanction', 'ofac', 'iran', 'russia', 'houthi', 'nuclear', 'military action', 'red sea'])) {
    return {
      category: 'global_lead_lag',
      eventType: 'Geopolitical / Sanctions Shock',
      direction: 'risk_off',
      severity: 82,
      transmission: ['Geopolitical risk premium', 'oil/energy', 'DXY safe-haven demand', 'defense/commodity dispersion'],
    };
  }
  if (containsAny(lower, ['tariff', 'section 301', 'section 232', 'trade representative', 'export control', 'bis', 'entity list'])) {
    return {
      category: 'global_lead_lag',
      eventType: 'Trade / Export Control Policy',
      direction: 'risk_off',
      severity: 80,
      transmission: ['Trade policy', 'supply-chain margins', 'China beta', 'semiconductor hardware chain'],
    };
  }
  if (containsAny(lower, ['payroll', 'nonfarm', 'cpi', 'ppi', 'pce', 'unemployment', 'wages', 'gdp', 'retail sales'])) {
    return {
      category: 'macro',
      eventType: 'Official Macro Data Signal',
      direction: containsAny(lower, ['hot', 'strong', 'beat', 'accelerat']) ? 'risk_off' : 'mixed',
      severity: 78,
      transmission: ['Macro surprise', 'Treasury curve', 'Fed pricing', 'equity factor rotation'],
    };
  }
  if (containsAny(lower, ['crude', 'oil', 'inventory', 'spr', 'opec', 'natural gas', 'lng'])) {
    return {
      category: 'liquidity',
      eventType: 'Energy / Inflation Impulse',
      direction: 'mixed',
      severity: 70,
      transmission: ['Energy prices', 'inflation expectations', 'transport margins', 'oil equities'],
    };
  }
  if (containsAny(lower, ['probe', 'investigation', 'antitrust', 'lawsuit', 'doj', 'ftc', 'sec charges'])) {
    return {
      category: 'company_event',
      eventType: 'Regulatory / Legal Shock',
      direction: 'risk_off',
      severity: 76,
      transmission: ['Regulatory overhang', 'multiple compression', 'sector sympathy'],
    };
  }
  if (containsAny(lower, ['subsidy', 'grant', 'approval', 'contract award', 'buyback', 'repurchase'])) {
    return {
      category: 'company_event',
      eventType: 'Positive Policy / Capital Return Signal',
      direction: 'risk_on',
      severity: 68,
      transmission: ['Policy support', 'earnings visibility', 'sector sentiment'],
    };
  }
  return {
    category: fallbackCategory,
    eventType: fallbackEventType,
    direction: 'neutral',
    severity: 48,
    transmission: ['Public headline watch', 'requires market confirmation'],
  };
}

function scoreGlobalSignals(events: GlobalSignalEvent[]): SignalScoreCard {
  const macroHawkScore = categoryScore(events, 'macro');
  const leverageUnwindScore = categoryScore(events, 'leverage');
  const globalContagionScore = categoryScore(events, 'global_lead_lag');
  const megaCapShockScore = Math.max(categoryScore(events, 'company_event'), categoryScore(events, 'filing') * 0.8);
  const optionsStressScore = categoryScore(events, 'options');
  const liquidityStressScore = categoryScore(events, 'liquidity');
  const newsVelocityScore = velocityScore(events);
  const fragilityScore = clamp(
    0.3 * leverageUnwindScore + 0.2 * optionsStressScore + 0.2 * liquidityStressScore + 0.2 * megaCapShockScore + 0.1 * newsVelocityScore
  );
  const triggerScore = clamp(0.35 * macroHawkScore + 0.25 * megaCapShockScore + 0.2 * globalContagionScore + 0.2 * newsVelocityScore);
  let marketRiskScore = clamp(
    0.25 * macroHawkScore +
      0.2 * leverageUnwindScore +
      0.15 * globalContagionScore +
      0.15 * megaCapShockScore +
      0.1 * optionsStressScore +
      0.1 * liquidityStressScore +
      0.05 * newsVelocityScore
  );

  const hasRedEligible = events.some((event) => event.canEscalateRed && event.severity >= 85 && event.confidence >= 70);
  if (!hasRedEligible && marketRiskScore >= 85) marketRiskScore = 84;

  const level = alertLevel(marketRiskScore);
  return {
    macroHawkScore: roundScore(macroHawkScore),
    leverageUnwindScore: roundScore(leverageUnwindScore),
    globalContagionScore: roundScore(globalContagionScore),
    megaCapShockScore: roundScore(megaCapShockScore),
    optionsStressScore: roundScore(optionsStressScore),
    liquidityStressScore: roundScore(liquidityStressScore),
    newsVelocityScore: roundScore(newsVelocityScore),
    fragilityScore: roundScore(fragilityScore),
    triggerScore: roundScore(triggerScore),
    marketRiskScore: roundScore(marketRiskScore),
    level,
    regime: regimeForScores(marketRiskScore, macroHawkScore, leverageUnwindScore, megaCapShockScore),
    action: actionForLevel(level),
  };
}

function categoryScore(events: GlobalSignalEvent[], category: SignalCategory): number {
  const categoryEvents = events.filter((event) => event.category === category);
  if (!categoryEvents.length) return 10;
  const weighted = categoryEvents.reduce((sum, event) => {
    const tierWeight = event.sourceTier === 'T0' ? 1.15 : event.sourceTier === 'T1' ? 1 : event.sourceTier === 'T2' ? 0.8 : 0.45;
    return sum + event.severity * (event.confidence / 100) * tierWeight * recencyWeight(event.publishedAt);
  }, 0);
  return clamp(15 + weighted / Math.sqrt(categoryEvents.length + 1));
}

function velocityScore(events: GlobalSignalEvent[]): number {
  const now = Date.now();
  const recent = events.filter((event) => now - new Date(event.publishedAt).getTime() < 1000 * 60 * 60 * 6);
  const highSeverity = recent.filter((event) => event.severity >= 75).length;
  return clamp(10 + recent.length * 6 + highSeverity * 10);
}

function recencyWeight(publishedAt: string): number {
  const ageMs = Date.now() - new Date(publishedAt).getTime();
  if (!Number.isFinite(ageMs) || ageMs < 0) return 1;
  const ageHours = ageMs / (1000 * 60 * 60);
  if (ageHours <= 6) return 1;
  if (ageHours <= 24) return 0.8;
  if (ageHours <= 72) return 0.45;
  if (ageHours <= 168) return 0.2;
  return 0.05;
}

function buildReplayEvents(): GlobalSignalEvent[] {
  const receivedAt = new Date().toISOString();
  return [
    {
      id: 'replay-2026-06-05-nfp',
      title: 'Replay: hot NFP created hawkish shock',
      summary: 'May payrolls beat consensus, reducing rate-cut expectations and pressuring long-duration equity.',
      category: 'macro',
      eventType: 'Macro Policy Shock',
      sourceId: 'replay-casebook',
      sourceName: 'Replay casebook',
      sourceTier: 'T0',
      confirmationStatus: 'replay',
      publishedAt: '2026-06-05T08:30:00-04:00',
      receivedAt,
      latencyMs: null,
      affectedAssets: ['QQQ', 'SOXX', 'NQ', 'US2Y', 'DXY'],
      direction: 'risk_off',
      severity: 86,
      confidence: 82,
      canEscalateRed: false,
      transmission: ['NFP surprise', '2Y yield up', 'Fed path repricing', 'high-duration equity compression'],
      evidence: [{ label: 'case', value: '2026-06-05 macro replay' }],
    },
    {
      id: 'replay-2026-06-05-meta-financing',
      title: 'Replay: META potential equity financing headline',
      summary: 'Potential equity raise for AI infrastructure created dilution and AI capex funding concern.',
      category: 'company_event',
      eventType: 'Equity Financing / Dilution Concern',
      sourceId: 'replay-casebook',
      sourceName: 'Replay casebook',
      sourceTier: 'T1',
      confirmationStatus: 'replay',
      publishedAt: '2026-06-05T13:30:00-04:00',
      receivedAt,
      latencyMs: null,
      affectedAssets: ['META', 'QQQ', 'NVDA', 'AVGO', 'SOXX'],
      direction: 'risk_off',
      severity: 84,
      confidence: 74,
      canEscalateRed: false,
      transmission: ['AI capex financing', 'possible dilution', 'mega-cap sentiment', 'semiconductor demand chain'],
      evidence: [{ label: 'case', value: 'reported-not-confirmed event replay' }],
    },
    {
      id: 'replay-korea-memory-stress',
      title: 'Replay: Korea memory leverage stress lead-lag',
      summary: 'Regional semiconductor weakness and forced liquidation headlines can transmit into MU/SOXX/NQ.',
      category: 'global_lead_lag',
      eventType: 'Korea Memory Stress',
      sourceId: 'replay-casebook',
      sourceName: 'Replay casebook',
      sourceTier: 'T1',
      confirmationStatus: 'replay',
      publishedAt: '2026-06-05T02:30:00-04:00',
      receivedAt,
      latencyMs: null,
      affectedAssets: ['MU', 'SOXX', 'SMH', 'NVDA', 'USDKRW', 'KOSPI'],
      direction: 'risk_off',
      severity: 82,
      confidence: 70,
      canEscalateRed: false,
      transmission: ['Asia semis lead US semis', 'memory chain pressure', 'FX stress', 'NQ hedge pressure'],
      evidence: [{ label: 'case', value: 'global lead-lag replay' }],
    },
  ];
}

function withImpactAssessment(event: GlobalSignalEvent): GlobalSignalEvent {
  return {
    ...event,
    impactAssessment: assessSignalImpact(event),
  };
}

function assessSignalImpact(event: GlobalSignalEvent): SignalImpactAssessment {
  const text = `${event.title} ${event.summary} ${event.eventType}`.toLowerCase();
  const bias: SignalImpactAssessment['bias'] =
    event.direction === 'risk_on' ? 'bullish' : event.direction === 'risk_off' ? 'bearish' : event.direction === 'mixed' ? 'mixed' : 'neutral';
  const reasoning: string[] = [];

  if (event.eventType.includes('Equity Financing') || containsAny(text, ['offering', 'convertible', 'dilution'])) {
    reasoning.push('Equity or convertible financing can add share supply, signal funding need, and pressure high-multiple peers.');
    reasoning.push('The first reaction is often bearish for the issuer unless proceeds clearly de-risk growth or balance-sheet stress.');
  } else if (containsAny(text, ['fed', 'fomc', 'interest rate', '2y', 'inflation', 'payroll', 'cpi', 'pce'])) {
    reasoning.push('Rate-path headlines transmit through 2Y yields, real rates, DXY, and long-duration equity multiples.');
    reasoning.push('If DXY and 2Y/10Y rise together, the read is rate/liquidity pressure rather than clean safety bid.');
  } else if (containsAny(text, ['sanction', 'iran', 'nuclear', 'military', 'red sea', 'houthi'])) {
    reasoning.push('Geopolitical sanctions and conflict headlines raise tail-risk premium and can move oil, defense, USD, and risk beta.');
    reasoning.push('Equity impact depends on whether oil spikes and whether NQ/credit spreads confirm risk-off.');
  } else if (containsAny(text, ['tariff', 'export control', 'entity list', 'section 301', 'section 232'])) {
    reasoning.push('Trade/export-control actions hit supply chains, gross margins, and China-sensitive revenue assumptions.');
    reasoning.push('Semiconductors, autos, industrials, solar, steel/aluminum, and retailers can react before fundamentals are repriced.');
  } else if (containsAny(text, ['oil', 'crude', 'inventory', 'opec', 'natural gas'])) {
    reasoning.push('Energy shocks feed inflation expectations and sector rotation; oil equities may benefit while transports/consumer face margin pressure.');
  } else {
    reasoning.push('Public signal needs tape confirmation: affected assets, yields, DXY, options skew, and sector ETF reaction decide tradability.');
  }

  return {
    bias,
    horizon: event.severity >= 82 ? 'intraday' : event.category === 'filing' || event.category === 'company_event' ? '1-3d' : 'intraday',
    affectedAssets: event.affectedAssets,
    reasoning,
    historicalAnalogs: buildHistoricalAnalogs(event),
  };
}

function buildHistoricalAnalogs(event: GlobalSignalEvent): HistoricalImpactAnalog[] {
  const text = `${event.title} ${event.summary} ${event.eventType}`.toLowerCase();
  if (event.eventType.includes('Equity Financing') || containsAny(text, ['offering', 'convertible', 'dilution'])) {
    return [
      {
        label: 'AI / mega-cap financing headline replay',
        setup: 'Large-cap growth company signals possible equity or convertible financing for capex.',
        usualMarketImpact: 'Issuer often sells first; AI/semiconductor suppliers can weaken if investors read it as capex funding stress.',
        watchNext: ['SEC 424B5 / 8-K confirmation', 'issuer premarket volume', 'QQQ/SMH sympathy', 'IV crush risk after the first gap'],
        confidence: 74,
      },
      {
        label: 'High-beta secondary offering pattern',
        setup: 'Company adds share supply after a strong run or while funding a large buildout.',
        usualMarketImpact: 'First move is usually dilution pressure; rebound depends on pricing discount and use-of-proceeds credibility.',
        watchNext: ['final offering size', 'pricing discount', 'bookrunner demand', 'whether prior low holds after open'],
        confidence: 70,
      },
    ];
  }
  if (containsAny(text, ['fed', 'fomc', 'interest rate', 'payroll', 'cpi', 'pce', 'inflation'])) {
    return [
      {
        label: 'Hot macro / hawkish Fed shock',
        setup: 'Data or Fed communication pushes front-end yields higher and lowers cut probability.',
        usualMarketImpact: '2Y up + DXY up pressures QQQ/NQ and crowded semis; banks may diverge depending on curve shape.',
        watchNext: ['2Y yield impulse', '10Y confirmation', 'DXY direction', 'NQ vs equal-weight market breadth'],
        confidence: 82,
      },
      {
        label: 'Dovish liquidity repair',
        setup: 'Fed tone or facility language eases liquidity fears.',
        usualMarketImpact: 'Risk assets can squeeze higher if yields fall and DXY softens; weak breadth can fade the move.',
        watchNext: ['real yields', 'credit spreads', 'VIX term structure', 'SMH/QQQ reclaim levels'],
        confidence: 72,
      },
    ];
  }
  if (containsAny(text, ['sanction', 'iran', 'nuclear', 'military', 'red sea', 'houthi'])) {
    return [
      {
        label: 'Iran / sanctions escalation headline',
        setup: 'Official or reported geopolitical action raises conflict or sanctions probability.',
        usualMarketImpact: 'Oil and defense can firm; DXY and gold may catch bid; high-beta equities weaken if yields/energy confirm.',
        watchNext: ['WTI/Brent reaction', 'DXY', 'gold', 'defense ETF', 'NQ overnight support'],
        confidence: 78,
      },
    ];
  }
  if (containsAny(text, ['tariff', 'export control', 'entity list', 'section 301', 'section 232'])) {
    return [
      {
        label: 'Export-control / tariff shock',
        setup: 'Official policy creates direct restrictions or cost pressure in cross-border supply chains.',
        usualMarketImpact: 'First reaction is sector-specific risk-off; durable impact depends on exemptions, implementation date, and retaliation.',
        watchNext: ['Federal Register details', 'company exposure disclosures', 'China/HK tape', 'SMH/SOXX relative strength'],
        confidence: 80,
      },
    ];
  }
  if (containsAny(text, ['oil', 'crude', 'inventory', 'opec', 'natural gas'])) {
    return [
      {
        label: 'Energy inflation impulse',
        setup: 'Oil/gas supply or inventory shock changes inflation and margin assumptions.',
        usualMarketImpact: 'Energy equities can outperform; airlines, transports, and consumer discretionary can lag if crude spike persists.',
        watchNext: ['Brent/WTI spread', '10Y breakevens', 'XLE vs XLY', 'airline/transport tape'],
        confidence: 70,
      },
    ];
  }
  return [
    {
      label: 'Public headline without confirmed market transmission',
      setup: 'Headline is public and relevant, but market direction is not yet validated.',
      usualMarketImpact: 'Impact is usually weak until confirmed by price, volume, options skew, yields, FX, or an official filing.',
      watchNext: ['affected ETF reaction', 'volume spike', 'options skew', 'official confirmation source'],
      confidence: 55,
    },
  ];
}

function buildAsiaSemiTape(sources: ProfessionalProvider[]): RegionalWatchItem[] {
  const isReady = (ids: string[]) => ids.some((id) => sources.some((source) => source.id === id && source.status === 'ready'));
  const item = (input: Omit<RegionalWatchItem, 'sourceStatus'>): RegionalWatchItem => ({
    ...input,
    sourceStatus: isReady(input.requiredSourceIds) ? 'ready' : 'missing',
  });

  return [
    item({
      id: 'sk-hynix-open',
      label: 'SK Hynix open',
      market: 'Korea',
      requiredSourceIds: ['korea-market-feed', 'ibkr-client-portal'],
      whatToWatch: 'Opening gap, first 30-60 minutes, and whether sellers keep hitting bids after the first flush.',
      riskOffTrigger: 'Direct open collapse, failed bounce, or limit-down / near limit-down behavior.',
      riskOnRepair: 'Gap-down gets absorbed, price reclaims VWAP/first reaction high, and Samsung is not confirming weakness.',
      affectedAssets: ['MU', 'SNDK', 'SMH', 'SOXX', 'NQ'],
      tradingRead: 'If Hynix cannot hold, do not bottom-fish US memory names on the first red print.',
    }),
    item({
      id: 'samsung-memory-confirmation',
      label: 'Samsung confirmation',
      market: 'Korea',
      requiredSourceIds: ['korea-market-feed', 'ibkr-client-portal'],
      whatToWatch: 'Whether Samsung confirms Hynix weakness or stays resilient as the higher-quality liquidity anchor.',
      riskOffTrigger: 'Samsung breaks with Hynix, showing sector-wide Korea memory stress instead of one-name liquidation.',
      riskOnRepair: 'Samsung holds flat/green while Hynix stabilizes, lowering contagion probability into US semis.',
      affectedAssets: ['MU', 'SNDK', 'AVGO', 'SMH', 'SOXX'],
      tradingRead: 'Hynix plus Samsung both weak is the cleaner pressure signal for US semis.',
    }),
    item({
      id: 'kospi-kosdaq-breadth',
      label: 'KOSPI / KOSDAQ breadth',
      market: 'Korea',
      requiredSourceIds: ['korea-market-feed'],
      whatToWatch: 'Index breadth, semiconductor subsector participation, and whether small-cap risk gets liquidated too.',
      riskOffTrigger: 'KOSDAQ accelerates lower with KOSPI, pointing to broad risk-off rather than isolated memory weakness.',
      riskOnRepair: 'Indexes stabilize and breadth improves after the open.',
      affectedAssets: ['EWY', 'QQQ', 'NQ', 'SMH'],
      tradingRead: 'Broad Korea weakness raises odds that US beta opens heavy even if single-name semis look mixed.',
    }),
    item({
      id: 'krw-fx-stress',
      label: 'KRW / USDKRW',
      market: 'FX',
      requiredSourceIds: ['korea-market-feed', 'polygon-massive', 'ibkr-client-portal'],
      whatToWatch: 'USDKRW spike, won liquidity stress, and whether FX confirms equity pressure.',
      riskOffTrigger: 'KRW weakens while Korea semis sell off, indicating foreign outflow / stress confirmation.',
      riskOnRepair: 'KRW stabilizes or strengthens while Korea equity stops making new lows.',
      affectedAssets: ['USDKRW', 'EWY', 'QQQ', 'NQ'],
      tradingRead: 'FX confirmation matters; equity-only dips can reverse, equity plus FX stress is harder to fade.',
    }),
    item({
      id: 'nq-futures',
      label: 'NQ futures',
      market: 'US premarket',
      requiredSourceIds: ['cme-nq-futures', 'databento', 'ibkr-client-portal'],
      whatToWatch: 'Whether NQ absorbs Asia weakness or breaks the overnight range / prior low.',
      riskOffTrigger: 'NQ loses overnight support while Korea memory tape stays weak.',
      riskOnRepair: 'NQ reclaims overnight VWAP/key trend line after Korea stops making new lows.',
      affectedAssets: ['NQ', 'QQQ', 'SMH', 'SOXX'],
      tradingRead: 'NQ is the transmission check from local Korea stress to US high-beta stress.',
    }),
    item({
      id: 'smh-soxx-premarket',
      label: 'SOXX / SMH premarket',
      market: 'US premarket',
      requiredSourceIds: ['semi-premarket-feed', 'nasdaq-totalview', 'databento', 'polygon-massive'],
      whatToWatch: 'Premarket gap, liquidity, recovery attempts, and whether ETFs break the prior low.',
      riskOffTrigger: 'SOXX/SMH fail every bounce and break prior low after Korea weakness.',
      riskOnRepair: 'ETF lower low fails, price reclaims key trend line, and put skew starts mean-reverting.',
      affectedAssets: ['SMH', 'SOXX', 'NVDA', 'AVGO', 'MU'],
      tradingRead: 'Do not use the first ETF dip as confirmation. Wait for structure.',
    }),
    item({
      id: 'mu-sndk-avgo-premarket',
      label: 'MU / SNDK / AVGO premarket',
      market: 'US premarket',
      requiredSourceIds: ['semi-premarket-feed', 'nasdaq-totalview', 'databento', 'polygon-massive'],
      whatToWatch: 'Memory sympathy in MU/SNDK and AI infrastructure read-through in AVGO.',
      riskOffTrigger: 'MU/SNDK gap down hard and AVGO joins instead of acting defensive.',
      riskOnRepair: 'MU/SNDK stabilize while AVGO/NVDA/SMH hold above premarket lows.',
      affectedAssets: ['MU', 'SNDK', 'AVGO', 'NVDA', 'SMH', 'SOXX'],
      tradingRead: 'If Korea is not collapsing, US semis can repair; if MU/SNDK/AVGO confirm, pressure is real.',
    }),
    item({
      id: 'put-skew-reversion',
      label: 'Put skew / options stress',
      market: 'Options',
      requiredSourceIds: ['opra-options-feed'],
      whatToWatch: 'SMH/SOXX put skew, sweep pressure, IV jump, and whether skew starts mean-reverting.',
      riskOffTrigger: 'Put skew steepens while ETF price keeps making lower lows.',
      riskOnRepair: 'Put skew mean-reverts while price stops breaking down.',
      affectedAssets: ['SMH', 'SOXX', 'QQQ', 'NQ'],
      tradingRead: 'For dip buys, skew repair is better confirmation than a single green candle.',
    }),
  ];
}

function buildTacticalPlaybook(): TacticalPlaybookRule[] {
  return [
    {
      id: 'do-not-watch-us-only',
      side: 'neutral',
      title: 'Monday premarket: do not stare only at US quotes',
      trigger: 'Korea opens before US premarket gives a clean semiconductor read.',
      confirmation: [
        'Track SK Hynix, Samsung, KOSPI/KOSDAQ, KRW, NQ futures, SOXX/SMH premarket, MU/SNDK/AVGO premarket.',
        'If Korea does not collapse, US semis may repair into the US session.',
        'If Korea opens directly into liquidation and Hynix/Samsung cannot hold, MU/SNDK/SMH/SOXX/NQ likely face pressure.',
      ],
      avoid: ['Do not treat a delayed US quote page as the primary signal.', 'Do not call a bottom before Korea stops making new lows.'],
      structures: ['Watchlist mode', 'Hedge review', 'No new leverage until confirmation'],
    },
    {
      id: 'semi-dip-buy-confirmation',
      side: 'dip_buy',
      title: 'If buying the semiconductor dip, do not rush the first wave',
      trigger: 'Only consider dip-buying after the first forced-selling wave has been tested.',
      confirmation: [
        'Korea does not print a second-leg liquidation.',
        'US semiconductors do not break the prior low.',
        'Put skew starts mean-reverting.',
        'NQ/SMH reclaim the key trend line or overnight VWAP.',
      ],
      avoid: ['Avoid catching the first red candle.', 'Avoid adding leverage while Korea, FX, and NQ are all confirming risk-off.'],
      structures: ['Small starter only after confirmation', 'Defined-risk call spread if IV is elevated', 'Wait for reclaim instead of guessing the low'],
    },
    {
      id: 'semi-short-structure',
      side: 'short',
      title: 'If shorting, do not chase the low',
      trigger: 'Wait for key market structure to break after the initial flush.',
      confirmation: [
        'Hynix/Samsung remain weak after the open.',
        'SMH/SOXX or NQ break prior low / overnight support.',
        'Put skew remains bid instead of mean-reverting.',
      ],
      avoid: [
        'Avoid naked all-in puts after IV already exploded.',
        'Avoid shorting after a vertical move without a failed rebound.',
        'Remember: gap-down plus reversal plus IV crush can kill naked puts even if the thesis is directionally right.',
      ],
      structures: ['Put spread', 'Bear call spread', 'Small SMH/SOXX put spread', 'Wait for rebound to short if first wave is already extended'],
    },
  ];
}

export function getAlertDeliveryConfig(): AlertDeliveryConfig {
  const telegramConfigured = Boolean(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID);
  const webhookConfigured = Boolean(process.env.GLOBAL_SIGNAL_ALERT_WEBHOOK_URL);
  const enabled = process.env.GLOBAL_SIGNAL_ALERTS_ENABLED === 'true';
  const minLevel = parseAlertLevel(process.env.GLOBAL_SIGNAL_ALERT_MIN_LEVEL || 'ORANGE');
  const minScore = clamp(Number(process.env.GLOBAL_SIGNAL_ALERT_MIN_SCORE || 70), 0, 100);
  const cooldownMinutes = Math.max(1, Number(process.env.GLOBAL_SIGNAL_ALERT_COOLDOWN_MINUTES || 30));
  const missingEnv: string[] = [];

  if (!telegramConfigured && !webhookConfigured) {
    missingEnv.push('TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID or GLOBAL_SIGNAL_ALERT_WEBHOOK_URL');
  }
  if (!enabled) missingEnv.push('GLOBAL_SIGNAL_ALERTS_ENABLED=true');

  return {
    enabled,
    minLevel,
    minScore,
    cooldownMinutes,
    telegramConfigured,
    webhookConfigured,
    redisCooldownConfigured: Boolean(process.env.REDIS_URL),
    cronPath: '/api/cron/global-signal-alerts',
    deliveryTargets: [
      ...(telegramConfigured ? ['telegram'] : []),
      ...(webhookConfigured ? ['webhook'] : []),
    ],
    missingEnv,
  };
}

function mapAffectedAssets(anchor: string, eventType: string, tickers: string[] = []): string[] {
  const base = new Set([anchor, ...tickers].filter(Boolean));
  if (['META', 'MSFT', 'GOOGL', 'AMZN', 'ORCL'].includes(anchor) || eventType.includes('Financing')) {
    ['QQQ', 'NVDA', 'AVGO', 'SOXX', 'AI_INFRA'].forEach((asset) => base.add(asset));
  }
  if (['NVDA', 'AVGO', 'MU', 'AMD', 'MRVL', 'ARM'].includes(anchor)) {
    ['SOXX', 'SMH', 'QQQ', 'NQ'].forEach((asset) => base.add(asset));
  }
  if (eventType.includes('Macro')) {
    ['SPY', 'QQQ', 'NQ', 'US2Y', 'US10Y', 'DXY', 'VIX'].forEach((asset) => base.add(asset));
  }
  return Array.from(base).slice(0, 12);
}

function mapPublicAffectedAssets(text: string, universe: string[]): string[] {
  const lower = text.toLowerCase();
  const assets = new Set<string>();
  for (const ticker of universe) {
    if (ticker.length >= 2 && lower.includes(ticker.toLowerCase())) assets.add(ticker);
  }
  if (containsAny(lower, ['fed', 'fomc', 'interest rate', 'inflation', 'payroll', 'cpi', 'pce', 'gdp'])) {
    ['QQQ', 'SPY', 'NQ', 'US2Y', 'US10Y', 'DXY', 'VIX'].forEach((asset) => assets.add(asset));
  }
  if (containsAny(lower, ['semiconductor', 'chip', 'nvidia', 'export control', 'entity list', 'hynix', 'samsung'])) {
    ['NVDA', 'AVGO', 'MU', 'AMD', 'SMH', 'SOXX', 'QQQ', 'NQ'].forEach((asset) => assets.add(asset));
  }
  if (containsAny(lower, ['iran', 'sanction', 'nuclear', 'red sea', 'houthi', 'military'])) {
    ['DXY', 'USO', 'XLE', 'GLD', 'NQ', 'QQQ', 'VIX'].forEach((asset) => assets.add(asset));
  }
  if (containsAny(lower, ['oil', 'crude', 'opec', 'natural gas', 'lng'])) {
    ['USO', 'XLE', 'XOM', 'CVX', 'DAL', 'UAL', 'XLY'].forEach((asset) => assets.add(asset));
  }
  if (containsAny(lower, ['tariff', 'trade representative', 'section 301', 'section 232'])) {
    ['FXI', 'KWEB', 'SMH', 'SOXX', 'XLI', 'XRT', 'DXY'].forEach((asset) => assets.add(asset));
  }
  if (!assets.size) ['SPY', 'QQQ'].forEach((asset) => assets.add(asset));
  return Array.from(assets).slice(0, 12);
}

function normalizeUniverse(universe: string[]): string[] {
  return Array.from(
    new Set(
      universe
        .map((ticker) => ticker.replace(/^\$/, '').trim().toUpperCase())
        .filter((ticker) => /^[A-Z0-9._-]{1,12}$/.test(ticker))
    )
  ).slice(0, 80);
}

function parseConfiguredFeeds(value?: string): string[] {
  if (!value) return [];
  return value
    .split(/[\n,;]+/)
    .map((url) => url.trim())
    .filter((url) => /^https:\/\//i.test(url));
}

function parseRssItems(xml: string): RssItem[] {
  const itemBlocks = [...xml.matchAll(/<item\b[\s\S]*?<\/item>/gi)].map((match) => match[0]);
  const atomBlocks = itemBlocks.length ? [] : [...xml.matchAll(/<entry\b[\s\S]*?<\/entry>/gi)].map((match) => match[0]);
  return (itemBlocks.length ? itemBlocks : atomBlocks)
    .map((block) => {
      const title = xmlValue(block, 'title');
      const summary = xmlValue(block, 'description') || xmlValue(block, 'summary') || xmlValue(block, 'content');
      const link = xmlValue(block, 'link') || xmlLinkHref(block);
      const date = xmlValue(block, 'pubDate') || xmlValue(block, 'updated') || xmlValue(block, 'published') || xmlValue(block, 'dc:date');
      const parsedDate = new Date(date);
      return {
        title: decodeXml(stripHtml(title || 'Public feed item')).slice(0, 240),
        summary: decodeXml(stripHtml(summary || title || '')).slice(0, 600),
        url: decodeXml(link || ''),
        publishedAt: Number.isNaN(parsedDate.getTime()) ? new Date().toISOString() : parsedDate.toISOString(),
      };
    })
    .filter((item) => item.title);
}

function xmlValue(block: string, tag: string): string {
  const escaped = tag.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = block.match(new RegExp(`<${escaped}\\b[^>]*>([\\s\\S]*?)<\\/${escaped}>`, 'i'));
  return match?.[1]?.replace(/^<!\[CDATA\[/, '').replace(/\]\]>$/, '').trim() || '';
}

function xmlLinkHref(block: string): string {
  const match = block.match(/<link\b[^>]*href=["']([^"']+)["'][^>]*>/i);
  return match?.[1] || '';
}

function decodeXml(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)));
}

function isRecentPublicItem(item: Pick<RssItem, 'publishedAt'>): boolean {
  const published = new Date(item.publishedAt).getTime();
  if (!Number.isFinite(published)) return false;
  return Date.now() - published <= 1000 * 60 * 60 * 24 * 14;
}

function dedupeEvents(events: GlobalSignalEvent[]): GlobalSignalEvent[] {
  const seen = new Set<string>();
  return events.filter((event) => {
    const key = `${event.sourceId}:${event.title.toLowerCase()}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function safeHost(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return 'configured feed';
  }
}

function buildProviderWarnings(sources: ProfessionalProvider[]): string[] {
  const warnings: string[] = [];
  if (!sources.some((source) => source.id === 'benzinga-news-api' && source.status === 'ready')) {
    warnings.push('BENZINGA_API_KEY missing: realtime professional headline adapter is not active.');
  }
  if (!sources.some((source) => source.id === 'opra-options-feed' && source.status === 'ready')) {
    warnings.push('OPRA options feed missing: options stress score cannot be trusted for live intraday alerts.');
  }
  if (!sources.some((source) => source.id === 'trading-economics' && source.status === 'ready')) {
    warnings.push('Macro consensus feed missing: NFP/CPI surprise scoring needs Trading Economics or Econoday.');
  }
  if (!sources.some((source) => source.id === 'ibkr-client-portal' && source.configured)) {
    warnings.push('IBKR not configured: execution, margin, and broker-side account risk are not connected.');
  }
  if (!sources.some((source) => source.id === 'korea-market-feed' && source.status === 'ready')) {
    warnings.push('Korea market feed missing: SK Hynix/Samsung/KOSPI/KRW lead-lag checklist is not live yet.');
  }
  if (!sources.some((source) => source.id === 'semi-premarket-feed' && source.status === 'ready')) {
    warnings.push('US semiconductor premarket feed missing: MU/SNDK/AVGO/SMH/SOXX confirmation is not live yet.');
  }
  return warnings;
}

function providerFailure(sourceId: string, err: unknown): GlobalSignalEvent[] {
  console.warn(`[global-signals/${sourceId}] ${err instanceof Error ? err.message : String(err)}`);
  return [];
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(url, { ...init, cache: 'no-store', signal: controller.signal });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchText(url: string, init?: RequestInit): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(url, { ...init, cache: 'no-store', signal: controller.signal });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return await res.text();
  } finally {
    clearTimeout(timeout);
  }
}

function containsAny(text: string, needles: string[]): boolean {
  return needles.some((needle) => text.includes(needle));
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

function parseBenzingaDate(value?: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function secAcceptanceToIso(value: string): string {
  if (/^\d{14}$/.test(value)) {
    return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(
      10,
      12
    )}:${value.slice(12, 14)}-04:00`;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? new Date().toISOString() : date.toISOString();
}

function latencyMs(publishedAt: string): number | null {
  const t = new Date(publishedAt).getTime();
  if (!Number.isFinite(t)) return null;
  return Math.max(0, Date.now() - t);
}

function alertLevel(score: number): AlertLevel {
  if (score >= 85) return 'RED';
  if (score >= 70) return 'ORANGE';
  if (score >= 50) return 'YELLOW';
  if (score >= 30) return 'LIGHT_YELLOW';
  return 'GREEN';
}

function parseAlertLevel(value: string): AlertLevel {
  const normalized = value.trim().toUpperCase();
  if (normalized === 'RED' || normalized === 'ORANGE' || normalized === 'YELLOW' || normalized === 'LIGHT_YELLOW' || normalized === 'GREEN') {
    return normalized;
  }
  return 'ORANGE';
}

function regimeForScores(score: number, macro: number, leverage: number, megaCap: number): string {
  if (score < 30) return 'Normal monitoring';
  if (score >= 85 && leverage >= 80) return 'Forced deleveraging risk';
  if (macro >= 80) return 'Hawkish macro shock';
  if (megaCap >= 75) return 'Mega-cap event stress';
  if (score >= 50) return 'Elevated risk watch';
  return 'Normal monitoring';
}

function actionForLevel(level: AlertLevel): string {
  const actions: Record<AlertLevel, string> = {
    GREEN: 'Normal monitoring. Keep position sizing rules intact.',
    LIGHT_YELLOW: 'Avoid chasing crowded high-beta names; wait for confirmation.',
    YELLOW: 'Reduce leverage and avoid first-leg dip buying in semis/AI beta.',
    ORANGE: 'Use protective structures only; hedge QQQ/SOXX/NQ exposure if already long.',
    RED: 'Stop adding leverage, protect capital first, and wait for volatility/yields to stabilize.',
  };
  return actions[level];
}

function roundScore(value: number): number {
  return Math.round(clamp(value));
}

function clamp(value: number, min = 0, max = 100): number {
  return Math.min(max, Math.max(min, value));
}

function stableId(input: string): string {
  let hash = 0;
  for (let i = 0; i < input.length; i += 1) {
    hash = (hash * 31 + input.charCodeAt(i)) >>> 0;
  }
  return hash.toString(36);
}
