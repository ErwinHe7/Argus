import { afterEach, describe, expect, it, vi } from "vitest";

import {
  clearManagedJwksForTesting,
  verifyManagedJwt,
} from "../../src/middleware/managed-jwks";
import { createTestRsaKey, signRs256 } from "../support/jwt";
import {
  AUTH0_AUDIENCE,
  AUTH0_ISSUER,
  auth0Claims,
} from "../support/security-fixtures";

describe("managed remote JWKS verification", () => {
  afterEach(() => {
    clearManagedJwksForTesting();
    vi.unstubAllGlobals();
  });

  it("reuses the managed resolver cache across protected requests", async () => {
    const key = createTestRsaKey("remote-managed-key");
    const fetcher = vi.fn(async () =>
      new Response(JSON.stringify({ keys: [key.publicJwk] }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
    vi.stubGlobal("fetch", fetcher);
    const token = signRs256(key, auth0Claims());
    const input = {
      token,
      issuer: AUTH0_ISSUER,
      audience: AUTH0_AUDIENCE,
      jwksUrl: `${AUTH0_ISSUER}.well-known/jwks.json`,
    };

    await verifyManagedJwt(input);
    await verifyManagedJwt(input);

    expect(fetcher).toHaveBeenCalledOnce();
  });
});
