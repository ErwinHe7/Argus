import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowLeft, ShieldCheck, TrendingDown, TrendingUp } from 'lucide-react';
import { buildTickerConsoleReport } from '@/lib/market-intelligence/ticker-console';
import { TickerStrategyBoard } from '@/components/market/TickerStrategyBoard';
import { TickerOptionsAnalytics } from '@/components/market/TickerOptionsAnalytics';
import { TickerProbabilityDistribution } from '@/components/market/TickerProbabilityDistribution';
import { InstitutionalHoldingsPanel } from '@/components/market/InstitutionalHoldingsPanel';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: { params: { symbol: string } }): Promise<Metadata> {
  const sym = params.symbol.toUpperCase();
  return {
    title: `${sym} · AXIO7 Ticker Console`,
    description: `Real-time market intelligence for ${sym}: news catalysts, options chain, Max Pain, Gamma exposure, lognormal probability, strategy candidates.`,
  };
}

export default async function TickerPage({ params }: { params: { symbol: string } }) {
  const symbol = params.symbol.toUpperCase();
  const report = await buildTickerConsoleReport(symbol);

  const quote = report.quote;
  const changeTone = quote?.changePct !== null && quote && quote.changePct >= 0 ? 'text-emerald-300' : 'text-red-300';

  return (
    <div className="-mx-4 -mb-24 -mt-6 space-y-5 bg-[#05070b] px-4 pb-24 pt-6 text-white sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Link
          href="/market"
          className="inline-flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-300 hover:text-white"
        >
          <ArrowLeft className="h-4 w-4" /> 返回 Market Console
        </Link>
        <Link
          href={`/market/intel/${symbol}`}
          className="inline-flex items-center gap-2 rounded-[6px] border border-blue-400/60 bg-blue-500/20 px-3 py-1.5 text-xs font-black uppercase tracking-[0.14em] text-blue-100 hover:bg-blue-500/30"
        >
          Smart Money Intel · Probability + Max Pain + 13F →
        </Link>
      </div>

      <header className="rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/40">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.16em] text-slate-300">Ticker Console</p>
            <h1 className="mt-1 font-mono text-5xl font-black tracking-tight text-white">${symbol}</h1>
            <p className="mt-2 text-sm text-slate-200">{quote?.name || '名称未知'}</p>
          </div>
          <div className="text-right">
            {quote?.price !== null && quote?.price !== undefined ? (
              <>
                <p className="font-mono text-4xl font-black text-white">{quote.price.toFixed(2)}</p>
                <p className={`mt-1 inline-flex items-center justify-end gap-1 font-mono text-sm font-black ${changeTone}`}>
                  {quote.changePct !== null && quote.changePct >= 0 ? (
                    <TrendingUp className="h-4 w-4" />
                  ) : (
                    <TrendingDown className="h-4 w-4" />
                  )}
                  {quote.change !== null ? `${quote.change >= 0 ? '+' : ''}${quote.change.toFixed(2)}` : '—'} ·{' '}
                  {quote.changePct !== null ? `${quote.changePct >= 0 ? '+' : ''}${quote.changePct.toFixed(2)}%` : '—'}
                </p>
                <p className="mt-1 text-[10px] text-slate-400">{quote.asOf ? new Date(quote.asOf).toLocaleString() : ''}</p>
              </>
            ) : (
              <p className="text-sm text-slate-300">暂无可靠报价</p>
            )}
          </div>
        </div>

        <dl className="mt-5 grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <Tile label="RSI(14)" value={fmt(quote?.rsi14, 1)} />
          <Tile label="SMA20" value={fmt(quote?.sma20)} />
          <Tile label="SMA50" value={fmt(quote?.sma50)} />
          <Tile label="SMA200" value={fmt(quote?.sma200)} />
          <Tile label="距 200DMA" value={pct(quote?.deviation200Pct)} tone={toneNum(quote?.deviation200Pct)} />
          <Tile label="5d / 1m" value={`${pct(quote?.change5dPct)} / ${pct(quote?.change1mPct)}`} />
        </dl>

        {quote?.note ? (
          <p className="mt-4 border-t border-slate-800 pt-3 text-sm leading-6 text-slate-100">{quote.note}</p>
        ) : null}
      </header>

      {quote?.price && quote.price > 0 ? (
        <TickerProbabilityDistribution
          ticker={symbol}
          defaultSpot={quote.price}
          defaultTarget={
            report.options?.maxPain?.maxPainStrike ??
            report.priceDistribution?.oneSigmaLow ??
            quote.price
          }
          defaultIvAnnual={
            report.options?.probability?.ivAtm ??
            report.priceDistribution?.annualizedVolatility ??
            0.3
          }
          defaultExpiration={
            report.options?.probability?.expiration ??
            report.priceDistribution?.expiration ??
            nextFridayISO()
          }
          volatilitySource={
            report.options?.probability?.ivAtm
              ? 'options_iv'
              : report.priceDistribution?.source === 'historical_volatility'
                ? 'historical_volatility'
                : 'historical_volatility'
          }
          volatilitySourceLabel={
            report.options?.probability?.ivAtm
              ? `Live options ATM IV (${report.options.provider})`
              : 'Historical volatility fallback, not live options IV'
          }
        />
      ) : null}

      <TickerOptionsAnalytics options={report.options} />

      <InstitutionalHoldingsPanel ticker={symbol} />

      <TickerStrategyBoard report={report} />

      <section className="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-5">
          <NewsCard newsItems={report.news} />
          <MacroContextCard series={report.macroExcerpt} />
          <InsiderCard insider={report.insider} />
        </div>

        <div className="space-y-5">
          <ReliabilityCard reliability={report.reliability} errors={report.errors} />
        </div>
      </section>

      <footer className="rounded-[8px] border border-slate-700 bg-slate-900 p-4 text-xs leading-6 text-slate-300">
        {report.disclaimer}
      </footer>
    </div>
  );
}

