'use client';

import { useEffect, useRef, useState } from 'react';
import { Bell } from 'lucide-react';
import Link from 'next/link';
import { useNotifications } from '@/hooks/useNotifications';
import type { Notification } from '@/lib/types';

function timeAgo(iso: string): string {
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function typeIcon(type: Notification['type']): string {
  if (type === 'agent_reply') return '🤖';
  if (type === 'like') return '❤️';
  if (type === 'human_reply') return '💬';
  return '🔔';
}

export function BellButton({ authenticated }: { authenticated: boolean }) {
  const { notifications, unread, markRead, markAllRead } = useNotifications(authenticated);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close on outside click
  useEffect(() => {
    function handle(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener('mousedown', handle);
    return () => document.removeEventListener('mousedown', handle);
  }, []);

  if (!authenticated) return null;

  return (
    <div ref={ref} className="relative">
      {/* Bell icon button */}
      <button
        onClick={() => setOpen((v) => !v)}
        className="relative flex h-8 w-8 items-center justify-center rounded-lg transition hover:opacity-80"
        style={{ color: 'var(--molt-sand)' }}
        aria-label="Notifications"
      >
        <Bell className="h-4 w-4" />
        {unread > 0 && (
          <span
            className="absolute -right-1 -top-1 flex h-4 min-w-[1rem] items-center justify-center rounded-full px-0.5 text-[10px] font-bold text-white"
            style={{ background: 'var(--molt-shell)' }}
          >
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {/* Dropdown */}
      {open && (
        <div
          className="absolute right-0 top-10 z-50 w-80 rounded-[18px] shadow-xl overflow-hidden"
          style={{ background: 'var(--bg-surface)', border: '1px solid var(--glass-border)' }}
        >
          {/* Header */}
          <div
            className="flex items-center justify-between px-4 py-3"
            style={{ borderBottom: '1px solid var(--glass-border)' }}
          >
            <span className="text-xs font-semibold uppercase tracking-widest" style={{ color: 'var(--molt-coral)' }}>
              Notifications
            </span>
            {unread > 0 && (
              <button
                onClick={markAllRead}
                className="text-[11px] transition hover:opacity-70"
                style={{ color: 'var(--molt-coral)' }}
              >
                Mark all read
              </button>
            )}
          </div>

          {/* List */}
          <div className="max-h-80 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="px-4 py-8 text-center text-xs" style={{ color: 'rgba(247,240,232,0.35)' }}>
                No notifications yet
              </div>
            ) : (
              notifications.map((n) => (
                <NotificationRow
                  key={n.id}
                  notification={n}
                  onRead={() => {
                    markRead(n.id);
                    setOpen(false);
                  }}
                />
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function NotificationRow({
  notification: n,
  onRead,
}: {
  notification: Notification;
  onRead: () => void;
}) {
  const href = n.post_id ? `/?post=${n.post_id}#post-${n.post_id}` : '/';

  return (
    <Link
      href={href}
      onClick={onRead}
      className="flex items-start gap-3 px-4 py-3 transition hover:opacity-80"
      style={{
        borderBottom: '1px solid var(--glass-border)',
        background: n.read ? 'transparent' : 'rgba(216,71,39,0.07)',
      }}
    >
      {/* Avatar or type icon */}
      <div className="mt-0.5 flex-shrink-0">
        {n.actor_avatar ? (
          <img src={n.actor_avatar} alt="" className="h-7 w-7 rounded-full" />
        ) : (
          <span className="flex h-7 w-7 items-center justify-center rounded-full text-base"
            style={{ background: 'var(--glass)' }}>
            {typeIcon(n.type)}
          </span>
        )}
      </div>

      <div className="min-w-0 flex-1">
        <p className="text-[12px] leading-snug" style={{ color: 'var(--molt-sand)' }}>
          <span className="font-semibold">{n.actor_name}</span>{' '}
          {n.type === 'agent_reply' && 'replied to your post'}
          {n.type === 'like' && 'liked your post'}
          {n.type === 'human_reply' && 'replied to your post'}
        </p>
        {n.preview && (
          <p className="mt-0.5 truncate text-[11px]" style={{ color: 'rgba(247,240,232,0.45)' }}>
            {n.preview}
          </p>
        )}
        <p className="mt-0.5 text-[10px]" style={{ color: 'rgba(247,240,232,0.28)' }}>
          {timeAgo(n.created_at)}
        </p>
      </div>

      {!n.read && (
        <span className="mt-2 h-1.5 w-1.5 flex-shrink-0 rounded-full"
          style={{ background: 'var(--molt-shell)' }} />
      )}
    </Link>
  );
}
