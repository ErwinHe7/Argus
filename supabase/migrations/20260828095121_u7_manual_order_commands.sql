-- U7: ambiguity-safe manual Webull order commands and order projections.
--
-- The provider contract remains fail-closed at the Edge adapter. These
-- objects establish the durable at-most-once boundary used by synthetic
-- fixtures now and by a separately approved partner contract later.

begin;

-- U6 mappings preserved unknown provider kinds without making them eligible
-- for financial mutation. Existing rows default fail-closed; only a fresh,
-- versioned read mapping can classify EQUITY/ETF as mutation eligible.
alter table argus_private.webull_asset_mappings
  add column asset_kind text not null default 'unsupported'
    check (asset_kind in ('equity','etf','unsupported')),
  add column provider_asset_kind text not null default 'LEGACY_UNKNOWN'
    check (provider_asset_kind ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$');
alter table argus_private.webull_asset_mappings
  alter column asset_kind drop default,
  alter column provider_asset_kind drop default;

-- U2 command rows were synthetic placeholders with weaker pending semantics.
-- Remove them before the U7 idempotency boundary can return one as a winner.
drop trigger provider_command_attempts_immutable
  on argus_private.provider_command_attempts;
delete from argus_private.provider_command_attempts;
delete from argus_private.reconciliation_records;
delete from argus_private.provider_commands;
delete from argus_private.order_previews;
create trigger provider_command_attempts_immutable
  before update or delete on argus_private.provider_command_attempts
  for each row execute function argus_private.reject_immutable_change();

alter table argus_private.order_previews
  add column operation text not null default 'place'
    check (operation in ('place','modify','cancel')),
  add column target_order_id uuid,
  add column policy_version text not null default 'webull-sandbox-manual-v1'
    check (policy_version ~ '^[a-z0-9][a-z0-9._-]{7,127}$'),
  add column provider_preview_ref_ciphertext bytea not null
    default decode(repeat('00',32),'hex')
    check (octet_length(provider_preview_ref_ciphertext) between 32 and 4096),
  add column provider_preview_ref_hash text not null default repeat('0',64)
    check (provider_preview_ref_hash ~ '^[a-f0-9]{64}$'),
  add column provider_preview_key_version integer not null default 1
    check (provider_preview_key_version > 0),
  add column estimated_total text,
  add column currency text check (currency is null or currency ~ '^[A-Z]{3}$');

alter table argus_private.order_previews
  alter column operation drop default,
  alter column policy_version drop default,
  alter column provider_preview_ref_ciphertext drop default,
  alter column provider_preview_ref_hash drop default,
  alter column provider_preview_key_version drop default;

create index order_previews_owner_expiry_idx
  on argus_private.order_previews(user_id,expires_at,id)
  where consumed_at is null;

alter table argus_private.provider_commands
  add column preview_id uuid references argus_private.order_previews(id),
  add column restriction_generation bigint,
  add column policy_version text,
  add column normalized_payload jsonb
    check (normalized_payload is null or jsonb_typeof(normalized_payload)='object'),
  add column target_order_id uuid,
  add column order_id uuid;

alter table argus_private.order_previews
  add constraint order_previews_owner_id_unique unique (user_id,id);

alter table argus_private.provider_commands
  add constraint provider_commands_preview_owner_fk
    foreign key (user_id,preview_id)
    references argus_private.order_previews(user_id,id),
  add constraint provider_commands_policy_version_check
    check (
      policy_version is null
      or policy_version ~ '^[a-z0-9][a-z0-9._-]{7,127}$'
    ),
  add constraint provider_commands_provider_ref_hash_check
    check (
      provider_order_ref_hash is null
      or provider_order_ref_hash ~ '^[a-f0-9]{64}$'
    );

alter table argus_private.provider_commands
  drop constraint provider_commands_user_id_idempotency_key_key;
create unique index provider_commands_idempotency_key_unique
  on argus_private.provider_commands(idempotency_key);

create table argus_private.webull_order_mappings (
  order_id uuid primary key,
  account_id uuid not null,
  connection_id uuid not null,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  provider_environment text not null
    check (provider_environment in ('sandbox','production')),
  provider_order_ref_ciphertext bytea not null
    check (octet_length(provider_order_ref_ciphertext) between 32 and 4096),
  provider_order_ref_hash text not null
    check (provider_order_ref_hash ~ '^[a-f0-9]{64}$'),
  key_version integer not null check (key_version > 0),
  created_at timestamptz not null default now(),
  foreign key (user_id,account_id,connection_id)
    references argus_brokerage.accounts(user_id,id,connection_id)
    on delete cascade,
  unique (user_id,account_id,provider_order_ref_hash),
  unique (user_id,account_id,order_id)
);

alter table argus_private.provider_commands
  add constraint provider_commands_target_order_owner_fk
    foreign key (user_id,account_id,target_order_id)
    references argus_private.webull_order_mappings(user_id,account_id,order_id),
  add constraint provider_commands_result_order_owner_fk
    foreign key (user_id,account_id,order_id)
    references argus_private.webull_order_mappings(user_id,account_id,order_id);

create table argus_brokerage.order_projection_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  account_id uuid not null,
  order_id uuid not null,
  generation bigint not null check (generation > 0),
  source text not null check (source in ('list','detail')),
  state text not null
    check (state in ('pending','partially_filled','filled','cancelled','rejected','expired','unknown')),
  filled_quantity numeric(38,18) not null check (filled_quantity >= 0),
  normalized_payload jsonb not null check (jsonb_typeof(normalized_payload)='object'),
  provider_observed_at timestamptz not null,
  fetched_at timestamptz not null,
  order_list_generation bigint,
  purge_after timestamptz not null default (now() + interval '90 days'),
  created_at timestamptz not null default now(),
  foreign key (user_id,account_id,connection_id)
    references argus_brokerage.accounts(user_id,id,connection_id)
    on delete cascade,
  foreign key (user_id,account_id,order_id)
    references argus_private.webull_order_mappings(user_id,account_id,order_id)
    on delete cascade,
  unique (user_id,account_id,order_id,generation),
  check (provider_observed_at <= fetched_at + interval '30 seconds'),
  check ((source='list')=(order_list_generation is not null)),
  check (purge_after > fetched_at)
);
create index order_projection_owner_latest_idx
  on argus_brokerage.order_projection_generations(
    user_id,account_id,order_id,generation desc
  );
