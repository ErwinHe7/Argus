import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");

describe("static Pages and Supabase waitlist runbook", () => {
  it("names the static-only host, exact Edge endpoint, and fail-closed activation gates", async () => {
    const runbook = await readFile(
      resolve(repositoryRoot, "docs/ritual-investing/site-demo-runbook.md"),
      "utf8",
    );
    for (const phrase of [
      "Cloudflare Pages",
      "static assets only",
      "Supabase Edge Function",
      "WAITLIST_FUNCTION_URL_PROD",
      "WAITLIST_FUNCTION_URL_STAGING",
      "WAITLIST_SUBMISSIONS=off",
      "exact landing origin",
      "Turnstile",
      "23 months 29 days",
      "preview",
      "privacy@just-build-this.app",
    ]) expect(runbook).toContain(phrase);
    expect(runbook).not.toMatch(/WAITLIST_NEON_URL|waitlist_runtime|Neon project/i);
  });

  it("documents the velocity-first dev, staging, prod release and recovery contract", async () => {
    const [runbook, terraformReadme] = await Promise.all([
      readFile(
        resolve(repositoryRoot, "docs/ritual-investing/production-release-runbook.md"),
        "utf8",
      ),
      readFile(
        resolve(repositoryRoot, "infra/terraform/ritual-investing/README.md"),
        "utf8",
      ),
    ]);
    for (const phrase of [
      "`dev`, `staging`, and `prod`",
      "Direct pushes remain allowed",
      "downloads the same artifact",
      "Artifact expired or missing",
      "automatic schema rollback",
      "Terraform state/backend",
      "Evidence custody",
      "Production remains NO-GO",
    ]) expect(runbook).toContain(phrase);
    expect(runbook).toContain("does not configure branch protection");
    expect(runbook).toMatch(/does not require a GitHub\s+deployment environment/);
    expect(runbook).toMatch(/repository-level GitHub\s+Actions variables/);
    expect(runbook).toContain("credential-free staging preflight");
    expect(terraformReadme).toContain("repository-level GitHub Actions variables");
  });

  it("moves the route and retention proof to Supabase and keeps Pages free of backend bindings", async () => {
    const [migration, edge, packageJson] = await Promise.all([
      readFile(resolve(
        repositoryRoot,
        "supabase/migrations/20260828145737_u12_waitlist.sql",
      ), "utf8"),
      readFile(resolve(repositoryRoot, "supabase/functions/waitlist/index.ts"), "utf8"),
      readFile(resolve(repositoryRoot, "ritual-investing-site/package.json"), "utf8"),
    ]);
    expect(migration).toContain("argus-waitlist-retention");
    expect(migration).toContain("23 months 29 days");
    expect(edge).toContain("cf-connecting-ip");
    expect(edge).toContain("access-control-allow-origin");
    expect(edge).not.toMatch(/Neon|Auth0|Webull/i);
    expect(packageJson).not.toMatch(/neondatabase|drizzle|hono|deploy:dry-run/i);
  });
});