function PriceDistributionCard({ distribution }: { distribution: TickerConsoleReportDistribution }) {
  if (!distribution) {
    return (
      <section className="rounded-[10px] border border-slate-700 bg-slate-900 p-6">
        <h2 className="text-xl font-black text-white">价格概率分布</h2>
        <p className="mt-2 text-sm text-slate-200">暂无可靠历史价格或期权 IV，无法生成概率分布。</p>
      </section>
    );
  }

  const maxDensity = Math.max(...distribution.points.map((point) => point.probabilityDensity), 0.000001);
  const sparsePoints = distribution.points.filter((_, index) => index % 2 === 0);

  return (
    <section className="rounded-[10px] border border-blue-400/40 bg-slate-900 p-6 shadow-2xl shadow-blue-950/30">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-[0.16em] text-blue-200">
            Probability Distribution · {distribution.source === 'options_iv' ? 'Option IV' : 'Historical Vol Fallback'}
          </p>
          <h2 className="mt-1 text-2xl font-black text-white">本周价格概率区间</h2>
          <p className="mt-2 max-w-4xl text-sm leading-6 text-slate-200">{distribution.narrative}</p>
        </div>
        <div className="grid grid-cols-2 gap-2 text-right sm:grid-cols-4">
          <MiniStat label="Spot" value={distribution.spot.toFixed(2)} />
          <MiniStat label="1σ 区间" value={`${distribution.oneSigmaLow.toFixed(2)} - ${distribution.oneSigmaHigh.toFixed(2)}`} />
          <MiniStat label="Expected Move" value={`±${distribution.expectedMove.toFixed(2)} (${distribution.expectedMovePct.toFixed(1)}%)`} />
          <MiniStat label="Vol" value={`${(distribution.annualizedVolatility * 100).toFixed(1)}%`} />
        </div>
      </div>

      <div className="rounded-[8px] border border-slate-700 bg-black p-4">
        <div className="flex h-40 items-end gap-1 overflow-hidden border-b border-slate-700 pb-2">
          {sparsePoints.map((point) => {
            const height = Math.max(3, (point.probabilityDensity / maxDensity) * 130);
            const isCenter = Math.abs(point.price - distribution.spot) / distribution.spot < 0.01;
            const within1Sigma =
              point.price >= distribution.oneSigmaLow && point.price <= distribution.oneSigmaHigh;
            return (
              <div
                key={point.price.toFixed(4)}
                title={`${point.price.toFixed(2)} · CDF ${(point.cumulativeProbability * 100).toFixed(1)}%`}
                className={`min-w-[5px] flex-1 rounded-t transition ${
                  isCenter
                    ? 'bg-blue-300'
                    : within1Sigma
                      ? 'bg-blue-500/60'
                      : 'bg-slate-600'
                }`}
                style={{ height }}
              />
            );
          })}
        </div>
        <div className="mt-2 flex justify-between font-mono text-[10px] text-slate-400">
          <span>{distribution.points[0]?.price.toFixed(2)}</span>
          <span className="text-blue-300">spot {distribution.spot.toFixed(2)}</span>
          <span>{distribution.points.at(-1)?.price.toFixed(2)}</span>
        </div>
      </div>

      <div className="mt-4 grid gap-2 sm:grid-cols-5">
        {distribution.levels.map((level) => (
          <div key={level.label} className="rounded-[6px] border border-slate-700 bg-slate-950 p-3">
            <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{level.label}</p>
            <p className="mt-1 font-mono text-base font-black text-white">{level.price.toFixed(2)}</p>
            <p className="mt-1 text-xs text-slate-200">
              高于 <span className="font-mono text-emerald-300">{(level.probabilityAbove * 100).toFixed(1)}%</span>
            </p>
          </div>
        ))}
      </div>

      <ul className="mt-4 space-y-1 border-t border-slate-800 pt-3 text-xs leading-5 text-slate-300">
        {distribution.caveats.map((caveat) => (
          <li key={caveat}>• {caveat}</li>
        ))}
      </ul>
    </section>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[6px] border border-slate-700 bg-slate-950 px-3 py-2 text-left">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{label}</p>
      <p className="mt-1 font-mono text-sm font-black text-white">{value}</p>
    </div>
  );
}

