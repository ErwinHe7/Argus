// Order-flow / Level-1+ data. Uses IBKR or Polygon last-trade + NBBO + aggregate.
// Yahoo can be used only by callers that explicitly allow retail fallback.

export type OrderFlowQuote = {
  bid?: number;
  ask?: number;
  bidSize?: number;
  askSize?: number;
  spread?: number;
  midpoint?: number;
};

export type OrderFlowTrade = {
  price: number;
  size: number;
  ts: string;
};

export type IntradayBar = {
  ts: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
};

export type OrderFlowReport = {
  ticker: string;
  spot: number;
  provider: 'ibkr' | 'polygon' | 'yahoo' | 'unavailable';
  previousClose?: number;
  dayVolume?: number;
  quote: OrderFlowQuote | null;
  lastTrades: OrderFlowTrade[];
  bars: IntradayBar[];
  vwap: number | null;
  buyPressurePct: number | null;
  notable: Array<{ ts: string; price: number; size: number; note: string }>;
  generatedAt: string;
  observationCutoff?: string | null;
  availabilityTime?: string | null;
  freshness?: {
    state:
      | 'realtime_snapshot'
      | 'outside_regular_session'
      | 'unsubscribed'
      | 'unavailable';
    ageSeconds: number | null;
    marketDataAvailability?: string;
    coverage: string;
    caveats: string[];
  };
};

export type OrderFlowOptions = {
  allowRetailFallback?: boolean;
};

export async function buildOrderFlowReport(ticker: string, options: OrderFlowOptions = {}): Promise<OrderFlowReport> {
  const sym = ticker.replace(/^\$/, '').toUpperCase();
  const allowRetailFallback = options.allowRetailFallback !== false;

  if (process.env.IBKR_MARKET_DATA_ENABLED === 'true' && process.env.IBKR_BASE_URL) {
    try {
      const { buildIbkrOrderFlowReport } = await import('./ibkr-client-portal');
      return await buildIbkrOrderFlowReport(sym);
    } catch (err) {
      console.warn('[orderflow/ibkr] failed:', err instanceof Error ? err.message : err);
    }
  }

  const polygonKey = process.env.POLYGON_API_KEY;
  if (polygonKey) {
    try {
      return await polygonReport(sym, polygonKey);
    } catch (err) {
      console.warn('[orderflow/polygon] failed:', err instanceof Error ? err.message : err);
    }
  }

  if (!allowRetailFallback) return unavailableReport(sym);

  try {
    return await yahooReport(sym);
  } catch (err) {
    console.warn('[orderflow/yahoo] failed:', err instanceof Error ? err.message : err);
    return unavailableReport(sym);
  }
}

async function polygonReport(ticker: string, apiKey: string): Promise<OrderFlowReport> {
  const [snap, tradesData] = await Promise.all([
    fetchJson<{
      ticker?: {
        day?: { v?: number; o?: number; h?: number; l?: number; c?: number; vw?: number };
        lastQuote?: { p?: number; P?: number; s?: number; S?: number; t?: number };
        lastTrade?: { p?: number; s?: number; t?: number };
        prevDay?: { c?: number };
      };
    }>(
      `https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers/${encodeURIComponent(ticker)}?apiKey=${apiKey}`
    ).catch(() => ({} as any)),
    fetchJson<{
      results?: Array<{ p?: number; s?: number; t?: number }>;
    }>(
      `https://api.polygon.io/v3/trades/${encodeURIComponent(ticker)}?limit=50&order=desc&apiKey=${apiKey}`
    ).catch(() => ({ results: [] })),
  ]);

  const snapTicker = snap?.ticker;
  const quote = snapTicker?.lastQuote
    ? {
        bid: snapTicker.lastQuote.p,
        ask: snapTicker.lastQuote.P,
        bidSize: snapTicker.lastQuote.s,
        askSize: snapTicker.lastQuote.S,
        spread:
          snapTicker.lastQuote.P && snapTicker.lastQuote.p
            ? snapTicker.lastQuote.P - snapTicker.lastQuote.p
            : undefined,
        midpoint:
          snapTicker.lastQuote.P && snapTicker.lastQuote.p
            ? (snapTicker.lastQuote.P + snapTicker.lastQuote.p) / 2
            : undefined,
      }
    : null;

  const trades = (tradesData.results || [])
    .filter((t) => typeof t.p === 'number' && typeof t.s === 'number')
    .map((t) => ({
      price: t.p!,
      size: t.s!,
      ts: t.t ? new Date(t.t / 1_000_000).toISOString() : new Date().toISOString(),
    }));

  const spot = snapTicker?.lastTrade?.p || snapTicker?.day?.c || 0;
  const vwap = snapTicker?.day?.vw || null;

  const buyish = trades.filter((t) => quote?.midpoint && t.price >= quote.midpoint).length;
  const buyPressurePct = trades.length ? Math.round((buyish / trades.length) * 100) : null;

  const notable = trades
    .filter((t) => t.size >= 1000)
    .slice(0, 10)
    .map((t) => ({
      ts: t.ts,
      price: t.price,
      size: t.size,
      note: t.size >= 10_000 ? 'block-size print' : 'large print',
    }));

  return {
    ticker,
    spot,
    provider: 'polygon',
    previousClose: snapTicker?.prevDay?.c,
    dayVolume: snapTicker?.day?.v,
    quote,
    lastTrades: trades.slice(0, 20),
    bars: [],
    vwap,
    buyPressurePct,
    notable,
    generatedAt: new Date().toISOString(),
  };
}

