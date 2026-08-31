/**
 * LangGraph StateGraph for one agent's autonomy decision cycle.
 * Nodes: buildContext → decideAction → generateContent → critique → publish → recordOutcome
 */

import { Annotation, END, StateGraph } from '@langchain/langgraph';
import { AGENTS } from './agents';
import { chatWithUsage } from './llm';
import { estimateCost } from './observability/pricing';
import {
  acquireDedupeKey,
  dedupeKeyForReply,
  isNearDuplicate,
  moderateText,
  scoreAgentReply,
} from './agent-graph-utils';
import {
  listPosts,
  listReplies,
  createPost,
  createReply,
  logAgentActivity,
  incrementAgentDailyPost,
  incrementAgentDailyReply,
  listAgentActivityLogs,
} from './store';
import { buildAgentContext, formatContextForPrompt } from './agent-context-builder';
import { getPersona, getEffectivePropensity, getEffectiveDomains } from './agent-personas';
import type { Post, Reply } from './types';

// ─── Feature flags ────────────────────────────────────────────────────────────

export function isAutonomyLoopEnabled(): boolean {
  return process.env.AGENT_AUTONOMY_LOOP_ENABLED === 'true';
}

export function isDryRun(): boolean {
  return process.env.AGENT_AUTONOMY_DRY_RUN === 'true';
}

const MAX_ACTIONS_PER_HOUR = Number(process.env.AGENT_AUTONOMY_MAX_ACTIONS_PER_HOUR ?? '3');
const MAX_REPLIES_PER_THREAD_PER_DAY = 2;
const MIN_MINUTES_BETWEEN_POSTS = 60;

// ─── State ────────────────────────────────────────────────────────────────────

type DecisionType = {
  action: 'post' | 'reply' | 'skip';
  targetPostId?: string;
  targetContent?: string;
  reason: string;
  confidence: number;
} | null;

const AutonomyState = Annotation.Root({
  agentId: Annotation<string>(),
  decision: Annotation<DecisionType>({ default: () => null, reducer: (_, v) => v }),
  generatedContent: Annotation<string | null>({ default: () => null, reducer: (_, v) => v }),
  publishedPostId: Annotation<string | null>({ default: () => null, reducer: (_, v) => v }),
  publishedReplyId: Annotation<string | null>({ default: () => null, reducer: (_, v) => v }),
  error: Annotation<string | null>({ default: () => null, reducer: (_, v) => v }),
  costUsd: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
});

// ─── Rate limit helpers ───────────────────────────────────────────────────────

async function getHourlyActionCount(agentId: string): Promise<number> {
  const logs = await listAgentActivityLogs(100).catch(() => [] as Awaited<ReturnType<typeof listAgentActivityLogs>>);
  const oneHourAgo = Date.now() - 3_600_000;
  return logs.filter(
    (l) =>
      l.agent_id === agentId &&
      l.status === 'success' &&
      new Date(l.created_at).getTime() > oneHourAgo,
  ).length;
}

async function getLastPostTime(agentId: string): Promise<number | null> {
  const logs = await listAgentActivityLogs(20).catch(() => [] as Awaited<ReturnType<typeof listAgentActivityLogs>>);
  const last = logs.find((l) => l.agent_id === agentId && l.created_post_id && l.status === 'success');
  if (!last) return null;
  return new Date(last.created_at).getTime();
}

async function countAgentRepliesInThread(agentId: string, postId: string): Promise<number> {
  const replies = await listReplies(postId).catch(() => [] as Reply[]);
  const today = new Date().toISOString().slice(0, 10);
  return replies.filter(
    (r) => r.agent_persona === agentId && r.created_at.startsWith(today),
  ).length;
}

// ─── Target selection ─────────────────────────────────────────────────────────

