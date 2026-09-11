# Strategy Lab implementation and release evidence

Hosted deployment update (2026-09-10 ET): the isolated strategy migration/API
and exact custom-domain/Worker callback configuration are now applied. See
[the hosted deployment receipt](SUPABASE-DEPLOYMENT-20260910.md) for verification
and remaining actual-user and broker acceptance. Historical release-preparation
notes below describe the earlier undeployed state.

Owner-approved scope: Astra's Pick strategy workspace, deterministic MR-v1 and
MOM-v1 research, local moomoo paper execution, owner-scoped controls, and monitoring.
Real-money and options execution are disabled. No profitability result is claimed.

The subsequent grid-trading request is implemented as **GRID-R1 local research**.
It adds editable fixed-range replay, per-slot accounting, local JSON import/export,
and synthetic teaching examples inside this workspace. Its broker execution is
unavailable; it does not widen the MR/MOM deployment allowlist or alter the
delivered connector packages. [Grid rules and sources](GRID-R1.md) and the
[grid delivery report](GRID-DELIVERY.md) record its separate checks and limits.

Continuous research adds a durable local worker and private loopback monitor for
source-readiness checks and eligible deterministic research jobs. The worker is
running locally; Ubuntu VPS service setup is prepared separately. Its current
six-symbol source-capability result is not a backtest, and execution and
promotion remain disabled. The [continuous research delivery report](CONTINUOUS-RESEARCH.md)
records the actual runtime, recovery checks, and deployment boundaries.

## Source ownership

| Component | Source |
|---|---|
| Workspace, Google session, controls, account evidence | `platform/features/strategy-lab/` |
| Existing shell and exact callback routing | `platform/features/research-desk/` |
| Versioned API contracts, ownership, control service, supervisor | `ritual-investing-api/src/domains/strategy-lab/` |
| Separate Edge entry and origin policy | `supabase/functions/strategy-api/` |
| Private owner-scoped state and capability functions | `supabase/migrations/20260908003020_strategy_lab_control_plane.sql` |
| Rust indicators, decisions, sizing, decimal replay ledger | `platform/quant_engine_rs/src/strategy_lab/` |
| Offline data validation and research evaluation | `platform/intraday_quant/src/intraday_quant/strategy_lab/` |
| Durable local runner and narrow paper SDK adapter | `platform/connectors/strategy/` |
| Static overlay preparation | `platform/scripts/strategy-stage.py` |

The scoped [product contract](PRODUCT.md) supplements the old research-only
contract for this explicitly authorized feature. It does not widen the existing
research APIs or enable the synthetic TypeScript execution service.

## User workflow

Open `/#/strategies`. Choose a hypothesis, save an immutable symbol/rule revision,
review its research evidence, pair a computer, and create a paused mandate.
The first release uses fixed v1 rules. Dry run is the default. Starting paper
execution requires the separate explicit resume request and local reconciliation.
Historical chart loading is independent of authentication and strategy controls.

The Google callback is exact `/strategy-auth/callback`. It exchanges PKCE once,
clears callback parameters, and uses the dedicated `leo.strategy-lab.auth.v1`
storage namespace. Browser-local journal and plan storage is unchanged. The
strategy API re-verifies membership and active sessions; guest preview cannot
authorize account state. Authenticated API requests carry idempotency keys and
do not follow redirects. Account changes and sign-out clear owner data.

“Pause requested” remains pending until the connector acknowledges it. Pause
does not cancel working orders or close positions. Software stops are local,
regular-session protections and require fresh quotes and a running computer.
First observed cumulative paper fill price is explicitly labeled where the
broker cannot supply the individual first fill. Unknown submissions never become
an automatic retry. See the [connector guide](CONNECTOR-GUIDE.md).

## Checks and evidence

Browser fixture results are under `platform/.impeccable/review/strategy-lab/`
and explicitly identify injected API events. They contain no real broker evidence.

Current UI checks:

- Full platform and scoped TypeScript checks, independent Worker typecheck, and
  static analyzer bundling pass. The frozen application is not rebuilt.
- Callback/root/legacy-route and browser-local record contracts: 15 passing tests.
- Strategy configuration, session boundaries, pending pause, expired lease,
  response validation, and stale-value unit contracts: 6 passing tests.
