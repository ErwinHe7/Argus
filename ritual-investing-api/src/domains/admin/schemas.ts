import { z } from "@hono/zod-openapi";

export const adminEditorialKindSchema = z.enum([
  "ritual",
  "asset_codex",
  "coven",
  "grimoire",
  "circle_template",
  "rowan",
  "briefing_template",
  "starpath_lesson",
]);

export type AdminEditorialKind = z.infer<typeof adminEditorialKindSchema>;