async function yahooReport(ticker: string): Promise<OrderFlowReport> {
  const url = `https://query2.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}?interval=1m&range=1d`;
  const data = await fetchJson<{
    chart?: {
      result?: Array<{
        meta?: { regularMarketPrice?: number; previousClose?: number };
        timestamp?: number[];
        indicators?: {
          quote?: Array<{ open?: number[]; high?: number[]; low?: number[]; close?: number[]; volume?: number[] }>;
        };
      }>;
    };
  }>(url, {
    headers: { Accept: 'application/json', 'User-Agent': process.env.YAHOO_USER_AGENT || 'AXIO7-MarketIntel/1.0' },
  });

  const root = data.chart?.result?.[0];
  const meta = root?.meta;
  const ts = root?.timestamp || [];
  const q = root?.indicators?.quote?.[0];
  const bars: IntradayBar[] = ts
    .map((t, i) => ({
      ts: new Date(t * 1000).toISOString(),
      open: q?.open?.[i] || 0,
      high: q?.high?.[i] || 0,
      low: q?.low?.[i] || 0,
      close: q?.close?.[i] || 0,
      volume: q?.volume?.[i] || 0,
    }))
    .filter((b) => b.close > 0);

  let pv = 0;
  let totalVol = 0;
  for (const b of bars) {
    pv += b.close * b.volume;
    totalVol += b.volume;
  }
  const vwap = totalVol > 0 ? pv / totalVol : null;

  return {
    ticker,
    spot: meta?.regularMarketPrice || bars.at(-1)?.close || 0,
    provider: 'yahoo',
    previousClose: meta?.previousClose,
    dayVolume: bars.reduce((sum, bar) => sum + bar.volume, 0),
    quote: null,
    lastTrades: [],
    bars: bars.slice(-90),
    vwap,
    buyPressurePct: null,
    notable: bars
      .filter((b) => b.volume > avgVolume(bars) * 4)
      .slice(-5)
      .map((b) => ({ ts: b.ts, price: b.close, size: b.volume, note: 'volume spike vs intraday average' })),
    generatedAt: new Date().toISOString(),
  };
}

function unavailableReport(ticker: string): OrderFlowReport {
  return {
    ticker,
    spot: 0,
    provider: 'unavailable',
    quote: null,
    lastTrades: [],
    bars: [],
    vwap: null,
    buyPressurePct: null,
    notable: [],
    generatedAt: new Date().toISOString(),
  };
}

function avgVolume(bars: IntradayBar[]): number {
  if (!bars.length) return 0;
  return bars.reduce((s, b) => s + b.volume, 0) / bars.length;
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(url, { ...init, cache: 'no-store', signal: controller.signal });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(t);
  }
}
