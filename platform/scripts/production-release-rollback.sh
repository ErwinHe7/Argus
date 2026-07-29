#!/usr/bin/env bash
#
# Restore one checksum-verified bundle produced by
# production-release-backup.sh. Every release archive is fully preflighted
# before the running deployment is stopped. The destructive volume restore is
# limited to four exact AXIO7 volume names and requires explicit confirmation.

set -euo pipefail
umask 077

readonly RESTORE_VOLUMES=(
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
  printf 'rollback: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  production-release-rollback.sh \
    --compose-dir /absolute/path/to/Axio7/infra/single-vm \
    --backup-dir /absolute/path/to/release-backup \
    --confirm-restore

The command verifies every checksum and image revision, fully extracts the
release archives into isolated staging storage, stops production writers,
creates a checksum-sealed emergency backup of the current deployment, restores
the matching state/live/Caddy/runtime set, retags the exact prior image IDs,
and starts Compose with --no-build --pull never. A failure after replacement
begins triggers a best-effort restore of the emergency backup.
EOF
}

read_metadata_value() {
  local key="$1"
  local file="$2"
  awk -F= -v wanted="$key" '
    $1 == wanted {
      sub(/^[^=]*=/, "")
      value=$0
    }
    END { print value }
  ' "$file" | tr -d '\r'
}

