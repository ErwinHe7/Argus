import React, { useEffect, useState } from 'react';
import { ArrowLeft, ArrowRight, Check, Lock, RefreshCw, ShieldCheck, X } from 'lucide-react';
import { assertPublishable, foundryAge, foundryPublicationSchema, type FoundryPublication, type LedgerPublic, type OverlayPublic } from './contract';
import './foundry.css';

type Load = { state: 'loading' } | { state: 'unavailable' } | { state: 'invalid' } | { state: 'ready'; data: FoundryPublication };
type Roles = FoundryPublication['roles'];

// Formatting only: every figure arrives computed, rounded, and validated from Python.
const decimals = (value: number, digits = 2) => value.toLocaleString('en-US', { minimumFractionDigits: digits, maximumFractionDigits: digits });
const percent = (value: number | null) => value === null ? '—' : `${decimals(value)}%`;
const signed = (value: number | null) => value === null ? '—' : `${value > 0 ? '+' : ''}${decimals(value)}%`;
const whole = (value: number) => value.toLocaleString('en-US');
const words = (value: string) => `${value.charAt(0).toUpperCase()}${value.slice(1).toLowerCase().replace(/_/g, ' ')}`;
const short = (hash: string) => `${hash.slice(0, 12)}…`;
const when = (value: string) => value.length === 10
  ? new Date(`${value}T12:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })
  : `${new Date(value).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit', timeZone: 'America/New_York' })} ET`;
const actorName = (roles: Roles, actor: string) => actor === 'human' ? 'Owner' : roles.find(role => role.id === actor)?.name ?? actor;
const STRUCTURES = { covered_call: 'Covered call', collar: 'Collar', protective_put: 'Protective put' } as const;
const EVIDENCE = { EXECUTABLE_QUOTES_OBSERVED: 'Observed executable quotes', MODEL_PRICED_NOT_EXECUTABLE: 'Model priced · not executable', SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE: 'Synthetic fixture · not market evidence' } as const;
const PRICING = { EXECUTABLE_QUOTES: 'Recorded quotes: sold at the bid, bought at the ask', MODEL_PRICED: 'Model values with a stated spread' } as const;
const FILLS = { bid: 'at bid', ask: 'at ask', model: 'model value' } as const;

async function loadFoundry(signal: AbortSignal): Promise<Load> {
  let bytes: Uint8Array | null = null;
  try {
    const response = await fetch('/app/research-desk/data/foundry.json', { cache: 'no-store', signal });
    if (!response.ok || !response.body) return { state: 'unavailable' };
    const reader = response.body.getReader(), chunks: Uint8Array[] = []; let length = 0;
    try {
      for (;;) {
        const { done, value } = await reader.read(); if (done) break;
        length += value.byteLength;
        if (length > 524288) { await reader.cancel(); return { state: 'invalid' }; }
        chunks.push(value);
      }
    } finally { reader.releaseLock(); }
    bytes = new Uint8Array(length); let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  } catch { return { state: 'unavailable' }; }
  try {
    const data = assertPublishable(foundryPublicationSchema.parse(JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes))));
    return foundryAge(data) === 'invalid-future' ? { state: 'invalid' } : { state: 'ready', data };
  } catch { return { state: 'invalid' }; }
}

export function Foundry() {
  const [load, setLoad] = useState<Load>({ state: 'loading' }), [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let alive = true; const controller = new AbortController(); const timer = window.setTimeout(() => controller.abort(), 12000);
    setLoad({ state: 'loading' });
    void loadFoundry(controller.signal).then(result => { if (alive) setLoad(result); }).finally(() => window.clearTimeout(timer));
    return () => { alive = false; window.clearTimeout(timer); controller.abort(); };
  }, [attempt]);
  return <section className="foundry-workspace" aria-labelledby="foundry-title">
    <div className="foundry-intro"><a className="text-button" href="#/home"><ArrowLeft size={14}/>Picks</a><h1 id="foundry-title">Return enhancement &amp; research agents</h1><p>Ideas come from the owner. Agents run the mechanical research: they freeze an idea, test it on development data, check it once on held-out data, and pause it when the evidence decays. No orders are placed.</p></div>
    {load.state === 'loading' ? <p className="foundry-status" role="status">Checking the published research record…</p>
      : load.state !== 'ready' ? <div className="foundry-alert" role="alert"><h2>{load.state === 'invalid' ? 'This research record failed validation.' : 'The research record is unavailable.'}</h2><p>{load.state === 'invalid' ? 'Nothing from it is shown. Missing, contradictory, or future-dated evidence is withheld rather than repaired.' : 'Nothing is shown without its published evidence. Try again shortly.'}</p><button className="border-button" onClick={() => setAttempt(value => value + 1)}><RefreshCw size={14}/>Try again</button></div>
      : <FoundryRecord data={load.data}/>}
  </section>;
}

