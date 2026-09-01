#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
audit="$repository_root/scripts/check-member-provider-boundaries.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/ritual-provider-audit.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

write_allowed_fixture() {
  rm -rf "$fixture"
  mkdir -p \
    "$fixture/ritual-investing-app/lib" \
    "$fixture/ritual-investing-api/src/jobs" \
    "$fixture/supabase/functions/_shared/webull" \
    "$fixture/supabase/functions/api" \
    "$fixture/supabase/functions/worker" \
    "$fixture/ritual-investing-demo/lib"
  cat >"$fixture/ritual-investing-app/pubspec.yaml" <<'EOF'
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: 2.17.2
  dio: ^5.9.2
EOF
  cat >"$fixture/ritual-investing-api/package.json" <<'EOF'
{"dependencies":{"hono":"4.13.3","jose":"6.2.10"}}
EOF
  cat >"$fixture/ritual-investing-app/lib/runtime.dart" <<'EOF'
const apiOrigin = 'https://api.just-build-this.app';
const authOrigin = 'https://PROJECT_REF.supabase.co';
const stagingFrameOrigin = 'https://staging.just-build-this.app';
EOF
  cat >"$fixture/ritual-investing-demo/lib/main.dart" <<'EOF'
const mode = 'memory-only';
EOF
  cat >"$fixture/ritual-investing-api/src/jobs/handlers.ts" <<'EOF'
export const handlers = Object.freeze({});
export const reviewedEvidenceSources = Object.freeze([
  "https://www.investor.gov/example",
  "https://www.sec.gov/example",
]);
EOF
  cat >"$fixture/ritual-investing-api/src/jobs/queue-consumer.ts" <<'EOF'
import { z } from "zod";
const queueWorkSchema = z.object({
  event_id: z.string().uuid(),
}).strict();
EOF
  cat >"$fixture/supabase/functions/_shared/webull/contract.ts" <<'EOF'
export const authorizationOrigin = "https://passport.webull.com";
export const sandboxOrigin = "https://oauth-open-api.sandbox.webull.com";
export const productionOrigin = "https://us-oauth-open-api.webull.com";
EOF
  cat >"$fixture/supabase/functions/_shared/webull/client.ts" <<'EOF'
export function createWebullClient() { throw new Error("partner gate"); }
EOF
  cat >"$fixture/supabase/functions/api/index.ts" <<'EOF'
createBlockedWebullProvider();
createBlockedBrokerageProjectionProvider();
createBlockedBrokerageOrderProvider();
EOF
  cat >"$fixture/supabase/functions/worker/index.ts" <<'EOF'
createBlockedWebullRecoveryProvider();
EOF
}

expect_failure() {
  label=$1
  if RITUAL_PROVIDER_AUDIT_ROOT="$fixture" "$audit" >"$fixture-output" 2>&1; then
    echo "expected provider audit to reject $label" >&2
    exit 1
  fi
}

write_allowed_fixture
RITUAL_PROVIDER_AUDIT_ROOT="$fixture" "$audit" >"$fixture-output"
grep -F "provider boundary audit passed" "$fixture-output" >/dev/null

printf '\n  stripe_sdk: ^1.0.0\n' >>"$fixture/ritual-investing-app/pubspec.yaml"
expect_failure "a prohibited production SDK"

write_allowed_fixture
printf '\n  auth0_flutter: ^2.6.0\n' >>"$fixture/ritual-investing-app/pubspec.yaml"
expect_failure "retired Auth0 authority"

write_allowed_fixture
printf "const provider = 'https://passport.webull.com/connect';\n" \
  >>"$fixture/ritual-investing-app/lib/runtime.dart"
expect_failure "direct mobile Webull egress"

write_allowed_fixture
printf "const provider = 'https://us-oauth-open-api.webull.com';\n" \
  >>"$fixture/ritual-investing-api/src/jobs/handlers.ts"
expect_failure "portable API Webull egress"

write_allowed_fixture
printf 'export const extra = "https://unreviewed.webull.com";\n' \
  >>"$fixture/supabase/functions/_shared/webull/contract.ts"
expect_failure "an unreviewed server Webull host"

write_allowed_fixture
printf '\ncreateWebullClient();\n' >>"$fixture/supabase/functions/api/index.ts"
expect_failure "real Webull provider initialization"

write_allowed_fixture
printf '\nconst provider = "direct";\n' \
  >>"$fixture/ritual-investing-api/src/jobs/queue-consumer.ts"
expect_failure "provider-selected queue transport"

write_allowed_fixture
printf "const formerStage = 'https://beta.just-build-this.app';\n" \
  >>"$fixture/ritual-investing-app/lib/runtime.dart"
expect_failure "the former deployment-stage host"

write_allowed_fixture
sed 's/createBlockedBrokerageOrderProvider();//' \
  "$fixture/supabase/functions/api/index.ts" >"$fixture/api-next"
mv "$fixture/api-next" "$fixture/supabase/functions/api/index.ts"
expect_failure "an opened Webull order gate"

echo "provider boundary audit regression tests passed"
