import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  SignJWT,
} from "jose";
import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1.0.15";

import { createSupabaseAccessTokenVerifier } from "../_shared/auth.ts";
import { createSupabaseDatabasePool } from "../_shared/database.ts";
import { rewriteSupabaseFunctionRequest } from "../_shared/http.ts";

const supabaseUrl = "https://project-ref.supabase.co";
const issuer = `${supabaseUrl}/auth/v1`;
const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";

async function fixture() {
  const { privateKey, publicKey } = await generateKeyPair("RS256");
  const jwk = await exportJWK(publicKey);
  Object.assign(jwk, { kid: "u3-test", alg: "RS256", use: "sig" });
  const verify = createSupabaseAccessTokenVerifier({
    supabaseUrl,
    keyResolver: createLocalJWKSet({ keys: [jwk] }),
  });
  const sign = (
    overrides: Record<string, unknown> = {},
    registered: { audience?: string; expiration?: number } = {},
  ) => {
    const now = Math.floor(Date.now() / 1_000);
    return new SignJWT({
      role: "authenticated",
      session_id: sessionId,
      aal: "aal1",
      user_metadata: { permissions: ["admin:operations:write"] },
      ...overrides,
    })
      .setProtectedHeader({ alg: "RS256", kid: "u3-test" })
      .setIssuer(issuer)
      .setAudience(registered.audience ?? "authenticated")
      .setSubject(userId)
      .setIssuedAt(now - 5)
      .setExpirationTime(registered.expiration ?? now + 300)
      .sign(privateKey);
  };
  return { verify, sign };
}

Deno.test("verified Supabase claims become immutable request identity", async () => {
  const { verify, sign } = await fixture();
  const principal = await verify(await sign());

  assertEquals(principal.userId, userId);
  assertEquals(principal.sessionId, sessionId);
  assertEquals(principal.aal, "aal1");
  assertEquals(Object.isFrozen(principal), true);
  assertEquals("permissions" in principal, false);
});

Deno.test("wrong audience, expiry, and malformed tokens fail closed", async () => {
  const { verify, sign } = await fixture();
  const wrongAudience = await sign({}, { audience: "wrong-audience" });
  const expired = await sign({}, { expiration: 1 });
  await assertRejects(() => verify(wrongAudience));
  await assertRejects(() => verify(expired));
  await assertRejects(() => verify("not-a-jwt"));
});

Deno.test("function prefix rewrite preserves zero-byte POST transport", async () => {
  const request = new Request(
    "https://project-ref.supabase.co/functions/v1/api/v1/session/bootstrap",
    {
      method: "POST",
      headers: { "content-length": "0" },
      body: new Uint8Array(0),
    },
  );
  const rewritten = rewriteSupabaseFunctionRequest(request, "api");
  assertEquals(new URL(rewritten.url).pathname, "/v1/session/bootstrap");
  assertEquals(rewritten.headers.get("content-length"), "0");
  assertEquals(await rewritten.arrayBuffer(), new ArrayBuffer(0));
});

Deno.test("database pool accepts only the dedicated Edge login", async () => {
  assertThrows(
    () =>
      createSupabaseDatabasePool(
        "postgresql://postgres.project-ref:secret@pooler.example.test:6543/postgres",
      ),
    Error,
    "invalid_supabase_database_role",
  );
  const pool = createSupabaseDatabasePool(
    "postgresql://argus_edge.project-ref:secret@pooler.example.test:6543/postgres",
  );
  await pool.end();
});
