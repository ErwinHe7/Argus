#!/usr/bin/env bash
#
# Quiesce the AXIO7 single-VM writers and create a checksum-sealed rollback
# bundle. This script never prints or sources .env.server.

set -euo pipefail
umask 077

readonly REQUIRED_VOLUMES=(
  axio7_quant-state
  axio7_quant-live
  axio7_caddy-data
  axio7_caddy-config
)
readonly RUNTIME_DIRECTORIES=(
  quant-normalized
  quant-manifests
  quant-rights
  quant-evidence
  private-rights-evidence
  quant-promotion
  quant-calibration
)

die() {
  printf 'backup: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  production-release-backup.sh \
    --compose-dir /absolute/path/to/Axio7/infra/single-vm \
    --backup-root /absolute/path/to/backups \
    --expected-normalized-sha256 HEX \
    --confirm-quiesce

The command stops monitor-scheduler, Caddy, web, quantd, market-archive, and
PostgreSQL, then leaves them stopped for a release cutover. It backs up the complete quant-state and
quant-live volumes, both Caddy volumes, all immutable runtime artifact directories,
the protected server environment, Compose/Caddy configuration, image IDs, and
checksums. It never runs `docker compose down` or removes a volume.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
compose_dir="$repo_root/infra/single-vm"
backup_root="/opt/axio7/backups"
expected_normalized_sha256=""
confirmed=false
quiesced=false
backup_complete=false
root_bashpid="$BASHPID"
preflight_dir=""

cleanup() {
  local status=$?
  local running_services=""
  local service_name=""

  [[ "$BASHPID" == "$root_bashpid" ]] || return "$status"
  trap - EXIT INT TERM HUP
  set +e +u
  if ((status != 0)) && $quiesced && ! $backup_complete; then
    printf 'backup: backup failed after quiesce; restarting the unchanged deployment\n' >&2
    if env GIT_COMMIT="$release_commit" "${compose[@]}" \
      up -d --no-build --pull never --wait --wait-timeout 180 \
      >/dev/null 2>&1 \
      && running_services="$(
        env GIT_COMMIT="$release_commit" "${compose[@]}" \
          ps --status running --services
      )"; then
      for service_name in quantd web postgres market-archive caddy monitor-scheduler ibkr-gateway; do
        if ! grep -Fxq "$service_name" <<< "$running_services"; then
          printf 'backup: unchanged deployment restart verification failed\n' >&2
          break
        fi
      done
    else
      printf 'backup: unchanged deployment restart failed; services remain stopped for operator recovery\n' >&2
    fi
  fi
  if [[ -n "$preflight_dir" && -n "${backup_root:-}" \
    && "$preflight_dir" == "$backup_root"/.backup-preflight.* \
    && "$preflight_dir" != "/" ]]; then
    rm -rf -- "$preflight_dir"
  fi
  exit "$status"
}
trap cleanup EXIT

on_signal() {
  local status="$1"
  local signal_name="$2"
  printf 'backup: received %s; entering fail-closed cleanup\n' \
    "$signal_name" >&2
  exit "$status"
}
trap 'on_signal 130 INT' INT
trap 'on_signal 143 TERM' TERM
trap 'on_signal 129 HUP' HUP

volume_is_detached() {
  local volume_name="$1"
  local attached_container_ids=""

  attached_container_ids="$(
    docker ps -q --filter "volume=$volume_name"
  )" || return 1
  [[ -z "$attached_container_ids" ]]
}

runtime_tree_matches_manifest() {
  local tree_root="$1"
  local expected_manifest="$2"
  local observed_manifest="$3"
  local directory_name=""
  local unexpected_entry=""
  local private_directory="$tree_root/private-rights-evidence"
  local private_attestation="$private_directory/account_owner_attestation.json"

  for directory_name in "${RUNTIME_DIRECTORIES[@]}"; do
    [[ -d "$tree_root/$directory_name" \
      && ! -L "$tree_root/$directory_name" ]] || return 1
  done
  [[ "$(stat -c '%a' "$private_directory")" == "700" ]] || return 1
  unexpected_entry="$(
    find "$private_directory" -mindepth 1 -maxdepth 1 \
      ! -name account_owner_attestation.json -print -quit
  )" || return 1
  [[ -z "$unexpected_entry" ]] || return 1
  if [[ -e "$private_attestation" || -L "$private_attestation" ]]; then
    [[ -f "$private_attestation" \
      && ! -L "$private_attestation" \
      && "$(stat -c '%a' "$private_attestation")" == "600" ]] || return 1
  fi
  unexpected_entry="$(
    cd -- "$tree_root"
    find "${RUNTIME_DIRECTORIES[@]}" \
      ! -type d ! -type f -print -quit
  )" || return 1
  [[ -z "$unexpected_entry" ]] || return 1
  unexpected_entry="$(
    cd -- "$tree_root"
    find "${RUNTIME_DIRECTORIES[@]}" -type f -links +1 -print -quit
  )" || return 1
  [[ -z "$unexpected_entry" ]] || return 1
  (
    cd -- "$tree_root"
    find "${RUNTIME_DIRECTORIES[@]}" -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 -r sha256sum
  ) > "$observed_manifest" || return 1
  cmp --silent "$expected_manifest" "$observed_manifest"
}

