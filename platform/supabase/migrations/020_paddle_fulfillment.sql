-- Durable, server-only Paddle fulfillment state.
--
-- Paddle deliveries are at-least-once and may arrive out of order. The tables
-- below keep provider resources separate from the generic entitlement snapshot,
-- while the SECURITY DEFINER functions make event claiming and source-timestamp
-- guarded upserts atomic.

CREATE TABLE IF NOT EXISTS public.paddle_customers (
  environment text NOT NULL,
  test_mode boolean NOT NULL,
  customer_id text NOT NULL,
  user_id text,
  email text,
  name text,
  status text,
  paddle_created_at timestamptz,
  paddle_updated_at timestamptz,
  source_event_occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (environment, customer_id),
  CONSTRAINT paddle_customers_environment_check
    CHECK (environment IN ('sandbox', 'live')),
  CONSTRAINT paddle_customers_mode_check
    CHECK (test_mode = (environment = 'sandbox')),
  CONSTRAINT paddle_customers_id_check
    CHECK (customer_id LIKE 'ctm\_%' ESCAPE '\')
);

CREATE INDEX IF NOT EXISTS paddle_customers_user_idx
  ON public.paddle_customers (user_id, environment);

CREATE TABLE IF NOT EXISTS public.paddle_subscriptions (
  environment text NOT NULL,
  test_mode boolean NOT NULL,
  subscription_id text NOT NULL,
  customer_id text NOT NULL,
  user_id text NOT NULL,
  transaction_id text,
  status text NOT NULL,
  price_id text NOT NULL,
  product_id text NOT NULL,
  current_period_end timestamptz,
  scheduled_change_action text,
  scheduled_change_at timestamptz,
  paddle_created_at timestamptz NOT NULL,
  paddle_updated_at timestamptz NOT NULL,
  source_event_occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (environment, subscription_id),
  CONSTRAINT paddle_subscriptions_environment_check
    CHECK (environment IN ('sandbox', 'live')),
  CONSTRAINT paddle_subscriptions_mode_check
    CHECK (test_mode = (environment = 'sandbox')),
  CONSTRAINT paddle_subscriptions_id_check
    CHECK (subscription_id LIKE 'sub\_%' ESCAPE '\'),
  CONSTRAINT paddle_subscriptions_customer_id_check
    CHECK (customer_id LIKE 'ctm\_%' ESCAPE '\'),
  CONSTRAINT paddle_subscriptions_transaction_id_check
    CHECK (transaction_id IS NULL OR transaction_id LIKE 'txn\_%' ESCAPE '\'),
  CONSTRAINT paddle_subscriptions_price_id_check
    CHECK (price_id LIKE 'pri\_%' ESCAPE '\'),
  CONSTRAINT paddle_subscriptions_product_id_check
    CHECK (product_id LIKE 'pro\_%' ESCAPE '\'),
  CONSTRAINT paddle_subscriptions_customer_fk
    FOREIGN KEY (environment, customer_id)
    REFERENCES public.paddle_customers (environment, customer_id)
);

CREATE INDEX IF NOT EXISTS paddle_subscriptions_user_idx
  ON public.paddle_subscriptions (user_id, environment, paddle_updated_at DESC);

CREATE INDEX IF NOT EXISTS paddle_subscriptions_customer_idx
  ON public.paddle_subscriptions (customer_id, environment);

CREATE INDEX IF NOT EXISTS paddle_subscriptions_status_idx
  ON public.paddle_subscriptions (environment, status);

CREATE TABLE IF NOT EXISTS public.paddle_transactions (
  environment text NOT NULL,
  test_mode boolean NOT NULL,
  transaction_id text NOT NULL,
  customer_id text NOT NULL,
  subscription_id text NOT NULL,
  user_id text NOT NULL,
  status text NOT NULL,
  price_id text NOT NULL,
  product_id text NOT NULL,
  currency_code text NOT NULL,
  total text,
  paddle_created_at timestamptz NOT NULL,
  paddle_updated_at timestamptz NOT NULL,
  source_event_occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (environment, transaction_id),
  CONSTRAINT paddle_transactions_environment_check
    CHECK (environment IN ('sandbox', 'live')),
  CONSTRAINT paddle_transactions_mode_check
    CHECK (test_mode = (environment = 'sandbox')),
  CONSTRAINT paddle_transactions_id_check
    CHECK (transaction_id LIKE 'txn\_%' ESCAPE '\'),
  CONSTRAINT paddle_transactions_customer_id_check
    CHECK (customer_id LIKE 'ctm\_%' ESCAPE '\'),
  CONSTRAINT paddle_transactions_subscription_id_check
    CHECK (subscription_id LIKE 'sub\_%' ESCAPE '\'),
  CONSTRAINT paddle_transactions_price_id_check
    CHECK (price_id LIKE 'pri\_%' ESCAPE '\'),
  CONSTRAINT paddle_transactions_product_id_check
    CHECK (product_id LIKE 'pro\_%' ESCAPE '\'),
  CONSTRAINT paddle_transactions_customer_fk
    FOREIGN KEY (environment, customer_id)
    REFERENCES public.paddle_customers (environment, customer_id),
  CONSTRAINT paddle_transactions_subscription_fk
    FOREIGN KEY (environment, subscription_id)
    REFERENCES public.paddle_subscriptions (environment, subscription_id)
);

CREATE INDEX IF NOT EXISTS paddle_transactions_user_idx
  ON public.paddle_transactions (user_id, environment, paddle_updated_at DESC);

CREATE INDEX IF NOT EXISTS paddle_transactions_subscription_idx
  ON public.paddle_transactions (subscription_id, environment);

CREATE TABLE IF NOT EXISTS public.paddle_webhook_events (
  environment text NOT NULL,
  test_mode boolean NOT NULL,
  event_id text NOT NULL,
  notification_id text,
  event_type text NOT NULL,
  claim_token text NOT NULL,
  occurred_at timestamptz NOT NULL,
  processing_status text NOT NULL DEFAULT 'processing',
  attempt_count integer NOT NULL DEFAULT 1,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (environment, event_id),
  CONSTRAINT paddle_webhook_events_environment_check
    CHECK (environment IN ('sandbox', 'live')),
  CONSTRAINT paddle_webhook_events_mode_check
    CHECK (test_mode = (environment = 'sandbox')),
  CONSTRAINT paddle_webhook_events_status_check
    CHECK (processing_status IN ('processing', 'processed', 'failed')),
  CONSTRAINT paddle_webhook_events_claim_token_check
    CHECK (length(claim_token) BETWEEN 16 AND 128),
  CONSTRAINT paddle_webhook_events_attempt_count_check
    CHECK (attempt_count > 0)
);

CREATE INDEX IF NOT EXISTS paddle_webhook_events_status_idx
  ON public.paddle_webhook_events (processing_status, claimed_at);

-- One reusable, not-yet-completed checkout transaction per user prevents two
-- concurrent Subscribe requests from creating two billable subscriptions.
-- Rows are permanent operational history; they are updated, never deleted.
CREATE TABLE IF NOT EXISTS public.paddle_checkout_attempts (
  environment text NOT NULL,
  test_mode boolean NOT NULL,
  user_id text NOT NULL,
  attempt_token text NOT NULL,
  transaction_id text,
  state text NOT NULL DEFAULT 'creating',
  claimed_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (environment, user_id),
  CONSTRAINT paddle_checkout_attempts_environment_check
    CHECK (environment IN ('sandbox', 'live')),
  CONSTRAINT paddle_checkout_attempts_mode_check
    CHECK (test_mode = (environment = 'sandbox')),
  CONSTRAINT paddle_checkout_attempts_state_check
    CHECK (state IN ('creating', 'ready', 'completed')),
  CONSTRAINT paddle_checkout_attempts_token_check
    CHECK (length(attempt_token) BETWEEN 16 AND 128),
  CONSTRAINT paddle_checkout_attempts_transaction_check
    CHECK (transaction_id IS NULL OR transaction_id LIKE 'txn\_%' ESCAPE '\'),
  CONSTRAINT paddle_checkout_attempts_state_transaction_check
    CHECK (
      (state = 'creating' AND transaction_id IS NULL)
      OR (state IN ('ready', 'completed') AND transaction_id IS NOT NULL)
    ),
  CONSTRAINT paddle_checkout_attempts_transaction_unique
    UNIQUE (environment, transaction_id)
);

CREATE INDEX IF NOT EXISTS paddle_checkout_attempts_state_idx
  ON public.paddle_checkout_attempts (environment, state, claimed_at);

ALTER TABLE public.paddle_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paddle_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paddle_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paddle_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paddle_checkout_attempts ENABLE ROW LEVEL SECURITY;

-- No anon/authenticated policies are intentional. Only server code holding the
-- service-role credential may inspect or mutate billing identifiers.
REVOKE ALL ON TABLE public.paddle_customers FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.paddle_subscriptions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.paddle_transactions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.paddle_webhook_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.paddle_checkout_attempts FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.paddle_customers TO service_role;
GRANT ALL ON TABLE public.paddle_subscriptions TO service_role;
GRANT ALL ON TABLE public.paddle_transactions TO service_role;
GRANT ALL ON TABLE public.paddle_webhook_events TO service_role;
GRANT ALL ON TABLE public.paddle_checkout_attempts TO service_role;

CREATE OR REPLACE FUNCTION public.claim_paddle_checkout_attempt(
  p_environment text,
  p_test_mode boolean,
  p_user_id text,
  p_attempt_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted boolean := false;
  existing public.paddle_checkout_attempts%ROWTYPE;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR p_test_mode IS DISTINCT FROM (p_environment = 'sandbox')
     OR NULLIF(btrim(p_user_id), '') IS NULL
     OR length(p_attempt_token) NOT BETWEEN 16 AND 128 THEN
    RAISE EXCEPTION 'Invalid Paddle checkout claim';
  END IF;

  INSERT INTO public.paddle_checkout_attempts (
    environment, test_mode, user_id, attempt_token, state, claimed_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_user_id, p_attempt_token, 'creating', now(), now()
  )
  ON CONFLICT (environment, user_id) DO NOTHING
  RETURNING true INTO inserted;

  IF COALESCE(inserted, false) THEN
    RETURN jsonb_build_object('state', 'claimed', 'attempt_token', p_attempt_token);
  END IF;

  SELECT * INTO existing
  FROM public.paddle_checkout_attempts
  WHERE environment = p_environment AND user_id = p_user_id;

  IF existing.state = 'ready' AND existing.transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'state', 'ready',
      'attempt_token', existing.attempt_token,
      'transaction_id', existing.transaction_id
    );
  END IF;
  IF existing.state = 'completed' THEN
    UPDATE public.paddle_checkout_attempts
    SET
      attempt_token = p_attempt_token,
      transaction_id = NULL,
      state = 'creating',
      claimed_at = now(),
      completed_at = NULL,
      updated_at = now()
    WHERE environment = p_environment
      AND user_id = p_user_id
      AND state = 'completed'
    RETURNING * INTO existing;
    IF existing.state = 'creating' AND existing.attempt_token = p_attempt_token THEN
      RETURN jsonb_build_object('state', 'claimed', 'attempt_token', p_attempt_token);
    END IF;
    RETURN jsonb_build_object('state', 'busy', 'attempt_token', p_attempt_token);
  END IF;
  IF existing.state = 'creating' AND existing.claimed_at < now() - interval '2 minutes' THEN
    RETURN jsonb_build_object('state', 'recover', 'attempt_token', existing.attempt_token);
  END IF;
  RETURN jsonb_build_object('state', 'busy', 'attempt_token', existing.attempt_token);
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_paddle_checkout_attempt(
  p_environment text,
  p_user_id text,
  p_previous_token text,
  p_attempt_token text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  reset boolean := false;
BEGIN
  UPDATE public.paddle_checkout_attempts
  SET attempt_token = p_attempt_token, claimed_at = now(), updated_at = now()
  WHERE environment = p_environment
    AND user_id = p_user_id
    AND state = 'creating'
    AND attempt_token = p_previous_token
    AND claimed_at < now() - interval '2 minutes'
  RETURNING true INTO reset;
  RETURN COALESCE(reset, false);
END;
$$;

-- Rotate an abandoned provider transaction only after application code has
-- retrieved it from Paddle and confirmed that it can no longer be checked out.
-- The expected token and transaction ID form a compare-and-swap guard.
CREATE OR REPLACE FUNCTION public.rotate_paddle_ready_checkout_attempt(
  p_environment text,
  p_user_id text,
  p_expected_token text,
  p_expected_transaction_id text,
  p_attempt_token text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rotated boolean := false;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR NULLIF(btrim(p_user_id), '') IS NULL
     OR length(p_expected_token) NOT BETWEEN 16 AND 128
     OR p_expected_transaction_id IS NULL
     OR p_expected_transaction_id NOT LIKE 'txn\_%' ESCAPE '\'
     OR length(p_attempt_token) NOT BETWEEN 16 AND 128 THEN
    RAISE EXCEPTION 'Invalid Paddle ready-checkout rotation';
  END IF;

  UPDATE public.paddle_checkout_attempts
  SET
    attempt_token = p_attempt_token,
    transaction_id = NULL,
    state = 'creating',
    claimed_at = now(),
    completed_at = NULL,
    updated_at = now()
  WHERE environment = p_environment
    AND user_id = p_user_id
    AND state = 'ready'
    AND attempt_token = p_expected_token
    AND transaction_id = p_expected_transaction_id
  RETURNING true INTO rotated;

  RETURN COALESCE(rotated, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_paddle_checkout_attempt(
  p_environment text,
  p_user_id text,
  p_attempt_token text,
  p_transaction_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_transaction_id IS NULL OR p_transaction_id NOT LIKE 'txn\_%' ESCAPE '\' THEN
    RAISE EXCEPTION 'Invalid Paddle transaction ID';
  END IF;
  UPDATE public.paddle_checkout_attempts
  SET transaction_id = p_transaction_id, state = 'ready', updated_at = now()
  WHERE environment = p_environment
    AND user_id = p_user_id
    AND state = 'creating'
    AND attempt_token = p_attempt_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Paddle checkout claim is no longer owned by this request';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_paddle_checkout_attempt(
  p_environment text,
  p_user_id text,
  p_transaction_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.paddle_checkout_attempts
  SET state = 'completed', completed_at = now(), updated_at = now()
  WHERE environment = p_environment
    AND user_id = p_user_id
    AND transaction_id = p_transaction_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_paddle_webhook_event(
  p_environment text,
  p_test_mode boolean,
  p_event_id text,
  p_notification_id text,
  p_event_type text,
  p_claim_token text,
  p_occurred_at timestamptz
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  claimed boolean := false;
  current_status text;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR p_test_mode IS DISTINCT FROM (p_environment = 'sandbox')
     OR NULLIF(btrim(p_event_id), '') IS NULL
     OR NULLIF(btrim(p_event_type), '') IS NULL
     OR length(p_claim_token) NOT BETWEEN 16 AND 128
     OR p_occurred_at IS NULL THEN
    RAISE EXCEPTION 'Invalid Paddle webhook claim';
  END IF;

  INSERT INTO public.paddle_webhook_events (
    environment,
    test_mode,
    event_id,
    notification_id,
    event_type,
    claim_token,
    occurred_at,
    processing_status,
    attempt_count,
    claimed_at,
    updated_at
  )
  VALUES (
    p_environment,
    p_test_mode,
    p_event_id,
    p_notification_id,
    p_event_type,
    p_claim_token,
    p_occurred_at,
    'processing',
    1,
    now(),
    now()
  )
  ON CONFLICT (environment, event_id) DO NOTHING
  RETURNING true INTO claimed;

  IF COALESCE(claimed, false) THEN
    RETURN 'claimed';
  END IF;

  SELECT processing_status
  INTO current_status
  FROM public.paddle_webhook_events
  WHERE environment = p_environment
    AND event_id = p_event_id;

  IF current_status = 'processed' THEN
    RETURN 'processed';
  END IF;

  UPDATE public.paddle_webhook_events
  SET
    notification_id = COALESCE(p_notification_id, notification_id),
    processing_status = 'processing',
    claim_token = p_claim_token,
    attempt_count = attempt_count + 1,
    claimed_at = now(),
    last_error = NULL,
    updated_at = now()
  WHERE environment = p_environment
    AND event_id = p_event_id
    AND event_type = p_event_type
    AND test_mode = p_test_mode
    AND (
      processing_status = 'failed'
      OR (processing_status = 'processing' AND claimed_at < now() - interval '5 minutes')
    )
  RETURNING true INTO claimed;

  IF COALESCE(claimed, false) THEN
    RETURN 'claimed';
  END IF;
  RETURN 'busy';
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_paddle_webhook_event(
  p_environment text,
  p_event_id text,
  p_claim_token text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  completed_event public.paddle_webhook_events%ROWTYPE;
BEGIN
  UPDATE public.paddle_webhook_events
  SET
    processing_status = 'processed',
    processed_at = now(),
    last_error = NULL,
    updated_at = now()
  WHERE environment = p_environment
    AND event_id = p_event_id
    AND processing_status = 'processing'
    AND claim_token = p_claim_token
  RETURNING * INTO completed_event;

  IF completed_event.event_id IS NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.paddle_webhook_events
      WHERE environment = p_environment
        AND event_id = p_event_id
        AND processing_status = 'processed'
    ) THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'Paddle webhook event is not claimed';
  END IF;

  -- Preserve compatibility with the provider-agnostic webhook audit table.
  INSERT INTO public.payment_webhook_events (
    provider,
    event_id,
    event_type,
    test_mode,
    processed_at
  )
  VALUES (
    'paddle',
    completed_event.event_id,
    completed_event.event_type,
    completed_event.test_mode,
    now()
  )
  ON CONFLICT (provider, event_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.fail_paddle_webhook_event(
  p_environment text,
  p_event_id text,
  p_claim_token text,
  p_error text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.paddle_webhook_events
  SET
    processing_status = 'failed',
    last_error = left(COALESCE(NULLIF(p_error, ''), 'Unknown processing error'), 2000),
    updated_at = now()
  WHERE environment = p_environment
    AND event_id = p_event_id
    AND processing_status = 'processing'
    AND claim_token = p_claim_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_paddle_customer(
  p_environment text,
  p_test_mode boolean,
  p_customer_id text,
  p_user_id text,
  p_email text,
  p_name text,
  p_status text,
  p_paddle_created_at timestamptz,
  p_paddle_updated_at timestamptz,
  p_event_occurred_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing_user_id text;
  existing_paddle_updated_at timestamptz;
  existing_event_occurred_at timestamptz;
  resource_is_newer boolean;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR p_test_mode IS DISTINCT FROM (p_environment = 'sandbox')
     OR p_customer_id NOT LIKE 'ctm\_%' ESCAPE '\'
     OR NULLIF(btrim(p_email), '') IS NULL
     OR NULLIF(btrim(p_status), '') IS NULL
     OR p_paddle_created_at IS NULL
     OR p_paddle_updated_at IS NULL
     OR p_event_occurred_at IS NULL THEN
    RAISE EXCEPTION 'Invalid Paddle customer snapshot';
  END IF;

  SELECT user_id, paddle_updated_at, source_event_occurred_at
  INTO existing_user_id, existing_paddle_updated_at, existing_event_occurred_at
  FROM public.paddle_customers
  WHERE environment = p_environment AND customer_id = p_customer_id;
  resource_is_newer :=
    existing_paddle_updated_at IS NULL
    OR (p_paddle_updated_at, p_event_occurred_at) >=
       (existing_paddle_updated_at, existing_event_occurred_at);
  IF existing_user_id IS NOT NULL
     AND p_user_id IS NOT NULL
     AND existing_user_id <> p_user_id THEN
    RAISE EXCEPTION 'Paddle customer is already bound to another user';
  END IF;

  INSERT INTO public.paddle_customers (
    environment, test_mode, customer_id, user_id, email, name, status,
    paddle_created_at, paddle_updated_at, source_event_occurred_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_customer_id, p_user_id, p_email, p_name, p_status,
    p_paddle_created_at, p_paddle_updated_at, p_event_occurred_at, now()
  )
  ON CONFLICT (environment, customer_id) DO UPDATE SET
    user_id = COALESCE(paddle_customers.user_id, EXCLUDED.user_id),
    email = CASE
      WHEN paddle_customers.paddle_updated_at IS NULL OR
           (EXCLUDED.paddle_updated_at, EXCLUDED.source_event_occurred_at) >=
           (paddle_customers.paddle_updated_at, paddle_customers.source_event_occurred_at)
      THEN EXCLUDED.email ELSE paddle_customers.email END,
    name = CASE
      WHEN paddle_customers.paddle_updated_at IS NULL OR
           (EXCLUDED.paddle_updated_at, EXCLUDED.source_event_occurred_at) >=
           (paddle_customers.paddle_updated_at, paddle_customers.source_event_occurred_at)
      THEN EXCLUDED.name ELSE paddle_customers.name END,
    status = CASE
      WHEN paddle_customers.paddle_updated_at IS NULL OR
           (EXCLUDED.paddle_updated_at, EXCLUDED.source_event_occurred_at) >=
           (paddle_customers.paddle_updated_at, paddle_customers.source_event_occurred_at)
      THEN EXCLUDED.status ELSE paddle_customers.status END,
    paddle_created_at = COALESCE(paddle_customers.paddle_created_at, EXCLUDED.paddle_created_at),
    paddle_updated_at = GREATEST(paddle_customers.paddle_updated_at, EXCLUDED.paddle_updated_at),
    source_event_occurred_at = CASE
      WHEN paddle_customers.paddle_updated_at IS NULL OR
           EXCLUDED.paddle_updated_at >= paddle_customers.paddle_updated_at
      THEN GREATEST(paddle_customers.source_event_occurred_at, EXCLUDED.source_event_occurred_at)
      ELSE paddle_customers.source_event_occurred_at END,
    updated_at = now();

  RETURN resource_is_newer;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_paddle_subscription(
  p_environment text,
  p_test_mode boolean,
  p_subscription_id text,
  p_customer_id text,
  p_user_id text,
  p_transaction_id text,
  p_status text,
  p_price_id text,
  p_product_id text,
  p_current_period_end timestamptz,
  p_scheduled_change_action text,
  p_scheduled_change_at timestamptz,
  p_paddle_created_at timestamptz,
  p_paddle_updated_at timestamptz,
  p_event_occurred_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing_user_id text;
  applied boolean := false;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR p_test_mode IS DISTINCT FROM (p_environment = 'sandbox')
     OR p_subscription_id NOT LIKE 'sub\_%' ESCAPE '\'
     OR p_customer_id NOT LIKE 'ctm\_%' ESCAPE '\'
     OR NULLIF(btrim(p_user_id), '') IS NULL
     OR (p_transaction_id IS NOT NULL AND p_transaction_id NOT LIKE 'txn\_%' ESCAPE '\')
     OR NULLIF(btrim(p_status), '') IS NULL
     OR p_price_id NOT LIKE 'pri\_%' ESCAPE '\'
     OR p_product_id NOT LIKE 'pro\_%' ESCAPE '\'
     OR p_paddle_created_at IS NULL
     OR p_paddle_updated_at IS NULL
     OR p_event_occurred_at IS NULL THEN
    RAISE EXCEPTION 'Invalid Paddle subscription snapshot';
  END IF;

  SELECT user_id INTO existing_user_id
  FROM public.paddle_subscriptions
  WHERE environment = p_environment AND subscription_id = p_subscription_id;
  IF existing_user_id IS NOT NULL AND existing_user_id <> p_user_id THEN
    RAISE EXCEPTION 'Paddle subscription is already bound to another user';
  END IF;

  SELECT user_id INTO existing_user_id
  FROM public.paddle_customers
  WHERE environment = p_environment AND customer_id = p_customer_id;
  IF existing_user_id IS NOT NULL AND existing_user_id <> p_user_id THEN
    RAISE EXCEPTION 'Paddle customer is already bound to another user';
  END IF;

  -- A subscription may arrive before customer.created. Insert a deliberately
  -- partial customer row, then let the customer event fill provider fields.
  INSERT INTO public.paddle_customers (
    environment, test_mode, customer_id, user_id, source_event_occurred_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_customer_id, p_user_id, p_event_occurred_at, now()
  )
  ON CONFLICT (environment, customer_id) DO UPDATE SET
    user_id = COALESCE(paddle_customers.user_id, EXCLUDED.user_id),
    updated_at = now();

  SELECT user_id INTO existing_user_id
  FROM public.paddle_customers
  WHERE environment = p_environment AND customer_id = p_customer_id;
  IF existing_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Paddle customer is already bound to another user';
  END IF;

  INSERT INTO public.paddle_subscriptions (
    environment, test_mode, subscription_id, customer_id, user_id, transaction_id,
    status, price_id, product_id, current_period_end, scheduled_change_action,
    scheduled_change_at, paddle_created_at, paddle_updated_at,
    source_event_occurred_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_subscription_id, p_customer_id, p_user_id,
    p_transaction_id, p_status, p_price_id, p_product_id, p_current_period_end,
    p_scheduled_change_action, p_scheduled_change_at, p_paddle_created_at,
    p_paddle_updated_at, p_event_occurred_at, now()
  )
  ON CONFLICT (environment, subscription_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    user_id = EXCLUDED.user_id,
    transaction_id = COALESCE(EXCLUDED.transaction_id, paddle_subscriptions.transaction_id),
    status = EXCLUDED.status,
    price_id = EXCLUDED.price_id,
    product_id = EXCLUDED.product_id,
    current_period_end = EXCLUDED.current_period_end,
    scheduled_change_action = EXCLUDED.scheduled_change_action,
    scheduled_change_at = EXCLUDED.scheduled_change_at,
    paddle_created_at = EXCLUDED.paddle_created_at,
    paddle_updated_at = EXCLUDED.paddle_updated_at,
    source_event_occurred_at = EXCLUDED.source_event_occurred_at,
    updated_at = now()
  WHERE
    paddle_subscriptions.user_id = EXCLUDED.user_id
    AND (EXCLUDED.paddle_updated_at, EXCLUDED.source_event_occurred_at) >=
        (paddle_subscriptions.paddle_updated_at, paddle_subscriptions.source_event_occurred_at)
  RETURNING true INTO applied;

  SELECT user_id INTO existing_user_id
  FROM public.paddle_subscriptions
  WHERE environment = p_environment AND subscription_id = p_subscription_id;
  IF existing_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Paddle subscription is already bound to another user';
  END IF;

  RETURN COALESCE(applied, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_paddle_transaction(
  p_environment text,
  p_test_mode boolean,
  p_transaction_id text,
  p_customer_id text,
  p_subscription_id text,
  p_user_id text,
  p_status text,
  p_price_id text,
  p_product_id text,
  p_currency_code text,
  p_total text,
  p_paddle_created_at timestamptz,
  p_paddle_updated_at timestamptz,
  p_event_occurred_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing_user_id text;
  existing_customer_id text;
  applied boolean := false;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR p_test_mode IS DISTINCT FROM (p_environment = 'sandbox')
     OR p_transaction_id NOT LIKE 'txn\_%' ESCAPE '\'
     OR p_customer_id NOT LIKE 'ctm\_%' ESCAPE '\'
     OR p_subscription_id NOT LIKE 'sub\_%' ESCAPE '\'
     OR NULLIF(btrim(p_user_id), '') IS NULL
     OR NULLIF(btrim(p_status), '') IS NULL
     OR p_price_id NOT LIKE 'pri\_%' ESCAPE '\'
     OR p_product_id NOT LIKE 'pro\_%' ESCAPE '\'
     OR NULLIF(btrim(p_currency_code), '') IS NULL
     OR p_paddle_created_at IS NULL
     OR p_paddle_updated_at IS NULL
     OR p_event_occurred_at IS NULL THEN
    RAISE EXCEPTION 'Invalid Paddle transaction snapshot';
  END IF;

  SELECT user_id INTO existing_user_id
  FROM public.paddle_transactions
  WHERE environment = p_environment AND transaction_id = p_transaction_id;
  IF existing_user_id IS NOT NULL AND existing_user_id <> p_user_id THEN
    RAISE EXCEPTION 'Paddle transaction is already bound to another user';
  END IF;

  SELECT user_id, customer_id INTO existing_user_id, existing_customer_id
  FROM public.paddle_subscriptions
  WHERE environment = p_environment AND subscription_id = p_subscription_id;
  IF NOT FOUND
     OR existing_user_id IS DISTINCT FROM p_user_id
     OR existing_customer_id IS DISTINCT FROM p_customer_id THEN
    RAISE EXCEPTION 'Paddle transaction does not match its subscription owner';
  END IF;

  SELECT user_id INTO existing_user_id
  FROM public.paddle_customers
  WHERE environment = p_environment AND customer_id = p_customer_id;
  IF existing_user_id IS NOT NULL AND existing_user_id <> p_user_id THEN
    RAISE EXCEPTION 'Paddle customer is already bound to another user';
  END IF;

  INSERT INTO public.paddle_customers (
    environment, test_mode, customer_id, user_id, source_event_occurred_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_customer_id, p_user_id, p_event_occurred_at, now()
  )
  ON CONFLICT (environment, customer_id) DO UPDATE SET
    user_id = COALESCE(paddle_customers.user_id, EXCLUDED.user_id),
    updated_at = now();

  SELECT user_id INTO existing_user_id
  FROM public.paddle_customers
  WHERE environment = p_environment AND customer_id = p_customer_id;
  IF existing_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Paddle customer is already bound to another user';
  END IF;

  INSERT INTO public.paddle_transactions (
    environment, test_mode, transaction_id, customer_id, subscription_id, user_id,
    status, price_id, product_id, currency_code, total, paddle_created_at,
    paddle_updated_at, source_event_occurred_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_transaction_id, p_customer_id, p_subscription_id,
    p_user_id, p_status, p_price_id, p_product_id, p_currency_code, p_total,
    p_paddle_created_at, p_paddle_updated_at, p_event_occurred_at, now()
  )
  ON CONFLICT (environment, transaction_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    subscription_id = EXCLUDED.subscription_id,
    user_id = EXCLUDED.user_id,
    status = EXCLUDED.status,
    price_id = EXCLUDED.price_id,
    product_id = EXCLUDED.product_id,
    currency_code = EXCLUDED.currency_code,
    total = EXCLUDED.total,
    paddle_created_at = EXCLUDED.paddle_created_at,
    paddle_updated_at = EXCLUDED.paddle_updated_at,
    source_event_occurred_at = EXCLUDED.source_event_occurred_at,
    updated_at = now()
  WHERE
    paddle_transactions.user_id = EXCLUDED.user_id
    AND (EXCLUDED.paddle_updated_at, EXCLUDED.source_event_occurred_at) >=
        (paddle_transactions.paddle_updated_at, paddle_transactions.source_event_occurred_at)
  RETURNING true INTO applied;

  SELECT user_id INTO existing_user_id
  FROM public.paddle_transactions
  WHERE environment = p_environment AND transaction_id = p_transaction_id;
  IF existing_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Paddle transaction is already bound to another user';
  END IF;

  RETURN COALESCE(applied, false);
END;
$$;

REVOKE ALL ON FUNCTION public.claim_paddle_webhook_event(text, boolean, text, text, text, text, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_paddle_webhook_event(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fail_paddle_webhook_event(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_paddle_customer(text, boolean, text, text, text, text, text, timestamptz, timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_paddle_subscription(text, boolean, text, text, text, text, text, text, text, timestamptz, text, timestamptz, timestamptz, timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_paddle_transaction(text, boolean, text, text, text, text, text, text, text, text, text, timestamptz, timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_paddle_webhook_event(text, boolean, text, text, text, text, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_paddle_webhook_event(text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_paddle_webhook_event(text, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_paddle_customer(text, boolean, text, text, text, text, text, timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_paddle_subscription(text, boolean, text, text, text, text, text, text, text, timestamptz, text, timestamptz, timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_paddle_transaction(text, boolean, text, text, text, text, text, text, text, text, text, timestamptz, timestamptz, timestamptz) TO service_role;

CREATE OR REPLACE FUNCTION public.paddle_billing_storage_ready()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    to_regclass('public.billing_provider_accounts') IS NOT NULL
    AND to_regclass('public.payment_webhook_events') IS NOT NULL
    AND to_regclass('public.paddle_customers') IS NOT NULL
    AND to_regclass('public.paddle_subscriptions') IS NOT NULL
    AND to_regclass('public.paddle_transactions') IS NOT NULL
    AND to_regclass('public.paddle_webhook_events') IS NOT NULL
    AND to_regclass('public.paddle_checkout_attempts') IS NOT NULL
    AND to_regprocedure(
      'public.claim_paddle_checkout_attempt(text,boolean,text,text)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.reset_paddle_checkout_attempt(text,text,text,text)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.rotate_paddle_ready_checkout_attempt(text,text,text,text,text)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.finalize_paddle_checkout_attempt(text,text,text,text)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.complete_paddle_checkout_attempt(text,text,text)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.claim_paddle_webhook_event(text,boolean,text,text,text,text,timestamptz)'
    ) IS NOT NULL
    AND to_regprocedure('public.complete_paddle_webhook_event(text,text,text)') IS NOT NULL
    AND to_regprocedure('public.fail_paddle_webhook_event(text,text,text,text)') IS NOT NULL
    AND to_regprocedure(
      'public.apply_paddle_customer(text,boolean,text,text,text,text,text,timestamptz,timestamptz,timestamptz)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.apply_paddle_subscription(text,boolean,text,text,text,text,text,text,text,timestamptz,text,timestamptz,timestamptz,timestamptz,timestamptz)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.apply_paddle_transaction(text,boolean,text,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz)'
    ) IS NOT NULL
    AND to_regprocedure(
      'public.apply_paddle_billing_account(text,boolean,text,text,text,text,text,timestamptz,boolean,timestamptz,timestamptz)'
    ) IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.paddle_billing_storage_ready() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.paddle_billing_storage_ready() TO service_role;

REVOKE ALL ON FUNCTION public.claim_paddle_checkout_attempt(text, boolean, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reset_paddle_checkout_attempt(text, text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rotate_paddle_ready_checkout_attempt(text, text, text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_paddle_checkout_attempt(text, text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_paddle_checkout_attempt(text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_paddle_checkout_attempt(text, boolean, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.reset_paddle_checkout_attempt(text, text, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.rotate_paddle_ready_checkout_attempt(text, text, text, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_paddle_checkout_attempt(text, text, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_paddle_checkout_attempt(text, text, text)
  TO service_role;

-- Migration 019 created this SECURITY DEFINER function before the stricter
-- role hardening above. Remove any direct browser-role execute grants too.
REVOKE ALL ON FUNCTION public.apply_paddle_billing_account(
  text, boolean, text, text, text, text, text, timestamptz, boolean,
  timestamptz, timestamptz
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_paddle_billing_account(
  text, boolean, text, text, text, text, text, timestamptz, boolean,
  timestamptz, timestamptz
) TO service_role;

COMMENT ON TABLE public.paddle_customers IS
  'Service-role-only mirror of Paddle customer state, isolated by live/sandbox environment.';
COMMENT ON TABLE public.paddle_subscriptions IS
  'Service-role-only Paddle subscription mirror used for provisioning and portal ownership.';
COMMENT ON TABLE public.paddle_transactions IS
  'Service-role-only mirror of completed Paddle transactions; rows are permanent billing history.';
COMMENT ON TABLE public.paddle_webhook_events IS
  'Atomic, retryable inbox for verified Paddle webhook deliveries.';
COMMENT ON TABLE public.paddle_checkout_attempts IS
  'Permanent per-user Paddle checkout guard that prevents concurrent subscription creation.';

-- Make the new tables and RPC signatures visible to PostgREST immediately.
NOTIFY pgrst, 'reload schema';
