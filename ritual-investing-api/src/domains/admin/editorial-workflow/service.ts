import type { EditorialKind } from "./schemas.ts";

export const editorialDefinitions = [
  {
    kind: "ritual_scenario",
    path: "/v1/admin/ritual-scenarios",
    highTrust: true,
  },
  { kind: "asset_codex", path: "/v1/admin/asset-codex", highTrust: false },
  { kind: "coven_entry", path: "/v1/admin/coven-entries", highTrust: false },
  { kind: "grimoire", path: "/v1/admin/grimoires", highTrust: false },
  {
    kind: "circle_template",
    path: "/v1/admin/circle-templates",
    highTrust: false,
  },
  { kind: "rowan_script", path: "/v1/admin/rowan-scripts", highTrust: true },
  {
    kind: "briefing_template",
    path: "/v1/admin/briefing-templates",
    highTrust: false,
  },
] as const satisfies readonly {
  kind: EditorialKind;
  path: string;
  highTrust: boolean;
}[];

export function etagVersion(value: string): number {
  const match = /^"v([1-9]\d*)"$/.exec(value);
  if (match?.[1] === undefined)
    throw new EditorialWorkflowError("version_conflict");
  return Number(match[1]);
}

export class EditorialWorkflowError extends Error {
  readonly code:
    | "not_found"
    | "version_conflict"
    | "idempotency_conflict"
    | "invalid_transition"
    | "self_approval"
    | "publishability_failed";

  constructor(
    code:
      | "not_found"
      | "version_conflict"
      | "idempotency_conflict"
      | "invalid_transition"
      | "self_approval"
      | "publishability_failed",
  ) {
    super(code);
    this.code = code;
    this.name = "EditorialWorkflowError";
  }
}
