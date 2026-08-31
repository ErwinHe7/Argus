// Cross-sectional ML long/short equity backtest — the "Voleon-style" engine.
//
// 和 lib/quant/backtest.ts (单股、规则化、long/cash) 不同, 这一层是:
//   - 横截面: 同一时刻把 universe 内所有股票拉一起打分排名
//   - 多空中性: 高分做多, 低分做空, 美元中性, 等权
//   - 用 ML 思路组合多个因子: 训练窗口里学每个因子的 IC, 再加权合成预测
//   - Walk-forward + purge: 训练样本的标签窗口必须在预测日之前已经闭合
//
// 模型选择: 没用 GBM, 用的是 per-feature rank-IC 加权组合 —— 这是真实因子投资
// 圈子里最经典的"白盒"组合方法, 数学清楚、无需矩阵求逆、在 TS 里跑得很快。
//
// 这是研究工具, 不是投资建议。免费日线 + 简单因子 + 不含退市股票, 净值数字会
// 比真实情况乐观, 请按"理解管线"对待, 不要拿数字直接做仓位决定。

export type MlLsPriceSeries = {
  symbol: string;
  dates: string[]; // ascending YYYY-MM-DD
  closes: number[];
  volumes: number[];
};

export type MlLsConfig = {
  forwardDays: number; // h, prediction horizon in trading days
  trainDays: number; // rolling training window length in trading days
  quantile: number; // 0..0.5, top/bottom fraction taken as long/short
  costBpsPerSide: number; // per-side turnover cost in bps (10 = 0.10%)
};

export const ML_LS_DEFAULTS: MlLsConfig = {
  forwardDays: 5,
  trainDays: 504,
  quantile: 0.2,
  costBpsPerSide: 10,
};

export const ML_LS_FEATURES = [
  { key: 'mom_21', label: '1M Momentum', formula: 'close[t] / close[t-21] - 1' },
  { key: 'mom_63', label: '3M Momentum', formula: 'close[t] / close[t-63] - 1' },
  { key: 'mom_126', label: '6M Momentum', formula: 'close[t] / close[t-126] - 1' },
  { key: 'rev_5', label: '1W Reversal', formula: '-(close[t] / close[t-5] - 1)' },
  { key: 'vol_21', label: '1M Realized Vol', formula: 'std(ret_1d, 21)' },
  { key: 'ma_gap', label: 'Gap vs SMA50', formula: 'close[t] / sma50(close) - 1' },
  { key: 'vol_z', label: 'Volume Z-score', formula: '(vol - sma21(vol)) / std21(vol)' },
] as const;

type FeatureKey = (typeof ML_LS_FEATURES)[number]['key'];

export type MlLsPeriod = {
  date: string;
  grossReturn: number;
  netReturn: number;
  turnover: number;
  ic: number;
  longs: string[];
  shorts: string[];
};

export type MlLsEquityPoint = {
  date: string;
  equity: number; // net, starts at 1.0
};

export type MlLsFeatureWeight = {
  key: FeatureKey;
  label: string;
  weight: number;
};

export type MlLsSummary = {
  periodsCount: number;
  yearsApprox: number;
  annualizedReturnPct: number;
  annualizedVolPct: number;
  sharpe: number;
  maxDrawdownPct: number;
  meanIc: number;
  hitRatePct: number;
  avgTurnover: number;
  finalEquity: number;
  universeSize: number;
};

export type MlLsResult = {
  summary: MlLsSummary;
  equityCurve: MlLsEquityPoint[];
  periods: MlLsPeriod[];
  lastFeatureWeights: MlLsFeatureWeight[];
  config: MlLsConfig;
  universeUsed: string[];
  notes: string[];
};

// ===========================================================================
// 主入口
// ===========================================================================

