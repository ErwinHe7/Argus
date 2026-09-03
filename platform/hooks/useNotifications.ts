'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { Notification } from '@/lib/types';

export function useNotifications(authenticated: boolean) {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unread, setUnread] = useState(0);
  const channelRef = useRef<any>(null);

  const fetchAll = useCallback(async () => {
    if (!authenticated) return;
    try {
      const res = await fetch('/api/notifications');
      if (!res.ok) return;
      const data = await res.json();
      setNotifications(data.notifications ?? []);
      setUnread(data.unread ?? 0);
    } catch {}
  }, [authenticated]);

  // Initial fetch
  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  // Supabase realtime subscription for new notifications
  useEffect(() => {
    if (!authenticated) return;
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anon) return;

    import('../lib/supabase-browser').then(({ supabaseBrowser }) => {
      const sb = supabaseBrowser();

      // We can't filter by user_id server-side in client realtime without RLS,
      // so we fetch fresh list on any notification insert and let the API filter.
      const channel = sb
        .channel('notifications')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, () => {
          fetchAll();
        })
        .subscribe();

      channelRef.current = channel;
    });

    return () => {
      channelRef.current?.unsubscribe();
    };
  }, [authenticated, fetchAll]);

  const markRead = useCallback(async (id: string) => {
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n))
    );
    setUnread((c) => Math.max(0, c - 1));
    await fetch(`/api/notifications/${id}/read`, { method: 'POST' });
  }, []);

  const markAllRead = useCallback(async () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    setUnread(0);
    await fetch('/api/notifications', { method: 'POST' });
  }, []);

  return { notifications, unread, markRead, markAllRead };
}
