import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { assertPublishable, foundryAge, foundryPublicationSchema } from './contract';

const source = JSON.parse(readFileSync(new URL('../data/foundry.json', import.meta.url), 'utf8'));
const fixtureUrl = new URL('./fixtures/synthetic-publication.json', import.meta.url);
const sha = (digit: string) => digit.repeat(64);

/** Hand-written published shape. Values are arbitrary placeholders, not market evidence. */
function published(): any {
  const value = structuredClone(source);
  Object.assign(value, { generatedAt: '2026-10-01T12:00:00Z', derivedPublicationRightsConfirmed: true });
  value.overlay = { status: 'PUBLISHED', artifact: {
    symbolLabel: 'Redacted holding', structure: 'collar', pricingMode: 'EXECUTABLE_QUOTES', evidenceStatus: 'EXECUTABLE_QUOTES_OBSERVED',
    engineVersion: 'leo-overlay-engine.v1', inputSha256: sha('a'), configSha256: sha('b'),
    observationCutoff: '2026-09-30T20:00:00+00:00', availabilityCutoff: '2026-09-30T20:05:00Z', freshness: 'historical_backtest_not_live',
    coverage: { sessions: 2, start: '2026-09-29', end: '2026-09-30', calendarSource: 'exchange_calendars XNYS', cycles: 1, deferredRolls: 0 },
    source: { name: 'Owner-supplied vendor export', licenseScope: 'Derived statistics only', quoteSources: ['vendor'], ivSources: [] },
    metrics: {
      overlay: { totalReturnPct: 1.25, annualizedReturnPct: null, annualizedVolatilityPct: 9.5, maxDrawdownPct: -2.1, downsideCapturePct: 60, upsideCapturePct: 70, premiumYieldAnnualizedPct: 4.2 },
      buyAndHold: { totalReturnPct: 1.5, annualizedReturnPct: null, annualizedVolatilityPct: 12, maxDrawdownPct: -3 },
      difference: { totalReturnPct: -0.25, maxDrawdownPct: 0.9 },
      counts: { assignments: 0, capHits: 0, putExercises: 0, deferredRolls: 0, exDividendItmShortCallEvents: 0 },
      activeReturnBootstrap: { status: 'insufficient_sessions', lower95Pct: null, upper95Pct: null, resamples: null, blockLength: null },
      activeReturnSignFlipP: null,
    },
    cycles: [{ cycleId: 'cycle-0001', opened: '2026-09-29', expiry: '2026-11-20', outcome: 'open_at_cutoff', overlayReturnPct: 1.25, baselineReturnPct: 1.5,
      legs: [{ right: 'call', side: 'short', strikeMoneynessPct: 5, dte: 52, fillSide: 'bid' }, { right: 'put', side: 'long', strikeMoneynessPct: -5, dte: 52, fillSide: 'ask' }] }],
    assumptions: ['Physical settlement at the expiry close.'], caveats: ['Historical backtest, not live.'],
    executionAuthorized: false, optionsExecutionEnabled: false, promotionEligible: false,
  } };
  value.ledger = { status: 'PUBLISHED', ledger: {
    headSha256: sha('c'), eventCount: 2, trialsTotal: 1, llmCalls: 0,
    specs: [{ specId: 'spec-mr-0001', template: 'MR-v1', symbolLabel: 'Redacted holding', stage: 'PROBE', status: 'REJECTED_NO_DEPLOYABLE_EDGE', familyTrialCount: 1, survivors: 0,
      gates: [{ id: 'probe_positive', passed: false, detail: 'Compounded development statistic was not positive.' }], nextAction: 'None; the owner may draft a new idea.' }],
    events: [
      { seq: 1, at: '2026-10-01T11:00:00+00:00', specId: 'spec-mr-0001', role: 'prototype_builder', kind: 'SPEC_FROZEN', fromStage: null, toStage: 'PROBE', status: 'ACTIVE', reasons: [] },
      { seq: 2, at: '2026-10-01T11:30:00Z', specId: 'spec-mr-0001', role: 'sweeper', kind: 'REJECTED_NO_DEPLOYABLE_EDGE', fromStage: 'PROBE', toStage: null, status: 'REJECTED_NO_DEPLOYABLE_EDGE', reasons: ['NON_POSITIVE_PROBE'] },
    ],
  } };
  return value;
}
const rejects = (mutate: (value: any) => void, base = published) => { const value = base(); mutate(value); return !foundryPublicationSchema.safeParse(value).success; };

test('the committed publication parses, keeps execution disabled, and ships nothing unconfirmed', () => {
  const data = assertPublishable(foundryPublicationSchema.parse(source));
  assert.equal(data.executionAuthorized, false); assert.equal(data.optionsExecutionEnabled, false);
  assert.equal(data.liveStagesLocked, true); assert.equal(data.llmCalls, 0);
  assert.deepEqual(data.roles.map(role => role.id), ['prototype_builder', 'sweeper', 'grower', 'maintainer']);
  assert.deepEqual(data.ladder.map(stage => [stage.id, stage.locked]), [['PROBE', false], ['BACKTEST', false], ['PAPER', false], ['LIVE_SMALL', true], ['LIVE_SCALED', true]]);
  if (data.overlay.status === 'ARTIFACT_PENDING' && data.ledger.status === 'ARTIFACT_PENDING') {
    assert.equal(data.generatedAt, null); assert.equal(foundryAge(data), 'pending');
  } else {
    assert.equal(data.derivedPublicationRightsConfirmed, true); assert.equal(foundryAge(data), 'historical');
  }
});

