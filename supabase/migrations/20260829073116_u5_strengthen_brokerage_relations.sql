begin;

-- U5 owns brokerage state, callback artifacts, projections and the Webull
-- command/reconciliation safety boundary. Webull remains the financial
-- authority; every network call stays outside these transactions.
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_roles where rolname='argus_brokerage_owner'
  ) then
    create role argus_brokerage_owner
      nologin noinherit nosuperuser nocreatedb nocreaterole
      noreplication nobypassrls;
  end if;
end
$$;

grant usage on schema argus_app,argus_brokerage,argus_private,extensions
  to argus_brokerage_owner;

-- Author the lifecycle FKs without transferring or broadening the U3 identity
-- owner's authority. Both lifecycle identity proofs are retained at the root.
do $membership$
begin
  execute pg_catalog.format(
    'grant argus_identity_owner to %I with set true',current_user
  );
end
$membership$;
set local role argus_identity_owner;
grant select on table argus_app.member_lifecycles to argus_brokerage_owner;
create policy u5_brokerage_owner_open_lifecycle
  on argus_app.member_lifecycles
  for select to argus_brokerage_owner
  using (state='open');
do $$
begin
  execute pg_catalog.format(
    'grant references on table argus_app.member_lifecycles to %I',
    session_user
  );
end
$$;
reset role;

-- Row-lock authority stays with the identity capability owner.  Brokerage
-- routines can serialize with lifecycle closure without receiving UPDATE on
-- the lifecycle relation itself.  U3 request-context installation can reuse
-- this exact helper when its lock is strengthened to FOR SHARE.
create or replace function argus_private.lock_open_member_lifecycle(
  p_tenant_id uuid,p_lifecycle_id uuid,p_identity_subject_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
begin
  perform 1
    from argus_app.member_lifecycles lifecycle
   where lifecycle.tenant_id=p_tenant_id
     and lifecycle.id=p_lifecycle_id
     and lifecycle.identity_subject_id=p_identity_subject_id
     and lifecycle.state='open'
   for share;
  return found;
end
$$;
grant create on schema argus_private to argus_identity_owner;
alter function argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)
  owner to argus_identity_owner;
revoke create on schema argus_private from argus_identity_owner;
revoke all on function
  argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker;
grant execute on function
  argus_private.lock_open_member_lifecycle(uuid,uuid,uuid)
to argus_brokerage_owner;

-- Expand every U5-owned member artifact with the immutable tenant+lifecycle
-- key. deletion_epoch remains a derived compatibility column until U10.
do $$
declare relation_name text;
declare schema_name text;
begin
  foreach relation_name in array array[
    'argus_brokerage.connections',
    'argus_brokerage.accounts',
    'argus_brokerage.active_account_selections',
    'argus_brokerage.projection_generations',
    'argus_brokerage.order_projection_generations',
    'argus_private.oauth_states',
    'argus_private.webull_completion_handles',
    'argus_private.webull_credentials',
    'argus_private.webull_account_mappings',
    'argus_private.refresh_leases',
    'argus_private.projection_refresh_leases',
    'argus_private.webull_asset_mappings',
    'argus_private.order_previews',
    'argus_private.provider_commands',
    'argus_private.provider_command_attempts',
    'argus_private.reconciliation_records',
    'argus_private.webull_order_mappings'
  ] loop
    schema_name:=pg_catalog.split_part(relation_name,'.',1);
    relation_name:=pg_catalog.split_part(relation_name,'.',2);
    execute pg_catalog.format(
      'alter table %I.%I add column tenant_id uuid, add column lifecycle_id uuid',
      schema_name,relation_name
    );
    execute pg_catalog.format(
      'update %I.%I child set tenant_id=member.tenant_id,lifecycle_id=member.lifecycle_id from argus_app.members member where member.user_id=child.user_id',
      schema_name,relation_name
    );
    execute pg_catalog.format(
      'alter table %I.%I alter column tenant_id set not null, alter column lifecycle_id set not null',
      schema_name,relation_name
    );
    execute pg_catalog.format(
      'drop trigger if exists enforce_live_member_epoch on %I.%I',
      schema_name,relation_name
    );
  end loop;
end
$$;

-- Attempts and reconciliation inherit the whole command parent, never merely
-- a user/command pair that could drift from account ownership.
alter table argus_private.provider_command_attempts
  add column connection_id uuid,
  add column account_id uuid;
update argus_private.provider_command_attempts child
   set connection_id=command.connection_id,
       account_id=command.account_id
  from argus_private.provider_commands command
 where command.id=child.command_id;
alter table argus_private.provider_command_attempts
  alter column connection_id set not null,
  alter column account_id set not null;

alter table argus_private.reconciliation_records
  add column connection_id uuid,
  add column account_id uuid;
update argus_private.reconciliation_records child
   set connection_id=command.connection_id,
       account_id=command.account_id
  from argus_private.provider_commands command
 where command.id=child.command_id;
alter table argus_private.reconciliation_records
  alter column connection_id set not null,
  alter column account_id set not null;

create unique index connections_u5_parent_unique on argus_brokerage.connections(
  tenant_id,lifecycle_id,user_id,id
);
create unique index accounts_u5_parent_unique on argus_brokerage.accounts(
  tenant_id,lifecycle_id,user_id,connection_id,id
);
create unique index projection_generations_u5_parent_unique
  on argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  );
create unique index order_projection_generations_u5_parent_unique
  on argus_brokerage.order_projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  );
create unique index provider_commands_u5_parent_unique
  on argus_private.provider_commands(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  );
create unique index webull_order_mappings_u5_parent_unique
  on argus_private.webull_order_mappings(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
  );
create unique index order_previews_u5_parent_unique
  on argus_private.order_previews(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  );

-- Remove the overlapping user/account/connection FK web. Each child receives
-- one parent-qualified relationship below. The outbox-event FK on refresh
-- leases is deliberately retained for U6.
do $$
declare constraint_row record;
begin
  for constraint_row in
    select relation_name,constraint_name from (values
      ('argus_brokerage.connections','connections_user_id_fkey'),
      ('argus_brokerage.accounts','accounts_user_id_connection_id_fkey'),
      ('argus_brokerage.accounts','accounts_user_id_fkey'),
      ('argus_brokerage.active_account_selections','active_account_selections_user_id_account_id_fkey'),
      ('argus_brokerage.active_account_selections','active_account_selections_user_id_connection_id_fkey'),
      ('argus_brokerage.active_account_selections','active_account_selections_user_id_fkey'),
      ('argus_brokerage.projection_generations','projection_generations_user_id_account_id_fkey'),
      ('argus_brokerage.projection_generations','projection_generations_user_id_connection_id_fkey'),
      ('argus_brokerage.projection_generations','projection_generations_user_id_fkey'),
      ('argus_brokerage.order_projection_generations','order_projection_generations_user_id_account_id_connection_fkey'),
      ('argus_brokerage.order_projection_generations','order_projection_generations_user_id_account_id_order_id_fkey'),
      ('argus_brokerage.order_projection_generations','order_projection_generations_user_id_fkey'),
      ('argus_private.oauth_states','oauth_states_owner_connection_fk'),
      ('argus_private.oauth_states','oauth_states_user_id_fkey'),
      ('argus_private.webull_completion_handles','webull_completion_handles_user_id_connection_id_fkey'),
      ('argus_private.webull_completion_handles','webull_completion_handles_user_id_fkey'),
      ('argus_private.webull_credentials','webull_credentials_connection_id_fkey'),
      ('argus_private.webull_credentials','webull_credentials_user_id_connection_id_fkey'),
      ('argus_private.webull_credentials','webull_credentials_user_id_fkey'),
      ('argus_private.webull_account_mappings','webull_account_mappings_account_id_fkey'),
      ('argus_private.webull_account_mappings','webull_account_mappings_connection_id_fkey'),
      ('argus_private.webull_account_mappings','webull_account_mappings_user_id_account_id_fkey'),
      ('argus_private.webull_account_mappings','webull_account_mappings_user_id_connection_id_fkey'),
      ('argus_private.webull_account_mappings','webull_account_mappings_user_id_fkey'),
      ('argus_private.refresh_leases','refresh_leases_connection_id_fkey'),
      ('argus_private.refresh_leases','refresh_leases_user_id_connection_id_fkey'),
      ('argus_private.refresh_leases','refresh_leases_user_id_fkey'),
      ('argus_private.projection_refresh_leases','projection_refresh_leases_account_id_fkey'),
      ('argus_private.projection_refresh_leases','projection_refresh_leases_owner_connection_fk'),
      ('argus_private.projection_refresh_leases','projection_refresh_leases_user_id_account_id_fkey'),
      ('argus_private.projection_refresh_leases','projection_refresh_leases_user_id_fkey'),
      ('argus_private.webull_asset_mappings','webull_asset_mappings_user_id_account_id_connection_id_fkey'),
      ('argus_private.webull_asset_mappings','webull_asset_mappings_user_id_account_id_fkey'),
      ('argus_private.webull_asset_mappings','webull_asset_mappings_user_id_fkey'),
      ('argus_private.order_previews','order_previews_user_id_account_id_fkey'),
      ('argus_private.order_previews','order_previews_user_id_connection_id_fkey'),
      ('argus_private.order_previews','order_previews_user_id_fkey'),
      ('argus_private.provider_commands','provider_commands_preview_id_fkey'),
      ('argus_private.provider_commands','provider_commands_preview_owner_fk'),
      ('argus_private.provider_commands','provider_commands_result_order_owner_fk'),
      ('argus_private.provider_commands','provider_commands_target_order_owner_fk'),
      ('argus_private.provider_commands','provider_commands_user_id_account_id_fkey'),
      ('argus_private.provider_commands','provider_commands_user_id_connection_id_fkey'),
      ('argus_private.provider_commands','provider_commands_user_id_fkey'),
      ('argus_private.provider_command_attempts','provider_command_attempts_user_id_command_id_fkey'),
      ('argus_private.provider_command_attempts','provider_command_attempts_user_id_fkey'),
      ('argus_private.reconciliation_records','reconciliation_records_user_id_command_id_fkey'),
      ('argus_private.reconciliation_records','reconciliation_records_user_id_fkey'),
      ('argus_private.webull_order_mappings','webull_order_mappings_user_id_account_id_connection_id_fkey'),
      ('argus_private.webull_order_mappings','webull_order_mappings_user_id_fkey')
    ) as constraints(relation_name,constraint_name)
  loop
    execute pg_catalog.format(
      'alter table %s drop constraint %I',
      constraint_row.relation_name,constraint_row.constraint_name
    );
  end loop;
end
$$;

alter table argus_brokerage.connections
  add constraint connections_u5_tenant_lifecycle_fk
    foreign key (tenant_id,lifecycle_id)
    references argus_app.member_lifecycles(tenant_id,id) on delete restrict,
  add constraint connections_u5_subject_lifecycle_fk
    foreign key (user_id,lifecycle_id)
    references argus_app.member_lifecycles(identity_subject_id,id) on delete restrict;

alter table argus_brokerage.accounts
  add constraint accounts_u5_connection_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id)
    references argus_brokerage.connections(tenant_id,lifecycle_id,user_id,id)
    on delete cascade;
alter table argus_brokerage.active_account_selections
  add constraint active_account_selections_u5_account_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id)
    references argus_brokerage.accounts(
      tenant_id,lifecycle_id,user_id,connection_id,id
    ) on delete cascade;
alter table argus_brokerage.projection_generations
  add constraint projection_generations_u5_account_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id)
    references argus_brokerage.accounts(
      tenant_id,lifecycle_id,user_id,connection_id,id
    ) on delete cascade;

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'oauth_states','webull_completion_handles','webull_credentials','refresh_leases'
  ] loop
    execute pg_catalog.format(
      'alter table argus_private.%I add constraint %I foreign key (tenant_id,lifecycle_id,user_id,connection_id) references argus_brokerage.connections(tenant_id,lifecycle_id,user_id,id) on delete cascade',
      relation_name,relation_name||'_u5_connection_fk'
    );
  end loop;
  foreach relation_name in array array[
    'webull_account_mappings','projection_refresh_leases',
    'webull_asset_mappings','order_previews','webull_order_mappings'
  ] loop
    execute pg_catalog.format(
      'alter table argus_private.%I add constraint %I foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id) references argus_brokerage.accounts(tenant_id,lifecycle_id,user_id,connection_id,id) on delete cascade',
      relation_name,relation_name||'_u5_account_fk'
    );
  end loop;
end
$$;

alter table argus_private.provider_commands
  add constraint provider_commands_u5_account_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id)
    references argus_brokerage.accounts(
      tenant_id,lifecycle_id,user_id,connection_id,id
    ) on delete restrict,
  add constraint provider_commands_u5_preview_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id,preview_id)
    references argus_private.order_previews(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,id
    ),
  add constraint provider_commands_u5_target_order_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id,target_order_id)
    references argus_private.webull_order_mappings(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
    ),
  add constraint provider_commands_u5_result_order_fk
    foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id)
    references argus_private.webull_order_mappings(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
    );
alter table argus_private.provider_command_attempts
  add constraint provider_command_attempts_u5_command_fk
    foreign key (
      tenant_id,lifecycle_id,user_id,connection_id,account_id,command_id
    ) references argus_private.provider_commands(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,id
    ) on delete cascade;
alter table argus_private.reconciliation_records
  add constraint reconciliation_records_u5_command_fk
    foreign key (
      tenant_id,lifecycle_id,user_id,connection_id,account_id,command_id
    ) references argus_private.provider_commands(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,id
    ) on delete cascade;
alter table argus_brokerage.order_projection_generations
  add constraint order_projection_generations_u5_order_fk
    foreign key (
      tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
    ) references argus_private.webull_order_mappings(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
    ) on delete cascade;

-- Every referencing side leads with the same lifecycle/account key used by
-- RLS and recovery queries.
create index connections_u5_lifecycle_idx
  on argus_brokerage.connections(tenant_id,lifecycle_id,user_id,created_at desc,id);
create index connections_u5_subject_lifecycle_idx
  on argus_brokerage.connections(user_id,lifecycle_id);
create index accounts_u5_lifecycle_idx
  on argus_brokerage.accounts(tenant_id,lifecycle_id,user_id,connection_id,id);
create index active_account_selections_u5_account_idx
  on argus_brokerage.active_account_selections(
    tenant_id,lifecycle_id,user_id,connection_id,account_id
  );
create index projection_generations_u5_latest_idx
  on argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,account_id,resource_type,generation desc
  );
create index order_projection_generations_u5_latest_idx
  on argus_brokerage.order_projection_generations(
    tenant_id,lifecycle_id,user_id,account_id,order_id,generation desc
  );
create index order_projection_generations_u5_order_fk_idx
  on argus_brokerage.order_projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
  );
create index provider_commands_u5_account_state_idx
  on argus_private.provider_commands(
    tenant_id,lifecycle_id,user_id,account_id,state,updated_at,id
  );
create index provider_commands_u5_preview_fk_idx
  on argus_private.provider_commands(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,preview_id
  );
create index provider_commands_u5_target_order_fk_idx
  on argus_private.provider_commands(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,target_order_id
  );
create index provider_commands_u5_result_order_fk_idx
  on argus_private.provider_commands(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,order_id
  );
create index provider_command_attempts_u5_command_idx
  on argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,command_id
  );
create index reconciliation_records_u5_due_idx
  on argus_private.reconciliation_records(
    status,next_attempt_at,tenant_id,lifecycle_id,account_id,command_id
  ) where status in ('pending','running');
create index reconciliation_records_u5_command_fk_idx
  on argus_private.reconciliation_records(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,command_id
  );
create index projection_refresh_leases_u5_account_fk_idx
  on argus_private.projection_refresh_leases(
    tenant_id,lifecycle_id,user_id,connection_id,account_id
  );
create index refresh_leases_u5_event_fk_idx
  on argus_private.refresh_leases(event_id);
create index webull_account_mappings_u5_account_fk_idx
  on argus_private.webull_account_mappings(
    tenant_id,lifecycle_id,user_id,connection_id,account_id
  );

do $$
declare relation_name text;
begin
  foreach relation_name in array array[
    'oauth_states','webull_completion_handles','webull_credentials',
    'webull_account_mappings','refresh_leases','projection_refresh_leases',
    'webull_asset_mappings','order_previews','webull_order_mappings'
  ] loop
    execute pg_catalog.format(
      'create index %I on argus_private.%I(tenant_id,lifecycle_id,user_id,connection_id)',
      relation_name||'_u5_lifecycle_idx',relation_name
    );
  end loop;
end
$$;

-- A single shape-only trigger derives the immutable lifecycle identity. It
-- never dispatches by table name or permits a lifecycle transition.
create or replace function argus_private.bind_brokerage_member_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_tenant_id uuid;
declare retained_lifecycle_id uuid;
declare retained_deletion_epoch bigint;
begin
  if tg_op='UPDATE' then
    if old.tenant_id<>new.tenant_id or old.lifecycle_id<>new.lifecycle_id
       or old.user_id<>new.user_id then
      raise exception 'brokerage_lifecycle_binding_immutable' using errcode='23514';
    end if;
    -- Lifecycle closure must not prevent identity-preserving degradation and
    -- cryptographic cleanup.  A caller that actually changes the legacy epoch
    -- still has to prove the current open lifecycle below.
    if new.deletion_epoch is not distinct from old.deletion_epoch then
      return new;
    end if;
  end if;

  select member.tenant_id,member.lifecycle_id,member.deletion_epoch
    into retained_tenant_id,retained_lifecycle_id,retained_deletion_epoch
    from argus_app.members member
    join argus_app.member_lifecycles lifecycle
      on lifecycle.tenant_id=member.tenant_id
     and lifecycle.id=member.lifecycle_id
     and lifecycle.identity_subject_id=member.user_id
   where member.user_id=new.user_id
     and member.status='active' and lifecycle.state='open';

  if retained_lifecycle_id is null then
    raise exception 'inactive_member_lifecycle' using errcode='28000';
  end if;
  if new.tenant_id is not null and new.tenant_id<>retained_tenant_id
     or new.lifecycle_id is not null and new.lifecycle_id<>retained_lifecycle_id
     or new.deletion_epoch<>retained_deletion_epoch then
    raise exception 'brokerage_lifecycle_mismatch' using errcode='42501';
  end if;
  new.tenant_id:=retained_tenant_id;
  new.lifecycle_id:=retained_lifecycle_id;
  new.deletion_epoch:=retained_deletion_epoch;
  return new;
end
$$;

do $$
declare relation_name text;
declare schema_name text;
begin
  foreach relation_name in array array[
    'argus_brokerage.connections','argus_brokerage.accounts',
    'argus_brokerage.active_account_selections',
    'argus_brokerage.projection_generations',
    'argus_brokerage.order_projection_generations',
    'argus_private.oauth_states','argus_private.webull_completion_handles',
    'argus_private.webull_credentials','argus_private.webull_account_mappings',
    'argus_private.refresh_leases','argus_private.projection_refresh_leases',
    'argus_private.webull_asset_mappings','argus_private.order_previews',
    'argus_private.provider_commands','argus_private.webull_order_mappings'
  ] loop
    schema_name:=pg_catalog.split_part(relation_name,'.',1);
    relation_name:=pg_catalog.split_part(relation_name,'.',2);
    execute pg_catalog.format(
      'create trigger bind_brokerage_member_lifecycle before insert or update on %I.%I for each row execute function argus_private.bind_brokerage_member_lifecycle()',
      schema_name,relation_name
    );
  end loop;
end
$$;

-- Command children inherit their complete parent identity. Callers cannot
-- supply a different account, lifecycle or subject while retaining a valid
-- command id.
create or replace function argus_private.bind_provider_command_child()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare retained_command argus_private.provider_commands%rowtype;
begin
  select command.* into retained_command
    from argus_private.provider_commands command
   where command.id=new.command_id;
  if retained_command.id is null then
    raise exception 'provider_command_parent_missing' using errcode='23503';
  end if;
  if new.tenant_id is not null and new.tenant_id<>retained_command.tenant_id
     or new.lifecycle_id is not null and new.lifecycle_id<>retained_command.lifecycle_id
     or new.user_id<>retained_command.user_id
     or new.connection_id is not null
        and new.connection_id<>retained_command.connection_id
     or new.account_id is not null and new.account_id<>retained_command.account_id
     or new.deletion_epoch<>retained_command.deletion_epoch then
    raise exception 'provider_command_child_mismatch' using errcode='42501';
  end if;
  if tg_op='UPDATE' and new.command_id<>old.command_id then
    raise exception 'provider_command_binding_immutable' using errcode='23514';
  end if;
  new.tenant_id:=retained_command.tenant_id;
  new.lifecycle_id:=retained_command.lifecycle_id;
  new.user_id:=retained_command.user_id;
  new.connection_id:=retained_command.connection_id;
  new.account_id:=retained_command.account_id;
  new.deletion_epoch:=retained_command.deletion_epoch;
  return new;
end
$$;

create trigger bind_provider_command_child
  before insert or update on argus_private.provider_command_attempts
  for each row execute function argus_private.bind_provider_command_child();
create trigger bind_provider_command_child
  before insert or update on argus_private.reconciliation_records
  for each row execute function argus_private.bind_provider_command_child();

create or replace function argus_private.guard_brokerage_connection_transition()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
begin
  if current_user='argus_member' then
    if (tg_op='INSERT' and new.status<>'pending')
       or (tg_op='UPDATE' and old.status is distinct from new.status
           and new.status not in (
             'pending','temporarily_unavailable','reauthorization_required'
           )) then
      raise exception 'brokerage_connection_transition_forbidden'
        using errcode='42501';
    end if;
  elsif current_user='argus_callback'
        and tg_op='UPDATE' and old.status is distinct from new.status
        and (old.status<>'pending'
             or new.status not in (
               'connected','denied','failed','temporarily_unavailable'
             )) then
    raise exception 'brokerage_connection_transition_forbidden'
      using errcode='42501';
  end if;
  return new;
end
$$;

create trigger guard_brokerage_connection_transition
  before insert or update on argus_brokerage.connections
  for each row execute function argus_private.guard_brokerage_connection_transition();

