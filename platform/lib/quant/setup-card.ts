// 形态卡计算层 / Pure computation for the ZIG-ZAG setup card.
// 输入 daily OHLCV，输出一张卡所需的全部要素：指标、枢轴、磁吸剖面、
// 关键价位、情景路径、以及自然语言解读。这里不做任何 I/O。
//
// 口径说明（可调，集中在 SETUP_CARD_DEFAULTS）：
//   - Stretch / Down 是「按波动率缩放的量度目标」，不是固定百分比；
//     horizon 天数与 sigma 倍数决定它们离 LAST 多远。
//   - Resistance / Support 优先取磁吸剖面里的高成交量节点，
//     取不到再退回 ZigZag 枢轴聚类。
// 所有函数对短序列都返回安全值（null / 空数组），调用方无需自己防御。

export type Candle = {
  date: string; // ISO yyyy-mm-dd
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
};

export type RangeState = 'BULL' | 'BEAR' | 'NEUTRAL';
export type MomentumState = 'KNIFE' | 'FALLING' | 'FLAT' | 'RISING' | 'SPIKE';
export type MagnetRole =
  | 'stretch'
  | 'resistance'
  | 'last'
  | 'sma20'
  | 'support'
  | 'down';

export type ZigZagPivot = {
  index: number;
  price: number;
  kind: 'high' | 'low';
  /** 'A' / 'B' … 只标注最后两个枢轴，跟卡面一致。 */
  label: string | null;
};

export type MagnetBin = {
  low: number;
  high: number;
  mid: number;
  /** 全窗口成交量 */
  volume: number;
  /** 最近 N 根（默认 15）的成交量，卡面用金色画 */
  recentVolume: number;
  /** 相对 LAST 的位置：上方是供给，下方是需求 */
  side: 'supply' | 'demand';
};

export type MagnetProfile = {
  bins: MagnetBin[];
  /** 成交量最大的那一档中值 —— 卡面右侧那颗星 */
  pointOfControl: number;
  maxVolume: number;
  /** LAST 之下 / 之上的成交量质量，用于表头的 bottom / top */
  massBelow: number;
  massAbove: number;
};

export type MagnetRow = {
  role: MagnetRole;
  label: string;
  price: number;
  /** 相对 LAST 的距离，正数在上方 */
  distancePct: number;
  description: string;
};

export type ScenarioPath = {
  kind: 'bull' | 'base' | 'bear';
  /** 0..1 的水平进度 + 价格，交给渲染层做坐标变换 */
  points: { t: number; price: number }[];
  target: number;
};

export type MomentumReading = {
  state: MomentumState;
  /** 每日百分比速度 */
  velocityPctPerDay: number;
  /** 加速度：速度的变化，负数代表还在加速下跌 */
  acceleration: number;
  /** 归一化到 -1..1 的柱状序列，给子面板画填充 */
  series: number[];
  /** 平滑后的信号线 */
  signal: number[];
};

export type BollingerBands = {
  upper: (number | null)[];
  middle: (number | null)[];
  lower: (number | null)[];
  period: number;
  multiplier: number;
};

export type SetupCardInput = {
  symbol: string;
  candles: Candle[];
  /** ATM 隐含波动率（0..1），拿不到就传 null，卡面会隐藏该面板 */
  atmIv?: number | null;
  /** 5 日前的 ATM IV，用于算变化 */
  atmIvPrior?: number | null;
  /** 所属板块与其 5 日涨跌幅，用于表头的 headwind/tailwind */
  sector?: { name: string; changePct5d: number } | null;
  options?: Partial<typeof SETUP_CARD_DEFAULTS>;
};

