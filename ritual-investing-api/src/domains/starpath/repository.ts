import type { DatabaseTransaction } from "../../db/database-port.ts";
import { sha256TextHex } from "../../security/sha256.ts";
import type {
  StarpathAnswerCommand,
  StarpathSkipRecallCommand,
  StarpathSnapshot,
} from "./schemas.ts";
import { starpathSnapshotSchema } from "./schemas.ts";
import {
  StarpathError,
  type StarpathCapabilityDecision,
  type StarpathCapabilityEvaluator,
  type StarpathProtectedRoute,
  type StarpathRepository,
} from "./ports.ts";

type JsonRecord = Record<string, unknown>;

type AuthorizedScope = Readonly<{
  decision: StarpathCapabilityDecision;
  authority: Readonly<{
    manifestId: string;
    manifestVersion: string;
    policyVersion: string;
    environment: "beta" | "production";
    jurisdiction: string;
    themeId: string;
  }>;
}>;

function record(value: unknown): JsonRecord {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new StarpathError("starpath_content_unavailable");
  }
  return value as JsonRecord;
}

function array(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    throw new StarpathError("starpath_content_unavailable");
  }
  return value;
}

function string(value: unknown): string {
  if (typeof value !== "string") {
    throw new StarpathError("starpath_content_unavailable");
  }
  return value;
}

function number(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(parsed)) {
    throw new StarpathError("starpath_content_unavailable");
  }
  return parsed;
}

function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") {
    throw new StarpathError("starpath_content_unavailable");
  }
  return value;
}

function nullableString(value: unknown): string | null {
  return value === null ? null : string(value);
}

function iso(value: unknown): string {
  const date = value instanceof Date ? value : new Date(string(value));
  if (!Number.isFinite(date.getTime())) {
    throw new StarpathError("starpath_content_unavailable");
  }
  return date.toISOString();
}

function postgresMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as { message: unknown }).message);
  }
  return "";
}

function mapPostgresError(error: unknown): never {
  const message = postgresMessage(error);
  if (message.includes("starpath_content_unavailable") ||
      message.includes("starpath_manifest_unavailable") ||
      message.includes("starpath_capability_scope_invalid")) {
    throw new StarpathError("starpath_content_unavailable");
  }
  if (message.includes("starpath_replacement_unavailable")) {
    throw new StarpathError("starpath_replacement_unavailable");
  }
  if (message.includes("member_lifecycle_not_open")) {
    throw new StarpathError("starpath_lifecycle_closed");
  }
  if (message.includes("idempotency_conflict")) {
    throw new StarpathError("starpath_idempotency_conflict");
  }
  if (message.includes("starpath_progress_version_conflict")) {
    throw new StarpathError("starpath_progress_conflict");
  }
  if (message.includes("starpath_session_not_found")) {
    throw new StarpathError("starpath_session_not_found");
  }
  if (message.includes("starpath_session_not_active") ||
      message.includes("starpath_replacement_scope_invalid")) {
    throw new StarpathError("starpath_session_conflict");
  }
  if (message.includes("starpath_node_locked")) {
    throw new StarpathError("starpath_node_locked");
  }
  if (message.includes("starpath_content_lineage_invalid")) {
    throw new StarpathError("starpath_content_conflict");
  }
  if (message.includes("starpath_recall_not_presented")) {
    throw new StarpathError("starpath_recall_conflict");
  }
  throw error;
}

async function databaseCall<T>(operation: () => Promise<T>): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    return mapPostgresError(error);
  }
}

function authorityRecord(value: unknown): AuthorizedScope["authority"] {
  const raw = record(value);
  const environment = string(raw.environment);
  if (environment !== "beta" && environment !== "production") {
    throw new StarpathError("starpath_content_unavailable");
  }
  return Object.freeze({
    manifestId: string(raw.manifestId),
    manifestVersion: string(raw.manifestVersion),
    policyVersion: string(raw.policyVersion),
    environment,
    jurisdiction: string(raw.jurisdiction),
    themeId: string(raw.themeId),
  });
}

