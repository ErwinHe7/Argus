import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import {
  MarketMonitorStorageError,
  setMarketMonitorStatus,
} from '@/lib/quant/market-monitors';
import { requirePaidResearchAccess } from '@/lib/research-access';
import { isSameOriginRequest } from '@/lib/same-origin';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const Body = z
  .object({
    status: z.enum(['active', 'paused']),
  })
  .strict();

export async function PATCH(
  request: NextRequest,
  context: { params: { id: string } }
) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json({ error: 'cross_origin_rejected' }, { status: 403 });
  }
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const { user } = access;
  const monitorId = z.string().uuid().safeParse(context.params.id);
  const body = Body.safeParse(await request.json().catch(() => null));
  if (!monitorId.success || !body.success) {
    return NextResponse.json({ error: 'invalid_monitor_update' }, { status: 400 });
  }
  try {
    const monitor = await setMarketMonitorStatus({
      userId: user.id,
      monitorId: monitorId.data,
      status: body.data.status,
    });
    if (!monitor) {
      return NextResponse.json({ error: 'monitor_not_found' }, { status: 404 });
    }
    return NextResponse.json(
      { monitor },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (error) {
    return NextResponse.json(
      {
        error: 'monitor_storage_unavailable',
        detail:
          error instanceof MarketMonitorStorageError
            ? error.message
            : 'Monitor update failed.',
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}