function FoundryRecord({ data }: { data: FoundryPublication }) {
  return <>
    <p className="foundry-boundary" role="status"><ShieldCheck size={14}/><strong>{data.generatedAt ? `Published ${when(data.generatedAt)}` : 'No research results published yet'}</strong><span>No orders</span><span>Options execution off</span><span>Live stages locked</span><span>{data.llmCalls} LLM calls</span></p>
    <section className="foundry-section" aria-labelledby="foundry-roles"><div className="foundry-heading"><h2 id="foundry-roles">Four research roles</h2><p>Each role runs deterministic code inside a fixed boundary. None of them can place an order.</p></div>
      <div className="foundry-roles">{data.roles.map(role => <article key={role.id}><h3>{role.name}</h3><p>{role.duty}</p><p className="foundry-limit"><strong>Boundary</strong>{role.boundary}</p></article>)}</div>
    </section>
    <section className="foundry-section" aria-labelledby="foundry-ladder"><div className="foundry-heading"><h2 id="foundry-ladder">The research ladder</h2><p>An idea moves up only through recorded gates. Paper is the highest stage implemented; both live stages are locked.</p></div>
      <ol className="foundry-ladder">{data.ladder.map(stage => <li key={stage.id} className={stage.locked ? 'is-locked' : undefined}>
        <div className="foundry-stage-title"><h3>{stage.locked && <Lock size={15} aria-hidden="true"/>}{stage.name}</h3><span>{stage.locked ? 'Locked' : `${stage.automatic ? 'Automatic' : 'Approval required'} · ${actorName(data.roles, stage.owner)}`}</span></div>
        <p>{stage.gate}</p>
        {stage.locked && <div className="foundry-lock"><p>{stage.lockReason}</p><p className="foundry-caption">Would require all of:</p><ul>{stage.futureGates.map(gate => <li key={gate}>{gate}</li>)}</ul></div>}
      </li>)}</ol>
    </section>
    <section className="foundry-section" aria-labelledby="foundry-overlay"><div className="foundry-heading"><h2 id="foundry-overlay">Options overlay backtest</h2><p>A covered call, collar, or protective put on a long stock position, compared with buy-and-hold over the same sessions.</p></div>
      {data.overlay.status === 'ARTIFACT_PENDING' ? <Pending reason={data.overlay.reason} command={data.overlay.command}/> : <Overlay artifact={data.overlay.artifact}/>}
    </section>
    <section className="foundry-section" aria-labelledby="foundry-ledger"><div className="foundry-heading"><h2 id="foundry-ledger">Agent ledger</h2><p>Every role action is an append-only, hash-chained event. Trials are counted, including the ones that failed.</p></div>
      {data.ledger.status === 'ARTIFACT_PENDING' ? <Pending reason={data.ledger.reason} command={data.ledger.command}/> : <Ledger ledger={data.ledger.ledger} roles={data.roles}/>}
    </section>
    <p className="source-line"><ShieldCheck size={13}/><span>{data.generatedAt ? `Generated ${when(data.generatedAt)}` : 'Not generated'} · derived-publication rights {data.derivedPublicationRightsConfirmed ? 'confirmed' : 'not confirmed'} · historical research, not live prices or a recommendation.</span></p>
    <div className="foundry-actions"><a className="gold-button" href="#/strategies">Open Strategies<ArrowRight size={15}/></a><a className="border-button" href="#/iv">Explore Options lab<ArrowRight size={15}/></a></div>
  </>;
}

function Pending({ reason, command }: { reason: string; command: string }) {
  return <div className="foundry-pending"><span className="pill">NOT YET PUBLISHED</span><p>{reason}</p><p className="foundry-caption">Local command for the owner</p><code>{command}</code></div>;
}

