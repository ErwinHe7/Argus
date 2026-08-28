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
  const directTarget =
    databaseUrl.username === "postgres" &&
    databaseUrl.hostname === directHost &&
    expectedHost === directHost &&
    databaseUrl.port === "5432";
  const poolerTarget =
    databaseUrl.username === `postgres.${projectId}` &&
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
}

try {
  validate();
  console.log("Supabase deploy target verified for protected main.");
} catch (error) {
  const message = error instanceof Error ? error.message : "unknown_error";
  console.error(message);
  process.exitCode = 1;
}
