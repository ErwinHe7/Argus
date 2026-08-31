#!/usr/bin/env bash
#
# One-time bridge for the exact legacy AXIO7 deployment copied flat into
# /opt/axio7. This accepts either missing application OCI revision labels or a
# shared revision exactly bound by the flat server environment, but only after
# proving the observed four-service/two-runtime-bind/four-volume shape.
# The canonical production-release-backup.sh remains the only backup path for
# commit-bound releases.

set -euo pipefail
umask 077

readonly EXPECTED_DEPLOYMENT_DIR="/opt/axio7"
readonly EXPECTED_SERVICES=(
  caddy
  monitor-scheduler
  quantd
  web
)
readonly STOP_ORDER=(
  monitor-scheduler
  caddy
  web
  quantd
)
readonly START_ORDER=(
  quantd
  web
  monitor-scheduler
  caddy
)
readonly REQUIRED_VOLUMES=(
  axio7_quant-state
  axio7_quant-live
  axio7_caddy-data
  axio7_caddy-config
)
readonly ALLOWED_RUNTIME_DIRECTORIES=(
  quant-normalized
  quant-manifests
  quant-rights
  quant-evidence
  private-rights-evidence
  quant-promotion
  quant-calibration
)

declare -A CONTAINER_IDS=()
declare -A CONFIG_HASHES=()
declare -A IMAGE_IDS=()
declare -A IMAGE_REFERENCES=()
declare -A RECOVERY_TAGS=()

