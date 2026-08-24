import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { InactiveBootstrapPrincipalError } from "../../src/domains/session/repository";
import { createTestRsaKey } from "../support/jwt";
import {
  ACCESS_AUDIENCE,
  ADMIN_CLIENT_ID,
  CONSUMER_CLIENT_ID,
  accessToken,
  memberToken,
  testBindings,
} from "../support/security-fixtures";

describe("member and staff authorization", () => {
  const auth0Key = createTestRsaKey("auth0-admin-key");
  const accessKey = createTestRsaKey("access-key");

  function app(staffResult: unknown = {
    id: "018f3c2a-4b67-7a89-8abc-123456789010",
    auth0Subject: "auth0|staff-1",
    accessIdentity: "operator@ritual-investing.test",
    allowedClientId: ADMIN_CLIENT_ID,
    displayLabel: "Ritual Operator",
    revocationEpoch: 0,
  }) {
    const resolveStaff = vi.fn(async (input: {
      auth0Subject: string;
      accessIdentity: string;
      allowedClientId: string;
    }) => {
      if (staffResult === null || typeof staffResult !== "object") return staffResult;
      const row = staffResult as {
        auth0Subject: string;
        accessIdentity: string;
        allowedClientId: string;
      };
      return input.auth0Subject === row.auth0Subject
        && input.accessIdentity === row.accessIdentity
        && input.allowedClientId === row.allowedClientId
        ? staffResult
        : null;
    });
    return {
      resolveStaff,
      app: createApp({
        dependencies: {
          auth0Keys: [auth0Key.publicJwk],
          accessKeys: [accessKey.publicJwk],
          resolveStaff,
        },
      } as never),
    };
  }

  function adminHeaders(overrides: {
    access?: string | null;
    auth0?: string | null;
  } = {}) {
    const access = overrides.access === undefined ? accessToken(accessKey) : overrides.access;
    const auth0 = overrides.auth0 === undefined
      ? memberToken(auth0Key, {
        sub: "auth0|staff-1",
        azp: ADMIN_CLIENT_ID,
        permissions: ["admin:operations:read"],
      })
      : overrides.auth0;
    return {
      ...(access === null ? {} : { "cf-access-jwt-assertion": access }),
      ...(auth0 === null ? {} : { authorization: `Bearer ${auth0}` }),
    };
  }

  async function request(staffResult?: unknown, headers = adminHeaders()) {
    const fixture = app(staffResult);
    const response = await fixture.app.request(
      "https://admin-api.ritual-investing.test/v1/admin/session",
      { headers },
      testBindings(),
    );
    return { ...fixture, response };
  }

  it("requires both verified identities and returns no tenant ownership", async () => {
    const { response, resolveStaff } = await request();

    expect(response.status).toBe(200);
    const body = await response.json() as { data: Record<string, unknown> };
    expect(body.data).toMatchObject({ display_label: "Ritual Operator" });
    expect(JSON.stringify(body)).not.toContain("tenant");
    expect(resolveStaff).toHaveBeenCalledWith(
      {
        auth0Subject: "auth0|staff-1",
        accessIdentity: "operator@ritual-investing.test",
        allowedClientId: ADMIN_CLIENT_ID,
      },
      expect.any(Object),
    );
  });

  it("accepts only the configured Cloudflare Access application audience", async () => {
    expect((await request(undefined, adminHeaders({
      access: accessToken(accessKey, { aud: ACCESS_AUDIENCE }),
    }))).response.status).toBe(200);

    expect((await request(undefined, adminHeaders({
      access: accessToken(accessKey, { aud: [ACCESS_AUDIENCE, "another-access-app"] }),
    }))).response.status).toBe(401);
  });

  it("does not expose an admin route on the consumer API hostname", async () => {
    const fixture = app();
    const response = await fixture.app.request(
      "https://api.ritual-investing.test/v1/admin/session",
      { headers: adminHeaders() },
      testBindings(),
    );

    expect(response.status).toBe(404);
    expect(fixture.resolveStaff).not.toHaveBeenCalled();
  });

  it.each([
    ["Access-only", adminHeaders({ auth0: null })],
    ["missing Access", adminHeaders({ access: null })],
    ["consumer client", adminHeaders({ auth0: memberToken(auth0Key, {
      sub: "auth0|staff-1",
      azp: CONSUMER_CLIENT_ID,
      permissions: ["admin:operations:read"],
    }) })],
    ["mismatched identity", adminHeaders({ access: accessToken(accessKey, {
      email: "different@ritual-investing.test",
    }) })],
  ])("denies %s", async (_case, headers) => {
    const { response } = await request(undefined, headers);
    expect([401, 403]).toContain(response.status);
  });

  it("denies an inactive or unknown staff row", async () => {
    const { response } = await request(null);
    expect(response.status).toBe(403);
  });

  it("denies an Auth0 token minted before staff revocation", async () => {
    const now = Math.floor(Date.now() / 1000);
    const { response } = await request({
      id: "018f3c2a-4b67-7a89-8abc-123456789010",
      auth0Subject: "auth0|staff-1",
      accessIdentity: "operator@ritual-investing.test",
      allowedClientId: ADMIN_CLIENT_ID,
      displayLabel: "Ritual Operator",
      revocationEpoch: now,
    }, adminHeaders({
      auth0: memberToken(auth0Key, {
        sub: "auth0|staff-1",
        azp: ADMIN_CLIENT_ID,
        permissions: ["admin:operations:read"],
        iat: now - 10,
      }),
    }));
    expect(response.status).toBe(403);
  });

  it("maps an inactive bootstrap subject to a stable denial", async () => {
    const bootstrap = vi.fn(async () => {
      throw new InactiveBootstrapPrincipalError();
    });
    const response = await createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        sessionRepository: { bootstrap },
      },
    } as never).request("/v1/session/bootstrap", {
      method: "POST",
      headers: { authorization: `Bearer ${memberToken(auth0Key)}` },
    }, testBindings());

    expect(response.status).toBe(403);
    expect(bootstrap).toHaveBeenCalledOnce();
  });
});
