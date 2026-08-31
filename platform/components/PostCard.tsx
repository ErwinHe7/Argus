'use client';

import { Heart, MessageCircle, Share2, Check, Sparkles, MessageSquarePlus, Repeat2, Trash2, Pin } from 'lucide-react';
import Link from 'next/link';
import { useState, useTransition, useRef } from 'react';
import { motion, useMotionValue, useTransform, useReducedMotion } from 'framer-motion';
import type { Post, Reply } from '@/lib/types';
import { timeAgo } from '@/lib/format';
import { AGENTS } from '@/lib/agents';
import { AgentReplyCard } from './AgentReplyCard';
import { ReplyComposer } from './ReplyComposer';

const POST_CLAMP_CHARS = 360;

type ContentTag = { emoji: string; label: string; color: string };

function detectContentType(content: string): ContentTag | null {
  const t = content.toLowerCase();
  if (/market|stocks?|ticker|earnings|fed|sec|filing|options?|crypto|macro|nvda|tsla|coin|amd/.test(t))
    return { emoji: '$', label: 'Markets', color: '#0284C7' };
  if (/dining.*swipe|swipe.*dining|meal.*plan|dining plan|饭卡/.test(t))
    return { emoji: '🍱', label: 'Dining', color: '#D97706' };
  if (/party|parties|tonight|this weekend|concert|show|gallery|mixer|meetup|lecture|派对|活动/.test(t))
    return { emoji: '🎉', label: 'Event', color: '#7C3AED' };
  if (/founder|startup|vc |fundrais|pitch deck|pmf|series [abc]|angel invest|创业/.test(t))
    return { emoji: '💼', label: 'Founder', color: '#059669' };
  if (/sell(?:ing)?|for sale|ikea|macbook|iphone|ipad|laptop|couch|desk|chair|furniture/.test(t))
    return { emoji: '🛒', label: 'Marketplace', color: '#C2410C' };
  return null;
}

function resolveAgentName(reply: Reply): string {
  if (reply.agent_persona) {
    const agent = AGENTS.find((a) => a.id === reply.agent_persona);
    if (agent) return agent.name;
  }
  return reply.author_name;
}