die() {
  printf 'legacy-backup: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  production-legacy-flat-migration-backup.sh \
    --deployment-dir /opt/axio7 \
    --backup-root /opt/axio7-legacy-migration-backups \
    [--preflight-only | --confirm-legacy-quiesce]

This is a one-time migration bridge for the exact flat /opt/axio7 Compose
project whose running quantd and web images have no OCI revision label. It
captures the exact four container/image IDs, protects every image with a
recovery tag, stops all four services, archives the complete state/live/Caddy
volumes and approved runtime trees, verifies extracted file manifests, and
leaves the legacy stack stopped for cutover.

It never sources or prints .env.server, never prunes an image or volume, and
refuses a commit-bound or differently shaped deployment. Use the canonical
production-release-backup.sh for every later release.

--preflight-only performs the complete read-only topology, image, environment,
mount, execution-gate, and runtime-tree validation without tagging images or
stopping a service.
EOF
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

validate_legacy_compose_model_and_running_env() {
  local model_dir="$1"
  local web_image_id="$2"

  docker run --rm --pull never --user 0:0 --network none --read-only \
    --tmpfs /tmp:size=8m \
    --entrypoint node \
    --mount "type=bind,src=$model_dir,dst=/input,readonly" \
    "$web_image_id" -e '
      const fs = require("fs");
      const fail = () => process.exit(41);
      let model;
      let noEnvModel;
      try {
        model = JSON.parse(fs.readFileSync("/input/compose.json", "utf8"));
        noEnvModel = JSON.parse(
          fs.readFileSync("/input/compose-no-env.json", "utf8"),
        );
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
          || !same(sortedKeys(model.volumes), sortedKeys(volumeNames))
          || noEnvModel.name !== "axio7"
          || !same(sortedKeys(noEnvModel.services), services)
          || !same(
            sortedKeys(noEnvModel.volumes),
            sortedKeys(volumeNames),
          )) {
        fail();
      }
      for (const [key, exactName] of Object.entries(volumeNames)) {
        const volume = model.volumes[key] || {};
        const noEnvVolume = noEnvModel.volumes[key] || {};
        if (volume.name !== exactName
            || (volume.external !== undefined && volume.external !== false)
            || noEnvVolume.name !== exactName
            || (noEnvVolume.external !== undefined
                && noEnvVolume.external !== false)) {
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
        const noEnvService = noEnvModel.services[serviceName] || {};
        const mounts = normalizedMounts(service);
        const noEnvMounts = normalizedMounts(noEnvService);
        const modelReleaseIds = releaseIds(service);
        const noEnvReleaseIds = releaseIds(noEnvService);
        const envFileEntries = noEnvService.env_file || [];
        const envFilePaths = envFileEntries.map((entry) =>
          typeof entry === "string" ? entry : entry?.path,
        );
        const expectedEnvFiles = [];
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
        const resolvedNoEnvImageReference =
          noEnvService.image ?? `${noEnvModel.name}-${serviceName}`;
        if ((serviceName === "quantd"
              && (modelReleaseIds.length !== 5
                || noEnvReleaseIds.length !== 5
                || new Set(modelReleaseIds).size !== 1
                || new Set(noEnvReleaseIds).size !== 1
                || modelReleaseIds[0] !== noEnvReleaseIds[0]))
            || !same(mounts, expectedMounts[serviceName].slice().sort())
            || !same(
              noEnvMounts,
              expectedMounts[serviceName].slice().sort(),
            )
            || service.env_file !== undefined
            || !same(envFilePaths, expectedEnvFiles)
            || envFileEntries.some((entry) =>
              typeof entry !== "object"
                || entry === null
                || (entry.required !== undefined && entry.required !== true)
                || entry.format !== undefined
            )
            || resolvedImageReference !== imageReference
            || resolvedNoEnvImageReference !== imageReference
            || (service.scale !== undefined && service.scale !== 1)
            || (service.deploy?.replicas !== undefined
                && service.deploy.replicas !== 1)
            || (noEnvService.scale !== undefined
                && noEnvService.scale !== 1)
            || (noEnvService.deploy?.replicas !== undefined
                && noEnvService.deploy.replicas !== 1)
            || (service.pre_start && service.pre_start.length)
            || (service.post_start && service.post_start.length)
            || (noEnvService.pre_start
                && noEnvService.pre_start.length)
            || (noEnvService.post_start
                && noEnvService.post_start.length)) {
          fail();
        }
        const runningEnvPath = `/input/${serviceName}.env.json`;
        if (fs.existsSync(runningEnvPath)) {
          let runningEntries;
          try {
            runningEntries = JSON.parse(
              fs.readFileSync(runningEnvPath, "utf8"),
            );
          } catch {
            fail();
          }
          const runningEnv = new Map();
          for (const entry of runningEntries || []) {
            const split = String(entry).indexOf("=");
            if (split < 1) fail();
            runningEnv.set(
              String(entry).slice(0, split),
              String(entry).slice(split + 1),
            );
          }
          for (const [key, value] of Object.entries(service.environment || {})) {
            if (typeof value !== "string" || runningEnv.get(key) !== value) {
              fail();
            }
          }
        }
      }
      const web = model.services.web || {};
      const noEnvWeb = noEnvModel.services.web || {};
      if (web.network_mode !== "service:quantd"
          || web.environment?.LIVE_EXECUTION_ENABLED !== "false"
          || web.environment?.BROKER_LIVE_ENABLED !== "false"
          || web.environment?.ANOMALY_LIVE_ORDER_ENABLED !== "false"
          || noEnvWeb.network_mode !== "service:quantd"
          || noEnvWeb.environment?.LIVE_EXECUTION_ENABLED !== "false"
          || noEnvWeb.environment?.BROKER_LIVE_ENABLED !== "false"
          || noEnvWeb.environment?.ANOMALY_LIVE_ORDER_ENABLED !== "false") {
        fail();
      }
    ' >/dev/null 2>&1
}

archive_member_path_is_safe() {
  local member="$1"
  local component=""
  local normalized="${member#./}"
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

volume_is_detached() {
  local volume_name="$1"
  local running_ids=""

  running_ids="$(docker ps -q --filter "volume=$volume_name")" || return 1
  [[ -z "$running_ids" ]]
}

write_volume_manifest() {
  local volume_name="$1"
  local output_path="$2"

  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    "$helper_image_id" -ec '
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
    "$helper_image_id" -ec '
      mountpoint -q /source
      cd /source
      find . -type d -print | LC_ALL=C sort
    ' > "$output_path"
}

archive_volume() {
  local volume_name="$1"
  local archive_name="$2"
  local manifest_name="$3"
  local directories_name="$4"
  local source_after="$backup_dir/$manifest_name.source-after"
  local directories_after="$backup_dir/$directories_name.source-after"

  volume_is_detached "$volume_name" \
    || die "volume is attached to a running container: $volume_name"
  write_volume_manifest "$volume_name" "$backup_dir/$manifest_name"
  write_volume_directories "$volume_name" "$backup_dir/$directories_name"
  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/tar \
    --mount "type=volume,src=$volume_name,dst=/source,readonly" \
    --mount "type=bind,src=$backup_dir,dst=/backup" \
    "$helper_image_id" -C /source -czf "/backup/$archive_name" .
  write_volume_manifest "$volume_name" "$source_after"
  write_volume_directories "$volume_name" "$directories_after"
  cmp --silent "$backup_dir/$manifest_name" "$source_after" \
    || die "volume changed while it was archived: $volume_name"
  cmp --silent "$backup_dir/$directories_name" "$directories_after" \
    || die "volume directory tree changed while it was archived: $volume_name"
  rm -f -- "$source_after" "$directories_after"
}

preflight_volume_archive() {
  local archive_name="$1"
  local manifest_name="$2"
  local directories_name="$3"
  local target_name="${archive_name%.tgz}"
  local target_dir="$preflight_dir/$target_name"
  local observed_manifest="$preflight_dir/$manifest_name.observed"
  local observed_directories="$preflight_dir/$directories_name.observed"

  mkdir -m 0700 -- "$target_dir"
  docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
    --mount "type=bind,src=$backup_dir,dst=/backup,readonly" \
    --mount "type=bind,src=$target_dir,dst=/target" \
    "$helper_image_id" -ec '
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
  cmp --silent "$backup_dir/$manifest_name" "$observed_manifest" \
    || die "extracted archive differs from source manifest: $archive_name"
  cmp --silent "$backup_dir/$directories_name" "$observed_directories" \
    || die "extracted archive omits or adds a directory: $archive_name"
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
  (
    cd -- "$tree_root"
    find . -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 -r sha256sum
  ) > "$observed_manifest" || return 1
  cmp --silent "$expected_manifest" "$observed_manifest"
}

restart_unchanged_legacy_stack() {
  local service=""
  local container_id=""
  local running=""
  local restart_failed=false
  local stability_pass=0

  printf 'legacy-backup: restarting the unchanged legacy containers after backup failure\n' >&2
  for service in "${START_ORDER[@]}"; do
    container_id="${CONTAINER_IDS[$service]:-}"
    if [[ -z "$container_id" ]]; then
      restart_failed=true
      continue
    fi
    docker start "$container_id" >/dev/null || restart_failed=true
  done
  for stability_pass in 1 2; do
    sleep 5
    for service in "${EXPECTED_SERVICES[@]}"; do
      container_id="${CONTAINER_IDS[$service]:-}"
      if [[ -z "$container_id" ]]; then
        restart_failed=true
        continue
      fi
      running="$(
        docker inspect --format '{{.State.Running}}' "$container_id"
      )" || {
        restart_failed=true
        continue
      }
      [[ "$running" == "true" ]] || restart_failed=true
    done
  done
  $restart_failed && return 1
  quiesced=false
  return 0
}

stop_running_legacy_writers() {
  local ids=""
  local container_id=""
  local stop_failed=false
  local volume_name=""

  ids="$(
    docker ps -q --filter label=com.docker.compose.project=axio7
  )" || return 1
  while IFS= read -r container_id || [[ -n "$container_id" ]]; do
    [[ -z "$container_id" ]] && continue
    [[ "$container_id" =~ ^[0-9a-f]{12,64}$ ]] || {
      stop_failed=true
      continue
    }
    docker stop --time 60 "$container_id" >/dev/null || stop_failed=true
  done <<< "$ids"
  for volume_name in "${REQUIRED_VOLUMES[@]}"; do
    ids="$(docker ps -q --filter "volume=$volume_name")" || {
      stop_failed=true
      continue
    }
    while IFS= read -r container_id || [[ -n "$container_id" ]]; do
      [[ -z "$container_id" ]] && continue
      [[ "$container_id" =~ ^[0-9a-f]{12,64}$ ]] || {
        stop_failed=true
        continue
      }
      docker stop --time 60 "$container_id" >/dev/null || stop_failed=true
    done <<< "$ids"
  done
  $stop_failed && return 1
  return 0
}

