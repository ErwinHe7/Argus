# Native package preparation

The end-user commands, OS prerequisites and recovery contract are in
[`../README.md`](../README.md). `build_native.py` runs on the target OS and CPU,
builds the Rust runner and separate engine, freezes the pinned Python SDK bridge,
collects notices, runs offline smoke checks, and writes an unsigned development
archive with file checksums and a command receipt. It never pairs, opens OpenD,
submits broker orders, publishes, or installs automatic startup services.

The sidecar entry point is `adapter/broker_sdk.py`: moomoo remains the default,
while `--broker ibkr-gateway` selects the separate experimental Client Portal
paper adapter. Both are checked offline in each native build. The IBKR vendor
SDK is not bundled. `CARGO_TARGET_DIR`, when set, selects the exact binary output
directory used by the native build and packaging steps.

For the website development download, `broker-tools/build_broker_tools.py`
accepts the verified native ZIP and its successful build receipt. It produces
20 MiB static parts and a small Windows installer kit with per-part and complete
archive SHA-256 validation. The installer uses only Leo's HTTPS origin, refuses
redirects, checks extraction paths, and never changes execution policy or starts
trading. `test_broker_tools.py` uses synthetic archives to verify corruption,
receipt mismatch, path traversal and case-insensitive duplicate rejection.

From the repository root, use a dedicated Python 3.12 environment and Rust 1.94:

```powershell
python platform/connectors/strategy/packaging/build_native.py --output 'C:\absolute\new-output' --wix-dir 'C:\absolute\wix314\bin'
```

WiX 3.14.1 is the bounded development MSI builder. The MSI is per user, persists
its installation path for uninstall, and retains files it does not own. ICE38 and
ICE64 validation remain enabled. ICE91 is omitted because the launch condition
prohibits per-machine installation; ICE61 warns about the intentional same-version
development upgrade behavior. Production signing and installer-toolchain review
remain separate release work.

After a final source freeze, already-built source-aligned executables can be
packaged with `--skip-build --sidecar PATH_TO_FROZEN_SDK_DIRECTORY`. The supplied
directory must contain `leo-paper-sdk.exe` (Windows) or `leo-paper-sdk` (Unix) and
its `_internal` directory. This shortcut does not replace a compiler receipt.
Default profile is `release`; `--profile debug` explicitly labels a debug bundle.
Use a fresh output directory on each attempt. Failed or provisional packages are
not delivery artifacts. Registry crate files with dates before 1980 are clamped
to ZIP's oldest representable timestamp without altering their bytes.

Verify Windows packages in a new isolated directory:

```powershell
& platform/connectors/strategy/packaging/verify_windows.ps1 -Bundle 'C:\absolute\output\leo-strategy-connector-0.1.0-dev-windows-x64' -Msi 'C:\absolute\output\leo-strategy-connector-0.1.0-dev-windows-x64.msi' -Output 'C:\absolute\new-verification-directory'
```

The verifier checks the installed executables, checksum tampering, unsafe/existing
paths, custom in-application journal protection, MSI/ZIP installation and removal,
and preserved external state. Its fixture journals contain no database or broker
data. It does not contact an API, broker or credential store. The script retains
logs and a receipt. The optional VC++ bootstrap installer is not run by this test.

The manual GitHub workflow defines five separate native jobs: Windows x64,
macOS 14 Intel, macOS 14 ARM64, Ubuntu 22.04 x64 and Ubuntu 24.04 x64. Windows CI
uses Server 2022 and therefore is not a Windows 11 client acceptance receipt.
Only native Windows checks were run during this local preparation. Unix helper
syntax checks on Windows are not Unix execution tests. Actual macOS/Linux
installations, credential store integration, vendor OpenD, Apple Silicon/Rosetta,
broker entitlement/lifecycle, signing and notarization remain explicitly unrun.
