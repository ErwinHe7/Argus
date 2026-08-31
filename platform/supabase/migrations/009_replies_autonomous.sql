-- 009: Add is_autonomous to replies table
-- Run in Supabase SQL Editor after 008

ALTER TABLE public.replies ADD COLUMN IF NOT EXISTS is_autonomous BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS replies_autonomous_idx ON public.replies (post_id, is_autonomous) WHERE is_autonomous = true;
