import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";
import type { AppEnvironment } from "../../app.ts";
import { collectionResponse, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import {
  simulationAccess,
  type SimulationRouteDependencies,
} from "../simulation/access.ts";
import { simulationErrors, simulationError } from "../simulation/routes.ts";
import {
  secureRoute,
  withSimulation,
  withSimulationPage,
} from "../simulation/route-support.ts";
import {
  boundedDateQuerySchema,
  commandHeaders,
  fundingFixtureSchema,
  fundingSourceSchema,
  ifMatchHeaders,
  listQuerySchema,
  portfolioCreateSchema,
  portfolioActivitySchema,
  portfolioParams,
  portfolioPatchSchema,
  portfolioPositionSchema,
  portfolioSnapshotSchema,
  portfolioViewSchema,
  sourceParams,
  etagVersion,
} from "../simulation/schemas.ts";

const readSecurity = [{ Auth0OAuth: ["read:self"] }];
const simulateSecurity = [{ Auth0OAuth: ["write:self", "simulate:self"] }];
const definitions = {
  list: createRoute({
    method: "get",
    path: "/v1/portfolios",
    operationId: "listPortfolios",
    tags: ["Portfolios"],
    security: readSecurity,
    request: { query: listQuerySchema },
    responses: {
      200: {
        description: "Current-generation Demo portfolios.",
        content: {
          "application/json": {
            schema: collectionResponse(portfolioViewSchema),
          },
        },
      },
      ...simulationErrors,
    },
  }),
  create: createRoute({
    method: "post",
    path: "/v1/portfolios",
    operationId: "createPortfolio",
    tags: ["Portfolios"],
    security: simulateSecurity,
    request: {
      headers: commandHeaders,
      body: {
        required: true,
        content: { "application/json": { schema: portfolioCreateSchema } },
      },
    },
    responses: {
      201: {
        description: "Created Demo portfolio.",
        content: {
          "application/json": { schema: objectResponse(portfolioViewSchema) },
        },
      },
      ...simulationErrors,
    },
  }),
  get: createRoute({
    method: "get",
    path: "/v1/portfolios/{portfolio_id}",
    operationId: "getPortfolio",
    tags: ["Portfolios"],
    security: readSecurity,
    request: { params: portfolioParams },
    responses: {
      200: {
        description: "Ledger-derived portfolio.",
        content: {
          "application/json": { schema: objectResponse(portfolioViewSchema) },
        },
      },
      ...simulationErrors,
    },
  }),
  patch: createRoute({
    method: "patch",
    path: "/v1/portfolios/{portfolio_id}",
    operationId: "patchPortfolio",
    tags: ["Portfolios"],
    security: simulateSecurity,
    request: {
      params: portfolioParams,
      headers: ifMatchHeaders,
      body: {
        required: true,
        content: { "application/json": { schema: portfolioPatchSchema } },
      },
    },
    responses: {
      200: {
        description: "Updated Demo portfolio.",
        content: {
          "application/json": { schema: objectResponse(portfolioViewSchema) },
        },
      },
      ...simulationErrors,
    },
  }),
  archive: createRoute({
    method: "delete",
    path: "/v1/portfolios/{portfolio_id}",
    operationId: "archivePortfolio",
    tags: ["Portfolios"],
    security: simulateSecurity,
    request: { params: portfolioParams, headers: ifMatchHeaders },
    responses: { 204: { description: "Archived." }, ...simulationErrors },
  }),
  holdings: createRoute({
    method: "get",
    path: "/v1/portfolios/{portfolio_id}/holdings",
    operationId: "listPortfolioHoldings",
    tags: ["Portfolios"],
    security: readSecurity,
    request: { params: portfolioParams, query: listQuerySchema },
    responses: {
      200: {
        description: "Ledger-derived positions.",
        content: {
          "application/json": {
            schema: collectionResponse(portfolioPositionSchema),
          },
        },
      },
      ...simulationErrors,
    },
  }),
  activity: createRoute({
    method: "get",
    path: "/v1/portfolios/{portfolio_id}/activity",
    operationId: "listPortfolioActivity",
    tags: ["Portfolios"],
    security: readSecurity,
    request: { params: portfolioParams, query: boundedDateQuerySchema },
    responses: {
      200: {
        description: "Immutable Demo activity.",
        content: {
          "application/json": {
            schema: collectionResponse(portfolioActivitySchema),
          },
        },
      },
      ...simulationErrors,
    },
  }),
  snapshots: createRoute({
    method: "get",
    path: "/v1/portfolios/{portfolio_id}/snapshots",
    operationId: "listPortfolioSnapshots",
    tags: ["Portfolios"],
    security: readSecurity,
    request: { params: portfolioParams, query: boundedDateQuerySchema },
    responses: {
      200: {
        description: "Balance snapshots.",
        content: {
          "application/json": {
            schema: collectionResponse(portfolioSnapshotSchema),
          },
        },
      },
      ...simulationErrors,
    },
  }),
  fundingList: createRoute({
    method: "get",
    path: "/v1/demo-funding-sources",
    operationId: "listDemoFundingSources",
    tags: ["Portfolios"],
    security: readSecurity,
    responses: {
      200: {
        description: "Fictional fixtures only.",
        content: {
          "application/json": {
            schema: objectResponse(z.array(fundingSourceSchema)),
          },
        },
      },
      ...simulationErrors,
    },
  }),
  fundingCreate: createRoute({
    method: "post",
    path: "/v1/demo-funding-sources",
    operationId: "createDemoFundingSource",
    tags: ["Portfolios"],
    security: simulateSecurity,
    request: {
      headers: commandHeaders,
      body: {
        required: true,
        content: { "application/json": { schema: fundingFixtureSchema } },
      },
    },
    responses: {
      201: {
        description: "Selected fictional source.",
        content: {
          "application/json": { schema: objectResponse(fundingSourceSchema) },
        },
      },
      ...simulationErrors,
    },
  }),
  fundingDelete: createRoute({
    method: "delete",
    path: "/v1/demo-funding-sources/{source_id}",
    operationId: "deleteDemoFundingSource",
    tags: ["Portfolios"],
    security: simulateSecurity,
    request: { params: sourceParams },
    responses: {
      204: { description: "Deactivated idempotently." },
      ...simulationErrors,
    },
  }),
};

export function registerPortfolioRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: SimulationRouteDependencies = {},
) {
  secureRoute(app, dependencies, definitions.list, "read");
  app.openapi(
    definitions.list,
    (c) =>
      withSimulationPage(c, dependencies, "portfolios", (a, after) =>
        a.repository.listPortfolios(
          a.member,
          c.req.valid("query").limit,
          after,
        ),
      ) as never,
  );
  secureRoute(app, dependencies, definitions.create, "simulate");
  app.openapi(
    definitions.create,
    (c) =>
      withSimulation(
        c,
        dependencies,
        (a) =>
          a.repository.createPortfolio(
            a.member,
            c.req.valid("json"),
            c.req.header("idempotency-key")!,
          ),
        201,
      ) as never,
  );
  secureRoute(app, dependencies, definitions.get, "read");
  app.openapi(
    definitions.get,
    (c) =>
      withSimulation(c, dependencies, (a) =>
        a.repository.getPortfolio(a.member, c.req.valid("param").portfolio_id),
      ) as never,
  );
  secureRoute(app, dependencies, definitions.patch, "simulate");
  app.openapi(
    definitions.patch,
    (c) =>
      withSimulation(c, dependencies, (a) =>
        a.repository.patchPortfolio(
          a.member,
          c.req.valid("param").portfolio_id,
          c.req.valid("json"),
          etagVersion(c.req.header("if-match")!),
        ),
      ) as never,
  );
  secureRoute(app, dependencies, definitions.archive, "simulate");
  app.openapi(definitions.archive, async (c) => {
    const a = simulationAccess(c, dependencies);
    if (!a) return simulationError(c, new Error("unavailable")) as never;
    try {
      const ok = await a.repository.archivePortfolio(
        a.member,
        c.req.valid("param").portfolio_id,
        etagVersion(c.req.header("if-match")!),
      );
      return ok
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
  secureRoute(app, dependencies, definitions.holdings, "read");
  app.openapi(
    definitions.holdings,
    (c) =>
      withSimulationPage(
        c,
        dependencies,
        `portfolio-holdings:${c.req.valid("param").portfolio_id}`,
        (a, after) =>
          a.repository.listHoldings(
            a.member,
            c.req.valid("param").portfolio_id,
            c.req.valid("query").limit,
            after,
          ),
      ) as never,
  );
  secureRoute(app, dependencies, definitions.activity, "read");
  app.openapi(definitions.activity, (c) => {
    const q = c.req.valid("query");
    return withSimulationPage(
      c,
      dependencies,
      `portfolio-activity:${c.req.valid("param").portfolio_id}`,
      (a, after) =>
        a.repository.listActivity(a.member, c.req.valid("param").portfolio_id, {
          ...q,
          after,
        }),
    ) as never;
  });
  secureRoute(app, dependencies, definitions.snapshots, "read");
  app.openapi(definitions.snapshots, (c) => {
    const q = c.req.valid("query");
    return withSimulationPage(
      c,
      dependencies,
      `portfolio-snapshots:${c.req.valid("param").portfolio_id}`,
      (a, after) =>
        a.repository.listSnapshots(
          a.member,
          c.req.valid("param").portfolio_id,
          { ...q, after },
        ),
    ) as never;
  });
  secureRoute(app, dependencies, definitions.fundingList, "read");
  app.openapi(
    definitions.fundingList,
    (c) =>
      withSimulation(c, dependencies, (a) =>
        a.repository.listFundingSources(a.member),
      ) as never,
  );
  secureRoute(app, dependencies, definitions.fundingCreate, "simulate");
  app.openapi(
    definitions.fundingCreate,
    (c) =>
      withSimulation(
        c,
        dependencies,
        (a) =>
          a.repository.createFundingSource(
            a.member,
            c.req.valid("json"),
            c.req.header("idempotency-key")!,
          ),
        201,
      ) as never,
  );
  secureRoute(app, dependencies, definitions.fundingDelete, "simulate");
  app.openapi(definitions.fundingDelete, async (c) => {
    const a = simulationAccess(c, dependencies);
    if (!a) return simulationError(c, new Error("unavailable")) as never;
    try {
      return (await a.repository.deleteFundingSource(
        a.member,
        c.req.valid("param").source_id,
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
