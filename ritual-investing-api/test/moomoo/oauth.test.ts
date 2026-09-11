import { describe, expect, it } from "vitest";

import {
  createMoomooAuthorization,
  MOOMOO_OAUTH_CONTRACT,
  moomooPkceChallenge,
  normalizeMoomooTokenResponse,
  prepareMoomooAuthorizationCodeExchange,
  prepareMoomooRefresh,
} from "../../src/providers/moomoo/oauth.ts";

const client = Object.freeze({
  clientId: "synthetic-moomoo-client",
  registeredRedirectUri: "https://app.example.test/brokers/moomoo/callback",
});
const owner = Object.freeze({
  userId: "018f3c2a-4b67-7a89-8abc-123456789001",
  sessionId: "018f3c2a-4b67-7a89-8abc-123456789002",
  connectionId: "018f3c2a-4b67-7a89-8abc-123456789003",
  deletionEpoch: 0,
});
const nowMs = Date.parse("2026-09-05T12:00:00Z");

async function fixture() {
  const authorization = await createMoomooAuthorization(client, owner, nowMs);
  const state = new URL(authorization.authorizationUrl).searchParams.get("state")!;
  const callback = new URL(client.registeredRedirectUri);
  callback.search = new URLSearchParams({ state, code: "synthetic+code/=&" }).toString();
  return { ...authorization, state, callback };
}

describe("moomoo public-client OAuth contract", () => {
  it("matches the RFC 7636 S256 fixture using Web Crypto", async () => {
    expect(await moomooPkceChallenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")).toBe(
      "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
    );
    await expect(moomooPkceChallenge("short")).rejects.toThrow("invalid_moomoo_pkce");
  });

  it("pins the host, generates independent secrets and exposes only documented query fields", async () => {
    const first = await fixture();
    const second = await fixture();
    const url = new URL(first.authorizationUrl);
    expect(url.origin + url.pathname).toBe(MOOMOO_OAUTH_CONTRACT.authorizationUrl);
    expect([...url.searchParams.keys()]).toEqual([
      "client_id", "code_challenge", "code_challenge_method", "redirect_uri", "response_type", "state",
    ]);
    expect(url.searchParams.get("code_challenge_method")).toBe("S256");
    expect(url.searchParams.get("code_challenge")).toBe(await moomooPkceChallenge(first.pending.codeVerifier));
    expect(url.searchParams.get("redirect_uri")).toBe(client.registeredRedirectUri);
    expect(first.state).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(first.pending.stateHash).toMatch(/^[a-f0-9]{64}$/);
    expect(first.state).not.toBe(second.state);
    expect(first.pending.codeVerifier).not.toBe(second.pending.codeVerifier);
    expect(first.authorizationUrl).not.toContain(first.pending.codeVerifier);
    expect(JSON.stringify(first.pending)).not.toContain(first.state);
  });

  it("constructs exact form bytes without egress and binds to the stored client", async () => {
    const test = await fixture();
    const request = await prepareMoomooAuthorizationCodeExchange({
      pending: test.pending, callbackUrl: test.callback.href, currentOwner: owner, nowMs: nowMs + 1_000,
    });
    expect(request.url).toBe("https://webapi.moomoo.com/oauth2/token");
    expect(request.headers).toEqual({ "Content-Type": "application/x-www-form-urlencoded" });
    expect(request.body).toBe(
      "grant_type=authorization_code&code=synthetic%2Bcode%2F%3D%26&client_id=synthetic-moomoo-client" +
      "&redirect_uri=https%3A%2F%2Fapp.example.test%2Fbrokers%2Fmoomoo%2Fcallback" +
      `&code_verifier=${test.pending.codeVerifier}`,
    );
    expect(request.redirect).toBe("error");
    expect(request.cache).toBe("no-store");
    expect(request.credentials).toBe("omit");
  });

  it.each([
    "http://app.example.test/callback", "https://user:password@app.example.test/callback",
    "https://app.example.test/callback?returnTo=evil", "https://app.example.test/callback#fragment",
    "https://app.example.test/a/../callback", "https://app.example.test/%2fcallback",
    " https://app.example.test/callback", "https://app.example.test:444/callback",
  ])("rejects unsafe or noncanonical registered callback %s", async (registeredRedirectUri) => {
    await expect(createMoomooAuthorization({ ...client, registeredRedirectUri }, owner, nowMs))
      .rejects.toThrow("invalid_moomoo_callback");
  });

  it("requires explicit local development for an exact loopback callback", async () => {
    const local = { ...client, registeredRedirectUri: "http://127.0.0.1:60355/callback" };
    await expect(createMoomooAuthorization(local, owner, nowMs)).rejects.toThrow();
    expect((await createMoomooAuthorization({ ...local, allowHttpLoopback: true }, owner, nowMs))
      .pending.client.registeredRedirectUri).toBe(local.registeredRedirectUri);
    await expect(createMoomooAuthorization({ ...client, registeredRedirectUri: "http://localhost.evil.test/callback", allowHttpLoopback: true }, owner, nowMs)).rejects.toThrow();
  });

  it("rejects substituted owner/session/connection/epoch, future or expired pending state", async () => {
    const test = await fixture();
    for (const field of ["userId", "sessionId", "connectionId"] as const) {
      await expect(prepareMoomooAuthorizationCodeExchange({
        pending: test.pending, callbackUrl: test.callback.href,
        currentOwner: { ...owner, [field]: "018f3c2a-4b67-7a89-8abc-123456789009" }, nowMs,
      })).rejects.toThrow("invalid_moomoo_authorization_binding");
    }
    for (const [currentOwner, time] of [[{ ...owner, deletionEpoch: 1 }, nowMs], [owner, nowMs - 1], [owner, nowMs + 300_000]] as const) {
      await expect(prepareMoomooAuthorizationCodeExchange({
        pending: test.pending, callbackUrl: test.callback.href, currentOwner, nowMs: time,
      })).rejects.toThrow("invalid_moomoo_authorization_binding");
    }
  });

  it("rejects callback redirects, duplicate fields, extra fields and swapped state", async () => {
    const test = await fixture();
    const callbacks = [
      test.callback.href.replace("app.example.test", "app.example.test.evil.test"),
      test.callback.href.replace("/callback?", "/other?"),
      `${test.callback.href}&state=${test.state}`, `${test.callback.href}&extra=value`,
      `${test.callback.href}#fragment`, test.callback.href.replace(test.state, "A".repeat(43)),
    ];
    for (const callbackUrl of callbacks) {
      await expect(prepareMoomooAuthorizationCodeExchange({
        pending: test.pending, callbackUrl, currentOwner: owner, nowMs,
      })).rejects.toThrow();
    }
  });

  it("collapses provider denial without reflecting provider details", async () => {
    const test = await fixture();
    test.callback.search = new URLSearchParams({ state: test.state, error: "access_denied", error_description: "synthetic-private-detail" }).toString();
    await expect(prepareMoomooAuthorizationCodeExchange({ pending: test.pending, callbackUrl: test.callback.href, currentOwner: owner, nowMs }))
      .rejects.toThrow(/^moomoo_authorization_denied$/);
  });

  it("constructs public-client refresh bytes without inventing a secret or scope", () => {
    const request = prepareMoomooRefresh(client, "synthetic+refresh/=&");
    expect(request.body).toBe("grant_type=refresh_token&refresh_token=synthetic%2Brefresh%2F%3D%26&client_id=synthetic-moomoo-client");
    expect(request.url).toBe(MOOMOO_OAUTH_CONTRACT.tokenUrl);
  });
});

