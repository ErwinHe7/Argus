import { NextRequest, NextResponse } from 'next/server';
import { requirePaidResearchAccess } from '@/lib/research-access';
import { getMarketMapSnapshot, listMarketMapSnapshots } from '@/lib/market-map/server';
import { marketMapHorizonSchema } from '@/lib/market-map/schema';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function GET(request: NextRequest) {
  const headers = { 'Cache-Control': 'private, no-store', 'X-Leo-Market-Map': 'research-snapshot' };
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  if (!access.user.authenticated) return NextResponse.json({ error: 'authentication_required' }, { status: 401, headers });
  const query = request.nextUrl.searchParams;
  if ([...query.keys()].some((key) => !['symbol', 'horizon'].includes(key)) ||
      query.getAll('symbol').length > 1 || query.getAll('horizon').length > 1) {
    return NextResponse.json({ error: 'invalid_market_map_query' }, { status: 400, headers });
  }
  const horizon = marketMapHorizonSchema.safeParse(query.get('horizon') ?? '20d');
  const symbol = query.get('symbol');
  if (!horizon.success || (symbol !== null && !/^[A-Z][A-Z0-9.-]{0,15}$/.test(symbol))) {
    return NextResponse.json({ error: 'invalid_market_map_query' }, { status: 400, headers });
  }
  if (symbol === null) return NextResponse.json({ snapshots: await listMarketMapSnapshots() }, { headers });
  const snapshot = await getMarketMapSnapshot(symbol, horizon.data);
  if (!snapshot) return NextResponse.json({ error: 'market_map_unavailable' }, { status: 503, headers });
  return NextResponse.json({ snapshot }, { headers });
}
