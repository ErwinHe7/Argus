import { NextRequest, NextResponse } from 'next/server';
import { getPublicMarketMapSnapshots } from '@/lib/market-map/public-server';
import { DEFAULT_PUBLIC_MARKET_SYMBOL, isPublicMarketSymbol } from '@/lib/market-map/public-catalog';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function GET(request: NextRequest) {
  const headers = { 'Cache-Control': 'no-store', 'X-Leo-Market-Map': 'public-daily-observations' };
  const query = request.nextUrl.searchParams;
  const symbol = query.get('symbol') ?? DEFAULT_PUBLIC_MARKET_SYMBOL;
  if ([...query.keys()].some((key) => key !== 'symbol') || query.getAll('symbol').length > 1 || !isPublicMarketSymbol(symbol)) {
    return NextResponse.json({ error: 'invalid_public_market_query' }, { status: 400, headers });
  }
  try {
    const snapshots = await getPublicMarketMapSnapshots(symbol);
    if (snapshots.length) return NextResponse.json({ mode: 'public_market', snapshots }, { headers });
  } catch { /* A source outage must never turn into synthetic data. */ }
  return NextResponse.json({ error: 'public_market_data_unavailable' }, { status: 503, headers });
}
