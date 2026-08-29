begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(43);

select ok(
  has_schema_privilege('argus_runtime', 'extensions', 'usage')
    and has_schema_privilege('argus_worker', 'extensions', 'usage')
    and has_schema_privilege('argus_waitlist', 'extensions', 'usage'),
  'capability roles can execute allowlisted extension-backed helpers'
);

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
grant argus_edge, argus_runtime, argus_worker, argus_waitlist,
  argus_member, argus_staff, argus_identity_owner
  to current_user with set true;
grant usage on schema extensions
  to argus_edge,argus_runtime,argus_worker,argus_waitlist,
     argus_member,argus_staff,argus_identity_owner;

select ok(
  (select bool_and(not rolcanlogin and not rolsuper and not rolbypassrls)
     from pg_roles
    where rolname in ('argus_member','argus_staff','argus_callback','argus_migration'))
  and (select count(*) from pg_roles
    where rolname in ('argus_member','argus_staff','argus_callback','argus_migration'))=4
  and (select not rolcanlogin and not rolsuper and not rolbypassrls
         from pg_roles where rolname='argus_publication_owner'),
  'use-case capability roles are NOLOGIN, non-owner, and non-BYPASSRLS'
);

select ok(
  pg_has_role('argus_edge','argus_member','member')
    and pg_has_role('argus_edge','argus_staff','member')
    and not pg_has_role('argus_edge','argus_callback','member')
    and not pg_has_role('argus_edge','argus_migration','member')
    and not pg_has_role('argus_edge','argus_publication_owner','member'),
  'API login can assume only member, staff, and retained runtime capabilities'
);

select is(
  (select count(*)::bigint
     from information_schema.role_table_grants
    where grantee in ('argus_callback','argus_migration')
      and table_schema in ('argus_app','argus_brokerage','argus_private')),
  0::bigint,
  'unbound callback and migration capabilities receive no application table grants'
);

select is(
  (select count(*)::bigint
     from information_schema.role_table_grants
    where grantee in ('argus_member','argus_staff')
      and (
        table_schema='argus_brokerage'
        or (table_schema='argus_private' and not (
          grantee='argus_staff' and table_name='admin_audit_events'
          and privilege_type='INSERT'
        ))
      )),
  0::bigint,
  'member and staff capabilities do not inherit U5/U6 brokerage or private operational grants'
);

select is(
  (select count(*)::bigint
     from pg_policy policy
     join pg_class relation on relation.oid=policy.polrelid
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname in ('argus_app','argus_private')
      and (select oid from pg_roles where rolname='argus_app_owner')=any(policy.polroles)
      and policy.polcmd='*'),
  0::bigint,
  'U4 application owner has no blanket FOR ALL policy'
);

select is(
  (with u4_policy_expressions as (
     select policy.polname,
            lower(regexp_replace(expression.expression_text,'[[:space:]]+',' ','g'))
              as expression_text
       from pg_policy policy
       cross join lateral unnest(array[
         pg_get_expr(policy.polqual,policy.polrelid),
         pg_get_expr(policy.polwithcheck,policy.polrelid)
       ]) expression(expression_text)
      where policy.polname like 'u4\_%' escape '\'
        and expression.expression_text is not null
   )
   select count(*)::bigint
     from u4_policy_expressions
    where expression_text like '%argus_private.has_staff_permission(%'
      and regexp_count(
            expression_text,
            'argus_private\.has_staff_permission\('
          ) <> regexp_count(
            expression_text,
            'select argus_private\.has_staff_permission\('
          )),
  0::bigint,
  'every U4 staff-permission policy helper is wrapped in a scalar SELECT initplan'
);

select is(
  (select count(*)::bigint
     from (
       select relation.oid
         from pg_class relation
         join pg_namespace namespace on namespace.oid=relation.relnamespace
         cross join lateral aclexplode(relation.relacl) privilege
        where namespace.nspname in ('argus_app','argus_private')
          and relation.relowner<>(select oid from pg_roles where rolname='argus_app_owner')
          and not (
            namespace.nspname='argus_app' and relation.relname='saved_items'
          )
          and privilege.grantee=(select oid from pg_roles where rolname='argus_app_owner')
          and privilege.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
        group by relation.oid
       having count(distinct privilege.privilege_type)=4
     ) broad_grant),
  0::bigint,
  'U4 application owner has no unexplained explicit four-DML grant'
);

select ok(
  has_table_privilege('argus_app_owner','argus_app.member_lifecycles','SELECT')
    and not has_table_privilege('argus_app_owner','argus_app.member_lifecycles','INSERT')
    and not has_table_privilege('argus_app_owner','argus_app.member_lifecycles','UPDATE')
    and not has_table_privilege('argus_app_owner','argus_app.member_lifecycles','DELETE')
    and not has_table_privilege('argus_app_owner','argus_app.member_lifecycles','REFERENCES'),
  'identity owner exposes only lifecycle SELECT to the U4 binding trigger'
);