verify_final_quiesced_sources() {
  local running_project_ids=""
  local all_project_count=""
  local service=""
  local container_id=""
  local observed_running=""
  local observed_image=""
  local observed_tag_image=""
  local volume_binding=""
  local volume_name=""
  local file_manifest=""
  local directory_manifest=""

  running_project_ids="$(
    docker ps -q --filter label=com.docker.compose.project=axio7
  )" || return 1
  [[ -z "$running_project_ids" ]] || return 1
  all_project_count="$(
    docker ps -aq \
      --filter label=com.docker.compose.project=axio7 \
      | awk 'NF { count += 1 } END { print count + 0 }'
  )" || return 1
  [[ "$all_project_count" == "4" ]] || return 1

  for service in "${EXPECTED_SERVICES[@]}"; do
    container_id="${CONTAINER_IDS[$service]}"
    observed_running="$(
      docker inspect --format '{{.State.Running}}' "$container_id"
    )" || return 1
    observed_image="$(
      docker inspect --format '{{.Image}}' "$container_id"
    )" || return 1
    observed_tag_image="$(
      docker image inspect --format '{{.Id}}' "${RECOVERY_TAGS[$service]}"
    )" || return 1
    [[ "$observed_running" == "false" \
      && "$observed_image" == "${IMAGE_IDS[$service]}" \
      && "$observed_tag_image" == "${IMAGE_IDS[$service]}" ]] \
      || return 1
  done

  for volume_binding in \
    "axio7_quant-state|quant-state-files.sha256|quant-state-directories.txt" \
    "axio7_quant-live|quant-live-files.sha256|quant-live-directories.txt" \
    "axio7_caddy-data|caddy-data-files.sha256|caddy-data-directories.txt" \
    "axio7_caddy-config|caddy-config-files.sha256|caddy-config-directories.txt"; do
    IFS='|' read -r volume_name file_manifest directory_manifest \
      <<< "$volume_binding"
    volume_is_detached "$volume_name" || return 1
    write_volume_manifest \
      "$volume_name" "$preflight_dir/$file_manifest.final-source" \
      || return 1
    write_volume_directories \
      "$volume_name" "$preflight_dir/$directory_manifest.final-source" \
      || return 1
    cmp --silent \
      "$backup_dir/$file_manifest" \
      "$preflight_dir/$file_manifest.final-source" \
      || return 1
    cmp --silent \
      "$backup_dir/$directory_manifest" \
      "$preflight_dir/$directory_manifest.final-source" \
      || return 1
    volume_is_detached "$volume_name" || return 1
  done

  runtime_tree_matches_manifest \
    "$runtime_dir" \
    "$backup_dir/runtime-files.sha256" \
    "$preflight_dir/runtime-files.final-source.sha256" \
    "$backup_dir/runtime-directories.txt" \
    || return 1
  (
    cd -- "$runtime_dir"
    find . -type d -print | LC_ALL=C sort
  ) > "$preflight_dir/runtime-tree-directories.final-source.txt" \
    || return 1
  cmp --silent \
    "$backup_dir/runtime-tree-directories.txt" \
    "$preflight_dir/runtime-tree-directories.final-source.txt" \
    || return 1
  [[ "$(sha256sum "$compose_file" | awk '{print $1}')" == "$compose_sha_before" \
    && "$(sha256sum "$caddy_file" | awk '{print $1}')" == "$caddy_sha_before" \
    && "$(sha256sum "$env_file" | awk '{print $1}')" == "$env_sha_before" ]] \
    || return 1

  running_project_ids="$(
    docker ps -q --filter label=com.docker.compose.project=axio7
  )" || return 1
  [[ -z "$running_project_ids" ]] || return 1
  for volume_name in "${REQUIRED_VOLUMES[@]}"; do
    volume_is_detached "$volume_name" || return 1
  done
}

root_bashpid="$BASHPID"
quiesced=false
backup_complete=false
preflight_dir=""
validation_dir=""
backup_dir=""
runtime_directories_file=""

