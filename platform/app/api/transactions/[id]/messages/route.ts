import { NextResponse } from 'next/server';
import { z } from 'zod';
import { canAccessTransaction, createMessage, listMessages } from '@/lib/store';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(_req: Request, { params }: { params: { id: string } }) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'sign in required' }, { status: 401 });
  const allowed = await canAccessTransaction(params.id, user.id, isAdmin(user));
  if (!allowed) return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  const messages = await listMessages(params.id);
  return NextResponse.json({ messages });
}

const Input = z.object({
  content: z.string().min(1).max(2000),
});

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  try {
    const user = await getCurrentUser();
    if (!user.authenticated) return NextResponse.json({ error: 'sign in required' }, { status: 401 });
    const allowed = await canAccessTransaction(params.id, user.id, isAdmin(user));
    if (!allowed) return NextResponse.json({ error: 'forbidden' }, { status: 403 });
    const message = await createMessage({
      transaction_id: params.id,
      sender_id: user.id,
      sender_name: user.name,
      content: parsed.data.content,
    });
    return NextResponse.json({ message });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
