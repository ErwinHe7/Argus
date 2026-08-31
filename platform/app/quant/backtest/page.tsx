import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowLeft, Workflow } from 'lucide-react';
import { BacktestConsole } from '@/components/quant/BacktestConsole';
import { STRATEGY_PRESETS } from '@/lib/quant/backtest';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 量化回测 · Walk-forward',
  description:
    'Walk-forward 单股回测控制台：选股票、选策略、选历史区间，得到对比 buy & hold 的净值曲线，手续费滑点都建模。',
};

// 中文策略说明
const STRATEGY_CN: Record<string, { label: string; description: string }> = {
  momentum_breakout: {
    label: '动量突破（Momentum Breakout）',
    description: 'price > SMA200 且过去 1 个月收益为正 时满仓；否则空仓。',
  },
  trend_sma_cross: {
    label: '趋势叠加（SMA 20 / 50 / 200）',
    description: 'SMA20 > SMA50 > SMA200（多头排列）时满仓；任意一根均线掉头就空仓。',
  },
  vol_target_trend: {
    label: '波动目标趋势（Vol-Targeted）',
    description: 'SMA50 > SMA200 时按 0.15 / 20日年化波动 计算仓位（上限 100%）。波动越大仓位越轻。',
  },
  mean_reversion_rsi: {
    label: 'RSI 均值回归',
    description: 'RSI(14) < 30 时买入；> 55 时平仓；中间区间持有当前仓位（不反手）。',
  },
  buy_and_hold: {
    label: '买入持有（基准）',
    description: '满仓一直拿。作为其它策略的对比基线。',
  },
};

export default function BacktestPage() {
  const strategies = STRATEGY_PRESETS.map((s) => ({
    id: s.id,
    label: STRATEGY_CN[s.id]?.label ?? s.label,
    description: STRATEGY_CN[s.id]?.description ?? s.description,
  }));

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
            href="/quant/scanner"
            className="inline-flex items-center gap-2 rounded-[6px] border border-emerald-400/60 bg-emerald-500/15 px-3 py-1.5 text-xs font-black tracking-[0.08em] text-emerald-100 hover:bg-emerald-500/25"
          >
            <Workflow className="h-3.5 w-3.5" /> 跑横截面扫描器 →
          </Link>
        </div>

        <header className="rounded-[8px] border border-slate-700 bg-gradient-to-br from-[#0b1120] to-[#080d1a] p-6">
          <p className="inline-flex items-center gap-2 rounded-[4px] border border-sky-400/40 bg-sky-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase tracking-[0.16em] text-sky-300">
            回测层 · Walk-Forward
          </p>
          <h1 className="mt-3 text-3xl font-black tracking-tight text-white">单股回测控制台</h1>
          <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-200">
            策略规则在 <span className="font-mono text-emerald-200">lib/quant/backtest.ts</span> 里全公开。
            每根 K 线<span className="text-white font-bold">只能看自己之前的数据</span>；
            前 200 根用来给 SMA200 暖机，不会被算进策略收益。
            每笔成交都扣 <span className="text-white">5 bps 手续费 + 5 bps 滑点</span>，让净值曲线更接近真实。
          </p>
        </header>

        <div className="mt-6">
          <BacktestConsole strategies={strategies} />
        </div>

        <footer className="mt-7 rounded-[6px] border border-slate-800 bg-black px-5 py-4 text-xs leading-7 text-slate-400">
          回测过得了，不等于实盘做得到。同一个策略在不同股票、不同时间窗里都要交叉验证；
          实际成本一般高于模型估计。研究工具，不构成投资建议。AXIO7 与 High-Flyer（幻方）无关联。
        </footer>
      </main>
    </div>
  );
}
