import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import { RepositoryNotFoundError } from "../../db/repository-support.ts";
import type { CircleRepository } from "./ports.ts";
import {
  circleCollectionResponseSchema,
  circleDetailResponseSchema,
} from "../content/schemas.ts";
import {
  cursorFilterIdentity,
  keysetPage,
  pagedContentQuery,
  typedKeysetPosition,
} from "../content/pagination.ts";
import { contentRecord, timestampString } from "../content/service.ts";
import {
  collectionDataResponse,
  dataResponse,
  expectedVersion,
  HttpBoundaryError,
  parseBody,
  rejectBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  idempotencyKeySchema,
  pageLimitSchema,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type CircleRouteRepository = CircleRepository;

export function registerCircleRoutes(
  dependencies: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => CircleRouteRepository;
  }>,
): void {
  const listCircles = retainedRoute(
    "get",
    "/v1/circles",
    "listCircles",
    "Circles",
    {
      query: z.object({
        archived: z.enum(["include", "exclude"]).optional(),
        cursor: pagedContentQuery.shape.cursor,
        limit: pageLimitSchema.optional(),
      }),
      response: circleCollectionResponseSchema,
    },
  );
  dependencies.register(listCircles, async (context) => {
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const includeArchived = context.req.query("archived") === "include";
    const baseBinding = {
      resource: "circles:list:v1",
      scope: "member",
      verifiedSubject: context.get("claims").userId,
      filterIdentity: cursorFilterIdentity({
        archived: includeArchived ? "include" : "exclude",
      }),
      pageSize,
    } as const;
    const rawCursor = context.req.query("cursor");
    const binding = rawCursor === undefined
      ? baseBinding
      : { ...baseBinding, cursor: rawCursor };
    const after = await typedKeysetPosition(
      binding,
      z.tuple([
        z.boolean(),
        z.string().min(1).max(64).nullable(),
        uuidSchema,
      ]),
    );
    const rows = await dependencies.repository(context).listPage({
      limit: pageSize + 1,
      includeArchived,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => {
      const circle = contentRecord(row);
      return [
        circle.archived_sort === true,
        timestampString(circle.archived_cursor_at),
        String(circle.id),
      ];
    });
    return collectionDataResponse(
      context,
      page.items.map((row) => {
        const {
          archived_sort: _archivedSort,
          archived_cursor_at: _archivedCursorAt,
          ...circle
        } = contentRecord(row);
        return {
          ...circle,
          archived_at: timestampString(circle.archived_at),
        };
      }),
      page.nextCursor,
    );
  });
  const circleAssetBody = z.object({
    assetId: uuidSchema,
    ordinal: z.number().int().min(1).max(50),
    weightBps: z.number().int().min(0).max(10000).nullable().optional(),
    note: z.string().max(2000).nullable().optional(),
  }).strict().openapi("CircleAssetInput");
  const circleBody = z
    .object({
      title: z.string().min(1).max(120),
      description: z.string().max(1000),
      assets: z.array(circleAssetBody).max(50).optional(),
    })
    .strict().openapi("CreateCircleRequest");
  const createCircle = retainedRoute(
    "post",
    "/v1/circles",
    "createCircle",
    "Circles",
    {
      body: circleBody,
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(createCircle, async (context) => {
    const input = await parseBody(context, circleBody);
    return dataResponse(
      context,
      await dependencies.repository(context).create({
        title: input.title,
        description: input.description,
        ...(input.assets === undefined ? {} : { assets: input.assets }),
      }),
    );
  });
  const circlePath = z.object({ circle_id: uuidSchema });
  const getCircle = retainedRoute(
    "get",
    "/v1/circles/{circle_id}",
    "getCircle",
    "Circles",
    { pathParams: circlePath, response: circleDetailResponseSchema },
  );
  dependencies.register(getCircle, async (context) =>
    dataResponse(
      context,
      await dependencies.repository(context).get(
        uuidSchema.parse(context.req.param("circle_id")),
      ),
    ));
  const updateCircle = retainedRoute(
    "patch",
    "/v1/circles/{circle_id}",
    "updateCircle",
    "Circles",
    {
      pathParams: circlePath,
      body: circleBody.omit({ assets: true }).partial(),
      headers: z.object({ "if-match": z.string() }),
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(updateCircle, async (context) => {
    const patch = await parseBody(
      context,
      circleBody.omit({ assets: true }).partial(),
    );
    return dataResponse(
      context,
      await dependencies.repository(context).update(
        uuidSchema.parse(context.req.param("circle_id")),
        {
          ...(patch.title === undefined ? {} : { title: patch.title }),
          ...(patch.description === undefined
            ? {}
            : { description: patch.description }),
        },
        expectedVersion(context),
      ),
    );
  });
  const replaceCircleAssetsBody = z.object({
    assets: z.array(circleAssetBody).max(50),
  }).strict().openapi("ReplaceCircleAssetsRequest");
  const replaceCircleAssets = retainedRoute(
    "put",
    "/v1/circles/{circle_id}/assets",
    "replaceCircleAssets",
    "Circles",
    {
      pathParams: circlePath,
      headers: z.object({ "if-match": z.string() }),
      body: replaceCircleAssetsBody,
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(replaceCircleAssets, async (context) => {
    const input = await parseBody(context, replaceCircleAssetsBody);
    return dataResponse(
      context,
      await dependencies.repository(context).replaceAssets(
        uuidSchema.parse(context.req.param("circle_id")),
        input.assets,
        expectedVersion(context),
      ),
    );
  });
  const circleAssetPath = z.object({
    circle_id: uuidSchema,
    asset_id: uuidSchema,
  });
  const putCircleAssetBody = circleAssetBody.omit({ assetId: true })
    .openapi("PutCircleAssetRequest");
  const putCircleAsset = retainedRoute(
    "put",
    "/v1/circles/{circle_id}/assets/{asset_id}",
    "putCircleAsset",
    "Circles",
    {
      pathParams: circleAssetPath,
      headers: z.object({ "if-match": z.string() }),
      body: putCircleAssetBody,
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(putCircleAsset, async (context) =>
    dataResponse(
      context,
      await dependencies.repository(context).putAsset(
        uuidSchema.parse(context.req.param("circle_id")),
        uuidSchema.parse(context.req.param("asset_id")),
        await parseBody(context, putCircleAssetBody),
        expectedVersion(context),
      ),
    ));
  const deleteCircleAsset = retainedRoute(
    "delete",
    "/v1/circles/{circle_id}/assets/{asset_id}",
    "deleteCircleAsset",
    "Circles",
    {
      pathParams: circleAssetPath,
      headers: z.object({ "if-match": z.string() }),
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(deleteCircleAsset, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await dependencies.repository(context).deleteAsset(
        uuidSchema.parse(context.req.param("circle_id")),
        uuidSchema.parse(context.req.param("asset_id")),
        expectedVersion(context),
      ),
    );
  });
  const archiveCircle = retainedRoute(
    "delete",
    "/v1/circles/{circle_id}",
    "archiveCircle",
    "Circles",
    {
      pathParams: circlePath,
      headers: z.object({ "if-match": z.string() }),
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(archiveCircle, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await dependencies.repository(context).archive(
        uuidSchema.parse(context.req.param("circle_id")),
        expectedVersion(context),
      ),
    );
  });
  const copyCircleTemplateBody = z.object({
    title: z.string().min(1).max(120).nullable().optional(),
  }).strict().openapi("CopyCircleTemplateRequest");
  const copyCircleTemplate = retainedRoute(
    "post",
    "/v1/circle-templates/{template_id}/copy",
    "copyCircleTemplate",
    "Circles",
    {
      pathParams: z.object({ template_id: uuidSchema }),
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      body: copyCircleTemplateBody,
      response: circleDetailResponseSchema,
    },
  );
  dependencies.register(copyCircleTemplate, async (context) => {
    const body = await parseBody(context, copyCircleTemplateBody);
    const template = await dependencies.repository(context).getTemplate(
      uuidSchema.parse(context.req.param("template_id")),
    );
    if (template === null) throw new RepositoryNotFoundError();
    const value = z.object({
      id: uuidSchema,
      title: z.string().min(1).max(120),
      description: z.string().max(1000),
      assets: z.array(
        z.object({
          id: uuidSchema,
          ordinal: z.number().int().positive(),
          weight_bps: z.number().int().min(0).max(10_000).nullable(),
          note: z.string().max(2_000).nullable(),
        }).passthrough(),
      ).max(50),
    }).passthrough().parse(template);
    return dataResponse(
      context,
      await dependencies.repository(context).create({
        title: body.title ?? value.title,
        description: value.description,
        sourceTemplateId: value.id,
        assets: value.assets.map((asset) => ({
          assetId: asset.id,
          ordinal: asset.ordinal,
          weightBps: asset.weight_bps,
          note: asset.note,
        })),
      }),
    );
  });

  const listSaved = retainedRoute("get", "/v1/saved", "listSaved", "Saved", {
    query: z.object({ limit: pageLimitSchema.optional() }),
  });
  dependencies.register(listSaved, async (context) =>
    dataResponse(
      context,
      await dependencies.repository(context).listSaved(
        pageLimitSchema.parse(context.req.query("limit")),
      ),
    ));
  const savedPath = z.object({
    item_kind: z.enum(["asset", "grimoire", "circle_template", "coven"]),
    item_id: uuidSchema,
  });
  const saveItem = retainedRoute(
    "post",
    "/v1/saved/{item_kind}/{item_id}",
    "saveItem",
    "Saved",
    {
      pathParams: savedPath,
      body: z.object({
        source_kind: z.enum([
          "ritual",
          "circle",
          "discover",
          "search",
          "direct",
        ]).optional(),
        source_id: uuidSchema.nullable().optional(),
      }).strict().openapi("SaveItemRequest"),
      optionalBody: true,
    },
  );
  dependencies.register(saveItem, async (context) => {
    const body = z.object({
      source_kind: z.enum(["ritual", "circle", "discover", "search", "direct"])
        .optional(),
      source_id: uuidSchema.nullable().optional(),
    }).strict().parse(context.req.valid("json" as never) ?? {});
    if (
      (body.source_kind === undefined || body.source_kind === "direct") &&
      body.source_id != null
    ) {
      throw new HttpBoundaryError(
        422,
        "validation_failed",
        "source_id requires an attributed source_kind.",
      );
    }
    return dataResponse(
      context,
      await dependencies.repository(context).save(
        savedPath.shape.item_kind.parse(context.req.param("item_kind")),
        uuidSchema.parse(context.req.param("item_id")),
        body.source_kind ?? "direct",
        body.source_id ?? undefined,
      ),
    );
  });
  const unsaveItem = retainedRoute(
    "delete",
    "/v1/saved/{item_kind}/{item_id}",
    "unsaveItem",
    "Saved",
    { pathParams: savedPath },
  );
  dependencies.register(unsaveItem, async (context) =>
    dataResponse(
      context,
      await dependencies.repository(context).unsave(
        savedPath.shape.item_kind.parse(context.req.param("item_kind")),
        uuidSchema.parse(context.req.param("item_id")),
      ) ?? { removed: true },
    ));
}
