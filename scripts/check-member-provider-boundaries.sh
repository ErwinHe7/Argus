#!/bin/sh
set -eu

audit_root=${RITUAL_PROVIDER_AUDIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
audit_root=$(CDPATH= cd -- "$audit_root" && pwd)

fail() {
  echo "provider boundary audit failed: $*" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "ripgrep (rg) is required"

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
    YOUR_AUTH0_DOMAIN|api.just-build-this.app|api.ritual-investing.example|research.ritual-investing.test|ritual-investing.app|schemas.android.com|developer.android.com|www.apple.com|media-processor.internal|media-scanner.internal|push-provider.internal)
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
test "$api_fetch_count" -eq 5 || \
  fail "expected 5 reviewed API fetch occurrences, found $api_fetch_count"

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
dependency_fetch_count=$(
  rg --count-matches '^[[:space:]]*return await fetcher\.fetch\(input, \{$' \
    "$job_handlers" || true
)
test "${worker_handler_count:-0}" -eq 1 || \
  fail "Worker fetch handler no longer matches its reviewed callsite"
test "${app_dispatch_count:-0}" -eq 2 || \
  fail "Hono app dispatches no longer match their 2 reviewed callsites"
test "${admin_assets_count:-0}" -eq 1 || \
  fail "ADMIN_ASSETS fetch no longer matches its reviewed callsite"
test "${dependency_fetch_count:-0}" -eq 1 || \
  fail "dependency fetch no longer matches its reviewed callsite"

dependency_fetch_occurrences=$(
  rg --count-matches 'dependencyFetch\(' "$job_handlers" || true
)
test "${dependency_fetch_occurrences:-0}" -eq 4 || \
  fail "expected the dependencyFetch definition and 3 reviewed calls"

push_fetch_count=$(
  rg -U --count-matches \
    'dependencyFetch\(\n[[:space:]]*environment\.PUSH_PROVIDER,\n[[:space:]]*"https://push-provider\.internal/v1/send",' \
    "$job_handlers" || true
)
scanner_fetch_count=$(
  rg -U --count-matches \
    'dependencyFetch\(\n[[:space:]]*environment\.MEDIA_SCANNER,\n[[:space:]]*"https://media-scanner\.internal/v1/scan",' \
    "$job_handlers" || true
)
processor_fetch_count=$(
  rg -U --count-matches \
    'dependencyFetch\(\n[[:space:]]*environment\.MEDIA_PROCESSOR,\n[[:space:]]*"https://media-processor\.internal/v1/rasterize",' \
    "$job_handlers" || true
)
test "${push_fetch_count:-0}" -eq 1 || \
  fail "PUSH_PROVIDER fetch binding or URL is not reviewed"
test "${scanner_fetch_count:-0}" -eq 1 || \
  fail "MEDIA_SCANNER fetch binding or URL is not reviewed"
test "${processor_fetch_count:-0}" -eq 1 || \
  fail "MEDIA_PROCESSOR fetch binding or URL is not reviewed"

allowed_consumers=' briefing-builder notification-writer notification-delivery privacy-export privacy-purge media-scan media-cleanup moderation-triage editorial-publisher recurring-plan-delivery privacy-export-retention '
consumer_values=$(
  sed -n '/queueConsumerSchema = z\.enum(/,/]);/p' "$queue_contract" |
    rg -o '"[a-z][a-z0-9-]+"' |
    tr -d '"'
)
test -n "$consumer_values" || fail "queue consumer schema parsed no worker effects"
for consumer in $consumer_values; do
  case "$allowed_consumers" in
    *" $consumer "*) ;;
    *) fail "unreviewed worker effect: $consumer" ;;
  esac
done

for worker_config in \
  "$audit_root/ritual-investing-api/wrangler.jsonc" \
  "$audit_root/ritual-investing-api/wrangler.beta.jsonc"; do
  test -f "$worker_config" || continue
  relative=${worker_config#"$audit_root"/}
  rg -q '"KILL_SWITCH_NOTIFICATION_DELIVERY"[[:space:]]*:[[:space:]]*"on"' \
    "$worker_config" || fail "$relative must keep external notification delivery disabled"
  rg -q '"KILL_SWITCH_MEDIA"[[:space:]]*:[[:space:]]*"on"' \
    "$worker_config" || fail "$relative must keep external media handlers disabled"
  if rg -n '"(PUSH_PROVIDER|MEDIA_SCANNER|MEDIA_PROCESSOR)"[[:space:]]*:' \
    "$worker_config"; then
    fail "$relative configures an external provider service binding"
  fi
done

echo "provider boundary audit passed: member dependencies, hosts, runtime entrypoints, effects, and disabled provider bindings are allowlisted"
