import 'server-only';

import type {
  MarketQueryV1,
  QuantDailyRegimeReport,
  QuantEvidenceEnvelope,
  QuantPipelineReadiness,
  QuantSessionFiveMinuteBar,
  QuantSessionSummary,
} from '@/lib/forecast-chat-types';

function backendUrl() {
  const configured = process.env.INTRADAY_QUANT_API_URL?.trim();
  if (configured) return configured.replace(/\/$/, '');
  if (process.env.NODE_ENV !== 'production') return 'http://127.0.0.1:8001';
  return null;
}

export class QuantBackendUnavailableError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'QuantBackendUnavailableError';
    this.code = code;
  }
}

export type QuantBackendStatus = {
  connected: boolean;
  code: string;
  runtime: 'rust';
  universeStatus?: string;
  execution?: string;
  modelStatus?: 'LOADED' | 'PARTIAL' | 'UNAVAILABLE';
  requestedModelCount?: number;
  loadedModelCount?: number;
  failedModelCount?: number;
  marketData?: DatabentoMarketDataStatus;
  readiness?: QuantPipelineReadiness;
  /**
   * The universe probe cannot prove target context, inference, or publication.
   * This remains false until a target-specific research receipt says otherwise.
   */
  liveForecastReady?: false;
};

export type FactorShadowStatus = {
  schema_version: 'axio.factor-shadow-status.v1';
  candidate: {
    candidate_id: 'axio.pv-multifactor-40-20-40';
    candidate_version: 'v1';
    owner: 'quant_engine_rs';
    scope: 'IMPERSONAL_CROSS_SECTIONAL_MARKET_RESEARCH_SHADOW';
    status: 'CANDIDATE_NOT_PROMOTED';
  };
  fixed_weights_percent: {
    momentum: 40;
    liquidity_proxy: 20;
    regime_and_other_price_volume: 40;
  };
  blockers: [
    'POINT_IN_TIME_UNIVERSE_NOT_VALIDATED',
    'LIQUIDITY_PROXY_NOT_VALIDATED',
    'PURGED_WALK_FORWARD_AND_FORWARD_SHADOW_INCOMPLETE',
  ];
  execution: 'DISABLED';
};

export type DatabentoMarketDataStatus = {
  configured: boolean;
  ok: boolean;
  provider: 'databento';
  state: string;
  authenticated: boolean;
  entitlementVerified: boolean;
  replayRequested: boolean;
  executionEnabled: false;
  dataset: string | null;
  schema: string | null;
  checkedAt: string;
  updatedAt: string | null;
  subscribedSymbols: string[];
  rightsReason?: string;
  reason?: string;
};

