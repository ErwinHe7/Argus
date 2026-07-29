import { NextRequest, NextResponse } from 'next/server';
import { buildPriceAnomalyReport } from '@/lib/quant/price-anomalies';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 25;

export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const params = req.nextUrl.searchParams;
  const tickersParam = params.get('tickers');
  const includeReplay = params.get('replay') !== 'false';
  const universe = tickersParam
    ? tickersParam
        .split(/[\s,;]+/)
        .map((ticker) => ticker.trim())
        .filter(Boolean)
    : undefined;

  const report = await buildPriceAnomalyReport({ universe, includeReplay });

  return NextResponse.json(report, {
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}
