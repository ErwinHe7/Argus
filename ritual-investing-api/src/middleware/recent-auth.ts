import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { errorResponse } from "./responses.ts";

export function requireRecentAuth(
  maximumAgeSeconds = 300,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const principal = context.get("authPrincipal");
    const now = Math.floor(Date.now() / 1000);
    if (
      principal === undefined ||
      principal.issuedAt > now + 30 ||
      now - principal.issuedAt > maximumAgeSeconds
    ) {
      return errorResponse(
        context,
        403,
        "recent_auth_required",
        "Recent authentication is required.",
      );
    }
    await next();
  };
}
