import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

import {
  parseReleaseController,
  parseReleaseSubject,
  type ReleaseControllerIdentity,
  type ReleaseEnvironment,
  type ReleaseSubjectIdentity,
  type ReleaseSurface,
} from "./verify-release-bundle.ts";

type ArtifactAvailability = "retained" | "missing" | "expired";
type ReceiptOutcome =
  | "success"
  | "failed-before-mutation"
  | "withheld-dependency"
  | "partial"
  | "recovered"
  | "rollback-failed";
type RollbackOutcome = "not-needed" | "not-attempted" | "recovered" | "failed";
type EligibilityScope = "full" | "demo-only" | "none";

export type DeploymentSurfaceReceipt = {
  target: { pagesProject: string; host: string };
  prior: { deploymentId: string | null; artifactDigest: string | null };
  attemptedDeploymentId: string | null;
  resultingDeploymentId: string | null;
  finalDeploymentId: string | null;
  probes: Array<{ url: string; status: number; passed: boolean; observedAt: string }>;
  rollback: { outcome: RollbackOutcome; deploymentId: string | null };
};

export type DeploymentReceipt = {
  schemaVersion: 1;
  environment: ReleaseEnvironment;
  artifact: { id: string; digest: string; availability: ArtifactAvailability };
  subject: ReleaseSubjectIdentity;
  controller: ReleaseControllerIdentity;
  manifestSha256: string;
  releaseDigest: string;
  profileIdentity: string;
  infrastructure: {
    terraformPlanDigest: string;
    liveInventoryDigest: string;
    lockProofDigest: string;
    beforeState: { lineage: string; serial: number };
    afterState: { lineage: string; serial: number };
  };
  surfaces: Record<ReleaseSurface, DeploymentSurfaceReceipt>;
  actor: string;
  startedAt: string;
  completedAt: string;
  recoveryOwner: string;
  nextAction: string;
  outcome: ReceiptOutcome;
  eligibility: { scope: EligibilityScope; promotable: boolean; reasons: string[] };
};

export type ReceiptVerificationContext = {
  expectedSubject: ReleaseSubjectIdentity;
  expectedController: ReleaseControllerIdentity;
  expectedManifestSha256: string;
  expectedReleaseDigest: string;
  prodLandingEligible: boolean;
};

export type ReceiptVerificationResult = {
  promotable: boolean;
  reconstructable: boolean;
  scope: EligibilityScope;
};

type ProdCheckStatus = "passed" | "failed" | "blocked";
type NativeCheck =
  | { availability: "available"; status: "passed" | "failed" | "blocked"; reason: null }
  | { availability: "unavailable"; status: "not-run"; reason: string };

export type ProdEvidenceEnvelope = {
  schemaVersion: "ritual-prod-evidence.v1";
  status: "ready" | "blocked";
  subject: ReleaseSubjectIdentity;
  controller: ReleaseControllerIdentity;
  source: {
    runId: string;
    attempt: number;
    artifact: { id: string; archiveSha256: string; manifestSha256: string };
  };
  checks: {
    rust: { status: ProdCheckStatus };
    python: { status: ProdCheckStatus };
    typescript: { status: ProdCheckStatus };
    docker: { status: ProdCheckStatus };
    native: NativeCheck;
  };
  prodTarget: { fingerprint: string; runningRevision: string };
  readiness: {
    status: "ready" | "blocked" | "unavailable";
    responseSha256: string | null;
    observedAt: string;
  };
  evidence: {
    actor: string;
    workflow: string;
    ref: string;
    sha: string;
    runId: string;
    attempt: number;
  };
};

export type ProdEvidenceVerificationContext = {
  expectedSubject: ReleaseSubjectIdentity;
  expectedController: ReleaseControllerIdentity;
  expectedArtifact: { id: string; archiveSha256: string; manifestSha256: string };
  expectedProdTargetFingerprint: string;
  expectedRunningRevision: string;
  expectedEvidence: ProdEvidenceEnvelope["evidence"];
  preflightStartedAt: string;
};

export type ProdEvidenceVerificationResult = {
  eligible: true;
  observedAgeSeconds: number;
  responseSha256: string;
};

