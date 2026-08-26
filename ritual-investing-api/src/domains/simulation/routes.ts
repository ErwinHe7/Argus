import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import { errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  simulationAccess,
  simulationSecurity,
  type SimulationRouteDependencies,
} from "./access.ts";
import {
  SimulationConflictError,
  SimulationInProgressError,
  SimulationInputError,
  SimulationNotFoundError,
} from "./repository.ts";
import {
  commandHeaders,
  contributionSchema,
  portfolioParams,
  simulationResultSchema,
} from "./schemas.ts";

export type { SimulationRouteDependencies } from "./access.ts";

export const simulationErrors = {
  401: {
    description: "Invalid token.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "Simulation conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  413: {
    description: "Too large.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  415: {
    description: "Unsupported media.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid input.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;

const contributionRoute = createRoute({
  method: "post",
  path: "/v1/portfolios/{portfolio_id}/contributions",
  operationId: "createDemoContribution",
  tags: ["Simulation"],
  security: [{ Auth0OAuth: ["write:self", "simulate:self"] }],
  request: {
    params: portfolioParams,
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: contributionSchema } },
    },
  },
  responses: {
    200: {
      description: "Committed fixture-backed Demo contribution.",
      content: {
        "application/json": {
          schema: objectResponse(simulationResultSchema).openapi(
            "SimulationResultResponse",
          ),
        },
      },
    },
    ...simulationErrors,
  },
});

export function simulationError(context: any, error: unknown): Response {
  if (error instanceof SimulationNotFoundError)
    return errorResponse(
      context,
      404,
      "not_found",
      "The requested resource was not found.",
    );
  if (error instanceof SimulationInProgressError)
    return errorResponse(
      context,
      409,
      "command_in_progress",
      "This Demo command is still processing. Retry with the same key.",
      { retryable: true, retryAfterSeconds: 2 },
    );
  if (error instanceof SimulationConflictError)
    return errorResponse(
      context,
      409,
      error.code,
      "The Demo command conflicts with current server state.",
    );
  if (error instanceof SimulationInputError)
    return errorResponse(
      context,
      422,
      error.code,
      "The Demo command input is not valid for this resource.",
    );
  return errorResponse(
    context,
    503,
    "service_unavailable",
    "Simulation storage is temporarily unavailable.",
    { retryable: true },
  );
}

export function registerSimulationRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: SimulationRouteDependencies = {},
): void {
  for (const middleware of simulationSecurity(
    dependencies,
    contributionRoute.method,
  ))
    app.use(contributionRoute.getRoutingPath(), middleware);
  app.openapi(contributionRoute, async (context) => {
    const access = simulationAccess(context, dependencies);
    if (access === undefined)
      return simulationError(
        context,
        new Error("repository_unavailable"),
      ) as never;
    try {
      const result = await access.repository.contribute(
        access.member,
        context.req.valid("param").portfolio_id,
        context.req.valid("json"),
        context.req.header("idempotency-key")!,
      );
      context.header("cache-control", "private, no-store");
      context.header("etag", `"v${result.portfolio_version}"`);
      return context.json(
        { data: result, meta: { request_id: requestIdFrom(context) } },
        200,
      ) as never;
    } catch (error) {
      return simulationError(context, error) as never;
    }
  });
}
