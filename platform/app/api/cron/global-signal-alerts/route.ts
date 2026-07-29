import { NextRequest, NextResponse } from 'next/server';
import { dispatchGlobalSignalAlerts } from '@/lib/quant/global-signal-alerts';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const secret = process.env.GLOBAL_SIGNAL_ALERT_SECRET || process.env.MARKET_CRON_SECRET || process.env.CRON_SECRET;
  const provided = req.nextUrl.searchParams.get('secret') || req.headers.get('authorization')?.replace(/^Bearer\s+/i, '');

  if (secret && provided !== secret) {
    return NextResponse.json({ ok: false, error: 'Unauthorized' }, { status: 401 });
  }

  const force = req.nextUrl.searchParams.get('force') === 'true';
  const result = await dispatchGlobalSignalAlerts({ force });

  return NextResponse.json(result, {
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}
