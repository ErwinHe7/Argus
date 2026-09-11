/** Real native-CLI/browser-schema boundary; every observation below is fictional. */
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { earningsReportSchema } from '../radar/earnings-contract';

const binary = process.argv[2];
assert(binary, 'Pass the built earnings-radar native binary path');
const source = { title: 'FICTIONAL integration-test evidence', url: 'https://example.invalid/test-only' };
const sessions = [];
for (let offset = 0; offset < 40; offset++) {
  const date = new Date(Date.UTC(2026, 7, 3 + offset));
  const day = date.toISOString().slice(0, 10);
  if ([0, 6].includes(date.getUTCDay()) || day === '2026-09-07') continue;
  sessions.push({ date: day, open_at: `${day}T13:30:00Z`, close_at: `${day}T20:00:00Z` });
}
const cutoff = '2026-09-10T19:59:00Z';
const expiry = '2026-09-11T20:00:00Z';
const leg = { symbol: 'TEST', right: 'call', strike: 100, expiry_at: expiry, bid: 2, ask: 3, observed_at: cutoff, available_at: cutoff };
const request = {
  schema_version: 'leo-earnings-comparison-request.v1', symbol: 'TEST', as_of: cutoff,
  event_at: '2026-09-10T21:00:00Z', event_known_at: '2026-09-01T12:00:00Z', event_source: source,
  history_source: source, history_price_basis: 'split_adjusted_regular_close', history_entitled: true,
  calendar: { source, version: 'FICTIONAL-test-calendar', coverage_start: '2026-08-03', coverage_end: '2026-09-11', sessions },
  history: [110, 95, 100].map((price, index) => {
    const before = sessions[index * 2], after = sessions[index * 2 + 1];
    return { event_id: `TEST-${index}`, event_at: `${before.date}T21:00:00Z`, event_known_at: before.open_at, source,
      before: { session_date: before.date, observed_at: before.close_at, available_at: before.close_at, price: 100 },
      after: { session_date: after.date, observed_at: after.close_at, available_at: after.close_at, price } };
  }),
  options: { source, entitled: true, quote_unit: 'usd_per_share', spot: 100, spot_observed_at: cutoff,
    spot_available_at: cutoff, strike: 100, listed_strikes: [95, 100, 105], expiry_at: expiry,
    call: leg, put: { ...leg, right: 'put' } },
};
function run(value: unknown) {
  const result = spawnSync(resolve(binary), [], { input: JSON.stringify(value), encoding: 'utf8', timeout: 15_000, maxBuffer: 512 * 1024, windowsHide: true });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  return JSON.parse(result.stdout);
}
const report = earningsReportSchema.parse(run(request));
assert.equal(report.status, 'available');
assert.equal(report.comparison?.historical_count, 3);
assert.equal(report.comparison?.straddle_mid_cost_percent, 5);
assert.equal(report.comparison?.straddle_ask_cost_percent, 6);
assert.equal(report.prediction_enabled, false);
const unavailable = earningsReportSchema.parse(run({ ...request, options: null }));
assert.equal(unavailable.status, 'unavailable');
assert.equal(unavailable.comparison, null);
assert.deepEqual(unavailable.reason_codes, ['option_quotes_unavailable']);
const malformed = run({ ...request, predict_direction: true });
assert.equal(malformed.status, 'unavailable');
assert.deepEqual(malformed.reason_codes, ['invalid_request']);
console.log(JSON.stringify({ schema: 'leo-earnings-cli-validation.v1', checks: 3, passed: true, input: 'fictional_only', brokerEvidence: false, nativeBinary: resolve(binary) }));
