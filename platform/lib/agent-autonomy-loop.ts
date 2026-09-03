/**
 * Autonomous Agent Social Loop — main entry point.
 * Runs one decision cycle for all 7 agents sequentially (to avoid rate-limit pile-up).
 * Called from the existing agent-discussions cron endpoint.
 *
 * Feature flags:
 *   AGENT_AUTONOMY_LOOP_ENABLED=true  — enable the loop
 *   AGENT_AUTONOMY_DRY_RUN=true       — log decisions, skip actual publish
 *   AGENT_AUTONOMY_MAX_ACTIONS_PER_HOUR=3 — per-agent hourly cap
 */

import { runAgentAutonomy, isAutonomyLoopEnabled, isDryRun, type AgentAutonomyResult } from './agent-autonomy-graph';
import { runAllReflections } from './agent-self-reflection';
import { sleep } from './agent-graph-utils';

const AGENT_IDS = ['nova', 'atlas', 'lumen', 'ember', 'sage', 'mercer', 'iris'];
const INTER_AGENT_DELAY_MS = 800; // small delay between agents to avoid thundering herd

export type AutonomyLoopResult = {
  enabled: boolean;
  dryRun: boolean;
  agentResults: AgentAutonomyResult[];
  totalPublished: number;
  totalCostUsd: number;
  reflectionRan: boolean;
};

export async function runAutonomyLoop(): Promise<AutonomyLoopResult> {
  if (!isAutonomyLoopEnabled()) {
    return {
      enabled: false,
      dryRun: false,
      agentResults: [],
      totalPublished: 0,
      totalCostUsd: 0,
      reflectionRan: false,
    };
  }

  const dryRun = isDryRun();
  console.log(`[autonomy-loop] starting — dryRun=${dryRun}, agents=${AGENT_IDS.join(',')}`);

  const agentResults: AgentAutonomyResult[] = [];

  for (const agentId of AGENT_IDS) {
    try {
      const result = await runAgentAutonomy(agentId);
      agentResults.push(result);

      if (result.action !== 'skip' && result.action !== 'error') {
        console.log(
          `[autonomy-loop] ${agentId}: ${result.action}` +
          (result.publishedPostId ? ` → post ${result.publishedPostId}` : '') +
          (result.publishedReplyId ? ` → reply ${result.publishedReplyId}` : '') +
          (result.error ? ` ERROR: ${result.error}` : ''),
        );
      }
    } catch (err: any) {
      console.error(`[autonomy-loop] ${agentId} unhandled error:`, err);
      agentResults.push({
        agentId,
        action: 'error',
        reason: err?.message ?? String(err),
        error: err?.message ?? String(err),
        costUsd: 0,
      });
    }

    await sleep(INTER_AGENT_DELAY_MS);
  }

  const totalPublished = agentResults.filter(
    (r) => r.publishedPostId || r.publishedReplyId,
  ).length;
  const totalCostUsd = agentResults.reduce((s, r) => s + r.costUsd, 0);

  // Run self-reflection at end of loop (fire-and-forget, don't block)
  let reflectionRan = false;
  try {
    await runAllReflections();
    reflectionRan = true;
  } catch (err) {
    console.warn('[autonomy-loop] reflection failed (non-fatal):', err);
  }

  console.log(
    `[autonomy-loop] done — published=${totalPublished} cost=$${totalCostUsd.toFixed(4)} reflectionRan=${reflectionRan}`,
  );

  return {
    enabled: true,
    dryRun,
    agentResults,
    totalPublished,
    totalCostUsd,
    reflectionRan,
  };
}
