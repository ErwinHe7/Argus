\set ON_ERROR_STOP on
\timing on

-- U5 rollback-only representative-volume query-plan fixture.
-- Run only against the disposable local Supabase database after a clean
-- migration replay:
--   psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
--     -X -f scripts/measure-u5-brokerage-plans.sql
--
-- The fixture models 100 members with 100 accounts each, 1m general
-- projection generations, 2m typed order generations, 100k commands, and
-- 10k due ambiguous reconciliations. All data and trigger state roll back.

begin;
set local statement_timeout='0';
set local lock_timeout='3s';
set local synchronous_commit=off;
set local work_mem='64MB';
set local maintenance_work_mem='512MB';

-- The retained local postgres role has an installer-owned membership with
-- SET/INHERIT false and must not retain SET authority for the U5 domain owner.
-- This preflight also detects residue from an interrupted manual harness before
-- any fixture is written. ON_ERROR_STOP disconnects on failure, rolling back
-- every later membership, policy, trigger, and data edit.
do $$
begin
  if pg_catalog.pg_has_role(
    'postgres','argus_brokerage_owner','set'
  ) or exists (
    select 1 from pg_catalog.pg_policies policy
     where policy.policyname in (
       'u5_performance_connection_insert','u5_performance_account_insert'
     )
  ) then
    raise exception 'u5_performance_harness_residue';
  end if;
end
$$;

\echo 'U5 fixture: 100 member lifecycles'
insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  pg_catalog.md5('u5-performance-user-'||member_ordinal::text)::uuid,
  'authenticated','authenticated',
  'u5-performance-'||member_ordinal::text||'@example.test','',
  pg_catalog.clock_timestamp(),'{}'::jsonb,'{}'::jsonb,
  pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp()
from pg_catalog.generate_series(1,100) member(member_ordinal);

create temporary table u5_performance_accounts on commit drop as
select
  account.account_ordinal,
  ((account.account_ordinal-1)/100)+1 member_ordinal,
  member.user_id,member.tenant_id,member.lifecycle_id,member.deletion_epoch,
  pg_catalog.md5(
    'u5-performance-connection-'||(((account.account_ordinal-1)/100)+1)::text
  )::uuid connection_id,
  pg_catalog.md5(
    'u5-performance-account-'||account.account_ordinal::text
  )::uuid account_id,
  pg_catalog.md5(
    'u5-performance-order-'||account.account_ordinal::text
  )::uuid order_id
from pg_catalog.generate_series(1,10000) account(account_ordinal)
join argus_app.members member
  on member.user_id=pg_catalog.md5(
    'u5-performance-user-'||(((account.account_ordinal-1)/100)+1)::text
  )::uuid;
create unique index u5_performance_accounts_ordinal_idx
  on u5_performance_accounts(account_ordinal);

-- Identity fixtures are created by retained postgres above. Every U5 relation
-- below is then accessed as the NOLOGIN brokerage owner. Membership, scoped
-- insert policies, trigger changes, and fixture rows are all transactional and
-- are erased by the final ROLLBACK (or by disconnect after ON_ERROR_STOP).
grant select on u5_performance_accounts to argus_brokerage_owner;
grant argus_brokerage_owner to postgres
  with set true granted by postgres;
set local role argus_brokerage_owner;
create policy u5_performance_connection_insert
  on argus_brokerage.connections
  for insert to argus_brokerage_owner with check (
    exists (
      select 1 from pg_temp.u5_performance_accounts fixture
       where fixture.user_id=connections.user_id
         and fixture.connection_id=connections.id
    )
  );
create policy u5_performance_account_insert
  on argus_brokerage.accounts
  for insert to argus_brokerage_owner with check (
    exists (
      select 1 from pg_temp.u5_performance_accounts fixture
       where fixture.user_id=accounts.user_id
         and fixture.connection_id=accounts.connection_id
         and fixture.account_id=accounts.id
    )
  );

-- These trigger changes and all fixture rows are transactional. The generated
-- rows already contain the complete validated parent identity, so bypassing
-- write-path materializers keeps the load bounded without changing query
-- indexes or planner statistics.
alter table argus_brokerage.connections disable trigger user;
alter table argus_brokerage.accounts disable trigger user;
alter table argus_brokerage.projection_generations disable trigger user;
alter table argus_private.webull_order_mappings disable trigger user;
alter table argus_brokerage.order_projection_generations disable trigger user;
alter table argus_private.provider_commands disable trigger user;
alter table argus_private.reconciliation_records disable trigger user;

\echo 'U5 fixture: 100 connections and 10k accounts (100/member)'
insert into argus_brokerage.connections(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,status,capability_version,
  authorized_at
)
select distinct on (fixture.connection_id)
  fixture.connection_id,fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,'connected',1,pg_catalog.clock_timestamp()
