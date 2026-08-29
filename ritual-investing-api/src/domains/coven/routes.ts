import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { CovenRepository } from "./ports.ts";
import {
  covenCollectionResponseSchema,
  covenDetailResponseSchema,
  covenEvidenceResponseSchema,
} from "../content/schemas.ts";
import {
  pagedContentQuery,
  cursorFilterIdentity,
  keysetPage,
  typedKeysetPosition,
} from "../content/pagination.ts";
import {
  contentRecord,
  evidenceClaimIds,
  presentCovenDetail,
  presentCovenSummary,
  presentEvidenceDetail,
} from "../content/service.ts";
import {
  collectionDataResponse,
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { pageLimitSchema, uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type CovenRouteRepository = CovenRepository;

export function registerCovenRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => CovenRouteRepository;
    evidence: (
      context: Context<RetainedAppEnvironment>,
      claimIds: string[],
    ) => Promise<unknown[]>;
  }>,
): void {
  const listCoven = retainedRoute("get", "/v1/coven", "listCoven", "Coven", {
    query: pagedContentQuery.extend({
      category: z.enum(["founder", "owner", "chief_executive"]).optional(),
      verified_as_of: z.string().date().optional(),
    }).strict(),
    response: covenCollectionResponseSchema,
  });
  input.register(listCoven, async (context) => {
    const category = context.req.query("category");
    const verifiedAsOf = context.req.query("verified_as_of");
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const binding = {
      resource: "coven:list:v1",
      scope: "member",
      verifiedSubject: context.get("claims").userId,
      filterIdentity: cursorFilterIdentity({
        category,
        verified_as_of: verifiedAsOf,
      }),
      pageSize,
      ...(context.req.query("cursor") === undefined
        ? {}
        : { cursor: context.req.query("cursor")! }),
    } as const;
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(120), uuidSchema]),
    );
    const rows = await input.repository(context).listPage({
      limit: pageSize + 1,
      category,
      verifiedAsOf,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => {
      const entry = contentRecord(row);
      return [String(entry.slug), String(entry.id)];
    });
    return collectionDataResponse(
      context,
      page.items.map(presentCovenSummary),
      page.nextCursor,
    );
  });

  const entryPath = z.object({ entry_id: uuidSchema });
  const getCoven = retainedRoute(
    "get",
    "/v1/coven/{entry_id}",
    "getCoven",
    "Coven",
    { pathParams: entryPath, response: covenDetailResponseSchema },
  );
  input.register(getCoven, async (context) => {
    const value = await input.repository(context).get(
      uuidSchema.parse(context.req.param("entry_id")),
    );
    if (value === null) return dataResponse(context, null);
    const claimIds = evidenceClaimIds(value);
    const evidence = claimIds.length === 0
      ? []
      : await input.evidence(context, claimIds);
    return dataResponse(context, presentCovenDetail(value, evidence));
  });

  const getEvidence = retainedRoute(
    "get",
    "/v1/coven/{entry_id}/evidence",
    "getCovenEvidence",
    "Coven",
    { pathParams: entryPath, response: covenEvidenceResponseSchema },
  );
  input.register(getEvidence, async (context) => {
    const value = await input.repository(context).get(
      uuidSchema.parse(context.req.param("entry_id")),
    );
    if (value === null) return dataResponse(context, null);
    const claimIds = evidenceClaimIds(value);
    const evidence = claimIds.length === 0
      ? []
      : await input.evidence(context, claimIds);
    return dataResponse(context, evidence.map(presentEvidenceDetail));
  });
}
