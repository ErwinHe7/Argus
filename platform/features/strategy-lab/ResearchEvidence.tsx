import React from 'react';
import type { EvidenceEvent } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { researchReportSchema } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { displayTime } from './catalog';
import { safeValue } from './state';

function percent(value: unknown): string {
  return typeof value === 'number' && Number.isFinite(value)
    ? new Intl.NumberFormat('en-US',{style:'percent',maximumFractionDigits:2}).format(value)
    : 'Not reported';
}
export function ResearchEvidence({events}: {events: EvidenceEvent[]}) {
  return <>{events.filter(event => event.kind === 'research_result').map(event => {
    const parsed=researchReportSchema.safeParse(event.payload.report);
    if (!parsed.success) return null;
    const report=parsed.data;
    return <section className="strategy-research-report" key={event.id}>
      <header><h3>{report.symbol} · {report.strategy}</h3><span>Exploratory · not promoted</span></header>
      <p>Locally supplied research summary. Daily-bar fills approximate execution; they do not validate the 9:35 a.m. quote window.</p>
      <dl><dt>Net account return</dt><dd>{percent(report.metrics.net_time_weighted_return)}</dd><dt>Maximum drawdown</dt><dd>{percent(report.metrics.max_drawdown)}</dd><dt>Completed trades</dt><dd>{safeValue(report.metrics.completed_trades)}</dd><dt>Source</dt><dd>{report.source_evidence.source}</dd><dt>Observation cutoff</dt><dd>{displayTime(report.observation_cutoff)}</dd></dl>
      <details><summary>Limitations and provenance</summary><ul>{report.limitations.map((item,index)=><li key={index}>{item}</li>)}</ul><p>Dataset SHA-256: <code>{report.source_evidence.dataset_sha256}</code></p><p>Artifact SHA-256: <code>{report.artifact_sha256}</code></p><p>Full metrics, cost assumptions, benchmarks, and holdout checks are available in this report’s recorded event.</p></details>
    </section>;
  })}</>;
}
