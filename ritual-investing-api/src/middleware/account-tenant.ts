import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { resolveAccountContext, type ResolvedAccountContext } from "../db/client.ts";
import { errorResponse } from "./responses.ts";

export type AccountTenantVariables = {
  accountTenant: ResolvedAccountContext;
};

export type AccountResolver = (
  subject: string,
  environment: AppEnvironment["Bindings"],
) => Promise<ResolvedAccountContext | null>;

const defaultResolver: AccountResolver = async (subject, environment) => {
  if (environment.IDENTITY_DATABASE_URL === undefined) {
    throw new Error("identity_database_binding_missing");
  }
  return resolveAccountContext(environment.IDENTITY_DATABASE_URL, subject);
};

export function accountTenant(
  resolver: AccountResolver = defaultResolver,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const principal = context.get("authPrincipal");
    if (principal === undefined) {
      return errorResponse(context, 401, "unauthorized", "A valid API access token is required.");
    }
    try {
      const resolved = await resolver(principal.subject, context.env);
      if (resolved === null) {
        return errorResponse(
          context,
          403,
          "account_inactive",
          "The account is not active.",
        );
      }
      context.set("accountTenant", Object.freeze(resolved));
      await next();
    } catch {
      return errorResponse(
        context,
        503,
        "service_unavailable",
        "Identity resolution is temporarily unavailable.",
        { retryable: true },
      );
    }
  };
}
