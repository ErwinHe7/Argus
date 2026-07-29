export type WebForecastDistribution = {
  engine: 'AXIO7 Web Forecast Engine';
  status: 'exploratory';
  horizonTradingDays: number;
  expectedReturnPct: number;
  medianReturnPct: number;
  probabilityUpPct: number;
  probabilityFlatPct: number;
  probabilityDownPct: number;
  lower10ReturnPct: number;
  upper90ReturnPct: number;
  expectedPrice: number;
  lower10Price: number;
  upper90Price: number;
  analogCount: number;
  trainingObservations: number;
  flatThresholdPct: number;
};

type Analog = {
  distance: number;
  futureReturn: number;
  weight: number;
};

const FEATURE_LOOKBACK = 252;

/**
 * Server-safe, deterministic forecast model.
 *
 * It compares the latest trend/volatility state with point-in-time historical
 * states, then builds a weighted forward-return distribution from the closest
 * analogs. Historical features never use observations after their candidate
 * cutoff. Results remain exploratory because this web model is not the native
 * intraday engine and has not passed a locked forward-shadow promotion gate.
 */
export function runWebForecast(
  rawCloses: number[],
  currentPrice: number | null,
  horizonTradingDays: number
): WebForecastDistribution | null {
  const closes = rawCloses.filter(
    (value) => typeof value === 'number' && Number.isFinite(value) && value > 0
  );
  const horizon = Math.max(1, Math.min(126, Math.round(horizonTradingDays)));
  if (closes.length < FEATURE_LOOKBACK + horizon + 24) return null;

  const currentFeatures = featuresAt(closes, closes.length - 1);
  if (!currentFeatures) return null;

  let step = Math.max(2, Math.floor(horizon / 3));
  let candidates = buildCandidates(closes, horizon, step);
  if (candidates.length < 24) {
    step = 1;
    candidates = buildCandidates(closes, horizon, step);
  }
  if (candidates.length < 18) return null;

  const dimensions = currentFeatures.length;
  const means = Array.from({ length: dimensions }, (_, dimension) =>
    mean(candidates.map((candidate) => candidate.features[dimension]))
  );
  const deviations = Array.from({ length: dimensions }, (_, dimension) =>
    sampleDeviation(
      candidates.map((candidate) => candidate.features[dimension]),
      means[dimension]
    )
  );

  const ranked = candidates
    .map((candidate) => ({
      distance: euclideanDistance(
        currentFeatures,
        candidate.features,
        means,
        deviations
      ),
      futureReturn: candidate.futureReturn,
    }))
    .filter(
      (candidate) =>
        Number.isFinite(candidate.distance) &&
        Number.isFinite(candidate.futureReturn)
    )
    .sort((left, right) => left.distance - right.distance);
  if (ranked.length < 18) return null;

  const neighborCount = Math.min(
    48,
    Math.max(18, Math.round(Math.sqrt(ranked.length) * 2.5))
  );
  const nearest = ranked.slice(0, neighborCount);
  const distanceScale =
    percentile(
      nearest.map((candidate) => candidate.distance),
      0.5
    ) || 1;
  const analogs: Analog[] = nearest.map((candidate) => ({
    ...candidate,
    weight: Math.exp(-candidate.distance / Math.max(0.15, distanceScale)),
  }));
  const weightSum = analogs.reduce((sum, analog) => sum + analog.weight, 0);
  if (!Number.isFinite(weightSum) || weightSum <= 0) return null;

  const expectedReturn =
    analogs.reduce(
      (sum, analog) => sum + analog.futureReturn * analog.weight,
      0
    ) / weightSum;
  const medianReturn = weightedPercentile(analogs, 0.5);
  const lower10Return = weightedPercentile(analogs, 0.1);
  const upper90Return = weightedPercentile(analogs, 0.9);
  const currentVol = currentFeatures[4];
  const flatThreshold = Math.max(
    0.0025,
    currentVol * Math.sqrt(horizon / 252) * 0.12
  );
  const probabilityUp = weightedShare(
    analogs,
    (value) => value > flatThreshold
  );
  const probabilityDown = weightedShare(
    analogs,
    (value) => value < -flatThreshold
  );
  const probabilityFlat = Math.max(0, 1 - probabilityUp - probabilityDown);
  const referencePrice =
    currentPrice && Number.isFinite(currentPrice)
      ? currentPrice
      : closes[closes.length - 1];

  return {
    engine: 'AXIO7 Web Forecast Engine',
    status: 'exploratory',
    horizonTradingDays: horizon,
    expectedReturnPct: round(expectedReturn * 100, 2),
    medianReturnPct: round(medianReturn * 100, 2),
    probabilityUpPct: round(probabilityUp * 100, 1),
    probabilityFlatPct: round(probabilityFlat * 100, 1),
    probabilityDownPct: round(probabilityDown * 100, 1),
    lower10ReturnPct: round(lower10Return * 100, 2),
    upper90ReturnPct: round(upper90Return * 100, 2),
    expectedPrice: round(referencePrice * (1 + expectedReturn), 2),
    lower10Price: round(referencePrice * (1 + lower10Return), 2),
    upper90Price: round(referencePrice * (1 + upper90Return), 2),
    analogCount: analogs.length,
    trainingObservations: closes.length,
    flatThresholdPct: round(flatThreshold * 100, 2),
  };
}

