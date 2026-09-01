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
    for (const name of ["source-guard", "member-provider-boundary", "demo-web-fast", "demo-provider-boundary", "site", "terraform-contract", "site-waitlist-edge", "api-security", "supabase-edge", "contract-client", "release-bundle"]) {
      expect(job(source, name).length).toBeGreaterThan(100);
    }
    expect(source).not.toMatch(/playwright|flutter\s+drive|integration_test|chromedriver|emulator|simulator|hosted[- ]acceptance|supabase\s+(start|link)|supabase\s+db\s+reset|--linked|restore|terraform\s+(plan|apply)|wrangler\s+(pages\s+deploy|versions\s+upload)/i);
    expect(source).toContain("DENO_VERSION: 2.9.6");
    expect(source).not.toContain("deno-version: v2.x");
    expect(source.match(/deno-version: \$\{\{ env\.DENO_VERSION \}\}/g)).toHaveLength(2);
    for (const name of ["source-guard", "member-provider-boundary", "demo-web-fast", "demo-provider-boundary"]) {
      expect(job(source, name)).toContain("sudo apt-get install -y ripgrep");
    }
    const legacyGuard = await readFile(resolve(root, "scripts/check-legacy-backend-removal.sh"), "utf8");
    expect(legacyGuard).toContain('command -v rg >/dev/null 2>&1 || fail "ripgrep (rg) is required"');
    expect(job(source, "demo-web-fast")).toContain("flutter test --exclude-tags golden");
    for (const name of ["starpath_visual_reference_test.dart", "member_entry_visual_test.dart", "visual_reference_test.dart"]) {
      const visualTest = await readFile(resolve(root, `ritual-investing-app/test/${name}`), "utf8");
      expect(visualTest).toContain("@Tags(['golden'])");
    }
    expectPinned(source);
  });

  it("validates both isolated Terraform roots without backend or mutation authority", async () => {
    const source = await readWorkflow("ritual-investing-ci.yml");
    const terraform = job(source, "terraform-contract");
    expect(terraform).toContain("terraform fmt -check -recursive infra/terraform/ritual-investing");
    for (const environment of ["staging", "prod"]) {
      expect(terraform).toContain(`environments/${environment} init -backend=false -input=false`);
      expect(terraform).toContain(`environments/${environment} validate`);
    }
    expect(terraform).not.toMatch(/secrets\.|environment:|terraform\s+(?:plan|apply)|-backend-config/);
    expect(job(source, "release-bundle")).toContain("terraform-contract");
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
    expect(memberRelease).not.toMatch(/member-beta|--arg environment beta|MEMBER_BETA|BETA_SUPABASE|preview-alias beta|beta\.just-build-this\.app/i);
    expect(memberRelease).toContain("environment: ritual-investing-web-release");
    expect(memberRelease).toContain("--preview-alias staging");
    expect(existsSync(resolve(root, ".github/workflows/ritual-investing.yml"))).toBe(false);
  });

  it("binds manual Supabase remediation to one retained release before staging credentials", async () => {
    const source = await readWorkflow("ritual-investing-supabase-remediation.yml");
    expect(source).toMatch(/on:\n\s+workflow_dispatch:/);
    expect(source).not.toMatch(/\n  (push|pull_request|workflow_run):/);
    for (const input of ["source_run_id", "source_attempt", "artifact_id", "source_sha", "archive_sha256", "manifest_sha256", "promotion_manifest", "promotion_manifest_sha256"]) {
      expect(source).toContain(`${input}:`);
    }
    const preflight = job(source, "preflight");
    expect(preflight).not.toMatch(/\n\s{4}environment:|secrets\.|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD|SUPABASE_DB_URL/);
    for (const proof of [".run_attempt == $attempt", ".expired == false", "merge-multiple: true", "release:verify", "snapshots/supabase/migrations", "snapshots/supabase/functions", "supabase-boundary-manifest-v1.txt", "supabase-migration-inventory-v1.txt", "controller-source"]) {
      expect(preflight).toContain(proof);
    }
    const promote = job(source, "promote");
    expect(promote).toContain("environment: ritual-supabase-remediation");
    expect(promote).toContain("needs.preflight.outputs.mutation_ready == 'true'");
    expect(promote).toContain("working-directory: release-source");
    expect(source).toContain("SUPABASE_CLI_VERSION: 2.115.0");
    expect(promote).toContain('supabase link --project-ref "$SUPABASE_PROJECT_ID"');
    expect(promote).toContain("supabase db push --include-all");
    expect(promote).toContain('supabase functions deploy api --project-ref "$SUPABASE_PROJECT_ID"');
    expect(promote).not.toMatch(/RITUAL_BETA|BETA_SUPABASE|beta\.just-build-this\.app/);
    expectPinned(source);
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
