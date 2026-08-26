import { describe, expect, it, vi } from "vitest";

import {
  consumersForTopic,
  publishDueOutbox,
  runScheduled,
} from "../../src/jobs/scheduled.ts";

describe("scheduled async dispatch", () => {
  it("maps only allowlisted topics to named consumers", () => {
    expect(consumersForTopic("briefing.daily.requested")).toEqual([
      "briefing-builder",
    ]);
    expect(consumersForTopic("briefing.weekly.generated")).toEqual([
      "notification-writer",
    ]);
    expect(consumersForTopic("notification.delivery.requested")).toEqual([
      "notification-delivery",
    ]);
    expect(consumersForTopic("media.scan.requested")).toEqual(["media-scan"]);
    expect(consumersForTopic("media.quarantine.cleanup")).toEqual([
      "media-cleanup",
    ]);
    expect(consumersForTopic("media.public.cleanup")).toEqual([
      "media-cleanup",
    ]);
    expect(consumersForTopic("privacy.deletion.requested")).toEqual([
      "privacy-purge",
    ]);
    expect(consumersForTopic("recurring.plan.due")).toEqual([
      "recurring-plan-delivery",
    ]);
    expect(
      consumersForTopic("privacy.export.retention.requested"),
    ).toEqual(["privacy-export-retention"]);
    expect(consumersForTopic("provider.raw.body")).toEqual([]);
  });

  it("honors the scheduled kill switch before opening a database binding", async () => {
    const events: unknown[] = [];
    await expect(
      runScheduled(
        { cron: "0 5 * * *", scheduledTime: Date.now() } as ScheduledController,
        { KILL_SWITCH_SCHEDULED: "on", ENVIRONMENT: "test" } as never,
        undefined,
        (event) => {
          events.push(event);
        },
      ),
    ).resolves.toBeUndefined();
    expect(events).toEqual([
      expect.objectContaining({
        event_name: "scheduled.delivery",
        outcome: "deferred",
        failure_code: "kill_switch_enabled",
      }),
    ]);
  });

  it("claims recurring and retention work on the minute cron while a global queue switch stops publishing", async () => {
    const sql: string[] = [];
    const query = vi.fn(async (statement: string) => {
      sql.push(statement);
      return { rows: [], rowCount: 0 };
    });
    const release = vi.fn();
    const end = vi.fn(async () => undefined);
    const sendBatch = vi.fn();
    await runScheduled(
      { cron: "* * * * *", scheduledTime: Date.now() } as ScheduledController,
      {
        ENVIRONMENT: "test",
        SCHEDULER_DATABASE_URL: "postgresql://scheduler.example/ritual",
        KILL_SWITCH_QUEUE: "on",
        ASYNC_QUEUE: { send: vi.fn(), sendBatch },
      } as never,
      () => ({
        connect: async () => ({ query, release }),
        end,
      }) as never,
    );
    expect(sql.join("\n")).toContain("enqueue_due_recurring_plans");
    expect(sql.join("\n")).toContain("enqueue_expired_privacy_exports");
    expect(sendBatch).not.toHaveBeenCalled();
  });

  it("publishes routed work in a batch and terminalizes unknown topics", async () => {
    const routedId = "018f3c2a-4b67-7a89-8abc-123456789021";
    const unknownId = "018f3c2a-4b67-7a89-8abc-123456789022";
    const calls: Array<{ sql: string; values?: unknown[] }> = [];
    const query = vi.fn(async (sql: string, values?: unknown[]) => {
      calls.push(values === undefined ? { sql } : { sql, values });
      if (sql.includes("select id,topic from outbox_events"))
        return {
          rows: [
            { id: routedId, topic: "privacy.export.requested" },
            { id: unknownId, topic: "future.unsupported.topic" },
          ],
          rowCount: 2,
        };
      return { rows: [], rowCount: 0 };
    });
    const sendBatch = vi.fn(async () => undefined);
    const published = await publishDueOutbox(
      "postgresql://scheduler.example/ritual",
      { send: vi.fn(), sendBatch } as never,
      () => ({
        connect: async () => ({ query, release: vi.fn() }),
        end: async () => undefined,
      }) as never,
    );
    expect(published).toBe(1);
    expect(sendBatch).toHaveBeenCalledWith([
      {
        body: {
          schema_version: 1,
          outbox_id: routedId,
          consumer: "privacy-export",
        },
      },
    ]);
    expect(
      calls.some(
        (call) =>
          call.sql.includes("terminalize_unroutable_outbox") &&
          JSON.stringify(call.values).includes(unknownId),
      ),
    ).toBe(true);
  });
});
