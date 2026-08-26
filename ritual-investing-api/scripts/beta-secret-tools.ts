import { randomBytes } from "node:crypto";
import {
  chmodSync,
  closeSync,
  existsSync,
  mkdirSync,
  openSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export const BETA_WORKER_NAME = "ritual-investing-api-beta";

export const roleDefinitions = [
  {
    passwordKey: "IDENTITY_PASSWORD",
    databaseUrlKey: "IDENTITY_DATABASE_URL",
    role: "ritual_identity_login",
  },
  {
    passwordKey: "BOOTSTRAP_PASSWORD",
    databaseUrlKey: "BOOTSTRAP_DATABASE_URL",
    role: "ritual_bootstrap_login",
  },
  {
    passwordKey: "STAFF_PASSWORD",
    databaseUrlKey: "STAFF_DATABASE_URL",
    role: "ritual_staff_login",
  },
  {
    passwordKey: "PUBLIC_PASSWORD",
    databaseUrlKey: "PUBLIC_DATABASE_URL",
    role: "ritual_public_login",
  },
  {
    passwordKey: "RUNTIME_PASSWORD",
    databaseUrlKey: "RUNTIME_DATABASE_URL",
    role: "ritual_runtime_login",
  },
  {
    passwordKey: "SCHEDULER_PASSWORD",
    databaseUrlKey: "SCHEDULER_DATABASE_URL",
    role: "ritual_scheduler_login",
  },
  {
    passwordKey: "PRIVACY_PASSWORD",
    databaseUrlKey: "PRIVACY_DATABASE_URL",
    role: "ritual_privacy_login",
  },
  {
    passwordKey: "MEDIA_PASSWORD",
    databaseUrlKey: "MEDIA_DATABASE_URL",
    role: "ritual_media_login",
  },
  {
    passwordKey: "AUDIT_PASSWORD",
    databaseUrlKey: "AUDIT_DATABASE_URL",
    role: "ritual_audit_login",
  },
] as const;

export const workerSecretKeys = [
  ...roleDefinitions.map((definition) => definition.databaseUrlKey),
  "CURSOR_SIGNING_KEY",
  "PUSH_TOKEN_ENCRYPTION_KEY",
] as const;

export type SecretStore = Record<string, string>;

function applicationConfigDirectory(): string {
  const configRoot = process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config");
  return resolve(configRoot, "ritual-investing");
}

export function defaultSecretStorePath(): string {
  return join(applicationConfigDirectory(), "beta-secrets.json");
}

export function defaultSqlOutputPath(): string {
  return join(applicationConfigDirectory(), "provision-beta-runtime-roles.sql");
}

function normalizeNeonHost(neonHost: string): string {
  const value = neonHost.trim();
  if (
    value.length === 0 ||
    value.includes("://") ||
    /[/@?#\s]/.test(value)
  ) {
    throw new Error(
      "--neon-host must be a pooled hostname with an optional port, not a URL",
    );
  }

  const parsed = new URL(`https://${value}`);
  if (parsed.hostname.length === 0) {
    throw new Error("--neon-host must contain a hostname");
  }
  return parsed.host;
}

function databaseUrl(
  host: string,
  database: string,
  role: string,
  password: string,
): string {
  const url = new URL("postgresql://placeholder.invalid");
  url.host = host;
  url.username = role;
  url.password = password;
  url.pathname = `/${database}`;
  url.searchParams.set("sslmode", "require");
  url.searchParams.set("channel_binding", "require");
  return url.toString();
}

export function generateBetaSecretStore(
  neonHost: string,
  database = "neondb",
): SecretStore {
  const host = normalizeNeonHost(neonHost);
  if (!/^[A-Za-z0-9_-]+$/.test(database)) {
    throw new Error("--database must contain only letters, numbers, _ or -");
  }

  const store: SecretStore = {};
  for (const definition of roleDefinitions) {
    store[definition.passwordKey] = randomBytes(32).toString("base64url");
  }
  for (const definition of roleDefinitions) {
    store[definition.databaseUrlKey] = databaseUrl(
      host,
      database,
      definition.role,
      store[definition.passwordKey]!,
    );
  }
  store.CURSOR_SIGNING_KEY = randomBytes(48).toString("base64url");
  store.PUSH_TOKEN_ENCRYPTION_KEY = randomBytes(32).toString("base64url");
  return store;
}

function ensurePrivateDirectory(path: string): void {
  if (!existsSync(path)) {
    mkdirSync(path, { recursive: true, mode: 0o700 });
    chmodSync(path, 0o700);
    return;
  }
  const status = statSync(path);
  if (!status.isDirectory()) throw new Error(`${path} is not a directory`);
  if ((status.mode & 0o077) !== 0) {
    throw new Error(
      `refusing to store secrets in ${path}: directory permissions must be 0700`,
    );
  }
}

export function writePrivateFile(
  path: string,
  contents: string,
  overwrite = false,
): void {
  ensurePrivateDirectory(dirname(path));
  let descriptor: number | undefined;
  try {
    descriptor = openSync(path, overwrite ? "w" : "wx", 0o600);
    writeFileSync(descriptor, contents, "utf8");
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      error.code === "EEXIST"
    ) {
      throw new Error(`${path} already exists; pass --force to replace it`);
    }
    throw error;
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
  }
  chmodSync(path, 0o600);
}

export function assertPrivateFile(path: string): void {
  const status = statSync(path);
  if (!status.isFile()) throw new Error(`${path} is not a regular file`);
  const mode = status.mode & 0o777;
  if (mode !== 0o600) {
    throw new Error(
      `refusing to read ${path}: permissions must be 0600 (found ${mode.toString(8).padStart(4, "0")})`,
    );
  }
}

export function readSecretStore(path: string): SecretStore {
  assertPrivateFile(path);
  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(
      `could not parse secret store ${path}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== "object") {
    throw new Error(`${path} must contain a JSON object of string key-value pairs`);
  }
  const store: SecretStore = {};
  for (const [key, value] of Object.entries(parsed)) {
    if (typeof value !== "string" || value.length === 0) {
      throw new Error(`${key} must be a non-empty string`);
    }
    store[key] = value;
  }
  return store;
}

export function requireKeys(
  store: SecretStore,
  keys: readonly string[],
): void {
  const missing = keys.filter((key) => store[key] === undefined);
  if (missing.length > 0) {
    throw new Error(`secret store is missing: ${missing.join(", ")}`);
  }
}

export function workerSecretPayload(store: SecretStore): SecretStore {
  requireKeys(store, workerSecretKeys);
  const payload: SecretStore = {};
  for (const key of workerSecretKeys) payload[key] = store[key]!;

  for (const definition of roleDefinitions) {
    const value = payload[definition.databaseUrlKey]!;
    let parsed: URL;
    try {
      parsed = new URL(value);
    } catch {
      throw new Error(`${definition.databaseUrlKey} must be a valid URL`);
    }
    if (
      parsed.protocol !== "postgresql:" ||
      parsed.username !== definition.role ||
      parsed.password.length === 0 ||
      parsed.hostname.length === 0
    ) {
      throw new Error(
        `${definition.databaseUrlKey} must be a PostgreSQL URL for ${definition.role}`,
      );
    }
  }

  const cursorKey = payload.CURSOR_SIGNING_KEY!;
  if (cursorKey.length < 32 || cursorKey.length > 512) {
    throw new Error("CURSOR_SIGNING_KEY must contain 32 to 512 characters");
  }
  const pushKey = payload.PUSH_TOKEN_ENCRYPTION_KEY!;
  if (!/^[A-Za-z0-9_-]{43}$/.test(pushKey)) {
    throw new Error(
      "PUSH_TOKEN_ENCRYPTION_KEY must be 32 random bytes encoded as unpadded base64url",
    );
  }
  return payload;
}

export function isDirectExecution(moduleUrl: string): boolean {
  const entrypoint = process.argv[1];
  return (
    entrypoint !== undefined &&
    pathToFileURL(resolve(entrypoint)).href === moduleUrl
  );
}

export function reportCliError(error: unknown): void {
  console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
}
