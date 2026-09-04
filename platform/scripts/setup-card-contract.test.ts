// 形态卡计算层的契约测试 / Contract tests for the ZIG-ZAG setup card.
// 用合成序列锁住每个要素的口径，避免以后调参把卡面算错。
// 运行：npm run test:setup-card

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildRead,
  buildScenarioPaths,
  buildSetupCard,
  computeBollinger,
  computeMagnetProfile,
  computeMomentum,
  computeRsi,
  computeSma,
  computeZigZag,
  detectLevels,
  projectTargets,
  realizedVolatility,
  type Candle,
} from '../lib/quant/setup-card';

/** 造一根 K 线：围绕 close 生成合理的 OHLC。 */
function bar(date: string, close: number, volume = 1_000_000): Candle {
  return {
    date,
    open: close,
    high: close * 1.01,
    low: close * 0.99,
    close,
    volume,
  };
}

function seriesFrom(closes: number[], volumes?: number[]): Candle[] {
  return closes.map((c, i) => {
    const d = new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10);
    return bar(d, c, volumes?.[i] ?? 1_000_000);
  });
}

/** 一段清晰的箱体：在 100 和 120 之间来回四次。 */
function rangingCloses(): number[] {
  const out: number[] = [];
  for (let leg = 0; leg < 4; leg += 1) {
    const up = leg % 2 === 0;
    for (let i = 0; i < 20; i += 1) {
      const t = i / 19;
      out.push(up ? 100 + 20 * t : 120 - 20 * t);
    }
  }
  return out;
}

test('computeSma only emits values once the window is full', () => {
  const sma = computeSma([1, 2, 3, 4, 5], 3);
  assert.deepEqual(sma.slice(0, 2), [null, null]);
  assert.equal(sma[2], 2);
  assert.equal(sma[4], 4);
});

test('computeBollinger centres on the SMA and is symmetric', () => {
  const values = [10, 12, 11, 13, 14, 12, 15, 16];
  const bb = computeBollinger(values, 4, 2);
  const i = values.length - 1;
  const mid = bb.middle[i];
  assert.ok(mid !== null && bb.upper[i] !== null && bb.lower[i] !== null);
  assert.ok(Math.abs((bb.upper[i]! - mid!) - (mid! - bb.lower[i]!)) < 1e-9);
  assert.ok(bb.upper[i]! > mid!);
});

test('computeBollinger collapses to the mean when the series is flat', () => {
  const bb = computeBollinger([7, 7, 7, 7, 7, 7], 3, 2);
  const i = 5;
  assert.equal(bb.upper[i], 7);
  assert.equal(bb.lower[i], 7);
});

test('computeRsi pins to 100 on an unbroken advance and stays in bounds', () => {
  const rising = Array.from({ length: 40 }, (_, i) => 100 + i);
  const rsi = computeRsi(rising, 14);
  assert.equal(rsi[rsi.length - 1], 100);

  const falling = Array.from({ length: 40 }, (_, i) => 100 - i);
  const rsiDown = computeRsi(falling, 14);
  assert.equal(rsiDown[rsiDown.length - 1], 0);

  for (const v of rsi) if (v !== null) assert.ok(v >= 0 && v <= 100);
});

test('computeRsi returns nulls when the series is shorter than the period', () => {
  const rsi = computeRsi([1, 2, 3], 14);
  assert.equal(rsi.every((v) => v === null), true);
});

test('computeZigZag alternates highs and lows and labels the last two A/B', () => {
  const pivots = computeZigZag(seriesFrom(rangingCloses()), 4.5);
  assert.ok(pivots.length >= 4, `expected several pivots, got ${pivots.length}`);
  for (let i = 1; i < pivots.length; i += 1) {
    assert.notEqual(
      pivots[i].kind,
      pivots[i - 1].kind,
      'pivots must strictly alternate'
    );
  }
  assert.equal(pivots[pivots.length - 2].label, 'A');
  assert.equal(pivots[pivots.length - 1].label, 'B');
});

test('computeZigZag ignores wiggles below the threshold', () => {
  // ±1% 的噪声，阈值 10% —— 不该确认出中间枢轴
  const closes = Array.from({ length: 60 }, (_, i) =>
    100 + (i % 2 === 0 ? 1 : -1)
  );
  const pivots = computeZigZag(seriesFrom(closes), 10);
  assert.ok(pivots.length <= 1, `expected no confirmed pivots, got ${pivots.length}`);
});

