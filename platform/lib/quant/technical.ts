import { fetchQuantSeries, type QuantSeries } from './data';
import { rsi } from './factors';
import { QUANT_DEFAULT_UNIVERSE } from './universe';

export type KdjPoint = {
  date: string;
  close: number;
  high: number;
  low: number;
  rsv: number | null;
  k: number | null;
  d: number | null;
  j: number | null;
};

export type KdjSignalRow = {
  ticker: string;
  price: number | null;
  asOf: string | null;
  signalDate: string;
  daysSinceCross: number;
  score: number;
  rsi14: number | null;
  current: {
    k: number | null;
    d: number | null;
    j: number | null;
  };
  cross: {
    k: number;
    d: number;
    j: number;
    previousK: number;
    previousD: number;
  };
  notes: string[];
  source: QuantSeries['source'];
};

export type KdjScanSettings = {
  range: '6mo' | '1y' | '2y';
  kdjPeriod: number;
  kSmoothing: number;
  dSmoothing: number;
  lowZoneMax: number;
  crossLookbackDays: number;
  limit: number;
};

export type KdjScanReport = {
  generatedAt: string;
  universeSource: string;
  configuredUniverseCount: number;
  scanned: number;
  matched: number;
  truncated: boolean;
  rows: KdjSignalRow[];
  errors: Array<{ ticker: string; reason: string }>;
  settings: KdjScanSettings;
  warning: string | null;
};

export type KdjScanOptions = {
  symbols?: readonly string[];
  range?: KdjScanSettings['range'];
  lowZoneMax?: number;
  crossLookbackDays?: number;
  limit?: number;
};

type TechnicalUniverse = {
  symbols: string[];
  source: string;
  warning: string | null;
};

const DEFAULT_SCAN_LIMIT = 80;
const DEFAULT_MAX_SCAN_LIMIT = 250;
const DEFAULT_CONCURRENCY = 8;

export async function runKdjLowCrossScan(options: KdjScanOptions = {}): Promise<KdjScanReport> {
  const generatedAt = new Date().toISOString();
  const universe = await resolveTechnicalUniverse(options.symbols);
  const maxLimit = clampInt(readIntEnv('TECHNICAL_SCAN_MAX_PER_REQUEST', DEFAULT_MAX_SCAN_LIMIT), 1, 1000);
  const defaultLimit = options.symbols?.length
    ? options.symbols.length
    : readIntEnv('TECHNICAL_SCAN_DEFAULT_LIMIT', DEFAULT_SCAN_LIMIT);
  const limit = clampInt(options.limit ?? defaultLimit, 1, Math.min(maxLimit, universe.symbols.length || 1));
  const symbols = universe.symbols.slice(0, limit);
  const settings: KdjScanSettings = {
    range: options.range ?? '6mo',
    kdjPeriod: 9,
    kSmoothing: 3,
    dSmoothing: 3,
    lowZoneMax: clampNumber(options.lowZoneMax ?? 35, 5, 60),
    crossLookbackDays: clampInt(options.crossLookbackDays ?? 3, 1, 10),
    limit,
  };

  const errors: Array<{ ticker: string; reason: string }> = [];
  const rows: KdjSignalRow[] = [];

  const results = await mapLimit(symbols, DEFAULT_CONCURRENCY, async (ticker) => {
    try {
      return await analyzeKdjLowCross(ticker, settings);
    } catch (err) {
      errors.push({
        ticker,
        reason: err instanceof Error ? err.message : 'scan failed',
      });
      return null;
    }
  });

  for (const row of results) {
    if (row) rows.push(row);
  }

  rows.sort((a, b) => {
    if (a.daysSinceCross !== b.daysSinceCross) return a.daysSinceCross - b.daysSinceCross;
    return b.score - a.score;
  });

  return {
    generatedAt,
    universeSource: universe.source,
    configuredUniverseCount: universe.symbols.length,
    scanned: symbols.length,
    matched: rows.length,
    truncated: universe.symbols.length > symbols.length,
    rows,
    errors,
    settings,
    warning: universe.warning,
  };
}

export function computeKdj(
  highs: number[],
  lows: number[],
  closes: number[],
  dates: string[],
  period = 9,
  kSmoothing = 3,
  dSmoothing = 3
): KdjPoint[] {
  const points: KdjPoint[] = [];
  let previousK = 50;
  let previousD = 50;

  for (let i = 0; i < closes.length; i += 1) {
    const high = highs[i];
    const low = lows[i];
    const close = closes[i];
    const date = dates[i];

    if (i < period - 1) {
      points.push({ date, close, high, low, rsv: null, k: null, d: null, j: null });
      continue;
    }

    const windowHigh = Math.max(...highs.slice(i - period + 1, i + 1));
    const windowLow = Math.min(...lows.slice(i - period + 1, i + 1));
    const rsv = windowHigh === windowLow ? 50 : ((close - windowLow) / (windowHigh - windowLow)) * 100;
    const k = ((kSmoothing - 1) * previousK + rsv) / kSmoothing;
    const d = ((dSmoothing - 1) * previousD + k) / dSmoothing;
    const j = 3 * k - 2 * d;

    points.push({
      date,
      close,
      high,
      low,
      rsv,
      k,
      d,
      j,
    });

    previousK = k;
    previousD = d;
  }

  return points;
}

