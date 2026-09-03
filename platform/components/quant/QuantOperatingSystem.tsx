'use client';

import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react';
import {
  Activity,
  AlertCircle,
  ArrowUpRight,
  BarChart3,
  BrainCircuit,
  Clock3,
  Database,
  Gauge,
  History,
  Layers3,
  RefreshCw,
  Scale,
  ShieldCheck,
  Waves,
} from 'lucide-react';

import { AnalogExplorerWorkspace, StateEngineWorkspace } from './os/AnalogStateWorkspaces';
import { AuditRuntimeWorkspace } from './os/AuditRuntimeWorkspace';
import { EventAtlasWorkspace, MarketMemoryWorkspace } from './os/MemoryEventWorkspaces';
import { MotifAnomalyWorkspace, ResearchFactoryWorkspace } from './os/ResearchWorkspaces';
import { StrategyRiskWorkspace } from './os/StrategyRiskWorkspace';
import styles from './QuantOperatingSystem.module.css';
import type {
  NativeBehavioralRegimeScore,
  NativeBehavioralStateLayer,
  NativeForecastResource,
  NativeForecastRow,
  NativeKernelRegression,
  NativeOsStore,
  NativeOsTab,
  NativeOutcomePredictionInterval,
  NativeProbabilityEstimateInterval,
  NativeRequestDefinition,
  NativeResourceEnvelope,
  NativeSdeCentralPredictionInterval,
} from '@/lib/quant/native-os-types';

const API = '/api/quant/intraday';

type Json = Record<string, unknown>;
type Tab = NativeOsTab;
type ForecastAsset = 'SPY' | 'QQQ' | 'SOXX' | 'NVDA' | 'MU' | 'AAPL';



const tabRequests: Record<Tab, readonly NativeRequestDefinition[]> = {
  overview: [
    { key: 'liveStatus', path: '/live/status' },
    { key: 'liveCapabilities', path: '/live/capabilities' },
    { key: 'liveBars', path: '/live/bars' },
    { key: 'ownerForecast', path: '/predictor/owner-preview' },
    { key: 'ownerForecastQqq', path: '/predictor/owner-preview?symbol=QQQ' },
    { key: 'ownerForecastSoxx', path: '/predictor/owner-preview?symbol=SOXX' },
    { key: 'ownerForecastNvda', path: '/predictor/owner-preview?symbol=NVDA' },
    { key: 'ownerForecastMu', path: '/predictor/owner-preview?symbol=MU' },
    { key: 'ownerForecastAapl', path: '/predictor/owner-preview?symbol=AAPL' },
    { key: 'forecast', path: '/predictor/forecast' },
    { key: 'forecastQqq', path: '/predictor/forecast?symbol=QQQ' },
    { key: 'forecastSoxx', path: '/predictor/forecast?symbol=SOXX' },
    { key: 'forecastNvda', path: '/predictor/forecast?symbol=NVDA' },
    { key: 'forecastMu', path: '/predictor/forecast?symbol=MU' },
    { key: 'forecastAapl', path: '/predictor/forecast?symbol=AAPL' },
    { key: 'opportunities', path: '/research/opportunities?horizon=15&limit=2' },
    { key: 'shadow', path: '/predictor/shadow' },
  ],
  memory: [
    { key: 'memorySummary', path: '/memory/summary' },
    { key: 'dataCapabilities', path: '/data/capabilities' },
    { key: 'dataCoverage', path: '/data/coverage' },
    { key: 'liveStatus', path: '/live/status' },
  ],
  events: [
    { key: 'eventAtlas', path: '/events/atlas' },
    { key: 'liveStatus', path: '/live/status' },
  ],
  analogs: [
    { key: 'analogsCurrent', path: '/analogs/current' },
    { key: 'liveStatus', path: '/live/status' },
  ],
  state: [
    { key: 'stateCurrent', path: '/state/current' },
    { key: 'liveStatus', path: '/live/status' },
  ],
  motifs: [
    { key: 'researchFactory', path: '/research/factory' },
    { key: 'eventAtlas', path: '/events/atlas' },
    { key: 'liveStatus', path: '/live/status' },
  ],
  strategyRisk: [
    { key: 'contextFusion', path: '/context/fusion' },
    { key: 'bettingAllocation', path: '/allocation/betting' },
    { key: 'portfolioAnalytics', path: '/risk/portfolio-analytics' },
  ],
  research: [
    { key: 'researchFactory', path: '/research/factory' },
    { key: 'predictorModel', path: '/predictor/model' },
    { key: 'walkForward', path: '/predictor/walk-forward' },
    { key: 'calibration', path: '/predictor/calibration' },
    { key: 'shadow', path: '/predictor/shadow' },
    { key: 'liveStatus', path: '/live/status' },
  ],
  audit: [
    { key: 'auditPredictions', path: '/audit/predictions' },
    { key: 'system', path: '/system/status' },
    { key: 'liveStatus', path: '/live/status' },
    { key: 'liveCapabilities', path: '/live/capabilities' },
    { key: 'shadow', path: '/predictor/shadow' },
    { key: 'settlements', path: '/predictor/settlements' },
    { key: 'dataCapabilities', path: '/data/capabilities' },
    { key: 'dataCoverage', path: '/data/coverage' },
  ],
};

const navigation: Array<[Tab, string, typeof Activity]> = [
  ['overview', '预测总览', Activity],
  ['memory', '市场记忆', Database],
  ['events', '事件图谱', History],
  ['analogs', '相似环境', BarChart3],
  ['state', '状态引擎', BrainCircuit],
  ['motifs', '异常母题', Waves],
  ['strategyRisk', '策略与风险', Scale],
  ['research', '研究工厂', Layers3],
  ['audit', '审计运行', ShieldCheck],
];

async function fetchJson(path: string, signal: AbortSignal): Promise<NativeResourceEnvelope> {
  const response = await fetch(`${API}${path}`, { cache: 'no-store', signal });
  const payload = await response.json().catch(() => ({
    status: 'UNAVAILABLE',
    detail: `Endpoint returned non-JSON content (HTTP ${response.status})`,
  }));
  const envelope = payload && typeof payload === 'object' && !Array.isArray(payload)
    ? payload as NativeResourceEnvelope
    : { status: 'UNAVAILABLE', detail: 'Endpoint returned an invalid payload.' };
  if (!response.ok) {
    throw new Error(String(envelope.detail || envelope.message || `quantd HTTP ${response.status}`));
  }
  return envelope;
}

