import { Activity, Archive, BarChart3, Clock3, Database, Fingerprint } from 'lucide-react';
import type { NativeOsStore } from '@/lib/quant/native-os-types';
import {
  AvailabilityBanner,
  DataTable,
  EvidenceFooter,
  FeatureStrip,
  KeyValueGrid,
  Metric,
  MetricGrid,
  QuestionCard,
  Section,
  ThreeColumn,
  TwoColumn,
  Workspace,
  compactPair,
  dateTime,
  decimal,
  first,
  firstNumber,
  firstRecord,
  integer,
  joinValues,
  percent,
  price,
  rangePercent,
  record,
  rows,
  shortDate,
  shortHash,
  strings,
  text,
  yesNo,
} from './workspace-ui';

export function MarketMemoryWorkspace({ store }: { store: NativeOsStore }) {
  const data = record(store.memorySummary);
  const snapshot = firstRecord(data, ['current_snapshot', 'latest_snapshot', 'snapshot', 'market_memory.current_snapshot']);
  const bySymbol = rows(data, ['coverage_by_symbol', 'symbols', 'coverage.symbols']);
  const flags = strings(first(data, ['data_quality_flags', 'quality.flags', 'current_snapshot.data_quality_flags']));

  return (
    <Workspace title="Market Memory" eyebrow="不可变历史市场记忆库" description="每个 decision timestamp 都必须能还原当时真正可见的信息、标签何时成熟，以及这条记录来自哪个数据版本。">
      <AvailabilityBanner payload={data} expected="/memory/summary" />
      <MetricGrid>
        <Metric label="Snapshots" value={integer(firstNumber(data, ['snapshot_count', 'total_snapshots', 'coverage.snapshots']))} note="immutable decision timestamps" />
        <Metric label="Independent sessions" value={integer(firstNumber(data, ['session_count', 'independent_sessions', 'coverage.sessions']))} note="not raw row count" />
        <Metric label="Symbols" value={integer(firstNumber(data, ['symbol_count', 'coverage.symbol_count']))} note={joinValues(first(data, ['symbol_names', 'coverage.symbol_names']))} />
        <Metric label="Latest decision as-of" value={dateTime(first(data, ['latest_decision_as_of', 'as_of', 'current_snapshot.decision_as_of']))} note="point-in-time cutoff" />
      </MetricGrid>

      <TwoColumn>
        <Section title="Current immutable snapshot" icon={Fingerprint} subtitle="Feature time and information-availability time are shown separately.">
          <KeyValueGrid items={[
            ['Snapshot ID', first(snapshot, ['snapshot_id', 'id'])],
            ['Symbol', first(snapshot, ['symbol', 'ticker'])],
            ['Decision as-of', dateTime(first(snapshot, ['decision_as_of', 'as_of']))],
            ['Information available', dateTime(first(snapshot, ['information_available_as_of', 'available_at']))],
            ['Session / minute', compactPair(first(snapshot, ['session_date', 'session']), first(snapshot, ['minute_of_session', 'session_minute']))],
            ['Reference price', price(first(snapshot, ['reference_price', 'close']))],
            ['Regime entropy', decimal(firstNumber(snapshot, ['regime_entropy', 'state_entropy']), 3)],
            ['Label available at', dateTime(first(snapshot, ['label_available_at']))],
          ]} />
          <FeatureStrip title="Data-quality flags" values={flags} empty="No snapshot quality flags have been emitted." />
        </Section>

        <Section title="Storage integrity" icon={Archive} subtitle="Corrections append a new record; they do not silently overwrite history.">
          <KeyValueGrid items={[
            ['Schema version', first(data, ['schema_version', 'schema.version'])],
            ['Dataset version', first(data, ['dataset_version', 'dataset.version'])],
            ['Storage format', first(data, ['storage_format', 'storage.format']) || 'UNAVAILABLE_NOT_MATERIALIZED'],
            ['Append only', yesNo(first(data, ['append_only', 'storage.append_only']))],
            ['Manifest SHA-256', shortHash(first(data, ['manifest_sha256', 'manifest.sha256', 'manifest_hash']))],
            ['Export status', first(data, ['export_status', 'storage.export_status'])],
            ['Current lineage SHA-256', shortHash(first(data, ['current_snapshot.lineage_sha256', 'latest_snapshot.lineage_sha256', 'lineage_sha256']))],
            ['Reconstruction', first(data, ['reconstruction.status', 'reconstruction_status'])],
            ['Duplicates rejected', integer(firstNumber(data, ['duplicates_rejected', 'quality.duplicate_count']))],
            ['Corrections recorded', integer(firstNumber(data, ['correction_count', 'corrections.count']))],
          ]} />
        </Section>
      </TwoColumn>

      <Section title="Coverage by symbol and horizon" icon={Database} subtitle="A large row count is not evidence if it comes from too few independent sessions.">
        <DataTable
          columns={['Symbol', 'Snapshots', 'Sessions', 'First as-of', 'Last as-of', '5m labels', '15m labels', '30m labels', '60m labels', 'Quality']}
          empty="No symbol-level Market Memory coverage is available yet."
          rows={bySymbol.map((value, index) => {
            const row = record(value);
            return [
              text(first(row, ['symbol', 'ticker'])) || `row ${index + 1}`,
              integer(firstNumber(row, ['snapshots', 'snapshot_count'])),
              integer(firstNumber(row, ['sessions', 'session_count'])),
              shortDate(first(row, ['start', 'first_as_of'])),
              shortDate(first(row, ['end', 'last_as_of'])),
              integer(firstNumber(row, ['labels_5m', 'horizons.5', 'horizon_5m'])),
              integer(firstNumber(row, ['labels_15m', 'horizons.15', 'horizon_15m'])),
              integer(firstNumber(row, ['labels_30m', 'horizons.30', 'horizon_30m'])),
              integer(firstNumber(row, ['labels_60m', 'horizons.60', 'horizon_60m'])),
              text(first(row, ['quality_status', 'status'])) || '—',
            ];
          })}
        />
      </Section>

      <EvidenceFooter payload={data} label="Market Memory evidence" />
    </Workspace>
  );
}

