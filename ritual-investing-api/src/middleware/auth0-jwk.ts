import type { MiddlewareHandler } from "hono";
import { jwk } from "hono/jwk";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";
import type { JWTPayload } from "hono/utils/jwt/types";
import { z } from "zod";

import type { AppEnvironment } from "../app.ts";
import { errorResponse } from "./responses.ts";

const permissionSchema = z.string().min(1).max(128);

export type VerifiedAuth0Principal = Readonly<{
  subject: string;
  permissions: readonly string[];
  authorizedParty?: string;
  issuedAt: number;
}>;

export type AuthVariables = {
  jwtPayload: JWTPayload;
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
    const issuer = context.env.AUTH0_ISSUER;
    const audience = context.env.AUTH0_AUDIENCE;
    const verify = jwk({
      ...(keys === undefined
        ? { jwks_uri: context.env.AUTH0_JWKS_URL }
        : { keys: [...keys] }),
      alg: ["RS256"],
      verification: { iss: issuer, aud: audience, exp: true, iat: true, nbf: true },
    });

    try {
      await verify(context, async () => {
        const payload = context.get("jwtPayload");
        const parsed = z.object({
          iss: z.literal(issuer),
          aud: z.literal(audience),
          sub: z.string().min(1).max(255),
          permissions: z.array(permissionSchema).max(64),
          azp: z.string().min(1).max(255).optional(),
          iat: z.number().int().nonnegative(),
          exp: z.number().int().positive(),
        }).passthrough().safeParse(payload);
        if (!parsed.success || new Set(parsed.data.permissions).size !== parsed.data.permissions.length) {
          return;
        }
        context.set("authPrincipal", Object.freeze({
          subject: parsed.data.sub,
          permissions: Object.freeze([...parsed.data.permissions]),
          issuedAt: parsed.data.iat,
          ...(parsed.data.azp === undefined ? {} : { authorizedParty: parsed.data.azp }),
        }));
        await next();
      });
    } catch {
      return errorResponse(
        context,
        401,
        "unauthorized",
        "A valid API access token is required.",
      );
    }

    if (context.get("authPrincipal") === undefined) {
      return errorResponse(
        context,
        401,
        "unauthorized",
        "A valid API access token is required.",
      );
    }
  };
}