select ok(
  has_table_privilege('argus_worker','argus_app.member_lifecycles','SELECT')
    and not has_table_privilege('argus_worker','argus_app.member_lifecycles','INSERT')
    and not has_table_privilege('argus_worker','argus_app.member_lifecycles','UPDATE')
    and not has_table_privilege('argus_worker','argus_app.member_lifecycles','DELETE')
    and exists (
      select 1 from pg_policies
       where schemaname='argus_app' and tablename='member_lifecycles'
         and policyname='u4_worker_open_lifecycle_binding'
         and cmd='SELECT' and 'argus_worker'=any(roles)
    ),
  'the retained U6 worker trigger bridge can resolve only open lifecycle parents'
);

select ok(
  (select jsonb_agg(privilege.privilege_type order by privilege.privilege_type)
     from pg_class relation
     cross join lateral aclexplode(relation.relacl) privilege
    where relation.oid='argus_app.member_saved_items'::regclass
      and privilege.grantee=(select oid from pg_roles where rolname='postgres'))
      ='["DELETE"]'::jsonb
    and exists (
      select 1 from pg_policies
       where schemaname='argus_app' and tablename='member_saved_items'
         and policyname='u4_u6_privacy_purge_saved_delete'
         and cmd='DELETE' and 'postgres'=any(roles) and qual='true'
    ),
  'the retained U6 privacy definer receives only saved-authority deletion'
);

select is(
  (select count(*)::bigint
     from pg_class relation
     join pg_namespace namespace on namespace.oid=relation.relnamespace
     cross join lateral aclexplode(relation.relacl) privilege
     join (values
       ('argus_private.staff_principals'),
       ('argus_app.editorial_review_requests'),
       ('argus_app.editorial_review_decisions'),
       ('argus_app.ritual_schedules'),
       ('argus_app.companies'),
       ('argus_app.onboarding_states'),
       ('argus_app.notification_preferences'),
       ('argus_app.editorial_revision_assets')
     ) forbidden(relation_name)
       on forbidden.relation_name=namespace.nspname||'.'||relation.relname
    where privilege.grantee=(select oid from pg_roles where rolname='argus_app_owner')
      and relation.relowner<>(select oid from pg_roles where rolname='argus_app_owner')
      and privilege.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')),
  0::bigint,
  'U4 application owner receives no unused explicit relation/action privilege'
);

select ok(
  (select count(*) from pg_policies
    where schemaname='argus_app' and 'argus_runtime'=any(roles)
      and tablename in (
        'catalog_assets','community_templates','companies','coven_entries',
        'editorial_items','editorial_revisions','editorial_review_requests',
        'editorial_review_decisions','publication_events','evidence_claims',
        'evidence_sources','grimoires','ritual_scenario_revisions',
        'ritual_scenarios','ritual_schedules','rowan_context_bindings',
        'rowan_script_revisions','rowan_scripts','editorial_render_documents'
      ))=0
  and not has_table_privilege('argus_runtime','argus_app.editorial_items','select')
  and not has_table_privilege('argus_runtime','argus_app.editorial_revisions','select')
  and not has_table_privilege('argus_runtime','argus_app.editorial_render_documents','select')
  and has_function_privilege(
    'argus_runtime','argus_private.list_current_published_editorial(text,integer)','execute'
  )
  and has_function_privilege(
    'argus_member','argus_private.get_current_published_editorial(text)','execute'
  )
  and (select count(*) from pg_proc function_row
       where function_row.oid in (
         'argus_private.list_current_published_editorial(text,integer)'::regprocedure,
         'argus_private.get_current_published_editorial(text)'::regprocedure
       ) and function_row.proowner=(
         select oid from pg_roles where rolname='argus_publication_owner'
       ))=2
  and (select count(*) from pg_policies
       where schemaname='argus_app'
         and 'argus_publication_owner'=any(roles)
         and cmd='SELECT' and qual='true')=3
  and (select count(*) from pg_class relation
       cross join lateral aclexplode(relation.relacl) privilege
       where relation.oid in (
         'argus_app.editorial_items'::regclass,
         'argus_app.editorial_revisions'::regclass,
         'argus_app.editorial_render_documents'::regclass
       ) and privilege.grantee=(
         select oid from pg_roles where rolname='argus_publication_owner'
       ) and privilege.privilege_type='SELECT')=3,
  'anonymous publication uses only two bounded functions with an exact NOLOGIN read owner'
);

select ok(
  has_function_privilege(
    'argus_edge','argus_private.install_request_context(uuid,uuid,text)','execute'
  ) and not has_function_privilege(
    'argus_runtime','argus_private.install_request_context(uuid,uuid,text)','execute'
  ),
  'only the trusted API login can install request context'
);

select ok(
  has_function_privilege(
    'argus_member','argus_private.trusted_request_lifecycle_id()','execute'
  ) and has_function_privilege(
    'argus_staff','argus_private.trusted_request_lifecycle_id()','execute'
  ) and has_function_privilege(
    'argus_runtime','argus_private.trusted_request_lifecycle_id()','execute'
  ),
  'member, staff, and retained runtime policies can read validated context'
);

select ok(
  has_function_privilege(
    'argus_member','argus_private.trusted_request_user_id()','execute'
  ) and has_function_privilege(
    'argus_staff','argus_private.trusted_request_user_id()','execute'
  ) and not has_function_privilege(
    'argus_member','argus_private.request_user_id()','execute'
  ) and not has_function_privilege(
    'argus_staff','argus_private.request_user_id()','execute'
  ),
  'U4 member and editorial repositories must use only trusted request identity'
);

select is(
  (select count(*)::bigint
     from pg_auth_members membership
     join pg_roles granted_role on granted_role.oid=membership.roleid
    where granted_role.rolname in (
      'argus_member','argus_staff','argus_callback','argus_migration'
    ) and membership.member in (
      select oid from pg_roles where rolname in (
        'argus_member','argus_staff','argus_callback','argus_migration'
      )
    )),
  0::bigint,
  'capability roles do not inherit one another'
);

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
        'search_path=""'=any(coalesce(p.proconfig,array[]::text[]))
        or
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
      and p.prosrc not like '%argus_private.trusted_request_user_id()%'),
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

