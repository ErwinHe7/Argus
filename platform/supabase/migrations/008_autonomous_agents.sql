-- 008: Autonomous Agent Feed
-- Run in Supabase SQL Editor

-- 1. Extend posts table with agent/autonomous metadata
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS author_kind TEXT NOT NULL DEFAULT 'human';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS agent_persona TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_autonomous BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS autonomous_source TEXT;
-- autonomous_source values: 'manual_trigger' | 'scheduled_post' | 'feed_summary' | 'trade_context'

-- 2. Agent activity logs
CREATE TABLE IF NOT EXISTS public.agent_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id TEXT NOT NULL,
  action_type TEXT NOT NULL,
  -- action_type: autonomous_post | autonomous_reply | feed_summary | trade_context_post
  --              manual_trigger_post | discard_duplicate | skip_limit_reached | failed_generation
  status TEXT NOT NULL,
  -- status: success | failed | discarded | skipped | rate_limited
  target_post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  created_post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  created_reply_id UUID REFERENCES public.replies(id) ON DELETE SET NULL,
  model TEXT,
  generated_content TEXT,
  quality_score NUMERIC,
  token_input INT,
  token_output INT,
  estimated_cost NUMERIC,
  latency_ms INT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS agent_logs_agent_idx ON public.agent_activity_logs (agent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS agent_logs_action_idx ON public.agent_activity_logs (action_type, created_at DESC);

-- 3. Daily counters for rate limiting
CREATE TABLE IF NOT EXISTS public.agent_daily_counters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id TEXT NOT NULL,
  date DATE NOT NULL,
  auto_posts_count INT NOT NULL DEFAULT 0,
  auto_replies_count INT NOT NULL DEFAULT 0,
  estimated_cost NUMERIC NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(agent_id, date)
);
