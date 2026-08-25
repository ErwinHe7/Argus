#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
audit="$repository_root/scripts/check-member-provider-boundaries.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/ritual-provider-audit.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

mkdir -p \
  "$fixture/ritual-investing-app/lib" \
  "$fixture/ritual-investing-app/android/app" \
  "$fixture/ritual-investing-app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm" \
  "$fixture/ritual-investing-api/src/jobs"

write_allowed_fixture() {
  cat >"$fixture/ritual-investing-app/pubspec.yaml" <<'EOF'
dependencies:
  flutter:
    sdk: flutter
  auth0_flutter: ^2.6.0
  dio: ^5.9.2
EOF
  cat >"$fixture/ritual-investing-api/package.json" <<'EOF'
{"dependencies":{"hono":"4.13.3","jose":"6.2.10"}}
EOF
  cat >"$fixture/ritual-investing-app/android/settings.gradle.kts" <<'EOF'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
EOF
  cat >"$fixture/ritual-investing-app/android/build.gradle.kts" <<'EOF'
allprojects { repositories { google(); mavenCentral() } }
EOF
  cat >"$fixture/ritual-investing-app/android/app/build.gradle.kts" <<'EOF'
plugins { id("com.android.application") }
EOF
  cat >"$fixture/ritual-investing-app/ios/Podfile" <<'EOF'
platform :ios, '15.0'
EOF
  cat >"$fixture/ritual-investing-app/ios/Podfile.lock" <<'EOF'
PODS:
  - Auth0 (2.10.0)
EOF
  cat >"$fixture/ritual-investing-app/ios/Runner.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
EOF
  cat >"$fixture/ritual-investing-app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" <<'EOF'
{"pins":[{"identity":"auth0.swift","location":"https://github.com/auth0/Auth0.swift.git"}],"version":3}
EOF
  cat >"$fixture/ritual-investing-app/lib/runtime.dart" <<'EOF'
const apiOrigin = 'https://api.just-build-this.app';
const authOrigin = 'https://tenant.us.auth0.com';
EOF
  cat >"$fixture/ritual-investing-api/src/index.ts" <<'EOF'
const worker = {
  fetch(request, environment, executionContext) {
    if (new URL(request.url).pathname.startsWith("/v1/"))
      return app.fetch(request, bindings, executionContext);
    if (bindings.ADMIN_ASSETS !== undefined)
      return bindings.ADMIN_ASSETS.fetch(request).then((response) =>
        secureAdminAsset(response),
      );
    return app.fetch(request, bindings, executionContext);
  },
};
EOF
  cat >"$fixture/ritual-investing-api/src/jobs/handlers.ts" <<'EOF'
async function dependencyFetch(
  fetcher: Fetcher,
  input: string,
  init: RequestInit,
): Promise<Response> {
  return await fetcher.fetch(input, {
    ...init,
    signal: AbortSignal.timeout(10_000),
  });
}

const push = dependencyFetch(
  environment.PUSH_PROVIDER,
  "https://push-provider.internal/v1/send",
  {},
);
const scan = dependencyFetch(
  environment.MEDIA_SCANNER,
  "https://media-scanner.internal/v1/scan",
  {},
);
const process = dependencyFetch(
  environment.MEDIA_PROCESSOR,
  "https://media-processor.internal/v1/rasterize",
  {},
);
EOF
  cat >"$fixture/ritual-investing-api/src/jobs/queue-consumer.ts" <<'EOF'
import { z } from "zod";
export const queueConsumerSchema = z.enum([
  "briefing-builder",
  "notification-writer",
  "recurring-plan-delivery",
  "privacy-export",
  "privacy-purge",
]);
EOF
  cat >"$fixture/ritual-investing-api/wrangler.jsonc" <<'EOF'
{"vars":{"KILL_SWITCH_NOTIFICATION_DELIVERY":"on","KILL_SWITCH_MEDIA":"on"}}
EOF
  cp "$fixture/ritual-investing-api/wrangler.jsonc" \
    "$fixture/ritual-investing-api/wrangler.beta.jsonc"
}

