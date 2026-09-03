import { NextResponse } from 'next/server';
import { generateFeedSummary, isAutonomousEnabled } from '@/lib/autonomous-agent';
import { getGlobalAutonomousStats } from '@/lib/store';

export const runtime = 'nodejs';
export const maxDuration = 60;

function checkSecret(req: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return true;
  const header = req.headers.get('x-cron-secret') ?? req.headers.get('authorization')?.replace('Bearer ', '');
  return header === secret;
}

export async function GET(req: Request) { return handler(req); }
export async function POST(req: Request) { return handler(req); }

async function handler(req: Request) {
  if (!checkSecret(req)) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  if (!isAutonomousEnabled() && process.env.AGENT_FEED_SUMMARY_ENABLED !== 'true') {
    return NextResponse.json({ skipped: true, reason: 'feed_summary_disabled' });
  }

  const stats = await getGlobalAutonomousStats();
  const globalMax = Number(process.env.MAX_AUTONOMOUS_POSTS_PER_DAY ?? '30');
  if (stats.today_posts >= globalMax) {
    return NextResponse.json({ skipped: true, reason: 'global_daily_limit_reached', stats });
  }

  const result = await generateFeedSummary();

  return NextResponse.json({
    ok: result.ok,
    reason: result.ok ? undefined : result.reason,
    post_id: result.ok ? result.post.id : undefined,
    costUsd: result.costUsd,
  });
}
