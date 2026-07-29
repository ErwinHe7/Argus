import type { Metadata } from 'next';
import Link from 'next/link';
import {
  ArrowLeft,
  BarChart3,
  Database,
  LockKeyhole,
  ShieldCheck,
} from 'lucide-react';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export const metadata: Metadata = {
  title: 'AXIO7 多因子影子模型',
  description:
    '40% 动量、20% 流动性代理、40% 市场状态与量价因子的独立研究候选。',
};

const groups = [
  {
    weight: '40%',
    title: '动量',
    detail: '只使用观测截止时点已经完成的价格与成交量窗口。',
  },
  {
    weight: '20%',
    title: '流动性代理',
    detail: '当前定义是 OHLCV 成交额代理；没有报价数据时不声称价差、深度或冲击成本。',
  },
  {
    weight: '40%',
    title: 'Regime-conditioned PV',
    detail: '用因果市场状态门控量价因子，避免把同一个 regime 常数当作横截面信号。',
  },
] as const;

const blockers = [
  '将获授权的 point-in-time 股票池、复权日线、退市与公司行动数据绑定到不可变清单',
  '完成 purged walk-forward、成本、换手、容量、负向对照和 untouched holdout',
  '完成真实 forward-shadow，并由人工审核精确 artifact hash',
  '把通过验证的 Rust 服务接入网站；在此之前不发布排名或概率',
] as const;

export default function ScannerPage() {
  return (
    <main className="min-h-screen bg-[#07090d] px-5 py-8 text-slate-100 sm:px-8">
      <div className="mx-auto max-w-5xl">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link
            href="/quant"
            className="inline-flex items-center gap-2 text-sm font-semibold text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" />
            返回量化研究
          </Link>
          <span className="rounded-full border border-amber-400/40 bg-amber-400/10 px-3 py-1 text-xs font-bold tracking-wide text-amber-200">
            SHADOW · CANDIDATE_NOT_PROMOTED
          </span>
        </div>

        <section className="mt-6 rounded-2xl border border-slate-700 bg-gradient-to-br from-slate-900 to-[#0a0e17] p-6 sm:p-8">
          <div className="flex items-start gap-4">
            <div className="rounded-xl border border-sky-400/30 bg-sky-400/10 p-3 text-sky-200">
              <BarChart3 className="h-6 w-6" />
            </div>
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.14em] text-sky-300">
                独立多因子研究模型
              </p>
              <h1 className="mt-2 text-3xl font-black tracking-tight">
                排名暂未公开：验证仍在进行
              </h1>
              <p className="mt-3 max-w-3xl text-base leading-7 text-slate-300">
                旧页面使用 Yahoo 数据并在 TypeScript 中即时计算，无法证明授权、时点一致性或完整覆盖，
                因此已经停止。新版本由 Rust 生成确定性研究排名；缺失、过期或未授权数据会整体失败关闭，
                不会跳过标的后继续展示一个看似完整的榜单。
              </p>
            </div>
          </div>
        </section>

        <section className="mt-6 grid gap-4 md:grid-cols-3">
          {groups.map((group) => (
            <article
              key={group.title}
              className="rounded-xl border border-slate-700 bg-slate-900/70 p-5"
            >
              <p className="text-3xl font-black text-white">{group.weight}</p>
              <h2 className="mt-2 text-lg font-bold text-sky-200">{group.title}</h2>
              <p className="mt-2 text-sm leading-6 text-slate-400">{group.detail}</p>
            </article>
          ))}
        </section>

        <section className="mt-6 rounded-xl border border-slate-700 bg-slate-900/70 p-6">
          <div className="flex items-center gap-3">
            <LockKeyhole className="h-5 w-5 text-amber-300" />
            <h2 className="text-xl font-bold">公开前必须完成</h2>
          </div>
          <ol className="mt-4 space-y-3 text-sm leading-6 text-slate-300">
            {blockers.map((blocker, index) => (
              <li key={blocker} className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-slate-800 text-xs font-bold text-sky-200">
                  {index + 1}
                </span>
                <span>{blocker}</span>
              </li>
            ))}
          </ol>
        </section>

        <section className="mt-6 grid gap-4 sm:grid-cols-2">
          <article className="rounded-xl border border-emerald-400/30 bg-emerald-400/5 p-5">
            <ShieldCheck className="h-5 w-5 text-emerald-300" />
            <h2 className="mt-3 font-bold">输出边界</h2>
            <p className="mt-2 text-sm leading-6 text-slate-300">
              仅输出研究分数、因子贡献、数据时点和限制；不输出 BUY/SELL、目标仓位或订单。
            </p>
          </article>
          <article className="rounded-xl border border-violet-400/30 bg-violet-400/5 p-5">
            <Database className="h-5 w-5 text-violet-300" />
            <h2 className="mt-3 font-bold">当前可用功能</h2>
            <p className="mt-2 text-sm leading-6 text-slate-300">
              日内 HMM / SDE / kernel 模型的实时研究入口保持独立。它不会被这个影子模型的验证状态阻塞。
            </p>
            <Link
              href="/"
              className="mt-4 inline-flex rounded-lg border border-violet-300/40 bg-violet-300/10 px-3 py-2 text-sm font-bold text-violet-100 hover:bg-violet-300/20"
            >
              打开 AXIO7 Research
            </Link>
          </article>
        </section>

        <p className="mt-6 text-xs leading-5 text-slate-500">
          这是非个性化市场研究，不构成投资建议。自动执行始终关闭。
        </p>
      </div>
    </main>
  );
}
