# AXIO7 Paddle Billing setup

AXIO7's Paddle integration uses Paddle Billing for three recurring SaaS plans,
Paddle.js for localized price previews and hosted checkout, signed server-side webhooks
for fulfillment, and Paddle's hosted customer portal. The browser never
receives the Paddle API key, notification signing secret, customer ID, or an
untrusted Price ID.

## Approval gate: do not disguise the product

Paddle must approve the seller identity, actual product, and Live checkout
domain before AXIO7 enables Live checkout. Paddle's Acceptable Use Policy can
exclude investment advice, trading recommendations, signals, and strategies.
Removing those capabilities is a product requirement, not a wording exercise:
do not relabel or conceal restricted functionality as "educational" to bypass
review. Keep `BILLING_PROVIDER` on the currently approved provider until Paddle
has approved what AXIO7 actually delivers.

Code integration does not approve an account or make it eligible for payouts.
Payout-bank and identity details belong only in Paddle's dashboard; they are not
application credentials and must never be committed to this repository.

Official references:

- [Create products and prices](https://developer.paddle.com/build/products/create-products-prices/)
- [Localized pricing page](https://developer.paddle.com/build/checkout/build-pricing-page/)
- [Default payment link](https://developer.paddle.com/build/transactions/default-payment-link/)
- [Webhook signature verification](https://developer.paddle.com/webhooks/about/signature-verification/)
- [Provision subscription access](https://developer.paddle.com/build/subscriptions/provision-access-webhooks/)
- [Customer portal sessions](https://developer.paddle.com/api-reference/customer-portals/create-customer-portal-session/)
- [Paddle Acceptable Use Policy](https://www.paddle.com/legal/acceptable-use/)

## Permanent Live catalog

The public Paddle catalog contains exactly three current `pro_...` products and
three current `pri_...` prices. Every current price is recurring, quantity one,
denominated in USD, has no country price overrides, and has no free trial.

Paddle API amounts are strings in the currency's lowest denomination. For
example, USD 50.00 is `"5000"`, not `"50"` or `"50.00"`.

| Product | Cadence | USD | Price environment variable |
| --- | --- | ---: | --- |
| Free | month | $0 (`0`) | `PADDLE_PRICE_FREE_MONTH` |
| Pro | month | $69 (`6900`) | `PADDLE_PRICE_PRO_MONTH` |
| Annual | year | $699 (`69900`) | `PADDLE_PRICE_ANNUAL_YEAR` |

The current production IDs are recorded in
[`docs/PADDLE_LIVE_CATALOG.md`](./PADDLE_LIVE_CATALOG.md). Keep credentials out
of that file and copy the IDs into encrypted deployment environment variables.

Product IDs are configured separately:

```env
PADDLE_PRODUCT_FREE=pro_...
PADDLE_PRODUCT_PRO=pro_...
PADDLE_PRODUCT_ANNUAL=pro_...
```

Do not create duplicates manually. After all Live approval gates pass, provision
or read back the catalog with the idempotent script:

```powershell
$env:PADDLE_ENVIRONMENT = 'live'
$env:PADDLE_API_KEY = 'pdl_live_apikey_...'
$env:PADDLE_CATALOG_CREATE_CONFIRM = 'CREATE_AXIO7_LIVE_CATALOG'
npm run paddle:catalog
```

The script keeps one stable product identity per tier and versions price
entities separately. A price revision therefore reuses the product, creates a
new immutable price when needed, and never archives or deletes an old price.
It also recognizes an exact current product/price created through an approved
dashboard or API workflow, so reruns do not duplicate the USD/no-trial catalog.
It prints the complete three-product/three-current-price mapping. Run it only
after approval. Copy its output into
Vercel's encrypted environment settings; do not paste credentials into chat or
source control.

After the webhook route is deployed on the approved domain, the companion
idempotent command can create or update the permanent Live client token and
notification destination without deleting either:

```powershell
$env:PADDLE_ENVIRONMENT = 'live'
$env:PADDLE_API_KEY = 'pdl_live_apikey_...'
$env:NEXT_PUBLIC_SITE_URL = 'https://axio7.com'
$env:PADDLE_LIVE_INFRA_CONFIRM = 'CREATE_AXIO7_LIVE_INFRA'
npm run paddle:live-infra
```

Store its token and signing-secret output directly in Vercel encrypted
environment settings. Treat the notification destination as permanent.

## Required environment variables

`PADDLE_ENVIRONMENT` has no default. It must be explicitly `sandbox` or `live`,
and the application must fail loudly when it is missing or does not match the
credential prefixes.

```env
BILLING_PROVIDER=paddle
PADDLE_ENVIRONMENT=live
PADDLE_API_KEY=pdl_live_apikey_...
PADDLE_NOTIFICATION_WEBHOOK_SECRET=pdl_ntfset_...
NEXT_PUBLIC_PADDLE_CLIENT_TOKEN=live_...

PADDLE_PRODUCT_STARTER=pro_...
PADDLE_PRICE_STARTER_MONTH=pri_...
PADDLE_PRICE_STARTER_YEAR=pri_...
PADDLE_PRODUCT_PRO=pro_...
PADDLE_PRICE_PRO_MONTH=pri_...
PADDLE_PRICE_PRO_YEAR=pri_...
PADDLE_PRODUCT_ADVANCED=pro_...
PADDLE_PRICE_ADVANCED_MONTH=pri_...
PADDLE_PRICE_ADVANCED_YEAR=pri_...

PADDLE_ALLOW_SANDBOX_ACCESS=false
```

- `PADDLE_API_KEY` is server-only. Live keys begin `pdl_live_apikey_`.
- `PADDLE_NOTIFICATION_WEBHOOK_SECRET` is the notification destination's
  signing secret, not the API key, and is server-only.
- `NEXT_PUBLIC_PADDLE_CLIENT_TOKEN` is browser-safe; the Live token must begin
  `live_`.
- `BILLING_PROVIDER=paddle` switches the public Subscribe flow. Do not set this
  in Production until the Live checkout smoke test has passed.

## Pricing and Checkout contract

The pricing page must keep Paddle as the source of truth for displayed totals:

- The server reads `x-vercel-ip-country` and passes a valid two-letter country
  code when present. This is used for address, tax, and payment-method context,
  never to select a country price override. When absent, it passes no country
  code so Paddle can detect location from the visitor's IP. An app-only sentinel
  such as `OTHERS` must never be sent to Paddle.
- The client calls `Paddle.PricePreview()` for the selected monthly or yearly
  Price IDs without forcing a currency and displays Paddle's `formattedTotals`
  values verbatim. It does not calculate, round, convert, or run the result
  through `Intl.NumberFormat`. Paddle applies a country override first, then an
  enabled automatic currency conversion, and otherwise returns the USD base
  price.
- Subscribe calls `Paddle.Checkout.open()` with `settings.displayMode` set to
  `overlay` and `settings.variant` set to `one-page`, using the exact Price ID
  whose preview is on screen.
- The server attaches the signed-in user's Paddle customer (including their
  verified account email) to the transaction, so Checkout inherits the email.
  No client-supplied customer ID is trusted. Successful Checkout redirects to
  `/welcome`.
- The server API key and notification signing secret never appear in a
  `'use client'` module or a `NEXT_PUBLIC_*` variable.

## Database migrations

Apply these migrations in order to the production Supabase project:

1. `supabase/migrations/018_multi_payment_providers.sql`
2. `supabase/migrations/019_paddle_billing.sql`
3. `supabase/migrations/020_paddle_fulfillment.sql`
4. `supabase/migrations/021_paddle_checkout_abandonment.sql`

Migration 020 adds service-role-only mirrors for customers, subscriptions, and
transactions, plus an atomic webhook inbox. Provider timestamps prevent older
or retried deliveries from rolling current state backward. Migration 021 lets
an authenticated user close an unpaid Checkout and choose another plan without
deleting the canceled Paddle transaction or allowing a stale browser event to
cancel a newer Checkout.

## Live dashboard steps that require the account owner

These steps cannot safely be inferred or completed from application code:

Use these exact website-verification values:

- Web domain: `axio7.com` (domain only, with no protocol, slash, or path)
- Pricing page: `https://axio7.com/pricing`
- Terms of service: `https://axio7.com/terms`
- Privacy policy: `https://axio7.com/privacy`
- Refund policy: `https://axio7.com/refunds`

1. Finish business and identity verification in Paddle Live.
2. Under **Checkout > Checkout settings**, submit `axio7.com` as a Live checkout
   domain and wait until its status is `approved`.
3. To show non-USD local currencies, enable the desired automatic conversions
   under **Business account > Currencies**. The current Live account has zero
   active conversions and no country overrides, so Paddle correctly falls back
   to the USD base prices until this dashboard setting changes.
4. In the same Checkout settings area, set the default payment link to the
   deployed Paddle.js page, `https://axio7.com/checkout/paddle`. Paddle appends
   its `_ptxn` transaction parameter to this URL. Live cannot use localhost.
5. Under **Developer tools > Authentication**, create a least-privilege Live API
   key and a Live client-side token. The API key needs read/write access for
   products, prices, customers, addresses, transactions, client-side tokens,
   and notification settings; read access for subscriptions; and write access
   for customer portal sessions.
6. Under **Developer tools > Notifications**, create the permanent destination
   `https://axio7.com/api/paddle/webhook`, then copy its signing secret directly
   to Vercel.

The permanent notification destination must include at least:

- `customer.created`
- `customer.updated`
- `subscription.created`
- `subscription.updated`
- `subscription.canceled`
- `transaction.completed`

Also subscribe to the status events used by AXIO7's access mirror, including
legacy or externally changed subscriptions: `subscription.activated`, `subscription.trialing`,
`subscription.past_due`, `subscription.paused`, and `subscription.resumed`.

The handler verifies `Paddle-Signature` against the untouched raw request body
before parsing or provisioning. Invalid signatures and processing failures must
return non-2xx so Paddle retries. A browser-side Checkout success event never
grants paid access.

## Entitlement and portal rules

- Current AXIO7 catalog prices have no trial. `active` grants access;
  `trialing` remains access-granting only for defensive handling of legacy or
  externally changed subscriptions.
- A pending scheduled cancellation does not revoke access while status remains
  `active`.
- `canceled` revokes access. `paused` and `past_due` follow the access policy in
  the server-side billing helper.
- The portal route authenticates first and resolves the Paddle customer ID from
  service-role-only storage. It never accepts a client-supplied customer ID.

## Permanent-entity rule

Never delete or offer to clean up the following, in Paddle or Supabase:

- the notification destination or its signing secret;
- the three products and six prices;
- any customer, subscription, transaction, webhook, or mirrored billing row.

These are production infrastructure and auditable business history. Even a test
subscription is canceled, never deleted. The only later cleanup in the approved
Live test is archiving the dedicated 100% test discount after the test has
finished.

The exact production validation sequence is in
[`docs/PADDLE_LIVE_RUNBOOK.md`](./PADDLE_LIVE_RUNBOOK.md).