const SHA256 = /^[a-f0-9]{64}$/;
const GIT_SHA = /^[a-f0-9]{40}$/;
const RUN_ID = /^[1-9][0-9]*$/;
const OUTCOMES: readonly ReceiptOutcome[] = [
  "success",
  "failed-before-mutation",
  "withheld-dependency",
  "partial",
  "recovered",
  "rollback-failed",
];
const NON_PROMOTABLE = new Set<ReceiptOutcome>([
  "failed-before-mutation",
  "withheld-dependency",
  "partial",
  "recovered",
  "rollback-failed",
]);
const EXPECTED_TARGETS = {
  staging: {
    landing: { pagesProject: "ritual-investing-site-staging", host: "staging.just-build-this.app" },
    demo: { pagesProject: "ritual-investing-demo-staging", host: "demo-staging.just-build-this.app" },
  },
  prod: {
    landing: { pagesProject: "ritual-investing-site", host: "just-build-this.app" },
    demo: { pagesProject: "ritual-investing-demo", host: "demo.just-build-this.app" },
  },
} as const;

function object(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as Record<string, unknown>;
}

function exactKeys(value: Record<string, unknown>, fields: readonly string[], label: string): void {
  const expected = new Set(fields);
  for (const key of Object.keys(value)) if (!expected.has(key)) throw new Error(`Unknown ${label} field: ${key}`);
  for (const key of fields) if (!(key in value)) throw new Error(`Missing ${label} field: ${key}`);
}

function string(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim() === "" || value !== value.trim()) throw new Error(`${label} must be a non-empty trimmed string`);
  return value;
}

function nullableString(value: unknown, label: string): string | null {
  return value === null ? null : string(value, label);
}

function digest(value: unknown, label: string): string {
  if (typeof value !== "string" || !SHA256.test(value)) throw new Error(`${label} must be a lowercase SHA-256 digest`);
  return value;
}

function isoDate(value: unknown, label: string): string {
  const text = string(value, label);
  if (new Date(text).toISOString() !== text) throw new Error(`${label} must be a canonical UTC timestamp`);
  return text;
}

function integer(value: unknown, label: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) throw new Error(`${label} must be a non-negative integer`);
  return value as number;
}

function positiveInteger(value: unknown, label: string): number {
  const result = integer(value, label);
  if (result < 1) throw new Error(`${label} must be greater than zero`);
  return result;
}

function parseState(value: unknown, label: string): { lineage: string; serial: number } {
  const candidate = object(value, label);
  exactKeys(candidate, ["lineage", "serial"], label);
  return { lineage: string(candidate.lineage, `${label} lineage`), serial: integer(candidate.serial, `${label} serial`) };
}

function parseProbe(value: unknown, label: string): DeploymentSurfaceReceipt["probes"][number] {
  const candidate = object(value, label);
  exactKeys(candidate, ["url", "status", "passed", "observedAt"], label);
  const urlText = string(candidate.url, `${label} URL`);
  let url: URL;
  try {
    url = new URL(urlText);
  } catch {
    throw new Error(`${label} URL is invalid`);
  }
  if (url.protocol !== "https:" || url.username !== "" || url.password !== "") throw new Error(`${label} URL must use credential-free HTTPS`);
  const status = integer(candidate.status, `${label} status`);
  if (status < 100 || status > 599) throw new Error(`${label} status is invalid`);
  if (typeof candidate.passed !== "boolean") throw new Error(`${label} passed must be boolean`);
  return { url: urlText, status, passed: candidate.passed, observedAt: isoDate(candidate.observedAt, `${label} observedAt`) };
}

