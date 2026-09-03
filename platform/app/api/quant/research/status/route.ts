import { NextResponse } from 'next/server';
import { probeQuantResearchBackend } from '@/lib/quant/research-client';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  const status = await probeQuantResearchBackend();
  return NextResponse.json(status, {
    status: status.connected ? 200 : 503,
    headers: { 'Cache-Control': 'no-store' },
  });
}
