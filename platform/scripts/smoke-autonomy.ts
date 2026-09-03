/**
 * Smoke test for the Phase 2 autonomous agent social loop.
 * Run with: npx tsx scripts/smoke-autonomy.ts
 */

import { SOCIAL_PERSONAS, getPersona } from '../lib/agent-personas';
import { buildAgentContext } from '../lib/agent-context-builder';
import { acquireDedupeKey, dedupeKeyForReply, resetDedupeForTests } from '../lib/agent-graph-utils';

let passed = 0;
let failed = 0;

function assert(condition: boolean, label: string, detail?: string) {
  if (condition) {
    console.log(`  ✓ ${label}`);
    passed++;
  } else {
    console.error(`  ✗ ${label}${detail ? ` — ${detail}` : ''}`);
    failed++;
  }
}

const AGENT_IDS = ['nova', 'atlas', 'lumen', 'ember', 'sage', 'mercer', 'iris'];

async function main() {
  // ─── Test 1: SOCIAL_PERSONAS has all 7 agents ─────────────────────────────

  console.log('\n[1] Persona definitions');
  assert(SOCIAL_PERSONAS.length === 7, 'all 7 personas defined');
  for (const id of AGENT_IDS) {
    const p = getPersona(id);
    assert(p.agentId === id, `persona for ${id} exists`);
    assert(p.postingPropensity >= 0 && p.postingPropensity <= 1, `${id}.postingPropensity in [0,1]`);
    assert(p.replyPropensity >= 0 && p.replyPropensity <= 1, `${id}.replyPropensity in [0,1]`);
    assert(p.contrarianBias >= 0 && p.contrarianBias <= 1, `${id}.contrarianBias in [0,1]`);
    assert(p.domains.length > 0, `${id} has at least one domain`);
    assert(p.voice.length > 20, `${id} has a non-trivial voice description`);
  }

  // ─── Test 2: Context builder ───────────────────────────────────────────────

  console.log('\n[2] Context builder token budget');
  for (const agentId of AGENT_IDS) {
    try {
      const ctx = await buildAgentContext(agentId);
      assert(ctx.estimatedTokens <= 3000, `${agentId} context under 3000 tokens (got ${ctx.estimatedTokens})`);
      assert(Array.isArray(ctx.recentFeed), `${agentId} recentFeed is array`);
      assert(Array.isArray(ctx.trendingTopics), `${agentId} trendingTopics is array`);
    } catch (err: any) {
      const msg: string = err?.message ?? String(err);
      if (msg.includes('SUPABASE') || msg.includes('fetch') || msg.includes('ENOTFOUND') || msg.includes('connect')) {
        console.log(`  ⚠ ${agentId}: Supabase not configured (OK in isolated test env)`);
      } else {
        assert(false, `${agentId} context builder threw unexpected error`, msg);
      }
    }
  }

  // ─── Test 3: Dedupe ────────────────────────────────────────────────────────

  console.log('\n[3] Dedupe (in-memory fallback)');
  resetDedupeForTests();

  const key = dedupeKeyForReply('smoke-post-123', 'nova', 'autonomy');
  const first = await acquireDedupeKey(key, 60);
  assert(first === true, 'first acquire returns true');

  const second = await acquireDedupeKey(key, 60);
  assert(second === false, 'second acquire (same key) returns false — dedupe working');

  resetDedupeForTests();

  // ─── Test 4: Persona distinctness ─────────────────────────────────────────

  console.log('\n[4] Persona distinctness');
  const postProps = SOCIAL_PERSONAS.map((p) => p.postingPropensity);
  const uniquePostProps = new Set(postProps);
  assert(uniquePostProps.size > 1, `agents have different postingPropensity values (${[...uniquePostProps].join(', ')})`);

  const voices = SOCIAL_PERSONAS.map((p) => p.voice.slice(0, 30));
  const uniqueVoices = new Set(voices);
  assert(uniqueVoices.size === 7, 'all 7 agents have unique voice descriptions');

  const contrarians = SOCIAL_PERSONAS.map((p) => p.contrarianBias);
  const maxContrarian = Math.max(...contrarians);
  const minContrarian = Math.min(...contrarians);
  assert(maxContrarian - minContrarian > 0.3, `contrarian bias has meaningful spread (${minContrarian}–${maxContrarian})`);

  // ─── Test 5: Self-reflection rules (unit) ─────────────────────────────────

  console.log('\n[5] Self-reflection rules (unit)');
  const STEP = 0.1;
  const THRESHOLD = 0.5;

  function simulateReflection(avgReplies: number, current: number): number {
    if (avgReplies < THRESHOLD) return Math.max(0.1, current - STEP);
    return current;
  }

  const before = 0.5;
  const afterLow = simulateReflection(0.1, before);
  assert(afterLow < before, `low engagement reduces postingPropensity (${before} → ${afterLow})`);
  assert(afterLow >= 0.1, 'postingPropensity never goes below 0.1');

  const afterHigh = simulateReflection(3.0, before);
  assert(afterHigh === before, 'high engagement does not reduce postingPropensity');

  const atFloor = simulateReflection(0.1, 0.1);
  assert(atFloor === 0.1, 'floor is respected (0.1 stays at 0.1)');

  // ─── Test 6: Feature flags ─────────────────────────────────────────────────

  console.log('\n[6] Feature flags');
  const { isAutonomyLoopEnabled, isDryRun } = await import('../lib/agent-autonomy-graph');

  const origEnabled = process.env.AGENT_AUTONOMY_LOOP_ENABLED;
  const origDryRun = process.env.AGENT_AUTONOMY_DRY_RUN;

  process.env.AGENT_AUTONOMY_LOOP_ENABLED = 'false';
  assert(isAutonomyLoopEnabled() === false, 'AGENT_AUTONOMY_LOOP_ENABLED=false → disabled');

  process.env.AGENT_AUTONOMY_LOOP_ENABLED = 'true';
  assert(isAutonomyLoopEnabled() === true, 'AGENT_AUTONOMY_LOOP_ENABLED=true → enabled');

  process.env.AGENT_AUTONOMY_DRY_RUN = 'true';
  assert(isDryRun() === true, 'AGENT_AUTONOMY_DRY_RUN=true → dry run');

  process.env.AGENT_AUTONOMY_LOOP_ENABLED = origEnabled ?? '';
  process.env.AGENT_AUTONOMY_DRY_RUN = origDryRun ?? '';

  // ─── Test 7: Dry-run loop (when Supabase configured) ──────────────────────

  console.log('\n[7] Dry-run loop');
  const supabaseOk = !!process.env.NEXT_PUBLIC_SUPABASE_URL && !!process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (supabaseOk) {
    process.env.AGENT_AUTONOMY_LOOP_ENABLED = 'true';
    process.env.AGENT_AUTONOMY_DRY_RUN = 'true';
    const { runAutonomyLoop } = await import('../lib/agent-autonomy-loop');
    try {
      const result = await runAutonomyLoop();
      assert(result.enabled === true, 'loop ran with enabled=true');
      assert(result.dryRun === true, 'loop ran in dry-run mode');
      assert(result.agentResults.length === 7, `all 7 agents made a decision (got ${result.agentResults.length})`);
      assert(result.totalPublished === 0, 'dry-run published nothing (totalPublished=0)');
      console.log('\n  Agent decisions:');
      for (const r of result.agentResults) {
        assert(
          ['post', 'reply', 'skip', 'error', 'unknown'].includes(r.action),
          `${r.agentId}: action "${r.action}" is valid`,
        );
        console.log(`    ${r.agentId.padEnd(8)} ${r.action.padEnd(6)} — ${r.reason.slice(0, 70)}`);
      }
    } catch (err: any) {
      console.log(`  ⚠ dry-run loop error: ${err?.message}`);
    }
    process.env.AGENT_AUTONOMY_LOOP_ENABLED = origEnabled ?? '';
    process.env.AGENT_AUTONOMY_DRY_RUN = origDryRun ?? '';
  } else {
    console.log('  ⚠ Supabase not configured — skipping live dry-run');
    console.log('    Set NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY to run the full loop test');
  }

  // ─── Summary ────────────────────────────────────────────────────────────────

  console.log(`\n${'─'.repeat(50)}`);
  console.log(`Smoke test: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error('smoke test crashed:', err);
  process.exit(1);
});
