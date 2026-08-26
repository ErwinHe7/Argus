import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { createTestRsaKey } from "../support/jwt";
import {
  memberToken,
  sessionSnapshot,
  testBindings,
} from "../support/security-fixtures";

describe("POST /v1/session/bootstrap", () => {
  const auth0Key = createTestRsaKey("session-key");

  function app(bootstrap = vi.fn(async () => sessionSnapshot)) {
    return {
      bootstrap,
      app: createApp({
        dependencies: {
          auth0Keys: [auth0Key.publicJwk],
          sessionRepository: { bootstrap },
        },
      } as never),
    };
  }

  it("uses only the verified subject and omits tenant ownership", async () => {
    const fixture = app();
    const response = await fixture.app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: { authorization: `Bearer ${memberToken(auth0Key)}` },
    }, testBindings());

    expect(response.status).toBe(200);
    expect(fixture.bootstrap).toHaveBeenCalledWith("auth0|member-1");
    const body = await response.json() as { data: unknown };
    expect(body.data).toEqual(sessionSnapshot);
    expect(JSON.stringify(body)).not.toContain("tenant_id");
  });

  it("accepts an edge-shaped empty POST without a media type", async () => {
    const fixture = app();
    const response = await fixture.app.request(new Request(
      "https://api.ritual-investing.test/v1/session/bootstrap",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key)}`,
          "content-length": "0",
        },
        body: new Uint8Array(0),
      },
    ), undefined, testBindings());

    expect(response.status).toBe(200);
    expect(fixture.bootstrap).toHaveBeenCalledWith("auth0|member-1");
  });

  it("rejects a request body and unsupported encodings before the repository", async () => {
    const fixture = app();
    const unsupportedType = await fixture.app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        "content-type": "text/plain",
      },
      body: "tenant_id=attacker",
    }, testBindings());
    expect(unsupportedType.status).toBe(415);

    const unsupportedEncoding = await fixture.app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        "content-type": "application/json",
        "content-encoding": "gzip",
      },
      body: "{}",
    }, testBindings());
    expect(unsupportedEncoding.status).toBe(415);
    expect(fixture.bootstrap).not.toHaveBeenCalled();
  });

  it("rejects even valid JSON ownership input because bootstrap has no body", async () => {
    const fixture = app();
    const response = await fixture.app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ tenant_id: "018f3c2a-4b67-7a89-8abc-123456789099" }),
    }, testBindings());

    expect(response.status).toBe(422);
    expect(fixture.bootstrap).not.toHaveBeenCalled();
  });

  it("does not sniff a body whose media type is missing", async () => {
    const fixture = app();
    const response = await fixture.app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: { authorization: `Bearer ${memberToken(auth0Key)}` },
      body: "{}",
    }, testBindings());

    expect(response.status).toBe(415);
    expect(fixture.bootstrap).not.toHaveBeenCalled();
  });

  it("enforces the 64 KiB consumer JSON cap", async () => {
    const fixture = app();
    const response = await fixture.app.request("/v1/session/bootstrap", {
      method: "POST",
      headers: {
        authorization: `Bearer ${memberToken(auth0Key)}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ payload: "x".repeat(65_536) }),
    }, testBindings());
    expect(response.status).toBe(413);
    expect(fixture.bootstrap).not.toHaveBeenCalled();
  });
});
