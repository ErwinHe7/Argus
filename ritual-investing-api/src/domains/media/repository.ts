import type { DatabaseTransaction } from "../../db/database-port.ts";
import { first, type JsonObject } from "../../db/repository-support.ts";

export function createSupabaseMediaRepository(
  database: DatabaseTransaction,
) {
  return Object.freeze({
    createUploadIntent: async (
      input: Readonly<{
        mimeType: "image/jpeg" | "image/png" | "image/webp";
        maxBytes: number;
        expiresAt: Date;
      }>,
    ) => {
      const result = await database.query<JsonObject>(
        `select * from argus_private.create_media_upload_intent($1,$2,$3)`,
        [
          input.mimeType,
          input.maxBytes,
          input.expiresAt,
        ],
      );
      return first(result.rows);
    },
    getUploadIntent: async (id: string) => {
      const result = await database.query<JsonObject>(
        `select * from argus_private.get_member_media_upload_intent($1)`,
        [id],
      );
      return result.rows[0] ?? null;
    },
    finalizeUpload: async (
      intentId: string,
      byteSize: number,
      checksum: string,
    ) => {
      const result = await database.query<JsonObject>(
        `select (argus_private.finalize_media_upload($1,$2,$3)).*`,
        [intentId, byteSize, checksum],
      );
      return first(result.rows);
    },
    getAsset: async (id: string) => {
      const result = await database.query<JsonObject>(
        `select * from argus_app.media_assets where id = $1`,
        [id],
      );
      return result.rows[0] ?? null;
    },
  });
}
