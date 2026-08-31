import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { runMarketResearch } from '@/lib/market-intelligence/engine';
import { getBrokerAdapter, planOrderFromSignal } from '@/lib/market-intelligence/broker';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const BodySchema = z.object({
  query: z.string().min(1).max(600),
  watchlist: z.array(z.string().min(1).max(12)).max(30).default([]),
  horizon: z.enum(['intraday', 'swing', 'long_term']).default('intraday'),
  acknowledgePaper: z.literal(true),
});

const ROUTE = '/api/strategy/execute';

export async function POST(req: NextRequest) {
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(
    key,
    Number(process.env.STRATEGY_EXECUTE_RATE_LIMIT || 12),
    Number(process.env.STRATEGY_EXECUTE_RATE_WINDOW_MS || 60_000)
  );
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit exceeded.' },
      { status: 429, headers: { 'Retry-After': String(rate.resetSeconds) } }
    );
  }

  const body = await req.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Invalid execute request. acknowledgePaper must be true.' },
      { status: 400 }
    );
  }

  const report = await runMarketResearch({
    query: parsed.data.query,
    watchlist: parsed.data.watchlist,
    horizon: parsed.data.horizon,
    mode: 'paper',
  });

  if (!report.compliance.allowed) {
    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'compliance_blocked',
      status: 'blocked',
      meta: { reasons: report.compliance.reasons },
    });
    return NextResponse.json({ ok: false, report, executed: [] }, { status: 200 });
  }

  const broker = getBrokerAdapter();
  if (broker.mode !== 'paper') {
    await recordAudit({
      route: ROUTE,
      actor: key,
      action: 'live_broker_blocked',
      status: 'blocked',
      meta: { broker: broker.name },
    });
    return NextResponse.json(
      {
        ok: false,
        error: 'Live broker execution is not allowed in this build. Paper mode only.',
        report,
        executed: [],
      },
      { status: 403 }
    );
  }

  const executed: Array<{ signalId: string; ticker: string; result: unknown }> = [];

  for (const signal of report.signals) {
    if (signal.action !== 'PAPER_LONG' && signal.action !== 'PAPER_SHORT') continue;
    const account = await broker.getAccount();
    const order = planOrderFromSignal(signal, account);
    if (!order) continue;
    const result = await broker.submitOrder(order);
    executed.push({ signalId: signal.id, ticker: signal.ticker, result });
  }

  const account = await broker.getAccount();
  const positions = await broker.getPositions();

  await recordAudit({
    route: ROUTE,
    actor: key,
    action: 'paper_execute',
    status: 'ok',
    meta: {
      signals: report.signals.length,
      executed: executed.length,
      cash: account.cash,
      equity: account.equity,
    },
  });

  return NextResponse.json(
    {
      ok: true,
      report,
      executed,
      account,
      positions,
      disclaimer:
        'Paper trading only. No real funds, no broker connection, no order routing. Synthetic fill prices.',
    },
    {
      headers: {
        'Cache-Control': 'no-store',
        'X-RateLimit-Remaining': String(rate.remaining),
      },
    }
  );
}
