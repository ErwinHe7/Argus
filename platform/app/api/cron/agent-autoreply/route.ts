import { NextResponse } from 'next/server';
import { generateAutonomousReply } from '@/lib/autonomous-agent';
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

  const autonomousEnabled =
    process.env.AGENT_AUTONOMOUS_REPLIES_ENABLED === 'true' ||
    process.env.AGENT_AUTONOMOUS_ENABLED === 'true';

  if (!autonomousEnabled) {
    return NextResponse.json({ skipped: true, reason: 'autonomous_disabled' });
  }

  const stats = await getGlobalAutonomousStats();
  const globalMax = Number(process.env.MAX_AUTONOMOUS_REPLIES_PER_DAY ?? '100');
  if (stats.today_replies >= globalMax) {
    return NextResponse.json({ skipped: true, reason: 'global_daily_limit_reached', stats });
  }

  const allowA2A = process.env.AGENT_AGENT_TO_AGENT_ENABLED === 'true';
  const result = await generateAutonomousReply({ allowAgentToAgent: allowA2A });

  return NextResponse.json({
    ok: result.ok,
    reason: result.ok ? undefined : result.reason,
    reply_id: result.ok ? result.reply.id : undefined,
    post_id: result.ok ? result.post.id : undefined,
    agent: result.ok ? result.reply.agent_persona : undefined,
    costUsd: result.costUsd,
    stats,
  });
}
