"""The four mechanical foundry roles, the owner's resume, local export and publication.

Prototype Builder freezes an allow-listed spec. Sweeper probes the baseline and
sweeps the predeclared grid on development data only, recording every trial.
Grower applies predeclared gates, evaluates the holdout once and prepares a paper
proposal or forward shadow. Maintainer pauses on stale, revised or decaying
evidence and never resumes. Strategy replays stay in Rust (``research.run_engine``,
``grid.run_grid_engine``); overlays use ``overlay_lab``. There is no LLM client,
network call, broker or order path, and execution is never authorized.
"""
from __future__ import annotations

import copy
import csv
import json
import math
import os
import random
import re
import subprocess
import tempfile
from dataclasses import dataclass, field, replace
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any

import pandas as pd

from ..backtest.validation import _session_sign_flip_placebo, benjamini_hochberg
from ..iv_lab import black_scholes
from ..overlay_lab import engine as overlay_engine
from ..overlay_lab import report as overlay_report
from ..strategy_lab import grid as grid_engine
from ..strategy_lab import research
from ..strategy_lab.continuous import IntegrityError, _json_bytes, _parse, _read_bytes, _reason, _sha, _write_bytes, exclusive_lock
from . import ledger, templates
from .ledger import Clock, utc_now

FOUNDRY_VERSION = "leo-foundry.v1"
PUBLICATION_VERSION = "leo-foundry-publication.v1"
EXPORT_VERSION = "leo-foundry-export.v1"
MAX_SPEC_BYTES = 256 * 1024
MAX_INPUT_BYTES = 64 * 1024 * 1024
MAX_ENGINE_BYTES = 256 * 1024 * 1024
STRATEGY_WARMUP_SESSIONS = 220  # research.evaluate_result's indicator warm-up
STRATEGY_BLOCK_LENGTH = 5
STRATEGY_MIN_SIGN_FLIP_SESSIONS = 20
SIGN_FLIP_REPORTED = "reported_diagnostic_not_promotion_evidence"
BH_REPORTED = "reported_descriptive_not_promotion_evidence"
DECAY_MIN_FORWARD_SESSIONS = 63
MAX_STALE_SESSIONS = 2
TIME_TOLERANCE = timedelta(minutes=5)
SYNTHETIC = "SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE"
# Environment failures are retried later, never recorded as a research verdict or a cached trial.
ENVIRONMENT_ERRORS = (OSError, subprocess.SubprocessError, MemoryError)
_PUBLISH_COMMAND = ("python -m intraday_quant.foundry publish --state-dir STATE_DIR --overlay-artifact ARTIFACT.json "
                    "--rights-confirmed --output ../features/research-desk/data/foundry.json")
_PUBLISH_NOTE = (" Run the command from platform/intraday_quant/. Each publish rewrites both sections, so pass the state "
                 "directory and the overlay artifact together when both exist.")
OVERLAY_PENDING = {
    "status": "ARTIFACT_PENDING",
    "reason": "No overlay backtest built from licensed, point-in-time option quotes has been published." + _PUBLISH_NOTE,
    "command": _PUBLISH_COMMAND,
}
LEDGER_PENDING = {
    "status": "ARTIFACT_PENDING",
    "reason": "No research-agent ledger has been exported for publication." + _PUBLISH_NOTE,
    "command": _PUBLISH_COMMAND,
}


class FoundryStopped(RuntimeError):
    """A STOP file in the state directory blocks advance."""


class _DuplicateSpec(ValueError):
    pass


class _Blocked(Exception):
    def __init__(self, reasons: list[str]) -> None:
        super().__init__(", ".join(reasons))
        self.reasons = reasons


@dataclass
class _Context:
    spec: Any
    frozen: dict[str, Any]
    raw: dict[str, Any]
    base_dir: Path
    engine: Path | None
    prepared: dict[date, dict[str, Any]] = field(default_factory=dict)

    @property
    def kind(self) -> str:
        return templates.TEMPLATES[self.spec.template].kind


def _receipt(kind: str, spec_id: str, **fields: Any) -> dict[str, Any]:
    return {"schema_version": ledger.RECEIPT_VERSION, "kind": kind, "spec_id": spec_id, **fields}


def _append(root: Path, now: Clock, spec_id: str, role: str, kind: str, from_stage: str | None, to_stage: str | None,
            reasons: list[str], receipt: dict[str, str] | None, *, status: str | None = None) -> dict[str, Any]:
    return ledger.append(root, now=now, spec_id=spec_id, role=role, kind=kind, from_stage=from_stage, to_stage=to_stage,
                         status=status or ledger.KINDS[kind][1], reasons=reasons, receipt=receipt)  # type: ignore[arg-type]


def _portable(path: Path, root: Path) -> str:
    """Path relative to the state directory when possible, so ledgers hash identically across hosts."""
    try:
        return Path(os.path.relpath(path, root)).as_posix()
    except ValueError:
        return path.as_posix()


def _norm_bar(bar: dict[str, Any]) -> dict[str, Any]:
    result = {}
    for key, value in bar.items():
        if key in ("open", "high", "low", "close"):
            result[key] = format(Decimal(str(value)).normalize(), "f")
        elif key in ("available_at", "open_at", "close_at"):
            result[key] = research.utc(value).isoformat()
        else:
            result[key] = value
    return result


def _validate_input(template: str, raw: dict[str, Any]) -> dict[str, Any]:
    """Schema-check a template input; return symbol, classification and normalized bars by session."""
    kind = templates.TEMPLATES[template].kind
    if kind == "strategy":
        source = research.RawDataset.model_validate(raw)
        if source.strategy != template:
            raise ValueError("source strategy differs from the spec template")
        research.verified_xnys_bars(source.bars)
        symbol, classification, bars = source.symbol, source.evidence.classification, [bar.model_dump(mode="json") for bar in source.bars]
    elif kind == "overlay":
        overlay = overlay_engine.OverlaySource.model_validate(raw)
        research.verified_xnys_bars(overlay.bars)
        symbol, classification, bars = overlay.symbol, overlay.evidence.classification, [bar.model_dump(mode="json") for bar in overlay.bars]
    else:
        evidence = raw.get("source_evidence")
        bars = raw.get("bars")
        if raw.get("schema_version") != "leo-grid-request.v1" or not isinstance(evidence, dict) or not isinstance(bars, list) or not bars:
            raise ValueError("expected a leo-grid-request.v1 input with bars and source evidence")
        symbol, classification = raw.get("symbol"), evidence.get("classification")
        if classification not in ("observed", "synthetic_fixture") or not all(isinstance(bar, dict) for bar in bars):
            raise ValueError("grid input needs observed or synthetic_fixture evidence and object bars")
    try:
        normalized = {str(bar["session_date"]): _norm_bar(bar) for bar in bars}
        dates = [date.fromisoformat(str(bar["session_date"])) for bar in bars]
    except (ArithmeticError, KeyError, TypeError) as error:
        raise ValueError("malformed input bars") from error
    if dates != sorted(set(dates)):
        raise ValueError("duplicate or unordered input sessions")
    return {"symbol": symbol, "classification": classification, "bars": normalized, "first": dates[0], "last": dates[-1]}


