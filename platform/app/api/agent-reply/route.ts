import { NextResponse } from 'next/server';
import { z } from 'zod';
import { createReply, getPost, createNotification } from '@/lib/store';
import { pickAgent } from '@/lib/agents';
import { runAgentGraph } from '@/lib/agent-graph'; // LangGraph pipeline

export const runtime = 'nodejs';
export const maxDuration = 30;

const Input = z.object({ post_id: z.string().min(1) });

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  }
  const post = await getPost(parsed.data.post_id);
  if (!post) return NextResponse.json({ error: 'post not found' }, { status: 404 });

  try {
    const reply = await runAgentGraph(post.id); // uses LangGraph StateGraph
    // Notify post author (skip if author is a guest/anon)
    if (post.author_id && !post.author_id.startsWith('guest-') && post.author_id !== 'axio7-seed') {
      createNotification({
        user_id: post.author_id,
        type: 'agent_reply',
        actor_name: reply.author_name,
        actor_avatar: reply.author_avatar ?? null,
        post_id: post.id,
        preview: reply.content.slice(0, 100),
      }).catch(() => {}); // fire-and-forget
    }
    return NextResponse.json({ reply });
  } catch (err: any) {
    // Graceful fallback: create a visible placeholder so the user sees *something*
    // rather than a blank post with no reply.
    const agent = pickAgent(post.content);
    const msg = err?.message?.includes('OPENAI_API_KEY') || err?.status === 401
      ? `[${agent.name} is offline — set OPENAI_API_KEY + OPENAI_BASE_URL in Vercel env vars to enable live replies.]`
      : `[${agent.name} hit an error: ${String(err?.message ?? err).slice(0, 200)}. Check your TokenRouter model + key.]`;
    const reply = await createReply({
      post_id: post.id,
      author_kind: 'agent',
      author_name: agent.name,
      author_avatar: agent.avatar,
      agent_persona: agent.id,
      content: msg,
      confidence_score: 0,
      visibility: 'public',
    });
    return NextResponse.json({ reply, degraded: true });
  }
}
