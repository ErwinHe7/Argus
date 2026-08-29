import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.15";
import { createHash } from "node:crypto";

import type { DatabaseClient } from "../../../ritual-investing-api/src/db/database-port.ts";
import type { OutboxEvent } from "../../../ritual-investing-api/src/jobs/consumer-receipts.ts";
import { createPrivacyExportSaga } from "../_shared/jobs/privacy-export.ts";
import {
  createPrivateSupabaseStorage,
  type PrivateStorage,
} from "../_shared/jobs/storage.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789101";
const lifecycleId = "018f3c2a-4b67-7a89-8abc-123456789102";
const generationId = "018f3c2a-4b67-7a89-8abc-123456789103";
const requestId = "018f3c2a-4b67-7a89-8abc-123456789104";
const storageObjectId = "018f3c2a-4b67-7a89-8abc-123456789105";
const sealChecksum = "a".repeat(64);

const event: OutboxEvent = {
  id: "018f3c2a-4b67-7a89-8abc-123456789106",
  eventType: "privacy.export.requested",
  handlerName: "privacy-export",
  aggregateId: generationId,
  tenantId: userId,
  lifecycleId,
  userId,
  deletionEpoch: null,
};

type PrivacyExportFixtureOptions = Readonly<{
  archiveByteLimit?: number;
  requirePageRenewal?: boolean;
  requireStreamUpload?: boolean;
  rows?: (offset: number, limit: number) => unknown[];
  sealedObjects?: readonly Readonly<{
    bucket: string;
    path: string;
    body: Uint8Array;
  }>[];
}>;

function concatenate(parts: readonly Uint8Array[]): Uint8Array {
  const result = new Uint8Array(
    parts.reduce((length, part) => length + part.byteLength, 0),
  );
  let offset = 0;
  for (const part of parts) {
    result.set(part, offset);
    offset += part.byteLength;
  }
  return result;
}

