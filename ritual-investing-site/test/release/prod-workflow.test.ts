import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../../..");
const readWorkflow = () => readFile(
  resolve(root, ".github/workflows/ritual-investing-prod.yml"),
  "utf8",
);

function job(source: string, name: string): string {
  const start = source.indexOf(`\n  ${name}:\n`);
  if (start < 0) throw new Error(`Missing required workflow job: ${name}`);
  const remainder = source.slice(start + name.length + 5);
  const next = /\n  (?=[A-Za-z0-9_-]+:\n)/.exec(remainder)?.index;
  return source.slice(start, next === undefined ? source.length : start + name.length + 5 + next);
}

describe("Ritual manual prod promotion workflow", () => {
  it("is manual-only and requires unambiguous retained release, staging, and evidence identities", async () => {
    const source = await readWorkflow();
    expect(source).toMatch(/on:\n\s+workflow_dispatch:/);
    expect(source).not.toMatch(/\n  (push|pull_request|workflow_run|schedule):/);
    for (const input of [
      "source_run_id",
      "source_artifact_id",
      "source_sha",
      "release_digest",
      "manifest_sha256",
      "staging_run_id",
      "staging_receipt_artifact_id",
      "evidence_run_id",
      "evidence_artifact_id",
    ]) expect(source).toContain(`${input}:`);
    expect(source).not.toContain("prod_readiness_url:");
    expect(source).not.toContain("inputs.prod_readiness_url");
    expect(source).not.toMatch(/reviewers:|wait_timer:|deployment_branch_policy:|branch_protection|ruleset|required_status_checks/);
    expect(source).toContain("group: ritual-investing-prod-promotion");
    expect(source).toContain("cancel-in-progress: false");
  });

  it("keeps canonical provenance and every fail-closed artifact check credential-free", async () => {
    const source = await readWorkflow();
    const preflight = job(source, "preflight");
    expect(preflight).toContain("if: github.ref == 'refs/heads/main'");
    expect(preflight).toContain("environment: prod");
    expect(preflight).not.toMatch(/secrets\./);
    expect(preflight).toContain("PROD_READINESS_URL: ${{ vars.AXIO7_PROD_READINESS_URL }}");
    for (const path of [
      '.path == ".github/workflows/ritual-investing-ci.yml"',
      '.path == ".github/workflows/ritual-investing-staging.yml"',
      '.path == ".github/workflows/ritual-investing-release-evidence.yml"',
    ]) expect(preflight).toContain(path);
    for (const identity of [
      "expected_source_name",
      "expected_staging_name",
      "expected_evidence_name",
      "SOURCE_ARTIFACT_ID",
      "STAGING_RECEIPT_ARTIFACT_ID",
      "EVIDENCE_ARTIFACT_ID",
      "merge-multiple: true",
    ]) expect(preflight).toContain(identity);
    expect(preflight).toContain("ref: refs/heads/main");
    expect(preflight).toContain("path: main-source");
    expect(preflight).toContain("fetch-depth: 0");
    expect(preflight).toContain('git -C main-source merge-base --is-ancestor "$SOURCE_SHA" HEAD');
    expect(preflight).toContain("RELEASE_BUNDLE_VERIFICATION_CONTEXT");
    expect(preflight).toContain("RELEASE_VERIFICATION_CONTEXT");
    expect(preflight).toContain("PROD_EVIDENCE_VERIFICATION_CONTEXT");
    expect(preflight).toContain("release:receipt:verify -- --prod-evidence");
    expect(preflight).toContain('.promotable == true and .reconstructable == true and .scope == "full"');
    expect(preflight).toContain("snapshots/infra/terraform/ritual-investing");
    expect(preflight).toContain("snapshots/supabase/migrations");
    expect(preflight).toContain("snapshots/supabase/functions");
    expect(preflight).toContain("prod_target_fingerprint");
  });

  it("revalidates the immutable staging workflow controller independently of the source head", async () => {
    const source = await readWorkflow();
    const preflight = job(source, "preflight");
    expect(preflight).not.toContain('staging_controller_sha="$(jq -er \'.head_sha\' "$RUNNER_TEMP/staging-run.json")"');
    expect(preflight).toContain('staging_controller_sha="$(jq -er \'.controller.sha\' "$RUNNER_TEMP/staging-artifact/staging-receipt.json")"');
    expect(preflight).toContain('[[ "$staging_controller_sha" =~ ^[a-f0-9]{40}$ ]]');
    expect(preflight).toContain('git -C main-source merge-base --is-ancestor "$staging_controller_sha" HEAD');
    expect(preflight).toContain('git -C main-source show "$staging_controller_sha:.github/workflows/ritual-investing-staging.yml"');
    expect(preflight).toContain('--arg stagingSha "$staging_controller_sha"');
  });

  it("fails before mutation without current infrastructure and an exact backend decision", async () => {
    const source = await readWorkflow();
    const preflight = job(source, "preflight");
    expect(preflight).toContain("RITUAL_PROD_INFRASTRUCTURE_RECEIPT");
    expect(preflight).toContain("RITUAL_PROD_INFRASTRUCTURE_RECEIPT_SHA256");
    expect(preflight).toContain("prod infrastructure readiness is not enabled");
    expect(preflight).toContain('$target_status" == "approved"');
    expect(preflight).toContain('$target_status" == "withheld"');
    expect(preflight).toContain("RITUAL_PROD_BACKEND_RECEIPT");
    expect(preflight).toContain("terraformSnapshotSha256");
    expect(preflight).toContain('.snapshots[] | select(.name == "terraform") | .sha256');
    expect(preflight).toContain("requiredSourceSha256");
    expect(preflight).toContain(".sourceSha256 == $source");
    expect(preflight).toContain("landing_eligible=false");
    expect(preflight).toContain("mutationScheduled:false");
    expect(job(source, "prod-infrastructure")).toContain("needs.preflight.outputs.mutation_ready == 'true'");
  });

  it("uses a separate prod-scoped, read-only Terraform refresh and exact no-op gate", async () => {
    const source = await readWorkflow();
    const infrastructure = job(source, "prod-infrastructure");
    expect(infrastructure).toContain("environment: prod");
    expect(infrastructure).toContain("group: ritual-investing-prod-infrastructure");
    expect(infrastructure).toContain("cancel-in-progress: false");
    expect(infrastructure).toContain("RITUAL_PROD_TERRAFORM_STATE_ACCESS_KEY_ID");
    expect(infrastructure).toContain("RITUAL_PROD_TERRAFORM_STATE_SECRET_ACCESS_KEY");
    expect(infrastructure).toContain("RITUAL_PROD_TERRAFORM_VARS_JSON");
    expect(infrastructure).toContain("hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1");
    expect(infrastructure).toContain('.pages_project_name == "ritual-investing-site"');
    expect(infrastructure).toContain("terraform state pull");
    expect(infrastructure).toContain("terraform plan -input=false -lock-timeout=60s -detailed-exitcode");
    expect(infrastructure).toContain('test "$plan_exit" = "0"');
    expect(infrastructure).toContain('.change.actions == ["no-op"]');
    expect(infrastructure).toContain("attributes:.change.before");
    expect(infrastructure).toContain("live_inventory_digest");
    expect(infrastructure).toContain("EXPECTED_TERRAFORM_SNAPSHOT_SHA256");
    expect(infrastructure).toContain(".terraformSnapshotSha256");
    expect(infrastructure).not.toContain("terraform apply");
    expect(infrastructure).not.toContain("CLOUDFLARE_CONTENT_API_TOKEN");
  });

  it("revalidates freshness and target immediately before serialized exact-tree publication", async () => {
    const source = await readWorkflow();
    const content = job(source, "prod-content");
    expect(source.match(/PROD_READINESS_URL: \$\{\{ vars\.AXIO7_PROD_READINESS_URL \}\}/g)).toHaveLength(2);
    expect(source.match(/secrets\.AXIO7_PROD_RESEARCH_TOKEN/g)).toHaveLength(1);
    expect(content).toContain("needs.prod-infrastructure.outputs.no_op_ready == 'true'");
    expect(content).toContain("environment: prod");
    expect(content).toContain("group: ritual-investing-prod-content");
    expect(content).toContain("cancel-in-progress: false");
    const revalidate = content.indexOf("Revalidate fresh evidence, exact target, bundle, infrastructure, and backend before mutation");
    const deployDemo = content.indexOf("Deploy exact immutable prod Demo subtree");
    const deployLanding = content.indexOf("Deploy exact immutable prod landing subtree");
    expect(revalidate).toBeGreaterThan(-1);
    expect(revalidate).toBeLessThan(deployDemo);
    expect(deployDemo).toBeLessThan(deployLanding);
    expect(content).toContain("PROD_EVIDENCE_VERIFICATION_CONTEXT");
    expect(content).toContain("revalidation_started_at");
    expect(content).toContain('test "$target_fingerprint" = "$PROD_TARGET_FINGERPRINT"');
    expect(content).toContain('test "$terraform_snapshot_sha256" = "$EXPECTED_TERRAFORM_SNAPSHOT_SHA256"');
    expect(content).toContain(".sourceSha256 == $source");
    expect(content).toContain('.status == "READY" and .public_realtime_research_ready == true');
    expect(content).toContain('test "$running_revision" = "$SOURCE_SHA"');
    expect(content).toContain("release-bundle/trees/prod/demo");
    expect(content).toContain("release-bundle/trees/prod/landing");
    expect(content).toContain("--project-name=ritual-investing-site");
    expect(content).toContain("if: env.LANDING_ELIGIBLE == 'true'");
    expect(content).toContain("approved-exact-prod-backend-target-and-receipt-are-absent");
    expect(content).not.toMatch(/npm run (?:build|assets:build)|release:bundle|flutter build|cargo build|docker build/);
  });

  it("captures real prior, resulting, final, rollback, probe, and strict receipt evidence", async () => {
    const source = await readWorkflow();
    const content = job(source, "prod-content");
    expect(content).toContain('select(.environment == "production")');
    expect(content).toContain('select(.deployment_trigger.metadata.commit_hash == $sha)');
    expect(content).toContain('"https://$host/version.json"');
    expect(content).toContain('if [[ -n "$prior_id" ]]');
    expect(content).toContain("PRIOR_DIGEST");
    expect(content).toContain("artifactDigest:($demoPriorDigest|nullIfEmpty)");
    expect(content).toContain("artifactDigest:($landingPriorDigest|nullIfEmpty)");
    expect(content).toContain("/deployments/$prior_id/rollback");
    expect(content).toContain(".success == true");
    expect(content).toContain('"$final_id" == "$prior_id"');
    for (const field of [
      "prior",
      "attemptedDeploymentId",
      "resultingDeploymentId",
      "finalDeploymentId",
      "probes",
      "rollback",
      "profileIdentity",
      "infrastructure",
      "controller",
      "eligibility",
    ]) expect(content).toContain(field);
    expect(content).toContain("release:receipt:verify");
    expect(content).toContain("ritual-prod-receipt-");
    expect(content).toContain("retention-days: 90");
  });

  it("pins every action to a full commit SHA", async () => {
    const source = await readWorkflow();
    for (const line of source.split("\n").filter((entry) => entry.includes("uses:"))) {
      expect(line).toMatch(/uses:\s+[\w.-]+\/[\w.-]+@[a-f0-9]{40}\s+#\s+\S+/);
    }
  });
});
