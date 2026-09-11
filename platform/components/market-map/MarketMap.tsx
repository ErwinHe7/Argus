'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useId, useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, ArrowUpRight, ChevronDown, Compass, Eye, Layers3, RotateCcw } from 'lucide-react';
import type { MarketMapSnapshot, PublicMarketMapSnapshot } from '@/lib/market-map/types';
import { PUBLIC_MARKET_ASSETS } from '@/lib/market-map/public-catalog';
import styles from './MarketMap.module.css';

// THESIS: One market map connects price structure, conditional simulations, and their evidence.
// OWN-WORLD: Leo's aubergine observatory, candle gold anchors, lilac structure, coral and sage signals.
// STORY: Inspect a completed session, read the range, trace each explanation to the same snapshot.
// FIRST VIEWPORT: A full-width research chart with historical candles and a distinct simulation field.
// FORM: A chart-led research folio; existing Leo identity, reference-directed composition.

type Snapshot = MarketMapSnapshot | PublicMarketMapSnapshot;
type Props = { snapshots: Snapshot[]; illustrative?: boolean; publicData?: boolean; publicSymbols?: string[] };
type LinePoint = { x: number; y: number };
const PALETTE = { gold: '#ecb667', lilac: '#d9a4df', green: '#91c7af', red: '#ef9c98', ink: '#f6ecf7', muted: '#bbaaC3' };
const roleColors: Record<string, string> = { stretch: PALETTE.lilac, resistance: PALETTE.red, last: PALETTE.gold, sma20: PALETTE.lilac, support: PALETTE.green, down: PALETTE.red };
const price = (value: number) => value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const signed = (value: number, suffix = '%') => `${value > 0 ? '+' : ''}${value.toFixed(2)}${suffix}`;
const date = (value: string, timeZone = 'America/New_York') => new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone }).format(new Date(value));
const path = (points: LinePoint[]) => points.map((point, index) => `${index ? 'L' : 'M'}${point.x.toFixed(2)},${point.y.toFixed(2)}`).join(' ');
const compact = (value: number) => Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(value);

