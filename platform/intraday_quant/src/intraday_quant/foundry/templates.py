"""Single source of truth for foundry roles, the stage ladder and research templates.

A ``leo-foundry-spec.v1`` may only pick allow-listed values: every swept value is
an enum in the JSON Schema, so an external drafting tool cannot invent a
parameter. The code here makes no LLM call and never authorizes execution.
"""
from __future__ import annotations

import itertools
from dataclasses import dataclass
from datetime import date
from typing import Annotated, Any, ClassVar, Literal, Union

from pydantic import Field, TypeAdapter, model_validator

from ..overlay_lab.engine import LEGS, Costs, ModelSettings, OverlayConfig
from ..strategy_lab.research import StrictModel

SPEC_VERSION = "leo-foundry-spec.v1"
ROLE_IDS = ("prototype_builder", "sweeper", "grower", "maintainer")
STAGES = ("PROBE", "BACKTEST", "PAPER")
LOCKED_STAGES = ("LIVE_SMALL", "LIVE_SCALED")
# LIVE_* are deliberately absent: no code path can move a spec past PAPER.
TRANSITIONS = {"PROBE": "BACKTEST", "BACKTEST": "PAPER"}
FDR_ALPHA = 0.05
MAX_OVERLAY_TRIALS = 64
SPEC_ID_PATTERN = r"^[a-z0-9][a-z0-9_-]{0,63}$"

ROLES = (
    {"id": "prototype_builder", "name": "Prototype Builder",
     "duty": "Validates the owner's idea against a fixed template and freezes it as a versioned research spec.",
     "boundary": "Chooses only allow-listed values; makes no LLM calls and cannot change a frozen spec."},
    {"id": "sweeper", "name": "Sweeper",
     "duty": "Runs the baseline probe and the predeclared parameter grid on development data, recording every trial.",
     "boundary": "Never sees the holdout; multiple-testing control decides survivors."},
    {"id": "grower", "name": "Grower",
     "duty": "Selects a survivor by a predeclared rule and evaluates the holdout exactly once.",
     "boundary": "Can prepare a paper proposal or forward shadow only; places no orders."},
    {"id": "maintainer", "name": "Maintainer",
     "duty": "Checks stale data, source revisions, and forward decay, and requests a pause when a check fails.",
     "boundary": "Can pause but never resume; only the owner resumes."},
)

_FUTURE_GATES = (
    "A written amendment to the owner's operating contract",
    "An approved live broker adapter",
    "Options-execution approval",
    "A declared capital cap",
    "A tested kill switch",
    "A paper track record reviewed by the owner",
)
_LIVE_LOCK = "Real-money and options execution are disabled by the operating contract."

LADDER = (
    {"id": "PROBE", "name": "Probe", "owner": "sweeper", "automatic": True, "locked": False,
     "gate": "Baseline trial on development data with enough sessions and a positive compounded result.",
     "lockReason": None, "futureGates": []},
    {"id": "BACKTEST", "name": "Backtest", "owner": "sweeper", "automatic": True, "locked": False,
     "gate": "Predeclared grid on development data; a survivor needs a Benjamini-Hochberg rejection and a positive bootstrap lower bound.",
     "lockReason": None, "futureGates": []},
    {"id": "PAPER", "name": "Paper", "owner": "grower", "automatic": True, "locked": False,
     "gate": "One holdout evaluation, observed evidence, and stable neighbours; then a paper proposal awaits the owner.",
     "lockReason": None, "futureGates": []},
    {"id": "LIVE_SMALL", "name": "Live small", "owner": "human", "automatic": False, "locked": True,
     "gate": "Not implemented.", "lockReason": _LIVE_LOCK, "futureGates": list(_FUTURE_GATES)},
    {"id": "LIVE_SCALED", "name": "Live scaled", "owner": "human", "automatic": False, "locked": True,
     "gate": "Not implemented.", "lockReason": _LIVE_LOCK, "futureGates": list(_FUTURE_GATES)},
)


@dataclass(frozen=True)
class Template:
    id: str
    kind: Literal["strategy", "overlay", "grid"]
    axes: tuple[tuple[str, tuple[Any, ...]], ...]
    baseline: dict[str, Any] | None
    probe: dict[str, Any]
    max_stage: str


