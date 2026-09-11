import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateMarketMapSnapshot } from '../lib/market-map/validate';
import type { MarketMapSnapshot } from '../lib/market-map/types';

const readReview = (name = 'review'): MarketMapSnapshot => JSON.parse(readFileSync(new URL(`../lib/market-map/artifacts/${name}.json`, import.meta.url), 'utf8')).snapshot;

test('all four explicit review artifacts pass the complete serialization contract', () => {
  for (const name of ['review', 'review-5d', 'review-10d', 'review-60d']) {
    assert.ok(validateMarketMapSnapshot(readReview(name), { review: true }));
  }
});

test('synthetic review cannot enter the production data path', () => {
  assert.equal(validateMarketMapSnapshot(readReview()), null);
});

test('crossed levels and unresolved evidence cannot enter review either', () => {
  const invalid = readReview();
  invalid.read.items[0].evidence_refs = ['missing-reference'];
  assert.equal(validateMarketMapSnapshot(invalid, { review: true }), null);
});

function isolatedLiveLikeFixture() {
  const snapshot = readReview();
  snapshot.asset.symbol = 'SPY';
  snapshot.provenance.sources.forEach((source) => { source.provider = 'TestVendor'; source.dataset = 'TestDaily'; });
  snapshot.provenance.rights.display_authorized = true;
  snapshot.provenance.rights.entitlement = 'member_research';
  return snapshot;
}

test('expired, incomplete and noncausal artifacts fail closed', () => {
  const fixture = isolatedLiveLikeFixture();
  const validClock = new Date(Date.parse(fixture.provenance.generated_at) + 1000);
  assert.ok(validateMarketMapSnapshot(fixture, { now: validClock }));
  assert.equal(validateMarketMapSnapshot(fixture, { now: new Date(fixture.provenance.freshness.expires_at) }), null);
  fixture.provenance.coverage.required_inputs[0].state = 'missing';
  assert.equal(validateMarketMapSnapshot(fixture, { now: validClock }), null);
  fixture.provenance.coverage.required_inputs[0].state = 'available';
  fixture.provenance.sources[0].observed_at = new Date(validClock.getTime() + 10000).toISOString();
  assert.equal(validateMarketMapSnapshot(fixture, { now: validClock }), null);
});

test('a stale IV tail is rejected even when supplied coverage claims complete', () => {
  const fixture = isolatedLiveLikeFixture();
  const validClock = new Date(Date.parse(fixture.provenance.generated_at) + 1000);
  fixture.panels.implied_volatility.series = fixture.panels.implied_volatility.series.slice(0, -1);
  assert.equal(validateMarketMapSnapshot(fixture, { now: validClock }), null);
});
