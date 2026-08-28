begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(24);

select ok(
  has_schema_privilege('argus_runtime', 'extensions', 'usage')
    and has_schema_privilege('argus_worker', 'extensions', 'usage')
    and has_schema_privilege('argus_waitlist', 'extensions', 'usage'),
  'capability roles can execute allowlisted extension-backed helpers'
);

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
grant argus_runtime, argus_worker, argus_waitlist
  to current_user with set true;
grant usage on schema extensions
  to argus_runtime, argus_worker, argus_waitlist;

select ok(not has_schema_privilege('anon', 'argus_app', 'usage'), 'anon has no Argus schema usage');
select ok(not has_schema_privilege('authenticated', 'argus_app', 'usage'), 'authenticated has no Argus schema usage');
select ok(not has_schema_privilege('anon', 'argus_brokerage', 'usage'), 'anon has no brokerage schema usage');
select ok(not has_schema_privilege('authenticated', 'argus_brokerage', 'usage'), 'authenticated has no brokerage schema usage');
select ok(not has_schema_privilege('anon', 'argus_private', 'usage'), 'anon has no private schema usage');
select ok(not has_schema_privilege('authenticated', 'argus_private', 'usage'), 'authenticated has no private schema usage');
select ok(has_schema_privilege('argus_runtime', 'argus_app', 'usage'), 'runtime can use Argus schema');
select ok(has_schema_privilege('argus_runtime', 'argus_brokerage', 'usage'), 'runtime can use brokerage schema');
select ok(has_schema_privilege('argus_runtime', 'argus_private', 'usage'), 'runtime can use private schema');

select is(
  (select count(*)::bigint
     from information_schema.role_table_grants
    where grantee in ('anon', 'authenticated')
      and table_schema in ('argus_app', 'argus_brokerage', 'argus_private')),
  0::bigint,
  'client roles have no application table grants'
);

select is(
  (select count(*)::bigint
     from information_schema.role_routine_grants
    where grantee in ('anon', 'authenticated')
      and specific_schema in ('argus_app', 'argus_brokerage', 'argus_private')),
  0::bigint,
  'client roles have no application function grants'
);

select is(
  (select count(*)::bigint
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
      and p.prosecdef
      and has_function_privilege('public', p.oid, 'execute')),
  0::bigint,
  'security-definer functions are never executable by PUBLIC'
);

select is(
  (select count(*)::bigint
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
      and p.prosecdef
      and not (
        exists (
          select 1
            from unnest(coalesce(p.proconfig, array[]::text[])) config(value)
            cross join lateral (
              select regexp_split_to_array(
                regexp_replace(config.value, '^search_path=', ''),
                '\s*,\s*'
              ) as schemas
            ) trusted_path
           where config.value like 'search_path=%'
             and (trusted_path.schemas)[1] = 'pg_catalog'
             and trusted_path.schemas <@ array[
               'pg_catalog', 'argus_private', 'argus_app', 'argus_brokerage',
               'auth', 'extensions', 'net', 'pgmq', 'storage', 'vault'
             ]::text[]
        )
      )),
  0::bigint,
  'every security-definer helper has an immutable trusted search path'
);

select is(
  (select count(*)::bigint
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'argus_private'
      and p.prosecdef
      and p.proname = 'has_staff_permission'
      and p.prosrc not like '%argus_private.request_user_id()%'),
  0::bigint,
  'staff privilege helper checks the Argus-owned request identity'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'authenticated', 'authenticated', 'staff@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into argus_app.members (user_id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
on conflict (user_id) do nothing;
insert into argus_private.staff_principals (user_id, permissions, display_label)
values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', array['editorial:read'], 'Test staff');
insert into argus_app.editorial_items (id, kind, slug, status)
values ('cccccccc-1000-4000-8000-000000000001', 'ritual', 'staff-only-draft', 'draft');

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
insert into argus_app.profiles (user_id, deletion_epoch, display_name)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, 'User A')
on conflict (user_id) do update set display_name = excluded.display_name;

select is(
  (select count(*)::bigint from argus_app.profiles),
  1::bigint,
  'runtime can read the verified owner row'
);

do $$ begin
  perform argus_private.set_request_context(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'bbbbbbbb-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;

select is(
  (select count(*)::bigint
     from argus_app.profiles
    where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'runtime claims for user B cannot read user A profile'
);

update argus_app.profiles set display_name = 'stolen'
 where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select count(*)::bigint from argus_app.profiles where display_name = 'stolen'),
  0::bigint,
  'ownership-compatible SELECT, USING, and WITH CHECK prevent cross-user update'
);
reset role;

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'cccccccc-0000-4000-8000-000000000001',
    'aal2'
  );
end $$;
select is(
  (select count(*)::bigint from argus_app.editorial_items where id = 'cccccccc-1000-4000-8000-000000000001'),
  1::bigint,
  'active staff permission can read draft editorial state'
);
reset role;

update argus_private.staff_principals
   set status = 'revoked', revoked_at = now(), revocation_epoch = revocation_epoch + 1
 where user_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'cccccccc-0000-4000-8000-000000000001',
    'aal2'
  );
end $$;
select is(
  (select count(*)::bigint from argus_app.editorial_items where id = 'cccccccc-1000-4000-8000-000000000001'),
  0::bigint,
  'revoked staff loses draft visibility immediately'
);
reset role;

set local role authenticated;
do $$ begin
  perform set_config(
    'request.jwt.claims',
    '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',
    true
  );
end $$;
select throws_ok(
  $$select * from argus_app.profiles$$,
  '42501',
  'permission denied for schema argus_app',
  'authenticated cannot bypass the API by naming the private schema'
);
reset role;

select is(
  (select count(*)::bigint
     from pg_policies
    where schemaname in ('argus_app', 'argus_brokerage', 'argus_private')
      and cmd in ('ALL', 'UPDATE')
      and qual is not null
      and with_check is null),
  0::bigint,
  'mutable ownership policies never omit WITH CHECK'
);

select is(
  (select count(*)::bigint
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
      and p.prokind in ('f', 'p')
      and pg_get_functiondef(p.oid) like '%auth.role()%'),
  0::bigint,
  'database code does not use deprecated auth.role()'
);

select is(
  (select count(*)::bigint
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname in ('argus_app','argus_brokerage','argus_private')),
  0::bigint,
  'no application or brokerage table is published to Realtime'
);

select * from finish();
rollback;
