import { randomUUID } from "node:crypto";
import process from "node:process";

import pg from "pg";

import { applyReviewedMigrations, readReviewedMigrations } from "./migrate.ts";

interface UpgradeMigration {
  name: string;
  body: string;
}

const destructiveSql =
  /\b(drop\s+(?:table|column|type|schema)|alter\s+table\b[^;]*?\bdrop\s+column\b|truncate\b)\b/i;
const contractMarker = /--\s*ritual:contract-after-client-drain\b/i;

export function assertUpgradePlan(
  migrations: readonly UpgradeMigration[],
): void {
  for (const migration of migrations) {
    if (
      destructiveSql.test(migration.body) &&
      !contractMarker.test(migration.body)
    ) {
      throw new Error(
        `${migration.name} contains destructive SQL without a reviewed contract phase`,
      );
    }
  }
}

function databaseUrlFor(ownerUrl: string, database: string): string {
  const parsed = new URL(ownerUrl);
  parsed.pathname = `/${database}`;
  return parsed.toString();
}

async function assertRelations(
  databaseUrl: string,
  relations: readonly string[],
): Promise<void> {
  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    for (const relation of relations) {
      const result = await client.query<{ relation: string | null }>(
        "select to_regclass($1)::text as relation",
        [relation],
      );
      if (result.rows[0]?.relation === null) {
        throw new Error(`expected relation ${relation} is missing`);
      }
    }
  } finally {
    await client.end();
  }
}

async function main(): Promise<void> {
  const ownerUrl = process.env.DATABASE_OWNER_URL;
  if (!ownerUrl) throw new Error("DATABASE_OWNER_URL is required");
  const migrations = await readReviewedMigrations();
  assertUpgradePlan(migrations);
  if (migrations.length < 2)
    throw new Error("upgrade check requires N-1 and N");

  const suffix = randomUUID().replaceAll("-", "").slice(0, 12);
  const emptyDatabase = `ritual_u9_empty_${suffix}`;
  const upgradeDatabase = `ritual_u9_upgrade_${suffix}`;
  const admin = new pg.Client({ connectionString: ownerUrl });
  await admin.connect();
  try {
    for (const database of [emptyDatabase, upgradeDatabase]) {
      await admin.query(`create database ${database}`);
    }
    const emptyUrl = databaseUrlFor(ownerUrl, emptyDatabase);
    const upgradeUrl = databaseUrlFor(ownerUrl, upgradeDatabase);

    const first = await applyReviewedMigrations(emptyUrl);
    if (first.length !== migrations.length) {
      throw new Error(
        "empty database did not apply the complete migration chain",
      );
    }
    if ((await applyReviewedMigrations(emptyUrl)).length !== 0) {
      throw new Error("repeat migration was not a no-op");
    }
    await assertRelations(emptyUrl, [
      "public.briefing_templates",
      "public.moderation_case_decisions",
      "public.admin_audit_checkpoints",
    ]);

    const prior = migrations.slice(0, -1);
    const latest = migrations.at(-1)!;
    const client = new pg.Client({ connectionString: upgradeUrl });
    await client.connect();
    try {
      await client.query("create schema if not exists ritual_private");
      await client.query(`
        create table ritual_private.applied_migrations (
          name text primary key,
          checksum text not null,
          applied_at timestamptz not null default now()
        )
      `);
      for (const migration of prior) {
        await client.query("begin");
        try {
          await client.query(migration.body);
          await client.query(
            "insert into ritual_private.applied_migrations(name, checksum) values ($1, $2)",
            [migration.name, migration.checksum],
          );
          await client.query("commit");
        } catch (error) {
          await client.query("rollback");
          throw error;
        }
      }
      for (const relation of [
        "public.outbox_events",
        "public.deletion_tombstones",
      ]) {
        const result = await client.query<{ relation: string | null }>(
          "select to_regclass($1)::text as relation",
          [relation],
        );
        if (result.rows[0]?.relation === null)
          throw new Error(`N-1 relation ${relation} is missing`);
      }

      await client.query("begin");
      await client.query(latest.body);
      await client.query("rollback");
      const rolledBack = await client.query<{ relation: string | null }>(
        "select to_regclass('public.admin_audit_checkpoints')::text as relation",
      );
      if (rolledBack.rows[0]?.relation !== null) {
        throw new Error("interrupted migration left N schema objects behind");
      }
      const interrupted = await client.query<{ applied: string | null }>(
        "select max(name) as applied from ritual_private.applied_migrations where name = $1",
        [latest.name],
      );
      if (interrupted.rows[0]?.applied !== null) {
        throw new Error("interrupted migration was recorded as applied");
      }
    } finally {
      await client.end();
    }

    const applied = await applyReviewedMigrations(upgradeUrl);
    if (applied.length !== 1 || applied[0] !== latest.name) {
      throw new Error("N-1 database did not advance by exactly migration N");
    }
    await assertRelations(upgradeUrl, [
      "public.outbox_events",
      "public.briefing_templates",
      "public.moderation_case_decisions",
      "public.admin_audit_checkpoints",
    ]);
    if ((await applyReviewedMigrations(upgradeUrl)).length !== 0) {
      throw new Error("upgraded database repeat migration was not a no-op");
    }
    process.stdout.write(
      `verified empty, N-1 to N, interrupted, and repeat migration paths (${migrations.length} migrations)\n`,
    );
  } finally {
    for (const database of [emptyDatabase, upgradeDatabase]) {
      await admin
        .query(`drop database if exists ${database} with (force)`)
        .catch(() => undefined);
    }
    await admin.end();
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  await main();
}