def _truncate(kind: str, raw: dict[str, Any], end: date) -> dict[str, Any]:
    """Development-only (or holdout-bounded) copy of the input; later observations are removed."""
    def keep(value: Any) -> bool:
        return date.fromisoformat(str(value)[:10]) <= end

    result = copy.deepcopy(raw)
    result["bars"] = [bar for bar in raw["bars"] if keep(bar["session_date"])]
    if kind == "overlay":
        result["dividends"] = [item for item in raw.get("dividends", []) if keep(item["ex_date"])]
        if raw.get("iv_marks") is not None:
            result["iv_marks"] = [item for item in raw["iv_marks"] if keep(item["session_date"])]
    return result


def _context(root: Path, spec: dict[str, Any]) -> _Context:
    frozen = spec["frozen"]
    model = templates.SPEC.validate_python(frozen["spec"])
    path = (root / frozen["spec"]["input"]["path"]).resolve()
    try:
        payload = _read_bytes(path, MAX_INPUT_BYTES)
    except (OSError, ValueError) as error:
        raise _Blocked(["FROZEN_INPUT_UNAVAILABLE"]) from error
    if _sha(payload) != frozen["input_sha256"]:
        raise _Blocked(["FROZEN_INPUT_CHANGED"])
    engine = None
    if frozen["engine_sha256"] is not None:
        engine = (root / frozen["spec"]["engine"]).resolve()
        try:
            engine_sha = _sha(_read_bytes(engine, MAX_ENGINE_BYTES))
        except (OSError, ValueError) as error:
            raise _Blocked(["ENGINE_UNAVAILABLE"]) from error
        if engine_sha != frozen["engine_sha256"]:
            raise _Blocked(["ENGINE_CHANGED"])
    raw = _parse(payload)
    if model.template == "OVERLAY-v1":
        try:
            _check_quote_file(raw, path.parent)
        except OSError as error:
            raise _Blocked(["FROZEN_INPUT_UNAVAILABLE"]) from error
        except ValueError as error:
            raise _Blocked(["FROZEN_INPUT_CHANGED"]) from error
    return _Context(model, frozen, raw, path.parent, engine)


def _check_quote_file(raw: dict[str, Any], base: Path) -> None:
    """An overlay source's hash-bound quote file must be present and unchanged before any replay."""
    quotes = raw.get("option_quotes")
    if not isinstance(quotes, dict):
        return
    path = Path(str(quotes["path"]))
    if _sha(_read_bytes(path if path.is_absolute() else base / path, overlay_engine.MAX_QUOTE_BYTES)) != str(quotes["sha256"]).lower():
        raise ValueError("option quote file sha256 mismatch")


def _overlay_evidence(raw: dict[str, Any], base: Path) -> list[tuple[date, datetime, str]]:
    """(session, available_at, canonical row) for every option quote, dividend and IV mark of an overlay source."""
    source = overlay_engine.OverlaySource.model_validate(raw)
    items = []
    if source.option_quotes is not None:
        for row in overlay_engine.load_quotes(source.option_quotes, base)[0]:
            items.append((row["session_date"], row["available_at"], json.dumps({"quote": row}, sort_keys=True, default=str)))
    for dividend in source.dividends:
        items.append((dividend.ex_date, research.utc(dividend.available_at),
                      json.dumps({"dividend": dividend.model_dump(mode="json")}, sort_keys=True)))
    for mark in source.iv_marks or []:
        items.append((mark.session_date, research.utc(mark.available_at), json.dumps({"iv_mark": mark.model_dump(mode="json")}, sort_keys=True)))
    return items


def _by_session(items: list[tuple[date, datetime, str]], last: date) -> dict[date, list[str]]:
    grouped: dict[date, list[str]] = {}
    for day, _, row in items:
        if day <= last:
            grouped.setdefault(day, []).append(row)
    return {day: sorted(rows) for day, rows in grouped.items()}


# -- replays and statistics ---------------------------------------------------
def _replay(ctx: _Context, point: dict[str, Any], end: date) -> tuple[list[tuple[str, float, str]], dict[str, Any]]:
    """Rows of (session, statistic return, sign-flip cluster) through ``end``; all strategy maths stays in its engine."""
    raw = _truncate(ctx.kind, ctx.raw, end)
    if ctx.kind == "strategy":
        if end not in ctx.prepared:
            ctx.prepared[end] = research.prepare(raw)
        parameters = templates.research_parameters(ctx.spec, point)
        request = ctx.prepared[end] if parameters is None else {**ctx.prepared[end], "research_parameters": parameters}
        result = research.run_engine(ctx.engine, request)  # type: ignore[arg-type]
        rows = [(str(item["session_date"]), float(item["net_return"]), str(item["session_date"]))
                for item in result["equity"][STRATEGY_WARMUP_SESSIONS:]]
    elif ctx.kind == "grid":
        result = grid_engine.run_grid_engine(ctx.engine, {**raw, "intervals": point["intervals"]})  # type: ignore[arg-type]
        rows, previous = [], 1.0
        for item in result["equity"]:
            level = 1 + float(item["total_return"])
            rows.append((str(item["session_date"]), level / previous - 1, str(item["session_date"])))
            previous = level
    else:
        result = overlay_engine.run_overlay(raw, templates.overlay_config(ctx.spec, point), base_dir=ctx.base_dir,
                                            seed=ctx.spec.inference.seed, resamples=ctx.spec.inference.resamples)
        rows = [(row["session_date"], float(row["active_return"]), row["cluster_date"]) for row in result["daily"]]
    return rows, result


def _window(rows: list[tuple[str, float, str]], start: date | None, end: date) -> list[tuple[str, float, str]]:
    return [row for row in rows if (start is None or ledger.day(row[0]) >= start) and ledger.day(row[0]) <= end]


def _drawdown(returns: list[float]) -> float:
    nav = peak = 1.0
    worst = 0.0
    for value in returns:
        nav *= 1 + value
        peak = max(peak, nav)
        worst = min(worst, nav / peak - 1)
    return worst


