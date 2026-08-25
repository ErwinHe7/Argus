import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { errorResponse } from "./responses.ts";

function memberClientAllowlist(value: string): ReadonlySet<string> {
  return new Set(
    value
      .split(",")
      .map((clientId) => clientId.trim())
      .filter((clientId) => clientId.length > 0),
  );
}

export const requireMemberClient: MiddlewareHandler<AppEnvironment> = async (
  context,
  next,
) => {
  const authorizedParty = context.get("authPrincipal")?.authorizedParty;
  if (
    authorizedParty === undefined ||
    !memberClientAllowlist(context.env.AUTH0_MEMBER_CLIENT_IDS).has(
      authorizedParty,
    )
  ) {
    return errorResponse(
      context,
      403,
      "forbidden",
      "This client is not authorized for member operations.",
    );
  }
  await next();
};
