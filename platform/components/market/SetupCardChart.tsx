'use client';

// 形态卡渲染 / ZIG-ZAG setup card.
// 全手写 SVG，跟 MaxPainChart 一样不引图表库：这张卡的要素（磁吸剖面、
// 情景路径、枢轴标注）没有现成图表库能直接画，引一个反而更绕。
//
// 布局分三段（跟卡面一致）：
//   历史区 → 情景区 → 磁吸剖面区
// 磁吸剖面的散点用确定性抖动，不能用 Math.random —— 否则 SSR 和 CSR
// 渲染不一致，Next 会报 hydration mismatch。

import { useMemo } from 'react';
import type {
  MagnetProfile,
  MagnetRow,
  ScenarioPath,
  SetupCard,
} from '@/lib/quant/setup-card';

const PALETTE = {
  bg: '#0a0f1c',
  panel: '#0d1424',
  grid: '#1e2a42',
  axis: '#5b6b8c',
  text: '#c8d3e8',
  textDim: '#7c8aa8',
  up: '#3fb950',
  down: '#e5534b',
  sma: '#b98ce8',
  band: '#3d4d6e',
  zigzag: '#5b8def',
  stretch: '#22d3ee',
  resistance: '#f0514f',
  support: '#3fb950',
  downLevel: '#f0883e',
  last: '#f5d90a',
  gold: '#e8b73a',
  bull: '#3fb950',
  base: '#8a97b4',
  bear: '#e5534b',
} as const;

const W = 1400;
/** 卡片最矮高度；解读折行多时会往下长，见 measureHeight */
const MIN_H = 930;
const READ_LINE_H = 19;
const READ_MAX_CHARS = 92;
const CHART = { x: 56, y: 50, w: 1198, h: 500 };
/** 历史 / 情景 / 磁吸剖面在主图里的横向占比 */
const SPLIT = { history: 0.72, scenario: 0.16 };

export type SetupCardChartProps = {
  card: SetupCard;
  className?: string;
};

