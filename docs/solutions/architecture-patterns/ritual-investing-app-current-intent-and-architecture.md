---
title: "Argus Member App: Product Intent and Current Authority"
date: 2026-08-28
category: architecture-patterns
module: ritual-investing-app
problem_type: architecture_pattern
component: frontend
severity: high
applies_when:
  - "changing member identity, brokerage, or application data flows"
  - "changing top-level navigation or financial actions"
  - "reviewing Demo, evidence, freshness, or Rowan behavior"
  - "migrating Auth0, Neon, Cloudflare compute, Queues, or R2"
related_components:
  - "ritual-investing-api"
  - "ritual-investing-admin"
  - "ritual-investing-demo"
  - "ritual-investing-site"
  - "supabase"
tags:
  - "ritual-investing"
  - "flutter"
  - "webull-connect"
  - "supabase"
  - "product-authority"
  - "standalone-demo"
  - "current-state"
---

# Argus Member App: Product Intent and Current Authority

## Current state

The replacement-first repository migration is implemented. The current runtime no longer contains Auth0 identity, a Neon application schema, Cloudflare backend request handling, Cloudflare Queues or Cron, R2 application objects, or server-authoritative simulated finance. Supabase is the only Argus backend authority, and Cloudflare Pages is limited to the static landing and standalone Demo artifacts.

All existing database contents are synthetic and the product is not live, so the Supabase baseline starts clean: there is no data copy, dual-write, shadow-read, or obsolete mobile-route compatibility layer. The generated Hono/Zod OpenAPI contract and Dart client are the controlled client boundary. Real Webull egress and order mutation remain fail-closed until the partner-confirmed sandbox and hosted acceptance gates pass.

## Product authority

Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders. Argus does not create a cash, position, fill, settlement, tax-lot, transaction, or statement ledger. It stores timestamped, per-resource projections so members can understand provider state without mistaking Argus for the brokerage record.

Argus is authoritative for ritual, editorial, community, preference, and privacy state. This includes Daily Ritual, discovery, Asset Codex, Circle, Grimoire, Founders' Coven, profiles, preferences, consent, Intentions, Future Mirror scenarios, notifications, privacy operations, moderation, and editorial workflow. Intentions and Future Mirror are explanatory scenarios, not financial commands or provider truth.

Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Application and brokerage relations live in non-exposed schemas and are served through the versioned Argus API. Flutter and the admin app use Supabase directly only for Auth and explicitly approved private Storage transport; they do not use the Data API for application data.

The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated. It is built from `ritual-investing-demo/`, has no durable browser state, and makes no Supabase, Webull, Auth0, Neon, or Cloudflare compute request. Production never imports its fixtures or reset behavior.

Cloudflare Pages serves only static landing and standalone Demo assets. Pages Functions, `_worker.js`, Worker routes, bindings, Queues, Cron, R2, auth, and stateful request handling are prohibited in the released Pages artifacts. A retained waitlist posts from the static landing page to a narrowly scoped Supabase Edge Function.

## Runtime shape

```text
Flutter member app                 Flutter admin app
        |                                  |
        | Supabase Auth + generated Argus API
        v                                  v
portable Hono/Zod application core and domain services
        |
        | injected runtime ports
        v
Supabase Edge Functions -> private Supabase Postgres
        |                 -> private Queues/Cron workers
        |                 -> private Storage
        |
        +-> Webull Connect (server-only authorization and brokerage calls)

Cloudflare Pages -> static landing assets + network-isolated Demo assets
```

`ritual-investing-api` owns contracts, domains, application services, and portable runtime ports. `supabase/functions/**` owns Deno/Supabase adapters, Webull HTTP and signing, secret access, and deploy entrypoints. The portable core must not import Cloudflare bindings, Auth0, Neon, R2, Wrangler, or Supabase function modules.

## Member behavior

### Identity and connection are independent

A member may sign up, restore, reauthenticate, sign out, and use every non-brokerage Argus surface without connecting Webull. A Webull authorization is a separate, server-owned lifecycle with explicit connected, denied, failed, disconnected, temporarily unavailable, and reauthorization-required states. Webull credentials, authorization codes, signing material, and raw provider payloads never reach Flutter, logs, analytics, exports, public database objects, or queue messages.

Disconnect and Argus deletion require a current-session, action-bound, one-use step-up receipt. They destroy Argus-held provider credentials but never claim to close a Webull account or cancel a Webull order.

### Brokerage reads are projections, not a ledger

