'use client';

import { useEffect, useState } from 'react';
import { Activity, AlertTriangle, FileSearch, Landmark, Loader2, Newspaper, TrendingDown, TrendingUp } from 'lucide-react';
import type { MacroReport, MacroSeries } from '@/lib/market-intelligence/macro';
import type { InsiderFiling, InsiderReport } from '@/lib/market-intelligence/insider';
import type { NewsPulseReport, TickerPulse } from '@/lib/market-intelligence/news-pulse';

export function FreeDataPanels() {
  const [macro, setMacro] = useState<MacroReport | null>(null);
  const [insider, setInsider] = useState<InsiderReport | null>(null);
  const [news, setNews] = useState<NewsPulseReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      try {
        const [macroRes, insiderRes, newsRes] = await Promise.allSettled([
          fetch('/api/market/macro').then((r) => r.json()),
          fetch('/api/market/insider').then((r) => r.json()),
          fetch('/api/market/news-pulse').then((r) => r.json()),
        ]);
        if (cancelled) return;
        if (macroRes.status === 'fulfilled' && !macroRes.value.error) setMacro(macroRes.value);
        if (insiderRes.status === 'fulfilled' && !insiderRes.value.error) setInsider(insiderRes.value);
        if (newsRes.status === 'fulfilled' && !newsRes.value.error) setNews(newsRes.value);
        if (
          macroRes.status === 'rejected' &&
          insiderRes.status === 'rejected' &&
          newsRes.status === 'rejected'
        ) {
          setError('全部免费数据源当前不可达。');
        }
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : 'fetch failed');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="space-y-5">
      {loading ? (
        <div className="flex items-center gap-2 rounded-[8px] border border-slate-700 bg-slate-950 p-4 text-sm text-slate-300">
          <Loader2 className="h-4 w-4 animate-spin" /> 正在加载宏观、内部人交易、新闻脉冲...
        </div>
      ) : null}

      {error ? (
        <div className="rounded-[8px] border border-red-400/40 bg-red-950/60 p-4 text-sm text-red-100">{error}</div>
      ) : null}

      <MacroPanel macro={macro} />
      <InsiderPanel insider={insider} />
      <NewsPulsePanel news={news} />
    </div>
  );
}

function MacroPanel({ macro }: { macro: MacroReport | null }) {
  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/30">
      <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Landmark className="h-5 w-5 text-blue-300" />
          <h2 className="text-lg font-black text-white">宏观面板 (FRED)</h2>
        </div>
        {macro?.recessionSignals?.length ? (
          <span className="inline-flex items-center gap-1 rounded-[6px] border border-red-400/40 bg-red-500/15 px-3 py-1 text-xs font-black text-red-200">
            <AlertTriangle className="h-3.5 w-3.5" /> 衰退先行信号 {macro.recessionSignals.length}
          </span>
        ) : null}
      </header>
      {!macro ? (
        <p className="text-sm text-slate-300">暂无可靠数据。</p>
      ) : (
        <>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {macro.series.map((s) => (
              <MacroCard key={s.id} series={s} />
            ))}
          </div>
          {macro.recessionSignals.length ? (
            <ul className="mt-4 space-y-1 rounded-[8px] border border-red-400/30 bg-red-950/40 p-3 text-sm text-red-100">
              {macro.recessionSignals.map((sig) => (
                <li key={sig}>• {sig}</li>
              ))}
            </ul>
          ) : null}
          <p className="mt-4 border-t border-slate-800 pt-3 text-xs leading-5 text-slate-400">{macro.disclaimer}</p>
        </>
      )}
    </section>
  );
}

