import { describe, expect, it, vi } from "vitest";

import fixture from "../fixtures/webull/public-contract.v1.json";
import {
  assertPartnerConfirmedContract,
  parsePartnerConfirmedContractFromEnvironment,
  publicWebullContract,
  WEBULL_PUBLIC_CONTRACT_VERSION,
  WebullProtocolGateError,
} from "../../../supabase/functions/_shared/webull/contract.ts";
import { createBlockedWebullProvider } from "../../../supabase/functions/_shared/webull/client.ts";
import { createWebullClient } from "../../../supabase/functions/_shared/webull/client.ts";

describe("Webull Connect promotion gate", () => {
  it("pins public facts while keeping every conflicting partner fact unresolved", () => {
    const contract = publicWebullContract("sandbox");
    expect(contract.version).toBe(WEBULL_PUBLIC_CONTRACT_VERSION);
    expect(contract.authorizationOrigin).toBe("https://passport.webull.com");
    expect(contract.apiOrigin).toBe(
      "https://oauth-open-api.sandbox.webull.com",
    );
    expect(contract.aggregateRequestsPerUserPerMinute).toBe(89);
    expect([...contract.unresolved]).toEqual(fixture.blocking_conflicts);
    expect(fixture.real_egress_enabled).toBe(false);
  });

  it("throws before building an authorization URL from public docs alone", () => {
    const provider = createBlockedWebullProvider(
      publicWebullContract("sandbox"),
    );
    expect(() => provider.authorizationUrl("A".repeat(43))).toThrow(
      WebullProtocolGateError,
    );
  });

  it("rejects unknown environments and incomplete or unsafe confirmations", () => {
    expect(() =>
      parsePartnerConfirmedContractFromEnvironment((name) =>
        name === "WEBULL_ENVIRONMENT" ? "preview" : undefined
      )
    ).toThrow("invalid_webull_environment");
    expect(() =>
      parsePartnerConfirmedContractFromEnvironment((name) =>
        name === "WEBULL_CONTRACT_STATUS" ? "partner_confirmed" : undefined
      )
    ).toThrow("incomplete_partner_confirmation");

    expect(() =>
      assertPartnerConfirmedContract({
        publicContract: publicWebullContract("sandbox"),
        confirmationReference: "WEBULL-1234",
        confirmedAt: "2026-08-28T12:00:00Z",
        clientId: "synthetic-client",
        redirectUri: "https://attacker.test/callback?next=private",
        authorizationScope: "user:trade:wr",
        authorizationEntrypoint: "authorization_code_endpoint",
        tokenSecretTransport: "signed_only",
        tokenContentType: "application/x-www-form-urlencoded",
        accountListPath: "/oauth-openapi/account/list",
        pkce: "unsupported",
        revocation: { supported: false },
        endpointRequestsPerWindow: { limit: Number.NaN, windowSeconds: 60 },
      })
    ).toThrow(WebullProtocolGateError);
  });

  it("uses only the exact synthetic partner-confirmed contract and intersects both limits", async () => {
    const calls: Array<{ url: URL; init: RequestInit }> = [];
    const consume = vi.fn(async () => true);
    const contract = {
      publicContract: publicWebullContract("sandbox"),
      confirmationReference: "WEBULL-SYNTHETIC-1234",
      confirmedAt: "2026-08-28T00:00:00Z",
      clientId: "synthetic-client-id",
      redirectUri: "https://just-build-this.app/mobile/webull/callback",
      authorizationScope: "user:trade:wr",
      authorizationEntrypoint: "authorization_code_endpoint" as const,
      tokenSecretTransport: "x-app-secret" as const,
      tokenContentType: "application/x-www-form-urlencoded" as const,
      accountListPath: "/oauth-openapi/account/list",
      pkce: "unsupported" as const,
      revocation: { supported: false as const },
      endpointRequestsPerWindow: { limit: 10, windowSeconds: 30 },
    };
    const client = createWebullClient({
      contract,
      credentials: {
        clientSecret: "synthetic-client-secret-value",
        appKey: "synthetic-app-key",
        appSecret: "synthetic-app-secret-value",
      },
      rateLimit: { consume },
      parseAccounts: () => [],
      fetch: vi.fn(async (url: URL | string | Request, init?: RequestInit) => {
        calls.push({ url: new URL(String(url)), init: init! });
        return new Response(
          JSON.stringify({
            token_type: "Bearer",
            access_token: "synthetic-access-token",
            refresh_token: "synthetic-refresh-token",
            expires_in: "1800",
            rt_expires_in: "1296000",
          }),
          { headers: { "content-type": "application/json" } },
        );
      }) as typeof fetch,
      now: () => new Date("2026-08-28T04:00:00Z"),
      nonce: () => "0123456789abcdef0123456789abcdef",
    });
    const authorization = client.authorizationUrl("A".repeat(43));
    expect(authorization.origin).toBe(contract.publicContract.apiOrigin);
    expect(authorization.pathname).toBe("/oauth2/auth-codes/get");
    expect(authorization.searchParams.get("scope")).toBe("user:trade:wr");

    await client.exchangeAuthorizationCode(
      "synthetic-code-value",
      "a".repeat(64),
    );
    expect(consume).toHaveBeenNthCalledWith(1, {
      scope: `webull:sandbox:user:${"a".repeat(64)}`,
      limit: 89,
      windowSeconds: 60,
    });
    expect(consume).toHaveBeenNthCalledWith(2, {
      scope: `webull:sandbox:user:${"a".repeat(64)}:path:/oauth2/tokens/create`,
      limit: 10,
      windowSeconds: 30,
    });
    expect(calls[0]!.init.redirect).toBe("error");
    expect(new Headers(calls[0]!.init.headers).get("x-app-secret")).toBe(
      "synthetic-app-secret-value",
    );
    expect(new TextDecoder().decode(calls[0]!.init.body as Uint8Array))
      .toContain(
        "client_secret=synthetic-client-secret-value",
      );
  });
});
