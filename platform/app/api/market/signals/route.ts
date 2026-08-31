import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { buildMarketSignalReport } from '@/lib/market-intelligence/market-signal';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 20;

const ROUTE = '/api/market/signals';

const QuerySchema = z.object({
  tickers: z
    .string()
    .optional()
    .transform((value) =>
      value
        ? value
            .split(',')
            .map((ticker) => ticker.trim())
            .filter(Boolean)
        : []
    ),
});

export async function GET(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, Number(process.env.MARKET_SIGNAL_RATE_LIMIT || 60), 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  const parsed = QuerySchema.safeParse({
    tickers: req.nextUrl.searchParams.get('tickers') || '',
  });

  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid signal query.' }, { status: 400 });
  }

  try {
    const report = await buildMarketSignalReport(parsed.data.tickers);
    return NextResponse.json(report, {
      headers: {
        'Cache-Control': 'no-store',
        'X-RateLimit-Remaining': String(rate.remaining),
      },
    });
  } catch (err) {
    console.error('[/api/market/signals]', err);
    return NextResponse.json({ error: 'Market signal data unavailable.' }, { status: 503 });
  }
}
