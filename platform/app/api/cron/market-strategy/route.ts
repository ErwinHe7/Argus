import { NextRequest, NextResponse } from 'next/server';
import { runMarketResearch } from '@/lib/market-intelligence/engine';
import { recordAudit } from '@/lib/market-intelligence/audit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const ROUTE = '/api/cron/market-strategy';

export async function GET(req: NextRequest) {
  const secret = process.env.MARKET_CRON_SECRET || process.env.CRON_SECRET;
  const provided =
    req.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ||
    req.nextUrl.searchParams.get('secret');

  if (secret && provided !== secret) {
    await recordAudit({ route: ROUTE, actor: 'cron', action: 'unauthorized', status: 'blocked' });
    return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  }

  const watchlist = (process.env.MARKET_STRATEGY_WATCHLIST || 'NVDA,AMD,TSLA,PLTR,COIN,MSFT,AVGO')
    .split(',')
    .map((ticker) => ticker.trim())
    .filter(Boolean);
  const query =
    process.env.MARKET_STRATEGY_QUERY ||
    'Reuters breaking news, X influencer posts, Truth Social provider events, AI chips, Tesla, crypto, Fed rates, unusual market tape';

  const report = await runMarketResearch({
    query,
    watchlist,
    horizon: 'intraday',
    mode: 'live_signal',
  });

  await recordAudit({
    route: ROUTE,
    actor: 'cron',
    action: 'scheduled_run',
    status: report.compliance.allowed ? 'ok' : 'blocked',
    meta: {
      watchlist,
      events: report.events.length,
      signals: report.signals.length,
      severity: report.compliance.severity,
    },
  });

  return NextResponse.json(report, { headers: { 'Cache-Control': 'no-store' } });
}
