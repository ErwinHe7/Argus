import { z } from "@hono/zod-openapi";

import {
  nullableTimestampSchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

const timestampSchema = z.string().datetime({ offset: true });
const boundedText = (minimum: number, maximum: number) =>
  z.string().min(minimum).max(maximum);

export const starpathEnvironmentSchema = z.enum(["beta", "production"]);
export const starpathNodeStateSchema = z.enum([
  "completed",
  "current",
  "locked",
]);
export const starpathAttemptKindSchema = z.enum(["node", "recall"]);
export const starpathCommandEffectSchema = z.enum([
  "started",
  "resumed",
  "content_replaced",
  "wrong_answer",
  "lesson_completed",
  "recall_completed",
  "recall_skipped",
  "semantic_replay",
  "idempotent_replay",
]);

export const starpathEvidenceSchema = z.object({
  ordinal: z.number().int().min(1).max(12),
  canonical_url: z.string().url().startsWith("https://"),
  source_title: boundedText(1, 300),
  publisher: boundedText(1, 200),
  source_observed_at: timestampSchema,
  effective_at: nullableTimestampSchema,
  retrieved_at: timestampSchema,
  current_until: timestampSchema,
  claim_summary: boundedText(1, 1200),
}).strict().openapi("StarpathEvidence");

export const starpathFactualSectionSchema = z.object({
  ordinal: z.number().int().min(1).max(12),
  kind: z.enum(["fact", "neutral_example"]),
  heading: boundedText(1, 160),
  body: boundedText(1, 4000),
  uncertainty: boundedText(1, 1200),
  observed_at: timestampSchema,
  evidence: z.array(starpathEvidenceSchema).min(1).max(12),
}).strict().openapi("StarpathFactualSection");

export const starpathKnowledgeCheckOptionSchema = z.object({
  id: uuidSchema,
  ordinal: z.number().int().min(1).max(5),
  label: boundedText(1, 600),
}).strict().openapi("StarpathKnowledgeCheckOption");

export const starpathKnowledgeCheckSchema = z.object({
  id: uuidSchema,
  prompt: boundedText(1, 1200),
  options: z.array(starpathKnowledgeCheckOptionSchema).min(2).max(5),
}).strict().openapi("StarpathKnowledgeCheck");

export const starpathNodeSchema = z.object({
  node_ordinal: z.number().int().min(1).max(8),
  pathway_ordinal: z.number().int().min(1).max(4),
  pathway_position: z.number().int().min(1).max(2),
  state: starpathNodeStateSchema,
  lesson_id: uuidSchema,
  revision_id: uuidSchema,
  title: boundedText(1, 160),
  guide: z.object({
    tarot_key: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    accessible_label: boundedText(1, 240),
  }).strict(),
  mythic_mnemonic: boundedText(1, 1200),
  factual_summary: boundedText(1, 2400),
  factual_sections: z.array(starpathFactualSectionSchema).min(1).max(12),
  material_limitations: boundedText(1, 2400),
  risk_context: boundedText(1, 2400),
  recall_prompt: boundedText(1, 800),
  rowan_explanation: boundedText(1, 2400),
  knowledge_check: starpathKnowledgeCheckSchema,
}).strict().openapi("StarpathNode");

export const starpathAuthoritySchema = z.object({
  capability_version: z.number().int().positive(),
  manifest_id: uuidSchema,
  manifest_version: z.string().min(3).max(128),
  policy_version: z.string().min(3).max(128),
  environment: starpathEnvironmentSchema,
  jurisdiction: z.string().min(2).max(32),
}).strict().openapi("StarpathAuthority");

export const starpathSessionSchema = z.object({
  id: uuidSchema,
  state: z.enum(["active", "closed", "replaced"]),
  started_at: timestampSchema,
  last_action_at: timestampSchema,
  explicit_start: z.boolean(),
  replacement_of_session_id: uuidSchema.nullable(),
}).strict().openapi("StarpathSession");

export const starpathThemeSchema = z.object({
  id: uuidSchema,
  key: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  title: boundedText(1, 160),
  horoscope_frame: boundedText(1, 1200),
  factual_focus: boundedText(1, 1200),
  accessible_label: boundedText(1, 240),
}).strict().openapi("StarpathSessionTheme");

export const starpathProgressSchema = z.object({
  current_node_ordinal: z.number().int().min(1).max(9),
  version: z.number().int().positive(),
  updated_at: timestampSchema,
}).strict().openapi("StarpathProgress");

export const starpathRecallSchema = z.object({
  id: uuidSchema,
  lesson_id: uuidSchema,
  revision_id: uuidSchema,
  question_id: uuidSchema,
  status: z.enum(["presented"]),
  prompt: boundedText(1, 800),
  knowledge_check: starpathKnowledgeCheckSchema,
}).strict().openapi("StarpathRecall");

export const starpathAnswerFeedbackSchema = z.object({
  is_correct: z.boolean(),
  explanation: boundedText(1, 2400),
}).strict().openapi("StarpathAnswerFeedback");

export const starpathSnapshotSchema = z.object({
  availability: z.enum(["available", "not_started"]),
  version: z.number().int().positive(),
  authority: starpathAuthoritySchema,
  session: starpathSessionSchema.nullable(),
  theme: starpathThemeSchema.nullable(),
  progress: starpathProgressSchema.nullable(),
  nodes: z.array(starpathNodeSchema).min(8).max(8),
  recall: starpathRecallSchema.nullable(),
  command_effect: starpathCommandEffectSchema.nullable(),
  answer: starpathAnswerFeedbackSchema.nullable(),
}).strict().openapi("StarpathSnapshot");

export const starpathStartCommandSchema = z.object({}).strict()
  .openapi("StartOrResumeStarpath");

export const starpathAnswerCommandSchema = z.object({
  session_id: uuidSchema,
  manifest_id: uuidSchema,
  revision_id: uuidSchema,
  question_id: uuidSchema,
  option_id: uuidSchema,
  attempt_kind: starpathAttemptKindSchema.optional(),
}).strict().openapi("AnswerStarpathQuestion");

export const starpathSkipRecallCommandSchema = z.object({
  session_id: uuidSchema,
}).strict().openapi("SkipStarpathRecall");

export const starpathSnapshotResponseSchema = retainedEnvelope(
  "StarpathSnapshotResponse",
  starpathSnapshotSchema,
);

export type StarpathSnapshot = z.infer<typeof starpathSnapshotSchema>;
export type StarpathAnswerCommand = z.infer<
  typeof starpathAnswerCommandSchema
>;
export type StarpathSkipRecallCommand = z.infer<
  typeof starpathSkipRecallCommandSchema
>;
