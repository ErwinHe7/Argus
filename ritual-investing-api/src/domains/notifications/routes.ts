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
  memberSecurity,
  sensitiveMemberSecurity,
  type MemberRouteDependencies,
  versionFrom,
} from "../accounts/access.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../editorial/cursor.ts";
import { currentMember } from "../u7-support.ts";
import {
  createPostgresNotificationRepository,
  NotificationConflictError,
  NotificationContentNotFoundError,
  type NotificationRepository,
} from "./repository.ts";
import {
  contentReportCreateSchema,
  contentReportSchema,
  deviceCreateSchema,
  deviceSchema,
  notificationListQuerySchema,
  notificationPreferencesPatchSchema,
  notificationPreferencesSchema,
  notificationReadAllSchema,
  notificationReadSchema,
  notificationSchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Authentication required.",
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
    description: "Optimistic concurrency or idempotency conflict.",
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
    description: "Temporarily unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const commandHeaders = z.object({ "idempotency-key": idempotencyKeySchema });
const preferenceHeaders = z.object({ "if-match": etagSchema });

const prefGet = createRoute({
  method: "get",
  path: "/v1/me/notification-preferences",
  operationId: "getNotificationPreferences",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["read:self"] }],
  responses: {
    200: {
      description: "Member notification preferences.",
      content: {
        "application/json": {
          schema: objectResponse(notificationPreferencesSchema),
        },
      },
    },
    ...errors,
  },
});
const prefPatch = createRoute({
  method: "patch",
  path: "/v1/me/notification-preferences",
  operationId: "patchNotificationPreferences",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    headers: preferenceHeaders,
    body: {
      required: true,
      content: {
        "application/json": { schema: notificationPreferencesPatchSchema },
      },
    },
  },
  responses: {
    200: {
      description: "Updated preferences.",
      content: {
        "application/json": {
          schema: objectResponse(notificationPreferencesSchema),
        },
      },
    },
    ...errors,
  },
});
const deviceCreate = createRoute({
  method: "post",
  path: "/v1/me/devices",
  operationId: "registerNotificationDevice",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: deviceCreateSchema } },
    },
  },
  responses: {
    201: {
      description: "Registered encrypted device token.",
      content: { "application/json": { schema: objectResponse(deviceSchema) } },
    },
    ...errors,
  },
});
const deviceDelete = createRoute({
  method: "delete",
  path: "/v1/me/devices/{installation_id}",
  operationId: "revokeNotificationDevice",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    params: z.object({ installation_id: z.string().uuid() }).strict(),
  },
  responses: { 204: { description: "Device revoked." }, ...errors },
});
const listRoute = createRoute({
  method: "get",
  path: "/v1/notifications",
  operationId: "listNotifications",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["read:self"] }],
  request: { query: notificationListQuerySchema },
  responses: {
    200: {
      description: "Bounded member notifications.",
      content: {
        "application/json": { schema: collectionResponse(notificationSchema) },
      },
    },
    ...errors,
  },
});
const readRoute = createRoute({
  method: "put",
  path: "/v1/notifications/{notification_id}/read-state",
  operationId: "setNotificationReadState",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    params: z.object({ notification_id: z.string().uuid() }).strict(),
    body: {
      required: true,
      content: { "application/json": { schema: notificationReadSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated notification read state.",
      content: {
        "application/json": { schema: objectResponse(notificationSchema) },
      },
    },
    ...errors,
  },
});
const readAllRoute = createRoute({
  method: "post",
  path: "/v1/notifications/read-all",
  operationId: "readAllNotifications",
  tags: ["Notifications"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    headers: commandHeaders,
    body: {
      required: false,
      content: { "application/json": { schema: notificationReadAllSchema } },
    },
  },
  responses: {
    200: {
      description: "A bounded page of notifications marked read.",
      content: {
        "application/json": {
          schema: objectResponse(
            z
              .object({
                updated_count: z.number().int().nonnegative().max(100),
              })
              .strict(),
          ),
        },
      },
    },
    ...errors,
  },
});
const reportRoute = createRoute({
  method: "post",
  path: "/v1/content-reports",
  operationId: "createContentReport",
  tags: ["Moderation"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: contentReportCreateSchema } },
    },
  },
  responses: {
    201: {
      description: "Nontoxic report receipt.",
      content: {
        "application/json": { schema: objectResponse(contentReportSchema) },
      },
    },
    ...errors,
  },
});

export type NotificationRouteDependencies = MemberRouteDependencies & {
  notificationRepository?: NotificationRepository;
};

