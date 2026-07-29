import { NextResponse } from 'next/server';
import { probeQuantResearchBackend } from '@/lib/quant/research-client';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const status = await probeQuantResearchBackend();
  return NextResponse.json(status, {
    status: status.connected ? 200 : 503,
    headers: { 'Cache-Control': 'no-store' },
  });
}
