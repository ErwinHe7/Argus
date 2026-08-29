import type { DatabaseClient } from "../../../../ritual-investing-api/src/db/database-port.ts";
import { inspectQuarantinedObject } from "../../../../ritual-investing-api/src/domains/media/service.ts";
import type { OutboxEvent } from "../../../../ritual-investing-api/src/jobs/consumer-receipts.ts";
import type { WorkerMediaSagaPort } from "../../../../ritual-investing-api/src/jobs/media.ts";
import type { WorkerTransaction } from "./purge.ts";
import type { PrivateStorage } from "./storage.ts";

type PreparedValidation = Readonly<{
  effect_id: string;
  effect_state: string;
  storage_object_id: string;
  bucket_id: string;
  object_path: string;
  mime_type: string;
  max_bytes: string | number;
  expected_checksum: string;
  user_id: string;
  upload_intent_id: string;
}>;

type PreparedCleanup = Readonly<{
  effect_id: string;
  effect_state: string;
  storage_object_id: string;
  bucket_id: string;
  object_path: string;
}>;

async function first<Row>(
  transaction: WorkerTransaction,
  sql: string,
  values: readonly unknown[],
): Promise<Row> {
  return transaction(async (database: DatabaseClient) => {
    const result = await database.query<Row>(sql, values);
    const row = result.rows[0];
    if (row === undefined) throw new Error("invalid_event_payload");
    return row;
  });
}

export function createMediaStorageSaga(
  config: Readonly<{
    storage: PrivateStorage;
    transaction: WorkerTransaction;
  }>,
): WorkerMediaSagaPort {
  return Object.freeze({
    async validate(event: OutboxEvent, keepAlive = async () => undefined) {
      const prepared = await first<PreparedValidation>(
        config.transaction,
        "select * from argus_private.prepare_media_structural_validation($1)",
        [event.id],
      );
      if (["succeeded", "rejected"].includes(prepared.effect_state)) {
        return `media:${prepared.upload_intent_id}:${prepared.effect_state}`;
      }
      await keepAlive();
      const object = await config.storage.get(
        prepared.bucket_id,
        prepared.object_path,
      );
      if (object === null) {
        await config.transaction((database) =>
          database.query(
            "select argus_private.mark_media_structural_reconciliation($1,$2)",
            [prepared.effect_id, "object_missing"],
          ).then(() => undefined)
        );
        throw new Error("storage_object_missing");
      }
      const inspection = await inspectQuarantinedObject(object.body, {
        declaredMime: prepared.mime_type,
        expectedChecksum: prepared.expected_checksum,
        actorId: prepared.user_id,
        intendedActorId: prepared.user_id,
        uploadIntentId: prepared.upload_intent_id,
        expectedUploadIntentId: prepared.upload_intent_id,
      });
      const accepted = inspection.validation.ok &&
        object.body.byteLength <= Number(prepared.max_bytes);
      const reason = accepted
        ? null
        : inspection.validation.ok
        ? "file_too_large"
        : inspection.validation.code;
      await keepAlive();
      await config.transaction((database) =>
        database.query(
          "select argus_private.complete_media_structural_validation($1,$2,$3,$4,$5,$6)",
          [
            prepared.effect_id,
            accepted,
            inspection.checksum,
            inspection.width,
            inspection.height,
            reason,
          ],
        ).then(() => undefined)
      );
      return `media:${prepared.upload_intent_id}:${
        accepted ? "structurally_verified" : "rejected"
      }`;
    },

    async cleanup(event: OutboxEvent, keepAlive = async () => undefined) {
      const prepared = await first<PreparedCleanup>(
        config.transaction,
        "select * from argus_private.prepare_media_cleanup($1)",
        [event.id],
      );
      if (prepared.effect_state === "deleted") {
        return `media-cleanup:${event.aggregateId}:deleted`;
      }
      await keepAlive();
      await config.storage.remove(prepared.bucket_id, [prepared.object_path]);
      await keepAlive();
      await config.transaction((database) =>
        database.query(
          "select argus_private.complete_media_cleanup($1)",
          [prepared.effect_id],
        ).then(() => undefined)
      );
      return `media-cleanup:${event.aggregateId}:deleted`;
    },
  });
}
