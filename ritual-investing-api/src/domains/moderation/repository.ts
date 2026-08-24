import { Pool, type PoolClient } from "@neondatabase/serverless";
import { z } from "zod";
import type { DatabasePoolFactory } from "../../db/client.ts";
import { adminRequestHash } from "../admin/request-hash.ts";
import {
  moderationCaseSchema,
  moderationReportSchema,
  type AdminModerationCase,
  type AdminModerationReport,
} from "./schemas.ts";

const moderationPageSchema = z
  .object({
    items: z.array(moderationReportSchema),
    next: z.string().nullable(),
  })
  .strict();

type JsonValueRow = { value: unknown };

export interface AdminModerationRepository {
  list(input: {
    actorStaffId: string;
    filters: Record<string, unknown>;
    limit: number;
    after?: string;
  }): Promise<{ items: AdminModerationReport[]; next: string | null }>;
  createCase(input: {
    actorStaffId: string;
    reportId: string;
    payload: unknown;
    requestId: string;
    idempotencyKey: string;
  }): Promise<AdminModerationCase>;
  getCase(input: {
    actorStaffId: string;
    caseId: string;
  }): Promise<AdminModerationCase | null>;
  patchCase(input: {
    actorStaffId: string;
    caseId: string;
    payload: unknown;
    expectedVersion: number;
    requestId: string;
  }): Promise<AdminModerationCase>;
}
export function createPostgresAdminModerationRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): AdminModerationRepository {
  const scoped = async <T>(
    staffId: string,
    fn: (client: PoolClient) => Promise<T>,
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
  const command = async (input: {
    actorStaffId: string;
    action: string;
    targetId: string;
    payload: unknown;
    expectedVersion?: number;
    requestId: string;
    idempotencyKey?: string;
  }): Promise<AdminModerationCase> =>
    moderationCaseSchema.parse(
      await scoped(
        input.actorStaffId,
        async (client) =>
          (
            await client.query<JsonValueRow>(
              "select ritual_private.admin_moderation_command($1,$2,$3,$4::jsonb,$5,$6,$7,$8)::jsonb value",
              [
                input.actorStaffId,
                input.action,
                input.targetId,
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
            )
          ).rows[0]!.value,
      ),
    );
  return {
    list: (input) =>
      scoped(
        input.actorStaffId,
        async (client) =>
          moderationPageSchema.parse(
            (
              await client.query<JsonValueRow>(
                "select ritual_private.admin_moderation_page($1::jsonb,$2,$3)::jsonb value",
                [
                  JSON.stringify(input.filters),
                  input.after ?? null,
                  input.limit,
                ],
              )
            ).rows[0]?.value ?? { items: [], next: null },
          ),
      ),
    createCase: (input) =>
      command({ ...input, action: "create_case", targetId: input.reportId }),
    getCase: (input) =>
      scoped(
        input.actorStaffId,
        async (client) =>
          ((value: unknown) =>
            value === null || value === undefined
              ? null
              : moderationCaseSchema.parse(value))(
            (
              await client.query<JsonValueRow>(
                "select ritual_private.admin_moderation_case($1)::jsonb value",
                [input.caseId],
              )
            ).rows[0]?.value,
          ),
      ),
    patchCase: (input) =>
      command({
        ...input,
        action: "patch_case",
        targetId: input.caseId,
        expectedVersion: input.expectedVersion,
      }),
  };
}
