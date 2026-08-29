import type {
  FutureMirror,
  FutureMirrorInput,
  IntentionCreateInput,
  IntentionPatchInput,
  MemberIntention,
} from "./schemas.ts";

export type ScenarioConflictCode =
  | "idempotency_conflict"
  | "invalid_scenario_input"
  | "invalid_scenario_horizon"
  | "scenario_value_too_large";

/**
 * A domain-level rejection that every ScenarioRepository implementation may
 * surface. Keeping it at the port lets HTTP mapping remain independent of the
 * SQL/Supabase adapter.
 */
export class ScenarioConflictError extends Error {
  readonly code: ScenarioConflictCode;

  constructor(code: ScenarioConflictCode) {
    super(code);
    this.name = "ScenarioConflictError";
    this.code = code;
  }
}

export interface ScenarioRepository {
  listIntentions(
    status?: "active" | "archived",
    limit?: number,
  ): Promise<{ items: MemberIntention[]; next_cursor: null }>;
  getIntention(id: string): Promise<MemberIntention>;
  createIntention(
    raw: IntentionCreateInput,
    idempotencyKey: string,
  ): Promise<MemberIntention>;
  patchIntention(
    id: string,
    raw: IntentionPatchInput,
    expectedVersion: number,
  ): Promise<MemberIntention>;
  archiveIntention(
    id: string,
    expectedVersion: number,
  ): Promise<MemberIntention>;
  createFutureMirror(
    intentionId: string,
    raw: FutureMirrorInput,
    idempotencyKey: string,
  ): Promise<FutureMirror>;
  getLatestFutureMirror(intentionId: string): Promise<FutureMirror>;
  getFutureMirror(intentionId: string, runId: string): Promise<FutureMirror>;
}
