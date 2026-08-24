import { env, exports } from "cloudflare:workers";
import {
  createExecutionContext,
  createMessageBatch,
  createScheduledController,
  getQueueResult,
  waitOnExecutionContext,
} from "cloudflare:test";
import { describe, expect, it } from "vitest";

import type { Bindings } from "../../src/config/env";
import worker from "../../src/index";

describe("Worker entrypoints", () => {
  it("serves fetch requests without leaking stack detail", async () => {
    const response = await exports.default.fetch("https://api.example.test/health");
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ data: { status: "ok" } });
  });

  it("exposes scheduled and queue handlers", async () => {
    const scheduledContext = createExecutionContext();
    await worker.scheduled(
      createScheduledController({ cron: "0 5 * * *", scheduledTime: new Date(0) }),
      env as unknown as Bindings,
      scheduledContext,
    );
    await waitOnExecutionContext(scheduledContext);

    const queueContext = createExecutionContext();
    const batch = createMessageBatch("ritual-jobs", [
      {
        id: "message-1",
        timestamp: new Date(0),
        attempts: 1,
        body: { kind: "noop" },
      },
    ]);
    await worker.queue(batch, env as unknown as Bindings, queueContext);
    const result = await getQueueResult(batch, queueContext);
    expect(result.retryMessages).toEqual([]);
  });
});
