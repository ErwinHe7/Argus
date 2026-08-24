import { Pool } from "@neondatabase/serverless";

import { parsePagePosition } from "../../contracts/page-position.ts";
import type { DatabasePoolFactory } from "../../db/client.ts";
import type { StaffPrincipal } from "../../middleware/cloudflare-access.ts";
import { sha256TextHex as digest } from "../../security/sha256.ts";
import type { AdminMedia, MediaUploadRequest } from "./schemas.ts";

export type UploadIntent = {
  id: string;
  r2Key: string;
  expectedMime: string;
  expectedByteSize: number;
  expectedChecksum: string;
  actorStaffId: string;
  status: string;
  expiresAt: Date;
};

export type MediaPageInput = {
  status?: string;
  mimeType?: string;
  search?: string;
  limit: number;
  after?: string;
};

export interface MediaRepository {
  createIntent(
    staff: StaffPrincipal,
    input: MediaUploadRequest,
    idempotencyKey: string,
    requestId: string,
  ): Promise<UploadIntent>;
  getIntentForCompletion(
    staff: StaffPrincipal,
    id: string,
  ): Promise<UploadIntent | null>;
  markUploaded(staff: StaffPrincipal, id: string): Promise<boolean>;
  queueScan(
    staff: StaffPrincipal,
    id: string,
    checksum: string,
    idempotencyKey: string,
    requestId: string,
  ): Promise<string | null>;
  list(
    staff: StaffPrincipal,
    input: MediaPageInput,
  ): Promise<{ items: AdminMedia[]; next: string | null }>;
  get(staff: StaffPrincipal, id: string): Promise<AdminMedia | null>;
  retire(
    staff: StaffPrincipal,
    id: string,
    version: number,
    reason: string,
    requestId: string,
  ): Promise<string | null>;
}

export class MediaConflictError extends Error {
  readonly code: "idempotency_conflict" | "referenced" | "version_conflict";

  constructor(
    code: "idempotency_conflict" | "referenced" | "version_conflict",
  ) {
    super(code);
    this.name = "MediaConflictError";
    this.code = code;
  }
}

type AdminMediaRow = AdminMedia & { created_at: Date };
const mediaColumns = `
  i.id,i.expected_mime mime_type,i.expected_byte_size::integer byte_size,
  i.expected_checksum checksum,i.status upload_status,
  coalesce(asset.quarantine_status,'pending') quarantine_status,
  asset.scan_result,
  case when asset.id is null then 'unavailable' else asset.status end derivative_status,
  ((select count(*) from ritual_scenario_revisions where art_media_id=i.id)+
   (select count(*) from grimoire_revisions where art_media_id=i.id)+
   (select count(*) from seeded_creators where avatar_media_id=i.id)+
   (select count(*) from circle_template_revisions where art_media_id=i.id))::integer reference_count,
  coalesce(asset.version,1) version,i.created_at`;

function mediaView(row: AdminMediaRow): AdminMedia {
  const { created_at: _createdAt, ...view } = row;
  return view;
}

function mapCommandError(error: unknown): never {
  if (error instanceof Error) {
    if (error.message.includes("idempotency_conflict"))
      throw new MediaConflictError("idempotency_conflict");
    if (error.message.includes("media asset is referenced"))
      throw new MediaConflictError("referenced");
    if (error.message.includes("media version conflict"))
      throw new MediaConflictError("version_conflict");
  }
  throw error;
}

