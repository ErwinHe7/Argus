export type QuarantinedMediaInspection = {
  declaredMime: string;
  detectedMime: string;
  extension: string;
  byteSize: number;
  checksum: string;
  expectedChecksum: string;
  width: number;
  height: number;
  decodedBytes: number;
  scanResult: string;
  polyglot: boolean;
  activeContent: boolean;
  actorId: string;
  intendedActorId: string;
  uploadIntentId: string;
  expectedUploadIntentId: string;
};

export type MediaValidationResult =
  | { ok: true }
  | {
      ok: false;
      code:
        | "active_content"
        | "checksum_mismatch"
        | "decompression_limit"
        | "extension_mismatch"
        | "file_too_large"
        | "foreign_actor"
        | "foreign_intent"
        | "malware"
        | "mime_mismatch"
        | "pixel_limit"
        | "polyglot"
        | "unsupported_type";
    };

const acceptedTypes = {
  "image/jpeg": new Set(["jpg", "jpeg"]),
  "image/png": new Set(["png"]),
  "image/webp": new Set(["webp"]),
} as const;

export function validateQuarantinedMedia(
  inspection: QuarantinedMediaInspection,
): MediaValidationResult {
  const extensions =
    acceptedTypes[inspection.detectedMime as keyof typeof acceptedTypes];
  if (extensions === undefined) return { ok: false, code: "unsupported_type" };
  if (inspection.declaredMime !== inspection.detectedMime)
    return { ok: false, code: "mime_mismatch" };
  if (!extensions.has(inspection.extension.toLowerCase() as never))
    return { ok: false, code: "extension_mismatch" };
  if (inspection.checksum !== inspection.expectedChecksum)
    return { ok: false, code: "checksum_mismatch" };
  if (inspection.byteSize > 10 * 1024 * 1024)
    return { ok: false, code: "file_too_large" };
  if (
    inspection.width < 1 ||
    inspection.height < 1 ||
    inspection.width > 10_000 ||
    inspection.height > 10_000 ||
    inspection.width * inspection.height > 40_000_000
  )
    return { ok: false, code: "pixel_limit" };
  if (inspection.decodedBytes > 64 * 1024 * 1024)
    return { ok: false, code: "decompression_limit" };
  if (inspection.activeContent) return { ok: false, code: "active_content" };
  if (inspection.polyglot) return { ok: false, code: "polyglot" };
  if (inspection.scanResult !== "clean") return { ok: false, code: "malware" };
  if (inspection.actorId !== inspection.intendedActorId)
    return { ok: false, code: "foreign_actor" };
  if (inspection.uploadIntentId !== inspection.expectedUploadIntentId)
    return { ok: false, code: "foreign_intent" };
  return { ok: true };
}

function hex(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function detectedRaster(
  bytes: Uint8Array,
): { mime: string; extension: string } | undefined {
  if (bytes.length >= 24 && hex(bytes.slice(0, 8)) === "89504e470d0a1a0a")
    return { mime: "image/png", extension: "png" };
  if (
    bytes.length >= 4 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes.at(-2) === 0xff &&
    bytes.at(-1) === 0xd9
  )
    return { mime: "image/jpeg", extension: "jpg" };
  if (
    bytes.length >= 30 &&
    new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
    new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP"
  )
    return { mime: "image/webp", extension: "webp" };
  return undefined;
}

function dimensions(
  bytes: Uint8Array,
  mime: string,
): { width: number; height: number } | undefined {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (mime === "image/png" && bytes.length >= 24)
    return { width: view.getUint32(16), height: view.getUint32(20) };
  if (
    mime === "image/webp" &&
    bytes.length >= 30 &&
    new TextDecoder().decode(bytes.slice(12, 16)) === "VP8X"
  )
    return {
      width:
        1 +
        view.getUint8(24) +
        (view.getUint8(25) << 8) +
        (view.getUint8(26) << 16),
      height:
        1 +
        view.getUint8(27) +
        (view.getUint8(28) << 8) +
        (view.getUint8(29) << 16),
    };
  if (mime === "image/jpeg") {
    let cursor = 2;
    while (cursor + 9 < bytes.length) {
      if (bytes[cursor] !== 0xff) {
        cursor += 1;
        continue;
      }
      const marker = bytes[cursor + 1]!;
      const length = view.getUint16(cursor + 2);
      if ([0xc0, 0xc1, 0xc2].includes(marker))
        return {
          height: view.getUint16(cursor + 5),
          width: view.getUint16(cursor + 7),
        };
      if (length < 2) break;
      cursor += 2 + length;
    }
  }
  return undefined;
}

export async function inspectQuarantinedObject(
  bytes: Uint8Array,
  input: Omit<
    QuarantinedMediaInspection,
    | "detectedMime"
    | "extension"
    | "byteSize"
    | "checksum"
    | "width"
    | "height"
    | "decodedBytes"
    | "polyglot"
    | "activeContent"
    | "scanResult"
  > & { scanResult: string },
): Promise<{
  validation: MediaValidationResult;
  width: number;
  height: number;
  checksum: string;
}> {
  const detected = detectedRaster(bytes);
  const size =
    detected === undefined ? undefined : dimensions(bytes, detected.mime);
  const checksum = hex(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
  );
  const textSample = new TextDecoder("utf-8", {
    fatal: false,
    ignoreBOM: false,
  })
    .decode(bytes.slice(0, Math.min(bytes.length, 8192)))
    .toLowerCase();
  const activeContent = /<(?:script|svg|html)|javascript:|onerror\s*=/.test(
    textSample,
  );
  const signatureCount = ["89504e470d0a1a0a", "ffd8ff", "52494646"].filter(
    (signature) => hex(bytes).includes(signature),
  ).length;
  const inspection: QuarantinedMediaInspection = {
    ...input,
    detectedMime: detected?.mime ?? "application/octet-stream",
    extension: detected?.extension ?? "bin",
    byteSize: bytes.byteLength,
    checksum,
    width: size?.width ?? 0,
    height: size?.height ?? 0,
    decodedBytes: (size?.width ?? 0) * (size?.height ?? 0) * 4,
    polyglot: signatureCount > 1,
    activeContent,
  };
  return {
    validation: validateQuarantinedMedia(inspection),
    width: inspection.width,
    height: inspection.height,
    checksum,
  };
}
