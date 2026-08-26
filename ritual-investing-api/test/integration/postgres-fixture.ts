import pg from "pg";

const allowedRoles = new Set([
  "ritual_runtime",
  "ritual_scheduler",
  "ritual_privacy_purge",
  "ritual_moderation_worker",
  "ritual_media_worker",
]);

export function requirePostgresUrl(
  name:
    | "DATABASE_OWNER_URL"
    | "DATABASE_RUNTIME_URL"
    | "DATABASE_SCHEDULER_URL"
    | "DATABASE_PRIVACY_PURGE_URL",
): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required for PostgreSQL integration`);
  return value;
}

export async function connectAsRestrictedRole(
  databaseUrl: string,
  role: string,
): Promise<pg.Client> {
  if (!allowedRoles.has(role)) throw new Error(`unreviewed test role ${role}`);
  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  await client.query(`set role ${role}`);
  const identity = await client.query<{ role: string }>(
    "select current_user as role",
  );
  if (identity.rows[0]?.role !== role) {
    await client.end();
    throw new Error(`restricted PostgreSQL role ${role} was not activated`);
  }
  return client;
}

export async function withRestrictedRole<T>(
  databaseUrl: string,
  role: string,
  operation: (client: pg.Client) => Promise<T>,
): Promise<T> {
  const client = await connectAsRestrictedRole(databaseUrl, role);
  try {
    return await operation(client);
  } finally {
    await client.end();
  }
}
