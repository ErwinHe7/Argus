// Mathematical/statistical arbitrage model inspired by public quant ideas, not by
// any private Renaissance Technologies implementation.
//
// Model stack:
// - OU residual: mean-reverting "spring" around a slow equilibrium.
// - Kalman local-level filter: denoised latent price + innovation z-score.
// - Cross-sectional z-scores: compare every ticker against the same universe.
// - Entropy/energy risk gate: penalize noisy, high-volatility regimes.
// - Dollar-neutral + beta-neutral weights: research targets, not live orders.

export type StatArbSeries = {
  symbol: string;
  dates: string[];
  closes: number[];
  volumes: number[];
  currentPrice: number | null;
  asOf: string | null;
};

export type StatArbConfig = {
  lookback: number;
  targetGross: number;
  maxAbsWeight: number;
  benchmarkSymbol: string;
};

export const STAT_ARB_DEFAULTS: StatArbConfig = {
  lookback: 252,
  targetGross: 1,
  maxAbsWeight: 0.1,
  benchmarkSymbol: 'SPY',
};

export type StatArbComponents = {
  ou: number;
  kalmanTrend: number;
  kalmanInnovation: number;
  momentum: number;
  entropy: number;
  energy: number;
  volumeFlow: number;
};

export type StatArbDiagnostics = {
  ouHalfLifeDays: number | null;
  ouPhi: number | null;
  residualZ: number | null;
  kalmanSlope20d: number | null;
  realizedVol20d: number | null;
  betaToBenchmark: number | null;
  entropy20d: number | null;
  maxDrawdown60d: number | null;
};

export type StatArbRow = {
  ticker: string;
  price: number | null;
  asOf: string | null;
  alpha: number;
  rawAlpha: number;
  targetWeight: number;
  side: 'long' | 'short' | 'flat';
  confidence: number;
  components: StatArbComponents;
  diagnostics: StatArbDiagnostics;
};

export type StatArbPortfolio = {
  generatedAt: string;
  config: StatArbConfig;
  universe: string[];
  benchmark: string;
  rows: StatArbRow[];
  summary: {
    grossExposure: number;
    netExposure: number;
    betaExposure: number;
    longCount: number;
    shortCount: number;
    flatCount: number;
    averageConfidence: number;
    model: string;
  };
  notes: string[];
};

type RawModelRow = {
  ticker: string;
  price: number | null;
  asOf: string | null;
  raw: {
    ouPull: number | null;
    kalmanTrend: number | null;
    kalmanInnovation: number | null;
    momentum63: number | null;
    entropy20: number | null;
    energy20: number | null;
    volumeFlow: number | null;
  };
  diagnostics: StatArbDiagnostics;
};

