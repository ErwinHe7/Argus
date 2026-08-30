#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

fail() {
  printf '%s\n' "legacy-backend-removal: $1" >&2
  exit 1
}

for retired_path in \
  ritual-investing-api/wrangler.jsonc \
  ritual-investing-api/wrangler.beta.jsonc \
  ritual-investing-api/vitest.worker.config.ts \
  ritual-investing-api/drizzle.config.ts \
  ritual-investing-api/drizzle \
  ritual-investing-api/src/index.ts \
  ritual-investing-api/src/generated/env.d.ts \
  ritual-investing-api/src/config/env.ts \
  ritual-investing-api/src/db/client.ts \
  ritual-investing-api/src/db/schema \
  ritual-investing-api/src/middleware/auth0-jwk.ts \
  ritual-investing-api/src/middleware/cloudflare-access.ts \
  ritual-investing-api/src/domains/simulation
do
  test ! -e "$retired_path" || fail "retired authority remains at $retired_path"
done

if rg -n '@neondatabase/serverless|drizzle-(orm|kit)|@cloudflare/vitest-plugin|wrangler' \
  ritual-investing-api/package.json ritual-investing-api/package-lock.json >/dev/null
then
  fail "retired API dependency remains"
fi

if rg -n '@neondatabase/serverless|drizzle-orm|middleware/(auth0-jwk|cloudflare-access)|wrangler' \
  ritual-investing-api/src/retained-app.ts \
  ritual-investing-api/src/db/database-port.ts \
  ritual-investing-api/src/db/request-context.ts \
  ritual-investing-api/src/db/request-transaction.ts \
  ritual-investing-api/src/db/supabase-repositories.ts \
  ritual-investing-api/src/domains/brokerage-accounts \
  ritual-investing-api/src/domains/brokerage-assets \
  ritual-investing-api/src/domains/brokerage-connections \
  ritual-investing-api/src/domains/brokerage-orders \
  ritual-investing-api/src/domains/brokerage-projections \
  ritual-investing-api/src/domains/intentions \
  ritual-investing-api/src/domains/media/service.ts \
  ritual-investing-api/src/domains/privacy/service.ts \
  ritual-investing-api/src/domains/session/supabase-schemas.ts \
  ritual-investing-api/src/jobs \
  ritual-investing-api/src/ports/infrastructure.ts \
  ritual-investing-api/src/security/sha256.ts >/dev/null
then
  fail "retired API source or test import remains"
fi

if rg -n -i \
  'auth0_flutter|auth0_session_repository|AUTH0_(DOMAIN|CLIENT_ID|AUDIENCE)|com\.auth0|auth0\.swift|webcredentials:.*AUTH0' \
  ritual-investing-app/pubspec.yaml \
  ritual-investing-app/pubspec.lock \
  ritual-investing-app/lib \
  ritual-investing-app/android \
  ritual-investing-app/ios \
  ritual-investing-admin/pubspec.yaml \
  ritual-investing-admin/pubspec.lock \
  ritual-investing-admin/lib \
  .github/workflows/ritual-investing.yml \
  docs/ritual-investing \
  --glob '!**/Pods/**' \
  --glob '!**/GeneratedPluginRegistrant.*' >/dev/null
then
  fail "retired Auth0 runtime or native configuration remains"
fi

for pages_config in \
  ritual-investing-site/wrangler.beta.jsonc \
  ritual-investing-site/wrangler.demo.jsonc \
  ritual-investing-site/wrangler.demo-beta.jsonc
do
  node --input-type=module -e '
    import { readFileSync } from "node:fs";
    const config = JSON.parse(readFileSync(process.argv[1], "utf8"));
    const forbidden = ["main", "routes", "route", "r2_buckets", "queues", "services", "durable_objects", "triggers", "vars"];
    if (typeof config.pages_build_output_dir !== "string" || forbidden.some((key) => key in config)) process.exit(1);
  ' "$pages_config" || fail "Cloudflare Pages config is not static-only: $pages_config"
done

for worker_config in \
  ritual-investing-site/wrangler.jsonc \
  ritual-investing-site/wrangler.landing.jsonc
do
  node --input-type=module -e '
    import { readFileSync } from "node:fs";
    const config = JSON.parse(readFileSync(process.argv[1], "utf8"));
    const forbidden = ["main", "routes", "route", "pages_build_output_dir", "r2_buckets", "queues", "services", "durable_objects", "triggers", "vars"];
    if (typeof config.assets?.directory !== "string" || "binding" in config.assets || forbidden.some((key) => key in config)) process.exit(1);
  ' "$worker_config" || fail "Cloudflare Worker config is not asset-only: $worker_config"
done

test ! -e ritual-investing-site/functions || fail "Pages Functions directory remains"
test ! -e ritual-investing-site/_worker.js || fail "Pages _worker.js remains"

printf '%s\n' "Legacy backend removal and static Cloudflare boundary verified."
