#!/bin/sh
set -eu

audit_root=${RITUAL_PROVIDER_AUDIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
audit_root=$(CDPATH= cd -- "$audit_root" && pwd)

fail() {
  echo "provider boundary audit failed: $*" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "ripgrep (rg) is required"

# Browsers and portable domain code never contact Webull. The only reviewed
# literal provider origins live in the server-side Edge contract module.
webull_contract="$audit_root/supabase/functions/_shared/webull/contract.ts"
test -f "$webull_contract" || fail "missing reviewed server-side Webull contract"
if rg -n -i 'https?://[^"'"'"'[:space:]]*webull\.(?:com|cn)' \
  "$audit_root/ritual-investing-app/lib" \
  "$audit_root/ritual-investing-demo/lib" \
  "$audit_root/ritual-investing-api/src"; then
  fail "a browser or portable API module contains direct Webull egress"
fi
webull_literals=$(rg -o -N --no-filename 'https://[^"'"'"'[:space:]]*webull\.com' \
  "$audit_root/supabase/functions" --glob '*.ts' --glob '!*.test.ts' || true)
test "$(printf '%s\n' "$webull_literals" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')" -eq 3 || \
  fail "server Webull literal-host allowlist drifted"
for required_webull_origin in \
  'https://passport.webull.com' \
  'https://oauth-open-api.sandbox.webull.com' \
  'https://us-oauth-open-api.webull.com'; do
  printf '%s\n' "$webull_literals" | grep -Fx "$required_webull_origin" >/dev/null || \
    fail "missing reviewed Webull origin $required_webull_origin"
done
if rg -n 'createWebullClient\(' "$audit_root/supabase/functions" \
  --glob '*.ts' --glob '!*.test.ts' --glob '!**/_shared/webull/client.ts'; then
  fail "real Webull egress is initialized before the partner contract gate is opened"
fi

app_manifest="$audit_root/ritual-investing-app/pubspec.yaml"
api_manifest="$audit_root/ritual-investing-api/package.json"
queue_contract="$audit_root/ritual-investing-api/src/jobs/queue-consumer.ts"
api_entrypoint="$audit_root/ritual-investing-api/src/index.ts"
job_handlers="$audit_root/ritual-investing-api/src/jobs/handlers.ts"

for required in \
  "$app_manifest" \
  "$api_manifest" \
  "$queue_contract" \
  "$api_entrypoint" \
  "$job_handlers"; do
  test -f "$required" || fail "missing required audit input ${required#"$audit_root"/}"
done

dependency_inputs="$app_manifest $api_manifest"
for native_manifest_or_lock in \
  "$audit_root/ritual-investing-app/pubspec.lock" \
  "$audit_root/ritual-investing-api/package-lock.json" \
  "$audit_root/ritual-investing-app/android/settings.gradle" \
  "$audit_root/ritual-investing-app/android/settings.gradle.kts" \
  "$audit_root/ritual-investing-app/android/build.gradle" \
  "$audit_root/ritual-investing-app/android/build.gradle.kts" \
  "$audit_root/ritual-investing-app/android/app/build.gradle" \
  "$audit_root/ritual-investing-app/android/app/build.gradle.kts" \
  "$audit_root/ritual-investing-app/android/gradle/libs.versions.toml" \
  "$audit_root/ritual-investing-app/ios/Podfile" \
  "$audit_root/ritual-investing-app/ios/Podfile.lock" \
  "$audit_root/ritual-investing-app/ios/Runner.xcodeproj/project.pbxproj" \
  "$audit_root/ritual-investing-app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
  "$audit_root/ritual-investing-app/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"; do
  if test -f "$native_manifest_or_lock"; then
    dependency_inputs="$dependency_inputs $native_manifest_or_lock"
  fi
done

prohibited_dependencies='flutter_stripe|stripe_sdk|stripe|plaid_flutter|plaid|braintree|paypal|square_in_app_payments|alpaca|snaptrade|coinmarketcap|firebase_messaging|onesignal_flutter|onesignal|braze_plugin|braze|purchases_flutter|revenuecat|in_app_purchase'
# The delimiters cover Dart/npm names plus native coordinates and manifests,
# such as `com.stripe:stripe-android`, `pod 'Plaid'`, and PBX product names.
# shellcheck disable=SC2086
if rg -n -i "(^|[\"'[:space:]/_.-])($prohibited_dependencies)([\"'[:space:]/_.:;(),-]|$)" $dependency_inputs; then
  fail "a bank, broker, payment, market-data, purchase, or push SDK is present"
fi

production_inputs=""
for directory in \
  "$audit_root/ritual-investing-app/lib" \
  "$audit_root/ritual-investing-app/android/app/src/main" \
  "$audit_root/ritual-investing-app/ios/Runner" \
  "$audit_root/ritual-investing-api/src"; do
  if test -d "$directory"; then
    production_inputs="$production_inputs $directory"
  fi
done

prohibited_hosts='api\.plaid\.com|sandbox\.plaid\.com|api\.stripe\.com|api\.braintreegateway\.com|api-m\.paypal\.com|api\.paypal\.com|paper-api\.alpaca\.markets|api\.alpaca\.markets|api\.snaptrade\.com|pro-api\.coinmarketcap\.com|api\.coinmarketcap\.com|api\.onesignal\.com|fcm\.googleapis\.com'
# shellcheck disable=SC2086
if test -n "$production_inputs" && \
  rg -n -i "https?://[^\"'[:space:]]*($prohibited_hosts)" $production_inputs \
    --glob '!**/generated/**' --glob '!**/*.g.dart'; then
  fail "a prohibited provider egress host is present in production code"
fi

# Literal production URLs are fail-closed. Runtime-supplied API/Auth0/Access
# values are validated by their typed configuration seams and do not appear in
# this list; a new literal must be reviewed here before it can ship.
# shellcheck disable=SC2086
literal_urls=$(rg -o -N --no-filename "https?://[^\"'[:space:]<>),;\x60]+" \
  $production_inputs --glob '!**/generated/**' --glob '!**/*.g.dart' || true)
printf '%s\n' "$literal_urls" | while IFS= read -r literal_url; do
  test -n "$literal_url" || continue
  literal_host=${literal_url#*://}
  literal_host=${literal_host%%/*}
  case "$literal_host" in
    YOUR_AUTH0_DOMAIN|PROJECT_REF.supabase.co|api.just-build-this.app|api.ritual-investing.example|research.ritual-investing.test|ritual-investing.app|schemas.android.com|developer.android.com|www.apple.com|media-processor.internal|media-scanner.internal|push-provider.internal)
      ;;
    # Frame messages are reviewed as an exact production/beta pair. Do not
    # broaden this to a wildcard subdomain allowlist.
    just-build-this.app|beta.just-build-this.app)
      ;;
    *.auth0.com)
      ;;
    *) fail "unreviewed literal production host: $literal_host" ;;
  esac
done

# Runtime egress is allowlisted by exact callsite shape, service binding, and
# internal URL. A whole-file exemption would let an unrelated or dynamically
# addressed provider call inherit approval merely by being placed in one of
# these files.
api_fetch_occurrences=$(
  rg -o -N '\.fetch\(|(^|[^[:alnum:]_])fetch\(' \
    "$audit_root/ritual-investing-api/src" \
    --glob '*.ts' --glob '!**/generated/**' || true
)
api_fetch_count=$(printf '%s\n' "$api_fetch_occurrences" | sed '/^$/d' | wc -l | tr -d ' ')
test "$api_fetch_count" -eq 4 || \
  fail "expected 4 reviewed API entrypoint/static-asset fetch occurrences, found $api_fetch_count"

worker_handler_count=$(
  rg --count-matches '^  fetch\(request, environment, executionContext\) \{$' \
    "$api_entrypoint" || true
)
app_dispatch_count=$(
  rg --count-matches '^[[:space:]]*return app\.fetch\(request, bindings, executionContext\);$' \
    "$api_entrypoint" || true
)
admin_assets_count=$(
  rg --count-matches '^[[:space:]]*return bindings\.ADMIN_ASSETS\.fetch\(request\)\.then\(\(response\) =>$' \
    "$api_entrypoint" || true
)
test "${worker_handler_count:-0}" -eq 1 || \
  fail "Worker fetch handler no longer matches its reviewed callsite"
test "${app_dispatch_count:-0}" -eq 2 || \
  fail "Hono app dispatches no longer match their 2 reviewed callsites"
test "${admin_assets_count:-0}" -eq 1 || \
  fail "ADMIN_ASSETS fetch no longer matches its reviewed callsite"
if rg -n 'dependencyFetch\(|PUSH_PROVIDER|MEDIA_SCANNER|MEDIA_PROCESSOR' \
  "$job_handlers"; then
  fail "portable API job handlers regained direct provider egress"
fi

rg -q 'event_id: z\.string\(\)\.uuid\(\)' "$queue_contract" || \
  fail "queue messages must remain opaque event identifiers"
if rg -n 'consumer|email|token|provider' "$queue_contract"; then
  fail "queue transport exposes a provider or consumer-selected effect"
fi

api_edge="$audit_root/supabase/functions/api/index.ts"
worker_edge="$audit_root/supabase/functions/worker/index.ts"
for required in "$api_edge" "$worker_edge"; do
  test -f "$required" || fail "missing Edge provider gate ${required#"$audit_root"/}"
done
rg -q 'createBlockedWebullProvider' "$api_edge" || \
  fail "API Edge must keep Webull authorization egress fail-closed"
rg -q 'createBlockedBrokerageProjectionProvider' "$api_edge" || \
  fail "API Edge must keep Webull projection egress fail-closed"
rg -q 'createBlockedBrokerageOrderProvider' "$api_edge" || \
  fail "API Edge must keep Webull order egress fail-closed"
rg -q 'createBlockedWebullRecoveryProvider' "$worker_edge" || \
  fail "worker Edge must keep Webull recovery egress fail-closed"

echo "provider boundary audit passed: member dependencies, hosts, runtime entrypoints, effects, and disabled provider bindings are allowlisted"
