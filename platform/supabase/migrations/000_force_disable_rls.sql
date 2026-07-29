-- Run this in Supabase SQL Editor to completely reset RLS on all tables.
-- It drops all existing policies first, then disables RLS.
-- Safe to run multiple times.

do $$ declare
  t text;
  p text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    -- Drop all policies on this table
    for p in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy if exists %I on public.%I', p, t);
    end loop;
    -- Disable RLS
    execute format('alter table public.%I disable row level security', t);
  end loop;
end $$;
