'use client';

import { useMemo, useState } from 'react';
import { Loader2, Play, Sigma, AlertTriangle } from 'lucide-react';

type Summary = {
  periodsCount: number;
  yearsApprox: number;
  annualizedReturnPct: number;
  annualizedVolPct: number;
  sharpe: number;
  maxDrawdownPct: number;
  meanIc: number;
  hitRatePct: number;
  avgTurnover: number;
  finalEquity: number;
  universeSize: number;
};

type EquityPoint = { date: string; equity: number };

type Period = {
  date: string;
  grossReturn: number;
  netReturn: number;
  turnover: number;
  ic: number;
  longs: string[];
  shorts: string[];
};

type FeatureWeight = { key: string; label: string; weight: number };

type ApiResponse = {
  range: string;
  asOf: string;
  fetchedMs: number;
  universeRequested: string[];
  universeFetched: string[];
  summary: Summary;
  equityCurve: EquityPoint[];
  periods: Period[];
  lastFeatureWeights: FeatureWeight[];
  config: {
    forwardDays: number;
    trainDays: number;
    quantile: number;
    costBpsPerSide: number;
  };
  universeUsed: string[];
  notes: string[];
};

const DEFAULT_UNIVERSE =
  'AAPL MSFT NVDA AMZN GOOGL META AVGO TSLA JPM BAC WFC GS XOM CVX COP UNH JNJ PFE PG KO PEP WMT HD DIS NFLX INTC AMD MU CRM ORCL';

export function MlLsConsole() {
  const [universe, setUniverse] = useState(DEFAULT_UNIVERSE);
  const [range, setRange] = useState<'2y' | '5y'>('5y');
  const [h, setH] = useState('5');
  const [trainDays, setTrainDays] = useState('504');
  const [quantile, setQuantile] = useState('0.2');
  const [cost, setCost] = useState('10');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ApiResponse | null>(null);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({
        universe: universe.trim(),
        range,
        h,
        train: trainDays,
        q: quantile,
        cost,
      });
      const res = await fetch(`/api/quant/ml-ls?${params.toString()}`, { cache: 'no-store' });
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

  return (
    <div className="space-y-6">
      <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-6">
        <p className="font-mono text-[11px] font-black uppercase tracking-[0.16em] text-violet-300">
          回测设置 · Walk-Forward Cross-Section
        </p>
        <h2 className="mt-2 text-xl font-black text-white">
          股票池 → 因子 → 滚动训练 → 多空组合
        </h2>
        <p className="mt-2 text-sm leading-7 text-slate-300">
          每隔 <span className="font-mono text-violet-200">h</span> 天再平衡一次:
          先用过去 <span className="font-mono text-violet-200">train</span> 天的横截面数据学每个因子的
          rank-IC 权重, 再用今天的横截面预测未来 h 天的相对强弱,
          排前 <span className="font-mono text-violet-200">q</span> 做多、排后 q 做空,
          美元中性等权。Purge 防泄漏: 训练样本的标签窗口必须在预测日之前已经闭合。
        </p>

        <div className="mt-5 grid gap-3 lg:grid-cols-6">
          <label className="block lg:col-span-6">
            <span className="font-mono text-[11px] font-black uppercase tracking-[0.12em] text-slate-400">
              股票池 (空格、逗号或换行分隔, 最多 40 只)
            </span>
            <textarea
              value={universe}
              onChange={(e) => setUniverse(e.target.value)}
              rows={3}
              className="mt-1.5 w-full rounded-[6px] border border-slate-700 bg-black px-3 py-2.5 font-mono text-sm font-black text-white focus:border-violet-400 focus:outline-none"
              spellCheck={false}
            />
          </label>
          <Knob label="历史区间" value={range} onChange={(v) => setRange(v as '2y' | '5y')} options={[['2y', '2 年'], ['5y', '5 年']]} />
          <Knob label="预测窗口 h (日)" value={h} onChange={setH} type="number" min={1} max={21} />
          <Knob label="训练窗口 (日)" value={trainDays} onChange={setTrainDays} type="number" min={60} max={1000} />
          <Knob label="多空分位 q" value={quantile} onChange={setQuantile} type="number" step="0.05" min={0.05} max={0.5} />
          <Knob label="成本 (bps/边)" value={cost} onChange={setCost} type="number" min={0} max={100} />
        </div>

        <div className="mt-5 flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={run}
            disabled={loading || !universe.trim()}
            className="inline-flex items-center gap-2 rounded-[6px] border border-violet-400/60 bg-violet-500/20 px-5 py-2.5 text-sm font-black uppercase tracking-[0.12em] text-violet-100 hover:bg-violet-500/30 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Play className="h-4 w-4" />}
            {loading ? '回测中 (拉数据 + 训练)…' : '运行回测'}
          </button>
          <span className="font-mono text-[11px] text-slate-400">
            7 个因子 · IC 加权合成 · 净值从 1.00 起步 (不是美元额)
          </span>
        </div>

        {error ? (
          <p className="mt-3 inline-flex items-center gap-2 rounded-[6px] border border-red-500/50 bg-red-500/10 px-3 py-2 text-sm text-red-200">
            <AlertTriangle className="h-4 w-4" /> {error}
          </p>
        ) : null}
      </section>

      {result ? <Results result={result} /> : null}
    </div>
  );
}

