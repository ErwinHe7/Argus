"""Append-only, hash-chained foundry ledger. Every read verifies the chain and receipts.

Layout under ``state_dir``: ``events/00000001.json`` (``leo-foundry-event.v1``,
each naming its predecessor's sha256), content-addressed ``receipts/<sha256>.json``,
``trials/<trial key>.json`` addressed by trial identity, ``proposals/<spec>/`` and
an optional ``STOP`` file. State is a pure fold over events. Editing, reordering
or removing an interior event, or editing a receipt, trial or proposal file,
raises ``IntegrityError``. The newest events have no later link, so truncating
the chain or editing fields the fold does not re-check on the last event is
detected only against an externally recorded head (``head_sha256`` in an
export, ``headSha256`` in a publication). No network, LLM client, broker or
order path exists here.
"""
from __future__ import annotations

import re
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Callable

from ..strategy_lab.continuous import IntegrityError, _json_bytes, _parse, _read_bytes, _sha, _write_new
from ..strategy_lab.research import utc
from . import templates

EVENT_VERSION = "leo-foundry-event.v1"
RECEIPT_VERSION = "leo-foundry-receipt.v1"
TRIAL_VERSION = "leo-foundry-trial.v1"
GENESIS = "0" * 64
MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_PUBLIC_EVENTS = 50
STATUSES = ("ACTIVE", "AWAITING_HUMAN_RESUME", "FORWARD_SHADOW", "PAUSED", "REJECTED_NO_DEPLOYABLE_EDGE", "BLOCKED")
TERMINAL = ("REJECTED_NO_DEPLOYABLE_EDGE", "BLOCKED")
ACTORS = templates.ROLE_IDS + ("human",)
# kind -> (allowed roles, resulting status or None when the fold decides, allowed receipt kinds)
KINDS: dict[str, tuple[tuple[str, ...], str | None, tuple[str | None, ...]]] = {
    "SPEC_FROZEN": (("prototype_builder",), "ACTIVE", ("frozen_spec",)),
    "SPEC_REJECTED": (("prototype_builder",), "BLOCKED", ("spec_rejection",)),
    "PROBE_COMPLETED": (("sweeper",), "ACTIVE", ("probe",)),
    "BACKTEST_COMPLETED": (("sweeper",), "ACTIVE", ("backtest",)),
    "PROMOTED": (("grower",), "ACTIVE", ("grower",)),
    "HOLDOUT_EVALUATED": (("grower",), "ACTIVE", ("holdout",)),
    "PAPER_PROPOSAL_ISSUED": (("grower",), "AWAITING_HUMAN_RESUME", ("proposal",)),
    "FORWARD_SHADOW_STARTED": (("grower",), "FORWARD_SHADOW", ("forward_shadow",)),
    "MAINTAINER_CHECK": (("maintainer",), None, ("check",)),
    "PAUSE_REQUESTED": (("maintainer",), "PAUSED", ("check",)),
    "HUMAN_RESUMED": (("human",), None, (None,)),
    "REJECTED_NO_DEPLOYABLE_EDGE": (("sweeper", "grower"), "REJECTED_NO_DEPLOYABLE_EDGE", ("probe", "backtest", "grower", "holdout")),
    "BLOCKED": (("sweeper", "grower"), "BLOCKED", (None, "blocked", "grower")),
}
EVENT_KEYS = {"schema_version", "seq", "at", "prev_sha256", "spec_id", "role", "kind", "from_stage", "to_stage",
              "status", "reasons", "receipt"}
_RECEIPT = re.compile(r"^receipts/([a-f0-9]{64})\.json$")
_PROPOSAL = re.compile(r"^proposals/[a-z0-9][a-z0-9_-]{0,63}/(research-report|proposal)\.json$")
_TRIAL = re.compile(r"^[a-f0-9]{64}$")
_EVENT = re.compile(r"^(\d{8})\.json$")
Clock = Callable[[], datetime]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def stamp(value: datetime) -> str:
    """Second-precision UTC ISO-8601 with an explicit +00:00 offset."""
    return utc(value).replace(microsecond=0).isoformat()


def resumed_status(spec: dict[str, Any]) -> str:
    return "FORWARD_SHADOW" if spec["template"] == "OVERLAY-v1" and spec["stage"] == "PAPER" else "ACTIVE"