function parseSurface(value: unknown, label: string): DeploymentSurfaceReceipt {
  const candidate = object(value, label);
  exactKeys(candidate, [
    "target", "prior", "attemptedDeploymentId", "resultingDeploymentId", "finalDeploymentId", "probes", "rollback",
  ], label);
  const target = object(candidate.target, `${label} target`);
  exactKeys(target, ["pagesProject", "host"], `${label} target`);
  const host = string(target.host, `${label} target host`);
  if (!/^[a-z0-9.-]+$/.test(host) || host.includes("..")) throw new Error(`${label} target host is invalid`);
  const prior = object(candidate.prior, `${label} prior deployment`);
  exactKeys(prior, ["deploymentId", "artifactDigest"], `${label} prior deployment`);
  const rollback = object(candidate.rollback, `${label} rollback`);
  exactKeys(rollback, ["outcome", "deploymentId"], `${label} rollback`);
  if (!(["not-needed", "not-attempted", "recovered", "failed"] as unknown[]).includes(rollback.outcome)) {
    throw new Error(`${label} rollback outcome is unknown`);
  }
  if (!Array.isArray(candidate.probes)) throw new Error(`${label} probes must be an array`);
  return {
    target: { pagesProject: string(target.pagesProject, `${label} target project`), host },
    prior: {
      deploymentId: nullableString(prior.deploymentId, `${label} prior deployment ID`),
      artifactDigest: prior.artifactDigest === null ? null : digest(prior.artifactDigest, `${label} prior artifact digest`),
    },
    attemptedDeploymentId: nullableString(candidate.attemptedDeploymentId, `${label} attempted deployment ID`),
    resultingDeploymentId: nullableString(candidate.resultingDeploymentId, `${label} resulting deployment ID`),
    finalDeploymentId: nullableString(candidate.finalDeploymentId, `${label} final deployment ID`),
    probes: candidate.probes.map((entry, index) => parseProbe(entry, `${label} probe ${index}`)),
    rollback: {
      outcome: rollback.outcome as RollbackOutcome,
      deploymentId: nullableString(rollback.deploymentId, `${label} rollback deployment ID`),
    },
  };
}

function parseReceipt(value: unknown): DeploymentReceipt {
  const candidate = object(value, "deployment receipt");
  exactKeys(candidate, [
    "schemaVersion", "environment", "artifact", "subject", "controller", "manifestSha256", "releaseDigest",
    "profileIdentity", "infrastructure", "surfaces", "actor", "startedAt", "completedAt", "recoveryOwner",
    "nextAction", "outcome", "eligibility",
  ], "deployment receipt");
  if (candidate.schemaVersion !== 1) throw new Error("Deployment receipt schemaVersion must be 1");
  if (candidate.environment !== "staging" && candidate.environment !== "prod") throw new Error("Deployment receipt environment must be staging or prod");

  const artifact = object(candidate.artifact, "deployment receipt artifact");
  exactKeys(artifact, ["id", "digest", "availability"], "deployment receipt artifact");
  if (!(["retained", "missing", "expired"] as unknown[]).includes(artifact.availability)) {
    throw new Error("Deployment receipt artifact availability is unknown");
  }
  const infrastructure = object(candidate.infrastructure, "deployment receipt infrastructure");
  exactKeys(infrastructure, [
    "terraformPlanDigest", "liveInventoryDigest", "lockProofDigest", "beforeState", "afterState",
  ], "deployment receipt infrastructure");
  const surfaces = object(candidate.surfaces, "deployment receipt surfaces");
  exactKeys(surfaces, ["demo", "landing"], "deployment receipt surfaces");
  const eligibility = object(candidate.eligibility, "deployment receipt eligibility");
  exactKeys(eligibility, ["scope", "promotable", "reasons"], "deployment receipt eligibility");
  if (!(["full", "demo-only", "none"] as unknown[]).includes(eligibility.scope)) throw new Error("Deployment receipt eligibility scope is unknown");
  if (typeof eligibility.promotable !== "boolean") throw new Error("Deployment receipt promotable flag must be boolean");
  if (!Array.isArray(eligibility.reasons) || eligibility.reasons.some((reason) => typeof reason !== "string" || reason.trim() === "")) {
    throw new Error("Deployment receipt eligibility reasons must be non-empty strings");
  }
  if (!(OUTCOMES as readonly unknown[]).includes(candidate.outcome)) throw new Error("Deployment receipt outcome is unknown");
  const startedAt = isoDate(candidate.startedAt, "Deployment receipt startedAt");
  const completedAt = isoDate(candidate.completedAt, "Deployment receipt completedAt");
  if (Date.parse(completedAt) < Date.parse(startedAt)) throw new Error("Deployment receipt time window is reversed");
  return {
    schemaVersion: 1,
    environment: candidate.environment,
    artifact: {
      id: string(artifact.id, "Artifact ID"),
      digest: digest(artifact.digest, "Artifact digest"),
      availability: artifact.availability as ArtifactAvailability,
    },
    subject: parseReleaseSubject(candidate.subject),
    controller: parseReleaseController(candidate.controller),
    manifestSha256: digest(candidate.manifestSha256, "Manifest digest"),
    releaseDigest: digest(candidate.releaseDigest, "Release digest"),
    profileIdentity: string(candidate.profileIdentity, "Profile identity"),
    infrastructure: {
      terraformPlanDigest: digest(infrastructure.terraformPlanDigest, "Terraform plan digest"),
      liveInventoryDigest: digest(infrastructure.liveInventoryDigest, "Live inventory digest"),
      lockProofDigest: digest(infrastructure.lockProofDigest, "Lock proof digest"),
      beforeState: parseState(infrastructure.beforeState, "Before state"),
      afterState: parseState(infrastructure.afterState, "After state"),
    },
    surfaces: { demo: parseSurface(surfaces.demo, "Demo surface"), landing: parseSurface(surfaces.landing, "Landing surface") },
    actor: string(candidate.actor, "Deployment actor"),
    startedAt,
    completedAt,
    recoveryOwner: string(candidate.recoveryOwner, "Recovery owner"),
    nextAction: string(candidate.nextAction, "Next action"),
    outcome: candidate.outcome as ReceiptOutcome,
    eligibility: {
      scope: eligibility.scope as EligibilityScope,
      promotable: eligibility.promotable,
      reasons: [...eligibility.reasons] as string[],
    },
  };
}

