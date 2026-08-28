-- U5: one-use Webull Connect callback and completion state.
-- Provider credentials and callback state remain in the non-exposed private
-- schemas. The public callback can consume only a hash of the state value; it
-- never receives a reusable database capability or a client-supplied owner.

alter table argus_private.oauth_states
  add column connection_id uuid,
  add column contract_version text not null default 'webull-connect-public-docs-2026-08-28',
  add column provider_environment text not null default 'sandbox'
    check (provider_environment in ('sandbox','production'));

-- Pending OAuth state is deliberately ephemeral and contains no user data in
-- this non-production migration. Clear any synthetic pre-U5 rows so the new
-- ownership FK and NOT NULL invariant apply deterministically on upgrade.
delete from argus_private.oauth_states;

alter table argus_private.oauth_states
  drop constraint if exists oauth_states_return_target_check;

alter table argus_private.oauth_states
  add constraint oauth_states_return_target_check
    check (return_target in ('webull_https','webull_native')),
  add constraint oauth_states_owner_connection_fk
    foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade;

alter table argus_private.oauth_states
  alter column connection_id set not null;

create index oauth_states_pending_owner_idx
  on argus_private.oauth_states(user_id, created_at desc)
  where consumed_at is null;

create table argus_private.webull_completion_handles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  session_id uuid not null,
  deletion_epoch bigint not null,
  connection_id uuid not null,
  handle_hash text not null unique check (handle_hash ~ '^[a-f0-9]{64}$'),
  outcome text not null
    check (outcome in ('connected','denied','failed','temporarily_unavailable')),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade,
  check (expires_at > created_at)
);

alter table argus_private.webull_completion_handles enable row level security;
alter table argus_private.webull_completion_handles force row level security;

create policy runtime_owner on argus_private.webull_completion_handles
  for all to argus_runtime
  using ((select argus_private.request_user_id()) = user_id)
  with check (
    (select argus_private.request_user_id()) = user_id
    and exists (
      select 1
        from argus_app.members member
       where member.user_id = webull_completion_handles.user_id
         and member.status = 'active'
         and member.deletion_epoch = webull_completion_handles.deletion_epoch
    )
  );

grant select, insert, update, delete
  on argus_private.webull_completion_handles to argus_runtime;
revoke all on argus_private.webull_completion_handles
  from public, anon, authenticated;

create trigger webull_completion_handles_live_epoch
  before insert or update on argus_private.webull_completion_handles
  for each row execute function argus_private.enforce_live_member_epoch();

create or replace function argus_private.consume_webull_oauth_state(
  p_state_hash text,
  p_consumed_at timestamptz
)
returns table (
  state_id uuid,
  user_id uuid,
  session_id uuid,
  deletion_epoch bigint,
  connection_id uuid,
  return_target text,
  contract_version text,
  provider_environment text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if p_state_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_state_hash' using errcode = '22023';
  end if;

  return query
  update argus_private.oauth_states state
     set consumed_at = p_consumed_at
    from argus_app.members member,
         argus_brokerage.connections connection
   where state.state_hash = p_state_hash
     and state.consumed_at is null
     and state.expires_at > p_consumed_at
     and member.user_id = state.user_id
     and member.status = 'active'
     and member.deletion_epoch = state.deletion_epoch
     and connection.id = state.connection_id
     and connection.user_id = state.user_id
     and connection.deletion_epoch = state.deletion_epoch
     and connection.status = 'pending'
  returning state.id, state.user_id, state.session_id, state.deletion_epoch,
            state.connection_id, state.return_target, state.contract_version,
            state.provider_environment;
end
$$;

revoke all on function argus_private.consume_webull_oauth_state(text,timestamptz)
  from public, anon, authenticated;
grant execute on function argus_private.consume_webull_oauth_state(text,timestamptz)
  to argus_runtime;

comment on function argus_private.consume_webull_oauth_state(text,timestamptz) is
  'Atomically consumes a high-entropy Webull state hash after checking expiry, deletion epoch, and pending connection ownership.';
comment on table argus_private.webull_completion_handles is
  'Short-lived, one-use, user-and-session-bound Webull callback outcomes. Only a SHA-256 handle hash is stored.';
