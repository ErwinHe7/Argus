import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { describe, expect, it } from "vitest";

import {
  applyReviewedMigrations,
  assertDirectOwnerDatabaseUrl,
  readReviewedMigrations,
  WAITLIST_MIGRATION_LOCK_KEY,
} from "../../scripts/check-migrations.ts";
import {
  describePostgres,
  ensureMigrated,
  ownerClient,
  ownerDatabaseUrl,
  provisionTestLogins,
} from "./support.ts";

describe("reviewed waitlist migrations", () => {
  it("requires an explicit direct owner URL and rejects Neon pooled hosts", () => {
    expect(() => assertDirectOwnerDatabaseUrl("postgresql://owner:secret@ep-name-pooler.us-east-2.aws.neon.tech/db"))
      .toThrow(/direct/i);
    expect(() => assertDirectOwnerDatabaseUrl("postgresql://waitlist_runtime:secret@ep-name.us-east-2.aws.neon.tech/db"))
      .toThrow(/owner/i);
    expect(() => assertDirectOwnerDatabaseUrl("postgresql://owner:secret@ep-name.us-east-2.aws.neon.tech/db"))
      .not.toThrow();
    expect(WAITLIST_MIGRATION_LOCK_KEY).toBe("just-build-this-waitlist-reviewed-migrations-v1");
  });

  it("checksum-locks reviewed SQL with explicit transaction boundaries", async () => {
    const migrations = await readReviewedMigrations(resolve(process.cwd(), "drizzle"));
    expect(migrations.map((migration) => migration.name)).toEqual(["0000_waitlist.sql"]);
    expect(migrations[0]?.checksum).toMatch(/^[a-f0-9]{64}$/);
    expect(migrations[0]?.body).not.toMatch(/^\s*begin;/i);
    expect(migrations[0]?.body).not.toMatch(/^\s*alter\s+role\b/imu);
    expect(migrations[0]?.body).toMatch(/rolcanlogin/u);
    const body = migrations[0]?.body ?? "";
    const temporaryCreateGrant = body.indexOf(
      "GRANT CREATE ON SCHEMA waitlist_private TO waitlist_function_owner",
    );
    const ownershipTransfer = body.indexOf(
      "ALTER TABLE waitlist_private.provisional_submissions OWNER TO waitlist_function_owner",
    );
    const temporaryCreateRevoke = body.indexOf(
      "REVOKE CREATE ON SCHEMA waitlist_private FROM waitlist_function_owner",
    );
    expect(temporaryCreateGrant).toBeGreaterThanOrEqual(0);
    expect(temporaryCreateGrant).toBeLessThan(ownershipTransfer);
    expect(temporaryCreateRevoke).toBeGreaterThan(ownershipTransfer);
    const assumeFunctionOwner = body.indexOf("SET LOCAL ROLE waitlist_function_owner");
    const ownerDefaults = body.indexOf("ALTER DEFAULT PRIVILEGES IN SCHEMA waitlist_private");
    const resetOwner = body.indexOf("RESET ROLE");
    expect(assumeFunctionOwner).toBeGreaterThan(temporaryCreateRevoke);
    expect(ownerDefaults).toBeGreaterThan(assumeFunctionOwner);
    expect(resetOwner).toBeGreaterThan(ownerDefaults);
    expect(body).not.toMatch(/alter\s+default\s+privileges\s+for\s+role/iu);

    const provisioning = await readFile(
      resolve(process.cwd(), "scripts/provision-waitlist-role.sql.example"),
      "utf8",
    );
    expect(provisioning).toMatch(/create\s+role\s+waitlist_runtime[\s\S]*\blogin\b/iu);
    expect(provisioning).toMatch(/create\s+role\s+waitlist_maintenance[\s\S]*\blogin\b/iu);
    expect(provisioning).not.toMatch(/^\s*alter\s+role\b/imu);
  });
});

describePostgres("waitlist migration on PostgreSQL 17", () => {
  it("applies once, repeats as a no-op, and rejects checksum drift", async () => {
    if (ownerDatabaseUrl === undefined) throw new Error("missing test database URL");
    const inspect = await ownerClient();
    const before = await inspect.query<{ ledger_exists: boolean }>(
      "select to_regclass('waitlist_private.applied_migrations') is not null as ledger_exists",
    );
    await inspect.end();
    await provisionTestLogins();
    const first = await applyReviewedMigrations(ownerDatabaseUrl);
    expect(first).toEqual(before.rows[0]?.ledger_exists ? [] : ["0000_waitlist.sql"]);
    await expect(applyReviewedMigrations(ownerDatabaseUrl)).resolves.toEqual([]);

    const directory = await mkdtemp(join(tmpdir(), "waitlist-migration-drift-"));
    const original = await readFile(resolve(process.cwd(), "drizzle/0000_waitlist.sql"), "utf8");
    await writeFile(join(directory, "0000_waitlist.sql"), original.replace("COMMIT;", "\n-- drift\nCOMMIT;"));
    await expect(applyReviewedMigrations(ownerDatabaseUrl, directory)).rejects.toThrow(/changed after it was applied/i);
  });

  it("owns an isolated ledger and exact three-column active table", async () => {
    await ensureMigrated();
    const client = await ownerClient();
    try {
      const columns = await client.query<{ column_name: string }>(`
        select column_name
        from information_schema.columns
        where table_schema = 'waitlist_private' and table_name = 'provisional_submissions'
        order by ordinal_position
      `);
      expect(columns.rows.map((row) => row.column_name)).toEqual([
        "normalized_email",
        "notice_version",
        "submitted_at",
      ]);
      const ledger = await client.query<{ name: string }>(
        "select name from waitlist_private.applied_migrations order by name",
      );
      expect(ledger.rows).toEqual([{ name: "0000_waitlist.sql" }]);

      const forbidden = await client.query<{ schema_name: string }>(`
        select schema_name
        from information_schema.schemata
        where schema_name in ('ritual_private', 'member_private', 'member')
      `);
      expect(forbidden.rows).toEqual([]);
      const ledgerNames = await client.query<{ table_name: string }>(`
        select table_name
        from information_schema.tables
        where table_schema = 'waitlist_private' and table_name ~ '(member|tenant|ledger)'
      `);
      expect(ledgerNames.rows).toEqual([]);
    } finally {
      await client.end();
    }
  });
});