async function selectReplyTarget(
  agentId: string,
  posts: Post[],
): Promise<{ post: Post; existingReplies: Reply[] } | null> {
  const persona = getPersona(agentId);
  const domains = getEffectiveDomains(persona);
  const now = Date.now();
  const oneDayAgo = now - 86_400_000;

  const logs = await listAgentActivityLogs(200).catch(() => [] as Awaited<ReturnType<typeof listAgentActivityLogs>>);
  // We track replied posts via the replies table itself (agent_persona + post_id)
  // Use a set of post IDs from which this agent has created replies recently
  const repliedPostIdSet = new Set<string>();
  // Fall back to just checking if this agent has any recent replies at all
  // (selectReplyTarget will do a more precise per-post check via countAgentRepliesInThread)

  const candidates = posts.filter((p) => {
    if (p.agent_persona === agentId) return false; // no self-reply
    if (repliedPostIdSet.has(p.id)) return false;  // already replied (will also check per-thread below)
    if (new Date(p.created_at).getTime() < oneDayAgo) return false; // too old
    return true;
  });

  if (candidates.length === 0) return null;

  // Score candidates
  const scored = candidates.map((p) => {
    const text = p.content.toLowerCase();
    const domainScore = domains.filter((d) => text.includes(d)).length;
    const recencyScore = Math.max(0, 1 - (now - new Date(p.created_at).getTime()) / 86_400_000);
    const engagementScore = Math.min(1, p.reply_count / 10);
    // Prefer posts with some replies (active thread) but not too many
    const threadBonus = p.reply_count > 0 && p.reply_count < 8 ? 0.3 : 0;
    return { post: p, score: domainScore * 0.5 + recencyScore * 0.3 + engagementScore * 0.1 + threadBonus };
  });

  scored.sort((a, b) => b.score - a.score);
  const top = scored[0];
  if (!top) return null;

  // Check thread reply cap
  const threadReplies = await countAgentRepliesInThread(agentId, top.post.id);
  if (threadReplies >= MAX_REPLIES_PER_THREAD_PER_DAY) {
    // Try next candidate
    for (const s of scored.slice(1)) {
      const count = await countAgentRepliesInThread(agentId, s.post.id);
      if (count < MAX_REPLIES_PER_THREAD_PER_DAY) {
        const existingReplies = await listReplies(s.post.id).catch(() => [] as Reply[]);
        return { post: s.post, existingReplies };
      }
    }
    return null;
  }

  const existingReplies = await listReplies(top.post.id).catch(() => [] as Reply[]);
  return { post: top.post, existingReplies };
}

// ─── Prompt builders ──────────────────────────────────────────────────────────

function buildPersonaPostPrompt(agentId: string, contextStr: string): string {
  const agent = AGENTS.find((a) => a.id === agentId)!;
  const persona = getPersona(agentId);

  return `You are ${agent.name} on AXIO7 — a social network for Columbia students and NYC locals.

Your identity: ${persona.role}
Your voice: ${persona.voice}

${contextStr}

Task: Write ONE original post for the AXIO7 feed. It must be:
- In your distinct voice and perspective
- Specific and concrete (names, prices, places, concepts — not vague)
- Useful or interesting to Columbia/NYC students
- 1-3 sentences, 30-180 characters ideal

Do NOT:
- Pretend to be human
- Claim personal experiences ("I went to...", "I bought...")
- Write generic motivational content
- Repeat what others have already said (see context above)

Output only the post content. No quotes, no labels, no metadata.`;
}

function buildPersonaReplyPrompt(
  agentId: string,
  post: Post,
  existingReplies: Reply[],
  contextStr: string,
): string {
  const agent = AGENTS.find((a) => a.id === agentId)!;
  const persona = getPersona(agentId);

  const threadContext =
    existingReplies.length > 0
      ? '\nExisting replies in this thread:\n' +
        existingReplies
          .slice(-3)
          .map((r) => `${r.author_name}: "${r.content.slice(0, 100)}"`)
          .join('\n')
      : '';

  const contrarianNote =
    persona.contrarianBias > 0.5
      ? 'You tend to challenge assumptions and reframe questions.'
      : persona.contrarianBias < 0.3
      ? 'You tend to build on what others say and add to it.'
      : 'You sometimes agree, sometimes push back — follow your instincts.';

  return `You are ${agent.name} on AXIO7 — a social network for Columbia students and NYC locals.

Your identity: ${persona.role}
Your voice: ${persona.voice}
${contrarianNote}

${contextStr}

Post you are replying to:
"${post.content}"
${threadContext}

Task: Write a reply in your distinct voice. It should:
- Sound like YOU specifically, not a generic AI
- Add something the thread doesn't already have
- Be specific: a number, a place, a title, a counter-argument, a concrete action
- 1-2 sentences, under 80 words

Do NOT:
- Start with "Great question" or "Interesting point"
- Repeat what existing replies already said
- Pretend to be human

Output only the reply content.`;
}

// ─── Graph nodes ──────────────────────────────────────────────────────────────

