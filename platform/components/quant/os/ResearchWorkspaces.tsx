import { Activity, BarChart3, Beaker, GitBranch, History, Radar, ShieldCheck, Sparkles } from 'lucide-react';
import type { NativeOsStore } from '@/lib/quant/native-os-types';
import {
  AvailabilityBanner,
  DataTable,
  DecisionBanner,
  EvidenceCard,
  EvidenceFooter,
  FeatureStrip,
  KeyValueGrid,
  Metric,
  MetricGrid,
  Section,
  StagePipeline,
  ThreeColumn,
  TwoColumn,
  Workspace,
  compactPair,
  dateTime,
  decimal,
  first,
  firstNumber,
  integer,
  joinValues,
  percent,
  rangePercent,
  record,
  resourceStatus,
  rows,
  strings,
  text,
  yesNo,
} from './workspace-ui';

export function MotifAnomalyWorkspace({ store }: { store: NativeOsStore }) {
  const factory = record(store.researchFactory);
  const atlas = record(store.eventAtlas);
  const motifRows = rows(factory, ['motifs', 'motif_candidates', 'discoveries.motifs']);
  const anomalyRows = rows(factory, ['anomalies', 'anomaly_candidates', 'discoveries.anomalies']);
  const controls = rows(factory, ['negative_controls', 'controls', 'validation.negative_controls']);
  const allCandidates = motifRows.length ? motifRows : anomalyRows;
  const noCandidates = allCandidates.length === 0 && ['AVAILABLE', 'EMPTY'].includes(resourceStatus(factory));

  return (
    <Workspace title="Motifs & Weak Anomalies" eyebrow="候选规律，不是交易信号" description="Matrix Profile、subsequence neighbors、change points 与 residual anomalies 只能产生候选。候选必须跨独立时期重复，并在 untouched OOS 与负控下存活。">
      <AvailabilityBanner payload={factory} expected="/research/factory → motifs and anomalies" />
      {noCandidates ? <DecisionBanner title="NO CANDIDATES REGISTERED" detail="The discovery runtime is available, but no motif or anomaly has entered the immutable candidate registry." /> : null}
      <MetricGrid>
        <Metric label="Motif candidates" value={integer(firstNumber(factory, ['motif_count', 'summary.motifs']) ?? motifRows.length)} note="discovery output" />
        <Metric label="Anomaly candidates" value={integer(firstNumber(factory, ['anomaly_count', 'summary.anomalies']) ?? anomalyRows.length)} note="not promoted signals" />
        <Metric label="Independent episodes" value={integer(firstNumber(factory, ['independent_episode_count', 'summary.independent_episodes']))} note="non-overlapping" />
        <Metric label="Negative-control survival" value={percent(firstNumber(factory, ['negative_control_survival_rate', 'summary.control_survival_rate']))} note="lower is safer" />
      </MetricGrid>

      <Section title="Discovery candidates" icon={Sparkles} subtitle="Every row keeps a research hypothesis ID and separates discovery, validation and untouched test data.">
        <DataTable
          columns={['Hypothesis ID', 'Method / window', 'Symbols', 'Episodes', 'Purged OOS', 'Bootstrap CI', 'After cost', 'FDR q', 'Current strategy', 'Recent decay', 'Negative control', 'Status']}
          empty="No motif or weak-anomaly candidate has been registered."
          rows={allCandidates.map((value, index) => {
            const row = record(value);
            return [
              text(first(row, ['hypothesis_id', 'id'])) || `candidate-${index + 1}`,
              compactPair(first(row, ['method', 'discovery_method']), first(row, ['window', 'window_minutes'])),
              joinValues(first(row, ['symbols', 'symbol'])),
              integer(firstNumber(row, ['independent_episodes', 'event_count', 'samples'])),
              percent(firstNumber(row, ['oos_effect', 'test_effect', 'oos_return'])),
              rangePercent(firstNumber(row, ['bootstrap_ci_low', 'bootstrap_ci.low']), firstNumber(row, ['bootstrap_ci_high', 'bootstrap_ci.high'])),
              percent(firstNumber(row, ['net_effect_after_cost', 'after_cost_effect'])),
              decimal(firstNumber(row, ['q_value', 'fdr_adjusted_p_value']), 4),
              text(first(row, ['strategy.current_action', 'current_action'])) || 'ABSTAIN',
              text(first(row, ['decay_status', 'recent_decay'])) || '—',
              text(first(row, ['negative_control_status', 'control_status'])) || '—',
              text(first(row, ['status', 'promotion_status'])) || 'RESEARCH_ONLY',
            ];
          })}
        />
      </Section>

      <TwoColumn>
        <Section title="Research windows and representations" icon={Radar} subtitle="Discovery runs on returns, normalized paths, volatility-adjusted returns or residuals—not raw price level.">
          <FeatureStrip title="Windows" values={strings(first(factory, ['motif_windows', 'configuration.windows']))} empty="No configured discovery windows were returned." />
          <FeatureStrip title="Representations" values={strings(first(factory, ['motif_representations', 'configuration.representations']))} empty="No configured motif representation was returned." />
          <FeatureStrip title="Methods" values={strings(first(factory, ['motif_methods', 'configuration.methods']))} empty="No configured discovery method was returned." />
        </Section>
        <Section title="Reaction context" icon={Activity} subtitle="A similar shock has different meaning in a sell-off, recovery, compression or liquidity-stress state.">
          <KeyValueGrid items={[
            ['Atlas events linked', integer(firstNumber(atlas, ['linked_motif_events', 'summary.linked_motifs']))],
            ['Reaction features', integer(firstNumber(factory, ['reaction_feature_count', 'configuration.reaction_features']))],
            ['Cross-asset confirmation', yesNo(first(factory, ['cross_asset_confirmation', 'configuration.cross_asset']))],
            ['Regime conditioned', yesNo(first(factory, ['regime_conditioned', 'configuration.regime_conditioned']))],
            ['Time-of-day conditioned', yesNo(first(factory, ['time_conditioned', 'configuration.time_conditioned']))],
            ['Discovery frozen at', dateTime(first(factory, ['discovery_frozen_at', 'partitions.discovery.end']))],
          ]} />
        </Section>
      </TwoColumn>

      <Section title="Negative controls and anti-pattern tests" icon={ShieldCheck} subtitle="A candidate that shuffled data, reversed labels or random timestamps can reproduce is classified as a false pattern.">
        <DataTable
          columns={['Control', 'Candidates tested', 'False discoveries', 'Observed effect', 'Control effect', 'Adjusted p / q', 'Decision']}
          empty="Negative controls have not been attached to motif discovery."
          rows={controls.map((value) => {
            const row = record(value);
            return [
              text(first(row, ['control', 'control_type', 'name'])) || '—',
              integer(firstNumber(row, ['tested', 'candidate_count'])),
              integer(firstNumber(row, ['false_discoveries', 'replicated_count'])),
              percent(firstNumber(row, ['observed_effect', 'effect'])),
              percent(firstNumber(row, ['control_effect', 'null_effect'])),
              decimal(firstNumber(row, ['q_value', 'adjusted_p_value']), 4),
              text(first(row, ['decision', 'status'])) || '—',
            ];
          })}
        />
      </Section>

      <EvidenceFooter payload={factory} label="Motif discovery evidence" />
    </Workspace>
  );
}

