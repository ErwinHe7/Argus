import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { IV_LAB_SYMBOLS, ivLabBundleSchema, ivLabEventsSchema, parseIvLabQuery,
  validateIvLabBundle, type IvLabBundle } from '../lib/iv-lab/types';

const bundle = JSON.parse(readFileSync(new URL('../lib/iv-lab/artifacts/iv-lab.json', import.meta.url), 'utf8')) as IvLabBundle;
const events: unknown = JSON.parse(readFileSync(new URL('../lib/iv-lab/artifacts/events.json', import.meta.url), 'utf8'));
const copy = () => structuredClone(bundle);

test('the URL allowlist accepts exactly one of the six research symbols', () => {
  for (const symbol of IV_LAB_SYMBOLS) assert.equal(parseIvLabQuery(new URLSearchParams({ symbol })), symbol);
  for (const value of ['', 'symbol=SPY', 'symbol=avgo', 'symbol=AVGO&symbol=NVDA',
    'symbol=AVGO&symbol=AVGO', 'symbol=AVGO&live=true', 'symbol=%20AVGO', 'symbol=']) {
    assert.equal(parseIvLabQuery(new URLSearchParams(value)), null, value);
  }
});

test('the imported artifact preserves unknown timestamps and historical status', () => {
  const parsed = validateIvLabBundle(bundle);
  assert.ok(parsed);
  assert.equal(parsed.methodology.premiumAndPnlUnits, 'USD per share');
  assert.equal(parsed.methodology.assumedContractMultiplier, 100);
  for (const symbol of parsed.symbols) {
    assert.equal(symbol.market.freshness, 'historical_snapshot_not_live');
    assert.equal(symbol.ivAssumption.observedAt, null);
    assert.equal(symbol.market.dailyBarCloseObservedAt, null);
    assert.equal(symbol.technical.predictionModelApplied, false);
    assert.deepEqual(symbol.configurations, bundle.symbols.find((item) => item.symbol === symbol.symbol)!.configurations);
  }
  assert.ok(parsed.symbols.find((item) => item.symbol === 'AVGO')!.optionEvidence.length > 0);
  assert.ok(ivLabEventsSchema.safeParse(events).success);
});

test('bad numerical values, changed P&L units, and ready/execute claims fail closed', () => {
  const mutations: Array<(value: any) => void> = [
    (value) => { value.symbols[0].configurations[0].scenarios[0].cells[0].pnl = NaN; },
    (value) => { value.symbols[0].market.spot = Infinity; },
    (value) => { value.methodology.premiumAndPnlUnits = 'USD per contract'; },
    (value) => { value.methodology.vegaUnits = 'per 100 percentage points'; },
    (value) => { value.symbols[0].ivAssumption.units = 'annualIv percent'; },
    (value) => { value.methodology.executionEnabled = true; },
    (value) => { value.methodology.predictionModelPromoted = true; },
    (value) => { value.symbols[0].market.freshness = 'fresh'; },
    (value) => { value.calibratedProbability = { status: 'ready', value: 0.8 }; },
  ];
  for (const mutate of mutations) {
    const value = copy(); mutate(value);
    assert.equal(validateIvLabBundle(value), null);
  }
});

test('partial scenario grids and duplicate identities cannot look complete', () => {
  for (const mutate of [
    (value: IvLabBundle) => { value.symbols[0].configurations[0].scenarios[0].cells.pop(); },
    (value: IvLabBundle) => { value.symbols[0].configurations[0].scenarios[0].cells[1] = value.symbols[0].configurations[0].scenarios[0].cells[0]; },
    (value: IvLabBundle) => { value.symbols[1].symbol = value.symbols[0].symbol; },
  ]) {
    const value = copy(); mutate(value);
    assert.equal(validateIvLabBundle(value), null);
  }
});

test('an impossible date, future availability, or fabricated IV timestamp is rejected', () => {
  const value = copy();
  value.symbols[0].market.observedAt = '2026-02-30T14:00:00Z';
  assert.equal(validateIvLabBundle(value), null);
  value.symbols[0].market.observedAt = bundle.symbols[0].market.observedAt;
  value.symbols[0].market.availableAt = '2099-01-01T00:00:00Z';
  assert.equal(validateIvLabBundle(value), null);
  const invented = copy() as any;
  invented.symbols[0].ivAssumption.observedAt = invented.generatedAt;
  assert.equal(ivLabBundleSchema.safeParse(invented).success, false);
});

test('an unconfirmed IPO or model release cannot acquire a dated countdown', () => {
  const value = structuredClone(events) as any;
  const event = value.events.find((item: any) => item.status === 'unconfirmed-date');
  assert.ok(event);
  event.eventDate = '2026-09-30';
  assert.equal(ivLabEventsSchema.safeParse(value).success, false);
});
