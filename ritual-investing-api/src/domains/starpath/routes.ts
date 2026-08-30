import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { StarpathRepository } from "./ports.ts";
import {
  starpathAnswerCommandSchema,
  starpathSkipRecallCommandSchema,
  starpathSnapshotResponseSchema,
} from "./schemas.ts";
import {
  dataResponse,
  expectedVersion,
  parseBody,
  rejectBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { idempotencyKeySchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type StarpathRouteRepository = StarpathRepository;

const idempotencyHeaders = z.object({
  "idempotency-key": idempotencyKeySchema,
});
const commandHeaders = idempotencyHeaders.extend({
  "if-match": z.string().regex(/^"v[1-9]\d*"$/),
});

export function registerStarpathRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => StarpathRouteRepository;
  }>,
): void {
  const read = retainedRoute(
    "get",
    "/v1/starpath",
    "getStarpath",
    "Starpath",
    {
      description:
        "Read the signed-in member's server-authoritative factual Starpath.",
      response: starpathSnapshotResponseSchema,
    },
  );
  input.register(read, async (context) =>
    dataResponse(context, await input.repository(context).read()));

  const start = retainedRoute(
    "post",
    "/v1/starpath/sessions",
    "startOrResumeStarpath",
    "Starpath",
    {
      headers: idempotencyHeaders,
      description:
        "Start or resume one reviewed, non-personalized learning session.",
      response: starpathSnapshotResponseSchema,
    },
  );
  input.register(start, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await input.repository(context).startOrResume(
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    );
  });

  const answer = retainedRoute(
    "post",
    "/v1/starpath/answers",
    "answerStarpathQuestion",
    "Starpath",
    {
      headers: commandHeaders,
      body: starpathAnswerCommandSchema,
      description:
        "Submit one exact factual-comprehension answer for server scoring.",
      response: starpathSnapshotResponseSchema,
    },
  );
  input.register(answer, async (context) =>
    dataResponse(
      context,
      await input.repository(context).answer(
        await parseBody(context, starpathAnswerCommandSchema),
        expectedVersion(context),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));

  const skipRecall = retainedRoute(
    "post",
    "/v1/starpath/recall/skip",
    "skipStarpathRecall",
    "Starpath",
    {
      headers: commandHeaders,
      body: starpathSkipRecallCommandSchema,
      description:
        "Skip the non-blocking recall prompt without changing node unlocks.",
      response: starpathSnapshotResponseSchema,
    },
  );
  input.register(skipRecall, async (context) =>
    dataResponse(
      context,
      await input.repository(context).skipRecall(
        await parseBody(context, starpathSkipRecallCommandSchema),
        expectedVersion(context),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));
}
