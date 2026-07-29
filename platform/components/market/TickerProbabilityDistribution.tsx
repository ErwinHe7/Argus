'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import {
  callImpliedProbability,
  computeOptionProbability,
  daysUntil,
  putImpliedProbability,
  type OptionProbabilityResult,
  type ProbabilityPoint,
} from '@/lib/optionProbability';

type Tab = 'lognormal' | 'pdf' | 'cdf' | 'call' | 'put';

const TABS: Array<{ key: Tab; label: string; hint: string }> = [
  { key: 'lognormal', label: 'Lognormal Distribution', hint: 'Terminal-price density with target probability shading.' },
  { key: 'pdf', label: 'Probability Density (PDF)', hint: 'Lognormal probability density f(x).' },
  { key: 'cdf', label: 'Cumulative (CDF)', hint: 'P(S_T ≤ price) cumulative distribution.' },
  { key: 'call', label: 'Call Implied Probability', hint: 'N(d2): risk-neutral prob of call finishing ITM at each strike.' },
  { key: 'put', label: 'Put Implied Probability', hint: '1 − N(d2): risk-neutral prob of put finishing ITM at each strike.' },
];

const CHART_WIDTH = 880;
const CHART_HEIGHT = 320;
const PADDING = { top: 24, right: 24, bottom: 36, left: 56 };

export type TickerProbabilityDistributionProps = {
  ticker: string;
  defaultSpot: number;
  defaultTarget?: number;
  defaultIvAnnual: number; // decimal
  defaultExpiration: string; // YYYY-MM-DD
  defaultRiskFreeRate?: number; // decimal, default 0.045
  defaultDividendYield?: number; // decimal, default 0
  volatilitySource: 'options_iv' | 'historical_volatility' | 'manual';
  volatilitySourceLabel?: string;
};

