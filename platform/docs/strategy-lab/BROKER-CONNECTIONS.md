# Broker connections — development delivery, 2026-09-11

Leo now has `#/brokers`, reached through **Connect broker** in the existing
navigation. It shows setup instructions and the signed-in owner's reported
computers/accounts. Google identity, broker authentication and paper execution
authority remain separate. The website never accepts a broker password, reaches
into localhost, or exposes an arbitrary order API.

## Implemented paths

| Broker | Local implementation | Release boundary |
| --- | --- | --- |
| moomoo REST OAuth | Separate read-only website account link with broker-hosted consent, PKCE and encrypted server tokens | Account visibility only; write/wildcard grants are rejected. This does not authorize the local paper runner. |
| moomoo / Futu | OpenD + existing paper SDK, Rust strategy/reconciliation/store, software stops | U.S. stocks/ETFs, USD, whole shares, SIMULATE mandates only. |
| IBKR Client Portal | New loopback HTTPS adapter, exact selected account, same-session boolean `isPaper` attestation, durable dispatch journal, quote/cash/order reconciliation | Experimental local paper opt-in; public commercial integration approval and broker acceptance are outstanding. |
| IBKR TWS | Optional SDK-based read-only inspector | No executable accounts. A port or DU prefix never establishes paper authority. Vendor SDK is not redistributed. |

The unified native sidecar preserves moomoo as its default. IBKR account IDs are
namespaced `IBKR:DU...`; existing moomoo numeric IDs retain their meaning. The
namespace prevents identity collisions and is not paper-environment proof.
The local execution paths require no additional cloud database migration or
changes to existing research APIs. The independent REST account-link feature uses
its own private D1 database and Worker; it does not modify the strategy database.
Owner-scoped pairing, mandates, leases, evidence and pause controls reuse the
isolated Strategy API and its verified identity/device bindings.

## Execution and recovery

IBKR paper execution requires an explicit local flag, selected account, persistent
journal, certificate verification and a current authorized Rust mandate. The
same local gateway supplies identity and execution. No TWS/Web API session mixing,
account switching, automated login, warning acceptance or live account fallback
is implemented. Unresolved warning/timeout outcomes stay blocked for reconciliation.

An account OS lock covers preflight through dispatch and observation. The durable
intent precedes transmission; acknowledged broker IDs survive read timeouts.
Order commitments are collected before positions, conservatively reserving
exposure through intervening fills. Definitely-unsent cancellation failures can
be retried; ambiguous transmission remains latched. The existing Rust lease
protects account ownership across registered installations.

Only fresh, entitled bid/ask data can authorize an entry. The IBKR adapter requires
validated, current 220–1,000-session local history with adjustment, calendar,
availability and hash evidence. Missing history produces no entry evaluation.
No new strategy implementation or fabricated historical performance is added.
See the bundled [IBKR guide](../../connectors/strategy/adapter/IBKR.md) for the
dataset schema and setup commands.

Local software stops require the computer and gateway to remain running.
Expired cloud authorization blocks entries while authorized exposure management
continues. Pause remains pending until acknowledged; it does not cancel orders
or liquidate positions. Stop state, unresolved orders and accounting survive
restarts. Neither the browser nor an AI explanation can place an order.

## Windows development download

The website kit contains an installer, exact native-package manifest, local
readiness inspector and IBKR guide. Native files are delivered as checksum-pinned
20 MiB parts, below the Workers per-asset limit. The PowerShell 7 installer uses
only Leo's HTTPS origin, refuses redirects and oversized/stalled responses,
verifies parts and the complete ZIP, rejects unsafe extraction paths and installs
to a new per-user application folder. Existing profiles/installations are retained.
No execution-policy change, automatic startup service, pairing or order occurs
during installation. Windows signing is absent; this is an unsigned preview.

The builder requires a successful native build receipt and exact matching ZIP.
Native binaries include the Rust connector, separate Rust strategy engine and
frozen Python sidecar. OpenD and IBKR software are separately installed. The
toolkit's manifest exposes sizes and SHA-256 values; it contains no credentials.

## Verification and remaining acceptance

- Rust connector: 21 tests, formatting and strict Clippy pass. Integration fixtures
  use the freshly built separate engine and an explicit Python runtime.
- Python adapters: 61 tests pass, including moomoo, IBKR Gateway, TWS inspection
  and provider dispatch. The independent review's three race/recovery findings
  are fixed with trigger-specific regressions and a passing recheck.
