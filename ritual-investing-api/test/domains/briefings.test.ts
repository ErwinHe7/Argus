import { beforeAll, describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app.ts";
import { createTestRsaKey } from "../support/jwt.ts";
import {
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures.ts";

describe("briefing reads", () => {
  let key: Awaited<ReturnType<typeof createTestRsaKey>>;
  beforeAll(async () => {
    key = await createTestRsaKey("u7-briefings");
  });

  const repository = () => ({
    daily: vi.fn().mockResolvedValue(null),
    list: vi
      .fn()
      .mockResolvedValue({
        items: [],
        next: {
          period: "2026-08-24",
          id: "018f3c2a-4b67-7a89-8abc-123456789001",
        },
      }),
    get: vi.fn(),
    markRead: vi.fn(),
  });
  const auth = async () => ({
    authorization: `Bearer ${await memberToken(key)}`,
  });

  it("returns briefing_pending without invoking any generation path", async () => {
    const repo = repository();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        briefingRepository: repo,
      },
    });
    const response = await app.request(
      "/v1/briefings/daily?local_date=2026-08-24",
      { headers: await auth() },
      testBindings(),
    );
    expect(response.status).toBe(202);
    expect(await response.json()).toMatchObject({
      data: { status: "briefing_pending", local_date: "2026-08-24" },
    });
    expect(repo.daily).toHaveBeenCalledOnce();
    expect(repo.list).not.toHaveBeenCalled();
  });

  it("signs type-and-period-scoped cursors for bounded immutable summaries", async () => {
    const repo = repository();
    const app = createApp({
      dependencies: {
        auth0Keys: [key.publicJwk],
        accountResolver: async () => resolvedMemberAccount,
        briefingRepository: repo,
      },
    });
    const first = await app.request(
      "/v1/briefings?type=weekly&period_start=2026-08-01&period_end=2026-08-31&limit=10",
      { headers: await auth() },
      testBindings(),
    );
    const cursor = ((await first.json()) as { meta: { next_cursor: string } })
      .meta.next_cursor;
    expect(cursor).toEqual(expect.any(String));
    const second = await app.request(
      `/v1/briefings?type=weekly&period_start=2026-08-01&period_end=2026-08-31&limit=10&cursor=${encodeURIComponent(cursor)}`,
      { headers: await auth() },
      testBindings(),
    );
    expect(second.status).toBe(200);
    expect(repo.list).toHaveBeenLastCalledWith(expect.any(Object), {
      type: "weekly",
      periodStart: "2026-08-01",
      periodEnd: "2026-08-31",
      limit: 10,
      afterPeriod: "2026-08-24",
      afterId: "018f3c2a-4b67-7a89-8abc-123456789001",
    });
  });
});
