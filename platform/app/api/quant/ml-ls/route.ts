import { NextRequest, NextResponse } from 'next/server';
import { fetchQuantSeries } from '@/lib/quant/data';
import {
  runMlLsBacktest,
  ML_LS_DEFAULTS,
  type MlLsPriceSeries,
  type MlLsConfig,
} from '@/lib/quant/ml-ls';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const ROUTE = '/api/quant/ml-ls';

// 默认股票池: 美股大盘横截面, 行业分散, 都有 >= 10 年历史
const DEFAULT_UNIVERSE = [
  'AAPL', 'MSFT', 'NVDA', 'AMZN', 'GOOGL', 'META', 'AVGO', 'TSLA',
  'JPM', 'BAC', 'WFC', 'GS', 'XOM', 'CVX', 'COP', 'UNH', 'JNJ', 'PFE',
  'PG', 'KO', 'PEP', 'WMT', 'HD', 'DIS', 'NFLX', 'INTC', 'AMD', 'MU',
  'CRM', 'ORCL',
];

const VALID_RANGES = ['2y', '5y'] as const;
type Range = (typeof VALID_RANGES)[number];

function parseUniverse(raw: string | null): string[] {
  if (!raw) return DEFAULT_UNIVERSE;
  const tickers = raw
    .split(/[,;\s]+/)
    .map((t) => t.trim().toUpperCase().replace(/^\$/, ''))
    .filter((t) => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(t));
  const uniq = Array.from(new Set(tickers));
  return uniq.length === 0 ? DEFAULT_UNIVERSE : uniq.slice(0, 40);
}

function clampInt(raw: string | null, def: number, min: number, max: number): number {
  const n = raw === null ? NaN : parseInt(raw, 10);
  if (!Number.isFinite(n)) return def;
  return Math.max(min, Math.min(max, Math.floor(n)));
}

function clampFloat(raw: string | null, def: number, min: number, max: number): number {
  const n = raw === null ? NaN : parseFloat(raw);
  if (!Number.isFinite(n)) return def;
  return Math.max(min, Math.min(max, n));
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
  const rangeParam = (url.searchParams.get('range') || '5y') as Range;
  const range: Range = VALID_RANGES.includes(rangeParam) ? rangeParam : '5y';

  const config: MlLsConfig = {
    forwardDays: clampInt(url.searchParams.get('h'), ML_LS_DEFAULTS.forwardDays, 1, 21),
    trainDays: clampInt(url.searchParams.get('train'), ML_LS_DEFAULTS.trainDays, 60, 1000),
    quantile: clampFloat(url.searchParams.get('q'), ML_LS_DEFAULTS.quantile, 0.05, 0.5),
    costBpsPerSide: clampFloat(url.searchParams.get('cost'), ML_LS_DEFAULTS.costBpsPerSide, 0, 100),
  };

  try {
    const start = Date.now();
    const series = await fetchUniverse(universe, range);
    const fetchedMs = Date.now() - start;
    if (series.length < 10) {
      return NextResponse.json(
        {
          error: `Only ${series.length} of ${universe.length} tickers returned data — need at least 10 to build a cross-section.`,
        },
        { status: 422 }
      );
    }

    const result = runMlLsBacktest(series, config);
    return NextResponse.json(
      {
        range,
        asOf: new Date().toISOString(),
        fetchedMs,
        universeRequested: universe,
        universeFetched: series.map((s) => s.symbol),
        ...result,
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (err) {
    console.error('[/api/quant/ml-ls]', err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Backtest failed.' },
      { status: 503 }
    );
  }
}

async function fetchUniverse(symbols: string[], range: Range): Promise<MlLsPriceSeries[]> {
  // 并发拉数据 (Yahoo 不喜欢一次性 30+ 个并发, 分两批)
  const BATCH = 12;
  const all: MlLsPriceSeries[] = [];
  for (let i = 0; i < symbols.length; i += BATCH) {
    const slice = symbols.slice(i, i + BATCH);
    const settled = await Promise.allSettled(
      slice.map((sym) => fetchQuantSeries(sym, range))
    );
    for (let j = 0; j < settled.length; j++) {
      const r = settled[j];
      if (r.status === 'fulfilled' && r.value.closes.length >= 220) {
        all.push({
          symbol: r.value.symbol,
          dates: r.value.dates,
          closes: r.value.closes,
          volumes: r.value.volumes,
        });
      }
    }
  }
  return all;
}
