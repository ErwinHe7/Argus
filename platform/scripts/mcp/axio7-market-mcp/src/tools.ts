// All MCP tools for AXIO7 Market Intelligence.
//
// Design rules:
//   1. Every tool wraps an existing AXIO7 HTTP endpoint — no new logic here.
//   2. Read-only by default. Only `ingest_manual_event` is write, scoped to
//      "user paste an X / Truth / Reuters / SEC URL", which is already public.
//   3. No live broker execution exposed via MCP. To run a real order, the
//      human must go to the AXIO7 web UI and confirm per-trade.
//   4. Every result returns evidence-rich JSON (sources, timestamps, URLs).
//
// Schema notes: zod is bundled but we surface JSON Schema directly here so
// the MCP server can advertise tools without an extra conversion step.

import { axio7Fetch, getBaseUrl } from './client.js';

export type McpTool = {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
  handler: (args: Record<string, unknown>) => Promise<unknown>;
};

function asString(v: unknown, fallback = ''): string {
  return typeof v === 'string' ? v : fallback;
}

function asStringArray(v: unknown): string[] {
  if (Array.isArray(v)) return v.filter((x) => typeof x === 'string') as string[];
  if (typeof v === 'string') return v.split(/[,\s]+/).filter(Boolean);
  return [];
}

function nextFridayISO(): string {
  const d = new Date();
  const dow = d.getUTCDay();
  const add = (5 - dow + 7) % 7 || 7;
  d.setUTCDate(d.getUTCDate() + add);
  return d.toISOString().slice(0, 10);
}

function upperTicker(v: unknown): string {
  const s = asString(v).replace(/^\$/, '').trim().toUpperCase();
  if (!/^[A-Z][A-Z0-9.]{0,5}$/.test(s)) {
    throw new Error(`invalid ticker: ${JSON.stringify(v)}`);
  }
  return s;
}

