import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth';
import { resolveBrokerAdapter } from '@/lib/market-intelligence/broker';
import { loadBrokerKey } from '@/lib/market-intelligence/broker-keys';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const ROUTE = '/api/strategy/confirm-execute';

const BodySchema = z.object({
  broker: z.enum(['alpaca', 'ibkr']),
  env: z.enum(['paper', 'live']),
  ticker: z.string().min(1).max(12),
  side: z.enum(['BUY', 'SELL']),
  qty: z.number().int().positive().max(100_000),
  orderType: z.enum(['MARKET', 'LIMIT']).default('MARKET'),
  limitPrice: z.number().positive().optional(),
  signalId: z.string().min(1).max(96),
  userConfirmedThesis: z.string().min(1).max(600),
  acknowledgeNotAdvice: z.literal(true),
});

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'Sign in required.' }, { status: 401 });

  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 30, 60_000);
  if (!rate.allowed) return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });

  const body = await req.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid confirm-execute body.' }, { status: 400 });
  }

  if (parsed.data.env === 'live' && process.env.LIVE_EXECUTION_ENABLED !== 'true') {
    await recordAudit({
      route: ROUTE,
      actor: user.id,
      action: 'live_blocked_env',
      status: 'blocked',
      meta: { broker: parsed.data.broker },
    });
    return NextResponse.json(
      {
        ok: false,
        error: 'Live execution is disabled in this deployment.',
        hint: 'Set LIVE_EXECUTION_ENABLED=true after RIA/non-RIA compliance review.',
      },
      { status: 403 }
    );
  }

  const stored = await loadBrokerKey(user.id, parsed.data.broker, parsed.data.env);
  if (!stored) {
    return NextResponse.json(
      { ok: false, error: `No ${parsed.data.broker} ${parsed.data.env} key on file for this account.` },
      { status: 404 }
    );
  }

  const adapter = await resolveBrokerAdapter(
    stored.kind === 'alpaca'
      ? {
          kind: 'alpaca',
          env: parsed.data.env,
          alpaca: { apiKey: stored.apiKey, apiSecret: stored.apiSecret },
        }
      : {
          kind: 'ibkr',
          env: parsed.data.env,
          ibkr: {
            baseUrl: stored.baseUrl,
            accountId: stored.accountId,
            sessionToken: stored.sessionToken,
          },
        }
  );

  if (adapter.mode === 'disabled') {
    await recordAudit({
      route: ROUTE,
      actor: user.id,
      action: 'adapter_disabled',
      status: 'blocked',
    });
    return NextResponse.json(
      { ok: false, error: 'Live adapter disabled by deployment.' },
      { status: 403 }
    );
  }

  const result = await adapter.submitOrder({
    signalId: parsed.data.signalId,
    ticker: parsed.data.ticker,
    side: parsed.data.side,
    qty: parsed.data.qty,
    type: parsed.data.orderType,
    timeInForce: 'DAY',
    limitPrice: parsed.data.limitPrice,
    notes: `User-confirmed non-discretionary order. Thesis: ${parsed.data.userConfirmedThesis.slice(0, 200)}`,
  });

  await recordAudit({
    route: ROUTE,
    actor: user.id,
    action: result.ok ? 'order_submitted' : 'order_rejected',
    status: result.ok ? 'ok' : 'error',
    meta: {
      broker: parsed.data.broker,
      env: parsed.data.env,
      ticker: parsed.data.ticker,
      side: parsed.data.side,
      qty: parsed.data.qty,
      signalId: parsed.data.signalId,
      orderId: result.orderId,
      rejectedReason: result.rejectedReason,
    },
  });

  return NextResponse.json(
    {
      ok: result.ok,
      result,
      disclaimer:
        'AXIO7 routed a user-confirmed, non-discretionary order to the user-owned broker account. AXIO7 does not custody funds, does not pool orders, and does not provide personalized investment advice.',
    },
    { status: result.ok ? 200 : 400, headers: { 'Cache-Control': 'no-store' } }
  );
}
