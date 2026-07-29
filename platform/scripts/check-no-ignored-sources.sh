#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
repository_root="$(cd "$repository_root" && pwd -P)"
script_path="${BASH_SOURCE[0]}"
script_directory="${script_path%/*}"
if [[ "$script_directory" == "$script_path" ]]; then
  script_directory="."
fi
application_root="$(cd "$script_directory/.." && pwd)"
case "$application_root" in
  "$repository_root" | "$repository_root"/*) ;;
  *)
    printf 'Application root is outside the Git checkout: %s\n' "$application_root" >&2
    exit 1
    ;;
esac
cd "$application_root"

protected_paths=(
  ".github/workflows"
  "app"
  "components"
  "ledger/schema.sql"
  "lib"
  "scripts"
  "quant_engine_rs/Cargo.lock"
  "quant_engine_rs/Cargo.toml"
  "quant_engine_rs/src"
  "quant_engine_rs/src/data"
  "quant_engine_rs/tests"
  "intraday_quant/configs"
  "intraday_quant/pyproject.toml"
  "intraday_quant/src/intraday_quant"
  "intraday_quant/src/intraday_quant/data"
  "intraday_quant/src/intraday_quant/reports"
  "intraday_quant/tests"
  "intraday_quant/scripts"
  "quant_core_cpp/apps"
  "quant_core_cpp/CMakeLists.txt"
  "quant_core_cpp/configs"
  "quant_core_cpp/include"
  "quant_core_cpp/src"
  "quant_core_cpp/tests"
)

source_integrity_failed=0

for protected_path in "${protected_paths[@]}"; do
  if [[ ! -e "$protected_path" ]]; then
    printf 'Protected source path is missing: %s\n' "$protected_path" >&2
    source_integrity_failed=1
    continue
  fi

  while IFS= read -r -d '' source_path; do
    case "$source_path" in
      */node_modules/* | */dist/* | */build/* | */target/* | */.next/* | \
        */.venv*/* | */__pycache__/* | */.pytest_cache/* | *.egg-info/* | \
        *.pyc | *.pyo | *.orig)
        continue
        ;;
    esac

    ignore_rule="$(git check-ignore --no-index --verbose -- "$source_path")"
    printf 'Ignored source file: %s\n  matched by: %s\n' "$source_path" "$ignore_rule" >&2
    source_integrity_failed=1
  done < <(
    git ls-files --cached --others --ignored --exclude-standard -z -- "$protected_path"
  )
done

if [[ "$source_integrity_failed" -ne 0 ]]; then
  printf 'Source-integrity check failed. Restore missing paths, narrow the ignore rule, or explicitly allow the source path.\n' >&2
  exit 1
fi

printf 'Source-integrity check passed: no protected source files are ignored.\n'
