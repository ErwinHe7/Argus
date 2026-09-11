'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { ArrowDownRight, ArrowRight, ArrowUpRight, Bookmark, Check, ChevronDown, Clock3, Download, ExternalLink, FileText, FlaskConical, LineChart, ShieldCheck, Table2, Trash2, X } from 'lucide-react';
import type { IvLabOverview, IvLabSymbol, IvLabConfiguration, IvLabCell, TechnicalPoint } from '@/lib/iv-lab/types';
import { IV_EVIDENCE, SYMBOL_NAMES } from '@/lib/iv-lab/evidence';
import { NOTEBOOK_KEY, downloadResearch, parseNotebook, type ResearchNote } from '@/lib/iv-lab/notebook';
import styles from './IvLab.module.css';

// THESIS: Extend Leo's technical research with an inspectable price × IV experiment.
// OWN-WORLD: Existing aubergine research surface, candle gold selection, lilac evidence, sage/coral P&L.
// STORY: Choose a real observed asset, change a stated assumption, inspect a calculated outcome, save the thesis.
// FIRST VIEWPORT: Six-name watchlist at left; selected asset, assumptions and a selectable P&L matrix at right.
// FORM: Narrow functional extension of Market Map. No new identity, promotional claims or invented forecasts.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

type Tab = 'scenario' | 'technical' | 'contracts' | 'notes';
const TABS: { id: Tab; label: string; icon: typeof LineChart }[] = [
  { id: 'scenario', label: 'Scenarios', icon: FlaskConical },
  { id: 'technical', label: 'Charts', icon: LineChart },
  { id: 'contracts', label: 'Contracts', icon: Table2 },
  { id: 'notes', label: 'Notes', icon: Bookmark },
];
const number = (value: number | null | undefined, digits = 2) => value == null ? '—' : value.toLocaleString('en-US', { minimumFractionDigits: digits, maximumFractionDigits: digits });
const dollars = (value: number | null | undefined) => value == null ? '—' : value.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 2 });
const signed = (value: number | null | undefined, digits = 1, suffix = '%') => value == null ? '—' : `${value > 0 ? '+' : ''}${number(value, digits)}${suffix}`;
const fractionPercent = (value: number | null | undefined, digits = 1) => value == null ? '—' : value.toLocaleString('en-US', { style: 'percent', minimumFractionDigits: digits, maximumFractionDigits: digits });
const dateTime = (value: string) => new Date(value).toLocaleString('en-US', { timeZone: 'America/New_York', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false });
const path = (points: { x: number; y: number }[]) => points.map((point, index) => `${index ? 'L' : 'M'}${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(' ');
const cellTone = (cell: IvLabCell) => cell.status !== 'valid' ? 'invalid' : cell.pnlPercent! >= 100 ? 'big-gain' : cell.pnlPercent! > .05 ? 'gain' : cell.pnlPercent! <= -70 ? 'big-loss' : cell.pnlPercent! < -.05 ? 'loss' : 'flat';

export function IvLab({ overview, dataBaseUrl, embedded = false, initialSymbol, renderMarketChart }: { overview: IvLabOverview; dataBaseUrl?: string; embedded?: boolean; initialSymbol?: string; renderMarketChart?: (symbol:string)=>ReactNode }) {
  const Workspace = embedded ? 'div' : 'main';
  const [symbol, setSymbol] = useState(overview.symbols.some(item => item.symbol === initialSymbol) ? initialSymbol! : overview.defaults.symbol);
  const [tab, setTab] = useState<Tab>('scenario');
  const [detail, setDetail] = useState<IvLabSymbol | null>(null);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [tenor, setTenor] = useState(overview.defaults.tenorDays);
  const [right, setRight] = useState<'call' | 'put'>(overview.defaults.right);
  const [strikeOffset, setStrikeOffset] = useState(overview.defaults.strikeOffsetPercent);
  const [elapsed, setElapsed] = useState(overview.defaults.elapsedDays);
  const [spotMove, setSpotMove] = useState(10);
  const [ivShift, setIvShift] = useState(10);
  const [notes, setNotes] = useState<ResearchNote[]>([]);
  const [editor, setEditor] = useState(false);
  const [thesis, setThesis] = useState('');
  const [invalidate, setInvalidate] = useState('');
  const [status, setStatus] = useState('');
  const [storageError, setStorageError] = useState('');
  const cache = useRef(new Map<string, IvLabSymbol>());
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const editorRef = useRef<HTMLDivElement>(null);
  const active = overview.symbols.find((item) => item.symbol === symbol) ?? overview.symbols[0]!;
  const context = IV_EVIDENCE[symbol]!;
  const configuration = detail?.configurations.find((item) => item.tenorDays === tenor && item.right === right && item.strikeOffsetPercent === strikeOffset);
  const scenario = configuration?.scenarios.find((item) => item.elapsedDays === elapsed);
  const selectedCell = scenario?.cells.find((item) => item.spotMovePercent === spotMove && item.ivShiftPp === ivShift);
  const technical = active.technical.latest;

  useEffect(() => {
    try { setNotes(parseNotebook(localStorage.getItem(NOTEBOOK_KEY))); }
    catch { setStorageError('Browser storage is unavailable. Export scenarios to keep a copy.'); }
  }, []);

  useEffect(() => {
    const cached = cache.current.get(symbol);
    setDetail(cached ?? null); setError(''); setEditor(false);
    if (cached && reload === 0) return;
    const controller = new AbortController();
    fetch(dataBaseUrl ? `${dataBaseUrl}/${encodeURIComponent(symbol)}.json` : `/api/quant/research/iv-lab?symbol=${encodeURIComponent(symbol)}`, { signal: controller.signal, cache: 'no-store' })
      .then(async (response) => {
        if (!response.ok) throw new Error('The market snapshot could not be loaded. Try again.');
        const data = await response.json() as { symbol: IvLabSymbol };
        if (data.symbol?.symbol !== symbol || !data.symbol.configurations?.length) throw new Error('The data does not match the selected symbol. Please reload.');
        if (!controller.signal.aborted) { cache.current.set(symbol, data.symbol); setDetail(data.symbol); }
      })
      .catch((reason: unknown) => { if (!controller.signal.aborted) setError(reason instanceof Error ? reason.message : 'Data could not be loaded.'); });
    return () => controller.abort();
  }, [symbol, reload, dataBaseUrl]);

  const openEditor = () => {
    setThesis(`I am testing ${symbol} after ${elapsed} days: a ${signed(spotMove, 0)} stock-price move and a ${signed(ivShift, 0, ' pp')} IV change.`);
    setInvalidate(''); setEditor(true); setStatus('');
    window.setTimeout(() => editorRef.current?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'center' }), 20);
  };
  const persist = (next: ResearchNote[]) => {
    try { localStorage.setItem(NOTEBOOK_KEY, JSON.stringify(next)); setNotes(next); setStorageError(''); return true; }
    catch { setStorageError('Note not saved: browser storage is unavailable or full. Export a copy.'); return false; }
  };
  const save = () => {
    if (!configuration || !selectedCell || !thesis.trim()) return;
    const note: ResearchNote = {
      id: crypto.randomUUID(), savedAt: new Date().toISOString(), symbol,
      artifactGeneratedAt: overview.generatedAt, configurationId: configuration.id, elapsedDays: elapsed,
      spotMovePercent: spotMove, ivShiftPp: ivShift, thesis: thesis.trim(), invalidate: invalidate.trim(),
      result: `Theoretical ${right === 'call' ? 'Call' : 'Put'}, initially ${tenor} days to expiry, strike ${dollars(configuration.strike)}; scenario P&L ${signed(selectedCell.pnlPercent)}, or ${dollars(selectedCell.pnl)} per share. Conditional valuation, not a trade record.`,
    };
    if (persist([note, ...notes].slice(0, 100))) { setEditor(false); setTab('notes'); setStatus('Saved in this browser. Export a copy to view on another device.'); }
  };
  const exportSelection = () => {
    if (!configuration || !selectedCell) return;
    downloadResearch(`astra-${symbol}-option-scenario.json`, {
      kind: 'conditional_research_not_execution', exportedAt: new Date().toISOString(),
      artifactGeneratedAt: overview.generatedAt, inputSha256: overview.inputSha256, symbol,
      market: active.market, ivAssumption: active.ivAssumption, configuration: { ...configuration, scenarios: undefined },
      scenario: selectedCell, elapsedDays: elapsed, methodology: overview.methodology, thesis, invalidate,
      evidence: IV_EVIDENCE[symbol],
    });
  };
  const restore = (note: ResearchNote) => {
    const [days, side, offset] = note.configurationId.split(':');
    if (!overview.symbols.some((item) => item.symbol === note.symbol) || !overview.axes.tenorDays.includes(Number(days)) || !overview.axes.strikeOffsetPercent.includes(Number(offset)) || !overview.axes.elapsedDays.includes(note.elapsedDays) || !overview.axes.spotMovePercent.includes(note.spotMovePercent) || !overview.axes.ivShiftPp.includes(note.ivShiftPp) || (side !== 'call' && side !== 'put')) {
      setStatus('This saved scenario is unavailable in the current model. Export the note to review it.'); return;
    }
    setSymbol(note.symbol); setTenor(Number(days)); setRight(side); setStrikeOffset(Number(offset));
    setElapsed(note.elapsedDays); setSpotMove(note.spotMovePercent); setIvShift(note.ivShiftPp); setTab('scenario'); setEditor(false);
    setStatus(note.artifactGeneratedAt === overview.generatedAt ? 'Saved scenario parameters restored.' : `Loaded the current snapshot. This note used data version ${note.artifactGeneratedAt}; results may differ.`);
  };

  return <div className={`${styles.page}${embedded ? ` ${styles.embedded}` : ''}`} data-design-contract="leo-market-map-extension-iv-v1" lang="en">
    <a className={styles.skip} href="#iv-workspace">Skip to Options lab</a>
    {!embedded && <header className={styles.header}>
      <Link href="/" className={styles.brand}><Image src="/brand/leo-lion.png" alt="" width={33} height={33} /><span>Astra's Pick</span><small>Options lab</small></Link>
      <nav aria-label="Analysis navigation"><Link href="/discover/market-map">Market map <ArrowUpRight size={13} /></Link><a href="#iv-method">Data & methods</a><Link href="/app/">Leo app <ArrowUpRight size={13} /></Link></nav>
    </header>}
    <Workspace className={styles.main} id="iv-workspace">
      <div className={styles.heading}>{!embedded && <div><h1>Test an option scenario.</h1><p>Inspect the chart, set your assumptions, and compare the effect of price, IV, and time.</p></div>}
        <div className={styles.snapshot}><strong><Clock3 size={14} /> {active.market.dailyBarLastDate.slice(5).replace('-', ' / ')} market snapshot</strong><span>{active.market.dailyBarLastDate.slice(0, 4)} · Archived data</span><span>Historical, not live</span></div>
      </div>
      <div className={styles.workspace}>
        <aside className={styles.sidebar} aria-label="Anthropic-related symbols">
          <div className={styles.sideHeading}><h2>Anthropic watchlist</h2><span>{overview.symbols.length} symbols</span></div>
          <div className={styles.watchHeader}><span>Symbol</span><span>Composite IV / percentile</span></div>
          <div className={styles.watchlist}>{overview.symbols.map((item) => <button key={item.symbol} className={styles.watchRow} aria-pressed={symbol === item.symbol} onClick={() => { setSymbol(item.symbol); setStatus(''); }} aria-label={`Analyze ${item.symbol}, composite IV ${fractionPercent(item.ivAssumption.annualIv)}`}>
            <span className={styles.watchSymbol}>{item.symbol}{symbol === item.symbol && <ArrowRight size={12} />}</span><span className={styles.watchIv}>{fractionPercent(item.ivAssumption.annualIv)}</span>
            <span className={styles.watchName}>{SYMBOL_NAMES[item.symbol]}</span><span className={styles.watchRank}>Percentile {number(item.ivAssumption.ivPercentilePercent, 1)}%</span>
          </button>)}</div>
          <p className={styles.sideNote}>Percentile compares IV with its own 52-week history, not the chance of a rise. Composite IV has no independent timestamp.</p>
          <div className={styles.eventMini}><h3><FileText size={14} /> Catalyst dates</h3><p>The September 1 release is complete. The IPO listing and next model release dates are unconfirmed.</p><a href="https://www.anthropic.com/news" target="_blank" rel="noreferrer">Verify with issuer <ExternalLink size={11} /></a></div>
          <button className={styles.noteShortcut} onClick={() => setTab('notes')}><span><Bookmark size={14} /> My notes</span><span>{notes.length}</span></button>
        </aside>
        <section className={styles.content} aria-label={`${symbol} option analysis`}>
          <div className={styles.instrument}>
            <div className={styles.instrumentName}><h2>{symbol}</h2><p>{SYMBOL_NAMES[symbol]} · {context.relationship}</p></div>
            <div className={styles.instrumentPrice}><strong>{dollars(active.market.spot)}</strong><small>Last trade reference · {dateTime(active.market.observedAt)} ET</small></div>
            <div className={styles.instrumentMetrics}>
              <div className={styles.metric}><span>Composite annual IV</span><strong>{fractionPercent(active.ivAssumption.annualIv)}</strong><small>Underlying metric, not contract IV</small></div>
              <div className={styles.metric}><span>52-week IV percentile</span><strong>{number(active.ivAssumption.ivPercentilePercent, 1)}%</strong><small>Relative to its own history</small></div>
              <div className={styles.metric}><span>RSI 14</span><strong>{number(technical.rsi14, 1)}</strong><small>{technical.date} daily bars</small></div>
            </div>
          </div>
          <div className={styles.tabs} role="tablist" aria-label="Analysis views">{TABS.map((item, index) => <button key={item.id} ref={(node) => { tabRefs.current[index] = node; }} id={`iv-tab-${item.id}`} role="tab" aria-selected={tab === item.id} aria-controls={`iv-panel-${item.id}`} tabIndex={tab === item.id ? 0 : -1} onClick={() => { setTab(item.id); setEditor(false); }} onKeyDown={(event) => {
            if (!['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(event.key)) return;
            event.preventDefault(); const next = event.key === 'Home' ? 0 : event.key === 'End' ? TABS.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + TABS.length) % TABS.length;
            setTab(TABS[next]!.id); tabRefs.current[next]?.focus();
          }}><item.icon size={15} />{item.label}{item.id === 'notes' && notes.length > 0 && ` ${notes.length}`}</button>)}</div>
          {storageError && <div className={styles.error} role="alert">{storageError}</div>}
          {status && <div className={styles.status} role="status">{status}</div>}
          <div className={styles.tabBody} role="tabpanel" id={`iv-panel-${tab}`} aria-labelledby={`iv-tab-${tab}`}>
            {tab === 'scenario' && <>
              <div className={styles.panelIntro}><div><h3>Compare option outcomes</h3><p>Set the option and elapsed time, then select a price and IV combination. P&L is conditional on those assumptions.</p></div><span className={styles.pill}><FlaskConical size={11} /> Hypothetical option</span></div>
              {error ? <div className={styles.error} role="alert"><span>{error}</span><button onClick={() => setReload((value) => value + 1)}>Reload</button></div> : !configuration || !scenario || !selectedCell ? <div className={styles.loading} aria-busy="true"><p>Loading {symbol} scenarios…</p><div /><div /></div> : <>
                <div className={styles.assumptions}>
                  <div className={styles.controls}>
                    <div className={styles.controlField}><span className={styles.controlLabel}>Option type</span><div className={styles.segmented} role="group" aria-label="Option type"><button aria-pressed={right === 'call'} onClick={() => setRight('call')}>Call</button><button aria-pressed={right === 'put'} onClick={() => setRight('put')}>Put</button></div></div>
                    <label><span>Initial time to expiry</span><select aria-label="Initial time to expiry" value={tenor} onChange={(event) => setTenor(Number(event.target.value))}>{overview.axes.tenorDays.map((value) => <option key={value} value={value}>{value} calendar days</option>)}</select></label>
                    <label><span>Strike vs. stock price</span><select aria-label="Strike vs. stock price" value={strikeOffset} onChange={(event) => setStrikeOffset(Number(event.target.value))}>{overview.axes.strikeOffsetPercent.map((value) => <option key={value} value={value}>{value === 0 ? 'At the money' : `${signed(value, 0)} vs. stock price`}</option>)}</select></label>
                    <label><span>Elapsed time</span><select aria-label="Elapsed time" value={elapsed} onChange={(event) => setElapsed(Number(event.target.value))}>{overview.axes.elapsedDays.map((value) => <option key={value} value={value}>{value === 0 ? 'Immediate' : `After ${value} days`}</option>)}</select></label>
                  </div>
                  <div className={styles.assumptionFooter}><span>Strike <b>{dollars(configuration.strike)}</b></span><span>Starting IV assumption <b>{fractionPercent(active.ivAssumption.annualIv)}</b></span><span>Assumed interest rate <b>{fractionPercent(overview.methodology.rateAnnual)}</b></span><span>Assumed dividend yield <b>{fractionPercent(overview.methodology.dividendYieldAnnual, 0)}</b></span></div>
                </div>
                <div className={styles.scenarioLayout}>
                  <div>
                    <div className={styles.matrixHeader}><strong>{elapsed === 0 ? 'Immediate' : `After ${elapsed} days`} · theoretical P&L</strong><span>Stock-price change →</span></div>
                    <div className={styles.matrixWrap}><table className={styles.matrix} aria-label="Theoretical option P&L by stock-price change and IV change"><thead><tr><th scope="col">IV change<br />(pp)</th>{overview.axes.spotMovePercent.map((move) => <th scope="col" key={move}>{signed(move, 0)}</th>)}</tr></thead>
                      <tbody>{[...overview.axes.ivShiftPp].reverse().map((shift) => <tr key={shift}><th scope="row">{signed(shift, 0, '')}</th>{overview.axes.spotMovePercent.map((move) => {
                        const cell = scenario.cells.find((item) => item.spotMovePercent === move && item.ivShiftPp === shift)!;
                        return <td key={move}><button className={styles.cell} data-tone={cellTone(cell)} aria-pressed={spotMove === move && ivShift === shift} disabled={cell.status !== 'valid'} aria-label={`Stock ${signed(move, 0)}, IV ${signed(shift, 0, ' percentage points')}, ${cell.status === 'valid' ? `theoretical P&L ${signed(cell.pnlPercent)}` : 'invalid IV assumption'}`} onClick={() => { setSpotMove(move); setIvShift(shift); }}>{cell.status === 'valid' ? signed(cell.pnlPercent, 0) : '—'}</button></td>;
                      })}</tr>)}</tbody>
                    </table></div>
                    <div className={styles.matrixLegend}><span>Loss</span><span className={styles.legendScale}><i style={{ background: '#60323b' }} /><i style={{ background: '#472b30' }} /><i style={{ background: '#2b2233' }} /><i style={{ background: '#213d32' }} /><i style={{ background: '#335748' }} /></span><span>Gain</span></div>
                    <p className={styles.matrixHint}>P&L is relative to the initial theoretical premium, before spreads, fees, and slippage. Starting IV is an underlying composite assumption, not a contract quote. IV changes use percentage points (pp).</p>
                  </div>
                  <Outcome cell={selectedCell} configuration={configuration} elapsed={elapsed} onSave={openEditor} />
                </div>
                <div className={styles.presetRow}><span>Quick scenarios</span><button onClick={() => { setSpotMove(10); setIvShift(10); }}><ArrowUpRight size={13} /> Stock +10% · IV +10 pp</button><button onClick={() => { setSpotMove(10); setIvShift(-10); }}><ArrowDownRight size={13} /> Stock up · IV down</button><button onClick={() => { setSpotMove(0); setIvShift(0); setElapsed(7); }}><Clock3 size={12} /> No change for 7 days</button></div>
                <dl className={styles.greeks}><div><dt>Delta</dt><dd>{number(configuration.baseline.delta, 3)}</dd><small>Local sensitivity to a $1 stock move</small></div><div><dt>Vega</dt><dd>{dollars(configuration.baseline.vegaPerPp)}</dd><small>Per +1 IV percentage point, per share</small></div><div><dt>Theta</dt><dd>{dollars(configuration.baseline.thetaPerDay)}</dd><small>Per elapsed calendar day, per share</small></div><div><dt>Gamma</dt><dd>{number(configuration.baseline.gamma, 4)}</dd><small>Delta sensitivity to the stock price</small></div></dl>
              </>}
            </>}
            {tab === 'technical' && <>
              {renderMarketChart ? <>{renderMarketChart(symbol)}<details className="market-archive"><summary><ChevronDown size={15}/>Recorded model-input chart<span>Through {active.market.dailyBarLastDate}</span></summary><TechnicalChart points={active.technical.series} symbol={symbol}/></details><p className={styles.caveat}>The indicators below and option scenarios use the dated research snapshot. TradingView supplies the displayed market chart.</p></> : <TechnicalChart points={active.technical.series} symbol={symbol} />}
              <div className={styles.indicatorStrip}><div><span>Price vs. 20-day SMA</span><strong>{signed(technical.priceVsSma20Percent)}</strong><small>{technical.trend === 'bullish' ? 'Above the moving average' : technical.trend === 'bearish' ? 'Below the moving average' : 'Near the moving average'}</small></div><div><span>KDJ · 9 / 3 / 3</span><strong>{number(technical.k, 1)} / {number(technical.d, 1)}</strong><small>K / D · J {number(technical.j, 1)}</small></div><div><span>20-day realized volatility</span><strong>{number(technical.realizedVol20Percent, 1)}%</strong><small>Observed close-to-close returns, annualized</small></div><div><span>MACD histogram</span><strong>{number(technical.macdHistogram, 3)}</strong><small>12 / 26 / 9 · not doubled</small></div></div>
              <div className={styles.evidenceGrid}><article><h3>{context.title}</h3><p>{context.mechanism}</p>{overview.events.relationships.filter((item) => item.symbol === symbol).map((item) => <div className={styles.evidenceFact} key={item.symbol}><p>{item.factZh}</p><a href={item.sourceUrl} target="_blank" rel="noreferrer">{item.symbol === 'GOOGL' ? 'CMA filing · 2024-12-24' : `Original source · as of ${item.asOf}`} <ExternalLink size={11} /></a>{item.symbol === 'GOOGL' && <><br /><a href="https://www.anthropic.com/news/google-broadcom-partnership-compute" target="_blank" rel="noreferrer">Compute partnership · 2026-04-06 <ExternalLink size={11} /></a><p className={styles.caveat}>The 2024 filing establishes an equity relationship; current ownership is unverified. The 2026 announcement confirms a compute partnership.</p></>}</div>)}<p className={styles.caveat}>{context.limitation}</p></article>
                <article><h3>Read price and volatility together</h3><p>Charts describe past price behavior. IV reflects expected volatility priced into options; its percentile adds historical context.</p><p className={styles.caveat}>No comparable IV history is available to verify an IV uptrend or measure how often price and IV rose together.</p><p className={styles.caveat}>Indicators use {active.market.coverage.observedSessions} validated observations. Calendar coverage and corporate-action adjustment are unverified. Indicators do not establish forecast probabilities.</p></article></div>
              {active.market.coverage.validationExcludedPrefixSessions > 0 && <div className={styles.quoteNotice}><ShieldCheck size={16} /><span>Invalid source bars were excluded. Indicators use the contiguous valid observations from {active.market.coverage.startDate}; source prices are unchanged.</span></div>}
              <div className={styles.timeline}>{overview.events.events.filter((item) => item.id !== 'glasswing-2026-04-07').map((item) => <div key={item.id}><time>{item.eventDate ?? 'Unconfirmed'}</time><div><strong className={item.eventDate ? undefined : styles.unknown}>{item.titleZh}</strong><p>{item.factsZh}</p><a href={item.sourceUrl} target="_blank" rel="noreferrer">Official source <ExternalLink size={10} /></a></div></div>)}</div>
            </>}
            {tab === 'contracts' && <>
              <div className={styles.panelIntro}><div><h3>{symbol} contract snapshots</h3><p>IBKR contract quotes are separate from the hypothetical Scenarios. Last-trade times do not date bid, ask, or IV.</p></div><span className={styles.pill}><Clock3 size={11} /> Historical reference</span></div>
              {active.optionEvidence.length ? <><div className={styles.contractTableWrap}><table className={styles.contractTable}><thead><tr><th>Expiry / type</th><th>Strike</th><th>Bid</th><th>Ask</th><th>Contract IV</th><th>Open interest</th></tr></thead><tbody>{active.optionEvidence.map((quote) => <tr key={`${quote.expirationDate}:${quote.side}:${quote.strike}`}><td>{quote.expirationDate}<br />{quote.side === 'call' ? 'Call' : 'Put'}</td><td>{dollars(quote.strike)}</td><td>{dollars(quote.bid)}</td><td>{dollars(quote.ask)}</td><td>{fractionPercent(quote.ivAnnual, 2)}</td><td>{number(quote.openInterest, 0)}</td></tr>)}</tbody></table></div><p className={styles.contractNote}>IBKR · collected 2026-09-06 · last trades 2026-09-04. Bid, ask, IV, and open interest have no independent timestamps; current spreads and execution availability are unverified. Exact expiry times and contract multipliers are unavailable.</p></> : <div className={styles.empty}><Table2 size={28} /><h3>No {symbol} contracts imported yet</h3><p>Use Scenarios with composite IV assumptions. Listed expiries, strikes, and bid/ask quotes are unavailable for this symbol.</p><button className={styles.primary} onClick={() => { setSymbol('AVGO'); setTab('contracts'); }}>View AVGO contracts <ArrowRight size={14} /></button></div>}
              <div className={styles.quoteNotice}><ShieldCheck size={17} /><span>Verify the catalyst date before choosing an expiry. The IPO listing date is unconfirmed.</span></div>
            </>}
            {tab === 'notes' && <>
              <div className={styles.panelIntro}><div><h3>Keep your reasoning.</h3><p>Save a thesis and revisit its assumptions. Notes stay in this browser and do not record executions or realized gains.</p></div>{notes.length > 0 && <button className={styles.secondary} onClick={() => downloadResearch('leo-iv-notebook.json', { schema: 'leo.iv-notebook.v1', notes })}><Download size={14} /> Export all</button>}</div>
              {notes.length ? <div className={styles.noteList}>{notes.map((note) => <article className={styles.noteCard} key={note.id}><div className={styles.noteMeta}><strong>{note.symbol}</strong><time>{dateTime(note.savedAt)} ET</time></div><p>{note.thesis}</p>{note.invalidate && <p><b>Invalidation: </b>{note.invalidate}</p>}<p className={styles.savedTerms}>{note.result}</p><p className={styles.savedTerms}>Data version: {note.artifactGeneratedAt}</p><div className={styles.noteActions}><button onClick={() => restore(note)}><FlaskConical size={13} /> Revisit scenario</button><button onClick={() => downloadResearch(`leo-${note.symbol}-${note.id.slice(0, 8)}.json`, note)}><Download size={13} /> Export</button><button onClick={() => { if (persist(notes.filter((item) => item.id !== note.id))) setStatus('Note deleted.'); }}><Trash2 size={13} /> Delete</button></div></article>)}</div> : <div className={styles.empty}><Bookmark size={28} /><h3>Save your first scenario</h3><p>Choose a scenario, state your thesis and what would change your view, then save a note.</p><button className={styles.primary} onClick={() => setTab('scenario')}>Explore a scenario <ArrowRight size={14} /></button></div>}
            </>}
          </div>
          {editor && <div className={styles.editor} ref={editorRef}><div className={styles.editorHeading}><h3>Save your {symbol} thesis</h3><button aria-label="Close note editor" onClick={() => setEditor(false)}><X size={18} /></button></div><label>Your thesis<textarea value={thesis} maxLength={2000} onChange={(event) => setThesis(event.target.value)} /></label><label>What would change your view?<textarea value={invalidate} maxLength={2000} onChange={(event) => setInvalidate(event.target.value)} placeholder="For example: price breaks my reference level, or the catalyst falls after expiry." /></label><div className={styles.editorActions}><small>Saves the data version and scenario parameters in this browser</small><div className={styles.noteActions}><button onClick={exportSelection}><Download size={14} /> Export scenario</button><button className={styles.primary} disabled={!thesis.trim()} onClick={save}><Check size={14} /> Save note</button></div></div></div>}
        </section>
      </div>
      <details className={styles.methodology} id="iv-method"><summary>Data, methods & limitations <ChevronDown size={16} /></summary><div className={styles.methodGrid}>
        <div><h3>Observed data and assumed inputs</h3><p>IBKR supplies prices, daily bars, composite IV, percentiles, and available contract quotes. This archived snapshot does not refresh automatically. Last trades may occur after hours; indicators use completed daily bars.</p><p>Composite IV and its percentile have no independent timestamps. Composite IV is a scenario assumption, not contract IV, a term structure, or a volatility skew.</p><p>Scenarios do not estimate outcome probabilities. A low IV percentile alone is not a buy signal.</p><a href="https://www.optionseducation.org/news/the-crush-is-real" target="_blank" rel="noreferrer">OIC: events and IV crush <ExternalLink size={11} /></a></div>
        <div><h3>Quantitative methods</h3><dl><div><dt>Option valuation</dt><dd>European Black–Scholes model. American early exercise, actual dividends, spreads, fees, and slippage are excluded.</dd></div><div><dt>Input assumptions</dt><dd>Risk-free rate {fractionPercent(overview.methodology.rateAnnual)}; dividend yield {fractionPercent(overview.methodology.dividendYieldAnnual, 0)}; calendar days per year: {overview.methodology.optionCalendarDaysPerYear}; assumed multiplier: {overview.methodology.assumedContractMultiplier}. Tenors start at the reference time and do not identify listed contracts.</dd></div><div><dt>P&L attribution</dt><dd>Price, IV, and time are changed separately; the residual is nonlinear interaction. Greeks describe starting sensitivity. Matrix cells use full repricing.</dd></div><div><dt>Data version</dt><dd>{overview.generatedAt}<br />{overview.schemaVersion} · {overview.methodology.modelVersion}</dd></div></dl></div>
      </div></details>
      {!embedded && <footer className={styles.footer}><p>Astra's Pick · Archived market data and conditional option valuations. No automated trading.</p><span>Price × Volatility × Time</span></footer>}
    </Workspace>
  </div>;
}

function Outcome({ cell, configuration, elapsed, onSave }: { cell: IvLabCell; configuration: IvLabConfiguration; elapsed: number; onSave: () => void }) {
  return <aside className={styles.outcome} aria-live="polite" aria-atomic="true">
    <div className={styles.outcomeMain}><h3>Selected scenario · theoretical P&L</h3><div className={styles.outcomeNumber} data-tone={(cell.pnl ?? 0) >= 0 ? 'up' : 'down'}>{signed(cell.pnlPercent)}</div><p>{dollars(cell.pnlPerContract)} / assumed 100-share contract</p><p className={styles.outcomeLabel}>Relative to theoretical premium · before costs</p></div>
    <dl className={styles.scenarioTerms}><div><dt>Stock-price change</dt><dd>{signed(cell.spotMovePercent, 0)}</dd></div><div><dt>IV change</dt><dd>{signed(cell.ivShiftPp, 0, ' pp')}</dd></div><div><dt>Time remaining</dt><dd>{cell.daysRemaining} days</dd></div><div><dt>Initial premium / share</dt><dd>{dollars(configuration.baseline.premium)}</dd></div><div><dt>{elapsed} days later / share</dt><dd>{dollars(cell.price)}</dd></div></dl>
    <div className={styles.attribution}><h4>P&L attribution · USD per share</h4>{[['Price only', cell.priceOnlyPnl], ['IV only', cell.ivOnlyPnl], ['Time only', cell.timeOnlyPnl], ['Nonlinear interaction', cell.interactionPnl]].map(([label, value]) => <div key={String(label)}><span>{label}</span><strong className={typeof value === 'number' && value > 0 ? styles.positive : styles.negative}>{typeof value === 'number' ? `${value > 0 ? '+' : ''}${dollars(value)}` : '—'}</strong></div>)}<small>Components sum to theoretical P&L, not an execution result.</small></div>
    <button className={styles.primary} onClick={onSave} disabled={cell.status !== 'valid'}><Bookmark size={14} /> Save scenario note</button>
  </aside>;
}

function TechnicalChart({ points, symbol }: { points: TechnicalPoint[]; symbol: string }) {
  const bars = points.slice(-80);
  const [inspection, setInspection] = useState<number | null>(null);
  const chartViewportRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    setInspection(null);
    const viewport = chartViewportRef.current;
    if (viewport) viewport.scrollLeft = viewport.scrollWidth;
  }, [symbol]);
  const inspected = bars[Math.min(inspection ?? bars.length - 1, bars.length - 1)]!;
  // Display-only coordinate transforms. All financial series are supplied by Python.
  const width = 860, left = 12, right = 65, top = 14, bottom = 250;
  const values = bars.flatMap((point) => [point.close, point.sma20, point.bollingerLower, point.bollingerUpper].filter((value): value is number => value != null));
  const low = Math.min(...values), high = Math.max(...values), span = high - low || 1;
  const x = (index: number) => left + index / Math.max(1, bars.length - 1) * (width - left - right);
  const y = (price: number) => bottom - (price - low) / span * (bottom - top);
  const series = (key: 'close' | 'sma20' | 'bollingerUpper' | 'bollingerLower') => bars.flatMap((point, index) => point[key] == null ? [] : [{ x: x(index), y: y(point[key]!) }]);
  const upper = series('bollingerUpper'), lower = series('bollingerLower');
  const cloud = upper.length && lower.length ? `${path(upper)} ${path([...lower].reverse()).replace(/^M/, 'L')} Z` : '';
  return <div className={styles.chartSection}>
    <div className={styles.chartTop}><div><h3>{symbol} · Completed daily bars</h3><p>{inspected.date} · Close {dollars(inspected.close)} · RSI {number(inspected.rsi14, 1)}</p></div><div className={styles.chartLegend}><span><i style={{ background: '#ecb667' }} />Close</span><span><i style={{ background: '#d9a4df' }} />SMA20</span><span><i style={{ background: '#776085' }} />Bollinger bands</span></div></div>
    <div className={styles.chartViewport} ref={chartViewportRef} tabIndex={0} role="region" aria-label={`${symbol} technical chart, scroll horizontally`}>
    <svg className={styles.chart} viewBox={`0 0 ${width} 310`} role="img" aria-label={`${symbol} close, 20-day moving average, and Bollinger bands across the latest ${bars.length} validated trading observations`}>
      {[0, .25, .5, .75, 1].map((portion) => { const value = low + span * portion; return <g key={portion}><line x1={left} x2={width - right + 7} y1={y(value)} y2={y(value)} stroke="#382a43" strokeWidth="1" /><text x={width - right + 15} y={y(value) + 4}>{number(value, 1)}</text></g>; })}
      {cloud && <path d={cloud} fill="#d9a4df" fillOpacity=".055" />}
      <path d={path(upper)} stroke="#776085" strokeWidth="1" fill="none" strokeDasharray="4 4" /><path d={path(lower)} stroke="#776085" strokeWidth="1" fill="none" strokeDasharray="4 4" />
      <path d={path(series('sma20'))} stroke="#d9a4df" strokeWidth="1.6" fill="none" /><path d={path(series('close'))} stroke="#ecb667" strokeWidth="2" fill="none" />
      <line x1={x(bars.indexOf(inspected))} x2={x(bars.indexOf(inspected))} y1={top} y2={bottom + 5} stroke="#a892b8" strokeWidth="1" strokeDasharray="3 5" /><circle cx={x(bars.indexOf(inspected))} cy={y(inspected.close)} r="4" fill="#ecb667" stroke="#17101f" strokeWidth="2" />
      {[0, Math.floor((bars.length - 1) / 2), bars.length - 1].map((index) => <text key={index} x={x(index)} y={282} textAnchor={index === 0 ? 'start' : index === bars.length - 1 ? 'end' : 'middle'}>{bars[index]!.date}</text>)}
    </svg>
    </div>
    <label className={styles.chartCaption}><span>Inspect daily history · after-hours reference prices are separate</span><input aria-label="Inspect historical trading day" type="range" min={0} max={bars.length - 1} value={inspection ?? bars.length - 1} onChange={(event) => setInspection(Number(event.target.value))} style={{ accentColor: '#ecb667', minHeight: 32 }} /></label>
  </div>;
}
