import {
  createRoute,
  OpenAPIHono,
  type RouteConfig,
  z,
} from "@hono/zod-openapi";
import type { Context, MiddlewareHandler } from "hono";

import type { VerifiedRequestClaims } from "./db/request-context.ts";
import {
  RepositoryNotFoundError,
  RepositoryRevisionConflictError,
  RepositoryStepUpRequiredError,
} from "./db/supabase-repositories.ts";
import { StaffAuthorizationError } from "./db/request-transaction.ts";
import type { RateLimitPort } from "./ports/infrastructure.ts";
import {
  BrokerageConnectionError,
  type BrokerageConnectionRepository,
} from "./domains/brokerage-connections/repository.ts";
import {
  BrokerageProjectionError,
  type BrokerageProjectionResource,
} from "./domains/brokerage-projections/types.ts";
import type { BrokerageProjectionService } from "./domains/brokerage-projections/service.ts";
import { BrokerageOrderError } from "./domains/brokerage-orders/types.ts";
import type { BrokerageOrderService } from "./domains/brokerage-orders/service.ts";
import {
  ScenarioConflictError,
  type ScenarioRepository,
} from "./domains/intentions/repository.ts";
import {
  futureMirrorInputSchema,
  futureMirrorSchema,
  intentionCreateSchema,
  intentionPageSchema,
  intentionPatchSchema,
  intentionSchema,
} from "./domains/intentions/schemas.ts";

type RepositoryModule = typeof import("./db/supabase-repositories.ts");

export type RetainedRepositorySet = Readonly<{
  session: ReturnType<RepositoryModule["createSupabaseSessionRepository"]>;
  accounts: ReturnType<RepositoryModule["createSupabaseAccountRepository"]>;
  assets: ReturnType<RepositoryModule["createSupabaseAssetRepository"]>;
  editorial: ReturnType<RepositoryModule["createSupabaseEditorialRepository"]>;
  briefings: ReturnType<RepositoryModule["createSupabaseBriefingRepository"]>;
  circles: ReturnType<RepositoryModule["createSupabaseCircleRepository"]>;
  coven: ReturnType<RepositoryModule["createSupabaseCovenRepository"]>;
  discover: ReturnType<RepositoryModule["createSupabaseDiscoverRepository"]>;
  media: ReturnType<RepositoryModule["createSupabaseMediaRepository"]>;
  moderation: ReturnType<
    RepositoryModule["createSupabaseModerationRepository"]
  >;
  notifications: ReturnType<
    RepositoryModule["createSupabaseNotificationRepository"]
  >;
  privacy: ReturnType<RepositoryModule["createSupabasePrivacyRepository"]>;
  rituals: ReturnType<RepositoryModule["createSupabaseRitualRepository"]>;
  rowan: ReturnType<RepositoryModule["createSupabaseRowanRepository"]>;
  search: ReturnType<RepositoryModule["createSupabaseSearchRepository"]>;
  admin: ReturnType<RepositoryModule["createSupabaseAdminRepository"]>;
  adminOperations: ReturnType<
    RepositoryModule["createSupabaseAdminOperationsRepository"]
  >;
  scenarios: ScenarioRepository;
}>;

export type PublicPreviewRepository = ReturnType<
  RepositoryModule["createSupabasePublicPreviewRepository"]
>;

export type VerifiedSupabasePrincipal = Readonly<{
  userId: string;
  sessionId: string;
  aal: "aal1" | "aal2";
  issuedAt: number;
  authenticatedAt?: number;
}>;

export type RetainedTokenVerifier = (
  token: string,
) => Promise<VerifiedSupabasePrincipal>;

export type RetainedRuntimeBindings = Readonly<{
  environment: "development" | "test" | "staging" | "production";
  buildRevision: string;
  consumerOrigin: string;
  adminOrigin: string;
}>;

type RetainedVariables = {
  requestId: string;
  principal: VerifiedSupabasePrincipal;
  claims: VerifiedRequestClaims;
};

export type RetainedAppEnvironment = {
  Bindings: RetainedRuntimeBindings;
  Variables: RetainedVariables;
};

export type RetainedTelemetryEvent = Readonly<{
  event: "http.request";
  requestId: string;
  method: string;
  route: string;
  status: number;
  latencyMs: number;
}>;

export type CreateRetainedAppOptions = Readonly<{
  verifyAccessToken: RetainedTokenVerifier;
  createRepositories: (claims: VerifiedRequestClaims) => RetainedRepositorySet;
  publicPreviewRepository: PublicPreviewRepository;
  rateLimit: RateLimitPort;
  createBrokerageConnections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageConnectionRepository;
  createBrokerageProjections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageProjectionService;
  createBrokerageOrders?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageOrderService;
  requestId?: () => string;
  telemetry?: (event: RetainedTelemetryEvent) => void | Promise<void>;
}>;

const requestIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const uuid = z.string().uuid();
const limit = z.coerce.number().int().min(1).max(100).default(25);
const jsonObject = z.record(z.string(), z.unknown());
const responseSchema = z
  .object({
    data: z.unknown(),
    meta: z.object({ request_id: uuid }).strict(),
  })
  .strict();
const responseMetaSchema = z.object({ request_id: uuid }).strict();
const collectionMetaSchema = responseMetaSchema.extend({
  next_cursor: z.string().min(1).max(2048).nullable(),
  has_more: z.boolean(),
}).strict().openapi("CollectionMeta");
const retainedTimestampSchema = z.string().datetime().nullable();

function retainedEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: responseMetaSchema }).strict().openapi(name);
}

function retainedCollectionEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: collectionMetaSchema }).strict().openapi(name);
}

const memberProfileSchema = z.object({
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  display_name: z.string().min(1).max(80),
  avatar_media_id: uuid.nullable(),
  locale: z.string().min(2).max(35),
  updated_at: retainedTimestampSchema,
}).strict().openapi("MemberProfile");
const memberPreferencesSchema = z.object({
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  theme_mode: z.enum(["system", "light", "dark"]),
  ritual_mode: z.enum(["tarot", "astrology"]),
  timezone: z.string().min(1).max(64),
  locale: z.string().min(2).max(35),
  version: z.coerce.number().int().positive(),
}).strict().openapi("MemberPreferences");
const onboardingStateSchema = z.object({
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  current_step: z.string().min(1).max(80),
  completed_steps: z.array(z.string().min(1).max(80)).max(64),
  completed_at: retainedTimestampSchema,
  version: z.coerce.number().int().positive(),
}).strict().openapi("OnboardingState");
const investorProfileSchema = z.object({
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  goal_type: z.enum(["calm_fund", "long_term_growth", "income", "exploration"]),
  time_horizon: z.enum(["short", "medium", "long"]),
  risk_comfort: z.enum(["low", "moderate", "high"]),
  version: z.coerce.number().int().positive(),
}).strict().openapi("InvestorProfile");
const astrologyProfileSchema = z.object({
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  birth_date: z.string().date(),
  derived_profile_code: z.enum(["lunar_patient", "solar_builder", "rising_explorer"]),
  algorithm_version: z.literal("v1"),
  enabled_at: z.string().datetime(),
  version: z.number().int().min(1).max(1),
}).strict().openapi("AstrologyProfile");
const memberAccountSchema = z.object({
  status: z.enum(["active", "suspended", "deletion_pending", "purging", "purged"]),
  deletion_epoch: z.coerce.number().int().nonnegative(),
  profile: memberProfileSchema.nullable(),
  preferences: memberPreferencesSchema.nullable(),
  onboarding: onboardingStateSchema.nullable(),
  investor_profile: investorProfileSchema.nullable(),
  astrology_profile: astrologyProfileSchema.nullable(),
}).strict().openapi("MemberAccount");
const memberAccountResponseSchema = retainedEnvelope(
  "MemberAccountResponse",
  memberAccountSchema,
);
const consentReceiptSchema = z.object({
  id: uuid,
  policy_code: z.string().min(1).max(80),
  policy_version: z.string().min(1).max(40),
  decision: z.enum(["accepted", "declined", "withdrawn"]),
  recorded_at: z.string().datetime(),
}).strict().openapi("ConsentReceipt");
const consentReceiptResponseSchema = retainedEnvelope(
  "ConsentReceiptResponse",
  consentReceiptSchema,
);
const sessionMemberSchema = z.object({
  user_id: uuid,
  status: z.literal("active"),
  deletion_epoch: z.coerce.number().int().nonnegative(),
  deletion_requested_at: retainedTimestampSchema,
  created_at: retainedTimestampSchema,
  updated_at: retainedTimestampSchema,
}).passthrough().openapi("SessionMember");
const sessionBootstrapSchema = z.object({
  member: sessionMemberSchema,
  profile: memberProfileSchema.nullable(),
  preferences: memberPreferencesSchema.nullable(),
  onboarding: onboardingStateSchema.nullable(),
  investor_profile: investorProfileSchema.nullable(),
  astrology_profile: z.record(z.string(), z.unknown()).nullable(),
  server_time: z.string().datetime(),
}).strict().openapi("SessionBootstrap");
const sessionBootstrapResponseSchema = retainedEnvelope(
  "SessionBootstrapResponse",
  sessionBootstrapSchema,
);