def _stats(kind: str, rows: list[tuple[str, float, str]], inference: Any) -> dict[str, Any]:
    """Compounded statistic, moving-block bootstrap and clustered sign-flip p-value (1.0 when insufficient)."""
    if not rows:
        return {"sessions": 0, "start": None, "end": None, "statistic": None, "p_value": 1.0, "max_drawdown": None,
                "sign_flip_status": "no_sessions", "bootstrap": {"status": "no_sessions"}}
    returns = [value for _, value, _ in rows]
    clusters = [cluster for _, _, cluster in rows]
    statistic = research._compound(returns)
    if kind == "overlay":
        inferred = overlay_report.active_inference(returns, clusters, seed=inference.seed, resamples=inference.resamples)
        bootstrap, sign_flip = inferred["active_return_bootstrap"], inferred["active_return_sign_flip"]
    else:
        bootstrap = research.block_interval(returns, seed=inference.seed, resamples=inference.resamples, block_length=STRATEGY_BLOCK_LENGTH)
        frame = pd.DataFrame({"date": clusters, "gross_return": returns, "net_return": returns})
        sign_flip = _session_sign_flip_placebo(frame, resamples=inference.resamples, random_seed=inference.seed,
                                               minimum_sessions=STRATEGY_MIN_SIGN_FLIP_SESSIONS)
    p_value = float(sign_flip["two_sided_plus_one_p_value"]) if sign_flip.get("status") == SIGN_FLIP_REPORTED else 1.0
    return {"sessions": len(rows), "start": rows[0][0], "end": rows[-1][0], "statistic": statistic, "p_value": p_value,
            "max_drawdown": _drawdown(returns), "sign_flip_status": sign_flip["status"],
            "bootstrap": {key: bootstrap.get(key) for key in ("status", "lower_95", "upper_95", "resamples", "block_length")}}


def _trial(root: Path, ctx: _Context, point: dict[str, Any], end: date) -> tuple[dict[str, Any], str]:
    """Run or reuse one content-addressed trial. Rejected attempts are recorded too, with p = 1."""
    overlay = ctx.kind == "overlay"
    identity = {"schema_version": ledger.TRIAL_VERSION, "foundry_version": FOUNDRY_VERSION, "template": ctx.spec.template,
                "point": point, "input_sha256": ctx.frozen["input_sha256"], "engine_sha256": ctx.frozen["engine_sha256"],
                "overlay_engine": overlay_engine.ENGINE_VERSION if overlay else None,
                "overlay": ctx.spec.overlay.model_dump(mode="json") if overlay else None,
                "end": end.isoformat(), "inference": ctx.spec.inference.model_dump(mode="json")}
    key = _sha(_json_bytes(identity))
    existing = ledger.read_trial(root, key)
    if existing is not None:
        return existing
    try:
        rows, result = _replay(ctx, point, end)
        record = {"state": "completed", "reason": None, "result_sha256": research.digest(result), **_stats(ctx.kind, rows, ctx.spec.inference)}
    except (IntegrityError, *ENVIRONMENT_ERRORS):
        raise
    except Exception as error:  # every deterministic rejection stays in the family
        record = {"state": "rejected", "reason": _reason(error), "result_sha256": None, **_stats(ctx.kind, [], ctx.spec.inference)}
    value = {"schema_version": ledger.TRIAL_VERSION, "trial_key": key, "identity": identity, **record,
             "llm_calls": 0, "execution_authorized": False}
    return value, ledger.write_trial(root, value)


# -- Sweeper -----------------------------------------------------------------
def _probe(root: Path, ctx: _Context, now: Clock) -> dict[str, Any]:
    spec = ctx.spec
    point = templates.probe_point(spec)
    record, sha = _trial(root, ctx, point, spec.evaluation.development_end)
    reasons = []
    if record["state"] != "completed":
        reasons.append("PROBE_TRIAL_REJECTED")
    elif record["sessions"] < spec.evaluation.minimum_dev_sessions:
        reasons.append("INSUFFICIENT_DEVELOPMENT_SESSIONS")
    elif not record["statistic"] > 0:
        reasons.append("NON_POSITIVE_PROBE_STATISTIC")
    receipt = ledger.put_receipt(root, _receipt(
        "probe", spec.spec_id, point=point, trial={"key": record["trial_key"], "sha256": sha}, state=record["state"],
        sessions=record["sessions"], statistic=record["statistic"], development_end=spec.evaluation.development_end.isoformat(),
        minimum_dev_sessions=spec.evaluation.minimum_dev_sessions, passed=not reasons, reasons=reasons))
    if reasons:
        return _append(root, now, spec.spec_id, "sweeper", "REJECTED_NO_DEPLOYABLE_EDGE", "PROBE", None, reasons, receipt)
    return _append(root, now, spec.spec_id, "sweeper", "PROBE_COMPLETED", "PROBE", "BACKTEST", [], receipt)


def _backtest(root: Path, ctx: _Context, now: Clock) -> dict[str, Any]:
    spec = ctx.spec
    points = templates.grid_points(spec)
    records = [_trial(root, ctx, point, spec.evaluation.development_end) for point in points]
    ids = [f"{spec.spec_id}:{index:03d}" for index in range(len(points))]
    frame = pd.DataFrame({"hypothesis_id": ids, "family": spec.spec_id, "p_value": [record["p_value"] for record, _ in records],
                          "test_kind": "primary", "pre_registered": True})
    corrected = benjamini_hochberg(frame, alpha=templates.FDR_ALPHA)
    families = corrected.get("families", [])
    if corrected["status"] != BH_REPORTED or len(families) != 1 or families[0]["hypothesis_count"] != len(points):
        raise _Blocked(["MULTIPLE_TESTING_CONTRACT_FAILED"])
    adjusted = {row["hypothesis_id"]: row for row in families[0]["results"]}
    trials = []
    for index, (point, (record, sha)) in enumerate(zip(points, records, strict=True)):
        row = adjusted[ids[index]]
        lower = record["bootstrap"].get("lower_95")
        survivor = (record["state"] == "completed" and row["rejected_at_alpha"] and record["statistic"] > 0
                    and lower is not None and lower > 0)
        trials.append({"index": index, "hypothesis_id": ids[index], "point": point, "trial_key": record["trial_key"],
                       "trial_sha256": sha, "state": record["state"], "sessions": record["sessions"], "statistic": record["statistic"],
                       "p_value": row["raw_p_value"], "adjusted_p_value": row["adjusted_p_value"],
                       "bh_rejected": row["rejected_at_alpha"], "lower_95": lower, "survivor": survivor})
    survivors = [trial["index"] for trial in trials if trial["survivor"]]
    receipt = ledger.put_receipt(root, _receipt(
        "backtest", spec.spec_id, family=spec.spec_id, family_trial_count=len(points), alpha=templates.FDR_ALPHA,
        method=corrected["method"], development_end=spec.evaluation.development_end.isoformat(), trials=trials, survivors=survivors))
    if not survivors:
        return _append(root, now, spec.spec_id, "sweeper", "REJECTED_NO_DEPLOYABLE_EDGE", "BACKTEST", None, ["NO_GRID_SURVIVORS"], receipt)
    return _append(root, now, spec.spec_id, "sweeper", "BACKTEST_COMPLETED", "BACKTEST", "BACKTEST", [], receipt)


# -- Grower ------------------------------------------------------------------
def _point_key(point: dict[str, Any]) -> str:
    return json.dumps(point, sort_keys=True)


