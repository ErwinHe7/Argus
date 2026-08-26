#!/bin/sh
set -eu

repository_root=${RITUAL_DEMO_AUDIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
repository_root=$(CDPATH= cd -- "$repository_root" && pwd)
app_root="$repository_root/ritual-investing-app"
demo_root="$repository_root/ritual-investing-demo"
build_root=${RITUAL_DEMO_BUILD_ROOT:-$demo_root/build/web}
maximum_asset_bytes=26214400
if test -n "${RITUAL_DEMO_AUDIT_ROOT:-}"; then
  maximum_asset_bytes=${RITUAL_DEMO_MAX_ASSET_BYTES:-$maximum_asset_bytes}
fi

fail() {
  echo "demo provider boundary audit failed: $*" >&2
  exit 1
}

case "$maximum_asset_bytes" in
  ''|*[!0-9]*) fail "maximum asset bytes must be a positive integer" ;;
esac
test "$maximum_asset_bytes" -gt 0 || fail "maximum asset bytes must be positive"
command -v dart >/dev/null 2>&1 || fail "dart is required"
command -v rg >/dev/null 2>&1 || fail "ripgrep (rg) is required"

for required in \
  "$app_root/tool/check_demo_import_boundary.dart" \
  "$demo_root/pubspec.yaml" \
  "$demo_root/lib" \
  "$demo_root/web" \
  "$build_root" \
  "$build_root/index.html" \
  "$build_root/flutter_bootstrap.js" \
  "$build_root/main.dart.js"; do
  test -e "$required" || fail "missing required audit input ${required#"$repository_root"/}"
done

(cd "$app_root" && dart tool/check_demo_import_boundary.dart)

source_pattern='auth0_flutter|flutter_secure_storage|path_provider|ritual_investing_api_client|@neondatabase/serverless|drizzle-orm|postgres(?:ql)?://|api(?:-beta)?\.just-build-this\.app|/v1/session/bootstrap|window\.(?:localStorage|sessionStorage|indexedDB)|globalThis\.(?:localStorage|sessionStorage|indexedDB)'
if rg -n -i "$source_pattern" "$demo_root/lib" "$demo_root/web" "$demo_root/pubspec.yaml"; then
  fail "demo-owned sources contain a provider, member API, database, or persistent-state boundary violation"
fi

if find "$build_root" -type l -print | grep . >/dev/null; then
  fail "release assets contain a symbolic link"
fi
if find "$build_root" -type f -name '*.map' -print | grep . >/dev/null; then
  fail "release assets contain a public source map"
fi
if test -s "$build_root/flutter_service_worker.js"; then
  fail "release assets contain an enabled Flutter service worker"
fi
if rg -n -i "(?:src|href)=[\"'](?:https?:)?//" "$build_root/index.html"; then
  fail "the demo entry document references an external runtime asset"
fi
rg -F '"useLocalCanvasKit":true' "$build_root/flutter_bootstrap.js" >/dev/null || \
  fail "Flutter runtime assets are not pinned to the local build"
rg -F 'serviceWorkerSettings: null' "$build_root/flutter_bootstrap.js" >/dev/null || \
  fail "Flutter service-worker registration is not disabled"

artifact_pattern='auth0|api(?:-beta)?\.just-build-this\.app|/v1/session/bootstrap|@neondatabase/serverless|drizzle-orm|postgres(?:ql)?://|flutter_secure_storage|path_provider|ritual_investing_api_client'
if rg -a -n -i "$artifact_pattern" "$build_root" --glob '!*.symbols' --glob '!flutter_service_worker.js'; then
  fail "release artifacts contain a production provider, member API, or database identifier"
fi

find "$build_root" -type f -print | while IFS= read -r asset; do
  bytes=$(wc -c <"$asset" | tr -d ' ')
  if test "$bytes" -gt "$maximum_asset_bytes"; then
    fail "asset exceeds the 25 MiB deployment limit: ${asset#"$build_root"/}"
  fi
done

echo "demo provider boundary audit passed: transitive sources and release artifacts are provider-free and ephemeral"
