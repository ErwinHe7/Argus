import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";
import { parse } from "yaml";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const ordinaryWorkflowPath = resolve(
  repositoryRoot,
  ".github/workflows/ritual-investing-ci.yml",
);
const remediationWorkflowPath = resolve(
  repositoryRoot,
  ".github/workflows/ritual-investing-supabase-remediation.yml",
);
const promotionManifestPath = resolve(
  repositoryRoot,
  "docs/ritual-investing/supabase-promotion-manifest.md",
);
const recoveryCoveragePath = resolve(
  repositoryRoot,
  "docs/ritual-investing/supabase-recovery-coverage.md",
);

type WorkflowStep = Readonly<{
  name?: string;
  run?: string;
  uses?: string;
  with?: unknown;
  env?: unknown;
}>;

type WorkflowJob = Readonly<{
  environment?: string | Readonly<{ name?: string }>;
  concurrency?: Readonly<{
    group?: string;
    "cancel-in-progress"?: boolean;
  }>;
  steps?: readonly WorkflowStep[];
}>;

type Workflow = Readonly<{
  on?: Readonly<Record<string, unknown>>;
  concurrency?: Readonly<{
    group?: string;
    "cancel-in-progress"?: boolean;
  }>;
  jobs?: Readonly<Record<string, WorkflowJob>>;
}>;

function optionalText(path: string): string {
  return existsSync(path) ? readFileSync(path, "utf8") : "";
}

function parsedWorkflow(source: string): Workflow {
  return (parse(source) ?? {}) as Workflow;
}

const runText = (step: WorkflowStep): string => step.run ?? "";

function promotionJob(workflow: Workflow): WorkflowJob | undefined {
  return Object.values(workflow.jobs ?? {}).find((job) =>
    (job.steps ?? []).some((step) =>
      /supabase\s+db\s+push|supabase\s+functions\s+deploy/.test(runText(step))
    )
  );
}

function firstStep(steps: readonly WorkflowStep[], pattern: RegExp): number {
  return steps.findIndex((step) => pattern.test(runText(step)));
}

const ordinarySource = optionalText(ordinaryWorkflowPath);
const remediationSource = optionalText(remediationWorkflowPath);
const ordinary = parsedWorkflow(ordinarySource);
const remediation = parsedWorkflow(remediationSource);
const manifest = optionalText(promotionManifestPath);
const recoveryCoverage = optionalText(recoveryCoveragePath);

