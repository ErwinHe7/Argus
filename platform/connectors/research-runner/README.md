# Continuous research operations

This runs the deterministic Python research queue and canonical Rust
`strategy-lab` engine on your own computer or Ubuntu machine. Repeated scans,
backtests, sensitivity checks, status updates and restart recovery make no LLM
calls and consume no AI tokens. The machine, storage and licensed data still
have their usual costs. Identical completed inputs are deduplicated; missing or
invalid inputs remain blocked until the input changes. This does not fabricate
data, improve a strategy by itself, promote results, or submit orders.

The optional monitor listens on `127.0.0.1:3119`. It displays research progress
and offers research pause/resume. No broker credentials or execution controls
are involved. It should remain on loopback even on a VPS.

## Configuration and prerequisites

Use a Python environment with the `intraday_quant` dependencies installed and a
native Rust `strategy-lab` binary built for the target OS. From `platform`:

```powershell
python -m venv .research-venv
& ./.research-venv/Scripts/python.exe -m pip install -e ./intraday_quant
cargo build --manifest-path ./quant_engine_rs/Cargo.toml --release --bin strategy-lab
```

An existing compatible research environment is also suitable. Never copy a
Windows virtual environment or `.exe` onto Ubuntu; build both there. The queue
config is UTF-8 JSON with an absolute local `state_dir`, absolute `engine`, and
absolute input paths. Use a dedicated private state directory outside the source
checkout. Do not point two machines at the same SQLite state or a network share.
For example, after replacing the paths with real local inputs:

```json
{
  "schema_version": "leo-continuous-research-config.v1",
  "state_dir": "C:/Users/YOU/AppData/Local/Leo/ResearchRunner",
  "engine": "C:/absolute/platform/quant_engine_rs/target/release/strategy-lab.exe",
  "interval_seconds": 30,
  "jobs": [
    {
      "id": "source-review",
      "kind": "source-capability",
      "input": "C:/absolute/research/source-evidence.json"
    }
  ]
}
```

`source-capability` evaluates the existing source-evidence contract. `research`
evaluates an existing research input and can request its bounded sensitivity
suite. These are distinct jobs, not a data downloader. Publish input updates
atomically. Changes to queue configuration require a controlled worker restart.
The research module validates config fields and inputs before admitting work.

## Windows

In PowerShell, set your actual absolute paths, then start the hidden worker and
optional local monitor:

```powershell
$platform = 'C:\absolute\platform'
$config = 'C:\absolute\research-config.json'
$python = Join-Path $platform '.research-venv\Scripts\python.exe'
& "$platform\connectors\research-runner\windows\start.ps1" -Config $config -Python $python -Dashboard
& "$platform\connectors\research-runner\windows\status.ps1" -Config $config
& "$platform\connectors\research-runner\windows\pause.ps1" -Config $config
& "$platform\connectors\research-runner\windows\resume.ps1" -Config $config
& "$platform\connectors\research-runner\windows\stop.ps1" -Config $config
```

Start is idempotent for the same config and state. The scripts remember the
Python and platform paths. `-PlatformDir` is available for a separate checkout;
`-DashboardPort` changes the optional monitor port after stopping the old monitor.
Start returns process IDs, not a guarantee that data passed validation; inspect
the latest heartbeat and worker state with status or the monitor.

The process survives closing this PowerShell window. It does not survive a
computer shutdown or user logoff, and these scripts do not install automatic
login/startup or a crash supervisor. Restart it explicitly after a crash. New
state directories receive access for the current Windows user and SYSTEM;
pre-existing directory permissions are preserved. Keep that directory private.

