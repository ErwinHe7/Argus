import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { checkIbkrHealth, getIbkrPublicConfig } from '@/lib/market-intelligence/ibkr-client-portal';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 15;

const ROUTE = '/api/market/ibkr/health';

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    return NextResponse.json(
      { error: user.authenticated ? 'forbidden' : 'authentication_required' },
      { status: user.authenticated ? 403 : 401, headers: { 'Cache-Control': 'no-store' } }
    );
  }

  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 30, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const publicConfig = getIbkrPublicConfig();
  if (!publicConfig.configured || !publicConfig.enabled) {
    return NextResponse.json(
      {
        ...publicConfig,
        ok: false,
        checkedAt: new Date().toISOString(),
        reason: publicConfig.configured
          ? 'IBKR_BASE_URL is configured, but IBKR_MARKET_DATA_ENABLED is not true.'
          : 'IBKR_BASE_URL is not configured.',
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  }

  const health = await checkIbkrHealth();
  return NextResponse.json(health, { headers: { 'Cache-Control': 'no-store' } });
}
