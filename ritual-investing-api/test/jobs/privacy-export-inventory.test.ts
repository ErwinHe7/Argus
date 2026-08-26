import { describe, expect, it, vi } from "vitest";

import { handlerFor } from "../../src/jobs/handlers";
import type { OutboxEvent } from "../../src/jobs/consumer-receipts";
import type { QueueWorkMessage } from "../../src/jobs/queue-consumer";

const tenantId = "018f3c2a-4b67-7a89-8abc-123456789021";
const requestId = "018f3c2a-4b67-7a89-8abc-123456789022";
const outboxId = "018f3c2a-4b67-7a89-8abc-123456789023";

describe("privacy export onboarding inventory", () => {
  it("exports every persisted investing and ritual personalization field", async () => {
    const selectedSql: string[] = [];
    const query = vi.fn(async (sql: string) => {
      selectedSql.push(sql);
      if (sql.includes("update privacy_requests request"))
        return {
          rows: [
            {
              snapshot_at: new Date("2026-08-25T12:00:00.000Z"),
              source_sequence: "9",
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("select to_jsonb(export_row)")) {
        if (sql.includes("from preferences")) {
          const value: Record<string, unknown> = {};
          if (sql.includes("ritual_familiarity"))
            value.ritual_familiarity = "curious";
          if (sql.includes("ritual_language"))
            value.ritual_language = "balanced";
          if (sql.includes("ritual_interests"))
            value.ritual_interests = ["practical_research", "astrology"];
          return { rows: [{ value }], rowCount: 1 };
        }
        if (sql.includes("from investor_profiles")) {
          const value: Record<string, unknown> = {};
          if (sql.includes("investing_experience"))
            value.investing_experience = "some_experience";
          if (sql.includes("contribution_rhythm"))
            value.contribution_rhythm = "monthly";
          return { rows: [{ value }], rowCount: 1 };
        }
        return { rows: [], rowCount: 0 };
      }
      return { rows: [], rowCount: 1 };
    });
    let archiveText = "";
    const message: QueueWorkMessage = {
      schema_version: 1,
      outbox_id: outboxId,
      consumer: "privacy-export",
    };
    const event: OutboxEvent = {
      id: outboxId,
      topic: "privacy.export.requested",
      aggregate_kind: "privacy-request",
      aggregate_id: requestId,
      aggregate_version: 1,
      tenant_id: tenantId,
      reset_generation: 0,
      deletion_generation: 0,
      payload: { request_id: requestId },
    };
    const effect = handlerFor(message, {
      PRIVACY_EXPORTS: {
        put: vi.fn(async (_key: string, body: ReadableStream<Uint8Array>) => {
          archiveText = new TextDecoder().decode(
            await new Response(body).arrayBuffer(),
          );
        }),
      },
    } as never);

    await effect({ query } as never, event);

    expect(archiveText).toContain('"ritual_familiarity":"curious"');
    expect(archiveText).toContain('"ritual_language":"balanced"');
    expect(archiveText).toContain(
      '"ritual_interests":["practical_research","astrology"]',
    );
    expect(archiveText).toContain(
      '"investing_experience":"some_experience"',
    );
    expect(archiveText).toContain('"contribution_rhythm":"monthly"');

    const personalizationQueries = selectedSql
      .filter(
        (sql) =>
          sql.includes("from preferences") ||
          sql.includes("from investor_profiles"),
      )
      .join("\n");
    for (const field of [
      "ritual_familiarity",
      "ritual_language",
      "ritual_interests",
      "investing_experience",
      "contribution_rhythm",
    ])
      expect(personalizationQueries).toContain(field);
  });
});
