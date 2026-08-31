import { chat } from '@/lib/llm';
import { fetchQuantSeries } from '@/lib/quant/data';
import { computeFactorScores } from '@/lib/quant/factors';
import { runWebForecast } from '@/lib/quant/web-forecast';
import {
  buildMarketSignalReport,
  fetchYahooSeries,
  type MarketSignalQuote,
} from '@/lib/market-intelligence/market-signal';
import { buildMacroReport } from '@/lib/market-intelligence/macro';
import { buildNewsPulseReport } from '@/lib/market-intelligence/news-pulse';
import {
  fetchAuthorizedMarketEvents,
  getSourceStatuses,
} from '@/lib/market-intelligence/sources';
import type {
  ForecastAsset,
  ForecastChatResult,
  ForecastEvidence,
  ForecastSource,
  ForecastSourceState,
} from '@/lib/forecast-chat-types';

type MassiveBar = {
  c?: number;
  h?: number;
  l?: number;
  o?: number;
  t?: number;
  v?: number;
};

type MassiveHistory = {
  state: ForecastSourceState;
  status: string;
  symbol: string;
  bars: MassiveBar[];
  error?: string;
};

type MassiveSnapshot = {
  state: ForecastSourceState;
  symbol: string;
  price: number | null;
  changePct: number | null;
  asOf: string | null;
  error?: string;
};

type AssetDefinition = {
  symbol: string;
  massiveSymbol: string | null;
  name: string;
};

const SYMBOL_ALIASES: Array<{ pattern: RegExp; symbol: string }> = [
  { pattern: /\bSPX\b|S&P\s*500|标普(?:500)?/i, symbol: '^GSPC' },
  { pattern: /\bNDX\b|NASDAQ\s*100|纳斯达克100|纳指100/i, symbol: '^NDX' },
  { pattern: /\bNASDAQ\b|NASDAQ COMPOSITE|纳斯达克|纳指/i, symbol: '^IXIC' },
  { pattern: /\bDJI\b|DOW JONES|道琼斯|道指/i, symbol: '^DJI' },
  { pattern: /\bRUT\b|RUSSELL\s*2000|罗素2000/i, symbol: '^RUT' },
  { pattern: /\bSOX\b|PHLX SEMICONDUCTOR|费城半导体/i, symbol: '^SOX' },
  { pattern: /\bVIX\b|恐慌指数/i, symbol: '^VIX' },
  { pattern: /\bBITCOIN\b|比特币/i, symbol: 'BTC-USD' },
  { pattern: /\bETHEREUM\b|以太坊/i, symbol: 'ETH-USD' },
  { pattern: /\bNVIDIA\b|英伟达/i, symbol: 'NVDA' },
  { pattern: /\bTESLA\b|特斯拉/i, symbol: 'TSLA' },
  { pattern: /\bAPPLE\b|苹果公司/i, symbol: 'AAPL' },
  { pattern: /\bMICROSOFT\b|微软/i, symbol: 'MSFT' },
  { pattern: /\bGOOGLE\b|\bALPHABET\b|谷歌/i, symbol: 'GOOGL' },
  { pattern: /\bAMAZON\b|亚马逊/i, symbol: 'AMZN' },
  { pattern: /\bMETA\b|脸书/i, symbol: 'META' },
];

const DIRECT_SYMBOL_MAP: Record<string, string> = {
  SPX: '^GSPC',
  GSPC: '^GSPC',
  NDX: '^NDX',
  IXIC: '^IXIC',
  DJI: '^DJI',
  RUT: '^RUT',
  SOX: '^SOX',
  VIX: '^VIX',
  BTC: 'BTC-USD',
  ETH: 'ETH-USD',
};

const INDEX_PROXY: Record<string, string> = {
  '^GSPC': 'SPY',
  '^NDX': 'QQQ',
  '^IXIC': 'QQQ',
  '^DJI': 'DIA',
  '^RUT': 'IWM',
  '^SOX': 'SOXX',
  '^VIX': 'VIXY',
};