test('computeMagnetProfile puts the point of control at the busiest price', () => {
  // 在 110 这一档堆很大的量，其他地方很小
  const closes = [...Array(30).fill(100), ...Array(30).fill(110)];
  const volumes = [...Array(30).fill(1), ...Array(30).fill(500)];
  const profile = computeMagnetProfile(seriesFrom(closes, volumes), 105, 40, 15);
  assert.ok(
    Math.abs(profile.pointOfControl - 110) < 2,
    `POC ${profile.pointOfControl} should sit near 110`
  );
  assert.ok(profile.maxVolume > 0);
});

test('computeMagnetProfile splits supply above and demand below last', () => {
  const profile = computeMagnetProfile(seriesFrom(rangingCloses()), 110, 40, 15);
  for (const b of profile.bins) {
    assert.equal(b.side, b.mid >= 110 ? 'supply' : 'demand');
  }
  assert.ok(profile.massBelow > 0 && profile.massAbove > 0);
});

test('computeMagnetProfile only counts the recent window as gold', () => {
  const profile = computeMagnetProfile(seriesFrom(rangingCloses()), 110, 40, 15);
  const total = profile.bins.reduce((s, b) => s + b.volume, 0);
  const recent = profile.bins.reduce((s, b) => s + b.recentVolume, 0);
  assert.ok(recent > 0);
  assert.ok(recent < total, 'recent volume must be a strict subset');
});

test('computeMomentum flags an accelerating decline as KNIFE', () => {
  // 跌幅逐日放大
  const closes: number[] = [100];
  for (let i = 1; i <= 40; i += 1) {
    closes.push(closes[i - 1] * (1 - 0.002 * i));
  }
  const m = computeMomentum(closes, 10);
  assert.equal(m.state, 'KNIFE');
  assert.ok(m.velocityPctPerDay < 0);
  assert.ok(m.acceleration < 0, 'still getting worse');
});

test('computeMomentum reads a steady drift as FLAT, not KNIFE', () => {
  const closes = Array.from({ length: 60 }, (_, i) => 100 + i * 0.01);
  const m = computeMomentum(closes, 10);
  assert.equal(m.state, 'FLAT');
});

test('computeMomentum degrades safely on a short series', () => {
  const m = computeMomentum([100, 101, 102], 10);
  assert.equal(m.state, 'FLAT');
  assert.deepEqual(m.series, []);
});

test('realizedVolatility is zero on a flat tape and positive on a noisy one', () => {
  assert.equal(realizedVolatility(Array(40).fill(100)), 0);
  const noisy = Array.from({ length: 40 }, (_, i) => 100 * (1 + (i % 2) * 0.03));
  assert.ok(realizedVolatility(noisy) > 0);
});

test('detectLevels brackets the last price', () => {
  const candles = seriesFrom(rangingCloses());
  const last = candles[candles.length - 1].close;
  const magnet = computeMagnetProfile(candles, last, 48, 15);
  const pivots = computeZigZag(candles, 4.5);
  const { resistance, support } = detectLevels(candles, magnet, pivots, last);
  assert.ok(resistance > last, `resistance ${resistance} must sit above ${last}`);
  assert.ok(support < last, `support ${support} must sit below ${last}`);
});

test('projectTargets always clears the range it is measured from', () => {
  const closes = rangingCloses();
  const last = closes[closes.length - 1];
  const { stretch, down } = projectTargets(last, closes, 120, 100, 10, 1);
  assert.ok(stretch > 120, 'stretch must clear resistance');
  assert.ok(down < 100, 'down must clear support');
});

test('projectTargets falls back to a fixed move when volatility is zero', () => {
  const flat = Array(60).fill(100);
  const { stretch, down } = projectTargets(100, flat, 101, 99, 10, 1);
  assert.ok(stretch > 101 && Number.isFinite(stretch));
  assert.ok(down < 99 && Number.isFinite(down));
});

test('buildScenarioPaths emits bull, base and bear anchored at last', () => {
  const paths = buildScenarioPaths(106.2, 120.71, 95.6, 111.93);
  assert.deepEqual(paths.map((p) => p.kind), ['bull', 'base', 'bear']);
  for (const p of paths) {
    assert.equal(p.points[0].price, 106.2);
    assert.equal(p.points[0].t, 0);
    assert.equal(p.points[p.points.length - 1].t, 1);
    assert.equal(p.points[p.points.length - 1].price, p.target);
  }
  assert.ok(paths[0].target > paths[2].target);
});

test('buildSetupCard returns null when there are not enough bars', () => {
  assert.equal(buildSetupCard({ symbol: 'X', candles: seriesFrom([1, 2, 3]) }), null);
});

