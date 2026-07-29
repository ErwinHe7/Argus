import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth';
import {
  deleteBrokerKey,
  listBrokerKeyStubs,
  saveBrokerKey,
  type BrokerKeyKind,
  type BrokerEnv,
} from '@/lib/market-intelligence/broker-keys';
import { recordAudit } from '@/lib/market-intelligence/audit';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const ROUTE = '/api/strategy/broker-keys';

const SaveBodySchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('alpaca'),
    env: z.enum(['paper', 'live']),
    apiKey: z.string().min(8).max(128),
    apiSecret: z.string().min(8).max(256),
  }),
  z.object({
    kind: z.literal('ibkr'),
    env: z.enum(['paper', 'live']),
    baseUrl: z.string().url().max(256),
    accountId: z.string().min(2).max(64),
    sessionToken: z.string().max(512).optional(),
  }),
]);

const DeleteBodySchema = z.object({
  kind: z.enum(['alpaca', 'ibkr']),
  env: z.enum(['paper', 'live']),
});

export async function GET() {
  const user = await getCurrentUser();
  if (!user.authenticated) {
    return NextResponse.json({ error: 'Sign in required.' }, { status: 401 });
  }
  const keys = await listBrokerKeyStubs(user.id);
  return NextResponse.json({ keys }, { headers: { 'Cache-Control': 'no-store' } });
}

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'Sign in required.' }, { status: 401 });

  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 10, 60_000);
  if (!rate.allowed) return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });

  const body = await req.json().catch(() => null);
  const parsed = SaveBodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid broker key body.' }, { status: 400 });
  }

  if (parsed.data.env === 'live' && process.env.LIVE_EXECUTION_ENABLED !== 'true') {
    await recordAudit({
      route: ROUTE,
      actor: user.id,
      action: 'live_save_blocked',
      status: 'blocked',
      meta: { kind: parsed.data.kind },
    });
    return NextResponse.json(
      { error: 'Live trading is not enabled in this deployment. Only paper keys may be saved.' },
      { status: 403 }
    );
  }

  try {
    const env = parsed.data.env as BrokerEnv;
    let kind: BrokerKeyKind;
    if (parsed.data.kind === 'alpaca') {
      kind = 'alpaca';
      await saveBrokerKey(user.id, kind, env, {
        kind: 'alpaca',
        apiKey: parsed.data.apiKey,
        apiSecret: parsed.data.apiSecret,
      });
    } else {
      kind = 'ibkr';
      await saveBrokerKey(user.id, kind, env, {
        kind: 'ibkr',
        baseUrl: parsed.data.baseUrl,
        accountId: parsed.data.accountId,
        sessionToken: parsed.data.sessionToken,
      });
    }
    await recordAudit({ route: ROUTE, actor: user.id, action: 'save', status: 'ok', meta: { kind, env } });
    return NextResponse.json({ ok: true, kind, env });
  } catch (err) {
    await recordAudit({
      route: ROUTE,
      actor: user.id,
      action: 'save_error',
      status: 'error',
      meta: { message: err instanceof Error ? err.message : 'unknown' },
    });
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Save failed.' },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'Sign in required.' }, { status: 401 });

  const body = await req.json().catch(() => null);
  const parsed = DeleteBodySchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: 'Invalid delete body.' }, { status: 400 });

  await deleteBrokerKey(user.id, parsed.data.kind, parsed.data.env);
  await recordAudit({
    route: ROUTE,
    actor: user.id,
    action: 'delete',
    status: 'ok',
    meta: parsed.data,
  });
  return NextResponse.json({ ok: true });
}