-- All provider workflows acquire durable identity and ownership guards in one
-- order. A lifecycle close takes the conflicting row lock and therefore
-- cannot pass a worker/callback validation check mid-transaction.
create or replace function argus_private.lock_brokerage_scope(
  p_tenant_id uuid,p_lifecycle_id uuid,p_user_id uuid,p_connection_id uuid,
  p_account_id uuid default null
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if not argus_private.lock_open_member_lifecycle(
    p_tenant_id,p_lifecycle_id,p_user_id
  ) then
    raise exception 'inactive_member_lifecycle' using errcode='28000';
  end if;
  perform 1
    from argus_brokerage.connections connection
   where connection.tenant_id=p_tenant_id
     and connection.lifecycle_id=p_lifecycle_id
     and connection.user_id=p_user_id and connection.id=p_connection_id
   for update;
  if not found then
    raise exception 'connection_not_found' using errcode='P0002';
  end if;
  if p_account_id is not null then
    perform 1
      from argus_brokerage.accounts account
     where account.tenant_id=p_tenant_id
       and account.lifecycle_id=p_lifecycle_id
       and account.user_id=p_user_id
       and account.connection_id=p_connection_id and account.id=p_account_id
     for update;
    if not found then
      raise exception 'account_not_found' using errcode='P0002';
    end if;
  end if;
end
$$;

-- Retained U15 completion entrypoints execute in separate worker
-- transactions from their claim. Wrap those implementations so every phase
-- obtains the same parent locks before an implementation can lock a lease,
-- credential, command or reconciliation row. The renamed functions are
-- implementation details and are executable only by this capability owner.
create or replace function argus_private.lock_brokerage_connection_scope(
  p_connection_id uuid,p_account_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare connection_record argus_brokerage.connections%rowtype;
begin
  select connection.* into connection_record
    from argus_brokerage.connections connection
   where connection.id=p_connection_id;
  if connection_record.id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    connection_record.tenant_id,connection_record.lifecycle_id,
    connection_record.user_id,connection_record.id,p_account_id
  );
  return true;
end
$$;

create or replace function argus_private.lock_brokerage_command_scope(
  p_command_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare command_record argus_private.provider_commands%rowtype;
begin
  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id;
  if command_record.id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.connection_id,
    command_record.account_id
  );
  return true;
end
$$;

alter function argus_private.mark_webull_refresh_egress_started(
  uuid,uuid,bigint,integer,uuid
) rename to mark_webull_refresh_egress_started_after_scope_lock;
alter function argus_private.reset_webull_refresh_before_egress(
  uuid,uuid,bigint,integer,text,uuid
) rename to reset_webull_refresh_before_egress_after_scope_lock;
alter function argus_private.release_webull_token_refresh(uuid,uuid)
  rename to release_webull_token_refresh_after_scope_lock;
alter function argus_private.fence_webull_refresh_outcome(
  uuid,uuid,bigint,integer,text,text
) rename to fence_webull_refresh_outcome_after_scope_lock;
alter function argus_private.commit_webull_token_refresh(
  uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
  bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
) rename to commit_webull_token_refresh_after_scope_lock;
alter function argus_private.mark_webull_reauthorization(
  uuid,uuid,bigint,integer,text
) rename to mark_webull_reauthorization_after_scope_lock;
alter function argus_private.authorize_webull_reconciliation_egress(
  uuid,uuid,bigint,integer,text
) rename to authorize_webull_reconciliation_egress_after_scope_lock;
alter function argus_private.record_webull_reconciliation_retry(
  uuid,uuid,bigint,integer,text,text
) rename to record_webull_reconciliation_retry_after_scope_lock;
alter function argus_private.mark_webull_reconciliation_reauthorization(
  uuid,uuid,bigint,integer,text,text
) rename to mark_webull_reconciliation_reauthorization_after_scope_lock;
alter function argus_private.commit_webull_reconciliation(
  uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
  timestamptz,bytea,text,integer,uuid
) rename to commit_webull_reconciliation_after_scope_lock;

create or replace function argus_private.mark_webull_refresh_egress_started(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_lease_token uuid
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_connection_scope(p_connection_id) then
    return false;
  end if;
  return argus_private.mark_webull_refresh_egress_started_after_scope_lock(
    p_event_id,p_connection_id,p_token_version,p_key_version,p_lease_token
  );
end
$$;

create or replace function argus_private.reset_webull_refresh_before_egress(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_lease_token uuid
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_connection_scope(p_connection_id) then
    return false;
  end if;
  return argus_private.reset_webull_refresh_before_egress_after_scope_lock(
    p_event_id,p_connection_id,p_token_version,p_key_version,p_aad_hash,
    p_lease_token
  );
end
$$;

create or replace function argus_private.release_webull_token_refresh(
  p_connection_id uuid,p_lease_token uuid
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_connection_scope(p_connection_id) then
    return false;
  end if;
  return argus_private.release_webull_token_refresh_after_scope_lock(
    p_connection_id,p_lease_token
  );
end
$$;

create or replace function argus_private.fence_webull_refresh_outcome(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_reason text
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_connection_scope(p_connection_id) then
    return false;
  end if;
  return argus_private.fence_webull_refresh_outcome_after_scope_lock(
    p_event_id,p_connection_id,p_token_version,p_key_version,p_aad_hash,p_reason
  );
end
$$;

create or replace function argus_private.commit_webull_token_refresh(
  p_event_id uuid,p_connection_id uuid,p_expected_token_version bigint,
  p_expected_key_version integer,p_expected_aad_hash text,p_lease_token uuid,
  p_next_token_version bigint,p_next_key_version integer,
  p_access_ciphertext bytea,p_access_nonce bytea,p_access_tag bytea,
  p_refresh_ciphertext bytea,p_refresh_nonce bytea,p_refresh_tag bytea,
  p_wrapped_data_key bytea,p_wrapped_key_nonce bytea,p_wrapped_key_tag bytea,
  p_next_aad_hash text,p_access_expires_at timestamptz,
  p_refresh_expires_at timestamptz
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_connection_scope(p_connection_id) then
    return false;
  end if;
  return argus_private.commit_webull_token_refresh_after_scope_lock(
    p_event_id,p_connection_id,p_expected_token_version,
    p_expected_key_version,p_expected_aad_hash,p_lease_token,
    p_next_token_version,p_next_key_version,p_access_ciphertext,p_access_nonce,
    p_access_tag,p_refresh_ciphertext,p_refresh_nonce,p_refresh_tag,
    p_wrapped_data_key,p_wrapped_key_nonce,p_wrapped_key_tag,p_next_aad_hash,
    p_access_expires_at,p_refresh_expires_at
  );
end
$$;

create or replace function argus_private.mark_webull_reauthorization(
  p_event_id uuid,p_connection_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_connection_scope(p_connection_id) then
    return false;
  end if;
  return argus_private.mark_webull_reauthorization_after_scope_lock(
    p_event_id,p_connection_id,p_token_version,p_key_version,p_aad_hash
  );
end
$$;

create or replace function argus_private.authorize_webull_reconciliation_egress(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_command_scope(p_command_id) then
    return false;
  end if;
  return argus_private.authorize_webull_reconciliation_egress_after_scope_lock(
    p_event_id,p_command_id,p_token_version,p_key_version,p_aad_hash
  );
end
$$;

create or replace function argus_private.record_webull_reconciliation_retry(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_reason text
)
returns text language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_command_scope(p_command_id) then
    return 'manual_review';
  end if;
  return argus_private.record_webull_reconciliation_retry_after_scope_lock(
    p_event_id,p_command_id,p_token_version,p_key_version,p_aad_hash,p_reason
  );
end
$$;

create or replace function argus_private.mark_webull_reconciliation_reauthorization(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_reason text
)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
  if not argus_private.lock_brokerage_command_scope(p_command_id) then
    return false;
  end if;
  return argus_private.mark_webull_reconciliation_reauthorization_after_scope_lock(
    p_event_id,p_command_id,p_token_version,p_key_version,p_aad_hash,p_reason
  );
end
$$;

create or replace function argus_private.commit_webull_reconciliation(
  p_event_id uuid,p_command_id uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_resolution text,p_order_id uuid,
  p_state text,p_filled_quantity numeric,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_reference_ciphertext bytea,p_reference_hash text,
  p_reference_key_version integer,p_instrument_id uuid
)
returns boolean language plpgsql security definer set search_path=''
as $$
declare command_record argus_private.provider_commands%rowtype;
declare next_attempt_number integer;
declare retained_provider_environment text;
begin
  if not argus_private.lock_brokerage_command_scope(p_command_id) then
    return false;
  end if;
  if p_payload::text ~*
       '"((access|refresh)_?token|secret|raw_payload|reviewed_payload|normalized_payload)"[[:space:]]*:'
     or pg_catalog.octet_length(p_reference_ciphertext) not between 32 and 4096
     or p_reference_hash !~ '^[a-f0-9]{64}$'
     or p_reference_key_version<1 then
    raise exception 'invalid_event_payload';
  end if;
  select command.* into command_record
    from argus_private.provider_commands command
    join argus_private.outbox_events event
      on event.id=p_event_id and event.topic='brokerage_reconcile'
     and event.event_type='webull.command.reconciliation.requested'
     and event.aggregate_id=command.id and event.user_id=command.user_id
     and event.deletion_epoch=command.deletion_epoch
    join argus_private.webull_credentials credential
      on credential.tenant_id=command.tenant_id
     and credential.lifecycle_id=command.lifecycle_id
     and credential.connection_id=command.connection_id
     and credential.user_id=command.user_id
     and credential.token_version=p_token_version
     and credential.key_version=p_key_version
     and credential.associated_data_hash=p_aad_hash
   where command.id=p_command_id and command.state='reconciling'
     and not exists (
       select 1 from argus_private.kill_switches switch_row
        where switch_row.name='provider_egress' and switch_row.enabled
     )
   for update of command;
  if command_record.id is null then return false; end if;
  select credential.provider_environment into retained_provider_environment
    from argus_private.webull_credentials credential
   where credential.tenant_id=command_record.tenant_id
     and credential.lifecycle_id=command_record.lifecycle_id
     and credential.connection_id=command_record.connection_id
     and credential.user_id=command_record.user_id
     and credential.token_version=p_token_version
     and credential.key_version=p_key_version
     and credential.associated_data_hash=p_aad_hash;
  if p_resolution not in (
       'applied','authoritative_not_applied','superseded_by_fill'
     )
     or (command_record.operation='place' and p_resolution<>'applied')
     or (command_record.operation in ('modify','cancel')
         and command_record.target_order_id<>p_order_id)
     or (p_resolution='superseded_by_fill'
         and (command_record.operation not in ('modify','cancel')
              or p_state<>'filled'))
     or (command_record.operation='cancel' and p_resolution='applied'
         and p_state<>'cancelled')
     or (command_record.target_order_id is not null
         and command_record.target_order_id<>p_order_id)
     or not exists (
       select 1 from argus_private.webull_asset_mappings asset
        where asset.tenant_id=command_record.tenant_id
          and asset.lifecycle_id=command_record.lifecycle_id
          and asset.user_id=command_record.user_id
          and asset.connection_id=command_record.connection_id
          and asset.account_id=command_record.account_id
          and asset.instrument_id=p_instrument_id
          and asset.asset_kind in ('equity','etf')
     ) then
    raise exception 'invalid_reconciliation_detail';
  end if;
  insert into argus_private.webull_order_mappings(
    tenant_id,lifecycle_id,order_id,account_id,connection_id,user_id,
    deletion_epoch,provider_environment,provider_order_ref_ciphertext,
    provider_order_ref_hash,key_version
  ) values (
    command_record.tenant_id,command_record.lifecycle_id,p_order_id,
    command_record.account_id,command_record.connection_id,
    command_record.user_id,command_record.deletion_epoch,
    retained_provider_environment,p_reference_ciphertext,p_reference_hash,
    p_reference_key_version
  ) on conflict (order_id) do nothing;
  if not exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.tenant_id=command_record.tenant_id
       and mapping.lifecycle_id=command_record.lifecycle_id
       and mapping.order_id=p_order_id
       and mapping.user_id=command_record.user_id
       and mapping.account_id=command_record.account_id
       and mapping.provider_order_ref_hash=p_reference_hash
  ) then raise exception 'provider_order_mapping_conflict'; end if;
  perform argus_private.append_order_projection_scoped(
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.deletion_epoch,
    command_record.connection_id,command_record.account_id,p_order_id,
    p_state,p_filled_quantity,'detail',p_payload,p_provider_observed_at,
    p_fetched_at,null
  );
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=command_record.id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome,provider_error_code
  ) values (
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.deletion_epoch,
    command_record.connection_id,command_record.account_id,command_record.id,
    next_attempt_number,'detail_lookup',
    case when p_resolution='applied' then 'accepted'
         else 'terminal_failure' end,p_resolution
  );
  update argus_private.provider_commands command
     set state='resolved',provider_order_ref_hash=p_reference_hash,
         order_id=p_order_id,updated_at=pg_catalog.clock_timestamp()
   where command.id=command_record.id;
  update argus_private.reconciliation_records record
     set status='resolved',
         last_error_code=case when p_resolution='applied' then null
                              else p_resolution end,
         updated_at=pg_catalog.clock_timestamp()
   where record.command_id=command_record.id;
  return true;
end
$$;

drop function argus_private.commit_webull_reconciliation_after_scope_lock(
  uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
  timestamptz,bytea,text,integer,uuid
);

-- Addressable provider facts are typed. JSON remains only as a bounded,
-- immutable, versioned snapshot envelope for audit/compatibility.
create table argus_brokerage.account_capabilities (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  capability_code text not null
    check (capability_code ~ '^[a-z][a-z0-9_.:-]{0,127}$'),
  provider_code text not null
    check (provider_code ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'),
  available boolean not null,
  capability_version integer not null check (capability_version >= 0),
  primary key (tenant_id,lifecycle_id,account_id,capability_code),
  unique (tenant_id,lifecycle_id,account_id,provider_code),
  foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id)
    references argus_brokerage.accounts(
      tenant_id,lifecycle_id,user_id,connection_id,id
    ) on delete cascade
);
create index account_capabilities_u5_account_fk_idx
  on argus_brokerage.account_capabilities(
    tenant_id,lifecycle_id,user_id,connection_id,account_id
  );
create index account_capabilities_u5_available_idx
  on argus_brokerage.account_capabilities(
    tenant_id,lifecycle_id,account_id,capability_code
  ) where available;

alter table argus_brokerage.accounts
  add column capability_normalization_state text not null default 'quarantined'
    check (capability_normalization_state in ('ready','quarantined'));

alter table argus_brokerage.projection_generations
  add column normalization_state text not null default 'quarantined'
    check (normalization_state in ('ready','quarantined'));
alter table argus_brokerage.projection_generations
  alter column normalization_state drop default;

-- Opaque provider evidence is physically private and one-to-one with the
-- typed generation header. The legacy normalized_payload column remains a
-- grant-free compatibility source only; no read or authorization uses it.
create table argus_private.projection_generation_snapshots (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  generation_id uuid not null,
  snapshot_schema_version integer not null check (snapshot_schema_version=1),
  snapshot_payload jsonb not null,
  snapshot_hash text not null check (
    snapshot_hash ~ '^[a-f0-9]{64}$'
    and snapshot_hash=pg_catalog.encode(
      extensions.digest(
        pg_catalog.convert_to(snapshot_payload::text,'UTF8'),'sha256'
      ),'hex'
    )
  ),
  snapshot_bytes integer not null check (
    snapshot_bytes=pg_catalog.octet_length(
      pg_catalog.convert_to(snapshot_payload::text,'UTF8')
    ) and snapshot_bytes between 2 and 262144
  ),
  primary key (tenant_id,lifecycle_id,generation_id),
  foreign key (
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  ) references argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  ) on delete cascade
);
create index projection_generation_snapshots_u5_parent_idx
  on argus_private.projection_generation_snapshots(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  );

insert into argus_private.projection_generation_snapshots(
  tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
  snapshot_schema_version,snapshot_payload,snapshot_hash,snapshot_bytes
)
select generation.tenant_id,generation.lifecycle_id,generation.user_id,
       generation.connection_id,generation.account_id,generation.id,1,
       bounded.payload,
       pg_catalog.encode(extensions.digest(
         pg_catalog.convert_to(bounded.payload::text,'UTF8'),'sha256'
       ),'hex'),
       pg_catalog.octet_length(pg_catalog.convert_to(bounded.payload::text,'UTF8'))
  from argus_brokerage.projection_generations generation
 cross join lateral (
   select case
     when pg_catalog.octet_length(
       pg_catalog.convert_to(generation.normalized_payload::text,'UTF8')
     )<=262144 then generation.normalized_payload
     else pg_catalog.jsonb_build_object(
       'reason','legacy_snapshot_too_large',
       'source_hash',pg_catalog.encode(extensions.digest(
         pg_catalog.convert_to(generation.normalized_payload::text,'UTF8'),
         'sha256'
       ),'hex')
     )
   end payload
 ) bounded;

create table argus_brokerage.projection_balance_facts (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  generation_id uuid not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  cash numeric(38,18) not null,
  buying_power numeric(38,18),
  market_value numeric(38,18),
  total_equity numeric(38,18) not null,
  primary key (tenant_id,lifecycle_id,generation_id),
  foreign key (
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  ) references argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  ) on delete cascade
);
create index projection_balance_facts_u5_parent_idx
  on argus_brokerage.projection_balance_facts(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  );

-- Parent-qualified asset identity is required before the position fact FK is
-- declared. The old primary key remains a compatibility key.
create unique index webull_asset_mappings_u5_parent_unique
  on argus_private.webull_asset_mappings(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,instrument_id
  );

create table argus_brokerage.projection_position_facts (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  generation_id uuid not null,
  ordinal integer not null check (ordinal between 0 and 9999),
  instrument_id uuid not null,
  symbol text not null check (symbol ~ '^[A-Z0-9][A-Z0-9.-]{0,31}$'),
  display_name text not null check (pg_catalog.char_length(display_name) between 1 and 160),
  asset_kind text not null check (asset_kind in ('equity','etf','unsupported')),
  provider_asset_kind text not null
    check (provider_asset_kind ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'),
  supported boolean not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  exchange text check (exchange is null or pg_catalog.char_length(exchange)<=32),
  market_timezone text not null check (pg_catalog.char_length(market_timezone)<=64),
  quantity numeric(38,18) not null,
  available_quantity numeric(38,18) not null,
  average_cost numeric(38,18),
  market_value numeric(38,18),
  primary key (tenant_id,lifecycle_id,generation_id,ordinal),
  unique (tenant_id,lifecycle_id,generation_id,instrument_id),
  foreign key (
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  ) references argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  ) on delete cascade,
  foreign key (tenant_id,lifecycle_id,user_id,connection_id,account_id,instrument_id)
    references argus_private.webull_asset_mappings(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,instrument_id
    )
);
create index projection_position_facts_u5_parent_idx
  on argus_brokerage.projection_position_facts(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  );
create index projection_position_facts_u5_instrument_fk_idx
  on argus_brokerage.projection_position_facts(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,instrument_id
  );

create table argus_brokerage.projection_restriction_facts (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  generation_id uuid not null,
  ordinal integer not null check (ordinal between 0 and 9999),
  restriction_code text not null
    check (restriction_code in ('closing_only','trading_disabled','liquidation_only','unsupported')),
  provider_code text not null
    check (provider_code ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'),
  active boolean not null,
  detail text check (detail is null or pg_catalog.char_length(detail)<=256),
  primary key (tenant_id,lifecycle_id,generation_id,ordinal),
  unique (tenant_id,lifecycle_id,generation_id,provider_code),
  foreign key (
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  ) references argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  ) on delete cascade
);
create index projection_restriction_facts_u5_parent_idx
  on argus_brokerage.projection_restriction_facts(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  );

create table argus_brokerage.projection_account_facts (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  generation_id uuid not null,
  display_label text not null check (pg_catalog.char_length(display_label) between 1 and 160),
  base_currency text not null check (base_currency ~ '^[A-Z]{3}$'),
  market_timezone text not null check (pg_catalog.char_length(market_timezone)<=64),
  account_status text not null
    check (account_status in ('available','restricted','closed','unavailable')),
  capability_version integer not null check (capability_version>=0),
  primary key (tenant_id,lifecycle_id,generation_id),
  foreign key (
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  ) references argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  ) on delete cascade
);
create index projection_account_facts_u5_parent_idx
  on argus_brokerage.projection_account_facts(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  );

create table argus_private.brokerage_normalization_quarantine (
  id uuid primary key default extensions.gen_random_uuid(),
  source_relation text not null,
  source_identity text not null,
  reason_code text not null check (reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  diagnostic_sqlstate text not null check (diagnostic_sqlstate ~ '^[A-Z0-9]{5}$'),
  source_hash text not null check (source_hash ~ '^[a-f0-9]{64}$'),
  quarantined_at timestamptz not null default pg_catalog.clock_timestamp(),
  unique (source_relation,source_identity,reason_code)
);

-- A legacy account capability document has exactly one deterministic
-- disposition. Unknown, well-formed codes stay typed but fail closed;
-- malformed, duplicate, and oversized documents are quarantined whole.
create or replace function argus_private.brokerage_account_capabilities_reason(
  p_capabilities jsonb
)
returns text
language plpgsql
immutable
set search_path=''
as $$
declare capability_count integer;
declare normalized_count integer;
declare distinct_capability_count integer;
declare distinct_provider_count integer;
begin
  if pg_catalog.jsonb_typeof(p_capabilities)<>'array' then
    return 'capabilities_not_array';
  end if;
  capability_count:=pg_catalog.jsonb_array_length(p_capabilities);
  if capability_count>64 then return 'capabilities_oversized'; end if;
  if exists (
    select 1
      from pg_catalog.jsonb_array_elements(p_capabilities) capability
     where pg_catalog.jsonb_typeof(capability)<>'object'
        or capability->>'capability'
             !~ '^[A-Za-z][A-Za-z0-9._:/-]{0,118}$'
        or capability->>'provider_code'
             !~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'
        or pg_catalog.jsonb_typeof(capability->'available')<>'boolean'
  ) then
    return 'capability_entry_invalid';
  end if;
  select pg_catalog.count(*)::integer,
         pg_catalog.count(distinct normalized.capability_code)::integer,
         pg_catalog.count(distinct normalized.provider_code)::integer
    into normalized_count,distinct_capability_count,distinct_provider_count
    from (
      select case capability->>'capability'
        when 'balances_read' then 'balances_read'
        when 'positions_read' then 'positions_read'
        when 'orders_read' then 'orders_read'
        when 'manual_orders' then 'manual_orders'
        else 'provider:'||pg_catalog.lower(pg_catalog.regexp_replace(
          capability->>'capability','[^A-Za-z0-9_.:-]','_','g'
        ))
      end capability_code,
      capability->>'provider_code' provider_code
      from pg_catalog.jsonb_array_elements(p_capabilities) capability
    ) normalized;
  if normalized_count<>distinct_capability_count
     or normalized_count<>distinct_provider_count then
    return 'capability_entry_duplicate';
  end if;
  return null;
end
$$;

insert into argus_brokerage.account_capabilities(
  tenant_id,lifecycle_id,user_id,connection_id,account_id,capability_code,
  provider_code,available,capability_version
)
select account.tenant_id,account.lifecycle_id,account.user_id,
       account.connection_id,account.id,
       case capability->>'capability'
         when 'balances_read' then 'balances_read'
         when 'positions_read' then 'positions_read'
         when 'orders_read' then 'orders_read'
         when 'manual_orders' then 'manual_orders'
         else 'provider:'||pg_catalog.lower(
           pg_catalog.regexp_replace(capability->>'capability','[^A-Za-z0-9_.:-]','_','g')
         )
       end,
       capability->>'provider_code',
       case when capability->>'capability' in (
         'balances_read','positions_read','orders_read','manual_orders'
       ) then (capability->>'available')::boolean else false end,
       account.capability_version
  from argus_brokerage.accounts account
 cross join lateral pg_catalog.jsonb_array_elements(
   case when argus_private.brokerage_account_capabilities_reason(
               account.capabilities
             ) is null
        then account.capabilities else '[]'::jsonb end
 ) capability
 where argus_private.brokerage_account_capabilities_reason(
         account.capabilities
       ) is null;

update argus_brokerage.accounts account
   set capability_normalization_state='ready'
 where argus_private.brokerage_account_capabilities_reason(
         account.capabilities
       ) is null;

insert into argus_private.brokerage_normalization_quarantine(
  source_relation,source_identity,reason_code,diagnostic_sqlstate,source_hash
)
select 'argus_brokerage.accounts.capabilities',account.id::text,
       argus_private.brokerage_account_capabilities_reason(account.capabilities),
       '22023',pg_catalog.encode(extensions.digest(
         pg_catalog.convert_to(account.capabilities::text,'UTF8'),'sha256'
       ),'hex')
  from argus_brokerage.accounts account
 where argus_private.brokerage_account_capabilities_reason(
         account.capabilities
       ) is not null;

create or replace function argus_private.sync_brokerage_account_capabilities()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if argus_private.brokerage_account_capabilities_reason(
       new.capabilities
     ) is not null then
    raise exception 'invalid_account_capabilities' using errcode='22023';
  end if;

  delete from argus_brokerage.account_capabilities capability
   where capability.tenant_id=new.tenant_id
     and capability.lifecycle_id=new.lifecycle_id
     and capability.account_id=new.id;
  insert into argus_brokerage.account_capabilities(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,capability_code,
    provider_code,available,capability_version
  )
  select new.tenant_id,new.lifecycle_id,new.user_id,new.connection_id,new.id,
         case capability->>'capability'
           when 'balances_read' then 'balances_read'
           when 'positions_read' then 'positions_read'
           when 'orders_read' then 'orders_read'
           when 'manual_orders' then 'manual_orders'
           else 'provider:'||pg_catalog.lower(
             pg_catalog.regexp_replace(
               capability->>'capability','[^A-Za-z0-9_.:-]','_','g'
             )
           )
         end,
         capability->>'provider_code',
         case when capability->>'capability' in (
           'balances_read','positions_read','orders_read','manual_orders'
         ) then (capability->>'available')::boolean else false end,
         new.capability_version
    from pg_catalog.jsonb_array_elements(new.capabilities) capability;
  update argus_brokerage.accounts account
     set capability_normalization_state='ready'
   where account.tenant_id=new.tenant_id
     and account.lifecycle_id=new.lifecycle_id
     and account.id=new.id;
  return null;
end
$$;

create trigger sync_brokerage_account_capabilities
  after insert or update of capabilities,capability_version
  on argus_brokerage.accounts
  for each row execute function argus_private.sync_brokerage_account_capabilities();

do $$
begin
  if exists (
    select 1 from argus_brokerage.accounts account
     where (account.capability_normalization_state='ready') is distinct from
       (argus_private.brokerage_account_capabilities_reason(
          account.capabilities
        ) is null)
  ) or exists (
    select 1 from argus_brokerage.accounts account
     where account.capability_normalization_state='ready'
       and (select pg_catalog.count(*)
              from argus_brokerage.account_capabilities capability
             where capability.tenant_id=account.tenant_id
               and capability.lifecycle_id=account.lifecycle_id
               and capability.account_id=account.id)
           <>pg_catalog.jsonb_array_length(account.capabilities)
  ) or exists (
    select 1 from argus_brokerage.accounts account
     where account.capability_normalization_state='quarantined'
       and (
         exists (
           select 1 from argus_brokerage.account_capabilities capability
            where capability.tenant_id=account.tenant_id
              and capability.lifecycle_id=account.lifecycle_id
              and capability.account_id=account.id
         )
         or not exists (
           select 1
             from argus_private.brokerage_normalization_quarantine quarantine
            where quarantine.source_relation=
                    'argus_brokerage.accounts.capabilities'
              and quarantine.source_identity=account.id::text
         )
       )
  ) then
    raise exception 'account_capability_backfill_parity_failed';
  end if;
end
$$;

create or replace function argus_private.prepare_brokerage_projection_snapshot()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare retained_snapshot_bytes integer;
begin
  if new.resource_type not in (
       'account','balance','positions','restrictions','orders'
     )
     or pg_catalog.jsonb_typeof(new.normalized_payload) not in ('object','array')
     or new.normalized_payload::text ~* '"((access|refresh)_?token|secret|raw_payload|provider_(account|asset|order)_(id|ref))"[[:space:]]*:' then
    raise exception 'invalid_projection_snapshot' using errcode='22023';
  end if;
  retained_snapshot_bytes:=pg_catalog.octet_length(
    pg_catalog.convert_to(new.normalized_payload::text,'UTF8')
  );
  if retained_snapshot_bytes>262144 then
    raise exception 'projection_snapshot_too_large' using errcode='22001';
  end if;
  if new.normalization_state is null then
    new.normalization_state:='ready';
  end if;
  return new;
end
$$;

create or replace function argus_private.materialize_brokerage_projection_payload(
  p_tenant_id uuid,p_lifecycle_id uuid,p_user_id uuid,p_connection_id uuid,
  p_account_id uuid,p_generation_id uuid,p_resource_type text,p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if p_resource_type='balance' then
    if pg_catalog.jsonb_typeof(p_payload)<>'object' then
      raise exception 'invalid_balance_projection' using errcode='22023';
    end if;
    insert into argus_brokerage.projection_balance_facts(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
      currency,cash,buying_power,market_value,total_equity
    ) values (
      p_tenant_id,p_lifecycle_id,p_user_id,p_connection_id,
      p_account_id,p_generation_id,p_payload->>'currency',
      (p_payload->>'cash')::numeric,
      (p_payload->>'buying_power')::numeric,
      (p_payload->>'market_value')::numeric,
      (p_payload->>'total_equity')::numeric
    );
  elsif p_resource_type='positions' then
    if pg_catalog.jsonb_typeof(p_payload)<>'array'
       or pg_catalog.jsonb_array_length(p_payload)>10000 then
      raise exception 'invalid_positions_projection' using errcode='22023';
    end if;
    insert into argus_brokerage.projection_position_facts(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
      ordinal,instrument_id,symbol,display_name,asset_kind,
      provider_asset_kind,supported,currency,exchange,market_timezone,
      quantity,available_quantity,average_cost,market_value
    )
    select p_tenant_id,p_lifecycle_id,p_user_id,p_connection_id,
           p_account_id,p_generation_id,(position.ordinality-1)::integer,
           (position.value->'asset'->>'instrument_id')::uuid,
           position.value->'asset'->>'symbol',
           position.value->'asset'->>'name',
           position.value->'asset'->>'asset_kind',
           position.value->'asset'->>'provider_asset_kind',
           (position.value->'asset'->>'supported')::boolean,
           position.value->>'currency',
           position.value->'asset'->>'exchange',
           position.value->'asset'->>'market_timezone',
           (position.value->>'quantity')::numeric,
           (position.value->>'available_quantity')::numeric,
           (position.value->>'average_cost')::numeric,
           (position.value->>'market_value')::numeric
      from pg_catalog.jsonb_array_elements(p_payload)
        with ordinality as position(value,ordinality);
  elsif p_resource_type='restrictions' then
    if pg_catalog.jsonb_typeof(p_payload)<>'array'
       or pg_catalog.jsonb_array_length(p_payload)>10000 then
      raise exception 'invalid_restrictions_projection' using errcode='22023';
    end if;
    insert into argus_brokerage.projection_restriction_facts(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
      ordinal,restriction_code,provider_code,active,detail
    )
    select p_tenant_id,p_lifecycle_id,p_user_id,p_connection_id,
           p_account_id,p_generation_id,(restriction.ordinality-1)::integer,
           restriction.value->>'restriction',
           restriction.value->>'provider_code',
           (restriction.value->>'active')::boolean,
           restriction.value->>'detail'
      from pg_catalog.jsonb_array_elements(p_payload)
        with ordinality as restriction(value,ordinality);
  elsif p_resource_type='account' then
    if pg_catalog.jsonb_typeof(p_payload)<>'object' then
      raise exception 'invalid_account_projection' using errcode='22023';
    end if;
    insert into argus_brokerage.projection_account_facts(
      tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
      display_label,base_currency,market_timezone,account_status,capability_version
    ) values (
      p_tenant_id,p_lifecycle_id,p_user_id,p_connection_id,p_account_id,
      p_generation_id,p_payload->>'display_label',
      p_payload->>'base_currency',p_payload->>'market_timezone',
      p_payload->>'status',(p_payload->>'capability_version')::integer
    );
  elsif p_resource_type='orders' then
    if pg_catalog.jsonb_typeof(p_payload)<>'array'
       or pg_catalog.jsonb_array_length(p_payload)>10000 then
      raise exception 'invalid_order_list_projection' using errcode='22023';
    end if;
    -- Order-list facts are materialized by append_order_projection_scoped;
    -- this generation is a typed list watermark only.
    return;
  else
    raise exception 'invalid_projection_resource' using errcode='22023';
  end if;
end
$$;

create or replace function argus_private.materialize_brokerage_projection_facts()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  insert into argus_private.projection_generation_snapshots(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
    snapshot_schema_version,snapshot_payload,snapshot_hash,snapshot_bytes
  ) values (
    new.tenant_id,new.lifecycle_id,new.user_id,new.connection_id,new.account_id,
    new.id,1,new.normalized_payload,
    pg_catalog.encode(extensions.digest(
      pg_catalog.convert_to(new.normalized_payload::text,'UTF8'),'sha256'
    ),'hex'),
    pg_catalog.octet_length(
      pg_catalog.convert_to(new.normalized_payload::text,'UTF8')
    )
  );
  if new.normalization_state='ready' then
    perform argus_private.materialize_brokerage_projection_payload(
      new.tenant_id,new.lifecycle_id,new.user_id,new.connection_id,new.account_id,
      new.id,new.resource_type,new.normalized_payload
    );
  end if;
  return null;
end
$$;

create trigger prepare_brokerage_projection_snapshot
  before insert on argus_brokerage.projection_generations
  for each row execute function argus_private.prepare_brokerage_projection_snapshot();
create trigger materialize_brokerage_projection_facts
  after insert on argus_brokerage.projection_generations
  for each row execute function argus_private.materialize_brokerage_projection_facts();

-- Existing valid generations are rematerialized through the same parser.
-- Bad historical shapes are retained only as private quarantined snapshots.
alter table argus_brokerage.projection_generations
  disable trigger projection_generations_immutable;
alter table argus_brokerage.projection_generations
  disable trigger bind_brokerage_member_lifecycle;
do $$
declare generation_row argus_brokerage.projection_generations%rowtype;
declare retained_sqlstate text;
begin
  for generation_row in
    select * from argus_brokerage.projection_generations order by id
  loop
    begin
      if pg_catalog.octet_length(pg_catalog.convert_to(
           generation_row.normalized_payload::text,'UTF8'
         ))>262144 then
        raise exception 'legacy_projection_snapshot_too_large'
          using errcode='22001';
      end if;
      perform argus_private.materialize_brokerage_projection_payload(
        generation_row.tenant_id,generation_row.lifecycle_id,
        generation_row.user_id,generation_row.connection_id,
        generation_row.account_id,generation_row.id,
        generation_row.resource_type,generation_row.normalized_payload
      );
      update argus_brokerage.projection_generations generation
         set normalization_state='ready'
       where generation.id=generation_row.id;
    exception when data_exception or integrity_constraint_violation then
      get stacked diagnostics retained_sqlstate=returned_sqlstate;
      insert into argus_private.brokerage_normalization_quarantine(
        source_relation,source_identity,reason_code,diagnostic_sqlstate,source_hash
      ) values (
        'argus_brokerage.projection_generations',generation_row.id::text,
        case when retained_sqlstate='22001'
             then 'projection_snapshot_too_large'
             else 'invalid_projection_snapshot' end,
        retained_sqlstate,
        case when retained_sqlstate='22001' then
          pg_catalog.encode(extensions.digest(pg_catalog.convert_to(
            generation_row.normalized_payload::text,'UTF8'
          ),'sha256'),'hex')
        else (
          select snapshot.snapshot_hash
            from argus_private.projection_generation_snapshots snapshot
           where snapshot.tenant_id=generation_row.tenant_id
             and snapshot.lifecycle_id=generation_row.lifecycle_id
             and snapshot.generation_id=generation_row.id
        ) end
      ) on conflict do nothing;
    when others then
      raise;
    end;
  end loop;
end
$$;
alter table argus_brokerage.projection_generations
  enable trigger projection_generations_immutable;
alter table argus_brokerage.projection_generations
  enable trigger bind_brokerage_member_lifecycle;

do $$
begin
  if exists (
    select 1 from argus_brokerage.projection_generations generation
     where not exists (
       select 1 from argus_private.projection_generation_snapshots snapshot
        where snapshot.tenant_id=generation.tenant_id
          and snapshot.lifecycle_id=generation.lifecycle_id
          and snapshot.generation_id=generation.id
     )
  ) or exists (
    select 1 from argus_brokerage.projection_generations generation
     where generation.normalization_state='ready' and (
       (generation.resource_type='balance' and not exists (
         select 1 from argus_brokerage.projection_balance_facts fact
          where fact.tenant_id=generation.tenant_id
            and fact.lifecycle_id=generation.lifecycle_id
            and fact.generation_id=generation.id
       )) or (generation.resource_type='account' and not exists (
         select 1 from argus_brokerage.projection_account_facts fact
          where fact.tenant_id=generation.tenant_id
            and fact.lifecycle_id=generation.lifecycle_id
            and fact.generation_id=generation.id
       )) or (generation.resource_type='positions' and
         (select pg_catalog.count(*) from argus_brokerage.projection_position_facts fact
           where fact.tenant_id=generation.tenant_id
             and fact.lifecycle_id=generation.lifecycle_id
             and fact.generation_id=generation.id)
         <>pg_catalog.jsonb_array_length(generation.normalized_payload)
       ) or (generation.resource_type='restrictions' and
         (select pg_catalog.count(*) from argus_brokerage.projection_restriction_facts fact
           where fact.tenant_id=generation.tenant_id
             and fact.lifecycle_id=generation.lifecycle_id
             and fact.generation_id=generation.id)
         <>pg_catalog.jsonb_array_length(generation.normalized_payload)
       )
     )
  ) or exists (
    select 1 from argus_brokerage.projection_generations generation
     where generation.normalization_state='quarantined' and (
       exists (select 1 from argus_brokerage.projection_balance_facts fact
                where fact.generation_id=generation.id)
       or exists (select 1 from argus_brokerage.projection_position_facts fact
                   where fact.generation_id=generation.id)
       or exists (select 1 from argus_brokerage.projection_restriction_facts fact
                   where fact.generation_id=generation.id)
       or exists (select 1 from argus_brokerage.projection_account_facts fact
                   where fact.generation_id=generation.id)
       or not exists (
         select 1 from argus_private.brokerage_normalization_quarantine quarantine
          where quarantine.source_relation='argus_brokerage.projection_generations'
            and quarantine.source_identity=generation.id::text
       )
     )
  ) then
    raise exception 'projection_generation_backfill_parity_failed';
  end if;
end
$$;

alter table argus_brokerage.order_projection_generations
  add column normalization_state text not null default 'quarantined',
  add column instrument_id uuid,
  add column symbol text,
  add column side text,
  add column provider_side text,
  add column order_type text,
  add column provider_order_type text,
  add column time_in_force text,
  add column provider_time_in_force text,
  add column quantity numeric(38,18),
  add column limit_price numeric(38,18),
  add column stop_price numeric(38,18),
  add column average_fill_price numeric(38,18),
  add column currency text,
  add column provider_state text,
  add column terminal boolean;
alter table argus_brokerage.order_projection_generations
  alter column normalization_state drop default;

create table argus_private.order_projection_generation_snapshots (
  tenant_id uuid not null,
  lifecycle_id uuid not null,
  user_id uuid not null,
  connection_id uuid not null,
  account_id uuid not null,
  generation_id uuid not null,
  snapshot_schema_version integer not null check (snapshot_schema_version=1),
  snapshot_payload jsonb not null,
  snapshot_hash text not null check (
    snapshot_hash ~ '^[a-f0-9]{64}$'
    and snapshot_hash=pg_catalog.encode(
      extensions.digest(
        pg_catalog.convert_to(snapshot_payload::text,'UTF8'),'sha256'
      ),'hex'
    )
  ),
  snapshot_bytes integer not null check (
    snapshot_bytes=pg_catalog.octet_length(
      pg_catalog.convert_to(snapshot_payload::text,'UTF8')
    ) and snapshot_bytes between 2 and 65536
  ),
  primary key (tenant_id,lifecycle_id,generation_id),
  foreign key (
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  ) references argus_brokerage.order_projection_generations(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,id
  ) on delete cascade
);
create index order_projection_generation_snapshots_u5_parent_idx
  on argus_private.order_projection_generation_snapshots(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id
  );

alter table argus_brokerage.order_projection_generations
  disable trigger order_projection_generations_immutable;
insert into argus_private.order_projection_generation_snapshots(
  tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
  snapshot_schema_version,snapshot_payload,snapshot_hash,snapshot_bytes
)
select generation.tenant_id,generation.lifecycle_id,generation.user_id,
       generation.connection_id,generation.account_id,generation.id,1,
       bounded.payload,
       pg_catalog.encode(extensions.digest(
         pg_catalog.convert_to(bounded.payload::text,'UTF8'),'sha256'
       ),'hex'),
       pg_catalog.octet_length(pg_catalog.convert_to(bounded.payload::text,'UTF8'))
  from argus_brokerage.order_projection_generations generation
 cross join lateral (
   select case
     when pg_catalog.octet_length(
       pg_catalog.convert_to(generation.normalized_payload::text,'UTF8')
     )<=65536 then generation.normalized_payload
     else pg_catalog.jsonb_build_object(
       'reason','legacy_snapshot_too_large',
       'source_hash',pg_catalog.encode(extensions.digest(
         pg_catalog.convert_to(generation.normalized_payload::text,'UTF8'),
         'sha256'
       ),'hex')
     )
   end payload
 ) bounded;

alter table argus_brokerage.order_projection_generations
  disable trigger bind_brokerage_member_lifecycle;
do $$
declare generation_row argus_brokerage.order_projection_generations%rowtype;
declare retained_sqlstate text;
begin
  for generation_row in
    select * from argus_brokerage.order_projection_generations order by id
  loop
    begin
      if pg_catalog.octet_length(pg_catalog.convert_to(
           generation_row.normalized_payload::text,'UTF8'
         ))>65536 then
        raise exception 'legacy_order_snapshot_too_large' using errcode='22001';
      elsif pg_catalog.jsonb_typeof(generation_row.normalized_payload)<>'object'
         or generation_row.normalized_payload::text ~*
           '"((access|refresh)_?token|secret|raw_payload|reviewed_payload|provider_(account|asset|order)_(id|ref))"[[:space:]]*:'
         or coalesce(
           generation_row.normalized_payload->>'symbol'
             !~ '^[A-Z0-9][A-Z0-9.-]{0,31}$',true
         )
         or coalesce(
           generation_row.normalized_payload->>'side'
             not in ('buy','sell','unsupported'),true
         )
         or coalesce(
           generation_row.normalized_payload->>'order_type'
             not in ('market','limit','stop','stop_limit','unsupported'),true
         )
         or coalesce(
           generation_row.normalized_payload->>'time_in_force'
             not in ('day','gtc','unsupported'),true
         )
         or coalesce(
           generation_row.normalized_payload->>'currency' !~ '^[A-Z]{3}$',true
         )
         or coalesce(
           generation_row.normalized_payload->>'provider_side'
             !~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',true
         )
         or coalesce(
           generation_row.normalized_payload->>'provider_order_type'
             !~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',true
         )
         or coalesce(
           generation_row.normalized_payload->>'provider_time_in_force'
             !~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',true
         )
         or coalesce(
           generation_row.normalized_payload->>'provider_state'
             !~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',true
         )
         or coalesce(
           generation_row.normalized_payload->>'terminal'
             not in ('true','false'),true
         )
         or (generation_row.normalized_payload->>'instrument_id')::uuid is null
         or coalesce(
           (generation_row.normalized_payload->>'quantity')::numeric<=0,true
         ) then
        raise exception 'invalid_order_projection_snapshot';
      end if;
      update argus_brokerage.order_projection_generations generation
         set normalization_state='ready',
             instrument_id=(generation_row.normalized_payload->>'instrument_id')::uuid,
             symbol=generation_row.normalized_payload->>'symbol',
             side=generation_row.normalized_payload->>'side',
             provider_side=generation_row.normalized_payload->>'provider_side',
             order_type=generation_row.normalized_payload->>'order_type',
             provider_order_type=generation_row.normalized_payload->>'provider_order_type',
             time_in_force=generation_row.normalized_payload->>'time_in_force',
             provider_time_in_force=generation_row.normalized_payload->>'provider_time_in_force',
             quantity=(generation_row.normalized_payload->>'quantity')::numeric,
             limit_price=(generation_row.normalized_payload->>'limit_price')::numeric,
             stop_price=(generation_row.normalized_payload->>'stop_price')::numeric,
             average_fill_price=(generation_row.normalized_payload->>'average_fill_price')::numeric,
             currency=generation_row.normalized_payload->>'currency',
             provider_state=generation_row.normalized_payload->>'provider_state',
             terminal=(generation_row.normalized_payload->>'terminal')::boolean
       where generation.id=generation_row.id;
    exception when data_exception or integrity_constraint_violation then
      get stacked diagnostics retained_sqlstate=returned_sqlstate;
      insert into argus_private.brokerage_normalization_quarantine(
        source_relation,source_identity,reason_code,diagnostic_sqlstate,source_hash
      ) values (
        'argus_brokerage.order_projection_generations',
        generation_row.id::text,
        case when retained_sqlstate='22001'
             then 'order_projection_snapshot_too_large'
             else 'invalid_order_projection_snapshot' end,
        retained_sqlstate,case when retained_sqlstate='22001' then
          pg_catalog.encode(extensions.digest(pg_catalog.convert_to(
            generation_row.normalized_payload::text,'UTF8'
          ),'sha256'),'hex')
        else (
          select snapshot.snapshot_hash
            from argus_private.order_projection_generation_snapshots snapshot
           where snapshot.tenant_id=generation_row.tenant_id
             and snapshot.lifecycle_id=generation_row.lifecycle_id
             and snapshot.generation_id=generation_row.id
        ) end
      ) on conflict do nothing;
    when others then
      raise;
    end;
  end loop;
end
$$;
alter table argus_brokerage.order_projection_generations
  enable trigger order_projection_generations_immutable;
alter table argus_brokerage.order_projection_generations
  enable trigger bind_brokerage_member_lifecycle;

alter table argus_brokerage.order_projection_generations
  add constraint order_projection_generations_u5_normalized_fact_check
    check (
      normalization_state='quarantined'
      or (
        normalization_state='ready' and instrument_id is not null
        and symbol ~ '^[A-Z0-9][A-Z0-9.-]{0,31}$'
        and side in ('buy','sell','unsupported')
        and order_type in ('market','limit','stop','stop_limit','unsupported')
        and time_in_force in ('day','gtc','unsupported')
        and quantity>0 and currency ~ '^[A-Z]{3}$'
        and provider_side ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'
        and provider_order_type ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'
        and provider_time_in_force ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'
        and provider_state ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$'
        and terminal is not null
      )
    );

create or replace function argus_private.prepare_brokerage_order_projection()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if pg_catalog.jsonb_typeof(new.normalized_payload)<>'object'
     or pg_catalog.octet_length(
       pg_catalog.convert_to(new.normalized_payload::text,'UTF8')
     )>65536
     or new.normalized_payload::text ~* '"((access|refresh)_?token|secret|raw_payload|reviewed_payload|provider_(account|asset|order)_(id|ref))"[[:space:]]*:' then
    raise exception 'invalid_order_projection_snapshot' using errcode='22023';
  end if;
  new.normalization_state:='ready';
  new.instrument_id:=(new.normalized_payload->>'instrument_id')::uuid;
  new.symbol:=new.normalized_payload->>'symbol';
  new.side:=new.normalized_payload->>'side';
  new.provider_side:=new.normalized_payload->>'provider_side';
  new.order_type:=new.normalized_payload->>'order_type';
  new.provider_order_type:=new.normalized_payload->>'provider_order_type';
  new.time_in_force:=new.normalized_payload->>'time_in_force';
  new.provider_time_in_force:=new.normalized_payload->>'provider_time_in_force';
  new.quantity:=(new.normalized_payload->>'quantity')::numeric;
  new.limit_price:=(new.normalized_payload->>'limit_price')::numeric;
  new.stop_price:=(new.normalized_payload->>'stop_price')::numeric;
  new.average_fill_price:=(new.normalized_payload->>'average_fill_price')::numeric;
  new.currency:=new.normalized_payload->>'currency';
  new.provider_state:=new.normalized_payload->>'provider_state';
  new.terminal:=(new.normalized_payload->>'terminal')::boolean;
  return new;
end
$$;
create trigger prepare_brokerage_order_projection
  before insert on argus_brokerage.order_projection_generations
  for each row execute function argus_private.prepare_brokerage_order_projection();

create or replace function argus_private.capture_brokerage_order_projection_snapshot()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  insert into argus_private.order_projection_generation_snapshots(
    tenant_id,lifecycle_id,user_id,connection_id,account_id,generation_id,
    snapshot_schema_version,snapshot_payload,snapshot_hash,snapshot_bytes
  ) values (
    new.tenant_id,new.lifecycle_id,new.user_id,new.connection_id,new.account_id,
    new.id,1,new.normalized_payload,
    pg_catalog.encode(extensions.digest(
      pg_catalog.convert_to(new.normalized_payload::text,'UTF8'),'sha256'
    ),'hex'),
    pg_catalog.octet_length(
      pg_catalog.convert_to(new.normalized_payload::text,'UTF8')
    )
  );
  return null;
end
$$;
create trigger capture_brokerage_order_projection_snapshot
  after insert on argus_brokerage.order_projection_generations
  for each row execute function argus_private.capture_brokerage_order_projection_snapshot();

do $$
begin
  if exists (
    select 1 from argus_brokerage.order_projection_generations generation
     where not exists (
       select 1
         from argus_private.order_projection_generation_snapshots snapshot
        where snapshot.tenant_id=generation.tenant_id
          and snapshot.lifecycle_id=generation.lifecycle_id
          and snapshot.generation_id=generation.id
     )
  ) or exists (
    select 1 from argus_brokerage.order_projection_generations generation
     where generation.normalization_state='ready'
       and (
         generation.instrument_id is null or generation.symbol is null
         or generation.side is null or generation.provider_side is null
         or generation.order_type is null
         or generation.provider_order_type is null
         or generation.time_in_force is null
         or generation.provider_time_in_force is null
         or generation.quantity is null or generation.currency is null
         or generation.provider_state is null or generation.terminal is null
       )
  ) or exists (
    select 1 from argus_brokerage.order_projection_generations generation
     where generation.normalization_state='quarantined'
       and not exists (
         select 1 from argus_private.brokerage_normalization_quarantine quarantine
          where quarantine.source_relation=
                  'argus_brokerage.order_projection_generations'
            and quarantine.source_identity=generation.id::text
       )
  ) then
    raise exception 'order_projection_backfill_parity_failed';
  end if;
end
$$;

-- Financial prepare is one short transaction: validate current typed
-- authority, lock connection then account, and commit an immutable command
-- plus its first attempt. Provider egress occurs only after this returns.
create or replace function argus_private.prepare_provider_order_command(
  p_preview_id uuid,p_command_id uuid,p_user_id uuid,p_deletion_epoch bigint,
  p_connection_id uuid,p_account_id uuid,p_operation text,
  p_target_order_id uuid,p_client_order_id text,p_idempotency_key text,
  p_normalized_payload jsonb,p_payload_hash text,p_policy_version text,
  p_now timestamptz default pg_catalog.now()
)
returns table (
  command_id uuid,user_id uuid,deletion_epoch bigint,connection_id uuid,
  account_id uuid,operation text,target_order_id uuid,client_order_id text,
  normalized_payload jsonb,normalized_payload_hash text,
  provider_preview_ref_ciphertext bytea,provider_preview_ref_hash text,
  provider_preview_key_version integer,state text,is_duplicate boolean,
  egress_started_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $$
declare
  request_user_id uuid;
  request_tenant_id uuid;
  request_lifecycle_id uuid;
  existing argus_private.provider_commands%rowtype;
  preview argus_private.order_previews%rowtype;
  connection_row argus_brokerage.connections%rowtype;
  account_row argus_brokerage.accounts%rowtype;
  restriction argus_brokerage.projection_generations%rowtype;
  target_state text;
  target_asset_kind text;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  if request_user_id is distinct from p_user_id
     or request_tenant_id is null or request_lifecycle_id is null then
    raise exception 'owner_mismatch' using errcode='42501';
  end if;
  if p_now>pg_catalog.now()+interval '30 seconds'
     or p_now<pg_catalog.now()-interval '30 seconds' then
    raise exception 'invalid_command_time';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_idempotency_key,554237)
  );
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,p_user_id,p_connection_id,p_account_id
  );

  select command.* into existing
    from argus_private.provider_commands command
   where command.idempotency_key=p_idempotency_key
   for update;
  if existing.id is not null then
    if existing.tenant_id<>request_tenant_id
       or existing.lifecycle_id<>request_lifecycle_id
       or existing.user_id<>p_user_id
       or existing.connection_id<>p_connection_id
       or existing.account_id<>p_account_id
       or existing.operation<>p_operation
       or existing.target_order_id is distinct from p_target_order_id
       or existing.client_order_id<>p_client_order_id
       or existing.normalized_payload_hash<>p_payload_hash
       or existing.normalized_payload is distinct from p_normalized_payload
       or existing.policy_version<>p_policy_version then
      raise exception 'idempotency_conflict';
    end if;
    return query
      select existing.id,existing.user_id,existing.deletion_epoch,
             existing.connection_id,existing.account_id,existing.operation,
             existing.target_order_id,existing.client_order_id,
             existing.normalized_payload,existing.normalized_payload_hash,
             saved.provider_preview_ref_ciphertext,
             saved.provider_preview_ref_hash,saved.provider_preview_key_version,
             existing.state,true,existing.egress_started_at
        from argus_private.order_previews saved
       where saved.tenant_id=existing.tenant_id
         and saved.lifecycle_id=existing.lifecycle_id
         and saved.user_id=existing.user_id
         and saved.connection_id=existing.connection_id
         and saved.account_id=existing.account_id
         and saved.id=existing.preview_id;
    return;
  end if;

  if exists (
    select 1 from argus_private.kill_switches switch_row
     where switch_row.name in ('provider_egress','order_mutations')
       and switch_row.enabled
  ) then
    raise exception 'provider_contract_unavailable';
  end if;

  select connection.* into connection_row
    from argus_brokerage.connections connection
   where connection.tenant_id=request_tenant_id
     and connection.lifecycle_id=request_lifecycle_id
     and connection.user_id=p_user_id and connection.id=p_connection_id;
  if connection_row.id is null then raise exception 'account_not_found'; end if;

  select account.* into account_row
    from argus_brokerage.accounts account
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=p_user_id
     and account.connection_id=p_connection_id and account.id=p_account_id;
  if account_row.id is null then raise exception 'account_not_found'; end if;
  if account_row.deletion_epoch<>p_deletion_epoch
     or connection_row.deletion_epoch<>p_deletion_epoch
     or connection_row.status<>'connected'
     or connection_row.egress_fenced_at is not null
     or account_row.status<>'available'
     or account_row.expires_at is null or account_row.expires_at<=p_now then
    raise exception 'brokerage_authority_stale';
  end if;
  if not exists (
       select 1 from argus_brokerage.account_capabilities capability
        where capability.tenant_id=request_tenant_id
          and capability.lifecycle_id=request_lifecycle_id
          and capability.account_id=p_account_id
          and capability.capability_code='manual_orders'
          and capability.available
          and capability.capability_version=account_row.capability_version
     ) or not exists (
       select 1 from argus_brokerage.account_capabilities capability
        where capability.tenant_id=request_tenant_id
          and capability.lifecycle_id=request_lifecycle_id
          and capability.account_id=p_account_id
          and capability.capability_code='orders_read'
          and capability.available
          and capability.capability_version=account_row.capability_version
     ) then
    raise exception 'capability_unavailable';
  end if;

  select generation.* into restriction
    from argus_brokerage.projection_generations generation
   where generation.tenant_id=request_tenant_id
     and generation.lifecycle_id=request_lifecycle_id
     and generation.user_id=p_user_id
     and generation.connection_id=p_connection_id
     and generation.account_id=p_account_id
     and generation.resource_type='restrictions'
     and generation.normalization_state='ready'
   order by generation.generation desc limit 1;
  if restriction.id is null or restriction.availability<>'available'
     or restriction.expires_at<=p_now then
    raise exception 'brokerage_authority_stale';
  end if;
  if exists (
    select 1 from argus_brokerage.projection_restriction_facts fact
     where fact.tenant_id=request_tenant_id
       and fact.lifecycle_id=request_lifecycle_id
       and fact.generation_id=restriction.id and fact.active
  ) then
    raise exception 'brokerage_restricted';
  end if;

  select saved.* into preview
    from argus_private.order_previews saved
   where saved.tenant_id=request_tenant_id
     and saved.lifecycle_id=request_lifecycle_id
     and saved.user_id=p_user_id
     and saved.connection_id=p_connection_id
     and saved.account_id=p_account_id and saved.id=p_preview_id
   for update;
  if preview.id is null then raise exception 'preview_mismatch'; end if;
  if preview.consumed_at is not null then raise exception 'preview_replayed'; end if;
  if preview.expires_at<=p_now then raise exception 'preview_expired'; end if;
  if preview.deletion_epoch<>p_deletion_epoch
     or preview.operation<>p_operation
     or preview.target_order_id is distinct from p_target_order_id
     or preview.capability_version<>account_row.capability_version
     or preview.restriction_generation<>restriction.generation
     or preview.policy_version<>p_policy_version
     or preview.reviewed_payload_hash<>p_payload_hash
     or preview.normalized_payload is distinct from p_normalized_payload then
    raise exception 'preview_mismatch';
  end if;

  if p_operation='place' then
    if p_target_order_id is not null or not exists (
      select 1 from argus_private.webull_asset_mappings asset
       where asset.tenant_id=request_tenant_id
         and asset.lifecycle_id=request_lifecycle_id
         and asset.user_id=p_user_id and asset.connection_id=p_connection_id
         and asset.account_id=p_account_id
         and asset.instrument_id=(p_normalized_payload->>'instrument_id')::uuid
         and asset.asset_kind in ('equity','etf')
    ) then
      raise exception 'unsupported_order';
    end if;
  elsif p_operation in ('modify','cancel') then
    if p_target_order_id is null then raise exception 'order_not_found'; end if;
    select projection.state,asset.asset_kind
      into target_state,target_asset_kind
      from argus_private.webull_order_mappings mapping
      join lateral (
        select generation.state,generation.instrument_id
          from argus_brokerage.order_projection_generations generation
         where generation.tenant_id=mapping.tenant_id
           and generation.lifecycle_id=mapping.lifecycle_id
           and generation.user_id=mapping.user_id
           and generation.connection_id=mapping.connection_id
           and generation.account_id=mapping.account_id
           and generation.order_id=mapping.order_id
           and generation.normalization_state='ready'
         order by generation.generation desc limit 1
      ) projection on true
      left join argus_private.webull_asset_mappings asset
        on asset.tenant_id=mapping.tenant_id
       and asset.lifecycle_id=mapping.lifecycle_id
       and asset.user_id=mapping.user_id
       and asset.connection_id=mapping.connection_id
       and asset.account_id=mapping.account_id
       and asset.instrument_id=projection.instrument_id
     where mapping.tenant_id=request_tenant_id
       and mapping.lifecycle_id=request_lifecycle_id
       and mapping.user_id=p_user_id and mapping.connection_id=p_connection_id
       and mapping.account_id=p_account_id and mapping.order_id=p_target_order_id;
    if target_state is null then raise exception 'order_not_found'; end if;
    if target_asset_kind is null or target_asset_kind not in ('equity','etf')
       or target_state not in ('pending','partially_filled') then
      raise exception 'unsupported_order';
    end if;
  else
    raise exception 'unsupported_order';
  end if;

  if exists (
    select 1 from argus_private.provider_commands blocked
     where blocked.tenant_id=request_tenant_id
       and blocked.lifecycle_id=request_lifecycle_id
       and blocked.user_id=p_user_id
       and blocked.account_id=p_account_id
       and blocked.state in ('dispatching','ambiguous','reconciling','manual_review')
  ) then
    raise exception 'account_command_blocked';
  end if;

  begin
    insert into argus_private.provider_commands(
      id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
      operation,client_order_id,idempotency_key,normalized_payload_hash,
      reviewed_payload_hash,capability_version,state,egress_started_at,
      preview_id,restriction_generation,policy_version,normalized_payload,
      target_order_id
    ) values (
      p_command_id,request_tenant_id,request_lifecycle_id,p_user_id,
      p_deletion_epoch,p_connection_id,p_account_id,p_operation,
      p_client_order_id,p_idempotency_key,p_payload_hash,
      preview.reviewed_payload_hash,account_row.capability_version,
      'dispatching',p_now,p_preview_id,restriction.generation,p_policy_version,
      p_normalized_payload,p_target_order_id
    );
  exception when unique_violation then
    raise exception 'idempotency_conflict';
  end;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome
  ) values (
    request_tenant_id,request_lifecycle_id,p_user_id,p_deletion_epoch,
    p_connection_id,p_account_id,p_command_id,1,'egress','started'
  );
  update argus_private.order_previews saved set consumed_at=p_now
   where saved.tenant_id=request_tenant_id
     and saved.lifecycle_id=request_lifecycle_id and saved.id=p_preview_id;

  return query
    select p_command_id,p_user_id,p_deletion_epoch,p_connection_id,p_account_id,
           p_operation,p_target_order_id,p_client_order_id,p_normalized_payload,
           p_payload_hash,preview.provider_preview_ref_ciphertext,
           preview.provider_preview_ref_hash,preview.provider_preview_key_version,
           'dispatching'::text,false,p_now;
end
$$;

create or replace function argus_private.claim_brokerage_reconciliation_attempt(
  p_command_id uuid,p_expected_user_id uuid,p_expected_deletion_epoch bigint,
  p_claimed_at timestamptz
)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare command_row argus_private.provider_commands%rowtype;
declare reconciliation argus_private.reconciliation_records%rowtype;
declare next_attempt_number integer;
begin
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=p_expected_user_id
     and command.deletion_epoch=p_expected_deletion_epoch;
  if command_row.id is null then return 'not_found'; end if;
  perform argus_private.lock_brokerage_scope(
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.connection_id,command_row.account_id
  );
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=p_expected_user_id
     and command.deletion_epoch=p_expected_deletion_epoch
   for update;
  if command_row.id is null then return 'not_found'; end if;
  if command_row.state='manual_review' then return 'manual_review'; end if;
  if command_row.state not in ('dispatching','ambiguous','reconciling') then
    return 'not_found';
  end if;
  if command_row.state='dispatching'
     and command_row.egress_started_at>p_claimed_at-interval '30 seconds' then
    return 'not_due';
  end if;
  if command_row.state='dispatching' then
    update argus_private.provider_commands command
       set state='ambiguous',updated_at=p_claimed_at
     where command.id=p_command_id;
    command_row.state:='ambiguous';
  end if;
  insert into argus_private.reconciliation_records(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,status,next_attempt_at
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_command_id,'pending',p_claimed_at
  ) on conflict on constraint reconciliation_records_command_id_key do nothing;
  select record.* into reconciliation
    from argus_private.reconciliation_records record
   where record.command_id=p_command_id
   for update;
  if reconciliation.attempts>=4
     or reconciliation.status in ('manual_review','exhausted') then
    update argus_private.provider_commands command
       set state='manual_review',updated_at=p_claimed_at
     where command.id=p_command_id
       and command.state in ('ambiguous','reconciling');
    update argus_private.reconciliation_records record
       set status='manual_review',next_attempt_at=p_claimed_at,
           last_error_code='reconciliation_exhausted',updated_at=p_claimed_at
     where record.command_id=p_command_id;
    return 'manual_review';
  end if;
  if reconciliation.next_attempt_at>p_claimed_at then return 'not_due'; end if;
  update argus_private.provider_commands command
     set state='reconciling',updated_at=p_claimed_at
   where command.id=p_command_id and command.state='ambiguous';
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.deletion_epoch,command_row.connection_id,command_row.account_id,
    p_command_id,next_attempt_number,'detail_lookup','started'
  );
  update argus_private.reconciliation_records record
     set status='running',attempts=record.attempts+1,
         next_attempt_at=p_claimed_at,updated_at=p_claimed_at
   where record.command_id=p_command_id;
  return 'claimed';
end
$$;

-- Adding the bounded-claim outcome changes the function's OUT row type, which
-- PostgreSQL cannot replace in place.  Deliberately omit CASCADE so an
-- unexpected dependency aborts the forward migration for review.
drop function argus_private.claim_provider_command_reconciliation(uuid);
create function argus_private.claim_provider_command_reconciliation(
  p_command_id uuid
)
returns table (
  claim_outcome text,command_id uuid,user_id uuid,deletion_epoch bigint,connection_id uuid,
  account_id uuid,operation text,target_order_id uuid,client_order_id text,
  normalized_payload jsonb,normalized_payload_hash text,
  provider_preview_ref_ciphertext bytea,provider_preview_ref_hash text,
  provider_preview_key_version integer,egress_started_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $$
declare command_row argus_private.provider_commands%rowtype;
declare claim_outcome text;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=request_user_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  claim_outcome:=argus_private.claim_brokerage_reconciliation_attempt(
    p_command_id,command_row.user_id,command_row.deletion_epoch,
    pg_catalog.clock_timestamp()
  );
  if claim_outcome='not_due' then
    raise exception 'dependency_unavailable';
  elsif claim_outcome='manual_review' then
    return query
      select 'manual_review'::text,command_row.id,command_row.user_id,
             command_row.deletion_epoch,command_row.connection_id,
             command_row.account_id,command_row.operation,
             command_row.target_order_id,command_row.client_order_id,
             null::jsonb,command_row.normalized_payload_hash,
             null::bytea,null::text,null::integer,
             command_row.egress_started_at;
    return;
  elsif claim_outcome<>'claimed' then
    raise exception 'command_not_found';
  end if;
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id;
  return query
    select 'claimed'::text,command_row.id,command_row.user_id,command_row.deletion_epoch,
           command_row.connection_id,command_row.account_id,
           command_row.operation,command_row.target_order_id,
           command_row.client_order_id,command_row.normalized_payload,
           command_row.normalized_payload_hash,
           preview.provider_preview_ref_ciphertext,
           preview.provider_preview_ref_hash,preview.provider_preview_key_version,
           command_row.egress_started_at
      from argus_private.order_previews preview
     where preview.tenant_id=command_row.tenant_id
       and preview.lifecycle_id=command_row.lifecycle_id
       and preview.user_id=command_row.user_id
       and preview.connection_id=command_row.connection_id
       and preview.account_id=command_row.account_id
       and preview.id=command_row.preview_id;
end
$$;

create or replace function argus_private.record_provider_command_dispatch_outcome(
  p_command_id uuid,p_state text,p_outcome text,p_reason_code text
)
returns table(
  command_id uuid,account_id uuid,operation text,target_order_id uuid,
  order_id uuid,state text,created_at timestamptz,updated_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $$
declare command_record argus_private.provider_commands%rowtype;
declare next_attempt_number integer;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  if p_state not in ('failed','ambiguous')
     or (p_state='failed' and p_outcome<>'terminal_failure')
     or (p_state='ambiguous' and p_outcome<>'ambiguous')
     or p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'invalid_dispatch_outcome' using errcode='22023';
  end if;
  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id
     and command.user_id=request_user_id;
  if command_record.id is null then raise exception 'command_not_found'; end if;
  perform argus_private.lock_brokerage_scope(
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.connection_id,
    command_record.account_id
  );
  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id
     and command.user_id=request_user_id
     and command.state='dispatching'
   for update;
  if command_record.id is null then raise exception 'command_not_found'; end if;
  update argus_private.provider_commands command
     set state=p_state,updated_at=pg_catalog.clock_timestamp()
   where command.id=command_record.id;
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=command_record.id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome,provider_error_code
  ) values (
    command_record.tenant_id,command_record.lifecycle_id,
    command_record.user_id,command_record.deletion_epoch,
    command_record.connection_id,command_record.account_id,command_record.id,
    next_attempt_number,'egress',p_outcome,p_reason_code
  );
  if p_state='ambiguous' then
    insert into argus_private.reconciliation_records(
      tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
      command_id,status,next_attempt_at
    ) values (
      command_record.tenant_id,command_record.lifecycle_id,
      command_record.user_id,command_record.deletion_epoch,
      command_record.connection_id,command_record.account_id,
      command_record.id,'pending',pg_catalog.clock_timestamp()
    ) on conflict on constraint reconciliation_records_command_id_key do update
      set status='pending',next_attempt_at=pg_catalog.clock_timestamp(),
          updated_at=pg_catalog.clock_timestamp();
    insert into argus_private.outbox_events(
      user_id,deletion_epoch,topic,event_type,aggregate_id,dedupe_key
    ) values (
      command_record.user_id,command_record.deletion_epoch,
      'brokerage_reconcile','webull.command.reconciliation.requested',
      command_record.id,'provider-command:'||command_record.id::text
    ) on conflict (topic,dedupe_key) do nothing;
  end if;
  return query
    select command_record.id,command_record.account_id,
           command_record.operation,command_record.target_order_id,
           command_record.order_id,p_state,command_record.created_at,
           pg_catalog.clock_timestamp();
end
$$;

create or replace function argus_private.claim_webull_token_refresh(
  p_event_id uuid,p_lease_token uuid,p_lease_seconds integer
)
returns table (
  claim_outcome text,user_id uuid,deletion_epoch bigint,connection_id uuid,
  provider_environment text,token_version bigint,key_version integer,
  access_ciphertext bytea,access_nonce bytea,access_tag bytea,
  refresh_ciphertext bytea,refresh_nonce bytea,refresh_tag bytea,
  wrapped_data_key bytea,wrapped_key_nonce bytea,wrapped_key_tag bytea,
  associated_data_hash text,access_expires_at timestamptz,
  refresh_expires_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $$
declare event_record argus_private.outbox_events%rowtype;
declare credential argus_private.webull_credentials%rowtype;
declare prior argus_private.refresh_leases%rowtype;
begin
  if p_lease_seconds<15 or p_lease_seconds>55 then
    raise exception 'invalid_lease_duration';
  end if;
  select event.* into event_record
    from argus_private.outbox_events event
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.token.refresh.requested'
     and event.aggregate_id in (
       select connection.id from argus_brokerage.connections connection
        where connection.user_id=event.user_id
          and connection.deletion_epoch=event.deletion_epoch
     )
     and exists (
       select 1 from argus_private.job_runs run
        where run.source_event_id=event.id
          and run.handler_name='webull-token-refresh'
          and run.status='leased'
          and run.leased_until>pg_catalog.clock_timestamp()
     );
  if event_record.id is null
     or not argus_private.assert_worker_event_current(p_event_id) then
    return;
  end if;
  if exists (
    select 1 from argus_private.kill_switches switch_row
     where switch_row.name='provider_egress' and switch_row.enabled
  ) then
    raise exception 'worker_killed';
  end if;
  select current_credential.* into credential
    from argus_private.webull_credentials current_credential
   where current_credential.connection_id=event_record.aggregate_id
     and current_credential.user_id=event_record.user_id
     and current_credential.deletion_epoch=event_record.deletion_epoch
     and exists (
       select 1 from argus_brokerage.connections connection
        where connection.tenant_id=current_credential.tenant_id
          and connection.lifecycle_id=current_credential.lifecycle_id
          and connection.id=current_credential.connection_id
          and connection.user_id=current_credential.user_id
          and connection.deletion_epoch=current_credential.deletion_epoch
          and connection.status='connected'
          and connection.egress_fenced_at is null
     );
  if credential.connection_id is null then return; end if;
  perform argus_private.lock_brokerage_scope(
    credential.tenant_id,credential.lifecycle_id,credential.user_id,
    credential.connection_id,null
  );
  select current_credential.* into credential
    from argus_private.webull_credentials current_credential
    join argus_brokerage.connections connection
      on connection.tenant_id=current_credential.tenant_id
     and connection.lifecycle_id=current_credential.lifecycle_id
     and connection.user_id=current_credential.user_id
     and connection.id=current_credential.connection_id
   where current_credential.tenant_id=credential.tenant_id
     and current_credential.lifecycle_id=credential.lifecycle_id
     and current_credential.connection_id=credential.connection_id
     and current_credential.user_id=credential.user_id
     and current_credential.deletion_epoch=credential.deletion_epoch
     and connection.status='connected' and connection.egress_fenced_at is null
   for update of current_credential;
  if credential.connection_id is null then return; end if;
  select lease.* into prior
    from argus_private.refresh_leases lease
   where lease.tenant_id=credential.tenant_id
     and lease.lifecycle_id=credential.lifecycle_id
     and lease.connection_id=credential.connection_id
   for update;
  if prior.connection_id is not null
     and prior.token_version<>credential.token_version then
    delete from argus_private.refresh_leases lease
     where lease.connection_id=prior.connection_id;
    prior.connection_id:=null;
  end if;
  if prior.connection_id is not null and prior.egress_started_at is not null then
    update argus_brokerage.connections connection
       set status='reauthorization_required',
           last_error_code='refresh_outcome_unknown',
           updated_at=pg_catalog.clock_timestamp()
     where connection.tenant_id=credential.tenant_id
       and connection.lifecycle_id=credential.lifecycle_id
       and connection.id=credential.connection_id
       and connection.user_id=credential.user_id
       and connection.deletion_epoch=credential.deletion_epoch
       and connection.status='connected';
    delete from argus_brokerage.active_account_selections selection
     where selection.tenant_id=credential.tenant_id
       and selection.lifecycle_id=credential.lifecycle_id
       and selection.user_id=credential.user_id
       and selection.connection_id=credential.connection_id;
    delete from argus_private.webull_credentials current_credential
     where current_credential.connection_id=credential.connection_id
       and current_credential.token_version=credential.token_version;
    delete from argus_private.refresh_leases lease
     where lease.connection_id=credential.connection_id;
    return query
      select 'reauthorization_required'::text,credential.user_id,
        credential.deletion_epoch,credential.connection_id,
        credential.provider_environment,credential.token_version,
        credential.key_version,null::bytea,null::bytea,null::bytea,
        null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,
        credential.associated_data_hash,credential.access_expires_at,
        credential.refresh_expires_at;
    return;
  end if;
  if prior.connection_id is not null
     and prior.leased_until>pg_catalog.clock_timestamp() then return; end if;
  delete from argus_private.refresh_leases lease
   where lease.connection_id=credential.connection_id;
  insert into argus_private.refresh_leases(
    tenant_id,lifecycle_id,connection_id,user_id,deletion_epoch,lease_token,
    token_version,leased_until,event_id,key_version,credential_aad_hash,
    egress_started_at
  ) values (
    credential.tenant_id,credential.lifecycle_id,credential.connection_id,
    credential.user_id,credential.deletion_epoch,p_lease_token,
    credential.token_version,
    pg_catalog.clock_timestamp()+pg_catalog.make_interval(secs=>p_lease_seconds),
    p_event_id,credential.key_version,credential.associated_data_hash,null
  );
  return query
    select 'claimed'::text,credential.user_id,credential.deletion_epoch,
      credential.connection_id,credential.provider_environment,
      credential.token_version,credential.key_version,
      credential.access_ciphertext,credential.access_nonce,credential.access_tag,
      credential.refresh_ciphertext,credential.refresh_nonce,
      credential.refresh_tag,credential.wrapped_data_key,
      credential.wrapped_key_nonce,credential.wrapped_key_tag,
      credential.associated_data_hash,credential.access_expires_at,
      credential.refresh_expires_at;
end
$$;

create or replace function argus_private.claim_webull_command_reconciliation(
  p_event_id uuid,p_command_id uuid
)
returns table(
  claim_outcome text,user_id uuid,deletion_epoch bigint,connection_id uuid,
  account_id uuid,command_id uuid,operation text,client_order_id text,
  target_order_id uuid,provider_environment text,token_version bigint,
  key_version integer,access_ciphertext bytea,access_nonce bytea,
  access_tag bytea,refresh_ciphertext bytea,refresh_nonce bytea,
  refresh_tag bytea,wrapped_data_key bytea,wrapped_key_nonce bytea,
  wrapped_key_tag bytea,associated_data_hash text,
  access_expires_at timestamptz,refresh_expires_at timestamptz,
  provider_account_id_ciphertext bytea,provider_account_key_version integer,
  target_order_ref_ciphertext bytea,target_order_ref_key_version integer
)
language plpgsql
security definer
set search_path=''
as $$
declare event_record argus_private.outbox_events%rowtype;
declare command_record argus_private.provider_commands%rowtype;
declare credential argus_private.webull_credentials%rowtype;
declare account_mapping argus_private.webull_account_mappings%rowtype;
declare target_mapping argus_private.webull_order_mappings%rowtype;
declare shared_claim_outcome text;
begin
  select event.* into event_record
    from argus_private.outbox_events event
   where event.id=p_event_id and event.topic='brokerage_reconcile'
     and event.event_type='webull.command.reconciliation.requested'
     and event.aggregate_id=p_command_id
     and exists (
       select 1 from argus_private.job_runs run
        where run.source_event_id=event.id
          and run.handler_name='webull-reconciliation'
          and run.status='leased'
          and run.leased_until>pg_catalog.clock_timestamp()
     );
  if event_record.id is null
     or not argus_private.assert_worker_event_current(p_event_id) then
    return;
  end if;
  if exists (
    select 1 from argus_private.kill_switches switch_row
     where switch_row.name='provider_egress' and switch_row.enabled
  ) then
    raise exception 'worker_killed';
  end if;

  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=event_record.user_id
     and command.deletion_epoch=event_record.deletion_epoch;
  if command_record.id is null then return; end if;
  shared_claim_outcome:=argus_private.claim_brokerage_reconciliation_attempt(
    p_command_id,event_record.user_id,event_record.deletion_epoch,
    pg_catalog.clock_timestamp()
  );
  if shared_claim_outcome='manual_review' then
    select command.* into command_record
      from argus_private.provider_commands command
     where command.id=p_command_id;
    return query
      select 'manual_review'::text,command_record.user_id,
        command_record.deletion_epoch,command_record.connection_id,
        command_record.account_id,command_record.id,command_record.operation,
        command_record.client_order_id,command_record.target_order_id,
        null::text,null::bigint,null::integer,
        null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,
        null::bytea,null::bytea,null::bytea,null::text,
        null::timestamptz,null::timestamptz,null::bytea,null::integer,
        null::bytea,null::integer;
    return;
  end if;
  if shared_claim_outcome<>'claimed' then return; end if;
  select command.* into command_record
    from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=event_record.user_id
     and command.deletion_epoch=event_record.deletion_epoch;

  select current_credential.* into credential
    from argus_private.webull_credentials current_credential
   where current_credential.tenant_id=command_record.tenant_id
     and current_credential.lifecycle_id=command_record.lifecycle_id
     and current_credential.connection_id=command_record.connection_id
     and current_credential.user_id=command_record.user_id
     and current_credential.deletion_epoch=command_record.deletion_epoch;
  select mapping.* into account_mapping
    from argus_private.webull_account_mappings mapping
   where mapping.tenant_id=command_record.tenant_id
     and mapping.lifecycle_id=command_record.lifecycle_id
     and mapping.account_id=command_record.account_id
     and mapping.connection_id=command_record.connection_id
     and mapping.user_id=command_record.user_id
     and mapping.deletion_epoch=command_record.deletion_epoch;
  if command_record.target_order_id is not null then
    select mapping.* into target_mapping
      from argus_private.webull_order_mappings mapping
     where mapping.tenant_id=command_record.tenant_id
       and mapping.lifecycle_id=command_record.lifecycle_id
       and mapping.order_id=command_record.target_order_id
       and mapping.account_id=command_record.account_id
       and mapping.connection_id=command_record.connection_id
       and mapping.user_id=command_record.user_id
       and mapping.deletion_epoch=command_record.deletion_epoch;
  end if;
  if credential.connection_id is null or account_mapping.account_id is null
     or (command_record.target_order_id is not null
         and target_mapping.order_id is null)
     or not exists (
       select 1
         from argus_app.member_lifecycles lifecycle
         join argus_brokerage.connections connection
           on connection.tenant_id=lifecycle.tenant_id
          and connection.lifecycle_id=lifecycle.id
          and connection.user_id=lifecycle.identity_subject_id
         join argus_brokerage.accounts account
           on account.tenant_id=connection.tenant_id
          and account.lifecycle_id=connection.lifecycle_id
          and account.user_id=connection.user_id
          and account.connection_id=connection.id
        where lifecycle.tenant_id=command_record.tenant_id
          and lifecycle.id=command_record.lifecycle_id
          and lifecycle.state='open'
          and connection.id=command_record.connection_id
          and connection.status='connected'
          and connection.egress_fenced_at is null
          and account.id=command_record.account_id
     ) then
    if command_record.state='dispatching' then
      update argus_private.provider_commands command
         set state='ambiguous',updated_at=pg_catalog.clock_timestamp()
       where command.id=command_record.id;
    end if;
    update argus_private.provider_commands command
       set state='manual_review',updated_at=pg_catalog.clock_timestamp()
     where command.id=command_record.id
       and command.state in ('ambiguous','reconciling');
    update argus_private.reconciliation_records record
       set status='manual_review',last_error_code='reconciliation_fenced',
           updated_at=pg_catalog.clock_timestamp()
     where record.command_id=command_record.id;
    return query
      select 'manual_review'::text,command_record.user_id,
        command_record.deletion_epoch,command_record.connection_id,
        command_record.account_id,command_record.id,command_record.operation,
        command_record.client_order_id,command_record.target_order_id,
        null::text,null::bigint,null::integer,
        null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,null::bytea,
        null::bytea,null::bytea,null::bytea,null::text,
        null::timestamptz,null::timestamptz,null::bytea,null::integer,
        null::bytea,null::integer;
    return;
  end if;
  return query
    select 'claimed'::text,credential.user_id,credential.deletion_epoch,
      credential.connection_id,command_record.account_id,command_record.id,
      command_record.operation,command_record.client_order_id,
      command_record.target_order_id,credential.provider_environment,
      credential.token_version,credential.key_version,
      credential.access_ciphertext,credential.access_nonce,credential.access_tag,
      credential.refresh_ciphertext,credential.refresh_nonce,
      credential.refresh_tag,credential.wrapped_data_key,
      credential.wrapped_key_nonce,credential.wrapped_key_tag,
      credential.associated_data_hash,credential.access_expires_at,
      credential.refresh_expires_at,
      account_mapping.provider_account_id_ciphertext,account_mapping.key_version,
      target_mapping.provider_order_ref_ciphertext,target_mapping.key_version;
end
$$;

create or replace function argus_private.terminalize_webull_recovery_dead_letter(
  p_event_id uuid,p_reason text
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare target_command_id uuid;
declare target_command_state text;
declare target_connection_id uuid;
declare target_owner_id uuid;
declare target_tenant_id uuid;
declare target_lifecycle_id uuid;
declare target_account_id uuid;
begin
  select connection.id,event.user_id,connection.tenant_id,connection.lifecycle_id
    into target_connection_id,target_owner_id,target_tenant_id,target_lifecycle_id
    from argus_private.outbox_events event
    join argus_brokerage.connections connection
      on connection.id=event.aggregate_id and connection.user_id=event.user_id
     and connection.deletion_epoch=event.deletion_epoch
    join argus_private.webull_credentials credential
      on credential.tenant_id=connection.tenant_id
     and credential.lifecycle_id=connection.lifecycle_id
     and credential.connection_id=connection.id
     and credential.user_id=connection.user_id
     and credential.deletion_epoch=connection.deletion_epoch
     and event.dedupe_key='webull-token:'||credential.connection_id::text
                          ||':'||credential.token_version::text
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.token.refresh.requested';
  if target_connection_id is not null then
    perform argus_private.lock_brokerage_scope(
      target_tenant_id,target_lifecycle_id,target_owner_id,
      target_connection_id,null
    );
    update argus_brokerage.connections connection
       set status='reauthorization_required',
           last_error_code='token_refresh_exhausted',
           updated_at=pg_catalog.clock_timestamp()
     where connection.id=target_connection_id
       and connection.user_id=target_owner_id
       and connection.status='connected';
    delete from argus_brokerage.active_account_selections selection
     where selection.user_id=target_owner_id
       and selection.connection_id=target_connection_id;
    delete from argus_private.refresh_leases lease
     where lease.connection_id=target_connection_id
       and lease.user_id=target_owner_id;
    delete from argus_private.webull_credentials credential
     where credential.connection_id=target_connection_id
       and credential.user_id=target_owner_id;
    return true;
  end if;
  if exists (
    select 1 from argus_private.outbox_events event
     where event.id=p_event_id and event.topic='brokerage_refresh'
       and event.event_type='webull.projection.refresh.requested'
  ) then
    select lease.connection_id,lease.account_id,lease.user_id,
           lease.tenant_id,lease.lifecycle_id
      into target_connection_id,target_account_id,target_owner_id,
           target_tenant_id,target_lifecycle_id
      from argus_private.outbox_events event
      join argus_private.projection_refresh_leases lease
        on lease.id=event.aggregate_id and lease.user_id=event.user_id
       and lease.deletion_epoch=event.deletion_epoch
     where event.id=p_event_id and event.topic='brokerage_refresh'
       and event.event_type='webull.projection.refresh.requested';
    if target_connection_id is null then return true; end if;
    perform argus_private.lock_brokerage_scope(
      target_tenant_id,target_lifecycle_id,target_owner_id,
      target_connection_id,target_account_id
    );
    delete from argus_private.projection_refresh_leases lease
     using argus_private.outbox_events event
     where event.id=p_event_id and event.aggregate_id=lease.id
       and lease.tenant_id=target_tenant_id
       and lease.lifecycle_id=target_lifecycle_id
       and lease.user_id=target_owner_id;
    return true;
  end if;
  select command.id,command.state,command.tenant_id,command.lifecycle_id,
         command.connection_id,command.account_id,command.user_id
    into target_command_id,target_command_state,target_tenant_id,
         target_lifecycle_id,target_connection_id,target_account_id,target_owner_id
    from argus_private.outbox_events event
    join argus_private.provider_commands command
      on command.id=event.aggregate_id and command.user_id=event.user_id
     and command.deletion_epoch=event.deletion_epoch
   where event.id=p_event_id and event.topic='brokerage_reconcile'
     and event.event_type='webull.command.reconciliation.requested';
  if target_command_id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    target_tenant_id,target_lifecycle_id,target_owner_id,
    target_connection_id,target_account_id
  );
  select command.id,command.state
    into target_command_id,target_command_state
    from argus_private.provider_commands command
   where command.id=target_command_id
   for update;
  if target_command_state not in (
    'dispatching','ambiguous','reconciling','manual_review'
  ) then
    return true;
  end if;
  if target_command_state='dispatching' then
    update argus_private.provider_commands command
       set state='ambiguous',updated_at=pg_catalog.clock_timestamp()
     where command.id=target_command_id;
    target_command_state:='ambiguous';
  end if;
  if target_command_state in ('ambiguous','reconciling') then
    update argus_private.provider_commands command
       set state='manual_review',updated_at=pg_catalog.clock_timestamp()
     where command.id=target_command_id;
  end if;
  insert into argus_private.reconciliation_records(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,status,next_attempt_at,last_error_code
  )
  select command.tenant_id,command.lifecycle_id,command.user_id,
         command.deletion_epoch,command.connection_id,command.account_id,
         command.id,'manual_review',pg_catalog.clock_timestamp(),
         case when p_reason~'^[a-z][a-z0-9_]{0,63}$'
              then p_reason else 'reconciliation_exhausted' end
    from argus_private.provider_commands command
   where command.id=target_command_id
  on conflict on constraint reconciliation_records_command_id_key do update
    set status='manual_review',last_error_code=excluded.last_error_code,
        updated_at=pg_catalog.clock_timestamp();
  return true;
end
$$;

-- Reconnect and callback replacement share one scoped cleanup. Accounts that
-- anchor durable commands are retained as unavailable audit parents; only
-- unreferenced provider materialization is deleted.
create or replace function argus_private.clear_webull_connection_materialization(
  p_connection_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare owner_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,owner_id
    from argus_private.read_trusted_request_context() context;
  if request_tenant_id is null or request_lifecycle_id is null
     or owner_id is null then
    raise exception 'owner_mismatch' using errcode='42501';
  end if;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,owner_id,p_connection_id,null
  );
  perform 1
    from argus_brokerage.accounts account
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=owner_id and account.connection_id=p_connection_id
   order by account.id
   for update;
  if exists (
    select 1 from argus_private.provider_commands command
     where command.tenant_id=request_tenant_id
       and command.lifecycle_id=request_lifecycle_id
       and command.user_id=owner_id and command.connection_id=p_connection_id
       and command.state in (
         'dispatching','ambiguous','reconciling','manual_review'
       )
  ) then
    raise exception 'connection_recovery_pending';
  end if;
  delete from argus_brokerage.active_account_selections selection
   where selection.tenant_id=request_tenant_id
     and selection.lifecycle_id=request_lifecycle_id
     and selection.user_id=owner_id
     and selection.connection_id=p_connection_id;
  delete from argus_private.refresh_leases lease
   where lease.tenant_id=request_tenant_id
     and lease.lifecycle_id=request_lifecycle_id
     and lease.user_id=owner_id and lease.connection_id=p_connection_id;
  delete from argus_private.webull_credentials credential
   where credential.tenant_id=request_tenant_id
     and credential.lifecycle_id=request_lifecycle_id
     and credential.user_id=owner_id
     and credential.connection_id=p_connection_id;
  delete from argus_private.webull_account_mappings mapping
   where mapping.tenant_id=request_tenant_id
     and mapping.lifecycle_id=request_lifecycle_id
     and mapping.user_id=owner_id and mapping.connection_id=p_connection_id;
  delete from argus_brokerage.accounts account
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=owner_id and account.connection_id=p_connection_id
     and not exists (
       select 1 from argus_private.provider_commands command
        where command.tenant_id=account.tenant_id
          and command.lifecycle_id=account.lifecycle_id
          and command.user_id=account.user_id
          and command.connection_id=account.connection_id
          and command.account_id=account.id
     );
  update argus_brokerage.accounts account
     set status='unavailable',
         expires_at=case when account.fetched_at is null then null
                         else pg_catalog.clock_timestamp() end
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=owner_id and account.connection_id=p_connection_id;
  return true;
end
$$;

create or replace function argus_private.disconnect_webull_connection(
  p_receipt_hash text,p_session_id uuid
)
returns table(connection_id uuid,status text,provider_grant_revoked boolean)
language plpgsql
security definer
set search_path=''
as $$
declare owner_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare selected_connection uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into owner_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  if owner_id is null or request_tenant_id is null
     or request_lifecycle_id is null
     or p_receipt_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'step_up_required' using errcode='42501';
  end if;
  select connection.id into selected_connection
    from argus_brokerage.connections connection
   where connection.tenant_id=request_tenant_id
     and connection.lifecycle_id=request_lifecycle_id
     and connection.user_id=owner_id and connection.status<>'disconnected'
   order by connection.created_at desc limit 1;
  if selected_connection is null then
    raise exception 'connection_not_found';
  end if;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,owner_id,selected_connection,null
  );
  update argus_private.step_up_receipts receipt
     set consumed_at=pg_catalog.clock_timestamp()
   where receipt.receipt_hash=p_receipt_hash and receipt.user_id=owner_id
     and receipt.session_id=p_session_id and receipt.action='webull_disconnect'
     and receipt.aal='aal2' and receipt.consumed_at is null
     and receipt.expires_at>pg_catalog.clock_timestamp();
  if not found then
    raise exception 'step_up_required' using errcode='42501';
  end if;
  update argus_brokerage.connections connection
     set status='disconnected',egress_fenced_at=pg_catalog.clock_timestamp(),
         disconnected_at=pg_catalog.clock_timestamp(),last_error_code=null,
         updated_at=pg_catalog.clock_timestamp()
   where connection.tenant_id=request_tenant_id
     and connection.lifecycle_id=request_lifecycle_id
     and connection.id=selected_connection and connection.user_id=owner_id;
  perform argus_private.clear_webull_connection_materialization(
    selected_connection
  );
  update argus_private.job_runs run
     set status='cancelled',lease_token=null,leased_until=null,
         last_error_code='member_deleted',updated_at=pg_catalog.clock_timestamp()
   where run.source_event_id in (
     select event.id from argus_private.outbox_events event
      where event.user_id=owner_id
        and event.topic in ('brokerage_refresh','brokerage_reconcile')
   ) and run.status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events event
   where event.user_id=owner_id
     and event.topic in ('brokerage_refresh','brokerage_reconcile');
  delete from argus_private.oauth_states state_row
   where state_row.tenant_id=request_tenant_id
     and state_row.lifecycle_id=request_lifecycle_id
     and state_row.user_id=owner_id
     and state_row.connection_id=selected_connection;
  delete from argus_private.webull_completion_handles handle
   where handle.tenant_id=request_tenant_id
     and handle.lifecycle_id=request_lifecycle_id
     and handle.user_id=owner_id
     and handle.connection_id=selected_connection;
  delete from argus_private.projection_refresh_leases lease
   where lease.tenant_id=request_tenant_id
     and lease.lifecycle_id=request_lifecycle_id
     and lease.user_id=owner_id and lease.connection_id=selected_connection;
  return query select selected_connection,'disconnected'::text,false;
end
$$;

create or replace function argus_private.claim_webull_projection_refresh(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_lease_seconds integer
)
returns table(
  claim_outcome text,lease_id uuid,user_id uuid,deletion_epoch bigint,
  connection_id uuid,account_id uuid,resource_type text,
  provider_environment text,token_version bigint,key_version integer,
  access_ciphertext bytea,access_nonce bytea,access_tag bytea,
  refresh_ciphertext bytea,refresh_nonce bytea,refresh_tag bytea,
  wrapped_data_key bytea,wrapped_key_nonce bytea,wrapped_key_tag bytea,
  associated_data_hash text,access_expires_at timestamptz,
  refresh_expires_at timestamptz,provider_account_id_ciphertext bytea,
  provider_account_key_version integer
)
language plpgsql
security definer
set search_path=''
as $$
declare event_record argus_private.outbox_events%rowtype;
declare lease_record argus_private.projection_refresh_leases%rowtype;
declare credential argus_private.webull_credentials%rowtype;
declare mapping argus_private.webull_account_mappings%rowtype;
begin
  if p_lease_seconds<15 or p_lease_seconds>55 then
    raise exception 'invalid_lease_duration';
  end if;
  select event.* into event_record
    from argus_private.outbox_events event
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
     and event.aggregate_id=p_lease_id
     and exists (
       select 1 from argus_private.job_runs run
        where run.source_event_id=event.id
          and run.handler_name='webull-projection-refresh'
          and run.status='leased'
          and run.leased_until>pg_catalog.clock_timestamp()
     );
  if event_record.id is null
     or not argus_private.assert_worker_event_current(p_event_id) then
    return;
  end if;
  if exists (
    select 1 from argus_private.kill_switches switch_row
     where switch_row.name='provider_egress' and switch_row.enabled
  ) then raise exception 'worker_killed'; end if;
  select lease.* into lease_record
    from argus_private.projection_refresh_leases lease
   where lease.id=p_lease_id and lease.user_id=event_record.user_id
     and lease.deletion_epoch=event_record.deletion_epoch;
  if lease_record.id is null then return; end if;
  perform argus_private.lock_brokerage_scope(
    lease_record.tenant_id,lease_record.lifecycle_id,lease_record.user_id,
    lease_record.connection_id,lease_record.account_id
  );
  select lease.* into lease_record
    from argus_private.projection_refresh_leases lease
   where lease.id=p_lease_id and lease.user_id=event_record.user_id
     and lease.deletion_epoch=event_record.deletion_epoch
   for update;
  if lease_record.id is null
     or lease_record.resource_type not in (
       'account','balance','positions','restrictions'
     )
     or lease_record.leased_until>pg_catalog.clock_timestamp() then
    return;
  end if;
  update argus_private.projection_refresh_leases lease
     set lease_token=p_lease_token,
         leased_until=pg_catalog.clock_timestamp()
           +pg_catalog.make_interval(secs=>p_lease_seconds),
         acquired_at=pg_catalog.clock_timestamp()
   where lease.id=p_lease_id;
  select current_credential.* into credential
    from argus_private.webull_credentials current_credential
   where current_credential.tenant_id=lease_record.tenant_id
     and current_credential.lifecycle_id=lease_record.lifecycle_id
     and current_credential.connection_id=lease_record.connection_id
     and current_credential.user_id=lease_record.user_id
     and current_credential.deletion_epoch=lease_record.deletion_epoch;
  select account_mapping.* into mapping
    from argus_private.webull_account_mappings account_mapping
   where account_mapping.tenant_id=lease_record.tenant_id
     and account_mapping.lifecycle_id=lease_record.lifecycle_id
     and account_mapping.account_id=lease_record.account_id
     and account_mapping.connection_id=lease_record.connection_id
     and account_mapping.user_id=lease_record.user_id
     and account_mapping.deletion_epoch=lease_record.deletion_epoch;
  if credential.connection_id is null or mapping.account_id is null
     or not exists (
       select 1 from argus_brokerage.connections connection
       join argus_brokerage.accounts account
         on account.tenant_id=connection.tenant_id
        and account.lifecycle_id=connection.lifecycle_id
        and account.user_id=connection.user_id
        and account.connection_id=connection.id
      where connection.tenant_id=lease_record.tenant_id
        and connection.lifecycle_id=lease_record.lifecycle_id
        and connection.user_id=lease_record.user_id
        and connection.id=lease_record.connection_id
        and connection.status='connected'
        and connection.egress_fenced_at is null
        and account.id=lease_record.account_id
     ) then
    delete from argus_private.projection_refresh_leases lease
     where lease.id=p_lease_id;
    return;
  end if;
  return query
    select 'claimed'::text,lease_record.id,credential.user_id,
      credential.deletion_epoch,credential.connection_id,
      lease_record.account_id,lease_record.resource_type,
      credential.provider_environment,credential.token_version,
      credential.key_version,credential.access_ciphertext,
      credential.access_nonce,credential.access_tag,
      credential.refresh_ciphertext,credential.refresh_nonce,
      credential.refresh_tag,credential.wrapped_data_key,
      credential.wrapped_key_nonce,credential.wrapped_key_tag,
      credential.associated_data_hash,credential.access_expires_at,
      credential.refresh_expires_at,
      mapping.provider_account_id_ciphertext,mapping.key_version;
end
$$;

create or replace function argus_private.authorize_webull_projection_egress(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare lease_record argus_private.projection_refresh_leases%rowtype;
begin
  if exists (
    select 1 from argus_private.kill_switches switch_row
     where switch_row.name='provider_egress' and switch_row.enabled
  ) then raise exception 'worker_killed'; end if;
  select lease.* into lease_record
    from argus_private.projection_refresh_leases lease
    join argus_private.outbox_events event
      on event.id=p_event_id and event.aggregate_id=lease.id
     and event.user_id=lease.user_id
     and event.deletion_epoch=lease.deletion_epoch
   where lease.id=p_lease_id;
  if lease_record.id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    lease_record.tenant_id,lease_record.lifecycle_id,lease_record.user_id,
    lease_record.connection_id,lease_record.account_id
  );
  return exists (
    select 1 from argus_private.outbox_events event
    join argus_private.job_runs run
      on run.source_event_id=event.id
     and run.handler_name='webull-projection-refresh'
     and run.status='leased' and run.leased_until>pg_catalog.clock_timestamp()
    join argus_private.projection_refresh_leases lease
      on lease.id=event.aggregate_id and lease.user_id=event.user_id
     and lease.deletion_epoch=event.deletion_epoch
     and lease.lease_token=p_lease_token
     and lease.leased_until>pg_catalog.clock_timestamp()
    join argus_brokerage.connections connection
      on connection.tenant_id=lease.tenant_id
     and connection.lifecycle_id=lease.lifecycle_id
     and connection.id=lease.connection_id
     and connection.user_id=lease.user_id
     and connection.status='connected'
     and connection.egress_fenced_at is null
    join argus_brokerage.accounts account
      on account.tenant_id=connection.tenant_id
     and account.lifecycle_id=connection.lifecycle_id
     and account.user_id=connection.user_id
     and account.connection_id=connection.id
     and account.id=lease.account_id
    join argus_private.webull_credentials credential
      on credential.tenant_id=connection.tenant_id
     and credential.lifecycle_id=connection.lifecycle_id
     and credential.connection_id=connection.id
     and credential.user_id=connection.user_id
     and credential.token_version=p_token_version
     and credential.key_version=p_key_version
     and credential.associated_data_hash=p_aad_hash
   where event.id=p_event_id and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
     and event.aggregate_id=p_lease_id
  );
end
$$;

create or replace function argus_private.commit_webull_projection_refresh(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_token_version bigint,
  p_key_version integer,p_aad_hash text,p_resource_type text,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_expires_at timestamptz,p_availability text,p_reason_code text
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare lease_record argus_private.projection_refresh_leases%rowtype;
declare next_generation bigint;
begin
  if p_resource_type not in ('account','balance','positions','restrictions')
     or pg_catalog.jsonb_typeof(p_payload) not in ('object','array')
     or p_payload::text ~*
       '"((access|refresh)_?token|secret|raw_payload|provider_(account|asset|order)_(id|ref))"[[:space:]]*:'
     or p_fetched_at>pg_catalog.clock_timestamp()+interval '30 seconds'
     or p_expires_at<p_fetched_at
     or p_expires_at>p_fetched_at+interval '5 minutes'
     or p_provider_observed_at>p_fetched_at
     or p_availability not in ('available','partial')
     or (p_reason_code is not null
         and p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$') then
    raise exception 'invalid_event_payload';
  end if;
  select lease.* into lease_record
    from argus_private.projection_refresh_leases lease
    join argus_private.outbox_events event
      on event.id=p_event_id and event.aggregate_id=lease.id
     and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
   where lease.id=p_lease_id;
  if lease_record.id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    lease_record.tenant_id,lease_record.lifecycle_id,lease_record.user_id,
    lease_record.connection_id,lease_record.account_id
  );
  select lease.* into lease_record
    from argus_private.projection_refresh_leases lease
    join argus_private.outbox_events event
      on event.id=p_event_id and event.aggregate_id=lease.id
     and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
     and event.user_id=lease.user_id
     and event.deletion_epoch=lease.deletion_epoch
    join argus_brokerage.connections connection
      on connection.tenant_id=lease.tenant_id
     and connection.lifecycle_id=lease.lifecycle_id
     and connection.user_id=lease.user_id
     and connection.id=lease.connection_id
     and connection.status='connected'
     and connection.egress_fenced_at is null
    join argus_brokerage.accounts account
      on account.tenant_id=connection.tenant_id
     and account.lifecycle_id=connection.lifecycle_id
     and account.user_id=connection.user_id
     and account.connection_id=connection.id and account.id=lease.account_id
    join argus_private.webull_credentials credential
      on credential.tenant_id=connection.tenant_id
     and credential.lifecycle_id=connection.lifecycle_id
     and credential.connection_id=connection.id
     and credential.user_id=connection.user_id
     and credential.token_version=p_token_version
     and credential.key_version=p_key_version
     and credential.associated_data_hash=p_aad_hash
   where lease.id=p_lease_id and lease.lease_token=p_lease_token
     and lease.leased_until>pg_catalog.clock_timestamp()
     and lease.resource_type=p_resource_type
     and not exists (
       select 1 from argus_private.kill_switches switch_row
        where switch_row.name='provider_egress' and switch_row.enabled
     )
   for update of lease;
  if lease_record.id is null then return false; end if;
  select coalesce(pg_catalog.max(generation.generation),0)+1
    into next_generation
    from argus_brokerage.projection_generations generation
   where generation.tenant_id=lease_record.tenant_id
     and generation.lifecycle_id=lease_record.lifecycle_id
     and generation.account_id=lease_record.account_id
     and generation.resource_type=p_resource_type;
  insert into argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    resource_type,generation,normalized_payload,provider_observed_at,fetched_at,
    expires_at,availability,reason_code,purge_after
  ) values (
    lease_record.tenant_id,lease_record.lifecycle_id,lease_record.user_id,
    lease_record.deletion_epoch,lease_record.connection_id,
    lease_record.account_id,p_resource_type,next_generation,p_payload,
    p_provider_observed_at,p_fetched_at,p_expires_at,p_availability,
    p_reason_code,p_fetched_at+interval '30 days'
  );
  delete from argus_private.projection_refresh_leases lease
   where lease.id=lease_record.id;
  return true;
end
$$;

create or replace function argus_private.release_webull_projection_refresh(
  p_event_id uuid,p_lease_id uuid,p_lease_token uuid,p_preserve_for_retry boolean
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare lease_record argus_private.projection_refresh_leases%rowtype;
begin
  select lease.* into lease_record
    from argus_private.projection_refresh_leases lease
    join argus_private.outbox_events event
      on event.id=p_event_id and event.aggregate_id=lease.id
     and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested'
   where lease.id=p_lease_id and lease.lease_token=p_lease_token;
  if lease_record.id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    lease_record.tenant_id,lease_record.lifecycle_id,lease_record.user_id,
    lease_record.connection_id,lease_record.account_id
  );
  if p_preserve_for_retry then
    update argus_private.projection_refresh_leases lease
       set leased_until=pg_catalog.clock_timestamp(),
           lease_token=extensions.gen_random_uuid()
      from argus_private.outbox_events event
     where lease.id=p_lease_id and lease.lease_token=p_lease_token
       and event.id=p_event_id and event.aggregate_id=lease.id
       and event.topic='brokerage_refresh'
       and event.event_type='webull.projection.refresh.requested';
    return found;
  end if;
  delete from argus_private.projection_refresh_leases lease
    using argus_private.outbox_events event
   where lease.id=p_lease_id and lease.lease_token=p_lease_token
     and event.id=p_event_id and event.aggregate_id=lease.id
     and event.topic='brokerage_refresh'
     and event.event_type='webull.projection.refresh.requested';
  return found;
end
$$;

create or replace function argus_private.consume_webull_oauth_state(
  p_state_hash text,p_consumed_at timestamptz
)
returns table(
  state_id uuid,user_id uuid,session_id uuid,deletion_epoch bigint,
  connection_id uuid,return_target text,contract_version text,
  provider_environment text
)
language plpgsql
security definer
set search_path=''
as $$
declare state_record argus_private.oauth_states%rowtype;
begin
  if p_state_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_state_hash' using errcode='22023';
  end if;
  select state.* into state_record
    from argus_private.oauth_states state
   where state.state_hash=p_state_hash and state.consumed_at is null
     and state.expires_at>p_consumed_at;
  if state_record.id is null then return; end if;
  perform argus_private.lock_brokerage_scope(
    state_record.tenant_id,state_record.lifecycle_id,state_record.user_id,
    state_record.connection_id,null
  );
  return query
  update argus_private.oauth_states state
     set consumed_at=p_consumed_at
    from argus_brokerage.connections connection
   where state.tenant_id=state_record.tenant_id
     and state.lifecycle_id=state_record.lifecycle_id
     and state.id=state_record.id and state.state_hash=p_state_hash
     and state.consumed_at is null and state.expires_at>p_consumed_at
     and connection.tenant_id=state.tenant_id
     and connection.lifecycle_id=state.lifecycle_id
     and connection.id=state.connection_id
     and connection.user_id=state.user_id
     and connection.status='pending'
  returning state.id,state.user_id,state.session_id,state.deletion_epoch,
            state.connection_id,state.return_target,state.contract_version,
            state.provider_environment;
end
$$;

create or replace function argus_private.append_order_projection(
  p_user_id uuid,p_deletion_epoch bigint,p_connection_id uuid,p_account_id uuid,
  p_order_id uuid,p_state text,p_filled_quantity numeric,p_source text,
  p_payload jsonb,p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_order_list_generation bigint
)
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare prior argus_brokerage.order_projection_generations%rowtype;
declare next_generation bigint;
declare prior_rank integer;
declare next_rank integer;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  if request_user_id is distinct from p_user_id
     or request_tenant_id is null or request_lifecycle_id is null then
    raise exception 'owner_mismatch' using errcode='42501';
  end if;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,p_user_id,p_connection_id,p_account_id
  );
  if pg_catalog.jsonb_typeof(p_payload)<>'object'
     or p_payload::text ~*
       '"(provider_order_id|provider_asset_id|token|secret|raw_payload)"'
     or p_payload->>'id' is distinct from p_order_id::text
     or p_payload->>'state' is distinct from p_state
     or (p_payload->>'filled_quantity')::numeric
          is distinct from p_filled_quantity
     or ((p_source='list') is distinct from
         (p_order_list_generation is not null))
     or p_provider_observed_at>p_fetched_at+interval '30 seconds'
     or p_fetched_at>pg_catalog.now()+interval '30 seconds' then
    raise exception 'invalid_order_projection';
  end if;
  -- The common account guard above serializes generation allocation. History
  -- is immutable, so taking an UPDATE row lock here would wrongly require an
  -- UPDATE RLS policy on evidence rows.
  select generation.* into prior
    from argus_brokerage.order_projection_generations generation
   where generation.tenant_id=request_tenant_id
     and generation.lifecycle_id=request_lifecycle_id
     and generation.user_id=p_user_id
     and generation.connection_id=p_connection_id
     and generation.account_id=p_account_id and generation.order_id=p_order_id
   order by generation.generation desc limit 1;
  if prior.id is not null then
    prior_rank:=case prior.state
      when 'unknown' then 0 when 'pending' then 10
      when 'partially_filled' then 20
      when 'rejected' then 30 when 'expired' then 30
      when 'cancelled' then 30 when 'filled' then 40 end;
    next_rank:=case p_state
      when 'unknown' then 0 when 'pending' then 10
      when 'partially_filled' then 20
      when 'rejected' then 30 when 'expired' then 30
      when 'cancelled' then 30 when 'filled' then 40 end;
    if next_rank is null or next_rank<prior_rank
       or p_filled_quantity<prior.filled_quantity
       or p_provider_observed_at<prior.provider_observed_at
       or (p_provider_observed_at=prior.provider_observed_at
           and prior.source='detail' and p_source='list') then
      raise exception 'non_monotonic_order_projection';
    end if;
  end if;
  next_generation:=coalesce(prior.generation,0)+1;
  insert into argus_brokerage.order_projection_generations(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    order_id,generation,source,state,filled_quantity,normalized_payload,
    provider_observed_at,fetched_at,order_list_generation,purge_after
  ) values (
    request_tenant_id,request_lifecycle_id,p_user_id,p_deletion_epoch,
    p_connection_id,p_account_id,p_order_id,next_generation,p_source,p_state,
    p_filled_quantity,p_payload,p_provider_observed_at,p_fetched_at,
    p_order_list_generation,p_fetched_at+interval '90 days'
  );
  return next_generation;
end
$$;

create or replace function argus_private.append_order_projection_scoped(
  p_tenant_id uuid,p_lifecycle_id uuid,p_user_id uuid,p_deletion_epoch bigint,
  p_connection_id uuid,p_account_id uuid,p_order_id uuid,p_state text,
  p_filled_quantity numeric,p_source text,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_order_list_generation bigint
)
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare prior argus_brokerage.order_projection_generations%rowtype;
declare next_generation bigint;
declare prior_rank integer;
declare next_rank integer;
begin
  perform argus_private.lock_brokerage_scope(
    p_tenant_id,p_lifecycle_id,p_user_id,p_connection_id,p_account_id
  );
  if pg_catalog.jsonb_typeof(p_payload)<>'object'
     or p_payload::text ~*
       '"(provider_order_id|provider_asset_id|token|secret|raw_payload)"'
     or p_payload->>'id' is distinct from p_order_id::text
     or p_payload->>'state' is distinct from p_state
     or (p_payload->>'filled_quantity')::numeric
          is distinct from p_filled_quantity
     or ((p_source='list') is distinct from
         (p_order_list_generation is not null))
     or p_provider_observed_at>p_fetched_at+interval '30 seconds'
     or p_fetched_at>pg_catalog.now()+interval '30 seconds' then
    raise exception 'invalid_order_projection';
  end if;
  -- lock_brokerage_scope already serializes this account. Read immutable
  -- evidence without manufacturing UPDATE authority solely for row locking.
  select generation.* into prior
    from argus_brokerage.order_projection_generations generation
   where generation.tenant_id=p_tenant_id
     and generation.lifecycle_id=p_lifecycle_id
     and generation.user_id=p_user_id
     and generation.connection_id=p_connection_id
     and generation.account_id=p_account_id and generation.order_id=p_order_id
   order by generation.generation desc limit 1;
  if prior.id is not null then
    prior_rank:=case prior.state
      when 'unknown' then 0 when 'pending' then 10
      when 'partially_filled' then 20
      when 'rejected' then 30 when 'expired' then 30
      when 'cancelled' then 30 when 'filled' then 40 end;
    next_rank:=case p_state
      when 'unknown' then 0 when 'pending' then 10
      when 'partially_filled' then 20
      when 'rejected' then 30 when 'expired' then 30
      when 'cancelled' then 30 when 'filled' then 40 end;
    if next_rank is null or next_rank<prior_rank
       or p_filled_quantity<prior.filled_quantity
       or p_provider_observed_at<prior.provider_observed_at
       or (p_provider_observed_at=prior.provider_observed_at
           and prior.source='detail' and p_source='list') then
      raise exception 'non_monotonic_order_projection';
    end if;
  end if;
  next_generation:=coalesce(prior.generation,0)+1;
  insert into argus_brokerage.order_projection_generations(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    order_id,generation,source,state,filled_quantity,normalized_payload,
    provider_observed_at,fetched_at,order_list_generation,purge_after
  ) values (
    p_tenant_id,p_lifecycle_id,p_user_id,p_deletion_epoch,p_connection_id,
    p_account_id,p_order_id,next_generation,p_source,p_state,
    p_filled_quantity,p_payload,p_provider_observed_at,p_fetched_at,
    p_order_list_generation,p_fetched_at+interval '90 days'
  );
  return next_generation;
end
$$;

create or replace function argus_private.begin_brokerage_order_list_ingestion(
  p_account_id uuid,p_connection_id uuid,p_deletion_epoch bigint
)
returns table(result_provider_environment text,result_list_generation bigint)
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    p_connection_id,p_account_id
  );
  return query
  select credential.provider_environment,
         coalesce(pg_catalog.max(generation.generation),0)+1
    from argus_brokerage.accounts account
    join argus_brokerage.connections connection
      on connection.tenant_id=account.tenant_id
     and connection.lifecycle_id=account.lifecycle_id
     and connection.user_id=account.user_id
     and connection.id=account.connection_id
    join argus_private.webull_credentials credential
      on credential.tenant_id=connection.tenant_id
     and credential.lifecycle_id=connection.lifecycle_id
     and credential.connection_id=connection.id
     and credential.user_id=connection.user_id
    left join argus_brokerage.projection_generations generation
      on generation.tenant_id=account.tenant_id
     and generation.lifecycle_id=account.lifecycle_id
     and generation.account_id=account.id
     and generation.resource_type='orders'
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=request_user_id and account.id=p_account_id
     and account.connection_id=p_connection_id
     and account.deletion_epoch=p_deletion_epoch
     and connection.status='connected'
     and connection.egress_fenced_at is null
   group by credential.provider_environment;
