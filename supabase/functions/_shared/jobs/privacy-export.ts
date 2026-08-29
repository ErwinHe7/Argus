import { createHash } from "node:crypto";

import type { DatabaseClient } from "../../../../ritual-investing-api/src/db/database-port.ts";
import { buildStreamingPrivacyZip } from "../../../../ritual-investing-api/src/domains/privacy/service.ts";
import type { OutboxEvent } from "../../../../ritual-investing-api/src/jobs/consumer-receipts.ts";
import {
  privacyExportCollections,
  type WorkerPrivacyExportSagaPort,
} from "../../../../ritual-investing-api/src/jobs/privacy-export.ts";
import type { WorkerTransaction } from "./purge.ts";
import type { PrivateStorage } from "./storage.ts";

type PreparedGeneration = Readonly<{
  generation_id: string;
  generation_number: number;
  generation_state: string;
  tenant_id: string;
  lifecycle_id: string;
  user_id: string;
  request_id: string;
  cutoff_at: Date | string;
  seal_checksum: string;
  archive_checksum: string | null;
  storage_object_id: string;
  bucket_id: string;
  object_path: string;
}>;

type SealedObject = Readonly<{
  bucket_id: string;
  object_path: string;
  content_checksum: string;
}>;

type PreparedRetention = Readonly<{
  generation_id: string;
  effect_id: string;
  effect_state: string;
  bucket_id: string;
  object_path: string;
}>;

const maximumArchiveBytes = 50 * 1024 * 1024;

function archiveByteLimit(configured?: number): number {
  if (configured === undefined) return maximumArchiveBytes;
  if (
    !Number.isSafeInteger(configured) || configured < 1 ||
    configured > maximumArchiveBytes
  ) {
    throw new Error("invalid_privacy_export_archive_limit");
  }
  return configured;
}

async function inspectArchive(
  body: ReadableStream<Uint8Array>,
  limit: number,
  keepAlive: () => Promise<void>,
): Promise<Readonly<{ byteLength: number; checksum: string }>> {
  const reader = body.getReader();
  const digest = createHash("sha256");
  let byteLength = 0;
  let complete = false;
  try {
    for (;;) {
      await keepAlive();
      const next = await reader.read();
      if (next.done) {
        complete = true;
        break;
      }
      if (byteLength > limit - next.value.byteLength) {
        throw new Error("privacy_export_archive_too_large");
      }
      byteLength += next.value.byteLength;
      digest.update(next.value);
    }
  } finally {
    if (!complete) await reader.cancel("privacy_export_archive_cancelled");
    reader.releaseLock();
  }
  return { byteLength, checksum: digest.digest("hex") };
}

function renewingStream(
  body: ReadableStream<Uint8Array>,
  keepAlive: () => Promise<void>,
): ReadableStream<Uint8Array> {
  const reader = body.getReader();
  let released = false;
  const release = () => {
    if (released) return;
    released = true;
    reader.releaseLock();
  };
  return new ReadableStream({
    async pull(controller) {
      try {
        await keepAlive();
        const next = await reader.read();
        if (next.done) {
          controller.close();
          release();
        } else {
          controller.enqueue(next.value);
        }
      } catch (error) {
        controller.error(error);
        try {
          await reader.cancel(error);
        } finally {
          release();
        }
      }
    },
    async cancel(reason) {
      try {
        await reader.cancel(reason);
      } finally {
        release();
      }
    },
  });
}

function verifiedSourceStream(
  body: ReadableStream<Uint8Array>,
  expectedChecksum: string,
  keepAlive: () => Promise<void>,
): ReadableStream<Uint8Array> {
  const reader = body.getReader();
  const digest = createHash("sha256");
  let released = false;
  const release = () => {
    if (released) return;
    released = true;
    reader.releaseLock();
  };
  return new ReadableStream({
    async pull(controller) {
      try {
        await keepAlive();
        const next = await reader.read();
        if (next.done) {
          if (digest.digest("hex") !== expectedChecksum) {
            throw new Error("privacy_export_source_mismatch");
          }
          controller.close();
          release();
        } else {
          digest.update(next.value);
          controller.enqueue(next.value);
        }
      } catch (error) {
        controller.error(error);
        try {
          await reader.cancel(error);
        } finally {
          release();
        }
      }
    },
    async cancel(reason) {
      try {
        await reader.cancel(reason);
      } finally {
        release();
      }
    },
  });
}

