import { createHmac } from "node:crypto";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";

import {
  denialDigest,
  FileDenialJournal,
  recordVerifiedRemoval,
  type DenialJournal,
  type DenialJournalEntry,
} from "../../scripts/record-removal.ts";
import { replayVerifiedRemovals } from "../../scripts/replay-removals.ts";
import {
  asRole,
  describePostgres,
  ensureMigrated,
  ownerClient,
  resetSubmissions,
} from "./support.ts";

const NOTICE = "waitlist-v1-2026-08-25";
const KEY = "test-only-key-with-at-least-32-bytes";

class MemoryJournal implements DenialJournal {
  readonly entries = new Map<string, DenialJournalEntry>();

  async read(environment: "production" | "beta"): Promise<DenialJournalEntry[]> {
    return [...this.entries.values()].filter((entry) => entry.environment === environment);
  }

  async put(entry: DenialJournalEntry): Promise<void> {
    const existing = this.entries.get(entry.digest);
    if (existing === undefined || existing.deletedAt < entry.deletedAt) this.entries.set(entry.digest, entry);
  }
}

describe("keyed waitlist denial journal", () => {
  it("uses a versioned environment-specific HMAC and never retains plaintext", async () => {
    const digest = denialDigest("person@example.com", "beta", KEY);
    expect(digest).toBe(
      createHmac("sha256", KEY).update("just-build-this:waitlist-denial:v1:beta:person@example.com").digest("hex"),
    );
    expect(digest).toMatch(/^[a-f0-9]{64}$/);
    expect(digest).not.toContain("person");
  });

  it("persists only the keyed digest in an environment-bound file fixture", async () => {
    const directory = await mkdtemp(join(tmpdir(), "waitlist-denial-journal-"));
    const path = join(directory, "beta.json");
    const journal = new FileDenialJournal(path, "beta");
    const digest = denialDigest("fixture@example.com", "beta", KEY);
    await journal.put({
      version: "waitlist-denial-v1",
      environment: "beta",
      digest,
      deletedAt: new Date(0).toISOString(),
    });
    const raw = await readFile(path, "utf8");
    expect(raw).toContain(digest);
    expect(raw).toContain("1970-01-01T00:00:00.000000Z");
    expect(raw).not.toContain("fixture@example.com");
    await expect(journal.read("beta")).resolves.toEqual([
      expect.objectContaining({ digest, deletedAt: "1970-01-01T00:00:00.000000Z" }),
    ]);
    await expect(new FileDenialJournal(path, "production").read("production")).rejects.toThrow(/environment/i);
  });
});

