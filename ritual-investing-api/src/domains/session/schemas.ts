import { z } from "@hono/zod-openapi";

import {
  investorProfileSchema,
  memberPreferencesSchema,
  memberProfileSchema,
  onboardingStateSchema,
} from "../accounts/schemas.ts";
import {
  nullableTimestampSchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";

const sessionMemberSchema = z.object({
  user_id: uuidSchema,
  status: z.literal("active"),
  deletion_epoch: z.coerce.number().int().nonnegative(),
  deletion_requested_at: nullableTimestampSchema,
  created_at: nullableTimestampSchema,
  updated_at: nullableTimestampSchema,
}).passthrough().openapi("SessionMember");
const memberBranchCapabilitiesSchema = z.object({
  schema_version: z.literal("member-branch-capabilities-v1"),
  capability_version: z.number().int().positive(),
  environment: z.enum(["beta", "production"]),
  evaluated_at: z.string().datetime(),
  expires_at: z.string().datetime(),
  branches: z.array(
    z.string().regex(/^(ritual|starpath|discover|coven|you)$/),
  ).min(1).max(5),
}).strict().openapi("MemberBranchCapabilities");
const sessionBootstrapSchema = z.object({
  member: sessionMemberSchema,
  profile: memberProfileSchema.nullable(),
  preferences: memberPreferencesSchema.nullable(),
  onboarding: onboardingStateSchema.nullable(),
  investor_profile: investorProfileSchema.nullable(),
  astrology_profile: z.record(z.string(), z.unknown()).nullable(),
  server_time: z.string().datetime(),
  branch_capabilities: memberBranchCapabilitiesSchema,
}).strict().openapi("SessionBootstrap");
export const sessionBootstrapResponseSchema = retainedEnvelope(
  "SessionBootstrapResponse",
  sessionBootstrapSchema,
);
export const onboardingFinalizeBodySchema = z.object({
  schema_version: z.number().int().min(2).max(2),
  expected_onboarding_version: z.number().int().positive(),
  investing: z.object({
    experience: z.enum(["new", "some_experience", "experienced"]),
    goal_type: z.enum([
      "calm_fund",
      "long_term_growth",
      "income",
      "exploration",
    ]),
    time_horizon: z.enum(["short", "medium", "long"]),
    risk_comfort: z.enum(["low", "moderate", "high"]),
    contribution_rhythm: z.enum([
      "weekly",
      "biweekly",
      "monthly",
      "irregular",
      "not_sure",
    ]),
  }).strict(),
  ritual: z.object({
    familiarity: z.enum([
      "new",
      "curious",
      "familiar",
      "practiced",
      "prefer_not_to_say",
    ]),
    language_preference: z.enum([
      "practical",
      "balanced",
      "mystical",
      "prefer_not_to_say",
    ]),
    interests: z.array(
      z.string().regex(
        /^(practical_research|tarot|astrology|moon_cycles|reflection)$/,
      ),
    ).min(1).max(5),
  }).strict(),
  astrology: z.object({
    enabled: z.boolean(),
    birth_date: z.string().date().optional(),
  }).strict().superRefine((value, issue) => {
    if (value.enabled !== (value.birth_date !== undefined)) {
      issue.addIssue({
        code: "custom",
        path: ["birth_date"],
        message: "birth_date must match astrology opt-in",
      });
    }
  }),
  consents: z.object({
    terms: z.object({
      policy_version: z.string().min(1).max(40),
      decision: z.literal("accepted"),
    }).strict(),
    privacy: z.object({
      policy_version: z.string().min(1).max(40),
      decision: z.literal("accepted"),
    }).strict(),
    demo_disclosure: z.object({
      policy_version: z.string().min(1).max(40),
      decision: z.literal("accepted"),
    }).strict(),
    astrology: z.object({
      policy_version: z.string().min(1).max(40),
      decision: z.enum(["accepted", "declined"]),
    }).strict(),
  }).strict(),
}).strict().openapi("FinalizeOnboardingRequest");
