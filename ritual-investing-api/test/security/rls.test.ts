import { randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import pg from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { applyReviewedMigrations } from "../../scripts/migrate";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const tenantTables = [
  "tenants",
  "accounts",
  "profiles",
  "preferences",
  "astrology_profiles",
  "investor_profiles",
  "onboarding_states",
  "consent_records",
  "device_installations",
  "notification_preferences",
  "daily_ritual_assignments",
  "circles",
  "circle_assets",
  "saved_assets",
  "saved_grimoires",
  "saved_circle_templates",
  "saved_coven_entries",
  "tenant_demo_states",
  "demo_portfolios",
  "portfolio_target_allocations",
  "idempotency_records",
  "simulation_commands",
  "demo_funding_sources",
  "simulated_orders",
  "simulated_order_fills",
  "ledger_transactions",
  "cash_ledger_entries",
  "position_ledger_entries",
  "portfolio_positions",
  "portfolio_balance_snapshots",
  "recurring_plans",
  "recurring_plan_allocations",
  "recurring_plan_runs",
  "rebalance_previews",
  "rebalance_preview_trades",
  "rebalance_preview_allocations",
  "order_previews",
  "intentions",
  "projection_runs",
  "projection_points",
  "briefings",
  "briefing_sections",
  "tenant_entitlements",
  "entitlement_events",
  "demo_checkout_sessions",
  "demo_reset_events",
  "notifications",
  "notification_deliveries",
  "privacy_requests",
  "privacy_export_artifacts",
  "content_reports",
] as const;

describe("restricted database roles and RLS", () => {
  it("forces RLS and defines USING plus WITH CHECK for tenant tables", async () => {
    const sql = `${await readFile(
      `${apiRoot}/drizzle/0002_roles_and_rls.sql`,
      "utf8",
    )}\n${await readFile(
      `${apiRoot}/drizzle/0006_simulated_ledger.sql`,
      "utf8",
    )}`;

    for (const table of tenantTables) {
      expect(sql, `RLS is not enabled for ${table}`).toMatch(
        new RegExp(
          `alter\\s+table\\s+${table}\\s+enable\\s+row\\s+level\\s+security`,
          "i",
        ),
      );
      expect(sql, `RLS is not forced for ${table}`).toMatch(
        new RegExp(
          `alter\\s+table\\s+${table}\\s+force\\s+row\\s+level\\s+security`,
          "i",
        ),
      );
      expect(sql, `tenant policy allowlist is missing ${table}`).toMatch(
        new RegExp(`(?:on\\s+${table}\\b|'${table}')`, "i"),
      );
    }
    expect(sql).toMatch(
      /create\s+policy[\s\S]*using\s*\([\s\S]*with\s+check\s*\(/i,
    );
  });

  it("defines non-owner, non-BYPASSRLS roles with narrow grants", async () => {
    const sql = await readFile(
      `${apiRoot}/drizzle/0002_roles_and_rls.sql`,
      "utf8",
    );

    for (const role of [
      "ritual_public",
      "ritual_identity_resolver",
      "ritual_runtime",
      "ritual_staff",
      "ritual_scheduler",
      "ritual_privacy_purge",
    ]) {
      expect(sql).toMatch(
        new RegExp(
          `create\\s+role\\s+${role}\\s+noinherit\\s+nologin\\s+nobypassrls`,
          "i",
        ),
      );
    }
    expect(sql).not.toMatch(
      /grant\s+.+\s+on\s+accounts\s+to\s+ritual_identity_resolver/i,
    );
    expect(sql).not.toMatch(
      /grant\s+.+\s+on\s+(?:circles|demo_portfolios|ledger_transactions)\s+to\s+ritual_staff/i,
    );
    expect(sql).not.toMatch(
      /grant\s+select,\s*insert,\s*update,\s*delete\s+on\s+table\s+[\s\S]*?consent_records[\s\S]*?to\s+ritual_runtime/i,
    );
  });

  it("exposes only allowlisted public projections", async () => {
    const sql = await readFile(
      `${apiRoot}/drizzle/0002_roles_and_rls.sql`,
      "utf8",
    );

    expect(sql).toMatch(
      /create\s+(?:or\s+replace\s+)?view\s+ritual_public\.daily_ritual_preview/i,
    );
    expect(sql).toMatch(
      /create\s+(?:or\s+replace\s+)?view\s+ritual_public\.asset_codex_preview/i,
    );
    expect(sql).toMatch(
      /create\s+(?:or\s+replace\s+)?view\s+ritual_public\.coven_preview/i,
    );
    for (const view of [
      "daily_ritual_preview",
      "asset_codex_preview",
      "coven_preview",
    ]) {
      const match = sql.match(
        new RegExp(`CREATE VIEW ritual_public\\.${view}[\\s\\S]*?;`, "i"),
      );
      expect(match?.[0]).not.toMatch(
        /review_notes|author_staff_id|tenant_id|claim_id|canonical_url/i,
      );
    }
  });

  it("resolves exactly one active account through a fixed-search-path function", async () => {
    const sql = await readFile(
      `${apiRoot}/drizzle/0002_roles_and_rls.sql`,
      "utf8",
    );

    expect(sql).toMatch(
      /function\s+ritual_private\.resolve_account_context\s*\(verified_subject\s+text\)/i,
    );
    expect(sql).toMatch(/security\s+definer/i);
    expect(sql).toMatch(
      /set\s+search_path\s*=\s*pg_catalog,\s*public,\s*ritual_private/i,
    );
    expect(sql).toMatch(
      /grant\s+execute\s+on\s+function\s+ritual_private\.resolve_account_context\(text\)\s+to\s+ritual_identity_resolver/i,
    );
  });
});

const postgresUrl = process.env.TEST_DATABASE_URL;
const tenantA = randomUUID();
const tenantB = randomUUID();
const tenantPurge = randomUUID();
const circleA = randomUUID();
const circleB = randomUUID();
const circlePurge = randomUUID();
const assetId = randomUUID();
const tombstoneId = randomUUID();
const seedVersionId = randomUUID();
const portfolioA = randomUUID();
const accountA = randomUUID();
const accountB = randomUUID();
const consentA = randomUUID();
const consentPurge = randomUUID();
const reportPurge = randomUUID();
const moderationPurge = randomUUID();
const reportTarget = randomUUID();
const subjectA = `auth0|${tenantA}`;
const subjectB = `auth0|${tenantB}`;
const seedVersionNumber =
  (Number.parseInt(seedVersionId.slice(0, 8), 16) % 2_000_000_000) + 1;

describe.skipIf(postgresUrl === undefined)(
  "PostgreSQL restricted-role integration",
  () => {
    let owner: pg.Client;

    async function bootstrapInPostgres(subject: string) {
      const client = new pg.Client({ connectionString: postgresUrl });
      await client.connect();
      try {
        await client.query("begin");
        await client.query("set local role ritual_bootstrap");
        const result = await client.query(
          "select * from ritual_private.bootstrap_member_account($1)",
          [subject],
        );
        await client.query("commit");
        return result.rows[0];
      } catch (error) {
        await client.query("rollback").catch(() => undefined);
        throw error;
      } finally {
        await client.end();
      }
    }

    beforeAll(async () => {
      if (postgresUrl === undefined) return;
      const bootstrap = new pg.Client({ connectionString: postgresUrl });
      await bootstrap.connect();
      await bootstrap.query(
        "create table if not exists n_minus_one_worker_fixture (id text primary key, payload text not null)",
      );
      await bootstrap.query(
        "insert into n_minus_one_worker_fixture(id, payload) values ('legacy', 'still-readable') on conflict (id) do nothing",
      );
      await bootstrap.end();
      const applied = await applyReviewedMigrations(postgresUrl);
      expect(
        applied.every((name) =>
          [
            "0001_ritual_foundation.sql",
            "0002_roles_and_rls.sql",
            "0003_identity_bootstrap.sql",
            "0004_editorial_catalog.sql",
            "0005_member_state.sql",
            "0006_simulated_ledger.sql",
            "0007_async_privacy.sql",
            "0008_admin_dashboard.sql",
            "0009_observability_audit.sql",
          ].includes(name),
        ),
      ).toBe(true);
      expect(await applyReviewedMigrations(postgresUrl)).toEqual([]);

      owner = new pg.Client({ connectionString: postgresUrl });
      await owner.connect();
      await owner.query(
        `insert into tenants(id, status) values
        ($1, 'active'), ($2, 'active'), ($3, 'purging')`,
        [tenantA, tenantB, tenantPurge],
      );
      await owner.query(
        `insert into accounts(id, tenant_id, auth0_subject, status) values
        ($1, $2, $3, 'active'),
        ($4, $5, $6, 'active')`,
        [accountA, tenantA, subjectA, accountB, tenantB, subjectB],
      );
      await owner.query(
        `insert into assets(id, slug, symbol, name, asset_type, currency, exchange, status)
       values ($1, $2, $3, 'Ritual Test Asset', 'etf', 'USD', 'DEMO', 'active')`,
        [assetId, `ritual-test-${assetId}`, assetId.slice(0, 8).toUpperCase()],
      );
      await owner.query(
        `insert into circles(id, tenant_id, title, description) values
        ($1, $2, 'Tenant A Circle', ''),
        ($3, $4, 'Tenant B Circle', ''),
        ($5, $6, 'Purge Circle', '')`,
        [circleA, tenantA, circleB, tenantB, circlePurge, tenantPurge],
      );
      await owner.query(
        `insert into consent_records(id, tenant_id, policy_code, policy_version, decision)
       values ($1, $2, 'terms', '1', 'accepted'),
              ($3, $4, 'terms', '1', 'accepted')`,
        [consentA, tenantA, consentPurge, tenantPurge],
      );
      await owner.query(
        `insert into editorial_items(id, kind, slug, status)
       values ($1, 'ritual', $2, 'published')`,
        [reportTarget, `purge-report-target-${reportTarget}`],
      );
      await owner.query(
        `insert into content_reports(id, tenant_id, target_kind, target_id, reason_code)
       values ($1, $2, 'ritual', $3, 'incorrect')`,
        [reportPurge, tenantPurge, reportTarget],
      );
      await owner.query(
        `insert into moderation_cases(id, report_id, status)
       values ($1, $2, 'open')`,
        [moderationPurge, reportPurge],
      );
      await owner.query(
        `insert into deletion_tombstones(id, tenant_id, subject_hash, effective_at, purge_generation, status)
       values ($1, $2, $3, now(), 1, 'pending')`,
        [tombstoneId, tenantPurge, `subject-hash-${tenantPurge}`],
      );
      await owner.query(
        `insert into demo_seed_versions(id, version, fixture_hash, published_at, is_current)
       values ($1, $2, $3, now(), false)`,
        [
          seedVersionId,
          seedVersionNumber,
          `integration-fixture-${seedVersionId}`,
        ],
      );
      await owner.query(
        `insert into tenant_demo_states(tenant_id, seed_version_id, reset_generation)
       values ($1, $2, 2)`,
        [tenantA, seedVersionId],
      );
      await owner.query(
        `insert into demo_portfolios(
           id, tenant_id, name, currency, status, reset_generation, is_default
         ) values ($1, $2, 'Demo Portfolio', 'USD', 'active', 2, true)`,
        [portfolioA, tenantA],
      );
    }, 30_000);

    afterAll(async () => {
      await owner?.end();
    });

    it("migrates the complete catalog and installs forced policies", async () => {
      const tables = await owner.query<{ table_name: string }>(
        "select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE'",
      );
      expect(tables.rows.length).toBeGreaterThanOrEqual(92);

      const unforced = await owner.query<{ relname: string }>(
        `
      select c.relname
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = any($1::text[]) and not c.relforcerowsecurity
    `,
        [tenantTables],
      );
      expect(unforced.rows).toEqual([]);

      const roles = await owner.query<{
        rolname: string;
        rolsuper: boolean;
        rolbypassrls: boolean;
        rolcanlogin: boolean;
      }>(
        `
      select rolname, rolsuper, rolbypassrls, rolcanlogin from pg_roles
      where rolname = any($1::text[])
    `,
        [
          [
            "ritual_public",
            "ritual_identity_resolver",
            "ritual_runtime",
            "ritual_staff",
            "ritual_scheduler",
            "ritual_privacy_purge",
          ],
        ],
      );
      expect(roles.rows).toHaveLength(6);
      expect(
        roles.rows.every(
          (role) => !role.rolsuper && !role.rolbypassrls && !role.rolcanlogin,
        ),
      ).toBe(true);
      expect(
        (await owner.query("select payload from n_minus_one_worker_fixture"))
          .rows,
      ).toEqual([{ payload: "still-readable" }]);
    });

    it("rolls a failed migration back without recording or partially granting it", async () => {
      const directory = await mkdtemp(
        resolve(tmpdir(), "ritual-failed-migration-"),
      );
      try {
        await writeFile(
          resolve(directory, "0003_expected_failure.sql"),
          `BEGIN;
CREATE TABLE ritual_private.failed_migration_probe (id integer PRIMARY KEY);
GRANT SELECT ON ritual_private.failed_migration_probe TO ritual_runtime;
SELECT * FROM ritual_private.relation_that_does_not_exist;
COMMIT;
`,
        );
        await expect(
          applyReviewedMigrations(postgresUrl!, directory),
        ).rejects.toMatchObject({
          code: "42P01",
        });
        expect(
          (
            await owner.query(
              "select to_regclass('ritual_private.failed_migration_probe') as relation",
            )
          ).rows,
        ).toEqual([{ relation: null }]);
        expect(
          (
            await owner.query(
              "select name from ritual_private.applied_migrations where name = '0003_expected_failure.sql'",
            )
          ).rows,
        ).toEqual([]);
        const circleCount = await owner.query<{ count: number }>(
          "select count(*)::integer as count from circles",
        );
        expect(circleCount.rows[0]?.count).toBeGreaterThanOrEqual(3);
      } finally {
        await rm(directory, { recursive: true, force: true });
      }
    });

    it("resolves one active subject without granting account-table reads", async () => {
      const client = new pg.Client({ connectionString: postgresUrl });
      await client.connect();
      await client.query("begin");
      await client.query("set local role ritual_identity_resolver");
      const resolved = await client.query(
        "select * from ritual_private.resolve_account_context($1)",
        [subjectA],
      );
      expect(resolved.rows).toEqual([
        expect.objectContaining({
          tenant_id: tenantA,
          account_status: "active",
          tenant_status: "active",
        }),
      ]);
      await expect(
        client.query("select * from accounts"),
      ).rejects.toMatchObject({ code: "42501" });
      await client.query("rollback");
      await client.end();
    });

    it("concurrently bootstraps one canonical account without orphan tenants", async () => {
      const subject = `auth0|bootstrap-${randomUUID()}`;
      const [first, second] = await Promise.all([
        bootstrapInPostgres(subject),
        bootstrapInPostgres(subject),
      ]);

      expect(first).toMatchObject({
        account_id: second.account_id,
        portfolio_id: second.portfolio_id,
        account_status: "active",
      });
      const rows = await owner.query<{
        account_count: number;
        tenant_count: number;
        profile_count: number;
        portfolio_count: number;
        entitlement_count: number;
      }>(
        `
      select
        count(distinct account.id)::integer as account_count,
        count(distinct tenant.id)::integer as tenant_count,
        count(distinct profile.tenant_id)::integer as profile_count,
        count(distinct portfolio.id)::integer as portfolio_count,
        count(distinct entitlement.id)::integer as entitlement_count
      from accounts account
      join tenants tenant on tenant.id = account.tenant_id
      join profiles profile on profile.tenant_id = tenant.id
      join demo_portfolios portfolio on portfolio.tenant_id = tenant.id
      join tenant_entitlements entitlement on entitlement.tenant_id = tenant.id
      where account.auth0_subject = $1
    `,
        [subject],
      );
      expect(rows.rows).toEqual([
        {
          account_count: 1,
          tenant_count: 1,
          profile_count: 1,
          portfolio_count: 1,
          entitlement_count: 1,
        },
      ]);
    });

    it("does not bootstrap an inactive or deletion-tombstoned subject", async () => {
      await owner.query(
        "update accounts set status = 'suspended' where auth0_subject = $1",
        [subjectA],
      );
      await expect(bootstrapInPostgres(subjectA)).rejects.toMatchObject({
        message: "subject_not_eligible",
      });
      await owner.query(
        "update accounts set status = 'active' where auth0_subject = $1",
        [subjectA],
      );

      const deletedSubject = `auth0|deleted-${randomUUID()}`;
      await owner.query(
        `insert into deletion_tombstones(tenant_id, subject_hash, effective_at, purge_generation, status)
       values ($1, encode(digest($2, 'sha256'), 'hex'), now(), 1, 'purged')`,
        [randomUUID(), deletedSubject],
      );
      await expect(bootstrapInPostgres(deletedSubject)).rejects.toMatchObject({
        message: "subject_previously_deleted",
      });
    });

    it("defaults to no rows and confines reads and writes to local context", async () => {
      const client = new pg.Client({ connectionString: postgresUrl });
      await client.connect();
      await client.query("begin");
      await client.query("set local role ritual_runtime");
      expect((await client.query("select id from circles")).rows).toEqual([]);
      await client.query("select set_config('ritual.tenant_id', $1, true)", [
        tenantA,
      ]);
      expect(
        (await client.query("select id from circles order by id")).rows,
      ).toEqual([{ id: circleA }]);
      expect(
        (
          await client.query(
            "update circles set title = 'hidden' where id = $1 returning id",
            [circleB],
          )
        ).rows,
      ).toEqual([]);
      expect(
        (
          await client.query("delete from circles where id = $1 returning id", [
            circleB,
          ])
        ).rows,
      ).toEqual([]);
      await client.query("commit");
      await client.end();
    });

    it("rejects WITH CHECK tenant overrides and cross-tenant attachments", async () => {
      const tenantOverride = new pg.Client({ connectionString: postgresUrl });
      await tenantOverride.connect();
      await tenantOverride.query("begin");
      await tenantOverride.query("set local role ritual_runtime");
      await tenantOverride.query(
        "select set_config('ritual.tenant_id', $1, true)",
        [tenantA],
      );
      await expect(
        tenantOverride.query(
          "insert into circles(tenant_id, title, description) values ($1, 'forbidden', '')",
          [tenantB],
        ),
      ).rejects.toMatchObject({ code: "42501" });
      await tenantOverride.query("rollback");
      await tenantOverride.end();

      const crossAttach = new pg.Client({ connectionString: postgresUrl });
      await crossAttach.connect();
      await crossAttach.query("begin");
      await crossAttach.query("set local role ritual_runtime");
      await crossAttach.query(
        "select set_config('ritual.tenant_id', $1, true)",
        [tenantA],
      );
      await expect(
        crossAttach.query(
          "insert into circle_assets(tenant_id, circle_id, asset_id, ordinal) values ($1, $2, $3, 1)",
          [tenantA, circleB, assetId],
        ),
      ).rejects.toMatchObject({ code: "23503" });
      await crossAttach.query("rollback");
      await crossAttach.end();
    });

    it("denies role escalation, staff tenant reads, and immutable rewrites", async () => {
      const runtime = new pg.Client({ connectionString: postgresUrl });
      await runtime.connect();
      await runtime.query("begin");
      await runtime.query("set local role ritual_runtime");
      await expect(
        runtime.query("alter table circles disable row level security"),
      ).rejects.toMatchObject({ code: "42501" });
      await runtime.query("rollback");
      await runtime.query("begin");
      await runtime.query("set local role ritual_runtime");
      await runtime.query("select set_config('ritual.tenant_id', $1, true)", [
        tenantA,
      ]);
      await expect(
        runtime.query("update consent_records set decision = 'withdrawn'"),
      ).rejects.toMatchObject({ code: "42501" });
      await runtime.query("rollback");
      await runtime.query("begin");
      await runtime.query("set local role ritual_runtime");
      await runtime.query("select set_config('ritual.tenant_id', $1, true)", [
        tenantA,
      ]);
      await expect(
        runtime.query("delete from accounts where tenant_id = $1", [tenantA]),
      ).rejects.toMatchObject({ code: "42501" });
      await runtime.query("rollback");
      await runtime.end();

      await expect(
        owner.query(
          "update consent_records set decision = 'withdrawn' where id = $1",
          [consentA],
        ),
      ).rejects.toMatchObject({ code: "55000" });

      const staff = new pg.Client({ connectionString: postgresUrl });
      await staff.connect();
      await staff.query("begin");
      await staff.query("set local role ritual_staff");
      await expect(staff.query("select * from circles")).rejects.toMatchObject({
        code: "42501",
      });
      await staff.query("rollback");
      await staff.end();
    });

    it("fences stale generations and incomplete ledger commits", async () => {
      const stale = new pg.Client({ connectionString: postgresUrl });
      await stale.connect();
      await stale.query("begin");
      await stale.query("set local role ritual_runtime");
      await stale.query("select set_config('ritual.tenant_id', $1, true)", [
        tenantA,
      ]);
      await expect(
        stale.query(
          `insert into idempotency_records(
          tenant_id, reset_generation, operation, idempotency_key, request_hash, state, expires_at
        ) values ($1, 1, 'order', 'stale-key', 'hash-a', 'processing', now() + interval '1 hour')`,
          [tenantA],
        ),
      ).rejects.toMatchObject({ code: "23514" });
      await stale.query("rollback");
      await stale.end();

      const incomplete = new pg.Client({ connectionString: postgresUrl });
      await incomplete.connect();
      await incomplete.query("begin");
      await incomplete.query("set local role ritual_runtime");
      await incomplete.query(
        "select set_config('ritual.tenant_id', $1, true)",
        [tenantA],
      );
      const idempotency = await incomplete.query<{ id: string }>(
        `insert into idempotency_records(
        tenant_id, reset_generation, operation, idempotency_key, request_hash, state, expires_at
      ) values ($1, 2, 'order', 'current-key', 'hash-b', 'processing', now() + interval '1 hour') returning id`,
        [tenantA],
      );
      await incomplete.query(
        `insert into simulation_commands(
        tenant_id, reset_generation, portfolio_id, idempotency_id, command_type, status, committed_at
      ) values ($1, 2, $2, $3, 'order', 'committed', now())`,
        [tenantA, portfolioA, idempotency.rows[0]?.id],
      );
      await expect(incomplete.query("commit")).rejects.toMatchObject({
        code: "23514",
      });
      await incomplete.query("rollback").catch(() => undefined);
      await incomplete.end();
    });

    it("allows only the scoped purge function to remove one purging tenant", async () => {
      await owner.query(
        `insert into deletion_journal_confirmations(
           tombstone_id,purge_generation,r2_key,body_checksum,confirmed_at
         ) values ($1,1,$2,$3,now())
         on conflict (tombstone_id,purge_generation) do nothing`,
        [tombstoneId, `deletion-deny/v1/${tombstoneId}/1.json`, "d".repeat(64)],
      );
      await owner.query(
        `insert into deletion_object_receipts(
           tombstone_id,purge_generation,object_class,prefix,listing_checksum,confirmed_empty_at
         ) values
           ($1,1,'privacy_exports',$2,$4,now()),
           ($1,1,'tenant_quarantine',$3,$4,now())
         on conflict (tombstone_id,purge_generation,object_class) do nothing`,
        [
          tombstoneId,
          `privacy-exports/v1/${tenantPurge}/`,
          `tenant-quarantine/v1/${tenantPurge}/`,
          "e".repeat(64),
        ],
      );
      const purge = new pg.Client({ connectionString: postgresUrl });
      await purge.connect();
      await purge.query("begin");
      await purge.query("set local role ritual_privacy_purge");
      const result = await purge.query(
        "select ritual_private.purge_tombstoned_tenant($1, 1) as receipt_id",
        [tombstoneId],
      );
      expect(result.rows[0]?.receipt_id).toEqual(expect.any(String));
      await purge.query("commit");
      await purge.query("begin");
      await purge.query("set local role ritual_privacy_purge");
      const replay = await purge.query(
        "select ritual_private.purge_tombstoned_tenant($1, 1) as receipt_id",
        [tombstoneId],
      );
      expect(replay.rows[0]?.receipt_id).toBe(result.rows[0]?.receipt_id);
      await purge.query("commit");
      await purge.end();

      expect(
        (
          await owner.query("select id from tenants where id = $1", [
            tenantPurge,
          ])
        ).rows,
      ).toEqual([]);
      expect(
        (
          await owner.query("select id from circles where tenant_id = $1", [
            tenantPurge,
          ])
        ).rows,
      ).toEqual([]);
      expect(
        (
          await owner.query("select id from moderation_cases where id = $1", [
            moderationPurge,
          ])
        ).rows,
      ).toEqual([]);
      expect(
        (
          await owner.query(
            "select status from deletion_tombstones where id = $1",
            [tombstoneId],
          )
        ).rows,
      ).toEqual([{ status: "purged" }]);
      expect(
        (
          await owner.query(
            "select purge_generation from purge_receipts where tombstone_id = $1",
            [tombstoneId],
          )
        ).rows,
      ).toEqual([{ purge_generation: 1 }]);
    });

    it("publishes views without tenant, staff, draft, or evidence-detail columns", async () => {
      const columns = await owner.query<{ column_name: string }>(`
      select column_name from information_schema.columns
      where table_schema = 'ritual_public'
    `);
      expect(columns.rows.map((row) => row.column_name)).not.toEqual(
        expect.arrayContaining([
          "tenant_id",
          "author_staff_id",
          "review_notes",
          "claim_id",
          "canonical_url",
        ]),
      );
    });
  },
);