export function runStatArbModel(
  inputSeries: StatArbSeries[],
  benchmarkSeries: StatArbSeries | null,
  partialConfig: Partial<StatArbConfig> = {}
): StatArbPortfolio {
  const config = { ...STAT_ARB_DEFAULTS, ...partialConfig };
  const rows = inputSeries
    .filter((s) => s.closes.length >= Math.max(120, config.lookback / 2))
    .map((s) => computeRawRow(s, benchmarkSeries, config.lookback));

  if (rows.length < 5) {
    throw new Error(`Need at least 5 valid tickers, got ${rows.length}.`);
  }

  const components = zscoreComponents(rows);
  const scored: StatArbRow[] = rows.map((row, i) => {
    const c = components[i];
    const rawAlpha =
      0.30 * c.ou +
      0.24 * c.kalmanTrend +
      0.16 * c.kalmanInnovation +
      0.16 * c.momentum +
      0.10 * c.volumeFlow -
      0.10 * c.energy -
      0.06 * c.entropy;

    const validSignals = [
      row.raw.ouPull,
      row.raw.kalmanTrend,
      row.raw.kalmanInnovation,
      row.raw.momentum63,
      row.raw.volumeFlow,
    ].filter((v) => Number.isFinite(v as number)).length;
    const confidence = Math.max(0, Math.min(1, validSignals / 5));

    return {
      ticker: row.ticker,
      price: row.price,
      asOf: row.asOf,
      alpha: 0,
      rawAlpha,
      targetWeight: 0,
      side: 'flat',
      confidence,
      components: c,
      diagnostics: row.diagnostics,
    };
  });

  const alphaValues = scored.map((r) => r.rawAlpha);
  const alphaZ = zscore(alphaValues);
  for (let i = 0; i < scored.length; i += 1) {
    scored[i].alpha = clamp(alphaZ[i], -3, 3);
  }

  const betaValues = scored.map((r) => r.diagnostics.betaToBenchmark ?? 1);
  const weights = betaNeutralWeights(
    scored.map((r) => r.alpha * r.confidence),
    betaValues,
    config.targetGross,
    config.maxAbsWeight
  );

  for (let i = 0; i < scored.length; i += 1) {
    scored[i].targetWeight = weights[i];
    scored[i].side = weights[i] > 0.002 ? 'long' : weights[i] < -0.002 ? 'short' : 'flat';
  }

  scored.sort((a, b) => b.targetWeight - a.targetWeight || b.alpha - a.alpha);

  const grossExposure = weights.reduce((s, w) => s + Math.abs(w), 0);
  const netExposure = weights.reduce((s, w) => s + w, 0);
  const betaExposure = weights.reduce((s, w, i) => s + w * betaValues[i], 0);
  const averageConfidence = scored.reduce((s, r) => s + r.confidence, 0) / scored.length;
  const notes = [
    'Research model only: no live orders, no position is placed.',
    'Weights are dollar-neutral and approximately beta-neutral to the benchmark.',
    'OU/Kalman parameters are estimated from free daily bars, so treat output as a hypothesis generator.',
  ];

  return {
    generatedAt: new Date().toISOString(),
    config,
    universe: inputSeries.map((s) => s.symbol),
    benchmark: config.benchmarkSymbol,
    rows: scored,
    summary: {
      grossExposure,
      netExposure,
      betaExposure,
      longCount: scored.filter((r) => r.side === 'long').length,
      shortCount: scored.filter((r) => r.side === 'short').length,
      flatCount: scored.filter((r) => r.side === 'flat').length,
      averageConfidence,
      model: 'OU + Kalman + entropy/energy cross-sectional stat-arb',
    },
    notes,
  };
}

function computeRawRow(
  series: StatArbSeries,
  benchmark: StatArbSeries | null,
  lookback: number
): RawModelRow {
  const closes = series.closes.slice(-lookback).filter((v) => Number.isFinite(v) && v > 0);
  const volumes = series.volumes.slice(-lookback);
  const logs = closes.map(Math.log);
  const returns = logReturns(closes);
  const residual = residualVsSma(logs, 60);
  const ou = estimateOu(residual);
  const kalman = kalmanLocalLevel(logs);
  const kalmanSlope20d =
    kalman.level.length >= 21 ? kalman.level.at(-1)! - kalman.level.at(-21)! : null;
  const vol20 = realizedVol(returns, 20);
  const entropy20 = signEntropy(returns.slice(-20));
  const energy20 = vol20 === null ? null : vol20 * vol20;
  const momentum63 = closes.length >= 64 ? closes.at(-1)! / closes.at(-64)! - 1 : null;
  const volumeFlow = volumeSurge(volumes, 5, 30);
  const beta = benchmark ? betaToBenchmark(series.closes, benchmark.closes, 63) : null;
  const drawdown60 = maxDrawdown(closes.slice(-60));

  const residualZ = ou.residualZ;
  const ouPull =
    residualZ === null || ou.halfLifeDays === null
      ? null
      : -residualZ / Math.sqrt(Math.max(2, ou.halfLifeDays));
  const kalmanInnovation = kalman.innovationZ === null ? null : -kalman.innovationZ;

  return {
    ticker: series.symbol,
    price: series.currentPrice ?? closes.at(-1) ?? null,
    asOf: series.asOf,
    raw: {
      ouPull,
      kalmanTrend: kalmanSlope20d,
      kalmanInnovation,
      momentum63,
      entropy20,
      energy20,
      volumeFlow,
    },
    diagnostics: {
      ouHalfLifeDays: ou.halfLifeDays,
      ouPhi: ou.phi,
      residualZ,
      kalmanSlope20d,
      realizedVol20d: vol20,
      betaToBenchmark: beta,
      entropy20d: entropy20,
      maxDrawdown60d: drawdown60,
    },
  };
}

