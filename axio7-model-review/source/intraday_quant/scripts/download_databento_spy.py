#!/usr/bin/env python3
"""Estimate or download Databento SPY one-minute OHLCV data.

Terminal setup from ``axio7-model-review/source/intraday_quant``::

    python3 -m venv .venv-databento
    source .venv-databento/bin/activate
    python -m pip install --upgrade pip
    python -m pip install databento pandas pyarrow

Keep the API key out of source control::

    export DATABENTO_API_KEY="YOUR_API_KEY"

Estimate coverage and cost without downloading::

    python scripts/download_databento_spy.py \
      --start 2024-07-18 \
      --end 2026-07-25 \
      --estimate-only

Download after reviewing the estimate::

    python scripts/download_databento_spy.py \
      --start 2024-07-18 \
      --end 2026-07-25 \
      --download

The end timestamp is exclusive. The raw DBN response is retained unchanged.
The normalized Parquet output defaults to regular-session bars whose start
times are from 09:30 through 15:59 America/New_York. Pass
``--include-extended-hours`` to retain every returned bar in the Parquet file.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DATASET = "EQUS.MINI"
SCHEMA = "ohlcv-1m"
STYPE_IN = "raw_symbol"
DEFAULT_SYMBOL = "SPY"
PROJECT_ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Estimate or download Databento EQUS.MINI SPY OHLCV-1m data.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--start", required=True, help="Inclusive ISO-8601 start date/time.")
    parser.add_argument("--end", required=True, help="Exclusive ISO-8601 end date/time.")
    parser.add_argument("--symbol", default=DEFAULT_SYMBOL, help="Raw equity symbol (default: SPY).")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--estimate-only",
        action="store_true",
        help="Print entitlement range and estimated cost without downloading.",
    )
    mode.add_argument(
        "--download",
        action="store_true",
        help="Download raw DBN, normalized Parquet, and a lineage receipt.",
    )
    parser.add_argument(
        "--raw-output",
        type=Path,
        help="Raw DBN output path; defaults beneath data/raw/.",
    )
    parser.add_argument(
        "--normalized-output",
        type=Path,
        help="Normalized Parquet output path; defaults beneath data/normalized/.",
    )
    parser.add_argument(
        "--receipt-output",
        type=Path,
        help="JSON receipt output path; defaults beneath data/manifests/.",
    )
    parser.add_argument(
        "--include-extended-hours",
        action="store_true",
        help="Keep all returned bars in normalized output instead of regular hours only.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Permit replacement of existing output files.",
    )
    return parser.parse_args()


def parse_iso(value: str, option: str) -> datetime:
    normalized = value.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as error:
        raise SystemExit(f"{option} must be an ISO-8601 date or timestamp: {value}") from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-")


def output_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    stem = "_".join(
        [
            "databento",
            slug(args.symbol.upper()),
            SCHEMA,
            slug(args.start),
            slug(args.end),
        ]
    )
    session_suffix = "all-sessions" if args.include_extended_hours else "rth"
    raw = args.raw_output or PROJECT_ROOT / "data" / "raw" / f"{stem}.dbn.zst"
    normalized = (
        args.normalized_output
        or PROJECT_ROOT / "data" / "normalized" / f"{stem}_{session_suffix}.parquet"
    )
    receipt = (
        args.receipt_output
        or PROJECT_ROOT / "data" / "manifests" / f"{stem}_{session_suffix}.receipt.json"
    )
    return raw.resolve(), normalized.resolve(), receipt.resolve()


def request_parameters(args: argparse.Namespace) -> dict[str, Any]:
    return {
        "dataset": DATASET,
        "schema": SCHEMA,
        "stype_in": STYPE_IN,
        "symbols": [args.symbol.upper()],
        "start": args.start,
        "end": args.end,
    }


def ensure_outputs_are_writable(paths: tuple[Path, ...], overwrite: bool) -> None:
    existing = [str(path) for path in paths if path.exists()]
    if existing and not overwrite:
        formatted = "\n  ".join(existing)
        raise SystemExit(
            "refusing to replace existing output files; pass --overwrite if intentional:\n"
            f"  {formatted}"
        )
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_frame(store: Any, symbol: str, regular_hours_only: bool) -> Any:
    import pandas as pd

    frame = store.to_df().reset_index()
    timestamp_column = next(
        (name for name in ("ts_event", "timestamp", "index") if name in frame.columns),
        None,
    )
    if timestamp_column is None:
        raise RuntimeError("Databento OHLCV frame has no recognizable event timestamp column")

    frame["timestamp"] = pd.to_datetime(frame[timestamp_column], utc=True)
    if regular_hours_only:
        eastern = frame["timestamp"].dt.tz_convert("America/New_York")
        minute_of_day = eastern.dt.hour * 60 + eastern.dt.minute
        frame = frame.loc[(minute_of_day >= 570) & (minute_of_day < 960)].copy()

    missing = [name for name in ("open", "high", "low", "close", "volume") if name not in frame]
    if missing:
        raise RuntimeError(f"Databento OHLCV frame is missing columns: {', '.join(missing)}")

    if "symbol" not in frame:
        frame["symbol"] = symbol
    frame["symbol"] = frame["symbol"].fillna(symbol).astype(str)
    frame["vwap"] = pd.NA
    frame["bid"] = pd.NA
    frame["ask"] = pd.NA
    frame["trade_count"] = pd.NA
    frame["source"] = "DATABENTO_EQUS_MINI_OHLCV_1M"
    frame["data_quality"] = "vendor_aggregate"

    columns = [
        "timestamp",
        "symbol",
        "open",
        "high",
        "low",
        "close",
        "volume",
        "vwap",
        "bid",
        "ask",
        "trade_count",
        "source",
        "data_quality",
    ]
    return frame[columns].sort_values(["timestamp", "symbol"]).reset_index(drop=True)


def json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_safe(item) for item in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def main() -> int:
    args = parse_args()
    start = parse_iso(args.start, "--start")
    end = parse_iso(args.end, "--end")
    if start >= end:
        raise SystemExit("--start must be earlier than the exclusive --end")

    api_key = os.environ.get("DATABENTO_API_KEY", "").strip()
    if not api_key:
        raise SystemExit("DATABENTO_API_KEY is not set")

    try:
        import databento as db
    except ImportError as error:
        raise SystemExit(
            "databento is not installed; activate the venv and run: "
            "python -m pip install databento pandas pyarrow"
        ) from error

    request = request_parameters(args)
    client = db.Historical(api_key)
    dataset_range = client.metadata.get_dataset_range(dataset=DATASET)
    estimated_cost = client.metadata.get_cost(**request)
    estimate = {
        "status": "ESTIMATE_ONLY" if args.estimate_only else "ESTIMATE_ACCEPTED_FOR_DOWNLOAD",
        "request": request,
        "dataset_range": json_safe(dataset_range),
        "estimated_cost_usd": float(estimated_cost),
        "end_is_exclusive": True,
    }
    print(json.dumps(estimate, indent=2, sort_keys=True))
    if args.estimate_only:
        return 0

    raw_path, normalized_path, receipt_path = output_paths(args)
    ensure_outputs_are_writable((raw_path, normalized_path, receipt_path), args.overwrite)

    store = client.timeseries.get_range(**request, path=str(raw_path))
    normalized = normalize_frame(
        store,
        args.symbol.upper(),
        regular_hours_only=not args.include_extended_hours,
    )
    normalized.to_parquet(normalized_path, index=False)

    receipt = {
        "schema_version": "argus.databento-download-receipt.v1",
        "created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "request": request,
        "dataset_range": json_safe(dataset_range),
        "estimated_cost_usd": float(estimated_cost),
        "end_is_exclusive": True,
        "regular_hours_only": not args.include_extended_hours,
        "normalized_timezone": "UTC",
        "raw_path": str(raw_path),
        "raw_bytes": raw_path.stat().st_size,
        "raw_sha256": sha256_file(raw_path),
        "normalized_path": str(normalized_path),
        "normalized_rows": int(len(normalized)),
        "normalized_first_timestamp": (
            normalized["timestamp"].min().isoformat() if not normalized.empty else None
        ),
        "normalized_last_timestamp": (
            normalized["timestamp"].max().isoformat() if not normalized.empty else None
        ),
    }
    receipt_path.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(receipt, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("download interrupted", file=sys.stderr)
        raise SystemExit(130)
