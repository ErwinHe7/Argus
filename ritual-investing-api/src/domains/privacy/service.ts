import { sha256TextHex as sha256 } from "../../security/sha256.ts";

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
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => `${JSON.stringify(key)}:${stableJson(child)}`)
      .join(",")}}`;
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

function concatenate(parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(
    parts.reduce((total, part) => total + part.length, 0),
  );
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

export type StreamingExportCollection = {
  name: string;
  readPage: (offset: number, limit: number) => Promise<unknown[]>;
};

export type StreamingPrivacyArchiveInput = Omit<
  ExportManifestInput,
  "rows"
> & {
  collections: readonly StreamingExportCollection[];
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
    for (let bit = 0; bit < 8; bit += 1)
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
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
 * Produces a valid stored ZIP while retaining only one bounded database page
 * and two central-directory records. `completion` resolves after the stream
 * has observed every row and finalized the deterministic manifest checksum.
 */
export function buildStreamingPrivacyZip(
  input: StreamingPrivacyArchiveInput,
): StreamingPrivacyArchiveResult {
  const pageSize = input.pageSize ?? 100;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 500)
    throw new Error("invalid_privacy_export_page_size");
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
        if (page.length > pageSize)
          throw new Error("privacy_export_page_exceeded_bound");
        if (page.length === 0) break;
        const safeRows = safeExportValue(page) as unknown[];
        const chunkText =
          safeRows
            .map((row) => stableJson({ collection: collection.name, row }))
            .join("\n") + "\n";
        const chunk = encoder.encode(chunkText);
        dataSize += chunk.length;
        if (dataSize > 0xffffffff)
          throw new Error("privacy_export_archive_too_large");
        dataCrcState = updateCrc32(dataCrcState, chunk);
        rollingChecksum = await sha256(
          `${rollingChecksum}:${collection.name}:${pageNumber}:${await sha256(chunkText)}`,
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

    const manifest = {
      schema_version: 2 as const,
      archive_format: "ritual-privacy-export",
      tenant_id: input.tenantId,
      request_id: input.requestId,
      snapshot_at: input.snapshotAt,
      source_sequence: input.sourceSequence,
      checksum_algorithm: "sha256-page-chain-v1",
      content_checksum: rollingChecksum,
      collections: collectionCounts,
    };
    const manifestBody = encoder.encode(stableJson(manifest));
    const manifestChecksum = await sha256(stableJson(manifest));
    resolveCompletion({ manifest, manifestChecksum });
    const manifestName = encoder.encode("manifest.json");
    const manifestCrc = crc32(manifestBody);
    const manifestOffset =
      dataHeader.length + dataName.length + dataSize + 16;
    const manifestHeader = zipLocalHeader(
      manifestName.length,
      0,
      manifestCrc,
      manifestBody.length,
    );
    yield manifestHeader;
    yield manifestName;
    yield manifestBody;

    const central = concatenate([
      zipCentralHeader(
        dataName.length,
        0x08,
        dataChecksum,
        dataSize,
        0,
      ),
      dataName,
      zipCentralHeader(
        manifestName.length,
        0,
        manifestCrc,
        manifestBody.length,
        manifestOffset,
      ),
      manifestName,
    ]);
    const centralOffset =
      manifestOffset +
      manifestHeader.length +
      manifestName.length +
      manifestBody.length;
    yield central;
    yield littleEndian([
      [0x06054b50, 4],
      [0, 2],
      [0, 2],
      [2, 2],
      [2, 2],
      [central.length, 4],
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