async function currentDatabaseTime(
  database: DatabaseTransaction,
): Promise<number> {
  const result = await database.query<{ now: string | Date }>(
    "select pg_catalog.clock_timestamp() as now",
  );
  const value = result.rows[0]?.now;
  if (value === undefined) throw new StarpathError("starpath_unavailable");
  return new Date(value).getTime();
}

async function authorize(
  database: DatabaseTransaction,
  evaluator: StarpathCapabilityEvaluator,
  route: StarpathProtectedRoute,
): Promise<AuthorizedScope> {
  let decision: StarpathCapabilityDecision;
  try {
    decision = await evaluator.evaluate(route);
  } catch (error) {
    if (error instanceof StarpathError) throw error;
    throw new StarpathError("starpath_unavailable");
  }
  const now = await currentDatabaseTime(database);
  const evaluatedAt = new Date(decision.evaluatedAt).getTime();
  const expiresAt = new Date(decision.expiresAt).getTime();
  if (
    decision.branch !== "starpath" || !decision.available ||
    !decision.protectedRoutes.includes(route) ||
    !Number.isSafeInteger(decision.capabilityVersion) ||
    decision.capabilityVersion <= 0 ||
    !["beta", "production"].includes(decision.environment) ||
    !/^[A-Z]{2,8}$/.test(decision.jurisdiction) ||
    !Number.isFinite(evaluatedAt) || !Number.isFinite(expiresAt) ||
    evaluatedAt > now + 5_000 || expiresAt <= now || expiresAt <= evaluatedAt
  ) {
    throw new StarpathError("starpath_unavailable");
  }
  const result = await databaseCall(() =>
    database.query<{ authority: unknown }>(
      `select argus_private.resolve_starpath_member_authority($1,$2)
              as authority`,
      [decision.environment, decision.jurisdiction],
    )
  );
  const authority = authorityRecord(result.rows[0]?.authority);
  if (
    authority.environment !== decision.environment ||
    authority.jurisdiction !== decision.jurisdiction
  ) {
    throw new StarpathError("starpath_content_unavailable");
  }
  return Object.freeze({ decision, authority });
}

async function requestHash(value: JsonRecord): Promise<string> {
  return sha256TextHex(JSON.stringify(value));
}

function rawSession(raw: JsonRecord | null) {
  if (raw === null) return null;
  return {
    id: string(raw.id),
    state: string(raw.state),
    started_at: iso(raw.startedAt),
    last_action_at: iso(raw.lastActionAt),
    explicit_start: boolean(raw.explicitStart),
    replacement_of_session_id: nullableString(raw.replacementOfSessionId),
  };
}

function mapEvidence(value: unknown) {
  const raw = record(value);
  return {
    ordinal: number(raw.ordinal),
    canonical_url: string(raw.canonicalUrl),
    source_title: string(raw.sourceTitle),
    publisher: string(raw.publisher),
    source_observed_at: iso(raw.sourceObservedAt),
    effective_at: raw.effectiveAt === null ? null : iso(raw.effectiveAt),
    retrieved_at: iso(raw.retrievedAt),
    current_until: iso(raw.currentUntil),
    claim_summary: string(raw.claimSummary),
  };
}

function mapKnowledgeCheck(value: unknown) {
  const raw = record(value);
  return {
    id: string(raw.id),
    prompt: string(raw.prompt),
    options: array(raw.options).map((value) => {
      const option = record(value);
      if ("isCorrect" in option || "is_correct" in option) {
        throw new StarpathError("starpath_content_unavailable");
      }
      return {
        id: string(option.id),
        ordinal: number(option.ordinal),
        label: string(option.label),
      };
    }),
  };
}

