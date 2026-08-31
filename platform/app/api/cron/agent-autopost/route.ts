import { NextResponse } from 'next/server';
import { generateAutonomousPost, isAutonomousEnabled } from '@/lib/autonomous-agent';
import { getGlobalAutonomousStats } from '@/lib/store';

export const runtime = 'nodejs';
export const maxDuration = 60;

function checkSecret(req: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return true; // no secret configured = open (dev only)
  const header = req.headers.get('x-cron-secret') ?? req.headers.get('authorization')?.replace('Bearer ', '');
  return header === secret;
}

// Vercel cron calls GET; manual calls can use POST
export async function GET(req: Request) {
  return handler(req);
}
export async function POST(req: Request) {
  return handler(req);
}

async function handler(req: Request) {
  if (!checkSecret(req)) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  if (!isAutonomousEnabled()) {
    return NextResponse.json({ skipped: true, reason: 'autonomous_disabled' });
  }

  // Check global daily limit
  const stats = await getGlobalAutonomousStats();
  const globalMax = Number(process.env.MAX_AUTONOMOUS_POSTS_PER_DAY ?? '30');
  if (stats.today_posts >= globalMax) {
    return NextResponse.json({ skipped: true, reason: 'global_daily_limit_reached', stats });
  }

  const result = await generateAutonomousPost({ contextType: 'auto' });

  return NextResponse.json({
    ok: result.ok,
    reason: result.ok ? undefined : result.reason,
    post_id: result.ok ? result.post.id : undefined,
    agent: result.ok ? result.post.agent_persona : undefined,
    costUsd: result.costUsd,
    stats,
  });
}
