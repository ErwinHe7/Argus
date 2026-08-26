import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { requireRequestBody } from "../../middleware/security-headers.ts";
import { ContentCursorStaleError } from "../editorial/repository.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import {
  type ContentRouteDependencies,
  registerMemberReadSecurity,
  resolveMemberAccess,
} from "../editorial/route-support.ts";
import {
  assetCodexDetailSchema,
  assetComparisonSchema,
  assetMetricSchema,
  assetSummarySchema,
  evidenceDetailSchema,
} from "../editorial/schemas.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import {
  assetCompareBodySchema,
  assetMetricsQuerySchema,
  assetPageQuerySchema,
  assetParamsSchema,
} from "./schemas.ts";

const errors = {
  401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
  403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
  404: { description: "Published asset not found.", content: { "application/json": { schema: errorResponseSchema } } },
  413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
  415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid bounded input.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Content storage unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const listRoute = createRoute({ method: "get", path: "/v1/assets", operationId: "listAssets", tags: ["Assets"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: assetPageQuerySchema }, responses: { 200: { description: "Published Asset Codex summaries.", content: { "application/json": { schema: collectionResponse(assetSummarySchema).openapi("AssetCollectionResponse") } } }, ...errors } });
const detailRoute = createRoute({ method: "get", path: "/v1/assets/{asset_id}", operationId: "getAsset", tags: ["Assets"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: assetParamsSchema }, responses: { 200: { description: "Published Asset Codex detail.", content: { "application/json": { schema: objectResponse(assetCodexDetailSchema).openapi("AssetDetailResponse") } } }, ...errors } });
const evidenceRoute = createRoute({ method: "get", path: "/v1/assets/{asset_id}/evidence", operationId: "getAssetEvidence", tags: ["Assets"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: assetParamsSchema }, responses: { 200: { description: "Published detailed claims and allowlisted sources.", content: { "application/json": { schema: objectResponse(evidenceDetailSchema.array()).openapi("AssetEvidenceResponse") } } }, ...errors } });
const metricsRoute = createRoute({ method: "get", path: "/v1/assets/{asset_id}/metrics", operationId: "getAssetMetrics", tags: ["Assets"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: assetParamsSchema, query: assetMetricsQuerySchema }, responses: { 200: { description: "At most 90 deterministic snapshots.", content: { "application/json": { schema: objectResponse(assetMetricSchema.array()).openapi("AssetMetricsResponse") } } }, ...errors } });
const compareRoute = createRoute({ method: "post", path: "/v1/assets/compare", operationId: "compareAssets", tags: ["Assets"], security: [{ Auth0OAuth: ["read:self"] }], request: { body: { required: true, content: { "application/json": { schema: assetCompareBodySchema } } } }, responses: { 200: { description: "Normalized comparison of two to five assets.", content: { "application/json": { schema: objectResponse(assetComparisonSchema).openapi("AssetComparisonResponse") } } }, ...errors } });

export function registerAssetRoutes(app: OpenAPIHono<AppEnvironment>, dependencies: ContentRouteDependencies = {}): void {
  registerMemberReadSecurity(app, listRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(listRoute, async (context) => {
    const query = context.req.valid("query");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (secret === undefined) return unavailable(context);
    try {
      const page = await resolveSignedPage({
        ...(query.cursor === undefined ? {} : { cursor: query.cursor }), secret,
        scope: `assets:${query.asset_type ?? "all"}:${query.symbol_prefix?.toUpperCase() ?? "all"}`,
        load: (after) => access.repository.listAssets(access.member, {
          limit: query.limit,
          ...(after === undefined ? {} : { after }),
          ...(query.asset_type === undefined ? {} : { assetType: query.asset_type }),
          ...(query.symbol_prefix === undefined ? {} : { symbolPrefix: query.symbol_prefix }),
        }),
      });
      return collection(context, page.items, page.nextCursor);
    } catch (error) { return pageError(context, error); }
  });

  // Static `/compare` must be registered before the UUID detail route so its
  // validator and RL-SEARCH chain cannot be shadowed by `{asset_id}`.
  registerMemberReadSecurity(app, compareRoute.getRoutingPath(), "RL_SEARCH", dependencies);
  app.use(compareRoute.getRoutingPath(), requireRequestBody);
  app.openapi(compareRoute, async (context) => {
    const body = context.req.valid("json");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    try {
      const result = await access.repository.compareAssets(access.member, body.asset_ids);
      if (result === null) return notFound(context);
      return context.json({ data: result, meta: { request_id: requestIdFrom(context) } }, 200);
    } catch { return unavailable(context); }
  });

  registerMemberReadSecurity(app, detailRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(detailRoute, async (context) => objectLookup(context, dependencies, (access) => access.repository.getAsset(access.member, context.req.valid("param").asset_id)));
  registerMemberReadSecurity(app, evidenceRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(evidenceRoute, async (context) => objectLookup(context, dependencies, (access) => access.repository.getAssetEvidence(access.member, context.req.valid("param").asset_id)));
  registerMemberReadSecurity(app, metricsRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(metricsRoute, async (context) => {
    const params = context.req.valid("param");
    const query = context.req.valid("query");
    return objectLookup(context, dependencies, (access) => access.repository.getAssetMetrics(access.member, params.asset_id, query.as_of));
  });
}

async function objectLookup<T>(context: Context<AppEnvironment>, dependencies: ContentRouteDependencies, load: (access: Exclude<Awaited<ReturnType<typeof resolveMemberAccess>>, Response>) => Promise<T | null>): Promise<never> {
  const access = await resolveMemberAccess(context, dependencies);
  if (access instanceof Response) return access as never;
  try {
    const value = await load(access);
    if (value === null) return notFound(context);
    return context.json({ data: value, meta: { request_id: requestIdFrom(context) } }, 200) as never;
  } catch { return unavailable(context); }
}

function collection<T>(context: Context<AppEnvironment>, data: T[], nextCursor: string | null): never {
  return context.json({ data, meta: { request_id: requestIdFrom(context), next_cursor: nextCursor, has_more: nextCursor !== null } }, 200) as never;
}
function pageError(context: Context<AppEnvironment>, error: unknown): never {
  if (error instanceof InvalidCursorError || error instanceof ContentCursorStaleError) return errorResponse(context, 422, "invalid_cursor", "The pagination cursor is invalid or stale.") as never;
  return unavailable(context);
}
function notFound(context: Context<AppEnvironment>): never { return errorResponse(context, 404, "not_found", "The requested resource was not found.") as never; }
function unavailable(context: Context<AppEnvironment>): never { return errorResponse(context, 503, "service_unavailable", "Asset research is temporarily unavailable.", { retryable: true }) as never; }
