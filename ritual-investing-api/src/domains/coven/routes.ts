import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { ContentCursorStaleError } from "../editorial/repository.ts";
import { type ContentRouteDependencies, registerMemberReadSecurity, resolveMemberAccess } from "../editorial/route-support.ts";
import { covenDetailSchema, covenSummarySchema, evidenceDetailSchema } from "../editorial/schemas.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import { covenPageQuerySchema, covenParamsSchema } from "./schemas.ts";

const errors = {
  401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
  403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
  404: { description: "Published Coven entry not found.", content: { "application/json": { schema: errorResponseSchema } } },
  413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
  415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid bounded input.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Content storage unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const listRoute = createRoute({ method: "get", path: "/v1/coven", operationId: "listCoven", tags: ["Founders Coven"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: covenPageQuerySchema }, responses: { 200: { description: "Currently verified published Coven entries.", content: { "application/json": { schema: collectionResponse(covenSummarySchema).openapi("CovenCollectionResponse") } } }, ...errors } });
const detailRoute = createRoute({ method: "get", path: "/v1/coven/{entry_id}", operationId: "getCovenEntry", tags: ["Founders Coven"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: covenParamsSchema }, responses: { 200: { description: "Published Coven entry and distinct qualifications.", content: { "application/json": { schema: objectResponse(covenDetailSchema).openapi("CovenDetailResponse") } } }, ...errors } });
const evidenceRoute = createRoute({ method: "get", path: "/v1/coven/{entry_id}/evidence", operationId: "getCovenEvidence", tags: ["Founders Coven"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: covenParamsSchema }, responses: { 200: { description: "Dated verification evidence without staff internals.", content: { "application/json": { schema: objectResponse(evidenceDetailSchema.array()).openapi("CovenEvidenceResponse") } } }, ...errors } });

export function registerCovenRoutes(app: OpenAPIHono<AppEnvironment>, dependencies: ContentRouteDependencies = {}): void {
  for (const route of [listRoute, detailRoute, evidenceRoute]) registerMemberReadSecurity(app, route.getRoutingPath(), "RL_MEMBER_READ", dependencies);

  app.openapi(listRoute, async (context) => {
    const query = context.req.valid("query");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (secret === undefined) return unavailable(context);
    try {
      const page = await resolveSignedPage({
        ...(query.cursor === undefined ? {} : { cursor: query.cursor }), secret,
        scope: `coven:${query.category ?? "all"}:${query.verified_as_of ?? "current"}`,
        load: (after) => access.repository.listMemberCoven(access.member, {
          limit: query.limit,
          ...(after === undefined ? {} : { after }),
          ...(query.category === undefined ? {} : { category: query.category }),
          ...(query.verified_as_of === undefined ? {} : { verifiedAsOf: query.verified_as_of }),
        }),
      });
      return context.json({ data: page.items, meta: { request_id: requestIdFrom(context), next_cursor: page.nextCursor, has_more: page.nextCursor !== null } }, 200) as never;
    } catch (error) {
      if (error instanceof InvalidCursorError || error instanceof ContentCursorStaleError) return errorResponse(context, 422, "invalid_cursor", "The pagination cursor is invalid or stale.") as never;
      return unavailable(context);
    }
  });

  app.openapi(detailRoute, async (context) => lookup(context, dependencies, (access) => access.repository.getMemberCoven(access.member, context.req.valid("param").entry_id)));
  app.openapi(evidenceRoute, async (context) => lookup(context, dependencies, (access) => access.repository.getMemberCovenEvidence(access.member, context.req.valid("param").entry_id)));
}

async function lookup<T>(context: Context<AppEnvironment>, dependencies: ContentRouteDependencies, load: (access: Exclude<Awaited<ReturnType<typeof resolveMemberAccess>>, Response>) => Promise<T | null>): Promise<never> {
  const access = await resolveMemberAccess(context, dependencies);
  if (access instanceof Response) return access as never;
  try {
    const value = await load(access);
    if (value === null) return errorResponse(context, 404, "not_found", "The requested resource was not found.") as never;
    return context.json({ data: value, meta: { request_id: requestIdFrom(context) } }, 200) as never;
  } catch { return unavailable(context); }
}

function unavailable(context: Context<AppEnvironment>): never { return errorResponse(context, 503, "service_unavailable", "Coven research is temporarily unavailable.", { retryable: true }) as never; }
