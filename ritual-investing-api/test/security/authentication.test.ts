import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey, signHs256, signRs256 } from "../support/jwt";
import {
  AUTH0_AUDIENCE,
  AUTH0_ISSUER,
  auth0Claims,
  memberToken,
  sessionSnapshot,
  testBindings,
} from "../support/security-fixtures";

describe("Auth0 API access-token verification", () => {
  const auth0Key = createTestRsaKey();

  function app() {
    return createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        sessionRepository: {
          bootstrap: async () => sessionSnapshot,
        },
      },
    } as never);
  }

  async function bootstrap(token: string) {
    return app().request(
      "/v1/session/bootstrap",
      { method: "POST", headers: { authorization: `Bearer ${token}` } },
      testBindings(),
    );
  }

  it("accepts a real RS256 token with the exact API contract", async () => {
    const response = await bootstrap(memberToken(auth0Key));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ data: sessionSnapshot });
  });

  it.each([
    ["wrong issuer", signRs256(auth0Key, auth0Claims({ iss: "https://wrong.example/" }))],
    ["wrong audience", signRs256(auth0Key, auth0Claims({ aud: "ritual-mobile-client" }))],
    ["expired", signRs256(auth0Key, auth0Claims({ exp: Math.floor(Date.now() / 1000) - 1 }))],
    ["future", signRs256(auth0Key, auth0Claims({ iat: Math.floor(Date.now() / 1000) + 300 }))],
    ["unexpected algorithm", signHs256(auth0Claims())],
    ["malformed", "not-a-jwt"],
  ])("denies a %s token with the stable envelope", async (_case, token) => {
    const response = await bootstrap(token);

    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toMatchObject({
      error: { code: "unauthorized", field_errors: [], retryable: false },
    });
  });

  it("denies a typical ID token and a token without the required permission", async () => {
    const idToken = signRs256(auth0Key, auth0Claims({
      aud: "ritual-mobile-client",
      permissions: undefined,
    }));
    expect((await bootstrap(idToken)).status).toBe(401);

    expect((await bootstrap(signRs256(auth0Key, auth0Claims({
      permissions: undefined,
    })))).status).toBe(401);
    expect((await bootstrap(signRs256(auth0Key, auth0Claims({
      sub: undefined,
    })))).status).toBe(401);

    const response = await bootstrap(memberToken(auth0Key, { permissions: ["read:self"] }));
    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toMatchObject({ error: { code: "forbidden" } });
  });

  it("rejects extra audiences and an unbounded permissions claim", async () => {
    expect((await bootstrap(memberToken(auth0Key, {
      aud: [AUTH0_AUDIENCE, "https://extra.example"],
    }))).status).toBe(401);
    expect((await bootstrap(memberToken(auth0Key, {
      iss: AUTH0_ISSUER,
      permissions: Array.from({ length: 65 }, (_, index) => `permission:${index}`),
    }))).status).toBe(401);
  });
});
