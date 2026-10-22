import React, { useEffect, useRef, useState } from 'react';
import { AlertTriangle, ArrowRight, Ban, CircleDot, Eye, ShieldCheck } from 'lucide-react';
import { modelAtlasSchema, type AtlasModel, type AtlasRegime, type ModelAtlas as Atlas } from './contract';
import './models.css';

// Display only. Every model quantity arrives precomputed and validated; the browser
// formats values and maps them to chart geometry, never derives a model output.
const PANEL = '#17101f', GOLD = '#ecb667', LILAC = '#d9a4df', GRID = '#2c2136', AXIS = '#594463', MUTED = '#bfafca', INK = '#f6edf7';
const fmt = (n: number | null | undefined, digits = 2) => n == null ? '—' : (Number(n.toFixed(digits)) === 0 ? 0 : n).toLocaleString('en-US', { maximumFractionDigits: digits, minimumFractionDigits: digits }).replace('-', '−');
const share = (n: number, digits = 1) => `${fmt(n * 100, digits)}%`;
const count = (n: number) => n.toLocaleString('en-US');
const utc = (value: string) => new Date(value).toLocaleString('en-US', { timeZone: 'UTC', dateStyle: 'medium', timeStyle: 'short' }) + ' UTC';
const words = (value: string) => { const text = value.toLowerCase().replace(/_/g, ' ').replace(/;\s*/g, '; ').replace(/\b(ou|hmm|vwap|sde)\b/g, m => m.toUpperCase()).replace('mahalanobis', 'Mahalanobis'); return text.charAt(0).toUpperCase() + text.slice(1); };
const TARGETS: Record<string, string> = { DIRECT_EQUITY: 'Stock', DIRECT_ETF: 'ETF', SPX_DIRECTION_AND_VWAP_PROXY_VIA_SPY: 'Index via SPY' };
const short = (hash: string) => `${hash.slice(0, 12)}…`;
const symbolFromHash = () => new URLSearchParams(location.hash.split('?')[1]).get('symbol');

function useWidth(fallback = 640): [React.RefObject<HTMLDivElement>, number] {
  const ref = useRef<HTMLDivElement>(null), [width, setWidth] = useState(fallback);
  useEffect(() => { const element = ref.current; if (!element || typeof ResizeObserver === 'undefined') return; const observer = new ResizeObserver(([entry]) => setWidth(Math.max(260, Math.round(entry!.contentRect.width)))); observer.observe(element); return () => observer.disconnect(); }, []);
  return [ref, width];
}
function ticks(min: number, max: number, target = 4) {
  const raw = (max - min) / target || 1, power = Math.floor(Math.log10(raw)), multiple = [1, 2, 2.5, 5, 10].find(m => m * 10 ** power >= raw)!, step = multiple * 10 ** power;
  const out: number[] = []; for (let v = Math.ceil(min / step) * step; v <= max + step * 1e-9; v += step) out.push(Math.abs(v) < step * 1e-9 ? 0 : v);
  return { values: out, digits: Math.max(0, -power + (multiple === 2.5 ? 1 : 0) - (multiple === 10 ? 1 : 0)) };
}
const mix = (a: string, b: string, t: number) => `rgb(${[1, 3, 5].map(i => Math.round(parseInt(a.slice(i, i + 2), 16) * (1 - t) + parseInt(b.slice(i, i + 2), 16) * t)).join(',')})`;

