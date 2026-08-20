import Ajv2020, { type ErrorObject, type ValidateFunction } from "ajv/dist/2020";
import addFormats from "ajv-formats";
import type {
  Manifest,
  ModelCard,
  ChartBar,
  ReplayRow,
  SessionArtifact,
  SessionIndexArtifact,
  SessionIndexEntry,
  SummaryArtifact,
} from "./generated/contracts";
import {
  manifestSchema,
  modelCardSchema,
  sessionIndexSchema,
  sessionSchema,
  summarySchema,
} from "./schemas";
import { ArtifactError } from "./ArtifactError";

const CONTRACT_VERSION = "1.0.0";
const ajv = new Ajv2020({ allErrors: true, strict: true });
addFormats(ajv);

const manifestValidator = ajv.compile<Manifest>(manifestSchema);
const sessionIndexValidator =
  ajv.compile<SessionIndexArtifact>(sessionIndexSchema);
const sessionValidator = ajv.compile<SessionArtifact>(sessionSchema);
const summaryValidator = ajv.compile<SummaryArtifact>(summarySchema);
const modelCardValidator = ajv.compile<ModelCard>(modelCardSchema);

function assertSupportedVersion(value: unknown, artifact: string): void {
  if (
    typeof value === "object" &&
    value !== null &&
    "contract_version" in value &&
    typeof value.contract_version === "string" &&
    value.contract_version !== CONTRACT_VERSION
  ) {
    throw ArtifactError.unsupportedVersion(artifact, {
      contractVersion: value.contract_version,
    });
  }
}

function validate<T>(
  value: unknown,
  artifact: string,
  validator: ValidateFunction<T>,
): T {
  assertSupportedVersion(value, artifact);
  if (!validator(value)) {
    throw ArtifactError.invalidSchema(
      artifact,
      validator.errors as ErrorObject[] | null,
    );
  }
  return value;
}

function semanticFailure(artifact: string, rule: string): never {
  throw ArtifactError.invalidSchema(artifact, { semanticRule: rule });
}

function timestampMilliseconds(timestamp: string): number {
  return Date.parse(timestamp);
}

function sameStrings(left: readonly string[], right: readonly string[]): boolean {
  return (
    left.length === right.length &&
    left.every((value, index) => value === right[index])
  );
}

function validateChartBarSemantics(bar: ChartBar): void {
  if (
    timestampMilliseconds(bar.available_at) !==
    timestampMilliseconds(bar.timestamp) + 60_000
  ) {
    semanticFailure("session", "chart-bar-availability");
  }

  const values = [bar.open, bar.high, bar.low, bar.close, bar.volume];
  const hasNull = values.some((value) => value === null);
  if (hasNull) {
    if (
      !bar.quality_flags.includes("UNRESOLVED_GAP") ||
      values.some((value) => value !== null)
    ) {
      semanticFailure("session", "chart-bar-unresolved-gap");
    }
    return;
  }

  if (
    bar.open === null ||
    bar.high === null ||
    bar.low === null ||
    bar.close === null ||
    bar.volume === null
  ) {
    semanticFailure("session", "chart-bar-completeness");
  }
  if (
    bar.low > Math.min(bar.open, bar.close) ||
    bar.high < Math.max(bar.open, bar.close)
  ) {
    semanticFailure("session", "chart-bar-ohlc-order");
  }
}

function validateForecastSemantics(row: ReplayRow): void {
  if (row.forecast.interval_low > row.forecast.interval_high) {
    semanticFailure("session", "forecast-interval-order");
  }
}