export function TickerProbabilityDistribution({
  ticker,
  defaultSpot,
  defaultTarget,
  defaultIvAnnual,
  defaultExpiration,
  defaultRiskFreeRate = 0.045,
  defaultDividendYield = 0,
  volatilitySource,
  volatilitySourceLabel,
}: TickerProbabilityDistributionProps) {
  const [tab, setTab] = useState<Tab>('lognormal');
  const [spot, setSpot] = useState<string>(formatNumber(defaultSpot));
  const [ivPct, setIvPct] = useState<string>(formatNumber(defaultIvAnnual * 100, 2));
  const [expiration, setExpiration] = useState<string>(defaultExpiration);
  const [target, setTarget] = useState<string>(formatNumber(defaultTarget ?? defaultSpot, 2));
  const [ratePct, setRatePct] = useState<string>(formatNumber(defaultRiskFreeRate * 100, 2));
  const [divPct, setDivPct] = useState<string>(formatNumber(defaultDividendYield * 100, 2));
  const [vSource, setVSource] = useState(volatilitySource);
  const [vSourceLabel, setVSourceLabel] = useState(volatilitySourceLabel || labelForSource(volatilitySource));

  // Keep target sensible if spot changes meaningfully
  useEffect(() => {
    setSpot(formatNumber(defaultSpot));
    setTarget(formatNumber(defaultTarget ?? defaultSpot, 2));
  }, [defaultSpot, defaultTarget]);

  const spotNum = parseNumber(spot);
  const targetNum = parseNumber(target);
  const ivNum = parseNumber(ivPct) / 100;
  const rateNum = parseNumber(ratePct) / 100;
  const divNum = parseNumber(divPct) / 100;
  const dte = useMemo(() => daysUntil(expiration), [expiration]);

  const result = useMemo(
    () =>
      computeOptionProbability(
        {
          spot: spotNum,
          target: targetNum,
          ivAnnual: ivNum,
          daysToExpiry: dte,
          riskFreeRate: rateNum,
          dividendYield: divNum,
        },
        240
      ),
    [spotNum, targetNum, ivNum, dte, rateNum, divNum]
  );

  const onIvEdited = () => {
    if (vSource !== 'manual') {
      setVSource('manual');
      setVSourceLabel('Manual override');
    }
  };

  return (
    <section className="rounded-[6px] border border-slate-700 bg-[#141a2b] p-5 shadow-xl shadow-black/25">
      <header className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-[0.16em] text-slate-300">
            Option Probability · risk-neutral / model-implied
          </p>
          <h2 className="mt-1 text-2xl font-black text-white">
            {ticker} Option Probability
          </h2>
          <p className="mt-1 max-w-3xl text-xs leading-5 text-slate-300">
            Lognormal terminal-price model. Approximation only — not a guaranteed forecast and not investment advice.
            Volatility source: <span className="font-mono text-blue-200">{vSourceLabel}</span>.
          </p>
        </div>
        <div className="grid grid-cols-2 gap-2 text-right sm:grid-cols-3">
          <BigStat
            label="Prob. above target"
            value={result.ok ? `${(result.probAbove * 100).toFixed(2)}%` : '—'}
            tone="emerald"
          />
          <BigStat
            label="Prob. below target"
            value={result.ok ? `${(result.probBelow * 100).toFixed(2)}%` : '—'}
            tone="red"
          />
          <BigStat
            label="Expected move"
            value={result.ok ? `±${result.expectedMove.toFixed(2)} (${result.expectedMovePct.toFixed(1)}%)` : '—'}
            tone="blue"
          />
        </div>
      </header>

      {/* Inputs */}
      <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <Input label="Spot" value={spot} onChange={setSpot} suffix="$" />
        <Input
          label="IV (annual)"
          value={ivPct}
          onChange={(v) => {
            setIvPct(v);
            onIvEdited();
          }}
          suffix="%"
        />
        <Input label="Expiration" value={expiration} onChange={setExpiration} type="date" />
        <Input label="Target" value={target} onChange={setTarget} suffix="$" highlight />
        <Input label="Risk-free rate" value={ratePct} onChange={setRatePct} suffix="%" />
        <Input label="Dividend yield" value={divPct} onChange={setDivPct} suffix="%" />
      </div>

      {/* Validation error */}
      {!result.ok ? (
        <div className="mt-4 rounded-[6px] border border-red-400/40 bg-red-500/10 px-3 py-2 text-sm text-red-100">
          {result.error}
        </div>
      ) : null}

      {/* Tabs */}
      <div className="mt-5 flex flex-wrap items-center gap-2 border-b border-slate-800 pb-2">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setTab(t.key)}
            className={`rounded-[6px] px-3 py-1.5 text-xs font-black uppercase tracking-wider transition ${
              tab === t.key
                ? 'border border-blue-400/60 bg-blue-500/20 text-blue-100'
                : 'border border-slate-700 bg-slate-950 text-slate-300 hover:text-white'
            }`}
            title={t.hint}
          >
            {t.label}
          </button>
        ))}
      </div>

      {result.ok ? (
        <>
          <ProbabilityChart tab={tab} result={result} />

          {/* Quick stats row */}
          <div className="mt-4 grid gap-2 sm:grid-cols-3 lg:grid-cols-6">
            <MiniStat label="Days to expiry" value={`${result.daysToExpiry}`} />
            <MiniStat label="σ (annual)" value={`${(result.ivAnnual * 100).toFixed(2)}%`} />
            <MiniStat label="1σ low" value={result.oneSigmaLow.toFixed(2)} />
            <MiniStat label="1σ high" value={result.oneSigmaHigh.toFixed(2)} />
            <MiniStat label="2σ low" value={result.twoSigmaLow.toFixed(2)} />
            <MiniStat label="2σ high" value={result.twoSigmaHigh.toFixed(2)} />
          </div>
        </>
      ) : null}

      <p className="mt-4 border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">
        Model: lognormal terminal-price model with drift{' '}
        <code className="font-mono text-slate-300">μ = ln(S₀) + (r − q − ½σ²)T</code> and std{' '}
        <code className="font-mono text-slate-300">σ√T</code>. Probabilities are risk-neutral and shift with assumed
        IV, rate, and dividend yield. They are not guaranteed forecasts and do not constitute investment advice.
      </p>
    </section>
  );
}

