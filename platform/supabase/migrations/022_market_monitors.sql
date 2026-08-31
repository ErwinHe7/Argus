-- Durable user-owned market research monitors.
--
-- The browser never writes these tables directly. Authenticated API routes
-- validate the allow-listed MarketQuery contract and use the service role.
-- The cron worker atomically claims due rows through claim_market_monitors().

CREATE TABLE IF NOT EXISTS public.market_monitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  source_question text NOT NULL,
  query jsonb NOT NULL,
  query_sha256 text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  cadence_minutes integer NOT NULL DEFAULT 5,
  next_run_at timestamptz NOT NULL DEFAULT now(),
  last_run_at timestamptz,
  last_result_status text,
  last_error text,
  last_triggered_at timestamptz,
  consecutive_failures integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT market_monitors_title_check
    CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
  CONSTRAINT market_monitors_question_check
    CHECK (char_length(btrim(source_question)) BETWEEN 1 AND 2000),
  CONSTRAINT market_monitors_query_hash_check
    CHECK (query_sha256 ~ '^[0-9a-f]{64}$'),
  CONSTRAINT market_monitors_status_check
    CHECK (status IN ('active', 'paused', 'disabled')),
  CONSTRAINT market_monitors_cadence_check
    CHECK (cadence_minutes IN (5, 15, 30, 60)),
  CONSTRAINT market_monitors_query_version_check
    CHECK (query ->> 'version' = 'axio.market-query.v1'),
  CONSTRAINT market_monitors_setup_check
    CHECK (
      query ->> 'setup_type' IN (
        'momentum',
        'gamma_squeeze',
        'vwap_reversal',
        'opening_turn',
        'closing_short_cover',
        'statistical_dislocation'
      )
    ),
  CONSTRAINT market_monitors_no_execution_fields_check
    CHECK (
      NOT (
        query ?| ARRAY[
          'order',
          'orders',
          'execute',
          'execution',
          'quantity',
          'position_size',
          'broker'
        ]
      )
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS market_monitors_active_query_idx
  ON public.market_monitors (user_id, query_sha256)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS market_monitors_due_idx
  ON public.market_monitors (next_run_at, id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS market_monitors_user_idx
  ON public.market_monitors (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.market_monitor_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monitor_id uuid NOT NULL REFERENCES public.market_monitors(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  observed_cutoff timestamptz NOT NULL,
  completed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL,
  triggered boolean NOT NULL DEFAULT false,
  response_sha256 text,
  candidate_count integer NOT NULL DEFAULT 0,
  result_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_code text,
  CONSTRAINT market_monitor_runs_response_hash_check
    CHECK (
      response_sha256 IS NULL
      OR response_sha256 ~ '^[0-9a-f]{64}$'
    ),
  CONSTRAINT market_monitor_runs_candidate_count_check
    CHECK (candidate_count >= 0)
);

CREATE INDEX IF NOT EXISTS market_monitor_runs_monitor_idx
  ON public.market_monitor_runs (monitor_id, completed_at DESC);

CREATE INDEX IF NOT EXISTS market_monitor_runs_user_idx
  ON public.market_monitor_runs (user_id, completed_at DESC);

CREATE TABLE IF NOT EXISTS public.market_monitor_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monitor_id uuid NOT NULL REFERENCES public.market_monitors(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fingerprint text NOT NULL,
  triggered_at timestamptz NOT NULL,
  title text NOT NULL,
  summary text NOT NULL,
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT market_monitor_events_fingerprint_check
    CHECK (fingerprint ~ '^[0-9a-f]{64}$'),
  CONSTRAINT market_monitor_events_title_check
    CHECK (char_length(btrim(title)) BETWEEN 1 AND 160),
  CONSTRAINT market_monitor_events_summary_check
    CHECK (char_length(btrim(summary)) BETWEEN 1 AND 2000),
  UNIQUE (monitor_id, fingerprint)
);

CREATE INDEX IF NOT EXISTS market_monitor_events_user_idx
  ON public.market_monitor_events (user_id, triggered_at DESC);

ALTER TABLE public.market_monitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_monitor_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_monitor_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.market_monitors FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.market_monitor_runs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.market_monitor_events FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.market_monitors TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.market_monitor_runs TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.market_monitor_events TO service_role;

CREATE OR REPLACE FUNCTION public.claim_market_monitors(
  p_limit integer DEFAULT 50,
  p_now timestamptz DEFAULT now()
)
RETURNS SETOF public.market_monitors
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH due AS (
    SELECT id
    FROM public.market_monitors
    WHERE status = 'active'
      AND next_run_at <= p_now
    ORDER BY next_run_at, id
    FOR UPDATE SKIP LOCKED
    LIMIT LEAST(GREATEST(p_limit, 1), 200)
  )
  UPDATE public.market_monitors AS monitor
  SET
    last_run_at = p_now,
    next_run_at = p_now + make_interval(mins => monitor.cadence_minutes),
    updated_at = p_now
  FROM due
  WHERE monitor.id = due.id
  RETURNING monitor.*;
$$;

REVOKE ALL ON FUNCTION public.claim_market_monitors(integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_market_monitors(integer, timestamptz)
  TO service_role;

COMMENT ON TABLE public.market_monitors IS
  'User-owned deterministic research monitors compiled from natural language into MarketQuery v1.';
COMMENT ON TABLE public.market_monitor_runs IS
  'Append-only scan receipts for due market monitors; no order or personalized advice fields.';
COMMENT ON TABLE public.market_monitor_events IS
  'Deduplicated research-condition events produced by monitor scans.';

NOTIFY pgrst, 'reload schema';