from u5_performance_accounts fixture
order by fixture.connection_id;

insert into argus_brokerage.accounts(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,
  display_label,base_currency,status,capability_version,capabilities,
  provider_observed_at,fetched_at,expires_at,capability_normalization_state
)
select
  fixture.account_id,fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,fixture.connection_id,
  'U5 account '||fixture.account_ordinal::text,'USD','available',1,'[]'::jsonb,
  pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp(),
  pg_catalog.clock_timestamp()+interval '1 hour','ready'
from u5_performance_accounts fixture;

\echo 'U5 fixture: 1m general projection generations'
insert into argus_brokerage.projection_generations(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
  resource_type,generation,normalized_payload,provider_observed_at,fetched_at,
  expires_at,availability,purge_after,normalization_state
)
select
  pg_catalog.md5(
    'u5-performance-projection-'||fixture.account_ordinal::text||'-'||
    generation.generation::text
  )::uuid,
  fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,fixture.connection_id,fixture.account_id,
  'positions',generation.generation,'[]'::jsonb,
  pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp(),
  pg_catalog.clock_timestamp()+interval '5 minutes','available',
  pg_catalog.clock_timestamp()+interval '30 days','ready'
from u5_performance_accounts fixture
cross join pg_catalog.generate_series(1,100) generation(generation);

\echo 'U5 fixture: 10k order mappings and 2m typed order generations'
insert into argus_private.webull_order_mappings(
  order_id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,
  account_id,provider_environment,provider_order_ref_ciphertext,
  provider_order_ref_hash,key_version
)
select
  fixture.order_id,fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,fixture.connection_id,fixture.account_id,'sandbox',
  pg_catalog.decode(pg_catalog.repeat('ab',32),'hex'),
  pg_catalog.md5('u5-performance-order-hash-a-'||fixture.account_ordinal::text)||
    pg_catalog.md5('u5-performance-order-hash-b-'||fixture.account_ordinal::text),
  1
from u5_performance_accounts fixture;

insert into argus_brokerage.order_projection_generations(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
  order_id,generation,source,state,filled_quantity,normalized_payload,
  provider_observed_at,fetched_at,purge_after,normalization_state,
  instrument_id,symbol,side,provider_side,order_type,provider_order_type,
  time_in_force,provider_time_in_force,quantity,currency,provider_state,terminal
)
select
  pg_catalog.md5(
    'u5-performance-order-generation-'||fixture.account_ordinal::text||'-'||
    generation.generation::text
  )::uuid,
  fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,fixture.connection_id,fixture.account_id,
  fixture.order_id,generation.generation,'detail','pending',0,'{}'::jsonb,
  pg_catalog.clock_timestamp(),pg_catalog.clock_timestamp(),
  pg_catalog.clock_timestamp()+interval '90 days','ready',
  '00000000-0000-4000-8000-000000000001'::uuid,
  'ARGUS','buy','BUY','limit','LIMIT','day','DAY',1,'USD','PENDING',false
from u5_performance_accounts fixture
cross join pg_catalog.generate_series(1,200) generation(generation);

\echo 'U5 fixture: 100k commands including 10k account-scoped ambiguities'
insert into argus_private.provider_commands(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
  operation,client_order_id,idempotency_key,normalized_payload_hash,
  reviewed_payload_hash,capability_version,state,egress_started_at,
  normalized_payload
)
select
  pg_catalog.md5('u5-performance-command-'||command.command_ordinal::text)::uuid,
  fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,fixture.connection_id,fixture.account_id,'place',
  'argus_perf_'||command.command_ordinal::text,
  'u5-performance-idempotency-'||command.command_ordinal::text,
  pg_catalog.repeat('a',64),pg_catalog.repeat('b',64),1,
  case when command.command_ordinal<=10000 then 'ambiguous' else 'failed' end,
  case when command.command_ordinal<=10000
       then pg_catalog.clock_timestamp()-interval '1 minute' end,
  '{}'::jsonb
from pg_catalog.generate_series(1,100000) command(command_ordinal)
join u5_performance_accounts fixture
  on fixture.account_ordinal=((command.command_ordinal-1)%10000)+1;

insert into argus_private.reconciliation_records(
  tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
  command_id,status,next_attempt_at,attempts
)
select
  fixture.tenant_id,fixture.lifecycle_id,fixture.user_id,
  fixture.deletion_epoch,fixture.connection_id,fixture.account_id,
  pg_catalog.md5('u5-performance-command-'||fixture.account_ordinal::text)::uuid,
  'pending',pg_catalog.clock_timestamp()-interval '1 minute',0
from u5_performance_accounts fixture;