function ProbabilityChart({ tab, result }: { tab: Tab; result: OptionProbabilityResult }) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const [hoverPx, setHoverPx] = useState<number | null>(null);

  const innerW = CHART_WIDTH - PADDING.left - PADDING.right;
  const innerH = CHART_HEIGHT - PADDING.top - PADDING.bottom;

  const series = useMemo(() => buildSeries(tab, result), [tab, result]);
  const yMax = Math.max(...series.points.map((p) => p.y), 1e-9);
  const xMin = result.minPrice;
  const xMax = result.maxPrice;

  const xScale = (x: number) => PADDING.left + ((x - xMin) / (xMax - xMin)) * innerW;
  const yScale = (y: number) => PADDING.top + innerH - (y / yMax) * innerH;

  // Build line + area paths.
  const linePath = series.points
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${xScale(p.x).toFixed(2)} ${yScale(p.y).toFixed(2)}`)
    .join(' ');
  const areaPath =
    `M ${xScale(series.points[0].x).toFixed(2)} ${yScale(0).toFixed(2)} ` +
    series.points.map((p) => `L ${xScale(p.x).toFixed(2)} ${yScale(p.y).toFixed(2)}`).join(' ') +
    ` L ${xScale(series.points[series.points.length - 1].x).toFixed(2)} ${yScale(0).toFixed(2)} Z`;

  // Shade region above target (lognormal/pdf only). For CDF show target-below shading.
  const shadeAbove = (tab === 'lognormal' || tab === 'pdf') && result.target >= xMin;
  let shadePath: string | null = null;
  if (shadeAbove) {
    const aboveTarget = series.points.filter((p) => p.x >= result.target);
    if (aboveTarget.length > 1) {
      shadePath =
        `M ${xScale(aboveTarget[0].x).toFixed(2)} ${yScale(0).toFixed(2)} ` +
        aboveTarget.map((p) => `L ${xScale(p.x).toFixed(2)} ${yScale(p.y).toFixed(2)}`).join(' ') +
        ` L ${xScale(aboveTarget[aboveTarget.length - 1].x).toFixed(2)} ${yScale(0).toFixed(2)} Z`;
    }
  }

  // X tick marks — 6 ticks across [xMin, xMax]
  const xTicks = useMemo(() => {
    const n = 6;
    const ticks: number[] = [];
    for (let i = 0; i <= n; i += 1) ticks.push(xMin + ((xMax - xMin) * i) / n);
    return ticks;
  }, [xMin, xMax]);

  // 1σ / 2σ shaded vertical regions (background)
  const oneSigmaRect = {
    x: xScale(result.oneSigmaLow),
    w: xScale(result.oneSigmaHigh) - xScale(result.oneSigmaLow),
  };
  const twoSigmaRect = {
    x: xScale(result.twoSigmaLow),
    w: xScale(result.twoSigmaHigh) - xScale(result.twoSigmaLow),
  };

  // Tooltip data based on hover x
  const tooltip = useMemo(() => {
    if (hoverPx === null) return null;
    const px = clamp(hoverPx, PADDING.left, PADDING.left + innerW);
    const xVal = xMin + ((px - PADDING.left) / innerW) * (xMax - xMin);
    // Lookup nearest point for the active series
    let nearest: { x: number; y: number } = series.points[0];
    let bestDist = Infinity;
    for (const p of series.points) {
      const d = Math.abs(p.x - xVal);
      if (d < bestDist) {
        bestDist = d;
        nearest = p;
      }
    }
    // Compute PDF/CDF/probAbove/probBelow at hovered price using the lognormal result
    const idx = nearestIndex(result.points, nearest.x);
    const lp = result.points[idx] || { price: nearest.x, pdf: 0, cdf: 0 };
    return {
      px,
      price: nearest.x,
      y: nearest.y,
      pdf: lp.pdf,
      cdf: lp.cdf,
      probAbove: 1 - lp.cdf,
      probBelow: lp.cdf,
    };
  }, [hoverPx, series, result, innerW, xMin, xMax]);

  return (
    <div className="mt-4 rounded-[8px] border border-slate-700 bg-black p-3">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`}
        preserveAspectRatio="none"
        className="block h-72 w-full"
        onMouseMove={(e) => {
          const rect = e.currentTarget.getBoundingClientRect();
          const ratio = CHART_WIDTH / rect.width;
          setHoverPx((e.clientX - rect.left) * ratio);
        }}
        onMouseLeave={() => setHoverPx(null)}
        onTouchMove={(e) => {
          const t = e.touches[0];
          if (!t) return;
          const rect = e.currentTarget.getBoundingClientRect();
          const ratio = CHART_WIDTH / rect.width;
          setHoverPx((t.clientX - rect.left) * ratio);
        }}
        onTouchEnd={() => setHoverPx(null)}
      >
        <defs>
          <linearGradient id="op-fill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#60a5fa" stopOpacity="0.55" />
            <stop offset="100%" stopColor="#1e3a8a" stopOpacity="0.05" />
          </linearGradient>
          <linearGradient id="op-shade" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#34d399" stopOpacity="0.55" />
            <stop offset="100%" stopColor="#065f46" stopOpacity="0.05" />
          </linearGradient>
        </defs>

        {/* 2σ + 1σ background */}
        <rect
          x={twoSigmaRect.x}
          y={PADDING.top}
          width={Math.max(0, twoSigmaRect.w)}
          height={innerH}
          fill="#1e293b"
          opacity="0.45"
        />
        <rect
          x={oneSigmaRect.x}
          y={PADDING.top}
          width={Math.max(0, oneSigmaRect.w)}
          height={innerH}
          fill="#1e3a8a"
          opacity="0.35"
        />

        {/* Y axis grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map((frac) => (
          <line
            key={frac}
            x1={PADDING.left}
            x2={PADDING.left + innerW}
            y1={PADDING.top + innerH * (1 - frac)}
            y2={PADDING.top + innerH * (1 - frac)}
            stroke="#1f2937"
            strokeWidth={1}
          />
        ))}

        {/* Area fill */}
        <path d={areaPath} fill="url(#op-fill)" />
        {/* Above-target shade */}
        {shadePath ? <path d={shadePath} fill="url(#op-shade)" /> : null}
        {/* Line */}
        <path d={linePath} stroke="#93c5fd" strokeWidth={2} fill="none" />

        {/* Spot marker */}
        <line
          x1={xScale(result.spot)}
          x2={xScale(result.spot)}
          y1={PADDING.top}
          y2={PADDING.top + innerH}
          stroke="#fbbf24"
          strokeWidth={1.5}
          strokeDasharray="4 3"
        />
        <text
          x={xScale(result.spot)}
          y={PADDING.top - 8}
          textAnchor="middle"
          fontSize={11}
          fill="#fbbf24"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          spot {result.spot.toFixed(2)}
        </text>

        {/* Target marker */}
        {result.target >= xMin && result.target <= xMax ? (
          <>
            <line
              x1={xScale(result.target)}
              x2={xScale(result.target)}
              y1={PADDING.top}
              y2={PADDING.top + innerH}
              stroke="#34d399"
              strokeWidth={1.5}
            />
            <text
              x={xScale(result.target)}
              y={PADDING.top + innerH + 22}
              textAnchor="middle"
              fontSize={11}
              fill="#34d399"
              fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
            >
              target {result.target.toFixed(2)}
            </text>
          </>
        ) : null}

        {/* X axis */}
        <line
          x1={PADDING.left}
          x2={PADDING.left + innerW}
          y1={PADDING.top + innerH}
          y2={PADDING.top + innerH}
          stroke="#334155"
          strokeWidth={1}
        />
        {xTicks.map((tick) => (
          <g key={tick.toFixed(3)}>
            <line
              x1={xScale(tick)}
              x2={xScale(tick)}
              y1={PADDING.top + innerH}
              y2={PADDING.top + innerH + 4}
              stroke="#475569"
              strokeWidth={1}
            />
            <text
              x={xScale(tick)}
              y={PADDING.top + innerH + 16}
              textAnchor="middle"
              fontSize={10}
              fill="#94a3b8"
              fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
            >
              {tick.toFixed(tick > 100 ? 0 : 1)}
            </text>
          </g>
        ))}

        {/* Y axis label */}
        <text
          x={12}
          y={PADDING.top + innerH / 2}
          textAnchor="middle"
          transform={`rotate(-90 12 ${PADDING.top + innerH / 2})`}
          fontSize={11}
          fill="#94a3b8"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          {series.yLabel}
        </text>
        <text
          x={PADDING.left + innerW / 2}
          y={CHART_HEIGHT - 4}
          textAnchor="middle"
          fontSize={11}
          fill="#94a3b8"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          Underlying price at expiration
        </text>

        {/* Hover crosshair + tooltip */}
        {tooltip ? (
          <>
            <line
              x1={tooltip.px}
              x2={tooltip.px}
              y1={PADDING.top}
              y2={PADDING.top + innerH}
              stroke="#64748b"
              strokeWidth={1}
            />
            <circle cx={tooltip.px} cy={yScale(tooltip.y)} r={3.5} fill="#93c5fd" />
            <g transform={`translate(${tooltipPlacement(tooltip.px, innerW)}, ${PADDING.top + 8})`}>
              <rect width={210} height={94} rx={6} fill="#0f172a" stroke="#334155" />
              <text x={10} y={18} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
                Price <tspan fill="#fbbf24">{tooltip.price.toFixed(2)}</tspan>
              </text>
              <text x={10} y={36} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
                PDF <tspan fill="#93c5fd">{tooltip.pdf.toExponential(2)}</tspan>
              </text>
              <text x={10} y={54} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
                CDF <tspan fill="#93c5fd">{(tooltip.cdf * 100).toFixed(2)}%</tspan>
              </text>
              <text x={10} y={72} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
                P(above) <tspan fill="#34d399">{(tooltip.probAbove * 100).toFixed(2)}%</tspan>
              </text>
              <text x={10} y={88} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
                P(below) <tspan fill="#f87171">{(tooltip.probBelow * 100).toFixed(2)}%</tspan>
              </text>
            </g>
          </>
        ) : null}
      </svg>

      <div className="mt-2 flex flex-wrap items-center justify-between gap-x-4 gap-y-1 text-[11px] text-slate-400">
        <span>
          <span className="mr-1 inline-block h-2 w-3 align-middle bg-blue-500/40" /> 1σ range
          <span className="ml-3 mr-1 inline-block h-2 w-3 align-middle bg-slate-600/60" /> 2σ range
          <span className="ml-3 mr-1 inline-block h-2 w-3 align-middle bg-emerald-500/40" /> above target
        </span>
        <span className="font-mono">
          {result.daysToExpiry}d to expiry · σ {(result.ivAnnual * 100).toFixed(1)}% · r {(result.riskFreeRate * 100).toFixed(2)}% · q {(result.dividendYield * 100).toFixed(2)}%
        </span>
      </div>
    </div>
  );
}

