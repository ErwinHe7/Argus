import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const scriptsDirectory = resolve(apiRoot, "scripts");

const passwordKeys = [
  "IDENTITY_PASSWORD",
  "BOOTSTRAP_PASSWORD",
  "STAFF_PASSWORD",
  "PUBLIC_PASSWORD",
  "RUNTIME_PASSWORD",
  "SCHEDULER_PASSWORD",
  "PRIVACY_PASSWORD",
  "MEDIA_PASSWORD",
  "AUDIT_PASSWORD",
] as const;

const databaseUrlKeys = [
  "IDENTITY_DATABASE_URL",
  "BOOTSTRAP_DATABASE_URL",
  "STAFF_DATABASE_URL",
  "PUBLIC_DATABASE_URL",
  "RUNTIME_DATABASE_URL",
  "SCHEDULER_DATABASE_URL",
  "PRIVACY_DATABASE_URL",
  "MEDIA_DATABASE_URL",
  "AUDIT_DATABASE_URL",
] as const;

const roleByDatabaseUrl = {
  IDENTITY_DATABASE_URL: "ritual_identity_login",
  BOOTSTRAP_DATABASE_URL: "ritual_bootstrap_login",
  STAFF_DATABASE_URL: "ritual_staff_login",
  PUBLIC_DATABASE_URL: "ritual_public_login",
  RUNTIME_DATABASE_URL: "ritual_runtime_login",
  SCHEDULER_DATABASE_URL: "ritual_scheduler_login",
  PRIVACY_DATABASE_URL: "ritual_privacy_login",
  MEDIA_DATABASE_URL: "ritual_media_login",
  AUDIT_DATABASE_URL: "ritual_audit_login",
} as const;

const passwordByDatabaseUrl = {
  IDENTITY_DATABASE_URL: "IDENTITY_PASSWORD",
  BOOTSTRAP_DATABASE_URL: "BOOTSTRAP_PASSWORD",
  STAFF_DATABASE_URL: "STAFF_PASSWORD",
  PUBLIC_DATABASE_URL: "PUBLIC_PASSWORD",
  RUNTIME_DATABASE_URL: "RUNTIME_PASSWORD",
  SCHEDULER_DATABASE_URL: "SCHEDULER_PASSWORD",
  PRIVACY_DATABASE_URL: "PRIVACY_PASSWORD",
  MEDIA_DATABASE_URL: "MEDIA_PASSWORD",
  AUDIT_DATABASE_URL: "AUDIT_PASSWORD",
} as const;

function runScript(
  script: string,
  args: readonly string[],
  environment: Record<string, string | undefined> = {},
) {
  return spawnSync(
    process.execPath,
    ["--experimental-strip-types", resolve(scriptsDirectory, script), ...args],
    {
      cwd: apiRoot,
      encoding: "utf8",
      env: { ...process.env, ...environment } as NodeJS.ProcessEnv,
    },
  );
}

function privateMode(path: string): number {
  return statSync(path).mode & 0o777;
}

function fixedSecretStore(): Record<string, string> {
  return {
    IDENTITY_PASSWORD: "identity-password",
    BOOTSTRAP_PASSWORD: "bootstrap-password",
    STAFF_PASSWORD: "staff'password",
    PUBLIC_PASSWORD: "public-password",
    RUNTIME_PASSWORD: "runtime-password",
    SCHEDULER_PASSWORD: "scheduler-password",
    PRIVACY_PASSWORD: "privacy-password",
    MEDIA_PASSWORD: "media-password",
    AUDIT_PASSWORD: "audit-password",
    IDENTITY_DATABASE_URL:
      "postgresql://ritual_identity_login:identity-password@ep-beta-pooler.example/neondb?sslmode=require",
    BOOTSTRAP_DATABASE_URL:
      "postgresql://ritual_bootstrap_login:bootstrap-password@ep-beta-pooler.example/neondb?sslmode=require",
    STAFF_DATABASE_URL:
      "postgresql://ritual_staff_login:staff%27password@ep-beta-pooler.example/neondb?sslmode=require",
    PUBLIC_DATABASE_URL:
      "postgresql://ritual_public_login:public-password@ep-beta-pooler.example/neondb?sslmode=require",
    RUNTIME_DATABASE_URL:
      "postgresql://ritual_runtime_login:runtime-password@ep-beta-pooler.example/neondb?sslmode=require",
    SCHEDULER_DATABASE_URL:
      "postgresql://ritual_scheduler_login:scheduler-password@ep-beta-pooler.example/neondb?sslmode=require",
    PRIVACY_DATABASE_URL:
      "postgresql://ritual_privacy_login:privacy-password@ep-beta-pooler.example/neondb?sslmode=require",
    MEDIA_DATABASE_URL:
      "postgresql://ritual_media_login:media-password@ep-beta-pooler.example/neondb?sslmode=require",
    AUDIT_DATABASE_URL:
      "postgresql://ritual_audit_login:audit-password@ep-beta-pooler.example/neondb?sslmode=require",
    CURSOR_SIGNING_KEY: "cursor-signing-secret-value-that-is-long-enough",
    PUSH_TOKEN_ENCRYPTION_KEY:
      "push-token-encryption-secret-value-43-chars",
  };
}

