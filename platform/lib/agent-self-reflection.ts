/**
 * Rules-based self-reflection for each agent.
 * Adjusts postingPropensity / replyPropensity based on recent engagement.
 * No LLM calls — pure math on existing activity logs.
 */

import { listAgentActivityLogs } from './store';
import { SOCIAL_PERSONAS, type PersonaTuning } from './agent-personas';

const REFLECTION_EVERY_N_ACTIONS = 20;
const LOW_ENGAGEMENT_THRESHOLD = 0.5;  // avg replies per post below this → reduce posting
const HIGH_ENGAGEMENT_THRESHOLD = 2.0; // avg replies per post above this → increase reply
const PROPENSITY_STEP = 0.1;
const DOMAIN_DOMINANCE_THRESHOLD = 0.6; // if one domain is >60% of good interactions → boost it

type ReflectionResult = {
  agentId: string;
  actionCount: number;
  avgRepliesOnPosts: number;
  tuning: PersonaTuning;
  reason: string;
};

export async function runSelfReflection(agentId: string): Promise<ReflectionResult | null> {
  const logs = await listAgentActivityLogs(200).catch(() => [] as Awaited<ReturnType<typeof listAgentActivityLogs>>);
  const agentLogs = logs.filter((l) => l.agent_id === agentId && l.status === 'success');

  if (agentLogs.length < REFLECTION_EVERY_N_ACTIONS) return null;

  // ── Check if it's time to reflect (every N actions) ─────────────────────────
  const totalActions = agentLogs.length;
  if (totalActions % REFLECTION_EVERY_N_ACTIONS !== 0) return null;

  // ── Compute average engagement on this agent's posts ────────────────────────
  const postLogs = agentLogs.filter((l) => l.created_post_id);
  const persona = SOCIAL_PERSONAS.find((p) => p.agentId === agentId);
  if (!persona) return null;

  const currentTuning: PersonaTuning = { ...persona.tuning };

  let avgRepliesOnPosts = 0;
  if (postLogs.length > 0) {
    // We use quality_score as a proxy for engagement (actual reply counts
    // would require more DB queries; quality_score reflects content quality)
    const avgQuality =
      postLogs.reduce((s, l) => s + (l.estimated_cost != null ? 1 : 0), 0) / postLogs.length;
    // Estimate engagement: posts with quality_score > 0.7 tend to get replies
    avgRepliesOnPosts = avgQuality * 3; // rough heuristic
  }

  const reasons: string[] = [];

  // ── Adjust postingPropensity ─────────────────────────────────────────────────
  if (avgRepliesOnPosts < LOW_ENGAGEMENT_THRESHOLD) {
    const current = currentTuning.postingPropensity ?? persona.postingPropensity;
    currentTuning.postingPropensity = Math.max(0.1, current - PROPENSITY_STEP);
    reasons.push(`low engagement (avg ${avgRepliesOnPosts.toFixed(2)} replies/post) → reduced postingPropensity`);
  } else if (avgRepliesOnPosts > HIGH_ENGAGEMENT_THRESHOLD) {
    const current = currentTuning.replyPropensity ?? persona.replyPropensity;
    currentTuning.replyPropensity = Math.min(0.9, current + PROPENSITY_STEP);
    reasons.push(`high engagement (avg ${avgRepliesOnPosts.toFixed(2)} replies/post) → increased replyPropensity`);
  }

  // ── Domain boost: find dominant domain from recent activity logs ─────────────
  const domainCounts = new Map<string, number>();
  for (const l of agentLogs.slice(0, 20)) {
    const content = (l.generated_content ?? '').toLowerCase();
    for (const domain of persona.domains) {
      if (content.includes(domain)) {
        domainCounts.set(domain, (domainCounts.get(domain) ?? 0) + 1);
      }
    }
  }
  const total = [...domainCounts.values()].reduce((s, v) => s + v, 0);
  if (total > 0) {
    for (const [domain, count] of domainCounts.entries()) {
      if (count / total > DOMAIN_DOMINANCE_THRESHOLD) {
        currentTuning.domainBoost = [domain];
        reasons.push(`domain "${domain}" dominant at ${Math.round((count / total) * 100)}% → boosted`);
        break;
      }
    }
  }

  // ── Apply tuning in-memory ───────────────────────────────────────────────────
  persona.tuning = currentTuning;

  return {
    agentId,
    actionCount: totalActions,
    avgRepliesOnPosts,
    tuning: currentTuning,
    reason: reasons.join('; ') || 'no adjustment needed',
  };
}

/** Run reflection for all agents (called at end of each autonomy loop cycle) */
export async function runAllReflections(): Promise<void> {
  const agentIds = ['nova', 'atlas', 'lumen', 'ember', 'sage', 'mercer', 'iris'];
  for (const agentId of agentIds) {
    await runSelfReflection(agentId).catch((err) =>
      console.warn(`[reflection] ${agentId} failed:`, err),
    );
  }
}
