import { describe, expect, it } from "vitest";

import {
  validateDeploymentReceipt,
  type DeploymentReceipt,
  type DeploymentSurfaceReceipt,
  type ReceiptVerificationContext,
} from "../../scripts/release/verify-deployment-receipt.ts";

const SUBJECT_SHA = "a".repeat(40);
const CONTROLLER_SHA = "b".repeat(40);
const DIGEST = "c".repeat(64);
const OTHER_DIGEST = "d".repeat(64);

const context: ReceiptVerificationContext = {
  expectedSubject: { repository: "owner/argus", sha: SUBJECT_SHA, runId: "101", attempt: 1 },
  expectedController: {
    workflow: "ritual-release.yml",
    ref: "refs/heads/main",
    sha: CONTROLLER_SHA,
    runId: "202",
    attempt: 2,
  },
  expectedManifestSha256: DIGEST,
  expectedReleaseDigest: OTHER_DIGEST,
  expectedProfileIdentity: "ritual-release-staging-v1",
  prodLandingEligible: true,
};

function surface(name: "landing" | "demo"): DeploymentSurfaceReceipt {
  const host = name === "landing" ? "staging.just-build-this.app" : "demo-staging.just-build-this.app";
  const pagesProject = name === "landing"
    ? "ritual-investing-site-staging"
    : "ritual-investing-demo-staging";
  return {
    target: { pagesProject, host },
    prior: { deploymentId: `${name}-prior`, artifactDigest: "e".repeat(64) },
    attemptedDeploymentId: `${name}-attempted`,
    resultingDeploymentId: `${name}-resulting`,
    finalDeploymentId: `${name}-resulting`,
    probes: [{
      url: `https://${host}/`,
      status: 200,
      passed: true,
      observedAt: "2026-08-30T18:00:02.000Z",
    }],
    rollback: { outcome: "not-needed", deploymentId: null },
  };
}

function receipt(): DeploymentReceipt {
  return {
    schemaVersion: 1,
    environment: "staging",
    artifact: { id: "artifact-303", digest: OTHER_DIGEST, availability: "retained" },
    subject: context.expectedSubject,
    controller: context.expectedController,
    manifestSha256: DIGEST,
    releaseDigest: OTHER_DIGEST,
    profileIdentity: "ritual-release-staging-v1",
    infrastructure: {
      terraformPlanDigest: "1".repeat(64),
      liveInventoryDigest: "2".repeat(64),
      lockProofDigest: "3".repeat(64),
      beforeState: { lineage: "staging-lineage", serial: 7 },
      afterState: { lineage: "staging-lineage", serial: 8 },
    },
    surfaces: { demo: surface("demo"), landing: surface("landing") },
    actor: "release-operator",
    startedAt: "2026-08-30T18:00:00.000Z",
    completedAt: "2026-08-30T18:00:03.000Z",
    recoveryOwner: "release-operations",
    nextAction: "none",
    outcome: "success",
    eligibility: { scope: "full", promotable: true, reasons: [] },
  };
}

