import { NextRequest, NextResponse } from 'next/server';
import { MarketQuerySchema } from '@/lib/quant/market-query-schema';
import { requestQuantResearch } from '@/lib/quant/research-client';
import { isSameOriginRequest } from '@/lib/same-origin';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json(
      { error: 'Cross-origin research requests are not accepted.' },
      { status: 403, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const declaredLength = Number(request.headers.get('content-length') || 0);
  if (!Number.isFinite(declaredLength) || declaredLength > 32_768) {
    return NextResponse.json(
      { error: 'Research request body exceeds 32 KiB.' },
      { status: 413, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const body = await request.json().catch(() => null);
  const parsed = MarketQuerySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Invalid market query contract.', detail: parsed.error.flatten() },
      { status: 400, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  try {
    const envelope = await requestQuantResearch(parsed.data);
    return NextResponse.json(envelope, {
      headers: {
        'Cache-Control': 'no-store',
        'X-AXIO7-Model-Runtime': 'rust',
        'X-AXIO7-Evidence-Contract': envelope.schema_version,
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: 'Leo’s quant engine is unavailable.',
        detail: error instanceof Error ? error.message : String(error),
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}