export function runMlLsBacktest(
  rawSeries: MlLsPriceSeries[],
  config: Partial<MlLsConfig> = {}
): MlLsResult {
  const cfg: MlLsConfig = { ...ML_LS_DEFAULTS, ...config };
  const notes: string[] = [];

  // 1. 把所有股票对齐到共同的交易日 (用最长那只的日历做参考, 缺失日填 NaN)
  const aligned = alignToCommonCalendar(rawSeries);
  const dates = aligned.dates;
  const universe = aligned.symbols;
  const closes = aligned.closes; // [N tickers][T dates]
  const volumes = aligned.volumes;
  const T = dates.length;
  const N = universe.length;

  if (N < 10) {
    throw new Error(`Need at least 10 tickers in the universe, got ${N}.`);
  }
  if (T < cfg.trainDays + 200) {
    throw new Error(
      `Need at least ${cfg.trainDays + 200} bars of history, got ${T}. Try a longer range or a smaller train window.`
    );
  }

  // 2. 每个特征的原始值矩阵 [T][N], NaN allowed
  const featuresRaw: Record<FeatureKey, number[][]> = {
    mom_21: computeMomentum(closes, 21, N, T),
    mom_63: computeMomentum(closes, 63, N, T),
    mom_126: computeMomentum(closes, 126, N, T),
    rev_5: computeMomentum(closes, 5, N, T).map((row) => row.map((v) => -v)),
    vol_21: computeRealizedVol(closes, 21, N, T),
    ma_gap: computeMaGap(closes, 50, N, T),
    vol_z: computeVolumeZ(volumes, 21, N, T),
  };

  // 3. 每天做横截面 z-score, NaN -> 0 (中性)
  const features: Record<FeatureKey, number[][]> = {} as Record<FeatureKey, number[][]>;
  for (const key of Object.keys(featuresRaw) as FeatureKey[]) {
    features[key] = featuresRaw[key].map((row) => zscoreSafe(row));
  }

  // 4. 前向 h 日收益 + 当日横截面去均值 (这就是预测标签)
  const labels: number[][] = computeForwardLabels(closes, cfg.forwardDays, N, T);

  // 5. 走步回测
  const periods: MlLsPeriod[] = [];
  const equityCurve: MlLsEquityPoint[] = [];
  let equity = 1.0;
  let prevWeights = new Array<number>(N).fill(0);
  let lastFeatureIcs: Record<FeatureKey, number> | null = null;

  const startT = cfg.trainDays + 130; // 留足 SMA50 + 6m momentum 的预热
  for (let t = startT; t + cfg.forwardDays < T; t += cfg.forwardDays) {
    // ---- 5a. 训练: 计算每个特征在 [t - trainDays, t - forwardDays] 区间内的 mean IC ----
    const trainStart = t - cfg.trainDays;
    const trainEnd = t - cfg.forwardDays; // purge: 标签窗口必须在 t 之前闭合
    const featureIcs = computeMeanRankIc(features, labels, trainStart, trainEnd);
    lastFeatureIcs = featureIcs;

    // ---- 5b. 当日预测: pred[n] = Σ ic_f * f[t][n] ----
    const preds = new Array<number>(N).fill(0);
    const valid = new Array<boolean>(N).fill(true);
    for (let n = 0; n < N; n++) {
      let sum = 0;
      let allFeaturesValid = true;
      for (const key of Object.keys(features) as FeatureKey[]) {
        const v = features[key][t][n];
        const raw = featuresRaw[key][t][n];
        if (!Number.isFinite(raw)) {
          allFeaturesValid = false;
        }
        sum += featureIcs[key] * v;
      }
      preds[n] = sum;
      valid[n] = allFeaturesValid;
    }

    // 只用有效股票
    const validIdx: number[] = [];
    for (let n = 0; n < N; n++) if (valid[n]) validIdx.push(n);
    if (validIdx.length < 10) continue;

    // ---- 5c. 排名 → 多空、美元中性、等权 ----
    const k = Math.max(1, Math.floor(validIdx.length * cfg.quantile));
    const ranked = validIdx
      .map((n) => ({ n, pred: preds[n] }))
      .sort((a, b) => b.pred - a.pred);
    const longIdx = ranked.slice(0, k).map((r) => r.n);
    const shortIdx = ranked.slice(-k).map((r) => r.n);

    const weights = new Array<number>(N).fill(0);
    for (const n of longIdx) weights[n] = 0.5 / k; // long gross = 0.5
    for (const n of shortIdx) weights[n] = -0.5 / k; // short gross = 0.5

    // ---- 5d. 持有 h 天的实现收益 (用 labels[t] 即 forward demeaned ret) ----
    let gross = 0;
    let icPairs: Array<[number, number]> = [];
    for (const n of validIdx) {
      const realized = labels[t][n];
      if (!Number.isFinite(realized)) continue;
      gross += weights[n] * realized;
      icPairs.push([preds[n], realized]);
    }

    // ---- 5e. 换手成本 ----
    let turnover = 0;
    for (let n = 0; n < N; n++) {
      turnover += Math.abs(weights[n] - prevWeights[n]);
    }
    const cost = turnover * (cfg.costBpsPerSide / 1e4);
    const net = gross - cost;

    // ---- 5f. IC: 预测 vs 实现 ----
    const ic = icPairs.length >= 5
      ? spearman(icPairs.map((p) => p[0]), icPairs.map((p) => p[1]))
      : 0;

    equity *= 1 + net;
    equityCurve.push({ date: dates[t], equity });
    periods.push({
      date: dates[t],
      grossReturn: gross,
      netReturn: net,
      turnover,
      ic,
      longs: longIdx.map((n) => universe[n]),
      shorts: shortIdx.map((n) => universe[n]),
    });
    prevWeights = weights;
  }

  if (periods.length === 0) {
    throw new Error('No rebalance periods produced — universe or history too small.');
  }

  // 6. 汇总
  const summary = summarize(periods, equity, cfg.forwardDays, N);
  const lastFeatureWeights: MlLsFeatureWeight[] = ML_LS_FEATURES.map((f) => ({
    key: f.key,
    label: f.label,
    weight: lastFeatureIcs ? lastFeatureIcs[f.key] : 0,
  }));

  if (summary.meanIc !== 0 && Math.abs(summary.meanIc) < 0.02) {
    notes.push(
      `Mean IC ≈ ${summary.meanIc.toFixed(3)} — 信号非常微弱。这是诚实的、典型的免费日线 + 简单因子结果。真正的 edge 在更好的数据和成本控制里。`
    );
  }
  if (summary.sharpe > 3) {
    notes.push(
      `Sharpe ${summary.sharpe.toFixed(2)} 看起来好得不真实。先怀疑数据/因子里有 look-ahead 或幸存者偏差, 而不是庆祝。`
    );
  }

  return {
    summary,
    equityCurve,
    periods,
    lastFeatureWeights,
    config: cfg,
    universeUsed: universe,
    notes,
  };
}

