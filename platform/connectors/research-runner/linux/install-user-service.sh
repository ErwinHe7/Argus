#!/usr/bin/env bash
# Installs reviewable user units only. Does not start/enable services or linger.
set -euo pipefail
umask 077
if [[ ${1:-} == --dry-run ]]; then dry_run=1; shift; else dry_run=0; fi
if [[ $# != 3 ]]; then
  printf 'Usage: bash %s [--dry-run] /absolute/platform /absolute/venv/bin/python /absolute/config.json\n' "$0" >&2
  exit 2
fi
if [[ $(uname -s) != Linux ]]; then
  printf 'This installer requires native Linux with a systemd user session.\n' >&2
  exit 2
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
platform=$1
python_bin=$2
config=$3
for value in "$platform" "$python_bin" "$config"; do
  if [[ $value != /* || $value == *$'\n'* || $value == *$'\r'* ]]; then
    printf 'Paths must be absolute and contain no line breaks.\n' >&2
    exit 2
  fi
done
if [[ ! -d $platform/intraday_quant/src || ! -x $python_bin || ! -f $config ]]; then
  printf 'Missing platform source, executable Python, or config file.\n' >&2
  exit 2
fi
if [[ $dry_run == 0 ]]; then
  systemctl --user show-environment >/dev/null
fi
# Python renders unit-file quoting; no eval, shell interpolation or credentials.
"$python_bin" - "$script_dir" "$platform" "$python_bin" "$config" "$dry_run" <<'PY'
import json
import os
from pathlib import Path
import sys

templates, platform_arg, python_arg, config_arg, dry_run = sys.argv[1:]
platform = Path(platform_arg).resolve(strict=True)
python = Path(python_arg).absolute()  # Keep venv path; resolving its symlink loses the venv.
config = Path(config_arg).resolve(strict=True)
settings = json.loads(config.read_text(encoding="utf-8-sig"))
state = Path(settings["state_dir"])
engine = Path(settings["engine"])
if not state.is_absolute() or state == Path("/") or not engine.is_absolute():
    raise SystemExit("state_dir must be a dedicated absolute directory and engine must be absolute.")
if not engine.is_file() or not os.access(engine, os.X_OK):
    raise SystemExit("Build a native Linux strategy-lab engine and point config.engine to it.")
if not (platform / "intraday_quant/src/intraday_quant/strategy_lab/continuous.py").is_file():
    raise SystemExit("Continuous research module is missing.")

def quote(value):
    text = str(value)
    if any(ord(char) < 32 for char in text):
        raise SystemExit("Unit paths must contain no control characters.")
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'

replacements = {
    # WorkingDirectory is a single path field, not a shell/ExecStart word list.
    # systemd keeps embedded spaces here and would treat surrounding quotes literally.
    "@PLATFORM@": str(platform).replace("%", "%%"),
    "@PYTHON@": quote(python),
    "@CONFIG@": quote(config),
    "@PYTHONPATH@": quote("PYTHONPATH=" + str(platform / "intraday_quant/src")),
}
unit_dir = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "systemd/user"
if not unit_dir.is_absolute():
    raise SystemExit("XDG_CONFIG_HOME must be absolute when configured.")
units = {}
for name in ("leo-research.service", "leo-research-monitor.service"):
    content = (Path(templates) / name).read_text(encoding="utf-8")
    for key, value in replacements.items():
        content = content.replace(key, value)
    units[name] = content
    destination = unit_dir / name
    if destination.exists() and destination.read_text(encoding="utf-8") != content:
        raise SystemExit(f"Refusing to overwrite a different existing unit: {destination}. Review it first.")
if dry_run == "1":
    for name, content in units.items():
        print(f"# Would install {unit_dir / name}\n{content}")
    raise SystemExit(0)
state.mkdir(mode=0o700, parents=True, exist_ok=True)
# This dedicated directory is research state only; no journal contents are removed.
state.chmod(0o700)
unit_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
for name, content in units.items():
    destination = unit_dir / name
    if not destination.exists():
        with destination.open("x", encoding="utf-8", newline="\n") as output:
            output.write(content)
    destination.chmod(0o600)
    print(f"Prepared {destination}")
PY
if [[ $dry_run == 0 ]]; then
  systemctl --user daemon-reload
  printf '%s\n' \
    'Units prepared; neither service was started or enabled.' \
    'Review: systemctl --user cat leo-research.service leo-research-monitor.service' \
    'Start: systemctl --user start leo-research.service' \
    'Optional dashboard: systemctl --user start leo-research-monitor.service' \
    'Inspect: systemctl --user status leo-research.service' \
    'Logs: journalctl --user -u leo-research.service -n 50 --no-pager'
fi
