import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import {
  validateProdEvidenceEnvelope,
  type ProdEvidenceEnvelope,
  type ProdEvidenceVerificationContext,
} from "../../scripts/release/verify-deployment-receipt.ts";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const SHA = "a".repeat(40);
const CONTROLLER_SHA = "b".repeat(40);
const ARCHIVE_SHA256 = "c".repeat(64);
const MANIFEST_SHA256 = "d".repeat(64);
const RESPONSE_SHA256 = "e".repeat(64);
const TARGET_FINGERPRINT = "f".repeat(64);
const PREFLIGHT_STARTED_AT = "2026-08-31T18:15:00.000Z";

const context: ProdEvidenceVerificationContext = {
  expectedSubject: { repository: "owner/argus", sha: SHA, runId: "101", attempt: 2 },
  expectedController: {
    workflow: "Ritual Investing Fast CI",
    ref: "refs/heads/main",
    sha: SHA,
    runId: "101",
    attempt: 2,
  },
  expectedArtifact: {
    id: "303",
    archiveSha256: ARCHIVE_SHA256,
    manifestSha256: MANIFEST_SHA256,
  },
  expectedProdTargetFingerprint: TARGET_FINGERPRINT,
  expectedRunningRevision: SHA,
  expectedEvidence: {
    actor: "release-operator",
    workflow: "Ritual Investing Manual Release Evidence",
    ref: "refs/heads/main",
    sha: CONTROLLER_SHA,
    runId: "404",
    attempt: 1,
  },
  preflightStartedAt: PREFLIGHT_STARTED_AT,
};

function envelope(): ProdEvidenceEnvelope {
  return {
    schemaVersion: "ritual-prod-evidence.v1",
    status: "ready",
    subject: context.expectedSubject,
    controller: context.expectedController,
    source: {
      runId: "101",
      attempt: 2,
      artifact: {
        id: "303",
        archiveSha256: ARCHIVE_SHA256,
        manifestSha256: MANIFEST_SHA256,
      },
    },
    checks: {
      rust: { status: "passed" },
      python: { status: "passed" },
      typescript: { status: "passed" },
      docker: { status: "passed" },
      native: { availability: "available", status: "passed", reason: null },
    },
    prodTarget: {
      fingerprint: TARGET_FINGERPRINT,
      runningRevision: SHA,
    },
    readiness: {
      status: "ready",
      responseSha256: RESPONSE_SHA256,
      observedAt: "2026-08-31T18:05:00.000Z",
    },
    evidence: {
      actor: "release-operator",
      workflow: "Ritual Investing Manual Release Evidence",
      ref: "refs/heads/main",
      sha: CONTROLLER_SHA,
      runId: "404",
      attempt: 1,
    },
  };
}

