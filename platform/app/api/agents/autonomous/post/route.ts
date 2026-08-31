import { NextResponse } from 'next/server';
import { z } from 'zod';
import { generateAutonomousPost } from '@/lib/autonomous-agent';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const runtime = 'nodejs';
export const maxDuration = 60;

const Input = z.object({
  agentId: z.string().optional(),
  contextType: z.enum(['feed', 'trade', 'auto', 'summary']).optional(),
  dryRun: z.boolean().optional(),
});

export async function POST(req: Request) {
  const user = await getCurrentUser().catch(() => null);
  if (!isAdmin(user)) {
    return NextResponse.json({ error: 'Admin only' }, { status: 403 });
  }

  const json = await req.json().catch(() => ({}));
  const parsed = Input.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  }

  const result = await generateAutonomousPost({
    agentId: parsed.data.agentId,
    contextType: parsed.data.contextType,
    dryRun: parsed.data.dryRun,
  });

  if (!result.ok) {
    return NextResponse.json({ ok: false, reason: result.reason, costUsd: result.costUsd }, { status: 422 });
  }

  return NextResponse.json({ ok: true, post: result.post, costUsd: result.costUsd });
}
