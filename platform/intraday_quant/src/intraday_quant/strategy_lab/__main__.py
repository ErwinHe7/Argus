from __future__ import annotations
import argparse
import json
from pathlib import Path
from .research import assess_retained_source, evaluate_result, prepare, run_engine, sensitivity, write_new
from .grid import run_grid_engine


def main() -> None:
    parser = argparse.ArgumentParser(description="Offline strategy research; never trades or downloads data")
    parser.add_argument("operation", choices=("prepare", "replay", "grid-replay", "evaluate", "sensitivity", "capability"))
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--registration", type=Path)
    args = parser.parse_args()
    raw = json.loads(args.input.read_text(encoding="utf-8-sig"))
    if args.operation == "capability":
        result = assess_retained_source(raw)
    elif args.operation == "prepare":
        result = prepare(raw)
    elif args.operation == "evaluate":
        registration = json.loads(args.registration.read_text(encoding="utf-8-sig")) if args.registration else None
        result = evaluate_result(raw, registration)
    else:
        if args.engine is None:
            parser.error("--engine is required; no alternate Python strategy calculation exists")
        if args.operation == "grid-replay":
            result = run_grid_engine(args.engine, raw)
        else:
            result = run_engine(args.engine, raw) if args.operation == "replay" else sensitivity(args.engine, raw)
    write_new(args.output, result)


if __name__ == "__main__":
    main()
