#!/usr/bin/env bash
# Verify container parity and exact 9/9 frozen-model loading.
#
# This is deliberately weaker than seal-nine-symbol-acceptance.py: it may pass
# while public publication remains blocked.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd -- "$script_dir"

[[ -f .env.server ]] || {
  printf 'infra/single-vm/.env.server is missing. Run prepare-runtime.sh first.\n' >&2
  exit 66
}
command -v docker >/dev/null 2>&1 || {
  printf 'Docker is unavailable.\n' >&2
  exit 69
}
docker compose version >/dev/null 2>&1 || {
  printf 'Docker Compose v2 is unavailable.\n' >&2
  exit 69
}

release_commit="$(git -C "$repo_root" rev-parse HEAD)"
configured_commit="$(
  awk -F= '
    $1 == "GIT_COMMIT" {
      sub(/^[^=]*=/, "")
      value=$0
    }
    END { print value }
  ' .env.server | tr -d '\r'
)"
[[ "$configured_commit" == "$release_commit" ]] || {
  printf '.env.server GIT_COMMIT must equal the exact checkout commit.\n' >&2
  exit 65
}
[[ "${GIT_COMMIT:-}" == "$release_commit" ]] || {
  printf 'GIT_COMMIT must equal the exact checkout commit.\n' >&2
  exit 65
}
docker compose --env-file .env.server config --quiet

for service in quantd web market-archive; do
  image_id="$(docker compose --env-file .env.server images -q "$service")"
  [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    printf 'Cannot resolve one content-addressed %s image.\n' "$service" >&2
    exit 65
  }
  revision="$(
    docker image inspect --format \
      '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
      "$image_id"
  )"
  [[ "$revision" == "$release_commit" ]] || {
    printf '%s image revision label does not match GIT_COMMIT.\n' "$service" >&2
    exit 65
  }
done

postgres_container="$(docker compose --env-file .env.server ps -q postgres)"
[[ -n "$postgres_container" ]] || {
  printf 'postgres is not running.\n' >&2
  exit 69
}
postgres_health="$(
  docker inspect --format \
    '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
    "$postgres_container"
)"
[[ "$postgres_health" == healthy ]] || {
  printf 'postgres is not healthy: %s\n' "$postgres_health" >&2
  exit 69
}

archive_container="$(docker compose --env-file .env.server ps -q market-archive)"
[[ -n "$archive_container" ]] || {
  printf 'market-archive is not running.\n' >&2
  exit 69
}
archive_running="$(
  docker inspect --format '{{.State.Running}}|{{.State.Restarting}}' \
    "$archive_container"
)"
[[ "$archive_running" == 'true|false' ]] || {
  printf 'market-archive is not stably running.\n' >&2
  exit 69
}

archive_counts="$(
  docker compose --env-file .env.server exec -T postgres \
    psql -U axio7 -d axio7_market -Atqc \
    "SELECT COUNT(*)::text || '|' || (SELECT COUNT(*)::text FROM market_data.live_archive_receipts) FROM market_data.live_equity_minute_bars;"
)"
[[ "$archive_counts" =~ ^[1-9][0-9]*\|[1-9][0-9]*$ ]] || {
  printf 'PostgreSQL live archive has no rows or receipts.\n' >&2
  exit 69
}

quantd_container="$(docker compose --env-file .env.server ps -q quantd)"
[[ -n "$quantd_container" ]] || {
  printf 'quantd is not running.\n' >&2
  exit 69
}
health="$(
  docker inspect --format \
    '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
    "$quantd_container"
)"
[[ "$health" == healthy ]] || {
  printf 'quantd has not passed its /health liveness check: %s\n' "$health" >&2
  exit 69
}

# The probe runs inside web, so the token is read from the existing container
# environment and never appears in host process arguments or output.
docker compose --env-file .env.server exec -T web node <<'NODE'
const expectedSymbols = ['AAPL', 'BE', 'IGV', 'MU', 'NBIS', 'NVDA', 'QQQ', 'SOXX', 'SPY'];
const backend = String(process.env.INTRADAY_QUANT_API_URL || '').replace(/\/$/, '');
const token = process.env.INTRADAY_QUANT_TOKEN;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function fetchJson(path) {
  const response = await fetch(`${backend}${path}`, {
    headers: {
      Accept: 'application/json',
      'X-Research-Token': token,
    },
    cache: 'no-store',
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    throw new Error(`${path} returned HTTP ${response.status}`);
  }
  return response.json();
}

(async () => {
  assert(backend === 'http://127.0.0.1:8001',
    'web is not connected to the private quantd loopback endpoint');
  assert(typeof token === 'string' && token.length >= 32,
    'research token is unavailable inside web');

  const supervisor = await fetchJson('/ready');
  assert(supervisor?.status === 'ready',
    'live provider supervisor has not passed the explicit readiness probe');
  const universe = await fetchJson('/api/v1/research/universe');
  const runtime = universe?.model_runtime;
  assert(universe?.production_inference_owner === 'quant_engine_rs',
    'production inference owner is not Rust');
  assert(universe?.execution === 'DISABLED', 'research execution is not disabled');
  assert(runtime?.schema_version === 'axio.model-runtime-receipt.v1',
    'model-runtime schema is incompatible');
  assert(runtime?.status === 'LOADED', 'frozen model runtime is not fully loaded');
  assert(runtime?.requested_artifact_count === 9, 'requested artifact count is not nine');
  assert(runtime?.loaded_artifact_count === 9, 'loaded artifact count is not nine');
  assert(runtime?.failed_artifact_count === 0, 'one or more frozen artifacts failed');
  assert(runtime?.automatic_execution_enabled === false,
    'model runtime unexpectedly enables automatic execution');

  const loadedSymbols = Array.isArray(runtime?.symbols)
    ? runtime.symbols
        .filter((row) => row?.status === 'LOADED' && row?.reason_code == null)
        .map((row) => row.model_symbol)
        .sort()
    : [];
  assert(JSON.stringify(loadedSymbols) === JSON.stringify(expectedSymbols),
    `loaded symbol mismatch: ${JSON.stringify(loadedSymbols)}`);

  const webResponse = await fetch('http://127.0.0.1:3000/', {
    cache: 'no-store',
    signal: AbortSignal.timeout(10_000),
  });
  assert(webResponse.ok, `Next.js returned HTTP ${webResponse.status}`);

  const summary = {
    schema_version: 'axio.container-runtime-verification.v1',
    web_to_quantd: 'CONNECTED',
    inference_owner: universe.production_inference_owner,
    model_runtime: runtime.status,
    requested_artifacts: runtime.requested_artifact_count,
    loaded_artifacts: runtime.loaded_artifact_count,
    failed_artifacts: runtime.failed_artifact_count,
    loaded_symbols: loadedSymbols,
    provider_supervisor: supervisor.status,
    nextjs_http_status: webResponse.status,
    execution: universe.execution,
    public_readiness_checked_separately: true,
  };
  console.log(JSON.stringify(summary, null, 2));
})().catch((error) => {
  console.error(
    `AXIO7 container runtime verification failed: ${
      error instanceof Error ? error.message : String(error)
    }`,
  );
  process.exit(1);
});
NODE
