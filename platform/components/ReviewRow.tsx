'use client';

import { useState, useTransition } from 'react';
import { Check, X } from 'lucide-react';
import type { Post, Reply } from '@/lib/types';
import { timeAgo } from '@/lib/format';

export function ReviewRow({ reply, post }: { reply: Reply; post: Post | null }) {
  const [status, setStatus] = useState<'open' | 'approved' | 'rejected'>('open');
  const [, start] = useTransition();

  function decide(decision: 'approved' | 'rejected') {
    setStatus(decision);
    start(async () => {
      await fetch('/api/review', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reply_id: reply.id, decision }),
      }).catch(() => setStatus('open'));
    });
  }

  if (status !== 'open') {
    return (
      <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 text-xs text-ink-muted">
        Reply from <span className="font-medium">{reply.author_name}</span> — {status}.
      </div>
    );
  }

  return (
    <article className="rounded-xl border border-amber-200 bg-amber-50/40 p-4">
      {post && (
        <div className="mb-2 text-xs text-ink-muted">
          Original post by {post.author_name} · {timeAgo(post.created_at)}
          <p className="mt-1 rounded bg-white/70 p-2 text-ink">{post.content}</p>
        </div>
      )}
      <div className="flex items-start gap-3">
        <img src={reply.author_avatar ?? ''} alt="" className="h-7 w-7 rounded-full bg-white" />
        <div className="flex-1">
          <div className="text-xs">
            <span className="font-semibold">{reply.author_name}</span>{' '}
            <span className="ml-1 rounded bg-amber-200/60 px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-amber-900">
              review
            </span>{' '}
            <span className="text-ink-muted">
              · confidence {reply.confidence_score != null ? `${(reply.confidence_score * 100).toFixed(0)}%` : '—'}
            </span>
          </div>
          <p className="mt-1 whitespace-pre-wrap text-sm text-ink">{reply.content}</p>
          <div className="mt-2 flex gap-2">
            <button
              onClick={() => decide('approved')}
              className="inline-flex items-center gap-1 rounded-md bg-emerald-600 px-2.5 py-1 text-xs font-medium text-white hover:bg-emerald-500"
            >
              <Check className="h-3 w-3" /> Approve
            </button>
            <button
              onClick={() => decide('rejected')}
              className="inline-flex items-center gap-1 rounded-md bg-rose-600 px-2.5 py-1 text-xs font-medium text-white hover:bg-rose-500"
            >
              <X className="h-3 w-3" /> Reject
            </button>
          </div>
        </div>
      </div>
    </article>
  );
}
