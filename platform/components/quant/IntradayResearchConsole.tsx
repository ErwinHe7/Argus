'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  BarChart3,
  CheckCircle2,
  Clock3,
  Database,
  FlaskConical,
  Layers3,
  Loader2,
  Play,
  RefreshCw,
  ShieldCheck,
  Sigma,
  XCircle,
} from 'lucide-react';
import type {
  AnalogCase,
  AuditRow,
  CandidateDecision,
  IntradayMetrics,
  IntradayOverview,
  IntradayRun,
  IntradayTrade,
  ModelDiagnostic,
  TimeBucketEffect,
} from '@/lib/quant/intraday-types';

const API = '/api/quant/intraday';

export function IntradayResearchConsole() {
  const [overview, setOverview] = useState<IntradayOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [profile, setProfile] = useState<'massive' | 'licensed'>('massive');

  const loadOverview = useCallback(async (requestedProfile?: string) => {
    setLoading(true);
    setError(null);
    try {
      const query = requestedProfile ? `?profile=${encodeURIComponent(requestedProfile)}` : '';
      const response = await fetch(`${API}/overview${query}`, { cache: 'no-store' });
      const payload = (await response.json()) as IntradayOverview & { error?: string; detail?: string };
      if (!response.ok) throw new Error(payload.detail || payload.error || `HTTP ${response.status}`);
      setOverview(payload);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadOverview();
  }, [loadOverview]);

  const startRun = async () => {
    setRunning(true);
    setError(null);
    try {
      const response = await fetch(`${API}/runs`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ profile }),
      });
      const payload = (await response.json()) as { run_id?: string; error?: string; detail?: string };
      if (!response.ok || !payload.run_id) {
        throw new Error(payload.detail || payload.error || `HTTP ${response.status}`);
      }
      await pollRun(payload.run_id);
      await loadOverview(profile);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setRunning(false);
    }
  };

  const pollRun = async (runId: string) => {
    for (let attempt = 0; attempt < 180; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 2_000));
      const response = await fetch(`${API}/runs/${encodeURIComponent(runId)}`, { cache: 'no-store' });
      const run = (await response.json()) as IntradayRun & { detail?: string };
      if (!response.ok) throw new Error(run.detail || `Run polling failed: HTTP ${response.status}`);
      if (run.status === 'completed') return;
      if (run.status === 'failed') throw new Error(run.error_message || 'Research run failed.');
    }
    throw new Error('Research run exceeded the 6 minute dashboard polling window.');
  };

  if (loading && !overview) return <LoadingState />;
  if (!overview?.run) {
    return (
      <EmptyState
        error={error}
        running={running}
        profile={profile}
        setProfile={setProfile}
        startRun={startRun}
        retry={() => loadOverview()}
      />
    );
  }

  const run = overview.run;
  const metrics = overview.metrics || {};
  const candidates = overview.candidates || [];
  const hypothesisRows = Array.isArray(overview.audits)
    ? overview.audits.filter((item) => item.audit_type === 'hypothesis_event')
    : [];
  const timeBucketEffects = !Array.isArray(overview.audits)
    ? overview.audits?.time_bucket_reversals || []
    : [];
  const evidenceIsSynthetic = run.evidence_tier.includes('synthetic') || run.evidence_tier.includes('pending');
  const selected = candidates.filter((item) => item.decision === 'selected');
  const rejected = candidates.filter((item) => item.decision === 'rejected');

  return (
    <div className="space-y-5">
      <section className="overflow-hidden rounded-xl border border-slate-700 bg-[#09101d] shadow-2xl shadow-black/25">
        <div className="grid gap-0 xl:grid-cols-[1fr_360px]">
          <div className="p-6 sm:p-8">
            <div className="flex flex-wrap items-center gap-2">
              <StatusPill run={run} />
              <span className="rounded border border-slate-600 bg-slate-950 px-2.5 py-1 font-mono text-[10px] font-bold uppercase tracking-[0.14em] text-slate-300">
                {run.source_mode}
              </span>
              <span className="rounded border border-slate-600 bg-slate-950 px-2.5 py-1 font-mono text-[10px] font-bold uppercase tracking-[0.14em] text-slate-300">
                Run {run.run_id.slice(0, 12)}
              </span>
            </div>
            <h2 className="mt-5 text-3xl font-black tracking-tight text-white sm:text-4xl">
              SPX 分钟级研究终端
            </h2>
            <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-300">
              每分钟建模市场状态，但只允许验证阈值之上的 0–2 笔交易。信号在 t 分钟收盘生成，
              最早 t+1 成交；相似历史只搜索过去；期权只接受真实 NBBO。
            </p>
            <EvidenceBanner synthetic={evidenceIsSynthetic} metrics={metrics} />
          </div>
          <div className="border-t border-slate-700 bg-[#050911] p-6 xl:border-l xl:border-t-0">
            <p className="font-mono text-[10px] font-black uppercase tracking-[0.16em] text-slate-500">
              Experiment control
            </p>
            <label className="mt-4 block text-xs font-bold text-slate-300">
              运行配置
              <select
                value={profile}
                onChange={(event) => setProfile(event.target.value as typeof profile)}
                className="mt-2 w-full rounded-md border border-slate-700 bg-slate-950 px-3 py-2.5 font-mono text-xs text-white outline-none focus:border-cyan-400"
              >
                <option value="licensed">Licensed historical data</option>
                <option value="massive">Massive real stock aggregates</option>
              </select>
            </label>
            <button
              type="button"
              onClick={startRun}
              disabled={running}
              className="mt-3 inline-flex w-full items-center justify-center gap-2 rounded-md border border-cyan-300/70 bg-cyan-400/15 px-4 py-3 text-xs font-black uppercase tracking-[0.12em] text-cyan-100 hover:bg-cyan-400/25 disabled:cursor-wait disabled:opacity-60"
            >
              {running ? <Loader2 className="h-4 w-4 animate-spin" /> : <Play className="h-4 w-4" />}
              {running ? 'Pipeline running' : 'Run experiment'}
            </button>
            <button
              type="button"
              onClick={() => loadOverview(run.profile)}
              disabled={loading}
              className="mt-2 inline-flex w-full items-center justify-center gap-2 rounded-md border border-slate-700 px-4 py-2.5 text-xs font-bold text-slate-300 hover:border-slate-500 hover:text-white"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} /> Refresh registry
            </button>
            {error ? <p className="mt-3 text-xs leading-5 text-rose-300">{error}</p> : null}
          </div>
        </div>
      </section>

      <ArchitectureStrip />
      <DataBootstrapPanel />
      <MetricGrid metrics={metrics} selected={selected.length} rejected={rejected.length} />

      <div className="grid gap-5 xl:grid-cols-[1.2fr_.8fr]">
        <EquityPanel points={overview.equity || []} />
        <CoveragePanel run={run} metrics={metrics} />
      </div>

      <MathPanel />
      <CurrentHintPanel hint={overview.current_hint} />
      <AnalogPanel rows={overview.analogs || []} run={run} asOf={overview.current_hint?.as_of} />
      <HypothesisPanel rows={hypothesisRows} />
      <TimeBucketEffectPanel rows={timeBucketEffects} />

      <div className="grid gap-5 xl:grid-cols-2">
        <DiagnosticsPanel rows={overview.diagnostics || []} />
        <DecisionPanel candidates={candidates} />
      </div>

      <TradePanel rows={overview.trades || []} optionStatus={run.option_status} />
    </div>
  );
}

