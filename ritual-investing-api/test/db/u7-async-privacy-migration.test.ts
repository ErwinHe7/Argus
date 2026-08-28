import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const baselinePath = resolve(
  process.cwd(),
  "../supabase/migrations/20260828054740_argus_private_baseline.sql",
);
const workerPath = resolve(
  process.cwd(),
  "../supabase/migrations/20260828132056_u10_supabase_jobs_storage.sql",
);

describe("U7 async and privacy migration", () => {
  it("adds consumer watermarks, upload intents, journal confirmations, and restore gates", async () => {
    const [baseline, worker] = await Promise.all([
      readFile(baselinePath, "utf8"),
      readFile(workerPath, "utf8"),
    ]);
    expect(baseline).toMatch(
      /create table argus_private\.aggregate_consumer_watermarks/i,
    );
    expect(baseline).toMatch(/create table argus_private\.media_upload_intents/i);
    expect(baseline).toMatch(
      /create table argus_private\.deletion_journal_confirmations/i,
    );
    expect(baseline).toMatch(
      /create table argus_private\.deletion_restore_checkpoints/i,
    );
    expect(worker).toMatch(/create or replace function argus_private\.prepare_member_purge/i);
    expect(worker).toMatch(/create or replace function argus_private\.purge_member_argus_data/i);
    expect(worker).toMatch(/auth_identity_still_present/i);
  });

  it("binds asynchronous work to owner/deletion epoch and opaque queue events", async () => {
    const [baseline, worker] = await Promise.all([
      readFile(baselinePath, "utf8"),
      readFile(workerPath, "utf8"),
    ]);
    expect(baseline).toMatch(
      /check \(\(user_id is null\) = \(deletion_epoch is null\)\)/i,
    );
    expect(baseline).toMatch(/select pgmq\.create\('argus_jobs'\)/i);
    expect(worker).toMatch(
      /jsonb_build_object\('version',\s*1,\s*'event_id',\s*event_record\.id\)/i,
    );
    expect(worker).toMatch(
      /member\.deletion_epoch\s*=\s*event_record\.deletion_epoch/i,
    );
  });
});
