import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchMassivePages, safeVendorUrl, selectResearchSessions, validateIvSessions } from './market-map-refresh.mjs';

test('vendor pagination cannot send credentials to another origin', async () => {
  let calls = 0;
  await assert.rejects(() => fetchMassivePages('/v3/reference/splits', 'not-a-real-key', async () => {
    calls++;
    return { ok: true, json: async () => ({ status: 'OK', results: [], next_url: 'https://attacker.invalid/collect' }) };
  }), /provider_url_rejected/);
  assert.equal(calls, 1);
  assert.equal(safeVendorUrl('https://api.massive.com/v3/reference/splits?apiKey=not-a-real-key').searchParams.has('apiKey'), false);
});

test('provider authorization errors expose only stable error codes', async () => {
  await assert.rejects(() => fetchMassivePages('/v3/reference/splits', 'not-a-real-key', async () => ({ ok: false, status: 403 })), { message: 'provider_not_entitled' });
});

test('explicit zero result pages are empty, missing responses are rejected', async () => {
  const response = (body) => async () => ({ ok: true, json: async () => body });
  assert.deepEqual((await fetchMassivePages('/v3/reference/splits', 'test', response({ status: 'OK', count: 0 }))).rows, []);
  await assert.rejects(() => fetchMassivePages('/v3/reference/splits', 'test', response({ status: 'OK' })), /provider_response_invalid/);
});

function calendarFixture() {
  const sessions = [];
  // Calendar fixture explicitly removes US Labor Day; production uses XNYS.
  for (let time = Date.parse('2026-04-01T00:00:00Z'); time < Date.parse('2027-01-01T00:00:00Z'); time += 86400000) {
    const date = new Date(time);
    const day = date.toISOString().slice(0, 10);
    if (![0, 6].includes(date.getUTCDay()) && day !== '2026-09-07') sessions.push({ date: day, open: `${day}T13:30:00Z`, close: `${day}T20:00:00Z` });
  }
  return { schema_version: 'market-map-calendar.v1', source: 'isolated-test-calendar', sessions };
}

test('EOD freshness carries Friday across a weekend and supplied exchange holiday', () => {
  const selected = selectResearchSessions(calendarFixture(), new Date('2026-09-07T21:30:00Z'), 60, 60);
  assert.equal(selected.history.at(-1).date, '2026-09-04');
  assert.equal(selected.expiresAt, '2026-09-08T21:00:00.000Z');
});

test('15:45 IV observations align with 16:00 closes, while a missing session is rejected', () => {
  const sessions = calendarFixture().sessions.slice(0, 6);
  const iv = { series: sessions.map((session) => ({ observed_at: `${session.date}T19:45:00Z`, percent: 24 })) };
  assert.doesNotThrow(() => validateIvSessions(iv, sessions));
  iv.series[5].observed_at = iv.series[4].observed_at;
  assert.throws(() => validateIvSessions(iv, sessions), /same_tenor_atm_iv_history_stale/);
});
