#!/usr/bin/env bash
set -euo pipefail
destination="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ "$destination" == /* && "$destination" != / && -f "$destination/.leo-zip-install-directory" ]] || { echo 'Installation receipt is missing.' >&2; exit 1; }
[[ "$(cat "$destination/.leo-zip-install-directory")" == "$destination" ]] || { echo 'Installation receipt path differs.' >&2; exit 1; }
case "$destination" in "$HOME"|"$HOME/.local"|"$HOME/.local/state"|"$HOME/Library"|"$HOME/Library/Application Support"|"$HOME/.local/state/leo-strategy-connector"*|"$HOME/Library/Application Support/Leo/StrategyConnector"*) echo 'Refusing state or home directory removal.' >&2; exit 1;; esac
if [[ -n "${XDG_STATE_HOME:-}" && ( "$destination" == "$XDG_STATE_HOME" || "$destination" == "$XDG_STATE_HOME/leo-strategy-connector"* ) ]]; then echo 'Refusing state directory removal.' >&2; exit 1; fi
if pgrep -f "$destination/bin/leo-strategy-connector" >/dev/null; then echo 'Pause entries, review exposure, then stop the connector before uninstalling.' >&2; exit 1; fi
if [[ -n "$(find "$destination" -type f \( -name 'journal.sqlite3*' -o -name 'research-upload.sqlite3*' \) -print -quit)" ]]; then echo 'Local journals are inside the application directory. Preserve them outside the installation before uninstalling.' >&2; exit 1; fi
# Only the exact resolved application tree named by its installation receipt is removed.
rm -rf -- "$destination"
echo 'Application files removed. Journals, configuration and native keyring entries remain.'
