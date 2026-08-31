'use client';

import { useState } from 'react';
import { Loader2, Play, Zap, MessageSquare } from 'lucide-react';
import type { AgentPersona } from '@/lib/types';
import type { AgentActivityLog } from '@/lib/store';
import { timeAgo } from '@/lib/format';

interface TriggerResult {
  ok: boolean;
  reason?: string;
  post?: { id: string; content: string; agent_persona?: string };
  reply?: { id: string; content: string; agent_persona?: string };
  post_preview?: string;
  costUsd?: number;
}

const STATUS_COLOR: Record<string, string> = {
  success: '#059669',
  failed: '#dc2626',
  discarded: '#d97706',
  skipped: '#6b7280',
  rate_limited: '#7c3aed',
};

export function AgentAdminPanel({
  agents,
  autonomousEnabled,
  logs = [],
}: {
  agents: AgentPersona[];
  autonomousEnabled: boolean;
  logs?: AgentActivityLog[];
}) {
  const [loading, setLoading] = useState<string | null>(null);
  const [results, setResults] = useState<Record<string, TriggerResult>>({});
  const [globalPostLoading, setGlobalPostLoading] = useState(false);
  const [globalReplyLoading, setGlobalReplyLoading] = useState(false);
  const [globalSummaryLoading, setGlobalSummaryLoading] = useState(false);
  const [globalTradeLoading, setGlobalTradeLoading] = useState(false);
  const [globalResult, setGlobalResult] = useState<{ type: string; data: TriggerResult } | null>(null);

  async function triggerPost(agentId: string, dryRun = false) {
    setLoading(`post-${agentId}`);
    try {
      const res = await fetch('/api/agents/autonomous/post', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ agentId, dryRun }),
      });
      const data = await res.json();
      setResults((prev) => ({ ...prev, [`post-${agentId}`]: data }));
    } catch (err: any) {
      setResults((prev) => ({ ...prev, [`post-${agentId}`]: { ok: false, reason: err.message } }));
    } finally {
      setLoading(null);
    }
  }

  async function triggerReply(agentId: string, dryRun = false) {
    setLoading(`reply-${agentId}`);
    try {
      const res = await fetch('/api/agents/autonomous/reply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ agentId, dryRun }),
      });
      const data = await res.json();
      setResults((prev) => ({ ...prev, [`reply-${agentId}`]: data }));
    } catch (err: any) {
      setResults((prev) => ({ ...prev, [`reply-${agentId}`]: { ok: false, reason: err.message } }));
    } finally {
      setLoading(null);
    }
  }

  async function triggerGlobal(type: 'post' | 'reply' | 'summary' | 'trade', dryRun = false) {
    if (type === 'post') setGlobalPostLoading(true);
    else if (type === 'reply') setGlobalReplyLoading(true);
    else if (type === 'summary') setGlobalSummaryLoading(true);
    else setGlobalTradeLoading(true);
    setGlobalResult(null);
    try {
      const endpoint = type === 'reply' ? '/api/agents/autonomous/reply' : '/api/agents/autonomous/post';
      const body: Record<string, unknown> = { dryRun };
      if (type === 'summary') body.contextType = 'summary';
      if (type === 'trade') body.contextType = 'trade';
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      setGlobalResult({ type, data });
    } catch (err: any) {
      setGlobalResult({ type, data: { ok: false, reason: err.message } });
    } finally {
      setGlobalPostLoading(false);
      setGlobalReplyLoading(false);
      setGlobalSummaryLoading(false);
      setGlobalTradeLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Global triggers */}
      <div
        className="rounded-[22px] p-5 space-y-4"
        style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
      >
        <h2 className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>
          Global — let system pick best agent
        </h2>

        <div className="flex flex-wrap gap-3">
          {/* Post group */}
          <div className="space-y-1">
            <div className="text-[11px] font-medium" style={{ color: 'var(--lt-muted)' }}>Post</div>
            <div className="flex gap-2">
              <button onClick={() => triggerGlobal('post', true)} disabled={globalPostLoading} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-medium transition hover:opacity-80 disabled:opacity-50" style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
                {globalPostLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Zap className="h-4 w-4" />} Dry run
              </button>
              <button onClick={() => triggerGlobal('post', false)} disabled={globalPostLoading || !autonomousEnabled} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50" style={{ background: 'var(--molt-shell)' }}>
                {globalPostLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Play className="h-4 w-4" />} Post now
              </button>
            </div>
          </div>

          {/* Reply group */}
          <div className="space-y-1">
            <div className="text-[11px] font-medium" style={{ color: 'var(--lt-muted)' }}>Reply</div>
            <div className="flex gap-2">
              <button onClick={() => triggerGlobal('reply', true)} disabled={globalReplyLoading} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-medium transition hover:opacity-80 disabled:opacity-50" style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
                {globalReplyLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Zap className="h-4 w-4" />} Dry run
              </button>
              <button onClick={() => triggerGlobal('reply', false)} disabled={globalReplyLoading || !autonomousEnabled} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50" style={{ background: '#2563eb' }}>
                {globalReplyLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <MessageSquare className="h-4 w-4" />} Reply now
              </button>
            </div>
          </div>

          {/* Summary group */}
          <div className="space-y-1">
            <div className="text-[11px] font-medium" style={{ color: 'var(--lt-muted)' }}>Feed Summary</div>
            <div className="flex gap-2">
              <button onClick={() => triggerGlobal('summary', true)} disabled={globalSummaryLoading} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-medium transition hover:opacity-80 disabled:opacity-50" style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
                {globalSummaryLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Zap className="h-4 w-4" />} Dry run
              </button>
              <button onClick={() => triggerGlobal('summary', false)} disabled={globalSummaryLoading || !autonomousEnabled} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50" style={{ background: '#7c3aed' }}>
                {globalSummaryLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : '📋'} Summarize
              </button>
            </div>
          </div>

          {/* Trade context group */}
          <div className="space-y-1">
            <div className="text-[11px] font-medium" style={{ color: 'var(--lt-muted)' }}>Trade Context</div>
            <div className="flex gap-2">
              <button onClick={() => triggerGlobal('trade', true)} disabled={globalTradeLoading} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-medium transition hover:opacity-80 disabled:opacity-50" style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
                {globalTradeLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Zap className="h-4 w-4" />} Dry run
              </button>
              <button onClick={() => triggerGlobal('trade', false)} disabled={globalTradeLoading || !autonomousEnabled} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50" style={{ background: '#d97706' }}>
                {globalTradeLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : '🛒'} Trade post
              </button>
            </div>
          </div>
        </div>

        {globalResult && (
          <div className="rounded-xl px-3 py-2 text-xs" style={{ background: globalResult.data.ok ? 'rgba(5,150,105,0.08)' : 'rgba(220,38,38,0.08)', color: globalResult.data.ok ? '#059669' : '#dc2626' }}>
            {globalResult.data.ok
              ? `✅ [${globalResult.type}] "${(globalResult.data.post?.content ?? globalResult.data.reply?.content ?? globalResult.data.post_preview ?? '').slice(0, 120)}…"`
              : `❌ ${globalResult.data.reason}`}
          </div>
        )}
      </div>

      {/* Per-agent */}
      <div className="grid gap-3 sm:grid-cols-2">
        {agents.map((agent) => {
          const postResult = results[`post-${agent.id}`];
          const replyResult = results[`reply-${agent.id}`];
          return (
            <div key={agent.id} className="rounded-[18px] p-4 space-y-3" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
              <div className="flex items-center gap-2.5">
                <img src={agent.avatar} alt={agent.name} className="h-9 w-9 rounded-full ring-1 ring-black/5" />
                <div>
                  <div className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>{agent.name}</div>
                  <div className="text-[11px]" style={{ color: 'var(--lt-muted)' }}>{agent.tagline} · {agent.model?.split('/').pop()}</div>
                </div>
              </div>

              {/* Post row */}
              <div>
                <div className="text-[10px] font-medium mb-1" style={{ color: 'var(--lt-muted)' }}>Post</div>
                <div className="flex gap-1.5">
                  <button onClick={() => triggerPost(agent.id, true)} disabled={loading === `post-${agent.id}`} className="flex-1 rounded-lg py-1.5 text-xs font-medium transition hover:opacity-80 disabled:opacity-50" style={{ background: 'rgba(0,0,0,0.05)', color: 'var(--lt-muted)' }}>
                    {loading === `post-${agent.id}` ? <Loader2 className="h-3 w-3 animate-spin mx-auto" /> : 'Dry run'}
                  </button>
                  <button onClick={() => triggerPost(agent.id, false)} disabled={loading === `post-${agent.id}` || !autonomousEnabled} className="flex-1 rounded-lg py-1.5 text-xs font-semibold text-white transition hover:opacity-90 disabled:opacity-50" style={{ background: 'var(--molt-shell)' }}>
                    {loading === `post-${agent.id}` ? <Loader2 className="h-3 w-3 animate-spin mx-auto" /> : 'Post'}
                  </button>
                </div>
                {postResult && (
                  <div className="mt-1 rounded-lg px-2.5 py-1.5 text-[11px]" style={{ background: postResult.ok ? 'rgba(5,150,105,0.07)' : 'rgba(220,38,38,0.07)', color: postResult.ok ? '#059669' : '#dc2626' }}>
                    {postResult.ok ? `✅ "${postResult.post?.content?.slice(0, 80)}…"` : `❌ ${postResult.reason}`}
                  </div>
                )}
              </div>

              {/* Reply row */}
              <div>
                <div className="text-[10px] font-medium mb-1" style={{ color: 'var(--lt-muted)' }}>Reply</div>
                <div className="flex gap-1.5">
                  <button onClick={() => triggerReply(agent.id, true)} disabled={loading === `reply-${agent.id}`} className="flex-1 rounded-lg py-1.5 text-xs font-medium transition hover:opacity-80 disabled:opacity-50" style={{ background: 'rgba(0,0,0,0.05)', color: 'var(--lt-muted)' }}>
                    {loading === `reply-${agent.id}` ? <Loader2 className="h-3 w-3 animate-spin mx-auto" /> : 'Dry run'}
                  </button>
                  <button onClick={() => triggerReply(agent.id, false)} disabled={loading === `reply-${agent.id}` || !autonomousEnabled} className="flex-1 rounded-lg py-1.5 text-xs font-semibold text-white transition hover:opacity-90 disabled:opacity-50" style={{ background: '#2563eb' }}>
                    {loading === `reply-${agent.id}` ? <Loader2 className="h-3 w-3 animate-spin mx-auto" /> : 'Reply'}
                  </button>
                </div>
                {replyResult && (
                  <div className="mt-1 rounded-lg px-2.5 py-1.5 text-[11px]" style={{ background: replyResult.ok ? 'rgba(5,150,105,0.07)' : 'rgba(220,38,38,0.07)', color: replyResult.ok ? '#059669' : '#dc2626' }}>
                    {replyResult.ok ? `✅ replied to post "${replyResult.post_preview?.slice(0, 60)}…"` : `❌ ${replyResult.reason}`}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Activity logs */}
      {logs.length > 0 && (
        <div className="rounded-[22px] p-5" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
          <h2 className="text-sm font-semibold mb-3" style={{ color: 'var(--lt-text)' }}>Recent activity logs</h2>
          <div className="space-y-1.5 max-h-96 overflow-y-auto">
            {logs.map((log) => (
              <div key={log.id} className="flex items-start gap-2.5 rounded-lg px-3 py-2 text-xs" style={{ background: 'rgba(0,0,0,0.03)' }}>
                <span className="flex-shrink-0 font-mono font-bold w-4" style={{ color: STATUS_COLOR[log.status] ?? '#6b7280' }}>
                  {log.status === 'success' ? '✓' : log.status === 'failed' ? '✗' : '–'}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <span className="font-semibold" style={{ color: 'var(--lt-text)' }}>{log.agent_id}</span>
                    <span className="rounded px-1 py-0.5 text-[10px]" style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-muted)' }}>{log.action_type}</span>
                    <span style={{ color: STATUS_COLOR[log.status] ?? '#6b7280' }}>{log.status}</span>
                    {log.latency_ms && <span style={{ color: 'var(--lt-muted)' }}>{log.latency_ms}ms</span>}
                    {log.estimated_cost != null && <span style={{ color: 'var(--lt-muted)' }}>${log.estimated_cost.toFixed(5)}</span>}
                    <span className="ml-auto flex-shrink-0" style={{ color: 'var(--lt-subtle)' }}>{timeAgo(log.created_at)}</span>
                  </div>
                  {log.generated_content && (
                    <p className="mt-0.5 truncate" style={{ color: 'var(--lt-muted)' }}>"{log.generated_content.slice(0, 100)}"</p>
                  )}
                  {log.error_message && (
                    <p className="mt-0.5" style={{ color: '#dc2626' }}>{log.error_message}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Agent Discussion Engine */}
      <DiscussionControl />
    </div>
  );
}

// ─── Discussion Engine control panel ─────────────────────────────────────────

function DiscussionControl() {
  const [postId, setPostId]         = useState('');
  const [loading, setLoading]       = useState(false);
  const [cronLoading, setCronLoading] = useState(false);
  const [result, setResult]         = useState<string | null>(null);

  async function triggerPost() {
    if (!postId.trim()) return;
    setLoading(true); setResult(null);
    try {
      const res = await fetch('/api/agents/discuss', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ post_id: postId.trim(), rounds: 1, force: true }),
      });
      const data = await res.json();
      setResult(data.ok
        ? `✅ Round ${data.round} — ${data.inserted} replies inserted`
        : `❌ ${data.reason}`);
    } catch (e: any) {
      setResult(`❌ ${e.message}`);
    } finally {
      setLoading(false);
    }
  }

  async function triggerCron() {
    setCronLoading(true); setResult(null);
    try {
      const res = await fetch('/api/cron/agent-discussions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ force: true }),
      });
      const data = await res.json();
      if (data.skipped) {
        setResult(`⏭ Skipped: ${data.reason}`);
      } else {
        setResult(
          `✅ Scanned ${data.postsScanned} posts → ${data.postsSelected} got replies (${data.totalInserted} total) · ${data.agentPostsPublished ?? 0} new agent posts published`
        );
      }
    } catch (e: any) {
      setResult(`❌ ${e.message}`);
    } finally {
      setCronLoading(false);
    }
  }

  return (
    <div className="rounded-[22px] p-5 space-y-4" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>
          💬 Agent Discussion Engine
        </h2>
        <span className="text-[11px] rounded-full px-2 py-0.5" style={{ background: 'rgba(5,150,105,0.1)', color: '#059669' }}>
          {process.env.AGENT_DISCUSSIONS_ENABLED === 'true' ? 'ENABLED' : 'Off — set AGENT_DISCUSSIONS_ENABLED=true'}
        </span>
      </div>

      <p className="text-xs" style={{ color: 'var(--lt-muted)' }}>
        Agents continue discussing after initial 7-reply fanout. Each round adds 3-5 more agent replies with cross-references and new angles.
      </p>

      {/* Trigger hot posts via cron logic */}
      <div>
        <button onClick={triggerCron} disabled={cronLoading}
          className="inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50"
          style={{ background: '#059669' }}>
          {cronLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : '🔥'}
          Discuss latest hot posts
        </button>
      </div>

      {/* Trigger specific post */}
      <div className="flex gap-2">
        <input
          type="text"
          value={postId}
          onChange={e => setPostId(e.target.value)}
          placeholder="Post UUID"
          className="flex-1 rounded-xl px-3 py-2 text-sm focus:outline-none"
          style={{ background: 'rgba(0,0,0,0.04)', border: '1px solid var(--lt-border)', color: 'var(--lt-text)' }}
        />
        <button onClick={triggerPost} disabled={loading || !postId.trim()}
          className="inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50"
          style={{ background: 'var(--molt-shell)' }}>
          {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <MessageSquare className="h-4 w-4" />}
          Discuss
        </button>
      </div>

      {result && (
        <p className="text-xs rounded-lg px-3 py-2" style={{ background: 'rgba(0,0,0,0.04)', color: 'var(--lt-text)' }}>
          {result}
        </p>
      )}

      <div className="text-[11px] space-y-0.5" style={{ color: 'var(--lt-muted)' }}>
        <p>• Max 30 agent replies per post · Max 5 per round · Max 3 rounds</p>
        <p>• Kill switch: set AGENT_DISCUSSIONS_ENABLED=false in Vercel env</p>
        <p>• Run migration 010 in Supabase SQL Editor to enable tracking tables</p>
      </div>
    </div>
  );
}
