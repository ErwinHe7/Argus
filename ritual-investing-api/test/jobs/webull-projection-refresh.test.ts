import { describe, expect, it, vi } from "vitest";

import {
  assertBackgroundProjectionSafe,
  runWebullProjectionRefresh,
} from "../../src/jobs/webull-projection-refresh.ts";

describe("Webull projection recovery", () => {
  it("accepts bounded normalized reads and rejects credential-shaped data", () => {
    const now = new Date("2026-08-28T12:00:00.000Z");
    expect(() => assertBackgroundProjectionSafe({
      payload: [{ symbol: "AAPL", quantity: "1" }],
      providerObservedAt: now,
      fetchedAt: now,
      expiresAt: new Date(now.getTime() + 60_000),
      availability: "available",
    }, now)).not.toThrow();
    expect(() => assertBackgroundProjectionSafe({
      payload: { access_token: "credential-canary" },
      providerObservedAt: now,
      fetchedAt: now,
      expiresAt: new Date(now.getTime() + 60_000),
      availability: "available",
    }, now)).toThrow("invalid_event_payload");
  });

  it("uses only an existing projection lease reference", async () => {
    const refreshExistingProjection = vi.fn(async () => "refreshed" as const);
    const event = {
      id: "018f3c2a-4b67-7a89-8abc-123456789011",
      eventType: "webull.projection.refresh.requested" as const,
      handlerName: "webull-projection-refresh" as const,
      aggregateId: "018f3c2a-4b67-7a89-8abc-123456789012",
      userId: "018f3c2a-4b67-7a89-8abc-123456789013",
      deletionEpoch: 1,
    };
    await runWebullProjectionRefresh(event, { refreshExistingProjection }, vi.fn());
    expect(refreshExistingProjection).toHaveBeenCalledWith(expect.objectContaining({
      leaseId: event.aggregateId,
    }));
  });
});
