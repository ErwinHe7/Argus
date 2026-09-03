'use client';

import { useMemo, useState } from 'react';
import type { MaxPainResult } from '@/lib/market-intelligence/options';

const CHART_WIDTH = 880;
const CHART_HEIGHT = 320;
const PADDING = { top: 28, right: 24, bottom: 40, left: 64 };

export type MaxPainChartProps = {
  ticker: string;
  expiration: string;
  daysToExpiry?: number | null;
  maxPain: MaxPainResult;
};

export function MaxPainChart({ ticker, expiration, daysToExpiry, maxPain }: MaxPainChartProps) {
  const [hoverIdx, setHoverIdx] = useState<number | null>(null);

  // Sort curve by strike and trim the wide tails so the chart stays readable.
  const points = useMemo(() => {
    const sorted = [...maxPain.curve].sort((a, b) => a.strike - b.strike);
    // Trim to strikes within ~5σ band around max pain & spot
    const center = Math.max(maxPain.spot, maxPain.maxPainStrike);
    const span = Math.max(
      center * 0.6,
      Math.abs(maxPain.maxPainStrike - maxPain.spot) * 4 + 5
    );
    const lo = Math.max(0, center - span);
    const hi = center + span;
    return sorted.filter((p) => p.strike >= lo && p.strike <= hi);
  }, [maxPain]);

  if (points.length === 0) {
    return (
      <div className="rounded-[8px] border border-slate-700 bg-black p-6 text-sm text-slate-300">
        No max-pain curve points available for {ticker} {expiration}.
      </div>
    );
  }

  const innerW = CHART_WIDTH - PADDING.left - PADDING.right;
  const innerH = CHART_HEIGHT - PADDING.top - PADDING.bottom;

  const xMin = points[0].strike;
  const xMax = points[points.length - 1].strike;
  const yMax = Math.max(...points.map((p) => p.totalPain), 1);

  const xScale = (x: number) => PADDING.left + ((x - xMin) / Math.max(1e-9, xMax - xMin)) * innerW;
  const yScale = (y: number) => PADDING.top + innerH - (y / yMax) * innerH;
  const barWidth = Math.max(2, innerW / Math.max(1, points.length) - 1);

  const spotX = xScale(clamp(maxPain.spot, xMin, xMax));
  const maxPainX = xScale(clamp(maxPain.maxPainStrike, xMin, xMax));

  const yTicks = computeYTicks(yMax, 5);
  const xTicks = computeXTicks(xMin, xMax, 6);

  const hover = hoverIdx !== null ? points[hoverIdx] : null;

  return (
    <div className="rounded-[8px] border border-slate-700 bg-black p-3">
      <svg
        viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`}
        preserveAspectRatio="none"
        className="block h-72 w-full"
        onMouseLeave={() => setHoverIdx(null)}
      >
        {/* Y axis grid */}
        {yTicks.map((tick) => (
          <g key={tick}>
            <line
              x1={PADDING.left}
              x2={PADDING.left + innerW}
              y1={yScale(tick)}
              y2={yScale(tick)}
              stroke="#1f2937"
              strokeWidth={1}
            />
            <text
              x={PADDING.left - 8}
              y={yScale(tick) + 4}
              textAnchor="end"
              fontSize={10}
              fill="#94a3b8"
              fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
            >
              {formatMoneyShort(tick)}
            </text>
          </g>
        ))}

        {/* Bars */}
        {points.map((p, idx) => {
          const x = xScale(p.strike) - barWidth / 2;
          const y = yScale(p.totalPain);
          const h = PADDING.top + innerH - y;
          const isPutSide = p.strike < maxPain.maxPainStrike;
          const isMaxPain = p.strike === maxPain.maxPainStrike;
          const color = isMaxPain
            ? '#facc15'
            : isPutSide
              ? '#f87171'
              : '#34d399';
          const opacity = hoverIdx === null || hoverIdx === idx ? 0.85 : 0.55;
          return (
            <rect
              key={`${p.strike}-${idx}`}
              x={x}
              y={y}
              width={barWidth}
              height={h}
              fill={color}
              opacity={opacity}
              onMouseEnter={() => setHoverIdx(idx)}
            />
          );
        })}

        {/* Max Pain vertical line */}
        <line
          x1={maxPainX}
          x2={maxPainX}
          y1={PADDING.top}
          y2={PADDING.top + innerH}
          stroke="#f87171"
          strokeDasharray="4 3"
          strokeWidth={1.5}
        />
        <text
          x={maxPainX}
          y={PADDING.top - 12}
          textAnchor="middle"
          fontSize={11}
          fill="#fca5a5"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          max pain {maxPain.maxPainStrike.toFixed(0)}
        </text>

        {/* Current price vertical line */}
        <line
          x1={spotX}
          x2={spotX}
          y1={PADDING.top}
          y2={PADDING.top + innerH}
          stroke="#60a5fa"
          strokeDasharray="4 3"
          strokeWidth={1.5}
        />
        <text
          x={spotX}
          y={PADDING.top + innerH + 22}
          textAnchor="middle"
          fontSize={11}
          fill="#93c5fd"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          spot {maxPain.spot.toFixed(2)}
        </text>

        {/* X axis */}
        <line
          x1={PADDING.left}
          x2={PADDING.left + innerW}
          y1={PADDING.top + innerH}
          y2={PADDING.top + innerH}
          stroke="#334155"
        />
        {xTicks.map((tick) => (
          <g key={tick.toFixed(2)}>
            <line
              x1={xScale(tick)}
              x2={xScale(tick)}
              y1={PADDING.top + innerH}
              y2={PADDING.top + innerH + 4}
              stroke="#475569"
            />
            <text
              x={xScale(tick)}
              y={PADDING.top + innerH + 16}
              textAnchor="middle"
              fontSize={10}
              fill="#94a3b8"
              fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
            >
              {tick >= 1000 ? tick.toFixed(0) : tick.toFixed(1)}
            </text>
          </g>
        ))}

        {/* Axis labels */}
        <text
          x={14}
          y={PADDING.top + innerH / 2}
          textAnchor="middle"
          transform={`rotate(-90 14 ${PADDING.top + innerH / 2})`}
          fontSize={11}
          fill="#94a3b8"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          Option Market Value (writer pain)
        </text>
        <text
          x={PADDING.left + innerW / 2}
          y={CHART_HEIGHT - 6}
          textAnchor="middle"
          fontSize={11}
          fill="#94a3b8"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace"
        >
          Strikes
        </text>

        {/* Hover tooltip */}
        {hover ? (
          <g transform={`translate(${tooltipPlacement(xScale(hover.strike), innerW)}, ${PADDING.top + 12})`}>
            <rect width={200} height={70} rx={6} fill="#0f172a" stroke="#334155" />
            <text x={10} y={20} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
              Strike <tspan fill="#fbbf24">{hover.strike.toFixed(2)}</tspan>
            </text>
            <text x={10} y={38} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
              Pain <tspan fill="#93c5fd">{formatMoneyShort(hover.totalPain)}</tspan>
            </text>
            <text x={10} y={56} fontSize={11} fill="#cbd5e1" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
              Side <tspan fill={hover.strike < maxPain.maxPainStrike ? '#f87171' : '#34d399'}>
                {hover.strike < maxPain.maxPainStrike ? 'put-dominant' : 'call-dominant'}
              </tspan>
            </text>
          </g>
        ) : null}
      </svg>

      <div className="mt-2 flex flex-wrap items-center justify-between gap-x-4 gap-y-1 text-[11px] text-slate-400">
        <span>
          <Swatch color="#f87171" /> put-dominant losses
          <Swatch color="#facc15" className="ml-3" /> max pain strike
          <Swatch color="#34d399" className="ml-3" /> call-dominant losses
        </span>
        <span className="font-mono">
          {ticker} · expires {expiration}
          {daysToExpiry !== undefined && daysToExpiry !== null ? ` · ${daysToExpiry}d` : ''}
        </span>
      </div>
    </div>
  );
}

function Swatch({ color, className = '' }: { color: string; className?: string }) {
  return (
    <span
      className={`mr-1 inline-block h-2 w-3 align-middle ${className}`}
      style={{ backgroundColor: color }}
    />
  );
}

function tooltipPlacement(px: number, innerW: number): number {
  const tooltipWidth = 200;
  const rightEdge = PADDING.left + innerW;
  if (px + tooltipWidth + 16 > rightEdge) return Math.max(PADDING.left, px - tooltipWidth - 12);
  return px + 12;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, n));
}

function computeYTicks(yMax: number, n: number): number[] {
  const step = niceStep(yMax / n);
  const ticks: number[] = [];
  for (let v = 0; v <= yMax + step / 2; v += step) ticks.push(v);
  return ticks;
}

function computeXTicks(xMin: number, xMax: number, n: number): number[] {
  const step = niceStep((xMax - xMin) / n);
  const start = Math.ceil(xMin / step) * step;
  const ticks: number[] = [];
  for (let v = start; v <= xMax + 1e-6; v += step) ticks.push(v);
  return ticks;
}

function niceStep(approx: number): number {
  if (approx <= 0 || !Number.isFinite(approx)) return 1;
  const exp = Math.pow(10, Math.floor(Math.log10(approx)));
  const f = approx / exp;
  let mult: number;
  if (f < 1.5) mult = 1;
  else if (f < 3) mult = 2;
  else if (f < 7) mult = 5;
  else mult = 10;
  return mult * exp;
}

function formatMoneyShort(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return '$0';
  if (value >= 1_000_000_000) return `$${(value / 1_000_000_000).toFixed(1)}B`;
  if (value >= 1_000_000) return `$${(value / 1_000_000).toFixed(0)}M`;
  if (value >= 1_000) return `$${(value / 1_000).toFixed(0)}K`;
  return `$${value.toFixed(0)}`;
}
