import { z } from "@hono/zod-openapi";

import {
  assetSummarySchema,
  circleTemplateSummarySchema,
  covenSummarySchema,
  grimoireSummarySchema,
} from "../content/schemas.ts";
import {
  jsonObjectSchema,
  nullableTimestampSchema,
  retainedCollectionEnvelope,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

export const notificationSchema = z.object({
  id: uuidSchema,
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  kind: z.string().min(1).max(80),
  title: z.string().min(1).max(160),
  body: z.string().min(1).max(2000),
  deep_link: z.string().max(512).nullable(),
  scheduled_at: nullableTimestampSchema,
  read_at: nullableTimestampSchema,
  created_at: z.string().datetime(),
}).strict().openapi("MemberNotification");
export const notificationCollectionResponseSchema = retainedEnvelope(
  "NotificationCollectionResponse",
  z.array(notificationSchema).max(100),
);
const notificationPreferencesSchema = z.object({
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  daily_ritual: z.boolean(),
  weekly_recap: z.boolean(),
  moon_cycle: z.boolean(),
  quiet_hours: jsonObjectSchema,
  version: z.coerce.number().int().positive(),
}).strict().openapi("NotificationPreferences");
export const notificationPreferencesResponseSchema = retainedEnvelope(
  "NotificationPreferencesResponse",
  notificationPreferencesSchema,
);
const privacyRequestSchema = z.object({
  id: uuidSchema,
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  request_type: z.enum(["export", "deletion"]),
  status: z.enum([
    "requested",
    "verified",
    "queued",
    "processing",
    "completed",
    "failed",
    "cancelled",
  ]),
  requested_at: z.string().datetime(),
  completed_at: nullableTimestampSchema,
  failure_code: z.string().max(128).nullable(),
}).strict().openapi("PrivacyRequest");
export const privacyRequestCollectionResponseSchema = retainedEnvelope(
  "PrivacyRequestCollectionResponse",
  z.array(privacyRequestSchema).max(100),
);
export const privacyRequestResponseSchema = retainedEnvelope(
  "PrivacyRequestResponse",
  privacyRequestSchema,
);
export const ritualAssignmentSchema = z.object({
  id: uuidSchema,
  user_id: uuidSchema,
  deletion_epoch: z.coerce.number().int().nonnegative(),
  local_date: z.string().date(),
  mode: z.enum(["tarot", "astrology"]),
  schedule_id: uuidSchema,
  revision_id: uuidSchema,
  rowan_revision_id: uuidSchema.nullable(),
  state: z.enum(["assigned", "revealed", "completed"]),
  revealed_at: nullableTimestampSchema,
  completed_at: nullableTimestampSchema,
  version: z.coerce.number().int().positive(),
  payload: jsonObjectSchema,
  body_template: z.string().nullable(),
  allowed_tokens: z.array(z.string()).nullable(),
  risk_footer: z.string().nullable(),
}).passthrough().openapi("DailyRitualAssignment");
export const ritualAssignmentResponseSchema = retainedEnvelope(
  "DailyRitualResponse",
  ritualAssignmentSchema,
);
export const ritualHistoryResponseSchema = retainedEnvelope(
  "RitualHistoryResponse",
  z.array(ritualAssignmentSchema).max(100),
);
const evidenceSourceSchema = z.object({
  canonical_url: z.string().url(),
  title: z.string().min(1),
  publisher: z.string().min(1),
  published_at: nullableTimestampSchema,
  retrieved_at: z.string().datetime(),
  source_kind: z.string().min(1),
}).passthrough().openapi("EvidenceSource");
const evidenceClaimSchema = z.object({
  id: uuidSchema,
  claim_type: z.string().min(1),
  summary: z.string().min(1),
  observed_at: nullableTimestampSchema,
  uncertainty: z.string().min(1),
  source: evidenceSourceSchema,
}).passthrough().openapi("EvidenceClaim");
export const ritualEvidenceResponseSchema = retainedEnvelope(
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
export const searchResponseSchema = retainedCollectionEnvelope(
  "SearchResponse",
  z.array(searchResultSchema).max(100),
);
const rowanCounselSchema = z.object({
  id: uuidSchema,
  script_key: z.string().min(1).max(160),
  priority: z.coerce.number().int(),
  body_template: z.string().min(1),
  allowed_tokens: z.array(z.string()).max(64),
  risk_footer: z.string().min(1),
}).strict().openapi("RowanCounsel");
export const rowanCounselResponseSchema = retainedEnvelope(
  "RowanCounselResponse",
  rowanCounselSchema,
);
