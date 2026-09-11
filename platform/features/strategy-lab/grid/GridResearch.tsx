import React, { useEffect, useRef, useState } from 'react';
import { ArrowLeft, Download, FlaskConical, LoaderCircle, Play, Upload } from 'lucide-react';
import { runGridReplay } from './runtime';
import { GRID_MAX_IMPORT_BYTES, parseGridRequest, parseGridResult } from './validation';
import type { GridRequest, GridResult } from './types';
import './grid.css';

// Extend Astra's flat working surface. Rust owns every level, fill, ledger, and return.
// The first state asks for evidence; demonstrations are explicitly chosen and labeled.
type Draft = Pick<GridRequest, 'lower' | 'upper' | 'tick_size' | 'starting_capital' | 'commission_per_order' | 'spacing'> & {
  intervals: string;
  slippage_bps: string;
  portfolio_loss_limit_bps: string;
};
const DEMOS = [
  { id: 'range', label: 'Range' },
  { id: 'decline', label: 'Decline' },
  { id: 'rally', label: 'Rally' },
] as const;
const dollars = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 2 });
const prices = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 6 });
const percentages = new Intl.NumberFormat('en-US', { style: 'percent', minimumFractionDigits: 2, maximumFractionDigits: 2 });
const integers = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });
const money = (value: string) => dollars.format(Number(value));
const price = (value: string) => prices.format(Number(value));
const pct = (value: number) => percentages.format(value);
const words = (value: string) => value.toLowerCase().replaceAll('_', ' ');
const EVENT_REASONS: Record<string, string> = {
  latched_portfolio_loss_next_observed_open: 'The portfolio loss trigger had latched. Inventory exited at the next observed open.',
  prior_close_sell_limit_eligible_at_open: 'The prior close proposed a sale, and the next opening price met its limit.',
  next_open_below_sell_limit: 'The opening price was below the sell limit. This proposal expired without a fill.',
  opening_price_outside_frozen_range: 'The opening price was outside the fixed range. The buy proposal expired.',
  adverse_open_above_buy_limit: 'The opening price exceeded the buy limit. The proposal expired without a fill.',
  cash_or_exit_fee_reserve_insufficient: 'Cash or the reserved exit fee was insufficient. The buy proposal expired.',
  prior_downward_close_crossing_next_open_limit: 'The prior close crossed a buy level, and the next opening price met the limit.',
  'marked_equity_reached_fixed_starting_capital_loss_limit; exit_next_observed_open': 'Marked equity reached the fixed portfolio loss trigger. Exit is scheduled for the next observed open.',
  completed_close_at_or_above_upper_slot_level: 'The completed close reached this slot’s sell level. A sale is proposed for the next observed open.',
  completed_close_crossed_down_through_lower_slot_level: 'The completed close crossed down through this slot’s buy level. A purchase is proposed for the next observed open.',
};

function toDraft(input: GridRequest): Draft {
  return {
    lower: input.lower, upper: input.upper, tick_size: input.tick_size,
    starting_capital: input.starting_capital, commission_per_order: input.commission_per_order,
    spacing: input.spacing, intervals: String(input.intervals),
    slippage_bps: String(input.slippage_bps), portfolio_loss_limit_bps: String(input.portfolio_loss_limit_bps),
  };
}

