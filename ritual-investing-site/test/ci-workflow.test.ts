import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../..");

async function readWorkflow(name: string): Promise<string> {
  return readFile(resolve(root, `.github/workflows/${name}`), "utf8");
}

function job(source: string, name: string): string {
  const start = source.indexOf(`\n  ${name}:\n`);
  if (start < 0) throw new Error(`Missing required workflow job: ${name}`);
  const remainder = source.slice(start + name.length + 5);
  const next = /\n  (?=[A-Za-z0-9_-]+:\n)/.exec(remainder)?.index;
  return source.slice(start, next === undefined ? source.length : start + name.length + 5 + next);
}

function expectPinned(source: string): void {
  for (const line of source.split("\n").filter((entry) => entry.includes("uses:"))) {
    expect(line).toMatch(/uses:\s+[\w.-]+\/[\w.-]+@[a-f0-9]{40}\s+#\s+\S+/);
  }
}

describe("Ritual fast CI", () => {
  it("is secret-free, cancelable, and contains only fast checks", async () => {
    const source = await readWorkflow("ritual-investing-ci.yml");
    expect(source).toMatch(/on:\n\s+pull_request:/);
    expect(source).toMatch(/\n\s+push:\n\s+branches: \[main\]/);
    expect(source).not.toMatch(/workflow_dispatch|workflow_run|secrets\.|environment:\s+(staging|prod)/);
    expect(source).toContain("cancel-in-progress: true");
    for (const name of ["source-guard", "member-provider-boundary", "demo-web-fast", "demo-provider-boundary", "site", "site-waitlist-edge", "api-security", "supabase-edge", "contract-client", "release-bundle"]) {
      expect(job(source, name).length).toBeGreaterThan(100);
    }
    expect(source).not.toMatch(/playwright|flutter\s+drive|integration_test|chromedriver|emulator|simulator|hosted[- ]acceptance|supabase\s+(start|link)|supabase\s+db\s+reset|--linked|restore|terraform\s+(plan|apply)|wrangler\s+(pages\s+deploy|versions\s+upload)/i);
    expectPinned(source);
  });

  it("uploads the immutable release only for a canonical main push", async () => {
    const source = await readWorkflow("ritual-investing-ci.yml");
    const release = job(source, "release-bundle");
    expect(release).toContain("if: github.event_name == 'push' && github.ref == 'refs/heads/main' && github.event.repository.fork == false");
    expect(release).toContain("npm run --silent release:bundle");
    expect(release).toContain("npm run --silent release:verify -- release/release-bundle");
    expect(release).toContain("retention-days: 30");
    expect(release).toContain("include-hidden-files: true");
    expect(source.match(/actions\/upload-artifact@/g)).toHaveLength(1);
  });

  it("uses staging terminology and removes the mixed predecessor", async () => {
    const source = await readWorkflow("ritual-investing-ci.yml");
    const memberRelease = await readWorkflow("ritual-investing-web-release.yml");
    expect(source).not.toMatch(/RITUAL_ENVIRONMENT[=:]\s*beta|landing-beta|demo-beta|beta\.just-build-this\.app/i);
    expect(source).toContain("RITUAL_ENVIRONMENT: staging");
    expect(memberRelease).toContain("--arg environment staging");
    expect(memberRelease).toContain("assets:build:member-staging");
    expect(memberRelease).not.toMatch(/member-beta|--arg environment beta/);
    expect(existsSync(resolve(root, ".github/workflows/ritual-investing.yml"))).toBe(false);
  });

  it("path-scopes the AXIO7 matrix away from Ritual-only changes", async () => {
    const source = await readWorkflow("ci.yml");
    expect(source).toMatch(/push:\n\s+branches: \["\*\*"\]\n\s+paths:/);
    expect(source).toMatch(/pull_request:\n\s+paths:/);
    expect(source).toContain('"axio7-model-review/**"');
    expect(source).not.toContain('"ritual-investing-*/**"');
    expect(source).toMatch(/\n\s+workflow_dispatch:/);
    expectPinned(source);
  });
});