function LoadingState() {
  return (
    <div className="flex min-h-[420px] items-center justify-center rounded-xl border border-slate-700 bg-[#09101d]">
      <div className="text-center">
        <Loader2 className="mx-auto h-7 w-7 animate-spin text-cyan-300" />
        <p className="mt-3 font-mono text-xs uppercase tracking-[0.14em] text-slate-400">Loading Rust registry</p>
      </div>
    </div>
  );
}

function EmptyState({
  error,
  running,
  profile,
  setProfile,
  startRun,
  retry,
}: {
  error: string | null;
  running: boolean;
  profile: 'massive' | 'licensed';
  setProfile: (profile: 'massive' | 'licensed') => void;
  startRun: () => void;
  retry: () => void;
}) {
  return (
    <section className="rounded-xl border border-amber-400/30 bg-[#09101d] p-8 text-white">
      <AlertTriangle className="h-8 w-8 text-amber-300" />
      <h2 className="mt-4 text-2xl font-black">尚无真实历史数据回测</h2>
      <p className="mt-2 max-w-2xl text-sm leading-7 text-slate-300">
        {error || 'Rust 后端会拒绝 synthetic 业绩。先同步 Massive 真实历史数据，再启动样本外回测。'}
      </p>
      <DataBootstrapPanel />
      <div className="mt-5 flex flex-wrap gap-3">
        <select
          value={profile}
          onChange={(event) => setProfile(event.target.value as typeof profile)}
          className="rounded-md border border-slate-700 bg-slate-950 px-3 py-2 text-xs"
        >
          <option value="licensed">Licensed historical data</option>
          <option value="massive">Massive real stock aggregates</option>
        </select>
        <button onClick={startRun} disabled={running} className="rounded-md bg-cyan-300 px-4 py-2 text-xs font-black text-slate-950">
          {running ? 'Running…' : 'Run experiment'}
        </button>
        <button onClick={retry} className="rounded-md border border-slate-600 px-4 py-2 text-xs font-bold text-slate-200">Retry API</button>
      </div>
      <pre className="mt-6 overflow-x-auto rounded-md border border-slate-800 bg-black p-4 text-[11px] text-emerald-200">{`cd quant_engine_rs\ncargo run --release --bin quantd -- --config configs/production.yaml`}</pre>
    </section>
  );
}

