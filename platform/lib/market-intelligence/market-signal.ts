export type SignalStatus = 'bottom' | 'watch' | 'risk' | 'unavailable';

export type MarketSignalMetric = {
  id: string;
  group: 'sentiment' | 'technical';
  title: string;
  value: string;
  status: SignalStatus;
  label: string;
  description: string;
  threshold: string;
  source: string;
  sourceUrl: string;
  asOf?: string;
  isBottomSignal: boolean;
};

export type MarketSignalGroup = {
  id: 'sentiment' | 'technical';
  title: string;
  signalCount: number;
  total: number;
  metricIds: string[];
};

export type MarketSignalQuote = {
  symbol: string;
  name: string;
  price: number | null;
  previousClose: number | null;
  change: number | null;
  changePct: number | null;
  dayHigh: number | null;
  dayLow: number | null;
  volume: number | null;
  rsi14: number | null;
  sma20: number | null;
  sma50: number | null;
  sma200: number | null;
  deviation200Pct: number | null;
  change5dPct: number | null;
  change1mPct: number | null;
  provider: 'Yahoo Finance';
  sourceUrl: string;
  asOf: string | null;
  note: string;
};

export type ReliabilityState = 'ok' | 'partial' | 'unavailable';

export type MarketSignalReliability = {
  indices: ReliabilityState;
  watchlist: ReliabilityState;
  sectors: ReliabilityState;
  themes: ReliabilityState;
  sentiment: ReliabilityState;
};

export type MarketSignalReport = {
  generatedAt: string;
  score: number;
  maxScore: number;
  stance: string;
  headline: string;
  summary: string;
  reliability: MarketSignalReliability;
  indices: MarketSignalQuote[];
  metrics: MarketSignalMetric[];
  groups: MarketSignalGroup[];
  watchlist: MarketSignalQuote[];
  sectors: MarketSignalQuote[];
  themes: MarketSignalQuote[];
  errors: string[];
  sources: Array<{ name: string; url: string; status: ReliabilityState; note: string }>;
  disclaimer: string;
};

export type YahooSeries = MarketSignalQuote & {
  closes: number[];
};

type CnnFearGreed = {
  score: number;
  rating: string;
  timestamp: string;
  previousClose?: number;
};

const DEFAULT_TICKERS = [
  'NVDA', 'AMD', 'AVGO', 'MRVL', 'MU', 'TSM', 'ASML', 'ARM', 'INTC', 'QCOM',
  'SMCI', 'DELL', 'HPE', 'ANET', 'CLS', 'VRT', 'COHR', 'LITE', 'AAOI', 'TSEM',
  'SIVE', 'ORCL', 'MSFT', 'GOOGL', 'META', 'AMZN', 'PLTR', 'CRM', 'NOW', 'SNOW',
  'PANW', 'CRWD', 'DDOG', 'NET', 'CEG', 'VST', 'ETN', 'PWR', 'GEV', 'FLNC',
  'OKLO', 'SMR', 'APLD', 'IREN',
];

const INDEX_SYMBOLS = [
  { symbol: '^GSPC', name: 'S&P 500' },
  { symbol: '^IXIC', name: 'Nasdaq Composite' },
  { symbol: '^NDX', name: 'Nasdaq 100' },
  { symbol: '^DJI', name: 'Dow Jones' },
  { symbol: '^RUT', name: 'Russell 2000' },
  { symbol: '^SOX', name: 'PHLX Semiconductor' },
  { symbol: '^VIX', name: 'VIX' },
];

const SECTOR_SYMBOLS = [
  { symbol: 'XLK', name: 'Technology' },
  { symbol: 'XLC', name: 'Communication Services' },
  { symbol: 'XLY', name: 'Consumer Discretionary' },
  { symbol: 'XLF', name: 'Financials' },
  { symbol: 'XLI', name: 'Industrials' },
  { symbol: 'XLE', name: 'Energy' },
  { symbol: 'XLV', name: 'Healthcare' },
  { symbol: 'XLP', name: 'Consumer Staples' },
  { symbol: 'XLU', name: 'Utilities' },
  { symbol: 'XLRE', name: 'Real Estate' },
];