# -- content-addressed files -------------------------------------------------
def put_receipt(root: Path, value: dict[str, Any]) -> dict[str, str]:
    payload = _json_bytes(value)
    sha = _sha(payload)
    path = root / "receipts" / f"{sha}.json"
    if path.exists():
        if _read_bytes(path, MAX_FILE_BYTES) != payload:
            raise IntegrityError("content-addressed receipt differs from its name")
    else:
        _write_new(path, value)
    return {"file": f"receipts/{sha}.json", "sha256": sha}


def read_receipt(root: Path, reference: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(reference, dict) or set(reference) != {"file", "sha256"}:
        raise IntegrityError("malformed receipt reference")
    match = _RECEIPT.match(str(reference["file"]))
    if match is None or match.group(1) != reference["sha256"]:
        raise IntegrityError("receipt reference is not content-addressed")
    return _verified(root / reference["file"], reference["sha256"], "receipt")


def _verified(path: Path, sha: str, label: str) -> dict[str, Any]:
    try:
        payload = _read_bytes(path, MAX_FILE_BYTES)
    except FileNotFoundError as error:
        raise IntegrityError(f"recorded {label} is missing") from error
    if _sha(payload) != sha:
        raise IntegrityError(f"recorded {label} hash mismatch")
    return _parse(payload)


def read_trial(root: Path, key: str) -> tuple[dict[str, Any], str] | None:
    path = root / "trials" / f"{key}.json"
    if not path.exists():
        return None
    payload = _read_bytes(path, MAX_FILE_BYTES)
    value = _parse(payload)
    if value.get("schema_version") != TRIAL_VERSION or value.get("trial_key") != key or _sha(_json_bytes(value["identity"])) != key:
        raise IntegrityError("trial receipt does not match its content-addressed identity")
    return value, _sha(payload)


def write_trial(root: Path, value: dict[str, Any]) -> str:
    key = value["trial_key"]
    if not _TRIAL.match(key) or _sha(_json_bytes(value["identity"])) != key:
        raise ValueError("trial key must address its identity")
    _write_new(root / "trials" / f"{key}.json", value)
    return _sha(_json_bytes(value))


def write_proposal_file(root: Path, spec_id: str, name: str, value: dict[str, Any]) -> dict[str, str]:
    relative = f"proposals/{spec_id}/{name}"
    if not _PROPOSAL.match(relative):
        raise ValueError("unsupported proposal file")
    payload = _json_bytes(value)
    path = root / relative
    if path.exists():
        if _read_bytes(path, MAX_FILE_BYTES) != payload:
            raise IntegrityError("existing proposal file differs; refusing a replacement")
    else:
        _write_new(path, value)
    return {"file": relative, "sha256": _sha(payload)}


# -- event chain -------------------------------------------------------------
def read_events(root: Path) -> list[tuple[dict[str, Any], str]]:
    """Every event with its file sha256, after verifying names, chain and shape."""
    directory = root / "events"
    if not directory.exists():
        return []
    names = sorted(path.name for path in directory.iterdir() if not path.name.startswith(".pending-"))
    events: list[tuple[dict[str, Any], str]] = []
    previous = GENESIS
    previous_at: datetime | None = None
    for index, name in enumerate(names, start=1):
        match = _EVENT.match(name)
        if match is None or int(match.group(1)) != index:
            raise IntegrityError("event files must be a contiguous 00000001.json sequence")
        payload = _read_bytes(directory / name, MAX_FILE_BYTES)
        try:
            event = _parse(payload)
        except ValueError as error:
            raise IntegrityError("unreadable ledger event") from error
        _check_shape(event)
        if event["seq"] != index or event["prev_sha256"] != previous:
            raise IntegrityError("ledger hash chain broken")
        at = utc(event["at"])
        if previous_at is not None and at < previous_at:
            raise IntegrityError("ledger timestamps run backwards")
        previous, previous_at = _sha(payload), at
        events.append((event, previous))
    return events


def _check_shape(event: dict[str, Any]) -> None:
    if set(event) != EVENT_KEYS or event["schema_version"] != EVENT_VERSION:
        raise IntegrityError("unexpected ledger event shape")
    if event["kind"] not in KINDS or event["role"] not in ACTORS or event["status"] not in STATUSES:
        raise IntegrityError("unknown event kind, role or status")
    for field in ("from_stage", "to_stage"):
        if event[field] is not None and event[field] not in templates.STAGES:
            raise IntegrityError("events may only name PROBE, BACKTEST or PAPER; live stages are locked")
    if (not isinstance(event["seq"], int) or not isinstance(event["reasons"], list)
            or not all(isinstance(reason, str) and 0 < len(reason) <= 2000 for reason in event["reasons"])):
        raise IntegrityError("malformed event fields")
    try:
        utc(event["at"])
    except (TypeError, ValueError) as error:
        raise IntegrityError("event time must be timezone-aware ISO-8601") from error


def _apply(root: Path, state: dict[str, Any], event: dict[str, Any]) -> None:
    """Fold one event into state, rejecting transitions the agents can never produce."""
    kind, spec_id = event["kind"], event["spec_id"]
    roles, status, receipt_kinds = KINDS[kind]
    if event["role"] not in roles:
        raise IntegrityError(f"{event['role']} cannot record {kind}")
    receipt = read_receipt(root, event["receipt"]) if event["receipt"] is not None else None
    receipt_kind = receipt.get("kind") if receipt is not None else None
    if receipt_kind not in receipt_kinds or (receipt is not None and (receipt.get("schema_version") != RECEIPT_VERSION
                                                                     or receipt.get("spec_id") != spec_id)):
        raise IntegrityError(f"{kind} carries an unexpected receipt")
    specs = state["specs"]
    if kind in ("SPEC_FROZEN", "SPEC_REJECTED"):
        if spec_id in specs or event["from_stage"] is not None or event["to_stage"] != ("PROBE" if kind == "SPEC_FROZEN" else None) \
                or event["status"] != status:
            raise IntegrityError("invalid spec admission event")
        if kind == "SPEC_REJECTED":
            state["rejected_drafts"].append(spec_id)
            return
        assert receipt is not None
        specs[spec_id] = {"spec_id": spec_id, "template": receipt["spec"]["template"], "symbol": receipt["spec"]["symbol"],
                          "classification": receipt["classification"], "pricing_mode": receipt.get("pricing_mode"),
                          "stage": "PROBE", "status": "ACTIVE", "frozen": receipt, "probe": None, "backtest": None,
                          "grower": None, "holdout": None, "proposal": None, "shadow": None, "last_check": None, "trial_keys": []}
        return
    spec = specs.get(spec_id)
    if spec is None or spec["status"] in TERMINAL or event["from_stage"] != spec["stage"]:
        raise IntegrityError("event does not continue its spec's current stage")
    target = event["to_stage"]
    if target is None:
        if kind not in ("REJECTED_NO_DEPLOYABLE_EDGE", "BLOCKED"):
            raise IntegrityError("only terminal events may omit the next stage")
    elif target != spec["stage"]:
        if templates.TRANSITIONS.get(spec["stage"]) != target or kind not in ("PROBE_COMPLETED", "PROMOTED"):
            raise IntegrityError("stage change outside the transition table")
        if target == "PAPER" and not _paper_allowed(spec):
            raise IntegrityError("this template or evidence is capped at BACKTEST")
    elif kind in ("PROBE_COMPLETED", "PROMOTED"):
        raise IntegrityError("promotion events must change stage")
    if status is None:
        status = spec["status"] if kind == "MAINTAINER_CHECK" else resumed_status(spec)
        if kind == "HUMAN_RESUMED" and spec["status"] not in ("PAUSED", "AWAITING_HUMAN_RESUME"):
            raise IntegrityError("only a paused or awaiting spec can be resumed")
    if event["status"] != status:
        raise IntegrityError(f"{kind} must record status {status}")
    if spec["status"] != "ACTIVE" and kind not in ("MAINTAINER_CHECK", "PAUSE_REQUESTED", "HUMAN_RESUMED"):
        raise IntegrityError("only the Maintainer or the owner act on a non-active spec")
    _record(root, spec, kind, receipt)
    spec["stage"] = target or spec["stage"]
    spec["status"] = status


def _paper_allowed(spec: dict[str, Any]) -> bool:
    template = templates.TEMPLATES[spec["template"]]
    return (template.max_stage == "PAPER" and spec["classification"] == "observed"
            and spec["pricing_mode"] in (None, "EXECUTABLE_QUOTES"))


def _record(root: Path, spec: dict[str, Any], kind: str, receipt: dict[str, Any] | None) -> None:
    if receipt is None:
        return
    receipt_kind = receipt["kind"]
    if receipt_kind == "probe":
        if spec["probe"] is not None:
            raise IntegrityError("probe already recorded")
        _trial_hashes(root, spec, [receipt["trial"]])
        spec["probe"] = receipt
    elif receipt_kind == "backtest":
        if spec["probe"] is None or spec["backtest"] is not None:
            raise IntegrityError("backtest out of order")
        _trial_hashes(root, spec, [{"key": row["trial_key"], "sha256": row["trial_sha256"]} for row in receipt["trials"]])
        spec["backtest"] = receipt
    elif receipt_kind == "holdout":
        if spec["holdout"] is not None or spec["backtest"] is None:
            raise IntegrityError("the holdout is evaluated exactly once, after the backtest")
        spec["holdout"] = receipt
    elif receipt_kind == "grower":
        if spec["backtest"] is None or (kind == "PROMOTED" and not (spec["holdout"] or {}).get("passed")):
            raise IntegrityError("promotion requires a passed holdout")
        spec["grower"] = receipt
    elif receipt_kind == "proposal":
        if spec["stage"] != "PAPER" or templates.TEMPLATES[spec["template"]].kind != "strategy":
            raise IntegrityError("paper proposals are issued only for promoted MR/MOM specs")
        for item in receipt["files"]:
            if not _PROPOSAL.match(str(item["file"])) or not str(item["file"]).startswith(f"proposals/{spec['spec_id']}/"):
                raise IntegrityError("unsafe proposal file reference")
            _verified(root / item["file"], item["sha256"], "proposal file")
        spec["proposal"] = receipt
    elif receipt_kind == "forward_shadow":
        if spec["stage"] != "PAPER" or spec["template"] != "OVERLAY-v1":
            raise IntegrityError("forward shadow applies only to promoted overlays")
        spec["shadow"] = receipt
    elif receipt_kind == "check":
        spec["last_check"] = receipt


def _trial_hashes(root: Path, spec: dict[str, Any], references: list[dict[str, Any]]) -> None:
    for reference in references:
        if not _TRIAL.match(str(reference["key"])):
            raise IntegrityError("malformed trial key")
        value = _verified(root / "trials" / f"{reference['key']}.json", reference["sha256"], "trial")
        if value.get("trial_key") != reference["key"] or _sha(_json_bytes(value["identity"])) != reference["key"]:
            raise IntegrityError("trial receipt does not match its identity")
        if reference["key"] not in spec["trial_keys"]:
            spec["trial_keys"].append(reference["key"])


def _empty() -> dict[str, Any]:
    return {"events": [], "head_sha256": None, "specs": {}, "rejected_drafts": []}


def fold_state(root: Path) -> dict[str, Any]:
    """Verified state: events, head hash and per-spec stage/status with their receipts."""
    state = _empty()
    for event, sha in read_events(root):
        _apply(root, state, event)
        state["events"].append(event)
        state["head_sha256"] = sha
    state["trials"] = sorted({key for spec in state["specs"].values() for key in spec["trial_keys"]})
    return state


def append(root: Path, *, now: Clock, spec_id: str, role: str, kind: str, from_stage: str | None, to_stage: str | None,
           status: str, reasons: list[str], receipt: dict[str, str] | None) -> dict[str, Any]:
    """Validate against the folded state, then publish the next event without clobbering."""
    state = fold_state(root)
    at = stamp(now())
    if state["events"] and utc(at) < utc(state["events"][-1]["at"]):
        raise ValueError("clock moved backwards; refusing to append to the ledger")
    event = {"schema_version": EVENT_VERSION, "seq": len(state["events"]) + 1, "at": at,
             "prev_sha256": state["head_sha256"] or GENESIS, "spec_id": spec_id, "role": role, "kind": kind,
             "from_stage": from_stage, "to_stage": to_stage, "status": status, "reasons": list(reasons), "receipt": receipt}
    try:
        _check_shape(event)
        _apply(root, state, event)
    except IntegrityError as error:
        raise ValueError(f"refusing an invalid ledger transition: {error}") from error
    _write_new(root / "events" / f"{event['seq']:08d}.json", event)
    return event


# -- public projection -------------------------------------------------------
def _spec_rows(spec: dict[str, Any]) -> tuple[int, int]:
    if spec["backtest"] is not None:
        return spec["backtest"]["family_trial_count"], len(spec["backtest"]["survivors"])
    return (1 if spec["probe"] is not None else 0), 0


def _gates(spec: dict[str, Any]) -> list[dict[str, Any]]:
    frozen = spec["frozen"]
    gates = [{"id": "spec_frozen", "passed": True,
              "detail": f"{spec['template']} spec frozen with {len(frozen['grid'])} predeclared grid points and 0 LLM calls."}]
    probe = spec["probe"]
    if probe is not None:
        gates.append({"id": "probe_positive", "passed": probe["passed"],
                      "detail": f"Development baseline over {probe['sessions']} sessions: "
                                + ("positive compounded statistic." if probe["passed"] else ", ".join(probe["reasons"]).lower().replace("_", " ") + ".")})
    backtest = spec["backtest"]
    if backtest is not None:
        gates.append({"id": "bh_survivors", "passed": bool(backtest["survivors"]),
                      "detail": f"{len(backtest['survivors'])} of {backtest['family_trial_count']} development trials survived "
                                f"Benjamini-Hochberg at {backtest['alpha']:g} with a positive statistic and bootstrap lower bound."})
    if spec["grower"] is not None:
        gates.extend({"id": gate["id"], "passed": gate["passed"], "detail": gate["detail"]} for gate in spec["grower"]["gates"])
    holdout = spec["holdout"]
    if holdout is not None:
        gates.append({"id": "holdout_once", "passed": holdout["passed"],
                      "detail": f"Holdout evaluated once over {holdout['sessions']} sessions: "
                                + ("positive compounded statistic." if holdout["passed"] else ", ".join(holdout["reasons"]).lower().replace("_", " ") + ".")})
    check = spec["last_check"]
    if check is not None:
        gates.append({"id": "maintainer_check", "passed": not check["reasons"],
                      "detail": f"Last check as of {check['as_of']}: "
                                + (", ".join(check["reasons"]).lower().replace("_", " ") if check["reasons"] else "all checks passed") + "."})
    return gates


def _next_action(spec: dict[str, Any]) -> str:
    status, stage = spec["status"], spec["stage"]
    if status == "ACTIVE":
        if stage == "PROBE":
            return "Run advance: the Sweeper probes the baseline on development data."
        if stage == "BACKTEST":
            return ("Run advance: the Grower checks the gates and evaluates the holdout once." if spec["backtest"] is not None
                    else "Run advance: the Sweeper runs the predeclared grid on development data.")
        return "The owner manages any paper mandate in Strategy Lab; the Maintainer keeps observing. No orders are placed here."
    return {
        "AWAITING_HUMAN_RESUME": "The owner reviews the paper proposal and research report, then resumes manually. No orders are placed.",
        "FORWARD_SHADOW": "The Maintainer observes forward data for the shadow overlay. No orders are placed.",
        "PAUSED": "The owner investigates the Maintainer's pause reasons; only the owner can resume.",
        "REJECTED_NO_DEPLOYABLE_EDGE": "None; the owner may draft a new idea.",
        "BLOCKED": f"None; this spec cannot advance past {stage}.",
    }[status]


def ledger_public(root: Path, *, public_symbols: bool = False, allow_synthetic: bool = False) -> dict[str, Any]:
    """camelCase ``LedgerPublic``: no idea text, paths, prices or receipts."""
    state = fold_state(root)
    if not state["events"]:
        raise ValueError("the ledger has no events to publish")
    specs = []
    for spec in state["specs"].values():
        if spec["classification"] != "observed" and not allow_synthetic:
            raise ValueError("the ledger holds synthetic-fixture research; refusing to publish it")
        family, survivors = _spec_rows(spec)
        specs.append({"specId": spec["spec_id"], "template": spec["template"],
                      "symbolLabel": spec["symbol"] if public_symbols else "Redacted holding",
                      "stage": spec["stage"], "status": spec["status"], "familyTrialCount": family, "survivors": survivors,
                      "gates": _gates(spec), "nextAction": _next_action(spec)})
    events = [{"seq": event["seq"], "at": event["at"], "specId": event["spec_id"], "role": event["role"], "kind": event["kind"],
               "fromStage": event["from_stage"], "toStage": event["to_stage"], "status": event["status"],
               "reasons": list(event["reasons"])} for event in state["events"][-MAX_PUBLIC_EVENTS:]]
    return {"headSha256": state["head_sha256"], "eventCount": len(state["events"]), "trialsTotal": len(state["trials"]),
            "llmCalls": 0, "specs": specs, "events": events}


def day(value: str | date) -> date:
    return value if isinstance(value, date) else date.fromisoformat(value)
