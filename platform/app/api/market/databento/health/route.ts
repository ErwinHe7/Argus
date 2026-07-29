import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { probeDatabentoMarketData } from '@/lib/quant/research-client';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 15;

const ROUTE = '/api/market/databento/health';

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    return NextResponse.json(
      { error: user.authenticated ? 'forbidden' : 'authentication_required' },
      {
        status: user.authenticated ? 403 : 401,
        headers: { 'Cache-Control': 'no-store' },
      }
    );
  }

  const rate = checkRateLimit(rateLimitKey(req, ROUTE), 30, 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      { status: 429, headers: { 'Cache-Control': 'no-store' } }
    );
  }

  const receipt = await probeDatabentoMarketData();
  return NextResponse.json(receipt, {
    headers: { 'Cache-Control': 'no-store' },
  });
}
