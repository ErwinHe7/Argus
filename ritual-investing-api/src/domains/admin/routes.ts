import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  objectResponse,
} from "../../contracts/common.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../editorial/cursor.ts";
import {
  adminIdentitySecurity,
  adminSecurity,
  type AdminRouteDependencies,
} from "./access.ts";
import {
  createPostgresAdminRepository,
  type AdminRepository,
} from "./repository.ts";
import {
  adminAuditEventSchema,
  adminAuditQuerySchema,
  adminHealthSchema,
  adminMeSchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Dual staff authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Staff permission denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Admin host only.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid filter.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Admin dependency unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;

const meRoute = createRoute({
  method: "get",
  path: "/v1/admin/me",
  operationId: "getAdminMe",
  tags: ["Admin Session"],
  security: [{ CloudflareAccess: [], Auth0OAuth: [] }],
  responses: {
    200: {
      description: "Current active staff session.",
      content: {
        "application/json": { schema: objectResponse(adminMeSchema) },
      },
    },
    ...errors,
  },
});
const readyRoute = createRoute({
  method: "get",
  path: "/v1/admin/health/ready",
  operationId: "getAdminHealthReady",
  tags: ["Admin Session"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:operations:read"] }],
  responses: {
    200: {
      description: "Redacted dependency readiness.",
      content: {
        "application/json": { schema: objectResponse(adminHealthSchema) },
      },
    },
    ...errors,
  },
});
const auditRoute = createRoute({
  method: "get",
  path: "/v1/admin/audit-events",
  operationId: "listAdminAuditEvents",
  tags: ["Admin Audit"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:audit:read"] }],
  request: { query: adminAuditQuerySchema },
  responses: {
    200: {
      description: "Bounded immutable redacted audit events.",
      content: {
        "application/json": {
          schema: collectionResponse(adminAuditEventSchema),
        },
      },
    },
    ...errors,
  },
});

export type AdminBaseRouteDependencies = AdminRouteDependencies & {
  adminRepository?: AdminRepository;
};

export function registerAdminRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: AdminBaseRouteDependencies = {},
) {
  for (const middleware of adminIdentitySecurity(dependencies))
    app.use(meRoute.getRoutingPath(), middleware);
  for (const middleware of adminSecurity(
    dependencies,
    "get",
    "admin:operations:read",
    "RL_ADMIN_READ",
  ))
    app.use(readyRoute.getRoutingPath(), middleware);
  for (const middleware of adminSecurity(
    dependencies,
    "get",
    "admin:audit:read",
    "RL_ADMIN_READ",
  ))
    app.use(auditRoute.getRoutingPath(), middleware);

  app.openapi(meRoute, (context: any) => {
    const staff = context.get("staffPrincipal");
    const principal = context.get("authPrincipal");
    if (staff === undefined || principal === undefined)
      return context.json(
        {
          error: {
            code: "forbidden",
            message: "An active staff principal is required.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: false,
          },
        },
        403,
      );
    return context.json(
      {
        data: {
          staff_id: staff.id,
          display_label: staff.displayLabel,
          permissions: principal.permissions
            .filter((permission: string) => permission.startsWith("admin:"))
            .sort(),
          revocation_epoch: staff.revocationEpoch,
        },
        meta: { request_id: requestIdFrom(context) },
      },
      200,
    );
  });
  app.openapi(readyRoute, (context: any) => {
    const dependenciesState = {
      neon:
        context.env.STAFF_DATABASE_URL === undefined
          ? ("missing" as const)
          : ("configured" as const),
      queue:
        context.env.ASYNC_QUEUE === undefined
          ? ("missing" as const)
          : ("configured" as const),
      media:
        context.env.MEDIA_QUARANTINE === undefined
          ? ("missing" as const)
          : ("configured" as const),
      identity:
        context.env.AUTH0_JWKS_URL.length === 0
          ? ("missing" as const)
          : ("configured" as const),
    };
    const status = Object.values(dependenciesState).includes("missing")
      ? ("degraded" as const)
      : ("ready" as const);
    return context.json(
      {
        data: { status, dependencies: dependenciesState },
        meta: { request_id: requestIdFrom(context) },
      },
      200,
    );
  });
  app.openapi(auditRoute, async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repository =
      dependencies.adminRepository ??
      (context.env.STAFF_DATABASE_URL === undefined
        ? undefined
        : createPostgresAdminRepository(context.env.STAFF_DATABASE_URL));
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (staff === undefined || repository === undefined || secret === undefined)
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "The audit store is unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    const query = context.req.valid("query");
    const scope = `admin-audit:${query.actor_staff_id ?? "all"}:${query.action ?? "all"}:${query.target_kind ?? "all"}:${query.from ?? "start"}:${query.to ?? "end"}`;
    try {
      const after = await decodeCursor(secret, scope, query.cursor);
      const page = await repository.listAudit({
        actorStaffId: staff.id,
        limit: query.limit,
        ...(query.actor_staff_id === undefined
          ? {}
          : { filterActorStaffId: query.actor_staff_id }),
        ...(query.action === undefined ? {} : { action: query.action }),
        ...(query.target_kind === undefined
          ? {}
          : { targetKind: query.target_kind }),
        ...(query.from === undefined ? {} : { from: query.from }),
        ...(query.to === undefined ? {} : { to: query.to }),
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
      if (error instanceof InvalidCursorError)
        return context.json(
          {
            error: {
              code: "invalid_cursor",
              message: "The audit cursor is invalid.",
              request_id: requestIdFrom(context),
              field_errors: [],
              retryable: false,
            },
          },
          422,
        );
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "The audit store is unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    }
  });
}