export function ModelAtlas() {
  const [atlas, setAtlas] = useState<Atlas | null>(null), [error, setError] = useState('');
  const [symbol, setSymbol] = useState(symbolFromHash), [regime, setRegime] = useState(0);
  useEffect(() => {
    const controller = new AbortController();
    fetch('/app/research-desk/data/model-atlas.json', { signal: controller.signal }).then(response => { if (!response.ok) throw new Error('Model parameters could not be loaded. Reload to try again.'); return response.json(); })
      .then(raw => { const parsed = modelAtlasSchema.safeParse(raw); if (!parsed.success) throw new Error('Model parameters failed validation, so none are shown.'); setAtlas(parsed.data); })
      .catch(reason => { if (!controller.signal.aborted) setError(reason instanceof Error ? reason.message : 'Model parameters are unavailable.'); });
    return () => controller.abort();
  }, []);
  useEffect(() => { const change = () => { const next = symbolFromHash(); if (next) { setSymbol(next); setRegime(0); } }; window.addEventListener('hashchange', change); return () => window.removeEventListener('hashchange', change); }, []);
  if (error) return <section className="tool-body"><p className="notice error" role="alert"><AlertTriangle size={16}/>{error}</p></section>;
  if (!atlas) return <section className="tool-body"><p className="muted" role="status">Loading model parameters…</p></section>;
  const model = atlas.models.find(item => item.symbol === symbol) ?? atlas.models[0]!;
  const select = (next: string) => { setSymbol(next); setRegime(0); history.replaceState(null, '', `#/models?symbol=${encodeURIComponent(next)}`); };
  const active = model.regimes[Math.min(regime, model.regimes.length - 1)]!;
  return <section className="tool-body atlas">
    <div className="atlas-intro"><h2>{atlas.models.length} frozen models, read from their parameters.</h2><p>Each model sorts the trading day into regimes, looks up similar moments from the same regime, and keeps a research-only diffusion layer. All of them are candidates: none is promoted and none publishes a probability.</p>
      <ul className="atlas-flags" aria-label="Model status"><li><ShieldCheck size={13}/>Not promoted</li><li><Ban size={13}/>No calibrated probability</li><li><Ban size={13}/>Execution disabled</li><li><Eye size={13}/>Frozen parameters, not live readings</li></ul></div>
    <div className="atlas-picker" role="group" aria-label="Model">{atlas.models.map(item => <button key={item.symbol} className={item.symbol === model.symbol ? 'selected' : ''} aria-pressed={item.symbol === model.symbol} onClick={() => select(item.symbol)}><b>{item.symbol}</b><span>{TARGETS[item.targetStatus] ?? words(item.targetStatus)}</span><small>{item.hmm.states} regimes{item.shadow.ouEnabled ? '' : ' · OU off'}</small></button>)}</div>
    <Pipeline model={model} atlas={atlas}/>
    <section className="atlas-section" aria-labelledby="atlas-regimes"><div className="atlas-heading"><h3 id="atlas-regimes">{model.symbol} regimes</h3><p>Each dot is one regime: volatility across, drift up or down, area by share of time in the {count(model.shadow.observations)}-minute shadow fit window. R1 has the lowest HMM variance and R{model.hmm.states} the highest. Hover, tap, or use the table to inspect one.</p></div>
      <div className="atlas-regime-layout"><RegimeMap model={model} active={active.state} onSelect={setRegime}/><Readout regime={active} atlas={atlas}/></div>
      <RegimeTable model={model} active={active.state} onSelect={setRegime}/></section>
    <section className="atlas-section" aria-labelledby="atlas-transition"><div className="atlas-heading"><h3 id="atlas-transition">How regimes hand off</h3><p>The HMM’s chance of moving from a row regime to a column regime in one {atlas.hmmStepMinutes}-minute step. The bright diagonal is persistence.</p></div><Transition model={model} step={atlas.hmmStepMinutes} active={active.state} onSelect={setRegime}/></section>
    <section className="atlas-section" aria-labelledby="atlas-selection"><div className="atlas-heading"><h3 id="atlas-selection">Why {model.hmm.states} regimes</h3><p>{words(model.selection.criterion)}. Fit on {model.selection.fitSessions} sessions, scored on the next {model.selection.validationSessions}; each regime needed at least {share(model.selection.minimumStateOccupancy, 0)} of validation occupancy.</p></div>
      <Selection model={model}/>{model.selection.atBoundary && <p className="notice"><AlertTriangle size={16}/>The best score is at the largest count tested ({model.hmm.states}). A larger model might score higher, so the best number of regimes is not established.</p>}</section>
    <div className="atlas-panels"><Kernel model={model} atlas={atlas}/><Lineage model={model}/></div>
    <section className="atlas-section" aria-labelledby="atlas-limits"><h3 id="atlas-limits">What this page does not show</h3><ul className="atlas-limits">{atlas.limitations.map(item => <li key={item}>{item}</li>)}</ul></section>
  </section>;
}

