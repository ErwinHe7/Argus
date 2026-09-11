# Leo broker tools — Windows x64 development preview

These tools connect one person's computer to their own Leo account. Real-money
execution is disabled. This preview is unsigned and has passed offline software
checks; a real broker paper entry/hold/exit cycle is still required before release.
Windows SmartScreen or your organization's policy may block unsigned programs.
Do not disable those protections; signed public installers are pending.

1. Extract this ZIP. Read `native-package.json` for the exact version and hashes.
2. Open PowerShell 7 in the extracted folder and run `./install.ps1`. It downloads
   the native connector from Leo, verifies every part and the complete archive,
   checks extraction paths, then installs to a new directory under Local AppData.
   It preserves existing installations and account state. No admin access is needed.
   If scripts are blocked by your computer's policy, stop and use your approved
   installation process; the toolkit does not alter execution policy.
3. Install OpenD from https://www.moomoo.com/download/OpenAPI and sign in directly
   with your broker. Leave it running on its local port 11111. Broker credentials
   never belong in the website or chat.
4. Visit https://leo.axio7.workers.dev/#/brokers, sign in with Google and open
   **Connect computer**. Create the one-use pairing token. Run the `pair.ps1`
   command printed by the installer and paste the token at its hidden prompt.
   Select the correct security firm if your account is outside moomoo US.
5. Review the strategy, paper account, instrument and limits in Leo. Authorize
   its paper mandate, then run the printed `start.ps1` command. Pairing by itself
   does not authorize a mandate or place an order.

The connector evaluates saved rules without calling an AI model every tick.
It checks owner authorization, a fresh control lease, broker reconciliation,
market hours, quotes, available cash and position limits before paper entries.
Keep the computer awake with OpenD and the connector running. Local software
stops are unavailable when either stops; they are not native broker stops.
**Pause** blocks new entries after acknowledgment. It does not cancel pending
orders or close existing positions. Inspect orders in the broker app if interrupted.

## IBKR

The native preview includes an experimental Client Portal paper adapter. Public
IBKR automatic trading is not enabled or approved. The separate `ibkr_sdk.py`
inspector is read-only and requires the official TWS API SDK installed under its
own terms. It cannot establish that a connection is a paper account from its port
or account prefix. Do not disable the TWS Read-Only API setting for this inspector.

The experimental Client Portal path uses its own local HTTPS gateway, exact
certificate verification, a selected account, explicit paper-session verification
and a separate journal. See the bundled `IBKR.md` for its flags and
limitations. It does not bundle IBKR software or bypass IBKR's approval requirements.

## Recovery and diagnostics

Run installed `scripts/diagnose.ps1` for offline checks. The optional
`python broker_readiness.py` reports relevant broker software and local ports only;
it does not read credentials, query positions or place orders. A listening port
does not prove broker login or paper-account readiness.

After a crash, restart the gateway and sign in, then restart the same connector
profile. Never delete its database to clear an unresolved order: reconciliation
must determine its outcome before another submission. Do not use two connectors
for the same account. Revoking a device blocks its future control authorization.

`./install.ps1 -VerifyOnly` downloads and validates without executing the native
installer. `-PartsDirectory C:\absolute\downloaded-parts` supports an offline copy
of the exact checksum-pinned parts. Files remain in a unique temporary directory
for diagnosis. The manifest beside the download also gives the small toolkit ZIP's
SHA-256; it contains no broker credentials. No VPS is required for local use.
