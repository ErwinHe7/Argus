import assert from 'node:assert/strict';
import test from 'node:test';
import { earningsReportSchema, earningsRequestTemplate } from './earnings-contract';

function fixture() {
  return {
    schema_version: 'leo-earnings-comparison.v1', feature_version: 'earnings-comparison-1.0.0',
    status: 'available', symbol: 'TEST', as_of: '2026-09-10T19:59:00Z', event_at: '2026-09-10T21:00:00Z',
    reason_codes: [], input_sha256: 'a'.repeat(64), prediction_enabled: false, execution_enabled: false,
    sources: Array.from({ length: 4 }, () => ({ title: 'FICTIONAL test evidence', url: 'https://example.invalid/test' })),
    limitations: ['FICTIONAL test fixture. Never publish as market evidence.'],
    comparison: { historical_count: 3, event_ids: ['TEST-1', 'TEST-2', 'TEST-3'], absolute_moves_percent: [10, 5, 0],
      median_absolute_move_percent: 5, raw_up_count: 1, raw_down_count: 1, raw_flat_count: 1,
      raw_up_frequency_percent: 100 / 3, straddle_mid_cost_percent: 5, straddle_ask_cost_percent: 6,
      cost_to_historical_median_ratio: 1 },
  };
}

test('accepts bounded research evidence, rejects invented prediction fields and permissions', () => {
  assert.equal(earningsReportSchema.safeParse(fixture()).success, true);
  assert.equal(earningsReportSchema.safeParse({ ...fixture(), prediction_enabled: true }).success, false);
  assert.equal(earningsReportSchema.safeParse({ ...fixture(), direction: 'bullish' }).success, false);
  assert.equal(earningsReportSchema.safeParse({ ...fixture(), execution_enabled: true }).success, false);
});

test('rejects mismatched counts, lookahead, crossed cost and unknown calculation values', () => {
  const value = fixture();
  value.comparison.raw_up_count = 2;
  assert.equal(earningsReportSchema.safeParse(value).success, false);
  assert.equal(earningsReportSchema.safeParse({ ...fixture(), as_of: '2026-09-11T00:00:00Z' }).success, false);
  const crossed = fixture(); crossed.comparison.straddle_ask_cost_percent = 1;
  assert.equal(earningsReportSchema.safeParse(crossed).success, false);
  const nonfinite = fixture(); nonfinite.comparison.median_absolute_move_percent = Number.POSITIVE_INFINITY;
  assert.equal(earningsReportSchema.safeParse(nonfinite).success, false);
});

test('unavailable reports withhold all comparisons; empty template carries no fake inputs', () => {
  assert.equal(earningsReportSchema.safeParse({ ...fixture(), status: 'unavailable', reason_codes: ['option_quotes_unavailable'], comparison: null }).success, true);
  assert.equal(earningsReportSchema.safeParse({ ...fixture(), status: 'unavailable', reason_codes: ['option_quotes_unavailable'] }).success, false);
  assert.equal(earningsRequestTemplate.options, null);
  assert.deepEqual(earningsRequestTemplate.history, []);
  assert.equal(earningsRequestTemplate.history_entitled, false);
});
