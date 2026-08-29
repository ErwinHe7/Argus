import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";
import { parse } from "yaml";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const workflowPath = resolve(
  repositoryRoot,
  ".github/workflows/ritual-investing-supabase-remediation.yml",
);
const hostedAcceptancePath = resolve(
  repositoryRoot,
  "scripts/check-supabase-hosted-acceptance.sh",
);

type WorkflowStep = Readonly<{
  name?: string;
  run?: string;
  uses?: string;
  with?: unknown;
  env?: unknown;
}>;

type WorkflowJob = Readonly<{ steps?: readonly WorkflowStep[] }>;
type Workflow = Readonly<{ jobs?: Readonly<Record<string, WorkflowJob>> }>;

const runText = (step: WorkflowStep): string => step.run ?? "";

function promotionSteps(): readonly WorkflowStep[] {
  if (!existsSync(workflowPath)) return [];
  const workflow = (parse(readFileSync(workflowPath, "utf8")) ??
    {}) as Workflow;
  return Object.values(workflow.jobs ?? {}).find((job) =>
    (job.steps ?? []).some((step) =>
      /supabase\s+test\s+db\s+--linked|check-supabase-hosted-acceptance/.test(
        runText(step),
      )
    )
  )?.steps ?? [];
}

function firstStep(steps: readonly WorkflowStep[], pattern: RegExp): number {
  return steps.findIndex((step) => pattern.test(runText(step)));
}

function matchingSteps(
  steps: readonly WorkflowStep[],
  pattern: RegExp,
): number[] {
  return steps.flatMap((step, index) =>
    pattern.test(runText(step)) ? [index] : []
  );
}

describe("U9 hosted fixture safety contract", () => {
  it("runs every hosted behavior suite while all external effects remain fenced", () => {
    const steps = promotionSteps();
    const fence = firstStep(
      steps,
      /fence-supabase-deployment|fence external effects/i,
    );
    const hostedTests = matchingSteps(
      steps,
      /supabase\s+test\s+db\s+--linked|check-supabase-hosted-acceptance|hosted (?:test|acceptance)/i,
    );
    const firstResume = firstStep(
      steps,
      /resume|unfence|enabled\s*=\s*false/i,
    );

    expect(fence).toBeGreaterThanOrEqual(0);
    expect(
      readFileSync(
        resolve(repositoryRoot, "scripts/fence-supabase-deployment.sql"),
        "utf8",
      ),
    ).toMatch(
      /background_workers[\s\S]*provider_egress[\s\S]*order_mutations/i,
    );
    expect(hostedTests.length).toBeGreaterThan(0);
    for (const testIndex of hostedTests) {
      expect(testIndex).toBeGreaterThan(fence);
      if (firstResume >= 0) expect(testIndex).toBeLessThan(firstResume);
    }
  });

  it("declares isolated synthetic fixtures for every hosted managed-resource class", () => {
    const source = readFileSync(hostedAcceptancePath, "utf8");
    expect(source).toMatch(/isolated[^\n]*synthetic|synthetic[^\n]*isolated/i);
    for (
      const resource of [
        /identit(?:y|ies)/i,
        /objects?/i,
        /queues?/i,
        /schedules?/i,
        /roles?/i,
        /rows?/i,
        /configuration/i,
      ]
    ) {
      expect(source, `missing fixture inventory class ${resource}`).toMatch(
        resource,
      );
    }
  });

  it("captures inventories around hosted tests and validates cleanup parity", () => {
    const steps = promotionSteps();
    const before = firstStep(
      steps,
      /fixture-inventory-before/,
    );
    const hostedTests = firstStep(steps, /supabase\s+test\s+db\s+--linked/);
    const after = firstStep(
      steps,
      /fixture-inventory-after/,
    );

    expect(before).toBeGreaterThanOrEqual(0);
    expect(hostedTests).toBeGreaterThan(before);
    expect(after).toBeGreaterThan(hostedTests);
    expect(runText(steps[after]!)).toMatch(/--assert-fixture-parity/);
  });

  it("cannot resume work when cleanup or inventory parity fails", () => {
    const steps = promotionSteps();
    const after = firstStep(
      steps,
      /fixture-inventory-after/,
    );
    const resume = firstStep(steps, /resume|unfence|enabled\s*=\s*false/i);
    const afterInventory = after < 0 ? "" : runText(steps[after]!);

    expect(afterInventory).toMatch(/--assert-fixture-parity/);
    if (resume >= 0) {
      expect(resume).toBeGreaterThan(after);
      expect(runText(steps[resume]!)).toMatch(/background_workers/);
      expect(runText(steps[resume]!)).not.toMatch(
        /provider_egress|order_mutations/,
      );
    }
  });

  it("proves bounded public behavior and every deployed Edge bundle revision", () => {
    const source = readFileSync(hostedAcceptancePath, "utf8");
    expect(source).toMatch(/public\/editorial\/ritual\?limit=1/);
    expect(source).toMatch(/public editorial envelope mismatch/);
    for (const bundle of ["api", "webull-callback", "worker", "waitlist"]) {
      expect(source, `missing ${bundle} revision proof`).toMatch(
        bundle === "api"
          ? /assert_observed_revision api/
          : new RegExp(`assert_bundle_revision ${bundle}`),
      );
    }
    expect(source).toMatch(/--connect-timeout 5/);
    expect(source).toMatch(/--max-time 15/);
  });

  it("keeps old-Edge acceptance compatible while requiring new-Edge revision evidence", () => {
    const source = readFileSync(hostedAcceptancePath, "utf8");
    expect(source).toMatch(/test "\$mode" = "--old-edge-new-schema"/);
    expect(source).toMatch(/if has\("meta"\).*else true end/s);
    expect(source).toMatch(/revision header missing/);
    expect(source).toMatch(/test "\$mode" = "--old-edge-new-schema" && return/);
  });

  it("attaches the immutable revision header in every remediation Edge bundle", () => {
    for (const bundle of ["api", "webull-callback", "worker", "waitlist"]) {
      expect(
        readFileSync(
          resolve(repositoryRoot, `supabase/functions/${bundle}/index.ts`),
          "utf8",
        ),
        `missing revision wrapper for ${bundle}`,
      ).toMatch(/withBuildRevisionHeader/);
    }
  });
});
