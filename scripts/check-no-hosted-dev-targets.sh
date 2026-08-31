#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_file=${1:-"$repository_root/ritual-investing-app/config/dev.json"}

node --input-type=module - "$config_file" <<'NODE'
import { readFileSync } from "node:fs";

const configFile = process.argv[2];
let config;
try {
  config = JSON.parse(readFileSync(configFile, "utf8"));
} catch {
  throw new Error("Dev configuration must be a readable JSON object.");
}
if (config === null || typeof config !== "object" || Array.isArray(config)) {
  throw new Error("Dev configuration must be a JSON object.");
}
if (config.RITUAL_ENVIRONMENT !== "dev") {
  throw new Error("The local launcher accepts only the dev environment profile.");
}

const loopbackHosts = new Set(["localhost", "127.0.0.1", "[::1]", "::1"]);
function localServiceUrl(name) {
  const raw = config[name];
  if (typeof raw !== "string" || raw === "") {
    throw new Error(`${name} is missing from the dev profile.`);
  }
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`${name} must be an exact loopback URL.`);
  }
  if ((url.protocol !== "http:" && url.protocol !== "https:") ||
      !loopbackHosts.has(url.hostname) || url.username !== "" ||
      url.password !== "" || url.search !== "" || url.hash !== "") {
    throw new Error(`${name} must be an exact loopback URL.`);
  }
  return url;
}

for (const name of Object.keys(config).filter((key) => key.endsWith("_URL"))) {
  localServiceUrl(name);
}
const api = localServiceUrl("RITUAL_API_BASE_URL");
const supabase = localServiceUrl("SUPABASE_URL");
if (api.origin !== supabase.origin || api.pathname !== "/functions/v1/api") {
  throw new Error("Dev Auth and Edge API targets must use one exact loopback origin.");
}
if (supabase.pathname !== "/") {
  throw new Error("Dev SUPABASE_URL must be a loopback origin without a path.");
}
NODE

printf '%s\n' "local dev targets verified"