function validateSessionSemantics(session: SessionArtifact): void {
  for (const bar of session.bars) validateChartBarSemantics(bar);

  for (let index = 1; index < session.bars.length; index += 1) {
    const left = session.bars[index - 1]!;
    const right = session.bars[index]!;
    if (timestampMilliseconds(left.timestamp) >= timestampMilliseconds(right.timestamp)) {
      semanticFailure("session", "chart-bar-order");
    }
    if (
      timestampMilliseconds(right.timestamp) !==
      timestampMilliseconds(left.timestamp) + 60_000
    ) {
      semanticFailure("session", "chart-bar-contiguity");
    }
  }

  for (let index = 0; index < session.rows.length; index += 1) {
    const row = session.rows[index]!;
    validateForecastSemantics(row);
    const previous = session.rows[index - 1];
    if (
      previous !== undefined &&
      (previous.bar_index >= row.bar_index ||
        timestampMilliseconds(previous.timestamp) >=
          timestampMilliseconds(row.timestamp))
    ) {
      semanticFailure("session", "replay-row-order");
    }

    const bar = session.bars[row.bar_index];
    if (
      bar === undefined ||
      bar.open === null ||
      bar.high === null ||
      bar.low === null ||
      bar.close === null ||
      bar.volume === null
    ) {
      semanticFailure("session", "replay-row-chart-bar");
    }
    if (
      row.timestamp !== bar.timestamp ||
      row.available_at !== bar.available_at ||
      row.open !== bar.open ||
      row.high !== bar.high ||
      row.low !== bar.low ||
      row.close !== bar.close ||
      row.volume !== bar.volume
    ) {
      semanticFailure("session", "replay-row-alignment");
    }

    const expectedOutcomeIndex = row.bar_index + 5;
    const outcomeBar = session.bars[expectedOutcomeIndex];
    if (
      row.outcome.bar_index !== expectedOutcomeIndex ||
      outcomeBar === undefined ||
      outcomeBar.open === null ||
      outcomeBar.high === null ||
      outcomeBar.low === null ||
      outcomeBar.close === null ||
      outcomeBar.volume === null
    ) {
      semanticFailure("session", "replay-outcome-horizon");
    }
    if (
      row.outcome.timestamp !== outcomeBar.timestamp ||
      row.outcome.available_at !== outcomeBar.available_at ||
      row.outcome.close !== outcomeBar.close
    ) {
      semanticFailure("session", "replay-outcome-alignment");
    }
  }
}

function validateSessionIndexSemantics(index: SessionIndexArtifact): void {
  for (let position = 0; position < index.sessions.length; position += 1) {
    const entry = index.sessions[position]!;
    const pathMatch = /^sessions\/(\d{4}-\d{2}-\d{2})\.json$/.exec(entry.path);
    if (pathMatch?.[1] !== entry.date) {
      semanticFailure("session index", "session-index-path-date");
    }
    const previous = index.sessions[position - 1];
    if (previous !== undefined && previous.date >= entry.date) {
      semanticFailure("session index", "session-index-order");
    }
  }
}

export function assertSessionIndexMatchesManifest(
  manifest: Manifest,
  index: SessionIndexArtifact,
): void {
  if (
    index.contract_version !== manifest.contract_version ||
    index.artifact_sha256 !== manifest.artifact_sha256
  ) {
    throw ArtifactError.hashMismatch(manifest.session_index.path, {
      relation: "manifest-to-index",
    });
  }
}

export function assertSessionMatchesBundle(
  manifest: Manifest,
  entry: SessionIndexEntry,
  session: SessionArtifact,
): void {
  const provenance = session.provenance;
  const hasBundleIdentity =
    session.contract_version === manifest.contract_version &&
    session.status === manifest.status &&
    session.symbol === manifest.symbol &&
    session.session_date === entry.date &&
    session.rows.length === entry.rows &&
    provenance.dataset_sha256 === manifest.dataset_sha256 &&
    provenance.artifact_sha256 === manifest.artifact_sha256 &&
    provenance.feature_version === manifest.feature_version &&
    provenance.direction_model_version === manifest.direction_model_version &&
    provenance.return_model_version === manifest.return_model_version &&
    sameStrings(provenance.caveat_codes, manifest.caveat_codes) &&
    session.rows.every(
      (row) =>
        row.forecast.probability_status === manifest.probability_status &&
        row.forecast.interval_status === manifest.interval_status,
    );

  if (!hasBundleIdentity) {
    throw ArtifactError.hashMismatch(entry.path, {
      relation: "manifest-index-to-session",
    });
  }
}

export function validateManifest(value: unknown): Manifest {
  return validate(value, "manifest", manifestValidator);
}

export function validateSessionIndex(value: unknown): SessionIndexArtifact {
  const index = validate(value, "session index", sessionIndexValidator);
  validateSessionIndexSemantics(index);
  return index;
}

export function validateSession(value: unknown): SessionArtifact {
  const session = validate(value, "session", sessionValidator);
  validateSessionSemantics(session);
  return session;
}

export function validateSummary(value: unknown): SummaryArtifact {
  return validate(value, "summary", summaryValidator);
}

export function validateModelCard(value: unknown): ModelCard {
  return validate(value, "model card", modelCardValidator);
}
