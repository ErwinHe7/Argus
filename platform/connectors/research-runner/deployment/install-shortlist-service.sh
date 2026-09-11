#!/usr/bin/env bash
# Prepare the separate shortlist user unit; never starts/enables or overwrites.
set -euo pipefail
umask 077
if [[ ${1:-} == --dry-run ]]; then dry_run=1; shift; else dry_run=0; fi
if [[ $# -lt 3 || $# -gt 4 || $(uname -s) != Linux ]]; then
  printf 'Usage: bash %s [--dry-run] /absolute/platform /absolute/python /absolute/shortlist-config.json [/absolute/private/publisher.env]\n' "$0" >&2
  exit 2
fi
platform=$1
python_bin=$2
config=$3
environment_file=${4:-}
if [[ $platform != /* || $python_bin != /* || $config != /* || ! -x $python_bin ]]; then
  printf 'Absolute platform, executable Python and config paths are required.\n' >&2
  exit 2
fi
if [[ $dry_run == 0 ]]; then systemctl --user show-environment >/dev/null; fi
"$python_bin" - "$platform" "$python_bin" "$config" "$dry_run" "$environment_file" <<'PY'
import json
import os
from pathlib import Path
import stat
import sys

platform_arg, python_arg, config_arg, dry_run, environment_arg = sys.argv[1:]
platform = Path(platform_arg).resolve(strict=True)
python = Path(python_arg).absolute()
config = Path(config_arg).resolve(strict=True)
sys.path.insert(0, str(platform / 'intraday_quant/src'))
from intraday_quant.shortlist_service import load_config
load_config(config)  # The service owns its contract and path-separation checks.
settings = json.loads(config.read_text(encoding='utf-8-sig'))
state = Path(settings['state_dir'])
public = Path(settings['public_dir'])

def quote(value):
    text = str(value)
    if any(ord(char) < 32 for char in text):
        raise SystemExit('Paths must not contain control characters.')
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%') + '"'

replacements = {
    '@PLATFORM@': str(platform).replace('%', '%%'),
    '@PYTHON@': quote(python), '@CONFIG@': quote(config),
    '@PYTHONPATH@': quote('PYTHONPATH=' + str(platform / 'intraday_quant/src')),
    '@ENVIRONMENT_FILE@': '',
}
if environment_arg:
    environment = Path(environment_arg)
    if not environment.is_absolute() or environment.is_symlink():
        raise SystemExit('EnvironmentFile must be an absolute, non-linked private file.')
    environment = environment.resolve(strict=True)
    if environment.is_relative_to(public) or environment.is_relative_to(state) or environment == config:
        raise SystemExit('EnvironmentFile must stay outside public output, state and JSON config.')
    info = environment.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise SystemExit('EnvironmentFile must be owned by this user with no group/other access (chmod 600).')
    replacements['@ENVIRONMENT_FILE@'] = 'EnvironmentFile=' + quote(environment)
content = (platform / 'connectors/research-runner/deployment/leo-shortlist.service').read_text(encoding='utf-8')
for key, value in replacements.items():
    content = content.replace(key, value)
unit_dir = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'systemd/user'
if not unit_dir.is_absolute():
    raise SystemExit('XDG_CONFIG_HOME must be absolute.')
destination = unit_dir / 'leo-shortlist.service'
if destination.exists() and destination.read_text(encoding='utf-8') != content:
    raise SystemExit('Existing leo-shortlist.service differs; preserve and review it first.')
if dry_run == '1':
    print(f'# Would prepare {destination}\n{content}')
    raise SystemExit(0)
for directory in (state, public):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory.chmod(0o700)
unit_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
if not destination.exists():
    with destination.open('x', encoding='utf-8', newline='\n') as target:
        target.write(content)
destination.chmod(0o600)
print(f'Prepared {destination}')
PY
if [[ $dry_run == 0 ]]; then
  systemctl --user daemon-reload
  printf '%s\n' 'Unit prepared; no service was started or enabled.' \
    'Review: systemctl --user cat leo-shortlist.service' \
    'Start: systemctl --user start leo-shortlist.service'
fi