export function QuantOperatingSystem() {
  const [tab, setTab] = useState<Tab>('overview');
  const [store, setStore] = useState<NativeOsStore>({});
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState<string[]>([]);
  const inFlight = useRef<AbortController | null>(null);

  const refresh = useCallback(async (background = false) => {
    if (!background) setLoading(true);
    inFlight.current?.abort();
    const controller = new AbortController();
    inFlight.current = controller;
    const definitions = tabRequests[tab];
    const results = await Promise.allSettled(
      definitions.map((definition) => fetchJson(definition.path, controller.signal)),
    );
    if (controller.signal.aborted) return;

    const next: Record<string, NativeResourceEnvelope> = {};
    const failures: string[] = [];
    results.forEach((result, index) => {
      const definition = definitions[index];
      if (result.status === 'fulfilled') {
        next[definition.key] = result.value;
        return;
      }
      const detail = result.reason instanceof Error ? result.reason.message : String(result.reason);
      failures.push(`${definition.key}: ${detail}`);
      next[definition.key] = {
        status: 'UNAVAILABLE',
        detail,
        endpoint: definition.path,
      };
    });
    setStore((current) => ({ ...current, ...next }));
    setErrors(failures);
    if (inFlight.current === controller) {
      inFlight.current = null;
      setLoading(false);
    }
  }, [tab]);

  useEffect(() => {
    void refresh();
    const intervalMs = tab === 'overview' || tab === 'state' ? 5_000 : 30_000;
    const timer = window.setInterval(() => {
      if (!document.hidden) void refresh(true);
    }, intervalMs);
    const handleVisibility = () => {
      if (!document.hidden) void refresh(true);
    };
    document.addEventListener('visibilitychange', handleVisibility);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', handleVisibility);
      inFlight.current?.abort();
    };
  }, [refresh, tab]);

  const live = (store.liveStatus || {}) as Json;
  const connected = String(live.status || '').startsWith('CONNECTED_');

  return (
    <div className={styles.os}>
      <header className={`${styles.osHeader} px-5 py-4 sm:px-7`}>
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className={styles.brandMark}>A7</div>
            <div>
              <p className={`${styles.brandTitle} text-sm font-semibold`}>AXIO7 · Native Quant OS</p>
              <p className={`${styles.brandSubtitle} mt-0.5 text-[10px]`}>MARKET MEMORY → STATE INFERENCE → ANALOG RETRIEVAL → OOS VALIDATION</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className={styles.livePill}>
              <span className={connected ? styles.liveDot : styles.waitingDot} />
              {connected ? 'Moomoo 实时行情在线' : '等待实时行情'}
            </span>
            <button onClick={() => void refresh()} aria-label="刷新当前工作台" className={styles.refresh}>
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>
      </header>

      <div className={`${styles.osGrid} grid min-h-[780px]`}>
        <aside className={`${styles.rail} border-b p-3 lg:border-b-0 lg:border-r`}>
          <nav className={`${styles.railNav} flex gap-1 overflow-x-auto lg:block lg:space-y-1`}>
            {navigation.map(([id, label, Icon]) => (
              <button
                key={id}
                onClick={() => setTab(id)}
                aria-current={tab === id ? 'page' : undefined}
                className={`${styles.navButton} ${tab === id ? styles.navActive : ''} flex shrink-0 items-center gap-3 rounded-lg px-3 py-2.5 text-[12px] lg:w-full`}
              >
                <Icon className="h-4 w-4" strokeWidth={1.8} />
                {label}
              </button>
            ))}
          </nav>
          <div className={`${styles.railNote} mt-6 hidden border-t px-3 pt-5 lg:block`}>
            <p className="text-[10px] leading-5">系统能力、数据物化和样本外证据分层显示。缺失证据保持 BLOCKED，不用默认值补洞。</p>
          </div>
        </aside>

        <main className={`${styles.workspace} p-4 sm:p-7 lg:p-9`}>
          <div className={styles.workspaceInner}>
            {errors.length ? (
              <div className={`${styles.errorBanner} mb-5 flex gap-3 rounded-xl p-4 text-sm`}>
                <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
                <span>部分数据暂时不可用：{errors.join('；')}</span>
              </div>
            ) : null}
            {tab === 'overview' ? <ForecastWorkspace store={store} /> : null}
            {tab === 'memory' ? <MarketMemoryWorkspace store={store} /> : null}
            {tab === 'events' ? <EventAtlasWorkspace store={store} /> : null}
            {tab === 'analogs' ? <AnalogExplorerWorkspace store={store} /> : null}
            {tab === 'state' ? <StateEngineWorkspace store={store} /> : null}
            {tab === 'motifs' ? <MotifAnomalyWorkspace store={store} /> : null}
            {tab === 'strategyRisk' ? <StrategyRiskWorkspace store={store} /> : null}
            {tab === 'research' ? <ResearchFactoryWorkspace store={store} /> : null}
            {tab === 'audit' ? <AuditRuntimeWorkspace store={store} /> : null}
          </div>
        </main>
      </div>
    </div>
  );
}