Stop verifies PID start time, executable, complete command line, config and state
before requesting graceful worker shutdown. The worker finishes its current
replay, then exits. The script waits 30 seconds by default (`-WaitSeconds 1..60`).
If it is still draining, it reports that fact and leaves the monitor available;
run status and stop again. After worker exit, stop requests graceful monitor
shutdown through `MONITOR_SHUTDOWN` and waits up to ten seconds. It observes
matching runtime processes as well as any Windows virtual-environment launcher;
a missing launcher alone is not proof of exit. It never kills an unverified
saved PID or deletes run history. A monitor started from an older version without
this shutdown marker must be updated before graceful stop can complete.
If identity verification fails, inspect the saved metadata and actual process;
do not edit a PID to force a stop.
Before acknowledging an old shutdown, explicit start also checks the worker's
OS file lock, so a manually launched worker without saved PID metadata is
respected.
An orphan runtime is reported as active and blocks a duplicate start. Stop sends
the validated config's shutdown request even when the saved launcher is gone,
and requires the worker's OS lock to be released before confirming shutdown.

## Ubuntu 22.04 / 24.04 VPS preparation

The credential-free research loop can run under a normal user systemd manager.
These commands assume you already have an Ubuntu machine and a source checkout;
they do not purchase or provision a VPS. Install Python, Rust and native build
prerequisites for that machine, then build and validate your research inputs:

```bash
cd /absolute/platform
python3 -m venv .research-venv
.research-venv/bin/python -m pip install -e ./intraday_quant
cargo build --manifest-path ./quant_engine_rs/Cargo.toml --release --bin strategy-lab

# Config must use this machine's absolute paths, including its native engine.
bash connectors/research-runner/linux/install-user-service.sh --dry-run \
  /absolute/platform /absolute/platform/.research-venv/bin/python /absolute/research-config.json
bash connectors/research-runner/linux/install-user-service.sh \
  /absolute/platform /absolute/platform/.research-venv/bin/python /absolute/research-config.json
systemctl --user cat leo-research.service leo-research-monitor.service
systemctl --user start leo-research.service
systemctl --user start leo-research-monitor.service  # optional
systemctl --user status leo-research.service
journalctl --user -u leo-research.service -n 50 --no-pager
```

The installer prepares user units with mode `0600`, a private `0700` research
state directory, and runtime `UMask=0077`. It does not start, enable, install a
system/root service, or enable lingering. An identical install is a no-op apart
from reloading definitions; a different existing unit is preserved and rejected
for manual review. Review rendered paths before starting. Linux process output
goes to the user journal; configure its retention according to available storage.

