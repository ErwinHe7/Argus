import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { errorResponse } from "./responses.ts";

export type RateLimitClass =
  | "RL_HEALTH"
  | "RL_PUBLIC"
  | "RL_SEARCH"
  | "RL_MEMBER_READ"
  | "RL_MEMBER_WRITE"
  | "RL_COMMAND"
  | "RL_SENSITIVE"
  | "RL_ADMIN_READ"
  | "RL_ADMIN_WRITE"
  | "RL_ADMIN_HIGH"
  | "RL_UPLOAD";

function normalizedRoute(pathname: string): string {
  return (
    pathname
      .replace(
        /[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi,
        ":id",
      )
      .replace(/\/{2,}/g, "/")
      .replace(/\/$/, "") || "/"
  );
}

function ipPrefix(
  context: Parameters<MiddlewareHandler<AppEnvironment>>[0],
): string {
  const address = context.req.header("cf-connecting-ip") ?? "unknown";
  if (/^\d{1,3}(?:\.\d{1,3}){3}$/.test(address)) {
    return `${address.split(".").slice(0, 3).join(".")}.0/24`;
  }
  if (address.includes(":")) {
    return `${address.split(":").slice(0, 4).join(":")}::/64`;
  }
  return "unknown";
}

async function pseudonymousKey(parts: readonly string[]): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(parts.join("\u001f")),
  );
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function enforce(
  context: Parameters<MiddlewareHandler<AppEnvironment>>[0],
  rateClass: RateLimitClass,
  keyParts: readonly string[],
): Promise<Response | undefined> {
  try {
    const binding = context.env[rateClass];
    const outcome = await binding.limit({
      key: await pseudonymousKey(keyParts),
    });
    if (!outcome.success) {
      context.header("retry-after", "60");
      return errorResponse(
        context,
        429,
        "rate_limited",
        "The request rate limit was exceeded.",
        { retryable: true, retryAfterSeconds: 60 },
      );
    }
  } catch {
    return errorResponse(
      context,
      503,
      "service_unavailable",
      "The request rate limit could not be checked.",
      { retryable: true },
    );
  }
}

export function preAuthRateLimit(
  rateClass: RateLimitClass,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const denial = await enforce(context, rateClass, [
      "ip",
      ipPrefix(context),
      normalizedRoute(new URL(context.req.url).pathname),
    ]);
    if (denial !== undefined) return denial;
    await next();
  };
}

export function subjectRateLimit(
  rateClass: RateLimitClass,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const principal = context.get("authPrincipal");
    if (principal === undefined) {
      return errorResponse(
        context,
        401,
        "unauthorized",
        "A valid API access token is required.",
      );
    }
    const denial = await enforce(context, rateClass, [
      "subject",
      principal.subject,
      normalizedRoute(new URL(context.req.url).pathname),
    ]);
    if (denial !== undefined) return denial;
    await next();
  };
}

export function tenantRateLimit(
  rateClass: RateLimitClass,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const account = context.get("accountTenant");
    if (account === undefined) {
      return errorResponse(
        context,
        401,
        "unauthorized",
        "An active member account is required.",
      );
    }
    const denial = await enforce(context, rateClass, [
      "tenant",
      account.tenantId,
      context.req.method,
      normalizedRoute(new URL(context.req.url).pathname),
    ]);
    if (denial !== undefined) return denial;
    await next();
  };
}

export function staffRateLimit(
  rateClass: RateLimitClass,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const staff = context.get("staffPrincipal");
    if (staff === undefined) {
      return errorResponse(
        context,
        403,
        "forbidden",
        "An active staff principal is required.",
      );
    }
    const denial = await enforce(context, rateClass, [
      "staff",
      staff.id,
      normalizedRoute(new URL(context.req.url).pathname),
    ]);
    if (denial !== undefined) return denial;
    await next();
  };
}