function MacroCard({ series }: { series: MacroSeries }) {
  const trendIcon =
    series.changeAbs === null
      ? null
      : series.changeAbs >= 0
        ? <TrendingUp className="h-4 w-4 text-emerald-300" />
        : <TrendingDown className="h-4 w-4 text-red-300" />;
  return (
    <a
      href={series.sourceUrl}
      target="_blank"
      rel="noreferrer"
      className={`min-w-0 rounded-[8px] border p-3 transition ${
        series.recessionFlag
          ? 'border-red-400/50 bg-red-950/40 hover:border-red-300'
          : 'border-slate-800 bg-black hover:border-blue-400'
      }`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="text-sm font-black text-white">{series.title}</p>
          <p className="font-mono text-[10px] uppercase tracking-wider text-slate-400">{series.id}</p>
        </div>
        {trendIcon}
      </div>
      <p className="mt-2 font-mono text-2xl font-black text-white">
        {series.latest === null ? '暂无' : `${formatLatest(series)}${series.unit && !['index', ''].includes(series.unit) ? ` ${series.unit}` : ''}`}
      </p>
      {series.yoyPct !== null ? (
        <p className={`mt-1 font-mono text-xs ${series.yoyPct >= 0 ? 'text-emerald-300' : 'text-red-300'}`}>
          YoY {series.yoyPct >= 0 ? '+' : ''}{series.yoyPct.toFixed(2)}%
        </p>
      ) : null}
      <p className="mt-2 text-xs leading-5 text-slate-300">{series.interpretation}</p>
      {series.threshold ? (
        <p className="mt-2 border-t border-slate-800 pt-2 text-[11px] text-slate-400">{series.threshold}</p>
      ) : null}
      <p className="mt-2 text-[10px] text-slate-400">{series.asOf ? `数据日期 ${series.asOf}` : 'asOf unknown'}</p>
    </a>
  );
}

function formatLatest(s: MacroSeries) {
  if (s.latest === null) return '暂无';
  if (s.id === 'CPIAUCSL' || s.id === 'M2SL') return new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 }).format(s.latest);
  return s.latest.toFixed(2);
}

