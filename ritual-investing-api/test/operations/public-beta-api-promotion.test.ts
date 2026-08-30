import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";
import { parse } from "yaml";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const workflowPath = resolve(
  repositoryRoot,
  ".github/workflows/ritual-investing-supabase-remediation.yml",
);

type WorkflowStep = Readonly<{
  name?: string;
  run?: string;
  uses?: string;
  with?: Readonly<Record<string, unknown>>;
}>;
type WorkflowJob = Readonly<{
  env?: Readonly<Record<string, unknown>>;
  steps?: readonly WorkflowStep[];
}>;
type Workflow = Readonly<{ jobs?: Readonly<Record<string, WorkflowJob>> }>;

const workflow = (parse(readFileSync(workflowPath, "utf8")) ?? {}) as Workflow;
const promotion = Object.values(workflow.jobs ?? {}).find((job) =>
  (job.steps ?? []).some((step) => /supabase functions deploy api/.test(step.run ?? ""))
);
const steps = promotion?.steps ?? [];
const runText = steps.map((step) => step.run ?? "").join("\n");

describe("public-beta API promotion evidence", () => {
  it("binds the protected job to the dedicated beta target and exact web origins", () => {
    expect(promotion?.env).toMatchObject({
      RITUAL_EXPECTED_BETA_PROJECT_ID: expect.any(String),
      RITUAL_BETA_ADMIN_ORIGIN: expect.any(String),
      RITUAL_BETA_PREVIEW_ORIGIN: expect.any(String),
    });
    expect(runText).toContain(
      "RITUAL_BETA_CONSUMER_ORIGINS=https://just-build-this.app,$RITUAL_BETA_PREVIEW_ORIGIN",
    );
    expect(runText).toContain("workers\\.dev");
    expect(runText).toMatch(
      /SUPABASE_PROJECT_ID[^\n]*RITUAL_EXPECTED_BETA_PROJECT_ID/,
    );
  });

  it("deploys and records the exact origin, admission, project, and revision bindings", () => {
    expect(runText).toMatch(
      /ARGUS_CONSUMER_ORIGINS=.*RITUAL_BETA_CONSUMER_ORIGINS/,
    );
    expect(runText).toMatch(/ARGUS_ADMIN_ORIGIN=.*RITUAL_BETA_ADMIN_ORIGIN/);
    expect(runText).toMatch(/ARGUS_WEB_ADMISSION=.*RITUAL_BETA_WEB_ADMISSION/);
    expect(runText).toMatch(/public-beta-api-evidence\.txt/);

    const upload = steps.find((step) => step.uses === "actions/upload-artifact@v4");
    expect(String(upload?.with?.path ?? "")).toContain(
      "public-beta-api-evidence.txt",
    );
  });
});