function buildCandidates(closes: number[], horizon: number, step: number) {
  const candidates: Array<{
    features: number[];
    futureReturn: number;
  }> = [];
  for (
    let cutoff = FEATURE_LOOKBACK;
    cutoff + horizon < closes.length;
    cutoff += step
  ) {
    const features = featuresAt(closes, cutoff);
    const start = closes[cutoff];
    const end = closes[cutoff + horizon];
    if (!features || !start || !end) continue;
    candidates.push({
      features,
      futureReturn: end / start - 1,
    });
  }
  return candidates;
}

function featuresAt(closes: number[], index: number): number[] | null {
  if (index < FEATURE_LOOKBACK || index >= closes.length) return null;
  const current = closes[index];
  const five = closes[index - 5];
  const twentyOne = closes[index - 21];
  const sixtyThree = closes[index - 63];
  const sma20 = averageWindow(closes, index, 20);
  const sma50 = averageWindow(closes, index, 50);
  const sma200 = averageWindow(closes, index, 200);
  const vol20 = realizedVolAt(closes, index, 20);
  const high252 = Math.max(...closes.slice(index - 251, index + 1));
  if (
    !current ||
    !five ||
    !twentyOne ||
    !sixtyThree ||
    !sma20 ||
    !sma50 ||
    !sma200 ||
    !vol20 ||
    !high252
  ) {
    return null;
  }
  return [
    current / five - 1,
    current / twentyOne - 1,
    current / sixtyThree - 1,
    sma20 / sma50 - 1,
    vol20,
    sma50 / sma200 - 1,
    current / high252 - 1,
  ];
}

function averageWindow(values: number[], endIndex: number, length: number) {
  const start = endIndex - length + 1;
  if (start < 0) return null;
  const window = values.slice(start, endIndex + 1);
  if (window.length !== length) return null;
  return mean(window);
}

function realizedVolAt(values: number[], endIndex: number, length: number) {
  if (endIndex - length < 0) return null;
  const returns: number[] = [];
  for (let index = endIndex - length + 1; index <= endIndex; index += 1) {
    const previous = values[index - 1];
    const current = values[index];
    if (!previous || !current) return null;
    returns.push(Math.log(current / previous));
  }
  const average = mean(returns);
  return sampleDeviation(returns, average) * Math.sqrt(252);
}

function euclideanDistance(
  current: number[],
  historical: number[],
  means: number[],
  deviations: number[]
) {
  let sum = 0;
  for (let index = 0; index < current.length; index += 1) {
    const deviation = deviations[index] || 1;
    const currentZ = (current[index] - means[index]) / deviation;
    const historicalZ = (historical[index] - means[index]) / deviation;
    const difference = currentZ - historicalZ;
    sum += difference * difference;
  }
  return Math.sqrt(sum / current.length);
}

function weightedShare(
  analogs: Analog[],
  predicate: (value: number) => boolean
) {
  const total = analogs.reduce((sum, analog) => sum + analog.weight, 0);
  const matching = analogs.reduce(
    (sum, analog) =>
      sum + (predicate(analog.futureReturn) ? analog.weight : 0),
    0
  );
  return total > 0 ? matching / total : 0;
}

function weightedPercentile(analogs: Analog[], target: number) {
  const sorted = [...analogs].sort(
    (left, right) => left.futureReturn - right.futureReturn
  );
  const total = sorted.reduce((sum, analog) => sum + analog.weight, 0);
  const threshold = total * Math.max(0, Math.min(1, target));
  let cumulative = 0;
  for (const analog of sorted) {
    cumulative += analog.weight;
    if (cumulative >= threshold) return analog.futureReturn;
  }
  return sorted.at(-1)?.futureReturn || 0;
}

function percentile(values: number[], target: number) {
  if (!values.length) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.max(
    0,
    Math.min(sorted.length - 1, Math.round((sorted.length - 1) * target))
  );
  return sorted[index];
}

function mean(values: number[]) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function sampleDeviation(values: number[], average: number) {
  if (values.length < 2) return 1;
  const variance =
    values.reduce((sum, value) => sum + (value - average) ** 2, 0) /
    (values.length - 1);
  return Math.sqrt(variance) || 1;
}

function round(value: number, digits: number) {
  const scale = 10 ** digits;
  return Math.round(value * scale) / scale;
}
