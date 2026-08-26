import {
  createLocalJWKSet,
  createRemoteJWKSet,
  jwtVerify,
  type JSONWebKeySet,
  type JWTPayload,
  type JWTVerifyGetKey,
} from "jose";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

const remoteResolvers = new Map<string, JWTVerifyGetKey>();

function remoteResolver(url: string): JWTVerifyGetKey {
  const existing = remoteResolvers.get(url);
  if (existing !== undefined) return existing;
  const resolver = createRemoteJWKSet(new URL(url), {
    timeoutDuration: 3_000,
    cooldownDuration: 30_000,
    cacheMaxAge: 10 * 60_000,
  });
  remoteResolvers.set(url, resolver);
  return resolver;
}

export function bearerToken(value: string): string | null {
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(
    value,
  );
  return match?.[1] ?? null;
}

export async function verifyManagedJwt(input: {
  token: string;
  issuer: string;
  audience: string;
  jwksUrl: string;
  keys?: readonly HonoJsonWebKey[];
}): Promise<JWTPayload> {
  const resolver =
    input.keys === undefined
      ? remoteResolver(input.jwksUrl)
      : createLocalJWKSet({
          keys: [...input.keys],
        } as unknown as JSONWebKeySet);
  const result = await jwtVerify(input.token, resolver, {
    algorithms: ["RS256"],
    issuer: input.issuer,
    audience: input.audience,
  });
  return result.payload;
}

export function clearManagedJwksForTesting(): void {
  remoteResolvers.clear();
}