const DISPLAY_NAMES: Record<string, string> = {
  '^GSPC': 'S&P 500 (SPX)',
  '^NDX': 'Nasdaq 100',
  '^IXIC': 'Nasdaq Composite',
  '^DJI': 'Dow Jones Industrial Average',
  '^RUT': 'Russell 2000',
  '^SOX': 'PHLX Semiconductor Index',
  '^VIX': 'CBOE Volatility Index',
  'BTC-USD': 'Bitcoin / U.S. Dollar',
  'ETH-USD': 'Ethereum / U.S. Dollar',
};

const SYMBOL_STOP_WORDS = new Set([
  'API',
  'AXIO',
  'AXIO7',
  'CEO',
  'CFO',
  'FED',
  'FOR',
  'FUTURE',
  'MODEL',
  'PREDICT',
  'SEC',
  'THE',
  'TREND',
  'WHAT',
  'WILL',
  'WITH',
  'YOU',
]);

export async function runForecastChat(
  query: string,
  requestedSymbols: string[] = []
): Promise<{ answer: string; forecast: ForecastChatResult }> {
  const generatedAt = new Date().toISOString();
  const definitions = resolveAssets(query, requestedSymbols);
  const symbols = definitions.map((asset) => asset.symbol);
  const horizon = inferHorizon(query);
  const horizonTradingDays = inferHorizonTradingDays(query);
  const newsSymbols = Array.from(
    new Set(definitions.map((asset) => asset.massiveSymbol).filter(Boolean))
  ) as string[];

  const [assetsSettled, marketSettled, macroSettled, newsSettled, eventsSettled] =
    await Promise.all([
      Promise.allSettled(
        definitions.map((definition) =>
          loadAsset(definition, horizonTradingDays)
        )
      ),
      buildMarketSignalReport(symbols).catch(() => null),
      buildMacroReport().catch(() => null),
      buildNewsPulseReport(newsSymbols.length ? newsSymbols : ['SPY', 'QQQ']).catch(
        () => null
      ),
      fetchAuthorizedMarketEvents(newsSymbols, query).catch(() => []),
    ]);

  const assets = assetsSettled
    .filter(
      (result): result is PromiseFulfilledResult<ForecastAsset> =>
        result.status === 'fulfilled'
    )
    .map((result) => result.value);

  const massiveStates = assetsSettled
    .filter(
      (
        result
      ): result is PromiseFulfilledResult<ForecastAsset & { massiveState?: ForecastSourceState }> =>
        result.status === 'fulfilled'
    )
    .map((result) => result.value.massiveState)
    .filter(Boolean) as ForecastSourceState[];

  const sourceStatuses = getSourceStatuses();
  const sources = buildSourceSummary({
    assets,
    massiveStates,
    market: marketSettled,
    macro: macroSettled,
    news: newsSettled,
    configuredVendorCount: sourceStatuses.filter((source) => source.productionReady)
      .length,
    events: eventsSettled,
  });

  const evidence = buildEvidence(newsSettled, eventsSettled);
  const modelContext = {
    generatedAt,
    question: query,
    horizon,
    assets,
    market: marketSettled
      ? {
          stance: marketSettled.stance,
          headline: marketSettled.headline,
          reliability: marketSettled.reliability,
          indices: marketSettled.indices.map(quoteBrief),
          sectors: rankQuotes(marketSettled.sectors).slice(0, 8).map(quoteBrief),
          themes: rankQuotes(marketSettled.themes).slice(0, 6).map(quoteBrief),
        }
      : null,
    macro: macroSettled
      ? {
          reliability: macroSettled.reliability,
          recessionSignals: macroSettled.recessionSignals,
          series: macroSettled.series
            .filter((series) => series.status === 'ok')
            .map((series) => ({
              id: series.id,
              title: series.title,
              latest: series.latest,
              unit: series.unit,
              asOf: series.asOf,
              changePct: series.changePct,
              yoyPct: series.yoyPct,
            })),
        }
      : null,
    evidence: evidence.slice(0, 12),
    sources,
  };

  const answer = await generateForecastAnswer(query, modelContext, assets, horizon);

  return {
    answer,
    forecast: {
      generatedAt,
      model: 'AXIO7 Web Forecast Engine',
      horizon,
      assets,
      sources,
      evidence,
      disclaimer:
        'AXIO7 combines configured market feeds, public data, deterministic quantitative features, and a server-side historical-analog forecast distribution. Source latency and availability are shown explicitly. The result is exploratory conditional research, not a guaranteed forecast or personalized investment advice.',
    },
  };
}

