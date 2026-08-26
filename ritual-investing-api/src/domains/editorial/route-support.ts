import type { Context } from "hono";
import type { OpenAPIHono } from "@hono/zod-openapi";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

import type { AppEnvironment } from "../../app.ts";
import { resolveAccountContext } from "../../db/client.ts";
import { auth0Jwk } from "../../middleware/auth0-jwk.ts";
import { requireMemberClient } from "../../middleware/member-client.ts";
import type { AccountResolver } from "../../middleware/account-tenant.ts";
import { requirePermission } from "../../middleware/permissions.ts";
import {
  preAuthRateLimit,
  subjectRateLimit,
  type RateLimitClass,
} from "../../middleware/rate-limit.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  consumerBodyLimit,
  requestMediaBoundary,
} from "../../middleware/security-headers.ts";
import { createPostgresMemberContentRepository, createPostgresPublicContentRepository } from "./postgres-repository.ts";
import type {
  MemberContentRepository,
  MemberRequestContext,
  PublicContentRepository,
} from "./repository.ts";

export interface ProjectionCache {
  match(request: Request): Promise<Response | undefined>;
  put(request: Request, response: Response): Promise<void>;
}

export type ContentRouteDependencies = {
  auth0Keys?: readonly HonoJsonWebKey[];
  accountResolver?: AccountResolver;
  contentRepository?: MemberContentRepository;
  publicContentRepository?: PublicContentRepository;
  projectionCache?: ProjectionCache;
  now?: () => Date;
};

const defaultAccountResolver: AccountResolver = async (subject, environment) => {
  if (environment.IDENTITY_DATABASE_URL === undefined) {
    throw new Error("identity_database_binding_missing");
  }
  return resolveAccountContext(environment.IDENTITY_DATABASE_URL, subject);
};

export function registerMemberReadSecurity(
  app: OpenAPIHono<AppEnvironment>,
  path: string,
  rateClass: Extract<RateLimitClass, "RL_MEMBER_READ" | "RL_SEARCH">,
  dependencies: ContentRouteDependencies,
): void {
  app.use(path, preAuthRateLimit(rateClass));
  app.use(path, auth0Jwk(dependencies.auth0Keys));
  app.use(path, requireMemberClient);
  app.use(path, requirePermission("read:self"));
  app.use(path, subjectRateLimit(rateClass));
  app.use(path, requestMediaBoundary);
  app.use(path, consumerBodyLimit);
}

export function registerMemberWriteSecurity(
  app: OpenAPIHono<AppEnvironment>,
  path: string,
  dependencies: ContentRouteDependencies,
): void {
  app.use(path, preAuthRateLimit("RL_MEMBER_WRITE"));
  app.use(path, auth0Jwk(dependencies.auth0Keys));
  app.use(path, requireMemberClient);
  app.use(path, requirePermission("write:self"));
  app.use(path, subjectRateLimit("RL_MEMBER_WRITE"));
  app.use(path, requestMediaBoundary);
  app.use(path, consumerBodyLimit);
}

export async function resolveMemberAccess(
  context: Context<AppEnvironment>,
  dependencies: ContentRouteDependencies,
): Promise<{ member: MemberRequestContext; repository: MemberContentRepository } | Response> {
  const principal = context.get("authPrincipal");
  if (principal === undefined) {
    return errorResponse(context, 401, "unauthorized", "A valid API access token is required.");
  }
  try {
    const resolved = await (dependencies.accountResolver ?? defaultAccountResolver)(
      principal.subject,
      context.env,
    );
    if (resolved === null) {
      return errorResponse(context, 403, "account_inactive", "The account is not active.");
    }
    const repository = dependencies.contentRepository
      ?? (context.env.RUNTIME_DATABASE_URL === undefined
        ? undefined
        : createPostgresMemberContentRepository(context.env.RUNTIME_DATABASE_URL));
    if (repository === undefined) {
      return errorResponse(context, 503, "service_unavailable", "Content storage is unavailable.", { retryable: true });
    }
    return {
      member: { ...resolved, subject: principal.subject },
      repository,
    };
  } catch {
    return errorResponse(context, 503, "service_unavailable", "Member access could not be resolved.", { retryable: true });
  }
}

export function resolvePublicRepository(
  context: Context<AppEnvironment>,
  dependencies: ContentRouteDependencies,
): PublicContentRepository | Response {
  const repository = dependencies.publicContentRepository
    ?? (context.env.PUBLIC_DATABASE_URL === undefined
      ? undefined
      : createPostgresPublicContentRepository(context.env.PUBLIC_DATABASE_URL));
  return repository ?? errorResponse(
    context,
    503,
    "service_unavailable",
    "Published content is unavailable.",
    { retryable: true },
  );
}

function defaultProjectionCache(): ProjectionCache | undefined {
  const cacheStorage = (globalThis as typeof globalThis & { caches?: CacheStorage & { default?: Cache } }).caches;
  const cache = cacheStorage?.default;
  if (cache === undefined) return undefined;
  return {
    async match(request) {
      return (await cache.match(request)) ?? undefined;
    },
    async put(request, response) {
      await cache.put(request, response);
    },
  };
}

function normalizedCacheRequest(context: Context<AppEnvironment>, revisionId: string): Request {
  const incoming = new URL(context.req.url);
  const normalized = new URL(incoming.pathname, context.env.API_ORIGIN);
  [...incoming.searchParams.entries()]
    .sort(([leftKey, leftValue], [rightKey, rightValue]) =>
      leftKey.localeCompare(rightKey) || leftValue.localeCompare(rightValue))
    .forEach(([key, value]) => normalized.searchParams.append(key, value));
  normalized.searchParams.set("_published_revision", revisionId);
  return new Request(normalized.toString(), { method: "GET" });
}

export type PublicProjectionPayload<T> = {
  data: T;
  nextCursor?: string | null;
};

export async function publicProjectionResponse<T>(
  context: Context<AppEnvironment>,
  dependencies: ContentRouteDependencies,
  revisionId: string,
  load: () => Promise<PublicProjectionPayload<T>>,
): Promise<Response> {
  const etag = `"pub-${revisionId}"`;
  context.header("etag", etag);
  context.header("cache-control", "public, max-age=60, stale-while-revalidate=300");
  context.header("vary", "origin");
  if (context.req.header("if-none-match") === etag) {
    return context.body(null, 304);
  }

  const cache = dependencies.projectionCache ?? defaultProjectionCache();
  const cacheRequest = normalizedCacheRequest(context, revisionId);
  if (cache !== undefined) {
    const cached = await cache.match(cacheRequest).catch(() => undefined);
    if (cached !== undefined) {
      try {
        const cachedBody = await cached.json() as PublicProjectionPayload<T>;
        return projectionJson(context, cachedBody);
      } catch {
        // A corrupt or unavailable shared cache must never hide a fresh safe projection.
      }
    }
    const value = await load();
    await cache.put(
      cacheRequest,
      new Response(JSON.stringify(value), {
        headers: { "content-type": "application/json", "cache-control": "public, max-age=60" },
      }),
    ).catch(() => undefined);
    return projectionJson(context, value);
  }
  return projectionJson(context, await load());
}

function projectionJson<T>(context: Context<AppEnvironment>, payload: PublicProjectionPayload<T>): Response {
  return context.json({
    data: payload.data,
    meta: {
      request_id: requestIdFrom(context),
      ...(payload.nextCursor === undefined ? {} : {
        next_cursor: payload.nextCursor,
        has_more: payload.nextCursor !== null,
      }),
    },
  }, 200);
}