create index order_projection_purge_idx
  on argus_brokerage.order_projection_generations(purge_after,id);
create index order_projection_list_batch_idx
  on argus_brokerage.order_projection_generations(
    user_id,account_id,order_list_generation
  ) where source='list';

alter table argus_private.webull_order_mappings enable row level security;
alter table argus_private.webull_order_mappings force row level security;
alter table argus_brokerage.order_projection_generations enable row level security;
alter table argus_brokerage.order_projection_generations force row level security;

create policy runtime_owner on argus_private.webull_order_mappings
  for all to argus_runtime
  using ((select argus_private.request_user_id())=user_id)
  with check (
    (select argus_private.request_user_id())=user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id=webull_order_mappings.user_id
         and member.status='active'
         and member.deletion_epoch=webull_order_mappings.deletion_epoch
    )
  );
create policy runtime_owner on argus_brokerage.order_projection_generations
  for all to argus_runtime
  using ((select argus_private.request_user_id())=user_id)
  with check (
    (select argus_private.request_user_id())=user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id=order_projection_generations.user_id
         and member.status='active'
         and member.deletion_epoch=order_projection_generations.deletion_epoch
    )
  );
create policy worker_order_projection_retention
  on argus_brokerage.order_projection_generations
  for delete to argus_worker
  using (purge_after <= now());
create policy runtime_staff_command_read on argus_private.provider_commands
  for select to argus_runtime
  using (argus_private.has_staff_permission('brokerage:read'));
create policy runtime_staff_command_attempt_read
  on argus_private.provider_command_attempts
  for select to argus_runtime
  using (argus_private.has_staff_permission('brokerage:read'));
create policy runtime_staff_reconciliation_read
  on argus_private.reconciliation_records
  for select to argus_runtime
  using (argus_private.has_staff_permission('brokerage:read'));