end
$$;

create or replace function argus_private.append_brokerage_order_list_observation(
  p_account_id uuid,p_connection_id uuid,p_deletion_epoch bigint,
  p_list_generation bigint,p_order_id uuid,p_reference_ciphertext bytea,
  p_reference_hash text,p_key_version integer,p_instrument_id uuid,
  p_state text,p_filled_quantity numeric,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz
)
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
declare retained_environment text;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    p_connection_id,p_account_id
  );
  select credential.provider_environment into retained_environment
    from argus_brokerage.accounts account
    join argus_brokerage.connections connection
      on connection.tenant_id=account.tenant_id
     and connection.lifecycle_id=account.lifecycle_id
     and connection.user_id=account.user_id
     and connection.id=account.connection_id
    join argus_private.webull_credentials credential
      on credential.tenant_id=connection.tenant_id
     and credential.lifecycle_id=connection.lifecycle_id
     and credential.connection_id=connection.id
     and credential.user_id=connection.user_id
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=request_user_id and account.id=p_account_id
     and account.connection_id=p_connection_id
     and account.deletion_epoch=p_deletion_epoch
     and connection.status='connected'
     and connection.egress_fenced_at is null
     and exists (
       select 1 from argus_private.webull_asset_mappings asset
        where asset.tenant_id=account.tenant_id
          and asset.lifecycle_id=account.lifecycle_id
          and asset.user_id=account.user_id
          and asset.connection_id=account.connection_id
          and asset.account_id=account.id
          and asset.instrument_id=p_instrument_id
     );
  if retained_environment is null or p_list_generation<1
     or pg_catalog.octet_length(p_reference_ciphertext) not between 32 and 4096
     or p_reference_hash !~ '^[a-f0-9]{64}$' or p_key_version<1 then
    raise exception 'order_list_ingestion_fenced' using errcode='42501';
  end if;
  insert into argus_private.webull_order_mappings(
    tenant_id,lifecycle_id,order_id,account_id,connection_id,user_id,
    deletion_epoch,provider_environment,provider_order_ref_ciphertext,
    provider_order_ref_hash,key_version
  ) values (
    request_tenant_id,request_lifecycle_id,p_order_id,p_account_id,
    p_connection_id,request_user_id,p_deletion_epoch,retained_environment,
    p_reference_ciphertext,p_reference_hash,p_key_version
  ) on conflict (user_id,account_id,provider_order_ref_hash) do nothing;
  if not exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.tenant_id=request_tenant_id
       and mapping.lifecycle_id=request_lifecycle_id
       and mapping.user_id=request_user_id and mapping.account_id=p_account_id
       and mapping.connection_id=p_connection_id
       and mapping.deletion_epoch=p_deletion_epoch
       and mapping.order_id=p_order_id
       and mapping.provider_order_ref_hash=p_reference_hash
  ) then
    raise exception 'provider_order_mapping_conflict';
  end if;
  return argus_private.append_order_projection_scoped(
    request_tenant_id,request_lifecycle_id,request_user_id,p_deletion_epoch,
    p_connection_id,p_account_id,p_order_id,p_state,p_filled_quantity,'list',
    p_payload,p_provider_observed_at,p_fetched_at,p_list_generation
  );
