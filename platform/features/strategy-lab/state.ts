import type { DeploymentMandate, EvidenceEvent, StrategyControl } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';

export function controlLabel(deployment: DeploymentMandate, controls: StrategyControl[], now: number): string {
  const control = controls.filter(item => item.deploymentId === deployment.id).sort((a, b) => b.mandateVersion - a.mandateVersion)[0];
  if (control?.status === 'pending') return control.action === 'pause' ? 'Pause requested' : control.action === 'retire' ? 'Retirement requested' : 'Resume requested';
  if (deployment.state === 'retired') return 'Retired';
  if (deployment.state === 'paused') return 'Entries paused';
  if (!deployment.leaseExpiresAt || Date.parse(deployment.leaseExpiresAt) <= now) return 'Authorization expired';
  return 'Running';
}
export function latestEvidence(events: EvidenceEvent[], kind: EvidenceEvent['kind'], deploymentId?: string): EvidenceEvent | undefined {
  return events.filter(event => event.kind === kind && (!deploymentId || event.deploymentId === deploymentId))
    .sort((a, b) => Date.parse(b.occurredAt) - Date.parse(a.occurredAt) || b.sequence - a.sequence)[0];
}
export function evidenceText(event: EvidenceEvent | undefined): string {
  if (!event) return 'No record yet';
  const payload = event.payload;
  for (const key of ['message', 'reason', 'summary', 'status', 'decision']) if (typeof payload[key] === 'string') return payload[key] as string;
  return 'Recorded event — open details for the reported fields.';
}
export function safeValue(value: unknown): string {
  if (value === null || value === undefined) return 'Not reported';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'number' && !Number.isFinite(value)) return 'Not reported';
  return typeof value === 'string' || typeof value === 'number' ? String(value) : 'See event details';
}

/** Retain verified account values only when the connector explicitly marks an outage. */
export function accountEvidence(events: EvidenceEvent[], deploymentId: string) {
  const rows = events.filter(event => event.kind === 'heartbeat' && event.deploymentId === deploymentId)
    .sort((a,b) => Date.parse(b.occurredAt)-Date.parse(a.occurredAt) || b.sequence-a.sequence);
  const current=rows[0];
  const retained=current?.payload.preserveLastVerifiedValues === true;
  const values=retained ? rows.find(event => event.payload.preserveLastVerifiedValues !== true) : current;
  return {current, values, retained};
}