- Browser interaction verifies chart-data outage independence, signed-out
  restrictions, immutable revision creation, research request/report import,
  pairing display, explicit paused mandate authorization, pending pause
  acknowledgement, stale preservation, disabled resume while stale, and clearing
  owner data on sign-out. Keyboard transitions focus the new heading; all five
  steps fit on the phone layout, including CTA navigation to steps four and five.
- Desktop and 390px mobile snapshots are captured. No horizontal page overflow
  or JavaScript page errors in the tested states. The scoped design detector
  reports no findings.

The independent review used the generic-agent fallback to the Impeccable finish
contract. It requested two navigation fixes; its final `ship` verdict scores
both resolved, with no fix-batch regression. This verdict is scoped to those
two fixes. Review and verdict files are beside the browser receipt.

Research checks: 17 Rust tests and 10 Python tests passed, together with the
strategy CLI build/subprocess smoke and feature formatting. Clippy reported four
pre-existing warnings in the unrelated `api.rs`, and none in Strategy Lab. See
[`../strategy-lab-runbook.md`](../strategy-lab-runbook.md). The retained source
capability receipt at `.quant-runtime/strategy-research/source-capability-20260907.json`
records actual 260-session datasets for six symbols, but missing adjustment,
calendar and historical-availability evidence prevents a credible performance
report. The daily-open proxy cannot validate the quote-window experiment.

The isolated API passed 21 tests: 17 service/HTTP tests and four tests against a
disposable PostgreSQL 18 cluster using the actual migration and retained trusted
request-context functions. These cover tenant/lifecycle RLS, one-use pairing,
revocation, concurrent controls, immutable reports and events, constrained
supervision, and more than 24,000 archived events without losing a quiet
account's safety snapshot. API TypeScript and the pinned Deno Edge graph check
passed. The task-owned database cluster was stopped. See
[`VALIDATION.md`](../../../ritual-investing-api/test/strategy-lab/VALIDATION.md)
and the [API contract](../../../ritual-investing-api/src/domains/strategy-lab/README.md).

Connector checks: 19 Rust tests and 13 fake-SDK Python tests passed, along with
strict Clippy and the Windows release build. Tests exercise the actual release
strategy engine with injected SDK observations, including the 09:30 to 09:35
entry transition, sized dry-run proposals without broker mutations, restart
reconciliation, cumulative paper fills, unresolved submissions, and persistent
software stops. Evidence uploads retain immutable retry batches within the API
body and individual-event limits. Oversized payloads remain in the local journal
and upload a labeled hash summary. See the source and binary hash receipt at
[`windows-offline-20260907.json`](../../connectors/strategy/validation/windows-offline-20260907.json).
The bundled SDK self-check and rejection of a REAL-environment request ran
without opening a broker connection.

Windows 11 x64 native acceptance passed **13 checks** against the final unsigned
MSI and ZIP. Both installers ran the installed runner, separate strategy engine,
and bundled SDK without a broker connection. All three installed executable
hashes matched the frozen package. Tampered packages, existing destinations,
and relative paths were refused. Removal preserved external state and custom
journal fixtures. These fixtures contain no brokerage data. Native credential
store pairing, clean-machine dependency installation, broker acceptance, and
non-Windows native acceptance remain separate gates.

Final Windows development artifacts:

- [MSI installer](</C:/Users/Hj/Desktop/Leo Roar/release-work/leo-strategy-native-20260907/delivery-windows/leo-strategy-connector-0.1.0-dev-windows-x64.msi>)
- [ZIP package](</C:/Users/Hj/Desktop/Leo Roar/release-work/leo-strategy-native-20260907/delivery-windows/leo-strategy-connector-0.1.0-dev-windows-x64.zip>)
- [Build receipt](</C:/Users/Hj/Desktop/Leo Roar/release-work/leo-strategy-native-20260907/delivery-windows/native-build-receipt.json>)
- [Installation receipt](</C:/Users/Hj/Desktop/Leo Roar/release-work/leo-strategy-native-20260907/delivery-windows/verification/windows-install-receipt.json>)
- [Combined native delivery receipt](</C:/Users/Hj/Desktop/Leo Roar/release-work/leo-strategy-native-20260907/delivery-windows/DELIVERY-RECEIPT.json>)
- [Artifact checksums](</C:/Users/Hj/Desktop/Leo Roar/release-work/leo-strategy-native-20260907/delivery-windows/ARTIFACT-SHA256SUMS>)

