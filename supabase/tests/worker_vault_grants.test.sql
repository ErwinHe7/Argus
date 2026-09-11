begin;

create extension if not exists pgtap with schema extensions;
set local search_path=extensions,pg_catalog,public;

select plan(4);

select ok(has_table_privilege('argus_jobs_owner','vault.decrypted_secrets','select'),
  'only the dispatch owner retains its reviewed Vault view access');
select ok(
  case when to_regprocedure('vault._crypto_aead_det_decrypt(bytea,bytea,bigint,bytea,bytea)') is null
    then true
    else has_function_privilege('argus_jobs_owner',
      'vault._crypto_aead_det_decrypt(bytea,bytea,bigint,bytea,bytea)','execute')
  end,
  'the dispatch owner can execute the Vault view dependency when installed');
select ok(not exists (
  select 1 from unnest(array['anon','authenticated','argus_edge','argus_worker_edge',
    'argus_runtime','argus_member','argus_staff','argus_callback','argus_worker']) role_name
  where has_table_privilege(role_name,'vault.decrypted_secrets','select')
), 'public and request roles cannot read Vault secrets');
select ok(not exists (
  select 1 from unnest(array['anon','authenticated','argus_edge','argus_worker_edge',
    'argus_runtime','argus_member','argus_staff','argus_callback','argus_worker']) role_name
  where has_function_privilege(role_name,
    'argus_private.resolve_worker_invocation_config()','execute')
), 'public and request roles cannot resolve worker credentials');

select * from finish();
rollback;