describe("prod evidence envelope", () => {
  it("accepts one exact ready release observed within the 15-minute preflight window", () => {
    expect(validateProdEvidenceEnvelope(envelope(), context)).toEqual({
      eligible: true,
      observedAgeSeconds: 600,
      responseSha256: RESPONSE_SHA256,
    });

    const nativeUnavailable = envelope();
    nativeUnavailable.checks.native = {
      availability: "unavailable",
      status: "not-run",
      reason: "cmake-not-installed-on-runner",
    };
    expect(validateProdEvidenceEnvelope(nativeUnavailable, context).eligible).toBe(true);
  });

  it.each([
    ["blocked envelope", (candidate: ProdEvidenceEnvelope) => { candidate.status = "blocked"; }],
    ["blocked readiness", (candidate: ProdEvidenceEnvelope) => { candidate.readiness.status = "blocked"; }],
    ["unavailable readiness", (candidate: ProdEvidenceEnvelope) => { candidate.readiness.status = "unavailable"; }],
    ["failed Rust", (candidate: ProdEvidenceEnvelope) => { candidate.checks.rust.status = "failed"; }],
    ["wrong target", (candidate: ProdEvidenceEnvelope) => { candidate.prodTarget.fingerprint = "0".repeat(64); }],
    ["wrong revision", (candidate: ProdEvidenceEnvelope) => { candidate.prodTarget.runningRevision = "9".repeat(40); }],
    ["wrong artifact", (candidate: ProdEvidenceEnvelope) => { candidate.source.artifact.archiveSha256 = "8".repeat(64); }],
    ["wrong run attempt", (candidate: ProdEvidenceEnvelope) => { candidate.source.attempt = 3; }],
  ])("rejects %s", (_label, mutate) => {
    const candidate = envelope();
    mutate(candidate);
    expect(() => validateProdEvidenceEnvelope(candidate, context)).toThrow();
  });

  it("rejects stale and future observations at prod preflight", () => {
    const stale = envelope();
    stale.readiness.observedAt = "2026-08-31T17:59:59.999Z";
    expect(() => validateProdEvidenceEnvelope(stale, context)).toThrow(/stale/i);

    const future = envelope();
    future.readiness.observedAt = "2026-08-31T18:15:00.001Z";
    expect(() => validateProdEvidenceEnvelope(future, context)).toThrow(/future/i);
  });

  it("fails closed when the native availability decision or response digest is missing", () => {
    const missingNative = structuredClone(envelope()) as unknown as Record<string, unknown>;
    delete (missingNative.checks as Record<string, unknown>).native;
    expect(() => validateProdEvidenceEnvelope(missingNative, context)).toThrow(/native/i);

    const unavailable = structuredClone(envelope()) as unknown as Record<string, unknown>;
    (unavailable.readiness as Record<string, unknown>).responseSha256 = null;
    expect(() => validateProdEvidenceEnvelope(unavailable, context)).toThrow(/response/i);
  });

  it("binds the evidence actor and exact evidence run", () => {
    const wrongActor = envelope();
    wrongActor.evidence.actor = "someone-else";
    expect(() => validateProdEvidenceEnvelope(wrongActor, context)).toThrow(/evidence.*actor/i);
  });

  it("resolves every executable project-contract path and preserves the checked-in NO-GO", async () => {
    const [contract, workflow, evidenceLog] = await Promise.all([
      readFile(resolve(repositoryRoot, "axio7-model-review/PROJECT_CONTRACT.md"), "utf8"),
      readFile(resolve(repositoryRoot, ".github/workflows/ritual-investing-release-evidence.yml"), "utf8"),
      readFile(resolve(repositoryRoot, "axio7-model-review/reference-docs/production-quant-inference.md"), "utf8"),
    ]);

    for (const path of [
      "axio7-model-review/source/quant_engine_rs",
      "axio7-model-review/source/intraday_quant",
      "axio7-model-review/source/quant_core_cpp",
      "axio7-model-review/apps/spy-price-demo",
      "axio7-model-review/source/quant_engine_rs/Dockerfile",
      ".github/workflows/ci.yml",
      "axio7-model-review/reference-docs/production-quant-inference.md",
    ]) expect(contract).toContain(path);
    expect(workflow).toContain("ritual-prod-evidence.v1");
    expect(workflow).toMatch(/on:\n\s+workflow_dispatch:/);
    expect(workflow).not.toMatch(/\n  (push|pull_request|workflow_run):/);
    for (const evidence of [
      "cargo clippy --all-targets --locked -- -D warnings",
      "cargo test --locked",
      "python -m pytest --basetemp .pytest-tmp -p no:cacheprovider",
      "working-directory: axio7-model-review/apps/spy-price-demo",
      "file: axio7-model-review/source/quant_engine_rs/Dockerfile",
      "Record the native toolchain availability decision",
      "environment: prod",
      "url.pathname !== \"/api/v1/system/readiness\"",
      "test \"$running_revision\" = \"$SOURCE_SHA\"",
      "--prod-evidence \"$RUNNER_TEMP/prod-evidence.json\"",
    ]) expect(workflow).toContain(evidence);
    expect(evidenceLog).toMatch(/production_ready=false/);
    expect(evidenceLog).toMatch(/NO-GO/);
  });
});
