import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { markNotificationRead } from '@/lib/store';

export const runtime = 'nodejs';

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ ok: false });
  await markNotificationRead(params.id, user.id);
  return NextResponse.json({ ok: true });
}
