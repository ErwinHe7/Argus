import { NextRequest, NextResponse } from 'next/server';
import { fetchQuantSeries } from '@/lib/quant/data';
import { runBacktest, type BacktestStrategy } from '@/lib/quant/backtest';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/quant/backtest';

const VALID_STRATEGIES: BacktestStrategy[] = [
  'momentum_breakout',
  'mean_reversion_rsi',
  'trend_sma_cross',
  'vol_target_trend',
  'buy_and_hold',
];

export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 20, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const url = new URL(req.url);
  const symbol = (url.searchParams.get('symbol') || '').replace(/^\$/, '').toUpperCase();
  if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(symbol)) {
    return NextResponse.json({ error: 'Invalid symbol.' }, { status: 400 });
  }

  const strategy = (url.searchParams.get('strategy') || 'trend_sma_cross') as BacktestStrategy;
  if (!VALID_STRATEGIES.includes(strategy)) {
    return NextResponse.json({ error: 'Invalid strategy.' }, { status: 400 });
  }

  const rangeParam = (url.searchParams.get('range') || '2y') as '1y' | '2y' | '5y';
  const range: '1y' | '2y' | '5y' = ['1y', '2y', '5y'].includes(rangeParam) ? rangeParam : '2y';

  try {
    const series = await fetchQuantSeries(symbol, range);
    if (series.closes.length < 220) {
      return NextResponse.json(
        { error: `Need ≥220 bars; got ${series.closes.length}. Try a longer range.` },
        { status: 422 }
      );
    }
    const result = runBacktest(symbol, series.closes, series.dates, {
      strategy,
      feeBps: 5,
      slippageBps: 5,
      startCash: 100_000,
    });
    return NextResponse.json(
      {
        symbol,
        strategy,
        range,
        asOf: series.asOf,
        currentPrice: series.currentPrice,
        ...result,
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (err) {
    console.error('[/api/quant/backtest]', err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Backtest failed.' },
      { status: 503 }
    );
  }
}
