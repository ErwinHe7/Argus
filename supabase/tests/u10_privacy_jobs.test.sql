begin;

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
grant argus_runtime, argus_worker, argus_waitlist, argus_brokerage_owner
  to current_user with set true;
grant usage on schema extensions
  to argus_runtime, argus_worker, argus_waitlist;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(18);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'authenticated','authenticated','privacy-a@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'authenticated','authenticated','privacy-b@example.test','',now(),
   '{"provider":"email","providers":["email"]}','{}',now(),now());
insert into argus_app.members(user_id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
on conflict (user_id) do nothing;
insert into argus_app.profiles(user_id,deletion_epoch,display_name)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'Purge me')
on conflict (user_id) do update set display_name=excluded.display_name;
insert into argus_private.media_upload_intents(
  id,user_id,deletion_epoch,bucket_id,object_path,mime_type,max_bytes,status,expires_at
) values (
  'aaaaaaaa-9000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'member-media',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/avatar.webp','image/webp',1024,'uploaded',now()+interval '1 day'
);
insert into argus_app.media_assets(
  id,storage_bucket,storage_path,mime_type,byte_size,checksum
) values (
  'aaaaaaaa-9100-4000-8000-000000000001','member-media',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/avatar.webp','image/webp',10,
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
);

-- A deletion must erase a retained command tree through the narrow U5 owner
-- phase; the generic postgres purge never receives brokerage table DML.
insert into argus_brokerage.connections(
  id,user_id,deletion_epoch,status,capability_version,authorized_at
) values (
  'aaaaaaaa-1000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'connected',1,now()
);
insert into argus_brokerage.accounts(
  id,user_id,deletion_epoch,connection_id,display_label,base_currency,status,
  capability_version,capabilities,fetched_at,expires_at
) values (
  'aaaaaaaa-2000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,
  'aaaaaaaa-1000-4000-8000-000000000001','Privacy brokerage','USD',
  'available',1,'[]',now(),now()+interval '5 minutes'
);
insert into argus_private.provider_commands(
  id,user_id,deletion_epoch,connection_id,account_id,operation,
  client_order_id,idempotency_key,normalized_payload_hash,
  reviewed_payload_hash,capability_version,state,egress_started_at
) values (
  'aaaaaaaa-8000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,
  'aaaaaaaa-1000-4000-8000-000000000001',
  'aaaaaaaa-2000-4000-8000-000000000001','place',
  'argus_privacy_command_000000000001','privacy-command-idempotency-0001',
  repeat('a',64),repeat('b',64),1,'manual_review',now()
);
insert into argus_private.provider_command_attempts(
  user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,
  'aaaaaaaa-8000-4000-8000-000000000001',1,'detail_lookup','not_found'
);
insert into argus_private.reconciliation_records(
  user_id,deletion_epoch,command_id,status,next_attempt_at,attempts,
  last_error_code
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,
  'aaaaaaaa-8000-4000-8000-000000000001','manual_review',now(),4,
  'provider_order_not_found'
);