function storedZipEntries(
  archive: Uint8Array,
): readonly Readonly<{ name: string; body: Uint8Array }>[] {
  const view = new DataView(
    archive.buffer,
    archive.byteOffset,
    archive.byteLength,
  );
  let endOffset = archive.byteLength - 22;
  while (endOffset >= 0 && view.getUint32(endOffset, true) !== 0x06054b50) {
    endOffset -= 1;
  }
  if (endOffset < 0) throw new Error("invalid_test_zip");
  const entryCount = view.getUint16(endOffset + 10, true);
  let centralOffset = view.getUint32(endOffset + 16, true);
  const decoder = new TextDecoder();
  const entries: Array<Readonly<{ name: string; body: Uint8Array }>> = [];
  for (let index = 0; index < entryCount; index += 1) {
    if (view.getUint32(centralOffset, true) !== 0x02014b50) {
      throw new Error("invalid_test_zip");
    }
    const size = view.getUint32(centralOffset + 20, true);
    const nameLength = view.getUint16(centralOffset + 28, true);
    const extraLength = view.getUint16(centralOffset + 30, true);
    const commentLength = view.getUint16(centralOffset + 32, true);
    const localOffset = view.getUint32(centralOffset + 42, true);
    const name = decoder.decode(
      archive.subarray(centralOffset + 46, centralOffset + 46 + nameLength),
    );
    if (view.getUint32(localOffset, true) !== 0x04034b50) {
      throw new Error("invalid_test_zip");
    }
    const localNameLength = view.getUint16(localOffset + 26, true);
    const localExtraLength = view.getUint16(localOffset + 28, true);
    const bodyOffset = localOffset + 30 + localNameLength + localExtraLength;
    entries.push({ name, body: archive.slice(bodyOffset, bodyOffset + size) });
    centralOffset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

function privacyExportFixture(options: PrivacyExportFixtureOptions = {}) {
  let archiveBytes = 0;
  let archiveChunks = 0;
  let completionCalls = 0;
  let failureCalls = 0;
  let failureReason: string | null = null;
  let keepAliveCalls = 0;
  let largestChunk = 0;
  let pageReads = 0;
  let previousPageRenewal = 0;
  let uploadCalls = 0;
  const memberOffsets: number[] = [];
  const objectGets: string[] = [];
  const uploadedParts: Uint8Array[] = [];
  const client: DatabaseClient = {
    async query<Row>(sql: string, values: readonly unknown[] = []) {
      if (sql.includes("prepare_privacy_export_generation")) {
        return {
          rows: [{
            generation_id: generationId,
            generation_number: 1,
            generation_state: "assembling",
            tenant_id: userId,
            lifecycle_id: lifecycleId,
            user_id: userId,
            request_id: requestId,
            cutoff_at: "2026-08-29T12:00:00.000Z",
            seal_checksum: sealChecksum,
            archive_checksum: null,
            storage_object_id: storageObjectId,
            bucket_id: "privacy-exports",
            object_path: `${userId}/exports/${generationId}.zip`,
          } as Row],
        };
      }
      if (sql.includes("list_privacy_export_generation_objects")) {
        return {
          rows: (options.sealedObjects ?? []).map((object) => ({
            bucket_id: object.bucket,
            object_path: object.path,
            content_checksum: createHash("sha256").update(object.body).digest(
              "hex",
            ),
          } as Row)),
        };
      }
      if (sql.includes("read_privacy_export_generation_page")) {
        pageReads += 1;
        if (
          options.requirePageRenewal &&
          keepAliveCalls <= previousPageRenewal
        ) {
          throw new Error("lease_not_renewed_before_page");
        }
        previousPageRenewal = keepAliveCalls;
        const collection = String(values[1]);
        const offset = Number(values[2]);
        const limit = Number(values[3]);
        if (collection !== "member") return { rows: [] };
        memberOffsets.push(offset);
        return {
          rows: (options.rows?.(offset, limit) ??
            (offset === 0 ? [{ id: userId, display_name: "Rowan" }] : []))
            .map((row) => ({ row_payload: row } as Row)),
        };
      }
      if (sql.includes("complete_privacy_export_generation")) {
        completionCalls += 1;
      }
      if (sql.includes("fail_privacy_export_generation")) {
        failureCalls += 1;
        failureReason = String(values[1]);
      }
      return { rows: [] };
    },
    release() {},
  };
  const transaction = async <T>(
    callback: (database: DatabaseClient) => Promise<T>,
  ) => await callback(client);
  const storage: PrivateStorage = {
    async get() {
      throw new Error("privacy_export_source_not_streamed");
    },
    async getStream(bucket, path) {
      objectGets.push(`${bucket}/${path}`);
      const object = options.sealedObjects?.find((candidate) =>
        candidate.bucket === bucket && candidate.path === path
      );
      if (!object) return null;
      return {
        body: new ReadableStream<Uint8Array>({
          start(controller) {
            const midpoint = Math.max(1, Math.floor(object.body.length / 2));
            controller.enqueue(object.body.slice(0, midpoint));
            if (midpoint < object.body.length) {
              controller.enqueue(object.body.slice(midpoint));
            }
            controller.close();
          },
        }),
        contentType: "application/octet-stream",
      };
    },
    async putImmutable(
      _bucket: string,
      _path: string,
      body: Uint8Array | ReadableStream<Uint8Array>,
      _contentType: string,
      expectedChecksum: string,
      expectedByteLength?: number,
    ) {
      uploadCalls += 1;
      if (!options.requireStreamUpload) return "created";
      if (!(body instanceof ReadableStream)) {
        throw new Error("privacy_export_upload_not_streaming");
      }
      const digest = createHash("sha256");
      const reader = body.getReader();
      for (;;) {
        const next = await reader.read();
        if (next.done) break;
        archiveChunks += 1;
        archiveBytes += next.value.byteLength;
        largestChunk = Math.max(largestChunk, next.value.byteLength);
        digest.update(next.value);
        uploadedParts.push(next.value.slice());
      }
      assertEquals(digest.digest("hex"), expectedChecksum);
      assertEquals(archiveBytes, expectedByteLength);
      return "created";
    },
    async remove() {},
    async createSignedUrl() {
      return "https://signed.invalid";
    },
  };
  const sagaConfig = {
    storage,
    transaction,
    archiveByteLimit: options.archiveByteLimit,
  } as Parameters<typeof createPrivacyExportSaga>[0] & {
    archiveByteLimit?: number;
  };
  return {
    saga: createPrivacyExportSaga(sagaConfig),
    keepAlive: async () => {
      keepAliveCalls += 1;
    },
    state: () => ({
      archiveBytes,
      archiveChunks,
      completionCalls,
      failureCalls,
      failureReason,
      keepAliveCalls,
      largestChunk,
      memberOffsets,
      objectGets,
      pageReads,
      uploadCalls,
      uploadedBody: concatenate(uploadedParts),
    }),
  };
}

Deno.test("privacy export uploads the bounded archive as a stream", async () => {
  const fixture = privacyExportFixture({ requireStreamUpload: true });
  assertEquals(
    await fixture.saga.exportGeneration(event, fixture.keepAlive),
    sealChecksum,
  );
  const state = fixture.state();
  assertEquals(state.uploadCalls, 1);
  assertEquals(state.completionCalls, 1);
  assertEquals(state.failureCalls, 0);
  assertEquals(state.archiveChunks > 1, true);
  assertEquals(state.archiveBytes > state.largestChunk, true);
  assertEquals(state.memberOffsets, [0, 0]);
});

Deno.test("privacy export renews its lease during every page and stream pass", async () => {
  const fixture = privacyExportFixture({
    requirePageRenewal: true,
    requireStreamUpload: true,
    rows(offset, limit) {
      if (offset === 0) {
        return Array.from(
          { length: limit },
          (_, ordinal) => ({ ordinal }),
        );
      }
      return offset === limit ? [{ ordinal: limit }] : [];
    },
  });
  await fixture.saga.exportGeneration(event, fixture.keepAlive);
  const state = fixture.state();
  assertEquals(state.memberOffsets, [0, 100, 0, 100]);
  assertEquals(state.keepAliveCalls > state.pageReads, true);
  assertEquals(state.completionCalls, 1);
});

Deno.test("privacy export rejects an oversized archive before upload", async () => {
  const fixture = privacyExportFixture({
    archiveByteLimit: 1_024,
    rows: (offset) => offset === 0 ? [{ payload: "x".repeat(4_096) }] : [],
  });
  await assertRejects(
    () => fixture.saga.exportGeneration(event, fixture.keepAlive),
    Error,
    "privacy_export_archive_too_large",
  );
  const state = fixture.state();
  assertEquals(state.uploadCalls, 0);
  assertEquals(state.completionCalls, 0);
  assertEquals(state.failureCalls, 1);
  assertEquals(state.failureReason, "privacy_export_assembly_failed");
});

Deno.test("privacy export includes every sealed media object", async () => {
  const avatarPath = `${userId}/avatar.png`;
  const avatarBody = new TextEncoder().encode("sealed-avatar-binary");
  const receiptPath = `${userId}/receipt.pdf`;
  const receiptBody = new TextEncoder().encode("sealed-receipt-binary");
  const fixture = privacyExportFixture({
    requireStreamUpload: true,
    sealedObjects: [
      {
        bucket: "member-media",
        path: receiptPath,
        body: receiptBody,
      },
      {
        bucket: "member-media",
        path: avatarPath,
        body: avatarBody,
      },
    ],
  });
  await fixture.saga.exportGeneration(event, fixture.keepAlive);
  const state = fixture.state();
  const entries = storedZipEntries(state.uploadedBody);
  assertEquals(entries.map((entry) => entry.name), [
    "data.ndjson",
    `objects/member-media/${avatarPath}`,
    `objects/member-media/${receiptPath}`,
    "manifest.json",
  ]);
  assertEquals(entries[1]?.body, avatarBody);
  assertEquals(entries[2]?.body, receiptBody);
  assertEquals(state.objectGets, [
    `member-media/${avatarPath}`,
    `member-media/${receiptPath}`,
    `member-media/${avatarPath}`,
    `member-media/${receiptPath}`,
  ]);
});

Deno.test("private Storage verifies a streaming immutable upload", async () => {
  const bytes = new Uint8Array([1, 2, 3]);
  const checksum = createHash("sha256").update(bytes).digest("hex");
  let uploaded = new Uint8Array();
  const storage = createPrivateSupabaseStorage({
    supabaseUrl: "https://project.supabase.co",
    secretKey: "sb_secret_stream-test",
    async fetch(_input, init) {
      const body = (init as globalThis.RequestInit | undefined)?.body;
      if (!(body instanceof ReadableStream)) {
        throw new Error("storage_upload_not_streaming");
      }
      uploaded = new Uint8Array(await new Response(body).arrayBuffer());
      return new Response(null, { status: 201 });
    },
  });
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes.subarray(0, 1));
      controller.enqueue(bytes.subarray(1));
      controller.close();
    },
  });
  assertEquals(
    await storage.putImmutable(
      "privacy-exports",
      `${userId}/exports/${generationId}.zip`,
      body,
      "application/zip",
      checksum,
      bytes.byteLength,
    ),
    "created",
  );
  assertEquals(uploaded, bytes);
});
