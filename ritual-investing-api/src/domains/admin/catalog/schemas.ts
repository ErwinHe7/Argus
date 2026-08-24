import { z } from "@hono/zod-openapi";

import {
  safeMarkdownSchema,
  safeReasonSchema,
  slugSchema,
} from "../editorial-workflow/schemas.ts";

const text = (max: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(max)
    .refine((value) => !/[<>\u0000]/.test(value));
const versioned = {
  version: z.number().int().positive(),
  etag: z.string(),
} as const;

export const assetSchema = z
  .object({
    id: z.string().uuid(),
    slug: slugSchema,
    symbol: z.string().regex(/^[A-Z0-9.-]{1,16}$/),
    name: text(160),
    asset_type: z
      .string()
      .regex(/^(equity|etf|index|cash)$/)
      .openapi({
        description: "Demo asset type: equity, etf, index, or cash.",
        example: "equity",
      }),
    currency: z.literal("USD"),
    exchange: z
      .string()
      .regex(/^[A-Z0-9.-]{1,24}$/)
      .nullable(),
    is_demo: z.literal(true),
    status: z.enum(["active", "inactive"]),
    ...versioned,
  })
  .strict()
  .openapi("AdminAsset");
export const createAssetSchema = assetSchema.omit({
  id: true,
  is_demo: true,
  version: true,
  etag: true,
});
export const patchAssetSchema = createAssetSchema
  .omit({ slug: true })
  .partial()
  .strict()
  .refine((value) => Object.keys(value).length > 0);

export const metricSnapshotSchema = z
  .object({
    id: z.string().uuid(),
    asset_id: z.string().uuid(),
    observed_at: z.iso.datetime({ offset: true }),
    price_minor: z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER),
    change_bps: z.number().int().min(-100_000).max(100_000).nullable(),
    expense_ratio_bps: z.number().int().min(0).max(100_000).nullable(),
    source_label: text(120),
    is_demo: z.literal(true),
  })
  .strict()
  .openapi("AdminAssetMetricSnapshot");
export const createMetricSnapshotSchema = metricSnapshotSchema
  .omit({ id: true, asset_id: true, is_demo: true })
  .refine((value) => new Date(value.observed_at) <= new Date(), {
    path: ["observed_at"],
    message: "observed_at cannot be in the future",
  });

const httpsUrl = z
  .string()
  .url()
  .max(2_048)
  .refine((value) => new URL(value).protocol === "https:", "HTTPS is required");
export const evidenceSourceSchema = z
  .object({
    id: z.string().uuid(),
    canonical_url: httpsUrl,
    title: text(240),
    publisher: text(160),
    published_at: z.iso.datetime({ offset: true }).nullable(),
    retrieved_at: z.iso.datetime({ offset: true }),
    source_kind: z.enum([
      "filing",
      "company",
      "exchange",
      "research",
      "news",
      "other",
    ]),
    status: z.enum(["active", "retired"]),
    ...versioned,
  })
  .strict()
  .openapi("AdminEvidenceSource");
export const createEvidenceSourceSchema = evidenceSourceSchema.omit({
  id: true,
  version: true,
  etag: true,
});
export const patchEvidenceSourceSchema = createEvidenceSourceSchema
  .partial()
  .strict()
  .refine((value) => Object.keys(value).length > 0);

export const evidenceClaimSchema = z
  .object({
    id: z.string().uuid(),
    source_id: z.string().uuid(),
    claim_type: slugSchema,
    summary: text(1_000),
    observed_at: z.iso.datetime({ offset: true }).nullable(),
    uncertainty: text(500),
    status: z.enum(["active", "superseded", "withdrawn"]),
  })
  .strict()
  .openapi("AdminEvidenceClaim");
export const createEvidenceClaimSchema = evidenceClaimSchema.omit({ id: true });

