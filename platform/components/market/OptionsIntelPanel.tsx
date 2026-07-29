'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import { Activity, Crosshair, Loader2, Sigma, TrendingUp } from 'lucide-react';
import type {
  OptionsIntelReport,
  TopOiRow,
  SerializableProbability,
} from '@/lib/market-intelligence/options';

export function OptionsIntelPanel({ defaultTicker = 'NVDA' }: { defaultTicker?: string }) {
  const [ticker, setTicker] = useState(defaultTicker);
  const [expiration, setExpiration] = useState(nextFriday());
  const [report, setReport] = useState<OptionsIntelReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(e?: FormEvent) {
    e?.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const url = new URL('/api/market/options', window.location.origin);
      url.searchParams.set('ticker', ticker.toUpperCase());
      url.searchParams.set('expiration', expiration);
      const res = await fetch(url.toString());
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || 'Options fetch failed.');
      setReport(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Options fetch failed.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <section className="space-y-4 rounded-[10px] border border-slate-700 bg-slate-900 p-6 text-white shadow-2xl shadow-black/35">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <div className="mb-2 inline-flex items-center gap-2 rounded-[6px] border border-amber-300/30 bg-amber-300/10 px-3 py-1 text-xs font-black uppercase tracking-[0.16em] text-amber-100">
            <Sigma className="h-4 w-4" /> Options Intel
          </div>
          <h2 className="text-2xl font-black tracking-tight text-white">
            Top OI, Max Pain, Gamma, and Lognormal Probability
          </h2>
          <p className="mt-1 text-xs leading-5 text-white/55">
            High-OI ranking, dealer gamma exposure, and a lognormal ending-price distribution from ATM IV. Public/licensed sources only.
          </p>
        </div>
        <form onSubmit={run} className="flex flex-wrap items-end gap-2">
          <label className="space-y-1">
            <span className="text-[10px] font-black uppercase tracking-[0.16em] text-white/40">Ticker</span>
            <input
              value={ticker}
              onChange={(e) => setTicker(e.target.value)}
              className="block w-28 rounded-[6px] border border-white/15 bg-black/35 px-3 py-2 text-sm font-black uppercase text-white outline-none focus:border-amber-300"
              maxLength={10}
            />
          </label>
          <label className="space-y-1">
            <span className="text-[10px] font-black uppercase tracking-[0.16em] text-white/40">Expiration</span>
            <input
              type="date"
              value={expiration}
              onChange={(e) => setExpiration(e.target.value)}
              className="block rounded-[6px] border border-white/15 bg-black/35 px-3 py-2 text-sm text-white outline-none focus:border-amber-300"
            />
          </label>
          <button
            type="submit"
            disabled={loading}
            className="inline-flex h-9 items-center gap-2 rounded-[6px] bg-amber-300 px-4 text-xs font-black uppercase tracking-[0.12em] text-slate-950 transition hover:bg-amber-200 disabled:opacity-60"
          >
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Activity className="h-4 w-4" />}
            Run
          </button>
        </form>
      </header>

      {error ? (
        <div className="rounded-[8px] border border-rose-300/30 bg-rose-950/30 p-3 text-sm text-rose-100">{error}</div>
      ) : null}

      {report ? (
        <>
          <ReportHeader report={report} />
          <div className="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
            <TopOiTable
              rows={report.topOi}
              spot={report.spot}
              maxPainStrike={report.maxPain?.maxPainStrike}
              underlying={report.underlying}
            />
            <SqueezePanel report={report} />
          </div>
          {report.probability ? <ProbabilityChart prob={report.probability} maxPainStrike={report.maxPain?.maxPainStrike} /> : null}
          {report.maxPain ? <MaxPainCurve report={report} /> : null}
          <footer className="border-t border-white/10 pt-3 text-[11px] leading-5 text-white/40">
            {report.disclaimer}
          </footer>
        </>
      ) : null}
    </section>
  );
}

function ReportHeader({ report }: { report: OptionsIntelReport }) {
  const providerLabel =
    report.provider === 'ibkr'
      ? 'IBKR Client Portal'
      : report.provider === 'polygon'
      ? 'Polygon options snapshot'
      : report.provider === 'yahoo'
        ? 'Yahoo Finance options JSON'
        : 'unavailable';
  return (
    <div className="grid gap-3 sm:grid-cols-3">
      <Tile label="Underlying" value={`$${report.underlying}`} sub={`Spot ${report.spot.toFixed(2)}`} />
      <Tile
        label="Expiration"
        value={report.expiration}
        sub={`${report.probability?.daysToExpiry ?? '?'} days, IV ${(((report.probability?.ivAtm ?? 0) * 100) || 0).toFixed(0)}%`}
      />
      <Tile label="Provider" value={providerLabel} sub={`fetched ${new Date(report.generatedAt).toLocaleTimeString()}`} />
    </div>
  );
}