alter table argus_brokerage.connections enable trigger user;
alter table argus_brokerage.accounts enable trigger user;
alter table argus_brokerage.projection_generations enable trigger user;
alter table argus_private.webull_order_mappings enable trigger user;
alter table argus_brokerage.order_projection_generations enable trigger user;
alter table argus_private.provider_commands enable trigger user;
alter table argus_private.reconciliation_records enable trigger user;

analyze argus_brokerage.accounts;
analyze argus_brokerage.projection_generations;
analyze argus_private.webull_order_mappings;
analyze argus_brokerage.order_projection_generations;
analyze argus_private.provider_commands;
analyze argus_private.reconciliation_records;

\echo 'U5 PLAN 1: latest ready typed projection (budget <= 200 ms)'
explain (analyze,buffers,timing,summary)
select generation.id,generation.generation,generation.resource_type,
       generation.provider_observed_at,generation.fetched_at,
       generation.expires_at,generation.availability,generation.reason_code,
       argus_private.read_brokerage_projection_payload(generation.id) payload
from argus_brokerage.projection_generations generation
join argus_brokerage.accounts account
  on account.tenant_id=generation.tenant_id
 and account.lifecycle_id=generation.lifecycle_id
 and account.id=generation.account_id
 and account.user_id=generation.user_id
where generation.tenant_id=(
        select tenant_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.lifecycle_id=(
        select lifecycle_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.user_id=(
        select user_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.account_id=(
        select account_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.resource_type='positions'
  and generation.normalization_state='ready'
order by generation.generation desc
limit 1;

\echo 'U5 PLAN 2: append next-generation lookup (append budget <= 500 ms)'
explain (analyze,buffers,timing,summary)
select coalesce(pg_catalog.max(generation.generation),0)+1
from argus_brokerage.projection_generations generation
where generation.tenant_id=(
        select tenant_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.lifecycle_id=(
        select lifecycle_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.account_id=(
        select account_id from u5_performance_accounts where account_ordinal=1
      )
  and generation.resource_type='positions';

\echo 'U5 PLAN 3: account-scoped command ambiguity gate (budget <= 150 ms)'
explain (analyze,buffers,timing,summary)
select 1
from argus_private.provider_commands command
where command.tenant_id=(
        select tenant_id from u5_performance_accounts where account_ordinal=1
      )
  and command.lifecycle_id=(
        select lifecycle_id from u5_performance_accounts where account_ordinal=1
      )
  and command.user_id=(
        select user_id from u5_performance_accounts where account_ordinal=1
      )
  and command.account_id=(
        select account_id from u5_performance_accounts where account_ordinal=1
      )
  and command.state in ('dispatching','ambiguous','reconciling','manual_review')
limit 1;

\echo 'U5 PLAN 4: queue-like due reconciliation claim (budget <= 150 ms)'
explain (analyze,buffers,timing,summary)
select reconciliation.command_id
from argus_private.reconciliation_records reconciliation
join argus_private.provider_commands command
  on command.tenant_id=reconciliation.tenant_id
 and command.lifecycle_id=reconciliation.lifecycle_id
 and command.user_id=reconciliation.user_id
 and command.connection_id=reconciliation.connection_id
 and command.account_id=reconciliation.account_id
 and command.id=reconciliation.command_id
where reconciliation.status in ('pending','running')
  and reconciliation.attempts<4
  and reconciliation.next_attempt_at<=pg_catalog.clock_timestamp()
  and command.state in ('ambiguous','reconciling')
order by reconciliation.next_attempt_at,reconciliation.command_id
limit 25
for update of reconciliation skip locked;

rollback;

-- Prove the rollback restored the retained role boundary and removed every
-- deterministic fixture/policy. These checks are intentionally outside the
-- fixture transaction.
do $$
begin
  if pg_catalog.pg_has_role(
    'postgres','argus_brokerage_owner','set'
  ) or exists (
    select 1
      from pg_catalog.pg_auth_members membership
      join pg_catalog.pg_roles granted_role
        on granted_role.oid=membership.roleid
      join pg_catalog.pg_roles member_role
        on member_role.oid=membership.member
      join pg_catalog.pg_roles grantor_role
        on grantor_role.oid=membership.grantor
     where granted_role.rolname='argus_brokerage_owner'
       and member_role.rolname='postgres'
       and grantor_role.rolname='postgres'
       and (membership.set_option or membership.inherit_option)
  ) or exists (
    select 1 from pg_catalog.pg_policies policy
     where policy.policyname in (
       'u5_performance_connection_insert','u5_performance_account_insert'
     )
  ) or exists (
    select 1 from auth.users user_row
     where user_row.id=any(array(
       select pg_catalog.md5(
         'u5-performance-user-'||member_ordinal::text
       )::uuid
       from pg_catalog.generate_series(1,100) member(member_ordinal)
     ))
  ) then
    raise exception 'u5_performance_harness_cleanup_failed';
  end if;
end
$$;