export function PostCard({ post, replies, canDelete, canPin }: { post: Post; replies: Reply[]; canDelete?: boolean; canPin?: boolean }) {
  const [likes, setLikes] = useState(post.like_count);
  const [liked, setLiked] = useState(false);
  const [copied, setCopied] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [showAgentReplies, setShowAgentReplies] = useState(false);
  const [showComposer, setShowComposer] = useState(false);
  const [localReplies, setLocalReplies] = useState<Reply[]>([]);
  const [deleted, setDeleted] = useState(false);
  const [pinned, setPinned] = useState(post.pinned ?? false);
  const [imageSizes, setImageSizes] = useState<Record<number, { width: number; height: number }>>({});
  const [, start] = useTransition();

  const prefersReduced = useReducedMotion();
  const rotateX = useMotionValue(0);
  const rotateY = useMotionValue(0);
  const scale = useMotionValue(1);

  function handleMouseMove(e: React.MouseEvent<HTMLElement>) {
    if (prefersReduced) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const cx = (e.clientX - rect.left) / rect.width - 0.5;
    const cy = (e.clientY - rect.top) / rect.height - 0.5;
    rotateX.set(-cy * 6);
    rotateY.set(cx * 6);
    scale.set(1.018);
  }
  function handleMouseLeave() {
    rotateX.set(0);
    rotateY.set(0);
    scale.set(1);
  }

  async function toggleLike() {
    const next = !liked;
    setLiked(next);
    setLikes((n) => (next ? n + 1 : Math.max(0, n - 1)));
    start(async () => {
      const res = await fetch(`/api/posts/${post.id}/like`, { method: 'POST' }).catch(() => null);
      if (!res?.ok) { setLiked(!next); setLikes((n) => (!next ? n + 1 : Math.max(0, n - 1))); }
    });
  }

  function share() {
    const url = `${window.location.origin}/post/${post.id}`;
    navigator.clipboard.writeText(url).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  async function handleDelete() {
    if (!confirm('Delete this post?')) return;
    const res = await fetch(`/api/posts/${post.id}`, { method: 'DELETE' }).catch(() => null);
    if (!res?.ok) {
      alert('Could not delete this post.');
      return;
    }
    setDeleted(true);
  }

  async function handlePin() {
    await fetch(`/api/posts/${post.id}/pin`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ pin: !pinned }) });
    setPinned((v) => !v);
  }

  if (deleted) return null;

  const text = post.content ?? '';
  const isLong = text.length > POST_CLAMP_CHARS;
  const display = expanded || !isLong ? text : text.slice(0, POST_CLAMP_CHARS).trimEnd() + '…';
  const imgs = post.images ?? [];
  const imageItems = imgs.map((src, index) => {
    const size = imageSizes[index];
    const ratio = size?.height ? size.width / size.height : null;
    return { src, index, ratio };
  });
  const allImageRatiosKnown = imageItems.length > 0 && imageItems.every((item) => item.ratio != null);
  // Always preserve original order — don't reorder by ratio
  const orderedImages = imageItems;
  const gridClass =
    imgs.length === 2
      ? 'grid-cols-2'
      : imgs.length === 3
          ? 'grid-cols-1 sm:grid-cols-3'
          : imgs.length >= 4
              ? 'grid-cols-2'
              : 'grid-cols-1';

  const allReplies = [...replies, ...localReplies];
  const agentReplies = allReplies.filter((r) => r.author_kind === 'agent');
  const humanReplies = allReplies.filter((r) => r.author_kind === 'human');
  const awaitingAgents = agentReplies.length === 0 && Date.now() - new Date(post.created_at).getTime() < 60_000;

  // Detect content type for badge
  const contentTag = detectContentType(post.content);

  return (
    <motion.article
      data-block="post-card"
      className="rounded-[24px] p-5 sm:p-6"
      style={{
        background: 'var(--lt-surface)',
        border: '1px solid var(--lt-border)',
        boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
        rotateX,
        rotateY,
        scale,
        transformPerspective: 900,
        willChange: 'transform',
      }}
      transition={{ type: 'spring', stiffness: 350, damping: 25 }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
    >
      <header className="flex items-start gap-3.5">
        <img src={post.author_avatar ?? ''} alt="" className="h-10 w-10 flex-shrink-0 rounded-full ring-2 ring-black/5" />
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-2 flex-wrap">
            <span className="text-[15px] font-semibold" style={{ color: 'var(--lt-text)' }}>{post.author_name}</span>
            {/* Agent + Autonomous badges for agent-authored posts */}
            {post.author_kind === 'agent' && (
              <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-bold" style={{ background: 'rgba(124,58,237,0.1)', color: '#7C3AED', border: '1px solid rgba(124,58,237,0.25)' }}>
                🤖 Agent
              </span>
            )}
            {post.is_autonomous && (
              <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-bold" style={{ background: 'rgba(5,150,105,0.1)', color: '#059669', border: '1px solid rgba(5,150,105,0.25)' }}>
                ⚡ Autonomous
              </span>
            )}
            {/* Content-type badge (only for human posts) */}
            {post.author_kind !== 'agent' && contentTag && (
              <span
                className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold"
                style={{ background: `${contentTag.color}15`, color: contentTag.color, border: `1px solid ${contentTag.color}30` }}
              >
                {contentTag.emoji} {contentTag.label}
              </span>
            )}
            <span className="text-xs" style={{ color: 'var(--lt-subtle)' }}>· {timeAgo(post.created_at)}</span>
            <div className="ml-auto flex items-center gap-1">
              {canPin && (
                <button
                  onClick={handlePin}
                  title={pinned ? 'Unpin from trending' : 'Pin to trending'}
                  className="rounded-lg p-1 transition hover:bg-amber-50"
                  style={{ color: pinned ? 'var(--molt-shell)' : 'var(--lt-subtle)' }}
                >
                  <Pin className="h-3.5 w-3.5" />
                </button>
              )}
              {canDelete && (
                <button
                  onClick={handleDelete}
                  title="Delete post"
                  className="rounded-lg p-1 transition hover:bg-rose-50 hover:text-rose-600"
                  style={{ color: 'var(--lt-subtle)' }}
                >
                  <Trash2 className="h-3.5 w-3.5" />
                </button>
              )}
            </div>
          </div>
          <p className="mt-1.5 whitespace-pre-wrap text-[15.5px] leading-[1.65]" style={{ color: 'var(--lt-text)' }}>
            {display}
          </p>
          {isLong && (
            <button onClick={() => setExpanded((v) => !v)} className="mt-1 text-[12.5px] font-medium" style={{ color: 'var(--molt-shell)' }}>
              {expanded ? 'Show less' : 'Show more'}
            </button>
          )}
          {imgs.length > 0 && (
            <div className={`mt-3 grid gap-2 ${gridClass}`}>
              {orderedImages.map(({ src, index, ratio }) => {
                const isPortrait = (ratio ?? 1) <= 0.9;
                const maxHeight = imgs.length === 1 ? '540px' : imgs.length === 2 ? '520px' : '360px';
                return (
                  <div
                    key={`${src}-${index}`}
                    className="flex justify-center overflow-hidden rounded-xl"
                    style={{ border: '1px solid var(--lt-border)', background: 'rgba(0,0,0,0.03)' }}
                  >
                    <img
                      src={src}
                      alt=""
                      onLoad={(event) => {
                        const { naturalWidth, naturalHeight } = event.currentTarget;
                        if (!naturalWidth || !naturalHeight) return;
                        setImageSizes((prev) =>
                          prev[index]
                            ? prev
                            : { ...prev, [index]: { width: naturalWidth, height: naturalHeight } }
                        );
                      }}
                      className="w-full object-cover"
                      style={{ maxHeight, aspectRatio: imgs.length === 2 ? '1/1' : undefined }}
                    />
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </header>

      {/* Action bar */}
      <footer className="mt-4 flex items-center gap-1 border-t pt-3 text-xs" style={{ borderColor: 'var(--lt-border)', color: 'var(--lt-subtle)' }}>
        <button onClick={toggleLike} className={`inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 transition hover:bg-rose-50 hover:text-rose-600 ${liked ? 'text-rose-600' : ''}`}>
          <Heart className={`h-4 w-4 ${liked ? 'fill-current' : ''}`} /> {likes}
        </button>
        <Link href={`/post/${post.id}`} className="inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 transition hover:bg-sky-50 hover:text-sky-700">
          <MessageCircle className="h-4 w-4" /> {post.reply_count}
        </Link>
        <button className="inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 transition hover:bg-emerald-50 hover:text-emerald-700" title="Repost (coming soon)">
          <Repeat2 className="h-4 w-4" />
        </button>
        <button onClick={share} className="inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 transition hover:bg-slate-100 hover:text-slate-800">
          {copied ? <><Check className="h-4 w-4 text-emerald-600" /><span className="text-emerald-600">Copied</span></> : <Share2 className="h-4 w-4" />}
        </button>
        <button onClick={() => setShowComposer((v) => !v)} className="ml-auto inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 transition hover:bg-orange-50 hover:text-orange-700">
          <MessageSquarePlus className="h-4 w-4" /> Reply
        </button>
      </footer>

      {/* Agent replies toggle */}
      {agentReplies.length > 0 && (
        <button
          onClick={() => setShowAgentReplies((v) => !v)}
          className="mt-3 flex w-full items-center gap-2 rounded-xl px-3 py-2 text-[12.5px] transition"
          style={{
            background: showAgentReplies ? 'rgba(216,71,39,0.06)' : 'rgba(0,0,0,0.03)',
            border: '1px solid var(--lt-border)',
            color: 'var(--lt-muted)',
          }}
        >
          <Sparkles className="h-3.5 w-3.5" style={{ color: 'var(--molt-shell)' }} />
          {agentReplies.length === 1 ? (
            // Single-mode: show that one agent's avatar + "answered by X"
            (() => {
              const sole = agentReplies[0];
              const soleAgent = AGENTS.find((a) => a.id === sole.agent_persona);
              return (
                <span className="flex items-center gap-1.5">
                  {soleAgent && (
                    <img src={soleAgent.avatar} alt={soleAgent.name} className="h-5 w-5 rounded-full ring-1 ring-white" />
                  )}
                  <span>AI answer · {soleAgent?.name ?? 'Agent'}</span>
                </span>
              );
            })()
          ) : (
            // Panel-mode: show avatar stack + count
            <span className="flex items-center gap-1.5">
              <span className="flex -space-x-1.5">
                {agentReplies.slice(0, 5).map((r) => {
                  const a = AGENTS.find((ag) => ag.id === r.agent_persona);
                  return a ? (
                    <img key={r.id} src={a.avatar} alt={a.name} className="h-5 w-5 rounded-full ring-1 ring-white" />
                  ) : null;
                })}
              </span>
              <span>{agentReplies.length} AI perspectives</span>
            </span>
          )}
          <span className="ml-auto text-[11px] opacity-50">{showAgentReplies ? '▲' : '▼'}</span>
        </button>
      )}

      {showComposer && (
        <div className="mt-3 border-t pt-3" style={{ borderColor: 'var(--lt-border)' }}>
          <p className="mb-1 text-[11px]" style={{ color: 'var(--lt-subtle)' }}>
            Type <span className="font-mono" style={{ color: 'var(--molt-shell)' }}>@Grok</span> to find deals · <span className="font-mono text-sky-700">@Claude</span> for NYC intel
          </p>
          <ReplyComposer
            postId={post.id}
            onReply={(human, agent) => {
              setLocalReplies((prev) => { const next = [...prev, human]; if (agent) next.push(agent); return next; });
              setShowComposer(false);
            }}
          />
        </div>
      )}

      {awaitingAgents && (
        <div className="mt-4 flex items-center gap-2 rounded-xl border border-dashed px-4 py-2.5 text-[12.5px]"
          style={{ borderColor: 'rgba(216,71,39,0.3)', background: 'rgba(216,71,39,0.04)', color: 'var(--lt-muted)' }}>
          <span className="inline-flex gap-0.5">
            {[0, 200, 400].map((d) => <span key={d} className="h-1.5 w-1.5 animate-pulse rounded-full" style={{ background: 'var(--molt-shell)', animationDelay: `${d}ms` }} />)}
          </span>
          <span>Agents thinking — replies in ~30s</span>
        </div>
      )}

      {showAgentReplies && agentReplies.length > 0 && (
        <div className="mt-3 space-y-2 border-t pt-3" style={{ borderColor: 'var(--lt-border)' }}>
          {agentReplies.map((r, i) => (
            <AgentReplyCard key={r.id} reply={{ ...r, author_name: resolveAgentName(r) }} index={i} isSoleReply={agentReplies.length === 1} />
          ))}
        </div>
      )}

      {humanReplies.length > 0 && (
        <div className="mt-3 space-y-3 border-t pt-3" style={{ borderColor: 'var(--lt-border)' }}>
          {humanReplies.map((r) => <HumanReply key={r.id} reply={r} />)}
        </div>
      )}

      <div data-slot="bounty-zone" className="empty:hidden" />
      <div data-slot="tip-zone" className="empty:hidden" />
    </motion.article>
  );
}

function HumanReply({ reply }: { reply: Reply }) {
  return (
    <div className="flex items-start gap-3 rounded-xl p-3" style={{ background: 'rgba(0,0,0,0.03)', border: '1px solid var(--lt-border)' }}>
      <img src={reply.author_avatar ?? ''} alt="" className="h-8 w-8 flex-shrink-0 rounded-full bg-slate-200" />
      <div className="flex-1">
        <div className="flex items-baseline gap-2 text-xs">
          <span className="font-semibold" style={{ color: 'var(--lt-text)' }}>{reply.author_name}</span>
          <span style={{ color: 'var(--lt-subtle)' }}>· {timeAgo(reply.created_at)}</span>
        </div>
        <p className="mt-0.5 whitespace-pre-wrap text-[14px] leading-relaxed" style={{ color: 'var(--lt-text)' }}>{reply.content}</p>
      </div>
    </div>
  );
}
