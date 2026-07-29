// Lognormal terminal-price model for option probability distribution.
// Risk-neutral / model-implied; not a real-world forecast.
//
//   S_T = S0 * exp( (r - q - 0.5 * sigma^2) * T + sigma * sqrt(T) * Z )
//   ln(S_T) ~ Normal(mu, std^2),  mu = ln(S0) + (r - q - 0.5*sigma^2)*T,  std = sigma*sqrt(T)

export type OptionProbabilityInputs = {
  spot: number;
  target: number;
  ivAnnual: number; // decimal, e.g. 0.42
  daysToExpiry: number;
  riskFreeRate: number; // decimal
  dividendYield: number; // decimal
};

export type ProbabilityPoint = {
  price: number;
  pdf: number;
  cdf: number;
};

export type OptionProbabilityResult = {
  ok: true;
  spot: number;
  target: number;
  ivAnnual: number;
  daysToExpiry: number;
  T: number;
  mu: number;
  std: number;
  riskFreeRate: number;
  dividendYield: number;
  probAbove: number;
  probBelow: number;
  expectedMove: number;
  expectedMovePct: number;
  oneSigmaLow: number;
  oneSigmaHigh: number;
  twoSigmaLow: number;
  twoSigmaHigh: number;
  minPrice: number;
  maxPrice: number;
  points: ProbabilityPoint[];
};

export type OptionProbabilityError = {
  ok: false;
  error: string;
};

export function validateInputs(input: OptionProbabilityInputs): string | null {
  if (!Number.isFinite(input.spot) || input.spot <= 0) return 'Stock price must be greater than 0.';
  if (!Number.isFinite(input.target) || input.target <= 0) return 'Target price must be greater than 0.';
  if (!Number.isFinite(input.ivAnnual) || input.ivAnnual <= 0) return 'Implied volatility must be greater than 0.';
  if (!Number.isFinite(input.daysToExpiry) || input.daysToExpiry <= 0) return 'Expiration must be in the future.';
  if (!Number.isFinite(input.riskFreeRate)) return 'Risk-free rate is invalid.';
  if (!Number.isFinite(input.dividendYield)) return 'Dividend yield is invalid.';
  return null;
}

export function computeOptionProbability(
  input: OptionProbabilityInputs,
  pointCount = 240
): OptionProbabilityResult | OptionProbabilityError {
  const err = validateInputs(input);
  if (err) return { ok: false, error: err };

  const { spot, target, ivAnnual, daysToExpiry, riskFreeRate, dividendYield } = input;
  const T = Math.max(daysToExpiry / 365, 1 / 365);
  const sigma = ivAnnual;
  const std = sigma * Math.sqrt(T);
  const mu = Math.log(spot) + (riskFreeRate - dividendYield - 0.5 * sigma * sigma) * T;

  // P(S_T <= K) = N(z), z = (ln K - mu) / std
  const zTarget = (Math.log(target) - mu) / std;
  const probBelow = normalCdf(zTarget);
  const probAbove = 1 - probBelow;

  // Expected move (1σ price delta around spot) and σ ranges based on lognormal quantiles.
  const oneSigmaLow = Math.exp(mu - std);
  const oneSigmaHigh = Math.exp(mu + std);
  const twoSigmaLow = Math.exp(mu - 2 * std);
  const twoSigmaHigh = Math.exp(mu + 2 * std);
  const expectedMove = (oneSigmaHigh - oneSigmaLow) / 2;
  const expectedMovePct = (expectedMove / spot) * 100;

  const minPrice = Math.max(0.01, spot * Math.exp(-4 * std));
  const maxPrice = spot * Math.exp(4 * std);

  const steps = Math.max(40, pointCount);
  const points: ProbabilityPoint[] = new Array(steps + 1);
  for (let i = 0; i <= steps; i += 1) {
    const price = minPrice + ((maxPrice - minPrice) * i) / steps;
    const z = (Math.log(price) - mu) / std;
    const pdf = (1 / (price * std * Math.sqrt(2 * Math.PI))) * Math.exp(-0.5 * z * z);
    points[i] = { price, pdf, cdf: normalCdf(z) };
  }

  return {
    ok: true,
    spot,
    target,
    ivAnnual,
    daysToExpiry,
    T,
    mu,
    std,
    riskFreeRate,
    dividendYield,
    probAbove,
    probBelow,
    expectedMove,
    expectedMovePct,
    oneSigmaLow,
    oneSigmaHigh,
    twoSigmaLow,
    twoSigmaHigh,
    minPrice,
    maxPrice,
    points,
  };
}

// Abramowitz & Stegun 7.1.26 — good to ~1e-7.
export function normalCdf(x: number): number {
  if (!Number.isFinite(x)) return x > 0 ? 1 : 0;
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const p = 0.3275911;
  const sign = x < 0 ? -1 : 1;
  const ax = Math.abs(x) / Math.sqrt(2);
  const t = 1 / (1 + p * ax);
  const y = 1 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-ax * ax);
  return 0.5 * (1 + sign * y);
}

export function normalPdf(x: number): number {
  return Math.exp(-0.5 * x * x) / Math.sqrt(2 * Math.PI);
}

// Black-Scholes call/put for "Call/Put Implied Probability" tab visualization.
// "Implied probability" here = N(d2) for calls, N(-d2) for puts evaluated across
// a sweep of strikes — the model-implied prob of finishing ITM at each strike.
export function callImpliedProbability(
  spot: number,
  strike: number,
  T: number,
  sigma: number,
  r: number,
  q: number
): number {
  if (strike <= 0 || sigma <= 0 || T <= 0 || spot <= 0) return 0;
  const d2 = (Math.log(spot / strike) + (r - q - 0.5 * sigma * sigma) * T) / (sigma * Math.sqrt(T));
  return normalCdf(d2);
}

export function putImpliedProbability(
  spot: number,
  strike: number,
  T: number,
  sigma: number,
  r: number,
  q: number
): number {
  return 1 - callImpliedProbability(spot, strike, T, sigma, r, q);
}

export function daysBetween(fromIso: string, toIso: string): number {
  const from = new Date(fromIso).getTime();
  const to = new Date(toIso).getTime();
  if (!Number.isFinite(from) || !Number.isFinite(to)) return 0;
  return Math.max(0, Math.round((to - from) / (24 * 60 * 60 * 1000)));
}

export function daysUntil(targetIso: string, now: Date = new Date()): number {
  const target = new Date(`${targetIso}T20:00:00Z`).getTime();
  if (!Number.isFinite(target)) return 0;
  return Math.max(0, Math.ceil((target - now.getTime()) / (24 * 60 * 60 * 1000)));
}
