import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AssetRepository } from "./ports.ts";
import {
  assetCollectionResponseSchema,
  assetComparisonResponseSchema,
  assetDetailResponseSchema,
  assetEvidenceResponseSchema,
  assetMetricsResponseSchema,
  publicAssetTypeSchema,
} from "../content/schemas.ts";
import {
  cursorFilterIdentity,
  keysetPage,
  pagedContentQuery,
  typedKeysetPosition,
} from "../content/pagination.ts";
import {
  contentArray,
  contentRecord,
  presentAssetDetail,
  presentAssetMetric,
  presentAssetSummary,
  presentEvidenceDetail,
  researchDisclosure,
} from "../content/service.ts";
import {
  collectionDataResponse,
  dataResponse,
  HttpBoundaryError,
  parseBody,
  query,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { pageLimitSchema, uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type AssetRouteRepository = AssetRepository;

export function registerAssetRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => AssetRouteRepository;
  }>,
): void {
  const listAssets = retainedRoute(
    "get",
    "/v1/assets",
    "listAssets",
    "Assets",
    {
      query: z.object({
        cursor: pagedContentQuery.shape.cursor,
        limit: pageLimitSchema.optional(),
        asset_type: publicAssetTypeSchema.optional(),
        symbol_prefix: z.string().min(1).max(32).optional(),
      }).strict(),
      response: assetCollectionResponseSchema,
    },
  );
  input.register(listAssets, async (context) => {
    const request = z.object({
      cursor: z.string().optional(),
      limit: pageLimitSchema,
      asset_type: publicAssetTypeSchema.optional(),
      symbol_prefix: z.string().min(1).max(32).optional(),
    }).parse(query(context));
    const baseBinding = {
      resource: "assets:list:v1",
      scope: "member",
      verifiedSubject: context.get("claims").userId,
      filterIdentity: cursorFilterIdentity({
        asset_type: request.asset_type,
        symbol_prefix: request.symbol_prefix,
      }),
      pageSize: request.limit,
    } as const;
    const binding = request.cursor === undefined
      ? baseBinding
      : { ...baseBinding, cursor: request.cursor };
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(32), uuidSchema]),
    );
    const rows = await input.repository(context).listPage({
      limit: request.limit + 1,
      assetType: request.asset_type === "market_index"
        ? "index"
        : request.asset_type,
      symbolPrefix: request.symbol_prefix,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => {
      const asset = contentRecord(row);
      return [String(asset.symbol), String(asset.id)];
    });
    return collectionDataResponse(
      context,
      page.items.map(presentAssetSummary),
      page.nextCursor,
    );
  });

  const compareBody = z.object({
    assetIds: z.array(uuidSchema).min(2).max(5),
  }).strict().openapi("CompareAssetsRequest");
  const compareAssets = retainedRoute(
    "post",
    "/v1/assets/compare",
    "compareAssets",
    "Assets",
    { body: compareBody, response: assetComparisonResponseSchema },
  );
  input.register(compareAssets, async (context) => {
    const request = await parseBody(context, compareBody);
    if (new Set(request.assetIds).size !== request.assetIds.length) {
      throw new HttpBoundaryError(
        422,
        "validation_failed",
        "Asset identifiers must be unique.",
      );
    }
    const rows = await input.repository(context).compare(request.assetIds);
    if (rows.length !== request.assetIds.length) {
      throw new HttpBoundaryError(
        404,
        "not_found",
        "A requested asset was not found.",
      );
    }
    const comparedAt = new Date().toISOString();
    return dataResponse(context, {
      assets: rows.map((row) => {
        const record = contentRecord(row);
        const payload = contentRecord(record.payload);
        const metrics = contentArray(payload, "metrics");
        return {
          asset: presentAssetSummary(record),
          latest_metric: metrics.length === 0
            ? null
            : presentAssetMetric(metrics[metrics.length - 1]),
          risk_count: contentArray(payload, "risks").length,
        };
      }),
      compared_at: comparedAt,
      demo: researchDisclosure(comparedAt),
    });
  });

  const assetPath = z.object({ asset_id: uuidSchema });
  const getAsset = retainedRoute(
    "get",
    "/v1/assets/{asset_id}",
    "getAsset",
    "Assets",
    {
      pathParams: assetPath,
      response: assetDetailResponseSchema,
    },
  );
  input.register(getAsset, async (context) => {
    const assetId = uuidSchema.parse(context.req.param("asset_id"));
    const repository = input.repository(context);
    const value = await repository.get(assetId);
    const evidence = value === null ? [] : await repository.evidence(assetId);
    return dataResponse(
      context,
      value === null ? null : presentAssetDetail(value, evidence),
    );
  });

  const getEvidence = retainedRoute(
    "get",
    "/v1/assets/{asset_id}/evidence",
    "getAssetEvidence",
    "Assets",
    { pathParams: assetPath, response: assetEvidenceResponseSchema },
  );
  input.register(getEvidence, async (context) =>
    dataResponse(
      context,
      (await input.repository(context).evidence(
        uuidSchema.parse(context.req.param("asset_id")),
      )).map(presentEvidenceDetail),
    ));

  const getMetrics = retainedRoute(
    "get",
    "/v1/assets/{asset_id}/metrics",
    "getAssetMetrics",
    "Assets",
    {
      pathParams: assetPath,
      query: z.object({ as_of: z.string().datetime().optional() }),
      response: assetMetricsResponseSchema,
    },
  );
  input.register(getMetrics, async (context) =>
    dataResponse(
      context,
      (await input.repository(context).metrics(
        uuidSchema.parse(context.req.param("asset_id")),
      )).map(presentAssetMetric),
    ));
}
