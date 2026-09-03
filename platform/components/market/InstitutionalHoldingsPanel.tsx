'use client';

import { useEffect, useMemo, useState } from 'react';
import { Building2, ExternalLink, Loader2, ShieldAlert } from 'lucide-react';
import type { InstitutionalHoldingsReport } from '@/lib/market-intelligence/institutional-holdings';

type LoadState =
  | { status: 'loading'; report?: undefined; error?: undefined }
  | { status: 'ok'; report: InstitutionalHoldingsReport; error?: undefined }
  | { status: 'error'; report?: undefined; error: string };

export function InstitutionalHoldingsPanel({ ticker }: { ticker: string }) {
  const [state, setState] = useState<LoadState>({ status: 'loading' });

  useEffect(() => {
    const controller = new AbortController();
    setState({ status: 'loading' });

    fetch(`/api/market/institutional-holdings?ticker=${encodeURIComponent(ticker)}`, {
      signal: controller.signal,
      headers: { Accept: 'application/json' },
    })
      .then(async (res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return (await res.json()) as InstitutionalHoldingsReport;
      })
      .then((report) => setState({ status: 'ok', report }))
      .catch((err) => {
        if (controller.signal.aborted) return;
        setState({ status: 'error', error: err instanceof Error ? err.message : 'fetch failed' });
      });

    return () => controller.abort();
  }, [ticker]);

  return (
    <section className="rounded-[6px] border border-slate-700 bg-[#141a2b] p-5 shadow-xl shadow-black/25">
      <header className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="mb-2 inline-flex items-center gap-2 rounded-[6px] border border-blue-400/50 bg-blue-500/20 px-3 py-1 text-xs font-black uppercase tracking-[0.14em] text-blue-100">
            <Building2 className="h-4 w-4" /> Institutional 13F · SEC
          </div>
          <h2 className="text-xl font-black text-white">{ticker} 大机构持仓扫描</h2>
          <p className="mt-1 max-w-4xl text-xs leading-5 text-slate-300">
            On-demand 拉取 Goldman Sachs、JPMorgan、Jane Street、Citadel 等最新公开 13F。注意：13F 是季度披露，
            不是实时仓位；它回答“这些大机构上一季公开报了什么”，不是“此刻正在买卖什么”。
          </p>
        </div>
        <SourceBadge state={state} />
      </header>

      {state.status === 'loading' ? (
        <div className="flex min-h-32 items-center justify-center rounded-[8px] border border-slate-700 bg-black text-sm text-slate-300">
          <Loader2 className="mr-2 h-4 w-4 animate-spin text-blue-300" /> Pulling latest SEC 13F information tables...
        </div>
      ) : state.status === 'error' ? (
        <div className="rounded-[8px] border border-red-400/40 bg-red-500/10 p-4 text-sm text-red-100">
          <ShieldAlert className="mb-2 h-5 w-5" />
          Institutional holdings unavailable: {state.error}
        </div>
      ) : (
        <InstitutionalRows report={state.report} />
      )}
    </section>
  );
}