create trigger webull_order_mappings_live_epoch
  before insert or update on argus_private.webull_order_mappings
  for each row execute function argus_private.enforce_live_member_epoch();
create trigger order_projection_generations_live_epoch
  before insert or update on argus_brokerage.order_projection_generations
  for each row execute function argus_private.enforce_live_member_epoch();
create trigger order_projection_generations_immutable
  before update on argus_brokerage.order_projection_generations
  for each row execute function argus_private.reject_immutable_change();

create or replace function argus_private.enforce_order_preview_consumption()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog
as $$
begin
  if old.consumed_at is not null
     or new.consumed_at is null
     or new.consumed_at < old.created_at
     or (to_jsonb(new)-'consumed_at') is distinct from
        (to_jsonb(old)-'consumed_at') then
    raise exception 'immutable_order_preview';
  end if;
  return new;
end
$$;
revoke all on function argus_private.enforce_order_preview_consumption()
  from public,anon,authenticated;
create trigger order_previews_consume_only
  before update on argus_private.order_previews
  for each row execute function argus_private.enforce_order_preview_consumption();

create or replace function argus_private.enforce_provider_command_transition()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog
as $$
declare
  immutable_changed boolean;
begin
  immutable_changed :=
    (to_jsonb(new)-'state'-'updated_at'-'provider_order_ref_hash'-'order_id')
      is distinct from
    (to_jsonb(old)-'state'-'updated_at'-'provider_order_ref_hash'-'order_id');
  if immutable_changed
     or not (
       (old.state='dispatching' and new.state in ('accepted','ambiguous','failed'))
       or (old.state='ambiguous' and new.state in ('reconciling','manual_review'))
       or (old.state='reconciling' and new.state in ('resolved','manual_review'))
     )
     or new.updated_at < old.updated_at then
    raise exception 'invalid_provider_command_transition';
  end if;
  return new;
end
$$;
revoke all on function argus_private.enforce_provider_command_transition()
  from public,anon,authenticated;
create trigger provider_commands_monotonic
  before update on argus_private.provider_commands
  for each row execute function argus_private.enforce_provider_command_transition();

