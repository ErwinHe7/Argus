import { Activity, AlertTriangle, ArrowDownRight, ArrowUpRight, Crosshair, Layers, Scale, Target } from 'lucide-react';
import type { OptionsIntelReport } from '@/lib/market-intelligence/options';

export function TickerOptionsAnalytics({ options }: { options: OptionsIntelReport | null }) {
  if (!options || options.spot <= 0) {
    return (
      <section className="rounded-[6px] border border-slate-700 bg-[#141a2b] p-5 shadow-xl shadow-black/25">
        <header className="mb-2 flex items-center gap-2">
          <Layers className="h-5 w-5 text-blue-300" />
          <h2 className="text-xl font-black text-white">期权分析</h2>
        </header>
        <p className="text-sm leading-6 text-slate-200">
          期权链当前不可达（Yahoo 拒绝 datacenter IP，或该 ticker 无可选期权链）。配置 <code className="font-mono text-amber-200">IBKR_BASE_URL</code> + <code className="font-mono text-amber-200">IBKR_MARKET_DATA_ENABLED</code> 可走 IBKR Client Portal；配置 <code className="font-mono text-amber-200">POLYGON_API_KEY</code> 可走 Polygon snapshot/OI。
        </p>
      </section>
    );
  }

  const { spot, expiration, provider, maxPain, squeezeAssessment, flowPressure, topCalls, topPuts, probability } = options;

  const maxPainPct = maxPain ? ((maxPain.maxPainStrike - spot) / spot) * 100 : null;

  return (
    <section className="space-y-5 rounded-[6px] border border-slate-700 bg-[#141a2b] p-5 shadow-xl shadow-black/25">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <div className="mb-2 inline-flex items-center gap-2 rounded-[6px] border border-blue-400/50 bg-blue-500/20 px-3 py-1 text-xs font-black uppercase tracking-[0.14em] text-blue-100">
            <Layers className="h-4 w-4" /> Options analytics · {provider}
          </div>
          <h2 className="text-xl font-black text-white">本周期权链分析 · 到期 {expiration}</h2>
          <p className="mt-1 text-xs text-slate-300">
            Spot <span className="font-mono font-black text-white">{spot.toFixed(2)}</span>
            {probability ? <> · DTE <span className="font-mono text-slate-100">{probability.daysToExpiry}</span> · ATM IV <span className="font-mono text-slate-100">{(probability.ivAtm * 100).toFixed(1)}%</span></> : null}
          </p>
        </div>
        <SqueezeChip scenario={squeezeAssessment.scenario} />
      </header>

      {/* Max Pain Card */}
      {maxPain ? (
        <div className="grid gap-4 lg:grid-cols-[1.2fr_1fr]">
          <div className="rounded-[8px] border border-pink-400/40 bg-pink-500/10 p-4">
            <div className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-pink-200">
              <Crosshair className="h-4 w-4" /> Max Pain · 本周到期最痛点
            </div>
            <div className="mt-2 flex flex-wrap items-end gap-4">
              <div>
                <p className="font-mono text-4xl font-black text-pink-100">{maxPain.maxPainStrike.toFixed(2)}</p>
                <p className="mt-1 text-xs text-pink-200">
                  距 spot <span className="font-mono font-black">{maxPainPct !== null ? `${maxPainPct >= 0 ? '+' : ''}${maxPainPct.toFixed(2)}%` : '—'}</span>
                </p>
              </div>
              <div className="flex-1 min-w-[200px]">
                <p className="text-xs leading-5 text-slate-100">
                  Max Pain 是到期日期权卖方（market maker）支付最少的 strike。统计上，进入周五美股期权到期日（OPEX）时，股价常被 dealer hedging 拉向此点（"pin"）。
                  {maxPainPct !== null && Math.abs(maxPainPct) > 5
                    ? ` 当前 spot 距离 ${Math.abs(maxPainPct).toFixed(1)}%，pin 力度较弱，更可能受催化新闻主导。`
                    : maxPainPct !== null && Math.abs(maxPainPct) > 2
                      ? ` 当前 spot 距离 ${Math.abs(maxPainPct).toFixed(1)}%，pin 力度中等。`
                      : ' 当前 spot 已贴近 max pain，进入到期周时 pin 风险高，单腿期权 IV crush 严重。'}
                </p>
              </div>
            </div>
            <MaxPainCurveChart maxPain={maxPain} spot={spot} />
            <p className="mt-3 border-t border-pink-400/30 pt-2 text-[11px] text-pink-200/80">
              total pain at max ≈ ${(maxPain.totalPainAtMax / 1_000_000).toFixed(2)}M · 仅供方向参考，不替代实时 dealer book。
            </p>
          </div>

          {/* Flow Pressure */}
          <FlowPressureCard flow={flowPressure} />
        </div>
      ) : null}

      {/* Squeeze + Rationale */}
      <SqueezeRationaleCard squeeze={squeezeAssessment} />

      {/* Top 10 Calls / Puts ranked */}
      <div className="grid gap-4 lg:grid-cols-2">
        <TopOiTable
          title="Top 10 Call OI · 上方压力位 / 反弹目标"
          rows={topCalls}
          spot={spot}
          maxPainStrike={maxPain?.maxPainStrike}
          side="C"
        />
        <TopOiTable
          title="Top 10 Put OI · 下方支撑位 / 对冲集中区"
          rows={topPuts}
          spot={spot}
          maxPainStrike={maxPain?.maxPainStrike}
          side="P"
        />
      </div>

      <p className="border-t border-slate-800 pt-3 text-[11px] leading-5 text-slate-400">
        数据来自 {provider === 'ibkr' ? 'IBKR Client Portal' : provider === 'polygon' ? 'Polygon snapshot' : provider === 'yahoo' ? 'Yahoo Finance v7 options' : '不可达 provider'}。
        非投资建议；OI 反映累积持仓，不等于今日资金方向；dealer book 不公开，本分析为公开 OI/IV/gamma 推断。
      </p>
    </section>
  );
}