const THEME_SYMBOLS = [
  { symbol: 'SMH', name: 'Semiconductor ETF (SMH)' },
  { symbol: 'SOXX', name: 'Semiconductor ETF (SOXX)' },
  { symbol: 'IGV', name: 'Software ETF (IGV)' },
  { symbol: 'BOTZ', name: 'Robotics & AI (BOTZ)' },
  { symbol: 'AIQ', name: 'AI & Automation (AIQ)' },
  { symbol: 'IWM', name: 'Russell 2000 ETF (IWM)' },
  { symbol: 'RSP', name: 'Equal-Weight S&P 500 (RSP)' },
];

const YAHOO_HEADERS = {
  Accept: 'application/json',
  'User-Agent': process.env.YAHOO_USER_AGENT || 'AXIO7-MarketSignal/1.0',
};

const CNN_HEADERS = {
  Accept: 'application/json,text/plain,*/*',
  Referer: 'https://www.cnn.com/markets/fear-and-greed',
  Origin: 'https://www.cnn.com',
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36',
};

export async function buildMarketSignalReport(
  inputTickers: string[] = [],
  options: { useDefaultWatchlist?: boolean } = {}
): Promise<MarketSignalReport> {
  const generatedAt = new Date().toISOString();
  const tickers = cleanTickers(inputTickers).slice(0, 50);
  const watchSymbols = tickers.length ? tickers : options.useDefaultWatchlist ? DEFAULT_TICKERS : [];
  const errors: string[] = [];

  const [indexResults, watchResults, sectorResults, themeResults, fearGreed] = await Promise.all([
    Promise.allSettled(INDEX_SYMBOLS.map((item) => fetchYahooSeries(item.symbol, item.name))),
    Promise.allSettled(watchSymbols.map((symbol) => fetchYahooSeries(symbol, symbol))),
    Promise.allSettled(SECTOR_SYMBOLS.map((item) => fetchYahooSeries(item.symbol, item.name))),
    Promise.allSettled(THEME_SYMBOLS.map((item) => fetchYahooSeries(item.symbol, item.name))),
    fetchCnnFearGreed().catch((err) => {
      errors.push(`CNN Fear&Greed: ${err instanceof Error ? err.message : 'unavailable'}`);
      return null;
    }),
  ]);

  const indices = collectSeries(indexResults, INDEX_SYMBOLS, 'index', errors);
  const watchlist = collectSeries(
    watchResults,
    watchSymbols.map((symbol) => ({ symbol, name: symbol })),
    'watchlist',
    errors
  );
  const sectors = collectSeries(sectorResults, SECTOR_SYMBOLS, 'sector', errors);
  const themes = collectSeries(themeResults, THEME_SYMBOLS, 'theme', errors);

  const spx = indices.find((quote) => quote.symbol === '^GSPC') || null;
  const ndx = indices.find((quote) => quote.symbol === '^NDX') || null;
  const vix = indices.find((quote) => quote.symbol === '^VIX') || null;

  const metrics = [
    buildVixMetric(vix),
    buildFearGreedMetric(fearGreed),
    buildRsiMetric('spx-rsi', '标普500 日线 RSI', spx, '标普500'),
    buildRsiMetric('ndx-rsi', '纳斯达克100 日线 RSI', ndx, '纳指100'),
    buildDeviationMetric('spx-200dma', '标普500 距200日均线偏离', spx, '标普500'),
    buildDeviationMetric('ndx-200dma', '纳斯达克100 距200日均线偏离', ndx, '纳指100'),
  ];

  const groups: MarketSignalGroup[] = [
    buildGroup('sentiment', '情绪指标', metrics, ['vix', 'fear-greed']),
    buildGroup('technical', '技术指标', metrics, ['spx-rsi', 'ndx-rsi', 'spx-200dma', 'ndx-200dma']),
  ];
  const score = metrics.filter((metric) => metric.isBottomSignal).length;
  const maxScore = metrics.length;

  const reliability: MarketSignalReliability = {
    indices: reliabilityFromCounts(indices.length, INDEX_SYMBOLS.length),
    watchlist: watchSymbols.length ? reliabilityFromCounts(watchlist.length, watchSymbols.length) : 'ok',
    sectors: reliabilityFromCounts(sectors.length, SECTOR_SYMBOLS.length),
    themes: reliabilityFromCounts(themes.length, THEME_SYMBOLS.length),
    sentiment: fearGreed && vix?.price ? 'ok' : vix?.price || fearGreed ? 'partial' : 'unavailable',
  };

  return {
    generatedAt,
    score,
    maxScore,
    stance: stanceFromScore(score),
    headline: headlineFromSignals(score, vix, fearGreed),
    summary: buildSummary(score, spx, ndx, vix, fearGreed),
    reliability,
    indices: indices.map(publicQuote),
    metrics,
    groups,
    watchlist: watchlist.map(publicQuote),
    sectors: sectors.map(publicQuote),
    themes: themes.map(publicQuote),
    errors,
    sources: [
      {
        name: 'Yahoo Finance Chart API',
        url: 'https://finance.yahoo.com/',
        status: reliability.indices === 'ok' ? 'ok' : reliability.indices === 'unavailable' ? 'unavailable' : 'partial',
        note: watchSymbols.length
          ? '指数、ETF、用户指定 ticker 的价格、成交量、日线 RSI、均线偏离均由 Yahoo Finance chart 数据计算。'
          : 'Overview 只抓指数、行业和主题 ETF；单股报价与完整分析只在 /market/ticker/[symbol] 拉取。',
      },
      {
        name: 'CNN Business Fear & Greed',
        url: 'https://www.cnn.com/markets/fear-and-greed',
        status: fearGreed ? 'ok' : 'unavailable',
        note: fearGreed ? 'CNN 恐惧贪婪指数已获取。' : 'CNN 当前不可用，页面显示暂无可靠数据，不使用模拟值。',
      },
    ],
    disclaimer:
      '数据来自公开免费/公开可访问 API，可能为延迟行情，仅用于市场研究展示，不构成投资建议。无法获取的数据会显示“暂无可靠数据”，不会用模拟值补齐。',
  };
}

