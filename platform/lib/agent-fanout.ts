import * as Sentry from '@sentry/nextjs';
import { AGENTS } from './agents';
import { chatWithUsage } from './llm';
import { cleanAgentReply, isNonAnswerReply } from './agent-output';
import { buildFanoutContext } from './agent-fanout-context';
import { acquireDedupeKey, dedupeKeyForReply } from './agent-graph-utils';
import { runGraphFanoutAdapter } from './agent-fanout-graph';
import { createReply, getPost, incrementLike, listListings } from './store';
import { startPostTrace, tracedLLMCall, flushTraces, type TraceContext } from './observability/llm-tracer';
import type { AgentPersona, Post } from './types';

const EVENT_KW     = ['party', 'event', 'concert', 'show', 'gallery', 'tonight', 'weekend', 'ticket', '活动'];
const FURNITURE_KW = ['furniture', 'desk', 'chair', 'couch', 'sofa', 'ikea', 'selling', 'sell', '家具'];

async function buildListingContext(content: string): Promise<string | null> {
  const lower = content.toLowerCase();
  const isEvent     = EVENT_KW.some((k) => lower.includes(k));
  const isFurniture = FURNITURE_KW.some((k) => lower.includes(k));
  if (!isEvent && !isFurniture) return null;

  const category = isFurniture ? 'furniture' : 'tickets';
  try {
    const all = await listListings({ category });
    const top5 = all.filter((l) => l.status === 'open').slice(0, 5);
    if (top5.length === 0) return null;
    const lines = top5.map((l) => {
      const price = l.asking_price_cents > 0 ? `$${(l.asking_price_cents / 100).toFixed(0)}` : 'price TBD';
      const loc = l.location ? ` · ${l.location}` : '';
      return `• "${l.title}" — ${price}${loc} (see /trade/${l.id})`;
    });
    return `[Live listings on AXIO7 Trade]\n${lines.join('\n')}`;
  } catch {
    return null;
  }
}

export type FanoutResult = {
  succeeded: number;
  failed: number;
  totalLatencyMs: number;
  totalCostUsd: number;
};

export async function fanOutAgentReplies(
  postId: string,
  mentionedAgentId?: string,
  agentIds?: string[]
): Promise<FanoutResult> {
  if (process.env.AGENT_GRAPH_FANOUT_ENABLED === 'true') {
    let publishStarted = false;
    try {
      return await runGraphFanoutAdapter(postId, {
        mentionedAgentId,
        agentIds,
        source: 'api',
        onPublishStarted: () => {
          publishStarted = true;
        },
      });
    } catch (error) {
      console.error('[fanout] graph_fanout_failed', { postId, publishStarted, error });
      if (!publishStarted) {
        console.warn('[fanout] graph_fanout_fallback_legacy', { postId });
        return await runLegacyFanout(postId, mentionedAgentId, agentIds);
      }
      return {
        succeeded: 0,
        failed: Math.max(1, agentIds?.length ?? AGENTS.length),
        totalLatencyMs: 0,
        totalCostUsd: 0,
      };
    }
  }

  return await runLegacyFanout(postId, mentionedAgentId, agentIds);
}

export async function runLegacyFanout(
  postId: string,
  mentionedAgentId?: string,
  agentIds?: string[]
): Promise<FanoutResult> {
  const post = await getPost(postId);
  if (!post) {
    console.error('[fanout] post not found', postId);
    return { succeeded: 0, failed: 0, totalLatencyMs: 0, totalCostUsd: 0 };
  }

  const traceCtx = startPostTrace(postId, post.author_id);

  let orderedAgents = agentIds && agentIds.length > 0
    ? AGENTS.filter((a) => agentIds.includes(a.id))
    : [...AGENTS];

  if (mentionedAgentId) {
    const idx = orderedAgents.findIndex((a) => a.id === mentionedAgentId);
    if (idx > 0) {
      const [mentioned] = orderedAgents.splice(idx, 1);
      orderedAgents.unshift(mentioned);
    }
    if (idx !== -1) {
      console.log(`[fanout] @mention detected — running ${mentionedAgentId} first`);
    }
  }

  const fanoutStart = Date.now();
  const results = await Promise.allSettled(
    orderedAgents.map((agent) => runOneAgent(agent, post, traceCtx))
  );

  let succeeded = 0;
  let failed = 0;
  let totalCostUsd = 0;
  results.forEach((r, i) => {
    const slug = orderedAgents[i].id;
    if (r.status === 'rejected') {
      failed++;
      console.error('[fanout]', slug, r.reason);
      return;
    }
    if (r.value.ok) {
      succeeded++;
      totalCostUsd += r.value.costUsd;
      return;
    }
    failed++;
    console.error('[fanout]', slug, r.value.error);
  });

  const totalLatencyMs = Date.now() - fanoutStart;
  console.log(`[fanout] post ${postId}: ${succeeded}/${orderedAgents.length} agents replied`);

  flushTraces().catch(() => {});

  return { succeeded, failed, totalLatencyMs, totalCostUsd };
}