`Restart=on-failure` restarts crashes after a 15-second delay, with five attempts
per five minutes. A deliberate `systemctl --user stop` is not restarted by that
policy. After correcting a repeated failure, use `systemctl --user reset-failed
leo-research.service` and start it again. The unit stops its entire process group;
an active replay that exceeds the 45-second stop timeout may be terminated and
recovered as interrupted on restart. [systemd service documentation](https://github.com/systemd/systemd/blob/main/man/systemd.service.xml)

For operation after logout and reboot, explicitly enable the unit and enable
lingering for this research user. `loginctl enable-linger` may require an
administrator under the host's policy; it keeps the user manager alive after
logout and starts it at boot. It does not unlock a broker credential store.
[systemd loginctl documentation](https://github.com/systemd/systemd/blob/main/man/loginctl.xml)

```bash
systemctl --user enable leo-research.service
loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger
# Optional monitor can be enabled separately after verifying local access.
```

For pause/resume and a graceful exit request, use the same environment and config:

```bash
export PYTHONPATH=/absolute/platform/intraday_quant/src
/absolute/platform/.research-venv/bin/python -m intraday_quant.strategy_lab.continuous pause --config /absolute/research-config.json
/absolute/platform/.research-venv/bin/python -m intraday_quant.strategy_lab.continuous status --config /absolute/research-config.json
/absolute/platform/.research-venv/bin/python -m intraday_quant.strategy_lab.continuous resume --config /absolute/research-config.json
/absolute/platform/.research-venv/bin/python -m intraday_quant.strategy_lab.continuous stop --config /absolute/research-config.json
# An explicit systemd stop is also available, with the timeout described above.
systemctl --user stop leo-research.service leo-research-monitor.service
```

Keep the dashboard private. From your own computer, forward its loopback port
over SSH, then open `http://127.0.0.1:3119` locally:

```bash
ssh -N -L 127.0.0.1:3119:127.0.0.1:3119 YOUR_USER@YOUR_VPS
```

To disable future startup, run `systemctl --user disable --now
leo-research.service leo-research-monitor.service`. Preserve the config, journal,
receipts and inputs. Disable lingering only if no other user service depends on
it. No service installation, enablement or VPS deployment is implied by these
prepared files.

## State, pause and recovery

`STOP` in the configured state directory is a persistent research pause. It
prevents admission of new job batches; an already active read-only batch,
including its predeclared sensitivity variants, may finish while the heartbeat
continues. Resume removes that marker; it cannot bypass data-validation failures.
`SHUTDOWN` requests worker exit after the active replay. Ordinary service
restarts must retain shutdown/pause intent. Windows explicit start acknowledges
and clears the previous shutdown marker with a receipt, while preserving STOP.
On Linux, after verifying the worker is stopped, deliberately remove only
`SHUTDOWN` from that specific state directory before a new manual start.
`MONITOR_SHUTDOWN` separately stops the local monitor; explicit Windows dashboard
start acknowledges it. On Linux, deliberately remove that marker before manually
restarting a monitor previously stopped through it.

`trials.sqlite3`, its SQLite companions, immutable experiment receipts and
`status.json` belong to the worker. `runner.lock` is an OS-held single-writer
lock, not a file to delete to bypass a running worker. `windows-process.json`
and `windows-monitor-process.json` track the local scripts' separate processes;
timestamped stdout/stderr logs are retained under `logs/`. Back up the entire
state directory while stopped. A last saved heartbeat is historical evidence,
not proof the process is still running; check its age and process status.

## Broker execution is a separate installation

This package does not run or configure the [paper strategy connector](../strategy/README.md).
That connector still requires authenticated OpenD and the per-user secure
credential store. Its Linux package currently requires a logged-in, unlocked
Secret Service desktop session; unattended headless broker execution is not
configured. Do not replace that store with environment variables, unit files,
plaintext passwords or a root service.

Moomoo documents command-line OpenD for Ubuntu and other platforms, including
loopback API binding. OpenD 10.10 uses interactive login by default and offers a
remembered-login mode after successful authentication. That vendor capability
does not establish unattended compatibility for this connector's credential
store. Keep OpenD bound to `127.0.0.1:11111` and credentials out of chat, source
files and process arguments. [Official command-line OpenD documentation](https://openapi.moomoo.com/moomoo-api-doc/en/opend/opend-cmd.html)

## Validation receipts

On 2026-09-08, isolated Windows smoke runs passed with system Python and the
existing connector virtual environment: hidden start, paths containing spaces,
duplicate-start detection, pause/resume idempotency, elapsed time and heartbeat
status, mismatched PID refusal, graceful stop and preservation of run history.
The virtual-environment smoke also passed active-lock refusal and explicit
restart preservation of pause/shutdown intent.
The smoke fixtures use an isolated loopback HTTP listener and perform no market
calculations or external requests. A test with the actual research venv injects
detached runtime children and crashes only their test launchers. It verifies
orphan status, restart refusal, graceful exit of all matching runtimes, release
of the worker lock and closure of the HTTP port. A simple launcher-kill trial did
not retain surviving children in that environment, so detachment is an explicit
fault injection rather than a claim about every virtual environment's behavior.
Ubuntu 24.04 WSL with systemd 255 passed Bash syntax, dry-run rendering with spaces
and `systemd-analyze --user verify` for both units. No Linux service was installed
or started. Native Ubuntu VPS runtime/reboot and Ubuntu 22.04 validation remain
unverified. These process checks do not establish data quality or strategy value.

```powershell
& ./connectors/research-runner/tests/windows-smoke.ps1 -Python 'C:\absolute\python.exe'
# A Windows venv with a redirector is required for detached-orphan fault injection.
& ./connectors/research-runner/tests/windows-smoke.ps1 -Python 'C:\absolute\venv\Scripts\python.exe' -ExerciseOrphan
```

```bash
bash connectors/research-runner/tests/linux-smoke.sh
```