function zscoreComponents(rows: RawModelRow[]): StatArbComponents[] {
  const keys = [
    'ouPull',
    'kalmanTrend',
    'kalmanInnovation',
    'momentum63',
    'entropy20',
    'energy20',
    'volumeFlow',
  ] as const;
  const z: Record<(typeof keys)[number], number[]> = {} as Record<(typeof keys)[number], number[]>;
  for (const key of keys) {
    z[key] = zscore(rows.map((r) => r.raw[key]));
  }
  return rows.map((_, i) => ({
    ou: z.ouPull[i],
    kalmanTrend: z.kalmanTrend[i],
    kalmanInnovation: z.kalmanInnovation[i],
    momentum: z.momentum63[i],
    entropy: z.entropy20[i],
    energy: z.energy20[i],
    volumeFlow: z.volumeFlow[i],
  }));
}

function betaNeutralWeights(
  alphas: number[],
  betas: number[],
  targetGross: number,
  maxAbsWeight: number
): number[] {
  let w = neutralizeNetAndBeta(alphas.map((v) => (Number.isFinite(v) ? v : 0)), betas);
  w = normalizeGross(w, targetGross);

  // Capping can reintroduce small net/beta exposure. Re-project a few times; if
  // the cap is too tight for the requested universe, the last projection is the
  // least-bad feasible research target.
  for (let i = 0; i < 4; i += 1) {
    w = w.map((x) => clamp(x, -maxAbsWeight, maxAbsWeight));
    w = neutralizeNetAndBeta(w, betas);
    w = normalizeGross(w, targetGross);
  }
  return w.map((x) => clamp(x, -maxAbsWeight, maxAbsWeight));
}

function neutralizeNetAndBeta(values: number[], betas: number[]): number[] {
  const n = values.length;
  if (n === 0) return [];
  const sumOne = n;
  const sumBeta = betas.reduce((s, b) => s + b, 0);
  const sumBeta2 = betas.reduce((s, b) => s + b * b, 0);
  const sumValue = values.reduce((s, v) => s + v, 0);
  const sumValueBeta = values.reduce((s, v, i) => s + v * betas[i], 0);
  const det = sumOne * sumBeta2 - sumBeta * sumBeta;
  if (Math.abs(det) < 1e-9) return demean(values);

  const a = (sumValue * sumBeta2 - sumValueBeta * sumBeta) / det;
  const b = (sumOne * sumValueBeta - sumBeta * sumValue) / det;
  return values.map((v, i) => v - a - b * betas[i]);
}

function normalizeGross(values: number[], targetGross: number): number[] {
  const gross = values.reduce((s, v) => s + Math.abs(v), 0);
  if (gross === 0) return values.map(() => 0);
  return values.map((v) => (v / gross) * targetGross);
}

function estimateOu(residuals: number[]): {
  phi: number | null;
  halfLifeDays: number | null;
  residualZ: number | null;
} {
  const xs: number[] = [];
  const ys: number[] = [];
  for (let i = 1; i < residuals.length; i += 1) {
    const a = residuals[i - 1];
    const b = residuals[i];
    if (Number.isFinite(a) && Number.isFinite(b)) {
      xs.push(a);
      ys.push(b);
    }
  }
  if (xs.length < 30) return { phi: null, halfLifeDays: null, residualZ: null };
  const mx = mean(xs);
  const my = mean(ys);
  let num = 0;
  let den = 0;
  for (let i = 0; i < xs.length; i += 1) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) ** 2;
  }
  if (den === 0) return { phi: null, halfLifeDays: null, residualZ: zLast(residuals) };
  const phi = clamp(num / den, 0.001, 0.999);
  const kappa = -Math.log(phi);
  const halfLifeDays = Math.log(2) / kappa;
  return { phi, halfLifeDays, residualZ: zLast(residuals) };
}

function kalmanLocalLevel(logs: number[]): { level: number[]; innovationZ: number | null } {
  if (logs.length === 0) return { level: [], innovationZ: null };
  const ret = logReturns(logs.map(Math.exp));
  const obsVariance = Math.max(1e-6, variance(ret.slice(-60)));
  const processVariance = obsVariance * 0.05;
  let level = logs[0];
  let p = obsVariance;
  const levels: number[] = [];
  const innovations: number[] = [];
  for (const observed of logs) {
    p += processVariance;
    const innovation = observed - level;
    const s = p + obsVariance;
    const k = p / s;
    level += k * innovation;
    p = (1 - k) * p;
    levels.push(level);
    innovations.push(innovation / Math.sqrt(s));
  }
  return { level: levels, innovationZ: zLast(innovations) };
}

