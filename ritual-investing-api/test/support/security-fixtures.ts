import type { Bindings } from "../../src/config/env";
import { createTestRsaKey, signRs256, type TestRsaKey } from "./jwt";

export const AUTH0_ISSUER = "https://ritual-test.us.auth0.com/";
export const AUTH0_AUDIENCE = "https://api.ritual-investing.test";
export const ACCESS_ISSUER = "https://ritual-team.cloudflareaccess.com";
export const ACCESS_AUDIENCE = "cf-access-app-audience";
export const ADMIN_CLIENT_ID = "ritual-admin-client";
export const CONSUMER_CLIENT_ID = "ritual-consumer-client";

export type FakeRateLimit = RateLimit & { keys: string[] };

export function fakeRateLimit(
  outcomes: Array<boolean | Error> = [],
): FakeRateLimit {
  const keys: string[] = [];
  return {
    keys,
    async limit({ key }) {
      keys.push(key);
      const outcome = outcomes.shift() ?? true;
      if (outcome instanceof Error) throw outcome;
      return { success: outcome };
    },
  };
}

export function testBindings(rateLimit = fakeRateLimit()): Bindings {
  return {
    ENVIRONMENT: "test",
    BUILD_REVISION: "test-revision",
    API_ORIGIN: "https://api.ritual-investing.test",
    CONSUMER_ORIGIN: "https://app.ritual-investing.test",
    ADMIN_ORIGIN: "https://admin.ritual-investing.test",
    ADMIN_HOST: "admin-api.ritual-investing.test",
    AUTH0_ISSUER,
    AUTH0_AUDIENCE,
    AUTH0_JWKS_URL: `${AUTH0_ISSUER}.well-known/jwks.json`,
    AUTH0_ADMIN_CLIENT_IDS: ADMIN_CLIENT_ID,
    CF_ACCESS_ISSUER: ACCESS_ISSUER,
    CF_ACCESS_AUDIENCE: ACCESS_AUDIENCE,
    CF_ACCESS_JWKS_URL: `${ACCESS_ISSUER}/cdn-cgi/access/certs`,
    CURSOR_SIGNING_KEY: "ritual-test-cursor-signing-key-32-bytes-minimum",
    RL_HEALTH: rateLimit,
    RL_PUBLIC: rateLimit,
    RL_SEARCH: rateLimit,
    RL_MEMBER_READ: rateLimit,
    RL_MEMBER_WRITE: rateLimit,
    RL_COMMAND: rateLimit,
    RL_SENSITIVE: rateLimit,
    RL_ADMIN_READ: rateLimit,
    RL_ADMIN_WRITE: rateLimit,
    RL_ADMIN_HIGH: rateLimit,
    RL_UPLOAD: rateLimit,
  } as Bindings;
}

export function auth0Claims(overrides: Record<string, unknown> = {}) {
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: AUTH0_ISSUER,
    aud: AUTH0_AUDIENCE,
    sub: "auth0|member-1",
    azp: CONSUMER_CLIENT_ID,
    iat: now - 5,
    exp: now + 300,
    permissions: ["read:self", "write:self"],
    ...overrides,
  };
}

export function accessClaims(overrides: Record<string, unknown> = {}) {
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: ACCESS_ISSUER,
    aud: [ACCESS_AUDIENCE],
    sub: "access-user-1",
    email: "operator@ritual-investing.test",
    iat: now - 5,
    exp: now + 300,
    ...overrides,
  };
}

export function memberToken(key: TestRsaKey, overrides: Record<string, unknown> = {}) {
  return signRs256(key, auth0Claims(overrides));
}

export function accessToken(key: TestRsaKey, overrides: Record<string, unknown> = {}) {
  return signRs256(key, accessClaims(overrides));
}

export const sessionSnapshot = {
  account: { id: "018f3c2a-4b67-7a89-8abc-123456789001", status: "active" as const },
  profile: { display_name: "Ritual Member", locale: "en-US" },
  preferences: {
    theme_mode: "system" as const,
    ritual_mode: "tarot" as const,
    timezone: "UTC",
    locale: "en-US",
    version: 1,
  },
  onboarding: { current_step: "welcome", completed_steps: [], version: 1 },
  entitlement: { plan_code: "demo", status: "active" as const },
  default_portfolio: {
    id: "018f3c2a-4b67-7a89-8abc-123456789002",
    name: "Demo Portfolio",
    currency: "USD" as const,
    status: "active" as const,
    version: 1,
  },
  server_time: "2026-08-24T04:00:00.000Z",
  contract_version: "1.0.0" as const,
};

export const resolvedMemberAccount = {
  accountId: "018f3c2a-4b67-7a89-8abc-123456789001",
  tenantId: "018f3c2a-4b67-7a89-8abc-123456789099",
  accountStatus: "active" as const,
  tenantStatus: "active" as const,
  revocationEpoch: 0,
};
