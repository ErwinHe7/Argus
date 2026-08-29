begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, pg_catalog, public;

select plan(35);

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

select ok(
  exists (select 1 from pg_roles where rolname = 'argus_edge' and rolcanlogin),
  'Edge pooler identity is a LOGIN role'
);

select ok(
  exists (
    select 1 from pg_roles
     where rolname = 'argus_edge'
       and not rolsuper and not rolcreaterole and not rolcreatedb
       and not rolreplication and not rolbypassrls
  ),
  'Edge pooler identity cannot bypass RLS or administer PostgreSQL'
);

select ok(
  exists (select 1 from pg_roles where rolname = 'argus_edge' and not rolinherit),
  'Edge pooler identity cannot inherit application privileges outside SET ROLE'
);

select ok(
  pg_has_role('argus_edge', 'argus_runtime', 'member'),
  'Edge pooler identity may SET ROLE to the runtime capability role'
);

select is(
  (select array_agg(parent.rolname::text order by parent.rolname)
     from pg_auth_members membership
     join pg_roles member on member.oid = membership.member
     join pg_roles parent on parent.oid = membership.roleid
    where member.rolname = 'argus_edge'),
  array['argus_callback','argus_member','argus_runtime','argus_staff'],
  'Edge pooler identity has only the reviewed request capability memberships'
);

select ok(
  not has_schema_privilege('argus_edge', 'argus_app', 'usage')
    and not has_schema_privilege('argus_edge', 'argus_brokerage', 'usage')
    and has_schema_privilege('argus_edge', 'argus_private', 'usage'),
  'Edge pooler identity can reach the private context installer but no relation schema'
);

select is(
  (select count(*)::bigint
     from information_schema.role_table_grants
    where grantee = 'argus_edge'
      and table_schema in ('argus_app', 'argus_brokerage', 'argus_private')),
  0::bigint,
  'Edge pooler identity has no direct application table privileges'
);

select ok(
  (select rolpassword is null or rolpassword like 'SCRAM-SHA-256$%'
     from pg_authid where rolname = 'argus_edge'),
  'Edge pooler password is absent on bootstrap or stored only as a SCRAM verifier'
);

select ok(
  (select rolconfig @> array[
    'statement_timeout=15s',
    'lock_timeout=3s',
    'idle_in_transaction_session_timeout=15s',
    'idle_session_timeout=5min'
  ] from pg_roles where rolname = 'argus_edge'),
  'Edge pooler identity has bounded query and idle timeouts'
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

select is(
  (select count(*)::bigint
     from pg_class relation
     join pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname in ('argus_app','argus_brokerage','argus_private')
      and relation.relkind in ('r','p')),
  124::bigint,
  'the current application relation baseline has one reviewed inventory'
);

select ok(
  exists(select 1 from pg_constraint
    where conrelid='argus_app.circle_assets'::regclass and contype='f'
      and pg_get_constraintdef(oid) like '%FOREIGN KEY (user_id, circle_id)%')
  and exists(select 1 from pg_constraint
    where conrelid='argus_app.future_mirror_points'::regclass and contype='f'
      and pg_get_constraintdef(oid) like '%FOREIGN KEY (user_id, run_id)%')
  and exists(select 1 from pg_constraint
    where conrelid='argus_app.briefing_sections'::regclass and contype='f'
      and pg_get_constraintdef(oid) like '%FOREIGN KEY (user_id, briefing_id)%'),
  'existing nested member children use parent-qualified foreign keys'
);

select ok(
  exists(select 1 from pg_constraint
    where conrelid='argus_app.briefing_read_states'::regclass and contype='f'
      and pg_get_constraintdef(oid)
        like '%FOREIGN KEY (user_id, deletion_epoch, briefing_id)%'),
  'briefing read state is parent- and lifecycle-qualified'
);

select * from finish();
rollback;
