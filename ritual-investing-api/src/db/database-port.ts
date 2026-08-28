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

export type DatabasePool = {
  connect(): Promise<DatabaseClient>;
  end(): Promise<void>;
};

export async function withDatabaseTransaction<T>(
  pool: DatabasePool,
  role: "argus_runtime",
  callback: (client: DatabaseClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  let transactionStarted = false;
  try {
    await client.query("begin");
    transactionStarted = true;
    await client.query(`set local role ${role}`);
    const result = await callback(client);
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
