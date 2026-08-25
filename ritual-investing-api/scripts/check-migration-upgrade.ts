import { randomUUID } from "node:crypto";
import process from "node:process";

import pg from "pg";

import { applyReviewedMigrations, readReviewedMigrations } from "./migrate.ts";

interface UpgradeMigration {
  name: string;
  body: string;
}

type ApplicableMigration = UpgradeMigration & { checksum: string };

const latestMigrationMarkers: Readonly<Record<string, string>> = {
  "0011_runtime_scope_and_review_fixes.sql":
    "select to_regprocedure('ritual_private.assert_runtime_scope()')::text as marker",
  "0012_member_experience.sql":
    "select to_regclass('public.onboarding_finalization_commands')::text as marker",
};

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

async function prepareMigrationLedger(client: pg.Client): Promise<void> {
  await client.query("create schema if not exists ritual_private");
  await client.query(`
    create table ritual_private.applied_migrations (
      name text primary key,
      checksum text not null,
      applied_at timestamptz not null default now()
    )
  `);
}

async function applyMigration(
  client: pg.Client,
  migration: ApplicableMigration,
): Promise<void> {
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

async function seedLegacyLedgerFixture(client: pg.Client): Promise<{
  entryIds: string[];
  positionId: string;
}> {
  const tenantId = randomUUID();
  const portfolioId = randomUUID();
  const idempotencyIds = [randomUUID(), randomUUID(), randomUUID()];
  const commandIds = [randomUUID(), randomUUID(), randomUUID()];
  const transactionIds = [randomUUID(), randomUUID(), randomUUID()];
  const entryIds = [randomUUID(), randomUUID(), randomUUID()];
  const assetId = "20000000-0000-4000-8000-000000000001";

  const seedVersion = await client.query<{ id: string }>(
    `select id from demo_seed_versions where is_current order by version desc limit 1`,
  );
  const seedVersionId = seedVersion.rows[0]?.id;
  if (seedVersionId === undefined)
    throw new Error("legacy fixture requires the published demo seed");
  await client.query("insert into tenants(id,status) values($1,'active')", [tenantId]);
  await client.query(
    "insert into tenant_demo_states(tenant_id,seed_version_id,reset_generation) values($1,$2,1)",
    [tenantId, seedVersionId],
  );
  await client.query(
    "insert into demo_portfolios(id,tenant_id,name,currency,status) values($1,$2,'Legacy basis fixture','USD','active')",
    [portfolioId, tenantId],
  );
  for (let index = 0; index < commandIds.length; index += 1) {
    await client.query(
      `insert into idempotency_records(id,tenant_id,reset_generation,operation,idempotency_key,request_hash,state,terminal_response,expires_at)
       values($1,$2,1,'legacy-ledger',$3,$4,'completed','{}'::jsonb,now()+interval '1 day')`,
      [
        idempotencyIds[index],
        tenantId,
        `legacy-${index}-${randomUUID()}`,
        "a".repeat(64),
      ],
    );
    await client.query(
      `insert into simulation_commands(id,tenant_id,reset_generation,portfolio_id,idempotency_id,command_type,status,committed_at)
       values($1,$2,1,$3,$4,'order','committed',now())`,
      [commandIds[index], tenantId, portfolioId, idempotencyIds[index]],
    );
    await client.query(
      `insert into ledger_transactions(id,tenant_id,reset_generation,portfolio_id,command_id,entry_type,effective_at,description_code)
       values($1,$2,1,$3,$4,'trade',now()+($5::text||' minutes')::interval,'legacy_trade')`,
      [transactionIds[index], tenantId, portfolioId, commandIds[index], index],
    );
  }
  for (const [index, quantity, price] of [
    [0, "10", 100] as const,
    [1, "10", 200] as const,
    [2, "-5", 300] as const,
  ]) {
    await client.query(
      `insert into position_ledger_entries(id,tenant_id,transaction_id,asset_id,quantity,unit_price_minor)
       values($1,$2,$3,$4,$5,$6)`,
      [entryIds[index], tenantId, transactionIds[index], assetId, quantity, price],
    );
  }
  await client.query(
    `insert into portfolio_positions(tenant_id,portfolio_id,asset_id,quantity,cost_basis_minor,as_of_transaction_id)
     values($1,$2,$3,15,2250,$4)`,
    [tenantId, portfolioId, assetId, transactionIds[2]],
  );
  return { entryIds, positionId: portfolioId };
}

async function seedDuplicateDeviceFixture(client: pg.Client): Promise<string[]> {
  const tenantIds = [randomUUID(), randomUUID()];
  for (const tenantId of tenantIds) {
    await client.query("insert into tenants(id,status) values($1,'active')", [tenantId]);
    await client.query(
      `insert into device_installations(tenant_id,platform,push_token_ciphertext,push_token_hash,status)
       values($1,'ios',$2,'duplicate-token-hash','active')`,
      [tenantId, `encrypted-${tenantId}`],
    );
  }
  return tenantIds;
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
  const fixtureDatabase = `ritual_u9_fixture_${suffix}`;
  const admin = new pg.Client({ connectionString: ownerUrl });
  await admin.connect();
  try {
    for (const database of [emptyDatabase, upgradeDatabase, fixtureDatabase]) {
      await admin.query(`create database ${database}`);
    }
    const emptyUrl = databaseUrlFor(ownerUrl, emptyDatabase);
    const upgradeUrl = databaseUrlFor(ownerUrl, upgradeDatabase);
    const fixtureUrl = databaseUrlFor(ownerUrl, fixtureDatabase);

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
      "public.outbox_dispatch_failures",
    ]);

    const fixtureClient = new pg.Client({ connectionString: fixtureUrl });
    await fixtureClient.connect();
    try {
      await prepareMigrationLedger(fixtureClient);
      const migrationByName = new Map(
        migrations.map((migration) => [migration.name, migration]),
      );
      for (const migration of migrations) {
        if (migration.name > "0005_member_state.sql") break;
        await applyMigration(fixtureClient, migration);
      }
      await fixtureClient.query("begin");
      const ledgerFixture = await seedLegacyLedgerFixture(fixtureClient);
      await fixtureClient.query("commit");
      const ledgerMigration = migrationByName.get("0006_simulated_ledger.sql");
      if (!ledgerMigration) throw new Error("missing 0006 simulated ledger migration");
      await applyMigration(fixtureClient, ledgerMigration);
      const replayed = await fixtureClient.query<{ id: string; delta: string }>(
        `select id,cost_basis_delta_minor::text delta
         from position_ledger_entries where id=any($1::uuid[])`,
        [ledgerFixture.entryIds],
      );
      const expectedDeltas = new Map(
        ledgerFixture.entryIds.map((id, index) => [id, ["1000", "2000", "-750"][index]]),
      );
      if (
        replayed.rows.length !== 3 ||
        replayed.rows.some((row) => row.delta !== expectedDeltas.get(row.id))
      ) {
        throw new Error("legacy ledger cost-basis replay did not preserve a profitable partial sale");
      }
      const reconciled = await fixtureClient.query<{ quantity: string; basis: string }>(
        `select quantity::text quantity,cost_basis_minor::text basis
         from portfolio_positions where portfolio_id=$1`,
        [ledgerFixture.positionId],
      );
      if (
        Number(reconciled.rows[0]?.quantity) !== 15 ||
        reconciled.rows[0]?.basis !== "2250"
      ) {
        throw new Error("legacy ledger upgrade did not reconcile the portfolio projection");
      }

      const duplicateTenantIds = await seedDuplicateDeviceFixture(fixtureClient);
      const asyncMigration = migrationByName.get("0007_async_privacy.sql");
      if (!asyncMigration) throw new Error("missing 0007 async privacy migration");
      await applyMigration(fixtureClient, asyncMigration);
      const revoked = await fixtureClient.query<{ status: string; ciphertext: string }>(
        `select status,push_token_ciphertext ciphertext from device_installations
         where tenant_id=any($1::uuid[]) order by tenant_id`,
        [duplicateTenantIds],
      );
      if (
        revoked.rows.length !== 2 ||
        revoked.rows.some((row) => row.status !== "revoked" || row.ciphertext !== "revoked")
      ) {
        throw new Error("ambiguous active push-token registrations were not all revoked");
      }

      const adminMigration = migrationByName.get("0008_admin_dashboard.sql");
      if (!adminMigration) throw new Error("missing 0008 admin dashboard migration");
      await applyMigration(fixtureClient, adminMigration);
      const unknownSubmitter = await fixtureClient.query<{ submitted_by: string | null }>(
        `select submitted_by::text from coven_qualifications
         where id='64000000-0000-4000-8000-000000000001'`,
      );
      if (unknownSubmitter.rows[0]?.submitted_by !== null) {
        throw new Error("legacy Coven qualification submitter was fabricated during upgrade");
      }
    } finally {
      await fixtureClient.end();
    }

    const prior = migrations.slice(0, -1);
    const latest = migrations.at(-1)!;
    const latestMarkerQuery = latestMigrationMarkers[latest.name];
    if (latestMarkerQuery === undefined) {
      throw new Error(`upgrade marker is not configured for ${latest.name}`);
    }
    const client = new pg.Client({ connectionString: upgradeUrl });
    await client.connect();
    try {
      await prepareMigrationLedger(client);
      for (const migration of prior) await applyMigration(client, migration);
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
      const rolledBack = await client.query<{ marker: string | null }>(
        latestMarkerQuery,
      );
      if (rolledBack.rows[0]?.marker !== null) {
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
      "public.outbox_dispatch_failures",
    ]);
    if ((await applyReviewedMigrations(upgradeUrl)).length !== 0) {
      throw new Error("upgraded database repeat migration was not a no-op");
    }
    const upgraded = new pg.Client({ connectionString: upgradeUrl });
    await upgraded.connect();
    try {
      const marker = await upgraded.query<{ marker: string | null }>(
        latestMarkerQuery,
      );
      if (marker.rows[0]?.marker === null)
        throw new Error("latest migration marker is missing after upgrade");
    } finally {
      await upgraded.end();
    }
    process.stdout.write(
      `verified empty, N-1 to N, interrupted, and repeat migration paths (${migrations.length} migrations)\n`,
    );
  } finally {
    for (const database of [emptyDatabase, upgradeDatabase, fixtureDatabase]) {
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
