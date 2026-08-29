import { describe, expect, it, vi } from "vitest";

import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const userA = "018f3c2a-4b67-7a89-8abc-123456789001";
const userB = "018f3c2a-4b67-7a89-8abc-123456789002";
const briefingIds = [
  "018f3c2a-4b67-7a89-8abc-123456789103",
  "018f3c2a-4b67-7a89-8abc-123456789102",
  "018f3c2a-4b67-7a89-8abc-123456789101",
] as const;
const bindings = {
  environment: "test" as const,
  buildRevision: "u8-pagination-test",
  consumerOrigin: "https://app.ritual-investing.test",
  adminOrigin: "https://admin.ritual-investing.test",
};
const headers = {
  authorization: "Bearer verified-supabase-token",
  origin: bindings.consumerOrigin,
};

function createTestApp(
  repositories: Partial<RetainedRepositorySet>,
  currentUser: () => string = () => userA,
) {
  return createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId: currentUser(),
      sessionId,
      aal: "aal1" as const,
      issuedAt: Math.floor(Date.now() / 1_000),
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback(repositories as RetainedRepositorySet),
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
}

const briefingRow = (id: string) => ({
  id,
  briefing_type: "daily",
  period_start: "2026-08-28",
  period_end: "2026-08-29",
  generated_at: "2026-08-29T12:00:00.000Z",
  generation: 2,
  source_sequence: 9,
  read_at: null,
});

describe("U8 route pagination contracts", () => {
  it("paginates equal sort values with a unique keyset tie-breaker", async () => {
    const listPage = vi.fn(async (input: {
      limit: number;
      after: readonly [string, string] | null;
    }) => {
      const rows = briefingIds.map(briefingRow);
      const afterId = input.after?.[1];
      return (afterId === undefined
        ? rows
        : rows.filter((row) => row.id < afterId)).slice(0, input.limit);
    });
    const app = createTestApp({ briefings: { listPage } as never });

    const first = await app.request(
      "/v1/briefings?type=daily&limit=2",
      { headers },
      bindings,
    );
    expect(first.status).toBe(200);
    const firstBody = await first.json() as {
      data: Array<{ id: string }>;
      meta: { next_cursor: string | null; has_more: boolean };
    };
    expect(firstBody.data.map(({ id }) => id)).toEqual(briefingIds.slice(0, 2));
    expect(firstBody.meta.has_more).toBe(true);
    expect(firstBody.meta.next_cursor).not.toBeNull();

    const second = await app.request(
      `/v1/briefings?type=daily&limit=2&cursor=${encodeURIComponent(firstBody.meta.next_cursor!)}`,
      { headers },
      bindings,
    );
    expect(second.status).toBe(200);
    const secondBody = await second.json() as {
      data: Array<{ id: string }>;
      meta: { next_cursor: string | null; has_more: boolean };
    };
    expect(secondBody.data.map(({ id }) => id)).toEqual([briefingIds[2]]);
    expect(secondBody.meta).toMatchObject({ next_cursor: null, has_more: false });
    expect([...new Set([
      ...firstBody.data.map(({ id }) => id),
      ...secondBody.data.map(({ id }) => id),
    ])]).toHaveLength(3);
    expect(listPage.mock.calls[1]?.[0]).toMatchObject({
      limit: 3,
      after: ["2026-08-29", briefingIds[1]],
    });
  });

  it("rejects a cursor when member, filters, or page size changes", async () => {
    let activeUser = userA;
    const listPage = vi.fn(async () =>
      briefingIds.map(briefingRow).slice(0, 2)
    );
    const app = createTestApp(
      { briefings: { listPage } as never },
      () => activeUser,
    );
    const initial = await app.request(
      "/v1/briefings?type=daily&limit=1",
      { headers },
      bindings,
    );
    const cursor = (await initial.json() as {
      meta: { next_cursor: string };
    }).meta.next_cursor;

    activeUser = userB;
    expect((await app.request(
      `/v1/briefings?type=daily&limit=1&cursor=${encodeURIComponent(cursor)}`,
      { headers },
      bindings,
    )).status).toBe(422);
    activeUser = userA;
    expect((await app.request(
      `/v1/briefings?type=weekly&limit=1&cursor=${encodeURIComponent(cursor)}`,
      { headers },
      bindings,
    )).status).toBe(422);
    expect((await app.request(
      `/v1/briefings?type=daily&limit=2&cursor=${encodeURIComponent(cursor)}`,
      { headers },
      bindings,
    )).status).toBe(422);
  });

  it("passes Coven filters and one-row overfetch to the normalized SQL port", async () => {
    const listPage = vi.fn(async () => []);
    const app = createTestApp({ coven: { listPage } as never });
    const response = await app.request(
      "/v1/coven?category=owner&verified_as_of=2026-08-01&limit=2",
      { headers },
      bindings,
    );
    expect(response.status).toBe(200);
    expect(listPage).toHaveBeenCalledWith({
      limit: 3,
      category: "owner",
      verifiedAsOf: "2026-08-01",
      after: null,
    });
  });

  it("preserves postgres Date circle cursor timestamps through the opaque cursor", async () => {
    const circleIds = [
      "018f3c2a-4b67-7a89-8abc-123456789201",
      "018f3c2a-4b67-7a89-8abc-123456789202",
    ];
    const archivedAt = new Date("2026-08-29T12:00:00.000Z");
    const rows = circleIds.map((id) => ({
      id, user_id: userA, deletion_epoch: "0", title: "Circle", description: "",
      private: true, source_template_id: null, source_revision_id: null, version: "1",
      archived_at: archivedAt, archived_sort: true, archived_cursor_at: archivedAt,
    }));
    const listPage = vi.fn(async (input: { after: readonly [boolean, string | null, string] | null }) =>
      input.after === null ? rows : []
    );
    const app = createTestApp({ circles: { listPage } as never });
    const first = await app.request("/v1/circles?archived=include&limit=1", { headers }, bindings);
    expect(first.status).toBe(200);
    const cursor = (await first.json() as { data: Array<{ archived_at: string }>; meta: { next_cursor: string } });
    expect(cursor.data[0]?.archived_at).toBe("2026-08-29T12:00:00.000Z");
    await app.request(`/v1/circles?archived=include&limit=1&cursor=${encodeURIComponent(cursor.meta.next_cursor)}`, { headers }, bindings);
    expect(listPage.mock.calls[1]?.[0].after).toEqual([true, "2026-08-29T12:00:00.000Z", circleIds[0]]);
  });

  it("uses a point lookup for a published creator", async () => {
    const creatorId = "018f3c2a-4b67-7a89-8abc-123456789120";
    const getCreator = vi.fn(async () => ({
      id: creatorId,
      slug: "mira-vale",
      display_name: "Mira Vale",
      bio: "Fictional research curator.",
      is_fictional: true,
      observed_at: "2026-08-29T12:00:00.000Z",
    }));
    const app = createTestApp({ discover: { getCreator } as never });

    const response = await app.request(
      `/v1/discover/creators/${creatorId}`,
      { headers },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(getCreator).toHaveBeenCalledOnce();
    expect(getCreator).toHaveBeenCalledWith(creatorId);
    expect((await response.json() as { data: { id: string } }).data.id).toBe(
      creatorId,
    );
  });
});