type AgentRunResult = { ok: true; costUsd: number } | { ok: false; error: unknown };

async function recoverAgentReply(
  agent: AgentPersona,
  userContent: string
): Promise<{ content: string; costUsd: number }> {
  const result = await chatWithUsage(
    [
      {
        role: 'system',
        content: `${agent.system_prompt}

Important: never output "No response", "topic unrelated", or any refusal placeholder. If the post is vague or outside your specialty, still give a grounded practical take that fits the post.`,
      },
      { role: 'user', content: userContent },
    ],
    {
      model: agent.id === 'ember' ? 'openai/gpt-4o-mini' : agent.model,
      temperature: 0.7,
      max_tokens: 260,
    }
  );
  return { content: cleanAgentReply(result.content), costUsd: 0 };
}

async function runOneAgent(
  agent: AgentPersona,
  post: Post,
  traceCtx: TraceContext
): Promise<AgentRunResult> {
  try {
    const context = await buildFanoutContext(post.content);

    const contextParts = [
      post.content,
      context.tradeContext ?? '',
      context.eventContext ?? '',
    ].filter(Boolean);
    const userContent = contextParts.join('\n\n');

    const result = await tracedLLMCall(
      agent,
      post.content,
      () =>
        chatWithUsage(
          [
            { role: 'system', content: agent.system_prompt },
            { role: 'user', content: userContent },
          ],
          {
            model: agent.model,
            temperature: 0.8,
            max_tokens: agent.model?.includes('nemotron') || agent.model?.includes('kimi') ? 800 : 220,
          }
        ),
      traceCtx
    );

    let trimmed = cleanAgentReply(result.content);
    let costUsd = result.costUsd;
    if (!trimmed || isNonAnswerReply(trimmed)) {
      const recovered = await recoverAgentReply(agent, userContent);
      trimmed = recovered.content;
      costUsd += recovered.costUsd;
    }

    if (!trimmed || isNonAnswerReply(trimmed)) {
      return { ok: false, error: 'empty completion' };
    }

    const dedupeKey = dedupeKeyForReply(post.id, agent.id, 'fanout');
    const acquired = await acquireDedupeKey(dedupeKey);
    if (!acquired) {
      console.log('[fanout] duplicate prevented', { postId: post.id, agentId: agent.id, dedupeKey });
      return { ok: false, error: 'duplicate prevented' };
    }

    await Promise.all([
      createReply({
        post_id: post.id,
        author_kind: 'agent',
        author_name: agent.name,
        author_avatar: agent.avatar,
        agent_persona: agent.id,
        content: trimmed,
        confidence_score: 0.8,
        visibility: 'public',
      }),
      incrementLike(post.id, `agent-${agent.id}`).catch((err) => {
        console.warn('[fanout] like failed', agent.id, err);
      }),
    ]);

    return { ok: true, costUsd };
  } catch (err) {
    Sentry.captureException(err, {
      extra: {
        agent_name: agent.name,
        agent_id: agent.id,
        model: agent.model,
        post_id: post.id,
        author_id: post.author_id,
        prompt_preview: post.content.slice(0, 200),
      },
    });
    return { ok: false, error: err };
  }
}
