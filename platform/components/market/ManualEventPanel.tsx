'use client';

import { FormEvent, useState } from 'react';
import { ClipboardPaste, Loader2, ShieldAlert, Sparkles } from 'lucide-react';

type ManualEventResponse = {
  event: {
    headline: string;
    summary: string;
    tickers: string[];
    sentiment: string;
    materialityScore: number;
    confidence: number;
    tags: string[];
    riskFlags: string[];
    sourceUrl?: string;
    publishedAt: string;
  };
  analysis: {
    directionSummary: string;
    tickerSummary: string;
    nextChecks: string[];
  };
  disclaimer: string;
  error?: string;
};

const SOURCE_TYPES: Array<{ value: string; label: string }> = [
  { value: 'x_manual', label: 'X / Twitter 文本' },
  { value: 'truth_manual', label: 'Truth Social 文本' },
  { value: 'reuters_headline', label: 'Reuters / 官方新闻' },
  { value: 'press_release', label: '公司公告 / 新闻稿' },
  { value: 'sec_url', label: 'SEC 文件 URL' },
  { value: 'other', label: '其他' },
];

export function ManualEventPanel() {
  const [sourceType, setSourceType] = useState('x_manual');
  const [sourceUrl, setSourceUrl] = useState('');
  const [text, setText] = useState('');
  const [tickersHint, setTickersHint] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ManualEventResponse | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const body: Record<string, unknown> = { sourceType, text };
      if (sourceUrl) body.sourceUrl = sourceUrl;
      if (tickersHint) {
        body.tickersHint = tickersHint
          .split(/[\s,]+/)
          .map((t) => t.replace(/^\$/, '').trim().toUpperCase())
          .filter(Boolean);
      }
      const res = await fetch('/api/market/events/manual', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data: ManualEventResponse = await res.json();
      if (!res.ok || data.error) throw new Error(data.error || `${res.status}`);
      setResult(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'manual event failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/30">
      <header className="mb-4 flex items-center gap-2">
        <ClipboardPaste className="h-5 w-5 text-amber-300" />
        <h2 className="text-xl font-black text-white">新闻 Resource / Catalyst Intake</h2>
      </header>
      <p className="mb-5 text-sm leading-6 text-slate-200">
        粘贴一条 X / Truth Social / Reuters / 官方公告 文本，或一个 SEC 文件 URL，先做“新闻 → 影响资产 → 后续验证点”的事件分析；点 ticker 后再进入价格概率分布和期权策略结构。不会替你下单。
      </p>

      <form onSubmit={submit} className="grid gap-3">
        <div className="grid gap-3 sm:grid-cols-[180px_1fr]">
          <label className="space-y-1.5">
            <span className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-200">来源类型</span>
            <select
              value={sourceType}
              onChange={(e) => setSourceType(e.target.value)}
              className="block h-10 w-full rounded-[6px] border border-slate-600 bg-slate-950 px-2 text-sm text-white outline-none focus:border-amber-300"
            >
              {SOURCE_TYPES.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
          <label className="space-y-1.5">
            <span className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-200">来源 URL (可选)</span>
            <input
              value={sourceUrl}
              onChange={(e) => setSourceUrl(e.target.value)}
              placeholder="https://x.com/... 或 https://www.sec.gov/..."
              className="block h-10 w-full rounded-[6px] border border-slate-600 bg-slate-950 px-3 text-sm text-white outline-none placeholder:text-slate-500 focus:border-amber-300"
            />
          </label>
        </div>
        <label className="space-y-1.5">
          <span className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-200">事件文本</span>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            required
            rows={5}
            placeholder="Trump: I will impose 100% tariffs on semiconductors imported from China starting next month..."
            className="block w-full rounded-[6px] border border-slate-600 bg-slate-950 px-3 py-2 text-sm leading-6 text-white outline-none placeholder:text-slate-500 focus:border-amber-300"
            maxLength={4000}
          />
        </label>
        <label className="space-y-1.5">
          <span className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-200">Ticker 提示 (可选, 逗号或空格分隔)</span>
          <input
            value={tickersHint}
            onChange={(e) => setTickersHint(e.target.value)}
            placeholder="NVDA, AMD, AVGO"
            className="block h-10 w-full rounded-[6px] border border-slate-600 bg-slate-950 px-3 text-sm font-mono uppercase text-white outline-none placeholder:text-slate-500 focus:border-amber-300"
          />
        </label>
        <button
          type="submit"
          disabled={loading || !text}
          className="inline-flex h-11 items-center justify-center gap-2 self-start rounded-[6px] bg-amber-300 px-6 text-sm font-black text-slate-950 transition hover:bg-amber-200 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Sparkles className="h-4 w-4" />}
          分析事件
        </button>
      </form>

      {error ? (
        <div className="mt-4 rounded-[8px] border border-red-400/40 bg-red-950/60 p-3 text-sm text-red-100">{error}</div>
      ) : null}

      {result ? (
        <div className="mt-5 space-y-4 rounded-[8px] border border-slate-700 bg-slate-950 p-4">
          <header className="flex flex-wrap items-center justify-between gap-3">
            <h3 className="text-base font-black text-white">{result.event.headline}</h3>
            <div className="flex flex-wrap gap-2">
              <Badge label={`materiality ${result.event.materialityScore}`} tone="amber" />
              <Badge label={`confidence ${result.event.confidence}`} tone="blue" />
              <Badge label={result.event.sentiment} tone={toneForSentiment(result.event.sentiment)} />
            </div>
          </header>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-[6px] border border-slate-700 bg-black p-3">
              <p className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-300">Ticker 映射</p>
              <p className="mt-1.5 font-mono text-sm font-black text-white">
                {result.event.tickers.length ? result.event.tickers.map((t) => `$${t}`).join(' · ') : '—'}
              </p>
              <p className="mt-2 text-xs leading-5 text-slate-200">{result.analysis.tickerSummary}</p>
              {result.event.tickers.length > 0 ? (
                <div className="mt-3 flex flex-wrap gap-2">
                  {result.event.tickers.map((t) => (
                    <a
                      key={t}
                      href={`/market/ticker/${encodeURIComponent(t)}`}
                      className="rounded-[6px] border border-blue-400/50 bg-blue-500/20 px-2.5 py-1 text-[11px] font-black text-blue-100 transition hover:bg-blue-500/35"
                    >
                      → 打开 {t} 分析
                    </a>
                  ))}
                </div>
              ) : null}
            </div>

            <div className="rounded-[6px] border border-slate-700 bg-black p-3">
              <p className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-300">方向 + 标签</p>
              <p className="mt-1.5 text-sm leading-6 text-slate-100">{result.analysis.directionSummary}</p>
              {result.event.tags.length ? (
                <div className="mt-2 flex flex-wrap gap-1">
                  {result.event.tags.map((t) => (
                    <span key={t} className="rounded border border-slate-700 bg-slate-800 px-2 py-0.5 text-[10px] font-mono font-black text-slate-100">
                      #{t}
                    </span>
                  ))}
                </div>
              ) : null}
              {result.event.riskFlags.length ? (
                <div className="mt-2 flex flex-wrap gap-1">
                  {result.event.riskFlags.map((r) => (
                    <span key={r} className="inline-flex items-center gap-1 rounded border border-red-400/40 bg-red-500/20 px-2 py-0.5 text-[10px] font-mono font-black text-red-100">
                      <ShieldAlert className="h-3 w-3" /> {r}
                    </span>
                  ))}
                </div>
              ) : null}
            </div>
          </div>

          <div className="rounded-[6px] border border-slate-700 bg-black p-3">
            <p className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-300">下一步要核实的事</p>
            <ul className="mt-2 space-y-1 text-sm leading-6 text-slate-100">
              {result.analysis.nextChecks.map((c) => (
                <li key={c}>• {c}</li>
              ))}
            </ul>
          </div>

          <p className="border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">{result.disclaimer}</p>
        </div>
      ) : null}
    </section>
  );
}

function Badge({ label, tone }: { label: string; tone: 'amber' | 'blue' | 'green' | 'red' | 'slate' }) {
  const cls: Record<string, string> = {
    amber: 'border-amber-400/40 bg-amber-500/15 text-amber-100',
    blue: 'border-blue-400/40 bg-blue-500/15 text-blue-100',
    green: 'border-emerald-400/40 bg-emerald-500/15 text-emerald-100',
    red: 'border-red-400/40 bg-red-500/15 text-red-100',
    slate: 'border-slate-600 bg-slate-800 text-slate-200',
  };
  return (
    <span className={`inline-flex items-center rounded-[6px] border px-2 py-1 text-[10px] font-black uppercase tracking-[0.1em] ${cls[tone]}`}>
      {label}
    </span>
  );
}

function toneForSentiment(s: string): 'green' | 'red' | 'amber' | 'slate' {
  if (s === 'bullish') return 'green';
  if (s === 'bearish') return 'red';
  if (s === 'mixed') return 'amber';
  return 'slate';
}
