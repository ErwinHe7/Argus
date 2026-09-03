'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { TickerProbabilityDistribution } from '@/components/market/TickerProbabilityDistribution';

export default function OptionProbabilityToolPage() {
  const [ticker, setTicker] = useState('NVDA');
  const [draft, setDraft] = useState('NVDA');

  return (
    <div className="-mx-4 -mb-24 -mt-6 space-y-5 bg-[#05070b] px-4 pb-24 pt-6 text-white sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <Link
        href="/market"
        className="inline-flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-300 hover:text-white"
      >
        <ArrowLeft className="h-4 w-4" /> Back to Market Console
      </Link>

      <header className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/40">
        <p className="font-mono text-xs uppercase tracking-[0.16em] text-slate-300">Tools</p>
        <h1 className="mt-1 text-3xl font-black text-white">Option Probability Distribution</h1>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-200">
          Single-stock lognormal terminal-price probability calculator. Risk-neutral / model-implied — not a forecast,
          not investment advice. Enter a ticker to seed defaults from the ticker console, then tune IV, target, and
          expiration to explore probabilities.
        </p>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setTicker(draft.trim().toUpperCase() || 'NVDA');
          }}
          className="mt-4 flex flex-wrap items-center gap-2"
        >
          <label className="flex items-center gap-2 rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-2">
            <span className="font-mono text-[10px] uppercase tracking-[0.14em] text-slate-400">Ticker</span>
            <input
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              className="w-24 bg-transparent font-mono text-base font-black uppercase text-white outline-none"
              placeholder="NVDA"
            />
          </label>
          <button
            type="submit"
            className="rounded-[6px] border border-blue-400/60 bg-blue-500/20 px-3 py-2 text-xs font-black uppercase tracking-wider text-blue-100 hover:bg-blue-500/30"
          >
            Load defaults
          </button>
          <Link
            href={`/market/ticker/${ticker}`}
            className="rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-2 text-xs font-black uppercase tracking-wider text-slate-300 hover:text-white"
          >
            Open full ticker console →
          </Link>
        </form>
      </header>

      <TickerProbabilityDistribution
        key={ticker}
        ticker={ticker}
        defaultSpot={100}
        defaultIvAnnual={0.4}
        defaultExpiration={nextFridayISO()}
        volatilitySource="manual"
        volatilitySourceLabel="Manual entry"
      />

      <p className="text-xs leading-5 text-slate-400">
        Tip: for real-time spot, IV, and nearest expiry autofill, open the full ticker console at{' '}
        <Link href={`/market/ticker/${ticker}`} className="text-blue-300 underline-offset-4 hover:underline">
          /market/ticker/{ticker}
        </Link>
        .
      </p>
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
