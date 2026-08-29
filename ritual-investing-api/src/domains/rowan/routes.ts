import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { RowanRepository } from "./ports.ts";
import { rowanCounselResponseSchema } from "../engagement/schemas.ts";
import {
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type RowanRouteRepository = RowanRepository;

export function registerRowanRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => RowanRouteRepository;
  }>,
): void {
  const surfaceSchema = z.string().min(1).max(80);
  const contextKeySchema = z.string().min(1).max(160);
  const rowan = retainedRoute(
    "get",
    "/v1/rowan/{surface}/{context_key}",
    "resolveRowan",
    "Rowan",
    {
      pathParams: z.object({
        surface: surfaceSchema,
        context_key: contextKeySchema,
      }),
      response: rowanCounselResponseSchema,
    },
  );
  input.register(rowan, async (context) =>
    dataResponse(
      context,
      await input.repository(context).resolve(
        surfaceSchema.parse(context.req.param("surface")),
        contextKeySchema.parse(context.req.param("context_key")),
      ),
    ));
}