function exactIdentity(expected: Record<string, unknown>, actual: Record<string, unknown>, label: string): void {
  for (const [key, value] of Object.entries(expected)) {
    if (actual[key] !== value) throw new Error(`${label} ${key} mismatch`);
  }
}

function parseProdCheck(value: unknown, label: string): { status: ProdCheckStatus } {
  const candidate = object(value, label);
  exactKeys(candidate, ["status"], label);
  if (!(candidate.status === "passed" || candidate.status === "failed" || candidate.status === "blocked")) {
    throw new Error(`${label} status is unknown`);
  }
  return { status: candidate.status };
}

function parseNativeCheck(value: unknown): NativeCheck {
  const candidate = object(value, "Native check");
  exactKeys(candidate, ["availability", "status", "reason"], "Native check");
  if (candidate.availability === "available") {
    if (!(candidate.status === "passed" || candidate.status === "failed" || candidate.status === "blocked")) {
      throw new Error("Available native check status is unknown");
    }
    if (candidate.reason !== null) throw new Error("Available native check must not include an unavailability reason");
    return { availability: "available", status: candidate.status, reason: null };
  }
  if (candidate.availability === "unavailable") {
    if (candidate.status !== "not-run") throw new Error("Unavailable native check must be not-run");
    return {
      availability: "unavailable",
      status: "not-run",
      reason: string(candidate.reason, "Native unavailability reason"),
    };
  }
  throw new Error("Native availability decision is missing or unknown");
}

