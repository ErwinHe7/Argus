import { NextResponse } from 'next/server';
import { z } from 'zod';
import { listAllReviewReplies, resolveReview } from '@/lib/store';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

async function requireAdmin() {
  const user = await getCurrentUser();
  return user.authenticated && isAdmin(user);
}

export async function GET() {
  if (!(await requireAdmin())) return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  const replies = await listAllReviewReplies();
  return NextResponse.json({ replies });
}

const Input = z.object({
  reply_id: z.string().min(1),
  decision: z.enum(['approved', 'rejected']),
});

export async function POST(req: Request) {
  if (!(await requireAdmin())) return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  try {
    await resolveReview(parsed.data.reply_id, parsed.data.decision);
    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
