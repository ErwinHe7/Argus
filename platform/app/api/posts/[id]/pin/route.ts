import { NextResponse } from 'next/server';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { pinPost, unpinPost } from '@/lib/store';

export const runtime = 'nodejs';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  const { pin } = await req.json().catch(() => ({ pin: true }));
  const ok = pin ? await pinPost(params.id) : await unpinPost(params.id);
  return NextResponse.json({ ok });
}
