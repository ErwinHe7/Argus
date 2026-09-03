import type { Metadata } from 'next';
import Link from 'next/link';
import {
  ArrowLeft,
  BarChart3,
  Database,
  LockKeyhole,
  ShieldCheck,
} from 'lucide-react';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export const metadata: Metadata = {
  title: 'AXIO7 Multi-factor Shadow Model',
  description:
    'An independent research candidate using 40% momentum, 20% liquidity proxy, and 40% regime-conditioned price-volume factors.',
};

const groups = [
  {
    weight: '40%',
    title: 'Momentum',
    detail: 'Uses only completed price and volume windows available by the observation cutoff.',
  },
  {
    weight: '20%',
    title: 'Liquidity proxy',
    detail: 'Currently defined as an OHLCV turnover proxy. It does not claim spread, depth, or impact cost without quote data.',
  },
  {
    weight: '40%',
    title: 'Regime-conditioned PV',
    detail: 'Uses a causal market-state gate for price-volume factors instead of treating one regime constant as a cross-sectional signal.',
  },
] as const;

const blockers = [
  'Bind licensed point-in-time universe, adjusted daily bars, delistings, and corporate actions to an immutable manifest.',
  'Complete purged walk-forward, cost, turnover, capacity, negative-control, and untouched-holdout tests.',
  'Complete a real forward shadow and have an operator review the exact artifact hash.',
  'Connect the validated Rust service to the site. Until then, publish no rankings or probabilities.',
] as const;

export default function ScannerPage() {
  return (
    <main className="min-h-screen bg-[#07090d] px-5 py-8 text-slate-100 sm:px-8">
      <div className="mx-auto max-w-5xl">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link
            href="/#research-workspace"
            className="inline-flex items-center gap-2 text-sm font-semibold text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to quantitative research
          </Link>
          <span className="rounded-full border border-amber-400/40 bg-amber-400/10 px-3 py-1 text-xs font-bold tracking-wide text-amber-200">
            SHADOW · CANDIDATE_NOT_PROMOTED
          </span>
        </div>

        <section className="mt-6 rounded-2xl border border-slate-700 bg-gradient-to-br from-slate-900 to-[#0a0e17] p-6 sm:p-8">
          <div className="flex items-start gap-4">
            <div className="rounded-xl border border-sky-400/30 bg-sky-400/10 p-3 text-sky-200">
              <BarChart3 className="h-6 w-6" />
            </div>
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.14em] text-sky-300">
                Independent multi-factor research model
              </p>
              <h1 className="mt-2 text-3xl font-black tracking-tight">
                Rankings withheld while validation continues
              </h1>
              <p className="mt-3 max-w-3xl text-base leading-7 text-slate-300">
                The retired page calculated rankings from Yahoo data in TypeScript without proving
                licensing, point-in-time integrity, or complete coverage. The replacement is a deterministic
                Rust research ranking. Missing, stale, or unlicensed data fails the entire request closed
                instead of silently skipping symbols and showing a deceptively complete list.
              </p>
            </div>
          </div>
        </section>

        <section className="mt-6 grid gap-4 md:grid-cols-3">
          {groups.map((group) => (
            <article
              key={group.title}
              className="rounded-xl border border-slate-700 bg-slate-900/70 p-5"
            >
              <p className="text-3xl font-black text-white">{group.weight}</p>
              <h2 className="mt-2 text-lg font-bold text-sky-200">{group.title}</h2>
              <p className="mt-2 text-sm leading-6 text-slate-400">{group.detail}</p>
            </article>
          ))}
        </section>

        <section className="mt-6 rounded-xl border border-slate-700 bg-slate-900/70 p-6">
          <div className="flex items-center gap-3">
            <LockKeyhole className="h-5 w-5 text-amber-300" />
            <h2 className="text-xl font-bold">Required before publication</h2>
          </div>
          <ol className="mt-4 space-y-3 text-sm leading-6 text-slate-300">
            {blockers.map((blocker, index) => (
              <li key={blocker} className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-slate-800 text-xs font-bold text-sky-200">
                  {index + 1}
                </span>
                <span>{blocker}</span>
              </li>
            ))}
          </ol>
        </section>

        <section className="mt-6 grid gap-4 sm:grid-cols-2">
          <article className="rounded-xl border border-emerald-400/30 bg-emerald-400/5 p-5">
            <ShieldCheck className="h-5 w-5 text-emerald-300" />
            <h2 className="mt-3 font-bold">Output boundary</h2>
            <p className="mt-2 text-sm leading-6 text-slate-300">
              Output is limited to research scores, factor contributions, data cutoffs, and constraints.
              It never emits BUY/SELL labels, target positions, or orders.
            </p>
          </article>
          <article className="rounded-xl border border-violet-400/30 bg-violet-400/5 p-5">
            <Database className="h-5 w-5 text-violet-300" />
            <h2 className="mt-3 font-bold">Currently available</h2>
            <p className="mt-2 text-sm leading-6 text-slate-300">
              The intraday HMM, SDE, and kernel research entry remains independent. This candidate&apos;s
              validation state does not block that separate workflow.
            </p>
            <Link
              href="/"
              className="mt-4 inline-flex rounded-lg border border-violet-300/40 bg-violet-300/10 px-3 py-2 text-sm font-bold text-violet-100 hover:bg-violet-300/20"
            >
              Open AXIO7 Research
            </Link>
          </article>
        </section>

        <p className="mt-6 text-xs leading-5 text-slate-500">
          This is impersonal market research, not investment advice. Automatic execution remains disabled.
        </p>
      </div>
    </main>
  );
}