Accounts, balances, positions, restrictions, and orders are separate immutable projection generations. Each surface exposes provider observation availability, Argus fetch time, expiry, and a visible freshness state. Stale or partially unavailable data may remain visible, but all order mutations remain disabled until the server confirms coherent, fresh capability and restriction authority.

### Financial commands are manual and provider-bound

Only partner-approved manual order combinations may be previewed, reviewed, and explicitly confirmed. A durable provider command exists before network egress and binds the owner, connection, account, operation, reviewed-payload hash, idempotency key, capability version, and stable provider identifier. An ambiguous response is reconciled without blind resubmission. Funding, deposits, withdrawals, account opening, autonomous trading, recurring financial execution, Rowan-triggered execution, recommendation-triggered execution, and rebalance execution are outside the product.

## Product and agency rules

- Preserve the sequence of emotional framing, adjacent evidence, observation context, uncertainty, risks, and limitations.
- Preserve original ritual language and familiar platform behavior; do not turn the app into a generic brokerage dashboard.
- Rowan cannot issue financial commands. Rowan explains concepts and evidence but does not decide, recommend an order, use intimacy to influence a decision, or receive Webull credentials, raw provider payloads, balances, or positions as prompt context.
- Mystical interpretation never hides evidence, timing, freshness, risk, or provider authority and never claims supernatural causation.
- Information architecture must distinguish Argus-owned reflection and discovery from Webull-owned account and order state.
- Accessibility, native navigation, safe areas, reduced motion, Dynamic Type/font scaling, and non-color status meaning remain release requirements.

## Ownership matrix

| Surface | Target authority | Client boundary | Migration disposition |
| --- | --- | --- | --- |
| Member and staff identity | Supabase Auth | Supabase Auth SDK through repository/controller seams | Replace Auth0 identities; do not migrate synthetic users |
| Ritual, discovery, community, preferences, privacy, editorial | Argus in private Supabase schemas | Generated Argus API; approved private Storage transport | Retain product vocabulary and behavior |
| Brokerage authorization and credentials | Webull authorization; Argus server custody | Edge Functions only | Add encrypted, fenced, server-only custody |
| Accounts, balances, positions, restrictions, orders | Webull | Timestamped Argus API projections | Replace simulated ledger authority |
| Manual order intent and recovery | Argus provider-command record plus Webull outcome | Generated Argus API | Replace simulated order commands; never blind-retry |
| Funding, recurring execution, rebalance execution, Demo membership/reset | None in production | None | Delete |
| Intentions and Future Mirror | Argus scenarios | Generated Argus API | Retain without brokerage authority |
| Background work | Supabase Postgres, Queues, Cron, Edge workers | Opaque server-only references | Replace Cloudflare Queues/Cron |
| Media and privacy artifacts | Private Supabase Storage | Signed/approved transport | Replace R2 |
| Landing and standalone Demo | Cloudflare Pages static assets | Browser static assets only | Remove all Cloudflare compute and state |

## Development and launch boundary

Every branch uses a disposable local Supabase CLI stack and replays migrations from empty state. There is no Supabase Pro branching requirement. Only serialized main or explicitly manual deployments may mutate the one hosted development project. A separate production Supabase project, production Webull registration, custom SMTP, backup/recovery decisions, reliability thresholds, limits, compliance review, and admin hosting are launch gates rather than pre-production assumptions.

The current Webull Connect contract must be confirmed in writing and through sanitized sandbox fixtures before any real provider call is enabled. Mock adapters may unblock provider-neutral work, but they are not provider proof.

## Verification authority

- `ritual-investing-api/scripts/generate-openapi.ts` and the generated Dart client enforce the client contract.
- `ritual-investing-api/test/contracts/product-authority.test.ts` enforces this product/data-authority baseline.
- `docs/ritual-investing/member-data-inventory.md` classifies migration-era data, compute, clients, provider dependencies, secrets, and operations exactly once.
- Demo provider/import/network/persistence tests prove the independent synthetic boundary.
- Supabase database, Edge, Auth, queue, Storage, and security tests replace legacy evidence before decommissioning.

## Related

- `CONCEPTS.md` — canonical product vocabulary.
- `ritual-investing-app/PRODUCT.md` — member purpose, safety, and agency authority.
- `ritual-investing-app/README.md` — member runtime and verification entrypoint.
- `ritual-investing-site/PRODUCT.md` — static site and standalone Demo authority.
- `docs/ritual-investing/member-data-inventory.md` — migration classification and privacy inventory.