function MaxPainCurveChart({
  maxPain,
  spot,
}: {
  maxPain: NonNullable<OptionsIntelReport['maxPain']>;
  spot: number;
}) {
  const curve = maxPain.curve.filter((point) => Number.isFinite(point.strike) && Number.isFinite(point.totalPain));
  if (curve.length < 3) return null;

  const width = 720;
  const height = 180;
  const pad = { top: 18, right: 18, bottom: 28, left: 42 };
  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const minStrike = Math.min(...curve.map((point) => point.strike));
  const maxStrike = Math.max(...curve.map((point) => point.strike));
  const maxPainValue = Math.max(...curve.map((point) => point.totalPain), 1);
  const xScale = (strike: number) =>
    pad.left + ((strike - minStrike) / Math.max(1, maxStrike - minStrike)) * innerW;
  const yScale = (pain: number) => pad.top + innerH - (pain / maxPainValue) * innerH;
  const barW = Math.max(2, innerW / curve.length - 1);
  const spotX = xScale(spot);
  const maxPainX = xScale(maxPain.maxPainStrike);

  return (
    <div className="mt-4 rounded-[8px] border border-pink-400/25 bg-black/60 p-3">
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <p className="font-mono text-[10px] font-black uppercase tracking-[0.12em] text-pink-200">
          Max Pain payout curve
        </p>
        <p className="font-mono text-[10px] text-slate-400">
          lower bar = less payout to option holders
        </p>
      </div>
      <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" className="h-44 w-full">
        {[0, 0.25, 0.5, 0.75, 1].map((frac) => (
          <line
            key={frac}
            x1={pad.left}
            x2={pad.left + innerW}
            y1={pad.top + innerH * frac}
            y2={pad.top + innerH * frac}
            stroke="#1f2937"
            strokeWidth={1}
          />
        ))}
        {curve.map((point) => {
          const x = xScale(point.strike) - barW / 2;
          const y = yScale(point.totalPain);
          const isMaxPain = Math.abs(point.strike - maxPain.maxPainStrike) < 0.01;
          const fill = isMaxPain ? '#f9a8d4' : point.strike >= spot ? '#5eead4' : '#f87171';
          return (
            <rect
              key={point.strike}
              x={x}
              y={y}
              width={barW}
              height={pad.top + innerH - y}
              fill={fill}
              opacity={isMaxPain ? 0.95 : 0.58}
            >
              <title>
                {point.strike.toFixed(2)} · total payout {formatPain(point.totalPain)}
              </title>
            </rect>
          );
        })}
        <line
          x1={spotX}
          x2={spotX}
          y1={pad.top}
          y2={pad.top + innerH}
          stroke="#60a5fa"
          strokeWidth={2}
          strokeDasharray="4 3"
        />
        <line
          x1={maxPainX}
          x2={maxPainX}
          y1={pad.top}
          y2={pad.top + innerH}
          stroke="#f9a8d4"
          strokeWidth={2}
        />
        <text x={spotX} y={pad.top + 12} textAnchor="middle" fontSize={10} fill="#93c5fd" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
          spot {spot.toFixed(2)}
        </text>
        <text x={maxPainX} y={pad.top + innerH + 18} textAnchor="middle" fontSize={10} fill="#f9a8d4" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
          max pain {maxPain.maxPainStrike.toFixed(2)}
        </text>
        <text x={pad.left} y={height - 6} fontSize={10} fill="#94a3b8" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
          {minStrike.toFixed(0)}
        </text>
        <text x={pad.left + innerW} y={height - 6} textAnchor="end" fontSize={10} fill="#94a3b8" fontFamily="ui-monospace, SFMono-Regular, Menlo, monospace">
          {maxStrike.toFixed(0)}
        </text>
      </svg>
      <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-[11px] text-slate-400">
        <span>
          <span className="mr-1 inline-block h-2 w-3 bg-red-400/70" /> below spot
          <span className="ml-3 mr-1 inline-block h-2 w-3 bg-teal-300/70" /> above spot
          <span className="ml-3 mr-1 inline-block h-2 w-3 bg-pink-300" /> max pain
        </span>
        <span className="font-mono">min payout {formatPain(maxPain.totalPainAtMax)}</span>
      </div>
    </div>
  );
}

