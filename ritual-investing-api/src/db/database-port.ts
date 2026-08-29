export type DatabaseQueryResult<Row = any> = {
  rows: Row[];
  rowCount?: number | null;
};

export type DatabaseClient = {
  query<Row = any>(
    text: string,
    values?: readonly unknown[],
  ): Promise<DatabaseQueryResult<Row>>;
  release(): void;
};

/**
 * Repository-facing handle for one already-open transaction. Connection
 * release, role switching, and nested transaction control stay in the
 * composition root that checked the connection out.
 */
export type DatabaseTransaction = Pick<DatabaseClient, "query">;

export type DatabasePool = {
  connect(): Promise<DatabaseClient>;
  end(): Promise<void>;
};

export type DatabaseCapabilityRole = "argus_runtime" | "argus_waitlist";

function executableSql(text: string): string {
  let sql = text.trimStart();
  while (sql.startsWith("--") || sql.startsWith("/*")) {
    if (sql.startsWith("--")) {
      const newline = sql.indexOf("\n");
      if (newline === -1) return "";
      sql = sql.slice(newline + 1).trimStart();
      continue;
    }
    const commentEnd = sql.indexOf("*/", 2);
    if (commentEnd === -1) return "";
    sql = sql.slice(commentEnd + 2).trimStart();
  }
  return sql;
}

function repositoryTransaction(client: DatabaseClient): DatabaseTransaction {
  return Object.freeze({
    async query<Row = any>(
      text: string,
      values: readonly unknown[] = [],
    ): Promise<DatabaseQueryResult<Row>> {
      const sql = executableSql(text);
      if (
        text.includes(";") ||
        /^(?:begin|start\s+transaction|commit|end|abort|rollback|savepoint|release|prepare\s+transaction|set|reset|discard)\b/i
          .test(sql)
      ) {
        throw new Error("nested_transaction_control_forbidden");
      }
      return client.query<Row>(text, values);
    },
  });
}

export async function withDatabaseTransaction<T>(
  pool: DatabasePool,
  role: DatabaseCapabilityRole,
  callback: (database: DatabaseTransaction) => Promise<T>,
  initialize?: (database: DatabaseTransaction) => Promise<void>,
): Promise<T> {
  const client = await pool.connect();
  const database = repositoryTransaction(client);
  let transactionStarted = false;
  try {
    await client.query("begin");
    transactionStarted = true;
    await initialize?.(database);
    await client.query(`set local role ${role}`);
    const result = await callback(database);
    await client.query("commit");
    transactionStarted = false;
    return result;
  } catch (error) {
    if (transactionStarted) {
      await client.query("rollback").catch(() => undefined);
    }
    throw error;
  } finally {
    client.release();
  }
}
