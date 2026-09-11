# Leo Whop billing

The isolated `leo-whop-billing` Worker creates hosted checkouts for the owner's
existing AXIO7 Live Trading product and verifies Whop membership status for the
signed-in Leo account. Google sign-in remains in the existing Leo Supabase project.
Paddle, existing memberships, research services and trading permissions are unchanged.

## Contract

| Endpoint | Access | Result |
| --- | --- | --- |
| `GET /health` | Public | Configuration presence, schema and disabled live-trading boundary; no credentials |
| `GET /status` | Verified Google Supabase bearer + exact Leo origin | `provider`, `status`, `checkedAt`, `cancelAtPeriodEnd`, `renewalPeriodEnd` |
| `POST /checkout` | Same identity/origin; empty body | Server-created HTTPS Whop checkout URL |
| `POST /webhook` | Whop raw-body HMAC + timestamp | Idempotent ingestion; no browser authority |

Only `https://leo.axio7.workers.dev` is currently permitted as the browser origin.
Custom-domain cutover must explicitly update the origin and callback configuration.
The API has no arbitrary charge, refund, cancellation, order or broker endpoint.
Cancellation and receipts remain at [Whop Orders](https://whop.com/@me/settings/orders/).

The fixed plan is `plan_lx8Xc92y4i1Mg`, product `prod_CxrnkRxYwMyY4`, account
`biz_ZtGv6nIHwM9GUh`. Before creating checkout, the server verifies USD 99.99,
30-day recurring billing, no initial fee and no trial. A changed price or product
requires an intentional reviewed update. Users confirm the total, including any
tax, on Whop. No payment is taken by the website itself.

## Identity and evidence

Supabase `/auth/v1/user` verifies each private request. Anonymous and non-Google
identities are rejected. The browser cannot supply an owner or plan. Each checkout
first reserves a random 256-bit reference in D1 for the verified owner; only that
reference is included in Whop metadata. Payment/membership records inherit the
reference. A membership's owner and reference cannot be changed by an upsert.
Secrets are Worker secrets and never enter UI bundles, logs or commits.

Webhook HMAC uses the exact raw body and raw `ws_...` secret with SHA-256, WebCrypto
verification and a five-minute timestamp tolerance. Persisted event IDs prevent
replay. Unrelated business/test events are acknowledged without granting access.
Relevant unresolved records remain retryable. Reads always retrieve current Whop
membership state, so delayed events and checkout redirects cannot grant access.
Only current `active` membership with an unexpired recurring period displays active.
Cancellation at period end preserves access through the confirmed period.

Status also queries payments belonging to the owner's checkout configurations to
recover missed webhooks. Recovery covers up to 20 configurations and 100 payments
per configuration; missing pagination metadata or additional results returns
unavailable and blocks checkout. It never silently reports no subscription after
a truncated scan. Increase coverage through a reviewed paginated implementation
before scaling beyond these explicit limits. A pending/unverifiable payment also
blocks another checkout. The server reuses a recent checkout and rate-limits new
checkout requests to three per hour per owner; status allows 30 requests/minute.

This release links purchases initiated on the Leo membership page. Older Whop
subscriptions and Paddle subscriptions remain managed through their existing
portals; they are not automatically migrated or assigned by email. Existing
Whop customers should check Orders before buying again. This membership record
does not change research access or authorize live trading.

## Vendor versions verified on September 11, 2026

- Membership retrieve uses `Api-Version-Date: 2026-09-11`: flat `account`,
  `product_id`, `plan_id`, `current_period_end` and `metadata` fields. The live API
  differs from portions of the generated OpenAPI examples.
- Payment lists explicitly use **2026-09-02**. The live current API rejects
  `checkout_configuration_ids`; Whop's response instructs callers to stay pinned
  before `2026-09-02-1`. The earlier supported pin accepts this filter and returns
  explicit `page_info.has_next_page`.
- Checkout configurations use 2026-09-11 and return `https://whop.com/checkout/ch_…/`.
- The dashboard-created webhook is v1, with both documented account-envelope
  variants accepted. Nine events: membership activated/deactivated/cancel-at-period-end,
  payment succeeded/failed, refund created/updated, dispute created/updated.
- The older `https://axio7.com/api/whop/webhook` and both older API keys were preserved.

Sources: [Whop webhook verification](https://docs.whop.com/developer/guides/webhooks),
[API versioning](https://docs.whop.com/developer/api/versioning),
[membership API](https://docs.whop.com/api-reference/memberships/retrieve-membership),
[D1 transactions](https://developers.cloudflare.com/d1/worker-api/d1-database/).

## Deployment and recovery

Use the checked-in Wrangler configuration and migration. Required server secrets:
`WHOP_API_KEY` and `WHOP_WEBHOOK_SECRET`. The dedicated API key has only checkout
configuration read/create, member read/email, payment read, and plan read scopes.
No charge, refund, member mutation, plan mutation or webhook-management scopes.
The owner's Windows setup retains encrypted DPAPI copies under `%LOCALAPPDATA%/LeoBilling`.
Do not print or commit these files. Vendor broker credentials are unrelated.

```powershell
# From platform/workers/whop-billing, with Wrangler available:
wrangler types
wrangler d1 migrations apply leo-whop-billing --remote
wrangler deploy --dry-run
wrangler deploy --keep-vars
```

Use a supported local workerd version for the configured compatibility date. The
development host's older workerd was exercised with a 2026-09-04 override; the
production Worker runs the pinned 2026-09-11 date. `entry.ts` exports only the
Worker handler. HTTP redirects are returned manually and rejected before parsing
data, avoiding credential forwarding and runtime-specific redirect-error behavior.

No VPS or LLM is required for checkout or membership verification. The Worker and
D1 operate on demand. Billing failures display unavailable, preserve the UI's last
confirmation, and leave public research and local broker controls functional.
Inspect Whop deliveries and `/health` first; replay failed events only after fixing
the cause. Never manufacture an active status or silently infer a paid entitlement.
For rollback, deploy a reviewed prior Worker version and the prior web overlay;
preserve D1 records and existing vendor subscriptions.

## Release evidence

September 11 release: web `5cba2277-a96f-4bd6-b5d5-4fc94b3d6fce`, billing Worker
`d31da722-52b3-49c4-979d-5a1287412f59`. The web overlay changes only desk.js/css and
preserves 2,583 frozen backend files, all broker downloads, services and Google
configuration. `leoinvesting.com` remains a separate, incomplete domain cutover.

Verification: 12 Worker tests with actual SQLite queries; six UI API tests; eight
auth contract tests; 16 browser groups; 18 existing billing contracts; scoped
TypeScript/build; 18 web production checks; seven billing HTTP checks; 22 domain
proxy tests. Whop's own signed synthetic activation event returned HTTP 200 and
was ignored without granting access. An actual existing Google session verified
successfully and opened the correct hosted Whop checkout showing $99.99/month.
The Subscribe action was not taken: a paid purchase/refund lifecycle remains
unperformed. Broker login and a broker-backed paper lifecycle are also separate.

Run the backend tests from the publication repository root:

```powershell
node --import ./platform/node_modules/tsx/dist/loader.mjs --test platform/workers/whop-billing/billing.test.ts
node platform/node_modules/typescript/bin/tsc --noEmit -p platform/workers/whop-billing/tsconfig.json
```
