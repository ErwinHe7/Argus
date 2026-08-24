import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, errorResponseSchema } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { ContentCursorStaleError } from "../editorial/repository.ts";
import { searchResultSchema } from "../editorial/schemas.ts";
import {
  type ContentRouteDependencies,
  registerMemberReadSecurity,
  resolveMemberAccess,
} from "../editorial/route-support.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import { searchQuerySchema } from "./schemas.ts";
import { parseSearchKinds } from "./service.ts";

const errors = {
  401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
  403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
  413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
  415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid bounded input.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Content storage unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const searchRoute = createRoute({
  method: "get",
  path: "/v1/search",
  operationId: "searchPublishedCatalog",
  tags: ["Search"],
  security: [{ Auth0OAuth: ["read:self"] }],
  request: { query: searchQuerySchema },
  responses: {
    200: { description: "Bounded mixed published search results.", content: { "application/json": { schema: collectionResponse(searchResultSchema).openapi("SearchResponse") } } },
    ...errors,
  },
});

export function registerSearchRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: ContentRouteDependencies = {},
): void {
  registerMemberReadSecurity(app, searchRoute.getRoutingPath(), "RL_SEARCH", dependencies);
  app.openapi(searchRoute, async (context) => {
    const query = context.req.valid("query");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (secret === undefined) return unavailable(context);
    const kinds = parseSearchKinds(query.kinds);
    try {
      const page = await resolveSignedPage({
        ...(query.cursor === undefined ? {} : { cursor: query.cursor }),
        secret,
        scope: `search:${kinds.join(",")}:${query.q.toLocaleLowerCase("en-US")}`,
        load: (after) => access.repository.search(access.member, {
          query: query.q,
          kinds,
          limit: query.limit,
          ...(after === undefined ? {} : { after }),
        }),
      });
      return context.json({ data: page.items, meta: { request_id: requestIdFrom(context), next_cursor: page.nextCursor, has_more: page.nextCursor !== null } }, 200) as never;
    } catch (error) {
      if (error instanceof InvalidCursorError || error instanceof ContentCursorStaleError) {
        return errorResponse(context, 422, "invalid_cursor", "The pagination cursor is invalid or stale.") as never;
      }
      return unavailable(context);
    }
  });
}

function unavailable(context: Context<AppEnvironment>): never {
  return errorResponse(context, 503, "service_unavailable", "Search is temporarily unavailable.", { retryable: true }) as never;
}
