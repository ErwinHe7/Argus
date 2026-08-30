import { readFile, readdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import pg from "pg";
import { describe, expect, expectTypeOf, it, vi } from "vitest";

import type {
  DatabaseClient,
  DatabasePool,
  DatabaseQueryResult,
  DatabaseTransaction,
} from "../../src/db/database-port.ts";
import {
  createVerifiedRequestClaims,
  type VerifiedRequestClaims,
} from "../../src/db/request-context.ts";
import {
  StaffAuthorizationError,
  withActiveCapabilityStaffRequestTransaction,
  withActiveStaffRequestTransaction,
  withAnonymousRequestTransaction,
  withMemberRequestTransaction,
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
  createSupabaseStarpathRepository,
} from "../../src/db/supabase-repositories.ts";
import { createSupabaseScenarioRepository } from "../../src/domains/intentions/repository.ts";
import {
  createPrivacyRequestService,
  type PrivacySignedStorage,
} from "../../src/domains/privacy/service.ts";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const userA = "018f3c2a-4b67-7a89-8abc-123456789001";
const userB = "018f3c2a-4b67-7a89-8abc-123456789002";
const sessionA = "018f3c2a-4b67-7a89-8abc-123456789011";
const sessionB = "018f3c2a-4b67-7a89-8abc-123456789012";
const validOnboardingFinalizationInput = {
  expectedOnboardingVersion: 1,
  investing: {
    goalType: "long_term_growth",
    timeHorizon: "long",
    riskComfort: "moderate",
  },
  astrology: { enabled: false },
  consents: {},
} as const;

type RecordedQuery = { text: string; values: readonly unknown[] };

function claims(
  userId = userA,
  sessionId = sessionA,
): VerifiedRequestClaims {
  return createVerifiedRequestClaims({ userId, sessionId, aal: "aal1" });
}

function recordingPool(
  respond: (
    text: string,
    values: readonly unknown[],
  ) => DatabaseQueryResult<any> = () => ({
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
      return respond(text, values) as DatabaseQueryResult<Row>;
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
  const database: DatabaseTransaction = { query: client.query };
  return { pool, database, queries, query, release };
}

function accountProjection(deletionEpoch: number | string = 0) {
  return {
    status: "active",
    deletion_epoch: deletionEpoch,
    profile: {
      user_id: userA,
      deletion_epoch: 0,
      display_name: "Ritual Member",
      avatar_media_id: null,
      locale: "en-US",
      updated_at: "2026-08-29T12:00:00.000Z",
    },
    preferences: {
      user_id: userA,
      deletion_epoch: 0,
      theme_mode: "system",
      ritual_mode: "tarot",
      timezone: "America/New_York",
      locale: "en-US",
      version: 1,
    },
    onboarding: {
      user_id: userA,
      deletion_epoch: 0,
      current_step: "complete",
      completed_steps: ["profile"],
      completed_at: "2026-08-29T12:00:00.000Z",
      version: 1,
    },
    investor_profile: null,
    astrology_profile: null,
  };
}

function ritualProjection(
  id = "018f3c2a-4b67-7a89-8abc-123456789021",
) {
  return {
    id,
    user_id: userA,
    deletion_epoch: "0",
    local_date: "2026-08-29",
    mode: "tarot",
    schedule_id: "018f3c2a-4b67-7a89-8abc-123456789022",
    revision_id: "018f3c2a-4b67-7a89-8abc-123456789023",
    rowan_revision_id: null,
    state: "assigned",
    revealed_at: null,
    completed_at: null,
    version: 1,
    payload: {
      title: "The Compass",
      interpretation: "Direction, not urgency.",
      guidance: "Compare the evidence.",
      market_label: "Market-informed",
      uncertainty: "Markets can change.",
    },
    body_template: null,
    allowed_tokens: null,
    risk_footer: null,
  };
}

function privacyService(
  pool: DatabasePool,
  verifiedClaims: VerifiedRequestClaims,
  signedStorage: PrivacySignedStorage = {
    createSignedUrl: async () => {
      throw new Error("storage_not_configured");
    },
    getStream: async () => {
      throw new Error("storage_not_configured");
    },
  },
  now?: () => number,
) {
  return createPrivacyRequestService({
    claims: verifiedClaims,
    withMemberTransaction: (callback) =>
      withMemberRequestTransaction(
        { pool, verifiedClaims },
        callback,
      ),
    repository: createSupabasePrivacyRepository,
    signedStorage,
    ...(now === undefined ? {} : { now }),
  });
}

describe("Supabase transaction-pooler repository boundary", () => {
  it("uses a PostgreSQL-safe structured advisory lock key for onboarding finalization", async () => {
    const stopAfterLock = new Error("stop_after_lock");
    const recorded = recordingPool((text) => {
      if (text.includes("pg_advisory_xact_lock")) throw stopAfterLock;
      return { rows: [], rowCount: 0 };
    });
    const session = createSupabaseSessionRepository(recorded.database, userA);
    const idempotencyKey = "onboarding-finalize-test";

    await expect(
      session.finalizeOnboarding(
        validOnboardingFinalizationInput,
        idempotencyKey,
      ),
    ).rejects.toBe(stopAfterLock);

    const lockQuery = recorded.queries.find(({ text }) =>
      text.includes("pg_advisory_xact_lock")
    );
    expect(lockQuery?.values).toEqual([
      JSON.stringify([userA, "onboarding.finalize", idempotencyKey]),
    ]);
  });

  it("keeps the onboarding finalization response inside the runtime role grant", async () => {
    const completedAt = "2026-08-29T12:00:00.000Z";
    const recorded = recordingPool((text) => {
      if (text.includes("select request_hash,response_status")) {
        return { rows: [], rowCount: 0 };
      }
      if (text.includes("select version,completed_at")) {
        return { rows: [{ version: 1, completed_at: null }], rowCount: 1 };
      }
      if (text.includes("jsonb_build_object")) {
        return {
          rows: [{
            snapshot: {
              member: {
                user_id: userA,
                status: "active",
                deletion_epoch: 0,
                deletion_requested_at: null,
                created_at: completedAt,
                updated_at: completedAt,
              },
              profile: null,
              preferences: null,
              onboarding: {
                user_id: userA,
                deletion_epoch: 0,
                current_step: "complete",
                completed_steps: ["investing", "ritual", "astrology", "consents"],
                completed_at: completedAt,
                version: 2,
              },
              investor_profile: {},
              astrology_profile: null,
              server_time: completedAt,
            },
          }],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 0 };
    });

    const completed = await createSupabaseSessionRepository(
      recorded.database,
      userA,
    ).finalizeOnboarding(
      validOnboardingFinalizationInput,
      "onboarding-finalize-runtime-grant",
    );

    expect(completed.onboarding?.completed_at).toBe(completedAt);
    const responseQuery = recorded.queries.find(({ text }) =>
      text.includes("jsonb_build_object")
    );
    expect(responseQuery?.text).not.toContain("argus_app.profiles");
    expect(responseQuery?.text).not.toContain("argus_app.preferences");
  });

  it("normalizes the account deletion epoch before returning the API projection", async () => {
    const recorded = recordingPool((text) => {
      if (
        !text.includes("from argus_app.members member") ||
        !text.includes("left join argus_app.profiles profile")
      ) {
        return { rows: [], rowCount: 0 };
      }
      return {
        rows: [accountProjection("0")],
        rowCount: 1,
      };
    });

    const account = await createSupabaseAccountRepository(recorded.database)
      .get();

    expect(account.deletion_epoch).toBe(0);
  });

  it("creates one local-day ritual assignment on first read and reuses it", async () => {
    const assignmentId = "018f3c2a-4b67-7a89-8abc-123456789021";
    let assignment: Record<string, unknown> | undefined;
    const recorded = recordingPool((text) => {
      if (text.includes("insert into argus_app.daily_ritual_assignments")) {
        if (assignment !== undefined) {
          if (!text.includes("on conflict (user_id,local_date,mode) do nothing")) {
            throw new Error("duplicate key value violates unique constraint");
          }
          return { rows: [], rowCount: 0 };
        }
        assignment = ritualProjection(assignmentId);
        return { rows: [], rowCount: 1 };
      }
      if (text.includes("from argus_app.daily_ritual_assignments assignment")) {
        return {
          rows: assignment === undefined
            ? []
            : text.includes("as projection")
              ? [{ projection: assignment }]
              : [assignment],
          rowCount: assignment === undefined ? 0 : 1,
        };
      }
      return { rows: [], rowCount: 0 };
    });
    const rituals = createSupabaseRitualRepository(recorded.database);

    const first = await rituals.getDaily("tarot");
    const repeated = await rituals.getDaily("tarot");

    expect(first?.id).toBe(assignmentId);
    expect(first?.deletion_epoch).toBe(0);
    expect(repeated?.id).toBe(assignmentId);
  });

  it("replaces the legacy demo ritual with the content for the drawn card", async () => {
    const legacy = {
      ...ritualProjection(),
      payload: {
        title: "The Compass",
        art_key: "the_compass",
        art_alt: "A compass card inviting deliberate research",
        interpretation: "Direction matters more than urgency.",
        guidance: "Compare the evidence and decide what deserves a closer look.",
        market_label: "Market-informed Demo",
        uncertainty: "Synthetic educational context can differ from current markets.",
        ideas: [{ symbol: "VIG" }],
        evidence: [{ factor_label: "Synthetic fixture" }],
      },
    };
    const recorded = recordingPool((text) => {
      if (text.includes("from argus_app.daily_ritual_assignments assignment")) {
        return { rows: [{ projection: legacy }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    });

    const result = await createSupabaseRitualRepository(recorded.database)
      .getDaily("tarot");

    expect(result?.payload).toMatchObject({
      title: "Death",
      art_key: "death",
      art_alt: "Death tarot card: a skeletal rider advances on a white horse at sunrise",
      interpretation:
        "Death marks a necessary ending: a pattern has run its course, creating room for a cleaner beginning.",
      guidance:
        "Name one assumption you are ready to release. Write down the evidence that would show an old thesis no longer fits.",
      market_label: "Tarot reflection",
      ideas: [],
      evidence: [],
    });
    expect(result?.body_template).toBe(
      "Let the ending be information, not catastrophe. Clearing an expired story can make your next question more honest.",
    );
    expect(result?.risk_footer).toBe(
      "Tarot is a reflection tool, not a prediction or financial recommendation.",
    );
    expect(JSON.stringify(result)).not.toMatch(/compass|demo|synthetic/i);
  });

  it("returns the complete ritual projection after a lifecycle transition", async () => {
    const assignmentId = "018f3c2a-4b67-7a89-8abc-123456789021";
    const revealed = {
      ...ritualProjection(assignmentId),
      state: "revealed",
      revealed_at: "2026-08-29T22:58:52.722457+00:00",
      version: 2,
    };
    const recorded = recordingPool((text) => {
      if (text.includes("update argus_app.daily_ritual_assignments")) {
        return { rows: [{ id: assignmentId }], rowCount: 1 };
      }
      if (text.includes("as projection")) {
        return { rows: [{ projection: revealed }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    });

    const result = await createSupabaseRitualRepository(
      recorded.database,
    ).transition(assignmentId, "assigned", "revealed", 1);

    expect(result).toEqual({ ...revealed, deletion_epoch: 0 });
  });

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
      "select argus_private.install_request_context($1::uuid, $2::uuid, $3::text)",
      "set local role argus_runtime",
      "commit",
    ]);
    expect(recorded.queries[1]?.values).toEqual([userA, sessionA, "aal1"]);
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

  it("exposes only guarded queries to repositories", async () => {
    const recorded = recordingPool();

    await withRequestTransaction(
      { pool: recorded.pool, verifiedClaims: claims() },
      async (database) => {
        expectTypeOf(database).not.toHaveProperty("release");
        expect("release" in database).toBe(false);
        await expect(database.query("commit")).rejects.toThrow(
          "nested_transaction_control_forbidden",
        );
        await expect(database.query("reset role")).rejects.toThrow(
          "nested_transaction_control_forbidden",
        );
        await expect(database.query("select 1; commit")).rejects.toThrow(
          "nested_transaction_control_forbidden",
        );
        await expect(database.query("/* repository */ end")).rejects.toThrow(
          "nested_transaction_control_forbidden",
        );
      },
    );

    expect(recorded.queries.map(({ text }) => text)).toEqual([
      "begin",
      "select argus_private.install_request_context($1::uuid, $2::uuid, $3::text)",
      "set local role argus_runtime",
      "commit",
    ]);
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
        rows: text.includes("has_live_staff_session")
          ? [{ live: true }]
          : text.includes("has_staff_permission")
            ? [{ allowed: false }]
            : [],
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

  it("rejects a stale JWT on a staff read after its Supabase session is deleted", async () => {
    const recorded = recordingPool((text) => ({
      rows: text.includes("has_live_staff_session") ? [{ live: false }] : [],
      rowCount: 0,
    }));
    const read = vi.fn(async () => "not reached");

    await expect(
      withActiveStaffRequestTransaction(
        { pool: recorded.pool, verifiedClaims: claims() },
        read,
      ),
    ).rejects.toBeInstanceOf(StaffAuthorizationError);
    expect(read).not.toHaveBeenCalled();
  });

  it("rejects a stale JWT on a staff write before current-role evaluation", async () => {
    const recorded = recordingPool((text) => ({
      rows: text.includes("has_live_staff_session") ? [{ live: false }] : [],
      rowCount: 0,
    }));
    const write = vi.fn(async () => "not reached");

    await expect(
      withStaffRequestTransaction(
        { pool: recorded.pool, verifiedClaims: claims() },
        "editorial:write",
        write,
      ),
    ).rejects.toBeInstanceOf(StaffAuthorizationError);
    expect(write).not.toHaveBeenCalled();
    expect(
      recorded.queries.some(({ text }) => text.includes("has_staff_permission")),
    ).toBe(false);
  });

  it("commits a high-trust self-approval denial audit before returning 403", async () => {
    const itemId = "018f3c2a-4b67-7a89-8abc-123456789090";
    const revisionId = "018f3c2a-4b67-7a89-8abc-123456789091";
    const recorded = recordingPool((text) => {
      if (text.includes("has_live_staff_session")) {
        return { rows: [{ live: true }], rowCount: 1 };
      }
      if (text.includes("has_staff_permission")) {
        return { rows: [{ allowed: true }], rowCount: 1 };
      }
      if (text.includes("select review.id,revision.author_staff_id")) {
        return {
          rows: [{ id: itemId, author_staff_id: userA, high_trust: true }],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 1 };
    });
    const result = await withActiveCapabilityStaffRequestTransaction(
      { pool: recorded.pool, verifiedClaims: claims() },
      async (database, actor) =>
        createSupabaseAdminRepository(database, actor).commandEditorial(
          "approve",
          itemId,
          revisionId,
          "Author cannot approve this high-trust revision.",
          true,
          "018f3c2a-4b67-7a89-8abc-123456789092",
        ),
    );
    expect(result).toEqual({ _denied: "self_approval" });

    const statements = recorded.queries.map(({ text }) => text);
    expect(statements.some((text) => text.includes("admin_audit_events"))).toBe(true);
    expect(statements.some((text) => text.includes("editorial_review_decisions"))).toBe(false);
    expect(statements).toContain("set local role argus_staff");
    const editorialAudit = statements.find((text) =>
      text.includes("admin_audit_events")
    );
    expect(editorialAudit).toContain("argus_private.trusted_request_user_id()");
    expect(editorialAudit).not.toMatch(
      /argus_private\.(?!trusted_)request_user_id\(\)/,
    );
    expect(statements).toContain("commit");
    expect(statements).not.toContain("rollback");
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
      text.includes("install_request_context"),
    );
    expect(installations.map(({ values }) => values)).toEqual([
      [userA, sessionA, "aal1"],
      [userB, sessionB, "aal1"],
    ]);
  });

  it("writes the retained privacy request and outbox through one U6 capability", async () => {
    const requestId = "018f3c2a-4b67-7a89-8abc-123456789041";
    const recorded = recordingPool((text) => {
      if (text.includes("request_privacy_export")) {
        return { rows: [{ id: requestId }], rowCount: 1 };
      }
      if (text.includes("list_member_privacy_requests")) {
        return { rows: [{ id: requestId }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    });
    const service = privacyService(recorded.pool, claims());

    await expect(service.request("export", "privacy-export-u14")).resolves.toEqual({
      id: requestId,
    });
    const statements = recorded.queries.map(({ text }) => text);
    expect(statements).toContain(
      "select argus_private.request_privacy_export($1) as id",
    );
    expect(statements.some((text) => /(?:insert|update|delete)\s/i.test(text))).toBe(false);
    expect(statements.at(-1)).toBe("commit");
  });

  it("replays an export idempotency key without creating a second request", async () => {
    const requestId = "018f3c2a-4b67-7a89-8abc-123456789041";
    const recorded = recordingPool((text) => {
      if (text.includes("request_privacy_export")) {
        return { rows: [{ id: requestId }], rowCount: 1 };
      }
      if (text.includes("list_member_privacy_requests")) {
        return { rows: [{ id: requestId }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    });
    const service = privacyService(recorded.pool, claims());
    await expect(service.request("export", "privacy-export-replay")).resolves
      .toEqual({ id: requestId });
    expect(recorded.queries.filter(({ text }) =>
      text.includes("request_privacy_export")
    )).toHaveLength(1);
  });

  it("scopes export idempotency by owner before the globally unique outbox key", async () => {
    const keys = new Set<string>();
    let created = 0;
    const recorded = recordingPool((text, values) => {
      if (text.includes("request_privacy_export")) {
        created += 1;
        keys.add(String(values[0]));
        return {
          rows: [{ id: created === 1
            ? "018f3c2a-4b67-7a89-8abc-123456789041"
            : "018f3c2a-4b67-7a89-8abc-123456789042" }],
          rowCount: 1,
        };
      }
      if (text.includes("list_member_privacy_requests")) {
        return {
          rows: [{ id: created === 1
            ? "018f3c2a-4b67-7a89-8abc-123456789041"
            : "018f3c2a-4b67-7a89-8abc-123456789042" }],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 0 };
    });
    await privacyService(recorded.pool, claims(userA))
      .request("export", "same-client-key-across-users");
    await privacyService(recorded.pool, claims(userB, sessionB))
      .request("export", "same-client-key-across-users");
    expect([...keys]).toHaveLength(2);
    expect([...keys].every((key) => /^privacy-export:[a-f0-9]{64}$/.test(key))).toBe(true);
    expect([...keys].join(" ")).not.toContain("same-client-key-across-users");
  });

  it("mints a bounded privacy URL without returning object coordinates", async () => {
    let now = 1_000;
    const nowSpy = vi.spyOn(Date, "now").mockImplementation(() => now);
    const signed = vi.fn(async () => {
      now = 11_000; // Signing latency cannot extend the advertised lifetime.
      return "https://project.supabase.co/storage/v1/object/sign/token";
    });
    const recorded = recordingPool((text) => {
      if (text.includes("prepare_privacy_export_download")) {
        return {
          rows: [{
            access_lease_id: "018f3c2a-4b67-7a89-8abc-123456789043",
            bucket_id: "privacy-exports",
            object_path: `${userA}/export.zip`,
            expires_in_seconds: 30,
          }],
          rowCount: 1,
        };
      }
      if (text.includes("confirm_privacy_export_download")) {
        return { rows: [{ current: true }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    });
    const service = privacyService(
      recorded.pool,
      claims(),
      {
        createSignedUrl: signed,
        getStream: async () => null,
      },
      () => 1_000,
    );
    const result = await service.createDownloadUrl(
      "018f3c2a-4b67-7a89-8abc-123456789041",
    );
    expect(signed).toHaveBeenCalledWith("privacy-exports", `${userA}/export.zip`, 30);
    expect(result).toEqual({
      url: "https://project.supabase.co/storage/v1/object/sign/token",
      expires_at: new Date(31_000).toISOString(),
    });
    expect(JSON.stringify(result)).not.toContain("export.zip");
    expect(recorded.queries.map(({ text }) => text)).toContain(
      "select argus_private.confirm_privacy_export_download($1) as current",
    );
    nowSpy.mockRestore();
  });

  it("persists briefing read state and joins it into subsequent owner reads", async () => {
    const briefingId = "018f3c2a-4b67-7a89-8abc-123456789061";
    const recorded = recordingPool((text) => {
      if (text.includes("with target as materialized")) {
        return {
          rows: [{
            id: briefingId,
            briefing_type: "daily",
            period_start: "2026-08-28",
            period_end: "2026-08-28",
            generated_at: "2026-08-28T12:00:00.000Z",
            generation: 1,
            source_sequence: 1,
            read_at: "2026-08-28T16:30:00.000Z",
          }],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 0 };
    });
    await withMemberRequestTransaction(
      { pool: recorded.pool, verifiedClaims: claims() },
      async (database) => {
        const repository = createSupabaseBriefingRepository(database);
        await expect(repository.setRead(briefingId, true)).resolves.toMatchObject({
          id: briefingId,
          read_at: "2026-08-28T16:30:00.000Z",
        });
        await repository.list(20);
        await repository.get(briefingId);
      },
    );

    const mutation = recorded.queries.find(({ text }) =>
      text.includes("insert into argus_app.briefing_read_states")
    );
    expect(mutation?.text).toContain("on conflict (user_id,briefing_id) do update");
    expect(mutation?.text).toContain("delete from argus_app.briefing_read_states");
    expect(mutation?.values).toEqual([briefingId, true]);
    const directReads = recorded.queries.filter(({ text }) =>
      text.includes("left join argus_app.briefing_read_states")
    );
    expect(directReads).toHaveLength(1);
    expect(directReads.every(({ text }) =>
      text.includes("read_state.deletion_epoch=briefing.deletion_epoch")
    )).toBe(true);
    expect(directReads.every(({ text }) =>
      text.includes("briefing.status='ready'")
    )).toBe(true);
    expect(directReads.every(({ text }) =>
      text.includes("argus_private.trusted_request_user_id()")
    )).toBe(true);
    expect(recorded.queries.some(({ text }) =>
      text.includes("argus_private.list_member_briefings_page")
    )).toBe(true);
    expect(recorded.queries.map(({ text }) => text)).toContain(
      "set local role argus_member",
    );
  });

  it("routes deletion through the action-bound Supabase definer function", async () => {
    const requestId = "018f3c2a-4b67-7a89-8abc-123456789041";
    const receipt = "R".repeat(43);
    const recorded = recordingPool((text) =>
      text.includes("begin_member_deletion") ||
        text.includes("list_member_privacy_requests")
        ? { rows: [{ id: requestId }], rowCount: 1 }
        : { rows: [], rowCount: 0 }
    );
    const service = privacyService(recorded.pool, claims());
    await expect(service.request(
      "deletion",
      "privacy-delete-idempotency",
      receipt,
    )).resolves.toEqual({ id: requestId });
    const invocation = recorded.queries.find(({ text }) =>
      text.includes("begin_member_deletion")
    );
    expect(invocation?.values[0]).toMatch(/^[a-f0-9]{64}$/);
    expect(invocation?.values).not.toContain(receipt);
    expect(invocation?.values[1]).toBe(sessionA);
  });

  it("runs public preview without inventing a user claim", async () => {
    const recorded = recordingPool();
    await expect(
      withAnonymousRequestTransaction(recorded.pool, (database) =>
        createSupabasePublicPreviewRepository(database).listPublished(
          "ritual",
          10,
        )),
    ).resolves.toEqual([]);
    expect(recorded.queries.map(({ text }) => text)).toEqual([
      "begin",
      "set local role argus_public_preview",
      expect.stringContaining("argus_private.list_current_published_editorial"),
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

    const scenarioSource = await readFile(
      resolve(apiRoot, "src/domains/intentions/repository.ts"),
      "utf8",
    );
    expect(scenarioSource).toContain("argus_private.trusted_request_user_id()");
    expect(scenarioSource).not.toMatch(
      /argus_private\.(?!trusted_)request_user_id\(\)/,
    );
  });

  it("executes every relation declared for each retained domain", async () => {
    const genericId = "018f3c2a-4b67-7a89-8abc-123456789099";
    let scenarioRequestHash = "";
    const recorded = recordingPool((text, values = []) => {
      if (text.includes("clock_timestamp() as now")) {
        return { rows: [{ now: "2026-08-30T12:00:00.000Z" }], rowCount: 1 };
      }
      if (text.includes("resolve_starpath_member_authority")) {
        return {
          rows: [{ authority: {
            manifestId: genericId,
            manifestVersion: "starpath-beta-v1",
            policyVersion: "starpath-no-advice-v1",
            environment: "beta",
            jurisdiction: "US",
            themeId: genericId,
          } }],
          rowCount: 1,
        };
      }
      if (
        text.includes("read_starpath_state") ||
        text.includes("start_or_resume_starpath_session") ||
        text.includes("answer_starpath_question") ||
        text.includes("skip_starpath_recall")
      ) {
        return {
          rows: [{ state: { availability: "not_started" } }],
          rowCount: 1,
        };
      }
      if (text.includes("read_starpath_curriculum_projection")) {
        return { rows: [{ projection: {} }], rowCount: 1 };
      }
      if (text.includes("select event_type,aggregate_id")) {
        return { rows: [], rowCount: 0 };
      }
      if (text.includes("select user_id from argus_app.members")) {
        return { rows: [{ user_id: userA }], rowCount: 1 };
      }
      if (text.includes("has_live_staff_session")) {
        return { rows: [{ live: true }], rowCount: 1 };
      }
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
      if (
        text.includes("from argus_app.members member") &&
        text.includes("left join argus_app.profiles profile")
      ) {
        return { rows: [accountProjection()], rowCount: 1 };
      }
      if (
        text.includes("from argus_app.daily_ritual_assignments assignment") &&
        text.includes("as projection")
      ) {
        return {
          rows: [{ projection: ritualProjection(genericId) }],
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
      if (text.includes("insert into argus_private.member_idempotency_records")) {
        scenarioRequestHash = String(values[3]);
        return { rows: [], rowCount: 1 };
      }
      if (text.includes("from argus_private.member_idempotency_records")) {
        return {
          rows: [{
            deletion_epoch: "0",
            request_hash: scenarioRequestHash,
            resource_id: genericId,
          }],
          rowCount: 1,
        };
      }
      if (text.includes("select deletion_epoch::text") && text.includes("argus_app.members")) {
        return { rows: [{ deletion_epoch: "0" }], rowCount: 1 };
      }
      if (text.includes("jsonb_build_object") && text.includes("argus_app.intentions")) {
        return {
          rows: [{
            id: genericId,
            title: "Member intention",
            target: { minor_units: "250000", currency: "USD" },
            target_date: "2028-08-28",
            status: "active",
            version: 1,
            created_at: "2026-08-28T00:00:00.000Z",
          }],
          rowCount: 1,
        };
      }
      if (text.includes("from argus_app.future_mirror_runs run")) {
        return {
          rows: [{
            id: genericId,
            intention_id: genericId,
            input_hash: "a".repeat(64),
            model_version: "argus-hypothetical-v1",
            assumption_version: "member-reviewed-v1",
            assumptions: {
              input: {
                name: "Steady path",
                baseline: { minor_units: "100000", currency: "USD" },
                monthly_contribution: { minor_units: "1000", currency: "USD" },
                annual_return_bps: { low: -1000, mid: 400, high: 1800 },
                as_of_date: "2026-08-28",
              },
              intention_snapshot: { target_date: "2028-08-28", currency: "USD" },
            },
            generated_at: "2026-08-28T00:00:00.000Z",
            uncertainty_disclosure:
              "This is a hypothetical scenario based only on member-entered assumptions and is not advice or a forecast.",
          }],
          rowCount: 1,
        };
      }
      if (text.includes("from argus_app.future_mirror_points")) {
        return {
          rows: [{
            ordinal: 1,
            projected_date: "2026-09-28",
            low_amount_minor: "100000",
            mid_amount_minor: "101000",
            high_amount_minor: "102000",
          }],
          rowCount: 1,
        };
      }
      return {
        rows: [{ id: genericId, outbox_id: genericId }],
        rowCount: 1,
      };
    });
    const capture = async (run: () => Promise<unknown>) => {
      const start = recorded.queries.length;
      await run();
      return recorded.queries.slice(start).map(({ text }) => text).join("\n");
    };
    const captureAttempt = async (run: () => Promise<unknown>) => {
      const start = recorded.queries.length;
      await run().catch(() => undefined);
      return recorded.queries.slice(start).map(({ text }) => text).join("\n");
    };
    const evidenceIds = [genericId];
    const database = recorded.database;
    const session = createSupabaseSessionRepository(database, userA);
    const accounts = createSupabaseAccountRepository(database);
    const assets = createSupabaseAssetRepository(database);
    const editorial = createSupabaseEditorialRepository(database);
    const briefings = createSupabaseBriefingRepository(database);
    const circles = createSupabaseCircleRepository(database);
    const coven = createSupabaseCovenRepository(database);
    const discover = createSupabaseDiscoverRepository(database);
    const media = createSupabaseMediaRepository(database);
    const moderation = createSupabaseModerationRepository(database);
    const notifications = createSupabaseNotificationRepository(database);
    const privacy = createSupabasePrivacyRepository(database);
    const rituals = createSupabaseRitualRepository(database);
    const rowan = createSupabaseRowanRepository(database);
    const search = createSupabaseSearchRepository(database);
    const admin = createSupabaseAdminRepository(database, claims());
    const adminOperations = createSupabaseAdminOperationsRepository(
      database,
      sessionA,
    );
    const scenarios = createSupabaseScenarioRepository(database);
    const preview = createSupabasePublicPreviewRepository(database);
    const starpathMember = createSupabaseStarpathRepository(database, {
      evaluate: async () => ({
        branch: "starpath",
        available: true,
        environment: "beta",
        jurisdiction: "US",
        capabilityVersion: 1,
        evaluatedAt: "2026-08-30T11:59:00.000Z",
        expiresAt: "2026-08-30T12:05:00.000Z",
        protectedRoutes: [
          "starpath.read",
          "starpath.start",
          "starpath.answer",
          "starpath.recall.skip",
        ],
      }),
    });

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
        await privacy.requestExport("u14-coverage-export");
        await privacy.getDeletionTombstone();
      }),
      scenarios: await capture(async () => {
        await scenarios.createIntention(
          {
            title: "Member intention",
            target: { minor_units: "250000", currency: "USD" },
            target_date: "2028-08-28",
          },
          "u9b-intention-idempotency-key",
        );
        await scenarios.getFutureMirror(genericId, genericId);
      }),
      publicPreview: await capture(() => preview.listPublished("ritual", 10)),
      rituals: await capture(async () => {
        await rituals.get(genericId);
        await rituals.getSchedule("2026-08-28", "tarot");
        await rituals.getScenario(genericId);
      }),
      rowan: await capture(() => rowan.resolve("daily_ritual", "daily")),
      starpathMember: [
        await captureAttempt(() => starpathMember.read()),
        await captureAttempt(() =>
          starpathMember.startOrResume("starpath-start-coverage")
        ),
        await captureAttempt(() =>
          starpathMember.answer({
            session_id: genericId,
            manifest_id: genericId,
            revision_id: genericId,
            question_id: genericId,
            option_id: genericId,
          }, 1, "starpath-answer-coverage")
        ),
        await captureAttempt(() =>
          starpathMember.skipRecall(
            { session_id: genericId },
            1,
            "starpath-recall-coverage",
          )
        ),
      ].join("\n"),
      search: await capture(() =>
        search.searchPage({
          query: "argus",
          kinds: ["asset", "coven", "grimoire", "circle_template"],
          limit: 10,
          after: null,
        })),
      admin: await capture(async () => {
        await admin.getStaffPrincipal();
        await admin.listAudit(10);
        await admin.listEditorial(10);
        await admin.issueStepUp("admin_job_retry", genericId);
        await admin.commandEditorial(
          "request_review", genericId, genericId, "Ready for review", false, genericId,
        );
        await admin.commandEditorial(
          "approve", genericId, genericId, "Evidence reviewed", false, genericId,
        );
        await admin.commandEditorial(
          "publish", genericId, genericId, "Approved publication", false, genericId,
        );
      }),
      adminOperations: await capture(async () => {
        await adminOperations.listJobs(10);
        await adminOperations.listPrivacy(10);
        await adminOperations.listAudit(10);
        await adminOperations.listBrokerageDiagnostics(10);
      }),
    };

    for (const [domain, relations] of Object.entries(
      RETAINED_SUPABASE_RELATIONS,
    )) {
      const executedSql = executedByDomain[domain];
      expect(executedSql, `${domain} has executable repository evidence`).toBeDefined();
      for (const relation of relations) {
        const composedCapabilities: Record<string, Record<string, string>> = {
          assets: {
            "argus_app.catalog_assets": "argus_private.list_published_assets_page",
            "argus_app.asset_codex_revisions": "argus_private.list_published_assets_page",
            "argus_app.editorial_render_documents": "argus_private.list_published_assets_page",
          },
          briefings: {
            "argus_app.briefing_sections": "argus_private.list_member_briefing_sections",
          },
          coven: {
            "argus_app.coven_entries": "argus_private.list_published_coven_page",
            "argus_app.companies": "argus_private.list_published_coven_page",
            "argus_app.coven_qualifications": "argus_private.list_published_coven_page",
            "argus_app.member_saved_items": "argus_private.list_published_coven_page",
            "argus_app.editorial_render_documents": "argus_private.list_published_coven_page",
          },
          discover: {
            "argus_app.grimoires": "argus_private.list_published_grimoires_page",
            "argus_app.community_templates": "argus_private.list_published_circle_templates_page",
            "argus_app.member_saved_items": "argus_private.list_published_grimoires_page",
            "argus_app.editorial_render_documents": "argus_private.list_published_grimoires_page",
          },
          media: {
            "argus_private.media_upload_intents": "argus_private.get_member_media_upload_intent",
            "argus_app.media_assets": "argus_private.finalize_media_upload",
          },
          privacy: {
            "argus_app.privacy_requests": "argus_private.list_member_privacy_requests",
            "argus_private.outbox_events": "argus_private.request_privacy_export",
            "argus_private.deletion_tombstones": "argus_private.get_member_deletion_tombstone",
          },
          starpathMember: {
            "argus_app.starpath_policies": "argus_private.resolve_starpath_member_authority",
            "argus_app.starpath_lessons": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_lesson_revisions": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_factual_sections": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_knowledge_checks": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_knowledge_check_options": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_evidence_bindings": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_session_themes": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_curriculum_manifests": "argus_private.resolve_starpath_member_authority",
            "argus_app.starpath_manifest_nodes": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_manifest_themes": "argus_private.read_starpath_curriculum_projection",
            "argus_app.starpath_sessions": "argus_private.read_starpath_state",
            "argus_app.starpath_progress_states": "argus_private.answer_starpath_question",
            "argus_app.starpath_lesson_completions": "argus_private.answer_starpath_question",
            "argus_app.starpath_attempts": "argus_private.answer_starpath_question",
            "argus_app.starpath_recall_states": "argus_private.skip_starpath_recall",
            "argus_private.member_idempotency_records": "argus_private.start_or_resume_starpath_session",
          },
          search: {
            "argus_app.catalog_assets": "argus_private.search_published_content_page",
            "argus_app.editorial_items": "argus_private.search_published_content_page",
          },
        };
        const capability = composedCapabilities[domain]?.[relation];
        if (capability !== undefined) {
          expect(executedSql, `${domain} composes ${relation} behind ${capability}`)
            .toContain(capability);
          continue;
        }
        if (
          (domain === "editorial" || domain === "publicPreview") &&
          [
            "argus_app.editorial_items",
            "argus_app.editorial_revisions",
            "argus_app.editorial_render_documents",
          ].includes(relation)
        ) {
          expect(executedSql, `${domain} executes the publication projection`)
            .toContain("argus_private.list_current_published_editorial");
          continue;
        }
        expect(executedSql, `${domain} executes ${relation}`).toContain(relation);
      }
    }
    expect(executedByDomain.adminOperations).toContain(
      "argus_private.list_job_diagnostics",
    );
    expect(executedByDomain.adminOperations).toContain(
      "argus_private.list_privacy_request_diagnostics",
    );
    expect(executedByDomain.adminOperations).not.toMatch(
      /from\s+argus_private\.job_runs|from\s+argus_app\.privacy_requests/i,
    );
    const brokerageDiagnostics = recorded.queries.find(({ text }) =>
      text.includes("'connection_health'::text")
    );
    expect(brokerageDiagnostics?.values).toEqual([10]);
    expect(brokerageDiagnostics?.text.match(/limit \$1/g)).toHaveLength(4);
    expect(brokerageDiagnostics?.text).toMatch(
      /from \(\s+select id,status,last_error_code,updated_at\s+from argus_brokerage\.connections\s+order by updated_at desc,id desc\s+limit \$1/s,
    );
    expect(brokerageDiagnostics?.text).toMatch(
      /from \(\s+select id,state,updated_at\s+from argus_private\.provider_commands\s+order by updated_at desc,id desc\s+limit \$1/s,
    );
    expect(brokerageDiagnostics?.text).toMatch(
      /from \(\s+select id,status,last_error_code,updated_at\s+from argus_private\.reconciliation_records\s+order by updated_at desc,id desc\s+limit \$1/s,
    );
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

    await expect(
      readFile(resolve(apiRoot, "src/db/client.ts"), "utf8"),
    ).rejects.toMatchObject({ code: "ENOENT" });
    expect(acceptedSources.join("\n")).not.toMatch(/ritual_identity_resolver|ritual_runtime/);
  });
});

const supabaseDatabaseUrl = process.env.SUPABASE_DB_URL;

describe.skipIf(supabaseDatabaseUrl === undefined)(
  "live Supabase transaction-pooler claims",
  () => {
    it("returns numeric account data and creates one real daily assignment", async () => {
      const integrationUser = "018f3c2a-4b67-7a89-8abc-123456789031";
      const integrationSession = "018f3c2a-4b67-7a89-8abc-123456789032";
      const nodePool = new pg.Pool({
        connectionString: supabaseDatabaseUrl,
        max: 1,
      });
      const client = await nodePool.connect();
      const database: DatabaseTransaction = {
        query: ((text: string, values?: readonly unknown[]) =>
          client.query(text, values as unknown[] | undefined)) as DatabaseTransaction["query"],
      };
      try {
        await client.query("begin");
        await client.query(
          `do $membership$ begin
             execute pg_catalog.format(
               'grant argus_edge,argus_member to %I with set true',current_user
             );
           end $membership$`,
        );
        await client.query(
          `insert into auth.users(
             instance_id,id,aud,role,email,raw_app_meta_data,
             raw_user_meta_data,created_at,updated_at,is_sso_user,is_anonymous
           ) values (
             '00000000-0000-0000-0000-000000000000',$1,
             'authenticated','authenticated','daily-ritual@example.test',
             '{"provider":"email","providers":["email"]}'::jsonb,
             '{}'::jsonb,current_timestamp,current_timestamp,false,false
           )`,
          [integrationUser],
        );
        await client.query(
          `update argus_app.preferences
              set timezone='America/New_York',ritual_mode='tarot'
            where user_id=$1`,
          [integrationUser],
        );
        await client.query("set local role argus_edge");
        await client.query(
          "select argus_private.install_request_context($1::uuid,$2::uuid,'aal1')",
          [integrationUser, integrationSession],
        );
        await client.query("reset role");
        await client.query("set local role argus_member");

        const account = await createSupabaseAccountRepository(database).get();
        const rituals = createSupabaseRitualRepository(database);
        const first = await rituals.getDaily("tarot");
        const repeated = await rituals.getDaily("tarot");

        expect(account.deletion_epoch).toBe(0);
        expect(first?.id).toBe(repeated?.id);
        expect(first?.deletion_epoch).toBe(0);
        const count = await database.query<{ total: number }>(
          `select count(*)::integer as total
             from argus_app.daily_ritual_assignments
            where user_id=argus_private.trusted_request_user_id()`,
        );
        expect(count.rows[0]?.total).toBe(1);
      } finally {
        await client.query("reset role").catch(() => undefined);
        await client.query("rollback").catch(() => undefined);
        client.release();
        await nodePool.end();
      }
    });

    it("scopes the request user helper to one transaction and recovers the pooled client after rollback", async () => {
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
              "select argus_private.request_user_id()::text as user_id",
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
              "select argus_private.request_user_id()::text as user_id",
            ),
        );
        expect(recovered.rows[0]?.user_id).toBe(userB);
      } finally {
        await pool.end();
      }
    });
  },
);