// 1. search_market_news ───────────────────────────────────────────────────────
const searchMarketNews: McpTool = {
  name: 'search_market_news',
  description:
    'Search AXIO7 for market-moving events across the 10 wired sources (Reuters/LSEG, X, Truth vendor, SEC EDGAR, Finnhub, NewsAPI, Polygon, Reddit, market tape, options flow). Returns ranked events with source tier, sentiment, materiality, confidence, affected tickers, and evidence URLs. Use this whenever the user asks "what news is moving X" or "what happened to NVDA today".',
  inputSchema: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'Free-text query, e.g. "tariff" or "NVDA China export". Optional.',
      },
      watchlist: {
        type: 'array',
        items: { type: 'string' },
        description: 'Tickers to focus on. e.g. ["NVDA","AMD","TSLA"].',
      },
      horizon: {
        type: 'string',
        enum: ['intraday', 'swing', 'long_term'],
        default: 'swing',
      },
    },
    additionalProperties: false,
  },
  async handler(args) {
    const body = {
      query: asString(args.query),
      watchlist: asStringArray(args.watchlist),
      horizon: asString(args.horizon, 'swing'),
      mode: 'paper',
    };
    const res = await axio7Fetch<unknown>('POST', '/api/market/research', { body });
    if (!res.ok) throw new Error(`search_market_news failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 2. get_market_signals ───────────────────────────────────────────────────────
const getMarketSignals: McpTool = {
  name: 'get_market_signals',
  description:
    'Macro/breadth dashboard: VIX, CNN Fear & Greed, indices (SPX/NDX/RUT/DJI), sector ETFs, theme ETFs, and a composite "bottom signal" score 0..maxScore with a stance label. Use for "how is the broad market" or "is the market oversold".',
  inputSchema: {
    type: 'object',
    properties: {
      watchlist: {
        type: 'array',
        items: { type: 'string' },
        description: 'Optional watchlist of tickers to enrich the dashboard. Pass [] for index-only view.',
      },
    },
    additionalProperties: false,
  },
  async handler(args) {
    const watchlist = asStringArray(args.watchlist);
    const query: Record<string, string | number | undefined> = {};
    if (watchlist.length) query.watchlist = watchlist.join(',');
    const res = await axio7Fetch<unknown>('GET', '/api/market/signals', { query });
    if (!res.ok) throw new Error(`get_market_signals failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 3. get_ticker_brief ─────────────────────────────────────────────────────────
const getTickerBrief: McpTool = {
  name: 'get_ticker_brief',
  description:
    'Full per-ticker dashboard: latest price/volume/RSI/SMA/52w; news catalysts for the ticker; SEC Form 4 insider activity; macro context excerpt; options summary (provider, max pain, top OI, IV, P(close>spot)); lognormal price distribution for this week (oneSigmaLow/High, expected move, levels with prob-above); and model strategy candidates with legs, breakevens, max P/L, invalidation. Use whenever the user picks a specific stock to analyze.',
  inputSchema: {
    type: 'object',
    properties: {
      ticker: { type: 'string', description: 'e.g. NVDA, MU, RKLB. Required.' },
    },
    required: ['ticker'],
    additionalProperties: false,
  },
  async handler(args) {
    const ticker = upperTicker(args.ticker);
    const res = await axio7Fetch<unknown>('GET', `/api/market/ticker/${encodeURIComponent(ticker)}`);
    if (!res.ok) throw new Error(`get_ticker_brief failed for ${ticker}: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 4. get_options_chain ────────────────────────────────────────────────────────
const getOptionsChain: McpTool = {
  name: 'get_options_chain',
  description:
    'Options chain analytics for a ticker + expiration. Returns: spot, provider (polygon/yahoo/ibkr), top 10 OI overall, top 10 calls separately, top 10 puts separately, max pain strike + distance from spot, gamma exposure (call/put GEX, zero-gamma strike, interpretation), squeeze assessment (gamma_squeeze_likely / dealer_pin_likely / put_unwind_likely / mixed) with rationale, and flow pressure (call/put OI %, call/put volume %, bid/ask quality, interpretation). If expiration omitted, uses next Friday.',
  inputSchema: {
    type: 'object',
    properties: {
      ticker: { type: 'string', description: 'e.g. NVDA. Required.' },
      expiration: {
        type: 'string',
        description: 'YYYY-MM-DD. If omitted, uses next Friday.',
      },
    },
    required: ['ticker'],
    additionalProperties: false,
  },
  async handler(args) {
    const ticker = upperTicker(args.ticker);
    const expiration = asString(args.expiration) || nextFridayISO();
    const res = await axio7Fetch<unknown>('GET', '/api/market/options', {
      query: { ticker, expiration },
    });
    if (!res.ok) throw new Error(`get_options_chain failed for ${ticker} ${expiration}: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 5. get_max_pain_and_walls ───────────────────────────────────────────────────
const getMaxPainAndWalls: McpTool = {
  name: 'get_max_pain_and_walls',
  description:
    'Convenience tool that calls the options endpoint and projects only: maxPain strike + distance from spot, top call wall (highest call OI strike), top put wall (highest put OI strike), and the squeeze regime. Use when the user asks "what is the max pain" or "where will it pin this week".',
  inputSchema: {
    type: 'object',
    properties: {
      ticker: { type: 'string' },
      expiration: { type: 'string' },
    },
    required: ['ticker'],
    additionalProperties: false,
  },
  async handler(args) {
    const ticker = upperTicker(args.ticker);
    const expiration = asString(args.expiration) || nextFridayISO();
    const res = await axio7Fetch<{
      spot?: number;
      provider?: string;
      maxPain?: { maxPainStrike: number; totalPainAtMax: number; distanceFromSpotPct: number };
      topCalls?: Array<{ rank: number; strike: number; openInterest: number; volume: number }>;
      topPuts?: Array<{ rank: number; strike: number; openInterest: number; volume: number }>;
      squeezeAssessment?: { scenario: string; rationale: string[] };
      flowPressure?: { callPutOiRatio: number; callPutVolumeRatio: number; interpretation: string };
    }>('GET', '/api/market/options', { query: { ticker, expiration } });
    if (!res.ok) throw new Error(`get_max_pain_and_walls failed: ${res.status} ${res.error}`);
    const d = res.data;
    return {
      ticker,
      expiration,
      provider: d.provider,
      spot: d.spot,
      maxPain: d.maxPain
        ? {
            strike: d.maxPain.maxPainStrike,
            distanceFromSpotPct: d.maxPain.distanceFromSpotPct,
            totalPainAtMax: d.maxPain.totalPainAtMax,
          }
        : null,
      callWall: d.topCalls?.[0]
        ? {
            strike: d.topCalls[0].strike,
            openInterest: d.topCalls[0].openInterest,
            volume: d.topCalls[0].volume,
          }
        : null,
      putWall: d.topPuts?.[0]
        ? {
            strike: d.topPuts[0].strike,
            openInterest: d.topPuts[0].openInterest,
            volume: d.topPuts[0].volume,
          }
        : null,
      squeeze: d.squeezeAssessment?.scenario,
      squeezeRationale: d.squeezeAssessment?.rationale,
      flow: d.flowPressure,
    };
  },
};

// 6. get_news_pulse ───────────────────────────────────────────────────────────
const getNewsPulse: McpTool = {
  name: 'get_news_pulse',
  description:
    'Free-tier news pulse: Hacker News front-page items that mention any ticker, plus GDELT global news index. No paid keys required. Use for a quick scan of what the broad financial/tech news cycle is reacting to.',
  inputSchema: {
    type: 'object',
    properties: {
      tickers: { type: 'array', items: { type: 'string' } },
    },
    additionalProperties: false,
  },
  async handler(args) {
    const tickers = asStringArray(args.tickers);
    const query: Record<string, string | number | undefined> = {};
    if (tickers.length) query.tickers = tickers.join(',');
    const res = await axio7Fetch<unknown>('GET', '/api/market/news-pulse', { query });
    if (!res.ok) throw new Error(`get_news_pulse failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 7. get_macro_panel ──────────────────────────────────────────────────────────
const getMacroPanel: McpTool = {
  name: 'get_macro_panel',
  description:
    'US macro snapshot from FRED: 10Y-2Y spread, Fed Funds rate, CPI, unemployment, M2, DXY, and a recession-signals digest. Use for "what is the macro setup" or to put a stock-specific catalyst into context.',
  inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  async handler() {
    const res = await axio7Fetch<unknown>('GET', '/api/market/macro');
    if (!res.ok) throw new Error(`get_macro_panel failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 8. get_insider_filings ──────────────────────────────────────────────────────
const getInsiderFilings: McpTool = {
  name: 'get_insider_filings',
  description:
    'SEC Form 4 insider filings count + latest filing per ticker, last ~90 days. Density/timing matters — clusters often precede catalysts. Use for "is there insider activity on NVDA" or "any unusual filings this week".',
  inputSchema: {
    type: 'object',
    properties: {
      tickers: {
        type: 'array',
        items: { type: 'string' },
        description: 'Optional. If empty, uses the default watchlist.',
      },
    },
    additionalProperties: false,
  },
  async handler(args) {
    const tickers = asStringArray(args.tickers);
    const query: Record<string, string | number | undefined> = {};
    if (tickers.length) query.tickers = tickers.join(',');
    const res = await axio7Fetch<unknown>('GET', '/api/market/insider', { query });
    if (!res.ok) throw new Error(`get_insider_filings failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 9. get_source_health ────────────────────────────────────────────────────────
const getSourceHealth: McpTool = {
  name: 'get_source_health',
  description:
    'Status of all 10+ data sources: which ones are live (have keys configured), which are in fixture/manual/disabled mode, X spending limit, and which influencer handles are being monitored. Use when the user asks "is data reliable" or before doing any time-sensitive analysis.',
  inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  async handler() {
    const res = await axio7Fetch<unknown>('GET', '/api/market/sources');
    if (!res.ok) throw new Error(`get_source_health failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

// 10. ingest_manual_event ─────────────────────────────────────────────────────
const ingestManualEvent: McpTool = {
  name: 'ingest_manual_event',
  description:
    'Paste an X tweet, Truth Social post, Reuters headline, official press release, or SEC filing URL/text. AXIO7 runs the full normalization pipeline: source-type weighting, ticker mapping, sentiment classification, materiality scoring, risk-flag detection, and a "next checks" list. Use whenever the user shows you a tweet or news snippet and asks "what does this mean for the stock". This is the only WRITE tool exposed via MCP, and the writes are intentionally limited to user-supplied public text.',
  inputSchema: {
    type: 'object',
    properties: {
      sourceType: {
        type: 'string',
        enum: ['x_manual', 'truth_manual', 'reuters_headline', 'press_release', 'sec_url', 'other'],
        default: 'other',
        description: 'Best guess for source category. Affects trust weighting.',
      },
      sourceUrl: { type: 'string', description: 'Original URL if known.' },
      text: { type: 'string', description: 'The pasted text. Required.' },
      tickersHint: {
        type: 'array',
        items: { type: 'string' },
        description: 'Optional ticker hints if you already know which symbols apply.',
      },
      publishedAt: {
        type: 'string',
        description: 'ISO timestamp of original publish. Defaults to now if omitted.',
      },
    },
    required: ['text'],
    additionalProperties: false,
  },
  async handler(args) {
    const body: Record<string, unknown> = {
      sourceType: asString(args.sourceType, 'other'),
      text: asString(args.text),
    };
    if (!body.text) throw new Error('ingest_manual_event requires non-empty text');
    if (args.sourceUrl) body.sourceUrl = asString(args.sourceUrl);
    const tickersHint = asStringArray(args.tickersHint);
    if (tickersHint.length) body.tickersHint = tickersHint;
    if (args.publishedAt) body.publishedAt = asString(args.publishedAt);
    const res = await axio7Fetch<unknown>('POST', '/api/market/events/manual', { body });
    if (!res.ok) throw new Error(`ingest_manual_event failed: ${res.status} ${res.error}`);
    return res.data;
  },
};

export const ALL_TOOLS: McpTool[] = [
  searchMarketNews,
  getMarketSignals,
  getTickerBrief,
  getOptionsChain,
  getMaxPainAndWalls,
  getNewsPulse,
  getMacroPanel,
  getInsiderFilings,
  getSourceHealth,
  ingestManualEvent,
];

export function describeBackend(): string {
  return `AXIO7 backend: ${getBaseUrl()}`;
}