// ===========================================================================
// 数据对齐
// ===========================================================================

function alignToCommonCalendar(series: MlLsPriceSeries[]): {
  symbols: string[];
  dates: string[];
  closes: number[][]; // [N][T]
  volumes: number[][]; // [N][T]
} {
  if (series.length === 0) throw new Error('Empty universe.');

  // 用最长那个 ticker 的日历作参考, 其它 ticker 缺失日填 NaN (而不是用 intersection,
  // 这样新 IPO 的票不会拖掉整个数据集)
  let longest = series[0];
  for (const s of series) if (s.dates.length > longest.dates.length) longest = s;
  const calendar = longest.dates;
  const dateIndex = new Map<string, number>();
  for (let i = 0; i < calendar.length; i++) dateIndex.set(calendar[i], i);

  const symbols: string[] = [];
  const closes: number[][] = [];
  const volumes: number[][] = [];
  for (const s of series) {
    const cRow = new Array<number>(calendar.length).fill(NaN);
    const vRow = new Array<number>(calendar.length).fill(NaN);
    for (let i = 0; i < s.dates.length; i++) {
      const idx = dateIndex.get(s.dates[i]);
      if (idx !== undefined) {
        cRow[idx] = s.closes[i];
        vRow[idx] = s.volumes[i];
      }
    }
    symbols.push(s.symbol);
    closes.push(cRow);
    volumes.push(vRow);
  }

  return { symbols, dates: calendar, closes, volumes };
}

// ===========================================================================
// 因子计算 (raw, 无 z-score, NaN allowed)
// 数据结构: 输入 closes[N][T], 输出 feature[T][N]
// ===========================================================================

function computeMomentum(closes: number[][], lookback: number, N: number, T: number): number[][] {
  const out: number[][] = Array.from({ length: T }, () => new Array<number>(N).fill(NaN));
  for (let t = 0; t < T; t++) {
    if (t < lookback) continue;
    for (let n = 0; n < N; n++) {
      const a = closes[n][t - lookback];
      const b = closes[n][t];
      if (Number.isFinite(a) && Number.isFinite(b) && a > 0) {
        out[t][n] = b / a - 1;
      }
    }
  }
  return out;
}

