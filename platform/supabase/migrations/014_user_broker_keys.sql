-- Per-user BYO broker credentials.
-- Encrypted at rest (AES-256-GCM) with BROKER_ENCRYPTION_KEY held by the app.
-- The database never sees plaintext keys; the encrypted_payload column stores an iv.tag.ct triplet.

create table if not exists public.user_broker_keys (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('alpaca', 'ibkr')),
  env text not null check (env in ('paper', 'live')),
  encrypted_payload text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, env)
);

alter table public.user_broker_keys enable row level security;

-- A user can read/manage only their own broker key rows.
drop policy if exists user_broker_keys_select on public.user_broker_keys;
create policy user_broker_keys_select
  on public.user_broker_keys
  for select
  using (auth.uid() = user_id);

drop policy if exists user_broker_keys_insert on public.user_broker_keys;
create policy user_broker_keys_insert
  on public.user_broker_keys
  for insert
  with check (auth.uid() = user_id);

drop policy if exists user_broker_keys_update on public.user_broker_keys;
create policy user_broker_keys_update
  on public.user_broker_keys
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists user_broker_keys_delete on public.user_broker_keys;
create policy user_broker_keys_delete
  on public.user_broker_keys
  for delete
  using (auth.uid() = user_id);

-- Service role bypasses RLS via the API; nothing else needs grants beyond default.