async function fetchQuantJson(path: string, timeoutMs = 5_000): Promise<unknown> {
  const backend = backendUrl();
  if (!backend) {
    throw new QuantBackendUnavailableError(
      'RUST_BACKEND_URL_NOT_CONFIGURED',
      'The Rust inference service URL is not configured for this deployment.'
    );
  }
  const token = process.env.INTRADAY_QUANT_TOKEN;
  if (!token || token.length < 32) {
    throw new QuantBackendUnavailableError(
      'RUST_BACKEND_TOKEN_NOT_CONFIGURED',
      'The server-side research token is missing or too short.'
    );
  }
  const response = await fetch(`${backend}${path}`, {
    headers: {
      Accept: 'application/json',
      'X-Research-Token': token,
    },
    cache: 'no-store',
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) {
    throw new QuantBackendUnavailableError(
      `RUST_BACKEND_HTTP_${response.status}`,
      `The Rust inference service rejected ${path}.`
    );
  }
  return response.json();
}

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function hasExactKeys(
  value: Record<string, unknown>,
  expected: readonly string[]
): boolean {
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return (
    actual.length === sortedExpected.length &&
    actual.every((key, index) => key === sortedExpected[index])
  );
}

function validateFactorShadowStatus(value: unknown): FactorShadowStatus {
  const payload = record(value);
  const candidate = record(payload?.candidate);
  const weights = record(payload?.fixed_weights_percent);
  const blockers = payload?.blockers;
  const expectedBlockers: FactorShadowStatus['blockers'] = [
    'POINT_IN_TIME_UNIVERSE_NOT_VALIDATED',
    'LIQUIDITY_PROXY_NOT_VALIDATED',
    'PURGED_WALK_FORWARD_AND_FORWARD_SHADOW_INCOMPLETE',
  ];
  const valid =
    payload !== null &&
    candidate !== null &&
    weights !== null &&
    hasExactKeys(payload, [
      'schema_version',
      'candidate',
      'fixed_weights_percent',
      'blockers',
      'execution',
    ]) &&
    hasExactKeys(candidate, [
      'candidate_id',
      'candidate_version',
      'owner',
      'scope',
      'status',
    ]) &&
    hasExactKeys(weights, [
      'momentum',
      'liquidity_proxy',
      'regime_and_other_price_volume',
    ]) &&
    payload.schema_version === 'axio.factor-shadow-status.v1' &&
    candidate.candidate_id === 'axio.pv-multifactor-40-20-40' &&
    candidate.candidate_version === 'v1' &&
    candidate.owner === 'quant_engine_rs' &&
    candidate.scope === 'IMPERSONAL_CROSS_SECTIONAL_MARKET_RESEARCH_SHADOW' &&
    candidate.status === 'CANDIDATE_NOT_PROMOTED' &&
    weights.momentum === 40 &&
    weights.liquidity_proxy === 20 &&
    weights.regime_and_other_price_volume === 40 &&
    Array.isArray(blockers) &&
    blockers.length === expectedBlockers.length &&
    blockers.every((blocker, index) => blocker === expectedBlockers[index]) &&
    payload.execution === 'DISABLED';
  if (!valid) {
    throw new QuantBackendUnavailableError(
      'RUST_FACTOR_SHADOW_CONTRACT_MISMATCH',
      'The Rust factor-shadow service returned an incompatible metadata-only contract.'
    );
  }
  return value as FactorShadowStatus;
}

const EVIDENCE_ENVELOPE_STATUSES = new Set([
  'AVAILABLE',
  'PARTIAL',
  'DATA_UNAVAILABLE',
  'UNCALIBRATED_RESEARCH_OUTPUT',
]);
const SHA256_HEX = /^[0-9a-f]{64}$/;
const UNCALIBRATED_FORBIDDEN_KEY =
  /(?:^|_)(?:p_(?:up|down|flat)|probability|frequency|raw_frequency|expected_(?:move|return|price|edge)|forecast_price|target_price|rank|rank_score|research_rank_score|heuristic_structure_score|trade|action|side|qty|quantity|order|position_size|target_weight|target_notional|stop_loss|legs)(?:$|_)/i;

function contractMismatch(detail: string): QuantBackendUnavailableError {
  return new QuantBackendUnavailableError(
    'RUST_BACKEND_CONTRACT_MISMATCH',
    `The Rust inference service returned an incompatible evidence contract: ${detail}`
  );
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isTimestamp(value: unknown): value is string {
  return (
    isNonEmptyString(value) &&
    Number.isFinite(Date.parse(value)) &&
    value.includes('T')
  );
}

function isOptionalFiniteNumber(value: unknown): boolean {
  return value === null || (typeof value === 'number' && Number.isFinite(value));
}

function isNonnegativeSafeInteger(value: unknown): value is number {
  return Number.isSafeInteger(value) && (value as number) >= 0;
}

function countMap(value: unknown): Record<string, number> | null {
  const candidate = record(value);
  if (
    !candidate ||
    Object.entries(candidate).some(
      ([reason, count]) =>
        reason.trim().length === 0 ||
        !Number.isSafeInteger(count) ||
        (count as number) <= 0
    )
  ) {
    return null;
  }
  return candidate as Record<string, number>;
}

function countMapTotal(value: Record<string, number>): number | null {
  let total = 0;
  for (const count of Object.values(value)) {
    total += count;
    if (!Number.isSafeInteger(total)) return null;
  }
  return total;
}

const INSUFFICIENT_EDGE_DETAIL =
  'Insufficient complete after-cost return metrics; no edge conclusion is supported.';
const LOSING_EDGE_DETAIL =
  'This exploratory rule lost money after the stated costs and does not demonstrate an edge.';
const NON_POSITIVE_EDGE_DETAIL =
  'At least one after-cost mean, median, or cumulative return is non-positive; this exploratory rule does not demonstrate an edge.';
const POSITIVE_DESCRIPTIVE_EDGE_DETAIL =
  'Mean, median, and cumulative returns are positive after stated costs in this exploratory sample; this descriptive result does not establish a statistically validated edge.';

function expectedHistoricalEdge(
  historical: Record<string, unknown>
): { classification: string; detail: string } | null {
  if (
    !Number.isSafeInteger(historical.completed_backtests) ||
    (historical.completed_backtests as number) < 0 ||
    !isOptionalFiniteNumber(historical.mean_net_return) ||
    !isOptionalFiniteNumber(historical.median_net_return) ||
    !isOptionalFiniteNumber(historical.cumulative_net_return)
  ) {
    return null;
  }
  const mean = historical.mean_net_return;
  const median = historical.median_net_return;
  const cumulative = historical.cumulative_net_return;
  if (
    historical.completed_backtests === 0 ||
    typeof mean !== 'number' ||
    typeof median !== 'number' ||
    typeof cumulative !== 'number'
  ) {
    return {
      classification: 'INSUFFICIENT_EVIDENCE',
      detail: INSUFFICIENT_EDGE_DETAIL,
    };
  }
  if (mean > 0 && median > 0 && cumulative > 0) {
    return {
      classification: 'POSITIVE_AFTER_COST_DESCRIPTIVE',
      detail: POSITIVE_DESCRIPTIVE_EDGE_DETAIL,
    };
  }
  return {
    classification: 'NO_DEMONSTRATED_EDGE',
    detail: cumulative < 0 ? LOSING_EDGE_DETAIL : NON_POSITIVE_EDGE_DETAIL,
  };
}

function hasValidHistoricalIntegrity(
  historical: Record<string, unknown>
): boolean {
  const session = record(historical.session_integrity);
  const label = record(historical.label_integrity);
  const vwap = record(historical.vwap_status);
  const sessionExclusions = countMap(session?.session_exclusion_counts);
  const eventExclusions = countMap(label?.event_exclusion_counts);
  if (
    !session ||
    !label ||
    !vwap ||
    !sessionExclusions ||
    !eventExclusions ||
    !isNonnegativeSafeInteger(session.target_rows) ||
    !isNonnegativeSafeInteger(session.unique_regular_session_rows) ||
    !isNonnegativeSafeInteger(session.exact_duplicate_rows) ||
    session.conflicting_duplicate_rows !== 0 ||
    !isNonnegativeSafeInteger(session.observed_sessions) ||
    !isNonnegativeSafeInteger(session.complete_sessions) ||
    !isNonnegativeSafeInteger(session.excluded_sessions) ||
    !Number.isSafeInteger(
      session.unique_regular_session_rows + session.exact_duplicate_rows
    ) ||
    session.target_rows !==
      session.unique_regular_session_rows + session.exact_duplicate_rows ||
    !Number.isSafeInteger(
      session.complete_sessions + session.excluded_sessions
    ) ||
    session.observed_sessions !==
      session.complete_sessions + session.excluded_sessions ||
    session.complete_sessions !== historical.sessions ||
    countMapTotal(sessionExclusions) !== session.excluded_sessions ||
    !isNonnegativeSafeInteger(label.detected_events) ||
    !isNonnegativeSafeInteger(label.completed_labels) ||
    !isNonnegativeSafeInteger(label.excluded_events) ||
    label.detected_events !== historical.event_sessions ||
    label.completed_labels !== historical.completed_backtests ||
    label.excluded_events !== label.detected_events - label.completed_labels ||
    countMapTotal(eventExclusions) !== label.excluded_events ||
    vwap.policy !==
      'SESSION_ATOMIC_AUTHORIZED_VENDOR_MINUTE_VWAP_OR_RECONSTRUCTED_CLOSE_VOLUME_PROXY' ||
    !isNonnegativeSafeInteger(vwap.eligible_minute_rows) ||
    !Number.isSafeInteger((historical.sessions as number) * 390) ||
    vwap.eligible_minute_rows !== (historical.sessions as number) * 390 ||
    !isNonnegativeSafeInteger(vwap.authorized_vendor_vwap_rows) ||
    vwap.authorized_vendor_vwap_rows > vwap.eligible_minute_rows ||
    !isNonnegativeSafeInteger(
      vwap.reported_but_unauthorized_vendor_vwap_rows
    ) ||
    vwap.reported_but_unauthorized_vendor_vwap_rows >
      vwap.eligible_minute_rows ||
    !Number.isSafeInteger(
      vwap.authorized_vendor_vwap_rows +
        vwap.reported_but_unauthorized_vendor_vwap_rows
    ) ||
    vwap.authorized_vendor_vwap_rows +
      vwap.reported_but_unauthorized_vendor_vwap_rows >
      vwap.eligible_minute_rows ||
    !isNonnegativeSafeInteger(
      vwap.sessions_using_authorized_vendor_vwap
    ) ||
    !isNonnegativeSafeInteger(vwap.sessions_using_reconstructed_proxy) ||
    !Number.isSafeInteger(
      vwap.sessions_using_authorized_vendor_vwap +
        vwap.sessions_using_reconstructed_proxy
    ) ||
    vwap.sessions_using_authorized_vendor_vwap +
      vwap.sessions_using_reconstructed_proxy !==
      historical.sessions ||
    vwap.authorized_vendor_vwap_rows <
      vwap.sessions_using_authorized_vendor_vwap * 390 ||
    !Number.isSafeInteger(
      vwap.sessions_using_authorized_vendor_vwap * 390
    ) ||
    typeof vwap.authorized_vendor_minute_coverage !== 'number' ||
    !Number.isFinite(vwap.authorized_vendor_minute_coverage) ||
    vwap.authorized_vendor_minute_coverage < 0 ||
    vwap.authorized_vendor_minute_coverage > 1 ||
    !isNonnegativeSafeInteger(vwap.parity_observations) ||
    !Number.isSafeInteger(
      vwap.sessions_using_authorized_vendor_vwap * 78
    ) ||
    vwap.parity_observations !==
      vwap.sessions_using_authorized_vendor_vwap * 78 ||
    !isOptionalFiniteNumber(vwap.median_absolute_parity_bps) ||
    !isOptionalFiniteNumber(vwap.maximum_absolute_parity_bps)
  ) {
    return false;
  }
  const expectedCoverage =
    vwap.eligible_minute_rows === 0
      ? 0
      : vwap.authorized_vendor_vwap_rows / vwap.eligible_minute_rows;
  if (
    Math.abs(vwap.authorized_vendor_minute_coverage - expectedCoverage) >
    1e-12
  ) {
    return false;
  }
  const medianParity = vwap.median_absolute_parity_bps;
  const maximumParity = vwap.maximum_absolute_parity_bps;
  return vwap.parity_observations === 0
    ? medianParity === null && maximumParity === null
    : typeof medianParity === 'number' &&
        typeof maximumParity === 'number' &&
        medianParity >= 0 &&
        maximumParity >= medianParity;
}

function hasNonNullForbiddenField(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(hasNonNullForbiddenField);
  const object = record(value);
  if (!object) return false;
  return Object.entries(object).some(
    ([key, child]) =>
      (child !== null &&
        key !== 'published_probability_status' &&
        child !== undefined &&
        UNCALIBRATED_FORBIDDEN_KEY.test(key)) ||
      hasNonNullForbiddenField(child)
  );
}

function verifyFreshnessEvidence(
  candidate: Record<string, unknown>,
  generatedAt: string
): void {
  const rows = candidate.freshness;
  if (!Array.isArray(rows) || rows.length === 0) {
    throw contractMismatch('candidate freshness evidence is absent');
  }
  const generatedMs = Date.parse(generatedAt);
  for (const value of rows) {
    const freshness = record(value);
    if (!freshness) {
      throw contractMismatch('candidate freshness evidence is malformed');
    }
    const observedAt = freshness.observed_at;
    const availableAt = freshness.available_at;
    const ageSeconds = freshness.age_seconds;
    const coverage = freshness.coverage;
    if (
      !isNonEmptyString(freshness.source) ||
      !isTimestamp(observedAt) ||
      !isTimestamp(availableAt) ||
      Date.parse(observedAt) > Date.parse(availableAt) ||
      Date.parse(availableAt) > generatedMs ||
      typeof ageSeconds !== 'number' ||
      !Number.isSafeInteger(ageSeconds) ||
      ageSeconds < 0 ||
      typeof freshness.realtime !== 'boolean' ||
      !isNonEmptyString(freshness.entitlement) ||
      typeof coverage !== 'number' ||
      !Number.isFinite(coverage) ||
      coverage < 0 ||
      coverage > 1
    ) {
      throw contractMismatch(
        'candidate source, clocks, freshness, coverage, or entitlement evidence is incomplete'
      );
    }
  }

  const primary = record(rows[0]);
  const metrics = record(candidate.metrics);
  if (!primary || !metrics) {
    throw contractMismatch('candidate metrics evidence is malformed');
  }
  if (
    (isNonEmptyString(metrics.data_source) &&
      metrics.data_source !== primary.source) ||
    (isTimestamp(metrics.observation_cutoff) &&
      metrics.observation_cutoff !== primary.observed_at) ||
    (isTimestamp(metrics.latest_input_available_at) &&
      metrics.latest_input_available_at !== primary.available_at) ||
    (typeof metrics.coverage === 'number' &&
      metrics.coverage !== primary.coverage)
  ) {
    throw contractMismatch(
      'candidate metrics and primary freshness evidence disagree'
    );
  }
}

function verifyModelLineage(candidate: Record<string, unknown>): void {
  if (
    candidate.status !== 'UNCALIBRATED_RESEARCH_OUTPUT' &&
    candidate.status !== 'VALIDATED_STATISTICAL_CANDIDATE'
  ) {
    return;
  }
  const freshness = candidate.freshness;
  if (
    !Array.isArray(freshness) ||
    !freshness.every((value) => {
      const evidence = record(value);
      return (
        evidence?.realtime === true &&
        evidence.entitlement === 'LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED'
      );
    })
  ) {
    throw contractMismatch('model candidate realtime entitlement is not verified');
  }
  const validation = record(record(candidate.metrics)?.validation);
  if (
    !validation ||
    !isNonEmptyString(validation.model_version) ||
    !isNonEmptyString(validation.feature_version) ||
    !isNonEmptyString(validation.model_hash) ||
    !SHA256_HEX.test(validation.model_hash) ||
    !isNonEmptyString(validation.feature_hash) ||
    !SHA256_HEX.test(validation.feature_hash) ||
    !isNonEmptyString(validation.data_manifest_hash) ||
    !SHA256_HEX.test(validation.data_manifest_hash)
  ) {
    throw contractMismatch(
      'candidate model, feature, or data-manifest lineage is incomplete'
    );
  }
  const usesDatabento = freshness.some(
    (value) => record(value)?.source === 'DATABENTO:EQUS.MINI'
  );
  if (
    usesDatabento &&
    (validation.schema_version !== 'databento_inference_receipt.v3' ||
      !isNonEmptyString(validation.source_envelopes_sha256) ||
      !SHA256_HEX.test(validation.source_envelopes_sha256) ||
      !isNonEmptyString(validation.forecast_sha256) ||
      !SHA256_HEX.test(validation.forecast_sha256) ||
      !isTimestamp(validation.published_at) ||
      !Number.isSafeInteger(validation.end_to_end_ms) ||
      (validation.end_to_end_ms as number) < 0 ||
      !Number.isSafeInteger(validation.budget_ms) ||
      (validation.budget_ms as number) <= 0 ||
      (validation.end_to_end_ms as number) > (validation.budget_ms as number))
  ) {
    throw contractMismatch(
      'Databento source receipt hash or publication SLA lineage is incomplete'
    );
  }
}

const PIPELINE_READINESS_STATES = new Set([
  'ready',
  'waiting',
  'blocked',
  'not_checked',
]);
const PIPELINE_READINESS_STAGES = [
  'model',
  'feed',
  'context',
  'inference',
  'publication',
] as const;

function verifyPipelineReadiness(
  envelope: Record<string, unknown>,
  candidateCount: number
) {
  if (envelope.readiness === undefined) {
    const query = record(envelope.query);
    if (
      query?.version === 'axio.market-query.v2' &&
      query.setup_type === 'model_forecast'
    ) {
      throw contractMismatch(
        'query-v2 model forecast is missing explicit pipeline readiness'
      );
    }
    // Compatibility is limited to legacy explicit-rule envelopes. A v2 model
    // forecast may never bypass the publication-stage contract above.
    return;
  }
  const readiness = record(envelope.readiness);
  if (
    !readiness ||
    Object.keys(readiness).some(
      (key) =>
        !PIPELINE_READINESS_STAGES.includes(
          key as (typeof PIPELINE_READINESS_STAGES)[number]
        )
    )
  ) {
    throw contractMismatch('pipeline readiness object is malformed');
  }
  for (const stageName of PIPELINE_READINESS_STAGES) {
    const stage = record(readiness[stageName]);
    if (
      !stage ||
      typeof stage.state !== 'string' ||
      !PIPELINE_READINESS_STATES.has(stage.state) ||
      (stage.code !== undefined &&
        stage.code !== null &&
        !isNonEmptyString(stage.code)) ||
      (stage.detail !== undefined &&
        stage.detail !== null &&
        !isNonEmptyString(stage.detail)) ||
      (stage.observed_at !== undefined &&
        stage.observed_at !== null &&
        !isTimestamp(stage.observed_at))
    ) {
      throw contractMismatch(`pipeline readiness stage ${stageName} is invalid`);
    }
  }
  const publication = record(readiness.publication);
  if (publication?.state === 'ready' && candidateCount === 0) {
    throw contractMismatch('publication is ready without a visible candidate');
  }
  const query = record(envelope.query);
  if (
    query?.setup_type === 'model_forecast' &&
    candidateCount > 0 &&
    publication?.state !== 'ready'
  ) {
    throw contractMismatch(
      'model forecast candidate lacks a committed publication stage'
    );
  }
}

function verifyEnvelopeSemantics(payload: unknown): QuantEvidenceEnvelope {
  const envelope = record(payload);
  if (
    !envelope ||
    envelope.schema_version !== 'axio.evidence-envelope.v1' ||
    !isNonEmptyString(envelope.request_id) ||
    !isNonEmptyString(envelope.query_sha256) ||
    !SHA256_HEX.test(envelope.query_sha256) ||
    !isTimestamp(envelope.generated_at) ||
    !isTimestamp(envelope.observation_cutoff) ||
    !isNonEmptyString(envelope.status) ||
    !record(envelope.query) ||
    !EVIDENCE_ENVELOPE_STATUSES.has(envelope.status) ||
    !Array.isArray(envelope.candidates) ||
    !Array.isArray(envelope.historical) ||
    !Array.isArray(envelope.data_blockers) ||
    !Array.isArray(envelope.caveats) ||
    envelope.caveats.length === 0 ||
    !envelope.caveats.every(isNonEmptyString)
  ) {
    throw contractMismatch('required public evidence fields are absent');
  }
  verifyPipelineReadiness(envelope, envelope.candidates.length);

  const blockers = envelope.data_blockers;
  if (!blockers.every(isNonEmptyString)) {
    throw contractMismatch('data blockers are malformed');
  }
  if (blockers.length > 0) {
    const validLiveFailure =
      envelope.status === 'DATA_UNAVAILABLE' &&
      envelope.candidates.length === 0 &&
      envelope.historical.length === 0;
    const validHistoricalOnlyPartial =
      envelope.status === 'PARTIAL' &&
      envelope.candidates.length === 0 &&
      envelope.historical.length > 0;
    if (!validLiveFailure && !validHistoricalOnlyPartial) {
      throw contractMismatch('data blockers did not fail closed');
    }
  }
  if (
    envelope.status === 'DATA_UNAVAILABLE' &&
    (envelope.candidates.length > 0 || envelope.historical.length > 0)
  ) {
    throw contractMismatch('DATA_UNAVAILABLE contains research results');
  }

  for (const value of envelope.candidates) {
    const candidate = record(value);
    if (
      !candidate ||
      !isNonEmptyString(candidate.symbol) ||
      !isNonEmptyString(candidate.status) ||
      !record(candidate.metrics) ||
      !Array.isArray(candidate.supporting_evidence) ||
      !Array.isArray(candidate.contrary_evidence)
    ) {
      throw contractMismatch('candidate evidence is malformed');
    }
    verifyFreshnessEvidence(candidate, envelope.generated_at);
    verifyModelLineage(candidate);
    if (
      !candidate.supporting_evidence.every((item) =>
        isNonEmptyString(record(item)?.statement)
      ) ||
      !candidate.contrary_evidence.every((item) =>
        isNonEmptyString(record(item)?.statement)
      )
    ) {
      throw contractMismatch('candidate evidence statements are malformed');
    }
    if (
      candidate.status === 'UNCALIBRATED_RESEARCH_OUTPUT' &&
      hasNonNullForbiddenField(candidate)
    ) {
      throw contractMismatch(
        'uncalibrated candidate contains probability, frequency, expected-value, price, rank, or trade output'
      );
    }
  }

  for (const value of envelope.historical) {
    const historical = record(value);
    const expectedEdge = historical
      ? expectedHistoricalEdge(historical)
      : null;
    if (
      !historical ||
      !isNonEmptyString(historical.symbol) ||
      !isNonEmptyString(historical.method_version) ||
      !isNonEmptyString(historical.event_definition) ||
      !isNonEmptyString(historical.source) ||
      !isNonEmptyString(historical.dataset_start) ||
      !isNonEmptyString(historical.dataset_end) ||
      !isNonEmptyString(historical.evidence_grade) ||
      !isNonEmptyString(historical.entry_semantics) ||
      historical.performance_scope !==
        'HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE' ||
      !Array.isArray(historical.caveats) ||
      historical.caveats.length === 0 ||
      !historical.caveats.every(isNonEmptyString) ||
      !Number.isSafeInteger(historical.sessions) ||
      (historical.sessions as number) < 0 ||
      !Number.isSafeInteger(historical.event_sessions) ||
      (historical.event_sessions as number) < 0 ||
      (historical.event_sessions as number) > (historical.sessions as number) ||
      !Number.isSafeInteger(historical.completed_backtests) ||
      (historical.completed_backtests as number) < 0 ||
      (historical.completed_backtests as number) >
        (historical.event_sessions as number) ||
      !hasValidHistoricalIntegrity(historical) ||
      typeof historical.assumed_round_trip_cost_bps !== 'number' ||
      !Number.isFinite(historical.assumed_round_trip_cost_bps) ||
      (historical.assumed_round_trip_cost_bps as number) < 0 ||
      !isOptionalFiniteNumber(historical.net_win_rate) ||
      (typeof historical.net_win_rate === 'number' &&
        (historical.net_win_rate < 0 || historical.net_win_rate > 1)) ||
      !isOptionalFiniteNumber(historical.mean_net_return) ||
      !isOptionalFiniteNumber(historical.median_net_return) ||
      !isOptionalFiniteNumber(historical.cumulative_net_return) ||
      (typeof historical.cumulative_net_return === 'number' &&
        historical.cumulative_net_return <= -1) ||
      !isOptionalFiniteNumber(historical.max_drawdown) ||
      (typeof historical.max_drawdown === 'number' &&
        (historical.max_drawdown < -1 || historical.max_drawdown > 0)) ||
      expectedEdge === null ||
      historical.edge_classification !== expectedEdge.classification ||
      historical.edge_classification_detail !== expectedEdge.detail ||
      !isNonEmptyString(historical.data_manifest_hash) ||
      !SHA256_HEX.test(historical.data_manifest_hash)
    ) {
      throw contractMismatch('historical evidence is incomplete');
    }
  }

  const hasCandidates = envelope.candidates.length > 0;
  const hasHistorical = envelope.historical.length > 0;
  const hasUncalibrated = envelope.candidates.some(
    (value) => record(value)?.status === 'UNCALIBRATED_RESEARCH_OUTPUT'
  );
  const expectedStatus =
    blockers.length > 0
      ? hasHistorical && !hasCandidates
        ? 'PARTIAL'
        : 'DATA_UNAVAILABLE'
      : hasUncalibrated
        ? 'UNCALIBRATED_RESEARCH_OUTPUT'
        : hasCandidates || hasHistorical
          ? 'AVAILABLE'
          : 'DATA_UNAVAILABLE';
  if (envelope.status !== expectedStatus) {
    throw contractMismatch(
      'status, data blockers, candidates, and historical evidence disagree'
    );
  }

  return payload as QuantEvidenceEnvelope;
}

export async function verifyQuantResearchResponseText(
  text: string
): Promise<QuantEvidenceEnvelope> {
  const hashField = /("response_sha256"\s*:\s*)"([0-9a-f]{64})"/g;
  const matches = [...text.matchAll(hashField)];
  if (
    matches.length !== 1 ||
    (text.match(/"response_sha256"\s*:/g) || []).length !== 1
  ) {
    throw contractMismatch('response SHA-256 seal is absent or ambiguous');
  }
  const declaredHash = matches[0][2];
  const matchIndex = matches[0].index;
  if (matchIndex === undefined) {
    throw contractMismatch('response SHA-256 seal position is unavailable');
  }
  const sealedText =
    text.slice(0, matchIndex) +
    `${matches[0][1]}null` +
    text.slice(matchIndex + matches[0][0].length);
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(sealedText)
  );
  const observedHash = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
  if (observedHash !== declaredHash) {
    throw contractMismatch('response SHA-256 seal does not match the raw payload');
  }

  let payload: unknown;
  try {
    payload = JSON.parse(text);
  } catch {
    throw contractMismatch('response is not valid JSON');
  }
  return verifyEnvelopeSemantics(payload);
}

export async function readIbkrQuoteRelayReceipt(): Promise<unknown> {
  return fetchQuantJson('/api/v1/live/ibkr/quotes');
}

export async function readMoomooOwnerForecastRelayReceipt(): Promise<unknown> {
  return fetchQuantJson('/api/v1/live/moomoo/forecasts');
}

export async function readFactorShadowStatus(): Promise<FactorShadowStatus> {
  return validateFactorShadowStatus(
    await fetchQuantJson('/api/v1/research/factor-shadow')
  );
}

const READY_MARKET_DATA_RIGHTS_REASONS = new Set([
  'VERIFIED',
  'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT',
]);

export async function probeDatabentoMarketData(): Promise<DatabentoMarketDataStatus> {
  const checkedAt = new Date().toISOString();
  try {
    const receipt = record(
      await fetchQuantJson('/api/v1/system/readiness')
    );
    const marketData = record(receipt?.market_data);
    const rights = record(marketData?.public_use_rights);
    const configured =
      receipt?.schema_version === 'axio.production_readiness.v2' &&
      marketData?.selected_provider === 'databento' &&
      marketData?.live_enabled === true;
    const rightsReady =
      rights?.status === 'READY' &&
      typeof rights.reason === 'string' &&
      READY_MARKET_DATA_RIGHTS_REASONS.has(rights.reason);
    const entitlementVerified =
      marketData?.provider_entitlement === 'READY';
    const streamFresh = marketData?.stream_freshness === 'FRESH';
    const feedFresh = marketData?.feed_freshness === 'FRESH';
    const ok =
      configured &&
      rightsReady &&
      entitlementVerified &&
      streamFresh &&
      feedFresh;
    const reasonParts = [
      configured ? null : 'DATABENTO_LIVE_PROVIDER_NOT_CONFIGURED',
      rightsReady
        ? null
        : `PUBLIC_USE_RIGHTS_${String(rights?.reason ?? 'UNAVAILABLE')}`,
      entitlementVerified ? null : 'PROVIDER_ENTITLEMENT_NOT_READY',
      streamFresh
        ? null
        : `STREAM_FRESHNESS_${String(
            marketData?.stream_freshness ?? 'UNAVAILABLE'
          )}`,
      feedFresh
        ? null
        : `ALL_SYMBOL_FEED_FRESHNESS_${String(
            marketData?.feed_freshness ?? 'UNAVAILABLE'
          )}`,
    ].filter((value): value is string => value !== null);
    const result: DatabentoMarketDataStatus = {
      configured,
      ok,
      provider: 'databento',
      state: ok ? 'AUTHORITATIVE_FEED_RECEIPT_READY' : 'READINESS_BLOCKED',
      authenticated: entitlementVerified,
      entitlementVerified,
      replayRequested: false,
      executionEnabled: false,
      dataset:
        typeof marketData?.selected_product === 'string'
          ? marketData.selected_product
          : null,
      schema: null,
      checkedAt,
      updatedAt: null,
      subscribedSymbols: [],
      rightsReason:
        typeof rights?.reason === 'string' ? rights.reason : undefined,
      reason: ok ? undefined : reasonParts.join(','),
    };
    return result;
  } catch (error) {
    return {
      configured: Boolean(process.env.DATABENTO_API_KEY),
      ok: false,
      provider: 'databento',
      state: 'UNAVAILABLE',
      authenticated: false,
      entitlementVerified: false,
      replayRequested: false,
      executionEnabled: false,
      dataset: null,
      schema: null,
      checkedAt,
      updatedAt: null,
      subscribedSymbols: [],
      reason:
        error instanceof QuantBackendUnavailableError
          ? error.code
          : 'RUST_BACKEND_UNREACHABLE',
    };
  }
}

export async function probeQuantResearchBackend(): Promise<QuantBackendStatus> {
  const backend = backendUrl();
  if (!backend) {
    return {
      connected: false,
      code: 'RUST_BACKEND_URL_NOT_CONFIGURED',
      runtime: 'rust',
    };
  }
  const token = process.env.INTRADAY_QUANT_TOKEN;
  if (!token || token.length < 32) {
    return {
      connected: false,
      code: 'RUST_BACKEND_TOKEN_NOT_CONFIGURED',
      runtime: 'rust',
    };
  }
  try {
    const response = await fetch(`${backend}/api/v1/research/universe`, {
      headers: {
        Accept: 'application/json',
        'X-Research-Token': token,
      },
      cache: 'no-store',
      signal: AbortSignal.timeout(4_000),
    });
    if (!response.ok) {
      return {
        connected: false,
        code: `RUST_BACKEND_HTTP_${response.status}`,
        runtime: 'rust',
      };
    }
    const payload = (await response.json()) as {
      status?: string;
      production_inference_owner?: string;
      execution?: string;
      model_runtime?: {
        schema_version?: string;
        status?: 'LOADED' | 'PARTIAL' | 'UNAVAILABLE';
        requested_artifact_count?: number;
        loaded_artifact_count?: number;
        failed_artifact_count?: number;
        quality_and_promotion_checked_separately?: boolean;
        automatic_execution_enabled?: boolean;
      };
    };
    if (
      payload.production_inference_owner !== 'quant_engine_rs' ||
      payload.execution !== 'DISABLED'
    ) {
      return {
        connected: false,
        code: 'RUST_BACKEND_BOUNDARY_MISMATCH',
        runtime: 'rust',
      };
    }
    const modelRuntime = payload.model_runtime;
    if (
      modelRuntime?.schema_version !== 'axio.model-runtime-receipt.v1' ||
      !Number.isSafeInteger(modelRuntime.requested_artifact_count) ||
      !Number.isSafeInteger(modelRuntime.loaded_artifact_count) ||
      !Number.isSafeInteger(modelRuntime.failed_artifact_count) ||
      modelRuntime.quality_and_promotion_checked_separately !== true ||
      modelRuntime.automatic_execution_enabled !== false
    ) {
      return {
        connected: false,
        code: 'RUST_MODEL_RUNTIME_CONTRACT_MISMATCH',
        runtime: 'rust',
      };
    }
    const requestedModelCount = modelRuntime.requested_artifact_count as number;
    const loadedModelCount = modelRuntime.loaded_artifact_count as number;
    const failedModelCount = modelRuntime.failed_artifact_count as number;
    const modelStatus = modelRuntime.status;
    const common = {
      runtime: 'rust' as const,
      universeStatus: payload.status,
      execution: payload.execution,
      modelStatus,
      requestedModelCount,
      loadedModelCount,
      failedModelCount,
    };
    if (
      modelStatus !== 'LOADED' ||
      requestedModelCount < 1 ||
      loadedModelCount !== requestedModelCount ||
      failedModelCount !== 0
    ) {
      return {
        connected: false,
        code:
          modelStatus === 'PARTIAL'
            ? 'RUST_MODEL_RUNTIME_PARTIAL'
            : 'RUST_MODEL_RUNTIME_UNAVAILABLE',
        ...common,
      };
    }
    const marketData = await probeDatabentoMarketData();
    const readiness: QuantPipelineReadiness = {
      model: {
        state: 'ready',
        code: 'FROZEN_MODEL_ARTIFACTS_LOADED',
        detail: `${loadedModelCount} of ${requestedModelCount} configured model artifacts loaded.`,
      },
      feed: marketData.ok
        ? {
            state: 'ready',
            code: 'AUTHORITATIVE_ALL_SYMBOL_FEED_RECEIPT_READY',
            detail:
              'The sanitized Rust production-readiness receipt verifies display rights, provider entitlement, stream freshness, and required-symbol feed freshness.',
          }
        : {
            state: 'blocked',
            code: marketData.reason ?? 'REALTIME_FEED_NOT_READY',
            detail:
              'The authoritative Rust production-readiness receipt does not mark the licensed feed ready.',
          },
      context: {
        state: 'not_checked',
        code: 'TARGET_CONTEXT_NOT_CHECKED',
        detail: 'Context completeness is checked for each requested symbol.',
      },
      inference: {
        state: 'not_checked',
        code: 'TARGET_INFERENCE_NOT_CHECKED',
        detail: 'Inference completion is checked for each requested symbol.',
      },
      publication: {
        state: 'not_checked',
        code: 'TARGET_PUBLICATION_NOT_CHECKED',
        detail: 'Forecast publication is checked for each requested symbol.',
      },
    };
    return {
      connected: true,
      code: 'CONNECTED',
      marketData,
      readiness,
      liveForecastReady: false,
      ...common,
    };
  } catch {
    return {
      connected: false,
      code: 'RUST_BACKEND_UNREACHABLE',
      runtime: 'rust',
    };
  }
}

export async function requestQuantResearch(
  query: MarketQueryV1
): Promise<QuantEvidenceEnvelope> {
  const backend = backendUrl();
  if (!backend) {
    throw new QuantBackendUnavailableError(
      'RUST_BACKEND_URL_NOT_CONFIGURED',
      'The Rust inference service URL is not configured for this deployment.'
    );
  }
  const token = process.env.INTRADAY_QUANT_TOKEN;
  if (!token || token.length < 32) {
    throw new QuantBackendUnavailableError(
      'RUST_BACKEND_TOKEN_NOT_CONFIGURED',
      'The server-side research token is missing or too short.'
    );
  }
  let response: Response;
  try {
    response = await fetch(`${backend}/api/v1/research/query`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-Research-Token': token,
      },
      body: JSON.stringify(query),
      cache: 'no-store',
      signal: AbortSignal.timeout(45_000),
    });
  } catch (error) {
    throw new QuantBackendUnavailableError(
      'RUST_BACKEND_UNREACHABLE',
      error instanceof Error ? error.message : 'The Rust inference service is unreachable.'
    );
  }
  const text = await response.text();
  if (!response.ok) {
    throw new QuantBackendUnavailableError(
      `RUST_BACKEND_HTTP_${response.status}`,
      text.slice(0, 800) || 'The Rust inference service rejected the request.'
    );
  }
  return verifyQuantResearchResponseText(text);
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function sessionBar(value: unknown): QuantSessionFiveMinuteBar | null {
  const bar = record(value);
  if (
    !bar ||
    !Number.isSafeInteger(bar.bar_number) ||
    (bar.bar_number as number) < 1 ||
    !isTimestamp(bar.window_start) ||
    !isTimestamp(bar.window_end) ||
    Date.parse(bar.window_end) <= Date.parse(bar.window_start) ||
    !isFiniteNumber(bar.open) ||
    !isFiniteNumber(bar.high) ||
    !isFiniteNumber(bar.low) ||
    !isFiniteNumber(bar.close) ||
    !isFiniteNumber(bar.volume) ||
    !isFiniteNumber(bar.return_pct) ||
    !Number.isSafeInteger(bar.minute_rows) ||
    (bar.minute_rows as number) < 1 ||
    (bar.minute_rows as number) > 5 ||
    bar.high < Math.max(bar.open, bar.close) ||
    bar.low > Math.min(bar.open, bar.close) ||
    bar.low <= 0 ||
    bar.volume < 0
  ) {
    return null;
  }
  return value as QuantSessionFiveMinuteBar;
}

