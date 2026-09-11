import { NextRequest, NextResponse } from 'next/server';
import { parseDiscoveryQuery } from '@/lib/investing/discovery';
import { getStockDiscovery } from '@/lib/investing/discovery-server';

export const dynamic = 'force-dynamic';
export async function GET(request: NextRequest) {
  const query = parseDiscoveryQuery(request.nextUrl.searchParams);
  if (!query) return NextResponse.json({ error: 'invalid_query' }, { status: 400 });
  try {
    const result = await getStockDiscovery(query);
    return NextResponse.json(result, { status: result.available ? 200 : 503,
      headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
  } catch {
    return NextResponse.json({ error: 'directory_unavailable' }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