end
$$;

create or replace function argus_private.complete_brokerage_order_list_ingestion(
  p_account_id uuid,p_connection_id uuid,p_deletion_epoch bigint,
  p_list_generation bigint,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_expires_at timestamptz,p_availability text,p_reason_code text
)
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
declare expected_count integer;
declare actual_count integer;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    p_connection_id,p_account_id
  );
  if pg_catalog.jsonb_typeof(p_payload)<>'array' then
    raise exception 'invalid_order_list_projection' using errcode='22023';
  end if;
  expected_count:=pg_catalog.jsonb_array_length(p_payload);
  if expected_count>10000 or p_list_generation<1 then
    raise exception 'invalid_order_list_projection' using errcode='22023';
  end if;
  if not exists (
    select 1 from argus_brokerage.accounts account
    join argus_brokerage.connections connection
      on connection.tenant_id=account.tenant_id
     and connection.lifecycle_id=account.lifecycle_id
     and connection.user_id=account.user_id
     and connection.id=account.connection_id
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=request_user_id and account.id=p_account_id
     and account.connection_id=p_connection_id
     and account.deletion_epoch=p_deletion_epoch
     and connection.status='connected'
     and connection.egress_fenced_at is null
  ) then
    raise exception 'order_list_ingestion_fenced' using errcode='42501';
  end if;
  select pg_catalog.count(*)::integer into actual_count
    from argus_brokerage.order_projection_generations generation
   where generation.tenant_id=request_tenant_id
     and generation.lifecycle_id=request_lifecycle_id
     and generation.user_id=request_user_id
     and generation.connection_id=p_connection_id
     and generation.account_id=p_account_id
     and generation.source='list'
     and generation.order_list_generation=p_list_generation;
  if actual_count<>expected_count or exists (
    select 1 from pg_catalog.jsonb_array_elements(p_payload) listed_order
     where pg_catalog.jsonb_typeof(listed_order)<>'object'
        or listed_order->>'id' is null
        or not exists (
          select 1 from argus_brokerage.order_projection_generations generation
           where generation.tenant_id=request_tenant_id
             and generation.lifecycle_id=request_lifecycle_id
             and generation.user_id=request_user_id
             and generation.connection_id=p_connection_id
             and generation.account_id=p_account_id
             and generation.order_list_generation=p_list_generation
             and generation.order_id=(listed_order->>'id')::uuid
        )
  ) then
    raise exception 'order_list_generation_mismatch' using errcode='23514';
  end if;
  insert into argus_brokerage.projection_generations(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    resource_type,generation,normalized_payload,provider_observed_at,fetched_at,
    expires_at,availability,reason_code,purge_after
  ) values (
    request_tenant_id,request_lifecycle_id,request_user_id,p_deletion_epoch,
    p_connection_id,p_account_id,'orders',p_list_generation,p_payload,
    p_provider_observed_at,p_fetched_at,p_expires_at,p_availability,
    p_reason_code,p_fetched_at+interval '90 days'
  );
  return p_list_generation;
