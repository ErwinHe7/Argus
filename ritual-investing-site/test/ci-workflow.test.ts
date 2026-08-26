import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");

async function workflow(): Promise<string> {
  return readFile(resolve(repositoryRoot, ".github/workflows/ritual-investing.yml"), "utf8");
}

function job(source: string, name: string): string {
  const start = source.indexOf(`\n  ${name}:\n`);
  if (start < 0) throw new Error(`Missing required workflow job: ${name}`);
  const remainder = source.slice(start + name.length + 5);
  const nextMatch = /\n  (?=[A-Za-z0-9_-]+:\n)/.exec(remainder);
  const next = nextMatch === null ? -1 : start + name.length + 5 + nextMatch.index;
  return source.slice(start, next < 0 ? source.length : next);
}

describe("Ritual release workflow contract", () => {
  it("makes provider, demo web, site, Postgres 17, and cross-browser proof required PR jobs", async () => {
    const source = await workflow();

    for (const name of [
      "demo-provider-boundary",
      "demo-web",
      "site",
      "site-postgres-17",
      "site-browser",
    ]) {
      expect(job(source, name)).not.toContain("if: github.event_name == 'workflow_dispatch'");
    }

    expect(job(source, "demo-provider-boundary")).toContain("test-check-demo-provider-boundaries.sh");
    expect(job(source, "demo-web")).toContain("flutter build web --release");
    expect(job(source, "site")).toContain("npm run deploy:dry-run:all");
    expect(job(source, "site-postgres-17")).toContain("postgres:17.11-alpine");
    expect(job(source, "site-browser")).toContain("playwright install --with-deps chromium firefox webkit");
  });

  it("keeps normal PR proof local and reserves deployed beta evidence for workflow dispatch", async () => {
    const source = await workflow();
    const browser = job(source, "site-browser");
    const staging = job(source, "staging");

    expect(browser).not.toMatch(/secrets\.|RITUAL_SITE_STAGING/);
    expect(staging).toContain("if: github.event_name == 'workflow_dispatch' && inputs.run_staging");
    expect(staging).toContain("site-browser");
    expect(staging).toContain("SITE_STAGING_LANDING_URL");
    expect(staging).toContain("SITE_STAGING_DEMO_URL");
    expect(staging).toContain("SITE_STAGING_EVIDENCE");
  });

  it("preserves the established mobile, API, contract, member, and admin regression jobs", async () => {
    const source = await workflow();
    for (const name of [
      "api-security",
      "postgres-17",
      "worker",
      "contract-client",
      "mobile-android",
      "mobile-ios",
      "member-integration-android",
      "member-integration-ios",
      "admin-web-browser",
    ]) {
      expect(job(source, name).length).toBeGreaterThan(100);
    }
  });
});