function resolveAssets(query: string, requested: string[]): AssetDefinition[] {
  const symbols = new Set<string>();

  for (const raw of requested) {
    const cleaned = raw.replace(/^\$/, '').trim().toUpperCase();
    if (!cleaned) continue;
    symbols.add(DIRECT_SYMBOL_MAP[cleaned] || cleaned);
  }

  for (const { pattern, symbol } of SYMBOL_ALIASES) {
    if (pattern.test(query)) symbols.add(symbol);
  }

  for (const raw of query.match(/\$?[A-Z][A-Z0-9.\-]{0,9}\b/g) || []) {
    const cleaned = raw.replace(/^\$/, '').toUpperCase();
    if (SYMBOL_STOP_WORDS.has(cleaned)) continue;
    symbols.add(DIRECT_SYMBOL_MAP[cleaned] || cleaned);
  }

  if (symbols.size === 0) {
    symbols.add('^GSPC');
    symbols.add('^NDX');
    symbols.add('^VIX');
  }

  return Array.from(symbols)
    .slice(0, 5)
    .map((symbol) => ({
      symbol,
      massiveSymbol:
        INDEX_PROXY[symbol] ||
        (/^[A-Z][A-Z0-9.]{0,9}$/.test(symbol) ? symbol : null),
      name: DISPLAY_NAMES[symbol] || symbol,
    }));
}

async function loadAsset(
  definition: AssetDefinition,
  horizonTradingDays: number
): Promise<ForecastAsset & { massiveState?: ForecastSourceState }> {
  const [quoteResult, seriesResult, massiveHistory, massiveSnapshot] =
    await Promise.all([
      fetchYahooSeries(definition.symbol, definition.name).catch(() => null),
      fetchQuantSeries(definition.symbol, '5y').catch(() => null),
      definition.massiveSymbol
        ? fetchMassiveHistory(definition.massiveSymbol)
        : Promise.resolve<MassiveHistory>({
            state: 'unavailable',
            status: 'not_applicable',
            symbol: definition.symbol,
            bars: [],
          }),
      definition.massiveSymbol
        ? fetchMassiveSnapshot(definition.massiveSymbol)
        : Promise.resolve<MassiveSnapshot>({
            state: 'unavailable',
            symbol: definition.symbol,
            price: null,
            changePct: null,
            asOf: null,
          }),
    ]);

  if (!quoteResult && !seriesResult && !massiveHistory.bars.length) {
    throw new Error(`No market history available for ${definition.symbol}`);
  }

  const factors = seriesResult
    ? computeFactorScores(seriesResult.closes, seriesResult.volumes, null)
    : {};
  const historyDates =
    massiveHistory.bars.length > 0
      ? massiveHistory.bars
          .map((bar) =>
            typeof bar.t === 'number'
              ? new Date(bar.t).toISOString().slice(0, 10)
              : null
          )
          .filter((date): date is string => Boolean(date))
      : seriesResult?.dates || [];
  const useMassivePrice =
    massiveSnapshot.state === 'real_time' && massiveSnapshot.price !== null;
  const price = useMassivePrice
    ? massiveSnapshot.price
    : quoteResult?.price ?? seriesResult?.currentPrice ?? massiveHistory.bars.at(-1)?.c ?? null;
  const changePct = useMassivePrice
    ? massiveSnapshot.changePct
    : quoteResult?.changePct ?? null;
  const asOf = useMassivePrice
    ? massiveSnapshot.asOf
    : quoteResult?.asOf ?? seriesResult?.asOf ?? null;
  const massiveState =
    massiveSnapshot.state === 'real_time'
      ? 'real_time'
      : massiveHistory.state === 'delayed' || massiveHistory.state === 'historical'
        ? massiveHistory.state
        : 'unavailable';
  const prediction = runWebForecast(
    seriesResult?.closes ||
      massiveHistory.bars
        .map((bar) => bar.c)
        .filter((value): value is number =>
          typeof value === 'number' && Number.isFinite(value)
        ),
    price,
    horizonTradingDays
  );

  return {
    symbol: displaySymbol(definition.symbol),
    dataSymbol: definition.symbol,
    name: definition.name,
    price,
    changePct,
    change5dPct: quoteResult?.change5dPct ?? null,
    change1mPct: quoteResult?.change1mPct ?? null,
    rsi14: quoteResult?.rsi14 ?? factorNumber(factors, 'rsi14'),
    sma20: quoteResult?.sma20 ?? null,
    sma50: quoteResult?.sma50 ?? null,
    sma200: quoteResult?.sma200 ?? null,
    deviation200Pct: quoteResult?.deviation200Pct ?? null,
    asOf,
    priceProvider: useMassivePrice ? 'Massive real-time snapshot' : 'Yahoo Finance',
    historyProvider: massiveHistory.bars.length
      ? `Massive ${massiveHistory.status.toLowerCase()} daily aggregates`
      : 'Yahoo Finance daily history',
    historyObservations:
      massiveHistory.bars.length || seriesResult?.closes.length || 0,
    historyFrom: historyDates.at(0) ?? null,
    historyTo: historyDates.at(-1) ?? null,
    trendLabel: trendLabel(quoteResult, factors),
    factors: Object.fromEntries(
      Object.entries(factors).map(([key, value]) => [
        key,
        typeof value === 'number' && Number.isFinite(value) ? round(value, 6) : null,
      ])
    ),
    prediction,
    massiveState,
  };
}

