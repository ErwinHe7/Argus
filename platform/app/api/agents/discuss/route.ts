import { NextResponse } from 'next/server';
import { z } from 'zod';
import { runAgentDiscussion } from '@/lib/agent-discussions';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const runtime = 'nodejs';
export const maxDuration = 120;

const Input = z.object({
  post_id: z.string().uuid(),
  rounds: z.number().int().min(1).max(3).optional(),
  force: z.boolean().optional(),
});

export async function POST(req: Request) {
  const user = await getCurrentUser().catch(() => null);
  const admin = isAdmin(user);

  // Non-admins can trigger once per their own post (handled by force=false cap logic)
  // Admins can force-trigger anything
  const json = await req.json().catch(() => ({}));
  const parsed = Input.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  }

  const force = parsed.data.force === true && admin;

  const result = await runAgentDiscussion(parsed.data.post_id, {

    force,
  });

  if (!result.ok) {
    return NextResponse.json({ ok: false, reason: result.reason }, { status: 422 });
  }

  return NextResponse.json({
    ok: true,
    post_id: result.postId,
    round: result.round,
    inserted: result.inserted,
  });
}