function mapNode(value: unknown, completed: Set<string>, current: number) {
  const raw = record(value);
  const lessonId = string(raw.lessonId);
  const nodeOrdinal = number(raw.nodeOrdinal);
  return {
    node_ordinal: nodeOrdinal,
    pathway_ordinal: number(raw.pathwayOrdinal),
    pathway_position: number(raw.pathwayPosition),
    state: completed.has(lessonId)
      ? "completed" as const
      : nodeOrdinal === current
      ? "current" as const
      : "locked" as const,
    lesson_id: lessonId,
    revision_id: string(raw.revisionId),
    title: string(raw.title),
    guide: {
      tarot_key: string(raw.tarotKey),
      accessible_label: string(raw.tarotAccessibleLabel),
    },
    mythic_mnemonic: string(raw.mythicMnemonic),
    factual_summary: string(raw.factualSummary),
    factual_sections: array(raw.factualSections).map((value) => {
      const section = record(value);
      return {
        ordinal: number(section.ordinal),
        kind: string(section.kind),
        heading: string(section.heading),
        body: string(section.body),
        uncertainty: string(section.uncertainty),
        observed_at: iso(section.observedAt),
        evidence: array(section.evidence).map(mapEvidence),
      };
    }),
    material_limitations: string(raw.materialLimitations),
    risk_context: string(raw.riskContext),
    recall_prompt: string(raw.recallPrompt),
    rowan_explanation: string(raw.rowanExplanation),
    knowledge_check: mapKnowledgeCheck(raw.knowledgeCheck),
  };
}

async function snapshot(
  database: DatabaseTransaction,
  scope: AuthorizedScope,
  rawStateValue: unknown,
): Promise<StarpathSnapshot> {
  const state = record(rawStateValue);
  const available = state.availability === "available";
  const rawStateSession = available ? record(state.session) : null;
  const manifestId = rawStateSession === null
    ? scope.authority.manifestId
    : string(rawStateSession.manifestId);
  const themeId = rawStateSession === null
    ? scope.authority.themeId
    : string(rawStateSession.themeId);
  if (
    rawStateSession !== null &&
    number(rawStateSession.capabilityVersion) > scope.decision.capabilityVersion
  ) {
    throw new StarpathError("starpath_unavailable");
  }
  const projectionResult = await databaseCall(() =>
    database.query<{ projection: unknown }>(
      `select argus_private.read_starpath_curriculum_projection($1,$2,$3,$4)
              as projection`,
      [
        manifestId,
        themeId,
        scope.decision.environment,
        scope.decision.jurisdiction,
      ],
    )
  );
  const projection = record(projectionResult.rows[0]?.projection);
  const manifest = record(projection.manifest);
  const theme = record(projection.theme);
  const progress = available ? record(state.progress) : null;
  const completed = new Set(
    available ? array(state.completedLessonIds).map(string) : [],
  );
  const currentNodeOrdinal = progress === null
    ? 1
    : number(progress.currentNodeOrdinal);
  const nodes = array(projection.nodes).map((value) =>
    mapNode(value, completed, currentNodeOrdinal)
  );
  const recallRaw = available && state.recall !== null
    ? record(state.recall)
    : null;
  const recallNode = recallRaw === null
    ? undefined
    : nodes.find((node) =>
      node.lesson_id === string(recallRaw.lessonId) &&
      node.revision_id === string(recallRaw.revisionId)
    );
  if (recallRaw !== null && recallNode === undefined) {
    throw new StarpathError("starpath_content_unavailable");
  }
  const answerRaw = state.answer === undefined || state.answer === null
    ? null
    : record(state.answer);
  const version = progress === null ? 1 : number(progress.version);
  try {
    return starpathSnapshotSchema.parse({
      availability: available ? "available" : "not_started",
      version,
      authority: {
        capability_version: scope.decision.capabilityVersion,
        manifest_id: string(manifest.id),
        manifest_version: string(manifest.manifestVersion),
        policy_version: string(manifest.policyVersion),
        environment: string(manifest.environment),
        jurisdiction: string(manifest.jurisdiction),
      },
      session: rawSession(rawStateSession),
      theme: available
        ? {
          id: string(theme.id),
          key: string(theme.key),
          title: string(theme.title),
          horoscope_frame: string(theme.horoscopeFrame),
          factual_focus: string(theme.factualFocus),
          accessible_label: string(theme.accessibleLabel),
        }
        : null,
      progress: progress === null
        ? null
        : {
          current_node_ordinal: currentNodeOrdinal,
          version,
          updated_at: iso(progress.updatedAt),
        },
      nodes,
      recall: recallRaw === null || recallNode === undefined
        ? null
        : {
          id: string(recallRaw.id),
          lesson_id: recallNode.lesson_id,
          revision_id: recallNode.revision_id,
          question_id: string(recallRaw.questionId),
          status: "presented",
          prompt: recallNode.recall_prompt,
          knowledge_check: recallNode.knowledge_check,
        },
      command_effect: state.commandEffect === undefined
        ? null
        : string(state.commandEffect),
      answer: answerRaw === null
        ? null
        : {
          is_correct: boolean(answerRaw.isCorrect),
          explanation: string(answerRaw.explanation),
        },
    });
  } catch (error) {
    if (error instanceof StarpathError) throw error;
    throw new StarpathError("starpath_content_unavailable");
  }
}