create or replace function argus_private.prepare_provider_order_command(
  p_preview_id uuid,
  p_command_id uuid,
  p_user_id uuid,
  p_deletion_epoch bigint,
  p_connection_id uuid,
  p_account_id uuid,
  p_operation text,
  p_target_order_id uuid,
  p_client_order_id text,
  p_idempotency_key text,
  p_normalized_payload jsonb,
  p_payload_hash text,
  p_policy_version text,
  p_now timestamptz default now()
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
security invoker
set search_path=pg_catalog,auth,argus_app,argus_brokerage,argus_private
as $$
declare
  existing argus_private.provider_commands%rowtype;
  preview argus_private.order_previews%rowtype;
  account_row record;
  restriction argus_brokerage.projection_generations%rowtype;
  target_state text;
  target_asset_kind text;
begin
  if argus_private.request_user_id() is distinct from p_user_id then
    raise exception 'owner_mismatch' using errcode='42501';
  end if;
  if p_now > now() + interval '30 seconds'
     or p_now < now() - interval '30 seconds' then
    raise exception 'invalid_command_time';
  end if;

  -- Serialize the global key before reading it. The second device waits for
  -- the first transaction and then observes its committed command, including
  -- when both confirmations arrived before either row existed.
  perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key,554237));
  select * into existing
    from argus_private.provider_commands command
   where command.idempotency_key=p_idempotency_key
   for update;
  if existing.id is not null then
    if existing.user_id<>p_user_id
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
       where saved.id=existing.preview_id and saved.user_id=existing.user_id;
    return;
  end if;

  if exists (
    select 1 from argus_private.kill_switches switch
     where switch.name in ('provider_egress','order_mutations')
       and switch.enabled
  ) then
    raise exception 'provider_contract_unavailable';
  end if;

  select account.*,connection.status as connection_status into account_row
    from argus_brokerage.accounts account
    join argus_brokerage.connections connection
      on connection.id=account.connection_id
     and connection.user_id=account.user_id
     and connection.deletion_epoch=account.deletion_epoch
   where account.id=p_account_id and account.user_id=p_user_id
     and account.connection_id=p_connection_id
   for update of account;
  if account_row.id is null then
    raise exception 'account_not_found';
  end if;
  if account_row.deletion_epoch<>p_deletion_epoch
     or account_row.connection_status<>'connected'
     or account_row.status<>'available'
     or account_row.expires_at is null
     or account_row.expires_at<=p_now then
    raise exception 'brokerage_authority_stale';
  end if;
  if not exists (
       select 1 from jsonb_array_elements(account_row.capabilities) capability
        where capability->>'capability'='manual_orders'
          and capability->>'available'='true'
     ) or not exists (
       select 1 from jsonb_array_elements(account_row.capabilities) capability
        where capability->>'capability'='orders_read'
          and capability->>'available'='true'
     ) then
    raise exception 'capability_unavailable';
  end if;

  select * into restriction
    from argus_brokerage.projection_generations generation
   where generation.user_id=p_user_id and generation.account_id=p_account_id
     and generation.resource_type='restrictions'
   order by generation.generation desc limit 1;
  if restriction.id is null
     or restriction.availability<>'available'
     or restriction.expires_at<=p_now
     or jsonb_typeof(restriction.normalized_payload)<>'array' then
    raise exception 'brokerage_authority_stale';
  end if;
  if exists (
    select 1 from jsonb_array_elements(restriction.normalized_payload) item
     where jsonb_typeof(item->'active') is distinct from 'boolean'
        or (item->>'active')::boolean
  ) then
    raise exception 'brokerage_restricted';
  end if;

  select * into preview
    from argus_private.order_previews saved
   where saved.id=p_preview_id and saved.user_id=p_user_id
   for update;
  if preview.id is null then raise exception 'preview_mismatch'; end if;
  if preview.consumed_at is not null then raise exception 'preview_replayed'; end if;
  if preview.expires_at<=p_now then raise exception 'preview_expired'; end if;
  if preview.deletion_epoch<>p_deletion_epoch
     or preview.connection_id<>p_connection_id
     or preview.account_id<>p_account_id
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
    if p_target_order_id is not null
       or not exists (
         select 1 from argus_private.webull_asset_mappings asset
          where asset.user_id=p_user_id and asset.account_id=p_account_id
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
        select state,normalized_payload->>'instrument_id' instrument_id
          from argus_brokerage.order_projection_generations generation
         where generation.user_id=mapping.user_id
           and generation.account_id=mapping.account_id
           and generation.order_id=mapping.order_id
         order by generation.generation desc limit 1
      ) projection on true
      left join argus_private.webull_asset_mappings asset
        on asset.user_id=mapping.user_id
       and asset.account_id=mapping.account_id
       and asset.instrument_id=projection.instrument_id::uuid
     where mapping.user_id=p_user_id and mapping.account_id=p_account_id
       and mapping.order_id=p_target_order_id;
    if target_state is null then raise exception 'order_not_found'; end if;
    if target_asset_kind is null
       or target_asset_kind not in ('equity','etf') then
      raise exception 'unsupported_order';
    end if;
    if target_state not in ('pending','partially_filled') then
      raise exception 'unsupported_order';
    end if;
  else
    raise exception 'unsupported_order';
  end if;

  if exists (
    select 1 from argus_private.provider_commands blocked
     where blocked.user_id=p_user_id and blocked.account_id=p_account_id
       and blocked.state in ('dispatching','ambiguous','reconciling','manual_review')
  ) then
    raise exception 'account_command_blocked';
  end if;

  begin
    insert into argus_private.provider_commands(
      id,user_id,deletion_epoch,connection_id,account_id,operation,
      client_order_id,idempotency_key,normalized_payload_hash,
      reviewed_payload_hash,capability_version,state,egress_started_at,
      preview_id,restriction_generation,policy_version,normalized_payload,
      target_order_id
    ) values (
      p_command_id,p_user_id,p_deletion_epoch,p_connection_id,p_account_id,
      p_operation,p_client_order_id,p_idempotency_key,p_payload_hash,
      preview.reviewed_payload_hash,account_row.capability_version,
      'dispatching',p_now,p_preview_id,restriction.generation,p_policy_version,
      p_normalized_payload,p_target_order_id
    );
  exception when unique_violation then
    raise exception 'idempotency_conflict';
  end;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
  ) values (p_user_id,p_deletion_epoch,p_command_id,1,'egress','started');
  update argus_private.order_previews set consumed_at=p_now
   where id=p_preview_id;

  return query
    select p_command_id,p_user_id,p_deletion_epoch,p_connection_id,p_account_id,
           p_operation,p_target_order_id,p_client_order_id,p_normalized_payload,
           p_payload_hash,preview.provider_preview_ref_ciphertext,
           preview.provider_preview_ref_hash,preview.provider_preview_key_version,
           'dispatching'::text,false,p_now;
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
security invoker
set search_path=pg_catalog,auth,argus_brokerage,argus_private
as $$
declare
  prior argus_brokerage.order_projection_generations%rowtype;
  next_generation bigint;
  prior_rank integer;
  next_rank integer;