function collectSeries<T extends { symbol: string; name: string }>(
  results: PromiseSettledResult<YahooSeries>[],
  defs: T[],
  kind: string,
  errors: string[]
): YahooSeries[] {
  const out: YahooSeries[] = [];
  results.forEach((result, idx) => {
    if (result.status === 'fulfilled') {
      out.push(result.value);
    } else {
      const symbol = defs[idx]?.symbol || 'unknown';
      errors.push(`${kind} ${symbol}: ${result.reason instanceof Error ? result.reason.message : 'unavailable'}`);
    }
  });
  return out;
}

function reliabilityFromCounts(ok: number, total: number): ReliabilityState {
  if (total === 0) return 'unavailable';
  if (ok === 0) return 'unavailable';
  if (ok === total) return 'ok';
  return 'partial';
}

function buildVixMetric(vix: YahooSeries | null): MarketSignalMetric {
  if (!vix?.price) {
    return unavailableMetric(
      'vix',
      'sentiment',
      'VIX 恐慌指数',
      'Yahoo Finance',
      yahooUrl('^VIX'),
      '> 28 = 开始关注 · > 35 = 强底部信号'
    );
  }
  const value = vix.price;
  const status: SignalStatus = value >= 35 ? 'bottom' : value >= 28 ? 'watch' : 'risk';
  return {
    id: 'vix',
    group: 'sentiment',
    title: 'VIX 恐慌指数',
    value: value.toFixed(2),
    status,
    label: statusLabel(status),
    description:
      status === 'bottom'
        ? `VIX ${value.toFixed(1)}，恐慌显著升温，进入强底部观察区。`
        : status === 'watch'
          ? `VIX ${value.toFixed(1)}，波动开始放大，底部信号开始出现。`
          : `VIX ${value.toFixed(1)}，市场低波动偏平静，不是恐慌底部。`,
    threshold: '> 28 = 开始关注 · > 35 = 强底部信号',
    source: 'Yahoo Finance',
    sourceUrl: yahooUrl('^VIX'),
    asOf: vix.asOf || undefined,
    isBottomSignal: status === 'bottom',
  };
}

function buildFearGreedMetric(fearGreed: CnnFearGreed | null): MarketSignalMetric {
  if (!fearGreed) {
    return unavailableMetric(
      'fear-greed',
      'sentiment',
      'CNN 恐惧贪婪指数',
      'CNN Business',
      'https://www.cnn.com/markets/fear-and-greed',
      '< 30 = 开始关注 · < 20 = 强底部信号'
    );
  }
  const score = fearGreed.score;
  const status: SignalStatus = score <= 20 ? 'bottom' : score <= 30 ? 'watch' : 'risk';
  return {
    id: 'fear-greed',
    group: 'sentiment',
    title: 'CNN 恐惧贪婪指数',
    value: `${score.toFixed(0)} · ${fearGreed.rating}`,
    status,
    label: statusLabel(status),
    description:
      status === 'bottom'
        ? `Fear & Greed ${score.toFixed(0)}，市场进入极度恐惧区。`
        : status === 'watch'
          ? `Fear & Greed ${score.toFixed(0)}，市场情绪偏恐惧，开始进入观察区。`
          : `Fear & Greed ${score.toFixed(0)}，市场情绪不恐慌，抄底分数不加分。`,
    threshold: '< 30 = 开始关注 · < 20 = 强底部信号',
    source: 'CNN Business',
    sourceUrl: 'https://www.cnn.com/markets/fear-and-greed',
    asOf: fearGreed.timestamp,
    isBottomSignal: status === 'bottom',
  };
}