end
$$;

create or replace function argus_private.record_provider_order_acknowledgement(
  p_command_id uuid,p_order_id uuid,p_reference_ciphertext bytea,
  p_reference_hash text,p_key_version integer,p_instrument_id uuid,
  p_state text,p_filled_quantity numeric,p_source text,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_expected_payload_hash text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare command_row argus_private.provider_commands%rowtype;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=request_user_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id;
  if command_row.id is null then
    raise exception 'invalid_provider_acknowledgement';
  end if;
  perform argus_private.lock_brokerage_scope(
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.connection_id,command_row.account_id
  );
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=request_user_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id
   for update;
  if command_row.id is null or command_row.state<>'dispatching'
     or command_row.normalized_payload_hash<>p_expected_payload_hash
     or (command_row.target_order_id is not null
         and command_row.target_order_id<>p_order_id)
     or pg_catalog.octet_length(p_reference_ciphertext) not between 32 and 4096
     or p_reference_hash !~ '^[a-f0-9]{64}$' or p_key_version<1
     or not exists (
       select 1 from argus_private.webull_asset_mappings asset
        where asset.tenant_id=command_row.tenant_id
          and asset.lifecycle_id=command_row.lifecycle_id
          and asset.user_id=command_row.user_id
          and asset.connection_id=command_row.connection_id
          and asset.account_id=command_row.account_id
          and asset.instrument_id=p_instrument_id
          and asset.asset_kind in ('equity','etf')
     ) then
    raise exception 'invalid_provider_acknowledgement';
  end if;
  insert into argus_private.webull_order_mappings(
    tenant_id,lifecycle_id,order_id,account_id,connection_id,user_id,
    deletion_epoch,provider_environment,provider_order_ref_ciphertext,
    provider_order_ref_hash,key_version
  )
  select command_row.tenant_id,command_row.lifecycle_id,p_order_id,
         command_row.account_id,command_row.connection_id,command_row.user_id,
         command_row.deletion_epoch,credential.provider_environment,
         p_reference_ciphertext,p_reference_hash,p_key_version
    from argus_private.webull_credentials credential
   where credential.tenant_id=command_row.tenant_id
     and credential.lifecycle_id=command_row.lifecycle_id
     and credential.connection_id=command_row.connection_id
     and credential.user_id=command_row.user_id
  on conflict (order_id) do nothing;
  if not exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.tenant_id=command_row.tenant_id
       and mapping.lifecycle_id=command_row.lifecycle_id
       and mapping.order_id=p_order_id
       and mapping.user_id=command_row.user_id
       and mapping.account_id=command_row.account_id
       and mapping.provider_order_ref_hash=p_reference_hash
  ) then raise exception 'provider_order_mapping_conflict'; end if;
  perform argus_private.append_order_projection(
    command_row.user_id,command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_order_id,p_state,p_filled_quantity,p_source,
    p_payload,p_provider_observed_at,p_fetched_at,null
  );
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_command_id,2,'egress','accepted'
  );
  update argus_private.provider_commands command
     set state='accepted',provider_order_ref_hash=p_reference_hash,
         order_id=p_order_id,updated_at=pg_catalog.now()
   where command.id=p_command_id;
