import type { QuantPipelineReadiness } from '@/lib/forecast-chat-types';

export type QuantPipelineCounts = {
  targets: number;
  contextReady: number;
  inferred: number;
  calibrated: number;
  promoted: number;
  published: number;
  withinSla: number;
};

export type QuantPipelineStatus = {
  counts: QuantPipelineCounts;
  readiness: Pick<
    QuantPipelineReadiness,
    'context' | 'inference' | 'publication'
  >;
  liveForecastReady: boolean;
};

const INFERENCE_COMPLETE_STAGES = new Set([
  'PREDICTION_LEDGER',
  'PUBLISH_STAGING',
  'PUBLISH_COMMIT',
  'PUBLISHED',
]);
const CONTEXT_READY_STATES = new Set([
  'RUNNING',
  'SLA_REJECTED',
  'PUBLISH_REJECTED',
  'PUBLISHED',
]);

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

/**
 * Reduce the sanitized Rust production-readiness receipt to user-visible
 * pipeline state. This function never inspects forecast values and never
 * upgrades a partial or malformed row to ready.
 */
export function pipelineStatusFromReceipt(
  receipt: Record<string, unknown>
): QuantPipelineStatus {
  const rawForecasts = Array.isArray(receipt.forecasts)
    ? receipt.forecasts
    : [];
  const forecasts = rawForecasts
    .map(record)
    .filter((row): row is Record<string, unknown> => row !== null);
  const everyForecastRowIsAnObject = forecasts.length === rawForecasts.length;
  const counts: QuantPipelineCounts = {
    targets: rawForecasts.length,
    contextReady: 0,
    inferred: 0,
    calibrated: 0,
    promoted: 0,
    published: 0,
    withinSla: 0,
  };
  let waitingForContext = false;
  let inferenceRunning = false;
  for (const forecast of forecasts) {
    const live = record(forecast.live_inference);
    const status = String(live?.status ?? 'UNAVAILABLE');
    const stage = String(live?.stage ?? 'UNAVAILABLE');
    const contextBlockers = Array.isArray(live?.context_blockers)
      ? live.context_blockers
      : [];
    const contextReady =
      live?.status_available === true &&
      contextBlockers.length === 0 &&
      CONTEXT_READY_STATES.has(status);
    if (contextReady) counts.contextReady += 1;
    if (['WAITING_FOR_TARGET', 'WAITING_FOR_CONTEXT'].includes(status)) {
      waitingForContext = true;
    }
    const inferenceComplete =
      INFERENCE_COMPLETE_STAGES.has(stage) || status === 'SLA_REJECTED';
    if (inferenceComplete) counts.inferred += 1;
    if (status === 'RUNNING') inferenceRunning = true;
    if (forecast.calibration === 'PROMOTED') counts.calibrated += 1;
    if (
      forecast.artifact_present === true &&
      forecast.validation_status === 'PASSED' &&
      forecast.promotion_registry_matches === true
    ) {
      counts.promoted += 1;
    }
    const published =
      status === 'PUBLISHED' &&
      live?.forecast_committed === true &&
      live?.receipt_committed === true &&
      live?.ledger_persisted === true;
    if (published) counts.published += 1;
    const endToEndMs = live?.end_to_end_ms;
    const budgetMs = live?.budget_ms;
    if (
      typeof endToEndMs === 'number' &&
      Number.isFinite(endToEndMs) &&
      endToEndMs >= 0 &&
      typeof budgetMs === 'number' &&
      Number.isFinite(budgetMs) &&
      budgetMs > 0 &&
      endToEndMs <= budgetMs
    ) {
      counts.withinSla += 1;
    }
  }
  const all = (count: number) => counts.targets > 0 && count === counts.targets;
  const liveForecastReady =
    receipt.public_realtime_research_ready === true &&
    everyForecastRowIsAnObject &&
    all(counts.published) &&
    forecasts.every((forecast) => forecast.ready === true);
  return {
    counts,
    readiness: {
      context: {
        state: all(counts.contextReady)
          ? 'ready'
          : waitingForContext
            ? 'waiting'
            : 'blocked',
        code: all(counts.contextReady)
          ? 'ALL_TARGET_CONTEXT_READY'
          : 'TARGET_CONTEXT_INCOMPLETE',
        detail: `${counts.contextReady} of ${counts.targets} targets have exact-cutoff causal context.`,
      },
      inference: {
        state: all(counts.inferred)
          ? 'ready'
          : inferenceRunning
            ? 'waiting'
            : 'blocked',
        code: all(counts.inferred)
          ? 'ALL_TARGET_INFERENCE_COMPLETE'
          : 'TARGET_INFERENCE_INCOMPLETE',
        detail: `${counts.inferred} of ${counts.targets} targets completed frozen Rust inference.`,
      },
      publication: {
        state: liveForecastReady ? 'ready' : 'blocked',
        code: liveForecastReady
          ? 'ALL_TARGET_PUBLICATIONS_READY'
          : 'PUBLICATION_GATES_BLOCKED',
        detail: `${counts.published} of ${counts.targets} targets are ledger-backed publications; ${counts.calibrated} calibrated and ${counts.promoted} promotion-matched.`,
      },
    },
    liveForecastReady,
  };
}