function FlowPressureCard({ flow }: { flow: OptionsIntelReport['flowPressure'] }) {
  if (!flow) {
    return (
      <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
        <div className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-200">
          <Scale className="h-4 w-4" /> 买卖压力（OI + 成交量）
        </div>
        <p className="mt-2 text-sm text-slate-300">期权链未返回有效 OI / volume。</p>
      </div>
    );
  }

  const oiCallPct = flow.oiPctCall * 100;
  const volCallPct = flow.volPctCall * 100;

  return (
    <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
      <div className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-200">
        <Scale className="h-4 w-4" /> 买卖压力（Call vs Put）
      </div>

      <div className="mt-3 space-y-3">
        <PressureBar
          label="未平仓 OI 占比"
          callPct={oiCallPct}
          callValue={flow.callOi}
          putValue={flow.putOi}
        />
        <PressureBar
          label="今日成交量占比"
          callPct={volCallPct}
          callValue={flow.callVolume}
          putValue={flow.putVolume}
        />
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2 border-t border-slate-800 pt-3 text-xs">
        <Stat label="Call/Put OI" value={Number.isFinite(flow.callPutOiRatio) ? flow.callPutOiRatio.toFixed(2) : '∞'} tone={flow.callPutOiRatio >= 1 ? 'green' : 'red'} />
        <Stat label="Call/Put Vol" value={Number.isFinite(flow.callPutVolumeRatio) ? flow.callPutVolumeRatio.toFixed(2) : '∞'} tone={flow.callPutVolumeRatio >= 1 ? 'green' : 'red'} />
      </div>

      <p className="mt-3 text-xs leading-5 text-slate-200">{flow.interpretation}</p>

      {flow.bidAskQuality !== 'unavailable' ? (
        <p className="mt-2 text-[11px] text-slate-400">
          Bid/ask 报价：{flow.bidAskQuality === 'ok' ? '良好覆盖' : '部分覆盖'} · 共 {flow.bidAskWeightedMidByStrike.length} 个有效 mid quote
        </p>
      ) : null}
    </div>
  );
}

