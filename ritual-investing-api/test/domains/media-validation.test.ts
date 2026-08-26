import { describe, expect, it } from "vitest";

import {
  inspectQuarantinedObject,
  validateQuarantinedMedia,
} from "../../src/domains/media/service";

const cleanPng = {
  declaredMime: "image/png",
  detectedMime: "image/png",
  extension: "png",
  byteSize: 256_000,
  checksum: "a".repeat(64),
  expectedChecksum: "a".repeat(64),
  width: 1024,
  height: 1024,
  decodedBytes: 4_194_304,
  scanResult: "clean" as const,
  polyglot: false,
  activeContent: false,
  actorId: "018f3c2a-4b67-7a89-8abc-123456789010",
  intendedActorId: "018f3c2a-4b67-7a89-8abc-123456789010",
  uploadIntentId: "018f3c2a-4b67-7a89-8abc-123456789011",
  expectedUploadIntentId: "018f3c2a-4b67-7a89-8abc-123456789011",
};

describe("R2 media quarantine completion", () => {
  it("accepts a bounded clean raster matching the single-use actor intent", () => {
    expect(validateQuarantinedMedia(cleanPng)).toEqual({ ok: true });
  });

  it.each([
    ["mime_mismatch", { detectedMime: "image/jpeg" }],
    ["extension_mismatch", { extension: "jpg" }],
    ["checksum_mismatch", { checksum: "b".repeat(64) }],
    ["file_too_large", { byteSize: 10 * 1024 * 1024 + 1 }],
    ["pixel_limit", { width: 10_001 }],
    ["decompression_limit", { decodedBytes: 65 * 1024 * 1024 }],
    ["active_content", { activeContent: true }],
    ["polyglot", { polyglot: true }],
    ["unsupported_type", { detectedMime: "image/svg+xml" }],
    ["unsupported_type", { detectedMime: "text/html" }],
    ["malware", { scanResult: "malicious" }],
    ["foreign_actor", { actorId: "018f3c2a-4b67-7a89-8abc-123456789099" }],
    [
      "foreign_intent",
      { uploadIntentId: "018f3c2a-4b67-7a89-8abc-123456789099" },
    ],
  ])("rejects %s before quarantine can attach", (code, override) => {
    expect(validateQuarantinedMedia({ ...cleanPng, ...override })).toEqual({
      ok: false,
      code,
    });
  });

  it.each([
    ["VP8X", 640, 480],
    ["VP8 ", 641, 481],
    ["VP8L", 642, 482],
  ])("reads %s WebP dimensions", async (chunk, width, height) => {
    const bytes = webpHeader(chunk, width, height);
    const expectedChecksum = [
      ...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
    ]
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
    const result = await inspectQuarantinedObject(bytes, {
      declaredMime: "image/webp",
      expectedChecksum,
      scanResult: "clean",
      actorId: cleanPng.actorId,
      intendedActorId: cleanPng.intendedActorId,
      uploadIntentId: cleanPng.uploadIntentId,
      expectedUploadIntentId: cleanPng.expectedUploadIntentId,
    });
    expect(result.validation).toEqual({ ok: true });
    expect({ width: result.width, height: result.height }).toEqual({
      width,
      height,
    });
  });
});

function webpHeader(chunk: string, width: number, height: number): Uint8Array {
  const bytes = new Uint8Array(30);
  bytes.set(new TextEncoder().encode("RIFF"), 0);
  bytes.set(new TextEncoder().encode("WEBP"), 8);
  bytes.set(new TextEncoder().encode(chunk), 12);
  const view = new DataView(bytes.buffer);
  if (chunk === "VP8X") {
    const encodedWidth = width - 1;
    const encodedHeight = height - 1;
    bytes.set(
      [encodedWidth, encodedWidth >>> 8, encodedWidth >>> 16],
      24,
    );
    bytes.set(
      [encodedHeight, encodedHeight >>> 8, encodedHeight >>> 16],
      27,
    );
  } else if (chunk === "VP8 ") {
    bytes.set([0x9d, 0x01, 0x2a], 23);
    view.setUint16(26, width, true);
    view.setUint16(28, height, true);
  } else {
    bytes[20] = 0x2f;
    view.setUint32(21, (width - 1) | ((height - 1) << 14), true);
  }
  return bytes;
}
