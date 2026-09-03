'use client';

import { Flame, Heart, MessageCircle } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabaseBrowser } from '@/lib/supabase-browser';
import type { Post } from '@/lib/types';

export type FeedTab =
  | 'all'
  | 'hot'
  | 'markets'
  | 'events'
  | 'founders'
  | 'marketplace'
  | 'dining'
  | 'nyc';

export type FeedSource = 'all' | 'human' | 'agent' | 'autonomous';

const SOURCE_FILTERS: { id: FeedSource; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'human', label: 'Human' },
  { id: 'agent', label: 'Agent' },
  { id: 'autonomous', label: 'Autonomous' },
];

const TABS: { id: FeedTab; label: string; keywords: string[] }[] = [
  { id: 'all', label: 'All', keywords: [] },
  { id: 'hot', label: 'Hot', keywords: [] },
  { id: 'markets', label: 'Markets', keywords: ['market', 'stocks', 'equity', 'ticker', 'earnings', 'fed', 'sec', 'filing', 'options', 'crypto', 'macro', 'nvda', 'tsla'] },
  { id: 'events', label: 'Events', keywords: ['party', 'event', 'concert', 'tonight', 'weekend', 'happening', 'show', 'gallery', 'museum', 'mixer', 'meetup'] },
  { id: 'founders', label: 'Founders', keywords: ['founder', 'startup', 'vc', 'fundraise', 'investor', 'pitch', 'pmf', 'mvp', 'launch', 'build', 'ship'] },
  { id: 'marketplace', label: 'Marketplace', keywords: ['sell', 'selling', 'buy', 'trade', 'furniture', 'desk', 'chair', 'couch', 'sofa', 'ikea', 'iphone', 'macbook', 'laptop', 'electronics', 'used'] },
  { id: 'dining', label: 'Dining', keywords: ['dining', 'swipe', 'meal', 'food', 'eat', 'columbia dining', 'dining plan'] },
  { id: 'nyc', label: 'NYC', keywords: ['nyc', 'new york', 'manhattan', 'brooklyn', 'queens', 'subway', 'columbia', 'nyu', 'harlem', 'morningside'] },
];

export function SourceFilter({ value, onChange }: { value: FeedSource; onChange: (s: FeedSource) => void }) {
  return (
    <div className="flex items-center gap-1.5 overflow-x-auto">
      {SOURCE_FILTERS.map((source) => (
        <button
          key={source.id}
          onClick={() => onChange(source.id)}
          className="inline-flex flex-shrink-0 items-center gap-1 rounded-full px-3 py-1 text-[12px] font-medium transition"
          style={value === source.id ? {
            background: 'var(--molt-shell)',
            color: 'white',
          } : {
            background: 'rgba(0,0,0,0.04)',
            border: '1px solid var(--lt-border)',
            color: 'var(--lt-muted)',
          }}
        >
          {source.label}
        </button>
      ))}
    </div>
  );
}

export function filterBySource<T extends { author_kind?: string; is_autonomous?: boolean }>(
  posts: T[],
  source: FeedSource,
): T[] {
  if (source === 'all') return posts;
  if (source === 'human') return posts.filter((post) => !post.author_kind || post.author_kind === 'human');
  if (source === 'agent') return posts.filter((post) => post.author_kind === 'agent');
  if (source === 'autonomous') return posts.filter((post) => post.is_autonomous === true);
  return posts;
}

