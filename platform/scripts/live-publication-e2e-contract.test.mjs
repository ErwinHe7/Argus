import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const fixture = JSON.parse(
  read('quant_engine_rs/tests/fixtures/live_publication_e2e_contract.json')
);

const compiledResearchClient = ts
  .transpileModule(read('lib/quant/research-client.ts'), {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
  })
  .outputText.replace(/import ['"]server-only['"];\s*/, '');
const { verifyQuantResearchResponseText } = await import(
  `data:text/javascript;base64,${Buffer.from(compiledResearchClient).toString('base64')}`
);

const compiledResearchAnswer = ts.transpileModule(
  read('lib/quant/research-answer.ts'),
  {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
  }
).outputText;
const { formatQuantResearchAnswer } = await import(
  `data:text/javascript;base64,${Buffer.from(compiledResearchAnswer).toString('base64')}`
);

function candidate(horizon) {
  return {
    symbol: fixture.public_symbol,
    setup_type: 'model_forecast',
    status: 'UNCALIBRATED_RESEARCH_OUTPUT',
    heuristic_structure_score: null,
    score_semantics:
      'Fresh frozen-model direction condition; probability and rank remain withheld.',
    supporting_evidence: [
      {
        code: 'FINALIZED_MARKET_BARS',
        statement:
          'The exact completed one-minute target and context bars were finalized.',
        observed_value: fixture.finalized_market_bars.length,
      },
      {
        code: 'CAUSAL_CONTEXT_ELIGIBLE',
        statement:
          'Every required context symbol passed the exact-cutoff causal eligibility gate.',
        observed_value: fixture.required_context_symbols,
      },
      {
        code: 'IMMUTABLE_MULTI_HORIZON_PUBLICATION',
        statement:
          'This horizon belongs to one fully committed immutable multi-horizon generation.',
        observed_value: horizon,
      },
    ],
    contrary_evidence: [
      {
        code: 'PROBABILITY_AND_EXPECTED_MOVE_WITHHELD',
        statement:
          'No matching promoted out-of-sample calibration exists; probability, expected move, rank, and execution remain withheld.',
        observed_value:
          'WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION',
      },
    ],
    metrics: {
      horizon_minutes: horizon,
      statistical_orientation:
        fixture.expected_orientations[String(horizon)],
      observation_cutoff: fixture.observation_cutoff,
      latest_input_available_at: fixture.latest_input_available_at,
      data_age_seconds: 2,
      data_source: 'DATABENTO:EQUS.MINI',
      coverage: 1,
      coverage_semantics:
        'ALL_REQUIRED_TARGET_AND_CONTEXT_SYMBOLS_PRESENT_AT_THE_DECISION_CUTOFF',
      caveats: [
        'The direction state is uncalibrated and is not a probability.',
        'Automatic execution is disabled.',
      ],
      published_probability_status:
        'WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION',
      validation: {
        model_version: fixture.lineage.model_version,
        feature_version: fixture.lineage.feature_version,
        model_hash: fixture.lineage.model_hash,
        feature_hash: fixture.lineage.feature_hash,
        data_manifest_hash: fixture.lineage.data_manifest_hash,
        schema_version: 'databento_inference_receipt.v3',
        source_envelopes_sha256:
          fixture.lineage.expected_source_envelopes_sha256,
        forecast_sha256: fixture.lineage.expected_forecast_sha256,
        published_at: fixture.published_at,
        end_to_end_ms: 1000,
        budget_ms: 5000,
      },
      interpretation: 'MODEL_DIRECTION_CONDITION_ONLY_NOT_A_TRADE',
    },
    freshness: [
      {
        source: 'DATABENTO:EQUS.MINI',
        observed_at: fixture.observation_cutoff,
        available_at: fixture.latest_input_available_at,
        age_seconds: 2,
        realtime: true,
        entitlement: 'LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED',
        coverage: 1,
      },
    ],
  };
}

function readinessStage(code) {
  return {
    state: 'ready',
    code,
    detail: `${code} verified by the deterministic contract fixture`,
    observed_at: fixture.published_at,
  };
}

function envelope() {
  return {
    schema_version: 'axio.evidence-envelope.v1',
    request_id: fixture.request_id,
    query_sha256: fixture.query_sha256,
    response_sha256: null,
    generated_at: fixture.generated_at,
    observation_cutoff: fixture.observation_cutoff,
    status: 'UNCALIBRATED_RESEARCH_OUTPUT',
    query: structuredClone(fixture.query),
    candidates: fixture.configured_horizons.map(candidate),
    exclusions: [],
    historical: [],
    data_blockers: [],
    readiness: {
      model: readinessStage('FROZEN_MODEL_ARTIFACT_VERIFIED'),
      feed: readinessStage('FINALIZED_REALTIME_BARS_VERIFIED'),
      context: readinessStage('CAUSAL_CONTEXT_VERIFIED'),
      inference: readinessStage('ALL_HORIZONS_INFERRED'),
      publication: readinessStage(
        'IMMUTABLE_MULTI_HORIZON_GENERATION_COMMITTED'
      ),
    },
    model_contract: {
      runtime_owner: 'RUST',
      forecast_horizons_minutes: fixture.configured_horizons,
      model_version: fixture.lineage.model_version,
      feature_schema_version: fixture.lineage.feature_version,
      probability_policy:
        'CALIBRATED_PROBABILITIES_REQUIRE_A_MATCHING_PROMOTED_OOS_ARTIFACT',
    },
    research_only_policy: {
      product_scope: 'IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH',
      personalization_used: false,
      investment_advice: false,
      execution_instruction: false,
      automatic_order_execution: false,
    },
    caveats: [
      'No candidate is an order, personalized recommendation, or guaranteed outcome.',
      'UNCALIBRATED_RESEARCH_OUTPUT exposes a direction condition only; probability, expected move, rank, and execution remain withheld.',
      'A neutral ticker query publishes every configured horizon atomically; automatic execution is disabled.',
    ],
  };
}

function seal(payload) {
  const unsealed = JSON.stringify(payload);
  const hash = createHash('sha256').update(unsealed).digest('hex');
  return JSON.stringify({ ...payload, response_sha256: hash });
}

function jsonPointer(value, pointer) {
  return pointer
    .split('/')
    .slice(1)
    .reduce(
      (current, segment) =>
        current?.[segment.replaceAll('~1', '/').replaceAll('~0', '~')],
      value
    );
}

test('shared Rust fixture survives the website verifier with every neutral-query horizon', async () => {
  const verified = await verifyQuantResearchResponseText(seal(envelope()));
  assert.equal(verified.query.setup_type, 'model_forecast');
  assert.equal(Object.hasOwn(verified.query, 'horizon_minutes'), false);
  assert.equal(Object.hasOwn(verified.query.filters, 'direction'), false);
  assert.deepEqual(
    verified.candidates.map((row) => row.metrics.horizon_minutes),
    fixture.configured_horizons
  );
  assert.equal(
    new Set(verified.candidates.map((row) => row.metrics.horizon_minutes)).size,
    fixture.configured_horizons.length
  );
  assert.equal(verified.readiness.publication.state, 'ready');
  assert.equal(
    verified.research_only_policy.automatic_order_execution,
    false
  );

  for (const pointer of fixture.ui_required_json_pointers) {
    assert.notEqual(
      jsonPointer(verified, pointer),
      undefined,
      `website-required field ${pointer} is absent`
    );
    assert.notEqual(
      jsonPointer(verified, pointer),
      null,
      `website-required field ${pointer} is null`
    );
  }
});

test('customer-facing answer renders all horizons and the Rust provenance without inventing probability', async () => {
  const verified = await verifyQuantResearchResponseText(seal(envelope()));
  const answer = formatQuantResearchAnswer('SPX', verified, []);
  for (const horizon of fixture.configured_horizons) {
    assert.match(answer, new RegExp(`${horizon}-minute horizon`));
  }
  assert.match(answer, /DATABENTO:EQUS\.MINI/);
  assert.ok(answer.includes(fixture.lineage.model_version));
  assert.ok(answer.includes(fixture.lineage.feature_version));
  assert.match(answer, /LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED/);
  assert.match(answer, /automatic execution is disabled/i);
  assert.doesNotMatch(answer, /\d+(?:\.\d+)?% P\(up\)/);
  assert.doesNotMatch(answer, /\bBUY\b|\bSELL\b|target price|position size/i);
});

test('the visible React surface is wired to interpreted-query, readiness, horizon, and lineage fields', () => {
  const chat = read('components/AxioChat.tsx');
  for (const token of [
    'function InterpretedQuery',
    'All configured horizons',
    'No setup, direction, or horizon inferred from a ticker',
    'function RecoveryActions',
    'Retry live',
    'View readiness',
    'candidate.metrics.horizon_minutes',
    'freshness?.source',
    'freshness?.observed_at',
    'freshness?.available_at',
    'freshness?.age_seconds',
    'freshness?.coverage',
    'freshness?.entitlement',
    'validation.model_version',
    'validation.feature_version',
    'validation.model_hash',
    'validation.feature_hash',
    'validation.data_manifest_hash',
    'explicitReadiness.publication?.state',
  ]) {
    assert.ok(chat.includes(token), `visible UI is not wired to ${token}`);
  }
});
