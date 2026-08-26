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
    const deadLetters: unknown[] = [];
    const ack = vi.fn();
    const retry = vi.fn();
    await runQueue(
      {
        messages: [
          {
            body: { push_token: "never-log-this", provider_body: "raw" },
            attempts: 1,
            ack,
            retry,
          },
        ],
      } as never,
      {
        ENVIRONMENT: "test",
        JOBS_DLQ: {
          send: async (message: unknown) => {
            deadLetters.push(message);
          },
        },
      } as never,
      undefined,
      (event) => {
        events.push(event);
      },
    );
    expect(ack).toHaveBeenCalledOnce();
    expect(retry).not.toHaveBeenCalled();
    expect(deadLetters).toEqual([
      expect.objectContaining({
        kind: "poison",
        failure_code: "invalid_event_payload",
        body_hash: expect.stringMatching(/^[a-f0-9]{64}$/),
      }),
    ]);
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
    expect(JSON.stringify(deadLetters)).not.toMatch(
      /never-log-this|provider_body|push_token/,
    );
  });

  it("retries poison delivery when the required DLQ is unavailable", async () => {
    const ack = vi.fn();
    const retry = vi.fn();
    await runQueue(
      {
        messages: [{ body: { malformed: true }, attempts: 1, ack, retry }],
      } as never,
      {
        ENVIRONMENT: "test",
        JOBS_DLQ: { send: async () => Promise.reject(new Error("down")) },
      } as never,
    );
    expect(ack).not.toHaveBeenCalled();
    expect(retry).toHaveBeenCalledWith({ delaySeconds: 60 });
  });

  it("parks killed work as a fresh delivery without spending its retry budget", async () => {
    const ack = vi.fn();
    const retry = vi.fn();
    const send = vi.fn(async () => undefined);
    const work: QueueWorkMessage = {
      schema_version: 1,
      outbox_id: "018f3c2a-4b67-7a89-8abc-123456789001",
      consumer: "briefing-builder",
    };
    await runQueue(
      { messages: [{ body: work, attempts: 4, ack, retry }] } as never,
      {
        ENVIRONMENT: "test",
        KILL_SWITCH_QUEUE: "on",
        ASYNC_QUEUE: { send },
      } as never,
    );
    expect(send).toHaveBeenCalledWith(work, { delaySeconds: 300 });
    expect(ack).toHaveBeenCalledOnce();
    expect(retry).not.toHaveBeenCalled();
  });
});
