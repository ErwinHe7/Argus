-- U6: authoritative Webull read projections.
--
-- All objects remain in non-exposed schemas. Projections are immutable by
-- generation, carry independent resource authority timestamps, and are
-- retained only long enough for UX, recovery and redacted operations.

begin;

alter table argus_private.webull_credentials
  add column provider_environment text not null default 'sandbox'
    check (provider_environment in ('sandbox','production'));
alter table argus_private.webull_account_mappings
  add column provider_environment text not null default 'sandbox'
    check (provider_environment in ('sandbox','production'));

alter table argus_brokerage.accounts
  add column market_timezone text
    check (
      market_timezone is null
      or (
        char_length(market_timezone) between 1 and 64
        and market_timezone !~ '[[:cntrl:]]'
      )
    ),
  add column capabilities jsonb not null default '[]'::jsonb
    check (jsonb_typeof(capabilities) = 'array');

alter table argus_brokerage.accounts
  add constraint accounts_owner_id_connection_unique
    unique (user_id, id, connection_id);

alter table argus_brokerage.projection_generations
  add column reason_code text
    check (
      reason_code is null
      or reason_code ~ '^[a-z][a-z0-9_]{0,63}$'
    ),
  add column purge_after timestamptz;

update argus_brokerage.projection_generations
   set purge_after = greatest(expires_at, fetched_at + interval '30 days');

alter table argus_brokerage.projection_generations
  alter column purge_after set default (now() + interval '30 days'),
  alter column purge_after set not null,
  add constraint projection_generations_purge_after_fetch_check
    check (purge_after > fetched_at);

create index projection_generations_purge_due_idx
  on argus_brokerage.projection_generations(purge_after, id);

-- Existing local and hosted-development rows are synthetic. Clear any stale
-- lease before strengthening the ownership key; a live provider refresh is
-- not permitted while the public Webull contract gate remains unresolved.
delete from argus_private.projection_refresh_leases;

alter table argus_private.projection_refresh_leases
  add column connection_id uuid,
  add column acquired_at timestamptz not null default now();

alter table argus_private.projection_refresh_leases
  add constraint projection_refresh_leases_owner_connection_fk
    foreign key (user_id, connection_id)
    references argus_brokerage.connections(user_id, id) on delete cascade;

alter table argus_private.projection_refresh_leases
  alter column connection_id set not null;

create index projection_refresh_leases_expiry_idx
  on argus_private.projection_refresh_leases(leased_until, account_id);

create table argus_private.webull_asset_mappings (
  instrument_id uuid primary key default gen_random_uuid(),
  account_id uuid not null,
  connection_id uuid not null,
  user_id uuid not null references argus_app.members(user_id) on delete cascade,
  deletion_epoch bigint not null,
  provider_environment text not null
    check (provider_environment in ('sandbox','production')),
  provider_asset_id_ciphertext bytea not null
    check (octet_length(provider_asset_id_ciphertext) between 32 and 4096),
  provider_asset_id_hash text not null
    check (provider_asset_id_hash ~ '^[a-f0-9]{64}$'),
  key_version integer not null check (key_version > 0),
  created_at timestamptz not null default now(),
  foreign key (user_id, account_id)
    references argus_brokerage.accounts(user_id, id) on delete cascade,
  foreign key (user_id, account_id, connection_id)
    references argus_brokerage.accounts(user_id, id, connection_id)
    on delete cascade,
  unique (user_id, account_id, provider_asset_id_hash),
  unique (user_id, account_id, instrument_id)
);

alter table argus_private.webull_asset_mappings enable row level security;
alter table argus_private.webull_asset_mappings force row level security;
create policy runtime_owner on argus_private.webull_asset_mappings
  for all to argus_runtime
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from argus_app.members member
       where member.user_id=webull_asset_mappings.user_id
         and member.status='active'
         and member.deletion_epoch=webull_asset_mappings.deletion_epoch
    )
  );
create trigger webull_asset_mappings_live_epoch
  before insert or update on argus_private.webull_asset_mappings
  for each row execute function argus_private.enforce_live_member_epoch();
grant select, insert, update, delete
  on argus_private.webull_asset_mappings to argus_runtime;

-- Generation rows may never be updated. A bounded worker may delete only
-- generations whose explicit retention deadline has passed.
drop trigger projection_generations_immutable
  on argus_brokerage.projection_generations;
create trigger projection_generations_immutable
  before update on argus_brokerage.projection_generations
  for each row execute function argus_private.reject_immutable_change();

create policy worker_projection_retention
  on argus_brokerage.projection_generations
  for delete to argus_worker
  using (purge_after <= now());

grant select, delete on argus_brokerage.projection_generations to argus_worker;
revoke all on argus_brokerage.accounts,
  argus_brokerage.projection_generations,
  argus_private.projection_refresh_leases,
  argus_private.webull_asset_mappings
from public, anon, authenticated;

comment on column argus_brokerage.accounts.capabilities is
  'Normalized capability flags; unknown provider values remain unsupported.';
comment on column argus_brokerage.projection_generations.purge_after is
  'Explicit bounded retention deadline. Rows are immutable until this deadline.';
comment on table argus_private.projection_refresh_leases is
  'Owner, deletion-epoch, connection, account, and resource-bound distributed refresh leases.';
comment on table argus_private.webull_asset_mappings is
  'Server-only provider asset identifiers mapped to opaque Argus instrument IDs; raw Webull identifiers never enter projections.';

commit;