export const seededCreatorSchema = z
  .object({
    id: z.string().uuid(),
    slug: slugSchema,
    display_name: text(120),
    bio: safeMarkdownSchema,
    avatar_media_id: z.string().uuid().nullable(),
    is_fictional: z.literal(true),
    status: z.enum(["active", "retired"]),
    ...versioned,
  })
  .strict()
  .openapi("AdminSeededCreator");
export const createSeededCreatorSchema = seededCreatorSchema.omit({
  id: true,
  is_fictional: true,
  version: true,
  etag: true,
});
export const patchSeededCreatorSchema = createSeededCreatorSchema
  .omit({ slug: true })
  .partial()
  .strict()
  .refine((value) => Object.keys(value).length > 0);

export const covenQualificationSchema = z
  .object({
    id: z.string().uuid(),
    entry_id: z.string().uuid(),
    category: z.enum(["founder", "owner", "chief_executive"]),
    person_name: text(160),
    valid_from: z.iso.date(),
    valid_to: z.iso.date().nullable(),
    current_verification_id: z.string().uuid().nullable(),
    submitted_by: z.string().uuid().nullable(),
  })
  .strict()
  .openapi("AdminCovenQualification");
export const createCovenQualificationSchema = z
  .object({
    category: z.enum(["founder", "owner", "chief_executive"]),
    person_name: text(160),
    valid_from: z.iso.date(),
    valid_to: z.iso.date().nullable().optional(),
  })
  .strict();
export const covenVerificationSchema = z
  .object({
    id: z.string().uuid(),
    qualification_id: z.string().uuid(),
    status: z.enum(["verified", "rejected"]),
    effective_as_of: z.iso.date(),
    verified_at: z.iso.datetime({ offset: true }),
    verified_by: z.string().uuid(),
    supersedes_id: z.string().uuid().nullable(),
    evidence_claim_ids: z.array(z.string().uuid()).min(1).max(50),
  })
  .strict()
  .openapi("AdminCovenVerification");
export const createCovenVerificationSchema = z
  .object({
    evidence_claim_ids: z.array(z.string().uuid()).min(1).max(50),
    effective_as_of: z.iso.date(),
    decision: z.enum(["verified", "rejected"]),
    reason: safeReasonSchema,
  })
  .strict();

export const ritualScheduleSchema = z
  .object({
    id: z.string().uuid(),
    local_date: z.iso.date(),
    mode: z.enum(["tarot", "astrology"]),
    revision_id: z.string().uuid(),
    audience: z.enum(["public", "member"]),
    state: z.enum(["draft", "scheduled", "active", "withdrawn"]),
    effective_at: z.iso.datetime({ offset: true }),
    ...versioned,
  })
  .strict()
  .openapi("AdminRitualSchedule");
export const createRitualScheduleSchema = ritualScheduleSchema.omit({
  id: true,
  state: true,
  version: true,
  etag: true,
});
export const patchRitualScheduleSchema = createRitualScheduleSchema
  .pick({ revision_id: true, effective_at: true })
  .partial()
  .strict()
  .refine((value) => Object.keys(value).length > 0);
export const deleteScheduleSchema = z
  .object({ reason: safeReasonSchema })
  .strict();

export const catalogListQuerySchema = z
  .object({
    status: z.string().trim().min(1).max(32).optional(),
    type: z.string().trim().min(1).max(32).optional(),
    search: z.string().trim().min(1).max(120).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();
export const scheduleListQuerySchema = z
  .object({
    from: z.iso.date(),
    to: z.iso.date(),
    mode: z.enum(["tarot", "astrology"]).optional(),
    state: z.enum(["draft", "scheduled", "active", "withdrawn"]).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict()
  .refine(
    (value) => {
      const range =
        new Date(`${value.to}T00:00:00Z`).getTime() -
        new Date(`${value.from}T00:00:00Z`).getTime();
      return range >= 0 && range <= 366 * 86_400_000;
    },
    { path: ["to"], message: "range must be at most 366 days" },
  );
