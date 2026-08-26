import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../../db/client.ts";
import type { AdminAuditEvent } from "./schemas.ts";

export type AdminAuditPage = { items: AdminAuditEvent[]; next: string | null };
export interface AdminRepository {
  listAudit(input: {
    actorStaffId: string;
    filterActorStaffId?: string;
    action?: string;
    targetKind?: string;
    from?: string;
    to?: string;
    limit: number;
    after?: string;
  }): Promise<AdminAuditPage>;
}

export function createPostgresAdminRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): AdminRepository {
  return {
    listAudit: async (input) => {
      const pool =
        poolFactory?.(databaseUrl) ??
        new Pool({ connectionString: databaseUrl, max: 1 });
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query("set local role ritual_staff");
        await client.query("select set_config('ritual.staff_id',$1,true)", [
          input.actorStaffId,
        ]);
        const result = await client.query(
          "select ritual_private.admin_audit_page($1,$2,$3,$4,$5,$6,$7)::jsonb value",
          [
            input.filterActorStaffId ?? null,
            input.action ?? null,
            input.targetKind ?? null,
            input.from ?? null,
            input.to ?? null,
            input.after ?? null,
            input.limit,
          ],
        );
        await client.query("commit");
        return (
          (result.rows[0]?.value as AdminAuditPage | undefined) ?? {
            items: [],
            next: null,
          }
        );
      } catch (error) {
        await client.query("rollback").catch(() => undefined);
        throw error;
      } finally {
        client.release();
        await pool.end();
      }
    },
  };
}