export function EventAtlasWorkspace({ store }: { store: NativeOsStore }) {
  const data = record(store.eventAtlas);
  const responseRows = rows(data, ['responses', 'event_responses', 'atlas', 'rows']);
  const legacyRows = rows(data, ['legacy_time_bucket_controls']);
  const endogenous = strings(first(data, ['taxonomy.endogenous', 'event_taxonomy.endogenous', 'endogenous_events']));
  const scheduled = strings(first(data, ['taxonomy.scheduled', 'event_taxonomy.scheduled', 'scheduled_events']));
  const reportedTypeCount = firstNumber(data, ['event_type_count', 'types', 'summary.types']);
  const taxonomyTypeCount = endogenous.length + scheduled.length;
  const displayedTypeCount = taxonomyTypeCount || reportedTypeCount;
  const typeCountNote = reportedTypeCount != null && taxonomyTypeCount > 0 && reportedTypeCount !== taxonomyTypeCount ? `taxonomy lists ${taxonomyTypeCount}; payload reports ${reportedTypeCount}` : 'endogenous + scheduled';

  return (
    <Workspace title="Event Response Atlas" eyebrow="事件 × 状态 × 第一反应" description="这里研究市场如何响应事件，而不是把事件名称本身当成固定买卖信号。所有统计都必须保留 detection time 与 information-availability time。">
      <AvailabilityBanner payload={data} expected="/events/atlas" />
      <MetricGrid>
        <Metric label="Detected events" value={integer(firstNumber(data, ['event_count', 'events', 'summary.events']))} note="point-in-time detections" />
        <Metric label="Event types" value={integer(displayedTypeCount)} note={typeCountNote} />
        <Metric label="Effective samples" value={decimal(firstNumber(data, ['effective_sample_size', 'summary.effective_sample_size']), 1)} note="dependence-adjusted" />
        <Metric label="Last detection" value={dateTime(first(data, ['last_detection_at', 'latest_event.detection_time', 'as_of']))} note="not event-day hindsight" />
      </MetricGrid>

      <TwoColumn>
        <Section title="Endogenous market events" icon={Activity} subtitle="Detected from price, volume, volatility, breadth and liquidity available at that moment.">
          <FeatureStrip title="Active taxonomy" values={endogenous} empty="Event taxonomy has not been materialized." />
        </Section>
        <Section title="Scheduled calendar events" icon={Clock3} subtitle="Only a genuinely point-in-time calendar can activate these labels.">
          <FeatureStrip title="Audited calendar types" values={scheduled} empty="No audited scheduled-event calendar is available." />
        </Section>
      </TwoColumn>

      <Section title="Conditional response distributions" icon={BarChart3} subtitle="Median, tails, path excursion, effective sample size and stability are shown together; mean return alone is insufficient.">
        <DataTable
          columns={['Event', 'Regime / time', 'N / ESS', 'P(up)', 'Median', '10–90% path', 'MFE / MAE', 'Bootstrap CI', 'Stability', 'Recent decay']}
          empty="No historical event-response distributions are available yet."
          rows={responseRows.map((value, index) => {
            const row = record(value);
            return [
              text(first(row, ['event_type', 'type', 'name'])) || `event ${index + 1}`,
              compactPair(first(row, ['regime', 'state']), first(row, ['time_bucket', 'minute_bucket'])),
              `${integer(firstNumber(row, ['sample_count', 'n']))} / ${decimal(firstNumber(row, ['effective_sample_size', 'ess']), 1)}`,
              percent(firstNumber(row, ['p_up', 'probability_up'])),
              percent(firstNumber(row, ['median_return', 'median'])),
              rangePercent(firstNumber(row, ['q10', 'quantile_10']), firstNumber(row, ['q90', 'quantile_90'])),
              `${percent(firstNumber(row, ['mfe', 'median_mfe']))} / ${percent(firstNumber(row, ['mae', 'median_mae']))}`,
              rangePercent(firstNumber(row, ['ci_low', 'bootstrap_ci.low']), firstNumber(row, ['ci_high', 'bootstrap_ci.high'])),
              decimal(firstNumber(row, ['stability_score', 'stability']), 2),
              text(first(row, ['decay_status', 'recent_decay', 'trend'])) || '—',
            ];
          })}
        />
      </Section>
      {legacyRows.length ? (
        <Section title="Legacy time-bucket controls" icon={Activity} subtitle="These rows are displayed only as legacy controls; they are not promoted to Event Atlas evidence.">
          <DataTable
            columns={['Control', 'Time bucket', 'N / ESS', 'P(up)', 'Bootstrap CI', 'Selected on validation', 'FDR q', 'Classification']}
            empty="No legacy time-bucket controls were returned."
            rows={legacyRows.map((value, index) => {
              const row = record(value);
              return [
                text(first(row, ['event_type', 'type', 'name'])) || `control ${index + 1}`,
                text(first(row, ['time_bucket', 'minute_bucket'])) || '—',
                `${integer(firstNumber(row, ['sample_count', 'n']))} / ${decimal(firstNumber(row, ['effective_sample_size', 'ess']), 1)}`,
                percent(firstNumber(row, ['p_up', 'probability_up'])),
                rangePercent(firstNumber(row, ['ci_low', 'bootstrap_ci.low']), firstNumber(row, ['ci_high', 'bootstrap_ci.high'])),
                yesNo(first(row, ['selected_on_validation', 'selected'])),
                decimal(firstNumber(row, ['fdr_q_value', 'q_value']), 4),
                text(first(row, ['classification', 'status'])) || 'LEGACY_CONTROL_ONLY',
              ];
            })}
          />
        </Section>
      ) : null}


      <ThreeColumn>
        <QuestionCard title="哪些历史时刻最像现在？" detail="按事件、pre-event state、liquidity、cross-asset confirmation 和反应形态联合筛选。" />
        <QuestionCard title="事件后路径怎么分布？" detail="对 1/5/15/30/60m 返回终点、MFE、MAE、恢复时间与尾部概率。" />
        <QuestionCard title="效应是否衰减？" detail="按年份、regime、时间桶与资产拆分，并对最近窗口运行方向反转检查。" />
      </ThreeColumn>

      <EvidenceFooter payload={data} label="Event Atlas evidence" />
    </Workspace>
  );
}
