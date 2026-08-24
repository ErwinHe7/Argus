import { createRoute, type OpenAPIHono } from "@hono/zod-openapi";
import type { AppEnvironment } from "../../app.ts";
import { objectResponse } from "../../contracts/common.ts";
import type { SimulationRouteDependencies } from "../simulation/access.ts";
import { secureRoute, withSimulation } from "../simulation/route-support.ts";
import { simulationErrors } from "../simulation/routes.ts";
import {
  commandHeaders,
  portfolioParams,
  rebalanceCommitSchema,
  rebalancePreviewInputSchema,
  rebalancePreviewSchema,
  simulationResultSchema,
} from "../simulation/schemas.ts";
const security = [{ Auth0OAuth: ["write:self", "simulate:self"] }];
const preview = createRoute({
  method: "post",
  path: "/v1/portfolios/{portfolio_id}/rebalance-previews",
  operationId: "createRebalancePreview",
  tags: ["Rebalancing"],
  security,
  request: {
    params: portfolioParams,
    body: {
      required: true,
      content: { "application/json": { schema: rebalancePreviewInputSchema } },
    },
  },
  responses: {
    200: {
      description:
        "Frozen 15-minute all-or-nothing trade set with no ledger effect.",
      content: {
        "application/json": { schema: objectResponse(rebalancePreviewSchema) },
      },
    },
    ...simulationErrors,
  },
});
const commit = createRoute({
  method: "post",
  path: "/v1/portfolios/{portfolio_id}/rebalances",
  operationId: "commitRebalance",
  tags: ["Rebalancing"],
  security,
  request: {
    params: portfolioParams,
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: rebalanceCommitSchema } },
    },
  },
  responses: {
    200: {
      description: "Atomic Demo rebalance.",
      content: {
        "application/json": { schema: objectResponse(simulationResultSchema) },
      },
    },
    ...simulationErrors,
  },
});
export function registerRebalanceRoutes(
  app: OpenAPIHono<AppEnvironment>,
  d: SimulationRouteDependencies = {},
) {
  secureRoute(app, d, preview, "simulate");
  app.openapi(
    preview,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.previewRebalance(
          a.member,
          c.req.valid("param").portfolio_id,
          c.req.valid("json"),
        ),
      ) as never,
  );
  secureRoute(app, d, commit, "simulate");
  app.openapi(
    commit,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.commitRebalance(
          a.member,
          c.req.valid("param").portfolio_id,
          c.req.valid("json"),
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
}
