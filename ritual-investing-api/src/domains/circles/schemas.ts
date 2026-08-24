import { z } from "@hono/zod-openapi";

import { boundedUserText } from "../../security/input-schemas.ts";

const circleTitle = boundedUserText({ maximum: 80 });
const circleDescription = boundedUserText({
  maximum: 10_000,
  minimum: 0,
  trim: false,
});
const circleNote = boundedUserText({
  maximum: 2_000,
  minimum: 0,
  trim: false,
});

export const circleIdParamsSchema = z.object({ id: z.uuid() });
export const circleAssetParamsSchema = z.object({
  id: z.uuid(),
  asset_id: z.uuid(),
});
export const circleListQuerySchema = z
  .object({
    archived: z.enum(["exclude", "include", "only"]).default("exclude"),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(20).max(2_048).optional(),
  })
  .strict();
export const circleAssetInputSchema = z
  .object({
    asset_id: z.uuid(),
    ordinal: z.number().int().min(1).max(50),
    weight_bps: z.number().int().min(0).max(10_000).optional(),
    note: circleNote.optional(),
  })
  .strict();
export const circleAssetMutationSchema = circleAssetInputSchema
  .omit({ asset_id: true })
  .strict();
export const circleAssetViewSchema = z
  .object({
    asset_id: z.uuid(),
    ordinal: z.number().int().min(1).max(50),
    weight_bps: z.number().int().min(0).max(10_000).nullable(),
    note: z.string().max(2_000).nullable(),
  })
  .strict();
export const circleCreateSchema = z
  .object({
    title: circleTitle,
    description: circleDescription.optional(),
    assets: z.array(circleAssetInputSchema).max(50).optional(),
  })
  .strict()
  .superRefine((value, ctx) => {
    const assets = value.assets ?? [];
    if (new Set(assets.map((x) => x.asset_id)).size !== assets.length)
      ctx.addIssue({
        code: "custom",
        path: ["assets"],
        message: "assets must be unique",
      });
    if (new Set(assets.map((x) => x.ordinal)).size !== assets.length)
      ctx.addIssue({
        code: "custom",
        path: ["assets"],
        message: "ordinals must be unique",
      });
    const weighted = assets.filter((x) => x.weight_bps !== undefined);
    if (
      weighted.length > 0 &&
      (weighted.length !== assets.length ||
        weighted.reduce((sum, x) => sum + (x.weight_bps ?? 0), 0) !== 10_000)
    )
      ctx.addIssue({
        code: "custom",
        path: ["assets"],
        message: "weights must all be present and total 10000",
      });
  });
export const circlePatchSchema = z
  .object({
    title: circleTitle.optional(),
    description: circleDescription.optional(),
  })
  .strict()
  .refine((v) => Object.keys(v).length > 0);
export const copyTemplateSchema = z
  .object({ title: circleTitle.optional() })
  .strict();
export const circleViewSchema = z
  .object({
    id: z.uuid(),
    title: z.string(),
    description: z.string(),
    private: z.literal(true),
    source_template_id: z.uuid().nullable(),
    source_revision_id: z.uuid().nullable(),
    assets: z.array(circleAssetViewSchema),
    version: z.number().int().positive(),
    archived_at: z.iso.datetime({ offset: true }).nullable(),
  })
  .strict()
  .openapi("CircleView");
