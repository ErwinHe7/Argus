#!/usr/bin/env bash
# Prepare ignored single-VM directories without fabricating release evidence.

set -euo pipefail
umask 077

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd -- "$script_dir"

usage() {
  cat <<'EOF'
Usage: bash prepare-runtime.sh [--check-env]

Creates the ignored host directories required by the single-VM deployment,
checks the exact nine frozen source artifacts, and creates .env.server from the
tracked example only when it is absent.

--check-env additionally requires a clean checkout, requires GIT_COMMIT to
match HEAD, and runs `docker compose ... config --quiet`. It does not create or
approve rights, promotion, calibration, manifest, or market-data artifacts.
EOF
}

check_env=false
case "${1:-}" in
  "")
    ;;
  --check-env)
    check_env=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

install -d -m 0755 \
  runtime/quant-normalized \
  runtime/quant-manifests \
  runtime/quant-rights \
  runtime/quant-evidence \
  runtime/quant-promotion/evidence \
  runtime/quant-calibration
install -d -m 0700 runtime/private-rights-evidence

registry="$repo_root/quant_engine_rs/data/models/universe/registry.json"
[[ -r "$registry" ]] || {
  printf 'Frozen-universe registry is missing or unreadable: %s\n' "$registry" >&2
  exit 66
}

# SPY intentionally maps to the frozen SPX model artifact.
for artifact in SPX QQQ NVDA AAPL MU SOXX NBIS BE IGV; do
  artifact_path="$repo_root/quant_engine_rs/data/models/universe/$artifact.frozen.json"
  [[ -r "$artifact_path" ]] || {
    printf 'Frozen model artifact is missing or unreadable: %s\n' "$artifact_path" >&2
    exit 66
  }
done

if [[ ! -f .env.server ]]; then
  install -m 0600 .env.server.example .env.server
  printf '%s\n' \
    'Created infra/single-vm/.env.server from the tracked example.' \
    'Populate its required server-only values and external pins; no value was printed.'
else
  chmod 0600 .env.server
  printf '%s\n' \
    'Kept the existing infra/single-vm/.env.server and enforced mode 0600.'
fi

if [[ "$check_env" == true ]]; then
  command -v docker >/dev/null 2>&1 || {
    printf 'Docker is unavailable.\n' >&2
    exit 69
  }
  docker compose version >/dev/null 2>&1 || {
    printf 'Docker Compose v2 is unavailable.\n' >&2
    exit 69
  }
  release_commit="$(git -C "$repo_root" rev-parse HEAD)"
  [[ -z "$(git -C "$repo_root" status --porcelain)" ]] || {
    printf 'Release checkout is dirty.\n' >&2
    exit 65
  }
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
    printf '.env.server GIT_COMMIT must equal the exact clean checkout commit.\n' >&2
    exit 65
  }
  [[ "${GIT_COMMIT:-}" == "$release_commit" ]] || {
    printf 'GIT_COMMIT must equal the exact clean checkout commit.\n' >&2
    exit 65
  }
  docker compose --env-file .env.server config --quiet
  printf '%s\n' \
    'Compose interpolation and the exact nine frozen source artifacts are valid.' \
    'Private release artifacts and real-session publication are checked separately.'
else
  cat <<'EOF'
Runtime directories and all nine frozen source artifacts are present.
No market-data, rights, promotion, calibration, or acceptance evidence was
created. After populating .env.server:
  export GIT_COMMIT="$(git -C ../.. rev-parse HEAD)"
  bash prepare-runtime.sh --check-env
EOF
fi
