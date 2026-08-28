import {
  createRemoteJWKSet,
  jwtVerify,
  type JWTVerifyGetKey,
} from "jose";
import { z } from "zod";

import type {
  RetainedTokenVerifier,
  VerifiedSupabasePrincipal,
} from "../../../ritual-investing-api/src/retained-app.ts";

const uuid = z.string().uuid();
const permission = z.enum([
  "read:self",
  "write:self",
  "privacy:self",
  "admin:operations:read",
  "admin:operations:write",
  "admin:privacy:read",
  "admin:privacy:write",
  "admin:media:read",
  "admin:media:write",
  "admin:editorial:read",
  "admin:editorial:write",
  "admin:editorial:review",
  "admin:editorial:publish",
  "admin:audit:read",
  "admin:catalog:read",
  "admin:catalog:write",
  "admin:coven:verify",
  "admin:moderation:read",
  "admin:moderation:write",
]);

const verifiedClaimsSchema = z
  .object({
    iss: z.string().url(),
    aud: z.union([z.literal("authenticated"), z.array(z.string()).min(1)]),
    sub: uuid,
    session_id: uuid,
    role: z.literal("authenticated"),
    aal: z.enum(["aal1", "aal2"]),
    iat: z.number().int().nonnegative(),
    exp: z.number().int().positive(),
    auth_time: z.number().int().nonnegative().optional(),
    app_metadata: z
      .object({ permissions: z.array(permission).max(32).optional() })
      .passthrough()
      .optional(),
  })
  .passthrough();

export type SupabaseJwtVerifierConfig = Readonly<{
  supabaseUrl: string;
  audience?: string;
  keyResolver?: JWTVerifyGetKey;
}>;

function issuerFor(supabaseUrl: string): string {
  const url = new URL(supabaseUrl);
  url.pathname = `${url.pathname.replace(/\/$/, "")}/auth/v1`;
  return url.toString().replace(/\/$/, "");
}

/**
 * Verify at the Edge boundary before any repository, provider, or database
 * adapter receives identity. Authorization data is read only from immutable
 * token claims or `app_metadata`; `user_metadata` is deliberately ignored.
 */
export function createSupabaseAccessTokenVerifier(
  config: SupabaseJwtVerifierConfig,
): RetainedTokenVerifier {
  const issuer = issuerFor(config.supabaseUrl);
  const audience = config.audience ?? "authenticated";
  const jwks =
    config.keyResolver ??
    createRemoteJWKSet(
      new URL(`${issuer}/.well-known/jwks.json`),
      { cooldownDuration: 30_000, cacheMaxAge: 600_000, timeoutDuration: 5_000 },
    );
  return async (token): Promise<VerifiedSupabasePrincipal> => {
    const { payload } = await jwtVerify(token, jwks, {
      issuer,
      audience,
      algorithms: ["ES256", "RS256"],
      clockTolerance: 30,
      maxTokenAge: "20m",
    });
    const claims = verifiedClaimsSchema.parse(payload);
    const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (!audiences.includes(audience)) throw new Error("wrong_audience");
    return Object.freeze({
      userId: claims.sub,
      sessionId: claims.session_id,
      aal: claims.aal,
      issuedAt: claims.iat,
      ...(claims.auth_time === undefined
        ? {}
        : { authenticatedAt: claims.auth_time }),
    });
  };
}