cleanup() {
  local status=$?

  [[ "$BASHPID" == "$root_bashpid" ]] || return "$status"
  trap - EXIT INT TERM HUP
  set +e +u
  if ((status != 0)) && $quiesced && ! $backup_complete; then
    if ! stop_running_legacy_writers \
      || ! restart_unchanged_legacy_stack; then
      printf 'legacy-backup: restart failed; exact legacy containers remain available by ID in %s\n' \
        "${backup_dir:-the incomplete backup directory}" >&2
    fi
  fi
  if [[ -n "$preflight_dir" \
    && -n "${backup_root:-}" \
    && "$preflight_dir" == "$backup_root"/.legacy-preflight.* \
    && "$preflight_dir" != "/" ]]; then
    rm -rf -- "$preflight_dir"
  fi
  if [[ -n "$validation_dir" \
    && -n "${backup_root:-}" \
    && "$validation_dir" == "$backup_root"/.legacy-config-validation.* \
    && "$validation_dir" != "/" ]]; then
    rm -rf -- "$validation_dir"
  fi
  if [[ -n "$runtime_directories_file" \
    && -n "${backup_root:-}" \
    && "$runtime_directories_file" == "$backup_root"/.runtime-directories.* \
    && "$runtime_directories_file" != "/" ]]; then
    rm -f -- "$runtime_directories_file"
  fi
  if ((status != 0)) && [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
    printf 'legacy-backup: incomplete mode-0700 evidence retained at %s\n' \
      "$backup_dir" >&2
  fi
  exit "$status"
}
trap cleanup EXIT

on_signal() {
  local status="$1"
  local signal_name="$2"
  printf 'legacy-backup: received %s; entering fail-closed cleanup\n' \
    "$signal_name" >&2
  exit "$status"
}
trap 'on_signal 130 INT' INT
trap 'on_signal 143 TERM' TERM
trap 'on_signal 129 HUP' HUP

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
deployment_dir="$EXPECTED_DEPLOYMENT_DIR"
backup_root="/opt/axio7-legacy-migration-backups"
confirmed=false
preflight_only=false

while (($#)); do
  case "$1" in
    --deployment-dir)
      (($# >= 2)) || die "--deployment-dir requires a value"
      deployment_dir="$2"
      shift 2
      ;;
    --backup-root)
      (($# >= 2)) || die "--backup-root requires a value"
      backup_root="$2"
      shift 2
      ;;
    --confirm-legacy-quiesce)
      confirmed=true
      shift
      ;;
    --preflight-only)
      preflight_only=true
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

if $confirmed && $preflight_only; then
  die "--preflight-only and --confirm-legacy-quiesce are mutually exclusive"
fi
$confirmed || $preflight_only \
  || die "refusing to stop the legacy deployment without --confirm-legacy-quiesce"
for command_name in \
  awk basename cat chmod cmp date docker find flock grep id install mapfile mkdir \
  mktemp mountpoint mv realpath rm sha256sum sleep sort stat tar tr xargs; do
  command -v "$command_name" >/dev/null 2>&1 \
    || die "required command is unavailable: $command_name"
done
docker compose version >/dev/null 2>&1 \
  || die "Docker Compose v2 is unavailable"
compose_version="$(docker compose version --short 2>/dev/null)" \
  || die "cannot resolve the Docker Compose version"
[[ "$compose_version" =~ ^v?[0-9]+(\.[0-9]+)+([._+-][A-Za-z0-9.-]+)?$ ]] \
  || die "Docker Compose returned an unsafe version identifier"
[[ -f "$script_dir/production-legacy-flat-migration-restore.sh" ]] \
  || die "the paired legacy restore helper is missing"

deployment_dir="$(realpath -e -- "$deployment_dir")"
[[ "$deployment_dir" == "$EXPECTED_DEPLOYMENT_DIR" ]] \
  || die "this one-time helper is restricted to /opt/axio7"
compose_file="$deployment_dir/compose.yaml"
caddy_file="$deployment_dir/Caddyfile"
env_file="$deployment_dir/.env.server"
runtime_dir="$deployment_dir/runtime"
for required_path in "$compose_file" "$caddy_file" "$env_file"; do
  [[ -f "$required_path" && ! -L "$required_path" ]] \
    || die "required flat-deployment file is missing or not regular"
done
[[ "$(stat -c '%a' "$env_file")" == "600" ]] \
  || die ".env.server mode must be 0600"
flat_compose_has_exact_web_env_file "$compose_file" \
  || die "flat web service must use exactly one .env.server env_file"
[[ -d "$runtime_dir" && ! -L "$runtime_dir" ]] \
  || die "legacy runtime must be one real directory"
runtime_dir="$(realpath -e -- "$runtime_dir")"
[[ "$runtime_dir" == "$deployment_dir/runtime" ]] \
  || die "runtime resolves outside /opt/axio7"
tree_has_control_characters "$runtime_dir" \
  && die "legacy runtime contains a control character in a path"

acquire_legacy_lock

backup_root="$(realpath -m -- "$backup_root")"
[[ "$backup_root" = /* && "$backup_root" != "/" ]] \
  || die "--backup-root must resolve to a non-root absolute path"
case "$backup_root/" in
  "$deployment_dir/"*)
    die "backup root must not be inside /opt/axio7"
    ;;
esac
case "$deployment_dir/" in
  "$backup_root/"*)
    die "/opt/axio7 must not be inside the backup root"
    ;;
esac
docker_root_dir="$(
  docker info --format '{{.DockerRootDir}}' 2>/dev/null
)" || die "cannot resolve the Docker data root"
docker_root_dir="$(realpath -e -- "$docker_root_dir")"
[[ -d "$docker_root_dir" && "$docker_root_dir" != "/" ]] \
  || die "Docker data root is not one safe directory"
paths_overlap "$backup_root" "$docker_root_dir" \
  && die "backup root must not overlap the Docker data root"
for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  volume_mountpoint="$(
    docker volume inspect --format '{{.Mountpoint}}' "$volume_name" 2>/dev/null
  )" || die "required legacy volume is missing: $volume_name"
  volume_mountpoint="$(realpath -e -- "$volume_mountpoint")"
  [[ -d "$volume_mountpoint" ]] \
    || die "legacy volume mountpoint is not a directory"
  paths_overlap "$backup_root" "$volume_mountpoint" \
    && die "backup root must not overlap a legacy volume mountpoint"
done
current_uid="$(id -u)"
if [[ -e "$backup_root" || -L "$backup_root" ]]; then
  [[ -d "$backup_root" && ! -L "$backup_root" ]] \
    || die "existing backup root must be a real directory"
  [[ "$(stat -c '%a' "$backup_root")" == "700" \
    && "$(stat -c '%u' "$backup_root")" == "$current_uid" ]] \
    || die "existing backup root must be mode 0700 and owned by the operator"
else
  mkdir -m 0700 -- "$backup_root"
fi
backup_root="$(realpath -e -- "$backup_root")"

compose=(
  docker compose
  --project-name axio7
  --project-directory "$deployment_dir"
  --env-file "$env_file"
  -f "$compose_file"
)
"${compose[@]}" config --quiet >/dev/null 2>&1 \
  || die "legacy Compose configuration is invalid"
configured_services="$(
  "${compose[@]}" config --services 2>/dev/null | LC_ALL=C sort
)" || die "cannot enumerate services from the flat Compose file"
expected_services="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | LC_ALL=C sort)"
[[ "$configured_services" == "$expected_services" ]] \
  || die "flat Compose file does not define the exact four-service legacy stack"
configured_volumes="$(
  "${compose[@]}" config --volumes 2>/dev/null | LC_ALL=C sort
)" || die "cannot enumerate volumes from the flat Compose file"
expected_volumes="$(
  printf '%s\n' caddy-config caddy-data quant-live quant-state | LC_ALL=C sort
)"
[[ "$configured_volumes" == "$expected_volumes" ]] \
  || die "flat Compose file does not define the exact four legacy volumes"
if grep -Eq '^[[:space:]]+scale:' "$compose_file"; then
  die "legacy Compose must not use the scale key during recovery"
fi
invalid_replica_lines="$(
  awk '
    /^[[:space:]]+replicas:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]+replicas:[[:space:]]*/, "", value)
      gsub(/^[[:space:]"'\'']+|[[:space:]"'\'']+$/, "", value)
      if (value != "1") {
        print NR ":" $0
      }
    }
  ' "$compose_file"
)"
[[ -z "$invalid_replica_lines" ]] \
  || die "legacy Compose may declare only replicas: 1 during recovery"
for gate_name in \
  LIVE_EXECUTION_ENABLED BROKER_LIVE_ENABLED ANOMALY_LIVE_ORDER_ENABLED; do
  grep -Eq \
    "^[[:space:]]+$gate_name:[[:space:]]+[\"']?false[\"']?[[:space:]]*$" \
    "$compose_file" \
    || die "legacy Compose does not hard-disable $gate_name"
done

observed_services="$(
  docker ps \
    --filter label=com.docker.compose.project=axio7 \
    --format '{{.Label "com.docker.compose.service"}}' \
    | LC_ALL=C sort
)" || die "cannot enumerate the legacy Compose services"
[[ "$observed_services" == "$expected_services" ]] \
  || die "running project is not the exact four-service legacy stack"
all_project_count="$(
  docker ps -aq \
    --filter label=com.docker.compose.project=axio7 \
    | awk 'NF { count += 1 } END { print count + 0 }'
)" || die "cannot count all legacy project containers"
[[ "$all_project_count" == "4" ]] \
  || die "legacy project has a stopped, one-off, or duplicate container"
all_project_services="$(
  docker ps -a \
    --filter label=com.docker.compose.project=axio7 \
    --format '{{.Label "com.docker.compose.service"}}' \
    | LC_ALL=C sort
)" || die "cannot enumerate all legacy project containers"
[[ "$all_project_services" == "$expected_services" ]] \
  || die "legacy project container history does not match the exact service set"
expected_project_volumes="$(
  printf '%s\n' "${REQUIRED_VOLUMES[@]}" | LC_ALL=C sort
)"
observed_project_volumes="$(
  docker volume ls \
    --filter label=com.docker.compose.project=axio7 \
    --format '{{.Name}}' \
    | LC_ALL=C sort
)" || die "cannot enumerate legacy project volumes"
[[ "$observed_project_volumes" == "$expected_project_volumes" ]] \
  || die "legacy project does not own the exact four fixed volumes"

