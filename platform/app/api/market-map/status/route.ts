import { NextResponse } from 'next/server';
import { getPublicMarketMapStatus } from '@/lib/market-map/public-server';

export const dynamic = 'force-dynamic';

export async function GET() {
  return NextResponse.json(await getPublicMarketMapStatus(), { headers: { 'Cache-Control': 'no-store' } });
}