export type SetupCard = {
  symbol: string;
  patternName: string;
  patternQualifier: string;
  state: RangeState;
  last: number;
  asOf: string | null;

  /** 清洗后的 K 线，渲染层直接拿来画蜡烛 */
  candles: Candle[];

  sma20: (number | null)[];
  bollinger: BollingerBands;
  rsi: (number | null)[];
  rsiNow: number | null;
  rsi5dChange: number | null;

  pivots: ZigZagPivot[];
  magnet: MagnetProfile;
  momentum: MomentumReading;

  levels: {
    stretch: number;
    resistance: number;
    support: number;
    down: number;
    sma20Now: number | null;
  };
  rows: MagnetRow[];
  scenarios: ScenarioPath[];

  volume: {
    bars: number[];
    average: number;
    /** 最新一根相对均量的倍数 */
    relative: number;
  };

  iv: { now: number | null; change5d: number | null };
  sector: { name: string; changePct5d: number } | null;

  /** 表头里 bottom / top 两个磁吸压力分 */
  pressure: { bottom: number; top: number };

  read: string[];
};

export const SETUP_CARD_DEFAULTS = {
  smaPeriod: 20,
  bollingerPeriod: 20,
  bollingerMultiplier: 2,
  rsiPeriod: 14,
  /** ZigZag 确认一个枢轴所需的最小回撤幅度 */
  zigzagThresholdPct: 4.5,
  /** 磁吸剖面的价格分档数 */
  magnetBins: 48,
  /** 用金色高亮的最近交易日数 */
  magnetRecentSessions: 15,
  /** 动量速度/加速度的回看窗口 */
  momentumLookback: 10,
  /** Stretch / Down 的投影天数 */
  projectionHorizonDays: 10,
  /** 投影用的 sigma 倍数 */
  projectionSigma: 1.0,
  /** 判定「区间清晰」所需的最少枢轴数 */
  minPivotsForRange: 4,
};

/* ------------------------------------------------------------------ */
/* 基础指标                                                             */
/* ------------------------------------------------------------------ */

export function computeSma(values: number[], period: number): (number | null)[] {
  if (period <= 0) return values.map(() => null);
  const out: (number | null)[] = new Array(values.length).fill(null);
  let sum = 0;
  for (let i = 0; i < values.length; i += 1) {
    sum += values[i];
    if (i >= period) sum -= values[i - period];
    if (i >= period - 1) out[i] = sum / period;
  }
  return out;
}

export function computeBollinger(
  values: number[],
  period: number,
  multiplier: number
): BollingerBands {
  const middle = computeSma(values, period);
  const upper: (number | null)[] = new Array(values.length).fill(null);
  const lower: (number | null)[] = new Array(values.length).fill(null);

  for (let i = period - 1; i < values.length; i += 1) {
    const mean = middle[i];
    if (mean === null) continue;
    let acc = 0;
    for (let j = i - period + 1; j <= i; j += 1) {
      const d = values[j] - mean;
      acc += d * d;
    }
    // 总体标准差，与多数看盘软件的 BB 口径一致
    const sd = Math.sqrt(acc / period);
    upper[i] = mean + multiplier * sd;
    lower[i] = mean - multiplier * sd;
  }
  return { upper, middle, lower, period, multiplier };
}

/** Wilder 平滑的 RSI。 */
export function computeRsi(values: number[], period: number): (number | null)[] {
  const out: (number | null)[] = new Array(values.length).fill(null);
  if (values.length <= period) return out;

  let gain = 0;
  let loss = 0;
  for (let i = 1; i <= period; i += 1) {
    const change = values[i] - values[i - 1];
    if (change >= 0) gain += change;
    else loss -= change;
  }
  let avgGain = gain / period;
  let avgLoss = loss / period;
  out[period] = rsiFrom(avgGain, avgLoss);

  for (let i = period + 1; i < values.length; i += 1) {
    const change = values[i] - values[i - 1];
    const g = change > 0 ? change : 0;
    const l = change < 0 ? -change : 0;
    avgGain = (avgGain * (period - 1) + g) / period;
    avgLoss = (avgLoss * (period - 1) + l) / period;
    out[i] = rsiFrom(avgGain, avgLoss);
  }
  return out;
}

