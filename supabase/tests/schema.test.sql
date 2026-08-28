begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(23);

select has_schema('argus_app', 'Argus-owned state has a private schema');
select has_schema('argus_brokerage', 'brokerage projections have a private schema');
select has_schema('argus_private', 'provider and operational state has a private schema');
select has_schema('pgmq', 'Supabase Queues extension schema exists');
select has_schema('cron', 'Supabase Cron extension schema exists');

select has_table('argus_app', 'members', 'member ownership root exists');
select has_table('argus_app', 'profiles', 'profiles are retained');
select has_table('argus_app', 'editorial_items', 'editorial data is retained');
select has_table('argus_app', 'intentions', 'Intentions remain Argus-owned');
select has_table('argus_app', 'future_mirror_runs', 'Future Mirror remains Argus-owned');
select has_table('argus_brokerage', 'projection_generations', 'brokerage state is a projection');
select has_table('argus_private', 'provider_commands', 'provider commands are durable and private');
select has_table('argus_private', 'outbox_events', 'transactional outbox exists');
select has_table('argus_private', 'deletion_tombstones', 'deletion fencing exists');

select is(
  (select count(*)::bigint
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'graphql_public')
      and c.relkind in ('r', 'p', 'v', 'm')
      and c.relname like 'argus_%'),
  0::bigint,
  'no Argus relation is created in an exposed schema'
);

select is(
  (select count(*)::bigint
     from information_schema.routines
    where routine_schema in ('public', 'graphql_public')
      and routine_name like 'argus_%'),
  0::bigint,
  'no Argus function is created in an exposed schema'
);

select is(
  (select count(*)::bigint
     from pg_roles
    where rolname in ('argus_runtime', 'argus_worker')
      and (rolsuper or rolcreaterole or rolcreatedb or rolreplication or rolbypassrls)),
  0::bigint,
  'application roles have no elevated PostgreSQL attributes'
);

select ok(
  exists (select 1 from pg_roles where rolname = 'argus_runtime' and not rolcanlogin),
  'runtime capability role is non-login until a separately rotated credential is provisioned'
);

select is(
  (select count(*)::bigint
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
      and c.relkind in ('r', 'p')
      and (not c.relrowsecurity or not c.relforcerowsecurity)),
  0::bigint,
  'every application table has RLS enabled and forced'
);

select is(
  (select count(*)::bigint
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('argus_app', 'argus_brokerage', 'argus_private')
      and c.relname = any(array[
        'demo_portfolios','demo_funding_sources','simulated_orders','simulated_order_fills',
        'ledger_transactions','cash_ledger_entries','position_ledger_entries',
        'portfolio_positions','portfolio_balance_snapshots','recurring_plans',
        'recurring_plan_runs','rebalance_previews','rebalance_preview_trades',
        'tenant_entitlements','demo_checkout_sessions','demo_reset_events'
      ])),
  0::bigint,
  'obsolete Demo ledger, funding, recurring, rebalance, and membership authority is absent'
);

select is(
  (select count(*)::bigint from argus_app.editorial_items where id = '10000000-0000-4000-8000-000000000001'),
  1::bigint,
  'deterministic non-brokerage editorial seed is present'
);

select is(
  (select count(*)::bigint from argus_app.catalog_assets where id = '10000000-0000-4000-8000-000000000002'),
  1::bigint,
  'deterministic non-brokerage catalog seed is present'
);

select is(
  (select count(*)::bigint from argus_private.schema_contract_versions where version = 'webull-supabase-v1'),
  1::bigint,
  'clean baseline contract version is recorded'
);

select * from finish();
rollback;