function buildRsiMetric(id: string, title: string, series: YahooSeries | null, label: string): MarketSignalMetric {
  if (!series || series.rsi14 === null) {
    return unavailableMetric(
      id,
      'technical',
      title,
      'Yahoo Finance',
      yahooUrl(series?.symbol || label),
      '< 35 = 底部信号 · < 45 = 开始关注'
    );
  }
  const rsi = series.rsi14;
  const status: SignalStatus = rsi <= 35 ? 'bottom' : rsi <= 45 ? 'watch' : 'risk';
  return {
    id,
    group: 'technical',
    title,
    value: `RSI ${rsi.toFixed(1)}`,
    status,
    label: statusLabel(status),
    description:
      status === 'bottom'
        ? `${label} 日线RSI ${rsi.toFixed(1)}，进入超卖底部信号区。`
        : status === 'watch'
          ? `${label} 日线RSI ${rsi.toFixed(1)}，动能转弱，开始关注。`
          : `${label} 日线RSI ${rsi.toFixed(1)}，动能未超卖，暂无底部信号。`,
    threshold: '< 35 = 底部信号 · < 45 = 开始关注',
    source: 'Yahoo Finance',
    sourceUrl: yahooUrl(series.symbol),
    asOf: series.asOf || undefined,
    isBottomSignal: status === 'bottom',
  };
}

function buildDeviationMetric(id: string, title: string, series: YahooSeries | null, label: string): MarketSignalMetric {
  if (!series || series.deviation200Pct === null || series.sma200 === null) {
    return unavailableMetric(
      id,
      'technical',
      title,
      'Yahoo Finance',
      yahooUrl(series?.symbol || label),
      '< -5% = 底部信号 · 0%~-5% = 开始关注'
    );
  }
  const deviation = series.deviation200Pct;
  const status: SignalStatus = deviation <= -5 ? 'bottom' : deviation <= 0 ? 'watch' : 'risk';
  return {
    id,
    group: 'technical',
    title,
    value: `${fmtSignedPct(deviation)}（均线 ${fmtNumber(series.sma200, 0)}）`,
    status,
    label: statusLabel(status),
    description:
      status === 'bottom'
        ? `${label} 低于200日均线 ${Math.abs(deviation).toFixed(1)}%，进入历史底部观察区。`
        : status === 'watch'
          ? `${label} 接近或略低于200日均线，开始进入技术观察区。`
          : `${label} 高于200日均线 ${deviation.toFixed(1)}%，距均线较远，暂无底部信号。`,
    threshold: '< -5% = 底部信号 · 0%~-5% = 开始关注',
    source: 'Yahoo Finance',
    sourceUrl: yahooUrl(series.symbol),
    asOf: series.asOf || undefined,
    isBottomSignal: status === 'bottom',
  };
}

function unavailableMetric(
  id: string,
  group: 'sentiment' | 'technical',
  title: string,
  source: string,
  sourceUrl: string,
  threshold: string
): MarketSignalMetric {
  return {
    id,
    group,
    title,
    value: '暂无可靠数据',
    status: 'unavailable',
    label: '暂无数据',
    description: '数据源当前不可用，未使用模拟值。',
    threshold,
    source,
    sourceUrl,
    isBottomSignal: false,
  };
}