function InstitutionalRows({ report }: { report: InstitutionalHoldingsReport }) {
  const reportedRows = report.rows.filter((row) => row.status === 'reported');
  const totals = useMemo(
    () => ({
      value: reportedRows.reduce((sum, row) => sum + row.reportedValueUsd, 0),
      stock: reportedRows.reduce((sum, row) => sum + row.stockShares, 0),
      calls: reportedRows.reduce((sum, row) => sum + row.callEquivalentShares, 0),
      puts: reportedRows.reduce((sum, row) => sum + row.putEquivalentShares, 0),
      netShareDelta: reportedRows.reduce((sum, row) => sum + (row.delta?.shareDelta ?? 0), 0),
      netValueDelta: reportedRows.reduce((sum, row) => sum + (row.delta?.valueDelta ?? 0), 0),
    }),
    [reportedRows]
  );

  if (!report.lookup) {
    return (
      <div className="rounded-[8px] border border-amber-400/40 bg-amber-500/10 p-4 text-sm leading-6 text-amber-100">
        No CUSIP mapping for {report.ticker}. Add the ticker CUSIP before 13F matching can be reliable.
      </div>
    );
  }

  return (
    <>
      <div className="mb-4 grid gap-2 sm:grid-cols-3 lg:grid-cols-6">
        <SummaryStat label="reported value" value={formatMoney(totals.value)} />
        <SummaryStat label="stock shares" value={formatCompact(totals.stock)} tone="blue" />
        <SummaryStat label="call equiv." value={formatCompact(totals.calls)} tone="green" />
        <SummaryStat label="put equiv." value={formatCompact(totals.puts)} tone="red" />
        <SummaryStat
          label="QoQ Δ shares"
          value={signedCompact(totals.netShareDelta)}
          tone={totals.netShareDelta > 0 ? 'green' : totals.netShareDelta < 0 ? 'red' : 'slate'}
        />
        <SummaryStat
          label="QoQ Δ value"
          value={signedMoney(totals.netValueDelta)}
          tone={totals.netValueDelta > 0 ? 'green' : totals.netValueDelta < 0 ? 'red' : 'slate'}
        />
      </div>

      <div className="overflow-x-auto rounded-[8px] border border-slate-700">
        <table className="w-full min-w-[940px] text-left text-sm">
          <thead className="bg-black/50">
            <tr className="text-[10px] font-black uppercase tracking-[0.12em] text-slate-300">
              <th className="px-3 py-2">Institution</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2">QoQ Action</th>
              <th className="px-3 py-2 text-right">Reported value</th>
              <th className="px-3 py-2 text-right">Stock shares</th>
              <th className="px-3 py-2 text-right">Δ shares (QoQ)</th>
              <th className="px-3 py-2 text-right">Calls</th>
              <th className="px-3 py-2 text-right">Puts</th>
              <th className="px-3 py-2">Filing</th>
            </tr>
          </thead>
          <tbody>
            {report.rows.map((row, index) => (
              <tr key={row.institutionId} className={index % 2 === 0 ? 'bg-black/25' : 'bg-slate-950/80'}>
                <td className="px-3 py-3">
                  <p className="font-black text-white">{row.institutionName}</p>
                  <p className="font-mono text-[10px] text-slate-400">CIK {row.cik}</p>
                </td>
                <td className="px-3 py-3">
                  <StatusPill status={row.status} />
                  {row.errorMessage ? <p className="mt-1 max-w-[180px] text-[10px] text-amber-200">{row.errorMessage}</p> : null}
                </td>
                <td className="px-3 py-3">
                  <ActionPill action={row.delta?.action ?? null} />
                  {row.delta?.priorReportDate ? (
                    <p className="mt-1 font-mono text-[10px] text-slate-500">vs {row.delta.priorReportDate}</p>
                  ) : null}
                </td>
                <td className="px-3 py-3 text-right font-mono font-black text-white">{formatMoney(row.reportedValueUsd)}</td>
                <td className="px-3 py-3 text-right font-mono text-slate-100">{formatCompact(row.stockShares)}</td>
                <td className="px-3 py-3 text-right font-mono">
                  {row.delta ? (
                    <span className={deltaTone(row.delta.shareDelta)}>
                      {signedCompact(row.delta.shareDelta)}
                      {row.delta.shareDeltaPct !== null ? (
                        <span className="ml-1 text-[10px] text-slate-400">
                          ({signedPct(row.delta.shareDeltaPct * 100)})
                        </span>
                      ) : null}
                    </span>
                  ) : (
                    <span className="text-slate-500">—</span>
                  )}
                </td>
                <td className="px-3 py-3 text-right font-mono text-emerald-300">{formatCompact(row.callEquivalentShares)}</td>
                <td className="px-3 py-3 text-right font-mono text-red-300">{formatCompact(row.putEquivalentShares)}</td>
                <td className="px-3 py-3 text-xs text-slate-300">
                  <p>
                    Period <span className="font-mono text-slate-100">{row.reportDate || 'n/a'}</span>
                  </p>
                  <p>
                    Filed <span className="font-mono text-slate-100">{row.filingDate || 'n/a'}</span>
                  </p>
                  {row.filingUrl ? (
                    <a
                      href={row.filingUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-1 inline-flex items-center gap-1 text-blue-300 underline-offset-4 hover:underline"
                    >
                      SEC filing <ExternalLink className="h-3 w-3" />
                    </a>
                  ) : null}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-3 border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">
        {report.disclaimer} CUSIP match: {report.lookup.cusips.join(', ')}. QoQ Δ compares the latest 13F-HR
        information table to the prior quarter&apos;s filing for the same institution.
      </p>
    </>
  );
}

function ActionPill({ action }: { action: 'new_position' | 'added' | 'reduced' | 'exited' | 'unchanged' | 'unavailable' | null }) {
  if (!action) return <span className="font-mono text-[10px] text-slate-500">—</span>;
  const map = {
    new_position: { label: 'NEW', cls: 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100' },
    added: { label: 'ADDED', cls: 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100' },
    reduced: { label: 'REDUCED', cls: 'border-amber-400/50 bg-amber-500/20 text-amber-100' },
    exited: { label: 'EXITED', cls: 'border-red-400/50 bg-red-500/20 text-red-100' },
    unchanged: { label: 'FLAT', cls: 'border-slate-600 bg-slate-800 text-slate-200' },
    unavailable: { label: 'NO PRIOR', cls: 'border-slate-600 bg-slate-800 text-slate-400' },
  } as const;
  const m = map[action];
  return <span className={`inline-flex rounded border px-2 py-0.5 text-[10px] font-black uppercase ${m.cls}`}>{m.label}</span>;
}

function deltaTone(delta: number): string {
  if (delta > 0) return 'text-emerald-300';
  if (delta < 0) return 'text-red-300';
  return 'text-slate-300';
}

function signedCompact(value: number): string {
  if (!Number.isFinite(value) || value === 0) return '0';
  const sign = value > 0 ? '+' : '−';
  return `${sign}${formatCompact(Math.abs(value))}`;
}

function signedMoney(value: number): string {
  if (!Number.isFinite(value) || value === 0) return '$0';
  const sign = value > 0 ? '+' : '−';
  return `${sign}${formatMoney(Math.abs(value))}`;
}

function signedPct(value: number): string {
  if (!Number.isFinite(value)) return '—';
  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(1)}%`;
}

function SourceBadge({ state }: { state: LoadState }) {
  if (state.status === 'loading') {
    return <span className="rounded-[6px] border border-blue-400/40 bg-blue-500/15 px-2 py-1 text-xs font-black text-blue-100">LOADING</span>;
  }
  if (state.status === 'error') {
    return <span className="rounded-[6px] border border-red-400/40 bg-red-500/15 px-2 py-1 text-xs font-black text-red-100">UNAVAILABLE</span>;
  }
  return (
    <span
      className={`rounded-[6px] border px-2 py-1 text-xs font-black ${
        state.report.reliability === 'ok'
          ? 'border-emerald-400/40 bg-emerald-500/15 text-emerald-100'
          : state.report.reliability === 'partial'
            ? 'border-amber-400/40 bg-amber-500/15 text-amber-100'
            : 'border-slate-600 bg-slate-800 text-slate-200'
      }`}
    >
      {state.report.reliability.toUpperCase()}
    </span>
  );
}

function StatusPill({ status }: { status: 'reported' | 'not_reported' | 'unavailable' }) {
  const cls =
    status === 'reported'
      ? 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100'
      : status === 'not_reported'
        ? 'border-slate-600 bg-slate-800 text-slate-200'
        : 'border-red-400/50 bg-red-500/20 text-red-100';
  const label = status === 'reported' ? 'reported' : status === 'not_reported' ? 'not in latest 13F' : 'unavailable';
  return <span className={`inline-flex rounded border px-2 py-0.5 text-[10px] font-black uppercase ${cls}`}>{label}</span>;
}

function SummaryStat({
  label,
  value,
  tone = 'slate',
}: {
  label: string;
  value: string;
  tone?: 'slate' | 'blue' | 'green' | 'red';
}) {
  const valueClass =
    tone === 'blue'
      ? 'text-blue-200'
      : tone === 'green'
        ? 'text-emerald-300'
        : tone === 'red'
          ? 'text-red-300'
          : 'text-white';
  return (
    <div className="rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-2">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{label}</p>
      <p className={`mt-1 font-mono text-base font-black ${valueClass}`}>{value}</p>
    </div>
  );
}

function formatMoney(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return '$0';
  if (value >= 1_000_000_000) return `$${(value / 1_000_000_000).toFixed(2)}B`;
  if (value >= 1_000_000) return `$${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `$${(value / 1_000).toFixed(1)}K`;
  return `$${value.toFixed(0)}`;
}

function formatCompact(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return '0';
  return Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(value);
}
