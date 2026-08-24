import { randomUUID } from "node:crypto";

import pg from "pg";
import { beforeAll, describe, expect, it, vi } from "vitest";

import { buildDeletionDenyEntry } from "../../src/domains/privacy/service.ts";
import type { DatabasePoolFactory } from "../../src/db/client.ts";
import { createPostgresAdminOperationsRepository } from "../../src/domains/admin-operations/repository.ts";
import { createPostgresMediaRepository } from "../../src/domains/media/repository.ts";
import { createPostgresNotificationRepository } from "../../src/domains/notifications/repository.ts";
import { createPostgresPrivacyRepository } from "../../src/domains/privacy/repository.ts";
import {
  consumeWithReceipt,
  type ConsumerEffect,
} from "../../src/jobs/consumer-receipts.ts";
import { replayDeletionDenyJournal } from "../../src/jobs/deletion-restore.ts";
import { runQueue } from "../../src/jobs/queue-runtime.ts";
import { handlerFor } from "../../src/jobs/handlers.ts";
import { pgPoolFactory } from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

async function ownerQuery<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  values: unknown[] = [],
) {
  const client = new pg.Client({ connectionString: databaseUrl! });
  await client.connect();
  try {
    return await client.query<T>(text, values);
  } finally {
    await client.end();
  }
}

