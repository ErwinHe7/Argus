begin;

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
  has_table_privilege('argus_runtime','argus_app.briefing_read_states','select')
  and has_table_privilege('argus_runtime','argus_app.briefing_read_states','insert')
  and has_table_privilege('argus_runtime','argus_app.briefing_read_states','update')
  and has_table_privilege('argus_runtime','argus_app.briefing_read_states','delete'),
  'only the Edge runtime receives the required read-state mutations'
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

insert into argus_app.briefings (
  id,user_id,deletion_epoch,briefing_type,period_start,period_end,status,generated_at
) values (
  '13131313-1000-4000-8000-000000000001',
  '13131313-1313-4313-8313-131313131313',0,
  'daily','2026-08-28','2026-08-28','ready',now()
);

set local role argus_runtime;
select argus_private.set_request_context(
  '13131313-1313-4313-8313-131313131313',
  '13131313-0000-4000-8000-000000000001','aal1'
);
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

select argus_private.set_request_context(
  '23232323-2323-4232-8232-232323232323',
  '23232323-0000-4000-8000-000000000001','aal1'
);
select is(
  (select count(*)::bigint from argus_app.briefing_read_states),0::bigint,
  'another member cannot enumerate briefing read state'
);
select throws_ok(
  $$insert into argus_app.briefing_read_states(
      user_id,deletion_epoch,briefing_id,read_at
    ) values (
      '13131313-1313-4313-8313-131313131313',0,
      '13131313-1000-4000-8000-000000000001',clock_timestamp()
    ) on conflict (user_id,briefing_id) do update set read_at=excluded.read_at$$,
  '42501',null,
  'another member cannot overwrite the owner read marker'
);
reset role;

update argus_app.members
   set status='deletion_pending',deletion_epoch=1,deletion_requested_at=now()
 where user_id='13131313-1313-4313-8313-131313131313';

set local role argus_runtime;
select argus_private.set_request_context(
  '13131313-1313-4313-8313-131313131313',
  '13131313-0000-4000-8000-000000000001','aal1'
);
select is(
  (select count(*)::bigint from argus_app.briefing_read_states),0::bigint,
  'deletion fencing hides the stale read marker'
);
select is(
  (select count(*)::bigint from argus_app.briefings),0::bigint,
  'deletion fencing also hides the stale generated briefing'
);
reset role;

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
