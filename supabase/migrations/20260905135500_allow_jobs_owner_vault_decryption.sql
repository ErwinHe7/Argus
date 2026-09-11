-- New Supabase Vault versions evaluate this invoker function when the dispatch
-- owner reads vault.decrypted_secrets. That owner already has the reviewed
-- view grant; grant only the matching dependency, never to an Edge login.
do $vault_dependency$
begin
  if to_regprocedure('vault._crypto_aead_det_decrypt(bytea,bytea,bigint,bytea,bytea)') is not null then
    grant execute on function vault._crypto_aead_det_decrypt(bytea,bytea,bigint,bytea,bytea)
      to argus_jobs_owner;
  end if;
end
$vault_dependency$;
