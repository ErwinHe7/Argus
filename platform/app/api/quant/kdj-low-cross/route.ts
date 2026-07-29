import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { runKdjLowCrossScan } from '@/lib/quant/technical';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const ROUTE = '/api/quant/kdj-low-cross';
const VALID_RANGES = ['6mo', '1y', '2y'] as const;

export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 8, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const url = new URL(req.url);
  const rangeParam = url.searchParams.get('range');
  const range = VALID_RANGES.includes(rangeParam as (typeof VALID_RANGES)[number])
    ? (rangeParam as (typeof VALID_RANGES)[number])
    : '6mo';
  const tickers = parseTickers(url.searchParams.get('tickers'));
  const limit = parseOptionalNumber(url.searchParams.get('limit'));
  const lowZoneMax = parseOptionalNumber(url.searchParams.get('lowZoneMax'));
  const crossLookbackDays = parseOptionalNumber(url.searchParams.get('crossLookbackDays'));

  try {
    const report = await runKdjLowCrossScan({
      symbols: tickers,
      range,
      limit,
      lowZoneMax,
      crossLookbackDays,
    });
    return NextResponse.json(report, { headers: { 'Cache-Control': 'no-store' } });
  } catch (err) {
    console.error('[/api/quant/kdj-low-cross]', err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'KDJ scan unavailable.' },
      { status: 503 }
    );
  }
}

function parseTickers(value: string | null): string[] | undefined {
  if (!value) return undefined;
  const symbols = value
    .split(/[\s,;]+/)
    .map((s) => s.replace(/^\$/, '').trim().toUpperCase())
    .filter((s) => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(s));
  return symbols.length > 0 ? symbols : undefined;
}

function parseOptionalNumber(value: string | null): number | undefined {
  if (!value) return undefined;
  const n = Number(value);
  return Number.isFinite(n) ? n : undefined;
}
