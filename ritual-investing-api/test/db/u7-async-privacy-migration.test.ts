import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const migrationPath = resolve(process.cwd(), "drizzle/0007_async_privacy.sql");

describe("U7 async and privacy migration", () => {
  it("adds consumer watermarks, upload intents, journal confirmations, and restore gates", async () => {
    const sql = await readFile(migrationPath, "utf8");
    expect(sql).toMatch(/^BEGIN;/);
    expect(sql).toMatch(/CREATE TABLE aggregate_consumer_watermarks/i);
    expect(sql).toMatch(/CREATE TABLE media_upload_intents/i);
    expect(sql).toMatch(/CREATE TABLE deletion_journal_confirmations/i);
    expect(sql).toMatch(/CREATE TABLE deletion_restore_checkpoints/i);
    expect(sql).toMatch(/journal confirmation required before purge/i);
    expect(sql).toMatch(/briefing watermark cannot regress/i);
    expect(sql).toMatch(/COMMIT;\s*$/);
  });

  it("removes cascading deletion from durable outbox history", async () => {
    const sql = await readFile(migrationPath, "utf8");
    expect(sql).toMatch(/DROP CONSTRAINT outbox_events_tenant_id_fkey/i);
    expect(sql).toMatch(
      /FOREIGN KEY \(tenant_id\) REFERENCES tenants\(id\) ON DELETE SET NULL/i,
    );
  });
});