function ForecastWorkspace({ store }: { store: NativeOsStore }) {
  const [asset, setAsset] = useState<ForecastAsset>('SPY');
  const liveForecastByAsset: Record<ForecastAsset, NativeForecastResource | undefined> = {
    SPY: store.forecast,
    QQQ: store.forecastQqq,
    SOXX: store.forecastSoxx,
    NVDA: store.forecastNvda,
    MU: store.forecastMu,
    AAPL: store.forecastAapl,
  };
  const ownerForecastByAsset: Record<ForecastAsset, NativeForecastResource | undefined> = {
    SPY: store.ownerForecast,
    QQQ: store.ownerForecastQqq,
    SOXX: store.ownerForecastSoxx,
    NVDA: store.ownerForecastNvda,
    MU: store.ownerForecastMu,
    AAPL: store.ownerForecastAapl,
  };
  const ownerForecast = ownerForecastByAsset[asset];
  const forecast = ownerForecast?.prediction_layer?.length
    ? ownerForecast
    : liveForecastByAsset[asset] ?? {};
  const rows = [...(forecast.prediction_layer ?? [])].sort((left, right) => compareHorizons(left.horizon_minutes, right.horizon_minutes));
  const live = jsonRecord(store.liveStatus);
  const liveBars = jsonRows(store.liveBars?.bars);
  const latestAssetBar = [...liveBars]
    .reverse()
    .find((row) => textValue(liveBarPayload(row).symbol).toUpperCase() === `US.${asset}`);
  const latestAssetUpdate = liveBarPayload(latestAssetBar);
  const latest = rows[0];
  const reference = finiteNumber(latest?.reference_price);
  const generatedAt = textValue(forecast.generated_at) || textValue(latest?.created_at);
  const previewMode = textValue(forecast.preview_mode);
  const ownerPreview = forecast.owner_only === true;
  const forecastScope = ownerPreview
    ? previewMode === 'DETERMINISTIC_REPLAY'
      ? 'OWNER ONLY - HISTORICAL REPLAY - NOT LIVE'
      : 'OWNER ONLY - MOOMOO LIVE FORWARD SHADOW'
    : 'Causal live conditional research - 5-60 min';
  const headline = predictionHeadline(rows);
  const behavioralState = forecast.behavioral_state_layer;
  const assetDescriptions: Record<ForecastAsset, string> = {
    SPY: '使用已完成的实时 bars，对 SPY（SPX 方向代理）的未来 5–60 分钟条件分布进行研究。',
    QQQ: '使用 QQQ 自身已完成的实时 bars，研究 Nasdaq-100 代理的未来 5–60 分钟条件分布。',
    SOXX: '使用 SOXX 自身已完成的实时 bars，独立研究半导体 ETF 的未来 5–60 分钟条件分布。',
    NVDA: '使用 NVDA 自身已完成的实时 bars，研究其未来 5–60 分钟条件分布。',
    MU: '使用 MU 自身已完成的实时 bars，研究其未来 5–60 分钟条件分布。',
    AAPL: '使用 AAPL 自身已完成的实时 bars，研究其未来 5–60 分钟条件分布。',
  };

  return (
    <div className="space-y-5">
      <section className={styles.forecastHero}>
        <div className={styles.forecastCopy}>
          <div>
            <p className={styles.eyebrow}>{forecastScope}</p>
            <div className={styles.assetSelector} aria-label="选择研究标的">
            {([
              ['SPY', 'SPX / SPY'],
              ['QQQ', 'QQQ'],
              ['SOXX', 'SOXX'],
              ['NVDA', 'NVDA'],
              ['MU', 'MU'],
              ['AAPL', 'AAPL'],
            ] as Array<[ForecastAsset, string]>).map(([symbol, label]) => (
              <button
                key={symbol}
                onClick={() => setAsset(symbol)}
                aria-pressed={asset === symbol}
                className={`${styles.assetButton} ${asset === symbol ? styles.assetActive : ''}`}
              >
                {label}
              </button>
            ))}
            </div>
            <p className={styles.heroDescription}>{assetDescriptions[asset]}</p>
            <h1 className={styles.heroHeadline}>{headline}</h1>
          </div>
          <div className={styles.priceLine}>
            <div>
              <p className={styles.priceLabel}>CURRENT REFERENCE · RUST FIELD</p>
              <p className={styles.priceValue}>{moneyPrice(reference)}</p>
            </div>
            <p className={styles.priceTime}>{generatedAt ? `${formatEt(generatedAt)} ET · UPDATED` : 'DATA UNAVAILABLE'}</p>
          </div>
        </div>
        <MarketEmotionPanel layer={behavioralState} />
      </section>

      {rows.length ? (
        <section className="overflow-hidden rounded-2xl border border-[#d9d9d5] bg-white">
          <div className="border-b border-[#ecece8] px-5 py-4 sm:px-6">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <h2 className="font-semibold tracking-[-0.01em]">Rust 原生收益分布与价格参考场景</h2>
                <p className="mt-1 text-xs leading-5 text-[#85888d]">收益标签是 next-1m open → horizon close；未来 entry price 在 cutoff 时未知，因此 expected_price 被 withheld。Rust 仅提供 current-close arithmetic reference scenario，前端不重算，也不把它冒充可执行终值预测。</p>
              </div>
              <span className="rounded-full bg-[#f2f2ef] px-3 py-1 text-[11px] text-[#686b70]">{textValue(forecast.status) || 'UNAVAILABLE'}</span>
            </div>
          </div>
          <div className="grid divide-y divide-[#ecece8] xl:grid-cols-2 xl:divide-x xl:divide-y-0">
            {rows.map((row, index) => (
              <PriceForecastCard
                key={textValue(row.prediction_id) || `${horizonLabel(row.horizon_minutes)}-${index}`}
                row={row}
                emphasized={index === rows.length - 1}
              />
            ))}
          </div>
        </section>
      ) : (
        <WaitingForForecast live={live} />
      )}

      {rows.length ? <NarrativeBrief rows={rows} /> : null}
      <ModelEvidenceComparison row={rows[rows.length - 1]} />

      <div className="grid gap-5 xl:grid-cols-[1.1fr_.9fr]">
        <HmmStatePanel row={rows[rows.length - 1]} />
        <ExecutionSeparation rows={rows} store={store} />
      </div>

      <RealtimeEvidence live={live} store={store} latestAssetBar={latestAssetBar} symbol={asset} />
    </div>
  );
}