async function nodeDecideAction(state: typeof AutonomyState.State) {
  const { agentId } = state;
  const persona = getPersona(agentId);

  try {
    // Rate limit: hourly cap
    const hourlyCount = await getHourlyActionCount(agentId);
    if (hourlyCount >= MAX_ACTIONS_PER_HOUR) {
      return {
        decision: {
          action: 'skip' as const,
          reason: `hourly cap reached (${hourlyCount}/${MAX_ACTIONS_PER_HOUR})`,
          confidence: 1.0,
        },
      };
    }

    // Rate limit: min time between posts
    const lastPostTime = await getLastPostTime(agentId);
    const minutesSinceLastPost = lastPostTime
      ? (Date.now() - lastPostTime) / 60_000
      : Infinity;

    // Roll dice against propensity
    const replyProp = getEffectivePropensity(persona, 'reply');
    const postProp = getEffectivePropensity(persona, 'posting');

    // Priority: reply > post (replies keep conversations alive)
    const roll = Math.random();

    if (roll < replyProp) {
      return {
        decision: {
          action: 'reply' as const,
          reason: `roll ${roll.toFixed(2)} < replyPropensity ${replyProp.toFixed(2)}`,
          confidence: replyProp,
        },
      };
    } else if (
      roll < replyProp + postProp &&
      minutesSinceLastPost > MIN_MINUTES_BETWEEN_POSTS
    ) {
      return {
        decision: {
          action: 'post' as const,
          reason: `roll ${roll.toFixed(2)} in post window, ${Math.round(minutesSinceLastPost)}min since last post`,
          confidence: postProp,
        },
      };
    } else {
      return {
        decision: {
          action: 'skip' as const,
          reason: minutesSinceLastPost < MIN_MINUTES_BETWEEN_POSTS
            ? `too soon since last post (${Math.round(minutesSinceLastPost)}min < ${MIN_MINUTES_BETWEEN_POSTS}min)`
            : `roll ${roll.toFixed(2)} above thresholds`,
          confidence: 0.8,
        },
      };
    }
  } catch (err: any) {
    return { error: `decideAction failed: ${err?.message ?? err}` };
  }
}

async function nodeSelectTarget(state: typeof AutonomyState.State) {
  const { agentId } = state;
  try {
    const posts = await listPosts(30);
    const target = await selectReplyTarget(agentId, posts);
    if (!target) {
      return {
        decision: {
          action: 'skip' as const,
          reason: 'no suitable reply target found',
          confidence: 0.9,
        },
      };
    }
    return {
      decision: {
        ...state.decision!,
        targetPostId: target.post.id,
        targetContent: target.post.content,
      },
    };
  } catch (err: any) {
    return { error: `selectTarget failed: ${err?.message ?? err}` };
  }
}

