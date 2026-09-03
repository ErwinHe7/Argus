import { describe, expect, it, vi } from "vitest";

import type {
  DatabaseQueryResult,
  DatabaseTransaction,
} from "../../src/db/database-port.ts";
import { createSupabaseRitualRepository } from "../../src/domains/rituals/repository.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const otherUserId = "018f3c2a-4b67-7a89-8abc-123456789002";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const assignmentId = "018f3c2a-4b67-7a89-8abc-123456789021";
const consumerOrigin = "https://app.ritual-investing.test";
const requestHeaders = {
  authorization: "Bearer verified-supabase-token",
  origin: consumerOrigin,
  "content-type": "application/json",
};
const bindings = {
  environment: "test" as const,
  buildRevision: "daily-ritual-u1-test",
  consumerOrigins: Object.freeze([consumerOrigin]),
  adminOrigin: "https://admin.ritual-investing.test",
  webAdmission: "open" as const,
};

type RitualState = "assigned" | "revealed" | "completed";

type AuthorityFixture = Readonly<{
  requestUserId?: string;
  assignmentUserId?: string;
  assignmentDeletionEpoch?: number;
  memberDeletionEpoch?: number;
  memberStatus?: "active" | "suspended" | "deletion_pending";
  localDate?: string;
  currentLocalDate?: string;
  mode?: "tarot" | "astrology";
  effectiveMode?: "tarot" | "astrology";
  serverEvaluatedAt?: string;
  validUntil?: string;
}>;

function projection(
  state: RitualState,
  version: number,
  fixture: Required<AuthorityFixture>,
  timestamps: Readonly<{
    revealedAt: string | null;
    completedAt: string | null;
  }>,
) {
  return {
    id: assignmentId,
    user_id: fixture.assignmentUserId,
    deletion_epoch: fixture.assignmentDeletionEpoch,
    local_date: fixture.localDate,
    mode: fixture.mode,
    schedule_id: "018f3c2a-4b67-7a89-8abc-123456789022",
    revision_id: "018f3c2a-4b67-7a89-8abc-123456789023",
    rowan_revision_id: null,
    state,
    revealed_at: timestamps.revealedAt,
    completed_at: timestamps.completedAt,
    version,
    payload: {
      title: "Strength",
      art_key: "strength",
      art_alt: "Strength tarot card",
      interpretation: "Patience is the stronger path.",
    },
    body_template: null,
    allowed_tokens: null,
    risk_footer: null,
  };
}

