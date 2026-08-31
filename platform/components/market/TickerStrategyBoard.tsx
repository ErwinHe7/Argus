import { Sparkles, ShieldAlert, Target } from 'lucide-react';
import type { TickerConsoleReport, TickerStrategyCandidate } from '@/lib/market-intelligence/ticker-console';

export function TickerStrategyBoard({ report }: { report: TickerConsoleReport }) {
  if (!report.strategyCandidates.length) {
    return (
      <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-xl shadow-black/30">
        <header className="mb-3 flex items-center gap-2">
          <Sparkles className="h-5 w-5 text-amber-300" />
          <h2 className="text-xl font-black text-white">期权策略候选</h2>
        </header>
        <p className="text-sm leading-6 text-slate-200">
          当前期权链不可达或没有足够 strikes 生成策略候选。请稍后再试，或在 /market Manual Event 面板手动粘贴催化新闻后再回到此页。
        </p>
      </section>
    );
  }

  return (
    <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-xl shadow-black/30">
      <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Sparkles className="h-5 w-5 text-amber-300" />
          <h2 className="text-xl font-black text-white">期权策略候选 · 基于实时 OI 与 Max Pain</h2>
        </div>
        <p className="text-[11px] text-slate-300">
          fitScore 越高越契合当前 setup，仅用于分析方向参考，不构成投资建议。
        </p>
      </header>

      <div className="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        {report.strategyCandidates.map((c) => (
          <CandidateCard key={c.id} candidate={c} />
        ))}
      </div>
    </section>
  );
}

function CandidateCard({ candidate }: { candidate: TickerStrategyCandidate }) {
  const biasTone =
    candidate.bias === 'bullish' ? 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100' :
    candidate.bias === 'bearish' ? 'border-red-400/50 bg-red-500/20 text-red-100' :
    candidate.bias === 'neutral' ? 'border-blue-400/50 bg-blue-500/20 text-blue-100' :
    'border-amber-400/50 bg-amber-500/20 text-amber-100';

  return (
    <article className="flex flex-col rounded-[8px] border border-slate-700 bg-slate-950 p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h3 className="text-base font-black text-white">{candidate.label}</h3>
          <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{candidate.type}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <span className={`inline-flex items-center rounded-[6px] border px-2 py-0.5 text-[10px] font-black uppercase ${biasTone}`}>
            {candidate.bias}
          </span>
          <span className="inline-flex items-center gap-1 rounded-[6px] border border-slate-600 bg-black px-2 py-0.5 text-[10px] font-mono font-black text-slate-100">
            <Target className="h-3 w-3" /> fit {candidate.fitScore}
          </span>
        </div>
      </div>

      <dl className="mt-4 grid grid-cols-1 gap-3 text-xs">
        <div>
          <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">交易腿</dt>
          <dd className="mt-1 font-mono text-sm font-black text-white">
            {candidate.legs.map((l, i) => (
              <span key={i} className="mr-2">
                {l.side === 'BUY' ? '+' : '-'}
                {l.qty} {l.strike}
                {l.right}
              </span>
            ))}
          </dd>
        </div>
        <div>
          <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">逻辑</dt>
          <dd className="mt-1 text-sm leading-5 text-slate-100">{candidate.rationale}</dd>
        </div>
        <div>
          <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">失效条件</dt>
          <dd className="mt-1 text-sm leading-5 text-amber-100">{candidate.invalidation}</dd>
        </div>
        <div>
          <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">Breakevens</dt>
          <dd className="mt-1 font-mono text-sm font-black text-white">
            {candidate.breakevens.length ? candidate.breakevens.map((b) => b.toFixed(2)).join(' / ') : '—'}
          </dd>
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="rounded-[6px] border border-slate-700 bg-black p-2.5">
            <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">Max Profit</dt>
            <dd className="mt-1 font-mono text-sm font-black text-emerald-300">
              {candidate.maxProfit !== null ? `$${candidate.maxProfit.toFixed(0)}` : '需真实 premium'}
            </dd>
          </div>
          <div className="rounded-[6px] border border-slate-700 bg-black p-2.5">
            <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">Max Loss</dt>
            <dd className="mt-1 font-mono text-sm font-black text-red-300">
              {candidate.maxLoss !== null ? `$${candidate.maxLoss.toFixed(0)}` : '需真实 premium'}
            </dd>
          </div>
        </div>
        {candidate.riskNotes.length ? (
          <div>
            <dt className="flex items-center gap-1 font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">
              <ShieldAlert className="h-3 w-3 text-red-300" /> 风险
            </dt>
            <dd>
              <ul className="mt-1 space-y-1 text-xs leading-5 text-slate-200">
                {candidate.riskNotes.map((r) => (
                  <li key={r}>• {r}</li>
                ))}
              </ul>
            </dd>
          </div>
        ) : null}
      </dl>

      <p className="mt-4 border-t border-slate-800 pt-3 text-[10px] leading-4 text-slate-400">
        若标记为模型估计，代表当前没有可靠实时期权报价；必须在券商/Polygon/OPRA 复核 bid/ask、OI 和成交量后才能用于实际仓位。
      </p>
    </article>
  );
}
