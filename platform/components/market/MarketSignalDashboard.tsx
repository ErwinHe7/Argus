'use client';

import { FormEvent, useEffect, useState } from 'react';
import {
  Activity,
  BarChart3,
  Gauge,
  Loader2,
  RefreshCw,
  ShieldAlert,
  Signal,
  TrendingDown,
  TrendingUp,
} from 'lucide-react';
import type {
  MarketSignalGroup,
  MarketSignalMetric,
  MarketSignalQuote,
  MarketSignalReport,
  SignalStatus,
} from '@/lib/market-intelligence/market-signal';

export function MarketSignalDashboard({ initialReport = null }: { initialReport?: MarketSignalReport | null }) {
  const [quickTicker, setQuickTicker] = useState('NVDA');
  const [report, setReport] = useState<MarketSignalReport | null>(initialReport);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setLoading(true);
    setError(null);

    try {
      const url = new URL('/api/market/signals', window.location.origin);
      const res = await fetch(url.toString(), { cache: 'no-store' });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || 'Market signal fetch failed.');
      setReport(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Market signal fetch failed.');
    } finally {
      setLoading(false);
    }
  }

  function openTicker(event: FormEvent) {
    event.preventDefault();
    const ticker = quickTicker.replace(/^\$/, '').trim().toUpperCase();
    if (!ticker) return;
    window.location.href = `/market/ticker/${encodeURIComponent(ticker)}`;
  }

  useEffect(() => {
    if (!initialReport) void refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 text-slate-100 shadow-2xl shadow-black/40 sm:p-6">
      <header className="grid gap-4 xl:grid-cols-[1fr_420px] xl:items-end">
        <div className="min-w-0">
          <div className="mb-3 inline-flex items-center gap-2 rounded-[6px] border border-blue-400/40 bg-blue-500/15 px-3 py-1.5 text-xs font-black uppercase tracking-[0.14em] text-blue-100">
            <Signal className="h-4 w-4" /> Live market signals
          </div>
          <h2 className="text-3xl font-black tracking-tight text-white sm:text-4xl">美股抄底信号仪表盘</h2>
          <p className="mt-3 max-w-4xl text-base leading-7 text-slate-200">
            实时监控 VIX、CNN 恐惧贪婪指数、日线 RSI、200 日均线偏离和重点股票行情。所有数字来自公开数据源，拿不到就显示暂无可靠数据，不填模拟值。
          </p>
        </div>

        <form onSubmit={openTicker} className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
          <label className="block">
            <span className="mb-2 block text-xs font-black uppercase tracking-[0.14em] text-slate-200">Ticker Console</span>
            <input
              value={quickTicker}
              onChange={(event) => setQuickTicker(event.target.value.toUpperCase())}
              className="block h-11 w-full rounded-[6px] border border-slate-600 bg-black px-3 text-sm font-bold uppercase text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400"
              placeholder="NVDA"
            />
          </label>
          <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
            <span className="text-xs font-semibold text-slate-300">
              {report ? `更新时间：${formatDateTime(report.generatedAt)}` : '等待实时数据'}
            </span>
            <button
              type="submit"
              disabled={!quickTicker.trim()}
              className="inline-flex h-10 items-center justify-center gap-2 rounded-[6px] bg-blue-500 px-4 text-sm font-black text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <BarChart3 className="h-4 w-4" />
              打开单股分析
            </button>
          </div>
          <button
            type="button"
            onClick={() => void refresh()}
            disabled={loading}
            className="mt-3 inline-flex h-9 items-center justify-center gap-2 rounded-[6px] border border-slate-600 bg-black px-3 text-xs font-black text-slate-100 transition hover:border-blue-400 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
            刷新市场状态
          </button>
        </form>
      </header>

      {error ? (
        <div className="mt-4 rounded-[8px] border border-red-400/40 bg-red-950/60 p-4 text-sm font-semibold text-red-100">
          {error}
        </div>
      ) : null}

      {report ? (
        <div className="mt-5 space-y-5">
          <section className="grid gap-4 xl:grid-cols-[340px_1fr]">
            <ScoreCard report={report} />
            <IndexStrip quotes={report.indices} />
          </section>

          <section className="grid gap-4 lg:grid-cols-2">
            {report.groups.map((group) => (
              <MetricGroup key={group.id} group={group} metrics={report.metrics} />
            ))}
          </section>

          <SectorGrid title="行业板块 SPDR" quotes={report.sectors} reliability={report.reliability.sectors} />
          <SectorGrid title="主题 / 宽基 ETF" quotes={report.themes} reliability={report.reliability.themes} />

          <section className="grid gap-3 lg:grid-cols-[1fr_1fr]">
            <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
              <div className="mb-2 flex items-center gap-2 text-sm font-black text-white">
                <Activity className="h-4 w-4 text-blue-300" /> 策略读数
              </div>
              <p className="text-base leading-7 text-slate-100">{report.summary}</p>
              <p className="mt-3 text-sm leading-6 text-slate-300">{report.headline}</p>
            </div>
            <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
              <div className="mb-2 flex items-center gap-2 text-sm font-black text-white">
                <ShieldAlert className="h-4 w-4 text-amber-300" /> 数据源状态
              </div>
              <div className="grid gap-2">
                {report.sources.map((source) => (
                  <a
                    key={source.name}
                    href={source.url}
                    target="_blank"
                    rel="noreferrer"
                    className="rounded-[6px] border border-slate-700 bg-black px-3 py-2 transition hover:border-blue-400"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <strong className="text-sm text-white">{source.name}</strong>
                      <SourceStatusPill status={source.status} />
                    </div>
                    <p className="mt-1 text-sm leading-5 text-slate-200">{source.note}</p>
                  </a>
                ))}
              </div>
              <p className="mt-3 border-t border-slate-800 pt-3 text-xs leading-5 text-slate-300">{report.disclaimer}</p>
            </div>
          </section>
        </div>
      ) : (
        <div className="mt-5 rounded-[8px] border border-slate-700 bg-slate-950 p-6 text-sm font-semibold text-slate-200">
          {loading ? '正在获取实时行情...' : '暂无数据。'}
        </div>
      )}
    </section>
  );
}

