import { Database, Fingerprint, Server, ShieldCheck } from 'lucide-react';
import type { NativeOsStore } from '@/lib/quant/native-os-types';
import {
  AvailabilityBanner,
  Checklist,
  DataTable,
  EvidenceFooter,
  HealthRow,
  KeyValueGrid,
  Metric,
  MetricGrid,
  Section,
  TwoColumn,
  Workspace,
  booleanValue,
  compactPair,
  dateTime,
  duration,
  first,
  firstNumber,
  integer,
  record,
  resourceStatus,
  rows,
  shortHash,
  text,
  yesNo,
} from './workspace-ui';

export function AuditRuntimeWorkspace({ store }: { store: NativeOsStore }) {
  const audit = record(store.auditPredictions);
  const system = record(store.system);
  const live = record(store.liveStatus);
  const liveCapabilities = record(store.liveCapabilities);
  const shadow = record(store.shadow);
  const settlements = record(store.settlements);
  const traces = rows(audit, ['predictions', 'traces', 'rows', 'audit']);
  const components = rows(system, ['components', 'services', 'health.components']);

  return (
    <Workspace title="Audit & Runtime" eyebrow="Every forecast must be replayable" description="从 prediction ID 可以追溯 snapshot、feature hash、analog set、state model、decision policy、data manifest 和最终 settlement。健康页同时区分在线、降级与数据陈旧。">
      <AvailabilityBanner payload={audit} expected="/audit/predictions" />
      <MetricGrid>
        <Metric label="Runtime" value={resourceStatus(system)} note={text(first(system, ['mode', 'runtime_mode'])) || 'native quantd'} />
        <Metric label="Live feed" value={resourceStatus(live)} note={dateTime(first(live, ['last_event_at', 'last_update', 'as_of']))} />
        <Metric label="Pending settlements" value={integer(firstNumber(settlements, ['pending', 'status.pending_forward_predictions']))} note="append-only outcomes" />
        <Metric label="Audited predictions" value={integer(firstNumber(audit, ['prediction_count', 'count', 'summary.total']) ?? traces.length)} note="traceable IDs" />
      </MetricGrid>

      <Section title="Prediction trace ledger" icon={Fingerprint} subtitle="A true snapshot link must be the exact persisted Market Memory ID; a derived trace ID is not presented as equivalent evidence.">
        <DataTable
          columns={['Prediction ID', 'Decision as-of', 'Symbol / horizon', 'Snapshot / trace', 'Analog IDs', 'Feature hash', 'Model hash', 'Manifest', 'Decision', 'Settlement', 'Evidence']}
          empty="No prediction audit trace is available."
          rows={traces.map((value, index) => {
            const row = record(value);
            const rawSettlement = text(first(row, ['settlement.status', 'settlement_status']));
            const settlement = rawSettlement === 'NOT_IN_PENDING_SET' ? 'UNKNOWN_NOT_PENDING' : rawSettlement || 'PENDING';
            return [
              text(first(row, ['prediction_id', 'id'])) || `prediction-${index + 1}`,
              dateTime(first(row, ['decision_as_of', 'as_of', 'created_at'])),
              compactPair(first(row, ['symbol']), first(row, ['horizon_minutes', 'horizon'])),
              shortHash(first(row, ['snapshot_id', 'market_snapshot_id'])),
              text(first(row, ['top_analog_ids_status', 'analog_ids_status'])) || '—',
              shortHash(first(row, ['feature_hash'])),
              shortHash(first(row, ['model_hash'])),
              shortHash(first(row, ['data_manifest_hash', 'manifest_hash'])),
              text(first(row, ['decision.action', 'decision', 'action'])) || '—',
              settlement,
              text(first(row, ['evidence_grade', 'evidence'])) || '—',
            ];
          })}
        />
      </Section>

      <TwoColumn>
        <Section title="Runtime components" icon={Server} subtitle="A process can be online while one feed, writer or model worker is degraded.">
          {components.length ? <div className="space-y-2">{components.map((value, index) => { const row = record(value); const status = text(first(row, ['status', 'health'])) || 'UNKNOWN'; return <HealthRow key={`${text(first(row, ['name', 'component']))}-${index}`} name={text(first(row, ['name', 'component', 'service'])) || `component ${index + 1}`} status={status} detail={text(first(row, ['detail', 'message', 'reason']))} />; })}</div> : <div className="space-y-2">
            <HealthRow name="quantd runtime" status={resourceStatus(system)} detail={text(first(system, ['message', 'detail']))} />
            <HealthRow name="Moomoo feed" status={resourceStatus(live)} detail={dateTime(first(live, ['last_update', 'as_of']))} />
            <HealthRow name="Prediction ledger" status={resourceStatus(shadow)} detail={`${integer(firstNumber(shadow, ['pending_forward_predictions', 'pending']))} pending`} />
            <HealthRow name="Settlement writer" status={resourceStatus(settlements)} detail={text(first(settlements, ['truth', 'message']))} />
          </div>}
        </Section>

        <Section title="Data truth and freshness" icon={Database} subtitle="Coverage, receive-time semantics and NBBO scope remain explicit at runtime.">
          <KeyValueGrid items={[
            ['Market coverage', first(liveCapabilities, ['market_coverage', 'coverage'])],
            ['Consolidated NBBO', yesNo(first(liveCapabilities, ['consolidated_nbbo']))],
            ['Latest completed bar', dateTime(first(live, ['last_completed_bar', 'last_bar_at']))],
            ['Feed lag', duration(firstNumber(live, ['lag_seconds', 'data_lag_seconds']), 'seconds')],
            ['Data capability', first(store.dataCapabilities, ['highest_level', 'level', 'status'])],
            ['Historical rows', integer(firstNumber(store.dataCoverage, ['rows', 'coverage.rows']))],
            ['Ledger mode', first(shadow, ['mode', 'storage_mode']) || 'append-only expected'],
            ['SSE / stream', first(system, ['stream_status', 'transport']) || 'snapshot polling'],
          ]} />
        </Section>
      </TwoColumn>

      <Section title="Reproducibility checklist" icon={ShieldCheck} subtitle="These gates answer whether another process can reconstruct the exact decision without hidden state.">
        <Checklist items={[
          ['Observation cutoff recorded', booleanValue(first(audit, ['checks.observation_cutoff', 'reproducibility.observation_cutoff']))],
          ['Snapshot and feature hashes linked', booleanValue(first(audit, ['checks.feature_lineage', 'reproducibility.feature_hash']))],
          ['Top analog IDs frozen', booleanValue(first(audit, ['checks.analog_ids', 'reproducibility.analog_ids']))],
          ['Model and policy versions frozen', booleanValue(first(audit, ['checks.model_policy', 'reproducibility.model_policy']))],
          ['Manifest SHA-256 verified', booleanValue(first(audit, ['checks.manifest_verified', 'reproducibility.manifest_verified']))],
          ['Settlement append-only', booleanValue(first(audit, ['checks.append_only_settlement', 'reproducibility.append_only_settlement']))],
        ]} />
      </Section>

      <EvidenceFooter payload={audit} label="Prediction audit evidence" />
    </Workspace>
  );
}
