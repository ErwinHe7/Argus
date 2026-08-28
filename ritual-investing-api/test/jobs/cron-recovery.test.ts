import { describe, expect, it } from "vitest";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { redactedFailureCode } from "../../src/jobs/queue-runtime";

describe("Supabase worker recovery", () => {
  it("persists only allowlisted diagnostic codes", () => {
    expect(redactedFailureCode(new Error("storage_unavailable"))).toBe("storage_unavailable");
    expect(redactedFailureCode(new Error("email=canary@example.test token=canary-secret"))).toBe("internal_failure");
    expect(redactedFailureCode("provider raw body canary-financial-value")).toBe("internal_failure");
  });

  it("uses stable bounded briefing cadences and idempotent repeated ticks", async () => {
    const migration = await readFile(
      resolve("../supabase/migrations/20260828132056_u10_supabase_jobs_storage.sql"),
      "utf8",
    );
    const enqueue = migration.match(
      /create or replace function argus_private\.enqueue_due_retained_jobs[\s\S]*?alter function argus_private\.enqueue_due_retained_jobs/,
    )?.[0];
    expect(enqueue).toBeDefined();
    expect(enqueue).toMatch(/extract\(isodow from current_date\) = 1/);
    expect(enqueue).toMatch(/date_trunc\('week',current_date\)::date \+ 6/);
    expect(enqueue).toMatch(/extract\(day from current_date\) in \(1,15\)/);
    expect(enqueue).toMatch(/order by candidate\.user_id,candidate\.briefing_type\s+limit p_batch_size/);
    expect(enqueue).toMatch(/on conflict \(user_id,briefing_type,period_start,period_end\) do nothing/);
    expect(enqueue).toMatch(/order by dedupe_key limit p_batch_size/);
    expect(enqueue).not.toMatch(/recurring|order\.place|brokerage/);
  });
});