function parseProdEvidenceEnvelope(value: unknown): ProdEvidenceEnvelope {
  const candidate = object(value, "prod evidence envelope");
  exactKeys(candidate, [
    "schemaVersion", "status", "subject", "controller", "source", "checks", "prodTarget", "readiness", "evidence",
  ], "prod evidence envelope");
  if (candidate.schemaVersion !== "ritual-prod-evidence.v1") {
    throw new Error("Prod evidence schemaVersion must be ritual-prod-evidence.v1");
  }
  if (candidate.status !== "ready" && candidate.status !== "blocked") {
    throw new Error("Prod evidence status must be ready or blocked");
  }

  const source = object(candidate.source, "prod evidence source");
  exactKeys(source, ["runId", "attempt", "artifact"], "prod evidence source");
  const sourceRunId = string(source.runId, "Prod evidence source run ID");
  if (!RUN_ID.test(sourceRunId)) throw new Error("Prod evidence source run ID is invalid");
  const artifact = object(source.artifact, "prod evidence artifact");
  exactKeys(artifact, ["id", "archiveSha256", "manifestSha256"], "prod evidence artifact");
  const artifactId = string(artifact.id, "Prod evidence artifact ID");
  if (!RUN_ID.test(artifactId)) throw new Error("Prod evidence artifact ID is invalid");

  const checks = object(candidate.checks, "prod evidence checks");
  exactKeys(checks, ["rust", "python", "typescript", "docker", "native"], "prod evidence checks");
  const prodTarget = object(candidate.prodTarget, "prod evidence target");
  exactKeys(prodTarget, ["fingerprint", "runningRevision"], "prod evidence target");
  const runningRevision = string(prodTarget.runningRevision, "Prod running revision");
  if (!GIT_SHA.test(runningRevision)) throw new Error("Prod running revision must be a lowercase Git SHA");

  const readiness = object(candidate.readiness, "prod readiness evidence");
  exactKeys(readiness, ["status", "responseSha256", "observedAt"], "prod readiness evidence");
  if (!(readiness.status === "ready" || readiness.status === "blocked" || readiness.status === "unavailable")) {
    throw new Error("Prod readiness status is unknown");
  }

  const evidence = object(candidate.evidence, "prod evidence run");
  exactKeys(evidence, ["actor", "workflow", "ref", "sha", "runId", "attempt"], "prod evidence run");
  const evidenceRef = string(evidence.ref, "Prod evidence ref");
  if (!evidenceRef.startsWith("refs/")) throw new Error("Prod evidence ref must be a full Git ref");
  const evidenceSha = string(evidence.sha, "Prod evidence workflow SHA");
  if (!GIT_SHA.test(evidenceSha)) throw new Error("Prod evidence workflow SHA must be a lowercase Git SHA");
  const evidenceRunId = string(evidence.runId, "Prod evidence run ID");
  if (!RUN_ID.test(evidenceRunId)) throw new Error("Prod evidence run ID is invalid");

  return {
    schemaVersion: "ritual-prod-evidence.v1",
    status: candidate.status,
    subject: parseReleaseSubject(candidate.subject),
    controller: parseReleaseController(candidate.controller),
    source: {
      runId: sourceRunId,
      attempt: positiveInteger(source.attempt, "Prod evidence source attempt"),
      artifact: {
        id: artifactId,
        archiveSha256: digest(artifact.archiveSha256, "Prod evidence archive digest"),
        manifestSha256: digest(artifact.manifestSha256, "Prod evidence manifest digest"),
      },
    },
    checks: {
      rust: parseProdCheck(checks.rust, "Rust check"),
      python: parseProdCheck(checks.python, "Python check"),
      typescript: parseProdCheck(checks.typescript, "TypeScript check"),
      docker: parseProdCheck(checks.docker, "Docker check"),
      native: parseNativeCheck(checks.native),
    },
    prodTarget: {
      fingerprint: digest(prodTarget.fingerprint, "Prod target fingerprint"),
      runningRevision,
    },
    readiness: {
      status: readiness.status,
      responseSha256: readiness.responseSha256 === null
        ? null
        : digest(readiness.responseSha256, "Prod readiness response digest"),
      observedAt: isoDate(readiness.observedAt, "Prod readiness observedAt"),
    },
    evidence: {
      actor: string(evidence.actor, "Prod evidence actor"),
      workflow: string(evidence.workflow, "Prod evidence workflow"),
      ref: evidenceRef,
      sha: evidenceSha,
      runId: evidenceRunId,
      attempt: positiveInteger(evidence.attempt, "Prod evidence attempt"),
    },
  };
}

