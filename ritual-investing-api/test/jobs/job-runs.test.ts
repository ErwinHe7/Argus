import { describe, expect, it, vi } from "vitest";

import { leaseJob } from "../../src/jobs/job-runs";

describe("job leases", () => {
  it("claims a precreated Admin retry attempt before inserting a new row", async () => {
    const queries: string[] = [];
    const query = vi.fn(async (sql: string) => {
      queries.push(sql);
      if (sql.includes("update job_runs"))
        return {
          rows: [{ id: "018f3c2a-4b67-7a89-8abc-123456789099" }],
          rowCount: 1,
        };
      return { rows: [], rowCount: 0 };
    });
    const release = vi.fn();
    const end = vi.fn(async () => undefined);
    const lease = await leaseJob(
      "postgresql://runtime.example/ritual",
      {
        schema_version: 1,
        outbox_id: "018f3c2a-4b67-7a89-8abc-123456789001",
        consumer: "privacy-export",
      },
      1,
      () => ({
        connect: async () => ({ query, release }),
        end,
      }) as never,
    );
    expect(lease?.id).toBe("018f3c2a-4b67-7a89-8abc-123456789099");
    expect(queries.some((sql) => sql.includes("insert into job_runs"))).toBe(
      false,
    );
    expect(release).toHaveBeenCalledOnce();
    expect(end).toHaveBeenCalledOnce();
  });
});
