import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { RitualRepository } from "./ports.ts";
import {
  ritualAssignmentResponseSchema,
  ritualEvidenceResponseSchema,
  ritualHistoryResponseSchema,
} from "../engagement/schemas.ts";
import {
  dataResponse,
  expectedVersion,
  parseBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { pageLimitSchema, uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type RitualRouteRepository = RitualRepository;

export function registerRitualRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => RitualRouteRepository;
  }>,
): void {
  const ritualPath = z.object({ assignment_id: uuidSchema });
  const getDaily = retainedRoute(
    "get",
    "/v1/rituals/daily",
    "getDailyRitual",
    "Rituals",
    {
      query: z.object({ mode: z.enum(["tarot", "astrology"]).optional() }),
      response: ritualAssignmentResponseSchema,
    },
  );
  input.register(getDaily, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getDaily(
        context.req.query("mode") as "tarot" | "astrology" | undefined,
      ),
    ));

  const history = retainedRoute(
    "get",
    "/v1/rituals",
    "listRitualHistory",
    "Rituals",
    {
      query: z.object({ limit: pageLimitSchema.optional() }),
      response: ritualHistoryResponseSchema,
    },
  );
  input.register(history, async (context) =>
    dataResponse(
      context,
      await input.repository(context).history(
        pageLimitSchema.parse(context.req.query("limit")),
      ),
    ));

  const getRitual = retainedRoute(
    "get",
    "/v1/rituals/{assignment_id}",
    "getRitual",
    "Rituals",
    { pathParams: ritualPath, response: ritualAssignmentResponseSchema },
  );
  input.register(getRitual, async (context) =>
    dataResponse(
      context,
      await input.repository(context).get(
        uuidSchema.parse(context.req.param("assignment_id")),
      ),
    ));

  const evidence = retainedRoute(
    "get",
    "/v1/rituals/{assignment_id}/evidence",
    "getRitualEvidence",
    "Rituals",
    { pathParams: ritualPath, response: ritualEvidenceResponseSchema },
  );
  input.register(evidence, async (context) =>
    dataResponse(
      context,
      await input.repository(context).evidence(
        uuidSchema.parse(context.req.param("assignment_id")),
      ),
    ));

  const transitionBody = z.object({
    from: z.enum(["assigned", "revealed"]),
    to: z.enum(["revealed", "completed"]),
  }).strict();
  const transition = retainedRoute(
    "post",
    "/v1/rituals/{assignment_id}/transition",
    "transitionRitual",
    "Rituals",
    {
      pathParams: ritualPath,
      body: transitionBody,
      headers: z.object({ "if-match": z.string() }),
      response: ritualAssignmentResponseSchema,
    },
  );
  input.register(transition, async (context) => {
    const body = await parseBody(context, transitionBody);
    return dataResponse(
      context,
      await input.repository(context).transition(
        uuidSchema.parse(context.req.param("assignment_id")),
        body.from,
        body.to,
        expectedVersion(context),
      ),
    );
  });
}