export function MarketMap({ snapshots, illustrative = false, publicData = false, publicSymbols }: Props) {
  const router = useRouter();
  const [refreshing, startRefresh] = useTransition();
  const [expired, setExpired] = useState(false);
  const chartRef = useRef<HTMLDivElement>(null);
  const [horizon, setHorizon] = useState(snapshots.find((item) => item.horizon === '20d')?.horizon ?? snapshots[0]!.horizon);
  const [cloud, setCloud] = useState(true);
  const [bands, setBands] = useState(true);
  const [evidence, setEvidence] = useState<string[]>([]);
  const [inspected, setInspected] = useState<number | null>(null);
  const snapshot = snapshots.find((item) => item.horizon === horizon) ?? snapshots[0]!;
  const publicSnapshot = publicData && 'mode' in snapshot && snapshot.mode === 'public_market' ? snapshot : null;
  const hfData = publicSnapshot?.provenance.sources.some((source) => /HF Data Library/i.test(source.provider));
  const adjustmentLabel = publicSnapshot ? publicSnapshot.price_adjustment.replaceAll('_', ' ') : snapshot.provenance.coverage.corporate_actions_adjusted ? 'adjusted' : 'unadjusted';
  const bars = snapshot.bars.slice(-100);
  const activeBar = bars[Math.min(inspected ?? bars.length - 1, bars.length - 1)]!;
  const iv = snapshot.panels.implied_volatility;
  const momentum = snapshot.technical_indicators.momentum;
  const lastMomentum = momentum.points.at(-1)!;
  const highlight = (refs: string[]) => evidence.some((ref) => refs.includes(ref));
  useEffect(() => {
    if (window.matchMedia('(max-width: 700px)').matches && chartRef.current) {
      chartRef.current.scrollLeft = chartRef.current.scrollWidth;
    }
  }, []);
  useEffect(() => {
    if (illustrative) return;
    const checkExpiry = () => {
      const stale = Date.parse(snapshot.provenance.freshness.expires_at) <= Date.now();
      setExpired(stale);
      if (stale) router.refresh();
    };
    checkExpiry();
    const remaining = Date.parse(snapshot.provenance.freshness.expires_at) - Date.now();
    const timer = window.setTimeout(checkExpiry, Math.max(0, remaining));
    document.addEventListener('visibilitychange', checkExpiry);
    window.addEventListener('pageshow', checkExpiry);
    return () => { window.clearTimeout(timer); document.removeEventListener('visibilitychange', checkExpiry); window.removeEventListener('pageshow', checkExpiry); };
  }, [snapshot.snapshot_id, snapshot.provenance.freshness.expires_at, illustrative, router]);
  if (expired && !illustrative) return null;

  return <div className={styles.page}>
    <a className={styles.skip} href="#market-read">Skip to market explanation</a>
    <header className={styles.header}>
      <Link href="/" className={styles.brand}><Image src="/brand/leo-lion.png" alt="" width={34} height={34} /><span>Leo</span></Link>
      <nav aria-label="Research navigation"><Link href="/discover/stocks">Stocks</Link><Link href="/research/iv">IV Lab</Link><Link href="/brokers">Brokers</Link><Link href="/app/">Open app <ArrowUpRight size={14} /></Link></nav>
    </header>

    <main className={styles.main}>
      <div className={styles.breadcrumb}><Link href="/app/#/discover"><ArrowLeft size={14} /> Discover</Link><span>/</span><span>Market Map</span>{!illustrative && <button className={styles.refresh} disabled={refreshing} onClick={() => startRefresh(() => router.refresh())}><RotateCcw size={13} />{refreshing ? 'Refreshing…' : 'Refresh snapshot'}</button>}</div>
      {illustrative && <aside className={styles.exampleNotice}><Eye size={17} /><div><strong>Illustrative research example</strong><span>Every market input on this page is synthetic. The indicators and simulation are calculated from those inputs; this is a feature preview, not a current market assessment.</span></div></aside>}
      {publicData && <aside className={styles.marketNotice}><div><strong>U.S. stocks & ETFs · real daily market records</strong><span>Completed sessions in USD. Indicators, simulations and The Read use the same observed prices and volume.{hfData && ' Source: IEX trades via HF Data Library; volume covers IEX only.'}</span></div><nav aria-label="Choose U.S. market">{PUBLIC_MARKET_ASSETS.filter((asset) => !publicSymbols || publicSymbols.includes(asset.symbol)).map((asset) => <Link key={asset.symbol} href={`/discover/market-map?symbol=${asset.symbol}`} aria-current={snapshot.asset.symbol === asset.symbol ? 'page' : undefined}>{asset.symbol} · {asset.label}</Link>)}</nav></aside>}

      <section className={styles.titleRow} aria-labelledby="map-title">
        <div><h1 id="map-title">Market Map<span className={styles.titleDot}>.</span></h1><p>Read the structure. Follow the evidence.</p></div>
        <div className={styles.snapshotDate}><span>{illustrative ? 'EXAMPLE SESSION' : 'COMPLETED SESSION'}</span><strong>{new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: snapshot.asset.market_timezone }).format(new Date(snapshot.provenance.observation_cutoff))}</strong><small>Daily bars · {snapshot.asset.currency} · {snapshot.asset.exchange}</small></div>
      </section>

      <article className={styles.folio} aria-label={`${snapshot.asset.symbol} market structure and simulation`}>
        <div className={styles.assetRow}>
          <div className={styles.asset}><span className={styles.symbol}>{snapshot.asset.symbol}</span><span>{snapshot.asset.name}</span></div>
          <div className={styles.price}><strong>{price(snapshot.last_price)}</strong><span>Last close</span></div>
          <div className={styles.structure} data-tone={snapshot.state}><span>PRICE STRUCTURE</span><strong>{snapshot.state === 'bull' ? 'Constructive' : snapshot.state === 'bear' ? 'Under pressure' : 'Range-bound'}</strong></div>
          <div className={styles.horizons} role="group" aria-label="Simulation horizon">{[...snapshots].sort((a,b) => a.monte_carlo.horizon_sessions-b.monte_carlo.horizon_sessions).map((item) => <button key={item.horizon} aria-pressed={snapshot.horizon === item.horizon} onClick={() => { setHorizon(item.horizon); setEvidence([]); }}>{item.horizon.replace('d', 'D')}</button>)}</div>
        </div>

        <div className={styles.chartTools}>
          <div className={styles.legend}><span><i style={{ background: PALETTE.gold }} /> Last close</span><span><i style={{ background: PALETTE.lilac }} /> SMA 20</span><span><i style={{ background: PALETTE.green }} /> Support</span><span><i style={{ background: PALETTE.red }} /> Resistance</span></div>
          <div className={styles.toggles}><button aria-pressed={bands} onClick={() => setBands(!bands)}><Layers3 size={14} /> Bollinger bands</button><button aria-pressed={cloud} onClick={() => setCloud(!cloud)}><Compass size={14} /> Simulation cloud</button></div>
        </div>

        <div className={styles.mobileChartViews} aria-label="Chart view"><button onClick={() => chartRef.current?.scrollTo({left: 0})}>Price history</button><button onClick={() => chartRef.current?.scrollTo({left: chartRef.current.scrollWidth})}>Scenario cloud <ArrowUpRight size={12} /></button></div>
        <div ref={chartRef} className={styles.chartScroll} tabIndex={0} role="region" aria-label="Price chart. Scroll horizontally on small screens.">
          <PriceChart snapshot={snapshot} bars={bars} bands={bands} cloud={cloud} evidence={evidence} inspected={inspected} onInspect={setInspected} />
        </div>
        <div className={styles.inspector}><span className={styles.inspectorDate}>{date(activeBar.observed_at, snapshot.asset.market_timezone)}</span><span>O <b>{price(activeBar.open)}</b></span><span>H <b>{price(activeBar.high)}</b></span><span>L <b>{price(activeBar.low)}</b></span><span>C <b>{price(activeBar.close)}</b></span><label>Inspect session<input aria-label="Inspect historical session" type="range" min={0} max={bars.length - 1} value={inspected ?? bars.length - 1} onChange={(event) => setInspected(Number(event.target.value))} /></label><button onClick={() => setInspected(null)} aria-label="Return to latest session"><RotateCcw size={15} /></button></div>
        <p className={styles.chartCaption}>Solid marks are historical observations. Dashed curves and particles are conditional simulations over {snapshot.monte_carlo.horizon_sessions} trading sessions. Swipe the chart to explore on mobile.</p>

        <div className={styles.panels}>
          <section className={styles.panel} data-highlighted={highlight(snapshot.panels.volume.evidence_refs)} id="evidence-volume"><div className={styles.panelHeading}><h2>Volume</h2><strong>{compact(snapshot.panels.volume.latest_volume)}</strong></div><p>{snapshot.panels.volume.relative_volume.toFixed(2)}× the {snapshot.panels.volume.average_window_sessions}-session average</p><MiniChart kind="bars" values={snapshot.panels.volume.series.slice(-70).map((point) => point.volume)} color={PALETTE.gold} label="Daily trading volume" /></section>
          <section className={styles.panel} data-highlighted={evidence.some((ref) => ref.includes('rsi'))} id="evidence-rsi"><div className={styles.panelHeading}><h2>RSI <span>14</span></h2><strong>{snapshot.technical_indicators.rsi14.latest.toFixed(1)}</strong></div><p>Wilder smoothing · 30 / 70 reference levels</p><MiniChart values={snapshot.technical_indicators.rsi14.points.slice(-70).map((point) => point.value)} color={PALETTE.lilac} range={[0, 100]} guides={[30, 70]} label="Relative strength index with 30 and 70 reference levels" /></section>
          <section className={styles.panel} data-highlighted={evidence.some((ref) => ref.includes('momentum'))} id="evidence-momentum"><div className={styles.panelHeading}><h2>Momentum</h2><strong className={['knife', 'falling'].includes(momentum.state) ? styles.negative : styles.positive}>{momentum.state}</strong></div><p>{signed(lastMomentum.velocity_percent_per_session, '% / session')} velocity</p><MiniChart values={momentum.points.slice(-70).map((point) => point.value)} secondary={momentum.points.slice(-70).map((point) => point.signal)} guides={[0]} color={PALETTE.red} label="Momentum and its signal line" /></section>
          {iv ? <section className={styles.panel} data-highlighted={highlight(iv.evidence_refs)} id="evidence-iv"><div className={styles.panelHeading}><h2>ATM IV <span>{iv.tenor_days}D</span></h2><strong>{iv.current_percent.toFixed(1)}%</strong></div><p>{signed(iv.change_5d_percentage_points, ' pp')} over five sessions</p><MiniChart values={iv.series.map((point) => point.percent)} color={PALETTE.lilac} label="Historical at the money implied volatility" /></section> : <section className={styles.panel} data-highlighted={evidence.some((ref) => ref.includes('atr'))} id="evidence-atr"><div className={styles.panelHeading}><h2>ATR <span>14</span></h2><strong>{snapshot.technical_indicators.atr14.latest.toFixed(2)}</strong></div><p>Average true range · {snapshot.asset.currency}</p><MiniChart values={snapshot.technical_indicators.atr14.points.slice(-70).map((point) => point.value)} color={PALETTE.lilac} label="Historical average true range in price units" /><p>Options IV is not supplied by this daily feed.</p></section>}
        </div>

        <section className={styles.sectorStrip} data-highlighted={highlight(snapshot.panels.sector.evidence_refs)}><span>{snapshot.panels.sector.sector_name} <b>{snapshot.panels.sector.benchmark_symbol}</b></span><span>5D benchmark <strong>{signed(snapshot.panels.sector.return_5d_percent)}</strong></span><span>Relative performance <strong>{signed(snapshot.panels.sector.asset_relative_5d_percent, ' pp')}</strong></span><span>{snapshot.panels.sector.state} backdrop</span></section>
      </article>

      <div className={styles.readGrid}>
        <section className={styles.ledger} aria-labelledby="ledger-title"><div className={styles.sectionTitle}><h2 id="ledger-title">Level ledger</h2><span>Same levels. Every view.</span></div><table><caption className={styles.srOnly}>Key prices and distances from the last close</caption><thead><tr><th scope="col">Level</th><th scope="col">Price</th><th scope="col">From close</th></tr></thead><tbody>{snapshot.levels.map((level) => <tr key={level.id} data-active={highlight(level.evidence_refs)}><th scope="row"><button onClick={() => setEvidence(highlight(level.evidence_refs) ? [] : level.evidence_refs)} aria-pressed={highlight(level.evidence_refs)}><i style={{ background: roleColors[level.role] }} />{level.label}</button></th><td>{price(level.price)}</td><td>{signed(level.distance_from_last_percent)}</td></tr>)}</tbody></table><p>Levels describe price structure. They are not estimates of intrinsic value or trade instructions.</p></section>

        <section className={styles.read} id="market-read" aria-labelledby="read-title"><div className={styles.sectionTitle}><h2 id="read-title">The Read<span>.</span></h2><span>From this snapshot</span></div><h3>{snapshot.read.title}</h3><p className={styles.readSummary}>{snapshot.read.summary}</p><div className={styles.readItems}>{snapshot.read.items.map((item) => <div key={item.id} className={styles.readItem} data-active={highlight(item.evidence_refs)}><span className={styles.readKind}>{item.kind}</span><p>{item.text}</p><button onClick={() => setEvidence(highlight(item.evidence_refs) ? [] : item.evidence_refs)} aria-pressed={highlight(item.evidence_refs)}><Eye size={14} />{highlight(item.evidence_refs) ? 'Evidence highlighted' : 'Show evidence'}</button>{highlight(item.evidence_refs) && <ul className={styles.evidenceList}>{snapshot.evidence.filter((source) => item.evidence_refs.includes(source.id)).map((source) => <li key={source.id}>{source.label} <small>{date(source.observed_at, snapshot.asset.market_timezone)}</small></li>)}</ul>}</div>)}</div></section>
      </div>

      <section className={styles.scenarios} aria-labelledby="scenario-title"><div className={styles.sectionTitle}><h2 id="scenario-title">Scenario reference paths</h2><span>Historical bootstrap · {snapshot.monte_carlo.horizon_sessions} sessions</span></div><div>{snapshot.scenarios.map((scenario) => <article key={scenario.id} data-tone={scenario.kind}><h3><i />{scenario.label}</h3><p>{scenario.interpretation}</p></article>)}</div></section>

      {snapshot.panels.volume.volume_at_price && <section className={styles.volumeProfile}><div className={styles.sectionTitle}><h2>Traded volume by price</h2><span>Observed trades · separate from the simulation</span></div><p>Point of control: {price(snapshot.panels.volume.volume_at_price.point_of_control_price)}</p><div>{snapshot.panels.volume.volume_at_price.bins.map((bin, index) => <span key={index} title={`${price(bin.lower_price)}–${price(bin.upper_price)}: ${compact(bin.volume)}`} style={{ height: `${Math.max(2, bin.volume / Math.max(...snapshot.panels.volume.volume_at_price!.bins.map((row) => row.volume)) * 90)}px` }} />)}</div></section>}

      <details className={styles.methodology}><summary>Sources & methodology <ChevronDown size={16} /></summary><div className={styles.methodologyBody}><section><h3>Observation & calculation</h3><dl><div><dt>Observation cutoff</dt><dd>{snapshot.provenance.observation_cutoff}</dd></div><div><dt>Generated</dt><dd>{snapshot.provenance.generated_at}</dd></div><div><dt>Coverage</dt><dd>{snapshot.bars.length} completed {publicData ? 'exchange daily records' : 'regular sessions'} · corporate actions {adjustmentLabel}</dd></div><div><dt>Model</dt><dd>{snapshot.monte_carlo.model.replaceAll('_', ' ')} · {snapshot.monte_carlo.trial_count.toLocaleString('en-US')} trials</dd></div><div><dt>Methodology</dt><dd>{snapshot.provenance.versions.methodology}</dd></div></dl><ul>{snapshot.monte_carlo.assumptions.map((item) => <li key={item}>{item}</li>)}</ul></section><section><h3>Data sources</h3>{snapshot.provenance.sources.map((source) => <div className={styles.source} key={source.id}><strong>{source.provider}</strong><p>{source.dataset}</p><small>Observed {source.observed_at} · stated delay {source.delay_minutes} min</small></div>)}<ul>{snapshot.provenance.caveats.map((item) => <li key={item}>{item}</li>)}</ul></section></div></details>
      <footer className={styles.footer}><span>Leo · Discover</span><p>{publicSnapshot && <>{hfData ? <>Data from <a href="https://hfdatalibrary.com" target="_blank" rel="noreferrer">HF Data Library (Ahmed Elkassabgi, 2026)</a>, under <a href="https://hfdatalibrary.com/pages/license" target="_blank" rel="noreferrer">CC BY 4.0 and upstream IEX terms</a>. Data provided for free by IEX. By accessing or using IEX Historical Data, you agree to the <a href="https://www.iex.io/legal/hist-data-terms" target="_blank" rel="noreferrer">IEX Historical Data Terms of Use</a>. </> : <><a href={publicSnapshot.provenance.rights.terms_url} target="_blank" rel="noreferrer">{publicSnapshot.provenance.sources[0]?.provider} · source terms</a>. </>}{publicSnapshot.provenance.rights.usage_note} Leo indicators, simulations and explanations are derived calculations. </>}{illustrative ? 'Synthetic example. ' : ''}{snapshot.read.disclosure}</p></footer>
    </main>
  </div>;
}

