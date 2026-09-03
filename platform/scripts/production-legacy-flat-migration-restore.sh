#!/usr/bin/env bash
#
# Restore only a checksum-sealed bundle produced by
# production-legacy-flat-migration-backup.sh. This is not a general rollback
# path and must never be used after entering the canonical checkout layout.

set -euo pipefail
umask 077

readonly EXPECTED_DEPLOYMENT_DIR="/opt/axio7"
readonly REQUIRED_VOLUMES=(
  axio7_quant-state
  axio7_quant-live
  axio7_caddy-data
  axio7_caddy-config
)
readonly EXPECTED_SERVICES=(
  caddy
  monitor-scheduler
  quantd
  web
)
declare -A RESTORED_CONTAINER_IDS=()

die() {
  printf 'legacy-restore: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  production-legacy-flat-migration-restore.sh \
    --deployment-dir /opt/axio7 \
    --backup-dir /opt/axio7-legacy-migration-backups/legacy-flat-TIMESTAMP \
    --confirm-legacy-restore

The command accepts only an axio.legacy-flat-migration-backup.v1 bundle,
preflights every checksum, image, configuration, archive member, extracted
volume, and runtime file before changing state, and requires every axio7
project container to be stopped. It makes a separate emergency snapshot of
the current fixed volumes and /opt/axio7 files, restores the exact legacy
images/data/configuration, and starts with --no-build --pull never.

It never deletes or prunes an image, named volume, backup, Paddle resource, or
secret. A failed restore leaves all writers stopped and preserves emergency
and preflight material for manual recovery.
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

runtime_directory_is_allowed() {
  case "$1" in
    market-data|releases|quant-raw|quant-normalized|quant-manifests|quant-rights|quant-evidence|private-rights-evidence|quant-promotion|quant-calibration)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

paths_overlap() {
  local left="$1"
  local right="$2"

  case "$left/" in
    "$right/"*)
      return 0
      ;;
  esac
  case "$right/" in
    "$left/"*)
      return 0
      ;;
  esac
  return 1
}

flat_compose_has_exact_web_env_file() {
  local compose_path="$1"
  local observed=""

  observed="$(
    awk '
      /^  web:[[:space:]]*$/ {
        in_web = 1
        next
      }
      in_web && /^  [^[:space:]][^:]*:/ {
        exit
      }
      in_web && /^    env_file:[[:space:]]*$/ {
        in_env_file = 1
        next
      }
      in_env_file && /^      -[[:space:]]*/ {
        value = $0
        sub(/^      -[[:space:]]*/, "", value)
        sub(/\r$/, "", value)
        print value
        next
      }
      in_env_file && /^    [^[:space:]][^:]*:/ {
        in_env_file = 0
      }
    ' "$compose_path"
  )"
  [[ "$observed" == ".env.server" ]]
}

acquire_legacy_lock() {
  local lock_dir="/run/lock/axio7-legacy-migration"
  local lock_file="$lock_dir/operation.lock"
  local operator_uid=""
  local opened_identity=""
  local path_identity=""

  operator_uid="$(id -u)"
  if [[ -e "$lock_dir" || -L "$lock_dir" ]]; then
    [[ -d "$lock_dir" && ! -L "$lock_dir" ]] \
      || die "legacy lock directory is not a real directory"
  else
    mkdir -m 0700 -- "$lock_dir"
  fi
  [[ "$(stat -c '%a' "$lock_dir")" == "700" \
    && "$(stat -c '%u' "$lock_dir")" == "$operator_uid" ]] \
    || die "legacy lock directory must be mode 0700 and operator-owned"

  if [[ -e "$lock_file" || -L "$lock_file" ]]; then
    [[ -f "$lock_file" && ! -L "$lock_file" \
      && "$(stat -c '%a' "$lock_file")" == "600" \
      && "$(stat -c '%u' "$lock_file")" == "$operator_uid" \
      && "$(stat -c '%h' "$lock_file")" == "1" ]] \
      || die "legacy lock file is not a safe operator-owned regular file"
  else
    install -m 0600 -- /dev/null "$lock_file"
  fi

  exec 9<> "$lock_file"
  opened_identity="$(stat -Lc '%d:%i' "/proc/$$/fd/9")"
  path_identity="$(stat -c '%d:%i' "$lock_file")"
  [[ "$opened_identity" == "$path_identity" \
    && "$(stat -c '%h' "$lock_file")" == "1" ]] \
    || die "legacy lock path changed while it was opened"
  flock -n 9 \
    || die "another AXIO7 migration operation holds the legacy lock"
}

tree_has_control_characters() {
  local tree_root="$1"

  find "$tree_root" -mindepth 1 -print0 \
    | LC_ALL=C grep -z '[[:cntrl:]]' >/dev/null
}

validate_legacy_compose_model() {
  local model_dir="$1"
  local web_image="$2"

  docker run --rm --pull never --user 0:0 --network none --read-only \
    --tmpfs /tmp:size=8m \
    --entrypoint node \
    --mount "type=bind,src=$model_dir,dst=/input,readonly" \
    "$web_image" -e '
      const fs = require("fs");
      const fail = () => process.exit(41);
      let model;
      try {
        model = JSON.parse(fs.readFileSync("/input/compose.json", "utf8"));
      } catch {
        fail();
      }
      const services = [
        "caddy", "monitor-scheduler", "quantd", "web",
      ];
      const volumeNames = {
        "caddy-config": "axio7_caddy-config",
        "caddy-data": "axio7_caddy-data",
        "quant-live": "axio7_quant-live",
        "quant-state": "axio7_quant-state",
      };
      const sortedKeys = (value) => Object.keys(value || {}).sort();
      const same = (left, right) =>
        JSON.stringify(left) === JSON.stringify(right);
      const releaseMount = /^\/opt\/axio7\/runtime\/releases\/([0-9a-f]{7})\/(quant-(?:raw|normalized|evidence|manifests|rights))$/;
      const normalizedMounts = (service) => (service.volumes || []).map((mount) => {
        const source = String(mount.source || "");
        const match = source.match(releaseMount);
        return [
          mount.type || "",
          match
            ? `/opt/axio7/runtime/releases/<release>/${match[2]}`
            : source,
          mount.target || "",
          String(mount.read_only === true),
        ].join("|");
      }).sort();
      const releaseIds = (service) => (service.volumes || [])
        .map((mount) => String(mount.source || "").match(releaseMount))
        .filter(Boolean)
        .map((match) => match[1]);
      if (model.name !== "axio7"
          || !same(sortedKeys(model.services), services)
          || !same(sortedKeys(model.volumes), sortedKeys(volumeNames))) {
        fail();
      }
      for (const [key, exactName] of Object.entries(volumeNames)) {
        const volume = model.volumes[key] || {};
        if (volume.name !== exactName
            || (volume.external !== undefined && volume.external !== false)) {
          fail();
        }
      }
      const expectedMounts = {
        caddy: [
          "bind|/opt/axio7/Caddyfile|/etc/caddy/Caddyfile|true",
          "volume|caddy-config|/config|false",
          "volume|caddy-data|/data|false",
        ],
        "monitor-scheduler": [],
        quantd: [
          "bind|/opt/axio7/runtime/market-data|/app/data/market|false",
          "bind|/opt/axio7/runtime/quant-calibration|/app/data/calibration|true",
          "bind|/opt/axio7/runtime/quant-promotion|/app/data/promotion|true",
          "bind|/opt/axio7/runtime/releases/<release>/quant-evidence|/app/data/evidence|true",
          "bind|/opt/axio7/runtime/releases/<release>/quant-manifests|/app/data/manifests|true",
          "bind|/opt/axio7/runtime/releases/<release>/quant-normalized|/app/data/normalized|true",
          "bind|/opt/axio7/runtime/releases/<release>/quant-raw|/app/data/raw|true",
          "bind|/opt/axio7/runtime/releases/<release>/quant-rights|/app/data/rights|true",
          "volume|quant-live|/app/data/live|false",
          "volume|quant-state|/app/data/state|false",
        ],
        web: [],
      };
      for (const serviceName of services) {
        const service = model.services[serviceName] || {};
        const mounts = normalizedMounts(service);
        const modelReleaseIds = releaseIds(service);
        const envFileEntries = service.env_file || [];
        const envFilePaths = envFileEntries.map((entry) =>
          typeof entry === "string" ? entry : entry?.path,
        );
        const expectedEnvFiles = serviceName === "web"
          ? ["/opt/axio7/.env.server"]
          : [];
        let imageReference;
        try {
          imageReference = fs.readFileSync(
            `/input/${serviceName}.image-reference`,
            "utf8",
          ).trim();
        } catch {
          fail();
        }
        const resolvedImageReference =
          service.image ?? `${model.name}-${serviceName}`;
        if ((serviceName === "quantd"
              && (modelReleaseIds.length !== 5
                || new Set(modelReleaseIds).size !== 1))
            || !same(mounts, expectedMounts[serviceName].slice().sort())
            || !same(envFilePaths, expectedEnvFiles)
            || envFileEntries.some((entry) =>
              typeof entry !== "object"
                || entry === null
                || (entry.required !== undefined && entry.required !== true)
                || entry.format !== undefined
            )
            || resolvedImageReference !== imageReference
            || (service.scale !== undefined && service.scale !== 1)
            || (service.deploy?.replicas !== undefined
                && service.deploy.replicas !== 1)
            || (service.pre_start && service.pre_start.length)
            || (service.post_start && service.post_start.length)) {
          fail();
        }
      }
      const web = model.services.web || {};
      if (web.network_mode !== "service:quantd"
          || web.environment?.LIVE_EXECUTION_ENABLED !== "false"
          || web.environment?.BROKER_LIVE_ENABLED !== "false"
          || web.environment?.ANOMALY_LIVE_ORDER_ENABLED !== "false") {
        fail();
      }
    ' >/dev/null 2>&1
}

