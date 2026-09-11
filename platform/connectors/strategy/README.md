# Leo Strategy Connector — native development package

The connector supports deterministic dry runs and moomoo U.S. SIMULATE accounts.
It runs a Rust connector, a separate Rust `strategy-lab` engine and a bundled
Python SDK sidecar. OpenD and broker authentication stay on your computer.
Real-money and options execution are unavailable. This package is unsigned
development software. Offline checks are not broker lifecycle validation.

## Platform and prerequisite status

| Target | Package/check status |
| --- | --- |
| Windows 11 x64 | Local development MSI and ZIP build; consult the accompanying native/install receipts for actual checks. Windows signing is pending. |
| macOS 14+ Intel | Native build workflow and tar installer source; no local native build or installation receipt. Developer ID signing/notarization pending. |
| macOS 14+ Apple Silicon | Native ARM64 build workflow and tar installer source; actual vendor OpenD build and any Rosetta requirement remain unverified. Signing/notarization pending. |
| Ubuntu 22.04 / 24.04 x64 | Separate native build jobs and tar installer source; no local native receipt. A logged-in desktop Secret Service session is required. |

Use Windows Credential Manager, macOS Keychain or Linux Secret Service. The
connector stores device credentials under service `com.leo.strategy-connector`
and the device UUID. It fails when the store cannot read/write a secret; there
is no plaintext fallback. Linux headless service execution is not configured.
No startup task, Windows service, launch agent or systemd service is installed.
Keep the terminal, computer, OpenD and network healthy while managing exposure.

