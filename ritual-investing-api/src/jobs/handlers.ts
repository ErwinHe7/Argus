import type { DatabaseClient } from "../db/database-port.ts";
import { inspectQuarantinedObject } from "../domains/media/service.ts";
import {
  buildStreamingPrivacyZip,
  type StreamingExportCollection,
} from "../domains/privacy/service.ts";
import { sha256TextHex } from "../security/sha256.ts";
import type { OutboxEvent } from "./consumer-receipts.ts";

export type WorkerStorageObject = Readonly<{
  body: Uint8Array;
  contentType: string;
}>;

export interface WorkerStoragePort {
  get(bucket: string, path: string): Promise<WorkerStorageObject | null>;
  put(bucket: string, path: string, body: BodyInit, contentType: string): Promise<void>;
  remove(bucket: string, paths: readonly string[]): Promise<void>;
}

export interface WorkerPurgeSagaPort {
  run(tombstoneId: string, keepAlive?: () => Promise<void>): Promise<string>;
}

export type JobHandlerDependencies = Readonly<{
  storage: WorkerStoragePort;
  purgeSaga: WorkerPurgeSagaPort;
}>;

export type JobEffect = (
  database: DatabaseClient,
  event: OutboxEvent,
) => Promise<string>;

async function assertCurrent(database: DatabaseClient, eventId: string) {
  const result = await database.query<{ current: boolean }>(
    "select argus_private.assert_worker_event_current($1) as current",
    [eventId],
  );
  if (result.rows[0]?.current !== true) throw new Error("deletion_epoch_changed");
}

function briefingBuilder(): JobEffect {
  return async (database, event) => {
    if (event.userId === null) throw new Error("invalid_event_payload");
    const updated = await database.query<{ id: string }>(
      `update argus_app.briefings set status='ready',generated_at=clock_timestamp()
        where id=$1 and user_id=$2 and deletion_epoch=$3 and status in ('queued','building')
        returning id`,
      [event.aggregateId, event.userId, event.deletionEpoch],
    );
    if (updated.rows.length === 0) return "briefing-stale";
    await database.query(
      `insert into argus_app.briefing_sections(
         user_id,deletion_epoch,briefing_id,section_type,ordinal,payload
       ) values ($1,$2,$3,'summary',1,$4::jsonb)
       on conflict (briefing_id,ordinal) do nothing`,
      [
        event.userId,
        event.deletionEpoch,
        event.aggregateId,
        JSON.stringify({ disclosure: "A reflective Argus briefing, not financial advice." }),
      ],
    );
    const generatedType = event.eventType.replace(".requested", ".generated");
    await database.query(
      `insert into argus_private.outbox_events(
         user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
       ) values ($1,$2,'argus_jobs',$3,$4,$5)
       on conflict (topic,dedupe_key) do nothing`,
      [
        event.userId,
        event.deletionEpoch,
        generatedType,
        event.aggregateId,
        `briefing-generated:${event.aggregateId}`,
      ],
    );
    return `briefing:${event.aggregateId}`;
  };
}

function notificationWriter(): JobEffect {
  return async (database, event) => {
    if (event.userId === null) throw new Error("invalid_event_payload");
    await database.query(
      `insert into argus_app.notifications(
         id,user_id,deletion_epoch,kind,title,body
       ) values ($1,$2,$3,'briefing_ready','Your Argus briefing is ready',
                 'Open Argus to view your latest reflection.')
       on conflict (user_id,id) do nothing`,
      [event.id, event.userId, event.deletionEpoch],
    );
    return `notification:${event.id}`;
  };
}

function mediaScan(storage: WorkerStoragePort): JobEffect {
  return async (database, event) => {
    if (event.userId === null) throw new Error("invalid_event_payload");
    const selected = await database.query<{
      bucket_id: string;
      object_path: string;
      mime_type: string;
      max_bytes: string | number;
      status: string;
      checksum: string | null;
    }>(
      "select * from argus_private.get_media_scan_target($1)",
      [event.id],
    );
    const intent = selected.rows[0];
    if (intent === undefined || !["uploaded", "scanning"].includes(intent.status)) {
      throw new Error("invalid_event_payload");
    }
    await assertCurrent(database, event.id);
    const object = await storage.get(intent.bucket_id, intent.object_path);
    if (object === null || object.body.byteLength > Number(intent.max_bytes)) {
      throw new Error("media_object_invalid");
    }
    const inspection = await inspectQuarantinedObject(object.body, {
      declaredMime: intent.mime_type,
      expectedChecksum: intent.checksum ?? "0".repeat(64),
      scanResult: "clean",
      actorId: event.userId,
      intendedActorId: event.userId,
      uploadIntentId: event.aggregateId,
      expectedUploadIntentId: event.aggregateId,
    });
    await assertCurrent(database, event.id);
    const accepted = inspection.validation.ok;
    const completed = await database.query<{ complete_media_scan: boolean }>(
      "select argus_private.complete_media_scan($1,$2,$3)",
      [event.id, accepted, inspection.checksum],
    );
    if (completed.rows[0]?.complete_media_scan !== true) {
      throw new Error("invalid_event_payload");
    }
    return `media:${event.aggregateId}:${accepted ? "accepted" : "rejected"}`;
  };
}