assert_safe_archive_members() {
  local archive_path="$1"
  local listing_path="$2"
  local member=""
  local normalized=""
  local component=""
  local -a components=()

  tar -tzf "$archive_path" > "$listing_path" \
    || die "cannot list archive: $(basename -- "$archive_path")"
  [[ -s "$listing_path" ]] \
    || die "archive is empty: $(basename -- "$archive_path")"

  while IFS= read -r member || [[ -n "$member" ]]; do
    [[ "$member" != /* ]] \
      || die "archive contains an absolute path: $(basename -- "$archive_path")"
    normalized="${member#./}"
    [[ -z "$normalized" || "$normalized" == "." ]] && continue
    IFS='/' read -r -a components <<< "$normalized"
    for component in "${components[@]}"; do
      [[ "$component" != ".." ]] \
        || die "archive contains path traversal: $(basename -- "$archive_path")"
    done
  done < "$listing_path"
}

assert_safe_runtime_archive_members() {
  local archive_path="$1"
  local listing_path="$2"
  local verbose_listing_path="$3"
  local member=""
  local normalized=""
  local verbose_line=""
  local member_type=""

  while IFS= read -r member || [[ -n "$member" ]]; do
    normalized="${member#./}"
    [[ -z "$normalized" || "$normalized" == "." ]] && continue
    runtime_manifest_path_is_allowed "$normalized" \
      || die "runtime archive contains an unapproved top-level path"
  done < "$listing_path"

  tar -tvzf "$archive_path" > "$verbose_listing_path" \
    || die "cannot inspect runtime archive member types"
  while IFS= read -r verbose_line || [[ -n "$verbose_line" ]]; do
    [[ -n "$verbose_line" ]] || continue
    member_type="${verbose_line:0:1}"
    case "$member_type" in
      -|d)
        ;;
      *)
        die "runtime archive contains a link or special member"
        ;;
    esac
  done < "$verbose_listing_path"
}

runtime_directory_name_is_allowed() {
  case "$1" in
    quant-normalized|quant-manifests|quant-rights|quant-evidence|private-rights-evidence|quant-promotion|quant-calibration)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

runtime_manifest_path_is_allowed() {
  local relative_path="$1"
  local component=""
  local -a components=()

  [[ -n "$relative_path" && "$relative_path" != /* ]] || return 1
  IFS='/' read -r -a components <<< "$relative_path"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" != "." && "$component" != ".." ]] \
      || return 1
  done
  runtime_directory_name_is_allowed "${components[0]}"
}

assert_safe_runtime_manifest() {
  local manifest_path="$1"
  local line=""
  local relative_path=""
  local line_count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_count += 1))
    [[ "$line" =~ ^[0-9a-f]{64}[[:space:]][\ \*](.+)$ ]] \
      || die "runtime checksum manifest contains an invalid line"
    relative_path="${BASH_REMATCH[1]}"
    runtime_manifest_path_is_allowed "$relative_path" \
      || die "runtime checksum manifest escapes the approved directories"
  done < "$manifest_path"
  ((line_count > 0)) || die "runtime checksum manifest is empty"
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

write_image_model_manifest() {
  local image_id="$1"
  local output_path="$2"

  docker run --rm --network none --read-only --entrypoint /bin/sh \
    "$image_id" -ec '
      root=/app/data/models/universe
      test -d "$root"
      test -z "$(find "$root" ! -type d ! -type f -print -quit)"
      test -z "$(find "$root" -type f -links +1 -print -quit)"
      find "$root" -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum
    ' > "$output_path"
  [[ -s "$output_path" ]]
}

volume_is_detached() {
  local volume_name="$1"
  local attached_container_ids=""

  attached_container_ids="$(
    docker ps -q --filter "volume=$volume_name"
  )" || return 1
  [[ -z "$attached_container_ids" ]]
}

stop_project_writers_by_label() {
  local container_ids=""
  local service_name=""

  for service_name in monitor-scheduler caddy web quantd; do
    container_ids="$(
      docker ps -q \
        --filter label=com.docker.compose.project=axio7 \
        --filter "label=com.docker.compose.service=$service_name"
    )" || return 1
    if [[ -n "$container_ids" ]]; then
      # The IDs come only from the exact Compose project/service label pair.
      # shellcheck disable=SC2086
      docker stop $container_ids >/dev/null 2>&1 || return 1
    fi
    container_ids="$(
      docker ps -q \
        --filter label=com.docker.compose.project=axio7 \
        --filter "label=com.docker.compose.service=$service_name"
    )" || return 1
    [[ -z "$container_ids" ]] || return 1
  done
}

archive_current_volume() {
  local volume_name="$1"
  local archive_name="$2"
  local destination_dir="$3"
  local helper_image="$4"

  case "$volume_name:$archive_name" in
    axio7_quant-state:quant-state.before-rollback.tgz|\
    axio7_quant-live:quant-live.before-rollback.tgz|\
    axio7_caddy-data:caddy-data.before-rollback.tgz|\
    axio7_caddy-config:caddy-config.before-rollback.tgz)
      ;;
    *)
      die "refusing to archive an unapproved volume target"
      ;;
  esac

  volume_is_detached "$volume_name" \
    || die "cannot prove the volume is detached: $volume_name"
  docker run --rm --user 0:0 --entrypoint /bin/tar \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    --mount "type=bind,src=$destination_dir,dst=/backup" \
    "$helper_image" -C /source -czf "/backup/$archive_name" .
}

restore_volume_from_staging() {
  local volume_name="$1"
  local staging_volume="$2"
  local helper_image="$3"
  local observed_name=""

  case "$volume_name" in
    axio7_quant-state|axio7_quant-live|axio7_caddy-data|axio7_caddy-config)
      ;;
    *)
      return 1
      ;;
  esac
  [[ "$staging_volume" == axio7-rollback-stage-* ]] || return 1

  observed_name="$(docker volume inspect --format '{{.Name}}' "$volume_name")" \
    || return 1
  [[ "$observed_name" == "$volume_name" ]] || return 1
  volume_is_detached "$volume_name" || return 1

  docker run --rm --user 0:0 --entrypoint /bin/sh \
    --mount "type=volume,src=$volume_name,dst=/target" \
    --mount "type=volume,src=$staging_volume,dst=/source,readonly" \
    "$helper_image" -ec '
      mountpoint -q /target
      mountpoint -q /source
      test -d /target
      test -d /source
      find /target -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      tar -C /source -cf - . | tar -C /target -xf -
    '
}

restore_volume_from_archive() {
  local volume_name="$1"
  local archive_name="$2"
  local archive_dir="$3"
  local helper_image="$4"
  local observed_name=""

  case "$volume_name:$archive_name" in
    axio7_quant-state:quant-state.before-rollback.tgz|\
    axio7_quant-live:quant-live.before-rollback.tgz|\
    axio7_caddy-data:caddy-data.before-rollback.tgz|\
    axio7_caddy-config:caddy-config.before-rollback.tgz)
      ;;
    *)
      return 1
      ;;
  esac

  observed_name="$(docker volume inspect --format '{{.Name}}' "$volume_name")" \
    || return 1
  [[ "$observed_name" == "$volume_name" ]] || return 1
  volume_is_detached "$volume_name" || return 1

  docker run --rm --user 0:0 --entrypoint /bin/sh \
    --mount "type=volume,src=$volume_name,dst=/target" \
    --mount "type=bind,src=$archive_dir,dst=/backup,readonly" \
    "$helper_image" -ec '
      mountpoint -q /target
      test -d /target
      find /target -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      tar -xzf "/backup/$1" -C /target
    ' restore-volume "$archive_name"
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
compose_dir="$repo_root/infra/single-vm"
backup_dir=""
confirmed=false
work_dir=""
runtime_dir=""
emergency_dir=""
displaced_dir=""
current_commit=""
current_quantd_image_id=""
current_web_image_id=""
current_caddy_image_id=""
current_scheduler_image_id=""
current_ibkr_gateway_image_id=""
current_quantd_tag=""
current_web_tag=""
current_caddy_tag=""
current_scheduler_tag=""
current_ibkr_gateway_tag=""
destructive_started=false
emergency_sealed=false
rollback_succeeded=false
recovery_attempted=false
recovery_succeeded=false
quiesced=false
root_bashpid="$BASHPID"
declare -a staging_volumes=()

cleanup() {
  local status=$?
  local volume_name=""
  local preserve_staging=false

  [[ "$BASHPID" == "$root_bashpid" ]] || return "$status"
  trap - EXIT ERR INT TERM HUP
  set +e +u

  if ((status != 0)); then
    if $destructive_started && $emergency_sealed && ! $rollback_succeeded; then
      attempt_emergency_recovery || true
    elif $quiesced && ! $destructive_started && ! $rollback_succeeded; then
      restart_unchanged_current || true
    fi
  fi

  if $destructive_started && ! $rollback_succeeded && ! $recovery_succeeded; then
    preserve_staging=true
  fi

  if ! $preserve_staging; then
    for volume_name in "${staging_volumes[@]}"; do
      if [[ "$volume_name" == axio7-rollback-stage-* ]]; then
        docker volume rm "$volume_name" >/dev/null 2>&1 || true
      fi
    done
    if [[ -n "$work_dir" && -n "${backup_parent:-}" \
      && "$work_dir" == "$backup_parent"/.rollback-work.* \
      && "$work_dir" != "/" ]]; then
      rm -rf -- "$work_dir"
    fi
  else
    printf 'rollback: retained preflight staging for manual recovery: %s\n' \
      "$work_dir" >&2
  fi
  exit "$status"
}
trap cleanup EXIT

on_signal() {
  local status="$1"
  local signal_name="$2"
  printf 'rollback: received %s; entering fail-closed cleanup\n' \
    "$signal_name" >&2
  exit "$status"
}
trap 'on_signal 130 INT' INT
trap 'on_signal 143 TERM' TERM
trap 'on_signal 129 HUP' HUP

restore_emergency_runtime() {
  local recovery_stage="$runtime_dir/.emergency-restore-$rollback_stamp"
  local directory_name=""

  [[ -n "$runtime_dir" && "$runtime_dir" != "/" ]] || return 1
  [[ "$recovery_stage" == "$runtime_dir"/.emergency-restore-* ]] || return 1
  [[ ! -e "$recovery_stage" ]] || return 1
  mkdir -m 0700 -- "$recovery_stage" || return 1
  tar -xzf "$emergency_dir/runtime-binds.before-rollback.tgz" \
    -C "$recovery_stage" || return 1

  runtime_tree_matches_manifest \
    "$recovery_stage" \
    "$emergency_dir/runtime-files.before-rollback.sha256" \
    "$work_dir/runtime-files.recovery-observed.sha256" \
    || return 1

  for directory_name in "${RUNTIME_DIRECTORIES[@]}"; do
    runtime_directory_name_is_allowed "$directory_name" || return 1
    rm -rf -- "$runtime_dir/$directory_name" || return 1
    mv -- "$recovery_stage/$directory_name" \
      "$runtime_dir/$directory_name" || return 1
  done
  rmdir -- "$recovery_stage" || return 1
}

attempt_emergency_recovery() {
  local recovery_failed=false
  local emergency_compose=()
  local container_id=""
  local health_status=""
  local restored_image=""
  local running_services=""
  local service_name=""
  local volume_name=""

  if $recovery_attempted; then
    $recovery_succeeded
    return
  fi
  recovery_attempted=true
  printf 'rollback: replacement failed; attempting emergency-state recovery\n' >&2
  stop_project_writers_by_label || recovery_failed=true
  for volume_name in "${RESTORE_VOLUMES[@]}"; do
    volume_is_detached "$volume_name" || recovery_failed=true
  done
  if $recovery_failed; then
    printf 'rollback: could not prove all writers stopped; emergency state was not modified or restarted\n' >&2
    return 1
  fi

  restore_volume_from_archive \
    axio7_quant-state quant-state.before-rollback.tgz \
    "$emergency_dir" "$current_quantd_image_id" \
    || recovery_failed=true
  restore_volume_from_archive \
    axio7_quant-live quant-live.before-rollback.tgz \
    "$emergency_dir" "$current_quantd_image_id" \
    || recovery_failed=true
  restore_volume_from_archive \
    axio7_caddy-data caddy-data.before-rollback.tgz \
    "$emergency_dir" "$current_quantd_image_id" \
    || recovery_failed=true
  restore_volume_from_archive \
    axio7_caddy-config caddy-config.before-rollback.tgz \
    "$emergency_dir" "$current_quantd_image_id" \
    || recovery_failed=true
  restore_emergency_runtime || recovery_failed=true

  install -m 0600 -- "$emergency_dir/.env.server.current" \
    "$compose_dir/.env.server" || recovery_failed=true
  install -m 0644 -- "$emergency_dir/compose.current.yaml" \
    "$compose_dir/compose.yaml" || recovery_failed=true
  install -m 0644 -- "$emergency_dir/Caddyfile.current" \
    "$compose_dir/Caddyfile" || recovery_failed=true

  docker image tag "$current_quantd_image_id" "axio7-quantd:$current_commit" \
    || recovery_failed=true
  docker image tag "$current_web_image_id" "axio7-web:$current_commit" \
    || recovery_failed=true
  docker image tag "$current_quantd_image_id" axio7-quantd:latest \
    || recovery_failed=true
  docker image tag "$current_web_image_id" axio7-web:latest \
    || recovery_failed=true
  docker image tag "$current_quantd_image_id" "$current_quantd_tag" \
    || recovery_failed=true
  docker image tag "$current_web_image_id" "$current_web_tag" \
    || recovery_failed=true
  docker image tag "$current_caddy_image_id" caddy:2.10-alpine \
    || recovery_failed=true
  docker image tag "$current_scheduler_image_id" curlimages/curl:8.14.1 \
    || recovery_failed=true
  docker image tag "$current_ibkr_gateway_image_id" axio7-ibkr-gateway:latest \
    || recovery_failed=true
  docker image tag "$current_caddy_image_id" "$current_caddy_tag" \
    || recovery_failed=true
  docker image tag "$current_scheduler_image_id" "$current_scheduler_tag" \
    || recovery_failed=true
  docker image tag "$current_ibkr_gateway_image_id" "$current_ibkr_gateway_tag" \
    || recovery_failed=true

  if $recovery_failed; then
    printf 'rollback: emergency restore was incomplete; all application writers remain stopped; use %s\n' \
      "$emergency_dir" >&2
    return 1
  fi

  emergency_compose=(
    docker compose
    --project-directory "$compose_dir"
    --env-file "$compose_dir/.env.server"
  )
  env GIT_COMMIT="$current_commit" "${emergency_compose[@]}" config --quiet \
    || recovery_failed=true
  if ! $recovery_failed; then
    env GIT_COMMIT="$current_commit" "${emergency_compose[@]}" \
      up -d --no-build --pull never --force-recreate \
      --wait --wait-timeout 180 >/dev/null 2>&1 \
      || recovery_failed=true
  fi

  if ! $recovery_failed; then
    if ! env GIT_COMMIT="$current_commit" "${emergency_compose[@]}" \
      exec -T quantd sh -ec '
        root=/app/data/models/universe
        test -d "$root"
        test -z "$(find "$root" ! -type d ! -type f -print -quit)"
        test -z "$(find "$root" -type f -links +1 -print -quit)"
        find "$root" -type f -print0 \
          | LC_ALL=C sort -z | xargs -0 -r sha256sum
      ' > "$work_dir/current-model-universe.restored.sha256" \
      || ! cmp --silent \
        "$work_dir/current-model-universe.sha256" \
        "$work_dir/current-model-universe.restored.sha256"; then
      recovery_failed=true
    fi
  fi

  if ! $recovery_failed; then
    for service_name in quantd web; do
      if ! container_id="$(
        env GIT_COMMIT="$current_commit" "${emergency_compose[@]}" \
          ps -q "$service_name"
      )" || [[ -z "$container_id" || "$container_id" == *$'\n'* ]]; then
        recovery_failed=true
        break
      fi
      if ! health_status="$(
        docker inspect --format \
          '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
          "$container_id"
      )" || [[ "$health_status" != "healthy" ]]; then
        recovery_failed=true
        break
      fi
    done
  fi

  if ! $recovery_failed; then
    if ! running_services="$(
      env GIT_COMMIT="$current_commit" "${emergency_compose[@]}" \
        ps --status running --services
    )"; then
      recovery_failed=true
    else
      for service_name in quantd web caddy monitor-scheduler ibkr-gateway; do
        grep -Fxq "$service_name" <<< "$running_services" \
          || recovery_failed=true
      done
    fi
  fi

  if ! $recovery_failed; then
    for service_name in quantd web caddy monitor-scheduler ibkr-gateway; do
      if ! restored_image="$(
        env GIT_COMMIT="$current_commit" "${emergency_compose[@]}" \
          images -q "$service_name"
      )"; then
        recovery_failed=true
        break
      fi
      case "$service_name:$restored_image" in
        "quantd:$current_quantd_image_id"|\
        "web:$current_web_image_id"|\
        "caddy:$current_caddy_image_id"|\
        "monitor-scheduler:$current_scheduler_image_id"|\
        "ibkr-gateway:$current_ibkr_gateway_image_id")
          ;;
        *)
          recovery_failed=true
          break
          ;;
      esac
    done
  fi

  if $recovery_failed; then
    if stop_project_writers_by_label; then
      printf 'rollback: emergency state was restored but runtime verification failed; writers are stopped; use %s\n' \
        "$emergency_dir" >&2
    else
      printf 'rollback: emergency runtime verification failed and writer shutdown could not be proven; isolate the host and use %s\n' \
        "$emergency_dir" >&2
    fi
    return 1
  fi

  recovery_succeeded=true
  destructive_started=false
  quiesced=false
  printf 'rollback: emergency state and exact application images were restored and verified; rollback remains failed\n' >&2
  return 0
}

restart_unchanged_current() {
  local running_services=""
  local service_name=""

  printf 'rollback: failure occurred before overwrite; restarting the unchanged deployment\n' >&2
  if ! env GIT_COMMIT="$current_commit" "${current_compose[@]}" \
    up -d --no-build --pull never --wait --wait-timeout 180 \
    >/dev/null 2>&1; then
    printf 'rollback: unchanged deployment restart failed; services remain stopped for operator recovery\n' >&2
    return 1
  fi
  if ! running_services="$(
    env GIT_COMMIT="$current_commit" "${current_compose[@]}" \
      ps --status running --services
  )"; then
    return 1
  fi
  for service_name in quantd web caddy monitor-scheduler ibkr-gateway; do
    grep -Fxq "$service_name" <<< "$running_services" || return 1
  done
  quiesced=false
  printf 'rollback: unchanged deployment restarted successfully\n' >&2
  return 0
}

while (($#)); do
  case "$1" in
    --compose-dir)
      (($# >= 2)) || die "--compose-dir requires a value"
      compose_dir="$2"
      shift 2
      ;;
    --backup-dir)
      (($# >= 2)) || die "--backup-dir requires a value"
      backup_dir="$2"
      shift 2
      ;;
    --confirm-restore)
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

$confirmed || die "refusing to restore persistent volumes without --confirm-restore"
[[ -n "$backup_dir" ]] || die "--backup-dir is required"

for command_name in \
  docker realpath sha256sum tar find awk cmp flock install mktemp grep sort stat xargs; do
  command -v "$command_name" >/dev/null 2>&1 \
    || die "required command is unavailable: $command_name"
done
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is unavailable"

compose_dir="$(realpath -e -- "$compose_dir")"
backup_dir="$(realpath -e -- "$backup_dir")"
backup_parent="$(realpath -e -- "$(dirname -- "$backup_dir")")"
[[ "$backup_dir" = /* && "$backup_dir" != "/" ]] \
  || die "--backup-dir must resolve to a non-root absolute path"
[[ "$compose_dir" = /* && "$compose_dir" != "/" ]] \
  || die "--compose-dir must resolve to a non-root absolute path"
runtime_dir="$compose_dir/runtime"
mkdir -p -- "$runtime_dir"
runtime_dir="$(realpath -e -- "$runtime_dir")"
[[ "$runtime_dir" == "$compose_dir/runtime" ]] \
  || die "runtime directory resolves outside the Compose directory"
case "$backup_dir/" in
  "$runtime_dir/"*)
    die "backup directory must not be inside the runtime directory"
    ;;
esac
case "$runtime_dir/" in
  "$backup_dir/"*)
    die "runtime directory must not be inside the backup directory"
    ;;
esac
exec 9> "$runtime_dir/.production-release.lock"
flock -n 9 || die "another AXIO7 backup, rollback, or deploy operation holds the lock"

for required_file in \
  SHA256SUMS rollback.env backup-manifest.json .env.server.pre \
  compose.pre.yaml Caddyfile.pre runtime-binds.tgz runtime-files.sha256 \
  quant-state.tgz quant-live.tgz caddy-data.tgz caddy-config.tgz; do
  [[ -f "$backup_dir/$required_file" ]] \
    || die "required backup file is missing: $required_file"
done

printf 'rollback: verifying backup checksums and metadata\n'
(
  cd -- "$backup_dir"
  sha256sum --check --strict SHA256SUMS
)

source_commit="$(read_metadata_value SOURCE_COMMIT "$backup_dir/rollback.env")"
quantd_image_id="$(read_metadata_value QUANTD_IMAGE_ID "$backup_dir/rollback.env")"
web_image_id="$(read_metadata_value WEB_IMAGE_ID "$backup_dir/rollback.env")"
caddy_image_id="$(read_metadata_value CADDY_IMAGE_ID "$backup_dir/rollback.env")"
scheduler_image_id="$(
  read_metadata_value SCHEDULER_IMAGE_ID "$backup_dir/rollback.env"
)"
ibkr_gateway_image_id="$(
  read_metadata_value IBKR_GATEWAY_IMAGE_ID "$backup_dir/rollback.env"
)"
quantd_rollback_tag="$(
  read_metadata_value QUANTD_ROLLBACK_TAG "$backup_dir/rollback.env"
)"
web_rollback_tag="$(
  read_metadata_value WEB_ROLLBACK_TAG "$backup_dir/rollback.env"
)"
caddy_rollback_tag="$(
  read_metadata_value CADDY_ROLLBACK_TAG "$backup_dir/rollback.env"
)"
scheduler_rollback_tag="$(
  read_metadata_value SCHEDULER_ROLLBACK_TAG "$backup_dir/rollback.env"
)"
ibkr_gateway_rollback_tag="$(
  read_metadata_value IBKR_GATEWAY_ROLLBACK_TAG "$backup_dir/rollback.env"
)"
metadata_quantd_revision="$(
  read_metadata_value QUANTD_IMAGE_REVISION "$backup_dir/rollback.env"
)"
metadata_web_revision="$(
  read_metadata_value WEB_IMAGE_REVISION "$backup_dir/rollback.env"
)"

[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || die "backup source commit is invalid"
[[ "$quantd_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "backup quantd image ID is invalid"
[[ "$web_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "backup web image ID is invalid"
[[ "$caddy_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "backup Caddy image ID is invalid"
[[ "$scheduler_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "backup scheduler image ID is invalid"
[[ "$ibkr_gateway_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "backup IBKR gateway image ID is invalid"
[[ "$quantd_rollback_tag" =~ ^axio7-quantd:rollback-[0-9TZ-]+-[0-9a-f]{12}$ ]] \
  || die "backup quantd rollback tag is invalid"
[[ "$web_rollback_tag" =~ ^axio7-web:rollback-[0-9TZ-]+-[0-9a-f]{12}$ ]] \
  || die "backup web rollback tag is invalid"
[[ "$caddy_rollback_tag" =~ ^axio7-caddy:rollback-[0-9TZ-]+-[0-9a-f]{12}$ ]] \
  || die "backup Caddy rollback tag is invalid"
[[ "$scheduler_rollback_tag" =~ ^axio7-monitor-scheduler:rollback-[0-9TZ-]+-[0-9a-f]{12}$ ]] \
  || die "backup scheduler rollback tag is invalid"
[[ "$ibkr_gateway_rollback_tag" =~ ^axio7-ibkr-gateway:rollback-[0-9TZ-]+-[0-9a-f]{12}$ ]] \
  || die "backup IBKR gateway rollback tag is invalid"
[[ "$metadata_quantd_revision" == "$source_commit" ]] \
  || die "backup quantd revision metadata does not match the source commit"
[[ "$metadata_web_revision" == "$source_commit" ]] \
  || die "backup web revision metadata does not match the source commit"
backup_environment_commit="$(
  read_metadata_value GIT_COMMIT "$backup_dir/.env.server.pre"
)"
[[ "$backup_environment_commit" == "$source_commit" ]] \
  || die "backup .env.server GIT_COMMIT does not match the source commit"

docker image inspect "$quantd_image_id" >/dev/null 2>&1 \
  || die "the exact rollback quantd image is no longer available locally"
docker image inspect "$web_image_id" >/dev/null 2>&1 \
  || die "the exact rollback web image is no longer available locally"
docker image inspect "$caddy_image_id" >/dev/null 2>&1 \
  || die "the exact rollback Caddy image is no longer available locally"
docker image inspect "$scheduler_image_id" >/dev/null 2>&1 \
  || die "the exact rollback scheduler image is no longer available locally"
docker image inspect "$ibkr_gateway_image_id" >/dev/null 2>&1 \
  || die "the exact rollback IBKR gateway image is no longer available locally"
rollback_quantd_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$quantd_image_id"
)"
rollback_web_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$web_image_id"
)"
[[ "$rollback_quantd_revision" == "$source_commit" ]] \
  || die "rollback quantd image revision does not match the source commit"
[[ "$rollback_web_revision" == "$source_commit" ]] \
  || die "rollback web image revision does not match the source commit"

work_dir="$(mktemp -d "$backup_parent/.rollback-work.XXXXXX")"
chmod 0700 -- "$work_dir"
write_image_model_manifest \
  "$quantd_image_id" "$work_dir/release-model-universe.sha256" \
  || die "cannot hash the rollback image model universe"
for archive_name in \
  runtime-binds.tgz quant-state.tgz quant-live.tgz \
  caddy-data.tgz caddy-config.tgz; do
  assert_safe_archive_members \
    "$backup_dir/$archive_name" "$work_dir/$archive_name.members"
done
assert_safe_runtime_archive_members \
  "$backup_dir/runtime-binds.tgz" \
  "$work_dir/runtime-binds.tgz.members" \
  "$work_dir/runtime-binds.tgz.verbose-members"
assert_safe_runtime_manifest "$backup_dir/runtime-files.sha256"

mkdir -m 0700 -- "$work_dir/runtime"
tar -xzf "$backup_dir/runtime-binds.tgz" -C "$work_dir/runtime"
runtime_tree_matches_manifest \
  "$work_dir/runtime" \
  "$backup_dir/runtime-files.sha256" \
  "$work_dir/runtime-files.release-observed.sha256" \
  || die "runtime archive does not exactly match its checksum manifest"

rollback_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
stage_prefix="axio7-rollback-stage-${rollback_stamp,,}-$$"
stage_quant_state="$stage_prefix-quant-state"
stage_quant_live="$stage_prefix-quant-live"
stage_caddy_data="$stage_prefix-caddy-data"
stage_caddy_config="$stage_prefix-caddy-config"

preflight_volume_archive() {
  local volume_name="$1"
  local archive_name="$2"

  [[ "$volume_name" == axio7-rollback-stage-* ]] \
    || die "invalid staging-volume name"
  docker volume create \
    --label "axio7.rollback.preflight=$rollback_stamp" \
    "$volume_name" >/dev/null
  staging_volumes+=("$volume_name")
  docker run --rm --user 0:0 --entrypoint /bin/sh \
    --mount "type=volume,src=$volume_name,dst=/stage" \
    --mount "type=bind,src=$backup_dir,dst=/backup,readonly" \
    "$quantd_image_id" -ec '
      mountpoint -q /stage
      test -z "$(find /stage -mindepth 1 -print -quit)"
      tar -xzf "/backup/$1" -C /stage
    ' preflight-volume "$archive_name"
}

printf 'rollback: fully extracting release archives into isolated staging\n'
preflight_volume_archive "$stage_quant_state" quant-state.tgz
preflight_volume_archive "$stage_quant_live" quant-live.tgz
preflight_volume_archive "$stage_caddy_data" caddy-data.tgz
preflight_volume_archive "$stage_caddy_config" caddy-config.tgz

env_file="$compose_dir/.env.server"
[[ -f "$env_file" ]] || die "current .env.server is missing"
[[ -f "$compose_dir/compose.yaml" ]] || die "current compose.yaml is missing"
[[ -f "$compose_dir/Caddyfile" ]] || die "current Caddyfile is missing"
for directory_name in "${RUNTIME_DIRECTORIES[@]}"; do
  [[ -d "$runtime_dir/$directory_name" \
    && ! -L "$runtime_dir/$directory_name" ]] \
    || die "current runtime directory is missing: $directory_name"
  [[ -z "$(
    find "$runtime_dir/$directory_name" -type l -print -quit
  )" ]] || die "current runtime bind directories contain a symbolic link"
done
private_attestation="$runtime_dir/private-rights-evidence/account_owner_attestation.json"
[[ "$(stat -c '%a' "$runtime_dir/private-rights-evidence")" == "700" ]] \
  || die "current private owner-attestation directory mode must be 0700"
[[ -z "$(
  find "$runtime_dir/private-rights-evidence" -mindepth 1 -maxdepth 1 \
    ! -name account_owner_attestation.json -print -quit
)" ]] || die "current private owner-attestation directory has an unexpected entry"
if [[ -e "$private_attestation" || -L "$private_attestation" ]]; then
  [[ -f "$private_attestation" \
    && ! -L "$private_attestation" \
    && "$(stat -c '%a' "$private_attestation")" == "600" \
    && "$(stat -c '%h' "$private_attestation")" == "1" ]] \
    || die "current private owner-attestation must be one mode-0600 regular file"
fi

current_commit="$(read_metadata_value GIT_COMMIT "$env_file")"
[[ "$current_commit" =~ ^[0-9a-f]{40}$ ]] \
  || die "current .env.server GIT_COMMIT is invalid"
current_compose=(
  docker compose
  --project-directory "$compose_dir"
  --env-file "$env_file"
)
env GIT_COMMIT="$current_commit" "${current_compose[@]}" config --quiet
if grep -Fq 'private-rights-evidence' "$compose_dir/compose.yaml"; then
  die "current Compose must never mount the private owner-attestation directory"
fi

current_quantd_image_id="$(
  env GIT_COMMIT="$current_commit" "${current_compose[@]}" images -q quantd \
    | awk 'NR == 1 { print; exit }'
)"
current_web_image_id="$(
  env GIT_COMMIT="$current_commit" "${current_compose[@]}" images -q web \
    | awk 'NR == 1 { print; exit }'
)"
[[ "$current_quantd_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the current quantd image ID"
[[ "$current_web_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the current web image ID"
current_caddy_image_id="$(
  env GIT_COMMIT="$current_commit" "${current_compose[@]}" images -q caddy \
    | awk 'NR == 1 { print; exit }'
)"
current_scheduler_image_id="$(
  env GIT_COMMIT="$current_commit" "${current_compose[@]}" \
    images -q monitor-scheduler | awk 'NR == 1 { print; exit }'
)"
current_ibkr_gateway_image_id="$(
  env GIT_COMMIT="$current_commit" "${current_compose[@]}" \
    images -q ibkr-gateway | awk 'NR == 1 { print; exit }'
)"
[[ "$current_caddy_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the current Caddy image ID"
[[ "$current_scheduler_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the current scheduler image ID"
[[ "$current_ibkr_gateway_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "cannot resolve the current IBKR gateway image ID"
write_image_model_manifest \
  "$current_quantd_image_id" "$work_dir/current-model-universe.sha256" \
  || die "cannot hash the current image model universe"
current_quantd_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$current_quantd_image_id"
)"
current_web_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$current_web_image_id"
)"
[[ "$current_quantd_revision" == "$current_commit" ]] \
  || die "current quantd image revision does not match .env.server"
[[ "$current_web_revision" == "$current_commit" ]] \
  || die "current web image revision does not match .env.server"

printf 'rollback: validating saved Compose, execution gates, and Caddy configuration\n'
if grep -Fq 'private-rights-evidence' "$backup_dir/compose.pre.yaml"; then
  die "saved Compose must never mount the private owner-attestation directory"
fi
env GIT_COMMIT="$source_commit" docker compose \
  --project-directory "$compose_dir" \
  --env-file "$backup_dir/.env.server.pre" \
  -f "$backup_dir/compose.pre.yaml" \
  config --quiet --no-env-resolution --no-path-resolution
for gate_name in \
  LIVE_EXECUTION_ENABLED BROKER_LIVE_ENABLED ANOMALY_LIVE_ORDER_ENABLED; do
  grep -Eq \
    "^[[:space:]]+$gate_name:[[:space:]]+[\"']?false[\"']?[[:space:]]*$" \
    "$backup_dir/compose.pre.yaml" \
    || die "saved Compose does not hard-disable $gate_name"
done
docker run --rm --network none --read-only \
  --tmpfs /data:size=16m --tmpfs /config:size=16m \
  --mount \
    "type=bind,src=$backup_dir/Caddyfile.pre,dst=/etc/caddy/Caddyfile,readonly" \
  "$caddy_image_id" \
  validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

emergency_dir="$backup_parent/pre-rollback-$rollback_stamp-${current_commit:0:12}"
[[ ! -e "$emergency_dir" ]] \
  || die "emergency backup destination already exists"
mkdir -m 0700 -- "$emergency_dir"

printf 'rollback: quiescing current production writers\n'
if ! env GIT_COMMIT="$current_commit" "${current_compose[@]}" \
  stop monitor-scheduler caddy web quantd; then
  quiesced=true
  die "failed while quiescing current production writers"
fi
quiesced=true
if ! running_services="$(
  env GIT_COMMIT="$current_commit" "${current_compose[@]}" \
    ps --status running --services
)"; then
  die "cannot verify that production writers stopped"
fi
for service_name in monitor-scheduler caddy web quantd; do
  if grep -Fxq "$service_name" <<< "$running_services"; then
    die "service is still running after quiesce: $service_name"
  fi
done

for volume_name in "${RESTORE_VOLUMES[@]}"; do
  observed_name="$(
    docker volume inspect --format '{{.Name}}' "$volume_name" 2>/dev/null
  )" || die "required restore target is missing: $volume_name"
  [[ "$observed_name" == "$volume_name" ]] \
    || die "resolved an unexpected volume while checking $volume_name"
  volume_is_detached "$volume_name" \
    || die "cannot prove the restore target is detached: $volume_name"
done

printf 'rollback: sealing the complete current deployment before overwrite\n'
install -m 0600 -- "$env_file" "$emergency_dir/.env.server.current"
install -m 0600 -- "$compose_dir/compose.yaml" \
  "$emergency_dir/compose.current.yaml"
install -m 0600 -- "$compose_dir/Caddyfile" "$emergency_dir/Caddyfile.current"
env GIT_COMMIT="$current_commit" "${current_compose[@]}" images --format json \
  > "$emergency_dir/images.current.json"

current_quantd_tag="axio7-quantd:pre-rollback-$rollback_stamp-${current_commit:0:12}"
current_web_tag="axio7-web:pre-rollback-$rollback_stamp-${current_commit:0:12}"
current_caddy_tag="axio7-caddy:pre-rollback-$rollback_stamp-${current_commit:0:12}"
current_scheduler_tag="axio7-monitor-scheduler:pre-rollback-$rollback_stamp-${current_commit:0:12}"
current_ibkr_gateway_tag="axio7-ibkr-gateway:pre-rollback-$rollback_stamp-${current_commit:0:12}"
docker image tag "$current_quantd_image_id" "$current_quantd_tag"
docker image tag "$current_web_image_id" "$current_web_tag"
docker image tag "$current_caddy_image_id" "$current_caddy_tag"
docker image tag "$current_scheduler_image_id" "$current_scheduler_tag"
docker image tag "$current_ibkr_gateway_image_id" "$current_ibkr_gateway_tag"

cat > "$emergency_dir/emergency.env" <<EOF
SOURCE_COMMIT=$current_commit
QUANTD_IMAGE_ID=$current_quantd_image_id
WEB_IMAGE_ID=$current_web_image_id
CADDY_IMAGE_ID=$current_caddy_image_id
SCHEDULER_IMAGE_ID=$current_scheduler_image_id
IBKR_GATEWAY_IMAGE_ID=$current_ibkr_gateway_image_id
QUANTD_IMAGE_REVISION=$current_quantd_revision
WEB_IMAGE_REVISION=$current_web_revision
QUANTD_RECOVERY_TAG=$current_quantd_tag
WEB_RECOVERY_TAG=$current_web_tag
CADDY_RECOVERY_TAG=$current_caddy_tag
SCHEDULER_RECOVERY_TAG=$current_scheduler_tag
IBKR_GATEWAY_RECOVERY_TAG=$current_ibkr_gateway_tag
EOF

archive_current_volume \
  axio7_quant-state quant-state.before-rollback.tgz \
  "$emergency_dir" "$current_quantd_image_id"
archive_current_volume \
  axio7_quant-live quant-live.before-rollback.tgz \
  "$emergency_dir" "$current_quantd_image_id"
archive_current_volume \
  axio7_caddy-data caddy-data.before-rollback.tgz \
  "$emergency_dir" "$current_quantd_image_id"
archive_current_volume \
  axio7_caddy-config caddy-config.before-rollback.tgz \
  "$emergency_dir" "$current_quantd_image_id"

(
  cd -- "$runtime_dir"
  find "${RUNTIME_DIRECTORIES[@]}" -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 -r sha256sum
) > "$emergency_dir/runtime-files.before-rollback.sha256"
[[ -s "$emergency_dir/runtime-files.before-rollback.sha256" ]] \
  || die "current runtime bind directories contain no recoverable files"
runtime_tree_matches_manifest \
  "$runtime_dir" \
  "$emergency_dir/runtime-files.before-rollback.sha256" \
  "$work_dir/runtime-files.current-source-observed.sha256" \
  || die "current runtime tree changed while its manifest was created"
tar -C "$runtime_dir" \
  -czf "$emergency_dir/runtime-binds.before-rollback.tgz" \
  "${RUNTIME_DIRECTORIES[@]}"

cat > "$emergency_dir/emergency-manifest.json" <<EOF
{
  "schema_version": "axio.production-emergency-backup.v1",
  "created_at": "$rollback_stamp",
  "source_commit": "$current_commit",
  "quantd_image_id": "$current_quantd_image_id",
  "web_image_id": "$current_web_image_id",
  "caddy_image_id": "$current_caddy_image_id",
  "scheduler_image_id": "$current_scheduler_image_id",
  "ibkr_gateway_image_id": "$current_ibkr_gateway_image_id",
  "quantd_image_revision": "$current_quantd_revision",
  "web_image_revision": "$current_web_revision",
  "state_live_runtime_caddy_config_captured_as_one_set": true,
  "services_left_stopped": true,
  "execution_enabled": false
}
EOF
(
  cd -- "$emergency_dir"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%P\0' \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum
) > "$emergency_dir/SHA256SUMS"
(
  cd -- "$emergency_dir"
  sha256sum --check --strict SHA256SUMS
)
for archive_name in \
  runtime-binds.before-rollback.tgz \
  quant-state.before-rollback.tgz quant-live.before-rollback.tgz \
  caddy-data.before-rollback.tgz caddy-config.before-rollback.tgz; do
  assert_safe_archive_members \
    "$emergency_dir/$archive_name" \
    "$work_dir/$archive_name.members"
done
assert_safe_runtime_archive_members \
  "$emergency_dir/runtime-binds.before-rollback.tgz" \
  "$work_dir/runtime-binds.before-rollback.tgz.members" \
  "$work_dir/runtime-binds.before-rollback.tgz.verbose-members"
mkdir -m 0700 -- "$work_dir/emergency-runtime"
tar -xzf "$emergency_dir/runtime-binds.before-rollback.tgz" \
  -C "$work_dir/emergency-runtime"
runtime_tree_matches_manifest \
  "$work_dir/emergency-runtime" \
  "$emergency_dir/runtime-files.before-rollback.sha256" \
  "$work_dir/runtime-files.emergency-observed.sha256" \
  || die "emergency runtime archive does not exactly match its checksum manifest"
emergency_sealed=true
destructive_started=true

printf 'rollback: restoring the preflighted persistent volume set\n'
restore_volume_from_staging \
  axio7_quant-state "$stage_quant_state" "$quantd_image_id" \
  || die "failed to restore axio7_quant-state"
restore_volume_from_staging \
  axio7_quant-live "$stage_quant_live" "$quantd_image_id" \
  || die "failed to restore axio7_quant-live"
restore_volume_from_staging \
  axio7_caddy-data "$stage_caddy_data" "$quantd_image_id" \
  || die "failed to restore axio7_caddy-data"
restore_volume_from_staging \
  axio7_caddy-config "$stage_caddy_config" "$quantd_image_id" \
  || die "failed to restore axio7_caddy-config"

displaced_dir="$runtime_dir/displaced-$rollback_stamp-${current_commit:0:12}"
[[ "$displaced_dir" == "$runtime_dir"/displaced-* ]] \
  || die "unsafe displaced-runtime path"
[[ ! -e "$displaced_dir" ]] || die "displaced-runtime path already exists"
mkdir -m 0700 -- "$displaced_dir"
for directory_name in "${RUNTIME_DIRECTORIES[@]}"; do
  mv -- "$runtime_dir/$directory_name" "$displaced_dir/$directory_name"
  mv -- "$work_dir/runtime/$directory_name" "$runtime_dir/$directory_name"
done
runtime_tree_matches_manifest \
  "$runtime_dir" \
  "$backup_dir/runtime-files.sha256" \
  "$work_dir/runtime-files.restored-observed.sha256" \
  || die "restored runtime tree does not exactly match its checksum manifest"

install -m 0600 -- "$backup_dir/.env.server.pre" "$env_file"
install -m 0644 -- "$backup_dir/compose.pre.yaml" "$compose_dir/compose.yaml"
install -m 0644 -- "$backup_dir/Caddyfile.pre" "$compose_dir/Caddyfile"

docker image tag "$quantd_image_id" axio7-quantd:latest
docker image tag "$web_image_id" axio7-web:latest
docker image tag "$quantd_image_id" "axio7-quantd:$source_commit"
docker image tag "$web_image_id" "axio7-web:$source_commit"
docker image tag "$quantd_image_id" "$quantd_rollback_tag"
docker image tag "$web_image_id" "$web_rollback_tag"
docker image tag "$caddy_image_id" caddy:2.10-alpine
docker image tag "$scheduler_image_id" curlimages/curl:8.14.1
docker image tag "$ibkr_gateway_image_id" axio7-ibkr-gateway:latest
docker image tag "$caddy_image_id" "$caddy_rollback_tag"
docker image tag "$scheduler_image_id" "$scheduler_rollback_tag"
docker image tag "$ibkr_gateway_image_id" "$ibkr_gateway_rollback_tag"

restored_compose=(
  docker compose
  --project-directory "$compose_dir"
  --env-file "$env_file"
)
env GIT_COMMIT="$source_commit" "${restored_compose[@]}" config --quiet
env GIT_COMMIT="$source_commit" "${restored_compose[@]}" \
  up -d --no-build --pull never --force-recreate --wait --wait-timeout 180

for service_name in quantd web; do
  container_id="$(
    env GIT_COMMIT="$source_commit" "${restored_compose[@]}" \
      ps -q "$service_name"
  )"
  [[ -n "$container_id" ]] || die "restored $service_name container did not start"
  health_status="$(
    docker inspect --format \
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
      "$container_id"
  )"
  [[ "$health_status" == "healthy" ]] \
    || die "restored $service_name liveness healthcheck is not healthy"
done

env GIT_COMMIT="$source_commit" "${restored_compose[@]}" \
  exec -T quantd sh -ec '
    root=/app/data/models/universe
    test -d "$root"
    test -z "$(find "$root" ! -type d ! -type f -print -quit)"
    test -z "$(find "$root" -type f -links +1 -print -quit)"
    find "$root" -type f -print0 \
      | LC_ALL=C sort -z | xargs -0 -r sha256sum
  ' > "$work_dir/release-model-universe.restored.sha256"
cmp --silent \
  "$work_dir/release-model-universe.sha256" \
  "$work_dir/release-model-universe.restored.sha256" \
  || die "restored read-only model universe differs from the rollback image"

restored_running_services="$(
  env GIT_COMMIT="$source_commit" "${restored_compose[@]}" \
    ps --status running --services
)"
for service_name in quantd web caddy monitor-scheduler ibkr-gateway; do
  grep -Fxq "$service_name" <<< "$restored_running_services" \
    || die "restored service is not running: $service_name"
done

restored_quantd_image="$(
  env GIT_COMMIT="$source_commit" "${restored_compose[@]}" images -q quantd \
    | awk 'NR == 1 { print; exit }'
)"
restored_web_image="$(
  env GIT_COMMIT="$source_commit" "${restored_compose[@]}" images -q web \
    | awk 'NR == 1 { print; exit }'
)"
restored_caddy_image="$(
  env GIT_COMMIT="$source_commit" "${restored_compose[@]}" images -q caddy \
    | awk 'NR == 1 { print; exit }'
)"
restored_scheduler_image="$(
  env GIT_COMMIT="$source_commit" "${restored_compose[@]}" \
    images -q monitor-scheduler | awk 'NR == 1 { print; exit }'
)"
restored_ibkr_gateway_image="$(
  env GIT_COMMIT="$source_commit" "${restored_compose[@]}" \
    images -q ibkr-gateway | awk 'NR == 1 { print; exit }'
)"
[[ "$restored_quantd_image" == "$quantd_image_id" ]] \
  || die "running quantd image does not match the rollback receipt"
[[ "$restored_web_image" == "$web_image_id" ]] \
  || die "running web image does not match the rollback receipt"
[[ "$restored_caddy_image" == "$caddy_image_id" ]] \
  || die "running Caddy image does not match the rollback receipt"
[[ "$restored_scheduler_image" == "$scheduler_image_id" ]] \
  || die "running scheduler image does not match the rollback receipt"
[[ "$restored_ibkr_gateway_image" == "$ibkr_gateway_image_id" ]] \
  || die "running IBKR gateway image does not match the rollback receipt"

rollback_succeeded=true
destructive_started=false
quiesced=false
cat > "$emergency_dir/rollback-receipt.json" <<EOF
{
  "schema_version": "axio.production-rollback.v1",
  "restored_at": "$rollback_stamp",
  "source_commit": "$source_commit",
  "quantd_image_id": "$quantd_image_id",
  "web_image_id": "$web_image_id",
  "caddy_image_id": "$caddy_image_id",
  "scheduler_image_id": "$scheduler_image_id",
  "ibkr_gateway_image_id": "$ibkr_gateway_image_id",
  "release_archives_fully_preflighted_before_quiesce": true,
  "emergency_state_sealed_before_overwrite": true,
  "state_and_wal_restored_as_one_set": true,
  "runtime_binds_restored_as_one_set": true,
  "read_only_model_universe_matches_image": true,
  "all_service_image_ids_verified": true,
  "quantd_liveness_healthcheck": "healthy",
  "web_liveness_healthcheck": "healthy",
  "caddy_running": true,
  "monitor_scheduler_running": true,
  "execution_enabled": false
}
EOF
sha256sum "$emergency_dir/rollback-receipt.json" \
  > "$emergency_dir/rollback-receipt.sha256"

printf 'rollback: restored release commit %s\n' "$source_commit"
printf 'rollback: emergency pre-rollback bundle: %s\n' "$emergency_dir"
printf 'rollback: displaced runtime bind directories: %s\n' "$displaced_dir"
printf 'rollback: production publication may remain blocked until a fresh regular-session receipt is generated\n'
