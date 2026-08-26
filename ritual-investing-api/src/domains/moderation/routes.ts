import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";
import type { AppEnvironment } from "../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  etagSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../contracts/common.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../editorial/cursor.ts";
import { adminSecurity, type AdminRouteDependencies } from "../admin/access.ts";
import {
  createPostgresAdminModerationRepository,
  type AdminModerationRepository,
} from "./repository.ts";
import {
  createModerationCaseSchema,
  moderationCaseSchema,
  moderationQuerySchema,
  moderationReportSchema,
  patchModerationCaseSchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Dual authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Permission denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "Conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid input.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const reportParams = z.object({ report_id: z.string().uuid() }).strict();
const caseParams = z.object({ case_id: z.string().uuid() }).strict();
const reports = createRoute({
  method: "get",
  path: "/v1/admin/moderation/reports",
  operationId: "listAdminModerationReports",
  tags: ["Admin Moderation"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:moderation:read"] }],
  request: { query: moderationQuerySchema },
  responses: {
    200: {
      description: "Redacted reports without reporter identity or member data.",
      content: {
        "application/json": {
          schema: collectionResponse(moderationReportSchema),
        },
      },
    },
    ...errors,
  },
});
const createCase = createRoute({
  method: "post",
  path: "/v1/admin/moderation/reports/{report_id}/cases",
  operationId: "createAdminModerationCase",
  tags: ["Admin Moderation"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:moderation:write"] }],
  request: {
    params: reportParams,
    headers: z.object({ "idempotency-key": idempotencyKeySchema }),
    body: {
      required: true,
      content: { "application/json": { schema: createModerationCaseSchema } },
    },
  },
  responses: {
    201: {
      description: "Audited moderation case.",
      content: {
        "application/json": { schema: objectResponse(moderationCaseSchema) },
      },
    },
    ...errors,
  },
});
const detail = createRoute({
  method: "get",
  path: "/v1/admin/moderation/cases/{case_id}",
  operationId: "getAdminModerationCase",
  tags: ["Admin Moderation"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:moderation:read"] }],
  request: { params: caseParams },
  responses: {
    200: {
      description: "Redacted case and immutable decision history.",
      content: {
        "application/json": { schema: objectResponse(moderationCaseSchema) },
      },
    },
    ...errors,
  },
});
const patch = createRoute({
  method: "patch",
  path: "/v1/admin/moderation/cases/{case_id}",
  operationId: "patchAdminModerationCase",
  tags: ["Admin Moderation"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:moderation:write"] }],
  request: {
    params: caseParams,
    headers: z.object({ "if-match": etagSchema }),
    body: {
      required: true,
      content: { "application/json": { schema: patchModerationCaseSchema } },
    },
  },
  responses: {
    200: {
      description: "Conditionally updated audited case.",
      content: {
        "application/json": { schema: objectResponse(moderationCaseSchema) },
      },
    },
    ...errors,
  },
});
export type AdminModerationRouteDependencies = AdminRouteDependencies & {
  adminModerationRepository?: AdminModerationRepository;
};
export function registerAdminModerationRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: AdminModerationRouteDependencies = {},
) {
  for (const [route, method, permission, rate] of [
    [reports, "get", "admin:moderation:read", "RL_ADMIN_READ"],
    [createCase, "post", "admin:moderation:write", "RL_ADMIN_WRITE"],
    [detail, "get", "admin:moderation:read", "RL_ADMIN_READ"],
    [patch, "patch", "admin:moderation:write", "RL_ADMIN_WRITE"],
  ] as const)
    for (const middleware of adminSecurity(
      dependencies,
      method,
      permission,
      rate,
    ))
      app.use(route.getRoutingPath(), middleware);
  const repository = (context: any) =>
    dependencies.adminModerationRepository ??
    (context.env.STAFF_DATABASE_URL === undefined
      ? undefined
      : createPostgresAdminModerationRepository(
          context.env.STAFF_DATABASE_URL,
        ));
  const failure = (context: any, error: unknown) => {
    if (error instanceof InvalidCursorError)
      return context.json(
        {
          error: {
            code: "invalid_cursor",
            message: "The cursor is invalid.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: false,
          },
        },
        422,
      );
    const code =
      error instanceof Error
        ? error.message.match(
            /not_found|version_conflict|idempotency_conflict|invalid_transition/,
          )?.[0]
        : undefined;
    return context.json(
      {
        error: {
          code: code ?? "service_unavailable",
          message:
            code === "not_found"
              ? "The case was not found."
              : code === undefined
                ? "Moderation is unavailable."
                : "The case transition could not be applied.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: code === undefined,
        },
      },
      code === "not_found" ? 404 : code === undefined ? 503 : 409,
    );
  };
  app.openapi(reports, async (context) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (!staff || !repo || !secret)
      return failure(context, new Error("unavailable"));
    const query = context.req.valid("query");
    const scope = `admin-moderation:${query.status ?? "all"}:${query.target_kind ?? "all"}:${query.from ?? "start"}:${query.to ?? "end"}`;
    try {
      const after = await decodeCursor(secret, scope, query.cursor);
      const page = await repo.list({
        actorStaffId: staff.id,
        filters: query,
        limit: query.limit,
        ...(after === undefined ? {} : { after }),
      });
      const next =
        page.next === null
          ? null
          : await encodeCursor(secret, scope, page.next);
      return context.json(
        {
          data: page.items,
          meta: {
            request_id: requestIdFrom(context),
            next_cursor: next,
            has_more: next !== null,
          },
        },
        200,
      );
    } catch (error) {
      return failure(context, error);
    }
  });
  app.openapi(createCase, async (context) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (!staff || !repo) return failure(context, new Error("unavailable"));
    try {
      const value = await repo.createCase({
        actorStaffId: staff.id,
        reportId: context.req.valid("param").report_id,
        payload: context.req.valid("json"),
        requestId: requestIdFrom(context),
        idempotencyKey: context.req.valid("header")["idempotency-key"],
      });
      context.header("etag", value.etag);
      return context.json(
        { data: value, meta: { request_id: requestIdFrom(context) } },
        201,
      );
    } catch (error) {
      return failure(context, error);
    }
  });
  app.openapi(detail, async (context) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (!staff || !repo) return failure(context, new Error("unavailable"));
    try {
      const value = await repo.getCase({
        actorStaffId: staff.id,
        caseId: context.req.valid("param").case_id,
      });
      if (value === null) throw new Error("not_found");
      context.header("etag", value.etag);
      return context.json(
        { data: value, meta: { request_id: requestIdFrom(context) } },
        200,
      );
    } catch (error) {
      return failure(context, error);
    }
  });
  app.openapi(patch, async (context) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (!staff || !repo) return failure(context, new Error("unavailable"));
    try {
      const value = await repo.patchCase({
        actorStaffId: staff.id,
        caseId: context.req.valid("param").case_id,
        payload: context.req.valid("json"),
        expectedVersion: Number(
          context.req.valid("header")["if-match"].slice(2, -1),
        ),
        requestId: requestIdFrom(context),
      });
      context.header("etag", value.etag);
      return context.json(
        { data: value, meta: { request_id: requestIdFrom(context) } },
        200,
      );
    } catch (error) {
      return failure(context, error);
    }
  });
}
