-- Add Paddle as a third isolated payment provider. Migration 018 creates the
-- provider tables and remains the required predecessor to this migration.

ALTER TABLE public.billing_provider_accounts
  DROP CONSTRAINT IF EXISTS billing_provider_accounts_provider_check;

ALTER TABLE public.billing_provider_accounts
  ADD CONSTRAINT billing_provider_accounts_provider_check
  CHECK (provider IN ('stripe', 'lemon_squeezy', 'paddle'));

ALTER TABLE public.payment_webhook_events
  DROP CONSTRAINT IF EXISTS payment_webhook_events_provider_check;

ALTER TABLE public.payment_webhook_events
  ADD CONSTRAINT payment_webhook_events_provider_check
  CHECK (provider IN ('stripe', 'lemon_squeezy', 'paddle'));

COMMENT ON TABLE public.billing_provider_accounts IS
  'Server-only Stripe, Lemon Squeezy, and Paddle entitlement snapshots isolated by provider and test/live environment.';

-- Paddle webhook delivery is at-least-once and events are not guaranteed to
-- arrive in order. Apply each verified subscription snapshot atomically so a
-- delayed event cannot overwrite newer billing state between an application
-- read and write.
CREATE OR REPLACE FUNCTION public.apply_paddle_billing_account(
  p_user_id text,
  p_test_mode boolean,
  p_provider_customer_id text,
  p_provider_subscription_id text,
  p_provider_order_id text,
  p_provider_price_id text,
  p_subscription_status text,
  p_current_period_end timestamptz,
  p_cancel_at_period_end boolean,
  p_provider_created_at timestamptz,
  p_source_updated_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  applied boolean := false;
BEGIN
  IF p_user_id IS NULL OR btrim(p_user_id) = ''
     OR p_provider_customer_id IS NULL OR btrim(p_provider_customer_id) = ''
     OR p_provider_subscription_id IS NULL OR btrim(p_provider_subscription_id) = ''
     OR p_provider_price_id IS NULL OR btrim(p_provider_price_id) = ''
     OR p_subscription_status IS NULL OR btrim(p_subscription_status) = ''
     OR p_provider_created_at IS NULL
     OR p_source_updated_at IS NULL THEN
    RAISE EXCEPTION 'A complete Paddle billing snapshot is required';
  END IF;

  INSERT INTO public.billing_provider_accounts (
    user_id,
    provider,
    test_mode,
    provider_customer_id,
    provider_subscription_id,
    provider_order_id,
    provider_price_id,
    subscription_status,
    current_period_end,
    cancel_at_period_end,
    lifetime_access,
    customer_portal_url,
    provider_created_at,
    source_updated_at,
    updated_at
  )
  VALUES (
    p_user_id,
    'paddle',
    p_test_mode,
    p_provider_customer_id,
    p_provider_subscription_id,
    p_provider_order_id,
    p_provider_price_id,
    p_subscription_status,
    p_current_period_end,
    p_cancel_at_period_end,
    false,
    NULL,
    p_provider_created_at,
    p_source_updated_at,
    now()
  )
  ON CONFLICT (user_id, provider, test_mode) DO UPDATE SET
    provider_customer_id = EXCLUDED.provider_customer_id,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    provider_order_id = COALESCE(
      EXCLUDED.provider_order_id,
      billing_provider_accounts.provider_order_id
    ),
    provider_price_id = EXCLUDED.provider_price_id,
    subscription_status = EXCLUDED.subscription_status,
    current_period_end = EXCLUDED.current_period_end,
    cancel_at_period_end = EXCLUDED.cancel_at_period_end,
    lifetime_access = false,
    customer_portal_url = NULL,
    provider_created_at = EXCLUDED.provider_created_at,
    source_updated_at = EXCLUDED.source_updated_at,
    updated_at = now()
  WHERE
    (
      billing_provider_accounts.provider_subscription_id IS NULL
      OR billing_provider_accounts.provider_subscription_id = EXCLUDED.provider_subscription_id
      OR billing_provider_accounts.provider_created_at IS NULL
      OR EXCLUDED.provider_created_at >= billing_provider_accounts.provider_created_at
    )
    AND (
      billing_provider_accounts.provider_subscription_id IS DISTINCT FROM EXCLUDED.provider_subscription_id
      OR billing_provider_accounts.source_updated_at IS NULL
      OR EXCLUDED.source_updated_at >= billing_provider_accounts.source_updated_at
    )
  RETURNING true INTO applied;

  RETURN COALESCE(applied, false);
END;
$$;

REVOKE ALL ON FUNCTION public.apply_paddle_billing_account(
  text,
  boolean,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  boolean,
  timestamptz,
  timestamptz
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.apply_paddle_billing_account(
  text,
  boolean,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  boolean,
  timestamptz,
  timestamptz
) TO service_role;

CREATE OR REPLACE FUNCTION public.paddle_billing_storage_ready()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT true;
$$;

REVOKE ALL ON FUNCTION public.paddle_billing_storage_ready() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.paddle_billing_storage_ready() TO service_role;
