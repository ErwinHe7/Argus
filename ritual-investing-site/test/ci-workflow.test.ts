import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");

async function workflow(): Promise<string> {
  return readFile(resolve(repositoryRoot, ".github/workflows/ritual-investing.yml"), "utf8");
}

async function releaseWorkflow(): Promise<string> {
  return readFile(
    resolve(repositoryRoot, ".github/workflows/ritual-investing-web-release.yml"),
    "utf8",
  );
}

async function remediationWorkflow(): Promise<string> {
  return readFile(
    resolve(repositoryRoot, ".github/workflows/ritual-investing-supabase-remediation.yml"),
    "utf8",
  );
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
  it("makes provider, member web, demo web, static site, waitlist Edge, and cross-browser proof required PR jobs", async () => {
    const source = await workflow();

    for (const name of [
      "demo-provider-boundary",
      "demo-web",
      "member-web",
      "site",
      "site-waitlist-edge",
      "site-browser",
    ]) {
      expect(job(source, name)).not.toContain("if: github.event_name == 'workflow_dispatch'");
    }

    expect(job(source, "demo-provider-boundary")).toContain("test-check-demo-provider-boundaries.sh");
    expect(job(source, "demo-web")).toContain("flutter build web --release");
    const memberWeb = job(source, "member-web");
    expect(memberWeb).toContain("flutter build web --release");
    expect(memberWeb).toContain("--no-web-resources-cdn");
    expect(memberWeb).toContain("--no-source-maps");
    expect(memberWeb).toContain("--no-wasm-dry-run");
    expect(memberWeb).toContain("--pwa-strategy=none");
    expect(memberWeb).toContain("--dart-define=BETA_SUPABASE_PROJECT_REF=");
    expect(memberWeb).toContain("--dart-define=BETA_SUPABASE_PUBLISHABLE_KEY_SHA256=");
    expect(memberWeb).toContain("npm run assets:build:member-beta");
    expect(memberWeb).toContain("wrangler versions upload --config wrangler.jsonc --dry-run");
    expect(memberWeb).not.toMatch(/secrets\.|CLOUDFLARE_API_TOKEN|SUPABASE_ACCESS_TOKEN/);
    expect(job(source, "site")).toContain("npm run pages:config:check");
    expect(job(source, "site")).not.toMatch(/types:check|resources:check|deploy:dry-run/);
    expect(job(source, "site-waitlist-edge")).toContain("deno task check");
    expect(job(source, "site-waitlist-edge")).toContain("deno task test");
    expect(job(source, "site-browser")).toContain("playwright install --with-deps chromium firefox webkit");
  });

  it("serializes preview, promotion, rollback, and Supabase remediation under one protected lock", async () => {
    const release = await releaseWorkflow();
    const remediation = await remediationWorkflow();

    expect(release).toContain("environment: ritual-investing-web-release");
    expect(release).toMatch(/options:\n\s+- preview\n\s+- promote\n\s+- rollback/);
    expect(release).toContain("group: ritual-investing-release");
    expect(remediation).toContain("group: ritual-investing-release");
    expect(release).toContain("APPROVED_MEMBER_WEB_RELEASE_MANIFEST_SHA256");
    expect(release).toContain("EXPECTED_MEMBER_WORKER_NAME");
    expect(release).toContain("EXPECTED_BETA_SUPABASE_PROJECT_ID");
    expect(release).toContain("wrangler versions upload");
    expect(release).toContain("--preview-alias beta");
    expect(release).not.toContain(".preview_accepted=true");
    expect(release).toContain('if: inputs.action == \'promote\'');
    expect(release).toContain('"$RITUAL_WORKER_VERSION_ID@100%"');
    expect(release).toContain("wrangler rollback");

    const promote = release.slice(release.indexOf("Verify the recorded preview version before promotion"));
    expect(promote).not.toContain("flutter build web");
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
