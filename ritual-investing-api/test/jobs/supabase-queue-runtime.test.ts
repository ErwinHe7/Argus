import { describe, expect, it, vi } from "vitest";

import {
  parseQueueWork,
  type QueueWorkMessage,
} from "../../src/jobs/queue-consumer";
import {
  runSupabaseQueue,
  type SupabaseQueueRuntime,
} from "../../src/jobs/queue-runtime";
import { handlerForEventType } from "../../src/jobs/scheduled";

const eventId = "018f3c2a-4b67-7a89-8abc-123456789001";

describe("Supabase queue runtime", () => {
  it("accepts only an opaque event id and schema version", () => {
    const message: QueueWorkMessage = { version: 1, event_id: eventId };
    expect(parseQueueWork(message)).toEqual(message);
    expect(() => parseQueueWork({ ...message, event_type: "privacy.export.requested" })).toThrow();
    expect(() => parseQueueWork({ ...message, consumer: "privacy-export" })).toThrow();
    expect(() => parseQueueWork({ ...message, token: "canary-secret" })).toThrow();
  });

  it("contains no background financial handler", () => {
    expect(handlerForEventType("privacy.export.requested")).toBe("privacy-export");
    expect(handlerForEventType("media.scan.requested")).toBe("media-scan");
    expect(handlerForEventType("recurring.plan.due")).toBeNull();
    expect(handlerForEventType("order.place.requested")).toBeNull();
    expect(handlerForEventType("provider_command_reconciliation_requested")).toBeNull();
  });

  it("bounds batches and releases the overlap lease", async () => {
    const release = vi.fn(async () => undefined);
    const runtime: SupabaseQueueRuntime = {
      acquireLease: vi.fn(async () => ({ token: "lease-1" })),
      releaseLease: release,
      relayOutbox: vi.fn(async () => 2),
      recoverExpired: vi.fn(async () => 1),
      processBatch: vi.fn(async () => ({ processed: 2, retried: 0, deadLettered: 0 })),
    };

    await expect(runSupabaseQueue(runtime, { batchSize: 0 })).rejects.toThrow("invalid_worker_batch_size");
    await expect(runSupabaseQueue(runtime, { batchSize: 26 })).rejects.toThrow("invalid_worker_batch_size");
    await expect(runSupabaseQueue(runtime, { batchSize: 5 })).resolves.toEqual({
      overlap: false,
      relayed: 2,
      recovered: 1,
      processed: 2,
      retried: 0,
      deadLettered: 0,
    });
    expect(release).toHaveBeenCalledWith({ token: "lease-1" });
  });

  it("does no work when another invocation owns the lease", async () => {
    const runtime: SupabaseQueueRuntime = {
      acquireLease: vi.fn(async () => null),
      releaseLease: vi.fn(),
      relayOutbox: vi.fn(),
      recoverExpired: vi.fn(),
      processBatch: vi.fn(),
    };
    await expect(runSupabaseQueue(runtime, { batchSize: 5 })).resolves.toEqual({
      overlap: true,
      relayed: 0,
      recovered: 0,
      processed: 0,
      retried: 0,
      deadLettered: 0,
    });
    expect(runtime.relayOutbox).not.toHaveBeenCalled();
  });
});
