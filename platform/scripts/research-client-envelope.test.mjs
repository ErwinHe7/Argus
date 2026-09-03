import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';

const source = readFileSync(
  new URL('../lib/quant/research-client.ts', import.meta.url),
  'utf8'
);
const compiled = ts
  .transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
  })
  .outputText.replace(/import ['"]server-only['"];\s*/, '');
const { verifyQuantResearchResponseText } = await import(
  `data:text/javascript;base64,${Buffer.from(compiled).toString('base64')}`
);
const explicitRuleCompletedBarFixtureText = readFileSync(
  new URL(
    '../quant_engine_rs/tests/fixtures/explicit_rule_completed_bar_contract.json',
    import.meta.url
  ),
  'utf8'
).trim();
const explicitRuleCompletedBarFixture = JSON.parse(
  explicitRuleCompletedBarFixtureText
);

function candidate() {
  return {
    symbol: 'NVDA',
    setup_type: 'statistical_dislocation',
    status: 'UNCALIBRATED_RESEARCH_OUTPUT',
    heuristic_structure_score: null,
    score_semantics: 'Uncalibrated direction only; rank withheld.',
    supporting_evidence: [
      {
        code: 'FRESH_NATIVE_FORECAST_CONTRACT',
        statement: 'Fresh native model evidence.',
        observed_value: 'POSITIVE_CONDITIONAL_MEAN',
      },
    ],
    contrary_evidence: [
      {
        code: 'PROBABILITY_AND_EXPECTED_MOVE_WITHHELD',
        statement: 'Probability, expected move, rank, and execution are withheld.',
        observed_value: 'WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION',
      },
    ],
    metrics: {
      statistical_orientation: 'POSITIVE_CONDITIONAL_MEAN',
      observation_cutoff: '2026-07-28T14:29:00Z',
      latest_input_available_at: '2026-07-28T14:29:02Z',
      data_age_seconds: 88,
      data_source: 'DATABENTO:EQUS.MINI',
      coverage: 1,
      coverage_semantics:
        'ALL_REQUIRED_TARGET_AND_CONTEXT_SYMBOLS_PRESENT_AT_THE_DECISION_CUTOFF',
      caveats: [
        'Provider send time is unavailable; availability uses the AXIO7 server receipt clock.',
        'OHLCV-1m bars do not include depth-of-book or options-chain observations.',
      ],
      published_probability_status:
        'WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION',
      validation: {
        model_version: 'nvda-model-v3',
        feature_version: 'feature-v4',
        model_hash: 'a'.repeat(64),
        feature_hash: 'b'.repeat(64),
        data_manifest_hash: 'c'.repeat(64),
        schema_version: 'databento_inference_receipt.v3',
        source_envelopes_sha256: 'e'.repeat(64),
        forecast_sha256: 'f'.repeat(64),
        published_at: '2026-07-28T14:29:06Z',
        end_to_end_ms: 4000,
        budget_ms: 5000,
      },
    },
    freshness: [
      {
        source: 'DATABENTO:EQUS.MINI',
        observed_at: '2026-07-28T14:29:00Z',
        available_at: '2026-07-28T14:29:02Z',
        age_seconds: 88,
        realtime: true,
        entitlement: 'LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED',
        coverage: 1,
      },
    ],
  };
}

function historical() {
  return {
    symbol: 'NVDA',
    setup_type: 'statistical_dislocation',
    method_version: 'causal-vwap-dislocation-5m.v2',
    event_definition: 'First causal completed-bar dislocation.',
    source: 'DATABENTO_EQUS_MINI',
    dataset_start: '2025-01-02',
    dataset_end: '2026-07-24',
    sessions: 390,
    event_sessions: 120,
    event_rate: 120 / 390,
    event_bar_q25: 8,
    event_bar_median: 16,
    event_bar_q75: 28,
    median_clock_et: '10:45-10:50',
    top_event_bars: [],
    forward_label_minutes: 15,
    completed_backtests: 118,
    session_integrity: {
      target_rows: 152100,
      unique_regular_session_rows: 152100,
      exact_duplicate_rows: 0,
      conflicting_duplicate_rows: 0,
      observed_sessions: 390,
      complete_sessions: 390,
      excluded_sessions: 0,
      session_exclusion_counts: {},
    },
    label_integrity: {
      detected_events: 120,
      completed_labels: 118,
      excluded_events: 2,
      event_exclusion_counts: {
        EVENT_TOO_LATE_FOR_EXACT_CLOCK_HORIZON: 1,
        MISSING_CONTIGUOUS_EXACT_CLOCK_HORIZON: 1,
      },
    },
    vwap_status: {
      policy:
        'SESSION_ATOMIC_AUTHORIZED_VENDOR_MINUTE_VWAP_OR_RECONSTRUCTED_CLOSE_VOLUME_PROXY',
      eligible_minute_rows: 152100,
      authorized_vendor_vwap_rows: 0,
      reported_but_unauthorized_vendor_vwap_rows: 0,
      authorized_vendor_minute_coverage: 0,
      sessions_using_authorized_vendor_vwap: 0,
      sessions_using_reconstructed_proxy: 390,
      parity_observations: 0,
      median_absolute_parity_bps: null,
      maximum_absolute_parity_bps: null,
    },
    entry_semantics: 'Next completed five-minute bar open.',
    assumed_round_trip_cost_bps: 3,
    raw_forward_direction_frequency: 0.56,
    median_forward_return: -0.001,
    forward_return_q05: -0.012,
    forward_return_q95: 0.01,
    median_mfe: 0.003,
    median_mae: -0.004,
    net_win_rate: 0.54,
    mean_net_return: 0.0007,
    median_net_return: 0.0005,
    cumulative_net_return: 0.082,
    max_drawdown: -0.041,
    edge_classification: 'POSITIVE_AFTER_COST_DESCRIPTIVE',
    edge_classification_detail:
      'Mean, median, and cumulative returns are positive after stated costs in this exploratory sample; this descriptive result does not establish a statistically validated edge.',
    performance_scope:
      'HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE',
    data_manifest_hash: '9'.repeat(64),
    evidence_grade: 'CONTAMINATED_EXPLORATORY_DESCRIPTIVE',
    caveats: [
      'Historical condition replay, not frozen-model out-of-sample performance.',
      'Round-trip spread and slippage are modeled; market impact is not.',
    ],
  };
}

function readiness(state = 'ready') {
  return Object.fromEntries(
    ['model', 'feed', 'context', 'inference', 'publication'].map((stage) => [
      stage,
      {
        state,
        code: `${stage.toUpperCase()}_${state.toUpperCase()}`,
        detail: `${stage} is ${state}`,
        observed_at: '2026-07-28T14:29:02Z',
      },
    ])
  );
}

function envelope() {
  return {
    schema_version: 'axio.evidence-envelope.v1',
    request_id: 'audit-nvda-v3',
    query_sha256: 'd'.repeat(64),
    response_sha256: null,
    generated_at: '2026-07-28T14:30:31Z',
    observation_cutoff: '2026-07-28T14:30:30Z',
    status: 'UNCALIBRATED_RESEARCH_OUTPUT',
    query: {
      version: 'axio.market-query.v1',
      intent: 'scan',
      setup_type: 'statistical_dislocation',
      symbols: ['NVDA'],
      horizon_minutes: 15,
      limit: 1,
      filters: {},
    },
    candidates: [candidate()],
    exclusions: [],
    historical: [],
    data_blockers: [],
    readiness: readiness(),
    model_contract: {},
    research_only_policy: {},
    caveats: ['Uncalibrated direction only.'],
  };
}

function seal(payload) {
  const unsealed = JSON.stringify({ ...payload, response_sha256: null });
  const hash = createHash('sha256').update(unsealed).digest('hex');
  return JSON.stringify({ ...payload, response_sha256: hash });
}

async function rejectsContract(text) {
  await assert.rejects(
    verifyQuantResearchResponseText(text),
    (error) => error?.code === 'RUST_BACKEND_CONTRACT_MISMATCH'
  );
}

test('accepts an exactly sealed, complete uncalibrated evidence envelope', async () => {
  const payload = envelope();
  const verified = await verifyQuantResearchResponseText(seal(payload));
  assert.equal(verified.request_id, payload.request_id);
});

test('accepts the shared completed-bar explicit-rule fixture without inventing a model forecast', async () => {
  const verified = await verifyQuantResearchResponseText(
    explicitRuleCompletedBarFixtureText
  );
  const candidate = verified.candidates[0];
  const completedBucketEnd = '2026-07-27T13:40:00Z';
  const finalMinuteStart = '2026-07-27T13:39:00Z';
  const finalMinuteAvailableAt = '2026-07-27T13:40:00.250Z';

  assert.equal(verified.query.setup_type, 'vwap_reversal');
  assert.equal(candidate.setup_type, 'vwap_reversal');
  assert.notEqual(candidate.status, 'UNCALIBRATED_RESEARCH_OUTPUT');
  assert.equal(verified.historical.length, 0);
  assert.equal(verified.observation_cutoff, completedBucketEnd);
  assert.equal(candidate.metrics.observation_cutoff, completedBucketEnd);
  assert.equal(candidate.freshness[0].observed_at, completedBucketEnd);
  assert.equal(
    candidate.freshness[0].available_at,
    finalMinuteAvailableAt
  );
  assert.equal(candidate.metrics.coverage, 1);
  assert.equal(candidate.freshness[0].coverage, 1);
  assert.equal(
    Date.parse(finalMinuteStart) + 60_000,
    Date.parse(completedBucketEnd)
  );
  for (const forbidden of [
    'statistical_orientation',
    'expected_return',
    'expected_price',
    'probability_up_percent',
    'forecast_sha256',
  ]) {
    assert.equal(candidate.metrics[forbidden], undefined);
  }
});

test('rejects a completed-bar rule response whose metrics drift into a trailing partial bucket', async () => {
  const payload = structuredClone(explicitRuleCompletedBarFixture);
  payload.candidates[0].metrics.observation_cutoff =
    '2026-07-27T13:41:00Z';
  await rejectsContract(seal(payload));
});

test('accepts a valid candidate when no contrary evidence was observed', async () => {
  const payload = envelope();
  payload.candidates[0].contrary_evidence = [];
  const verified = await verifyQuantResearchResponseText(seal(payload));
  assert.equal(verified.candidates[0].contrary_evidence.length, 0);
});

test('requires explicit pipeline readiness for query-v2 model forecasts', async () => {
  const missing = envelope();
  missing.query = {
    version: 'axio.market-query.v2',
    intent: 'forecast',
    setup_type: 'model_forecast',
    symbols: ['NVDA'],
    horizon_minutes: null,
    horizons_minutes: [5, 15, 30, 60],
    limit: 1,
    filters: {},
  };
  delete missing.readiness;
  await rejectsContract(seal(missing));

  const legacyRule = envelope();
  delete legacyRule.readiness;
  const verified = await verifyQuantResearchResponseText(seal(legacyRule));
  assert.equal(verified.query.version, 'axio.market-query.v1');
});

test('rejects transport tampering before trusting envelope fields', async () => {
  const text = seal(envelope()).replace('"NVDA"', '"AAPL"');
  await rejectsContract(text);
});

test('rejects sealed uncalibrated price or probability output', async () => {
  const pricePayload = envelope();
  pricePayload.candidates[0].metrics.expected_price = 200;
  await rejectsContract(seal(pricePayload));

  const probabilityPayload = envelope();
  probabilityPayload.candidates[0].metrics.probability_up_percent = 62;
  await rejectsContract(seal(probabilityPayload));
});

test('rejects status and blocker combinations that do not fail closed', async () => {
  const payload = envelope();
  payload.data_blockers = ['NVDA:STALE'];
  await rejectsContract(seal(payload));
});

test('accepts historical evidence when live freshness fails independently', async () => {
  const payload = envelope();
  payload.status = 'PARTIAL';
  payload.candidates = [];
  payload.historical = [historical()];
  payload.data_blockers = ['PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH'];
  payload.readiness = readiness('blocked');
  const verified = await verifyQuantResearchResponseText(seal(payload));
  assert.equal(verified.status, 'PARTIAL');
  assert.equal(verified.historical[0].completed_backtests, 118);
  assert.equal(
    verified.historical[0].edge_classification,
    'POSITIVE_AFTER_COST_DESCRIPTIVE'
  );
});

test('rejects historical evidence with impossible metrics or overstated edge classification', async () => {
  const payload = envelope();
  payload.status = 'PARTIAL';
  payload.candidates = [];
  payload.historical = [historical()];
  payload.data_blockers = ['PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH'];
  payload.readiness = readiness('blocked');

  payload.historical[0].assumed_round_trip_cost_bps = -1;
  await rejectsContract(seal(payload));

  payload.historical[0].assumed_round_trip_cost_bps = 3;
  payload.historical[0].max_drawdown = 0.01;
  await rejectsContract(seal(payload));

  payload.historical[0].max_drawdown = -0.041;
  payload.historical[0].mean_net_return = -0.0007;
  payload.historical[0].median_net_return = -0.0005;
  payload.historical[0].cumulative_net_return = -0.082;
  await rejectsContract(seal(payload));

  payload.historical[0].edge_classification = 'NO_DEMONSTRATED_EDGE';
  payload.historical[0].edge_classification_detail =
    'This exploratory rule lost money after the stated costs and does not demonstrate an edge.';
  const verified = await verifyQuantResearchResponseText(seal(payload));
  assert.equal(verified.historical[0].edge_classification, 'NO_DEMONSTRATED_EDGE');
});

test('rejects inconsistent historical session, label, or VWAP integrity status', async () => {
  const base = envelope();
  base.status = 'PARTIAL';
  base.candidates = [];
  base.historical = [historical()];
  base.data_blockers = ['PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH'];
  base.readiness = readiness('blocked');

  const badSession = structuredClone(base);
  badSession.historical[0].session_integrity.complete_sessions = 389;
  await rejectsContract(seal(badSession));

  const badLabel = structuredClone(base);
  badLabel.historical[0].label_integrity.event_exclusion_counts[
    'EVENT_TOO_LATE_FOR_EXACT_CLOCK_HORIZON'
  ] = 2;
  await rejectsContract(seal(badLabel));

  const badVwap = structuredClone(base);
  badVwap.historical[0].vwap_status.sessions_using_authorized_vendor_vwap = 1;
  badVwap.historical[0].vwap_status.sessions_using_reconstructed_proxy = 389;
  await rejectsContract(seal(badVwap));
});

test('rejects a sealed model candidate without the licensed realtime entitlement', async () => {
  const payload = envelope();
  payload.candidates[0].freshness[0].entitlement = 'UNLICENSED';
  await rejectsContract(seal(payload));
});

test('validates all five pipeline readiness stages and publication consistency', async () => {
  const valid = envelope();
  const verified = await verifyQuantResearchResponseText(seal(valid));
  assert.equal(verified.readiness.publication.state, 'ready');

  const unknownState = envelope();
  unknownState.readiness.context.state = 'mystery';
  await rejectsContract(seal(unknownState));

  const invalidTimestamp = envelope();
  invalidTimestamp.readiness.inference.observed_at = 'not-a-timestamp';
  await rejectsContract(seal(invalidTimestamp));

  const noCandidate = envelope();
  noCandidate.status = 'DATA_UNAVAILABLE';
  noCandidate.candidates = [];
  noCandidate.data_blockers = ['LIVE_FORECAST_NOT_PUBLISHED'];
  await rejectsContract(seal(noCandidate));
});