async function fetchMassiveHistory(symbol: string): Promise<MassiveHistory> {
  const apiKey = process.env.MASSIVE_API_KEY;
  if (!apiKey) {
    return {
      state: 'unavailable',
      status: 'credential_missing',
      symbol,
      bars: [],
    };
  }

  const to = new Date();
  const from = new Date(to);
  from.setUTCFullYear(from.getUTCFullYear() - 5);
  const url =
    `https://api.massive.com/v2/aggs/ticker/${encodeURIComponent(symbol)}` +
    `/range/1/day/${from.toISOString().slice(0, 10)}/${to
      .toISOString()
      .slice(0, 10)}?adjusted=true&sort=asc&limit=5000`;

  try {
    const response = await timedFetch(url, {
      headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json' },
    });
    const payload = (await response.json()) as {
      status?: string;
      results?: MassiveBar[];
      error?: string;
      message?: string;
    };
    if (!response.ok) {
      return {
        state: 'unavailable',
        status: payload.status || `http_${response.status}`,
        symbol,
        bars: [],
        error: payload.error || payload.message,
      };
    }
    const status = payload.status || 'OK';
    return {
      state: /DELAYED/i.test(status) ? 'delayed' : 'historical',
      status,
      symbol,
      bars: payload.results || [],
    };
  } catch (error) {
    return {
      state: 'unavailable',
      status: 'request_failed',
      symbol,
      bars: [],
      error: error instanceof Error ? error.message : 'request failed',
    };
  }
}

async function fetchMassiveSnapshot(symbol: string): Promise<MassiveSnapshot> {
  const apiKey = process.env.MASSIVE_API_KEY;
  if (!apiKey) {
    return {
      state: 'unavailable',
      symbol,
      price: null,
      changePct: null,
      asOf: null,
    };
  }

  const url = `https://api.massive.com/v2/snapshot/locale/us/markets/stocks/tickers/${encodeURIComponent(
    symbol
  )}`;
  try {
    const response = await timedFetch(url, {
      headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json' },
    });
    const payload = (await response.json()) as {
      status?: string;
      error?: string;
      message?: string;
      ticker?: {
        lastTrade?: { p?: number; t?: number };
        todaysChangePerc?: number;
        updated?: number;
      };
    };
    if (!response.ok || !payload.ticker) {
      return {
        state: 'unavailable',
        symbol,
        price: null,
        changePct: null,
        asOf: null,
        error: payload.error || payload.message || payload.status,
      };
    }
    const timestamp =
      payload.ticker.lastTrade?.t || payload.ticker.updated || null;
    return {
      state: /DELAYED/i.test(payload.status || '') ? 'delayed' : 'real_time',
      symbol,
      price: finiteOrNull(payload.ticker.lastTrade?.p),
      changePct: finiteOrNull(payload.ticker.todaysChangePerc),
      asOf: timestamp ? new Date(normalizeEpoch(timestamp)).toISOString() : null,
    };
  } catch (error) {
    return {
      state: 'unavailable',
      symbol,
      price: null,
      changePct: null,
      asOf: null,
      error: error instanceof Error ? error.message : 'request failed',
    };
  }
}

