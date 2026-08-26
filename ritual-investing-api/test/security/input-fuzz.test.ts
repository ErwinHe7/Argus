import { describe, expect, it } from "vitest";

import {
  catalogListQuerySchema,
  createEvidenceSourceSchema,
} from "../../src/domains/admin/catalog/schemas";
import {
  safeMarkdownSchema,
  safeReasonSchema,
} from "../../src/domains/admin/editorial-workflow/schemas";
import { mediaUploadRequestSchema } from "../../src/domains/media/schemas";
import {
  inputMoneySchema,
  quantitySchema,
} from "../../src/domains/simulation/schemas";
import { searchQuerySchema } from "../../src/domains/search/schemas";
import { profilePatchSchema } from "../../src/domains/accounts/schemas";
import { circleCreateSchema } from "../../src/domains/circles/schemas";
import { decodeCursor, encodeCursor } from "../../src/domains/editorial/cursor";

describe("structured hostile input corpus", () => {
  it.each([
    ["oversized", "x".repeat(8_001)],
    ["active HTML", "safe <script>alert(1)</script>"],
    ["javascript Markdown", "[open](javascript:alert(1))"],
    ["Unicode bidi control", "approved\u202Egpj.exe"],
    ["C0 control", "approved\u0007hidden"],
  ])("rejects %s text", (_case, value) => {
    expect(safeMarkdownSchema.safeParse(value).success).toBe(false);
  });

  it("rejects unsafe URLs, unknown fields, and upload boundary abuse", () => {
    expect(
      createEvidenceSourceSchema.safeParse({
        canonical_url: "http://example.com/source",
        title: "Source",
        publisher: "Publisher",
        published_at: null,
        retrieved_at: "2026-08-24T12:00:00.000Z",
        source_kind: "research",
        status: "active",
      }).success,
    ).toBe(false);
    expect(safeReasonSchema.safeParse("ok\u0000secret").success).toBe(false);
    expect(
      mediaUploadRequestSchema.safeParse({
        mime_type: "image/svg+xml",
        byte_size: 1_000_000_000,
        checksum: "not-a-checksum",
        tenant_id: "00000000-0000-4000-8000-000000000001",
      }).success,
    ).toBe(false);
  });

  it.each(["member\u202Ename", "member\u0007name"])(
    "applies the shared control policy to member text %s",
    (value) => {
      expect(
        profilePatchSchema.safeParse({ display_name: value }).success,
      ).toBe(false);
      expect(
        circleCreateSchema.safeParse({ title: value, description: value })
          .success,
      ).toBe(false);
      expect(
        searchQuerySchema.safeParse({ q: value, kinds: "asset", limit: 20 })
          .success,
      ).toBe(false);
    },
  );

  it.each([
    [{ minor_units: -1, currency: "USD" }],
    [{ minor_units: 1.2, currency: "USD" }],
    [{ minor_units: 1_000_000_001, currency: "USD" }],
  ])("rejects decimal money edge %#", (value) => {
    expect(inputMoneySchema.safeParse(value).success).toBe(false);
  });

  it.each(["1e3", "01", "0", "1.0000000000001", "1000000001"])(
    "rejects unsafe quantity %s",
    (value) => {
      expect(quantitySchema.safeParse({ value, scale: 12 }).success).toBe(
        false,
      );
    },
  );

  it("rejects cursor and sort/search injection", async () => {
    const secret = "u9-cursor-secret-with-at-least-32-bytes";
    const cursor = await encodeCursor(secret, "scope", "next-row");
    await expect(
      decodeCursor(secret, "scope", `${cursor.slice(0, -1)}x`),
    ).rejects.toThrow();
    expect(
      catalogListQuerySchema.safeParse({
        limit: 20,
        sort: "created_at desc; drop table accounts",
      }).success,
    ).toBe(false);
    expect(
      searchQuerySchema.safeParse({ q: "tenant_id", kinds: "asset", limit: 20 })
        .success,
    ).toBe(false);
  });
});