function MarketEmotionPanel({ layer }: { layer?: NativeBehavioralStateLayer }) {
  const publication = layer?.market_emotion_proxy;
  const available = textValue(publication?.publication_status) === 'AVAILABLE_PARTIAL_PRICE_FLOW_PROXY';
  const rawIndex = available ? rawIndexValue(publication?.raw_compatibility_index) : null;
  const dominant = available ? textValue(publication?.dominant_market_response_pattern) : '';
  const rawScores = available
    ? (layer?.behavioral_regime?.raw_scores ?? [])
        .filter((row): row is NativeBehavioralRegimeScore => rawIndexValue(row.raw_score) != null)
        .slice(0, 3)
    : [];
  const reason = publication?.reason_codes?.[0] || 'MARKET_EMOTION_PROXY_UNAVAILABLE';
  const ringStyle = {
    '--emotion-score': rawIndex == null ? '0%' : `${rawIndex}%`,
  } as CSSProperties;

  return (
    <aside className={styles.emotionPanel} aria-label="Market Emotion market-response proxy">
      <div>
        <div className={styles.emotionHeader}>
          <div>
            <p className={styles.emotionKicker}>Market Emotion</p>
            <p className="mt-1 text-[9px] text-[#8a8d92]">RUST · MARKET-RESPONSE PROXY</p>
          </div>
          <span className={styles.emotionStatus}>{textValue(publication?.publication_status) || 'WITHHELD'}</span>
        </div>

        <div className={styles.emotionCore}>
          <div className={styles.emotionRing} style={ringStyle}>
            <span className={styles.emotionValue}>
              {rawIndex == null ? '—' : rawIndex.toFixed(0)}
              {rawIndex == null ? null : <small>/100</small>}
            </span>
          </div>
          <div>
            <Gauge className="mb-3 h-4 w-4 text-[#e1bf8f]" aria-hidden="true" />
            <p className={styles.emotionLabel}>
              {available ? marketEmotionLabel(dominant) : 'Withheld'}
            </p>
            <p className={styles.emotionMeta}>
              {available
                ? `raw compatibility · separation ${decimal(publication?.score_margin, 1)} pts`
                : reason}
            </p>
          </div>
        </div>

        {rawScores.length ? (
          <div className={styles.emotionScores} aria-label="Top market-response compatibility scores">
            {rawScores.map((row, index) => {
              const score = rawIndexValue(row.raw_score) as number;
              return (
                <div className={styles.emotionScoreRow} key={`${textValue(row.regime)}-${index}`}>
                  <span>{marketEmotionShortLabel(textValue(row.regime))}</span>
                  <span className={styles.emotionTrack}>
                    <span className={styles.emotionFill} style={{ width: `${score}%` }} />
                  </span>
                  <span className="text-right font-mono">{score.toFixed(0)}</span>
                </div>
              );
            })}
          </div>
        ) : (
          <p className="text-[10px] leading-5 text-[#85888d]">
            缺失、未核验、覆盖不足或形态分离太低时，Rust 会把指数与标签一起撤回。
          </p>
        )}
      </div>

      <p className={styles.emotionCaveat}>
        {available
          ? `as_of ${formatEt(publication?.as_of)} ET · price/flow coverage ${probability(publication?.price_flow_feature_coverage_ratio)} · full-domain coverage ${probability(publication?.required_domain_coverage_ratio)} · NOT A DIRECT PSYCHOLOGY OBSERVATION · NOT A PROBABILITY`
          : 'NOT A DIRECT PSYCHOLOGY OBSERVATION · NOT A PROBABILITY · DOES NOT IDENTIFY WHO IS BUYING OR SELLING'}
      </p>
    </aside>
  );
}

