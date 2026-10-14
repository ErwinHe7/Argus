from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from ..strategy_lab.continuous import IntegrityError, RunnerLocked, _reason
from . import agents, templates


def _summary(value: dict[str, Any], output: Path) -> dict[str, Any]:
    return {"output": str(output), "generatedAt": value["generatedAt"], "overlay": value["overlay"]["status"],
            "ledger": value["ledger"]["status"], "executionAuthorized": False}


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="python -m intraday_quant.foundry",
                                     description="Local research foundry; no LLM calls, data downloads, orders or live stages")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("schema", help="print the leo-foundry-spec.v1 JSON Schema")
    command = commands.add_parser("draft", help="Prototype Builder: freeze or reject a spec")
    command.add_argument("--spec", type=Path, required=True)
    command.add_argument("--state-dir", type=Path, required=True)
    command = commands.add_parser("advance", help="Sweeper and Grower: one step per active spec")
    command.add_argument("--state-dir", type=Path, required=True)
    command.add_argument("--until-blocked", action="store_true")
    command = commands.add_parser("observe", help="Maintainer: check freshness, revisions and forward decay")
    command.add_argument("--state-dir", type=Path, required=True)
    command.add_argument("--spec-id", required=True)
    command.add_argument("--input", type=Path, required=True)
    command.add_argument("--as-of", required=True, help="ISO-8601 timestamp with a timezone")
    command = commands.add_parser("resume", help="Owner only: resume a paused or awaiting spec")
    command.add_argument("--state-dir", type=Path, required=True)
    command.add_argument("--spec-id", required=True)
    command = commands.add_parser("export", help="verified local export; never overwrites")
    command.add_argument("--state-dir", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command = commands.add_parser("publish", help="write the leo-foundry-publication.v1 document")
    command.add_argument("--output", type=Path, required=True)
    command.add_argument("--state-dir", type=Path)
    command.add_argument("--overlay-artifact", type=Path)
    command.add_argument("--rights-confirmed", action="store_true", help="derived-statistics publication rights are confirmed")
    command.add_argument("--public-symbols", action="store_true", help="show symbols instead of 'Redacted holding'")
    command.add_argument("--generated-at", help="ISO-8601 UTC publication time (default: now)")
    args = parser.parse_args(argv)
    try:
        result: Any
        if args.command == "schema":
            result = templates.spec_schema()
        elif args.command == "draft":
            result = agents.draft(args.spec, args.state_dir)
        elif args.command == "advance":
            result = agents.advance(args.state_dir, until_blocked=args.until_blocked)
        elif args.command == "observe":
            result = agents.observe(args.state_dir, args.spec_id, args.input, args.as_of)
        elif args.command == "resume":
            result = agents.resume(args.state_dir, args.spec_id)
        elif args.command == "export":
            value = agents.export(args.state_dir, args.output)
            result = {"output": str(args.output), "head_sha256": value["head_sha256"], "event_count": value["event_count"]}
        else:
            value = agents.publish(args.output, state_dir=args.state_dir, overlay_artifact=args.overlay_artifact,
                                   rights_confirmed=args.rights_confirmed, public_symbols=args.public_symbols,
                                   generated_at=args.generated_at)
            result = _summary(value, args.output)
        print(json.dumps(result, indent=2, sort_keys=True, allow_nan=False))
    except (OSError, ValueError, ArithmeticError, RunnerLocked, IntegrityError, agents.FoundryStopped) as error:
        parser.exit(2, _reason(error) + "\n")


if __name__ == "__main__":
    main()
