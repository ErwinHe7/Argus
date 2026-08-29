import { describe, expect, it } from "vitest";

import {
  decodeOpaqueCursor,
  encodeOpaqueCursor,
} from "../../src/contracts/opaque-cursor.ts";

const binding = {
  resource: "notifications",
  scope: "member-inbox",
  verifiedSubject: "member-018f3c2a",
  filterIdentity: "unread=true&types=mention,reply",
  pageSize: 25,
} as const;

function encodeRawCursor(value: unknown): string {
  const text = typeof value === "string" ? value : JSON.stringify(value);
  const bytes = new TextEncoder().encode(text);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

const validEnvelope = {
  v: 1,
  r: binding.resource,
  b: "a".repeat(64),
  n: binding.pageSize,
  p: ["2026-08-29T12:00:00.000Z", "notification-42"],
};
const { p: _position, ...missingPositionEnvelope } = validEnvelope;

describe("opaque cursor envelopes", () => {
  it("deterministically round-trips without exposing binding inputs", async () => {
    const input = {
      ...binding,
      position: ["2026-08-29T12:00:00.000Z", "notification-42"] as const,
    };

    const first = await encodeOpaqueCursor(input);
    const second = await encodeOpaqueCursor(input);

    expect(first).toBe(second);
    expect(first).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(atob(first.replaceAll("-", "+").replaceAll("_", "/")))
      .not.toContain(binding.verifiedSubject);
    expect(atob(first.replaceAll("-", "+").replaceAll("_", "/")))
      .not.toContain(binding.filterIdentity);
    await expect(decodeOpaqueCursor(first, binding)).resolves.toEqual(
      input.position,
    );
  });

  it.each(
    [
      ["resource", { resource: "briefings" }],
      ["scope", { scope: "staff-feed" }],
      ["verified subject", { verifiedSubject: "member-other" }],
      ["filter identity", { filterIdentity: "unread=false" }],
      ["page size", { pageSize: 50 }],
    ] as const,
  )("rejects cross-%s cursor reuse", async (_label, changedBinding) => {
    const cursor = await encodeOpaqueCursor({
      ...binding,
      position: ["2026-08-29T12:00:00.000Z", "notification-42"],
    });

    await expect(
      decodeOpaqueCursor(cursor, { ...binding, ...changedBinding }),
    ).rejects.toThrow("invalid_cursor");
  });

  it.each([
    ["malformed base64url", "not*base64url"],
    ["malformed UTF-8", "_w"],
    ["malformed JSON", encodeRawCursor("not-json")],
    ["non-object JSON", encodeRawCursor([])],
    ["stale version", encodeRawCursor({ ...validEnvelope, v: 0 })],
    ["unknown version", encodeRawCursor({ ...validEnvelope, v: 2 })],
    ["missing field", encodeRawCursor(missingPositionEnvelope)],
    ["extra field", encodeRawCursor({ ...validEnvelope, extra: true })],
    [
      "invalid position",
      encodeRawCursor({ ...validEnvelope, p: { id: "42" } }),
    ],
  ])("rejects %s", async (_label, cursor) => {
    await expect(decodeOpaqueCursor(cursor, binding)).rejects.toThrow(
      "invalid_cursor",
    );
  });

  it("rejects oversized envelope values before emitting or decoding a cursor", async () => {
    const position = ["2026-08-29T12:00:00.000Z", "notification-42"] as const;

    await expect(
      encodeOpaqueCursor({ ...binding, resource: "r".repeat(129), position }),
    ).rejects.toThrow("invalid_cursor");
    await expect(
      encodeOpaqueCursor({ ...binding, scope: "s".repeat(129), position }),
    ).rejects.toThrow("invalid_cursor");
    await expect(
      encodeOpaqueCursor({
        ...binding,
        verifiedSubject: "u".repeat(257),
        position,
      }),
    ).rejects.toThrow("invalid_cursor");
    await expect(
      encodeOpaqueCursor({
        ...binding,
        filterIdentity: "f".repeat(513),
        position,
      }),
    ).rejects.toThrow("invalid_cursor");
    await expect(
      encodeOpaqueCursor({ ...binding, pageSize: 1_001, position }),
    ).rejects.toThrow("invalid_cursor");
    await expect(
      encodeOpaqueCursor({ ...binding, position: ["p".repeat(513)] }),
    ).rejects.toThrow("invalid_cursor");
    await expect(
      encodeOpaqueCursor({
        ...binding,
        position: Array.from({ length: 8 }, () => "p".repeat(512)),
      }),
    ).rejects.toThrow("invalid_cursor");
    await expect(decodeOpaqueCursor("a".repeat(2_049), binding)).rejects
      .toThrow(
        "invalid_cursor",
      );
  });
});
