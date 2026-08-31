'use client';

import { useEffect, useState } from 'react';
import { AlertCircle, ExternalLink, Loader2, MessageSquare, Plug, Radio, RefreshCw } from 'lucide-react';

type FeedItem = {
  id: string;
  source: 'x' | 'truth_social' | 'manual';
  postedAt: string;
  text: string;
  url?: string;
  tickers: string[];
  sentiment: 'bullish' | 'bearish' | 'neutral' | 'mixed';
  materiality: number;
  confidence: number;
  engagementScore?: number;
};

type Monitor = {
  id: string;
  displayName: string;
  xHandle?: string;
  truthHandle?: string;
  weight: number;
  enabled: boolean;
  notes: string;
};

type Entry = {
  monitor: Monitor;
  status: 'live' | 'disabled' | 'no_recent';
  reason: string;
  items: FeedItem[];
};

type FeedResponse = {
  generatedAt: string;
  configured: { xApi: boolean; truthVendor: boolean };
  monitors: Entry[];
  flatItems: FeedItem[];
  setupHint: string;
};

export function InfluencerFeedCard() {
  const [data, setData] = useState<FeedResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/market/influencer-feed', { cache: 'no-store' });
      const json = await res.json();
      if (!res.ok) throw new Error(json?.error || `${res.status}`);
      setData(json);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'fetch failed');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/40">
      <header className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div>
          <div className="mb-2 inline-flex items-center gap-2 rounded-[6px] border border-amber-300/50 bg-amber-300/15 px-3 py-1 text-xs font-black uppercase tracking-[0.14em] text-amber-100">
            <Radio className="h-4 w-4" /> Influencer Feed
          </div>
          <h2 className="text-xl font-black text-white">Trump · Elon · Jensen · 其他高影响账号</h2>
          <p className="mt-1 text-xs leading-5 text-slate-300">
            实时拉取关键账号发言（X + Truth Social），抽取受影响 ticker、方向、置信度。点 ticker 进入完整期权 + 概率分析。
          </p>
        </div>
        <button
          type="button"
          onClick={() => void load()}
          disabled={loading}
          className="inline-flex h-9 items-center gap-2 rounded-[6px] border border-slate-600 bg-black px-3 text-xs font-black text-slate-100 transition hover:border-amber-300 disabled:opacity-60"
        >
          {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
          刷新
        </button>
      </header>

      {error ? (
        <div className="mb-4 rounded-[8px] border border-red-400/40 bg-red-950/60 p-3 text-sm text-red-100">{error}</div>
      ) : null}

      {data ? (
        <>
          {!data.configured.xApi && !data.configured.truthVendor ? (
            <div className="mb-4 rounded-[8px] border border-amber-400/40 bg-amber-500/10 p-4">
              <div className="flex items-center gap-2 text-amber-200">
                <Plug className="h-4 w-4" />
                <strong className="text-sm font-black">未配置 X / Truth 凭据</strong>
              </div>
              <p className="mt-2 text-xs leading-5 text-slate-100">{data.setupHint}</p>
              <a
                href="/market#manual"
                className="mt-3 inline-flex items-center gap-1 text-xs font-black text-amber-200 hover:text-amber-100"
              >
                → 用 Manual Event 面板粘贴 Trump/Elon 发言
              </a>
            </div>
          ) : null}

          {/* Per-influencer grid */}
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {data.monitors.map((entry) => (
              <MonitorCard key={entry.monitor.id} entry={entry} />
            ))}
          </div>

          {data.flatItems.length > 0 ? (
            <div className="mt-5">
              <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-200">
                <MessageSquare className="h-4 w-4 text-blue-300" /> 最新 {data.flatItems.length} 条 (按时间)
              </div>
              <div className="space-y-2">
                {data.flatItems.slice(0, 5).map((item) => (
                  <CompactItem key={item.id} item={item} />
                ))}
              </div>
            </div>
          ) : null}

          <p className="mt-4 border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">
            数据来自 X API v2 recent search（如已配置）+ 授权 Truth Social provider（如已配置）。
            <strong className="text-slate-200">不模仿任何人的语气、不生成假发言</strong>；每条都点回原 post。
            生成时间：{new Date(data.generatedAt).toLocaleString()}
          </p>
        </>
      ) : loading ? (
        <div className="flex items-center gap-2 text-sm text-slate-200">
          <Loader2 className="h-4 w-4 animate-spin" /> 拉取关键账号最新发言...
        </div>
      ) : null}
    </section>
  );
}

