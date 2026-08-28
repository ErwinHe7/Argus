import type { DatabaseClient } from "../../../../ritual-investing-api/src/db/database-port.ts";
import { sha256TextHex } from "../../../../ritual-investing-api/src/security/sha256.ts";
import type { WorkerPurgeSagaPort } from "../../../../ritual-investing-api/src/jobs/handlers.ts";
import type { WorkerAuthAdmin } from "./auth-admin.ts";
import type { PrivateStorage } from "./storage.ts";

export type PurgePhase =
  | "requested"
  | "neutralized"
  | "storage_purged"
  | "data_purged"
  | "complete";

export type WorkerTransaction = <T>(
  callback: (database: DatabaseClient) => Promise<T>,
) => Promise<T>;

export type PurgeFaultPoint =
  | "after_prepare"
  | "after_storage"
  | "after_data"
  | "after_auth"
  | "after_complete";

export function createMemberPurgeSaga(config: Readonly<{
  storage: PrivateStorage;
  authAdmin: WorkerAuthAdmin;
  transaction: WorkerTransaction;
  fault?: (point: PurgeFaultPoint) => Promise<void> | void;
}>): WorkerPurgeSagaPort {
  const fault = async (point: PurgeFaultPoint) => config.fault?.(point);
  return Object.freeze({
    async run(tombstoneId: string, keepAlive = async () => undefined) {
      const prepared = await config.transaction(async (database) => {
        const result = await database.query<{
          user_id: string;
          deletion_epoch: number;
          purge_phase: PurgePhase;
        }>("select * from argus_private.prepare_member_purge($1)", [tombstoneId]);
        const row = result.rows[0];
        if (row === undefined) throw new Error("invalid_event_payload");
        return row;
      });
      await fault("after_prepare");

      if (prepared.purge_phase === "complete") {
        return `privacy-purged:${tombstoneId}`;
      }

      if (prepared.purge_phase === "neutralized") {
        const objects = await config.transaction(async (database) =>
          (await database.query<{ bucket_id: string; object_path: string }>(
            "select * from argus_private.list_member_purge_objects($1)",
            [tombstoneId],
          )).rows
        );
        for (const bucket of ["member-media", "media-quarantine", "privacy-exports"]) {
          const paths = objects.filter((object) => object.bucket_id === bucket)
            .map((object) => object.object_path);
          for (let offset = 0; offset < paths.length; offset += 100) {
            await keepAlive();
            await config.storage.remove(bucket, paths.slice(offset, offset + 100));
          }
        }
        const receipts = await Promise.all(objects.map(async (object) => ({
          bucket_id: object.bucket_id,
          path_hash: await sha256TextHex(object.object_path),
        })));
        await config.transaction(async (database) => {
          await database.query(
            "select argus_private.mark_member_storage_purged($1,$2::jsonb)",
            [tombstoneId, JSON.stringify(receipts)],
          );
        });
      }
      await fault("after_storage");

      if (["neutralized", "storage_purged"].includes(prepared.purge_phase)) {
        await keepAlive();
        await config.transaction(async (database) => {
          await database.query("select argus_private.purge_member_argus_data($1)", [
            tombstoneId,
          ]);
        });
      }
      await fault("after_data");

      // Never run Auth Admin while a database transaction or tombstone lock is
      // held. A repeated DELETE/404 is success, so every crash boundary resumes.
      await keepAlive();
      await config.authAdmin.deleteUser(prepared.user_id);
      await fault("after_auth");

      await keepAlive();
      await config.transaction(async (database) => {
        await database.query("select argus_private.complete_member_purge($1)", [
          tombstoneId,
        ]);
      });
      await fault("after_complete");
      return `privacy-purged:${tombstoneId}`;
    },
  });
}