export async function fetchYahooSeries(symbol: string, name: string): Promise<YahooSeries> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=1y&includePrePost=false`;
  const data = await fetchJson<{
    chart?: {
      result?: Array<{
        meta?: {
          symbol?: string;
          shortName?: string;
          regularMarketPrice?: number;
          chartPreviousClose?: number;
          previousClose?: number;
          regularMarketTime?: number;
          currency?: string;
        };
        timestamp?: number[];
        indicators?: {
          quote?: Array<{
            open?: Array<number | null>;
            high?: Array<number | null>;
            low?: Array<number | null>;
            close?: Array<number | null>;
            volume?: Array<number | null>;
          }>;
        };
      }>;
      error?: { code?: string; description?: string };
    };
  }>(url, { headers: YAHOO_HEADERS });

  const root = data.chart?.result?.[0];
  if (!root) throw new Error(data.chart?.error?.description || `Yahoo data unavailable for ${symbol}`);

  const q = root.indicators?.quote?.[0];
  const closes = (q?.close || []).filter((value): value is number => Number.isFinite(value));
  const highs = (q?.high || []).filter((value): value is number => Number.isFinite(value));
  const lows = (q?.low || []).filter((value): value is number => Number.isFinite(value));
  const volumes = (q?.volume || []).filter((value): value is number => Number.isFinite(value));
  const price = numberOrNull(root.meta?.regularMarketPrice) ?? closes.at(-1) ?? null;
  const priorDailyClose = closes.length > 1 ? closes.at(-2)! : null;
  const previousClose =
    numberOrNull(root.meta?.previousClose) ??
    priorDailyClose ??
    numberOrNull(root.meta?.chartPreviousClose);
  const change = price !== null && previousClose !== null ? price - previousClose : null;
  const changePct = change !== null && previousClose ? (change / previousClose) * 100 : null;
  const sma20 = sma(closes, 20);
  const sma50 = sma(closes, 50);
  const sma200 = sma(closes, 200);
  const change5dPct = lookbackPct(closes, 5);
  const change1mPct = lookbackPct(closes, 21);

  return {
    symbol,
    name: root.meta?.shortName || name,
    price,
    previousClose,
    change,
    changePct,
    dayHigh: highs.at(-1) ?? null,
    dayLow: lows.at(-1) ?? null,
    volume: volumes.at(-1) ?? null,
    rsi14: rsi(closes, 14),
    sma20,
    sma50,
    sma200,
    deviation200Pct: price !== null && sma200 ? ((price - sma200) / sma200) * 100 : null,
    change5dPct,
    change1mPct,
    provider: 'Yahoo Finance',
    sourceUrl: yahooUrl(symbol),
    asOf: root.meta?.regularMarketTime
      ? new Date(root.meta.regularMarketTime * 1000).toISOString()
      : root.timestamp?.at(-1)
        ? new Date(root.timestamp.at(-1)! * 1000).toISOString()
        : null,
    note: interpretation(price, sma20, sma50, sma200, changePct, change5dPct, change1mPct),
    closes,
  };
}

function interpretation(
  price: number | null,
  sma20: number | null,
  sma50: number | null,
  sma200: number | null,
  changePct: number | null,
  change5dPct: number | null,
  change1mPct: number | null
): string {
  if (price === null) return '暂无可靠数据';
  const parts: string[] = [];
  if (sma200 !== null) {
    const dev = ((price - sma200) / sma200) * 100;
    if (dev <= -5) parts.push('已跌破200日均线 5% 以上，进入超跌区');
    else if (dev <= 0) parts.push('围绕200日均线运行，趋势中性偏弱');
    else if (dev >= 15) parts.push('明显高于200日均线，注意追高风险');
    else parts.push('位于200日均线上方，趋势偏多');
  }
  if (sma20 !== null && sma50 !== null) {
    if (sma20 > sma50) parts.push('短均线在长均线上方，短期动能偏正');
    else parts.push('短均线低于长均线，短期动能偏弱');
  }
  if (change5dPct !== null && change1mPct !== null) {
    parts.push(`5日 ${fmtSignedPct(change5dPct)} · 月度 ${fmtSignedPct(change1mPct)}`);
  } else if (changePct !== null) {
    parts.push(`今日 ${fmtSignedPct(changePct)}`);
  }
  return parts.join('；') || '数据可读，状态中性';
}

async function fetchCnnFearGreed(): Promise<CnnFearGreed | null> {
  const data = await fetchJson<{
    fear_and_greed?: {
      score?: number;
      rating?: string;
      timestamp?: string;
      previous_close?: number;
    };
  }>('https://production.dataviz.cnn.io/index/fearandgreed/graphdata', { headers: CNN_HEADERS });

  const fg = data.fear_and_greed;
  if (!fg || !Number.isFinite(fg.score)) return null;
  return {
    score: fg.score!,
    rating: fg.rating || 'unknown',
    timestamp: fg.timestamp || new Date().toISOString(),
    previousClose: fg.previous_close,
  };
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 9000);
  try {
    const res = await fetch(url, { ...init, cache: 'no-store', signal: controller.signal });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  } finally {
    clearTimeout(timeout);
  }
}

function buildGroup(
  id: 'sentiment' | 'technical',
  title: string,
  metrics: MarketSignalMetric[],
  metricIds: string[]
): MarketSignalGroup {
  const rows = metrics.filter((metric) => metricIds.includes(metric.id));
  return {
    id,
    title,
    signalCount: rows.filter((metric) => metric.isBottomSignal).length,
    total: rows.length,
    metricIds,
  };
}

function stanceFromScore(score: number) {
  if (score >= 4) return '强底部信号 · 分批观察';
  if (score >= 2) return '开始关注 · 等确认';
  return '偏高风险 · 谨慎追高';
}

function headlineFromSignals(score: number, vix: YahooSeries | null, fearGreed: CnnFearGreed | null) {
  const vixText = vix?.price ? `VIX ${vix.price.toFixed(1)}` : 'VIX 暂无可靠数据';
  const fgText = fearGreed ? `Fear & Greed ${fearGreed.score.toFixed(0)}` : 'Fear & Greed 暂无可靠数据';
  if (score >= 4) return `${vixText}，${fgText}，市场接近恐慌底部观察区。`;
  if (score >= 2) return `${vixText}，${fgText}，部分指标开始转弱，需要价格确认。`;
  return `${vixText}，${fgText}，底部信号不足，追高风险更需要控制。`;
}

function buildSummary(
  score: number,
  spx: YahooSeries | null,
  ndx: YahooSeries | null,
  vix: YahooSeries | null,
  fearGreed: CnnFearGreed | null
) {
  const spxText = spx?.price ? `标普500 ${fmtNumber(spx.price, 0)}（${fmtSignedPct(spx.changePct)}）` : '标普500 暂无可靠数据';
  const ndxText = ndx?.price ? `纳指100 ${fmtNumber(ndx.price, 0)}（${fmtSignedPct(ndx.changePct)}）` : '纳指100 暂无可靠数据';
  const vixText = vix?.price ? `VIX ${vix.price.toFixed(2)}` : 'VIX 暂无可靠数据';
  const fgText = fearGreed ? `CNN 情绪 ${fearGreed.score.toFixed(0)} / ${fearGreed.rating}` : 'CNN 情绪暂无可靠数据';
  return `${spxText}，${ndxText}，${vixText}，${fgText}。当前综合底部信号 ${score}/6，所有分数只代表市场状态，不代表买卖建议。`;
}

function cleanTickers(tickers: string[]) {
  return Array.from(
    new Set(
      tickers
        .map((ticker) => ticker.replace(/^\$/, '').trim().toUpperCase())
        .filter((ticker) => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(ticker))
    )
  );
}

function publicQuote(series: YahooSeries): MarketSignalQuote {
  const { closes: _closes, ...quote } = series;
  return quote;
}

function sma(values: number[], period: number): number | null {
  if (values.length < period) return null;
  const slice = values.slice(-period);
  return slice.reduce((sum, value) => sum + value, 0) / period;
}

function rsi(values: number[], period: number): number | null {
  if (values.length <= period) return null;
  const slice = values.slice(-(period + 1));
  let gains = 0;
  let losses = 0;
  for (let i = 1; i < slice.length; i += 1) {
    const change = slice[i] - slice[i - 1];
    if (change >= 0) gains += change;
    else losses += Math.abs(change);
  }
  const avgGain = gains / period;
  const avgLoss = losses / period;
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}

function lookbackPct(closes: number[], periods: number): number | null {
  if (closes.length <= periods) return null;
  const last = closes.at(-1)!;
  const prior = closes.at(-1 - periods)!;
  if (!prior) return null;
  return ((last - prior) / prior) * 100;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function statusLabel(status: SignalStatus) {
  if (status === 'bottom') return '底部信号';
  if (status === 'watch') return '开始关注';
  if (status === 'risk') return '危险';
  return '暂无数据';
}

function yahooUrl(symbol: string) {
  return `https://finance.yahoo.com/quote/${encodeURIComponent(symbol)}`;
}

function fmtNumber(value: number | null | undefined, digits = 2) {
  if (value === null || value === undefined || !Number.isFinite(value)) return '暂无可靠数据';
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
}

function fmtSignedPct(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(value)) return '暂无可靠数据';
  return `${value >= 0 ? '+' : ''}${value.toFixed(1)}%`;
}
