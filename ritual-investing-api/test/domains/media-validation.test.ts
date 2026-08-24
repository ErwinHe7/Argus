import { describe, expect, it } from "vitest";

import { validateQuarantinedMedia } from "../../src/domains/media/service";

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
});