function computeRealizedVol(closes: number[][], window: number, N: number, T: number): number[][] {
  const out: number[][] = Array.from({ length: T }, () => new Array<number>(N).fill(NaN));
  for (let n = 0; n < N; n++) {
    const rets: number[] = new Array<number>(T).fill(NaN);
    for (let t = 1; t < T; t++) {
      const a = closes[n][t - 1];
      const b = closes[n][t];
      if (Number.isFinite(a) && Number.isFinite(b) && a > 0) rets[t] = b / a - 1;
    }
    for (let t = window; t < T; t++) {
      let sum = 0;
      let cnt = 0;
      for (let k = t - window + 1; k <= t; k++) {
        if (Number.isFinite(rets[k])) {
          sum += rets[k];
          cnt++;
        }
      }
      if (cnt < window / 2) continue;
      const mean = sum / cnt;
      let v = 0;
      for (let k = t - window + 1; k <= t; k++) {
        if (Number.isFinite(rets[k])) v += (rets[k] - mean) ** 2;
      }
      out[t][n] = Math.sqrt(v / Math.max(1, cnt - 1));
    }
  }
  return out;
}

function computeMaGap(closes: number[][], window: number, N: number, T: number): number[][] {
  const out: number[][] = Array.from({ length: T }, () => new Array<number>(N).fill(NaN));
  for (let n = 0; n < N; n++) {
    for (let t = window - 1; t < T; t++) {
      let sum = 0;
      let cnt = 0;
      for (let k = t - window + 1; k <= t; k++) {
        if (Number.isFinite(closes[n][k])) {
          sum += closes[n][k];
          cnt++;
        }
      }
      if (cnt < window / 2) continue;
      const sma = sum / cnt;
      const c = closes[n][t];
      if (Number.isFinite(c) && sma > 0) out[t][n] = c / sma - 1;
    }
  }
  return out;
}

function computeVolumeZ(volumes: number[][], window: number, N: number, T: number): number[][] {
  const out: number[][] = Array.from({ length: T }, () => new Array<number>(N).fill(NaN));
  for (let n = 0; n < N; n++) {
    for (let t = window; t < T; t++) {
      let sum = 0;
      let cnt = 0;
      for (let k = t - window + 1; k <= t; k++) {
        if (Number.isFinite(volumes[n][k]) && volumes[n][k] > 0) {
          sum += volumes[n][k];
          cnt++;
        }
      }
      if (cnt < window / 2) continue;
      const mean = sum / cnt;
      let v = 0;
      for (let k = t - window + 1; k <= t; k++) {
        if (Number.isFinite(volumes[n][k]) && volumes[n][k] > 0) v += (volumes[n][k] - mean) ** 2;
      }
      const std = Math.sqrt(v / Math.max(1, cnt - 1));
      const vol = volumes[n][t];
      if (std > 0 && Number.isFinite(vol)) out[t][n] = (vol - mean) / std;
    }
  }
  return out;
}

function computeForwardLabels(closes: number[][], h: number, N: number, T: number): number[][] {
  const fwd: number[][] = Array.from({ length: T }, () => new Array<number>(N).fill(NaN));
  for (let t = 0; t + h < T; t++) {
    // 1. 每只股票算未来 h 日收益
    const row: number[] = new Array<number>(N).fill(NaN);
    let sum = 0;
    let cnt = 0;
    for (let n = 0; n < N; n++) {
      const a = closes[n][t];
      const b = closes[n][t + h];
      if (Number.isFinite(a) && Number.isFinite(b) && a > 0) {
        row[n] = b / a - 1;
        sum += row[n];
        cnt++;
      }
    }
    // 2. 减掉当日横截面均值
    if (cnt > 0) {
      const mean = sum / cnt;
      for (let n = 0; n < N; n++) {
        if (Number.isFinite(row[n])) fwd[t][n] = row[n] - mean;
      }
    }
  }
  return fwd;
}

// ===========================================================================
// 统计工具
// ===========================================================================

function zscoreSafe(row: number[]): number[] {
  const valid = row.filter((v) => Number.isFinite(v));
  if (valid.length === 0) return row.map(() => 0);
  const mean = valid.reduce((s, v) => s + v, 0) / valid.length;
  const variance = valid.reduce((s, v) => s + (v - mean) ** 2, 0) / Math.max(1, valid.length - 1);
  const std = Math.sqrt(variance);
  if (std === 0) return row.map(() => 0);
  return row.map((v) => (Number.isFinite(v) ? (v - mean) / std : 0));
}

