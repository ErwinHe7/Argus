import { describe, expect, it } from "vitest";

import {
  cursorFilterIdentity,
  keysetPage,
  keysetPosition,
} from "../../src/domains/content/pagination.ts";

const request = {
  resource: "briefings",
  scope: "member",
  verifiedSubject: "018f3c2a-4b67-7a89-8abc-123456789001",
  filterIdentity: cursorFilterIdentity({
    period_end: "2026-08-29",
    type: "daily",
  }),
  pageSize: 2,
} as const;

describe("keyset page composition", () => {
  it("uses the unique tie-breaker of the last returned row", async () => {
    const page = await keysetPage(
      request,
      [
        { period_end: "2026-08-29", id: "c" },
        { period_end: "2026-08-29", id: "b" },
        { period_end: "2026-08-29", id: "a" },
      ],
      (item) => [item.period_end, item.id],
    );

    expect(page.items.map((item) => item.id)).toEqual(["c", "b"]);
    expect(page.nextCursor).not.toBeNull();
    await expect(
      keysetPosition({ ...request, cursor: page.nextCursor! }),
    ).resolves.toEqual(["2026-08-29", "b"]);
  });

  it("returns no cursor when the repository did not overfetch", async () => {
    const page = await keysetPage(
      request,
      [{ period_end: "2026-08-29", id: "c" }],
      (item) => [item.period_end, item.id],
    );
    expect(page).toMatchObject({ nextCursor: null });
  });

  it("rejects repository results that exceed the one-row overfetch contract", async () => {
    await expect(keysetPage(
      request,
      [
        { period_end: "2026-08-29", id: "d" },
        { period_end: "2026-08-29", id: "c" },
        { period_end: "2026-08-29", id: "b" },
        { period_end: "2026-08-29", id: "a" },
      ],
      (item) => [item.period_end, item.id],
    )).rejects.toThrow("keyset_page_overfetch_exceeded");
  });

  it("rejects a cursor when any filter binding changes", async () => {
    const page = await keysetPage(
      request,
      [
        { period_end: "2026-08-29", id: "c" },
        { period_end: "2026-08-29", id: "b" },
        { period_end: "2026-08-29", id: "a" },
      ],
      (item) => [item.period_end, item.id],
    );

    await expect(keysetPosition({
      ...request,
      filterIdentity: cursorFilterIdentity({
        period_end: "2026-08-29",
        type: "weekly",
      }),
      cursor: page.nextCursor!,
    })).rejects.toMatchObject({ status: 422, code: "invalid_cursor" });
  });

  it("canonicalizes filter identity independently of object insertion order", () => {
    expect(cursorFilterIdentity({ type: "daily", period_end: null })).toBe(
      cursorFilterIdentity({ period_end: null, type: "daily" }),
    );
  });
});
