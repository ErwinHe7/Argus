import { NextResponse } from 'next/server';
import { z } from 'zod';
import { fanOutAgentReplies } from '@/lib/agent-fanout';
import { getPost } from '@/lib/store';
import { classifyQuery } from '@/lib/query-router';
import { getCurrentUser } from '@/lib/auth';
import { trackServerEvent } from '@/lib/observability/posthog-server';
import { runAgentDiscussion, isDiscussionsEnabled } from '@/lib/agent-discussions';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const Input = z.object({
  post_id: z.string().uuid(),
  mention: z.string().optional(),
  // Optional explicit agent override — bypasses the query router entirely.
  // Used by listing Ask AI to run only trade-relevant personas.
  agent_ids: z.array(z.string()).optional(),
});

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid input' }, { status: 400 });

  const { post_id, mention, agent_ids: explicitAgentIds } = parsed.data;

  // If caller provided explicit agent_ids, skip the query router entirely
  if (explicitAgentIds && explicitAgentIds.length > 0) {
    const [user, result] = await Promise.all([
      getCurrentUser().catch(() => null),
      fanOutAgentReplies(post_id, mention, explicitAgentIds).catch((err) => {
        console.error('[fanout]', err);
        return { succeeded: 0, failed: explicitAgentIds.length, totalLatencyMs: 0, totalCostUsd: 0 };
      }),
    ]);
    try {
      trackServerEvent(user?.id ?? 'anonymous', {
        event: 'agents_responded',
        properties: {
          post_id,
          user_id: user?.id ?? 'anonymous',
          routing_mode: 'panel',
          agents_succeeded: result.succeeded,
          agents_failed: result.failed,
          total_latency_ms: result.totalLatencyMs,
          total_cost_usd: result.totalCostUsd,
        },
      });
    } catch { /* non-blocking */ }
    return NextResponse.json({ ...result, routing_mode: 'explicit' });
  }

  // Run router + user lookup in parallel — router needs post content
  const [user, post] = await Promise.all([
    getCurrentUser().catch(() => null),
    getPost(post_id).catch(() => null),
  ]);

  // Classify query intent (fails safe to panel)
  const decision = post
    ? await classifyQuery(post.content).catch(() => ({ mode: 'panel' as const, reasoning: 'fallback' }))
    : { mode: 'panel' as const, reasoning: 'no post' };

  const agentIds =
    decision.mode === 'single' && 'single_agent_id' in decision && decision.single_agent_id
      ? [decision.single_agent_id]
      : undefined;

  console.log(`[fanout] post=${post_id} mode=${decision.mode} agents=${agentIds ?? 'all'}`);

  const result = await fanOutAgentReplies(post_id, mention, agentIds).catch((err) => {
    console.error('[fanout]', err);
    return { succeeded: 0, failed: agentIds ? agentIds.length : 7, totalLatencyMs: 0, totalCostUsd: 0 };
  });

  try {
    trackServerEvent(user?.id ?? 'anonymous', {
      event: 'agents_responded',
      properties: {
        post_id,
        user_id: user?.id ?? 'anonymous',
        routing_mode: decision.mode,
        agents_succeeded: result.succeeded,
        agents_failed: result.failed,
        total_latency_ms: result.totalLatencyMs,
        total_cost_usd: result.totalCostUsd,
      },
    });
  } catch {
    // non-blocking
  }

  // Fire-and-forget discussion round 1 after initial fanout
  // Only for panel-mode (multi-agent) posts, not single-agent utility replies
  if (isDiscussionsEnabled() && decision.mode === 'panel' && result.succeeded > 0) {
    // Delay 90s so initial replies are visible before discussion starts
    setTimeout(() => {
      runAgentDiscussion(post_id, {}).catch((err) => {
        console.warn('[discussion] auto-trigger failed', err?.message);
      });
    }, 90_000);
  }

  return NextResponse.json({ ...result, routing_mode: decision.mode });
}
