import { NextRequest, NextResponse } from 'next/server';
import { buildInstitutionalHoldingsReport } from '@/lib/market-intelligence/institutional-holdings';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/market/institutional-holdings';

export async function GET(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 20, 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  const ticker = (req.nextUrl.searchParams.get('ticker') || 'NVDA').trim().toUpperCase();
  if (!/^[A-Z0-9.$-]{1,12}$/.test(ticker)) {
    return NextResponse.json({ error: 'Invalid ticker.' }, { status: 400 });
  }

  try {
    const report = await buildInstitutionalHoldingsReport(ticker);
    return NextResponse.json(report, {
      headers: {
        'Cache-Control': 's-maxage=3600, stale-while-revalidate=21600',
        'X-RateLimit-Remaining': String(rate.remaining),
      },
    });
  } catch (err) {
    console.error('[/api/market/institutional-holdings]', err);
    return NextResponse.json({ error: 'Institutional holdings unavailable.' }, { status: 503 });
  }
}