TEMPLATES = {
    "MR-v1": Template("MR-v1", "strategy",
                      (("mr_z_abs", (1.8, 2.0, 2.2)), ("mr_rsi_max", (28, 30, 32)), ("stop_multiple", (1.5, 2.0, 2.5))),
                      {"mr_z_abs": 2.0, "mr_rsi_max": 30, "stop_multiple": 2.0},
                      {"mr_z_abs": 2.0, "mr_rsi_max": 30, "stop_multiple": 2.0}, "PAPER"),
    "MOM-v1": Template("MOM-v1", "strategy",
                       (("momentum_lookback", (50, 55, 60)), ("stop_multiple", (2.5, 3.0, 3.5))),
                       {"momentum_lookback": 55, "stop_multiple": 3.0},
                       {"momentum_lookback": 55, "stop_multiple": 3.0}, "PAPER"),
    "OVERLAY-v1": Template("OVERLAY-v1", "overlay",
                           (("call_otm_pct", (0.02, 0.03, 0.05, 0.08, 0.10)), ("put_otm_pct", (0.03, 0.05, 0.08, 0.10)),
                            ("target_dte", (21, 30, 45))),
                           None, {"call_otm_pct": 0.05, "put_otm_pct": 0.05, "target_dte": 30}, "PAPER"),
    "GRID-R1": Template("GRID-R1", "grid", (("intervals", (4, 6, 8, 10)),), None, {"intervals": 6}, "BACKTEST"),
}


def _enum(template: str, axis: str) -> Any:
    return Literal[dict(TEMPLATES[template].axes)[axis]]  # type: ignore[valid-type]


MrZ = _enum("MR-v1", "mr_z_abs")
MrRsi = _enum("MR-v1", "mr_rsi_max")
MrStop = _enum("MR-v1", "stop_multiple")
MomLookback = _enum("MOM-v1", "momentum_lookback")
MomStop = _enum("MOM-v1", "stop_multiple")
CallOtm = _enum("OVERLAY-v1", "call_otm_pct")
PutOtm = _enum("OVERLAY-v1", "put_otm_pct")
TargetDte = _enum("OVERLAY-v1", "target_dte")
GridIntervals = _enum("GRID-R1", "intervals")


def _all(template: str, axis: str) -> Any:
    return Field(default_factory=lambda: list(dict(TEMPLATES[template].axes)[axis]))


class _Sweep(StrictModel):
    template_id: ClassVar[str]

    @model_validator(mode="after")
    def canonical(self) -> "_Sweep":
        """Each swept list is non-empty, duplicate-free and kept in template order."""
        for axis, allowed in TEMPLATES[self.template_id].axes:
            values = getattr(self, axis, None)
            if values is None:
                continue
            if not values or len(set(values)) != len(values):
                raise ValueError(f"{axis}: choose one or more distinct allow-listed values")
            setattr(self, axis, [value for value in allowed if value in values])
        return self


class MrSweep(_Sweep):
    template_id: ClassVar[str] = "MR-v1"
    mr_z_abs: list[MrZ] = _all("MR-v1", "mr_z_abs")
    mr_rsi_max: list[MrRsi] = _all("MR-v1", "mr_rsi_max")
    stop_multiple: list[MrStop] = _all("MR-v1", "stop_multiple")


class MomSweep(_Sweep):
    template_id: ClassVar[str] = "MOM-v1"
    momentum_lookback: list[MomLookback] = _all("MOM-v1", "momentum_lookback")
    stop_multiple: list[MomStop] = _all("MOM-v1", "stop_multiple")


class OverlaySweep(_Sweep):
    template_id: ClassVar[str] = "OVERLAY-v1"
    structure: Literal["covered_call", "collar", "protective_put"]
    call_otm_pct: list[CallOtm] | None = None
    put_otm_pct: list[PutOtm] | None = None
    target_dte: list[TargetDte] = _all("OVERLAY-v1", "target_dte")

    @model_validator(mode="after")
    def legs(self) -> "OverlaySweep":
        rights = {right for right, _ in LEGS[self.structure]}
        if (self.call_otm_pct is not None) != ("call" in rights) or (self.put_otm_pct is not None) != ("put" in rights):
            raise ValueError("swept strike distances must match the structure's legs exactly")
        return self


class GridSweep(_Sweep):
    template_id: ClassVar[str] = "GRID-R1"
    intervals: list[GridIntervals] = _all("GRID-R1", "intervals")


class InputRef(StrictModel):
    path: Annotated[str, Field(min_length=1, max_length=1024)]
    sha256: Annotated[str, Field(pattern=r"^[a-f0-9]{64}$")]


class Evaluation(StrictModel):
    development_end: date
    holdout_start: date
    holdout_end: date
    minimum_dev_sessions: Annotated[int, Field(ge=20, le=5000)]
    minimum_holdout_sessions: Annotated[int, Field(ge=5, le=5000)]
    maximum_forward_drawdown: Annotated[float, Field(gt=0, le=0.5)]

    @model_validator(mode="after")
    def chronological(self) -> "Evaluation":
        if not self.development_end < self.holdout_start <= self.holdout_end:
            raise ValueError("development and holdout must be disjoint chronological windows")
        return self


class Inference(StrictModel):
    seed: Annotated[int, Field(ge=0, le=2**31 - 1)] = 7
    resamples: Literal[200, 500, 1000, 2000] = 2000


class OverlayBase(StrictModel):
    """Overlay settings the grid does not sweep; validated by the overlay lab per grid point."""
    shares: int
    pricing_mode: Literal["EXECUTABLE_QUOTES", "MODEL_PRICED"]
    min_dte: int
    max_dte: int
    max_spread_fraction: float
    model: ModelSettings | None = None
    costs: Costs