function verifySessionSummary(payload: unknown): QuantSessionSummary {
  const summary = record(payload);
  const source = record(summary?.source);
  const bars = Array.isArray(summary?.five_minute_bars)
    ? summary.five_minute_bars.map(sessionBar)
    : [];
  const peaks = Array.isArray(summary?.peak_windows)
    ? summary.peak_windows.map(sessionBar)
    : [];
  const latest =
    summary?.latest_completed_bar === null
      ? null
      : sessionBar(summary?.latest_completed_bar);
  const valid =
    summary !== null &&
    source !== null &&
    summary.schema_version === 'axio.session-summary.v1' &&
    (summary.status === 'COMPLETE_78_BAR_SESSION' ||
      summary.status === 'SESSION_TO_DATE') &&
    summary.result_kind === 'OBSERVED_SESSION_TREND' &&
    (summary.scope === 'LAST_COMPLETED_REGULAR_SESSION' ||
      summary.scope === 'CURRENT_REGULAR_SESSION_TO_DATE') &&
    isNonEmptyString(summary.public_symbol) &&
    isNonEmptyString(summary.data_symbol) &&
    isNonEmptyString(summary.proxy_disclosure) &&
    typeof summary.session_date_et === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(summary.session_date_et) &&
    (summary.trend_state === 'UP_SESSION' ||
      summary.trend_state === 'DOWN_SESSION' ||
      summary.trend_state === 'FLAT_SESSION') &&
    isFiniteNumber(summary.session_return_pct) &&
    isFiniteNumber(summary.session_open) &&
    isFiniteNumber(summary.session_high) &&
    isFiniteNumber(summary.session_low) &&
    isFiniteNumber(summary.session_close) &&
    isFiniteNumber(summary.session_range_pct) &&
    isFiniteNumber(summary.close_location_pct) &&
    isFiniteNumber(summary.total_volume) &&
    summary.session_low > 0 &&
    summary.session_high >= summary.session_low &&
    summary.session_open >= summary.session_low &&
    summary.session_open <= summary.session_high &&
    summary.session_close >= summary.session_low &&
    summary.session_close <= summary.session_high &&
    summary.session_range_pct >= 0 &&
    summary.close_location_pct >= 0 &&
    summary.close_location_pct <= 100 &&
    summary.total_volume >= 0 &&
    isOptionalFiniteNumber(summary.close_volume_proxy) &&
    isOptionalFiniteNumber(summary.close_vs_close_volume_proxy_bps) &&
    isNonnegativeSafeInteger(summary.minute_rows) &&
    summary.minute_rows > 0 &&
    isNonnegativeSafeInteger(summary.five_minute_bar_count) &&
    summary.five_minute_bar_count > 0 &&
    bars.length === summary.five_minute_bar_count &&
    bars.every((bar) => bar !== null) &&
    peaks.length <= 3 &&
    peaks.every((bar) => bar !== null) &&
    (summary.latest_completed_bar === null || latest !== null) &&
    source.provider === 'databento' &&
    source.dataset === 'EQUS.MINI' &&
    source.schema === 'ohlcv-1m' &&
    source.storage === 'APPEND_ONLY_SQLITE' &&
    isTimestamp(source.first_observed_at) &&
    isTimestamp(source.last_observed_at) &&
    isTimestamp(source.last_available_at) &&
    Date.parse(source.first_observed_at) <= Date.parse(source.last_observed_at) &&
    Date.parse(source.last_observed_at) <= Date.parse(source.last_available_at) &&
    Array.isArray(source.entitlements) &&
    source.entitlements.length > 0 &&
    source.entitlements.every(isNonEmptyString) &&
    summary.model_status ===
      'LIVE_FROZEN_MODEL_RESULT_NOT_AVAILABLE_FOR_THIS_CUTOFF' &&
    summary.probability_published === false &&
    summary.automatic_execution_enabled === false &&
    Array.isArray(summary.caveats) &&
    summary.caveats.length > 0 &&
    summary.caveats.every(isNonEmptyString);
  if (!valid) {
    throw contractMismatch('observed Databento session summary is malformed');
  }
  if (
    summary.status === 'COMPLETE_78_BAR_SESSION' &&
    (summary.minute_rows !== 390 ||
      summary.five_minute_bar_count !== 78 ||
      latest === null)
  ) {
    throw contractMismatch(
      'complete observed session does not contain 390 minutes and 78 five-minute bars'
    );
  }
  return payload as QuantSessionSummary;
}

