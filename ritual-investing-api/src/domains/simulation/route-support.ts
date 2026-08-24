import type { OpenAPIHono } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { memberSecurity } from "../accounts/access.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import {
  simulationAccess,
  simulationSecurity,
  type SimulationRouteDependencies,
} from "./access.ts";
import type { SimulationPage } from "./repository.ts";
import { simulationError } from "./routes.ts";

export type ProtectedPolicy = "read" | "write" | "simulate";

export function secureRoute(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: SimulationRouteDependencies,
  route: { getRoutingPath(): string; method: string },
  policy: ProtectedPolicy,
): void {
  const middleware =
    policy === "simulate"
      ? simulationSecurity(dependencies, route.method)
      : memberSecurity(dependencies, policy === "write", route.method);
  for (const handler of middleware) app.use(route.getRoutingPath(), handler);
}

export async function withSimulation<T>(
  context: any,
  dependencies: SimulationRouteDependencies,
  action: (
    access: NonNullable<ReturnType<typeof simulationAccess>>,
  ) => Promise<T>,
  status = 200,
): Promise<Response> {
  const access = simulationAccess(context, dependencies);
  if (access === undefined)
    return simulationError(context, new Error("repository_unavailable"));
  try {
    const result = await action(access);
    if (result === null)
      return errorResponse(
        context,
        404,
        "not_found",
        "The requested resource was not found.",
      );
    context.header("cache-control", "private, no-store");
    if (typeof result === "object" && result !== null && "version" in result)
      context.header(
        "etag",
        `"v${String((result as { version: number }).version)}"`,
      );
    return context.json(
      { data: result, meta: { request_id: requestIdFrom(context) } },
      status,
    );
  } catch (error) {
    return simulationError(context, error);
  }
}

export async function withSimulationPage<T>(
  context: any,
  dependencies: SimulationRouteDependencies,
  scope: string,
  load: (
    access: NonNullable<ReturnType<typeof simulationAccess>>,
    after?: string,
  ) => Promise<SimulationPage<T>>,
): Promise<Response> {
  const access = simulationAccess(context, dependencies);
  const secret = context.env.CURSOR_SIGNING_KEY;
  if (access === undefined || secret === undefined)
    return simulationError(context, new Error("repository_unavailable"));
  const query = context.req.valid("query") as { cursor?: string };
  try {
    const page = await resolveSignedPage({
      ...(query.cursor === undefined ? {} : { cursor: query.cursor }),
      secret,
      scope: `${scope}:${access.member.tenantId}`,
      load: (after) => load(access, after),
    });
    context.header("cache-control", "private, no-store");
    return context.json(
      {
        data: page.items,
        meta: {
          request_id: requestIdFrom(context),
          next_cursor: page.nextCursor,
          has_more: page.nextCursor !== null,
        },
      },
      200,
    );
  } catch (error) {
    if (error instanceof InvalidCursorError)
      return errorResponse(
        context,
        422,
        "invalid_cursor",
        "The pagination cursor is invalid or stale.",
      );
    return simulationError(context, error);
  }
}
