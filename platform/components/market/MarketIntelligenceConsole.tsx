'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Clock3,
  FileText,
  Gauge,
  Loader2,
  Radio,
  SatelliteDish,
  Search,
  ShieldCheck,
  Siren,
  TrendingDown,
  TrendingUp,
  Users,
} from 'lucide-react';
import type { MarketResearchReport, MarketSourceKind, SignalAction, StrategyMode } from '@/lib/market-intelligence/types';

const DEFAULT_QUERY =
  'Reuters breaking news, X influencer posts, Truth Social provider events, AI chips, Tesla, crypto, Fed rates, unusual market tape';
const DEFAULT_WATCHLIST = 'NVDA, AMD, TSLA, PLTR, COIN, MSFT, AVGO';

export function MarketIntelligenceConsole() {
  const [query, setQuery] = useState(DEFAULT_QUERY);
  const [watchlist, setWatchlist] = useState(DEFAULT_WATCHLIST);
  const [horizon, setHorizon] = useState<'intraday' | 'swing' | 'long_term'>('intraday');
  const [mode, setMode] = useState<StrategyMode>('paper');
  const [report, setReport] = useState<MarketResearchReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const parsedWatchlist = useMemo(
    () =>
      watchlist
        .split(/[\s,]+/)
        .map((ticker) => ticker.replace(/^\$/, '').trim().toUpperCase())
        .filter(Boolean)
        .slice(0, 30),
    [watchlist]
  );

  const readiness = useMemo(() => {
    if (!report) return { on: 0, total: 0, pct: 0 };
    const productionSources = report.sources.filter((source) => source.productionReady);
    return {
      on: productionSources.length,
      total: report.sources.length,
      pct: Math.round((productionSources.length / Math.max(1, report.sources.length)) * 100),
    };
  }, [report]);

  async function runResearch(event?: FormEvent) {
    event?.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await fetch('/api/strategy/run', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, watchlist: parsedWatchlist, horizon, mode }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || 'Strategy run failed.');
      setReport(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Strategy run failed.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void runResearch();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="space-y-5">
      <form
        onSubmit={runResearch}
        className="grid gap-4 rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-2xl shadow-black/35 xl:grid-cols-[1.15fr_0.7fr_0.48fr_auto]"
      >
        <label className="space-y-2">
          <span className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.16em] text-cyan-200">
            <Search className="h-4 w-4" /> Strategy universe
          </span>
          <textarea
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            rows={3}
            className="min-h-[96px] w-full resize-none rounded-[8px] border border-slate-600 bg-slate-950 px-3 py-3 text-sm leading-6 text-white outline-none transition focus:border-cyan-300"
            maxLength={600}
          />
        </label>

        <label className="space-y-2">
          <span className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.16em] text-emerald-200">
            <Radio className="h-4 w-4" /> Watchlist
          </span>
          <textarea
            value={watchlist}
            onChange={(event) => setWatchlist(event.target.value)}
            rows={3}
            className="min-h-[96px] w-full resize-none rounded-[8px] border border-slate-600 bg-slate-950 px-3 py-3 text-sm leading-6 text-white outline-none transition focus:border-emerald-300"
          />
        </label>

        <div className="grid gap-3">
          <Segmented
            label="horizon"
            icon={<Clock3 className="h-4 w-4" />}
            value={horizon}
            onChange={(value) => setHorizon(value as typeof horizon)}
            options={[
              ['intraday', 'Day'],
              ['swing', 'Swing'],
              ['long_term', 'Long'],
            ]}
          />
          <Segmented
            label="mode"
            icon={<Siren className="h-4 w-4" />}
            value={mode}
            onChange={(value) => setMode(value as StrategyMode)}
            options={[
              ['paper', 'Paper'],
              ['live_signal', 'Signal'],
            ]}
          />
        </div>

        <div className="flex xl:items-end">
          <button
            type="submit"
            disabled={loading}
            className="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[8px] bg-cyan-300 px-5 text-sm font-black text-slate-950 shadow-lg shadow-cyan-950/30 transition hover:bg-cyan-200 disabled:cursor-not-allowed disabled:opacity-60 xl:w-auto"
          >
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Activity className="h-4 w-4" />}
            Run strategy
          </button>
        </div>
      </form>

      {error ? (
        <div className="rounded-[8px] border border-rose-300/40 bg-rose-950/30 p-4 text-sm text-rose-100">
          {error}
        </div>
      ) : null}

      {report ? (
        <>
          <section className="grid gap-4 xl:grid-cols-[1fr_0.72fr_0.72fr]">
            <Panel>
              <div className="mb-3 flex flex-wrap items-center gap-2">
                <StatusPill allowed={report.compliance.allowed} severity={report.compliance.severity} />
                <span className="rounded-[6px] border border-white/10 px-2 py-1 text-xs font-bold text-white/55">
                  {new Date(report.generatedAt).toLocaleString()}
                </span>
                <span className="rounded-[6px] bg-cyan-300/12 px-2 py-1 text-xs font-black uppercase tracking-[0.12em] text-cyan-100">
                  {report.mode}
                </span>
              </div>
              <h2 className="text-2xl font-black tracking-tight text-white">Strategy Brief</h2>
              <p className="mt-3 text-sm leading-7 text-white/72">{report.brief}</p>
              <p className="mt-4 border-t border-white/10 pt-3 text-xs leading-5 text-white/45">{report.disclaimer}</p>
            </Panel>

            <Panel>
              <MetricHeader icon={<Gauge className="h-5 w-5 text-cyan-200" />} title="Readiness" />
              <div className="grid grid-cols-3 gap-3">
                <Metric label="sources on" value={`${readiness.on}/${readiness.total}`} />
                <Metric label="coverage" value={`${readiness.pct}%`} />
                <Metric label="signals" value={String(report.signals.length)} />
              </div>
              <div className="mt-4 h-2 overflow-hidden rounded-full bg-white/8">
                <div className="h-full bg-cyan-300" style={{ width: `${readiness.pct}%` }} />
              </div>
              <p className="mt-3 text-xs leading-5 text-white/45">
                Production readiness means credentials are configured for licensed/authorized providers. SEC EDGAR is public and always on.
              </p>
            </Panel>

            <Panel>
              <MetricHeader icon={<ShieldCheck className="h-5 w-5 text-emerald-300" />} title="Risk Frame" />
              <div className="grid grid-cols-2 gap-3">
                <Metric label="stance" value={report.decisionFrame.stance} />
                <Metric label="confidence" value={`${report.decisionFrame.confidence}/100`} />
              </div>
              <ul className="mt-4 space-y-2 text-sm leading-6 text-white/62">
                {report.decisionFrame.rationale.slice(0, 3).map((item) => (
                  <li key={item} className="flex gap-2">
                    <CheckCircle2 className="mt-1 h-4 w-4 shrink-0 text-emerald-300" />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </Panel>
          </section>

          <section className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
            <div className="space-y-3">
              <MetricHeader icon={<Activity className="h-5 w-5 text-cyan-200" />} title="Signal Blotter" />
              <div className="grid gap-3">
                {report.signals.length ? (
                  report.signals.map((signal) => (
                    <article key={signal.id} className="rounded-[8px] border border-white/12 bg-slate-950/55 p-4">
                      <div className="flex flex-wrap items-start justify-between gap-3">
                        <div>
                          <div className="flex flex-wrap items-center gap-2">
                            <ActionBadge action={signal.action} />
                            <h3 className="text-xl font-black text-white">${signal.ticker}</h3>
                            <span className="rounded-[6px] bg-white/8 px-2 py-1 text-xs font-black uppercase tracking-[0.12em] text-white/45">
                              {signal.horizon}
                            </span>
                          </div>
                          <p className="mt-2 text-sm leading-6 text-white/68">{signal.thesis}</p>
                        </div>
                        <div className="grid grid-cols-2 gap-2">
                          <Score label="score" value={signal.score} tone="cyan" />
                          <Score label="conf" value={signal.confidence} tone="emerald" />
                        </div>
                      </div>
                      <p className="mt-3 text-xs leading-5 text-amber-100/70">{signal.invalidation}</p>
                      {signal.riskFlags.length ? (
                        <div className="mt-3 flex flex-wrap gap-2">
                          {signal.riskFlags.map((flag) => (
                            <span key={flag} className="rounded-[6px] bg-amber-300/10 px-2 py-1 text-[11px] font-bold text-amber-100/75">
                              {flag}
                            </span>
                          ))}
                        </div>
                      ) : null}
                    </article>
                  ))
                ) : (
                  <EmptyState text="No signals. Connect live sources or add a watchlist." />
                )}
              </div>
            </div>

            <div className="space-y-4">
              <Panel>
                <MetricHeader icon={<SatelliteDish className="h-5 w-5 text-cyan-200" />} title="Source Mesh" />
                <div className="mt-3 space-y-2">
                  {report.sources.map((source) => (
                    <div key={source.id} className="flex items-center justify-between gap-3 rounded-[8px] bg-black/20 px-3 py-2">
                      <div className="min-w-0">
                        <p className="truncate text-xs font-black text-white">{source.name}</p>
                        <p className="truncate text-[11px] text-white/40">{source.coverage}</p>
                      </div>
                      <span
                        className={`shrink-0 rounded-[6px] px-2 py-1 text-[10px] font-black uppercase tracking-[0.12em] ${
                          source.productionReady ? 'bg-emerald-300/15 text-emerald-200' : 'bg-white/8 text-white/35'
                        }`}
                      >
                        {source.productionReady ? 'live' : 'key'}
                      </span>
                    </div>
                  ))}
                </div>
              </Panel>

              <Panel>
                <MetricHeader icon={<Users className="h-5 w-5 text-pink-200" />} title="Influencer Monitor" />
                <div className="mt-3 grid gap-2">
                  {report.influencers.map((influencer) => (
                    <div key={influencer.id} className="rounded-[8px] bg-black/20 px-3 py-2">
                      <div className="flex items-center justify-between gap-3">
                        <p className="text-xs font-black text-white">{influencer.displayName}</p>
                        <span
                          className={`rounded-[6px] px-2 py-1 text-[10px] font-black uppercase tracking-[0.12em] ${
                            influencer.enabled ? 'bg-emerald-300/15 text-emerald-200' : 'bg-white/8 text-white/35'
                          }`}
                        >
                          {influencer.enabled ? 'armed' : 'handle'}
                        </span>
                      </div>
                      <p className="mt-1 text-[11px] leading-5 text-white/40">
                        {influencer.xHandle ? `X @${influencer.xHandle}` : 'X handle unset'}
                        {influencer.truthHandle ? ` - Truth @${influencer.truthHandle}` : ''}
                      </p>
                    </div>
                  ))}
                </div>
              </Panel>
            </div>
          </section>

          <section className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
            <div className="space-y-3">
              <MetricHeader icon={<Siren className="h-5 w-5 text-rose-200" />} title="Ranked Event Tape" />
              {report.events.map((event) => (
                <article key={event.id} className="rounded-[8px] border border-white/12 bg-slate-950/55 p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="break-words text-base font-black text-white">{event.title}</h3>
                      <p className="mt-1 text-xs font-bold uppercase tracking-[0.12em] text-white/38">
                        {event.sourceName} - {event.verification} - {new Date(event.publishedAt).toLocaleString()}
                      </p>
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <Score label="mat" value={event.materiality} tone="cyan" />
                      <Score label="conf" value={event.confidence} tone="emerald" />
                    </div>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-white/68">{event.summary}</p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    {event.tickers.map((ticker) => (
                      <span key={ticker} className="rounded-[6px] bg-cyan-300/12 px-2 py-1 text-xs font-black text-cyan-100">
                        ${ticker}
                      </span>
                    ))}
                    <span className="rounded-[6px] bg-white/8 px-2 py-1 text-xs font-black text-white/62">
                      {event.sentiment}
                    </span>
                    <span className="rounded-[6px] bg-white/8 px-2 py-1 text-xs font-black text-white/62">
                      {labelForKind(event.sourceKind)}
                    </span>
                  </div>
                  {event.url ? (
                    <a
                      href={event.url}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-3 inline-flex items-center gap-2 text-xs font-black text-cyan-200 underline-offset-4 hover:underline"
                    >
                      <FileText className="h-4 w-4" /> Source
                    </a>
                  ) : null}
                </article>
              ))}
            </div>

            <Panel>
              <MetricHeader icon={<CheckCircle2 className="h-5 w-5 text-emerald-300" />} title="Next Checks" />
              <ul className="mt-3 space-y-2 text-sm leading-6 text-white/62">
                {report.decisionFrame.nextChecks.map((item) => (
                  <li key={item} className="flex gap-2">
                    <CheckCircle2 className="mt-1 h-4 w-4 shrink-0 text-emerald-300" />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-5 border-t border-white/10 pt-4">
                <h3 className="text-sm font-black text-white">Audit trail</h3>
                <ul className="mt-3 space-y-2 text-xs leading-5 text-white/48">
                  {report.audit.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </div>
            </Panel>
          </section>
        </>
      ) : null}
    </div>
  );
}

function Segmented({
  label,
  icon,
  value,
  options,
  onChange,
}: {
  label: string;
  icon: React.ReactNode;
  value: string;
  options: string[][];
  onChange: (value: string) => void;
}) {
  return (
    <div className="space-y-2">
      <span className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.16em] text-amber-200">
        {icon} {label}
      </span>
      <div className="grid grid-cols-2 rounded-[8px] border border-slate-600 bg-slate-950 p-1">
        {options.map(([optionValue, optionLabel]) => (
          <button
            key={optionValue}
            type="button"
            onClick={() => onChange(optionValue)}
            className={`min-h-9 rounded-[6px] text-xs font-black transition ${
              value === optionValue ? 'bg-cyan-300 text-slate-950' : 'text-white/65 hover:bg-white/8 hover:text-white'
            }`}
          >
            {optionLabel}
          </button>
        ))}
      </div>
    </div>
  );
}

function Panel({ children }: { children: React.ReactNode }) {
  return <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-5 shadow-inner shadow-black/30">{children}</div>;
}

function MetricHeader({ icon, title }: { icon: React.ReactNode; title: string }) {
  return (
    <div className="mb-4 flex items-center gap-2 text-sm font-black text-white">
      {icon} {title}
    </div>
  );
}

function StatusPill({ allowed, severity }: { allowed: boolean; severity: string }) {
  if (!allowed) {
    return (
      <span className="inline-flex items-center gap-2 rounded-[6px] bg-rose-300/12 px-3 py-1.5 text-xs font-black uppercase tracking-[0.14em] text-rose-200">
        <AlertTriangle className="h-4 w-4" /> blocked
      </span>
    );
  }

  return (
    <span
      className={`inline-flex items-center gap-2 rounded-[6px] px-3 py-1.5 text-xs font-black uppercase tracking-[0.14em] ${
        severity === 'caution' ? 'bg-amber-300/14 text-amber-100' : 'bg-emerald-300/14 text-emerald-100'
      }`}
    >
      <ShieldCheck className="h-4 w-4" /> {severity}
    </span>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[8px] bg-black/25 p-3">
      <p className="text-[10px] font-black uppercase tracking-[0.16em] text-white/35">{label}</p>
      <p className="mt-1 break-words text-lg font-black text-white">{value}</p>
    </div>
  );
}

function Score({ label, value, tone }: { label: string; value: number; tone: 'cyan' | 'emerald' }) {
  const color = tone === 'cyan' ? 'text-cyan-100 bg-cyan-300/12' : 'text-emerald-100 bg-emerald-300/12';
  return (
    <span className={`inline-flex min-w-[68px] flex-col items-center rounded-[8px] px-2 py-1 ${color}`}>
      <span className="text-[9px] font-black uppercase tracking-[0.14em] opacity-70">{label}</span>
      <span className="text-sm font-black">{value}</span>
    </span>
  );
}

function ActionBadge({ action }: { action: SignalAction }) {
  const styles: Record<SignalAction, string> = {
    PAPER_LONG: 'bg-emerald-300/15 text-emerald-200',
    PAPER_SHORT: 'bg-rose-300/15 text-rose-200',
    WATCH: 'bg-cyan-300/15 text-cyan-100',
    RISK_OFF: 'bg-amber-300/15 text-amber-100',
    NO_TRADE: 'bg-white/8 text-white/45',
  };
  const Icon = action === 'PAPER_SHORT' ? TrendingDown : action === 'PAPER_LONG' ? TrendingUp : ShieldCheck;
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-[6px] px-2 py-1 text-xs font-black uppercase tracking-[0.12em] ${styles[action]}`}>
      <Icon className="h-3.5 w-3.5" /> {action.replace('_', ' ')}
    </span>
  );
}

function EmptyState({ text }: { text: string }) {
  return <div className="rounded-[8px] border border-dashed border-slate-700 bg-slate-950 p-6 text-sm font-semibold text-slate-300">{text}</div>;
}

function labelForKind(kind: MarketSourceKind) {
  const labels: Record<MarketSourceKind, string> = {
    sec_edgar: 'SEC',
    reuters_lseg: 'Reuters',
    news_api: 'News',
    x_api: 'X',
    truth_social: 'Truth',
    market_tape: 'Tape',
    options_flow: 'Options',
    earnings: 'Earnings',
    polygon: 'Polygon',
    reddit: 'Reddit',
    manual: 'Manual',
    demo: 'Fallback',
  };
  return labels[kind];
}