export function validateProdEvidenceEnvelope(
  value: unknown,
  context: ProdEvidenceVerificationContext,
): ProdEvidenceVerificationResult {
  const envelope = parseProdEvidenceEnvelope(value);
  if (envelope.status !== "ready") throw new Error("Prod evidence status is blocked");
  exactIdentity(context.expectedSubject, envelope.subject, "Release subject");
  exactIdentity(context.expectedController, envelope.controller, "Release controller");
  if (envelope.source.runId !== context.expectedSubject.runId || envelope.source.attempt !== context.expectedSubject.attempt) {
    throw new Error("Prod evidence source run or attempt mismatch");
  }
  if (envelope.source.artifact.id !== context.expectedArtifact.id ||
      envelope.source.artifact.archiveSha256 !== context.expectedArtifact.archiveSha256 ||
      envelope.source.artifact.manifestSha256 !== context.expectedArtifact.manifestSha256) {
    throw new Error("Prod evidence source artifact mismatch");
  }
  for (const [name, check] of Object.entries({
    Rust: envelope.checks.rust,
    Python: envelope.checks.python,
    TypeScript: envelope.checks.typescript,
    Docker: envelope.checks.docker,
  })) {
    if (check.status !== "passed") throw new Error(`${name} prod evidence did not pass`);
  }
  if (envelope.checks.native.availability === "available" && envelope.checks.native.status !== "passed") {
    throw new Error("Available native prod evidence did not pass");
  }
  if (envelope.prodTarget.fingerprint !== context.expectedProdTargetFingerprint) {
    throw new Error("Prod target fingerprint mismatch");
  }
  if (envelope.prodTarget.runningRevision !== context.expectedRunningRevision) {
    throw new Error("Prod running revision mismatch");
  }
  if (envelope.readiness.status !== "ready") throw new Error("Prod readiness status is not ready");
  if (envelope.readiness.responseSha256 === null) throw new Error("Prod readiness response digest is unavailable");
  exactIdentity(context.expectedEvidence, envelope.evidence, "Prod evidence run");

  const preflight = Date.parse(isoDate(context.preflightStartedAt, "Prod preflight startedAt"));
  const observed = Date.parse(envelope.readiness.observedAt);
  const ageMilliseconds = preflight - observed;
  if (ageMilliseconds < 0) throw new Error("Prod readiness observation is from the future");
  if (ageMilliseconds > 15 * 60 * 1000) throw new Error("Prod readiness observation is stale");
  return {
    eligible: true,
    observedAgeSeconds: ageMilliseconds / 1000,
    responseSha256: envelope.readiness.responseSha256,
  };
}

function validateOutcome(receipt: DeploymentReceipt): void {
  const { outcome, eligibility, artifact, surfaces } = receipt;
  if (receipt.infrastructure.beforeState.lineage !== receipt.infrastructure.afterState.lineage ||
      receipt.infrastructure.afterState.serial < receipt.infrastructure.beforeState.serial) {
    throw new Error("Deployment receipt state lineage or serial moved backwards");
  }
  for (const surfaceName of ["demo", "landing"] as const) {
    const surface = surfaces[surfaceName];
    const expected = EXPECTED_TARGETS[receipt.environment][surfaceName];
    if (surface.target.pagesProject !== expected.pagesProject || surface.target.host !== expected.host) {
      throw new Error(`${receipt.environment} ${surfaceName} receipt target does not match the reviewed profile`);
    }
    if (receipt.environment === "prod" &&
        (surface.prior.deploymentId === null) !== (surface.prior.artifactDigest === null)) {
      throw new Error(`Prod ${surfaceName} prior deployment ID and artifact digest must be recorded together`);
    }
    if (surface.probes.some(({ url }) => new URL(url).hostname !== surface.target.host)) {
      throw new Error(`${receipt.environment} ${surfaceName} probe escaped its exact target host`);
    }
  }
  if (NON_PROMOTABLE.has(outcome) && (eligibility.promotable || eligibility.scope === "full")) {
    throw new Error(`${outcome} evidence cannot be promotable or full`);
  }
  if (eligibility.promotable ? eligibility.reasons.length !== 0 : eligibility.reasons.length === 0) {
    throw new Error("Deployment receipt eligibility reasons do not match its promotable state");
  }
  if (outcome === "success") {
    if (!eligibility.promotable || eligibility.scope !== "full") throw new Error("Successful deployment must be a full promotable receipt");
    for (const [name, surface] of Object.entries(surfaces)) {
      if (surface.attemptedDeploymentId === null || surface.resultingDeploymentId === null || surface.finalDeploymentId === null ||
          surface.probes.length === 0 || surface.probes.some(({ passed }) => !passed)) {
        throw new Error(`Successful ${name} deployment requires final IDs and passing probes`);
      }
    }
  }
  if (artifact.availability !== "retained") {
    if (outcome !== "failed-before-mutation" || eligibility.promotable || eligibility.scope !== "none" ||
        receipt.nextAction !== "create-new-main-release") {
      throw new Error("Missing or expired artifact is non-reconstructable and requires create-new-main-release");
    }
    for (const surface of Object.values(surfaces)) {
      if (surface.attemptedDeploymentId !== null || surface.resultingDeploymentId !== null || surface.probes.length !== 0) {
        throw new Error("Unavailable artifact receipt must prove failure before mutation");
      }
    }
  } else if (outcome === "failed-before-mutation") {
    if (receipt.nextAction === "create-new-main-release") {
      throw new Error("Retained artifact must not be reported as expired or missing");
    }
    for (const surface of Object.values(surfaces)) {
      if (surface.attemptedDeploymentId !== null || surface.resultingDeploymentId !== null || surface.probes.length !== 0) {
        throw new Error("Failure-before-mutation receipt cannot contain mutation or probe evidence");
      }
    }
  }
  if (outcome === "withheld-dependency") {
    const landing = surfaces.landing;
    if (eligibility.scope !== "demo-only" || landing.attemptedDeploymentId !== null ||
        landing.resultingDeploymentId !== null || landing.finalDeploymentId !== landing.prior.deploymentId ||
        landing.probes.length !== 0 || landing.rollback.outcome !== "not-attempted") {
      throw new Error("Withheld dependency receipt must leave landing unmodified and unprobed");
    }
  }
  if (outcome === "recovered" && !Object.values(surfaces).some((surface) =>
    surface.rollback.outcome === "recovered" &&
    surface.rollback.deploymentId === surface.prior.deploymentId &&
    surface.finalDeploymentId === surface.prior.deploymentId
  )) {
    throw new Error("Recovered outcome requires a recovered rollback record");
  }
  if (outcome === "rollback-failed" && !Object.values(surfaces).some(({ rollback }) => rollback.outcome === "failed")) {
    throw new Error("Rollback-failed outcome requires a failed rollback record");
  }
}