def _holdout_users(state: dict[str, Any], spec_state: dict[str, Any]) -> list[str]:
    """Other specs that already evaluated an overlapping holdout on the same frozen input."""
    frozen = spec_state["frozen"]
    start, end = (ledger.day(frozen["spec"]["evaluation"][key]) for key in ("holdout_start", "holdout_end"))
    return sorted(other["spec_id"] for other in state["specs"].values()
                  if other["spec_id"] != spec_state["spec_id"] and other["holdout"] is not None
                  and other["frozen"]["input_sha256"] == frozen["input_sha256"]
                  and ledger.day(other["holdout"]["window"]["start"]) <= end and start <= ledger.day(other["holdout"]["window"]["end"]))


def _gates(ctx: _Context, spec_state: dict[str, Any], users: list[str]) -> tuple[dict[str, Any], list[tuple[dict[str, Any], str, str]]]:
    spec = ctx.spec
    template = templates.TEMPLATES[spec.template]
    trials = spec_state["backtest"]["trials"]
    selected = min((trial for trial in trials if trial["survivor"]), key=lambda trial: (trial["adjusted_p_value"], trial["index"]))
    by_point = {_point_key(trial["point"]): trial for trial in trials}
    near = [by_point[_point_key(point)] for point in templates.neighbours(spec, selected["point"])]
    positive = sum(1 for trial in near if trial["state"] == "completed" and trial["statistic"] > 0)
    checks: list[tuple[dict[str, Any], str, str]] = []

    def gate(gate_id: str, passed: bool, detail: str, kind: str = "", reason: str = "") -> None:
        checks.append(({"id": gate_id, "passed": passed, "detail": detail}, kind, reason))

    gate("template_max_stage", template.max_stage == "PAPER",
         f"{spec.template} may reach PAPER as a proposal or shadow only." if template.max_stage == "PAPER"
         else f"{spec.template} is capped at {template.max_stage}; it never reaches PAPER.", "BLOCKED", "TEMPLATE_CAPPED_AT_BACKTEST")
    observed = spec_state["classification"] == "observed"
    gate("evidence_observed", observed, "Source evidence is classified as observed." if observed
         else "Synthetic-fixture evidence is capped at BACKTEST.", "BLOCKED", "SYNTHETIC_EVIDENCE_CAPPED_AT_BACKTEST")
    if template.kind == "overlay":
        executable = spec.overlay.pricing_mode == "EXECUTABLE_QUOTES"
        gate("executable_quotes", executable, "Overlay trials priced from executable bid/ask quotes." if executable
             else "MODEL_PRICED_NOT_EXECUTABLE overlays are capped at BACKTEST.", "BLOCKED", "MODEL_PRICED_CAPPED_AT_BACKTEST")
    gate("holdout_unused", not users, "No other spec has evaluated an overlapping holdout on this frozen input." if not users
         else f"The overlapping holdout on this frozen input was already evaluated by {', '.join(users[:5])}; it is never reused.",
         "BLOCKED", "HOLDOUT_ALREADY_CONSUMED")
    gate("selection_rule", True, f"Grid point {selected['index'] + 1} of {len(trials)} selected by minimum adjusted p-value, then grid order.")
    if template.kind == "strategy":
        baseline = templates.is_baseline(spec, selected["point"])
        gate("baseline_selected", baseline, "The selected point is the deployed baseline." if baseline
             else "The selected point is not the template baseline; only the baseline can be paper traded.",
             "BLOCKED", "SELECTED_POINT_NOT_BASELINE")
    gate("neighbours_positive", bool(near) and 2 * positive >= len(near),
         f"{positive} of {len(near)} adjacent grid neighbours have a positive development statistic; at least half, and at least one, are required.",
         "REJECTED_NO_DEPLOYABLE_EDGE", "UNSTABLE_GRID_NEIGHBOURS")
    return selected, checks


def _guard_grower(spec_state: dict[str, Any]) -> None:
    active = (spec_state["status"], spec_state["stage"]) == ("ACTIVE", "BACKTEST")
    if spec_state["holdout"] is not None and not active:
        raise ValueError("holdout already evaluated for this spec; a second attempt is refused")
    if not active or spec_state["backtest"] is None:
        raise ValueError("the Grower acts only after a completed backtest")


def _holdout(root: Path, ctx: _Context, spec_state: dict[str, Any], point: dict[str, Any],
             now: Clock) -> tuple[dict[str, Any], dict[str, Any]]:
    if spec_state["holdout"] is not None:
        raise ValueError("holdout already evaluated for this spec; a second attempt is refused")
    evaluation, inference = ctx.spec.evaluation, ctx.spec.inference
    failure, result = None, None
    try:
        rows, result = _replay(ctx, point, evaluation.holdout_end)
        stats = _stats(ctx.kind, _window(rows, evaluation.holdout_start, evaluation.holdout_end), inference)
    except (IntegrityError, *ENVIRONMENT_ERRORS):  # nothing is recorded; the holdout stays unused
        raise
    except Exception as error:
        failure, stats = _reason(error), _stats(ctx.kind, [], inference)
    reasons = []
    if failure:
        reasons.append("HOLDOUT_REPLAY_REJECTED")
    elif stats["sessions"] < evaluation.minimum_holdout_sessions:
        reasons.append("INSUFFICIENT_HOLDOUT_SESSIONS")
    elif not stats["statistic"] > 0:
        reasons.append("NON_POSITIVE_HOLDOUT_STATISTIC")
    report = None
    if not reasons and ctx.kind == "strategy":
        try:
            report = ledger.put_receipt(root, research.evaluate_result(result, None, seed=inference.seed, resamples=inference.resamples,  # type: ignore[arg-type]
                                                                       block_length=STRATEGY_BLOCK_LENGTH))
        except (ValueError, KeyError, TypeError) as error:
            failure = _reason(error)
            reasons.append("RESEARCH_REPORT_REJECTED")
    value = _receipt("holdout", ctx.spec.spec_id, point=point, window={"start": evaluation.holdout_start.isoformat(),
                                                                       "end": evaluation.holdout_end.isoformat()},
                     minimum_holdout_sessions=evaluation.minimum_holdout_sessions, failure=failure, report=report,
                     passed=not reasons, reasons=reasons, **stats)
    event = _append(root, now, ctx.spec.spec_id, "grower", "HOLDOUT_EVALUATED", "BACKTEST", "BACKTEST", [], ledger.put_receipt(root, value))
    return value, event


def _proposal_steps(spec_id: str) -> list[str]:
    return [
        "Review research-report.json and the foundry ledger. The holdout was evaluated once; nothing here is promotion evidence.",
        "Import research-report.json into Strategy Lab's research evidence view.",
        "If you choose to continue, configure the deployed baseline yourself in Strategy Lab and start a paper (simulated) mandate. No order has been placed.",
        f"Record your decision with: python -m intraday_quant.foundry resume --state-dir STATE_DIR --spec-id {spec_id}",
    ]