function fixture(input: AuthorityFixture = {}) {
  const authority: Required<AuthorityFixture> = {
    requestUserId: input.requestUserId ?? userId,
    assignmentUserId: input.assignmentUserId ?? userId,
    assignmentDeletionEpoch: input.assignmentDeletionEpoch ?? 0,
    memberDeletionEpoch: input.memberDeletionEpoch ?? 0,
    memberStatus: input.memberStatus ?? "active",
    localDate: input.localDate ?? "2026-09-02",
    currentLocalDate: input.currentLocalDate ?? "2026-09-02",
    mode: input.mode ?? "tarot",
    effectiveMode: input.effectiveMode ?? "tarot",
    serverEvaluatedAt:
      input.serverEvaluatedAt ?? "2026-09-02T16:00:00.000Z",
    validUntil: input.validUntil ?? "2026-09-03T04:00:00.000Z",
  };
  let state: RitualState = "assigned";
  let version = 1;
  let revealedAt: string | null = null;
  let completedAt: string | null = null;
  const queries: Array<{ text: string; values: readonly unknown[] }> = [];

  const query = vi.fn(async <Row>(
    text: string,
    values: readonly unknown[] = [],
  ): Promise<DatabaseQueryResult<Row>> => {
    queries.push({ text, values });
    if (text.includes("insert into argus_app.daily_ritual_assignments")) {
      return { rows: [], rowCount: 0 };
    }
    if (text.includes("update argus_app.daily_ritual_assignments")) {
      const [requestedId, from, to, expectedVersion] = values as readonly [
        string,
        RitualState,
        RitualState,
        number,
      ];
      const guards = {
        adjacent: /\$2\s*=\s*'assigned'[\s\S]*\$3\s*=\s*'revealed'[\s\S]*or[\s\S]*\$2\s*=\s*'revealed'[\s\S]*\$3\s*=\s*'completed'/i.test(
          text,
        ),
        owner: /assignment\.user_id\s*=\s*argus_private\.trusted_request_user_id\(\)/i.test(
          text,
        ),
        deletionEpoch:
          /assignment\.deletion_epoch\s*=\s*member\.deletion_epoch/i.test(text) &&
          /preferences\.deletion_epoch\s*=\s*member\.deletion_epoch/i.test(text),
        active: /member\.status\s*=\s*'active'/i.test(text),
        day: /assignment\.local_date\s*=\s*\(\s*current_timestamp at time zone preferences\.timezone\s*\)::date/i.test(
          text,
        ),
        mode: /assignment\.mode\s*=\s*preferences\.ritual_mode/i.test(text),
      };
      const allowed = requestedId === assignmentId &&
        state === from &&
        version === expectedVersion &&
        (!guards.adjacent ||
          (from === "assigned" && to === "revealed") ||
          (from === "revealed" && to === "completed")) &&
        (!guards.owner || authority.requestUserId === authority.assignmentUserId) &&
        (!guards.deletionEpoch ||
          (authority.assignmentDeletionEpoch === authority.memberDeletionEpoch)) &&
        (!guards.active || authority.memberStatus === "active") &&
        (!guards.day || authority.localDate === authority.currentLocalDate) &&
        (!guards.mode || authority.mode === authority.effectiveMode);
      if (!allowed) return { rows: [], rowCount: 0 };

      state = to;
      version += 1;
      if (to === "revealed") revealedAt = "2026-09-02T16:01:00.000Z";
      if (to === "completed") completedAt = "2026-09-02T16:02:00.000Z";
      return {
        rows: [{ id: assignmentId }] as Row[],
        rowCount: 1,
      };
    }
    if (text.includes("from argus_app.daily_ritual_assignments assignment")) {
      const value = projection(state, version, authority, {
        revealedAt,
        completedAt,
      });
      const addsServerAuthority =
        text.includes("'server_evaluated_at'") &&
        text.includes("'valid_until'");
      return {
        rows: [{
          projection: addsServerAuthority
            ? {
              ...value,
              server_evaluated_at: authority.serverEvaluatedAt,
              valid_until: authority.validUntil,
            }
            : value,
        }] as Row[],
        rowCount: 1,
      };
    }
    return { rows: [], rowCount: 0 };
  });
  const database: DatabaseTransaction = {
    query: query as DatabaseTransaction["query"],
  };
  const rituals = createSupabaseRitualRepository(database);
  const transactions: string[] = [];
  const withRepositories = vi.fn(async (
    _claims: unknown,
    transaction: string,
    callback: (repositories: RetainedRepositorySet) => Promise<unknown>,
  ) => {
    transactions.push(transaction);
    return await callback({ rituals } as unknown as RetainedRepositorySet);
  });
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId: authority.requestUserId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: 1,
    })),
    withRepositories: withRepositories as never,
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
  return {
    app,
    queries,
    transactions,
    snapshot: () => ({ state, version, revealedAt, completedAt }),
  };
}

async function transition(
  test: ReturnType<typeof fixture>,
  from: RitualState,
  to: RitualState,
  expectedVersion: number,
) {
  return await test.app.request(
    `/v1/rituals/${assignmentId}/transition`,
    {
      method: "POST",
      headers: { ...requestHeaders, "if-match": `"v${expectedVersion}"` },
      body: JSON.stringify({ from, to }),
    },
    bindings,
  );
}

