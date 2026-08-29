import {
  type JsonObject,
  RepositoryNotFoundError,
  RepositoryStepUpRequiredError,
  first,
} from "../../db/repository-support.ts";
import type { DatabaseTransaction } from "../../db/database-port.ts";

export function createSupabasePrivacyRepository(
  database: DatabaseTransaction,
) {
  return Object.freeze({
    list: async () =>
      (
        await database.query<JsonObject>(
          `select * from argus_private.list_member_privacy_requests()`,
        )
      ).rows,
    requestExport: async (scopedDedupeKey: string) => {
      const created = await database.query<{ id: string }>(
        `select argus_private.request_privacy_export($1) as id`,
        [scopedDedupeKey],
      );
      const request = first(created.rows);
      const createdRequest = await database.query<JsonObject>(
        `select * from argus_private.list_member_privacy_requests()
          where id=$1`,
        [request.id],
      );
      return first(createdRequest.rows);
    },
    requestDeletion: async (
      receiptHash: string,
      sessionId: string,
      dedupeKey: string,
    ) => {
      try {
        const result = await database.query<{ id: string }>(
          "select argus_private.begin_member_deletion($1,$2,$3) as id",
          [receiptHash, sessionId, dedupeKey],
        );
        const deletion = first(result.rows);
        const request = await database.query<JsonObject>(
          `select * from argus_private.list_member_privacy_requests()
            where id=$1`,
          [deletion.id],
        );
        return first(request.rows);
      } catch (error) {
        if (
          error instanceof Error &&
          (error.message === "step_up_required" ||
            error.message.includes("step_up_required"))
        ) {
          throw new RepositoryStepUpRequiredError();
        }
        throw error;
      }
    },
    getDeletionTombstone: async () => {
      const result = await database.query<JsonObject>(
        `select * from argus_private.get_member_deletion_tombstone()`,
      );
      return result.rows[0] ?? null;
    },
    prepareDownload: async (requestId: string) => {
      const result = await database.query<{
        access_lease_id: string;
        bucket_id: string;
        object_path: string;
        expires_in_seconds: number;
      }>(
        `select * from argus_private.prepare_privacy_export_download($1)`,
        [requestId],
      );
      if (result.rows[0] === undefined) throw new RepositoryNotFoundError();
      return result.rows[0];
    },
    confirmDownload: async (accessLeaseId: string) => {
      const current = await database.query<{ current: boolean }>(
        `select argus_private.confirm_privacy_export_download($1) as current`,
        [accessLeaseId],
      );
      if (current.rows[0]?.current !== true) {
        throw new RepositoryNotFoundError();
      }
    },
  });
}
