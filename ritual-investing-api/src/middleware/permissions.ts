import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { errorResponse } from "./responses.ts";

export function requirePermission(permission: string): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const principal = context.get("authPrincipal");
    if (principal === undefined || !principal.permissions.includes(permission)) {
      return errorResponse(
        context,
        403,
        "forbidden",
        "The authenticated principal does not have permission for this operation.",
      );
    }
    await next();
  };
}
