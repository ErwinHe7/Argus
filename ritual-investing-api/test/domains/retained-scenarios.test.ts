import { describe, expect, it, vi } from "vitest";

import {
  createFutureMirrorProjectionHash,
  createHypotheticalProjection,
} from "../../src/domains/intentions/repository.ts";
import {
  ScenarioConflictError,
  type ScenarioRepository,
} from "../../src/domains/intentions/ports.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const intentionId = "018f3c2a-4b67-7a89-8abc-123456789020";
const runId = "018f3c2a-4b67-7a89-8abc-123456789021";
const bindings = {
  environment: "test" as const,
  buildRevision: "u9b-test",
  consumerOrigin: "https://app.ritual-investing.test",
  adminOrigin: "https://admin.ritual-investing.test",
};

function fixture(
  scenarios: Partial<ScenarioRepository> | Record<string, unknown>,
) {
  return createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: "aal1" as const,
      issuedAt: 1,
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback({ scenarios } as unknown as RetainedRepositorySet),
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
}

function nonSupabaseScenarioRepository(
  createIntention: ScenarioRepository["createIntention"],
): ScenarioRepository {
  const unexpected = async (): Promise<never> => {
    throw new Error("Unexpected ScenarioRepository method call");
  };
  return {
    listIntentions: unexpected,
    getIntention: unexpected,
    createIntention,
    patchIntention: unexpected,
    archiveIntention: unexpected,
    createFutureMirror: unexpected,
    getLatestFutureMirror: unexpected,
    getFutureMirror: unexpected,
  };
}

const reviewedInput = {
  name: "Steady path",
  baseline: { minor_units: "9007199254740991", currency: "USD" as const },
  monthly_contribution: { minor_units: "0", currency: "USD" as const },
  annual_return_bps: { low: -5000, mid: 0, high: 5000 },
  as_of_date: "2026-08-28",
};

