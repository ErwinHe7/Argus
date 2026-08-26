#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
audit="$repository_root/scripts/check-demo-provider-boundaries.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/ritual-demo-boundary.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

write_allowed_fixture() {
  rm -rf "$fixture/ritual-investing-app" "$fixture/ritual-investing-demo"
  mkdir -p \
    "$fixture/ritual-investing-app/lib/core/bootstrap" \
    "$fixture/ritual-investing-app/lib/core/navigation" \
    "$fixture/ritual-investing-app/tool" \
    "$fixture/ritual-investing-demo/lib" \
    "$fixture/ritual-investing-demo/web" \
    "$fixture/ritual-investing-demo/build/web"

  cp "$repository_root/ritual-investing-app/tool/check_demo_import_boundary.dart" \
    "$fixture/ritual-investing-app/tool/check_demo_import_boundary.dart"
  cat >"$fixture/ritual-investing-app/lib/core/bootstrap/app_runtime.dart" <<'EOF'
export 'member_shell_runtime.dart';
EOF
  cat >"$fixture/ritual-investing-app/lib/core/bootstrap/member_shell_runtime.dart" <<'EOF'
import '../navigation/member_app_router.dart';
const memberShell = safeRouter;
EOF
  cat >"$fixture/ritual-investing-app/lib/core/navigation/member_app_router.dart" <<'EOF'
const safeRouter = 'memory-only-demo';
EOF
  cat >"$fixture/ritual-investing-demo/pubspec.yaml" <<'EOF'
name: ritual_investing_demo
dependencies:
  flutter:
    sdk: flutter
  ritual_investing_app:
    path: ../ritual-investing-app
EOF
  cat >"$fixture/ritual-investing-demo/lib/main.dart" <<'EOF'
const demoMode = 'canonical-memory-fixtures';
EOF
  cat >"$fixture/ritual-investing-demo/web/index.html" <<'EOF'
<!doctype html><script src="flutter_bootstrap.js"></script>
EOF
  cat >"$fixture/ritual-investing-demo/build/web/index.html" <<'EOF'
<!doctype html><script src="flutter_bootstrap.js"></script>
EOF
  cat >"$fixture/ritual-investing-demo/build/web/flutter_bootstrap.js" <<'EOF'
_flutter.buildConfig = {"builds":[{"mainJsPath":"main.dart.js"}],"wasmHashes":{},"useLocalCanvasKit":true};
_flutter.loader.load({serviceWorkerSettings: null});
EOF
  cat >"$fixture/ritual-investing-demo/build/web/main.dart.js" <<'EOF'
console.log('provider-free-demo');
EOF
  : >"$fixture/ritual-investing-demo/build/web/flutter_service_worker.js"
}

expect_failure() {
  label=$1
  if RITUAL_DEMO_AUDIT_ROOT="$fixture" RITUAL_DEMO_MAX_ASSET_BYTES=512 \
    "$audit" >"$fixture/output" 2>&1; then
    echo "expected demo provider boundary to reject $label" >&2
    exit 1
  fi
}

write_allowed_fixture
RITUAL_DEMO_AUDIT_ROOT="$fixture" RITUAL_DEMO_MAX_ASSET_BYTES=512 \
  "$audit" >"$fixture/output"
grep -F "demo provider boundary audit passed" "$fixture/output" >/dev/null

write_allowed_fixture
printf "import 'package:auth0_flutter/auth0_flutter.dart';\n" \
  >>"$fixture/ritual-investing-app/lib/core/navigation/member_app_router.dart"
expect_failure "a forbidden transitive provider import"

write_allowed_fixture
printf "const endpoint = 'https://api.just-build-this.app/v1/session/bootstrap';\n" \
  >>"$fixture/ritual-investing-demo/lib/main.dart"
expect_failure "a member API hostname"

write_allowed_fixture
printf "final state = window.localStorage;\n" \
  >>"$fixture/ritual-investing-app/lib/core/navigation/member_app_router.dart"
expect_failure "persistent browser storage in the demo source graph"

write_allowed_fixture
printf "https://tenant.us.auth0.com/authorize\n" \
  >>"$fixture/ritual-investing-demo/build/web/main.dart.js"
expect_failure "a provider identifier in the release artifact"

write_allowed_fixture
printf '{}\n' >"$fixture/ritual-investing-demo/build/web/main.dart.js.map"
expect_failure "a public source map"

write_allowed_fixture
printf "self.addEventListener('fetch', function () {});\n" \
  >"$fixture/ritual-investing-demo/build/web/flutter_service_worker.js"
expect_failure "a demo service worker"

write_allowed_fixture
printf '<script src="https://cdn.example.invalid/flutter.js"></script>\n' \
  >"$fixture/ritual-investing-demo/build/web/index.html"
expect_failure "an external runtime asset"

write_allowed_fixture
printf '%0513d' 0 >"$fixture/ritual-investing-demo/build/web/oversized.bin"
expect_failure "an oversized asset"

echo "demo provider boundary regression tests passed"