for service in "${EXPECTED_SERVICES[@]}"; do
  service_id="$(
    docker ps -q \
      --filter label=com.docker.compose.project=axio7 \
      --filter "label=com.docker.compose.service=$service"
  )" || die "cannot inspect the running $service container"
  [[ "$service_id" =~ ^[0-9a-f]{12,64}$ ]] \
    || die "cannot resolve exactly one running $service container"
  service_id="$(
    docker inspect --format '{{.Id}}' "$service_id"
  )" || die "cannot canonicalize the running $service container ID"
  [[ "$service_id" =~ ^[0-9a-f]{64}$ ]] \
    || die "$service container ID is not content-addressed"
  auto_remove="$(docker inspect --format '{{.HostConfig.AutoRemove}}' "$service_id")"
  [[ "$auto_remove" == "false" ]] \
    || die "$service uses AutoRemove and cannot be safely quiesced"
  CONTAINER_IDS["$service"]="$service_id"
  working_dir="$(
    docker inspect --format \
      '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' \
      "$service_id"
  )"
  config_files="$(
    docker inspect --format \
      '{{index .Config.Labels "com.docker.compose.project.config_files"}}' \
      "$service_id"
  )"
  [[ "$working_dir" == "$deployment_dir" \
    && "$config_files" == "$compose_file" ]] \
    || die "$service was not created from the exact flat /opt/axio7 Compose file"
  config_hash_line="$(
    "${compose[@]}" config --hash "$service" 2>/dev/null
  )" || die "cannot hash the effective $service Compose configuration"
  [[ "$config_hash_line" =~ ^${service}[[:space:]]([0-9a-f]{64})$ ]] \
    || die "effective $service Compose hash has an unexpected format"
  config_hash="${BASH_REMATCH[1]}"
  running_config_hash="$(
    docker inspect --format \
      '{{index .Config.Labels "com.docker.compose.config-hash"}}' \
      "$service_id"
  )"
  [[ "$running_config_hash" =~ ^[0-9a-f]{64}$ ]] \
    || die "$service running Compose hash is not content-addressed"
  if [[ "$running_config_hash" != "$config_hash" ]]; then
    container_name="$(
      docker inspect --format '{{.Name}}' "$service_id"
    )"
    container_name="${container_name#/}"
    [[ "$container_name" =~ ^axio7-[a-z0-9-]+-1$ ]] \
      || die "$service running container name is outside the legacy project"
    reconcile_output="$(
      "${compose[@]}" \
        --ansi never \
        --progress plain \
        --dry-run \
        up -d --no-build --pull never --no-deps "$service" 2>&1
    )" || die "cannot dry-run the effective $service Compose configuration"
    grep -Eq \
      "Container[[:space:]]+$container_name[[:space:]]+Running" \
      <<< "$reconcile_output" \
      || die "$service running configuration differs from the flat Compose file"
    grep -Eq \
      '(^|[[:space:]])(Create|Creating|Created|Recreate|Recreated|Restart|Restarting|Stop|Stopping|Remove|Removing)([[:space:]]|$)' \
      <<< "$reconcile_output" \
      && die "$service dry-run would mutate the legacy deployment"
  fi
  CONFIG_HASHES["$service"]="$config_hash"

  image_id="$(docker inspect --format '{{.Image}}' "$service_id")"
  image_reference="$(docker inspect --format '{{.Config.Image}}' "$service_id")"
  [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
    || die "$service image ID is not content-addressed"
  [[ "$image_reference" =~ ^[A-Za-z0-9][A-Za-z0-9._/:+-]*$ \
    && "$image_reference" != *"@"* ]] \
    || die "$service image reference is unsafe for recovery tagging"
  IMAGE_IDS["$service"]="$image_id"
  IMAGE_REFERENCES["$service"]="$image_reference"
done

quantd_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "${IMAGE_IDS[quantd]}"
)"
web_revision="$(
  docker image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "${IMAGE_IDS[web]}"
)"
[[ "$quantd_revision" != "<no value>" ]] || quantd_revision=""
[[ "$web_revision" != "<no value>" ]] || web_revision=""
application_oci_revision="NONE"
application_oci_revision_labels_absent=true
application_oci_revision_json=null
if [[ -n "$quantd_revision" || -n "$web_revision" ]]; then
  [[ "$quantd_revision" =~ ^[0-9a-f]{40}$ \
    && "$web_revision" == "$quantd_revision" ]] \
    || die "flat quantd and web OCI revisions must be the same full commit"
  mapfile -t env_git_commit_lines < <(
    grep -E '^GIT_COMMIT=[0-9a-f]{40}\r?$' "$env_file"
  )
  [[ "${#env_git_commit_lines[@]}" == "1" ]] \
    || die "flat environment must contain one full GIT_COMMIT binding"
  env_git_commit="${env_git_commit_lines[0]#GIT_COMMIT=}"
  env_git_commit="${env_git_commit%$'\r'}"
  [[ "$env_git_commit" == "$quantd_revision" ]] \
    || die "flat environment GIT_COMMIT differs from the application images"
  application_oci_revision="$quantd_revision"
  application_oci_revision_labels_absent=false
  application_oci_revision_json="\"$quantd_revision\""
fi

validation_dir="$(mktemp -d "$backup_root/.legacy-config-validation.XXXXXX")"
chmod 0700 -- "$validation_dir"
"${compose[@]}" config --format json \
  > "$validation_dir/compose.json" 2>/dev/null \
  || die "cannot render the effective legacy Compose model"
"${compose[@]}" config --no-env-resolution --format json \
  > "$validation_dir/compose-no-env.json" 2>/dev/null \
  || die "cannot render the legacy Compose env-file model"
for service in "${EXPECTED_SERVICES[@]}"; do
  docker inspect --format '{{json .Config.Env}}' \
    "${CONTAINER_IDS[$service]}" \
    > "$validation_dir/$service.env.json" \
    || die "cannot capture the running $service environment for hash-only comparison"
  printf '%s\n' "${IMAGE_REFERENCES[$service]}" \
    > "$validation_dir/$service.image-reference"
done
validate_legacy_compose_model_and_running_env \
  "$validation_dir" "${IMAGE_IDS[web]}" \
  || die "effective legacy Compose model or running environment differs from the exact safe shape"
rm -rf -- "$validation_dir"
validation_dir=""

web_container="${CONTAINER_IDS[web]}"
docker exec "$web_container" sh -ec '
  test "$LIVE_EXECUTION_ENABLED" = "false"
  test "$BROKER_LIVE_ENABLED" = "false"
  test "$ANOMALY_LIVE_ORDER_ENABLED" = "false"
' >/dev/null

