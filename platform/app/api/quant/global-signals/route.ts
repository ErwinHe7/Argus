import { NextRequest, NextResponse } from 'next/server';
import { buildGlobalSignalsReport } from '@/lib/quant/global-signals';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const params = req.nextUrl.searchParams;
  const includeReplay = params.get('replay') !== 'false';
  const tickersParam = params.get('tickers');
  const universe = tickersParam
    ? tickersParam
        .split(/[\s,;]+/)
        .map((ticker) => ticker.trim())
        .filter(Boolean)
    : undefined;

  const report = await buildGlobalSignalsReport({ includeReplay, universe });

  return NextResponse.json(report, {
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}