test('buildSetupCard assembles every element of the card', () => {
  const card = buildSetupCard({
    symbol: 'WMT',
    candles: seriesFrom(rangingCloses()),
    atmIv: 0.23,
    atmIvPrior: 0.314,
    sector: { name: 'Defensive', changePct5d: -5.8 },
  });
  assert.ok(card, 'card should build');
  assert.equal(card!.symbol, 'WMT');
  assert.equal(card!.patternName, 'ZIG-ZAG');
  assert.equal(card!.patternQualifier, 'well-defined range');

  // 关键价位排序：down < support < last < resistance < stretch
  const l = card!.levels;
  assert.ok(l.down < l.support, 'down below support');
  assert.ok(l.support < card!.last, 'support below last');
  assert.ok(card!.last < l.resistance, 'last below resistance');
  assert.ok(l.resistance < l.stretch, 'resistance below stretch');

  // 表格是固定角色顺序，不是按价格排序
  assert.deepEqual(
    card!.rows.map((r) => r.role),
    ['stretch', 'resistance', 'last', 'sma20', 'support', 'down']
  );
  assert.equal(card!.rows.find((r) => r.role === 'last')!.distancePct, 0);

  // IV 变化按百分点算：23% - 31.4% = -8.4pts
  assert.ok(Math.abs(card!.iv.change5d! - -8.4) < 1e-6);

  assert.ok(card!.pivots.length >= 4);
  assert.ok(card!.magnet.bins.length > 0);
  assert.ok(card!.scenarios.length === 3);
  assert.ok(card!.read.length > 0);
  assert.ok(card!.volume.average > 0);
  assert.ok(card!.pressure.bottom + card!.pressure.top > 0);
});

test('SMA20 keeps its row position even when it prices above LAST', () => {
  // 一段下跌行情：收盘远低于 20 日均线，SMA20 价格高于 LAST
  const closes: number[] = [];
  for (let i = 0; i < 90; i += 1) closes.push(130 - i * 0.35);
  const card = buildSetupCard({ symbol: 'WMT', candles: seriesFrom(closes) });
  assert.ok(card);
  const sma = card!.rows.find((r) => r.role === 'sma20')!;
  assert.ok(sma.price > card!.last, 'this fixture must put SMA20 above LAST');
  assert.deepEqual(
    card!.rows.map((r) => r.role),
    ['stretch', 'resistance', 'last', 'sma20', 'support', 'down'],
    'role order is fixed regardless of price'
  );
});

test('buildSetupCard marks a thin tape as a forming range', () => {
  const closes = Array.from({ length: 40 }, (_, i) => 100 + i * 0.05);
  const card = buildSetupCard({ symbol: 'X', candles: seriesFrom(closes) });
  assert.ok(card);
  assert.equal(card!.patternQualifier, 'forming range');
});

test('buildRead warns about the knife and reports draining IV', () => {
  const closes: number[] = [100];
  for (let i = 1; i <= 60; i += 1) closes.push(closes[i - 1] * (1 - 0.002 * i));
  const card = buildSetupCard({
    symbol: 'WMT',
    candles: seriesFrom(closes),
    atmIv: 0.23,
    atmIvPrior: 0.314,
    sector: { name: 'Defensive', changePct5d: -5.8 },
  });
  assert.ok(card);
  const text = card!.read.join('\n');
  assert.match(text, /ACCELERATING/);
  assert.match(text, /falling-knife/);
  assert.match(text, /Headwind: Defensive is bleeding \(-5\.8% 5d\)/);
  assert.match(text, /draining — options getting cheaper/);
});

test('buildRead omits the IV and sector lines when those inputs are absent', () => {
  const card = buildSetupCard({
    symbol: 'X',
    candles: seriesFrom(rangingCloses()),
  });
  assert.ok(card);
  const text = card!.read.join('\n');
  assert.doesNotMatch(text, /ATM IV/);
  assert.doesNotMatch(text, /Headwind|Tailwind/);
  // 但区间那两条永远在
  assert.match(text, /is ranging between S /);
  assert.match(text, /Range plays/);
});

test('buildRead is driven by the card, so a rich card yields a full read', () => {
  const card = buildSetupCard({
    symbol: 'WMT',
    candles: seriesFrom(rangingCloses()),
    atmIv: 0.23,
    atmIvPrior: 0.2,
    sector: { name: 'Defensive', changePct5d: 1.2 },
  });
  assert.ok(card);
  const lines = buildRead(card!);
  assert.deepEqual(lines, card!.read);
  assert.match(lines.join('\n'), /Tailwind: Defensive is leading/);
  assert.match(lines.join('\n'), /building — options getting richer/);
});
