"""Command-line entry point for deterministic SPY replay artifacts."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

from intraday_quant.demo.artifacts import (
    FIXTURE_GENERATED_AT,
    BundleBuildResult,
    _build_bundle,
    _write_fixture,
)
from intraday_quant.demo.contracts import write_json_schemas


def _default_schema_output() -> Path:
    repository = Path(__file__).resolve().parents[5]
    return repository / "contracts" / "spy-price-demo" / "v1"


def _parse_generation_time(value: str | None, *, default: datetime | None = None) -> datetime:
    if value is None:
        return default if default is not None else datetime.now(timezone.utc)
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as error:
        raise ValueError(f"invalid ISO-8601 --generated-at value: {value}") from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _receipt(result: BundleBuildResult, output: Path) -> dict[str, object]:
    manifest = result.manifest
    return {
        "artifact_sha256": manifest.artifact_sha256,
        "output": str(output),
        "rows": manifest.quality.source_rows,
        "sessions": manifest.split.test_sessions,
        "source_sessions": result.source_sessions,
        "source_sha256": manifest.dataset_sha256,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    build = commands.add_parser("build", help="build the historical OOS artifact bundle")
    build.add_argument("--input", required=True, type=Path)
    build.add_argument("--output", required=True, type=Path)
    build.add_argument("--generated-at")

    schemas = commands.add_parser("schemas", help="write the browser JSON Schemas")
    schemas.add_argument("--output", type=Path, default=_default_schema_output())

    fixture = commands.add_parser("fixture", help="write the explicit UI fixture bundle")
    fixture.add_argument("--output", required=True, type=Path)
    fixture.add_argument("--generated-at")
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(arguments)
    try:
        if args.command == "build":
            result = _build_bundle(
                args.input,
                args.output,
                _parse_generation_time(args.generated_at),
            )
            payload: dict[str, object] = _receipt(result, args.output)
        elif args.command == "fixture":
            result = _write_fixture(
                args.output,
                _parse_generation_time(args.generated_at, default=FIXTURE_GENERATED_AT),
            )
            payload = _receipt(result, args.output)
        else:
            written = write_json_schemas(args.output)
            payload = {"files": len(written), "output": str(args.output)}
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