function Pipeline({model, atlas}: {model: AtlasModel; atlas: Atlas}) {
  const steps: [string, string, string, 'on' | 'shadow' | 'off'][] = [
    ['Inputs', `${atlas.features.hmm.length} regime inputs and ${atlas.features.kernel.length} analog features, point in time`, 'Frozen schema', 'on'],
    ['01 · Regime filter', `Gaussian HMM, ${model.hmm.states} regimes, one step per ${atlas.hmmStepMinutes} minutes, filtered forward only`, 'Candidate', 'on'],
    ['02 · Same-regime kernel', `${model.kernel.neighbors} nearest analogs from ${count(model.kernel.analogRows)} rows in the same regime and time bucket`, 'Uncalibrated', 'on'],
    ['03 · Regime SDE', `Drift and volatility per regime at ${model.shadow.stepMinutes}-minute steps`, 'Shadow only', 'shadow'],
    ['04 · VWAP-residual OU', model.shadow.ouEnabled ? 'Mean reversion toward VWAP per regime' : `Rejected: ${model.shadow.ouRejectionReasons.map(reason => words(reason.replace(/^OU_/, '')).toLowerCase()).join('; ') || 'disabled'}`, model.shadow.ouEnabled ? 'Shadow only' : 'Disabled', model.shadow.ouEnabled ? 'shadow' : 'off'],
    ['Calibration', 'No validated calibration artifact, so no probability is published', 'Unavailable', 'off'],
  ];
  const Icon = {on: CircleDot, shadow: Eye, off: Ban};
  return <ol className="atlas-pipeline" aria-label={`${model.symbol} model pipeline`}>{steps.map(([title, detail, status, kind], index) => { const StatusIcon = Icon[kind]; return <li key={title} className={kind}><b>{title}</b><p>{detail}</p><span><StatusIcon size={12}/>{status}</span>{index < steps.length - 1 && <ArrowRight className="atlas-arrow" size={14} aria-hidden/>}</li>; })}</ol>;
}

function RegimeMap({model, active, onSelect}: {model: AtlasModel; active: number; onSelect: (state: number) => void}) {
  const [ref, width] = useWidth(), height = Math.round(Math.min(380, Math.max(250, width * .58))), pad = {left: 52, right: 18, top: 18, bottom: 44};
  const xMax = Math.max(...model.regimes.map(r => r.volatilityBpPerSqrtMinute)) * 1.12, yMax = Math.max(1e-9, ...model.regimes.map(r => Math.abs(r.driftBpPerMinute))) * 1.25;
  const vol = ticks(0, xMax), drift = ticks(-yMax, yMax, 4);
  const x = (v: number) => pad.left + v / xMax * (width - pad.left - pad.right), y = (v: number) => pad.top + (yMax - v) / (2 * yMax) * (height - pad.top - pad.bottom), radius = (s: number) => 4 + Math.sqrt(s) * 22;
  const order = [...model.regimes].sort((a, b) => b.timeShare - a.timeShare), selected = model.regimes[active]!;
  return <div className="atlas-chart" ref={ref}><svg width={width} height={height} role="img" aria-label={`${model.symbol} regimes by volatility and drift. Values are listed in the regime table.`}>
    {vol.values.map(v => <g key={`x${v}`}><line x1={x(v)} x2={x(v)} y1={pad.top} y2={height - pad.bottom} stroke={GRID}/><text x={x(v)} y={height - pad.bottom + 18} textAnchor="middle">{fmt(v, vol.digits)}</text></g>)}
    {drift.values.map(v => <g key={`y${v}`}><line x1={pad.left} x2={width - pad.right} y1={y(v)} y2={y(v)} stroke={v === 0 ? AXIS : GRID}/><text x={pad.left - 8} y={y(v) + 4} textAnchor="end">{fmt(v, drift.digits)}</text></g>)}
    <text x={width - pad.right} y={height - 6} textAnchor="end">Volatility, bp per √minute →</text><text x={pad.left - 44} y={pad.top - 6}>Drift, bp/min</text>
    {order.map(r => <g key={r.state} className="atlas-dot" onPointerEnter={() => onSelect(r.state)} onClick={() => onSelect(r.state)}>
      <circle cx={x(r.volatilityBpPerSqrtMinute)} cy={y(r.driftBpPerMinute)} r={Math.max(14, radius(r.timeShare) + 4)} fill="transparent"/>
      <circle cx={x(r.volatilityBpPerSqrtMinute)} cy={y(r.driftBpPerMinute)} r={radius(r.timeShare)} fill={r.state === active ? GOLD : LILAC} fillOpacity={r.state === active ? 1 : .55} stroke={PANEL} strokeWidth="2"/></g>)}
    <text className="atlas-dot-label" x={Math.min(x(selected.volatilityBpPerSqrtMinute) + radius(selected.timeShare) + 6, width - pad.right - 24)} y={y(selected.driftBpPerMinute) - radius(selected.timeShare) - 4}>{selected.label}</text>
  </svg></div>;
}

