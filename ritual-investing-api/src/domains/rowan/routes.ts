import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import { errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { rowanCounselSchema } from "../editorial/schemas.ts";
import {
  type ContentRouteDependencies,
  registerMemberReadSecurity,
  resolveMemberAccess,
} from "../editorial/route-support.ts";
import { rowanQuerySchema } from "./schemas.ts";
import { resolveReviewedCounsel } from "./service.ts";

const errors = {
  401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
  403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
  404: { description: "Reviewed Rowan counsel not found.", content: { "application/json": { schema: errorResponseSchema } } },
  413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
  415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid bounded input.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Content storage unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const rowanRoute = createRoute({
  method: "get",
  path: "/v1/rowan/counsel",
  operationId: "getRowanCounsel",
  tags: ["Rowan"],
  security: [{ Auth0OAuth: ["read:self"] }],
  request: { query: rowanQuerySchema },
  responses: {
    200: { description: "Reviewed deterministic counsel.", content: { "application/json": { schema: objectResponse(rowanCounselSchema).openapi("RowanCounselResponse") } } },
    ...errors,
  },
});

export function registerRowanRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: ContentRouteDependencies = {},
): void {
  registerMemberReadSecurity(app, rowanRoute.getRoutingPath(), "RL_SEARCH", dependencies);
  app.openapi(rowanRoute, async (context) => {
    const query = context.req.valid("query");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    try {
      const counsel = await resolveReviewedCounsel(access.repository, access.member, {
        surface: query.surface,
        contextCode: query.context_code,
        ...(query.resource_id === undefined ? {} : { resourceId: query.resource_id }),
      });
      if (counsel === null) return errorResponse(context, 404, "not_found", "The requested resource was not found.") as never;
      return context.json({ data: counsel, meta: { request_id: requestIdFrom(context) } }, 200);
    } catch {
      return errorResponse(context, 503, "service_unavailable", "Rowan counsel is temporarily unavailable.", { retryable: true }) as never;
    }
  });
}