function PressureBar({ label, callPct, callValue, putValue }: { label: string; callPct: number; callValue: number; putValue: number }) {
  const callWidth = Math.max(2, Math.min(98, callPct));
  return (
    <div>
      <div className="flex items-center justify-between text-[11px] font-semibold text-slate-300">
        <span>{label}</span>
        <span>
          <span className="font-mono font-black text-emerald-300">{callValue.toLocaleString()}</span>
          <span className="mx-1 text-slate-500">vs</span>
          <span className="font-mono font-black text-red-300">{putValue.toLocaleString()}</span>
        </span>
      </div>
      <div className="mt-1 flex h-3 w-full overflow-hidden rounded-full border border-slate-700 bg-black">
        <div className="bg-emerald-500/70" style={{ width: `${callWidth}%` }} title={`Call ${callPct.toFixed(0)}%`} />
        <div className="bg-red-500/70" style={{ width: `${100 - callWidth}%` }} title={`Put ${(100 - callPct).toFixed(0)}%`} />
      </div>
      <div className="mt-1 flex justify-between font-mono text-[10px] text-slate-400">
        <span className="text-emerald-300">Call {callPct.toFixed(0)}%</span>
        <span className="text-red-300">Put {(100 - callPct).toFixed(0)}%</span>
      </div>
    </div>
  );
}

function SqueezeChip({ scenario }: { scenario: OptionsIntelReport['squeezeAssessment']['scenario'] }) {
  const map: Record<typeof scenario, { label: string; cls: string; icon: JSX.Element }> = {
    gamma_squeeze_likely: {
      label: 'Gamma squeeze setup',
      cls: 'border-emerald-400/50 bg-emerald-500/20 text-emerald-100',
      icon: <ArrowUpRight className="h-3.5 w-3.5" />,
    },
    dealer_pin_likely: {
      label: 'Dealer pin likely',
      cls: 'border-pink-400/50 bg-pink-500/20 text-pink-100',
      icon: <Crosshair className="h-3.5 w-3.5" />,
    },
    put_unwind_likely: {
      label: 'Put unwind risk',
      cls: 'border-red-400/50 bg-red-500/20 text-red-100',
      icon: <ArrowDownRight className="h-3.5 w-3.5" />,
    },
    mixed: {
      label: 'Mixed / no clear regime',
      cls: 'border-slate-600 bg-slate-800 text-slate-200',
      icon: <Activity className="h-3.5 w-3.5" />,
    },
  };
  const entry = map[scenario];
  return (
    <span className={`inline-flex items-center gap-1 rounded-[6px] border px-3 py-1.5 text-xs font-black uppercase tracking-[0.12em] ${entry.cls}`}>
      {entry.icon} {entry.label}
    </span>
  );
}

