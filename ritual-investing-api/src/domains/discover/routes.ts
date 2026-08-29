import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { DiscoverRepository } from "./ports.ts";
import {
  circleTemplateCollectionResponseSchema,
  circleTemplateDetailResponseSchema,
  creatorCollectionResponseSchema,
  creatorResponseSchema,
  discoverAssetCollectionResponseSchema,
  discoverResponseSchema,
  grimoireCollectionResponseSchema,
  grimoireDetailResponseSchema,
} from "../content/schemas.ts";
import {
  cursorFilterIdentity,
  keysetPage,
  type KeysetPageRequest,
  pagedContentQuery,
  typedKeysetPosition,
} from "../content/pagination.ts";
import {
  presentAssetSummary,
  presentCircleTemplate,
  presentCircleTemplateSummary,
  presentCovenSummary,
  presentCreator,
  presentGrimoireDetail,
  presentGrimoireSummary,
} from "../content/service.ts";
import {
  collectionDataResponse,
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { pageLimitSchema, uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type DiscoverRouteRepository = DiscoverRepository;
type ContentRow = Record<string, unknown>;

function memberPageBinding(
  context: Context<RetainedAppEnvironment>,
  resource: string,
  filters: Readonly<Record<string, string | null | undefined>>,
  pageSize: number,
): KeysetPageRequest {
  const binding = {
    resource,
    scope: "member",
    verifiedSubject: context.get("claims").userId,
    filterIdentity: cursorFilterIdentity(filters),
    pageSize,
  } as const;
  const cursor = context.req.query("cursor");
  return cursor === undefined ? binding : { ...binding, cursor };
}

export function registerDiscoverRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => DiscoverRouteRepository;
    circleTemplate: (
      context: Context<RetainedAppEnvironment>,
      templateId: string,
    ) => Promise<ContentRow | null>;
    assets: (
      context: Context<RetainedAppEnvironment>,
      page: Readonly<{
        limit: number;
        after: readonly [symbol: string, id: string] | null;
      }>,
    ) => Promise<ContentRow[]>;
    coven: (
      context: Context<RetainedAppEnvironment>,
      page: Readonly<{
        limit: number;
        after: readonly [slug: string, id: string] | null;
      }>,
    ) => Promise<ContentRow[]>;
  }>,
): void {
  const getTemplate = retainedRoute(
    "get",
    "/v1/discover/circle-templates/{template_id}",
    "getCircleTemplate",
    "Discover",
    {
      pathParams: z.object({ template_id: uuidSchema }),
      response: circleTemplateDetailResponseSchema,
    },
  );
  input.register(getTemplate, async (context) => {
    const value = await input.circleTemplate(
      context,
      uuidSchema.parse(context.req.param("template_id")),
    );
    return dataResponse(
      context,
      value === null ? null : presentCircleTemplate(value),
    );
  });

  const listAssets = retainedRoute(
    "get",
    "/v1/discover/assets",
    "listDiscoverAssets",
    "Discover",
    {
      query: pagedContentQuery,
      response: discoverAssetCollectionResponseSchema,
    },
  );
  input.register(listAssets, async (context) => {
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const binding = memberPageBinding(
      context,
      "discover:assets:v1",
      {},
      pageSize,
    );
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(32), uuidSchema]),
    );
    const rows = await input.assets(context, {
      limit: pageSize + 1,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => [
      String(row.symbol),
      String(row.id),
    ]);
    return collectionDataResponse(
      context,
      page.items.map(presentAssetSummary),
      page.nextCursor,
    );
  });

  const listGrimoires = retainedRoute(
    "get",
    "/v1/discover/grimoires",
    "listGrimoires",
    "Discover",
    {
      query: pagedContentQuery.extend({
        theme: z.string().min(1).max(64).regex(/^[a-z0-9_]+$/).optional(),
      }).strict(),
      response: grimoireCollectionResponseSchema,
    },
  );
  input.register(listGrimoires, async (context) => {
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const theme = context.req.query("theme");
    const binding = memberPageBinding(
      context,
      "discover:grimoires:v1",
      { theme },
      pageSize,
    );
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(120), uuidSchema]),
    );
    const rows = await input.repository(context).listGrimoiresPage({
      limit: pageSize + 1,
      theme,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => [
      String(row.slug),
      String(row.id),
    ]);
    return collectionDataResponse(
      context,
      page.items.map(presentGrimoireSummary),
      page.nextCursor,
    );
  });

  const getGrimoire = retainedRoute(
    "get",
    "/v1/discover/grimoires/{id}",
    "getGrimoire",
    "Discover",
    {
      pathParams: z.object({ id: uuidSchema }),
      response: grimoireDetailResponseSchema,
    },
  );
  input.register(getGrimoire, async (context) => {
    const value = await input.repository(context).getGrimoire(
      uuidSchema.parse(context.req.param("id")),
    );
    return dataResponse(
      context,
      value === null ? null : presentGrimoireDetail(value),
    );
  });

  const listTemplates = retainedRoute(
    "get",
    "/v1/discover/circle-templates",
    "listCircleTemplates",
    "Discover",
    {
      query: pagedContentQuery.extend({
        creator: z.string().min(1).max(120).optional(),
      }).strict(),
      response: circleTemplateCollectionResponseSchema,
    },
  );
  input.register(listTemplates, async (context) => {
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const creator = context.req.query("creator");
    const binding = memberPageBinding(
      context,
      "discover:circle-templates:v1",
      { creator },
      pageSize,
    );
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(120), uuidSchema]),
    );
    const rows = await input.repository(context).listCircleTemplatesPage({
      limit: pageSize + 1,
      creator,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => [
      String(row.slug),
      String(row.id),
    ]);
    return collectionDataResponse(
      context,
      page.items.map(presentCircleTemplateSummary),
      page.nextCursor,
    );
  });

  const listCreators = retainedRoute(
    "get",
    "/v1/discover/creators",
    "listSeededCreators",
    "Discover",
    { query: pagedContentQuery, response: creatorCollectionResponseSchema },
  );
  input.register(listCreators, async (context) => {
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const binding = memberPageBinding(
      context,
      "discover:creators:v1",
      {},
      pageSize,
    );
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(120), uuidSchema]),
    );
    const rows = await input.repository(context).listCreatorsPage({
      limit: pageSize + 1,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => [
      String(row.display_name),
      String(row.id),
    ]);
    return collectionDataResponse(
      context,
      page.items.map(presentCreator),
      page.nextCursor,
    );
  });

  const getCreator = retainedRoute(
    "get",
    "/v1/discover/creators/{id}",
    "getSeededCreator",
    "Discover",
    {
      pathParams: z.object({ id: uuidSchema }),
      response: creatorResponseSchema,
    },
  );
  input.register(getCreator, async (context) => {
    const value = await input.repository(context).getCreator(
      uuidSchema.parse(context.req.param("id")),
    );
    return dataResponse(context, value === null ? null : presentCreator(value));
  });

  const discoverQuery = pagedContentQuery.extend({
    section: z.enum(["asset", "coven", "grimoire", "circle_template"])
      .optional(),
  }).strict();
  const listDiscover = retainedRoute(
    "get",
    "/v1/discover",
    "listDiscover",
    "Discover",
    { query: discoverQuery, response: discoverResponseSchema },
  );
  input.register(listDiscover, async (context) => {
    const requestedLimit = pageLimitSchema.parse(context.req.query("limit"));
    const section = z.enum([
      "asset",
      "coven",
      "grimoire",
      "circle_template",
    ]).optional().parse(context.req.query("section"));
    const binding = memberPageBinding(
      context,
      "discover:mixed:v1",
      { section },
      requestedLimit,
    );
    const positionKind = section === undefined
      ? z.enum(["asset", "coven", "grimoire", "circle_template"])
      : z.literal(section);
    const after = await typedKeysetPosition(
      binding,
      z.tuple([positionKind, z.string().min(1).max(120), uuidSchema]),
    );
    const repository = input.repository(context);
    const kinds = [
      "asset",
      "coven",
      "grimoire",
      "circle_template",
    ] as const;
    const startIndex = after === null ? 0 : kinds.indexOf(after[0]);
    const shouldLoad = (kind: typeof kinds[number]) =>
      (section === undefined || section === kind) &&
      kinds.indexOf(kind) >= startIndex;
    const afterFor = (kind: typeof kinds[number]) =>
      after !== null && after[0] === kind
        ? [after[1], after[2]] as const
        : null;
    const fetchLimit = requestedLimit + 1;
    const [assets, coven, grimoires, templates] = await Promise.all([
      shouldLoad("asset")
        ? input.assets(context, {
          limit: fetchLimit,
          after: afterFor("asset"),
        })
        : [],
      shouldLoad("coven")
        ? input.coven(context, {
          limit: fetchLimit,
          after: afterFor("coven"),
        })
        : [],
      shouldLoad("grimoire")
        ? repository.listGrimoiresPage({
          limit: fetchLimit,
          theme: undefined,
          after: afterFor("grimoire"),
        })
        : [],
      shouldLoad("circle_template")
        ? repository.listCircleTemplatesPage({
          limit: fetchLimit,
          creator: undefined,
          after: afterFor("circle_template"),
        })
        : [],
    ]);
    const rows = [
      ...assets.map((row) => ({ kind: "asset" as const, row })),
      ...coven.map((row) => ({ kind: "coven" as const, row })),
      ...grimoires.map((row) => ({ kind: "grimoire" as const, row })),
      ...templates.map((row) => ({
        kind: "circle_template" as const,
        row,
      })),
    ].slice(0, fetchLimit);
    const page = await keysetPage(binding, rows, (entry) => [
      entry.kind,
      String(entry.kind === "asset" ? entry.row.symbol : entry.row.slug),
      String(entry.row.id),
    ]);
    const values = page.items.map(({ kind, row }) => {
      if (kind === "asset") return { kind, asset: presentAssetSummary(row) };
      if (kind === "coven") return { kind, coven: presentCovenSummary(row) };
      if (kind === "grimoire") {
        return { kind, grimoire: presentGrimoireSummary(row) };
      }
      return {
        kind,
        circle_template: presentCircleTemplateSummary(row),
      };
    });
    return collectionDataResponse(context, values, page.nextCursor);
  });
}