function residualVsSma(values: number[], window: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < values.length; i += 1) {
    if (i + 1 < window) {
      out.push(NaN);
      continue;
    }
    const base = mean(values.slice(i + 1 - window, i + 1));
    out.push(values[i] - base);
  }
  return out;
}

function logReturns(closes: number[]): number[] {
  const out: number[] = [];
  for (let i = 1; i < closes.length; i += 1) {
    const a = closes[i - 1];
    const b = closes[i];
    if (a > 0 && b > 0) out.push(Math.log(b / a));
  }
  return out;
}

function realizedVol(returns: number[], window: number): number | null {
  const slice = returns.slice(-window).filter(Number.isFinite);
  if (slice.length < Math.max(5, window / 2)) return null;
  return Math.sqrt(variance(slice)) * Math.sqrt(252);
}

function signEntropy(returns: number[]): number | null {
  const valid = returns.filter(Number.isFinite);
  if (valid.length < 5) return null;
  const up = valid.filter((r) => r > 0).length;
  const down = valid.filter((r) => r < 0).length;
  const flat = valid.length - up - down;
  const ps = [up, down, flat].map((n) => n / valid.length).filter((p) => p > 0);
  const entropy = -ps.reduce((s, p) => s + p * Math.log(p), 0);
  return entropy / Math.log(3);
}

function volumeSurge(volumes: number[], shortLen: number, longLen: number): number | null {
  const short = volumes.slice(-shortLen).filter((v) => Number.isFinite(v) && v > 0);
  const long = volumes.slice(-longLen).filter((v) => Number.isFinite(v) && v > 0);
  if (short.length < shortLen / 2 || long.length < longLen / 2) return null;
  const base = mean(long);
  if (base === 0) return null;
  return mean(short) / base - 1;
}

function betaToBenchmark(closes: number[], benchmarkCloses: number[], window: number): number | null {
  const n = Math.min(closes.length, benchmarkCloses.length);
  if (n < window + 1) return null;
  const a = logReturns(closes.slice(-n)).slice(-window);
  const b = logReturns(benchmarkCloses.slice(-n)).slice(-window);
  if (a.length !== b.length || a.length < window / 2) return null;
  const cov = covariance(a, b);
  const vb = variance(b);
  return vb === 0 ? null : cov / vb;
}

function maxDrawdown(values: number[]): number | null {
  const valid = values.filter((v) => Number.isFinite(v) && v > 0);
  if (valid.length < 2) return null;
  let peak = valid[0];
  let worst = 0;
  for (const v of valid) {
    peak = Math.max(peak, v);
    worst = Math.min(worst, v / peak - 1);
  }
  return worst;
}

function zscore(values: Array<number | null>): number[] {
  const valid = values.filter((v): v is number => Number.isFinite(v as number));
  if (valid.length < 2) return values.map(() => 0);
  const m = mean(valid);
  const sd = Math.sqrt(variance(valid)) || 1;
  return values.map((v) => (Number.isFinite(v as number) ? clamp(((v as number) - m) / sd, -3, 3) : 0));
}

function zLast(values: number[]): number | null {
  const valid = values.filter(Number.isFinite);
  if (valid.length < 10) return null;
  const last = valid.at(-1);
  if (!Number.isFinite(last as number)) return null;
  const m = mean(valid);
  const sd = Math.sqrt(variance(valid)) || 1;
  return ((last as number) - m) / sd;
}

function demean(values: number[]): number[] {
  const m = mean(values);
  return values.map((v) => v - m);
}

function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((s, v) => s + v, 0) / values.length;
}

function variance(values: number[]): number {
  const valid = values.filter(Number.isFinite);
  if (valid.length < 2) return 0;
  const m = mean(valid);
  return valid.reduce((s, v) => s + (v - m) ** 2, 0) / Math.max(1, valid.length - 1);
}

function covariance(a: number[], b: number[]): number {
  const n = Math.min(a.length, b.length);
  if (n < 2) return 0;
  const ax = a.slice(-n);
  const bx = b.slice(-n);
  const ma = mean(ax);
  const mb = mean(bx);
  let s = 0;
  for (let i = 0; i < n; i += 1) s += (ax[i] - ma) * (bx[i] - mb);
  return s / Math.max(1, n - 1);
}

function dot(a: number[], b: number[]): number {
  const n = Math.min(a.length, b.length);
  let s = 0;
  for (let i = 0; i < n; i += 1) s += a[i] * b[i];
  return s;
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}