function ScoreCard({ report }: { report: MarketSignalReport }) {
  return (
    <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-5">
      <p className="text-xs font-black uppercase tracking-[0.14em] text-slate-200">综合底部信号评分</p>
      <div className="mt-3 flex items-end gap-2">
        <span className="text-6xl font-black leading-none text-white">{report.score}</span>
        <span className="pb-2 text-2xl font-black text-slate-300">/ {report.maxScore}</span>
      </div>
      <div className="mt-4 h-3 overflow-hidden rounded-full bg-slate-800">
        <div
          className={`h-full rounded-full ${report.score >= 4 ? 'bg-emerald-400' : report.score >= 2 ? 'bg-blue-400' : 'bg-red-500'}`}
          style={{ width: `${(report.score / report.maxScore) * 100}%` }}
        />
      </div>
      <p className={`mt-4 text-lg font-black ${report.score >= 4 ? 'text-emerald-300' : report.score >= 2 ? 'text-blue-300' : 'text-red-300'}`}>
        {report.stance}
      </p>
      <p className="mt-2 text-sm leading-6 text-slate-200">{report.headline}</p>
    </div>
  );
}

function IndexStrip({ quotes }: { quotes: MarketSignalQuote[] }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
      {quotes.map((quote) => (
        <QuoteTile key={quote.symbol} quote={quote} />
      ))}
    </div>
  );
}

function QuoteTile({ quote }: { quote: MarketSignalQuote }) {
  // Index symbols like ^GSPC don't have a ticker console; link them to source.
  // Tradeable symbols (no leading caret) link to /market/ticker/<symbol>.
  const isIndex = quote.symbol.startsWith('^');
  const href = isIndex ? quote.sourceUrl : `/market/ticker/${encodeURIComponent(quote.symbol)}`;
  const targetProps = isIndex ? { target: '_blank', rel: 'noreferrer' as const } : {};
  return (
    <a
      href={href}
      {...targetProps}
      className="min-w-0 rounded-[8px] border border-slate-700 bg-slate-950 p-4 transition hover:border-blue-400 hover:bg-slate-900"
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="truncate text-sm font-black text-white">{quote.name}</p>
          <p className="font-mono text-xs font-bold text-slate-300">{quote.symbol}</p>
        </div>
        {quote.changePct !== null && quote.changePct >= 0 ? (
          <TrendingUp className="h-5 w-5 shrink-0 text-emerald-300" />
        ) : (
          <TrendingDown className="h-5 w-5 shrink-0 text-red-300" />
        )}
      </div>
      <p className="mt-3 font-mono text-2xl font-black text-white">{formatNumber(quote.price)}</p>
      <p className={`mt-1 font-mono text-sm font-black ${toneForChange(quote.changePct)}`}>
        {formatSigned(quote.change)} / {formatSignedPct(quote.changePct)}
      </p>
      <p className="mt-2 text-xs font-semibold text-slate-400">{quote.asOf ? formatDateTime(quote.asOf) : '暂无更新时间'}</p>
    </a>
  );
}

function MetricGroup({ group, metrics }: { group: MarketSignalGroup; metrics: MarketSignalMetric[] }) {
  const rows = metrics.filter((metric) => group.metricIds.includes(metric.id));
  return (
    <section className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2 text-lg font-black text-white">
          <Gauge className="h-5 w-5 text-blue-300" /> {group.title}
        </div>
        <span className="rounded-[6px] border border-slate-700 bg-black px-3 py-1.5 text-sm font-black text-slate-100">
          {group.signalCount}/{group.total} 底部信号
        </span>
      </div>

      <div className="grid gap-3">
        {rows.map((metric) => (
          <MetricCard key={metric.id} metric={metric} />
        ))}
      </div>
    </section>
  );
}