function buildSeries(
  tab: Tab,
  result: OptionProbabilityResult
): { points: Array<{ x: number; y: number }>; yLabel: string } {
  const { points, T, ivAnnual, riskFreeRate, dividendYield, spot } = result;
  if (tab === 'lognormal' || tab === 'pdf') {
    return { points: points.map((p) => ({ x: p.price, y: p.pdf })), yLabel: 'Probability density' };
  }
  if (tab === 'cdf') {
    return { points: points.map((p) => ({ x: p.price, y: p.cdf })), yLabel: 'P(S_T ≤ price)' };
  }
  if (tab === 'call') {
    return {
      points: points.map((p) => ({
        x: p.price,
        y: callImpliedProbability(spot, p.price, T, ivAnnual, riskFreeRate, dividendYield),
      })),
      yLabel: 'Call ITM probability',
    };
  }
  return {
    points: points.map((p) => ({
      x: p.price,
      y: putImpliedProbability(spot, p.price, T, ivAnnual, riskFreeRate, dividendYield),
    })),
    yLabel: 'Put ITM probability',
  };
}

function tooltipPlacement(px: number, innerW: number): number {
  const tooltipWidth = 210;
  const rightEdge = PADDING.left + innerW;
  if (px + tooltipWidth + 16 > rightEdge) return Math.max(PADDING.left, px - tooltipWidth - 12);
  return px + 12;
}

