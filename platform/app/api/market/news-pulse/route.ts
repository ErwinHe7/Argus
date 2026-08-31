import { NextRequest, NextResponse } from 'next/server';
import { buildNewsPulseReport } from '@/lib/market-intelligence/news-pulse';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 25;

const ROUTE = '/api/market/news-pulse';

export async function GET(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 30, 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  const tickersParam = req.nextUrl.searchParams.get('tickers') || '';
  const tickers = tickersParam
    ? tickersParam.split(',').map((t) => t.trim()).filter(Boolean)
    : undefined;

  try {
    const report = await buildNewsPulseReport(tickers);
    return NextResponse.json(report, {
      headers: { 'Cache-Control': 'no-store', 'X-RateLimit-Remaining': String(rate.remaining) },
    });
  } catch (err) {
    console.error('[/api/market/news-pulse]', err);
    return NextResponse.json({ error: 'News pulse unavailable.' }, { status: 503 });
  }
}
