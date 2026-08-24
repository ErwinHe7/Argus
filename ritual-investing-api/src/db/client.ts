import { Pool, type PoolClient } from "@neondatabase/serverless";

import type { RequestDatabaseContext } from "./request-context";

export type ResolvedAccountContext = Pick<
  RequestDatabaseContext,
  | "accountId"
  | "tenantId"
  | "accountStatus"
  | "tenantStatus"
  | "revocationEpoch"
>;

type ApplicationDatabaseRole =
  | "ritual_identity_resolver"
  | "ritual_runtime";

export type DatabasePool = {
  connect(): Promise<PoolClient>;
  end(): Promise<void>;
};

export type DatabasePoolFactory = (databaseUrl: string) => DatabasePool;

const neonPoolFactory: DatabasePoolFactory = (databaseUrl) =>
  new Pool({ connectionString: databaseUrl, max: 1 });

async function withDatabaseRole<T>(
  databaseUrl: string,
  role: ApplicationDatabaseRole,
  callback: (client: PoolClient) => Promise<T>,
  poolFactory: DatabasePoolFactory = neonPoolFactory,
): Promise<T> {
  const pool = poolFactory(databaseUrl);
  let client: PoolClient | undefined;
  try {
    client = await pool.connect();
    await client.query("begin");
    await client.query(`set local role ${role}`);
    const result = await callback(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client?.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client?.release();
    await pool.end();
  }
}

interface ResolverRow {
  account_id: string;
  tenant_id: string;
  account_status: "active";
  tenant_status: "active";
  revocation_epoch: number;
}

export async function resolveAccountContext(
  identityDatabaseUrl: string,
  verifiedSubject: string,
): Promise<ResolvedAccountContext | null> {
  if (verifiedSubject.length < 1 || verifiedSubject.length > 255) {
    return null;
  }

  const rows = await withDatabaseRole(
    identityDatabaseUrl,
    "ritual_identity_resolver",
    async (client) => {
      const result = await client.query<ResolverRow>(
        "select account_id, tenant_id, account_status, tenant_status, revocation_epoch from ritual_private.resolve_account_context($1)",
        [verifiedSubject],
      );
      return result.rows;
    },
  );
  const row = rows[0];
  if (rows.length !== 1 || row === undefined) {
    return null;
  }

  return {
    accountId: row.account_id,
    tenantId: row.tenant_id,
    accountStatus: row.account_status,
    tenantStatus: row.tenant_status,
    revocationEpoch: Number(row.revocation_epoch),
  };
}

/**
 * The only runtime-client seam installs transaction-local scope before the
 * callback receives the connection, then commits/rolls back and closes it.
 */
export async function withScopedRuntimeClient<T>(
  runtimeDatabaseUrl: string,
  context: RequestDatabaseContext,
  callback: (client: PoolClient) => Promise<T>,
  poolFactory?: DatabasePoolFactory,
): Promise<T> {
  return withDatabaseRole(runtimeDatabaseUrl, "ritual_runtime", async (client) => {
    await client.query(
      "select set_config('ritual.tenant_id', $1, true), set_config('ritual.principal', $2, true), set_config('ritual.account_id', $3, true), set_config('ritual.revocation_epoch', $4, true)",
      [
        context.tenantId,
        context.principal,
        context.accountId,
        String(context.revocationEpoch),
      ],
    );
    await client.query("select ritual_private.assert_runtime_scope()");
    return callback(client);
  }, poolFactory);
}
