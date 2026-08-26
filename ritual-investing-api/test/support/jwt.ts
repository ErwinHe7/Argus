import { createHmac, generateKeyPairSync, sign, type KeyObject } from "node:crypto";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

export type TestRsaKey = {
  kid: string;
  privateKey: KeyObject;
  publicJwk: HonoJsonWebKey & { kid: string; alg: "RS256"; use: "sig" };
};

function base64Url(value: string | Buffer): string {
  return Buffer.from(value).toString("base64url");
}

export function createTestRsaKey(kid = "ritual-test-key"): TestRsaKey {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", {
    modulusLength: 2048,
  });
  const exported = publicKey.export({ format: "jwk" });
  if (exported.kty === undefined || exported.n === undefined || exported.e === undefined) {
    throw new Error("RSA public JWK is incomplete");
  }
  return {
    kid,
    privateKey,
    publicJwk: {
      kty: exported.kty,
      n: exported.n,
      e: exported.e,
      kid,
      alg: "RS256",
      use: "sig",
    },
  };
}

export function signRs256(
  key: TestRsaKey,
  payload: Record<string, unknown>,
  header: Record<string, unknown> = {},
): string {
  const protectedHeader = base64Url(
    JSON.stringify({ alg: "RS256", typ: "JWT", kid: key.kid, ...header }),
  );
  const encodedPayload = base64Url(JSON.stringify(payload));
  const input = `${protectedHeader}.${encodedPayload}`;
  const signature = sign("RSA-SHA256", Buffer.from(input), key.privateKey);
  return `${input}.${signature.toString("base64url")}`;
}

export function signHs256(payload: Record<string, unknown>): string {
  const protectedHeader = base64Url(
    JSON.stringify({ alg: "HS256", typ: "JWT", kid: "symmetric-test-key" }),
  );
  const encodedPayload = base64Url(JSON.stringify(payload));
  const input = `${protectedHeader}.${encodedPayload}`;
  const signature = createHmac("sha256", "not-a-real-secret").update(input).digest("base64url");
  return `${input}.${signature}`;
}
