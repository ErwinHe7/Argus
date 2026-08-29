begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

grant argus_runtime to current_user with set true;
grant usage on schema extensions to argus_runtime;

select plan(10);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'authenticated','authenticated','lifecycle-a@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
   'authenticated','authenticated','lifecycle-b@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());
insert into argus_app.members(user_id) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee')
on conflict (user_id) do nothing;
insert into argus_app.profiles(user_id,deletion_epoch,display_name) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',0,'Lifecycle A')
on conflict (user_id) do update
  set display_name=excluded.display_name;

select todo_start('U3 replaces the mutable deletion epoch with an immutable lifecycle/incarnation identifier');
select has_column('argus_app','members','lifecycle_id',
  'member root has an immutable lifecycle identifier');
select todo_end();

select cmp_ok((select count(*)::bigint from information_schema.columns user_column
  join information_schema.columns epoch_column
    on epoch_column.table_schema=user_column.table_schema
   and epoch_column.table_name=user_column.table_name
   and epoch_column.column_name='deletion_epoch'
  where user_column.table_schema in ('argus_app','argus_brokerage','argus_private')
    and user_column.column_name='user_id'),'>=',40::bigint,
  'the current lifecycle inventory spans every member-owned domain');

select is((select count(*)::bigint from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
    and relation.relkind in ('r','p')
    and exists(select 1 from pg_attribute user_column
      where user_column.attrelid=relation.oid and user_column.attname='user_id'
        and not user_column.attisdropped)
    and exists(select 1 from pg_attribute epoch_column
      where epoch_column.attrelid=relation.oid and epoch_column.attname='deletion_epoch'
        and not epoch_column.attisdropped)
    and (not relation.relrowsecurity or not relation.relforcerowsecurity)),
  0::bigint,'every current member/epoch relation forces RLS');

set local role argus_runtime;
select argus_private.set_request_context(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'dddddddd-0000-4000-8000-000000000001','aal1');
select is((select count(*)::bigint from argus_app.profiles),1::bigint,
  'the current owner can read current-epoch state');
reset role;

update argus_app.members set deletion_epoch=1
 where user_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';

set local role argus_runtime;
select argus_private.set_request_context(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'dddddddd-0000-4000-8000-000000000001','aal1');
select todo_start('U3 must make old-lifecycle reads invisible, not only reject writes');
select is((select count(*)::bigint from argus_app.profiles),0::bigint,
  'an old lifecycle cannot read rows from its closed epoch');
select todo_end();
select throws_ok(
  $$update argus_app.profiles set display_name='stale write'$$,
  'P0001','member_deletion_epoch_mismatch',
  'the current trigger rejects a stale-epoch write');
select lives_ok(
  $$insert into argus_app.preferences(user_id,deletion_epoch)
    values ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',1)
    on conflict (user_id) do update
      set deletion_epoch=excluded.deletion_epoch$$,
  'the current epoch can create new state');
reset role;

set local role argus_runtime;
select argus_private.set_request_context(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'eeeeeeee-0000-4000-8000-000000000001','aal1');
select is((select count(*)::bigint from argus_app.preferences
  where user_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),0::bigint,
  'another member cannot observe current-lifecycle state');
reset role;

delete from auth.users where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
select is(
  (select count(*)::bigint from argus_app.members
    where user_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')+
  (select count(*)::bigint from argus_app.profiles
    where user_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')+
  (select count(*)::bigint from argus_app.preferences
    where user_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  0::bigint,'Auth deletion cascades current direct member-owned rows');

select ok(exists(select 1 from auth.users
  where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
  'another member lifecycle is unaffected by owner deletion');

select * from finish();
rollback;
