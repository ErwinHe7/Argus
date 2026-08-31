/**
 * Builds the "awareness snapshot" each agent gets before deciding what to do.
 * Token-bounded to stay under 3000 tokens (≈12 000 chars at ~4 chars/token).
 */

import { listPosts, listAgentActivityLogs } from './store';
import type { Post } from './types';

const STOPWORDS = new Set([
  'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'was',
  'has', 'had', 'have', 'with', 'that', 'this', 'they', 'from', 'will',
  'what', 'when', 'how', 'any', 'more', 'some', 'just', 'into', 'about',
  'than', 'then', 'been', 'also', 'its', 'our', 'your', 'their', 'which',
]);

export type FeedSnapshot = {
  id: string;
  authorName: string;
  authorKind: string;
  agentPersona?: string | null;
  content: string;
  replyCount: number;
  likeCount: number;
  createdAt: string;
};

export type AgentOutputSnapshot = {
  agentId: string;
  agentName: string;
  content: string;
  type: 'post' | 'reply';
  postId: string | null;
  createdAt: string;
};

export type AgentContext = {
  recentFeed: FeedSnapshot[];
  myRecentOutputs: AgentOutputSnapshot[];
  othersRecentOutputs: AgentOutputSnapshot[];
  trendingTopics: string[];
  estimatedTokens: number;
};

function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

function truncate(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return text.slice(0, maxChars - 1) + '…';
}

function extractTrendingTopics(posts: Post[], topN = 3): string[] {
  const freq = new Map<string, number>();
  for (const post of posts) {
    const words = post.content
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 3 && !STOPWORDS.has(w));
    for (const w of words) {
      freq.set(w, (freq.get(w) ?? 0) + 1);
    }
  }
  return [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([word]) => word);
}

export async function buildAgentContext(agentId: string): Promise<AgentContext> {
  const TOKEN_BUDGET = 3000;

  // Fetch raw data in parallel
  const [recentPosts, activityLogs] = await Promise.all([
    listPosts(50).catch(() => [] as Post[]),
    listAgentActivityLogs(200).catch(() => [] as Awaited<ReturnType<typeof listAgentActivityLogs>>),
  ]);

  // ── Trending topics from last 50 posts ──────────────────────────────────────
  const trendingTopics = extractTrendingTopics(recentPosts);

  // ── Recent feed (last 20, truncated content) ────────────────────────────────
  const recentFeed: FeedSnapshot[] = recentPosts.slice(0, 20).map((p) => ({
    id: p.id,
    authorName: p.author_name,
    authorKind: p.author_kind ?? 'human',
    agentPersona: p.agent_persona ?? null,
    content: truncate(p.content, 120),
    replyCount: p.reply_count,
    likeCount: p.like_count,
    createdAt: p.created_at,
  }));

  // ── My recent outputs (last 5) ──────────────────────────────────────────────
  const myLogs = activityLogs
    .filter(
      (l) =>
        l.agent_id === agentId &&
        l.status === 'success' &&
        l.generated_content,
    )
    .slice(0, 5);

  const myRecentOutputs: AgentOutputSnapshot[] = myLogs.map((l) => ({
    agentId,
    agentName: l.agent_id,
    content: truncate(l.generated_content ?? '', 100),
    type: l.created_post_id ? 'post' : 'reply',
    postId: l.created_post_id ?? l.created_reply_id ?? null,
    createdAt: l.created_at,
  }));

  // ── Others' recent outputs (last 2 per agent) ───────────────────────────────
  const otherAgentIds = ['nova', 'atlas', 'lumen', 'ember', 'sage', 'mercer', 'iris'].filter(
    (id) => id !== agentId,
  );

  const othersRecentOutputs: AgentOutputSnapshot[] = [];
  for (const otherId of otherAgentIds) {
    const otherLogs = activityLogs
      .filter(
        (l) =>
          l.agent_id === otherId &&
          l.status === 'success' &&
          l.generated_content,
      )
      .slice(0, 2);
    for (const l of otherLogs) {
      othersRecentOutputs.push({
        agentId: otherId,
        agentName: otherId,
        content: truncate(l.generated_content ?? '', 80),
        type: l.created_post_id ? 'post' : 'reply',
        postId: l.created_post_id ?? l.created_reply_id ?? null,
        createdAt: l.created_at,
      });
    }
  }

  // ── Token estimate ──────────────────────────────────────────────────────────
  const allText = [
    ...recentFeed.map((f) => f.content),
    ...myRecentOutputs.map((o) => o.content),
    ...othersRecentOutputs.map((o) => o.content),
    ...trendingTopics,
  ].join(' ');
  const estimatedTokens = estimateTokens(allText);

  // Trim feed if over budget
  if (estimatedTokens > TOKEN_BUDGET) {
    const excess = estimatedTokens - TOKEN_BUDGET;
    const charsToTrim = excess * 4;
    let trimmed = 0;
    for (let i = recentFeed.length - 1; i >= 10 && trimmed < charsToTrim; i--) {
      trimmed += recentFeed[i].content.length;
      recentFeed.splice(i, 1);
    }
  }

  return {
    recentFeed,
    myRecentOutputs,
    othersRecentOutputs,
    trendingTopics,
    estimatedTokens: Math.min(estimatedTokens, TOKEN_BUDGET),
  };
}

/** Format context into a compact string for injection into agent system prompt */
export function formatContextForPrompt(ctx: AgentContext, agentId: string): string {
  const parts: string[] = [];

  if (ctx.trendingTopics.length) {
    parts.push(`Trending now: ${ctx.trendingTopics.join(', ')}.`);
  }

  if (ctx.myRecentOutputs.length) {
    parts.push(
      `Your recent posts/replies: ${ctx.myRecentOutputs
        .map((o) => `"${o.content}"`)
        .join(' | ')}`,
    );
  }

  const othersSnippets = ctx.othersRecentOutputs
    .slice(0, 6)
    .map((o) => `${o.agentName}: "${o.content}"`)
    .join(' | ');
  if (othersSnippets) {
    parts.push(`Other agents recently said: ${othersSnippets}`);
  }

  const hotPosts = ctx.recentFeed
    .filter((f) => f.replyCount > 2)
    .slice(0, 3)
    .map((f) => `"${f.content}" (${f.replyCount} replies)`);
  if (hotPosts.length) {
    parts.push(`Hot threads: ${hotPosts.join(' | ')}`);
  }

  return parts.join('\n');
}
