import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../../..");
const readWorkflow = () => readFile(resolve(root, ".github/workflows/ritual-investing-release-evidence.yml"), "utf8");

function job(source: string, name: string): string {
  const start = source.indexOf(`\n  ${name}:\n`);
  if (start < 0) throw new Error(`Missing required workflow job: ${name}`);
  const remainder = source.slice(start + name.length + 5);
  const next = /\n  (?=[A-Za-z0-9_-]+:\n)/.exec(remainder)?.index;
  return source.slice(start, next === undefined ? source.length : start + name.length + 5 + next);
}

const heavyJobs = ["member-web-build", "demo-browser", "site-browser", "supabase-local", "mobile-android", "mobile-ios", "member-integration-android", "member-integration-ios", "admin-web-browser"];

describe("Ritual manual release evidence", () => {
  it("requires and verifies one exact canonical source release", async () => {
    const source = await readWorkflow();
    expect(source).toMatch(/on:\n\s+workflow_dispatch:/);
    expect(source).not.toMatch(/\n\s+(push|pull_request|workflow_run):/);
    for (const input of ["source_run_id", "artifact_id", "source_sha", "archive_sha256", "manifest_sha256"]) expect(source).toContain(`${input}:`);
    const preflight = job(source, "source-release");
    for (const condition of ['.repository.full_name == $repository', '.head_repository.full_name == $repository', '.event == "push"', '.head_branch == "main"', '.head_sha == $sha', '.conclusion == "success"', '.path == ".github/workflows/ritual-investing-ci.yml"', '.workflow_run.id == $run_id', '.expired == false']) expect(preflight).toContain(condition);
    expect(preflight).toContain("artifact-ids: ${{ inputs.artifact_id }}");
    expect(preflight).toContain("run-id: ${{ inputs.source_run_id }}");
    expect(preflight).toContain(".workflow_run.repository_id == $source_run[0].repository.id");
    expect(preflight).toContain(".workflow_run.head_repository_id == $source_run[0].head_repository.id");
    expect(preflight).toContain('test "$actual_archive_sha256" = "$EXPECTED_ARCHIVE_SHA256"');
    expect(preflight).toContain('test "$actual_manifest_sha256" = "$EXPECTED_MANIFEST_SHA256"');
  });

  it("runs every migrated heavy check manually against the selected SHA", async () => {
    const source = await readWorkflow();
    for (const name of heavyJobs) {
      const section = job(source, name);
      expect(section).toContain("needs: source-release");
      expect(section).toContain("ref: ${{ inputs.source_sha }}");
    }
    expect(job(source, "demo-browser")).toContain("flutter drive");
    expect(job(source, "site-browser")).toContain("npm run test:browser");
    expect(job(source, "supabase-local")).toContain("supabase db reset");
    expect(job(source, "member-integration-android")).toContain("android-emulator-runner");
    expect(job(source, "member-integration-ios")).toContain("xcrun simctl");
    expect(job(source, "member-web-build")).toContain("assets:build:member-staging");
  });

  it("records evidence only after all manual checks and pins every action", async () => {
    const source = await readWorkflow();
    const summary = job(source, "evidence-summary");
    for (const name of heavyJobs) expect(summary).toContain(name);
    expect(summary).toContain("retention-days: 30");
    expect(source).not.toMatch(/secrets\.|environment:/);
    for (const line of source.split("\n").filter((entry) => entry.includes("uses:"))) expect(line).toMatch(/uses:\s+[\w.-]+\/[\w.-]+@[a-f0-9]{40}\s+#\s+\S+/);
  });
});