describePostgres("verified removal and restore replay", () => {
  beforeAll(ensureMigrated);
  beforeEach(resetSubmissions);

  it("requires mailbox-possession verification before deleting or journaling", async () => {
    const journal = new MemoryJournal();
    await expect(
      recordVerifiedRemoval({
        mailboxPossessionVerified: false,
        environment: "beta",
        email: "target@example.com",
        hmacKey: KEY,
        journal,
        maintenance: {
          removeVerified: () => {
            throw new Error("must not execute");
          },
        },
      }),
    ).rejects.toThrow(/mailbox possession/i);
    expect(journal.entries.size).toBe(0);
  });

  it("removes only the target, records no plaintext, and repeats idempotently", async () => {
    await asRole("waitlist_runtime", async (runtime) => {
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["target@example.com", NOTICE]);
      await runtime.query("select waitlist_private.submit_provisional($1, $2)", ["keep@example.com", NOTICE]);
    });
    const journal = new MemoryJournal();
    const maintenance = {
      removeVerified: (email: string) =>
        asRole("waitlist_maintenance", async (client) => {
          const result = await client.query<{ removed_at: string | null }>(
            `select to_char(
               waitlist_private.remove_verified($1) at time zone 'UTC',
               'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
             ) as removed_at`,
            [email],
          );
          return result.rows[0]?.removed_at ?? null;
        }),
    };
    const first = await recordVerifiedRemoval({
      mailboxPossessionVerified: true,
      environment: "beta",
      email: " TARGET@example.com ",
      hmacKey: KEY,
      journal,
      maintenance,
    });
    const second = await recordVerifiedRemoval({
      mailboxPossessionVerified: true,
      environment: "beta",
      email: "target@example.com",
      hmacKey: KEY,
      journal,
      maintenance,
    });
    expect(first.status).toBe("recorded");
    expect(second.status).toBe("recorded");
    expect(journal.entries.size).toBe(1);
    expect(JSON.stringify([...journal.entries.values()])).not.toContain("target@example.com");

    const owner = await ownerClient();
    try {
      const rows = await owner.query<{ normalized_email: string }>(
        "select normalized_email from waitlist_private.provisional_submissions",
      );
      expect(rows.rows).toEqual([{ normalized_email: "keep@example.com" }]);
    } finally {
      await owner.end();
    }
  });

  it("journals an already-absent verified address using a database-owned timestamp", async () => {
    const journal = new MemoryJournal();
    const result = await recordVerifiedRemoval({
      mailboxPossessionVerified: true,
      environment: "production",
      email: "absent@example.com",
      hmacKey: KEY,
      journal,
      maintenance: {
        removeVerified: (email: string) =>
          asRole("waitlist_maintenance", async (client) => {
            const removed = await client.query<{ removed_at: string }>(
              `select to_char(
                 waitlist_private.remove_verified($1) at time zone 'UTC',
                 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
               ) as removed_at`,
              [email],
            );
            return removed.rows[0]?.removed_at ?? null;
          }),
      },
    });
    expect(result.status).toBe("recorded");
    expect(journal.entries.size).toBe(1);
    expect(JSON.stringify([...journal.entries.values()])).not.toContain("absent@example.com");
  });

  it("serializes concurrent submit and removal so only a genuinely newer row survives", async () => {
    for (let index = 0; index < 12; index += 1) {
      const email = `race-${index}@example.com`;
      const [removal] = await Promise.all([
        asRole("waitlist_maintenance", async (client) => {
          const result = await client.query<{ removed_at: string }>(
            "select waitlist_private.remove_verified($1)::text as removed_at",
            [email],
          );
          const timestamp = result.rows[0]?.removed_at;
          if (timestamp === undefined) throw new Error("missing removal timestamp");
          return timestamp;
        }),
        asRole("waitlist_runtime", (client) =>
          client.query("select waitlist_private.submit_provisional($1, $2)", [email, NOTICE]),
        ),
      ]);
      const owner = await ownerClient();
      try {
        const active = await owner.query<{ is_newer: boolean }>(
          `select submitted_at > $2::timestamptz as is_newer
           from waitlist_private.provisional_submissions where normalized_email = $1`,
          [email, removal],
        );
        const isNewer = active.rows[0]?.is_newer;
        if (isNewer !== undefined) {
          expect(isNewer).toBe(true);
        }
      } finally {
        await owner.end();
      }
    }
  });

  it("gates restore traffic, requires secure address input, removes stale rows, and preserves newer resubmission", async () => {
    const journal = new MemoryJournal();
    const deletedAt = new Date(Date.now() - 60_000).toISOString();
    const digest = denialDigest("target@example.com", "production", KEY);
    await journal.put({ version: "waitlist-denial-v1", environment: "production", digest, deletedAt });
    const maintenance = {
      replayDenial: (email: string, timestamp: string) =>
        asRole("waitlist_maintenance", async (client) => {
          const result = await client.query<{ replay_denial: string }>(
            "select waitlist_private.replay_denial($1, $2::timestamptz)",
            [email, timestamp],
          );
          return Number(result.rows[0]?.replay_denial ?? 0);
        }),
      purgeExpired: () =>
        asRole("waitlist_maintenance", async (client) => {
          const result = await client.query<{ purge_expired: string }>("select waitlist_private.purge_expired()");
          return Number(result.rows[0]?.purge_expired ?? 0);
        }),
    };
    await expect(
      replayVerifiedRemovals({ trafficGated: false, environment: "production", hmacKey: KEY, emails: [], journal, maintenance }),
    ).rejects.toThrow(/traffic must be gated/i);
    await expect(
      replayVerifiedRemovals({ trafficGated: true, environment: "production", hmacKey: KEY, emails: [], journal, maintenance }),
    ).rejects.toThrow(/secure replay input/i);

    const owner = await ownerClient();
    try {
      await owner.query(
        `insert into waitlist_private.provisional_submissions values ($1, $2, $3::timestamptz)`,
        ["target@example.com", NOTICE, new Date(Date.now() - 120_000).toISOString()],
      );
      await owner.query(
        `insert into waitlist_private.provisional_submissions values ($1, $2, clock_timestamp() - interval '23 months 30 days')`,
        ["expired@example.com", NOTICE],
      );
    } finally {
      await owner.end();
    }
    const stale = await replayVerifiedRemovals({
      trafficGated: true,
      environment: "production",
      hmacKey: KEY,
      emails: ["target@example.com"],
      journal,
      maintenance,
    });
    expect(stale).toEqual({ denialCount: 1, retentionCount: 1 });

    await asRole("waitlist_runtime", (runtime) =>
      runtime.query("select waitlist_private.submit_provisional($1, $2)", ["target@example.com", NOTICE]),
    );
    const newer = await replayVerifiedRemovals({
      trafficGated: true,
      environment: "production",
      hmacKey: KEY,
      emails: ["target@example.com"],
      journal,
      maintenance,
    });
    expect(newer).toEqual({ denialCount: 0, retentionCount: 0 });
    const inspect = await ownerClient();
    try {
      const rows = await inspect.query<{ normalized_email: string }>(
        "select normalized_email from waitlist_private.provisional_submissions",
      );
      expect(rows.rows).toEqual([{ normalized_email: "target@example.com" }]);
    } finally {
      await inspect.end();
    }
  });
});