end
$$;

create or replace function argus_private.record_provider_command_not_found(
  p_command_id uuid
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare command_row argus_private.provider_commands%rowtype;
declare next_attempt_number integer;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=request_user_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  perform argus_private.lock_brokerage_scope(
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.connection_id,command_row.account_id
  );
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id and command.state='reconciling'
   for update;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_command_id,next_attempt_number,
    'detail_lookup','not_found'
  );
  update argus_private.reconciliation_records record
     set status='pending',next_attempt_at=pg_catalog.now()+interval '30 seconds',
         last_error_code='provider_order_not_found',updated_at=pg_catalog.now()
   where record.command_id=p_command_id;
end
$$;

create or replace function argus_private.record_provider_command_lookup_ambiguous(
  p_command_id uuid,p_reason_code text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare command_row argus_private.provider_commands%rowtype;
declare next_attempt_number integer;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  if p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    p_reason_code:='provider_lookup_unavailable';
  end if;
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=request_user_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  perform argus_private.lock_brokerage_scope(
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.connection_id,command_row.account_id
  );
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id and command.state='reconciling'
   for update;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome,provider_error_code
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_command_id,next_attempt_number,
    'detail_lookup','ambiguous',p_reason_code
  );
  update argus_private.reconciliation_records record
     set status='pending',next_attempt_at=pg_catalog.now()+interval '30 seconds',
         last_error_code=p_reason_code,updated_at=pg_catalog.now()
   where record.command_id=p_command_id;
end
$$;

create or replace function argus_private.record_provider_order_reconciliation(
  p_command_id uuid,p_resolution text,p_order_id uuid,p_state text,
  p_filled_quantity numeric,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_reference_ciphertext bytea,p_reference_hash text,p_key_version integer,
  p_instrument_id uuid
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare command_row argus_private.provider_commands%rowtype;
declare next_attempt_number integer;
declare retained_provider_environment text;
declare request_user_id uuid;
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
begin
  select context.user_id,context.tenant_id,context.lifecycle_id
    into request_user_id,request_tenant_id,request_lifecycle_id
    from argus_private.read_trusted_request_context() context;
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id
     and command.user_id=request_user_id
     and command.tenant_id=request_tenant_id
     and command.lifecycle_id=request_lifecycle_id;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  perform argus_private.lock_brokerage_scope(
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.connection_id,command_row.account_id
  );
  select command.* into command_row
    from argus_private.provider_commands command
   where command.id=p_command_id and command.state='reconciling'
   for update;
  if command_row.id is null
     or p_resolution not in (
       'applied','authoritative_not_applied','superseded_by_fill'
     )
     or (command_row.operation='place' and p_resolution<>'applied')
     or (command_row.operation in ('modify','cancel')
         and command_row.target_order_id<>p_order_id)
     or (p_resolution='superseded_by_fill'
         and (command_row.operation not in ('modify','cancel')
              or p_state<>'filled'))
     or (command_row.operation='cancel' and p_resolution='applied'
         and p_state<>'cancelled')
     or (command_row.target_order_id is not null
         and command_row.target_order_id<>p_order_id)
     or not exists (
       select 1 from argus_private.webull_asset_mappings asset
        where asset.tenant_id=command_row.tenant_id
          and asset.lifecycle_id=command_row.lifecycle_id
          and asset.user_id=command_row.user_id
          and asset.connection_id=command_row.connection_id
          and asset.account_id=command_row.account_id
          and asset.instrument_id=p_instrument_id
          and asset.asset_kind in ('equity','etf')
     ) then
    raise exception 'invalid_reconciliation_detail';
  end if;
  select credential.provider_environment into retained_provider_environment
    from argus_private.webull_credentials credential
   where credential.tenant_id=command_row.tenant_id
     and credential.lifecycle_id=command_row.lifecycle_id
     and credential.connection_id=command_row.connection_id
     and credential.user_id=command_row.user_id;
  insert into argus_private.webull_order_mappings(
    tenant_id,lifecycle_id,order_id,account_id,connection_id,user_id,
    deletion_epoch,provider_environment,provider_order_ref_ciphertext,
    provider_order_ref_hash,key_version
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,p_order_id,
    command_row.account_id,command_row.connection_id,command_row.user_id,
    command_row.deletion_epoch,retained_provider_environment,
    p_reference_ciphertext,p_reference_hash,p_key_version
  ) on conflict (order_id) do nothing;
  if not exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.tenant_id=command_row.tenant_id
       and mapping.lifecycle_id=command_row.lifecycle_id
       and mapping.order_id=p_order_id
       and mapping.user_id=command_row.user_id
       and mapping.account_id=command_row.account_id
       and mapping.provider_order_ref_hash=p_reference_hash
  ) then raise exception 'provider_order_mapping_conflict'; end if;
  perform argus_private.append_order_projection(
    command_row.user_id,command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_order_id,p_state,p_filled_quantity,'detail',
    p_payload,p_provider_observed_at,p_fetched_at,null
  );
  select coalesce(pg_catalog.max(attempt.attempt_number),0)+1
    into next_attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
    command_id,attempt_number,attempt_kind,outcome,provider_error_code
  ) values (
    command_row.tenant_id,command_row.lifecycle_id,command_row.user_id,
    command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_command_id,next_attempt_number,'detail_lookup',
    case when p_resolution='applied' then 'accepted'
         else 'terminal_failure' end,p_resolution
  );
  update argus_private.provider_commands command
     set state='resolved',provider_order_ref_hash=p_reference_hash,
         order_id=p_order_id,updated_at=pg_catalog.now()
   where command.id=p_command_id;
  update argus_private.reconciliation_records record
     set status='resolved',
         last_error_code=case when p_resolution='applied' then null
                              else p_resolution end,
         updated_at=pg_catalog.now()
   where record.command_id=p_command_id;
end
$$;

create or replace function argus_private.read_brokerage_projection_payload(
  p_generation_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path=''
as $$
  select case generation.resource_type
    when 'balance' then (
      select pg_catalog.jsonb_build_object(
        'currency',fact.currency,'cash',fact.cash::text,
        'buying_power',fact.buying_power::text,
        'market_value',fact.market_value::text,
        'total_equity',fact.total_equity::text
      )
      from argus_brokerage.projection_balance_facts fact
      where fact.tenant_id=generation.tenant_id
        and fact.lifecycle_id=generation.lifecycle_id
        and fact.generation_id=generation.id
    )
    when 'positions' then coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'asset',pg_catalog.jsonb_build_object(
            'instrument_id',fact.instrument_id,'symbol',fact.symbol,
            'name',fact.display_name,'asset_kind',fact.asset_kind,
            'provider_asset_kind',fact.provider_asset_kind,
            'supported',fact.supported,'currency',fact.currency,
            'exchange',fact.exchange,'market_timezone',fact.market_timezone
          ),
          'quantity',fact.quantity::text,
          'available_quantity',fact.available_quantity::text,
          'average_cost',fact.average_cost::text,
          'market_value',fact.market_value::text,'currency',fact.currency
        ) order by fact.ordinal
      )
      from argus_brokerage.projection_position_facts fact
      where fact.tenant_id=generation.tenant_id
        and fact.lifecycle_id=generation.lifecycle_id
        and fact.generation_id=generation.id
    ),'[]'::jsonb)
    when 'restrictions' then coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'restriction',fact.restriction_code,
          'provider_code',fact.provider_code,'active',fact.active,
          'detail',fact.detail
        ) order by fact.ordinal
      )
      from argus_brokerage.projection_restriction_facts fact
      where fact.tenant_id=generation.tenant_id
        and fact.lifecycle_id=generation.lifecycle_id
        and fact.generation_id=generation.id
    ),'[]'::jsonb)
    when 'account' then (
      select pg_catalog.jsonb_build_object(
        'display_label',fact.display_label,
        'base_currency',fact.base_currency,
        'market_timezone',fact.market_timezone,
        'status',fact.account_status,
        'capability_version',fact.capability_version,
        'capabilities',coalesce((
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'capability',case capability.capability_code
                when 'balances_read' then 'balances_read'
                when 'positions_read' then 'positions_read'
                when 'orders_read' then 'orders_read'
                when 'manual_orders' then 'manual_orders'
                else 'unsupported' end,
              'provider_code',capability.provider_code,
              'available',capability.available
            ) order by capability.provider_code
          )
          from argus_brokerage.account_capabilities capability
          where capability.tenant_id=fact.tenant_id
            and capability.lifecycle_id=fact.lifecycle_id
            and capability.account_id=fact.account_id
            and capability.capability_version=fact.capability_version
        ),'[]'::jsonb)
      )
      from argus_brokerage.projection_account_facts fact
      where fact.tenant_id=generation.tenant_id
        and fact.lifecycle_id=generation.lifecycle_id
        and fact.generation_id=generation.id
    )
    else null
  end
  from argus_brokerage.projection_generations generation
  where generation.id=p_generation_id and generation.normalization_state='ready'
$$;

create or replace function argus_private.read_brokerage_order_payload(
  p_generation_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'id',generation.order_id,'instrument_id',generation.instrument_id,
    'symbol',generation.symbol,'side',generation.side,
    'provider_side',generation.provider_side,
    'order_type',generation.order_type,
    'provider_order_type',generation.provider_order_type,
    'time_in_force',generation.time_in_force,
    'provider_time_in_force',generation.provider_time_in_force,
    'quantity',generation.quantity::text,
    'filled_quantity',generation.filled_quantity::text,
    'limit_price',generation.limit_price::text,
    'stop_price',generation.stop_price::text,
    'average_fill_price',generation.average_fill_price::text,
    'currency',generation.currency,'state',generation.state,
    'provider_state',generation.provider_state,
    'terminal',generation.terminal
  )
  from argus_brokerage.order_projection_generations generation
  where generation.id=p_generation_id and generation.normalization_state='ready'
$$;

-- Member projection writes cross named short definer transactions. Every
-- path takes lifecycle -> connection -> account before a lease, mapping, or
-- generation row, so reconnect/disconnect cannot be followed by a stale write.
create or replace function argus_private.acquire_brokerage_projection_lease(
  p_account_id uuid,p_connection_id uuid,p_deletion_epoch bigint,
  p_resource_type text,p_lease_token uuid,p_leased_until timestamptz
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  if request_tenant_id is null or request_lifecycle_id is null
     or request_user_id is null or p_resource_type not in (
       'account','balance','positions','restrictions'
     ) or p_leased_until<=pg_catalog.clock_timestamp() then
    raise exception 'refresh_fenced' using errcode='42501';
  end if;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    p_connection_id,p_account_id
  );
  if not exists (
    select 1 from argus_brokerage.accounts account
    join argus_brokerage.connections connection
      on connection.tenant_id=account.tenant_id
     and connection.lifecycle_id=account.lifecycle_id
     and connection.user_id=account.user_id
     and connection.id=account.connection_id
    where account.tenant_id=request_tenant_id
      and account.lifecycle_id=request_lifecycle_id
      and account.user_id=request_user_id and account.id=p_account_id
      and account.connection_id=p_connection_id
      and account.deletion_epoch=p_deletion_epoch
      and connection.status='connected'
  ) then
    return false;
  end if;
  insert into argus_private.projection_refresh_leases(
    tenant_id,lifecycle_id,account_id,connection_id,user_id,deletion_epoch,
    resource_type,lease_token,leased_until
  ) values (
    request_tenant_id,request_lifecycle_id,p_account_id,p_connection_id,
    request_user_id,p_deletion_epoch,p_resource_type,p_lease_token,p_leased_until
  )
  on conflict (account_id,resource_type) do update
    set connection_id=excluded.connection_id,user_id=excluded.user_id,
        deletion_epoch=excluded.deletion_epoch,lease_token=excluded.lease_token,
        leased_until=excluded.leased_until,acquired_at=pg_catalog.clock_timestamp()
  where projection_refresh_leases.leased_until<=pg_catalog.clock_timestamp()
    and projection_refresh_leases.tenant_id=excluded.tenant_id
    and projection_refresh_leases.lifecycle_id=excluded.lifecycle_id
    and projection_refresh_leases.connection_id=excluded.connection_id
    and projection_refresh_leases.user_id=excluded.user_id;
  return found;
end
$$;

create or replace function argus_private.release_brokerage_projection_lease(
  p_account_id uuid,p_resource_type text,p_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
declare retained_connection_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  select account.connection_id into retained_connection_id
    from argus_brokerage.accounts account
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=request_user_id and account.id=p_account_id;
  if retained_connection_id is null then return false; end if;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    retained_connection_id,p_account_id
  );
  delete from argus_private.projection_refresh_leases lease
   where lease.tenant_id=request_tenant_id
     and lease.lifecycle_id=request_lifecycle_id
     and lease.user_id=request_user_id and lease.account_id=p_account_id
     and lease.resource_type=p_resource_type
     and lease.lease_token=p_lease_token;
  return found;
end
$$;

create or replace function argus_private.append_brokerage_projection_generation(
  p_account_id uuid,p_connection_id uuid,p_deletion_epoch bigint,
  p_resource_type text,p_lease_token uuid,p_payload jsonb,
  p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_expires_at timestamptz,p_availability text,p_reason_code text,
  p_purge_after timestamptz
)
returns table(
  result_id uuid,result_generation bigint,result_resource_type text,
  result_provider_observed_at timestamptz,result_fetched_at timestamptz,
  result_expires_at timestamptz,result_availability text,result_reason_code text,
  result_normalization_state text
)
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
declare next_generation bigint;
declare retained_sqlstate text;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    p_connection_id,p_account_id
  );
  perform 1 from argus_private.projection_refresh_leases lease
   where lease.tenant_id=request_tenant_id
     and lease.lifecycle_id=request_lifecycle_id
     and lease.user_id=request_user_id and lease.account_id=p_account_id
     and lease.connection_id=p_connection_id
     and lease.deletion_epoch=p_deletion_epoch
     and lease.resource_type=p_resource_type
     and lease.lease_token=p_lease_token
     and lease.leased_until>pg_catalog.clock_timestamp()
   for update;
  if not found or not exists (
    select 1 from argus_brokerage.connections connection
    join argus_brokerage.accounts account
      on account.tenant_id=connection.tenant_id
     and account.lifecycle_id=connection.lifecycle_id
     and account.user_id=connection.user_id
     and account.connection_id=connection.id
    where connection.tenant_id=request_tenant_id
      and connection.lifecycle_id=request_lifecycle_id
      and connection.user_id=request_user_id and connection.id=p_connection_id
      and connection.status='connected' and account.id=p_account_id
      and account.deletion_epoch=p_deletion_epoch
  ) then
    raise exception 'refresh_fenced' using errcode='42501';
  end if;
  select coalesce(pg_catalog.max(generation.generation),0)+1
    into next_generation
    from argus_brokerage.projection_generations generation
   where generation.tenant_id=request_tenant_id
     and generation.lifecycle_id=request_lifecycle_id
     and generation.account_id=p_account_id
     and generation.resource_type=p_resource_type;
  begin
    return query
    insert into argus_brokerage.projection_generations(
      tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
      resource_type,generation,normalized_payload,provider_observed_at,fetched_at,
      expires_at,availability,reason_code,purge_after
    ) values (
      request_tenant_id,request_lifecycle_id,request_user_id,p_deletion_epoch,
      p_connection_id,p_account_id,p_resource_type,next_generation,p_payload,
      p_provider_observed_at,p_fetched_at,p_expires_at,p_availability,
      p_reason_code,p_purge_after
    ) returning projection_generations.id,projection_generations.generation,
        projection_generations.resource_type,
        projection_generations.provider_observed_at,
        projection_generations.fetched_at,projection_generations.expires_at,
        projection_generations.availability,projection_generations.reason_code,
        projection_generations.normalization_state;
  exception when data_exception or integrity_constraint_violation then
    get stacked diagnostics retained_sqlstate=returned_sqlstate;
    return query
    insert into argus_brokerage.projection_generations(
      tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
      resource_type,generation,normalized_payload,provider_observed_at,fetched_at,
      expires_at,availability,reason_code,purge_after,normalization_state
    ) values (
      request_tenant_id,request_lifecycle_id,request_user_id,p_deletion_epoch,
      p_connection_id,p_account_id,p_resource_type,next_generation,p_payload,
      p_provider_observed_at,p_fetched_at,p_expires_at,'unavailable',
      'provider_schema_unrecognized',p_purge_after,'quarantined'
    ) returning projection_generations.id,projection_generations.generation,
        projection_generations.resource_type,
        projection_generations.provider_observed_at,
        projection_generations.fetched_at,projection_generations.expires_at,
        projection_generations.availability,projection_generations.reason_code,
        projection_generations.normalization_state;
    insert into argus_private.brokerage_normalization_quarantine(
      source_relation,source_identity,reason_code,diagnostic_sqlstate,source_hash
    )
    select 'argus_brokerage.projection_generations',generation.id::text,
           'provider_schema_unrecognized',retained_sqlstate,snapshot.snapshot_hash
      from argus_brokerage.projection_generations generation
      join argus_private.projection_generation_snapshots snapshot
        on snapshot.tenant_id=generation.tenant_id
       and snapshot.lifecycle_id=generation.lifecycle_id
       and snapshot.generation_id=generation.id
     where generation.tenant_id=request_tenant_id
       and generation.lifecycle_id=request_lifecycle_id
       and generation.account_id=p_account_id
       and generation.resource_type=p_resource_type
       and generation.generation=next_generation;
  end;
end
$$;

create or replace function argus_private.resolve_webull_asset_mapping_scoped(
  p_instrument_id uuid,p_account_id uuid,p_connection_id uuid,
  p_deletion_epoch bigint,p_provider_environment text,
  p_provider_asset_id_ciphertext bytea,p_provider_asset_id_hash text,
  p_key_version integer,p_asset_kind text,p_provider_asset_kind text
)
returns table(result_instrument_id uuid,result_key_version integer)
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    p_connection_id,p_account_id
  );
  if not exists (
    select 1 from argus_brokerage.connections connection
    join argus_brokerage.accounts account
      on account.tenant_id=connection.tenant_id
     and account.lifecycle_id=connection.lifecycle_id
     and account.user_id=connection.user_id
     and account.connection_id=connection.id
    where connection.tenant_id=request_tenant_id
      and connection.lifecycle_id=request_lifecycle_id
      and connection.user_id=request_user_id and connection.id=p_connection_id
      and connection.status='connected' and account.id=p_account_id
      and account.deletion_epoch=p_deletion_epoch
  ) then
    raise exception 'refresh_fenced' using errcode='42501';
  end if;
  insert into argus_private.webull_asset_mappings(
    tenant_id,lifecycle_id,instrument_id,account_id,connection_id,user_id,
    deletion_epoch,provider_environment,provider_asset_id_ciphertext,
    provider_asset_id_hash,key_version,asset_kind,provider_asset_kind
  ) values (
    request_tenant_id,request_lifecycle_id,p_instrument_id,p_account_id,
    p_connection_id,request_user_id,p_deletion_epoch,p_provider_environment,
    p_provider_asset_id_ciphertext,p_provider_asset_id_hash,p_key_version,
    p_asset_kind,p_provider_asset_kind
  ) on conflict (user_id,account_id,provider_asset_id_hash) do update
    set asset_kind=excluded.asset_kind,
        provider_asset_kind=excluded.provider_asset_kind
  where webull_asset_mappings.asset_kind='unsupported'
    and webull_asset_mappings.provider_asset_kind='LEGACY_UNKNOWN';
  return query
  select mapping.instrument_id,mapping.key_version
    from argus_private.webull_asset_mappings mapping
   where mapping.tenant_id=request_tenant_id
     and mapping.lifecycle_id=request_lifecycle_id
     and mapping.user_id=request_user_id and mapping.account_id=p_account_id
     and mapping.connection_id=p_connection_id
     and mapping.deletion_epoch=p_deletion_epoch
     and mapping.provider_environment=p_provider_environment
     and mapping.provider_asset_id_hash=p_provider_asset_id_hash;
end
$$;

