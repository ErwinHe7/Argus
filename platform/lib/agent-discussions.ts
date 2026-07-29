/**
 * Agent Discussion Engine — Autonomous Community Mode
 *
 * Agents scan the entire site, find interesting threads, and autonomously
 * decide where to contribute — just like real community members.
 *
 * Two modes:
 * 1. runAgentDiscussion(postId)  — targeted: discuss one specific post
 * 2. runAutonomousDiscussionScan() — global: agents scan & self-select threads
 *
 * Feature flag: AGENT_DISCUSSIONS_ENABLED=true
 */

import { AGENTS } from './agents';
import { chatWithUsage } from './llm';
import { Annotation, END, StateGraph } from '@langchain/langgraph';
import { acquireDedupeKey, dedupeKeyForReply } from './agent-graph-utils';
import {
  listPosts,
  getPost,
  listReplies,
  createPost,
  createReply,
  countAgentDiscussionReplies,
  getDiscussionRoundForPost,
  isDiscussionJobRunning,
  createDiscussionJob,
  finishDiscussionJob,
  getHourlyDiscussionCount,
} from './store';
import type { Post, Reply, AgentPersona } from './types';

// ─── Feature flags + caps ─────────────────────────────────────────────────────

export function isDiscussionsEnabled(): boolean {
  return process.env.AGENT_DISCUSSIONS_ENABLED === 'true';
}

const CAP = {
  maxRoundsPerPost:        Number(process.env.MAX_DISCUSSION_ROUNDS_PER_POST ?? '5'),
  maxRepliesPerRound:      Number(process.env.MAX_AGENT_DISCUSSION_REPLIES_PER_ROUND ?? '4'),
  maxTotalRepliesPerPost:  Number(process.env.MAX_TOTAL_AGENT_REPLIES_PER_POST ?? '40'),
  maxRepliesPerHour:       Number(process.env.MAX_AGENT_DISCUSSION_REPLIES_PER_HOUR ?? '200'),
  // How many posts agents scan per autonomous run
  scanPostsPerRun:         Number(process.env.DISCUSSION_SCAN_POSTS_PER_RUN ?? '15'),
  // How many posts get selected for discussion per run
  maxPostsPerRun:          Number(process.env.DISCUSSION_MAX_POSTS_PER_RUN ?? '5'),
};

// ─── Topic detection ──────────────────────────────────────────────────────────

const TOPIC_AGENTS: Record<string, string[]> = {
  markets:    ['nova', 'mercer', 'sage', 'atlas'],
  trade:      ['mercer', 'atlas', 'nova', 'lumen'],
  startup:    ['nova', 'ember', 'atlas', 'mercer'],
  philosophy: ['lumen', 'sage', 'iris', 'nova'],
  nyc:        ['iris', 'atlas', 'nova', 'mercer'],
  events:     ['iris', 'atlas', 'nova', 'sage'],
  books:      ['sage', 'lumen', 'nova', 'iris'],
  career:     ['nova', 'ember', 'lumen', 'atlas'],
  food:       ['iris', 'atlas', 'nova'],
};

function detectTopic(text: string): string {
  const t = text.toLowerCase();
  if (/market|stocks?|ticker|earnings|fed|sec|filing|options?|crypto|macro|nvda|tsla|coin|amd/.test(t)) return 'markets';
  if (/trade|sell|buy|furniture|deal|price|ikea|macbook|iphone/.test(t)) return 'trade';
  if (/startup|founder|vc|pmf|launch|ship|build|mvp|fundrais/.test(t)) return 'startup';
  if (/philosophy|meaning|identity|purpose|belief|existential/.test(t)) return 'philosophy';
  if (/event|concert|party|tonight|weekend|gallery|show|exhibit/.test(t)) return 'events';
  if (/book|read|essay|paper|research|thesis|novel/.test(t)) return 'books';
  if (/nyc|new york|columbia|manhattan|brooklyn|subway|morningside/.test(t)) return 'nyc';
  if (/job|offer|career|intern|salary|interview|resume|hire/.test(t)) return 'career';
  if (/food|eat|restaurant|ramen|pizza|dining|swipe|meal/.test(t)) return 'food';
  return 'general';
}

// ─── Interest scoring (agent self-selects threads) ────────────────────────────

/**
 * Score how interested a specific agent is in a given post/thread.
 * Higher = more likely to participate.
 */
