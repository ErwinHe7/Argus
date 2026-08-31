-- 015_manual_market_events.sql
-- Persistent storage for user-pasted market events (X tweets, Truth posts,
-- Reuters headlines, SEC URLs, press releases) so they flow into the
-- ticker console catalysts instead of being one-shot analyses.
--
-- These are PUBLIC user-supplied text. No vendor data, no scraped paywalled
-- content. Stored per-user; readable by the user; service role aggregates
-- across users for ticker-level views.

create table if not exists public.manual_market_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  source_type text not null check (source_type in (
    'x_manual','truth_manual','reuters_headline','press_release','sec_url','other'
  )),
  source_url text,
  headline text not null,
  text text not null,
  tickers text[] not null default '{}'::text[],
  tags text[] not null default '{}'::text[],
  sentiment text not null check (sentiment in ('bullish','bearish','neutral','mixed')),
  materiality_score int not null check (materiality_score between 0 and 100),
  confidence int not null check (confidence between 0 and 100),
  risk_flags text[] not null default '{}'::text[],
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists manual_market_events_published_at_desc_idx
  on public.manual_market_events (published_at desc);

create index if not exists manual_market_events_user_idx
  on public.manual_market_events (user_id, published_at desc);

-- GIN index on tickers array for fast per-ticker lookups
create index if not exists manual_market_events_tickers_gin_idx
  on public.manual_market_events using gin (tickers);

alter table public.manual_market_events enable row level security;

-- Owners can read/write their own rows
drop policy if exists manual_market_events_owner_select on public.manual_market_events;
create policy manual_market_events_owner_select
  on public.manual_market_events
  for select
  using (auth.uid() = user_id);

drop policy if exists manual_market_events_owner_insert on public.manual_market_events;
create policy manual_market_events_owner_insert
  on public.manual_market_events
  for insert
  with check (auth.uid() = user_id);

drop policy if exists manual_market_events_owner_delete on public.manual_market_events;
create policy manual_market_events_owner_delete
  on public.manual_market_events
  for delete
  using (auth.uid() = user_id);

-- Anonymous insert allowed for the MVP single-user flow where session may be
-- unauthenticated. Service role still aggregates for ticker views.
drop policy if exists manual_market_events_anon_insert on public.manual_market_events;
create policy manual_market_events_anon_insert
  on public.manual_market_events
  for insert
  to anon
  with check (user_id is null);

-- Service role bypasses RLS by default; no extra policy needed.
