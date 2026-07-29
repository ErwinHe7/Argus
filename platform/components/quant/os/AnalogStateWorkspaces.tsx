import { ArrowRight, Beaker, GitBranch, History, Layers3, Network, Radar, ShieldCheck } from 'lucide-react';
import type { NativeOsStore } from '@/lib/quant/native-os-types';
import {
  AvailabilityBanner,
  DataTable,
  DecisionBanner,
  EvidenceFooter,
  FeatureStrip,
  KeyValueGrid,
  Metric,
  MetricGrid,
  ProbabilityBars,
  Section,
  SimilarityBars,
  TwoColumn,
  Workspace,
  compactPair,
  dateTime,
  decimal,
  duration,
  first,
  firstNumber,
  firstRecord,
  integer,
  isStrictlyAvailable,
  keyValueRows,
  percent,
  probabilityRows,
  record,
  rows,
  strings,
  text,
  transitionRows,
  yesNo,
} from './workspace-ui';

export function AnalogExplorerWorkspace({ store }: { store: NativeOsStore }) {
  const data = record(store.analogsCurrent);
  const analogRows = rows(data, ['analogs', 'top_analogs', 'results', 'prediction.analogs']);
  const diagnostics = firstRecord(data, ['diagnostics', 'analog_diagnostics', 'retrieval']);
  const kernel = firstRecord(data, ['kernel_regression']);
  const calibration = firstRecord(data, ['probability_calibration']);
  const directionIntervals = firstRecord(kernel, ['direction_probability_intervals']);
  const outcomeIntervals = rows(data, ['outcome_prediction_intervals']).map(record);
  const sensitivity = rows(data, ['sensitivity', 'k_bandwidth_sensitivity', 'diagnostics.sensitivity']);
  const firstAnalog = record(analogRows[0]);
  const similarities = keyValueRows(first(firstAnalog, ['feature_similarity', 'feature_level_similarity']));
  const explicitStatus = String(first(data, ['analog_status', 'status']) || 'UNKNOWN');
  const unreliable = /OUT_OF_DISTRIBUTION|NO_RELIABLE_ANALOG|BLOCKED|UNAVAILABLE/.test(explicitStatus.toUpperCase());
  const analogAgeMeanDays = firstNumber(diagnostics, ['analog_age_mean_days', 'age_mean_days']);
  const analogAgeMedianDays = firstNumber(diagnostics, ['analog_age_median_days', 'age_median_days']);
  const noTradeReasons = strings(first(data, ['no_trade_reasons', 'decision.no_trade_reasons']));
  const calibrationEligibility = first(calibration, ['eligible_for_probability_use']);
  const calibrationEligibilityLabel = calibrationEligibility === true ? 'true' : calibrationEligibility === false ? 'false' : 'unavailable';
  const calibrationStatus = text(first(calibration, ['status'])) || 'UNAVAILABLE';
  const contractProbabilityUp = firstNumber(data, ['calibrated_probability_up']);
  const runtimeProbabilityUp = firstNumber(calibration, ['calibrated_probability_up']);
  const probabilityPromoted = calibrationEligibility === true
    && calibrationStatus === 'PROMOTED_OOS_CALIBRATION_APPLIED'
    && contractProbabilityUp != null
    && runtimeProbabilityUp != null
    && contractProbabilityUp >= 0
    && contractProbabilityUp <= 1
    && Math.abs(contractProbabilityUp - runtimeProbabilityUp) <= 1e-9;
  const promotedProbabilityUp = probabilityPromoted ? contractProbabilityUp : undefined;
  const middleEighty = outcomeIntervals.find((row) => firstNumber(row, ['probability_mass']) === 0.8);
  const rawDirectionRows = ([
    ['Up', firstRecord(directionIntervals, ['up'])],
    ['Flat', firstRecord(directionIntervals, ['flat'])],
    ['Down', firstRecord(directionIntervals, ['down'])],
  ] as Array<[string, ReturnType<typeof record>]>).filter(([, interval]) => Object.keys(interval).length > 0);
  const reportedFractionPercent = (value: number | undefined) => value == null ? 'unavailable' : `${(value * 100).toFixed(2)}%`;
  const reportedProbability = (value: number | undefined) => value == null || value < 0 || value > 1 ? 'unavailable' : `${(value * 100).toFixed(2)}%`;
  const reportedDecimal = (value: number | undefined, digits: number) => value == null ? 'unavailable' : decimal(value, digits);
  const reportedInteger = (value: number | undefined) => value == null ? 'unavailable' : integer(value);
  const reportedPrice = (value: number | undefined) => value == null ? 'unavailable' : `$${value.toFixed(2)}`;
  const reportedReturnRange = (row: ReturnType<typeof record> | undefined) => row
    ? `${reportedFractionPercent(firstNumber(row, ['lower_return']))} – ${reportedFractionPercent(firstNumber(row, ['upper_return']))}`
    : 'unavailable';
  const reportedPriceRange = (row: ReturnType<typeof record> | undefined) => row
    ? `${reportedPrice(firstNumber(row, ['current_close_reference_scenario_lower_price']))} – ${reportedPrice(firstNumber(row, ['current_close_reference_scenario_upper_price']))}`
    : 'unavailable';
  return (
    <Workspace title="Historical Analog Explorer" eyebrow="Past-only conditional retrieval" description="只检索 decision_as_of 之前、且 forward label 已完全成熟的历史状态。相似 K 线不是故事素材，而是一组带权条件分布；未校准频率绝不冒充方向概率。">
      <AvailabilityBanner payload={data} expected="/analogs/current" />
      {unreliable ? <DecisionBanner title={explicitStatus} detail="当前环境与历史库的距离过大时，系统必须明确输出 NO RELIABLE ANALOG，而不是强行返回几个日期。" /> : null}
      {!probabilityPromoted ? <DecisionBanner title="Direction probability WITHHELD" detail={`eligible_for_probability_use is not true (${calibrationStatus}). Raw kernel frequencies remain visible only as uncalibrated historical estimates; no bullish / bearish conclusion is produced.`} /> : null}

      <Section title="查询上下文与 Rust 条件分布" icon={Radar} subtitle="decision timestamp、return definition 与 calibration lifecycle 必须同时可见；前端不重算价格或概率。">
        <KeyValueGrid items={[
          ['Symbol', first(data, ['symbol', 'target'])],
          ['Decision as-of', dateTime(first(data, ['decision_as_of', 'as_of']))],
          ['Horizon', first(data, ['horizon_label', 'horizon', 'horizon_minutes'])],
          ['Expected return', reportedFractionPercent(firstNumber(data, ['expected_return']))],
          ['Median return', reportedFractionPercent(firstNumber(data, ['median_return']))],
          ['Return definition', first(data, ['return_definition']) || 'unavailable'],
          ['Current-close reference scenario', reportedPrice(firstNumber(data, ['current_close_reference_scenario_expected_price']))],
          ['Price scenario status', first(data, ['current_close_reference_scenario_status']) || 'unavailable'],
          ['Price scenario semantics', first(data, ['current_close_reference_scenario_semantics']) || 'unavailable'],
          ['Promoted calibrated P(up)', probabilityPromoted ? reportedProbability(promotedProbabilityUp) : 'withheld · calibration not promoted'],
          ['Calibration status', calibrationStatus],
          ['Calibration eligible', calibrationEligibilityLabel],
          ['Kernel analogue middle 80% return range', reportedReturnRange(middleEighty)],
          ['Kernel analogue middle 80% current-close scenario range', reportedPriceRange(middleEighty)],
          ['Middle 80% semantics', middleEighty ? first(middleEighty, ['semantics']) : 'unavailable'],
          ['Dispersion', reportedFractionPercent(firstNumber(data, ['dispersion', 'uncertainty', 'prediction.dispersion']))],
          ['Evidence grade', first(data, ['evidence_grade', 'evidence'])],
        ]} />
        <p className="mt-4 rounded-lg border border-[#e4ddd2] bg-[#fffaf3] p-3 text-[11px] leading-5 text-[#75562c]">“kernel analogue 中间80%结果范围，非 confidence/conformal”——这是历史相似样本的结果范围。</p>
        <FeatureStrip title="No-trade reasons" values={noTradeReasons} empty="No explicit no-trade reason was returned." />
      </Section>

      <MetricGrid>
        <Metric label="Kernel neighbors" value={reportedInteger(firstNumber(kernel, ['neighbor_count']))} note="past-only matches" />
        <Metric label="Kernel ESS" value={reportedDecimal(firstNumber(kernel, ['effective_sample_size']), 2)} note="after kernel weights" />
        <Metric label="Feature dimensions" value={reportedInteger(firstNumber(kernel, ['feature_dimension_count']))} note="Rust field; expected 12D when that artifact is active" />
        <Metric label="Metric / kernel" value={compactPair(first(kernel, ['metric']), first(kernel, ['kernel']))} note={`bandwidth ${reportedDecimal(firstNumber(kernel, ['bandwidth']), 6)}`} />
        <Metric label="OOD score" value={reportedDecimal(firstNumber(data, ['ood_score', 'diagnostics.ood_score']), 3)} note={explicitStatus} />
        <Metric label="NW expected return" value={reportedFractionPercent(firstNumber(kernel, ['nadaraya_watson_expected_return']))} note="Rust Nadaraya–Watson output" />
        <Metric label="Local-linear intercept" value={reportedFractionPercent(firstNumber(kernel, ['local_linear_intercept']))} note="diagnostic; not recomputed in UI" />
        <Metric label="Direction threshold" value={reportedFractionPercent(firstNumber(kernel, ['direction_event_threshold_return']))} note="raw event definition" />
      </MetricGrid>

      <Section title="未校准历史核频率估计区间" icon={ShieldCheck} subtitle="Raw Up / Flat / Down 95% Wilson ranges。它们描述 kernel 历史频率估计，不是 promoted 涨跌概率，也不是 strategy confidence。">
        <DataTable
          columns={['Direction', 'Raw estimate', '95% Wilson range', 'Confidence level', 'ESS', 'Method', 'Status', 'Semantics']}
          empty="Rust did not emit direction_probability_intervals; raw frequency intervals are unavailable."
          rows={rawDirectionRows.map(([label, interval]) => [
            label,
            reportedProbability(firstNumber(interval, ['estimate'])),
            `${reportedProbability(firstNumber(interval, ['lower']))} – ${reportedProbability(firstNumber(interval, ['upper']))}`,
            reportedProbability(firstNumber(interval, ['confidence_level'])),
            reportedDecimal(firstNumber(interval, ['effective_sample_size']), 2),
            text(first(interval, ['method'])) || 'unavailable',
            text(first(interval, ['status'])) || 'UNAVAILABLE',
            text(first(interval, ['semantics'])) || 'unavailable',
          ])}
        />
        <FeatureStrip title="Selected kernel dimensions" values={strings(first(kernel, ['selected_dimensions']))} empty="selected_dimensions unavailable" />
      </Section>

      <Section title="Kernel analogue outcome intervals" icon={Layers3} subtitle="收益范围直接来自 next-open→horizon-close 标签；价格列只是 Rust 的 current-close arithmetic reference scenario，不是 label-aligned expected/executable price，也不是 confidence / conformal interval。">
        <DataTable
          columns={['Probability mass', 'Return range', 'Current-close scenario price', 'Method', 'Status', 'Semantics']}
          empty="No Rust outcome_prediction_intervals were emitted."
          rows={outcomeIntervals.map((row) => [
            reportedProbability(firstNumber(row, ['probability_mass'])),
            reportedReturnRange(row),
            reportedPriceRange(row),
            text(first(row, ['method'])) || 'unavailable',
            text(first(row, ['status'])) || 'UNAVAILABLE',
            text(first(row, ['semantics'])) || 'unavailable',
          ])}
        />
      </Section>

      <Section title="Top historical environments" icon={History} subtitle="Timestamp, distance, kernel weight and subsequent realized path remain attached to every analog ID.">
        <DataTable
          columns={['Rank', 'Snapshot / trace ID', 'Timestamp', 'Distance', 'Weight', 'Regime match', 'Forward return', 'MFE', 'MAE', 'Path status']}
          empty="No reliable historical analogs were returned."
          rows={analogRows.map((value, index) => {
            const row = record(value);
            return [
              `#${integer(firstNumber(row, ['rank'])) || index + 1}`,
              text(first(row, ['market_snapshot_id', 'snapshot_id', 'derived_trace_id', 'legacy_analog_id', 'analog_id', 'id'])) || '—',
              dateTime(first(row, ['analog_timestamp', 'timestamp', 'analog_date'])),
              decimal(firstNumber(row, ['distance']), 4),
              decimal(firstNumber(row, ['weight']), 4),
              decimal(firstNumber(row, ['regime_similarity', 'state_similarity']), 3),
              percent(firstNumber(row, ['forward_return', 'subsequent_return'])),
              percent(firstNumber(row, ['mfe'])),
              percent(firstNumber(row, ['mae'])),
              text(first(row, ['path_status', 'label_status'])) || 'matured',
            ];
          })}
        />
      </Section>

      <TwoColumn>
        <Section title="Feature-level similarity" icon={Radar} subtitle="A high aggregate score can hide one dangerously dissimilar state variable.">
          <SimilarityBars rows={similarities} />
        </Section>
        <Section title="Retrieval diagnostics" icon={ShieldCheck} subtitle="Distance concentration and period dependence expose fragile nearest-neighbor stories.">
          <KeyValueGrid items={[
            ['Kernel status', first(kernel, ['status']) || 'UNAVAILABLE'],
            ['Concentration penalty', decimal(firstNumber(diagnostics, ['concentration_penalty', 'distance_concentration', 'concentration']), 3)],
            ['Maximum day weight', percent(firstNumber(diagnostics, ['max_day_weight', 'maximum_day_weight']))],
            ['Analog age mean', analogAgeMeanDays == null ? 'unavailable' : `${decimal(analogAgeMeanDays, 1)}d`],
            ['Analog age median', analogAgeMedianDays == null ? 'unavailable' : `${decimal(analogAgeMedianDays, 1)}d`],
            ['Dominant period share', percent(firstNumber(diagnostics, ['dominant_period_share', 'max_period_share']))],
            ['Same-day overlap', percent(firstNumber(diagnostics, ['same_day_overlap', 'overlap_share']))],
            ['Regime conditioned', yesNo(first(diagnostics, ['regime_conditioned']))],
            ['Time-of-day conditioned', yesNo(first(diagnostics, ['time_of_day_conditioned']))],
            ['Scaler fit', first(diagnostics, ['scaler_fit', 'scaler_scope']) || 'train only expected'],
            ['Feature selection', first(diagnostics, ['feature_selection_scope']) || 'train only expected'],
          ]} />
          <FeatureStrip title="Known retrieval limitations" values={strings(first(diagnostics, ['limitations']))} empty="No retrieval limitation metadata was returned." />
        </Section>
      </TwoColumn>

      <Section title="Sensitivity to K and bandwidth" icon={GitBranch} subtitle="Raw frequency is explicitly uncalibrated. A conditional mean or frequency that flips under small reasonable retrieval changes is not stable enough to trade.">
        <DataTable
          columns={['K', 'Bandwidth', 'ESS', 'Expected return', 'Raw up frequency (uncalibrated)', 'Dispersion', 'Decision']}
          empty="K / bandwidth sensitivity has not been computed."
          rows={sensitivity.map((value) => {
            const row = record(value);
            return [
              integer(firstNumber(row, ['k', 'neighbors'])),
              decimal(firstNumber(row, ['bandwidth']), 4),
              decimal(firstNumber(row, ['effective_sample_size', 'ess']), 1),
              percent(firstNumber(row, ['expected_return', 'mean'])),
              reportedProbability(firstNumber(row, ['raw_analog_up_frequency'])),
              percent(firstNumber(row, ['dispersion', 'std'])),
              text(first(row, ['decision', 'status'])) || '—',
            ];
          })}
        />
      </Section>

      <EvidenceFooter payload={data} label="Analog retrieval evidence" />
    </Workspace>
  );
}
export function StateEngineWorkspace({ store }: { store: NativeOsStore }) {
  const data = record(store.stateCurrent);
  const stateStatus = (text(first(data, ['status.status', 'status'])) || 'UNAVAILABLE_STATUS_MISSING').toUpperCase();
  const integrityFreshness = firstRecord(data, ['freshness']);
  if (!isStrictlyAvailable(data)) {
    return (
      <Workspace title="Market State Engine" eyebrow="HMM is context, not a price target" description="Latent-state probabilities stay hidden unless the state resource is explicitly AVAILABLE.">
        <AvailabilityBanner payload={data} expected="/state/current" />
        <DecisionBanner
          title={`State probabilities unavailable (${stateStatus})`}
          detail="Current, next-state, and horizon probabilities are suppressed because artifact integrity or availability is not fully established."
        />
        <Section title="State artifact integrity" icon={ShieldCheck} subtitle="Only integrity, caveat, and unavailable-state metadata are shown while the resource is not AVAILABLE.">
          <KeyValueGrid items={[
            ['Endpoint schema', first(data, ['schema_version'])],
            ['Artifact schema', first(data, ['artifact_schema_version'])],
            ['Observation cutoff', dateTime(first(data, ['observation_cutoff', 'as_of']))],
            ['Latest input available-at', dateTime(first(data, ['latest_input_available_at']))],
            ['Input availability', first(data, ['input_availability_status'])],
            ['Freshness', first(integrityFreshness, ['status'])],
            ['Age / maximum', compactPair(first(integrityFreshness, ['age_seconds']), first(integrityFreshness, ['maximum_age_seconds']))],
            ['Model validation', first(data, ['model_validation_status', 'validation.status'])],
            ['Model artifact SHA-256', first(data, ['model_artifact_sha256', 'artifact_sha256'])],
            ['Feature schema SHA-256', first(data, ['state_feature_schema_sha256', 'feature_schema_sha256'])],
            ['Mapping semantics', first(data, ['state_mapping_semantics', 'mapping_semantics'])],
            ['Probability semantics', first(data, ['probability_semantics'])],
          ]} />
          <FeatureStrip
            title="Registered state features"
            values={strings(first(data, ['state_feature_schema', 'feature_schema']))}
            empty="The state artifact did not publish a validated feature schema."
          />
        </Section>
        <FeatureStrip
          title="State-model caveats"
          values={strings(first(data, ['caveats']))}
          empty="The unavailable payload did not include additional caveats."
        />
        <EvidenceFooter payload={data} label="State Engine integrity evidence" />
      </Workspace>
    );
  }

  const current = firstRecord(data, ['current_state', 'state', 'current']);
  const certainty = firstRecord(data, ['raw_state_certainty', 'current_state.raw_state_certainty']);
  const durationDiagnostics = firstRecord(data, ['duration_diagnostics']);
  const decisionBoundary = firstRecord(data, ['decision_boundary']);
  const crossSession = firstRecord(data, ['cross_session_state_forecast']);
  const stateDefinition = firstRecord(data, ['state_definition']);
  const freshness = firstRecord(data, ['freshness']);
  const horizonForecasts = rows(data, ['horizon_state_forecasts']);
  const availableHorizon = horizonForecasts
    .map(record)
    .find((row) => text(first(row, ['status'])).startsWith('AVAILABLE'));
  const filtered = probabilityRows(first(current, ['filtered_state_probabilities', 'filtered_probabilities']), first(data, ['state_names', 'labels']));
  const currentNextStateStatus = text(first(current, ['next_state_probability_status']));
  const nextStateStatus = currentNextStateStatus
    || text(first(availableHorizon, ['status']))
    || 'UNAVAILABLE';
  const predictedSource = nextStateStatus.startsWith('AVAILABLE')
    ? currentNextStateStatus.startsWith('AVAILABLE')
      ? first(current, ['next_state_probabilities', 'predicted_state_probabilities'])
      : first(availableHorizon, ['endpoint_state_probabilities'])
    : undefined;
  const predicted = probabilityRows(predictedSource, first(data, ['state_names', 'labels']));
  const comparisons = rows(data, ['model_comparisons', 'candidates', 'models']);
  const transitions = rows(data, ['transition_audit', 'transition_matrix', 'transitions']);
  const semanticState = text(first(current, ['semantic_state', 'state_name', 'label']));
  const rawStateId = text(first(current, ['raw_state_id', 'state_id']));
  const expectedDurationMinutes = firstNumber(durationDiagnostics, ['expected_spell_minutes_including_current']);
  const expectedDurationObservations = firstNumber(durationDiagnostics, ['expected_spell_observations_including_current']);
  const expectedDurationValue = expectedDurationMinutes != null
    ? duration(expectedDurationMinutes)
    : expectedDurationObservations != null
      ? `${decimal(expectedDurationObservations, 1)} observations`
      : '—';
  const crossSessionStatus = text(first(crossSession, ['status'])) || 'UNAVAILABLE_REQUIRES_SEPARATELY_VALIDATED_OVERNIGHT_MODEL';
  const continuousSizingImpact = first(decisionBoundary, ['continuous_sizing_impact']) ?? false;
  const hardNoTradeVetoImpact = first(decisionBoundary, ['hard_no_trade_veto_impact']) ?? true;
  const directAllocationImpact = first(decisionBoundary, ['direct_allocation_impact']) ?? hardNoTradeVetoImpact;
  const untruncatedGeometricDiagnostic = first(durationDiagnostics, ['untruncated_geometric_diagnostic']) ?? true;
  const mustNotExtrapolatePastSessionClose = first(durationDiagnostics, ['must_not_extrapolate_past_session_close']) ?? true;

  return (
    <Workspace title="Market State Engine" eyebrow="HMM is context, not a price target" description="实时只展示前向过滤的潜在状态概率。状态名称直接来自冻结 artifact 的 train-only profile；同 session 的 pA^h 与跨 session / 明日预测严格分开。">
      <AvailabilityBanner payload={data} expected="/state/current" />
      <DecisionBanner
        title="Raw state certainty is uncalibrated; entropy can veto only"
        detail={`direct_allocation_impact=${yesNo(directAllocationImpact)} (hard veto only); continuous_sizing_impact=${yesNo(continuousSizingImpact)}; hard_no_trade_veto_impact=${yesNo(hardNoTradeVetoImpact)}. Cross-session state forecast: ${crossSessionStatus}.`}
      />

      <MetricGrid>
        <Metric label="Semantic state" value={semanticState || 'UNMAPPED'} note={`raw ${rawStateId || '—'} · artifact profile`} />
        <Metric
          label="Raw top-state probability"
          value={percent(firstNumber(certainty, ['top_probability']))}
          note={`uncalibrated · top-two margin ${percent(firstNumber(certainty, ['top_two_probability_margin']))}`}
        />
        <Metric
          label="One-step state-change P"
          value={percent(firstNumber(current, ['one_step_change_probability']))}
          note="P(zₜ₊₁ ≠ zₜ); not transition-row entropy"
        />
        <Metric
          label="Transition-row entropy"
          value={decimal(firstNumber(current, ['transition_row_normalized_entropy']), 3)}
          note="posterior-weighted row uncertainty; not P(change)"
        />
      </MetricGrid>

      <TwoColumn>
        <Section title="Current filtered probabilities" icon={Layers3} subtitle="Forward filter uses only observations completed by observation_cutoff; these are not return-confidence probabilities.">
          <ProbabilityBars rows={filtered} empty="No validated filtered state probabilities are available." />
        </Section>
        <Section title="Next available same-session distribution" icon={ArrowRight} subtitle={`Status: ${nextStateStatus}. UI never substitutes the unconstrained one-step diagnostic across a session boundary.`}>
          <ProbabilityBars rows={predicted} empty="No same-session next-state distribution is available at this boundary." />
        </Section>
      </TwoColumn>

      <Section title="Same-session multi-horizon state forecasts" icon={ArrowRight} subtitle="Every row declares availability. A horizon that crosses the close stays unavailable until a separately validated overnight model exists.">
        <DataTable
          columns={['Horizon', 'Status', 'Dominant state', 'Dominant probability', 'Endpoint entropy', 'No state change', 'Semantics']}
          empty="No same-session horizon forecasts were emitted by the artifact."
          rows={horizonForecasts.map((value) => {
            const row = record(value);
            const steps = firstNumber(row, ['horizon_steps', 'transitions_ahead']);
            const minutes = firstNumber(row, ['horizon_minutes']);
            const horizonStatus = text(first(row, ['status'])) || 'UNAVAILABLE';
            const horizonAvailable = horizonStatus.startsWith('AVAILABLE');
            return [
              `${integer(steps)} step / ${integer(minutes)}m`,
              horizonStatus,
              horizonAvailable ? text(first(row, ['dominant_state'])) || '—' : 'WITHHELD',
              horizonAvailable ? percent(firstNumber(row, ['dominant_probability'])) : 'WITHHELD',
              horizonAvailable ? decimal(firstNumber(row, ['normalized_endpoint_entropy', 'endpoint_entropy']), 3) : 'WITHHELD',
              horizonAvailable ? percent(firstNumber(row, ['posterior_weighted_no_state_change_probability'])) : 'WITHHELD',
              text(first(row, ['probability_semantics'])) || '—',
            ];
          })}
        />
      </Section>

      <TwoColumn>
        <Section title="Duration diagnostics" icon={History} subtitle="This is an untruncated geometric-HMM diagnostic; it must not be extrapolated past the session close.">
          <KeyValueGrid items={[
            ['Expected untruncated spell', expectedDurationValue],
            ['Expected spell observations', decimal(expectedDurationObservations, 2)],
            ['Expected future self-transitions', decimal(firstNumber(durationDiagnostics, ['expected_future_self_transitions']), 2)],
            ['Observation cadence', `${integer(firstNumber(durationDiagnostics, ['observation_minutes']))}m`],
            ['Duration model', first(durationDiagnostics, ['duration_model'])],
            ['Untruncated geometric diagnostic', yesNo(untruncatedGeometricDiagnostic)],
            ['Must not extrapolate past close', yesNo(mustNotExtrapolatePastSessionClose)],
            ['Semantics', first(durationDiagnostics, ['semantics'])],
          ]} />
        </Section>
        <Section title="Decision boundary and overnight limitation" icon={ShieldCheck} subtitle="The state layer does not continuously size capital; entropy may only impose a fail-closed veto, and no overnight transition model is supplied.">
          <KeyValueGrid items={[
            ['Conditioning role', first(decisionBoundary, ['forecast_conditioning_role'])],
            ['Direct allocation impact (veto only)', yesNo(directAllocationImpact)],
            ['Continuous sizing impact', yesNo(continuousSizingImpact)],
            ['Hard no-trade veto impact', yesNo(hardNoTradeVetoImpact)],
            ['Execution eligible', yesNo(first(decisionBoundary, ['execution_eligible']))],
            ['Certainty semantics', first(decisionBoundary, ['confidence_semantics'])],
            ['Session reset', yesNo(first(stateDefinition, ['session_reset']))],
            ['Cross-session model available', yesNo(first(stateDefinition, ['cross_session_model_available']))],
            ['Cross-session status', crossSessionStatus],
            ['Today → tomorrow supported', yesNo(first(crossSession, ['today_to_tomorrow_claim_supported']))],
          ]} />
        </Section>
      </TwoColumn>

      <Section title="State-model comparison" icon={Beaker} subtitle="Complexity can advance only when purged OOS evidence improves over the no-HMM baseline.">
        <DataTable
          columns={['Model', 'States', 'Train likelihood', 'Validation score', 'Test score / delta', 'Stability', 'Selected', 'Reason']}
          empty="No Gaussian / Student-t / sticky / switching-AR comparison is available."
          rows={comparisons.map((value) => {
            const row = record(value);
            return [
              text(first(row, ['model', 'model_type', 'name'])) || '—',
              integer(firstNumber(row, ['states', 'state_count'])),
              decimal(firstNumber(row, ['train_log_likelihood', 'train_score']), 3),
              decimal(firstNumber(row, ['validation_log_likelihood', 'validation_score']), 3),
              decimal(firstNumber(row, ['test_log_likelihood', 'oos_delta', 'test_delta', 'test_score']), 4),
              decimal(firstNumber(row, ['stability_score', 'stability']), 3),
              yesNo(first(row, ['selected', 'promoted'])),
              text(first(row, ['reason', 'status'])) || '—',
            ];
          })}
        />
      </Section>

      <Section title="State artifact integrity" icon={ShieldCheck} subtitle="Schema, cutoff, availability and freshness are separate. A fresh file timestamp never substitutes for a persisted market observation cutoff.">
        <KeyValueGrid items={[
          ['Endpoint schema', first(data, ['schema_version'])],
          ['Artifact schema', first(data, ['artifact_schema_version'])],
          ['Observation cutoff', dateTime(first(data, ['observation_cutoff', 'as_of']))],
          ['Latest input available-at', dateTime(first(data, ['latest_input_available_at']))],
          ['Input availability', first(data, ['input_availability_status'])],
          ['Freshness', first(freshness, ['status'])],
          ['Age / maximum', compactPair(first(freshness, ['age_seconds']), first(freshness, ['maximum_age_seconds']))],
          ['Model validation', first(data, ['model_validation_status', 'validation.status'])],
          ['Model artifact SHA-256', first(data, ['model_artifact_sha256', 'artifact_sha256'])],
          ['Feature schema SHA-256', first(data, ['state_feature_schema_sha256', 'feature_schema_sha256'])],
          ['Mapping semantics', first(data, ['state_mapping_semantics', 'mapping_semantics'])],
          ['Probability semantics', first(current, ['probability_semantics']) || first(data, ['probability_semantics'])],
        ]} />
        <FeatureStrip
          title="Registered state features"
          values={strings(first(data, ['state_feature_schema', 'feature_schema']))}
          empty="The state artifact did not publish a validated feature schema."
        />
      </Section>

      <Section title="Transition audit" icon={Network} subtitle="Counts are train-only fractional Baum-Welch smoothed-ξ expected mass—not observed hard transitions and not a live feature.">
        <DataTable
          columns={['From state', 'To state', 'Probability', 'Train soft count', 'Origin soft mass', 'Count semantics']}
          empty="Transition audit rows have not been emitted."
          rows={transitions.flatMap((value, rowIndex) => transitionRows(value, rowIndex))}
        />
      </Section>

      <FeatureStrip
        title="State-model caveats"
        values={strings(first(data, ['caveats']))}
        empty="No state-model caveats were returned."
      />
      <EvidenceFooter payload={data} label="State Engine evidence" />
    </Workspace>
  );
}
