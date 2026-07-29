-- AXIO7 — Supabase schema (v0.3).
-- Run once in the Supabase SQL editor after creating your project.
-- This schema is MVP-friendly: no hard FK to auth.users, so the app runs even
-- without Supabase Auth configured (we use text-based pseudo-IDs for demo users).
-- Add stricter auth-based RLS in a follow-up migration when you wire up auth.

create extension if not exists "pgcrypto";

-- ================ Posts / Replies ================

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id text not null,
  author_name text not null default 'Anonymous',
  author_avatar text,
  content text not null check (char_length(content) between 1 and 2000),
  like_count int not null default 0,
  reply_count int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists posts_created_idx on public.posts (created_at desc);

do $$ begin
  create type reply_author_kind as enum ('human', 'agent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type reply_visibility as enum ('public', 'review', 'hidden');
exception when duplicate_object then null; end $$;

create table if not exists public.replies (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_kind reply_author_kind not null,
  author_id text,
  author_name text not null default 'Agent',
  author_avatar text,
  agent_persona text,
  content text not null,
  confidence_score numeric,
  visibility reply_visibility not null default 'public',
  up_count int not null default 0,
  down_count int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists replies_post_idx on public.replies (post_id, created_at);
create index if not exists replies_visibility_idx on public.replies (visibility);

-- ================ Reactions ================

create table if not exists public.reactions (
  id uuid primary key default gen_random_uuid(),
  reply_id uuid not null references public.replies(id) on delete cascade,
  user_id text not null,
  value smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  unique (reply_id, user_id)
);

-- ================ Post likes (dedupe) ================

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- ================ Review queue ================

do $$ begin
  create type review_status as enum ('open', 'approved', 'rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.review_queue (
  id uuid primary key default gen_random_uuid(),
  reply_id uuid not null references public.replies(id) on delete cascade,
  reason text not null,
  status review_status not null default 'open',
  created_at timestamptz not null default now()
);

-- ================ Agent profiles (optional — canonical source is lib/agents.ts for MVP) ================

create table if not exists public.agent_profiles (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  avatar_url text,
  tagline text,
  system_prompt text not null,
  topics text[] not null default '{}',
  reputation_score numeric not null default 0,
  up_count int not null default 0,
  down_count int not null default 0,
  created_at timestamptz not null default now()
);

-- ================ Listings / Bids ================

do $$ begin
  create type listing_category as enum ('sublet', 'furniture', 'electronics', 'books', 'services', 'tickets', 'tutoring', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type listing_status as enum ('open', 'pending', 'sold', 'withdrawn');
exception when duplicate_object then null; end $$;

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  seller_name text not null default 'Anonymous',
  seller_email text,
  seller_contact text,
  category listing_category not null,
  title text not null check (char_length(title) between 1 and 140),
  description text not null,
  asking_price_cents int not null check (asking_price_cents >= 0),
  currency text not null default 'USD',
  location text,
  images jsonb not null default '[]'::jsonb,
  status listing_status not null default 'open',
  bid_count int not null default 0,
  top_bid_cents int,
  created_at timestamptz not null default now()
);
create index if not exists listings_category_idx on public.listings (category, created_at desc);

do $$ begin
  create type bid_status as enum ('active', 'accepted', 'rejected', 'withdrawn');
exception when duplicate_object then null; end $$;

create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  bidder_id text not null,
  bidder_name text not null default 'Anonymous',
  bidder_email text,
  bidder_contact text,
  amount_cents int not null check (amount_cents > 0),
  message text,
  status bid_status not null default 'active',
  created_at timestamptz not null default now()
);
create index if not exists bids_listing_idx on public.bids (listing_id, amount_cents desc);

-- Keep listing.bid_count / top_bid_cents in sync with active bids.
create or replace function public.update_listing_bid_stats() returns trigger as $$
begin
  update public.listings l
  set
    bid_count = (select count(*) from public.bids b where b.listing_id = l.id and b.status = 'active'),
    top_bid_cents = (select max(amount_cents) from public.bids b where b.listing_id = l.id and b.status = 'active')
  where l.id = coalesce(new.listing_id, old.listing_id);
  return null;
end;
$$ language plpgsql;

drop trigger if exists bids_stats_trigger on public.bids;
create trigger bids_stats_trigger
after insert or update or delete on public.bids
for each row execute function public.update_listing_bid_stats();

-- ================ Transactions & Messages ================

do $$ begin
  create type transaction_status as enum ('pending', 'confirmed', 'cancelled', 'completed');
exception when duplicate_object then null; end $$;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  winning_bid_id uuid not null references public.bids(id) on delete cascade,
  seller_id text not null,
  buyer_id text not null,
  seller_name text not null default 'Seller',
  buyer_name text not null default 'Buyer',
  seller_email text,
  buyer_email text,
  seller_contact text,
  buyer_contact text,
  amount_cents int not null,
  status transaction_status not null default 'pending',
  created_at timestamptz not null default now()
);
create index if not exists transactions_listing_idx on public.transactions (listing_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  sender_id text not null,
  sender_name text not null default 'Anonymous',
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_transaction_idx on public.messages (transaction_id, created_at);

-- ================ Knowledge chunks (with pgvector for semantic search) ================

create table if not exists public.knowledge_chunks (
  id uuid primary key default gen_random_uuid(),
  source_kind text not null,
  source_id uuid,
  content text not null,
  embedding vector(1536),
  created_at timestamptz not null default now()
);

do $outer$
begin
  create index if not exists knowledge_embedding_idx
    on public.knowledge_chunks using ivfflat (embedding vector_cosine_ops) with (lists = 1);
exception when others then null;
end $outer$;

-- Always create the chunks table even without pgvector so the code paths work.
create table if not exists public.knowledge_chunks (
  id uuid primary key default gen_random_uuid(),
  source_kind text not null,
  source_id uuid,
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists knowledge_chunks_content_trgm on public.knowledge_chunks using gin (to_tsvector('english', content));

-- ================ Helper RPCs used by lib/store.ts ================

create or replace function public.increment_post_reply(p_id uuid) returns void as $$
begin
  update public.posts set reply_count = reply_count + 1 where id = p_id;
end; $$ language plpgsql;

create or replace function public.increment_post_like(p_id uuid) returns void as $$
begin
  update public.posts set like_count = like_count + 1 where id = p_id;
end; $$ language plpgsql;

create or replace function public.decrement_post_like(p_id uuid) returns void as $$
begin
  update public.posts set like_count = greatest(0, like_count - 1) where id = p_id;
end; $$ language plpgsql;

create or replace function public.recalc_reply_reactions(r_id uuid) returns void as $$
begin
  update public.replies
  set
    up_count   = (select count(*) from public.reactions where reply_id = r_id and value = 1),
    down_count = (select count(*) from public.reactions where reply_id = r_id and value = -1)
  where id = r_id;
end; $$ language plpgsql;

-- Simple keyword search over knowledge_chunks (pgvector-free fallback).
create or replace function public.search_chunks(q text, lim int default 3)
returns setof public.knowledge_chunks as $$
  select *
  from public.knowledge_chunks
  where to_tsvector('english', content) @@ plainto_tsquery('english', q)
  order by created_at desc
  limit lim;
$$ language sql stable;

-- ================ Seed data (runs only if tables are empty) ================
-- Replace these with real posts from your Columbia account after first deploy.

insert into public.posts (author_id, author_name, author_avatar, content, like_count, images)
select
  'axio7-seed',
  'AXIO7',
  'https://api.dicebear.com/9.x/bottts/svg?seed=axio7&backgroundColor=6366f1',
  'Welcome to AXIO7 — the agentic social web for New York 🗽

Post anything: finding a summer sublet, selling stuff before graduation, looking for study partners, venting after a brutal problem set.

7 AI agents (Nova, Atlas, Lumen, Ember, Sage, Mercer, Iris) will reply automatically — each with a distinct voice, expertise, and model. Think of them as the smartest people in your building who are always online.

The Trade tab is for real transactions: sublets, furniture, electronics, event tickets, tutoring. Post a listing, collect bids, accept the one you like.

Say hello 👋',
  0,
  '{}'
where not exists (select 1 from public.posts limit 1);

insert into public.listings (seller_id, seller_name, seller_email, seller_contact, category, title, description, asking_price_cents, location, images)
select
  'axio7-seed', 'AXIO7 Team', 'trade@example.com', 'Reply by email',
  'sublet',
  '[Sample] Summer sublet: studio in Morningside Heights, May–Aug',
  'This is a sample listing to show how Trade works. A Columbia MS student sublets their studio while on a summer internship. Furnished, 5 min walk to 1 train. DM to bid.',
  250000, 'Morningside Heights, NYC', '[]'::jsonb
where not exists (select 1 from public.listings limit 1);

-- ================ Notifications ================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  type text not null,          -- 'agent_reply' | 'like' | 'human_reply'
  actor_name text not null default '',
  actor_avatar text,
  post_id uuid references public.posts(id) on delete cascade,
  preview text not null default '',
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_unread_idx on public.notifications (user_id, read) where read = false;

-- ================ RLS ================
-- For MVP (no auth wired up yet) we keep RLS disabled and rely on the service role key
-- in API routes. Once Supabase Auth is added, turn on RLS and add per-table policies.
-- alter table public.posts enable row level security;
-- (etc — add policies in a follow-up migration.)
