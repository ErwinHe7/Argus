import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { ContentCursorStaleError, type PageResult } from "../editorial/repository.ts";
import { type ContentRouteDependencies, registerMemberReadSecurity, resolveMemberAccess } from "../editorial/route-support.ts";
import {
  circleTemplateDetailSchema,
  circleTemplateSummarySchema,
  discoverItemSchema,
  grimoireDetailSchema,
  grimoireSummarySchema,
  seededCreatorSchema,
} from "../editorial/schemas.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import {
  catalogIdParamsSchema,
  creatorQuerySchema,
  discoverQuerySchema,
  grimoireQuerySchema,
  templateQuerySchema,
} from "./schemas.ts";

const errors = {
  401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
  403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
  404: { description: "Published item not found.", content: { "application/json": { schema: errorResponseSchema } } },
  413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
  415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid bounded input.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Content storage unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const discoverRoute = createRoute({ method: "get", path: "/v1/discover", operationId: "listDiscover", tags: ["Discover"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: discoverQuerySchema }, responses: { 200: { description: "Bounded published discovery sections.", content: { "application/json": { schema: collectionResponse(discoverItemSchema).openapi("DiscoverResponse") } } }, ...errors } });
const grimoiresRoute = createRoute({ method: "get", path: "/v1/grimoires", operationId: "listGrimoires", tags: ["Discover"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: grimoireQuerySchema }, responses: { 200: { description: "Published Grimoire summaries.", content: { "application/json": { schema: collectionResponse(grimoireSummarySchema).openapi("GrimoireCollectionResponse") } } }, ...errors } });
const grimoireRoute = createRoute({ method: "get", path: "/v1/grimoires/{id}", operationId: "getGrimoire", tags: ["Discover"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: catalogIdParamsSchema }, responses: { 200: { description: "Published Grimoire detail.", content: { "application/json": { schema: objectResponse(grimoireDetailSchema).openapi("GrimoireDetailResponse") } } }, ...errors } });
const creatorsRoute = createRoute({ method: "get", path: "/v1/community/creators", operationId: "listSeededCreators", tags: ["Discover"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: creatorQuerySchema }, responses: { 200: { description: "Fictional seeded creator summaries.", content: { "application/json": { schema: collectionResponse(seededCreatorSchema).openapi("CreatorCollectionResponse") } } }, ...errors } });
const templatesRoute = createRoute({ method: "get", path: "/v1/circle-templates", operationId: "listCircleTemplates", tags: ["Discover"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: templateQuerySchema }, responses: { 200: { description: "Published Circle-template summaries.", content: { "application/json": { schema: collectionResponse(circleTemplateSummarySchema).openapi("CircleTemplateCollectionResponse") } } }, ...errors } });
const templateRoute = createRoute({ method: "get", path: "/v1/circle-templates/{id}", operationId: "getCircleTemplate", tags: ["Discover"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: catalogIdParamsSchema }, responses: { 200: { description: "Published Circle-template detail.", content: { "application/json": { schema: objectResponse(circleTemplateDetailSchema).openapi("CircleTemplateDetailResponse") } } }, ...errors } });

export function registerDiscoverRoutes(app: OpenAPIHono<AppEnvironment>, dependencies: ContentRouteDependencies = {}): void {
  for (const route of [discoverRoute, grimoiresRoute, grimoireRoute, creatorsRoute, templatesRoute, templateRoute]) registerMemberReadSecurity(app, route.getRoutingPath(), "RL_MEMBER_READ", dependencies);

  app.openapi(discoverRoute, async (context) => {
    const query = context.req.valid("query");
    return paged(context, dependencies, `discover:${query.section ?? "all"}`, query.cursor, (access, after) => {
    return access.repository.listMemberDiscover(access.member, { limit: query.limit, ...(after === undefined ? {} : { after }), ...(query.section === undefined ? {} : { section: query.section }) });
    });
  });
  app.openapi(grimoiresRoute, async (context) => {
    const query = context.req.valid("query");
    return paged(context, dependencies, `grimoires:${query.theme ?? "all"}`, query.cursor, (access, after) => {
    return access.repository.listGrimoires(access.member, { limit: query.limit, ...(after === undefined ? {} : { after }), ...(query.theme === undefined ? {} : { theme: query.theme }) });
    });
  });
  app.openapi(creatorsRoute, async (context) => {
    const query = context.req.valid("query");
    return paged(context, dependencies, "creators", query.cursor, (access, after) => {
    return access.repository.listCreators(access.member, { limit: query.limit, ...(after === undefined ? {} : { after }) });
    });
  });
  app.openapi(templatesRoute, async (context) => {
    const query = context.req.valid("query");
    return paged(context, dependencies, `circle-templates:${query.theme ?? "all"}:${query.creator ?? "all"}`, query.cursor, (access, after) => {
    return access.repository.listCircleTemplates(access.member, { limit: query.limit, ...(after === undefined ? {} : { after }), ...(query.theme === undefined ? {} : { theme: query.theme }), ...(query.creator === undefined ? {} : { creator: query.creator }) });
    });
  });
  app.openapi(grimoireRoute, async (context) => lookup(context, dependencies, (access) => access.repository.getGrimoire(access.member, context.req.valid("param").id)));
  app.openapi(templateRoute, async (context) => lookup(context, dependencies, (access) => access.repository.getCircleTemplate(access.member, context.req.valid("param").id)));
}

type Access = Exclude<Awaited<ReturnType<typeof resolveMemberAccess>>, Response>;

async function paged<T>(context: Context<AppEnvironment>, dependencies: ContentRouteDependencies, scope: string, cursor: string | undefined, load: (access: Access, after: string | undefined) => Promise<PageResult<T>>): Promise<never> {
  const access = await resolveMemberAccess(context, dependencies);
  if (access instanceof Response) return access as never;
  const secret = context.env.CURSOR_SIGNING_KEY;
  if (secret === undefined) return unavailable(context);
  try {
    const page = await resolveSignedPage({ ...(cursor === undefined ? {} : { cursor }), secret, scope, load: (after) => load(access, after) });
    return context.json({ data: page.items, meta: { request_id: requestIdFrom(context), next_cursor: page.nextCursor, has_more: page.nextCursor !== null } }, 200) as never;
  } catch (error) {
    if (error instanceof InvalidCursorError || error instanceof ContentCursorStaleError) return errorResponse(context, 422, "invalid_cursor", "The pagination cursor is invalid or stale.") as never;
    return unavailable(context);
  }
}

async function lookup<T>(context: Context<AppEnvironment>, dependencies: ContentRouteDependencies, load: (access: Access) => Promise<T | null>): Promise<never> {
  const access = await resolveMemberAccess(context, dependencies);
  if (access instanceof Response) return access as never;
  try {
    const value = await load(access);
    if (value === null) return errorResponse(context, 404, "not_found", "The requested resource was not found.") as never;
    return context.json({ data: value, meta: { request_id: requestIdFrom(context) } }, 200) as never;
  } catch { return unavailable(context); }
}

function unavailable(context: Context<AppEnvironment>): never { return errorResponse(context, 503, "service_unavailable", "Discovery content is temporarily unavailable.", { retryable: true }) as never; }