function buildSourceSummary({
  assets,
  massiveStates,
  market,
  macro,
  news,
  configuredVendorCount,
  events,
}: {
  assets: ForecastAsset[];
  massiveStates: ForecastSourceState[];
  market: Awaited<ReturnType<typeof buildMarketSignalReport>> | null;
  macro: Awaited<ReturnType<typeof buildMacroReport>> | null;
  news: Awaited<ReturnType<typeof buildNewsPulseReport>> | null;
  configuredVendorCount: number;
  events: Awaited<ReturnType<typeof fetchAuthorizedMarketEvents>>;
}): ForecastSource[] {
  const massiveState: ForecastSourceState = massiveStates.includes('real_time')
    ? 'real_time'
    : massiveStates.includes('delayed')
      ? 'delayed'
      : massiveStates.includes('historical')
        ? 'historical'
        : 'unavailable';
  const latestAssetTime =
    assets
      .map((asset) => asset.asOf)
      .filter((value): value is string => Boolean(value))
      .sort()
      .at(-1) || null;
  const secEvents = events.filter((event) => event.sourceKind === 'sec_edgar');

  return [
    {
      id: 'massive',
      name: 'Massive',
      state: massiveState,
      role: 'Licensed market aggregates and snapshot capability',
      asOf: assets
        .map((asset) => asset.historyTo)
        .filter((value): value is string => Boolean(value))
        .sort()
        .at(-1),
      note:
        massiveState === 'real_time'
          ? 'Licensed real-time snapshot is available.'
          : massiveState === 'delayed' || massiveState === 'historical'
            ? 'Daily aggregates are connected; the current plan does not authorize real-time snapshots.'
            : 'Credential or entitlement is unavailable.',
    },
    {
      id: 'yahoo',
      name: 'Yahoo Finance Chart API',
      state: assets.length ? 'delayed' : 'unavailable',
      role: 'Current/delayed quotes and one-to-two-year daily history',
      asOf: latestAssetTime,
      note: assets.length
        ? `${assets.length} requested market series loaded.`
        : 'No requested series loaded.',
    },
    {
      id: 'axio7-quant',
      name: 'AXIO7 Web Forecast Engine',
      state: assets.length ? 'computed' : 'unavailable',
      role:
        'Server-side historical analog distribution plus deterministic trend, momentum, RSI, volatility, and flow features',
      asOf: latestAssetTime,
      note: assets.length
        ? `${assets.filter((asset) => asset.prediction).length}/${assets.length} requested assets received a model distribution from timestamped historical bars.`
        : 'No historical series was available for feature computation.',
    },
    {
      id: 'fred',
      name: 'FRED',
      state:
        macro?.reliability === 'ok'
          ? 'historical'
          : macro?.reliability === 'partial'
            ? 'partial'
            : 'unavailable',
      role: 'Rates, yield curve, inflation, employment, money supply, and dollar data',
      asOf:
        macro?.series
          .map((series) => series.asOf)
          .filter((value): value is string => Boolean(value))
          .sort()
          .at(-1) || null,
      note: macro
        ? `${macro.series.filter((series) => series.status === 'ok').length}/${macro.series.length} macro series loaded.`
        : 'Macro service unavailable.',
    },
    {
      id: 'public-news',
      name: 'GDELT + Hacker News',
      state:
        news &&
        (news.reliability.gdelt === 'ok' ||
          news.reliability.hackernews === 'ok')
          ? 'partial'
          : 'unavailable',
      role: 'Recent public news density and headlines',
      asOf: news?.generatedAt || null,
      note: news
        ? `${news.gdelt.length + news.hackerNews.length} recent public items loaded.`
        : 'Public news services unavailable.',
    },
    {
      id: 'sec-vendors',
      name: 'SEC EDGAR + configured licensed event feeds',
      state:
        secEvents.length || configuredVendorCount > 0 ? 'partial' : 'unavailable',
      role: 'Filings and authorized market-moving events',
      asOf:
        events
          .map((event) => event.publishedAt)
          .filter(Boolean)
          .sort()
          .at(-1) || null,
      note: `${secEvents.length} SEC filing event(s), ${configuredVendorCount} licensed event source(s) configured.`,
    },
  ];
}

