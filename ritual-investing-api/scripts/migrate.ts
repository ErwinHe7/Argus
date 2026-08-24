import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";

import pg from "pg";

const migrationName = /^\d{4}_[a-z0-9_]+\.sql$/;

interface Migration {
  name: string;
  checksum: string;
  body: string;
}
export async function readReviewedMigrations(
  directory = resolve(process.cwd(), "drizzle"),
): Promise<Migration[]> {
  const names = (await readdir(directory))
    .filter((name) => migrationName.test(name))
    .sort();
  if (names.length === 0) {
    throw new Error("no reviewed SQL migrations found");
  }

  return Promise.all(
    names.map(async (name) => {
      const sql = await readFile(resolve(directory, name), "utf8");
      if (!/^BEGIN;\s*/i.test(sql) || !/\s*COMMIT;\s*$/i.test(sql)) {
        throw new Error(`${name} must have explicit BEGIN/COMMIT boundaries`);
      }
      return {
        name,
        checksum: createHash("sha256").update(sql).digest("hex"),
        body: sql.replace(/^BEGIN;\s*/i, "").replace(/\s*COMMIT;\s*$/i, ""),
      };
    }),
  );
}

export async function applyReviewedMigrations(
  databaseUrl: string,
  directory?: string,
): Promise<string[]> {
  const migrations = await readReviewedMigrations(directory);
  const client = new pg.Client({ connectionString: databaseUrl });
  const applied: string[] = [];
  await client.connect();
  try {
    await client.query("select pg_advisory_lock(hashtext('ritual-reviewed-migrations'))");
    await client.query("create schema if not exists ritual_private");
    await client.query(`
      create table if not exists ritual_private.applied_migrations (
        name text primary key,
        checksum text not null,
        applied_at timestamptz not null default now()
      )
    `);

    for (const migration of migrations) {
      const existing = await client.query<{ checksum: string }>(
        "select checksum from ritual_private.applied_migrations where name = $1",
        [migration.name],
      );
      const recorded = existing.rows[0];
      if (recorded !== undefined) {
        if (recorded.checksum !== migration.checksum) {
          throw new Error(`${migration.name} changed after it was applied`);
        }
        continue;
      }

      await client.query("begin");
      try {
        await client.query(migration.body);
        await client.query(
          "insert into ritual_private.applied_migrations(name, checksum) values ($1, $2)",
          [migration.name, migration.checksum],
        );
        await client.query("commit");
        applied.push(migration.name);
      } catch (error) {
        await client.query("rollback");
        throw error;
      }
    }
  } finally {
    await client
      .query("select pg_advisory_unlock(hashtext('ritual-reviewed-migrations'))")
      .catch(() => undefined);
    await client.end();
  }
  return applied;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv.includes("--check")) {
    const migrations = await readReviewedMigrations();
    process.stdout.write(`validated ${migrations.length} reviewed migrations\n`);
  } else {
    const databaseUrl = process.env.DATABASE_OWNER_URL;
    if (databaseUrl === undefined || databaseUrl.length === 0) {
      throw new Error("DATABASE_OWNER_URL is required for migrations");
    }
    const applied = await applyReviewedMigrations(databaseUrl);
    process.stdout.write(
      applied.length === 0
        ? "schema already current\n"
        : `applied ${applied.join(", ")}\n`,
    );
  }
}