export function createPostgresMediaRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): MediaRepository {
  const scoped = async <T>(
    staff: StaffPrincipal,
    fn: (
      client: Awaited<ReturnType<ReturnType<DatabasePoolFactory>["connect"]>>,
    ) => Promise<T>,
  ) => {
    const pool =
      poolFactory?.(databaseUrl) ??
      new Pool({ connectionString: databaseUrl, max: 1 });
    const client = await pool.connect();
    try {
      await client.query("begin");
      await client.query("set local role ritual_staff");
      await client.query("select set_config('ritual.staff_id',$1,true)", [
        staff.id,
      ]);
      const result = await fn(client);
      await client.query("commit");
      return result;
    } catch (error) {
      await client.query("rollback").catch(() => undefined);
      throw error;
    } finally {
      client.release();
      await pool.end();
    }
  };

  return {
    createIntent: async (staff, input, idempotencyKey, requestId) => {
      try {
        return await scoped(staff, async (client) => {
          const requestHash = await digest(JSON.stringify(input));
          const id = (
            await client.query<{ id: string }>(
              `select ritual_private.create_media_upload_intent($1,$2,$3,$4,$5,$6,$7,$8) id`,
              [
                crypto.randomUUID(),
                staff.id,
                input.mime_type,
                input.byte_size,
                input.checksum,
                idempotencyKey,
                requestHash,
                requestId,
              ],
            )
          ).rows[0]!.id;
          return (
            await client.query<UploadIntent>(
              `select id,r2_key "r2Key",expected_mime "expectedMime",expected_byte_size "expectedByteSize",
                    expected_checksum "expectedChecksum",actor_staff_id "actorStaffId",status,expires_at "expiresAt"
               from media_upload_intents where id=$1 and actor_staff_id=$2`,
              [id, staff.id],
            )
          ).rows[0]!;
        });
      } catch (error) {
        return mapCommandError(error);
      }
    },
    getIntentForCompletion: (staff, id) =>
      scoped(
        staff,
        async (client) =>
          (
            await client.query<UploadIntent>(
              `select id,r2_key "r2Key",expected_mime "expectedMime",expected_byte_size "expectedByteSize",
              expected_checksum "expectedChecksum",actor_staff_id "actorStaffId",status,expires_at "expiresAt"
         from media_upload_intents where id=$1 and actor_staff_id=$2 and status in ('issued','uploaded')
          and expires_at>now() for update`,
              [id, staff.id],
            )
          ).rows[0] ?? null,
      ),
    markUploaded: (staff, id) =>
      scoped(
        staff,
        async (client) =>
          (
            await client.query(
              `update media_upload_intents set status='uploaded' where id=$1 and actor_staff_id=$2
        and status='issued' and expires_at>now()`,
              [id, staff.id],
            )
          ).rowCount === 1,
      ),
    queueScan: async (staff, id, checksum, idempotencyKey, requestId) => {
      try {
        return await scoped(staff, async (client) => {
          const requestHash = await digest(
            `media.complete:${id}:${checksum}:v1`,
          );
          return (
            await client.query<{ outbox_id: string }>(
              `select ritual_private.queue_media_scan($1,$2,$3,$4,$5,$6) outbox_id`,
              [id, staff.id, checksum, idempotencyKey, requestHash, requestId],
            )
          ).rows[0]!.outbox_id;
        });
      } catch (error) {
        if (
          typeof error === "object" &&
          error !== null &&
          "code" in error &&
          error.code === "P0002"
        )
          return null;
        return mapCommandError(error);
      }
    },
    list: (staff, input) =>
      scoped(staff, async (client) => {
        const [afterCreated, afterId] = parsePagePosition(input.after);
        const rows = (
          await client.query<AdminMediaRow>(
            `select ${mediaColumns}
           from media_upload_intents i left join media_assets asset on asset.upload_intent_id=i.id
          where ($1::text is null or i.status=$1) and ($2::text is null or i.expected_mime=$2)
            and ($3::text is null or i.id::text like lower($3) || '%' or i.expected_checksum like lower($3) || '%')
            and ($4::timestamptz is null or (i.created_at,i.id)<($4,$5::uuid))
          order by i.created_at desc,i.id desc limit $6`,
            [
              input.status ?? null,
              input.mimeType ?? null,
              input.search ?? null,
              afterCreated,
              afterId,
              input.limit + 1,
            ],
          )
        ).rows;
        const items = rows.slice(0, input.limit).map(mediaView);
        const tail =
          rows.length > input.limit ? rows[input.limit - 1] : undefined;
        return {
          items,
          next:
            tail === undefined
              ? null
              : `${tail.created_at.toISOString()}|${tail.id}`,
        };
      }),
    get: (staff, id) =>
      scoped(staff, async (client) => {
        const row = (
          await client.query<AdminMediaRow>(
            `select ${mediaColumns}
           from media_upload_intents i left join media_assets asset on asset.upload_intent_id=i.id where i.id=$1`,
            [id],
          )
        ).rows[0];
        return row === undefined ? null : mediaView(row);
      }),
    retire: async (staff, id, version, reason, requestId) => {
      try {
        return await scoped(
          staff,
          async (client) =>
            (
              await client.query<{ outbox_id: string }>(
                `select ritual_private.retire_media_asset($1,$2,$3,$4,$5) outbox_id`,
                [id, staff.id, version, reason, requestId],
              )
            ).rows[0]!.outbox_id,
        );
      } catch (error) {
        if (
          typeof error === "object" &&
          error !== null &&
          "code" in error &&
          error.code === "P0002"
        )
          return null;
        return mapCommandError(error);
      }
    },
  };
}
