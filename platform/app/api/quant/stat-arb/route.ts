import { NextRequest, NextResponse } from 'next/server';
import { fetchQuantSeries } from '@/lib/quant/data';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { QUANT_DEFAULT_UNIVERSE } from '@/lib/quant/universe';
import {
  runStatArbModel,
  STAT_ARB_DEFAULTS,
  type StatArbSeries,
} from '@/lib/quant/stat-arb';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const ROUTE = '/api/quant/stat-arb';

function parseUniverse(raw: string | null): string[] {
  if (!raw) return [...QUANT_DEFAULT_UNIVERSE];
  const tickers = raw
    .split(/[,;\s]+/)
    .map((t) => t.trim().toUpperCase().replace(/^\$/, ''))
    .filter((t) => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(t));
  const unique = Array.from(new Set(tickers));
  return unique.length > 0 ? unique.slice(0, 60) : [...QUANT_DEFAULT_UNIVERSE];
}

function clampFloat(raw: string | null, def: number, min: number, max: number): number {
  const n = raw === null ? NaN : Number.parseFloat(raw);
  if (!Number.isFinite(n)) return def;
  return Math.max(min, Math.min(max, n));
}

async function fetchSeries(symbols: string[]): Promise<StatArbSeries[]> {
  const out: StatArbSeries[] = [];
  const BATCH = 12;
  for (let i = 0; i < symbols.length; i += BATCH) {
    const batch = symbols.slice(i, i + BATCH);
    const settled = await Promise.allSettled(batch.map((symbol) => fetchQuantSeries(symbol, '5y')));
    for (const result of settled) {
      if (result.status !== 'fulfilled') continue;
      const s = result.value;
      if (s.closes.length < 220) continue;
      out.push({
        symbol: s.symbol,
        dates: s.dates,
        closes: s.closes,
        volumes: s.volumes,
        currentPrice: s.currentPrice,
        asOf: s.asOf,
      });
    }
  }
  return out;
}

export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 6, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit. Try again in a minute.' }, { status: 429 });
  }

  const url = new URL(req.url);
  const universe = parseUniverse(url.searchParams.get('universe'));
  const benchmark = (url.searchParams.get('benchmark') || STAT_ARB_DEFAULTS.benchmarkSymbol)
    .trim()
    .toUpperCase()
    .replace(/^\$/, '');
  if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(benchmark)) {
    return NextResponse.json({ error: 'Invalid benchmark.' }, { status: 400 });
  }

  const config = {
    ...STAT_ARB_DEFAULTS,
    benchmarkSymbol: benchmark,
    targetGross: clampFloat(url.searchParams.get('gross'), STAT_ARB_DEFAULTS.targetGross, 0.1, 2),
    maxAbsWeight: clampFloat(
      url.searchParams.get('cap'),
      STAT_ARB_DEFAULTS.maxAbsWeight,
      0.01,
      0.25
    ),
  };

  try {
    const symbols = Array.from(new Set([...universe, benchmark]));
    const series = await fetchSeries(symbols);
    const benchmarkSeries = series.find((s) => s.symbol.toUpperCase() === benchmark) ?? null;
    const modelSeries = series.filter((s) => s.symbol.toUpperCase() !== benchmark);
    const report = runStatArbModel(modelSeries, benchmarkSeries, config);
    return NextResponse.json(
      {
        requestedUniverse: universe,
        fetchedUniverse: modelSeries.map((s) => s.symbol),
        benchmarkFetched: Boolean(benchmarkSeries),
        ...report,
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (err) {
    console.error('[/api/quant/stat-arb]', err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Stat-arb model failed.' },
      { status: 503 }
    );
  }
}
