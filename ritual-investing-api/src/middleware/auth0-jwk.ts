import type { MiddlewareHandler } from "hono";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";
import { z } from "zod";

import type { AppEnvironment } from "../app.ts";
import { bearerToken, verifyManagedJwt } from "./managed-jwks.ts";
import { errorResponse } from "./responses.ts";

const permissionSchema = z.string().min(1).max(128);
const authenticatedAtClaim = "https://ritual-investing.app/authenticated_at";

export type VerifiedAuth0Principal = Readonly<{
  subject: string;
  permissions: readonly string[];
  authorizedParty?: string;
  issuedAt: number;
  authenticatedAt?: number;
}>;

export type AuthVariables = {
  authPrincipal: VerifiedAuth0Principal;
};

export function auth0Jwk(
  keys?: readonly HonoJsonWebKey[],
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const authorization = context.req.header("authorization");
    if (authorization === undefined || authorization.length > 16_391) {
      return errorResponse(
        context,
        401,
        "unauthorized",
        "A valid API access token is required.",
      );
    }
    const token = bearerToken(authorization);
    if (token === null)
      return errorResponse(
        context,
        401,
        "unauthorized",
        "A valid API access token is required.",
      );
    const issuer = context.env.AUTH0_ISSUER;
    const audience = context.env.AUTH0_AUDIENCE;
    const userinfoAudience = `${issuer}userinfo`;

    try {
      const payload = await verifyManagedJwt({
        token,
        issuer,
        audience,
        jwksUrl: context.env.AUTH0_JWKS_URL,
        ...(keys === undefined ? {} : { keys }),
      });
      const parsed = z
        .object({
          iss: z.literal(issuer),
          aud: z.union([
            z.literal(audience),
            z.tuple([z.literal(audience), z.literal(userinfoAudience)]),
            z.tuple([z.literal(userinfoAudience), z.literal(audience)]),
          ]),
          sub: z.string().min(1).max(255),
          permissions: z.array(permissionSchema).max(64),
          azp: z.string().min(1).max(255).optional(),
          iat: z.number().int().nonnegative(),
          auth_time: z.number().int().nonnegative().optional(),
          [authenticatedAtClaim]: z.number().int().nonnegative().optional(),
          exp: z.number().int().positive(),
        })
        .passthrough()
        .safeParse(payload);
      if (
        !parsed.success ||
        new Set(parsed.data.permissions).size !==
          parsed.data.permissions.length ||
        parsed.data.iat > Math.floor(Date.now() / 1_000) + 60
      )
        throw new Error("invalid_claims");
      const authenticatedAt =
        parsed.data[authenticatedAtClaim] ?? parsed.data.auth_time;
      context.set(
        "authPrincipal",
        Object.freeze({
          subject: parsed.data.sub,
          permissions: Object.freeze([...parsed.data.permissions]),
          issuedAt: parsed.data.iat,
          ...(authenticatedAt === undefined
            ? {}
            : { authenticatedAt }),
          ...(parsed.data.azp === undefined
            ? {}
            : { authorizedParty: parsed.data.azp }),
        }),
      );
    } catch {
      return errorResponse(
        context,
        401,
        "unauthorized",
        "A valid API access token is required.",
      );
    }

    await next();
  };
}
