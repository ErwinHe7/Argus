import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import Link from 'next/link';
import { ArrowLeft, Atom, Brain, Gauge, Sigma } from 'lucide-react';
import { QUANT_DEFAULT_UNIVERSE } from '@/lib/quant/universe';
import { fetchQuantSeries } from '@/lib/quant/data';
import { runStatArbModel, type StatArbSeries } from '@/lib/quant/stat-arb';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export const metadata: Metadata = {
  title: 'AXIO7 Stat-Arb Model · OU + Kalman + Entropy',
  description:
    'Mathematical/statistical arbitrage research model using OU mean reversion, Kalman filtering, entropy and beta-neutral portfolio weights.',
};

async function fetchSeries(symbols: string[]): Promise<StatArbSeries[]> {
  const out: StatArbSeries[] = [];
  const BATCH = 12;
  for (let i = 0; i < symbols.length; i += BATCH) {
    const batch = symbols.slice(i, i + BATCH);
    const settled = await Promise.allSettled(batch.map((symbol) => fetchQuantSeries(symbol, '5y')));
    for (const result of settled) {
      if (result.status !== 'fulfilled') continue;
      const s = result.value;
      if (s.closes.length < 220) continue;
      out.push({
        symbol: s.symbol,
        dates: s.dates,
        closes: s.closes,
        volumes: s.volumes,
        currentPrice: s.currentPrice,
        asOf: s.asOf,
      });
    }
  }
  return out;
}