quantd_mounts="$(
  docker inspect --format \
    '{{range .Mounts}}{{printf "%s|%s|%s|%s|%t\n" .Type .Name .Source .Destination .RW}}{{end}}' \
    "${CONTAINER_IDS[quantd]}"
)"
[[ "$(awk -F'|' '$1 == "volume" { count += 1 } END { print count + 0 }' <<< "$quantd_mounts")" == "2" ]] \
  || die "legacy quantd does not have exactly two named volumes"
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
    || die "legacy quantd volume mount is missing or changed: $volume_name"
done
[[ "$(awk -F'|' '$1 == "bind" { count += 1 } END { print count + 0 }' <<< "$quantd_mounts")" == "8" ]] \
  || die "legacy quantd does not have exactly eight runtime bind mounts"
[[ "$(awk 'NF { count += 1 } END { print count + 0 }' <<< "$quantd_mounts")" == "10" ]] \
  || die "legacy quantd has an unapproved extra mount"
for runtime_mount in \
  "quant-calibration|/app/data/calibration|false" \
  "quant-promotion|/app/data/promotion|false" \
  "market-data|/app/data/market|true"; do
  IFS='|' read -r directory_name destination expected_rw <<< "$runtime_mount"
  source_path="$runtime_dir/$directory_name"
  awk -F'|' -v source="$source_path" -v destination="$destination" \
      -v expected_rw="$expected_rw" '
    $1 == "bind" && $3 == source && $4 == destination && $5 == expected_rw {
      found += 1
    }
    END { exit(found == 1 ? 0 : 1) }
  ' <<< "$quantd_mounts" \
    || die "legacy quantd fixed runtime mount is missing: $directory_name"
done
active_release_source="$(
  awk -F'|' '
    $1 == "bind" && $4 == "/app/data/manifests" && $5 == "false" {
      print $3
    }
  ' <<< "$quantd_mounts"
)"
[[ "$active_release_source" =~ ^$runtime_dir/releases/([0-9a-f]{7})/quant-manifests$ ]] \
  || die "legacy quantd active release mount is invalid"
active_release_root="${active_release_source%/quant-manifests}"
[[ -d "$active_release_root" && ! -L "$active_release_root" ]] \
  || die "legacy quantd active release directory is missing"
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
    || die "legacy quantd release mount is missing: $directory_name"
done

caddy_mounts="$(
  docker inspect --format \
    '{{range .Mounts}}{{printf "%s|%s|%s|%s|%t\n" .Type .Name .Source .Destination .RW}}{{end}}' \
    "${CONTAINER_IDS[caddy]}"
)"
[[ "$(awk -F'|' '$1 == "volume" { count += 1 } END { print count + 0 }' <<< "$caddy_mounts")" == "2" ]] \
  || die "legacy Caddy does not have exactly two named volumes"
[[ "$(awk -F'|' '$1 == "bind" { count += 1 } END { print count + 0 }' <<< "$caddy_mounts")" == "1" ]] \
  || die "legacy Caddy does not have exactly one bind mount"
[[ "$(awk 'NF { count += 1 } END { print count + 0 }' <<< "$caddy_mounts")" == "3" ]] \
  || die "legacy Caddy has an unapproved extra mount"
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
    || die "legacy Caddy volume mount is missing or changed: $volume_name"
done
awk -F'|' -v source="$caddy_file" '
  $1 == "bind" && $3 == source && $4 == "/etc/caddy/Caddyfile" && $5 == "false" {
    found += 1
  }
  END { exit(found == 1 ? 0 : 1) }
' <<< "$caddy_mounts" \
  || die "legacy Caddyfile bind is missing or writable"

for service in web monitor-scheduler; do
  service_mounts="$(
    docker inspect --format \
      '{{range .Mounts}}{{printf "%s|%s|%s|%s|%t\n" .Type .Name .Source .Destination .RW}}{{end}}' \
      "${CONTAINER_IDS[$service]}"
  )"
  [[ -z "$(awk -F'|' '$1 == "volume" || $1 == "bind" { print; exit }' <<< "$service_mounts")" ]] \
    || die "$service has an unapproved persistent mount outside the sealed volume set"
done

for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  observed_name="$(
    docker volume inspect --format '{{.Name}}' "$volume_name" 2>/dev/null
  )" || die "required legacy volume is missing: $volume_name"
  [[ "$observed_name" == "$volume_name" ]] \
    || die "resolved an unexpected volume for $volume_name"
done

helper_image_id="${IMAGE_IDS[quantd]}"
docker run --rm --pull never --network none --read-only \
  --tmpfs /data:size=16m --tmpfs /config:size=16m \
  --entrypoint caddy \
  --mount "type=bind,src=$caddy_file,dst=/etc/caddy/Caddyfile,readonly" \
  "${IMAGE_IDS[caddy]}" \
  validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 \
  || die "legacy Caddy configuration is invalid"

runtime_directories_file="$backup_root/.runtime-directories.$$"
: > "$runtime_directories_file"
while IFS= read -r runtime_entry || [[ -n "$runtime_entry" ]]; do
  [[ -n "$runtime_entry" ]] || continue
  runtime_name="$(basename -- "$runtime_entry")"
  runtime_directory_is_allowed "$runtime_name" \
    || die "legacy runtime contains an unapproved top-level entry"
  [[ -d "$runtime_entry" && ! -L "$runtime_entry" ]] \
    || die "legacy runtime top-level entries must be real directories"
  printf '%s\n' "$runtime_name" >> "$runtime_directories_file"
done < <(find "$runtime_dir" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort)
for required_runtime in \
  market-data releases quant-raw quant-normalized quant-manifests \
  quant-calibration quant-promotion; do
  grep -Fxq "$required_runtime" "$runtime_directories_file" \
    || die "legacy runtime is missing $required_runtime"
done
expected_release_directories="$(
  printf '%s\n' \
    quant-evidence quant-manifests quant-normalized quant-raw quant-rights \
    | LC_ALL=C sort
)"
while IFS= read -r release_entry || [[ -n "$release_entry" ]]; do
  [[ -n "$release_entry" ]] || continue
  release_name="$(basename -- "$release_entry")"
  [[ "$release_name" =~ ^[0-9a-f]{7}$ \
    && -d "$release_entry" && ! -L "$release_entry" ]] \
    || die "legacy release tree contains an invalid release directory"
  observed_release_directories="$(
    find "$release_entry" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
      | LC_ALL=C sort
  )"
  [[ "$observed_release_directories" == "$expected_release_directories" ]] \
    || die "legacy release directory does not contain the exact artifact trees"
done < <(find "$runtime_dir/releases" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort)
[[ -z "$(find "$runtime_dir" -mindepth 1 ! -type d ! -type f -print -quit)" ]] \
  || die "legacy runtime contains a link or special entry"