function mediaCleanup(storage: WorkerStoragePort): JobEffect {
  return async (database, event) => {
    const selected = await database.query<{ bucket_id: string; object_path: string }>(
      `select bucket_id,object_path from argus_private.media_upload_intents
        where id=$1 and status in ('accepted','rejected','expired')`,
      [event.aggregateId],
    );
    const object = selected.rows[0];
    if (object === undefined) return "media-cleanup-stale";
    await assertCurrent(database, event.id);
    await storage.remove(object.bucket_id, [object.object_path]);
    return `media-cleanup:${event.aggregateId}`;
  };
}

export const privacyExportCollections = Object.freeze([
  ["member", "select status,created_at from argus_app.members where user_id=$1"],
  ["profile", "select display_name,avatar_media_id,locale from argus_app.profiles where user_id=$1"],
  ["preferences", "select theme_mode,ritual_mode,timezone,locale,version from argus_app.preferences where user_id=$1"],
  ["astrology_profile", "select birth_date,derived_profile_code,algorithm_version,enabled_at from argus_app.astrology_profiles where user_id=$1"],
  ["investor_profile", "select goal_type,time_horizon,risk_comfort,version from argus_app.investor_profiles where user_id=$1"],
  ["onboarding", "select current_step,completed_steps,completed_at,version from argus_app.onboarding_states where user_id=$1"],
  ["consents", "select policy_code,policy_version,decision,recorded_at from argus_app.consent_records where user_id=$1 order by recorded_at,id"],
  ["notification_preferences", "select daily_ritual,weekly_recap,moon_cycle,quiet_hours,version from argus_app.notification_preferences where user_id=$1"],
  ["ritual_assignments", "select id,local_date,mode,state,revealed_at,completed_at from argus_app.daily_ritual_assignments where user_id=$1 order by local_date,id"],
  ["circles", "select id,title,description,version,archived_at from argus_app.circles where user_id=$1 order by id"],
  ["circle_assets", "select id,circle_id,asset_id,ordinal,weight_bps,note from argus_app.circle_assets where user_id=$1 order by circle_id,ordinal,id"],
  ["saved_items", "select item_kind,item_id,source_kind,source_id,saved_at from argus_app.saved_items where user_id=$1 order by saved_at,item_kind,item_id"],
  ["intentions", "select id,title,target_amount_minor::text,currency,target_date,status,version,created_at from argus_app.intentions where user_id=$1 order by id"],
  ["future_mirror_runs", "select id,intention_id,input_hash,model_version,assumptions,status,created_at,completed_at from argus_app.future_mirror_runs where user_id=$1 order by id"],
  ["future_mirror_points", "select run_id,ordinal,projected_date,amount_minor::text from argus_app.future_mirror_points where user_id=$1 order by run_id,ordinal"],
  ["briefings", "select id,briefing_type,period_start,period_end,status,generated_at from argus_app.briefings where user_id=$1 order by id"],
  ["briefing_sections", "select id,briefing_id,section_type,ordinal,payload from argus_app.briefing_sections where user_id=$1 order by briefing_id,ordinal"],
  ["notifications", "select id,kind,title,body,read_at,created_at from argus_app.notifications where user_id=$1 order by id"],
  ["privacy_requests", "select id,request_type,status,requested_at,completed_at,failure_code from argus_app.privacy_requests where user_id=$1 order by id"],
  ["content_reports", "select id,target_kind,target_id,reason_code,details,status,created_at from argus_app.content_reports where user_id=$1 order by id"],
] as const);