validate_sealed_env_file() {
  local staged_dir="$1"

  printf '%s\n' \
    'services:' \
    '  env-check:' \
    '    image: scratch' \
    '    env_file:' \
    '      - .env.server.legacy' \
    | docker compose \
      --project-name axio7-legacy-env-check \
      --project-directory "$staged_dir" \
      --env-file "$staged_dir/.env.server.legacy" \
      -f - config --quiet >/dev/null 2>&1
}

archive_member_path_is_safe() {
  local member="$1"
  local normalized="${member#./}"
  local component=""
  local -a components=()

  [[ "$member" != /* ]] || return 1
  [[ -z "$normalized" || "$normalized" == "." ]] && return 0
  IFS='/' read -r -a components <<< "$normalized"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" != "." && "$component" != ".." ]] \
      || return 1
  done
}

assert_safe_archive() {
  local archive_path="$1"
  local name_listing="$2"
  local verbose_listing="$3"
  local member=""
  local verbose_line=""
  local member_type=""

  tar -tzf "$archive_path" > "$name_listing" \
    || die "cannot list archive: $(basename -- "$archive_path")"
  [[ -s "$name_listing" ]] \
    || die "archive is empty: $(basename -- "$archive_path")"
  while IFS= read -r member || [[ -n "$member" ]]; do
    archive_member_path_is_safe "$member" \
      || die "archive has an unsafe member path: $(basename -- "$archive_path")"
  done < "$name_listing"

  tar -tvzf "$archive_path" > "$verbose_listing" \
    || die "cannot inspect archive member types: $(basename -- "$archive_path")"
  while IFS= read -r verbose_line || [[ -n "$verbose_line" ]]; do
    [[ -n "$verbose_line" ]] || continue
    member_type="${verbose_line:0:1}"
    case "$member_type" in
      -|d)
        ;;
      *)
        die "archive contains a link or special member: $(basename -- "$archive_path")"
        ;;
    esac
  done < "$verbose_listing"
}

assert_safe_runtime_archive() {
  local listing_path="$1"
  local member=""
  local normalized=""
  local top_level=""

  while IFS= read -r member || [[ -n "$member" ]]; do
    normalized="${member#./}"
    [[ -z "$normalized" || "$normalized" == "." ]] && continue
    top_level="${normalized%%/*}"
    runtime_directory_is_allowed "$top_level" \
      || die "runtime archive has an unapproved top-level member"
  done < "$listing_path"
}

runtime_tree_matches_manifest() {
  local tree_root="$1"
  local expected_manifest="$2"
  local observed_manifest="$3"
  local expected_directories="$4"
  local entry=""
  local name=""
  local unexpected=""
  local private_dir=""
  local private_file=""

  tree_has_control_characters "$tree_root" && return 1
  while IFS= read -r name || [[ -n "$name" ]]; do
    [[ -n "$name" ]] || continue
    runtime_directory_is_allowed "$name" || return 1
    [[ -d "$tree_root/$name" && ! -L "$tree_root/$name" ]] || return 1
  done < "$expected_directories"
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -n "$entry" ]] || continue
    name="$(basename -- "$entry")"
    runtime_directory_is_allowed "$name" || return 1
    grep -Fxq "$name" "$expected_directories" || return 1
    [[ -d "$entry" && ! -L "$entry" ]] || return 1
  done < <(find "$tree_root" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort)
  if grep -Fxq private-rights-evidence "$expected_directories"; then
    private_dir="$tree_root/private-rights-evidence"
    private_file="$private_dir/account_owner_attestation.json"
    [[ "$(stat -c '%a' "$private_dir")" == "700" ]] || return 1
    [[ -z "$(
      find "$private_dir" -mindepth 1 -maxdepth 1 \
        ! -name account_owner_attestation.json -print -quit
    )" ]] || return 1
    if [[ -e "$private_file" || -L "$private_file" ]]; then
      [[ -f "$private_file" \
        && ! -L "$private_file" \
        && "$(stat -c '%a' "$private_file")" == "600" \
        && "$(stat -c '%h' "$private_file")" == "1" ]] || return 1
    fi
  fi
  unexpected="$(
    find "$tree_root" -mindepth 1 ! -type d ! -type f -print -quit
  )" || return 1
  [[ -z "$unexpected" ]] || return 1
  unexpected="$(
    find "$tree_root" -type f -links +1 -print -quit
  )" || return 1
  [[ -z "$unexpected" ]] || return 1
  (
    cd -- "$tree_root"
    find . -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 -r sha256sum
  ) > "$observed_manifest" || return 1
  cmp --silent "$expected_manifest" "$observed_manifest"
}

staged_tree_matches_manifests() {
  local tree_root="$1"
  local expected_files="$2"
  local expected_directories="$3"
  local output_prefix="$4"
  local observed_files="$work_dir/$output_prefix.files.sha256"
  local observed_directories="$work_dir/$output_prefix.directories.txt"
  local unexpected=""

  [[ -d "$tree_root" && ! -L "$tree_root" ]] || return 1
  tree_has_control_characters "$tree_root" && return 1
  unexpected="$(
    find "$tree_root" -mindepth 1 ! -type d ! -type f -print -quit
  )" || return 1
  [[ -z "$unexpected" ]] || return 1
  unexpected="$(find "$tree_root" -type f -links +1 -print -quit)" \
    || return 1
  [[ -z "$unexpected" ]] || return 1
  (
    cd -- "$tree_root"
    find . -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 -r sha256sum
  ) > "$observed_files" || return 1
  (
    cd -- "$tree_root"
    find . -type d -print | LC_ALL=C sort
  ) > "$observed_directories" || return 1
  cmp --silent "$expected_files" "$observed_files" \
    && cmp --silent "$expected_directories" "$observed_directories"
}

write_volume_manifest() {
  local volume_name="$1"
  local output_path="$2"

  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    "$quantd_image_id" -ec '
      mountpoint -q /source
      cd /source
      if find . -mindepth 1 -print0 \
        | LC_ALL=C grep -z "[[:cntrl:]]" >/dev/null; then
        exit 1
      fi
      test -z "$(find . -mindepth 1 ! -type d ! -type f -print -quit)"
      test -z "$(find . -type f -links +1 -print -quit)"
      find . -type f -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 -r sha256sum
    ' > "$output_path"
}

write_volume_directories() {
  local volume_name="$1"
  local output_path="$2"

  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    "$quantd_image_id" -ec '
      mountpoint -q /source
      cd /source
      find . -type d -print | LC_ALL=C sort
    ' > "$output_path"
}

preflight_volume_archive() {
  local archive_name="$1"
  local manifest_name="$2"
  local directories_name="$3"
  local target_dir="$work_dir/${archive_name%.tgz}"
  local observed_manifest="$work_dir/$manifest_name.observed"
  local observed_directories="$work_dir/$directories_name.observed"

  mkdir -m 0700 -- "$target_dir"
  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
    --mount "type=bind,src=$backup_dir,dst=/backup,readonly" \
    --mount "type=bind,src=$target_dir,dst=/target" \
    "$quantd_image_id" -ec '
      mountpoint -q /target
      test -z "$(find /target -mindepth 1 -print -quit)"
      tar -xzf "/backup/$1" -C /target
      cd /target
      if find . -mindepth 1 -print0 \
        | LC_ALL=C grep -z "[[:cntrl:]]" >/dev/null; then
        exit 1
      fi
      test -z "$(find . -mindepth 1 ! -type d ! -type f -print -quit)"
      test -z "$(find . -type f -links +1 -print -quit)"
      find . -type f -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 -r sha256sum
    ' preflight "$archive_name" > "$observed_manifest"
  (
    cd -- "$target_dir"
    find . -type d -print | LC_ALL=C sort
  ) > "$observed_directories"
  cmp --silent "$sealed_dir/$manifest_name" "$observed_manifest" \
    || die "extracted archive differs from its sealed manifest: $archive_name"
  cmp --silent "$sealed_dir/$directories_name" "$observed_directories" \
    || die "extracted archive omits or adds a directory: $archive_name"
}

volume_is_detached() {
  local volume_name="$1"
  local running_ids=""

  running_ids="$(docker ps -q --filter "volume=$volume_name")" || return 1
  [[ -z "$running_ids" ]]
}

archive_current_volume() {
  local volume_name="$1"
  local archive_name="$2"

  volume_is_detached "$volume_name" || return 1
  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/tar \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    --mount "type=bind,src=$emergency_dir,dst=/backup" \
    "$quantd_image_id" -C /source -czf "/backup/$archive_name" .
}

restore_volume_from_stage() {
  local volume_name="$1"
  local stage_name="$2"
  local expected_manifest="$3"
  local expected_directories="$4"
  local observed_name=""
  local source_dir="$work_dir/$stage_name"

  case "$volume_name:$stage_name" in
    axio7_quant-state:quant-state|\
    axio7_quant-live:quant-live|\
    axio7_caddy-data:caddy-data|\
    axio7_caddy-config:caddy-config)
      ;;
    *)
      return 1
      ;;
  esac
  observed_name="$(
    docker volume inspect --format '{{.Name}}' "$volume_name" 2>/dev/null
  )" || return 1
  [[ "$observed_name" == "$volume_name" ]] || return 1
  volume_is_detached "$volume_name" || return 1
  [[ -d "$source_dir" && ! -L "$source_dir" ]] || return 1

  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/bash \
    --mount "type=volume,src=$volume_name,dst=/target" \
    --mount "type=bind,src=$source_dir,dst=/source,readonly" \
    "$quantd_image_id" -o pipefail -ec '
      mountpoint -q /source
      mountpoint -q /target
      find /target -mindepth 1 -depth -delete
      test -z "$(find /target -mindepth 1 -print -quit)"
      tar -C /source -cpf - . | tar -C /target -xpf -
    ' || return 1
  write_volume_manifest \
    "$volume_name" "$work_dir/$expected_manifest.restored" || return 1
  write_volume_directories \
    "$volume_name" "$work_dir/$expected_directories.restored" || return 1
  cmp --silent \
    "$sealed_dir/$expected_manifest" \
    "$work_dir/$expected_manifest.restored" \
    && cmp --silent \
      "$sealed_dir/$expected_directories" \
      "$work_dir/$expected_directories.restored"
}

bundle_file_is_allowed() {
  case "$1" in
    .env.server.legacy|\
    Caddyfile.legacy|\
    RECOVERY.txt|\
    backup-manifest.json|\
    caddy-config-directories.txt|\
    caddy-config-files.sha256|\
    caddy-config.tgz|\
    caddy-data-directories.txt|\
    caddy-data-files.sha256|\
    caddy-data.tgz|\
    compose.legacy.yaml|\
    legacy.env|\
    quant-live-directories.txt|\
    quant-live-files.sha256|\
    quant-live.tgz|\
    quant-state-directories.txt|\
    quant-state-files.sha256|\
    quant-state-sqlite-family-files.txt|\
    quant-state.tgz|\
    restore-legacy-flat.sh|\
    runtime-binds.tgz|\
    runtime-directories.txt|\
    runtime-files.sha256|\
    runtime-tree-directories.txt)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_checksum_manifest() {
  local line=""
  local filename=""
  local count=0
  local seen_file="$work_dir/checksum-files.txt"
  local bundle_entry=""
  local bundle_name=""

  : > "$seen_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[0-9a-f]{64}[[:space:]][\ \*]([^/]+)$ ]] \
      || die "SHA256SUMS contains an invalid line"
    filename="${BASH_REMATCH[1]}"
    bundle_file_is_allowed "$filename" \
      || die "SHA256SUMS contains an unapproved file"
    grep -Fxq "$filename" "$seen_file" \
      && die "SHA256SUMS contains a duplicate file"
    printf '%s\n' "$filename" >> "$seen_file"
    ((count += 1))
  done < "$backup_dir/SHA256SUMS"
  ((count == 24)) || die "SHA256SUMS does not cover the exact legacy bundle"
  while IFS= read -r filename || [[ -n "$filename" ]]; do
    [[ -n "$filename" ]] || continue
    grep -Fxq "$filename" "$seen_file" \
      || die "SHA256SUMS omits a required legacy bundle file"
  done < <(
    printf '%s\n' \
      .env.server.legacy Caddyfile.legacy RECOVERY.txt \
      backup-manifest.json caddy-config-directories.txt \
      caddy-config-files.sha256 caddy-config.tgz caddy-data-directories.txt \
      caddy-data-files.sha256 caddy-data.tgz compose.legacy.yaml legacy.env \
      quant-live-directories.txt quant-live-files.sha256 quant-live.tgz \
      quant-state-directories.txt quant-state-files.sha256 \
      quant-state-sqlite-family-files.txt quant-state.tgz \
      restore-legacy-flat.sh runtime-binds.tgz runtime-directories.txt \
      runtime-files.sha256 runtime-tree-directories.txt \
      | LC_ALL=C sort
  )
  while IFS= read -r bundle_entry || [[ -n "$bundle_entry" ]]; do
    [[ -n "$bundle_entry" ]] || continue
    bundle_name="$(basename -- "$bundle_entry")"
    [[ -f "$bundle_entry" && ! -L "$bundle_entry" ]] \
      || die "legacy bundle contains a non-regular top-level entry"
    if [[ "$bundle_name" == "SHA256SUMS" ]]; then
      continue
    fi
    bundle_file_is_allowed "$bundle_name" \
      || die "legacy bundle contains an unexpected top-level file"
    grep -Fxq "$bundle_name" "$seen_file" \
      || die "legacy bundle contains an unhashed top-level file"
  done < <(find "$backup_dir" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort)
}

file_matches_staged_checksum() {
  local file_path="$1"
  local bundle_name="$2"
  local expected_hash=""
  local observed_hash=""

  expected_hash="$(
    awk -v wanted="$bundle_name" '
      $2 == wanted {
        print $1
        count += 1
      }
      END {
        if (count != 1) exit 1
      }
    ' "$sealed_dir/SHA256SUMS"
  )" || return 1
  [[ "$expected_hash" =~ ^[0-9a-f]{64}$ ]] || return 1
  observed_hash="$(sha256sum "$file_path" | awk '{print $1}')" || return 1
  [[ "$observed_hash" == "$expected_hash" ]]
}

stop_all_axio7_writers() {
  local container_ids=""
  local container_id=""
  local volume_name=""
  local operation_failed=false

  container_ids="$(
    docker ps -q --filter label=com.docker.compose.project=axio7
  )" || return 1
  while IFS= read -r container_id || [[ -n "$container_id" ]]; do
    [[ -z "$container_id" ]] && continue
    [[ "$container_id" =~ ^[0-9a-f]{12,64}$ ]] || {
      operation_failed=true
      continue
    }
    docker stop --time 60 "$container_id" >/dev/null || operation_failed=true
  done <<< "$container_ids"

  for volume_name in "${REQUIRED_VOLUMES[@]}"; do
    container_ids="$(docker ps -q --filter "volume=$volume_name")" || {
      operation_failed=true
      continue
    }
    while IFS= read -r container_id || [[ -n "$container_id" ]]; do
      [[ -z "$container_id" ]] && continue
      [[ "$container_id" =~ ^[0-9a-f]{12,64}$ ]] || {
        operation_failed=true
        continue
      }
      docker stop --time 60 "$container_id" >/dev/null || operation_failed=true
    done <<< "$container_ids"
  done
  $operation_failed && return 1

  container_ids="$(
    docker ps -q --filter label=com.docker.compose.project=axio7
  )" || return 1
  [[ -z "$container_ids" ]] || return 1
  for volume_name in "${REQUIRED_VOLUMES[@]}"; do
    container_ids="$(docker ps -q --filter "volume=$volume_name")" || return 1
    [[ -z "$container_ids" ]] || return 1
  done
}

root_bashpid="$BASHPID"
work_dir=""
sealed_dir=""
emergency_dir=""
destructive_started=false
restore_succeeded=false

cleanup() {
  local status=$?

  [[ "$BASHPID" == "$root_bashpid" ]] || return "$status"
  trap - EXIT INT TERM HUP
  set +e +u
  if $destructive_started && ! $restore_succeeded; then
    if stop_all_axio7_writers; then
      printf 'legacy-restore: restore failed after replacement began; all AXIO7 writers are stopped\n' >&2
    else
      printf 'legacy-restore: CRITICAL: restore failed and stopped AXIO7 state cannot be proven\n' >&2
    fi
    printf 'legacy-restore: current-state emergency snapshot: %s\n' \
      "$emergency_dir" >&2
    printf 'legacy-restore: preflight material retained at: %s\n' \
      "$work_dir" >&2
  elif [[ -n "$work_dir" \
    && -n "${backup_parent:-}" \
    && "$work_dir" == "$backup_parent"/.legacy-restore-work.* \
    && "$work_dir" != "/" ]]; then
    rm -rf -- "$work_dir"
  fi
  exit "$status"
}
trap cleanup EXIT

on_signal() {
  local status="$1"
  local signal_name="$2"
  printf 'legacy-restore: received %s; entering fail-closed cleanup\n' \
    "$signal_name" >&2
  exit "$status"
}
trap 'on_signal 130 INT' INT
trap 'on_signal 143 TERM' TERM
trap 'on_signal 129 HUP' HUP

deployment_dir="$EXPECTED_DEPLOYMENT_DIR"
backup_dir=""
confirmed=false

while (($#)); do
  case "$1" in
    --deployment-dir)
      (($# >= 2)) || die "--deployment-dir requires a value"
      deployment_dir="$2"
      shift 2
      ;;
    --backup-dir)
      (($# >= 2)) || die "--backup-dir requires a value"
      backup_dir="$2"
      shift 2
      ;;
    --confirm-legacy-restore)
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

$confirmed \
  || die "refusing destructive recovery without --confirm-legacy-restore"
[[ -n "$backup_dir" ]] || die "--backup-dir is required"
for command_name in \
  awk basename cat chmod cmp date dirname docker find flock grep id install mkdir \
  mktemp mountpoint mv realpath rm sha256sum sort stat tar tr xargs; do
  command -v "$command_name" >/dev/null 2>&1 \
    || die "required command is unavailable: $command_name"
done
docker compose version >/dev/null 2>&1 \
  || die "Docker Compose v2 is unavailable"
current_compose_version="$(docker compose version --short 2>/dev/null)" \
  || die "cannot resolve the Docker Compose version"
[[ "$current_compose_version" =~ ^v?[0-9]+(\.[0-9]+)+([._+-][A-Za-z0-9.-]+)?$ ]] \
  || die "Docker Compose returned an unsafe version identifier"
compose_up_help="$(docker compose up --help 2>/dev/null)" \
  || die "cannot inspect Docker Compose recovery capabilities"
for compose_option in --no-build --pull --force-recreate --wait --wait-timeout; do
  grep -Fq -- "$compose_option" <<< "$compose_up_help" \
    || die "Docker Compose is too old for fail-closed legacy recovery"
done

deployment_dir="$(realpath -e -- "$deployment_dir")"
[[ "$deployment_dir" == "$EXPECTED_DEPLOYMENT_DIR" ]] \
  || die "this one-time restore is restricted to /opt/axio7"
backup_dir="$(realpath -e -- "$backup_dir")"
backup_parent="$(realpath -e -- "$(dirname -- "$backup_dir")")"
[[ "$backup_dir" = /* && "$backup_dir" != "/" ]] \
  || die "--backup-dir must resolve to a non-root absolute path"
[[ "$(stat -c '%a' "$backup_dir")" == "700" ]] \
  || die "legacy backup directory mode must be 0700"
[[ "$(stat -c '%u' "$backup_dir")" == "$(id -u)" ]] \
  || die "legacy backup directory must be owned by the restore operator"
paths_overlap "$backup_dir" "$deployment_dir" \
  && die "legacy backup must not overlap /opt/axio7"
docker_root_dir="$(
  docker info --format '{{.DockerRootDir}}' 2>/dev/null
)" || die "cannot resolve the Docker data root"
docker_root_dir="$(realpath -e -- "$docker_root_dir")"
[[ -d "$docker_root_dir" && "$docker_root_dir" != "/" ]] \
  || die "Docker data root is not one safe directory"
paths_overlap "$backup_dir" "$docker_root_dir" \
  && die "legacy backup must not overlap the Docker data root"
for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  volume_mountpoint="$(
    docker volume inspect --format '{{.Mountpoint}}' "$volume_name" 2>/dev/null
  )" || die "fixed restore volume is missing: $volume_name"
  volume_mountpoint="$(realpath -e -- "$volume_mountpoint")"
  [[ -d "$volume_mountpoint" ]] \
    || die "fixed restore volume mountpoint is not a directory"
  paths_overlap "$backup_dir" "$volume_mountpoint" \
    && die "legacy backup must not overlap a fixed volume mountpoint"
done

acquire_legacy_lock

work_dir="$(mktemp -d "$backup_parent/.legacy-restore-work.XXXXXX")"
chmod 0700 -- "$work_dir"
for required_file in \
  SHA256SUMS .env.server.legacy Caddyfile.legacy RECOVERY.txt \
  backup-manifest.json caddy-config-directories.txt \
  caddy-config-files.sha256 caddy-config.tgz caddy-data-directories.txt \
  caddy-data-files.sha256 caddy-data.tgz compose.legacy.yaml legacy.env \
  quant-live-directories.txt quant-live-files.sha256 quant-live.tgz \
  quant-state-directories.txt quant-state-files.sha256 \
  quant-state-sqlite-family-files.txt quant-state.tgz \
  restore-legacy-flat.sh runtime-binds.tgz runtime-directories.txt \
  runtime-files.sha256 runtime-tree-directories.txt; do
  [[ -f "$backup_dir/$required_file" && ! -L "$backup_dir/$required_file" ]] \
    || die "legacy bundle file is missing or not regular: $required_file"
done
[[ "$(stat -c '%a' "$backup_dir/.env.server.legacy")" == "600" ]] \
  || die "sealed legacy environment mode must be 0600"
[[ "$(stat -c '%a' "$backup_dir/restore-legacy-flat.sh")" == "700" ]] \
  || die "sealed legacy restore helper mode must be 0700"
validate_checksum_manifest
(
  cd -- "$backup_dir"
  sha256sum --check --strict SHA256SUMS
)
sealed_dir="$work_dir/sealed"
mkdir -m 0700 -- "$sealed_dir"
install -m 0600 -- "$backup_dir/SHA256SUMS" "$sealed_dir/SHA256SUMS"
for staged_file in \
  .env.server.legacy Caddyfile.legacy RECOVERY.txt backup-manifest.json \
  caddy-config-directories.txt caddy-config-files.sha256 \
  caddy-data-directories.txt caddy-data-files.sha256 \
  compose.legacy.yaml legacy.env \
  quant-live-directories.txt quant-live-files.sha256 \
  quant-state-directories.txt quant-state-files.sha256 \
  quant-state-sqlite-family-files.txt restore-legacy-flat.sh \
  runtime-directories.txt runtime-files.sha256 runtime-tree-directories.txt; do
  install -m 0600 -- "$backup_dir/$staged_file" "$sealed_dir/$staged_file"
  file_matches_staged_checksum "$sealed_dir/$staged_file" "$staged_file" \
    || die "legacy bundle changed while its sealed metadata was staged"
done
chmod 0700 -- "$sealed_dir/restore-legacy-flat.sh"
running_restore_script="$(realpath -e -- "${BASH_SOURCE[0]}")"
cmp --silent "$running_restore_script" "$sealed_dir/restore-legacy-flat.sh" \
  || die "run the exact restore helper sealed inside this legacy bundle"

schema_version="$(read_metadata_value SCHEMA_VERSION "$sealed_dir/legacy.env")"
saved_deployment="$(read_metadata_value DEPLOYMENT_DIR "$sealed_dir/legacy.env")"
saved_compose_version="$(
  read_metadata_value DOCKER_COMPOSE_VERSION "$sealed_dir/legacy.env"
)"
application_oci_revision="$(
  read_metadata_value APPLICATION_OCI_REVISION "$sealed_dir/legacy.env"
)"
[[ "$schema_version" == "axio.legacy-flat-migration-backup.v1" \
  && "$saved_deployment" == "$EXPECTED_DEPLOYMENT_DIR" ]] \
  || die "legacy bundle metadata is not eligible for this restore"
[[ "$saved_compose_version" =~ ^v?[0-9]+(\.[0-9]+)+([._+-][A-Za-z0-9.-]+)?$ \
  && "$saved_compose_version" == "$current_compose_version" ]] \
  || die "restore requires the exact Docker Compose version used for backup"
grep -Fq '"schema_version": "axio.legacy-flat-migration-backup.v1"' \
  "$sealed_dir/backup-manifest.json" \
  || die "legacy backup manifest schema is invalid"
grep -Fq '"services_left_stopped": true' "$sealed_dir/backup-manifest.json" \
  || die "legacy backup was not sealed with services stopped"
grep -Fq '"execution_enabled": false' "$sealed_dir/backup-manifest.json" \
  || die "legacy backup does not prove disabled execution"
for required_manifest_fact in \
  '"compose_project": "axio7"' \
  '"service_count": 4' \
  '"complete_volume_set": true' \
  '"sqlite_wal_captured_as_complete_quiesced_volume": true' \
  '"runtime_tree_exactly_manifested": true' \
  '"runtime_hardlinks_dereferenced": true' \
  '"environment_contents_printed": false'; do
  grep -Fq "$required_manifest_fact" "$sealed_dir/backup-manifest.json" \
    || die "legacy backup manifest omits a required sealed fact"
done
if [[ "$application_oci_revision" == "NONE" ]]; then
  grep -Fq '"application_oci_revision_labels_absent": true' \
    "$sealed_dir/backup-manifest.json" \
    && grep -Fq '"application_oci_revision": null' \
      "$sealed_dir/backup-manifest.json" \
    || die "legacy backup manifest has an invalid absent revision binding"
elif [[ "$application_oci_revision" =~ ^[0-9a-f]{40}$ ]]; then
  grep -Fq '"application_oci_revision_labels_absent": false' \
    "$sealed_dir/backup-manifest.json" \
    && grep -Fq \
      "\"application_oci_revision\": \"$application_oci_revision\"" \
      "$sealed_dir/backup-manifest.json" \
    || die "legacy backup manifest has an invalid application revision binding"
else
  die "legacy bundle contains an invalid application OCI revision"
fi

quantd_image_id="$(read_metadata_value QUANTD_IMAGE_ID "$sealed_dir/legacy.env")"
web_image_id="$(read_metadata_value WEB_IMAGE_ID "$sealed_dir/legacy.env")"
caddy_image_id="$(read_metadata_value CADDY_IMAGE_ID "$sealed_dir/legacy.env")"
scheduler_image_id="$(read_metadata_value SCHEDULER_IMAGE_ID "$sealed_dir/legacy.env")"
quantd_container_id="$(read_metadata_value QUANTD_CONTAINER_ID "$sealed_dir/legacy.env")"
web_container_id="$(read_metadata_value WEB_CONTAINER_ID "$sealed_dir/legacy.env")"
caddy_container_id="$(read_metadata_value CADDY_CONTAINER_ID "$sealed_dir/legacy.env")"
scheduler_container_id="$(read_metadata_value SCHEDULER_CONTAINER_ID "$sealed_dir/legacy.env")"
quantd_config_hash="$(read_metadata_value QUANTD_COMPOSE_CONFIG_HASH "$sealed_dir/legacy.env")"
web_config_hash="$(read_metadata_value WEB_COMPOSE_CONFIG_HASH "$sealed_dir/legacy.env")"
caddy_config_hash="$(read_metadata_value CADDY_COMPOSE_CONFIG_HASH "$sealed_dir/legacy.env")"
scheduler_config_hash="$(read_metadata_value SCHEDULER_COMPOSE_CONFIG_HASH "$sealed_dir/legacy.env")"
quantd_reference="$(read_metadata_value QUANTD_IMAGE_REFERENCE "$sealed_dir/legacy.env")"
web_reference="$(read_metadata_value WEB_IMAGE_REFERENCE "$sealed_dir/legacy.env")"
caddy_reference="$(read_metadata_value CADDY_IMAGE_REFERENCE "$sealed_dir/legacy.env")"
scheduler_reference="$(read_metadata_value SCHEDULER_IMAGE_REFERENCE "$sealed_dir/legacy.env")"
quantd_tag="$(read_metadata_value QUANTD_RECOVERY_TAG "$sealed_dir/legacy.env")"
web_tag="$(read_metadata_value WEB_RECOVERY_TAG "$sealed_dir/legacy.env")"
caddy_tag="$(read_metadata_value CADDY_RECOVERY_TAG "$sealed_dir/legacy.env")"
scheduler_tag="$(read_metadata_value SCHEDULER_RECOVERY_TAG "$sealed_dir/legacy.env")"

for container_id in \
  "$quantd_container_id" "$web_container_id" "$caddy_container_id" \
  "$scheduler_container_id"; do
  [[ "$container_id" =~ ^[0-9a-f]{64}$ ]] \
    || die "legacy bundle contains an invalid original container ID"
done
for image_id in \
  "$quantd_image_id" "$web_image_id" "$caddy_image_id" \
  "$scheduler_image_id"; do
  [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
    || die "legacy bundle contains an invalid image ID"
  docker image inspect "$image_id" >/dev/null \
    || die "required legacy image ID is no longer present locally"
done
for application_image_id in "$quantd_image_id" "$web_image_id"; do
  observed_revision="$(
    docker image inspect --format \
      '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
      "$application_image_id"
  )"
  [[ "$observed_revision" != "<no value>" ]] || observed_revision=""
  if [[ "$application_oci_revision" == "NONE" ]]; then
    [[ -z "$observed_revision" ]] \
      || die "sealed legacy application image unexpectedly has a revision"
  else
    [[ "$observed_revision" == "$application_oci_revision" ]] \
      || die "sealed legacy application image revision changed"
  fi
done
for config_hash in \
  "$quantd_config_hash" "$web_config_hash" "$caddy_config_hash" \
  "$scheduler_config_hash"; do
  [[ "$config_hash" =~ ^[0-9a-f]{64}$ ]] \
    || die "legacy bundle contains an invalid Compose configuration hash"
done
for manifest_binding in \
  "docker_compose_version|$saved_compose_version" \
  "quantd_container_id|$quantd_container_id" \
  "web_container_id|$web_container_id" \
  "caddy_container_id|$caddy_container_id" \
  "scheduler_container_id|$scheduler_container_id" \
  "quantd_compose_config_hash|$quantd_config_hash" \
  "web_compose_config_hash|$web_config_hash" \
  "caddy_compose_config_hash|$caddy_config_hash" \
  "scheduler_compose_config_hash|$scheduler_config_hash" \
  "quantd_image_id|$quantd_image_id" \
  "web_image_id|$web_image_id" \
  "caddy_image_id|$caddy_image_id" \
  "scheduler_image_id|$scheduler_image_id"; do
  manifest_key="${manifest_binding%%|*}"
  manifest_value="${manifest_binding#*|}"
  grep -Fqx "  \"$manifest_key\": \"$manifest_value\"," \
    "$sealed_dir/backup-manifest.json" \
    || die "legacy metadata and JSON manifest disagree on $manifest_key"
done
for image_reference in \
  "$quantd_reference" "$web_reference" "$caddy_reference" \
  "$scheduler_reference" \
  "$quantd_tag" "$web_tag" "$caddy_tag" "$scheduler_tag"; do
  [[ "$image_reference" =~ ^[A-Za-z0-9][A-Za-z0-9._/:+-]*$ \
    && "$image_reference" != *"@"* ]] \
    || die "legacy bundle contains an unsafe image reference"
done
for tag_binding in \
  "$quantd_tag|$quantd_image_id" \
  "$web_tag|$web_image_id" \
  "$caddy_tag|$caddy_image_id" \
  "$scheduler_tag|$scheduler_image_id"; do
  recovery_tag="${tag_binding%%|*}"
  expected_image="${tag_binding#*|}"
  observed_image="$(
    docker image inspect --format '{{.Id}}' "$recovery_tag"
  )" || die "legacy recovery tag is missing: $recovery_tag"
  [[ "$observed_image" == "$expected_image" ]] \
    || die "legacy recovery tag points to the wrong image"
done

for gate_name in \
  LIVE_EXECUTION_ENABLED BROKER_LIVE_ENABLED ANOMALY_LIVE_ORDER_ENABLED; do
  grep -Eq \
    "^[[:space:]]+$gate_name:[[:space:]]+[\"']?false[\"']?[[:space:]]*$" \
    "$sealed_dir/compose.legacy.yaml" \
    || die "saved legacy Compose does not hard-disable $gate_name"
done
flat_compose_has_exact_web_env_file "$sealed_dir/compose.legacy.yaml" \
  || die "saved legacy web service does not use the sealed environment file"
validate_sealed_env_file "$sealed_dir" \
  || die "sealed legacy environment file is invalid"
if [[ "$application_oci_revision" != "NONE" ]]; then
  mapfile -t sealed_git_commit_lines < <(
    grep -E '^GIT_COMMIT=[0-9a-f]{40}\r?$' \
      "$sealed_dir/.env.server.legacy"
  )
  [[ "${#sealed_git_commit_lines[@]}" == "1" ]] \
    || die "sealed legacy environment has an invalid GIT_COMMIT binding"
  sealed_git_commit="${sealed_git_commit_lines[0]#GIT_COMMIT=}"
  sealed_git_commit="${sealed_git_commit%$'\r'}"
  [[ "$sealed_git_commit" == "$application_oci_revision" ]] \
    || die "sealed legacy environment differs from the application revision"
fi
saved_compose=(
  docker compose
  --project-name axio7
  --project-directory "$deployment_dir"
  --env-file "$sealed_dir/.env.server.legacy"
  -f "$sealed_dir/compose.legacy.yaml"
)
"${saved_compose[@]}" config --no-env-resolution --quiet >/dev/null 2>&1 \
  || die "saved legacy Compose configuration is invalid"
configured_services="$(
  "${saved_compose[@]}" config --no-env-resolution --services 2>/dev/null \
    | LC_ALL=C sort
)" || die "cannot enumerate services from saved legacy Compose"
expected_services="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | LC_ALL=C sort)"
[[ "$configured_services" == "$expected_services" ]] \
  || die "saved legacy Compose does not define the exact four services"
configured_volumes="$(
  "${saved_compose[@]}" config --no-env-resolution --volumes 2>/dev/null \
    | LC_ALL=C sort
)" || die "cannot enumerate volumes from saved legacy Compose"
expected_volumes="$(
  printf '%s\n' caddy-config caddy-data quant-live quant-state | LC_ALL=C sort
)"
[[ "$configured_volumes" == "$expected_volumes" ]] \
  || die "saved legacy Compose does not define the exact four volumes"
if grep -Eq \
  '^[[:space:]]+(scale|replicas):' \
  "$sealed_dir/compose.legacy.yaml"; then
  die "saved legacy Compose would scale a service during recovery"
fi
model_dir="$work_dir/compose-model"
mkdir -m 0700 -- "$model_dir"
"${saved_compose[@]}" config --no-env-resolution --format json \
  > "$model_dir/compose.json" 2>/dev/null \
  || die "cannot render the sealed legacy Compose model"
for image_binding in \
  "quantd|$quantd_reference" \
  "web|$web_reference" \
  "caddy|$caddy_reference" \
  "monitor-scheduler|$scheduler_reference"; do
  service="${image_binding%%|*}"
  image_reference="${image_binding#*|}"
  printf '%s\n' "$image_reference" \
    > "$model_dir/$service.image-reference"
done
validate_legacy_compose_model "$model_dir" "$web_image_id" \
  || die "sealed legacy Compose resolves outside the exact safe topology"
docker run --rm --pull never --network none --read-only \
  --tmpfs /data:size=16m --tmpfs /config:size=16m \
  --entrypoint caddy \
  --mount \
    "type=bind,src=$sealed_dir/Caddyfile.legacy,dst=/etc/caddy/Caddyfile,readonly" \
  "$caddy_image_id" \
  validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 \
  || die "saved legacy Caddy configuration is invalid"

for archive_name in \
  quant-state.tgz quant-live.tgz caddy-data.tgz caddy-config.tgz \
  runtime-binds.tgz; do
  file_matches_staged_checksum "$backup_dir/$archive_name" "$archive_name" \
    || die "legacy archive changed after checksum validation: $archive_name"
  assert_safe_archive \
    "$backup_dir/$archive_name" \
    "$work_dir/$archive_name.members" \
    "$work_dir/$archive_name.verbose-members"
done
assert_safe_runtime_archive "$work_dir/runtime-binds.tgz.members"
preflight_volume_archive \
  quant-state.tgz quant-state-files.sha256 quant-state-directories.txt
preflight_volume_archive \
  quant-live.tgz quant-live-files.sha256 quant-live-directories.txt
preflight_volume_archive \
  caddy-data.tgz caddy-data-files.sha256 caddy-data-directories.txt
preflight_volume_archive \
  caddy-config.tgz caddy-config-files.sha256 caddy-config-directories.txt
(
  cd -- "$work_dir/quant-state"
  find . -type f \( \
    -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" \
    -o -name "*-wal" -o -name "*-shm" -o -name "*-journal" \
  \) -print | LC_ALL=C sort
) > "$work_dir/quant-state-sqlite-family-files.observed.txt"
[[ -s "$sealed_dir/quant-state-sqlite-family-files.txt" ]] \
  || die "sealed quant-state SQLite-family manifest is empty"
cmp --silent \
  "$sealed_dir/quant-state-sqlite-family-files.txt" \
  "$work_dir/quant-state-sqlite-family-files.observed.txt" \
  || die "extracted quant-state SQLite/WAL family differs from the sealed list"
mkdir -m 0700 -- "$work_dir/runtime"
docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
  --mount "type=bind,src=$backup_dir,dst=/backup,readonly" \
  --mount "type=bind,src=$work_dir/runtime,dst=/target" \
  "$quantd_image_id" -ec '
    mountpoint -q /target
    test -z "$(find /target -mindepth 1 -print -quit)"
    tar -xzf /backup/runtime-binds.tgz -C /target
    cd /target
    if find . -mindepth 1 -print0 \
      | LC_ALL=C grep -z "[[:cntrl:]]" >/dev/null; then
      exit 1
    fi
    test -z "$(find . -mindepth 1 ! -type d ! -type f -print -quit)"
    test -z "$(find . -type f -links +1 -print -quit)"
  ' || die "cannot safely extract the sealed legacy runtime"
for archive_name in \
  quant-state.tgz quant-live.tgz caddy-data.tgz caddy-config.tgz \
  runtime-binds.tgz; do
  file_matches_staged_checksum "$backup_dir/$archive_name" "$archive_name" \
    || die "legacy archive changed during extraction: $archive_name"
done
runtime_tree_matches_manifest \
  "$work_dir/runtime" \
  "$sealed_dir/runtime-files.sha256" \
  "$work_dir/runtime-files.observed.sha256" \
  "$sealed_dir/runtime-directories.txt" \
  || die "extracted legacy runtime differs from its sealed manifest"
(
  cd -- "$work_dir/runtime"
  find . -type d -print | LC_ALL=C sort
) > "$work_dir/runtime-tree-directories.observed.txt"
cmp --silent \
  "$sealed_dir/runtime-tree-directories.txt" \
  "$work_dir/runtime-tree-directories.observed.txt" \
  || die "extracted legacy runtime omits or adds a directory"

running_project_ids="$(
  docker ps -q --filter label=com.docker.compose.project=axio7
)" || die "cannot verify that current AXIO7 containers are stopped"
[[ -z "$running_project_ids" ]] \
  || die "stop every current axio7 project container before legacy restore"
for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  observed_name="$(
    docker volume inspect --format '{{.Name}}' "$volume_name" 2>/dev/null
  )" || die "fixed restore volume is missing: $volume_name"
  [[ "$observed_name" == "$volume_name" ]] \
    || die "resolved an unexpected fixed restore volume"
  volume_is_detached "$volume_name" \
    || die "fixed restore volume is attached to a running container"
done

restore_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
emergency_dir="$backup_parent/pre-legacy-restore-$restore_stamp"
[[ ! -e "$emergency_dir" ]] \
  || die "pre-restore emergency directory already exists"
mkdir -m 0700 -- "$emergency_dir"
for current_file in .env.server compose.yaml Caddyfile; do
  if [[ -e "$deployment_dir/$current_file" || -L "$deployment_dir/$current_file" ]]; then
    [[ -f "$deployment_dir/$current_file" \
      && ! -L "$deployment_dir/$current_file" ]] \
      || die "current deployment configuration is not a regular file"
    install -m 0600 -- \
      "$deployment_dir/$current_file" \
      "$emergency_dir/$current_file.current"
  fi
done
if [[ -e "$deployment_dir/runtime" || -L "$deployment_dir/runtime" ]]; then
  [[ -d "$deployment_dir/runtime" && ! -L "$deployment_dir/runtime" ]] \
    || die "current runtime is not a real directory"
  tar -C "$deployment_dir" \
    -czf "$emergency_dir/runtime.current.tgz" runtime
fi
archive_current_volume \
  axio7_quant-state quant-state.current.tgz \
  || die "cannot preserve current quant-state before legacy restore"
archive_current_volume \
  axio7_quant-live quant-live.current.tgz \
  || die "cannot preserve current quant-live before legacy restore"
archive_current_volume \
  axio7_caddy-data caddy-data.current.tgz \
  || die "cannot preserve current Caddy data before legacy restore"
archive_current_volume \
  axio7_caddy-config caddy-config.current.tgz \
  || die "cannot preserve current Caddy config before legacy restore"
cat > "$emergency_dir/README.txt" <<EOF
This is the complete stopped current-state snapshot made immediately before
restoring legacy bundle:
  $backup_dir
If legacy restore fails, keep all writers stopped and inspect these archives.
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

for staged_binding in \
  "quant-state|quant-state-files.sha256|quant-state-directories.txt" \
  "quant-live|quant-live-files.sha256|quant-live-directories.txt" \
  "caddy-data|caddy-data-files.sha256|caddy-data-directories.txt" \
  "caddy-config|caddy-config-files.sha256|caddy-config-directories.txt" \
  "runtime|runtime-files.sha256|runtime-tree-directories.txt"; do
  IFS='|' read -r stage_name staged_files staged_directories \
    <<< "$staged_binding"
  staged_tree_matches_manifests \
    "$work_dir/$stage_name" \
    "$sealed_dir/$staged_files" \
    "$sealed_dir/$staged_directories" \
    "final-$stage_name" \
    || die "staged legacy $stage_name changed before destructive restore"
done
runtime_tree_matches_manifest \
  "$work_dir/runtime" \
  "$sealed_dir/runtime-files.sha256" \
  "$work_dir/runtime-files.final-private-check.sha256" \
  "$sealed_dir/runtime-directories.txt" \
  || die "staged legacy runtime failed its final private-tree check"
for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  volume_is_detached "$volume_name" \
    || die "fixed restore volume became attached before replacement"
done
for tag_binding in \
  "$quantd_tag|$quantd_image_id" \
  "$web_tag|$web_image_id" \
  "$caddy_tag|$caddy_image_id" \
  "$scheduler_tag|$scheduler_image_id"; do
  recovery_tag="${tag_binding%%|*}"
  expected_image="${tag_binding#*|}"
  observed_image="$(
    docker image inspect --format '{{.Id}}' "$recovery_tag"
  )" || die "legacy recovery tag disappeared before replacement"
  [[ "$observed_image" == "$expected_image" ]] \
    || die "legacy recovery tag changed before replacement"
done

destructive_started=true
restore_volume_from_stage \
  axio7_quant-state quant-state \
  quant-state-files.sha256 quant-state-directories.txt \
  || die "failed to restore exact legacy quant-state"
restore_volume_from_stage \
  axio7_quant-live quant-live \
  quant-live-files.sha256 quant-live-directories.txt \
  || die "failed to restore exact legacy quant-live"
restore_volume_from_stage \
  axio7_caddy-data caddy-data \
  caddy-data-files.sha256 caddy-data-directories.txt \
  || die "failed to restore exact legacy Caddy data"
restore_volume_from_stage \
  axio7_caddy-config caddy-config \
  caddy-config-files.sha256 caddy-config-directories.txt \
  || die "failed to restore exact legacy Caddy config"

displaced_runtime="$deployment_dir/runtime.pre-legacy-restore-$restore_stamp"
[[ ! -e "$displaced_runtime" ]] \
  || die "displaced runtime destination already exists"
if [[ -e "$deployment_dir/runtime" ]]; then
  mv -- "$deployment_dir/runtime" "$displaced_runtime"
fi
mkdir -m 0700 -- "$deployment_dir/runtime"
tar -C "$work_dir/runtime" -cpf - . \
  | tar -C "$deployment_dir/runtime" -xpf -
runtime_tree_matches_manifest \
  "$deployment_dir/runtime" \
  "$sealed_dir/runtime-files.sha256" \
  "$work_dir/runtime-files.restored.sha256" \
  "$sealed_dir/runtime-directories.txt" \
  || die "restored legacy runtime differs from its sealed manifest"
(
  cd -- "$deployment_dir/runtime"
  find . -type d -print | LC_ALL=C sort
) > "$work_dir/runtime-tree-directories.restored.txt"
cmp --silent \
  "$sealed_dir/runtime-tree-directories.txt" \
  "$work_dir/runtime-tree-directories.restored.txt" \
  || die "restored legacy runtime omits or adds a directory"

install -m 0600 -- \
  "$sealed_dir/.env.server.legacy" "$deployment_dir/.env.server"
install -m 0644 -- \
  "$sealed_dir/compose.legacy.yaml" "$deployment_dir/compose.yaml"
install -m 0644 -- \
  "$sealed_dir/Caddyfile.legacy" "$deployment_dir/Caddyfile"

docker image tag "$quantd_image_id" "$quantd_reference"
docker image tag "$web_image_id" "$web_reference"
docker image tag "$caddy_image_id" "$caddy_reference"
docker image tag "$scheduler_image_id" "$scheduler_reference"

restored_compose=(
  docker compose
  --project-name axio7
  --project-directory "$deployment_dir"
  --env-file "$deployment_dir/.env.server"
  -f "$deployment_dir/compose.yaml"
)
"${restored_compose[@]}" config --quiet >/dev/null 2>&1 \
  || die "installed legacy Compose configuration is invalid"
cmp --silent \
  "$sealed_dir/.env.server.legacy" "$deployment_dir/.env.server" \
  && cmp --silent \
    "$sealed_dir/compose.legacy.yaml" "$deployment_dir/compose.yaml" \
  && cmp --silent \
    "$sealed_dir/Caddyfile.legacy" "$deployment_dir/Caddyfile" \
  || die "installed legacy configuration differs from the immutable stage"
for config_binding in \
  "quantd|$quantd_config_hash" \
  "web|$web_config_hash" \
  "caddy|$caddy_config_hash" \
  "monitor-scheduler|$scheduler_config_hash"; do
  service="${config_binding%%|*}"
  expected_config_hash="${config_binding#*|}"
  config_hash_line="$(
    "${restored_compose[@]}" config --hash "$service" 2>/dev/null
  )" || die "cannot hash installed legacy $service configuration"
  [[ "$config_hash_line" =~ ^${service}[[:space:]]([0-9a-f]{64})$ ]] \
    || die "installed legacy $service configuration hash has an unexpected format"
  [[ "${BASH_REMATCH[1]}" == "$expected_config_hash" ]] \
    || die "installed legacy $service configuration differs from its sealed hash"
done
cmp --silent \
  "$sealed_dir/.env.server.legacy" "$deployment_dir/.env.server" \
  && cmp --silent \
    "$sealed_dir/compose.legacy.yaml" "$deployment_dir/compose.yaml" \
  && cmp --silent \
    "$sealed_dir/Caddyfile.legacy" "$deployment_dir/Caddyfile" \
  || die "installed legacy configuration changed before startup"
"${restored_compose[@]}" \
  up -d --no-build --pull never --force-recreate --wait --wait-timeout 180

running_services="$(
  "${restored_compose[@]}" ps --status running --services | LC_ALL=C sort
)"
expected_services="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | LC_ALL=C sort)"
[[ "$running_services" == "$expected_services" ]] \
  || die "restored legacy service set is incomplete"
running_project_services="$(
  docker ps \
    --filter label=com.docker.compose.project=axio7 \
    --format '{{.Label "com.docker.compose.service"}}' \
    | LC_ALL=C sort
)" || die "cannot enumerate the restored AXIO7 project"
[[ "$running_project_services" == "$expected_services" ]] \
  || die "restored AXIO7 project has an unexpected running container"
for service_binding in \
  "quantd|$quantd_image_id" \
  "web|$web_image_id" \
  "caddy|$caddy_image_id" \
  "monitor-scheduler|$scheduler_image_id"; do
  service="${service_binding%%|*}"
  expected_image="${service_binding#*|}"
  container_id="$("${restored_compose[@]}" ps -q "$service")"
  [[ "$container_id" =~ ^[0-9a-f]{12,64}$ ]] \
    || die "cannot resolve one restored $service container"
  container_id="$(
    docker inspect --format '{{.Id}}' "$container_id"
  )" || die "cannot canonicalize the restored $service container ID"
  [[ "$container_id" =~ ^[0-9a-f]{64}$ ]] \
    || die "restored $service container ID is not content-addressed"
  actual_image="$(docker inspect --format '{{.Image}}' "$container_id")"
  [[ "$actual_image" == "$expected_image" ]] \
    || die "restored $service does not use the sealed legacy image"
  RESTORED_CONTAINER_IDS["$service"]="$container_id"
done

quantd_mounts="$(
  docker inspect --format \
    '{{range .Mounts}}{{printf "%s|%s|%s|%s|%t\n" .Type .Name .Source .Destination .RW}}{{end}}' \
    "${RESTORED_CONTAINER_IDS[quantd]}"
)"
[[ "$(awk -F'|' '$1 == "volume" { count += 1 } END { print count + 0 }' <<< "$quantd_mounts")" == "2" \
  && "$(awk -F'|' '$1 == "bind" { count += 1 } END { print count + 0 }' <<< "$quantd_mounts")" == "8" \
  && "$(awk 'NF { count += 1 } END { print count + 0 }' <<< "$quantd_mounts")" == "10" ]] \
  || die "restored quantd mount count differs from the sealed topology"
for expected_mount in \
  "axio7_quant-live|/app/data/live" \
  "axio7_quant-state|/app/data/state"; do
  volume_name="${expected_mount%%|*}"
  destination="${expected_mount#*|}"
  awk -F'|' -v name="$volume_name" -v destination="$destination" '
    $1 == "volume" && $2 == name && $4 == destination && $5 == "true" {
      found += 1
    }
    END { exit(found == 1 ? 0 : 1) }
  ' <<< "$quantd_mounts" \
    || die "restored quantd uses the wrong fixed volume"
done
for runtime_mount in \
  "$deployment_dir/runtime/quant-calibration|/app/data/calibration|false" \
  "$deployment_dir/runtime/quant-promotion|/app/data/promotion|false" \
  "$deployment_dir/runtime/market-data|/app/data/market|true"; do
  IFS='|' read -r source_path destination expected_rw <<< "$runtime_mount"
  awk -F'|' -v source="$source_path" -v destination="$destination" \
      -v expected_rw="$expected_rw" '
    $1 == "bind" && $3 == source && $4 == destination && $5 == expected_rw {
      found += 1
    }
    END { exit(found == 1 ? 0 : 1) }
  ' <<< "$quantd_mounts" \
    || die "restored quantd uses the wrong fixed runtime bind"
done
active_release_source="$(
  awk -F'|' '
    $1 == "bind" && $4 == "/app/data/manifests" && $5 == "false" {
      print $3
    }
  ' <<< "$quantd_mounts"
)"
[[ "$active_release_source" =~ ^$deployment_dir/runtime/releases/([0-9a-f]{7})/quant-manifests$ ]] \
  || die "restored quantd active release mount is invalid"
active_release_root="${active_release_source%/quant-manifests}"
for runtime_mount in \
  "quant-raw|/app/data/raw" \
  "quant-normalized|/app/data/normalized" \
  "quant-evidence|/app/data/evidence" \
  "quant-manifests|/app/data/manifests" \
  "quant-rights|/app/data/rights"; do
  directory_name="${runtime_mount%%|*}"
  destination="${runtime_mount#*|}"
  source_path="$active_release_root/$directory_name"
  awk -F'|' -v source="$source_path" -v destination="$destination" '
    $1 == "bind" && $3 == source && $4 == destination && $5 == "false" {
      found += 1
    }
    END { exit(found == 1 ? 0 : 1) }
  ' <<< "$quantd_mounts" \
    || die "restored quantd uses the wrong release runtime bind"
done

caddy_mounts="$(
  docker inspect --format \
    '{{range .Mounts}}{{printf "%s|%s|%s|%s|%t\n" .Type .Name .Source .Destination .RW}}{{end}}' \
    "${RESTORED_CONTAINER_IDS[caddy]}"
)"
[[ "$(awk -F'|' '$1 == "volume" { count += 1 } END { print count + 0 }' <<< "$caddy_mounts")" == "2" \
  && "$(awk -F'|' '$1 == "bind" { count += 1 } END { print count + 0 }' <<< "$caddy_mounts")" == "1" \
  && "$(awk 'NF { count += 1 } END { print count + 0 }' <<< "$caddy_mounts")" == "3" ]] \
  || die "restored Caddy mount count differs from the sealed topology"
for expected_mount in \
  "axio7_caddy-data|/data" \
  "axio7_caddy-config|/config"; do
  volume_name="${expected_mount%%|*}"
  destination="${expected_mount#*|}"
  awk -F'|' -v name="$volume_name" -v destination="$destination" '
    $1 == "volume" && $2 == name && $4 == destination && $5 == "true" {
      found += 1
    }
    END { exit(found == 1 ? 0 : 1) }
  ' <<< "$caddy_mounts" \
    || die "restored Caddy uses the wrong fixed volume"
done
awk -F'|' -v source="$deployment_dir/Caddyfile" '
  $1 == "bind" && $3 == source && $4 == "/etc/caddy/Caddyfile" && $5 == "false" {
    found += 1
  }
  END { exit(found == 1 ? 0 : 1) }
' <<< "$caddy_mounts" \
  || die "restored Caddy uses the wrong configuration bind"
for service in web monitor-scheduler; do
  service_mounts="$(
    docker inspect --format \
      '{{range .Mounts}}{{printf "%s|%s|%s|%s|%t\n" .Type .Name .Source .Destination .RW}}{{end}}' \
      "${RESTORED_CONTAINER_IDS[$service]}"
  )"
  [[ -z "$(awk -F'|' '$1 == "volume" || $1 == "bind" { print; exit }' <<< "$service_mounts")" ]] \
    || die "restored $service has an unapproved persistent mount"
done
web_container="$("${restored_compose[@]}" ps -q web)"
docker exec "$web_container" sh -ec '
  test "$LIVE_EXECUTION_ENABLED" = "false"
  test "$BROKER_LIVE_ENABLED" = "false"
  test "$ANOMALY_LIVE_ORDER_ENABLED" = "false"
' >/dev/null

restore_succeeded=true
destructive_started=false
printf 'legacy-restore: exact legacy deployment restored and verified\n'
printf 'legacy-restore: pre-restore emergency snapshot retained at %s\n' \
  "$emergency_dir"
