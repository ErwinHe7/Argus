'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import type { Post, Reply } from '@/lib/types';
import { PostCard } from './PostCard';
import { FeedTabs, filterByTab, filterBySource, SourceFilter, type FeedTab, type FeedSource } from './FeedTabs';

/**
 * Wraps the initial SSR-rendered post list and subscribes to Supabase Realtime.
 * New posts slide in at the top; new replies and likes refresh the affected card.
 *
 * Falls back gracefully when Supabase env vars are missing (demo mode).
 */
export function FeedRealtime({
  initialPosts,
  initialReplies,
  userId,
  isAdmin,
}: {
  initialPosts: Post[];
  initialReplies: Reply[][];
  userId?: string;
  isAdmin?: boolean;
}) {
  const [posts, setPosts] = useState(initialPosts);
  const [repliesMap, setRepliesMap] = useState<Record<string, Reply[]>>(() => {
    const m: Record<string, Reply[]> = {};
    initialPosts.forEach((p, i) => { m[p.id] = initialReplies[i] ?? []; });
    return m;
  });
  const [newPostIds, setNewPostIds] = useState<Set<string>>(new Set());
  const [tab, setTab] = useState<FeedTab>('all');
  const [source, setSource] = useState<FeedSource>('all');
  // Show sticky prompt for new users — always false on server to avoid hydration mismatch
  const [showFirstPostPrompt, setShowFirstPostPrompt] = useState(false);
  useEffect(() => {
    try {
      if (localStorage.getItem('axio7_onboarded_v1') === '1' && !localStorage.getItem('axio7_first_post_done')) {
        setShowFirstPostPrompt(true);
      }
    } catch { /* ignore */ }
  }, []);
  const channelRef = useRef<ReturnType<ReturnType<typeof import('../lib/supabase-browser').supabaseBrowser>['channel']> | null>(null);

  useEffect(() => {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anon) return;

    import('../lib/supabase-browser').then(({ supabaseBrowser }) => {
      const sb = supabaseBrowser();

      const channel = sb
        .channel('feed')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, (payload) => {
          const newPost = payload.new as Post & { images?: string[] };
          const p: Post = { ...newPost, images: newPost.images ?? [] };
          setPosts((prev) => {
            if (prev.some((x) => x.id === p.id)) return prev;
            setNewPostIds((s) => new Set(s).add(p.id));
            setRepliesMap((m) => ({ ...m, [p.id]: [] }));
            setTimeout(() => setNewPostIds((s) => { const next = new Set(s); next.delete(p.id); return next; }), 700);
            return [p, ...prev];
          });
        })
        .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'posts' }, (payload) => {
          const deletedPost = payload.old as { id?: string };
          if (!deletedPost.id) return;
          setPosts((prev) => prev.filter((p) => p.id !== deletedPost.id));
          setRepliesMap((prev) => {
            const next = { ...prev };
            delete next[deletedPost.id!];
            return next;
          });
        })
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'replies' }, (payload) => {
          const reply = payload.new as Reply;
          setRepliesMap((m) => {
            const existing = m[reply.post_id] ?? [];
            if (existing.some((r) => r.id === reply.id)) return m;
            return { ...m, [reply.post_id]: [...existing, reply] };
          });
          setPosts((prev) =>
            prev.map((p) =>
              p.id === reply.post_id ? { ...p, reply_count: p.reply_count + 1 } : p
            )
          );
        })
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'post_likes' }, (payload) => {
          const like = payload.new as { post_id: string };
          setPosts((prev) =>
            prev.map((p) => p.id === like.post_id ? { ...p, like_count: p.like_count + 1 } : p)
          );
        })
        .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'post_likes' }, (payload) => {
          const like = payload.old as { post_id: string };
          setPosts((prev) =>
            prev.map((p) => p.id === like.post_id ? { ...p, like_count: Math.max(0, p.like_count - 1) } : p)
          );
        })
        .subscribe();

      channelRef.current = channel;
    });

    return () => {
      channelRef.current?.unsubscribe();
    };
  }, []);

  // Listen for posts submitted by THIS client so they appear instantly
  useEffect(() => {
    function handleNewPost(e: Event) {
      const post = (e as CustomEvent<Post>).detail;
      if (!post) return;
      setPosts((prev) => {
        if (prev.some((x) => x.id === post.id)) return prev;
        setNewPostIds((s) => new Set(s).add(post.id));
        setRepliesMap((m) => ({ ...m, [post.id]: [] }));
        setTimeout(() => setNewPostIds((s) => { const next = new Set(s); next.delete(post.id); return next; }), 700);
        return [post, ...prev];
      });
      // Mark first post done, hide prompt
      try { localStorage.setItem('axio7_first_post_done', '1'); } catch { /* ignore */ }
      setShowFirstPostPrompt(false);
    }
    window.addEventListener('axio7:new-post', handleNewPost);
    return () => window.removeEventListener('axio7:new-post', handleNewPost);
  }, []);

  const visible = useMemo(
    () => filterBySource(filterByTab(posts, tab), source),
    [posts, tab, source]
  );

  return (
    <div>
      <FeedTabs value={tab} onChange={setTab} />

      {/* Source filter row */}
      <div className="mt-2 px-0.5">
        <SourceFilter value={source} onChange={setSource} />
      </div>

      {/* Post-onboarding sticky prompt for new users */}
      {showFirstPostPrompt && (
        <div
          className="mt-3 flex items-center justify-between gap-3 rounded-[18px] px-4 py-3"
          style={{ background: 'rgba(216,71,39,0.07)', border: '1px solid rgba(216,71,39,0.2)' }}
        >
          <p className="text-sm font-medium" style={{ color: 'var(--molt-shell)' }}>
            🚀 Post your first question — get 7 AI perspectives in ~30s
          </p>
          <button
            onClick={() => {
              try { localStorage.setItem('axio7_first_post_done', '1'); } catch { /* ignore */ }
              setShowFirstPostPrompt(false);
            }}
            className="flex-shrink-0 text-[11px] opacity-50 hover:opacity-80 transition"
            style={{ color: 'var(--lt-muted)' }}
          >
            ✕
          </button>
        </div>
      )}

      <div className="mt-4 space-y-4">
        {visible.length === 0 ? (
          <div className="rounded-[22px] border border-dashed border-slate-300 bg-white/60 p-10 text-center text-sm text-ink-muted">
            No {source !== 'all' ? source + ' ' : ''}posts in <span className="font-medium">{tab}</span> yet.
          </div>
        ) : (
          visible.map((post) => (
            <div
              key={post.id}
              className={newPostIds.has(post.id) ? 'animate-slide-in' : ''}
            >
              <PostCard
                post={post}
                replies={repliesMap[post.id] ?? []}
                canDelete={isAdmin || (!!userId && post.author_id === userId)}
                canPin={isAdmin}
              />
            </div>
          ))
        )}
      </div>
    </div>
  );
}
