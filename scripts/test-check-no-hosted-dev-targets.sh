#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
guard="$repository_root/scripts/check-no-hosted-dev-targets.sh"
launcher="$repository_root/scripts/run-ritual-investing-dev.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/ritual-dev-targets.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

write_config() {
  environment=$1
  api_url=$2
  supabase_url=$3
  config_file=$4
  printf '%s\n' \
    '{' \
    "  \"RITUAL_ENVIRONMENT\": \"$environment\"," \
    "  \"RITUAL_API_BASE_URL\": \"$api_url\"," \
    "  \"SUPABASE_URL\": \"$supabase_url\"" \
    '}' >"$config_file"
}

expect_rejected() {
  label=$1
  config_file=$2
  if "$guard" "$config_file" >"$fixture/output" 2>&1; then
    printf '%s\n' "expected dev target guard to reject $label" >&2
    exit 1
  fi
}

write_config \
  dev \
  http://127.0.0.1:54321/functions/v1/api \
  http://127.0.0.1:54321 \
  "$fixture/loopback.json"
"$guard" "$fixture/loopback.json" >"$fixture/output"
grep -F "local dev targets verified" "$fixture/output" >/dev/null

write_config \
  dev \
  https://project.supabase.co/functions/v1/api \
  https://project.supabase.co \
  "$fixture/hosted.json"
expect_rejected "a hosted Supabase target" "$fixture/hosted.json"

for host in 0.0.0.0 192.168.1.25; do
  write_config \
    dev \
    "http://$host:54321/functions/v1/api" \
    "http://$host:54321" \
    "$fixture/non-loopback.json"
  expect_rejected "non-loopback host $host" "$fixture/non-loopback.json"
done

printf '%s\n' \
  '{' \
  '  "RITUAL_ENVIRONMENT": "dev",' \
  '  "RITUAL_API_BASE_URL": "http://127.0.0.1:54321/functions/v1/api",' \
  '  "SUPABASE_URL": "http://127.0.0.1:54321",' \
  '  "METRICS_SERVICE_URL": "https://metrics.example"' \
  '}' >"$fixture/extra-hosted-service.json"
expect_rejected \
  "an additional hosted service" \
  "$fixture/extra-hosted-service.json"

write_config \
  staging \
  https://staging-project.supabase.co/functions/v1/api \
  https://staging-project.supabase.co \
  "$fixture/staging.json"
expect_rejected "a staging profile" "$fixture/staging.json"

mkdir -p "$fixture/bin"
cat >"$fixture/bin/flutter" <<'EOF'
#!/bin/sh
set -eu
: >"$RITUAL_FAKE_FLUTTER_MARKER"
EOF
chmod +x "$fixture/bin/flutter"
if PATH="$fixture/bin:$PATH" \
  RITUAL_DEV_CONFIG="$fixture/hosted.json" \
  RITUAL_FAKE_FLUTTER_MARKER="$fixture/flutter-started" \
  "$launcher" >"$fixture/launcher-output" 2>&1; then
  printf '%s\n' "expected the dev launcher to reject hosted targets" >&2
  exit 1
fi
test ! -e "$fixture/flutter-started" || {
  printf '%s\n' "dev launcher started Flutter before target validation" >&2
  exit 1
}

printf '%s\n' "no-hosted-dev-target regression tests passed"
