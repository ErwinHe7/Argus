import { BookOpen, Crosshair, Gauge, Layers3, Radar, ShieldAlert } from 'lucide-react';

const FLOW = [
  ['1', '新闻定方向', '先看财报、AI 订单、利率、盘前消息和板块联动，判断是趋势延续还是利好兑现。'],
  ['2', '价格定结构', '标出 VWAP、昨高/昨低、支撑压力、expected move、max pain、大 OI strike。'],
  ['3', 'IV 定买卖', 'IV 高且事件落地时，做市商更容易杀 premium；IV 扩张且现货突破，才偏向 debit spread。'],
  ['4', 'Gamma 定风控', '突破大 OI strike 且成交放大，可能 gamma squeeze；横盘时短期期权会被 theta 吃掉。'],
] as const;

const STRATEGIES = [
  {
    title: 'Bull Call Debit Spread',
    cn: '垂直看涨价差',
    use: '新闻偏多、现货突破关键位，但不想裸买 OTM call。',
    structure: '买低 strike Call，卖高 strike Call。',
    risk: '亏损=净 debit；盈利=宽度-debit。',
  },
  {
    title: 'Bear Call Credit Spread',
    cn: '看跌 Call 垂直价差',
    use: '上方压力强、IV 偏贵、预期做市商杀短期期权。',
    structure: '卖 180C @1.27，买 182.5C @0.65。',
    risk: 'NVDA 案例 credit 约 0.62，BE 180.62，最大风险约 1.88/组。',
  },
  {
    title: 'Bull Put Credit Spread',
    cn: '看涨 Put 垂直价差',
    use: '下方支撑强，想收 theta，而不是追涨现货。',
    structure: '卖 172.5P @1.35，买 170P @0.805。',
    risk: 'NVDA 案例 credit 约 0.545，BE 171.96，跌破支撑要止损。',
  },
  {
    title: 'Bear Put Debit Spread',
    cn: '垂直看跌价差',
    use: '利空新闻后跌破支撑，反抽不过 VWAP。',
    structure: '买高 strike Put，卖低 strike Put。',
    risk: '亏损=净 debit；盈利=宽度-debit。',
  },
  {
    title: 'Long Call Butterfly',
    cn: '蝶式期权',
    use: '目标价明确，预期价格向一个磁铁位收敛。',
    structure: '买 172.5C，卖 2 张 175C，买 177.5C。',
    risk: 'NVDA 案例 debit 约 0.69，BE 173.19 / 176.81，最大收益在 175 附近。',
  },
  {
    title: 'Broken Wing Butterfly',
    cn: '破翼蝶式',
    use: '有方向偏见，但仍想围绕目标价做低成本结构。',
    structure: '例如 172.5/175/180 call broken-wing fly。',
    risk: '成本更低不是免费；宽翼一侧有尾部风险，gamma squeeze 穿翼要处理。',
  },
] as const;

const CASES = [
  ['NVDA 180/182.5 Bear Call', '压力位卖 call spread', '低于 180 收满 credit；站上 180.62 风险扩大。'],
  ['NVDA 172.5/170 Bull Put', '支撑位卖 put spread', '高于 172.5 收租；跌破 171.96 说明支撑失败。'],
  ['NVDA 172.5/175/177.5 Fly', '目标 175 pin', '适合一天内冲到目标但不过度暴走。'],
  ['NVDA 190/192.5 Short Call Vertical', '远端压力收 premium', 'credit 约 0.30，核心是判断 190 压制有效。'],
] as const;

export function OptionsStrategyPlaybook() {
  return (
    <aside className="space-y-4 rounded-[10px] border border-slate-700 bg-slate-900 p-6 shadow-2xl shadow-black/30 xl:sticky xl:top-24">
      <header>
        <div className="mb-2 inline-flex items-center gap-2 rounded-[6px] border border-amber-300/30 bg-amber-300/10 px-3 py-1 text-xs font-black uppercase tracking-[0.16em] text-amber-100">
          <BookOpen className="h-4 w-4" /> Options Playbook
        </div>
        <h2 className="text-2xl font-black tracking-tight text-white">策略侧栏：先分析，再选结构</h2>
        <p className="mt-2 text-sm leading-6 text-slate-300">
          教学内容基于你给的 NVDA 截图整理，仅用于分析流程，不构成投资建议。
        </p>
      </header>

      <section className="space-y-2">
        <div className="flex items-center gap-2 text-sm font-black text-white">
          <Radar className="h-4 w-4 text-cyan-200" /> Analysis flow
        </div>
        <div className="grid gap-2">
          {FLOW.map(([step, title, body]) => (
            <div key={step} className="rounded-[8px] border border-slate-800 bg-slate-950 p-4">
              <div className="flex items-center gap-2">
                <span className="inline-flex h-5 w-5 items-center justify-center rounded bg-cyan-300 text-[10px] font-black text-slate-950">
                  {step}
                </span>
                <strong className="text-sm font-black text-white">{title}</strong>
              </div>
              <p className="mt-2 text-sm leading-6 text-slate-300">{body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="space-y-2">
        <div className="flex items-center gap-2 text-sm font-black text-white">
          <Layers3 className="h-4 w-4 text-amber-200" /> Strategy menu
        </div>
        <div className="max-h-[520px] space-y-2 overflow-y-auto pr-1">
          {STRATEGIES.map((item) => (
            <article key={item.title} className="rounded-[8px] border border-slate-800 bg-slate-950 p-4">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h3 className="text-base font-black text-white">{item.cn}</h3>
                  <p className="font-mono text-xs uppercase tracking-[0.12em] text-cyan-100">{item.title}</p>
                </div>
                <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0 text-rose-200" />
              </div>
              <dl className="mt-3 space-y-2 text-sm leading-6">
                <div>
                  <dt className="font-black text-slate-100">什么时候用</dt>
                  <dd className="text-slate-300">{item.use}</dd>
                </div>
                <div>
                  <dt className="font-black text-slate-100">结构</dt>
                  <dd className="text-slate-300">{item.structure}</dd>
                </div>
                <div>
                  <dt className="font-black text-slate-100">风险</dt>
                  <dd className="text-slate-300">{item.risk}</dd>
                </div>
              </dl>
            </article>
          ))}
        </div>
      </section>

      <section className="space-y-2">
        <div className="flex items-center gap-2 text-sm font-black text-white">
          <Crosshair className="h-4 w-4 text-emerald-200" /> NVDA case notes
        </div>
        <div className="space-y-2">
          {CASES.map(([name, setup, note]) => (
            <div key={name} className="rounded-[8px] border border-slate-800 bg-slate-950 p-4">
              <strong className="block text-sm font-black text-white">{name}</strong>
              <span className="mt-1 block text-sm font-black text-amber-100">{setup}</span>
              <p className="mt-1 text-sm leading-6 text-slate-300">{note}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="rounded-[8px] border border-cyan-300/20 bg-cyan-300/10 p-3">
        <div className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-cyan-100">
          <Gauge className="h-4 w-4" /> Dealer / Gamma checklist
        </div>
        <ul className="mt-2 space-y-1 text-sm leading-6 text-cyan-50">
          <li>现货没有突破 + IV 高：优先考虑 credit spread / butterfly。</li>
          <li>突破大 OI strike + 成交放大 + IV 上升：警惕 gamma squeeze。</li>
          <li>事件落地后 IV crush：裸买短期期权最容易被杀。</li>
          <li>每个结构先写 breakeven、最大亏损、失效价格，再考虑下单。</li>
        </ul>
      </section>
    </aside>
  );
}
