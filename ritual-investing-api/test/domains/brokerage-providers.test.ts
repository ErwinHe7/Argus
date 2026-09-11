import { afterEach, describe, expect, it, vi } from "vitest";
import { getBrokerageProviderCatalog } from "../../src/domains/brokerage-providers/catalog.ts";
import {
  brokerageProviderCatalogResponseSchema,
  brokerageProviderCatalogSchema,
} from "../../src/domains/brokerage-providers/schemas.ts";
import {
  buildRetainedOpenApiDocument,
  createRetainedApp,
} from "../../src/retained-app.ts";

const bindings = {
  environment: "test" as const,
  buildRevision: "provider-readiness-test",
  consumerOrigins: ["https://app.example.test"],
  adminOrigin: "https://admin.example.test",
  webAdmission: "open" as const,
};
const authorization = { authorization: "Bearer signed-supabase-token" };

function fixture(allowed = true) {
  const withRepositories = vi.fn(async () => { throw new Error("unexpected_database_access"); });
  const withPublicPreview = vi.fn(async () => { throw new Error("unexpected_database_access"); });
  const createBrokerageConnections = vi.fn(() => { throw new Error("unexpected_broker_access"); });
  const createBrokerageOrders = vi.fn(() => { throw new Error("unexpected_broker_access"); });
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId: "018f3c2a-4b67-7a89-8abc-123456789001",
      sessionId: "018f3c2a-4b67-7a89-8abc-123456789002",
      aal: "aal1" as const,
      issuedAt: Math.floor(Date.now() / 1000) - 5,
    })),
    withRepositories,
    withPublicPreview,
    createPrivacyService: () => ({} as never),
    createBrokerageConnections,
    createBrokerageOrders,
    rateLimit: { allow: vi.fn(async () => ({ allowed })) },
    requestId: () => "018f3c2a-4b67-7a89-8abc-123456789077",
  });
  return { app, withRepositories, withPublicPreview, createBrokerageConnections, createBrokerageOrders };
}

afterEach(() => vi.restoreAllMocks());

describe("US brokerage provider readiness", () => {
  it("requires member authentication before exposing the setup endpoint", async () => {
    const { app } = fixture();
    const response = await app.request("/v1/brokerage/providers", {}, bindings);
    expect(response.status).toBe(401);
  });

  it("returns actionable readiness without touching broker accounts, credentials, or the database", async () => {
    const f = fixture();
    const network = vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("unexpected_egress"));
    const response = await f.app.request("/v1/brokerage/providers", { headers: authorization }, bindings);
    expect(response.status).toBe(200);
    const body = brokerageProviderCatalogResponseSchema.parse(await response.json());
    const data = brokerageProviderCatalogSchema.parse(body.data);
    expect(data.providers.map((provider) => provider.id)).toEqual(["ibkr", "moomoo", "webull"]);
    expect(data).toEqual(getBrokerageProviderCatalog());
    expect(network).not.toHaveBeenCalled();
    expect(f.withRepositories).not.toHaveBeenCalled();
    expect(f.withPublicPreview).not.toHaveBeenCalled();
    expect(f.createBrokerageConnections).not.toHaveBeenCalled();
    expect(f.createBrokerageOrders).not.toHaveBeenCalled();
  });

  it("does not convert broker choice or a requested live flag into account or order authority", async () => {
    const { app } = fixture();
    const response = await app.request("/v1/brokerage/providers?broker=moomoo&connected=true&live=true", { headers: authorization }, bindings);
    const body = brokerageProviderCatalogResponseSchema.parse(await response.json());
    const data = brokerageProviderCatalogSchema.parse(body.data);
    expect(data.automatic_execution).toBe(false);
    expect(data.execution_mode).toBe("user_confirmed");
    for (const provider of data.providers) {
      expect(provider.connection_available).toBe(false);
      expect(provider.manual_orders_available).toBe(false);
      expect(provider.status).toBe("setup_required");
    }
    expect(brokerageProviderCatalogSchema.safeParse({ ...data, automatic_execution: true }).success).toBe(false);
    expect(brokerageProviderCatalogSchema.safeParse({
      ...data,
      providers: data.providers.map((provider) => ({ ...provider, connection_available: true })),
    }).success).toBe(false);
  });

  it("distinguishes existing fixture implementation from missing adapters and avoids an invented moomoo partner gate", () => {
    const catalog = getBrokerageProviderCatalog();
    const webull = catalog.providers.find((provider) => provider.id === "webull")!;
    const moomoo = catalog.providers.find((provider) => provider.id === "moomoo")!;
    const ibkr = catalog.providers.find((provider) => provider.id === "ibkr")!;
    expect(webull.implementation).toBe("fixture_validated_connection_and_manual_orders");
    expect(webull.reason_codes).toContain("live_provider_binding_pending");
    expect(ibkr.reason_codes).toContain("third_party_access_required");
    expect(moomoo.implementation).toBe("adapter_pending");
    expect(moomoo.reason_codes).toContain("us_account_permissions_unverified");
    expect(JSON.stringify(moomoo)).not.toMatch(/partner.*approval|approval.*partner/i);
  });

  it("honors the shared rate limit before returning readiness", async () => {
    const { app } = fixture(false);
    const response = await app.request("/v1/brokerage/providers", { headers: authorization }, bindings);
    expect(response.status).toBe(429);
  });

  it("publishes an explicit authenticated read-only OpenAPI envelope", () => {
    const { app } = fixture();
    const path = buildRetainedOpenApiDocument(app).paths["/v1/brokerage/providers"]!;
    expect(Object.keys(path)).toEqual(["get"]);
    expect(path.get?.security).toEqual([{ SupabaseBearer: [] }]);
    expect(JSON.stringify(path.get?.responses["200"])).toContain("BrokerageProviderCatalogResponse");
  });
});