describe("beta secret generation", () => {
  it("creates a protected complete key-value store without printing values", () => {
    const workspace = mkdtempSync(join(tmpdir(), "ritual-beta-generate-"));
    const output = join(workspace, "private", "beta-secrets.json");
    const result = runScript("generate-beta-secrets.ts", [
      "--neon-host",
      "ep-beta-pooler.example",
      "--output",
      output,
    ]);

    expect(result.status, result.stderr).toBe(0);
    const raw = readFileSync(output, "utf8");
    const values = JSON.parse(raw) as Record<string, string>;
    expect(Object.keys(values).sort()).toEqual(
      [
        ...passwordKeys,
        ...databaseUrlKeys,
        "CURSOR_SIGNING_KEY",
        "PUSH_TOKEN_ENCRYPTION_KEY",
      ].sort(),
    );
    expect(privateMode(output)).toBe(0o600);
    expect(privateMode(dirname(output))).toBe(0o700);

    const passwords = passwordKeys.map((key) => values[key]);
    expect(new Set(passwords).size).toBe(passwordKeys.length);
    for (const password of passwords) {
      expect(password).toMatch(/^[A-Za-z0-9_-]{43}$/);
    }
    expect(values.CURSOR_SIGNING_KEY).toMatch(/^[A-Za-z0-9_-]{64}$/);
    expect(values.PUSH_TOKEN_ENCRYPTION_KEY).toMatch(
      /^[A-Za-z0-9_-]{43}$/,
    );

    for (const databaseUrlKey of databaseUrlKeys) {
      const parsed = new URL(values[databaseUrlKey]!);
      expect(parsed.protocol).toBe("postgresql:");
      expect(parsed.hostname).toBe("ep-beta-pooler.example");
      expect(parsed.username).toBe(roleByDatabaseUrl[databaseUrlKey]);
      expect(parsed.password).toBe(
        values[passwordByDatabaseUrl[databaseUrlKey]],
      );
      expect(parsed.pathname).toBe("/neondb");
      expect(parsed.searchParams.get("sslmode")).toBe("require");
      expect(parsed.searchParams.get("channel_binding")).toBe("require");
    }

    for (const value of Object.values(values)) {
      expect(result.stdout).not.toContain(value);
      expect(result.stderr).not.toContain(value);
    }

    const repeat = runScript("generate-beta-secrets.ts", [
      "--neon-host",
      "ep-beta-pooler.example",
      "--output",
      output,
    ]);
    expect(repeat.status).not.toBe(0);
    expect(readFileSync(output, "utf8")).toBe(raw);
  });
});

