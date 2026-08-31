'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { Loader2, Send, ImagePlus, X, Sparkles } from 'lucide-react';
import { AGENTS, extractMentionedAgentId } from '@/lib/agents';
import { supabaseBrowser } from '@/lib/supabase-browser';
import { trackPostCreated } from '@/components/PostHogProvider';

type UploadedImage = { url: string; preview: string };

const QUICK_CHIPS = [
  { label: 'Market catalyst check', text: 'Watching NVDA and TSLA today. Which public catalysts are actually moving the tape?' },
  { label: 'NYC this weekend?', text: "What's happening in NYC this weekend? Events, parties, anything fun?" },
  { label: 'Connect with founders', text: 'Looking to connect with NYC founders working on interesting problems. Who should I meet?' },
  { label: 'Macro debate', text: 'How are people thinking about rates, AI capex, and crypto beta this week?' },
];

export function PostComposer() {
  const searchParams = useSearchParams();
  const prefill = searchParams.get('prefill') ?? '';
  const [content, setContent] = useState(prefill);
  const [name, setName] = useState('');
  const [userId, setUserId] = useState<string | null>(null);
  const [eduVerified, setEduVerified] = useState(false);
  const [mode, setMode] = useState<'post' | 'ask'>('post');
  const [postError, setPostError] = useState<string | null>(null);

  // Pre-fill name from Supabase session if signed in
  useEffect(() => {
    supabaseBrowser().auth.getUser().then(({ data }) => {
      const u = data?.user;
      if (u) {
        const meta = u.user_metadata ?? {};
        const realName = (meta.full_name as string) || (meta.name as string) || u.email?.split('@')[0] || '';
        if (realName) setName(realName);
        setUserId(u.id);
        setEduVerified(Boolean(u.email?.toLowerCase().endsWith('.edu')));
      }
    }).catch(() => {});
  }, []);
  const [images, setImages] = useState<UploadedImage[]>([]);
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [focused, setFocused] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function uploadFiles(files: File[]) {
    const remaining = 4 - images.length;
    if (remaining <= 0) return;
    const batch = files.slice(0, remaining);
    setUploading(true);
    try {
      await Promise.all(
        batch.map(async (file) => {
          const preview = URL.createObjectURL(file);
          const fd = new FormData();
          fd.append('file', file);
          const res = await fetch('/api/upload', { method: 'POST', body: fd });
          if (!res.ok) return;
          const { url } = await res.json();
          setImages((prev) => [...prev, { url, preview }]);
        })
      );
    } finally {
      setUploading(false);
    }
  }

  function handleFileInput(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []).filter((f) => f.type.startsWith('image/'));
    if (files.length) uploadFiles(files);
    e.target.value = '';
  }

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setDragOver(false);
      const files = Array.from(e.dataTransfer.files).filter((f) => f.type.startsWith('image/'));
      if (files.length) uploadFiles(files);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [images]
  );

  function removeImage(idx: number) {
    setImages((prev) => {
      URL.revokeObjectURL(prev[idx].preview);
      return prev.filter((_, i) => i !== idx);
    });
  }

  // Detect @mention in the current textarea content
  const mentionedAgentId = extractMentionedAgentId(content);
  const mentionedAgent = mentionedAgentId ? AGENTS.find((a) => a.id === mentionedAgentId) ?? null : null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!content.trim() || submitting) return;

    // Ask mode: redirect to /ask page with query pre-filled
    if (mode === 'ask') {
      window.location.href = `/ask?q=${encodeURIComponent(content.trim())}`;
      return;
    }

    // Must be signed in to post
    if (!userId) {
      window.location.href = `/auth/signin?next=${encodeURIComponent(window.location.pathname)}`;
      return;
    }

    setSubmitting(true);
    setPostError(null);
    try {
      const res = await fetch('/api/posts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          author_name: eduVerified ? `${name.trim() || 'Verified Student'} · EDU verified` : name.trim() || undefined,
          content: content.trim(),
          images: images.map((i) => i.url),
        }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error ?? `Post failed (${res.status})`);
      }
      const { post } = await res.json();
      trackPostCreated({
        user_id: userId ?? post.author_id,
        post_id: post.id,
        post_length: content.trim().length,
        has_image: images.length > 0,
      });
      setContent('');
      setImages([]);
      // Notify FeedRealtime directly — no router.refresh() to avoid state reset
      window.dispatchEvent(new CustomEvent('axio7:new-post', { detail: post }));
      fetch('/api/fanout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ post_id: post.id, ...(mentionedAgentId ? { mention: mentionedAgentId } : {}) }),
      }).catch(() => {});
    } catch (err: any) {
      setPostError(err?.message ?? 'Failed to post. Please try again.');
    } finally {
      setSubmitting(false);
    }
  }

  const gridClass =
    images.length === 1
      ? 'grid-cols-1'
      : images.length === 2
      ? 'grid-cols-2'
      : images.length === 3
      ? 'grid-cols-3'
      : 'grid-cols-2';

  const expanded = focused || content.length > 0 || images.length > 0;

  function fillChip(text: string) {
    setContent(text);
    setFocused(true);
  }

  return (
    <form
      onSubmit={submit}
      className="rounded-[24px] p-5 transition-all sm:p-6"
      style={{
        background: 'var(--lt-surface)',
        border: `1px solid ${expanded ? 'rgba(216,71,39,0.4)' : 'var(--lt-border)'}`,
        boxShadow: expanded ? '0 0 0 3px rgba(216,71,39,0.12)' : '0 2px 8px rgba(0,0,0,0.06)',
      }}
    >
      {/* Post / Ask mode toggle */}
      <div className="mb-3 flex gap-1 rounded-xl p-0.5 w-fit" style={{ background: 'rgba(0,0,0,0.06)' }}>
        {(['post', 'ask'] as const).map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => setMode(m)}
            className="rounded-lg px-3 py-1 text-xs font-semibold capitalize transition"
            style={mode === m
              ? { background: 'white', color: 'var(--lt-text)', boxShadow: '0 1px 3px rgba(0,0,0,0.12)' }
              : { color: 'var(--lt-muted)' }
            }
          >
            {m}
          </button>
        ))}
      </div>

      {/* Quick suggestion chips */}
      {!expanded && (
        <div className="mb-3 flex flex-wrap gap-1.5">
          {QUICK_CHIPS.map((c) => (
            <button
              key={c.label}
              type="button"
              onClick={() => fillChip(c.text)}
              className="rounded-full px-3 py-1 text-[11px] font-medium transition hover:opacity-80"
              style={{ background: 'rgba(216,71,39,0.07)', border: '1px solid rgba(216,71,39,0.18)', color: 'var(--molt-shell)' }}
            >
              {c.label}
            </button>
          ))}
        </div>
      )}

      <div className="flex items-start gap-3">
        <span className="inline-flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-full bg-[var(--molt-coral)]/30 text-xs font-black italic" style={{ fontFamily: 'var(--font-fraunces)', color: 'var(--molt-sand)' }}>
          AX7
        </span>
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Your name"
              className="min-w-0 flex-1 border-none bg-transparent text-xs font-medium focus:outline-none"
              style={{ color: name ? 'var(--lt-text)' : 'var(--lt-subtle)', caretColor: 'var(--molt-shell)' }}
            />
            {eduVerified && (
              <span className="rounded-full border border-emerald-300/30 bg-emerald-300/10 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-emerald-200">
                EDU verified
              </span>
            )}
          </div>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            rows={expanded ? 4 : 2}
            placeholder={mode === 'ask' ? 'Ask anything — only you see the answer.' : 'Post something.'}
            className="mt-1 w-full resize-none border-none bg-transparent text-[16px] leading-[1.6] focus:outline-none"
            style={{ color: 'var(--lt-text)', caretColor: 'var(--molt-shell)' }}
          />
        </div>
      </div>

      {images.length > 0 && (
        <div className={`mt-3 grid gap-1.5 pl-14 ${gridClass}`}>
          {images.map((img, i) => (
            <div key={img.url} className="relative">
              <img
                src={img.preview}
                alt=""
                className={`w-full rounded-xl border border-slate-100 object-cover ${images.length === 1 ? 'max-h-64' : 'h-28'}`}
              />
              <button
                type="button"
                onClick={() => removeImage(i)}
                className="absolute right-1 top-1 inline-flex h-6 w-6 items-center justify-center rounded-full bg-black/60 text-white"
              >
                <X className="h-3 w-3" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Agent preview strip */}
      {expanded && (
        <div className="mt-4 border-t pt-3" style={{ borderColor: 'var(--lt-border)' }}>
          <div className="flex items-center gap-2">
            <Sparkles className="h-3.5 w-3.5" style={{ color: 'var(--molt-shell)' }} />
            <span className="text-[11px] font-medium uppercase tracking-wider" style={{ color: 'var(--lt-subtle)' }}>
              will reply:
            </span>
            <div className="flex -space-x-2">
              {AGENTS.map((a) => (
                <img
                  key={a.id}
                  src={a.avatar}
                  alt={a.name}
                  title={a.name}
                  className="h-6 w-6 rounded-full transition hover:z-10 hover:scale-110"
                  style={{
                    boxShadow: mentionedAgentId === a.id
                      ? '0 0 0 2.5px var(--molt-coral), 0 0 0 4px rgba(216,71,39,0.25)'
                      : '0 0 0 2px white',
                    opacity: mentionedAgentId && mentionedAgentId !== a.id ? 0.45 : 1,
                    transform: mentionedAgentId === a.id ? 'scale(1.18)' : undefined,
                    zIndex: mentionedAgentId === a.id ? 10 : undefined,
                  }}
                />
              ))}
            </div>
            <span className="text-[11px]" style={{ color: 'var(--lt-subtle)' }}>· ~30s</span>
          </div>
          {mentionedAgent && (
            <div className="mt-2 flex items-center gap-1.5">
              <span
                className="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
                style={{
                  background: 'rgba(216,71,39,0.12)',
                  color: 'var(--molt-coral)',
                  border: '1px solid rgba(216,71,39,0.3)',
                }}
              >
                <img src={mentionedAgent.avatar} alt="" className="h-3.5 w-3.5 rounded-full" />
                @{mentionedAgent.name} replies first
              </span>
            </div>
          )}
        </div>
      )}

      {postError && (
        <div className="mt-2 rounded-lg px-3 py-2 text-xs" style={{ background: 'rgba(220,38,38,0.08)', color: '#dc2626' }}>
          {postError}
        </div>
      )}

      <div className="mt-3 flex items-center justify-between border-t pt-3" style={{ borderColor: 'var(--lt-border)' }}>
        <div className="flex items-center gap-3">
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            className="sr-only"
            onChange={handleFileInput}
          />
          {images.length < 4 && (
            <button
              type="button"
              disabled={uploading}
              onClick={() => fileInputRef.current?.click()}
              onDrop={handleDrop}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              className={`inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs transition disabled:opacity-50`}
              style={{ color: dragOver ? 'var(--molt-shell)' : 'var(--lt-text)' }}
            >
              {uploading ? <Loader2 className="h-4 w-4 animate-spin" /> : <ImagePlus className="h-4 w-4" />}
              {uploading ? 'Uploading…' : 'Photo'}
            </button>
          )}
          {!expanded && (
            <span className="text-xs" style={{ color: 'var(--lt-subtle)' }}>7 models reply</span>
          )}
        </div>
        <button
          type="submit"
          disabled={!content.trim() || submitting}
          className="inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:opacity-90 active:scale-95 disabled:cursor-not-allowed disabled:opacity-40"
          style={{ background: 'var(--molt-shell)' }}
        >
          {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
          {mode === 'ask' ? 'Ask' : 'Post'}
        </button>
      </div>
    </form>
  );
}