function Tile({ label, value, tone }: { label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-[6px] border border-slate-700 bg-slate-950 p-3">
      <p className="text-[10px] font-black uppercase tracking-[0.12em] text-slate-300">{label}</p>
      <p className={`mt-1 font-mono text-base font-black ${tone || 'text-white'}`}>{value}</p>
    </div>
  );
}

function NewsCard({ newsItems }: { newsItems: TickerConsoleReportNews }) {
  const manualCount = newsItems.filter((n) => n.source === 'manual').length;
  return (
    <article className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-xl shadow-black/30">
      <header className="mb-3 flex items-center justify-between gap-2">
        <h2 className="text-lg font-black text-white">新闻 Resource / Catalyst Feed</h2>
        {manualCount > 0 ? (
          <span className="inline-flex items-center gap-1 rounded border border-amber-400/50 bg-amber-500/20 px-2 py-0.5 text-[10px] font-black uppercase tracking-wider text-amber-100">
            {manualCount} manual
          </span>
        ) : null}
      </header>
      {newsItems.length === 0 ? (
        <p className="text-sm leading-6 text-slate-200">
          免费源当前没有命中该 ticker。回到 <a href="/market" className="text-blue-300 underline-offset-4 hover:underline">/market</a> 用 Catalyst Intake 粘贴一条 X / Truth / Reuters / 官方公告，事件会自动出现在这里（写入 Supabase 持久化）。
        </p>
      ) : (
        <ul className="space-y-3">
          {newsItems.map((item) => (
            <li
              key={item.id}
              className={`rounded-[6px] border bg-black p-3 ${item.source === 'manual' ? 'border-amber-400/40' : 'border-slate-800'}`}
            >
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0 flex-1">
                  {item.url ? (
                    <a
                      href={item.url}
                      target="_blank"
                      rel="noreferrer"
                      className="font-bold text-white underline-offset-4 hover:underline"
                    >
                      {item.title}
                    </a>
                  ) : (
                    <p className="font-bold text-white">{item.title}</p>
                  )}
                  <p className="mt-1 text-[11px] font-mono text-slate-400">
                    {item.source === 'manual' ? (
                      <span className="text-amber-200">
                        MANUAL · {item.manualSourceType?.replace(/_/g, ' ') ?? 'other'}
                      </span>
                    ) : (
                      item.source.toUpperCase()
                    )}
                    {' · '}
                    {new Date(item.publishedAt).toLocaleString()}{' '}
                    {item.tone !== undefined ? `· tone ${item.tone.toFixed(2)}` : ''}
                    {item.source === 'manual' && item.materialityScore !== undefined
                      ? ` · M${item.materialityScore}/C${item.confidence}`
                      : ''}
                  </p>
                </div>
                {item.source === 'manual' && item.sentiment ? (
                  <span
                    className={`shrink-0 rounded border px-1.5 py-0.5 text-[10px] font-black uppercase ${
                      item.sentiment === 'bullish'
                        ? 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100'
                        : item.sentiment === 'bearish'
                          ? 'border-red-400/50 bg-red-500/20 text-red-100'
                          : item.sentiment === 'mixed'
                            ? 'border-amber-400/50 bg-amber-500/20 text-amber-100'
                            : 'border-slate-600 bg-slate-800 text-slate-200'
                    }`}
                  >
                    {item.sentiment}
                  </span>
                ) : null}
              </div>
            </li>
          ))}
        </ul>
      )}
      <p className="mt-3 border-t border-slate-800 pt-3 text-xs leading-5 text-slate-300">
        免费源：Hacker News / GDELT。
        <span className="text-amber-200">手动粘贴</span>事件持久化到 Supabase，14 天内自动出现在此 ticker 的 catalyst feed。
        Reuters/LSEG、X official、Truth provider 配上后进同一条 evidence chain。
      </p>
    </article>
  );
}