export async function requestQuantSessionSummary(
  symbol: string
): Promise<QuantSessionSummary> {
  const normalized = symbol.trim().toUpperCase();
  if (!/^[A-Z][A-Z0-9.-]{0,11}$/.test(normalized)) {
    throw new QuantBackendUnavailableError(
      'RUST_SESSION_SUMMARY_SYMBOL_INVALID',
      'The requested session-summary symbol is invalid.'
    );
  }
  const payload = await fetchQuantJson(
    `/api/v1/research/session-summary?symbol=${encodeURIComponent(normalized)}`,
    10_000
  );
  return verifySessionSummary(payload);
}

const DAILY_REGIMES = new Set([
  'HIGH_VOL_SELL_OFF',
  'HIGH_VOL_RECOVERY',
  'LOW_VOL_BREAKOUT',
  'RISK_ON_TREND',
  'RISK_OFF_TREND',
  'HIGH_VOL_RANGE',
  'LOW_VOL_RANGE',
  'MIXED_TRANSITION',
]);

function wilsonScoreInterval(successes: number, trials: number, z: number) {
  const proportion = successes / trials;
  const zSquared = z * z;
  const denominator = 1 + zSquared / trials;
  const center =
    (proportion + zSquared / (2 * trials)) / denominator;
  const radius =
    (z *
      Math.sqrt(
        (proportion * (1 - proportion)) / trials +
          zSquared / (4 * trials * trials)
      )) /
    denominator;
  return {
    lower: Math.max(0, center - radius),
    upper: Math.min(1, center + radius),
  };
}