function rsiFrom(avgGain: number, avgLoss: number): number {
  if (avgLoss === 0) return avgGain === 0 ? 50 : 100;
  const rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}

/**
 * ZigZag：只有当价格从当前候选极值反向走够 thresholdPct 才确认一个枢轴。
 * 返回的枢轴严格高低交替，最后两个带 'A' / 'B' 标签。
 */
export function computeZigZag(
  candles: Candle[],
  thresholdPct: number
): ZigZagPivot[] {
  if (candles.length < 3 || thresholdPct <= 0) return [];
  const threshold = thresholdPct / 100;
  const pivots: ZigZagPivot[] = [];

  // 用前几根确定初始方向
  let direction: 'up' | 'down' =
    candles[1].close >= candles[0].close ? 'up' : 'down';
  let extremeIndex = 0;
  let extremePrice = direction === 'up' ? candles[0].high : candles[0].low;

  for (let i = 1; i < candles.length; i += 1) {
    const bar = candles[i];
    if (direction === 'up') {
      if (bar.high >= extremePrice) {
        extremePrice = bar.high;
        extremeIndex = i;
      } else if (extremePrice > 0 && (extremePrice - bar.low) / extremePrice >= threshold) {
        pivots.push({ index: extremeIndex, price: extremePrice, kind: 'high', label: null });
        direction = 'down';
        extremePrice = bar.low;
        extremeIndex = i;
      }
    } else {
      if (bar.low <= extremePrice) {
        extremePrice = bar.low;
        extremeIndex = i;
      } else if (extremePrice > 0 && (bar.high - extremePrice) / extremePrice >= threshold) {
        pivots.push({ index: extremeIndex, price: extremePrice, kind: 'low', label: null });
        direction = 'up';
        extremePrice = bar.high;
        extremeIndex = i;
      }
    }
  }

  // 收尾的未确认摆动也画出来，否则最右边会缺一段
  const lastConfirmed = pivots[pivots.length - 1];
  if (!lastConfirmed || lastConfirmed.index !== extremeIndex) {
    pivots.push({
      index: extremeIndex,
      price: extremePrice,
      kind: direction === 'up' ? 'high' : 'low',
      label: null,
    });
  }

  // 卡面只给最后两个枢轴标 A / B
  if (pivots.length >= 2) {
    pivots[pivots.length - 2].label = 'A';
    pivots[pivots.length - 1].label = 'B';
  }
  return pivots;
}

/**
 * 磁吸剖面：把每根 K 线的成交量沿它的 high-low 均摊到价格分档里。
 * 均摊而不是只记 close，是因为宽幅震荡日的成交确实分布在整段价格上。
 */
export function computeMagnetProfile(
  candles: Candle[],
  last: number,
  binCount: number,
  recentSessions: number
): MagnetProfile {
  const empty: MagnetProfile = {
    bins: [],
    pointOfControl: last,
    maxVolume: 0,
    massBelow: 0,
    massAbove: 0,
  };
  if (candles.length === 0 || binCount <= 0) return empty;

  let lo = Infinity;
  let hi = -Infinity;
  for (const c of candles) {
    if (c.low < lo) lo = c.low;
    if (c.high > hi) hi = c.high;
  }
  if (!Number.isFinite(lo) || !Number.isFinite(hi) || hi <= lo) return empty;

  const width = (hi - lo) / binCount;
  const bins: MagnetBin[] = Array.from({ length: binCount }, (_, i) => {
    const binLow = lo + i * width;
    const binHigh = binLow + width;
    return {
      low: binLow,
      high: binHigh,
      mid: (binLow + binHigh) / 2,
      volume: 0,
      recentVolume: 0,
      side: (binLow + binHigh) / 2 >= last ? ('supply' as const) : ('demand' as const),
    };
  });

  const recentStart = Math.max(0, candles.length - recentSessions);
  for (let i = 0; i < candles.length; i += 1) {
    const c = candles[i];
    const span = Math.max(c.high - c.low, width * 0.5);
    const firstBin = clampIndex(Math.floor((c.low - lo) / width), binCount);
    const lastBin = clampIndex(Math.floor((c.high - lo) / width), binCount);
    const touched = lastBin - firstBin + 1;
    const share = c.volume / touched;
    for (let b = firstBin; b <= lastBin; b += 1) {
      bins[b].volume += share;
      if (i >= recentStart) bins[b].recentVolume += share;
    }
    void span;
  }

  let maxVolume = 0;
  let pocIndex = 0;
  let massBelow = 0;
  let massAbove = 0;
  for (let i = 0; i < bins.length; i += 1) {
    if (bins[i].volume > maxVolume) {
      maxVolume = bins[i].volume;
      pocIndex = i;
    }
    if (bins[i].mid < last) massBelow += bins[i].volume;
    else massAbove += bins[i].volume;
  }

  return {
    bins,
    pointOfControl: bins[pocIndex].mid,
    maxVolume,
    massBelow,
    massAbove,
  };
}

