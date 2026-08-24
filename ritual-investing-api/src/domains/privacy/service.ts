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
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1)
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
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

export function buildPrivacyZip(manifest: Record<string, unknown>): Uint8Array {
  const files = [
    [
      "manifest.json",
      JSON.stringify({
        schema_version: 1,
        archive_format: "ritual-privacy-export",
        manifest,
      }),
    ],
    ["data.json", JSON.stringify(manifest.data ?? {})],
  ] as const;
  const locals: Uint8Array[] = [];
  const central: Uint8Array[] = [];
  let offset = 0;
  for (const [name, content] of files) {
    const nameBytes = new TextEncoder().encode(name);
    const contentBytes = new TextEncoder().encode(content);
    const checksum = crc32(contentBytes);
    const localHeader = littleEndian([
      [0x04034b50, 4],
      [20, 2],
      [0, 2],
      [0, 2],
      [0, 2],
      [0, 2],
      [checksum, 4],
      [contentBytes.length, 4],
      [contentBytes.length, 4],
      [nameBytes.length, 2],
      [0, 2],
    ]);
    locals.push(localHeader, nameBytes, contentBytes);
    const centralHeader = littleEndian([
      [0x02014b50, 4],
      [20, 2],
      [20, 2],
      [0, 2],
      [0, 2],
      [0, 2],
      [0, 2],
      [checksum, 4],
      [contentBytes.length, 4],
      [contentBytes.length, 4],
      [nameBytes.length, 2],
      [0, 2],
      [0, 2],
      [0, 2],
      [0, 2],
      [0, 4],
      [offset, 4],
    ]);
    central.push(centralHeader, nameBytes);
    offset += localHeader.length + nameBytes.length + contentBytes.length;
  }
  const centralBytes = concatenate(central);
  const end = littleEndian([
    [0x06054b50, 4],
    [0, 2],
    [0, 2],
    [files.length, 2],
    [files.length, 2],
    [centralBytes.length, 4],
    [offset, 4],
    [0, 2],
  ]);
  return concatenate([...locals, centralBytes, end]);
}
