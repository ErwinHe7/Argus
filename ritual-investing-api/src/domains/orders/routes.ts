import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, objectResponse } from "../../contracts/common.ts";
import type { SimulationRouteDependencies } from "../simulation/access.ts";
import {
  secureRoute,
  withSimulation,
  withSimulationPage,
} from "../simulation/route-support.ts";
import { simulationErrors } from "../simulation/routes.ts";
import {
  commandHeaders,
  orderCommitSchema,
  orderListQuerySchema,
  orderParams,
  orderPreviewInputSchema,
  orderPreviewSchema,
  orderViewSchema,
  portfolioParams,
  simulationResultSchema,
} from "../simulation/schemas.ts";

const read = [{ Auth0OAuth: ["read:self"] }];
const simulate = [{ Auth0OAuth: ["write:self", "simulate:self"] }];
const preview = createRoute({
  method: "post",
  path: "/v1/portfolios/{portfolio_id}/order-previews",
  operationId: "createOrderPreview",
  tags: ["Orders"],
  security: simulate,
  request: {
    params: portfolioParams,
    body: {
      required: true,
      content: { "application/json": { schema: orderPreviewInputSchema } },
    },
  },
  responses: {
    200: {
      description: "Frozen, expiring Demo quote with no ledger effect.",
      content: {
        "application/json": { schema: objectResponse(orderPreviewSchema) },
      },
    },
    ...simulationErrors,
  },
});
const commit = createRoute({
  method: "post",
  path: "/v1/portfolios/{portfolio_id}/orders",
  operationId: "commitOrder",
  tags: ["Orders"],
  security: simulate,
  request: {
    params: portfolioParams,
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: orderCommitSchema } },
    },
  },
  responses: {
    200: {
      description: "Atomic one-fill Demo order.",
      content: {
        "application/json": { schema: objectResponse(simulationResultSchema) },
      },
    },
    ...simulationErrors,
  },
});
const list = createRoute({
  method: "get",
  path: "/v1/orders",
  operationId: "listOrders",
  tags: ["Orders"],
  security: read,
  request: { query: orderListQuerySchema },
  responses: {
    200: {
      description: "Current-generation tenant orders.",
      content: {
        "application/json": { schema: collectionResponse(orderViewSchema) },
      },
    },
    ...simulationErrors,
  },
});
const get = createRoute({
  method: "get",
  path: "/v1/orders/{order_id}",
  operationId: "getOrder",
  tags: ["Orders"],
  security: read,
  request: { params: orderParams },
  responses: {
    200: {
      description: "Immutable order and fill.",
      content: {
        "application/json": { schema: objectResponse(orderViewSchema) },
      },
    },
    ...simulationErrors,
  },
});

export function registerOrderRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: SimulationRouteDependencies = {},
) {
  secureRoute(app, dependencies, preview, "simulate");
  app.openapi(
    preview,
    (c) =>
      withSimulation(c, dependencies, (a) =>
        a.repository.previewOrder(
          a.member,
          c.req.valid("param").portfolio_id,
          c.req.valid("json"),
        ),
      ) as never,
  );
  secureRoute(app, dependencies, commit, "simulate");
  app.openapi(
    commit,
    (c) =>
      withSimulation(c, dependencies, (a) =>
        a.repository.commitOrder(
          a.member,
          c.req.valid("param").portfolio_id,
          c.req.valid("json"),
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
  secureRoute(app, dependencies, list, "read");
  app.openapi(list, (c) => {
    const q = c.req.valid("query");
    return withSimulationPage(
      c,
      dependencies,
      `orders:${q.portfolio_id ?? "all"}:${q.status ?? "all"}`,
      (a, after) => a.repository.listOrders(a.member, { ...q, after }),
    ) as never;
  });
  secureRoute(app, dependencies, get, "read");
  app.openapi(
    get,
    (c) =>
      withSimulation(c, dependencies, (a) =>
        a.repository.getOrder(a.member, c.req.valid("param").order_id),
      ) as never,
  );
}
