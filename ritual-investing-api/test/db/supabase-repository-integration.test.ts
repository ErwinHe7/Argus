import { readFile, readdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import pg from "pg";
import { describe, expect, it, vi } from "vitest";

import type {
  DatabaseClient,
  DatabasePool,
  DatabaseQueryResult,
} from "../../src/db/database-port.ts";
import {
  createVerifiedRequestClaims,
  type VerifiedRequestClaims,
} from "../../src/db/request-context.ts";
import {
  StaffAuthorizationError,
  withRequestTransaction,
  withStaffRequestTransaction,
} from "../../src/db/request-transaction.ts";
import {
  RETAINED_SUPABASE_RELATIONS,
  createSupabaseAccountRepository,
  createSupabaseAdminOperationsRepository,
  createSupabaseAdminRepository,
  createSupabaseAssetRepository,
  createSupabaseBriefingRepository,
  createSupabaseCircleRepository,
  createSupabaseCovenRepository,
  createSupabaseDiscoverRepository,
  createSupabaseEditorialRepository,
  createSupabaseMediaRepository,
  createSupabaseModerationRepository,
  createSupabaseNotificationRepository,
  createSupabasePrivacyRepository,
  createSupabasePublicPreviewRepository,
  createSupabaseRitualRepository,
  createSupabaseRowanRepository,
  createSupabaseSearchRepository,
  createSupabaseSessionRepository,
} from "../../src/db/supabase-repositories.ts";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const userA = "018f3c2a-4b67-7a89-8abc-123456789001";
const userB = "018f3c2a-4b67-7a89-8abc-123456789002";
const sessionA = "018f3c2a-4b67-7a89-8abc-123456789011";
const sessionB = "018f3c2a-4b67-7a89-8abc-123456789012";

type RecordedQuery = { text: string; values: readonly unknown[] };

function claims(
  userId = userA,
  sessionId = sessionA,
): VerifiedRequestClaims {
  return createVerifiedRequestClaims({ userId, sessionId, aal: "aal1" });
}

function recordingPool(
  respond: (text: string) => DatabaseQueryResult<any> = () => ({
    rows: [],
    rowCount: 0,
  }),
) {
  const queries: RecordedQuery[] = [];
  const release = vi.fn();
  const query = vi.fn(
    async <Row>(
      text: string,
      values: readonly unknown[] = [],
    ): Promise<DatabaseQueryResult<Row>> => {
      queries.push({ text, values });
      return respond(text) as DatabaseQueryResult<Row>;
    },
  );
  const client: DatabaseClient = {
    query: query as DatabaseClient["query"],
    release,
  };
  const pool: DatabasePool = {
    connect: vi.fn(async () => client),
    end: vi.fn(async () => undefined),
  };
  return { pool, queries, query, release };
}

describe("Supabase transaction-pooler repository boundary", () => {
  it("installs only verified JWT claims inside the owning transaction", async () => {
    const recorded = recordingPool();
    const verified = claims();

    await withRequestTransaction(
      { pool: recorded.pool, verifiedClaims: verified },
      async (database, context) => {
        expect(database).toBeDefined();
        expect(context).toEqual(verified);
        expect(Object.isFrozen(context)).toBe(true);
        return "ok";
      },
    );

    expect(recorded.queries.map(({ text }) => text)).toEqual([
      "begin",
      "set local role argus_runtime",
      "select argus_private.set_request_context($1::uuid, $2::uuid, $3::text)",
      "commit",
    ]);
    expect(recorded.queries[2]?.values).toEqual([userA, sessionA, "aal1"]);
    expect(recorded.release).toHaveBeenCalledOnce();
  });

  it("rolls back a multi-statement mutation and always releases the client", async () => {
    const recorded = recordingPool();

    await expect(
      withRequestTransaction(
        { pool: recorded.pool, verifiedClaims: claims() },
        async (database) => {
          await database.query("insert into argus_app.preferences values ($1)", [
            userA,
          ]);
          await database.query("insert into argus_private.outbox_events values ($1)", [
            userA,
          ]);
          throw new Error("constraint_failure");
        },
      ),
    ).rejects.toThrow("constraint_failure");

    const statements = recorded.queries.map(({ text }) => text);
    expect(statements).toContain("rollback");
    expect(statements).not.toContain("commit");
    expect(recorded.release).toHaveBeenCalledOnce();
  });

  it("does not allow client owner fields or mutable authorization claims", () => {
    expect(() =>
      createVerifiedRequestClaims({
        userId: userA,
        sessionId: sessionA,
        aal: "aal1",
        ownerId: userB,
      } as never),
    ).toThrow();

    const verified = claims();
    expect(() => {
      (verified as { userId: string }).userId = userB;
    }).toThrow();
    expect(verified.userId).toBe(userA);
  });

  it("rejects an owner override even when an unchecked object reaches the boundary", async () => {
    const recorded = recordingPool();
    await expect(
      withRequestTransaction(
        {
          pool: recorded.pool,
          verifiedClaims: {
            userId: userA,
            sessionId: sessionA,
            aal: "aal1",
            ownerId: userB,
          } as never,
        },
        async () => undefined,
      ),
    ).rejects.toThrow();
    expect(recorded.query).not.toHaveBeenCalled();
  });

  it("checks current staff permission inside the same claim-scoped transaction", async () => {
    const recorded = recordingPool();
    recorded.query.mockImplementation(
      (async (text: string) => ({
        rows: text.includes("has_staff_permission") ? [{ allowed: false }] : [],
        rowCount: 0,
      })) as never,
    );

    await expect(
      withStaffRequestTransaction(
        { pool: recorded.pool, verifiedClaims: claims() },
        "editorial.publish",
        async () => "not reached",
      ),
    ).rejects.toBeInstanceOf(StaffAuthorizationError);
    expect(recorded.query.mock.calls.map(([text]) => text)).toContain("rollback");
  });

  it("sets distinct transaction-local claims when a pooled client is reused", async () => {
    const recorded = recordingPool();

    await withRequestTransaction(
      { pool: recorded.pool, verifiedClaims: claims(userA, sessionA) },
      async () => undefined,
    );
    await withRequestTransaction(
      { pool: recorded.pool, verifiedClaims: claims(userB, sessionB) },
      async () => undefined,
    );

    const installations = recorded.queries.filter(({ text }) =>
      text.includes("set_request_context"),
    );
    expect(installations.map(({ values }) => values)).toEqual([
      [userA, sessionA, "aal1"],
      [userB, sessionB, "aal1"],
    ]);
  });

  it("writes the retained privacy request and outbox atomically in U2 schemas", async () => {
    const requestId = "018f3c2a-4b67-7a89-8abc-123456789041";
    const recorded = recordingPool((text) =>
      text.includes("insert into argus_app.privacy_requests")
        ? { rows: [{ id: requestId }], rowCount: 1 }
        : { rows: [], rowCount: 0 },
    );
    const repository = createSupabasePrivacyRepository({
      pool: recorded.pool,
      claims: claims(),
    });

    await expect(repository.request("export", "privacy-export-u14")).resolves.toEqual({
      id: requestId,
    });
    const statements = recorded.queries.map(({ text }) => text);
    expect(statements.some((text) => text.includes("argus_app.privacy_requests"))).toBe(true);
    expect(statements.some((text) => text.includes("argus_private.outbox_events"))).toBe(true);
    expect(statements.at(-1)).toBe("commit");
  });

  it("runs public preview without inventing a user claim", async () => {
    const recorded = recordingPool();
    const repository = createSupabasePublicPreviewRepository(recorded.pool);

    await expect(repository.listPublished("ritual", 10)).resolves.toEqual([]);
    expect(recorded.queries.map(({ text }) => text)).toEqual([
      "begin",
      "set local role argus_runtime",
      expect.stringContaining("argus_app.editorial_items"),
      "commit",
    ]);
    expect(recorded.queries.every(({ text }) => !text.includes("set_request_context"))).toBe(true);
  });

  it("maps every retained domain only to relations present in Supabase migrations", async () => {
    const migrationRoot = resolve(apiRoot, "../supabase/migrations");
    const migrations = (
      await Promise.all(
        (await readdir(migrationRoot))
          .filter((name) => name.endsWith(".sql"))
          .map((name) => readFile(join(migrationRoot, name), "utf8")),
      )
    ).join("\n");
    const acceptedSource = await readFile(
      resolve(apiRoot, "src/db/supabase-repositories.ts"),
      "utf8",
    );

    for (const [domain, relations] of Object.entries(
      RETAINED_SUPABASE_RELATIONS,
    )) {
      expect(relations.length, domain).toBeGreaterThan(0);
      for (const relation of relations) {
        expect(migrations, `${domain}:${relation}`).toMatch(
          new RegExp(`create table ${relation.replace(".", "\\.")}\\s*\\(`, "i"),
        );
      }
    }
    expect(acceptedSource).not.toMatch(
      /\britual_(?:private|public|catalog)\b|\b(?:from|join|update|into)\s+ritual\./i,
    );
    expect(acceptedSource).not.toMatch(/@neondatabase|cloudflare|Auth0|\bDeno\b/);
  });

  it("executes every relation declared for each retained domain", async () => {
    const genericId = "018f3c2a-4b67-7a89-8abc-123456789099";
    const recorded = recordingPool((text) => {
      if (text.includes("has_staff_permission")) {
        return { rows: [{ allowed: true }], rowCount: 1 };
      }
      if (text.includes("as snapshot")) {
        return {
          rows: [
            {
              snapshot: {
                member: {
                  user_id: userA,
                  status: "active",
                  deletion_epoch: 0,
                  deletion_requested_at: null,
                  created_at: "2026-08-28T00:00:00.000Z",
                  updated_at: "2026-08-28T00:00:00.000Z",
                },
                profile: null,
                preferences: null,
                onboarding: null,
                investor_profile: null,
                astrology_profile: null,
                server_time: "2026-08-28T00:00:00.000Z",
              },
            },
          ],
          rowCount: 1,
        };
      }
      if (text.includes("update argus_private.media_upload_intents")) {
        return {
          rows: [
            {
              bucket_id: "media-quarantine",
              object_path: "u14/coverage.webp",
              mime_type: "image/webp",
              max_bytes: 1024,
            },
          ],
          rowCount: 1,
        };
      }
      return {
        rows: [{ id: genericId, outbox_id: genericId }],
        rowCount: 1,
      };
    });
    const binding = { pool: recorded.pool, claims: claims() };
    const capture = async (run: () => Promise<unknown>) => {
      const start = recorded.queries.length;
      await run();
      return recorded.queries.slice(start).map(({ text }) => text).join("\n");
    };
    const evidenceIds = [genericId];
    const session = createSupabaseSessionRepository(binding);
    const accounts = createSupabaseAccountRepository(binding);
    const assets = createSupabaseAssetRepository(binding);
    const editorial = createSupabaseEditorialRepository(binding);
    const briefings = createSupabaseBriefingRepository(binding);
    const circles = createSupabaseCircleRepository(binding);
    const coven = createSupabaseCovenRepository(binding);
    const discover = createSupabaseDiscoverRepository(binding);
    const media = createSupabaseMediaRepository(binding);
    const moderation = createSupabaseModerationRepository(binding);
    const notifications = createSupabaseNotificationRepository(binding);
    const privacy = createSupabasePrivacyRepository(binding);
    const rituals = createSupabaseRitualRepository(binding);
    const rowan = createSupabaseRowanRepository(binding);
    const search = createSupabaseSearchRepository(binding);
    const admin = createSupabaseAdminRepository(binding);
    const adminOperations = createSupabaseAdminOperationsRepository(binding);
    const preview = createSupabasePublicPreviewRepository(recorded.pool);

    const executedByDomain: Record<string, string> = {
      session: await capture(() => session.bootstrap()),
      accounts: await capture(async () => {
        await accounts.get();
        await accounts.recordConsent({
          policyCode: "privacy",
          policyVersion: "v1",
          decision: "accepted",
        });
      }),
      assets: await capture(async () => {
        await assets.list(10);
        await assets.listEvidence(evidenceIds);
      }),
      editorial: await capture(async () => {
        await editorial.listPublished("ritual", 10);
        await editorial.listEvidence(evidenceIds);
      }),
      briefings: await capture(() => briefings.get(genericId)),
      circles: await capture(async () => {
        await circles.get(genericId);
        await circles.listSaved(10);
      }),
      coven: await capture(() => coven.list(10)),
      discover: await capture(async () => {
        await discover.listAssets(10);
        await discover.listGrimoires(10);
        await discover.listCircleTemplates(10);
      }),
      media: await capture(async () => {
        await media.getUploadIntent(genericId);
        await media.finalizeUpload(genericId, 512, "a".repeat(64));
      }),
      moderation: await capture(async () => {
        await moderation.report({
          targetKind: "editorial",
          targetId: genericId,
          reasonCode: "incorrect",
        });
        await moderation.decide(
          genericId,
          1,
          { status: "actioned" },
          genericId,
        );
      }),
      notifications: await capture(async () => {
        await notifications.list(10);
        await notifications.getPreferences();
      }),
      privacy: await capture(async () => {
        await privacy.request("export", "u14-coverage-export");
        await privacy.getDeletionTombstone();
      }),
      publicPreview: await capture(() => preview.listPublished("ritual", 10)),
      rituals: await capture(async () => {
        await rituals.get(genericId);
        await rituals.getSchedule("2026-08-28", "tarot");
        await rituals.getScenario(genericId);
      }),
      rowan: await capture(() => rowan.resolve("daily_ritual", "daily")),
      search: await capture(() => search.search("argus", 10)),
      admin: await capture(async () => {
        await admin.getStaffPrincipal();
        await admin.listAudit(10);
        await admin.listEditorial(10);
      }),
      adminOperations: await capture(async () => {
        await adminOperations.listJobs(10);
        await adminOperations.listPrivacy(10);
        await adminOperations.listAudit(10);
      }),
    };

    for (const [domain, relations] of Object.entries(
      RETAINED_SUPABASE_RELATIONS,
    )) {
      const executedSql = executedByDomain[domain];
      expect(executedSql, `${domain} has executable repository evidence`).toBeDefined();
      for (const relation of relations) {
        expect(executedSql, `${domain} executes ${relation}`).toContain(relation);
      }
    }
  });

  it("defines a retained Supabase session model without deleted Demo authority", async () => {
    const source = await readFile(
      resolve(apiRoot, "src/domains/session/supabase-schemas.ts"),
      "utf8",
    );
    expect(source).not.toMatch(/entitlement|portfolio|reset_generation|is_demo/i);
    expect(source).toMatch(/member|preferences|onboarding|investor_profile/);
  });

  it("keeps portable database and retained repository modules runtime-neutral", async () => {
    const retained = [
      "src/db/database-port.ts",
      "src/db/request-context.ts",
      "src/db/request-transaction.ts",
      "src/db/supabase-repositories.ts",
      "src/domains/session/supabase-schemas.ts",
      "src/ports/infrastructure.ts",
    ].map((path) => resolve(apiRoot, path));
    const forbidden =
      /(?:from|import\()\s*["'][^"']*(?:@neondatabase|drizzle-orm\/neon|cloudflare|wrangler|supabase\/functions)|\bDeno\.|\bR2(?:Bucket|Object)\b/i;

    const acceptedSources: string[] = [];
    for (const path of retained) {
      const source = await readFile(path, "utf8");
      acceptedSources.push(source);
      expect(source, path).not.toMatch(forbidden);
      expect(source, path).not.toMatch(/from\s*["']\.\/client(?:\.ts)?["']/i);
    }

    const legacyNeon = await readFile(resolve(apiRoot, "src/db/client.ts"), "utf8");
    expect(legacyNeon).toMatch(/@neondatabase\/serverless/);
    expect(legacyNeon).toMatch(/withScopedRuntimeClient/);
    expect(acceptedSources.join("\n")).not.toMatch(/ritual_identity_resolver|ritual_runtime/);
  });
});

const supabaseDatabaseUrl = process.env.SUPABASE_DB_URL;

describe.skipIf(supabaseDatabaseUrl === undefined)(
  "live Supabase transaction-pooler claims",
  () => {
    it("scopes auth.uid to one transaction and recovers the pooled client after rollback", async () => {
      const nodePool = new pg.Pool({
        connectionString: supabaseDatabaseUrl,
        max: 1,
      });
      const pool: DatabasePool = {
        connect: async () =>
          (await nodePool.connect()) as unknown as DatabaseClient,
        end: () => nodePool.end(),
      };
      try {
        const first = await withRequestTransaction(
          { pool, verifiedClaims: claims(userA, sessionA) },
          async (database) =>
            database.query<{ user_id: string }>(
              "select auth.uid()::text as user_id",
            ),
        );
        expect(first.rows[0]?.user_id).toBe(userA);

        await expect(
          withRequestTransaction(
            { pool, verifiedClaims: claims(userB, sessionB) },
            async (database) => database.query("select 1 / 0"),
          ),
        ).rejects.toThrow();

        const recovered = await withRequestTransaction(
          { pool, verifiedClaims: claims(userB, sessionB) },
          async (database) =>
            database.query<{ user_id: string }>(
              "select auth.uid()::text as user_id",
            ),
        );
        expect(recovered.rows[0]?.user_id).toBe(userB);
      } finally {
        await pool.end();
      }
    });
  },
);
