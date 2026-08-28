import { describe, expect, it, vi } from "vitest";

import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const briefingId = "018f3c2a-4b67-7a89-8abc-123456789061";
const readAt = "2026-08-28T16:30:00.000Z";
const bindings = {
  environment: "test" as const,
  buildRevision: "u13-test",
  consumerOrigin: "https://app.ritual-investing.test",
  adminOrigin: "https://admin.ritual-investing.test",
};
const headers = {
  authorization: "Bearer verified-supabase-token",
  origin: bindings.consumerOrigin,
  "content-type": "application/json",
};

function fixture() {
  let persistedReadAt: string | null = null;
  const summary = () => ({
    id: briefingId,
    briefing_type: "daily",
    period_start: "2026-08-28",
    period_end: "2026-08-28",
    generated_at: "2026-08-28T12:00:00.000Z",
    generation: 1,
    source_sequence: 1,
    read_at: persistedReadAt,
  });
  const briefings = {
    list: vi.fn(async () => [summary()]),
    setRead: vi.fn(async (_id: string, read: boolean) => {
      persistedReadAt = read ? readAt : null;
      return summary();
    }),
  };
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: Math.floor(Date.now() / 1_000),
    })),
    createRepositories: () => ({ briefings } as unknown as RetainedRepositorySet),
    publicPreviewRepository: {
      listPublished: vi.fn(async () => []),
      getPublished: vi.fn(async () => null),
    },
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
  return { app, briefings };
}

describe("briefing read-state API", () => {
  it("writes the owner marker and exposes the same state on the next read", async () => {
    const test = fixture();
    const marked = await test.app.request(
      `/v1/briefings/${briefingId}/read-state`,
      { method: "PUT", headers, body: JSON.stringify({ read: true }) },
      bindings,
    );
    expect(marked.status).toBe(200);
    expect(await marked.json()).toMatchObject({ data: { id: briefingId, read_at: readAt } });
    expect(test.briefings.setRead).toHaveBeenCalledWith(briefingId, true);

    const listed = await test.app.request(
      "/v1/briefings?limit=20",
      { headers },
      bindings,
    );
    expect(listed.status).toBe(200);
    expect(await listed.json()).toMatchObject({
      data: [{ id: briefingId, read_at: readAt }],
    });

    const unmarked = await test.app.request(
      `/v1/briefings/${briefingId}/read-state`,
      { method: "PUT", headers, body: JSON.stringify({ read: false }) },
      bindings,
    );
    expect(unmarked.status).toBe(200);
    expect(await unmarked.json()).toMatchObject({ data: { read_at: null } });
  });
});
