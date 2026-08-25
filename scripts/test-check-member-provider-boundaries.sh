#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
audit="$repository_root/scripts/check-member-provider-boundaries.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/ritual-provider-audit.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

mkdir -p \
  "$fixture/ritual-investing-app/lib" \
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
  cat >"$fixture/ritual-investing-app/lib/runtime.dart" <<'EOF'
const apiOrigin = 'https://api.just-build-this.app';
const authOrigin = 'https://tenant.us.auth0.com';
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
sed 's/KILL_SWITCH_NOTIFICATION_DELIVERY":"on/KILL_SWITCH_NOTIFICATION_DELIVERY":"off/' \
  "$fixture/ritual-investing-api/wrangler.beta.jsonc" \
  >"$fixture/ritual-investing-api/wrangler.beta.next"
mv "$fixture/ritual-investing-api/wrangler.beta.next" \
  "$fixture/ritual-investing-api/wrangler.beta.jsonc"
expect_failure "external notification delivery activation"

echo "provider boundary audit regression tests passed"
