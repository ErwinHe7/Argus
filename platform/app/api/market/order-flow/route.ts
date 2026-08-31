import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { buildOrderFlowReport } from '@/lib/market-intelligence/order-flow';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 20;

const ROUTE = '/api/market/order-flow';
const QuerySchema = z.object({ ticker: z.string().min(1).max(10) });

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    return NextResponse.json(
      { error: user.authenticated ? 'forbidden' : 'authentication_required' },
      { status: user.authenticated ? 403 : 401, headers: { 'Cache-Control': 'no-store' } }
    );
  }

  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 40, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, {
      status: 429,
      headers: { 'Retry-After': String(rate.resetSeconds) },
    });
  }

  const parsed = QuerySchema.safeParse({ ticker: req.nextUrl.searchParams.get('ticker') || '' });
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid ticker.' }, { status: 400 });
  }

  try {
    const report = await buildOrderFlowReport(parsed.data.ticker, {
      allowRetailFallback: false,
    });
    return NextResponse.json(report, {
      headers: { 'Cache-Control': 'no-store', 'X-RateLimit-Remaining': String(rate.remaining) },
    });
  } catch (err) {
    console.error('[/api/market/order-flow]', err);
    return NextResponse.json({ error: 'Order flow unavailable.' }, { status: 503 });
  }
}
