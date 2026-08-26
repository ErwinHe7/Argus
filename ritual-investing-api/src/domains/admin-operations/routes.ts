import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../contracts/common.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { adminSecurity, type AdminRouteDependencies } from "../admin/access.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../editorial/cursor.ts";
import {
  AdminOperationConflictError,
  createPostgresAdminOperationsRepository,
  type AdminOperationsRepository,
} from "./repository.ts";
import {
  adminJobSchema,
  adminPrivacySchema,
  adminRetrySchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Dual authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Staff permission denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "Not retryable or idempotency conflict.",
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
    description: "Operations unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const jobParams = z.object({ job_id: z.string().uuid() }).strict();
const privacyParams = z.object({ request_id: z.string().uuid() }).strict();
const retryHeaders = z.object({ "idempotency-key": idempotencyKeySchema });
const jobQuery = z
  .object({
    status: z.enum(["leased", "completed", "retry", "dead_letter"]).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();
const privacyQuery = z
  .object({
    status: z
      .enum([
        "requested",
        "verified",
        "queued",
        "processing",
        "completed",
        "failed",
        "cancelled",
      ])
      .optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();

const jobs = createRoute({
  method: "get",
  path: "/v1/admin/jobs",
  operationId: "listAdminJobs",
  tags: ["Admin Operations"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:operations:read"] }],
  request: { query: jobQuery },
  responses: {
    200: {
      description: "Bounded redacted job metadata.",
      content: {
        "application/json": { schema: collectionResponse(adminJobSchema) },
      },
    },
    ...errors,
  },
});
const job = createRoute({
  method: "get",
  path: "/v1/admin/jobs/{job_id}",
  operationId: "getAdminJob",
  tags: ["Admin Operations"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:operations:read"] }],
  request: { params: jobParams },
  responses: {
    200: {
      description: "Redacted job metadata without payload/provider body.",
      content: {
        "application/json": { schema: objectResponse(adminJobSchema) },
      },
    },
    ...errors,
  },
});
const jobRetry = createRoute({
  method: "post",
  path: "/v1/admin/jobs/{job_id}/retry",
  operationId: "retryAdminJob",
  tags: ["Admin Operations"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:operations:write"] }],
  request: {
    params: jobParams,
    headers: retryHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: adminRetrySchema } },
    },
  },
  responses: {
    202: {
      description: "Audited retry queued exactly once.",
      content: {
        "application/json": { schema: objectResponse(adminJobSchema) },
      },
    },
    ...errors,
  },
});
const privacy = createRoute({
  method: "get",
  path: "/v1/admin/privacy/requests",
  operationId: "listAdminPrivacyRequests",
  tags: ["Admin Privacy"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:privacy:read"] }],
  request: { query: privacyQuery },
  responses: {
    200: {
      description: "Bounded minimized privacy operation metadata.",
      content: {
        "application/json": { schema: collectionResponse(adminPrivacySchema) },
      },
    },
    ...errors,
  },
});
const privacyDetail = createRoute({
  method: "get",
  path: "/v1/admin/privacy/requests/{request_id}",
  operationId: "getAdminPrivacyRequest",
  tags: ["Admin Privacy"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:privacy:read"] }],
  request: { params: privacyParams },
  responses: {
    200: {
      description: "Minimized privacy operation metadata.",
      content: {
        "application/json": { schema: objectResponse(adminPrivacySchema) },
      },
    },
    ...errors,
  },
});
const privacyRetry = createRoute({
  method: "post",
  path: "/v1/admin/privacy/requests/{request_id}/retry",
  operationId: "retryAdminPrivacyRequest",
  tags: ["Admin Privacy"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:privacy:write"] }],
  request: {
    params: privacyParams,
    headers: retryHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: adminRetrySchema } },
    },
  },
  responses: {
    202: {
      description: "Audited privacy retry queued exactly once.",
      content: {
        "application/json": {
          schema: objectResponse(
            z.object({ outbox_id: z.string().uuid() }).strict(),
          ),
        },
      },
    },
    ...errors,
  },
});

export type AdminOperationsRouteDependencies = AdminRouteDependencies & {
  adminOperationsRepository?: AdminOperationsRepository;
};

export function registerAdminOperationsRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: AdminOperationsRouteDependencies = {},
) {
  for (const route of [jobs, job])
    for (const middleware of adminSecurity(
      dependencies,
      "get",
      "admin:operations:read",
      "RL_ADMIN_READ",
    ))
      app.use(route.getRoutingPath(), middleware);
  for (const middleware of adminSecurity(
    dependencies,
    "post",
    "admin:operations:write",
    "RL_ADMIN_HIGH",
  ))
    app.use(jobRetry.getRoutingPath(), middleware);
  for (const route of [privacy, privacyDetail])
    for (const middleware of adminSecurity(
      dependencies,
      "get",
      "admin:privacy:read",
      "RL_ADMIN_READ",
    ))
      app.use(route.getRoutingPath(), middleware);
  for (const middleware of adminSecurity(
    dependencies,
    "post",
    "admin:privacy:write",
    "RL_ADMIN_HIGH",
  ))
    app.use(privacyRetry.getRoutingPath(), middleware);
  const repository = (context: any) =>
    dependencies.adminOperationsRepository ??
    (context.env.STAFF_DATABASE_URL === undefined
      ? undefined
      : createPostgresAdminOperationsRepository(
          context.env.STAFF_DATABASE_URL,
        ));
  const unavailable = (context: any) =>
    context.json(
      {
        error: {
          code: "service_unavailable",
          message: "Admin operations are unavailable.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: true,
        },
      },
      503,
    );
  const missing = (context: any) =>
    context.json(
      {
        error: {
          code: "not_found",
          message: "Operation not found.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      404,
    );
  const commandError = (context: any, error: AdminOperationConflictError) =>
    error.code === "not_found"
      ? missing(context)
      : context.json(
          {
            error: {
              code: error.code,
              message:
                error.code === "idempotency_conflict"
                  ? "The idempotency key conflicts with a prior command."
                  : "The operation is not retryable.",
              request_id: requestIdFrom(context),
              field_errors: [],
              retryable: false,
            },
          },
          409,
        );
  const loadPage = async (context: any, kind: "jobs" | "privacy") => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (staff === undefined || repo === undefined || secret === undefined)
      return unavailable(context);
    const query = context.req.valid("query");
    const scope = `admin:${kind}:${query.status ?? "all"}`;
    try {
      const after = await decodeCursor(secret, scope, query.cursor);
      const input = {
        limit: query.limit,
        ...(query.status === undefined ? {} : { status: query.status }),
        ...(after === undefined ? {} : { after }),
      };
      const page =
        kind === "jobs"
          ? await repo.listJobs(staff, input)
          : await repo.listPrivacy(staff, input);
      const nextCursor =
        page.next === null
          ? null
          : await encodeCursor(secret, scope, page.next);
      return context.json(
        {
          data: page.items,
          meta: {
            request_id: requestIdFrom(context),
            next_cursor: nextCursor,
            has_more: nextCursor !== null,
          },
        },
        200,
      );
    } catch (error) {
      if (!(error instanceof InvalidCursorError)) throw error;
      return context.json(
        {
          error: {
            code: "invalid_cursor",
            message: "The cursor is invalid for this collection.",
            request_id: requestIdFrom(context),
            field_errors: [{ path: "query.cursor", code: "invalid_cursor" }],
            retryable: false,
          },
        },
        422,
      );
    }
  };

  app.openapi(jobs, (async (context: any) =>
    loadPage(context, "jobs")) as never);
  app.openapi(privacy, (async (context: any) =>
    loadPage(context, "privacy")) as never);
  app.openapi(job, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (staff === undefined || repo === undefined) return unavailable(context);
    const data = await repo.getJob(staff, context.req.valid("param").job_id);
    return data === null
      ? missing(context)
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
  app.openapi(jobRetry, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    const queue = context.env.ASYNC_QUEUE;
    if (staff === undefined || repo === undefined || queue === undefined)
      return unavailable(context);
    try {
      const data = await repo.retryJob(
        staff,
        context.req.valid("param").job_id,
        context.req.valid("json").reason,
        requestIdFrom(context),
        context.req.valid("header")["idempotency-key"],
      );
      await queue.send({
        schema_version: 1,
        outbox_id: data.outbox_id,
        consumer: data.consumer,
      });
      return context.json(
        { data, meta: { request_id: requestIdFrom(context) } },
        202,
      );
    } catch (error) {
      if (error instanceof AdminOperationConflictError)
        return commandError(context, error);
      throw error;
    }
  }) as never);
  app.openapi(privacyDetail, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (staff === undefined || repo === undefined) return unavailable(context);
    const data = await repo.getPrivacy(
      staff,
      context.req.valid("param").request_id,
    );
    return data === null
      ? missing(context)
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
  app.openapi(privacyRetry, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    const queue = context.env.ASYNC_QUEUE;
    if (staff === undefined || repo === undefined || queue === undefined)
      return unavailable(context);
    try {
      const retry = await repo.retryPrivacy(
        staff,
        context.req.valid("param").request_id,
        context.req.valid("json").reason,
        requestIdFrom(context),
        context.req.valid("header")["idempotency-key"],
      );
      await queue.send({
        schema_version: 1,
        outbox_id: retry.outboxId,
        consumer: retry.consumer,
      });
      return context.json(
        {
          data: { outbox_id: retry.outboxId },
          meta: { request_id: requestIdFrom(context) },
        },
        202,
      );
    } catch (error) {
      if (error instanceof AdminOperationConflictError)
        return commandError(context, error);
      throw error;
    }
  }) as never);
}
