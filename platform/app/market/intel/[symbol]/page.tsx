import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowLeft, Brain, Building2, Sigma, Target } from 'lucide-react';
import { buildTickerConsoleReport } from '@/lib/market-intelligence/ticker-console';
import { TickerProbabilityDistribution } from '@/components/market/TickerProbabilityDistribution';
import { MaxPainChart } from '@/components/market/MaxPainChart';
import { InstitutionalHoldingsPanel } from '@/components/market/InstitutionalHoldingsPanel';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: { params: { symbol: string } }): Promise<Metadata> {
  const sym = params.symbol.toUpperCase();
  return {
    title: `${sym} · AXIO7 Intel`,
    description: `${sym} smart-money intelligence: option probability distribution, Max Pain dealer pin map, and Goldman / JPMorgan / Jane Street / Citadel 13F holdings with quarter-over-quarter deltas.`,
  };
}

export default async function IntelPage({ params }: { params: { symbol: string } }) {
  const symbol = params.symbol.toUpperCase();
  const report = await buildTickerConsoleReport(symbol);

  const quote = report.quote;
  const options = report.options;

  return (
    <div className="-mx-4 -mb-24 -mt-6 space-y-5 bg-[#05070b] px-4 pb-24 pt-6 text-white sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Link
          href={`/market/ticker/${symbol}`}
          className="inline-flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-300 hover:text-white"
        >
          <ArrowLeft className="h-4 w-4" /> Back to {symbol} ticker console
        </Link>
        <Link
          href="/market"
          className="text-xs font-black uppercase tracking-[0.14em] text-slate-400 hover:text-white"
        >
          Market Console →
        </Link>
      </div>

      <header className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/40">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-xs uppercase tracking-[0.16em] text-blue-200">
              <Brain className="h-4 w-4" /> Smart Money & Options Intel
            </p>
            <h1 className="mt-2 font-mono text-4xl font-black tracking-tight text-white">{symbol}</h1>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-200">
              Three-in-one intel view: <strong className="text-blue-200">Option Probability</strong> (lognormal terminal-price model),
              <strong className="text-blue-200"> Max Pain</strong> (dealer pin map from open interest), and
              <strong className="text-blue-200"> Institutional 13F</strong> (latest reported positions from Goldman, JPMorgan, Jane Street, Citadel, Susquehanna, Renaissance — with quarter-over-quarter deltas).
            </p>
          </div>
          {quote?.price ? (
            <div className="text-right">
              <p className="font-mono text-3xl font-black text-white">${quote.price.toFixed(2)}</p>
              <p className="font-mono text-xs text-slate-400">
                {quote.asOf ? new Date(quote.asOf).toLocaleString() : 'no timestamp'}
              </p>
            </div>
          ) : null}
        </div>

        {/* In-page nav */}
        <nav className="mt-5 flex flex-wrap gap-2">
          <SectionLink href="#probability" icon={<Sigma className="h-3.5 w-3.5" />} label="Option Probability" />
          <SectionLink href="#max-pain" icon={<Target className="h-3.5 w-3.5" />} label="Max Pain" />
          <SectionLink href="#institutional" icon={<Building2 className="h-3.5 w-3.5" />} label="13F Holdings" />
        </nav>
      </header>

      <section id="probability" className="scroll-mt-24">
        {quote?.price && quote.price > 0 ? (
          <TickerProbabilityDistribution
            ticker={symbol}
            defaultSpot={quote.price}
            defaultTarget={
              options?.maxPain?.maxPainStrike ??
              report.priceDistribution?.oneSigmaLow ??
              quote.price
            }
            defaultIvAnnual={
              options?.probability?.ivAtm ??
              report.priceDistribution?.annualizedVolatility ??
              0.3
            }
            defaultExpiration={
              options?.probability?.expiration ??
              report.priceDistribution?.expiration ??
              nextFridayISO()
            }
            volatilitySource={options?.probability?.ivAtm ? 'options_iv' : 'historical_volatility'}
            volatilitySourceLabel={
              options?.probability?.ivAtm
                ? `Live options ATM IV (${options.provider})`
                : 'Historical volatility fallback, not live options IV'
            }
          />
        ) : (
          <EmptyCard title="Option Probability unavailable" body="No reliable spot quote — probability model can't seed defaults." />
        )}
      </section>

      <section id="max-pain" className="scroll-mt-24 rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-xl shadow-black/30">
        <header className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="mb-2 inline-flex items-center gap-2 rounded-[6px] border border-amber-400/50 bg-amber-500/15 px-3 py-1 text-xs font-black uppercase tracking-[0.14em] text-amber-100">
              <Target className="h-4 w-4" /> Max Pain · {options?.provider ?? 'unavailable'}
            </div>
            <h2 className="text-xl font-black text-white">{symbol} Max Pain · {options?.expiration ?? 'no expiry'}</h2>
            <p className="mt-1 max-w-3xl text-xs leading-5 text-slate-300">
              The strike where total option writer payout (call + put) is minimized at expiration — i.e. where dealers would prefer
              the stock to settle. Convergence is a tendency, not a guarantee; treat it as one piece of structural evidence
              alongside flow and catalysts.
            </p>
          </div>
          {options?.maxPain ? (
            <div className="text-right">
              <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-amber-200">max pain</p>
              <p className="font-mono text-3xl font-black text-amber-200">${options.maxPain.maxPainStrike.toFixed(2)}</p>
              <p className="font-mono text-xs text-slate-400">
                {options.maxPain.distanceFromSpotPct >= 0 ? '+' : ''}
                {options.maxPain.distanceFromSpotPct.toFixed(2)}% from spot
              </p>
            </div>
          ) : null}
        </header>

        {options?.maxPain ? (
          <MaxPainChart
            ticker={symbol}
            expiration={options.expiration}
            daysToExpiry={options.probability?.daysToExpiry ?? null}
            maxPain={options.maxPain}
          />
        ) : (
          <p className="rounded-[8px] border border-slate-700 bg-black p-4 text-sm leading-6 text-slate-300">
            Options chain unavailable for {symbol} (Yahoo blocked or no listed expiries). Configure
            <code className="mx-1 font-mono text-amber-200">IBKR_BASE_URL</code> or
            <code className="mx-1 font-mono text-amber-200">POLYGON_API_KEY</code> to enable Max Pain.
          </p>
        )}
      </section>

      <section id="institutional" className="scroll-mt-24">
        <InstitutionalHoldingsPanel ticker={symbol} />
      </section>

      <footer className="rounded-[8px] border border-slate-700 bg-slate-900 p-4 text-xs leading-6 text-slate-300">
        Intel page combines model-implied probability, dealer pin maps from OI, and SEC 13F institutional positions.
        Probabilities are risk-neutral approximations; Max Pain is a tendency not a forecast; 13F is quarterly with up
        to 45-day reporting lag and excludes market-making positions. Not investment advice.
      </footer>
    </div>
  );
}

function SectionLink({ href, label, icon }: { href: string; label: string; icon: React.ReactNode }) {
  return (
    <a
      href={href}
      className="inline-flex items-center gap-1.5 rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs font-black uppercase tracking-wider text-slate-300 hover:border-blue-400/60 hover:text-white"
    >
      {icon} {label}
    </a>
  );
}

function EmptyCard({ title, body }: { title: string; body: string }) {
  return (
    <div className="rounded-[10px] border border-slate-700 bg-slate-900 p-6">
      <h2 className="text-lg font-black text-white">{title}</h2>
      <p className="mt-2 text-sm text-slate-300">{body}</p>
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