export function validateDeploymentReceipt(
  value: unknown,
  context: ReceiptVerificationContext,
): ReceiptVerificationResult {
  const receipt = parseReceipt(value);
  exactIdentity(context.expectedSubject, receipt.subject, "Release subject");
  exactIdentity(context.expectedController, receipt.controller, "Release controller");
  if (receipt.manifestSha256 !== context.expectedManifestSha256) throw new Error("Manifest digest mismatch");
  if (receipt.releaseDigest !== context.expectedReleaseDigest || receipt.artifact.digest !== context.expectedReleaseDigest) {
    throw new Error("Release artifact digest mismatch");
  }
  if (receipt.environment === "prod" && receipt.outcome === "success" &&
      receipt.eligibility.scope === "full" && !context.prodLandingEligible) {
    throw new Error("Prod landing remains withheld because no approved prod target is configured");
  }
  validateOutcome(receipt);
  return {
    promotable: receipt.eligibility.promotable,
    reconstructable: receipt.artifact.availability === "retained",
    scope: receipt.eligibility.scope,
  };
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const prodEvidenceMode = process.argv[2] === "--prod-evidence";
    const receiptPath = process.argv[prodEvidenceMode ? 3 : 2];
    const contextJson = process.env[prodEvidenceMode
      ? "PROD_EVIDENCE_VERIFICATION_CONTEXT"
      : "RELEASE_VERIFICATION_CONTEXT"];
    if (receiptPath === undefined || contextJson === undefined) {
      throw new Error(prodEvidenceMode
        ? "Usage: PROD_EVIDENCE_VERIFICATION_CONTEXT='<json>' verify-deployment-receipt.ts --prod-evidence <evidence.json>"
        : "Usage: RELEASE_VERIFICATION_CONTEXT='<json>' verify-deployment-receipt.ts <receipt.json>");
    }
    const value: unknown = JSON.parse(await readFile(receiptPath, "utf8"));
    const result = prodEvidenceMode
      ? validateProdEvidenceEnvelope(value, JSON.parse(contextJson) as ProdEvidenceVerificationContext)
      : validateDeploymentReceipt(value, JSON.parse(contextJson) as ReceiptVerificationContext);
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Deployment receipt verification failed");
    process.exitCode = 1;
  }
}
