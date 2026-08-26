import type { NeonQueryFunction } from "@neondatabase/serverless";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";

import { createWaitlistRepository } from "../../src/waitlist/repository.ts";
import {
  asRole,
  describePostgres,
  ensureMigrated,
  ownerClient,
  resetSubmissions,
} from "./support.ts";

const NOTICE = "waitlist-v1-2026-08-25";

describe("Neon HTTP waitlist repository", () => {
  it("constructs a one-shot parameterized capability only when given the runtime URL", async () => {
    const calls: Array<{ strings: readonly string[]; values: readonly unknown[] }> = [];
    const query = (async (strings: TemplateStringsArray, ...values: unknown[]) => {
      calls.push({ strings: [...strings], values });
      return calls.length === 2 ? [{ purge_expired: "3" }] : [];
    }) as unknown as NeonQueryFunction<false, false>;
    const repository = createWaitlistRepository("postgresql://runtime:redacted@example.test/waitlist", {
      queryFactory: () => query,
    });

    await expect(repository.submit("  Mixed.Case+tag@example.com  ", NOTICE)).resolves.toBeUndefined();
    await expect(repository.purgeExpired()).resolves.toEqual({ deletedCount: 3 });

    expect(calls[0]?.strings.join("?")).toMatch(/submit_provisional\(\?, \?\)/);
    expect(calls[0]?.values).toEqual(["  Mixed.Case+tag@example.com  ", NOTICE]);
    expect(calls[1]?.strings.join("?")).toMatch(/purge_expired\(\)/);
    expect(JSON.stringify(calls)).not.toContain("redacted");
  });
});

describePostgres("waitlist submission capability", () => {
  beforeAll(ensureMigrated);
  beforeEach(resetSubmissions);

  it("normalizes only case and surrounding space while preserving dots and plus aliases", async () => {
    await asRole("waitlist_runtime", async (runtime) => {
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["  Person.Name+one@example.com ", NOTICE]);
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["person.name+one@EXAMPLE.COM", "future-v2"]);
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["personname+one@example.com", NOTICE]);
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["person.name@example.com", NOTICE]);
    });

    const owner = await ownerClient();
    try {
      const rows = await owner.query<{
        normalized_email: string;
        notice_version: string;
        submitted_at: Date;
      }>("select * from waitlist_private.provisional_submissions order by normalized_email");
      expect(rows.rows).toHaveLength(3);
      expect(rows.rows.map((row) => row.normalized_email)).toEqual([
        "person.name+one@example.com",
        "person.name@example.com",
        "personname+one@example.com",
      ]);
      expect(rows.rows[0]?.notice_version).toBe(NOTICE);
    } finally {
      await owner.end();
    }
  });

  it("keeps the first notice and server timestamp immutable across concurrent duplicates", async () => {
    const before = new Date();
    await asRole("waitlist_runtime", async (runtime) => {
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["first@example.com", NOTICE]);
    });
    await Promise.all(
      Array.from({ length: 12 }, (_, index) =>
        asRole("waitlist_runtime", (runtime) =>
          runtime.query("select waitlist_private.submit_provisional($1, $2)", [
            index % 2 === 0 ? " FIRST@example.com " : "first@EXAMPLE.com",
            `rewritten-${index}`,
          ]),
        ),
      ),
    );
    const owner = await ownerClient();
    try {
      const result = await owner.query<{ notice_version: string; submitted_at: Date }>(
        "select notice_version, submitted_at from waitlist_private.provisional_submissions where normalized_email = 'first@example.com'",
      );
      expect(result.rows).toHaveLength(1);
      expect(result.rows[0]?.notice_version).toBe(NOTICE);
      expect(result.rows[0]?.submitted_at.getTime()).toBeGreaterThanOrEqual(before.getTime());
      const timestamp = result.rows[0]?.submitted_at.toISOString();
      await asRole("waitlist_runtime", (runtime) =>
        runtime.query("select waitlist_private.submit_provisional($1, $2)", ["first@example.com", "another-version"]),
      );
      const after = await owner.query<{ submitted_at: Date }>(
        "select submitted_at from waitlist_private.provisional_submissions where normalized_email = 'first@example.com'",
      );
      expect(after.rows[0]?.submitted_at.toISOString()).toBe(timestamp);
    } finally {
      await owner.end();
    }
  });

  it("rejects hostile bounds without interpreting input as SQL", async () => {
    await asRole("waitlist_runtime", async (runtime) => {
      await expect(
        runtime.query("select waitlist_private.submit_provisional($1, $2)", ["x".repeat(255), NOTICE]),
      ).rejects.toThrow();
      await expect(
        runtime.query("select waitlist_private.submit_provisional($1, $2)", ["abc", NOTICE]),
      ).rejects.toThrow();
      await expect(
        runtime.query("select waitlist_private.submit_provisional($1, $2)", ["valid@example.com", "x".repeat(129)]),
      ).rejects.toThrow();
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", [
        "o'hara+');drop-table@example.com",
        NOTICE,
      ]);
    });
    const owner = await ownerClient();
    try {
      const rows = await owner.query<{ normalized_email: string }>(
        "select normalized_email from waitlist_private.provisional_submissions",
      );
      expect(rows.rows).toEqual([{ normalized_email: "o'hara+');drop-table@example.com" }]);
    } finally {
      await owner.end();
    }
  });
});
