import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  etagSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../../contracts/common.ts";
import { requestIdFrom } from "../../../middleware/request-context.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../../editorial/cursor.ts";
import { adminSecurity, type AdminRouteDependencies } from "../access.ts";
import {
  createPostgresAdminCatalogRepository,
  type AdminCatalogRepository,
  type CatalogKind,
} from "./repository.ts";
import {
  assetSchema,
  catalogListQuerySchema,
  covenQualificationSchema,
  covenVerificationSchema,
  createAssetSchema,
  createCovenQualificationSchema,
  createCovenVerificationSchema,
  createEvidenceClaimSchema,
  createEvidenceSourceSchema,
  createMetricSnapshotSchema,
  createRitualScheduleSchema,
  createSeededCreatorSchema,
  deleteScheduleSchema,
  evidenceClaimSchema,
  evidenceSourceSchema,
  metricSnapshotSchema,
  patchAssetSchema,
  patchEvidenceSourceSchema,
  patchRitualScheduleSchema,
  patchSeededCreatorSchema,
  ritualScheduleSchema,
  scheduleListQuerySchema,
  seededCreatorSchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Dual staff authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Staff permission denied and audited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Resource not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "State, version, or idempotency conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Strict input validation failed.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Catalog unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const idemHeaders = z.object({ "idempotency-key": idempotencyKeySchema });
const etagHeaders = z.object({ "if-match": etagSchema });

export type AdminCatalogRouteDependencies = AdminRouteDependencies & {
  adminCatalogRepository?: AdminCatalogRepository;
};

function repo(context: any, dependencies: AdminCatalogRouteDependencies) {
  return (
    dependencies.adminCatalogRepository ??
    (context.env.STAFF_DATABASE_URL === undefined
      ? undefined
      : createPostgresAdminCatalogRepository(context.env.STAFF_DATABASE_URL))
  );
}
function error(context: any, failure: unknown) {
  const code =
    failure instanceof Error
      ? failure.message.match(
          /not_found|version_conflict|idempotency_conflict|invalid_transition|self_approval|publishability_failed/,
        )?.[0]
      : undefined;
  if (code !== undefined)
    return context.json(
      {
        error: {
          code,
          message:
            code === "not_found"
              ? "The resource was not found."
              : "The administrative transition could not be applied.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      code === "not_found" ? 404 : 409,
    );
  if (failure instanceof InvalidCursorError)
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
  return context.json(
    {
      error: {
        code: "service_unavailable",
        message: "The administrative catalog is unavailable.",
        request_id: requestIdFrom(context),
        field_errors: [],
        retryable: true,
      },
    },
    503,
  );
}
function ok(context: any, value: any, status = 200) {
  if (typeof value?.etag === "string") context.header("etag", value.etag);
  context.header("cache-control", "no-store");
  return context.json(
    { data: value, meta: { request_id: requestIdFrom(context) } },
    status,
  );
}

const crud = [
  {
    kind: "asset" as const,
    path: "/v1/admin/assets",
    id: "asset_id",
    tag: "Admin Assets",
    suffix: "Asset",
    schema: assetSchema,
    create: createAssetSchema,
    patch: patchAssetSchema,
  },
  {
    kind: "evidence_source" as const,
    path: "/v1/admin/evidence-sources",
    id: "source_id",
    tag: "Admin Evidence",
    suffix: "EvidenceSource",
    schema: evidenceSourceSchema,
    create: createEvidenceSourceSchema,
    patch: patchEvidenceSourceSchema,
  },
  {
    kind: "evidence_claim" as const,
    path: "/v1/admin/evidence-claims",
    id: "claim_id",
    tag: "Admin Evidence",
    suffix: "EvidenceClaim",
    schema: evidenceClaimSchema,
    create: createEvidenceClaimSchema,
    patch: null,
  },
  {
    kind: "seeded_creator" as const,
    path: "/v1/admin/seeded-creators",
    id: "creator_id",
    tag: "Admin Seeded Community",
    suffix: "SeededCreator",
    schema: seededCreatorSchema,
    create: createSeededCreatorSchema,
    patch: patchSeededCreatorSchema,
  },
];

export function registerAdminCatalogRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: AdminCatalogRouteDependencies = {},
) {
  for (const definition of crud) {
    const params = z.object({ [definition.id]: z.string().uuid() }).strict();
    const listRoute = createRoute({
      method: "get",
      path: definition.path,
      operationId: `listAdmin${definition.suffix}s`,
      tags: [definition.tag],
      security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:catalog:read"] }],
      request: { query: catalogListQuerySchema },
      responses: {
        200: {
          description: "Bounded staff-safe catalog results.",
          content: {
            "application/json": {
              schema: collectionResponse(definition.schema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const createRouteDefinition = createRoute({
      method: "post",
      path: definition.path,
      operationId: `createAdmin${definition.suffix}`,
      tags: [definition.tag],
      security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:catalog:write"] }],
      request: {
        headers: idemHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: definition.create } },
        },
      },
      responses: {
        201: {
          description: "Audited global catalog record.",
          content: {
            "application/json": { schema: objectResponse(definition.schema) },
          },
        },
        ...errors,
      },
    } as any);
    const detailRoute = createRoute({
      method: "get",
      path: `${definition.path}/{${definition.id}}`,
      operationId: `getAdmin${definition.suffix}`,
      tags: [definition.tag],
      security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:catalog:read"] }],
      request: { params },
      responses: {
        200: {
          description: "Staff-safe catalog detail.",
          content: {
            "application/json": { schema: objectResponse(definition.schema) },
          },
        },
        ...errors,
      },
    } as any);
    for (const [route, method, permission, rate] of [
      [listRoute, "get", "admin:catalog:read", "RL_ADMIN_READ"],
      [createRouteDefinition, "post", "admin:catalog:write", "RL_ADMIN_WRITE"],
      [detailRoute, "get", "admin:catalog:read", "RL_ADMIN_READ"],
    ] as const)
      for (const middleware of adminSecurity(
        dependencies,
        method,
        permission,
        rate,
      ))
        app.use(route.getRoutingPath(), middleware);
    app.openapi(listRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repo(context, dependencies);
      const secret = context.env.CURSOR_SIGNING_KEY;
      if (
        staff === undefined ||
        repository === undefined ||
        secret === undefined
      )
        return error(context, new Error("unavailable"));
      const query = context.req.valid("query");
      const scope = `admin-catalog:${definition.kind}:${query.status ?? "all"}:${query.type ?? "all"}:${query.search ?? "all"}`;
      try {
        const after = await decodeCursor(secret, scope, query.cursor);
        const page = await repository.list({
          actorStaffId: staff.id,
          kind: definition.kind,
          filters: {
            status: query.status,
            type: query.type,
            search: query.search,
          },
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
      } catch (failure) {
        return error(context, failure);
      }
    });
    app.openapi(createRouteDefinition, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repo(context, dependencies);
      if (staff === undefined || repository === undefined)
        return error(context, new Error("unavailable"));
      try {
        return ok(
          context,
          await repository.create({
            actorStaffId: staff.id,
            kind: definition.kind,
            payload: context.req.valid("json"),
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
          201,
        );
      } catch (failure) {
        return error(context, failure);
      }
    });
    app.openapi(detailRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repo(context, dependencies);
      if (staff === undefined || repository === undefined)
        return error(context, new Error("unavailable"));
      try {
        const value = await repository.get({
          actorStaffId: staff.id,
          kind: definition.kind,
          id: context.req.valid("param")[definition.id],
        });
        if (value === null) throw new Error("not_found");
        return ok(context, value);
      } catch (failure) {
        return error(context, failure);
      }
    });
    if (definition.patch !== null) {
      const patchRoute = createRoute({
        method: "patch",
        path: `${definition.path}/{${definition.id}}`,
        operationId: `patchAdmin${definition.suffix}`,
        tags: [definition.tag],
        security: [
          { CloudflareAccess: [], Auth0OAuth: ["admin:catalog:write"] },
        ],
        request: {
          params,
          headers: etagHeaders,
          body: {
            required: true,
            content: { "application/json": { schema: definition.patch } },
          },
        },
        responses: {
          200: {
            description: "Conditionally updated audited record.",
            content: {
              "application/json": { schema: objectResponse(definition.schema) },
            },
          },
          ...errors,
        },
      } as any);
      for (const middleware of adminSecurity(
        dependencies,
        "patch",
        "admin:catalog:write",
        "RL_ADMIN_WRITE",
      ))
        app.use(patchRoute.getRoutingPath(), middleware);
      app.openapi(patchRoute, async (context: any) => {
        const staff = context.get("staffPrincipal");
        const repository = repo(context, dependencies);
        if (staff === undefined || repository === undefined)
          return error(context, new Error("unavailable"));
        try {
          return ok(
            context,
            await repository.patch({
              actorStaffId: staff.id,
              kind: definition.kind,
              id: context.req.valid("param")[definition.id],
              payload: context.req.valid("json"),
              expectedVersion: Number(
                context.req.valid("header")["if-match"].slice(2, -1),
              ),
              requestId: requestIdFrom(context),
            }),
          );
        } catch (failure) {
          return error(context, failure);
        }
      });
    }
  }

  const appendDefinitions = [
    {
      action: "asset_metric" as const,
      path: "/v1/admin/assets/{asset_id}/metric-snapshots",
      param: "asset_id",
      operationId: "createAdminAssetMetricSnapshot",
      permission: "admin:catalog:write",
      body: createMetricSnapshotSchema,
      response: metricSnapshotSchema,
    },
    {
      action: "coven_qualification" as const,
      path: "/v1/admin/coven-entries/{entry_id}/qualifications",
      param: "entry_id",
      operationId: "createAdminCovenQualification",
      permission: "admin:editorial:write",
      body: createCovenQualificationSchema,
      response: covenQualificationSchema,
    },
    {
      action: "coven_verification" as const,
      path: "/v1/admin/coven-qualifications/{qualification_id}/verifications",
      param: "qualification_id",
      operationId: "verifyAdminCovenQualification",
      permission: "admin:coven:verify",
      body: createCovenVerificationSchema,
      response: covenVerificationSchema,
    },
  ];
  for (const definition of appendDefinitions) {
    const route = createRoute({
      method: "post",
      path: definition.path,
      operationId: definition.operationId,
      tags: ["Admin Catalog"],
      security: [{ CloudflareAccess: [], Auth0OAuth: [definition.permission] }],
      request: {
        params: z.object({ [definition.param]: z.string().uuid() }).strict(),
        headers: idemHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: definition.body } },
        },
      },
      responses: {
        201: {
          description: "Immutable audited child record.",
          content: {
            "application/json": { schema: objectResponse(definition.response) },
          },
        },
        ...errors,
      },
    } as any);
    for (const middleware of adminSecurity(
      dependencies,
      "post",
      definition.permission,
      definition.action === "coven_verification"
        ? "RL_ADMIN_HIGH"
        : "RL_ADMIN_WRITE",
    ))
      app.use(route.getRoutingPath(), middleware);
    app.openapi(route, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repo(context, dependencies);
      if (staff === undefined || repository === undefined)
        return error(context, new Error("unavailable"));
      try {
        return ok(
          context,
          await repository.append({
            actorStaffId: staff.id,
            action: definition.action,
            parentId: context.req.valid("param")[definition.param],
            payload: context.req.valid("json"),
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
          201,
        );
      } catch (failure) {
        return error(context, failure);
      }
    });
  }

  const scheduleParams = z.object({ schedule_id: z.string().uuid() }).strict();
  const listSchedules = createRoute({
    method: "get",
    path: "/v1/admin/ritual-schedules",
    operationId: "listAdminRitualSchedules",
    tags: ["Admin Scheduling"],
    security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:editorial:read"] }],
    request: { query: scheduleListQuerySchema },
    responses: {
      200: {
        description: "Bounded schedules.",
        content: {
          "application/json": {
            schema: collectionResponse(ritualScheduleSchema),
          },
        },
      },
      ...errors,
    },
  });
  const createSchedule = createRoute({
    method: "post",
    path: "/v1/admin/ritual-schedules",
    operationId: "createAdminRitualSchedule",
    tags: ["Admin Scheduling"],
    security: [
      { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:publish"] },
    ],
    request: {
      headers: idemHeaders,
      body: {
        required: true,
        content: { "application/json": { schema: createRitualScheduleSchema } },
      },
    },
    responses: {
      201: {
        description: "Audited approved schedule.",
        content: {
          "application/json": { schema: objectResponse(ritualScheduleSchema) },
        },
      },
      ...errors,
    },
  });
  const patchSchedule = createRoute({
    method: "patch",
    path: "/v1/admin/ritual-schedules/{schedule_id}",
    operationId: "patchAdminRitualSchedule",
    tags: ["Admin Scheduling"],
    security: [
      { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:publish"] },
    ],
    request: {
      params: scheduleParams,
      headers: etagHeaders,
      body: {
        required: true,
        content: { "application/json": { schema: patchRitualScheduleSchema } },
      },
    },
    responses: {
      200: {
        description: "Conditionally updated schedule.",
        content: {
          "application/json": { schema: objectResponse(ritualScheduleSchema) },
        },
      },
      ...errors,
    },
  });
  const deleteSchedule = createRoute({
    method: "delete",
    path: "/v1/admin/ritual-schedules/{schedule_id}",
    operationId: "withdrawAdminRitualSchedule",
    tags: ["Admin Scheduling"],
    security: [
      { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:publish"] },
    ],
    request: {
      params: scheduleParams,
      headers: etagHeaders,
      body: {
        required: true,
        content: { "application/json": { schema: deleteScheduleSchema } },
      },
    },
    responses: {
      204: { description: "Schedule withdrawn; assignments remain frozen." },
      ...errors,
    },
  });
  for (const [route, method, permission, rate] of [
    [listSchedules, "get", "admin:editorial:read", "RL_ADMIN_READ"],
    [createSchedule, "post", "admin:editorial:publish", "RL_ADMIN_HIGH"],
    [patchSchedule, "patch", "admin:editorial:publish", "RL_ADMIN_HIGH"],
    [deleteSchedule, "delete", "admin:editorial:publish", "RL_ADMIN_HIGH"],
  ] as const)
    for (const middleware of adminSecurity(
      dependencies,
      method,
      permission,
      rate,
    ))
      app.use(route.getRoutingPath(), middleware);
  app.openapi(listSchedules, async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repository = repo(context, dependencies);
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (staff === undefined || repository === undefined || secret === undefined)
      return error(context, new Error("unavailable"));
    const query = context.req.valid("query");
    const scope = `admin-schedules:${query.from}:${query.to}:${query.mode ?? "all"}:${query.state ?? "all"}`;
    try {
      const after = await decodeCursor(secret, scope, query.cursor);
      const page = await repository.list({
        actorStaffId: staff.id,
        kind: "ritual_schedule",
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
    } catch (failure) {
      return error(context, failure);
    }
  });
  app.openapi(createSchedule, async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repository = repo(context, dependencies);
    if (staff === undefined || repository === undefined)
      return error(context, new Error("unavailable"));
    try {
      return ok(
        context,
        await repository.create({
          actorStaffId: staff.id,
          kind: "ritual_schedule",
          payload: context.req.valid("json"),
          requestId: requestIdFrom(context),
          idempotencyKey: context.req.valid("header")["idempotency-key"],
        }),
        201,
      );
    } catch (failure) {
      return error(context, failure);
    }
  });
  app.openapi(patchSchedule, async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repository = repo(context, dependencies);
    if (staff === undefined || repository === undefined)
      return error(context, new Error("unavailable"));
    try {
      return ok(
        context,
        await repository.patch({
          actorStaffId: staff.id,
          kind: "ritual_schedule",
          id: context.req.valid("param").schedule_id,
          payload: context.req.valid("json"),
          expectedVersion: Number(
            context.req.valid("header")["if-match"].slice(2, -1),
          ),
          requestId: requestIdFrom(context),
        }),
      );
    } catch (failure) {
      return error(context, failure);
    }
  });
  app.openapi(deleteSchedule, async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repository = repo(context, dependencies);
    if (staff === undefined || repository === undefined)
      return error(context, new Error("unavailable"));
    try {
      await repository.withdrawSchedule({
        actorStaffId: staff.id,
        scheduleId: context.req.valid("param").schedule_id,
        expectedVersion: Number(
          context.req.valid("header")["if-match"].slice(2, -1),
        ),
        reason: context.req.valid("json").reason,
        requestId: requestIdFrom(context),
      });
      return context.body(null, 204);
    } catch (failure) {
      return error(context, failure);
    }
  });
}
