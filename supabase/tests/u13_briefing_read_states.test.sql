begin;

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
do $membership$ begin
  execute pg_catalog.format(
    'grant argus_edge,argus_identity_owner,argus_member,argus_runtime,argus_worker,argus_waitlist to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions
  to argus_edge, argus_identity_owner, argus_member, argus_runtime,
     argus_worker, argus_waitlist;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(15);

select has_table(
  'argus_app','briefing_read_states',
  'member briefing read state is durable'
);
select col_not_null(
  'argus_app','briefing_read_states','deletion_epoch',
  'briefing read state is deletion-epoch bound'
);
select col_not_null(
  'argus_app','briefing_read_states','read_at',
  'a persisted read marker has an exact timestamp'
);
select ok(
  (select relrowsecurity from pg_class
    where oid='argus_app.briefing_read_states'::regclass),
  'briefing read state has RLS enabled'
);
select ok(
  (select relforcerowsecurity from pg_class
    where oid='argus_app.briefing_read_states'::regclass),
  'briefing read state forces RLS for its owner'
);
select ok(
  has_table_privilege('argus_member','argus_app.briefing_read_states','select')
  and has_table_privilege('argus_member','argus_app.briefing_read_states','insert')
  and has_table_privilege('argus_member','argus_app.briefing_read_states','update')
  and has_table_privilege('argus_member','argus_app.briefing_read_states','delete')
  and not has_table_privilege('argus_runtime','argus_app.briefing_read_states','select')
  and not has_table_privilege('argus_runtime','argus_app.briefing_read_states','insert')
  and not has_table_privilege('argus_runtime','argus_app.briefing_read_states','update')
  and not has_table_privilege('argus_runtime','argus_app.briefing_read_states','delete'),
  'only the lifecycle-bound member capability receives read-state mutations'
);
select is(
  (select count(*)::bigint from information_schema.role_table_grants
    where grantee in ('anon','authenticated')
      and table_schema='argus_app'
      and table_name='briefing_read_states'),
  0::bigint,
  'client roles cannot bypass the generated API boundary'
);

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','13131313-1313-4313-8313-131313131313','authenticated','authenticated','briefing-a@example.test','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','23232323-2323-4232-8232-232323232323','authenticated','authenticated','briefing-b@example.test','',now(),'{}','{}',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at) values
  ('13131313-0000-4000-8000-000000000001','13131313-1313-4313-8313-131313131313',now(),now()),
  ('23232323-0000-4000-8000-000000000001','23232323-2323-4232-8232-232323232323',now(),now());

insert into argus_app.briefings (
  id,user_id,deletion_epoch,briefing_type,period_start,period_end,status,generated_at
) values
  ('13131313-1000-4000-8000-000000000001',
   '13131313-1313-4313-8313-131313131313',0,
   'daily','2026-08-28','2026-08-28','ready',now()),
  ('23232323-1000-4000-8000-000000000001',
   '23232323-2323-4232-8232-232323232323',0,
   'daily','2026-08-28','2026-08-28','ready',now());
insert into argus_app.briefing_read_states(
  user_id,deletion_epoch,briefing_id,read_at
) values (
  '23232323-2323-4232-8232-232323232323',0,
  '23232323-1000-4000-8000-000000000001',clock_timestamp()
);

set local role argus_edge;
select argus_private.install_request_context(
  '13131313-1313-4313-8313-131313131313',
  '13131313-0000-4000-8000-000000000001','aal1'
);
set local role argus_member;
select lives_ok(
  $$insert into argus_app.briefing_read_states(
      user_id,deletion_epoch,briefing_id,read_at
    ) values (
      '13131313-1313-4313-8313-131313131313',0,
      '13131313-1000-4000-8000-000000000001',clock_timestamp()
    )$$,
  'the owner can durably mark their briefing read'
);
select is(
  (select count(*)::bigint from argus_app.briefing_read_states),1::bigint,
  'the owner can read their persisted marker'
);

select is(
  (select count(*)::bigint from argus_app.briefing_read_states
    where user_id='23232323-2323-4232-8232-232323232323'),0::bigint,
  'the owner cannot enumerate another member briefing read state'
);
select throws_ok(
  $$insert into argus_app.briefing_read_states(
      user_id,deletion_epoch,briefing_id,read_at
    ) values (
      '23232323-2323-4232-8232-232323232323',0,
      '23232323-1000-4000-8000-000000000001',clock_timestamp()
    ) on conflict (user_id,briefing_id) do update set read_at=excluded.read_at$$,
  '28000','inactive_member_lifecycle',
  'the owner cannot overwrite another member read marker'
);
reset role;

update argus_app.members
   set status='deletion_pending',deletion_epoch=1,deletion_requested_at=now()
 where user_id='13131313-1313-4313-8313-131313131313';

set local role argus_identity_owner;
select argus_private.close_member_lifecycle(
  (select lifecycle_id from argus_app.members
    where user_id='13131313-1313-4313-8313-131313131313'),
  'u13-briefing-close'
);
reset role;
set local role argus_member;
select is(
  (select count(*)::bigint from argus_app.briefing_read_states),
  0::bigint,
  'a closed lifecycle invalidates the already-issued briefing context'
);
reset role;
select is(
  (select state from argus_app.member_lifecycles
    where identity_subject_id='13131313-1313-4313-8313-131313131313'),
  'closed',
  'the deletion transition closes the immutable lifecycle parent'
);

select is(
  (select count(*)::bigint from argus_app.briefing_read_states
    where user_id='13131313-1313-4313-8313-131313131313'),1::bigint,
  'the hidden marker remains available for bounded purge cascade'
);
delete from argus_app.briefings
 where id='13131313-1000-4000-8000-000000000001';
select is(
  (select count(*)::bigint from argus_app.briefing_read_states
    where user_id='13131313-1313-4313-8313-131313131313'),0::bigint,
  'briefing purge cascades to its read state'
);

select * from finish();
rollback;
