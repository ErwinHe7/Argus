begin;

-- U5 transfers brokerage relation ownership to a NOLOGIN capability owner.
-- This rollback-only membership is fixture authority, never a production
-- runtime grant.
do $membership$ begin
  execute pg_catalog.format(
    'grant argus_brokerage_owner,argus_worker to %I with set true',current_user
  );
end $membership$;
grant usage on schema extensions to argus_worker;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(19);

set local role argus_worker;
select is(argus_private.retained_job_handler('webull.token.refresh.requested'),
  'webull-token-refresh','token refresh is explicitly allowlisted');
select is(argus_private.retained_job_handler('webull.projection.refresh.requested'),
  'webull-projection-refresh','projection refresh is explicitly allowlisted');
select is(argus_private.retained_job_handler('webull.command.reconciliation.requested'),
  'webull-reconciliation','existing-command lookup is explicitly allowlisted');
select is(argus_private.retained_job_handler('webull.order.place.requested'),null,
  'background placement has no handler');
reset role;
select ok(not has_table_privilege('argus_worker','argus_private.webull_credentials','select'),
  'worker cannot read credentials directly');
select ok(not has_table_privilege('argus_worker','argus_private.provider_commands','select'),
  'worker cannot read financial commands directly');
select ok(has_function_privilege('argus_worker',
  'argus_private.claim_webull_command_reconciliation(uuid,uuid)','execute'),
  'worker receives only the narrow reconciliation claim');
select ok(not has_function_privilege('argus_worker',
  'argus_private.prepare_provider_order_command(uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz)','execute'),
  'worker cannot prepare a provider command');
select ok(has_function_privilege('argus_member',
  'argus_private.disconnect_webull_connection(text,uuid)','execute'),
  'member capability can call the atomic disconnect boundary');
select is((select count(*)::bigint from cron.job
  where jobname='argus-webull-recovery-coordinate'
    and command='select argus_private.coordinate_webull_recovery(25);'),
  1::bigint,'Cron has one bounded composed recovery coordinator and no provider values');
select ok(not ((select proargnames::text from pg_proc
  where oid='argus_private.claim_webull_command_reconciliation(uuid,uuid)'::regprocedure)
  ~* 'normalized_payload|reviewed_payload|provider_preview'),
  'reconciliation claim cannot return reviewed or preview payloads');
select ok((select pg_get_functiondef(
  'argus_private.coordinate_webull_recovery(integer)'::regprocedure))
  !~* 'prepare_provider_order_command|insert[[:space:]]+into[[:space:]]+argus_private.provider_commands',
  'recovery enqueue cannot create a provider command');
select is(argus_private.coordinate_webull_recovery(25),0,
  'provider kill switch prevents recovery work from being enqueued');

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000','cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'authenticated','authenticated','u15@example.test','',now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into argus_app.members(user_id)
values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc')
on conflict (user_id) do nothing;
insert into argus_brokerage.connections(
  id,user_id,deletion_epoch,status,capability_version,authorized_at
) values (
  'cccccccc-1000-4000-8000-000000000001',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',0,'connected',1,now()
);
insert into argus_brokerage.accounts(
  id,user_id,deletion_epoch,connection_id,display_label,base_currency,status,
  capability_version,capabilities,fetched_at,expires_at
) values (
  'cccccccc-2000-4000-8000-000000000001',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',0,
  'cccccccc-1000-4000-8000-000000000001','Synthetic','USD','available',1,'[]',
  now(),now()+interval '5 minutes'
);
insert into argus_private.webull_credentials(
  connection_id,user_id,deletion_epoch,token_version,key_version,
  access_ciphertext,access_nonce,access_tag,refresh_ciphertext,refresh_nonce,
  refresh_tag,wrapped_data_key,wrapped_key_nonce,wrapped_key_tag,
  associated_data_hash,access_expires_at,refresh_expires_at,provider_environment
) values (
  'cccccccc-1000-4000-8000-000000000001',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',0,1,1,
  decode(repeat('11',32),'hex'),decode(repeat('12',12),'hex'),decode(repeat('13',16),'hex'),
  decode(repeat('21',32),'hex'),decode(repeat('22',12),'hex'),decode(repeat('23',16),'hex'),
  decode(repeat('31',32),'hex'),decode(repeat('32',12),'hex'),decode(repeat('33',16),'hex'),
  repeat('a',64),now()+interval '5 minutes',now()+interval '1 day','sandbox'
);

select throws_ok(
  $$insert into argus_private.outbox_events(
      user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
    ) values (
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',0,'brokerage_reconcile',
      'webull.token.refresh.requested','cccccccc-1000-4000-8000-000000000001',
      'wrong-topic-event-0001'
    )$$,
  '23514',null,'topic and handler type cannot be crossed'
);

update argus_app.members set status='deletion_pending',deletion_epoch=1,
  deletion_requested_at=clock_timestamp()
 where user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
insert into argus_private.deletion_tombstones(
  tenant_id,lifecycle_id,user_id,deletion_epoch
)
select member.tenant_id,member.lifecycle_id,member.user_id,member.deletion_epoch
  from argus_app.members member
 where member.user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';

select is((select status from argus_brokerage.connections
  where id='cccccccc-1000-4000-8000-000000000001'),'disconnected',
  'deletion atomically fences the Webull connection');
select is((select count(*)::bigint from argus_private.webull_credentials
  where user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),0::bigint,
  'deletion cryptographically destroys credential envelopes');
select is((select count(*)::bigint from argus_brokerage.accounts
  where user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),0::bigint,
  'deletion destroys provider mappings and projections through account ownership');
select ok((select webull_fenced_at is not null and webull_credentials_destroyed_at is not null
  from argus_private.deletion_tombstones
  where user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
  'deletion records both pre-Auth Webull fence checkpoints');
select ok((select pg_get_functiondef(
  'argus_private.complete_member_purge(uuid)'::regprocedure))
  ~ 'webull_credentials_destroyed_at is null',
  'Auth-last completion refuses an incomplete Webull destruction phase');

select * from finish();
rollback;
