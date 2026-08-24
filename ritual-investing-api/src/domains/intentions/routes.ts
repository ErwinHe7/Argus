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
  futureMirrorInputSchema,
  futureMirrorSchema,
  ifMatchHeaders,
  intentionCreateSchema,
  intentionListQuerySchema,
  intentionParams,
  intentionPatchSchema,
  intentionSchema,
  runParams,
} from "../simulation/schemas.ts";
const read = [{ Auth0OAuth: ["read:self"] }],
  write = [{ Auth0OAuth: ["write:self"] }],
  simulate = [{ Auth0OAuth: ["write:self", "simulate:self"] }];
const list = createRoute({
  method: "get",
  path: "/v1/intentions",
  operationId: "listIntentions",
  tags: ["Intentions"],
  security: read,
  request: { query: intentionListQuerySchema },
  responses: {
    200: {
      description: "Server-authoritative intentions.",
      content: {
        "application/json": { schema: collectionResponse(intentionSchema) },
      },
    },
    ...simulationErrors,
  },
});
const create = createRoute({
  method: "post",
  path: "/v1/intentions",
  operationId: "createIntention",
  tags: ["Intentions"],
  security: write,
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: intentionCreateSchema } },
    },
  },
  responses: {
    201: {
      description: "Created Demo intention.",
      content: {
        "application/json": { schema: objectResponse(intentionSchema) },
      },
    },
    ...simulationErrors,
  },
});
const get = createRoute({
  method: "get",
  path: "/v1/intentions/{intention_id}",
  operationId: "getIntention",
  tags: ["Intentions"],
  security: read,
  request: { params: intentionParams },
  responses: {
    200: {
      description: "Intention with ledger-derived progress.",
      content: {
        "application/json": { schema: objectResponse(intentionSchema) },
      },
    },
    ...simulationErrors,
  },
});
const patch = createRoute({
  method: "patch",
  path: "/v1/intentions/{intention_id}",
  operationId: "patchIntention",
  tags: ["Intentions"],
  security: write,
  request: {
    params: intentionParams,
    headers: ifMatchHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: intentionPatchSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated intention.",
      content: {
        "application/json": { schema: objectResponse(intentionSchema) },
      },
    },
    ...simulationErrors,
  },
});
const archive = createRoute({
  method: "delete",
  path: "/v1/intentions/{intention_id}",
  operationId: "archiveIntention",
  tags: ["Intentions"],
  security: write,
  request: { params: intentionParams, headers: ifMatchHeaders },
  responses: {
    204: { description: "Archived; historical projections retained." },
    ...simulationErrors,
  },
});
const build = createRoute({
  method: "post",
  path: "/v1/intentions/{intention_id}/future-mirror",
  operationId: "createFutureMirror",
  tags: ["Future Mirror"],
  security: simulate,
  request: {
    params: intentionParams,
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: futureMirrorInputSchema } },
    },
  },
  responses: {
    200: {
      description: "Deterministic projection with uncertainty bands.",
      content: {
        "application/json": { schema: objectResponse(futureMirrorSchema) },
      },
    },
    ...simulationErrors,
  },
});
const latest = createRoute({
  method: "get",
  path: "/v1/intentions/{intention_id}/future-mirror/latest",
  operationId: "getLatestFutureMirror",
  tags: ["Future Mirror"],
  security: read,
  request: { params: intentionParams },
  responses: {
    200: {
      description: "Monotonic current projection.",
      content: {
        "application/json": { schema: objectResponse(futureMirrorSchema) },
      },
    },
    ...simulationErrors,
  },
});
const historical = createRoute({
  method: "get",
  path: "/v1/intentions/{intention_id}/future-mirror/{run_id}",
  operationId: "getFutureMirror",
  tags: ["Future Mirror"],
  security: read,
  request: { params: runParams },
  responses: {
    200: {
      description: "Historical projection scoped to its intention.",
      content: {
        "application/json": { schema: objectResponse(futureMirrorSchema) },
      },
    },
    ...simulationErrors,
  },
});
export function registerIntentionRoutes(
  app: OpenAPIHono<AppEnvironment>,
  d: SimulationRouteDependencies = {},
) {
  secureRoute(app, d, list, "read");
  app.openapi(list, (c) => {
    const q = c.req.valid("query");
    return withSimulationPage(
      c,
      d,
      `intentions:${q.status ?? "all"}`,
      (a, after) => a.repository.listIntentions(a.member, { ...q, after }),
    ) as never;
  });
  secureRoute(app, d, create, "write");
  app.openapi(
    create,
    (c) =>
      withSimulation(
        c,
        d,
        (a) =>
          a.repository.createIntention(
            a.member,
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
        a.repository.getIntention(a.member, c.req.valid("param").intention_id),
      ) as never,
  );
  secureRoute(app, d, patch, "write");
  app.openapi(
    patch,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.patchIntention(
          a.member,
          c.req.valid("param").intention_id,
          c.req.valid("json"),
          etagVersion(c.req.header("if-match")!),
        ),
      ) as never,
  );
  secureRoute(app, d, archive, "write");
  app.openapi(archive, async (c) => {
    const a = simulationAccess(c, d);
    if (!a) return simulationError(c, new Error("unavailable")) as never;
    try {
      return (await a.repository.archiveIntention(
        a.member,
        c.req.valid("param").intention_id,
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
  secureRoute(app, d, build, "simulate");
  app.openapi(
    build,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.buildFutureMirror(
          a.member,
          c.req.valid("param").intention_id,
          c.req.valid("json"),
          c.req.header("idempotency-key")!,
        ),
      ) as never,
  );
  secureRoute(app, d, latest, "read");
  app.openapi(
    latest,
    (c) =>
      withSimulation(c, d, (a) =>
        a.repository.getLatestFutureMirror(
          a.member,
          c.req.valid("param").intention_id,
        ),
      ) as never,
  );
  secureRoute(app, d, historical, "read");
  app.openapi(historical, (c) => {
    const p = c.req.valid("param");
    return withSimulation(c, d, (a) =>
      a.repository.getFutureMirror(a.member, p.intention_id, p.run_id),
    ) as never;
  });
}
