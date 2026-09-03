import type { Metadata } from 'next';
import Link from 'next/link';
import {
  ArrowLeft,
  BarChart3,
  Database,
  ExternalLink,
  Gauge,
  Info,
  Rocket,
  Scale,
  Wallet,
} from 'lucide-react';
import {
  spaceFundamentals,
  spaceFundamentalSources,
  type SpaceCompanyFundamentals,
  type SpaceFundamentalMetric,
} from '@/lib/market-intelligence/space-fundamentals';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 Space Fundamentals',
  description: 'RKLB, ASTS, PL and SpaceX IPO fundamental comparison dashboard.',
};

type MetricKey = keyof SpaceCompanyFundamentals['metrics'];

const publicCompanies = spaceFundamentals.filter((company) => company.status === 'public');
const chartCompanies = spaceFundamentals;

export default function SpaceFundamentalsPage() {
  return (
    <div className="-mx-4 -mb-24 -mt-6 min-h-screen bg-[#eef1f4] px-4 pb-24 pt-0 text-slate-950 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
      <main className="mx-auto min-h-screen max-w-[1320px] bg-[#06080d] px-5 py-6 text-white shadow-2xl shadow-black/25 sm:px-8">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href="/market"
            className="inline-flex items-center gap-2 text-xs font-black text-slate-300 hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" /> Back to market
          </Link>
          <Link
            href="/api/market/space-fundamentals"
            className="inline-flex items-center gap-2 rounded-[6px] border border-slate-600 bg-slate-900 px-3 py-1.5 text-xs font-black text-slate-200 hover:bg-slate-800"
          >
            <Database className="h-3.5 w-3.5" /> JSON API
          </Link>
        </div>

        <header className="border border-slate-700 bg-[#111827] p-6">
          <p className="inline-flex items-center gap-2 border border-cyan-400/40 bg-cyan-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase text-cyan-200">
            <Rocket className="h-3.5 w-3.5" /> Space fundamentals
          </p>
          <div className="mt-4 grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
            <div>
              <h1 className="text-3xl font-black text-white sm:text-4xl">
                RKLB / ASTS / PL 基本面图表对比
              </h1>
              <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-200">
                把公开航天股和 SpaceX IPO 招股书放在同一张研究台上：收入规模、估值倍数、现金和订单、
                盈利质量分开看。SpaceX 是招股书参考，不当成已上市股票直接交易比较。
              </p>
            </div>
            <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-1">
              <HeroMetric label="public tickers" value="RKLB ASTS PL" />
              <HeroMetric label="IPO reference" value="SPCX / SpaceX" />
              <HeroMetric label="snapshot" value="2026-06-04" />
            </div>
          </div>
        </header>

        <section className="mt-5 grid gap-4 lg:grid-cols-4">
          {publicCompanies.map((company) => (
            <CompanySnapshot key={company.symbol} company={company} />
          ))}
          <CompanySnapshot company={spaceFundamentals.find((company) => company.symbol === 'SPCX')!} />
        </section>

        <section className="mt-5 grid gap-5 xl:grid-cols-2">
          <ChartPanel
            icon={<BarChart3 className="h-4 w-4" />}
            title="经营规模"
            description="TTM/年度收入。SpaceX 量级明显更大，所以公开小票要看增速和订单兑现，而不是只看规模。"
            companies={chartCompanies}
            metricKey="ttmRevenue"
          />
          <ChartPanel
            icon={<Scale className="h-4 w-4" />}
            title="估值倍数"
            description="P/S 越高，市场为每 1 美元收入付的钱越多。三只公开股 PE 都不可用，因为 GAAP 仍亏损。"
            companies={publicCompanies}
            metricKey="psRatio"
            riskHigh
          />
          <ChartPanel
            icon={<Wallet className="h-4 w-4" />}
            title="现金与订单"
            description="现金/流动性决定 runway，backlog/RPO 决定未来收入可见度。ASTS 钱最多，RKLB/PL 订单可见度更直接。"
            companies={chartCompanies}
            metricKey="cashLiquidity"
            secondaryMetricKey="backlog"
          />
          <ChartPanel
            icon={<Gauge className="h-4 w-4" />}
            title="盈利质量"
            description="Adjusted EBITDA 和 FCF 更适合看经营拐点；净利润受研发、折旧、认股权证公允价值等影响很大。"
            companies={chartCompanies}
            metricKey="adjustedEbitda"
            secondaryMetricKey="freeCashFlow"
            allowNegative
          />
        </section>

        <section className="mt-5 border border-slate-700 bg-[#0b1120] p-5">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-slate-400">
                <Info className="h-3.5 w-3.5 text-amber-200" /> metric table
              </p>
              <h2 className="mt-2 text-xl font-black text-white">核心基本面明细</h2>
            </div>
            <p className="max-w-xl text-xs leading-6 text-slate-400">
              `n/a` 不是缺陷：亏损成长股的 PE 没有解释力，应该用 P/S、EV/Sales、现金 runway、订单和收入兑现速度。
            </p>
          </div>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[1180px] border-collapse text-left text-[12px]">
              <thead>
                <tr className="border-b border-slate-700 font-mono text-[10px] uppercase text-slate-400">
                  <th className="px-2 py-2.5">Company</th>
                  <th className="px-2 py-2.5 text-right">Mkt Cap</th>
                  <th className="px-2 py-2.5 text-right">Revenue</th>
                  <th className="px-2 py-2.5 text-right">Growth</th>
                  <th className="px-2 py-2.5 text-right">Gross Margin</th>
                  <th className="px-2 py-2.5 text-right">P/S</th>
                  <th className="px-2 py-2.5 text-right">EV/Sales</th>
                  <th className="px-2 py-2.5 text-right">Cash</th>
                  <th className="px-2 py-2.5 text-right">Backlog/RPO</th>
                  <th className="px-2 py-2.5 text-right">Adj EBITDA</th>
                  <th className="px-2 py-2.5 text-right">FCF</th>
                  <th className="px-2 py-2.5">Catalyst</th>
                </tr>
              </thead>
              <tbody>
                {spaceFundamentals.map((company) => (
                  <tr key={company.symbol} className="border-b border-slate-800 text-slate-200">
                    <td className="px-2 py-3">
                      <div className="font-mono font-black text-white">{company.symbol}</div>
                      <div className="mt-1 text-[11px] text-slate-400">{company.name}</div>
                    </td>
                    <TableMetric metric={company.metrics.marketCap} />
                    <TableMetric metric={company.metrics.ttmRevenue} />
                    <TableMetric metric={company.metrics.revenueGrowth} />
                    <TableMetric metric={company.metrics.grossMargin} />
                    <TableMetric metric={company.metrics.psRatio} />
                    <TableMetric metric={company.metrics.evSales} />
                    <TableMetric metric={company.metrics.cashLiquidity} />
                    <TableMetric metric={company.metrics.backlog} />
                    <TableMetric metric={company.metrics.adjustedEbitda} />
                    <TableMetric metric={company.metrics.freeCashFlow} />
                    <td className="max-w-[260px] px-2 py-3 text-xs leading-5 text-slate-300">
                      {company.catalysts[0]}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="mt-5 grid gap-5 lg:grid-cols-[1fr_0.8fr]">
          <div className="border border-slate-700 bg-[#0b1120] p-5">
            <h2 className="text-xl font-black text-white">明天怎么用这张表</h2>
            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              <SignalBlock
                symbol="PL"
                title="事件票"
                body="Q1 FY2027 财报在 2026-06-04 盘后，明天最容易由 beat、guide、FCF 触发大幅波动。"
                tone="amber"
              />
              <SignalBlock
                symbol="ASTS"
                title="情绪票"
                body="SpaceX 招股书直接强化 Starlink Mobile 叙事，ASTS 可能被当成对标，但 P/S 极高。"
                tone="cyan"
              />
              <SignalBlock
                symbol="RKLB"
                title="质量票"
                body="收入、毛利率、backlog 最扎实；短线压力来自高估值和 ATM 增发计划。"
                tone="emerald"
              />
            </div>
          </div>

          <div className="border border-slate-700 bg-[#0b1120] p-5">
            <h2 className="text-xl font-black text-white">数据源</h2>
            <div className="mt-4 space-y-2">
              {spaceFundamentalSources.map((source) => (
                <a
                  key={source.id}
                  href={source.url}
                  target="_blank"
                  rel="noreferrer"
                  className="flex items-start justify-between gap-3 border border-slate-800 bg-black px-3 py-2 text-xs leading-5 text-slate-300 hover:border-slate-600 hover:text-white"
                >
                  <span>{source.label}</span>
                  <ExternalLink className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                </a>
              ))}
            </div>
          </div>
        </section>

        <footer className="mt-5 border border-slate-800 bg-black px-4 py-3 text-xs leading-6 text-slate-400">
          Research tooling only, not investment advice. Market data can be delayed; SpaceX S-1/A is preliminary and may
          change before effectiveness.
        </footer>
      </main>
    </div>
  );
}

function HeroMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="border border-slate-700 bg-[#06080d] px-4 py-3">
      <p className="font-mono text-[10px] font-black uppercase text-slate-500">{label}</p>
      <p className="mt-1 font-mono text-sm font-black text-white">{value}</p>
    </div>
  );
}

function CompanySnapshot({ company }: { company: SpaceCompanyFundamentals }) {
  return (
    <article className="border border-slate-700 bg-[#0b1120] p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] font-black uppercase text-slate-500">{company.status}</p>
          <h2 className="mt-1 font-mono text-2xl font-black text-white">{company.symbol}</h2>
          <p className="mt-1 text-xs font-bold text-slate-300">{company.name}</p>
        </div>
        <span className="border border-slate-700 bg-black px-2 py-1 font-mono text-[10px] font-black text-slate-300">
          {company.latestQuarter}
        </span>
      </div>
      <p className="mt-4 min-h-[66px] text-xs leading-6 text-slate-300">{company.business}</p>
      <div className="mt-4 grid grid-cols-2 gap-2">
        <MiniMetric label="Revenue" metric={company.metrics.ttmRevenue} />
        <MiniMetric label="P/S" metric={company.metrics.psRatio} />
        <MiniMetric label="Cash" metric={company.metrics.cashLiquidity} />
        <MiniMetric label="Backlog" metric={company.metrics.backlog} />
      </div>
    </article>
  );
}

function MiniMetric({ label, metric }: { label: string; metric: SpaceFundamentalMetric }) {
  return (
    <div className="border border-slate-800 bg-black px-3 py-2">
      <p className="font-mono text-[10px] text-slate-500">{label}</p>
      <p className="mt-1 font-mono text-sm font-black text-white">{formatMetric(metric, true)}</p>
    </div>
  );
}

function ChartPanel({
  icon,
  title,
  description,
  companies,
  metricKey,
  secondaryMetricKey,
  riskHigh = false,
  allowNegative = false,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  companies: SpaceCompanyFundamentals[];
  metricKey: MetricKey;
  secondaryMetricKey?: MetricKey;
  riskHigh?: boolean;
  allowNegative?: boolean;
}) {
  return (
    <div className="border border-slate-700 bg-[#0b1120] p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase text-slate-400">
            {icon} compare
          </p>
          <h2 className="mt-2 text-xl font-black text-white">{title}</h2>
          <p className="mt-2 text-xs leading-6 text-slate-400">{description}</p>
        </div>
      </div>
      <div className="mt-5 space-y-4">
        <BarGroup companies={companies} metricKey={metricKey} riskHigh={riskHigh} allowNegative={allowNegative} />
        {secondaryMetricKey ? (
          <div className="border-t border-slate-800 pt-4">
            <BarGroup companies={companies} metricKey={secondaryMetricKey} allowNegative={allowNegative} muted />
          </div>
        ) : null}
      </div>
    </div>
  );
}

function BarGroup({
  companies,
  metricKey,
  riskHigh = false,
  allowNegative = false,
  muted = false,
}: {
  companies: SpaceCompanyFundamentals[];
  metricKey: MetricKey;
  riskHigh?: boolean;
  allowNegative?: boolean;
  muted?: boolean;
}) {
  const rows = companies
    .map((company) => ({ company, metric: company.metrics[metricKey] }))
    .filter((row) => row.metric.value !== null);
  const maxAbs = Math.max(...rows.map((row) => Math.abs(row.metric.value || 0)), 1);
  const label = rows[0]?.metric.label || metricKey;

  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-3">
        <p className="font-mono text-[10px] font-black uppercase text-slate-500">{label}</p>
        <p className="font-mono text-[10px] text-slate-600">{allowNegative ? 'negative values shown in red' : ''}</p>
      </div>
      <div className="space-y-2">
        {rows.map(({ company, metric }) => {
          const value = metric.value || 0;
          const width = `${Math.max(3, (Math.abs(value) / maxAbs) * 100)}%`;
          const negative = value < 0;
          const barColor = negative
            ? 'bg-rose-500'
            : riskHigh
              ? 'bg-amber-400'
              : muted
                ? 'bg-sky-400'
                : 'bg-emerald-400';
          return (
            <div key={`${company.symbol}-${metricKey}`} className="grid grid-cols-[64px_1fr_96px] items-center gap-3">
              <span className="font-mono text-xs font-black text-slate-200">{company.symbol}</span>
              <div className="h-7 border border-slate-800 bg-black">
                <div className={`h-full ${barColor}`} style={{ width }} />
              </div>
              <span className={`text-right font-mono text-xs font-black ${negative ? 'text-rose-300' : 'text-white'}`}>
                {formatMetric(metric)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function SignalBlock({
  symbol,
  title,
  body,
  tone,
}: {
  symbol: string;
  title: string;
  body: string;
  tone: 'amber' | 'cyan' | 'emerald';
}) {
  const toneClass =
    tone === 'amber'
      ? 'border-amber-400/35 bg-amber-500/10 text-amber-100'
      : tone === 'cyan'
        ? 'border-cyan-400/35 bg-cyan-500/10 text-cyan-100'
        : 'border-emerald-400/35 bg-emerald-500/10 text-emerald-100';
  return (
    <div className={`border p-4 ${toneClass}`}>
      <p className="font-mono text-[10px] font-black uppercase">{symbol}</p>
      <h3 className="mt-2 text-base font-black text-white">{title}</h3>
      <p className="mt-2 text-xs leading-6">{body}</p>
    </div>
  );
}

function TableMetric({ metric }: { metric: SpaceFundamentalMetric }) {
  return <td className="px-2 py-3 text-right font-mono text-xs font-black text-slate-100">{formatMetric(metric)}</td>;
}

function formatMetric(metric: SpaceFundamentalMetric, compact = false): string {
  if (metric.value === null || metric.value === undefined || !Number.isFinite(metric.value)) return 'n/a';
  const value = metric.value;
  if (metric.unit === 'usd_m') return compact ? usdCompact(value) : usdMillions(value);
  if (metric.unit === 'percent') return `${value >= 0 ? '+' : ''}${value.toFixed(1)}%`;
  if (metric.unit === 'multiple') return `${value.toFixed(value >= 100 ? 0 : 1)}x`;
  if (metric.unit === 'ratio') return value.toFixed(2);
  return value.toLocaleString();
}

function usdMillions(value: number): string {
  const sign = value < 0 ? '-' : '';
  const abs = Math.abs(value);
  if (abs >= 1000) return `${sign}$${(abs / 1000).toFixed(abs >= 10000 ? 1 : 2)}B`;
  return `${sign}$${abs.toFixed(abs >= 100 ? 0 : 1)}M`;
}

function usdCompact(value: number): string {
  return usdMillions(value).replace('.00', '');
}
