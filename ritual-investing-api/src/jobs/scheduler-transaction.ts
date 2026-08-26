import { Pool } from "@neondatabase/serverless";

import type { DatabasePoolFactory } from "../db/client.ts";

export type SchedulerTransactionRole =
  | "ritual_scheduler"
  | "ritual_audit_reconciler";

export async function withSchedulerTransaction<T>(
  databaseUrl: string,
  callback: (
    client: Awaited<ReturnType<ReturnType<DatabasePoolFactory>["connect"]>>,
  ) => Promise<T>,
  poolFactory?: DatabasePoolFactory,
  role: SchedulerTransactionRole = "ritual_scheduler",
): Promise<T> {
  const pool =
    poolFactory?.(databaseUrl) ??
    new Pool({ connectionString: databaseUrl, max: 1 });
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query(`set local role ${role}`);
    await client.query("set local lock_timeout='5s'");
    await client.query("set local statement_timeout='45s'");
    const result = await callback(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}
