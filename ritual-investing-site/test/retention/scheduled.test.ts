import { describe, expect, it, vi } from "vitest";

import { createWorker, type RuntimeSiteEnv, type SiteEnv } from "../../src/index.ts";
import { runScheduledRetention, type RetentionTelemetryPoint } from "../../src/retention/scheduled.ts";

describe("scheduled retention", () => {
  it("invokes only the no-argument purge capability and records an idempotent checkpoint", async () => {
    const purgeExpired = vi.fn(async () => undefined);
    const checkpoint = {
      readLastSuccess: vi.fn(async () => 100),
      recordSuccess: vi.fn(async () => undefined),
    };
    const telemetry: RetentionTelemetryPoint[] = [];

    const result = await runScheduledRetention({
      scheduledAt: 200,
      purge: { purgeExpired },
      checkpoint,
      emit: (point) => telemetry.push(point),
      sleep: vi.fn(async () => undefined),
    });

    expect(result).toEqual({ ok: true, attempts: 1, overdue: false });
    expect(purgeExpired).toHaveBeenCalledWith();
    expect(checkpoint.recordSuccess).toHaveBeenCalledWith(200);
    expect(telemetry).toEqual([{ event: "retention_purge_completed", attempts: 1, overdue: false }]);
  });

  it("retries a transient failure with a strict bound", async () => {
    const purgeExpired = vi.fn().mockRejectedValueOnce(new Error("temporary")).mockResolvedValue(undefined);
    const sleep = vi.fn(async () => undefined);

    const result = await runScheduledRetention({
      scheduledAt: 200,
      purge: { purgeExpired },
      checkpoint: { readLastSuccess: async () => 150, recordSuccess: async () => undefined },
      emit: vi.fn(),
      sleep,
    });

    expect(result).toEqual({ ok: true, attempts: 2, overdue: false });
    expect(purgeExpired).toHaveBeenCalledTimes(2);
    expect(sleep).toHaveBeenCalledOnce();
  });

  it("emits aggregate failure and overdue telemetry without exception or request data", async () => {
    const points: RetentionTelemetryPoint[] = [];
    const result = await runScheduledRetention({
      scheduledAt: 200_000_000,
      purge: { purgeExpired: vi.fn(async () => { throw new Error("connection string with private detail"); }) },
      checkpoint: { readLastSuccess: async () => 0, recordSuccess: async () => undefined },
      emit: (point) => points.push(point),
      sleep: vi.fn(async () => undefined),
    });

    expect(result).toEqual({ ok: false, attempts: 3, overdue: true });
    expect(points).toEqual([
      { event: "retention_purge_failed", attempts: 3, overdue: true },
      { event: "retention_purge_overdue", attempts: 3, overdue: true },
    ]);
    expect(JSON.stringify(points)).not.toContain("private detail");
  });

  it("wires the daily handler to only purge, checkpoint, and allowlisted aggregate telemetry", async () => {
    const purgeExpired = vi.fn(async () => undefined);
    const written: unknown[] = [];
    const checkpoint = new Map<string, string>([["retention:last-success-scheduled-at:v1", "150"]]);
    const environment: RuntimeSiteEnv = {
      ASSETS: {
        fetch: vi.fn(async () => new Response("asset")),
        connect() {
          throw new Error("Static Assets never opens sockets in retention tests.");
        },
      } satisfies SiteEnv["ASSETS"],
      ENVIRONMENT: "production",
      WAITLIST_SUBMISSIONS: "off",
      WAITLIST_TELEMETRY: { writeDataPoint: (point) => { written.push(point); } },
    };
    let task: Promise<unknown> | undefined;
    const context = {
      waitUntil(promise: Promise<unknown>) { task = promise; },
    } as ExecutionContext;
    const worker = createWorker({
      purgeFactory: () => ({ purgeExpired }),
      checkpointFactory: () => ({
        readLastSuccess: async () => Number(checkpoint.get("retention:last-success-scheduled-at:v1") ?? "0"),
        recordSuccess: async (scheduledAt) => {
          checkpoint.set("retention:last-success-scheduled-at:v1", String(scheduledAt));
        },
      }),
      sleep: async () => undefined,
    });

    worker.scheduled({ scheduledTime: 200 }, environment, context);
    await task;

    expect(purgeExpired).toHaveBeenCalledWith();
    expect(checkpoint.get("retention:last-success-scheduled-at:v1")).toBe("200");
    expect(written).toEqual([{
      indexes: ["retention_purge_completed"],
      blobs: ["production", "within_window"],
      doubles: [1, 0],
    }]);
    expect(JSON.stringify(written)).not.toMatch(/url|query|email|token|body|user.?agent|connection/i);

    const submission = await worker.fetch(
      new Request("https://just-build-this.app/api/waitlist", { method: "POST" }),
      environment,
      {} as ExecutionContext,
    );
    expect(submission.status).toBe(503);
  });
});
