import { describe, expect, it, vi } from "vitest";

import { createPostgresAdminModerationRepository } from "../../src/domains/moderation/repository";

const staffId = "018f3c2a-4b67-7a89-8abc-123456789010";
const caseId = "018f3c2a-4b67-7a89-8abc-123456789011";

function poolReturning(value: unknown) {
  const query = vi.fn(async (sql: string) => ({
    rows: sql.includes("::jsonb value") ? [{ value }] : [],
  }));
  return {
    factory: () => ({
      connect: async () => ({
        query,
        release: vi.fn(),
      }),
      end: vi.fn(),
    }),
    query,
  };
}

describe("Postgres moderation response boundary", () => {
  it("rejects malformed JSON returned by the database command", async () => {
    const pool = poolReturning({ id: caseId, etag: '"v1"' });
    const repository = createPostgresAdminModerationRepository(
      "postgres://test.invalid/ritual",
      pool.factory as never,
    );

    await expect(
      repository.patchCase({
        actorStaffId: staffId,
        caseId,
        payload: {
          status: "resolved",
          resolution_code: "reviewed",
          reason: "Independent review completed.",
        },
        expectedVersion: 1,
        requestId: "018f3c2a-4b67-7a89-8abc-123456789012",
      }),
    ).rejects.toThrow();
  });

  it("rejects malformed moderation reports in a database page", async () => {
    const pool = poolReturning({ items: [{ id: caseId }], next: null });
    const repository = createPostgresAdminModerationRepository(
      "postgres://test.invalid/ritual",
      pool.factory as never,
    );

    await expect(
      repository.list({ actorStaffId: staffId, filters: {}, limit: 20 }),
    ).rejects.toThrow();
  });
});
