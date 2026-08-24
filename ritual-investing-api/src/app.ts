import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";

import type { Bindings } from "./config/env.ts";
import { errorResponseSchema, objectResponse } from "./contracts/common.ts";
import { errorHandler, validationError } from "./middleware/error-handler.ts";
import {
  requestContext,
  requestIdFrom,
  type RequestContextVariables,
} from "./middleware/request-context.ts";

export type AppEnvironment = {
  Bindings: Bindings;
  Variables: RequestContextVariables;
};

const healthDataSchema = z.object({ status: z.literal("ok") }).strict();
const sessionDataSchema = z
  .object({
    contract_version: z.literal("1.0.0"),
    server_time: z.iso.datetime({ offset: true }),
  })
  .strict();
const healthResponseSchema = objectResponse(healthDataSchema).openapi("HealthResponse");
const sessionResponseSchema = objectResponse(sessionDataSchema).openapi("SessionResponse");

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

const sessionRoute = createRoute({
  method: "get",
  path: "/v1/session",
  operationId: "getSession",
  tags: ["Platform"],
  security: [{ Auth0OAuth: [] }],
  responses: {
    200: {
      description: "Authenticated member bootstrap.",
      content: { "application/json": { schema: sessionResponseSchema } },
    },
    401: {
      description: "Authentication is not available until the identity module is installed.",
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

  app.openapi(healthRoute, (context) =>
    context.json(
      {
        data: { status: "ok" as const },
        meta: { request_id: requestIdFrom(context) },
      },
      200,
    ),
  );

  app.openapi(sessionRoute, (context) =>
    context.json(
      {
        error: {
          code: "unauthorized",
          message: "A valid member access token is required.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      401,
    ),
  );

  if (options.enableContractTestRoute) {
    app.openapi(contractTestRoute, (context) => context.body(null, 204));
  }

  return app;
}
