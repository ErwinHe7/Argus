import type { MiddlewareHandler } from "hono";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

import type { AppEnvironment } from "../../app.ts";
import { auth0Jwk } from "../../middleware/auth0-jwk.ts";
import {
  authorizeStaff,
  cloudflareAccessJwk,
  requireAdminHost,
  type StaffResolver,
} from "../../middleware/cloudflare-access.ts";
import { requirePermission } from "../../middleware/permissions.ts";
import {
  preAuthRateLimit,
  staffRateLimit,
  type RateLimitClass,
} from "../../middleware/rate-limit.ts";
import {
  adminBodyLimit,
  requestMediaBoundary,
} from "../../middleware/security-headers.ts";

export type AdminRouteDependencies = {
  auth0Keys?: readonly HonoJsonWebKey[];
  accessKeys?: readonly HonoJsonWebKey[];
  resolveStaff?: StaffResolver;
};

export function adminSecurity(
  dependencies: AdminRouteDependencies,
  method: string,
  permission: string,
  rate: RateLimitClass,
): MiddlewareHandler<AppEnvironment>[] {
  return [
    requireAdminHost,
    preAuthRateLimit(rate),
    requestMediaBoundary,
    adminBodyLimit,
    cloudflareAccessJwk(dependencies.accessKeys),
    auth0Jwk(dependencies.auth0Keys),
    requirePermission(permission),
    authorizeStaff(dependencies.resolveStaff),
    staffRateLimit(rate),
  ].map((middleware) => async (context, next) => {
    if (context.req.method !== method.toUpperCase()) return next();
    return middleware(context, next);
  });
}
