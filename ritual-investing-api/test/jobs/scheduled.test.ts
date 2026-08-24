import { describe, expect, it } from "vitest";

import { consumersForTopic, runScheduled } from "../../src/jobs/scheduled.ts";

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
});