describe("beta Neon SQL rendering", () => {
  it("renders every password into a protected SQL file and escapes literals", () => {
    const workspace = mkdtempSync(join(tmpdir(), "ritual-beta-sql-"));
    const secretsPath = join(workspace, "beta-secrets.json");
    const output = join(workspace, "private", "provision-beta-roles.sql");
    const values = fixedSecretStore();
    writeFileSync(secretsPath, `${JSON.stringify(values, null, 2)}\n`, {
      mode: 0o600,
    });

    const result = runScript("render-beta-role-sql.ts", [
      "--secrets",
      secretsPath,
      "--output",
      output,
    ]);

    expect(result.status, result.stderr).toBe(0);
    expect(privateMode(output)).toBe(0o600);
    const sql = readFileSync(output, "utf8");
    expect(sql).not.toMatch(/<[A-Z_]+_PASSWORD>/);
    expect(sql).toContain("ritual_identity_login");
    expect(sql).toContain("PASSWORD 'identity-password'");
    expect(sql).toContain("PASSWORD 'staff''password'");
    for (const password of passwordKeys.map((key) => values[key]!)) {
      expect(result.stdout).not.toContain(password);
      expect(result.stderr).not.toContain(password);
    }
  });

  it("rejects an incomplete secret store before writing SQL", () => {
    const workspace = mkdtempSync(join(tmpdir(), "ritual-beta-sql-missing-"));
    const secretsPath = join(workspace, "beta-secrets.json");
    const output = join(workspace, "provision-beta-roles.sql");
    const values = fixedSecretStore();
    delete values.AUDIT_PASSWORD;
    writeFileSync(secretsPath, `${JSON.stringify(values)}\n`, { mode: 0o600 });

    const result = runScript("render-beta-role-sql.ts", [
      "--secrets",
      secretsPath,
      "--output",
      output,
    ]);

    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/AUDIT_PASSWORD/);
    expect(existsSync(output)).toBe(false);
  });
});

describe("beta Worker secret deployment", () => {
  it("requires confirmation and bulk-uploads only the Worker allowlist over stdin", () => {
    const workspace = mkdtempSync(join(tmpdir(), "ritual-beta-deploy-"));
    const secretsPath = join(workspace, "beta-secrets.json");
    const fakeWrangler = join(workspace, "fake-wrangler.mjs");
    const capturePath = join(workspace, "wrangler-capture.json");
    const values: Record<string, string> = {
      ...fixedSecretStore(),
      EXTRA_LOCAL_ONLY: "never-upload",
    };
    writeFileSync(secretsPath, `${JSON.stringify(values)}\n`, { mode: 0o600 });
    writeFileSync(
      fakeWrangler,
      `import { writeFileSync } from "node:fs";
let input = "";
for await (const chunk of process.stdin) input += chunk;
writeFileSync(process.env.FAKE_WRANGLER_CAPTURE, JSON.stringify({
  args: process.argv.slice(2),
  input,
}));
`,
      { mode: 0o700 },
    );

    const commonArgs = [
      "--secrets",
      secretsPath,
      "--wrangler",
      fakeWrangler,
    ];
    const environment = { FAKE_WRANGLER_CAPTURE: capturePath };
    const unconfirmed = runScript(
      "deploy-beta-worker-secrets.ts",
      commonArgs,
      environment,
    );
    expect(unconfirmed.status).not.toBe(0);
    expect(existsSync(capturePath)).toBe(false);

    const result = runScript(
      "deploy-beta-worker-secrets.ts",
      [...commonArgs, "--yes"],
      environment,
    );
    expect(result.status, result.stderr).toBe(0);
    const capture = JSON.parse(readFileSync(capturePath, "utf8")) as {
      args: string[];
      input: string;
    };
    expect(capture.args).toEqual([
      "secret",
      "bulk",
      "--config",
      resolve(apiRoot, "wrangler.beta.jsonc"),
      "--name",
      "ritual-investing-api-beta",
    ]);
    const uploaded = JSON.parse(capture.input) as Record<string, string>;
    expect(Object.keys(uploaded).sort()).toEqual(
      [
        ...databaseUrlKeys,
        "CURSOR_SIGNING_KEY",
        "PUSH_TOKEN_ENCRYPTION_KEY",
      ].sort(),
    );
    for (const key of databaseUrlKeys) expect(uploaded[key]).toBe(values[key]);
    expect(uploaded.CURSOR_SIGNING_KEY).toBe(values.CURSOR_SIGNING_KEY);
    expect(uploaded.PUSH_TOKEN_ENCRYPTION_KEY).toBe(
      values.PUSH_TOKEN_ENCRYPTION_KEY,
    );
    for (const key of passwordKeys) expect(uploaded[key]).toBeUndefined();
    expect(uploaded.EXTRA_LOCAL_ONLY).toBeUndefined();
    for (const value of Object.values(values)) {
      expect(result.stdout).not.toContain(value);
      expect(result.stderr).not.toContain(value);
    }

    chmodSync(secretsPath, 0o644);
    const insecure = runScript(
      "deploy-beta-worker-secrets.ts",
      [...commonArgs, "--yes"],
      environment,
    );
    expect(insecure.status).not.toBe(0);
    expect(insecure.stderr).toMatch(/0600|permissions/i);
  });
});
