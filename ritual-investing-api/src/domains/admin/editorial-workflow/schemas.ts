import { z } from "@hono/zod-openapi";

import { boundedUserText } from "../../../security/input-schemas.ts";

const safeText = (maximum: number) =>
  boundedUserText({ maximum }).refine(
    (value) => !/[<>]/u.test(value),
    "active markup is not allowed",
  );

export const safeReasonSchema = safeText(500);
export const safeMarkdownSchema = safeText(8_000).refine(
  (value) =>
    !/\[[^\]]*\]\((?!https:\/\/)[^)]+\)/i.test(value) &&
    !/(?:javascript|data|vbscript):/i.test(value),
  "only HTTPS Markdown links are allowed",
);
export const slugSchema = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  .min(2)
  .max(96);

const ideaSchema = z
  .object({
    asset_id: z.string().uuid(),
    appearance_reason: safeText(500),
    risk_summary: safeText(500),
  })
  .strict();
const evidenceSchema = z
  .object({
    claim_id: z.string().uuid(),
    factor_label: safeText(160),
  })
  .strict();

export const ritualPayloadSchema = z
  .object({
    scenario_key: slugSchema,
    mode: z.enum(["tarot", "astrology"]),
    cadence: z.enum(["daily", "weekly", "moon_cycle"]),
    title: safeText(160),
    interpretation: safeMarkdownSchema,
    guidance: safeMarkdownSchema,
    market_label: safeText(120),
    art_media_id: z.string().uuid().nullable().optional(),
    observation_at: z.iso.datetime({ offset: true }),
    uncertainty: safeText(500),
    ideas: z.array(ideaSchema).min(3).max(5),
    evidence: z.array(evidenceSchema).min(1).max(20),
  })
  .strict()
  .superRefine((value, context) => {
    if (
      new Set(value.ideas.map((idea) => idea.asset_id)).size !==
      value.ideas.length
    )
      context.addIssue({
        code: "custom",
        path: ["ideas"],
        message: "asset IDs must be unique",
      });
    if (
      new Set(value.evidence.map((entry) => entry.claim_id)).size !==
      value.evidence.length
    )
      context.addIssue({
        code: "custom",
        path: ["evidence"],
        message: "claim IDs must be unique",
      });
  });

export const assetCodexPayloadSchema = z
  .object({
    asset_id: z.string().uuid(),
    thesis: safeMarkdownSchema,
    appearance_reason: safeText(500),
    metrics_as_of: z.iso.datetime({ offset: true }),
    limitations: safeText(1_000),
    risks: z
      .array(
        z
          .object({
            title: safeText(160),
            detail: safeText(1_000),
            severity: z.enum(["low", "medium", "high"]),
          })
          .strict(),
      )
      .min(1)
      .max(20),
    evidence_claim_ids: z.array(z.string().uuid()).min(1).max(50),
  })
  .strict();

export const covenEntryPayloadSchema = z
  .object({
    company_id: z.string().uuid(),
    summary: safeMarkdownSchema,
    inclusion_rationale: safeMarkdownSchema,
    limitations: safeText(1_000),
  })
  .strict();

const curatedAssetSchema = z
  .object({
    asset_id: z.string().uuid(),
    note: safeText(500),
  })
  .strict();

export const grimoirePayloadSchema = z
  .object({
    theme_code: slugSchema,
    title: safeText(160),
    description: safeMarkdownSchema,
    curator_label: safeText(120),
    art_media_id: z.string().uuid().nullable().optional(),
    assets: z.array(curatedAssetSchema).min(1).max(50),
  })
  .strict();

export const circleTemplatePayloadSchema = z
  .object({
    creator_id: z.string().uuid(),
    theme_code: slugSchema,
    title: safeText(160),
    description: safeMarkdownSchema,
    art_media_id: z.string().uuid().nullable().optional(),
    assets: z
      .array(
        curatedAssetSchema
          .extend({ weight_bps: z.number().int().min(0).max(10_000) })
          .strict(),
      )
      .min(1)
      .max(50),
  })
  .strict()
  .refine(
    (value) =>
      value.assets.reduce((sum, asset) => sum + asset.weight_bps, 0) === 10_000,
    { path: ["assets"], message: "weights must total 10,000 basis points" },
  );

