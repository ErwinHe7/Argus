#!/usr/bin/env bash
# Prepare a private local runtime. Never starts services or edits firewall/auth.
set -euo pipefail
umask 077
if [[ $# -lt 1 || $# -gt 2 || ${2:-} != '' && ${2:-} != --with-research ]]; then
  printf 'Usage: bash %s /absolute/platform [--with-research]\n' "$0" >&2
  exit 2
fi
platform=$1
if [[ $(uname -s) != Linux || $platform != /* || ! -d $platform/intraday_quant/src ]]; then
  printf 'Requires Linux and an absolute extracted platform directory.\n' >&2
  exit 2
fi
python3 -c 'import sys; assert sys.version_info >= (3, 11), "Python 3.11+ required"'
python3 "$platform/connectors/research-runner/deployment/verify_source_bundle.py" "$platform"
if [[ ! -x $platform/.research-venv/bin/python ]]; then
  # The shortlist is stdlib-only: avoid ensurepip/package downloads entirely.
  python3 -m venv --without-pip "$platform/.research-venv"
fi
export PYTHONPATH="$platform/intraday_quant/src"
"$platform/.research-venv/bin/python" -c 'from zoneinfo import ZoneInfo; ZoneInfo("America/New_York"); import intraday_quant.shortlist_service'
if [[ ${2:-} == --with-research ]]; then
  # Research uses Pydantic. The shortlist service itself uses only the stdlib.
  "$platform/.research-venv/bin/python" -m ensurepip --upgrade
  "$platform/.research-venv/bin/python" -m pip install 'pydantic>=2.7,<3'
  command -v cargo >/dev/null || { printf 'Rust 1.88+ and cargo must be installed first.\n' >&2; exit 2; }
  # One build job limits pressure on a small VPS. Rust may still need more RAM.
  CARGO_BUILD_JOBS=1 cargo build --locked --manifest-path "$platform/quant_engine_rs/Cargo.toml" --release --bin strategy-lab
  "$platform/.research-venv/bin/python" -c 'import intraday_quant.strategy_lab.continuous'
fi
printf 'Runtime prepared at %s/.research-venv; no service started or enabled.\n' "$platform"