function DataBootstrapPanel() {
  const [plan, setPlan] = useState<{ massive?: { api_key_present?: boolean; symbols?: string[] } } | null>(null);
  const [coverage, setCoverage] = useState<{ manifest_count?: number; real_vendor_bars_ready?: boolean; truth?: string } | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    Promise.all([
      fetch(`${API}/data/plan`, { cache: 'no-store' }).then((response) => response.json()),
      fetch(`${API}/data/coverage`, { cache: 'no-store' }).then((response) => response.json()),
    ])
      .then(([nextPlan, nextCoverage]) => {
        if (active) {
          setPlan(nextPlan);
          setCoverage(nextCoverage);
        }
      })
      .catch((cause) => {
        if (active) setFailure(cause instanceof Error ? cause.message : String(cause));
      });
    return () => { active = false; };
  }, []);

  const keyReady = Boolean(plan?.massive?.api_key_present);
  const barsReady = Boolean(coverage?.real_vendor_bars_ready);
  return (
    <section className="mt-5 rounded-xl border border-slate-700 bg-[#09101d] p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h3 className="inline-flex items-center gap-2 text-sm font-black uppercase tracking-[0.08em] text-white">
          <Database className="h-4 w-4 text-cyan-300" />真实数据接入
        </h3>
        <span className="font-mono text-[10px] text-slate-500">Massive REST · 1m · adjusted</span>
      </div>
      <div className="mt-4 grid gap-3 sm:grid-cols-3">
        <MiniMetric label="Massive API key" value={keyReady ? 'READY' : 'MISSING'} />
        <MiniMetric label="Normalized bars" value={barsReady ? 'READY' : 'SYNCING / EMPTY'} />
        <MiniMetric label="Sync manifests" value={String(coverage?.manifest_count || 0)} />
      </div>
      <p className="mt-3 text-[11px] leading-5 text-slate-400">
        覆盖标的：{plan?.massive?.symbols?.join(', ') || 'loading…'}。完整同步完成后点击 Run experiment；日常增量运行 quantctl data massive-poll。
      </p>
      {failure ? <p className="mt-2 text-xs text-rose-300">{failure}</p> : null}
    </section>
  );
}

function StatusPill({ run }: { run: IntradayRun }) {
  const completed = run.status === 'completed';
  return (
    <span className={`inline-flex items-center gap-1.5 rounded border px-2.5 py-1 font-mono text-[10px] font-black uppercase tracking-[0.14em] ${completed ? 'border-emerald-400/50 bg-emerald-400/10 text-emerald-200' : 'border-amber-400/50 bg-amber-400/10 text-amber-200'}`}>
      {completed ? <CheckCircle2 className="h-3.5 w-3.5" /> : <Clock3 className="h-3.5 w-3.5" />}
      {run.status}
    </span>
  );
}

function EvidenceBanner({ synthetic, metrics }: { synthetic: boolean; metrics: IntradayMetrics }) {
  const insufficient = (metrics.number_of_trades || 0) < 30;
  return (
    <div className={`mt-5 flex items-start gap-3 rounded-md border p-3.5 ${synthetic ? 'border-amber-400/30 bg-amber-400/8' : 'border-sky-400/30 bg-sky-400/8'}`}>
      <ShieldCheck className={`mt-0.5 h-5 w-5 shrink-0 ${synthetic ? 'text-amber-300' : 'text-sky-300'}`} />
      <p className="text-xs leading-6 text-slate-200">
        <strong className="text-white">证据等级：</strong>{' '}
        {synthetic ? '当前不是授权历史回测，不展示为真实业绩。' : '授权历史数据回测；仍须检查样本外、成本、许可与数据覆盖。'}
        {insufficient ? ' 当前 OOS 交易样本不足，年化与 Sharpe 已主动隐藏。' : ''}
      </p>
    </div>
  );
}