function buildEvidence(
  news: Awaited<ReturnType<typeof buildNewsPulseReport>> | null,
  events: Awaited<ReturnType<typeof fetchAuthorizedMarketEvents>>
): ForecastEvidence[] {
  const marketEvidence: ForecastEvidence[] = events.slice(0, 12).map((event) => ({
    id: event.id,
    title: event.title,
    source: event.sourceName,
    url: event.url,
    publishedAt: event.publishedAt,
    kind: event.sourceKind === 'sec_edgar' ? 'filing' : 'market_event',
  }));
  const newsEvidence: ForecastEvidence[] = [
    ...(news?.gdelt || []),
    ...(news?.hackerNews || []),
  ]
    .sort(
      (left, right) =>
        new Date(right.publishedAt).getTime() -
        new Date(left.publishedAt).getTime()
    )
    .slice(0, 12)
    .map((item) => ({
      id: item.id,
      title: item.title,
      source: item.source === 'gdelt' ? item.domain || 'GDELT' : 'Hacker News',
      url: item.url,
      publishedAt: item.publishedAt,
      kind: 'news' as const,
    }));
  return [...marketEvidence, ...newsEvidence]
    .sort(
      (left, right) =>
        new Date(right.publishedAt).getTime() -
        new Date(left.publishedAt).getTime()
    )
    .slice(0, 18);
}

async function generateForecastAnswer(
  query: string,
  context: unknown,
  assets: ForecastAsset[],
  horizon: string
): Promise<string> {
  const system = [
    'You are the AXIO7 Forecast Model, a sober market-scenario research system.',
    'The application has already loaded and timestamped market, macro, news, and deterministic quantitative features.',
    'Use only the supplied context. Never invent a price, event, source, probability, or data freshness claim.',
    'Answer in the same language as the user. If the user writes Chinese, answer in clear professional Chinese.',
    'Do not say there is no data when asset quotes or quantitative features are present.',
    'Distinguish real-time, delayed, and historical sources. If real-time entitlement is unavailable, say so once and use the latest timestamped data conditionally.',
    'Structure the answer with: current state, base case, upside case, downside case, key confirmation/invalidation signals, and data timestamp.',
    'Give a directional bias only when supported. Do not promise returns, issue a personalized buy/sell instruction, or pretend the model is calibrated when it is not.',
    'Cite data source names in parentheses, such as (Massive), (Yahoo Finance), (FRED), (GDELT), or (SEC EDGAR).',
    'Keep the response concise but substantive: approximately 350-650 words for Chinese or 250-450 words for English.',
  ].join('\n');

  try {
    const response = await chat(
      [
        { role: 'system', content: system },
        {
          role: 'user',
          content: `Question: ${query}\nRequested horizon: ${horizon}\n\nVerified model context:\n${JSON.stringify(
            context
          )}`,
        },
      ],
      { temperature: 0.25, max_tokens: 1500 }
    );
    if (response.trim()) return response.trim();
  } catch (error) {
    console.warn(
      '[forecast-chat/model]',
      error instanceof Error ? error.message : 'model failed'
    );
  }

  return deterministicFallback(query, assets, horizon);
}