Python and pinned dependencies are inside the native package. The SDK is
`moomoo-api==10.10.7008`; use vendor OpenD 10.10.7008 or newer as documented on the
[official download page](https://www.moomoo.com/download/OpenAPI). OpenD itself
has not been installed or authenticated by this build. Install it separately,
authenticate there, and bind its API to `127.0.0.1:11111`. Credentials must never
be pasted into the website or chat. The US moomoo SDK security firm is `FUTUINC`;
`FUTUSECURITIES` is a different firm. Choose the firm matching your vendor account.

## Windows installation

Verify the artifact SHA-256 against the delivered `ARTIFACT-SHA256SUMS`. The
archive also contains a full file inventory in `SHA256SUMS`. Review unsigned
development provenance before running; checksum agreement does not establish a
trusted publisher. Use one of these installation paths:

* MSI: open `leo-strategy-connector-0.1.0-dev-windows-x64.msi`, or use
  `msiexec.exe /i "C:\absolute\path\leo-strategy-connector-0.1.0-dev-windows-x64.msi"`.
  It installs per user under `%LOCALAPPDATA%\Programs\LeoStrategyConnectorMsiDev`.
  Remove it through Windows Installed apps or `msiexec.exe /x "C:\absolute\path\package.msi"`.
* ZIP: extract to an ordinary folder, open PowerShell there, and run
  `& .\scripts\install.ps1`. It verifies files and installs to
  `%LOCALAPPDATA%\Programs\LeoStrategyConnectorDev`. `-InstallDir` accepts a new
  absolute application directory. Existing directories are never overwritten.
  Remove a ZIP installation using its `scripts\uninstall.ps1`.

Run the installed scripts using your organization's normal PowerShell policy;
these scripts do not change policy or bypass endpoint protection. Both uninstall
paths preserve configuration, SQLite journals and OS credentials. Neither starts
the connector, cancels orders or revokes the device.

For a ZIP installation, set the application path once:

```powershell
$app = Join-Path $env:LOCALAPPDATA 'Programs\LeoStrategyConnectorDev'
& "$app\scripts\bootstrap.ps1"
```

For MSI use `Programs\LeoStrategyConnectorMsiDev` instead. Bootstrap runs offline
checks. If a Visual C++ DLL is missing, use `bootstrap.ps1 -InstallVisualCpp` to
download the Microsoft x64 redistributable and verify its Microsoft signature
before installation. It retains the installer for inspection. A restart-required
exit is reported. This optional dependency installation was not run in the native
receipt unless explicitly recorded there.

## Pair, start and inspect

Create a one-use pairing token in Strategies → Connect computer on the configured
website. Use the deployment's actual HTTPS Strategy API base URL in this command:

```powershell
& "$app\scripts\pair.ps1" -ApiBase 'https://YOUR_STRATEGY_API_BASE' -Name 'My Windows computer'
& "$app\scripts\start.ps1"
```

The prompt hides the token, sends it to stdin and closes the stream. It never
puts the token in process arguments, a file or command history. Pairing does not
start trading. The API URL is deployment-specific; this package does not ship a
working hosted endpoint. The CLI rejects an existing paired profile. Start with
a paused dry-run mandate, confirm account identity and reconciliation, and resume
from the website. Paper mandates require separate explicit user authorization.

`scripts\diagnose.ps1` invokes `doctor`, a synthetic offline arithmetic fixture in
the separate engine, and SDK `--self-check`. These are offline;
`doctor` does not open a credential store or broker connection. `start.ps1 -Once`
is a real authorized runtime tick and can submit paper orders under an active
mandate. It is not an offline diagnostic. Close the foreground terminal only
after reviewing exposure: stopping a process is not a broker cancellation.

Direct commands are available for operators:

```powershell
& "$app\bin\leo-strategy-connector.exe" doctor
& "$app\bin\leo-strategy-connector.exe" run
& "$app\bin\leo-strategy-connector.exe" upload-report --research-run-id 'RESEARCH_RUN_UUID' --report 'C:\absolute\path\report.json'
```

For a separate local profile, put `--state-dir 'C:\absolute\state'` before the
subcommand; the scripts expose `-StateDir` where applicable. Reuse the same state
directory on restart. Pairing writes paths to `config.json`; moving an installed
package requires updating the executable paths while stopped, preserving device
identity and the journal. Do not copy a profile to run a second connector.

## State and recovery

Default state directories are `%LOCALAPPDATA%\Leo\StrategyConnector` (Windows),
`~/Library/Application Support/Leo/StrategyConnector` (macOS), and
`${XDG_STATE_HOME:-~/.local/state}/leo-strategy-connector` (Linux). `config.json`
contains endpoint, device ID and executable paths, not the device credential.
`journal.sqlite3` plus its WAL/SHM companions stores durable runtime evidence;
`research-upload.sqlite3` is the separate report outbox. Make consistent backups
while the connector is stopped; keep all SQLite companions if present.

* Pause: wait for the connector acknowledgement. Pausing inhibits new entry
  submissions; it does not cancel working orders or flatten positions. Existing
  authorized position management continues. An offline device cannot acknowledge
  a remote request. A lost control lease blocks new entries locally within its
  15-second lifetime; the normal control poll interval is five seconds.
* Computer/OpenD/network failure: inspect actual positions and pending orders in
  the broker app, restore the same installation and journal, and allow account,
  position, balance and cumulative-fill reconciliation before requesting resume.
  A process restart cannot by itself prove a broker submission failed.
* Unknown order outcome: the intent remains durable and blocks the account.
  Do not repeat it, delete the ledger, reset sequence counters, or pair another
  device to bypass the block. The bounded broker history is not proof of absence.
  Preserve evidence and resolve the broker identity/facts before further action.
* Software stop: the computer, connector, adapter and OpenD must be running with
  fresh regular-session quotes. A qualifying crossing latches local exit intent.
  There is no native broker stop/OCO guarantee. The connector cannot reconstruct
  an unobserved crossing during an outage, and gaps may exceed the configured stop.
* Manual trades/account reset/balance discrepancy: new entries pause. User resume
  cannot bypass failed reconciliation. The flat-account resolution procedure
  below is explicit and remains paused afterward.

For a manual reset, first inspect broker state, stop the connector, and make a
consistent journal backup. Only after the SIMULATE account is verified flat with
no working orders and no unresolved intent, run:

```powershell
& "$app\bin\leo-strategy-connector.exe" resolve-flat-account --account-id 'SIMULATE_ACCOUNT_ID' --accept-flat-paper-reset
```

The `--accept-flat-paper-reset` flag is the explicit local acknowledgement. The
command must obtain a fresh broker snapshot and refuses
unknown/working/non-flat states; it changes reconciliation baselines, preserves
order evidence and leaves entries paused. This does not cancel or liquidate.
Restart, observe successful reconciliation, and request resume separately.

If pairing fails after the server creates a device but before the keyring write,
revoke that device on the website and create a fresh pairing token. Revocation is
separate from uninstall. Do not remove an old journal while unresolved exposure
or intents remain. OS credentials can be removed manually from the native store
after the associated device has been revoked and no longer needs recovery.

## macOS and Linux source preparation

Native tar packages contain `scripts/install.sh`, `uninstall.sh`, `pair.sh` and
`diagnose.sh`; invoke install with `bash scripts/install.sh` after extraction. The
default application directory is `~/.local/share/leo-strategy-connector-dev`.
Pair via `bash "$app/scripts/pair.sh" 'https://YOUR_STRATEGY_API_BASE' 'My computer'`
and run `"$app/bin/leo-strategy-connector" run`. Unlock Keychain/Secret Service
first. Ubuntu build prerequisites are `build-essential pkg-config libdbus-1-dev
libssl-dev`; runtime prerequisites include `dbus-user-session`, `gnome-keyring`
and an unlocked user desktop session. No Linux plaintext or root-service fallback
is supplied. macOS requires the Xcode command line tools when building from source.

The manual workflow `.github/workflows/strategy-connector-native.yml` builds each
architecture on its own native runner. It has not been dispatched as part of the
Windows development preparation. macOS 14 Intel uses a larger runner label that
requires availability in the repository's GitHub plan. A workflow file is not a
native runtime receipt. Apple Silicon acceptance additionally requires inspecting
the actual vendor OpenD binary, running it on the target Mac, and recording
whether Rosetta is required/installed. The ARM64 sidecar build does not establish
that vendor compatibility. Ubuntu 22.04 and 24.04 are separately built and checked;
a newer glibc build must not be substituted for the older distribution.

Build in a dedicated Python 3.12 environment with Rust 1.94 and the platform build
tools. The script bundles pinned SDK requirements and PyInstaller 6.16.0, preserves
dependency notices and produces checksum/command receipts. On Windows add a WiX
3.14.1 binary directory to emit the development MSI:

```powershell
python packaging/build_native.py --output 'C:\absolute\new-output' --wix-dir 'C:\absolute\wix\bin'
```

Use `--skip-build --sidecar 'C:\absolute\leo-paper-sdk'` only for already built,
matching native sources and review the receipt. Public signing, notarization,
clean-machine install/uninstall, actual OS credential writes, entitlement, paper
entry/hold/exit, partial-fill/restart/failure tests and deployment configuration
are separate release gates. None is implied by offline test success.
