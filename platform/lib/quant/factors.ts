// 量化因子库 / Factor library for the QUANT TRADING module.
// 每个因子接收一段历史价格 + 成交量（或基本面快照），返回一个原始数值。
// 因子要求：deterministic、无 look-ahead、可在 scanner 与 backtest 中复用。
//
// 因子分类对照（中文 / category）：
//   动量    momentum      （趋势延续）
//   均值回归 mean reversion（短期超跌反弹）
//   趋势    trend          （SMA 多空排列）
//   波动率  volatility    （历史波动 + 波动扩张）
//   资金流  flow           （成交量异动 / 流动性）
//   价值    value          （earnings yield = 1/PE）
//   质量    quality        （盈利能力 - 占位，需基本面数据接入）

export type FactorScores = {
  // === 动量类 momentum ===
  momentum_12_1: number | null;       // 12-1月 经典动量
  momentum_3m: number | null;         // 3月动量
  momentum_1m: number | null;         // 1月动量
  momentum_consistency_60: number | null; // 60日内上涨日比例（动量"干净度"）

  // === 均值回归 mean reversion ===
  meanReversion_5d: number | null;    // 最近5天反向收益

  // === 趋势 trend ===
  rsi14: number | null;
  trend_sma50_200: number | null;     // SMA50 / SMA200 - 1
  gap_from_52w_high: number | null;   // 当前价距52周高点（高=接近高位）

  // === 波动率 volatility ===
  vol_realized_20: number | null;     // 20日年化已实现波动
  vol_zscore_20_60: number | null;    // 20日 vs 60日 波动扩张

  // === 资金流 flow ===
  liquidity_dollar_vol: number | null; // log10(20日均美元成交额)
  volume_surge_5_30: number | null;    // 5日均成交 / 30日均成交 - 1

  // === 价值 value (来自基本面) ===
  value_earningsYield: number | null;  // 1 / trailingPE；高=便宜

  // === 质量 quality (来自基本面，占位) ===
  quality_profitMargin: number | null; // 净利润率
};

export type FundamentalsSnapshot = {
  trailingPE: number | null;
  forwardPE: number | null;
  profitMargin: number | null;
  marketCap: number | null;
};

export type FactorWeights = Partial<Record<keyof FactorScores, number>>;

// 默认权重 — 不是 curve-fit 的产物，是一个有解释性的起点。
// 正权重 = 该因子高分倾向看多；负权重 = 该因子高分倾向减仓。
export const QUANT_DEFAULT_WEIGHTS: Required<FactorWeights> = {
  // 动量族 - 主驱动
  momentum_12_1: 0.22,
  momentum_3m: 0.12,
  momentum_1m: 0.08,
  momentum_consistency_60: 0.08,

  // 均值回归 - 反向小权重
  meanReversion_5d: 0.08,

  // 趋势
  trend_sma50_200: 0.16,
  gap_from_52w_high: 0.06,
  rsi14: -0.04,        // 偏过热扣分

  // 波动率（负权重 = 高波动扣分）
  vol_realized_20: -0.08,
  vol_zscore_20_60: -0.04,

  // 资金流
  liquidity_dollar_vol: 0.06,
  volume_surge_5_30: 0.08,

  // 价值（earnings yield 越高越便宜 = 加分）
  value_earningsYield: 0.08,

  // 质量
  quality_profitMargin: 0.04,
};

// 因子元数据 — 给 UI 用，让用户能一眼看懂每个因子在干什么。
export type FactorMeta = {
  key: keyof FactorScores;
  label: string;       // 短中文名
  category: '动量' | '均值回归' | '趋势' | '波动率' | '资金流' | '价值' | '质量';
  formula: string;     // 一行公式或定义
  direction: '高分看多' | '高分看空' | '中性';
  status: '已接入' | '数据待接入';
  source: string;      // 数据来源
};