function deterministicFallback(
  query: string,
  assets: ForecastAsset[],
  horizon: string
) {
  const chinese = /[\u3400-\u9fff]/.test(query);
  const primary = assets[0];
  if (!primary) {
    return chinese
      ? '当前没有成功加载可验证的市场序列，因此 AXIO7 不生成方向判断。请明确输入 ticker 后重试。'
      : 'No verified market series loaded, so AXIO7 is not producing a directional view. Add a ticker and retry.';
  }
  const price = primary.price === null ? '—' : primary.price.toFixed(2);
  const rsi = primary.rsi14 === null ? '—' : primary.rsi14.toFixed(1);
  const oneMonth =
    primary.change1mPct === null
      ? '—'
      : `${primary.change1mPct >= 0 ? '+' : ''}${primary.change1mPct.toFixed(2)}%`;
  const prediction = primary.prediction;
  if (!prediction) {
    return chinese
      ? `当前状态\n${primary.name} 参考价 ${price}，近一月 ${oneMonth}，RSI(14) 为 ${rsi}，趋势为“${primary.trendLabel}”。\n\n模型状态\n历史样本不足，AXIO7 Web Forecast Engine 没有生成收益分布，因此不输出伪造的上涨概率。可验证行情时间为 ${primary.asOf || '未提供'}，价格来源为 ${primary.priceProvider}。\n\n判断\n在 ${horizon} 内维持中性条件判断：价格与中长期均线同步走强才确认上行；跌破关键均线并伴随波动扩张则确认下行。这是研究结果，不是保证性预测。`
      : `Current state\n${primary.name} is at ${price}, with a one-month change of ${oneMonth}, RSI(14) of ${rsi}, and a ${primary.trendLabel.toLowerCase()} trend state.\n\nModel status\nThe historical sample was insufficient for the AXIO7 Web Forecast Engine to produce a return distribution, so no probability is being fabricated. The verified market timestamp is ${primary.asOf || 'unavailable'} from ${primary.priceProvider}.\n\nView\nFor ${horizon}, the stance remains neutral and conditional: synchronized price and medium-term trend strength would confirm upside, while a key moving-average break with volatility expansion would confirm downside. This is research, not a guaranteed forecast.`;
  }

  const expected = signedPercent(prediction.expectedReturnPct);
  const median = signedPercent(prediction.medianReturnPct);
  const lower = signedPercent(prediction.lower10ReturnPct);
  const upper = signedPercent(prediction.upper90ReturnPct);
  const directionalSpread =
    prediction.probabilityUpPct - prediction.probabilityDownPct;
  const bias =
    directionalSpread >= 8
      ? chinese
        ? '温和偏多'
        : 'moderately positive'
      : directionalSpread <= -8
        ? chinese
          ? '温和偏空'
          : 'moderately negative'
        : chinese
          ? '中性/震荡'
          : 'neutral / range-bound';
  if (chinese) {
    return `结论（${horizon}）\nAXIO7 当前判断为${bias}。${prediction.horizonTradingDays} 个交易日的历史相似状态模型给出预期收益 ${expected}、中位数 ${median}；上涨/横盘/下跌权重分别为 ${prediction.probabilityUpPct}% / ${prediction.probabilityFlatPct}% / ${prediction.probabilityDownPct}%。\n\n当前状态\n${primary.name} 参考价 ${price}，近一月 ${oneMonth}，RSI(14) 为 ${rsi}，趋势为“${primary.trendLabel}”。\n\n基准情景\n模型基于 ${prediction.trainingObservations} 根历史日线，选取 ${prediction.analogCount} 个最接近的点时状态。10%–90% 历史条件区间为 ${lower} 至 ${upper}，对应价格约 ${prediction.lower10Price.toFixed(2)}–${prediction.upper90Price.toFixed(2)}；这不是置信保证区间。\n\n上行情景\n若价格保持在中期趋势上方，动量改善且波动没有同步扩张，上行权重会得到确认；模型当前上行参考目标为预期价格 ${prediction.expectedPrice.toFixed(2)}，而非交易指令。\n\n下行情景\n若关键均线失守、RSI继续走弱且波动扩张，则当前${bias}判断失效，并应优先参考区间下沿 ${prediction.lower10Price.toFixed(2)} 的压力测试。\n\n数据与限制\n行情时间：${primary.asOf || '未提供'}；价格：${primary.priceProvider}；历史：${primary.historyProvider}。AXIO7 Web Forecast Engine 为部署在网站后端的探索性模型，概率来自历史相似状态的加权分布，尚未等同于通过前瞻影子期验证的生产交易模型。`;
  }
  return `Conclusion (${horizon})\nAXIO7's current bias is ${bias}. The ${prediction.horizonTradingDays}-trading-day historical-analog model estimates an expected return of ${expected} and a median of ${median}; the weighted up / flat / down shares are ${prediction.probabilityUpPct}% / ${prediction.probabilityFlatPct}% / ${prediction.probabilityDownPct}%.\n\nCurrent state\n${primary.name} is at ${price}, with a one-month change of ${oneMonth}, RSI(14) of ${rsi}, and a ${primary.trendLabel.toLowerCase()} trend state.\n\nBase case\nThe model used ${prediction.trainingObservations} daily observations and ${prediction.analogCount} nearest point-in-time states. Its historical conditional 10th–90th percentile range is ${lower} to ${upper}, or approximately ${prediction.lower10Price.toFixed(2)}–${prediction.upper90Price.toFixed(2)}. This is not a guaranteed confidence interval.\n\nUpside case\nPrice holding above the medium-term trend, improving momentum, and contained volatility would confirm the upside case. The model's current expected-price reference is ${prediction.expectedPrice.toFixed(2)}, not a trading instruction.\n\nDownside case\nA key moving-average break, weaker RSI, and volatility expansion would invalidate the current bias and put the lower stress reference of ${prediction.lower10Price.toFixed(2)} in focus.\n\nData and limitations\nMarket timestamp: ${primary.asOf || 'unavailable'}; price source: ${primary.priceProvider}; history: ${primary.historyProvider}. The AXIO7 Web Forecast Engine is an exploratory server-side model. Its probabilities are weighted historical-analog frequencies and are not equivalent to a production model that has passed a locked forward-shadow validation period.`;
}

