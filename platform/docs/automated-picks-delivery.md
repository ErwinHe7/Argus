# Automatic stock shortlist — deployed September 8, 2026

[Astra's Pick](https://leo.axio7.workers.dev/#/home) now receives actual publications
from a continuously running local Python process. The homepage shows the first
research candidate, its reasons, remaining checks, and the observation date.

## Program and evidence

`intraday_quant.shortlist_service` scans configured observations every 30 seconds,
reuses the existing Python screener, and retains immutable results for unchanged
input/generator/calendar identities. Invalid, missing, future, or regressed inputs
preserve the previous dated result. It does not download data or call AI/brokers.

The current universe is five stocks and three funds, dated September 4, 2026.
NVDA/ZM/AMZN match three/two/one checks: close above SMA50, RSI14 in 50–65, and
close from SMA20 through 1.05 × SMA20. Existing tie ordering is unchanged. These
are descriptive research criteria, not valuation, expected returns, or orders.
Source adjustment/calendar limitations remain visible. The source still does
not support credible strategy performance backtests. TradingView is a separate
display and supplies no raw input to this program.

Authenticated HTTPS uploads go to `leo-shortlist-feed.axio7.workers.dev/publication`.
A separate SQLite Durable Object atomically retains the envelope and revision
identities. It rejects unauthorized/oversized/undeclared data, future observations,
global and per-symbol regressions, and changed data under an existing revision.
The Python artifact byte hash is publisher-attested; the Worker separately
checks canonical JSON identity without claiming equivalent cross-language bytes.
No account state, secret, or raw price history is uploaded.

The main site's exact read-only proxy is
`/app/research-desk/data/shortlist-feed/current.json`. It forwards no caller
cookies, credentials, query parameters, or write methods. The browser validates
the bounded envelope and polls every minute while visible. Publisher heartbeat
and market cutoff remain separate; errors retain dated evidence, and download
exports exactly the displayed snapshot. There is no automatic strategy promotion.

## Verification

- Windows Python: 25 passed, one POSIX-only skip across new service and existing
  screener cases. Ubuntu 24.04: all 15 service cases passed, including FIFO and
  actual process lock. The final HTTP-header change passed two targeted tests.
- Worker: nine unit/Miniflare groups passed, including SQLite restart,
  concurrent writes, auth, size bounds, immutable revisions, and per-symbol
  regression. Independent review's per-symbol finding was fixed and tested.
  Worker typecheck and dry run passed.
- Website: 22 shortlist/publication/routing tests passed; three publication cases
  passed again after per-row future validation. Scoped TypeScript and static build
  passed. Six browser checks passed for actual local data, download, keyboard,
  failure retention, stale state, and polling. Injected time/network cases are
  labeled. The initial stale fixture incorrectly attempted to rewind a retained
  heartbeat; testing initial stale state passed without weakening the guard.
- Scoped visual review shipped three valid desktop/mobile opening/detail captures.
  No detector ran for this refinement; prior scans retain their original scope.
- Actual cloud verification observed two advancing heartbeats with unchanged
  revision, publishedAt, and September 4 cutoff. The live homepage showed the
  expected stocks. Root, original, app, pricing, and auth callback returned 200.
  Remote JS/CSS hashes match the release. This establishes operation, not profit.

Actual deployment first encountered Cloudflare 403/1010 for Python's default
User-Agent. The truthful `LeoShortlistPublisher/1.0` and JSON Accept headers
resolved it, and the daemon subsequently delivered automatically. One combined
stop/config/start/temp-file-cleanup command was rejected by automatic review;
separately verified operations succeeded. The private temporary secret file was
retained rather than deleted. Tokens remain outside public assets and source
packages in the current-user/SYSTEM-restricted runtime directory.

## Release and rollback

Main version: `b65031ab-8539-44bc-b05a-f13098de4503`.
Feed version: `5ac5c1bd-3072-4f28-9a6f-c88196326511`.
Recorded previous main version: `31f5c855-3aec-4e01-9ad9-e0869ee5cee5`.

The stage `release-work/leo-auto-picks-20260908` preserves 2,583 frozen backend
files and unrelated assets. Two assets changed from its prepared parent; twelve
uploaded relative to the earlier live release include previously authorized
Strategy Lab/grid/Picks work. Only one service binding and its exact asset-route
override were added. Hostname/existing bindings remain. No dirty Next.js rebuild
occurred; the pre-existing frozen negative-zero warning remains.

Receipts are in that stage (`live-verification.json`, stage/deployment logs),
`.impeccable/review/automated-picks/`, `.quant-runtime/shortlist-publisher-validation/`,
and `connectors/research-runner/deployment/`.

## VPS and operation

No VPS has been purchased or connected. The Windows publisher must currently
remain running. The cloud site retains results if it stops and labels an expired
heartbeat. Windows startup/reboot persistence was not installed.

Proposed starter: DigitalOcean Basic Regular, 2 GiB/1 vCPU/50 GiB, $12/month,
Ubuntu 24.04 x64. This is an initial sizing judgment for the small daily screen,
not a large-backtest capacity guarantee. See [official pricing](https://www.digitalocean.com/pricing/droplets)
and the [Chinese installation guide](../connectors/research-runner/deployment/README.zh-CN.md).

Final package: `connectors/research-runner/deployment/dist/leo-vps-source-20260908-v3.zip`,
SHA256 `5814a95ffa8a4ac6c9575c776f6e5ebcb4f27d20f788762558ed03ab8d393abd`.
Its 122 allowlisted files omit history, credentials, account state, and Windows
binaries. Final extracted hashes and stdlib-only runtime preparation passed in
Ubuntu 24.04 WSL. Earlier v1/v2 archives are superseded. Native Rust build, actual
VPS execution, and remote reboot recovery remain unverified.

Migration must stop the Windows publisher first, then transfer its private
journal/receipts, calendar cache, and authorized source over SSH into separate
private directories. Preserve revision and original publishedAt: a new journal
over identical input can conflict with the cloud's immutable revision. Update
native config paths, use the protected systemd EnvironmentFile for the token,
and keep one active publisher. Verify upload, heartbeat, restart, and reboot
before retiring the Windows process. These private inputs are intentionally
absent from the source ZIP.

Local controls: `scripts/shortlist-service.ps1 -Action Status|Start|Pause|Resume|Stop`.
Config: `.quant-runtime/shortlist-publisher/config.json`; diagnostics remain private.
Research and paper connectors are separate, with real-money execution disabled.
A VPS does not supply market data: continued updates require authorized source
acquisition or validated imports; saved files are never relabeled as fresh prices.