async function analyzeKdjLowCross(
  ticker: string,
  settings: KdjScanSettings
): Promise<KdjSignalRow | null> {
  const series = await fetchQuantSeries(ticker, settings.range);
  if (series.closes.length < settings.kdjPeriod + settings.crossLookbackDays + 5) {
    throw new Error(`only ${series.closes.length} daily bars`);
  }

  const points = computeKdj(
    series.highs,
    series.lows,
    series.closes,
    series.dates,
    settings.kdjPeriod,
    settings.kSmoothing,
    settings.dSmoothing
  );
  const cross = findRecentLowCross(points, settings.crossLookbackDays, settings.lowZoneMax);
  if (!cross) return null;

  const current = points.at(-1);
  const rsi14 = rsi(series.closes, 14);
  const daysSinceCross = points.length - 1 - cross.index;
  const score = scoreKdjSignal(cross.point, current, daysSinceCross, rsi14, settings);
  const notes = buildSignalNotes(cross.point, current, daysSinceCross, rsi14);

  return {
    ticker,
    price: series.currentPrice,
    asOf: series.asOf,
    signalDate: cross.point.date,
    daysSinceCross,
    score,
    rsi14,
    current: {
      k: current?.k ?? null,
      d: current?.d ?? null,
      j: current?.j ?? null,
    },
    cross: {
      k: cross.point.k,
      d: cross.point.d,
      j: cross.point.j,
      previousK: cross.previous.k,
      previousD: cross.previous.d,
    },
    notes,
    source: series.source,
  };
}

function findRecentLowCross(points: KdjPoint[], lookbackDays: number, lowZoneMax: number) {
  const start = Math.max(1, points.length - lookbackDays);
  let latest:
    | {
        index: number;
        point: KdjPoint & { k: number; d: number; j: number };
        previous: KdjPoint & { k: number; d: number };
      }
    | null = null;

  for (let i = start; i < points.length; i += 1) {
    const previous = points[i - 1];
    const point = points[i];
    if (!hasKdj(previous) || !hasKdj(point)) continue;

    const crossedUp = previous.k <= previous.d && point.k > point.d;
    const lowZone = point.k <= lowZoneMax && point.d <= lowZoneMax;
    if (crossedUp && lowZone) {
      latest = { index: i, point, previous };
    }
  }

  return latest;
}

function hasKdj(point: KdjPoint): point is KdjPoint & { k: number; d: number; j: number } {
  return (
    Number.isFinite(point.k) &&
    Number.isFinite(point.d) &&
    Number.isFinite(point.j)
  );
}

function scoreKdjSignal(
  cross: KdjPoint & { k: number; d: number; j: number },
  current: KdjPoint | undefined,
  daysSinceCross: number,
  rsi14: number | null,
  settings: KdjScanSettings
) {
  const lowBonus = Math.max(0, settings.lowZoneMax - Math.max(cross.k, cross.d));
  const freshnessBonus = Math.max(0, settings.crossLookbackDays - daysSinceCross) * 4;
  const spreadBonus =
    current && Number.isFinite(current.k) && Number.isFinite(current.d) && (current.k as number) > (current.d as number)
      ? 5
      : -3;
  const jBonus = current && Number.isFinite(current.j) && Number.isFinite(current.d)
    ? Math.max(-4, Math.min(6, (((current.j as number) - (current.d as number)) / 10)))
    : 0;
  const rsiBonus = rsi14 !== null && rsi14 < 45 ? 3 : 0;
  return lowBonus + freshnessBonus + spreadBonus + jBonus + rsiBonus;
}

function buildSignalNotes(
  cross: KdjPoint & { k: number; d: number; j: number },
  current: KdjPoint | undefined,
  daysSinceCross: number,
  rsi14: number | null
): string[] {
  const notes = [
    daysSinceCross === 0 ? '最新交易日金叉' : `${daysSinceCross} 个交易日前金叉`,
    `金叉点 K=${cross.k.toFixed(1)} / D=${cross.d.toFixed(1)}`,
  ];
  if (current && hasKdj(current)) {
    notes.push(current.k > current.d ? 'K 仍在 D 上方' : '金叉后已回落');
  }
  if (rsi14 !== null) {
    notes.push(rsi14 < 45 ? 'RSI 仍偏低位' : 'RSI 已脱离低位');
  }
  return notes;
}