function MonitorCard({ entry }: { entry: Entry }) {
  const { monitor, status, reason, items } = entry;
  const initials = monitor.displayName
    .split(/\s+/)
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  const statusCls =
    status === 'live'
      ? 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100'
      : status === 'no_recent'
        ? 'border-blue-400/50 bg-blue-500/20 text-blue-100'
        : 'border-slate-600 bg-slate-800 text-slate-200';

  const statusLabel = status === 'live' ? 'LIVE' : status === 'no_recent' ? 'IDLE' : 'OFFLINE';

  return (
    <article className="rounded-[8px] border border-slate-700 bg-slate-950 p-3">
      <header className="flex items-start justify-between gap-2">
        <div className="flex items-start gap-3 min-w-0">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-slate-600 bg-black font-mono text-sm font-black text-slate-100">
            {initials}
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-black text-white">{monitor.displayName}</p>
            <div className="mt-0.5 flex flex-wrap gap-1 text-[10px]">
              {monitor.xHandle ? (
                <span className="font-mono text-slate-300">@{monitor.xHandle}</span>
              ) : null}
              {monitor.truthHandle ? (
                <span className="font-mono text-pink-300">truth/@{monitor.truthHandle}</span>
              ) : null}
            </div>
          </div>
        </div>
        <span className={`shrink-0 rounded border px-1.5 py-0.5 text-[9px] font-black uppercase tracking-wider ${statusCls}`}>
          {statusLabel}
        </span>
      </header>

      <p className="mt-2 text-[11px] leading-4 text-slate-400">weight {monitor.weight} · {reason}</p>

      {items.length > 0 ? (
        <ul className="mt-3 space-y-2 border-t border-slate-800 pt-3">
          {items.slice(0, 3).map((item) => (
            <li key={item.id} className="text-xs leading-5">
              <div className="flex items-start gap-2">
                <SentimentDot sentiment={item.sentiment} />
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-3 text-slate-100">{item.text}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-1.5">
                    {item.tickers.slice(0, 5).map((t) => (
                      <a
                        key={t}
                        href={`/market/ticker/${encodeURIComponent(t)}`}
                        className="rounded border border-blue-400/40 bg-blue-500/15 px-1.5 py-0.5 text-[10px] font-mono font-black text-blue-100 hover:bg-blue-500/30"
                      >
                        ${t}
                      </a>
                    ))}
                    <span className="font-mono text-[10px] text-slate-500">
                      M{item.materiality}/C{item.confidence}
                    </span>
                    {item.url ? (
                      <a
                        href={item.url}
                        target="_blank"
                        rel="noreferrer"
                        className="ml-auto inline-flex items-center gap-0.5 text-[10px] text-slate-400 hover:text-blue-300"
                      >
                        原帖 <ExternalLink className="h-2.5 w-2.5" />
                      </a>
                    ) : null}
                  </div>
                </div>
              </div>
            </li>
          ))}
        </ul>
      ) : status === 'disabled' ? (
        <p className="mt-3 border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">
          <AlertCircle className="mr-1 inline h-3 w-3 text-amber-300" />
          {monitor.notes}
        </p>
      ) : (
        <p className="mt-3 border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">近期无命中。</p>
      )}
    </article>
  );
}

function CompactItem({ item }: { item: FeedItem }) {
  const sourceLabel = item.source === 'x' ? 'X' : item.source === 'truth_social' ? 'Truth' : 'Manual';
  const sourceCls =
    item.source === 'x'
      ? 'text-slate-100'
      : item.source === 'truth_social'
        ? 'text-pink-200'
        : 'text-amber-200';

  return (
    <div className="flex items-start gap-3 rounded-[6px] border border-slate-700 bg-slate-950 p-3">
      <SentimentDot sentiment={item.sentiment} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2 text-[10px] font-mono">
          <span className={`font-black ${sourceCls}`}>{sourceLabel}</span>
          <span className="text-slate-500">·</span>
          <span className="text-slate-400">{new Date(item.postedAt).toLocaleString()}</span>
          <span className="text-slate-500">·</span>
          <span className="text-slate-400">M{item.materiality}/C{item.confidence}</span>
          {item.engagementScore !== undefined ? (
            <>
              <span className="text-slate-500">·</span>
              <span className="text-slate-400">engagement {item.engagementScore}</span>
            </>
          ) : null}
        </div>
        <p className="mt-1 line-clamp-2 text-sm leading-5 text-slate-100">{item.text}</p>
        <div className="mt-1 flex flex-wrap items-center gap-1.5">
          {item.tickers.slice(0, 6).map((t) => (
            <a
              key={t}
              href={`/market/ticker/${encodeURIComponent(t)}`}
              className="rounded border border-blue-400/40 bg-blue-500/15 px-1.5 py-0.5 text-[10px] font-mono font-black text-blue-100 hover:bg-blue-500/30"
            >
              ${t}
            </a>
          ))}
          {item.url ? (
            <a
              href={item.url}
              target="_blank"
              rel="noreferrer"
              className="ml-auto inline-flex items-center gap-0.5 text-[10px] text-slate-400 hover:text-blue-300"
            >
              原帖 <ExternalLink className="h-2.5 w-2.5" />
            </a>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function SentimentDot({ sentiment }: { sentiment: FeedItem['sentiment'] }) {
  const cls =
    sentiment === 'bullish'
      ? 'bg-emerald-400'
      : sentiment === 'bearish'
        ? 'bg-red-400'
        : sentiment === 'mixed'
          ? 'bg-amber-400'
          : 'bg-slate-500';
  return <span className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${cls}`} title={sentiment} />;
}
