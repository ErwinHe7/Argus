import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { NotificationRepository } from "./ports.ts";
import {
  notificationCollectionResponseSchema,
  notificationPreferencesResponseSchema,
  notificationSchema,
} from "../engagement/schemas.ts";
import {
  dataResponse,
  expectedVersion,
  parseBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  idempotencyKeySchema,
  jsonObjectSchema,
  pageLimitSchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type NotificationRouteRepository = NotificationRepository;

export function registerNotificationRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => NotificationRouteRepository;
  }>,
): void {
  const listNotifications = retainedRoute(
    "get",
    "/v1/notifications",
    "listNotifications",
    "Notifications",
    {
      query: z.object({ limit: pageLimitSchema.optional() }),
      response: notificationCollectionResponseSchema,
    },
  );
  input.register(listNotifications, async (context) =>
    dataResponse(
      context,
      await input.repository(context).list(
        pageLimitSchema.parse(context.req.query("limit")),
      ),
    ));

  const getPreferences = retainedRoute(
    "get",
    "/v1/notification-preferences",
    "getNotificationPreferences",
    "Notifications",
    { response: notificationPreferencesResponseSchema },
  );
  input.register(
    getPreferences,
    async (context) =>
      dataResponse(context, await input.repository(context).getPreferences()),
  );

  const updatePreferences = retainedRoute(
    "patch",
    "/v1/notification-preferences",
    "updateNotificationPreferences",
    "Notifications",
    {
      body: jsonObjectSchema,
      headers: z.object({ "if-match": z.string() }),
      response: notificationPreferencesResponseSchema,
    },
  );
  input.register(updatePreferences, async (context) =>
    dataResponse(
      context,
      await input.repository(context).updatePreferences(
        await parseBody(context, jsonObjectSchema),
        expectedVersion(context),
      ),
    ));

  const readBody = z.object({ read: z.boolean() }).strict()
    .openapi("SetNotificationReadStateRequest");
  const markRead = retainedRoute(
    "patch",
    "/v1/notifications/{notification_id}/read",
    "markNotificationRead",
    "Notifications",
    {
      pathParams: z.object({ notification_id: uuidSchema }),
      body: readBody,
      response: retainedEnvelope("NotificationResponse", notificationSchema),
    },
  );
  input.register(markRead, async (context) => {
    const body = await parseBody(context, readBody);
    return dataResponse(
      context,
      await input.repository(context).setRead(
        uuidSchema.parse(context.req.param("notification_id")),
        body.read,
      ),
    );
  });

  const readAllBody = z.object({
    before: z.string().datetime(),
  }).strict().openapi("ReadAllNotificationsRequest");
  const readAll = retainedRoute(
    "post",
    "/v1/notifications/read-all",
    "readAllNotifications",
    "Notifications",
    {
      body: readAllBody,
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      response: retainedEnvelope(
        "ReadAllNotificationsResponse",
        z.object({
          updated_count: z.number().int().nonnegative().max(10000),
        }).strict(),
      ),
    },
  );
  input.register(readAll, async (context) => {
    const body = await parseBody(context, readAllBody);
    return dataResponse(
      context,
      await input.repository(context).readAll(body.before),
    );
  });
}