describe("retained Intentions and hypothetical Future Mirror", () => {
  it("projects exact bigint minor units with floor rounding at the safe-input boundary", () => {
    const first = createHypotheticalProjection({
      ...reviewedInput,
      targetDate: "2026-09-28",
    });
    const second = createHypotheticalProjection({
      ...reviewedInput,
      targetDate: "2026-09-28",
    });

    expect(first).toEqual(second);
    expect(first).toEqual([
      {
        ordinal: 1,
        projected_date: "2026-09-28",
        low_amount_minor: "8631899285793449",
        mid_amount_minor: "9007199254740991",
        high_amount_minor: "9382499223688532",
      },
    ]);
  });

  it("keeps the projection identity stable across title-only intention edits", async () => {
    const first = await createFutureMirrorProjectionHash(
      reviewedInput,
      "2027-08-28",
      "USD",
    );
    const afterTitleEdit = await createFutureMirrorProjectionHash(
      reviewedInput,
      "2027-08-28",
      "USD",
    );
    expect(first).toBe(afterTitleEdit);
  });

  it("rejects invalid horizons without using floating financial math", () => {
    expect(() =>
      createHypotheticalProjection({
        ...reviewedInput,
        targetDate: "2026-08-28",
      })
    ).toThrowError(new ScenarioConflictError("invalid_scenario_horizon"));
  });

  it("registers owner-scoped scenario routes and preserves exact reviewed input", async () => {
    const createFutureMirror = vi.fn(async () => ({ id: runId }));
    const app = fixture({ createFutureMirror });
    const response = await app.request(
      `/v1/intentions/${intentionId}/future-mirror`,
      {
        method: "POST",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          "idempotency-key": "future-mirror-reviewed-0001",
          origin: bindings.consumerOrigin,
        },
        body: JSON.stringify({
          name: "Steady path",
          baseline: { minor_units: "125000", currency: "USD" },
          monthly_contribution: { minor_units: "25000", currency: "USD" },
          annual_return_bps: { low: -1000, mid: 400, high: 1800 },
          as_of_date: "2026-08-28",
        }),
      },
      bindings,
    );

    expect(response.status).toBe(200);
    expect(createFutureMirror).toHaveBeenCalledWith(
      intentionId,
      expect.objectContaining({
        baseline: { minor_units: "125000", currency: "USD" },
      }),
      "future-mirror-reviewed-0001",
    );
  });

  it("maps exact idempotency conflicts without leaking reviewed values", async () => {
    const app = fixture({
      createIntention: vi.fn(async () => {
        throw new ScenarioConflictError("idempotency_conflict");
      }),
    });
    const response = await app.request(
      "/v1/intentions",
      {
        method: "POST",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          "idempotency-key": "intention-reviewed-000001",
          origin: bindings.consumerOrigin,
        },
        body: JSON.stringify({
          title: "A private intention",
          target: { minor_units: "250000", currency: "USD" },
          target_date: "2028-08-28",
        }),
      },
      bindings,
    );

    expect(response.status).toBe(409);
    expect(await response.text()).not.toContain("A private intention");
  });

  it.each([
    ["idempotency_conflict", 409],
    ["invalid_scenario_input", 422],
  ] as const)(
    "maps shared ScenarioRepository %s errors to %i without a Supabase adapter",
    async (code, status) => {
      const app = fixture(nonSupabaseScenarioRepository(async () => {
        throw new ScenarioConflictError(code);
      }));
      const response = await app.request(
        "/v1/intentions",
        {
          method: "POST",
          headers: {
            authorization: "Bearer valid-token",
            "content-type": "application/json",
            "idempotency-key": "intention-port-error-000001",
            origin: bindings.consumerOrigin,
          },
          body: JSON.stringify({
            title: "A private intention",
            target: { minor_units: "250000", currency: "USD" },
            target_date: "2028-08-28",
          }),
        },
        bindings,
      );

      expect(response.status).toBe(status);
      expect(await response.json()).toMatchObject({ error: { code } });
    },
  );

  it("maps an intention-currency mismatch as invalid scenario input", async () => {
    const app = fixture({
      createFutureMirror: vi.fn(async () => {
        throw new ScenarioConflictError("invalid_scenario_input");
      }),
    });
    const response = await app.request(
      `/v1/intentions/${intentionId}/future-mirror`,
      {
        method: "POST",
        headers: {
          authorization: "Bearer valid-token",
          "content-type": "application/json",
          "idempotency-key": "future-mirror-currency-0001",
          origin: bindings.consumerOrigin,
        },
        body: JSON.stringify({
          ...reviewedInput,
          baseline: { minor_units: "100000", currency: "EUR" },
          monthly_contribution: { minor_units: "1000", currency: "EUR" },
        }),
      },
      bindings,
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toMatchObject({
      error: { code: "invalid_scenario_input" },
    });
  });

  it("keeps the list limit within the response contract", async () => {
    const listIntentions = vi.fn();
    const app = fixture({ listIntentions });
    const response = await app.request(
      "/v1/intentions?limit=51",
      {
        headers: {
          authorization: "Bearer valid-token",
          origin: bindings.consumerOrigin,
        },
      },
      bindings,
    );

    expect(response.status).toBe(422);
    expect(listIntentions).not.toHaveBeenCalled();
  });

  it("contains no brokerage or command vocabulary in the scenario contract", () => {
    const paths = createRetainedApp({
      verifyAccessToken: vi.fn(),
      withRepositories: vi.fn(),
      withPublicPreview: vi.fn(),
      createPrivacyService: vi.fn(),
      rateLimit: {} as never,
    }).getOpenAPIDocument({
      openapi: "3.0.3",
      info: { title: "test", version: "1" },
    }).paths;
    expect(paths?.["/v1/intentions"]).toMatchObject({ get: {}, post: {} });
    expect(paths?.["/v1/intentions/{intention_id}"]).toMatchObject({
      get: {},
      patch: {},
      delete: {},
    });
    expect(paths?.["/v1/intentions/{intention_id}/future-mirror"])
      .toMatchObject({
        post: {},
      });
    expect(paths?.["/v1/intentions/{intention_id}/future-mirror/latest"])
      .toMatchObject({
        get: {},
      });
    expect(paths?.["/v1/intentions/{intention_id}/future-mirror/{run_id}"])
      .toMatchObject({
        get: {},
      });
    expect({
      list: paths?.["/v1/intentions"]?.get?.operationId,
      create: paths?.["/v1/intentions"]?.post?.operationId,
      get: paths?.["/v1/intentions/{intention_id}"]?.get?.operationId,
      patch: paths?.["/v1/intentions/{intention_id}"]?.patch?.operationId,
      archive: paths?.["/v1/intentions/{intention_id}"]?.delete?.operationId,
      createMirror: paths?.["/v1/intentions/{intention_id}/future-mirror"]?.post
        ?.operationId,
      latestMirror: paths
        ?.["/v1/intentions/{intention_id}/future-mirror/latest"]?.get
        ?.operationId,
      getMirror: paths?.["/v1/intentions/{intention_id}/future-mirror/{run_id}"]
        ?.get
        ?.operationId,
    }).toEqual({
      list: "listIntentions",
      create: "createIntention",
      get: "getIntention",
      patch: "patchIntention",
      archive: "archiveIntention",
      createMirror: "createFutureMirror",
      latestMirror: "getLatestFutureMirror",
      getMirror: "getFutureMirror",
    });
    const serialized = JSON.stringify(
      paths?.["/v1/intentions/{intention_id}/future-mirror"],
    );
    expect(serialized).not.toMatch(
      /brokerage|balance|position|order|provider|credential|command|portfolio|ledger/i,
    );
  });
});
