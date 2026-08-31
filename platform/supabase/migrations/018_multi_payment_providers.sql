-- Keep payment-provider identifiers and entitlements isolated by provider and
-- environment. A Stripe customer/subscription must never collide with a Lemon
-- Squeezy resource, and test purchases must never overwrite live purchases.

CREATE TABLE IF NOT EXISTS public.billing_provider_accounts (
  user_id text NOT NULL,
  provider text NOT NULL,
  test_mode boolean NOT NULL DEFAULT true,
  email text,
  provider_customer_id text,
  provider_subscription_id text,
  provider_order_id text,
  provider_price_id text,
  subscription_status text,
  current_period_end timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  lifetime_access boolean NOT NULL DEFAULT false,
  customer_portal_url text,
  provider_created_at timestamptz,
  source_updated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, provider, test_mode),
  CONSTRAINT billing_provider_accounts_provider_check
    CHECK (provider IN ('stripe', 'lemon_squeezy')),
  CONSTRAINT billing_provider_accounts_customer_unique
    UNIQUE (provider, test_mode, provider_customer_id),
  CONSTRAINT billing_provider_accounts_subscription_unique
    UNIQUE (provider, test_mode, provider_subscription_id),
  CONSTRAINT billing_provider_accounts_order_unique
    UNIQUE (provider, test_mode, provider_order_id)
);

CREATE INDEX IF NOT EXISTS billing_provider_accounts_user_idx
  ON public.billing_provider_accounts (user_id);

CREATE INDEX IF NOT EXISTS billing_provider_accounts_status_idx
  ON public.billing_provider_accounts (provider, test_mode, subscription_status);

CREATE TABLE IF NOT EXISTS public.payment_webhook_events (
  provider text NOT NULL,
  event_id text NOT NULL,
  event_type text NOT NULL,
  test_mode boolean NOT NULL DEFAULT true,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (provider, event_id),
  CONSTRAINT payment_webhook_events_provider_check
    CHECK (provider IN ('stripe', 'lemon_squeezy'))
);

CREATE INDEX IF NOT EXISTS payment_webhook_events_processed_at_idx
  ON public.payment_webhook_events (processed_at);

ALTER TABLE public.billing_provider_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_webhook_events ENABLE ROW LEVEL SECURITY;

-- No public policies are intentional. Billing reads and writes use only the
-- server-side Supabase service role, which bypasses RLS.

-- Preserve already-provisioned Stripe customers and entitlements. The legacy
-- billing_accounts table remains in place so the existing Stripe routes and UI
-- can be deployed independently from this migration.
INSERT INTO public.billing_provider_accounts (
  user_id,
  provider,
  test_mode,
  email,
  provider_customer_id,
  provider_subscription_id,
  provider_order_id,
  provider_price_id,
  subscription_status,
  current_period_end,
  cancel_at_period_end,
  lifetime_access,
  created_at,
  updated_at
)
SELECT
  user_id,
  'stripe',
  NOT stripe_livemode,
  email,
  stripe_customer_id,
  stripe_subscription_id,
  lifetime_payment_intent_id,
  COALESCE(stripe_price_id, lifetime_price_id),
  subscription_status,
  current_period_end,
  cancel_at_period_end,
  lifetime_access,
  created_at,
  updated_at
FROM public.billing_accounts
ON CONFLICT (user_id, provider, test_mode) DO UPDATE SET
  email = EXCLUDED.email,
  provider_customer_id = EXCLUDED.provider_customer_id,
  provider_subscription_id = EXCLUDED.provider_subscription_id,
  provider_order_id = EXCLUDED.provider_order_id,
  provider_price_id = EXCLUDED.provider_price_id,
  subscription_status = EXCLUDED.subscription_status,
  current_period_end = EXCLUDED.current_period_end,
  cancel_at_period_end = EXCLUDED.cancel_at_period_end,
  lifetime_access = EXCLUDED.lifetime_access,
  updated_at = EXCLUDED.updated_at;

INSERT INTO public.payment_webhook_events (
  provider,
  event_id,
  event_type,
  test_mode,
  processed_at
)
SELECT
  'stripe',
  event_id,
  event_type,
  NOT livemode,
  processed_at
FROM public.stripe_webhook_events
ON CONFLICT (provider, event_id) DO NOTHING;

COMMENT ON TABLE public.billing_provider_accounts IS
  'Server-only provider identifiers and entitlement snapshots, isolated by provider and test/live environment.';

COMMENT ON COLUMN public.billing_provider_accounts.test_mode IS
  'True for sandbox/test purchases. Test rows cannot grant production access unless explicitly enabled.';

COMMENT ON COLUMN public.billing_provider_accounts.customer_portal_url IS
  'Provider-hosted customer portal URL, if supplied by the verified provider webhook.';
