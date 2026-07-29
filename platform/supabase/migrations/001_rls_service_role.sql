-- Migration 001: Enable RLS on all tables with a service_role bypass policy.
-- This lets the app's server-side service role key always read/write,
-- while blocking direct anon/user access (enforced by table-specific policies below).
--
-- Run this in Supabase SQL Editor if you get "permission denied" errors from API routes.

-- Posts
alter table public.posts enable row level security;
create policy "service_role full access" on public.posts
  to service_role using (true) with check (true);
create policy "anon read" on public.posts
  for select to anon using (true);
create policy "authenticated read" on public.posts
  for select to authenticated using (true);

-- Replies
alter table public.replies enable row level security;
create policy "service_role full access" on public.replies
  to service_role using (true) with check (true);
create policy "anon read public replies" on public.replies
  for select to anon using (visibility = 'public');
create policy "authenticated read public replies" on public.replies
  for select to authenticated using (visibility = 'public');

-- Reactions
alter table public.reactions enable row level security;
create policy "service_role full access" on public.reactions
  to service_role using (true) with check (true);

-- Post likes
alter table public.post_likes enable row level security;
create policy "service_role full access" on public.post_likes
  to service_role using (true) with check (true);

-- Review queue
alter table public.review_queue enable row level security;
create policy "service_role full access" on public.review_queue
  to service_role using (true) with check (true);

-- Listings
alter table public.listings enable row level security;
create policy "service_role full access" on public.listings
  to service_role using (true) with check (true);
create policy "anon read open listings" on public.listings
  for select to anon using (status = 'open');
create policy "authenticated read listings" on public.listings
  for select to authenticated using (true);

-- Bids
alter table public.bids enable row level security;
create policy "service_role full access" on public.bids
  to service_role using (true) with check (true);

-- Transactions
alter table public.transactions enable row level security;
create policy "service_role full access" on public.transactions
  to service_role using (true) with check (true);

-- Messages
alter table public.messages enable row level security;
create policy "service_role full access" on public.messages
  to service_role using (true) with check (true);

-- Agent profiles
alter table public.agent_profiles enable row level security;
create policy "service_role full access" on public.agent_profiles
  to service_role using (true) with check (true);
create policy "anon read agent profiles" on public.agent_profiles
  for select to anon using (true);

-- Knowledge chunks
alter table public.knowledge_chunks enable row level security;
create policy "service_role full access" on public.knowledge_chunks
  to service_role using (true) with check (true);
create policy "anon read knowledge" on public.knowledge_chunks
  for select to anon using (true);