describe("U9 protected Supabase promotion contract", () => {
  it("keeps the ordinary CI workflow read-only against hosted Supabase", () => {
    expect(ordinarySource).not.toMatch(
      /supabase-hosted-development|supabase\s+(?:link|db\s+(?:push|repair)|functions\s+deploy)|psql[^\n]*SUPABASE_DB_URL|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD/,
    );
    expect(ordinarySource).not.toMatch(
      /github\.event_name\s*==\s*['"]push['"][\s\S]{0,500}(?:db\s+push|functions\s+deploy|fence-supabase-deployment)/,
    );
  });

  it("runs ordinary CI when the remediation workflow changes", () => {
    for (const eventName of ["pull_request", "push"] as const) {
      const trigger = ordinary.on?.[eventName] as
        | Readonly<{ paths?: readonly string[] }>
        | undefined;
      expect(trigger?.paths, `${eventName} paths`).toEqual(
        expect.arrayContaining([
          ".github/workflows/ritual-investing-supabase-remediation.yml",
        ]),
      );
    }
  });

  it("provides one manual-only protected and non-canceling remediation path", () => {
    expect(existsSync(remediationWorkflowPath), remediationWorkflowPath).toBe(
      true,
    );
    expect(Object.keys(remediation.on ?? {})).toEqual(["workflow_dispatch"]);

    const job = promotionJob(remediation);
    expect(job, "missing hosted promotion job").toBeDefined();
    const environment = typeof job?.environment === "string"
      ? job.environment
      : job?.environment?.name;
    expect(environment).toBe("ritual-supabase-remediation");

    const concurrency = job?.concurrency ?? remediation.concurrency;
    expect(concurrency?.group).toMatch(
      /supabase.*remediation|remediation.*supabase/,
    );
    expect(concurrency?.["cancel-in-progress"]).toBe(false);
  });

  it("defines an immutable manifest and recovery contract for every bound input", () => {
    expect(existsSync(promotionManifestPath), promotionManifestPath).toBe(
      true,
    );
    expect(existsSync(recoveryCoveragePath), recoveryCoveragePath).toBe(
      true,
    );

    for (
      const [label, pattern] of Object.entries({
        contractVersion: /contract[_ -]version/i,
        projectIdentity: /project[_ -](?:id|ref)|project identity/i,
        branchIdentity: /branch[_ -](?:name|ref)|branch identity/i,
        gitRevision: /git[_ -](?:revision|sha)|GITHUB_SHA/i,
        migrationChecksums: /migration[_ -]checksums?/i,
        targetFingerprint: /target[_ -]fingerprint|schema[_ -]fingerprint/i,
        captureTime: /captur(?:e|ed)[_ -](?:at|time)/i,
        inventory: /inventory/i,
        roles: /roles?/i,
        managedResources: /managed[_ -]resources?/i,
        backup: /backup[_ -](?:id|identifier)|backup/i,
        restoreDrill: /restore[_ -]drill/i,
        gateResults: /gate[_ -]results?|test evidence/i,
        recoveryCoverage: /recovery[_ -]coverage/i,
        releaseApproval: /release[_ -](?:approval|commander)/i,
        recoveryApproval: /recovery[_ -](?:approval|owner)/i,
        securityApproval: /security[_ -](?:approval|approver)/i,
        trafficAdmission: /traffic[_ -]admission|maintenance[_ -]gate/i,
        fenceStates:
          /background_workers[\s\S]*provider_egress[\s\S]*order_mutations/i,
      })
    ) {
      expect(manifest, `promotion manifest is missing ${label}`).toMatch(
        pattern,
      );
    }
    expect(manifest).toMatch(/immutable|any bound change invalidates/i);
    expect(recoveryCoverage).toMatch(
      /database[\s\S]*Auth[\s\S]*Storage[\s\S]*queues?[\s\S]*Cron[\s\S]*roles?[\s\S]*Vault[\s\S]*Edge secrets?[\s\S]*functions?/i,
    );
    expect(recoveryCoverage).toMatch(
      /restorable[\s\S]*reconstructable[\s\S]*disposable[\s\S]*fix-forward-only/i,
    );
  });

  it("revalidates every manifest binding before the first fence or mutation", () => {
    const steps = promotionJob(remediation)?.steps ?? [];
    const firstDanger = firstStep(
      steps,
      /fence-supabase-deployment|supabase\s+db\s+(?:push|reset|repair)|supabase\s+functions\s+deploy|\bupdate\s+argus_private\.kill_switches/i,
    );
    expect(firstDanger, "missing fence or hosted mutation")
      .toBeGreaterThanOrEqual(0);
    const preMutation = steps.slice(0, firstDanger).map(runText).join("\n");

    for (
      const [label, pattern] of Object.entries({
        manifest: /supabase-promotion-manifest/i,
        exactTarget: /check-supabase-deploy-target|exact target/i,
        revision: /RITUAL_SOURCE_SHA|git revision/i,
        migrationChecksum: /migration checksum|migration-inventory/i,
        fingerprint: /fingerprint/i,
        inventory: /inventory/i,
        recovery: /recovery/i,
        approval: /approval|approver/i,
      })
    ) {
      expect(preMutation, `${label} is not rebound before mutation`).toMatch(
        pattern,
      );
    }
  });

  it("fences first and proves both mixed-version states in order", () => {
    const steps = promotionJob(remediation)?.steps ?? [];
    const fence = firstStep(
      steps,
      /fence-supabase-deployment|fence external effects/i,
    );
    const schema = firstStep(steps, /supabase\s+db\s+push/);
    const oldEdge = firstStep(steps, /--old-edge-new-schema/);
    const edge = firstStep(steps, /supabase\s+functions\s+deploy/);
    const newEdge = firstStep(steps, /--new-edge-new-schema/);

    expect(fence).toBeGreaterThanOrEqual(0);
    expect(schema).toBeGreaterThan(fence);
    expect(oldEdge).toBeGreaterThan(schema);
    expect(edge).toBeGreaterThan(oldEdge);
    expect(newEdge).toBeGreaterThan(edge);
  });

  it("records the complete observation window without broadly resuming financial fences", () => {
    for (
      const checkpoint of [
        /\bimmediate\b/i,
        /\+1\s*(?:hour|h)\b/i,
        /\+4\s*(?:hours?|h)\b/i,
        /\+24\s*(?:hours?|h)\b/i,
      ]
    ) {
      expect(manifest, `missing observation checkpoint ${checkpoint}`).toMatch(
        checkpoint,
      );
    }
    expect(remediationSource).toMatch(/actions\/upload-artifact@/);
    expect(remediationSource).toMatch(
      /observation[^\n]*(?:artifact|evidence)|(?:artifact|evidence)[^\n]*observation/i,
    );
    expect(manifest).toMatch(/observation[_ -](?:artifact|evidence)/i);

    const resumeSteps = (promotionJob(remediation)?.steps ?? [])
      .map(runText)
      .filter((source) => /resume|unfence|enabled\s*=\s*false/i.test(source));
    for (const source of resumeSteps) {
      expect(source).not.toMatch(/provider_egress|order_mutations/);
      expect(source).toMatch(/background_workers/);
    }
  });
});
