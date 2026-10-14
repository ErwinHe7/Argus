from __future__ import annotations

import argparse
from pathlib import Path

from ..strategy_lab.continuous import _parse, _read_bytes
from ..strategy_lab.research import write_new
from .engine import run_overlay

MAX_JSON_BYTES = 64 * 1024 * 1024


def main() -> None:
    parser = argparse.ArgumentParser(description="Offline options-overlay backtest; never trades or downloads data")
    parser.add_argument("--source", type=Path, required=True, help="leo-overlay-source.v1 JSON")
    parser.add_argument("--config", type=Path, required=True, help="leo-overlay-config.v1 JSON")
    parser.add_argument("--output", type=Path, required=True, help="New artifact path; existing files are never overwritten")
    args = parser.parse_args()
    source = _parse(_read_bytes(args.source, MAX_JSON_BYTES))
    config = _parse(_read_bytes(args.config, MAX_JSON_BYTES))
    write_new(args.output, run_overlay(source, config, base_dir=args.source.resolve().parent))


if __name__ == "__main__":
    main()
