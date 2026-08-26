import { describe, expect, it, vi } from "vitest";

import {
  notificationDeliveryEnabled,
  notificationWriterEnabled,
} from "../../src/config/env";
import type { OutboxEvent } from "../../src/jobs/consumer-receipts";
import { handlerFor } from "../../src/jobs/handlers";

const tenantId = "018f3c2a-4b67-7a89-8abc-123456789010";
const eventId = "018f3c2a-4b67-7a89-8abc-123456789011";
const briefingId = "018f3c2a-4b67-7a89-8abc-123456789012";
const notificationId = "018f3c2a-4b67-7a89-8abc-123456789013";

describe("in-app-only notification runtime", () => {
  it("uses explicit writer and delivery gates with legacy fallback", () => {
    expect(
      notificationWriterEnabled({ KILL_SWITCH_NOTIFICATIONS: "on" } as never),
    ).toBe(false);
    expect(
      notificationWriterEnabled({
        KILL_SWITCH_NOTIFICATIONS: "on",
        KILL_SWITCH_NOTIFICATION_WRITER: "off",
      } as never),
    ).toBe(true);
    expect(
      notificationDeliveryEnabled({
        KILL_SWITCH_NOTIFICATIONS: "off",
        KILL_SWITCH_NOTIFICATION_DELIVERY: "on",
      } as never),
    ).toBe(false);
  });

  it("persists one inbox row and enqueues no delivery when delivery is off", async () => {
    const calls: Array<{ sql: string; values: unknown[] }> = [];
    const query = vi.fn(async (sql: string, values: unknown[] = []) => {
      calls.push({ sql, values });
      if (sql.includes("from notification_preferences"))
        return { rows: [{ allowed: true }], rowCount: 1 };
      if (sql.includes("insert into notifications"))
        return { rows: [{ id: notificationId }], rowCount: 1 };
      if (sql.includes("insert into outbox_events"))
        return { rows: [{ id: eventId }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    });
    const effect = handlerFor(
      {
        schema_version: 1,
        outbox_id: eventId,
        consumer: "notification-writer",
      },
      {
        KILL_SWITCH_NOTIFICATION_WRITER: "off",
        KILL_SWITCH_NOTIFICATION_DELIVERY: "on",
      } as never,
    );
    const event: OutboxEvent = {
      id: eventId,
      topic: "briefing.daily.generated",
      aggregate_kind: "briefing",
      aggregate_id: briefingId,
      aggregate_version: 1,
      tenant_id: tenantId,
      reset_generation: 0,
      deletion_generation: 0,
      payload: { briefing_id: briefingId },
    };

    await expect(effect({ query } as never, event)).resolves.toBe(
      `notification:${eventId}`,
    );
    expect(
      calls.filter((call) => call.sql.includes("insert into notifications")),
    ).toHaveLength(1);
    expect(
      calls.filter((call) => call.sql.includes("insert into outbox_events")),
    ).toHaveLength(0);
  });
});