function downloadJson(name: string, serialized: string) {
  const url = URL.createObjectURL(new Blob([serialized], { type: 'application/json' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function GridResearch({ onBack }: { onBack: () => void }) {
  const [input, setInput] = useState<GridRequest | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [result, setResult] = useState<GridResult | null>(null);
  const [frozenReport, setFrozenReport] = useState('');
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const operation = useRef(0);
  const heading = useRef<HTMLHeadingElement>(null);
  const reportHeading = useRef<HTMLHeadingElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    heading.current?.focus({ preventScroll: true });
    return () => { operation.current += 1; };
  }, []);

  useEffect(() => {
    // Focus after React has committed the new report, including repeated runs.
    // Let the browser reveal the result for keyboard and sighted users alike.
    if (result) reportHeading.current?.focus();
  }, [result]);

  function clearResult() {
    setResult(null);
    setFrozenReport('');
  }

  function installRequest(value: unknown) {
    const next = parseGridRequest(value);
    setInput(next);
    setDraft(toDraft(next));
    clearResult();
    setStatus(`${next.symbol} loaded. Review the fixed rules, then run the historical replay.`);
  }

  async function loadDemo(id: typeof DEMOS[number]['id']) {
    if (busy) return;
    const ticket = ++operation.current;
    setBusy(`demo-${id}`);
    setError('');
    setStatus('Loading the fictitious demonstration…');
    clearResult();
    try {
      const response = await fetch(`/app/research-desk/grid/${id}.json`, { cache: 'no-store' });
      if (!response.ok) throw new Error('The demonstration could not load. Try again or import a local request.');
      const raw = await response.text();
      if (new Blob([raw]).size > GRID_MAX_IMPORT_BYTES) throw new Error('The demonstration exceeds the 4 MiB import limit.');
      const candidate = parseGridRequest(JSON.parse(raw));
      if (candidate.source_evidence.classification !== 'synthetic_fixture') throw new Error('This demonstration lacks its synthetic-data label. Import a verified request instead.');
      if (ticket === operation.current) installRequest(candidate);
    } catch (reason) {
      if (ticket === operation.current) { setError(reason instanceof Error ? reason.message : 'The demonstration could not load.'); setStatus(''); }
    } finally { if (ticket === operation.current) setBusy(''); }
  }

  async function importFile(file: File) {
    if (busy) return;
    const ticket = ++operation.current;
    setBusy('import');
    setError('');
    setStatus('Reading the request on this device…');
    clearResult();
    try {
      if (file.size > GRID_MAX_IMPORT_BYTES) throw new Error('Choose a complete request JSON no larger than 4 MiB.');
      let value: unknown;
      try { value = JSON.parse(await file.text()); }
      catch { throw new Error('This file is not valid JSON. Export a complete leo-grid-request.v1 request and try again.'); }
      if (ticket === operation.current) installRequest(value);
    } catch (reason) {
      if (ticket === operation.current) { setError(reason instanceof Error ? reason.message : 'The request could not be imported.'); setStatus(''); }
    } finally { if (ticket === operation.current) setBusy(''); }
  }

  function change<K extends keyof Draft>(key: K, value: Draft[K]) {
    if (!draft || busy) return;
    setDraft({ ...draft, [key]: value });
    clearResult();
    setError('');
    setStatus('Rules changed. The prior result was cleared; run a new replay.');
  }

  function requestSnapshot(): GridRequest {
    if (!input || !draft) throw new Error('Import a request or load a demonstration first.');
    // Preserve the declared historical cutoff. It is an assertion, not proof of past selection.
    return parseGridRequest({
      ...input, ...draft,
      intervals: draft.intervals === '' ? undefined : Number(draft.intervals),
      slippage_bps: draft.slippage_bps === '' ? undefined : Number(draft.slippage_bps),
      portfolio_loss_limit_bps: draft.portfolio_loss_limit_bps === '' ? undefined : Number(draft.portfolio_loss_limit_bps),
    });
  }

  async function replay() {
    if (busy) return;
    const ticket = ++operation.current;
    setError('');
    clearResult();
    try {
      const snapshot = requestSnapshot();
      setBusy('replay');
      setStatus('Validating observations and replaying the fixed rules locally…');
      const report = parseGridResult(await runGridReplay(snapshot));
      if (ticket !== operation.current) return;
      setResult(report);
      setFrozenReport(JSON.stringify(report, null, 2));
      setStatus('Replay complete. Review total portfolio P&L and remaining inventory before closed-cycle profit.');
    } catch (reason) {
      if (ticket === operation.current) { setError(reason instanceof Error ? reason.message : 'The replay could not finish. Check the request and try again.'); setStatus(''); }
    } finally { if (ticket === operation.current) setBusy(''); }
  }

  function exportRequest() {
    try {
      const snapshot = requestSnapshot();
      downloadJson(`${snapshot.symbol}-grid-request.json`, JSON.stringify(snapshot, null, 2));
      setStatus('The complete request was exported, including its source manifest and observations.');
      setError('');
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Check the configuration before exporting.'); }
  }

  return <section className="grid-research" aria-labelledby="grid-research-title" aria-busy={Boolean(busy)}>
    <button className="text-button grid-back" onClick={onBack}><ArrowLeft size={15}/>Back to strategy setup</button>
    <header className="grid-heading">
      <h2 id="grid-research-title" tabIndex={-1} ref={heading}>Grid research</h2>
      <span><FlaskConical size={15}/>Historical replay only</span>
    </header>
    <p className="grid-intro">Test a fixed price range with separate buy-and-sell slots. See how repeated cycles, costs, and unsold shares affect the whole portfolio.</p>
    <p className="grid-boundary">GRID-R1 · U.S. stocks · cash start · whole shares · no borrowing. Grid replay has no broker connection or paper-execution authorization.</p>

    <section className="grid-data" aria-labelledby="grid-data-title">
      <div className="grid-section-heading"><h3 id="grid-data-title">Load replay data</h3>{input && <button className="text-button" disabled={Boolean(busy)} onClick={() => { setInput(null); setDraft(null); clearResult(); setError(''); setStatus('Input cleared. Import a request or choose a demonstration.'); }}>Clear input</button>}</div>
      <p>Import a complete request with its source manifest and daily observations. Your file stays on this device; the replay runs locally.</p>
      <div className="grid-import-row">
        <input ref={fileInput} type="file" accept="application/json,.json" className="sr-only" tabIndex={-1} aria-label="Complete grid request JSON" disabled={Boolean(busy)} onChange={event => { const file = event.currentTarget.files?.[0]; event.currentTarget.value = ''; if (file) void importFile(file); }}/>
        <button className="border-button" disabled={Boolean(busy)} onClick={() => fileInput.current?.click()}><Upload size={15}/>Import request JSON</button>
        <span>leo-grid-request.v1 · maximum 4 MiB</span>
      </div>
      <div className="grid-demo-row"><span>Fictitious DEMO data</span><div>{DEMOS.map(demo => <button key={demo.id} className="border-button" disabled={Boolean(busy)} onClick={() => void loadDemo(demo.id)}>{busy === `demo-${demo.id}` ? <LoaderCircle size={14} className="grid-spinner"/> : <FlaskConical size={14}/>}DEMO · {demo.label}</button>)}</div></div>
      <p className="grid-fine">Demonstrations use invented prices to show behavior in a range, decline, or rally. Their returns are illustrations, not performance evidence.</p>
      <details className="grid-disclosure"><summary>What the request file must include</summary><p>Use a complete <code>leo-grid-request.v1</code> JSON request: symbol, declared configuration cutoff, observation cutoff, fixed rules, <code>source_evidence</code>, and daily <code>bars</code>. The manifest declares source, SHA-256, calendar, adjustment, coverage, availability, classification, and license scope.</p><p>Each bar includes its session date, open/close/availability timestamps, decimal-string OHLC prices, and integer volume. Load a DEMO and export its request to inspect the format. Replace all synthetic observations and declarations before labeling data observed.</p><p><a href="/app/research-desk/grid/GRID-R1.md" target="_blank" rel="noopener noreferrer">Read the full GRID-R1 rules and sources</a></p></details>
    </section>

    <div className="grid-feedback" aria-live="polite" role="status">{busy && <LoaderCircle size={15} className="grid-spinner"/>}{status}</div>
    {error && <div className="grid-error" role="alert"><strong>Replay needs attention</strong><p>{error}</p><p>Review the rules or import a corrected complete request, then try again.</p></div>}

    {!input || !draft ? <div className="grid-empty"><h3>No replay loaded</h3><p>Choose a local request or an explicitly labeled DEMO above. Portfolio P&L, inventory, and the replay journal appear only after the engine completes a run.</p></div> : <>
      <div className="grid-input-summary"><strong>{input.symbol}</strong><span className="grid-evidence-label">{input.source_evidence.classification === 'synthetic_fixture' ? 'Fictitious DEMO · synthetic demonstration' : 'User-supplied observations · not independently verified'}</span><p>{input.bars[0]?.session_date} through {input.bars.at(-1)?.session_date} · {integers.format(input.bars.length)} supplied daily bars</p><p>Source: {input.source_evidence.source}</p></div>
      <form className="grid-form" onSubmit={event => { event.preventDefault(); void replay(); }}>
        <div className="grid-section-heading"><h3>Fix the replay rules</h3><span>USD · parameters stay fixed during a run</span></div>
        <fieldset disabled={Boolean(busy)}>
          <legend className="sr-only">Grid configuration</legend>
          <div className="grid-fields">
            <DecimalField label="Lower bound · USD" value={draft.lower} onChange={value => change('lower', value)}/>
            <DecimalField label="Upper bound · USD" value={draft.upper} onChange={value => change('upper', value)}/>
            <label className="strategy-field">Grid intervals<input type="number" min="2" max="100" step="1" required value={draft.intervals} onChange={event => change('intervals', event.target.value)}/><small>2–100 separate slots</small></label>
            <label className="strategy-field">Grid spacing<select value={draft.spacing} onChange={event => change('spacing', event.target.value as Draft['spacing'])}><option value="arithmetic">Arithmetic · equal price differences</option><option value="geometric">Geometric · equal price ratios</option></select></label>
            <DecimalField label="Starting cash · USD" value={draft.starting_capital} onChange={value => change('starting_capital', value)}/>
            <DecimalField label="Price tick · USD" value={draft.tick_size} onChange={value => change('tick_size', value)}/>
            <DecimalField label="Commission per order · USD" value={draft.commission_per_order} onChange={value => change('commission_per_order', value)}/>
            <label className="strategy-field">Slippage allowance · bps<input type="number" min="0" max="1000" step="1" required value={draft.slippage_bps} onChange={event => change('slippage_bps', event.target.value)}/><small>100 basis points equals 1%.</small></label>
            <label className="strategy-field">Portfolio loss limit · bps<input type="number" min="1" max="10000" step="1" required value={draft.portfolio_loss_limit_bps} onChange={event => change('portfolio_loss_limit_bps', event.target.value)}/><small>A replay trigger, not a guaranteed loss cap.</small></label>
          </div>
        </fieldset>
        <details className="grid-disclosure"><summary>Replay timing and limits</summary><p>Daily closing observations produce decisions for a later session open under the engine’s limit-fill approximation. These bars cannot establish intraday price order, executable quotes, or actual fills.</p><p>The declared configuration cutoff is <time>{input.configured_at}</time>. Importing this timestamp does not prove the rules were selected in the past. This replay is not untouched out-of-sample evidence and cannot promote a strategy.</p><p>Observation cutoff: <time>{input.as_of}</time>. A loss trigger can leave liquidation pending when the input ends. The report keeps that inventory visible.</p></details>
        <div className="grid-run-actions"><button type="submit" className="gold-button" disabled={Boolean(busy)}>{busy === 'replay' ? <LoaderCircle size={15} className="grid-spinner"/> : <Play size={15}/>} {busy === 'replay' ? 'Replaying locally…' : 'Run historical replay'}</button><button type="button" className="border-button" disabled={Boolean(busy)} onClick={exportRequest}><Download size={15}/>Export request</button></div>
      </form>
    </>}

    {result && <GridReport result={result} headingRef={reportHeading} onExport={() => { downloadJson(`${result.configuration.symbol}-grid-result.json`, frozenReport); setStatus('The frozen engine result was exported. Its configuration and evidence hashes are included.'); }}/>} 
  </section>;
}

function DecimalField({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  return <label className="strategy-field">{label}<input type="text" inputMode="decimal" pattern="[0-9]+([.][0-9]+)?" required autoComplete="off" spellCheck={false} value={value} onChange={event => onChange(event.target.value)}/></label>;
}

function GridReport({ result, headingRef, onExport }: { result: GridResult; headingRef: React.RefObject<HTMLHeadingElement>; onExport: () => void }) {
  const { metrics, benchmarks, configuration } = result;
  const synthetic = result.evidence_status === 'SYNTHETIC_DEMONSTRATION';
  const latestEvents = result.journal.slice(-20).reverse();
  return <section className="grid-report" aria-labelledby="grid-result-title">
    <div className="grid-section-heading"><div><h3 id="grid-result-title" tabIndex={-1} ref={headingRef}>{configuration.symbol} replay result</h3><p>{synthetic ? 'Fictitious DEMO · synthetic demonstration' : 'User-supplied observations · not independently verified'}</p></div><button className="border-button" onClick={onExport}><Download size={15}/>Export frozen result</button></div>
    <p className="grid-result-scope">Historical approximation · no live or paper orders · not eligible for strategy promotion</p>

    <dl className="grid-portfolio-totals">
      <div><dt>Total marked portfolio P&L</dt><dd>{money(metrics.total_pnl)}</dd><small>{pct(metrics.total_return)} net return · includes remaining inventory</small></div>
      <div><dt>Remaining inventory</dt><dd>{integers.format(metrics.ending_quantity)} shares</dd><small>{integers.format(metrics.open_slots)} open slots · {money(metrics.ending_cash)} in cash</small></div>
    </dl>
    {metrics.loss_latched && <p className="grid-loss-state">Portfolio loss trigger latched. {metrics.pending_liquidation ? 'Liquidation is still pending; remaining inventory is included in marked P&L.' : 'Review the exit events below; the trigger does not guarantee a maximum loss.'}</p>}
    <EquityChart result={result}/>

    <section className="grid-comparison" aria-labelledby="grid-comparison-title"><h4 id="grid-comparison-title">Ending portfolio comparison</h4><div className="grid-table-scroll" tabIndex={0} role="region" aria-label="Grid, cash, and buy-and-hold comparison"><table><thead><tr><th scope="col">Approach</th><th scope="col">Ending equity</th><th scope="col">Total return</th></tr></thead><tbody><tr><th scope="row">Grid replay</th><td>{money(metrics.ending_equity)}</td><td>{pct(metrics.total_return)}</td></tr><tr><th scope="row">Cash benchmark</th><td>{money(benchmarks.cash_ending_equity)}</td><td>{pct(benchmarks.cash_total_return)}</td></tr><tr><th scope="row">Buy and hold benchmark</th><td>{money(benchmarks.buy_and_hold_ending_equity)}</td><td>{pct(benchmarks.buy_and_hold_total_return)}</td></tr></tbody></table></div><p className="grid-fine">Benchmarks use this engine report’s period and assumptions. All values are historical replay output.</p></section>

    <section className="grid-accounting" aria-labelledby="grid-accounting-title"><h4 id="grid-accounting-title">P&L and risk detail</h4><dl><dt>Closed-cycle P&L</dt><dd>{money(metrics.realized_cycle_pnl)}</dd><dt>Other realized exit P&L</dt><dd>{money(metrics.realized_exit_pnl)}</dd><dt>Unrealized inventory P&L</dt><dd>{money(metrics.unrealized_pnl)}</dd><dt>Total fees</dt><dd>{money(metrics.fees)}</dd><dt>Maximum marked drawdown</dt><dd>{pct(metrics.max_drawdown)}</dd><dt>Completed cycles</dt><dd>{integers.format(metrics.completed_cycles)}</dd><dt>Sessions outside the range</dt><dd>{integers.format(metrics.range_breach_sessions)}</dd><dt>Replay sessions</dt><dd>{integers.format(metrics.sessions)}</dd></dl><p className="grid-fine">Closed-cycle profit alone omits unrealized inventory losses. Total marked portfolio P&L above is the overall result.</p></section>

    <section className="grid-slot-section" aria-labelledby="grid-slots-title"><h4 id="grid-slots-title">Slot ledger</h4><p>Each slot retains its assigned budget and whole-share quantity. Pending decisions are not completed fills.</p><div className="grid-table-scroll" tabIndex={0} role="region" aria-label="Grid slot ledger"><table><thead><tr><th scope="col">Slot</th><th scope="col">Buy / sell levels</th><th scope="col">Budget</th><th scope="col">Shares / cycle</th><th scope="col">Held</th><th scope="col">Entry</th><th scope="col">Entry fee</th><th scope="col">Cycles</th><th scope="col">Pending</th></tr></thead><tbody>{result.slots.map(slot => <tr key={slot.slot_id}><th scope="row">{slot.slot_id}</th><td>{price(slot.buy_level)} / {price(slot.sell_level)}</td><td>{money(slot.budget)}</td><td>{integers.format(slot.quantity_per_cycle)}</td><td>{integers.format(slot.held_quantity)}</td><td>{slot.entry_price === null ? 'No position' : price(slot.entry_price)}</td><td>{money(slot.entry_fee)}</td><td>{slot.completed_cycles}</td><td>{slot.pending ? words(slot.pending) : 'None'}</td></tr>)}</tbody></table></div></section>

    <section className="grid-journal" aria-labelledby="grid-journal-title"><h4 id="grid-journal-title">Replay journal</h4><details className="grid-disclosure"><summary>View latest {latestEvents.length} of {integers.format(result.journal.length)} events · newest first</summary>{latestEvents.length ? <ol>{latestEvents.map(event => <li key={event.event_id}><div><strong>{words(event.kind)}</strong><time>{event.session_date}</time></div><p>{EVENT_REASONS[event.reason] ?? words(event.reason)}</p><dl><dt>Slot</dt><dd>{event.slot_id ?? 'Portfolio'}</dd><dt>Share change</dt><dd>{integers.format(event.quantity_delta)}</dd><dt>Price</dt><dd>{event.price === null ? 'Not applicable' : price(event.price)}</dd><dt>Cash change</dt><dd>{money(event.cash_delta)}</dd><dt>Fee</dt><dd>{money(event.fee)}</dd></dl><small>{event.at}</small></li>)}</ol> : <p>No events were recorded for this replay.</p>}</details><p className="grid-fine">The frozen export contains the complete journal and every equity observation.</p></section>

    <section className="grid-provenance" aria-labelledby="grid-provenance-title"><h4 id="grid-provenance-title">Source, dates, and limitations</h4><dl><dt>Source</dt><dd>{configuration.source_evidence.source}</dd><dt>Period</dt><dd>{result.equity[0]?.session_date} through {result.equity.at(-1)?.session_date}</dd><dt>Observation cutoff</dt><dd>{configuration.as_of}</dd><dt>Declared configuration cutoff</dt><dd>{configuration.configured_at}</dd><dt>Calendar</dt><dd>{configuration.source_evidence.calendar_source}</dd><dt>Adjustment</dt><dd>{words(configuration.source_evidence.adjustment)}</dd><dt>Coverage</dt><dd>User asserts completeness; not independently verified</dd><dt>Availability</dt><dd>Declared point in time</dd><dt>License scope</dt><dd>{configuration.source_evidence.license_scope}</dd><dt>Fill model</dt><dd>Daily close signal → next open limit approximation</dd></dl><ul>{result.limitations.map((limitation, index) => <li key={`${index}-${limitation}`}>{limitation}</li>)}</ul><details className="grid-disclosure"><summary>Frozen identifiers and grid levels</summary><dl><dt>Run ID</dt><dd><code>{result.run_id}</code></dd><dt>Configuration hash</dt><dd><code>{result.configuration_hash}</code></dd><dt>Declared dataset SHA-256</dt><dd><code>{configuration.source_evidence.dataset_sha256}</code></dd><dt>Canonical bars SHA-256</dt><dd><code>{result.canonical_bars_sha256}</code></dd><dt>Frozen levels · USD</dt><dd className="grid-levels">{result.levels.join(' · ')}</dd></dl></details></section>
  </section>;
}

function EquityChart({ result }: { result: GridResult }) {
  // Coordinate mapping only. Every equity observation and benchmark is supplied by Rust.
  const values = result.equity.map(point => Number(point.equity));
  const cash = Number(result.benchmarks.cash_ending_equity);
  const min = Math.min(cash, ...values);
  const max = Math.max(cash, ...values);
  const spread = max - min || 1;
  const y = (value: number) => 22 + ((max - value) / spread) * 172;
  const x = (index: number) => 80 + (index / Math.max(values.length - 1, 1)) * 552;
  const path = values.map((value, index) => `${index ? 'L' : 'M'}${x(index).toFixed(2)},${y(value).toFixed(2)}`).join(' ');
  const end = result.equity.at(-1)!;
  return <figure className="grid-equity-chart"><figcaption><strong>Marked portfolio equity</strong><span><i/>Grid replay <i className="grid-cash-key"/>Cash</span></figcaption><div className="grid-chart-frame"><div className="grid-chart-axis" aria-hidden="true"><span>{dollars.format(max)}</span><span>{dollars.format(min)}</span></div><svg viewBox="72 14 568 188" role="img" aria-labelledby="grid-equity-chart-title grid-equity-chart-description"><title id="grid-equity-chart-title">Historical marked portfolio equity</title><desc id="grid-equity-chart-description">Engine-reported portfolio equity from {result.equity[0].session_date} to {end.session_date}. Ending equity {money(result.metrics.ending_equity)}, total return {pct(result.metrics.total_return)}, maximum drawdown {pct(result.metrics.max_drawdown)}. Includes remaining inventory; this is a historical approximation.</desc><line x1="80" x2="632" y1="22" y2="22" className="grid-chart-rule"/><line x1="80" x2="632" y1="194" y2="194" className="grid-chart-rule"/><line x1="80" x2="632" y1={y(cash)} y2={y(cash)} className="grid-chart-cash"/><path d={path} className="grid-chart-equity"/>{values.length === 1 && <circle cx={x(0)} cy={y(values[0])} r="3" className="grid-chart-point"/>}</svg><div className="grid-chart-dates"><span>{result.equity[0].session_date}</span><span>{end.session_date}</span></div></div></figure>;
}
