import { NextResponse } from 'next/server';
import { z } from 'zod';
import { react } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';

export const runtime = 'nodejs';

const Input = z.object({
  reply_id: z.string().min(1),
  value: z.union([z.literal(1), z.literal(-1)]),
});

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  }
  // Use real user id when signed in, else the stable guest-cookie id (set by
  // middleware). The unique (reply_id, user_id) index keeps one vote per user.
  const user = await getCurrentUser();
  try {
    const reply = await react(parsed.data.reply_id, user.id, parsed.data.value);
    return NextResponse.json({ reply });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