function agentInterestScore(agent: AgentPersona, post: Post, replies: Reply[]): number {
  const topic = detectTopic(post.content);
  const preferred = TOPIC_AGENTS[topic] ?? [];

  let score = 0;

  // Domain match
  if (preferred.includes(agent.id)) score += 3;

  // Keyword match with agent's topics
  const postText = post.content.toLowerCase();
  const topicMatches = agent.topics.filter(t => postText.includes(t)).length;
  score += topicMatches * 0.5;

  // Thread health: more replies = more interesting, but not too crowded
  const agentRepliesInThread = replies.filter(r =>
    r.author_kind === 'agent' && r.agent_persona === agent.id
  ).length;
  if (agentRepliesInThread > 0) score -= 2; // already spoke here recently
  if (replies.length > 5 && replies.length < 25) score += 1; // active but not saturated

  // Recency: posts in last 6h get bonus
  const ageHours = (Date.now() - new Date(post.created_at).getTime()) / 3_600_000;
  if (ageHours < 3) score += 2;
  else if (ageHours < 12) score += 1;

  // Human post bonus (agents prefer responding to humans, not just each other)
  const humanReplies = replies.filter(r => r.author_kind === 'human').length;
  if (humanReplies > 0) score += 1;

  // Avoid maxed-out threads
  const totalAgentReplies = replies.filter(r => r.author_kind === 'agent').length;
  if (totalAgentReplies >= CAP.maxTotalRepliesPerPost) score -= 10;

  return score;
}

// ─── Agent selection for a specific post ─────────────────────────────────────

function selectAgentsForPost(
  post: Post,
  replies: Reply[],
  count: number,
): AgentPersona[] {
  // Score each agent's interest in this post
  const scored = AGENTS.map(a => ({
    agent: a,
    score: agentInterestScore(a, post, replies) + Math.random() * 0.5, // tiny random jitter
  })).sort((a, b) => b.score - a.score);

  // Filter out agents who've already replied too many times in this thread
  const eligible = scored.filter(({ agent }) => {
    const speakCount = replies.filter(r => r.agent_persona === agent.id).length;
    return speakCount < 3;
  });

  return eligible.slice(0, count).map(s => s.agent);
}

// ─── Quality checks ───────────────────────────────────────────────────────────

const LOW_QUALITY_PATTERNS = [
  /^(great|interesting|good point|nice|well said|exactly|absolutely|definitely|i agree)[\s!.]*$/i,
  /system prompt/i,
  /as an ai/i,
  /i cannot/i,
  /i'm not able/i,
];

function passesQuality(content: string): boolean {
  const t = content.trim();
  if (t.length < 25 || t.length > 600) return false;
  if (LOW_QUALITY_PATTERNS.some(p => p.test(t))) return false;
  if (t.split(/\s+/).length < 6) return false;
  return true;
}

function isDuplicate(content: string, existing: Reply[]): boolean {
  const norm = content.toLowerCase().replace(/[^a-z0-9\s]/g, '').trim();
  const aWords = new Set(norm.split(/\s+/).filter(w => w.length > 3));
  return existing.some(r => {
    const rNorm = r.content.toLowerCase().replace(/[^a-z0-9\s]/g, '').trim();
    const bWords = new Set(rNorm.split(/\s+/).filter(w => w.length > 3));
    if (aWords.size === 0 || bWords.size === 0) return false;
    const intersection = [...aWords].filter(w => bWords.has(w)).length;
    const union = new Set([...aWords, ...bWords]).size;
    return intersection / union > 0.60;
  });
}

// ─── Prompt builder ───────────────────────────────────────────────────────────

function buildDiscussionPrompt(
  agent: AgentPersona,
  post: Post,
  existingReplies: Reply[],
): string {
  // Show the most relevant recent replies, not just the latest
  const agentReplies = existingReplies.filter(r => r.author_kind === 'agent').slice(-6);
  const humanReplies = existingReplies.filter(r => r.author_kind === 'human').slice(-3);

  const threadContext = [...humanReplies, ...agentReplies]
    .sort((a, b) => a.created_at.localeCompare(b.created_at))
    .slice(-8)
    .map(r => `${r.author_name}: "${r.content.slice(0, 180)}"`)
    .join('\n');

  const totalReplies = existingReplies.length;

  // Different instructions based on thread state
  let task: string;
  if (totalReplies === 0) {
    task = 'This thread just started. Give your initial take from your specific angle.';
  } else if (totalReplies < 5) {
    task = 'Build on or challenge one of the existing replies. Add something concrete the others missed.';
  } else if (totalReplies < 15) {
    task = 'The thread is active. Pick the most interesting point and push it further, or offer a contrarian view.';
  } else {
    task = 'This is a rich thread. Either ask a sharp follow-up question that no one has addressed, or give a specific actionable recommendation for the original poster.';
  }

  return `You are ${agent.name} — one of AXIO7's agents on a student platform for Columbia and NYC.

Your identity: ${agent.description ?? agent.tagline}
Your expertise: ${agent.topics.slice(0, 5).join(', ')}

Original post:
"${post.content.slice(0, 500)}"

Current discussion (${totalReplies} replies so far):
${threadContext || '(first reply)'}

Your task:
${task}

Hard rules:
- 1-4 sentences. Be sharp, specific, natural.
- Reference something specific from the thread when it exists.
- Stay in your domain — don't fake expertise you don't have.
- Add a Columbia/NYC/trade/local detail when genuinely relevant.
- Never say "As an AI", "I'm an AI", or anything that breaks character.
- Don't start with "Great point" or empty affirmations.
- Don't repeat what was already said.

Output your reply only. Nothing else.`;
}

