import { z } from "@hono/zod-openapi";

import { demoDisclosureSchema } from "../../contracts/common.ts";

export const modeSchema = z.enum(["tarot", "astrology"]);
export const publicDateSchema = z.iso.date();
export const uuidSchema = z.uuid();

export const artReferenceSchema = z.object({
  key: z.enum(["the_compass"]),
  alt: z.string().min(1).max(240),
}).strict().openapi("ArtReference");

export const assetIdeaSchema = z.object({
  asset_id: uuidSchema,
  symbol: z.string().min(1).max(16),
  name: z.string().min(1).max(120),
  appearance_reason: z.string().min(1).max(500),
  risk_summary: z.string().min(1).max(500),
}).strict().openapi("RitualAssetIdea");

export const publicAssetTeaserSchema = assetIdeaSchema.pick({
  symbol: true,
  name: true,
  appearance_reason: true,
}).strict().openapi("PublicAssetTeaser");

export const evidenceSummarySchema = z.object({
  claim_id: uuidSchema,
  factor_label: z.string().min(1).max(120),
  summary: z.string().min(1).max(1_000),
  observed_at: z.iso.datetime({ offset: true }),
  uncertainty: z.string().min(1).max(1_000),
}).strict().openapi("EvidenceSummary");

export const evidenceDetailSchema = evidenceSummarySchema.extend({
  source: z.object({
    title: z.string().min(1).max(240),
    publisher: z.string().min(1).max(120),
    url: z.url().refine((value) => value.startsWith("https://")),
    published_at: z.iso.datetime({ offset: true }).nullable(),
  }).strict(),
}).strict().openapi("EvidenceDetail");

export const dailyRitualPreviewSchema = z.object({
  date: publicDateSchema,
  mode: modeSchema,
  title: z.string().min(1).max(120),
  art: artReferenceSchema,
  interpretation_excerpt: z.string().min(1).max(500),
  market_label: z.string().min(1).max(120),
  idea_teasers: z.array(publicAssetTeaserSchema).min(3).max(5),
  demo: demoDisclosureSchema,
}).strict().openapi("DailyRitualPreview");

