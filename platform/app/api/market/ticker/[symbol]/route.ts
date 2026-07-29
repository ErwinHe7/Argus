import { NextRequest, NextResponse } from 'next/server';
import { buildTickerConsoleReport } from '@/lib/market-intelligence/ticker-console';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/market/ticker';

export async function GET(req: NextRequest, { params }: { params: { symbol: string } }) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 30, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const symbol = params.symbol.replace(/^\$/, '').toUpperCase();
  if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(symbol)) {
    return NextResponse.json({ error: 'Invalid ticker.' }, { status: 400 });
  }

  try {
    const report = await buildTickerConsoleReport(symbol);
    return NextResponse.json(report, { headers: { 'Cache-Control': 'no-store' } });
  } catch (err) {
    console.error('[/api/market/ticker]', err);
    return NextResponse.json({ error: 'Ticker console unavailable.' }, { status: 503 });
  }
}