create or replace function argus_private.invalidate_brokerage_account_scoped(
  p_account_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
declare retained_connection_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  select account.connection_id into retained_connection_id
    from argus_brokerage.accounts account
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=request_user_id and account.id=p_account_id;
  if retained_connection_id is null then return null; end if;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,
    retained_connection_id,p_account_id
  );
  update argus_brokerage.accounts account
     set status='unavailable',expires_at=pg_catalog.clock_timestamp()
   where account.tenant_id=request_tenant_id
     and account.lifecycle_id=request_lifecycle_id
     and account.user_id=request_user_id and account.id=p_account_id;
  delete from argus_brokerage.active_account_selections selection
   where selection.tenant_id=request_tenant_id
     and selection.lifecycle_id=request_lifecycle_id
     and selection.user_id=request_user_id and selection.account_id=p_account_id;
  return retained_connection_id;
end
$$;

create or replace function argus_private.require_brokerage_reauthorization_scoped(
  p_connection_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare request_tenant_id uuid;
declare request_lifecycle_id uuid;
declare request_user_id uuid;
begin
  select context.tenant_id,context.lifecycle_id,context.user_id
    into request_tenant_id,request_lifecycle_id,request_user_id
    from argus_private.read_trusted_request_context() context;
  perform argus_private.lock_brokerage_scope(
    request_tenant_id,request_lifecycle_id,request_user_id,p_connection_id,null
  );
  update argus_brokerage.connections connection
     set status='reauthorization_required',
         last_error_code='provider_authorization_invalid',
         updated_at=pg_catalog.clock_timestamp()
   where connection.tenant_id=request_tenant_id
     and connection.lifecycle_id=request_lifecycle_id
     and connection.user_id=request_user_id and connection.id=p_connection_id;
  if not found then return false; end if;
  delete from argus_brokerage.active_account_selections selection
   where selection.tenant_id=request_tenant_id
     and selection.lifecycle_id=request_lifecycle_id
     and selection.user_id=request_user_id
     and selection.connection_id=p_connection_id;
  return true;
end
$$;

create or replace function argus_private.get_brokerage_normalization_summary()
returns table(
  source_relation text,reason_code text,diagnostic_sqlstate text,
  quarantined_count bigint,oldest_at timestamptz,newest_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not argus_private.has_staff_permission('brokerage:data_quality') then
    raise exception 'staff_permission_required' using errcode='42501';
  end if;
  return query
  select quarantine.source_relation,quarantine.reason_code,
         quarantine.diagnostic_sqlstate,pg_catalog.count(*)::bigint,
         pg_catalog.min(quarantine.quarantined_at),
         pg_catalog.max(quarantine.quarantined_at)
    from argus_private.brokerage_normalization_quarantine quarantine
   group by quarantine.source_relation,quarantine.reason_code,
            quarantine.diagnostic_sqlstate
   order by quarantine.source_relation,quarantine.reason_code,
            quarantine.diagnostic_sqlstate;
end
$$;

-- Deletion fencing must succeed even when a durable command retains its audit
-- account. Destroy reusable credential/account envelopes immediately, retain
-- only command-dependent parents as unavailable, and leave final erasure to
-- the storage-gated brokerage purge phase below.
create or replace function argus_private.fence_webull_member_for_deletion(
  p_tombstone_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  tombstone argus_private.deletion_tombstones%rowtype;
  retained_tenant_id uuid;
  retained_lifecycle_id uuid;
begin
  select target.* into tombstone
    from argus_private.deletion_tombstones target
   where target.id=p_tombstone_id
   for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;
  if tombstone.webull_credentials_destroyed_at is not null then return true; end if;

  select member.tenant_id,member.lifecycle_id
    into retained_tenant_id,retained_lifecycle_id
    from argus_app.members member
   where member.user_id=tombstone.user_id
     and member.deletion_epoch=tombstone.deletion_epoch
     and member.status in ('deletion_pending','purging');
  if retained_lifecycle_id is null then
    raise exception 'deletion_epoch_changed';
  end if;
  if not argus_private.lock_open_member_lifecycle(
    retained_tenant_id,retained_lifecycle_id,tombstone.user_id
  ) then
    raise exception 'deletion_lifecycle_closed' using errcode='23514';
  end if;

  perform connection.id
    from argus_brokerage.connections connection
   where connection.tenant_id=retained_tenant_id
     and connection.lifecycle_id=retained_lifecycle_id
     and connection.user_id=tombstone.user_id
   order by connection.id
   for update;
  perform account.id
    from argus_brokerage.accounts account
   where account.tenant_id=retained_tenant_id
     and account.lifecycle_id=retained_lifecycle_id
     and account.user_id=tombstone.user_id
   order by account.connection_id,account.id
   for update;

  update argus_brokerage.connections connection
     set status='disconnected',
         egress_fenced_at=pg_catalog.clock_timestamp(),
         disconnected_at=pg_catalog.clock_timestamp(),
         last_error_code=null,updated_at=pg_catalog.clock_timestamp()
   where connection.tenant_id=retained_tenant_id
     and connection.lifecycle_id=retained_lifecycle_id
     and connection.user_id=tombstone.user_id
     and connection.status<>'disconnected';

  update argus_private.job_runs run
     set status='cancelled',lease_token=null,leased_until=null,
         last_error_code='member_deleted',updated_at=pg_catalog.clock_timestamp()
   where run.source_event_id in (
     select event.id from argus_private.outbox_events event
      where event.user_id=tombstone.user_id
        and event.topic in ('brokerage_refresh','brokerage_reconcile')
   ) and run.status not in ('succeeded','dead_lettered','cancelled');
  delete from argus_private.outbox_events event
   where event.user_id=tombstone.user_id
     and event.topic in ('brokerage_refresh','brokerage_reconcile');
  update argus_private.oauth_states state
     set consumed_at=coalesce(
       state.consumed_at,pg_catalog.clock_timestamp()
     )
   where state.tenant_id=retained_tenant_id
     and state.lifecycle_id=retained_lifecycle_id
     and state.user_id=tombstone.user_id;
  delete from argus_private.webull_completion_handles handle
   where handle.tenant_id=retained_tenant_id
     and handle.lifecycle_id=retained_lifecycle_id
     and handle.user_id=tombstone.user_id;
  delete from argus_private.refresh_leases lease
   where lease.tenant_id=retained_tenant_id
     and lease.lifecycle_id=retained_lifecycle_id
     and lease.user_id=tombstone.user_id;
  delete from argus_private.projection_refresh_leases lease
   where lease.tenant_id=retained_tenant_id
     and lease.lifecycle_id=retained_lifecycle_id
     and lease.user_id=tombstone.user_id;
  delete from argus_private.webull_credentials credential
   where credential.tenant_id=retained_tenant_id
     and credential.lifecycle_id=retained_lifecycle_id
     and credential.user_id=tombstone.user_id;
  delete from argus_private.webull_account_mappings mapping
   where mapping.tenant_id=retained_tenant_id
     and mapping.lifecycle_id=retained_lifecycle_id
     and mapping.user_id=tombstone.user_id;
  delete from argus_brokerage.active_account_selections selection
   where selection.tenant_id=retained_tenant_id
     and selection.lifecycle_id=retained_lifecycle_id
     and selection.user_id=tombstone.user_id;
  delete from argus_brokerage.accounts account
   where account.tenant_id=retained_tenant_id
     and account.lifecycle_id=retained_lifecycle_id
     and account.user_id=tombstone.user_id
     and not exists (
       select 1 from argus_private.provider_commands command
        where command.tenant_id=account.tenant_id
          and command.lifecycle_id=account.lifecycle_id
          and command.user_id=account.user_id
          and command.connection_id=account.connection_id
          and command.account_id=account.id
     );
  update argus_brokerage.accounts account
     set status='unavailable',expires_at=pg_catalog.clock_timestamp()
   where account.tenant_id=retained_tenant_id
     and account.lifecycle_id=retained_lifecycle_id
     and account.user_id=tombstone.user_id;
  delete from argus_private.oauth_states state
   where state.tenant_id=retained_tenant_id
     and state.lifecycle_id=retained_lifecycle_id
     and state.user_id=tombstone.user_id;

  update argus_private.deletion_tombstones target
     set webull_fenced_at=coalesce(
           target.webull_fenced_at,pg_catalog.clock_timestamp()
         ),
         webull_credentials_destroyed_at=coalesce(
           target.webull_credentials_destroyed_at,pg_catalog.clock_timestamp()
         )
   where target.id=tombstone.id;
  return true;
end
$$;

-- Privacy purge is the only supported deletion path for immutable brokerage
-- attempts. UPDATE remains impossible, and no request/worker role receives a
-- DELETE capability; the tombstone-scoped owner policy below is the sole
-- exception.
drop trigger provider_command_attempts_immutable
  on argus_private.provider_command_attempts;
create trigger provider_command_attempts_immutable
  before update on argus_private.provider_command_attempts
  for each row execute function argus_private.reject_immutable_change();

-- The retained privacy orchestrator does not own brokerage relations. This
-- narrow phase validates the exact deletion incarnation, shares the common
-- lifecycle -> connection -> account lock order, and then removes children,
-- commands, and the connection root in deterministic order. Provider egress
-- has already been fenced by prepare_member_purge; this routine never sends or
-- retries a provider command.
create or replace function argus_private.purge_member_brokerage_data(
  p_tombstone_id uuid
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  retained_tenant_id uuid;
  retained_lifecycle_id uuid;
  retained_user_id uuid;
  affected integer;
  purged_tables integer:=0;
begin
  select member.tenant_id,member.lifecycle_id,member.user_id
    into retained_tenant_id,retained_lifecycle_id,retained_user_id
    from argus_private.deletion_tombstones tombstone
    join argus_app.members member
      on member.user_id=tombstone.user_id
     and member.deletion_epoch=tombstone.deletion_epoch
     and member.status='purging'
    join argus_app.member_lifecycles lifecycle
      on lifecycle.tenant_id=member.tenant_id
     and lifecycle.id=member.lifecycle_id
     and lifecycle.identity_subject_id=member.user_id
     and lifecycle.state='open'
   where tombstone.id=p_tombstone_id
     and tombstone.status='purging'
     and tombstone.purge_phase='storage_purged'
   for share of tombstone;

  if retained_user_id is null then
    raise exception 'brokerage_purge_scope_invalid' using errcode='23514';
  end if;
  if not argus_private.lock_open_member_lifecycle(
    retained_tenant_id,retained_lifecycle_id,retained_user_id
  ) then
    raise exception 'brokerage_purge_lifecycle_closed' using errcode='23514';
  end if;

  perform connection.id
    from argus_brokerage.connections connection
   where connection.tenant_id=retained_tenant_id
     and connection.lifecycle_id=retained_lifecycle_id
     and connection.user_id=retained_user_id
   order by connection.id
   for update;
  perform account.id
    from argus_brokerage.accounts account
   where account.tenant_id=retained_tenant_id
     and account.lifecycle_id=retained_lifecycle_id
     and account.user_id=retained_user_id
   order by account.connection_id,account.id
   for update;

  delete from argus_private.reconciliation_records record
   where record.tenant_id=retained_tenant_id
     and record.lifecycle_id=retained_lifecycle_id
     and record.user_id=retained_user_id;
  get diagnostics affected=row_count;
  if affected>0 then purged_tables:=purged_tables+1; end if;

  delete from argus_private.provider_command_attempts attempt
   where attempt.tenant_id=retained_tenant_id
     and attempt.lifecycle_id=retained_lifecycle_id
     and attempt.user_id=retained_user_id;
  get diagnostics affected=row_count;
  if affected>0 then purged_tables:=purged_tables+1; end if;

  delete from argus_private.provider_commands command
   where command.tenant_id=retained_tenant_id
     and command.lifecycle_id=retained_lifecycle_id
     and command.user_id=retained_user_id;
  get diagnostics affected=row_count;
  if affected>0 then purged_tables:=purged_tables+1; end if;

  delete from argus_brokerage.connections connection
   where connection.tenant_id=retained_tenant_id
     and connection.lifecycle_id=retained_lifecycle_id
     and connection.user_id=retained_user_id;
  get diagnostics affected=row_count;
  if affected>0 then purged_tables:=purged_tables+1; end if;

  return purged_tables;
end
$$;

-- Replace the legacy generic purge loop so it delegates U5 state to the
-- brokerage owner and never requires postgres table DML on brokerage-owned
-- relations. The explicit private-table exclusion is intentionally an
-- inventory: a future brokerage relation must extend the named purge phase.
create or replace function argus_private.purge_member_argus_data(
  p_tombstone_id uuid
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  tombstone argus_private.deletion_tombstones%rowtype;
  table_record record;
  purged_tables integer:=0;
  affected integer;
begin
  select target.* into tombstone
    from argus_private.deletion_tombstones target
   where target.id=p_tombstone_id
     and target.status='purging'
     and target.purge_phase in ('storage_purged','data_purged')
   for update;
  if tombstone.id is null then raise exception 'tombstone_missing'; end if;

  if tombstone.purge_phase='storage_purged' then
    purged_tables:=purged_tables+
      argus_private.purge_member_brokerage_data(tombstone.id);

    delete from argus_app.moderation_cases moderation
     using argus_app.content_reports report
     where moderation.report_id=report.id
       and report.user_id=tombstone.user_id;
    if found then purged_tables:=purged_tables+1; end if;

    delete from argus_app.media_assets asset
     using argus_private.media_upload_intents intent
     where intent.user_id=tombstone.user_id
       and asset.storage_bucket=intent.bucket_id
       and asset.storage_path=intent.object_path;
    if found then purged_tables:=purged_tables+1; end if;

    for table_record in
      select namespace.nspname schema_name,relation.relname table_name
        from pg_catalog.pg_class relation
        join pg_catalog.pg_namespace namespace
          on namespace.oid=relation.relnamespace
        join pg_catalog.pg_attribute attribute
          on attribute.attrelid=relation.oid
         and attribute.attname='user_id'
         and not attribute.attisdropped
       where namespace.nspname='argus_app'
         and relation.relkind='r'
         and relation.relname<>'members'
    loop
      execute pg_catalog.format(
        'delete from %I.%I where user_id=$1',
        table_record.schema_name,table_record.table_name
      ) using tombstone.user_id;
      get diagnostics affected=row_count;
      if affected>0 then purged_tables:=purged_tables+1; end if;
    end loop;

    for table_record in
      select namespace.nspname schema_name,relation.relname table_name
        from pg_catalog.pg_class relation
        join pg_catalog.pg_namespace namespace
          on namespace.oid=relation.relnamespace
        join pg_catalog.pg_attribute attribute
          on attribute.attrelid=relation.oid
         and attribute.attname='user_id'
         and not attribute.attisdropped
       where namespace.nspname='argus_private'
         and relation.relkind='r'
         and relation.relname not in (
           'deletion_tombstones','deletion_restore_checkpoints',
           'projection_generation_snapshots',
           'order_projection_generation_snapshots','oauth_states',
           'webull_completion_handles','webull_credentials',
           'webull_account_mappings','refresh_leases',
           'projection_refresh_leases','webull_asset_mappings',
           'order_previews','provider_commands','provider_command_attempts',
           'reconciliation_records','webull_order_mappings'
         )
    loop
      execute pg_catalog.format(
        'delete from %I.%I where user_id=$1',
        table_record.schema_name,table_record.table_name
      ) using tombstone.user_id;
      get diagnostics affected=row_count;
      if affected>0 then purged_tables:=purged_tables+1; end if;
    end loop;

    delete from argus_private.admin_audit_events audit
     where audit.actor_user_id=tombstone.user_id;
    if found then purged_tables:=purged_tables+1; end if;

    update argus_private.deletion_tombstones target
       set purge_phase='data_purged',purged_tables_count=purged_tables
     where target.id=tombstone.id;
  end if;
  return purged_tables;
end
$$;

-- Replace legacy runtime-wide policies with explicit lifecycle-scoped
-- capability roles. The owner role is NOLOGIN and reachable only through the
-- routines granted below.
grant argus_callback to argus_edge;
grant usage on schema argus_app,argus_brokerage,argus_private
  to argus_member,argus_callback,argus_staff,argus_worker;
grant select on argus_app.members,argus_app.member_lifecycles
  to argus_callback;
grant execute on function
  argus_private.read_trusted_request_context(),
  argus_private.trusted_request_user_id(),
  argus_private.trusted_request_tenant_id(),
  argus_private.trusted_request_lifecycle_id()
to argus_callback;

grant select on argus_app.members to argus_brokerage_owner;
grant select,update on argus_private.deletion_tombstones
  to argus_brokerage_owner;
grant select on argus_private.kill_switches to argus_brokerage_owner;
grant select,insert,delete on argus_private.outbox_events to argus_brokerage_owner;
grant select,update on argus_private.job_runs to argus_brokerage_owner;
grant select,update on argus_private.step_up_receipts to argus_brokerage_owner;
grant execute on function argus_private.assert_worker_event_current(uuid)
  to argus_brokerage_owner;
grant execute on function argus_private.has_staff_permission(text)
  to argus_brokerage_owner;

create policy u5_brokerage_owner_member_read on argus_app.members
  for select to argus_brokerage_owner
  using (status in ('active','deletion_pending','purging'));
create policy u5_brokerage_owner_tombstone_read
  on argus_private.deletion_tombstones
  for select to argus_brokerage_owner using (true);
create policy u5_brokerage_owner_tombstone_update
  on argus_private.deletion_tombstones
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_brokerage_owner_kill_switch_read
  on argus_private.kill_switches
  for select to argus_brokerage_owner using (true);
create policy u5_brokerage_owner_outbox_read on argus_private.outbox_events
  for select to argus_brokerage_owner using (true);
create policy u5_brokerage_owner_outbox_delete on argus_private.outbox_events
  for delete to argus_brokerage_owner using (true);
create policy u5_brokerage_owner_outbox_insert on argus_private.outbox_events
  for insert to argus_brokerage_owner with check (true);
create policy u5_brokerage_owner_job_read on argus_private.job_runs
  for select to argus_brokerage_owner using (true);
create policy u5_brokerage_owner_job_update on argus_private.job_runs
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_brokerage_owner_receipt_read
  on argus_private.step_up_receipts
  for select to argus_brokerage_owner using (true);
create policy u5_brokerage_owner_receipt_update
  on argus_private.step_up_receipts
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_callback_member_read on argus_app.members
  for select to argus_callback using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and lifecycle_id=(select argus_private.trusted_request_lifecycle_id())
    and user_id=(select argus_private.trusted_request_user_id())
    and status='active'
  );
create policy u5_callback_lifecycle_read on argus_app.member_lifecycles
  for select to argus_callback using (
    tenant_id=(select argus_private.trusted_request_tenant_id())
    and id=(select argus_private.trusted_request_lifecycle_id())
    and identity_subject_id=(select argus_private.trusted_request_user_id())
    and state='open'
  );

do $$
declare relation_record record;
declare policy_record record;
begin
  for relation_record in
    select * from (values
      ('argus_brokerage','connections'),
      ('argus_brokerage','accounts'),
      ('argus_brokerage','active_account_selections'),
      ('argus_brokerage','projection_generations'),
      ('argus_brokerage','order_projection_generations'),
      ('argus_brokerage','account_capabilities'),
      ('argus_brokerage','projection_balance_facts'),
      ('argus_brokerage','projection_position_facts'),
      ('argus_brokerage','projection_restriction_facts'),
      ('argus_brokerage','projection_account_facts'),
      ('argus_private','projection_generation_snapshots'),
      ('argus_private','order_projection_generation_snapshots'),
      ('argus_private','oauth_states'),
      ('argus_private','webull_completion_handles'),
      ('argus_private','webull_credentials'),
      ('argus_private','webull_account_mappings'),
      ('argus_private','refresh_leases'),
      ('argus_private','projection_refresh_leases'),
      ('argus_private','webull_asset_mappings'),
      ('argus_private','order_previews'),
      ('argus_private','provider_commands'),
      ('argus_private','provider_command_attempts'),
      ('argus_private','reconciliation_records'),
      ('argus_private','webull_order_mappings'),
      ('argus_private','brokerage_normalization_quarantine')
    ) as relation_rows(schema_name,relation_name)
  loop
    for policy_record in
      select policy.policyname
        from pg_catalog.pg_policies policy
       where policy.schemaname=relation_record.schema_name
         and policy.tablename=relation_record.relation_name
    loop
      execute pg_catalog.format(
        'drop policy %I on %I.%I',policy_record.policyname,
        relation_record.schema_name,relation_record.relation_name
      );
    end loop;
    execute pg_catalog.format(
      'alter table %I.%I enable row level security',
      relation_record.schema_name,relation_record.relation_name
    );
    execute pg_catalog.format(
      'alter table %I.%I force row level security',
      relation_record.schema_name,relation_record.relation_name
    );
  end loop;
end
$$;

-- Exact NOLOGIN owner matrix. Each permissive action is required by a named
-- SECURITY DEFINER routine or typed materialization trigger above; those
-- routines validate event/request identity and acquire the common scope lock.
create policy u5_owner_select on argus_brokerage.connections
  for select to argus_brokerage_owner using (true);
create policy u5_owner_update on argus_brokerage.connections
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_privacy_purge_delete on argus_brokerage.connections
  for delete to argus_brokerage_owner using (
    exists (
      select 1
        from argus_private.deletion_tombstones tombstone
        join argus_app.members member
          on member.user_id=tombstone.user_id
         and member.deletion_epoch=tombstone.deletion_epoch
         and member.tenant_id=connections.tenant_id
         and member.lifecycle_id=connections.lifecycle_id
       where tombstone.user_id=connections.user_id
         and tombstone.status='purging'
         and tombstone.purge_phase='storage_purged'
         and member.status='purging'
    )
  );
create policy u5_owner_select on argus_brokerage.accounts
  for select to argus_brokerage_owner using (true);
create policy u5_owner_update on argus_brokerage.accounts
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_delete on argus_brokerage.accounts
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_delete on argus_brokerage.active_account_selections
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_brokerage.projection_generations
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_brokerage.projection_generations
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_select on argus_brokerage.order_projection_generations
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_brokerage.order_projection_generations
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_select on argus_brokerage.account_capabilities
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_brokerage.account_capabilities
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_delete on argus_brokerage.account_capabilities
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_brokerage.projection_balance_facts
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_select on argus_brokerage.projection_balance_facts
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_brokerage.projection_position_facts
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_select on argus_brokerage.projection_position_facts
  for select to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_brokerage.projection_restriction_facts
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_brokerage.projection_restriction_facts
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_insert on argus_brokerage.projection_account_facts
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_select on argus_brokerage.projection_account_facts
  for select to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_private.projection_generation_snapshots
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.projection_generation_snapshots
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_insert
  on argus_private.order_projection_generation_snapshots
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_quarantine_select
  on argus_private.brokerage_normalization_quarantine
  for select to argus_brokerage_owner using (true);
create policy u5_owner_quarantine_insert
  on argus_private.brokerage_normalization_quarantine
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_select on argus_private.oauth_states
  for select to argus_brokerage_owner using (true);
create policy u5_owner_update on argus_private.oauth_states
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_delete on argus_private.oauth_states
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_delete on argus_private.webull_completion_handles
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_private.webull_credentials
  for select to argus_brokerage_owner using (true);
create policy u5_owner_update on argus_private.webull_credentials
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_delete on argus_private.webull_credentials
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_private.webull_account_mappings
  for select to argus_brokerage_owner using (true);
create policy u5_owner_delete on argus_private.webull_account_mappings
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_private.refresh_leases
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.refresh_leases
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_update on argus_private.refresh_leases
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_delete on argus_private.refresh_leases
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_private.projection_refresh_leases
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.projection_refresh_leases
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_update on argus_private.projection_refresh_leases
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_delete on argus_private.projection_refresh_leases
  for delete to argus_brokerage_owner using (true);
create policy u5_owner_select on argus_private.webull_asset_mappings
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.webull_asset_mappings
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_update on argus_private.webull_asset_mappings
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_select on argus_private.order_previews
  for select to argus_brokerage_owner using (true);
create policy u5_owner_update on argus_private.order_previews
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_select on argus_private.provider_commands
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.provider_commands
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_update on argus_private.provider_commands
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_privacy_purge_delete on argus_private.provider_commands
  for delete to argus_brokerage_owner using (
    exists (
      select 1
        from argus_private.deletion_tombstones tombstone
        join argus_app.members member
          on member.user_id=tombstone.user_id
         and member.deletion_epoch=tombstone.deletion_epoch
         and member.tenant_id=provider_commands.tenant_id
         and member.lifecycle_id=provider_commands.lifecycle_id
       where tombstone.user_id=provider_commands.user_id
         and tombstone.status='purging'
         and tombstone.purge_phase='storage_purged'
         and member.status='purging'
    )
  );
create policy u5_owner_select on argus_private.provider_command_attempts
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.provider_command_attempts
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_privacy_purge_delete
  on argus_private.provider_command_attempts
  for delete to argus_brokerage_owner using (
    exists (
      select 1
        from argus_private.deletion_tombstones tombstone
        join argus_app.members member
          on member.user_id=tombstone.user_id
         and member.deletion_epoch=tombstone.deletion_epoch
         and member.tenant_id=provider_command_attempts.tenant_id
         and member.lifecycle_id=provider_command_attempts.lifecycle_id
       where tombstone.user_id=provider_command_attempts.user_id
         and tombstone.status='purging'
         and tombstone.purge_phase='storage_purged'
         and member.status='purging'
    )
  );
create policy u5_owner_select on argus_private.reconciliation_records
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.reconciliation_records
  for insert to argus_brokerage_owner with check (true);
create policy u5_owner_update on argus_private.reconciliation_records
  for update to argus_brokerage_owner using (true) with check (true);
create policy u5_owner_privacy_purge_delete
  on argus_private.reconciliation_records
  for delete to argus_brokerage_owner using (
    exists (
      select 1
        from argus_private.deletion_tombstones tombstone
        join argus_app.members member
          on member.user_id=tombstone.user_id
         and member.deletion_epoch=tombstone.deletion_epoch
         and member.tenant_id=reconciliation_records.tenant_id
         and member.lifecycle_id=reconciliation_records.lifecycle_id
       where tombstone.user_id=reconciliation_records.user_id
         and tombstone.status='purging'
         and tombstone.purge_phase='storage_purged'
         and member.status='purging'
    )
  );
create policy u5_owner_select on argus_private.webull_order_mappings
  for select to argus_brokerage_owner using (true);
create policy u5_owner_insert on argus_private.webull_order_mappings
  for insert to argus_brokerage_owner with check (true);

-- Member and callback table policies mirror only SQL issued by their U5
-- adapters. Sensitive cleanup and command outcome mutation cross named
-- definer entrypoints instead of receiving direct DML.
create policy u5_member_select on argus_brokerage.connections
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_insert on argus_brokerage.connections
  for insert to argus_member with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_update on argus_brokerage.connections
  for update to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.accounts
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.active_account_selections
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_insert on argus_brokerage.active_account_selections
  for insert to argus_member with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_update on argus_brokerage.active_account_selections
  for update to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_delete on argus_brokerage.active_account_selections
  for delete to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.projection_generations
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.order_projection_generations
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.account_capabilities
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.projection_balance_facts
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.projection_position_facts
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.projection_restriction_facts
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_brokerage.projection_account_facts
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_insert on argus_private.oauth_states
  for insert to argus_member with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.oauth_states
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_update on argus_private.oauth_states
  for update to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.webull_completion_handles
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_update on argus_private.webull_completion_handles
  for update to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.webull_credentials
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.webull_account_mappings
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.webull_asset_mappings
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.order_previews
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_insert on argus_private.order_previews
  for insert to argus_member with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.provider_commands
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_member_select on argus_private.webull_order_mappings
  for select to argus_member using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));

create policy u5_callback_select on argus_brokerage.connections
  for select to argus_callback using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_callback_update on argus_brokerage.connections
  for update to argus_callback using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id())) with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_callback_insert on argus_brokerage.accounts
  for insert to argus_callback with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_callback_select on argus_private.oauth_states
  for select to argus_callback using (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_callback_insert on argus_private.webull_completion_handles
  for insert to argus_callback with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_callback_insert on argus_private.webull_credentials
  for insert to argus_callback with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));
