#!/bin/sh
set -eu

if [ -z "${INTRADAY_QUANT_TOKEN:-}" ] || [ "${#INTRADAY_QUANT_TOKEN}" -lt 32 ]; then
  echo "INTRADAY_QUANT_TOKEN must contain at least 32 characters" >&2
  exit 64
fi

port="${PORT:-8001}"
host="${AXIO_QUANT_HOST:-127.0.0.1}"
config="${AXIO_QUANT_CONFIG:-configs/production.yaml}"

quantd --config "$config" --host "$host" --port "$port" &
api_pid=$!
model_pid=""
options_pid=""

cleanup() {
  [ -z "$options_pid" ] || kill "$options_pid" 2>/dev/null || true
  [ -z "$model_pid" ] || kill "$model_pid" 2>/dev/null || true
  kill "$api_pid" 2>/dev/null || true
  wait "$api_pid" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

attempt=0
until curl --fail --silent "http://127.0.0.1:${port}/health" >/dev/null; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ] || ! kill -0 "$api_pid" 2>/dev/null; then
    echo "quantd failed to become healthy" >&2
    exit 70
  fi
  sleep 1
done

# The readiness command contains no order path. If the configured account lacks
# SIP/OPRA entitlement, the API remains online for historical research and
# returns DATA_UNAVAILABLE for live scans.
if quantctl --config "$config" live massive-check \
  --output data/live/massive_readiness.json; then
  quantctl --config "$config" live massive-model &
  model_pid=$!
  quantctl --config "$config" live massive-options-watch &
  options_pid=$!
else
  echo "SIP/OPRA readiness failed; live model/watchers were not started" >&2
fi

wait "$api_pid"