begin
  if argus_private.request_user_id() is distinct from p_user_id then
    raise exception 'owner_mismatch' using errcode='42501';
  end if;
  if jsonb_typeof(p_payload)<>'object'
     or p_payload::text ~* '"(provider_order_id|provider_asset_id|token|secret|raw_payload)"'
     or p_payload->>'id' is distinct from p_order_id::text
     or p_payload->>'state' is distinct from p_state
     or (p_payload->>'filled_quantity')::numeric is distinct from p_filled_quantity
     or ((p_source='list') is distinct from
         (p_order_list_generation is not null))
     or p_provider_observed_at>p_fetched_at+interval '30 seconds'
     or p_fetched_at>now()+interval '30 seconds' then
    raise exception 'invalid_order_projection';
  end if;
  select * into prior
    from argus_brokerage.order_projection_generations generation
   where generation.user_id=p_user_id and generation.account_id=p_account_id
     and generation.order_id=p_order_id
   order by generation.generation desc limit 1
   for update;
  if prior.id is not null then
    prior_rank := case prior.state
      when 'unknown' then 0 when 'pending' then 10
      when 'partially_filled' then 20
      when 'rejected' then 30 when 'expired' then 30
      when 'cancelled' then 30 when 'filled' then 40 end;
    next_rank := case p_state
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
  next_generation := coalesce(prior.generation,0)+1;
  insert into argus_brokerage.order_projection_generations(
    user_id,deletion_epoch,connection_id,account_id,order_id,generation,
    source,state,filled_quantity,normalized_payload,provider_observed_at,
    fetched_at,order_list_generation,purge_after
  ) values (
    p_user_id,p_deletion_epoch,p_connection_id,p_account_id,p_order_id,
    next_generation,p_source,p_state,p_filled_quantity,p_payload,
    p_provider_observed_at,p_fetched_at,p_order_list_generation,
    p_fetched_at+interval '90 days'
  );
  return next_generation;
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
security invoker
set search_path=pg_catalog,auth,argus_brokerage,argus_private
as $$
declare command_row argus_private.provider_commands%rowtype;
begin
  select * into command_row from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=argus_private.request_user_id()
   for update;
  if command_row.id is null or command_row.state<>'dispatching'
     or command_row.normalized_payload_hash<>p_expected_payload_hash
     or (command_row.target_order_id is not null
         and command_row.target_order_id<>p_order_id)
     or octet_length(p_reference_ciphertext) not between 32 and 4096
     or p_reference_hash !~ '^[a-f0-9]{64}$' or p_key_version<1
     or not exists (
       select 1 from argus_private.webull_asset_mappings asset
        where asset.user_id=command_row.user_id
          and asset.account_id=command_row.account_id
          and asset.instrument_id=p_instrument_id
          and asset.asset_kind in ('equity','etf')
     ) then
    raise exception 'invalid_provider_acknowledgement';
  end if;
  insert into argus_private.webull_order_mappings(
    order_id,account_id,connection_id,user_id,deletion_epoch,
    provider_environment,provider_order_ref_ciphertext,
    provider_order_ref_hash,key_version
  ) select p_order_id,command_row.account_id,command_row.connection_id,
           command_row.user_id,command_row.deletion_epoch,
           credential.provider_environment,p_reference_ciphertext,
           p_reference_hash,p_key_version
      from argus_private.webull_credentials credential
     where credential.connection_id=command_row.connection_id
       and credential.user_id=command_row.user_id
  on conflict (order_id) do nothing;
  if not exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.order_id=p_order_id and mapping.user_id=command_row.user_id
       and mapping.account_id=command_row.account_id
       and mapping.provider_order_ref_hash=p_reference_hash
  ) then raise exception 'provider_order_mapping_conflict'; end if;
  perform argus_private.append_order_projection(
    command_row.user_id,command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_order_id,p_state,p_filled_quantity,p_source,
    p_payload,p_provider_observed_at,p_fetched_at,null
  );
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_row.user_id,command_row.deletion_epoch,p_command_id,2,'egress','accepted'
  );
  update argus_private.provider_commands
     set state='accepted',provider_order_ref_hash=p_reference_hash,
         order_id=p_order_id,updated_at=now()
   where id=p_command_id;