function rank(values: number[]): number[] {
  const n = values.length;
  const idx = values.map((val, i) => ({ val, i })).sort((a, b) => a.val - b.val);
  const ranks = new Array<number>(n);
  let i = 0;
  while (i < n) {
    let j = i;
    while (j + 1 < n && idx[j + 1].val === idx[i].val) j++;
    const avg = (i + j + 2) / 2; // 1-indexed average rank for ties
    for (let k = i; k <= j; k++) ranks[idx[k].i] = avg;
    i = j + 1;
  }
  return ranks;
}

function pearson(x: number[], y: number[]): number {
  const n = x.length;
  if (n < 2) return 0;
  let mx = 0;
  let my = 0;
  for (let i = 0; i < n; i++) {
    mx += x[i];
    my += y[i];
  }
  mx /= n;
  my /= n;
  let num = 0;
  let dx = 0;
  let dy = 0;
  for (let i = 0; i < n; i++) {
    const a = x[i] - mx;
    const b = y[i] - my;
    num += a * b;
    dx += a * a;
    dy += b * b;
  }
  const den = Math.sqrt(dx * dy);
  return den === 0 ? 0 : num / den;
}

function spearman(x: number[], y: number[]): number {
  if (x.length !== y.length || x.length < 2) return 0;
  return pearson(rank(x), rank(y));
}

function computeMeanRankIc(
  features: Record<FeatureKey, number[][]>,
  labels: number[][],
  startT: number,
  endT: number
): Record<FeatureKey, number> {
  const result = {} as Record<FeatureKey, number>;
  for (const key of Object.keys(features) as FeatureKey[]) {
    const ics: number[] = [];
    for (let t = startT; t < endT; t++) {
      const f = features[key][t];
      const y = labels[t];
      const pairsX: number[] = [];
      const pairsY: number[] = [];
      for (let n = 0; n < f.length; n++) {
        if (Number.isFinite(f[n]) && Number.isFinite(y[n])) {
          pairsX.push(f[n]);
          pairsY.push(y[n]);
        }
      }
      if (pairsX.length >= 10) ics.push(spearman(pairsX, pairsY));
    }
    result[key] = ics.length === 0 ? 0 : ics.reduce((s, v) => s + v, 0) / ics.length;
  }
  return result;
}

function summarize(
  periods: MlLsPeriod[],
  finalEquity: number,
  forwardDays: number,
  universeSize: number
): MlLsSummary {
  const n = periods.length;
  const periodsPerYear = 252 / forwardDays;
  const yearsApprox = n / periodsPerYear;

  const meanRet =
    periods.reduce((s, p) => s + p.netReturn, 0) / n;
  const variance =
    periods.reduce((s, p) => s + (p.netReturn - meanRet) ** 2, 0) / Math.max(1, n - 1);
  const std = Math.sqrt(variance);
  const annReturn = Math.pow(finalEquity, 1 / Math.max(yearsApprox, 1 / 252)) - 1;
  const annVol = std * Math.sqrt(periodsPerYear);
  const sharpe = annVol === 0 ? 0 : (meanRet * periodsPerYear) / annVol;

  let peak = -Infinity;
  let worst = 0;
  let cum = 1.0;
  for (const p of periods) {
    cum *= 1 + p.netReturn;
    if (cum > peak) peak = cum;
    if (peak > 0) {
      const dd = cum / peak - 1;
      if (dd < worst) worst = dd;
    }
  }

  const wins = periods.filter((p) => p.netReturn > 0).length;
  const meanIc =
    periods.reduce((s, p) => s + (Number.isFinite(p.ic) ? p.ic : 0), 0) / n;
  const avgTurnover = periods.reduce((s, p) => s + p.turnover, 0) / n;

  return {
    periodsCount: n,
    yearsApprox,
    annualizedReturnPct: annReturn * 100,
    annualizedVolPct: annVol * 100,
    sharpe,
    maxDrawdownPct: worst * 100,
    meanIc,
    hitRatePct: (wins / n) * 100,
    avgTurnover,
    finalEquity,
    universeSize,
  };
}
