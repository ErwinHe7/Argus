import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { errorResponse } from "./responses.ts";

export function requireRecentAuth(
  maximumAgeSeconds = 300,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const principal = context.get("authPrincipal");
    const now = Math.floor(Date.now() / 1000);
    const authenticatedAt = principal?.authenticatedAt;
    if (
      principal === undefined ||
      authenticatedAt === undefined ||
      authenticatedAt > now + 30 ||
      now - authenticatedAt > maximumAgeSeconds
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
