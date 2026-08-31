-- Refunds are reviewed by Paddle or an authorized operator. The production
-- website never creates Paddle adjustments and does not need adjustment.write.

ALTER TABLE public.billing_provider_accounts
  ADD COLUMN IF NOT EXISTS refund_status text,
  ADD COLUMN IF NOT EXISTS refund_transaction_id text,
  ADD COLUMN IF NOT EXISTS refund_subscription_id text,
  ADD COLUMN IF NOT EXISTS refund_updated_at timestamptz;

ALTER TABLE public.billing_provider_accounts
  DROP CONSTRAINT IF EXISTS billing_provider_accounts_refund_status_check;

ALTER TABLE public.billing_provider_accounts
  ADD CONSTRAINT billing_provider_accounts_refund_status_check
  CHECK (
    refund_status IS NULL
    OR refund_status IN ('under_review', 'approved', 'rejected', 'reversed')
  );

CREATE TABLE IF NOT EXISTS public.billing_usage_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  event_type text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT billing_usage_events_type_check CHECK (
    event_type IN (
      'research_report_generated',
      'api_call_completed',
      'export_downloaded',
      'subscription_started',
      'renewal_cancelled',
      'refund_requested'
    )
  )
);

CREATE INDEX IF NOT EXISTS billing_usage_events_user_time_idx
  ON public.billing_usage_events (user_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.billing_service_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  summary text NOT NULL,
  impact text NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT billing_service_incidents_time_check
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE IF NOT EXISTS public.billing_refund_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  environment text NOT NULL,
  customer_id text NOT NULL,
  subscription_id text NOT NULL,
  transaction_id text NOT NULL,
  adjustment_id text,
  reason text NOT NULL,
  usage_summary jsonb NOT NULL,
  status text NOT NULL DEFAULT 'under_review',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  CONSTRAINT billing_refund_requests_environment_check
    CHECK (environment IN ('sandbox', 'live')),
  CONSTRAINT billing_refund_requests_status_check
    CHECK (status IN ('under_review', 'approved', 'rejected', 'reversed')),
  CONSTRAINT billing_refund_requests_reason_check
    CHECK (char_length(reason) BETWEEN 20 AND 2000)
);

CREATE UNIQUE INDEX IF NOT EXISTS billing_refund_requests_open_unique
  ON public.billing_refund_requests (user_id, environment, transaction_id)
  WHERE status = 'under_review';

CREATE INDEX IF NOT EXISTS billing_refund_requests_status_time_idx
  ON public.billing_refund_requests (environment, status, created_at DESC);

ALTER TABLE public.billing_usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_service_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_refund_requests ENABLE ROW LEVEL SECURITY;

-- No public policies are intentional. These tables contain server-recorded
-- billing evidence and are accessed only through the service-role backend.

CREATE OR REPLACE FUNCTION public.paddle_billing_storage_ready()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    to_regclass('public.paddle_customers') IS NOT NULL
    AND to_regclass('public.paddle_subscriptions') IS NOT NULL
    AND to_regclass('public.paddle_transactions') IS NOT NULL
    AND to_regclass('public.paddle_checkout_attempts') IS NOT NULL
    AND to_regclass('public.billing_refund_requests') IS NOT NULL
    AND to_regclass('public.billing_usage_events') IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.paddle_billing_storage_ready() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.paddle_billing_storage_ready() TO service_role;

COMMENT ON TABLE public.billing_refund_requests IS
  'Server-only refund review queue. Insertion never creates a Paddle adjustment.';

COMMENT ON TABLE public.billing_usage_events IS
  'Append-only factual usage evidence used for support and refund review; no inferred usage.';
