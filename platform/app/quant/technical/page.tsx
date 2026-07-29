import type { Metadata } from 'next';
import Link from 'next/link';
import {
  AlertTriangle,
  ArrowLeft,
  Database,
  ExternalLink,
  Filter,
  Radar,
  RefreshCw,
  SlidersHorizontal,
  TrendingUp,
} from 'lucide-react';
import { runKdjLowCrossScan, type KdjSignalRow } from '@/lib/quant/technical';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export const metadata: Metadata = {
  title: 'AXIO7 技术指标分析 · KDJ 低位金叉',
  description: '按 KDJ(9,3,3) 扫描低位金叉股票，支持配置全市场股票池或手动 ticker 列表。',
};

type PageProps = {
  searchParams?: Record<string, string | string[] | undefined>;
};

export default async function TechnicalAnalysisPage({ searchParams }: PageProps) {
  const tickersParam = getParam(searchParams, 'tickers');
  const lowZoneMaxParam = getParam(searchParams, 'lowZoneMax');
  const crossLookbackDaysParam = getParam(searchParams, 'crossLookbackDays');
  const limitParam = getParam(searchParams, 'limit');
  const rangeParam = getParam(searchParams, 'range');

  let report: Awaited<ReturnType<typeof runKdjLowCrossScan>> | undefined;
  let fatal: string | null = null;
  try {
    report = await runKdjLowCrossScan({
      symbols: tickersParam ? tickersParam.split(/[\s,;]+/) : undefined,
      lowZoneMax: numericParam(lowZoneMaxParam),
      crossLookbackDays: numericParam(crossLookbackDaysParam),
      limit: numericParam(limitParam),
      range: rangeParam === '1y' || rangeParam === '2y' ? rangeParam : '6mo',
    });
  } catch (err) {
    fatal = err instanceof Error ? err.message : '未知错误';
  }

  const defaultLow = String(report?.settings.lowZoneMax ?? lowZoneMaxParam ?? 35);
  const defaultLookback = String(report?.settings.crossLookbackDays ?? crossLookbackDaysParam ?? 3);
  const defaultLimit = String(report?.settings.limit ?? limitParam ?? 80);
  const defaultRange = report?.settings.range ?? rangeParam ?? '6mo';

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
            href="/api/quant/kdj-low-cross"
            className="inline-flex items-center gap-2 rounded-[6px] border border-slate-600 bg-slate-800/60 px-3 py-1.5 text-xs font-black tracking-[0.08em] text-slate-200 hover:bg-slate-700/60"
          >
            <ExternalLink className="h-3.5 w-3.5" /> JSON API
          </Link>
        </div>

        <header className="rounded-[8px] border border-slate-700 bg-gradient-to-br from-[#0b1120] to-[#080d1a] p-6">
          <p className="inline-flex items-center gap-2 rounded-[4px] border border-cyan-400/40 bg-cyan-500/10 px-2.5 py-1 font-mono text-[11px] font-black uppercase tracking-[0.16em] text-cyan-200">
            <Radar className="h-3.5 w-3.5" /> 技术指标分析 · KDJ station
          </p>
          <h1 className="mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">
            KDJ 低位金叉股票筛选
          </h1>
          <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-200">
            扫描股票池里的日 K，按 <span className="font-mono text-cyan-100">KDJ(9,3,3)</span> 找最近低位金叉：
            K 从下向上穿 D，且金叉点 K/D 仍在低位阈值以下。结果只作为研究清单，不是买卖建议。
          </p>
        </header>

        <form
          action="/quant/technical"
          className="mt-5 grid gap-4 rounded-[8px] border border-slate-700 bg-[#0b1120] p-5 lg:grid-cols-[1.2fr_0.35fr_0.35fr_0.35fr_0.35fr_auto]"
        >
          <label className="space-y-2">
            <span className="flex items-center gap-2 font-mono text-[10px] font-black uppercase tracking-[0.14em] text-slate-300">
              <Filter className="h-3.5 w-3.5 text-cyan-200" /> ticker 列表
            </span>
            <input
              name="tickers"
              defaultValue={tickersParam || ''}
              placeholder="留空使用默认/全市场股票池；也可输入 AAPL,NVDA,TSLA"
              className="h-11 w-full rounded-[6px] border border-slate-600 bg-black px-3 font-mono text-sm text-white outline-none focus:border-cyan-300"
            />
          </label>

          <SelectField
            label="范围"
            name="range"
            defaultValue={defaultRange}
            options={[
              ['6mo', '6个月'],
              ['1y', '1年'],
              ['2y', '2年'],
            ]}
          />
          <SelectField
            label="低位阈值"
            name="lowZoneMax"
            defaultValue={defaultLow}
            options={[
              ['20', '20'],
              ['30', '30'],
              ['35', '35'],
              ['40', '40'],
            ]}
          />
          <SelectField
            label="金叉窗口"
            name="crossLookbackDays"
            defaultValue={defaultLookback}
            options={[
              ['1', '1日'],
              ['3', '3日'],
              ['5', '5日'],
              ['10', '10日'],
            ]}
          />
          <SelectField
            label="扫描上限"
            name="limit"
            defaultValue={defaultLimit}
            options={[
              ['40', '40'],
              ['80', '80'],
              ['150', '150'],
              ['250', '250'],
            ]}
          />

          <div className="flex items-end">
            <button
              type="submit"
              className="inline-flex h-11 w-full items-center justify-center gap-2 rounded-[6px] border border-cyan-300/70 bg-cyan-300 px-4 text-sm font-black text-slate-950 hover:bg-cyan-200 lg:w-auto"
            >
              <RefreshCw className="h-4 w-4" /> 扫描
            </button>
          </div>
        </form>

        {fatal ? (
          <div className="mt-6 rounded-[6px] border border-red-500/60 bg-red-500/10 p-5 text-sm text-red-200">
            技术指标扫描失败：{fatal}
          </div>
        ) : report ? (
          <TechnicalScanView report={report} />
        ) : null}

        <footer className="mt-7 rounded-[6px] border border-slate-800 bg-black px-5 py-4 text-xs leading-7 text-slate-400">
          生产环境要扫“全部股票”，把 Moomoo/Futu、Polygon、Nasdaq screener 或内部 universe 服务输出成 JSON/CSV，
          配到 <span className="font-mono text-cyan-200">TECHNICAL_UNIVERSE_URL</span>；临时也可以用
          <span className="font-mono text-cyan-200"> TECHNICAL_SCAN_UNIVERSE</span> 写逗号分隔 ticker。
          行情数据当前使用 Yahoo 日线拉取，可能延迟、缺失或被限流。
        </footer>
      </main>
    </div>
  );
}