function ArchitectureStrip() {
  const blocks = [
    [Database, '01', 'Data', '1m bars · quality'],
    [Layers3, '02', 'State', 'features · candidates'],
    [Sigma, '03', 'Models', 'Rust analog · calibrated heads'],
    [ShieldCheck, '04', 'Validation', 'purge · embargo'],
    [Activity, '05', 'Execution', 't+1 · costs · NBBO'],
    [BarChart3, '06', 'Registry', 'SQLite WAL · DBN manifests'],
  ] as const;
  return (
    <section className="grid overflow-hidden rounded-xl border border-slate-700 bg-[#070c15] sm:grid-cols-2 xl:grid-cols-6">
      {blocks.map(([Icon, index, title, detail], i) => (
        <div key={title} className={`p-4 ${i ? 'border-t border-slate-800 sm:border-l sm:border-t-0' : ''}`}>
          <div className="flex items-center justify-between text-slate-500"><Icon className="h-4 w-4" /><span className="font-mono text-[10px]">{index}</span></div>
          <p className="mt-3 text-xs font-black uppercase tracking-[0.12em] text-white">{title}</p>
          <p className="mt-1 font-mono text-[10px] text-slate-500">{detail}</p>
        </div>
      ))}
    </section>
  );
}

function MetricGrid({ metrics, selected, rejected }: { metrics: IntradayMetrics; selected: number; rejected: number }) {
  const cards = [
    ['OOS trades', String(metrics.number_of_trades ?? 0), `${selected} selected · ${rejected} rejected`],
    ['Win rate', pct(metrics.win_rate), wilsonLabel(metrics.number_of_trades || 0, metrics.win_rate || 0)],
    ['Profit factor', number(metrics.profit_factor), 'gross profit / gross loss'],
    ['Net return', pct(metrics.total_return), 'after modeled costs'],
    ['Expectancy', pct(metrics.expectancy_per_trade), 'net per selected trade'],
    ['No-trade days', `${number(metrics.percentage_no_trade_days, 1)}%`, 'abstention is allowed'],
    ['Max drawdown', pct(metrics.maximum_drawdown), 'test-fold selected trades'],
    ['Avg holding', `${number(metrics.average_holding_period, 1)}m`, `sessions ${metrics.observed_sessions ?? 0}`],
  ];
  return (
    <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {cards.map(([label, value, note]) => (
        <div key={label} className="rounded-lg border border-slate-700 bg-[#09101d] p-4">
          <p className="font-mono text-[10px] font-black uppercase tracking-[0.14em] text-slate-500">{label}</p>
          <p className="mt-2 font-mono text-2xl font-black text-white">{value}</p>
          <p className="mt-1.5 text-[11px] text-slate-500">{note}</p>
        </div>
      ))}
    </section>
  );
}

function EquityPanel({ points }: { points: Array<{ date: string; equity: number; drawdown: number }> }) {
  if (points.length === 0) return <Panel title="OOS equity" icon={BarChart3}><p className="text-sm text-slate-500">No selected OOS trades; equity remains cash.</p></Panel>;
  const width = 780;
  const height = 240;
  const values = points.map((point) => point.equity);
  const low = Math.min(...values, 0.999);
  const high = Math.max(...values, 1.001);
  const x = (index: number) => 30 + (index / Math.max(points.length - 1, 1)) * (width - 50);
  const y = (value: number) => 20 + ((high - value) / Math.max(high - low, 1e-9)) * (height - 50);
  const path = points.map((point, i) => `${i ? 'L' : 'M'} ${x(i).toFixed(1)} ${y(point.equity).toFixed(1)}`).join(' ');
  return (
    <Panel title="OOS net equity" icon={BarChart3} trailing={`${points[0].date} → ${points.at(-1)?.date}`}>
      <svg viewBox={`0 0 ${width} ${height}`} className="mt-3 w-full overflow-visible">
        {[0, 1, 2, 3].map((index) => {
          const value = low + ((high - low) * index) / 3;
          return <g key={index}><line x1="30" x2={width - 20} y1={y(value)} y2={y(value)} stroke="#1e293b" strokeDasharray="3 4" /><text x="26" y={y(value) + 4} fill="#64748b" fontSize="10" textAnchor="end">{value.toFixed(3)}</text></g>;
        })}
        <path d={path} fill="none" stroke="#67e8f9" strokeWidth="2.4" />
        {points.map((point, i) => <circle key={point.date} cx={x(i)} cy={y(point.equity)} r="3.5" fill="#0f172a" stroke="#67e8f9" />)}
      </svg>
    </Panel>
  );
}

