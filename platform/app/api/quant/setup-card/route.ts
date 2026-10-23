import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { fetchQuantSeries } from '@/lib/quant/data';
import { buildSetupCard, type Candle } from '@/lib/quant/setup-card';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/quant/setup-card';
/** 画一张卡至少要能算出 SMA20 + 一段可辨认的箱体 */
const MIN_BARS = 60;

export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;

  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 30, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  const url = new URL(req.url);
  const symbol = (url.searchParams.get('symbol') || '')
    .replace(/^\$/, '')
    .toUpperCase();
  if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(symbol)) {
    return NextResponse.json({ error: 'Invalid symbol.' }, { status: 400 });
  }

  const rangeParam = url.searchParams.get('range') || '1y';
  const range: '6mo' | '1y' | '2y' =
    rangeParam === '6mo' || rangeParam === '2y' ? rangeParam : '1y';

  try {
    const series = await fetchQuantSeries(symbol, range);
    if (series.closes.length < MIN_BARS) {
      return NextResponse.json(
        {
          error: `Need ≥${MIN_BARS} bars; got ${series.closes.length}. Try a longer range.`,
        },
        { status: 422 }
      );
    }

    const candles: Candle[] = series.dates.map((date, i) => ({
      date,
      open: series.opens[i],
      high: series.highs[i],
      low: series.lows[i],
      close: series.closes[i],
      volume: series.volumes[i],
    }));

    const card = buildSetupCard({ symbol, candles });
    if (!card) {
      return NextResponse.json(
        { error: `Could not build a setup card for ${symbol}.` },
        { status: 422 }
      );
    }

    return NextResponse.json({
      card,
      source: series.source,
      asOf: series.asOf,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error.';
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