expect_failure() {
  label=$1
  if RITUAL_PROVIDER_AUDIT_ROOT="$fixture" "$audit" >"$fixture/output" 2>&1; then
    echo "expected provider audit to reject $label" >&2
    exit 1
  fi
}

write_allowed_fixture
RITUAL_PROVIDER_AUDIT_ROOT="$fixture" "$audit" >"$fixture/output"
grep -F "provider boundary audit passed" "$fixture/output" >/dev/null

printf '\n  stripe_sdk: ^1.0.0\n' >>"$fixture/ritual-investing-app/pubspec.yaml"
expect_failure "a prohibited Flutter dependency"

write_allowed_fixture
printf '\ndependencies { implementation("com.stripe:stripe-android:21.0.0") }\n' \
  >>"$fixture/ritual-investing-app/android/app/build.gradle.kts"
expect_failure "a prohibited Gradle dependency"

write_allowed_fixture
printf "\npod 'Plaid', '~> 5.0'\n" >>"$fixture/ritual-investing-app/ios/Podfile"
expect_failure "a prohibited CocoaPods dependency"

write_allowed_fixture
printf '\nproductName = RevenueCat;\n' \
  >>"$fixture/ritual-investing-app/ios/Runner.xcodeproj/project.pbxproj"
expect_failure "a prohibited Xcode package dependency"

write_allowed_fixture
cat >"$fixture/ritual-investing-app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" <<'EOF'
{"pins":[{"identity":"onesignal","location":"https://github.com/OneSignal/OneSignal-XCFramework.git"}],"version":3}
EOF
expect_failure "a prohibited SwiftPM dependency"

write_allowed_fixture
printf "const endpoint = 'https://api.plaid.com/link';\n" \
  >>"$fixture/ritual-investing-app/lib/runtime.dart"
expect_failure "a prohibited egress host"

write_allowed_fixture
printf "const endpoint = 'https://unreviewed-provider.example/send';\n" \
  >>"$fixture/ritual-investing-app/lib/runtime.dart"
expect_failure "an unreviewed literal egress host"

write_allowed_fixture
cat >"$fixture/ritual-investing-api/src/jobs/queue-consumer.ts" <<'EOF'
import { z } from "zod";
export const queueConsumerSchema = z.enum([
  "briefing-builder",
  "bank-transfer",
]);
EOF
expect_failure "an unknown worker effect"

write_allowed_fixture
cat >"$fixture/ritual-investing-api/src/jobs/queue-consumer.ts" <<'EOF'
import { z } from "zod";
export const workerEffectSchema = z.enum([
  "briefing-builder",
]);
EOF
expect_failure "an empty parsed worker-effect allowlist"

write_allowed_fixture
cat >>"$fixture/ritual-investing-api/src/jobs/handlers.ts" <<'EOF'
const providerName = "BROKER_PROVIDER";
const provider = environment[providerName];
const response = await provider.fetch("https://broker-provider.internal/v1/account");
EOF
expect_failure "a dynamically addressed Fetcher binding"

write_allowed_fixture
cat >>"$fixture/ritual-investing-api/src/jobs/handlers.ts" <<'EOF'
const dynamicProvider = dependencyFetch(
  environment.BROKER_PROVIDER,
  "https://broker-provider.internal/v1/account",
  {},
);
EOF
expect_failure "an unreviewed dependencyFetch binding"

write_allowed_fixture
sed 's/KILL_SWITCH_NOTIFICATION_DELIVERY":"on/KILL_SWITCH_NOTIFICATION_DELIVERY":"off/' \
  "$fixture/ritual-investing-api/wrangler.beta.jsonc" \
  >"$fixture/ritual-investing-api/wrangler.beta.next"
mv "$fixture/ritual-investing-api/wrangler.beta.next" \
  "$fixture/ritual-investing-api/wrangler.beta.jsonc"
expect_failure "external notification delivery activation"

echo "provider boundary audit regression tests passed"