function clampIndex(i: number, length: number): number {
  if (i < 0) return 0;
  if (i > length - 1) return length - 1;
  return i;
}

/**
 * 动量：速度取近 lookback 天的日均百分比变化，加速度取
 * 后半段速度减前半段速度。两者都为负 = 还在加速下跌 = KNIFE。
 */
export function computeMomentum(
  closes: number[],
  lookback: number
): MomentumReading {
  const flat: MomentumReading = {
    state: 'FLAT',
    velocityPctPerDay: 0,
    acceleration: 0,
    series: [],
    signal: [],
  };
  if (closes.length < lookback * 2 || lookback < 2) return flat;

  const dailyPct: number[] = [];
  for (let i = 1; i < closes.length; i += 1) {
    const prev = closes[i - 1];
    dailyPct.push(prev === 0 ? 0 : ((closes[i] - prev) / prev) * 100);
  }

  const recent = dailyPct.slice(-lookback);
  const previous = dailyPct.slice(-lookback * 2, -lookback);
  const velocity = mean(recent);
  const acceleration = velocity - mean(previous);

  // 子面板画的是 lookback 长度的滚动平均，归一化到 -1..1
  const rolling = computeSma(dailyPct, lookback).map((v) => v ?? 0);
  const scale = Math.max(...rolling.map((v) => Math.abs(v)), 1e-9);
  const series = rolling.map((v) => v / scale);
  const signal = computeSma(series, Math.max(2, Math.round(lookback / 2))).map(
    (v) => v ?? 0
  );

  let state: MomentumState = 'FLAT';
  if (velocity < -0.5 && acceleration < 0) state = 'KNIFE';
  else if (velocity < -0.15) state = 'FALLING';
  else if (velocity > 0.5 && acceleration > 0) state = 'SPIKE';
  else if (velocity > 0.15) state = 'RISING';

  return { state, velocityPctPerDay: velocity, acceleration, series, signal };
}

function mean(values: number[]): number {
  if (values.length === 0) return 0;
  let sum = 0;
  for (const v of values) sum += v;
  return sum / values.length;
}

/** 年化实现波动率，用于把 Stretch / Down 缩放到合理距离。 */
export function realizedVolatility(closes: number[], lookback = 20): number {
  if (closes.length < lookback + 1) return 0;
  const rets: number[] = [];
  for (let i = closes.length - lookback; i < closes.length; i += 1) {
    const prev = closes[i - 1];
    if (prev > 0) rets.push(Math.log(closes[i] / prev));
  }
  if (rets.length < 2) return 0;
  const m = mean(rets);
  let acc = 0;
  for (const r of rets) acc += (r - m) * (r - m);
  const sd = Math.sqrt(acc / (rets.length - 1));
  return sd * Math.sqrt(252);
}

/* ------------------------------------------------------------------ */
/* 关键价位                                                             */
/* ------------------------------------------------------------------ */

