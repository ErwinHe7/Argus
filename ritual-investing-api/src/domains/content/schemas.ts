import { z } from "@hono/zod-openapi";

import {
  nullableTimestampSchema,
  retainedCollectionEnvelope,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

export const publicAssetTypeSchema = z.enum([
  "equity",
  "etf",
  "market_index",
  "cash",
]);
const catalogAssetSchema = z.object({
  id: uuidSchema,
  slug: z.string().min(1).max(120),
  symbol: z.string().min(1).max(32),
  name: z.string().min(1).max(160),
  asset_type: publicAssetTypeSchema,
  currency: z.string().regex(/^[A-Z]{3}$/),
  exchange: z.string().max(64).nullable(),
  status: z.enum(["active", "inactive"]),
}).strict().openapi("CatalogAsset");
const researchDisclosureSchema = z.object({
  is_demo: z.boolean(),
  observed_at: z.string().datetime(),
  source_label: z.string().min(1).max(120),
  limitations: z.array(z.string().min(1).max(500)).min(1).max(20),
}).strict().openapi("ResearchDisclosure");
const evidenceSummarySchema = z.object({
  claim_id: uuidSchema,
  factor_label: z.string().min(1).max(120),
  summary: z.string().min(1).max(1000),
  observed_at: z.string().datetime(),
  uncertainty: z.string().min(1).max(1000),
}).strict().openapi("EvidenceSummary");
const evidenceDetailSchema = evidenceSummarySchema.extend({
  source: z.object({
    title: z.string().min(1).max(240),
    publisher: z.string().min(1).max(120),
    url: z.string().url().refine((value) => value.startsWith("https://"))
      .nullable(),
    published_at: nullableTimestampSchema,
  }).strict(),
}).strict().openapi("EvidenceDetail");
export const assetSummarySchema = catalogAssetSchema
  .omit({ exchange: true, status: true })
  .extend({
    revision_id: uuidSchema,
    appearance_reason: z.string().min(1).max(1000),
    demo: researchDisclosureSchema,
  }).strict().openapi("AssetSummary");
const assetRiskSchema = z.object({
  title: z.string().min(1).max(120),
  detail: z.string().min(1).max(2000),
  severity: z.enum(["low", "medium", "high"]),
}).strict().openapi("AssetRisk");
const assetDetailSchema = assetSummarySchema.extend({
  thesis: z.string().min(1).max(10000),
  limitations: z.string().min(1).max(2000),
  metrics_as_of: z.string().datetime(),
  evidence: z.array(evidenceSummarySchema).max(20),
  risks: z.array(assetRiskSchema).max(20),
  saved: z.boolean(),
}).strict().openapi("AssetCodexDetail");
const assetMetricSchema = z.object({
  observed_at: z.string().datetime(),
  price_minor: z.number().int().nonnegative(),
  change_bps: z.number().int().nullable(),
  expense_ratio_bps: z.number().int().nonnegative().nullable(),
  source_label: z.string().min(1).max(120),
  demo: researchDisclosureSchema,
}).strict().openapi("AssetMetric");
export const assetCollectionResponseSchema = retainedCollectionEnvelope(
  "AssetCollectionResponse",
  z.array(assetSummarySchema).max(100),
);
export const assetDetailResponseSchema = retainedEnvelope(
  "AssetDetailResponse",
  assetDetailSchema,
);
export const assetEvidenceResponseSchema = retainedEnvelope(
  "AssetEvidenceResponse",
  z.array(evidenceDetailSchema).max(20),
);
export const assetMetricsResponseSchema = retainedEnvelope(
  "AssetMetricsResponse",
  z.array(assetMetricSchema).max(90),
);
const assetComparisonSchema = z.object({
  assets: z.array(
    z.object({
      asset: assetSummarySchema,
      latest_metric: assetMetricSchema.nullable(),
      risk_count: z.number().int().nonnegative(),
    }).strict(),
  ).min(2).max(5),
  compared_at: z.string().datetime(),
  demo: researchDisclosureSchema,
}).strict().openapi("AssetComparison");
export const assetComparisonResponseSchema = retainedEnvelope(
  "AssetComparisonResponse",
  assetComparisonSchema,
);

export const briefingSummarySchema = z.object({
  id: uuidSchema,
  briefing_type: z.enum(["daily", "weekly", "moon_cycle"]),
  period_start: z.string().date(),
  period_end: z.string().date(),
  generated_at: z.string().datetime(),
  generation: z.number().int().positive(),
  source_sequence: z.number().int().positive(),
  read_at: nullableTimestampSchema,
}).strict().openapi("BriefingSummary");
const briefingSectionSchema = z.object({
  ordinal: z.number().int().positive(),
  source_sequence: z.number().int().positive(),
  schema_version: z.number().int().positive(),
  disclosure: z.string().min(1).max(2000),
}).strict().openapi("BriefingSection");
const briefingDetailSchema = briefingSummarySchema.extend({
  sections: z.array(briefingSectionSchema).max(100),
}).strict().openapi("BriefingDetail");
export const briefingCollectionResponseSchema = retainedCollectionEnvelope(
  "BriefingCollectionResponse",
  z.array(briefingSummarySchema).max(100),
);
export const briefingDetailResponseSchema = retainedEnvelope(
  "BriefingDetailResponse",
  briefingDetailSchema,
);
export const briefingPendingResponseSchema = retainedEnvelope(
  "BriefingPendingResponse",
  z.object({
    status: z.literal("briefing_pending"),
    local_date: z.string().date(),
  }).strict().openapi("BriefingPending"),
);

const circleSchema = z.object({
  id: uuidSchema,
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  title: z.string().min(1).max(80),
  description: z.string().max(1000),
  private: z.literal(true),
  source_template_id: uuidSchema.nullable(),
  source_revision_id: uuidSchema.nullable(),
  version: z.coerce.number().int().positive(),
  archived_at: nullableTimestampSchema,
  assets: z.array(
    z.object({
      id: uuidSchema,
      asset_id: uuidSchema,
      ordinal: z.coerce.number().int().positive(),
      weight_bps: z.coerce.number().int().min(0).max(10000).nullable(),
      note: z.string().max(2000).nullable(),
    }).passthrough(),
  ).optional(),
}).passthrough().openapi("MemberCircle");
export const circleCollectionResponseSchema = retainedCollectionEnvelope(
  "CircleCollectionResponse",
  z.array(circleSchema).max(100),
);
export const circleDetailResponseSchema = retainedEnvelope(
  "CircleDetailResponse",
  circleSchema,
);
const seededCreatorSchema = z.object({
  id: uuidSchema,
  slug: z.string().min(1).max(120),
  display_name: z.string().min(1).max(120),
  bio: z.string().min(1).max(2000),
  is_fictional: z.literal(true),
  demo: researchDisclosureSchema,
}).strict().openapi("SeededCreator");
export const creatorResponseSchema = retainedEnvelope(
  "CreatorResponse",
  seededCreatorSchema.nullable(),
);
const circleTemplateAssetSchema = assetSummarySchema.extend({
  ordinal: z.number().int().min(1).max(50),
  weight_bps: z.number().int().min(0).max(10000).nullable(),
  note: z.string().max(2000).nullable(),
}).strict().openapi("CircleTemplateAsset");
const circleTemplateDetailSchema = z.object({
  id: uuidSchema,
  revision_id: uuidSchema,
  slug: z.string().min(1).max(120),
  title: z.string().min(1).max(120),
  description: z.string().min(1).max(2000),
  theme: z.string().min(1).max(64),
  creator: seededCreatorSchema,
  assets: z.array(circleTemplateAssetSchema).max(50),
  saved: z.boolean(),
  demo: researchDisclosureSchema,
}).strict().openapi("CircleTemplateDetail");
export const circleTemplateDetailResponseSchema = retainedEnvelope(
  "CircleTemplateDetailResponse",
  circleTemplateDetailSchema,
);
const covenQualificationSchema = z.object({
  category: z.enum(["founder", "owner", "chief_executive"]),
  person_name: z.string().min(1).max(120),
  effective_date: z.string().date(),
  valid_to: z.string().date().nullable(),
  verified_as_of: z.string().date(),
  evidence: z.array(evidenceSummarySchema).max(20),
}).strict().openapi("CovenQualification");
export const covenSummarySchema = z.object({
  id: uuidSchema,
  revision_id: uuidSchema,
  slug: z.string().min(1).max(120),
  company: z.string().min(1).max(160),
  symbol: z.string().max(32).nullable(),
  category: z.enum(["founder", "owner", "chief_executive"]),
  focus: z.string().min(1).max(120),
  teaser: z.string().min(1).max(500),
  effective_date: z.string().date(),
  verified_as_of: z.string().date(),
  demo: researchDisclosureSchema,
}).strict().openapi("CovenSummary");
const covenDetailSchema = covenSummarySchema.extend({
  summary: z.string().min(1).max(2000),
  inclusion_rationale: z.string().min(1).max(5000),
  limitations: z.string().min(1).max(2000),
  qualifications: z.array(covenQualificationSchema).max(20),
  evidence: z.array(evidenceDetailSchema).max(100),
  saved: z.boolean(),
}).strict().openapi("CovenEntryDetail");
export const covenCollectionResponseSchema = retainedCollectionEnvelope(
  "CovenCollectionResponse",
  z.array(covenSummarySchema).max(100),
);
export const covenDetailResponseSchema = retainedEnvelope(
  "CovenDetailResponse",
  covenDetailSchema,
);
export const covenEvidenceResponseSchema = retainedEnvelope(
  "CovenEvidenceResponse",
  z.array(evidenceDetailSchema).max(100),
);
export const grimoireSummarySchema = z.object({
  id: uuidSchema,
  revision_id: uuidSchema,
  slug: z.string().min(1).max(120),
  title: z.string().min(1).max(120),
  description: z.string().min(1).max(2000),
  theme: z.string().min(1).max(64),
  curator_label: z.string().min(1).max(120),
  demo: researchDisclosureSchema,
}).strict().openapi("GrimoireSummary");
const grimoireDetailSchema = grimoireSummarySchema.extend({
  assets: z.array(assetSummarySchema).max(50),
  saved: z.boolean(),
}).strict().openapi("GrimoireDetail");
export const circleTemplateSummarySchema = circleTemplateDetailSchema.omit({
  assets: true,
  saved: true,
}).openapi("CircleTemplateSummary");
export const discoverAssetCollectionResponseSchema = retainedCollectionEnvelope(
  "DiscoverAssetCollectionResponse",
  z.array(assetSummarySchema).max(100),
);
export const grimoireCollectionResponseSchema = retainedCollectionEnvelope(
  "GrimoireCollectionResponse",
  z.array(grimoireSummarySchema).max(100),
);
export const circleTemplateCollectionResponseSchema =
  retainedCollectionEnvelope(
    "CircleTemplateCollectionResponse",
    z.array(circleTemplateSummarySchema).max(100),
  );
export const grimoireDetailResponseSchema = retainedEnvelope(
  "GrimoireDetailResponse",
  grimoireDetailSchema,
);
export const creatorCollectionResponseSchema = retainedCollectionEnvelope(
  "CreatorCollectionResponse",
  z.array(seededCreatorSchema).max(100),
);
const discoverItemSchema = z.object({
  kind: z.enum(["asset", "coven", "grimoire", "circle_template"]),
  asset: assetSummarySchema.nullable().optional(),
  coven: covenSummarySchema.nullable().optional(),
  grimoire: grimoireSummarySchema.nullable().optional(),
  circle_template: circleTemplateSummarySchema.nullable().optional(),
}).strict().openapi("DiscoverItem");
export const discoverResponseSchema = retainedCollectionEnvelope(
  "DiscoverResponse",
  z.array(discoverItemSchema).max(100),
);