function Overlay({ artifact }: { artifact: OverlayPublic }) {
  const { overlay, buyAndHold, difference, counts, activeReturnBootstrap: bootstrap, activeReturnSignFlipP: signFlip } = artifact.metrics;
  const rows: [string, string, string, string][] = [
    ['Total return', signed(overlay.totalReturnPct), signed(buyAndHold.totalReturnPct), signed(difference.totalReturnPct)],
    ['Annualized return', signed(overlay.annualizedReturnPct), signed(buyAndHold.annualizedReturnPct), '—'],
    ['Annualized volatility', percent(overlay.annualizedVolatilityPct), percent(buyAndHold.annualizedVolatilityPct), '—'],
    ['Maximum drawdown', percent(overlay.maxDrawdownPct), percent(buyAndHold.maxDrawdownPct), signed(difference.maxDrawdownPct)],
    ['Downside capture', percent(overlay.downsideCapturePct), '—', '—'],
    ['Upside capture', percent(overlay.upsideCapturePct), '—', '—'],
    ['Premium yield, annualized', percent(overlay.premiumYieldAnnualizedPct), '—', '—'],
  ];
  const facts: [string, string][] = [
    ['Holding', artifact.symbolLabel], ['Structure', STRUCTURES[artifact.structure]], ['Evidence', EVIDENCE[artifact.evidenceStatus]], ['Pricing', PRICING[artifact.pricingMode]],
    ['Source', `${artifact.source.name} · ${artifact.source.licenseScope}`], ['Quote sources', artifact.source.quoteSources.join(', ') || 'None'], ['IV sources', artifact.source.ivSources.join(', ') || 'None'],
    ['Observation cutoff', when(artifact.observationCutoff)], ['Availability cutoff', when(artifact.availabilityCutoff)], ['Freshness', 'Historical backtest, not live'],
    ['Coverage', `${when(artifact.coverage.start)} – ${when(artifact.coverage.end)}`], ['Sessions', whole(artifact.coverage.sessions)], ['Calendar', artifact.coverage.calendarSource],
    ['Option cycles', whole(artifact.coverage.cycles)], ['Engine', artifact.engineVersion],
  ];
  return <div className="foundry-overlay">
    {artifact.evidenceStatus === 'MODEL_PRICED_NOT_EXECUTABLE' && <p className="notice"><ShieldCheck size={15}/><span><strong>Model priced, not executable.</strong> Option values come from a pricing model with a stated spread, not from recorded quotes. They are not prices that could have been traded.</span></p>}
    <dl className="foundry-facts">{facts.map(([term, detail]) => <div key={term}><dt>{term}</dt><dd>{detail}</dd></div>)}<div><dt>Input / config</dt><dd title={`${artifact.inputSha256} / ${artifact.configSha256}`}>{short(artifact.inputSha256)} / {short(artifact.configSha256)}</dd></div></dl>
    <h3 className="foundry-subtitle">Results</h3>
    <div className="table-scroll"><table><thead><tr><th>Measure</th><th>Overlay</th><th>Buy-and-hold</th><th>Difference</th></tr></thead><tbody>{rows.map(([measure, ...cells]) => <tr key={measure}><td>{measure}</td>{cells.map((cell, index) => <td key={index}>{cell}</td>)}</tr>)}</tbody></table></div>
    <p className="foundry-caption">A dash means the lab did not report that figure, for example an annualized return over fewer than 252 sessions.</p>
    <div className="foundry-split">
      <div><h3 className="foundry-subtitle">Outcomes</h3><dl className="definition-list">{([['Assignments', counts.assignments], ['Cap hits', counts.capHits], ['Put exercises', counts.putExercises], ['Deferred rolls', counts.deferredRolls], ['Ex-dividend in-the-money short calls', counts.exDividendItmShortCallEvents]] as const).map(([term, detail]) => <div key={term}><dt>{term}</dt><dd>{whole(detail)}</dd></div>)}</dl><p className="foundry-caption">Ex-dividend events flag early-assignment risk; early exercise is not modelled.</p></div>
      <div><h3 className="foundry-subtitle">Is the difference distinguishable from noise?</h3><dl className="definition-list"><div><dt>Active return, 95% bootstrap interval</dt><dd>{bootstrap.lower95Pct !== null && bootstrap.upper95Pct !== null ? `${signed(bootstrap.lower95Pct)} to ${signed(bootstrap.upper95Pct)}` : 'Not reported'}</dd></div><div><dt>Bootstrap</dt><dd>{words(bootstrap.status)}{bootstrap.resamples !== null && ` · ${whole(bootstrap.resamples)} resamples`}{bootstrap.blockLength !== null && ` · ${whole(bootstrap.blockLength)}-session blocks`}</dd></div><div><dt>Sign-flip p-value</dt><dd>{signFlip === null ? 'Not reported' : signFlip.toLocaleString('en-US', { maximumFractionDigits: 4 })}</dd></div></dl><p className="foundry-caption">Active return compares the overlay with buy-and-hold day by day. These statistics describe this historical sample only.</p></div>
    </div>
    <details className="foundry-disclosure"><summary>Every cycle ({whole(artifact.cycles.length)})</summary>
      <div className="table-scroll"><table><thead><tr><th>Cycle</th><th>Opened</th><th>Expiry</th><th>Legs</th><th>Outcome</th><th>Overlay</th><th>Buy-and-hold</th></tr></thead><tbody>{artifact.cycles.map(cycle => <tr key={cycle.cycleId}><td>{cycle.cycleId}</td><td>{when(cycle.opened)}</td><td>{when(cycle.expiry)}</td><td className="foundry-legs">{cycle.legs.map((leg, index) => <span key={index}>{words(leg.side)} {leg.right} · strike moneyness {signed(leg.strikeMoneynessPct)} · {whole(leg.dte)} DTE · {FILLS[leg.fillSide]}</span>)}</td><td>{words(cycle.outcome)}</td><td>{signed(cycle.overlayReturnPct)}</td><td>{signed(cycle.baselineReturnPct)}</td></tr>)}</tbody></table></div>
    </details>
    <div className="foundry-split">
      <div><h3 className="foundry-subtitle">Assumptions</h3>{artifact.assumptions.length ? <ul className="foundry-list">{artifact.assumptions.map(item => <li key={item}>{item}</li>)}</ul> : <p className="foundry-caption">None declared.</p>}</div>
      <div><h3 className="foundry-subtitle">Caveats</h3><ul className="foundry-list">{artifact.caveats.map(item => <li key={item}>{item}</li>)}</ul></div>
    </div>
  </div>;
}

