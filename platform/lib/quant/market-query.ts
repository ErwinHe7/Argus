import type {
  MarketQueryV1,
  MarketSetupType,
} from '@/lib/forecast-chat-types';

const RESERVED = new Set([
  'AI',
  'API',
  'AXIO',
  'AXIO7',
  'CALL',
  'CALLS',
  'DTE',
  'ETF',
  'FED',
  'GAMMA',
  'GEX',
  'K',
  'KLINE',
  'MODEL',
  'OI',
  'PUT',
  'PUTS',
  'SIP',
  'SPX',
  'NDX',
  'THE',
  'VWAP',
]);

const NAME_ALIASES: Array<[RegExp, string]> = [
  [/\bSPX\b|S&P\s*500|标普(?:500)?|大盘/i, 'SPX'],
  [/\bNDX\b|NASDAQ\s*100|纳斯达克100|纳指/i, 'QQQ'],
  [/\bNVIDIA\b|英伟达/i, 'NVDA'],
  [/\bAPPLE\b|苹果/i, 'AAPL'],
  [/\bMICRON\b|美光/i, 'MU'],
];

const GAMMA_DEFAULT_UNIVERSE = [
  'SPX',
  'QQQ',
  'NVDA',
  'AAPL',
  'MU',
  'SOXX',
  'NBIS',
  'BE',
  'IGV',
];

const INDEX_DEFAULT_UNIVERSE = ['SPX', 'QQQ', 'SOXX'];
const PUBLIC_UNIVERSE = new Set(GAMMA_DEFAULT_UNIVERSE);
type Direction = 'down' | 'up';
type HorizonMinutes = 5 | 15 | 30 | 60;

export class UnsupportedScheduledEventModelError extends Error {
  readonly code = 'SCHEDULED_EVENT_MODEL_NOT_READY' as const;
  readonly eventKind: 'fomc_macro' | 'earnings';

  constructor(eventKind: 'fomc_macro' | 'earnings') {
    const requirement =
      eventKind === 'earnings'
        ? 'a versioned point-in-time earnings calendar plus licensed historical consensus and surprise inputs'
        : 'a versioned point-in-time macro calendar plus causal market-implied and official-release inputs';
    super(
      `AXIO7 will not route this scheduled-event forecast through the intraday price model. The ${eventKind} event atlas is not promoted and requires ${requirement}.`
    );
    this.name = 'UnsupportedScheduledEventModelError';
    this.eventKind = eventKind;
  }
}

export class MarketQueryClarificationError extends Error {
  readonly code = 'MARKET_QUERY_NEEDS_CLARIFICATION' as const;
  readonly setupType: Exclude<MarketSetupType, 'model_forecast'> | null;
  readonly symbols: string[];
  readonly missingFields: Array<
    'setup_type' | 'direction' | 'horizon_minutes'
  >;
  readonly allowedValues = {
    setup_type: [
      'momentum',
      'gamma_squeeze',
      'vwap_reversal',
      'opening_turn',
      'closing_short_cover',
      'statistical_dislocation',
    ] as const,
    direction: ['up', 'down'] as const,
    horizon_minutes: [5, 15, 30, 60] as const,
  };

  constructor(input: {
    setupType: Exclude<MarketSetupType, 'model_forecast'> | null;
    symbols: string[];
    missingFields: Array<
      'setup_type' | 'direction' | 'horizon_minutes'
    >;
  }) {
    const missing = input.missingFields
      .map((field) =>
        field === 'setup_type'
          ? 'a named historical rule'
          : field === 'direction'
          ? 'a bullish/up or bearish/down direction'
          : 'a 5, 15, 30, or 60 minute horizon'
      )
      .join(' and ');
    super(
      `Please specify ${missing}${
        input.setupType
          ? ` for the ${input.setupType.replaceAll('_', ' ')} rule`
          : ''
      }. AXIO7 will not invent those assumptions or substitute an unrelated historical rule.`
    );
    this.name = 'MarketQueryClarificationError';
    this.setupType = input.setupType;
    this.symbols = input.symbols;
    this.missingFields = input.missingFields;
  }
}

function unsupportedScheduledEventPrediction(
  text: string
): 'fomc_macro' | 'earnings' | null {
  const asksForPrediction =
    /predict|forecast|tomorrow|next\s+(?:day|session)|market\s+(?:move|reaction)|what\s+will\s+happen|\u9884(?:\u6d4b|\u5224)|\u660e\u5929|\u540e\u5929|\u8d70\u52bf|\u6da8\u8dcc|\u5e02\u573a\u53cd\u5e94|\u4f1a.{0,6}(?:\u6da8|\u8dcc)/i.test(
      text
    );
  if (!asksForPrediction) return null;
  if (
    /\b(?:FOMC|CPI|PPI|NFP|FED)\b|federal\s+reserve|nonfarm|payroll|rate\s+decision|\u7f8e\u8054\u50a8|\u8054\u50a8|\u5229\u7387\u51b3\u8bae|\u975e\u519c|\u901a\u80c0|\u5b8f\u89c2/i.test(
      text
    )
  ) {
    return 'fomc_macro';
  }
  if (
    /\bearnings\b|earnings\s+surprise|quarterly\s+results|\bEPS\b|\u8d22\u62a5|\u4e1a\u7ee9|\u8425\u6536|\u76c8\u5229\u9884\u671f/i.test(
      text
    )
  ) {
    return 'earnings';
  }
  return null;
}

