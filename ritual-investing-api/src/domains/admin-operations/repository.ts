import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../../db/client.ts";
import type { StaffPrincipal } from "../../middleware/cloudflare-access.ts";
import type { AdminJob, AdminPrivacy } from "./schemas.ts";

type JobRow = Omit<AdminJob, "created_at" | "completed_at"> & {
  created_at: Date;
  completed_at: Date | null;
};
type PrivacyRow = Omit<
  AdminPrivacy,
  "snapshot_at" | "queued_at" | "completed_at"
> & {
  snapshot_at: Date | null;
  queued_at: Date | null;
  completed_at: Date | null;
};
type Page<T> = { items: T[]; next: string | null };
type PageInput = { status?: string; limit: number; after?: string };

const jobView = (row: JobRow): AdminJob => ({
  ...row,
  created_at: row.created_at.toISOString(),
  completed_at: row.completed_at?.toISOString() ?? null,
});
const privacyView = (row: PrivacyRow): AdminPrivacy => ({
  ...row,
  snapshot_at: row.snapshot_at?.toISOString() ?? null,
  queued_at: row.queued_at?.toISOString() ?? null,
  completed_at: row.completed_at?.toISOString() ?? null,
});

function pagePosition(
  value: string | undefined,
): [string | null, string | null] {
  if (value === undefined) return [null, null];
  const separator = value.lastIndexOf("|");
  if (separator <= 0) throw new Error("invalid_cursor_position");
  return [value.slice(0, separator), value.slice(separator + 1)];
}

async function digest(value: string): Promise<string> {
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(hash)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export class AdminOperationConflictError extends Error {
  readonly code: "idempotency_conflict" | "not_retryable" | "not_found";

  constructor(code: "idempotency_conflict" | "not_retryable" | "not_found") {
    super(code);
    this.name = "AdminOperationConflictError";
    this.code = code;
  }
}

export interface AdminOperationsRepository {
  listJobs(staff: StaffPrincipal, input: PageInput): Promise<Page<AdminJob>>;
  getJob(staff: StaffPrincipal, id: string): Promise<AdminJob | null>;
  retryJob(
    staff: StaffPrincipal,
    id: string,
    reason: string,
    requestId: string,
    idempotencyKey: string,
  ): Promise<AdminJob>;
  listPrivacy(
    staff: StaffPrincipal,
    input: PageInput,
  ): Promise<Page<AdminPrivacy>>;
  getPrivacy(staff: StaffPrincipal, id: string): Promise<AdminPrivacy | null>;
  retryPrivacy(
    staff: StaffPrincipal,
    id: string,
    reason: string,
    requestId: string,
    idempotencyKey: string,
  ): Promise<{ outboxId: string; consumer: string }>;
}

function mapCommandError(error: unknown): never {
  if (error instanceof Error) {
    if (error.message.includes("idempotency_conflict"))
      throw new AdminOperationConflictError("idempotency_conflict");
    if (error.message.includes("not retryable"))
      throw new AdminOperationConflictError("not_retryable");
    if (error.message.includes("not found"))
      throw new AdminOperationConflictError("not_found");
  }
  throw error;
}

export function createPostgresAdminOperationsRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): AdminOperationsRepository {
  const scoped = async <T>(
    staff: StaffPrincipal,
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
        staff.id,
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

  return {
    listJobs: (staff, input) =>
      scoped(staff, async (client) => {
        const [afterCreated, afterId] = pagePosition(input.after);
        const rows = (
          await client.query(
            "select * from ritual_private.admin_job_page($1,$2,$3,$4)",
            [input.status ?? null, afterCreated, afterId, input.limit + 1],
          )
        ).rows as JobRow[];
        const items = rows.slice(0, input.limit).map(jobView);
        const tail =
          rows.length > input.limit ? rows[input.limit - 1] : undefined;
        return {
          items,
          next:
            tail === undefined
              ? null
              : `${tail.created_at.toISOString()}|${tail.id}`,
        };
      }),
    getJob: (staff, id) =>
      scoped(staff, async (client) => {
        const row = (
          await client.query(
            "select * from ritual_private.admin_job_metadata($1)",
            [id],
          )
        ).rows[0] as JobRow | undefined;
        return row === undefined ? null : jobView(row);
      }),
    retryJob: async (staff, id, reason, requestId, idempotencyKey) => {
      try {
        return await scoped(staff, async (client) => {
          const requestHash = await digest(JSON.stringify({ id, reason }));
          const row = (
            await client.query(
              "select * from ritual_private.admin_retry_job_command($1,$2,$3,$4,$5,$6)",
              [id, staff.id, reason, requestId, idempotencyKey, requestHash],
            )
          ).rows[0] as JobRow;
          return jobView(row);
        });
      } catch (error) {
        return mapCommandError(error);
      }
    },
    listPrivacy: (staff, input) =>
      scoped(staff, async (client) => {
        const [afterQueued, afterId] = pagePosition(input.after);
        const rows = (
          await client.query(
            "select * from ritual_private.admin_privacy_page($1,$2,$3,$4)",
            [input.status ?? null, afterQueued, afterId, input.limit + 1],
          )
        ).rows as PrivacyRow[];
        const items = rows.slice(0, input.limit).map(privacyView);
        const tail =
          rows.length > input.limit ? rows[input.limit - 1] : undefined;
        return {
          items,
          next:
            tail?.queued_at === null || tail === undefined
              ? null
              : `${tail.queued_at.toISOString()}|${tail.id}`,
        };
      }),
    getPrivacy: (staff, id) =>
      scoped(staff, async (client) => {
        const row = (
          await client.query(
            "select * from ritual_private.admin_privacy_metadata($1)",
            [id],
          )
        ).rows[0] as PrivacyRow | undefined;
        return row === undefined ? null : privacyView(row);
      }),
    retryPrivacy: async (staff, id, reason, requestId, idempotencyKey) => {
      try {
        return await scoped(staff, async (client) => {
          const requestHash = await digest(JSON.stringify({ id, reason }));
          const result = (await client.query(
            "select * from ritual_private.admin_retry_privacy_command($1,$2,$3,$4,$5,$6)",
            [id, staff.id, reason, requestId, idempotencyKey, requestHash],
          )) as { rows: Array<{ outbox_id: string; consumer: string }> };
          return {
            outboxId: result.rows[0]!.outbox_id,
            consumer: result.rows[0]!.consumer,
          };
        });
      } catch (error) {
        return mapCommandError(error);
      }
    },
  };
}