test('the synthetic drift fixture matches the schema but can never be published', { skip: !existsSync(fixtureUrl) && 'fixture not generated yet' }, () => {
  const fixture = foundryPublicationSchema.parse(JSON.parse(readFileSync(fixtureUrl, 'utf8')));
  assert.equal(fixture.overlay.status === 'PUBLISHED' && fixture.overlay.artifact.evidenceStatus, 'SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE');
  assert.throws(() => assertPublishable(fixture), /Synthetic fixture/);
});

test('a hand-written published shape is accepted and gated by evidence status', () => {
  const data = foundryPublicationSchema.parse(published());
  assert.equal(assertPublishable(data), data);
  assert.equal(foundryAge(data, Date.parse('2026-10-02T00:00:00Z')), 'historical');
  assert.equal(foundryAge(data, Date.parse('2026-10-01T11:00:00Z')), 'invalid-future');
  const synthetic = published(); synthetic.overlay.artifact.evidenceStatus = 'SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE';
  assert.throws(() => assertPublishable(foundryPublicationSchema.parse(synthetic)), /Synthetic fixture/);
  const modelled = published(); Object.assign(modelled.overlay.artifact, { pricingMode: 'MODEL_PRICED', evidenceStatus: 'MODEL_PRICED_NOT_EXECUTABLE' });
  for (const item of modelled.overlay.artifact.cycles[0].legs) item.fillSide = 'model';
  assert.equal(foundryPublicationSchema.safeParse(modelled).success, true);
});

test('published sections require confirmed rights and a generation time', () => {
  assert.ok(rejects(value => { value.derivedPublicationRightsConfirmed = false; }));
  assert.ok(rejects(value => { value.generatedAt = null; }));
  assert.ok(rejects(value => { value.derivedPublicationRightsConfirmed = false; value.overlay = structuredClone(source.overlay); }));
  assert.ok(rejects(value => { value.derivedPublicationRightsConfirmed = false; value.ledger = structuredClone(source.ledger); }));
});

test('model-priced results stay labelled not executable with model fills', () => {
  assert.ok(rejects(value => { value.overlay.artifact.pricingMode = 'MODEL_PRICED'; }));
  assert.ok(rejects(value => { value.overlay.artifact.evidenceStatus = 'MODEL_PRICED_NOT_EXECUTABLE'; }));
  assert.ok(rejects(value => { Object.assign(value.overlay.artifact, { pricingMode: 'MODEL_PRICED', evidenceStatus: 'MODEL_PRICED_NOT_EXECUTABLE' }); }));
  assert.ok(rejects(value => { value.overlay.artifact.cycles[0].legs[0].fillSide = 'ask'; }));
  assert.ok(rejects(value => { value.overlay.artifact.structure = 'covered_call'; }));
});

test('live stages stay locked and unreachable', () => {
  assert.ok(rejects(value => { Object.assign(value.ladder[3], { locked: false, lockReason: null, futureGates: [] }); }));
  assert.ok(rejects(value => { value.ladder[4].locked = false; }));
  assert.ok(rejects(value => { value.ladder[3].futureGates = []; }));
  assert.ok(rejects(value => { value.ladder[2].locked = true; }));
  assert.ok(rejects(value => { value.liveStagesLocked = false; }));
  assert.ok(rejects(value => { value.ladder.reverse(); }));
  assert.ok(rejects(value => { value.roles.reverse(); }));
  assert.ok(rejects(value => { value.ledger.ledger.specs[0].stage = 'LIVE_SMALL'; }));
  assert.ok(rejects(value => { value.ledger.ledger.events[1].toStage = 'LIVE_SMALL'; }));
});

test('execution flags, LLM calls, and undeclared keys are rejected everywhere', () => {
  for (const field of ['executionAuthorized', 'optionsExecutionEnabled']) assert.ok(rejects(value => { value[field] = true; }));
  for (const field of ['executionAuthorized', 'optionsExecutionEnabled', 'promotionEligible']) assert.ok(rejects(value => { value.overlay.artifact[field] = true; }));
  assert.ok(rejects(value => { value.llmCalls = 1; }));
  assert.ok(rejects(value => { value.ledger.ledger.llmCalls = 2; }));
  assert.ok(rejects(value => { value.idea = 'Owner idea text'; }));
  assert.ok(rejects(value => { value.roles[0].prompt = 'free text'; }));
  assert.ok(rejects(value => { value.overlay.artifact.bid = 1.2; }));
  assert.ok(rejects(value => { value.overlay.artifact.cycles[0].legs[0].fillPrice = 1.2; }));
  assert.ok(rejects(value => { value.ledger.ledger.events[0].receipt = null; }));
  assert.ok(rejects(value => { value.overlay.reason = 'extra'; }));
  assert.ok(rejects(value => { value.overlay.artifact.freshness = 'live'; }));
});

test('evidence cannot follow the publication time or arrive out of order', () => {
  assert.ok(rejects(value => { value.overlay.artifact.availabilityCutoff = '2026-10-01T12:05:01Z'; }));
  assert.equal(rejects(value => { value.overlay.artifact.availabilityCutoff = '2026-10-01T12:05:00Z'; }), false);
  assert.ok(rejects(value => { value.ledger.ledger.events[1].at = '2026-10-02T00:00:00Z'; }));
  assert.ok(rejects(value => { value.overlay.artifact.coverage.end = '2026-10-02'; }));
  assert.ok(rejects(value => { value.ledger.ledger.events.reverse(); }));
  assert.ok(rejects(value => { value.ledger.ledger.eventCount = 1; }));
  assert.ok(rejects(value => { value.overlay.artifact.metrics.counts.deferredRolls = 3; }));
  assert.ok(rejects(value => { value.overlay.artifact.observationCutoff = '2026-09-30T16:00:00-04:00'; }));
  assert.equal(rejects(value => { value.overlay.artifact.cycles[0].expiry = '2027-01-15'; }), false);
});
