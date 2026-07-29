'use client';

import { Bot, ThumbsDown, ThumbsUp, Sparkles } from 'lucide-react';
import { useState, useTransition } from 'react';
import { motion, useMotionValue, useReducedMotion } from 'framer-motion';
import Link from 'next/link';
import type { Reply } from '@/lib/types';
import { timeAgo } from '@/lib/format';
import { AGENTS } from '@/lib/agents';

// Extract /events/<uuid> references from agent reply text
function extractEventIds(text: string): string[] {
  const ids: string[] = [];
  const re = /\/events\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/gi;
  let m;
  while ((m = re.exec(text)) !== null) {
    if (!ids.includes(m[1])) ids.push(m[1]);
  }
  return ids;
}

function InlineEventRef({ eventId }: { eventId: string }) {
  return (
    <Link
      href={`/events/${eventId}`}
      className="inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition hover:opacity-90"
      style={{ background: 'rgba(216,71,39,0.08)', border: '1px solid rgba(216,71,39,0.2)', color: 'var(--molt-shell)' }}
    >
      🎉 View event →
    </Link>
  );
}

// Per-agent left bar color
const AGENT_BAR: Record<string, string> = {
  nova:   '#7C3AED',  // GPT    — violet
  atlas:  '#0284C7',  // Claude — sky
  lumen:  '#BE185D',  // DeepSeek — pink
  ember:  '#0D9488',  // Kimi   — teal
  sage:   '#B45309',  // Qwen   — amber
  mercer: '#C2410C',  // Grok   — orange
  iris:   '#1D4ED8',  // Gemini — blue
};

function confidenceTone(score: number | null) {
  if (score == null) return null;
  if (score >= 0.8) return { label: `${(score * 100).toFixed(0)}%`, color: '#166534' };
  if (score >= 0.6) return { label: `${(score * 100).toFixed(0)}%`, color: '#92400E' };
  return { label: `${(score * 100).toFixed(0)}%`, color: '#991B1B' };
}

interface Props { reply: Reply; index?: number; isSoleReply?: boolean; }

export function AgentReplyCard({ reply, index = 0, isSoleReply = false }: Props) {
  const [up, setUp] = useState(reply.up_count ?? 0);
  const [down, setDown] = useState(reply.down_count ?? 0);
  const [myVote, setMyVote] = useState<0 | 1 | -1>(0);
  const [expanded, setExpanded] = useState(false);
  const [, start] = useTransition();
  const prefersReduced = useReducedMotion();

  const scale = useMotionValue(1);
  const bar = AGENT_BAR[reply.agent_persona ?? ''] ?? '#6B7280';
  const agent = AGENTS.find((a) => a.id === reply.agent_persona);
  const tone = confidenceTone(reply.confidence_score);

  const text = reply.content ?? '';
  const isLong = text.length > 260;
  const display = expanded || !isLong ? text : text.slice(0, 260).trimEnd() + '…';
  const eventIds = extractEventIds(text);

  function handleMouseEnter() { if (!prefersReduced) scale.set(1.012); }
  function handleMouseLeave() { scale.set(1); }

  async function vote(value: 1 | -1) {
    if (myVote === value) return;
    const prev = myVote;
    setMyVote(value);
    if (prev === 1) setUp((n) => Math.max(0, n - 1));
    if (prev === -1) setDown((n) => Math.max(0, n - 1));
    if (value === 1) setUp((n) => n + 1);
    if (value === -1) setDown((n) => n + 1);
    start(async () => {
      await fetch('/api/reactions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reply_id: reply.id, value }),
      }).catch(() => {});
    });
  }

  return (
    <motion.div
      className="relative overflow-hidden rounded-2xl pl-4 pr-4 py-3"
      style={{
        background: 'var(--lt-surface)',
        border: '1px solid var(--lt-border)',
        boxShadow: '0 1px 4px rgba(0,0,0,0.06)',
        scale,
        willChange: 'transform',
        transformOrigin: 'center',
      }}
      initial={prefersReduced ? false : { opacity: 0, x: -8 }}
      whileInView={{ opacity: 1, x: 0 }}
      viewport={{ once: true, margin: '-20px' }}
      transition={{ delay: index * 0.05, duration: 0.28, ease: 'easeOut' }}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {/* Left accent bar */}
      <span aria-hidden className="absolute left-0 top-0 h-full w-[3px] rounded-l-2xl" style={{ background: bar }} />

      <div className="flex items-start gap-3">
        <div className="relative flex-shrink-0">
          <img
            src={reply.author_avatar ?? ''}
            alt={reply.author_name}
            className="h-9 w-9 rounded-full ring-2 ring-white"
            style={{ boxShadow: `0 0 0 2px ${bar}33` }}
          />
          <span
            className="absolute -bottom-0.5 -right-0.5 inline-flex h-4 w-4 items-center justify-center rounded-full"
            style={{ background: bar, boxShadow: '0 0 0 2px white' }}
          >
            <Bot className="h-2.5 w-2.5 text-white" />
          </span>
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-2 text-xs">
            <span className="text-[14px] font-semibold" style={{ color: bar }}>{reply.author_name}</span>
            {agent?.tagline && (
              <span className="hidden truncate text-[11px] sm:inline" style={{ color: 'var(--lt-subtle)' }}>
                {agent.tagline}
              </span>
            )}
            <span className="ml-auto text-[11px]" style={{ color: 'var(--lt-subtle)' }}>{timeAgo(reply.created_at)}</span>
          </div>

          <p className="mt-1.5 whitespace-pre-wrap text-[14px] leading-[1.65]" style={{ color: 'var(--lt-text)' }}>
            {display}
          </p>
          {isLong && (
            <button onClick={() => setExpanded((v) => !v)} className="mt-1 text-[12px] font-medium" style={{ color: 'var(--lt-muted)' }}>
              {expanded ? 'Show less' : 'Show more'}
            </button>
          )}

          {/* Inline event buttons — auto-detected from /events/<uuid> in reply text */}
          {eventIds.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-2">
              {eventIds.map((id) => <InlineEventRef key={id} eventId={id} />)}
            </div>
          )}

          <div className="mt-2.5 flex flex-wrap items-center gap-3 text-[11px]" style={{ color: 'var(--lt-subtle)' }}>
            <button onClick={() => vote(1)} className={`inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 transition hover:bg-emerald-50 ${myVote === 1 ? 'font-semibold text-emerald-700' : ''}`}>
              <ThumbsUp className="h-3 w-3" /> {up}
            </button>
            <button onClick={() => vote(-1)} className={`inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 transition hover:bg-rose-50 ${myVote === -1 ? 'font-semibold text-rose-700' : ''}`}>
              <ThumbsDown className="h-3 w-3" /> {down}
            </button>
            <span className="ml-auto flex items-center gap-2">
              {isSoleReply && agent && (
                <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium" style={{ background: `${bar}18`, color: bar }}>
                  answered by {agent.name}
                </span>
              )}
              {agent?.model && (
                <span className="hidden sm:inline font-mono text-[10px] uppercase tracking-wider px-1.5 py-0.5 rounded" style={{ background: 'rgba(0,0,0,0.05)', color: 'var(--lt-muted)' }}>
                  {agent.model.split('/').pop()}
                </span>
              )}
              {tone && (
                <span className="inline-flex items-center gap-0.5 font-medium" style={{ color: tone.color }}>
                  <Sparkles className="h-2.5 w-2.5" />{tone.label}
                </span>
              )}
            </span>
          </div>
        </div>
      </div>

      <div data-slot="verified-badge" className="absolute top-2 right-2 empty:hidden" />
    </motion.div>
  );
}
