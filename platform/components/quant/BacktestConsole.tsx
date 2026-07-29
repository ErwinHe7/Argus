'use client';

import { useState } from 'react';
import { Loader2, Play, TrendingUp } from 'lucide-react';

type StrategyOption = {
  id: string;
  label: string;
  description: string;
};

type EquityPoint = {
  t: number;
  date: string;
  price: number;
  position: number;
  equity: number;
  benchmark: number;
};

type Summary = {
  ticker: string;
  strategy: string;
  bars: number;
  totalReturnPct: number;
  benchmarkReturnPct: number;
  alphaPct: number;
  cagrPct: number;
  maxDrawdownPct: number;
  sharpe: number;
  hitRate: number;
  tradeCount: number;
  exposurePct: number;
};

type Trade = {
  date: string;
  side: 'BUY' | 'SELL';
  price: number;
  shares: number;
  notional: number;
  reason: string;
};

type ApiResponse = {
  symbol: string;
  strategy: string;
  range: string;
  asOf: string | null;
  currentPrice: number | null;
  summary: Summary;
  equity: EquityPoint[];
  trades: Trade[];
};

export function BacktestConsole({ strategies }: { strategies: StrategyOption[] }) {
  const [symbol, setSymbol] = useState('NVDA');
  const [strategy, setStrategy] = useState('trend_sma_cross');
  const [range, setRange] = useState<'1y' | '2y' | '5y'>('2y');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ApiResponse | null>(null);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      const sym = symbol.trim().toUpperCase().replace(/^\$/, '');
      const res = await fetch(
        `/api/quant/backtest?symbol=${encodeURIComponent(sym)}&strategy=${strategy}&range=${range}`,
        { cache: 'no-store' }
      );
      const json = (await res.json()) as ApiResponse | { error: string };
      if (!res.ok || 'error' in json) {
        const msg = 'error' in json ? json.error : `HTTP ${res.status}`;
        setError(msg);
        setResult(null);
      } else {
        setResult(json);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '请求失败');
      setResult(null);
    } finally {
      setLoading(false);
    }
  }

  const activeStrategy = strategies.find((s) => s.id === strategy);

  return (
    <div className="space-y-6">
      <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-6">
        <p className="font-mono text-[11px] font-black uppercase tracking-[0.16em] text-emerald-300">
          回测设置
        </p>
        <h2 className="mt-2 text-xl font-black text-white">
          选股票 → 选策略 → 选历史区间
        </h2>

        <div className="mt-5 grid gap-3 lg:grid-cols-4">
          <label className="block">
            <span className="font-mono text-[11px] font-black uppercase tracking-[0.12em] text-slate-400">
              股票代码
            </span>
            <input
              value={symbol}
              onChange={(e) => setSymbol(e.target.value)}
              className="mt-1.5 w-full rounded-[6px] border border-slate-700 bg-black px-3 py-2.5 font-mono text-base font-black text-white focus:border-emerald-400 focus:outline-none"
              placeholder="NVDA"
              spellCheck={false}
            />
          </label>
          <label className="block lg:col-span-2">
            <span className="font-mono text-[11px] font-black uppercase tracking-[0.12em] text-slate-400">
              策略
            </span>
            <select
              value={strategy}
              onChange={(e) => setStrategy(e.target.value)}
              className="mt-1.5 w-full rounded-[6px] border border-slate-700 bg-black px-3 py-2.5 font-mono text-sm font-black text-white focus:border-emerald-400 focus:outline-none"
            >
              {strategies.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="font-mono text-[11px] font-black uppercase tracking-[0.12em] text-slate-400">
              历史区间
            </span>
            <select
              value={range}
              onChange={(e) => setRange(e.target.value as '1y' | '2y' | '5y')}
              className="mt-1.5 w-full rounded-[6px] border border-slate-700 bg-black px-3 py-2.5 font-mono text-sm font-black text-white focus:border-emerald-400 focus:outline-none"
            >
              <option value="1y">1 年</option>
              <option value="2y">2 年</option>
              <option value="5y">5 年</option>
            </select>
          </label>
        </div>

        {activeStrategy ? (
          <p className="mt-4 rounded-[6px] border border-slate-700 bg-[#070b16] px-4 py-2.5 text-sm leading-7 text-slate-300">
            <span className="font-mono text-[11px] font-black uppercase tracking-[0.12em] text-slate-500">
              策略规则 ·{' '}
            </span>
            {activeStrategy.description}
          </p>
        ) : null}

        <div className="mt-5 flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={run}
            disabled={loading || !symbol.trim()}
            className="inline-flex items-center gap-2 rounded-[6px] border border-emerald-400/60 bg-emerald-500/20 px-5 py-2.5 text-sm font-black uppercase tracking-[0.12em] text-emerald-100 hover:bg-emerald-500/30 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Play className="h-4 w-4" />
            )}
            运行回测
          </button>
          <span className="font-mono text-[11px] text-slate-400">
            初始资金 $100,000 · 手续费 5 bps · 滑点 5 bps
          </span>
        </div>

        {error ? (
          <p className="mt-3 rounded-[6px] border border-red-500/50 bg-red-500/10 px-3 py-2 text-sm text-red-200">
            {error}
          </p>
        ) : null}
      </section>

      {result ? <Results result={result} strategies={strategies} /> : null}
    </div>
  );
}

