import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowLeft, BookOpen, Brain, LineChart } from 'lucide-react';
import { MlLsConsole } from '@/components/quant/MlLsConsole';
import { ML_LS_FEATURES } from '@/lib/quant/ml-ls';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 量化 · ML 多空回测 (Voleon 风格)',
  description:
    '横截面 ML 长短股票回测: 多因子 + walk-forward + purge + 多空中性。复刻 Voleon 那一类"systematic ML quant"的最小骨架。',
};

export default function MlLsPage() {
  return (
    <div className="-mx-4 -mb-24 -mt-6 min-h-screen bg-[#f3eee5] px-4 pb-24 pt-0 text-slate-950 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <main className="mx-auto min-h-screen max-w-[1280px] bg-[#05070b] px-5 py-6 text-white shadow-2xl shadow-black/30 sm:px-8">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href="/quant"
            className="inline-flex items-center gap-2 text-xs font-black tracking-[0.08em] text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" /> 返回量化首页
          </Link>
          <Link
            href="/quant/backtest"
            className="inline-flex items-center gap-2 rounded-[6px] border border-sky-400/60 bg-sky-500/15 px-3 py-1.5 text-xs font-black tracking-[0.08em] text-sky-100 hover:bg-sky-500/25"
          >
            <LineChart className="h-3.5 w-3.5" /> 单股规则回测 →
          </Link>
        </div>

        <header className="rounded-[8px] border border-slate-700 bg-gradient-to-br from-[#1a0d2e] to-[#0c0a1f] p-7 shadow-xl shadow-black/30">
          <p className="inline-flex items-center gap-2 rounded-[4px] border border-violet-400/40 bg-violet-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase tracking-[0.18em] text-violet-200">
            <Brain className="h-3.5 w-3.5" />
            SYSTEMATIC ML LONG/SHORT · v0.1
          </p>
          <h1 className="mt-4 text-3xl font-black leading-tight tracking-tight text-white sm:text-4xl">
            横截面 <span className="text-violet-300">多因子多空</span> 回测
          </h1>
          <p className="mt-4 max-w-3xl text-base font-medium leading-7 text-slate-200">
            和左边那条<span className="font-mono text-sky-200">/quant/backtest</span>(单股、规则化、long/cash)不一样。
            这里是 Voleon / D.E. Shaw 那一类<span className="text-white font-bold">"systematic ML quant"</span>
            的最小骨架: 同一时刻把一篮子股票拉一起打分, 排名最高那批做多、最低那批做空,
            模型从历史里学每个因子值多少钱(rank-IC 加权), 每隔 h 天再平衡。
            数学透明 — 没有黑盒, 没有 LLM, 没有"AI 解盘"。
          </p>
          <div className="mt-5 grid gap-2 text-sm leading-7 text-slate-300 sm:grid-cols-2 lg:grid-cols-3">
            <FactCard color="violet" k="横截面" v="同一天打分排名 (相对强弱), 不押大盘方向" />
            <FactCard color="emerald" k="多空中性" v="多头 +0.5 / 空头 -0.5, 净敞口 ≈ 0" />
            <FactCard color="amber" k="Walk-forward" v="滚动训练窗 + purge, 杜绝 look-ahead" />
            <FactCard color="sky" k="标签" v="未来 h 日横截面去均值收益 (学相对涨跌)" />
            <FactCard color="rose" k="模型" v="rank-IC 加权合成 (白盒, 跑得快)" />
            <FactCard color="cyan" k="成本" v="按 |Δw| × bps 扣换手成本, 不假装零成本" />
          </div>
        </header>

        {/* ===== 因子总表 ===== */}
        <section className="mt-6 rounded-[8px] border border-slate-700 bg-[#0b1120] p-6">
          <p className="inline-flex items-center gap-2 font-mono text-[11px] font-black uppercase tracking-[0.16em] text-violet-300">
            <BookOpen className="h-3.5 w-3.5" /> 系统里装了哪 7 个因子
          </p>
          <h2 className="mt-2 text-xl font-black text-white">每一个都能在 lib/quant/ml-ls.ts 里看到公式</h2>
          <p className="mt-2 text-sm leading-7 text-slate-300">
            所有因子先按公式算原始值, 再做<span className="text-white font-bold">每日横截面 z-score</span>,
            最后用训练窗里的 rank-IC 加权合成 — 这是因子投资圈最经典的"白盒"组合方法。
          </p>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[700px] border-collapse text-left text-sm">
              <thead>
                <tr className="border-b border-slate-700 font-mono text-[10px] uppercase tracking-[0.12em] text-slate-400">
                  <th className="py-2 pr-3">因子</th>
                  <th className="py-2 pr-3">公式</th>
                  <th className="py-2">直觉</th>
                </tr>
              </thead>
              <tbody>
                {ML_LS_FEATURES.map((f) => (
                  <tr key={f.key} className="border-b border-slate-800">
                    <td className="py-2.5 pr-3">
                      <p className="font-black text-white">{f.label}</p>
                      <p className="font-mono text-[10px] text-slate-500">{f.key}</p>
                    </td>
                    <td className="py-2.5 pr-3 font-mono text-[11px] text-emerald-200">{f.formula}</td>
                    <td className="py-2.5 text-[12px] leading-6 text-slate-300">
                      {INTUITION[f.key] ?? '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <div className="mt-6">
          <MlLsConsole />
        </div>

        {/* ===== 坑 + 期望管理 ===== */}
        <section className="mt-7 rounded-[8px] border border-slate-700 bg-[#0b1120] p-6">
          <p className="font-mono text-[11px] font-black uppercase tracking-[0.16em] text-amber-300">
            老实写下来的限制
          </p>
          <h2 className="mt-2 text-lg font-black text-white">这版故意没做的事</h2>
          <ul className="mt-3 space-y-2 text-sm leading-7 text-slate-300">
            <li>
              <span className="text-white font-bold">没用 GBM / 神经网络。</span> 用的是 rank-IC 加权合成 —
              和因子投资圈几十年来的标准做法一致, 白盒、跑得快、TS 里不需要矩阵求逆。
              真要上 GBM, 应该在更好的数据 + 更多特征上再考虑。
            </li>
            <li>
              <span className="text-white font-bold">有幸存者偏差。</span> Yahoo 只给"今天还活着"的票,
              退市/破产的看不到 — 回测会偏乐观。要真做, 得用 CRSP / Compustat 这类含退市的数据库。
            </li>
            <li>
              <span className="text-white font-bold">没做行业/市值中性化。</span> 现在的多空组合可能集中
              在某个行业 (例如全做多科技股、做空银行股) — 真实组合需要约束。
            </li>
            <li>
              <span className="text-white font-bold">交易成本只算了换手 × bps。</span> 没建模冲击成本、没建模
              资金借贷成本 (做空要付 short rebate)。真实净收益会更低。
            </li>
            <li>
              <span className="text-white font-bold">很大概率 Sharpe 很低甚至为负。</span> 这是诚实的、典型的
              "免费日线 + 7 个简单因子"的结果。真正的 edge 在更好的数据 + 更细的特征 + 更严的成本控制里,
              而不是"换个更花哨的模型"。
            </li>
          </ul>
        </section>

        <footer className="mt-7 rounded-[6px] border border-slate-800 bg-black px-5 py-4 text-xs leading-7 text-slate-400">
          研究工具, 不构成投资建议。完整逻辑在 <span className="font-mono text-violet-200">lib/quant/ml-ls.ts</span>。
          所有数据来自 Yahoo Finance, 可能延迟或被修订。
        </footer>
      </main>
    </div>
  );
}

const INTUITION: Record<string, string> = {
  mom_21: '过去 1 个月跑赢同行的, 短期容易继续跑赢',
  mom_63: '中期动量, 抓持续性强的趋势',
  mom_126: '长期动量, 区分结构性赢家 vs 临时反弹',
  rev_5: '短期反转: 一周猛涨的, 接下来容易回调一点',
  vol_21: '高波动股票长期跑输 (低波动异象)',
  ma_gap: '偏离 50 日均线太远, 容易回归',
  vol_z: '近期成交量异动暗示关注度变化',
};

function FactCard({ color, k, v }: { color: 'violet' | 'emerald' | 'amber' | 'sky' | 'rose' | 'cyan'; k: string; v: string }) {
  const map: Record<string, string> = {
    violet: 'border-violet-400/40 bg-violet-500/10 text-violet-100',
    emerald: 'border-emerald-400/40 bg-emerald-500/10 text-emerald-100',
    amber: 'border-amber-400/40 bg-amber-500/10 text-amber-100',
    sky: 'border-sky-400/40 bg-sky-500/10 text-sky-100',
    rose: 'border-rose-400/40 bg-rose-500/10 text-rose-100',
    cyan: 'border-cyan-400/40 bg-cyan-500/10 text-cyan-100',
  };
  return (
    <div className={`rounded-[6px] border px-3 py-2 ${map[color]}`}>
      <p className="font-mono text-[10px] font-black uppercase tracking-[0.16em]">{k}</p>
      <p className="mt-0.5 text-[12px] leading-6 text-slate-200">{v}</p>
    </div>
  );
}
