/**
 * POST /api/subagent
 *
 * Runs a single subagent in isolation — the fine-grained reasoning unit
 * inside a parent agent. Useful for:
 *   - Debugging individual subagent behaviour
 *   - Future: @Signal, @Probe style direct mentions
 *   - Future: chaining multiple subagents across posts
 *
 * Body: { post_id, parent_agent_id, subagent_name }
 * Returns: { reply } — a Reply stored in the replies table as author_kind='agent'
 */

import { NextResponse } from 'next/server';
import { z } from 'zod';
import { getAgent } from '@/lib/agents';
import { chat } from '@/lib/llm';
import { createReply, getPost } from '@/lib/store';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 30;

const Input = z.object({
  post_id:         z.string().uuid(),
  parent_agent_id: z.string().min(1),
  subagent_name:   z.string().min(1),
});

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid input' }, { status: 400 });

  const { post_id, parent_agent_id, subagent_name } = parsed.data;

  const parentAgent = getAgent(parent_agent_id);
  if (!parentAgent) return NextResponse.json({ error: 'unknown agent' }, { status: 400 });

  const subAgent = parentAgent.sub_agents?.find(
    (s) => s.name.toLowerCase() === subagent_name.toLowerCase()
  );
  if (!subAgent) return NextResponse.json({ error: 'subagent not found on this agent' }, { status: 404 });

  const post = await getPost(post_id);
  if (!post) return NextResponse.json({ error: 'post not found' }, { status: 404 });

  try {
    const content = await chat(
      [
        {
          role: 'system',
          content: `You are ${subAgent.name}, a specialised sub-agent within ${parentAgent.name}.
Your single responsibility: ${subAgent.responsibility}
${parentAgent.system_prompt}
Focus ONLY on your specific responsibility. Be concise — under 50 words.`,
        },
        {
          role: 'user',
          content: `Post:\n"""\n${post.content}\n"""\n\nComplete your responsibility: ${subAgent.responsibility}`,
        },
      ],
      { model: parentAgent.model, temperature: 0.7, max_tokens: 150 }
    );

    const reply = await createReply({
      post_id,
      author_kind: 'agent',
      author_name: `${subAgent.name} (${parentAgent.name})`,
      author_avatar: parentAgent.avatar,
      agent_persona: parentAgent.id,
      content: content.trim(),
      confidence_score: 0.75,
      visibility: 'public',
    });

    return NextResponse.json({ reply, subagent: subAgent.name, parent: parentAgent.name });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
