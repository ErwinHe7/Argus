import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { shortlistAge, shortlistSchema } from './contract';
const source = JSON.parse(readFileSync(new URL('../data/shortlist.json', import.meta.url), 'utf8'));
test('the rendered shortlist is a frozen descriptive artifact bound to its actual source file', () => {
  const data = shortlistSchema.parse(source);
  assert.equal(data.inputSha256, createHash('sha256').update(readFileSync(new URL('../data/desk-data.json', import.meta.url))).digest('hex'));
  assert.equal(data.predictionEnabled, false); assert.equal(data.executionEnabled, false);
  assert.equal(data.universe.companyStocks, 5); assert.equal(data.universe.funds, 3);
  assert.deepEqual(data.stocks.slice(0, 3).map(row => row.symbol), ['NVDA', 'ZM', 'AMZN']);
  assert.ok(data.funds.some(row => row.symbol === 'DXYZ'));
  assert.ok(!data.stocks.some(row => row.symbol === 'DXYZ'));
});
test('contradictory rankings and criterion counts are rejected before rendering', () => {
  for (const mutate of [
    (data: any) => { data.stocks[0].criteriaMet = 0; },
    (data: any) => { data.stocks[0].rank = 9; },
    (data: any) => { data.stocks[0].asOf = '2026-09-03'; },
    (data: any) => { data.universe.eligibleCompanyStocks = 99; },
    (data: any) => { data.stocks[0].close = -1; },
  ]) { const next = structuredClone(source); mutate(next); assert.equal(shortlistSchema.safeParse(next).success, false); }
});
test('historical snapshots cannot silently become forecasts or execution authority', () => {
  for (const field of ['predictionEnabled', 'executionEnabled']) assert.equal(shortlistSchema.safeParse({ ...source, [field]: true }).success, false);
  assert.equal(shortlistSchema.safeParse({ ...source, dataMode: 'live' }).success, false);
});
test('freshness expires at the declared review deadline and rejects future evidence', () => {
  const data = shortlistSchema.parse(source);
  const deadline = Date.parse('2026-09-08T20:00:00Z');
  assert.equal(data.reviewAfter, '2026-09-08T20:00:00Z');
  assert.equal(shortlistAge(data, deadline - 1), 'dated');
  assert.equal(shortlistAge(data, deadline), 'review-needed');
  assert.equal(shortlistAge(data, Date.parse('2026-09-01T00:00:00Z')), 'invalid-future');
  assert.equal(shortlistAge({ ...data, reviewAfter: null }, deadline), 'dated');
});
