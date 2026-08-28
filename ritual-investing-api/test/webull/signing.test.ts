import { describe, expect, it } from "vitest";

import fixture from "../fixtures/webull/signing.v1.json";
import {
  exactJsonBody,
  signWebullRequest,
} from "../../../supabase/functions/_shared/webull/signing.ts";

describe("Webull exact-byte signing", () => {
  it("reproduces the official published fixture", () => {
    const signature = signWebullRequest({
      path: fixture.path,
      query: fixture.query,
      headers: fixture.headers,
      bodyBytes: new TextEncoder().encode(fixture.body),
      appSecret: fixture.app_secret,
    });
    expect(signature.bodyMd5).toBe(fixture.expected_body_md5);
    expect(signature.value).toBe(fixture.expected_signature);
  });

  it("strictly percent-encodes RFC3986 punctuation and signs the sent bytes", () => {
    const bodyBytes = exactJsonBody({ note: "same bytes" });
    const signature = signWebullRequest({
      path: "/oauth-openapi/test",
      query: { note: "!'()*" },
      headers: {
        host: "oauth-open-api.sandbox.webull.com",
        "x-app-key": "synthetic-app-key",
        "x-signature-algorithm": "HMAC-SHA1",
        "x-signature-nonce": "0123456789abcdef0123456789abcdef",
        "x-signature-version": "1.0",
        "x-timestamp": "2026-08-28T12:00:00Z",
      },
      bodyBytes,
      appSecret: "synthetic-app-secret-value",
    });
    expect(signature.encoded).toContain("%21%27%28%29%2A");
    expect(signature.bodyMd5).toMatch(/^[A-F0-9]{32}$/);

    const changed = signWebullRequest({
      path: "/oauth-openapi/test",
      query: { note: "!'()*" },
      headers: {
        host: "oauth-open-api.sandbox.webull.com",
        "x-app-key": "synthetic-app-key",
        "x-signature-algorithm": "HMAC-SHA1",
        "x-signature-nonce": "0123456789abcdef0123456789abcdef",
        "x-signature-version": "1.0",
        "x-timestamp": "2026-08-28T12:00:00Z",
      },
      bodyBytes: new Uint8Array([...bodyBytes, 0x20]),
      appSecret: "synthetic-app-secret-value",
    });
    expect(changed.value).not.toBe(signature.value);
  });

  it("rejects alternate ports, traversal, absolute URLs, and header/query collisions", () => {
    const base = {
      query: {},
      headers: {
        host: "oauth-open-api.sandbox.webull.com",
        "x-app-key": "synthetic-app-key",
        "x-signature-algorithm": "HMAC-SHA1",
        "x-signature-nonce": "0123456789abcdef0123456789abcdef",
        "x-signature-version": "1.0",
        "x-timestamp": "2026-08-28T12:00:00Z",
      },
      appSecret: "synthetic-app-secret-value",
    } as const;
    for (
      const path of [
        "https://attacker.test/x",
        "//attacker.test/x",
        "/a/../b",
        "/a%2Fb",
      ]
    ) {
      expect(() => signWebullRequest({ ...base, path })).toThrow();
    }
    expect(() =>
      signWebullRequest({
        ...base,
        path: "/safe",
        query: { host: "attacker.test" },
      })
    ).toThrow("duplicate_webull_signing_name");
  });
});