function Ledger({ ledger, roles }: { ledger: LedgerPublic; roles: Roles }) {
  return <div className="foundry-ledger">
    <dl className="foundry-facts"><div><dt>Events</dt><dd>{whole(ledger.eventCount)}</dd></div><div><dt>Trials recorded</dt><dd>{whole(ledger.trialsTotal)}</dd></div><div><dt>LLM calls</dt><dd>{ledger.llmCalls}</dd></div><div><dt>Chain head</dt><dd title={ledger.headSha256}>{short(ledger.headSha256)}</dd></div></dl>
    {ledger.specs.length ? <div className="foundry-specs">{ledger.specs.map(spec => <article key={spec.specId}>
      <div className="foundry-spec-title"><h3>{spec.template} · {spec.symbolLabel}</h3><span className="pill">{words(spec.status)}</span></div>
      <p className="foundry-caption">{spec.specId} · {words(spec.stage)} stage · trials in family: {whole(spec.familyTrialCount)} · survivors: {whole(spec.survivors)}</p>
      {spec.gates.length > 0 && <ul className="foundry-gates">{spec.gates.map(gate => <li key={gate.id} className={gate.passed ? 'passed' : undefined}>{gate.passed ? <Check size={14}/> : <X size={14}/>}<span><strong>{words(gate.id)} · {gate.passed ? 'passed' : 'not passed'}</strong>{gate.detail}</span></li>)}</ul>}
      <p className="foundry-next"><strong>Next</strong>{spec.nextAction}</p>
    </article>)}</div> : <p className="foundry-caption">No research specs are recorded.</p>}
    <h3 className="foundry-subtitle">Recent events</h3>
    {ledger.events.length ? <div className="table-scroll"><table><thead><tr><th>#</th><th>Time</th><th>Spec</th><th>Role</th><th>Event</th><th>Stage</th><th>Status</th><th>Reasons</th></tr></thead><tbody>{ledger.events.map(event => <tr key={event.seq}><td>{event.seq}</td><td>{when(event.at)}</td><td>{event.specId}</td><td>{actorName(roles, event.role)}</td><td>{words(event.kind)}</td><td>{event.fromStage ? words(event.fromStage) : '—'} → {event.toStage ? words(event.toStage) : '—'}</td><td>{words(event.status)}</td><td>{event.reasons.length ? event.reasons.join('; ') : '—'}</td></tr>)}</tbody></table></div> : <p className="foundry-caption">No events are recorded.</p>}
    <p className="foundry-caption">Showing up to the 50 most recent events, oldest first. The full ledger stays with its owner.</p>
  </div>;
}
