import type { Context, MiddlewareHandler } from "hono";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

import type { AppEnvironment } from "../../app.ts";
import {
  accountTenant,
  type AccountResolver,
} from "../../middleware/account-tenant.ts";
import { auth0Jwk } from "../../middleware/auth0-jwk.ts";
import { requirePermission } from "../../middleware/permissions.ts";
import {
  preAuthRateLimit,
  subjectRateLimit,
} from "../../middleware/rate-limit.ts";
import {
  consumerBodyLimit,
  requestMediaBoundary,
} from "../../middleware/security-headers.ts";
import { requireRecentAuth } from "../../middleware/recent-auth.ts";
import {
  createPostgresMemberRepository,
  type MemberContext,
  type MemberRepository,
} from "./repository.ts";

export type MemberRouteDependencies = {
  auth0Keys?: readonly HonoJsonWebKey[];
  accountResolver?: AccountResolver;
  memberRepository?: MemberRepository;
};

export function memberSecurity(
  dependencies: MemberRouteDependencies,
  write: boolean,
  method: string,
): MiddlewareHandler<AppEnvironment>[] {
  const rate = write ? "RL_MEMBER_WRITE" : "RL_MEMBER_READ";
  return [
    preAuthRateLimit(rate),
    auth0Jwk(dependencies.auth0Keys),
    requirePermission(write ? "write:self" : "read:self"),
    subjectRateLimit(rate),
    requestMediaBoundary,
    consumerBodyLimit,
    accountTenant(dependencies.accountResolver),
  ].map((middleware) => async (context, next) => {
    if (context.req.method !== method.toUpperCase()) return next();
    return middleware(context, next);
  });
}

export function privacySecurity(
  dependencies: MemberRouteDependencies,
  method: string,
): MiddlewareHandler<AppEnvironment>[] {
  return [
    preAuthRateLimit("RL_SENSITIVE"),
    auth0Jwk(dependencies.auth0Keys),
    requirePermission("privacy:self"),
    subjectRateLimit("RL_SENSITIVE"),
    requestMediaBoundary,
    consumerBodyLimit,
    requireRecentAuth(300),
    accountTenant(dependencies.accountResolver),
  ].map((middleware) => async (context, next) => {
    if (context.req.method !== method.toUpperCase()) return next();
    return middleware(context, next);
  });
}

export function sensitiveMemberSecurity(
  dependencies: MemberRouteDependencies,
  method: string,
): MiddlewareHandler<AppEnvironment>[] {
  return [
    preAuthRateLimit("RL_SENSITIVE"),
    auth0Jwk(dependencies.auth0Keys),
    requirePermission("write:self"),
    subjectRateLimit("RL_SENSITIVE"),
    requestMediaBoundary,
    consumerBodyLimit,
    accountTenant(dependencies.accountResolver),
  ].map((middleware) => async (context, next) => {
    if (context.req.method !== method.toUpperCase()) return next();
    return middleware(context, next);
  });
}

export function memberAccess(
  context: Context<AppEnvironment>,
  dependencies: MemberRouteDependencies,
): { member: MemberContext; repository: MemberRepository } | undefined {
  const account = context.get("accountTenant");
  const principal = context.get("authPrincipal");
  const repository =
    dependencies.memberRepository ??
    (context.env.RUNTIME_DATABASE_URL === undefined
      ? undefined
      : createPostgresMemberRepository(context.env.RUNTIME_DATABASE_URL));
  return account === undefined ||
    principal === undefined ||
    repository === undefined
    ? undefined
    : {
        member: { ...account, subject: principal.subject },
        repository,
      };
}

export function versionFrom(value: string | undefined): number | undefined {
  const match = value?.match(/^"v([1-9]\d*)"$/);
  return match === null || match === undefined ? undefined : Number(match[1]);
}