describe("deployment receipt contract", () => {
  it("accepts a complete successful receipt only with exact subject and controller provenance", () => {
    expect(validateDeploymentReceipt(receipt(), context)).toEqual({
      promotable: true,
      reconstructable: true,
      scope: "full",
    });

    const wrongController = receipt();
    wrongController.controller = { ...wrongController.controller, runId: "999" };
    expect(() => validateDeploymentReceipt(wrongController, context)).toThrow(/controller.*run/i);

    const unknown = { ...receipt(), extra: true };
    expect(() => validateDeploymentReceipt(unknown, context)).toThrow(/unknown/i);

    const wrongProfile = receipt();
    wrongProfile.profileIdentity = "ritual-release-prod-withheld-v1";
    expect(() => validateDeploymentReceipt(wrongProfile, context)).toThrow(/profile identity/i);
  });

  it.each(["withheld-dependency", "partial", "recovered", "rollback-failed"] as const)(
    "accepts %s as evidence but never as promotable",
    (outcome) => {
      const candidate = receipt();
      candidate.outcome = outcome;
      candidate.eligibility = { scope: outcome === "withheld-dependency" ? "demo-only" : "none", promotable: false, reasons: [outcome] };
      candidate.surfaces.landing.probes[0]!.passed = false;
      if (outcome === "withheld-dependency") {
        candidate.surfaces.landing.attemptedDeploymentId = null;
        candidate.surfaces.landing.resultingDeploymentId = null;
        candidate.surfaces.landing.finalDeploymentId = candidate.surfaces.landing.prior.deploymentId;
        candidate.surfaces.landing.probes = [];
        candidate.surfaces.landing.rollback = { outcome: "not-attempted", deploymentId: null };
      } else if (outcome === "recovered") {
        candidate.surfaces.landing.finalDeploymentId = candidate.surfaces.landing.prior.deploymentId;
        candidate.surfaces.landing.rollback = {
          outcome: "recovered",
          deploymentId: candidate.surfaces.landing.prior.deploymentId,
        };
      } else if (outcome === "rollback-failed") {
        candidate.surfaces.landing.rollback = { outcome: "failed", deploymentId: null };
      }

      expect(validateDeploymentReceipt(candidate, context)).toMatchObject({ promotable: false });
    },
  );

  it("rejects partial evidence falsely marked promotable or full", () => {
    const candidate = receipt();
    candidate.outcome = "partial";
    candidate.surfaces.landing.probes[0]!.passed = false;
    expect(() => validateDeploymentReceipt(candidate, context)).toThrow(/promotable|full/i);
  });

  it("rejects cross-environment targets and backwards state evidence", () => {
    const wrongTarget = receipt();
    wrongTarget.surfaces.landing.target.host = "just-build-this.app";
    expect(() => validateDeploymentReceipt(wrongTarget, context)).toThrow(/reviewed profile/i);

    const backwardsState = receipt();
    backwardsState.infrastructure.afterState.serial = 6;
    expect(() => validateDeploymentReceipt(backwardsState, context)).toThrow(/state lineage|serial/i);
  });

  it.each(["missing", "expired"] as const)(
    "reports a %s artifact as non-reconstructable and requires a new main release",
    (availability) => {
      const candidate = receipt();
      candidate.artifact = { id: "artifact-303", digest: OTHER_DIGEST, availability };
      candidate.outcome = "failed-before-mutation";
      candidate.eligibility = { scope: "none", promotable: false, reasons: [availability] };
      candidate.nextAction = "create-new-main-release";
      candidate.surfaces.demo.attemptedDeploymentId = null;
      candidate.surfaces.demo.resultingDeploymentId = null;
      candidate.surfaces.demo.finalDeploymentId = candidate.surfaces.demo.prior.deploymentId;
      candidate.surfaces.demo.probes = [];
      candidate.surfaces.landing.attemptedDeploymentId = null;
      candidate.surfaces.landing.resultingDeploymentId = null;
      candidate.surfaces.landing.finalDeploymentId = candidate.surfaces.landing.prior.deploymentId;
      candidate.surfaces.landing.probes = [];

      expect(validateDeploymentReceipt(candidate, context)).toEqual({
        promotable: false,
        reconstructable: false,
        scope: "none",
      });
    },
  );

  it("rejects full prod success when the prod landing profile is withheld", () => {
    const candidate = receipt();
    candidate.environment = "prod";
    candidate.surfaces.landing.target = {
      pagesProject: "ritual-investing-site",
      host: "just-build-this.app",
    };
    candidate.surfaces.landing.probes[0]!.url = "https://just-build-this.app/";
    candidate.surfaces.demo.target = {
      pagesProject: "ritual-investing-demo",
      host: "demo.just-build-this.app",
    };
    candidate.surfaces.demo.probes[0]!.url = "https://demo.just-build-this.app/";
    expect(() => validateDeploymentReceipt(candidate, { ...context, prodLandingEligible: false }))
      .toThrow(/approved prod target|withheld/i);
  });

  it("rejects any prior deployment without its exact artifact digest", () => {
    const candidate = receipt();
    candidate.surfaces.demo.prior.artifactDigest = null;

    expect(() => validateDeploymentReceipt(candidate, context))
      .toThrow(/prior deployment ID and artifact digest/i);
  });
});
