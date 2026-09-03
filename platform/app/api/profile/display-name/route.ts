import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { getDisplayName, setDisplayName } from '@/lib/store';

export const runtime = 'nodejs';

export async function GET() {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ displayName: null });
  const displayName = await getDisplayName(user.id);
  return NextResponse.json({ displayName });
}

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'not authenticated' }, { status: 401 });
  const { displayName } = await req.json().catch(() => ({}));
  if (!displayName || typeof displayName !== 'string' || displayName.trim().length === 0) {
    return NextResponse.json({ error: 'invalid name' }, { status: 400 });
  }
  const trimmed = displayName.trim().slice(0, 40);
  await setDisplayName(user.id, trimmed);
  return NextResponse.json({ ok: true, displayName: trimmed });
}