function privacyExport(storage: WorkerStoragePort): JobEffect {
  return async (database, event) => {
    if (event.userId === null) throw new Error("invalid_event_payload");
    const request = await database.query<{ requested_at: Date | string }>(
      `update argus_app.privacy_requests set status='processing',failure_code=null
        where id=$1 and user_id=$2 and deletion_epoch=$3
          and request_type='export' and status in ('requested','queued','processing')
        returning requested_at`,
      [event.aggregateId, event.userId, event.deletionEpoch],
    );
    const requestedAt = request.rows[0]?.requested_at;
    if (requestedAt === undefined) return "privacy-export-stale";
    const collections: StreamingExportCollection[] = privacyExportCollections.map(
      ([name, sql]) => ({
        name,
        readPage: async (offset, limit) =>
          (await database.query<{ value: unknown }>(
            `select to_jsonb(export_row) value from (${sql}) export_row limit $2 offset $3`,
            [event.userId, limit, offset],
          )).rows.map((row) => row.value),
      }),
    );
    const archive = buildStreamingPrivacyZip({
      tenantId: event.userId,
      requestId: event.aggregateId,
      snapshotAt: new Date(requestedAt).toISOString(),
      sourceSequence: Number(event.deletionEpoch ?? 0),
      collections,
      pageSize: 100,
    });
    const objectPath = `${event.userId}/${event.aggregateId}.zip`;
    await assertCurrent(database, event.id);
    await storage.put("privacy-exports", objectPath, archive.body, "application/zip");
    const completion = await archive.completion;
    await assertCurrent(database, event.id);
    await database.query(
      `insert into argus_private.privacy_export_artifacts(
         user_id,deletion_epoch,request_id,bucket_id,object_path,checksum,expires_at
       ) values ($1,$2,$3,'privacy-exports',$4,$5,clock_timestamp()+interval '7 days')
       on conflict (request_id) do update set object_path=excluded.object_path,
         checksum=excluded.checksum,expires_at=excluded.expires_at,revoked_at=null`,
      [event.userId, event.deletionEpoch, event.aggregateId, objectPath, completion.manifestChecksum],
    );
    await database.query(
      `update argus_app.privacy_requests set status='completed',completed_at=clock_timestamp()
        where id=$1 and user_id=$2 and deletion_epoch=$3 and status='processing'`,
      [event.aggregateId, event.userId, event.deletionEpoch],
    );
    return completion.manifestChecksum;
  };
}

function privacyExportRetention(storage: WorkerStoragePort): JobEffect {
  return async (database, event) => {
    if (event.userId === null) throw new Error("invalid_event_payload");
    const artifact = await database.query<{ bucket_id: string; object_path: string }>(
      `select bucket_id,object_path from argus_private.privacy_export_artifacts
        where id=$1 and user_id=$2 and deletion_epoch=$3
          and expires_at<=clock_timestamp() and revoked_at is null for update`,
      [event.aggregateId, event.userId, event.deletionEpoch],
    );
    const object = artifact.rows[0];
    if (object === undefined) return "privacy-retention-stale";
    await assertCurrent(database, event.id);
    await storage.remove(object.bucket_id, [object.object_path]);
    await assertCurrent(database, event.id);
    await database.query(
      "update argus_private.privacy_export_artifacts set revoked_at=clock_timestamp() where id=$1",
      [event.aggregateId],
    );
    return `privacy-retained:${event.aggregateId}`;
  };
}

export async function runPrivacyPurge(
  event: OutboxEvent,
  purgeSaga: WorkerPurgeSagaPort,
  keepAlive?: () => Promise<void>,
): Promise<string> {
  if (event.userId !== null || event.deletionEpoch !== null) {
    throw new Error("invalid_event_payload");
  }
  return purgeSaga.run(event.aggregateId, keepAlive);
}

function privacyPurge(purgeSaga: WorkerPurgeSagaPort): JobEffect {
  return async (_database, event) => runPrivacyPurge(event, purgeSaga);
}

function moderationTriage(): JobEffect {
  return async (database, event) => {
    const result = await database.query<{ outcome: string }>(
      "select argus_private.triage_content_report($1) as outcome",
      [event.id],
    );
    return result.rows[0]?.outcome ?? "global-job-stale";
  };
}

export function handlerFor(
  event: OutboxEvent,
  dependencies: JobHandlerDependencies,
): JobEffect {
  switch (event.handlerName) {
    case "briefing-builder":
      return briefingBuilder();
    case "notification-writer":
      return notificationWriter();
    case "media-scan":
      return mediaScan(dependencies.storage);
    case "media-cleanup":
      return mediaCleanup(dependencies.storage);
    case "privacy-export":
      return privacyExport(dependencies.storage);
    case "privacy-export-retention":
      return privacyExportRetention(dependencies.storage);
    case "privacy-purge":
      return privacyPurge(dependencies.purgeSaga);
    case "moderation-triage":
      return moderationTriage();
  }
}

export async function effectHash(effect: string): Promise<string> {
  return sha256TextHex(effect);
}