/**
 * 阻力 / 支撑：先在磁吸剖面里找 LAST 上下最重的成交量节点，
 * 找不到（比如剖面太薄）再退回 ZigZag 枢轴。
 */
export function detectLevels(
  candles: Candle[],
  magnet: MagnetProfile,
  pivots: ZigZagPivot[],
  last: number
): { resistance: number; support: number } {
  const above = magnet.bins.filter((b) => b.mid > last * 1.005);
  const below = magnet.bins.filter((b) => b.mid < last * 0.995);

  const heaviest = (bins: MagnetBin[]): number | null => {
    if (bins.length === 0) return null;
    let best = bins[0];
    for (const b of bins) if (b.volume > best.volume) best = b;
    return best.volume > 0 ? best.mid : null;
  };

  const pivotHigh = pivots
    .filter((p) => p.kind === 'high' && p.price > last)
    .map((p) => p.price)
    .sort((a, b) => a - b)[0];
  const pivotLow = pivots
    .filter((p) => p.kind === 'low' && p.price < last)
    .map((p) => p.price)
    .sort((a, b) => b - a)[0];

  const highs = candles.map((c) => c.high);
  const lows = candles.map((c) => c.low);

  const resistance =
    heaviest(above) ?? pivotHigh ?? Math.max(...highs, last * 1.05);
  const support = heaviest(below) ?? pivotLow ?? Math.min(...lows, last * 0.95);

  return { resistance, support };
}

/**
 * Stretch / Down 是按波动率缩放的量度目标，不是写死的百分比：
 *   move = last * sigma_annual * sqrt(horizon / 252) * sigmaMultiple
 * 上方目标至少落在阻力之上，下方目标至少落在支撑之下，
 * 否则「突破目标」会画在区间里面，没有意义。
 */
export function projectTargets(
  last: number,
  closes: number[],
  resistance: number,
  support: number,
  horizonDays: number,
  sigmaMultiple: number
): { stretch: number; down: number } {
  const sigma = realizedVolatility(closes);
  const move = last * sigma * Math.sqrt(horizonDays / 252) * sigmaMultiple;
  const fallback = last * 0.05;
  const size = move > 0 ? move : fallback;
  return {
    stretch: Math.max(last + size, resistance * 1.01),
    down: Math.min(last - size, support * 0.99),
  };
}

export function buildScenarioPaths(
  last: number,
  stretch: number,
  down: number,
  sma20Now: number | null
): ScenarioPath[] {
  const base = sma20Now ?? last;
  const curve = (target: number, sag: number): { t: number; price: number }[] => [
    { t: 0, price: last },
    { t: 0.5, price: last + (target - last) * sag },
    { t: 1, price: target },
  ];
  return [
    { kind: 'bull', points: curve(stretch, 0.35), target: stretch },
    { kind: 'base', points: curve(base, 0.6), target: base },
    { kind: 'bear', points: curve(down, 0.35), target: down },
  ];
}

/* ------------------------------------------------------------------ */
/* 组装                                                                 */
/* ------------------------------------------------------------------ */