export function SetupCardChart({ card, className }: SetupCardChartProps) {
  const geom = useMemo(() => buildGeometry(card), [card]);
  // 解读折行后可能比默认版心还长，先量再定卡片高度，
  // 免得最后一条 bullet 压在页脚免责声明上。
  const readLines = useMemo(
    () => card.read.map((line) => wrapText(line, READ_MAX_CHARS)),
    [card.read]
  );
  const readRows = readLines.reduce((sum, l) => sum + l.length, 0);
  const H = Math.max(MIN_H, TABLE.y + 44 + readRows * READ_LINE_H + 34);

  return (
    <div className={className}>
      <svg
        viewBox={`0 0 ${W} ${H}`}
        role="img"
        aria-label={`${card.symbol} ${card.patternName} setup card`}
        style={{ width: '100%', height: 'auto', background: PALETTE.bg }}
      >
        <Header card={card} />
        <MainChart card={card} geom={geom} />
        <SubPanels card={card} />
        <MagnetTable rows={card.rows} />
        <TheRead lines={readLines} />
        <text
          x={40}
          y={H - 12}
          fill={PALETTE.textDim}
          fontSize={11}
          fontStyle="italic"
          opacity={0.75}
        >
          right-edge cloud = MAGNET PROFILE: volume at each price (red supply ·
          green demand · gold = last 15 sessions) · scenario paths are
          illustrative, not forecasts
        </text>
      </svg>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* 几何                                                                 */
/* ------------------------------------------------------------------ */

type Geometry = {
  xOf: (index: number) => number;
  yOf: (price: number) => number;
  candleWidth: number;
  historyEnd: number;
  scenarioEnd: number;
  priceMin: number;
  priceMax: number;
  ticks: number[];
};

function buildGeometry(card: SetupCard): Geometry {
  const { candlesLen, lows, highs } = summarize(card);

  // y 轴只包住价格与区间边界；Stretch / Down 落在外面时标 "beyond view"
  const lo = Math.min(...lows, card.levels.support);
  const hi = Math.max(...highs, card.levels.resistance, card.levels.stretch);
  const pad = (hi - lo) * 0.06 || 1;
  const priceMin = lo - pad;
  const priceMax = hi + pad;

  const historyEnd = CHART.x + CHART.w * SPLIT.history;
  const scenarioEnd = historyEnd + CHART.w * SPLIT.scenario;

  const xOf = (index: number) =>
    CHART.x +
    (candlesLen <= 1 ? 0 : (index / (candlesLen - 1)) * (historyEnd - CHART.x));
  const yOf = (price: number) => {
    const t = (price - priceMin) / (priceMax - priceMin || 1);
    return CHART.y + CHART.h - t * CHART.h;
  };

  return {
    xOf,
    yOf,
    candleWidth: Math.max(2, ((historyEnd - CHART.x) / Math.max(1, candlesLen)) * 0.62),
    historyEnd,
    scenarioEnd,
    priceMin,
    priceMax,
    ticks: niceTicks(priceMin, priceMax, 5),
  };
}

function summarize(card: SetupCard) {
  const bb = card.bollinger;
  const lows: number[] = [];
  const highs: number[] = [];
  for (const c of card.candles) {
    lows.push(c.low);
    highs.push(c.high);
  }
  for (let i = 0; i < bb.lower.length; i += 1) {
    const l = bb.lower[i];
    const u = bb.upper[i];
    if (l !== null) lows.push(l);
    if (u !== null) highs.push(u);
  }
  lows.push(card.last);
  highs.push(card.last);
  return { candlesLen: card.candles.length, lows, highs };
}

function niceTicks(min: number, max: number, count: number): number[] {
  const span = max - min;
  if (span <= 0) return [min];
  const raw = span / count;
  const mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? mag * 10;
  const first = Math.ceil(min / step) * step;
  const out: number[] = [];
  for (let v = first; v <= max; v += step) out.push(Number(v.toFixed(6)));
  return out;
}

/* ------------------------------------------------------------------ */
/* 表头                                                                 */
/* ------------------------------------------------------------------ */

function Header({ card }: { card: SetupCard }) {
  const bits: string[] = [`state ${card.state}`];
  if (card.rsiNow !== null) bits.push(`RSI ${card.rsiNow.toFixed(0)}`);
  bits.push(
    `bottom ${card.pressure.bottom.toFixed(2)} / top ${card.pressure.top.toFixed(2)}`
  );
  if (card.sector) {
    bits.push(
      `${card.sector.name} ${fmtPct(card.sector.changePct5d)} (5d)`
    );
  }
  if (card.iv.now !== null) {
    const chg =
      card.iv.change5d !== null
        ? ` ${card.iv.change5d < 0 ? '↓' : '↑'}${Math.abs(card.iv.change5d).toFixed(1)}`
        : '';
    bits.push(`IV ${(card.iv.now * 100).toFixed(0)}%${chg} (5d)`);
  }

  return (
    <g>
      <text x={40} y={26} fontSize={25} fontWeight={700} fill={PALETTE.textDim}>
        {card.symbol}
        <tspan fill={PALETTE.axis}>{'  ·  '}</tspan>
        <tspan fill={PALETTE.text}>{card.patternName}</tspan>
        <tspan fill={PALETTE.textDim}>{` (${card.patternQualifier})`}</tspan>
      </text>
      <text x={40} y={44} fontSize={12} fill={PALETTE.textDim}>
        {bits.join('   |   ')}
      </text>
    </g>
  );
}

/* ------------------------------------------------------------------ */
/* 主图                                                                 */
/* ------------------------------------------------------------------ */

function MainChart({ card, geom }: { card: SetupCard; geom: Geometry }) {
  return (
    <g>
      <rect
        x={CHART.x}
        y={CHART.y}
        width={CHART.w}
        height={CHART.h}
        fill={PALETTE.panel}
        stroke={PALETTE.grid}
      />
      {geom.ticks.map((t) => (
        <g key={t}>
          <line
            x1={CHART.x}
            x2={CHART.x + CHART.w}
            y1={geom.yOf(t)}
            y2={geom.yOf(t)}
            stroke={PALETTE.grid}
            strokeWidth={1}
            opacity={0.5}
          />
          <text
            x={CHART.x - 8}
            y={geom.yOf(t) + 4}
            fontSize={12}
            fill={PALETTE.axis}
            textAnchor="end"
          >
            {t.toFixed(0)}
          </text>
        </g>
      ))}

      <BollingerBand card={card} geom={geom} />
      <Candles card={card} geom={geom} />
      <SmaLine card={card} geom={geom} />
      <ZigZag card={card} geom={geom} />
      <Levels card={card} geom={geom} />
      <Scenarios card={card} geom={geom} />
      <MagnetCloud magnet={card.magnet} geom={geom} last={card.last} />
      <LastMarker card={card} geom={geom} />

      <line
        x1={geom.historyEnd}
        x2={geom.historyEnd}
        y1={CHART.y}
        y2={CHART.y + CHART.h}
        stroke={PALETTE.axis}
        strokeWidth={1}
        strokeDasharray="2 4"
        opacity={0.5}
      />
      <text
        x={geom.historyEnd - 6}
        y={CHART.y + CHART.h - 10}
        fontSize={11}
        fill={PALETTE.textDim}
        textAnchor="end"
      >
        history ←
      </text>
      <text
        x={geom.historyEnd + 6}
        y={CHART.y + CHART.h - 10}
        fontSize={11}
        fill={PALETTE.textDim}
      >
        → scenarios
      </text>
    </g>
  );
}

function BollingerBand({ card, geom }: { card: SetupCard; geom: Geometry }) {
  const { upper, lower } = card.bollinger;
  const up = linePath(upper, geom);
  const lo = linePath(lower, geom);
  if (!up || !lo) return null;
  return (
    <g>
      <path d={up} fill="none" stroke={PALETTE.band} strokeWidth={1} strokeDasharray="2 3" />
      <path d={lo} fill="none" stroke={PALETTE.band} strokeWidth={1} strokeDasharray="2 3" />
      <text
        x={geom.historyEnd - 4}
        y={CHART.y + 232}
        fontSize={11}
        fill={PALETTE.band}
        textAnchor="end"
      >
        BB({card.bollinger.period},{card.bollinger.multiplier}σ)
      </text>
    </g>
  );
}

function SmaLine({ card, geom }: { card: SetupCard; geom: Geometry }) {
  const d = linePath(card.sma20, geom);
  if (!d) return null;
  return <path d={d} fill="none" stroke={PALETTE.sma} strokeWidth={1.8} />;
}

function linePath(values: (number | null)[], geom: Geometry): string | null {
  let d = '';
  let started = false;
  for (let i = 0; i < values.length; i += 1) {
    const v = values[i];
    if (v === null) continue;
    d += `${started ? 'L' : 'M'}${geom.xOf(i).toFixed(2)} ${geom.yOf(v).toFixed(2)}`;
    started = true;
  }
  return started ? d : null;
}

function Candles({ card, geom }: { card: SetupCard; geom: Geometry }) {
  const candles = card.candles;
  return (
    <g>
      {candles.map((c, i) => {
        const up = c.close >= c.open;
        const color = up ? PALETTE.up : PALETTE.down;
        const x = geom.xOf(i);
        const yHigh = geom.yOf(c.high);
        const yLow = geom.yOf(c.low);
        const yOpen = geom.yOf(c.open);
        const yClose = geom.yOf(c.close);
        const top = Math.min(yOpen, yClose);
        const height = Math.max(1, Math.abs(yClose - yOpen));
        return (
          <g key={c.date}>
            <line x1={x} x2={x} y1={yHigh} y2={yLow} stroke={color} strokeWidth={1} />
            <rect
              x={x - geom.candleWidth / 2}
              y={top}
              width={geom.candleWidth}
              height={height}
              fill={color}
            />
          </g>
        );
      })}
    </g>
  );
}

function ZigZag({ card, geom }: { card: SetupCard; geom: Geometry }) {
  if (card.pivots.length < 2) return null;
  const d = card.pivots
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${geom.xOf(p.index)} ${geom.yOf(p.price)}`)
    .join('');
  return (
    <g>
      <path
        d={d}
        fill="none"
        stroke={PALETTE.zigzag}
        strokeWidth={1.6}
        strokeDasharray="6 4"
      />
      {card.pivots.map((p) => {
        const x = geom.xOf(p.index);
        const y = geom.yOf(p.price);
        const high = p.kind === 'high';
        const color = high ? PALETTE.down : PALETTE.up;
        // 高点朝下的三角，低点朝上的三角
        const tri = high
          ? `${x - 6},${y - 10} ${x + 6},${y - 10} ${x},${y - 1}`
          : `${x - 6},${y + 10} ${x + 6},${y + 10} ${x},${y + 1}`;
        return (
          <g key={`${p.index}-${p.kind}`}>
            <polygon points={tri} fill={color} />
            {p.label && (
              <text
                x={x}
                y={high ? y - 16 : y + 26}
                fontSize={13}
                fontWeight={700}
                fill={PALETTE.zigzag}
                textAnchor="middle"
              >
                {p.label}
              </text>
            )}
          </g>
        );
      })}
    </g>
  );
}

function Levels({ card, geom }: { card: SetupCard; geom: Geometry }) {
  const { stretch, resistance, support, down } = card.levels;
  const items = [
    {
      key: 'stretch',
      price: stretch,
      color: PALETTE.stretch,
      label: `STRETCH ${stretch.toFixed(2)} (${fmtPct(pctFrom(card.last, stretch))})`,
      dash: '10 5',
      width: 2.5,
    },
    {
      key: 'resistance',
      price: resistance,
      color: PALETTE.resistance,
      label: `RESISTANCE ${resistance.toFixed(2)}`,
      dash: undefined,
      width: 3,
    },
    {
      key: 'support',
      price: support,
      color: PALETTE.support,
      label: `SUPPORT ${support.toFixed(2)}`,
      dash: undefined,
      width: 3,
    },
    {
      key: 'down',
      price: down,
      color: PALETTE.downLevel,
      label: `DOWN ${down.toFixed(2)} (${fmtPct(pctFrom(card.last, down))})`,
      dash: '6 4',
      width: 1.6,
    },
  ];

  // 价位挨得近时标签会叠在一起：按 y 从上到下扫一遍，
  // 不够 14px 就把后一个往下推。
  const placed: { y: number; labelY: number }[] = [];
  let cursor = -Infinity;
  for (const it of items) {
    const beyond = it.price < geom.priceMin || it.price > geom.priceMax;
    const y = beyond
      ? it.price > geom.priceMax
        ? CHART.y + 10
        : CHART.y + CHART.h - 10
      : geom.yOf(it.price);
    const wanted = y - 7;
    const labelY = Math.max(wanted, cursor + 14);
    cursor = labelY;
    placed.push({ y, labelY });
  }

  return (
    <g>
      {items.map((it, idx) => {
        const beyond = it.price < geom.priceMin || it.price > geom.priceMax;
        const { y, labelY } = placed[idx];
        return (
          <g key={it.key}>
            {!beyond && (
              <line
                x1={CHART.x}
                x2={CHART.x + CHART.w}
                y1={y}
                y2={y}
                stroke={it.color}
                strokeWidth={it.width}
                strokeDasharray={it.dash}
                opacity={0.9}
              />
            )}
            <text
              x={CHART.x + 6}
              y={labelY}
              fontSize={13}
              fontWeight={700}
              fill={it.color}
            >
              {it.label}
              {beyond ? ' (beyond view)' : ''}
            </text>
          </g>
        );
      })}
    </g>
  );
}

function Scenarios({ card, geom }: { card: SetupCard; geom: Geometry }) {
  const style: Record<ScenarioPath['kind'], { color: string; dash: string; label: string }> = {
    bull: { color: PALETTE.bull, dash: '3 4', label: 'bull path' },
    base: { color: PALETTE.base, dash: '9 6', label: 'base path' },
    bear: { color: PALETTE.bear, dash: '3 4', label: 'bear path' },
  };
  const span = geom.scenarioEnd - geom.historyEnd;

  return (
    <g>
      {card.scenarios.map((path) => {
        const s = style[path.kind];
        const d = path.points
          .map(
            (pt, i) =>
              `${i === 0 ? 'M' : 'L'}${geom.historyEnd + pt.t * span} ${clampY(
                geom.yOf(pt.price)
              )}`
          )
          .join('');
        const endY = clampY(geom.yOf(path.target));
        return (
          <g key={path.kind}>
            <path
              d={d}
              fill="none"
              stroke={s.color}
              strokeWidth={1.6}
              strokeDasharray={s.dash}
              opacity={0.85}
            />
            <text
              x={geom.scenarioEnd - 6}
              y={endY - 6}
              fontSize={12}
              fontStyle="italic"
              fill={s.color}
              textAnchor="end"
            >
              {s.label}
            </text>
          </g>
        );
      })}
    </g>
  );
}

function clampY(y: number): number {
  return Math.max(CHART.y + 4, Math.min(CHART.y + CHART.h - 4, y));
}

/**
 * 磁吸剖面：每个价格档按成交量撒点。抖动用确定性哈希，
 * 保证 SSR / CSR 渲染完全一致。
 */
function MagnetCloud({
  magnet,
  geom,
  last,
}: {
  magnet: MagnetProfile;
  geom: Geometry;
  last: number;
}) {
  const x0 = geom.scenarioEnd + 62;
  const width = CHART.x + CHART.w - x0 - 6;
  if (magnet.maxVolume <= 0 || width <= 0) return null;

  const dots: { x: number; y: number; fill: string; r: number }[] = [];
  const outline: string[] = [];

  magnet.bins.forEach((bin, bi) => {
    const y = geom.yOf(bin.mid);
    if (y < CHART.y || y > CHART.y + CHART.h) return;
    const ratio = bin.volume / magnet.maxVolume;
    outline.push(`${x0 + ratio * width},${y}`);

    const count = Math.round(ratio * 26);
    const goldShare = bin.volume > 0 ? bin.recentVolume / bin.volume : 0;
    for (let i = 0; i < count; i += 1) {
      const jx = hash01(bi * 131 + i * 17);
      const jy = hash01(bi * 977 + i * 31) - 0.5;
      const isGold = hash01(bi * 61 + i * 7) < goldShare;
      dots.push({
        x: x0 + jx * ratio * width,
        y: y + jy * 9,
        r: 1.6,
        fill: isGold
          ? PALETTE.gold
          : bin.side === 'supply'
            ? PALETTE.resistance
            : PALETTE.support,
      });
    }
  });

  const pocY = geom.yOf(magnet.pointOfControl);

  return (
    <g>
      <text x={x0} y={CHART.y + 14} fontSize={11} fill={PALETTE.textDim}>
        MAGNET
      </text>
      <text x={x0} y={CHART.y + 27} fontSize={11} fill={PALETTE.textDim}>
        PROFILE
      </text>
      {outline.length > 1 && (
        <polyline
          points={outline.join(' ')}
          fill="none"
          stroke={PALETTE.resistance}
          strokeWidth={1.2}
          opacity={0.5}
        />
      )}
      {dots.map((d, i) => (
        <circle key={i} cx={d.x} cy={d.y} r={d.r} fill={d.fill} opacity={0.62} />
      ))}
      {pocY >= CHART.y && pocY <= CHART.y + CHART.h && (
        <>
          <text x={x0 + width + 2} y={pocY + 5} fontSize={14} fill={PALETTE.gold}>
            ★
          </text>
          <text
            x={x0 + width + 18}
            y={pocY + 5}
            fontSize={14}
            fontWeight={700}
            fill={PALETTE.gold}
          >
            {magnet.pointOfControl.toFixed(2)}
          </text>
        </>
      )}
      <text
        x={CHART.x + CHART.w - 6}
        y={CHART.y + CHART.h - 24}
        fontSize={10}
        fill={PALETTE.gold}
        textAnchor="end"
        opacity={0.8}
      >
        gold = last 15d
      </text>
      <line
        x1={CHART.x}
        x2={CHART.x + CHART.w}
        y1={geom.yOf(last)}
        y2={geom.yOf(last)}
        stroke={PALETTE.last}
        strokeWidth={1}
        strokeDasharray="4 4"
        opacity={0.55}
      />
    </g>
  );
}

/** 32-bit 整数哈希 → 0..1，用来做确定性抖动。 */
function hash01(n: number): number {
  let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b);
  x = Math.imul(x ^ (x >>> 13), 0xc2b2ae35);
  return ((x ^ (x >>> 16)) >>> 0) / 4294967296;
}

function LastMarker({ card, geom }: { card: SetupCard; geom: Geometry }) {
  const y = geom.yOf(card.last);
  const x = geom.historyEnd;
  const label = `LAST ${card.last.toFixed(2)}`;
  const width = label.length * 9.2 + 16;
  return (
    <g>
      <rect
        x={x - width - 8}
        y={y - 15}
        width={width}
        height={26}
        rx={4}
        fill={PALETTE.last}
      />
      <text
        x={x - width / 2 - 8}
        y={y + 3}
        fontSize={15}
        fontWeight={700}
        fill="#1a1400"
        textAnchor="middle"
      >
        {label}
      </text>
    </g>
  );
}

/* ------------------------------------------------------------------ */
/* 子面板                                                               */
/* ------------------------------------------------------------------ */

const PANEL = { y: 565, h: 135, gap: 24, x: 44 };

function SubPanels({ card }: { card: SetupCard }) {
  const width = (W - PANEL.x * 2 - PANEL.gap * 3) / 4;
  const at = (i: number) => PANEL.x + i * (width + PANEL.gap);

  const rsiChange =
    card.rsi5dChange !== null
      ? `${card.rsi5dChange < 0 ? '↓' : '↑'}${Math.abs(card.rsi5dChange).toFixed(0)}`
      : '';
  const ivChange =
    card.iv.change5d !== null
      ? `${card.iv.change5d < 0 ? '↓' : '↑'}${Math.abs(card.iv.change5d).toFixed(1)}`
      : '';

  return (
    <g>
      <Panel
        x={at(0)}
        width={width}
        title="VOLUME"
        value={`${card.volume.relative.toFixed(1)}× avg`}
        valueColor={PALETTE.text}
      >
        <VolumeBars card={card} x={at(0)} width={width} />
      </Panel>

      <Panel
        x={at(1)}
        width={width}
        title="RSI 14"
        value={`${card.rsiNow !== null ? card.rsiNow.toFixed(0) : '—'} ${rsiChange}`}
        valueColor={PALETTE.text}
      >
        <RsiTrace card={card} x={at(1)} width={width} />
      </Panel>

      <Panel
        x={at(2)}
        width={width}
        title="MOMENTUM"
        value={`${card.momentum.state} ${card.momentum.state === 'KNIFE' ? '↓' : ''}`}
        valueColor={
          card.momentum.state === 'KNIFE' || card.momentum.state === 'FALLING'
            ? PALETTE.down
            : card.momentum.state === 'FLAT'
              ? PALETTE.text
              : PALETTE.up
        }
      >
        <MomentumTrace card={card} x={at(2)} width={width} />
      </Panel>

      <Panel
        x={at(3)}
        width={width}
        title="ATM IV"
        value={
          card.iv.now !== null
            ? `${(card.iv.now * 100).toFixed(0)}% ${ivChange}`
            : 'n/a'
        }
        valueColor={card.iv.now !== null ? PALETTE.up : PALETTE.textDim}
      >
        <IvTrace card={card} x={at(3)} width={width} />
      </Panel>
    </g>
  );
}

function Panel({
  x,
  width,
  title,
  value,
  valueColor,
  children,
}: {
  x: number;
  width: number;
  title: string;
  value: string;
  valueColor: string;
  children: React.ReactNode;
}) {
  // 面板内容一律裁到面板框内，否则动量的填充区会溢出到卡片上
  const clipId = `panel-clip-${Math.round(x)}`;
  return (
    <g>
      <defs>
        <clipPath id={clipId}>
          <rect x={x} y={PANEL.y} width={width} height={PANEL.h} />
        </clipPath>
      </defs>
      <text x={x} y={PANEL.y - 8} fontSize={12} fontWeight={700} fill={PALETTE.textDim}>
        {title}
      </text>
      <text
        x={x + width}
        y={PANEL.y - 8}
        fontSize={14}
        fontWeight={700}
        fill={valueColor}
        textAnchor="end"
      >
        {value}
      </text>
      <rect
        x={x}
        y={PANEL.y}
        width={width}
        height={PANEL.h}
        fill={PALETTE.panel}
        stroke={PALETTE.grid}
      />
      <g clipPath={`url(#${clipId})`}>{children}</g>
    </g>
  );
}

function VolumeBars({ card, x, width }: { card: SetupCard; x: number; width: number }) {
  const bars = card.volume.bars.slice(-16);
  const closes = card.candles.slice(-16);
  const max = Math.max(...bars, 1);
  const bw = width / Math.max(1, bars.length);
  const avgY = PANEL.y + PANEL.h - (card.volume.average / max) * (PANEL.h - 10);
  return (
    <g>
      {bars.map((v, i) => {
        const h = (v / max) * (PANEL.h - 10);
        const c = closes[i];
        const up = c ? c.close >= c.open : true;
        return (
          <rect
            key={i}
            x={x + i * bw + 1}
            y={PANEL.y + PANEL.h - h}
            width={Math.max(1, bw - 2)}
            height={h}
            fill={up ? PALETTE.up : PALETTE.down}
            opacity={0.85}
          />
        );
      })}
      <line
        x1={x}
        x2={x + width}
        y1={avgY}
        y2={avgY}
        stroke={PALETTE.gold}
        strokeWidth={1}
        strokeDasharray="4 3"
      />
    </g>
  );
}

function RsiTrace({ card, x, width }: { card: SetupCard; x: number; width: number }) {
  const values = card.rsi.filter((v): v is number => v !== null).slice(-60);
  if (values.length < 2) return null;
  const yOf = (v: number) => PANEL.y + PANEL.h - (v / 100) * PANEL.h;
  const d = values
    .map((v, i) => `${i === 0 ? 'M' : 'L'}${x + (i / (values.length - 1)) * width} ${yOf(v)}`)
    .join('');
  const lastY = yOf(values[values.length - 1]);
  return (
    <g>
      <rect x={x} y={PANEL.y} width={width} height={yOf(70) - PANEL.y} fill={PALETTE.down} opacity={0.12} />
      <rect x={x} y={yOf(30)} width={width} height={PANEL.y + PANEL.h - yOf(30)} fill={PALETTE.up} opacity={0.12} />
      <path d={d} fill="none" stroke="#f078a8" strokeWidth={1.6} />
      <circle cx={x + width} cy={lastY} r={3} fill="#f078a8" />
    </g>
  );
}

function MomentumTrace({ card, x, width }: { card: SetupCard; x: number; width: number }) {
  const series = card.momentum.series.slice(-60);
  const signal = card.momentum.signal.slice(-60);
  if (series.length < 2) return null;
  const mid = PANEL.y + PANEL.h / 2;
  const yOf = (v: number) => mid - v * (PANEL.h / 2 - 6);
  const px = (i: number) => x + (i / (series.length - 1)) * width;

  const area =
    `M${px(0)} ${mid}` +
    series.map((v, i) => `L${px(i)} ${yOf(v)}`).join('') +
    `L${px(series.length - 1)} ${mid}Z`;
  const signalPath = signal
    .map((v, i) => `${i === 0 ? 'M' : 'L'}${px(i)} ${yOf(v)}`)
    .join('');
  const negative = series[series.length - 1] < 0;

  return (
    <g>
      <path d={area} fill={negative ? PALETTE.down : PALETTE.up} opacity={0.45} />
      <path d={signalPath} fill="none" stroke={PALETTE.gold} strokeWidth={1.4} strokeDasharray="4 3" />
      <line x1={x} x2={x + width} y1={mid} y2={mid} stroke={PALETTE.grid} strokeWidth={1} />
      <text x={x + 6} y={PANEL.y + 16} fontSize={11} fill={PALETTE.textDim}>
        {card.momentum.velocityPctPerDay < 0 ? '▼' : '▲'}{' '}
        {card.momentum.velocityPctPerDay.toFixed(2)}%/d · a{' '}
        {card.momentum.acceleration.toFixed(2)}
      </text>
    </g>
  );
}

function IvTrace({ card, x, width }: { card: SetupCard; x: number; width: number }) {
  if (card.iv.now === null) {
    return (
      <text
        x={x + width / 2}
        y={PANEL.y + PANEL.h / 2}
        fontSize={12}
        fill={PALETTE.textDim}
        textAnchor="middle"
      >
        no options chain
      </text>
    );
  }
  // 只有当期与 5 日前两个点时，画一段直线示意方向
  const prior =
    card.iv.change5d !== null ? card.iv.now - card.iv.change5d / 100 : card.iv.now;
  const lo = Math.min(prior, card.iv.now) * 0.9;
  const hi = Math.max(prior, card.iv.now) * 1.1;
  const yOf = (v: number) =>
    PANEL.y + PANEL.h - ((v - lo) / (hi - lo || 1)) * (PANEL.h - 16) - 8;
  return (
    <g>
      <path
        d={`M${x + 8} ${yOf(prior)}L${x + width - 8} ${yOf(card.iv.now)}`}
        fill="none"
        stroke="#3fd0e8"
        strokeWidth={2}
      />
      <circle cx={x + width - 8} cy={yOf(card.iv.now)} r={3.5} fill="#3fd0e8" />
    </g>
  );
}

/* ------------------------------------------------------------------ */
/* 磁吸表 + 解读                                                        */
/* ------------------------------------------------------------------ */

const TABLE = { x: 44, y: 730, w: 630, rowH: 22 };

function MagnetTable({ rows }: { rows: MagnetRow[] }) {
  const cols = [0, 150, 260, 360];
  const roleColor: Record<MagnetRow['role'], string> = {
    stretch: PALETTE.stretch,
    resistance: PALETTE.resistance,
    last: PALETTE.text,
    sma20: PALETTE.sma,
    support: PALETTE.support,
    down: PALETTE.downLevel,
  };

  return (
    <g>
      <rect
        x={TABLE.x}
        y={TABLE.y}
        width={TABLE.w}
        height={TABLE.rowH * (rows.length + 1) + 6}
        fill={PALETTE.panel}
        stroke={PALETTE.grid}
      />
      {['MAGNET', 'PRICE', 'DIST', 'ROLE'].map((h, i) => (
        <text
          key={h}
          x={TABLE.x + cols[i] + (i === 0 ? 16 : 60)}
          y={TABLE.y + 17}
          fontSize={12}
          fontWeight={700}
          fill={PALETTE.textDim}
          textAnchor={i === 0 ? 'start' : i === 3 ? 'middle' : 'end'}
        >
          {h}
        </text>
      ))}
      <line
        x1={TABLE.x}
        x2={TABLE.x + TABLE.w}
        y1={TABLE.y + TABLE.rowH}
        y2={TABLE.y + TABLE.rowH}
        stroke={PALETTE.grid}
      />
      {rows.map((r, i) => {
        const y = TABLE.y + TABLE.rowH * (i + 2) - 5;
        return (
          <g key={r.role}>
            <text x={TABLE.x + 16} y={y} fontSize={12} fontWeight={700} fill={roleColor[r.role]}>
              {r.label}
            </text>
            <text x={TABLE.x + cols[1] + 60} y={y} fontSize={12} fill={PALETTE.text} textAnchor="end">
              {r.price.toFixed(2)}
            </text>
            <text x={TABLE.x + cols[2] + 60} y={y} fontSize={12} fill={PALETTE.text} textAnchor="end">
              {fmtPct(r.distancePct)}
            </text>
            <text x={TABLE.x + cols[3] + 130} y={y} fontSize={12} fill={PALETTE.textDim} textAnchor="middle">
              {r.description}
            </text>
          </g>
        );
      })}
    </g>
  );
}

/** 每个元素是一条 bullet 折好的若干行。 */
function TheRead({ lines }: { lines: string[][] }) {
  const x = 700;

  let row = 0;
  const rendered = lines.map((wrapped, i) => {
    const node = (
      <g key={i}>
        {wrapped.map((segment, j) => {
          const y = TABLE.y + 44 + row * READ_LINE_H;
          row += 1;
          return (
            <text
              key={j}
              x={j === 0 ? x : x + 10}
              y={y}
              fontSize={12}
              fill={PALETTE.text}
            >
              {j === 0 && <tspan fill={PALETTE.axis}>• </tspan>}
              {segment}
            </text>
          );
        })}
      </g>
    );
    return node;
  });

  return (
    <g>
      <text x={x} y={TABLE.y + 17} fontSize={15} fontWeight={700} fill={PALETTE.text}>
        ▣ THE READ
      </text>
      {rendered}
    </g>
  );
}

function wrapText(text: string, maxChars: number): string[] {
  const words = text.split(' ');
  const out: string[] = [];
  let line = '';
  for (const word of words) {
    if (line.length === 0) {
      line = word;
    } else if (line.length + 1 + word.length <= maxChars) {
      line += ` ${word}`;
    } else {
      out.push(line);
      line = word;
    }
  }
  if (line.length > 0) out.push(line);
  return out;
}

/* ------------------------------------------------------------------ */

function fmtPct(v: number): string {
  return `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`;
}

function pctFrom(base: number, target: number): number {
  return base === 0 ? 0 : ((target - base) / base) * 100;
}


export default SetupCardChart;
