import type { AgentPersona, Reply, Post } from './types';
import { chat } from './llm';
import { pickAgent } from './agents';
import { searchRelevant, upsertChunk } from './knowledge';
import { createReply, enqueueReview, getPost, listReplies } from './store';

// Multi-stage agent pipeline.
// Node order: loadContext → retrieveContext → pickAgent → draft → moderate → critique → persist
// Ported from agent-human-network/apps/worker/app/graphs/brief_generation.py (7-node LangGraph)
// but TypeScript-native, no Python/LangChain required.

type PipelineState = {
  post: Post;
  agent: AgentPersona;
  retrievedContext: string[];
  previousReplies: string[];
  draft: string;
  critiqueNotes: string;
  confidenceScore: number;
  moderationFlag: string | null;
  publishDecision: 'public' | 'review' | 'hidden';
};

const MODERATION_BLOCKLIST = [
  /\bnigg/i, /\bfag/i, /kill yourself/i, /kys/i, /\brape\b/i, /\bchink/i,
];
const MODERATION_SOFT_FLAGS = [
  /suicide/i, /self-harm/i, /overdose/i,
];

async function loadContextNode(postId: string): Promise<Pick<PipelineState, 'post' | 'previousReplies'>> {
  const post = await getPost(postId);
  if (!post) throw new Error(`post ${postId} not found`);
  const replies = await listReplies(postId);
  return {
    post,
    previousReplies: replies.slice(-3).map((r) => `${r.author_name}: ${r.content}`),
  };
}

async function retrieveContextNode(post: Post): Promise<string[]> {
  const query = post.content.slice(0, 500);
  return searchRelevant(query, 3);
}

function pickAgentNode(post: Post): AgentPersona {
  return pickAgent(post.content);
}

function buildDraftPrompt(state: Pick<PipelineState, 'post' | 'agent' | 'retrievedContext' | 'previousReplies'>): string {
  const ctx = state.retrievedContext.length
    ? `\n\nRelated context from AXIO7 (use only if genuinely useful):\n${state.retrievedContext.map((c) => `- ${c}`).join('\n')}`
    : '';
  const prev = state.previousReplies.length
    ? `\n\nPrevious replies on this post (don't repeat them):\n${state.previousReplies.join('\n')}`
    : '';
  const subs = state.agent.sub_agents?.length
    ? `\n\nAs ${state.agent.name}, you have these internal sub-agents to satisfy before replying:\n${state.agent.sub_agents.map((s) => `- ${s.name}: ${s.responsibility}`).join('\n')}`
    : '';
  return `A user posted on AXIO7:\n\n"""\n${state.post.content}\n"""${ctx}${prev}${subs}\n\nWrite your reply as ${state.agent.name}. Stay in character.`;
}

async function draftNode(state: PipelineState): Promise<string> {
  const draft = await chat(
    [
      { role: 'system', content: state.agent.system_prompt },
      { role: 'user', content: buildDraftPrompt(state) },
    ],
    { temperature: 0.85, max_tokens: 280 }
  );
  return draft.trim();
}

function moderationNode(draft: string): string | null {
  for (const rx of MODERATION_BLOCKLIST) if (rx.test(draft)) return 'blocked: profanity/slur';
  for (const rx of MODERATION_SOFT_FLAGS) if (rx.test(draft)) return 'soft: self-harm topic — route to Ember + review';
  if (draft.length < 15) return 'soft: too short to be useful';
  return null;
}

async function critiqueNode(state: PipelineState): Promise<{ score: number; notes: string }> {
  const critiqueSystem = `You are a strict reviewer. Given a user's post and an AI-drafted reply, score how useful the reply is on a 0.0-1.0 scale based on: specificity, relevance, honesty, and safety. Respond ONLY as compact JSON: {"score": 0.0, "notes": "one short sentence"}.`;
  const critiqueUser = `POST: """${state.post.content}"""\n\nDRAFT: """${state.draft}"""\n\nScore it.`;
  try {
    const raw = await chat(
      [
        { role: 'system', content: critiqueSystem },
        { role: 'user', content: critiqueUser },
      ],
      { temperature: 0.2, max_tokens: 120 }
    );
    // Strip any code fence.
    const cleaned = raw.replace(/```json\s*/i, '').replace(/```$/i, '').trim();
    const match = cleaned.match(/\{[\s\S]*\}/);
    const parsed = match ? JSON.parse(match[0]) : { score: 0.7, notes: 'no parse' };
    const score = Math.max(0, Math.min(1, Number(parsed.score) || 0.7));
    return { score, notes: String(parsed.notes ?? '').slice(0, 200) };
  } catch {
    // If critique fails, default to mid-confidence so we don't block the reply.
    return { score: 0.7, notes: 'critique unavailable' };
  }
}

function confidenceNode(state: PipelineState): 'public' | 'review' | 'hidden' {
  if (state.moderationFlag?.startsWith('blocked')) return 'hidden';
  if (state.moderationFlag?.startsWith('soft')) return 'review';
  if (state.confidenceScore >= 0.6) return 'public';
  if (state.confidenceScore >= 0.3) return 'review';
  return 'hidden';
}

async function persistNode(state: PipelineState): Promise<Reply> {
  const reply = await createReply({
    post_id: state.post.id,
    author_kind: 'agent',
    author_name: state.agent.name,
    author_avatar: state.agent.avatar,
    agent_persona: state.agent.id,
    content: state.draft,
    confidence_score: Number(state.confidenceScore.toFixed(2)),
    visibility: state.publishDecision,
  });
  if (state.publishDecision === 'review') {
    const reason = state.moderationFlag || `low confidence ${state.confidenceScore.toFixed(2)}`;
    await enqueueReview(reply.id, reason);
  }
  if (state.publishDecision === 'public') {
    // Feed the reply into the knowledge base for future retrieval.
    await upsertChunk({
      source_kind: 'reply',
      source_id: reply.id,
      content: `${state.agent.name} on "${state.post.content.slice(0, 80)}": ${state.draft.slice(0, 300)}`,
    });
  }
  return reply;
}

export async function runAgentPipeline(postId: string): Promise<Reply> {
  const { post, previousReplies } = await loadContextNode(postId);
  const retrievedContext = await retrieveContextNode(post);
  const agent = pickAgentNode(post);

  const initialState: PipelineState = {
    post,
    agent,
    retrievedContext,
    previousReplies,
    draft: '',
    critiqueNotes: '',
    confidenceScore: 0,
    moderationFlag: null,
    publishDecision: 'public',
  };

  initialState.draft = await draftNode(initialState);
  initialState.moderationFlag = moderationNode(initialState.draft);
  const critique = await critiqueNode(initialState);
  initialState.confidenceScore = critique.score;
  initialState.critiqueNotes = critique.notes;
  initialState.publishDecision = confidenceNode(initialState);

  // Also upsert the post itself as a chunk for future agent retrieval.
  await upsertChunk({
    source_kind: 'post',
    source_id: post.id,
    content: `${post.author_name} posted: ${post.content}`,
  });

  return persistNode(initialState);
}
