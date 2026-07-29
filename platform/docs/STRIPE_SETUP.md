# AXIO7 Stripe production setup

The application code supports four recurring monthly subscription tiers. Stripe
Checkout collects the payment; a signed webhook updates AXIO7 access; Stripe's
customer portal handles cards, invoices, and cancellation.

## 1. Prepare the Stripe account

Activate and verify the Stripe account using the real business, owner,
representative, tax, address, and payout-bank details. Do not mix test and live
keys or use another person's identity.

In Stripe Dashboard, create four active monthly prices in USD:

1. `AXIO7 Starter`: $59.90/month.
2. `AXIO7 Pro`: $159.90/month.
3. `AXIO7 Premium`: $299.90/month.
4. `AXIO7 Enterprise`: $2,999.90/month.

The names, descriptions, amounts, currencies, and billing interval shown on
`/pricing` are loaded directly from these Stripe Price and Product records.

## 2. Apply the database migration

Run both `supabase/migrations/016_stripe_billing.sql` and
`supabase/migrations/017_stripe_live_mode_isolation.sql` in the production
Supabase project before enabling checkout. The app intentionally refuses to start a
charge if it cannot persist the Stripe customer mapping.

## 3. Configure environment values

Set these in the Vercel project and locally in `.env.local` for testing:

```dotenv
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_STARTER=price_...
STRIPE_PRICE_PRO=price_...
STRIPE_PRICE_PREMIUM=price_...
STRIPE_PRICE_ENTERPRISE=price_...
STRIPE_ALLOW_SANDBOX_ACCESS=false
STRIPE_AUTOMATIC_TAX=false
NEXT_PUBLIC_SITE_URL=https://axio7.com
```

Test-mode keys must use test-mode Price IDs and a test webhook secret. When
launching, replace all of them with live-mode values together.

## 4. Register the production webhook

Create a Stripe webhook destination for:

`https://axio7.com/api/stripe/webhook`

Subscribe it to:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.finalization_failed`
- `charge.refunded`

Copy that destination's signing secret into `STRIPE_WEBHOOK_SECRET`. Webhook
delivery must succeed before considering paid access operational.

For local testing, Stripe CLI can forward signed events:

```powershell
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

Use the temporary `whsec_...` printed by the CLI in local `.env.local`.

## 5. Configure the customer portal and payment methods

Enable Stripe Customer Portal subscription cancellation, invoice history, and
payment-method updates. In Payment methods, enable only methods compatible with
the business country, product, currency, and risk policy. Stripe decides when
wallet buttons such as Apple Pay, Google Pay, and Link are eligible to appear.

If `STRIPE_AUTOMATIC_TAX=true`, first complete Stripe Tax registration and
product tax-code setup. Leave it false until then.

## 6. Production acceptance check

1. Complete one test checkout for each subscription tier.
2. Confirm both webhook deliveries return HTTP 200.
3. Confirm `/billing` shows the correct access.
4. Cancel the monthly subscription in the portal and confirm the end date.
5. Switch all Stripe values to live mode and make a small real purchase with a
   refund afterward.

The provisioning script accepts either `STRIPE_PUBLISHABLE_KEY` or
`NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`. With an activated Live account and
Live keys, run it with `VERCEL_DEPLOY_AFTER_PROVISION=true`; it creates fresh
Live products, prices, portal configuration and webhook, writes the Vercel
variables together, and triggers a production deployment.

Paid features are not globally gated by this change. Use
`billingAccountHasAccess()` wherever a specific AXIO7 feature should require a
paid entitlement.
