import { z } from "@hono/zod-openapi";

export const scenarioUuidSchema = z.string().uuid();

export const exactMinorUnitsSchema = z.string()
  .regex(/^(?:0|[1-9]\d{0,18})$/)
  .refine((value) => BigInt(value) <= 9_223_372_036_854_775_807n, {
    message: "minor units exceed the exact storage limit",
  });

export const scenarioMinorUnitsSchema = exactMinorUnitsSchema
  .regex(/^(?:0|[1-9]\d{0,15})$/)
  .refine((value) => BigInt(value) <= 9_007_199_254_740_991n, {
    message: "minor units exceed the reviewed-input limit",
  });

export const scenarioMoneySchema = z.object({
  minor_units: scenarioMinorUnitsSchema,
  currency: z.string().regex(/^[A-Z]{3}$/),
}).strict().openapi("ScenarioMoney");

export const intentionStatusSchema = z.enum(["active", "archived"]);

export const intentionSchema = z.object({
  id: scenarioUuidSchema,
  title: z.string().min(1).max(120),
  target: scenarioMoneySchema,
  target_date: z.string().date(),
  status: intentionStatusSchema,
  version: z.number().int().positive(),
  created_at: z.string().datetime(),
}).strict().openapi("MemberIntention");

export const intentionCreateSchema = z.object({
  title: z.string().trim().min(1).max(120),
  target: scenarioMoneySchema,
  target_date: z.string().date(),
}).strict().openapi("CreateMemberIntention");

export const intentionPatchSchema = z.object({
  title: z.string().trim().min(1).max(120).optional(),
  target: scenarioMoneySchema.optional(),
  target_date: z.string().date().optional(),
}).strict().refine((value) => Object.keys(value).length > 0, {
  message: "at least one field is required",
}).openapi("PatchMemberIntention");

export const intentionPageSchema = z.object({
  items: z.array(intentionSchema).max(50),
  next_cursor: z.string().nullable(),
}).strict().openapi("MemberIntentionPage");

export const futureMirrorInputSchema = z.object({
  name: z.string().trim().min(1).max(80),
  baseline: scenarioMoneySchema,
  monthly_contribution: scenarioMoneySchema,
  annual_return_bps: z.object({
    low: z.number().int().min(-5000).max(5000),
    mid: z.number().int().min(-5000).max(5000),
    high: z.number().int().min(-5000).max(5000),
  }).strict(),
  as_of_date: z.string().date(),
}).strict().superRefine((value, context) => {
  const { low, mid, high } = value.annual_return_bps;
  if (low > mid || mid > high) {
    context.addIssue({
      code: "custom",
      path: ["annual_return_bps"],
      message: "return bands must be ordered low through high",
    });
  }
  if (value.baseline.currency !== value.monthly_contribution.currency) {
    context.addIssue({
      code: "custom",
      path: ["monthly_contribution", "currency"],
      message: "scenario currencies must match",
    });
  }
}).openapi("CreateHypotheticalFutureMirror");

export const futureMirrorPointSchema = z.object({
  ordinal: z.number().int().positive(),
  projected_date: z.string().date(),
  low_amount_minor: exactMinorUnitsSchema,
  mid_amount_minor: exactMinorUnitsSchema,
  high_amount_minor: exactMinorUnitsSchema,
}).strict().openapi("HypotheticalFutureMirrorPoint");

export const futureMirrorSchema = z.object({
  id: scenarioUuidSchema,
  intention_id: scenarioUuidSchema,
  name: z.string().min(1).max(80),
  baseline: scenarioMoneySchema,
  monthly_contribution: scenarioMoneySchema,
  annual_return_bps: z.object({
    low: z.number().int(),
    mid: z.number().int(),
    high: z.number().int(),
  }).strict(),
  as_of_date: z.string().date(),
  target_date: z.string().date(),
  points: z.array(futureMirrorPointSchema).min(1).max(121),
  model_version: z.string().min(1).max(64),
  assumption_version: z.string().min(1).max(64),
  input_hash: z.string().regex(/^[a-f0-9]{64}$/),
  generated_at: z.string().datetime(),
  uncertainty_disclosure: z.string().min(40).max(400),
}).strict().openapi("HypotheticalFutureMirror");

export type IntentionCreateInput = z.infer<typeof intentionCreateSchema>;
export type IntentionPatchInput = z.infer<typeof intentionPatchSchema>;
export type FutureMirrorInput = z.infer<typeof futureMirrorInputSchema>;
export type MemberIntention = z.infer<typeof intentionSchema>;
export type FutureMirror = z.infer<typeof futureMirrorSchema>;
export type FutureMirrorPoint = z.infer<typeof futureMirrorPointSchema>;
