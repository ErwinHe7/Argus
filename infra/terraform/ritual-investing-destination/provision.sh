#!/bin/sh
# Python owns argument validation, sanitized receipts, and all external I/O.
set -eu
umask 077
feature_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$feature_root/provision.py" "$@"
