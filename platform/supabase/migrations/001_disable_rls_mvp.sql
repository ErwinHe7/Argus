-- Migration 001: Disable RLS on all tables for MVP.
-- The app uses service_role key server-side; RLS is not needed until
-- we have per-user client-side queries. Re-enable in a later migration.
-- Run once in Supabase SQL Editor.

alter table public.posts disable row level security;
alter table public.replies disable row level security;
alter table public.reactions disable row level security;
alter table public.post_likes disable row level security;
alter table public.review_queue disable row level security;
alter table public.listings disable row level security;
alter table public.bids disable row level security;
alter table public.transactions disable row level security;
alter table public.messages disable row level security;
alter table public.agent_profiles disable row level security;
alter table public.knowledge_chunks disable row level security;