if grep -Fxq private-rights-evidence "$runtime_directories_file"; then
  private_dir="$runtime_dir/private-rights-evidence"
  private_file="$private_dir/account_owner_attestation.json"
  [[ "$(stat -c '%a' "$private_dir")" == "700" ]] \
    || die "private owner-attestation directory mode must be 0700"
  [[ -z "$(
    find "$private_dir" -mindepth 1 -maxdepth 1 \
      ! -name account_owner_attestation.json -print -quit
  )" ]] || die "private owner-attestation directory has an unexpected entry"
  if [[ -e "$private_file" || -L "$private_file" ]]; then
    [[ -f "$private_file" \
      && ! -L "$private_file" \
      && "$(stat -c '%a' "$private_file")" == "600" \
      && "$(stat -c '%h' "$private_file")" == "1" ]] \
      || die "private owner-attestation must be one mode-0600 regular file"
  fi
fi

if $preflight_only; then
  printf 'legacy-backup: read-only four-service preflight passed; no service or image was changed\n'
  exit 0
fi

compose_sha_before="$(sha256sum "$compose_file" | awk '{print $1}')"
caddy_sha_before="$(sha256sum "$caddy_file" | awk '{print $1}')"
env_sha_before="$(sha256sum "$env_file" | awk '{print $1}')"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$backup_root/legacy-flat-$stamp"
[[ ! -e "$backup_dir" ]] || die "legacy backup destination already exists"
mkdir -m 0700 -- "$backup_dir"
mv -- "$runtime_directories_file" "$backup_dir/runtime-directories.txt"
runtime_directories_file=""

for service in "${EXPECTED_SERVICES[@]}"; do
  recovery_tag="axio7-legacy-recovery-$service:$stamp"
  if docker image inspect "$recovery_tag" >/dev/null 2>&1; then
    die "refusing to overwrite an existing legacy recovery tag"
  fi
  docker image tag "${IMAGE_IDS[$service]}" "$recovery_tag"
  RECOVERY_TAGS["$service"]="$recovery_tag"
done

printf 'legacy-backup: quiescing the exact four-service flat deployment\n'
quiesced=true
for service in "${STOP_ORDER[@]}"; do
  docker stop --time 60 "${CONTAINER_IDS[$service]}" >/dev/null \
    || die "failed to stop legacy service: $service"
done
running_project_ids="$(
  docker ps -q --filter label=com.docker.compose.project=axio7
)" || die "cannot verify legacy service quiescence"
[[ -z "$running_project_ids" ]] \
  || die "a legacy project container is still running after quiesce"
for service in "${EXPECTED_SERVICES[@]}"; do
  running="$(
    docker inspect --format '{{.State.Running}}' "${CONTAINER_IDS[$service]}"
  )"
  [[ "$running" == "false" ]] \
    || die "legacy service is still running after quiesce: $service"
done
for volume_name in "${REQUIRED_VOLUMES[@]}"; do
  volume_is_detached "$volume_name" \
    || die "cannot prove the quiesced volume is detached: $volume_name"
done

install -m 0600 -- "$env_file" "$backup_dir/.env.server.legacy"
install -m 0600 -- "$compose_file" "$backup_dir/compose.legacy.yaml"
install -m 0600 -- "$caddy_file" "$backup_dir/Caddyfile.legacy"
[[ "$(sha256sum "$compose_file" | awk '{print $1}')" == "$compose_sha_before" \
  && "$(sha256sum "$caddy_file" | awk '{print $1}')" == "$caddy_sha_before" \
  && "$(sha256sum "$env_file" | awk '{print $1}')" == "$env_sha_before" ]] \
  || die "flat deployment configuration changed during quiesce"

cat > "$backup_dir/legacy.env" <<EOF
SCHEMA_VERSION=axio.legacy-flat-migration-backup.v1
DEPLOYMENT_DIR=$deployment_dir
DOCKER_COMPOSE_VERSION=$compose_version
APPLICATION_OCI_REVISION=$application_oci_revision
QUANTD_CONTAINER_ID=${CONTAINER_IDS[quantd]}
WEB_CONTAINER_ID=${CONTAINER_IDS[web]}
CADDY_CONTAINER_ID=${CONTAINER_IDS[caddy]}
SCHEDULER_CONTAINER_ID=${CONTAINER_IDS[monitor-scheduler]}
QUANTD_COMPOSE_CONFIG_HASH=${CONFIG_HASHES[quantd]}
WEB_COMPOSE_CONFIG_HASH=${CONFIG_HASHES[web]}
CADDY_COMPOSE_CONFIG_HASH=${CONFIG_HASHES[caddy]}
SCHEDULER_COMPOSE_CONFIG_HASH=${CONFIG_HASHES[monitor-scheduler]}
QUANTD_IMAGE_ID=${IMAGE_IDS[quantd]}
WEB_IMAGE_ID=${IMAGE_IDS[web]}
CADDY_IMAGE_ID=${IMAGE_IDS[caddy]}
SCHEDULER_IMAGE_ID=${IMAGE_IDS[monitor-scheduler]}
QUANTD_IMAGE_REFERENCE=${IMAGE_REFERENCES[quantd]}
WEB_IMAGE_REFERENCE=${IMAGE_REFERENCES[web]}
CADDY_IMAGE_REFERENCE=${IMAGE_REFERENCES[caddy]}
SCHEDULER_IMAGE_REFERENCE=${IMAGE_REFERENCES[monitor-scheduler]}
QUANTD_RECOVERY_TAG=${RECOVERY_TAGS[quantd]}
WEB_RECOVERY_TAG=${RECOVERY_TAGS[web]}
CADDY_RECOVERY_TAG=${RECOVERY_TAGS[caddy]}
SCHEDULER_RECOVERY_TAG=${RECOVERY_TAGS[monitor-scheduler]}
EOF

archive_volume \
  axio7_quant-state quant-state.tgz \
  quant-state-files.sha256 quant-state-directories.txt
archive_volume \
  axio7_quant-live quant-live.tgz \
  quant-live-files.sha256 quant-live-directories.txt
archive_volume \
  axio7_caddy-data caddy-data.tgz \
  caddy-data-files.sha256 caddy-data-directories.txt
archive_volume \
  axio7_caddy-config caddy-config.tgz \
  caddy-config-files.sha256 caddy-config-directories.txt

