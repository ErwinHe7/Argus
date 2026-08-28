begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(18);

select has_table('argus_brokerage', 'connections', 'normalized connection state exists');
select has_table('argus_brokerage', 'accounts', 'local brokerage account projection root exists');
select has_table('argus_brokerage', 'projection_generations', 'immutable projections exist');
select has_table('argus_private', 'oauth_states', 'OAuth state is private');
select has_table('argus_private', 'webull_credentials', 'token ciphertext is private');
select has_table('argus_private', 'webull_account_mappings', 'provider identifiers are private');
select has_table('argus_private', 'provider_commands', 'durable provider commands are private');
select has_table('argus_private', 'provider_command_attempts', 'command attempts are private');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
insert into argus_app.members (user_id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

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
  'positions', 1, '{"positions":[]}', now(), now(), now() + interval '5 minutes', 'available'
);

set local role argus_runtime;
do $$ begin
  perform argus_private.set_request_context(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'bbbbbbbb-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is((select count(*)::bigint from argus_brokerage.connections), 0::bigint, 'user B cannot read user A connection');
select is((select count(*)::bigint from argus_brokerage.accounts), 0::bigint, 'user B cannot read user A account');
select is((select count(*)::bigint from argus_brokerage.projection_generations), 0::bigint, 'user B cannot read user A projection');

do $$ begin
  perform argus_private.set_request_context(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select is((select count(*)::bigint from argus_brokerage.projection_generations), 1::bigint, 'verified owner can read projection');
select throws_ok(
  $$update argus_brokerage.projection_generations set normalized_payload = '{"positions":[{"symbol":"NO"}]}' where id = 'aaaaaaaa-3000-4000-8000-000000000001'$$,
  '42501',
  'permission denied for table projection_generations',
  'runtime cannot mutate an immutable projection generation'
);

select is(
  argus_private.create_provider_command(
    'aaaaaaaa-4000-4000-8000-000000000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
    'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001',
    'place', 'client-order-0001', 'idem-key-0000000000000001',
    'payload-hash-1', 'review-hash-1', 1
  ),
  'aaaaaaaa-4000-4000-8000-000000000001'::uuid,
  'first command is durably created'
);
select is(
  argus_private.create_provider_command(
    'aaaaaaaa-4000-4000-8000-000000000099',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
    'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001',
    'place', 'client-order-0001', 'idem-key-0000000000000001',
    'payload-hash-1', 'review-hash-1', 1
  ),
  'aaaaaaaa-4000-4000-8000-000000000001'::uuid,
  'same owner, account, operation, and payload returns existing command'
);
select throws_ok(
  $$select argus_private.create_provider_command(
    'aaaaaaaa-4000-4000-8000-000000000098',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0,
    'aaaaaaaa-1000-4000-8000-000000000001',
    'aaaaaaaa-2000-4000-8000-000000000001',
    'cancel', 'client-order-0001', 'idem-key-0000000000000001',
    'payload-hash-CONFLICT', 'review-hash-1', 1
  )$$,
  'P0001',
  'idempotency_conflict',
  'conflicting idempotency reuse is rejected'
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
do $$ begin
  perform argus_private.set_request_context(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'aal1'
  );
end $$;
select throws_ok(
  $$insert into argus_private.oauth_states (
      id, user_id, session_id, deletion_epoch, state_hash, return_target, expires_at
    ) values (
      'aaaaaaaa-5000-4000-8000-000000000001',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'aaaaaaaa-0000-4000-8000-000000000001', 0,
      'late-state-hash', '/portfolio', now() + interval '5 minutes'
    )$$,
  'P0001',
  'member_deletion_epoch_mismatch',
  'deletion epoch rejects a late callback write'
);
reset role;

select is(
  (select count(*)::bigint from information_schema.role_table_grants
    where grantee in ('anon','authenticated')
      and table_schema = 'argus_private'
      and table_name in ('oauth_states','webull_credentials','provider_commands','provider_command_attempts')),
  0::bigint,
  'client roles receive no credential or command table grants'
);

select * from finish();
rollback;
