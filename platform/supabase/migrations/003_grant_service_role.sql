-- Migration 003: Grant service_role full access to all public tables.
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query).
-- This is needed when service_role gets 42501 "permission denied" errors.

-- Disable RLS on all tables
DO $$ DECLARE
  tbl text;
BEGIN
  FOR tbl IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', tbl);
  END LOOP;
END $$;

-- Grant full access to service_role and postgres
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO service_role;

GRANT USAGE ON SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Also grant to anon for read operations
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
