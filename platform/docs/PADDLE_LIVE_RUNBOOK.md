# Paddle Live launch and zero-cost test runbook

This runbook is deliberately staged. Stop at the first failed gate; do not work
around an account, product, or domain restriction. The account owner completes
all identity checks and the real checkout personally.

## Current execution status (2026-07-28 UTC)

- The current Live catalog has exactly three Paddle purchase choices: Free monthly,
  Pro monthly, and Annual yearly. The pricing page also exposes a non-checkout
  Enterprise contact tier. The pricing page, checkout backend,
  fulfillment storage, permanent webhook destination, and Production
  environment variables are deployed.
- The account owner confirmed verification is complete, the Live default
  payment link is saved, and `axio7.com` is an approved checkout domain.
- The owner-completed zero-cost Live checkout and lifecycle exercise passed;
  the completion receipt is preserved at the end of this runbook. Its
  single-use discount was archived and must not be reused.
- The first launch attempt exposed an internal reverse-proxy origin in the
  Paddle transaction `checkout.url`. The corrected implementation requires the
  server-only `AXIO7_SITE_URL` in Production.
- The corrected implementation requires the server-only `AXIO7_SITE_URL` in
  Production. Image
  `sha256:ac9986661666ff068ebe8f8907013dde2e9c580bc590c977967eb0d83c4b3d7e`
  is deployed and healthy. The running environment confirms
  `AXIO7_SITE_URL=https://axio7.com`, the checkout origin code contains no
  `localhost:3000`, and an unauthenticated same-origin probe reaches the route
  and returns the expected `401 authentication_required` rather than 403.
- The stale failed attempt had no matching Paddle transaction, and the durable
  checkout-attempt contract prevents a retry from creating a duplicate sale.

## Stage 1: approval and deployment preflight

Before creating or testing anything in Live, confirm:

- Paddle has approved the actual AXIO7 functionality. The approved product must
  not include trade recommendations, trading signals, or other prohibited
  functionality disguised as educational content.
- Business and identity verification show complete in the Paddle dashboard.
- `axio7.com` is an approved Live checkout domain.
- `https://axio7.com/checkout/paddle` is the Live default payment link.
- The current application revision is deployed at `https://axio7.com`.

The account owner must confirm the verification and default-link items in the
dashboard. Checkout cannot be validated on localhost in Live.

## Stage 2: verify that every component is Live

Confirm all of these together; mixed Sandbox/Live configuration is an immediate
stop condition:

- `PADDLE_ENVIRONMENT=live`
- `PADDLE_API_KEY` begins `pdl_live_apikey_`
- `NEXT_PUBLIC_PADDLE_CLIENT_TOKEN` begins `live_`
- the Free, Pro, and Annual Product IDs are valid, distinct `pro_...` IDs
- the three current Price IDs are valid, distinct `pri_...` IDs: Free month,
  Pro month, and Annual year
- the server SDK selects Paddle production (`api.paddle.com`)
- client code contains no `Paddle.Environment.set('sandbox')`
- the permanent notification destination points to
  `https://axio7.com/api/paddle/webhook`
- Production has migrations 018 through 024, including legacy Lifetime fulfillment

Open the deployed pricing page without paying. Verify all three cards and their
Paddle-formatted totals: Free monthly, Pro monthly, and Annual yearly.
Each purchase action must open a one-page overlay for its exact current Price
ID, and Checkout success must target `/welcome`. Confirm all three current
prices have no trial period and no country price overrides.

Historical Starter, Pro, Lifetime, annual, and Advanced Price IDs remain
configured so verified webhooks for existing legacy subscriptions can still reconcile. They are not
public purchase choices and must not participate in current-catalog
completeness. Never delete or archive those historical Paddle entities.

## Stage 3: create the safe Live test discount

Only after Stages 1 and 2 pass, create one dedicated, single-purpose Live
discount:

- 100% percentage discount;
- a unique, unguessable code;
- restricted as tightly as Paddle permits;
- intended only for this one launch test.

Record its `dsc_...` ID and code. The purpose is to create a real zero-total
transaction and subscription, including real webhooks and database records,
without a charge or refund. Do not publish or reuse the code.

If a 100% Live discount cannot exercise this catalog, stop. Discuss alternatives
before charging anything; do not initiate a paid/refund test without the account
owner's explicit decision.

## Stage 4: account-owner checkout handoff

Pause automation here. The account owner must:

1. Sign in on `https://axio7.com`.
2. Open the deployed pricing page.
3. Select one subscription and open Checkout.
4. Apply the dedicated 100% discount code.
5. Confirm the total is zero.
6. Complete Checkout personally with a real card/payment method.
7. Confirm that Paddle redirects to `/welcome`.

No agent or developer should enter card details, impersonate the account owner,
or click the final payment confirmation on their behalf.

## Stage 5: verify fulfillment

After the account owner reports completion, verify all of the following before
changing the subscription:

1. The Paddle transaction is `completed` with a zero total.
2. A Live customer and Live subscription were created.
3. The permanent notification destination received its deliveries and the
   application returned 2xx after successful verification/processing.
4. The service-role-only customer, subscription, transaction, and event mirrors
   contain matching IDs and Live environment markers.
5. The signed-in application user resolves to that Paddle customer server-side.
6. The subscription status is `active`, and the access helper grants the
   selected tier. A current-catalog checkout must not create a trialing
   subscription.
7. The customer portal opens through a newly minted authenticated portal
   session.

Failures are fixed and the affected verification repeated. Do not delete rows or
Paddle entities to force a retry.

## Stage 6: exercise the subscription lifecycle

Use the subscription created in Stage 4. After each operation, verify the Paddle
state, webhook delivery, database mirror, and access result:

1. Upgrade to another catalog plan immediately with proration billing mode
   `do_not_bill`. Confirm the Price/Product IDs change and no charge is created.
2. Schedule cancellation with `effective_from: next_billing_period`. Confirm
   the subscription remains `active`, the scheduled change is stored, and
   access remains granted through the end of the billing period.
3. Cancel with `effective_from: immediately`. Confirm status becomes `canceled`
   and access is denied.

Do not skip the scheduled-cancellation assertion: a pending change alone must
not revoke paid access.

## Stage 7: finish without deleting business history

- Confirm the test subscription is canceled.
- Archive the dedicated 100% discount so it cannot be reused.
- Preserve the test customer, subscription, transaction, webhook deliveries,
  and all database mirrors.
- Preserve the permanent notification destination, its secret, the three
  current products and prices, and every historical predecessor product/price.

Only after every stage passes should Production use
`BILLING_PROVIDER=paddle` for customers generally.

## Live completion receipt -- 2026-07-26 UTC

The owner-completed zero-cost Live test passed end to end:

- Starter monthly Checkout completed with USD total `0`; no agent entered
  payment details or submitted the purchase.
- The checkout attempt and Live customer, transaction, subscription, and
  billing-account mirrors reconciled successfully.
- Paddle delivery logs for the required transaction and subscription events
  report `delivered` with HTTP 200; application event rows were processed once
  with no error.
- Starter monthly was upgraded to Pro monthly using
  `proration_billing_mode=do_not_bill`; no new transaction or charge was
  created, and the Pro price was mirrored.
- End-of-period cancellation kept the subscription `active` and access
  granted while recording the scheduled change.
- Immediate cancellation changed the subscription to `canceled`, cleared the
  scheduled change, and caused the access helper to deny access.
- The single-use 100% discount was used once and archived.
- The real customer, transaction, subscription, notification, and database
  history remains intact. No refund or adjustment was created.
