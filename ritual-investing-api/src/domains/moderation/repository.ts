import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";

export function createSupabaseModerationRepository(
  database: DatabaseTransaction,
) {
  return Object.freeze({
    report: async (
      input: Readonly<{
        targetKind: string;
        targetId: string;
        reasonCode: string;
        details?: string;
      }>,
    ) => {
      const created = await database.query<{ id: string }>(
        `select argus_private.create_content_report($1,$2,$3,$4) as id`,
        [
          input.targetKind,
          input.targetId,
          input.reasonCode,
          input.details ?? null,
        ],
      );
      const result = await database.query<JsonObject>(
        `select * from argus_app.content_reports
            where tenant_id=argus_private.trusted_request_tenant_id()
              and lifecycle_id=argus_private.trusted_request_lifecycle_id()
              and id=$1`,
        [first(created.rows).id],
      );
      return first(result.rows);
    },
    decide: async (
      caseId: string,
      expectedVersion: number,
      decision: JsonObject,
      correlationId: string,
    ) => {
      const result = await database.query<JsonObject>(
        `update argus_app.moderation_cases
              set status = $3,
                  decision_payload = $4::jsonb,
                  version = version + 1,
                  updated_at = clock_timestamp()
            where id = $1 and version = $2
          returning *`,
        [caseId, expectedVersion, decision.status, JSON.stringify(decision)],
      );
      if (result.rows.length !== 1) {
        throw new RepositoryRevisionConflictError();
      }
      await database.query(
        `insert into argus_private.admin_audit_events(
             actor_user_id, action, target_kind, target_id, outcome,
             correlation_id
           ) values (argus_private.request_user_id(), 'moderation.decide', 'moderation_case', $1,
                     'allowed', $2)`,
        [caseId, correlationId],
      );
      return result.rows[0]!;
    },
  });
}