function MacroContextCard({ series }: { series: Array<{ id: string; title: string; latest: number | null; unit: string; interpretation: string }> }) {
  if (!series.length) {
    return (
      <article className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-xl shadow-black/30">
        <h2 className="mb-2 text-lg font-black text-white">宏观环境 · FRED</h2>
        <p className="text-sm text-slate-300">暂无可靠数据。</p>
      </article>
    );
  }
  return (
    <article className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-xl shadow-black/30">
      <h2 className="mb-3 text-lg font-black text-white">宏观环境 · FRED</h2>
      <ul className="grid gap-2 sm:grid-cols-2">
        {series.map((s) => (
          <li key={s.id} className="rounded-[6px] border border-slate-800 bg-black p-3">
            <p className="text-[10px] font-mono uppercase tracking-[0.12em] text-slate-400">{s.id}</p>
            <p className="text-sm font-black text-white">{s.title}</p>
            <p className="font-mono text-base font-black text-blue-200">
              {s.latest !== null ? s.latest.toFixed(2) : '—'}
              {s.unit && !['index', ''].includes(s.unit) ? ` ${s.unit}` : ''}
            </p>
            <p className="mt-1 text-xs leading-5 text-slate-300">{s.interpretation}</p>
          </li>
        ))}
      </ul>
    </article>
  );
}

function InsiderCard({ insider }: { insider: { ticker: string; totalFilings90d: number; latest: { filedAt: string; primaryDocDescription: string; url: string } | null } | null }) {
  if (!insider) {
    return (
      <article className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-xl shadow-black/30">
        <h2 className="mb-2 text-lg font-black text-white">SEC Form 4 内部人</h2>
        <p className="text-sm text-slate-300">该 ticker 暂无 CIK 映射或近期没有 Form 4。</p>
      </article>
    );
  }
  return (
    <article className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-xl shadow-black/30">
      <h2 className="mb-3 text-lg font-black text-white">SEC Form 4 内部人</h2>
      <p className="text-sm text-slate-200">
        近 90 日 <strong className="font-mono text-2xl font-black text-white">{insider.totalFilings90d}</strong> 笔 Form 4 申报。
      </p>
      {insider.latest ? (
        <p className="mt-2 text-sm text-slate-300">
          最新申报 {insider.latest.filedAt}：
          <a href={insider.latest.url} target="_blank" rel="noreferrer" className="ml-1 text-blue-300 underline-offset-4 hover:underline">
            {insider.latest.primaryDocDescription}
          </a>
        </p>
      ) : null}
      <p className="mt-2 text-[11px] leading-5 text-slate-400">
        Form 4 是高管/董事/10%+ 股东买卖申报。频率不等于方向，但密集申报常出现在重要 catalyst 前后。
      </p>
    </article>
  );
}

function ReliabilityCard({ reliability, errors }: { reliability: Record<string, string>; errors: string[] }) {
  return (
    <article className="rounded-[10px] border border-slate-700 bg-slate-900 p-5 shadow-xl shadow-black/30">
      <h2 className="mb-3 flex items-center gap-2 text-lg font-black text-white">
        <ShieldCheck className="h-5 w-5 text-blue-300" /> 数据可靠性
      </h2>
      <ul className="grid grid-cols-2 gap-2 text-xs">
        {Object.entries(reliability).map(([k, v]) => (
          <li key={k} className="flex items-center justify-between rounded border border-slate-800 bg-black px-3 py-2">
            <span className="font-mono text-slate-300">{k}</span>
            <span
              className={`font-mono font-black ${
                v === 'ok' ? 'text-emerald-300' : v === 'partial' ? 'text-blue-300' : 'text-slate-400'
              }`}
            >
              {v}
            </span>
          </li>
        ))}
      </ul>
      {errors.length > 0 ? (
        <details className="mt-3 rounded border border-slate-800 bg-black p-2 text-xs">
          <summary className="cursor-pointer text-slate-300">查看错误 ({errors.length})</summary>
          <ul className="mt-2 space-y-1 text-[11px] text-slate-400">
            {errors.map((e, i) => (
              <li key={i}>• {e}</li>
            ))}
          </ul>
        </details>
      ) : null}
    </article>
  );
}

function nextFridayISO(): string {
  const d = new Date();
  const dow = d.getUTCDay();
  const add = (5 - dow + 7) % 7 || 7;
  d.setUTCDate(d.getUTCDate() + add);
  return d.toISOString().slice(0, 10);
}

function fmt(v: number | null | undefined, digits = 2): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '—';
  return v.toFixed(digits);
}

function pct(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '—';
  return `${v >= 0 ? '+' : ''}${v.toFixed(2)}%`;
}

function toneNum(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return 'text-slate-300';
  if (v > 0) return 'text-emerald-300';
  if (v < 0) return 'text-red-300';
  return 'text-blue-300';
}

type TickerConsoleReportNews = Awaited<ReturnType<typeof buildTickerConsoleReport>>['news'];
type TickerConsoleReportDistribution = Awaited<ReturnType<typeof buildTickerConsoleReport>>['priceDistribution'];
