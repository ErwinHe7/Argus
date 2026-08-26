import { beforeAll, beforeEach, expect, it } from "vitest";

import {
  asRole,
  describePostgres,
  ensureMigrated,
  ownerClient,
  provisionTestLogins,
  resetSubmissions,
} from "./support.ts";

const NOTICE = "waitlist-v1-2026-08-25";

describePostgres("waitlist effective privileges", () => {
  beforeAll(async () => {
    await ensureMigrated();
    await provisionTestLogins();
  });
  beforeEach(resetSubmissions);

  it("uses non-inheriting, non-owner, non-bypass roles and a NOLOGIN function owner", async () => {
    const owner = await ownerClient();
    try {
      const roles = await owner.query<{
        rolname: string;
        rolsuper: boolean;
        rolinherit: boolean;
        rolcreaterole: boolean;
        rolcreatedb: boolean;
        rolcanlogin: boolean;
        rolreplication: boolean;
        rolbypassrls: boolean;
      }>(`
        select rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb,
               rolcanlogin, rolreplication, rolbypassrls
        from pg_roles
        where rolname in ('waitlist_function_owner', 'waitlist_runtime', 'waitlist_maintenance')
        order by rolname
      `);
      expect(roles.rows).toEqual([
        expect.objectContaining({ rolname: "waitlist_function_owner", rolsuper: false, rolinherit: false, rolcanlogin: false, rolbypassrls: false }),
        expect.objectContaining({ rolname: "waitlist_maintenance", rolsuper: false, rolinherit: false, rolcanlogin: true, rolbypassrls: false }),
        expect.objectContaining({ rolname: "waitlist_runtime", rolsuper: false, rolinherit: false, rolcanlogin: true, rolbypassrls: false }),
      ]);
      for (const role of roles.rows) {
        expect(role).toMatchObject({
          rolsuper: false,
          rolinherit: false,
          rolcreaterole: false,
          rolcreatedb: false,
          rolreplication: false,
          rolbypassrls: false,
        });
      }
      const ownerMembership = await owner.query<{ membership_count: string }>(`
        select count(*)::text as membership_count
        from pg_catalog.pg_auth_members membership
        join pg_catalog.pg_roles granted on granted.oid = membership.roleid
        join pg_catalog.pg_roles member on member.oid = membership.member
        where granted.rolname = 'waitlist_function_owner' and member.rolname = current_user
      `);
      expect(ownerMembership.rows[0]?.membership_count).toBe("0");
    } finally {
      await owner.end();
    }
  });

  it("allows runtime execution of only submit and fixed-cutoff purge", async () => {
    await asRole("waitlist_runtime", async (runtime) => {
      await expect(
        runtime.query("select waitlist_private.submit_provisional($1, $2)", ["allowed@example.com", NOTICE]),
      ).resolves.toBeDefined();
      const purge = await runtime.query<{ purge_expired: string }>("select waitlist_private.purge_expired()");
      expect(purge.rows).toEqual([{ purge_expired: "0" }]);
      await expect(runtime.query("select waitlist_private.purge_expired(now())")).rejects.toThrow();
      await expect(runtime.query("select * from waitlist_private.provisional_submissions")).rejects.toThrow();
      await expect(runtime.query("select * from waitlist_private.applied_migrations")).rejects.toThrow();
      await expect(
        runtime.query("insert into waitlist_private.provisional_submissions values ('x@example.com', $1, now())", [NOTICE]),
      ).rejects.toThrow();
      await expect(runtime.query("update waitlist_private.provisional_submissions set notice_version = 'x'")).rejects.toThrow();
      await expect(runtime.query("delete from waitlist_private.provisional_submissions")).rejects.toThrow();
      await expect(runtime.query("create table waitlist_private.forbidden(id integer)")).rejects.toThrow();
      await expect(runtime.query("create table public.forbidden(id integer)")).rejects.toThrow();
      await expect(runtime.query("create temporary table forbidden_temp(id integer)")).rejects.toThrow();
      await expect(runtime.query("create schema forbidden_runtime")).rejects.toThrow();
      await expect(runtime.query("set role waitlist_function_owner")).rejects.toThrow();
      await expect(runtime.query("select waitlist_private.remove_verified('allowed@example.com')")).rejects.toThrow();
      await expect(runtime.query("select waitlist_private.replay_denial('allowed@example.com', now())")).rejects.toThrow();
    });
    await asRole("waitlist_maintenance", async (maintenance) => {
      await expect(
        maintenance.query("select waitlist_private.submit_provisional($1, $2)", ["forbidden@example.com", NOTICE]),
      ).rejects.toThrow();
      await expect(maintenance.query("select * from waitlist_private.provisional_submissions")).rejects.toThrow();
    });
  });

  it("revokes default/public paths and fixes SECURITY DEFINER ownership and search paths", async () => {
    const owner = await ownerClient();
    try {
      const grants = await owner.query<{
        public_schema: boolean;
        public_table: boolean;
        public_submit: boolean;
        runtime_schema_create: boolean;
        runtime_table_select: boolean;
        runtime_submit: boolean;
        runtime_purge: boolean;
        runtime_connect: boolean;
        runtime_temporary: boolean;
      }>(`
        select
          has_schema_privilege('public', 'waitlist_private', 'USAGE') as public_schema,
          has_table_privilege('public', 'waitlist_private.provisional_submissions', 'SELECT') as public_table,
          has_function_privilege('public', 'waitlist_private.submit_provisional(text,text)', 'EXECUTE') as public_submit,
          has_schema_privilege('waitlist_runtime', 'waitlist_private', 'CREATE') as runtime_schema_create,
          has_table_privilege('waitlist_runtime', 'waitlist_private.provisional_submissions', 'SELECT') as runtime_table_select,
          has_function_privilege('waitlist_runtime', 'waitlist_private.submit_provisional(text,text)', 'EXECUTE') as runtime_submit,
          has_function_privilege('waitlist_runtime', 'waitlist_private.purge_expired()', 'EXECUTE') as runtime_purge,
          has_database_privilege('waitlist_runtime', current_database(), 'CONNECT') as runtime_connect,
          has_database_privilege('waitlist_runtime', current_database(), 'TEMPORARY') as runtime_temporary
      `);
      expect(grants.rows[0]).toEqual({
        public_schema: false,
        public_table: false,
        public_submit: false,
        runtime_schema_create: false,
        runtime_table_select: false,
        runtime_submit: true,
        runtime_purge: true,
        runtime_connect: true,
        runtime_temporary: false,
      });
      const functions = await owner.query<{ proname: string; prosecdef: boolean; owner: string; config: string[] }>(`
        select p.proname, p.prosecdef, r.rolname as owner, p.proconfig as config
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        join pg_roles r on r.oid = p.proowner
        where n.nspname = 'waitlist_private'
          and p.proname in ('submit_provisional', 'purge_expired', 'remove_verified', 'replay_denial')
        order by p.proname
      `);
      expect(functions.rows).toHaveLength(4);
      for (const fn of functions.rows) {
        expect(fn).toMatchObject({ prosecdef: true, owner: "waitlist_function_owner" });
        expect(fn.config).toContain("search_path=pg_catalog, waitlist_private");
      }
    } finally {
      await owner.end();
    }
  });

  it("uses a database-owned cutoff, deletes before 24 months, and returns only a count", async () => {
    const owner = await ownerClient();
    try {
      await owner.query(`
        insert into waitlist_private.provisional_submissions(normalized_email, notice_version, submitted_at)
        values
          ('keep@example.com', '${NOTICE}', clock_timestamp() - interval '23 months 28 days'),
          ('purge@example.com', '${NOTICE}', clock_timestamp() - interval '23 months 30 days')
      `);
    } finally {
      await owner.end();
    }
    const purged = await asRole("waitlist_runtime", (runtime) =>
      runtime.query<{ purge_expired: string }>("select waitlist_private.purge_expired()"),
    );
    expect(purged.rows).toEqual([{ purge_expired: "1" }]);
    expect(JSON.stringify(purged.rows)).not.toContain("example.com");
    const inspect = await ownerClient();
    try {
      const remaining = await inspect.query<{ normalized_email: string }>(
        "select normalized_email from waitlist_private.provisional_submissions",
      );
      expect(remaining.rows).toEqual([{ normalized_email: "keep@example.com" }]);
    } finally {
      await inspect.end();
    }
  });
});