set local role argus_edge;
do $$ begin
  perform argus_private.install_request_context(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
reset role;

set local role argus_member;
insert into argus_app.profiles (user_id, deletion_epoch, display_name)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, 'User A')
on conflict (user_id) do update set display_name = excluded.display_name;

select is(
  (select count(*)::bigint from argus_app.profiles),
  1::bigint,
  'member capability can read the verified owner row'
);
reset role;

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute format(
    'update pg_temp.%I set user_id=$1,tenant_id=$1,lifecycle_id=$2,installed_at=clock_timestamp()',
    context_relation
  ) using
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,
    (select lifecycle_id from argus_app.members
      where user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
end $$;
reset role;

set local role argus_member;
select is(
  (select count(*)::bigint
     from argus_app.profiles
    where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'trusted user B context cannot read user A profile'
);

update argus_app.profiles set display_name = 'stolen'
 where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select count(*)::bigint from argus_app.profiles where display_name = 'stolen'),
  0::bigint,
  'ownership-compatible SELECT, USING, and WITH CHECK prevent cross-user update'
);
reset role;

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute format(
    'update pg_temp.%I set user_id=$1,tenant_id=$1,lifecycle_id=$2,aal=''aal2'',installed_at=clock_timestamp()',
    context_relation
  ) using
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid,
    (select lifecycle_id from argus_app.members
      where user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc');
end $$;
reset role;

set local role argus_staff;
select is(
  (select count(*)::bigint from argus_app.editorial_items where id = 'cccccccc-1000-4000-8000-000000000001'),
  1::bigint,
  'active staff permission can read draft editorial state'
);
reset role;

update argus_private.staff_principals
   set status = 'revoked', revoked_at = now(), revocation_epoch = revocation_epoch + 1
 where user_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

set local role argus_staff;
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

select is(
  (select count(*)::bigint
     from pg_proc function_row
     join pg_namespace namespace on namespace.oid=function_row.pronamespace
     join pg_roles owner on owner.oid=function_row.proowner
    where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
      and owner.rolname in (
        'argus_runtime','argus_worker','argus_waitlist',
        'argus_edge','argus_worker_edge','argus_waitlist_edge'
      )),
  0::bigint,
  'capability and login roles own no application routine'
);

select is(
  (select count(*)::bigint
     from pg_proc function_row
     join pg_namespace namespace on namespace.oid=function_row.pronamespace
    where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
      and has_function_privilege('public',function_row.oid,'execute')),
  0::bigint,
  'PUBLIC cannot execute invoker or definer application routines'
);

select is(
  (select count(*)::bigint
     from information_schema.role_table_grants
    where grantee in ('argus_edge','argus_worker_edge','argus_waitlist_edge')
      and table_schema in ('argus_app','argus_brokerage','argus_private')),
  0::bigint,
  'Edge login shells receive no direct application table grant'
);

select * from finish();
rollback;
