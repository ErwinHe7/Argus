import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { pipelineStatusFromReceipt } from '../lib/quant/production-readiness';

function readyForecast(symbol: string) {
  return {
    symbol,
    artifact_present: true,
    validation_status: 'PASSED',
    calibration: 'PROMOTED',
    promotion_registry_matches: true,
    ready: true,
    live_inference: {
      status_available: true,
      status: 'PUBLISHED',
      stage: 'PUBLISHED',
      context_blockers: [] as Array<Record<string, unknown>>,
      forecast_committed: true,
      receipt_committed: true,
      ledger_persisted: true,
      end_to_end_ms: 1800,
      budget_ms: 5000,
    },
  };
}

test('all target gates produce a ready pipeline without reading forecast values', () => {
  const status = pipelineStatusFromReceipt({
    public_realtime_research_ready: true,
    forecasts: [readyForecast('SPY'), readyForecast('QQQ')],
  });

  assert.deepEqual(status.counts, {
    targets: 2,
    contextReady: 2,
    inferred: 2,
    calibrated: 2,
    promoted: 2,
    published: 2,
    withinSla: 2,
    researchReady: 2,
  });
  assert.equal(status.liveResearchReady, true);
  assert.equal(status.liveForecastReady, true);
  assert.equal(status.readiness.context?.state, 'ready');
  assert.equal(status.readiness.inference?.state, 'ready');
  assert.equal(status.readiness.publication?.state, 'ready');
});

test('a context gap and an uncommitted peer fail closed even if the global flag is true', () => {
  const blocked = readyForecast('QQQ');
  blocked.ready = false;
  blocked.calibration = 'UNPROMOTED';
  blocked.promotion_registry_matches = false;
  blocked.live_inference = {
    ...blocked.live_inference,
    status: 'WAITING_FOR_CONTEXT',
    stage: 'FEATURE_ENGINE',
    context_blockers: [{ symbol: 'HYG', reason_codes: ['CONTEXT_GAP'] }],
    forecast_committed: false,
    receipt_committed: false,
    ledger_persisted: false,
    end_to_end_ms: 5500,
  };
  const status = pipelineStatusFromReceipt({
    public_realtime_research_ready: true,
    forecasts: [readyForecast('SPY'), blocked],
  });

  assert.equal(status.liveForecastReady, false);
  assert.equal(status.counts.contextReady, 1);
  assert.equal(status.counts.inferred, 1);
  assert.equal(status.counts.calibrated, 1);
  assert.equal(status.counts.promoted, 1);
  assert.equal(status.counts.published, 1);
  assert.equal(status.counts.withinSla, 1);
  assert.equal(status.counts.researchReady, 1);
  assert.equal(status.liveResearchReady, true);
  assert.equal(status.readiness.context?.state, 'waiting');
  assert.equal(status.readiness.inference?.state, 'blocked');
  assert.equal(status.readiness.publication?.state, 'blocked');
});

test('missing or malformed forecast rows never become ready', () => {
  const status = pipelineStatusFromReceipt({
    public_realtime_research_ready: true,
    forecasts: [null, 'invalid'],
  });
  assert.equal(status.counts.targets, 2);
  assert.equal(status.counts.contextReady, 0);
  assert.equal(status.counts.researchReady, 0);
  assert.equal(status.liveResearchReady, false);
  assert.equal(status.liveForecastReady, false);
  assert.equal(status.readiness.context?.state, 'blocked');
  assert.equal(status.readiness.inference?.state, 'blocked');
  assert.equal(status.readiness.publication?.state, 'blocked');
});

test('a malformed peer cannot disappear from the readiness denominator', () => {
  const status = pipelineStatusFromReceipt({
    public_realtime_research_ready: true,
    forecasts: [readyForecast('SPY'), 'invalid'],
  });
  assert.equal(status.counts.targets, 2);
  assert.equal(status.counts.published, 1);
  assert.equal(status.counts.researchReady, 1);
  assert.equal(status.liveResearchReady, true);
  assert.equal(status.liveForecastReady, false);
  assert.equal(status.readiness.publication?.state, 'blocked');
});

test('unpromoted output is usable research while official forecast stays blocked', () => {
  const researchOnly = readyForecast('SPY');
  researchOnly.ready = false;
  researchOnly.calibration = 'UNPROMOTED';
  researchOnly.promotion_registry_matches = false;
  const status = pipelineStatusFromReceipt({
    public_realtime_research_ready: false,
    forecasts: [researchOnly],
  });

  assert.equal(status.counts.researchReady, 1);
  assert.equal(status.liveResearchReady, true);
  assert.equal(status.liveForecastReady, false);
  assert.equal(status.readiness.publication?.state, 'blocked');
});

test('the readiness reducer does not inspect or calculate forecast economics', async () => {
  const source = await readFile(
    new URL('../lib/quant/production-readiness.ts', import.meta.url),
    'utf8'
  );
  for (const forbidden of [
    'expected_return',
    'return_quantiles',
    'p_positive_after_cost',
    'calibrated_probability_up',
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
});
