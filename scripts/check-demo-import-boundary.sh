#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
app_root="$repository_root/ritual-investing-app"

command -v dart >/dev/null 2>&1 || {
  echo "demo import boundary audit failed: dart is required" >&2
  exit 1
}

cd "$app_root"
exec dart tool/check_demo_import_boundary.dart