export default async function StatArbPage() {
  let report: ReturnType<typeof runStatArbModel> | null = null;
  let error: string | null = null;

  try {
    const benchmark = 'SPY';
    const symbols = Array.from(new Set([...QUANT_DEFAULT_UNIVERSE, benchmark]));
    const series = await fetchSeries(symbols);
    const benchmarkSeries = series.find((s) => s.symbol === benchmark) ?? null;
    const modelSeries = series.filter((s) => s.symbol !== benchmark);
    report = runStatArbModel(modelSeries, benchmarkSeries, { benchmarkSymbol: benchmark });
  } catch (err) {
    error = err instanceof Error ? err.message : 'Unknown model error';
  }

  return (
    <div className="-mx-4 -mb-24 -mt-6 min-h-screen bg-[#f3eee5] px-4 pb-24 pt-0 text-slate-950 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <main className="mx-auto min-h-screen max-w-[1280px] bg-[#05070b] px-5 py-6 text-white shadow-2xl shadow-black/30 sm:px-8">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href="/quant"
            className="inline-flex items-center gap-2 text-xs font-black tracking-[0.08em] text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" /> Back to quant
          </Link>
          <Link
            href="/api/quant/stat-arb"
            className="inline-flex items-center gap-2 rounded-[6px] border border-emerald-400/60 bg-emerald-500/15 px-3 py-1.5 text-xs font-black tracking-[0.08em] text-emerald-100 hover:bg-emerald-500/25"
          >
            Open JSON API
          </Link>
        </div>

        <header className="rounded-[8px] border border-slate-700 bg-gradient-to-br from-[#0b1120] to-[#080d1a] p-6">
          <p className="inline-flex items-center gap-2 rounded-[4px] border border-emerald-400/40 bg-emerald-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase tracking-[0.16em] text-emerald-300">
            <Atom className="h-3.5 w-3.5" /> Mathematical Stat-Arb Lab
          </p>
          <h1 className="mt-3 text-3xl font-black tracking-tight text-white">
            OU + Kalman + Entropy Market-Neutral Model
          </h1>
          <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-200">
            A transparent research model in the spirit of statistical arbitrage: OU mean reversion,
            Kalman filtered trend, cross-sectional z-scores, entropy/energy risk gates, and
            dollar-neutral plus beta-neutral portfolio targets. It is not a Renaissance/Medallion
            replica; it is a clean mathematical sandbox you can inspect and backtest.
          </p>
        </header>

        {error ? (
          <section className="mt-6 rounded-[6px] border border-red-500/50 bg-red-500/10 p-5 text-sm text-red-200">
            Model failed: {error}
          </section>
        ) : report ? (
          <ModelView report={report} />
        ) : null}

        <footer className="mt-7 rounded-[6px] border border-slate-800 bg-black px-5 py-4 text-xs leading-7 text-slate-400">
          Research tool only, not investment advice. Free Yahoo daily data can be delayed or revised.
          Target weights are hypotheses for paper trading, not live orders.
        </footer>
      </main>
    </div>
  );
}

function ModelView({ report }: { report: NonNullable<ReturnType<typeof runStatArbModel>> }) {
  const longs = report.rows.filter((r) => r.side === 'long').slice(0, 10);
  const shorts = report.rows.filter((r) => r.side === 'short').slice(-10).reverse();

  return (
    <>
      <section className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Metric label="Gross" value={pct(report.summary.grossExposure * 100)} />
        <Metric label="Net" value={pct(report.summary.netExposure * 100)} />
        <Metric label="Beta" value={report.summary.betaExposure.toFixed(3)} />
        <Metric label="Avg Confidence" value={pct(report.summary.averageConfidence * 100)} />
      </section>

      <section className="mt-5 grid gap-4 lg:grid-cols-2">
        <Book title="Long Book" rows={longs} tone="long" />
        <Book title="Short Book" rows={shorts} tone="short" />
      </section>

      <section className="mt-7 rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[11px] font-black uppercase tracking-[0.16em] text-violet-300">
              <Sigma className="h-3.5 w-3.5" /> Full Ranked Book
            </p>
            <h2 className="mt-2 text-lg font-black text-white">
              Alpha components and target weights
            </h2>
          </div>
          <p className="font-mono text-[11px] text-slate-400">
            Generated {new Date(report.generatedAt).toLocaleString('zh-CN')}
          </p>
        </div>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[1180px] border-collapse text-left text-[12px]">
            <thead>
              <tr className="border-b border-slate-700 font-mono text-[10px] uppercase tracking-[0.08em] text-slate-400">
                <th className="px-2 py-2.5">Ticker</th>
                <th className="px-2 py-2.5 text-right">Weight</th>
                <th className="px-2 py-2.5 text-right">Alpha</th>
                <th className="px-2 py-2.5 text-right">OU</th>
                <th className="px-2 py-2.5 text-right">Kalman Trend</th>
                <th className="px-2 py-2.5 text-right">Innovation</th>
                <th className="px-2 py-2.5 text-right">Momentum</th>
                <th className="px-2 py-2.5 text-right">Entropy</th>
                <th className="px-2 py-2.5 text-right">Energy</th>
                <th className="px-2 py-2.5 text-right">Beta</th>
                <th className="px-2 py-2.5 text-right">OU Half-Life</th>
              </tr>
            </thead>
            <tbody className="text-slate-200">
              {report.rows.map((row) => (
                <tr key={row.ticker} className="border-b border-slate-800 hover:bg-slate-900/40">
                  <td className="px-2 py-2.5 font-mono font-black text-white">{row.ticker}</td>
                  <td className={`px-2 py-2.5 text-right font-mono font-black ${tone(row.targetWeight)}`}>
                    {pct(row.targetWeight * 100)}
                  </td>
                  <td className={`px-2 py-2.5 text-right font-mono ${tone(row.alpha)}`}>
                    {signed(row.alpha)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">{signed(row.components.ou)}</td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {signed(row.components.kalmanTrend)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {signed(row.components.kalmanInnovation)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {signed(row.components.momentum)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {signed(row.components.entropy)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {signed(row.components.energy)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {num(row.diagnostics.betaToBenchmark, 2)}
                  </td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {num(row.diagnostics.ouHalfLifeDays, 1)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-7 grid gap-4 lg:grid-cols-3">
        <Explainer
          icon={<Atom className="h-4 w-4" />}
          title="OU Spring"
          text="The residual from a slow moving average is modeled like a mean-reverting spring. Large negative residuals can create positive pullback alpha when half-life is reasonable."
        />
        <Explainer
          icon={<Brain className="h-4 w-4" />}
          title="Kalman State"
          text="A local-level Kalman filter separates latent price from observation noise, then scores trend slope and surprise innovation."
        />
        <Explainer
          icon={<Gauge className="h-4 w-4" />}
          title="Entropy/Energy Gate"
          text="High sign entropy and high realized variance are treated as noisy state energy, reducing position confidence."
        />
      </section>
    </>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[6px] border border-slate-700 bg-[#0b1120] px-4 py-3">
      <p className="font-mono text-[10px] font-black uppercase tracking-[0.12em] text-slate-400">
        {label}
      </p>
      <p className="mt-2 font-mono text-2xl font-black text-white">{value}</p>
    </div>
  );
}

function Book({
  title,
  rows,
  tone,
}: {
  title: string;
  rows: NonNullable<ReturnType<typeof runStatArbModel>>['rows'];
  tone: 'long' | 'short';
}) {
  const cls =
    tone === 'long'
      ? 'border-emerald-500/40 bg-emerald-500/5 text-emerald-200'
      : 'border-red-500/40 bg-red-500/5 text-red-200';
  return (
    <article className={`rounded-[8px] border p-5 ${cls}`}>
      <h2 className="font-mono text-xs font-black uppercase tracking-[0.12em]">{title}</h2>
      <ul className="mt-3 space-y-2">
        {rows.map((row) => (
          <li
            key={row.ticker}
            className="flex items-center justify-between rounded-[6px] border border-slate-700 bg-[#070b16] px-4 py-2.5"
          >
            <div>
              <p className="font-mono text-base font-black text-white">{row.ticker}</p>
              <p className="font-mono text-[11px] text-slate-400">
                alpha {signed(row.alpha)} · beta {num(row.diagnostics.betaToBenchmark, 2)}
              </p>
            </div>
            <span className={`font-mono text-xl font-black ${toneClass(row.targetWeight)}`}>
              {pct(row.targetWeight * 100)}
            </span>
          </li>
        ))}
      </ul>
    </article>
  );
}

function Explainer({
  icon,
  title,
  text,
}: {
  icon: ReactNode;
  title: string;
  text: string;
}) {
  return (
    <article className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
      <p className="inline-flex items-center gap-2 text-emerald-300">{icon}</p>
      <h3 className="mt-3 text-base font-black text-white">{title}</h3>
      <p className="mt-2 text-xs leading-6 text-slate-300">{text}</p>
    </article>
  );
}

function pct(v: number): string {
  if (!Number.isFinite(v)) return '-';
  return `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`;
}

function signed(v: number | null): string {
  if (v === null || !Number.isFinite(v)) return '-';
  return `${v >= 0 ? '+' : ''}${v.toFixed(2)}`;
}

function num(v: number | null, digits: number): string {
  if (v === null || !Number.isFinite(v)) return '-';
  return v.toFixed(digits);
}

function tone(v: number): string {
  return v >= 0 ? 'text-emerald-300' : 'text-red-300';
}

function toneClass(v: number): string {
  return v >= 0 ? 'text-emerald-300' : 'text-red-300';
}
