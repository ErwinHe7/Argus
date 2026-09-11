import React, { useEffect, useMemo, useState } from 'react';
import { ArrowLeft, ArrowRight, ArrowUpRight, ChevronDown, Download, RefreshCw, Search, Send } from 'lucide-react';
import { download } from '../storage';
import { explainEvidence, type Explanation } from './explain';
import { dateLabel, eventDay, eventOrder, eventTime, eventUpcoming, sourceCurrent, timeLabel, useRadar, type RadarEvent } from './useRadar';
import type { EventRadar } from './contract';
import { EarningsComparison } from './EarningsComparison';
import './radar.css';

type Filter = 'Upcoming' | 'Earnings' | 'Macro' | 'Past';
const initialId = () => new URLSearchParams(location.hash.split('?')[1]).get('event') ?? '';

export function Radar({ initialFilter = 'Upcoming' }: { initialFilter?: Filter }) {
  const { data, loading, error, now, refresh } = useRadar();
  const [filter, setFilter] = useState<Filter>(initialFilter), [query, setQuery] = useState(''), [id, setId] = useState(initialId);
  const [picked, setPicked] = useState(0);
  const events = useMemo(() => data?.events.filter(event => (filter === 'Past' ? !eventUpcoming(event, now) : eventUpcoming(event, now))
    && (filter !== 'Earnings' || event.kind === 'earnings') && (filter !== 'Macro' || event.kind === 'macro')
    && `${event.title} ${event.symbols.join(' ')} ${event.referencePeriod ?? ''}`.toLowerCase().includes(query.toLowerCase())).sort((a, b) => filter === 'Past' ? eventOrder(b).localeCompare(eventOrder(a)) : eventOrder(a).localeCompare(eventOrder(b))) ?? [], [data, filter, query, now]);
  const selected = events.find(event => event.id === id) ?? events[0];
  useEffect(() => {
    if (!picked || !matchMedia('(max-width: 800px)').matches) return;
    const heading = document.querySelector<HTMLElement>('.radar-detail h2');
    heading?.focus({ preventScroll: true }); heading?.closest('aside')?.scrollIntoView({ block: 'start', behavior: 'instant' });
  }, [picked]);
  return <section className="radar-workspace">
    <div className="radar-intro"><div><a className="text-button" href="#/home"><ArrowLeft size={14}/>Picks</a><h1>What could move the market?</h1><p>The next catalyst, what to watch, and the source behind it.</p></div><button className="border-button" onClick={refresh} disabled={loading}><RefreshCw size={14}/>{loading ? 'Checking…' : 'Refresh calendar'}</button></div>
    <p className="radar-status" role="status">{!data ? loading ? 'Opening the source calendar…' : 'Calendar unavailable.' : <>Calendar snapshot {timeLabel(data.generatedAt)}. <span>Source review times are shown separately. No directional forecast.</span></>}</p>
    {error && <p className="radar-alert" role="alert">{error}</p>}
    <div className="radar-toolbar"><div className="radar-filters" role="group" aria-label="Filter catalysts">{(['Upcoming', 'Earnings', 'Macro', 'Past'] as const).map(value => <button key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>{value}</button>)}</div><label className="radar-search"><Search size={16}/><input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Company or event" aria-label="Search catalysts" maxLength={80}/></label></div>
    {data && <p className="radar-coverage">{data.coverage.scope} · {data.events.length} recorded events · {dateLabel(data.coverage.from)} – {dateLabel(data.coverage.through)}</p>}
    <div className="radar-layout"><div className="radar-list" aria-label="Catalyst calendar">
      {events.length ? events.map(event => <button className="radar-event" key={event.id} aria-pressed={selected?.id === event.id} onClick={() => { setId(event.id); setPicked(value => value + 1); }}><span className="radar-event-date">{dateLabel(eventDay(event))}<small>{event.scheduledAt ? new Date(event.scheduledAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', timeZone: 'America/New_York' }) + ' ET' : 'Time unconfirmed'}</small></span><span className="radar-event-copy"><strong>{event.title}</strong><span>{event.referencePeriod ?? (event.kind === 'earnings' ? event.symbols.join(' · ') : 'U.S. macro calendar')}</span><small>{data && sourceCurrent(data, event, now) ? 'Source checked' : 'Source needs review'} · {event.kind === 'earnings' ? 'Earnings' : 'Macro'}</small></span><ArrowRight size={16}/></button>) : <div className="radar-empty"><h2>{loading && !data ? 'Loading the calendar…' : 'No matching events in this coverage.'}</h2><p>{data ? 'Try another filter or consult the original calendars. This is a selected event watchlist, not every market event.' : 'No event dates are shown until their evidence can be loaded.'}</p>{query && <button className="text-button" onClick={() => setQuery('')}>Clear search</button>}</div>}
      <p className="radar-list-note">A catalyst tells you when to pay attention. It does not tell you which way prices will move.</p>
    </div>{data && selected ? <EventDetail data={data} event={selected} now={now}/> : <aside className="radar-detail radar-empty"><h2>Follow the evidence.</h2><p>Select a catalyst to see its source, timing, and watch conditions.</p></aside>}</div>
    {data && <>
      <EvidenceAssistant data={data} event={selected} now={now}/>
      <EarningsComparison/>
      <details className="radar-sources"><summary>Sources, coverage &amp; research record<ChevronDown size={16}/></summary><div className="radar-source-grid">{data.sources.map(source => <div key={source.id}><a href={source.url} target="_blank" rel="noreferrer">{source.title}<ArrowUpRight size={13}/></a><p>{source.mode === 'automatic' ? 'Scheduled checks' : 'Manually verified source'} · {source.state === 'error' ? 'Latest check failed' : 'Source retained'}</p><p>{source.retrievedAt ? `Last verified ${timeLabel(source.retrievedAt)}` : 'No successful verification'}</p>{source.error && <p>{source.error}</p>}</div>)}</div><ul>{data.limitations.map(item => <li key={item}>{item}</li>)}</ul><div className="radar-actions"><button className="text-button" onClick={() => download('astra-event-radar.json', data)}><Download size={14}/>Download the evidence</button><a className="text-button" href="#/forecast">Inspect the forecast record<ArrowRight size={14}/></a></div></details>
    </>}
  </section>;
}

function EventDetail({ data, event, now }: { data: EventRadar; event: RadarEvent; now: number }) {
  const source = data.sources.find(item => item.id === event.sourceId);
  const primarySymbol = event.symbols[0];
  const plan = new URLSearchParams({ symbol: primarySymbol ?? 'SPY', date: eventDay(event), thesis: `${event.title}. ${event.watchFor} Invalidation: [write the condition that would change my view].`, source: event.sourceUrl });
  return <aside className="radar-detail" aria-label="Selected catalyst"><button className="text-button radar-back" onClick={() => document.querySelector<HTMLElement>('.radar-event[aria-pressed="true"]')?.focus()}><ArrowLeft size={14}/>Back to calendar</button><div className="radar-detail-title"><h2 tabIndex={-1}>{event.title}</h2><span>{event.kind === 'earnings' ? primarySymbol : 'Macro'}</span></div><p className="radar-detail-time">{eventTime(event)}</p><p>{event.summary}</p>
    <div className="radar-watch"><h3>What to watch</h3><p>{event.watchFor}</p></div>
    {event.scenarios.length > 0 && <div className="radar-scenarios"><h3>Conditions to compare</h3><p className="radar-caption">Qualitative scenarios; no assigned probability.</p>{event.scenarios.map(scenario => <div key={scenario.condition}><strong>{scenario.condition}</strong><p>{scenario.implication}</p></div>)}</div>}
    <div className="radar-limit"><h3>What we do not know</h3><p>{event.limitation}</p>{event.kind === 'earnings' && <p>There is no verified pre-event option surface or matched historical reaction series for this event in the public feed. An implied move and a direction call are withheld.</p>}</div>
    <p className="radar-proof">{sourceCurrent(data, event, now) ? 'Source within review window.' : 'Recheck the date with the issuer or agency.'} {source?.retrievedAt && `Verified ${timeLabel(source.retrievedAt)}.`}</p>
    <a className="text-button" href={event.sourceUrl} target="_blank" rel="noreferrer">Read the primary source<ArrowUpRight size={14}/></a>
    <div className="radar-actions"><a className="gold-button" href={`#/positions?${plan}`}>Make a trade plan<ArrowRight size={15}/></a><a className="border-button" href={`#/structure?symbol=${encodeURIComponent(primarySymbol ?? 'SPY')}`}>View {primarySymbol ?? 'SPY'} chart<ArrowUpRight size={14}/></a></div>
    {!primarySymbol && <p className="radar-caption">SPY opens as a broad-market reference. It is not an event-specific buy recommendation.</p>}
  </aside>;
}

function EvidenceAssistant({ data, event, now }: { data: EventRadar; event: RadarEvent | undefined; now: number }) {
  const [question, setQuestion] = useState(''), [answer, setAnswer] = useState<(Explanation & { snapshotAt: string }) | null>(null);
  const current = event ? sourceCurrent(data, event, now) : false;
  useEffect(() => { setAnswer(null); }, [event?.id, data.generatedAt, current]);
  const ask = (value: string) => { if (!value.trim()) return; setQuestion(value); setAnswer({ ...explainEvidence(value.slice(0, 500), data, event, now), snapshotAt: data.generatedAt }); };
  return <section className="radar-assistant" aria-label="Astra evidence assistant"><div className="radar-assistant-heading"><div><h2>Ask Astra about the evidence.</h2><p>Recorded facts and simple explanations. No AI call or trading permission.</p></div><span>Evidence assistant</span></div><div className="radar-prompts">{['What should I watch?', 'What should I buy?', 'Can you predict this?'].map(prompt => <button key={prompt} className="border-button" onClick={() => ask(prompt)}>{prompt}</button>)}</div><form onSubmit={e => { e.preventDefault(); ask(question); }}><label htmlFor="radar-question">Ask about this event, its source, or the trading workflow</label><div><input id="radar-question" maxLength={500} value={question} onChange={e => setQuestion(e.target.value)} placeholder={event ? `Explain ${event.title}` : 'What is coming next?'} required/><button className="gold-button" aria-label="Ask Astra"><Send size={16}/>Ask</button></div></form>{answer && <div className="radar-answer" role="status"><h3>{answer.title}</h3>{answer.paragraphs.map((paragraph, index) => <p key={index}>{paragraph}</p>)}<div className="radar-actions">{answer.links.map(link => <a className="text-button" href={link.href} key={link.href} {...(link.href.startsWith('https:') ? { target: '_blank', rel: 'noreferrer' } : {})}>{link.label}<ArrowUpRight size={13}/></a>)}</div><small>Based on the calendar snapshot {timeLabel(answer.snapshotAt)}. Unsupported questions return no answer.</small></div>}</section>;
}

export function RadarTeaser() {
  const { data, now } = useRadar();
  const next = data?.events.filter(event => eventUpcoming(event, now)).sort((a, b) => eventOrder(a).localeCompare(eventOrder(b)))[0];
  return <a className="radar-teaser" href={next ? `#/radar?event=${encodeURIComponent(next.id)}` : '#/radar'}><span>{next ? <><strong>Next catalyst</strong> {next.title} · {eventTime(next)}</> : <><strong>Event radar</strong> Check upcoming catalysts before making a plan.</>}</span><span>Explore radar<ArrowRight size={14}/></span></a>;
}

export function ForecastRecord() {
  const { data, error, loading, now } = useRadar();
  return <section className="radar-workspace"><div className="radar-intro"><div><a className="text-button" href="#/radar"><ArrowLeft size={14}/>Event radar</a><h1>The record behind a prediction.</h1><p>Pre-event hypotheses and sourced outcomes belong together.</p></div></div><div className="radar-record-intro"><h2>No validated direction model is published.</h2><p>The calendar and conditional research are available. A market probability requires a model that has passed chronological evaluation. A claimed win rate from another website cannot establish Leo’s accuracy.</p></div>{error && <p className="radar-alert" role="alert">{error}</p>}{!data ? <p role="status">{loading ? 'Checking published evidence…' : 'Published evidence unavailable.'}</p> : data.records.length ? <div className="radar-ledger">{data.records.map(record => <article key={record.id}><h3>{record.kind === 'hypothesis' ? 'Registered hypothesis' : 'Outcome record'} · {data.events.find(event => event.id === record.eventId)?.title ?? record.eventId}</h3><p>{record.statement}</p><small>{timeLabel(record.registeredAt)} · Record {record.sequence}</small>{record.sourceUrl && <a className="text-button" href={record.sourceUrl} target="_blank" rel="noreferrer">Outcome source<ArrowUpRight size={13}/></a>}</article>)}</div> : <div className="radar-empty"><h3>No published hypotheses or scored outcomes yet.</h3><p>The append-only research journal is implemented. No example wins, hindsight calls, or simulated returns have been added to this public record.</p></div>}<div className="radar-source-grid radar-model-requirements"><div><h3>Market forecast</h3><p>Needs current entitled history, a versioned model, and untouched evaluation periods.</p></div><div><h3>Earnings comparison</h3><p>Needs synchronized pre-event quotes and correctly aligned historical results. A straddle premium is not a probability.</p></div><div><h3>Strategy performance</h3><p>Needs a cash ledger, costs, holdouts, and observed paper execution. A test passing does not establish profitability.</p></div></div>{data && <EvidenceAssistant data={data} event={data.events.find(event => eventUpcoming(event, now))} now={now}/>}<div className="radar-actions"><a className="gold-button" href="#/radar">Explore catalysts<ArrowRight size={14}/></a><a className="border-button" href="#/strategies">Test a strategy<ArrowRight size={14}/></a></div></section>;
}