function nearestIndex(points: ProbabilityPoint[], x: number): number {
  let lo = 0;
  let hi = points.length - 1;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (points[mid].price < x) lo = mid + 1;
    else hi = mid;
  }
  if (lo > 0 && Math.abs(points[lo - 1].price - x) < Math.abs(points[lo].price - x)) return lo - 1;
  return lo;
}

function Input({
  label,
  value,
  onChange,
  suffix,
  type = 'text',
  highlight = false,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  suffix?: string;
  type?: 'text' | 'date';
  highlight?: boolean;
}) {
  return (
    <label
      className={`flex flex-col gap-1 rounded-[6px] border bg-slate-950 p-2 ${
        highlight ? 'border-emerald-400/40' : 'border-slate-700'
      }`}
    >
      <span className="text-[10px] font-black uppercase tracking-[0.12em] text-slate-300">{label}</span>
      <div className="flex items-center gap-1">
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          inputMode={type === 'date' ? undefined : 'decimal'}
          className="w-full bg-transparent font-mono text-sm font-black text-white outline-none placeholder:text-slate-600"
        />
        {suffix ? <span className="font-mono text-[10px] text-slate-400">{suffix}</span> : null}
      </div>
    </label>
  );
}

function BigStat({ label, value, tone }: { label: string; value: string; tone: 'emerald' | 'red' | 'blue' }) {
  const toneClass =
    tone === 'emerald' ? 'text-emerald-300' : tone === 'red' ? 'text-red-300' : 'text-blue-200';
  return (
    <div className="rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-2 text-left sm:text-right">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{label}</p>
      <p className={`mt-1 font-mono text-lg font-black ${toneClass}`}>{value}</p>
    </div>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-2">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{label}</p>
      <p className="mt-1 font-mono text-sm font-black text-white">{value}</p>
    </div>
  );
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, n));
}

function formatNumber(n: number, digits = 2): string {
  if (!Number.isFinite(n)) return '';
  return n.toFixed(digits);
}

function parseNumber(s: string): number {
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : NaN;
}

function labelForSource(source: 'options_iv' | 'historical_volatility' | 'manual'): string {
  if (source === 'options_iv') return 'Live options IV';
  if (source === 'historical_volatility') return 'Historical volatility fallback, not live options IV';
  return 'Manual override';
}
