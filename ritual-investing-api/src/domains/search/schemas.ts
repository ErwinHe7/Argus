import { z } from "@hono/zod-openapi";
import { hasSafeTextControls } from "../../security/input-schemas.ts";

const safeSearchPattern = /^[\p{L}\p{N}][\p{L}\p{N}\s&'’.-]*$/u;
const forbiddenSearchFields = new Set([
  "author_staff_id",
  "canonical_url",
  "content_hash",
  "revision_id",
  "status",
  "tenant_id",
]);

export const searchQuerySchema = z
  .object({
    q: z
      .string()
      .trim()
      .min(2)
      .max(100)
      .refine(hasSafeTextControls)
      .regex(safeSearchPattern)
      .refine((value) => value.split(/\s+/u).length <= 12, {
        message: "search is limited to 12 tokens",
      })
      .refine(
        (value) =>
          !value
            .toLocaleLowerCase("en-US")
            .split(/\s+/u)
            .map((token) =>
              token.replace(/^[^\p{L}\p{N}_]+|[^\p{L}\p{N}_]+$/gu, ""),
            )
            .some((token) => forbiddenSearchFields.has(token)),
        { message: "raw field names are not searchable" },
      )
      .transform((value) => value.normalize("NFC")),
    kinds: z
      .string()
      .min(1)
      .max(80)
      .regex(
        /^(asset|coven|grimoire|circle_template)(,(asset|coven|grimoire|circle_template))*$/,
      ),
    cursor: z.string().min(20).max(2_048).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .strict();