function Readout({regime, atlas}: {regime: AtlasRegime; atlas: Atlas}) {
  const extent = Math.max(1, ...regime.inputMeans.map(Math.abs));
  return <aside className="atlas-readout" aria-live="polite"><span className="pill">Selected regime</span><strong>{regime.label}</strong>
    <dl className="definition-list"><div><dt>Share of time</dt><dd>{share(regime.timeShare)}</dd></div><div><dt>Mean stay</dt><dd>{fmt(regime.meanStayMinutes, 0)} min</dd></div><div><dt>Drift</dt><dd>{fmt(regime.driftBpPerMinute, 3)} bp/min</dd></div><div><dt>Volatility</dt><dd>{fmt(regime.volatilityBpPerSqrtMinute, 2)} bp/√min</dd></div>
      <div><dt>OU half-life</dt><dd>{regime.ou ? regime.ou.halfLifeMinutes == null ? 'Not mean reverting' : `${fmt(regime.ou.halfLifeMinutes, 0)} min` : 'OU disabled'}</dd></div>{regime.ou && <div><dt>Long-run VWAP gap</dt><dd>{fmt(regime.ou.longRunResidualBp, 2)} bp</dd></div>}</dl>
    <p className="atlas-input-title">Regime inputs, standardized</p>
    <ul className="atlas-inputs">{atlas.features.hmm.map((feature, index) => { const value = regime.inputMeans[index]!; const size = Math.abs(value) / extent * 50; return <li key={feature.id}><span>{feature.label}</span><svg viewBox="0 0 100 8" preserveAspectRatio="none" aria-hidden><line x1="50" x2="50" y1="0" y2="8" stroke={AXIS}/><rect x={value < 0 ? 50 - size : 50} width={size} y="1" height="6" rx="1" fill={value < 0 ? LILAC : GOLD}/></svg><b>{fmt(value, 2)}</b></li>; })}</ul>
  </aside>;
}

function RegimeTable({model, active, onSelect}: {model: AtlasModel; active: number; onSelect: (state: number) => void}) {
  return <div className="atlas-table-wrap" tabIndex={0} role="region" aria-label={`${model.symbol} regime table, scroll horizontally`}><table className="atlas-table"><thead><tr><th scope="col">Regime</th><th scope="col">Share of time</th><th scope="col">Mean stay</th><th scope="col">Drift, bp/min</th><th scope="col">Volatility, bp/√min</th><th scope="col">OU half-life</th></tr></thead>
    <tbody>{model.regimes.map(r => <tr key={r.state} className={r.state === active ? 'selected' : ''}><th scope="row"><button aria-pressed={r.state === active} onClick={() => onSelect(r.state)} onFocus={() => onSelect(r.state)}>{r.label}</button></th><td>{share(r.timeShare)}</td><td>{fmt(r.meanStayMinutes, 0)} min</td><td>{fmt(r.driftBpPerMinute, 3)}</td><td>{fmt(r.volatilityBpPerSqrtMinute, 2)}</td><td>{r.ou ? r.ou.halfLifeMinutes == null ? 'None' : `${fmt(r.ou.halfLifeMinutes, 0)} min` : 'Disabled'}</td></tr>)}</tbody></table></div>;
}