// ─── Generate one reply from one agent on one post ───────────────────────────

async function generateOneReply(
  agent: AgentPersona,
  post: Post,
  existingReplies: Reply[],
  round: number,
): Promise<{ content: string; ok: boolean }> {
  const prompt = buildDiscussionPrompt(agent, post, existingReplies);

  try {
    const result = await chatWithUsage(
      [{ role: 'user', content: prompt }],
      { model: agent.model, temperature: 0.9, max_tokens: 220 },
    );
    const content = result.content.trim().replace(/^["']|["']$/g, '');
    if (!passesQuality(content)) return { content, ok: false };
    if (isDuplicate(content, existingReplies)) return { content, ok: false };
    return { content, ok: true };
  } catch (err: any) {
    console.error(`[discussion] ${agent.id} LLM error:`, err?.message?.slice(0, 100));
    return { content: '', ok: false };
  }
}

// ─── Discuss a single post ────────────────────────────────────────────────────

export type DiscussionResult =
  | { ok: true; inserted: number; round: number; postId: string }
  | { ok: false; reason: string };

async function runLegacyAgentDiscussion(
  postId: string,
  options: { force?: boolean } = {},
): Promise<DiscussionResult> {
  if (!isDiscussionsEnabled() && !options.force) {
    return { ok: false, reason: 'discussions_disabled' };
  }

  const hourlyCount = await getHourlyDiscussionCount();
  if (hourlyCount >= CAP.maxRepliesPerHour) {
    return { ok: false, reason: 'global_hourly_cap_reached' };
  }

  const post = await getPost(postId).catch(() => null);
  if (!post) return { ok: false, reason: 'post_not_found' };

  const [existingReplies, currentRound, totalAgentReplies, jobRunning] = await Promise.all([
    listReplies(postId).catch(() => [] as Reply[]),
    getDiscussionRoundForPost(postId),
    countAgentDiscussionReplies(postId),
    isDiscussionJobRunning(postId),
  ]);

  if (!options.force && jobRunning) return { ok: false, reason: 'job_already_running' };
  if (totalAgentReplies >= CAP.maxTotalRepliesPerPost) return { ok: false, reason: 'max_total_replies_reached' };

  const nextRound = currentRound + 1;
  if (!options.force && nextRound > CAP.maxRoundsPerPost) return { ok: false, reason: 'max_rounds_reached' };

  const jobId = await createDiscussionJob(postId, nextRound).catch(() => null);

  // Select 2-4 agents most interested in this post
  const agentCount = Math.min(CAP.maxRepliesPerRound, CAP.maxTotalRepliesPerPost - totalAgentReplies);
  const agents = selectAgentsForPost(post, existingReplies, agentCount);

  if (agents.length === 0) {
    await finishDiscussionJob(jobId ?? '', 'skipped', { error: 'no eligible agents' });
    return { ok: false, reason: 'no_eligible_agents' };
  }

  let inserted = 0;
  let runningReplies = [...existingReplies];

  for (const agent of agents) {
    const { content, ok } = await generateOneReply(agent, post, runningReplies, nextRound);
    if (!ok || !content) { await new Promise(r => setTimeout(r, 200)); continue; }

    try {
      const reply = await createReply({
        post_id: postId,
        author_kind: 'agent',
        author_name: agent.name,
        author_avatar: agent.avatar,
        agent_persona: agent.id,
        content,
        confidence_score: 0.82,
        visibility: 'public',
        reply_type: 'agent_discussion',
        discussion_round: nextRound,
        is_autonomous: true,
      });
      runningReplies = [...runningReplies, reply];
      inserted++;
    } catch (err: any) {
      console.error(`[discussion] save failed ${agent.id}:`, err?.message?.slice(0, 100));
    }

    await new Promise(r => setTimeout(r, 400)); // stagger between agents
  }

  await finishDiscussionJob(jobId ?? '', inserted > 0 ? 'completed' : 'skipped', { inserted });
  console.log(`[discussion] post=${postId} round=${nextRound} inserted=${inserted}`);
  return { ok: true, inserted, round: nextRound, postId };
}

export async function runAgentDiscussion(
  postId: string,
  options: { force?: boolean } = {},
): Promise<DiscussionResult> {
  if (process.env.AGENT_GRAPH_DISCUSSIONS_ENABLED === 'true') {
    let publishStarted = false;
    try {
      return await runAgentDiscussionGraph(postId, options, () => {
        publishStarted = true;
      });
    } catch (error) {
      console.error('[discussion:graph] failed', { postId, publishStarted, error });
      if (!publishStarted) return await runLegacyAgentDiscussion(postId, options);
      return { ok: false, reason: 'graph_failed_after_publish_started' };
    }
  }
  return await runLegacyAgentDiscussion(postId, options);
}

// ─── Agent self-posting ───────────────────────────────────────────────────────

/**
 * Build a prompt for an agent to write an original post inspired by
 * what it sees in the current feed — not copying, but organically reacting.
 */
function buildSelfPostPrompt(agent: AgentPersona, feedContext: Post[]): string {
  const feedSnippet = feedContext
    .slice(0, 6)
    .map(p => `"${p.content.slice(0, 120)}"`)
    .join('\n');

  return `You are ${agent.name} on AXIO7, a student platform for Columbia University and NYC locals.

Your identity: ${agent.description ?? agent.tagline}
Your expertise: ${agent.topics.slice(0, 5).join(', ')}

Recent posts you've seen on the feed:
${feedSnippet}

You've decided to start a new conversation based on something you noticed or a topic you care about.

Write ONE short post that:
- Is genuinely in your domain (${agent.tagline})
- Reacts to the mood/topics of the feed, but isn't a copy
- Is specific: name a place, price, concept, situation, or question
- Would make Columbia students or NYC locals want to reply
- Is 1-3 sentences

Hard rules:
- Never say "As an AI" or break character
- No generic content ("Life is short!", etc.)
- Make it feel organic — like you just thought of something worth sharing
- Can be a take, an observation, a question, or a tip

Output only the post text. Nothing else.`;
}

/**
 * Agent generates and publishes its own new post.
 * Returns the created Post or null on failure.
 */
async function generateAndPublishAgentPost(
  agent: AgentPersona,
  feedContext: Post[],
): Promise<Post | null> {
  const prompt = buildSelfPostPrompt(agent, feedContext);

  let content = '';
  try {
    const result = await chatWithUsage(
      [{ role: 'user', content: prompt }],
      { model: agent.model, temperature: 0.92, max_tokens: 200 },
    );
    content = result.content.trim().replace(/^["']|["']$/g, '');
  } catch (err: any) {
    console.error(`[discussion-post] ${agent.id} LLM error:`, err?.message?.slice(0, 100));
    return null;
  }

  if (!passesQuality(content)) return null;

  // Dedup against recent feed posts
  if (isDuplicate(content, feedContext.map(p => ({
    content: p.content,
    // minimal Reply shape for dedup check
    id: p.id, post_id: p.id, author_kind: 'human' as const,
    author_id: '', author_name: '', author_avatar: null,
    agent_persona: null, created_at: p.created_at,
    confidence_score: null, visibility: 'public' as const,
    up_count: 0, down_count: 0,
  })))) return null;

  try {
    const post = await createPost({
      author_id: `agent-${agent.id}`,
      author_name: agent.name,
      author_avatar: agent.avatar,
      content,
      images: [],
      author_kind: 'agent',
      agent_persona: agent.id,
      is_autonomous: true,
      autonomous_source: 'scheduled_post',
    });
    console.log(`[discussion-post] ${agent.id} published: "${content.slice(0, 60)}"`);
    return post;
  } catch (err: any) {
    console.error(`[discussion-post] createPost failed ${agent.id}:`, err?.message?.slice(0, 100));
    return null;
  }
}

// ─── Autonomous scan: agents browse the whole site ───────────────────────────

export type ScanResult = {
  postsScanned: number;
  postsSelected: number;
  totalInserted: number;
  agentPostsPublished: number;
  details: Array<{ postId: string; inserted: number; skipped?: string }>;
  agentPosts: Array<{ agentId: string; postId: string; preview: string }>;
};

/**
 * Main autonomous mode: scan recent posts across the site, score each one
 * per-agent, let each agent pick threads to contribute to independently.
 *
 * This is the "Moltbook-style" self-directed behavior:
 * - Each agent acts on its own interest score
 * - Multiple agents can pick different posts in the same run
 * - Naturally spreads discussion across the whole feed
 */
async function runLegacyAutonomousDiscussionScan(options: {
  force?: boolean;
} = {}): Promise<ScanResult> {
  const empty: ScanResult = {
    postsScanned: 0, postsSelected: 0,
    totalInserted: 0, agentPostsPublished: 0,
    details: [], agentPosts: [],
  };

  if (!isDiscussionsEnabled() && !options.force) return empty;

  const hourlyCount = await getHourlyDiscussionCount();
  if (hourlyCount >= CAP.maxRepliesPerHour) {
    console.log('[discussion-scan] hourly cap reached');
    return empty;
  }

  // Scan recent posts — more than we'll process, so we can score + select
  const recentPosts = await listPosts(CAP.scanPostsPerRun).catch(() => [] as Post[]);
  if (recentPosts.length === 0) return empty;

  // For each post, fetch its replies and compute per-agent interest scores
  const postProfiles = await Promise.all(
    recentPosts.map(async post => {
      const replies = await listReplies(post.id).catch(() => [] as Reply[]);
      const totalAgentReplies = replies.filter(r => r.author_kind === 'agent').length;
      const currentRound = await getDiscussionRoundForPost(post.id).catch(() => 0);
      const jobRunning = await isDiscussionJobRunning(post.id).catch(() => false);
      return { post, replies, totalAgentReplies, currentRound, jobRunning };
    })
  );

  // ── Per-agent decision: post something new OR reply to existing threads ──────
  const postAgentQueue = new Map<string, AgentPersona[]>();
  const agentPostResults: ScanResult['agentPosts'] = [];

  // Agents that will post (max 2 per scan to avoid flooding)
  let agentPostsThisScan = 0;
  const MAX_AGENT_POSTS_PER_SCAN = 2;

  // Shuffle agents so different ones get priority each run
  const shuffledAgents = [...AGENTS].sort(() => Math.random() - 0.5);

  for (const agent of shuffledAgents) {
    // Score every eligible post for this agent
    const scored = postProfiles
      .filter(p =>
        !p.jobRunning &&
        p.totalAgentReplies < CAP.maxTotalRepliesPerPost &&
        (options.force || p.currentRound < CAP.maxRoundsPerPost)
      )
      .map(p => ({
        ...p,
        score: agentInterestScore(agent, p.post, p.replies),
      }))
      .filter(p => p.score > 0)
      .sort((a, b) => b.score - a.score);

    const bestScore = scored[0]?.score ?? 0;

    // Decision: if the feed doesn't have anything very interesting for this agent
    // (best score ≤ 1.5), consider starting a new conversation instead.
    // Also randomly decide to post (20% chance) even when good threads exist,
    // to keep the feed lively with new topics.
    const shouldPost =
      agentPostsThisScan < MAX_AGENT_POSTS_PER_SCAN &&
      (bestScore <= 1.5 || Math.random() < 0.20);

    if (shouldPost) {
      agentPostsThisScan++;
      // Fire-and-forget post generation (don't block the reply loop)
      generateAndPublishAgentPost(agent, recentPosts).then(post => {
        if (post) {
          agentPostResults.push({
            agentId: agent.id,
            postId: post.id,
            preview: post.content.slice(0, 80),
          });
        }
      }).catch(() => {});
    } else {
      // Reply to existing threads
      const picks = scored.slice(0, 2);
      for (const pick of picks) {
        const existing = postAgentQueue.get(pick.post.id) ?? [];
        if (existing.length < CAP.maxRepliesPerRound) {
          postAgentQueue.set(pick.post.id, [...existing, agent]);
        }
      }
    }
  }

  // Flatten to a deduplicated list of (postId, agents[]) pairs, limit total posts per run
  const workItems = [...postAgentQueue.entries()]
    .sort((a, b) => b[1].length - a[1].length) // posts with more interested agents first
    .slice(0, CAP.maxPostsPerRun);

  console.log(`[discussion-scan] scanned=${recentPosts.length} selected=${workItems.length} agents`);

  const details: ScanResult['details'] = [];
  let totalInserted = 0;

  for (const [postId, agents] of workItems) {
    const profile = postProfiles.find(p => p.post.id === postId)!;

    const jobId = await createDiscussionJob(postId, profile.currentRound + 1).catch(() => null);
    let inserted = 0;
    let runningReplies = [...profile.replies];

    for (const agent of agents) {
      const { content, ok } = await generateOneReply(
        agent, profile.post, runningReplies, profile.currentRound + 1
      );
      if (!ok || !content) continue;

      try {
        const reply = await createReply({
          post_id: postId,
          author_kind: 'agent',
          author_name: agent.name,
          author_avatar: agent.avatar,
          agent_persona: agent.id,
          content,
          confidence_score: 0.82,
          visibility: 'public',
          reply_type: 'agent_discussion',
          discussion_round: profile.currentRound + 1,
          is_autonomous: true,
        });
        runningReplies = [...runningReplies, reply];
        inserted++;
        totalInserted++;
      } catch (err: any) {
        console.error(`[discussion-scan] save failed ${agent.id}:`, err?.message?.slice(0, 80));
      }

      await new Promise(r => setTimeout(r, 350));
    }

    await finishDiscussionJob(jobId ?? '', inserted > 0 ? 'completed' : 'skipped', { inserted });
    details.push({ postId, inserted });
    console.log(`[discussion-scan] post=${postId} inserted=${inserted}`);

    // Pause between posts to avoid rate-limit spikes
    await new Promise(r => setTimeout(r, 800));
  }

  // Small wait to let fire-and-forget agent posts settle
  await new Promise(r => setTimeout(r, 1500));

  return {
    postsScanned: recentPosts.length,
    postsSelected: workItems.length,
    totalInserted,
    agentPostsPublished: agentPostResults.length,
    details,
    agentPosts: agentPostResults,
  };
}

type DiscussionOptions = { force?: boolean };

type DiscussionProfile = {
  post: Post;
  replies: Reply[];
  totalAgentReplies: number;
  currentRound: number;
  jobRunning: boolean;
};

async function createDiscussionReplyWithDedupe(input: {
  postId: string;
  agent: AgentPersona;
  content: string;
  round: number;
  scope: string;
  onPublishStarted?: () => void;
}): Promise<Reply | null> {
  const dedupeKey = dedupeKeyForReply(input.postId, input.agent.id, input.scope);
  const acquired = await acquireDedupeKey(dedupeKey);
  if (!acquired) {
    console.log('[discussion:graph] duplicate prevented', { postId: input.postId, agentId: input.agent.id, dedupeKey });
    return null;
  }
  input.onPublishStarted?.();
  return await createReply({
    post_id: input.postId,
    author_kind: 'agent',
    author_name: input.agent.name,
    author_avatar: input.agent.avatar,
    agent_persona: input.agent.id,
    content: input.content,
    confidence_score: 0.82,
    visibility: 'public',
    reply_type: 'agent_discussion',
    discussion_round: input.round,
    is_autonomous: true,
  });
}

const DiscussionState = Annotation.Root({
  postId: Annotation<string>(),
  options: Annotation<DiscussionOptions>({ default: () => ({}), reducer: (_, v) => v }),
  post: Annotation<Post | null>({ default: () => null, reducer: (_, v) => v }),
  existingReplies: Annotation<Reply[]>({ default: () => [], reducer: (_, v) => v }),
  currentRound: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
  totalAgentReplies: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
  nextRound: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
  agents: Annotation<AgentPersona[]>({ default: () => [], reducer: (_, v) => v }),
  inserted: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
  publishStartedCallback: Annotation<(() => void) | undefined>({ default: () => undefined, reducer: (_, v) => v }),
  result: Annotation<DiscussionResult | null>({ default: () => null, reducer: (_, v) => v }),
});

type DS = typeof DiscussionState.State;

async function loadDiscussionContextNode(state: DS): Promise<Partial<DS>> {
  if (!isDiscussionsEnabled() && !state.options.force) {
    return { result: { ok: false, reason: 'discussions_disabled' } };
  }
  const hourlyCount = await getHourlyDiscussionCount();
  if (hourlyCount >= CAP.maxRepliesPerHour) {
    return { result: { ok: false, reason: 'global_hourly_cap_reached' } };
  }
  const post = await getPost(state.postId).catch(() => null);
  if (!post) return { result: { ok: false, reason: 'post_not_found' } };
  const [existingReplies, currentRound, totalAgentReplies, jobRunning] = await Promise.all([
    listReplies(state.postId).catch(() => [] as Reply[]),
    getDiscussionRoundForPost(state.postId),
    countAgentDiscussionReplies(state.postId),
    isDiscussionJobRunning(state.postId),
  ]);
  if (!state.options.force && jobRunning) return { result: { ok: false, reason: 'job_already_running' } };
  if (totalAgentReplies >= CAP.maxTotalRepliesPerPost) return { result: { ok: false, reason: 'max_total_replies_reached' } };
  const nextRound = currentRound + 1;
  if (!state.options.force && nextRound > CAP.maxRoundsPerPost) return { result: { ok: false, reason: 'max_rounds_reached' } };
  return { post, existingReplies, currentRound, totalAgentReplies, nextRound };
}

function routeDiscussionAfterLoad(state: DS): 'selectDiscussionAgents' | 'finishDiscussion' {
  return state.result ? 'finishDiscussion' : 'selectDiscussionAgents';
}

async function selectDiscussionAgentsNode(state: DS): Promise<Partial<DS>> {
  const agentCount = Math.min(CAP.maxRepliesPerRound, CAP.maxTotalRepliesPerPost - state.totalAgentReplies);
  const agents = selectAgentsForPost(state.post!, state.existingReplies, agentCount);
  if (agents.length === 0) return { result: { ok: false, reason: 'no_eligible_agents' } };
  return { agents };
}

async function generateDiscussionRepliesNode(state: DS): Promise<Partial<DS>> {
  const jobId = await createDiscussionJob(state.postId, state.nextRound).catch(() => null);
  let inserted = 0;
  let runningReplies = [...state.existingReplies];
  for (const agent of state.agents) {
    const { content, ok } = await generateOneReply(agent, state.post!, runningReplies, state.nextRound);
    if (!ok || !content) {
      await new Promise((resolve) => setTimeout(resolve, 200));
      continue;
    }
    try {
      const reply = await createDiscussionReplyWithDedupe({
        postId: state.postId,
        agent,
        content,
        round: state.nextRound,
        scope: `discussion:${state.nextRound}`,
        onPublishStarted: state.publishStartedCallback,
      });
      if (reply) {
        runningReplies = [...runningReplies, reply];
        inserted++;
      }
    } catch (error: any) {
      console.error(`[discussion:graph] save failed ${agent.id}:`, error?.message?.slice(0, 100));
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  await finishDiscussionJob(jobId ?? '', inserted > 0 ? 'completed' : 'skipped', { inserted });
  console.log(`[discussion:graph] post=${state.postId} round=${state.nextRound} inserted=${inserted}`);
  return { inserted, result: { ok: true, inserted, round: state.nextRound, postId: state.postId } };
}

function finishDiscussionNode(): Partial<DS> {
  return {};
}

const discussionWorkflow = new StateGraph(DiscussionState)
  .addNode('loadDiscussionContext', loadDiscussionContextNode)
  .addNode('selectDiscussionAgents', selectDiscussionAgentsNode)
  .addNode('generateDiscussionReplies', generateDiscussionRepliesNode)
  .addNode('finishDiscussion', finishDiscussionNode)
  .addEdge('__start__', 'loadDiscussionContext')
  .addConditionalEdges('loadDiscussionContext', routeDiscussionAfterLoad, {
    selectDiscussionAgents: 'selectDiscussionAgents',
    finishDiscussion: 'finishDiscussion',
  })
  .addEdge('selectDiscussionAgents', 'generateDiscussionReplies')
  .addEdge('generateDiscussionReplies', 'finishDiscussion')
  .addEdge('finishDiscussion', END);

const discussionGraph = discussionWorkflow.compile();

async function runAgentDiscussionGraph(
  postId: string,
  options: DiscussionOptions,
  onPublishStarted?: () => void,
): Promise<DiscussionResult> {
  const finalState = await discussionGraph.invoke({ postId, options, publishStartedCallback: onPublishStarted });
  return finalState.result ?? { ok: false, reason: 'graph_no_result' };
}

const ScanState = Annotation.Root({
  options: Annotation<DiscussionOptions>({ default: () => ({}), reducer: (_, v) => v }),
  recentPosts: Annotation<Post[]>({ default: () => [], reducer: (_, v) => v }),
  postProfiles: Annotation<DiscussionProfile[]>({ default: () => [], reducer: (_, v) => v }),
  workItems: Annotation<Array<{ postId: string; agents: AgentPersona[] }>>({ default: () => [], reducer: (_, v) => v }),
  agentPostAgents: Annotation<AgentPersona[]>({ default: () => [], reducer: (_, v) => v }),
  details: Annotation<ScanResult['details']>({ default: () => [], reducer: (_, v) => v }),
  agentPosts: Annotation<ScanResult['agentPosts']>({ default: () => [], reducer: (_, v) => v }),
  totalInserted: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
  publishStartedCallback: Annotation<(() => void) | undefined>({ default: () => undefined, reducer: (_, v) => v }),
  result: Annotation<ScanResult | null>({ default: () => null, reducer: (_, v) => v }),
});

type SS = typeof ScanState.State;

function emptyScanResult(): ScanResult {
  return {
    postsScanned: 0,
    postsSelected: 0,
    totalInserted: 0,
    agentPostsPublished: 0,
    details: [],
    agentPosts: [],
  };
}

async function loadScanContextNode(state: SS): Promise<Partial<SS>> {
  if (!isDiscussionsEnabled() && !state.options.force) return { result: emptyScanResult() };
  const hourlyCount = await getHourlyDiscussionCount();
  if (hourlyCount >= CAP.maxRepliesPerHour) {
    console.log('[discussion-scan:graph] hourly cap reached');
    return { result: emptyScanResult() };
  }
  const recentPosts = await listPosts(CAP.scanPostsPerRun).catch(() => [] as Post[]);
  if (recentPosts.length === 0) return { result: emptyScanResult() };
  const postProfiles = await Promise.all(
    recentPosts.map(async (post) => {
      const replies = await listReplies(post.id).catch(() => [] as Reply[]);
      const totalAgentReplies = replies.filter((reply) => reply.author_kind === 'agent').length;
      const currentRound = await getDiscussionRoundForPost(post.id).catch(() => 0);
      const jobRunning = await isDiscussionJobRunning(post.id).catch(() => false);
      return { post, replies, totalAgentReplies, currentRound, jobRunning };
    }),
  );
  return { recentPosts, postProfiles };
}

function routeScanAfterLoad(state: SS): 'selectScanWork' | 'finishScan' {
  return state.result ? 'finishScan' : 'selectScanWork';
}

function selectScanWorkNode(state: SS): Partial<SS> {
  const postAgentQueue = new Map<string, AgentPersona[]>();
  const agentPostAgents: AgentPersona[] = [];
  let agentPostsThisScan = 0;
  const maxAgentPostsPerScan = 2;
  const shuffledAgents = [...AGENTS].sort(() => Math.random() - 0.5);

  for (const agent of shuffledAgents) {
    const scored = state.postProfiles
      .filter((profile) =>
        !profile.jobRunning &&
        profile.totalAgentReplies < CAP.maxTotalRepliesPerPost &&
        (state.options.force || profile.currentRound < CAP.maxRoundsPerPost)
      )
      .map((profile) => ({
        ...profile,
        score: agentInterestScore(agent, profile.post, profile.replies),
      }))
      .filter((profile) => profile.score > 0)
      .sort((a, b) => b.score - a.score);

    const bestScore = scored[0]?.score ?? 0;
    const shouldPost =
      agentPostsThisScan < maxAgentPostsPerScan &&
      (bestScore <= 1.5 || Math.random() < 0.20);

    if (shouldPost) {
      agentPostsThisScan++;
      agentPostAgents.push(agent);
      continue;
    }

    for (const pick of scored.slice(0, 2)) {
      const existing = postAgentQueue.get(pick.post.id) ?? [];
      if (existing.length < CAP.maxRepliesPerRound) {
        postAgentQueue.set(pick.post.id, [...existing, agent]);
      }
    }
  }

  const workItems = [...postAgentQueue.entries()]
    .sort((a, b) => b[1].length - a[1].length)
    .slice(0, CAP.maxPostsPerRun)
    .map(([postId, agents]) => ({ postId, agents }));

  console.log(`[discussion-scan:graph] scanned=${state.recentPosts.length} selected=${workItems.length} agents`);
  return { workItems, agentPostAgents };
}

async function publishScanAgentPostsNode(state: SS): Promise<Partial<SS>> {
  const agentPosts: ScanResult['agentPosts'] = [...state.agentPosts];
  for (const agent of state.agentPostAgents) {
    state.publishStartedCallback?.();
    const post = await generateAndPublishAgentPost(agent, state.recentPosts).catch(() => null);
    if (post) {
      agentPosts.push({
        agentId: agent.id,
        postId: post.id,
        preview: post.content.slice(0, 80),
      });
    }
  }
  return { agentPosts };
}

async function publishScanRepliesNode(state: SS): Promise<Partial<SS>> {
  const details: ScanResult['details'] = [];
  let totalInserted = state.totalInserted;

  for (const item of state.workItems) {
    const profile = state.postProfiles.find((candidate) => candidate.post.id === item.postId);
    if (!profile) continue;
    const nextRound = profile.currentRound + 1;
    const jobId = await createDiscussionJob(item.postId, nextRound).catch(() => null);
    let inserted = 0;
    let runningReplies = [...profile.replies];

    for (const agent of item.agents) {
      const { content, ok } = await generateOneReply(agent, profile.post, runningReplies, nextRound);
      if (!ok || !content) continue;
      try {
        const reply = await createDiscussionReplyWithDedupe({
          postId: item.postId,
          agent,
          content,
          round: nextRound,
          scope: `discussion-scan:${nextRound}`,
          onPublishStarted: state.publishStartedCallback,
        });
        if (reply) {
          runningReplies = [...runningReplies, reply];
          inserted++;
          totalInserted++;
        }
      } catch (error: any) {
        console.error(`[discussion-scan:graph] save failed ${agent.id}:`, error?.message?.slice(0, 80));
      }
      await new Promise((resolve) => setTimeout(resolve, 350));
    }

    await finishDiscussionJob(jobId ?? '', inserted > 0 ? 'completed' : 'skipped', { inserted });
    details.push({ postId: item.postId, inserted });
    console.log(`[discussion-scan:graph] post=${item.postId} inserted=${inserted}`);
    await new Promise((resolve) => setTimeout(resolve, 800));
  }

  return { details, totalInserted };
}

function finishScanNode(state: SS): Partial<SS> {
  if (state.result) return {};
  return {
    result: {
      postsScanned: state.recentPosts.length,
      postsSelected: state.workItems.length,
      totalInserted: state.totalInserted,
      agentPostsPublished: state.agentPosts.length,
      details: state.details,
      agentPosts: state.agentPosts,
    },
  };
}

const scanWorkflow = new StateGraph(ScanState)
  .addNode('loadScanContext', loadScanContextNode)
  .addNode('selectScanWork', selectScanWorkNode)
  .addNode('publishScanAgentPosts', publishScanAgentPostsNode)
  .addNode('publishScanReplies', publishScanRepliesNode)
  .addNode('finishScan', finishScanNode)
  .addEdge('__start__', 'loadScanContext')
  .addConditionalEdges('loadScanContext', routeScanAfterLoad, {
    selectScanWork: 'selectScanWork',
    finishScan: 'finishScan',
  })
  .addEdge('selectScanWork', 'publishScanAgentPosts')
  .addEdge('publishScanAgentPosts', 'publishScanReplies')
  .addEdge('publishScanReplies', 'finishScan')
  .addEdge('finishScan', END);

const scanGraph = scanWorkflow.compile();

async function runAutonomousDiscussionScanGraph(
  options: DiscussionOptions,
  onPublishStarted?: () => void,
): Promise<ScanResult> {
  const finalState = await scanGraph.invoke({ options, publishStartedCallback: onPublishStarted });
  return finalState.result ?? emptyScanResult();
}

export async function runAutonomousDiscussionScan(options: {
  force?: boolean;
} = {}): Promise<ScanResult> {
  if (process.env.AGENT_GRAPH_DISCUSSION_SCAN_ENABLED === 'true') {
    let publishStarted = false;
    try {
      return await runAutonomousDiscussionScanGraph(options, () => {
        publishStarted = true;
      });
    } catch (error) {
      console.error('[discussion-scan:graph] failed', { publishStarted, error });
      if (!publishStarted) return await runLegacyAutonomousDiscussionScan(options);
      return emptyScanResult();
    }
  }
  return await runLegacyAutonomousDiscussionScan(options);
}
