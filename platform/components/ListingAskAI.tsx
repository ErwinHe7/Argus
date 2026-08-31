'use client';

import { useState } from 'react';
import { Bot, ChevronDown, ChevronUp, Loader2 } from 'lucide-react';
import { AgentReplyCard } from './AgentReplyCard';
import type { Listing, Reply } from '@/lib/types';
import { formatCents } from '@/lib/format';

// Persona IDs for trade-relevant panel (Price, Location, Safety, Negotiation)
const TRADE_PANEL_AGENTS = ['nova', 'atlas', 'mercer', 'lumen'];

// Query patterns that signal a decision/opinion (→ panel)
const DECISION_PATTERNS = [
  /worth\b/i, /should i\b/i, /该不该/i, /值得/i, /靠谱/i, /legit/i,
  /good deal/i, /negotiate/i, /offer/i, /overpriced/i, /fair price/i,
  /recommend/i, /thoughts on/i, /what do you think/i, /is this/i,
];

function isDecisionQuery(q: string) {
  return DECISION_PATTERNS.some((p) => p.test(q));
}

// Quick-suggestion chips shown below the input
const QUICK_ASKS = [
  'Is this priced fairly?',
  'What should I watch out for?',
  'How should I negotiate?',
  'Is this listing legit?',
];

interface Props {
  listing: Pick<Listing, 'id' | 'title' | 'category' | 'asking_price_cents' | 'currency' | 'location' | 'description'>;
}

export function ListingAskAI({ listing }: Props) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [replies, setReplies] = useState<Reply[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function ask(q: string) {
    const trimmed = q.trim();
    if (!trimmed) return;
    setLoading(true);
    setError(null);
    setReplies([]);

    // Build a synthetic post content enriched with listing context
    const listingCtx = [
      `Listing: "${listing.title}"`,
      `Category: ${listing.category}`,
      `Price: ${formatCents(listing.asking_price_cents, listing.currency)}`,
      listing.location ? `Location: ${listing.location}` : null,
      listing.description ? `Description: ${listing.description.slice(0, 300)}` : null,
    ]
      .filter(Boolean)
      .join('\n');

    const fullQuery = `${trimmed}\n\n[Listing context]\n${listingCtx}`;

    // Decide mode client-side: decision queries → panel (4 agents), info → single
    const isDecision = isDecisionQuery(trimmed);
    const agentIds = isDecision ? TRADE_PANEL_AGENTS : undefined; // undefined = router decides

    try {
      // Create an ephemeral post, then fan-out agents
      const postRes = await fetch('/api/posts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: fullQuery }),
      });
      if (!postRes.ok) {
        const d = await postRes.json().catch(() => ({}));
        throw new Error(d.error ?? 'Failed to create post');
      }
      const { post } = await postRes.json();

      // Fan-out: pass agent_ids override so trade panel only calls relevant agents
      const fanoutRes = await fetch('/api/fanout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          post_id: post.id,
          ...(agentIds ? { agent_ids: agentIds } : {}),
        }),
      });
      if (!fanoutRes.ok) throw new Error('Agents failed to respond');

      // Fetch the replies that were just created
      const repliesRes = await fetch(`/api/posts/${post.id}/replies`);
      if (!repliesRes.ok) throw new Error('Could not load replies');
      const data = await repliesRes.json();
      setReplies((data.replies ?? []).filter((r: Reply) => r.author_kind === 'agent'));
    } catch (err: any) {
      setError(err.message ?? 'Something went wrong. Try again.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="rounded-[22px] overflow-hidden"
      style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
    >
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between px-5 py-4 text-sm font-medium transition hover:opacity-80"
        style={{ color: 'var(--lt-text)' }}
      >
        <span className="inline-flex items-center gap-2">
          <Bot className="h-4 w-4" style={{ color: 'var(--molt-shell)' }} />
          Ask agents about this listing
        </span>
        {open ? <ChevronUp className="h-4 w-4" style={{ color: 'var(--lt-muted)' }} /> : <ChevronDown className="h-4 w-4" style={{ color: 'var(--lt-muted)' }} />}
      </button>

      {open && (
        <div className="border-t px-5 pb-5 pt-4 space-y-4" style={{ borderColor: 'var(--lt-border)' }}>
          {/* Quick chips */}
          <div className="flex flex-wrap gap-2">
            {QUICK_ASKS.map((chip) => (
              <button
                key={chip}
                onClick={() => { setQuery(chip); ask(chip); }}
                disabled={loading}
                className="rounded-full px-3 py-1 text-xs font-medium transition hover:opacity-80 disabled:opacity-50"
                style={{ background: 'rgba(216,71,39,0.08)', border: '1px solid rgba(216,71,39,0.2)', color: 'var(--molt-shell)' }}
              >
                {chip}
              </button>
            ))}
          </div>

          {/* Free-text input */}
          <div className="flex gap-2">
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && !loading) ask(query); }}
              placeholder="Ask anything about this listing…"
              className="flex-1 rounded-xl px-3 py-2 text-sm focus:outline-none"
              style={{ background: 'rgba(0,0,0,0.04)', border: '1px solid var(--lt-border)', color: 'var(--lt-text)' }}
            />
            <button
              onClick={() => ask(query)}
              disabled={loading || !query.trim()}
              className="inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50"
              style={{ background: 'var(--molt-shell)' }}
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Ask'}
            </button>
          </div>

          {loading && (
            <div className="flex items-center gap-2 text-xs" style={{ color: 'var(--lt-muted)' }}>
              <span className="inline-flex gap-0.5">
                {[0, 200, 400].map((d) => (
                  <span key={d} className="h-1.5 w-1.5 animate-pulse rounded-full" style={{ background: 'var(--molt-shell)', animationDelay: `${d}ms` }} />
                ))}
              </span>
              <span>Agents analyzing this listing…</span>
            </div>
          )}

          {error && (
            <p className="rounded-lg px-3 py-2 text-sm" style={{ background: 'rgba(220,38,38,0.06)', color: '#dc2626' }}>
              {error}
            </p>
          )}

          {replies.length > 0 && (
            <div className="space-y-2 pt-1">
              {replies.map((r, i) => (
                <AgentReplyCard key={r.id} reply={r} index={i} isSoleReply={replies.length === 1} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