docker run --rm --pull never --user 0:0 --network none --entrypoint /bin/sh \
  --mount type=volume,src=axio7_quant-state,dst=/source,readonly \
  "$helper_image_id" -ec '
    cd /source
    find . -type f \( \
      -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" \
      -o -name "*-wal" -o -name "*-shm" -o -name "*-journal" \
    \) -print | LC_ALL=C sort
  ' > "$backup_dir/quant-state-sqlite-family-files.txt"
[[ -s "$backup_dir/quant-state-sqlite-family-files.txt" ]] \
  || die "quant-state contains no SQLite-family file to recover"

(
  cd -- "$runtime_dir"
  find . -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 -r sha256sum
) > "$backup_dir/runtime-files.sha256"
[[ -s "$backup_dir/runtime-files.sha256" ]] \
  || die "legacy runtime contains no recoverable files"
(
  cd -- "$runtime_dir"
  find . -type d -print | LC_ALL=C sort
) > "$backup_dir/runtime-tree-directories.txt"
runtime_tree_matches_manifest \
  "$runtime_dir" \
  "$backup_dir/runtime-files.sha256" \
  "$backup_dir/runtime-files.source-observed.sha256" \
  "$backup_dir/runtime-directories.txt" \
  || die "legacy runtime tree changed before archive creation"
mapfile -t present_runtime_directories \
  < "$backup_dir/runtime-directories.txt"
tar --hard-dereference -C "$runtime_dir" \
  -czf "$backup_dir/runtime-binds.tgz" \
  "${present_runtime_directories[@]}"
runtime_tree_matches_manifest \
  "$runtime_dir" \
  "$backup_dir/runtime-files.sha256" \
  "$backup_dir/runtime-files.source-after.sha256" \
  "$backup_dir/runtime-directories.txt" \
  || die "legacy runtime tree changed while it was archived"
(
  cd -- "$runtime_dir"
  find . -type d -print | LC_ALL=C sort
) > "$backup_dir/runtime-tree-directories.source-after.txt"
cmp --silent \
  "$backup_dir/runtime-tree-directories.txt" \
  "$backup_dir/runtime-tree-directories.source-after.txt" \
  || die "legacy runtime directory tree changed while it was archived"
rm -f -- \
  "$backup_dir/runtime-files.source-observed.sha256" \
  "$backup_dir/runtime-files.source-after.sha256" \
  "$backup_dir/runtime-tree-directories.source-after.txt"

preflight_dir="$(mktemp -d "$backup_root/.legacy-preflight.XXXXXX")"
chmod 0700 -- "$preflight_dir"
for archive_name in \
  quant-state.tgz quant-live.tgz caddy-data.tgz caddy-config.tgz \
  runtime-binds.tgz; do
  assert_safe_archive \
    "$backup_dir/$archive_name" \
    "$preflight_dir/$archive_name.members" \
    "$preflight_dir/$archive_name.verbose-members"
done
assert_safe_runtime_archive "$preflight_dir/runtime-binds.tgz.members"

preflight_volume_archive \
  quant-state.tgz quant-state-files.sha256 quant-state-directories.txt
preflight_volume_archive \
  quant-live.tgz quant-live-files.sha256 quant-live-directories.txt
preflight_volume_archive \
  caddy-data.tgz caddy-data-files.sha256 caddy-data-directories.txt
preflight_volume_archive \
  caddy-config.tgz caddy-config-files.sha256 caddy-config-directories.txt
mkdir -m 0700 -- "$preflight_dir/runtime"
tar -xzf "$backup_dir/runtime-binds.tgz" -C "$preflight_dir/runtime"
runtime_tree_matches_manifest \
  "$preflight_dir/runtime" \
  "$backup_dir/runtime-files.sha256" \
  "$preflight_dir/runtime-files.observed.sha256" \
  "$backup_dir/runtime-directories.txt" \
  || die "extracted runtime archive differs from the source tree"
(
  cd -- "$preflight_dir/runtime"
  find . -type d -print | LC_ALL=C sort
) > "$preflight_dir/runtime-tree-directories.observed.txt"
cmp --silent \
  "$backup_dir/runtime-tree-directories.txt" \
  "$preflight_dir/runtime-tree-directories.observed.txt" \
  || die "extracted runtime archive omits or adds a directory"

install -m 0700 -- \
  "$script_dir/production-legacy-flat-migration-restore.sh" \
  "$backup_dir/restore-legacy-flat.sh"
cat > "$backup_dir/RECOVERY.txt" <<EOF
The legacy containers and exact image IDs remain on this host.
To restore this checksum-sealed bundle after a failed cutover, first ensure no
axio7 Compose container is running, then run:

  bash "$backup_dir/restore-legacy-flat.sh" \\
    --deployment-dir /opt/axio7 \\
    --backup-dir "$backup_dir" \\
    --confirm-legacy-restore

The restore helper validates every checksum/archive/image before overwriting a
fixed AXIO7 volume. It creates a separate pre-restore emergency snapshot and
never deletes or prunes images, volumes, backups, Paddle data, or secrets.
EOF

cat > "$backup_dir/backup-manifest.json" <<EOF
{
  "schema_version": "axio.legacy-flat-migration-backup.v1",
  "created_at": "$stamp",
  "deployment_dir": "/opt/axio7",
  "docker_compose_version": "$compose_version",
  "compose_project": "axio7",
  "service_count": 4,
  "quantd_container_id": "${CONTAINER_IDS[quantd]}",
  "web_container_id": "${CONTAINER_IDS[web]}",
  "caddy_container_id": "${CONTAINER_IDS[caddy]}",
  "scheduler_container_id": "${CONTAINER_IDS[monitor-scheduler]}",
  "quantd_compose_config_hash": "${CONFIG_HASHES[quantd]}",
  "web_compose_config_hash": "${CONFIG_HASHES[web]}",
  "caddy_compose_config_hash": "${CONFIG_HASHES[caddy]}",
  "scheduler_compose_config_hash": "${CONFIG_HASHES[monitor-scheduler]}",
  "quantd_image_id": "${IMAGE_IDS[quantd]}",
  "web_image_id": "${IMAGE_IDS[web]}",
  "caddy_image_id": "${IMAGE_IDS[caddy]}",
  "scheduler_image_id": "${IMAGE_IDS[monitor-scheduler]}",
  "application_oci_revision_labels_absent": $application_oci_revision_labels_absent,
  "application_oci_revision": $application_oci_revision_json,
  "complete_volume_set": true,
  "sqlite_wal_captured_as_complete_quiesced_volume": true,
  "runtime_tree_exactly_manifested": true,
  "runtime_hardlinks_dereferenced": true,
  "services_left_stopped": true,
  "execution_enabled": false,
  "environment_contents_printed": false
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
verify_final_quiesced_sources \
  || die "legacy sources or stopped-service state changed before final seal"

backup_complete=true
printf 'legacy-backup: sealed one-time migration bundle: %s\n' "$backup_dir"
printf 'legacy-backup: all four legacy services remain stopped for cutover\n'
printf 'legacy-backup: recovery command is recorded in %s/RECOVERY.txt\n' \
  "$backup_dir"
