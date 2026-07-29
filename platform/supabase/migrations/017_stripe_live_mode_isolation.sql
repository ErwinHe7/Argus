-- Sandbox and live Stripe objects are isolated. Track the mode that owns the
-- current customer/subscription mapping so a test customer can never be reused
-- for a real charge or grant production paid access.

ALTER TABLE public.billing_accounts
  ADD COLUMN IF NOT EXISTS stripe_livemode boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS billing_accounts_stripe_livemode_idx
  ON public.billing_accounts (stripe_livemode);

COMMENT ON COLUMN public.billing_accounts.stripe_livemode IS
  'True only when the stored Stripe customer and entitlement came from live mode.';