export const rowanCounselSchema = z.object({
  script_revision_id: uuidSchema,
  surface: z.enum(["daily_ritual", "evidence", "asset_codex", "coven"]),
  body: z.string().min(1).max(2_000).refine(
    (value) => !/(\{\{|\$\{|\[\[|<%)/u.test(value),
    { message: "Rowan counsel cannot contain unresolved template tokens" },
  ),
  risk_footer: z.string().min(1).max(500),
}).strict().openapi("RowanCounsel");

export const dailyRitualDetailSchema = z.object({
  assignment_id: uuidSchema,
  date: publicDateSchema,
  mode: modeSchema,
  revision: z.object({ id: uuidSchema, number: z.number().int().positive() }).strict(),
  title: z.string().min(1).max(120),
  art: artReferenceSchema,
  interpretation: z.string().min(1).max(10_000),
  guidance: z.string().min(1).max(2_000),
  market_label: z.string().min(1).max(120),
  ideas: z.array(assetIdeaSchema).min(3).max(5),
  evidence: z.array(evidenceSummarySchema).min(1).max(20),
  rowan: rowanCounselSchema,
  version: z.number().int().positive(),
  state: z.enum(["assigned", "revealed", "completed"]),
  revealed_at: z.iso.datetime({ offset: true }).nullable(),
  completed_at: z.iso.datetime({ offset: true }).nullable(),
  demo: demoDisclosureSchema,
}).strict().openapi("DailyRitualDetail");

export const ritualHistoryItemSchema = dailyRitualDetailSchema.pick({
  assignment_id: true,
  date: true,
  mode: true,
  title: true,
  state: true,
  demo: true,
}).strict().openapi("RitualHistoryItem");

export const assetSummarySchema = z.object({
  id: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  symbol: z.string().min(1).max(16),
  name: z.string().min(1).max(120),
  asset_type: z.enum(["equity", "etf", "index", "cash"]).openapi({
    "x-enum-varnames": ["equity", "etf", "marketIndex", "cash"],
  }),
  currency: z.literal("USD"),
  revision_id: uuidSchema,
  appearance_reason: z.string().min(1).max(1_000),
  demo: demoDisclosureSchema,
}).strict().openapi("AssetSummary");

export const assetCodexDetailSchema = assetSummarySchema.extend({
  thesis: z.string().min(1).max(10_000),
  risks: z.array(z.object({
    title: z.string().min(1).max(120),
    detail: z.string().min(1).max(2_000),
    severity: z.enum(["low", "medium", "high"]),
  }).strict()).min(1).max(20),
  evidence: z.array(evidenceSummarySchema).min(1).max(20),
  metrics_as_of: z.iso.datetime({ offset: true }),
  limitations: z.string().min(1).max(2_000),
  saved: z.boolean(),
}).strict().openapi("AssetCodexDetail");

export const assetMetricSchema = z.object({
  observed_at: z.iso.datetime({ offset: true }),
  price_minor: z.number().int().nonnegative(),
  change_bps: z.number().int().nullable(),
  expense_ratio_bps: z.number().int().nonnegative().nullable(),
  source_label: z.string().min(1).max(120),
  demo: demoDisclosureSchema,
}).strict().openapi("AssetMetric");

export const assetComparisonSchema = z.object({
  assets: z.array(z.object({
    asset: assetSummarySchema,
    latest_metric: assetMetricSchema,
    risk_count: z.number().int().nonnegative(),
  }).strict()).min(2).max(5),
  compared_at: z.iso.datetime({ offset: true }),
  demo: demoDisclosureSchema,
}).strict().openapi("AssetComparison");

export const covenQualificationSchema = z.object({
  category: z.enum(["founder", "owner", "chief_executive"]),
  person_name: z.string().min(1).max(120),
  effective_date: publicDateSchema,
  valid_to: publicDateSchema.nullable(),
  verified_as_of: publicDateSchema,
  evidence: z.array(evidenceSummarySchema).min(1).max(20),
}).strict().openapi("CovenQualification");

export const publicCovenTeaserSchema = z.object({
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  company: z.string().min(1).max(120),
  category: z.enum(["founder", "owner", "chief_executive"]),
  verified_as_of: publicDateSchema,
  teaser: z.string().min(1).max(500),
  demo: demoDisclosureSchema,
}).strict().openapi("PublicCovenTeaser");

export const covenSummarySchema = publicCovenTeaserSchema.extend({
  id: uuidSchema,
  effective_date: publicDateSchema,
  revision_id: uuidSchema,
}).strict().openapi("CovenSummary");

export const covenDetailSchema = z.object({
  id: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  company: z.string().min(1).max(120),
  symbol: z.string().min(1).max(16).nullable(),
  summary: z.string().min(1).max(2_000),
  inclusion_rationale: z.string().min(1).max(5_000),
  limitations: z.string().min(1).max(2_000),
  qualifications: z.array(covenQualificationSchema).min(1).max(20),
  revision_id: uuidSchema,
  saved: z.boolean(),
  demo: demoDisclosureSchema,
}).strict().openapi("CovenEntryDetail");

export const grimoireSummarySchema = z.object({
  id: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  title: z.string().min(1).max(120),
  description: z.string().min(1).max(2_000),
  theme: z.string().min(1).max(64),
  curator_label: z.string().min(1).max(120),
  revision_id: uuidSchema,
  demo: demoDisclosureSchema,
}).strict().openapi("GrimoireSummary");

export const grimoireDetailSchema = grimoireSummarySchema.extend({
  assets: z.array(assetSummarySchema).min(1).max(50),
}).strict().openapi("GrimoireDetail");

export const seededCreatorSchema = z.object({
  id: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  display_name: z.string().min(1).max(120),
  bio: z.string().min(1).max(2_000),
  is_fictional: z.literal(true),
  demo: demoDisclosureSchema,
}).strict().openapi("SeededCreator");

export const circleTemplateSummarySchema = z.object({
  id: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  title: z.string().min(1).max(120),
  description: z.string().min(1).max(2_000),
  theme: z.string().min(1).max(64),
  creator: seededCreatorSchema,
  revision_id: uuidSchema,
  demo: demoDisclosureSchema,
}).strict().openapi("CircleTemplateSummary");

export const circleTemplateDetailSchema = circleTemplateSummarySchema.extend({
  assets: z.array(assetSummarySchema.extend({
    ordinal: z.number().int().min(1).max(50),
    weight_bps: z.number().int().min(0).max(10_000).nullable(),
    note: z.string().max(2_000).nullable(),
  }).strict()).min(1).max(50),
}).strict().openapi("CircleTemplateDetail");

export const discoverItemSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("asset"), asset: assetSummarySchema }).strict(),
  z.object({ kind: z.literal("coven"), coven: covenSummarySchema }).strict(),
  z.object({ kind: z.literal("grimoire"), grimoire: grimoireSummarySchema }).strict(),
  z.object({ kind: z.literal("circle_template"), circle_template: circleTemplateSummarySchema }).strict(),
]).openapi("DiscoverItem");

export const publicDiscoverItemSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("asset"),
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    symbol: z.string().min(1).max(16),
    title: z.string().min(1).max(120),
    teaser: z.string().min(1).max(500),
    demo: demoDisclosureSchema,
  }).strict(),
  z.object({
    kind: z.literal("coven"),
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    title: z.string().min(1).max(120),
    category: z.enum(["founder", "owner", "chief_executive"]),
    verified_as_of: publicDateSchema,
    teaser: z.string().min(1).max(500),
    demo: demoDisclosureSchema,
  }).strict(),
  z.object({
    kind: z.literal("grimoire"),
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    title: z.string().min(1).max(120),
    teaser: z.string().min(1).max(500),
    demo: demoDisclosureSchema,
  }).strict(),
  z.object({
    kind: z.literal("circle_template"),
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    title: z.string().min(1).max(120),
    teaser: z.string().min(1).max(500),
    creator_label: z.string().min(1).max(120),
    is_fictional: z.literal(true),
    demo: demoDisclosureSchema,
  }).strict(),
]).openapi("PublicDiscoverItem");

