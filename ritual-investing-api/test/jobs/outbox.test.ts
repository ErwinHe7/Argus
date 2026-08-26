import { describe, expect, it, vi } from "vitest";

import { enqueueOutbox } from "../../src/jobs/outbox";

describe("transactional outbox", () => {
  it("writes the minimal versioned event through the caller transaction", async () => {
    const query = vi.fn().mockResolvedValue({ rows: [{ id: "outbox-1" }] });
    const id = await enqueueOutbox({ query } as never, {
      topic: "briefing.requested",
      aggregateKind: "tenant",
      aggregateId: "018f3c2a-4b67-7a89-8abc-123456789001",
      aggregateVersion: 7,
      tenantId: "018f3c2a-4b67-7a89-8abc-123456789001",
      resetGeneration: 2,
      deletionGeneration: 0,
      dedupeKey: "daily:2026-08-24:7",
      payload: { local_date: "2026-08-24" },
    });
    expect(id).toBe("outbox-1");
    expect(query).toHaveBeenCalledOnce();
  });

  it("rejects credential-like or provider payloads before SQL", async () => {
    const query = vi.fn();
    await expect(
      enqueueOutbox({ query } as never, {
        topic: "notification.requested",
        aggregateKind: "tenant",
        aggregateId: "018f3c2a-4b67-7a89-8abc-123456789001",
        aggregateVersion: 1,
        tenantId: "018f3c2a-4b67-7a89-8abc-123456789001",
        resetGeneration: 1,
        deletionGeneration: 0,
        dedupeKey: "unsafe",
        payload: { provider_body: { token: "secret" } },
      }),
    ).rejects.toThrow("unsafe_outbox_payload");
    expect(query).not.toHaveBeenCalled();
  });
});
