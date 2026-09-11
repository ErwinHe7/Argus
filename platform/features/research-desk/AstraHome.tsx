import React, { useEffect, useState } from 'react';
import { ArrowRight, ArrowUpRight, Check, Minus, RefreshCw } from 'lucide-react';
import { TradingViewChart } from './tradingview';
import { shortlistAge, shortlistSchema, type Shortlist, type ShortlistRow } from './shortlist/contract';
import { publicationFuture, publicationSchema, publisherView, type Publication } from './shortlist/publication';
import './shortlist/shortlist.css';
import { RadarTeaser } from './radar/Radar';
export type { MarketRead } from './types';
const cash = (value: number) => value.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
const dateLabel = (value: string) => new Date(`${value}T12:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });

export function AstraHome() {
  const [data, setData] = useState<Shortlist | null>(null);
  const [publication, setPublication] = useState<Publication | null>(null);
  const [feedAvailable, setFeedAvailable] = useState(false);
  const [error, setError] = useState(''), [loading, setLoading] = useState(true), [attempt, setAttempt] = useState(0);
  const [group, setGroup] = useState<'stocks' | 'funds'>('stocks'), [symbol, setSymbol] = useState('');
  const [expanded, setExpanded] = useState(false), [now, setNow] = useState(Date.now);
  const [selectionRevision, setSelectionRevision] = useState(0);
  useEffect(() => { const timer = window.setInterval(() => setNow(Date.now()), 60000); return () => window.clearInterval(timer); }, []);
  useEffect(() => {
    if (symbol && window.matchMedia('(max-width: 800px)').matches) {
      const heading = document.querySelector<HTMLElement>('.pick-detail h2');
      heading?.focus({ preventScroll: true });
      heading?.closest('aside')?.scrollIntoView({ behavior: 'instant', block: 'start' });
    }
  }, [symbol, selectionRevision]);
  useEffect(() => {
    let active = true, busy = false, controller: AbortController | null = null;
    async function refresh() {
      if (busy) return;
      busy = true; controller = new AbortController();
      const timer = window.setTimeout(() => controller?.abort(), 12000);
      setLoading(true);
      try {
        const response = await fetch('/app/research-desk/data/shortlist-feed/current.json', { signal: controller.signal, cache: 'no-store' });
        if (!response.ok) throw new Error('feed unavailable');
        const result = publicationSchema.parse(await boundedJson(response));
        if (publicationFuture(result)) throw new Error('future publication');
        if (active) {
          setPublication(previous => previous && Date.parse(result.publisher.heartbeatAt) < Date.parse(previous.publisher.heartbeatAt) ? previous : result);
          if (result.shortlist) setData(previous => previous && (result.shortlist!.asOf < previous.asOf || Date.parse(result.shortlist!.sourceRetrievedAt) < Date.parse(previous.sourceRetrievedAt)) ? previous : result.shortlist);
          setFeedAvailable(true); setError(''); setNow(Date.now());
        }
      } catch {
        if (active) setFeedAvailable(false);
        try {
          const response = await fetch('/app/research-desk/data/shortlist.json', { signal: controller.signal, cache: 'no-store' });
          if (!response.ok) throw new Error('snapshot unavailable');
          const result = shortlistSchema.parse(await boundedJson(response));
          if (shortlistAge(result) === 'invalid-future') throw new Error('future snapshot');
          if (active) { setData(previous => previous ?? result); setError(''); setNow(Date.now()); }
        } catch {
          if (active) setError('The shortlist could not be refreshed. Try again or explore the markets.');
        }
      } finally {
        window.clearTimeout(timer); busy = false; if (active) setLoading(false);
      }
    }
    void refresh();
    const interval = window.setInterval(() => { if (document.visibilityState === 'visible') void refresh(); }, 60000);
    const onVisible = () => { if (document.visibilityState === 'visible') void refresh(); };
    document.addEventListener('visibilitychange', onVisible);
    return () => { active = false; controller?.abort(); window.clearInterval(interval); document.removeEventListener('visibilitychange', onVisible); };
  }, [attempt]);
  const rows = data?.[group] ?? [];
  const selected = rows.find(row => row.symbol === symbol) ?? rows[0];
  const stale = data ? shortlistAge(data, now) === 'review-needed' : false;
  const visible = expanded ? rows : rows.slice(0, 3);
  const automation = publisherView(feedAvailable ? publication : null, now);
  const first = rows[0];
  return <div className="picks-home">
    <section className="picks-opening"><div><h1>What’s worth buying?</h1><p>A clear shortlist, the reasons behind it, and what needs to happen next.</p></div><a className="text-button" href="#/board">Explore more markets<ArrowUpRight size={16}/></a></section>
    <div className="picks-automation" role="status"><strong className={automation.active ? 'is-running' : ''}>{automation.label}</strong><span>{automation.detail}</span></div>
    <div className="picks-toolbar"><div className="picks-filters" role="group" aria-label="Shortlist asset type">{(['stocks', 'funds'] as const).map(value => <button key={value} aria-pressed={group === value} onClick={() => { setGroup(value); setSymbol(''); setExpanded(false); }}>{value === 'stocks' ? 'Stocks' : 'ETFs & funds'}{data && <span>{value === 'stocks' ? data.universe.companyStocks : data.universe.funds}</span>}</button>)}</div><div className="picks-date">{data && <span>Snapshot · {dateLabel(data.asOf)}</span>}<button className="icon-button" aria-label="Refresh shortlist" disabled={loading} onClick={() => setAttempt(value => value + 1)}><RefreshCw size={16}/></button></div></div>
    {error && <p className="picks-status" role="alert">{error}{data && ' The previous dated list remains below.'}</p>}
    {stale && <p className="picks-status">This snapshot needs a refresh before a new buy decision. The historical ranking is retained below.</p>}
    {!data ? <div className="picks-empty" role="status"><h2>{loading ? 'Checking the shortlist…' : 'The shortlist is unavailable.'}</h2><p>{loading ? 'Loading the recorded rules and their evidence.' : 'No stock suggestions are shown without their underlying evidence.'}</p>{!loading && <div><button className="gold-button" onClick={() => setAttempt(value => value + 1)}>Try again</button><a className="text-button" href="#/board">Browse markets<ArrowRight size={16}/></a></div>}</div> : <>
      {first && <section className="picks-answer" aria-label="Where to start"><div><h2>{stale ? `${first.symbol} led the last recorded screen.` : first.criteriaMet === first.criteriaTotal ? `Start your research with ${first.symbol}.` : 'No stock clears every check yet.'}</h2><p>{stale ? 'Refresh the underlying observations before using this ranking for a new decision.' : first.criteriaMet === first.criteriaTotal ? `${first.summary} Review the conditions and counterpoint below before making a plan.` : `${first.symbol} ranks first in this group, but ${first.watch}`}</p></div><button className="text-button" onClick={() => { setSymbol(first.symbol); setSelectionRevision(value => value + 1); document.querySelector<HTMLElement>('.pick-detail')?.scrollIntoView({ behavior: 'instant', block: 'start' }); }}>Why {first.symbol}<ArrowRight size={16}/></button></section>}
      <p className="picks-scope">Technical screen of {group === 'stocks' ? data.universe.companyStocks : data.universe.funds} tracked {group === 'stocks' ? 'companies' : 'funds'}. Ranked by three published checks, using recorded daily closes. <a href="#picks-method" onClick={event => { event.preventDefault(); const details = document.getElementById('picks-method') as HTMLDetailsElement | null; if (details) { details.open = true; details.scrollIntoView({ behavior: 'instant', block: 'start' }); details.querySelector('summary')?.focus(); } }}>How we choose</a></p>
      <div className="picks-layout"><section className="picks-list" aria-label="Ranked shortlist">
        {visible.length ? <ol>{visible.map(row => <li key={row.symbol} className={selected?.symbol === row.symbol ? 'is-selected' : ''}><button className="pick-select" aria-pressed={selected?.symbol === row.symbol} aria-label={`Review ${row.symbol}, rank ${row.rank}`} onClick={() => { setSymbol(row.symbol); setSelectionRevision(value => value + 1); }}><span className="pick-rank">{row.rank}</span><span className="pick-content"><span className="pick-title"><strong>{row.symbol}</strong><span>{cash(row.close)}</span></span><span className="pick-name">{row.name}</span><span className="pick-reason">{row.summary}</span><span className="pick-verdict"><span className={row.criteriaMet === 3 ? 'matches' : ''}>{stale ? 'Historical' : row.criteriaMet === 3 ? 'Fits the screen' : 'Wait for confirmation'}</span><span>{row.criteriaMet} of {row.criteriaTotal} checks<ArrowRight size={14}/></span></span></span></button></li>)}</ol> : <div className="picks-empty"><h2>No usable {group === 'stocks' ? 'stock' : 'fund'} evidence.</h2><p>Incomplete observations are excluded instead of receiving a rank.</p></div>}
        {rows.length > 3 && <button className="text-button picks-show-all" onClick={() => setExpanded(value => !value)}>{expanded ? 'Show the shortlist' : `Compare all ${rows.length} ${group === 'stocks' ? 'stocks' : 'funds'}`}<ArrowRight size={14}/></button>}
        <p className="picks-list-note">A screen match is a research candidate. The list does not assess business value or forecast returns.</p>
      </section>{selected && <CandidateDetails row={selected}/>}</div>
      <details className="picks-method" id="picks-method"><summary>How we choose—and what this list cannot tell you</summary><div className="picks-method-content"><div><h2>Three straightforward checks</h2>{data.methodology.criteria.map(item => <p key={item.id}><strong>{item.label}.</strong> {item.definition}</p>)}<p>{data.methodology.ranking}</p><p>{data.methodology.scoreMeaning}</p></div><div><h2>The evidence behind the list</h2><p>Source: {selected?.source ?? 'Recorded market observations'}. Daily closes through {dateLabel(data.asOf)}. TradingView charts are a separate market display and do not update this ranking.</p><ul>{data.limitations.map(item => <li key={item}>{item}</li>)}</ul>{data.exclusions.length > 0 && <p>Excluded: {data.exclusions.map(item => `${item.symbol} — ${item.reason}`).join('; ')}.</p>}<button className="text-button" onClick={() => { const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })); const anchor = document.createElement('a'); anchor.href = url; anchor.download = 'astra-shortlist.json'; anchor.click(); window.setTimeout(() => URL.revokeObjectURL(url), 1000); }}>Download the ranked evidence<ArrowRight size={14}/></button></div></div></details>
    </>}
    <RadarTeaser/>
    <section className="picks-support"><h2>Go deeper when you need to.</h2><div><a href="#/radar">Event radar &amp; Ask Astra<ArrowUpRight size={14}/></a><a href="#/structure">Charts<ArrowUpRight size={14}/></a><a href="#/strategies">Test a strategy<ArrowUpRight size={14}/></a><a href="#/iv">Options lab<ArrowUpRight size={14}/></a></div></section>
  </div>;
}
async function boundedJson(response: Response): Promise<unknown> {
  if (!response.body) throw new Error('No evidence body');
  const reader = response.body.getReader(), chunks: Uint8Array[] = []; let length = 0;
  try {
    for (;;) { const { done, value } = await reader.read(); if (done) break; length += value.byteLength; if (length > 524288) { await reader.cancel(); throw new Error('Evidence exceeds limit'); } chunks.push(value); }
    const bytes = new Uint8Array(length); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  } finally { reader.releaseLock(); }
}
function CandidateDetails({ row }: { row: ShortlistRow }) {
  return <aside className="pick-detail" aria-label={`${row.symbol} supporting evidence`}><button className="text-button pick-back" onClick={() => document.querySelector<HTMLElement>('.pick-select[aria-pressed="true"]')?.focus()}>Back to shortlist</button><div className="pick-detail-heading"><div><h2 tabIndex={-1} aria-live="polite">A closer look at {row.symbol}</h2><span>{row.assetType.replaceAll('_', ' ')}</span></div><a className="text-button" href={`#/structure?symbol=${encodeURIComponent(row.symbol)}`}>Full chart<ArrowUpRight size={14}/></a></div><TradingViewChart symbol={row.symbol} compact/>
    <div className="pick-checks">{row.criteria.map(item => <div key={item.id}>{item.passed ? <Check size={15} className="passed"/> : <Minus size={15}/>}<span><strong>{item.label}</strong><span>{item.detail}</span></span></div>)}</div>
    <div className="pick-caution"><h3>The catch</h3><p>{row.counterpoint}</p><h3>Before you buy</h3><p>{row.watch}</p></div><a className="gold-button" href={`#/positions?symbol=${encodeURIComponent(row.symbol)}`}>Make a plan for {row.symbol}<ArrowRight size={15}/></a><p className="pick-source">Rule evidence: {dateLabel(row.asOf)} close · {row.coverage.observedSessions} observed sessions. Calendar completeness and price adjustments are unverified.</p>
  </aside>;
}
