# AXIO7 Lemon Squeezy payment setup

AXIO7 supports Lemon Squeezy as a hosted subscription checkout and keeps the
existing Stripe integration as a fallback. Card details never pass through the
AXIO7 server.

## What the account owner must complete

1. Create and verify a Lemon Squeezy store using the account owner's real legal,
   tax, address, and payout information.
2. Ask Lemon Squeezy to approve AXIO7's actual product and functionality before
   accepting live orders. Describe the product truthfully; a label such as
   "educational" does not override the provider's acceptable-use review.
3. Complete the tax form Lemon Squeezy assigns to the account. A person who is
   genuinely non-US for US tax purposes normally completes the applicable W-8;
   a US person completes W-9 and supplies the required TIN. Do not select W-8
   merely because an SSN is unavailable.
4. Configure an eligible bank payout account or a verified PayPal account in the
   store dashboard. Payout support depends on the seller's actual country.

The payment-provider account review and any F-1 work-authorization question are
separate. AXIO7 does not collect or store identity documents, SSNs, tax forms,
or payout-bank credentials.

## Products and prices

Create four **monthly subscription** variants in the approved store:

| AXIO7 plan | Monthly price | Server variable |
| --- | ---: | --- |
| Starter | USD 59.90 | `LEMONSQUEEZY_VARIANT_STARTER` |
| Pro | USD 159.90 | `LEMONSQUEEZY_VARIANT_PRO` |
| Premium | USD 299.90 | `LEMONSQUEEZY_VARIANT_PREMIUM` |
| Enterprise | USD 2,999.90 | `LEMONSQUEEZY_VARIANT_ENTERPRISE` |

The browser sends only a plan key. The AXIO7 server maps that key to one of the
four configured Variant IDs, so a customer cannot submit their own price.

## Required server variables

Add these as Vercel Production environment variables. API and webhook secrets
must be marked Sensitive and must never use the `NEXT_PUBLIC_` prefix.

```dotenv
BILLING_PROVIDER=lemonsqueezy
LEMONSQUEEZY_API_KEY=...
LEMONSQUEEZY_STORE_ID=...
LEMONSQUEEZY_WEBHOOK_SECRET=...
LEMONSQUEEZY_VARIANT_STARTER=...
LEMONSQUEEZY_VARIANT_PRO=...
LEMONSQUEEZY_VARIANT_PREMIUM=...
LEMONSQUEEZY_VARIANT_ENTERPRISE=...
LEMONSQUEEZY_TEST_MODE=false
LEMONSQUEEZY_ALLOW_TEST_ACCESS=false
```

Keep `LEMONSQUEEZY_TEST_MODE=true` during sandbox testing. Test and live objects
are isolated and test purchases do not grant production access.

## Webhook

Create a Lemon Squeezy webhook with this URL:

```text
https://axio7.com/api/lemonsqueezy/webhook
```

Use a new random signing secret (32 bytes or more). Subscribe at minimum to:

- `subscription_created`
- `subscription_updated`
- `subscription_cancelled`
- `subscription_resumed`
- `subscription_expired`
- `subscription_paused`
- `subscription_unpaused`
- `subscription_payment_success`
- `subscription_payment_failed`
- `subscription_payment_recovered`
- `subscription_payment_refunded`

The server verifies the raw-body HMAC signature and checks the event name,
store, test/live mode, and configured Variant ID before changing access. It then
retrieves the current subscription from Lemon Squeezy to avoid stale webhook
delivery order.

## Database and release order

1. Apply `supabase/migrations/018_multi_payment_providers.sql` to the production
   Supabase project.
2. Deploy the application while keeping `BILLING_PROVIDER=stripe`.
3. Configure Lemon Squeezy test variables and verify a complete test checkout,
   webhook delivery, access update, and Customer Portal redirect.
4. Complete store activation and product approval.
5. Replace every test resource with its live counterpart, set
   `LEMONSQUEEZY_TEST_MODE=false`, then switch `BILLING_PROVIDER=lemonsqueezy`
   and redeploy.

The checkout route fails closed if the database migration, signing secret, API
key, store, or selected Variant ID is missing.
