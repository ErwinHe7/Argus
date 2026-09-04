// 本地预览：把形态卡渲染成静态 HTML，方便肉眼核对版式。
// 用法：npx tsx scripts/render-setup-card-preview.tsx <输出路径.html>
// 只用合成数据，不打任何外部接口。

import { writeFileSync } from 'node:fs';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';

import { SetupCardChart } from '../components/market/SetupCardChart';
import { buildSetupCard, type Candle } from '../lib/quant/setup-card';

/** 确定性伪随机，保证每次预览一致。 */
function rng(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

/** 造一段「先冲高、再破位下行、末段箱体震荡」的行情。 */
function syntheticCandles(): Candle[] {
  const rand = rng(20260904);
  const closes: number[] = [];
  let price = 125;
  for (let i = 0; i < 190; i += 1) {
    let drift: number;
    if (i < 45) drift = 0.0018; // 冲高到 133
    else if (i < 105) drift = -0.0032; // 破位下行
    else drift = 0.0002; // 箱体
    const shock = (rand() - 0.5) * 0.022;
    price = price * (1 + drift + shock);
    closes.push(price);
  }
  // 末段做一根急跌，触发 KNIFE
  for (let i = 0; i < 6; i += 1) {
    price = price * (1 - 0.012 - i * 0.004);
    closes.push(price);
  }

  return closes.map((close, i) => {
    const prev = i === 0 ? close : closes[i - 1];
    const open = prev * (1 + (rand() - 0.5) * 0.006);
    const high = Math.max(open, close) * (1 + rand() * 0.009);
    const low = Math.min(open, close) * (1 - rand() * 0.009);
    const date = new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10);
    return {
      date,
      open,
      high,
      low,
      close,
      volume: Math.round(6_000_000 * (0.6 + rand() * 1.4)),
    };
  });
}

const card = buildSetupCard({
  symbol: 'WMT',
  candles: syntheticCandles(),
  atmIv: 0.23,
  atmIvPrior: 0.314,
  sector: { name: 'Defensive', changePct5d: -5.8 },
});

if (!card) {
  console.error('setup card did not build');
  process.exit(1);
}

const svg = renderToStaticMarkup(<SetupCardChart card={card} />);
const out = process.argv[2] || 'setup-card-preview.html';
writeFileSync(
  out,
  `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#0a0f1c">${svg}</body>`
);
console.log(`wrote ${out}`);
console.log(
  `last=${card.last.toFixed(2)} support=${card.levels.support.toFixed(
    2
  )} resistance=${card.levels.resistance.toFixed(
    2
  )} stretch=${card.levels.stretch.toFixed(2)} down=${card.levels.down.toFixed(2)}`
);
console.log(`state=${card.state} momentum=${card.momentum.state} rsi=${card.rsiNow?.toFixed(0)}`);