end
$$;

create or replace function argus_private.claim_provider_command_reconciliation(
  p_command_id uuid
)
returns table (
  command_id uuid,user_id uuid,deletion_epoch bigint,connection_id uuid,
  account_id uuid,operation text,target_order_id uuid,client_order_id text,
  normalized_payload jsonb,normalized_payload_hash text,
  provider_preview_ref_ciphertext bytea,provider_preview_ref_hash text,
  provider_preview_key_version integer,egress_started_at timestamptz
)
language plpgsql
security invoker
set search_path=pg_catalog,auth,argus_private
as $$
declare command_row argus_private.provider_commands%rowtype;
declare attempt_number integer;
begin
  select * into command_row from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=argus_private.request_user_id()
     and (
       command.state in ('ambiguous','reconciling')
       or (command.state='dispatching'
           and command.egress_started_at<=now()-interval '30 seconds')
     ) for update;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  if command_row.state='dispatching' then
    update argus_private.provider_commands set state='ambiguous',updated_at=now()
     where id=p_command_id;
    command_row.state := 'ambiguous';
    insert into argus_private.reconciliation_records(
      user_id,deletion_epoch,command_id,status,next_attempt_at
    ) values (
      command_row.user_id,command_row.deletion_epoch,p_command_id,
      'pending',now()
    ) on conflict (command_id) do nothing;
  end if;
  if command_row.state='ambiguous' then
    update argus_private.provider_commands set state='reconciling',updated_at=now()
     where id=p_command_id;
  end if;
  select coalesce(max(attempt.attempt_number),0)+1 into attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_row.user_id,command_row.deletion_epoch,p_command_id,
    attempt_number,'detail_lookup','started'
  );
  update argus_private.reconciliation_records
     set status='running',attempts=attempts+1,updated_at=now()
   where command_id=p_command_id;
  return query
    select command_row.id,command_row.user_id,command_row.deletion_epoch,
           command_row.connection_id,command_row.account_id,
           command_row.operation,command_row.target_order_id,
           command_row.client_order_id,command_row.normalized_payload,
           command_row.normalized_payload_hash,
           preview.provider_preview_ref_ciphertext,
           preview.provider_preview_ref_hash,preview.provider_preview_key_version,
           command_row.egress_started_at
      from argus_private.order_previews preview
     where preview.id=command_row.preview_id;
end
$$;

create or replace function argus_private.record_provider_command_not_found(
  p_command_id uuid
)
returns void
language plpgsql
security invoker
set search_path=pg_catalog,auth,argus_private
as $$
declare command_row argus_private.provider_commands%rowtype;
declare attempt_number integer;
begin
  select * into command_row from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=argus_private.request_user_id()
     and command.state='reconciling' for update;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  select coalesce(max(attempt.attempt_number),0)+1 into attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome
  ) values (
    command_row.user_id,command_row.deletion_epoch,p_command_id,
    attempt_number,'detail_lookup','not_found'
  );
  update argus_private.reconciliation_records
     set status='pending',next_attempt_at=now()+interval '30 seconds',
         last_error_code='provider_order_not_found',updated_at=now()
   where command_id=p_command_id;
