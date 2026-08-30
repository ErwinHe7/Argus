import { describe, expect, it, vi } from "vitest";

import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const briefingId = "018f3c2a-4b67-7a89-8abc-123456789061";
const assetId = "018f3c2a-4b67-7a89-8abc-123456789062";
const readAt = "2026-08-28T16:30:00.000Z";
const consumerOrigin = "https://app.ritual-investing.test";
const bindings = {
  environment: "test" as const,
  buildRevision: "u13-test",
  consumerOrigins: Object.freeze([consumerOrigin]),
  adminOrigin: "https://admin.ritual-investing.test",
  webAdmission: "open" as const,
};
const headers = {
  authorization: "Bearer verified-supabase-token",
  origin: consumerOrigin,
  "content-type": "application/json",
};

function fixture() {
  let persistedReadAt: Date | null = null;
  const summary = () => ({
    id: briefingId,
    briefing_type: "daily",
    period_start: "2026-08-28",
    period_end: "2026-08-28",
    generated_at: new Date("2026-08-28T12:00:00.000Z"),
    generation: 1,
    source_sequence: 1,
    read_at: persistedReadAt,
  });
  const briefings = {
    listPage: vi.fn(async () => [summary()]),
    list: vi.fn(async () => [summary()]),
    setRead: vi.fn(async (_id: string, read: boolean) => {
      persistedReadAt = read ? new Date(readAt) : null;
      return summary();
    }),
  };
  const assets = {
    listPage: vi.fn(async () => [{
      id: assetId,
      slug: "argus-test",
      symbol: "ARGX",
      name: "Argus Test Asset",
      asset_type: "equity",
      currency: "USD",
      revision_id: "018f3c2a-4b67-7a89-8abc-123456789063",
      revision_created_at: "2026-08-28 12:00:00+00",
      payload: { appearance_reason: "Timestamp regression fixture." },
    }]),
    list: vi.fn(async () => [{
      id: assetId,
      slug: "argus-test",
      symbol: "ARGX",
      name: "Argus Test Asset",
      asset_type: "equity",
      currency: "USD",
      revision_id: "018f3c2a-4b67-7a89-8abc-123456789063",
      revision_created_at: "2026-08-28 12:00:00+00",
      payload: { appearance_reason: "Timestamp regression fixture." },
    }]),
  };
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: Math.floor(Date.now() / 1_000),
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback({ assets, briefings } as unknown as RetainedRepositorySet),
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
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
    expect(await marked.json()).toMatchObject({
      data: {
        id: briefingId,
        generated_at: "2026-08-28T12:00:00.000Z",
        read_at: readAt,
      },
    });
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

describe("retained timestamp presentation", () => {
  it("normalizes parseable database timestamps in research disclosures", async () => {
    const test = fixture();
    const response = await test.app.request(
      "/v1/assets?limit=20",
      { headers },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      data: [{
        id: assetId,
        demo: { observed_at: "2026-08-28T12:00:00.000Z" },
      }],
    });
  });
});