const allowedRowanToken = z
  .string()
  .regex(/^(member_display_name|ritual_title|intention_title|demo_disclosure)$/)
  .openapi({
    description:
      "Allowlisted Rowan token: member_display_name, ritual_title, intention_title, or demo_disclosure.",
    example: "ritual_title",
  });
export const rowanScriptPayloadSchema = z
  .object({
    script_key: slugSchema,
    surface: z.enum(["ritual", "intention", "briefing"]),
    body_template: safeMarkdownSchema,
    allowed_tokens: z.array(allowedRowanToken).max(4),
    risk_footer: safeText(500),
  })
  .strict()
  .refine(
    (value) =>
      !/(urgent|exclusive|only I|guarantee|must invest|act now|love you|jealous)/i.test(
        value.body_template,
      ),
    { path: ["body_template"], message: "coercive language is not allowed" },
  );

export const briefingTemplatePayloadSchema = z
  .object({
    template_key: slugSchema,
    briefing_type: z.enum(["daily", "weekly", "moon_cycle"]),
    title: safeText(160),
    sections: z
      .array(
        z
          .object({
            section_type: slugSchema,
            heading: safeText(160),
            body: safeMarkdownSchema,
          })
          .strict(),
      )
      .min(1)
      .max(20),
  })
  .strict();

export const editorialKindSchema = z.enum([
  "ritual_scenario",
  "asset_codex",
  "coven_entry",
  "grimoire",
  "circle_template",
  "rowan_script",
  "briefing_template",
]);
export type EditorialKind = z.infer<typeof editorialKindSchema>;

export const editorialPayloadSchemas = {
  ritual_scenario: ritualPayloadSchema,
  asset_codex: assetCodexPayloadSchema,
  coven_entry: covenEntryPayloadSchema,
  grimoire: grimoirePayloadSchema,
  circle_template: circleTemplatePayloadSchema,
  rowan_script: rowanScriptPayloadSchema,
  briefing_template: briefingTemplatePayloadSchema,
} as const;

export const editorialPayloadSchema = z.union([
  ritualPayloadSchema,
  assetCodexPayloadSchema,
  covenEntryPayloadSchema,
  grimoirePayloadSchema,
  circleTemplatePayloadSchema,
  rowanScriptPayloadSchema,
  briefingTemplatePayloadSchema,
]);

export const editorialRevisionSchema = z
  .object({
    id: z.string().uuid(),
    revision_number: z.number().int().positive(),
    state: z.enum([
      "draft",
      "in_review",
      "approved",
      "changes_requested",
      "rejected",
    ]),
    version: z.number().int().positive(),
    author_staff_id: z.string().uuid(),
    payload: editorialPayloadSchema,
    etag: z.string(),
  })
  .strict();

export const editorialItemSchema = z
  .object({
    id: z.string().uuid(),
    kind: editorialKindSchema,
    slug: slugSchema,
    status: z.enum(["draft", "published", "withdrawn", "retired"]),
    version: z.number().int().positive(),
    current_published_revision_id: z.string().uuid().nullable(),
    revision: editorialRevisionSchema.optional(),
    etag: z.string(),
  })
  .strict();

export type AdminEditorialItem = z.infer<typeof editorialItemSchema>;
export type AdminEditorialRevision = z.infer<typeof editorialRevisionSchema>;

export const editorialListQuerySchema = z
  .object({
    state: z.enum(["draft", "published", "withdrawn", "retired"]).optional(),
    author_staff_id: z.string().uuid().optional(),
    search: z.string().trim().min(1).max(120).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();

export const reviewRequestSchema = z
  .object({ note: safeReasonSchema, high_trust: z.boolean().optional() })
  .strict();
export const reviewDecisionSchema = z
  .object({
    decision: z.enum(["approved", "changes_requested", "rejected"]),
    reason: safeReasonSchema,
  })
  .strict();
export const publicationSchema = z
  .object({
    effective_at: z.iso.datetime({ offset: true }),
    reason: safeReasonSchema,
  })
  .strict();
export const withdrawalSchema = z.object({ reason: safeReasonSchema }).strict();