The ZIP is 51,227,314 bytes. The package contains the native runner, native
research engine, frozen Python SDK adapter, scripts, notices, and an inventory.
OpenD remains separately installed and locally authenticated. Packaging commands
and the five-target manual CI workflow are documented in
[`packaging/README.md`](../../connectors/strategy/packaging/README.md).
Only `delivery-windows` is the final native delivery; earlier failed or provisional
package directories are preserved for diagnosis and must not be distributed.
Final source and executable hash audits passed. Signature probes confirm that
the MSI and three application executables are unsigned. The development
dependency inventory lists 22 Python distributions and 454 Rust lock entries;
138 lock entries lack locally collected notices, including target-specific
dependencies that may not be linked. Public redistribution requires a dependency
and notice review plus an approved Python runtime build. The development
inventory is not public distribution clearance.

## Release preparation

The static build reads `LEO_STRATEGY_PUBLIC_CONFIG` when explicitly supplied;
otherwise it emits the disabled example connection configuration. Its only
allowed production API destination is the existing Leo Supabase project. The
browser configuration accepts publishable/legacy anon keys and rejects secret
or service-role keys. Broker passwords never belong in it.

`strategy-stage.py` creates a fresh copy of the previously verified Astra overlay,
copies only the built research-desk assets and route wrapper, then compares all
frozen backend and unrelated asset hashes. It refuses to overwrite an existing
stage. Preparing or dry-running that bundle does not deploy it. Do not run a
wholesale Next.js rebuild/deploy of this dirty checkout.

Prepared stage:
`C:\Users\Hj\Desktop\Leo Roar\release-work\leo-strategy-workspace-20260907`.
Its `stage-receipt.json` confirms all **2,583 frozen backend files**, unrelated
assets, and Worker configuration are unchanged. Only desk JavaScript/CSS and the
two new strategy configuration/guide assets differ; no assets were removed.
The existing Worker hostname remains `leo.axio7.workers.dev`.

Wrangler **4.127.1** `deploy --dry-run` passed: 351 assets, 14,307.45 KiB bundled
Worker, 2,861.98 KiB gzip. Its existing negative-zero comparison warning comes
from the retained backend; that frozen source was preserved. The dry-run receipt
and bundle are in the stage. No Worker deployment was performed. Connections
remain disabled in `strategy-config.json` until the external setup below passes.

A web rollback does not stop a local connector or cancel broker orders. Preserve
the strategy control route while policies are active. Restoring the previous
static overlay must not be represented as a trading halt; acknowledged pauses
or expiry of control authorization govern entries, and existing exposure still
needs monitoring. Never delete the control database or a local journal as a
rollback action.

External release prerequisites:

- Deploy the new migration and `strategy-api` to the intended project using
  its existing restricted database connection. Preserve the retained member API
  origin policy. Configure the strategy origin as `https://leo.axio7.workers.dev`.
- Add `https://leo.axio7.workers.dev/strategy-auth/callback` to Supabase's allowed
  redirects and retain the other application callbacks. Verify Google OAuth on
  the exact production origin before enabling the public connection config.
- Install and authenticate OpenD locally with appropriate paper-account and
  market-data entitlement. Complete a broker paper entry/hold/exit and recovery
  cycle, separately from injected tests.
- Run native installation and OpenD checks on each supported operating system.
  Do not infer native Apple Silicon OpenD support; verify the actual vendor build
  and any required Rosetta path.
- Supply Windows signing and macOS signing/notarization credentials before
  public distribution. Unsigned development packages must remain labeled.
- Configure the supervisor provider only when wanted. Model, HTTPS endpoint, and
  server-side credential must be explicit; no implicit paid fallback exists.

First-release limits: rules use the fixed MR-v1 and MOM-v1 presets; changing the
selected symbol creates a new immutable configuration. Only one active mandate
is allowed per paper account, a stricter limit than one per account/instrument.
Research requests await a locally generated report; they do not start a cloud
backtest or upload historical bars. The regime selector remains unavailable for
execution. These constraints are enforced by the API and connector.

Known recovery boundary: retirement requires a fresh flat reconciliation and an
acknowledgement from the bound connector. A lost ledger or revoked connector with
an unacknowledged mandate cannot currently be forcibly replaced. Preserve the
local journal and retire flat policies before replacing a working computer.
Credential revocation still immediately prevents further lease renewal. A
separate verified recovery flow is required before supporting forced replacement.

IV trading and real-money operation are separate later releases.
