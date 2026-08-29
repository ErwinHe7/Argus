import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryStepUpRequiredError,
} from "../../db/repository-support.ts";
import { sha256TextHex } from "../../security/sha256.ts";

export function createSupabaseAdminOperationsRepository(
  database: DatabaseTransaction,
  staffSessionId: string,
) {
  return Object.freeze({
    listJobs: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `select * from argus_private.list_job_diagnostics($1)`,
          [limit],
        )
      ).rows,
    listPrivacy: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `select * from argus_private.list_privacy_request_diagnostics($1)`,
          [limit],
        )
      ).rows,
    listAudit: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `select id,actor_user_id,action,target_kind,target_id,outcome,
                    reason_code,correlation_id,occurred_at
               from argus_private.admin_audit_events
              order by occurred_at desc, id desc
              limit $1`,
          [limit],
        )
      ).rows,
    listBrokerageDiagnostics: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `with diagnostics as (
               select connection.id,'connection_health'::text as kind,
                      connection.status,connection.last_error_code as reason_code,
                      connection.updated_at as observed_at
                 from (
                   select id,status,last_error_code,updated_at
                     from argus_brokerage.connections
                    order by updated_at desc,id desc
                    limit $1
                 ) connection
               union all
               select command.id,'provider_command'::text,command.state,
                      null::text,command.updated_at
                 from (
                   select id,state,updated_at
                     from argus_private.provider_commands
                    order by updated_at desc,id desc
                    limit $1
                 ) command
               union all
               select reconciliation.id,'reconciliation'::text,
                      reconciliation.status,reconciliation.last_error_code,
                      reconciliation.updated_at
                 from (
                   select id,status,last_error_code,updated_at
                     from argus_private.reconciliation_records
                    order by updated_at desc,id desc
                    limit $1
                 ) reconciliation
             )
             select argus_private.admin_diagnostic_correlation(
                      diagnostics.kind,diagnostics.id
                    ) as correlation_id,
                    diagnostics.kind,diagnostics.status,
                    case when diagnostics.reason_code is null then null
                         when diagnostics.reason_code ~ '^[a-z][a-z0-9_]{0,63}$'
                           then diagnostics.reason_code
                         else 'provider_error_redacted' end as reason_code,
                    diagnostics.observed_at
               from diagnostics
              order by diagnostics.observed_at desc,diagnostics.id desc
              limit $1`,
          [limit],
        )
      ).rows,
    requestJobRetry: async (
      jobId: string,
      dedupeKey: string,
      receipt: string,
    ) =>
      (async () => {
        const result = await database.query<{ outbox_id: string }>(
          `select argus_private.request_admin_job_retry($1,$2,$3,$4) as outbox_id`,
          [
            jobId,
            dedupeKey,
            await sha256TextHex(receipt),
            staffSessionId,
          ],
        );
        return first(result.rows).outbox_id;
      })().catch((error: unknown) => {
        if (
          error instanceof Error && error.message.includes("step_up_required")
        ) {
          throw new RepositoryStepUpRequiredError();
        }
        throw error;
      }),
    requestPrivacyRetry: async (
      requestId: string,
      dedupeKey: string,
      receipt: string,
    ) =>
      (async () => {
        const result = await database.query<{ outbox_id: string }>(
          `select argus_private.request_admin_privacy_retry($1,$2,$3,$4) as outbox_id`,
          [
            requestId,
            dedupeKey,
            await sha256TextHex(receipt),
            staffSessionId,
          ],
        );
        return first(result.rows).outbox_id;
      })().catch((error: unknown) => {
        if (
          error instanceof Error && error.message.includes("step_up_required")
        ) {
          throw new RepositoryStepUpRequiredError();
        }
        throw error;
      }),
  });
}