export const searchResultSchema = discoverItemSchema.openapi("SearchResult");

export type DailyRitualPreview = z.infer<typeof dailyRitualPreviewSchema>;
export type DailyRitualDetail = z.infer<typeof dailyRitualDetailSchema>;
export type EvidenceDetail = z.infer<typeof evidenceDetailSchema>;
export type AssetSummary = z.infer<typeof assetSummarySchema>;
export type AssetCodexDetail = z.infer<typeof assetCodexDetailSchema>;
export type AssetMetric = z.infer<typeof assetMetricSchema>;
export type AssetComparison = z.infer<typeof assetComparisonSchema>;
export type PublicCovenTeaser = z.infer<typeof publicCovenTeaserSchema>;
export type CovenSummary = z.infer<typeof covenSummarySchema>;
export type CovenDetail = z.infer<typeof covenDetailSchema>;
export type GrimoireSummary = z.infer<typeof grimoireSummarySchema>;
export type GrimoireDetail = z.infer<typeof grimoireDetailSchema>;
export type SeededCreator = z.infer<typeof seededCreatorSchema>;
export type CircleTemplateSummary = z.infer<typeof circleTemplateSummarySchema>;
export type CircleTemplateDetail = z.infer<typeof circleTemplateDetailSchema>;
export type DiscoverItem = z.infer<typeof discoverItemSchema>;
export type PublicDiscoverItem = z.infer<typeof publicDiscoverItemSchema>;
export type RowanCounsel = z.infer<typeof rowanCounselSchema>;
