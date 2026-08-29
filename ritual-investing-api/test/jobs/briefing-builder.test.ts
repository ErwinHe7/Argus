import { describe, expect, it } from "vitest";

import type { DatabaseClient } from "../../src/db/database-port";
import {
  handlerFor,
  type JobHandlerDependencies,
} from "../../src/jobs/handlers";

describe("briefing builder", () => {
  it("constructs section JSON in Postgres instead of casting serialized JSON", async () => {
    const queries: Array<{
      text: string;
      values: readonly unknown[];
    }> = [];
    const database: DatabaseClient = {
      async query<Row>(text: string, values: readonly unknown[] = []) {
        queries.push({ text, values });
        return {
          rows:
            (text.includes("update argus_app.briefings")
              ? [{ id: "700199a4-4c23-470a-93c4-83b5181c775d" }]
              : []) as Row[],
          rowCount: text.includes("update argus_app.briefings") ? 1 : 0,
        };
      },
      release() {},
    };
    const event = {
      id: "c09b4ae8-b99f-4726-b59a-c386444b3b42",
      eventType: "briefing.daily.requested",
      handlerName: "briefing-builder",
      aggregateId: "700199a4-4c23-470a-93c4-83b5181c775d",
      userId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      deletionEpoch: 0,
    } as const;
    const effect = handlerFor(event, {} as JobHandlerDependencies);

    await expect(effect(database, event)).resolves.toBe(
      "briefing:700199a4-4c23-470a-93c4-83b5181c775d",
    );

    const section = queries.find(({ text }) =>
      text.includes("insert into argus_app.briefing_sections")
    );
    expect(section?.text).toContain(
      "jsonb_build_object('disclosure',$4::text)",
    );
    expect(section?.values[3]).toBe(
      "A reflective Argus briefing, not financial advice.",
    );
  });
});
