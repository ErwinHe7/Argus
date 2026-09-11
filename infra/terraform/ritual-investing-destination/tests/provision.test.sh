#!/usr/bin/env bash
set -euo pipefail
feature_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$feature_root/tests" -p 'test_*.py'
