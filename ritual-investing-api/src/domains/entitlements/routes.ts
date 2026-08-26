import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";
import type { AppEnvironment } from "../../app.ts";
import { objectResponse } from "../../contracts/common.ts";
import type { SimulationRouteDependencies } from "../simulation/access.ts";
import { secureRoute, withSimulation } from "../simulation/route-support.ts";
import { simulationErrors } from "../simulation/routes.ts";
import {
  checkoutCreateSchema,
  checkoutSessionSchema,
  commandHeaders,
  demoPlanSchema,
  demoResetResultSchema,
  demoResetSchema,
  entitlementSchema,
  etagVersion,
  sessionParams,
  versionedCommandHeaders,
} from "../simulation/schemas.ts";
const read = [{ Auth0OAuth: ["read:self"] }],
  simulate = [{ Auth0OAuth: ["write:self", "simulate:self"] }];
const emptyCommandBody = {
  required: false,
  content: { "application/json": { schema: z.object({}).strict() } },
} as const;
const plans = createRoute({
  method: "get",
  path: "/v1/demo-plans",
  operationId: "listDemoPlans",
  tags: ["Demo Entitlements"],
  security: read,
  responses: {
    200: {
      description: "Copy-only Demo plans; no processor identifiers.",
      content: {
        "application/json": { schema: objectResponse(z.array(demoPlanSchema)) },
      },
    },
    ...simulationErrors,
  },
});
const entitlement = createRoute({
  method: "get",
  path: "/v1/me/entitlements",
  operationId: "getDemoEntitlement",
  tags: ["Demo Entitlements"],
  security: read,
  responses: {
    200: {
      description: "Current Demo entitlement.",
      content: {
        "application/json": { schema: objectResponse(entitlementSchema) },
      },
    },
    ...simulationErrors,
  },
});
const checkout = createRoute({
  method: "post",
  path: "/v1/demo-checkout-sessions",
  operationId: "createDemoCheckout",
  tags: ["Demo Entitlements"],
  security: simulate,
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: checkoutCreateSchema } },
    },
  },
  responses: {
    201: {
      description: "Fixture-only Demo checkout.",
      content: {
        "application/json": { schema: objectResponse(checkoutSessionSchema) },
      },
    },
    ...simulationErrors,
  },
});
const checkoutGet = createRoute({
  method: "get",
  path: "/v1/demo-checkout-sessions/{session_id}",
  operationId: "getDemoCheckout",
  tags: ["Demo Entitlements"],
  security: read,
  request: { params: sessionParams },
  responses: {
    200: {
      description: "Demo checkout state.",
      content: {
        "application/json": { schema: objectResponse(checkoutSessionSchema) },
      },
    },
    ...simulationErrors,
  },
});
const confirm = createRoute({
  method: "post",
  path: "/v1/demo-checkout-sessions/{session_id}/confirm",
  operationId: "confirmDemoCheckout",
  tags: ["Demo Entitlements"],
  security: simulate,
  request: {
    params: sessionParams,
    headers: versionedCommandHeaders,
    body: emptyCommandBody,
  },
  responses: {
    200: {
      description: "Granted Demo entitlement; no charge.",
      content: {
        "application/json": { schema: objectResponse(entitlementSchema) },
      },
    },
    ...simulationErrors,
  },
});
const restore = createRoute({
  method: "post",
  path: "/v1/me/entitlements/restore",
  operationId: "restoreDemoEntitlement",
  tags: ["Demo Entitlements"],
  security: simulate,
  request: { headers: commandHeaders, body: emptyCommandBody },
  responses: {
    200: {
      description: "Restored from server Demo history without external store.",
      content: {
        "application/json": { schema: objectResponse(entitlementSchema) },
      },
    },
    ...simulationErrors,
  },
});
const downgrade = createRoute({
  method: "post",
  path: "/v1/me/entitlements/downgrade",
  operationId: "downgradeDemoEntitlement",
  tags: ["Demo Entitlements"],
  security: simulate,
  request: { headers: versionedCommandHeaders, body: emptyCommandBody },
  responses: {
    200: {
      description: "Downgraded to free Demo access; feature state retained.",
      content: {
        "application/json": { schema: objectResponse(entitlementSchema) },
      },
    },
    ...simulationErrors,
  },
});
const reset = createRoute({
  method: "post",
  path: "/v1/me/demo-reset",
  operationId: "resetDemoState",
  tags: ["Simulation"],
  security: simulate,
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: demoResetSchema } },
    },
  },
  responses: {
    200: {
      description: "Atomically advanced generation and reseeded Demo state.",
      content: {
        "application/json": { schema: objectResponse(demoResetResultSchema) },
      },
    },
    ...simulationErrors,
  },
});
export function registerEntitlementRoutes(
  app: OpenAPIHono<AppEnvironment>,
  d: SimulationRouteDependencies = {},
) {
  secureRoute(app, d, plans, "read");
  app.openapi(
    plans,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.listDemoPlans(a.member),
      ) as never,
  );
  secureRoute(app, d, entitlement, "read");
  app.openapi(
    entitlement,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.getEntitlement(a.member),
      ) as never,
  );
  secureRoute(app, d, checkout, "simulate");
  app.openapi(
    checkout,
    (c) =>
      withSimulation(
        c,
        d,
        (a) =>
          a.repository.createCheckout(
            a.member,
            c.req.valid("json").plan_code,
            c.req.header("idempotency-key")!,
          ),
        201,
      ) as never,
  );
  secureRoute(app, d, checkoutGet, "read");
  app.openapi(
    checkoutGet,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.getCheckout(a.member, c.req.valid("param").session_id),
      ) as never,
  );
  secureRoute(app, d, confirm, "simulate");
  app.openapi(
    confirm,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.confirmCheckout(
          a.member,
          c.req.valid("param").session_id,
          etagVersion(c.req.header("if-match")!),
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
  secureRoute(app, d, restore, "simulate");
  app.openapi(
    restore,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.restoreEntitlement(
          a.member,
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
  secureRoute(app, d, downgrade, "simulate");
  app.openapi(
    downgrade,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.downgradeEntitlement(
          a.member,
          etagVersion(c.req.header("if-match")!),
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
  secureRoute(app, d, reset, "simulate");
  app.openapi(
    reset,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.resetDemo(
          a.member,
          c.req.valid("json").seed_version,
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
}
