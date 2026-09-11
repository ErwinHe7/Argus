import type { SupabaseClient } from '@supabase/supabase-js';
import type { PublicConfig } from './config';
import type { ConfigurationInput, DeploymentMandate, Explanation, ResearchRun, StrategyControl, StrategyStatus, StrategyVersion } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { strategyVersionSchema, mandateSchema, controlSchema, researchRunSchema, deviceSchema, eventSchema } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';

export class StrategyApiError extends Error {
  constructor(public readonly status: number, message: string) { super(message); }
}
export function parseStatus(value: unknown): StrategyStatus {
  if (!value || typeof value !== 'object') throw new Error('Strategy status could not be validated.');
  const state = value as Record<string, unknown>;
  const member = state.membership as {userId?: unknown; status?: unknown} | undefined;
  if (!member || typeof member.userId !== 'string' || member.status !== 'active') throw new StrategyApiError(403, 'An active Leo identity is required. Sign in again.');
  return {
    membership: { userId: member.userId, status: 'active' },
    configurations: strategyVersionSchema.array().parse(state.configurations),
    deployments: mandateSchema.array().parse(state.deployments),
    devices: deviceSchema.array().parse(state.devices),
    researchRuns: researchRunSchema.array().parse(state.researchRuns),
    evidence: eventSchema.array().parse(state.evidence),
    controls: controlSchema.array().parse(state.controls),
  };
}

export class StrategyClient {
  constructor(private readonly config: PublicConfig, private readonly auth: SupabaseClient, private readonly request: typeof fetch = (...args) => fetch(...args)) {}

  private async call<T>(path: string, body?: unknown, key?: string): Promise<T> {
    const { data, error } = await this.auth.auth.getSession();
    if (error || !data.session || data.session.user.is_anonymous) throw new StrategyApiError(401, 'Sign in with Google to continue.');
    let response: Response;
    try {
      response = await this.request(`${this.config.apiUrl}${path}`, {
        method: body === undefined ? 'GET' : 'POST', redirect: 'error', cache: 'no-store',
        signal: AbortSignal.timeout(12_000),
        headers: { Authorization: `Bearer ${data.session.access_token}`, apikey: this.config.publishableKey,
          ...(body === undefined ? {} : { 'Content-Type': 'application/json', 'Idempotency-Key': key ?? crypto.randomUUID() }) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    } catch { throw new StrategyApiError(0, 'The strategy service did not respond. Last reported values are preserved. Refresh before retrying an action.'); }
    if (!response.ok) {
      // Never echo arbitrary server/provider text that could contain credentials.
      const messages: Record<number, string> = {
        400: 'The request was not accepted. Check your configuration and refresh.',
        401: 'Your session expired. Sign in again to reconnect.',
        403: 'Your account cannot access this strategy state. Sign in again or contact support.',
        409: 'State changed or this account already has an active policy. Refresh before retrying.',
        422: 'The configuration is not supported. Use the fixed v1 rules and a U.S. stock or ETF.',
        429: 'Too many requests. Wait briefly, then refresh.',
      };
      throw new StrategyApiError(response.status, messages[response.status] ?? 'The strategy service is unavailable. Last reported values are preserved.');
    }
    const envelope: unknown = await response.json();
    const current = await this.auth.auth.getSession();
    if (current.error || current.data.session?.user.id !== data.session.user.id) {
      throw new StrategyApiError(401, 'The signed-in account changed. Refresh this workspace.');
    }
    if (!envelope || typeof envelope !== 'object' || !('data' in envelope)) throw new Error('The strategy response is incomplete. Refresh to retry.');
    return (envelope as {data: T}).data;
  }
  async status(): Promise<StrategyStatus> { return parseStatus(await this.call('/v1/status')); }
  async configure(input: ConfigurationInput, key: string): Promise<StrategyVersion> { return strategyVersionSchema.parse(await this.call('/v1/configurations', input, key)); }
  async pairing(key: string): Promise<{pairingToken: string; expiresAt: string}> {
    const data = await this.call<{pairingToken: string; expiresAt: string}>('/v1/pairing', {}, key);
    if (!/^[a-f0-9]{64}$/.test(data.pairingToken) || !Number.isFinite(Date.parse(data.expiresAt))) throw new Error('Pairing response is invalid. Request a new code.');
    return data;
  }
  async research(strategyVersionId: string, key: string): Promise<ResearchRun> { return researchRunSchema.parse(await this.call('/v1/research-runs', {strategyVersionId}, key)); }
  async uploadReport(runId: string, report: unknown, key: string): Promise<ResearchRun> {
    const result = await this.call<{run: unknown}>(`/v1/research-runs/${encodeURIComponent(runId)}/report`, {report}, key);
    return researchRunSchema.parse(result.run);
  }
  async deploy(input: Pick<DeploymentMandate, 'strategyVersionId'|'deviceId'|'accountId'|'mode'|'configurationHash'>, key: string): Promise<DeploymentMandate> { return mandateSchema.parse(await this.call('/v1/deployments', input, key)); }
  async control(deployment: DeploymentMandate, action: 'pause'|'resume', key: string): Promise<StrategyControl> {
    return controlSchema.parse(await this.call(`/v1/deployments/${encodeURIComponent(deployment.id)}/controls`, { action, reason: action === 'pause' ? 'User requested a pause from the strategy workspace.' : 'User requested resume after reconciliation.', expectedVersion: deployment.mandateVersion }, key));
  }
  async retire(deployment: DeploymentMandate, key: string): Promise<unknown> {
    return this.call(`/v1/deployments/${encodeURIComponent(deployment.id)}/retire`, {expectedVersion:deployment.mandateVersion,reason:'User requested retirement after verified flat reconciliation.'}, key);
  }
  async revoke(deviceId: string, key: string): Promise<unknown> {
    return this.call(`/v1/devices/${encodeURIComponent(deviceId)}/revoke`, {reason:'User revoked this device from the strategy workspace.'}, key);
  }
  async explain(question: string, deploymentId: string | undefined, key: string): Promise<Explanation> {
    const result = await this.call<Explanation>('/v1/explanations', {question, ...(deploymentId ? {deploymentId} : {})}, key);
    if (typeof result.answer !== 'string' || !Array.isArray(result.evidenceIds)) throw new Error('No validated explanation was returned. Inspect the event records.');
    return result;
  }
}