function normalizeUniverseSymbol(raw: string) {
  const symbol = raw
    .trim()
    .replace(/^\$/, '')
    .replace(/^US\./i, '')
    .toUpperCase();
  return symbol;
}

function inferSetupType(text: string): MarketSetupType {
  if (/gamma|gex|squeeze|伽马|挤压|call\s*wall/i.test(text)) {
    return 'gamma_squeeze';
  }
  if (
    /momentum|动量|趋势延续|加速上涨|加速下跌|强势突破|持续走强|持续走弱/i.test(
      text
    )
  ) {
    return 'momentum';
  }
  if (/vwap|成交量加权|均价.*转折|转折.*均价/i.test(text)) {
    return 'vwap_reversal';
  }
  if (/short\s*cover|空头回补|逼空回补|尾盘回补/i.test(text)) {
    return 'closing_short_cover';
  }
  if (
    /statistical\s*(?:dislocation|anomaly)|market\s*dislocation|统计(?:性)?(?:错位|异常)|市场错位/i.test(
      text
    )
  ) {
    return 'statistical_dislocation';
  }
  if (
    /开盘.{0,12}(?:第.{0,4}根|买盘|衰竭|转折)|opening.{0,20}(?:bar|exhaustion|turn|window)|买盘衰竭|exhaustion|turning\s*(?:point|window)?/i.test(
      text
    )
  ) {
    return 'opening_turn';
  }
  return 'model_forecast';
}

function inferHorizon(text: string): HorizonMinutes | undefined {
  const explicit = text.match(
    /(?:未来|接下来|next|within)\s*(5|15|30|60)\s*(?:m|min|minutes?|分钟)/i
  );
  if (explicit) return Number(explicit[1]) as HorizonMinutes;
  const standalone = text.match(
    /\b(5|15|30|60)\s*(?:-\s*)?(?:m|min|minutes?)\b/i
  );
  if (standalone) return Number(standalone[1]) as HorizonMinutes;
  const chineseStandalone = text.match(/(?:^|\D)(5|15|30|60)\s*分钟/i);
  if (chineseStandalone) {
    return Number(chineseStandalone[1]) as HorizonMinutes;
  }
  if (/一小时|1\s*hour|hourly/i.test(text)) return 60;
  if (/半小时|half\s*hour/i.test(text)) return 30;
  return undefined;
}

function inferDirection(text: string): Direction | undefined {
  const upward =
    /上涨|向上|反弹|站回|看多|多头|reclaim|upside|upward|bullish|\blong\b/i.test(
      text
    );
  const downward =
    /下跌|向下|买盘.*不足|衰竭|跌破|看空|空头|downside|downward|bearish/i.test(
      text
    );
  if (upward === downward) return undefined;
  return upward ? 'up' : 'down';
}

function inferMaxDte(text: string) {
  if (/\b0\s*DTE\b|当天到期|零日到期/i.test(text)) return 0;
  const match = text.match(/(?:DTE|到期|未来)\s*(?:<=|≤|不超过|within)?\s*(\d{1,2})\s*(?:天|days?)?/i);
  return match ? Math.min(60, Math.max(0, Number(match[1]))) : 14;
}

function inferSymbols(
  text: string,
  requested: string[],
  setupType: MarketSetupType
) {
  const symbols = new Set<string>();
  for (const raw of requested) {
    const symbol = normalizeUniverseSymbol(raw);
    if (PUBLIC_UNIVERSE.has(symbol)) symbols.add(symbol);
  }
  for (const [pattern, symbol] of NAME_ALIASES) {
    if (pattern.test(text)) symbols.add(symbol);
  }
  for (const match of text.matchAll(/\$([A-Za-z][A-Za-z0-9.]{0,9})\b/g)) {
    const symbol = normalizeUniverseSymbol(match[1]);
    if (PUBLIC_UNIVERSE.has(symbol)) symbols.add(symbol);
  }
  const normalizedStandalone = normalizeUniverseSymbol(text);
  for (const raw of text.match(/\b[A-Za-z][A-Za-z0-9.]{1,9}\b/g) || []) {
    const symbol = normalizeUniverseSymbol(raw);
    const explicitlyUppercase = raw === raw.toUpperCase();
    const unambiguousLowercaseSymbol = symbol !== 'BE';
    const standaloneSymbol = normalizedStandalone === symbol;
    if (
      !RESERVED.has(symbol) &&
      PUBLIC_UNIVERSE.has(symbol) &&
      (explicitlyUppercase || unambiguousLowercaseSymbol || standaloneSymbol)
    ) {
      symbols.add(symbol);
    }
  }
  if (symbols.size === 0) {
    const defaults =
      setupType === 'gamma_squeeze' ||
      setupType === 'momentum' ||
      setupType === 'model_forecast' ||
      setupType === 'statistical_dislocation'
        ? GAMMA_DEFAULT_UNIVERSE
        : INDEX_DEFAULT_UNIVERSE;
    defaults.forEach((symbol) => symbols.add(symbol));
  }
  return Array.from(symbols).slice(0, 20);
}

