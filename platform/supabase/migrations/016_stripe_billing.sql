-- Stripe is the payment source of truth. These tables keep only the minimum
-- identifiers and entitlement state AXIO7 needs; no card data is stored here.

CREATE TABLE IF NOT EXISTS public.billing_accounts (
  user_id text PRIMARY KEY,
  email text,
  stripe_customer_id text UNIQUE,
  stripe_subscription_id text UNIQUE,
  subscription_status text,
  stripe_price_id text,
  current_period_end timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  lifetime_access boolean NOT NULL DEFAULT false,
  lifetime_price_id text,
  lifetime_payment_intent_id text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS billing_accounts_subscription_status_idx
  ON public.billing_accounts (subscription_status);

CREATE TABLE IF NOT EXISTS public.stripe_webhook_events (
  event_id text PRIMARY KEY,
  event_type text NOT NULL,
  livemode boolean NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.billing_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;

-- No public policies are intentional. AXIO7 billing reads/writes use the
-- server-only Supabase service role, which bypasses RLS.
