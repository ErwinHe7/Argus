import { Pool } from "@neondatabase/serverless";
import { z } from "zod";

import type { DatabasePoolFactory } from "../db/client.ts";
import { verifyDeletionDenyEntry } from "../domains/privacy/service.ts";

const denialSchema = z
  .object({
    schema_version: z.literal(1),
    tombstone_id: z.string().uuid(),
    tenant_id: z.string().uuid(),
    subject_hash: z.string().regex(/^[a-f0-9]{64}$/),
    effective_at: z.string().datetime(),
    purge_generation: z.number().int().positive(),
  })
  .strict();

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function listJournal(bucket: R2Bucket) {
  let cursor: string | undefined;
  const entries: Array<{
    key: string;
    body: string;
    checksum: string;
    parsed: z.infer<typeof denialSchema>;
  }> = [];
  do {
    const page = await bucket.list({
      prefix: "deletion-deny/v1/",
      ...(cursor === undefined ? {} : { cursor }),
    });
    for (const object of page.objects) {
      const stored = await bucket.get(object.key);
      if (stored === null) throw new Error("deletion_journal_object_missing");
      const body = await stored.text();
      const checksum = stored.customMetadata?.body_checksum;
      if (
        checksum === undefined ||
        !(await verifyDeletionDenyEntry(body, checksum))
      )
        throw new Error("deletion_journal_checksum_invalid");
      const parsed = denialSchema.parse(JSON.parse(body));
      if (
        object.key !==
        `deletion-deny/v1/${parsed.tombstone_id}/${parsed.purge_generation}.json`
      )
        throw new Error("deletion_journal_key_mismatch");
      entries.push({ key: object.key, body, checksum, parsed });
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor !== undefined);
  return entries.sort((left, right) => left.key.localeCompare(right.key));
}

export async function replayDeletionDenyJournal(
  databaseUrl: string,
  bucket: R2Bucket,
  restoreEpoch: string,
  poolFactory?: DatabasePoolFactory,
) {
  if (!/^[A-Za-z0-9._:-]{1,128}$/.test(restoreEpoch))
    throw new Error("invalid_restore_epoch");
  const entries = await listJournal(bucket);
  const replayChecksum = await sha256(
    entries.map((entry) => `${entry.key}:${entry.checksum}`).join("\n"),
  );
  const pool =
    poolFactory?.(databaseUrl) ??
    new Pool({ connectionString: databaseUrl, max: 1 });
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("set local role ritual_privacy_purge");
    for (const entry of entries) {
      const denial = entry.parsed;
      await client.query(
        `select ritual_private.replay_deletion_denial($1,$2,$3,$4,$5)`,
        [
          denial.tombstone_id,
          denial.tenant_id,
          denial.subject_hash,
          denial.effective_at,
          denial.purge_generation,
        ],
      );
      await client.query(
        `insert into deletion_journal_confirmations(tombstone_id,purge_generation,r2_key,body_checksum,confirmed_at) values ($1,$2,$3,$4,now()) on conflict (tombstone_id,purge_generation) do update set r2_key=excluded.r2_key,body_checksum=excluded.body_checksum,confirmed_at=excluded.confirmed_at`,
        [
          denial.tombstone_id,
          denial.purge_generation,
          entry.key,
          entry.checksum,
        ],
      );
    }
    const highestEffectiveAt =
      entries.length === 0
        ? new Date(0)
        : new Date(
            Math.max(
              ...entries.map((entry) => Date.parse(entry.parsed.effective_at)),
            ),
          );
    await client.query(
      `insert into deletion_restore_checkpoints(restore_epoch,journal_prefix,highest_effective_at,entry_count,replay_checksum,completed_at) values ($1,'deletion-deny/v1/',$2,$3,$4,now()) on conflict (restore_epoch) do update set highest_effective_at=excluded.highest_effective_at,entry_count=excluded.entry_count,replay_checksum=excluded.replay_checksum,completed_at=excluded.completed_at`,
      [restoreEpoch, highestEffectiveAt, entries.length, replayChecksum],
    );
    await client.query("commit");
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
  const marker = JSON.stringify({
    schema_version: 1,
    restore_epoch: restoreEpoch,
    replay_checksum: replayChecksum,
    entry_count: entries.length,
  });
  await bucket.put(`restore-cutover/v1/${restoreEpoch}.json`, marker, {
    httpMetadata: { contentType: "application/json" },
    customMetadata: { replay_checksum: replayChecksum },
  });
  return { entryCount: entries.length, replayChecksum };
}

export async function restoreCutoverReady(
  bucket: R2Bucket | undefined,
  restoreEpoch: string | undefined,
): Promise<boolean> {
  if (restoreEpoch === undefined || restoreEpoch.length === 0) return true;
  if (bucket === undefined) return false;
  const marker = await bucket.get(`restore-cutover/v1/${restoreEpoch}.json`);
  if (marker === null) return false;
  const metadataChecksum = marker.customMetadata?.replay_checksum;
  const parsed = z
    .object({
      schema_version: z.literal(1),
      restore_epoch: z.literal(restoreEpoch),
      replay_checksum: z.string().regex(/^[a-f0-9]{64}$/),
      entry_count: z.number().int().nonnegative(),
    })
    .strict()
    .safeParse(await marker.json());
  return parsed.success && parsed.data.replay_checksum === metadataChecksum;
}
