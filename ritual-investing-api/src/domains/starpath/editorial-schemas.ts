import { z } from "@hono/zod-openapi";

export const starpathPolicyVersionSchema = z.string().min(3).max(128).regex(
  /^[a-z0-9][a-z0-9._-]+$/,
);

export const starpathReviewDisciplineSchema = z.enum([
  "factual",
  "compliance",
]);

export const starpathReviewDecisionSchema = z.enum([
  "approved",
  "changes_requested",
  "rejected",
]);

export const starpathSubmitRevisionBodySchema = z.object({
  policy_version: starpathPolicyVersionSchema,
}).strict();

export const starpathReviewBodySchema = z.object({
  discipline: starpathReviewDisciplineSchema,
  decision: starpathReviewDecisionSchema,
  reason: z.string().min(8).max(500),
}).strict();

export const starpathPublishManifestBodySchema = z.object({
  reason: z.string().min(8).max(500),
}).strict();

export type StarpathReviewDiscipline = z.infer<
  typeof starpathReviewDisciplineSchema
>;
export type StarpathReviewDecision = z.infer<
  typeof starpathReviewDecisionSchema
>;
