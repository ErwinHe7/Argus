import {
  Activity,
  BarChart3,
  BrainCircuit,
  Database,
  Gauge,
  Layers3,
  LockKeyhole,
  Network,
  Radar,
  ShieldAlert,
  ShieldCheck,
  SlidersHorizontal,
  Workflow,
} from 'lucide-react';

import type { NativeOsStore } from '@/lib/quant/native-os-types';
import {
  AvailabilityBanner,
  DataTable,
  EmptyDetail,
  EvidenceFooter,
  FeatureStrip,
  KeyValueGrid,
  Metric,
  MetricGrid,
  Section,
  TwoColumn,
  Workspace,
  booleanValue,
  dateTime,
  decimal,
  first,
  firstNumber,
  firstRecord,
  integer,
  isUnavailable,
  joinValues,
  percent,
  record,
  resourceStatus,
  rows,
  strings,
  text,
  yesNo,
} from './workspace-ui';

type BoundaryDefinition = {
  id: string;
  aliases: string[];
  title: string;
  principle: string;
  gate: string;
  source: string;
};

const productionBoundaries: BoundaryDefinition[] = [
  {
    id: 'point_in_time_data',
    aliases: ['data', 'market_memory', 'point_in_time', 'information_timing'],
    title: '1 · 点时数据与历史记忆',
    principle: '价格、财报、宏观、新闻与事件都按当时真实可见时间进入模型；修订不会改写旧快照。',
    gate: '缺少来源、as-of、覆盖或修订血缘时，后续预测必须阻断。',
    source: 'Context Fusion',
  },
  {
    id: 'behavioral_context',
    aliases: ['behavior', 'event_context', 'macro_context', 'human_behavior'],
    title: '2 · 行为、事件与宏观环境',
    principle: '只把压力下重复出现的市场行为编码为可检验特征，不臆测单个投资者的心理。',
    gate: '事件发布时间、财报可用时间或宏观 vintage 不可审计时，特征不得进入生产。',
    source: 'Context Fusion',
  },
  {
    id: 'state_inference',
    aliases: ['state', 'hmm', 'regime', 'baum_welch'],
    title: '3 · 隐状态与环境识别',
    principle: 'HMM / filtering 输出状态概率和不确定性，用于条件化预测，不把状态名称解释为因果。',
    gate: '模型版本、训练截止、状态熵或样本外对照缺失时，只能研究，不可下注。',
    source: 'Context Fusion',
  },
  {
    id: 'nonrandom_analogs',
    aliases: ['analogs', 'kernel', 'motifs', 'nonrandom_effects', 'anomalies'],
    title: '4 · 相似环境与非随机效应',
    principle: '核相似度、历史 analog 和异常母题只使用训练期、成熟标签与独立交易日。',
    gate: 'OOD、有效样本不足、重叠泄漏或负控失败时，不产生可交易证据。',
    source: 'Context Fusion',
  },
  {
    id: 'calibrated_prediction',
    aliases: ['prediction', 'calibration', 'probability', 'forecast'],
    title: '5 · 概率预测与校准',
    principle: '输出条件概率、区间和尾部风险；预测与交易决定分离，允许明确弃权。',
    gate: '未经 walk-forward、校准、成本后评估和 untouched test，不展示为生产优势。',
    source: 'Context Fusion',
  },
  {
    id: 'dynamic_betting',
    aliases: ['betting', 'allocation', 'kelly', 'position_sizing'],
    title: '6 · 动态下注与组合配置',
    principle: '分数 Kelly、置信折扣、相关性与容量约束共同决定仓位；没有优势时仓位为零。',
    gate: '缺少成本、概率校准、集中度上限或组合预算时，决定必须是 NO_TRADE。',
    source: 'Betting Allocation',
  },
  {
    id: 'execution_risk',
    aliases: ['portfolio_risk', 'execution', 'risk', 'kill_switch'],
    title: '7 · 执行与独立风险控制',
    principle: '风险、流动性、滑点、压力测试和 kill switch 在订单前独立复核模型决定。',
    gate: '任何硬限额越界、风险数据陈旧或执行证据缺失，都覆盖预测并阻止下单。',
    source: 'Portfolio Analytics',
  },
];

