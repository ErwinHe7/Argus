# Broker connection delivery — 2026-09-11

Extend the existing authenticated Leo workspace with a clear broker connection
entry and working local setup tools. Preserve the existing static-overlay host,
private device pairing, mandates, reconciliation and pending pause semantics.

## Scope

- Inspect the Strategy Lab UI/API contracts, Rust connector protocol/runtime,
  Python moomoo bridge, native package receipts and official broker API docs.
- Add `features/strategy-lab/brokers`, local readiness/IBKR adapter tools, and a
  verified Windows development download using the existing native connector.
- Reuse the current owner-scoped API. Broker credentials remain in each user's
  own authenticated broker application. Desktop-app presence is not API access.
- Keep live-money execution disabled. Verified moomoo SIMULATE mandates retain
  paper execution. IBKR execution requires broker-supported paper attestation
  for the actual execution session and any required commercial authorization.
- Publish only reviewed static assets; preserve backend, billing and unrelated
  routes. The separate custom-domain access problem does not authorize replacing
  the old domain's infrastructure.

## Acceptance

- Readiness reports distinguish installed, listening, authenticated and verified
  paper state, and never read browser credentials or submit diagnostic orders.
- New provider paths reject live/unknown sessions, stale data and ambiguous
  submissions. Unknown outcomes remain unresolved until reconciliation.
- Download manifests validate every part and the complete native archive before
  installation; existing state and application directories are preserved.
- UI guest, owner, stale and revoked states cannot imply an active connection or
  grant a trading mandate. Keyboard/mobile controls remain usable.
- Run focused Python/Rust checks when affected, browser regressions, TypeScript,
  frozen-stage identity checks and production asset/route verification.

## External prerequisites

Each user must authenticate and approve the broker connection themselves. Broker
data entitlements, partner/OAuth approval, signing credentials, completed paper
entry/hold/exit evidence and access to the custom-domain account are separate
release conditions. A code test or listener does not satisfy these conditions.

## Delivered software preview

Published Worker `964f8a15-7f90-492d-b26e-9bb6158e8885`; all fifteen production
checks passed. Native Windows build/install/integrity/state checks passed and
the preview is installed locally. Broker authentication, pairing and an actual
paper lifecycle remain incomplete. The exact boundary and receipts are recorded
in `docs/strategy-lab/BROKER-CONNECTIONS.md`. No real or paper orders were submitted.
