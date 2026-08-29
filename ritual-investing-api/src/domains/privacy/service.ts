import type { DatabaseTransaction } from "../../db/database-port.ts";
import type { VerifiedRequestClaims } from "../../db/request-claims.ts";
import { RepositoryStepUpRequiredError } from "../../db/repository-errors.ts";
import { sha256TextHex as sha256 } from "../../security/sha256.ts";

const maxSignedUrlLength = 4_096;

function requireSafeSignedUrl(value: string): string {
  if (
    value.length === 0 ||
    value.length > maxSignedUrlLength ||
    value.trim() !== value
  ) {
    throw new Error("storage_unavailable");
  }
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error("storage_unavailable");
  }
  if (
    parsed.protocol !== "https:" ||
    parsed.username.length !== 0 ||
    parsed.password.length !== 0 ||
    parsed.href.length === 0 ||
    parsed.href.length > maxSignedUrlLength
  ) {
    throw new Error("storage_unavailable");
  }
  return value;
}

export type PrivacyRequestRepository = Readonly<{
  list(): Promise<unknown[]>;
  requestExport(scopedDedupeKey: string): Promise<unknown>;
  requestDeletion(
    receiptHash: string,
    sessionId: string,
    dedupeKey: string,
  ): Promise<unknown>;
  getDeletionTombstone(): Promise<unknown>;
  prepareDownload(requestId: string): Promise<
    Readonly<{
      access_lease_id: string;
      bucket_id: string;
      object_path: string;
      expires_in_seconds: number;
    }>
  >;
  confirmDownload(accessLeaseId: string): Promise<void>;
}>;

export type PrivacySignedStorage = Readonly<{
  createSignedUrl(
    bucket: string,
    path: string,
    expiresInSeconds: number,
  ): Promise<string>;
}>;

export type PrivacyRequestService = Readonly<{
  list(): Promise<unknown[]>;
  request(
    requestType: "export" | "deletion",
    dedupeKey: string,
    stepUpReceipt?: string,
  ): Promise<unknown>;
  getDeletionTombstone(): Promise<unknown>;
  createDownloadUrl(requestId: string): Promise<
    Readonly<{
      url: string;
      expires_at: string;
    }>
  >;
}>;

export type CreatePrivacyRequestServiceInput = Readonly<{
  claims: VerifiedRequestClaims;
  withMemberTransaction<T>(
    callback: (database: DatabaseTransaction) => Promise<T>,
  ): Promise<T>;
  repository(database: DatabaseTransaction): PrivacyRequestRepository;
  signedStorage: PrivacySignedStorage;
  now?: () => number;
}>;

/**
 * Composes the privacy request and signed-download saga. Database checkpoints
 * are short and committed before Storage I/O; the external port never receives
 * a transaction-bound database handle.
 */
export function createPrivacyRequestService(
  input: CreatePrivacyRequestServiceInput,
): PrivacyRequestService {
  const withRepository = <T>(
    callback: (repository: PrivacyRequestRepository) => Promise<T>,
  ) =>
    input.withMemberTransaction((database) =>
      callback(input.repository(database))
    );

  return Object.freeze({
    list: () => withRepository((repository) => repository.list()),
    request: async (
      requestType: "export" | "deletion",
      dedupeKey: string,
      stepUpReceipt?: string,
    ) => {
      if (requestType === "deletion") {
        if (stepUpReceipt === undefined) {
          throw new RepositoryStepUpRequiredError();
        }
        const receiptHash = await sha256(stepUpReceipt);
        return withRepository((repository) =>
          repository.requestDeletion(
            receiptHash,
            input.claims.sessionId,
            dedupeKey,
          )
        );
      }
      const scopedDedupeKey = `privacy-export:${await sha256(
        `${input.claims.userId}\u0000${dedupeKey}`,
      )}`;
      return withRepository((repository) =>
        repository.requestExport(scopedDedupeKey)
      );
    },
    getDeletionTombstone: () =>
      withRepository((repository) => repository.getDeletionTombstone()),
    createDownloadUrl: async (requestId: string) => {
      const artifact = await withRepository((repository) =>
        repository.prepareDownload(requestId)
      );
      if (
        !Number.isInteger(artifact.expires_in_seconds) ||
        artifact.expires_in_seconds < 1 ||
        artifact.expires_in_seconds > 30
      ) {
        throw new Error("storage_unavailable");
      }
      const issuedAt = (input.now ?? Date.now)();
      const url = requireSafeSignedUrl(
        await input.signedStorage.createSignedUrl(
          artifact.bucket_id,
          artifact.object_path,
          artifact.expires_in_seconds,
        ),
      );
      await withRepository((repository) =>
        repository.confirmDownload(artifact.access_lease_id)
      );
      return {
        url,
        expires_at: new Date(
          issuedAt + artifact.expires_in_seconds * 1_000,
        ).toISOString(),
      };
    },
  });
}