export function StrategyRiskWorkspace({ store }: { store: NativeOsStore }) {
  const context = record(store.contextFusion);
  const allocation = record(store.bettingAllocation);
  const risk = record(store.portfolioAnalytics);

  const contextStatus = resourceStatus(context);
  const allocationStatus = bettingDecisionStatus(allocation);
  const riskStatus = portfolioDecisionStatus(risk);
  const overallStatus = consolidatedStatus(contextStatus, allocationStatus, riskStatus);

  const dataSources = rows(context, [
    'required_sources',
    'data_readiness',
    'sources',
    'data.sources',
    'readiness.sources',
    'input_readiness',
  ]);
  const readySources = dataSources.filter((value) => /READY|AVAILABLE|OK|CONNECTED|ARCHIVED/i.test(rowStatus(record(value)))).length;
  const contextSignals = rows(context, [
    'latest_features',
    'context_signals',
    'signals',
    'features',
    'fused_context.signals',
    'prediction_inputs',
  ]);
  const eligibleFields = strings(first(context, ['model_eligible_fields']));
  const liquidityRows = rows(risk, ['liquidity', 'liquidity_results']);
  const factorExposures = firstRecord(risk, ['factor_exposures']);
  const factorRows = Object.entries(factorExposures).map(([key, value]) => ({ key, value }));
  const stressRows = rows(risk, ['stress_results']);
  const breaches = rows(risk, ['breaches', 'limit_breaches', 'controls.breaches']);
  const pretradeChecks = firstRecord(allocation, ['pretrade_checks']);
  const riskChecks = firstRecord(risk, ['checks']);
  const checkRows = Object.entries(riskChecks).map(([key, value]) => ({ key, value }));
  const boundaryEvidence = [
    ...rows(context, ['production_boundaries', 'boundaries', 'controls.production_boundaries']),
    ...rows(allocation, ['production_boundaries', 'boundaries']),
    ...rows(risk, ['production_boundaries', 'boundaries']),
  ];

  const blockedReasons = uniqueStrings([
    ...strings(first(context, ['reason_codes', 'blocked_reasons', 'blocking_reasons', 'reasons'])),
    ...strings(first(allocation, ['reason_codes', 'no_trade_reasons', 'blocked_reasons', 'decision.reasons'])),
    ...strings(first(risk, ['reason_codes', 'blocked_reasons', 'breach_reasons', 'risk_reasons'])),
    ...breaches.map((value) => text(first(record(value), ['reason', 'name', 'limit', 'id']))).filter(Boolean),
  ]);

  return (
    <Workspace
      title="策略与风险"
      eyebrow="Context → Probability → Bet → Portfolio → Execution"
      description="把图片中的行为重复、非随机效应、历史相似环境、隐状态、概率下注、因子配置与风险控制收敛为七道生产边界。页面只展示后端返回的真实证据；缺失值不会被模拟结果填充。"
    >
      <OperationalGate
        overall={overallStatus}
        context={contextStatus}
        allocation={allocationStatus}
        risk={riskStatus}
        reasons={blockedReasons}
      />

      <div className="grid gap-3 xl:grid-cols-3">
        <AvailabilityBanner payload={context} expected="/context/fusion" />
        <AvailabilityBanner payload={allocation} expected="/allocation/betting" />
        <AvailabilityBanner payload={risk} expected="/risk/portfolio-analytics" />
      </div>

      <MetricGrid>
        <Metric
          label="Real-data sources ready"
          value={dataSources.length ? `${readySources} / ${dataSources.length}` : '—'}
          note={dataSources.length ? '仅统计端点实际报告的数据源' : 'UNAVAILABLE · 未返回 readiness rows'}
        />
        <Metric
          label="Decision as-of"
          value={dateTime(first(allocation, ['forecast_as_of', 'as_of', 'generated_at']))}
          note="position sizing information cutoff"
        />
        <Metric
          label="Dynamic bet fraction"
          value={percent(firstNumber(allocation, ['fractional_kelly']))}
          note={allocationStatus}
        />
        <Metric
          label="Portfolio risk state"
          value={riskStatus}
          note={dateTime(first(risk, ['decision_as_of', 'as_of', 'generated_at']))}
        />
      </MetricGrid>

      <Section
        title="七道生产边界"
        icon={Workflow}
        subtitle="边界描述是生产合同；状态只从三项原生端点读取。没有逐边界证据时显示 UNAVAILABLE，而不是继承端点的总体 READY。"
      >
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {productionBoundaries.map((definition) => {
            const evidence = findBoundaryEvidence(boundaryEvidence, definition);
            const resolved = resolveBoundaryEvidence(definition, evidence, context, allocation, risk, eligibleFields);
            return <BoundaryCard key={definition.id} definition={definition} status={resolved.status} detail={resolved.detail} />;
          })}
        </div>
      </Section>

      <Section
        title="数据 · 真实数据就绪度"
        icon={Database}
        subtitle="行情、财报、宏观、新闻/地缘和跨资产数据必须分别报告来源、点时性、覆盖、延迟与阻断原因。"
      >
        <DataTable
          columns={['Source', 'Role', 'Status', 'As-of / vintage', 'Coverage', 'Point-in-time', 'Freshness', 'Blocker']}
          empty="Context Fusion 尚未返回真实数据源 readiness；宏观或财报字段不能因此被推定为已连接。"
          rows={dataSources.map((value, index) => {
            const row = record(value);
            return [
              text(first(row, ['source', 'name', 'dataset', 'key'])) || `source ${index + 1}`,
              text(first(row, ['role', 'category', 'purpose'])) || '—',
              <CriticalStatus key="status" value={rowStatus(row)} compact />,
              dateTime(first(row, ['as_of', 'vintage_at', 'available_at', 'latest_at'])),
              joinValues(first(row, ['coverage', 'symbols', 'window', 'history'])),
              yesNo(first(row, ['point_in_time', 'pit_safe', 'vintage_safe', 'as_of_safe'])),
              joinValues(first(row, ['freshness', 'latency_ms', 'age_seconds', 'staleness'])),
              text(first(row, ['blocker', 'reason', 'detail'])) || '—',
            ];
          })}
        />
      </Section>

      <Section
        title="预测 · 多环境融合与概率证据"
        icon={BrainCircuit}
        subtitle="模型可以结合市场状态、历史 analog、财报、宏观与事件，但每个信号都要暴露 availability time、方向和证据等级。"
      >
        <TwoColumn>
          <div className="rounded-xl border border-[#e1e1dc] bg-[#fafaf8] p-4">
            <KeyValueGrid items={[
              ['Context status', contextStatus],
              ['Context as-of', dateTime(first(context, ['as_of', 'generated_at']))],
              ['Provider', first(context, ['provider'])],
              ['Input path', first(context, ['input_path'])],
              ['Point-in-time ready', yesNo(first(context, ['point_in_time_ready']))],
              ['Observations', integer(firstNumber(context, ['observation_count']))],
              ['Model-eligible fields', integer(eligibleFields.length || undefined)],
              ['Betting evidence', first(allocation, ['evidence_status'])],
              ['Forecast as-of', dateTime(first(allocation, ['forecast_as_of']))],
            ]} />
          </div>
          <div className="rounded-xl border border-[#e1e1dc] bg-[#fafaf8] p-4">
            <FeatureStrip title="Macro context fields" values={matchingFieldNames(contextSignals, ['macro', 'rate', 'yield', 'inflation', 'growth', 'employment'])} empty="No point-in-time macro field reported." />
            <FeatureStrip title="Earnings / fundamentals fields" values={matchingFieldNames(contextSignals, ['earning', 'eps', 'revenue', 'guidance', 'fundamental'])} empty="No point-in-time earnings field reported." />
            <FeatureStrip title="Geopolitical / event fields" values={matchingFieldNames(contextSignals, ['event', 'news', 'geo', 'sentiment', 'policy'])} empty="No audited event field reported." />
            <FeatureStrip title="Prohibited production uses" values={strings(first(context, ['prohibited_uses']))} empty="No prohibited-use contract reported." />
          </div>
        </TwoColumn>
        <div className="mt-5">
          <DataTable
            columns={['Signal', 'Family', 'Observed value', 'Direction', 'Availability time', 'Evidence', 'Status']}
            empty="No fused prediction signals are available; the UI will not infer a forecast from narrative context."
            rows={contextSignals.map((value, index) => {
              const row = record(value);
              return [
                text(first(row, ['signal', 'name', 'feature', 'key'])) || `signal ${index + 1}`,
                text(first(row, ['family', 'group', 'category'])) || '—',
                joinValues(first(row, ['value', 'observation', 'score'])),
                text(first(row, ['direction', 'effect', 'side'])) || '—',
                dateTime(first(row, ['available_at', 'information_time', 'as_of'])),
                joinValues(first(row, ['evidence', 'evidence_tier', 'support'])),
                <CriticalStatus key="status" value={rowStatus(row)} compact />,
              ];
            })}
          />
        </div>
      </Section>

      <TwoColumn>
        <Section
          title="组合 · 动态下注决定"
          icon={SlidersHorizontal}
          subtitle="下注比例必须来自校准概率、成本后优势、分数 Kelly 与组合约束；它不是对收益的承诺。"
        >
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-[#deded9] bg-[#f7f7f4] p-4">
            <div>
              <p className="text-[10px] uppercase tracking-[0.1em] text-[#8b8e92]">Current allocation decision</p>
              <p className="mt-1 text-sm font-semibold text-[#282b2d]">{text(first(allocation, ['action'])) || 'No decision payload'}</p>
            </div>
            <CriticalStatus value={allocationStatus} />
          </div>
          <KeyValueGrid items={[
            ['Executable', yesNo(first(allocation, ['executable']))],
            ['Symbol / horizon', pair(first(allocation, ['symbol']), minuteHorizon(firstNumber(allocation, ['horizon_minutes'])))],
            ['Evidence status', first(allocation, ['evidence_status'])],
            ['Net edge', basisPoints(firstNumber(allocation, ['net_edge_bps']))],
            ['Raw Kelly', percent(firstNumber(allocation, ['raw_kelly_fraction']))],
            ['Fractional Kelly', percent(firstNumber(allocation, ['fractional_kelly']))],
            ['Shrinkage factor', percent(firstNumber(allocation, ['shrinkage_factor']))],
            ['Target weight', percent(firstNumber(allocation, ['target_weight']))],
            ['Policy version', first(allocation, ['policy_version'])],
            ['Forecast as-of', dateTime(first(allocation, ['forecast_as_of']))],
          ]} />
          <FeatureStrip title="No-trade / blocking reasons" values={strings(first(allocation, ['reason_codes']))} empty="No decision reason codes reported." />
          <FeatureStrip title="Pretrade checks" values={objectFacts(pretradeChecks)} empty="No pretrade checks reported." />
        </Section>

        <Section
          title="风控 · 组合风险状态"
          icon={ShieldAlert}
          subtitle="风险端点独立于预测和下注算法；任一硬约束可以把策略决定覆盖为 BLOCKED。"
        >
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-[#deded9] bg-[#f7f7f4] p-4">
            <div>
              <p className="text-[10px] uppercase tracking-[0.1em] text-[#8b8e92]">Independent portfolio gate</p>
              <p className="mt-1 text-sm font-semibold text-[#282b2d]">{yesNo(first(risk, ['new_risk_allowed'])) === 'YES' ? 'NEW_RISK_ALLOWED' : yesNo(first(risk, ['new_risk_allowed'])) === 'NO' ? 'NEW_RISK_BLOCKED' : 'No risk decision payload'}</p>
            </div>
            <CriticalStatus value={riskStatus} />
          </div>
          <KeyValueGrid items={[
            ['Gross exposure', percent(firstNumber(risk, ['gross_exposure', 'exposure.gross']))],
            ['Net exposure', percent(firstNumber(risk, ['net_exposure', 'exposure.net']))],
            ['Max position weight', percent(firstNumber(risk, ['max_position_weight']))],
            ['Historical VaR', percent(firstNumber(risk, ['historical_var_fraction']))],
            ['Expected shortfall', percent(firstNumber(risk, ['expected_shortfall_fraction']))],
            ['Worst stress loss', percent(firstNumber(risk, ['worst_stress_loss_fraction']))],
            ['Drawdown', percent(firstNumber(risk, ['drawdown_fraction']))],
            ['Daily loss', percent(firstNumber(risk, ['daily_loss_fraction']))],
            ['Kill switch recommended', yesNo(first(risk, ['kill_switch_recommended']))],
          ]} />
          <FeatureStrip title="Risk reason codes" values={strings(first(risk, ['reason_codes']))} empty="No risk reason codes reported." />
        </Section>
      </TwoColumn>

      <Section
        title="组合 · 因子暴露与流动性"
        icon={Layers3}
        subtitle="目标权重来自下注端点；组合因子与流动性来自独立风险端点。缺少持仓明细时不会推算或展示假仓位。"
      >
        <div className="grid gap-5 xl:grid-cols-2">
          <div>
            <p className="mb-3 text-[10px] font-semibold uppercase tracking-[0.1em] text-[#85888d]">Factor exposure</p>
            <DataTable
              columns={['Factor', 'Exposure']}
              empty="UNAVAILABLE · Portfolio Analytics has not returned factor_exposures."
              rows={factorRows.map((value) => {
                const row = record(value);
                return [
                  reportedText(first(row, ['key'])),
                  fractionPercent(firstNumber(row, ['value'])),
                ];
              })}
            />
          </div>
          <div>
            <p className="mb-3 text-[10px] font-semibold uppercase tracking-[0.1em] text-[#85888d]">Liquidity evidence</p>
            <DataTable
              columns={['Asset', 'Market value', 'Average daily dollar volume', 'Estimated liquidation days', 'Within policy']}
              empty="UNAVAILABLE · Portfolio Analytics has not returned liquidity evidence."
              rows={liquidityRows.map((value) => {
                const row = record(value);
                return [
                  reportedText(first(row, ['symbol'])),
                  reportedNumber(firstNumber(row, ['market_value'])),
                  reportedNumber(firstNumber(row, ['average_daily_dollar_volume'])),
                  reportedDays(firstNumber(row, ['estimated_liquidation_days'])),
                  <ReportedBooleanStatus key="within-policy" value={first(row, ['within_policy'])} />,
                ];
              })}
            />
          </div>
        </div>
      </Section>

      <TwoColumn>
        <Section
          title="执行 · 订单前放行"
          icon={LockKeyhole}
          subtitle="预测与组合决定不会直接变成订单；交易模式、行情新鲜度、流动性、成本和 kill switch 必须同时通过。"
        >
          {Object.keys(pretradeChecks).length || Object.keys(riskChecks).length || first(allocation, ['executable']) !== undefined ? (
            <KeyValueGrid items={[
              ['Allocation action', first(allocation, ['action'])],
              ['Executable', yesNo(first(allocation, ['executable']))],
              ['Forecast as-of', dateTime(first(allocation, ['forecast_as_of']))],
              ['Pretrade checks', joinValues(pretradeChecks)],
              ['New risk allowed', yesNo(first(risk, ['new_risk_allowed']))],
              ['Kill switch recommended', yesNo(first(risk, ['kill_switch_recommended']))],
              ['Risk checks', joinValues(riskChecks)],
              ['Final gate', overallStatus],
            ]} />
          ) : (
            <EmptyDetail text="Execution evidence is UNAVAILABLE. A model or allocation result must not be interpreted as an order." />
          )}
        </Section>

        <Section
          title="风控 · 限额与压力情景"
          icon={Gauge}
          subtitle="当前值、硬限额和 headroom 必须来自同一 as-of；压力结果不得用静态占位数表示。"
        >
          <DataTable
            columns={['Risk check', 'Reported result']}
            empty="UNAVAILABLE · Portfolio Analytics has not returned checks."
            rows={checkRows.map((value) => {
              const row = record(value);
              return [
                reportedText(first(row, ['key'])),
                <ReportedBooleanStatus key="result" value={first(row, ['value'])} />,
              ];
            })}
          />
          <div className="mt-4">
            <DataTable
              columns={['Stress scenario', 'P&L', 'Loss fraction', 'Position coverage', 'Usable', 'Reason codes']}
              empty="UNAVAILABLE · No stress_results have been computed for this portfolio snapshot."
              rows={stressRows.map((value) => {
                const row = record(value);
                return [
                  reportedText(first(row, ['name'])),
                  reportedNumber(firstNumber(row, ['pnl'])),
                  fractionPercent(firstNumber(row, ['loss_fraction'])),
                  reportedCoverage(
                    firstNumber(row, ['covered_nonzero_positions']),
                    firstNumber(row, ['total_nonzero_positions']),
                  ),
                  <ReportedBooleanStatus key="usable" value={first(row, ['usable'])} />,
                  reportedList(first(row, ['reason_codes'])),
                ];
              })}
            />
          </div>
        </Section>
      </TwoColumn>

      <EvidenceFooter payload={context} label="Context Fusion evidence" />
      <EvidenceFooter payload={allocation} label="Dynamic Betting evidence" />
      <EvidenceFooter payload={risk} label="Portfolio Risk evidence" />
    </Workspace>
  );
}

function OperationalGate({
  overall,
  context,
  allocation,
  risk,
  reasons,
}: {
  overall: string;
  context: string;
  allocation: string;
  risk: string;
  reasons: string[];
}) {
  const blocked = isCritical(overall);
  return (
    <section className={`rounded-2xl border p-5 sm:p-6 ${blocked ? 'border-[#d9a99d] bg-[#fff4f1]' : 'border-[#bdd5c8] bg-[#f1f8f4]'}`}>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex min-w-0 gap-3">
          {blocked ? <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-[#9a453b]" /> : <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-[#386a55]" />}
          <div>
            <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-[#777a80]">Consolidated production gate</p>
            <h2 className={`mt-1 text-xl font-semibold ${blocked ? 'text-[#793b33]' : 'text-[#28533f]'}`}>
              {overall === 'NO_TRADE' ? '当前结论：NO_TRADE' : overall === 'BLOCKED' ? '当前结论：BLOCKED' : overall === 'UNAVAILABLE' ? '当前结论：UNAVAILABLE' : `当前结论：${overall}`}
            </h2>
            <p className="mt-2 max-w-3xl text-xs leading-5 text-[#666a70]">
              只有数据上下文、动态下注和独立组合风控同时放行，系统才有资格进入执行检查。此状态不代表收益保证。
            </p>
          </div>
        </div>
        <CriticalStatus value={overall} />
      </div>
      <div className="mt-5 grid gap-2 sm:grid-cols-3">
        <GateState label="Data / prediction context" value={context} icon={Network} />
        <GateState label="Betting / allocation" value={allocation} icon={BarChart3} />
        <GateState label="Portfolio / risk" value={risk} icon={Radar} />
      </div>
      {reasons.length ? (
        <div className="mt-4 border-t border-black/10 pt-4">
          <p className="text-[10px] font-semibold uppercase tracking-[0.1em] text-[#85888d]">Reported blockers / no-trade reasons</p>
          <ul className="mt-2 grid gap-1.5 text-xs leading-5 text-[#6d514a] sm:grid-cols-2">
            {reasons.slice(0, 10).map((reason) => <li key={reason} className="flex gap-2"><span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-current" />{reason}</li>)}
          </ul>
        </div>
      ) : null}
    </section>
  );
}

function GateState({ label, value, icon: Icon }: { label: string; value: string; icon: typeof Activity }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-black/10 bg-white/65 px-3 py-3">
      <span className="inline-flex min-w-0 items-center gap-2 text-[10px] font-medium text-[#55585c]"><Icon className="h-3.5 w-3.5 shrink-0" />{label}</span>
      <CriticalStatus value={value} compact />
    </div>
  );
}

function BoundaryCard({ definition, status, detail }: { definition: BoundaryDefinition; status: string; detail: string }) {
  return (
    <article className={`rounded-xl border p-4 ${isCritical(status) ? 'border-[#e2c4bb] bg-[#fff8f5]' : 'border-[#d9d9d5] bg-[#fafaf8]'}`}>
      <div className="flex items-start justify-between gap-3">
        <h3 className="text-sm font-semibold leading-5 text-[#292b2d]">{definition.title}</h3>
        <CriticalStatus value={status} compact />
      </div>
      <p className="mt-3 text-xs leading-5 text-[#64676c]">{definition.principle}</p>
      <div className="mt-3 border-t border-[#e6e6e1] pt-3">
        <p className="text-[9px] font-semibold uppercase tracking-[0.09em] text-[#95989d]">Production gate</p>
        <p className="mt-1 text-[10px] leading-4 text-[#777a80]">{definition.gate}</p>
      </div>
      <p className="mt-3 font-mono text-[9px] text-[#96999d]">{definition.source} · {detail || 'no boundary evidence returned'}</p>
    </article>
  );
}

function CriticalStatus({ value, compact = false }: { value: string; compact?: boolean }) {
  const normalized = value.trim().toUpperCase() || 'UNAVAILABLE';
  const unavailable = /UNAVAILABLE|ERROR|DISCONNECT|MISSING/.test(normalized);
  const stopped = /BLOCK|NO_TRADE|NO_EDGE|REJECT|FAIL|BREACH|DEGRADED|PENDING|AWAIT|EXPLOR|CONTAMINATED|RESEARCH|UNPROMOTED/.test(normalized);
  const tone = unavailable
    ? 'border-[#d8aaa0] bg-[#fbe4df] text-[#813e35]'
    : stopped
      ? 'border-[#e1bf8f] bg-[#fff0d9] text-[#7b5420]'
      : 'border-[#bdd8ca] bg-[#e8f4ed] text-[#315f4e]';
  return <span className={`inline-flex shrink-0 items-center rounded-full border font-semibold uppercase tracking-[0.08em] ${compact ? 'px-2 py-1 text-[8px]' : 'px-3 py-1.5 text-[10px]'} ${tone}`}>{normalized}</span>;
}

function ReportedBooleanStatus({ value }: { value: unknown }) {
  if (typeof value !== 'boolean') return <CriticalStatus value="UNAVAILABLE" compact />;
  return <CriticalStatus value={value ? 'PASS' : 'FAIL'} compact />;
}

function findBoundaryEvidence(values: unknown[], definition: BoundaryDefinition) {
  const needles = [definition.id, ...definition.aliases].map(normalizeKey);
  const match = values.find((value) => {
    const row = record(value);
    const identity = normalizeKey(text(first(row, ['id', 'key', 'name', 'boundary', 'module', 'stage'])));
    return identity && needles.some((needle) => identity === needle || identity.includes(needle) || needle.includes(identity));
  });
  return record(match);
}

function resolveBoundaryEvidence(
  definition: BoundaryDefinition,
  explicit: ReturnType<typeof record>,
  context: ReturnType<typeof record>,
  allocation: ReturnType<typeof record>,
  risk: ReturnType<typeof record>,
  eligibleFields: string[],
) {
  if (Object.keys(explicit).length) {
    return {
      status: rowStatus(explicit),
      detail: text(first(explicit, ['evidence', 'detail', 'reason'])) || 'explicit boundary record',
    };
  }

  if (definition.id === 'point_in_time_data') {
    if (isUnavailable(context)) return { status: resourceStatus(context), detail: 'Context Fusion unavailable' };
    const ready = first(context, ['point_in_time_ready']);
    if (ready === undefined || ready === null) return { status: 'UNAVAILABLE', detail: 'point_in_time_ready not reported' };
    return {
      status: booleanValue(ready) ? 'READY' : 'BLOCKED',
      detail: pair(first(context, ['provider']), first(context, ['input_path'])),
    };
  }

  if (definition.id === 'behavioral_context' || definition.id === 'state_inference' || definition.id === 'nonrandom_analogs') {
    const matched = eligibleFields.filter((field) => {
      const identity = normalizeKey(field);
      return definition.aliases.some((alias) => identity.includes(normalizeKey(alias)));
    });
    return matched.length
      ? { status: 'AVAILABLE', detail: `model-eligible: ${matched.slice(0, 4).join(', ')}` }
      : { status: 'UNAVAILABLE', detail: 'no matching model-eligible field reported' };
  }

  if (definition.id === 'calibrated_prediction') {
    const evidenceStatus = text(first(allocation, ['evidence_status'])).toUpperCase();
    return evidenceStatus
      ? { status: evidenceStatus, detail: text(first(allocation, ['truth'])) || 'allocation evidence status' }
      : { status: 'UNAVAILABLE', detail: 'evidence_status not reported' };
  }

  if (definition.id === 'dynamic_betting') {
    return {
      status: bettingDecisionStatus(allocation),
      detail: text(first(allocation, ['truth', 'action'])) || 'betting decision status',
    };
  }

  return {
    status: portfolioDecisionStatus(risk),
    detail: text(first(risk, ['truth'])) || 'portfolio risk status',
  };
}

function normalizeKey(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

function rowStatus(value: ReturnType<typeof record>) {
  const explicit = text(first(value, ['status', 'state', 'readiness', 'decision', 'health'])).toUpperCase();
  if (explicit) return explicit;
  const scalar = first(value, ['value']);
  if (typeof scalar === 'boolean') return scalar ? 'READY' : 'BLOCKED';
  if (typeof scalar === 'string' && /^(READY|AVAILABLE|OK|PASS|PASSED|BLOCKED|FAIL|FAILED|UNAVAILABLE|PENDING|NO_TRADE)$/i.test(scalar)) return scalar.toUpperCase();
  const ready = first(value, ['ready', 'available', 'connected', 'point_in_time_ready']);
  return ready === undefined || ready === null ? 'UNAVAILABLE' : booleanValue(ready) ? 'READY' : 'BLOCKED';
}

function bettingDecisionStatus(value: ReturnType<typeof record>) {
  const endpointStatus = resourceStatus(value);
  if (isUnavailable(value)) return endpointStatus;
  const action = text(first(value, ['action'])).toUpperCase();
  if (/BLOCK|NO_TRADE|REJECT|FAIL/.test(action)) return action.includes('NO_TRADE') ? 'NO_TRADE' : 'BLOCKED';
  const executable = first(value, ['executable']);
  if (executable !== undefined && executable !== null && !booleanValue(executable)) return 'NO_TRADE';
  if (action) return action;
  return /READY|AVAILABLE|OK/.test(endpointStatus) ? 'BLOCKED' : endpointStatus;
}

function portfolioDecisionStatus(value: ReturnType<typeof record>) {
  const endpointStatus = resourceStatus(value);
  if (isUnavailable(value)) return endpointStatus;
  const explicit = text(first(value, ['status'])).toUpperCase();
  const newRiskAllowed = first(value, ['new_risk_allowed']);
  const killSwitch = first(value, ['kill_switch_recommended']);
  const breachCount = firstNumber(value, ['breach_count', 'controls.breach_count']);
  const reportedBreaches = rows(value, ['breaches', 'limit_breaches', 'controls.breaches']);
  if (killSwitch !== undefined && killSwitch !== null && booleanValue(killSwitch)) return 'BLOCKED';
  if (newRiskAllowed !== undefined && newRiskAllowed !== null && !booleanValue(newRiskAllowed)) return 'BLOCKED';
  if ((breachCount != null && breachCount > 0) || reportedBreaches.length) return 'BLOCKED';
  if (/BLOCK|REJECT|FAIL|BREACH|HALT/.test(explicit)) return 'BLOCKED';
  if (explicit) return explicit;
  return /READY|AVAILABLE|OK/.test(endpointStatus) ? endpointStatus : 'UNAVAILABLE';
}

function consolidatedStatus(context: string, allocation: string, risk: string) {
  const values = [context, allocation, risk].map((value) => value.toUpperCase());
  if (values.some((value) => /UNAVAILABLE|ERROR|DISCONNECT|MISSING/.test(value))) return 'UNAVAILABLE';
  if (values.some((value) => /BLOCK|REJECT|FAIL|BREACH|HALT/.test(value))) return 'BLOCKED';
  if (values.some((value) => /NO_TRADE/.test(value))) return 'NO_TRADE';
  if (values.some((value) => /DEGRADED|PENDING|AWAIT/.test(value))) return 'BLOCKED';
  return values.every((value) => /READY|AVAILABLE|OK|APPROVED|ELIGIBLE/.test(value)) ? 'READY' : 'BLOCKED';
}

function isCritical(value: string) {
  return /BLOCK|NO_TRADE|NO_EDGE|UNAVAILABLE|FAIL|ERROR|REJECT|BREACH|DEGRADED|PENDING|AWAIT|DISCONNECT|EXPLOR|CONTAMINATED|RESEARCH|UNPROMOTED/.test(value.toUpperCase());
}

function uniqueStrings(values: string[]) {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)));
}

function matchingFieldNames(values: unknown[], needles: string[]) {
  return uniqueStrings(values.flatMap((value) => {
    const row = record(value);
    const name = text(first(row, ['name', 'field', 'feature', 'signal', 'key']));
    const family = text(first(row, ['family', 'group', 'category']));
    const identity = `${name} ${family}`.toLowerCase();
    return needles.some((needle) => identity.includes(needle)) && name ? [name] : [];
  }));
}

function objectFacts(value: ReturnType<typeof record>) {
  return Object.entries(value).map(([key, item]) => `${key}: ${joinValues(item)}`);
}

function reportedText(value: unknown) {
  return text(value) || 'UNAVAILABLE';
}

function reportedNumber(value?: number) {
  return value == null ? 'UNAVAILABLE' : value.toLocaleString('en-US', { maximumFractionDigits: 6 });
}

function reportedDays(value?: number) {
  return value == null ? 'UNAVAILABLE' : `${decimal(value, 3)} days`;
}

function fractionPercent(value?: number) {
  return value == null ? 'UNAVAILABLE' : `${(value * 100).toFixed(2)}%`;
}

function reportedCoverage(covered?: number, total?: number) {
  return covered == null || total == null ? 'UNAVAILABLE' : `${integer(covered)} / ${integer(total)}`;
}

function reportedList(value: unknown) {
  if (!Array.isArray(value)) return 'UNAVAILABLE';
  const reported = value.map(text).filter(Boolean);
  return reported.length ? reported.join(', ') : 'NONE_REPORTED';
}

function pair(left: unknown, right: unknown) {
  const values = [text(left), text(right)].filter(Boolean);
  return values.length ? values.join(' · ') : '—';
}

function minuteHorizon(value?: number) {
  return value == null ? '' : `${value}m`;
}

function basisPoints(value?: number) {
  return value == null ? '—' : `${value.toFixed(2)} bps`;
}
