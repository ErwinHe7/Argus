-- Support the public AXIO7 Lifetime tier as a one-time Paddle transaction.
-- Subscription transactions keep their existing fulfillment path. A one-time
-- transaction may omit subscription_id only when the application has already
-- validated it against the configured Lifetime price.

ALTER TABLE public.paddle_transactions
  DROP CONSTRAINT IF EXISTS paddle_transactions_subscription_fk,
  DROP CONSTRAINT IF EXISTS paddle_transactions_subscription_id_check;

ALTER TABLE public.paddle_transactions
  ALTER COLUMN subscription_id DROP NOT NULL;

ALTER TABLE public.paddle_transactions
  ADD CONSTRAINT paddle_transactions_subscription_id_check
    CHECK (subscription_id IS NULL OR subscription_id LIKE 'sub\_%' ESCAPE '\'),
  ADD CONSTRAINT paddle_transactions_subscription_fk
    FOREIGN KEY (environment, subscription_id)
    REFERENCES public.paddle_subscriptions (environment, subscription_id);

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
     OR (p_subscription_id IS NOT NULL AND p_subscription_id NOT LIKE 'sub\_%' ESCAPE '\')
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

  IF p_subscription_id IS NOT NULL THEN
    SELECT user_id, customer_id INTO existing_user_id, existing_customer_id
    FROM public.paddle_subscriptions
    WHERE environment = p_environment AND subscription_id = p_subscription_id;
    IF NOT FOUND
       OR existing_user_id IS DISTINCT FROM p_user_id
       OR existing_customer_id IS DISTINCT FROM p_customer_id THEN
      RAISE EXCEPTION 'Paddle transaction does not match its subscription owner';
    END IF;
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

CREATE OR REPLACE FUNCTION public.apply_paddle_lifetime_billing_account(
  p_user_id text,
  p_test_mode boolean,
  p_provider_customer_id text,
  p_provider_order_id text,
  p_provider_price_id text,
  p_provider_created_at timestamptz,
  p_source_updated_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  transaction_owner text;
  transaction_customer text;
  transaction_price text;
  transaction_subscription text;
  transaction_status text;
  applied boolean := false;
BEGIN
  IF NULLIF(btrim(p_user_id), '') IS NULL
     OR p_provider_customer_id NOT LIKE 'ctm\_%' ESCAPE '\'
     OR p_provider_order_id NOT LIKE 'txn\_%' ESCAPE '\'
     OR p_provider_price_id NOT LIKE 'pri\_%' ESCAPE '\'
     OR p_provider_created_at IS NULL
     OR p_source_updated_at IS NULL THEN
    RAISE EXCEPTION 'A complete Paddle lifetime snapshot is required';
  END IF;

  SELECT user_id, customer_id, price_id, subscription_id, status
  INTO transaction_owner, transaction_customer, transaction_price,
       transaction_subscription, transaction_status
  FROM public.paddle_transactions
  WHERE environment = CASE WHEN p_test_mode THEN 'sandbox' ELSE 'live' END
    AND transaction_id = p_provider_order_id;

  IF NOT FOUND
     OR transaction_owner IS DISTINCT FROM p_user_id
     OR transaction_customer IS DISTINCT FROM p_provider_customer_id
     OR transaction_price IS DISTINCT FROM p_provider_price_id
     OR transaction_subscription IS NOT NULL
     OR transaction_status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'Paddle lifetime entitlement does not match its completed transaction';
  END IF;

  INSERT INTO public.billing_provider_accounts (
    user_id, provider, test_mode, provider_customer_id,
    provider_subscription_id, provider_order_id, provider_price_id,
    subscription_status, current_period_end, cancel_at_period_end,
    lifetime_access, customer_portal_url, provider_created_at,
    source_updated_at, refund_status, refund_transaction_id,
    refund_subscription_id, refund_updated_at, updated_at
  ) VALUES (
    p_user_id, 'paddle', p_test_mode, p_provider_customer_id,
    NULL, p_provider_order_id, p_provider_price_id,
    'completed', NULL, false,
    true, NULL, p_provider_created_at,
    p_source_updated_at, NULL, NULL,
    NULL, NULL, now()
  )
  ON CONFLICT (user_id, provider, test_mode) DO UPDATE SET
    provider_customer_id = EXCLUDED.provider_customer_id,
    provider_subscription_id = NULL,
    provider_order_id = EXCLUDED.provider_order_id,
    provider_price_id = EXCLUDED.provider_price_id,
    subscription_status = EXCLUDED.subscription_status,
    current_period_end = NULL,
    cancel_at_period_end = false,
    lifetime_access = true,
    customer_portal_url = NULL,
    provider_created_at = EXCLUDED.provider_created_at,
    source_updated_at = EXCLUDED.source_updated_at,
    refund_status = NULL,
    refund_transaction_id = NULL,
    refund_subscription_id = NULL,
    refund_updated_at = NULL,
    updated_at = now()
  WHERE
    billing_provider_accounts.provider_subscription_id IS NULL
    AND (
      billing_provider_accounts.source_updated_at IS NULL
      OR EXCLUDED.source_updated_at >= billing_provider_accounts.source_updated_at
    )
  RETURNING true INTO applied;

  RETURN COALESCE(applied, false);
END;
$$;

REVOKE ALL ON FUNCTION public.apply_paddle_transaction(
  text, boolean, text, text, text, text, text, text, text, text, text,
  timestamptz, timestamptz, timestamptz
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_paddle_transaction(
  text, boolean, text, text, text, text, text, text, text, text, text,
  timestamptz, timestamptz, timestamptz
) TO service_role;

REVOKE ALL ON FUNCTION public.apply_paddle_lifetime_billing_account(
  text, boolean, text, text, text, timestamptz, timestamptz
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_paddle_lifetime_billing_account(
  text, boolean, text, text, text, timestamptz, timestamptz
) TO service_role;

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
    AND to_regclass('public.billing_usage_events') IS NOT NULL
    AND to_regprocedure(
      'public.apply_paddle_lifetime_billing_account(text,boolean,text,text,text,timestamptz,timestamptz)'
    ) IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.paddle_billing_storage_ready() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.paddle_billing_storage_ready() TO service_role;

NOTIFY pgrst, 'reload schema';
