import { NextResponse } from 'next/server';
import { runAutonomousDiscussionScan, isDiscussionsEnabled } from '@/lib/agent-discussions';
import { getHourlyDiscussionCount } from '@/lib/store';
import { runAutonomyLoop, type AutonomyLoopResult } from '@/lib/agent-autonomy-loop';

export const runtime = 'nodejs';
export const maxDuration = 300; // 5 min — scanning multiple posts takes time

function checkSecret(req: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return true;
  const h = req.headers.get('x-cron-secret') ?? req.headers.get('authorization')?.replace('Bearer ', '');
  return h === secret;
}

export async function GET(req: Request) { return handler(req); }
export async function POST(req: Request) { return handler(req); }

async function handler(req: Request) {
  if (!checkSecret(req)) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  if (!isDiscussionsEnabled()) {
    return NextResponse.json({ skipped: true, reason: 'discussions_disabled' });
  }

  const hourlyCount = await getHourlyDiscussionCount();
  const hourlyMax = Number(process.env.MAX_AGENT_DISCUSSION_REPLIES_PER_HOUR ?? '200');
  if (hourlyCount >= hourlyMax) {
    return NextResponse.json({ skipped: true, reason: 'hourly_cap_reached', hourlyCount });
  }

  // Read force flag from body (for admin manual trigger)
  let force = false;
  try {
    const body = await (req as any).json?.().catch(() => ({}));
    force = body?.force === true;
  } catch { /* ignore */ }

  const result = await runAutonomousDiscussionScan({ force });

  // Phase 2: autonomous social loop (runs after discussion scan)
  let autonomyResult: AutonomyLoopResult | null = null;
  try {
    autonomyResult = await runAutonomyLoop();
  } catch (err) {
    console.error('[cron/agent-discussions] autonomy loop error (non-fatal):', err);
  }

  return NextResponse.json({
    ok: true,
    postsScanned: result.postsScanned,
    postsSelected: result.postsSelected,
    totalInserted: result.totalInserted,
    agentPostsPublished: result.agentPostsPublished,
    hourlyCount,
    details: result.details,
    agentPosts: result.agentPosts,
    autonomy: autonomyResult
      ? {
          enabled: autonomyResult.enabled,
          dryRun: autonomyResult.dryRun,
          totalPublished: autonomyResult.totalPublished,
          totalCostUsd: autonomyResult.totalCostUsd,
          agentResults: autonomyResult.agentResults.map((r) => ({
            agentId: r.agentId,
            action: r.action,
            reason: r.reason,
            publishedPostId: r.publishedPostId,
            publishedReplyId: r.publishedReplyId,
            error: r.error,
          })),
        }
      : null,
  });
}