function verifyDailyRegimeReport(payload: unknown): QuantDailyRegimeReport {
  const report = record(payload);
  const regime = record(report?.current_regime);
  const market = record(report?.current_market);
  const prediction = record(report?.prediction);
  const rawLikelihood = record(report?.raw_likelihood);
  const interval = record(report?.prediction_interval);
  const rationale = record(report?.prediction_rationale);
  const validation = record(report?.walk_forward_validation);
  const source = record(report?.source);
  const model = record(report?.model_contract);
  const contextPolicy = record(report?.macro_news_policy);
  const taxonomy = Array.isArray(report?.regime_taxonomy)
    ? report.regime_taxonomy
    : [];
  const analogs = Array.isArray(report?.similar_historical_sessions)
    ? report.similar_historical_sessions
    : [];
  const sameRegimeHistory = Array.isArray(report?.same_regime_history)
    ? report.same_regime_history
    : [];
  const features = Array.isArray(report?.feature_snapshot)
    ? report.feature_snapshot
    : [];
  const files = Array.isArray(source?.files) ? source.files : [];
  const coverage = record(market?.minute_coverage);
  const validHistoricalSession = (value: unknown, index: number) => {
    const analog = record(value);
    return (
      analog !== null &&
      analog.rank === index + 1 &&
      typeof analog.session_date_et === 'string' &&
      /^\d{4}-\d{2}-\d{2}$/.test(analog.session_date_et) &&
      DAILY_REGIMES.has(String(analog.regime)) &&
      analog.regime === regime?.label &&
      isFiniteNumber(analog.standardized_euclidean_distance) &&
      analog.standardized_euclidean_distance >= 0 &&
      isFiniteNumber(analog.session_return_pct) &&
      typeof analog.next_session_date_et === 'string' &&
      /^\d{4}-\d{2}-\d{2}$/.test(analog.next_session_date_et) &&
      isFiniteNumber(analog.next_session_return_pct) &&
      (analog.next_session_direction === 'UP' ||
        analog.next_session_direction === 'DOWN' ||
        analog.next_session_direction === 'FLAT')
    );
  };
  const taxonomyLabels = taxonomy.map((value) => String(record(value)?.label));
  const activeTaxonomy = taxonomy.filter(
    (value) => record(value)?.active === true
  );
  const sameRegimeDates = sameRegimeHistory.map(
    (value) => String(record(value)?.session_date_et)
  );
  const expectedRawLikelihoodInterval =
    prediction !== null &&
    Number.isSafeInteger(prediction.raw_up_count) &&
    Number.isSafeInteger(prediction.analog_sample_size) &&
    (prediction.analog_sample_size as number) > 0
      ? wilsonScoreInterval(
          prediction.raw_up_count as number,
          prediction.analog_sample_size as number,
          1.959963984540054
        )
      : null;
  const valid =
    report !== null &&
    regime !== null &&
    market !== null &&
    prediction !== null &&
    rawLikelihood !== null &&
    interval !== null &&
    rationale !== null &&
    validation !== null &&
    source !== null &&
    model !== null &&
    contextPolicy !== null &&
    coverage !== null &&
    report.schema_version === 'axio.daily-regime.v3' &&
    report.status === 'AVAILABLE_UNCALIBRATED' &&
    report.result_kind === 'NEXT_REGULAR_SESSION_ANALOG_LEAN' &&
    isTimestamp(report.generated_at) &&
    isTimestamp(report.observation_cutoff) &&
    report.public_symbol === 'SPX' &&
    report.data_symbol === 'SPY' &&
    isNonEmptyString(report.proxy_disclosure) &&
    report.forecast_horizon === 'NEXT_COMPLETE_US_REGULAR_SESSION' &&
    DAILY_REGIMES.has(String(regime.label)) &&
    isNonEmptyString(regime.display_name) &&
    isNonEmptyString(regime.definition) &&
    isNonEmptyString(regime.market_summary) &&
    Array.isArray(regime.classification_reasons) &&
    regime.classification_reasons.length >= 5 &&
    regime.classification_reasons.every(isNonEmptyString) &&
    isFiniteNumber(regime.volatility_percentile_prior_252) &&
    regime.volatility_percentile_prior_252 >= 0 &&
    regime.volatility_percentile_prior_252 <= 1 &&
    isFiniteNumber(regime.cross_asset_breadth) &&
    regime.cross_asset_breadth >= 0 &&
    regime.cross_asset_breadth <= 1 &&
    taxonomy.length === 8 &&
    new Set(taxonomyLabels).size === 8 &&
    taxonomyLabels.every((label) => DAILY_REGIMES.has(label)) &&
    activeTaxonomy.length === 1 &&
    record(activeTaxonomy[0])?.label === regime.label &&
    taxonomy.every((value, index) => {
      const item = record(value);
      return (
        item !== null &&
        item.priority === index + 1 &&
        DAILY_REGIMES.has(String(item.label)) &&
        isNonEmptyString(item.display_name) &&
        isNonEmptyString(item.definition) &&
        isNonEmptyString(item.selection_rule) &&
        typeof item.active === 'boolean'
      );
    }) &&
    typeof market.session_date_et === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(market.session_date_et) &&
    [
      market.open,
      market.high,
      market.low,
      market.close,
      market.session_return_pct,
      market.twenty_session_return_pct,
      market.twenty_session_annualized_volatility_pct,
      market.close_location_pct,
    ].every(isFiniteNumber) &&
    (market.low as number) > 0 &&
    (market.high as number) >= (market.low as number) &&
    (market.open as number) >= (market.low as number) &&
    (market.open as number) <= (market.high as number) &&
    (market.close as number) >= (market.low as number) &&
    (market.close as number) <= (market.high as number) &&
    (market.close_location_pct as number) >= 0 &&
    (market.close_location_pct as number) <= 100 &&
    ['SPY', 'QQQ', 'IWM', 'SOXX', 'HYG', 'TLT', 'UUP', 'VXX'].every(
      (symbol) =>
        Number.isSafeInteger(coverage[symbol]) &&
        // Databento OHLCV-1m emits only minutes containing trades. Rust also
        // verifies that sparse context ETFs cover both session edges.
        (coverage[symbol] as number) >= (symbol === 'SPY' ? 390 : 20)
    ) &&
    (prediction.lean === 'UP' ||
      prediction.lean === 'DOWN' ||
      prediction.lean === 'MIXED') &&
    (prediction.directional_call_status ===
      'PUBLISHED_RAW_RESEARCH_LEAN' ||
      prediction.directional_call_status ===
        'WITHHELD_INSUFFICIENT_AGREEMENT') &&
    isNonEmptyString(prediction.target_definition) &&
    Number.isSafeInteger(prediction.analog_sample_size) &&
    (prediction.analog_sample_size as number) >= 10 &&
    Number.isSafeInteger(prediction.raw_up_count) &&
    Number.isSafeInteger(prediction.raw_down_or_flat_count) &&
    (prediction.raw_up_count as number) +
      (prediction.raw_down_or_flat_count as number) ===
      prediction.analog_sample_size &&
    isFiniteNumber(prediction.raw_up_frequency) &&
    Math.abs(
      prediction.raw_up_frequency -
        (prediction.raw_up_count as number) /
          (prediction.analog_sample_size as number)
    ) < 1e-10 &&
    isFiniteNumber(prediction.raw_directional_agreement) &&
    Math.abs(
      prediction.raw_directional_agreement -
        Math.max(
          prediction.raw_up_frequency as number,
          1 - (prediction.raw_up_frequency as number)
        )
    ) < 1e-10 &&
    prediction.minimum_directional_agreement === 0.6 &&
    isOptionalFiniteNumber(prediction.reported_evidence_strength) &&
    (prediction.directional_call_status ===
    'WITHHELD_INSUFFICIENT_AGREEMENT'
      ? prediction.lean === 'MIXED' &&
        prediction.reported_evidence_strength === null &&
        (prediction.raw_directional_agreement as number) < 0.6
      : prediction.lean !== 'MIXED' &&
        prediction.reported_evidence_strength ===
          prediction.raw_directional_agreement &&
        (prediction.raw_directional_agreement as number) >= 0.6) &&
    isFiniteNumber(prediction.median_next_session_return_pct) &&
    isFiniteNumber(prediction.mean_next_session_return_pct) &&
    prediction.calibrated_probability === false &&
    isNonEmptyString(prediction.interpretation) &&
    rawLikelihood.method ===
      'NEAREST_SAME_REGIME_EMPIRICAL_SIGN_FREQUENCY' &&
    rawLikelihood.sample_size === prediction.analog_sample_size &&
    rawLikelihood.up_count === prediction.raw_up_count &&
    rawLikelihood.down_or_flat_count === prediction.raw_down_or_flat_count &&
    isFiniteNumber(rawLikelihood.up_estimate) &&
    Math.abs(
      (rawLikelihood.up_estimate as number) -
        (prediction.raw_up_frequency as number)
    ) < 1e-10 &&
    isFiniteNumber(rawLikelihood.down_or_flat_estimate) &&
    Math.abs(
      (rawLikelihood.down_or_flat_estimate as number) -
        (1 - (prediction.raw_up_frequency as number))
    ) < 1e-10 &&
    rawLikelihood.confidence_method === 'WILSON_SCORE_INTERVAL' &&
    rawLikelihood.confidence_level === 0.95 &&
    isFiniteNumber(rawLikelihood.up_lower_bound) &&
    isFiniteNumber(rawLikelihood.up_upper_bound) &&
    expectedRawLikelihoodInterval !== null &&
    Math.abs(
      (rawLikelihood.up_lower_bound as number) -
        expectedRawLikelihoodInterval.lower
    ) < 1e-10 &&
    Math.abs(
      (rawLikelihood.up_upper_bound as number) -
        expectedRawLikelihoodInterval.upper
    ) < 1e-10 &&
    (rawLikelihood.up_lower_bound as number) <=
      (rawLikelihood.up_estimate as number) &&
    (rawLikelihood.up_estimate as number) <=
      (rawLikelihood.up_upper_bound as number) &&
    rawLikelihood.calibrated_probability === false &&
    isNonEmptyString(rawLikelihood.interpretation) &&
    analogs.length === prediction.analog_sample_size &&
    analogs.every(validHistoricalSession) &&
    sameRegimeHistory.length >= analogs.length &&
    sameRegimeHistory.every(validHistoricalSession) &&
    new Set(sameRegimeDates).size === sameRegimeHistory.length &&
    analogs.every(
      (value, index) =>
        record(value)?.session_date_et ===
          record(sameRegimeHistory[index])?.session_date_et &&
        record(value)?.standardized_euclidean_distance ===
          record(sameRegimeHistory[index])?.standardized_euclidean_distance
    ) &&
    interval.method === 'PREQUENTIAL_ABSOLUTE_RESIDUAL_CONFORMAL' &&
    interval.nominal_coverage === 0.9 &&
    isFiniteNumber(interval.point_estimate_pct) &&
    isFiniteNumber(interval.lower_bound_pct) &&
    isFiniteNumber(interval.upper_bound_pct) &&
    (interval.lower_bound_pct as number) <=
      (interval.point_estimate_pct as number) &&
    (interval.point_estimate_pct as number) <=
      (interval.upper_bound_pct as number) &&
    Number.isSafeInteger(interval.calibration_sessions) &&
    (interval.calibration_sessions as number) >= 40 &&
    Number.isSafeInteger(interval.evaluated_sessions) &&
    Number.isSafeInteger(interval.covered_sessions) &&
    (interval.covered_sessions as number) <=
      (interval.evaluated_sessions as number) &&
    isOptionalFiniteNumber(interval.empirical_coverage) &&
    (interval.empirical_coverage === null ||
      ((interval.empirical_coverage as number) >= 0 &&
        (interval.empirical_coverage as number) <= 1)) &&
    interval.directional_probability === false &&
    isNonEmptyString(interval.interpretation) &&
    isNonEmptyString(rationale.conclusion) &&
    Array.isArray(rationale.supporting_evidence) &&
    rationale.supporting_evidence.every(isNonEmptyString) &&
    Array.isArray(rationale.opposing_evidence) &&
    rationale.opposing_evidence.every(isNonEmptyString) &&
    Array.isArray(rationale.uncertainty_reasons) &&
    rationale.uncertainty_reasons.length >= 3 &&
    rationale.uncertainty_reasons.every(isNonEmptyString) &&
    Array.isArray(rationale.model_steps) &&
    rationale.model_steps.length >= 7 &&
    rationale.model_steps.every(isNonEmptyString) &&
    validation.method === 'PURGED_EXPANDING_WALK_FORWARD' &&
    Number.isSafeInteger(validation.evaluation_window_sessions) &&
    Number.isSafeInteger(validation.eligible_queries) &&
    Number.isSafeInteger(validation.directional_calls) &&
    Number.isSafeInteger(validation.correct_directional_calls) &&
    (validation.correct_directional_calls as number) <=
      (validation.directional_calls as number) &&
    isOptionalFiniteNumber(validation.raw_directional_hit_frequency) &&
    validation.probability_interpretation_allowed === false &&
    Array.isArray(validation.notes) &&
    validation.notes.every(isNonEmptyString) &&
    features.length === 15 &&
    features.every((value) => {
      const feature = record(value);
      return (
        feature !== null &&
        isNonEmptyString(feature.name) &&
        isFiniteNumber(feature.value) &&
        isNonEmptyString(feature.unit)
      );
    }) &&
    source.provider === 'Databento' &&
    source.dataset === 'EQUS.MINI' &&
    source.schema === 'ohlcv-1m' &&
    source.session_clock === '09:30-16:00 America/New_York' &&
    typeof source.history_start === 'string' &&
    typeof source.history_end === 'string' &&
    Number.isSafeInteger(source.complete_feature_sessions) &&
    (source.complete_feature_sessions as number) >= 100 &&
    isTimestamp(source.acquired_at) &&
    isTimestamp(source.latest_available_at) &&
    typeof source.dataset_sha256 === 'string' &&
    SHA256_HEX.test(source.dataset_sha256) &&
    files.length >= 4 &&
    files.every((value) => {
      const file = record(value);
      return (
        file !== null &&
        isNonEmptyString(file.request_name) &&
        isNonEmptyString(file.file_name) &&
        Number.isSafeInteger(file.bytes) &&
        (file.bytes as number) > 0 &&
        typeof file.sha256 === 'string' &&
        SHA256_HEX.test(file.sha256) &&
        isTimestamp(file.acquired_at)
      );
    }) &&
    model.model_id === 'axio7.spx-next-session-regime-analog' &&
    isNonEmptyString(model.model_version) &&
    model.owner === 'quant_engine_rs' &&
    isNonEmptyString(model.regime_algorithm) &&
    isNonEmptyString(model.analog_algorithm) &&
    model.feature_count === 15 &&
    model.neighbors === 15 &&
    model.minimum_analogs === 10 &&
    isNonEmptyString(model.fit_semantics) &&
    isNonEmptyString(model.label_semantics) &&
    model.status === 'UNCALIBRATED_RESEARCH_OUTPUT' &&
    model.source_code === 'quant_engine_rs/src/daily_regime.rs' &&
    contextPolicy.status ===
      'DISPLAY_CONTEXT_ONLY_NOT_NUMERICAL_MODEL_INPUT' &&
    isNonEmptyString(contextPolicy.detail) &&
    report.probability_published === false &&
    report.automatic_execution_enabled === false &&
    Array.isArray(report.caveats) &&
    report.caveats.length > 0 &&
    report.caveats.every(isNonEmptyString);
  if (!valid) {
    throw contractMismatch('daily regime and historical analog report is malformed');
  }
  return payload as QuantDailyRegimeReport;
}

export async function requestQuantDailyRegime(
  symbol: string
): Promise<QuantDailyRegimeReport> {
  const normalized = symbol.trim().toUpperCase();
  if (normalized !== 'SPX') {
    throw new QuantBackendUnavailableError(
      'RUST_DAILY_REGIME_SYMBOL_UNSUPPORTED',
      'The daily-regime v3 contract currently supports SPX through SPY.'
    );
  }
  const payload = await fetchQuantJson(
    `/api/v1/research/daily-regime?symbol=${encodeURIComponent(normalized)}`,
    45_000
  );
  return verifyDailyRegimeReport(payload);
}
