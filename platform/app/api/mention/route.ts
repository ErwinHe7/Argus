import { NextResponse } from 'next/server';
import { z } from 'zod';
import { AGENTS, getAgent } from '@/lib/agents';
import { chat, chatWithUsage } from '@/lib/llm';
import { cleanAgentReply, isNonAnswerReply } from '@/lib/agent-output';
import { createReply, getPost, listListings } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';
import { formatCents } from '@/lib/format';
import type { Listing } from '@/lib/types';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 45;

const Input = z.object({
  post_id: z.string().uuid(),
  // The comment text containing @AgentName plus user context
  comment: z.string().min(1).max(2000),
  // Optional: human reply author
  author_name: z.string().max(80).optional(),
});

// Parse "@Name" mentions from text — returns lowercase agent id or null
function parseMention(text: string): string | null {
  const m = text.match(/@([A-Za-z]+)/);
  if (!m) return null;
  const name = m[1].toLowerCase();
  // Accept both "mercer" and "Mercer"
  return AGENTS.find((a) => a.id === name || a.name.toLowerCase() === name)?.id ?? null;
}

// Mercer special power: search real listings from DB and format as structured reply
async function mercerWithListings(post_id: string, userComment: string, post_content: string): Promise<string> {
  const allListings = await listListings().catch(() => [] as Listing[]);
  const openListings = allListings.filter((l) => l.status === 'open').slice(0, 20);

  // Extract category hint from user comment + post content combined
  const combined = `${post_content} ${userComment}`.toLowerCase();
  const wantsFurniture = /furniture|desk|chair|couch|sofa|ikea|bed/.test(combined);
  const wantsElectronics = /phone|laptop|macbook|ipad|iphone|electronics/.test(combined);

  const relevant = openListings.filter((l) => {
    if (wantsFurniture && l.category === 'furniture') return true;
    if (wantsElectronics && l.category === 'electronics') return true;
    return !wantsFurniture && !wantsElectronics;
  }).slice(0, 4);

  const listingContext = relevant.length > 0
    ? `\n\nActive listings on AXIO7 right now:\n${relevant.map((l) =>
        `- "${l.title}" by ${l.seller_name} · ${formatCents(l.asking_price_cents, l.currency)}${l.location ? ` · ${l.location}` : ''} · ${l.bid_count} bids · /trade/${l.id}`
      ).join('\n')}`
    : '\n\n(No matching listings currently open on the platform.)';

  const agent = getAgent('mercer')!;
  const prompt = `A user asks: "${userComment}"

The original post context: "${post_content.slice(0, 300)}"${listingContext}

As Mercer, give a concrete deal-finding reply. If there are matching listings, mention them by name and link. If not, suggest where to look and what price to expect. Under 80 words.`;

  return chat(
    [{ role: 'system', content: agent.system_prompt }, { role: 'user', content: prompt }],
    { model: agent.model, temperature: 0.7, max_tokens: 200 }
  );
}

// Atlas special power: answer NYC-specific questions with location detail
async function atlasWithContext(post_id: string, userComment: string, post_content: string): Promise<string> {
  const agent = getAgent('atlas')!;
  const prompt = `User is asking: "${userComment}"

Post context: "${post_content.slice(0, 300)}"

As Atlas, give concrete local context with specific places, transit lines, timing, or price ranges where useful. Under 80 words.`;
  return chat(
    [{ role: 'system', content: agent.system_prompt }, { role: 'user', content: prompt }],
    { model: agent.model, temperature: 0.7, max_tokens: 200 }
  );
}

export async function POST(req: Request) {
  // Must be signed in to reply
  const user = await getCurrentUser().catch(() => null);
  if (!user?.authenticated) {
    return NextResponse.json(
      { error: 'Sign in required. Create a free account to reply.' },
      { status: 401 }
    );
  }

  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid input' }, { status: 400 });

  const { post_id, comment } = parsed.data;

  // First: save the human comment as a reply
  const post = await getPost(post_id);
  if (!post) return NextResponse.json({ error: 'post not found' }, { status: 404 });

  const humanReply = await createReply({
    post_id,
    author_kind: 'human',
    author_id: user.id,
    author_name: user.name || user.email?.split('@')[0] || 'User',
    content: comment,
    visibility: 'public',
  });

  // Then: check for @mention and dispatch the right agent
  const agentId = parseMention(comment);
  if (!agentId) {
    return NextResponse.json({ human_reply: humanReply, agent_reply: null });
  }

  const agent = getAgent(agentId);
  if (!agent) {
    return NextResponse.json({ human_reply: humanReply, agent_reply: null });
  }

  try {
    let content: string;

    // Agents with special DB-powered behaviors
    if (agentId === 'mercer') {
      content = await mercerWithListings(post_id, comment, post.content);
    } else if (agentId === 'atlas') {
      content = await atlasWithContext(post_id, comment, post.content);
    } else {
      // Generic agent with user comment as context
      const messages: { role: 'system' | 'user'; content: string }[] = [
          { role: 'system', content: agent.system_prompt },
          {
            role: 'user',
            content: `Post: "${post.content.slice(0, 300)}"\n\nA user @mentioned you and asked: "${comment}"\n\nReply directly to their question, in character. Under 70 words.`,
          },
        ];
      const primary = await chatWithUsage(messages, {
        model: agent.model,
        temperature: 0.8,
        max_tokens: agent.model?.includes('nemotron') ? 800 : 200,
      });
      content = cleanAgentReply(primary.content);

      if (isNonAnswerReply(content)) {
        const recovery = await chatWithUsage(
          [
            {
              role: 'system',
              content: `${agent.system_prompt}

Never output "No response", "topic unrelated", or any refusal placeholder. If the post is vague or outside your specialty, still give a grounded practical take.`,
            },
            {
              role: 'user',
              content: `Post: "${post.content.slice(0, 300)}"\n\nA user @mentioned you and asked: "${comment}"\n\nReply directly in under 70 words.`,
            },
          ],
          {
            model: agent.id === 'ember' ? 'openai/gpt-4o-mini' : agent.model,
            temperature: 0.7,
            max_tokens: 260,
          }
        );
        content = cleanAgentReply(recovery.content);
      }
    }

    if (isNonAnswerReply(content)) {
      throw new Error('agent returned an empty or refusal-style reply');
    }

    const agentReply = await createReply({
      post_id,
      author_kind: 'agent',
      author_name: agent.name,
      author_avatar: agent.avatar,
      agent_persona: agent.id,
      content: content.trim(),
      confidence_score: 0.85,
      visibility: 'public',
    });

    return NextResponse.json({ human_reply: humanReply, agent_reply: agentReply });
  } catch (err: any) {
    console.error('[mention] agent failed', agentId, err?.message);
    return NextResponse.json({ human_reply: humanReply, agent_reply: null, error: err?.message });
  }
}