describe("Daily Ritual transition authority", () => {
  it("allows only adjacent edges and stamps each transition exactly once", async () => {
    const test = fixture();

    const revealed = await transition(test, "assigned", "revealed", 1);
    expect(revealed.status).toBe(200);
    expect(await revealed.json()).toMatchObject({
      data: {
        state: "revealed",
        version: 2,
        revealed_at: "2026-09-02T16:01:00.000Z",
        completed_at: null,
        server_evaluated_at: "2026-09-02T16:00:00.000Z",
        valid_until: "2026-09-03T04:00:00.000Z",
      },
    });

    const replayedReveal = await transition(test, "assigned", "revealed", 1);
    expect(replayedReveal.status).toBe(409);
    expect(test.snapshot()).toEqual({
      state: "revealed",
      version: 2,
      revealedAt: "2026-09-02T16:01:00.000Z",
      completedAt: null,
    });

    const completed = await transition(test, "revealed", "completed", 2);
    expect(completed.status).toBe(200);
    expect(await completed.json()).toMatchObject({
      data: {
        state: "completed",
        version: 3,
        revealed_at: "2026-09-02T16:01:00.000Z",
        completed_at: "2026-09-02T16:02:00.000Z",
      },
    });
    expect(test.transactions).toEqual(["member", "member", "member"]);
    expect(
      test.queries.filter(({ text }) =>
        text.includes("update argus_app.daily_ritual_assignments")
      ),
    ).toHaveLength(3);
  });

  it.each([
    ["assigned", "assigned"],
    ["assigned", "completed"],
    ["revealed", "revealed"],
    ["completed", "completed"],
  ] as const)("rejects non-adjacent %s to %s before repository mutation", async (
    from,
    to,
  ) => {
    const test = fixture();
    const response = await transition(test, from, to, 1);

    expect(response.status).toBe(422);
    expect(test.queries).toEqual([]);
    expect(test.snapshot()).toEqual({
      state: "assigned",
      version: 1,
      revealedAt: null,
      completedAt: null,
    });
  });

  it.each([
    ["another member's assignment", { assignmentUserId: otherUserId }],
    ["a retired deletion epoch", { assignmentDeletionEpoch: 0, memberDeletionEpoch: 1 }],
    ["an inactive member", { memberStatus: "suspended" as const }],
    ["a closing member", { memberStatus: "deletion_pending" as const }],
    ["a stale local day", { currentLocalDate: "2026-09-03" }],
    ["a stale preference mode", { effectiveMode: "astrology" as const }],
  ])("denies %s without mutating lifecycle fields", async (_label, denied) => {
    const test = fixture(denied);
    const before = test.snapshot();

    const response = await transition(test, "assigned", "revealed", 1);

    expect(response.status).toBe(409);
    expect(test.snapshot()).toEqual(before);
    expect(
      test.queries.filter(({ text }) =>
        text.includes("update argus_app.daily_ritual_assignments")
      ),
    ).toHaveLength(1);
  });

  it("requires bearer authentication before opening the member transaction", async () => {
    const test = fixture();
    const response = await test.app.request(
      `/v1/rituals/${assignmentId}/transition`,
      {
        method: "POST",
        headers: {
          origin: consumerOrigin,
          "content-type": "application/json",
          "if-match": '"v1"',
        },
        body: JSON.stringify({ from: "assigned", to: "revealed" }),
      },
      bindings,
    );

    expect(response.status).toBe(401);
    expect(test.transactions).toEqual([]);
    expect(test.queries).toEqual([]);
  });

  it("rejects a stale If-Match version without mutation", async () => {
    const test = fixture();
    const before = test.snapshot();

    const response = await transition(test, "assigned", "revealed", 2);

    expect(response.status).toBe(409);
    expect(test.snapshot()).toEqual(before);
  });
});

describe("Daily Ritual day authority", () => {
  it.each([
    [
      "ordinary America/New_York day",
      "2026-09-02",
      "2026-09-02T16:00:00.000Z",
      "2026-09-03T04:00:00.000Z",
    ],
    [
      "spring DST day",
      "2026-03-08",
      "2026-03-08T16:00:00.000Z",
      "2026-03-09T04:00:00.000Z",
    ],
    [
      "fall DST day",
      "2026-11-01",
      "2026-11-01T16:00:00.000Z",
      "2026-11-02T05:00:00.000Z",
    ],
  ])("returns server-owned metadata for an %s", async (
    _label,
    localDate,
    serverEvaluatedAt,
    validUntil,
  ) => {
    const test = fixture({ localDate, currentLocalDate: localDate, serverEvaluatedAt, validUntil });
    const response = await test.app.request(
      "/v1/rituals/daily?mode=tarot",
      { headers: requestHeaders },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      data: {
        local_date: localDate,
        server_evaluated_at: serverEvaluatedAt,
        valid_until: validUntil,
      },
    });
    const projectionQuery = test.queries.find(({ text }) =>
      text.includes("from argus_app.daily_ritual_assignments assignment")
    );
    expect(projectionQuery?.text).toMatch(
      /\(assignment\.local_date \+ 1\)::timestamp\s+at time zone preferences\.timezone/i,
    );
  });
});
