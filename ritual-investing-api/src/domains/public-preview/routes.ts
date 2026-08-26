import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { preAuthRateLimit } from "../../middleware/rate-limit.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { ContentCursorStaleError } from "../editorial/repository.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import { serializePublicCoven, serializePublicDaily, serializePublicDiscover } from "../editorial/service.ts";
import {
  type ContentRouteDependencies,
  publicProjectionResponse,
  resolvePublicRepository,
} from "../editorial/route-support.ts";
import {
  dailyRitualPreviewSchema,
  publicDiscoverItemSchema,
  publicCovenTeaserSchema,
} from "../editorial/schemas.ts";
import {
  publicCovenQuerySchema,
  publicCovenSlugSchema,
  publicDailyQuerySchema,
  publicPageQuerySchema,
} from "./schemas.ts";
import { loadPublicDaily } from "./service.ts";
import type { PageResult } from "../editorial/repository.ts";

const errors = {
  404: { description: "Published item not found.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid public query.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Published content unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const dailyRoute = createRoute({
  method: "get", path: "/v1/public/rituals/daily", operationId: "getPublicDailyRitual", tags: ["Public Preview"], security: [],
  request: { query: publicDailyQuerySchema },
  responses: { 200: { description: "Allowlisted published Daily Ritual preview.", content: { "application/json": { schema: objectResponse(dailyRitualPreviewSchema).openapi("PublicDailyRitualResponse") } } }, 304: { description: "Published revision unchanged." }, ...errors },
});
const discoverRoute = createRoute({
  method: "get", path: "/v1/public/discover", operationId: "listPublicDiscover", tags: ["Public Preview"], security: [],
  request: { query: publicPageQuerySchema },
  responses: { 200: { description: "Allowlisted published discovery teasers.", content: { "application/json": { schema: collectionResponse(publicDiscoverItemSchema).openapi("PublicDiscoverResponse") } } }, 304: { description: "Published revision unchanged." }, ...errors },
});
const covenRoute = createRoute({
  method: "get", path: "/v1/public/coven", operationId: "listPublicCoven", tags: ["Public Preview"], security: [],
  request: { query: publicCovenQuerySchema },
  responses: { 200: { description: "Allowlisted published Coven teasers.", content: { "application/json": { schema: collectionResponse(publicCovenTeaserSchema).openapi("PublicCovenResponse") } } }, 304: { description: "Published revision unchanged." }, ...errors },
});
const covenDetailRoute = createRoute({
  method: "get", path: "/v1/public/coven/{slug}", operationId: "getPublicCoven", tags: ["Public Preview"], security: [],
  request: { params: publicCovenSlugSchema },
  responses: { 200: { description: "Allowlisted published Coven teaser detail.", content: { "application/json": { schema: objectResponse(publicCovenTeaserSchema).openapi("PublicCovenDetailResponse") } } }, 304: { description: "Published revision unchanged." }, ...errors },
});

function utcDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function daysBetween(left: string, right: string): number {
  return Math.floor((Date.parse(`${right}T00:00:00Z`) - Date.parse(`${left}T00:00:00Z`)) / 86_400_000);
}

