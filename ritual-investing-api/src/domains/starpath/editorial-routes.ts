import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import {
  dataResponse,
  parseBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";
import type { StarpathEditorialRepository } from "./editorial-repository.ts";
import {
  starpathPublishManifestBodySchema,
  starpathReviewBodySchema,
  starpathSubmitRevisionBodySchema,
} from "./editorial-schemas.ts";

export type StarpathEditorialRouteRepository = StarpathEditorialRepository;

export function registerStarpathEditorialRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => StarpathEditorialRouteRepository;
  }>,
): void {
  const getRevision = retainedRoute(
    "get",
    "/v1/admin/starpath/revisions/{revision_id}",
    "getAdminStarpathRevision",
    "Admin Starpath",
    {
      transaction: { mode: "staff", permission: "editorial:read" },
      pathParams: z.object({ revision_id: uuidSchema }),
    },
  );
  input.register(getRevision, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getRevisionAuthority(
        uuidSchema.parse(context.req.param("revision_id")),
      ),
    ));

  const submitRevision = retainedRoute(
    "post",
    "/v1/admin/starpath/revisions/{revision_id}/submit",
    "submitAdminStarpathRevision",
    "Admin Starpath",
    {
      transaction: { mode: "staff", permission: "editorial:write" },
      pathParams: z.object({ revision_id: uuidSchema }),
      body: starpathSubmitRevisionBodySchema,
    },
  );
  input.register(submitRevision, async (context) => {
    const body = await parseBody(context, starpathSubmitRevisionBodySchema);
    return dataResponse(
      context,
      await input.repository(context).submitRevision(
        uuidSchema.parse(context.req.param("revision_id")),
        body.policy_version,
      ),
    );
  });

  const decideReview = retainedRoute(
    "post",
    "/v1/admin/starpath/revisions/{revision_id}/reviews",
    "reviewAdminStarpathRevision",
    "Admin Starpath",
    {
      // Discipline-specific authorization is evaluated by the database from
      // the request body and trusted current staff principal.
      transaction: { mode: "staff" },
      pathParams: z.object({ revision_id: uuidSchema }),
      body: starpathReviewBodySchema,
    },
  );
  input.register(decideReview, async (context) => {
    const body = await parseBody(context, starpathReviewBodySchema);
    return dataResponse(
      context,
      await input.repository(context).decideReview(
        uuidSchema.parse(context.req.param("revision_id")),
        body.discipline,
        body.decision,
        body.reason,
      ),
    );
  });

  const publishManifest = retainedRoute(
    "post",
    "/v1/admin/starpath/manifests/{manifest_id}/publish",
    "publishAdminStarpathManifest",
    "Admin Starpath",
    {
      transaction: { mode: "staff", permission: "editorial:publish" },
      pathParams: z.object({ manifest_id: uuidSchema }),
      body: starpathPublishManifestBodySchema,
    },
  );
  input.register(publishManifest, async (context) => {
    const body = await parseBody(context, starpathPublishManifestBodySchema);
    return dataResponse(
      context,
      await input.repository(context).publishManifest(
        uuidSchema.parse(context.req.param("manifest_id")),
        body.reason,
      ),
    );
  });
}
