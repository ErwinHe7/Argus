// Presentation-only adapter for the canonical Rust options engine.
//
// This module intentionally contains no provider access, Black-Scholes,
// lognormal probability, dealer-sign inference, max-pain calculation, or
// gamma aggregation. Those operations belong to the point-in-time Rust
// service, where data lineage and fail-closed readiness are enforced.

export type OptionSide = 'C' | 'P';

export type OptionContract = {
  symbol: string;
  underlying: string;
  expiration: string;
  strike: number;
  side: OptionSide;
  openInterest: number;
  volume: number;
  lastPrice?: number;
  bid?: number;
  ask?: number;
  bidSize?: number;
  askSize?: number;
  iv?: number;
  delta?: number;
  gamma?: number;
};

export type OptionsChain = {
  underlying: string;
  spot: number;
  expiration: string;
  fetchedAt: string;
  // Legacy connector return type only. These providers are not called by the
  // presentation adapter or accepted as a canonical analytics report.
  provider: 'massive' | 'ibkr' | 'polygon' | 'yahoo' | 'unavailable';
  contracts: OptionContract[];
};

export type MaxPainPoint = {
  strike: number;
  totalPain: number;
};

export type MaxPainResult = {
  maxPainStrike: number;
  totalPainAtMax: number;
  spot: number;
  distanceFromSpotPct: number;
  curve: MaxPainPoint[];
};

export type GammaExposureBin = {
  strike: number;
  callGex: number;
  putGex: number;
  netGex: number;
};

export type GammaExposureResult = {
  totalCallGex: number;
  totalPutGex: number;
  netGex: number;
  zeroGammaStrike: number | null;
  bins: GammaExposureBin[];
  interpretation: 'gamma_squeeze_setup' | 'dealer_pin' | 'put_wall_risk' | 'balanced';
  rationale: string;
};

export type TopOiRow = {
  rank: number;
  symbol: string;
  expiration: string;
  strike: number;
  side: OptionSide;
  openInterest: number;
  volume: number;
};

export type EndingPriceProbabilityPoint = {
  price: number;
  lognormalPdf: number;
  lognormalCdf: number;
};

export type SerializableProbability = {
  underlying: string;
  spot: number;
  expiration: string;
  daysToExpiry: number;
  ivAtm: number;
  riskFreeRate: number;
  points: EndingPriceProbabilityPoint[];
  probAboveSpot: number;
  probAboveLevels: Array<{ level: number; probability: number }>;
};

export type SqueezeAssessment = {
  scenario: 'gamma_squeeze_likely' | 'dealer_pin_likely' | 'put_unwind_likely' | 'mixed';
  callOiTotal: number;
  putOiTotal: number;
  callPutRatio: number;
  rationale: string[];
  caveats: string[];
};

export type FlowPressure = {
  callOi: number;
  putOi: number;
  callVolume: number;
  putVolume: number;
  callPutOiRatio: number;
  callPutVolumeRatio: number;
  oiPctCall: number;
  volPctCall: number;
  bidAskQuality: 'ok' | 'partial' | 'unavailable';
  bidAskWeightedMidByStrike: Array<{
    strike: number;
    side: OptionSide;
    mid: number;
    spreadPct: number;
  }>;
  interpretation: string;
};

export type OptionsIntelReport = {
  underlying: string;
  expiration: string;
  spot: number;
  provider: 'massive' | 'ibkr' | 'polygon' | 'yahoo' | 'unavailable';
  topOi: TopOiRow[];
  topCalls: TopOiRow[];
  topPuts: TopOiRow[];
  maxPain: MaxPainResult | null;
  gex: GammaExposureResult | null;
  probability: SerializableProbability | null;
  squeezeAssessment: SqueezeAssessment;
  flowPressure: FlowPressure | null;
  generatedAt: string;
  disclaimer: string;
  dataReadiness?: {
    chainComplete: boolean;
    modelReady: boolean;
    capturedAt?: string;
    blockers: string[];
    contractsSha256?: string;
  };
  gammaConvexityRisk?: unknown;
};

function controlPlaneBaseUrl(): string {
  const raw =
    process.env.AXIO_QUANT_CONTROL_URL ||
    process.env.INTRADAY_QUANT_API_URL ||
    'http://127.0.0.1:8001';
  return raw.replace(/\/+$/, '');
}

function researchHeaders(): HeadersInit {
  const token = process.env.INTRADAY_QUANT_TOKEN;
  if (!token || token.length < 32) {
    throw new Error('Rust quant control plane is disabled: INTRADAY_QUANT_TOKEN is missing.');
  }
  return {
    Accept: 'application/json',
    'x-research-token': token,
  };
}

function isOptionsIntelReport(value: unknown): value is OptionsIntelReport {
  if (!value || typeof value !== 'object') return false;
  const row = value as Partial<OptionsIntelReport>;
  return (
    typeof row.underlying === 'string' &&
    typeof row.expiration === 'string' &&
    typeof row.spot === 'number' &&
    Array.isArray(row.topOi) &&
    Array.isArray(row.topCalls) &&
    Array.isArray(row.topPuts) &&
    typeof row.generatedAt === 'string'
  );
}

export async function buildOptionsIntelReport(
  underlying: string,
  expiration: string,
  extraProbabilityLevels: number[] = []
): Promise<OptionsIntelReport> {
  const ticker = underlying.replace(/^\$/, '').replace(/^US\./i, '').toUpperCase();
  const url = new URL(
    `${controlPlaneBaseUrl()}/api/v1/options/intel/${encodeURIComponent(ticker)}`
  );
  url.searchParams.set('expiration', expiration);
  if (extraProbabilityLevels.length) {
    url.searchParams.set(
      'levels',
      extraProbabilityLevels
        .filter((value) => Number.isFinite(value) && value > 0)
        .join(',')
    );
  }
  const response = await fetch(url, {
    headers: researchHeaders(),
    cache: 'no-store',
    signal: AbortSignal.timeout(8_000),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(
      `Rust options engine unavailable (${response.status})${detail ? `: ${detail.slice(0, 240)}` : ''}`
    );
  }
  const payload: unknown = await response.json();
  if (!isOptionsIntelReport(payload)) {
    throw new Error('Rust options engine returned an invalid presentation contract.');
  }
  return payload;
}
