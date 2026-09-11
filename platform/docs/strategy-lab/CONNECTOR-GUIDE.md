# Leo Connector: installation and recovery

Release status: development implementation. Public signed installers and native
broker integration receipts are prerequisites to general distribution. Real-money
execution and options execution are unavailable. Test-event evidence is never
proof of a broker fill or of profitability.

## Before pairing

1. Install the official moomoo/Futu OpenD for your operating system. Authenticate
   in OpenD locally and keep it running. Do not enter your brokerage password into
   the Leo website or its chat. Consult the connector package README for the
   exact tested OpenD and SDK versions.
2. Install the matching Leo Connector development package. Targets are Windows
   11 x64, macOS 14+ Intel/Apple Silicon, and Ubuntu 22.04/24.04 x64. A build target
   is not an OpenD verification receipt. Apple Silicon must be tested with the
   vendor build, including Rosetta if required. Windows ARM and Linux ARM are
   outside the first release.
3. Ensure the operating system credential store is available: Windows Credential
   Manager, macOS Keychain, or Linux Secret Service. On Linux, unlock the desktop
   keyring. The connector does not downgrade to plaintext credential storage.
4. Select an entitled U.S. SIMULATE account in OpenD. Keep historical files and
   data manifests on this computer. The daily-bar strategy requires 220 completed
   sessions; unavailable data disable the dependent action.

## Pair and start

1. Sign in with Google at Astra's Pick and open Strategies → Connect computer.
2. Create the single-use pairing token. Paste it only into the connector's local
   pairing prompt before it expires. Do not put it in a URL, email, screenshot,
   command history, or chat. It authorizes a device to access your strategy state.
3. Wait for the computer and its discovered paper accounts to appear in the
   workspace. Confirm the account identifier on both screens.
4. Save a strategy revision, review its data limitations, and create a paused
   **dry-run** mandate. Dry runs record decisions without sending orders.
5. Resume from the website after the connector reconciles the account. When the
   local dry-run behavior has been verified, create a paper mandate using the
   fixed rules. Do not treat passing dry runs as proof of profitability.

Use the package's pairing and start scripts. The pairing script reads the token
through a hidden prompt and sends it to the runner's standard input; it never
adds the token to the command line. The underlying runner provides `doctor`,
`pair`, `run`, and `upload-report`. `doctor` checks installation only and makes
no broker connection. Run `leo-paper-sdk --self-check` to verify the bundled SDK
and calendar imports without contacting OpenD. These checks do not prove login,
entitlement, or account availability.

When switching a dry run to paper, pause and retire the original policy after a
fresh flat reconciliation, wait for retirement acknowledgement, then create the
new paper mandate. Existing policy revisions cannot be edited in place.

## Local research

The research CLI validates a source manifest, prepares an input, calls the Rust
engine, and evaluates its replay. A daily history downloaded today can support
today's observation-based decisions; it does not establish when each historical
bar originally became available. Historical replay requires that independent
availability evidence and verified adjustments and exchange-session coverage.

Upload only the `leo-strategy-research.v1` summary in Review evidence, or use
`upload-report --research-run-id RUN_UUID --report PATH` on the paired connector.
Raw bar files stay local. Reports disclose costs, adverse gap fills, chronological
holdouts and concentration. The daily-open proxy cannot verify the 9:35–9:40
entry window. A completed report remains exploratory and cannot promote itself
or enable a mandate.

## What Pause means

“Pause requested” means the website recorded the instruction. “Entries paused”
means the connector acknowledged it. Pausing does not cancel pending orders or
close positions. Existing authorized management continues while the connector
runs. A lost authorization lease locally blocks new entries within 15 seconds.
Pending orders may still fill after a pause. Review them in your broker app.

Paper accounts do not provide native stops or an OCO guarantee. Leo's local
software stop watches fresh regular-session bids. A crossing latches an exit;
unknown submission results require reconciliation before any duplicate action.
If OpenD, the computer, or the connector stops, **protection is unavailable**.
The connector does not invent a stop crossing that occurred while disconnected.
Gaps and missing liquidity can produce losses beyond the configured stop.

Paper fill observations are derived from cumulative filled quantity and average
price. The first observed cumulative price is the recorded stop basis when an
individual first fill is unavailable. This is explicitly a paper observation,
not a reconstructed detailed deal feed. Modeled fees remain separate.

## Recover a stopped or disconnected computer

1. Inspect positions and working orders directly in the broker app. Restarting
   OpenD does not cancel orders or close positions.
2. Restore OpenD and the same connector installation and durable local database.
   Do not delete the ledger, reset sequence counters, or pair a second device to
   bypass unresolved orders. OpenD should remain bound to a local interface.
3. Allow the connector to reconcile balances, positions, and cumulative fills.
   Manual trades, unexpected differences, and account resets pause new entries.
4. Read the incident and verify the broker state before requesting resume. A
   user resume request alone cannot bypass unsuccessful reconciliation.

After a deliberate paper-account reset or manual cash change, restore a flat
account with no working or unknown orders before considering the local
`resolve-flat-account --account-id ACCOUNT --accept-flat-paper-reset` command.
Stop the connector first. This explicit operation rechecks the broker, records
the accepted reset, and leaves entries paused. It cannot clear uncertain order
outcomes or adopt an unexplained position. Preserve the journal throughout.

Linux's Secret Service must be unlocked for the current user; a headless server
needs a deliberately configured keyring session. Closing a laptop or sleeping
the operating system prevents local monitoring. The runner does not install a
secret background service or automatically start trading after installation.

## Evidence before use beyond development

Complete an actual paper entry/hold/exit cycle and deliberate restart, connection
loss, partial-fill, and manual-activity tests. Keep these broker receipts separate
from unit tests and injected fixtures. macOS signing/notarization, Windows signing,
native installation tests, data entitlement, and server deployment configuration
must be completed before public distribution. No such receipt is implied by
downloading this guide.

[Official OpenD documentation](https://openapi.moomoo.com/moomoo-api-doc/en/opend/opend-intro.html)
and [paper-account limits](https://openapi.moomoo.com/moomoo-api-doc/en/qa/trade.html).