export function ResearchFactoryWorkspace({ store }: { store: NativeOsStore }) {
  const data = record(store.researchFactory);
  const hypotheses = rows(data, ['hypotheses', 'candidates', 'registry']);
  const stages = rows(data, ['pipeline_stages', 'stages', 'pipeline']);
  const model = record(store.predictorModel);
  const walkForward = record(store.walkForward);
  const calibration = record(store.calibration);
  const emptyRegistry = hypotheses.length === 0 && firstNumber(data, ['hypothesis_count', 'summary.hypotheses']) === 0 && ['AVAILABLE', 'EMPTY'].includes(resourceStatus(data));

  return (
    <Workspace title="Research Factory" eyebrow="Discover → falsify → shadow → monitor" description="候选生成、去重、train-only screening、purged validation、calibration、untouched test、forward shadow 与 decay monitoring 是一条不可跳步的流水线。">
      <AvailabilityBanner payload={data} expected="/research/factory" />
      {emptyRegistry ? <DecisionBanner title="FACTORY OPERATIONAL · REGISTRY EMPTY" detail="Pipeline gates are implemented, but no hypothesis has produced materialized validation or promotion evidence." /> : null}
      <MetricGrid>
        <Metric label="Registered hypotheses" value={integer(firstNumber(data, ['hypothesis_count', 'summary.hypotheses']) ?? hypotheses.length)} note="immutable IDs" />
        <Metric label="Variants tried" value={integer(firstNumber(data, ['variant_count', 'summary.variants_tried']))} note="multiple-testing family" />
        <Metric label="Forward shadow" value={integer(firstNumber(store.shadow, ['verified_moomoo_forward_predictions', 'settled_forward_predictions']))} note="genuine future observations" />
        <Metric label="Promoted models" value={integer(firstNumber(data, ['promoted_count', 'summary.promoted']))} note={text(first(model, ['promotion_status', 'status'])) || 'no silent promotion'} />
      </MetricGrid>

      <Section title="Factory stage ledger" icon={GitBranch} subtitle="Counts must only move forward through declared gates; rejection is retained as evidence.">
        <StagePipeline rows={stages} payload={data} />
      </Section>

      <Section title="Hypothesis registry" icon={Beaker} subtitle="Effect size, multiplicity, costs and decay sit beside the headline result.">
        <DataTable
          columns={['Hypothesis ID', 'Target / horizon', 'Discovery time', 'Train / val / test', 'Variants', 'FDR q', 'Effect + CI', 'Cost-adjusted', 'Shadow', 'Status']}
          empty="No research hypotheses are registered."
          rows={hypotheses.map((value, index) => {
            const row = record(value);
            return [
              text(first(row, ['hypothesis_id', 'id'])) || `hypothesis-${index + 1}`,
              compactPair(first(row, ['target', 'symbol']), first(row, ['horizon', 'horizon_minutes'])),
              dateTime(first(row, ['discovery_timestamp', 'created_at'])),
              `${integer(firstNumber(row, ['train_samples', 'samples.train']))} / ${integer(firstNumber(row, ['validation_samples', 'samples.validation']))} / ${integer(firstNumber(row, ['test_samples', 'samples.test']))}`,
              integer(firstNumber(row, ['variants_tried', 'variant_count'])),
              decimal(firstNumber(row, ['fdr_adjusted_p_value', 'q_value']), 4),
              `${percent(firstNumber(row, ['effect_size', 'effect']))} ${rangePercent(firstNumber(row, ['ci_low', 'bootstrap_ci.low']), firstNumber(row, ['ci_high', 'bootstrap_ci.high']))}`,
              percent(firstNumber(row, ['net_effect_after_cost', 'expected_net_return'])),
              text(first(row, ['shadow_status', 'forward_shadow'])) || '—',
              text(first(row, ['promotion_status', 'status'])) || 'RESEARCH_ONLY',
            ];
          })}
        />
      </Section>

      <ThreeColumn>
        <EvidenceCard title="Purged walk-forward" icon={History} status={resourceStatus(walkForward)} rows={[
          ['Embargo', first(walkForward, ['split_contract.embargo', 'embargo'])],
          ['Folds', integer(firstNumber(walkForward, ['evaluation.fold_count', 'fold_count']))],
          ['Untouched test', first(walkForward, ['evaluation.test_status', 'test_status'])],
        ]} />
        <EvidenceCard title="Calibration" icon={BarChart3} status={resourceStatus(calibration)} rows={[
          ['Method', first(calibration, ['method', 'calibration_method'])],
          ['OOS Brier', decimal(firstNumber(calibration, ['brier', 'metrics.brier']), 4)],
          ['Promotion', first(calibration, ['promotion', 'promotion_status'])],
        ]} />
        <EvidenceCard title="Decay monitoring" icon={Activity} status={text(first(data, ['decay.status', 'decay_status'])) || 'PENDING'} rows={[
          ['Recent window', first(data, ['decay.window', 'decay_window'])],
          ['Effect drift', percent(firstNumber(data, ['decay.effect_drift', 'effect_drift']))],
          ['Retirement rule', first(data, ['decay.retirement_rule', 'retirement_rule'])],
        ]} />
      </ThreeColumn>

      <EvidenceFooter payload={data} label="Research Factory evidence" />
    </Workspace>
  );
}