def _grow(root: Path, ctx: _Context, spec_state: dict[str, Any], now: Clock) -> list[dict[str, Any]]:
    _guard_grower(spec_state)
    spec = ctx.spec
    users = [] if spec_state["holdout"] is not None else _holdout_users(ledger.fold_state(root), spec_state)
    selected, checks = _gates(ctx, spec_state, users)
    failure = next(((kind, reason) for gate, kind, reason in checks if not gate["passed"]), None)
    grower = ledger.put_receipt(root, _receipt(
        "grower", spec.spec_id, selected={"index": selected["index"], "point": selected["point"],
                                          "adjusted_p_value": selected["adjusted_p_value"]},
        gates=[gate for gate, _, _ in checks], outcome=failure[0] if failure else "HOLDOUT"))
    if failure is not None:
        return [_append(root, now, spec.spec_id, "grower", failure[0], "BACKTEST", None, [failure[1]], grower)]
    events = []
    holdout = spec_state["holdout"]
    if holdout is None:
        holdout, event = _holdout(root, ctx, spec_state, selected["point"], now)
        events.append(event)
    if not holdout["passed"]:
        # The holdout receipt is already recorded once; the rejection carries the Grower's receipt.
        events.append(_append(root, now, spec.spec_id, "grower", "REJECTED_NO_DEPLOYABLE_EDGE", "BACKTEST", None,
                              holdout["reasons"], grower))
        return events
    events.append(_append(root, now, spec.spec_id, "grower", "PROMOTED", "BACKTEST", "PAPER", [], grower))
    events.append(_paper_outputs(root, ctx, selected["point"], holdout, now))
    return events


def _paper_outputs(root: Path, ctx: _Context, point: dict[str, Any], holdout: dict[str, Any], now: Clock) -> dict[str, Any]:
    """MR/MOM: Strategy Lab report plus a human-step proposal. Overlay: forward shadow. Never an order."""
    spec = ctx.spec
    if ctx.kind == "strategy":
        report = ledger.read_receipt(root, holdout["report"])
        files = [ledger.write_proposal_file(root, spec.spec_id, "research-report.json", report),
                 ledger.write_proposal_file(root, spec.spec_id, "proposal.json", {
                     "strategyId": spec.template, "symbol": spec.symbol, "parameters": {}, "mode": "paper",
                     "steps": _proposal_steps(spec.spec_id)})]
        receipt = ledger.put_receipt(root, _receipt("proposal", spec.spec_id, files=files, execution_authorized=False))
        return _append(root, now, spec.spec_id, "grower", "PAPER_PROPOSAL_ISSUED", "PAPER", "PAPER", [], receipt)
    receipt = ledger.put_receipt(root, _receipt("forward_shadow", spec.spec_id, point=point,
                                                config_sha256=research.digest(templates.overlay_config(spec, point)),
                                                orders="none_placed", execution_authorized=False, options_execution_enabled=False))
    return _append(root, now, spec.spec_id, "grower", "FORWARD_SHADOW_STARTED", "PAPER", "PAPER", [], receipt)


def _awaits_step(spec_state: dict[str, Any]) -> bool:
    """Active below PAPER, or promoted but interrupted before its paper outputs were recorded."""
    if spec_state["status"] != "ACTIVE":
        return False
    return spec_state["stage"] != "PAPER" or (spec_state["proposal"] is None and spec_state["shadow"] is None)


def _advance_spec(root: Path, spec_state: dict[str, Any], now: Clock) -> list[dict[str, Any]]:
    _refuse_if_stopped(root)
    stage, spec_id = spec_state["stage"], spec_state["spec_id"]
    role = "sweeper" if stage == "PROBE" or spec_state["backtest"] is None else "grower"
    try:
        ctx = _context(root, spec_state)
        if stage == "PROBE":
            return [_probe(root, ctx, now)]
        if spec_state["backtest"] is None:
            return [_backtest(root, ctx, now)]
        if stage == "PAPER":
            return [_paper_outputs(root, ctx, spec_state["grower"]["selected"]["point"], spec_state["holdout"], now)]
        return _grow(root, ctx, spec_state, now)
    except _Blocked as blocked:
        receipt = ledger.put_receipt(root, _receipt("blocked", spec_id, reasons=blocked.reasons))
        return [_append(root, now, spec_id, role, "BLOCKED", stage, None, blocked.reasons, receipt)]


def _refuse_if_stopped(root: Path) -> None:
    if (root / "STOP").exists():
        raise FoundryStopped("STOP file present in the state directory; advance and grow refused")


def advance(state_dir: Path | str, *, until_blocked: bool = False, now: Clock = utc_now) -> list[dict[str, Any]]:
    """One role step per active spec; with ``until_blocked`` repeat until nothing can move."""
    root = Path(state_dir).resolve()
    appended: list[dict[str, Any]] = []
    _refuse_if_stopped(root)
    with exclusive_lock(root):
        while True:
            progressed = False
            for spec_state in ledger.fold_state(root)["specs"].values():
                _refuse_if_stopped(root)
                if not _awaits_step(spec_state):
                    continue
                appended.extend(_advance_spec(root, spec_state, now))
                progressed = True
            if not until_blocked or not progressed:
                return appended


def grow(state_dir: Path | str, spec_id: str, *, now: Clock = utc_now) -> list[dict[str, Any]]:
    """The Grower's step for one spec; a second holdout attempt is refused."""
    root = Path(state_dir).resolve()
    _refuse_if_stopped(root)
    with exclusive_lock(root):
        spec_state = _spec(ledger.fold_state(root), spec_id)
        _guard_grower(spec_state)
        return _advance_spec(root, spec_state, now)


def _spec(state: dict[str, Any], spec_id: str) -> dict[str, Any]:
    if spec_id not in state["specs"]:
        raise ValueError("unknown spec id")
    return state["specs"][spec_id]


