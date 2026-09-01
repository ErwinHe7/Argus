import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import {
  dataResponse,
  parseBody,
  rejectBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { idempotencyKeySchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";
import {
  birthdayOnboardingFinalizeBodySchema,
  onboardingFinalizeBodySchema,
  sessionBootstrapResponseSchema,
} from "./schemas.ts";
import type { SessionService } from "./service.ts";

export function registerSessionRoutes(input: Readonly<{
  register: RetainedRouteRegistrar;
  service: (context: Context<RetainedAppEnvironment>) => SessionService;
}>): void {
  const bootstrap = retainedRoute(
    "post",
    "/v1/session/bootstrap",
    "bootstrapSession",
    "Session",
    { response: sessionBootstrapResponseSchema },
  );
  input.register(bootstrap, async (context) => {
    await rejectBody(context);
    return dataResponse(context, await input.service(context).bootstrap());
  });

  const finalizeBirthdayOnboarding = retainedRoute(
    "post",
    "/v1/session/onboarding/birthday/finalize",
    "finalizeBirthdayOnboarding",
    "Session",
    {
      transaction: "runtime",
      body: birthdayOnboardingFinalizeBodySchema,
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      response: sessionBootstrapResponseSchema,
    },
  );
  input.register(finalizeBirthdayOnboarding, async (context) =>
    dataResponse(
      context,
      await input.service(context).finalizeBirthdayOnboarding(
        await parseBody(context, birthdayOnboardingFinalizeBodySchema),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));

  const finalizeOnboarding = retainedRoute(
    "post",
    "/v1/session/onboarding/finalize",
    "finalizeOnboarding",
    "Session",
    {
      transaction: "runtime",
      body: onboardingFinalizeBodySchema,
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      response: sessionBootstrapResponseSchema,
    },
  );
  input.register(finalizeOnboarding, async (context) =>
    dataResponse(
      context,
      await input.service(context).finalizeOnboarding(
        await parseBody(context, onboardingFinalizeBodySchema),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));
}
