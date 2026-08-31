import { NextRequest, NextResponse } from 'next/server';
import { buildMacroReport } from '@/lib/market-intelligence/macro';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 20;

const ROUTE = '/api/market/macro';

export async function GET(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 40, 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  try {
    const report = await buildMacroReport();
    return NextResponse.json(report, {
      headers: { 'Cache-Control': 'no-store', 'X-RateLimit-Remaining': String(rate.remaining) },
    });
  } catch (err) {
    console.error('[/api/market/macro]', err);
    return NextResponse.json({ error: 'Macro data unavailable.' }, { status: 503 });
  }
}
