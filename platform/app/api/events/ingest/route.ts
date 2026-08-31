import { NextRequest, NextResponse } from 'next/server';
import { ingestAll } from '@/lib/events/ingest';

export const runtime = 'nodejs';
export const maxDuration = 60;

export async function GET(req: NextRequest) {
  // Accept either EVENT_INGEST_SECRET or CRON_SECRET (for Vercel cron compatibility)
  const secret = req.headers.get('authorization')?.replace('Bearer ', '')
    ?? req.nextUrl.searchParams.get('secret')
    ?? '';
  const expected = process.env.EVENT_INGEST_SECRET ?? process.env.CRON_SECRET ?? '';
  if (expected && secret !== expected) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const perSource = await ingestAll();
    const summary = {
      fetched: perSource.reduce((s, r) => s + r.inserted + r.updated + r.skipped, 0),
      upserted: perSource.reduce((s, r) => s + r.inserted + r.updated, 0),
      skipped: perSource.reduce((s, r) => s + r.skipped, 0),
      errors: perSource.filter((r) => r.error !== null).length,
    };
    console.log('[events/ingest]', JSON.stringify(summary));
    return NextResponse.json({ ok: true, summary, perSource });
  } catch (err: unknown) {
    console.error('[events/ingest] fatal', err);
    return NextResponse.json({ ok: false, error: String(err) }, { status: 500 });
  }
}

// Also accept POST for manual triggers
export const POST = GET;
