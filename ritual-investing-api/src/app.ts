import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";

import type { Bindings } from "./config/env.ts";
import { errorResponseSchema, objectResponse } from "./contracts/common.ts";
import { registerSessionRoutes, type SessionRouteDependencies } from "./domains/session/routes.ts";
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
import { exactOriginCors, securityHeaders } from "./middleware/security-headers.ts";

export type AppEnvironment = {
  Bindings: Bindings;
  Variables: RequestContextVariables & AuthVariables & AccountTenantVariables & AccessVariables;
};

const healthDataSchema = z.object({
  status: z.literal("ok"),
  build_revision: z.string().min(1),
}).strict();
const healthResponseSchema = objectResponse(healthDataSchema).openapi("HealthResponse");

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
  dependencies?: SessionRouteDependencies;
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

  app.use("*", requestContext);
  app.use("*", securityHeaders);
  app.use("*", exactOriginCors);
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
  const healthHandler = (context: Parameters<Parameters<typeof app.openapi>[1]>[0]) =>
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
  app.openapi(healthRoute, (context) =>
    healthHandler(context),
  );
  app.openapi(liveHealthRoute, (context) => healthHandler(context));

  registerSessionRoutes(app, options.dependencies);

  if (options.enableContractTestRoute) {
    app.openapi(contractTestRoute, (context) => context.body(null, 204));
  }

  return app;
}