describe("moomoo token response normalization", () => {
  const response = Object.freeze({
    access_token: "synthetic-access", token_type: "Bearer", expires_in: 7_200,
    refresh_token: "synthetic-refresh", scope: "quote:read trade:read accid:123456",
  });

  it("uses returned lifetime and granted scopes without inferring trading availability", () => {
    expect(normalizeMoomooTokenResponse(response, { grantType: "authorization_code", receivedAtMs: nowMs })).toEqual({
      accessToken: "synthetic-access", refreshToken: "synthetic-refresh",
      accessExpiresAtMs: nowMs + 7_200_000, grantedScopes: ["quote:read", "trade:read", "accid:123456"],
    });
  });

  it("retains the original refresh token when the response omits it", () => {
    // Exact documented refresh shape omits both refresh_token and token_type.
    const { refresh_token: _omittedRefresh, token_type: _omittedType, ...refreshed } = response;
    const context = { grantType: "refresh_token" as const, receivedAtMs: nowMs, previousRefreshToken: "synthetic-refresh" };
    expect(normalizeMoomooTokenResponse(refreshed, context).refreshToken).toBe("synthetic-refresh");
    expect(normalizeMoomooTokenResponse(response, context).refreshToken).toBe("synthetic-refresh");
    expect(() => normalizeMoomooTokenResponse({ ...response, refresh_token: "unexpected-rotation" }, context))
      .toThrow("unexpected_moomoo_refresh_rotation");
  });

  it.each([
    { error: "synthetic-secret-provider-detail" }, { expires_in: "7200" }, { expires_in: 0 },
    { expires_in: -1 }, { expires_in: Number.MAX_SAFE_INTEGER }, { access_token: "" },
    { access_token: "token\nheader" }, { refresh_token: null }, { token_type: "MAC" },
    { scope: "" }, { scope: "quote:read\ntrade:write" },
  ])("rejects malformed or unsuccessful responses without exposing payloads: %j", (override) => {
    expect(() => normalizeMoomooTokenResponse({ ...response, ...override }, { grantType: "authorization_code", receivedAtMs: nowMs }))
      .toThrow(/^invalid_moomoo_token_response$/);
  });
});
