import { describe, expect, it } from "vitest";

import { decideRetry } from "../../src/jobs/retry-policy";
import {
  parseQueueWork,
  type QueueWorkMessage,
} from "../../src/jobs/queue-consumer";

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
});
