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

for required in "$app_manifest" "$api_manifest" "$queue_contract"; do
  test -f "$required" || fail "missing required audit input ${required#"$audit_root"/}"
done

dependency_inputs="$app_manifest $api_manifest"
for lock_file in \
  "$audit_root/ritual-investing-app/pubspec.lock" \
  "$audit_root/ritual-investing-api/package-lock.json"; do
  if test -f "$lock_file"; then
    dependency_inputs="$dependency_inputs $lock_file"
  fi
done

prohibited_dependencies='flutter_stripe|stripe_sdk|stripe|plaid_flutter|plaid|braintree|paypal|square_in_app_payments|alpaca|snaptrade|coinmarketcap|firebase_messaging|onesignal_flutter|onesignal|braze_plugin|braze|purchases_flutter|revenuecat|in_app_purchase'
# shellcheck disable=SC2086
if rg -n -i "(^|[\"[:space:]/_-])($prohibited_dependencies)([\"[:space:]/_:-]|$)" $dependency_inputs; then
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
    *.auth0.com)
      ;;
    *) fail "unreviewed literal production host: $literal_host" ;;
  esac
done

if test -d "$audit_root/ritual-investing-api/src"; then
  fetch_files=$(rg -l '\.fetch\(|(^|[^[:alnum:]_])fetch\(' \
    "$audit_root/ritual-investing-api/src" \
    --glob '*.ts' --glob '!**/generated/**' || true)
  for fetch_file in $fetch_files; do
    relative=${fetch_file#"$audit_root"/}
    case "$relative" in
      ritual-investing-api/src/index.ts|ritual-investing-api/src/jobs/handlers.ts)
        ;;
      *) fail "unreviewed API runtime network entrypoint: $relative" ;;
    esac
  done
fi

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