export function registerPublicPreviewRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: ContentRouteDependencies = {},
): void {
  for (const path of [dailyRoute, discoverRoute, covenRoute, covenDetailRoute].map((route) => route.getRoutingPath())) {
    app.use(path, preAuthRateLimit("RL_PUBLIC"));
  }

  app.openapi(dailyRoute, async (context) => {
    const query = context.req.valid("query");
    const today = utcDate((dependencies.now ?? (() => new Date()))());
    const date = query.date ?? today;
    const age = daysBetween(date, today);
    if (age < 0 || age > 7) {
      return errorResponse(context, 422, "validation_failed", "Public ritual dates are limited to today and the prior seven days.");
    }
    const repository = resolvePublicRepository(context, dependencies);
    if (repository instanceof Response) return repository;
    try {
      const result = await loadPublicDaily(repository, date, query.mode);
      if (result === null) {
        return errorResponse(context, 503, "content_unavailable", "The Daily Ritual is not currently available.", { retryable: true, retryAfterSeconds: 300 });
      }
      return await publicProjectionResponse(context, dependencies, result.revisionId, async () => {
        const value = await result.load();
        if (value === null) throw new ContentCursorStaleError();
        return { data: serializePublicDaily(value) };
      });
    } catch {
      return errorResponse(context, 503, "service_unavailable", "Published content is temporarily unavailable.", { retryable: true });
    }
  });

  app.openapi(discoverRoute, async (context) => {
    const query = context.req.valid("query");
    const repository = resolvePublicRepository(context, dependencies);
    if (repository instanceof Response) return repository;
    try {
      const revisionId = await repository.resolveDiscoverRevision();
      return await servePublicPage(context, dependencies, "public-discover", revisionId, query.cursor, async (after) => {
        const page = await repository.listDiscover({ limit: query.limit, ...(after === undefined ? {} : { after }) }, revisionId);
        return { ...page, items: page.items.map(serializePublicDiscover) };
      });
    } catch { return errorResponse(context, 503, "service_unavailable", "Published content is temporarily unavailable.", { retryable: true }); }
  });

  app.openapi(covenRoute, async (context) => {
    const query = context.req.valid("query");
    const repository = resolvePublicRepository(context, dependencies);
    if (repository instanceof Response) return repository;
    try {
      const revisionId = await repository.resolveCovenRevision();
      if (revisionId === null) return await publicProjectionResponse(context, dependencies, "empty", async () => ({ data: [], nextCursor: null }));
      return await servePublicPage(context, dependencies, `public-coven:${query.category ?? "all"}`, revisionId, query.cursor, async (after) => {
        const page = await repository.listCoven({ limit: query.limit, ...(after === undefined ? {} : { after }), ...(query.category === undefined ? {} : { category: query.category }) }, revisionId);
        return { ...page, items: page.items.map(serializePublicCoven) };
      });
    } catch { return errorResponse(context, 503, "service_unavailable", "Published content is temporarily unavailable.", { retryable: true }); }
  });

  app.openapi(covenDetailRoute, async (context) => {
    const { slug } = context.req.valid("param");
    const repository = resolvePublicRepository(context, dependencies);
    if (repository instanceof Response) return repository;
    try {
      const revisionId = await repository.resolveCovenRevision(slug);
      if (revisionId === null) return errorResponse(context, 404, "not_found", "The requested resource was not found.");
      return await publicProjectionResponse(context, dependencies, revisionId, async () => {
        const value = await repository.getCoven(slug, revisionId);
        if (value === null) throw new ContentCursorStaleError();
        return { data: serializePublicCoven(value) };
      });
    } catch {
      return errorResponse(context, 503, "service_unavailable", "Published content is temporarily unavailable.", { retryable: true });
    }
  });
}

async function servePublicPage<T>(
  context: Context<AppEnvironment>,
  dependencies: ContentRouteDependencies,
  scope: string,
  revisionId: string,
  cursor: string | undefined,
  repositoryCall: (after: string | undefined) => Promise<PageResult<T>>,
): Promise<Response> {
  const secret = context.env.CURSOR_SIGNING_KEY;
  if (secret === undefined) return errorResponse(context, 503, "service_unavailable", "Cursor signing is unavailable.", { retryable: true });
  try {
    return await publicProjectionResponse(context, dependencies, revisionId, async () => {
      const result = await resolveSignedPage({
        load: repositoryCall,
        ...(cursor === undefined ? {} : { cursor }),
        secret,
        scope: `${scope}:revision:${revisionId}`,
      });
      return { data: result.items, nextCursor: result.nextCursor };
    });
  } catch (error) {
    if (error instanceof InvalidCursorError || error instanceof ContentCursorStaleError) return errorResponse(context, 422, "invalid_cursor", "The pagination cursor is invalid or stale.");
    return errorResponse(context, 503, "service_unavailable", "Published content is temporarily unavailable.", { retryable: true });
  }
}