async function resolveTechnicalUniverse(symbols?: readonly string[]): Promise<TechnicalUniverse> {
  const explicit = normalizeSymbols(symbols ?? []);
  if (explicit.length > 0) {
    return { symbols: explicit, source: 'query:tickers', warning: null };
  }

  const envList = normalizeSymbols(process.env.TECHNICAL_SCAN_UNIVERSE || '');
  if (envList.length > 0) {
    return { symbols: envList, source: 'env:TECHNICAL_SCAN_UNIVERSE', warning: null };
  }

  const universeUrl = process.env.TECHNICAL_UNIVERSE_URL?.trim();
  if (universeUrl) {
    try {
      const headers: Record<string, string> = {
        accept: 'application/json,text/csv,text/plain',
      };
      const auth = process.env.TECHNICAL_UNIVERSE_AUTH_HEADER?.trim();
      if (auth) headers.authorization = auth;

      const res = await fetch(universeUrl, { headers, cache: 'no-store' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const contentType = res.headers.get('content-type') || '';
      const symbolsFromRemote = contentType.includes('json')
        ? parseUniversePayload(await res.json())
        : parseUniverseText(await res.text());
      const normalized = normalizeSymbols(symbolsFromRemote);
      if (normalized.length === 0) throw new Error('empty symbol list');
      return { symbols: normalized, source: 'env:TECHNICAL_UNIVERSE_URL', warning: null };
    } catch (err) {
      return {
        symbols: normalizeSymbols(QUANT_DEFAULT_UNIVERSE),
        source: 'default:QUANT_DEFAULT_UNIVERSE',
        warning:
          `TECHNICAL_UNIVERSE_URL failed; using default universe. ` +
          `${err instanceof Error ? err.message : 'unknown error'}`,
      };
    }
  }

  return {
    symbols: normalizeSymbols(QUANT_DEFAULT_UNIVERSE),
    source: 'default:QUANT_DEFAULT_UNIVERSE',
    warning: 'No all-market universe provider configured yet.',
  };
}

function normalizeSymbols(input: string | readonly unknown[]): string[] {
  const raw = typeof input === 'string' ? input.split(/[\s,;]+/) : input;
  const seen = new Set<string>();
  const symbols: string[] = [];

  for (const item of raw) {
    const symbol = String(item || '')
      .replace(/^\$/, '')
      .trim()
      .toUpperCase();
    if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(symbol)) continue;
    if (seen.has(symbol)) continue;
    seen.add(symbol);
    symbols.push(symbol);
  }

  return symbols;
}

function parseUniversePayload(payload: unknown): string[] {
  if (Array.isArray(payload)) {
    return payload.flatMap((item) => {
      if (typeof item === 'string') return [item];
      if (item && typeof item === 'object') {
        const row = item as Record<string, unknown>;
        return [row.symbol, row.ticker, row.code].filter(Boolean).map(String);
      }
      return [];
    });
  }

  if (payload && typeof payload === 'object') {
    const row = payload as Record<string, unknown>;
    for (const key of ['symbols', 'tickers', 'data', 'results']) {
      const value = row[key];
      if (Array.isArray(value)) return parseUniversePayload(value);
    }
  }

  return [];
}

function parseUniverseText(text: string): string[] {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length === 0) return [];

  const first = splitCsvLine(lines[0]);
  const symbolIndex = first.findIndex((cell) => /^(symbol|ticker|code)$/i.test(cell.trim()));
  const start = symbolIndex >= 0 ? 1 : 0;
  const index = symbolIndex >= 0 ? symbolIndex : 0;

  return lines.slice(start).map((line) => splitCsvLine(line)[index] || '');
}

function splitCsvLine(line: string): string[] {
  return line.split(',').map((cell) => cell.trim().replace(/^"|"$/g, ''));
}

function clampInt(value: number, min: number, max: number): number {
  const n = Number.isFinite(value) ? Math.trunc(value) : min;
  return Math.max(min, Math.min(max, n));
}

function clampNumber(value: number, min: number, max: number): number {
  const n = Number.isFinite(value) ? value : min;
  return Math.max(min, Math.min(max, n));
}

function readIntEnv(key: string, fallback: number): number {
  const value = Number(process.env[key]);
  return Number.isFinite(value) ? Math.trunc(value) : fallback;
}

async function mapLimit<T, R>(
  items: readonly T[],
  limit: number,
  worker: (item: T, index: number) => Promise<R>
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let index = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    for (;;) {
      const current = index;
      index += 1;
      if (current >= items.length) return;
      results[current] = await worker(items[current], current);
    }
  });
  await Promise.all(workers);
  return results;
}