set local role argus_runtime;
select argus_private.set_request_context(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001','aal2'
);
select throws_ok(
  $$select argus_private.begin_member_deletion(
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001','privacy-delete-key-0001'
  )$$,
  '42501','step_up_required',
  'deletion without an action-bound receipt fails closed'
);
reset role;
select is(
  (select count(*)::bigint from argus_app.privacy_requests
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'failed deletion leaves no partial request'
);

insert into argus_private.step_up_receipts(
  user_id,session_id,deletion_epoch,action,receipt_hash,aal,expires_at
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001',0,'argus_delete',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','aal2',now()+interval '5 minutes'
), (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'bbbbbbbb-0000-4000-8000-000000000001',0,'argus_delete',
  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','aal2',now()+interval '5 minutes'
);

set local role argus_runtime;
select argus_private.set_request_context(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001','aal2'
);
select lives_ok(
  $$select argus_private.begin_member_deletion(
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001','privacy-delete-key-0001'
  )$$,
  'valid AAL2 deletion request commits tombstone, epoch, and outbox atomically'
);
select is(
  (select count(*)::bigint from argus_private.deletion_tombstones
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'deletion creates one tombstone'
);
reset role;
select is(
  (select count(*)::bigint from argus_private.outbox_events event
    join argus_private.deletion_tombstones tombstone on tombstone.id=event.aggregate_id
    where tombstone.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      and event.user_id is null and event.deletion_epoch is null),
  1::bigint,
  'purge event is provider-neutral and survives member Auth cascade'
);
set local role argus_runtime;
select ok(
  (select consumed_at is not null from argus_private.step_up_receipts
    where receipt_hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  'successful deletion consumes the receipt'
);
select is(
  argus_private.begin_member_deletion(
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001','privacy-delete-key-0001'
  ),
  (select id from argus_app.privacy_requests
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and request_type='deletion'),
  'same-owner idempotency replay returns the original request without a fresh receipt'
);
reset role;
select is(
  (select count(*)::bigint from argus_private.deletion_tombstones
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'idempotency replay creates no duplicate tombstone'
);

set local role argus_runtime;
select argus_private.set_request_context(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'bbbbbbbb-0000-4000-8000-000000000001','aal2'
);
select throws_ok(
  $$select argus_private.begin_member_deletion(
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'bbbbbbbb-0000-4000-8000-000000000001','privacy-delete-key-0001'
  )$$,
  '42501','step_up_required',
  'another user cannot replay or learn an existing deletion key'
);
reset role;
select is(
  (select consumed_at from argus_private.step_up_receipts
    where receipt_hash='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
  null::timestamptz,
  'failed action-bound verification leaves its receipt unconsumed'
);

set local role argus_worker;
select lives_ok(
  format(
    'select * from argus_private.prepare_member_purge(%L)',
    (select id from argus_private.deletion_tombstones
      where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  ),
  'purge preparation neutralizes old retained work'
);
reset role;
select ok(
  exists(select 1 from auth.users where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  and exists(select 1 from argus_private.deletion_tombstones
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and purge_phase='neutralized'),
  'Auth identity remains present after neutralization'
);

set local role argus_worker;
select argus_private.mark_member_storage_purged(
  (select id from argus_private.deletion_tombstones
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  jsonb_build_array(jsonb_build_object(
    'bucket_id','member-media',
    'path_hash',encode(digest(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/avatar.webp','sha256'
    ),'hex')
  ))
);
select argus_private.purge_member_argus_data(
  (select id from argus_private.deletion_tombstones
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
);
reset role;
select ok(
  exists(select 1 from auth.users where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  and exists(select 1 from argus_private.deletion_tombstones
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and purge_phase='data_purged'),
  'Argus data is purged while Auth identity still exists'
);
select is(
  (select count(*)::bigint from argus_app.profiles
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  + (select count(*)::bigint from argus_app.media_assets
    where storage_path like 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/%'),
  0::bigint,
  'purge removes owner and global-path Argus product rows'
);
select is(
  (select count(*)::bigint from argus_brokerage.connections
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  + (select count(*)::bigint from argus_brokerage.accounts
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  + (select count(*)::bigint from argus_private.provider_commands
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  + (select count(*)::bigint from argus_private.provider_command_attempts
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  + (select count(*)::bigint from argus_private.reconciliation_records
    where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'privacy purge removes the lifecycle-scoped brokerage command tree'
);
set local role argus_worker;
select throws_ok(
  format(
    'select argus_private.complete_member_purge(%L)',
    (select id from argus_private.deletion_tombstones
      where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  ),
  'P0001','auth_identity_still_present',
  'terminal purge cannot be marked before Auth deletion'
);
reset role;

delete from auth.users where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role argus_worker;
select lives_ok(
  format(
    'select argus_private.complete_member_purge(%L)',
    (select id from argus_private.deletion_tombstones
      where user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  ),
  'purge completes only after Auth identity is absent'
);
reset role;
select ok(
  not exists(select 1 from auth.users where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
  and exists(select 1 from argus_private.deletion_tombstones tombstone
    join argus_private.purge_receipts receipt on receipt.tombstone_id=tombstone.id
    where tombstone.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      and tombstone.purge_phase='complete' and tombstone.status='purged'),
  'terminal tombstone and receipt appear only after Auth-last completion'
);

select * from finish();
rollback;