function PriceChart({ snapshot, bars, bands, cloud, evidence, inspected, onInspect }: { snapshot: Snapshot; bars: Snapshot['bars']; bands: boolean; cloud: boolean; evidence: string[]; inspected: number | null; onInspect: (index: number | null) => void }) {
  const id = useId().replaceAll(':', '');
  const W = 1320, H = 495, left = 20, right = 1250, top = 42, bottom = 442, historyEnd = 775, futureEnd = 1110;
  const [min, max] = (() => { const visibleTimes = new Set(bars.map((bar) => bar.observed_at)); const values = [...bars.flatMap((bar) => [bar.low, bar.high]), ...snapshot.levels.map((level) => level.price), ...snapshot.technical_indicators.bollinger20.points.filter((point) => visibleTimes.has(point.observed_at)).flatMap((point) => [point.lower, point.upper]), ...snapshot.monte_carlo.sampled_paths.flatMap((trial) => trial.points.map((point) => point.price)), ...snapshot.monte_carlo.terminal_particles.map((particle) => particle.terminal_price), ...snapshot.scenarios.flatMap((scenario) => scenario.points.map((point) => point.price))]; const lo = Math.min(...values), hi = Math.max(...values), pad = (hi - lo || hi * 0.1) * 0.08; return [lo - pad, hi + pad]; })();
  const y = (value: number) => bottom - (value - min) / (max - min) * (bottom - top);
  const x = (index: number) => left + (index + 0.5) / bars.length * (historyEnd - left);
  const xf = (offset: number) => historyEnd + offset / snapshot.monte_carlo.horizon_sessions * (futureEnd - historyEnd);
  const indexes = new Map(bars.map((bar, index) => [bar.observed_at, index]));
  const bb = snapshot.technical_indicators.bollinger20.points.filter((point) => indexes.has(point.observed_at));
  const selectedIndex = inspected ?? bars.length - 1;
  return <svg className={styles.priceChart} viewBox={`0 0 ${W} ${H}`} role="img" aria-labelledby={`${id}-title ${id}-desc`}>
    <title id={`${id}-title`}>{`${snapshot.asset.symbol}: historical price and Monte Carlo scenarios`}</title><desc id={`${id}-desc`}>Candlesticks, Bollinger bands, moving average, confirmed pivots, six key levels and a separately marked simulated distribution. Exact values are available in the level ledger and session inspector.</desc>
    <defs><clipPath id={`${id}-clip`}><rect x={left} y={top} width={right-left} height={bottom-top} /></clipPath><linearGradient id={`${id}-future`} x1="0" x2="1"><stop offset="0" stopColor={PALETTE.lilac} stopOpacity="0.015" /><stop offset="1" stopColor={PALETTE.lilac} stopOpacity="0.065" /></linearGradient></defs>
    <rect x={historyEnd} y={top} width={right-historyEnd} height={bottom-top} fill={`url(#${id}-future)`} />
    <text x={left} y={20} className={styles.chartLabel}>OBSERVED PRICE · DAILY</text><text x={historyEnd+16} y={20} className={styles.chartLabel}>CONDITIONAL SCENARIOS</text><text x={futureEnd+12} y={20} className={styles.chartLabel}>TERMINAL CLOUD</text>
    {Array.from({ length: 6 }, (_, index) => { const value = min + (max-min) * index / 5; return <g key={index}><line x1={left} x2={right} y1={y(value)} y2={y(value)} className={styles.gridLine} /><text x={right+10} y={y(value)+4} className={styles.axisLabel}>{price(value)}</text></g>; })}
    <line x1={historyEnd} x2={historyEnd} y1={top} y2={bottom} stroke={PALETTE.muted} strokeOpacity="0.45" strokeDasharray="3 6" />
    <g clipPath={`url(#${id}-clip)`}>
      {bands && bb.length > 0 && <><path d={`${path(bb.map((p) => ({ x: x(indexes.get(p.observed_at)!), y: y(p.upper) })))} ${path([...bb].reverse().map((p) => ({ x: x(indexes.get(p.observed_at)!), y: y(p.lower) }))).replace(/^M/, 'L')} Z`} fill={PALETTE.lilac} fillOpacity="0.055" /><path d={path(bb.map((p) => ({ x: x(indexes.get(p.observed_at)!), y: y(p.upper) })))} fill="none" stroke={PALETTE.lilac} strokeOpacity="0.3" strokeWidth="1" /><path d={path(bb.map((p) => ({ x: x(indexes.get(p.observed_at)!), y: y(p.lower) })))} fill="none" stroke={PALETTE.lilac} strokeOpacity="0.3" strokeWidth="1" /></>}
      {snapshot.levels.filter((level) => level.role !== 'sma20').map((level) => <g key={level.id} opacity={evidence.length && !level.evidence_refs.some((ref) => evidence.includes(ref)) ? 0.35 : 1}><line x1={left} x2={right} y1={y(level.price)} y2={y(level.price)} stroke={roleColors[level.role]} strokeWidth={level.role === 'last' ? 1.5 : 1} strokeDasharray={level.role === 'last' ? '0' : '3 6'} strokeOpacity={level.role === 'last' ? 0.8 : 0.5} /><rect x={left+5} y={y(level.price)-18} width={142} height={17} fill="#120e19" fillOpacity="0.92" /><text x={left+9} y={y(level.price)-6} fill={roleColors[level.role]} className={styles.levelLabel}>{level.label.toUpperCase()} {price(level.price)}</text></g>)}
      {cloud && snapshot.monte_carlo.sampled_paths.map((trial) => <path key={trial.sample_id} d={path(trial.points.map((p) => ({ x: xf(p.session_offset), y: y(p.price) })))} fill="none" stroke={PALETTE.lilac} strokeWidth="0.8" strokeOpacity="0.09" />)}
      {snapshot.scenarios.map((scenario) => <path key={scenario.id} d={path(scenario.points.map((p) => ({ x: xf(p.session_offset), y: y(p.price) })))} fill="none" stroke={scenario.kind === 'bull' ? PALETTE.green : scenario.kind === 'bear' ? PALETTE.red : PALETTE.lilac} strokeWidth="2" strokeDasharray="6 5" />)}
      {cloud && snapshot.monte_carlo.terminal_particles.map((particle) => <circle key={particle.sample_id} cx={futureEnd+17+((particle.sample_id*2654435761>>>0)%1000)/1000*100} cy={y(particle.terminal_price)} r={particle.sample_id%7===0 ? 1.9 : 1.2} fill={particle.terminal_price >= snapshot.last_price ? PALETTE.green : PALETTE.red} opacity={0.2+(particle.sample_id%5)*0.1} />)}
      {bars.map((bar,index) => { const color=bar.close>=bar.open ? PALETTE.green : PALETTE.red; return <g key={bar.observed_at}><line x1={x(index)} x2={x(index)} y1={y(bar.high)} y2={y(bar.low)} stroke={color} strokeWidth="1" /><rect x={x(index)-2.35} y={Math.min(y(bar.open),y(bar.close))} width={4.7} height={Math.max(1.25,Math.abs(y(bar.close)-y(bar.open)))} fill={bar.close>=bar.open ? '#1d352c' : color} stroke={color} strokeWidth="0.8" /></g>; })}
      <path d={path(snapshot.technical_indicators.sma20.points.filter((p) => indexes.has(p.observed_at)).map((p) => ({ x:x(indexes.get(p.observed_at)!), y:y(p.price) })))} fill="none" stroke={PALETTE.lilac} strokeWidth="1.8" />
      {snapshot.zigzag.confirmed_pivots.filter((p) => indexes.has(p.observed_at)).map((pivot,index) => <g key={pivot.id}><circle cx={x(indexes.get(pivot.observed_at)!)} cy={y(pivot.price)} r="3" fill="#120e19" stroke={PALETTE.gold} /><text x={x(indexes.get(pivot.observed_at)!)} y={y(pivot.price)+(pivot.kind==='high' ? -11 : 18)} textAnchor="middle" fill={PALETTE.gold} className={styles.pivotLabel}>{String.fromCharCode(65+index%26)}</text></g>)}
      {snapshot.zigzag.provisional_leg && indexes.has(snapshot.zigzag.provisional_leg.from_observed_at) && <line x1={x(indexes.get(snapshot.zigzag.provisional_leg.from_observed_at)!)} y1={y(snapshot.zigzag.provisional_leg.from_price)} x2={x(bars.length-1)} y2={y(snapshot.zigzag.provisional_leg.to_price)} stroke={PALETTE.gold} strokeDasharray="2 5" opacity="0.6" />}
      <line x1={x(selectedIndex)} x2={x(selectedIndex)} y1={top} y2={bottom} stroke={PALETTE.ink} strokeOpacity={inspected===null ? 0 : 0.25} />
      {bars.map((bar,index) => <rect key={`hit-${bar.observed_at}`} x={x(index)-(historyEnd-left)/bars.length/2} y={top} width={(historyEnd-left)/bars.length} height={bottom-top} fill="transparent" onMouseEnter={() => onInspect(index)} onClick={() => onInspect(index)} />)}
    </g>
    <circle cx={historyEnd} cy={y(snapshot.last_price)} r="4.2" fill={PALETTE.gold} />
    {[0, Math.floor(bars.length/3),Math.floor(bars.length*2/3),bars.length-1].map((index) => <text key={index} x={x(index)} y={bottom+26} textAnchor={index===0 ? 'start' : 'middle'} className={styles.axisLabel}>{date(bars[index]!.observed_at, snapshot.asset.market_timezone)}</text>)}
    <text x={futureEnd} y={bottom+26} textAnchor="middle" className={styles.axisLabel}>+{snapshot.monte_carlo.horizon_sessions} SESSIONS</text><text x={right} y={H-4} textAnchor="end" className={styles.chartLabel}>UNCALIBRATED MODEL · NOT A FORECAST</text>
  </svg>;
}

