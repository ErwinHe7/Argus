#!/usr/bin/env bash
set -euo pipefail
application="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
"$application/bin/leo-strategy-connector" doctor
engine_result="$(printf '%s' '{"operation":"stop","strategy":"MR-v1","first_fill_price":"100","signal_atr":"2"}' | "$application/bin/strategy-lab")"
[[ "$engine_result" == '{"initial_stop":"96.000000"}' ]] || { echo 'Separate engine synthetic offline fixture failed.' >&2; exit 1; }
"$application/adapter/leo-paper-sdk/leo-paper-sdk" --self-check
if [[ "$(uname -s)" == Linux ]]; then
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || { echo 'No desktop D-Bus session. Unlock a Secret Service keyring in a user session before pairing.' >&2; exit 1; }
  command -v busctl >/dev/null && busctl --user status org.freedesktop.secrets >/dev/null || { echo 'Secret Service availability is not verified. No plaintext fallback is supported.' >&2; exit 1; }
fi
echo 'Offline dependency checks passed; broker entitlement, orders, credential writes and control pairing were not tested.'