export function registerNotificationRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: NotificationRouteDependencies = {},
) {
  for (const middleware of memberSecurity(dependencies, false, "get")) {
    app.use(prefGet.getRoutingPath(), middleware);
    app.use(listRoute.getRoutingPath(), middleware);
  }
  for (const middleware of memberSecurity(dependencies, true, "patch"))
    app.use(prefPatch.getRoutingPath(), middleware);
  for (const middleware of sensitiveMemberSecurity(dependencies, "post"))
    app.use(deviceCreate.getRoutingPath(), middleware);
  for (const method of ["post", "put", "delete"] as const)
    for (const middleware of memberSecurity(dependencies, true, method)) {
      app.use("/v1/me/devices/*", middleware);
      app.use("/v1/notifications/*", middleware);
      app.use("/v1/content-reports", middleware);
    }

  const access = (context: any) => ({
    member: currentMember(context),
    repository:
      dependencies.notificationRepository ??
      (context.env.RUNTIME_DATABASE_URL === undefined
        ? undefined
        : createPostgresNotificationRepository(
            context.env.RUNTIME_DATABASE_URL,
          )),
  });
  const unavailable = (context: any) =>
    context.json(
      {
        error: {
          code: "service_unavailable",
          message: "Notifications are unavailable.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: true,
        },
      },
      503,
    );
  const conflict = (context: any, error: NotificationConflictError) =>
    context.json(
      {
        error: {
          code: error.message,
          message:
            "The request conflicts with a prior version or idempotency key.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      409,
    );

  app.openapi(prefGet, (async (context: any) => {
    const { member, repository } = access(context);
    return member === undefined || repository === undefined
      ? unavailable(context)
      : context.json(
          {
            data: await repository.getPreferences(member),
            meta: { request_id: requestIdFrom(context) },
          },
          200,
        );
  }) as never);
  app.openapi(prefPatch, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    const version = versionFrom(context.req.valid("header")["if-match"]);
    if (version === undefined) throw new Error("validated_etag_missing");
    try {
      return context.json(
        {
          data: await repository.patchPreferences(
            member,
            context.req.valid("json"),
            version,
          ),
          meta: { request_id: requestIdFrom(context) },
        },
        200,
      );
    } catch (error) {
      if (error instanceof NotificationConflictError)
        return conflict(context, error);
      throw error;
    }
  }) as never);
  app.openapi(deviceCreate, (async (context: any) => {
    const { member, repository } = access(context);
    const key = context.env.PUSH_TOKEN_ENCRYPTION_KEY;
    if (member === undefined || repository === undefined || key === undefined)
      return unavailable(context);
    try {
      return context.json(
        {
          data: await repository.registerDevice(
            member,
            context.req.valid("json"),
            key,
            context.req.valid("header")["idempotency-key"],
          ),
          meta: { request_id: requestIdFrom(context) },
        },
        201,
      );
    } catch (error) {
      if (error instanceof NotificationConflictError)
        return conflict(context, error);
      throw error;
    }
  }) as never);
  app.openapi(deviceDelete, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    await repository.revokeDevice(
      member,
      context.req.valid("param").installation_id,
    );
    return context.body(null, 204);
  }) as never);
  app.openapi(listRoute, (async (context: any) => {
    const { member, repository } = access(context);
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (
      member === undefined ||
      repository === undefined ||
      secret === undefined
    )
      return unavailable(context);
    const query = context.req.valid("query");
    try {
      const scope = `notifications:${member.tenantId}:${query.read}`;
      const after = await decodeCursor(secret, scope, query.cursor);
      const page = await repository.list(member, {
        read: query.read,
        limit: query.limit,
        ...(after === undefined ? {} : { after }),
      });
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
  }) as never);
  app.openapi(readRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    const data = await repository.markRead(
      member,
      context.req.valid("param").notification_id,
      context.req.valid("json").read,
    );
    return data === null
      ? context.json(
          {
            error: {
              code: "not_found",
              message: "Notification not found.",
              request_id: requestIdFrom(context),
              field_errors: [],
              retryable: false,
            },
          },
          404,
        )
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
  app.openapi(readAllRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    try {
      const data = context.req.valid("json") as { before?: string } | undefined;
      return context.json(
        {
          data: {
            updated_count: await repository.markAllRead(
              member,
              data?.before,
              context.req.valid("header")["idempotency-key"],
            ),
          },
          meta: { request_id: requestIdFrom(context) },
        },
        200,
      );
    } catch (error) {
      if (error instanceof NotificationConflictError)
        return conflict(context, error);
      throw error;
    }
  }) as never);
  app.openapi(reportRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    try {
      return context.json(
        {
          data: await repository.report(
            member,
            context.req.valid("json"),
            context.req.valid("header")["idempotency-key"],
          ),
          meta: { request_id: requestIdFrom(context) },
        },
        201,
      );
    } catch (error) {
      if (error instanceof NotificationContentNotFoundError)
        return context.json(
          {
            error: {
              code: "not_found",
              message: "Content not found.",
              request_id: requestIdFrom(context),
              field_errors: [],
              retryable: false,
            },
          },
          404,
        );
      if (error instanceof NotificationConflictError)
        return conflict(context, error);
      throw error;
    }
  }) as never);
}