function PriceForecastCard({ row, emphasized }: { row: NativeForecastRow; emphasized: boolean }) {
  const promoted = hasPromotedProbabilityCalibration(row);
  const calibration = row.probability_calibration;
  const outcome = middleEightyOutcomeInterval(row.outcome_prediction_intervals);
  const calibrationStatus = textValue(calibration?.status) || textValue(row.calibration_status) || 'UNAVAILABLE';
  const probabilityPublication = promoted
    ? 'BINARY_P_UP_CALIBRATION_PUBLISHED_ONLY'
    : 'WITHHELD_UNTIL_PROMOTED_OOS_CALIBRATION';

  return (
    <article className={`p-5 sm:p-6 ${emphasized ? 'bg-[#fbfcfa]' : ''}`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-medium text-[#85888d]">未来 {horizonLabel(row.horizon_minutes)} 分钟 · {formatEt(row.label_end)} ET</p>
          <p className={`mt-2 text-xs font-semibold ${promoted ? 'text-[#316b56]' : 'text-[#8a622f]'}`}>{probabilityPublication}</p>
        </div>
        <div className="text-right">
          <p className="text-[10px] uppercase tracking-[0.1em] text-[#9a9da2]">Current-close reference scenario</p>
          <p className="mt-1 font-mono text-2xl font-semibold tracking-[-0.035em]">{moneyPrice(row.current_close_reference_scenario_expected_price)}</p>
          <p className="mt-1 text-xs text-[#65686e]">expected_return {signedPercent(row.expected_return)}</p>
        </div>
      </div>

      <div className="mt-5 rounded-xl border border-[#e6e6e1] bg-[#f8f8f5] p-4">
        <p className="text-[11px] font-semibold text-[#4f5257]">kernel analogue 中间80%结果范围，非 confidence/conformal</p>
        {outcome ? (
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            <MiniFact label="Return range" value={`${signedPercent(outcome.lower_return)} – ${signedPercent(outcome.upper_return)}`} />
            <MiniFact label="Current-close scenario price range" value={`${moneyPrice(outcome.current_close_reference_scenario_lower_price)} – ${moneyPrice(outcome.current_close_reference_scenario_upper_price)}`} />
            <MiniFact label="Method / status" value={`${textValue(outcome.method) || 'unavailable'} · ${textValue(outcome.status) || 'UNAVAILABLE'}`} />
            <MiniFact label="Probability mass" value={probability(outcome.probability_mass)} />
          </div>
        ) : (
          <p className="mt-3 text-xs text-[#8a8d92]">unavailable：Rust 未提供 probability_mass=0.8 的 outcome_prediction_intervals。</p>
        )}
        <p className="mt-3 text-[11px] leading-5 text-[#85888d]">return_definition: {textValue(row.return_definition) || 'unavailable'} · price scenario: {textValue(row.current_close_reference_scenario_status) || 'unavailable'}{outcome?.semantics ? ` · ${outcome.semantics}` : ''}</p>
      </div>

      {promoted ? (
        <div className="mt-4 rounded-xl border border-[#cfe1d7] bg-[#f3faf6] p-4">
          <p className="text-[11px] font-semibold text-[#315f4e]">Promoted binary P(up) · Down / Flat 未做联合校准</p>
          <div className="mt-3 grid gap-3 text-[11px] sm:grid-cols-2">
            <MiniFact label="Up · calibrated" value={probability(row.calibrated_probability_up ?? calibration?.calibrated_probability_up)} />
            <MiniFact
              label="OOS reliability-bin 95% sampling range"
              value={calibration?.calibrated_probability_up_interval
                ? `[${probability(calibration.calibrated_probability_up_interval.lower)}, ${probability(calibration.calibrated_probability_up_interval.upper)}]`
                : 'unavailable'}
            />
          </div>
          <p className="mt-3 text-[11px] leading-5 text-[#557064]">calibration_status: {calibrationStatus} · method: {textValue(calibration?.method) || 'unavailable'}。该区间来自 OOS reliability bin 的抽样误差，不包含 drift / model-selection uncertainty，也不是三分类联合 confidence。</p>
        </div>
      ) : (
        <div className="mt-4 rounded-xl border border-[#ead7b9] bg-[#fff9ef] p-4 text-[#75562c]">
          <p className="text-xs font-semibold">方向概率 withheld</p>
          <p className="mt-1 text-[11px] leading-5">未发现 eligible_for_probability_use=true 的 promoted OOS calibration；不得把 raw frequency 当成涨跌概率，也不生成 bullish / bearish 标题。status: {calibrationStatus}</p>
        </div>
      )}

      <div className="mt-4">
        <RawKernelFrequencyIntervals kernel={row.kernel_regression} compact />
      </div>
      <p className="mt-4 border-t border-[#ecece8] pt-3 text-[11px] leading-5 text-[#85888d]">kernel neighbors {integerValue(row.kernel_regression?.neighbor_count)} · ESS {decimal(row.kernel_regression?.effective_sample_size, 2)} · epistemic {decimal(row.epistemic_uncertainty, 3)} · OOD {decimal(row.ood_score, 3)}</p>
    </article>
  );
}

function NarrativeBrief({ rows }: { rows: NativeForecastRow[] }) {
  return (
    <section className="rounded-2xl border border-[#cfd9d3] bg-[#f5faf7] p-5 sm:p-6">
      <div className="flex gap-3">
        <Waves className="mt-0.5 h-5 w-5 shrink-0 text-[#497764]" />
        <div className="min-w-0">
          <h2 className="font-semibold text-[#244c3d]">模型原生输出摘要</h2>
          <p className="mt-1 text-[11px] leading-5 text-[#557064]">只转述 Rust 字段；不在浏览器重算价格、概率或方向。</p>
          <div className="mt-3 space-y-2">
            {rows.map((row, index) => {
              const promoted = hasPromotedProbabilityCalibration(row);
              const calibratedUp = calibratedUpProbability(row);
              const outcome = middleEightyOutcomeInterval(row.outcome_prediction_intervals);
              return (
                <p key={textValue(row.prediction_id) || `${horizonLabel(row.horizon_minutes)}-${index}`} className="text-sm leading-6 text-[#3f5f53]">
                  {horizonLabel(row.horizon_minutes)} 分钟：next-open 基准 expected_return {signedPercent(row.expected_return)}；current-close 参考场景 {moneyPrice(row.current_close_reference_scenario_expected_price)}（非 label-aligned expected price）；{promoted ? `已校准 binary P(up) ${probability(calibratedUp)} 可发布，Down / Flat 与整体方向未联合校准` : '方向概率 withheld（未 promoted）'}；kernel analogue 中间 80% 结果范围为 return {outcome ? `${signedPercent(outcome.lower_return)} – ${signedPercent(outcome.upper_return)}` : 'unavailable'}、current-close scenario price {outcome ? `${moneyPrice(outcome.current_close_reference_scenario_lower_price)} – ${moneyPrice(outcome.current_close_reference_scenario_upper_price)}` : 'unavailable'}。
                </p>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}

function ModelEvidenceComparison({ row }: { row?: NativeForecastRow }) {
  if (!row) {
    return <Panel title="12D kernel evidence vs SDE shadow" subtitle="两层证据尚未到达"><p className="text-sm text-[#777a80]">unavailable</p></Panel>;
  }
  const kernel = row.kernel_regression;
  const sde = row.stochastic_research_layer;
  const sdeForecast = sde?.horizon_forecast;
  const direction = sdeForecast?.direction_probabilities;
  const intervals = sdeForecast?.central_prediction_intervals ?? [];
  const affectsDecision = sde?.affects_decision;

  return (
    <Panel title="12D kernel evidence vs SDE shadow" subtitle="两层并列审计、不得混合：kernel 是主条件分布证据；SDE uncalibrated / affects_decision=false，且不得改变决策。">
      <div className="grid gap-4 xl:grid-cols-2">
        <div className="rounded-xl border border-[#dfe4e1] bg-[#f8faf8] p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-sm font-semibold text-[#315f4e]">12D kernel evidence</h3>
            <span className="rounded-full bg-white px-2.5 py-1 text-[10px] text-[#557064]">{textValue(kernel?.status) || 'UNAVAILABLE'}</span>
          </div>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <MiniFact label="Feature dimensions" value={integerValue(kernel?.feature_dimension_count)} />
            <MiniFact label="Selected dimensions" value={kernel?.selected_dimensions?.length ? kernel.selected_dimensions.join(', ') : 'unavailable'} />
            <MiniFact label="Metric / kernel" value={`${textValue(kernel?.metric) || 'unavailable'} · ${textValue(kernel?.kernel) || 'unavailable'}`} />
            <MiniFact label="Bandwidth" value={decimal(kernel?.bandwidth, 6)} />
            <MiniFact label="Neighbors / ESS" value={`${integerValue(kernel?.neighbor_count)} / ${decimal(kernel?.effective_sample_size, 2)}`} />
            <MiniFact label="NW expected return" value={signedPercent(kernel?.nadaraya_watson_expected_return)} />
            <MiniFact label="Local-linear intercept" value={signedPercent(kernel?.local_linear_intercept)} />
            <MiniFact label="Direction threshold" value={signedPercent(kernel?.direction_event_threshold_return)} />
            <MiniFact label="Return definition" value={textValue(row.return_definition) || 'unavailable'} />
          </div>
          <div className="mt-4">
            <RawKernelFrequencyIntervals kernel={kernel} />
          </div>
        </div>

        <div className={`rounded-xl border p-4 ${affectsDecision === false ? 'border-[#e2d8c7] bg-[#fffaf2]' : 'border-[#e5c6bd] bg-[#fff7f4]'}`}>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-sm font-semibold text-[#75562c]">SDE shadow · uncalibrated</h3>
            <span className="rounded-full bg-white px-2.5 py-1 text-[10px] text-[#75562c]">{textValue(sde?.status) || 'UNAVAILABLE'}</span>
          </div>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <MiniFact label="Model family" value={textValue(sde?.model_family) || 'unavailable'} />
            <MiniFact label="affects_decision" value={booleanLabel(affectsDecision)} />
            <MiniFact label="Horizon" value={`${horizonLabel(sdeForecast?.horizon_minutes)}m`} />
            <MiniFact label="Martingale audit" value={textValue(sde?.martingale_audit_status) || 'UNAVAILABLE'} />
            <MiniFact label="SDE Up / Flat / Down" value={`${probability(direction?.p_up)} / ${probability(direction?.p_flat)} / ${probability(direction?.p_down)}`} />
            <MiniFact label="Material move log thresholds" value={`${signedPercent(direction?.material_move_lower_threshold_log_return)} / ${signedPercent(direction?.material_move_upper_threshold_log_return)}`} />
            <MiniFact label="Method / status" value={`${textValue(direction?.method) || 'unavailable'} · ${textValue(direction?.status) || 'UNAVAILABLE'}`} />
            <MiniFact label="Probability semantics" value={textValue(direction?.semantics) || textValue(sde?.probability_semantics) || 'unavailable'} />
          </div>
          <div className="mt-4 border-t border-[#eadfce] pt-4">
            <p className="text-[11px] font-semibold text-[#75562c]">SDE central prediction intervals · 非 confidence / conformal</p>
            {intervals.length ? (
              <div className="mt-3 space-y-2">
                {intervals.map((interval, index) => <SdeIntervalRow key={`${probability(interval.probability_mass)}-${index}`} interval={interval} />)}
              </div>
            ) : (
              <p className="mt-2 text-xs text-[#8a7558]">unavailable</p>
            )}
          </div>
          <p className="mt-4 text-[11px] leading-5 text-[#8a7558]">research_policy: {textValue(sde?.research_policy) || 'unavailable'}。此层不得改变 decision；若 affects_decision 不是 false，界面会保留警示而不推断其含义。</p>
        </div>
      </div>
    </Panel>
  );
}

function RawKernelFrequencyIntervals({ kernel, compact = false }: { kernel?: NativeKernelRegression; compact?: boolean }) {
  const intervals = kernel?.direction_probability_intervals;
  const entries: Array<[string, NativeProbabilityEstimateInterval | undefined]> = [
    ['Up', intervals?.up],
    ['Flat', intervals?.flat],
    ['Down', intervals?.down],
  ];
  const available = entries.some(([, interval]) => interval != null);
  return (
    <div className="rounded-xl border border-[#e5ddd0] bg-[#fffaf3] p-3.5">
      <p className="text-[11px] font-semibold text-[#75562c]">Raw Up / Flat / Down 95% Wilson ranges</p>
      <p className="mt-1 text-[10px] leading-4 text-[#8a7558]">未校准历史核频率估计区间；不是 promoted 方向概率，也不是策略 confidence。</p>
      {available ? (
        <div className={`mt-3 grid gap-2 ${compact ? 'grid-cols-1' : 'sm:grid-cols-3'}`}>
          {entries.map(([label, interval]) => (
            <div key={label} className="rounded-lg bg-white p-3">
              <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[#8a7558]">{label}</p>
              <p className="mt-1 font-mono text-xs text-[#4f5257]">estimate {probability(interval?.estimate)}</p>
              <p className="mt-1 font-mono text-[11px] text-[#65686e]">[{probability(interval?.lower)}, {probability(interval?.upper)}]</p>
              <p className="mt-2 text-[10px] leading-4 text-[#8a8d92]">level {probability(interval?.confidence_level)} · ESS {decimal(interval?.effective_sample_size, 2)}</p>
              <p className="mt-1 break-words text-[10px] leading-4 text-[#8a8d92]">{textValue(interval?.method) || 'unavailable'} · {textValue(interval?.status) || 'UNAVAILABLE'}</p>
            </div>
          ))}
        </div>
      ) : (
        <p className="mt-3 text-xs text-[#8a7558]">unavailable</p>
      )}
    </div>
  );
}

function SdeIntervalRow({ interval }: { interval: NativeSdeCentralPredictionInterval }) {
  return (
    <div className="rounded-lg bg-white p-3 text-[11px] text-[#65686e]">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="font-semibold text-[#4f5257]">mass {probability(interval.probability_mass)}</span>
        <span>{textValue(interval.status) || 'UNAVAILABLE'}</span>
      </div>
      <p className="mt-1 font-mono">log return [{signedPercent(interval.lower_log_return)}, {signedPercent(interval.upper_log_return)}]</p>
      <p className="mt-1 break-words text-[10px] leading-4 text-[#8a8d92]">{textValue(interval.method) || 'unavailable'} · {textValue(interval.semantics) || 'unavailable'}</p>
    </div>
  );
}

function HmmStatePanel({ row }: { row?: NativeForecastRow }) {
  if (!row) return <Panel title="HMM 市场状态" subtitle="等待实时状态进入模型"><p className="text-sm text-[#777a80]">unavailable</p></Panel>;
  const filtered = finiteNumberArray(row.filtered_state_probabilities);
  const predicted = finiteNumberArray(row.predicted_state_probabilities);
  const currentTop = topState(filtered);
  const nextTop = topState(predicted);
  return (
    <Panel title="HMM：当前状态 → 下一状态" subtitle="Forward filtering 汇总所有可能历史路径；不是只取一条 Viterbi 路径。状态概率是 regime context，不是收益 confidence。">
      <div className="rounded-xl bg-[#f6f6f3] p-4">
        <div className="flex items-center justify-between gap-4">
          <div><p className="text-[10px] uppercase tracking-[0.1em] text-[#8a8d92]">当前最可能</p><p className="mt-1 text-lg font-semibold">{topStateLabel(currentTop)}</p></div>
          <ArrowUpRight className="h-5 w-5 rotate-45 text-[#a3a5a8]" />
          <div className="text-right"><p className="text-[10px] uppercase tracking-[0.1em] text-[#8a8d92]">下一步最可能</p><p className="mt-1 text-lg font-semibold">{topStateLabel(nextTop)}</p></div>
        </div>
      </div>
      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <StateBars title="当前过滤概率" values={filtered} />
        <StateBars title="下一状态概率" values={predicted} />
      </div>
      <p className="mt-4 text-[11px] leading-5 text-[#85888d]">状态编号按训练期统计特征固定排序，不直接等同于“牛/熊”。状态熵 {decimal(row.state_entropy, 3)}；熵越高，状态判断越不确定。</p>
    </Panel>
  );
}

function StateBars({ title, values }: { title: string; values: number[] }) {
  if (!values.length) return <div><p className="mb-2 text-[11px] font-medium text-[#777a80]">{title}</p><p className="text-xs text-[#8a8d92]">unavailable</p></div>;
  return <div><p className="mb-2 text-[11px] font-medium text-[#777a80]">{title}</p><div className="space-y-2">{values.map((value, index) => <div key={index} className="grid grid-cols-[24px_1fr_42px] items-center gap-2 text-[10px]"><span>S{index + 1}</span><div className="h-1.5 overflow-hidden rounded-full bg-[#ecece8]"><div className="h-full rounded-full bg-[#6f8079]" style={{ width: probabilityBarWidth(value) }} /></div><span className="text-right text-[#777a80]">{probability(value)}</span></div>)}</div></div>;
}

function ExecutionSeparation({ rows, store }: { rows: NativeForecastRow[]; store: NativeOsStore }) {
  const decisions = rows.map((row) => jsonRecord(row.decision)).filter((row) => Object.keys(row).length > 0);
  const decisionAvailable = decisions.length > 0;
  const eligible = decisions.some((row) => row.eligible === true);
  const reasons = Array.from(new Set(decisions.flatMap((row) => stringArray(row.no_trade_reasons))));
  const shadow = jsonRecord(store.shadow);
  const decisionTitle = !decisionAvailable ? '执行结论 unavailable' : eligible ? '存在 Rust 标记为 eligible 的候选' : '当前执行结论：不交易';
  const decisionDetail = !decisionAvailable ? 'Rust 未提供 decision；前端不会把缺失值解释成 NO_TRADE。' : eligible ? '仍处于 paper/shadow 模式。' : '条件分布可以正常生成；成本后优势、方向证据或独立验证仍可能不足。';
  return (
    <Panel title="预测与交易分开" subtitle="有预测，不代表此刻有足够优势值得下注。">
      <div className={`rounded-xl p-4 ${eligible ? 'bg-[#eef8f3] text-[#315f4e]' : 'bg-[#fff7ed] text-[#75562c]'}`}>
        <div className="flex items-center gap-2"><ShieldCheck className="h-4 w-4" /><p className="text-sm font-semibold">{decisionTitle}</p></div>
        <p className="mt-2 text-xs leading-5">{decisionDetail}</p>
      </div>
      <div className="mt-4 space-y-2">{reasons.slice(0, 5).map((reason) => <div key={reason} className="flex gap-2 text-xs leading-5 text-[#65686e]"><span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-[#aaa]" />{humanDecisionReason(reason)}</div>)}</div>
      <div className="mt-5 grid grid-cols-3 gap-3 border-t border-[#ecece8] pt-4 text-center"><MiniFact label="真实前瞻" value={integerValue(shadow.verified_moomoo_forward_predictions)} /><MiniFact label="已结算" value={integerValue(shadow.settled_forward_predictions)} /><MiniFact label="待验证" value={integerValue(shadow.pending_forward_predictions ?? shadow.pending)} /></div>
    </Panel>
  );
}

function RealtimeEvidence({ live, store, latestAssetBar, symbol }: { live: Json; store: NativeOsStore; latestAssetBar?: Json; symbol: ForecastAsset }) {
  const capabilities = jsonRecord(store.liveCapabilities);
  const update = liveBarPayload(latestAssetBar);
  return (
    <Panel title="实时输入证据" subtitle="只有当前交易日完成的一分钟 bar 才能触发预测。">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <MiniFact label="连接" value={textValue(live.status) || 'UNAVAILABLE'} />
        <MiniFact label={`最新 ${symbol} bar`} value={update.bar_end ? `${formatEt(update.bar_end)} ET` : 'unavailable'} />
        <MiniFact label="最新收盘" value={moneyPrice(update.close)} />
        <MiniFact label="行情覆盖" value={textValue(capabilities.market_coverage) || 'UNAVAILABLE'} />
        <MiniFact label="是否 NBBO" value={booleanChinese(capabilities.consolidated_nbbo)} />
      </div>
    </Panel>
  );
}

function liveBarPayload(row?: Json): Json {
  return jsonRecord(row?.update ?? row);
}

function WaitingForForecast({ live }: { live: Json }) {
  return <section className="rounded-2xl border border-[#e4d5bd] bg-[#fffaf2] p-6"><div className="flex gap-3"><Clock3 className="mt-0.5 h-5 w-5 text-[#9a743a]" /><div><h2 className="font-semibold text-[#71542b]">等待第一条完整实时分钟</h2><p className="mt-2 text-sm leading-6 text-[#806943]">行情连接状态：{textValue(live.status) || 'UNAVAILABLE'}。系统不会拿昨天收盘价或尚未结束的分钟提前写未来价格。</p></div></div></section>;
}

function Panel({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return <section className="rounded-2xl border border-[#d9d9d5] bg-white p-5 sm:p-6"><div className="mb-5"><h2 className="font-semibold tracking-[-0.01em]">{title}</h2>{subtitle ? <p className="mt-1 text-xs leading-5 text-[#85888d]">{subtitle}</p> : null}</div>{children}</section>;
}

function MiniFact({ label, value }: { label: string; value: string }) {
  return <div><p className="text-[10px] uppercase tracking-[0.1em] text-[#95989d]">{label}</p><p className="mt-1 break-words text-xs font-medium text-[#3e4145]">{value}</p></div>;
}

function hasPromotedProbabilityCalibration(row: NativeForecastRow) {
  const contractValue = finiteNumber(row.calibrated_probability_up);
  const runtimeValue = finiteNumber(row.probability_calibration?.calibrated_probability_up);
  return row.probability_calibration?.eligible_for_probability_use === true
    && textValue(row.probability_calibration?.status) === 'PROMOTED_OOS_CALIBRATION_APPLIED'
    && textValue(row.calibration_status) === 'PROMOTED_OOS_CALIBRATION_APPLIED'
    && textValue(row.published_probability_status) === 'PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION'
    && contractValue != null
    && runtimeValue != null
    && contractValue >= 0
    && contractValue <= 1
    && Math.abs(contractValue - runtimeValue) <= 1e-9;
}

function calibratedUpProbability(row: NativeForecastRow) {
  return finiteNumber(row.calibrated_probability_up)
    ?? finiteNumber(row.probability_calibration?.calibrated_probability_up);
}

function middleEightyOutcomeInterval(intervals?: NativeOutcomePredictionInterval[]) {
  return intervals?.find((interval) => finiteNumber(interval.probability_mass) === 0.8) ?? null;
}

function predictionHeadline(rows: NativeForecastRow[]) {
  if (!rows.length) return '正在等待新的实时市场状态';
  const longest = rows[rows.length - 1];
  const horizon = horizonLabel(longest.horizon_minutes);
  if (!hasPromotedProbabilityCalibration(longest)) return `未来 ${horizon} 分钟：方向概率暂不发布`;
  return `未来 ${horizon} 分钟：已校准 binary P(up) ${probability(calibratedUpProbability(longest))}；非整体方向结论`;
}

function topState(values: number[]): { index: number; value: number } | null {
  if (!values.length) return null;
  return values.reduce((best, value, index) => value > best.value ? { index, value } : best, { index: 0, value: values[0] });
}

function topStateLabel(state: { index: number; value: number } | null) {
  return state ? `S${state.index + 1} · ${probability(state.value)}` : 'unavailable';
}

function rawIndexValue(value: unknown) {
  const parsed = finiteNumber(value);
  return parsed != null && parsed >= 0 && parsed <= 100 ? parsed : null;
}

function marketEmotionLabel(value: string) {
  const labels: Record<string, string> = {
    STRESS_LIKE: '压力释放型',
    CHASE_LIKE: '追涨型',
    CROWDING_LIKE: '方向拥挤型',
    ATTENTION_SHOCK_LIKE: '注意力冲击型',
    REBOUND_SQUEEZE_LIKE: '反弹挤压型',
    MIXED_OR_CONFLICTED: '混合 / 冲突型',
  };
  return labels[value] || 'Unresolved pattern';
}

function marketEmotionShortLabel(value: string) {
  const labels: Record<string, string> = {
    STRESS_LIKE: 'STRESS',
    CHASE_LIKE: 'CHASE',
    CROWDING_LIKE: 'CROWDING',
    ATTENTION_SHOCK_LIKE: 'ATTENTION',
    REBOUND_SQUEEZE_LIKE: 'REBOUND',
    MIXED_OR_CONFLICTED: 'MIXED',
  };
  return labels[value] || value || 'UNKNOWN';
}

function humanDecisionReason(reason: string) {
  const map: Record<string, string> = {
    CONFIDENCE_BELOW_POLICY: '方向概率指标没有达到策略门槛',
    EDGE_BELOW_COST_AND_POLICY: '扣除价差、滑点和政策缓冲后，期望优势不足',
    INSUFFICIENT_EFFECTIVE_SAMPLE: '相似历史状态的有效独立样本不足',
    MODEL_NOT_PROMOTED_NO_OOS_EDGE: '模型尚未通过独立样本外晋级验证',
    OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED: '方向概率校准 artifact 尚未通过 promoted OOS 门槛',
  };
  return map[reason] || reason;
}

function compareHorizons(left: unknown, right: unknown) {
  const leftValue = finiteNumber(left);
  const rightValue = finiteNumber(right);
  if (leftValue == null && rightValue == null) return 0;
  if (leftValue == null) return 1;
  if (rightValue == null) return -1;
  return leftValue - rightValue;
}

function finiteNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function finiteNumberArray(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  const parsed = value.map(finiteNumber);
  return parsed.every((item): item is number => item != null) ? parsed : [];
}

function jsonRecord(value: unknown): Json {
  return value != null && typeof value === 'object' && !Array.isArray(value) ? value as Json : {};
}

function jsonRows(value: unknown): Json[] {
  return Array.isArray(value) ? value.map(jsonRecord).filter((row) => Object.keys(row).length > 0) : [];
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string' && item.length > 0) : [];
}

function textValue(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function horizonLabel(value: unknown) {
  const number = finiteNumber(value);
  return number == null ? 'unavailable' : number.toFixed(0);
}

function moneyPrice(value: unknown) {
  const number = finiteNumber(value);
  return number != null && number > 0 ? `$${number.toFixed(2)}` : 'unavailable';
}

function probability(value: unknown) {
  const number = finiteNumber(value);
  return number != null && number >= 0 && number <= 1 ? `${(number * 100).toFixed(1)}%` : 'unavailable';
}

function signedPercent(value: unknown) {
  const number = finiteNumber(value);
  return number == null ? 'unavailable' : `${number >= 0 ? '+' : ''}${(number * 100).toFixed(3)}%`;
}

function decimal(value: unknown, digits: number) {
  const number = finiteNumber(value);
  return number == null ? 'unavailable' : number.toFixed(digits);
}

function integerValue(value: unknown) {
  const number = finiteNumber(value);
  return number == null ? 'unavailable' : number.toFixed(0);
}

function booleanLabel(value: unknown) {
  if (value === true) return 'true · WARNING';
  if (value === false) return 'false · shadow only';
  return 'unavailable';
}

function booleanChinese(value: unknown) {
  if (value === true) return '是';
  if (value === false) return '否';
  return 'unavailable';
}

function probabilityBarWidth(value: number) {
  return `${Math.min(100, Math.max(0, value * 100))}%`;
}

function formatEt(value: unknown) {
  const raw = textValue(value);
  if (!raw) return 'unavailable';
  const date = new Date(raw);
  if (Number.isNaN(date.valueOf())) return 'unavailable';
  return new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'America/New_York',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(date);
}
