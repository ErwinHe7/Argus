import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { rejectRequestBody } from "../../middleware/security-headers.ts";
import { ContentCursorStaleError, ContentInvalidStateError, ContentVersionConflictError } from "../editorial/repository.ts";
import {
  type ContentRouteDependencies,
  registerMemberReadSecurity,
  registerMemberWriteSecurity,
  resolveMemberAccess,
} from "../editorial/route-support.ts";
import {
  dailyRitualDetailSchema,
  evidenceDetailSchema,
  ritualHistoryItemSchema,
} from "../editorial/schemas.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import {
  assignmentParamsSchema,
  assignmentVersionHeadersSchema,
  historyQuerySchema,
  ritualDailyQuerySchema,
} from "./schemas.ts";
import { validateHistoryRange, versionFromEtag } from "./service.ts";

const routeErrors = {
  401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
  403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
  404: { description: "Assignment not found.", content: { "application/json": { schema: errorResponseSchema } } },
  409: { description: "Version or state conflict.", content: { "application/json": { schema: errorResponseSchema } } },
  413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
  415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
  422: { description: "Invalid bounded input.", content: { "application/json": { schema: errorResponseSchema } } },
  429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
  503: { description: "Content storage unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
} as const;

const dailyRoute = createRoute({ method: "get", path: "/v1/rituals/daily", operationId: "getDailyRitual", tags: ["Rituals"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: ritualDailyQuerySchema }, responses: { 200: { description: "Frozen Daily Ritual assignment.", content: { "application/json": { schema: objectResponse(dailyRitualDetailSchema).openapi("DailyRitualResponse") } } }, ...routeErrors } });
const assignmentRoute = createRoute({ method: "get", path: "/v1/rituals/{assignment_id}", operationId: "getRitualAssignment", tags: ["Rituals"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: assignmentParamsSchema }, responses: { 200: { description: "Owned frozen assignment.", content: { "application/json": { schema: objectResponse(dailyRitualDetailSchema) } } }, ...routeErrors } });
const evidenceRoute = createRoute({ method: "get", path: "/v1/rituals/{assignment_id}/evidence", operationId: "getRitualEvidence", tags: ["Rituals"], security: [{ Auth0OAuth: ["read:self"] }], request: { params: assignmentParamsSchema }, responses: { 200: { description: "Evidence frozen to the owned assignment.", content: { "application/json": { schema: objectResponse(evidenceDetailSchema.array()).openapi("RitualEvidenceResponse") } } }, ...routeErrors } });
const revealRoute = createRoute({ method: "post", path: "/v1/rituals/{assignment_id}/reveal", operationId: "revealRitual", tags: ["Rituals"], security: [{ Auth0OAuth: ["write:self"] }], request: { params: assignmentParamsSchema, headers: assignmentVersionHeadersSchema }, responses: { 200: { description: "Idempotently revealed assignment.", content: { "application/json": { schema: objectResponse(dailyRitualDetailSchema) } } }, ...routeErrors } });
const completeRoute = createRoute({ method: "post", path: "/v1/rituals/{assignment_id}/complete", operationId: "completeRitual", tags: ["Rituals"], security: [{ Auth0OAuth: ["write:self"] }], request: { params: assignmentParamsSchema, headers: assignmentVersionHeadersSchema }, responses: { 200: { description: "Idempotently completed assignment.", content: { "application/json": { schema: objectResponse(dailyRitualDetailSchema) } } }, ...routeErrors } });
const historyRoute = createRoute({ method: "get", path: "/v1/rituals/history", operationId: "listRitualHistory", tags: ["Rituals"], security: [{ Auth0OAuth: ["read:self"] }], request: { query: historyQuerySchema }, responses: { 200: { description: "Bounded owned assignment history.", content: { "application/json": { schema: collectionResponse(ritualHistoryItemSchema).openapi("RitualHistoryResponse") } } }, ...routeErrors } });

export function registerRitualRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: ContentRouteDependencies = {},
): void {
  registerMemberReadSecurity(app, dailyRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(dailyRoute, async (context) => {
    const query = context.req.valid("query");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    try {
      const detail = await access.repository.getOrCreateDaily(access.member, { mode: query.mode, ...(query.date === undefined ? {} : { date: query.date }) });
      return detailResponse(context, detail);
    } catch {
      return unavailable(context);
    }
  });

  // Register static single-segment routes before the UUID route. Hono executes
  // matching middleware in registration order, so this also avoids duplicate
  // limiter/auth chains on `/daily` and `/history`.
  registerMemberReadSecurity(app, historyRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(historyRoute, async (context) => {
    const query = context.req.valid("query");
    if (!validateHistoryRange(query.from, query.to)) return errorResponse(context, 422, "validation_failed", "The history range must be ordered and no longer than 366 days.") as never;
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (secret === undefined) return unavailable(context);
    try {
      const page = await resolveSignedPage({
        ...(query.cursor === undefined ? {} : { cursor: query.cursor }), secret, scope: `ritual-history:${query.mode ?? "all"}:${query.from ?? "start"}:${query.to ?? "end"}`,
        load: (after) => access.repository.listHistory(access.member, {
          limit: query.limit,
          ...(after === undefined ? {} : { after }),
          ...(query.mode === undefined ? {} : { mode: query.mode }),
          ...(query.from === undefined ? {} : { from: query.from }),
          ...(query.to === undefined ? {} : { to: query.to }),
        }),
      });
      return context.json({ data: page.items.map(historyItem), meta: { request_id: requestIdFrom(context), next_cursor: page.nextCursor, has_more: page.nextCursor !== null } }, 200) as never;
    } catch (error) {
      if (error instanceof InvalidCursorError || error instanceof ContentCursorStaleError) return errorResponse(context, 422, "invalid_cursor", "The pagination cursor is invalid or stale.") as never;
      return unavailable(context);
    }
  });

  registerMemberReadSecurity(app, assignmentRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(assignmentRoute, async (context) => {
    const { assignment_id: id } = context.req.valid("param");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    try { return detailResponse(context, await access.repository.getAssignment(access.member, id)); } catch { return unavailable(context); }
  });

  registerMemberReadSecurity(app, evidenceRoute.getRoutingPath(), "RL_MEMBER_READ", dependencies);
  app.openapi(evidenceRoute, async (context) => {
    const { assignment_id: id } = context.req.valid("param");
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    try {
      const evidence = await access.repository.getAssignmentEvidence(access.member, id);
      if (evidence === null) return notFound(context);
      return context.json({ data: evidence, meta: { request_id: requestIdFrom(context) } }, 200);
    } catch { return unavailable(context); }
  });

  registerMemberWriteSecurity(app, revealRoute.getRoutingPath(), dependencies);
  app.use(revealRoute.getRoutingPath(), rejectRequestBody);
  app.openapi(revealRoute, async (context) => {
      const { assignment_id: id } = context.req.valid("param");
      const version = versionFromEtag(context.req.valid("header")["if-match"]);
      const access = await resolveMemberAccess(context, dependencies);
      if (access instanceof Response) return access as never;
      try {
        return detailResponse(context, await access.repository.transitionAssignment(access.member, id, "reveal", version));
      } catch (error) {
        if (error instanceof ContentVersionConflictError) return errorResponse(context, 409, "version_conflict", "The resource version is stale.") as never;
        if (error instanceof ContentInvalidStateError) return errorResponse(context, 409, "invalid_state_transition", "The ritual state transition is not allowed.") as never;
        return unavailable(context);
      }
  });
  registerMemberWriteSecurity(app, completeRoute.getRoutingPath(), dependencies);
  app.use(completeRoute.getRoutingPath(), rejectRequestBody);
  app.openapi(completeRoute, async (context) => {
    const { assignment_id: id } = context.req.valid("param");
    const version = versionFromEtag(context.req.valid("header")["if-match"]);
    const access = await resolveMemberAccess(context, dependencies);
    if (access instanceof Response) return access as never;
    try {
      return detailResponse(context, await access.repository.transitionAssignment(access.member, id, "complete", version));
    } catch (error) {
      if (error instanceof ContentVersionConflictError) return errorResponse(context, 409, "version_conflict", "The resource version is stale.") as never;
      if (error instanceof ContentInvalidStateError) return errorResponse(context, 409, "invalid_state_transition", "The ritual state transition is not allowed.") as never;
      return unavailable(context);
    }
  });
}

function detailResponse(context: Context<AppEnvironment>, detail: typeof dailyRitualDetailSchema._output | null): never {
  if (detail === null) return notFound(context);
  context.header("etag", `"v${detail.version}"`);
  return context.json({ data: detail, meta: { request_id: requestIdFrom(context) } }, 200) as never;
}

function historyItem(detail: typeof dailyRitualDetailSchema._output) {
  return { assignment_id: detail.assignment_id, date: detail.date, mode: detail.mode, title: detail.title, state: detail.state, demo: detail.demo };
}

function notFound(context: Context<AppEnvironment>): never {
  return errorResponse(context, 404, "not_found", "The requested resource was not found.") as never;
}

function unavailable(context: Context<AppEnvironment>): never {
  return errorResponse(context, 503, "service_unavailable", "Ritual content is temporarily unavailable.", { retryable: true }) as never;
}
