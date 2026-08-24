import { describe, expect, it, vi } from "vitest";

import { decideRetry } from "../../src/jobs/retry-policy";
import {
  parseQueueWork,
  type QueueWorkMessage,
} from "../../src/jobs/queue-consumer";
import { runQueue } from "../../src/jobs/queue-runtime";

describe("Queue retry policy", () => {
  it("bounds exponential retry and terminalizes poison work without error text", () => {
    expect(decideRetry(1, "provider_timeout")).toEqual({
      action: "retry",
      delaySeconds: 10,
      failureCode: "provider_timeout",
    });
    expect(decideRetry(5, "provider_timeout")).toEqual({
      action: "dead_letter",
      failureCode: "provider_timeout",
    });
  });

  it("accepts only minimal versioned identifiers and rejects provider bodies or tokens", () => {
    const valid: QueueWorkMessage = {
      schema_version: 1,
      outbox_id: "018f3c2a-4b67-7a89-8abc-123456789001",
      consumer: "briefing-builder",
    };
    expect(parseQueueWork(valid)).toEqual(valid);
    expect(() => parseQueueWork({ ...valid, push_token: "secret" })).toThrow();
    expect(() => parseQueueWork({ ...valid, provider_body: {} })).toThrow();
  });

  it("emits a redacted terminal event for malformed delivery without its body", async () => {
    const events: unknown[] = [];
    const ack = vi.fn();
    await runQueue(
      {
        messages: [
          {
            body: { push_token: "never-log-this", provider_body: "raw" },
            attempts: 1,
            ack,
            retry: vi.fn(),
          },
        ],
      } as never,
      { ENVIRONMENT: "test" } as never,
      undefined,
      (event) => {
        events.push(event);
      },
    );
    expect(ack).toHaveBeenCalledOnce();
    expect(events).toEqual([
      expect.objectContaining({
        event_name: "queue.delivery",
        outcome: "rejected",
        failure_code: "invalid_event_payload",
      }),
    ]);
    expect(JSON.stringify(events)).not.toMatch(
      /never-log-this|provider_body|push_token/,
    );
  });
});