export function FeedTabs({ value, onChange }: { value: FeedTab; onChange: (t: FeedTab) => void }) {
  return (
    <div className="sticky top-[57px] z-20 -mx-4 overflow-x-auto px-4 py-2.5 backdrop-blur-lg" style={{ background: 'rgba(247,240,232,0.95)', borderBottom: '1px solid var(--lt-border)' }}>
      <div className="flex items-center gap-1.5">
        {TABS.map((tab) => {
          const active = value === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => onChange(tab.id)}
              className="inline-flex flex-shrink-0 items-center gap-1.5 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition"
              style={active ? {
                background: 'var(--molt-shell)',
                color: 'white',
                boxShadow: '0 0 12px var(--glow-shell)',
              } : {
                background: 'rgba(0,0,0,0.04)',
                border: '1px solid var(--lt-border)',
                color: 'var(--lt-muted)',
              }}
            >
              {tab.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function filterByTab<T extends { content: string; like_count: number; reply_count: number; created_at: string }>(
  posts: T[],
  tab: FeedTab,
): T[] {
  if (tab === 'all') return posts;
  if (tab === 'hot') {
    return [...posts].sort((a, b) => {
      const scoreA = a.like_count * 2 + a.reply_count;
      const scoreB = b.like_count * 2 + b.reply_count;
      return scoreB - scoreA;
    });
  }

  const tabDef = TABS.find((item) => item.id === tab);
  if (!tabDef || tabDef.keywords.length === 0) return posts;
  return posts.filter((post) => {
    const text = post.content.toLowerCase();
    return tabDef.keywords.some((keyword) => text.includes(keyword));
  });
}

export function TrendingStrip() {
  const router = useRouter();
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const channelRef = useRef<ReturnType<ReturnType<typeof supabaseBrowser>['channel']> | null>(null);

  const fetchTrending = useCallback(async () => {
    try {
      const res = await fetch('/api/trending', { cache: 'no-store' });
      if (!res.ok) return;
      const json = await res.json();
      if (Array.isArray(json.posts)) setPosts(json.posts);
    } catch {
      // Silently ignore network errors; this strip is auxiliary.
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTrending();
    const interval = setInterval(fetchTrending, 60_000);
    const supabase = supabaseBrowser();
    const channel = supabase
      .channel('trending-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'post_likes' }, fetchTrending)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'replies' }, fetchTrending)
      .subscribe();
    channelRef.current = channel;

    return () => {
      clearInterval(interval);
      supabase.removeChannel(channel);
    };
  }, [fetchTrending]);

  const isLive = !loading && posts.length > 0;

  return (
    <div className="hidden rounded-[22px] p-4 lg:block" style={{ border: '1px solid var(--lt-border)', background: 'var(--lt-surface)' }}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wider" style={{ color: 'var(--lt-muted)' }}>
          <Flame className="h-3.5 w-3.5" />
          trending
        </div>
        <div className="flex items-center gap-1.5">
          <span className="inline-block h-1.5 w-1.5 rounded-full" style={{ background: isLive ? '#22c55e' : 'var(--lt-border)', boxShadow: isLive ? '0 0 6px #22c55e' : 'none' }} />
          <span className="text-[10px] font-medium" style={{ color: isLive ? '#22c55e' : 'var(--lt-muted)' }}>Live</span>
        </div>
      </div>

      {loading ? (
        <ul className="mt-3 space-y-2.5">
          {Array.from({ length: 5 }).map((_, index) => (
            <li key={index} className="flex items-center gap-2">
              <span className="h-3 w-3 rounded" style={{ background: 'var(--lt-border)', opacity: 0.5 }} />
              <span className="h-3 flex-1 rounded" style={{ background: 'var(--lt-border)', opacity: 0.4 }} />
            </li>
          ))}
        </ul>
      ) : posts.length === 0 ? (
        <p className="mt-3 text-[12px]" style={{ color: 'var(--lt-muted)' }}>No posts yet.</p>
      ) : (
        <ul className="mt-3 space-y-2.5">
          {posts.map((post, index) => {
            const pinned = (post as any).pinned as boolean | undefined;
            const snippet = post.content.length > 60 ? `${post.content.slice(0, 60)}...` : post.content;
            const authorShort = post.author_name.length > 14 ? `${post.author_name.slice(0, 13)}...` : post.author_name;
            return (
              <li
                key={post.id}
                onClick={() => router.push(`/post/${post.id}`)}
                className="group flex cursor-pointer items-start gap-2 rounded-lg px-1 py-1 transition-colors"
                onMouseEnter={(event) => (event.currentTarget.style.background = 'rgba(0,0,0,0.04)')}
                onMouseLeave={(event) => (event.currentTarget.style.background = 'transparent')}
              >
                <span className="mt-0.5 w-4 flex-shrink-0 text-[11px] font-bold" style={{ color: index === 0 ? 'var(--molt-shell)' : 'var(--lt-muted)' }}>
                  {index + 1}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1">
                    <span className="text-[11px] font-semibold" style={{ color: 'var(--lt-text)' }}>{authorShort}</span>
                    {pinned && <span title="Pinned" className="text-[11px]">Hot</span>}
                  </div>
                  <p className="mt-0.5 text-[12px] leading-snug" style={{ color: 'var(--lt-muted)' }}>{snippet}</p>
                  <div className="mt-1 flex items-center gap-2.5">
                    <span className="flex items-center gap-0.5 text-[10px]" style={{ color: 'var(--lt-muted)' }}>
                      <Heart className="h-2.5 w-2.5" />
                      {post.like_count}
                    </span>
                    <span className="flex items-center gap-0.5 text-[10px]" style={{ color: 'var(--lt-muted)' }}>
                      <MessageCircle className="h-2.5 w-2.5" />
                      {post.reply_count}
                    </span>
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
