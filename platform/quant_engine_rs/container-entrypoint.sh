#!/bin/bash
set -eu

if [ -z "${INTRADAY_QUANT_TOKEN:-}" ] || [ "${#INTRADAY_QUANT_TOKEN}" -lt 32 ]; then
  echo "INTRADAY_QUANT_TOKEN must contain at least 32 characters" >&2
  exit 64
fi

if [ -n "${RAILWAY_PROJECT_ID:-}" ] || [ -n "${RAILWAY_ENVIRONMENT_ID:-}" ]; then
  echo "Railway deployment is intentionally blocked: quantd is a loopback-only control plane and has no TLS/mTLS listener. Use the audited single-VM shared-network-namespace deployment." >&2
  exit 78
fi

port="${PORT:-8001}"
host="${AXIO_QUANT_HOST:-127.0.0.1}"
config="${AXIO_QUANT_CONFIG:-configs/production.yaml}"
instance_lock="${AXIO_QUANT_INSTANCE_LOCK:-data/state/quantd.instance.lock}"
lock_dir=$(dirname "$instance_lock")

if ! command -v flock >/dev/null 2>&1; then
  echo "quantd singleton lock is unavailable: flock is not installed (the runtime image must include util-linux)" >&2
  exit 69
fi
if [ ! -d "$lock_dir" ]; then
  echo "quantd singleton lock directory does not exist: $lock_dir (mount the persistent quant-state volume before startup)" >&2
  exit 73
fi
if [ ! -w "$lock_dir" ]; then
  echo "quantd singleton lock directory is not writable: $lock_dir" >&2
  exit 73
fi
if ! { exec 9>"$instance_lock"; }; then
  echo "quantd singleton lock file cannot be opened for writing: $instance_lock" >&2
  exit 73
fi
if ! flock --exclusive --nonblock 9; then
  echo "quantd singleton lock is already held: $instance_lock (only one quantd instance may use this state volume)" >&2
  exit 75
fi

api_pid=""
model_pid=""
options_pid=""

cleanup() {
  exit_status=$?
  trap - EXIT INT TERM
  [ -z "$options_pid" ] || kill "$options_pid" 2>/dev/null || true
  [ -z "$model_pid" ] || kill "$model_pid" 2>/dev/null || true
  [ -z "$api_pid" ] || kill "$api_pid" 2>/dev/null || true
  [ -z "$options_pid" ] || wait "$options_pid" 2>/dev/null || true
  [ -z "$model_pid" ] || wait "$model_pid" 2>/dev/null || true
  [ -z "$api_pid" ] || wait "$api_pid" 2>/dev/null || true
  exit "$exit_status"
}
trap 'exit 130' INT
trap 'exit 143' TERM
trap cleanup EXIT

quantd --config "$config" --host "$host" --port "$port" &
api_pid=$!

attempt=0
until curl --fail --silent "http://127.0.0.1:${port}/health" >/dev/null; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ] || ! kill -0 "$api_pid" 2>/dev/null; then
    echo "quantd failed to become healthy" >&2
    exit 70
  fi
  sleep 1
done

# Massive workers are opt-in because the canonical production configuration
# currently uses Databento for equities. quantd supervises that in-process
# Databento task; this shell owns only explicitly enabled Massive children.
if [ "${AXIO_START_MASSIVE_WORKERS:-false}" = "true" ]; then
  historical_bars="${AXIO_HISTORICAL_BARS:-data/normalized/market_bars.csv}"
  universe_registry="${AXIO_UNIVERSE_REGISTRY:-data/models/universe/registry.json}"
  prediction_ledger="${AXIO_PREDICTION_LEDGER:-data/state/prediction_ledger.sqlite3}"
  # SIP and OPRA are intentionally gated independently: an options entitlement
  # failure must not suppress a healthy equities shadow-model worker, and the
  # inverse is also true. Neither readiness command contains an order path.
  if quantctl --config "$config" live massive-check \
    --scope equity \
    --output data/live/massive_readiness.json; then
    if [ ! -r "$historical_bars" ]; then
      echo "Massive equities model was not started: historical bars are not readable at $historical_bars" >&2
    elif [ ! -r "$universe_registry" ]; then
      echo "Massive equities model was not started: universe registry is not readable at $universe_registry" >&2
    else
      quantctl --config "$config" live massive-model \
        --historical-bars "$historical_bars" \
        --universe-registry "$universe_registry" \
        --ledger "$prediction_ledger" &
      model_pid=$!
    fi
  else
    echo "Massive SIP readiness failed; equities model worker was not started" >&2
  fi
  if quantctl --config "$config" live massive-check \
    --scope options \
    --output data/live/massive_readiness.json; then
    quantctl --config "$config" live massive-options-watch &
    options_pid=$!
  else
    echo "Massive OPRA readiness failed; options watcher was not started" >&2
  fi
fi

# Bash wait -n reaps the first child that exits. Polling kill -0 is unsafe here
# because it continues to succeed for an unreaped zombie and can leave a dead
# quantd container looking alive forever.
child_pids=("$api_pid")
[ -z "$model_pid" ] || child_pids+=("$model_pid")
[ -z "$options_pid" ] || child_pids+=("$options_pid")
exited_pid=""
if wait -n -p exited_pid "${child_pids[@]}"; then
  child_status=0
else
  child_status=$?
fi

if [ -z "$exited_pid" ]; then
  echo "entrypoint could not reap a supervised child (wait status $child_status)" >&2
  exit 70
fi

case "$exited_pid" in
  "$api_pid")
    child_name="quantd"
    successful_exit_status=70
    ;;
  "$model_pid")
    child_name="Massive model worker"
    successful_exit_status=71
    ;;
  "$options_pid")
    child_name="Massive options worker"
    successful_exit_status=72
    ;;
  *)
    echo "entrypoint could not identify exited child: $exited_pid" >&2
    exit 70
    ;;
esac
echo "$child_name exited unexpectedly with status $child_status" >&2
[ "$child_status" -ne 0 ] || child_status="$successful_exit_status"
exit "$child_status"
