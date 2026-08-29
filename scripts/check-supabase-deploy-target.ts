import { createHash } from "node:crypto";
import { readFileSync, realpathSync, statSync } from "node:fs";
import { relative, resolve } from "node:path";

const required = (name: string): string => {
  const value = process.env[name]?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error(`missing_${name.toLowerCase()}`);
  }
  return value;
};

function reject(code: string): never {
  throw new Error(`supabase_deploy_target_rejected:${code}`);
}

function requireDigest(name: string): string {
  const value = required(name);
  if (!/^[a-f0-9]{64}$/.test(value)) reject(name.toLowerCase());
  return value;
}

function requireReference(name: string): string {
  const value = required(name);
  if (!/^[A-Za-z0-9][A-Za-z0-9._:@/-]{2,127}$/.test(value)) {
    reject(name.toLowerCase());
  }
  return value;
}

function requireApproved(inputName: string, approvedName: string): string {
  const input = required(inputName);
  if (input !== required(approvedName)) {
    reject(`${inputName.toLowerCase()}_approval`);
  }
  return input;
}

function validatePromotionBindings(): void {
  if (required("GITHUB_EVENT_NAME") !== "workflow_dispatch") {
    reject("promotion_event");
  }

  const revision = required("RITUAL_PROMOTION_GIT_REVISION");
  if (!/^[a-f0-9]{40}$/.test(revision) || revision !== required("GITHUB_SHA")) {
    reject("git_revision");
  }
  if (
    required("RITUAL_PROMOTION_CONTRACT_VERSION") !==
      "argus-supabase-promotion/v1" ||
    required("RITUAL_PROMOTION_PROJECT_ID") !==
      required("SUPABASE_PROJECT_ID") ||
    required("RITUAL_PROMOTION_BRANCH_REF") !== required("GITHUB_REF")
  ) {
    reject("manifest_identity");
  }

  const digestBindings = [
    ["RITUAL_PROMOTION_MANIFEST_SHA256", "RITUAL_APPROVED_MANIFEST_SHA256"],
    ["RITUAL_MIGRATION_CHECKSUM", "RITUAL_APPROVED_MIGRATION_CHECKSUM"],
    ["RITUAL_SOURCE_TARGET_FINGERPRINT", "RITUAL_APPROVED_SOURCE_FINGERPRINT"],
    ["RITUAL_TARGET_FINGERPRINT", "RITUAL_APPROVED_TARGET_FINGERPRINT"],
    ["RITUAL_INVENTORY_SHA256", "RITUAL_APPROVED_INVENTORY_SHA256"],
    [
      "RITUAL_RECOVERY_COVERAGE_SHA256",
      "RITUAL_APPROVED_RECOVERY_COVERAGE_SHA256",
    ],
  ] as const;
  for (const [inputName, approvedName] of digestBindings) {
    requireDigest(inputName);
    requireDigest(approvedName);
    requireApproved(inputName, approvedName);
  }

  for (
    const [inputName, approvedName] of [
      ["RITUAL_BACKUP_ID", "RITUAL_APPROVED_BACKUP_ID"],
      ["RITUAL_RESTORE_DRILL_ID", "RITUAL_APPROVED_RESTORE_DRILL_ID"],
      ["RITUAL_RELEASE_APPROVAL", "RITUAL_APPROVED_RELEASE_APPROVAL"],
      ["RITUAL_RECOVERY_APPROVAL", "RITUAL_APPROVED_RECOVERY_APPROVAL"],
      ["RITUAL_SECURITY_APPROVAL", "RITUAL_APPROVED_SECURITY_APPROVAL"],
    ] as const
  ) {
    requireReference(inputName);
    requireReference(approvedName);
    requireApproved(inputName, approvedName);
  }

  if (
    required("RITUAL_TRAFFIC_ADMISSION") !== "maintenance" ||
    required("RITUAL_FENCE_BACKGROUND_WORKERS") !== "true" ||
    required("RITUAL_FENCE_PROVIDER_EGRESS") !== "true" ||
    required("RITUAL_FENCE_ORDER_MUTATIONS") !== "true"
  ) {
    reject("fence_contract");
  }

  const capturedAt = required("RITUAL_CAPTURED_AT");
  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(capturedAt) ||
    Number.isNaN(Date.parse(capturedAt)) ||
    new Date(capturedAt).toISOString().replace(".000Z", "Z") !== capturedAt
  ) {
    reject("capture_time");
  }
  if (
    !/^u9-[a-z0-9][a-z0-9-]{4,59}$/.test(required("RITUAL_FIXTURE_NAMESPACE"))
  ) {
    reject("fixture_namespace");
  }
  const oldEdgeRevision = required("RITUAL_OLD_EDGE_REVISION");
  if (!/^[a-f0-9]{40}$/.test(oldEdgeRevision) || oldEdgeRevision === revision) {
    reject("old_edge_revision");
  }

  const runnerTemp = realpathSync(required("RUNNER_TEMP"));
  const manifestPath = realpathSync(required("RITUAL_PROMOTION_MANIFEST_PATH"));
  const manifestRelative = relative(runnerTemp, manifestPath);
  if (
    manifestRelative.startsWith("..") ||
    resolve(runnerTemp, manifestRelative) !== manifestPath
  ) {
    reject("manifest_path");
  }
  const manifestStat = statSync(manifestPath);
  if (!manifestStat.isFile() || manifestStat.size > 65_536) {
    reject("manifest_file");
  }
  const actualManifestDigest = createHash("sha256")
    .update(readFileSync(manifestPath))
    .digest("hex");
  if (actualManifestDigest !== required("RITUAL_PROMOTION_MANIFEST_SHA256")) {
    reject("manifest_digest");
  }
}