end
$$;

create or replace function argus_private.record_provider_command_lookup_ambiguous(
  p_command_id uuid,p_reason_code text
)
returns void
language plpgsql
security invoker
set search_path=pg_catalog,auth,argus_private
as $$
declare command_row argus_private.provider_commands%rowtype;
declare attempt_number integer;
begin
  if p_reason_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    p_reason_code := 'provider_lookup_unavailable';
  end if;
  select * into command_row from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=argus_private.request_user_id()
     and command.state='reconciling' for update;
  if command_row.id is null then raise exception 'command_not_found'; end if;
  select coalesce(max(attempt.attempt_number),0)+1 into attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome,
    provider_error_code
  ) values (
    command_row.user_id,command_row.deletion_epoch,p_command_id,
    attempt_number,'detail_lookup','ambiguous',p_reason_code
  );
  update argus_private.reconciliation_records
     set status='pending',next_attempt_at=now()+interval '30 seconds',
         last_error_code=p_reason_code,updated_at=now()
   where command_id=p_command_id;
end
$$;

create or replace function argus_private.record_provider_order_reconciliation(
  p_command_id uuid,p_resolution text,p_order_id uuid,p_state text,
  p_filled_quantity numeric,
  p_payload jsonb,p_provider_observed_at timestamptz,p_fetched_at timestamptz,
  p_reference_ciphertext bytea,p_reference_hash text,p_key_version integer,
  p_instrument_id uuid
)
returns void
language plpgsql
security invoker
set search_path=pg_catalog,auth,argus_brokerage,argus_private
as $$
declare command_row argus_private.provider_commands%rowtype;
declare attempt_number integer;
declare provider_environment text;
begin
  select * into command_row from argus_private.provider_commands command
   where command.id=p_command_id and command.user_id=argus_private.request_user_id()
     and command.state='reconciling' for update;
  if command_row.id is null
     or p_resolution not in (
       'applied','authoritative_not_applied','superseded_by_fill'
     )
     or (command_row.operation='place' and p_resolution<>'applied')
     or (command_row.operation in ('modify','cancel')
         and command_row.target_order_id<>p_order_id)
     or (p_resolution='superseded_by_fill' and
         (command_row.operation not in ('modify','cancel') or p_state<>'filled'))
     or (command_row.operation='cancel' and p_resolution='applied'
         and p_state<>'cancelled')
     or (command_row.target_order_id is not null
         and command_row.target_order_id<>p_order_id)
     or not exists (
       select 1 from argus_private.webull_asset_mappings asset
        where asset.user_id=command_row.user_id
          and asset.account_id=command_row.account_id
          and asset.instrument_id=p_instrument_id
          and asset.asset_kind in ('equity','etf')
     ) then raise exception 'invalid_reconciliation_detail'; end if;
  select credential.provider_environment into provider_environment
    from argus_private.webull_credentials credential
   where credential.connection_id=command_row.connection_id
     and credential.user_id=command_row.user_id;
  insert into argus_private.webull_order_mappings(
    order_id,account_id,connection_id,user_id,deletion_epoch,
    provider_environment,provider_order_ref_ciphertext,
    provider_order_ref_hash,key_version
  ) values (
    p_order_id,command_row.account_id,command_row.connection_id,
    command_row.user_id,command_row.deletion_epoch,provider_environment,
    p_reference_ciphertext,p_reference_hash,p_key_version
  ) on conflict (order_id) do nothing;
  if not exists (
    select 1 from argus_private.webull_order_mappings mapping
     where mapping.order_id=p_order_id and mapping.user_id=command_row.user_id
       and mapping.account_id=command_row.account_id
       and mapping.provider_order_ref_hash=p_reference_hash
  ) then raise exception 'provider_order_mapping_conflict'; end if;
  perform argus_private.append_order_projection(
    command_row.user_id,command_row.deletion_epoch,command_row.connection_id,
    command_row.account_id,p_order_id,p_state,p_filled_quantity,'detail',
    p_payload,p_provider_observed_at,p_fetched_at,null
  );
  select coalesce(max(attempt.attempt_number),0)+1 into attempt_number
    from argus_private.provider_command_attempts attempt
   where attempt.command_id=p_command_id;
  insert into argus_private.provider_command_attempts(
    user_id,deletion_epoch,command_id,attempt_number,attempt_kind,outcome,
    provider_error_code
  ) values (
    command_row.user_id,command_row.deletion_epoch,p_command_id,
    attempt_number,'detail_lookup',
    case when p_resolution='applied' then 'accepted' else 'terminal_failure' end,
    p_resolution
  );
  update argus_private.provider_commands
     set state='resolved',provider_order_ref_hash=p_reference_hash,
         order_id=p_order_id,updated_at=now()
   where id=p_command_id;
  update argus_private.reconciliation_records
     set status='resolved',
         last_error_code=case when p_resolution='applied' then null
                              else p_resolution end,
         updated_at=now()
   where command_id=p_command_id;
