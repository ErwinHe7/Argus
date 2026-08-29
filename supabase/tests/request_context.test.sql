begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

grant argus_edge,argus_runtime,argus_identity_owner
  to current_user with set true;
grant usage on schema extensions to argus_edge,argus_runtime,argus_identity_owner;

select plan(20);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','14141414-1414-4414-8414-141414141414',
   'authenticated','authenticated','context-a@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','24242424-2424-4424-8424-242424242424',
   'authenticated','authenticated','context-b@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());

select has_function(
  'argus_private','install_request_context',array['uuid','uuid','text'],
  'trusted API context has one exact installer signature'
);
select has_function(
  'argus_private','trusted_request_lifecycle_id',array[]::text[],
  'policies can read a validated lifecycle identifier'
);
select ok(
  (select routine.prosrc like '%argus_private.lock_open_member_lifecycle(%'
       and routine.prosrc !~* 'for[[:space:]]+key[[:space:]]+share'
     from pg_proc routine
    where routine.oid=
      'argus_private.install_request_context(uuid,uuid,text)'::regprocedure),
  'context installation delegates lifecycle serialization to the shared lock helper'
);
select ok(
  (select routine.prosecdef
       and owner.rolname='argus_identity_owner'
       and 'search_path=""'=any(coalesce(routine.proconfig,array[]::text[]))
       and routine.prosrc ~* 'for[[:space:]]+share'
     from pg_proc routine
     join pg_roles owner on owner.oid=routine.proowner
    where routine.oid=
      'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)'::regprocedure)
  and not has_function_privilege(
    'argus_edge',
    'argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)',
    'execute'
  ),
  'identity-owned helper holds a FOR SHARE lock without exposing it to the login'
);

set local role argus_runtime;
select throws_ok(
  $$select argus_private.install_request_context(
    '14141414-1414-4414-8414-141414141414',
    '14141414-0000-4000-8000-000000000001','aal1')$$,
  '42501','permission denied for function install_request_context',
  'a capability role cannot install or replace trusted context'
);
reset role;

select argus_private.close_member_lifecycle(
  (select lifecycle_id from argus_app.members
    where user_id='14141414-1414-4414-8414-141414141414'),
  'pgtap-preinstall-close'
);
set local role argus_edge;
select throws_ok(
  $$select argus_private.install_request_context(
    '14141414-1414-4414-8414-141414141414',
    '14141414-0000-4000-8000-000000000001','aal1')$$,
  '28000','inactive_member_lifecycle',
  'closed lifecycle cannot install a new context');
reset role;

set local role argus_edge;
select lives_ok(
  $$select argus_private.install_request_context(
    '24242424-2424-4424-8424-242424242424',
    '24242424-0000-4000-8000-000000000001','aal1')$$,
  'the trusted login installs context before assuming a capability role'
);
reset role;

set local role argus_runtime;
select is(argus_private.trusted_request_user_id(),
  '24242424-2424-4424-8424-242424242424'::uuid,
  'trusted context returns its verified identity subject');
select is(argus_private.trusted_request_tenant_id(),
  '24242424-2424-4424-8424-242424242424'::uuid,
  'tenant authority is derived from the lifecycle parent');
select is(argus_private.trusted_request_lifecycle_id(),
  (select lifecycle_id from argus_app.members
    where user_id='24242424-2424-4424-8424-242424242424'),
  'lifecycle authority is derived instead of caller supplied');

select argus_private.set_request_context(
  '14141414-1414-4414-8414-141414141414',
  '14141414-0000-4000-8000-000000000001','aal1');
select is(argus_private.trusted_request_user_id(),
  '24242424-2424-4424-8424-242424242424'::uuid,
  'spoofed legacy JWT GUCs cannot replace trusted context');
reset role;

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute format(
    'update pg_temp.%I set installed_at=statement_timestamp()-interval ''2 minutes''',
    context_relation
  );
end
$$;
reset role;
set local role argus_runtime;
select is(argus_private.trusted_request_user_id(),null::uuid,
  'stale trusted context fails closed');
reset role;
set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute format(
    'update pg_temp.%I set installed_at=clock_timestamp()',context_relation
  );
end
$$;
reset role;

select lives_ok(
  $$select argus_private.close_member_lifecycle(
    (select lifecycle_id from argus_app.members
      where user_id='24242424-2424-4424-8424-242424242424'),
    'pgtap-close')$$,
  'the private primitive closes a lifecycle exactly once'
);
reset role;

set local role argus_runtime;
select is(argus_private.trusted_request_user_id(),null::uuid,
  'closing the lifecycle immediately invalidates installed context');
select is(argus_private.trusted_request_lifecycle_id(),null::uuid,
  'closed lifecycle identifiers are never returned to policies');
reset role;

select set_config('argus.request_context_relation','not-a-valid-context',true);
set local role argus_runtime;
select is(argus_private.trusted_request_user_id(),null::uuid,
  'malformed context relation names fail closed');
reset role;

select set_config(
  'argus.request_context_relation',
  'argus_request_context_00000000000000000000000000000000',true
);
create temporary table argus_request_context_00000000000000000000000000000000(
  caller_supplied text
) on commit drop;
set local role argus_runtime;
select is(argus_private.trusted_request_user_id(),null::uuid,
  'a caller-owned context relation fails closed');
reset role;
drop table argus_request_context_00000000000000000000000000000000;

set local role argus_edge;
select throws_ok(
  $$select argus_private.install_request_context(
    '14141414-1414-4414-8414-141414141414',
    '14141414-0000-4000-8000-000000000001','aal3')$$,
  '22023','invalid_aal','malformed assurance context fails closed');
reset role;

select is(
  (select count(*)::bigint from pg_class relation
    join pg_namespace namespace on namespace.oid=relation.relnamespace
   where namespace.oid=pg_my_temp_schema()
     and relation.relname like 'argus_request_context_%'
     and relation.relpersistence='t'),
  1::bigint,
  'one transaction owns one protected temporary context relation'
);

select ok(
  (select relation.relowner=(select oid from pg_roles
     where rolname='argus_identity_owner')
     from pg_class relation
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.oid=pg_my_temp_schema()
      and relation.relname like 'argus_request_context_%'),
  'the protected context relation is not owned by a caller capability'
);

select * from finish();
rollback;