const secretKeyPattern =
  /(?:auth0.?subject|ciphertext|idempotency|password|provider.body|push.token|raw.token|request.?hash|secret)/i;

function safeExportValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(safeExportValue);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([key]) => !secretKeyPattern.test(key.replaceAll("_", ".")))
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, safeExportValue(child)]),
    );
  }
  return value;
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${
      Object.entries(value as Record<string, unknown>)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => `${JSON.stringify(key)}:${stableJson(child)}`)
        .join(",")
    }}`;
  }
  return JSON.stringify(value);
}

export type ExportManifestInput = {
  tenantId: string;
  requestId: string;
  snapshotAt: string;
  sourceSequence: number;
  rows: Record<string, unknown[]>;
};

export async function buildExportManifest(input: ExportManifestInput) {
  const data = safeExportValue(input.rows) as Record<string, unknown[]>;
  const contentChecksum = await sha256(stableJson(data));
  return {
    schema_version: 1 as const,
    tenant_id: input.tenantId,
    request_id: input.requestId,
    snapshot_at: input.snapshotAt,
    source_sequence: input.sourceSequence,
    content_checksum: contentChecksum,
    data,
  };
}

export type DeletionDenyInput = {
  tombstoneId: string;
  tenantId: string;
  subjectHash: string;
  effectiveAt: string;
  purgeGeneration: number;
};

export async function buildDeletionDenyEntry(input: DeletionDenyInput) {
  const payload = {
    schema_version: 1 as const,
    tombstone_id: input.tombstoneId,
    tenant_id: input.tenantId,
    subject_hash: input.subjectHash,
    effective_at: input.effectiveAt,
    purge_generation: input.purgeGeneration,
  };
  const body = stableJson(payload);
  const checksum = await sha256(body);
  return {
    key: `deletion-deny/v1/${input.tombstoneId}/${input.purgeGeneration}.json`,
    body,
    checksum,
  };
}

export async function verifyDeletionDenyEntry(
  body: string,
  expectedChecksum: string,
): Promise<boolean> {
  return (
    /^[a-f0-9]{64}$/.test(expectedChecksum) &&
    (await sha256(body)) === expectedChecksum
  );
}

function crc32(bytes: Uint8Array): number {
  return (updateCrc32(0xffffffff, bytes) ^ 0xffffffff) >>> 0;
}

function littleEndian(values: Array<[number, number]>): Uint8Array {
  const size = values.reduce((total, [, width]) => total + width, 0);
  const result = new Uint8Array(size);
  const view = new DataView(result.buffer);
  let offset = 0;
  for (const [value, width] of values) {
    if (width === 2) view.setUint16(offset, value, true);
    else view.setUint32(offset, value, true);
    offset += width;
  }
  return result;
}

export type StreamingExportCollection = {
  name: string;
  readPage: (offset: number, limit: number) => Promise<unknown[]>;
};

export type StreamingPrivacyArchiveFile = Readonly<{
  name: string;
  contentChecksum: string;
  open: () => Promise<ReadableStream<Uint8Array>>;
}>;

export type StreamingPrivacyArchiveInput =
  & Omit<
    ExportManifestInput,
    "rows"
  >
  & {
    sealedManifestChecksum: string;
    collections: readonly StreamingExportCollection[];
    files?: readonly StreamingPrivacyArchiveFile[];
    pageSize?: number;
  };

type StreamingPrivacyArchiveResult = {
  body: ReadableStream<Uint8Array>;
  completion: Promise<{
    manifest: Record<string, unknown>;
    manifestChecksum: string;
  }>;
};

function updateCrc32(state: number, bytes: Uint8Array): number {
  let crc = state;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return crc;
}

function zipLocalHeader(
  nameLength: number,
  flags: number,
  checksum = 0,
  size = 0,
): Uint8Array {
  return littleEndian([
    [0x04034b50, 4],
    [20, 2],
    [flags, 2],
    [0, 2],
    [0, 2],
    [0, 2],
    [checksum, 4],
    [size, 4],
    [size, 4],
    [nameLength, 2],
    [0, 2],
  ]);
}

function zipCentralHeader(
  nameLength: number,
  flags: number,
  checksum: number,
  size: number,
  offset: number,
): Uint8Array {
  return littleEndian([
    [0x02014b50, 4],
    [20, 2],
    [20, 2],
    [flags, 2],
    [0, 2],
    [0, 2],
    [0, 2],
    [checksum, 4],
    [size, 4],
    [size, 4],
    [nameLength, 2],
    [0, 2],
    [0, 2],
    [0, 2],
    [0, 2],
    [0, 4],
    [offset, 4],
  ]);
}

/**
 * Produces a valid stored ZIP while retaining only one bounded database page,
 * one file chunk, and compact central-directory metadata. `completion`
 * resolves after the stream has observed every row and finalized the
 * deterministic manifest checksum.
 */
export function buildStreamingPrivacyZip(
  input: StreamingPrivacyArchiveInput,
): StreamingPrivacyArchiveResult {
  if (!/^[a-f0-9]{64}$/.test(input.sealedManifestChecksum)) {
    throw new Error("invalid_privacy_export_seal");
  }
  const pageSize = input.pageSize ?? 100;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 500) {
    throw new Error("invalid_privacy_export_page_size");
  }
  const files = [...(input.files ?? [])].sort((left, right) =>
    left.name < right.name ? -1 : left.name > right.name ? 1 : 0
  );
  const archiveNamePattern = /^[A-Za-z0-9._/-]{1,1024}$/;
  for (const [index, file] of files.entries()) {
    if (
      !archiveNamePattern.test(file.name) || file.name.startsWith("/") ||
      file.name.split("/").includes("..") ||
      !/^[a-f0-9]{64}$/.test(file.contentChecksum) ||
      (index > 0 && files[index - 1]?.name === file.name)
    ) {
      throw new Error("invalid_privacy_export_file");
    }
  }
  if (files.length + 2 > 0xffff) {
    throw new Error("privacy_export_archive_too_large");
  }
  let resolveCompletion!: (value: {
    manifest: Record<string, unknown>;
    manifestChecksum: string;
  }) => void;
  let rejectCompletion!: (reason: unknown) => void;
  const completion = new Promise<{
    manifest: Record<string, unknown>;
    manifestChecksum: string;
  }>((resolve, reject) => {
    resolveCompletion = resolve;
    rejectCompletion = reject;
  });
  void completion.catch(() => undefined);
  const encoder = new TextEncoder();
  const iterator = (async function* () {
    const centralEntries: Array<
      Readonly<{
        name: Uint8Array;
        flags: number;
        checksum: number;
        size: number;
        offset: number;
      }>
    > = [];
    let archiveOffset = 0;
    const dataName = encoder.encode("data.ndjson");
    const dataHeader = zipLocalHeader(dataName.length, 0x08);
    yield dataHeader;
    yield dataName;
    let dataCrcState = 0xffffffff;
    let dataSize = 0;
    let rollingChecksum = await sha256("ritual-privacy-export:v2");
    const collectionCounts: Record<string, number> = {};
    for (const collection of input.collections) {
      let offset = 0;
      let pageNumber = 0;
      for (;;) {
        const page = await collection.readPage(offset, pageSize);
        if (page.length > pageSize) {
          throw new Error("privacy_export_page_exceeded_bound");
        }
        if (page.length === 0) break;
        const safeRows = safeExportValue(page) as unknown[];
        const chunkText = safeRows
          .map((row) => stableJson({ collection: collection.name, row }))
          .join("\n") + "\n";
        const chunk = encoder.encode(chunkText);
        dataSize += chunk.length;
        if (dataSize > 0xffffffff) {
          throw new Error("privacy_export_archive_too_large");
        }
        dataCrcState = updateCrc32(dataCrcState, chunk);
        rollingChecksum = await sha256(
          `${rollingChecksum}:${collection.name}:${pageNumber}:${await sha256(
            chunkText,
          )}`,
        );
        yield chunk;
        offset += page.length;
        pageNumber += 1;
        if (page.length < pageSize) break;
      }
      collectionCounts[collection.name] = offset;
    }
    const dataChecksum = (dataCrcState ^ 0xffffffff) >>> 0;
    yield littleEndian([
      [0x08074b50, 4],
      [dataChecksum, 4],
      [dataSize, 4],
      [dataSize, 4],
    ]);
    centralEntries.push({
      name: dataName,
      flags: 0x08,
      checksum: dataChecksum,
      size: dataSize,
      offset: 0,
    });
    archiveOffset = dataHeader.length + dataName.length + dataSize + 16;

    const archivedFiles: Array<
      Readonly<{
        archive_path: string;
        content_checksum: string;
        byte_length: number;
      }>
    > = [];
    for (const file of files) {
      const name = encoder.encode(file.name);
      const header = zipLocalHeader(name.length, 0x08);
      const fileOffset = archiveOffset;
      yield header;
      yield name;
      let checksumState = 0xffffffff;
      let size = 0;
      const reader = (await file.open()).getReader();
      let complete = false;
      try {
        for (;;) {
          const next = await reader.read();
          if (next.done) {
            complete = true;
            break;
          }
          if (size > 0xffffffff - next.value.byteLength) {
            throw new Error("privacy_export_archive_too_large");
          }
          size += next.value.byteLength;
          checksumState = updateCrc32(checksumState, next.value);
          yield next.value;
        }
      } finally {
        if (!complete) await reader.cancel("privacy_export_archive_cancelled");
        reader.releaseLock();
      }
      const checksum = (checksumState ^ 0xffffffff) >>> 0;
      yield littleEndian([
        [0x08074b50, 4],
        [checksum, 4],
        [size, 4],
        [size, 4],
      ]);
      centralEntries.push({
        name,
        flags: 0x08,
        checksum,
        size,
        offset: fileOffset,
      });
      archiveOffset += header.length + name.length + size + 16;
      if (archiveOffset > 0xffffffff) {
        throw new Error("privacy_export_archive_too_large");
      }
      archivedFiles.push({
        archive_path: file.name,
        content_checksum: file.contentChecksum,
        byte_length: size,
      });
    }

    const manifest = {
      schema_version: 2 as const,
      archive_format: "ritual-privacy-export",
      tenant_id: input.tenantId,
      request_id: input.requestId,
      snapshot_at: input.snapshotAt,
      source_sequence: input.sourceSequence,
      sealed_manifest_checksum: input.sealedManifestChecksum,
      checksum_algorithm: "sha256-page-chain-v1",
      content_checksum: rollingChecksum,
      collections: collectionCounts,
      files: archivedFiles,
    };
    const manifestBody = encoder.encode(stableJson(manifest));
    const manifestChecksum = await sha256(stableJson(manifest));
    resolveCompletion({ manifest, manifestChecksum });
    const manifestName = encoder.encode("manifest.json");
    const manifestCrc = crc32(manifestBody);
    const manifestOffset = archiveOffset;
    const manifestHeader = zipLocalHeader(
      manifestName.length,
      0,
      manifestCrc,
      manifestBody.length,
    );
    yield manifestHeader;
    yield manifestName;
    yield manifestBody;
    centralEntries.push({
      name: manifestName,
      flags: 0,
      checksum: manifestCrc,
      size: manifestBody.length,
      offset: manifestOffset,
    });
    const centralOffset = manifestOffset +
      manifestHeader.length +
      manifestName.length +
      manifestBody.length;
    const centralSize = centralEntries.reduce(
      (size, entry) => size + 46 + entry.name.length,
      0,
    );
    if (centralOffset > 0xffffffff || centralSize > 0xffffffff) {
      throw new Error("privacy_export_archive_too_large");
    }
    for (const entry of centralEntries) {
      yield zipCentralHeader(
        entry.name.length,
        entry.flags,
        entry.checksum,
        entry.size,
        entry.offset,
      );
      yield entry.name;
    }
    const entryCount = centralEntries.length;
    yield littleEndian([
      [0x06054b50, 4],
      [0, 2],
      [0, 2],
      [entryCount, 2],
      [entryCount, 2],
      [centralSize, 4],
      [centralOffset, 4],
      [0, 2],
    ]);
  })();
  const body = new ReadableStream<Uint8Array>({
    async pull(controller) {
      try {
        const next = await iterator.next();
        if (next.done) controller.close();
        else controller.enqueue(next.value);
      } catch (error) {
        rejectCompletion(error);
        controller.error(error);
      }
    },
    async cancel(reason) {
      rejectCompletion(reason);
      await iterator.return?.();
    },
  });
  return { body, completion };
}
