import type {
  StarpathAnswerCommand,
  StarpathSkipRecallCommand,
  StarpathSnapshot,
} from "./schemas.ts";

export type StarpathProtectedRoute =
  | "starpath.read"
  | "starpath.start"
  | "starpath.answer"
  | "starpath.recall.skip";

export type StarpathCapabilityDecision = Readonly<{
  branch: "starpath";
  available: boolean;
  environment: "beta" | "production";
  jurisdiction: string;
  capabilityVersion: number;
  evaluatedAt: string;
  expiresAt: string;
  protectedRoutes: readonly StarpathProtectedRoute[];
}>;

/**
 * External RC1 consumer boundary. The implementation is owned by release
 * control; Starpath deliberately owns neither flag storage nor evaluation.
 */
export interface StarpathCapabilityEvaluator {
  evaluate(route: StarpathProtectedRoute): Promise<StarpathCapabilityDecision>;
}

export interface StarpathRepository {
  read(): Promise<StarpathSnapshot>;
  startOrResume(idempotencyKey: string): Promise<StarpathSnapshot>;
  answer(
    command: StarpathAnswerCommand,
    expectedVersion: number,
    idempotencyKey: string,
  ): Promise<StarpathSnapshot>;
  skipRecall(
    command: StarpathSkipRecallCommand,
    expectedVersion: number,
    idempotencyKey: string,
  ): Promise<StarpathSnapshot>;
}

export type StarpathErrorCode =
  | "starpath_unavailable"
  | "starpath_content_unavailable"
  | "starpath_replacement_unavailable"
  | "starpath_lifecycle_closed"
  | "starpath_idempotency_conflict"
  | "starpath_progress_conflict"
  | "starpath_session_not_found"
  | "starpath_session_conflict"
  | "starpath_node_locked"
  | "starpath_content_conflict"
  | "starpath_recall_conflict";

export class StarpathError extends Error {
  constructor(readonly code: StarpathErrorCode) {
    super(code);
    this.name = "StarpathError";
  }
}