function Transition({model, step, active, onSelect}: {model: AtlasModel; step: number; active: number; onSelect: (state: number) => void}) {
  const [ref, width] = useWidth(), [hover, setHover] = useState<[number, number] | null>(null), states = model.hmm.states, label = 34;
  const cell = Math.max(16, Math.min(40, Math.floor((Math.min(width, 600) - label) / states))), size = label + cell * states, legend = Math.min(size - label, 260);
  const [from, to] = hover ?? [active, active], color = (p: number) => mix(PANEL, GOLD, Math.sqrt(p));
  return <div className="atlas-transition" ref={ref}>
    <p className="atlas-cell-readout" aria-live="polite"><b>{share(model.hmm.transition[from]![to]!)}</b> chance R{from + 1} moves to R{to + 1} in one {step}-minute step</p>
    <svg width={size} height={size + 44} role="img" aria-label={`${model.symbol} regime transition matrix. Values are listed under Matrix values.`} onPointerLeave={() => setHover(null)}>
      {model.hmm.transition.map((row, i) => <g key={i}><text x={label - 6} y={label + i * cell + cell / 2 + 4} textAnchor="end" className={i === active ? 'strong' : ''}>R{i + 1}</text><text x={label + i * cell + cell / 2} y={label - 8} textAnchor="middle" className={i === active ? 'strong' : ''}>{cell >= 22 || i % 2 === 0 ? `R${i + 1}` : ''}</text>
        {row.map((p, j) => <rect key={j} x={label + j * cell + 1} y={label + i * cell + 1} width={cell - 2} height={cell - 2} rx="2" fill={color(p)} stroke={hover?.[0] === i && hover[1] === j ? INK : 'none'} onPointerEnter={() => setHover([i, j])} onClick={() => onSelect(i)}/>)}</g>)}
      <defs><linearGradient id="atlas-scale"><stop offset="0" stopColor={PANEL}/><stop offset="1" stopColor={GOLD}/></linearGradient></defs>
      <rect x={label} y={size + 10} width={legend} height="8" rx="2" fill="url(#atlas-scale)" stroke={AXIS}/>
      {[0, .05, .25, 1].map(p => <text key={p} x={label + Math.sqrt(p) * legend} y={size + 34} textAnchor={p === 0 ? 'start' : p === 1 ? 'end' : 'middle'}>{p === 0 ? '0' : `${p * 100}%`}</text>)}
    </svg>
    <details className="atlas-matrix"><summary>Matrix values</summary><div className="atlas-table-wrap" tabIndex={0} role="region" aria-label="Transition matrix values, scroll horizontally"><table className="atlas-table compact"><thead><tr><th scope="col">From \ to</th>{model.regimes.map(r => <th key={r.state} scope="col">{r.label}</th>)}</tr></thead><tbody>{model.hmm.transition.map((row, i) => <tr key={i}><th scope="row">R{i + 1}</th>{row.map((p, j) => <td key={j}>{fmt(p * 100, 1)}</td>)}</tr>)}</tbody></table></div><p className="muted small">Percent per {step}-minute step. Each row sums to 100% before rounding.</p></details>
  </div>;
}

function Selection({model}: {model: AtlasModel}) {
  const [ref, width] = useWidth(), [hover, setHover] = useState<number | null>(null), height = 230, pad = {left: 56, right: 20, top: 24, bottom: 40};
  const candidates = [...model.selection.candidates].sort((a, b) => a.states - b.states), scores = candidates.map(c => c.validationLogLikelihood);
  const span = Math.max(...scores) - Math.min(...scores) || 1, yTicks = ticks(Math.min(...scores) - span * .08, Math.max(...scores) + span * .08, 4);
  const lo = Math.min(yTicks.values[0]!, Math.min(...scores)), hi = Math.max(yTicks.values[yTicks.values.length - 1]!, Math.max(...scores)), first = candidates[0]!.states, last = candidates[candidates.length - 1]!.states;
  const x = (k: number) => pad.left + (k - first) / Math.max(1, last - first) * (width - pad.left - pad.right), y = (v: number) => pad.top + (hi - v) / (hi - lo) * (height - pad.top - pad.bottom);
  const shown = candidates.find(c => c.states === (hover ?? model.selection.selectedStates))!;
  const move = (event: React.PointerEvent<SVGRectElement>) => { const box = event.currentTarget.getBoundingClientRect(), k = first + (event.clientX - box.left) / box.width * (last - first); setHover(candidates.reduce((best, c) => Math.abs(c.states - k) < Math.abs(best.states - k) ? c : best).states); };
  return <div className="atlas-chart" ref={ref}>
    <p className="atlas-cell-readout" aria-live="polite"><b>{shown.states} regimes</b> · validation log-likelihood {fmt(shown.validationLogLikelihood, 3)} per observation · {shown.states === model.selection.selectedStates ? 'selected' : shown.eligible ? 'eligible' : words(shown.status).toLowerCase()}</p>
    <ul className="atlas-key" aria-label="Marker key"><li><i className="filled"/>Eligible</li><li><i className="hollow"/>Rejected for low occupancy</li><li><i className="chosen"/>Selected</li></ul>
    <svg width={width} height={height} role="img" aria-label={`Validation score by number of regimes for ${model.symbol}; ${model.selection.selectedStates} selected.`}>
      {yTicks.values.map(v => <g key={v}><line x1={pad.left} x2={width - pad.right} y1={y(v)} y2={y(v)} stroke={GRID}/><text x={pad.left - 8} y={y(v) + 4} textAnchor="end">{fmt(v, yTicks.digits)}</text></g>)}
      {candidates.map(c => <text key={c.states} x={x(c.states)} y={height - pad.bottom + 18} textAnchor="middle">{c.states}</text>)}
      <text x={width - pad.right} y={height - 4} textAnchor="end">Number of regimes →</text>
      {hover != null && <line x1={x(hover)} x2={x(hover)} y1={pad.top} y2={height - pad.bottom} stroke={AXIS}/>}
      <path d={candidates.map((c, i) => `${i ? 'L' : 'M'}${x(c.states)},${y(c.validationLogLikelihood)}`).join(' ')} fill="none" stroke={LILAC} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round"/>
      {candidates.map(c => { const chosen = c.states === model.selection.selectedStates; return <circle key={c.states} cx={x(c.states)} cy={y(c.validationLogLikelihood)} r={chosen ? 6 : 4.5} fill={chosen ? GOLD : c.eligible ? LILAC : PANEL} stroke={chosen || c.eligible ? PANEL : LILAC} strokeWidth="2"/>; })}
      <rect x={pad.left} y={pad.top} width={width - pad.left - pad.right} height={height - pad.top - pad.bottom} fill="transparent" onPointerMove={move} onPointerLeave={() => setHover(null)}/>
    </svg></div>;
}