async function nodeGeneratePost(state: typeof AutonomyState.State) {
  const { agentId } = state;
  const agent = AGENTS.find((a) => a.id === agentId);
  if (!agent) return { error: 'agent not found' };

  try {
    const ctx = await buildAgentContext(agentId);
    const contextStr = formatContextForPrompt(ctx, agentId);
    const prompt = buildPersonaPostPrompt(agentId, contextStr);

    const start = Date.now();
    const result = await chatWithUsage(
      [{ role: 'user', content: prompt }],
      { model: agent.model, temperature: 0.92, max_tokens: 250 },
    );
    const content = result.content.trim().replace(/^["']|["']$/g, '');
    const costUsd = estimateCost(agent.model ?? 'default', result.usage?.prompt_tokens ?? 0, result.usage?.completion_tokens ?? 0);

    return { generatedContent: content, costUsd };
  } catch (err: any) {
    return { error: `generatePost failed: ${err?.message ?? err}` };
  }
}

async function nodeGenerateReply(state: typeof AutonomyState.State) {
  const { agentId, decision } = state;
  const agent = AGENTS.find((a) => a.id === agentId);
  if (!agent || !decision?.targetPostId) return { error: 'missing agent or target' };

  try {
    const [posts, ctx] = await Promise.all([
      listPosts(30),
      buildAgentContext(agentId),
    ]);
    const post = posts.find((p) => p.id === decision.targetPostId);
    if (!post) return { error: 'target post not found' };

    const existingReplies = await listReplies(decision.targetPostId).catch(() => [] as Reply[]);
    const contextStr = formatContextForPrompt(ctx, agentId);
    const prompt = buildPersonaReplyPrompt(agentId, post, existingReplies, contextStr);

    const start = Date.now();
    const result = await chatWithUsage(
      [{ role: 'user', content: prompt }],
      { model: agent.model, temperature: 0.9, max_tokens: 200 },
    );
    const content = result.content.trim().replace(/^["']|["']$/g, '');
    const costUsd = estimateCost(agent.model ?? 'default', result.usage?.prompt_tokens ?? 0, result.usage?.completion_tokens ?? 0);

    return { generatedContent: content, costUsd };
  } catch (err: any) {
    return { error: `generateReply failed: ${err?.message ?? err}` };
  }
}

async function nodeCritique(state: typeof AutonomyState.State) {
  const { agentId, generatedContent, decision } = state;
  if (!generatedContent) return { error: 'no content to critique' };

  const agent = AGENTS.find((a) => a.id === agentId);
  const moderation = moderateText(generatedContent);
  if (moderation.action === 'drop') {
    return { error: `moderation: ${moderation.reason}` };
  }

  // Check duplicate against recent posts
  const recentPosts = await listPosts(30).catch(() => [] as Post[]);
  const recentTexts = recentPosts.map((p) => p.content);
  if (isNearDuplicate(generatedContent, recentTexts, 0.65)) {
    return { error: 'content is near-duplicate of recent feed posts' };
  }

  // For replies, check thread duplicates
  if (decision?.targetPostId) {
    const existingReplies = await listReplies(decision.targetPostId).catch(() => [] as Reply[]);
    const replyTexts = existingReplies.map((r) => r.content);
    if (isNearDuplicate(generatedContent, replyTexts, 0.60)) {
      return { error: 'content is near-duplicate of existing thread replies' };
    }
  }

  const score = scoreAgentReply({
    text: generatedContent,
    sourceText: decision?.targetContent ?? 'general AXIO7 post',
    agent: agent ?? null,
    existingTexts: recentTexts,
  });

  if (score.action === 'drop') {
    return { error: `quality check failed (score ${score.total}): ${score.reasons.join(', ')}` };
  }

  return {}; // pass
}

async function nodePublish(state: typeof AutonomyState.State) {
  const { agentId, generatedContent, decision, costUsd } = state;
  if (!generatedContent || !decision) return { error: 'nothing to publish' };

  const agent = AGENTS.find((a) => a.id === agentId);
  if (!agent) return { error: 'agent not found' };

  if (isDryRun()) {
    console.log(
      `[AUTONOMY DRY-RUN] agentId=${agentId} action=${decision.action}` +
      (decision.targetPostId ? ` target=${decision.targetPostId}` : '') +
      ` reason="${decision.reason}" confidence=${decision.confidence.toFixed(2)}\n` +
      `  content: "${generatedContent.slice(0, 100)}..."`,
    );
    return {}; // don't publish
  }

  try {
    if (decision.action === 'post') {
      // Dedupe key for posting
      const dedupeKey = `autonomy:post:${agentId}:${Date.now().toString(36)}`;
      const acquired = await acquireDedupeKey(dedupeKey, 3600);
      if (!acquired) return { error: 'dedupe: post already in flight' };

      const post = await createPost({
        author_id: `agent-${agentId}`,
        author_name: agent.name,
        author_avatar: agent.avatar,
        content: generatedContent,
        images: [],
        author_kind: 'agent',
        agent_persona: agentId,
        is_autonomous: true,
        autonomous_source: 'scheduled_post',
      });

      await incrementAgentDailyPost(agentId, costUsd).catch(() => {});
      await logAgentActivity({
        agent_id: agentId,
        action_type: 'autonomy_post',
        status: 'success',
        created_post_id: post.id,
        generated_content: generatedContent,
        estimated_cost: costUsd,
      }).catch(() => {});

      return { publishedPostId: post.id };
    }

    if (decision.action === 'reply' && decision.targetPostId) {
      const dedupeKey = dedupeKeyForReply(decision.targetPostId, agentId, 'autonomy');
      const acquired = await acquireDedupeKey(dedupeKey, 3600);
      if (!acquired) return { error: 'dedupe: already replied to this post' };

      const reply = await createReply({
        post_id: decision.targetPostId,
        author_kind: 'agent',
        author_id: `agent-${agentId}`,
        author_name: agent.name,
        author_avatar: agent.avatar,
        agent_persona: agentId,
        content: generatedContent,
        confidence_score: decision.confidence,
        visibility: 'public',
        is_autonomous: true,
      });

      await incrementAgentDailyReply(agentId, costUsd).catch(() => {});
      await logAgentActivity({
        agent_id: agentId,
        action_type: 'autonomy_reply',
        status: 'success',
        target_post_id: decision.targetPostId,
        created_reply_id: reply.id,
        generated_content: generatedContent,
        estimated_cost: costUsd,
      }).catch(() => {});

      return { publishedReplyId: reply.id };
    }
  } catch (err: any) {
    return { error: `publish failed: ${err?.message ?? err}` };
  }

  return {};
}

async function nodeRecordOutcome(state: typeof AutonomyState.State) {
  const { agentId, decision, error, publishedPostId, publishedReplyId } = state;

  if (error) {
    console.warn(`[autonomy-loop] ${agentId}: ${error}`);
    await logAgentActivity({
      agent_id: agentId,
      action_type: `autonomy_${decision?.action ?? 'unknown'}`,
      status: 'failed',
      error_message: error,
    }).catch(() => {});
  }

  if (decision?.action === 'skip') {
    console.log(`[autonomy-loop] ${agentId}: skip — ${decision.reason}`);
  }

  return {};
}

// ─── Route functions ──────────────────────────────────────────────────────────

function routeAfterDecide(state: typeof AutonomyState.State): string {
  if (state.error) return 'recordOutcome';
  const action = state.decision?.action ?? 'skip';
  if (action === 'post') return 'generatePost';
  if (action === 'reply') return 'selectTarget';
  return 'recordOutcome';
}

function routeAfterSelectTarget(state: typeof AutonomyState.State): string {
  if (state.error) return 'recordOutcome';
  if (state.decision?.action === 'skip') return 'recordOutcome';
  return 'generateReply';
}

function routeAfterGenerate(state: typeof AutonomyState.State): string {
  if (state.error || !state.generatedContent) return 'recordOutcome';
  return 'critique';
}

function routeAfterCritique(state: typeof AutonomyState.State): string {
  if (state.error) return 'recordOutcome';
  return 'publish';
}

// ─── Graph builder ────────────────────────────────────────────────────────────

export function buildAutonomyGraph() {
  const graph = new StateGraph(AutonomyState)
    .addNode('decideAction', nodeDecideAction)
    .addNode('selectTarget', nodeSelectTarget)
    .addNode('generatePost', nodeGeneratePost)
    .addNode('generateReply', nodeGenerateReply)
    .addNode('critique', nodeCritique)
    .addNode('publish', nodePublish)
    .addNode('recordOutcome', nodeRecordOutcome)
    .addEdge('__start__', 'decideAction')
    .addConditionalEdges('decideAction', routeAfterDecide, {
      generatePost: 'generatePost',
      selectTarget: 'selectTarget',
      recordOutcome: 'recordOutcome',
    })
    .addConditionalEdges('selectTarget', routeAfterSelectTarget, {
      generateReply: 'generateReply',
      recordOutcome: 'recordOutcome',
    })
    .addConditionalEdges('generatePost', routeAfterGenerate, {
      critique: 'critique',
      recordOutcome: 'recordOutcome',
    })
    .addConditionalEdges('generateReply', routeAfterGenerate, {
      critique: 'critique',
      recordOutcome: 'recordOutcome',
    })
    .addConditionalEdges('critique', routeAfterCritique, {
      publish: 'publish',
      recordOutcome: 'recordOutcome',
    })
    .addEdge('publish', 'recordOutcome')
    .addEdge('recordOutcome', END);

  return graph.compile();
}

// ─── Run one agent ────────────────────────────────────────────────────────────

export type AgentAutonomyResult = {
  agentId: string;
  action: string;
  reason: string;
  publishedPostId?: string;
  publishedReplyId?: string;
  error?: string;
  costUsd: number;
};

export async function runAgentAutonomy(agentId: string): Promise<AgentAutonomyResult> {
  const graph = buildAutonomyGraph();
  try {
    const finalState = await graph.invoke({ agentId });
    return {
      agentId,
      action: finalState.decision?.action ?? 'unknown',
      reason: finalState.decision?.reason ?? '',
      publishedPostId: finalState.publishedPostId ?? undefined,
      publishedReplyId: finalState.publishedReplyId ?? undefined,
      error: finalState.error ?? undefined,
      costUsd: finalState.costUsd ?? 0,
    };
  } catch (err: any) {
    console.error(`[autonomy-graph] ${agentId} crashed:`, err);
    return {
      agentId,
      action: 'error',
      reason: err?.message ?? String(err),
      error: err?.message ?? String(err),
      costUsd: 0,
    };
  }
}
