"""Offline GRID-R1 orchestration. All strategy and accounting work stays in Rust."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
from typing import Any


def run_grid_engine(engine: Path, request: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(request, dict) or request.get("schema_version") != "leo-grid-request.v1":
        raise ValueError("expected a complete leo-grid-request.v1 JSON document")
    if "operation" in request:
        raise ValueError("import requests must not contain an operation override")
    serialized = json.dumps({**request, "operation": "grid_replay"}, allow_nan=False)
    if len(serialized.encode("utf-8")) > 4 * 1024 * 1024:
        raise ValueError("grid input exceeds 4 MiB")
    completed = subprocess.run(
        [str(engine.resolve())], input=serialized, text=True, encoding="utf-8",
        capture_output=True, check=False, timeout=180,
    )
    try:
        result = json.loads(completed.stdout)
    except (json.JSONDecodeError, UnicodeError) as error:
        raise ValueError("Rust grid engine returned an unreadable result") from error
    if not isinstance(result, dict):
        raise ValueError("Rust grid engine returned an unsupported result")
    if completed.returncode or "error" in result:
        raise ValueError(f"Rust grid replay rejected input: {result.get('error', 'unknown failure')}")
    if (result.get("schema_version") != "leo-grid-result.v1"
            or result.get("strategy") != "GRID-R1"
            or result.get("execution_authorized") is not False
            or result.get("paper_execution_available") is not False
            or result.get("promotion_eligible") is not False):
        raise ValueError("unexpected grid result contract or execution authority")
    return result
