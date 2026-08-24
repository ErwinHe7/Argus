import { Pool } from "@neondatabase/serverless";
import type { MiddlewareHandler } from "hono";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";
import { z } from "zod";

import type { AppEnvironment } from "../app.ts";
import { verifyManagedJwt } from "./managed-jwks.ts";
import { errorResponse } from "./responses.ts";

export type VerifiedAccessPrincipal = Readonly<{
  subject: string;
  identity: string;
  issuedAt: number;
}>;

export type StaffPrincipal = Readonly<{
  id: string;
  auth0Subject: string;
  accessIdentity: string;
  allowedClientId: string;
  displayLabel: string;
  revocationEpoch: number;
}>;

export type StaffResolverInput = {
  auth0Subject: string;
  accessIdentity: string;
  allowedClientId: string;
};

export type StaffResolver = (
  input: StaffResolverInput,
  environment: AppEnvironment["Bindings"],
) => Promise<StaffPrincipal | null>;

export type AccessVariables = {
  accessPrincipal: VerifiedAccessPrincipal;
  staffPrincipal: StaffPrincipal;
};

export const requireAdminHost: MiddlewareHandler<AppEnvironment> = async (context, next) => {
  if (new URL(context.req.url).hostname.toLowerCase() !== context.env.ADMIN_HOST.toLowerCase()) {
    return errorResponse(context, 404, "not_found", "The requested resource was not found.");
  }
  await next();
};

export function cloudflareAccessJwk(
  keys?: readonly HonoJsonWebKey[],
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const assertion = context.req.header("cf-access-jwt-assertion");
    if (assertion === undefined || assertion.length === 0 || assertion.length > 16_384) {
      return errorResponse(context, 401, "unauthorized", "A Cloudflare Access assertion is required.");
    }

    const issuer = context.env.CF_ACCESS_ISSUER;
    const audience = context.env.CF_ACCESS_AUDIENCE;

    try {
      const payload = await verifyManagedJwt({
        token: assertion,
        issuer,
        audience,
        jwksUrl: context.env.CF_ACCESS_JWKS_URL,
        ...(keys === undefined ? {} : { keys }),
      });
      const exactAudience = z.union([
        z.literal(audience),
        z.tuple([z.literal(audience)]),
      ]);
      const parsed = z
        .object({
          iss: z.literal(issuer),
          aud: exactAudience,
          sub: z.string().min(1).max(255),
          email: z.string().email().max(320),
          iat: z.number().int().nonnegative(),
          exp: z.number().int().positive(),
        })
        .passthrough()
        .safeParse(payload);
      if (
        !parsed.success ||
        parsed.data.iat > Math.floor(Date.now() / 1_000) + 60
      )
        throw new Error("invalid_claims");
      context.set(
        "accessPrincipal",
        Object.freeze({
          subject: parsed.data.sub,
          identity: parsed.data.email.trim().toLowerCase(),
          issuedAt: parsed.data.iat,
        }),
      );
    } catch {
      return errorResponse(context, 401, "unauthorized", "A valid Cloudflare Access assertion is required.");
    }

    await next();
  };
}

const defaultStaffResolver: StaffResolver = async (input, environment) => {
  if (environment.STAFF_DATABASE_URL === undefined) {
    throw new Error("staff_database_binding_missing");
  }
  const pool = new Pool({ connectionString: environment.STAFF_DATABASE_URL, max: 1 });
  let client;
  try {
    client = await pool.connect();
    await client.query("begin");
    await client.query("set local role ritual_staff_resolver");
    const result = await client.query<{
      id: string;
      auth0_subject: string;
      access_identity: string;
      allowed_client_id: string;
      display_label: string;
      revocation_epoch: number;
    }>(
      "select * from ritual_private.resolve_staff_principal($1, $2, $3)",
      [input.auth0Subject, input.accessIdentity, input.allowedClientId],
    );
    await client.query("commit");
    const row = result.rows[0];
    if (result.rows.length !== 1 || row === undefined) return null;
    return Object.freeze({
      id: row.id,
      auth0Subject: row.auth0_subject,
      accessIdentity: row.access_identity,
      allowedClientId: row.allowed_client_id,
      displayLabel: row.display_label,
      revocationEpoch: Number(row.revocation_epoch),
    });
  } catch (error) {
    await client?.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client?.release();
    await pool.end();
  }
};

function adminClientAllowlist(value: string): ReadonlySet<string> {
  return new Set(value.split(",").map((entry) => entry.trim()).filter(Boolean));
}

export function authorizeStaff(
  resolver: StaffResolver = defaultStaffResolver,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const auth0 = context.get("authPrincipal");
    const access = context.get("accessPrincipal");
    const authorizedParty = auth0?.authorizedParty;
    if (
      auth0 === undefined
      || access === undefined
      || authorizedParty === undefined
      || !adminClientAllowlist(context.env.AUTH0_ADMIN_CLIENT_IDS).has(authorizedParty)
    ) {
      return errorResponse(context, 403, "forbidden", "An authorized staff principal is required.");
    }

    try {
      const staff = await resolver({
        auth0Subject: auth0.subject,
        accessIdentity: access.identity,
        allowedClientId: authorizedParty,
      }, context.env);
      if (staff === null || auth0.issuedAt < staff.revocationEpoch) {
        return errorResponse(context, 403, "forbidden", "An active staff principal is required.");
      }
      context.set("staffPrincipal", staff);
      await next();
    } catch {
      return errorResponse(
        context,
        503,
        "service_unavailable",
        "Staff identity resolution is temporarily unavailable.",
        { retryable: true },
      );
    }
  };
}
