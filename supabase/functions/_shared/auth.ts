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
    amr: z.array(
      z.object({
        method: z.string().min(1).max(64),
        timestamp: z.number().int().nonnegative(),
      }).passthrough(),
    ).max(16).optional(),
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
      // Hosted projects may use Supabase's one-hour JWT lifetime. `exp` is
      // still mandatory; this cap prevents unusually old signed tokens while
      // allowing a valid token throughout its configured lifetime.
      maxTokenAge: "65m",
    });
    const claims = verifiedClaimsSchema.parse(payload);
    const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (!audiences.includes(audience)) throw new Error("wrong_audience");
    const now = Math.floor(Date.now() / 1_000);
    const authenticationTimes = [
      ...(claims.auth_time === undefined ? [] : [claims.auth_time]),
      ...(claims.amr ?? []).map((entry) => entry.timestamp),
    ];
    if (authenticationTimes.some((timestamp) => timestamp > now + 30)) {
      throw new Error("future_authentication_time");
    }
    const authenticatedAt = authenticationTimes.length === 0
      ? undefined
      : Math.max(...authenticationTimes);
    return Object.freeze({
      userId: claims.sub,
      sessionId: claims.session_id,
      aal: claims.aal,
      issuedAt: claims.iat,
      ...(authenticatedAt === undefined
        ? {}
        : { authenticatedAt }),
    });
  };
}
