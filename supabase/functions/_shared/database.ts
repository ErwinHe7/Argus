import postgres, { type Sql } from "postgres";

import type {
  DatabaseClient,
  DatabasePool,
  DatabaseQueryResult,
} from "../../../ritual-investing-api/src/db/database-port.ts";

type ReservedSql = Awaited<ReturnType<Sql["reserve"]>>;

function databaseClient(connection: ReservedSql): DatabaseClient {
  let released = false;
  return {
    async query<Row = any>(
      text: string,
      values: readonly unknown[] = [],
    ): Promise<DatabaseQueryResult<Row>> {
      if (released) throw new Error("database_client_released");
      const rows = await connection.unsafe<Row[]>(text, [...values] as never[]);
      return {
        rows: [...rows] as Row[],
        rowCount: rows.count,
      };
    },
    release(): void {
      if (released) return;
      released = true;
      connection.release();
    },
  };
}

/**
 * SUPABASE_DB_URL must be Supabase's transaction-pooler URL for the dedicated
 * non-BYPASSRLS, NOINHERIT login selected by the caller. Its password is
 * provisioned and rotated out-of-band after migrations; it is never embedded
 * in the repo. Each login has membership only in its matching NOLOGIN
 * capability role, which every transaction assumes with SET LOCAL ROLE. Never
 * pass a postgres owner credential or secret API key here.
 */
function createDatabasePool(
  databaseUrl: string,
  allowedRole: RegExp,
): DatabasePool {
  const parsed = new URL(databaseUrl);
  if (!["postgres:", "postgresql:"].includes(parsed.protocol)) {
    throw new Error("invalid_supabase_database_url");
  }
  const username = decodeURIComponent(parsed.username);
  if (!allowedRole.test(username)) {
    throw new Error("invalid_supabase_database_role");
  }
  const sql = postgres(databaseUrl, {
    max: 4,
    idle_timeout: 20,
    connect_timeout: 10,
    prepare: false,
    ssl: parsed.hostname === "127.0.0.1" || parsed.hostname === "localhost"
      ? false
      : "require",
  });
  return Object.freeze({
    async connect() {
      return databaseClient(await sql.reserve());
    },
    async end() {
      await sql.end({ timeout: 5 });
    },
  });
}

export function createSupabaseDatabasePool(databaseUrl: string): DatabasePool {
  return createDatabasePool(databaseUrl, /^argus_edge(?:\.[a-z0-9_-]+)?$/i);
}

/** Dedicated public waitlist login with no member, admin, or brokerage role. */
export function createSupabaseWaitlistDatabasePool(
  databaseUrl: string,
): DatabasePool {
  return createDatabasePool(
    databaseUrl,
    /^argus_waitlist_edge(?:\.[a-z]{20})?$/,
  );
}

/** Dedicated non-inheriting login for the authenticated worker Edge function. */
export function createSupabaseWorkerDatabasePool(databaseUrl: string): DatabasePool {
  return createDatabasePool(
    databaseUrl,
    /^argus_worker_edge(?:\.[a-z]{20})?$/,
  );
}