# -- Prototype Builder -------------------------------------------------------
def _freeze(root: Path, base: Path, raw: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    spec = templates.SPEC.validate_python(raw)
    if spec.spec_id in state["specs"]:
        raise _DuplicateSpec("spec_id already frozen; draft under a new id")
    input_path = (base / spec.input.path).resolve()
    payload = _read_bytes(input_path, MAX_INPUT_BYTES)
    if _sha(payload) != spec.input.sha256:
        raise ValueError("input sha256 does not match the spec")
    raw_input = _parse(payload)
    summary = _validate_input(spec.template, raw_input)
    if spec.template == "OVERLAY-v1":
        _check_quote_file(raw_input, input_path.parent)
    if summary["symbol"] != spec.symbol:
        raise ValueError("input symbol differs from the spec")
    if summary["first"] > spec.evaluation.development_end or summary["last"] < spec.evaluation.holdout_end:
        raise ValueError("input must cover the development window and the whole holdout")
    frozen = spec.model_dump(mode="json")
    frozen["input"]["path"] = _portable(input_path, root)
    engine_sha = None
    if spec.template != "OVERLAY-v1":
        engine = (base / spec.engine).resolve()
        engine_sha = _sha(_read_bytes(engine, MAX_ENGINE_BYTES))
        frozen["engine"] = _portable(engine, root)
    return _receipt("frozen_spec", spec.spec_id, spec=frozen, spec_sha256=research.digest(frozen), input_sha256=spec.input.sha256,
                    engine_sha256=engine_sha, classification=summary["classification"],
                    pricing_mode=spec.overlay.pricing_mode if spec.template == "OVERLAY-v1" else None,
                    grid=templates.grid_points(spec), probe_point=templates.probe_point(spec),
                    foundry_version=FOUNDRY_VERSION, llm_calls=0, execution_authorized=False)


def draft(spec_path: Path | str, state_dir: Path | str, *, now: Clock = utc_now) -> dict[str, Any]:
    """Freeze a valid spec (SPEC_FROZEN) or record why it was refused (SPEC_REJECTED)."""
    root, spec_file = Path(state_dir).resolve(), Path(spec_path).resolve()
    with exclusive_lock(root):
        state = ledger.fold_state(root)
        payload = _read_bytes(spec_file, MAX_SPEC_BYTES)
        raw: Any = None
        try:
            raw = _parse(payload)
            frozen = _freeze(root, spec_file.parent, raw, state)
        except _DuplicateSpec:
            raise
        except (ValueError, ArithmeticError, UnicodeError, RecursionError, OSError) as error:
            candidate = raw.get("spec_id") if isinstance(raw, dict) else None
            valid = isinstance(candidate, str) and re.fullmatch(templates.SPEC_ID_PATTERN, candidate) and candidate not in state["specs"]
            spec_id = candidate if valid else f"rejected-{_sha(payload)[:12]}"
            receipt = ledger.put_receipt(root, _receipt("spec_rejection", spec_id, input_sha256=_sha(payload), reason=_reason(error)))
            return _append(root, now, spec_id, "prototype_builder", "SPEC_REJECTED", None, None, [_reason(error)], receipt)
        return _append(root, now, frozen["spec_id"], "prototype_builder", "SPEC_FROZEN", None, "PROBE", [], ledger.put_receipt(root, frozen))


# -- Maintainer and owner ----------------------------------------------------
def _sessions_missed(last: date, moment: datetime) -> int:
    """Completed XNYS sessions after the last observed one, as of ``moment``."""
    import exchange_calendars as calendars

    start = last + timedelta(days=1)
    if start > moment.date():
        return 0
    # The calendar must extend past a weekend or holiday as_of, or the range query is out of bounds.
    calendar = calendars.get_calendar("XNYS", start=str(last), end=str(moment.date() + timedelta(days=7)))
    return sum(1 for session in calendar.sessions_in_range(str(start), str(moment.date()))
               if research.utc(calendar.session_close(session).to_pydatetime()) <= moment)


def observe(state_dir: Path | str, spec_id: str, input_path: Path | str, as_of: str | datetime, *, now: Clock = utc_now) -> dict[str, Any]:
    """STALE_DATA, SOURCE_REVISED, DECAY_DRAWDOWN and DECAY_RETURN; any failure requests a pause."""
    root, path = Path(state_dir).resolve(), Path(input_path).resolve()
    with exclusive_lock(root):
        spec_state = _spec(ledger.fold_state(root), spec_id)
        if spec_state["status"] in ledger.TERMINAL:
            raise ValueError("terminal spec; nothing to maintain")
        moment = research.utc(as_of)
        if moment > research.utc(now()):
            raise ValueError("as_of is in the future")
        payload = _read_bytes(path, MAX_INPUT_BYTES)
        raw = _parse(payload)
        summary = _validate_input(spec_state["template"], raw)
        if summary["symbol"] != spec_state["symbol"]:
            raise ValueError("observation symbol differs from the spec")
        overlay = templates.TEMPLATES[spec_state["template"]].kind == "overlay"
        evidence = _overlay_evidence(raw, path.parent) if overlay else []
        times = [research.utc(bar["available_at"]) for bar in summary["bars"].values()] + [available for _, available, _ in evidence]
        if max(times) > moment:
            raise ValueError("observation holds data not available at as_of; non-causal input rejected")
        missed = _sessions_missed(summary["last"], moment)
        checks: dict[str, Any] = {"STALE_DATA": {"failed": missed > MAX_STALE_SESSIONS, "completed_sessions_missing": missed,
                                                 "maximum": MAX_STALE_SESSIONS, "last_session": summary["last"].isoformat()}}
        ctx = None
        try:
            ctx = _context(root, spec_state)
            frozen_summary = _validate_input(spec_state["template"], ctx.raw)
            frozen_bars = frozen_summary["bars"]
            revised = {day for day, bar in frozen_bars.items() if summary["bars"].get(day) != bar}
            if overlay:  # quotes, dividends and IV marks are evidence too
                try:
                    before = _by_session(_overlay_evidence(ctx.raw, ctx.base_dir), frozen_summary["last"])
                except (OSError, ValueError) as error:
                    raise _Blocked(["FROZEN_INPUT_UNREADABLE"]) from error
                after = _by_session(evidence, frozen_summary["last"])
                revised |= {day.isoformat() for day in set(before) | set(after) if before.get(day) != after.get(day)}
            ordered = sorted(revised)
            checks["SOURCE_REVISED"] = {"failed": bool(ordered), "compared_sessions": len(frozen_bars),
                                        "compared_inputs": ["bars", "option_quotes", "dividends", "iv_marks"] if overlay else ["bars"],
                                        "revised_or_missing_sessions": len(ordered), "first_revised": ordered[0] if ordered else None}
        except _Blocked as blocked:  # without the frozen evidence nothing can be ruled out
            checks["FROZEN_INPUTS_UNVERIFIED"] = {"failed": True, "reasons": blocked.reasons}
        holdout = spec_state["holdout"]
        limit = None if ctx is None else ctx.spec.evaluation.maximum_forward_drawdown
        checks["DECAY_DRAWDOWN"] = {"applicable": False, "failed": False, "limit": limit}
        checks["DECAY_RETURN"] = {"applicable": False, "failed": False, "minimum_sessions": DECAY_MIN_FORWARD_SESSIONS}
        if ctx is not None and spec_state["stage"] == "PAPER" and holdout is not None:
            try:
                rows, _ = _replay(replace(ctx, raw=raw, base_dir=path.parent, prepared={}), holdout["point"], summary["last"])
                forward = [value for day, value, _ in rows if ledger.day(day) > ctx.spec.evaluation.holdout_end]
                compounded = research._compound(forward) if forward else 0.0
                drawdown = _drawdown(forward)
                checks["DECAY_DRAWDOWN"].update(applicable=True, failed=drawdown < -ctx.spec.evaluation.maximum_forward_drawdown,
                                                forward_sessions=len(forward), max_drawdown=drawdown)
                checks["DECAY_RETURN"].update(applicable=True, failed=len(forward) >= DECAY_MIN_FORWARD_SESSIONS and compounded < 0,
                                              forward_sessions=len(forward), compounded=compounded)
            except IntegrityError:
                raise
            except Exception as error:
                checks["FORWARD_REPLAY_FAILED"] = {"failed": True, "reason": _reason(error)}
        reasons = [name for name, check in checks.items() if check["failed"]]
        receipt = ledger.put_receipt(root, _receipt("check", spec_id, as_of=ledger.stamp(moment), input_sha256=_sha(payload),
                                                    checks=checks, reasons=reasons))
        stage = spec_state["stage"]
        if reasons:
            return _append(root, now, spec_id, "maintainer", "PAUSE_REQUESTED", stage, stage, reasons, receipt)
        return _append(root, now, spec_id, "maintainer", "MAINTAINER_CHECK", stage, stage, [], receipt, status=spec_state["status"])


def resume(state_dir: Path | str, spec_id: str, *, now: Clock = utc_now) -> dict[str, Any]:
    """The owner's explicit resume; the agents can never do this themselves."""
    root = Path(state_dir).resolve()
    with exclusive_lock(root):
        spec_state = _spec(ledger.fold_state(root), spec_id)
        if spec_state["status"] not in ("PAUSED", "AWAITING_HUMAN_RESUME"):
            raise ValueError("only a paused or awaiting spec can be resumed")
        stage = spec_state["stage"]
        return _append(root, now, spec_id, "human", "HUMAN_RESUMED", stage, stage, [], None, status=ledger.resumed_status(spec_state))


def export(state_dir: Path | str, output: Path | str) -> dict[str, Any]:
    """Verified local export (snake_case); the owner's idea text is omitted. Never overwrites."""
    state = ledger.fold_state(Path(state_dir).resolve())
    specs = {}
    for spec_id, spec in state["specs"].items():
        frozen = {**spec["frozen"], "spec": {key: value for key, value in spec["frozen"]["spec"].items() if key != "idea"}}
        specs[spec_id] = {**{key: value for key, value in spec.items() if key != "frozen"}, "frozen": frozen}
    value = {"schema_version": EXPORT_VERSION, "head_sha256": state["head_sha256"], "event_count": len(state["events"]),
             "events": state["events"], "specs": specs, "rejected_drafts": state["rejected_drafts"], "trials_total": len(state["trials"]),
             "llm_calls": 0, "execution_authorized": False, "options_execution_enabled": False}
    research.write_new(Path(output), value)
    return value


# -- publication -------------------------------------------------------------
def _instant(value: str) -> datetime:
    return datetime.combine(date.fromisoformat(value), datetime.min.time(), timezone.utc) if len(value) == 10 else research.utc(value)


def _evidence_times(value: dict[str, Any]) -> list[str]:
    times: list[str] = []
    if value["overlay"]["status"] == "PUBLISHED":
        artifact = value["overlay"]["artifact"]
        times += [artifact["observationCutoff"], artifact["availabilityCutoff"], artifact["coverage"]["start"], artifact["coverage"]["end"]]
        times += [cycle["opened"] for cycle in artifact["cycles"]]
    if value["ledger"]["status"] == "PUBLISHED":
        times += [event["at"] for event in value["ledger"]["ledger"]["events"]]
    return times


def publication(*, overlay: dict[str, Any] | None, ledger_section: dict[str, Any] | None, rights_confirmed: bool,
                generated_at: str | None) -> dict[str, Any]:
    """The exact camelCase ``leo-foundry-publication.v1`` document."""
    published = overlay is not None or ledger_section is not None
    if published and not rights_confirmed:
        raise ValueError("refusing to publish derived results without --rights-confirmed")
    if published and generated_at is None:
        raise ValueError("published sections need a generation time")
    value = {
        "schemaVersion": PUBLICATION_VERSION, "generatedAt": generated_at if published else None,
        "executionAuthorized": False, "optionsExecutionEnabled": False, "liveStagesLocked": True, "llmCalls": 0,
        "derivedPublicationRightsConfirmed": bool(rights_confirmed),
        "roles": copy.deepcopy(list(templates.ROLES)), "ladder": copy.deepcopy(list(templates.LADDER)),
        "overlay": {"status": "PUBLISHED", "artifact": overlay} if overlay is not None else dict(OVERLAY_PENDING),
        "ledger": {"status": "PUBLISHED", "ledger": ledger_section} if ledger_section is not None else dict(LEDGER_PENDING),
    }
    if overlay is not None and overlay["pricingMode"] == "MODEL_PRICED" and overlay["evidenceStatus"] != overlay_engine.MODEL_LABEL:
        raise ValueError("model-priced overlays must stay labelled MODEL_PRICED_NOT_EXECUTABLE")
    if published:
        limit = research.utc(generated_at) + TIME_TOLERANCE  # type: ignore[arg-type]
        if any(_instant(item) > limit for item in _evidence_times(value)):
            raise ValueError("evidence timestamps follow the publication time")
    return value


def publication_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def _write_publication(path: Path, value: dict[str, Any]) -> None:
    _write_bytes(path, publication_bytes(value), replace=True)
    path.chmod(0o644)  # static site builds read it; mkstemp files start private


def publish(output: Path | str, *, state_dir: Path | str | None = None, overlay_artifact: Path | str | None = None,
            rights_confirmed: bool = False, public_symbols: bool = False, generated_at: str | None = None,
            now: Clock = utc_now) -> dict[str, Any]:
    """Write the deterministic publication; pending sections when no evidence is supplied."""
    if (state_dir is not None or overlay_artifact is not None) and not rights_confirmed:
        raise ValueError("refusing to publish derived results without --rights-confirmed")
    overlay = None
    if overlay_artifact is not None:
        artifact = _parse(_read_bytes(Path(overlay_artifact), MAX_INPUT_BYTES))
        evidence = (artifact.get("source") or {}).get("evidence") or {}
        if artifact.get("evidence_status") == SYNTHETIC or evidence.get("classification") != "observed":
            raise ValueError("synthetic fixtures are never published as market evidence")
        overlay = overlay_report.public_projection(artifact, public_symbol=public_symbols)
    ledger_section = None if state_dir is None else ledger.ledger_public(Path(state_dir).resolve(), public_symbols=public_symbols)
    published = overlay is not None or ledger_section is not None
    moment = (ledger.stamp(research.utc(generated_at)) if generated_at else ledger.stamp(now())) if published else None
    value = publication(overlay=overlay, ledger_section=ledger_section, rights_confirmed=rights_confirmed, generated_at=moment)
    _write_publication(Path(output), value)
    return value


# -- deterministic synthetic fixture (contract drift test only; never shipped) --
SYNTHETIC_GENERATED_AT = "2026-10-01T13:00:00+00:00"
_SYNTHETIC_CLOCK = datetime(2026, 10, 1, 12, 0, tzinfo=timezone.utc)


class StepClock:
    """Deterministic clock: each call returns the next minute."""

    def __init__(self, start: datetime, step: timedelta = timedelta(minutes=1)) -> None:
        self.current, self.step = start, step

    def __call__(self) -> datetime:
        value = self.current
        self.current += self.step
        return value


def _synthetic_inputs(folder: Path) -> Path:
    """Write a synthetic overlay source and quote file. Not market data; classification synthetic_fixture."""
    import exchange_calendars as calendars

    calendar = calendars.get_calendar("XNYS", start="2023-07-03", end="2024-09-30")
    schedule = calendar.schedule.loc["2023-07-03":"2024-06-28"]
    rng = random.Random(20230703)
    price, closes = 100.0, []
    for _ in range(len(schedule)):
        closes.append(round(price, 2))
        price *= math.exp(0.0002 + 0.008 * rng.gauss(0, 1))
    expiries = []
    for year, month in [(2023, m) for m in range(7, 13)] + [(2024, m) for m in range(1, 10)]:
        friday = next(date(year, month, day) for day in range(15, 22) if date(year, month, day).weekday() == 4)
        expiries.append(calendar.date_to_session(friday, direction="previous").date())
    strikes = [2.5 * step for step in range(math.floor(min(closes) * 0.85 / 2.5), math.ceil(max(closes) * 1.2 / 2.5) + 1)]
    bars, rows, previous = [], [], closes[0]
    for (timestamp, session), close in zip(schedule.iterrows(), closes, strict=True):
        day, close_at = timestamp.date(), session["close"].to_pydatetime()
        bars.append({"session_date": day.isoformat(), "available_at": ledger.stamp(close_at + timedelta(minutes=1)),
                     "open": f"{previous:.2f}", "high": f"{max(previous, close) + 0.4:.2f}", "low": f"{min(previous, close) - 0.4:.2f}",
                     "close": f"{close:.2f}", "volume": 100000})
        previous = close
        for expiry in expiries:
            days = (expiry - day).days
            if not 1 <= days <= 70:
                continue
            for strike in strikes:
                value = black_scholes(close, strike, days, 0.22, "call", rate=0.04)
                rows.append({"session_date": day.isoformat(), "observed_at": ledger.stamp(close_at - timedelta(minutes=5)),
                             "available_at": ledger.stamp(close_at + timedelta(minutes=1)),
                             "contract": f"ZZSYN{expiry:%y%m%d}C{round(strike * 1000):08d}", "expiry": expiry.isoformat(),
                             "strike": f"{strike:.2f}", "right": "call", "bid": f"{max(0.01, value['premium'] * 0.98 - 0.01):.2f}",
                             "ask": f"{value['premium'] * 1.02 + 0.02:.2f}", "multiplier": "100", "delta": f"{value['delta']:.4f}",
                             "source": "synthetic_quote_fixture"})
    folder.mkdir(parents=True, exist_ok=True)
    quotes = folder / "synthetic-quotes.csv"
    with quotes.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    quote_sha = _sha(quotes.read_bytes())
    source = {"schema_version": "leo-overlay-source.v1", "symbol": "ZZSYN", "code_revision": FOUNDRY_VERSION,
              "evidence": {"source": "Deterministic synthetic fixture (not market data)", "dataset_sha256": quote_sha,
                           "calendar_source": "pending_official_verification", "adjustment_verified": True, "coverage_verified": False,
                           "availability_verified": True, "classification": "synthetic_fixture", "license_scope": "Contract drift test only"},
              "bars": bars, "corporate_actions": {"splits": []}, "dividend_policy": "excluded_price_only", "dividends": [],
              "option_quotes": {"path": quotes.name, "sha256": quote_sha}, "iv_marks": None}
    path = folder / "synthetic-overlay-source.json"
    path.write_bytes(_json_bytes(source))
    return path


def _synthetic_overlay_base() -> dict[str, Any]:
    return {"shares": 100, "pricing_mode": "EXECUTABLE_QUOTES", "min_dte": 20, "max_dte": 50, "max_spread_fraction": 0.5,
            "model": None, "costs": {"commission_per_contract": "0.65", "share_slippage_bps": 2}}


def synthetic_publication() -> dict[str, Any]:
    """Publication built from deterministic synthetic inputs. Bypasses the synthetic refusal; never ship it."""
    with tempfile.TemporaryDirectory(prefix="leo-foundry-fixture-") as temporary:
        folder = Path(temporary).resolve()
        source_path = _synthetic_inputs(folder / "inputs")
        base = _synthetic_overlay_base()
        config = {"schema_version": "leo-overlay-config.v1", "structure": "covered_call", "shares": base["shares"],
                  "pricing_mode": base["pricing_mode"], "call_rule": {"kind": "otm_pct", "value": 0.05}, "put_rule": None,
                  "target_dte": 30, "min_dte": base["min_dte"], "max_dte": base["max_dte"],
                  "max_spread_fraction": base["max_spread_fraction"], "model": None, "costs": base["costs"]}
        artifact = overlay_engine.run_overlay(_parse(source_path.read_bytes()), config, base_dir=source_path.parent, resamples=200)
        overlay = overlay_report.public_projection(artifact)
        if overlay["evidenceStatus"] != SYNTHETIC:
            raise AssertionError("the drift fixture must stay labelled synthetic")
        spec = {"schema_version": templates.SPEC_VERSION, "spec_id": "synthetic-covered-call", "template": "OVERLAY-v1",
                "symbol": "ZZSYN", "idea": "Synthetic drift fixture: sell monthly out-of-the-money calls against a held position.",
                "input": {"path": source_path.name, "sha256": _sha(source_path.read_bytes())},
                "evaluation": {"development_end": "2024-03-28", "holdout_start": "2024-04-01", "holdout_end": "2024-06-28",
                               "minimum_dev_sessions": 60, "minimum_holdout_sessions": 40, "maximum_forward_drawdown": 0.2},
                "inference": {"seed": 7, "resamples": 200},
                "sweep": {"structure": "covered_call", "call_otm_pct": [0.03, 0.05, 0.08], "target_dte": [30]}, "overlay": base}
        rejected = copy.deepcopy(spec)
        rejected.update(spec_id="synthetic-rejected-draft", sweep={**spec["sweep"], "call_otm_pct": [0.04]})
        state, clock = folder / "state", StepClock(_SYNTHETIC_CLOCK)
        for name, value in (("rejected-spec.json", rejected), ("spec.json", spec)):
            (folder / "inputs" / name).write_bytes(_json_bytes(value))
            draft(folder / "inputs" / name, state, now=clock)
        advance(state, until_blocked=True, now=clock)
        ledger_section = ledger.ledger_public(state, allow_synthetic=True)
    return publication(overlay=overlay, ledger_section=ledger_section, rights_confirmed=True, generated_at=SYNTHETIC_GENERATED_AT)


def write_synthetic_fixture(path: Path | str) -> None:
    _write_publication(Path(path), synthetic_publication())
