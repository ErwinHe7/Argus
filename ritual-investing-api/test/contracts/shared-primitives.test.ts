import { describe, expect, it } from "vitest";

import { parsePagePosition } from "../../src/contracts/page-position.ts";
import { sha256TextHex } from "../../src/security/sha256.ts";

describe("shared contract primitives", () => {
  it("preserves the lowercase SHA-256 text representation", async () => {
    await expect(sha256TextHex("abc")).resolves.toBe(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  });

  it("preserves page-position parsing and validation", () => {
    expect(parsePagePosition(undefined)).toEqual([null, null]);
    expect(parsePagePosition("2026-08-24T00:00:00.000Z|record-id")).toEqual([
      "2026-08-24T00:00:00.000Z",
      "record-id",
    ]);
    expect(() => parsePagePosition("missing-separator")).toThrow(
      "invalid_cursor_position",
    );
  });
});