- Toolkit: six synthetic archive tests and Windows profile checks pass, including
  corruption, traversal, duplicate names, receipt mismatch, isolated profiles,
  exact account selection, explicit paper opt-in and TLS requirements.
- Browser checks distinguish guest, verified owner, stale/future report, revoked
  device and anonymous/mismatched owner. A heartbeat is not broker/protection proof.

Native package/install receipts and final production hashes belong to the dated
release directories. Browser/API fixtures and synthetic order tests are not
broker-backed execution evidence. No actual broker orders have been placed as
part of this delivery. Each user must authenticate locally, supply entitled data,
pair their computer, review a paper mandate and complete an entry/hold/exit plus
recovery cycle. Native macOS/Linux acceptance, signing/notarization and public
IBKR approval remain outstanding. Real-money and options execution are disabled.

The website release uses the existing static-overlay process and preserves the
frozen backend, current Worker hostname and unrelated routes/assets. The separate
custom-domain access problem does not authorize replacing its owner account or
DNS configuration. No VPS is needed to install locally; continuous operation
requires an awake computer or a separately configured always-on host.

## First broker-preview receipt

The reviewed preview is live at `https://leo.axio7.workers.dev/#/brokers`, Worker
version `964f8a15-7f90-492d-b26e-9bb6158e8885`. Fifteen production checks passed,
including every download and the reassembled native archive. Two existing UI
assets changed and five downloads were added; 2,583 backend files and 256 other
assets are unchanged. Broker/auth/strategy browser groups passed 5/9/5, with 17
routing tests and no recorded browser errors. Nine native Windows install,
uninstall, integrity and state-preservation checks passed.

The native ZIP is 51,318,802 bytes, SHA-256
`f619b8b816c3ce84f0c5ecdaee2ab05c765e09181664de09c82475ecd4387f4d`.
The 22,469-byte website toolkit ZIP has SHA-256
`f9d59fa7f22819a60cdaa154bfb98ec11fb781590351c6d403dd98d1b8132746`.
Public release metadata is available alongside the website download. Source
checksums matched the final native build. Broker gateways and the native kit were
also installed on the owner's Windows computer; no account was paired or mandate
started. A local moomoo account-discovery probe timed out, so broker readiness
remains unverified. The broker and control service were not treated as connected
merely because their processes or ports were present.

## Direct account-link update — 2026-09-11

The updated Brokers page is published at the same Leo origin, Worker version
`4dcc330c-c533-4346-b5bc-413f956c8e2a`. Only its JavaScript/CSS changed; all 263
assets, 2,583 frozen backend files, five broker downloads, Google configuration,
Whop membership and three service bindings are retained. All 18 web production
checks passed, along with seven proxy runtime and 22 proxy tooling tests.

moomoo now also has a direct, read-only OAuth account link. Leo's public OAuth
client is registered, the isolated Worker and encrypted D1 store are deployed,
and the live browser reached moomoo's broker login page from a verified Google
session. This reads only masked account metadata after broker consent. It does
not attach the REST token to the local runner, enable trades or replace paper
mandates. Disconnect removes Leo's stored link, while broker-side permission
removal remains in moomoo. The [API contract](../../workers/broker-link/README.md)
records the exact endpoints, scope restrictions and acceptance evidence.

The new Worker passes 18 software tests and 11 production HTTP checks. Frontend
checks pass four account-link tests, eight auth/strategy contract tests, eleven
broker browser groups, eleven auth groups, scoped TypeScript and the static build.
Independent review found and verified fixes for a disconnect/focus race. Neither
these fixtures nor the real login-page handoff establish a completed account link.

Local preflight still could not verify broker login: OpenD's read-only status
request timed out, and the pinned-certificate IBKR gateway returned HTTP 403 for
its authentication status. The browser's local certificate interstitial was not
bypassed. No connector was paired or started and no order was submitted. The
[IBKR onboarding brief](IBKR-ONBOARDING.md) explains the separate public integration
review and owner information still required. No VPS or model tokens are needed
for the direct account-link service; local execution still requires a running host.

The production browser check also exposed an existing strategy-session bug:
extra JWT verification timestamps reached a strict database-claim schema and
caused authenticated requests to fail. The repository now projects the three
verified identity/session fields explicitly. Isolated `strategy-api` v2 is
deployed, and the actual Google session now displays verified Leo account
records with no local computer paired. Permissions, membership checks and RLS
are unchanged. The [fix receipt](SESSION-PROJECTION-FIX-20260911.md) records 49
passing tests, two pre-existing hosted-database test skips, and live verification.