function TopOiTable({
  rows,
  spot,
  maxPainStrike,
  underlying,
}: {
  rows: TopOiRow[];
  spot: number;
  maxPainStrike?: number;
  underlying: string;
}) {
  return (
    <div className="rounded-[8px] border border-white/12 bg-slate-950/60 p-4">
      <h3 className="mb-3 flex items-center gap-2 text-sm font-black uppercase tracking-[0.12em] text-white">
        <TrendingUp className="h-4 w-4 text-amber-200" /> Top 10 Open Interest
      </h3>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="text-[10px] uppercase tracking-[0.14em] text-white/40">
            <tr>
              <th className="py-2 pr-3 text-left">#</th>
              <th className="py-2 pr-3 text-left">Contract</th>
              <th className="py-2 pr-3 text-right">OI</th>
              <th className="py-2 pr-3 text-right">Vol</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr className="border-t border-white/8">
                <td colSpan={4} className="py-4 text-sm leading-6 text-white/60">
                  当前 provider 没有返回逐合约 Open Interest。IBKR Client Portal 可用于 bid/ask 和合约报价；
                  Max Pain / Top OI 需要 Polygon/OPRA/Databento/ORATS 等逐合约 OI 数据源。
                </td>
              </tr>
            ) : null}
            {rows.map((row) => {
              const itm = row.side === 'C' ? spot > row.strike : spot < row.strike;
              const isMaxPain = maxPainStrike !== undefined && Math.abs(row.strike - maxPainStrike) < 1e-6;
              return (
                <tr
                  key={`${row.symbol}-${row.strike}-${row.side}`}
                  className="border-t border-white/8 text-white/80"
                >
                  <td className="py-2 pr-3 text-[11px] font-black text-white/45">{row.rank}</td>
                  <td className="py-2 pr-3 font-mono text-xs">
                    {row.symbol && row.symbol.length < 30
                      ? row.symbol
                      : `${underlying} ${row.expiration} ${row.strike}${row.side}`}
                    <span className="ml-2 inline-flex items-center gap-1">
                      {row.side === 'C' ? (
                        <span className="rounded bg-emerald-300/15 px-1.5 py-0.5 text-[10px] font-black text-emerald-200">CALL</span>
                      ) : (
                        <span className="rounded bg-rose-300/15 px-1.5 py-0.5 text-[10px] font-black text-rose-200">PUT</span>
                      )}
                      {itm ? (
                        <span className="rounded bg-white/8 px-1.5 py-0.5 text-[10px] font-black text-white/55">ITM</span>
                      ) : null}
                      {isMaxPain ? (
                        <span className="rounded bg-amber-300/15 px-1.5 py-0.5 text-[10px] font-black text-amber-100">MAX PAIN</span>
                      ) : null}
                    </span>
                  </td>
                  <td className="py-2 pr-3 text-right font-mono">{row.openInterest.toLocaleString()}</td>
                  <td className="py-2 pr-3 text-right font-mono text-white/55">{row.volume.toLocaleString()}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function SqueezePanel({ report }: { report: OptionsIntelReport }) {
  const sq = report.squeezeAssessment;
  const gex = report.gex;
  const label =
    sq.scenario === 'gamma_squeeze_likely'
      ? 'Gamma squeeze setup'
      : sq.scenario === 'dealer_pin_likely'
        ? 'Dealer pin (max-pain magnet)'
        : sq.scenario === 'put_unwind_likely'
          ? 'Put wall / negative-gamma risk'
          : 'Mixed regime';
  const tone =
    sq.scenario === 'gamma_squeeze_likely'
      ? 'bg-emerald-300/15 text-emerald-200'
      : sq.scenario === 'dealer_pin_likely'
        ? 'bg-amber-300/15 text-amber-100'
        : sq.scenario === 'put_unwind_likely'
          ? 'bg-rose-300/15 text-rose-200'
          : 'bg-white/10 text-white/60';

  return (
    <div className="space-y-3 rounded-[8px] border border-white/12 bg-slate-950/60 p-4">
      <h3 className="flex items-center gap-2 text-sm font-black uppercase tracking-[0.12em] text-white">
        <Crosshair className="h-4 w-4 text-amber-200" /> Dealer Positioning
      </h3>
      <div className={`inline-flex items-center gap-2 rounded-[6px] px-3 py-1.5 text-xs font-black uppercase tracking-[0.12em] ${tone}`}>
        {label}
      </div>

      <div className="grid grid-cols-3 gap-3 text-xs">
        <Tile label="Call OI" value={sq.callOiTotal.toLocaleString()} compact />
        <Tile label="Put OI" value={sq.putOiTotal.toLocaleString()} compact />
        <Tile label="C/P ratio" value={Number.isFinite(sq.callPutRatio) ? sq.callPutRatio.toFixed(2) : 'Infinity'} compact />
      </div>

      {gex ? (
        <div className="grid grid-cols-3 gap-3 text-xs">
          <Tile label="Call GEX" value={fmtBn(gex.totalCallGex)} compact />
          <Tile label="Put GEX" value={fmtBn(gex.totalPutGex)} compact />
          <Tile
            label="Zero gamma"
            value={gex.zeroGammaStrike !== null ? `$${gex.zeroGammaStrike.toFixed(0)}` : 'n/a'}
            compact
          />
        </div>
      ) : null}

      <p className="text-xs leading-5 text-white/65">{gex?.rationale}</p>
      <ul className="space-y-1 text-xs leading-5 text-white/65">
        {sq.rationale.map((r) => (
          <li key={r}>- {r}</li>
        ))}
      </ul>
      <ul className="border-t border-white/10 pt-2 text-[11px] leading-5 text-white/40">
        {sq.caveats.map((r) => (
          <li key={r}>- {r}</li>
        ))}
      </ul>
    </div>
  );
}

function ProbabilityChart({
  prob,
  maxPainStrike,
}: {
  prob: SerializableProbability;
  maxPainStrike?: number;
}) {
  const w = 760;
  const h = 260;
  const padX = 36;
  const padY = 24;

  const xs = prob.points.map((p) => p.price);
  const ys = prob.points.map((p) => p.lognormalPdf);
  const xMin = Math.min(...xs);
  const xMax = Math.max(...xs);
  const yMax = Math.max(...ys);

  const path = useMemo(() => {
    if (!prob.points.length) return '';
    return prob.points
      .map((p, i) => {
        const x = padX + ((p.price - xMin) / (xMax - xMin)) * (w - padX * 2);
        const y = h - padY - (p.lognormalPdf / yMax) * (h - padY * 2);
        return `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`;
      })
      .join(' ');
  }, [prob, xMin, xMax, yMax]);

  const xTickVals = xTicks(xMin, xMax, 8);
  const spotX = padX + ((prob.spot - xMin) / (xMax - xMin)) * (w - padX * 2);
  const maxPainX =
    maxPainStrike !== undefined
      ? padX + ((maxPainStrike - xMin) / (xMax - xMin)) * (w - padX * 2)
      : null;

  return (
    <div className="rounded-[8px] border border-white/12 bg-slate-950/60 p-4">
      <h3 className="mb-3 flex items-center gap-2 text-sm font-black uppercase tracking-[0.12em] text-white">
        Ending-price probability ({prob.daysToExpiry}d, IV {(prob.ivAtm * 100).toFixed(0)}%)
      </h3>
      <svg viewBox={`0 0 ${w} ${h}`} className="h-auto w-full">
        <defs>
          <linearGradient id="probFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="rgb(56,189,248)" stopOpacity="0.6" />
            <stop offset="100%" stopColor="rgb(56,189,248)" stopOpacity="0.05" />
          </linearGradient>
        </defs>
        {/* fill area */}
        <path d={`${path} L${padX + (w - padX * 2)},${h - padY} L${padX},${h - padY} Z`} fill="url(#probFill)" />
        <path d={path} fill="none" stroke="rgb(125,211,252)" strokeWidth={2} />
        {/* x axis */}
        <line x1={padX} y1={h - padY} x2={w - padX} y2={h - padY} stroke="rgb(255,255,255)" strokeOpacity={0.15} />
        {xTickVals.map((v) => {
          const x = padX + ((v - xMin) / (xMax - xMin)) * (w - padX * 2);
          return (
            <g key={v}>
              <line x1={x} y1={h - padY} x2={x} y2={h - padY + 4} stroke="rgb(255,255,255)" strokeOpacity={0.25} />
              <text x={x} y={h - 6} fill="rgb(255,255,255)" fillOpacity={0.5} fontSize="10" textAnchor="middle">
                {v.toFixed(0)}
              </text>
            </g>
          );
        })}
        {/* spot line */}
        <line x1={spotX} y1={padY} x2={spotX} y2={h - padY} stroke="rgb(250,204,21)" strokeDasharray="4 4" />
        <text x={spotX + 4} y={padY + 12} fill="rgb(250,204,21)" fontSize="10" fontWeight={700}>
          Spot {prob.spot.toFixed(2)}
        </text>
        {/* max pain */}
        {maxPainX !== null ? (
          <>
            <line x1={maxPainX} y1={padY} x2={maxPainX} y2={h - padY} stroke="rgb(244,114,182)" strokeDasharray="2 4" />
            <text x={maxPainX + 4} y={padY + 26} fill="rgb(244,114,182)" fontSize="10" fontWeight={700}>
              Max Pain {maxPainStrike!.toFixed(0)}
            </text>
          </>
        ) : null}
      </svg>

      <div className="mt-3 grid gap-2 text-xs sm:grid-cols-2">
        <p className="text-white/60">
          P(close &gt; spot {prob.spot.toFixed(2)}) ={' '}
          <strong className="text-emerald-200">{(prob.probAboveSpot * 100).toFixed(2)}%</strong>
        </p>
        {prob.probAboveLevels.map((row) => (
          <p key={row.level} className="text-white/60">
            P(close &gt; {row.level.toFixed(2)}) ={' '}
            <strong className="text-cyan-200">{(row.probability * 100).toFixed(2)}%</strong>
          </p>
        ))}
      </div>
    </div>
  );
}

function MaxPainCurve({ report }: { report: OptionsIntelReport }) {
  if (!report.maxPain) return null;
  const w = 760;
  const h = 200;
  const padX = 36;
  const padY = 24;
  const pts = report.maxPain.curve;
  const xs = pts.map((p) => p.strike);
  const ys = pts.map((p) => p.totalPain);
  const xMin = Math.min(...xs);
  const xMax = Math.max(...xs);
  const yMax = Math.max(...ys) || 1;

  const path = pts
    .map((p, i) => {
      const x = padX + ((p.strike - xMin) / (xMax - xMin)) * (w - padX * 2);
      const y = h - padY - (p.totalPain / yMax) * (h - padY * 2);
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(' ');

  const maxPainX = padX + ((report.maxPain.maxPainStrike - xMin) / (xMax - xMin)) * (w - padX * 2);
  const spotX = padX + ((report.spot - xMin) / (xMax - xMin)) * (w - padX * 2);

  return (
    <div className="rounded-[8px] border border-white/12 bg-slate-950/60 p-4">
      <h3 className="mb-3 flex items-center gap-2 text-sm font-black uppercase tracking-[0.12em] text-white">
        Max Pain Curve (total writer pain by close)
      </h3>
      <svg viewBox={`0 0 ${w} ${h}`} className="h-auto w-full">
        <path d={path} fill="none" stroke="rgb(244,114,182)" strokeWidth={2} />
        <line x1={padX} y1={h - padY} x2={w - padX} y2={h - padY} stroke="rgb(255,255,255)" strokeOpacity={0.15} />
        <line x1={maxPainX} y1={padY} x2={maxPainX} y2={h - padY} stroke="rgb(244,114,182)" strokeDasharray="2 4" />
        <text x={maxPainX + 4} y={padY + 12} fill="rgb(244,114,182)" fontSize="10" fontWeight={700}>
          Min @ {report.maxPain.maxPainStrike.toFixed(0)}
        </text>
        <line x1={spotX} y1={padY} x2={spotX} y2={h - padY} stroke="rgb(250,204,21)" strokeDasharray="4 4" />
        <text x={spotX + 4} y={padY + 26} fill="rgb(250,204,21)" fontSize="10" fontWeight={700}>
          Spot {report.spot.toFixed(2)}
        </text>
      </svg>
      <p className="mt-3 text-xs leading-5 text-white/55">
        Max Pain strike is {report.maxPain.maxPainStrike.toFixed(2)} (
        {report.maxPain.distanceFromSpotPct >= 0 ? '+' : ''}
        {report.maxPain.distanceFromSpotPct.toFixed(2)}% from spot). Total pain at that level:{' '}
        {fmtBn(report.maxPain.totalPainAtMax)}.
      </p>
    </div>
  );
}

function Tile({
  label,
  value,
  sub,
  compact,
}: {
  label: string;
  value: string;
  sub?: string;
  compact?: boolean;
}) {
  return (
    <div className="rounded-[6px] border border-white/10 bg-black/25 px-3 py-2">
      <p className="text-[10px] font-black uppercase tracking-[0.14em] text-white/40">{label}</p>
      <p className={`font-black text-white ${compact ? 'text-sm' : 'text-base'}`}>{value}</p>
      {sub ? <p className="text-[10px] text-white/45">{sub}</p> : null}
    </div>
  );
}

function fmtBn(v: number) {
  const a = Math.abs(v);
  if (a >= 1e9) return `${(v / 1e9).toFixed(2)}B`;
  if (a >= 1e6) return `${(v / 1e6).toFixed(2)}M`;
  if (a >= 1e3) return `${(v / 1e3).toFixed(2)}K`;
  return v.toFixed(0);
}

function xTicks(min: number, max: number, n: number): number[] {
  const step = (max - min) / n;
  const out: number[] = [];
  for (let i = 0; i <= n; i += 1) out.push(min + step * i);
  return out;
}

function nextFriday(): string {
  const d = new Date();
  const dow = d.getUTCDay();
  const add = (5 - dow + 7) % 7 || 7;
  d.setUTCDate(d.getUTCDate() + add);
  return d.toISOString().slice(0, 10);
}
