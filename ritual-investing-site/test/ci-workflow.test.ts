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
  it("makes provider, demo web, static site, waitlist Edge, and cross-browser proof required PR jobs", async () => {
    const source = await workflow();

    for (const name of [
      "demo-provider-boundary",
      "demo-web",
      "site",
      "site-waitlist-edge",
      "site-browser",
    ]) {
      expect(job(source, name)).not.toContain("if: github.event_name == 'workflow_dispatch'");
    }

    expect(job(source, "demo-provider-boundary")).toContain("test-check-demo-provider-boundaries.sh");
    expect(job(source, "demo-web")).toContain("flutter build web --release");
    expect(job(source, "site")).toContain("npm run pages:config:check");
    expect(job(source, "site")).not.toMatch(/types:check|resources:check|deploy:dry-run/);
    expect(job(source, "site-waitlist-edge")).toContain("deno task check");
    expect(job(source, "site-waitlist-edge")).toContain("deno task test");
    expect(job(source, "site-browser")).toContain("playwright install --with-deps chromium firefox webkit");
  });

  it("keeps normal PR proof local and reserves hosted Supabase credentials for protected deployment", async () => {
    const source = await workflow();
    const browser = job(source, "site-browser");
    const hosted = job(source, "supabase-hosted-development");

    expect(browser).not.toMatch(/secrets\.|RITUAL_SITE_STAGING/);
    expect(hosted).toContain("github.event_name == 'push'");
    expect(hosted).toContain("github.ref == 'refs/heads/main'");
    expect(hosted).toContain("environment: ritual-supabase-development");
    expect(hosted).toContain("SUPABASE_ACCESS_TOKEN");
    expect(hosted).toContain("cancel-in-progress: false");
  });

  it("preserves the established mobile, API, contract, member, and admin regression jobs", async () => {
    const source = await workflow();
    for (const name of [
      "api-security",
      "supabase-local",
      "supabase-edge",
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
