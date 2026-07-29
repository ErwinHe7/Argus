create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  email text,
  requested_at timestamptz not null default now(),
  status text not null default 'pending',
  notes text
);

create index if not exists account_deletion_requests_user_id_idx
  on public.account_deletion_requests (user_id);

create index if not exists account_deletion_requests_status_idx
  on public.account_deletion_requests (status);
