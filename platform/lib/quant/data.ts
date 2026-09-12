// 量化数据层 / Thin data-fetch layer for the QUANT module.
// 直接打 Yahoo chart 端点拿 dates + closes + volumes（market-intelligence 里那个会丢掉 dates/volumes）。
// 同时提供基本面快照（trailingPE / profitMargin），用于价值/质量因子。
// Yahoo 的基本面端点经常返回 401 — 这里直接 graceful fallback 到 null，不抛错。

const YAHOO_HEADERS: HeadersInit = {
  accept: 'application/json',
  'user-agent':
    'Mozilla/5.0 (compatible; AXIO7-quant/1.0; +https://axio7.com)',
};

export type QuantSeries = {
  symbol: string;
  /** 开盘价，与 closes 对齐。Yahoo 缺这根的 open 时回落到该根的 close，
   *  这样保留哪些 bar 的判定不变 —— 既有的因子/回测口径不受影响。 */
  opens: number[];
  highs: number[];
  lows: number[];
  closes: number[];
  volumes: number[];
  dates: string[]; // ISO yyyy-mm-dd, aligned with closes
  asOf: string | null;
  currentPrice: number | null;
  source: 'Yahoo Finance';
};

export async function fetchQuantSeries(
  symbol: string,
  range: '6mo' | '1y' | '2y' | '5y' = '2y'
): Promise<QuantSeries> {
  const url =
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}` +
    `?interval=1d&range=${range}&includePrePost=false`;

  const res = await fetch(url, { headers: YAHOO_HEADERS, cache: 'no-store' });
  if (!res.ok) {
    throw new Error(`Yahoo chart failed for ${symbol}: HTTP ${res.status}`);
  }
  const data = (await res.json()) as YahooChartResponse;
  const root = data?.chart?.result?.[0];
  if (!root) {
    throw new Error(
      data?.chart?.error?.description || `Yahoo returned no data for ${symbol}`
    );
  }
  const q = root.indicators?.quote?.[0];
  const opensRaw = q?.open || [];
  const highsRaw = q?.high || [];
  const lowsRaw = q?.low || [];
  const closesRaw = q?.close || [];
  const volumesRaw = q?.volume || [];
  const timestamps = root.timestamp || [];

  const opens: number[] = [];
  const highs: number[] = [];
  const lows: number[] = [];
  const closes: number[] = [];
  const volumes: number[] = [];
  const dates: string[] = [];
  for (let i = 0; i < closesRaw.length; i += 1) {
    const h = highsRaw[i];
    const l = lowsRaw[i];
    const c = closesRaw[i];
    const t = timestamps[i];
    if (
      typeof h === 'number' &&
      Number.isFinite(h) &&
      typeof l === 'number' &&
      Number.isFinite(l) &&
      typeof c === 'number' &&
      Number.isFinite(c) &&
      t
    ) {
      const o = opensRaw[i];
      opens.push(typeof o === 'number' && Number.isFinite(o) ? o : c);
      highs.push(h);
      lows.push(l);
      closes.push(c);
      volumes.push(typeof volumesRaw[i] === 'number' ? (volumesRaw[i] as number) : 0);
      dates.push(new Date(t * 1000).toISOString().slice(0, 10));
    }
  }

  return {
    symbol,
    opens,
    highs,
    lows,
    closes,
    volumes,
    dates,
    asOf:
      typeof root.meta?.regularMarketTime === 'number'
        ? new Date(root.meta.regularMarketTime * 1000).toISOString()
        : null,
    currentPrice:
      typeof root.meta?.regularMarketPrice === 'number'
        ? root.meta.regularMarketPrice
        : closes.at(-1) ?? null,
    source: 'Yahoo Finance',
  };
}

// ---- 基本面快照（价值/质量因子用） ----

export type FundamentalsSnapshot = {
  symbol: string;
  trailingPE: number | null;
  forwardPE: number | null;
  profitMargin: number | null;
  marketCap: number | null;
};

const EMPTY_FUNDAMENTALS = (symbol: string): FundamentalsSnapshot => ({
  symbol,
  trailingPE: null,
  forwardPE: null,
  profitMargin: null,
  marketCap: null,
});

// Yahoo 的 v7 quote 端点经常被限流 / 要求 cookie。
// 我们尽力一试，失败就 null（让上层把因子标成 'data 待接入'，不要因此让整个 scan 挂掉）。
export async function fetchQuantFundamentals(
  symbol: string
): Promise<FundamentalsSnapshot> {
  try {
    const url = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${encodeURIComponent(symbol)}`;
    const res = await fetch(url, { headers: YAHOO_HEADERS, cache: 'no-store' });
    if (!res.ok) return EMPTY_FUNDAMENTALS(symbol);
    const json = (await res.json()) as YahooQuoteResponse;
    const row = json?.quoteResponse?.result?.[0];
    if (!row) return EMPTY_FUNDAMENTALS(symbol);
    return {
      symbol,
      trailingPE:
        typeof row.trailingPE === 'number' && Number.isFinite(row.trailingPE)
          ? row.trailingPE
          : null,
      forwardPE:
        typeof row.forwardPE === 'number' && Number.isFinite(row.forwardPE) ? row.forwardPE : null,
      profitMargin: null, // v7 quote 没有 profitMargin；要等 v10 quoteSummary 接入
      marketCap:
        typeof row.marketCap === 'number' && Number.isFinite(row.marketCap) ? row.marketCap : null,
    };
  } catch {
    return EMPTY_FUNDAMENTALS(symbol);
  }
}

type YahooChartResponse = {
  chart?: {
    result?: Array<{
      meta?: {
        symbol?: string;
        regularMarketPrice?: number;
        regularMarketTime?: number;
      };
      timestamp?: number[];
      indicators?: {
        quote?: Array<{
          open?: Array<number | null>;
          close?: Array<number | null>;
          high?: Array<number | null>;
          low?: Array<number | null>;
          volume?: Array<number | null>;
        }>;
      };
    }>;
    error?: { description?: string };
  };
};

type YahooQuoteResponse = {
  quoteResponse?: {
    result?: Array<{
      symbol?: string;
      trailingPE?: number;
      forwardPE?: number;
      marketCap?: number;
    }>;
    error?: unknown;
  };
};
