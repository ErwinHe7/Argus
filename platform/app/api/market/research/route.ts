import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { runMarketResearch } from '@/lib/market-intelligence/engine';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const BodySchema = z.object({
  query: z.string().min(1).max(600),
  watchlist: z.array(z.string().min(1).max(12)).max(30).default([]),
  horizon: z.enum(['intraday', 'swing', 'long_term']).default('swing'),
  mode: z.enum(['paper', 'live_signal']).default('paper'),
});

const ROUTE = '/api/market/research';

export async function POST(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const limit = Number(process.env.MARKET_RESEARCH_RATE_LIMIT || 30);
  const windowMs = Number(process.env.MARKET_RESEARCH_RATE_WINDOW_MS || 60_000);
  const rate = checkRateLimit(key, limit, windowMs);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit exceeded. Try again shortly.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  const body = await req.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);

  if (!parsed.success) {
    await recordAudit({ route: ROUTE, actor: key, action: 'invalid_body', status: 'error' });
    return NextResponse.json({ error: 'Invalid market research request.' }, { status: 400 });
  }

  try {
    const report = await runMarketResearch(parsed.data);
    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'research_run',
      status: report.compliance.allowed ? 'ok' : 'blocked',
      meta: {
        query: parsed.data.query.slice(0, 120),
        watchlist: parsed.data.watchlist,
        horizon: parsed.data.horizon,
        mode: parsed.data.mode,
        events: report.events.length,
        signals: report.signals.length,
        severity: report.compliance.severity,
      },
    });
    return NextResponse.json(report, {
      headers: {
        'Cache-Control': 'no-store',
        'X-RateLimit-Remaining': String(rate.remaining),
      },
    });
  } catch (err) {
    console.error('[/api/market/research] failed', err);
    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'engine_error',
      status: 'error',
      meta: { message: err instanceof Error ? err.message : 'unknown' },
    });
    return NextResponse.json({ error: 'Market research agents are unavailable. Try again.' }, { status: 503 });
  }
}