function InsiderPanel({ insider }: { insider: InsiderReport | null }) {
  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/30">
      <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <FileSearch className="h-5 w-5 text-amber-300" />
          <h2 className="text-lg font-black text-white">内部人交易 Form 4 (SEC EDGAR)</h2>
        </div>
        <SourcePill status={insider?.reliability || 'unavailable'} />
      </header>
      {!insider ? (
        <p className="text-sm text-slate-300">暂无可靠数据。</p>
      ) : (
        <>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[700px] text-left">
              <thead>
                <tr className="text-xs font-black uppercase tracking-[0.12em] text-slate-300">
                  <th className="border-b border-slate-800 py-2 pr-3">Ticker</th>
                  <th className="border-b border-slate-800 py-2 pr-3 text-right">90d 申报</th>
                  <th className="border-b border-slate-800 py-2 pr-3 text-right">近期总数</th>
                  <th className="border-b border-slate-800 py-2 pr-3">最新申报</th>
                  <th className="border-b border-slate-800 py-2 text-right">日期</th>
                </tr>
              </thead>
              <tbody>
                {insider.summaries
                  .slice()
                  .sort((a, b) => b.totalFilings90d - a.totalFilings90d)
                  .map((sum) => (
                    <tr key={sum.ticker} className="text-sm text-slate-100">
                      <td className="border-b border-slate-900 py-2 pr-3 font-mono font-black text-white">
                        {sum.ticker}
                      </td>
                      <td className="border-b border-slate-900 py-2 pr-3 text-right font-mono font-black">
                        {sum.totalFilings90d}
                      </td>
                      <td className="border-b border-slate-900 py-2 pr-3 text-right font-mono text-slate-300">
                        {sum.totalFilingsAllRecent}
                      </td>
                      <td className="border-b border-slate-900 py-2 pr-3">
                        {sum.latest ? (
                          <a href={sum.latest.url} target="_blank" rel="noreferrer" className="text-xs font-bold text-blue-300 underline-offset-4 hover:underline">
                            {sum.latest.primaryDocDescription || sum.latest.accession}
                          </a>
                        ) : (
                          <span className="text-xs text-slate-400">暂无近期 Form 4</span>
                        )}
                      </td>
                      <td className="border-b border-slate-900 py-2 text-right font-mono text-slate-300">
                        {sum.latest?.filedAt || '--'}
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
          <details className="mt-4 rounded-[8px] border border-slate-800 bg-black p-3 text-sm text-slate-200">
            <summary className="cursor-pointer font-black text-white">最近 15 笔 Form 4 申报</summary>
            <ul className="mt-2 space-y-1">
              {insider.topRecent.map((f) => (
                <InsiderFilingRow key={`${f.ticker}-${f.accession}`} filing={f} />
              ))}
            </ul>
          </details>
          <p className="mt-4 border-t border-slate-800 pt-3 text-xs leading-5 text-slate-400">{insider.disclaimer}</p>
        </>
      )}
    </section>
  );
}

function InsiderFilingRow({ filing }: { filing: InsiderFiling }) {
  return (
    <li className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-900 py-1 text-xs">
      <span className="font-mono font-black text-white">{filing.ticker}</span>
      <span className="font-mono text-slate-300">Form {filing.form}</span>
      <span className="text-slate-400">{filing.filedAt}</span>
      <a href={filing.url} target="_blank" rel="noreferrer" className="text-blue-300 underline-offset-4 hover:underline">
        {filing.primaryDocDescription}
      </a>
    </li>
  );
}

function NewsPulsePanel({ news }: { news: NewsPulseReport | null }) {
  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/30">
      <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Newspaper className="h-5 w-5 text-emerald-300" />
          <h2 className="text-lg font-black text-white">新闻脉冲 (Hacker News + GDELT)</h2>
        </div>
        <div className="flex gap-2">
          <ChipPill label="HN" status={news?.reliability.hackernews || 'unavailable'} />
          <ChipPill label="GDELT" status={news?.reliability.gdelt || 'unavailable'} />
        </div>
      </header>
      {!news ? (
        <p className="text-sm text-slate-300">暂无可靠数据。</p>
      ) : (
        <>
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {news.pulses.filter((p) => p.total > 0).slice(0, 9).map((pulse) => (
              <TickerPulseCard key={pulse.ticker} pulse={pulse} />
            ))}
            {news.pulses.every((p) => p.total === 0) ? (
              <p className="text-sm text-slate-300">近 7 日所有 ticker 均无显著公开新闻命中。</p>
            ) : null}
          </div>
          <p className="mt-4 border-t border-slate-800 pt-3 text-xs leading-5 text-slate-400">{news.disclaimer}</p>
        </>
      )}
    </section>
  );
}

function TickerPulseCard({ pulse }: { pulse: TickerPulse }) {
  return (
    <article className="rounded-[8px] border border-slate-800 bg-black p-3">
      <div className="flex items-center justify-between">
        <strong className="font-mono text-base font-black text-white">{pulse.ticker}</strong>
        <span className="font-mono text-xs text-slate-400">
          HN {pulse.hnCount} · GDELT {pulse.gdeltCount}
        </span>
      </div>
      {pulse.averageTone !== null ? (
        <p
          className={`mt-1 font-mono text-xs ${
            pulse.averageTone > 1 ? 'text-emerald-300' : pulse.averageTone < -1 ? 'text-red-300' : 'text-slate-300'
          }`}
        >
          tone {pulse.averageTone >= 0 ? '+' : ''}{pulse.averageTone.toFixed(2)}
        </p>
      ) : null}
      <p className="mt-2 text-xs text-slate-200">{pulse.interpretation}</p>
      <ul className="mt-2 space-y-1">
        {pulse.topItems.slice(0, 3).map((item) => (
          <li key={item.id} className="text-xs leading-5">
            <a
              href={item.url}
              target="_blank"
              rel="noreferrer"
              className="text-blue-300 underline-offset-4 hover:underline"
            >
              {item.title.length > 90 ? `${item.title.slice(0, 90)}…` : item.title}
            </a>
            <span className="ml-2 font-mono text-[10px] text-slate-400">
              {item.source === 'hackernews' ? 'HN' : item.domain || 'GDELT'}
            </span>
          </li>
        ))}
      </ul>
    </article>
  );
}

function SourcePill({ status }: { status: 'ok' | 'partial' | 'unavailable' }) {
  const cls =
    status === 'ok'
      ? 'border-emerald-400/40 bg-emerald-500/15 text-emerald-200'
      : status === 'partial'
        ? 'border-blue-400/40 bg-blue-500/15 text-blue-200'
        : 'border-slate-600 bg-slate-800 text-slate-300';
  const label = status === 'ok' ? 'LIVE' : status === 'partial' ? 'PARTIAL' : 'NO DATA';
  return (
    <span className={`inline-flex items-center gap-1 rounded-[6px] border px-2.5 py-1 text-xs font-black uppercase tracking-[0.12em] ${cls}`}>
      <Activity className="h-3 w-3" /> {label}
    </span>
  );
}

function ChipPill({ label, status }: { label: string; status: 'ok' | 'unavailable' }) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-[6px] border px-2 py-1 text-[11px] font-black uppercase tracking-[0.12em] ${
        status === 'ok' ? 'border-emerald-400/40 bg-emerald-500/15 text-emerald-200' : 'border-slate-600 bg-slate-800 text-slate-300'
      }`}
    >
      {label} {status === 'ok' ? 'LIVE' : 'NO DATA'}
    </span>
  );
}
