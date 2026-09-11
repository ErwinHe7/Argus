import { NextRequest, NextResponse } from 'next/server';
import { parseIvLabQuery } from '@/lib/iv-lab/types';
import { getIvLabSymbol } from '@/lib/iv-lab/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  const headers = {
    'Cache-Control': 'private, no-store',
    'X-Leo-Research-Mode': 'historical-snapshot',
  };
  const symbol = parseIvLabQuery(request.nextUrl.searchParams);
  if (!symbol) return NextResponse.json({ error: 'invalid_iv_lab_query' }, { status: 400, headers });
  const snapshot = getIvLabSymbol(symbol);
  if (!snapshot) return NextResponse.json({ error: 'iv_lab_data_unavailable' }, { status: 503, headers });
  return NextResponse.json({ symbol: snapshot }, { headers });
}
