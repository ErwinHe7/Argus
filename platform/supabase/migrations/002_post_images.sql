-- Migration 002: Add images array to posts table.
-- Run in Supabase SQL Editor.
alter table public.posts
  add column if not exists images text[] not null default '{}';