function validate(): void {
  const event = required("GITHUB_EVENT_NAME");
  if (event !== "push" && event !== "workflow_dispatch") reject("event");
  if (required("GITHUB_REF") !== "refs/heads/main") reject("ref");
  if (
    required("GITHUB_REPOSITORY") !== required("RITUAL_EXPECTED_REPOSITORY")
  ) {
    reject("repository");
  }

  const projectId = required("SUPABASE_PROJECT_ID");
  const expectedProjectId = required("RITUAL_EXPECTED_SUPABASE_PROJECT_ID");
  if (!/^[a-z]{20}$/.test(projectId) || projectId !== expectedProjectId) {
    reject("project");
  }
  const projectUrl = required("SUPABASE_PROJECT_URL");
  if (projectUrl !== `https://${projectId}.supabase.co`) {
    reject("project_url");
  }
  if (
    required("RITUAL_HOSTED_API_URL") !== `${projectUrl}/functions/v1/api`
  ) {
    reject("api_url");
  }

  let databaseUrl: URL;
  try {
    databaseUrl = new URL(required("SUPABASE_DB_URL"));
  } catch {
    reject("database_url");
  }
  const expectedHost = required("RITUAL_EXPECTED_SUPABASE_DB_HOST");
  const directHost = `db.${projectId}.supabase.co`;
  const directTarget = databaseUrl.username === "postgres" &&
    databaseUrl.hostname === directHost &&
    expectedHost === directHost &&
    databaseUrl.port === "5432";
  const poolerTarget = databaseUrl.username === `postgres.${projectId}` &&
    databaseUrl.hostname === expectedHost &&
    databaseUrl.hostname !== directHost &&
    databaseUrl.port === "6543";
  if (
    !["postgres:", "postgresql:"].includes(databaseUrl.protocol) ||
    (!directTarget && !poolerTarget) ||
    databaseUrl.pathname !== "/postgres" ||
    databaseUrl.password.length === 0 ||
    databaseUrl.searchParams.get("sslmode") !== "require"
  ) {
    reject("database_target");
  }

  const promotionMode = process.env.RITUAL_PROMOTION_MODE?.trim();
  if (
    promotionMode !== undefined && promotionMode !== "" &&
    promotionMode !== "remediation"
  ) {
    reject("promotion_mode");
  }
  if (promotionMode === "remediation") {
    validatePromotionBindings();
  }
}

try {
  validate();
  console.log("Supabase deploy target verified for protected main.");
} catch (error) {
  const message = error instanceof Error ? error.message : "unknown_error";
  console.error(message);
  process.exitCode = 1;
}