class _SpecBase(StrictModel):
    schema_version: Literal["leo-foundry-spec.v1"]
    spec_id: Annotated[str, Field(pattern=SPEC_ID_PATTERN)]
    symbol: Annotated[str, Field(pattern=r"^[A-Z0-9][A-Z0-9.-]{0,15}$")]
    idea: Annotated[str, Field(min_length=1, max_length=4000)]
    input: InputRef
    evaluation: Evaluation
    inference: Inference = Field(default_factory=Inference)


class _BaselineSpec(_SpecBase):
    engine: Annotated[str, Field(min_length=1, max_length=1024)]

    @model_validator(mode="after")
    def baseline_swept(self) -> "_BaselineSpec":
        baseline = TEMPLATES[self.template].baseline  # type: ignore[attr-defined]
        if any(value not in getattr(self.sweep, axis) for axis, value in baseline.items()):  # type: ignore[attr-defined]
            raise ValueError("the sweep must include the template baseline on every axis")
        return self


class MrSpec(_BaselineSpec):
    template: Literal["MR-v1"]
    sweep: MrSweep = Field(default_factory=MrSweep)


class MomSpec(_BaselineSpec):
    template: Literal["MOM-v1"]
    sweep: MomSweep = Field(default_factory=MomSweep)


class OverlaySpec(_SpecBase):
    template: Literal["OVERLAY-v1"]
    sweep: OverlaySweep
    overlay: OverlayBase

    @model_validator(mode="after")
    def bounded_grid(self) -> "OverlaySpec":
        points = grid_points(self)
        if len(points) > MAX_OVERLAY_TRIALS:
            raise ValueError(f"overlay grid exceeds {MAX_OVERLAY_TRIALS} trials")
        for point in points:
            OverlayConfig.model_validate(overlay_config(self, point))
        return self


class GridSpec(_SpecBase):
    template: Literal["GRID-R1"]
    engine: Annotated[str, Field(min_length=1, max_length=1024)]
    sweep: GridSweep = Field(default_factory=GridSweep)


FoundrySpec = Annotated[Union[MrSpec, MomSpec, OverlaySpec, GridSpec], Field(discriminator="template")]
SPEC = TypeAdapter(FoundrySpec)


def spec_schema() -> dict[str, Any]:
    return SPEC.json_schema()


def grid_points(spec: Any) -> list[dict[str, Any]]:
    """The predeclared grid in template order; the order also breaks selection ties."""
    axes = [(axis, getattr(spec.sweep, axis)) for axis, _ in TEMPLATES[spec.template].axes if getattr(spec.sweep, axis) is not None]
    fixed = {"structure": spec.sweep.structure} if spec.template == "OVERLAY-v1" else {}
    return [{**fixed, **dict(zip([axis for axis, _ in axes], values, strict=True))}
            for values in itertools.product(*(values for _, values in axes))]


def probe_point(spec: Any) -> dict[str, Any]:
    """Template baseline (MR/MOM) or the template's reference value where swept, else the first swept value."""
    probe = TEMPLATES[spec.template].probe
    point = dict(grid_points(spec)[0])
    for axis in point:
        values = getattr(spec.sweep, axis) if axis != "structure" else None
        if values is not None and probe.get(axis) in values:
            point[axis] = probe[axis]
    return point


def neighbours(spec: Any, point: dict[str, Any]) -> list[dict[str, Any]]:
    """Grid points one adjacent swept value away on exactly one axis."""
    result = []
    for axis, _ in TEMPLATES[spec.template].axes:
        values = getattr(spec.sweep, axis)
        if values is None:
            continue
        index = values.index(point[axis])
        for other in (index - 1, index + 1):
            if 0 <= other < len(values):
                result.append({**point, axis: values[other]})
    return result


def is_baseline(spec: Any, point: dict[str, Any]) -> bool:
    baseline = TEMPLATES[spec.template].baseline
    return baseline is not None and point == baseline


def research_parameters(spec: Any, point: dict[str, Any]) -> dict[str, Any] | None:
    """Rust replay overrides; the baseline runs with none, exactly as the deployed version."""
    return None if is_baseline(spec, point) else dict(point)


def overlay_config(spec: Any, point: dict[str, Any]) -> dict[str, Any]:
    base = spec.overlay.model_dump(mode="json")
    call, put = point.get("call_otm_pct"), point.get("put_otm_pct")
    return {"schema_version": "leo-overlay-config.v1", "structure": point["structure"], "shares": base["shares"],
            "pricing_mode": base["pricing_mode"],
            "call_rule": None if call is None else {"kind": "otm_pct", "value": call},
            "put_rule": None if put is None else {"kind": "otm_pct", "value": put},
            "target_dte": point["target_dte"], "min_dte": base["min_dte"], "max_dte": base["max_dte"],
            "max_spread_fraction": base["max_spread_fraction"], "model": base["model"], "costs": base["costs"]}