while (($#)); do
  case "$1" in
    --compose-dir)
      (($# >= 2)) || die "--compose-dir requires a value"
      compose_dir="$2"
      shift 2
      ;;
    --backup-root)
      (($# >= 2)) || die "--backup-root requires a value"
      backup_root="$2"
      shift 2
      ;;
    --expected-normalized-sha256)
      (($# >= 2)) || die "--expected-normalized-sha256 requires a value"
      expected_normalized_sha256="${2,,}"
      shift 2
      ;;
    --confirm-quiesce)
      confirmed=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

$confirmed || die "refusing to stop production writers without --confirm-quiesce"
[[ "$expected_normalized_sha256" =~ ^[0-9a-f]{64}$ ]] \
  || die "--expected-normalized-sha256 must be exactly 64 hexadecimal characters"
[[ "$expected_normalized_sha256" != "$(printf '0%.0s' {1..64})" ]] \
  || die "the normalized-data SHA-256 must be nonzero"

for command_name in \
  docker git realpath sha256sum tar find sort awk cmp flock install mktemp stat tr xargs; do
  command -v "$command_name" >/dev/null 2>&1 \
    || die "required command is unavailable: $command_name"
done
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is unavailable"

compose_dir="$(realpath -e -- "$compose_dir")"
repo_root="$(realpath -e -- "$compose_dir/../..")"
runtime_dir="$compose_dir/runtime"
env_file="$compose_dir/.env.server"

[[ -f "$compose_dir/compose.yaml" ]] || die "compose.yaml is missing"
[[ -f "$compose_dir/Caddyfile" ]] || die "Caddyfile is missing"
[[ -f "$env_file" ]] || die ".env.server is missing"
mkdir -p -- "$runtime_dir"
runtime_dir="$(realpath -e -- "$runtime_dir")"
[[ "$runtime_dir" == "$compose_dir/runtime" ]] \
  || die "runtime directory resolves outside the Compose directory"
exec 9> "$runtime_dir/.production-release.lock"
flock -n 9 || die "another AXIO7 backup, rollback, or deploy operation holds the lock"

release_commit="$(git -C "$repo_root" rev-parse HEAD)"
[[ "$release_commit" =~ ^[0-9a-f]{40}$ ]] || die "HEAD is not a full Git commit"
[[ -z "$(git -C "$repo_root" status --porcelain)" ]] \
  || die "release checkout is dirty; commit or remove every source change first"

configured_commit="$(
  awk -F= '$1 == "GIT_COMMIT" { sub(/^[^=]*=/, ""); value=$0 } END { print value }' \
    "$env_file" | tr -d '\r'
)"
[[ "$configured_commit" == "$release_commit" ]] \
  || die ".env.server GIT_COMMIT does not match the clean release checkout"
[[ -z "${GIT_COMMIT:-}" || "$GIT_COMMIT" == "$release_commit" ]] \
  || die "process GIT_COMMIT does not match the clean release checkout"
export GIT_COMMIT="$release_commit"

for directory_name in "${RUNTIME_DIRECTORIES[@]}"; do
  mkdir -p -- "$runtime_dir/$directory_name"
  [[ -d "$runtime_dir/$directory_name" \
    && ! -L "$runtime_dir/$directory_name" ]] \
    || die "runtime bind target is not a real directory: $directory_name"
done
mkdir -p -- "$runtime_dir/quant-promotion/evidence"
for directory_name in "${RUNTIME_DIRECTORIES[@]}"; do
  [[ -z "$(
    find "$runtime_dir/$directory_name" -type l -print -quit
  )" ]] || die "runtime bind directories must not contain symbolic links"
done
private_attestation="$runtime_dir/private-rights-evidence/account_owner_attestation.json"
[[ "$(stat -c '%a' "$runtime_dir/private-rights-evidence")" == "700" ]] \
  || die "private owner-attestation directory mode must be 0700"
[[ -z "$(
  find "$runtime_dir/private-rights-evidence" -mindepth 1 -maxdepth 1 \
    ! -name account_owner_attestation.json -print -quit
)" ]] || die "private owner-attestation directory has an unexpected entry"
if [[ -e "$private_attestation" || -L "$private_attestation" ]]; then
  [[ -f "$private_attestation" \
    && ! -L "$private_attestation" \
    && "$(stat -c '%a' "$private_attestation")" == "600" \
    && "$(stat -c '%h' "$private_attestation")" == "1" ]] \
    || die "private owner-attestation artifact must be one mode-0600 regular file"
fi

normalized_csv="$runtime_dir/quant-normalized/market_bars.csv"

[[ -f "$normalized_csv" ]] || die "normalized market_bars.csv is missing"
[[ -n "$(find "$runtime_dir/quant-manifests" -type f -print -quit)" ]] \
  || die "runtime/quant-manifests contains no immutable manifest"

observed_normalized_sha256="$(sha256sum "$normalized_csv" | awk '{print $1}')"
[[ "$observed_normalized_sha256" == "$expected_normalized_sha256" ]] \
  || die "normalized market_bars.csv does not match the release hash"

compose=(docker compose --project-directory "$compose_dir" --env-file "$env_file")
env GIT_COMMIT="$release_commit" "${compose[@]}" config --quiet
if grep -Fq 'private-rights-evidence' "$compose_dir/compose.yaml"; then
  die "Compose must never mount the private owner-attestation directory"
fi

for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  observed_name="$(docker volume inspect --format '{{.Name}}' "$volume_name" 2>/dev/null)" \
    || die "required volume is missing: $volume_name"
  [[ "$observed_name" == "$volume_name" ]] \
    || die "resolved an unexpected volume while checking $volume_name"
done

quantd_image_id="$("${compose[@]}" images -q quantd | awk 'NR == 1 { print; exit }')"
web_image_id="$("${compose[@]}" images -q web | awk 'NR == 1 { print; exit }')"
caddy_image_id="$("${compose[@]}" images -q caddy | awk 'NR == 1 { print; exit }')"
scheduler_image_id="$(
  "${compose[@]}" images -q monitor-scheduler | awk 'NR == 1 { print; exit }'
)"
ibkr_gateway_image_id="$(
  "${compose[@]}" images -q ibkr-gateway | awk 'NR == 1 { print; exit }'
)"
postgres_image_id="$(
  "${compose[@]}" images -q postgres | awk 'NR == 1 { print; exit }'
)"
market_archive_image_id="$(
  "${compose[@]}" images -q market-archive | awk 'NR == 1 { print; exit }'
)"
[[ "$quantd_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running quantd image ID"
[[ "$web_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running web image ID"
[[ "$caddy_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running Caddy image ID"
[[ "$scheduler_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running scheduler image ID"
[[ "$ibkr_gateway_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running IBKR gateway image ID"
[[ "$postgres_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running PostgreSQL image ID"
[[ "$market_archive_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the running market-archive image ID"
quantd_image_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$quantd_image_id"
)"
web_image_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$web_image_id"
)"
market_archive_image_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$market_archive_image_id"
)"
[[ "$quantd_image_revision" == "$release_commit" ]] \
  || die "running quantd image revision does not match the release checkout"
[[ "$web_image_revision" == "$release_commit" ]] \
  || die "running web image revision does not match the release checkout"
[[ "$market_archive_image_revision" == "$release_commit" ]] \
  || die "running market-archive image revision does not match the release checkout"
for gate_name in \
  LIVE_EXECUTION_ENABLED BROKER_LIVE_ENABLED ANOMALY_LIVE_ORDER_ENABLED; do
  grep -Eq \
    "^[[:space:]]+$gate_name:[[:space:]]+[\"']?false[\"']?[[:space:]]*$" \
    "$compose_dir/compose.yaml" \
    || die "Compose does not hard-disable $gate_name"
done
docker run --rm --network none --read-only \
  --tmpfs /data:size=16m --tmpfs /config:size=16m \
  --mount \
    "type=bind,src=$compose_dir/Caddyfile,dst=/etc/caddy/Caddyfile,readonly" \
  "$caddy_image_id" \
  validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
short_commit="${release_commit:0:12}"
backup_root="$(realpath -m -- "$backup_root")"
[[ "$backup_root" = /* && "$backup_root" != "/" ]] \
  || die "--backup-root must resolve to a non-root absolute path"
mkdir -p -- "$backup_root"
chmod 0700 -- "$backup_root"
backup_root="$(realpath -e -- "$backup_root")"
case "$backup_root/" in
  "$runtime_dir/"*)
    die "backup root must not be inside the runtime directory"
    ;;
esac
case "$runtime_dir/" in
  "$backup_root/"*)
    die "runtime directory must not be inside the backup root"
    ;;
esac
backup_dir="$backup_root/release-$stamp-$short_commit"
[[ ! -e "$backup_dir" ]] || die "backup destination already exists"
mkdir -m 0700 -- "$backup_dir"

printf 'backup: quiescing production writers\n'
if ! env GIT_COMMIT="$release_commit" "${compose[@]}" \
  stop monitor-scheduler caddy web market-archive quantd postgres; then
  quiesced=true
  die "failed while quiescing production writers"
fi
quiesced=true
if ! running_services="$(
  env GIT_COMMIT="$release_commit" "${compose[@]}" \
    ps --status running --services
)"; then
  die "cannot verify that production writers stopped"
fi
for service_name in monitor-scheduler caddy web market-archive quantd postgres; do
  if grep -Fxq "$service_name" <<<"$running_services"; then
    die "service is still running after quiesce: $service_name"
  fi
done

install -m 0600 -- "$env_file" "$backup_dir/.env.server.pre"
install -m 0600 -- "$compose_dir/compose.yaml" "$backup_dir/compose.pre.yaml"
install -m 0600 -- "$compose_dir/Caddyfile" "$backup_dir/Caddyfile.pre"
git -C "$repo_root" show --no-patch --format=fuller "$release_commit" \
  > "$backup_dir/source-commit.txt"
"${compose[@]}" images --format json > "$backup_dir/images.pre.json"

quantd_rollback_tag="axio7-quantd:rollback-$stamp-$short_commit"
web_rollback_tag="axio7-web:rollback-$stamp-$short_commit"
caddy_rollback_tag="axio7-caddy:rollback-$stamp-$short_commit"
scheduler_rollback_tag="axio7-monitor-scheduler:rollback-$stamp-$short_commit"
ibkr_gateway_rollback_tag="axio7-ibkr-gateway:rollback-$stamp-$short_commit"
postgres_rollback_tag="axio7-postgres:rollback-$stamp-$short_commit"
market_archive_rollback_tag="axio7-market-archive:rollback-$stamp-$short_commit"
docker image tag "$quantd_image_id" "$quantd_rollback_tag"
docker image tag "$web_image_id" "$web_rollback_tag"
docker image tag "$caddy_image_id" "$caddy_rollback_tag"
docker image tag "$scheduler_image_id" "$scheduler_rollback_tag"
docker image tag "$ibkr_gateway_image_id" "$ibkr_gateway_rollback_tag"
docker image tag "$postgres_image_id" "$postgres_rollback_tag"
docker image tag "$market_archive_image_id" "$market_archive_rollback_tag"

cat > "$backup_dir/rollback.env" <<EOF
SOURCE_COMMIT=$release_commit
QUANTD_IMAGE_ID=$quantd_image_id
WEB_IMAGE_ID=$web_image_id
CADDY_IMAGE_ID=$caddy_image_id
SCHEDULER_IMAGE_ID=$scheduler_image_id
IBKR_GATEWAY_IMAGE_ID=$ibkr_gateway_image_id
POSTGRES_IMAGE_ID=$postgres_image_id
MARKET_ARCHIVE_IMAGE_ID=$market_archive_image_id
QUANTD_ROLLBACK_TAG=$quantd_rollback_tag
WEB_ROLLBACK_TAG=$web_rollback_tag
CADDY_ROLLBACK_TAG=$caddy_rollback_tag
SCHEDULER_ROLLBACK_TAG=$scheduler_rollback_tag
IBKR_GATEWAY_ROLLBACK_TAG=$ibkr_gateway_rollback_tag
POSTGRES_ROLLBACK_TAG=$postgres_rollback_tag
MARKET_ARCHIVE_ROLLBACK_TAG=$market_archive_rollback_tag
NORMALIZED_SHA256=$observed_normalized_sha256
QUANTD_IMAGE_REVISION=$quantd_image_revision
WEB_IMAGE_REVISION=$web_image_revision
MARKET_ARCHIVE_IMAGE_REVISION=$market_archive_image_revision
EOF

archive_volume() {
  local volume_name="$1"
  local archive_name="$2"
  volume_is_detached "$volume_name" \
    || die "cannot prove the volume is detached: $volume_name"
  docker run --rm --user 0:0 --entrypoint /bin/tar \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    --mount "type=bind,src=$backup_dir,dst=/backup" \
    "$quantd_image_id" -C /source -czf "/backup/$archive_name" .
}

archive_volume axio7_quant-state quant-state.tgz
archive_volume axio7_quant-live quant-live.tgz
archive_volume axio7_caddy-data caddy-data.tgz
archive_volume axio7_caddy-config caddy-config.tgz

(
  cd -- "$runtime_dir"
  find "${RUNTIME_DIRECTORIES[@]}" -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 -r sha256sum
) > "$backup_dir/runtime-files.sha256"
[[ -s "$backup_dir/runtime-files.sha256" ]] \
  || die "runtime bind directories contain no recoverable files"
runtime_tree_matches_manifest \
  "$runtime_dir" \
  "$backup_dir/runtime-files.sha256" \
  "$backup_dir/runtime-files.source-observed.sha256" \
  || die "runtime bind tree changed while its manifest was created"
tar -C "$runtime_dir" -czf "$backup_dir/runtime-binds.tgz" \
  "${RUNTIME_DIRECTORIES[@]}"

printf 'backup: preflighting every archive before sealing\n'
for archive_name in \
  quant-state.tgz quant-live.tgz caddy-data.tgz caddy-config.tgz \
  runtime-binds.tgz; do
  tar -tzf "$backup_dir/$archive_name" >/dev/null \
    || die "backup archive cannot be fully read: $archive_name"
done
preflight_dir="$(mktemp -d "$backup_root/.backup-preflight.XXXXXX")"
chmod 0700 -- "$preflight_dir"
mkdir -m 0700 -- "$preflight_dir/runtime"
tar -xzf "$backup_dir/runtime-binds.tgz" -C "$preflight_dir/runtime"
runtime_tree_matches_manifest \
  "$preflight_dir/runtime" \
  "$backup_dir/runtime-files.sha256" \
  "$preflight_dir/runtime-files.archive-observed.sha256" \
  || die "runtime archive does not exactly match its checksum manifest"

cat > "$backup_dir/backup-manifest.json" <<EOF
{
  "schema_version": "axio.production-backup.v1",
  "created_at": "$stamp",
  "source_commit": "$release_commit",
  "quantd_image_id": "$quantd_image_id",
  "web_image_id": "$web_image_id",
  "caddy_image_id": "$caddy_image_id",
  "scheduler_image_id": "$scheduler_image_id",
  "ibkr_gateway_image_id": "$ibkr_gateway_image_id",
  "postgres_image_id": "$postgres_image_id",
  "market_archive_image_id": "$market_archive_image_id",
  "quantd_image_revision": "$quantd_image_revision",
  "web_image_revision": "$web_image_revision",
  "market_archive_image_revision": "$market_archive_image_revision",
  "quantd_rollback_tag": "$quantd_rollback_tag",
  "web_rollback_tag": "$web_rollback_tag",
  "caddy_rollback_tag": "$caddy_rollback_tag",
  "scheduler_rollback_tag": "$scheduler_rollback_tag",
  "ibkr_gateway_rollback_tag": "$ibkr_gateway_rollback_tag",
  "postgres_rollback_tag": "$postgres_rollback_tag",
  "market_archive_rollback_tag": "$market_archive_rollback_tag",
  "normalized_market_bars_sha256": "$observed_normalized_sha256",
  "services_left_stopped": true,
  "append_only_market_database_restored_by_release_rollback": false,
  "execution_enabled": false
}
EOF

(
  cd -- "$backup_dir"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%P\0' \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum
) > "$backup_dir/SHA256SUMS"
(
  cd -- "$backup_dir"
  sha256sum --check --strict SHA256SUMS
)

backup_complete=true
printf 'backup: sealed rollback bundle: %s\n' "$backup_dir"
printf 'backup: application, archive, PostgreSQL, scheduler, and Caddy services remain stopped for cutover\n'