create policy u5_callback_insert on argus_private.webull_account_mappings
  for insert to argus_callback with check (tenant_id=(select argus_private.trusted_request_tenant_id()) and lifecycle_id=(select argus_private.trusted_request_lifecycle_id()) and user_id=(select argus_private.trusted_request_user_id()));

create policy u5_staff_command_read on argus_private.provider_commands
  for select to argus_staff
  using ((select argus_private.has_staff_permission('brokerage:read')));
create policy u5_staff_attempt_read on argus_private.provider_command_attempts
  for select to argus_staff
  using ((select argus_private.has_staff_permission('brokerage:read')));
create policy u5_staff_reconciliation_read
  on argus_private.reconciliation_records
  for select to argus_staff
  using ((select argus_private.has_staff_permission('brokerage:read')));
create policy u5_worker_projection_retention
  on argus_brokerage.projection_generations
  for delete to argus_worker using (purge_after<=pg_catalog.now());
create policy u5_worker_order_projection_retention
  on argus_brokerage.order_projection_generations
  for delete to argus_worker using (purge_after<=pg_catalog.now());

revoke all on
  argus_brokerage.connections,argus_brokerage.accounts,
  argus_brokerage.active_account_selections,
  argus_brokerage.projection_generations,
  argus_brokerage.order_projection_generations,
  argus_brokerage.account_capabilities,
  argus_brokerage.projection_balance_facts,
  argus_brokerage.projection_position_facts,
  argus_brokerage.projection_restriction_facts,
  argus_brokerage.projection_account_facts,
  argus_private.projection_generation_snapshots,
  argus_private.order_projection_generation_snapshots,
  argus_private.oauth_states,argus_private.webull_completion_handles,
  argus_private.webull_credentials,argus_private.webull_account_mappings,
  argus_private.refresh_leases,argus_private.projection_refresh_leases,
  argus_private.webull_asset_mappings,argus_private.order_previews,
  argus_private.provider_commands,argus_private.provider_command_attempts,
  argus_private.reconciliation_records,argus_private.webull_order_mappings,
  argus_private.brokerage_normalization_quarantine
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker;

grant select on argus_brokerage.connections to argus_member;
grant insert(id,user_id,deletion_epoch,status)
  on argus_brokerage.connections to argus_member;
grant update(status,last_error_code,updated_at)
  on argus_brokerage.connections to argus_member;
grant select(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,display_label,
  base_currency,market_timezone,status,capability_version,
  provider_observed_at,fetched_at,expires_at
) on argus_brokerage.accounts to argus_member;
grant select,insert,delete on argus_brokerage.active_account_selections
  to argus_member;
grant update(deletion_epoch,connection_id,account_id,selected_at)
  on argus_brokerage.active_account_selections to argus_member;
grant select on argus_brokerage.account_capabilities,
  argus_brokerage.projection_balance_facts,
  argus_brokerage.projection_position_facts,
  argus_brokerage.projection_restriction_facts,
  argus_brokerage.projection_account_facts to argus_member;
grant select(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
  resource_type,generation,provider_observed_at,fetched_at,expires_at,
  availability,reason_code,purge_after,created_at,normalization_state
) on argus_brokerage.projection_generations to argus_member;
grant select(
  id,tenant_id,lifecycle_id,user_id,deletion_epoch,connection_id,account_id,
  order_id,generation,source,state,filled_quantity,provider_observed_at,
  fetched_at,order_list_generation,purge_after,created_at,normalization_state,
  instrument_id,symbol,side,provider_side,order_type,provider_order_type,
  time_in_force,provider_time_in_force,quantity,limit_price,stop_price,
  average_fill_price,currency,provider_state,terminal
) on argus_brokerage.order_projection_generations to argus_member;
grant insert on argus_private.oauth_states to argus_member;
grant update(consumed_at) on argus_private.oauth_states to argus_member;
grant select(user_id,consumed_at) on argus_private.oauth_states to argus_member;
grant update(consumed_at) on argus_private.webull_completion_handles
  to argus_member;
grant select(
  handle_hash,user_id,session_id,consumed_at,expires_at,connection_id,outcome,
  created_at
) on argus_private.webull_completion_handles to argus_member;
grant select(connection_id,user_id,provider_environment)
  on argus_private.webull_credentials to argus_member;
-- Member provider reads need the encrypted account identifier envelope, but
-- never the connection token/key envelope above.
grant select on argus_private.webull_account_mappings to argus_member;
grant select on argus_private.webull_asset_mappings to argus_member;
grant insert on argus_private.order_previews to argus_member;
grant select(
  id,account_id,operation,target_order_id,policy_version,capability_version,
  restriction_generation,reviewed_payload_hash,estimated_total,currency,
  expires_at
) on argus_private.order_previews to argus_member;
grant select(
  id,user_id,account_id,operation,target_order_id,order_id,state,created_at,
  updated_at,egress_started_at
) on argus_private.provider_commands to argus_member;
grant select on argus_private.webull_order_mappings to argus_member;

grant select on argus_brokerage.connections to argus_callback;
grant update(
  status,authorized_at,disconnected_at,last_error_code,updated_at
) on argus_brokerage.connections to argus_callback;
grant insert on argus_brokerage.accounts to argus_callback;
grant select on argus_private.oauth_states to argus_callback;
grant insert on argus_private.webull_completion_handles,
  argus_private.webull_credentials,argus_private.webull_account_mappings
to argus_callback;
grant select(
  id,user_id,account_id,operation,target_order_id,order_id,state,created_at,
  updated_at,egress_started_at
) on argus_private.provider_commands to argus_staff;
grant select(
  id,user_id,command_id,attempt_number,attempt_kind,outcome,provider_error_code,
  created_at
) on argus_private.provider_command_attempts to argus_staff;
grant select(
  user_id,command_id,status,attempts,next_attempt_at,last_error_code,
  updated_at
) on argus_private.reconciliation_records to argus_staff;
grant delete on argus_brokerage.projection_generations,
  argus_brokerage.order_projection_generations to argus_worker;

revoke all on function argus_private.prepare_provider_order_command(
  uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz
),argus_private.append_order_projection(
  uuid,bigint,uuid,uuid,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,bigint
),argus_private.begin_brokerage_order_list_ingestion(uuid,uuid,bigint),
  argus_private.append_brokerage_order_list_observation(
    uuid,uuid,bigint,bigint,uuid,bytea,text,integer,uuid,text,numeric,jsonb,
    timestamptz,timestamptz
  ),argus_private.complete_brokerage_order_list_ingestion(
    uuid,uuid,bigint,bigint,jsonb,timestamptz,timestamptz,timestamptz,text,text
),argus_private.record_provider_order_acknowledgement(
  uuid,uuid,bytea,text,integer,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,text
),argus_private.record_provider_command_dispatch_outcome(uuid,text,text,text),
  argus_private.claim_provider_command_reconciliation(uuid),
  argus_private.record_provider_command_not_found(uuid),
  argus_private.record_provider_command_lookup_ambiguous(uuid,text),
  argus_private.record_provider_order_reconciliation(
    uuid,text,uuid,text,numeric,jsonb,timestamptz,timestamptz,bytea,text,integer,uuid
  ),argus_private.clear_webull_connection_materialization(uuid),
  argus_private.disconnect_webull_connection(text,uuid),
  argus_private.acquire_brokerage_projection_lease(
    uuid,uuid,bigint,text,uuid,timestamptz
  ),argus_private.release_brokerage_projection_lease(uuid,text,uuid),
  argus_private.append_brokerage_projection_generation(
    uuid,uuid,bigint,text,uuid,jsonb,timestamptz,timestamptz,timestamptz,
    text,text,timestamptz
  ),argus_private.resolve_webull_asset_mapping_scoped(
    uuid,uuid,uuid,bigint,text,bytea,text,integer,text,text
  ),argus_private.invalidate_brokerage_account_scoped(uuid),
  argus_private.require_brokerage_reauthorization_scoped(uuid),
  argus_private.get_brokerage_normalization_summary(),
  argus_private.consume_webull_oauth_state(text,timestamptz),
  argus_private.read_brokerage_projection_payload(uuid),
  argus_private.read_brokerage_order_payload(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker;

grant execute on function argus_private.prepare_provider_order_command(
  uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz
),argus_private.begin_brokerage_order_list_ingestion(uuid,uuid,bigint),
  argus_private.append_brokerage_order_list_observation(
    uuid,uuid,bigint,bigint,uuid,bytea,text,integer,uuid,text,numeric,jsonb,
    timestamptz,timestamptz
  ),argus_private.complete_brokerage_order_list_ingestion(
    uuid,uuid,bigint,bigint,jsonb,timestamptz,timestamptz,timestamptz,text,text
),argus_private.record_provider_order_acknowledgement(
  uuid,uuid,bytea,text,integer,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,text
),argus_private.record_provider_command_dispatch_outcome(uuid,text,text,text),
  argus_private.claim_provider_command_reconciliation(uuid),
  argus_private.record_provider_command_not_found(uuid),
  argus_private.record_provider_command_lookup_ambiguous(uuid,text),
  argus_private.record_provider_order_reconciliation(
    uuid,text,uuid,text,numeric,jsonb,timestamptz,timestamptz,bytea,text,integer,uuid
  ),argus_private.clear_webull_connection_materialization(uuid),
  argus_private.disconnect_webull_connection(text,uuid),
  argus_private.acquire_brokerage_projection_lease(
    uuid,uuid,bigint,text,uuid,timestamptz
  ),argus_private.release_brokerage_projection_lease(uuid,text,uuid),
  argus_private.append_brokerage_projection_generation(
    uuid,uuid,bigint,text,uuid,jsonb,timestamptz,timestamptz,timestamptz,
    text,text,timestamptz
  ),argus_private.resolve_webull_asset_mapping_scoped(
    uuid,uuid,uuid,bigint,text,bytea,text,integer,text,text
  ),argus_private.invalidate_brokerage_account_scoped(uuid),
  argus_private.require_brokerage_reauthorization_scoped(uuid),
  argus_private.read_brokerage_projection_payload(uuid),
  argus_private.read_brokerage_order_payload(uuid)
to argus_member;
grant execute on function
  argus_private.consume_webull_oauth_state(text,timestamptz),
  argus_private.clear_webull_connection_materialization(uuid)
to argus_callback;
grant execute on function argus_private.get_brokerage_normalization_summary()
  to argus_staff;

revoke all on function
  argus_private.claim_webull_token_refresh(uuid,uuid,integer),
  argus_private.mark_webull_refresh_egress_started(uuid,uuid,bigint,integer,uuid),
  argus_private.reset_webull_refresh_before_egress(uuid,uuid,bigint,integer,text,uuid),
  argus_private.release_webull_token_refresh(uuid,uuid),
  argus_private.fence_webull_refresh_outcome(uuid,uuid,bigint,integer,text,text),
  argus_private.commit_webull_token_refresh(
    uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
    bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
  ),argus_private.claim_webull_projection_refresh(uuid,uuid,uuid,integer),
  argus_private.release_webull_projection_refresh(uuid,uuid,uuid,boolean),
  argus_private.authorize_webull_projection_egress(
    uuid,uuid,uuid,bigint,integer,text
  ),argus_private.mark_webull_reauthorization(uuid,uuid,bigint,integer,text),
  argus_private.commit_webull_projection_refresh(
    uuid,uuid,uuid,bigint,integer,text,text,jsonb,timestamptz,timestamptz,
    timestamptz,text,text
  ),argus_private.claim_webull_command_reconciliation(uuid,uuid),
  argus_private.authorize_webull_reconciliation_egress(
    uuid,uuid,bigint,integer,text
  ),argus_private.record_webull_reconciliation_retry(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.mark_webull_reconciliation_reauthorization(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.commit_webull_reconciliation(
    uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
    timestamptz,bytea,text,integer,uuid
  ),argus_private.terminalize_webull_recovery_dead_letter(uuid,text)
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker;

grant execute on function
  argus_private.claim_webull_token_refresh(uuid,uuid,integer),
  argus_private.mark_webull_refresh_egress_started(uuid,uuid,bigint,integer,uuid),
  argus_private.reset_webull_refresh_before_egress(uuid,uuid,bigint,integer,text,uuid),
  argus_private.release_webull_token_refresh(uuid,uuid),
  argus_private.fence_webull_refresh_outcome(uuid,uuid,bigint,integer,text,text),
  argus_private.commit_webull_token_refresh(
    uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
    bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
  ),argus_private.claim_webull_projection_refresh(uuid,uuid,uuid,integer),
  argus_private.release_webull_projection_refresh(uuid,uuid,uuid,boolean),
  argus_private.authorize_webull_projection_egress(
    uuid,uuid,uuid,bigint,integer,text
  ),argus_private.mark_webull_reauthorization(uuid,uuid,bigint,integer,text),
  argus_private.commit_webull_projection_refresh(
    uuid,uuid,uuid,bigint,integer,text,text,jsonb,timestamptz,timestamptz,
    timestamptz,text,text
  ),argus_private.claim_webull_command_reconciliation(uuid,uuid),
  argus_private.authorize_webull_reconciliation_egress(
    uuid,uuid,bigint,integer,text
  ),argus_private.record_webull_reconciliation_retry(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.mark_webull_reconciliation_reauthorization(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.commit_webull_reconciliation(
    uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
    timestamptz,bytea,text,integer,uuid
  ),argus_private.terminalize_webull_recovery_dead_letter(uuid,text)
to argus_worker;

revoke execute on function argus_private.lock_brokerage_scope(
  uuid,uuid,uuid,uuid,uuid
),argus_private.lock_brokerage_connection_scope(uuid,uuid),
  argus_private.lock_brokerage_command_scope(uuid),
  argus_private.claim_brokerage_reconciliation_attempt(
    uuid,uuid,bigint,timestamptz
  ),
  argus_private.append_order_projection_scoped(
    uuid,uuid,uuid,bigint,uuid,uuid,uuid,text,numeric,text,jsonb,
    timestamptz,timestamptz,bigint
  ),
  argus_private.mark_webull_refresh_egress_started_after_scope_lock(
    uuid,uuid,bigint,integer,uuid
  ),argus_private.reset_webull_refresh_before_egress_after_scope_lock(
    uuid,uuid,bigint,integer,text,uuid
  ),argus_private.release_webull_token_refresh_after_scope_lock(uuid,uuid),
  argus_private.fence_webull_refresh_outcome_after_scope_lock(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.commit_webull_token_refresh_after_scope_lock(
    uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
    bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
  ),argus_private.mark_webull_reauthorization_after_scope_lock(
    uuid,uuid,bigint,integer,text
  ),argus_private.authorize_webull_reconciliation_egress_after_scope_lock(
    uuid,uuid,bigint,integer,text
  ),argus_private.record_webull_reconciliation_retry_after_scope_lock(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.mark_webull_reconciliation_reauthorization_after_scope_lock(
    uuid,uuid,bigint,integer,text,text
),argus_private.bind_brokerage_member_lifecycle(),
  argus_private.bind_provider_command_child(),
  argus_private.guard_brokerage_connection_transition(),
  argus_private.brokerage_account_capabilities_reason(jsonb),
  argus_private.sync_brokerage_account_capabilities(),
  argus_private.prepare_brokerage_projection_snapshot(),
  argus_private.materialize_brokerage_projection_payload(
    uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb
  ),argus_private.materialize_brokerage_projection_facts(),
  argus_private.prepare_brokerage_order_projection(),
  argus_private.capture_brokerage_order_projection_snapshot()
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker;

grant execute on function
  argus_private.claim_brokerage_reconciliation_attempt(
    uuid,uuid,bigint,timestamptz
  ),
  argus_private.mark_webull_refresh_egress_started_after_scope_lock(
    uuid,uuid,bigint,integer,uuid
  ),argus_private.reset_webull_refresh_before_egress_after_scope_lock(
    uuid,uuid,bigint,integer,text,uuid
  ),argus_private.release_webull_token_refresh_after_scope_lock(uuid,uuid),
  argus_private.fence_webull_refresh_outcome_after_scope_lock(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.commit_webull_token_refresh_after_scope_lock(
    uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
    bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
  ),argus_private.mark_webull_reauthorization_after_scope_lock(
    uuid,uuid,bigint,integer,text
  ),argus_private.authorize_webull_reconciliation_egress_after_scope_lock(
    uuid,uuid,bigint,integer,text
  ),argus_private.record_webull_reconciliation_retry_after_scope_lock(
    uuid,uuid,bigint,integer,text,text
  ),argus_private.mark_webull_reconciliation_reauthorization_after_scope_lock(
    uuid,uuid,bigint,integer,text,text
  )
to argus_brokerage_owner;

do $membership$
begin
  execute pg_catalog.format(
    'grant argus_brokerage_owner to %I with set true',current_user
  );
end
$membership$;
grant create on schema argus_brokerage,argus_private to argus_brokerage_owner;
do $$
declare relation_record record;
begin
  for relation_record in
    select * from (values
      ('argus_brokerage','connections'),
      ('argus_brokerage','accounts'),
      ('argus_brokerage','active_account_selections'),
      ('argus_brokerage','projection_generations'),
      ('argus_brokerage','order_projection_generations'),
      ('argus_brokerage','account_capabilities'),
      ('argus_brokerage','projection_balance_facts'),
      ('argus_brokerage','projection_position_facts'),
      ('argus_brokerage','projection_restriction_facts'),
      ('argus_brokerage','projection_account_facts'),
      ('argus_private','projection_generation_snapshots'),
      ('argus_private','order_projection_generation_snapshots'),
      ('argus_private','oauth_states'),
      ('argus_private','webull_completion_handles'),
      ('argus_private','webull_credentials'),
      ('argus_private','webull_account_mappings'),
      ('argus_private','refresh_leases'),
      ('argus_private','projection_refresh_leases'),
      ('argus_private','webull_asset_mappings'),
      ('argus_private','order_previews'),
      ('argus_private','provider_commands'),
      ('argus_private','provider_command_attempts'),
      ('argus_private','reconciliation_records'),
      ('argus_private','webull_order_mappings'),
      ('argus_private','brokerage_normalization_quarantine')
    ) as relation_rows(schema_name,relation_name)
  loop
    execute pg_catalog.format(
      'alter table %I.%I owner to argus_brokerage_owner',
      relation_record.schema_name,relation_record.relation_name
    );
  end loop;
end
$$;

alter function argus_private.lock_brokerage_scope(uuid,uuid,uuid,uuid,uuid)
  owner to argus_brokerage_owner;
alter function argus_private.lock_brokerage_connection_scope(uuid,uuid)
  owner to argus_brokerage_owner;
alter function argus_private.lock_brokerage_command_scope(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.claim_brokerage_reconciliation_attempt(
  uuid,uuid,bigint,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.bind_brokerage_member_lifecycle()
  owner to argus_brokerage_owner;
alter function argus_private.bind_provider_command_child()
  owner to argus_brokerage_owner;
alter function argus_private.guard_brokerage_connection_transition()
  owner to argus_brokerage_owner;
alter function argus_private.brokerage_account_capabilities_reason(jsonb)
  owner to argus_brokerage_owner;
alter function argus_private.sync_brokerage_account_capabilities()
  owner to argus_brokerage_owner;
alter function argus_private.prepare_brokerage_projection_snapshot()
  owner to argus_brokerage_owner;
alter function argus_private.materialize_brokerage_projection_payload(
  uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb
) owner to argus_brokerage_owner;
alter function argus_private.materialize_brokerage_projection_facts()
  owner to argus_brokerage_owner;
alter function argus_private.prepare_brokerage_order_projection()
  owner to argus_brokerage_owner;
alter function argus_private.capture_brokerage_order_projection_snapshot()
  owner to argus_brokerage_owner;
alter function argus_private.acquire_brokerage_projection_lease(
  uuid,uuid,bigint,text,uuid,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.release_brokerage_projection_lease(uuid,text,uuid)
  owner to argus_brokerage_owner;
alter function argus_private.append_brokerage_projection_generation(
  uuid,uuid,bigint,text,uuid,jsonb,timestamptz,timestamptz,timestamptz,
  text,text,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.resolve_webull_asset_mapping_scoped(
  uuid,uuid,uuid,bigint,text,bytea,text,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.invalidate_brokerage_account_scoped(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.require_brokerage_reauthorization_scoped(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.get_brokerage_normalization_summary()
  owner to argus_brokerage_owner;
alter function argus_private.purge_member_brokerage_data(uuid)
  owner to argus_brokerage_owner;
set local role argus_brokerage_owner;
revoke all on function argus_private.purge_member_brokerage_data(uuid)
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker,argus_brokerage_owner,postgres;
grant execute on function argus_private.purge_member_brokerage_data(uuid)
  to postgres;
reset role;
alter function argus_private.append_order_projection_scoped(
  uuid,uuid,uuid,bigint,uuid,uuid,uuid,text,numeric,text,jsonb,
  timestamptz,timestamptz,bigint
) owner to argus_brokerage_owner;
alter function argus_private.prepare_provider_order_command(
  uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.record_provider_command_dispatch_outcome(
  uuid,text,text,text
) owner to argus_brokerage_owner;
alter function argus_private.append_order_projection(
  uuid,bigint,uuid,uuid,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,bigint
) owner to argus_brokerage_owner;
alter function argus_private.begin_brokerage_order_list_ingestion(
  uuid,uuid,bigint
) owner to argus_brokerage_owner;
alter function argus_private.append_brokerage_order_list_observation(
  uuid,uuid,bigint,bigint,uuid,bytea,text,integer,uuid,text,numeric,jsonb,
  timestamptz,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.complete_brokerage_order_list_ingestion(
  uuid,uuid,bigint,bigint,jsonb,timestamptz,timestamptz,timestamptz,text,text
) owner to argus_brokerage_owner;
alter function argus_private.record_provider_order_acknowledgement(
  uuid,uuid,bytea,text,integer,uuid,text,numeric,text,jsonb,timestamptz,
  timestamptz,text
) owner to argus_brokerage_owner;
alter function argus_private.claim_provider_command_reconciliation(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.record_provider_command_not_found(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.record_provider_command_lookup_ambiguous(uuid,text)
  owner to argus_brokerage_owner;
alter function argus_private.record_provider_order_reconciliation(
  uuid,text,uuid,text,numeric,jsonb,timestamptz,timestamptz,bytea,text,integer,uuid
) owner to argus_brokerage_owner;
alter function argus_private.claim_webull_token_refresh(uuid,uuid,integer)
  owner to argus_brokerage_owner;
alter function argus_private.mark_webull_refresh_egress_started(
  uuid,uuid,bigint,integer,uuid
) owner to argus_brokerage_owner;
alter function argus_private.reset_webull_refresh_before_egress(
  uuid,uuid,bigint,integer,text,uuid
) owner to argus_brokerage_owner;
alter function argus_private.release_webull_token_refresh(uuid,uuid)
  owner to argus_brokerage_owner;
alter function argus_private.fence_webull_refresh_outcome(
  uuid,uuid,bigint,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.commit_webull_token_refresh(
  uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
  bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.claim_webull_projection_refresh(uuid,uuid,uuid,integer)
  owner to argus_brokerage_owner;
alter function argus_private.authorize_webull_projection_egress(
  uuid,uuid,uuid,bigint,integer,text
) owner to argus_brokerage_owner;
alter function argus_private.commit_webull_projection_refresh(
  uuid,uuid,uuid,bigint,integer,text,text,jsonb,timestamptz,timestamptz,
  timestamptz,text,text
) owner to argus_brokerage_owner;
alter function argus_private.release_webull_projection_refresh(
  uuid,uuid,uuid,boolean
) owner to argus_brokerage_owner;
alter function argus_private.mark_webull_reauthorization(
  uuid,uuid,bigint,integer,text
) owner to argus_brokerage_owner;
alter function argus_private.claim_webull_command_reconciliation(uuid,uuid)
  owner to argus_brokerage_owner;
alter function argus_private.authorize_webull_reconciliation_egress(
  uuid,uuid,bigint,integer,text
) owner to argus_brokerage_owner;
alter function argus_private.record_webull_reconciliation_retry(
  uuid,uuid,bigint,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.mark_webull_reconciliation_reauthorization(
  uuid,uuid,bigint,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.commit_webull_reconciliation(
  uuid,uuid,bigint,integer,text,text,uuid,text,numeric,jsonb,timestamptz,
  timestamptz,bytea,text,integer,uuid
) owner to argus_brokerage_owner;
alter function argus_private.mark_webull_refresh_egress_started_after_scope_lock(
  uuid,uuid,bigint,integer,uuid
) owner to argus_brokerage_owner;
alter function argus_private.reset_webull_refresh_before_egress_after_scope_lock(
  uuid,uuid,bigint,integer,text,uuid
) owner to argus_brokerage_owner;
alter function argus_private.release_webull_token_refresh_after_scope_lock(
  uuid,uuid
) owner to argus_brokerage_owner;
alter function argus_private.fence_webull_refresh_outcome_after_scope_lock(
  uuid,uuid,bigint,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.commit_webull_token_refresh_after_scope_lock(
  uuid,uuid,bigint,integer,text,uuid,bigint,integer,bytea,bytea,bytea,
  bytea,bytea,bytea,bytea,bytea,bytea,text,timestamptz,timestamptz
) owner to argus_brokerage_owner;
alter function argus_private.mark_webull_reauthorization_after_scope_lock(
  uuid,uuid,bigint,integer,text
) owner to argus_brokerage_owner;
alter function argus_private.authorize_webull_reconciliation_egress_after_scope_lock(
  uuid,uuid,bigint,integer,text
) owner to argus_brokerage_owner;
alter function argus_private.record_webull_reconciliation_retry_after_scope_lock(
  uuid,uuid,bigint,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.mark_webull_reconciliation_reauthorization_after_scope_lock(
  uuid,uuid,bigint,integer,text,text
) owner to argus_brokerage_owner;
alter function argus_private.terminalize_webull_recovery_dead_letter(uuid,text)
  owner to argus_brokerage_owner;
alter function argus_private.disconnect_webull_connection(text,uuid)
  owner to argus_brokerage_owner;
alter function argus_private.clear_webull_connection_materialization(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.consume_webull_oauth_state(text,timestamptz)
  owner to argus_brokerage_owner;
alter function argus_private.read_brokerage_projection_payload(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.read_brokerage_order_payload(uuid)
  owner to argus_brokerage_owner;

-- Retained U15 purge orchestration delegates its brokerage destruction phase
-- to the U5 capability owner. The legacy orchestrator receives only EXECUTE
-- on this narrow phase, never direct brokerage relation privileges.
alter function argus_private.fence_webull_member_for_deletion(uuid)
  set search_path='';
alter function argus_private.fence_webull_member_for_deletion(uuid)
  owner to argus_brokerage_owner;
alter function argus_private.fence_webull_on_tombstone()
  set search_path='';
alter function argus_private.fence_webull_on_tombstone()
  owner to argus_brokerage_owner;
revoke all on function
  argus_private.fence_webull_member_for_deletion(uuid),
  argus_private.fence_webull_on_tombstone()
from public,anon,authenticated,argus_runtime,argus_member,argus_callback,
     argus_staff,argus_worker;
grant execute on function
  argus_private.fence_webull_member_for_deletion(uuid)
to postgres;

-- Brokerage definers call the U3 identity context only after their final
-- owner is installed. Grant the single composite context reader so domain
-- routines cannot accumulate subtly different scalar identity dependencies.
set local role argus_identity_owner;
revoke execute on function
  argus_private.trusted_request_user_id(),
  argus_private.trusted_request_tenant_id(),
  argus_private.trusted_request_lifecycle_id()
from argus_brokerage_owner;
grant execute on function
  argus_private.read_trusted_request_context()
to argus_brokerage_owner;
reset role;

revoke create on schema argus_brokerage,argus_private
  from argus_brokerage_owner;
do $membership$
begin
  execute pg_catalog.format(
    'revoke argus_brokerage_owner,argus_identity_owner from %I',current_user
  );
end
$membership$;

commit;
