import { describe, expect, it } from "vitest";

import type { DatabaseClient } from "../../src/db/database-port";
import {
  handlerFor,
  type JobHandlerDependencies,
} from "../../src/jobs/handlers";

describe("briefing generation coordination", () => {
  it("coordinates a generation without fabricating generated content", async () => {
    const queries: Array<{
      text: string;
      values: readonly unknown[];
    }> = [];
    const database: DatabaseClient = {
      async query<Row>(text: string, values: readonly unknown[] = []) {
        queries.push({ text, values });
        return {
          rows: [{ outcome: "generation-coordinated" }] as Row[],
          rowCount: 1,
        };
      },
      release() {},
    };
    const event = {
      id: "c09b4ae8-b99f-4726-b59a-c386444b3b42",
      eventType: "briefing.daily.requested",
      handlerName: "briefing-generation-coordinator",
      aggregateId: "700199a4-4c23-470a-93c4-83b5181c775d",
      tenantId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      lifecycleId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      userId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      deletionEpoch: 0,
    } as const;
    const effect = handlerFor(event, {} as JobHandlerDependencies);

    await expect(effect(database, event)).resolves.toBe(
      "generation-coordinated",
    );

    expect(queries).toEqual([{
      text: "select argus_private.coordinate_briefing_generation($1) as outcome",
      values: [event.id],
    }]);
    expect(queries.some(({ text }) => text.includes("briefing_sections"))).toBe(false);
  });
});