function MetricCard({ metric }: { metric: MarketSignalMetric }) {
  return (
    <article className="rounded-[8px] border border-slate-700 bg-black p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <h3 className="text-base font-black leading-6 text-white">{metric.title}</h3>
        <StatusBadge status={metric.status} />
      </div>
      <p className={`mt-3 break-words font-mono text-2xl font-black ${metric.status === 'bottom' ? 'text-emerald-300' : metric.status === 'watch' ? 'text-blue-300' : metric.status === 'risk' ? 'text-red-300' : 'text-slate-200'}`}>
        {metric.value}
      </p>
      <p className="mt-2 text-sm leading-6 text-slate-200">{metric.description}</p>
      <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-slate-800 pt-3">
        <span className="text-xs font-semibold text-slate-300">{metric.threshold}</span>
        <a href={metric.sourceUrl} target="_blank" rel="noreferrer" className="text-xs font-black text-blue-300 underline-offset-4 hover:underline">
          {metric.source}
        </a>
      </div>
    </article>
  );
}

function SectorGrid({
  title,
  quotes,
  reliability,
}: {
  title: string;
  quotes: MarketSignalQuote[];
  reliability: 'ok' | 'partial' | 'unavailable';
}) {
  if (!quotes.length) {
    return (
      <section className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-lg font-black text-white">{title}</h3>
          <SourceStatusPill status={reliability} />
        </div>
        <p className="mt-3 text-sm text-slate-200">暂无可靠数据。</p>
      </section>
    );
  }
  return (
    <section className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <h3 className="text-lg font-black text-white">{title}</h3>
        <SourceStatusPill status={reliability} />
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
        {quotes.map((quote) => (
          <a
            key={quote.symbol}
            href={`/market/ticker/${encodeURIComponent(quote.symbol)}`}
            className="min-w-0 rounded-[8px] border border-slate-700 bg-black p-3 transition hover:border-blue-400"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="font-mono text-sm font-black text-white">{quote.symbol}</p>
                <p className="truncate text-xs font-semibold text-slate-300">{quote.name}</p>
              </div>
              {quote.changePct !== null && quote.changePct >= 0 ? (
                <TrendingUp className="h-4 w-4 shrink-0 text-emerald-300" />
              ) : (
                <TrendingDown className="h-4 w-4 shrink-0 text-red-300" />
              )}
            </div>
            <p className="mt-2 font-mono text-lg font-black text-white">{formatNumber(quote.price)}</p>
            <p className={`mt-1 font-mono text-xs font-black ${toneForChange(quote.changePct)}`}>
              {formatSignedPct(quote.changePct)} · 5d {formatSignedPct(quote.change5dPct)} · 1m {formatSignedPct(quote.change1mPct)}
            </p>
            <p className="mt-2 line-clamp-2 text-[11px] leading-4 text-slate-300">{quote.note}</p>
          </a>
        ))}
      </div>
    </section>
  );
}

function StatusBadge({ status, compact }: { status: SignalStatus; compact?: boolean }) {
  const cls =
    status === 'bottom'
      ? 'border-emerald-400/40 bg-emerald-500/15 text-emerald-200'
      : status === 'watch'
        ? 'border-blue-400/40 bg-blue-500/15 text-blue-200'
        : status === 'risk'
          ? 'border-red-400/40 bg-red-500/15 text-red-200'
          : 'border-slate-600 bg-slate-800 text-slate-300';
  const label = status === 'bottom' ? '底部信号' : status === 'watch' ? '开始关注' : status === 'risk' ? '危险' : '暂无数据';

  return (
    <span className={`inline-flex items-center rounded-[6px] border px-2.5 py-1 text-xs font-black ${cls} ${compact ? 'uppercase tracking-[0.12em]' : ''}`}>
      {label}
    </span>
  );
}

function SourceStatusPill({ status }: { status: 'ok' | 'partial' | 'unavailable' }) {
  const cls =
    status === 'ok'
      ? 'border-emerald-400/40 bg-emerald-500/15 text-emerald-200'
      : status === 'partial'
        ? 'border-blue-400/40 bg-blue-500/15 text-blue-200'
        : 'border-slate-600 bg-slate-800 text-slate-300';
  const label = status === 'ok' ? 'LIVE' : status === 'partial' ? 'PARTIAL' : 'NO DATA';

  return (
    <span className={`inline-flex items-center rounded-[6px] border px-2.5 py-1 text-xs font-black uppercase tracking-[0.12em] ${cls}`}>
      {label}
    </span>
  );
}

function toneForChange(value: number | null) {
  if (value === null || !Number.isFinite(value)) return 'text-slate-300';
  if (value > 0) return 'text-emerald-300';
  if (value < 0) return 'text-red-300';
  return 'text-blue-300';
}

function formatNumber(value: number | null, digits = 2) {
  if (value === null || !Number.isFinite(value)) return '--';
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
}

function formatSigned(value: number | null) {
  if (value === null || !Number.isFinite(value)) return '--';
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}`;
}

function formatSignedPct(value: number | null) {
  if (value === null || !Number.isFinite(value)) return '--';
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function formatCompact(value: number | null) {
  if (value === null || !Number.isFinite(value)) return '--';
  return new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(value);
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}
