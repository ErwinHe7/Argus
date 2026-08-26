import pg from "pg";
import { describe } from "vitest";

import { applyReviewedMigrations } from "../../scripts/check-migrations.ts";

const { Client } = pg;

export const ownerDatabaseUrl = process.env.WAITLIST_TEST_DATABASE_URL;
export const describePostgres = ownerDatabaseUrl === undefined ? describe.skip : describe;

export async function ensureMigrated(): Promise<void> {
  if (ownerDatabaseUrl === undefined) throw new Error("WAITLIST_TEST_DATABASE_URL is required");
  await provisionTestLogins();
  await applyReviewedMigrations(ownerDatabaseUrl);
}

export async function ownerClient(): Promise<pg.Client> {
  if (ownerDatabaseUrl === undefined) throw new Error("WAITLIST_TEST_DATABASE_URL is required");
  const client = new Client({ connectionString: ownerDatabaseUrl });
  await client.connect();
  return client;
}

const rolePasswords = {
  waitlist_runtime: "waitlist-runtime-test-password",
  waitlist_maintenance: "waitlist-maintenance-test-password",
} as const;

let provisioning: Promise<void> | undefined;

export async function provisionTestLogins(): Promise<void> {
  provisioning ??= (async () => {
    const client = await ownerClient();
    try {
      await client.query(`
        do $roles$
        begin
          if not exists (select 1 from pg_catalog.pg_roles where rolname = 'waitlist_runtime') then
            create role waitlist_runtime
              nosuperuser nocreatedb nocreaterole noinherit login noreplication nobypassrls
              password 'waitlist-runtime-test-password';
          end if;
          if not exists (select 1 from pg_catalog.pg_roles where rolname = 'waitlist_maintenance') then
            create role waitlist_maintenance
              nosuperuser nocreatedb nocreaterole noinherit login noreplication nobypassrls
              password 'waitlist-maintenance-test-password';
          end if;
        end
        $roles$
      `);
      await client.query("alter role waitlist_runtime login password 'waitlist-runtime-test-password'");
      await client.query("alter role waitlist_maintenance login password 'waitlist-maintenance-test-password'");
    } finally {
      await client.end();
    }
  })();
  await provisioning;
}

async function roleClient(role: keyof typeof rolePasswords): Promise<pg.Client> {
  if (ownerDatabaseUrl === undefined) throw new Error("WAITLIST_TEST_DATABASE_URL is required");
  await provisionTestLogins();
  const parsed = new URL(ownerDatabaseUrl);
  parsed.username = role;
  parsed.password = rolePasswords[role];
  const client = new Client({ connectionString: parsed.toString() });
  await client.connect();
  return client;
}

export async function resetSubmissions(): Promise<void> {
  const client = await ownerClient();
  try {
    await client.query("truncate table waitlist_private.provisional_submissions");
  } finally {
    await client.end();
  }
}

export async function asRole<T>(
  role: "waitlist_runtime" | "waitlist_maintenance",
  operation: (client: pg.Client) => Promise<T>,
): Promise<T> {
  const client = await roleClient(role);
  try {
    return await operation(client);
  } finally {
    await client.end();
  }
}
