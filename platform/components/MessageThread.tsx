'use client';

import { useEffect, useRef, useState } from 'react';
import { Bot, ChevronDown, ChevronUp, Loader2, Send, Sparkles, X } from 'lucide-react';
import type { Message } from '@/lib/types';
import { timeAgo } from '@/lib/format';

// ─── Agent co-pilot panel ────────────────────────────────────────────────────

type CopilotResult = { question: string; answer: string };

async function askCopilot(question: string): Promise<string> {
  const res = await fetch('/api/ask', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: question }),
  });
  if (!res.ok) throw new Error('Agent failed');
  const data = await res.json();
  return data.answer ?? '';
}

function CopilotPanel({
  anchoredMessage,
  onClear,
}: {
  anchoredMessage: Message | null;
  onClear: () => void;
}) {
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [translating, setTranslating] = useState(false);
  const [results, setResults] = useState<CopilotResult[]>([]);

  async function run(q: string) {
    if (!q.trim()) return;
    setLoading(true);
    try {
      const fullQ = anchoredMessage
        ? `Regarding this message: "${anchoredMessage.content.slice(0, 300)}"\n\n${q}`
        : q;
      const answer = await askCopilot(fullQ);
      setResults((prev) => [{ question: q, answer }, ...prev].slice(0, 5));
      setQuery('');
    } catch {
      setResults((prev) => [{ question: q, answer: 'Agent unavailable. Try again.' }, ...prev].slice(0, 5));
    } finally {
      setLoading(false);
    }
  }

  async function translateAnchor() {
    if (!anchoredMessage) return;
    setTranslating(true);
    try {
      const answer = await askCopilot(
        `Translate this message to English (show original below translation): "${anchoredMessage.content}"`
      );
      setResults((prev) => [{ question: 'Translate', answer }, ...prev].slice(0, 5));
    } catch {
      /* ignore */
    } finally {
      setTranslating(false);
    }
  }

  const QUICK = anchoredMessage
    ? ["What does this mean?", "Is this a fair offer?", "How should I respond?"]
    : ["Is this price fair?", "What should I ask the seller?", "Any red flags?"];

  return (
    <div className="flex flex-col h-full" style={{ minHeight: 400 }}>
      {/* Header */}
      <div
        className="flex items-center justify-between px-3 py-2.5 text-xs font-semibold flex-shrink-0"
        style={{ borderBottom: '1px solid var(--lt-border)', color: 'var(--lt-text)' }}
      >
        <span className="inline-flex items-center gap-1.5">
          <Sparkles className="h-3.5 w-3.5" style={{ color: 'var(--molt-shell)' }} />
          Agent co-pilot
        </span>
        <span className="text-[10px] font-normal" style={{ color: 'var(--lt-muted)' }}>
          7 models
        </span>
      </div>

      {/* Anchored message */}
      {anchoredMessage && (
        <div
          className="mx-3 mt-2.5 rounded-lg px-3 py-2 text-xs flex-shrink-0"
          style={{ background: 'rgba(216,71,39,0.06)', border: '1px solid rgba(216,71,39,0.18)' }}
        >
          <div className="flex items-center justify-between gap-2 mb-1">
            <span className="font-medium" style={{ color: 'var(--molt-shell)' }}>Asking about:</span>
            <div className="flex items-center gap-1">
              <button
                onClick={translateAnchor}
                disabled={translating}
                className="rounded px-1.5 py-0.5 text-[10px] font-medium transition hover:opacity-80 disabled:opacity-50"
                style={{ background: 'rgba(216,71,39,0.1)', color: 'var(--molt-shell)' }}
              >
                {translating ? <Loader2 className="h-2.5 w-2.5 animate-spin inline" /> : 'Translate'}
              </button>
              <button onClick={onClear} className="opacity-40 hover:opacity-80 transition">
                <X className="h-3 w-3" style={{ color: 'var(--lt-muted)' }} />
              </button>
            </div>
          </div>
          <p className="line-clamp-2" style={{ color: 'var(--lt-text)' }}>{anchoredMessage.content}</p>
        </div>
      )}

      {/* Quick chips */}
      <div className="flex flex-wrap gap-1.5 px-3 pt-2.5 flex-shrink-0">
        {QUICK.map((q) => (
          <button
            key={q}
            onClick={() => run(q)}
            disabled={loading}
            className="rounded-full px-2.5 py-1 text-[11px] font-medium transition hover:opacity-80 disabled:opacity-50"
            style={{ background: 'rgba(0,0,0,0.05)', color: 'var(--lt-muted)' }}
          >
            {q}
          </button>
        ))}
      </div>

      {/* Input */}
      <div className="px-3 pt-2 flex-shrink-0">
        <div className="flex gap-1.5">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter' && !loading) run(query); }}
            placeholder="Ask agents anything…"
            className="flex-1 rounded-lg px-2.5 py-1.5 text-xs focus:outline-none"
            style={{ background: 'rgba(0,0,0,0.04)', border: '1px solid var(--lt-border)', color: 'var(--lt-text)' }}
          />
          <button
            onClick={() => run(query)}
            disabled={loading || !query.trim()}
            className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg text-white transition hover:opacity-90 disabled:opacity-40"
            style={{ background: 'var(--molt-shell)' }}
          >
            {loading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Send className="h-3.5 w-3.5" />}
          </button>
        </div>
      </div>

      {/* Results */}
      <div className="flex-1 overflow-y-auto px-3 pt-3 space-y-3 pb-3">
        {results.length === 0 && (
          <p className="text-center text-[11px] pt-6" style={{ color: 'var(--lt-muted)' }}>
            Hover a message and click "Ask AI", or use a chip above.
          </p>
        )}
        {results.map((r, i) => (
          <div
            key={i}
            className="rounded-xl px-3 py-2.5 text-xs space-y-1"
            style={{ background: 'rgba(0,0,0,0.04)', border: '1px solid var(--lt-border)' }}
          >
            <p className="font-medium text-[11px]" style={{ color: 'var(--lt-muted)' }}>{r.question}</p>
            <p className="leading-relaxed whitespace-pre-wrap" style={{ color: 'var(--lt-text)' }}>{r.answer}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Main thread ─────────────────────────────────────────────────────────────

export function MessageThread({
  transactionId,
  currentUserId,
  currentUserName,
  sellerName,
  buyerName,
  initialMessages,
}: {
  transactionId: string;
  currentUserId: string;
  currentUserName: string;
  sellerName: string;
  buyerName: string;
  initialMessages: Message[];
}) {
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [content, setContent] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [anchoredMessage, setAnchoredMessage] = useState<Message | null>(null);
  const [copilotOpen, setCopilotOpen] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length]);

  // Poll every 4s
  useEffect(() => {
    const iv = setInterval(async () => {
      const res = await fetch(`/api/transactions/${transactionId}/messages`).catch(() => null);
      if (!res?.ok) return;
      const { messages: next } = await res.json();
      if (Array.isArray(next)) setMessages(next);
    }, 4000);
    return () => clearInterval(iv);
  }, [transactionId]);

  async function send() {
    if (!content.trim() || submitting) return;
    const body = content.trim();
    setContent('');
    setSubmitting(true);
    try {
      const res = await fetch(`/api/transactions/${transactionId}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sender_name: currentUserName, content: body }),
      });
      if (res.ok) {
        const { message } = await res.json();
        setMessages((prev) => [...prev, message]);
      } else {
        setContent(body);
      }
    } finally {
      setSubmitting(false);
      textareaRef.current?.focus();
    }
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  }

  return (
    <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
      {/* ── Chat thread ── */}
      <div
        className="flex flex-col overflow-hidden rounded-[22px] lg:flex-1"
        style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)', minHeight: 480 }}
      >
        {/* Header */}
        <div
          className="flex items-center justify-between px-4 py-3 text-xs"
          style={{ borderBottom: '1px solid var(--lt-border)', color: 'var(--lt-muted)' }}
        >
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full" style={{ background: '#4A7C59' }} />
            <span>
              <span className="font-medium" style={{ color: 'var(--lt-text)' }}>{sellerName}</span>
              {' × '}
              <span className="font-medium" style={{ color: 'var(--lt-text)' }}>{buyerName}</span>
            </span>
          </div>
          <div className="flex items-center gap-2">
            <span>{messages.filter((m) => m.sender_id !== 'system').length} messages</span>
            {/* Mobile copilot toggle */}
            <button
              onClick={() => setCopilotOpen((v) => !v)}
              className="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-[11px] font-medium transition hover:opacity-80 lg:hidden"
              style={{ background: 'rgba(216,71,39,0.08)', color: 'var(--molt-shell)' }}
            >
              <Bot className="h-3.5 w-3.5" />
              AI
              {copilotOpen ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
            </button>
          </div>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3" style={{ maxHeight: '55vh', minHeight: 240 }}>
          {messages.length === 0 && (
            <p className="py-10 text-center text-sm" style={{ color: 'var(--lt-muted)' }}>
              Say hi to get started.
            </p>
          )}
          {messages.map((m) => {
            const isSystem = m.sender_id === 'system';
            const isMine = !isSystem && m.sender_id === currentUserId;

            if (isSystem) {
              return (
                <div key={m.id} className="flex justify-center">
                  <div
                    className="max-w-[85%] rounded-xl px-3 py-2 text-center text-xs"
                    style={{ background: 'rgba(0,0,0,0.05)', color: 'var(--lt-subtle)' }}
                  >
                    {m.content}
                  </div>
                </div>
              );
            }

            return (
              <div key={m.id} className={`group flex items-end gap-2 ${isMine ? 'flex-row-reverse' : 'flex-row'}`}>
                <div
                  className="flex-shrink-0 h-7 w-7 rounded-full flex items-center justify-center text-xs font-bold text-white"
                  style={{ background: isMine ? 'var(--molt-shell)' : 'var(--lt-subtle)' }}
                >
                  {m.sender_name.slice(0, 1).toUpperCase()}
                </div>

                <div className={`flex flex-col gap-0.5 max-w-[72%] ${isMine ? 'items-end' : 'items-start'}`}>
                  <div className="flex items-center gap-1.5 text-[10px]" style={{ color: 'var(--lt-subtle)' }}>
                    {!isMine && (
                      <span className="font-medium" style={{ color: 'var(--lt-muted)' }}>{m.sender_name}</span>
                    )}
                    <span>{timeAgo(m.created_at)}</span>
                    {/* Ask AI about this message — shown on hover */}
                    <button
                      onClick={() => { setAnchoredMessage(m); setCopilotOpen(true); }}
                      className="hidden group-hover:inline-flex items-center gap-0.5 rounded px-1 py-0.5 text-[9px] font-medium transition"
                      style={{ background: 'rgba(216,71,39,0.08)', color: 'var(--molt-shell)' }}
                    >
                      <Sparkles className="h-2.5 w-2.5" /> Ask AI
                    </button>
                  </div>
                  <div
                    className="rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed whitespace-pre-wrap"
                    style={isMine ? {
                      background: 'var(--molt-shell)',
                      color: 'white',
                      borderBottomRightRadius: 4,
                    } : {
                      background: 'rgba(0,0,0,0.06)',
                      color: 'var(--lt-text)',
                      borderBottomLeftRadius: 4,
                    }}
                  >
                    {m.content}
                  </div>
                </div>
              </div>
            );
          })}
          <div ref={endRef} />
        </div>

        {/* Input */}
        <div className="px-4 py-3" style={{ borderTop: '1px solid var(--lt-border)' }}>
          <div className="flex items-end gap-2">
            <textarea
              ref={textareaRef}
              rows={2}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Type a message… (Enter to send)"
              className="flex-1 resize-none rounded-xl px-3 py-2.5 text-sm focus:outline-none"
              style={{
                background: 'rgba(0,0,0,0.04)',
                border: '1px solid var(--lt-border)',
                color: 'var(--lt-text)',
                caretColor: 'var(--molt-shell)',
              }}
            />
            <button
              onClick={send}
              disabled={!content.trim() || submitting}
              className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl text-white transition hover:opacity-90 disabled:opacity-40"
              style={{ background: 'var(--molt-shell)' }}
            >
              {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
            </button>
          </div>
        </div>
      </div>

      {/* ── Agent co-pilot sidebar (desktop) / bottom drawer (mobile) ── */}
      {/* Mobile: shown below chat when toggled */}
      {copilotOpen && (
        <div
          className="overflow-hidden rounded-[22px] lg:hidden"
          style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
        >
          <CopilotPanel
            anchoredMessage={anchoredMessage}
            onClear={() => setAnchoredMessage(null)}
          />
        </div>
      )}

      {/* Desktop: always visible on the right */}
      <div
        className="hidden lg:flex flex-col overflow-hidden rounded-[22px] lg:w-72 xl:w-80"
        style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)', minHeight: 480 }}
      >
        <CopilotPanel
          anchoredMessage={anchoredMessage}
          onClear={() => setAnchoredMessage(null)}
        />
      </div>
    </div>
  );
}
