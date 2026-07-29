-- Add pinned column to posts for admin trending control
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS posts_pinned_idx ON public.posts (pinned) WHERE pinned = true;