function Results({ result, strategies }: { result: ApiResponse; strategies: StrategyOption[] }) {
  const s = result.summary;
  const stratLabel = strategies.find((x) => x.id === result.strategy)?.label ?? result.strategy;
  return (
    <>
      <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-6">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <div>
            <p className="font-mono text-[11px] font-black uppercase tracking-[0.16em] text-emerald-300">
              回测结果
            </p>
            <h2 className="mt-1 text-2xl font-black text-white">
              {result.symbol} · {stratLabel}
            </h2>
          </div>
          <p className="font-mono text-[11px] text-slate-400">
            {s.bars} 根 K 线 · {result.range} 区间 · 最新数据{' '}
            {result.asOf ? new Date(result.asOf).toLocaleDateString('zh-CN') : '—'}
          </p>
        </div>

        <dl className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Metric
            label="策略总收益"
            value={pct(s.totalReturnPct)}
            tone={s.totalReturnPct >= 0 ? 'pos' : 'neg'}
          />
          <Metric
            label="VS 买入持有"
            value={pct(s.alphaPct)}
            tone={s.alphaPct >= 0 ? 'pos' : 'neg'}
            note={`基准（buy & hold）${pct(s.benchmarkReturnPct)}`}
          />
          <Metric label="CAGR 年化" value={pct(s.cagrPct)} tone={s.cagrPct >= 0 ? 'pos' : 'neg'} />
          <Metric
            label="最大回撤"
            value={pct(s.maxDrawdownPct)}
            tone={s.maxDrawdownPct <= -20 ? 'neg' : 'neutral'}
          />
          <Metric label="Sharpe 比率" value={s.sharpe.toFixed(2)} tone="neutral" />
          <Metric label="胜率" value={`${(s.hitRate * 100).toFixed(0)}%`} tone="neutral" />
          <Metric label="交易次数" value={s.tradeCount.toString()} tone="neutral" />
          <Metric label="持仓时间占比" value={`${s.exposurePct.toFixed(0)}%`} tone="neutral" />
        </dl>
      </section>

      <EquityChart equity={result.equity} symbol={result.symbol} />

      {result.trades.length > 0 ? (
        <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
          <h3 className="text-base font-black text-white">交易日志（{result.trades.length} 笔）</h3>
          <div className="mt-3 max-h-80 overflow-y-auto rounded-[6px] border border-slate-800">
            <table className="w-full border-collapse text-left text-[12px]">
              <thead className="sticky top-0 bg-[#0b1120]">
                <tr className="border-b border-slate-700 font-mono text-[10px] uppercase tracking-[0.08em] text-slate-400">
                  <th className="px-3 py-2.5">日期</th>
                  <th className="px-3 py-2.5">方向</th>
                  <th className="px-3 py-2.5 text-right">成交价</th>
                  <th className="px-3 py-2.5 text-right">股数</th>
                  <th className="px-3 py-2.5 text-right">名义金额</th>
                  <th className="px-3 py-2.5">触发条件</th>
                </tr>
              </thead>
              <tbody className="text-slate-200">
                {result.trades.map((t, i) => (
                  <tr key={`${t.date}-${i}`} className="border-b border-slate-800">
                    <td className="px-3 py-2 font-mono">{t.date}</td>
                    <td
                      className={`px-3 py-2 font-mono font-black ${
                        t.side === 'BUY' ? 'text-emerald-300' : 'text-red-300'
                      }`}
                    >
                      {t.side === 'BUY' ? '买入' : '卖出'}
                    </td>
                    <td className="px-3 py-2 text-right font-mono">{t.price.toFixed(2)}</td>
                    <td className="px-3 py-2 text-right font-mono">{t.shares.toFixed(2)}</td>
                    <td className="px-3 py-2 text-right font-mono">
                      ${t.notional.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                    </td>
                    <td className="px-3 py-2 text-slate-300">{t.reason}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}
    </>
  );
}

function Metric({
  label,
  value,
  tone,
  note,
}: {
  label: string;
  value: string;
  tone: 'pos' | 'neg' | 'neutral';
  note?: string;
}) {
  const toneClass =
    tone === 'pos' ? 'text-emerald-300' : tone === 'neg' ? 'text-red-300' : 'text-white';
  return (
    <div className="rounded-[6px] border border-slate-700 bg-[#070b16] px-4 py-3">
      <p className="font-mono text-[11px] font-black tracking-[0.06em] text-slate-400">
        {label}
      </p>
      <p className={`mt-2 font-mono text-2xl font-black ${toneClass}`}>{value}</p>
      {note ? <p className="mt-1 font-mono text-[10px] text-slate-500">{note}</p> : null}
    </div>
  );
}

function EquityChart({ equity, symbol }: { equity: EquityPoint[]; symbol: string }) {
  if (equity.length < 2) return null;

  const view = equity.filter((p) => p.equity > 0);
  if (view.length < 2) return null;
  const minDate = view[0].date;
  const maxDate = view[view.length - 1].date;

  const yMax = Math.max(...view.map((p) => Math.max(p.equity, p.benchmark)));
  const yMin = Math.min(...view.map((p) => Math.min(p.equity, p.benchmark)));
  const padY = (yMax - yMin) * 0.05;
  const lo = yMin - padY;
  const hi = yMax + padY;

  const w = 920;
  const h = 320;
  const pad = { left: 60, right: 16, top: 16, bottom: 32 };

  const xs = (i: number) =>
    pad.left + ((w - pad.left - pad.right) * i) / Math.max(1, view.length - 1);
  const ys = (v: number) =>
    pad.top + ((h - pad.top - pad.bottom) * (hi - v)) / Math.max(1, hi - lo);

  const stratPath = view
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${xs(i).toFixed(2)} ${ys(p.equity).toFixed(2)}`)
    .join(' ');
  const benchPath = view
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${xs(i).toFixed(2)} ${ys(p.benchmark).toFixed(2)}`)
    .join(' ');

  const yTicks = 4;
  const ticks = Array.from({ length: yTicks + 1 }, (_, i) => lo + ((hi - lo) * i) / yTicks);

  return (
    <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h3 className="text-base font-black text-white">净值曲线 · {symbol}</h3>
        <div className="flex items-center gap-4 font-mono text-[11px] text-slate-300">
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block h-2 w-5 rounded bg-emerald-300" /> 策略净值
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block h-2 w-5 rounded bg-slate-400" /> 买入持有
          </span>
        </div>
      </div>
      <div className="mt-3 overflow-x-auto">
        <svg
          viewBox={`0 0 ${w} ${h}`}
          className="w-full"
          style={{ minWidth: w / 1.3, maxWidth: '100%' }}
        >
          {ticks.map((t, i) => (
            <g key={i}>
              <line
                x1={pad.left}
                x2={w - pad.right}
                y1={ys(t)}
                y2={ys(t)}
                stroke="#1e293b"
                strokeDasharray="2 4"
              />
              <text
                x={pad.left - 8}
                y={ys(t) + 4}
                fontSize={11}
                fontFamily="monospace"
                fill="#94a3b8"
                textAnchor="end"
              >
                ${(t / 1000).toFixed(0)}k
              </text>
            </g>
          ))}
          <path d={benchPath} fill="none" stroke="#94a3b8" strokeWidth={1.6} />
          <path d={stratPath} fill="none" stroke="#34d399" strokeWidth={2} />
          <text
            x={pad.left}
            y={h - 10}
            fontSize={11}
            fontFamily="monospace"
            fill="#94a3b8"
            textAnchor="start"
          >
            {minDate}
          </text>
          <text
            x={w - pad.right}
            y={h - 10}
            fontSize={11}
            fontFamily="monospace"
            fill="#94a3b8"
            textAnchor="end"
          >
            {maxDate}
          </text>
        </svg>
      </div>
      <p className="mt-2 inline-flex items-center gap-1.5 text-xs text-slate-300">
        <TrendingUp className="h-3.5 w-3.5 text-emerald-300" />
        绿色 = 策略把 $100k 跑成多少；灰色 = 同一时间起点的买入持有作为对比。
      </p>
    </section>
  );
}

function pct(v: number): string {
  if (!Number.isFinite(v)) return '—';
  return `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`;
}