function MiniChart({ values, secondary = [], color, range, guides = [], kind = 'line', label }: { values: number[]; secondary?: number[]; color: string; range?: [number, number]; guides?: number[]; kind?: 'line' | 'bars'; label: string }) {
  const width=280, height=95, all=[...values,...secondary,...guides];
  const min=range?.[0] ?? (kind==='bars' ? 0 : Math.min(...all));
  const max=range?.[1] ?? Math.max(...all);
  const x=(index:number) => 5+index/Math.max(values.length-1,1)*(width-10);
  const y=(value:number) => height-8-(value-min)/(max-min||1)*(height-16);
  return <svg viewBox={`0 0 ${width} ${height}`} className={styles.miniChart} role="img" aria-label={label}>{guides.filter((guide)=>guide>=min&&guide<=max).map((guide)=><g key={guide}><line x1="0" x2={width} y1={y(guide)} y2={y(guide)} stroke={PALETTE.muted} opacity="0.3" strokeDasharray="3 5" /><text x={width-3} y={y(guide)-4} textAnchor="end" className={styles.miniLabel}>{guide}</text></g>)}{kind==='bars' ? values.map((value,index)=><rect key={index} x={x(index)} y={y(value)} width={Math.max(1,width/values.length-1.5)} height={height-8-y(value)} fill={color} opacity={index===values.length-1 ? 1 : 0.42} />) : <path d={path(values.map((value,index)=>({x:x(index),y:y(value)})))} fill="none" stroke={color} strokeWidth="1.8" />}{secondary.length>0&&<path d={path(secondary.map((value,index)=>({x:x(index),y:y(value)})))} fill="none" stroke={PALETTE.lilac} strokeWidth="1.1" strokeDasharray="4 3" />}</svg>;
}