export function buildSetupCard(input: SetupCardInput): SetupCard | null {
  const opts = { ...SETUP_CARD_DEFAULTS, ...(input.options ?? {}) };
  const candles = input.candles.filter(
    (c) =>
      Number.isFinite(c.open) &&
      Number.isFinite(c.high) &&
      Number.isFinite(c.low) &&
      Number.isFinite(c.close)
  );
  if (candles.length < opts.smaPeriod + 2) return null;

  const closes = candles.map((c) => c.close);
  const last = closes[closes.length - 1];
  if (!Number.isFinite(last) || last <= 0) return null;

  const sma20 = computeSma(closes, opts.smaPeriod);
  const bollinger = computeBollinger(
    closes,
    opts.bollingerPeriod,
    opts.bollingerMultiplier
  );
  const rsi = computeRsi(closes, opts.rsiPeriod);
  const rsiNow = rsi[rsi.length - 1];
  const rsiPrior = rsi[rsi.length - 6] ?? null;
  const rsi5dChange =
    rsiNow !== null && rsiPrior !== null ? rsiNow - rsiPrior : null;

  const pivots = computeZigZag(candles, opts.zigzagThresholdPct);
  const magnet = computeMagnetProfile(
    candles,
    last,
    opts.magnetBins,
    opts.magnetRecentSessions
  );
  const momentum = computeMomentum(closes, opts.momentumLookback);
  const { resistance, support } = detectLevels(candles, magnet, pivots, last);
  const { stretch, down } = projectTargets(
    last,
    closes,
    resistance,
    support,
    opts.projectionHorizonDays,
    opts.projectionSigma
  );
  const sma20Now = sma20[sma20.length - 1];

  const span = resistance - support;
  const position = span > 0 ? (last - support) / span : 0.5;
  const state: RangeState =
    position >= 0.7 ? 'BULL' : position <= 0.3 ? 'BEAR' : 'NEUTRAL';

  const volumes = candles.map((c) => c.volume);
  const volumeWindow = volumes.slice(-opts.magnetRecentSessions);
  const volumeAverage = mean(volumeWindow);
  const relative =
    volumeAverage > 0 ? volumes[volumes.length - 1] / volumeAverage : 0;

  const rows = buildRows({ stretch, resistance, last, sma20Now, support, down });

  const totalMass = magnet.massBelow + magnet.massAbove;
  const pressure = {
    bottom: totalMass > 0 ? (magnet.massBelow / totalMass) * 10 : 0,
    top: totalMass > 0 ? (magnet.massAbove / totalMass) * 10 : 0,
  };

  const iv = {
    now: input.atmIv ?? null,
    change5d:
      input.atmIv != null && input.atmIvPrior != null
        ? (input.atmIv - input.atmIvPrior) * 100
        : null,
  };

  const wellDefined = pivots.length >= opts.minPivotsForRange && span > 0;

  const card: SetupCard = {
    symbol: input.symbol,
    patternName: 'ZIG-ZAG',
    patternQualifier: wellDefined ? 'well-defined range' : 'forming range',
    state,
    last,
    asOf: candles[candles.length - 1]?.date ?? null,
    candles,
    sma20,
    bollinger,
    rsi,
    rsiNow,
    rsi5dChange,
    pivots,
    magnet,
    momentum,
    levels: { stretch, resistance, support, down, sma20Now },
    rows,
    scenarios: buildScenarioPaths(last, stretch, down, sma20Now),
    volume: { bars: volumes, average: volumeAverage, relative },
    iv,
    sector: input.sector ?? null,
    pressure,
    read: [],
  };

  card.read = buildRead(card);
  return card;
}

function buildRows(levels: {
  stretch: number;
  resistance: number;
  last: number;
  sma20Now: number | null;
  support: number;
  down: number;
}): MagnetRow[] {
  const { last } = levels;
  const dist = (price: number) => ((price - last) / last) * 100;
  const rows: MagnetRow[] = [
    {
      role: 'stretch',
      label: '↑ Stretch',
      price: levels.stretch,
      distancePct: dist(levels.stretch),
      description: 'upside measured-move target',
    },
    {
      role: 'resistance',
      label: 'Resistance',
      price: levels.resistance,
      distancePct: dist(levels.resistance),
      description: 'supply — break-UP trigger',
    },
    {
      role: 'last',
      label: 'LAST',
      price: last,
      distancePct: 0,
      description: 'current price',
    },
  ];
  if (levels.sma20Now !== null) {
    rows.push({
      role: 'sma20',
      label: 'SMA20',
      price: levels.sma20Now,
      distancePct: dist(levels.sma20Now),
      description: 'dynamic magnet (20-day mean)',
    });
  }
  rows.push(
    {
      role: 'support',
      label: 'Support',
      price: levels.support,
      distancePct: dist(levels.support),
      description: 'demand — break-DOWN trigger',
    },
    {
      role: 'down',
      label: '↓ Down',
      price: levels.down,
      distancePct: dist(levels.down),
      description: 'downside measured-move risk',
    }
  );
  // 固定角色顺序（Stretch → Resistance → LAST → SMA20 → Support → Down），
  // 不按价格排序：SMA20 在跌破均线时价格高于 LAST，但读者仍然期望
  // 它排在 LAST 下面的「动态磁吸」位置上。
  return rows;
}

