import Ajv2020, { type ErrorObject, type ValidateFunction } from "ajv/dist/2020";
import addFormats from "ajv-formats";
import type {
  Manifest,
  ModelCard,
  SessionArtifact,
  SessionIndexArtifact,
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

export function validateManifest(value: unknown): Manifest {
  return validate(value, "manifest", manifestValidator);
}

export function validateSessionIndex(value: unknown): SessionIndexArtifact {
  return validate(value, "session index", sessionIndexValidator);
}

export function validateSession(value: unknown): SessionArtifact {
  return validate(value, "session", sessionValidator);
}

export function validateSummary(value: unknown): SummaryArtifact {
  return validate(value, "summary", summaryValidator);
}

export function validateModelCard(value: unknown): ModelCard {
  return validate(value, "model card", modelCardValidator);
}