export const FACTOR_META: FactorMeta[] = [
  { key: 'momentum_12_1', label: '12-1月动量', category: '动量',
    formula: 'close[-21] / close[-252] - 1', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'momentum_3m', label: '3月动量', category: '动量',
    formula: 'close[今] / close[63天前] - 1', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'momentum_1m', label: '1月动量', category: '动量',
    formula: 'close[今] / close[21天前] - 1', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'momentum_consistency_60', label: '60日上涨比例', category: '动量',
    formula: '过去60交易日中收阳线的比例', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'meanReversion_5d', label: '5日反向', category: '均值回归',
    formula: '-(close[今] / close[5天前] - 1)', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'trend_sma50_200', label: 'SMA50/200 趋势', category: '趋势',
    formula: 'SMA50 / SMA200 - 1', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'gap_from_52w_high', label: '52周高位距离', category: '趋势',
    formula: 'close[今] / max(close[过去252天])', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'rsi14', label: 'RSI(14)', category: '趋势',
    formula: '14日相对强弱指标', direction: '高分看空', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'vol_realized_20', label: '20日年化波动', category: '波动率',
    formula: 'stdev(log returns, 20d) × √252', direction: '高分看空', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'vol_zscore_20_60', label: '波动扩张 20/60', category: '波动率',
    formula: 'vol_20d / vol_60d - 1', direction: '高分看空', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'liquidity_dollar_vol', label: '流动性 log10$V', category: '资金流',
    formula: 'log10(20日均成交额, 美元)', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'volume_surge_5_30', label: '5/30 成交异动', category: '资金流',
    formula: '5日均成交 / 30日均成交 - 1', direction: '高分看多', status: '已接入', source: 'Yahoo daily bars' },
  { key: 'value_earningsYield', label: '盈利收益率 1/PE', category: '价值',
    formula: '1 / trailingPE（仅正值）', direction: '高分看多', status: '已接入', source: 'Yahoo quoteSummary' },
  { key: 'quality_profitMargin', label: '净利润率', category: '质量',
    formula: 'profitMargin (TTM)', direction: '高分看多', status: '数据待接入', source: 'Yahoo quoteSummary（部分股票可能为空）' },
];

export function computeFactorScores(
  closes: number[],
  volumes: number[] = [],
  fundamentals: FundamentalsSnapshot | null = null
): FactorScores {
  return {
    momentum_12_1: priceMomentum(closes, 252, 21),
    momentum_3m: priceMomentum(closes, 63, 0),
    momentum_1m: priceMomentum(closes, 21, 0),
    momentum_consistency_60: momentumConsistency(closes, 60),
    meanReversion_5d: meanReversion(closes, 5),
    rsi14: rsi(closes, 14),
    trend_sma50_200: trendRatio(closes, 50, 200),
    gap_from_52w_high: gapFromHigh(closes, 252),
    vol_realized_20: realizedVol(closes, 20),
    vol_zscore_20_60: volExpansion(closes, 20, 60),
    liquidity_dollar_vol: liquidityScore(closes, volumes, 20),
    volume_surge_5_30: volumeSurge(volumes, 5, 30),
    value_earningsYield: earningsYield(fundamentals),
    quality_profitMargin: fundamentals?.profitMargin ?? null,
  };
}

export type ScoredTicker = {
  ticker: string;
  raw: FactorScores;
  z: FactorScores;
  composite: number; // 加权 z-score 总和
  rank: number;      // 1 = 最高
};

// 横截面排名 — z-score 每个因子后加权求和。
export function rankUniverse(
  rows: Array<{ ticker: string; raw: FactorScores }>,
  weights: Required<FactorWeights> = QUANT_DEFAULT_WEIGHTS
): ScoredTicker[] {
  if (rows.length === 0) return [];

  const factorKeys = Object.keys(weights) as Array<keyof FactorScores>;
  const stats: Record<string, { mean: number; std: number }> = {};

  for (const key of factorKeys) {
    const values = rows.map((r) => r.raw[key]).filter((v): v is number => Number.isFinite(v as number));
    if (values.length === 0) {
      stats[key] = { mean: 0, std: 1 };
      continue;
    }
    const mean = values.reduce((s, v) => s + v, 0) / values.length;
    const variance = values.reduce((s, v) => s + (v - mean) ** 2, 0) / Math.max(1, values.length - 1);
    const std = Math.sqrt(variance) || 1;
    stats[key] = { mean, std };
  }

  const scored = rows.map((r) => {
    const z: FactorScores = {} as FactorScores;
    let composite = 0;
    for (const key of factorKeys) {
      const raw = r.raw[key];
      if (raw === null || !Number.isFinite(raw)) {
        z[key] = null;
        continue;
      }
      const zVal = (raw - stats[key].mean) / stats[key].std;
      const clipped = Math.max(-3, Math.min(3, zVal));
      z[key] = clipped;
      composite += clipped * weights[key];
    }
    return { ticker: r.ticker, raw: r.raw, z, composite, rank: 0 };
  });

  scored.sort((a, b) => b.composite - a.composite);
  scored.forEach((row, i) => { row.rank = i + 1; });
  return scored;
}

// ----- 因子计算实现 ---------------------------------------------

function priceMomentum(closes: number[], lookback: number, skipRecent: number): number | null {
  const needed = lookback + skipRecent + 1;
  if (closes.length < needed) return null;
  const end = closes.length - 1 - skipRecent;
  const start = end - lookback;
  const startPrice = closes[start];
  const endPrice = closes[end];
  if (!startPrice || !endPrice) return null;
  return endPrice / startPrice - 1;
}

