import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { ScenarioRepository } from "./ports.ts";
import {
  futureMirrorInputSchema,
  futureMirrorSchema,
  intentionCreateSchema,
  intentionPageSchema,
  intentionPatchSchema,
  intentionSchema,
} from "./schemas.ts";
import {
  dataResponse,
  expectedVersion,
  parseBody,
  query,
  rejectBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  idempotencyKeySchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type IntentionRouteRepository = ScenarioRepository;

const idempotencyHeaders = z.object({
  "idempotency-key": idempotencyKeySchema,
});
const versionHeaders = z.object({
  "if-match": z.string().regex(/^"v[1-9]\d*"$/),
});
const intentionPath = z.object({ intention_id: uuidSchema }).strict();
const runPath = z.object({
  intention_id: uuidSchema,
  run_id: uuidSchema,
}).strict();
const scenarioLimit = z.coerce.number().int().min(1).max(50).default(25);
const intentionResponseSchema = retainedEnvelope(
  "MemberIntentionResponse",
  intentionSchema,
);
const intentionPageResponseSchema = retainedEnvelope(
  "MemberIntentionPageResponse",
  intentionPageSchema,
);
const futureMirrorResponseSchema = retainedEnvelope(
  "HypotheticalFutureMirrorResponse",
  futureMirrorSchema,
);

export function registerIntentionRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => IntentionRouteRepository;
  }>,
): void {
  const listIntentions = retainedRoute(
    "get",
    "/v1/intentions",
    "listIntentions",
    "Intentions",
    {
      query: z.object({
        status: z.enum(["active", "archived"]).optional(),
        limit: scenarioLimit.optional(),
      }).strict(),
      description: "Member-owned intentions entered directly in Argus.",
      response: intentionPageResponseSchema,
    },
  );
  input.register(listIntentions, async (context) => {
    const request = z.object({
      status: z.enum(["active", "archived"]).optional(),
      limit: scenarioLimit,
    }).parse(query(context));
    return dataResponse(
      context,
      await input.repository(context).listIntentions(
        request.status,
        request.limit,
      ),
    );
  });

  const createIntention = retainedRoute(
    "post",
    "/v1/intentions",
    "createIntention",
    "Intentions",
    {
      transaction: "runtime",
      headers: idempotencyHeaders,
      body: intentionCreateSchema,
      description:
        "Create one member-owned intention from exact reviewed input.",
      response: intentionResponseSchema,
    },
  );
  input.register(createIntention, async (context) =>
    dataResponse(
      context,
      await input.repository(context).createIntention(
        await parseBody(context, intentionCreateSchema),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));

  const getIntention = retainedRoute(
    "get",
    "/v1/intentions/{intention_id}",
    "getIntention",
    "Intentions",
    {
      pathParams: intentionPath,
      description: "Read one member-owned intention.",
      response: intentionResponseSchema,
    },
  );
  input.register(getIntention, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getIntention(
        uuidSchema.parse(context.req.param("intention_id")),
      ),
    ));

  const patchIntention = retainedRoute(
    "patch",
    "/v1/intentions/{intention_id}",
    "patchIntention",
    "Intentions",
    {
      pathParams: intentionPath,
      headers: versionHeaders,
      body: intentionPatchSchema,
      description:
        "Update exact member-entered fields with optimistic versioning.",
      response: intentionResponseSchema,
    },
  );
  input.register(patchIntention, async (context) =>
    dataResponse(
      context,
      await input.repository(context).patchIntention(
        uuidSchema.parse(context.req.param("intention_id")),
        await parseBody(context, intentionPatchSchema),
        expectedVersion(context),
      ),
    ));

  const archiveIntention = retainedRoute(
    "delete",
    "/v1/intentions/{intention_id}",
    "archiveIntention",
    "Intentions",
    {
      pathParams: intentionPath,
      headers: versionHeaders,
      description: "Archive an intention with optimistic versioning.",
      response: intentionResponseSchema,
    },
  );
  input.register(archiveIntention, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await input.repository(context).archiveIntention(
        uuidSchema.parse(context.req.param("intention_id")),
        expectedVersion(context),
      ),
    );
  });

  const createFutureMirror = retainedRoute(
    "post",
    "/v1/intentions/{intention_id}/future-mirror",
    "createFutureMirror",
    "Future Mirror",
    {
      transaction: "runtime",
      pathParams: intentionPath,
      headers: idempotencyHeaders,
      body: futureMirrorInputSchema,
      description:
        "Create a deterministic hypothetical scenario from member-entered assumptions only.",
      response: futureMirrorResponseSchema,
    },
  );
  input.register(createFutureMirror, async (context) =>
    dataResponse(
      context,
      await input.repository(context).createFutureMirror(
        uuidSchema.parse(context.req.param("intention_id")),
        await parseBody(context, futureMirrorInputSchema),
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
      ),
    ));

  const getLatestFutureMirror = retainedRoute(
    "get",
    "/v1/intentions/{intention_id}/future-mirror/latest",
    "getLatestFutureMirror",
    "Future Mirror",
    {
      pathParams: intentionPath,
      description: "Read the latest completed hypothetical scenario.",
      response: futureMirrorResponseSchema,
    },
  );
  input.register(getLatestFutureMirror, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getLatestFutureMirror(
        uuidSchema.parse(context.req.param("intention_id")),
      ),
    ));

  const getFutureMirror = retainedRoute(
    "get",
    "/v1/intentions/{intention_id}/future-mirror/{run_id}",
    "getFutureMirror",
    "Future Mirror",
    {
      pathParams: runPath,
      description: "Read one immutable historical hypothetical scenario.",
      response: futureMirrorResponseSchema,
    },
  );
  input.register(getFutureMirror, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getFutureMirror(
        uuidSchema.parse(context.req.param("intention_id")),
        uuidSchema.parse(context.req.param("run_id")),
      ),
    ));
}
