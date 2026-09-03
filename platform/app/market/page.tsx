import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import Link from 'next/link';
import { ArrowLeft, BarChart3, Building2, Crosshair, Sigma } from 'lucide-react';
import { buildTickerConsoleReport } from '@/lib/market-intelligence/ticker-console';
import { TickerProbabilityDistribution } from '@/components/market/TickerProbabilityDistribution';
import { TickerOptionsAnalytics } from '@/components/market/TickerOptionsAnalytics';
import { InstitutionalHoldingsPanel } from '@/components/market/InstitutionalHoldingsPanel';

export const dynamic = 'force-dynamic';

const PRIMARY_TICKER = 'NVDA';

export const metadata: Metadata = {
  title: 'AXIO7 Strategy · NVDA',
  description:
    'Single-stock NVDA option probability, Max Pain, open interest, and SEC 13F institutional holdings.',
};

export default async function MarketPage() {
  const report = await buildTickerConsoleReport(PRIMARY_TICKER);
  const quote = report.quote;
  const spot = quote?.price || report.priceDistribution?.spot || report.options?.spot || 0;
  const defaultVol =
    report.options?.probability?.ivAtm ||
    report.priceDistribution?.annualizedVolatility ||
    0.4;
  const defaultExpiration =
    report.options?.probability?.expiration ||
    report.priceDistribution?.expiration ||
    nextFridayISO();
  const defaultTarget =
    report.options?.maxPain?.maxPainStrike ||
    report.priceDistribution?.oneSigmaLow ||
    spot;

  return (
    <div className="-mx-4 -mb-24 -mt-6 min-h-screen bg-[#f3eee5] px-4 pb-24 pt-0 text-slate-950 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <main className="mx-auto min-h-screen max-w-[1210px] bg-[#05070b] px-5 py-6 text-white shadow-2xl shadow-black/30 sm:px-7">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href={`/market/ticker/${PRIMARY_TICKER}`}
            className="inline-flex items-center gap-2 text-xs font-black uppercase tracking-[0.16em] text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" /> Back to NVDA ticker console
          </Link>
          <span className="font-mono text-xs font-black uppercase tracking-[0.16em] text-slate-500">
            Strategy console · single ticker
          </span>
        </div>

        <section className="rounded-[6px] border border-slate-700 bg-[#141a2b] p-5 shadow-xl shadow-black/25">
          <div className="flex flex-wrap items-start justify-between gap-6">
            <div className="max-w-3xl">
              <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase tracking-[0.16em] text-slate-300">
                <BarChart3 className="h-4 w-4 text-blue-200" /> Smart money & options intel
              </p>
              <h1 className="mt-4 text-3xl font-black tracking-tight text-white">{PRIMARY_TICKER}</h1>
              <p className="mt-3 text-sm font-semibold leading-7 text-slate-200">
                One clean ticker first. Probability distribution, Max Pain / OI / Gamma, and institutional 13F holdings
                stay on this page. No broad watchlist table, no random ticker noise.
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                <Pill icon={<Sigma className="h-3.5 w-3.5" />} label="Option Probability" />
                <Pill icon={<Crosshair className="h-3.5 w-3.5" />} label="Max Pain" />
                <Pill icon={<Building2 className="h-3.5 w-3.5" />} label="13F Holdings" />
              </div>
            </div>

            <div className="text-right">
              <p className="font-mono text-4xl font-black text-white">{spot > 0 ? spot.toFixed(2) : '--'}</p>
              <p className={`mt-2 font-mono text-sm font-black ${tone(quote?.changePct)}`}>
                {fmtSigned(quote?.change)} · {pct(quote?.changePct)}
              </p>
              <p className="mt-2 font-mono text-[10px] text-slate-400">
                {quote?.asOf ? new Date(quote.asOf).toLocaleString() : 'No quote timestamp'}
              </p>
            </div>
          </div>

          <dl className="mt-6 grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
            <Metric label="RSI(14)" value={fmt(quote?.rsi14, 1)} />
            <Metric label="SMA20" value={fmt(quote?.sma20)} />
            <Metric label="SMA50" value={fmt(quote?.sma50)} />
            <Metric label="SMA200" value={fmt(quote?.sma200)} />
            <Metric label="距 200DMA" value={pct(quote?.deviation200Pct)} tone={tone(quote?.deviation200Pct)} />
            <Metric label="5D / 1M" value={`${pct(quote?.change5dPct)} / ${pct(quote?.change1mPct)}`} />
          </dl>
        </section>

        <div className="mt-5 space-y-5">
          {spot > 0 ? (
            <TickerProbabilityDistribution
              ticker={PRIMARY_TICKER}
              defaultSpot={spot}
              defaultTarget={defaultTarget}
              defaultIvAnnual={defaultVol}
              defaultExpiration={defaultExpiration}
              volatilitySource={
                report.options?.probability?.ivAtm
                  ? 'options_iv'
                  : report.priceDistribution?.source === 'historical_volatility'
                    ? 'historical_volatility'
                    : 'manual'
              }
              volatilitySourceLabel={
                report.options?.probability?.ivAtm
                  ? `Live options ATM IV (${report.options.provider})`
                  : report.priceDistribution
                    ? 'Historical volatility fallback, not live options IV'
                    : 'Manual entry'
              }
            />
          ) : null}

          <TickerOptionsAnalytics options={report.options} />

          <InstitutionalHoldingsPanel ticker={PRIMARY_TICKER} />
        </div>

        <footer className="mt-5 rounded-[6px] border border-slate-800 bg-black px-4 py-3 text-xs leading-6 text-slate-400">
          Data can be delayed or unavailable. Probability is a risk-neutral model approximation. 13F data is quarterly
          SEC disclosure, not live trading flow. This page is research tooling, not investment advice.
        </footer>
      </main>
    </div>
  );
}

function Pill({ icon, label }: { icon: ReactNode; label: string }) {
  return (
    <span className="inline-flex items-center gap-2 rounded-[4px] border border-slate-600 bg-[#0a0e1a] px-3 py-1.5 font-mono text-[10px] font-black uppercase tracking-[0.12em] text-slate-200">
      {icon}
      {label}
    </span>
  );
}

function Metric({ label, value, tone: toneClass }: { label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-[4px] border border-slate-700 bg-[#070b16] px-3 py-3">
      <p className="font-mono text-[10px] font-black uppercase tracking-[0.13em] text-slate-400">{label}</p>
      <p className={`mt-2 font-mono text-base font-black ${toneClass || 'text-white'}`}>{value}</p>
    </div>
  );
}

function nextFridayISO(): string {
  const d = new Date();
  const dow = d.getUTCDay();
  const add = (5 - dow + 7) % 7 || 7;
  d.setUTCDate(d.getUTCDate() + add);
  return d.toISOString().slice(0, 10);
}

function fmt(v: number | null | undefined, digits = 2): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '--';
  return v.toFixed(digits);
}

function fmtSigned(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '--';
  return `${v >= 0 ? '+' : ''}${v.toFixed(2)}`;
}

function pct(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '--';
  return `${v >= 0 ? '+' : ''}${v.toFixed(2)}%`;
}

function tone(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return 'text-slate-300';
  if (v > 0) return 'text-emerald-300';
  if (v < 0) return 'text-red-300';
  return 'text-slate-300';
}