function momentumConsistency(closes: number[], lookback: number): number | null {
  if (closes.length < lookback + 1) return null;
  let up = 0;
  let total = 0;
  for (let i = closes.length - lookback; i < closes.length; i += 1) {
    const a = closes[i - 1];
    const b = closes[i];
    if (a > 0 && b > 0) {
      total += 1;
      if (b > a) up += 1;
    }
  }
  if (total === 0) return null;
  return up / total - 0.5; // 居中到 0；正 = 上涨日多于一半
}

function meanReversion(closes: number[], lookback: number): number | null {
  if (closes.length < lookback + 1) return null;
  const startPrice = closes[closes.length - 1 - lookback];
  const endPrice = closes[closes.length - 1];
  if (!startPrice || !endPrice) return null;
  return -(endPrice / startPrice - 1);
}

export function rsi(closes: number[], period = 14): number | null {
  if (closes.length < period + 1) return null;
  let gainSum = 0;
  let lossSum = 0;
  for (let i = closes.length - period; i < closes.length; i += 1) {
    const change = closes[i] - closes[i - 1];
    if (change >= 0) gainSum += change;
    else lossSum -= change;
  }
  const avgGain = gainSum / period;
  const avgLoss = lossSum / period;
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}

function trendRatio(closes: number[], shortLen: number, longLen: number): number | null {
  if (closes.length < longLen) return null;
  const shortMa = sma(closes, shortLen);
  const longMa = sma(closes, longLen);
  if (!shortMa || !longMa) return null;
  return shortMa / longMa - 1;
}

function gapFromHigh(closes: number[], lookback: number): number | null {
  if (closes.length < Math.min(60, lookback)) return null;
  const window = closes.slice(-lookback);
  const high = Math.max(...window);
  const last = closes[closes.length - 1];
  if (!high || !last) return null;
  return last / high; // 1 = 在52周高位
}

export function sma(closes: number[], period: number): number | null {
  if (closes.length < period) return null;
  const slice = closes.slice(-period);
  return slice.reduce((s, v) => s + v, 0) / period;
}

export function realizedVol(closes: number[], lookback = 20): number | null {
  if (closes.length < lookback + 1) return null;
  const slice = closes.slice(-(lookback + 1));
  const returns: number[] = [];
  for (let i = 1; i < slice.length; i += 1) {
    if (slice[i] > 0 && slice[i - 1] > 0) {
      returns.push(Math.log(slice[i] / slice[i - 1]));
    }
  }
  if (returns.length < lookback / 2) return null;
  const mean = returns.reduce((s, v) => s + v, 0) / returns.length;
  const variance = returns.reduce((s, v) => s + (v - mean) ** 2, 0) / Math.max(1, returns.length - 1);
  return Math.sqrt(variance) * Math.sqrt(252);
}

function volExpansion(closes: number[], shortLen: number, longLen: number): number | null {
  const shortV = realizedVol(closes, shortLen);
  const longV = realizedVol(closes, longLen);
  if (!shortV || !longV) return null;
  return shortV / longV - 1;
}

function liquidityScore(closes: number[], volumes: number[], lookback: number): number | null {
  if (closes.length < lookback || volumes.length < lookback) return null;
  const recentCloses = closes.slice(-lookback);
  const recentVolumes = volumes.slice(-lookback);
  let sum = 0;
  let count = 0;
  for (let i = 0; i < recentCloses.length; i += 1) {
    const v = recentVolumes[i];
    const c = recentCloses[i];
    if (Number.isFinite(v) && Number.isFinite(c) && v > 0 && c > 0) {
      sum += v * c;
      count += 1;
    }
  }
  if (count === 0) return null;
  return Math.log10(sum / count);
}

function volumeSurge(volumes: number[], shortLen: number, longLen: number): number | null {
  if (volumes.length < longLen) return null;
  const recent = volumes.slice(-shortLen).filter((v) => Number.isFinite(v) && v > 0);
  const baseline = volumes.slice(-longLen).filter((v) => Number.isFinite(v) && v > 0);
  if (recent.length < shortLen / 2 || baseline.length < longLen / 2) return null;
  const shortAvg = recent.reduce((s, v) => s + v, 0) / recent.length;
  const longAvg = baseline.reduce((s, v) => s + v, 0) / baseline.length;
  if (longAvg === 0) return null;
  return shortAvg / longAvg - 1;
}

function earningsYield(f: FundamentalsSnapshot | null): number | null {
  if (!f) return null;
  const pe = f.trailingPE ?? f.forwardPE;
  if (pe === null || !Number.isFinite(pe) || pe <= 0) return null;
  return 1 / pe;
}
