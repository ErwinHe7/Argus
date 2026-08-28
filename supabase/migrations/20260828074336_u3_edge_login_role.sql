-- U3: login identity for the Edge transaction-pooler connection.
-- The password is deliberately absent from migrations. Provision and rotate it
-- out-of-band, then store the resulting pooler DSN as the SUPABASE_DB_URL Edge
-- secret. All application privileges remain on the NOLOGIN argus_runtime role.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'argus_edge') then
    create role argus_edge
      login noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

alter role argus_edge password null;
alter role argus_edge set statement_timeout = '15s';
alter role argus_edge set lock_timeout = '3s';
alter role argus_edge set idle_in_transaction_session_timeout = '15s';
alter role argus_edge set idle_session_timeout = '5min';

revoke all on schema argus_app, argus_brokerage, argus_private from argus_edge;
revoke all on all tables in schema argus_app, argus_brokerage, argus_private
  from argus_edge;
revoke all on all sequences in schema argus_app, argus_brokerage, argus_private
  from argus_edge;
revoke all on all functions in schema argus_app, argus_brokerage, argus_private
  from argus_edge;

grant argus_runtime to argus_edge;