function SqueezeRationaleCard({ squeeze }: { squeeze: OptionsIntelReport['squeezeAssessment'] }) {
  return (
    <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
      <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-200">
        <Activity className="h-4 w-4 text-amber-300" /> Dealer 行为推断
      </div>
      <ul className="space-y-1 text-sm leading-6 text-slate-100">
        {squeeze.rationale.map((r, i) => (
          <li key={i}>• {r}</li>
        ))}
      </ul>
      {squeeze.caveats.length ? (
        <div className="mt-3 border-t border-slate-800 pt-3">
          <div className="mb-1 flex items-center gap-1 text-[11px] font-black uppercase tracking-[0.12em] text-amber-200">
            <AlertTriangle className="h-3 w-3" /> Caveats
          </div>
          <ul className="space-y-1 text-[11px] leading-5 text-slate-300">
            {squeeze.caveats.map((c, i) => (
              <li key={i}>• {c}</li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  );
}

function TopOiTable({
  title,
  rows,
  spot,
  maxPainStrike,
  side,
}: {
  title: string;
  rows: OptionsIntelReport['topCalls'];
  spot: number;
  maxPainStrike?: number;
  side: 'C' | 'P';
}) {
  if (!rows.length) {
    return (
      <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
        <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-200">
          <Target className="h-4 w-4 text-blue-300" /> {title}
        </div>
        <p className="text-sm text-slate-300">无 {side === 'C' ? 'call' : 'put'} OI 数据。</p>
      </div>
    );
  }

  const maxOi = Math.max(...rows.map((r) => r.openInterest), 1);
  const isCall = side === 'C';

  return (
    <div className="rounded-[8px] border border-slate-700 bg-slate-950 p-4">
      <div className="mb-3 flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-200">
        <Target className={`h-4 w-4 ${isCall ? 'text-emerald-300' : 'text-red-300'}`} /> {title}
      </div>
      <div className="overflow-hidden rounded-[6px] border border-slate-700">
        <table className="w-full text-left text-sm">
          <thead className="bg-black/40">
            <tr className="text-[10px] font-black uppercase tracking-[0.12em] text-slate-300">
              <th className="py-2 pl-2 pr-2">#</th>
              <th className="py-2 pr-2">Strike</th>
              <th className="py-2 pr-2">% Spot</th>
              <th className="py-2 pr-2 text-right">OI</th>
              <th className="py-2 pr-2 text-right">Vol</th>
              <th className="py-2 pr-2">权重</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const pct = ((row.strike - spot) / spot) * 100;
              const oiPct = (row.openInterest / maxOi) * 100;
              const isMaxPain = maxPainStrike !== undefined && Math.abs(row.strike - maxPainStrike) < 0.01;
              return (
                <tr key={`${row.strike}-${row.side}`} className={`text-slate-100 ${row.rank % 2 === 1 ? 'bg-black/30' : ''}`}>
                  <td className="py-2 pl-2 pr-2 font-mono text-[11px] text-slate-300">#{row.rank}</td>
                  <td className="py-2 pr-2 font-mono text-sm font-black text-white">
                    {row.strike.toFixed(0)}
                    {isMaxPain ? <span className="ml-1 rounded bg-pink-500/30 px-1 text-[9px] font-black text-pink-100">MP</span> : null}
                  </td>
                  <td className={`py-2 pr-2 font-mono text-xs font-black ${pct > 0 ? 'text-emerald-300' : pct < 0 ? 'text-red-300' : 'text-slate-300'}`}>
                    {pct >= 0 ? '+' : ''}{pct.toFixed(1)}%
                  </td>
                  <td className="py-2 pr-2 text-right font-mono text-xs font-black text-white">
                    {row.openInterest.toLocaleString()}
                  </td>
                  <td className="py-2 pr-2 text-right font-mono text-xs text-slate-200">
                    {row.volume.toLocaleString()}
                  </td>
                  <td className="py-2 pr-2">
                    <div className="h-2 w-full overflow-hidden rounded-full bg-slate-800">
                      <div
                        className={`h-full ${isCall ? 'bg-emerald-500/70' : 'bg-red-500/70'}`}
                        style={{ width: `${oiPct}%` }}
                      />
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-[11px] leading-5 text-slate-400">
        {isCall
          ? '高 OI 的 call 通常代表卖方（dealer）大量短仓，被视为上方压力 / "call wall"；spot 接近这里时容易反复触碰再回。'
          : '高 OI 的 put 通常是机构对冲底仓，被视为下方支撑 / "put wall"；spot 跌破时容易触发 dealer 卖压（put unwind）。'}
        {maxPainStrike !== undefined ? ` MP = max pain strike (${maxPainStrike.toFixed(2)})。` : ''}
      </p>
    </div>
  );
}

function Stat({ label, value, tone }: { label: string; value: string; tone: 'green' | 'red' | 'slate' }) {
  const cls = tone === 'green' ? 'text-emerald-300' : tone === 'red' ? 'text-red-300' : 'text-slate-100';
  return (
    <div className="rounded-[6px] border border-slate-700 bg-black p-2">
      <p className="font-mono text-[10px] uppercase tracking-[0.12em] text-slate-300">{label}</p>
      <p className={`mt-1 font-mono text-sm font-black ${cls}`}>{value}</p>
    </div>
  );
}

function formatPain(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return '0';
  if (value >= 1_000_000_000) return `${(value / 1_000_000_000).toFixed(2)}B`;
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return value.toFixed(0);
}
