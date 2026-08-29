import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { ModerationRepository } from "./ports.ts";
import {
  dataResponse,
  expectedVersion,
  parseBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { idempotencyKeySchema, uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type ModerationRouteRepository = ModerationRepository;

export function registerModerationRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => ModerationRouteRepository;
  }>,
): void {
  const reportBody = z.object({
    targetKind: z.string().min(1).max(80),
    targetId: uuidSchema,
    reasonCode: z.string().min(1).max(80),
    details: z.string().max(1000).optional(),
  }).strict();
  const reportContent = retainedRoute(
    "post",
    "/v1/moderation/reports",
    "reportContent",
    "Moderation",
    { body: reportBody },
  );
  input.register(reportContent, async (context) => {
    const body = await parseBody(context, reportBody);
    return dataResponse(
      context,
      await input.repository(context).report({
        targetKind: body.targetKind,
        targetId: body.targetId,
        reasonCode: body.reasonCode,
        ...(body.details === undefined ? {} : { details: body.details }),
      }),
    );
  });

  const decisionBody = z.object({ status: z.string().min(1).max(40) })
    .passthrough();
  const decideModeration = retainedRoute(
    "post",
    "/v1/admin/moderation/{case_id}/decision",
    "decideModeration",
    "Admin Moderation",
    {
      transaction: { mode: "runtime-staff", permission: "editorial:write" },
      pathParams: z.object({ case_id: uuidSchema }),
      body: decisionBody,
      headers: z.object({
        "if-match": z.string(),
        "idempotency-key": idempotencyKeySchema,
      }),
    },
  );
  input.register(decideModeration, async (context) =>
    dataResponse(
      context,
      await input.repository(context).decide(
        uuidSchema.parse(context.req.param("case_id")),
        expectedVersion(context),
        await parseBody(context, decisionBody),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));
}
