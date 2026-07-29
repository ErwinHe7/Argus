'use client';

import { useEffect, useRef, useState } from 'react';
import { Loader2, Send, X } from 'lucide-react';
import { AGENTS } from '@/lib/agents';
import { supabaseBrowser } from '@/lib/supabase-browser';
import type { Reply } from '@/lib/types';

interface Props {
  postId: string;
  onReply: (human: Reply, agent: Reply | null) => void;
}

// Agent names for @mention autocomplete
const AGENT_NAMES = AGENTS.map((a) => ({ id: a.id, name: a.name, tagline: a.tagline, avatar: a.avatar }));

export function ReplyComposer({ postId, onReply }: Props) {
  const [content, setContent] = useState('');
  const [authorName, setAuthorName] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [mention, setMention] = useState<typeof AGENTS[0] | null>(null);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [suggestionQuery, setSuggestionQuery] = useState('');
  const [isLoggedIn, setIsLoggedIn] = useState<boolean | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Check auth state on mount
  useEffect(() => {
    supabaseBrowser().auth.getUser().then(({ data }) => {
      setIsLoggedIn(!!data?.user);
      if (data?.user) {
        const meta = data.user.user_metadata ?? {};
        const name = (meta.full_name as string) || (meta.name as string) || '';
        if (name) setAuthorName(name);
      }
    }).catch(() => setIsLoggedIn(false));
  }, []);

  // Parse @mention from content and show autocomplete
  useEffect(() => {
    const match = content.match(/@(\w*)$/);
    if (match) {
      setSuggestionQuery(match[1].toLowerCase());
      setShowSuggestions(true);
    } else {
      setShowSuggestions(false);
    }
    // Detect if a full @Name is in the text
    const fullMatch = content.match(/@([A-Za-z]+)/);
    if (fullMatch) {
      const found = AGENTS.find(
        (a) => a.id === fullMatch[1].toLowerCase() || a.name.toLowerCase() === fullMatch[1].toLowerCase()
      );
      setMention(found ?? null);
    } else {
      setMention(null);
    }
  }, [content]);

  const suggestions = AGENT_NAMES.filter(
    (a) =>
      suggestionQuery === '' ||
      a.name.toLowerCase().startsWith(suggestionQuery) ||
      a.id.startsWith(suggestionQuery)
  );

  function insertMention(agentName: string) {
    const updated = content.replace(/@\w*$/, `@${agentName} `);
    setContent(updated);
    setShowSuggestions(false);
    textareaRef.current?.focus();
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!content.trim() || submitting) return;

    // Must be signed in
    if (!isLoggedIn) {
      window.location.href = `/auth/signin?next=${encodeURIComponent(window.location.pathname)}`;
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch('/api/mention', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          post_id: postId,
          comment: content.trim(),
          author_name: authorName.trim() || undefined,
        }),
      });
      if (!res.ok) return;
      const { human_reply, agent_reply } = await res.json();
      setContent('');
      onReply(human_reply, agent_reply ?? null);
    } finally {
      setSubmitting(false);
    }
  }

  // Show sign-in prompt if not logged in
  if (isLoggedIn === false) {
    return (
      <div className="mt-2 flex items-center justify-between rounded-xl px-4 py-3"
        style={{ background: 'rgba(216,71,39,0.06)', border: '1px solid rgba(216,71,39,0.18)' }}>
        <p className="text-sm" style={{ color: 'var(--lt-muted)' }}>Sign in to reply</p>
        <a href={`/auth/signin?next=${encodeURIComponent(window.location.pathname)}`}
          className="rounded-full px-4 py-1.5 text-xs font-semibold text-white transition hover:opacity-90"
          style={{ background: 'var(--molt-shell)' }}>
          Sign in
        </a>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="relative mt-3 space-y-2">
      {/* Mention badge */}
      {mention && (
        <div className="flex items-center gap-2 rounded-xl bg-[var(--molt-coral)]/10 px-3 py-1.5 text-xs">
          <img src={mention.avatar} alt="" className="h-5 w-5 rounded-full" />
          <span className="font-medium text-[var(--molt-ocean)]">@{mention.name}</span>
          <span className="text-[var(--molt-ocean)]/50">{mention.tagline}</span>
          {mention.id === 'mercer' && (
            <span className="ml-auto rounded bg-[var(--molt-shell)]/10 px-1.5 py-0.5 text-[10px] font-semibold text-[var(--molt-shell)]">
              searches listings
            </span>
          )}
          {mention.id === 'atlas' && (
            <span className="ml-auto rounded bg-sky-100 px-1.5 py-0.5 text-[10px] font-semibold text-sky-700">
              nyc intel
            </span>
          )}
          <button
            type="button"
            onClick={() => { setContent(content.replace(/@[A-Za-z]+\s?/, '')); setMention(null); }}
            className="ml-auto opacity-50 hover:opacity-100"
          >
            <X className="h-3 w-3" />
          </button>
        </div>
      )}

      <div className="relative flex gap-2">
        <div className="flex-1 space-y-1">
          <input
            value={authorName}
            onChange={(e) => setAuthorName(e.target.value)}
            placeholder="Your name (optional)"
            className="w-full rounded-xl border border-[rgba(11,79,108,0.1)] bg-white/80 px-3 py-1.5 text-xs text-[var(--molt-ocean)] placeholder:text-slate-400 focus:border-[var(--molt-coral)] focus:outline-none"
          />
          <div className="relative">
            <textarea
              ref={textareaRef}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              rows={2}
              placeholder="Reply… or type @Claude, @Grok, @GPT to summon an agent"
              className="w-full resize-none rounded-xl border border-[rgba(11,79,108,0.1)] bg-white/80 px-3 py-2 text-sm text-[var(--molt-ocean)] placeholder:text-slate-400 focus:border-[var(--molt-coral)] focus:outline-none"
            />

            {/* @mention autocomplete dropdown */}
            {showSuggestions && suggestions.length > 0 && (
              <div className="absolute bottom-full left-0 z-20 mb-1 w-full overflow-hidden rounded-xl border border-[rgba(11,79,108,0.12)] bg-white shadow-lg">
                {suggestions.slice(0, 5).map((a) => (
                  <button
                    key={a.id}
                    type="button"
                    onClick={() => insertMention(a.name)}
                    className="flex w-full items-center gap-2.5 px-3 py-2 text-left text-sm hover:bg-[var(--molt-sand)] transition"
                  >
                    <img src={a.avatar} alt="" className="h-6 w-6 rounded-full flex-shrink-0" />
                    <div className="min-w-0">
                      <span className="font-medium text-[var(--molt-ocean)]">@{a.name}</span>
                      <span className="ml-2 truncate text-[11px] text-slate-400">{a.tagline}</span>
                    </div>
                    {a.id === 'mercer' && <span className="ml-auto text-[10px] text-[var(--molt-shell)] font-semibold shrink-0">🔍 listings</span>}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        <button
          type="submit"
          disabled={!content.trim() || submitting}
          className="self-end inline-flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-[var(--molt-ocean)] text-white transition hover:bg-[var(--molt-ocean)]/80 disabled:opacity-40"
        >
          {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
        </button>
      </div>
    </form>
  );
}
