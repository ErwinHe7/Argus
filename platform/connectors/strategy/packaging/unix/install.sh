#!/usr/bin/env bash
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
destination="${1:-$HOME/.local/share/leo-strategy-connector-dev}"
[[ "$destination" == /* && "$destination" != / && ! -e "$destination" && ! -L "$destination" ]] || { echo 'Choose a new absolute application directory.' >&2; exit 1; }
if [[ "$(uname -s)" == Darwin ]]; then
  (cd -- "$source_dir" && shasum -a 256 -c SHA256SUMS)
else
  (cd -- "$source_dir" && sha256sum -c SHA256SUMS)
fi
mkdir -p -- "$destination"
destination="$(cd -- "$destination" && pwd -P)"
cp -R -- "$source_dir/." "$destination/"
printf '%s\n' "$destination" > "$destination/.leo-zip-install-directory"
"$destination/bin/leo-strategy-connector" doctor
"$destination/adapter/leo-paper-sdk/leo-paper-sdk" --self-check
printf 'Installed unsigned development package at %s. Pairing and startup are separate.\n' "$destination"
