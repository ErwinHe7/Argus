# Continuous research delivery — September 8, 2026

Leo now has a running local research worker and a private monitor at
[127.0.0.1:3119](http://127.0.0.1:3119/). The Strategy Lab workspace includes an
“Open local monitor” link independently of cloud authentication and archived
chart loading. The existing Picks, Markets, plans, and supporting routes remain.

The worker scans configured local files every 30 seconds. Changed, validated
research inputs can run baseline and predeclared sensitivity experiments through
the canonical Rust engine. Python prepares datasets and evaluates Rust results;
there is no second strategy implementation and no LLM call in the recurring loop.
This is repeatable programmed research, not autonomous strategy rewriting.

## Actual result

The currently configured `recorded-market-history` job evaluates the retained
IBKR source file `deliverables/leo-iv-research/market-data.json`. It contains 260
sessions per symbol for DXYZ, ZM, AVGO, AMZN, GOOGL, and NVDA, from August 25, 2025
through September 4, 2026. Its source-capability result is **insufficient evidence**:
verified adjustments, complete-session attestation, and historical availability
receipts are missing. An options quote-chain limitation is recorded separately
and is not treated as a prerequisite for MR/MOM equity research.

At the final local recovery verification, the durable journal contained two
source-capability batches for two implementation identities, two source
experiments, **zero Rust strategy replays, and zero AI calls**. These are neither
two profitable backtests nor six tested strategies. Restarting unchanged final
inputs reused the same result and did not add another batch. No broker connection
or order was made by this service. Execution and promotion flags remain false.

The loop watches local files; it does not acquire updated market data. A valid
`research` job requires a dataset accepted by the existing provenance, adjustment,
calendar, coverage, and availability contract. No performance report is fabricated
when those requirements are absent. Registration and predeclared sensitivity
settings do not authorize automatic deployment or winner selection.

## Sources and interfaces

All paths in this table are relative to `Argus/platform`.

| Component | Source |
|---|---|
| Durable worker and versioned config/status/result contracts | `intraday_quant/src/intraday_quant/strategy_lab/continuous.py` |
| Existing dataset preparation and canonical result evaluation | `intraday_quant/src/intraday_quant/strategy_lab/research.py` |
| Local HTTP monitor and bounded evidence projection | `intraday_quant/src/intraday_quant/strategy_lab/monitor.py` |
| Monitor UI and inherited design documentation | `connectors/research-runner/web/` |
| Windows hidden-process lifecycle scripts | `connectors/research-runner/windows/` |
| Ubuntu user services and installer | `connectors/research-runner/linux/` |
| Website integration | `features/strategy-lab/StrategyWorkspace.tsx`, `strategy.css` |

The queue accepts `leo-continuous-research-config.v1` with absolute `state_dir`,
native `engine`, `interval_seconds`, and bounded `jobs`. Each job has `id`, `kind`,
and `input`. Kinds are `source-capability` and `research`; only `research` accepts
`sensitivity` and optional `registration`. See the [operations guide](../../connectors/research-runner/README.md)
for a complete configuration and platform commands.

The local monitor exposes only fixed static assets, `GET /api/status`, and
`POST /api/control` with research `pause` or `resume`. It binds to IPv4 loopback,
checks Host and Origin, uses a per-process control token, and does not expose raw
market files, arbitrary filesystem access, broker endpoints, or shell commands.
This is a local-user interface, not a public multiuser authentication service.

## Persistence and controls

An OS-held lock permits one worker per state directory. SQLite records each
batch and experiment before it executes; immutable receipts bind inputs,
registration, engine, evaluator, and dependency identities. Completed and rejected
attempts remain visible. Recovery reuses completed operations and rejects missing
or modified immutable artifacts rather than silently replacing history.

Heartbeat publication continues during research. Research pause persists in
`STOP`, displays pending until acknowledged, and prevents new job batches. An
active read-only batch may complete its predeclared variants. `SHUTDOWN` stops
after the current operation, leaving unfinished work recoverable. These actions
never cancel broker orders or close positions. Explicit Windows start acknowledges
an old shutdown while preserving pause; ordinary service restarts preserve both.

Source or dependency changes require a controlled worker restart. The native
engine is snapshotted and identified by hash. The currently running local binary
is the existing Windows development build, not a signed public distribution.
The current config and journal are under `.quant-runtime/continuous-research/`;
the newly created state directory has current-user and SYSTEM access.

## Verification

| Check | Result and scope |
|---|---|
| Continuous worker unit tests | 27 passed, one POSIX-only case skipped on Windows; admissions, deduplication, immutable recovery, process locking, heartbeat, pause, shutdown, source identity, and Windows status-write recovery |
| Existing strategy lab Python suite | 10 passed; no separate strategy implementation introduced |
| Monitor HTTP/state suite | 6 passed; Host/Origin/control boundaries and stale/failed state behavior |
| Independent code review | Two material findings corrected: nonregular input could block, and Windows launcher exit could leave a runtime child |
| POSIX FIFO correction | Actual final reader rejected a FIFO without blocking on Ubuntu 24.04 WSL |
| Windows operations | Hidden start, duplicate refusal, persistent pause, graceful stop, identity mismatch, and deliberately detached orphan-runtime recovery passed in isolated fixtures |
| Actual local recovery | Worker and listener stopped gracefully, restarted, and reused the unchanged final result; HTTP monitor returned 200 |
| Browser workflow | 6 passed: actual heartbeat/source data, acknowledged controls, mobile keyboard/layout, stale values, network loss, and website link independent of cloud setup |
| Web build | Scoped TypeScript and static research-desk build passed |
| Ubuntu preparation | Bash syntax, path rendering, and systemd 255 unit verification passed on Ubuntu 24.04 WSL; no service installed or started |
| Static release preparation | Frozen backend, unrelated assets, and Worker config retained; Wrangler dry run passed |

Python tests were run with `unittest` in the existing compatible research venv.
The broader pytest collection encountered an unavailable `yaml` dependency in the
shared conftest; this is not recorded as a pytest pass. Browser stale/network
cases are explicitly injected browser conditions, distinct from the actual worker
and real retained source file. Process fault fixtures do not establish broker
reliability or strategy profitability.

Receipts are in `.quant-runtime/continuous-research/validation/` and
`.impeccable/review/continuous-research/`. The first browser run stopped when an
in-progress implementation change correctly tripped source-integrity protection;
its receipt is retained separately from the final six passing checks. A premature
fixed-delay restart assertion was corrected to await the restored job key and
waiting state; the final runtime receipt records the unchanged durable count.

Visual QA includes desktop and mobile captures and a focused independent review.
The requested square-button correction was verified with both recaptures. Its
ship verdict covers that correction, not trading readiness or a new whole-page
audit. The detector returned no regex findings with HTML parser support
unavailable; it did not perform full computed-style or contrast evaluation.

## Startup, recovery, and VPS handoff

On this computer, from `Argus/platform`:

```powershell
$config = (Resolve-Path '.quant-runtime/continuous-research/config.json').Path
$python = (Resolve-Path '.quant-runtime/strategy-research-venv/Scripts/python.exe').Path
& ./connectors/research-runner/windows/status.ps1 -Config $config
& ./connectors/research-runner/windows/start.ps1 -Config $config -Python $python -Dashboard
# Research controls:
& ./connectors/research-runner/windows/pause.ps1 -Config $config
& ./connectors/research-runner/windows/resume.ps1 -Config $config
# Controlled shutdown, preserving all evidence:
& ./connectors/research-runner/windows/stop.ps1 -Config $config
```

The worker survives closing its launching terminal. The Windows scripts do not
install startup, logoff persistence, or a crash supervisor. The computer must
remain running. Use status/heartbeat to distinguish saved evidence from a live
process. After a source update, stop, start explicitly, then wait for the job's
waiting/active state instead of treating the initial status publication as final.
Back up the entire state directory while stopped; do not delete its lock or
history to bypass errors.

Ubuntu user services prepare restart-on-failure and private permissions. Build
Python and Rust natively on the target and inspect rendered units before starting.
Enablement and user lingering for reboot/logout operation are explicit operations.
Use SSH port forwarding for the monitor; do not open port 3119 publicly. No VPS
hostname was supplied, so no machine was purchased, provisioned, or deployed.
Ubuntu 22.04 native runtime, VPS reboot recovery, and macOS service packaging
remain unverified. The separate broker connector still requires its own secure
credential store and authenticated OpenD; these research units do not satisfy
headless broker execution requirements.

## Web release

The prepared overlay is `release-work/leo-continuous-research-20260908` at the
workspace root. Its receipt records 2,583 unchanged frozen backend files, unchanged
unrelated assets and Worker configuration, and only `desk.js`/`desk.css` changed.
Wrangler's dry run read 359 assets and exited successfully; its existing frozen
backend negative-zero warning remains. No wholesale Next.js build or public
deployment occurred. Hostname `leo.axio7.workers.dev` and application routes are
unchanged. The existing strategy API, Google configuration, entitled data,
native OpenD, signing/notarization, and broker lifecycle gates remain outstanding.
