import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import {
  simulationAccess,
  type SimulationRouteDependencies,
} from "../simulation/access.ts";
import {
  secureRoute,
  withSimulation,
  withSimulationPage,
} from "../simulation/route-support.ts";
import { simulationError, simulationErrors } from "../simulation/routes.ts";
import {
  commandHeaders,
  etagVersion,
  ifMatchHeaders,
  planParams,
  portfolioParams,
  recurringListQuerySchema,
  recurringPlanCreateSchema,
  recurringPlanPatchSchema,
  recurringPlanSchema,
} from "../simulation/schemas.ts";
const read = [{ Auth0OAuth: ["read:self"] }];
const simulate = [{ Auth0OAuth: ["write:self", "simulate:self"] }];
const list = createRoute({
  method: "get",
  path: "/v1/portfolios/{portfolio_id}/recurring-plans",
  operationId: "listRecurringPlans",
  tags: ["Recurring Plans"],
  security: read,
  request: { params: portfolioParams, query: recurringListQuerySchema },
  responses: {
    200: {
      description: "Current-generation recurring plans.",
      content: {
        "application/json": { schema: collectionResponse(recurringPlanSchema) },
      },
    },
    ...simulationErrors,
  },
});
const create = createRoute({
  method: "post",
  path: "/v1/portfolios/{portfolio_id}/recurring-plans",
  operationId: "createRecurringPlan",
  tags: ["Recurring Plans"],
  security: simulate,
  request: {
    params: portfolioParams,
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: recurringPlanCreateSchema } },
    },
  },
  responses: {
    201: {
      description: "Created Demo recurring plan.",
      content: {
        "application/json": { schema: objectResponse(recurringPlanSchema) },
      },
    },
    ...simulationErrors,
  },
});
const get = createRoute({
  method: "get",
  path: "/v1/recurring-plans/{plan_id}",
  operationId: "getRecurringPlan",
  tags: ["Recurring Plans"],
  security: read,
  request: { params: planParams },
  responses: {
    200: {
      description: "Plan and recent immutable runs.",
      content: {
        "application/json": { schema: objectResponse(recurringPlanSchema) },
      },
    },
    ...simulationErrors,
  },
});
const patch = createRoute({
  method: "patch",
  path: "/v1/recurring-plans/{plan_id}",
  operationId: "patchRecurringPlan",
  tags: ["Recurring Plans"],
  security: simulate,
  request: {
    params: planParams,
    headers: ifMatchHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: recurringPlanPatchSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated plan.",
      content: {
        "application/json": { schema: objectResponse(recurringPlanSchema) },
      },
    },
    ...simulationErrors,
  },
});
const transition = (action: "pause" | "resume") =>
  createRoute({
    method: "post",
    path: `/v1/recurring-plans/{plan_id}/${action}`,
    operationId: `${action}RecurringPlan`,
    tags: ["Recurring Plans"],
    security: simulate,
    request: { params: planParams, headers: ifMatchHeaders },
    responses: {
      200: {
        description: `${action}d plan.`,
        content: {
          "application/json": { schema: objectResponse(recurringPlanSchema) },
        },
      },
      ...simulationErrors,
    },
  });
const pause = transition("pause"),
  resume = transition("resume");
const cancel = createRoute({
  method: "delete",
  path: "/v1/recurring-plans/{plan_id}",
  operationId: "cancelRecurringPlan",
  tags: ["Recurring Plans"],
  security: simulate,
  request: { params: planParams, headers: ifMatchHeaders },
  responses: {
    204: { description: "Terminal cancellation; runs retained." },
    ...simulationErrors,
  },
});
export function registerRecurringPlanRoutes(
  app: OpenAPIHono<AppEnvironment>,
  d: SimulationRouteDependencies = {},
) {
  secureRoute(app, d, list, "read");
  app.openapi(list, (c) => {
    const p = c.req.valid("param"),
      q = c.req.valid("query");
    return withSimulationPage(
      c,
      d,
      `recurring:${p.portfolio_id}:${q.status ?? "all"}`,
      (a, after) =>
        a.repository.listRecurringPlans(a.member, p.portfolio_id, {
          ...q,
          after,
        }),
    ) as never;
  });
  secureRoute(app, d, create, "simulate");
  app.openapi(
    create,
    (c) =>
      withSimulation(
        c,
        d,
        (a) =>
          a.repository.createRecurringPlan(
            a.member,
            c.req.valid("param").portfolio_id,
            c.req.valid("json"),
            c.req.header("idempotency-key")!,
          ),
        201,
      ) as never,
  );
  secureRoute(app, d, get, "read");
  app.openapi(
    get,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.getRecurringPlan(a.member, c.req.valid("param").plan_id),
      ) as never,
  );
  secureRoute(app, d, patch, "simulate");
  app.openapi(
    patch,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.patchRecurringPlan(
          a.member,
          c.req.valid("param").plan_id,
          c.req.valid("json"),
          etagVersion(c.req.header("if-match")!),
        ),
      ) as never,
  );
  for (const [route, action] of [
    [pause, "pause"],
    [resume, "resume"],
  ] as const) {
    secureRoute(app, d, route, "simulate");
    app.openapi(
      route,
      (c) =>
        withSimulation(c, d, (a) =>
          a.repository.transitionRecurringPlan(
            a.member,
            c.req.valid("param").plan_id,
            action,
            etagVersion(c.req.header("if-match")!),
          ),
        ) as never,
    );
  }
  secureRoute(app, d, cancel, "simulate");
  app.openapi(cancel, async (c) => {
    const a = simulationAccess(c, d);
    if (!a) return simulationError(c, new Error("unavailable")) as never;
    try {
      return (await a.repository.cancelRecurringPlan(
        a.member,
        c.req.valid("param").plan_id,
        etagVersion(c.req.header("if-match")!),
      ))
        ? (c.body(null, 204) as never)
        : (errorResponse(
            c,
            404,
            "not_found",
            "The requested resource was not found.",
          ) as never);
    } catch (e) {
      return simulationError(c, e) as never;
    }
  });
}
