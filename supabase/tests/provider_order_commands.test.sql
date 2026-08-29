begin;

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
do $membership$ begin
  execute pg_catalog.format(
    'grant argus_runtime,argus_worker,argus_waitlist,argus_edge,argus_member,argus_brokerage_owner,argus_identity_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions
  to argus_runtime, argus_worker, argus_waitlist;

create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to argus_runtime,argus_member;
set local search_path=extensions,pg_catalog,public;

select plan(44);

select has_table('argus_private','order_previews','order previews are private');
select has_table('argus_private','provider_commands','provider commands are private');
select has_table('argus_private','provider_command_attempts','provider attempts are private');
select has_table('argus_private','webull_order_mappings','provider order references are private');
select has_table('argus_brokerage','order_projection_generations','order details are immutable generations');
select has_column('argus_brokerage','order_projection_generations','order_list_generation','list rows bind one atomic list generation');
select has_column('argus_private','provider_commands','normalized_payload','command binds normalized payload');
select has_column('argus_private','provider_commands','restriction_generation','command binds restriction authority');
select has_column('argus_private','provider_commands','preview_id','command binds one reviewed preview');
select has_column('argus_private','order_previews','provider_preview_ref_ciphertext','raw preview identifier is encrypted');
select has_column('argus_private','webull_asset_mappings','asset_kind','asset mappings retain fail-closed normalized kind');
select has_column('argus_private','webull_asset_mappings','provider_asset_kind','unknown provider asset kind is preserved');
select has_index('argus_private','provider_commands','provider_commands_idempotency_key_unique','idempotency key is globally unique');
select ok(
  not has_schema_privilege('argus_runtime','auth','usage'),
  'runtime cannot traverse the Supabase-owned auth schema'
);
select ok(
  not exists (
    select 1
      from pg_proc proc
      join pg_namespace namespace on namespace.oid=proc.pronamespace
      cross join lateral aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl
     join pg_roles grantee on grantee.oid=acl.grantee
     where namespace.nspname='auth'
       and proc.proname='uid'
       and grantee.rolname='argus_runtime'
       and acl.privilege_type='EXECUTE'
  ),
  'runtime has no direct execute grant on the Supabase-owned auth uid helper'
);
select ok(
  has_function_privilege('argus_runtime','argus_private.request_user_id()','execute'),
  'runtime may execute only the Argus-owned request identity helper'
);
select is(
  (select count(*)::bigint from argus_private.provider_commands where state='pending'),
  0::bigint,
  'no legacy pending command can become a U7 idempotency winner'
);
select ok(
  not has_table_privilege('authenticated','argus_private.provider_commands','select'),
  'authenticated cannot access provider commands through the Data API'
);
select ok(
  not has_table_privilege('authenticated','argus_private.webull_order_mappings','select'),
  'authenticated cannot access provider order mappings through the Data API'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'argus_private.prepare_provider_order_command(uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz)',
    'execute'
  ),
  'authenticated cannot invoke the durable command capability'
);
select is(
  to_regprocedure('argus_private.create_provider_command(uuid,uuid,bigint,uuid,uuid,text,text,text,text,text,integer)')::text,
  null,
  'legacy unreviewed provider command capability is removed'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','authenticated','authenticated','u7-a@example.test','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','authenticated','authenticated','u7-b@example.test','',now(),'{}','{}',now(),now());
-- U14's auth.users provisioning trigger creates the matching member rows.
-- Seeding them again here would mask the production provisioning behavior and
-- violate the members primary key.
insert into argus_brokerage.connections(id,user_id,deletion_epoch,status) values
  ('aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'connected'),
  ('bbbbbbbb-1000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',0,'connected');
insert into argus_brokerage.accounts(
  id,user_id,deletion_epoch,connection_id,display_label,base_currency,status,
  capability_version,capabilities,provider_observed_at,fetched_at,expires_at
) values
  ('aaaaaaaa-2000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','Webull A1','USD','available',7,'[{"capability":"orders_read","provider_code":"ORDERS_READ","available":true},{"capability":"manual_orders","provider_code":"MANUAL_ORDERS","available":true}]',now(),now(),now()+interval '5 minutes'),
  ('aaaaaaaa-2000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','Webull A2','USD','available',7,'[{"capability":"orders_read","provider_code":"ORDERS_READ","available":true},{"capability":"manual_orders","provider_code":"MANUAL_ORDERS","available":true}]',now(),now(),now()+interval '5 minutes');
insert into argus_brokerage.projection_generations(
  user_id,deletion_epoch,connection_id,account_id,resource_type,generation,
  normalized_payload,provider_observed_at,fetched_at,expires_at,availability
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001','restrictions',1,'[]',now(),now(),now()+interval '5 minutes','available'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002','restrictions',1,'[]',now(),now(),now()+interval '5 minutes','available');
insert into argus_private.webull_asset_mappings(
  instrument_id,account_id,connection_id,user_id,deletion_epoch,
  provider_environment,provider_asset_id_ciphertext,provider_asset_id_hash,key_version
  ,asset_kind,provider_asset_kind
) values
  ('aaaaaaaa-6000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'sandbox',decode(repeat('ab',32),'hex'),repeat('a',64),1,'equity','EQUITY'),
  ('aaaaaaaa-6000-4000-8000-000000000002','aaaaaaaa-2000-4000-8000-000000000002','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'sandbox',decode(repeat('bc',32),'hex'),repeat('b',64),1,'etf','ETF');
insert into argus_private.order_previews(
  id,user_id,deletion_epoch,connection_id,account_id,capability_version,
  restriction_generation,reviewed_payload_hash,normalized_payload,expires_at,
  operation,policy_version,provider_preview_ref_ciphertext,
  provider_preview_ref_hash,provider_preview_key_version
) values
  ('aaaaaaaa-7000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001',7,1,repeat('c',64),'{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000001","side":"buy","order_type":"limit","time_in_force":"day","quantity":"1","limit_price":"10"}',now()+interval '1 minute','place','webull-sandbox-manual-v1',decode(repeat('cd',32),'hex'),repeat('d',64),1),
  ('aaaaaaaa-7000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001',7,1,repeat('e',64),'{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000001","side":"buy","order_type":"limit","time_in_force":"day","quantity":"2","limit_price":"10"}',now()+interval '1 minute','place','webull-sandbox-manual-v1',decode(repeat('ef',32),'hex'),repeat('f',64),1),
  ('aaaaaaaa-7000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002',7,1,repeat('1',64),'{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000002","side":"sell","order_type":"market","time_in_force":"day","quantity":"1","limit_price":null}',now()+interval '1 minute','place','webull-sandbox-manual-v1',decode(repeat('12',32),'hex'),repeat('2',64),1);

update argus_private.kill_switches set enabled=false
 where name in ('provider_egress','order_mutations','background_workers');

set local role argus_edge;
select argus_private.install_request_context(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001','aal1'
);
reset role;
set local role argus_member;

select is(
  (select state from argus_private.prepare_provider_order_command(
    'aaaaaaaa-7000-4000-8000-000000000001','aaaaaaaa-8000-4000-8000-000000000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001','place',null,
    'argus_000000000000000000000000000000000000000000000001','u7-idempotency-key-0001',
    '{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000001","side":"buy","order_type":"limit","time_in_force":"day","quantity":"1","limit_price":"10"}',repeat('c',64),'webull-sandbox-manual-v1'
  )),
  'dispatching'::text,
  'new command is dispatching before provider egress'::text
);
reset role;
select is(
  (select count(*)::bigint from argus_private.provider_command_attempts
    where command_id='aaaaaaaa-8000-4000-8000-000000000001'
      and attempt_kind='egress' and outcome='started'),
  1::bigint,
  'immutable started attempt commits with the command'
);
set local role argus_member;
select is(
  (select is_duplicate from argus_private.prepare_provider_order_command(
    'aaaaaaaa-7000-4000-8000-000000000001','aaaaaaaa-8000-4000-8000-000000000099',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001','place',null,
    'argus_000000000000000000000000000000000000000000000001','u7-idempotency-key-0001',
    '{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000001","side":"buy","order_type":"limit","time_in_force":"day","quantity":"1","limit_price":"10"}',repeat('c',64),'webull-sandbox-manual-v1'
  )),
  true,
  'exact duplicate returns the durable winner even after preview consumption'
);
reset role;
select is(
  (select count(*)::bigint from argus_private.provider_commands),
  1::bigint,
  'duplicate confirmation does not create a second command'
);
select is(
  (select count(*)::bigint from argus_private.provider_command_attempts
    where command_id='aaaaaaaa-8000-4000-8000-000000000001'
      and attempt_kind='egress' and outcome='started'),
  1::bigint,
  'duplicate confirmation does not create a second egress attempt'
);
set local role argus_brokerage_owner;
alter table argus_private.provider_commands
  disable trigger provider_commands_monotonic;
update argus_private.provider_commands
   set egress_started_at=clock_timestamp()-interval '31 seconds'
 where id='aaaaaaaa-8000-4000-8000-000000000001';
alter table argus_private.provider_commands
  enable trigger provider_commands_monotonic;
reset role;
select is(
  argus_private.coordinate_webull_recovery(1),
  1,
  'a stale durable dispatch checkpoint is scheduled for lookup-only recovery'
);
select ok(
  exists (
    select 1 from argus_private.outbox_events event
     where event.topic='brokerage_reconcile'
       and event.event_type='webull.command.reconciliation.requested'
       and event.aggregate_id='aaaaaaaa-8000-4000-8000-000000000001'
       and event.dedupe_key='webull-reconcile:aaaaaaaa-8000-4000-8000-000000000001'
  )
  and not exists (
    select 1 from argus_private.reconciliation_records record
     where record.command_id='aaaaaaaa-8000-4000-8000-000000000001'
  ),
  'the scheduler emits one command-bound event and leaves lookup claiming transactional'
);
set local role argus_member;
select throws_ok(
  $$select * from argus_private.prepare_provider_order_command(
    'aaaaaaaa-7000-4000-8000-000000000002','aaaaaaaa-8000-4000-8000-000000000002',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001','place',null,
    'argus_111111111111111111111111111111111111111111111111','u7-idempotency-key-0001',
    '{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000001","side":"buy","order_type":"limit","time_in_force":"day","quantity":"2","limit_price":"10"}',repeat('e',64),'webull-sandbox-manual-v1'
  )$$,
  'P0001','idempotency_conflict',
  'conflicting payload reuse cannot return the prior command'
);
select throws_ok(
  $$select * from argus_private.prepare_provider_order_command(
    'aaaaaaaa-7000-4000-8000-000000000002','aaaaaaaa-8000-4000-8000-000000000003',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001','place',null,
    'argus_222222222222222222222222222222222222222222222222','u7-idempotency-key-0002',
    '{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000001","side":"buy","order_type":"limit","time_in_force":"day","quantity":"2","limit_price":"10"}',repeat('e',64),'webull-sandbox-manual-v1'
  )$$,
  'P0001','account_command_blocked',
  'dispatching command blocks only its account'
);
select is(
  (select state from argus_private.prepare_provider_order_command(
    'aaaaaaaa-7000-4000-8000-000000000003','aaaaaaaa-8000-4000-8000-000000000004',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000002','place',null,
    'argus_333333333333333333333333333333333333333333333333','u7-idempotency-key-0003',
    '{"instrument_id":"aaaaaaaa-6000-4000-8000-000000000002","side":"sell","order_type":"market","time_in_force":"day","quantity":"1","limit_price":null}',repeat('1',64),'webull-sandbox-manual-v1'
  )),
  'dispatching'::text,
  'another account remains independently available'::text
);
reset role;
select throws_ok(
  $$update argus_private.provider_commands set state='accepted',updated_at=now()
     where id='aaaaaaaa-8000-4000-8000-000000000001';
    update argus_private.provider_commands set state='ambiguous',updated_at=now()
     where id='aaaaaaaa-8000-4000-8000-000000000001'$$,
  'P0001','invalid_provider_command_transition',
  'terminal command outcome cannot regress to ambiguity'
);
select throws_ok(
  $$update argus_private.provider_command_attempts set outcome='accepted'
     where command_id='aaaaaaaa-8000-4000-8000-000000000001'$$,
  'P0001','immutable_record',
  'provider attempt history is immutable even for the table owner path'
);

set local role argus_member;
select is(
  (select state from argus_private.record_provider_command_dispatch_outcome(
    'aaaaaaaa-8000-4000-8000-000000000001','ambiguous','ambiguous',
    'provider_response_unknown'
  )),
  'ambiguous'::text,
  'possible provider send transitions to lookup-only ambiguity'
);
reset role;
select is(
  (select count(*)::bigint
     from argus_private.outbox_events event
     join argus_private.provider_commands command
       on command.id=event.aggregate_id
      and command.tenant_id=event.tenant_id
      and command.lifecycle_id=event.lifecycle_id
      and command.user_id=event.user_id
    where event.event_type='webull.command.reconciliation.requested'
      and event.event_version=1
      and event.topic='brokerage_reconcile'
      and command.id='aaaaaaaa-8000-4000-8000-000000000001'),
  1::bigint,
  'ambiguous dispatch emits one command-bound lifecycle-scoped reconciliation event'
);
set local role argus_member;
select is(
  (select claim_outcome
     from argus_private.claim_provider_command_reconciliation(
       'aaaaaaaa-8000-4000-8000-000000000001'
     )),
  'claimed'::text,
  'member reconciliation uses the bounded shared lookup claim'
);
select lives_ok(
  $$select argus_private.record_provider_command_not_found(
      'aaaaaaaa-8000-4000-8000-000000000001'
    )$$,
  'provider not-found remains weak lookup-only evidence'
);
reset role;
update argus_private.reconciliation_records
   set next_attempt_at=clock_timestamp()
 where command_id='aaaaaaaa-8000-4000-8000-000000000001';
set local role argus_member;
select lives_ok(
  $statement$do $body$ begin
    perform claim.claim_outcome
      from argus_private.claim_provider_command_reconciliation(
        'aaaaaaaa-8000-4000-8000-000000000001'
      ) claim;
    perform argus_private.record_provider_command_not_found(
      'aaaaaaaa-8000-4000-8000-000000000001'
    );
  end $body$$statement$,
  'second lookup cannot resubmit the provider command'
);
reset role;
update argus_private.reconciliation_records
   set next_attempt_at=clock_timestamp()
 where command_id='aaaaaaaa-8000-4000-8000-000000000001';
set local role argus_member;
select lives_ok(
  $statement$do $body$ begin
    perform claim.claim_outcome
      from argus_private.claim_provider_command_reconciliation(
        'aaaaaaaa-8000-4000-8000-000000000001'
      ) claim;
    perform argus_private.record_provider_command_not_found(
      'aaaaaaaa-8000-4000-8000-000000000001'
    );
  end $body$$statement$,
  'third lookup remains reconciliation-only'
);
reset role;
update argus_private.reconciliation_records
   set next_attempt_at=clock_timestamp()
 where command_id='aaaaaaaa-8000-4000-8000-000000000001';
set local role argus_member;
select lives_ok(
  $statement$do $body$ begin
    perform claim.claim_outcome
      from argus_private.claim_provider_command_reconciliation(
        'aaaaaaaa-8000-4000-8000-000000000001'
      ) claim;
    perform argus_private.record_provider_command_not_found(
      'aaaaaaaa-8000-4000-8000-000000000001'
    );
  end $body$$statement$,
  'fourth lookup reaches the configured external-lookup bound'
);
reset role;
update argus_private.reconciliation_records
   set next_attempt_at=clock_timestamp()
 where command_id='aaaaaaaa-8000-4000-8000-000000000001';
set local role argus_member;
select is(
  (select claim_outcome
     from argus_private.claim_provider_command_reconciliation(
       'aaaaaaaa-8000-4000-8000-000000000001'
     )),
  'manual_review'::text,
  'fifth claim persists manual review without another provider lookup'
);
reset role;
select ok(
  (select state='manual_review'
     from argus_private.provider_commands
    where id='aaaaaaaa-8000-4000-8000-000000000001')
  and (select attempts=4 and status='manual_review'
         from argus_private.reconciliation_records
        where command_id='aaaaaaaa-8000-4000-8000-000000000001')
  and (select pg_catalog.count(*)=1
         from argus_private.provider_command_attempts
        where command_id='aaaaaaaa-8000-4000-8000-000000000001'
          and attempt_kind='egress' and outcome='started'),
  'bounded not-found recovery never creates a second egress attempt'
);

set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute pg_catalog.format(
    'update pg_temp.%I set user_id=$1,tenant_id=$2,lifecycle_id=$3,installed_at=clock_timestamp()',
    context_relation
  ) using
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,
    (select member.tenant_id from argus_app.members member
      where member.user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    (select member.lifecycle_id from argus_app.members member
      where member.user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
end $$;
reset role;
set local role argus_member;
select is(
  (select count(*)::bigint from argus_private.provider_commands),
  0::bigint,
  'another user cannot read commands'
);
select is(
  (select count(*)::bigint from argus_private.webull_order_mappings),
  0::bigint,
  'another user cannot read provider order mappings'
);

reset role;

select * from finish();
rollback;
