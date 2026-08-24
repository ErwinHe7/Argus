import type { MiddlewareHandler } from "hono";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";
import { Pool } from "@neondatabase/serverless";

import type { AppEnvironment } from "../../app.ts";
import type { DatabasePoolFactory } from "../../db/client.ts";
import { auth0Jwk } from "../../middleware/auth0-jwk.ts";
import {
  authorizeStaff,
  cloudflareAccessJwk,
  requireAdminHost,
  type StaffResolver,
} from "../../middleware/cloudflare-access.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { errorResponse } from "../../middleware/responses.ts";
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
  auditDeniedAdminAttempt?: AdminDenialAuditor;
};

export type AdminDenialInput = {
  actorStaffId: string;
  permission: string;
  method: string;
  requestId: string;
};

export type AdminDenialAuditor = (
  input: AdminDenialInput,
  environment: AppEnvironment["Bindings"],
) => Promise<void>;

const adminDenialPoolFactory: DatabasePoolFactory = (databaseUrl) =>
  new Pool({ connectionString: databaseUrl, max: 1 });

export async function recordPostgresAdminDenial(
  input: AdminDenialInput,
  databaseUrl: string,
  poolFactory: DatabasePoolFactory = adminDenialPoolFactory,
): Promise<void> {
  const pool = poolFactory(databaseUrl);
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("set local role ritual_staff");
    await client.query("select set_config('ritual.staff_id',$1,true)", [
      input.actorStaffId,
    ]);
    await client.query(
      "select ritual_private.record_admin_denial($1,$2,$3,$4)",
      [
        input.actorStaffId,
        `denied:${input.method.toLowerCase()}:${input.permission}`,
        "Missing required permission.",
        input.requestId,
      ],
    );
    await client.query("commit");
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

const defaultDenialAuditor: AdminDenialAuditor = async (input, environment) => {
  if (environment.STAFF_DATABASE_URL === undefined)
    throw new Error("staff_database_binding_missing");
  await recordPostgresAdminDenial(input, environment.STAFF_DATABASE_URL);
};

function requireAuditedAdminPermission(
  permission: string,
  auditor: AdminDenialAuditor = defaultDenialAuditor,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const principal = context.get("authPrincipal");
    if (principal?.permissions.includes(permission)) return next();
    const staff = context.get("staffPrincipal");
    if (staff === undefined)
      return errorResponse(
        context,
        403,
        "forbidden",
        "An active staff principal is required.",
      );
    try {
      await auditor(
        {
          actorStaffId: staff.id,
          permission,
          method: context.req.method,
          requestId: requestIdFrom(context),
        },
        context.env,
      );
    } catch {
      return errorResponse(
        context,
        503,
        "service_unavailable",
        "The privileged denial audit is unavailable.",
        { retryable: true },
      );
    }
    return errorResponse(
      context,
      403,
      "forbidden",
      "The authenticated principal does not have permission for this operation.",
    );
  };
}

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
    authorizeStaff(dependencies.resolveStaff),
    requireAuditedAdminPermission(
      permission,
      dependencies.auditDeniedAdminAttempt ?? defaultDenialAuditor,
    ),
    staffRateLimit(rate),
  ].map((middleware) => async (context, next) => {
    if (context.req.method !== method.toUpperCase()) return next();
    return middleware(context, next);
  });
}

export function adminIdentitySecurity(
  dependencies: AdminRouteDependencies,
): MiddlewareHandler<AppEnvironment>[] {
  return [
    requireAdminHost,
    preAuthRateLimit("RL_ADMIN_READ"),
    requestMediaBoundary,
    adminBodyLimit,
    cloudflareAccessJwk(dependencies.accessKeys),
    auth0Jwk(dependencies.auth0Keys),
    authorizeStaff(dependencies.resolveStaff),
    staffRateLimit("RL_ADMIN_READ"),
  ];
}
