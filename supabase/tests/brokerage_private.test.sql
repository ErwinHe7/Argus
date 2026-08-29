begin;

-- PostgreSQL 17 gives a non-superuser role creator ADMIN but not SET on
-- newly created roles. Enable role switching only for this test transaction;
-- the final rollback restores the hosted membership options.
do $membership$ begin
  execute pg_catalog.format(
    'grant argus_runtime,argus_worker,argus_waitlist,argus_edge,argus_member,argus_callback,argus_identity_owner,argus_brokerage_owner to %I with set true',
    current_user
  );
end $membership$;
grant usage on schema extensions
  to argus_runtime, argus_worker, argus_waitlist;

create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to argus_runtime,argus_member,argus_callback;
set local search_path = extensions, pg_catalog, public;

select plan(36);

select has_table('argus_brokerage', 'connections', 'normalized connection state exists');
select has_table('argus_brokerage', 'accounts', 'local brokerage account projection root exists');
select has_table('argus_brokerage', 'projection_generations', 'immutable projections exist');
select has_table('argus_private', 'oauth_states', 'OAuth state is private');
select has_table('argus_private', 'webull_credentials', 'token ciphertext is private');
select has_table('argus_private', 'webull_account_mappings', 'provider identifiers are private');
select has_table('argus_private', 'webull_completion_handles', 'one-use completion handles are private');
select has_table('argus_private', 'provider_commands', 'durable provider commands are private');
select has_table('argus_private', 'provider_command_attempts', 'command attempts are private');
select has_table('argus_private', 'webull_asset_mappings', 'provider asset identifiers stay in a private mapping');
select has_column('argus_private', 'webull_credentials', 'provider_environment', 'credential envelope is provider-environment bound');
select has_column('argus_private', 'webull_account_mappings', 'provider_environment', 'account identifier envelope is provider-environment bound');
select has_column('argus_brokerage', 'accounts', 'capabilities', 'normalized account capabilities are stored privately');
select has_column('argus_brokerage', 'projection_generations', 'reason_code', 'projection availability reason is explicit');
select has_column('argus_brokerage', 'projection_generations', 'purge_after', 'projection retention is bounded');
select has_column('argus_private', 'projection_refresh_leases', 'connection_id', 'refresh lease is connection-bound');
select has_index('argus_brokerage', 'projection_generations', 'projection_generations_purge_due_idx', 'projection purge deadline is indexed');
select ok(
  has_table_privilege('argus_worker', 'argus_brokerage.projection_generations', 'delete'),
  'bounded worker may delete expired projection generations'
);
select is(
  (select count(*)::bigint from pg_policies
    where schemaname='argus_brokerage'
      and tablename='projection_generations'
      and policyname='u5_worker_projection_retention'
      and cmd='DELETE'),
  1::bigint,
  'worker projection deletion is constrained by an explicit retention policy'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
insert into argus_app.members (user_id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
on conflict (user_id) do nothing;

insert into argus_brokerage.connections (id, user_id, deletion_epoch, status)
values ('aaaaaaaa-1000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, 'connected');
insert into argus_brokerage.accounts (
  id, user_id, deletion_epoch, connection_id, display_label, base_currency, capability_version
) values (
  'aaaaaaaa-2000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
  'aaaaaaaa-1000-4000-8000-000000000001', 'Webull •••• 0001', 'USD', 1
);
insert into argus_brokerage.projection_generations (
  id, user_id, deletion_epoch, connection_id, account_id, resource_type,
  generation, normalized_payload, provider_observed_at, fetched_at, expires_at, availability
) values (
  'aaaaaaaa-3000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
  'aaaaaaaa-1000-4000-8000-000000000001', 'aaaaaaaa-2000-4000-8000-000000000001',
  'positions', 1, '[]', now(), now(), now() + interval '5 minutes', 'available'
);
insert into argus_private.webull_asset_mappings (
  instrument_id, account_id, connection_id, user_id, deletion_epoch,
  provider_environment, provider_asset_id_ciphertext,
  provider_asset_id_hash, key_version, asset_kind, provider_asset_kind
) values (
  'aaaaaaaa-6000-4000-8000-000000000001',
  'aaaaaaaa-2000-4000-8000-000000000001',
  'aaaaaaaa-1000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, 'sandbox',
  decode(repeat('ab',32),'hex'), repeat('e',64), 1, 'equity', 'EQUITY'
);

set local role argus_edge;
do $$ begin
  perform argus_private.install_request_context(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'bbbbbbbb-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
reset role;
set local role argus_member;
select is((select count(*)::bigint from argus_brokerage.connections), 0::bigint, 'user B cannot read user A connection');
select is((select count(*)::bigint from argus_brokerage.accounts), 0::bigint, 'user B cannot read user A account');
select is((select count(*)::bigint from argus_brokerage.projection_generations), 0::bigint, 'user B cannot read user A projection');
select is((select count(*)::bigint from argus_private.webull_asset_mappings), 0::bigint, 'user B cannot read user A provider asset mapping');

reset role;
set local role argus_identity_owner;
do $$
declare context_relation text:=current_setting('argus.request_context_relation');
begin
  execute pg_catalog.format(
    'update pg_temp.%I set user_id=$1,tenant_id=$2,lifecycle_id=$3,installed_at=clock_timestamp()',
    context_relation
  ) using
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,
    (select member.tenant_id from argus_app.members member
      where member.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
    (select member.lifecycle_id from argus_app.members member
      where member.user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
end $$;
reset role;
set local role argus_member;
select is((select count(*)::bigint from argus_brokerage.projection_generations), 1::bigint, 'verified owner can read projection');
select is((select count(*)::bigint from argus_private.webull_asset_mappings), 1::bigint, 'verified owner can read only their provider asset mapping');
select throws_ok(
  $$update argus_brokerage.projection_generations set normalized_payload = '{"positions":[{"symbol":"NO"}]}' where id = 'aaaaaaaa-3000-4000-8000-000000000001'$$,
  '42501',
  'permission denied for table projection_generations',
  'runtime cannot mutate an immutable projection generation'
);

reset role;
update argus_brokerage.connections set status='pending'
 where id='aaaaaaaa-1000-4000-8000-000000000001';
insert into argus_private.oauth_states (
  id,user_id,session_id,deletion_epoch,connection_id,state_hash,
  return_target,contract_version,expires_at
) values (
  'aaaaaaaa-5000-4000-8000-000000000010',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001',0,
  'aaaaaaaa-1000-4000-8000-000000000001',repeat('b',64),
  'webull_native','webull-connect-public-docs-2026-08-28',now()+interval '5 minutes'
);
set local role argus_callback;
select is(
  (select count(*)::bigint from argus_private.oauth_states
    where state_hash=repeat('b',64) and consumed_at is null),
  1::bigint,
  'installed callback context authorizes its exact lifecycle row policy'
);
select is(
  (select count(*)::bigint from argus_private.consume_webull_oauth_state(repeat('b',64),now())),
  1::bigint,
  'valid unexpired state hash crosses the narrow definer boundary once'
);
select is(
  (select count(*)::bigint from argus_private.consume_webull_oauth_state(repeat('b',64),now())),
  0::bigint,
  'consumed state hash cannot be replayed'
);
reset role;
insert into argus_private.oauth_states (
  id,user_id,session_id,deletion_epoch,connection_id,state_hash,
  return_target,contract_version,expires_at,created_at
) values (
  'aaaaaaaa-5000-4000-8000-000000000011',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001',0,
  'aaaaaaaa-1000-4000-8000-000000000001',repeat('c',64),
  'webull_native','webull-connect-public-docs-2026-08-28',
  now()-interval '5 minutes',now()-interval '10 minutes'
);
set local role argus_callback;
select is(
  (select count(*)::bigint from argus_private.consume_webull_oauth_state(repeat('c',64),now())),
  0::bigint,
  'expired state hash cannot cross the callback boundary'
);
reset role;
select is(
  (select count(*)::bigint from argus_private.oauth_states
    where state_hash=repeat('c',64) and consumed_at is null),
  1::bigint,
  'expired callback rejection does not mark the state consumed'
);
reset role;
update argus_brokerage.connections set status='connected'
 where id='aaaaaaaa-1000-4000-8000-000000000001';
insert into argus_private.oauth_states (
  id,user_id,session_id,deletion_epoch,connection_id,state_hash,
  return_target,contract_version,expires_at
) values (
  'aaaaaaaa-5000-4000-8000-000000000012',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-0000-4000-8000-000000000001',0,
  'aaaaaaaa-1000-4000-8000-000000000001',repeat('d',64),
  'webull_native','webull-connect-public-docs-2026-08-28',now()+interval '5 minutes'
);
set local role argus_callback;
select is(
  (select count(*)::bigint from argus_private.consume_webull_oauth_state(repeat('d',64),now())),
  0::bigint,
  'state cannot complete after its connection leaves pending status'
);
select is(
  (select count(*)::bigint from argus_private.oauth_states
    where state_hash=repeat('d',64) and consumed_at is null),
  1::bigint,
  'status-change callback rejection does not mark the state consumed'
);

reset role;

insert into argus_private.webull_credentials (
  connection_id, user_id, deletion_epoch, token_version, key_version,
  access_ciphertext, access_nonce, access_tag, refresh_ciphertext, refresh_nonce,
  refresh_tag, wrapped_data_key, wrapped_key_nonce, wrapped_key_tag,
  associated_data_hash, access_expires_at, refresh_expires_at
) values (
  'aaaaaaaa-1000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, 1, 1,
  decode('01','hex'), decode('02','hex'), decode('03','hex'), decode('04','hex'), decode('05','hex'),
  decode('06','hex'), decode('07','hex'), decode('08','hex'), decode('09','hex'),
  'associated-hash', now() + interval '30 minutes', now() + interval '15 days'
);
update argus_app.members
   set status = 'deletion_pending', deletion_epoch = deletion_epoch + 1, deletion_requested_at = now()
 where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

set local role argus_runtime;
select throws_ok(
  $$insert into argus_private.oauth_states (
      id, user_id, session_id, deletion_epoch, connection_id, state_hash,
      return_target, contract_version, expires_at
    ) values (
      'aaaaaaaa-5000-4000-8000-000000000001',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'aaaaaaaa-0000-4000-8000-000000000001', 0,
      'aaaaaaaa-1000-4000-8000-000000000001', repeat('a',64),
      'webull_native', 'webull-connect-public-docs-2026-08-28',
      now() + interval '5 minutes'
    )$$,
  '42501',
  'permission denied for table oauth_states',
  'deletion epoch rejects a late callback write'
);
reset role;

select is(
  (select count(*)::bigint from information_schema.role_table_grants
    where grantee in ('anon','authenticated')
      and table_schema = 'argus_private'
      and table_name in ('oauth_states','webull_credentials','webull_completion_handles','webull_asset_mappings','provider_commands','provider_command_attempts')),
  0::bigint,
  'client roles receive no credential or command table grants'
);

select ok(
  not has_function_privilege('authenticated', 'argus_private.consume_webull_oauth_state(text,timestamptz)', 'execute'),
  'authenticated cannot invoke the state capability directly'
);

select * from finish();
rollback;
