import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import process from "node:process";

import pg from "pg";

const { Client } = pg;
const migrationName = /^\d{4}_[a-z0-9_]+\.sql$/;
const beginBoundary = /^\s*BEGIN;\s*/i;
const commitBoundary = /\s*COMMIT;\s*$/i;
const reservedPrincipals = new Set([
  "waitlist_runtime",
  "waitlist_maintenance",
  "waitlist_function_owner",
]);

export const WAITLIST_MIGRATION_LOCK_KEY = "just-build-this-waitlist-reviewed-migrations-v1";

export type ReviewedMigration = {
  name: string;
  checksum: string;
  body: string;
};

export function assertDirectOwnerDatabaseUrl(databaseUrl: string): void {
  let parsed: URL;
  try {
    parsed = new URL(databaseUrl);
  } catch {
    throw new Error("A valid direct owner database URL is required.");
  }
  if (parsed.protocol !== "postgres:" && parsed.protocol !== "postgresql:") {
    throw new Error("A PostgreSQL direct owner database URL is required.");
  }
  if (parsed.hostname.includes("-pooler.")) {
    throw new Error("Reviewed migrations require a direct Neon owner URL, not a pooled URL.");
  }
  if (reservedPrincipals.has(decodeURIComponent(parsed.username))) {
    throw new Error("Reviewed migrations cannot run with a runtime, maintenance, or function-owner capability.");
  }
  if (parsed.hostname.length === 0 || parsed.pathname === "" || parsed.pathname === "/") {
    throw new Error("A complete direct owner database URL is required.");
  }
}

export async function readReviewedMigrations(
  directory = resolve(process.cwd(), "drizzle"),
): Promise<ReviewedMigration[]> {
  const names = (await readdir(directory)).filter((name) => migrationName.test(name)).sort();
  if (names.length === 0) throw new Error("No reviewed waitlist SQL migrations were found.");

  return Promise.all(
    names.map(async (name) => {
      const sql = await readFile(resolve(directory, name), "utf8");
      if (!beginBoundary.test(sql) || !commitBoundary.test(sql)) {
        throw new Error(`${name} must have explicit BEGIN/COMMIT boundaries.`);
      }
      return {
        name,
        checksum: createHash("sha256").update(sql).digest("hex"),
        body: sql.replace(beginBoundary, "").replace(commitBoundary, ""),
      };
    }),
  );
}

export async function applyReviewedMigrations(
  databaseUrl: string,
  directory?: string,
): Promise<string[]> {
  assertDirectOwnerDatabaseUrl(databaseUrl);
  const migrations = await readReviewedMigrations(directory);
  const client = new Client({ connectionString: databaseUrl });
  const applied: string[] = [];
  let lockHeld = false;

  await client.connect();
  try {
    const identity = await client.query<{ current_user: string; database_owner: string }>(`
      select current_user, pg_catalog.pg_get_userbyid(database.datdba) as database_owner
      from pg_catalog.pg_database database
      where database.datname = pg_catalog.current_database()
    `);
    const currentUser = identity.rows[0]?.current_user;
    if (
      currentUser === undefined ||
      reservedPrincipals.has(currentUser) ||
      identity.rows[0]?.database_owner !== currentUser
    ) {
      throw new Error("Reviewed migrations require the direct database owner credential.");
    }

    await client.query("select pg_advisory_lock(hashtextextended($1, 0))", [WAITLIST_MIGRATION_LOCK_KEY]);
    lockHeld = true;

    await client.query("begin");
    try {
      await client.query("create schema if not exists waitlist_private");
      await client.query("revoke all on schema waitlist_private from public");
      await client.query(`
        create table if not exists waitlist_private.applied_migrations (
          name text primary key,
          checksum text not null check (checksum ~ '^[a-f0-9]{64}$'),
          applied_at timestamptz not null default clock_timestamp()
        )
      `);
      await client.query("revoke all on waitlist_private.applied_migrations from public");
      await client.query("commit");
    } catch (error) {
      await client.query("rollback");
      throw error;
    }

    for (const migration of migrations) {
      const existing = await client.query<{ checksum: string }>(
        "select checksum from waitlist_private.applied_migrations where name = $1",
        [migration.name],
      );
      const recorded = existing.rows[0];
      if (recorded !== undefined) {
        if (recorded.checksum !== migration.checksum) {
          throw new Error(`${migration.name} changed after it was applied.`);
        }
        continue;
      }

      await client.query("begin");
      try {
        await client.query(migration.body);
        await client.query(
          "insert into waitlist_private.applied_migrations(name, checksum) values ($1, $2)",
          [migration.name, migration.checksum],
        );
        await client.query("commit");
        applied.push(migration.name);
      } catch (error) {
        await client.query("rollback");
        throw error;
      }
    }
    return applied;
  } finally {
    if (lockHeld) {
      await client
        .query("select pg_advisory_unlock(hashtextextended($1, 0))", [WAITLIST_MIGRATION_LOCK_KEY])
        .catch(() => undefined);
    }
    await client.end();
  }
}

async function main(): Promise<void> {
  if (process.argv.includes("--check")) {
    const migrations = await readReviewedMigrations();
    process.stdout.write(
      JSON.stringify({ migrations: migrations.map(({ name, checksum }) => ({ name, checksum })) }) + "\n",
    );
    return;
  }
  const databaseUrl = process.env.WAITLIST_MIGRATION_OWNER_DATABASE_URL;
  if (databaseUrl === undefined) {
    throw new Error("WAITLIST_MIGRATION_OWNER_DATABASE_URL is required.");
  }
  const applied = await applyReviewedMigrations(databaseUrl);
  process.stdout.write(JSON.stringify({ applied }) + "\n");
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(resolve(entrypoint)).href) {
  main().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : "Waitlist migration failed.";
    process.stderr.write(message + "\n");
    process.exitCode = 1;
  });
}