const publicAssetTypeSchema = z.enum(["equity", "etf", "market_index", "cash"]);
const catalogAssetSchema = z.object({
  id: uuid,
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
  claim_id: uuid,
  factor_label: z.string().min(1).max(120),
  summary: z.string().min(1).max(1000),
  observed_at: z.string().datetime(),
  uncertainty: z.string().min(1).max(1000),
}).strict().openapi("EvidenceSummary");
const evidenceDetailSchema = evidenceSummarySchema.extend({
  source: z.object({
    title: z.string().min(1).max(240),
    publisher: z.string().min(1).max(120),
    url: z.string().url().refine((value) => value.startsWith("https://")).nullable(),
    published_at: retainedTimestampSchema,
  }).strict(),
}).strict().openapi("EvidenceDetail");
const assetSummarySchema = catalogAssetSchema.omit({ exchange: true, status: true }).extend({
  revision_id: uuid,
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
const assetCollectionResponseSchema = retainedCollectionEnvelope(
  "AssetCollectionResponse",
  z.array(assetSummarySchema).max(100),
);
const assetDetailResponseSchema = retainedEnvelope(
  "AssetDetailResponse",
  assetDetailSchema,
);
const assetEvidenceResponseSchema = retainedEnvelope(
  "AssetEvidenceResponse",
  z.array(evidenceDetailSchema).max(20),
);
const assetMetricsResponseSchema = retainedEnvelope(
  "AssetMetricsResponse",
  z.array(assetMetricSchema).max(90),
);
const assetComparisonSchema = z.object({
  assets: z.array(z.object({
    asset: assetSummarySchema,
    latest_metric: assetMetricSchema.nullable(),
    risk_count: z.number().int().nonnegative(),
  }).strict()).min(2).max(5),
  compared_at: z.string().datetime(),
  demo: researchDisclosureSchema,
}).strict().openapi("AssetComparison");
const assetComparisonResponseSchema = retainedEnvelope(
  "AssetComparisonResponse",
  assetComparisonSchema,
);

const briefingSummarySchema = z.object({
  id: uuid,
  briefing_type: z.enum(["daily", "weekly", "moon_cycle"]),
  period_start: z.string().date(),
  period_end: z.string().date(),
  generated_at: z.string().datetime(),
  generation: z.number().int().positive(),
  source_sequence: z.number().int().positive(),
  read_at: retainedTimestampSchema,
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
const briefingCollectionResponseSchema = retainedCollectionEnvelope(
  "BriefingCollectionResponse",
  z.array(briefingSummarySchema).max(100),
);
const briefingDetailResponseSchema = retainedEnvelope(
  "BriefingDetailResponse",
  briefingDetailSchema,
);
const briefingPendingResponseSchema = retainedEnvelope(
  "BriefingPendingResponse",
  z.object({
    status: z.literal("briefing_pending"),
    local_date: z.string().date(),
  }).strict().openapi("BriefingPending"),
);

const circleSchema = z.object({
  id: uuid,
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  title: z.string().min(1).max(80),
  description: z.string().max(1000),
  private: z.literal(true),
  source_template_id: uuid.nullable(),
  source_revision_id: uuid.nullable(),
  version: z.coerce.number().int().positive(),
  archived_at: retainedTimestampSchema,
  assets: z.array(z.object({
    id: uuid,
    asset_id: uuid,
    ordinal: z.coerce.number().int().positive(),
    weight_bps: z.coerce.number().int().min(0).max(10000).nullable(),
    note: z.string().max(2000).nullable(),
  }).passthrough()).optional(),
}).passthrough().openapi("MemberCircle");
const circleCollectionResponseSchema = retainedCollectionEnvelope(
  "CircleCollectionResponse",
  z.array(circleSchema).max(100),
);
const circleDetailResponseSchema = retainedEnvelope("CircleDetailResponse", circleSchema);
const seededCreatorSchema = z.object({
  id: uuid,
  slug: z.string().min(1).max(120),
  display_name: z.string().min(1).max(120),
  bio: z.string().min(1).max(2000),
  is_fictional: z.literal(true),
  demo: researchDisclosureSchema,
}).strict().openapi("SeededCreator");
const circleTemplateAssetSchema = assetSummarySchema.extend({
  ordinal: z.number().int().min(1).max(50),
  weight_bps: z.number().int().min(0).max(10000).nullable(),
  note: z.string().max(2000).nullable(),
}).strict().openapi("CircleTemplateAsset");
const circleTemplateDetailSchema = z.object({
  id: uuid,
  revision_id: uuid,
  slug: z.string().min(1).max(120),
  title: z.string().min(1).max(120),
  description: z.string().min(1).max(2000),
  theme: z.string().min(1).max(64),
  creator: seededCreatorSchema,
  assets: z.array(circleTemplateAssetSchema).max(50),
  saved: z.boolean(),
  demo: researchDisclosureSchema,
}).strict().openapi("CircleTemplateDetail");
const circleTemplateDetailResponseSchema = retainedEnvelope(
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
const covenSummarySchema = z.object({
  id: uuid,
  revision_id: uuid,
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
const covenCollectionResponseSchema = retainedCollectionEnvelope(
  "CovenCollectionResponse",
  z.array(covenSummarySchema).max(100),
);
const covenDetailResponseSchema = retainedEnvelope("CovenDetailResponse", covenDetailSchema);
const covenEvidenceResponseSchema = retainedEnvelope(
  "CovenEvidenceResponse",
  z.array(evidenceDetailSchema).max(100),
);
const grimoireSummarySchema = z.object({
  id: uuid,
  revision_id: uuid,
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
const circleTemplateSummarySchema = circleTemplateDetailSchema.omit({
  assets: true,
  saved: true,
}).openapi("CircleTemplateSummary");
const discoverAssetCollectionResponseSchema = retainedCollectionEnvelope(
  "DiscoverAssetCollectionResponse",
  z.array(assetSummarySchema).max(100),
);
const grimoireCollectionResponseSchema = retainedCollectionEnvelope(
  "GrimoireCollectionResponse",
  z.array(grimoireSummarySchema).max(100),
);
const circleTemplateCollectionResponseSchema = retainedCollectionEnvelope(
  "CircleTemplateCollectionResponse",
  z.array(circleTemplateSummarySchema).max(100),
);
const grimoireDetailResponseSchema = retainedEnvelope(
  "GrimoireDetailResponse",
  grimoireDetailSchema,
);
const creatorCollectionResponseSchema = retainedCollectionEnvelope(
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
const discoverResponseSchema = retainedCollectionEnvelope(
  "DiscoverResponse",
  z.array(discoverItemSchema).max(100),
);

const notificationSchema = z.object({
  id: uuid,
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  kind: z.string().min(1).max(80),
  title: z.string().min(1).max(160),
  body: z.string().min(1).max(2000),
  deep_link: z.string().max(512).nullable(),
  scheduled_at: retainedTimestampSchema,
  read_at: retainedTimestampSchema,
  created_at: z.string().datetime(),
}).strict().openapi("MemberNotification");
const notificationCollectionResponseSchema = retainedEnvelope(
  "NotificationCollectionResponse",
  z.array(notificationSchema).max(100),
);
const notificationPreferencesSchema = z.object({
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  daily_ritual: z.boolean(),
  weekly_recap: z.boolean(),
  moon_cycle: z.boolean(),
  quiet_hours: jsonObject,
  version: z.coerce.number().int().positive(),
}).strict().openapi("NotificationPreferences");
const notificationPreferencesResponseSchema = retainedEnvelope(
  "NotificationPreferencesResponse",
  notificationPreferencesSchema,
);
const privacyRequestSchema = z.object({
  id: uuid,
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  request_type: z.enum(["export", "deletion"]),
  status: z.enum(["requested", "verified", "queued", "processing", "completed", "failed", "cancelled"]),
  requested_at: z.string().datetime(),
  completed_at: retainedTimestampSchema,
  failure_code: z.string().max(128).nullable(),
}).strict().openapi("PrivacyRequest");
const privacyRequestCollectionResponseSchema = retainedEnvelope(
  "PrivacyRequestCollectionResponse",
  z.array(privacyRequestSchema).max(100),
);
const privacyRequestResponseSchema = retainedEnvelope("PrivacyRequestResponse", privacyRequestSchema);
const ritualAssignmentSchema = z.object({
  id: uuid,
  user_id: uuid,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  local_date: z.string().date(),
  mode: z.enum(["tarot", "astrology"]),
  schedule_id: uuid,
  revision_id: uuid,
  rowan_revision_id: uuid.nullable(),
  state: z.enum(["assigned", "revealed", "completed"]),
  revealed_at: retainedTimestampSchema,
  completed_at: retainedTimestampSchema,
  version: z.coerce.number().int().positive(),
  payload: jsonObject,
  body_template: z.string().nullable(),
  allowed_tokens: z.array(z.string()).nullable(),
  risk_footer: z.string().nullable(),
}).passthrough().openapi("DailyRitualAssignment");
const ritualAssignmentResponseSchema = retainedEnvelope(
  "DailyRitualResponse",
  ritualAssignmentSchema,
);
const ritualHistoryResponseSchema = retainedEnvelope(
  "RitualHistoryResponse",
  z.array(ritualAssignmentSchema).max(100),
);
const evidenceSourceSchema = z.object({
  canonical_url: z.string().url(),
  title: z.string().min(1),
  publisher: z.string().min(1),
  published_at: retainedTimestampSchema,
  retrieved_at: z.string().datetime(),
  source_kind: z.string().min(1),
}).passthrough().openapi("EvidenceSource");
const evidenceClaimSchema = z.object({
  id: uuid,
  claim_type: z.string().min(1),
  summary: z.string().min(1),
  observed_at: retainedTimestampSchema,
  uncertainty: z.string().min(1),
  source: evidenceSourceSchema,
}).passthrough().openapi("EvidenceClaim");
const ritualEvidenceResponseSchema = retainedEnvelope(
  "RitualEvidenceResponse",
  z.array(evidenceClaimSchema).max(256),
);
const searchResultSchema = z.object({
  kind: z.enum(["asset", "coven", "grimoire", "circle_template"]),
  asset: assetSummarySchema.nullable().optional(),
  coven: covenSummarySchema.nullable().optional(),
  grimoire: grimoireSummarySchema.nullable().optional(),
  circle_template: circleTemplateSummarySchema.nullable().optional(),
}).strict().openapi("SearchResult");
const searchResponseSchema = retainedCollectionEnvelope(
  "SearchResponse",
  z.array(searchResultSchema).max(100),
);
const rowanCounselSchema = z.object({
  id: uuid,
  script_key: z.string().min(1).max(160),
  priority: z.coerce.number().int(),
  body_template: z.string().min(1),
  allowed_tokens: z.array(z.string()).max(64),
  risk_footer: z.string().min(1),
}).strict().openapi("RowanCounsel");
const rowanCounselResponseSchema = retainedEnvelope("RowanCounselResponse", rowanCounselSchema);
const brokerageStateSchema = z.enum([
  "fresh",
  "empty",
  "stale",
  "partial",
  "unavailable",
  "offline",
  "rate_limited",
  "disconnected",
  "reauthorization_required",
]);
const brokerageCapabilitySchema = z.object({
  capability: z.enum([
    "balances_read",
    "positions_read",
    "orders_read",
    "manual_orders",
    "unsupported",
  ]),
  provider_code: z.string().min(1).max(128),
  available: z.boolean(),
}).strict().openapi("BrokerageCapability");
const brokerageAccountSchema = z.object({
  id: uuid,
  connection_id: uuid,
  display_label: z.string().min(1).max(160),
  base_currency: z.string().regex(/^[A-Z]{3}$/),
  market_timezone: z.string().min(1).max(64).nullable(),
  status: z.enum(["available", "restricted", "closed", "unavailable"]),
  capability_version: z.number().int().nonnegative(),
  capabilities: z.array(brokerageCapabilitySchema).max(64),
  state: brokerageStateSchema,
  selected: z.boolean(),
  provider_observed_at: z.string().datetime().nullable(),
  fetched_at: z.string().datetime().nullable(),
  expires_at: z.string().datetime().nullable(),
}).strict().openapi("BrokerageAccount");
const brokerageAccountAuthoritySchema = z.object({
  display_label: z.string().min(1).max(160),
  base_currency: z.string().regex(/^[A-Z]{3}$/),
  market_timezone: z.string().min(1).max(64),
  status: z.enum(["available", "restricted", "closed", "unavailable"]),
  capability_version: z.number().int().nonnegative(),
  capabilities: z.array(brokerageCapabilitySchema).max(64),
}).strict().openapi("BrokerageAccountAuthority");
const decimalStringSchema = z.string().regex(
  /^-?(?:0|[1-9]\d*)(?:\.\d{1,18})?$/,
);
const brokerageBalanceSchema = z.object({
  currency: z.string().regex(/^[A-Z]{3}$/),
  cash: decimalStringSchema,
  buying_power: decimalStringSchema.nullable(),
  market_value: decimalStringSchema.nullable(),
  total_equity: decimalStringSchema,
}).strict().openapi("BrokerageBalance");
const brokerageAssetSchema = z.object({
  instrument_id: uuid,
  symbol: z.string().min(1).max(32),
  name: z.string().min(1).max(160),
  asset_kind: z.enum(["equity", "etf", "unsupported"]),
  provider_asset_kind: z.string().min(1).max(128),
  supported: z.boolean(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  exchange: z.string().max(32).nullable(),
  market_timezone: z.string().min(1).max(64),
}).strict().openapi("BrokerageAsset");
const brokeragePositionSchema = z.object({
  asset: brokerageAssetSchema,
  quantity: decimalStringSchema,
  available_quantity: decimalStringSchema,
  average_cost: decimalStringSchema.nullable(),
  market_value: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/),
}).strict().openapi("BrokeragePosition");
const brokerageRestrictionSchema = z.object({
  restriction: z.enum([
    "closing_only",
    "trading_disabled",
    "liquidation_only",
    "unsupported",
  ]),
  provider_code: z.string().min(1).max(128),
  active: z.boolean(),
  detail: z.string().max(256).nullable(),
}).strict().openapi("BrokerageRestriction");

function brokerageProjectionResponseSchema(
  name: string,
  data: z.ZodType,
) {
  return z.object({
    account_id: uuid,
    resource: z.enum(["account", "balance", "positions", "restrictions"]),
    generation: z.number().int().positive().nullable(),
    state: brokerageStateSchema,
    reason: z.string().max(64).nullable(),
    provider_observed_at: z.string().datetime().nullable(),
    fetched_at: z.string().datetime().nullable(),
    expires_at: z.string().datetime().nullable(),
    data: data.nullable(),
  }).strict().openapi(name);
}

function brokerageEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: responseMetaSchema }).strict().openapi(name);
}

const memberStepUpReceiptSchema = z.object({
  receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/),
  action: z.enum(["webull_disconnect", "argus_delete"]),
  user_id: uuid,
  session_id: uuid,
  expires_at: z.string().datetime(),
}).strict().openapi("MemberStepUpReceipt");
const memberStepUpReceiptResponseSchema = brokerageEnvelope(
  "MemberStepUpReceiptResponse",
  memberStepUpReceiptSchema,
);
const webullAuthorizationSessionSchema = z.object({
  connection_id: uuid,
  authorization_url: z.string().url().refine((value) => value.startsWith("https://")),
  expires_at: z.string().datetime(),
}).strict().openapi("WebullAuthorizationSession");
const webullAuthorizationSessionResponseSchema = brokerageEnvelope(
  "WebullAuthorizationSessionResponse",
  webullAuthorizationSessionSchema,
);
const webullConnectionSchema = z.object({
  id: uuid.nullable().optional(),
  status: z.enum([
    "disconnected",
    "pending",
    "connected",
    "denied",
    "failed",
    "temporarily_unavailable",
    "reauthorization_required",
  ]),
  capability_version: z.number().int().nonnegative().nullable().optional(),
  authorized_at: z.string().datetime().nullable().optional(),
  disconnected_at: z.string().datetime().nullable().optional(),
  last_error_code: z.string().min(1).max(128).nullable().optional(),
  updated_at: z.string().datetime().nullable().optional(),
}).strict().openapi("WebullConnection");
const webullConnectionResponseSchema = brokerageEnvelope(
  "WebullConnectionResponse",
  webullConnectionSchema,
);
const webullAccountSelectionSchema = z.object({
  account_id: uuid,
  selected: z.literal(true),
}).strict().openapi("WebullAccountSelection");
const webullAccountSelectionResponseSchema = brokerageEnvelope(
  "WebullAccountSelectionResponse",
  webullAccountSelectionSchema,
);
const webullCompletionSchema = z.object({
  connection_id: uuid,
  outcome: z.enum(["connected", "denied", "failed", "temporarily_unavailable"]),
  created_at: z.string().datetime(),
}).strict().openapi("WebullCompletion");
const webullCompletionResponseSchema = brokerageEnvelope(
  "WebullCompletionResponse",
  webullCompletionSchema,
);
const webullDisconnectSchema = z.object({
  connection_id: uuid,
  status: z.literal("disconnected"),
  provider_grant_revoked: z.literal(false),
}).strict().openapi("WebullDisconnectReceipt");
const webullDisconnectResponseSchema = brokerageEnvelope(
  "WebullDisconnectResponse",
  webullDisconnectSchema,
);

const brokerageAccountsResponseSchema = brokerageEnvelope(
  "BrokerageAccountsResponse",
  z.array(brokerageAccountSchema).max(100),
);
const brokerageCapabilitiesResponseSchema = brokerageEnvelope(
  "BrokerageCapabilitiesResponse",
  brokerageProjectionResponseSchema(
    "BrokerageCapabilitiesProjection",
    brokerageAccountAuthoritySchema,
  ),
);
const brokerageBalancesResponseSchema = brokerageEnvelope(
  "BrokerageBalancesResponse",
  brokerageProjectionResponseSchema(
    "BrokerageBalancesProjection",
    brokerageBalanceSchema,
  ),
);
const brokeragePositionsResponseSchema = brokerageEnvelope(
  "BrokeragePositionsResponse",
  brokerageProjectionResponseSchema(
    "BrokeragePositionsProjection",
    z.array(brokeragePositionSchema).max(10_000),
  ),
);
const brokerageRestrictionsResponseSchema = brokerageEnvelope(
  "BrokerageRestrictionsResponse",
  brokerageProjectionResponseSchema(
    "BrokerageRestrictionsProjection",
    z.array(brokerageRestrictionSchema).max(256),
  ),
);
const brokerageOrderStateSchema = z.enum([
  "pending",
  "partially_filled",
  "filled",
  "cancelled",
  "rejected",
  "expired",
  "unknown",
]);
const brokerageOrderSchema = z.object({
  id: uuid,
  instrument_id: uuid,
  symbol: z.string().min(1).max(32),
  side: z.enum(["buy", "sell", "unsupported"]),
  provider_side: z.string().min(1).max(128),
  order_type: z.enum(["market", "limit", "stop", "stop_limit", "unsupported"]),
  provider_order_type: z.string().min(1).max(128),
  time_in_force: z.enum(["day", "gtc", "unsupported"]),
  provider_time_in_force: z.string().min(1).max(128),
  quantity: decimalStringSchema,
  filled_quantity: decimalStringSchema,
  limit_price: decimalStringSchema.nullable(),
  stop_price: decimalStringSchema.nullable(),
  average_fill_price: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  state: brokerageOrderStateSchema,
  provider_state: z.string().min(1).max(128),
  terminal: z.boolean(),
}).strict().openapi("BrokerageOrder");
const brokerageOrderDetailSchema = brokerageOrderSchema.extend({
  generation: z.number().int().positive(),
  source: z.enum(["list", "detail"]),
  provider_observed_at: z.string().datetime(),
  fetched_at: z.string().datetime(),
}).strict().openapi("BrokerageOrderDetail");
const brokerageOrdersResponseSchema = brokerageEnvelope(
  "BrokerageOrdersResponse",
  z.object({
    account_id: uuid,
    state: brokerageStateSchema,
    provider_observed_at: z.string().datetime().nullable(),
    fetched_at: z.string().datetime().nullable(),
    expires_at: z.string().datetime().nullable(),
    orders: z.array(brokerageOrderSchema).max(10_000),
  }).strict().openapi("BrokerageOrderList"),
);
const brokerageOrderDetailResponseSchema = brokerageEnvelope(
  "BrokerageOrderDetailResponse",
  brokerageOrderDetailSchema,
);
const placeOrderIntentSchema = z.object({
  instrument_id: uuid,
  side: z.enum(["buy", "sell"]),
  order_type: z.enum(["market", "limit"]),
  time_in_force: z.literal("day"),
  quantity: decimalStringSchema,
  limit_price: decimalStringSchema.nullable(),
}).strict().openapi("PlaceBrokerageOrderIntent");
const modifyOrderIntentSchema = z.object({
  quantity: decimalStringSchema,
  limit_price: decimalStringSchema.nullable(),
}).strict().openapi("ModifyBrokerageOrderIntent");
const brokerageOrderPreviewSchema = z.object({
  id: uuid,
  account_id: uuid,
  operation: z.enum(["place", "modify", "cancel"]),
  target_order_id: uuid.nullable(),
  policy_version: z.string().min(8).max(128),
  capability_version: z.number().int().nonnegative(),
  restriction_generation: z.number().int().positive(),
  reviewed_payload_hash: z.string().regex(/^[a-f0-9]{64}$/),
  estimated_total: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/).nullable(),
  expires_at: z.string().datetime(),
}).strict().openapi("BrokerageOrderPreview");
const brokerageOrderPreviewResponseSchema = brokerageEnvelope(
  "BrokerageOrderPreviewResponse",
  brokerageOrderPreviewSchema,
);
const confirmPlaceOrderSchema = z.object({
  preview_id: uuid,
  confirmed: z.literal(true),
  intent: placeOrderIntentSchema,
}).strict().openapi("ConfirmPlaceBrokerageOrder");
const confirmModifyOrderSchema = z.object({
  preview_id: uuid,
  confirmed: z.literal(true),
  intent: modifyOrderIntentSchema,
}).strict().openapi("ConfirmModifyBrokerageOrder");
const confirmCancelOrderSchema = z.object({
  preview_id: uuid,
  confirmed: z.literal(true),
}).strict().openapi("ConfirmCancelBrokerageOrder");
const brokerageCommandStateSchema = z.enum([
  "dispatching",
  "accepted",
  "ambiguous",
  "reconciling",
  "resolved",
  "failed",
  "manual_review",
]);
const brokerageOrderCommandSchema = z.object({
  id: uuid,
  account_id: uuid,
  operation: z.enum(["place", "modify", "cancel"]),
  target_order_id: uuid.nullable(),
  order_id: uuid.nullable(),
  state: brokerageCommandStateSchema,
  ambiguous: z.boolean(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
}).strict().openapi("BrokerageOrderCommand");
const brokerageOrderCommandResponseSchema = brokerageEnvelope(
  "BrokerageOrderCommandResponse",
  brokerageOrderCommandSchema,
);
const brokerageOrderReconciliationResponseSchema = brokerageEnvelope(
  "BrokerageOrderReconciliationResponse",
  z.object({
    command: brokerageOrderCommandSchema,
    status: z.enum([
      "pending",
      "running",
      "resolved",
      "manual_review",
      "exhausted",
    ])
      .nullable(),
    attempts: z.number().int().nonnegative(),
    next_attempt_at: z.string().datetime().nullable(),
    last_error_code: z.string().max(64).nullable(),
    egress_started_at: z.string().datetime(),
  }).strict().openapi("BrokerageOrderReconciliation"),
);
const errorSchema = z
  .object({
    error: z
      .object({
        code: z.string(),
        message: z.string(),
        request_id: uuid,
        field_errors: z.array(z.unknown()),
        retryable: z.boolean(),
      })
      .strict(),
  })
  .strict();
const idempotencyKey = z.string().min(16).max(64).regex(/^[\x21-\x7E]+$/);
const scenarioIdempotencyHeaders = z.object({
  "idempotency-key": idempotencyKey,
});
const scenarioVersionHeaders = z.object({
  "if-match": z.string().regex(/^"v[1-9]\d*"$/),
});
const scenarioIntentionPath = z.object({ intention_id: uuid }).strict();
const scenarioRunPath = z.object({ intention_id: uuid, run_id: uuid }).strict();
const scenarioLimit = z.coerce.number().int().min(1).max(50).default(25);

function scenarioEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: responseMetaSchema }).strict().openapi(name);
}

const intentionResponseSchema = scenarioEnvelope(
  "MemberIntentionResponse",
  intentionSchema,
);
const intentionPageResponseSchema = scenarioEnvelope(
  "MemberIntentionPageResponse",
  intentionPageSchema,
);
const futureMirrorResponseSchema = scenarioEnvelope(
  "HypotheticalFutureMirrorResponse",
  futureMirrorSchema,
);

class HttpBoundaryError extends Error {
  readonly status: 400 | 401 | 403 | 404 | 409 | 413 | 415 | 422 | 429 | 503;
  readonly code: string;
  readonly publicMessage: string;
  readonly retryable: boolean;
  readonly retryAfterSeconds: number | undefined;

  constructor(
    status: 400 | 401 | 403 | 404 | 409 | 413 | 415 | 422 | 429 | 503,
    code: string,
    publicMessage: string,
    retryable = false,
    retryAfterSeconds?: number,
  ) {
    super(code);
    this.status = status;
    this.code = code;
    this.publicMessage = publicMessage;
    this.retryable = retryable;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function errorResponse(
  context: Context<RetainedAppEnvironment>,
  error: HttpBoundaryError,
): Response {
  const headers = error.retryAfterSeconds === undefined
    ? undefined
    : { "retry-after": String(error.retryAfterSeconds) };
  return context.json(
    {
      error: {
        code: error.code,
        message: error.publicMessage,
        request_id: context.get("requestId"),
        field_errors: [],
        retryable: error.retryable,
      },
    },
    error.status,
    headers,
  );
}

function bearerToken(value: string | undefined): string | null {
  if (value === undefined || value.length > 16_391) return null;
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(value);
  return match?.[1] ?? null;
}

function claimsFrom(
  principal: VerifiedSupabasePrincipal,
): VerifiedRequestClaims {
  return Object.freeze({
    userId: uuid.parse(principal.userId),
    sessionId: uuid.parse(principal.sessionId),
    aal: principal.aal,
  });
}

async function digest(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)]
    .map((entry) => entry.toString(16).padStart(2, "0"))
    .join("");
}

function normalizedRoute(path: string): string {
  return path
    .replace(
      /[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi,
      "{id}",
    )
    .slice(0, 256);
}

async function parseBody<T>(
  context: Context<RetainedAppEnvironment>,
  schema: z.ZodType<T>,
): Promise<T> {
  try {
    // @hono/zod-openapi validates and consumes JSON before invoking the
    // handler. Reuse that boundary result rather than attempting to read the
    // request stream a second time.
    return schema.parse(context.req.valid("json" as never));
  } catch {
    throw new HttpBoundaryError(
      422,
      "validation_failed",
      "The request body failed validation.",
    );
  }
}

async function rejectBody(context: Context<RetainedAppEnvironment>) {
  if (
    context.req.raw.body !== null &&
    context.req.header("content-length") !== "0" &&
    (await context.req.raw.text()).length > 0
  ) {
    throw new HttpBoundaryError(
      422,
      "validation_failed",
      "This operation does not accept a request body.",
    );
  }
}

function expectedVersion(context: Context<RetainedAppEnvironment>): number {
  const match = /^"v([1-9]\d*)"$/.exec(context.req.header("if-match") ?? "");
  if (match === null) {
    throw new HttpBoundaryError(
      422,
      "invalid_if_match",
      "If-Match must contain the current version ETag.",
    );
  }
  return Number(match[1]);
}

function dataResponse(
  context: Context<RetainedAppEnvironment>,
  data: unknown,
): Response {
  if (data === null || data === undefined) {
    throw new HttpBoundaryError(
      404,
      "not_found",
      "The requested resource was not found.",
    );
  }
  const version = typeof data === "object" &&
      data !== null &&
      "version" in data &&
      Number.isInteger((data as { version?: unknown }).version)
    ? Number((data as { version: number }).version)
    : undefined;
  if (version !== undefined) context.header("etag", `"v${version}"`);
  return context.json(
    { data, meta: { request_id: context.get("requestId") } },
    200,
  );
}

function collectionDataResponse(
  context: Context<RetainedAppEnvironment>,
  data: unknown,
  nextCursor: string | null = null,
): Response {
  return context.json(
    {
      data,
      meta: {
        request_id: context.get("requestId"),
        next_cursor: nextCursor,
        has_more: nextCursor !== null,
      },
    },
    200,
  );
}

function contentRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function contentString(
  value: Record<string, unknown>,
  key: string,
  fallback: string,
): string {
  const candidate = value[key];
  return typeof candidate === "string" && candidate.trim().length > 0
    ? candidate
    : fallback;
}

function contentNullableString(
  value: Record<string, unknown>,
  key: string,
): string | null {
  const candidate = value[key];
  return typeof candidate === "string" && candidate.trim().length > 0
    ? candidate
    : null;
}

function timestampString(value: unknown): string | null {
  if (value instanceof Date) {
    return value.toJSON();
  }
  return typeof value === "string" &&
      value.trim().length > 0 &&
      !Number.isNaN(Date.parse(value))
    ? value
    : null;
}

function contentTimestamp(
  value: Record<string, unknown>,
  key: string,
  fallback: string,
): string {
  return contentNullableTimestamp(value, key) ?? fallback;
}

function contentNullableTimestamp(
  value: Record<string, unknown>,
  key: string,
): string | null {
  return timestampString(value[key]);
}

function contentArray(value: Record<string, unknown>, key: string): unknown[] {
  const candidate = value[key];
  return Array.isArray(candidate) ? candidate : [];
}

function contentInteger(
  value: Record<string, unknown>,
  key: string,
  fallback: number,
): number {
  const candidate = value[key];
  return typeof candidate === "number" && Number.isSafeInteger(candidate)
    ? candidate
    : fallback;
}

const EPOCH_ISO = new Date(0).toISOString();

function researchDisclosure(
  observedAt: unknown,
): Record<string, unknown> {
  const timestamp = timestampString(observedAt);
  return {
    is_demo: false,
    observed_at: timestamp === null
      ? EPOCH_ISO
      : new Date(timestamp).toISOString(),
    source_label: "Argus editorial",
    limitations: [
      "Editorial research is informational and is not brokerage authority.",
    ],
  };
}

function presentEvidenceSummary(value: unknown): Record<string, unknown> {
  const claim = contentRecord(value);
  return {
    claim_id: contentString(claim, "claim_id", contentString(claim, "id", "")),
    factor_label: contentString(claim, "factor_label", contentString(claim, "claim_type", "Research evidence")),
    summary: contentString(claim, "summary", "Evidence summary unavailable."),
    observed_at: contentTimestamp(claim, "observed_at", EPOCH_ISO),
    uncertainty: contentString(claim, "uncertainty", "Uncertainty not specified."),
  };
}

function presentEvidenceDetail(value: unknown): Record<string, unknown> {
  const claim = contentRecord(value);
  const source = contentRecord(claim.source);
  const candidateUrl = contentNullableString(source, "canonical_url");
  const url = candidateUrl !== null && candidateUrl.startsWith("https://")
    ? candidateUrl
    : null;
  return {
    ...presentEvidenceSummary(claim),
    source: {
      title: contentString(source, "title", "Source"),
      publisher: contentString(source, "publisher", "Unknown publisher"),
      url,
      published_at: contentNullableTimestamp(source, "published_at"),
    },
  };
}

function presentAssetSummary(value: unknown): Record<string, unknown> {
  const asset = contentRecord(value);
  const payload = contentRecord(asset.payload);
  return {
    id: asset.id,
    slug: asset.slug,
    symbol: asset.symbol,
    name: asset.name,
    asset_type: asset.asset_type === "index" ? "market_index" : asset.asset_type,
    currency: asset.currency,
    revision_id: asset.revision_id,
    appearance_reason: contentString(
      payload,
      "appearance_reason",
      "Included in the current Argus editorial catalog.",
    ),
    demo: researchDisclosure(asset.revision_created_at),
  };
}

function presentAssetDetail(value: unknown): Record<string, unknown> {
  const asset = contentRecord(value);
  const payload = contentRecord(asset.payload);
  return {
    ...presentAssetSummary(asset),
    thesis: contentString(payload, "thesis", "Editorial thesis unavailable."),
    limitations: contentString(
      payload,
      "limitations",
      "Review the cited evidence and current brokerage information.",
    ),
    metrics_as_of: timestampString(payload.metrics_as_of) ??
      timestampString(asset.revision_created_at) ?? EPOCH_ISO,
    evidence: contentArray(payload, "evidence").map(presentEvidenceSummary),
    risks: contentArray(payload, "risks").map((entry) => {
      const risk = contentRecord(entry);
      return {
        title: contentString(risk, "title", "Risk"),
        detail: contentString(risk, "detail", "Risk detail unavailable."),
        severity: ["low", "medium", "high"].includes(String(risk.severity))
          ? risk.severity
          : "medium",
      };
    }),
    saved: asset.saved === true,
  };
}

function presentAssetMetric(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const metric = contentRecord(row.metric ?? value);
  return {
    observed_at: contentTimestamp(metric, "observed_at", EPOCH_ISO),
    price_minor: Math.max(0, contentInteger(metric, "price_minor", 0)),
    change_bps: metric.change_bps === null
      ? null
      : contentInteger(metric, "change_bps", 0),
    expense_ratio_bps: metric.expense_ratio_bps === null
      ? null
      : Math.max(0, contentInteger(metric, "expense_ratio_bps", 0)),
    source_label: contentString(metric, "source_label", "Argus editorial"),
    demo: researchDisclosure(metric.observed_at),
  };
}

function presentBriefingSummary(value: unknown): Record<string, unknown> {
  const briefing = contentRecord(value);
  return {
    id: briefing.id,
    briefing_type: briefing.briefing_type,
    period_start: briefing.period_start,
    period_end: briefing.period_end,
    generated_at: contentTimestamp(
      briefing,
      "generated_at",
      EPOCH_ISO,
    ),
    generation: Math.max(1, contentInteger(briefing, "generation", 1)),
    source_sequence: Math.max(
      1,
      contentInteger(briefing, "source_sequence", 1),
    ),
    read_at: contentNullableTimestamp(briefing, "read_at"),
  };
}

function presentBriefingDetail(value: unknown): Record<string, unknown> {
  const briefing = contentRecord(value);
  return {
    ...presentBriefingSummary(briefing),
    sections: contentArray(briefing, "sections").map((entry, index) => {
      const section = contentRecord(entry);
      const payload = contentRecord(section.payload);
      return {
        ordinal: Math.max(1, contentInteger(section, "ordinal", index + 1)),
        source_sequence: Math.max(
          1,
          contentInteger(payload, "source_sequence", contentInteger(briefing, "source_sequence", 1)),
        ),
        schema_version: Math.max(1, contentInteger(payload, "schema_version", 1)),
        disclosure: contentString(
          payload,
          "disclosure",
          contentString(payload, "summary", "Reviewed Argus briefing section."),
        ),
      };
    }),
  };
}

function presentCircleTemplate(value: unknown): Record<string, unknown> {
  const template = contentRecord(value);
  const payload = contentRecord(template.payload);
  const observedAt = template.revision_created_at;
  const creatorLabel = contentString(template, "creator_label", "Argus editor");
  return {
    id: template.id,
    revision_id: template.revision_id,
    slug: template.slug,
    title: template.title,
    description: template.description,
    theme: contentString(payload, "theme", contentString(template, "theme_code", "research")),
    creator: {
      id: template.id,
      slug: contentString(
        payload,
        "creator_slug",
        String(template.slug ?? "creator"),
      ),
      display_name: creatorLabel,
      bio: contentString(payload, "creator_bio", "Fictional Argus editorial creator."),
      is_fictional: true,
      demo: researchDisclosure(observedAt),
    },
    assets: contentArray(template, "assets").map((entry) => {
      const asset = contentRecord(entry);
      return {
        ...presentAssetSummary(asset),
        ordinal: Math.max(1, contentInteger(asset, "ordinal", 1)),
        weight_bps: typeof asset.weight_bps === "number" ? asset.weight_bps : null,
        note: contentNullableString(asset, "note"),
      };
    }),
    saved: template.saved === true,
    demo: researchDisclosure(observedAt),
  };
}

function contentDate(value: unknown, fallback = "1970-01-01"): string {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}/.test(value)
    ? value.slice(0, 10)
    : fallback;
}

function presentCovenSummary(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  const company = contentRecord(row.company);
  const qualifications = contentArray(row, "qualification_payload");
  const firstQualification = contentRecord(qualifications[0]);
  const category = contentString(
    payload,
    "category",
    contentString(firstQualification, "category", "founder"),
  );
  const observed = row.revision_created_at;
  return {
    id: row.id,
    revision_id: row.revision_id,
    slug: row.slug,
    company: contentString(company, "name", "Company"),
    symbol: contentNullableString(row, "symbol"),
    category: ["founder", "owner", "chief_executive"].includes(category)
      ? category
      : "founder",
    focus: contentString(payload, "focus", "Long-term company research"),
    teaser: contentString(payload, "teaser", contentString(payload, "summary", "Argus company research.")),
    effective_date: contentDate(payload.effective_date, contentDate(observed)),
    verified_as_of: contentDate(payload.verified_as_of, contentDate(observed)),
    demo: researchDisclosure(observed),
  };
}

function evidenceClaimIds(value: unknown): string[] {
  const collected = new Set<string>();
  const visit = (candidate: unknown, key?: string): void => {
    if (Array.isArray(candidate)) {
      for (const entry of candidate) visit(entry, key);
      return;
    }
    if (typeof candidate !== "object" || candidate === null) {
      if (
        typeof candidate === "string" &&
        (key === "evidence_claim_ids" || key === "claim_id") &&
        uuid.safeParse(candidate).success
      ) {
        collected.add(candidate);
      }
      return;
    }
    for (const [childKey, child] of Object.entries(candidate)) {
      visit(child, childKey);
    }
  };
  visit(value);
  return [...collected];
}

function presentCovenDetail(
  value: unknown,
  evidenceValues: readonly unknown[] = [],
): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  const observed = row.revision_created_at;
  const evidenceById = new Map(
    evidenceValues.map((entry) => {
      const evidence = contentRecord(entry);
      return [String(evidence.id ?? evidence.claim_id ?? ""), evidence] as const;
    }),
  );
  const evidence = [...evidenceById.values()].map(presentEvidenceDetail);
  return {
    ...presentCovenSummary(row),
    summary: contentString(payload, "summary", "Argus company research."),
    inclusion_rationale: contentString(
      payload,
      "inclusion_rationale",
      "Included under the published Argus editorial criteria.",
    ),
    limitations: contentString(
      payload,
      "limitations",
      "Editorial qualification evidence can change over time.",
    ),
    qualifications: contentArray(row, "qualification_payload").map((entry) => {
      const qualification = contentRecord(entry);
      const category = contentString(qualification, "category", "founder");
      const qualificationEvidence = evidenceClaimIds(qualification)
        .map((claimId) => evidenceById.get(claimId))
        .filter((claim): claim is Record<string, unknown> => claim !== undefined)
        .map(presentEvidenceSummary);
      return {
        category: ["founder", "owner", "chief_executive"].includes(category)
          ? category
          : "founder",
        person_name: contentString(qualification, "person_name", "Published qualification"),
        effective_date: contentDate(qualification.effective_date, contentDate(observed)),
        valid_to: qualification.valid_to == null ? null : contentDate(qualification.valid_to),
        verified_as_of: contentDate(qualification.verified_as_of, contentDate(observed)),
        evidence: qualificationEvidence.length > 0
          ? qualificationEvidence
          : contentArray(qualification, "evidence").map(presentEvidenceSummary),
      };
    }),
    evidence: evidence.length > 0
      ? evidence
      : contentArray(payload, "evidence").map(presentEvidenceDetail),
    saved: row.saved === true,
  };
}

function presentGrimoireSummary(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  return {
    id: row.id,
    revision_id: row.revision_id,
    slug: row.slug,
    title: contentString(payload, "title", String(row.slug ?? "Grimoire")),
    description: contentString(payload, "description", "Published Argus research collection."),
    theme: contentString(payload, "theme", contentString(row, "theme_code", "research")),
    curator_label: contentString(payload, "curator_label", "Argus editorial"),
    demo: researchDisclosure(row.revision_created_at),
  };
}

function presentGrimoireDetail(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  return {
    ...presentGrimoireSummary(row),
    assets: contentArray(row, "assets").map(presentAssetSummary),
    saved: row.saved === true,
  };
}

function presentCircleTemplateSummary(value: unknown): Record<string, unknown> {
  const detail = presentCircleTemplate(value);
  const { assets: _assets, saved: _saved, ...summary } = detail;
  return summary;
}

function presentCreator(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  return {
    id: row.id,
    slug: contentString(payload, "creator_slug", String(row.slug ?? "creator")),
    display_name: contentString(row, "creator_label", "Argus editor"),
    bio: contentString(payload, "creator_bio", "Fictional Argus editorial creator."),
    is_fictional: true,
    demo: researchDisclosure(row.revision_created_at),
  };
}

function matchesPublishedSearch(value: Record<string, unknown>, query: string): boolean {
  const normalized = query.trim().toLocaleLowerCase("en-US");
  return ["slug", "symbol", "name", "title", "description", "company", "focus", "teaser"]
    .some((key) => {
      const candidate = value[key];
      return typeof candidate === "string" &&
        candidate.toLocaleLowerCase("en-US").includes(normalized);
    });
}

type RouteOptions = Readonly<{
  public?: boolean;
  body?: z.ZodType;
  optionalBody?: boolean;
  pathParams?: z.ZodType;
  query?: z.ZodType;
  headers?: z.ZodType;
  description?: string;
  response?: z.ZodType;
  acceptedResponse?: z.ZodType;
}>;

type RouteAccess = Readonly<{ isPublic: boolean; isAdmin: boolean }>;
const routeAccess = new WeakMap<object, RouteAccess>();

function route(
  method: "get" | "post" | "put" | "patch" | "delete",
  path: string,
  operationId: string,
  tag: string,
  options: RouteOptions = {},
) {
  const request: Record<string, unknown> = {};
  if (options.pathParams !== undefined) request.params = options.pathParams;
  if (options.query !== undefined) request.query = options.query;
  if (options.headers !== undefined) request.headers = options.headers;
  if (options.body !== undefined) {
    request.body = {
      required: options.optionalBody !== true,
      content: { "application/json": { schema: options.body } },
    };
  }
  const definition = createRoute({
    method,
    path,
    operationId,
    tags: [tag],
    security: options.public === true ? [] : [{ SupabaseBearer: [] }],
    ...(Object.keys(request).length === 0 ? {} : { request }),
    responses: {
      200: {
        description: options.description ?? "Argus response.",
        content: {
          "application/json": { schema: options.response ?? responseSchema },
        },
      },
      ...(options.acceptedResponse === undefined
        ? {}
        : {
          202: {
            description: "The requested resource is still being prepared.",
            content: {
              "application/json": { schema: options.acceptedResponse },
            },
          },
        }),
      401: {
        description: "Invalid Supabase access token.",
        content: { "application/json": { schema: errorSchema } },
      },
      403: {
        description: "Owner or current staff authorization denied.",
        content: { "application/json": { schema: errorSchema } },
      },
      409: {
        description: "Revision or idempotency conflict.",
        content: { "application/json": { schema: errorSchema } },
      },
      422: {
        description: "Strict request validation failed.",
        content: { "application/json": { schema: errorSchema } },
      },
      429: {
        description: "Rate limited.",
        content: { "application/json": { schema: errorSchema } },
      },
      503: {
        description: "A required private dependency is unavailable.",
        content: { "application/json": { schema: errorSchema } },
      },
    },
  } as RouteConfig);
  routeAccess.set(definition, {
    isPublic: options.public === true,
    isAdmin: path.startsWith("/v1/admin/"),
  });
  return definition;
}

function query(context: Context<RetainedAppEnvironment>) {
  return Object.fromEntries(new URL(context.req.url).searchParams.entries());
}

function repositories(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
) {
  return options.createRepositories(context.get("claims"));
}

function brokerageConnections(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
): BrokerageConnectionRepository {
  const factory = options.createBrokerageConnections;
  if (factory === undefined) {
    throw new HttpBoundaryError(
      503,
      "webull_contract_unavailable",
      "Webull connection is temporarily unavailable.",
      true,
    );
  }
  return factory(context.get("claims"));
}

function brokerageProjections(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
): BrokerageProjectionService {
  const factory = options.createBrokerageProjections;
  if (factory === undefined) {
    throw new HttpBoundaryError(
      503,
      "brokerage_reads_unavailable",
      "Brokerage data is temporarily unavailable.",
      true,
    );
  }
  return factory(context.get("claims"));
}

function brokerageOrders(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
): BrokerageOrderService {
  const factory = options.createBrokerageOrders;
  if (factory === undefined) {
    throw new HttpBoundaryError(
      503,
      "brokerage_orders_unavailable",
      "Brokerage orders are temporarily unavailable.",
      true,
    );
  }
  return factory(context.get("claims"));
}

export function buildRetainedOpenApiDocument(
  app: OpenAPIHono<RetainedAppEnvironment>,
) {
  const document = app.getOpenAPIDocument({
    openapi: "3.0.3",
    info: {
      title: "Argus API",
      version: "2.0.0",
      description:
        "Supabase Edge contract for Argus-owned member, editorial, privacy, and staff data. Brokerage routes are added only after the Webull protocol gate.",
    },
    servers: [
      { url: "https://PROJECT_REF.supabase.co/functions/v1/api" },
    ],
  });
  document.components = {
    ...document.components,
    securitySchemes: {
      SupabaseBearer: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
        description:
          "Supabase Auth access token verified by signature, issuer, audience, expiry, session, role, and AAL at the Edge boundary.",
      },
    },
  };
  return document;
}

export function createRetainedApp(options: CreateRetainedAppOptions) {
  const app = new OpenAPIHono<RetainedAppEnvironment>({
    defaultHook: (result) => {
      if (!result.success) {
        throw new HttpBoundaryError(
          422,
          "validation_failed",
          "The request failed validation.",
        );
      }
    },
  });

  const requestContext: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const incoming = context.req.header("x-request-id");
    const requestId = incoming !== undefined && requestIdPattern.test(incoming)
      ? incoming
      : (options.requestId?.() ?? crypto.randomUUID());
    context.set("requestId", requestId);
    context.header("x-request-id", requestId);
    const startedAt = performance.now();
    await next();
    context.header("x-content-type-options", "nosniff");
    context.header("x-frame-options", "DENY");
    context.header("referrer-policy", "no-referrer");
    if (context.req.header("authorization") !== undefined) {
      context.header("cache-control", "private, no-store");
    }
    try {
      await options.telemetry?.({
        event: "http.request",
        requestId,
        method: context.req.method,
        route: normalizedRoute(context.req.path),
        status: context.res.status,
        latencyMs: Math.round(performance.now() - startedAt),
      });
    } catch {
      // Telemetry is deliberately best-effort. A failed sink must never replace
      // an already-computed response or expose sink details to the caller.
    }
  };
  app.use("*", requestContext);

  const exactOriginCors: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const origin = context.req.header("origin");
    const expectedOrigin = context.req.path.startsWith("/v1/admin/")
      ? context.env.adminOrigin
      : context.env.consumerOrigin;
    if (origin !== undefined && origin !== expectedOrigin) {
      throw new HttpBoundaryError(
        403,
        "origin_denied",
        "The request origin is not allowed.",
      );
    }
    if (origin === expectedOrigin) {
      context.header("access-control-allow-origin", expectedOrigin);
      context.header(
        "access-control-allow-methods",
        "GET, POST, PUT, PATCH, DELETE, OPTIONS",
      );
      context.header(
        "access-control-allow-headers",
        "authorization, content-type, if-match, idempotency-key, x-request-id",
      );
      context.header(
        "access-control-expose-headers",
        "etag, retry-after, x-request-id",
      );
      context.header("access-control-max-age", "600");
      context.header("vary", "origin");
    }
    if (context.req.method === "OPTIONS") {
      context.res = context.body(null, 204);
      return;
    }
    await next();
  };
  app.use("*", exactOriginCors);

  const enforceJsonBoundary: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    if (context.req.raw.body !== null) {
      const declaredSize = Number(context.req.header("content-length"));
      if (Number.isFinite(declaredSize) && declaredSize > 65_536) {
        throw new HttpBoundaryError(
          413,
          "payload_too_large",
          "The request body exceeds the allowed size.",
        );
      }
      const copy = await context.req.raw.clone().arrayBuffer();
      if (copy.byteLength > 65_536) {
        throw new HttpBoundaryError(
          413,
          "payload_too_large",
          "The request body exceeds the allowed size.",
        );
      }
      if (copy.byteLength > 0) {
        const contentType = context.req.header("content-type")
          ?.split(";", 1)[0]
          ?.trim()
          .toLowerCase();
        if (contentType !== "application/json") {
          throw new HttpBoundaryError(
            415,
            "unsupported_media_type",
            "JSON requests require application/json.",
          );
        }
      }
    }
    await next();
  };
  app.use("*", enforceJsonBoundary);

  const authenticate: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const token = bearerToken(context.req.header("authorization"));
    if (token === null) {
      throw new HttpBoundaryError(
        401,
        "unauthorized",
        "A valid Supabase access token is required.",
      );
    }
    try {
      const principal = Object.freeze(await options.verifyAccessToken(token));
      context.set("principal", principal);
      context.set("claims", claimsFrom(principal));
    } catch {
      throw new HttpBoundaryError(
        401,
        "unauthorized",
        "A valid Supabase access token is required.",
      );
    }
    await next();
  };

  const enforceRateLimit: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const principal = context.get("principal");
    const scope = await digest(
      [
        principal?.userId ?? "public",
        context.req.method,
        normalizedRoute(context.req.path),
      ].join("\u001f"),
    );
    try {
      const outcome = await options.rateLimit.allow(scope, {
        limit: principal === undefined ? 120 : 240,
        windowSeconds: 60,
      });
      if (!outcome.allowed) {
        throw new HttpBoundaryError(
          429,
          "rate_limited",
          "The request rate limit was exceeded.",
          true,
          outcome.retryAfterSeconds ?? 60,
        );
      }
    } catch (error) {
      if (error instanceof HttpBoundaryError) throw error;
      throw new HttpBoundaryError(
        503,
        "service_unavailable",
        "The request rate limit could not be checked.",
        true,
      );
    }
    await next();
  };

  const requireAal2: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    if (context.get("principal")?.aal !== "aal2") {
      throw new HttpBoundaryError(
        403,
        "aal2_required",
        "A current AAL2 staff session is required.",
      );
    }
    await next();
  };

  app.onError((error, context) => {
    if (error instanceof HttpBoundaryError) {
      return errorResponse(context, error);
    }
    if (error instanceof RepositoryNotFoundError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          404,
          "not_found",
          "The requested resource was not found.",
        ),
      );
    }
    if (error instanceof RepositoryRevisionConflictError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          409,
          "revision_conflict",
          "The resource changed. Refresh before retrying.",
        ),
      );
    }
    if (error instanceof RepositoryStepUpRequiredError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          403,
          "step_up_required",
          "A current action-bound authorization is required.",
        ),
      );
    }
    if (error instanceof ScenarioConflictError) {
      const invalid = error.code === "invalid_scenario_input" ||
        error.code === "invalid_scenario_horizon" ||
        error.code === "scenario_value_too_large";
      return errorResponse(
        context,
        new HttpBoundaryError(
          invalid ? 422 : 409,
          error.code,
          invalid
            ? "The reviewed hypothetical scenario assumptions are invalid."
            : "The idempotency key conflicts with an earlier reviewed request.",
        ),
      );
    }
    if (error instanceof StaffAuthorizationError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          403,
          "forbidden",
          "Current staff authorization is required.",
        ),
      );
    }
    if (error instanceof BrokerageConnectionError) {
      const stepUp = error.code === "step_up_required";
      const conflict = error.code === "connection_already_connected";
      return errorResponse(
        context,
        new HttpBoundaryError(
          stepUp ? 403 : conflict ? 409 : 404,
          error.code,
          stepUp
            ? "A current action-bound authorization is required."
            : conflict
            ? "The Webull connection already exists."
            : "The requested brokerage resource was not found.",
        ),
      );
    }
    if (error instanceof BrokerageProjectionError) {
      const notFound = error.code === "account_not_found";
      return errorResponse(
        context,
        new HttpBoundaryError(
          notFound ? 404 : 503,
          notFound ? "account_not_found" : "brokerage_reads_unavailable",
          notFound
            ? "The requested brokerage resource was not found."
            : "Brokerage data is temporarily unavailable.",
          !notFound,
        ),
      );
    }
    if (error instanceof BrokerageOrderError) {
      const notFound = [
        "account_not_found",
        "order_not_found",
        "command_not_found",
      ]
        .includes(error.code);
      const conflict = [
        "idempotency_conflict",
        "account_command_blocked",
        "preview_replayed",
        "preview_mismatch",
      ].includes(error.code);
      const unavailable = error.code === "provider_contract_unavailable";
      return errorResponse(
        context,
        new HttpBoundaryError(
          notFound ? 404 : conflict ? 409 : unavailable ? 503 : 422,
          error.code,
          notFound
            ? "The requested brokerage order resource was not found."
            : conflict
            ? "The financial command conflicts with existing or reviewed state."
            : unavailable
            ? "Brokerage order execution is temporarily unavailable."
            : "Current brokerage authority does not permit this order action.",
          unavailable,
        ),
      );
    }
    return errorResponse(
      context,
      new HttpBoundaryError(
        503,
        "service_unavailable",
        "The request could not be completed.",
        true,
      ),
    );
  });
  app.notFound((context) =>
    errorResponse(
      context,
      new HttpBoundaryError(
        404,
        "not_found",
        "The requested resource was not found.",
      ),
    )
  );

  const middlewareByPath = new Map<string, RouteAccess>();
  const register = (
    definition: ReturnType<typeof route>,
    handler: (
      context: Context<RetainedAppEnvironment>,
    ) => Response | Promise<Response>,
  ) => {
    const routingPath = definition.getRoutingPath();
    const access = routeAccess.get(definition);
    if (access === undefined || (access.isPublic && access.isAdmin)) {
      throw new Error("invalid_route_access_classification");
    }
    const existingAccess = middlewareByPath.get(routingPath);
    if (existingAccess !== undefined) {
      if (
        existingAccess.isPublic !== access.isPublic ||
        existingAccess.isAdmin !== access.isAdmin
      ) {
        throw new Error("inconsistent_route_access_classification");
      }
    } else {
      if (!access.isPublic) app.use(routingPath, authenticate);
      if (access.isAdmin) app.use(routingPath, requireAal2);
      app.use(routingPath, enforceRateLimit);
      middlewareByPath.set(routingPath, access);
    }
    app.openapi(definition as never, handler as never);
  };

  const health = route("get", "/v1/health/live", "getLiveHealth", "Platform", {
    public: true,
  });
  register(
    health,
    (context) =>
      dataResponse(context, {
        status: "ok",
        build_revision: context.env.buildRevision,
      }),
  );

  const openapi = route(
    "get",
    "/v1/openapi.json",
    "getOpenApiDocument",
    "Platform",
    { public: true },
  );
  let serializedContract: Promise<{ body: string; etag: string }> | undefined;
  register(
    openapi,
    async (context) => {
      serializedContract ??= (async () => {
        const body = JSON.stringify(buildRetainedOpenApiDocument(app));
        return {
          body,
          etag: `"openapi-${(await digest(body)).slice(0, 24)}"`,
        };
      })();
      const contract = await serializedContract;
      context.header("etag", contract.etag);
      context.header("cache-control", "public, max-age=300");
      if (context.req.header("if-none-match") === contract.etag) {
        return context.body(null, 304);
      }
      return context.body(contract.body, 200, {
        "content-type": "application/json; charset=UTF-8",
      });
    },
  );

  const bodylessBootstrap = route(
    "post",
    "/v1/session/bootstrap",
    "bootstrapSession",
    "Session",
    { response: sessionBootstrapResponseSchema },
  );
  register(bodylessBootstrap, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await repositories(context, options).session.bootstrap(),
    );
  });
  const onboardingFinalizeBody = z.object({
    schema_version: z.number().int().min(2).max(2),
    expected_onboarding_version: z.number().int().positive(),
    investing: z.object({
      experience: z.enum(["new", "some_experience", "experienced"]),
      goal_type: z.enum(["calm_fund", "long_term_growth", "income", "exploration"]),
      time_horizon: z.enum(["short", "medium", "long"]),
      risk_comfort: z.enum(["low", "moderate", "high"]),
      contribution_rhythm: z.enum(["weekly", "biweekly", "monthly", "irregular", "not_sure"]),
    }).strict(),
    ritual: z.object({
      familiarity: z.enum(["new", "curious", "familiar", "practiced", "prefer_not_to_say"]),
      language_preference: z.enum(["practical", "balanced", "mystical", "prefer_not_to_say"]),
      interests: z.array(
        z.string().regex(/^(practical_research|tarot|astrology|moon_cycles|reflection)$/),
      ).min(1).max(5),
    }).strict(),
    astrology: z.object({
      enabled: z.boolean(),
      birth_date: z.string().date().optional(),
    }).strict().superRefine((value, issue) => {
      if (value.enabled !== (value.birth_date !== undefined)) {
        issue.addIssue({ code: "custom", path: ["birth_date"], message: "birth_date must match astrology opt-in" });
      }
    }),
    consents: z.object({
      terms: z.object({ policy_version: z.string().min(1).max(40), decision: z.literal("accepted") }).strict(),
      privacy: z.object({ policy_version: z.string().min(1).max(40), decision: z.literal("accepted") }).strict(),
      demo_disclosure: z.object({ policy_version: z.string().min(1).max(40), decision: z.literal("accepted") }).strict(),
      astrology: z.object({ policy_version: z.string().min(1).max(40), decision: z.enum(["accepted", "declined"]) }).strict(),
    }).strict(),
  }).strict().openapi("FinalizeOnboardingRequest");
  const finalizeOnboarding = route(
    "post",
    "/v1/session/onboarding/finalize",
    "finalizeOnboarding",
    "Session",
    {
      body: onboardingFinalizeBody,
      headers: z.object({ "idempotency-key": idempotencyKey }),
      response: sessionBootstrapResponseSchema,
    },
  );
  register(finalizeOnboarding, async (context) => {
    const input = await parseBody(context, onboardingFinalizeBody);
    return dataResponse(
      context,
      await repositories(context, options).session.finalizeOnboarding(
        {
          expectedOnboardingVersion: input.expected_onboarding_version,
          investing: {
            goalType: input.investing.goal_type,
            timeHorizon: input.investing.time_horizon,
            riskComfort: input.investing.risk_comfort,
          },
          astrology: {
            enabled: input.astrology.enabled,
            ...(input.astrology.birth_date === undefined ? {} : { birthDate: input.astrology.birth_date }),
          },
          consents: Object.fromEntries(
            Object.entries(input.consents).map(([policyCode, consent]) => [
              policyCode,
              { policyVersion: consent.policy_version, decision: consent.decision },
            ]),
          ),
        },
        idempotencyKey.parse(context.req.header("idempotency-key")),
      ),
    );
  });

  const stepUpBody = z.object({
    action: z.enum(["webull_disconnect", "argus_delete"]),
  }).strict();
  const issueStepUp = route(
    "post",
    "/v1/member/step-up",
    "issueMemberStepUp",
    "Member Security",
    { body: stepUpBody, response: memberStepUpReceiptResponseSchema },
  );
  register(issueStepUp, async (context) => {
    const authenticatedAt = context.get("principal").authenticatedAt;
    const currentSeconds = Math.floor(Date.now() / 1_000);
    if (
      authenticatedAt === undefined ||
      authenticatedAt > currentSeconds + 30 ||
      currentSeconds - authenticatedAt > 300
    ) {
      throw new HttpBoundaryError(
        403,
        "recent_auth_required",
        "Recent authentication is required.",
      );
    }
    const input = await parseBody(context, stepUpBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).issueStepUp(input.action),
    );
  });

  const connectionStartBody = z.object({
    return_target: z.enum(["webull_https", "webull_native"]),
  }).strict();
  const startConnection = route(
    "post",
    "/v1/brokerage/connections/start",
    "startWebullConnection",
    "Brokerage Connections",
    { body: connectionStartBody, response: webullAuthorizationSessionResponseSchema },
  );
  register(startConnection, async (context) => {
    const input = await parseBody(context, connectionStartBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).start(input.return_target),
    );
  });

  const reconnect = route(
    "post",
    "/v1/brokerage/connections/reconnect",
    "reconnectWebullConnection",
    "Brokerage Connections",
    { body: connectionStartBody, response: webullAuthorizationSessionResponseSchema },
  );
  register(reconnect, async (context) => {
    const input = await parseBody(context, connectionStartBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).reconnect(
        input.return_target,
      ),
    );
  });

  const getConnection = route(
    "get",
    "/v1/brokerage/connection",
    "getWebullConnection",
    "Brokerage Connections",
    { response: webullConnectionResponseSchema },
  );
  register(getConnection, async (context) =>
    dataResponse(
      context,
      await brokerageConnections(context, options).status(),
    ));

  const selectAccountBody = z.object({ account_id: uuid }).strict();
  const selectBrokerageAccount = route(
    "patch",
    "/v1/brokerage/accounts/selection",
    "selectWebullAccount",
    "Brokerage Connections",
    { body: selectAccountBody, response: webullAccountSelectionResponseSchema },
  );
  register(selectBrokerageAccount, async (context) => {
    const input = await parseBody(context, selectAccountBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).selectAccount(
        input.account_id,
      ),
    );
  });

  const completionBody = z.object({
    completion: z.string().min(43).max(128).regex(/^[A-Za-z0-9_-]+$/),
  }).strict();
  const redeemCompletion = route(
    "post",
    "/v1/brokerage/connections/completions/redeem",
    "redeemWebullCompletion",
    "Brokerage Connections",
    { body: completionBody, response: webullCompletionResponseSchema },
  );
  register(redeemCompletion, async (context) => {
    const input = await parseBody(context, completionBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).redeemCompletion(
        input.completion,
      ),
    );
  });

  const disconnectBody = z.object({
    step_up_receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/),
  }).strict();
  const disconnect = route(
    "post",
    "/v1/brokerage/connections/disconnect",
    "disconnectWebullConnection",
    "Brokerage Connections",
    { body: disconnectBody, response: webullDisconnectResponseSchema },
  );
  register(disconnect, async (context) => {
    const input = await parseBody(context, disconnectBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).disconnect(
        input.step_up_receipt,
      ),
    );
  });

  const listBrokerageAccounts = route(
    "get",
    "/v1/brokerage/accounts",
    "listWebullAccounts",
    "Brokerage Reads",
    {
      description: "Owner-scoped Webull accounts and normalized capabilities.",
      response: brokerageAccountsResponseSchema,
    },
  );
  register(listBrokerageAccounts, async (context) =>
    dataResponse(
      context,
      await brokerageProjections(context, options).listAccounts(),
    ));

  const brokerageReadPath = z.object({ account_id: uuid });
  const brokerageReadQuery = z.object({
    refresh: z.enum(["true", "false"]).optional(),
  });
  for (
    const [path, operationId, resource, response] of [
      [
        "/v1/brokerage/accounts/{account_id}/capabilities",
        "getWebullAccountCapabilities",
        "account",
        brokerageCapabilitiesResponseSchema,
      ],
      [
        "/v1/brokerage/accounts/{account_id}/balances",
        "getWebullBalances",
        "balance",
        brokerageBalancesResponseSchema,
      ],
      [
        "/v1/brokerage/accounts/{account_id}/positions",
        "getWebullPositions",
        "positions",
        brokeragePositionsResponseSchema,
      ],
      [
        "/v1/brokerage/accounts/{account_id}/restrictions",
        "getWebullRestrictions",
        "restrictions",
        brokerageRestrictionsResponseSchema,
      ],
    ] as const satisfies readonly (readonly [
      string,
      string,
      BrokerageProjectionResource,
      z.ZodType,
    ])[]
  ) {
    const definition = route(
      "get",
      path,
      operationId,
      "Brokerage Reads",
      {
        pathParams: brokerageReadPath,
        query: brokerageReadQuery,
        description:
          "Immutable provider-authoritative projection with independent freshness timestamps.",
        response,
      },
    );
    register(definition, async (context) =>
      dataResponse(
        context,
        await brokerageProjections(context, options).read(
          uuid.parse(context.req.param("account_id")),
          resource,
          context.req.query("refresh") === "true",
        ),
      ));
  }

  const brokerageOrderPath = z.object({ account_id: uuid });
  const brokerageOrderReadQuery = z.object({
    refresh: z.enum(["true", "false"]).optional(),
  });
  const brokerageOrderDetailPath = z.object({
    account_id: uuid,
    order_id: uuid,
  });
  const listBrokerageOrders = route(
    "get",
    "/v1/brokerage/accounts/{account_id}/orders",
    "listWebullOrders",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderPath,
      query: brokerageOrderReadQuery,
      description:
        "Provider-authoritative order history with explicit freshness.",
      response: brokerageOrdersResponseSchema,
    },
  );
  register(listBrokerageOrders, async (context) =>
    dataResponse(
      context,
      await brokerageOrders(context, options).listOrders(
        uuid.parse(context.req.param("account_id")),
        context.req.query("refresh") === "true",
      ),
    ));

  const getBrokerageOrder = route(
    "get",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}",
    "getWebullOrder",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderDetailPath,
      description:
        "Latest positive order detail evidence; provider identifiers stay private.",
      response: brokerageOrderDetailResponseSchema,
    },
  );
  register(getBrokerageOrder, async (context) =>
    dataResponse(
      context,
      await brokerageOrders(context, options).order(
        uuid.parse(context.req.param("account_id")),
        uuid.parse(context.req.param("order_id")),
      ),
    ));

  const previewPlaceOrder = route(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/previews",
    "previewWebullOrder",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderPath,
      body: placeOrderIntentSchema,
      description:
        "Short-lived capability- and restriction-bound manual order review.",
      response: brokerageOrderPreviewResponseSchema,
    },
  );
  register(previewPlaceOrder, async (context) =>
    dataResponse(
      context,
      await brokerageOrders(context, options).previewPlace(
        uuid.parse(context.req.param("account_id")),
        await parseBody(context, placeOrderIntentSchema),
      ),
    ));

  const previewModifyOrder = route(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}/modify-preview",
    "previewWebullOrderModification",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderDetailPath,
      body: modifyOrderIntentSchema,
      description:
        "Review a modification only after proving target-order ownership.",
      response: brokerageOrderPreviewResponseSchema,
    },
  );
  register(previewModifyOrder, async (context) =>
    dataResponse(
      context,
      await brokerageOrders(context, options).previewModify(
        uuid.parse(context.req.param("account_id")),
        uuid.parse(context.req.param("order_id")),
        await parseBody(context, modifyOrderIntentSchema),
      ),
    ));

  const previewCancelOrder = route(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel-preview",
    "previewWebullOrderCancellation",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderDetailPath,
      description:
        "Review cancellation only after proving target-order ownership.",
      response: brokerageOrderPreviewResponseSchema,
    },
  );
  register(previewCancelOrder, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await brokerageOrders(context, options).previewCancel(
        uuid.parse(context.req.param("account_id")),
        uuid.parse(context.req.param("order_id")),
      ),
    );
  });

  const mutationHeaders = z.object({ "idempotency-key": idempotencyKey });
  const placeBrokerageOrder = route(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders",
    "placeWebullOrder",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderPath,
      headers: mutationHeaders,
      body: confirmPlaceOrderSchema,
      description:
        "Persist once before one provider submission; ambiguous results are never blindly retried.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  register(placeBrokerageOrder, async (context) => {
    const body = await parseBody(context, confirmPlaceOrderSchema);
    return dataResponse(
      context,
      await brokerageOrders(context, options).confirmPlace({
        accountId: uuid.parse(context.req.param("account_id")),
        previewId: body.preview_id,
        idempotencyKey: idempotencyKey.parse(
          context.req.header("idempotency-key"),
        ),
        intent: body.intent,
      }),
    );
  });

  const modifyBrokerageOrder = route(
    "patch",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}",
    "modifyWebullOrder",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderDetailPath,
      headers: mutationHeaders,
      body: confirmModifyOrderSchema,
      description:
        "Create a distinct durable modification command against an owned order.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  register(modifyBrokerageOrder, async (context) => {
    const body = await parseBody(context, confirmModifyOrderSchema);
    return dataResponse(
      context,
      await brokerageOrders(context, options).confirmModify({
        accountId: uuid.parse(context.req.param("account_id")),
        orderId: uuid.parse(context.req.param("order_id")),
        previewId: body.preview_id,
        idempotencyKey: idempotencyKey.parse(
          context.req.header("idempotency-key"),
        ),
        intent: body.intent,
      }),
    );
  });

  const cancelBrokerageOrder = route(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel",
    "cancelWebullOrder",
    "Brokerage Orders",
    {
      pathParams: brokerageOrderDetailPath,
      headers: mutationHeaders,
      body: confirmCancelOrderSchema,
      description:
        "Create a distinct durable cancellation command against an owned order.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  register(cancelBrokerageOrder, async (context) => {
    const body = await parseBody(context, confirmCancelOrderSchema);
    return dataResponse(
      context,
      await brokerageOrders(context, options).confirmCancel({
        accountId: uuid.parse(context.req.param("account_id")),
        orderId: uuid.parse(context.req.param("order_id")),
        previewId: body.preview_id,
        idempotencyKey: idempotencyKey.parse(
          context.req.header("idempotency-key"),
        ),
      }),
    );
  });

  const commandPath = z.object({ command_id: uuid });
  const getBrokerageOrderCommand = route(
    "get",
    "/v1/brokerage/order-commands/{command_id}",
    "getWebullOrderCommand",
    "Brokerage Orders",
    {
      pathParams: commandPath,
      description: "Owner-scoped redacted command and reconciliation state.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  register(getBrokerageOrderCommand, async (context) =>
    dataResponse(
      context,
      await brokerageOrders(context, options).command(
        uuid.parse(context.req.param("command_id")),
      ),
    ));

  const account = route("get", "/v1/account", "getAccount", "Account", {
    response: memberAccountResponseSchema,
  });
  register(
    account,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).accounts.get(),
      ),
  );

  const listIntentions = route(
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
  register(listIntentions, async (context) => {
    const input = z.object({
      status: z.enum(["active", "archived"]).optional(),
      limit: scenarioLimit,
    }).parse(query(context));
    return dataResponse(
      context,
      await repositories(context, options).scenarios.listIntentions(
        input.status,
        input.limit,
      ),
    );
  });

  const createIntention = route(
    "post",
    "/v1/intentions",
    "createIntention",
    "Intentions",
    {
      headers: scenarioIdempotencyHeaders,
      body: intentionCreateSchema,
      description: "Create one member-owned intention from exact reviewed input.",
      response: intentionResponseSchema,
    },
  );
  register(createIntention, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).scenarios.createIntention(
        await parseBody(context, intentionCreateSchema),
        idempotencyKey.parse(context.req.header("idempotency-key")),
      ),
    ));

  const getIntention = route(
    "get",
    "/v1/intentions/{intention_id}",
    "getIntention",
    "Intentions",
    {
      pathParams: scenarioIntentionPath,
      description: "Read one member-owned intention.",
      response: intentionResponseSchema,
    },
  );
  register(getIntention, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).scenarios.getIntention(
        uuid.parse(context.req.param("intention_id")),
      ),
    ));

  const patchIntention = route(
    "patch",
    "/v1/intentions/{intention_id}",
    "patchIntention",
    "Intentions",
    {
      pathParams: scenarioIntentionPath,
      headers: scenarioVersionHeaders,
      body: intentionPatchSchema,
      description: "Update exact member-entered fields with optimistic versioning.",
      response: intentionResponseSchema,
    },
  );
  register(patchIntention, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).scenarios.patchIntention(
        uuid.parse(context.req.param("intention_id")),
        await parseBody(context, intentionPatchSchema),
        expectedVersion(context),
      ),
    ));

  const archiveIntention = route(
    "delete",
    "/v1/intentions/{intention_id}",
    "archiveIntention",
    "Intentions",
    {
      pathParams: scenarioIntentionPath,
      headers: scenarioVersionHeaders,
      description: "Archive an intention with optimistic versioning.",
      response: intentionResponseSchema,
    },
  );
  register(archiveIntention, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await repositories(context, options).scenarios.archiveIntention(
        uuid.parse(context.req.param("intention_id")),
        expectedVersion(context),
      ),
    );
  });

  const createFutureMirror = route(
    "post",
    "/v1/intentions/{intention_id}/future-mirror",
    "createFutureMirror",
    "Future Mirror",
    {
      pathParams: scenarioIntentionPath,
      headers: scenarioIdempotencyHeaders,
      body: futureMirrorInputSchema,
      description:
        "Create a deterministic hypothetical scenario from member-entered assumptions only.",
      response: futureMirrorResponseSchema,
    },
  );
  register(createFutureMirror, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).scenarios.createFutureMirror(
        uuid.parse(context.req.param("intention_id")),
        await parseBody(context, futureMirrorInputSchema),
        idempotencyKey.parse(context.req.header("idempotency-key")),
      ),
    ));

  const getLatestFutureMirror = route(
    "get",
    "/v1/intentions/{intention_id}/future-mirror/latest",
    "getLatestFutureMirror",
    "Future Mirror",
    {
      pathParams: scenarioIntentionPath,
      description: "Read the latest completed hypothetical scenario.",
      response: futureMirrorResponseSchema,
    },
  );
  register(getLatestFutureMirror, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).scenarios.getLatestFutureMirror(
        uuid.parse(context.req.param("intention_id")),
      ),
    ));

  const getFutureMirror = route(
    "get",
    "/v1/intentions/{intention_id}/future-mirror/{run_id}",
    "getFutureMirror",
    "Future Mirror",
    {
      pathParams: scenarioRunPath,
      description: "Read one immutable historical hypothetical scenario.",
      response: futureMirrorResponseSchema,
    },
  );
  register(getFutureMirror, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).scenarios.getFutureMirror(
        uuid.parse(context.req.param("intention_id")),
        uuid.parse(context.req.param("run_id")),
      ),
    ));

  const preferencesPatch = z
    .object({
      themeMode: z.enum(["system", "light", "dark"]).optional(),
      ritualMode: z.enum(["tarot", "astrology"]).optional(),
      timezone: z.string().min(1).max(64).optional(),
      locale: z.string().min(2).max(35).optional(),
    })
    .strict();
  const updatePreferences = route(
    "patch",
    "/v1/preferences",
    "updatePreferences",
    "Account",
    {
      body: preferencesPatch,
      headers: z.object({ "if-match": z.string() }),
      response: retainedEnvelope(
        "UpdatePreferencesResponse",
        memberPreferencesSchema,
      ),
    },
  );
  register(updatePreferences, async (context) => {
    const patch = await parseBody(context, preferencesPatch);
    return dataResponse(
      context,
      await repositories(context, options).accounts.updatePreferences(
        {
          ...(patch.themeMode === undefined
            ? {}
            : { themeMode: patch.themeMode }),
          ...(patch.ritualMode === undefined
            ? {}
            : { ritualMode: patch.ritualMode }),
          ...(patch.timezone === undefined ? {} : { timezone: patch.timezone }),
          ...(patch.locale === undefined ? {} : { locale: patch.locale }),
        },
        expectedVersion(context),
      ),
    );
  });

  const investorBody = z.object({
    goalType: z.enum(["calm_fund", "long_term_growth", "income", "exploration"]),
    timeHorizon: z.enum(["short", "medium", "long"]),
    riskComfort: z.enum(["low", "moderate", "high"]),
  }).strict().openapi("UpdateInvestorProfileRequest");
  const updateInvestor = route(
    "put",
    "/v1/investor-profile",
    "updateInvestorProfile",
    "Account",
    {
      body: investorBody,
      headers: z.object({ "if-match": z.string().optional() }),
      response: retainedEnvelope("InvestorProfileResponse", investorProfileSchema),
    },
  );
  register(updateInvestor, async (context) => {
    const input = await parseBody(context, investorBody);
    const rawVersion = context.req.header("if-match");
    return dataResponse(
      context,
      await repositories(context, options).accounts.updateInvestor(
        input,
        rawVersion === undefined ? undefined : expectedVersion(context),
      ),
    );
  });

  const astrologyBody = z.object({
    birthDate: z.string().date(),
  }).strict().openapi("UpdateAstrologyProfileRequest");
  const updateAstrology = route(
    "put",
    "/v1/astrology-profile",
    "updateAstrologyProfile",
    "Account",
    {
      body: astrologyBody,
      headers: z.object({ "if-match": z.string().optional() }),
      response: retainedEnvelope("AstrologyProfileResponse", astrologyProfileSchema),
    },
  );
  register(updateAstrology, async (context) => {
    const input = await parseBody(context, astrologyBody);
    const rawVersion = context.req.header("if-match");
    return dataResponse(
      context,
      await repositories(context, options).accounts.updateAstrology(
        input.birthDate,
        rawVersion === undefined ? undefined : expectedVersion(context),
      ),
    );
  });
  const deleteAstrology = route(
    "delete",
    "/v1/astrology-profile",
    "deleteAstrologyProfile",
    "Account",
    {
      headers: z.object({ "if-match": z.string() }),
      response: retainedEnvelope(
        "DeleteAstrologyProfileResponse",
        z.object({ removed: z.literal(true) }).strict(),
      ),
    },
  );
  register(deleteAstrology, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await repositories(context, options).accounts.deleteAstrology(
        expectedVersion(context),
      ),
    );
  });

  const consentBody = z
    .object({
      policyCode: z.string().min(1).max(80),
      policyVersion: z.string().min(1).max(40),
      decision: z.enum(["accepted", "declined", "withdrawn"]),
    })
    .strict();
  const consent = route("post", "/v1/consents", "recordConsent", "Account", {
    body: consentBody,
    response: consentReceiptResponseSchema,
  });
  register(consent, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).accounts.recordConsent(
        await parseBody(context, consentBody),
      ),
    ));

  const listAssets = route("get", "/v1/assets", "listAssets", "Assets", {
    query: z.object({
      limit: limit.optional(),
      asset_type: publicAssetTypeSchema.optional(),
      symbol_prefix: z.string().optional(),
    }),
    response: assetCollectionResponseSchema,
  });
  register(listAssets, async (context) => {
    const input = z.object({
      limit,
      asset_type: publicAssetTypeSchema.optional(),
      symbol_prefix: z.string().optional(),
    }).parse(query(context));
    return collectionDataResponse(
      context,
      (await repositories(context, options).assets.list(
        input.limit,
        input.asset_type === "market_index" ? "index" : input.asset_type,
        input.symbol_prefix,
      )).map(presentAssetSummary),
    );
  });

  const compareAssetsBody = z.object({
    assetIds: z.array(uuid).min(2).max(5),
  }).strict().openapi("CompareAssetsRequest");
  const compareAssets = route(
    "post",
    "/v1/assets/compare",
    "compareAssets",
    "Assets",
    { body: compareAssetsBody, response: assetComparisonResponseSchema },
  );
  register(compareAssets, async (context) => {
    const input = await parseBody(context, compareAssetsBody);
    if (new Set(input.assetIds).size !== input.assetIds.length) {
      throw new HttpBoundaryError(422, "validation_failed", "Asset identifiers must be unique.");
    }
    const rows = await repositories(context, options).assets.compare(input.assetIds);
    if (rows.length !== input.assetIds.length) {
      throw new HttpBoundaryError(404, "not_found", "A requested asset was not found.");
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

  const getAsset = route("get", "/v1/assets/{asset_id}", "getAsset", "Assets", {
    pathParams: z.object({ asset_id: uuid }),
    response: assetDetailResponseSchema,
  });
  register(getAsset, async (context) => {
    const value = await repositories(context, options).assets.get(
      uuid.parse(context.req.param("asset_id")),
    );
    return dataResponse(context, value === null ? null : presentAssetDetail(value));
  });
  const getAssetEvidence = route(
    "get",
    "/v1/assets/{asset_id}/evidence",
    "getAssetEvidence",
    "Assets",
    { pathParams: z.object({ asset_id: uuid }), response: assetEvidenceResponseSchema },
  );
  register(getAssetEvidence, async (context) =>
    dataResponse(
      context,
      (await repositories(context, options).assets.evidence(
        uuid.parse(context.req.param("asset_id")),
      )).map(presentEvidenceDetail),
    ));
  const getAssetMetrics = route(
    "get",
    "/v1/assets/{asset_id}/metrics",
    "getAssetMetrics",
    "Assets",
    {
      pathParams: z.object({ asset_id: uuid }),
      query: z.object({ as_of: z.string().datetime().optional() }),
      response: assetMetricsResponseSchema,
    },
  );
  register(getAssetMetrics, async (context) =>
    dataResponse(
      context,
      (await repositories(context, options).assets.metrics(
        uuid.parse(context.req.param("asset_id")),
      )).map(presentAssetMetric),
    ));

  const listEditorial = route(
    "get",
    "/v1/editorial/{kind}",
    "listEditorial",
    "Editorial",
    {
      pathParams: z.object({ kind: z.string().min(1).max(80) }),
      query: z.object({ limit: limit.optional() }),
    },
  );
  register(listEditorial, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).editorial.listPublished(
        z.string().min(1).max(80).parse(context.req.param("kind")),
        limit.parse(context.req.query("limit")),
      ),
    ));

  const getEditorial = route(
    "get",
    "/v1/editorial/items/{slug}",
    "getEditorial",
    "Editorial",
    { pathParams: z.object({ slug: z.string().min(1).max(120) }) },
  );
  register(getEditorial, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).editorial.getPublished(
        z.string().min(1).max(120).parse(context.req.param("slug")),
      ),
    ));

  const listBriefings = route(
    "get",
    "/v1/briefings",
    "listBriefings",
    "Briefings",
    {
      query: z.object({
        type: z.enum(["daily", "weekly", "moon_cycle"]).optional(),
        period_start: z.string().date().optional(),
        period_end: z.string().date().optional(),
        cursor: z.string().min(1).max(2048).optional(),
        limit: limit.optional(),
      }),
      response: briefingCollectionResponseSchema,
    },
  );
  register(listBriefings, async (context) => {
    const input = z.object({
      type: z.enum(["daily", "weekly", "moon_cycle"]).optional(),
      period_start: z.string().date().optional(),
      period_end: z.string().date().optional(),
      cursor: z.string().optional(),
      limit,
    }).parse(query(context));
    if (input.cursor !== undefined) {
      throw new HttpBoundaryError(422, "invalid_cursor", "The pagination cursor is invalid or stale.");
    }
    return collectionDataResponse(
      context,
      (await repositories(context, options).briefings.list(
        input.limit,
        input.type,
        input.period_start,
        input.period_end,
      )).map(presentBriefingSummary),
    );
  });
  const getDailyBriefing = route(
    "get",
    "/v1/briefings/daily",
    "getDailyBriefing",
    "Briefings",
    {
      query: z.object({ local_date: z.string().date().optional() }),
      response: briefingDetailResponseSchema,
      acceptedResponse: briefingPendingResponseSchema,
    },
  );
  register(getDailyBriefing, async (context) => {
    const localDate = context.req.query("local_date") ??
      new Date().toISOString().slice(0, 10);
    const value = await repositories(context, options).briefings.daily(localDate);
    if (value === null || contentRecord(value).status !== "ready") {
      return context.json(
        {
          data: { status: "briefing_pending", local_date: localDate },
          meta: { request_id: context.get("requestId") },
        },
        202,
      );
    }
    return dataResponse(context, presentBriefingDetail(value));
  });
  const getBriefing = route(
    "get",
    "/v1/briefings/{briefing_id}",
    "getBriefing",
    "Briefings",
    {
      pathParams: z.object({ briefing_id: uuid }),
      response: briefingDetailResponseSchema,
    },
  );
  register(getBriefing, async (context) => {
    const value = await repositories(context, options).briefings.get(
      uuid.parse(context.req.param("briefing_id")),
    );
    return dataResponse(context, value === null ? null : presentBriefingDetail(value));
  });
  const briefingReadBody = z.object({ read: z.boolean() }).strict()
    .openapi("SetBriefingReadStateRequest");
  const setBriefingReadState = route(
    "put",
    "/v1/briefings/{briefing_id}/read-state",
    "setBriefingReadState",
    "Briefings",
    {
      pathParams: z.object({ briefing_id: uuid }),
      body: briefingReadBody,
      response: retainedEnvelope("BriefingSummaryResponse", briefingSummarySchema),
    },
  );
  register(setBriefingReadState, async (context) => {
    const input = await parseBody(context, briefingReadBody);
    return dataResponse(
      context,
      presentBriefingSummary(
        await repositories(context, options).briefings.setRead(
          uuid.parse(context.req.param("briefing_id")),
          input.read,
        ),
      ),
    );
  });

  const listCircles = route("get", "/v1/circles", "listCircles", "Circles", {
    query: z.object({
      archived: z.enum(["include", "exclude"]).optional(),
      cursor: z.string().min(1).max(2048).optional(),
      limit: limit.optional(),
    }),
    response: circleCollectionResponseSchema,
  });
  register(listCircles, async (context) => {
    if (context.req.query("cursor") !== undefined) {
      throw new HttpBoundaryError(422, "invalid_cursor", "The pagination cursor is invalid or stale.");
    }
    const rows = await repositories(context, options).circles.list(
      limit.parse(context.req.query("limit")),
    );
    const includeArchived = context.req.query("archived") === "include";
    return collectionDataResponse(
      context,
      includeArchived ? rows : rows.filter((row) => contentRecord(row).archived_at == null),
    );
  });
  const circleAssetBody = z.object({
    assetId: uuid,
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
  const createCircle = route("post", "/v1/circles", "createCircle", "Circles", {
    body: circleBody,
    headers: z.object({ "idempotency-key": idempotencyKey }),
    response: circleDetailResponseSchema,
  });
  register(createCircle, async (context) => {
    const input = await parseBody(context, circleBody);
    return dataResponse(
      context,
      await repositories(context, options).circles.create({
        title: input.title,
        description: input.description,
        ...(input.assets === undefined ? {} : { assets: input.assets }),
      }),
    );
  });
  const circlePath = z.object({ circle_id: uuid });
  const getCircle = route(
    "get",
    "/v1/circles/{circle_id}",
    "getCircle",
    "Circles",
    { pathParams: circlePath, response: circleDetailResponseSchema },
  );
  register(getCircle, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.get(
        uuid.parse(context.req.param("circle_id")),
      ),
    ));
  const updateCircle = route(
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
  register(updateCircle, async (context) => {
    const patch = await parseBody(context, circleBody.omit({ assets: true }).partial());
    return dataResponse(
      context,
      await repositories(context, options).circles.update(
        uuid.parse(context.req.param("circle_id")),
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
  const replaceCircleAssets = route(
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
  register(replaceCircleAssets, async (context) => {
    const input = await parseBody(context, replaceCircleAssetsBody);
    return dataResponse(
      context,
      await repositories(context, options).circles.replaceAssets(
        uuid.parse(context.req.param("circle_id")),
        input.assets,
        expectedVersion(context),
      ),
    );
  });
  const circleAssetPath = z.object({ circle_id: uuid, asset_id: uuid });
  const putCircleAssetBody = circleAssetBody.omit({ assetId: true })
    .openapi("PutCircleAssetRequest");
  const putCircleAsset = route(
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
  register(putCircleAsset, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.putAsset(
        uuid.parse(context.req.param("circle_id")),
        uuid.parse(context.req.param("asset_id")),
        await parseBody(context, putCircleAssetBody),
        expectedVersion(context),
      ),
    ));
  const deleteCircleAsset = route(
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
  register(deleteCircleAsset, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await repositories(context, options).circles.deleteAsset(
        uuid.parse(context.req.param("circle_id")),
        uuid.parse(context.req.param("asset_id")),
        expectedVersion(context),
      ),
    );
  });
  const archiveCircle = route(
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
  register(archiveCircle, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await repositories(context, options).circles.archive(
        uuid.parse(context.req.param("circle_id")),
        expectedVersion(context),
      ),
    );
  });
  const copyCircleTemplateBody = z.object({
    title: z.string().min(1).max(120).nullable().optional(),
  }).strict().openapi("CopyCircleTemplateRequest");
  const copyCircleTemplate = route(
    "post",
    "/v1/circle-templates/{template_id}/copy",
    "copyCircleTemplate",
    "Circles",
    {
      pathParams: z.object({ template_id: uuid }),
      headers: z.object({ "idempotency-key": idempotencyKey }),
      body: copyCircleTemplateBody,
      response: circleDetailResponseSchema,
    },
  );
  register(copyCircleTemplate, async (context) => {
    const body = await parseBody(context, copyCircleTemplateBody);
    const template = await repositories(context, options).circles.getTemplate(
      uuid.parse(context.req.param("template_id")),
    );
    if (template === null) throw new RepositoryNotFoundError();
    const value = contentRecord(template);
    return dataResponse(
      context,
      await repositories(context, options).circles.create({
        title: body.title ?? contentString(value, "title", "My circle"),
        description: contentString(value, "description", ""),
        sourceTemplateId: String(value.id),
        assets: contentArray(value, "assets").map((entry, index) => {
          const asset = contentRecord(entry);
          return {
            assetId: String(asset.id),
            ordinal: contentInteger(asset, "ordinal", index + 1),
            weightBps: typeof asset.weight_bps === "number" ? asset.weight_bps : null,
            note: contentNullableString(asset, "note"),
          };
        }),
      }),
    );
  });

  const listSaved = route("get", "/v1/saved", "listSaved", "Saved", {
    query: z.object({ limit: limit.optional() }),
  });
  register(listSaved, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.listSaved(
        limit.parse(context.req.query("limit")),
      ),
    ));
  const savedPath = z.object({
    item_kind: z.enum(["asset", "grimoire", "circle_template", "coven"]),
    item_id: uuid,
  });
  const saveItem = route(
    "post",
    "/v1/saved/{item_kind}/{item_id}",
    "saveItem",
    "Saved",
    {
      pathParams: savedPath,
      body: z.object({
        source_kind: z.enum(["ritual", "circle", "discover", "search", "direct"]).optional(),
        source_id: uuid.nullable().optional(),
      }).strict().openapi("SaveItemRequest"),
      optionalBody: true,
    },
  );
  register(saveItem, async (context) => {
    const body = z.object({
      source_kind: z.enum(["ritual", "circle", "discover", "search", "direct"]).optional(),
      source_id: uuid.nullable().optional(),
    }).strict().parse(context.req.valid("json" as never) ?? {});
    if (
      (body.source_kind === undefined || body.source_kind === "direct") &&
      body.source_id != null
    ) {
      throw new HttpBoundaryError(422, "validation_failed", "source_id requires an attributed source_kind.");
    }
    return dataResponse(
      context,
      await repositories(context, options).circles.save(
        savedPath.shape.item_kind.parse(context.req.param("item_kind")),
        uuid.parse(context.req.param("item_id")),
        body.source_kind ?? "direct",
        body.source_id ?? undefined,
      ),
    );
  });
  const unsaveItem = route(
    "delete",
    "/v1/saved/{item_kind}/{item_id}",
    "unsaveItem",
    "Saved",
    { pathParams: savedPath },
  );
  register(unsaveItem, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.unsave(
        savedPath.shape.item_kind.parse(context.req.param("item_kind")),
        uuid.parse(context.req.param("item_id")),
      ) ?? { removed: true },
    ));

  const pagedContentQuery = z.object({
    cursor: z.string().min(1).max(2_048).optional(),
    limit: limit.optional(),
  }).strict();
  const rejectRetainedCursor = (context: Context<RetainedAppEnvironment>): void => {
    if (context.req.query("cursor") !== undefined) {
      throw new HttpBoundaryError(
        422,
        "invalid_cursor",
        "This retained collection has no additional page for the supplied cursor.",
      );
    }
  };

  const listCoven = route("get", "/v1/coven", "listCoven", "Coven", {
    query: pagedContentQuery.extend({
      category: z.enum(["founder", "owner", "chief_executive"]).optional(),
      verified_as_of: z.string().date().optional(),
    }).strict(),
    response: covenCollectionResponseSchema,
  });
  register(listCoven, async (context) => {
    rejectRetainedCursor(context);
    const category = context.req.query("category");
    const verifiedAsOf = context.req.query("verified_as_of");
    const values = (
      await repositories(context, options).coven.list(
        limit.parse(context.req.query("limit")),
      )
    ).map(presentCovenSummary).filter((entry) =>
      (category === undefined || entry.category === category) &&
      (verifiedAsOf === undefined || String(entry.verified_as_of) <= verifiedAsOf)
    );
    return collectionDataResponse(context, values);
  });
  const getCoven = route("get", "/v1/coven/{entry_id}", "getCoven", "Coven", {
    pathParams: z.object({ entry_id: uuid }),
    response: covenDetailResponseSchema,
  });
  register(getCoven, async (context) => {
    const value = await repositories(context, options).coven.get(
      uuid.parse(context.req.param("entry_id")),
    );
    if (value === null) return dataResponse(context, null);
    const claimIds = evidenceClaimIds(value);
    const evidence = claimIds.length === 0
      ? []
      : await repositories(context, options).assets.listEvidence(claimIds);
    return dataResponse(context, presentCovenDetail(value, evidence));
  });
  const getCovenEvidence = route(
    "get",
    "/v1/coven/{entry_id}/evidence",
    "getCovenEvidence",
    "Coven",
    {
      pathParams: z.object({ entry_id: uuid }),
      response: covenEvidenceResponseSchema,
    },
  );
  register(getCovenEvidence, async (context) => {
    const value = await repositories(context, options).coven.get(
      uuid.parse(context.req.param("entry_id")),
    );
    if (value === null) return dataResponse(context, null);
    const claimIds = evidenceClaimIds(value);
    const evidence = claimIds.length === 0
      ? []
      : await repositories(context, options).assets.listEvidence(claimIds);
    return dataResponse(context, evidence.map(presentEvidenceDetail));
  });

  const getCircleTemplate = route(
    "get",
    "/v1/discover/circle-templates/{template_id}",
    "getCircleTemplate",
    "Discover",
    {
      pathParams: z.object({ template_id: uuid }),
      response: circleTemplateDetailResponseSchema,
    },
  );
  register(getCircleTemplate, async (context) => {
    const value = await repositories(context, options).circles.getTemplate(
      uuid.parse(context.req.param("template_id")),
    );
    return dataResponse(context, value === null ? null : presentCircleTemplate(value));
  });

  const listDiscoverAssets = route(
    "get",
    "/v1/discover/assets",
    "listDiscoverAssets",
    "Discover",
    { query: pagedContentQuery, response: discoverAssetCollectionResponseSchema },
  );
  register(listDiscoverAssets, async (context) => {
    rejectRetainedCursor(context);
    const values = await repositories(context, options).assets.list(
      limit.parse(context.req.query("limit")),
    );
    return collectionDataResponse(context, values.map(presentAssetSummary));
  });

  const listGrimoires = route(
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
  register(listGrimoires, async (context) => {
    rejectRetainedCursor(context);
    const values = await repositories(context, options).discover.listGrimoires(
      limit.parse(context.req.query("limit")),
      context.req.query("theme"),
    );
    return collectionDataResponse(context, values.map(presentGrimoireSummary));
  });

  const getGrimoire = route(
    "get",
    "/v1/discover/grimoires/{id}",
    "getGrimoire",
    "Discover",
    { pathParams: z.object({ id: uuid }), response: grimoireDetailResponseSchema },
  );
  register(getGrimoire, async (context) => {
    const value = await repositories(context, options).discover.getGrimoire(
      uuid.parse(context.req.param("id")),
    );
    return dataResponse(context, value === null ? null : presentGrimoireDetail(value));
  });

  const listCircleTemplates = route(
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
  register(listCircleTemplates, async (context) => {
    rejectRetainedCursor(context);
    const values = await repositories(context, options).discover.listCircleTemplates(
      limit.parse(context.req.query("limit")),
      context.req.query("creator"),
    );
    return collectionDataResponse(context, values.map(presentCircleTemplateSummary));
  });

  const listSeededCreators = route(
    "get",
    "/v1/discover/creators",
    "listSeededCreators",
    "Discover",
    { query: pagedContentQuery, response: creatorCollectionResponseSchema },
  );
  register(listSeededCreators, async (context) => {
    rejectRetainedCursor(context);
    const values = await repositories(context, options).discover.listCreators(
      limit.parse(context.req.query("limit")),
    );
    return collectionDataResponse(context, values.map(presentCreator));
  });

  const discoverQuery = pagedContentQuery.extend({
    section: z.enum(["asset", "coven", "grimoire", "circle_template"]).optional(),
  }).strict();
  const listDiscover = route("get", "/v1/discover", "listDiscover", "Discover", {
    query: discoverQuery,
    response: discoverResponseSchema,
  });
  register(listDiscover, async (context) => {
    rejectRetainedCursor(context);
    const requestedLimit = limit.parse(context.req.query("limit"));
    const section = context.req.query("section");
    const repositorySet = repositories(context, options);
    const [assets, coven, grimoires, templates] = await Promise.all([
      section === undefined || section === "asset" ? repositorySet.assets.list(requestedLimit) : [],
      section === undefined || section === "coven" ? repositorySet.coven.list(requestedLimit) : [],
      section === undefined || section === "grimoire" ? repositorySet.discover.listGrimoires(requestedLimit) : [],
      section === undefined || section === "circle_template"
        ? repositorySet.discover.listCircleTemplates(requestedLimit)
        : [],
    ]);
    const values = [
      ...assets.map((asset) => ({ kind: "asset", asset: presentAssetSummary(asset) })),
      ...coven.map((entry) => ({ kind: "coven", coven: presentCovenSummary(entry) })),
      ...grimoires.map((entry) => ({ kind: "grimoire", grimoire: presentGrimoireSummary(entry) })),
      ...templates.map((entry) => ({
        kind: "circle_template",
        circle_template: presentCircleTemplateSummary(entry),
      })),
    ].slice(0, requestedLimit);
    return collectionDataResponse(context, values);
  });

  const uploadIntentBody = z.object({
    bucketId: z.enum(["member-media", "media-quarantine"]),
    objectPath: z.string().min(1).max(512),
    mimeType: z.enum(["image/jpeg", "image/png", "image/webp"]),
    maxBytes: z.number().int().min(1).max(10 * 1024 * 1024),
    expiresAt: z.coerce.date(),
  }).strict();
  const createUploadIntent = route(
    "post",
    "/v1/media/upload-intents",
    "createUploadIntent",
    "Media",
    { body: uploadIntentBody },
  );
  register(
    createUploadIntent,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).media.createUploadIntent(
          await parseBody(context, uploadIntentBody),
        ),
      ),
  );
  const getUploadIntent = route(
    "get",
    "/v1/media/upload-intents/{intent_id}",
    "getUploadIntent",
    "Media",
    { pathParams: z.object({ intent_id: uuid }) },
  );
  register(
    getUploadIntent,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).media.getUploadIntent(
          uuid.parse(context.req.param("intent_id")),
        ),
      ),
  );
  const finalizeMediaBody = z.object({
    byteSize: z.number().int().positive(),
    checksum: z.string().regex(/^[a-f0-9]{64}$/),
  }).strict();
  const finalizeMedia = route(
    "post",
    "/v1/admin/media/upload-intents/{intent_id}/finalize",
    "finalizeUpload",
    "Admin Media",
    { pathParams: z.object({ intent_id: uuid }), body: finalizeMediaBody },
  );
  register(finalizeMedia, async (context) => {
    const input = await parseBody(context, finalizeMediaBody);
    return dataResponse(
      context,
      await repositories(context, options).media.finalizeUpload(
        uuid.parse(context.req.param("intent_id")),
        input.byteSize,
        input.checksum,
      ),
    );
  });

  const reportBody = z.object({
    targetKind: z.string().min(1).max(80),
    targetId: uuid,
    reasonCode: z.string().min(1).max(80),
    details: z.string().max(1000).optional(),
  }).strict();
  const reportContent = route(
    "post",
    "/v1/moderation/reports",
    "reportContent",
    "Moderation",
    { body: reportBody },
  );
  register(reportContent, async (context) => {
    const input = await parseBody(context, reportBody);
    return dataResponse(
      context,
      await repositories(context, options).moderation.report({
        targetKind: input.targetKind,
        targetId: input.targetId,
        reasonCode: input.reasonCode,
        ...(input.details === undefined ? {} : { details: input.details }),
      }),
    );
  });
  const moderationDecision = z.object({ status: z.string().min(1).max(40) })
    .passthrough();
  const decideModeration = route(
    "post",
    "/v1/admin/moderation/{case_id}/decision",
    "decideModeration",
    "Admin Moderation",
    {
      pathParams: z.object({ case_id: uuid }),
      body: moderationDecision,
      headers: z.object({
        "if-match": z.string(),
        "idempotency-key": idempotencyKey,
      }),
    },
  );
  register(
    decideModeration,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).moderation.decide(
          uuid.parse(context.req.param("case_id")),
          expectedVersion(context),
          await parseBody(context, moderationDecision),
          idempotencyKey.parse(context.req.header("idempotency-key")),
        ),
      ),
  );

  const listNotifications = route(
    "get",
    "/v1/notifications",
    "listNotifications",
    "Notifications",
    {
      query: z.object({ limit: limit.optional() }),
      response: notificationCollectionResponseSchema,
    },
  );
  register(
    listNotifications,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).notifications.list(
          limit.parse(context.req.query("limit")),
        ),
      ),
  );
  const notificationPreferences = route(
    "get",
    "/v1/notification-preferences",
    "getNotificationPreferences",
    "Notifications",
    { response: notificationPreferencesResponseSchema },
  );
  register(
    notificationPreferences,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).notifications.getPreferences(),
      ),
  );
  const updateNotificationPreferences = route(
    "patch",
    "/v1/notification-preferences",
    "updateNotificationPreferences",
    "Notifications",
    {
      body: jsonObject,
      headers: z.object({ "if-match": z.string() }),
      response: notificationPreferencesResponseSchema,
    },
  );
  register(
    updateNotificationPreferences,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).notifications.updatePreferences(
          await parseBody(context, jsonObject),
          expectedVersion(context),
        ),
      ),
  );
  const markNotificationRead = route(
    "patch",
    "/v1/notifications/{notification_id}/read",
    "markNotificationRead",
    "Notifications",
    {
      pathParams: z.object({ notification_id: uuid }),
      body: z.object({ read: z.boolean() }).strict().openapi("SetNotificationReadStateRequest"),
      response: retainedEnvelope("NotificationResponse", notificationSchema),
    },
  );
  register(markNotificationRead, async (context) => {
    const input = await parseBody(
      context,
      z.object({ read: z.boolean() }).strict(),
    );
    return dataResponse(
      context,
      await repositories(context, options).notifications.setRead(
        uuid.parse(context.req.param("notification_id")),
        input.read,
      ),
    );
  });
  const readAllNotificationsBody = z.object({
    before: z.string().datetime(),
  }).strict().openapi("ReadAllNotificationsRequest");
  const readAllNotifications = route(
    "post",
    "/v1/notifications/read-all",
    "readAllNotifications",
    "Notifications",
    {
      body: readAllNotificationsBody,
      headers: z.object({ "idempotency-key": idempotencyKey }),
      response: retainedEnvelope(
        "ReadAllNotificationsResponse",
        z.object({ updated_count: z.number().int().nonnegative().max(10000) }).strict(),
      ),
    },
  );
  register(readAllNotifications, async (context) => {
    const input = await parseBody(context, readAllNotificationsBody);
    return dataResponse(
      context,
      await repositories(context, options).notifications.readAll(input.before),
    );
  });

  const listPrivacy = route(
    "get",
    "/v1/privacy/requests",
    "listPrivacyRequests",
    "Privacy",
    { response: privacyRequestCollectionResponseSchema },
  );
  register(
    listPrivacy,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).privacy.list(),
      ),
  );
  const privacyBody = z.object({
    requestType: z.enum(["export", "deletion"]),
    step_up_receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/)
      .optional(),
  }).strict().superRefine((value, context) => {
    if (value.requestType === "deletion" && value.step_up_receipt === undefined) {
      context.addIssue({
        code: "custom",
        path: ["step_up_receipt"],
        message: "Deletion requires an action-bound step-up receipt.",
      });
    }
    if (value.requestType === "export" && value.step_up_receipt !== undefined) {
      context.addIssue({
        code: "custom",
        path: ["step_up_receipt"],
        message: "Export requests do not accept a step-up receipt.",
      });
    }
  }).openapi("RequestPrivacyActionRequest");
  const requestPrivacy = route(
    "post",
    "/v1/privacy/requests",
    "requestPrivacyAction",
    "Privacy",
    {
      body: privacyBody,
      headers: z.object({ "idempotency-key": idempotencyKey }),
      response: privacyRequestResponseSchema,
    },
  );
  register(requestPrivacy, async (context) => {
    const input = await parseBody(context, privacyBody);
    return dataResponse(
      context,
      await repositories(context, options).privacy.request(
        input.requestType,
        idempotencyKey.parse(context.req.header("idempotency-key")),
        input.step_up_receipt,
      ),
    );
  });
  const createPrivacyDownload = route(
    "post",
    "/v1/privacy/requests/{request_id}/download-url",
    "createPrivacyDownloadUrl",
    "Privacy",
    {
      pathParams: z.object({ request_id: uuid }),
      description: "Mint an owner-scoped privacy export URL that expires in five minutes.",
      response: retainedEnvelope(
        "PrivacyDownloadUrlResponse",
        z.object({
          url: z.string().url(),
          expires_at: z.string().datetime(),
        }).strict().openapi("PrivacyDownloadUrl"),
      ),
    },
  );
  register(createPrivacyDownload, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await repositories(context, options).privacy.createDownloadUrl(
        uuid.parse(context.req.param("request_id")),
      ),
    );
  });

  const ritualPath = z.object({ assignment_id: uuid });
  const getDailyRitual = route(
    "get",
    "/v1/rituals/daily",
    "getDailyRitual",
    "Rituals",
    {
      query: z.object({ mode: z.enum(["tarot", "astrology"]).optional() }),
      response: ritualAssignmentResponseSchema,
    },
  );
  register(getDailyRitual, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).rituals.getDaily(
        context.req.query("mode") as "tarot" | "astrology" | undefined,
      ),
    ));
  const ritualHistory = route(
    "get",
    "/v1/rituals",
    "listRitualHistory",
    "Rituals",
    {
      query: z.object({ limit: limit.optional() }),
      response: ritualHistoryResponseSchema,
    },
  );
  register(ritualHistory, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).rituals.history(
        limit.parse(context.req.query("limit")),
      ),
    ));
  const getRitual = route(
    "get",
    "/v1/rituals/{assignment_id}",
    "getRitual",
    "Rituals",
    { pathParams: ritualPath, response: ritualAssignmentResponseSchema },
  );
  register(
    getRitual,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).rituals.get(
          uuid.parse(context.req.param("assignment_id")),
        ),
      ),
  );
  const ritualEvidence = route(
    "get",
    "/v1/rituals/{assignment_id}/evidence",
    "getRitualEvidence",
    "Rituals",
    { pathParams: ritualPath, response: ritualEvidenceResponseSchema },
  );
  register(ritualEvidence, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).rituals.evidence(
        uuid.parse(context.req.param("assignment_id")),
      ),
    ));
  const transitionBody = z.object({
    from: z.enum(["assigned", "revealed"]),
    to: z.enum(["revealed", "completed"]),
  }).strict();
  const transitionRitual = route(
    "post",
    "/v1/rituals/{assignment_id}/transition",
    "transitionRitual",
    "Rituals",
    {
      pathParams: ritualPath,
      body: transitionBody,
      headers: z.object({ "if-match": z.string() }),
      response: ritualAssignmentResponseSchema,
    },
  );
  register(transitionRitual, async (context) => {
    const input = await parseBody(context, transitionBody);
    return dataResponse(
      context,
      await repositories(context, options).rituals.transition(
        uuid.parse(context.req.param("assignment_id")),
        input.from,
        input.to,
        expectedVersion(context),
      ),
    );
  });

  const search = route("get", "/v1/search", "search", "Search", {
    query: z.object({
      q: z.string().trim().min(2).max(100),
      kinds: z.string().min(1).max(80).regex(
        /^(asset|coven|grimoire|circle_template)(,(asset|coven|grimoire|circle_template))*$/,
      ),
      cursor: z.string().min(1).max(2_048).optional(),
      limit: limit.optional(),
    }).strict(),
    response: searchResponseSchema,
  });
  register(search, async (context) => {
    if (context.req.query("cursor") !== undefined) {
      throw new HttpBoundaryError(
        422,
        "invalid_cursor",
        "This retained search has no additional page for the supplied cursor.",
      );
    }
    const query = z.string().trim().min(2).max(100).parse(context.req.query("q"));
    const kinds = new Set(
      z.string().parse(context.req.query("kinds")).split(","),
    );
    const requestedLimit = limit.parse(context.req.query("limit"));
    const repositorySet = repositories(context, options);
    const [assets, coven, grimoires, templates] = await Promise.all([
      kinds.has("asset") ? repositorySet.assets.list(100) : [],
      kinds.has("coven") ? repositorySet.coven.list(100) : [],
      kinds.has("grimoire") ? repositorySet.discover.listGrimoires(100) : [],
      kinds.has("circle_template") ? repositorySet.discover.listCircleTemplates(100) : [],
    ]);
    const values = [
      ...assets.map(presentAssetSummary).filter((entry) => matchesPublishedSearch(entry, query))
        .map((asset) => ({ kind: "asset", asset })),
      ...coven.map(presentCovenSummary).filter((entry) => matchesPublishedSearch(entry, query))
        .map((entry) => ({ kind: "coven", coven: entry })),
      ...grimoires.map(presentGrimoireSummary).filter((entry) => matchesPublishedSearch(entry, query))
        .map((entry) => ({ kind: "grimoire", grimoire: entry })),
      ...templates.map(presentCircleTemplateSummary).filter((entry) => matchesPublishedSearch(entry, query))
        .map((entry) => ({ kind: "circle_template", circle_template: entry })),
    ].slice(0, requestedLimit);
    return collectionDataResponse(context, values);
  });
  const rowan = route(
    "get",
    "/v1/rowan/{surface}/{context_key}",
    "resolveRowan",
    "Rowan",
    {
      pathParams: z.object({
        surface: z.string().min(1).max(80),
        context_key: z.string().min(1).max(160),
      }),
      response: rowanCounselResponseSchema,
    },
  );
  register(
    rowan,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).rowan.resolve(
          z.string().min(1).max(80).parse(context.req.param("surface")),
          z.string().min(1).max(160).parse(context.req.param("context_key")),
        ),
      ),
  );

  const publicList = route(
    "get",
    "/v1/public/editorial/{kind}",
    "listPublicEditorial",
    "Public",
    {
      public: true,
      pathParams: z.object({ kind: z.string().min(1).max(80) }),
      query: z.object({ limit: limit.optional() }),
    },
  );
  register(
    publicList,
    async (context) =>
      dataResponse(
        context,
        await options.publicPreviewRepository.listPublished(
          z.string().min(1).max(80).parse(context.req.param("kind")),
          limit.parse(context.req.query("limit")),
        ),
      ),
  );
  const publicGet = route(
    "get",
    "/v1/public/editorial/items/{slug}",
    "getPublicEditorial",
    "Public",
    {
      public: true,
      pathParams: z.object({ slug: z.string().min(1).max(120) }),
    },
  );
  register(
    publicGet,
    async (context) =>
      dataResponse(
        context,
        await options.publicPreviewRepository.getPublished(
          z.string().min(1).max(120).parse(context.req.param("slug")),
        ),
      ),
  );

  const adminSession = route(
    "get",
    "/v1/admin/session",
    "getAdminSession",
    "Admin",
  );
  register(
    adminSession,
    async (context) => {
      const staff = await repositories(context, options).admin
        .getStaffPrincipal();
      if (staff === null) throw new StaffAuthorizationError();
      return dataResponse(context, staff);
    },
  );
  const adminStepUpBody = z.object({
    action: z.enum(["admin_job_retry", "admin_privacy_retry"]),
    target_id: uuid,
  }).strict();
  const adminStepUp = route(
    "post",
    "/v1/admin/step-up",
    "issueAdminStepUp",
    "Admin",
    { body: adminStepUpBody },
  );
  register(adminStepUp, async (context) => {
    const input = await parseBody(context, adminStepUpBody);
    return dataResponse(context, {
      receipt: await repositories(context, options).admin.issueStepUp(
        input.action,
        input.target_id,
      ),
    });
  });
  const adminAudit = route(
    "get",
    "/v1/admin/audit",
    "listAdminAudit",
    "Admin",
    { query: z.object({ limit: limit.optional() }) },
  );
  register(
    adminAudit,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).admin.listAudit(
          limit.parse(context.req.query("limit")),
        ),
      ),
  );
  const adminEditorialKind = z.enum([
    "ritual",
    "asset_codex",
    "coven",
    "grimoire",
    "circle_template",
    "rowan",
    "briefing_template",
  ]);
  const adminEditorialCreateBody = z.object({
    kind: adminEditorialKind,
    slug: z.string().min(1).max(120).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    payload: jsonObject,
  }).strict();
  const adminEditorialRevisionBody = z.object({ payload: jsonObject }).strict();
  const adminEditorialCommandBody = z.object({
    action: z.enum([
      "request_review",
      "approve",
      "changes_requested",
      "publish",
      "withdraw",
    ]),
    revision_id: uuid.nullable(),
    reason: z.string().min(8).max(500),
    high_trust: z.boolean().default(false),
  }).strict();
  const listAdminEditorial = route(
    "get",
    "/v1/admin/editorial",
    "listAdminEditorial",
    "Admin",
    { query: z.object({ limit: limit.optional(), kind: adminEditorialKind.optional() }) },
  );
  register(
    listAdminEditorial,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).admin.listEditorial(
          limit.parse(context.req.query("limit")),
          context.req.query("kind"),
        ),
      ),
  );
  const createAdminEditorial = route(
    "post",
    "/v1/admin/editorial",
    "createAdminEditorial",
    "Admin",
    { body: adminEditorialCreateBody },
  );
  register(createAdminEditorial, async (context) => {
    const body = await parseBody(context, adminEditorialCreateBody);
    return dataResponse(
      context,
      await repositories(context, options).admin.createEditorial(
        body.kind,
        body.slug,
        body.payload,
        context.get("requestId"),
      ),
    );
  });
  const getAdminEditorial = route(
    "get",
    "/v1/admin/editorial/{item_id}",
    "getAdminEditorial",
    "Admin",
    { pathParams: z.object({ item_id: uuid }) },
  );
  register(getAdminEditorial, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).admin.getEditorial(
        uuid.parse(context.req.param("item_id")),
      ),
    ));
  const createAdminEditorialRevision = route(
    "post",
    "/v1/admin/editorial/{item_id}/revisions",
    "createAdminEditorialRevision",
    "Admin",
    {
      pathParams: z.object({ item_id: uuid }),
      body: adminEditorialRevisionBody,
    },
  );
  register(createAdminEditorialRevision, async (context) => {
    const body = await parseBody(context, adminEditorialRevisionBody);
    return dataResponse(
      context,
      await repositories(context, options).admin.createEditorialRevision(
        uuid.parse(context.req.param("item_id")),
        body.payload,
        context.get("requestId"),
      ),
    );
  });
  const patchAdminEditorialRevision = route(
    "patch",
    "/v1/admin/editorial/{item_id}/revisions/{revision_id}",
    "patchAdminEditorialRevision",
    "Admin",
    {
      pathParams: z.object({ item_id: uuid, revision_id: uuid }),
      headers: scenarioVersionHeaders,
      body: adminEditorialRevisionBody,
    },
  );
  register(patchAdminEditorialRevision, async (context) => {
    const body = await parseBody(context, adminEditorialRevisionBody);
    return dataResponse(
      context,
      await repositories(context, options).admin.patchEditorialRevision(
        uuid.parse(context.req.param("item_id")),
        uuid.parse(context.req.param("revision_id")),
        expectedVersion(context),
        body.payload,
        context.get("requestId"),
      ),
    );
  });
  const commandAdminEditorial = route(
    "post",
    "/v1/admin/editorial/{item_id}/commands",
    "commandAdminEditorial",
    "Admin",
    {
      pathParams: z.object({ item_id: uuid }),
      body: adminEditorialCommandBody,
    },
  );
  register(commandAdminEditorial, async (context) => {
    const body = await parseBody(context, adminEditorialCommandBody);
    if (body.action !== "withdraw" && body.revision_id === null) {
      throw new HttpBoundaryError(
        422,
        "revision_required",
        "This editorial command requires a revision.",
      );
    }
    return dataResponse(
      context,
      await repositories(context, options).admin.commandEditorial(
        body.action,
        uuid.parse(context.req.param("item_id")),
        body.revision_id,
        body.reason,
        body.high_trust,
        context.get("requestId"),
      ),
    );
  });
  const adminJobs = route(
    "get",
    "/v1/admin/operations/jobs",
    "listAdminJobs",
    "Admin Operations",
    { query: z.object({ limit: limit.optional() }) },
  );
  register(
    adminJobs,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).adminOperations.listJobs(
          limit.parse(context.req.query("limit")),
        ),
      ),
  );
  const adminPrivacy = route(
    "get",
    "/v1/admin/operations/privacy",
    "listAdminPrivacy",
    "Admin Operations",
    { query: z.object({ limit: limit.optional() }) },
  );
  register(
    adminPrivacy,
    async (context) =>
      dataResponse(
        context,
        await repositories(context, options).adminOperations.listPrivacy(
          limit.parse(context.req.query("limit")),
        ),
      ),
  );
  const adminBrokerage = route(
    "get",
    "/v1/admin/operations/brokerage",
    "listAdminBrokerageDiagnostics",
    "Admin Operations",
    { query: z.object({ limit: limit.optional() }) },
  );
  register(adminBrokerage, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).adminOperations
        .listBrokerageDiagnostics(limit.parse(context.req.query("limit"))),
    ));
  const adminRetryBody = z.object({
    step_up_receipt: z.string().min(43).max(128).regex(/^[A-Za-z0-9_-]+$/),
  }).strict();
  const retryJob = route(
    "post",
    "/v1/admin/operations/jobs/{job_id}/retry",
    "retryAdminJob",
    "Admin Operations",
    {
      pathParams: z.object({ job_id: uuid }),
      headers: z.object({ "idempotency-key": idempotencyKey }),
      body: adminRetryBody,
    },
  );
  register(retryJob, async (context) => {
    const body = await parseBody(context, adminRetryBody);
    return dataResponse(context, {
      outbox_id: await repositories(context, options).adminOperations
        .requestJobRetry(
          uuid.parse(context.req.param("job_id")),
          idempotencyKey.parse(context.req.header("idempotency-key")),
          body.step_up_receipt,
        ),
    });
  });
  const retryPrivacy = route(
    "post",
    "/v1/admin/operations/privacy/{request_id}/retry",
    "retryAdminPrivacy",
    "Admin Operations",
    {
      pathParams: z.object({ request_id: uuid }),
      headers: z.object({ "idempotency-key": idempotencyKey }),
      body: adminRetryBody,
    },
  );
  register(retryPrivacy, async (context) => {
    const body = await parseBody(context, adminRetryBody);
    return dataResponse(context, {
      outbox_id: await repositories(context, options).adminOperations
        .requestPrivacyRetry(
          uuid.parse(context.req.param("request_id")),
          idempotencyKey.parse(context.req.header("idempotency-key")),
          body.step_up_receipt,
        ),
    });
  });

  return app;
}
