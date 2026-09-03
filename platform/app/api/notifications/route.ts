import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { listNotifications, getUnreadCount, markAllNotificationsRead } from '@/lib/store';

export const runtime = 'nodejs';

export async function GET() {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ notifications: [], unread: 0 });
  const [notifications, unread] = await Promise.all([
    listNotifications(user.id),
    getUnreadCount(user.id),
  ]);
  return NextResponse.json({ notifications, unread });
}

export async function POST() {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ ok: false });
  await markAllNotificationsRead(user.id);
  return NextResponse.json({ ok: true });
}
