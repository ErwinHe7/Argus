import { NextRequest, NextResponse } from 'next/server';
import {
  MarketMonitorStorageError,
  runDueMarketMonitors,
} from '@/lib/quant/market-monitors';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 300;

function authorized(request: NextRequest) {
  const expected =
    process.env.MARKET_MONITOR_CRON_SECRET || process.env.CRON_SECRET;
  if (!expected) return process.env.NODE_ENV !== 'production';
  const supplied =
    request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ||
    request.nextUrl.searchParams.get('secret');
  return supplied === expected;
}

function regularMarketWindow() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/New_York',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date());
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  if (value.weekday === 'Sat' || value.weekday === 'Sun') return false;
  const minute = Number(value.hour) * 60 + Number(value.minute);
  return minute >= 9 * 60 + 25 && minute <= 16 * 60 + 10;
}

export async function GET(request: NextRequest) {
  if (!authorized(request)) {
    return NextResponse.json({ ok: false, error: 'unauthorized' }, { status: 401 });
  }
  const force = request.nextUrl.searchParams.get('force') === 'true';
  if (!force && !regularMarketWindow()) {
    return NextResponse.json({
      ok: true,
      skipped: true,
      reason: 'outside_regular_market_window',
    });
  }
  try {
    const result = await runDueMarketMonitors(50);
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: 'monitor_worker_unavailable',
        detail:
          error instanceof MarketMonitorStorageError
            ? error.message
            : String(error),
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}