/** 把算出来的状态翻译成卡片下方那几条 bullet。 */
export function buildRead(card: SetupCard): string[] {
  const out: string[] = [];
  const pct = (v: number) => `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`;
  const { support, resistance, stretch, down } = card.levels;
  const supportDist = ((support - card.last) / card.last) * 100;
  const resistanceDist = ((resistance - card.last) / card.last) * 100;

  out.push(
    `${card.symbol} is ranging between S ${support.toFixed(2)} (${pct(
      supportDist
    )}) and R ${resistance.toFixed(2)} (${pct(
      resistanceDist
    )}) — no edge until one side breaks.`
  );
  out.push(
    `Range plays: fade the edges, or wait for the break (targets ${stretch.toFixed(
      2
    )} up / ${down.toFixed(2)} down).`
  );

  if (card.rsiNow !== null) {
    if (card.rsiNow <= 30) {
      out.push(
        `RSI ${card.rsiNow.toFixed(
          0
        )} is washed out — watch for a hammer/reclaim to time the bounce.`
      );
    } else if (card.rsiNow >= 70) {
      out.push(
        `RSI ${card.rsiNow.toFixed(
          0
        )} is stretched — chasing here pays the worst entry.`
      );
    } else {
      out.push(`RSI ${card.rsiNow.toFixed(0)} is mid-range — no momentum edge.`);
    }
  }

  if (card.sector) {
    const bleeding = card.sector.changePct5d < 0;
    out.push(
      `${bleeding ? 'Headwind' : 'Tailwind'}: ${card.sector.name} is ${
        bleeding ? 'bleeding' : 'leading'
      } (${pct(card.sector.changePct5d)} 5d).`
    );
  }

  if (card.momentum.state === 'KNIFE') {
    out.push(
      `⚠ The decline is still ACCELERATING (v ${card.momentum.velocityPctPerDay.toFixed(
        2
      )}%/d and getting worse) — falling knife; bounces from here have been the weakest bucket. Wait for the brake.`
    );
  } else if (card.momentum.state === 'SPIKE') {
    out.push(
      `Momentum is ACCELERATING up (v ${card.momentum.velocityPctPerDay.toFixed(
        2
      )}%/d) — late entries carry the gap risk.`
    );
  }

  if (card.iv.now !== null) {
    const ivPct = (card.iv.now * 100).toFixed(0);
    if (card.iv.change5d !== null) {
      const draining = card.iv.change5d < 0;
      out.push(
        `Options fear gauge: ATM IV ${ivPct}%, ${card.iv.change5d.toFixed(
          1
        )} pts over 5d — ${
          draining
            ? 'draining — options getting cheaper, fear easing'
            : 'building — options getting richer, fear rising'
        }.`
      );
    } else {
      out.push(`Options fear gauge: ATM IV ${ivPct}%.`);
    }
  }

  const patterns: string[] = [];
  if (card.momentum.state === 'KNIFE') patterns.push('falling-knife⚠');
  if (card.rsiNow !== null && card.rsiNow <= 30) patterns.push('oversold');
  if (card.rsiNow !== null && card.rsiNow >= 70) patterns.push('overbought');
  if (card.state === 'NEUTRAL') patterns.push('range-bound');
  if (patterns.length > 0) out.push(`Patterns on: ${patterns.join(', ')}.`);

  return out;
}
