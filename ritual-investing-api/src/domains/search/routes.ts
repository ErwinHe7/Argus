import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { SearchRepository } from "./ports.ts";
import {
  contentRecord,
  presentAssetSummary,
  presentCircleTemplateSummary,
  presentCovenSummary,
  presentGrimoireSummary,
} from "../content/service.ts";
import {
  cursorFilterIdentity,
  keysetPage,
  pagedContentQuery,
  typedKeysetPosition,
} from "../content/pagination.ts";
import { searchResponseSchema } from "../engagement/schemas.ts";
import {
  collectionDataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { pageLimitSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

type ContentRow = Record<string, unknown>;

export function registerSearchRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => SearchRepository;
  }>,
): void {
  const search = retainedRoute("get", "/v1/search", "search", "Search", {
    query: z.object({
      q: z.string().trim().min(2).max(100),
      kinds: z.string().min(1).max(80).regex(
        /^(asset|coven|grimoire|circle_template)(,(asset|coven|grimoire|circle_template))*$/,
      ),
      cursor: pagedContentQuery.shape.cursor,
      limit: pageLimitSchema.optional(),
    }).strict(),
    response: searchResponseSchema,
  });
  input.register(search, async (context) => {
    const query = z.string().trim().min(2).max(100).parse(
      context.req.query("q"),
    );
    const kinds = z.string().parse(context.req.query("kinds")).split(",");
    const canonicalKinds = [...new Set(kinds)].sort();
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const baseBinding = {
      resource: "search:published:v1",
      scope: "member",
      verifiedSubject: context.get("claims").userId,
      filterIdentity: cursorFilterIdentity({
        q: query,
        kinds: canonicalKinds.join(","),
      }),
      pageSize,
    } as const;
    const cursor = context.req.query("cursor");
    const binding = cursor === undefined
      ? baseBinding
      : { ...baseBinding, cursor };
    const after = await typedKeysetPosition(
      binding,
      z.tuple([
        z.number().int(),
        z.string().min(1).max(240),
        z.enum(["asset", "coven", "grimoire", "circle_template"]),
        z.string().uuid(),
      ]),
    );
    const rows = await input.repository(context).searchPage({
      query,
      kinds: canonicalKinds,
      limit: pageSize + 1,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => [
      Number(row.rank),
      String(row.label),
      String(row.result_kind),
      String(row.id),
    ]);
    const values = page.items.map((row) => {
      const kind = String(row.result_kind);
      const summary = contentRecord(row.summary);
      if (kind === "asset") {
        return { kind, asset: presentAssetSummary(summary) };
      }
      if (kind === "coven") {
        return { kind, coven: presentCovenSummary(summary) };
      }
      if (kind === "grimoire") {
        return { kind, grimoire: presentGrimoireSummary(summary) };
      }
      return {
        kind: "circle_template",
        circle_template: presentCircleTemplateSummary(summary),
      };
    });
    return collectionDataResponse(context, values, page.nextCursor);
  });
}