function Knob({
  label,
  value,
  onChange,
  type,
  min,
  max,
  step,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: 'number';
  min?: number;
  max?: number;
  step?: string;
  options?: Array<[string, string]>;
}) {
  return (
    <label className="block">
      <span className="font-mono text-[10px] font-black uppercase tracking-[0.12em] text-slate-400">
        {label}
      </span>
      {options ? (
        <select
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="mt-1.5 w-full rounded-[6px] border border-slate-700 bg-black px-3 py-2.5 font-mono text-sm font-black text-white focus:border-violet-400 focus:outline-none"
        >
          {options.map(([v, label]) => (
            <option key={v} value={v}>
              {label}
            </option>
          ))}
        </select>
      ) : (
        <input
          type={type ?? 'text'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          min={min}
          max={max}
          step={step}
          className="mt-1.5 w-full rounded-[6px] border border-slate-700 bg-black px-3 py-2.5 font-mono text-sm font-black text-white focus:border-violet-400 focus:outline-none"
        />
      )}
    </label>
  );
}

function Results({ result }: { result: ApiResponse }) {
  const s = result.summary;
  const lastPeriod = result.periods[result.periods.length - 1];
  const dropped = result.universeRequested.filter((t) => !result.universeFetched.includes(t));

  return (
    <>
      <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-6">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <div>
            <p className="font-mono text-[11px] font-black uppercase tracking-[0.16em] text-violet-300">
              回测结果 · 扣完成本
            </p>
            <h2 className="mt-1 text-2xl font-black text-white">
              {result.universeFetched.length} 只股票 · 每 {result.config.forwardDays} 天再平衡 ·{' '}
              {result.periods.length} 个调仓期
            </h2>
          </div>
          <p className="font-mono text-[11px] text-slate-400">
            约 {s.yearsApprox.toFixed(1)} 年 · 数据拉取 {(result.fetchedMs / 1000).toFixed(1)}s ·{' '}
            {result.range}
          </p>
        </div>

        <dl className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Metric
            label="年化收益 (净)"
            value={pct(s.annualizedReturnPct)}
            tone={s.annualizedReturnPct >= 0 ? 'pos' : 'neg'}
          />
          <Metric
            label="年化波动"
            value={pct(s.annualizedVolPct)}
            tone="neutral"
          />
          <Metric
            label="Sharpe (rf=0)"
            value={s.sharpe.toFixed(2)}
            tone={s.sharpe > 0.5 ? 'pos' : s.sharpe < 0 ? 'neg' : 'neutral'}
          />
          <Metric
            label="最大回撤"
            value={pct(s.maxDrawdownPct)}
            tone={s.maxDrawdownPct <= -20 ? 'neg' : 'neutral'}
          />
          <Metric
            label="Mean IC"
            value={s.meanIc.toFixed(3)}
            tone={s.meanIc > 0 ? 'pos' : 'neg'}
            note="预测排名 vs 实现收益排名 · Spearman"
          />
          <Metric
            label="胜率 (期数)"
            value={`${s.hitRatePct.toFixed(0)}%`}
            tone="neutral"
          />
          <Metric
            label="平均换手 (Σ|Δw|)"
            value={s.avgTurnover.toFixed(2)}
            tone="neutral"
            note={`成本 ${result.config.costBpsPerSide} bps/边`}
          />
          <Metric
            label="终值 (起点 1.00)"
            value={s.finalEquity.toFixed(3)}
            tone={s.finalEquity >= 1 ? 'pos' : 'neg'}
          />
        </dl>

        {result.notes.length > 0 ? (
          <ul className="mt-4 space-y-1.5">
            {result.notes.map((n, i) => (
              <li
                key={i}
                className="rounded-[6px] border border-amber-400/40 bg-amber-500/10 px-3 py-2 text-[12px] leading-6 text-amber-100"
              >
                ⚠ {n}
              </li>
            ))}
          </ul>
        ) : null}

        {dropped.length > 0 ? (
          <p className="mt-3 text-[11px] text-slate-500">
            Yahoo 没回数据或历史过短, 跳过: {dropped.join(', ')}
          </p>
        ) : null}
      </section>

      <EquityChart curve={result.equityCurve} />
      <FeatureWeights weights={result.lastFeatureWeights} />
      <IcChart periods={result.periods} />

      {lastPeriod ? (
        <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
          <h3 className="text-base font-black text-white">最近一次再平衡 · {lastPeriod.date}</h3>
          <p className="mt-1 font-mono text-[11px] text-slate-400">
            预测排名最高/最低各 {lastPeriod.longs.length} 只 (top/bottom {(result.config.quantile * 100).toFixed(0)}%)
          </p>
          <div className="mt-3 grid gap-3 md:grid-cols-2">
            <Bucket title="多头" tone="emerald" names={lastPeriod.longs} />
            <Bucket title="空头" tone="red" names={lastPeriod.shorts} />
          </div>
          <p className="mt-3 text-[11px] text-slate-500">
            研究输出, 不是下单建议。实盘前还差: 流动性筛选 · 行业/市值中性 · 容量分析 · paper trading。
          </p>
        </section>
      ) : null}
    </>
  );
}

function EquityChart({ curve }: { curve: EquityPoint[] }) {
  if (curve.length < 2) return null;
  const w = 920;
  const h = 320;
  const pad = { left: 60, right: 16, top: 16, bottom: 32 };

  const values = curve.map((p) => p.equity);
  const yMax = Math.max(...values, 1.0);
  const yMin = Math.min(...values, 1.0);
  const padY = Math.max(0.01, (yMax - yMin) * 0.05);
  const lo = yMin - padY;
  const hi = yMax + padY;

  const xs = (i: number) => pad.left + ((w - pad.left - pad.right) * i) / Math.max(1, curve.length - 1);
  const ys = (v: number) => pad.top + ((h - pad.top - pad.bottom) * (hi - v)) / Math.max(1e-9, hi - lo);

  const path = curve
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${xs(i).toFixed(2)} ${ys(p.equity).toFixed(2)}`)
    .join(' ');

  // 基准线: equity = 1.0
  const baseY = ys(1.0);

  const yTicks = 4;
  const ticks = Array.from({ length: yTicks + 1 }, (_, i) => lo + ((hi - lo) * i) / yTicks);

  return (
    <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h3 className="text-base font-black text-white">净值曲线 · 起点 1.00 · 扣完成本</h3>
        <div className="flex items-center gap-4 font-mono text-[11px] text-slate-300">
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block h-2 w-5 rounded bg-violet-300" /> 多空净值
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block h-2 w-5 rounded bg-slate-500" /> 1.00 起点线
          </span>
        </div>
      </div>
      <div className="mt-3 overflow-x-auto">
        <svg viewBox={`0 0 ${w} ${h}`} className="w-full" style={{ minWidth: w / 1.3, maxWidth: '100%' }}>
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
                {t.toFixed(2)}
              </text>
            </g>
          ))}
          <line x1={pad.left} x2={w - pad.right} y1={baseY} y2={baseY} stroke="#475569" strokeWidth={1} />
          <path d={path} fill="none" stroke="#c4b5fd" strokeWidth={2} />
          <text x={pad.left} y={h - 10} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="start">
            {curve[0].date}
          </text>
          <text x={w - pad.right} y={h - 10} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="end">
            {curve[curve.length - 1].date}
          </text>
        </svg>
      </div>
    </section>
  );
}

function FeatureWeights({ weights }: { weights: FeatureWeight[] }) {
  const maxAbs = Math.max(...weights.map((w) => Math.abs(w.weight)), 1e-6);
  return (
    <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
      <h3 className="inline-flex items-center gap-2 text-base font-black text-white">
        <Sigma className="h-4 w-4 text-violet-300" /> 最新训练窗口内的因子 IC (= 合成权重)
      </h3>
      <p className="mt-1 text-[11px] text-slate-400">
        每个因子在训练窗内的平均 rank-IC。正 = 高分股票后续相对涨, 负 = 高分股票后续相对跌。
      </p>
      <div className="mt-3 space-y-2">
        {weights.map((w) => {
          const pctW = (Math.abs(w.weight) / maxAbs) * 100;
          const pos = w.weight >= 0;
          return (
            <div key={w.key} className="grid grid-cols-[160px_1fr_70px] items-center gap-3">
              <span className="font-mono text-[12px] text-slate-200">{w.label}</span>
              <div className="flex items-center">
                {!pos ? (
                  <div className="flex w-1/2 justify-end pr-1">
                    <div
                      className="h-3 rounded-l bg-red-400/70"
                      style={{ width: `${pctW}%` }}
                    />
                  </div>
                ) : (
                  <div className="w-1/2" />
                )}
                <span className="h-3 w-px bg-slate-600" />
                {pos ? (
                  <div className="flex w-1/2 justify-start pl-1">
                    <div
                      className="h-3 rounded-r bg-emerald-400/70"
                      style={{ width: `${pctW}%` }}
                    />
                  </div>
                ) : (
                  <div className="w-1/2" />
                )}
              </div>
              <span className={`text-right font-mono text-[12px] font-black ${pos ? 'text-emerald-300' : 'text-red-300'}`}>
                {w.weight >= 0 ? '+' : ''}{w.weight.toFixed(3)}
              </span>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function IcChart({ periods }: { periods: Period[] }) {
  if (periods.length < 2) return null;
  const w = 920;
  const h = 180;
  const pad = { left: 60, right: 16, top: 12, bottom: 28 };

  const maxAbs = Math.max(...periods.map((p) => Math.abs(p.ic)), 0.05);
  const xs = (i: number) => pad.left + ((w - pad.left - pad.right) * i) / Math.max(1, periods.length - 1);
  const midY = pad.top + (h - pad.top - pad.bottom) / 2;
  const yScale = (h - pad.top - pad.bottom) / 2 / maxAbs;
  const ys = (v: number) => midY - v * yScale;

  return (
    <section className="rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
      <h3 className="text-base font-black text-white">每期 IC (预测排名 vs 实现收益排名)</h3>
      <p className="mt-1 text-[11px] text-slate-400">
        正值 = 那期预测对了相对强弱方向。在 0 附近上下飘是正常的; 持续偏正 = 模型有 edge。
      </p>
      <div className="mt-3 overflow-x-auto">
        <svg viewBox={`0 0 ${w} ${h}`} className="w-full" style={{ minWidth: w / 1.3, maxWidth: '100%' }}>
          <line x1={pad.left} x2={w - pad.right} y1={midY} y2={midY} stroke="#475569" strokeWidth={1} />
          {periods.map((p, i) => {
            const bx = xs(i);
            const by = ys(p.ic);
            const barH = Math.abs(by - midY);
            const top = p.ic >= 0 ? by : midY;
            const fill = p.ic >= 0 ? '#34d399' : '#f87171';
            return (
              <rect
                key={i}
                x={bx - 1.5}
                y={top}
                width={3}
                height={barH}
                fill={fill}
                opacity={0.85}
              />
            );
          })}
          <text x={pad.left - 8} y={midY + 4} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="end">
            0
          </text>
          <text x={pad.left - 8} y={pad.top + 10} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="end">
            +{maxAbs.toFixed(2)}
          </text>
          <text x={pad.left - 8} y={h - pad.bottom} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="end">
            -{maxAbs.toFixed(2)}
          </text>
          <text x={pad.left} y={h - 8} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="start">
            {periods[0].date}
          </text>
          <text x={w - pad.right} y={h - 8} fontSize={11} fontFamily="monospace" fill="#94a3b8" textAnchor="end">
            {periods[periods.length - 1].date}
          </text>
        </svg>
      </div>
    </section>
  );
}

function Bucket({
  title,
  tone,
  names,
}: {
  title: string;
  tone: 'emerald' | 'red';
  names: string[];
}) {
  const border = tone === 'emerald' ? 'border-emerald-400/40 bg-emerald-500/10' : 'border-red-400/40 bg-red-500/10';
  const text = tone === 'emerald' ? 'text-emerald-200' : 'text-red-200';
  return (
    <div className={`rounded-[6px] border ${border} p-3`}>
      <p className={`font-mono text-[10px] font-black uppercase tracking-[0.16em] ${text}`}>{title}</p>
      <div className="mt-2 flex flex-wrap gap-1.5">
        {names.map((n) => (
          <span
            key={n}
            className="rounded-[4px] border border-slate-700 bg-black px-2 py-1 font-mono text-[11px] font-black text-white"
          >
            {n}
          </span>
        ))}
      </div>
    </div>
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
  const toneClass = tone === 'pos' ? 'text-emerald-300' : tone === 'neg' ? 'text-red-300' : 'text-white';
  return (
    <div className="rounded-[6px] border border-slate-700 bg-[#070b16] px-4 py-3">
      <p className="font-mono text-[11px] font-black tracking-[0.06em] text-slate-400">{label}</p>
      <p className={`mt-2 font-mono text-2xl font-black ${toneClass}`}>{value}</p>
      {note ? <p className="mt-1 font-mono text-[10px] text-slate-500">{note}</p> : null}
    </div>
  );
}

function pct(v: number): string {
  if (!Number.isFinite(v)) return '—';
  return `${v >= 0 ? '+' : ''}${v.toFixed(2)}%`;
}
