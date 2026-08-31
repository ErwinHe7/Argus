-- User profiles: custom display names for authenticated users
CREATE TABLE IF NOT EXISTS public.user_profiles (
  user_id text PRIMARY KEY,
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 40),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS user_profiles_user_idx ON public.user_profiles (user_id);
