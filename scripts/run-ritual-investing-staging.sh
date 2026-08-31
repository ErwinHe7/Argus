#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root/ritual-investing-app"

exec flutter run --dart-define-from-file=config/staging.json "$@"
