import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { compileMarketQuery } from '@/lib/quant/market-query';
import {
  createMarketMonitor,
  listMarketMonitors,
  MarketMonitorStorageError,
} from '@/lib/quant/market-monitors';
import { requirePaidResearchAccess } from '@/lib/research-access';
import { isSameOriginRequest } from '@/lib/same-origin';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const CreateBody = z
  .object({
    question: z.string().min(1).max(2000),
    watchlist: z.array(z.string().min(1).max(12)).max(30).optional(),
    cadence_minutes: z.union([
      z.literal(5),
      z.literal(15),
      z.literal(30),
      z.literal(60),
    ]).optional(),
  })
  .strict();

export async function GET() {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const { user } = access;
  try {
    const monitors = await listMarketMonitors(user.id);
    return NextResponse.json(
      { monitors },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (error) {
    return NextResponse.json(
      {
        error: 'monitor_storage_unavailable',
        detail:
          error instanceof MarketMonitorStorageError
            ? error.message
            : 'Monitor storage failed.',
        monitors: [],
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json({ error: 'cross_origin_rejected' }, { status: 403 });
  }
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const { user } = access;
  const body = await request.json().catch(() => null);
  const parsed = CreateBody.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'invalid_monitor', detail: parsed.error.flatten() },
      { status: 400, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const compiled = compileMarketQuery(
    parsed.data.question,
    parsed.data.watchlist ?? []
  );
  try {
    const monitor = await createMarketMonitor({
      user,
      question: parsed.data.question,
      query: compiled.query,
      cadenceMinutes: parsed.data.cadence_minutes,
    });
    return NextResponse.json(
      { monitor, compiler_notes: compiled.notes },
      { status: monitor.status === 'CREATED' ? 201 : 200 }
    );
  } catch (error) {
    return NextResponse.json(
      {
        error: 'monitor_storage_unavailable',
        detail: error instanceof Error ? error.message : String(error),
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}
