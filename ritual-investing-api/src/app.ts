import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";

import type { Bindings } from "./config/env.ts";
import { errorResponseSchema, objectResponse } from "./contracts/common.ts";
import { buildOpenApiDocument } from "./contracts/openapi.ts";
import {
  registerSessionRoutes,
  type SessionRouteDependencies,
} from "./domains/session/routes.ts";
import { registerEditorialContentRoutes } from "./domains/editorial/routes.ts";
import { registerAccountRoutes } from "./domains/accounts/routes.ts";
import type { MemberRouteDependencies } from "./domains/accounts/access.ts";
import { registerCircleRoutes } from "./domains/circles/routes.ts";
import { registerSaveRoutes } from "./domains/saves/routes.ts";
import {
  registerSimulationRoutes,
  type SimulationRouteDependencies,
} from "./domains/simulation/routes.ts";
import { registerPortfolioRoutes } from "./domains/portfolios/routes.ts";
import { registerOrderRoutes } from "./domains/orders/routes.ts";
import { registerRecurringPlanRoutes } from "./domains/recurring-plans/routes.ts";
import { registerRebalanceRoutes } from "./domains/rebalancing/routes.ts";
import { registerIntentionRoutes } from "./domains/intentions/routes.ts";
import { registerEntitlementRoutes } from "./domains/entitlements/routes.ts";
import type { ContentRouteDependencies } from "./domains/editorial/route-support.ts";
import type { AccountTenantVariables } from "./middleware/account-tenant.ts";
import type { AuthVariables } from "./middleware/auth0-jwk.ts";
import type { AccessVariables } from "./middleware/cloudflare-access.ts";
import { errorHandler, validationError } from "./middleware/error-handler.ts";
import { preAuthRateLimit } from "./middleware/rate-limit.ts";
import {
  requestContext,
  requestIdFrom,
  type RequestContextVariables,
} from "./middleware/request-context.ts";
import {
  exactOriginCors,
  securityHeaders,
} from "./middleware/security-headers.ts";
import { requireRestoreCutover } from "./middleware/restore-cutover.ts";
import {
  registerBriefingRoutes,
  type BriefingRouteDependencies,
} from "./domains/briefings/routes.ts";
import {
  registerNotificationRoutes,
  type NotificationRouteDependencies,
} from "./domains/notifications/routes.ts";
import {
  registerPrivacyRoutes,
  type PrivacyRouteDependencies,
} from "./domains/privacy/routes.ts";
import {
  registerMediaRoutes,
  type MediaRouteDependencies,
} from "./domains/media/routes.ts";
import {
  registerAdminOperationsRoutes,
  type AdminOperationsRouteDependencies,
} from "./domains/admin-operations/routes.ts";
import {
  registerAdminEditorialRoutes,
  type AdminEditorialRouteDependencies,
} from "./domains/admin/editorial-workflow/routes.ts";
import {
  registerAdminRoutes,
  type AdminBaseRouteDependencies,
} from "./domains/admin/routes.ts";
import {
  registerAdminCatalogRoutes,
  type AdminCatalogRouteDependencies,
} from "./domains/admin/catalog/routes.ts";
import {
  registerAdminModerationRoutes,
  type AdminModerationRouteDependencies,
} from "./domains/moderation/routes.ts";
import {
  telemetryMiddleware,
  type TelemetrySink,
} from "./observability/telemetry.ts";

export type AppEnvironment = {
  Bindings: Bindings;
  Variables: RequestContextVariables &
    AuthVariables &
    AccountTenantVariables &
    AccessVariables;
};

const healthDataSchema = z
  .object({
    status: z.literal("ok"),
    build_revision: z.string().min(1),
  })
  .strict();
const healthResponseSchema =
  objectResponse(healthDataSchema).openapi("HealthResponse");
const openApiDocumentSchema = z
  .object({
    openapi: z.literal("3.0.3"),
  })
  .passthrough()
  .openapi("OpenApiDocument");

const healthRoute = createRoute({
  method: "get",
  path: "/health",
  operationId: "getHealth",
  tags: ["Platform"],
  security: [],
  responses: {
    200: {
      description: "Worker liveness without a database dependency.",
      content: { "application/json": { schema: healthResponseSchema } },
    },
  },
});

const liveHealthRoute = createRoute({
  method: "get",
  path: "/v1/health/live",
  operationId: "getLiveHealth",
  tags: ["Platform"],
  security: [],
  responses: {
    200: {
      description: "Worker liveness without a database or provider dependency.",
      content: { "application/json": { schema: healthResponseSchema } },
    },
  },
});

const openApiRoute = createRoute({
  method: "get",
  path: "/v1/openapi.json",
  operationId: "getOpenApiDocument",
  tags: ["Platform"],
  security: [],
  responses: {
    200: {
      description: "OpenAPI 3.0.3 contract without runtime configuration.",
      headers: {
        ETag: { schema: { type: "string" } },
        "Cache-Control": { schema: { type: "string" } },
      },
      content: { "application/json": { schema: openApiDocumentSchema } },
    },
    304: {
      description: "Contract revision unchanged.",
      headers: { ETag: { schema: { type: "string" } } },
    },
    429: {
      description: "Rate limited.",
      headers: { "Retry-After": { schema: { type: "integer", minimum: 1 } } },
      content: { "application/json": { schema: errorResponseSchema } },
    },
    503: {
      description: "The health rate limit could not be checked.",
      content: { "application/json": { schema: errorResponseSchema } },
    },
  },
});

