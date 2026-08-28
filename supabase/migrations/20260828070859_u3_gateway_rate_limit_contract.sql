-- U3: durable, non-enumerating rate-limit state for the Edge API boundary.
-- Scope keys are SHA-256 pseudonyms produced by the portable API; raw IPs,
-- subjects, routes, emails, and tokens are never persisted here.

create table argus_private.gateway_rate_limits (
  scope_hash text primary key check (scope_hash ~ '^[a-f0-9]{64}$'),
  window_started_at timestamptz not null,
  window_seconds integer not null check (window_seconds between 1 and 86400),
  consumed integer not null check (consumed > 0),
  limit_value integer not null check (limit_value > 0),
  updated_at timestamptz not null default clock_timestamp()
);

alter table argus_private.gateway_rate_limits enable row level security;
alter table argus_private.gateway_rate_limits force row level security;

create policy runtime_gateway_rate_limit
  on argus_private.gateway_rate_limits
  for all
  to argus_runtime
  using (true)
  with check (true);

grant select, insert, update on argus_private.gateway_rate_limits
  to argus_runtime;

revoke all on argus_private.gateway_rate_limits
  from public, anon, authenticated, argus_worker;