describe.skipIf(databaseUrl === undefined)(
  "U7 PostgreSQL async and deletion invariants",
  () => {
    const tenantId = randomUUID();
    const accountId = randomUUID();
    const aggregateId = randomUUID();
    const v1 = randomUUID();
    const v2 = randomUUID();
    const rollbackEvent = randomUUID();

    beforeAll(async () => {
      await ownerQuery("insert into tenants(id,status) values ($1,'active')", [
        tenantId,
      ]);
      await ownerQuery(
        "insert into accounts(id,tenant_id,auth0_subject,status) values ($1,$2,$3,'active')",
        [accountId, tenantId, `auth0|u7-${tenantId}`],
      );
      await ownerQuery(
        "insert into notification_preferences(tenant_id) values ($1)",
        [tenantId],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
         reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($2::uuid,'briefing.daily.generated','briefing',$5::uuid,1,$1::uuid,0,0,($2::uuid)::text,'{}'::jsonb,1,now()),
              ($3::uuid,'briefing.daily.generated','briefing',$5::uuid,2,$1::uuid,0,0,($3::uuid)::text,'{}'::jsonb,1,now()),
              ($4::uuid,'briefing.daily.generated','briefing',$4::uuid,1,$1::uuid,0,0,($4::uuid)::text,'{}'::jsonb,1,now())`,
        [tenantId, v1, v2, rollbackEvent, aggregateId],
      );
    });

    const notificationEffect: ConsumerEffect = async (client, event) => {
      await client.query(
        `insert into notifications(tenant_id,kind,title,body,source_outbox_id,
         reset_generation,deletion_generation)
       values ($1,'briefing_ready','Ready','Open the briefing.',$2,$3,$4)`,
        [
          event.tenant_id,
          event.id,
          event.reset_generation,
          event.deletion_generation,
        ],
      );
      return `notification:${event.id}`;
    };

    it("rolls back the effect and receipt when a consumer crashes", async () => {
      await expect(
        consumeWithReceipt(
          databaseUrl!,
          {
            schema_version: 1,
            outbox_id: rollbackEvent,
            consumer: "notification-writer",
          },
          async (client, event) => {
            await notificationEffect(client, event);
            throw new Error("crash_after_effect");
          },
          pgPoolFactory,
        ),
      ).rejects.toThrow("crash_after_effect");
      const result = await ownerQuery<{ effects: string; receipts: string }>(
        `select
        (select count(*) from notifications where source_outbox_id=$1)::text effects,
        (select count(*) from consumer_receipts where outbox_id=$1)::text receipts`,
        [rollbackEvent],
      );
      expect(result.rows[0]).toEqual({ effects: "0", receipts: "0" });
    });

    it("deduplicates concurrent delivery and fences N before an applied N+1", async () => {
      const message = {
        schema_version: 1,
        outbox_id: v2,
        consumer: "notification-writer",
      } as const;
      const concurrent = await Promise.all([
        consumeWithReceipt(
          databaseUrl!,
          message,
          notificationEffect,
          pgPoolFactory,
        ),
        consumeWithReceipt(
          databaseUrl!,
          message,
          notificationEffect,
          pgPoolFactory,
        ),
      ]);
      expect(concurrent.sort()).toEqual(["applied", "duplicate"]);
      expect(
        await consumeWithReceipt(
          databaseUrl!,
          { ...message, outbox_id: v1 },
          notificationEffect,
          pgPoolFactory,
        ),
      ).toBe("stale");
      const result = await ownerQuery<{
        effects: string;
        receipts: string;
        watermark: number;
      }>(
        `select
        (select count(*) from notifications where source_outbox_id in ($1,$2))::text effects,
        (select count(*) from consumer_receipts where outbox_id in ($1,$2) and consumer='notification-writer')::text receipts,
        (select aggregate_version from aggregate_consumer_watermarks where tenant_id=$3
          and consumer='notification-writer' and aggregate_kind='briefing' and aggregate_id=$4) watermark`,
        [v1, v2, tenantId, aggregateId],
      );
      expect(result.rows[0]).toEqual({
        effects: "1",
        receipts: "2",
        watermark: 2,
      });
    });

    it("queues and executes actor-bound media work through the restricted worker role", async () => {
      const staffId = randomUUID();
      await ownerQuery(
        "insert into staff_principals(id,auth0_subject,access_identity,allowed_client_id,status,display_label) values ($1,$2,$3,'ritual-admin-client','active','Media Operator')",
        [staffId, `auth0|media-${staffId}`, `media-${staffId}@ritual.test`],
      );
      const staff = {
        id: staffId,
        auth0Subject: `auth0|media-${staffId}`,
        accessIdentity: `media-${staffId}@ritual.test`,
        allowedClientId: "ritual-admin-client",
        displayLabel: "Media Operator",
        revocationEpoch: 0,
      };
      const png = new Uint8Array(24);
      png.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      new DataView(png.buffer).setUint32(16, 1);
      new DataView(png.buffer).setUint32(20, 1);
      const checksum = [
        ...new Uint8Array(await crypto.subtle.digest("SHA-256", png)),
      ]
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
      const repository = createPostgresMediaRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const intent = await repository.createIntent(
        staff,
        { mime_type: "image/png", byte_size: png.byteLength, checksum },
        `media-upload-${randomUUID()}`,
        randomUUID(),
      );
      expect(await repository.markUploaded(staff, intent.id)).toBe(true);
      const key = `media-complete-${randomUUID()}`;
      const completeRequestId = randomUUID();
      const outboxId = await repository.queueScan(
        staff,
        intent.id,
        checksum,
        key,
        completeRequestId,
      );
      expect(
        await repository.queueScan(
          staff,
          intent.id,
          checksum,
          key,
          completeRequestId,
        ),
      ).toBe(outboxId);
      const runtime = new pg.Client({ connectionString: databaseUrl! });
      await runtime.connect();
      try {
        await runtime.query("begin");
        await runtime.query("set local role ritual_runtime");
        await expect(
          runtime.query(
            `insert into media_assets(id,r2_key,mime_type,byte_size,checksum,quarantine_status,status)
         values ($1,'media/v1/forbidden','image/png',24,$2,'clear','active')`,
            [randomUUID(), checksum],
          ),
        ).rejects.toThrow(/permission denied/);
        await runtime.query("rollback");
      } finally {
        await runtime.end();
      }
      const objects = new Map<
        string,
        { bytes: Uint8Array; metadata: Record<string, string> }
      >([
        [
          intent.r2Key,
          {
            bytes: png,
            metadata: { upload_intent_id: intent.id, actor_staff_id: staff.id },
          },
        ],
      ]);
      const quarantine = {
        get: async (objectKey: string) => {
          const object = objects.get(objectKey);
          return object === undefined
            ? null
            : {
                customMetadata: object.metadata,
                arrayBuffer: async () =>
                  object.bytes.buffer.slice(
                    object.bytes.byteOffset,
                    object.bytes.byteOffset + object.bytes.byteLength,
                  ),
              };
        },
        delete: async (objectKey: string) => {
          objects.delete(objectKey);
        },
      } as unknown as R2Bucket;
      const publicObjects = new Map<string, Uint8Array>();
      const publicBucket = {
        put: async (objectKey: string, value: Uint8Array) => {
          publicObjects.set(objectKey, value);
        },
        delete: async (objectKey: string) => {
          publicObjects.delete(objectKey);
        },
      } as unknown as R2Bucket;
      const scanMessage = {
        schema_version: 1 as const,
        outbox_id: outboxId!,
        consumer: "media-scan" as const,
      };
      const bindings = {
        MEDIA_QUARANTINE: quarantine,
        MEDIA_PUBLIC: publicBucket,
        MEDIA_SCANNER: {
          fetch: async () => Response.json({ result: "clean" }),
        },
        MEDIA_PROCESSOR: { fetch: async () => new Response(png) },
      } as never;
      expect(
        await consumeWithReceipt(
          databaseUrl!,
          scanMessage,
          handlerFor(scanMessage, bindings),
          pgPoolFactory,
        ),
      ).toBe("applied");
      expect(objects.has(intent.r2Key)).toBe(true);
      const terminal = await ownerQuery<{
        status: string;
        assets: string;
        cleanup_id: string;
      }>(
        `select i.status,
              (select count(*) from media_assets where upload_intent_id=i.id)::text assets,
              (select id from outbox_events where topic='media.quarantine.cleanup' and aggregate_id=i.id) cleanup_id
         from media_upload_intents i where i.id=$1`,
        [intent.id],
      );
      expect(terminal.rows[0]?.status).toBe("accepted");
      expect(terminal.rows[0]?.assets).toBe("1");
      const cleanupMessage = {
        schema_version: 1 as const,
        outbox_id: terminal.rows[0]!.cleanup_id,
        consumer: "media-cleanup" as const,
      };
      expect(
        await consumeWithReceipt(
          databaseUrl!,
          cleanupMessage,
          handlerFor(cleanupMessage, bindings),
          pgPoolFactory,
        ),
      ).toBe("applied");
      expect(objects.has(intent.r2Key)).toBe(false);
      const creatorId = randomUUID();
      await ownerQuery(
        `insert into seeded_creators(id,slug,display_name,bio,avatar_media_id,is_fictional,status)
       values ($1,$2,'Fixture Creator','Fictional test creator.',$3,true,'active')`,
        [creatorId, `fixture-${creatorId}`, intent.id],
      );
      await expect(
        repository.retire(
          staff,
          intent.id,
          1,
          "Retire a referenced fixture",
          randomUUID(),
        ),
      ).rejects.toMatchObject({ code: "referenced" });
      await ownerQuery("delete from seeded_creators where id=$1", [creatorId]);
      const retireOutbox = await repository.retire(
        staff,
        intent.id,
        1,
        "No longer approved for ritual use",
        randomUUID(),
      );
      const publicCleanup = {
        schema_version: 1 as const,
        outbox_id: retireOutbox!,
        consumer: "media-cleanup" as const,
      };
      expect(
        await consumeWithReceipt(
          databaseUrl!,
          publicCleanup,
          handlerFor(publicCleanup, bindings),
          pgPoolFactory,
        ),
      ).toBe("applied");
      expect(publicObjects.has(`media/v1/${intent.id}`)).toBe(false);
      const audit = await ownerQuery<{ receipts: string; audits: string }>(
        `select
        (select count(*) from admin_operation_receipts where actor_staff_id=$1 and operation in ('media.upload-request','media.complete'))::text receipts,
        (select count(*) from admin_audit_events where actor_staff_id=$1 and action in ('media.upload-request','media.complete','media.retire'))::text audits`,
        [staff.id],
      );
      expect(audit.rows[0]).toEqual({ receipts: "2", audits: "3" });
    });

    it("triages only an exact published report through the narrow definer seam", async () => {
      const itemId = randomUUID();
      const reportId = randomUUID();
      const outboxId = randomUUID();
      await ownerQuery(
        `insert into editorial_items(id,kind,slug,status) values ($1,'asset_codex',$2,'published')`,
        [itemId, `u7-report-${itemId}`],
      );
      await ownerQuery(
        `insert into content_reports(id,tenant_id,target_kind,target_id,reason_code)
       values ($1,$2,'codex',$3,'incorrect')`,
        [reportId, tenantId, itemId],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($1::uuid,'content-report.created','content-report',$2::uuid,1,$3::uuid,0,0,($1::uuid)::text,jsonb_build_object('report_id',$2::uuid),1,now())`,
        [outboxId, reportId, tenantId],
      );
      const runtime = new pg.Client({ connectionString: databaseUrl! });
      await runtime.connect();
      try {
        await runtime.query("begin");
        await runtime.query("set local role ritual_runtime");
        await runtime.query("select set_config('ritual.tenant_id',$1,true)", [
          tenantId,
        ]);
        await expect(
          runtime.query(
            "insert into moderation_cases(report_id,status) values ($1,'open')",
            [reportId],
          ),
        ).rejects.toThrow(/permission denied/);
        await runtime.query("rollback");
      } finally {
        await runtime.end();
      }
      const work = {
        schema_version: 1 as const,
        outbox_id: outboxId,
        consumer: "moderation-triage" as const,
      };
      expect(
        await consumeWithReceipt(
          databaseUrl!,
          work,
          handlerFor(work, {} as never),
          pgPoolFactory,
        ),
      ).toBe("applied");
      expect(
        (
          await ownerQuery(
            "select id from moderation_cases where report_id=$1",
            [reportId],
          )
        ).rowCount,
      ).toBe(1);
    });

    it("prevents runtime from purging and requires durable external confirmations", async () => {
      const purgeTenant = randomUUID();
      const purgeAccount = randomUUID();
      const tombstone = randomUUID();
      const purgeOutbox = randomUUID();
      await ownerQuery(
        "insert into tenants(id,status) values ($1,'deletion_pending')",
        [purgeTenant],
      );
      await ownerQuery(
        "insert into accounts(id,tenant_id,auth0_subject,status) values ($1,$2,$3,'deletion_pending')",
        [purgeAccount, purgeTenant, `auth0|purge-${purgeTenant}`],
      );
      await ownerQuery(
        `insert into deletion_tombstones(id,tenant_id,subject_hash,effective_at,purge_generation,status)
       values ($1,$2,$3,now(),1,'pending')`,
        [
          tombstone,
          purgeTenant,
          purgeTenant.replaceAll("-", "").padEnd(64, "a"),
        ],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
         reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($1::uuid,'privacy.deletion.requested','deletion-tombstone',$2::uuid,1,$3::uuid,0,1,($1::uuid)::text,
         jsonb_build_object('tombstone_id',$2::uuid),1,now())`,
        [purgeOutbox, tombstone, purgeTenant],
      );
      const invoke = async (role: string) => {
        const client = new pg.Client({ connectionString: databaseUrl! });
        await client.connect();
        try {
          await client.query("begin");
          await client.query(`set local role ${role}`);
          await client.query(
            "select ritual_private.purge_tombstoned_tenant($1,1)",
            [tombstone],
          );
          await client.query("commit");
        } catch (error) {
          await client.query("rollback").catch(() => undefined);
          throw error;
        } finally {
          await client.end();
        }
      };
      await expect(invoke("ritual_runtime")).rejects.toThrow(
        /permission denied/,
      );
      const begin = new pg.Client({ connectionString: databaseUrl! });
      await begin.connect();
      await begin.query("begin");
      await begin.query("set local role ritual_privacy_purge");
      const authorized = await begin.query<{ authorized: boolean }>(
        "select ritual_private.begin_privacy_purge_event($1,$2,1) authorized",
        [purgeOutbox, purgeTenant],
      );
      await begin.query("commit");
      await begin.end();
      expect(authorized.rows[0]?.authorized).toBe(true);
      await expect(invoke("ritual_privacy_purge")).rejects.toThrow(
        /journal confirmation required/,
      );
      await ownerQuery(
        `insert into deletion_journal_confirmations(tombstone_id,purge_generation,r2_key,body_checksum,confirmed_at)
       values ($1,1,$2,$3,now())`,
        [tombstone, `deletion-deny/v1/${tombstone}/1.json`, "b".repeat(64)],
      );
      await ownerQuery(
        `insert into deletion_object_receipts(tombstone_id,purge_generation,object_class,prefix,listing_checksum,confirmed_empty_at)
       values ($1,1,'privacy_exports',$3,$2,now()),($1,1,'tenant_quarantine',$4,$2,now())`,
        [
          tombstone,
          "b".repeat(64),
          `privacy-exports/v1/${purgeTenant}/`,
          `tenant-quarantine/v1/${purgeTenant}/`,
        ],
      );
      await invoke("ritual_privacy_purge");
      const state = await ownerQuery<{ tenants: string; receipts: string }>(
        `select (select count(*) from tenants where id=$1)::text tenants,
              (select count(*) from purge_receipts where tombstone_id=$2)::text receipts`,
        [purgeTenant, tombstone],
      );
      expect(state.rows[0]).toEqual({ tenants: "0", receipts: "1" });
    });

    it("replays the independent R2 denial journal before stale-Neon traffic", async () => {
      const staleTenant = randomUUID();
      const staleAccount = randomUUID();
      const tombstone = randomUUID();
      await ownerQuery("insert into tenants(id,status) values ($1,'active')", [
        staleTenant,
      ]);
      await ownerQuery(
        "insert into accounts(id,tenant_id,auth0_subject,status) values ($1,$2,$3,'active')",
        [staleAccount, staleTenant, `auth0|stale-${staleTenant}`],
      );
      const entry = await buildDeletionDenyEntry({
        tombstoneId: tombstone,
        tenantId: staleTenant,
        subjectHash: staleTenant.replaceAll("-", "").padEnd(64, "c"),
        effectiveAt: "2026-08-24T10:00:00.000Z",
        purgeGeneration: 1,
      });
      const objects = new Map<
        string,
        { body: string; metadata: Record<string, string> }
      >([
        [
          entry.key,
          { body: entry.body, metadata: { body_checksum: entry.checksum } },
        ],
      ]);
      const bucket = {
        list: async ({ prefix }: { prefix: string }) => ({
          objects: [...objects.keys()]
            .filter((key) => key.startsWith(prefix))
            .map((key) => ({ key })),
          truncated: false,
        }),
        get: async (key: string) => {
          const object = objects.get(key);
          return object === undefined
            ? null
            : {
                customMetadata: object.metadata,
                text: async () => object.body,
                json: async () => JSON.parse(object.body),
              };
        },
        put: async (
          key: string,
          body: string,
          options: { customMetadata?: Record<string, string> },
        ) => {
          objects.set(key, { body, metadata: options.customMetadata ?? {} });
        },
      } as unknown as R2Bucket;
      const result = await replayDeletionDenyJournal(
        databaseUrl!,
        bucket,
        "restore-u7-stale-neon",
        pgPoolFactory,
      );
      expect(result.entryCount).toBe(1);
      const state = await ownerQuery<{
        tenant_status: string;
        account_status: string;
        revocation_epoch: number;
        checkpoints: string;
      }>(
        `select t.status tenant_status,a.status account_status,a.revocation_epoch,
        (select count(*) from deletion_restore_checkpoints where restore_epoch='restore-u7-stale-neon')::text checkpoints
       from tenants t join accounts a on a.tenant_id=t.id where t.id=$1`,
        [staleTenant],
      );
      expect(state.rows[0]).toEqual({
        tenant_status: "deletion_pending",
        account_status: "deletion_pending",
        revocation_epoch: 1,
        checkpoints: "1",
      });
      expect(objects.has("restore-cutover/v1/restore-u7-stale-neon.json")).toBe(
        true,
      );
    });

    it("reassigns a push token globally without allowing an old-tenant replay to reactivate it", async () => {
      const secondTenant = randomUUID();
      const secondAccount = randomUUID();
      await ownerQuery("insert into tenants(id,status) values ($1,'active')", [
        secondTenant,
      ]);
      await ownerQuery(
        "insert into accounts(id,tenant_id,auth0_subject,status) values ($1,$2,$3,'active')",
        [secondAccount, secondTenant, `auth0|device-${secondTenant}`],
      );
      const repository = createPostgresNotificationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const context = (tenant: string, account: string) => ({
        subject: `auth0|device-${tenant}`,
        tenantId: tenant,
        accountId: account,
        accountStatus: "active" as const,
        tenantStatus: "active" as const,
        revocationEpoch: 0,
      });
      const key = btoa(
        String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))),
      )
        .replaceAll("+", "-")
        .replaceAll("/", "_")
        .replaceAll("=", "");
      const input = {
        platform: "ios" as const,
        push_token: "same-provider-token-for-one-physical-installation",
      };
      const firstKey = `device-a-${randomUUID()}`;
      const first = await repository.registerDevice(
        context(tenantId, accountId),
        input,
        key,
        firstKey,
      );
      const second = await repository.registerDevice(
        context(secondTenant, secondAccount),
        input,
        key,
        `device-b-${randomUUID()}`,
      );
      const replay = await repository.registerDevice(
        context(tenantId, accountId),
        input,
        key,
        firstKey,
      );
      expect(second.status).toBe("active");
      expect(replay.status).toBe("revoked");
      const active = await ownerQuery<{ tenant_id: string }>(
        "select tenant_id from device_installations where push_token_hash=(select push_token_hash from device_installations where id=$1) and status='active'",
        [second.id],
      );
      expect(active.rows).toEqual([{ tenant_id: secondTenant }]);
    });

    it("claims an admin retry and its audit exactly once while preserving replay-safe Queue metadata", async () => {
      const staffId = randomUUID();
      const outboxId = randomUUID();
      const jobId = randomUUID();
      await ownerQuery(
        "insert into staff_principals(id,auth0_subject,access_identity,allowed_client_id,status,display_label) values ($1,$2,$3,'ritual-admin-client','active','U7 Operator')",
        [staffId, `auth0|staff-${staffId}`, `u7-${staffId}@ritual.test`],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($1::uuid,'content-report.created','content-report',$1::uuid,1,$2,0,0,($1::uuid)::text,'{}'::jsonb,1,now())`,
        [outboxId, tenantId],
      );
      await ownerQuery(
        `insert into job_runs(id,outbox_id,consumer,status,attempt,correlation_id,failure_code,created_at,completed_at)
       values ($1,$2,'moderation-triage','dead_letter',5,$3,'internal_failure',now(),now())`,
        [jobId, outboxId, randomUUID()],
      );
      const staff = {
        id: staffId,
        auth0Subject: `auth0|staff-${staffId}`,
        accessIdentity: `u7-${staffId}@ritual.test`,
        allowedClientId: "ritual-admin-client",
        displayLabel: "U7 Operator",
        revocationEpoch: 0,
      };
      const repository = createPostgresAdminOperationsRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const key = `admin-retry-${randomUUID()}`;
      const first = await repository.retryJob(
        staff,
        jobId,
        "Retry reviewed poison work",
        randomUUID(),
        key,
      );
      const replay = await repository.retryJob(
        staff,
        jobId,
        "Retry reviewed poison work",
        randomUUID(),
        key,
      );
      expect(replay).toEqual(first);
      const evidence = await ownerQuery<{ receipts: string; audits: string }>(
        `select
        (select count(*) from admin_operation_receipts where actor_staff_id=$1 and operation='job.retry' and idempotency_key=$2)::text receipts,
        (select count(*) from admin_audit_events where actor_staff_id=$1 and action='job.retry' and target_id=$3)::text audits`,
        [staffId, key, jobId],
      );
      expect(evidence.rows[0]).toEqual({ receipts: "1", audits: "1" });
      await expect(
        repository.retryJob(
          staff,
          jobId,
          "A different reviewed reason",
          randomUUID(),
          key,
        ),
      ).rejects.toMatchObject({ code: "idempotency_conflict" });
    });

    it("terminalizes poison work in the DLQ with only redacted identifiers", async () => {
      const outboxId = randomUUID();
      const requestId = randomUUID();
      await ownerQuery(
        `insert into privacy_requests(id,tenant_id,request_type,status,snapshot_at,source_sequence,archive_schema_version,expires_at)
       values ($1,$2,'export','failed',now(),0,1,now()+interval '7 days')`,
        [requestId, tenantId],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($1::uuid,'privacy.export.requested','privacy-request',$2,1,$3,0,0,($1::uuid)::text,jsonb_build_object('request_id',$2::uuid),1,now())`,
        [outboxId, requestId, tenantId],
      );
      const ack = vi.fn();
      const retry = vi.fn();
      const dlq = vi.fn();
      await runQueue(
        {
          messages: [
            {
              body: {
                schema_version: 1,
                outbox_id: outboxId,
                consumer: "privacy-export",
              },
              attempts: 5,
              ack,
              retry,
            },
          ],
        } as unknown as MessageBatch<unknown>,
        {
          RUNTIME_DATABASE_URL: databaseUrl!,
          SCHEDULER_DATABASE_URL: databaseUrl!,
          JOBS_DLQ: { send: dlq } as unknown as Queue,
          KILL_SWITCH_QUEUE: "off",
          KILL_SWITCH_NOTIFICATIONS: "off",
          KILL_SWITCH_EXPORTS: "off",
          KILL_SWITCH_PURGE: "off",
          KILL_SWITCH_MEDIA: "off",
        } as never,
        pgPoolFactory,
      );
      expect(retry).not.toHaveBeenCalled();
      expect(ack).toHaveBeenCalledOnce();
      expect(dlq).toHaveBeenCalledWith({
        schema_version: 1,
        outbox_id: outboxId,
        consumer: "privacy-export",
        failure_code: "privacy_export_unavailable",
      });
      expect(JSON.stringify(dlq.mock.calls)).not.toMatch(
        /provider|token|body/i,
      );
    });

    it("exports one coherent tenant ZIP and lets deletion revoke links and fence queued export work", async () => {
      const foreignTenant = randomUUID();
      await ownerQuery("insert into tenants(id,status) values ($1,'active')", [
        foreignTenant,
      ]);
      await ownerQuery(
        "insert into profiles(tenant_id,display_name,locale) values ($1,'Export Member','en-US') on conflict (tenant_id) do update set display_name=excluded.display_name",
        [tenantId],
      );
      await ownerQuery(
        "insert into profiles(tenant_id,display_name,locale) values ($1,'Foreign Secret Member','en-US')",
        [foreignTenant],
      );
      const requestId = randomUUID();
      const outboxId = randomUUID();
      await ownerQuery(
        `insert into privacy_requests(id,tenant_id,request_type,status,snapshot_at,source_sequence,archive_schema_version,verified_at,queued_at,expires_at)
       values ($1,$2,'export','queued',now(),7,1,now(),now(),now()+interval '7 days')`,
        [requestId, tenantId],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($1::uuid,'privacy.export.requested','privacy-request',$2,1,$3,0,0,($1::uuid)::text,jsonb_build_object('request_id',$2::uuid),1,now())`,
        [outboxId, requestId, tenantId],
      );
      const objects = new Map<
        string,
        {
          bytes: Uint8Array;
          contentType?: string;
          metadata: Record<string, string>;
        }
      >();
      const bucket = {
        put: async (
          key: string,
          value: Uint8Array | ArrayBuffer | string,
          options?: {
            httpMetadata?: { contentType?: string };
            customMetadata?: Record<string, string>;
          },
        ) => {
          const bytes =
            typeof value === "string"
              ? new TextEncoder().encode(value)
              : value instanceof Uint8Array
                ? value
                : new Uint8Array(value);
          objects.set(key, {
            bytes,
            ...(options?.httpMetadata?.contentType === undefined
              ? {}
              : { contentType: options.httpMetadata.contentType }),
            metadata: options?.customMetadata ?? {},
          });
        },
        get: async (key: string) => {
          const object = objects.get(key);
          return object === undefined
            ? null
            : {
                customMetadata: object.metadata,
                arrayBuffer: async () =>
                  object.bytes.buffer.slice(
                    object.bytes.byteOffset,
                    object.bytes.byteOffset + object.bytes.byteLength,
                  ),
                text: async () => new TextDecoder().decode(object.bytes),
                json: async () =>
                  JSON.parse(new TextDecoder().decode(object.bytes)),
                body: object.bytes,
              };
        },
        delete: async (key: string) => {
          objects.delete(key);
        },
        list: async ({ prefix }: { prefix: string }) => ({
          objects: [...objects.keys()]
            .filter((key) => key.startsWith(prefix))
            .map((key) => ({ key })),
          truncated: false,
        }),
      } as unknown as R2Bucket;
      const message = {
        schema_version: 1 as const,
        outbox_id: outboxId,
        consumer: "privacy-export" as const,
      };
      let snapshotSelected!: () => void;
      let resumeExport!: () => void;
      const selected = new Promise<void>((resolve) => {
        snapshotSelected = resolve;
      });
      const resume = new Promise<void>((resolve) => {
        resumeExport = resolve;
      });
      const gatedPoolFactory: DatabasePoolFactory = (url) => {
        const pool = pgPoolFactory(url);
        return {
          connect: async () => {
            const client = await pool.connect();
            const originalQuery = client.query.bind(client) as (
              ...args: unknown[]
            ) => Promise<unknown>;
            let gated = false;
            (
              client as unknown as {
                query: (...args: unknown[]) => Promise<unknown>;
              }
            ).query = async (...args: unknown[]) => {
              const result = await originalQuery(...args);
              if (
                !gated &&
                typeof args[0] === "string" &&
                args[0].includes("from outbox_events where id=$1")
              ) {
                gated = true;
                snapshotSelected();
                await resume;
              }
              return result;
            };
            return client;
          },
          end: () => pool.end(),
        };
      };
      const exporting = consumeWithReceipt(
        databaseUrl!,
        message,
        handlerFor(message, { PRIVACY_EXPORTS: bucket } as never),
        gatedPoolFactory,
      );
      await selected;
      await ownerQuery(
        "update profiles set display_name='Mutated During Export' where tenant_id=$1",
        [tenantId],
      );
      resumeExport();
      expect(await exporting).toBe("applied");
      const key = `privacy-exports/v1/${tenantId}/${requestId}.zip`;
      const archive = objects.get(key)!;
      expect(archive.contentType).toBe("application/zip");
      expect([...archive.bytes.slice(0, 2)]).toEqual([0x50, 0x4b]);
      const readable = new TextDecoder().decode(archive.bytes);
      expect(readable).toContain("Export Member");
      expect(readable).not.toContain("Mutated During Export");
      expect(readable).not.toContain("Foreign Secret Member");
      for (const section of [
        "account",
        "profile",
        "onboarding",
        "astrology_profile",
        "investor_profile",
        "consents",
        "saved_assets",
        "circles",
        "circle_assets",
        "demo_portfolios",
        "portfolio_positions",
        "simulation_activity",
        "simulated_orders",
        "recurring_plans",
        "intentions",
        "projection_runs",
        "briefings",
        "briefing_sections",
        "entitlements",
        "entitlement_events",
        "notification_preferences",
        "notifications",
        "content_reports",
      ])
        expect(readable).toContain(`\"${section}\"`);
      expect(readable).not.toMatch(
        /auth0_subject|push_token|ciphertext|idempotency|outbox|job_runs|password|provider_body|request_hash/i,
      );

      const member = {
        subject: `auth0|u7-${tenantId}`,
        tenantId,
        accountId,
        accountStatus: "active" as const,
        tenantStatus: "active" as const,
        revocationEpoch: 0,
      };
      const privacy = createPostgresPrivacyRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const link = await privacy.createDownloadLink(
        member,
        requestId,
        "https://api.ritual.test",
      );
      expect(link?.url).toContain("/v1/me/privacy/exports/");
      const token = new URL(link!.url).searchParams.get("token")!;
      const queuedId = randomUUID();
      const queuedOutbox = randomUUID();
      await ownerQuery(
        `insert into privacy_requests(id,tenant_id,request_type,status,snapshot_at,source_sequence,archive_schema_version,verified_at,queued_at,expires_at)
       values ($1,$2,'export','queued',now(),8,1,now(),now(),now()+interval '7 days')`,
        [queuedId, tenantId],
      );
      await ownerQuery(
        `insert into outbox_events(id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
       values ($1::uuid,'privacy.export.requested','privacy-request',$2,1,$3,0,0,($1::uuid)::text,jsonb_build_object('request_id',$2::uuid),1,now())`,
        [queuedOutbox, queuedId, tenantId],
      );
      await privacy.requestDeletion(member, `delete-export-${randomUUID()}`);
      expect(
        await privacy.consumeDownload(member, requestId, token),
      ).toBeNull();
      const staleMessage = {
        schema_version: 1 as const,
        outbox_id: queuedOutbox,
        consumer: "privacy-export" as const,
      };
      expect(
        await consumeWithReceipt(
          databaseUrl!,
          staleMessage,
          handlerFor(staleMessage, { PRIVACY_EXPORTS: bucket } as never),
          pgPoolFactory,
        ),
      ).toBe("deleted");
      expect(
        objects.has(`privacy-exports/v1/${tenantId}/${queuedId}.zip`),
      ).toBe(false);
      const state = await ownerQuery<{
        publication_state: string;
        queued_status: string;
      }>(
        `select a.publication_state,(select status from privacy_requests where id=$2) queued_status
         from privacy_export_artifacts a where a.tenant_id=$1 and a.request_id=$3`,
        [tenantId, queuedId, requestId],
      );
      expect(state.rows[0]).toEqual({
        publication_state: "revoked",
        queued_status: "cancelled",
      });
    });
  },
);