function CoveragePanel({ run, metrics }: { run: IntradayRun; metrics: IntradayMetrics }) {
  const coverage = run.data_coverage || {};
  const rows = [
    ['Coverage', `${shortDate(coverage.start)} → ${shortDate(coverage.end)}`],
    ['Sessions', String(coverage.sessions ?? 0)],
    ['Feature rows', integer(coverage.rows)],
    ['Annualization', metrics.annualization_status || 'not reported'],
    ['Options', run.option_status || 'not executed'],
  ];
  return (
    <Panel title="Evidence & data coverage" icon={Database}>
      <dl className="mt-2 divide-y divide-slate-800">
        {rows.map(([label, value]) => <div key={label} className="grid grid-cols-[120px_1fr] gap-3 py-3 text-xs"><dt className="font-mono uppercase tracking-[0.08em] text-slate-500">{label}</dt><dd className="text-right leading-5 text-slate-200">{value}</dd></div>)}
      </dl>
    </Panel>
  );
}

function MathPanel() {
  return (
    <Panel title="Executable mathematical model" icon={Sigma} trailing="docs/intraday-quant-mathematics.md">
      <div className="mt-3 grid gap-3 lg:grid-cols-3">
        <Formula label="Prior-only analog kernel" formula={'dᵢ = √mean((z − zᵢ)²)\nwᵢ ∝ exp[−½(dᵢ / b)²]\nμ̂ = Σwᵢrᵢ'} note="Only training-fold states with timestampᵢ < query time are eligible." />
        <Formula label="Cost-aware utility" formula={'μ̂net = μ̂ − spread − slippage − fee\nScore = [μ̂net(p₀+p̂)+0.25·MFÊ]\n        / max(MAÊ+uncertainty, floor)'} note="Threshold is fixed on validation; test outcomes never tune it." />
        <Formula label="Execution chronology" formula={'Fₜ → signal at t close\nentry ≥ t+1 open\nLong option: ask+slip → bid−slip'} note="Wide, stale, crossed, zero-bid, or illiquid option quotes are rejected." />
      </div>
    </Panel>
  );
}

function Formula({ label, formula, note }: { label: string; formula: string; note: string }) {
  return <div className="rounded-md border border-slate-700 bg-black p-4"><p className="text-xs font-black text-cyan-200">{label}</p><pre className="mt-3 overflow-x-auto whitespace-pre-wrap font-mono text-[11px] leading-6 text-slate-200">{formula}</pre><p className="mt-3 text-[11px] leading-5 text-slate-500">{note}</p></div>;
}

function CurrentHintPanel({ hint }: { hint: IntradayOverview['current_hint'] }) {
  return (
    <Panel title="当前状态历史形态提示" icon={Activity} trailing={hint?.as_of ? shortTime(hint.as_of) : 'waiting for real bars'}>
      {!hint ? (
        <p className="mt-3 text-xs text-amber-200">同步 Massive 真实分钟数据并运行模型后，这里会显示当前状态最相似的历史日期与 abstain/方向提示。</p>
      ) : (
        <div className="mt-3 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {(hint.horizons || []).map((row) => (
            <div key={row.horizon_minutes} className="rounded-md border border-slate-800 bg-black p-3">
              <p className="font-mono text-[9px] uppercase tracking-[0.12em] text-slate-500">Future {row.horizon_minutes}m · bucket #{row.bucket_5m + 1}</p>
              <p className={`mt-2 text-lg font-black ${row.abstain ? 'text-amber-200' : row.suggested_direction > 0 ? 'text-emerald-300' : 'text-rose-300'}`}>
                {row.abstain ? 'INSUFFICIENT EVIDENCE' : row.suggested_direction > 0 ? 'POSITIVE TILT' : 'NEGATIVE TILT'}
              </p>
              <p className="mt-2 text-[11px] text-slate-400">
                E[r] {pct(row.prediction.expected_return)} · P(conditional outcome) {pct(row.prediction.win_probability)} · sim {number(row.prediction.similarity_score, 3)}
              </p>
              <p className="mt-1 font-mono text-[9px] text-slate-600">as of {shortTime(row.as_of)}</p>
            </div>
          ))}
          <p className="text-[11px] leading-5 text-slate-500 sm:col-span-2 xl:col-span-4">
            Whole-market statistical research only. No holdings, account value, cost basis, risk tolerance, or personal suitability inputs are used; this is not investment advice or an execution instruction.
          </p>
        </div>
      )}
    </Panel>
  );
}