export function requestsMarketMonitor(text: string) {
  return /monitor|watch|alert|notify|监测|监控|盯盘|提醒|持续扫描|自动扫描/i.test(
    text
  );
}

export function inferMonitorCadenceMinutes(
  text: string
): 5 | 15 | 30 | 60 {
  if (
    /(?:every|each|每)\s*(?:60\s*(?:min(?:ute)?s?|分钟)|1\s*(?:hour|hr|小时))|hourly|每小时/i.test(
      text
    )
  ) {
    return 60;
  }
  if (/(?:every|each|每)\s*30\s*(?:min(?:ute)?s?|分钟)/i.test(text)) {
    return 30;
  }
  if (/(?:every|each|每)\s*15\s*(?:min(?:ute)?s?|分钟)/i.test(text)) {
    return 15;
  }
  return 5;
}

export function compileMarketQuery(
  text: string,
  requestedSymbols: string[] = []
): { query: MarketQueryV1; notes: string[] } {
  const unsupportedEvent = unsupportedScheduledEventPrediction(text);
  if (unsupportedEvent) {
    throw new UnsupportedScheduledEventModelError(unsupportedEvent);
  }
  const setupType = inferSetupType(text);
  const wantsBacktest =
    /回测|历史验证|historical\s*(?:test|backtest)|backtest/i.test(text);
  const wantsLive =
    /现在|实时|今天|盘中|当前|预测|live|now|today|scan|forecast|predict/i.test(
      text
    );
  const direction = inferDirection(text);
  const horizon = inferHorizon(text);
  const symbols = inferSymbols(text, requestedSymbols, setupType);
  if (wantsBacktest && setupType === 'model_forecast') {
    const missingFields: Array<
      'setup_type' | 'direction' | 'horizon_minutes'
    > = ['setup_type'];
    if (direction === undefined) missingFields.push('direction');
    if (horizon === undefined) missingFields.push('horizon_minutes');
    throw new MarketQueryClarificationError({
      setupType: null,
      symbols,
      missingFields,
    });
  }
  if (setupType !== 'model_forecast') {
    const missingFields: Array<'direction' | 'horizon_minutes'> = [];
    if (direction === undefined) missingFields.push('direction');
    if (horizon === undefined) missingFields.push('horizon_minutes');
    if (missingFields.length > 0) {
      throw new MarketQueryClarificationError({
        setupType,
        symbols,
        missingFields,
      });
    }
  }
  const notes: string[] = [];
  const chinese = /[\u3400-\u9fff]/.test(text);
  if (/\bSPX\b|标普(?:500)?|大盘/i.test(text) && symbols.includes('SPX')) {
    notes.push(
      chinese
        ? 'SPX 本身没有集中成交量；盘中量价与 VWAP 研究使用 SPY 作为明确的数据代理。'
        : 'SPX has no centralized traded volume; intraday price/volume and VWAP research uses SPY as the explicit data proxy.'
    );
  }
  if (setupType === 'gamma_squeeze') {
    notes.push(
      chinese
        ? 'Gamma 查询要求完整、实时、具备 OI 与 Greeks 的 OPRA 期权链；缺一项即拒绝排名。'
        : 'Gamma research requires a complete realtime OPRA chain with OI and Greeks; AXIO7 withholds the result when any required field is absent.'
    );
  }
  const intent =
    wantsBacktest && !wantsLive
      ? 'backtest'
      : requestsMarketMonitor(text)
        ? 'scan'
        : setupType === 'model_forecast'
          ? 'forecast'
          : 'scan';
  return {
    query: {
      version: 'axio.market-query.v2',
      intent,
      setup_type: setupType,
      symbols,
      ...(horizon === undefined ? {} : { horizon_minutes: horizon }),
      limit: Math.min(10, symbols.length),
      filters: {
        ...(setupType === 'model_forecast' || direction === undefined
          ? {}
          : { direction }),
        require_realtime: !(wantsBacktest && !wantsLive),
        include_historical: wantsBacktest,
        max_data_age_seconds: 120,
        max_dte: inferMaxDte(text),
        maximum_option_spread_pct: 0.15,
        minimum_option_quote_coverage: 0.8,
      },
    },
    notes,
  };
}
