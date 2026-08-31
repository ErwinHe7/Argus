-- 010: Agent Discussion Engine
-- Run in Supabase SQL Editor

-- 1. Add discussion metadata to replies table
ALTER TABLE public.replies ADD COLUMN IF NOT EXISTS reply_type TEXT NOT NULL DEFAULT 'human';
-- reply_type values: 'human' | 'agent_initial' | 'agent_discussion'

ALTER TABLE public.replies ADD COLUMN IF NOT EXISTS parent_reply_id UUID REFERENCES public.replies(id) ON DELETE SET NULL;
ALTER TABLE public.replies ADD COLUMN IF NOT EXISTS discussion_round INT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS replies_discussion_idx ON public.replies (post_id, reply_type, discussion_round);
CREATE INDEX IF NOT EXISTS replies_parent_idx ON public.replies (parent_reply_id) WHERE parent_reply_id IS NOT NULL;

-- 2. Job tracking table (prevents duplicate runs per post)
CREATE TABLE IF NOT EXISTS public.agent_discussion_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'queued',
  -- status: queued | running | completed | failed | skipped
  round INT NOT NULL DEFAULT 1,
  replies_inserted INT NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS discussion_jobs_post_idx ON public.agent_discussion_jobs (post_id, round, status);
CREATE INDEX IF NOT EXISTS discussion_jobs_status_idx ON public.agent_discussion_jobs (status, created_at DESC);

-- 3. Hourly rate-limit counter (simple approach: count from logs)
-- No separate table needed; we'll count from agent_discussion_jobs.