function trendLabel(
  quote: MarketSignalQuote | null,
  factors: Record<string, unknown>
) {
  const price = quote?.price;
  const sma50 = quote?.sma50;
  const sma200 = quote?.sma200;
  const momentum = factorNumber(factors, 'momentum_3m');
  if (
    price !== null &&
    price !== undefined &&
    sma50 !== null &&
    sma50 !== undefined &&
    sma200 !== null &&
    sma200 !== undefined
  ) {
    if (price > sma50 && sma50 > sma200 && (momentum ?? 0) >= 0)
      return 'Uptrend';
    if (price < sma50 && sma50 < sma200 && (momentum ?? 0) <= 0)
      return 'Downtrend';
  }
  return 'Mixed / transitional';
}

function inferHorizon(query: string) {
  if (/intraday|today|next day|明天|今天|日内/i.test(query)) return 'intraday';
  if (/week|周|短期/i.test(query)) return 'one to four weeks';
  if (/year|annual|一年|长期/i.test(query)) return 'six to twelve months';
  return 'one to three months';
}

function inferHorizonTradingDays(query: string) {
  if (/intraday|today|next day|明天|今天|日内/i.test(query)) return 1;
  if (/week|周|短期/i.test(query)) return 10;
  if (/year|annual|一年|长期/i.test(query)) return 126;
  return 21;
}

function quoteBrief(quote: MarketSignalQuote) {
  return {
    symbol: quote.symbol,
    name: quote.name,
    price: quote.price,
    changePct: quote.changePct,
    change5dPct: quote.change5dPct,
    change1mPct: quote.change1mPct,
    rsi14: quote.rsi14,
    deviation200Pct: quote.deviation200Pct,
    asOf: quote.asOf,
  };
}

function rankQuotes(quotes: MarketSignalQuote[]) {
  return [...quotes].sort(
    (left, right) =>
      Math.abs(right.change1mPct || 0) - Math.abs(left.change1mPct || 0)
  );
}

function displaySymbol(symbol: string) {
  const entry = Object.entries(DIRECT_SYMBOL_MAP).find(
    ([, mapped]) => mapped === symbol
  );
  return entry?.[0] || symbol;
}

function factorNumber(
  factors: Record<string, unknown>,
  key: string
): number | null {
  const value = factors[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function finiteOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function normalizeEpoch(value: number) {
  if (value > 1e17) return Math.floor(value / 1e6);
  if (value > 1e14) return Math.floor(value / 1e3);
  if (value < 1e12) return value * 1000;
  return value;
}

function signedPercent(value: number) {
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function round(value: number, digits: number) {
  const scale = 10 ** digits;
  return Math.round(value * scale) / scale;
}

async function timedFetch(url: string, init: RequestInit) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    return await fetch(url, {
      ...init,
      cache: 'no-store',
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}