function Kernel({model, atlas}: {model: AtlasModel; atlas: Atlas}) {
  const k = model.kernel;
  return <section className="atlas-panel" aria-labelledby="atlas-kernel"><h3 id="atlas-kernel">Same-regime kernel</h3><p className="muted small">How the 12-dimensional analog search finds comparable moments.</p>
    <dl className="definition-list"><div><dt>Distance</dt><dd>{words(k.metric)}, {share(k.covarianceShrinkage, 0)} shrinkage</dd></div><div><dt>Neighbors</dt><dd>{k.neighbors}, bandwidth {words(k.bandwidthRule).toLowerCase()} × {k.bandwidthMultiplier}</dd></div>
      <div><dt>Regime match</dt><dd>{words(k.regimeMatchPolicy)}, similarity ≥ {k.minimumRegimeSimilarity}</dd></div><div><dt>Dominant regime</dt><dd>Posterior ≥ {k.minimumDominantRegimeProbability}</dd></div><div><dt>Minimum effective sample</dt><dd>{k.minimumEffectiveSampleSize}</dd></div>
      <div><dt>Same time of day</dt><dd>{k.sameTimeBucket ? 'Required' : 'Not required'}</dd></div><div><dt>Out of distribution</dt><dd>Distance above {fmt(k.oodDistanceThreshold, 2)} ({share(k.oodQuantile, 0)} quantile)</dd></div>
      <div><dt>Feature weights</dt><dd>{k.metricWeightsFitted ? 'Fitted per horizon' : `Uniform, ${fmt(k.metricWeights[0]!, 3)} each; none fitted`}</dd></div><div><dt>Analog rows</dt><dd>{count(k.analogRows)} through {utc(k.trainEnd)}</dd></div></dl>
    <ul className="atlas-chips" aria-label="Analog features">{atlas.features.kernel.map(feature => <li key={feature.id}>{feature.label}</li>)}</ul></section>;
}

function Lineage({model}: {model: AtlasModel}) {
  const l = model.lineage;
  return <section className="atlas-panel" aria-labelledby="atlas-lineage"><h3 id="atlas-lineage">Lineage</h3><p className="muted small">The exact frozen file behind every number on this page.</p>
    <dl className="definition-list"><div><dt>Target</dt><dd>{model.modelSymbol === model.symbol ? model.symbol : `${model.symbol} via ${model.modelSymbol}`} ({model.priceSymbol})</dd></div><div><dt>Status</dt><dd>{words(model.promotionStatus)}</dd></div>
      <div><dt>Training cutoff</dt><dd>{utc(l.trainingCutoff)}</dd></div><div><dt>Created</dt><dd>{utc(l.createdAt)}</dd></div><div><dt>Training rows</dt><dd>{count(l.trainingRows)}</dd></div>
      <div><dt>Shadow fit window</dt><dd>{count(model.shadow.observations)} one-minute rows to {utc(model.shadow.observationCutoff)}</dd></div>
      <div><dt>Model hash</dt><dd title={l.modelHash}><code>{short(l.modelHash)}</code></dd></div><div><dt>File SHA-256</dt><dd title={l.artifactFileSha256}><code>{short(l.artifactFileSha256)}</code></dd></div>
      <div><dt>Code commit</dt><dd title={l.codeCommit}><code>{short(l.codeCommit)}</code></dd></div><div><dt>Version</dt><dd className="atlas-wrap">{l.modelVersion}</dd></div></dl></section>;
}
