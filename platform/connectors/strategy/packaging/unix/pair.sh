#!/usr/bin/env bash
set -euo pipefail
set +x
[[ $# -ge 1 ]] || { echo 'Usage: pair.sh HTTPS_API_BASE [DEVICE_NAME] [SECURITY_FIRM]' >&2; exit 1; }
application="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
read -r -s -p 'Paste one-use pairing token (hidden): ' pairing_token
printf '\n' >&2
trap 'unset pairing_token' EXIT
printf '%s' "$pairing_token" | "$application/bin/leo-strategy-connector" pair --api-base "$1" --name "${2:-$(hostname)}" --engine "$application/bin/strategy-lab" --adapter "$application/adapter/leo-paper-sdk/leo-paper-sdk" --adapter-argument=--security-firm "--adapter-argument=${3:-FUTUINC}"