const contractTestRoute = createRoute({
  method: "post",
  path: "/v1/contract-test",
  request: {
    body: {
      required: true,
      content: {
        "application/json": {
          schema: z.object({ title: z.string().min(1).max(120) }).strict(),
        },
      },
    },
  },
  responses: {
    204: { description: "Input passed strict validation." },
    422: {
      description: "Input failed strict validation.",
      content: { "application/json": { schema: errorResponseSchema } },
    },
  },
});

export type CreateAppOptions = {
  enableContractTestRoute?: boolean;
  telemetrySink?: TelemetrySink;
  dependencies?: SessionRouteDependencies &
    ContentRouteDependencies &
    MemberRouteDependencies &
    SimulationRouteDependencies &
    BriefingRouteDependencies &
    NotificationRouteDependencies &
    PrivacyRouteDependencies &
    MediaRouteDependencies &
    AdminOperationsRouteDependencies &
    AdminEditorialRouteDependencies &
    AdminBaseRouteDependencies &
    AdminCatalogRouteDependencies &
    AdminModerationRouteDependencies;
};

export function createApp(options: CreateAppOptions = {}) {
  const app = new OpenAPIHono<AppEnvironment>({
    defaultHook: (result, context) => {
      if (!result.success) {
        return context.json(
          validationError(requestIdFrom(context), result.error),
          422,
        );
      }
    },
  });
  let serializedOpenApi: Promise<{ body: string; etag: string }> | undefined;

  function openApiResponse() {
    serializedOpenApi ??= (async () => {
      const body = JSON.stringify(buildOpenApiDocument(app));
      const digest = new Uint8Array(
        await crypto.subtle.digest("SHA-256", new TextEncoder().encode(body)),
      );
      const revision = [...digest]
        .map((value) => value.toString(16).padStart(2, "0"))
        .join("")
        .slice(0, 24);
      return { body, etag: `"openapi-${revision}"` };
    })();
    return serializedOpenApi;
  }

  app.use("*", requestContext);
  app.use("*", telemetryMiddleware(options.telemetrySink));
  app.use("*", securityHeaders);
  app.use("*", exactOriginCors);
  app.use("/v1/*", requireRestoreCutover);
  app.onError(errorHandler);
  app.notFound((context) =>
    context.json(
      {
        error: {
          code: "not_found",
          message: "The requested resource was not found.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      404,
    ),
  );

  app.use(healthRoute.getRoutingPath(), preAuthRateLimit("RL_HEALTH"));
  app.use(liveHealthRoute.getRoutingPath(), preAuthRateLimit("RL_HEALTH"));
  app.use(openApiRoute.getRoutingPath(), preAuthRateLimit("RL_HEALTH"));
  const healthHandler = (
    context: Parameters<Parameters<typeof app.openapi>[1]>[0],
  ) =>
    context.json(
      {
        data: {
          status: "ok" as const,
          build_revision: context.env?.BUILD_REVISION ?? "unknown",
        },
        meta: { request_id: requestIdFrom(context) },
      },
      200,
    );
  app.openapi(healthRoute, (context) => healthHandler(context));
  app.openapi(liveHealthRoute, (context) => healthHandler(context));
  app.openapi(openApiRoute, async (context) => {
    const { body, etag } = await openApiResponse();
    context.header("etag", etag);
    context.header("cache-control", "public, max-age=300");
    if (context.req.header("if-none-match") === etag)
      return context.body(null, 304) as never;
    return context.body(body, 200, {
      "content-type": "application/json; charset=UTF-8",
    }) as never;
  });

  registerSessionRoutes(app, options.dependencies);
  registerEditorialContentRoutes(app, options.dependencies);
  registerAccountRoutes(app, options.dependencies);
  registerCircleRoutes(app, options.dependencies);
  registerSaveRoutes(app, options.dependencies);
  registerSimulationRoutes(app, options.dependencies);
  registerPortfolioRoutes(app, options.dependencies);
  registerOrderRoutes(app, options.dependencies);
  registerRecurringPlanRoutes(app, options.dependencies);
  registerRebalanceRoutes(app, options.dependencies);
  registerIntentionRoutes(app, options.dependencies);
  registerEntitlementRoutes(app, options.dependencies);
  registerBriefingRoutes(app, options.dependencies);
  registerNotificationRoutes(app, options.dependencies);
  registerPrivacyRoutes(app, options.dependencies);
  registerMediaRoutes(app, options.dependencies);
  registerAdminOperationsRoutes(app, options.dependencies);
  registerAdminRoutes(app, options.dependencies);
  registerAdminEditorialRoutes(app, options.dependencies);
  registerAdminCatalogRoutes(app, options.dependencies);
  registerAdminModerationRoutes(app, options.dependencies);

  if (options.enableContractTestRoute) {
    app.openapi(contractTestRoute, (context) => context.body(null, 204));
  }

  return app;
}
