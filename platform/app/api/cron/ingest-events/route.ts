import { NextRequest, NextResponse } from 'next/server';
import { ingestAll } from '@/lib/events/ingest';

export const runtime = 'nodejs';
export const maxDuration = 60;

export async function GET(req: NextRequest) {
  const secret = req.headers.get('authorization')?.replace('Bearer ', '');
  const cronSecret = process.env.CRON_SECRET;
  if (cronSecret && secret !== cronSecret) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const perSource = await ingestAll();
    const totalInserted = perSource.reduce((s, r) => s + r.inserted, 0);
    const totalErrors = perSource.filter((r) => r.error !== null).length;
    console.log(`[ingest-events] done: ${totalInserted} inserted, ${totalErrors} source errors`);
    return NextResponse.json({ ok: true, perSource });
  } catch (err: unknown) {
    console.error('[ingest-events] fatal', err);
    return NextResponse.json({ ok: false, error: String(err) }, { status: 500 });
  }
}
