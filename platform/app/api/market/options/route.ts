import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { buildOptionsIntelReport } from '@/lib/market-intelligence/options';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/market/options';

const QuerySchema = z.object({
  ticker: z.string().min(1).max(10),
  expiration: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'expiration must be YYYY-MM-DD'),
  levels: z
    .string()
    .optional()
    .transform((s) =>
      s
        ? s
            .split(',')
            .map((n) => Number(n.trim()))
            .filter((n) => Number.isFinite(n) && n > 0)
        : []
    ),
});

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    return NextResponse.json(
      { error: user.authenticated ? 'forbidden' : 'authentication_required' },
      { status: user.authenticated ? 403 : 401, headers: { 'Cache-Control': 'no-store' } }
    );
  }

  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(
    key,
    Number(process.env.MARKET_OPTIONS_RATE_LIMIT || 40),
    Number(process.env.MARKET_OPTIONS_RATE_WINDOW_MS || 60_000)
  );
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, {
      status: 429,
      headers: { 'Retry-After': String(rate.resetSeconds) },
    });
  }

  const parsed = QuerySchema.safeParse({
    ticker: req.nextUrl.searchParams.get('ticker') || '',
    expiration: req.nextUrl.searchParams.get('expiration') || nextFriday(),
    levels: req.nextUrl.searchParams.get('levels') || '',
  });
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid options query.', issues: parsed.error.flatten() }, { status: 400 });
  }

  try {
    const report = await buildOptionsIntelReport(parsed.data.ticker, parsed.data.expiration, parsed.data.levels);
    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'options_intel',
      status: 'ok',
      meta: {
        ticker: parsed.data.ticker,
        expiration: parsed.data.expiration,
        provider: report.provider,
        contracts: report.topOi.length,
      },
    });
    return NextResponse.json(report, {
      headers: {
        'Cache-Control': 'no-store',
        'X-RateLimit-Remaining': String(rate.remaining),
      },
    });
  } catch (err) {
    console.error('[/api/market/options]', err);
    return NextResponse.json({ error: 'Options intel unavailable.' }, { status: 503 });
  }
}

function nextFriday(): string {
  const d = new Date();
  const dow = d.getUTCDay();
  const add = (5 - dow + 7) % 7 || 7;
  d.setUTCDate(d.getUTCDate() + add);
  return d.toISOString().slice(0, 10);
}