end
$$;

revoke all on function argus_private.prepare_provider_order_command(
  uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz
),argus_private.append_order_projection(
  uuid,bigint,uuid,uuid,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,bigint
),argus_private.record_provider_order_acknowledgement(
  uuid,uuid,bytea,text,integer,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,text
),argus_private.claim_provider_command_reconciliation(uuid),
  argus_private.record_provider_command_not_found(uuid),
  argus_private.record_provider_command_lookup_ambiguous(uuid,text),
  argus_private.record_provider_order_reconciliation(
    uuid,text,uuid,text,numeric,jsonb,timestamptz,timestamptz,bytea,text,integer,uuid
  ) from public,anon,authenticated;

grant execute on function argus_private.prepare_provider_order_command(
  uuid,uuid,uuid,bigint,uuid,uuid,text,uuid,text,text,jsonb,text,text,timestamptz
),argus_private.append_order_projection(
  uuid,bigint,uuid,uuid,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,bigint
),argus_private.record_provider_order_acknowledgement(
  uuid,uuid,bytea,text,integer,uuid,text,numeric,text,jsonb,timestamptz,timestamptz,text
),argus_private.claim_provider_command_reconciliation(uuid),
  argus_private.record_provider_command_not_found(uuid),
  argus_private.record_provider_command_lookup_ambiguous(uuid,text),
  argus_private.record_provider_order_reconciliation(
    uuid,text,uuid,text,numeric,jsonb,timestamptz,timestamptz,bytea,text,integer,uuid
  ) to argus_runtime;

-- Remove the U2 placeholder that could create an unreviewed pending command.
-- U7's prepare function is the sole financial-command creation capability.
drop function argus_private.create_provider_command(
  uuid,uuid,bigint,uuid,uuid,text,text,text,text,text,integer
);

grant select,insert,update,delete on argus_private.webull_order_mappings
  to argus_runtime;
grant select,insert on argus_brokerage.order_projection_generations
  to argus_runtime;
grant select,delete on argus_brokerage.order_projection_generations
  to argus_worker;
-- U7 SECURITY INVOKER functions derive identity through the U2-owned request
-- helper. argus_runtime intentionally retains no auth schema or function grant.
revoke all on argus_private.webull_order_mappings,
  argus_brokerage.order_projection_generations
  from public,anon,authenticated;

comment on table argus_private.order_previews is
  'One-use owner/account/operation/payload/policy/provider-preview bound manual order review.';
comment on table argus_private.provider_commands is
  'Durable at-most-once financial commands; dispatching and first attempt commit before egress.';
comment on table argus_private.webull_order_mappings is
  'Server-only encrypted provider order references mapped to opaque Argus order IDs.';
comment on table argus_brokerage.order_projection_generations is
  'Immutable provider-authoritative order details; detail evidence supersedes lagging lists monotonically.';

commit;
