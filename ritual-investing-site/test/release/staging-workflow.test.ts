import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../../..");
const readWorkflow = () => readFile(
  resolve(root, ".github/workflows/ritual-investing-staging.yml"),
  "utf8",
);

function job(source: string, name: string): string {
  const start = source.indexOf(`\n  ${name}:\n`);
  if (start < 0) throw new Error(`Missing required workflow job: ${name}`);
  const remainder = source.slice(start + name.length + 5);
  const next = /\n  (?=[A-Za-z0-9_-]+:\n)/.exec(remainder)?.index;
  return source.slice(start, next === undefined ? source.length : start + name.length + 5 + next);
}

describe("Ritual automatic staging workflow", () => {
  it("accepts only the successful canonical main release controller", async () => {
    const source = await readWorkflow();
    expect(source).toMatch(/workflow_run:\n\s+workflows: \["Ritual Investing Fast CI"\]/);
    expect(source).toMatch(/types: \[completed\]/);
    expect(source).toMatch(/branches: \[main\]/);
    const preflight = job(source, "preflight");
    for (const condition of [
      "github.event.workflow_run.repository.full_name == github.repository",
      "github.event.workflow_run.head_repository.full_name == github.repository",
      "github.event.workflow_run.event == 'push'",
      "github.event.workflow_run.head_branch == 'main'",
      "github.event.workflow_run.conclusion == 'success'",
      "github.event.workflow_run.path == '.github/workflows/ritual-investing-ci.yml'",
    ]) expect(preflight).toContain(condition);
    expect(preflight).not.toMatch(/\n\s{4}environment:/);
    expect(preflight).not.toMatch(/secrets\./);
    expect(preflight).toContain("RELEASE_BUNDLE_VERIFICATION_CONTEXT");
    expect(preflight).toContain("release:verify --");
    expect(preflight).toContain("demo_probe_manifest_sha256");
    expect(preflight).toContain("landing_probe_manifest_sha256");
    expect(preflight).toContain(".probeManifestSha256");
    expect(preflight).toContain("merge-multiple: true");
    expect(preflight).toContain("snapshots/infra/terraform/ritual-investing");
    expect(preflight).toContain("snapshots/supabase/migrations");
    expect(preflight).toContain("snapshots/supabase/functions");
  });

  it("fails closed on absent infrastructure proof before an environment job", async () => {
    const source = await readWorkflow();
    const preflight = job(source, "preflight");
    expect(preflight).toContain("RITUAL_STAGING_INFRASTRUCTURE_RECEIPT");
    expect(preflight).toContain("RITUAL_STAGING_INFRASTRUCTURE_RECEIPT_SHA256");
    expect(preflight).toContain("staging infrastructure readiness is not enabled");
    expect(preflight).toContain("status == \"ready\"");
    expect(preflight).toContain("expiresAt");
    expect(source).not.toContain("terraform apply");
    expect(source).not.toContain("setup-terraform");

    const content = job(source, "staging-content");
    expect(content).toContain("needs.preflight.outputs.mutation_ready == 'true'");
    expect(content).toContain("environment: staging");
  });

  it("serializes exact-tree content publication and keeps credentials separate", async () => {
    const source = await readWorkflow();
    expect(source).toMatch(/concurrency:\n\s+group: ritual-investing-staging-deployment\n\s+cancel-in-progress: false/);
    const content = job(source, "staging-content");
    expect(content).toContain("group: ritual-investing-staging-content");
    expect(content).toContain("cancel-in-progress: false");
    expect(content).toContain("CLOUDFLARE_CONTENT_API_TOKEN");
    expect(content).not.toMatch(/AWS_|TF_VAR_|TERRAFORM_TOKEN|CLOUDFLARE_CONTROL_PLANE/);
    expect(content).toContain("release-bundle/trees/staging/demo");
    expect(content).toContain("release-bundle/trees/staging/landing");
    expect(content.indexOf("Deploy exact immutable staging Demo subtree"))
      .toBeLessThan(content.indexOf("Deploy exact immutable staging landing subtree"));
    expect(content).toContain("landing_eligible");
    expect(content).toContain("withheld-dependency");
    expect(content).toContain("EXPECTED_INFRASTRUCTURE_RECEIPT_SHA256");
    expect(content).toContain("EXPECTED_BACKEND_RECEIPT_SHA256");
    expect(content).toContain('test "$INFRASTRUCTURE_RECEIPT_SHA256" = "$EXPECTED_INFRASTRUCTURE_RECEIPT_SHA256"');
    expect(content).toContain('test "$BACKEND_RECEIPT_SHA256" = "$EXPECTED_BACKEND_RECEIPT_SHA256"');
    expect(content).toContain(".fingerprint == $fingerprint");
    expect(content).toContain('select(.environment == "production")');
    expect(content).toContain("DEMO_PRIOR_DIGEST");
    expect(content).toContain("LANDING_PRIOR_DIGEST");
    expect(content).toContain("/version.json");
    expect(content).toContain("expectedProfileIdentity");
    expect(content).toContain('select(.environment == "production" and .deployment_trigger.metadata.commit_hash == $sha)');
    expect(content).toContain('/deployments/$prior_id/rollback');
    expect(content).toContain(".success == true");
    expect(content).toContain('"$final_id" == "$prior_id"');
    expect(content).toContain('echo "${surface^^}_FINAL_ID=$prior_id"');
    expect(content).toContain("id: receipt");
    expect(content).toContain("if: always() && steps.receipt.outcome == 'success'");
    expect(content).not.toContain('[[ -n "${DEMO_PRIOR_ID:-}"');
    for (const field of ["prior", "attemptedDeploymentId", "resultingDeploymentId", "finalDeploymentId", "probes", "rollback", "profileIdentity", "infrastructure", "controller"]) {
      expect(content).toContain(field);
    }
    expect(content).toContain("release:receipt:verify");
    expect(content).toContain("DEMO_PROBE_MANIFEST_SHA256: ${{ needs.preflight.outputs.demo_probe_manifest_sha256 }}");
    expect(content).toContain("LANDING_PROBE_MANIFEST_SHA256: ${{ needs.preflight.outputs.landing_probe_manifest_sha256 }}");
    expect(content).toContain("RELEASE_PROBE_MANIFEST_SHA256: ${{ needs.preflight.outputs.demo_probe_manifest_sha256 }}");
    expect(content).toContain("RELEASE_PROBE_MANIFEST_SHA256: ${{ needs.preflight.outputs.landing_probe_manifest_sha256 }}");
    expect(content).toContain('--arg manifestSha256 "$EXPECTED_MANIFEST_SHA256"');
    for (const value of [
      "demo-staging.just-build-this.app",
      "staging.just-build-this.app",
      "RELEASE_PROBE_REVISION",
      "RELEASE_PROBE_MANIFEST_SHA256",
      "RELEASE_PROBE_REQUIRED_HEADERS",
      "RELEASE_PROBE_UNKNOWN_ROUTE_POLICY",
    ]) expect(content).toContain(value);
    expect(content).toContain("retention-days: 30");
  });

  it("contains no heavy automatic checks and pins every action", async () => {
    const source = await readWorkflow();
    expect(source).not.toMatch(/playwright|flutter\s+drive|integration[_ -]?test|e2e|simulator|xcrun|android-emulator|hosted acceptance|supabase\s+(?:start|db\s+reset|link|db\s+push|functions\s+deploy)/i);
    for (const line of source.split("\n").filter((entry) => entry.includes("uses:"))) {
      expect(line).toMatch(/uses:\s+[\w.-]+\/[\w.-]+@[a-f0-9]{40}\s+#\s+\S+/);
    }
  });
});
