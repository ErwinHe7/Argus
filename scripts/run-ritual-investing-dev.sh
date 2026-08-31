#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_file=${RITUAL_DEV_CONFIG:-"$repository_root/ritual-investing-app/config/dev.json"}

"$repository_root/scripts/check-no-hosted-dev-targets.sh" "$config_file"

cd "$repository_root/ritual-investing-app"
exec flutter run --dart-define-from-file="$config_file" "$@"