async function one<Row>(
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

export function createPrivacyExportSaga(
  config: Readonly<{
    storage: PrivateStorage;
    transaction: WorkerTransaction;
    archiveByteLimit?: number;
  }>,
): WorkerPrivacyExportSagaPort {
  return Object.freeze({
    async exportGeneration(
      event: OutboxEvent,
      keepAlive = async () => undefined,
    ) {
      const prepared = await one<PreparedGeneration>(
        config.transaction,
        "select * from argus_private.prepare_privacy_export_generation($1)",
        [event.id],
      );
      if (
        prepared.generation_state === "published" && prepared.archive_checksum
      ) {
        return prepared.seal_checksum;
      }
      try {
        const limit = archiveByteLimit(config.archiveByteLimit);
        const sourceObjects = await config.transaction(async (database) =>
          (await database.query<SealedObject>(
            "select * from argus_private.list_privacy_export_generation_objects($1)",
            [prepared.generation_id],
          )).rows
        );
        const collections = privacyExportCollections.map((collection) => ({
          name: collection.name,
          readPage: async (offset: number, pageLimit: number) => {
            await keepAlive();
            const page = await config.transaction(async (database) =>
              (await database.query<{ row_payload: unknown }>(
                "select row_payload from argus_private.read_privacy_export_generation_page($1,$2,$3,$4)",
                [
                  prepared.generation_id,
                  collection.name,
                  offset,
                  pageLimit,
                ],
              )).rows.map((row) => row.row_payload)
            );
            await keepAlive();
            return page;
          },
        }));
        const files = [...sourceObjects]
          .sort((left, right) => {
            const leftName = `${left.bucket_id}/${left.object_path}`;
            const rightName = `${right.bucket_id}/${right.object_path}`;
            return leftName < rightName ? -1 : leftName > rightName ? 1 : 0;
          })
          .map((source) => ({
            name: `objects/${source.bucket_id}/${source.object_path}`,
            contentChecksum: source.content_checksum,
            open: async () => {
              await keepAlive();
              const object = await config.storage.getStream(
                source.bucket_id,
                source.object_path,
              );
              if (object === null) {
                throw new Error("privacy_export_source_mismatch");
              }
              return verifiedSourceStream(
                object.body,
                source.content_checksum,
                keepAlive,
              );
            },
          }));
        const buildArchive = () =>
          buildStreamingPrivacyZip({
            tenantId: prepared.tenant_id,
            requestId: prepared.request_id,
            snapshotAt: new Date(prepared.cutoff_at).toISOString(),
            sourceSequence: prepared.generation_number,
            sealedManifestChecksum: prepared.seal_checksum,
            collections,
            files,
            pageSize: 100,
          });
        const inspectionArchive = buildArchive();
        const inspection = await inspectArchive(
          inspectionArchive.body,
          limit,
          keepAlive,
        );
        const inspectedCompletion = await inspectionArchive.completion;
        const uploadArchive = buildArchive();
        await keepAlive();
        await config.storage.putImmutable(
          prepared.bucket_id,
          prepared.object_path,
          renewingStream(uploadArchive.body, keepAlive),
          "application/zip",
          inspection.checksum,
          inspection.byteLength,
        );
        const completion = await uploadArchive.completion;
        if (
          completion.manifestChecksum !==
            inspectedCompletion.manifestChecksum
        ) {
          throw new Error("privacy_export_manifest_mismatch");
        }
        await keepAlive();
        await config.transaction((database) =>
          database.query(
            "select argus_private.complete_privacy_export_generation($1,$2,$3,$4,$5)",
            [
              prepared.generation_id,
              prepared.seal_checksum,
              completion.manifestChecksum,
              inspection.checksum,
              inspection.byteLength,
            ],
          ).then(() => undefined)
        );
        return prepared.seal_checksum;
      } catch (error) {
        const reason = error instanceof Error && [
            "privacy_export_source_mismatch",
            "privacy_export_manifest_mismatch",
            "storage_object_conflict",
          ].includes(error.message)
          ? error.message
          : "privacy_export_assembly_failed";
        await config.transaction((database) =>
          database.query(
            "select argus_private.fail_privacy_export_generation($1,$2)",
            [prepared.generation_id, reason],
          ).then(() => undefined)
        );
        throw error;
      }
    },

    async expireGeneration(
      event: OutboxEvent,
      keepAlive = async () => undefined,
    ) {
      const prepared = await one<PreparedRetention>(
        config.transaction,
        "select * from argus_private.prepare_privacy_export_retention($1)",
        [event.id],
      );
      if (prepared.effect_state === "deleted") {
        return `privacy-export-retention:${prepared.generation_id}:deleted`;
      }
      await keepAlive();
      await config.storage.remove(prepared.bucket_id, [prepared.object_path]);
      await keepAlive();
      await config.transaction((database) =>
        database.query(
          "select argus_private.complete_privacy_export_retention($1)",
          [prepared.effect_id],
        ).then(() => undefined)
      );
      return `privacy-export-retention:${prepared.generation_id}:deleted`;
    },
  });
}
