import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../../../db/client.ts";
import { adminRequestHash } from "../request-hash.ts";

export type CatalogKind =
  | "asset"
  | "evidence_source"
  | "evidence_claim"
  | "seeded_creator"
  | "ritual_schedule";
export type CatalogPage = { items: unknown[]; next: string | null };
export interface AdminCatalogRepository {
  list(input: {
    actorStaffId: string;
    kind: CatalogKind;
    filters: Record<string, unknown>;
    limit: number;
    after?: string;
  }): Promise<CatalogPage>;
  get(input: {
    actorStaffId: string;
    kind: CatalogKind;
    id: string;
  }): Promise<unknown | null>;
  create(input: {
    actorStaffId: string;
    kind: CatalogKind;
    payload: unknown;
    requestId: string;
    idempotencyKey: string;
  }): Promise<any>;
  patch(input: {
    actorStaffId: string;
    kind: CatalogKind;
    id: string;
    payload: unknown;
    expectedVersion: number;
    requestId: string;
  }): Promise<any>;
  append(input: {
    actorStaffId: string;
    action: "asset_metric" | "coven_qualification" | "coven_verification";
    parentId: string;
    payload: unknown;
    requestId: string;
    idempotencyKey: string;
  }): Promise<any>;
  withdrawSchedule(input: {
    actorStaffId: string;
    scheduleId: string;
    expectedVersion: number;
    reason: string;
    requestId: string;
  }): Promise<void>;
}

export function createPostgresAdminCatalogRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): AdminCatalogRepository {
  const scoped = async <T>(
    staffId: string,
    fn: (client: any) => Promise<T>,
  ) => {
    const pool =
      poolFactory?.(databaseUrl) ??
      new Pool({ connectionString: databaseUrl, max: 1 });
    const client = await pool.connect();
    try {
      await client.query("begin");
      await client.query("set local role ritual_staff");
      await client.query("select set_config('ritual.staff_id',$1,true)", [
        staffId,
      ]);
      const value = await fn(client);
      await client.query("commit");
      return value;
    } catch (error) {
      await client.query("rollback").catch(() => undefined);
      throw error;
    } finally {
      client.release();
      await pool.end();
    }
  };
  const command = (input: {
    actorStaffId: string;
    action: string;
    targetId?: string;
    payload: unknown;
    expectedVersion?: number;
    requestId: string;
    idempotencyKey?: string;
  }) =>
    scoped(input.actorStaffId, async (client) => {
      const result = await client.query(
        "select ritual_private.admin_catalog_command($1,$2,$3,$4::jsonb,$5,$6,$7,$8)::jsonb value",
        [
          input.actorStaffId,
          input.action,
          input.targetId ?? null,
          JSON.stringify(input.payload),
          input.expectedVersion ?? null,
          input.requestId,
          input.idempotencyKey ?? null,
          await adminRequestHash({
            action: input.action,
            targetId: input.targetId,
            payload: input.payload,
            expectedVersion: input.expectedVersion,
          }),
        ],
      );
      return result.rows[0]!.value;
    });
  return {
    list: (input) =>
      scoped(input.actorStaffId, async (client) => {
        const result = await client.query(
          "select ritual_private.admin_catalog_page($1,$2::jsonb,$3,$4)::jsonb value",
          [
            input.kind,
            JSON.stringify(input.filters),
            input.after ?? null,
            input.limit,
          ],
        );
        return result.rows[0]?.value ?? { items: [], next: null };
      }),
    get: (input) =>
      scoped(input.actorStaffId, async (client) => {
        const result = await client.query(
          "select ritual_private.admin_catalog_item($1,$2)::jsonb value",
          [input.kind, input.id],
        );
        return result.rows[0]?.value ?? null;
      }),
    create: (input) => command({ ...input, action: `create:${input.kind}` }),
    patch: (input) =>
      command({
        ...input,
        action: `patch:${input.kind}`,
        targetId: input.id,
        expectedVersion: input.expectedVersion,
      }),
    append: async (input) => {
      const value = await command({
        ...input,
        action: `append:${input.action}`,
        targetId: input.parentId,
      });
      if (
        typeof value === "object" &&
        value !== null &&
        value._denied === "self_approval"
      )
        throw new Error("self_approval");
      return value;
    },
    withdrawSchedule: async (input) => {
      await command({
        actorStaffId: input.actorStaffId,
        action: "withdraw:ritual_schedule",
        targetId: input.scheduleId,
        payload: { reason: input.reason },
        expectedVersion: input.expectedVersion,
        requestId: input.requestId,
      });
    },
  };
}

export { createSupabaseAdminRepository as createSupabaseAdminCatalogRepository } from "../../../db/supabase-repositories.ts";