function AnalogPanel({ rows, run, asOf }: { rows: AnalogCase[]; run: IntradayRun; asOf?: string }) {
  const positive = rows.filter((row) => (row.forward_return || 0) > 0).length;
  const average = rows.length ? rows.reduce((sum, row) => sum + (row.forward_return || 0), 0) / rows.length : 0;
  return (
    <Panel title="当前状态最相似的历史分钟" icon={FlaskConical} trailing={asOf ? `As of ${shortTime(asOf)}` : 'past-only analogs'}>
      <div className="mt-3 grid gap-3 sm:grid-cols-3">
        <MiniMetric label="Prior analogs" value={String(rows.length)} />
        <MiniMetric label="Gross positive" value={rows.length ? `${positive}/${rows.length}` : '—'} />
        <MiniMetric label="Mean forward return" value={pct(average)} />
      </div>
      <div className="mt-4 overflow-x-auto rounded-md border border-slate-800">
        <table className="min-w-[760px] w-full text-left text-xs">
          <thead className="bg-black font-mono text-[10px] uppercase tracking-[0.1em] text-slate-500"><tr><th className="px-3 py-2.5">Rank</th><th>Historical time</th><th>Similarity</th><th>Forward return</th><th>MFE</th><th>MAE</th><th>Distance</th></tr></thead>
          <tbody>{rows.map((row) => <tr key={`${row.rank}-${row.analog_date}`} className="border-t border-slate-800 text-slate-300"><td className="px-3 py-2.5 font-mono text-white">#{row.rank}</td><td className="font-mono">{row.analog_date}</td><td>{number(row.similarity, 3)}</td><td className={tone(row.forward_return)}>{pct(row.forward_return)}</td><td className="text-emerald-300">{pct(row.mfe)}</td><td className="text-rose-300">{pct(row.mae)}</td><td>{number(row.distance, 3)}</td></tr>)}</tbody>
        </table>
      </div>
      <p className="mt-3 text-[11px] leading-5 text-slate-500">相似度只搜索查询时刻以前、同一 5 分钟时段且标签窗口已经完整结束的历史状态；未来收益只用于历史结果统计，不进入特征。Source tier: {run.evidence_tier}.</p>
    </Panel>
  );
}

function HypothesisPanel({ rows }: { rows: AuditRow[] }) {
  return (
    <Panel title="Simons-style anomaly audit" icon={Activity} trailing="event population · not selected-trade OOS">
      <div className="mt-3 overflow-x-auto rounded-md border border-slate-800">
        <table className="min-w-[760px] w-full text-left text-xs"><thead className="bg-black font-mono text-[10px] uppercase tracking-[0.1em] text-slate-500"><tr><th className="px-3 py-2.5">Setup</th><th>Events</th><th>Wins</th><th>Win rate</th><th>Mean net</th><th>Profit factor</th><th>Status</th></tr></thead><tbody>{rows.map((row) => { const p = row.payload; const eventCount = asNumber(p.event_days ?? p.events ?? p.trades) || 0; return <tr key={`${row.audit_type}-${row.row_number}`} className="border-t border-slate-800 text-slate-300"><td className="px-3 py-2.5 font-bold text-white">{String(p.setup ?? '—')}</td><td>{eventCount || '—'}</td><td>{String(p.wins_after_cost ?? p.wins ?? '—')}</td><td>{pct(asNumber(p.win_rate_after_cost ?? p.win_rate))}</td><td className={tone(asNumber(p.average_net_return ?? p.expectancy))}>{pct(asNumber(p.average_net_return ?? p.expectancy))}</td><td>{number(asNumber(p.profit_factor), 2)}</td><td><AuditStatus value={eventCount < 30 ? 'insufficient_sample' : String(p.status ?? p.scope ?? 'review')} /></td></tr>; })}</tbody></table>
      </div>
    </Panel>
  );
}

function TimeBucketEffectPanel({ rows }: { rows: TimeBucketEffect[] }) {
  const selected = rows.filter((row) => row.selected_on_validation);
  const shown = (selected.length ? selected : rows)
    .slice()
    .sort((a, b) => a.validation_q_value - b.validation_q_value)
    .slice(0, 20);
  return (
    <Panel
      title="第 N 个 5 分钟 K 线反转审计"
      icon={Clock3}
      trailing={`${selected.length} validation-selected / ${rows.length} tested`}
    >
      <p className="mt-3 text-[11px] leading-5 text-slate-400">
        仅在五分钟 K 线收盘后观察其方向。60% 日期训练、20% 验证筛选、最后 20% 只做样本外评价；q 值经过全部时段/方向的 FDR 校正。
      </p>
      <div className="mt-3 overflow-x-auto rounded-md border border-slate-800">
        <table className="min-w-[940px] w-full text-left text-xs">
          <thead className="bg-black font-mono text-[10px] uppercase tracking-[0.08em] text-slate-500">
            <tr><th className="px-3 py-2.5">5m bucket (ET)</th><th>Observed</th><th>Train/Val/Test</th><th>Val reversal</th><th>Test reversal</th><th>Test strong</th><th>Val q</th><th>OOS mean</th><th>Decision</th></tr>
          </thead>
          <tbody>{shown.map((row) => (
            <tr key={`${row.bucket_5m}-${row.observed_bar_direction}`} className="border-t border-slate-800 text-slate-300">
              <td className="px-3 py-2.5 font-mono text-white">#{row.bucket_5m + 1} · {row.clock_label_et}</td>
              <td className={row.observed_bar_direction === 'up' ? 'text-emerald-300' : 'text-rose-300'}>{row.observed_bar_direction.toUpperCase()}</td>
              <td>{row.train_samples}/{row.validation_samples}/{row.test_samples}</td>
              <td>{pct(row.validation_reversal_rate)}</td>
              <td>{pct(row.test_reversal_rate)}</td>
              <td>{pct(row.test_strong_reversal_rate)}</td>
              <td>{number(row.validation_q_value, 4)}</td>
              <td className={tone(row.test_mean_reversal_return)}>{pct(row.test_mean_reversal_return)}</td>
              <td><AuditStatus value={row.selected_on_validation ? 'validation_supported' : 'not_selected'} /></td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      {!rows.length ? <p className="mt-4 text-xs text-amber-200">等待 Massive 真实分钟数据同步后生成，不展示 synthetic 统计。</p> : null}
    </Panel>
  );
}

function DiagnosticsPanel({ rows }: { rows: ModelDiagnostic[] }) {
  return (
    <Panel title="Walk-forward diagnostics" icon={ShieldCheck}>
      <div className="mt-3 overflow-x-auto"><table className="w-full text-left text-xs"><thead className="font-mono text-[10px] uppercase tracking-[0.08em] text-slate-500"><tr><th className="py-2">Fold</th><th>Model</th><th>Train / Val / Test</th><th>Brier</th></tr></thead><tbody>{rows.map((row, index) => <tr key={`${row.fold}-${row.model}-${index}`} className="border-t border-slate-800 text-slate-300"><td className="py-2.5">{row.fold}</td><td className="font-mono text-white">{row.model}</td><td>{row.train_rows} / {row.validation_rows} / {row.test_rows}</td><td>{row.validation_brier == null ? 'empirical' : number(row.validation_brier, 4)}</td></tr>)}</tbody></table></div>
    </Panel>
  );
}

function DecisionPanel({ candidates }: { candidates: CandidateDecision[] }) {
  const reasons = useMemo(() => {
    const count = new Map<string, number>();
    candidates.filter((row) => row.decision === 'rejected').forEach((row) => { const key = row.rejection_reason || 'unspecified'; count.set(key, (count.get(key) || 0) + 1); });
    return [...count.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6);
  }, [candidates]);
  const max = Math.max(...reasons.map(([, count]) => count), 1);
  return (
    <Panel title="Abstention & rejection ledger" icon={XCircle}>
      <div className="mt-4 space-y-3">{reasons.map(([reason, count]) => <div key={reason}><div className="flex justify-between gap-3 text-[11px]"><span className="font-mono text-slate-300">{reason}</span><span className="text-white">{count}</span></div><div className="mt-1 h-1.5 overflow-hidden rounded-full bg-slate-800"><div className="h-full bg-cyan-400" style={{ width: `${(count / max) * 100}%` }} /></div></div>)}</div>
      <p className="mt-5 text-[11px] leading-5 text-slate-500">Every non-traded candidate remains queryable. “No trade” is a first-class decision, not missing data.</p>
    </Panel>
  );
}

function TradePanel({ rows, optionStatus }: { rows: IntradayTrade[]; optionStatus?: string | null }) {
  return (
    <Panel title="Historical OOS simulation blotter" icon={BarChart3} trailing={`${rows.length} simulated paths`}>
      <div className="mt-3 overflow-x-auto rounded-md border border-slate-800"><table className="min-w-[1040px] w-full text-left text-xs"><thead className="bg-black font-mono text-[10px] uppercase tracking-[0.08em] text-slate-500"><tr><th className="px-3 py-2.5">Signal</th><th>Setup</th><th>Side</th><th>Entry</th><th>Exit</th><th>Hold</th><th>Probability</th><th>Score</th><th>Gross P&L</th><th>Cost</th><th>Net P&L</th><th>Exit reason</th></tr></thead><tbody>{rows.map((row) => <tr key={row.trade_id} className="border-t border-slate-800 text-slate-300"><td className="px-3 py-2.5 font-mono">{shortTime(row.signal_time)}</td><td>{row.setup}</td><td className={(row.direction || 0) > 0 ? 'text-emerald-300' : 'text-rose-300'}>{(row.direction || 0) > 0 ? 'LONG' : 'SHORT'}</td><td>{number(row.underlying_entry, 2)}</td><td>{number(row.underlying_exit, 2)}</td><td>{row.holding_minutes}m</td><td>{pct(row.model_probability)}</td><td>{number(row.score, 2)}</td><td>{usd(row.gross_pnl)}</td><td className="text-amber-300">{usd(row.cost)}</td><td className={tone(row.net_pnl)}>{usd(row.net_pnl)}</td><td>{row.exit_reason}</td></tr>)}</tbody></table></div>
      <div className="mt-3 flex items-start gap-2 rounded border border-amber-400/20 bg-amber-400/5 p-3 text-[11px] leading-5 text-amber-100"><AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />{optionStatus || '期权回测未执行：没有真实历史 NBBO。Underlying 结果不能冒充 0DTE 期权结果。'}</div>
      <p className="mt-3 text-[11px] leading-5 text-slate-500">Rows above are historical out-of-sample simulations, not current recommendations, orders, or account-specific instructions.</p>
    </Panel>
  );
}

function Panel({ title, icon: Icon, trailing, children }: { title: string; icon: typeof Activity; trailing?: string; children: React.ReactNode }) {
  return <section className="rounded-xl border border-slate-700 bg-[#09101d] p-5"><div className="flex flex-wrap items-center justify-between gap-3"><h3 className="inline-flex items-center gap-2 text-sm font-black uppercase tracking-[0.08em] text-white"><Icon className="h-4 w-4 text-cyan-300" />{title}</h3>{trailing ? <span className="font-mono text-[10px] text-slate-500">{trailing}</span> : null}</div>{children}</section>;
}

function MiniMetric({ label, value }: { label: string; value: string }) { return <div className="rounded-md border border-slate-800 bg-black p-3"><p className="font-mono text-[9px] uppercase tracking-[0.12em] text-slate-500">{label}</p><p className="mt-1.5 font-mono text-lg font-black text-white">{value}</p></div>; }
function AuditStatus({ value }: { value: string }) { const good = value.includes('supported'); return <span className={`inline-flex items-center gap-1 rounded px-2 py-1 font-mono text-[9px] uppercase ${good ? 'bg-emerald-400/10 text-emerald-200' : 'bg-slate-700/70 text-slate-300'}`}>{good ? <CheckCircle2 className="h-3 w-3" /> : <AlertTriangle className="h-3 w-3" />}{value}</span>; }
function asNumber(value: unknown): number | undefined { const parsed = typeof value === 'number' ? value : Number(value); return Number.isFinite(parsed) ? parsed : undefined; }
function number(value?: number | null, digits = 2): string { return value == null || !Number.isFinite(value) ? '—' : value.toFixed(digits); }
function integer(value?: number | null): string { return value == null ? '—' : Math.round(value).toLocaleString(); }
function pct(value?: number | null): string { return value == null || !Number.isFinite(value) ? '—' : `${value >= 0 ? '+' : ''}${(value * 100).toFixed(2)}%`; }
function usd(value?: number | null): string { return value == null || !Number.isFinite(value) ? '—' : `${value < 0 ? '-' : ''}$${Math.abs(value).toFixed(2)}`; }
function tone(value?: number | null): string { return (value || 0) > 0 ? 'text-emerald-300' : (value || 0) < 0 ? 'text-rose-300' : 'text-slate-300'; }
function shortDate(value?: string | null): string { return value ? value.slice(0, 10) : '—'; }
function shortTime(value?: string | null): string { return value ? value.replace('T', ' ').slice(0, 16) : '—'; }
function wilsonLabel(n: number, rate: number): string { if (!n) return 'no observed trades'; const z = 1.96; const denominator = 1 + z * z / n; const center = (rate + z * z / (2 * n)) / denominator; const half = (z * Math.sqrt((rate * (1 - rate) + z * z / (4 * n)) / n)) / denominator; return `95% CI ${(100 * Math.max(0, center - half)).toFixed(1)}–${(100 * Math.min(1, center + half)).toFixed(1)}%`; }
