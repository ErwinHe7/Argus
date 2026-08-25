import type { Context, MiddlewareHandler } from "hono";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

import type { AppEnvironment } from "../../app.ts";
import {
  accountTenant,
  type AccountResolver,
} from "../../middleware/account-tenant.ts";
import { auth0Jwk } from "../../middleware/auth0-jwk.ts";
import { requireMemberClient } from "../../middleware/member-client.ts";
import { requirePermission } from "../../middleware/permissions.ts";
import {
  preAuthRateLimit,
  tenantRateLimit,
} from "../../middleware/rate-limit.ts";
import {
  consumerBodyLimit,
  requestMediaBoundary,
} from "../../middleware/security-headers.ts";
import type { MemberContext } from "../accounts/repository.ts";
import {
  createPostgresSimulationRepository,
  type SimulationRepository,
} from "./repository.ts";

export type SimulationRouteDependencies = {
  auth0Keys?: readonly HonoJsonWebKey[];
  accountResolver?: AccountResolver;
  simulationRepository?: SimulationRepository;
};

function methodAware(
  method: string,
  middleware: MiddlewareHandler<AppEnvironment>,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    if (context.req.method !== method.toUpperCase()) return next();
    return middleware(context, next);
  };
}

export function simulationSecurity(
  dependencies: SimulationRouteDependencies,
  method: string,
): MiddlewareHandler<AppEnvironment>[] {
  return [
    preAuthRateLimit("RL_COMMAND"),
    auth0Jwk(dependencies.auth0Keys),
    requireMemberClient,
    requirePermission("write:self"),
    requirePermission("simulate:self"),
    requestMediaBoundary,
    consumerBodyLimit,
    accountTenant(dependencies.accountResolver),
    tenantRateLimit("RL_COMMAND"),
  ].map((middleware) => methodAware(method, middleware));
}

export function simulationAccess(
  context: Context<AppEnvironment>,
  dependencies: SimulationRouteDependencies,
): { member: MemberContext; repository: SimulationRepository } | undefined {
  const account = context.get("accountTenant");
  const principal = context.get("authPrincipal");
  const repository =
    dependencies.simulationRepository ??
    (context.env.RUNTIME_DATABASE_URL === undefined
      ? undefined
      : createPostgresSimulationRepository(context.env.RUNTIME_DATABASE_URL));
  return account === undefined ||
    principal === undefined ||
    repository === undefined
    ? undefined
    : {
        member: { ...account, subject: principal.subject },
        repository,
      };
}