function TechnicalScanView({ report }: { report: Awaited<ReturnType<typeof runKdjLowCrossScan>> }) {
  return (
    <>
      <section className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <Metric label="命中" value={`${report.matched}`} tone={report.matched > 0 ? 'good' : 'muted'} />
        <Metric label="已扫描" value={`${report.scanned}/${report.configuredUniverseCount}`} />
        <Metric label="低位阈值" value={`K/D ≤ ${report.settings.lowZoneMax}`} />
        <Metric label="金叉窗口" value={`${report.settings.crossLookbackDays} 日`} />
        <Metric label="生成时间" value={new Date(report.generatedAt).toLocaleTimeString('zh-CN')} />
      </section>

      <section className="mt-5 rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
              <Database className="h-3.5 w-3.5 text-cyan-200" /> universe
            </p>
            <h2 className="mt-2 text-lg font-black text-white">股票池来源：{report.universeSource}</h2>
            <p className="mt-2 max-w-3xl text-xs leading-6 text-slate-400">
              {report.truncated
                ? `当前请求只扫描前 ${report.scanned} 只；把扫描上限调高，或在后端改 TECHNICAL_SCAN_MAX_PER_REQUEST 分批跑全市场。`
                : '当前请求已覆盖配置股票池。'}
            </p>
          </div>
          <div className="rounded-[6px] border border-cyan-400/40 bg-cyan-500/10 px-3 py-2 font-mono text-[11px] font-black text-cyan-100">
            KDJ({report.settings.kdjPeriod},{report.settings.kSmoothing},{report.settings.dSmoothing})
          </div>
        </div>

        {report.warning ? (
          <div className="mt-4 flex gap-2 rounded-[6px] border border-amber-400/40 bg-amber-500/10 p-3 text-xs leading-6 text-amber-100">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <span>{report.warning}</span>
          </div>
        ) : null}
      </section>

      <section className="mt-5 rounded-[8px] border border-slate-700 bg-[#0b1120] p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[10px] font-black uppercase tracking-[0.16em] text-emerald-300">
              <TrendingUp className="h-3.5 w-3.5" /> low-zone golden cross
            </p>
            <h2 className="mt-2 text-lg font-black text-white">低位金叉清单</h2>
          </div>
          <p className="font-mono text-[10px] text-slate-500">
            排序：金叉越新越靠前，同日按低位程度和延续性打分
          </p>
        </div>

        {report.rows.length ? (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[1120px] border-collapse text-left text-[12px]">
              <thead>
                <tr className="border-b border-slate-700 font-mono text-[10px] uppercase tracking-[0.08em] text-slate-400">
                  <th className="px-2 py-2.5">#</th>
                  <th className="px-2 py-2.5">代码</th>
                  <th className="px-2 py-2.5 text-right">价格</th>
                  <th className="px-2 py-2.5">金叉日</th>
                  <th className="px-2 py-2.5 text-right">距今</th>
                  <th className="px-2 py-2.5 text-right text-cyan-300">金叉 K/D/J</th>
                  <th className="px-2 py-2.5 text-right text-emerald-300">当前 K/D/J</th>
                  <th className="px-2 py-2.5 text-right text-amber-300">RSI14</th>
                  <th className="px-2 py-2.5 text-right">分数</th>
                  <th className="px-2 py-2.5">备注</th>
                </tr>
              </thead>
              <tbody className="text-slate-200">
                {report.rows.map((row, index) => (
                  <SignalRow key={row.ticker} row={row} index={index} />
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="mt-4 rounded-[6px] border border-dashed border-slate-700 bg-black/30 p-6 text-sm leading-7 text-slate-300">
            当前扫描范围内没有命中 KDJ 低位金叉。可以把金叉窗口调到 5-10 日、低位阈值调到 40，或者接入更大的股票池后再跑。
          </div>
        )}
      </section>

      {report.errors.length > 0 ? (
        <section className="mt-5 rounded-[6px] border border-amber-500/40 bg-amber-500/10 p-3">
          <p className="font-mono text-[11px] font-black uppercase tracking-[0.08em] text-amber-200">
            数据不足或拉取失败（{report.errors.length}）
          </p>
          <ul className="mt-1.5 grid grid-cols-2 gap-x-4 text-[11px] text-amber-100 sm:grid-cols-3 lg:grid-cols-4">
            {report.errors.slice(0, 32).map((e) => (
              <li key={e.ticker} className="font-mono">
                {e.ticker}: {e.reason}
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </>
  );
}

function SignalRow({ row, index }: { row: KdjSignalRow; index: number }) {
  return (
    <tr className="border-b border-slate-800 hover:bg-slate-900/40">
      <td className="px-2 py-2.5 font-mono text-slate-400">{index + 1}</td>
      <td className="px-2 py-2.5 font-mono font-black">
        <Link href={`/market/ticker/${row.ticker}`} className="text-cyan-200 hover:text-cyan-100">
          {row.ticker}
        </Link>
      </td>
      <td className="px-2 py-2.5 text-right font-mono">{row.price ? row.price.toFixed(2) : '--'}</td>
      <td className="px-2 py-2.5 font-mono text-slate-300">{row.signalDate}</td>
      <td className="px-2 py-2.5 text-right font-mono">
        {row.daysSinceCross === 0 ? '今日' : `${row.daysSinceCross} 日`}
      </td>
      <td className="px-2 py-2.5 text-right font-mono text-cyan-100">
        {fmtKdj(row.cross.k)} / {fmtKdj(row.cross.d)} / {fmtKdj(row.cross.j)}
      </td>
      <td className="px-2 py-2.5 text-right font-mono text-emerald-100">
        {fmtKdj(row.current.k)} / {fmtKdj(row.current.d)} / {fmtKdj(row.current.j)}
      </td>
      <td className="px-2 py-2.5 text-right font-mono text-amber-100">{fmtKdj(row.rsi14)}</td>
      <td className="px-2 py-2.5 text-right font-mono font-black text-white">{row.score.toFixed(1)}</td>
      <td className="px-2 py-2.5">
        <div className="flex flex-wrap gap-1.5">
          {row.notes.map((note) => (
            <span key={note} className="rounded-[4px] border border-slate-700 bg-black px-2 py-1 text-[10px] text-slate-300">
              {note}
            </span>
          ))}
        </div>
      </td>
    </tr>
  );
}

function SelectField({
  label,
  name,
  defaultValue,
  options,
}: {
  label: string;
  name: string;
  defaultValue: string;
  options: Array<[string, string]>;
}) {
  return (
    <label className="space-y-2">
      <span className="flex items-center gap-2 font-mono text-[10px] font-black uppercase tracking-[0.14em] text-slate-300">
        <SlidersHorizontal className="h-3.5 w-3.5 text-slate-400" /> {label}
      </span>
      <select
        name={name}
        defaultValue={defaultValue}
        className="h-11 w-full rounded-[6px] border border-slate-600 bg-black px-2 font-mono text-sm text-white outline-none focus:border-cyan-300"
      >
        {options.map(([value, optionLabel]) => (
          <option key={value} value={value}>
            {optionLabel}
          </option>
        ))}
      </select>
    </label>
  );
}

function Metric({ label, value, tone = 'neutral' }: { label: string; value: string; tone?: 'good' | 'muted' | 'neutral' }) {
  const color = tone === 'good' ? 'text-emerald-300' : tone === 'muted' ? 'text-slate-300' : 'text-white';
  return (
    <div className="rounded-[6px] border border-slate-700 bg-[#0b1120] px-4 py-3">
      <p className="font-mono text-[10px] font-black uppercase tracking-[0.13em] text-slate-400">{label}</p>
      <p className={`mt-2 font-mono text-lg font-black ${color}`}>{value}</p>
    </div>
  );
}

function getParam(params: PageProps['searchParams'], key: string): string | undefined {
  const value = params?.[key];
  if (Array.isArray(value)) return value[0];
  return value;
}

function numericParam(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const n = Number(value);
  return Number.isFinite(n) ? n : undefined;
}

function fmtKdj(value: number | null | undefined): string {
  if (value === null || value === undefined || !Number.isFinite(value)) return '--';
  return value.toFixed(1);
}