export function createBlockedStarpathCapabilityEvaluator(): StarpathCapabilityEvaluator {
  return Object.freeze({
    evaluate: async () => {
      throw new StarpathError("starpath_unavailable");
    },
  });
}

export function createSupabaseStarpathRepository(
  database: DatabaseTransaction,
  evaluator: StarpathCapabilityEvaluator,
): StarpathRepository {
  return Object.freeze({
    read: async () => {
      const scope = await authorize(database, evaluator, "starpath.read");
      const state = await databaseCall(() =>
        database.query<{ state: unknown }>(
          `select argus_private.read_starpath_state($1,$2) as state`,
          [scope.authority.manifestId, scope.authority.themeId],
        )
      );
      return snapshot(database, scope, state.rows[0]?.state);
    },
    startOrResume: async (idempotencyKey: string) => {
      const scope = await authorize(database, evaluator, "starpath.start");
      const hash = await requestHash({ operation: "starpath.start" });
      const state = await databaseCall(() =>
        database.query<{ state: unknown }>(
          `select argus_private.start_or_resume_starpath_session(
                    $1,$2,$3,$4,$5
                  ) as state`,
          [
            idempotencyKey,
            hash,
            scope.authority.manifestId,
            scope.authority.themeId,
            scope.decision.capabilityVersion,
          ],
        )
      );
      return snapshot(database, scope, state.rows[0]?.state);
    },
    answer: async (
      command: StarpathAnswerCommand,
      expectedVersion: number,
      idempotencyKey: string,
    ) => {
      const scope = await authorize(database, evaluator, "starpath.answer");
      const attemptKind = command.attempt_kind ?? "node";
      const hash = await requestHash({
        operation: "starpath.answer",
        session_id: command.session_id,
        manifest_id: command.manifest_id,
        revision_id: command.revision_id,
        question_id: command.question_id,
        option_id: command.option_id,
        attempt_kind: attemptKind,
        expected_version: expectedVersion,
      });
      const state = await databaseCall(() =>
        database.query<{ state: unknown }>(
          `select argus_private.answer_starpath_question(
                    $1,$2,$3,$4,$5,$6,$7,$8,$9
                  ) as state`,
          [
            idempotencyKey,
            hash,
            command.session_id,
            command.manifest_id,
            command.revision_id,
            command.question_id,
            command.option_id,
            expectedVersion,
            attemptKind,
          ],
        )
      );
      return snapshot(database, scope, state.rows[0]?.state);
    },
    skipRecall: async (
      command: StarpathSkipRecallCommand,
      expectedVersion: number,
      idempotencyKey: string,
    ) => {
      const scope = await authorize(
        database,
        evaluator,
        "starpath.recall.skip",
      );
      const hash = await requestHash({
        operation: "starpath.recall.skip",
        session_id: command.session_id,
        expected_version: expectedVersion,
      });
      const state = await databaseCall(() =>
        database.query<{ state: unknown }>(
          `select argus_private.skip_starpath_recall($1,$2,$3,$4) as state`,
          [idempotencyKey, hash, command.session_id, expectedVersion],
        )
      );
      return snapshot(database, scope, state.rows[0]?.state);
    },
  });
}
