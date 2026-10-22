"""Export a compact, display-only view of the frozen candidate model artifacts.

The Astra's Pick model atlas renders this file. It reads the exact-symbol
registry and each frozen predictor, checks that both agree, and keeps only the
parameters a reader can inspect: HMM regimes, state-count selection, kernel
retrieval settings, and the shadow SDE/OU layer. Unit conversions and parameter
transforms are computed here so the browser never derives a model quantity.

No market observation, forecast, calibrated probability, or execution authority
is produced. A promoted or calibrated artifact fails the export, because the
atlas copy states that every model is an unpromoted candidate.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
import math
from pathlib import Path
from typing import Any

try:
    from .iv_lab import _number, _timestamp
except ImportError:
    from iv_lab import _number, _timestamp

PLATFORM = Path(__file__).resolve().parents[3]
DEFAULT_REGISTRY = PLATFORM / "quant_engine_rs/data/models/universe/registry.json"
DEFAULT_OUTPUT = PLATFORM / "features/research-desk/data/model-atlas.json"
FEATURE_SCHEMA_VERSION = "point-in-time-v4-strict-context+frozen-hmm+analog12"
# predictor.rs FROZEN_FEATURE_SCHEMA, in order, for the version above.
HMM_FEATURES = [
    ("hmm.active_5m_return", "5-minute return"),
    ("hmm.dist_vwap", "Distance from VWAP"),
    ("hmm.rolling_realized_vol", "Realized volatility"),
    ("hmm.volume_zscore", "Volume z-score"),
]
KERNEL_FEATURES = [
    ("analog.ret_1m", "1-minute return"),
    ("analog.ret_5m", "5-minute return"),
    ("analog.ret_15m", "15-minute return"),
    ("analog.vwap_distance", "Distance from VWAP"),
    ("analog.realized_volatility", "Realized volatility"),
    ("analog.normalized_range", "Normalized range"),
    ("analog.volume_zscore", "Volume z-score"),
    ("analog.rvol", "Relative volume"),
    ("analog.session_range_position", "Position in session range"),
    ("analog.cross_asset_breadth", "Cross-asset breadth"),
    ("analog.slope_15m", "15-minute slope"),
    ("analog.minute_of_session", "Minute of session"),
]
# The frozen HMM observes one row per completed 5-minute bucket
# (predictor.rs: minute_in_5m_bucket == 4); the shadow layer uses 1-minute steps.
HMM_STEP_MINUTES = 5
BASIS_POINTS = 10_000


def _text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name}: text required")
    return value


def _iso(value: Any, name: str) -> str:
    return _timestamp(value, name).isoformat().replace("+00:00", "Z")


def _round(value: float, digits: int = 6) -> float:
    return round(value, digits) + 0.0


def _matrix(value: Any, states: int, columns: int, name: str, **bounds: float) -> list[list[float]]:
    if not isinstance(value, list) or len(value) != states:
        raise ValueError(f"{name}: expected {states} rows")
    rows = []
    for index, row in enumerate(value):
        if not isinstance(row, list) or len(row) != columns:
            raise ValueError(f"{name}[{index}]: expected {columns} columns")
        rows.append([_number(item, f"{name}[{index}]", **bounds) for item in row])
    return rows


def _selection(raw: dict[str, Any], states: int) -> dict[str, Any]:
    candidates = []
    for index, item in enumerate(raw.get("candidate_scores") or []):
        candidates.append({
            "states": int(_number(item.get("state_count"), f"candidate[{index}].state_count", minimum=1)),
            "validationLogLikelihood": _round(_number(item.get("validation_average_log_likelihood"), f"candidate[{index}] validation score")),
            "eligible": item.get("occupancy_eligible") is True,
            "status": _text(item.get("status"), f"candidate[{index}].status"),
        })
    selected = int(_number(raw.get("selected_state_count"), "selected_state_count", minimum=1))
    chosen = [item for item in candidates if item["states"] == selected]
    if selected != states or len(chosen) != 1 or not chosen[0]["eligible"]:
        raise ValueError("regime selection does not match an eligible fitted state count")
    return {
        "criterion": _text(raw.get("selection_criterion"), "selection_criterion"),
        "selectedStates": selected,
        "atBoundary": raw.get("selected_at_candidate_boundary") is True,
        "warning": raw.get("selection_warning") or None,
        "fitSessions": int(_number(raw.get("fit_session_count"), "fit_session_count", minimum=1)),
        "validationSessions": int(_number(raw.get("validation_session_count"), "validation_session_count", minimum=1)),
        "minimumStateOccupancy": _round(_number(raw.get("minimum_state_occupancy_fraction"), "minimum_state_occupancy_fraction", minimum=0, maximum=1)),
        "candidates": candidates,
    }


def _regimes(hmm: dict[str, Any], shadow: dict[str, Any], states: int) -> list[dict[str, Any]]:
    transition = _matrix(hmm.get("transition"), states, states, "hmm.transition", minimum=0, maximum=1)
    for index, row in enumerate(transition):
        if not math.isclose(sum(row), 1.0, rel_tol=0, abs_tol=1e-8):
            raise ValueError(f"hmm.transition[{index}]: probabilities must sum to 1")
    means = _matrix(hmm.get("means"), states, len(HMM_FEATURES), "hmm.means")
    diffusion = shadow.get("diffusion_states") or []
    ou_states = shadow.get("vwap_residual_ou_states") or []
    if len(diffusion) != states or (shadow.get("vwap_residual_ou_enabled") is True and len(ou_states) != states):
        raise ValueError("shadow layer states do not match the HMM")
    weights = [_number(item.get("posterior_weight"), f"diffusion[{index}].posterior_weight", minimum=0) for index, item in enumerate(diffusion)]
    total = sum(weights)
    if total <= 0:
        raise ValueError("shadow layer has no posterior weight")
    regimes = []
    for state in range(states):
        drift = diffusion[state]
        if drift.get("state") != state:
            raise ValueError(f"diffusion state {state} is out of order")
        persistence = transition[state][state]
        ou = None
        if shadow.get("vwap_residual_ou_enabled") is True:
            item = ou_states[state]
            if item.get("state") != state:
                raise ValueError(f"OU state {state} is out of order")
            kappa = _number(item.get("kappa_per_minute"), f"ou[{state}].kappa_per_minute")
            ou = {
                "halfLifeMinutes": _round(math.log(2) / kappa, 2) if kappa > 0 else None,
                "longRunResidualBp": _round(_number(item.get("long_run_vwap_residual"), f"ou[{state}].long_run_vwap_residual") * BASIS_POINTS, 3),
                "autoregressivePhi": _round(_number(item.get("autoregressive_phi"), f"ou[{state}].autoregressive_phi"), 5),
            }
        regimes.append({
            "state": state,
            "label": f"R{state + 1}",
            "timeShare": _round(weights[state] / total, 5),
            "persistence": _round(persistence, 4),  # same rounding as the exported matrix
            "meanStayMinutes": _round(HMM_STEP_MINUTES / (1 - persistence), 1) if persistence < 1 else None,
            "driftBpPerMinute": _round(_number(drift.get("drift_per_minute"), f"diffusion[{state}].drift") * BASIS_POINTS, 5),
            "volatilityBpPerSqrtMinute": _round(_number(drift.get("volatility_per_sqrt_minute"), f"diffusion[{state}].volatility", minimum=0) * BASIS_POINTS, 4),
            "inputMeans": [_round(value, 4) for value in means[state]],
            "ou": ou,
        })
    return regimes


def model_view(entry: dict[str, Any], artifact: dict[str, Any], artifact_bytes: bytes, artifact_path: str) -> dict[str, Any]:
    symbol = _text(entry.get("public_symbol"), "public_symbol")
    for field in ("model_hash", "model_version", "artifact_version"):
        if artifact.get(field) != entry.get(field):
            raise ValueError(f"{symbol}: registry {field} does not match the artifact")
    if _timestamp(artifact.get("training_cutoff"), "training_cutoff") != _timestamp(entry.get("training_cutoff"), "registry training_cutoff"):
        raise ValueError(f"{symbol}: registry training cutoff does not match the artifact")
    if artifact.get("feature_schema_version") != FEATURE_SCHEMA_VERSION:
        raise ValueError(f"{symbol}: unknown feature schema; feature labels cannot be verified")
    if entry.get("promotion_status") != "CANDIDATE_NOT_PROMOTED" or artifact.get("calibration_version") != "UNAVAILABLE_FAIL_CLOSED" or artifact.get("calibration_ref") is not None:
        raise ValueError(f"{symbol}: promotion or calibration changed; update the atlas contract before publishing")
    hmm, shadow, kernel = artifact.get("hmm") or {}, artifact.get("short_horizon_model") or {}, artifact.get("analog_engine") or {}
    states = int(_number(hmm.get("states"), "hmm.states", minimum=2))
    if hmm.get("dimensions") != len(HMM_FEATURES) or shadow.get("state_count") != states:
        raise ValueError(f"{symbol}: HMM and shadow layer dimensions disagree")
    config = kernel.get("config") or {}
    weights = [_round(_number(value, "learned_metric_weights", minimum=0), 6) for value in kernel.get("learned_metric_weights") or []]
    if len(weights) != len(KERNEL_FEATURES):
        raise ValueError(f"{symbol}: kernel metric weights do not cover the 12 features")
    jump = shadow.get("jump_diagnostic") or {}
    return {
        "symbol": symbol,
        "modelSymbol": _text(entry.get("model_symbol"), "model_symbol"),
        "priceSymbol": _text(entry.get("price_symbol"), "price_symbol"),
        "targetStatus": _text(entry.get("target_status"), "target_status"),
        "promotionStatus": entry["promotion_status"],
        "calibrationVersion": artifact["calibration_version"],
        "lineage": {
            "artifactPath": artifact_path,
            "artifactFileSha256": sha256(artifact_bytes).hexdigest(),
            "artifactSha256": _text(artifact.get("artifact_sha256"), "artifact_sha256"),
            "modelHash": artifact["model_hash"],
            "modelVersion": artifact["model_version"],
            "createdAt": _iso(artifact.get("created_at"), "created_at"),
            "trainingCutoff": _iso(artifact.get("training_cutoff"), "training_cutoff"),
            "codeCommit": _text(artifact.get("code_commit_hash"), "code_commit_hash"),
            "trainingDatasetHash": _text(artifact.get("training_dataset_hash"), "training_dataset_hash"),
            "trainingRows": int(_number(artifact.get("training_state_count"), "training_state_count", minimum=1)),
        },
        "selection": _selection(artifact.get("regime_selection") or {}, states),
        "hmm": {
            "states": states,
            "logLikelihood": _round(_number(hmm.get("log_likelihood"), "hmm.log_likelihood"), 2),
            "bic": _round(_number(hmm.get("bic"), "hmm.bic"), 2),
            "transition": [[_round(value, 4) for value in row] for row in _matrix(hmm.get("transition"), states, states, "hmm.transition", minimum=0, maximum=1)],
        },
        "regimes": _regimes(hmm, shadow, states),
        "kernel": {
            "metric": _text(config.get("metric"), "kernel.metric"),
            "neighbors": int(_number(config.get("neighbors"), "kernel.neighbors", minimum=1)),
            "bandwidthRule": _text(config.get("bandwidth_rule"), "kernel.bandwidth_rule"),
            "bandwidthMultiplier": _number(config.get("bandwidth_multiplier"), "kernel.bandwidth_multiplier", strictly_positive=True),
            "covarianceShrinkage": _number(config.get("covariance_shrinkage"), "kernel.covariance_shrinkage", minimum=0, maximum=1),
            "regimeMatchPolicy": _text(config.get("regime_match_policy"), "kernel.regime_match_policy"),
            "minimumRegimeSimilarity": _number(config.get("minimum_regime_similarity"), "kernel.minimum_regime_similarity", minimum=0, maximum=1),
            "minimumDominantRegimeProbability": _number(config.get("minimum_dominant_regime_probability"), "kernel.minimum_dominant_regime_probability", minimum=0, maximum=1),
            "minimumEffectiveSampleSize": _number(config.get("minimum_effective_sample_size"), "kernel.minimum_effective_sample_size", minimum=0),
            "sameTimeBucket": config.get("same_time_bucket") is True,
            "oodQuantile": _number(config.get("ood_quantile"), "kernel.ood_quantile", minimum=0, maximum=1),
            "oodDistanceThreshold": _round(_number(kernel.get("ood_distance_threshold"), "kernel.ood_distance_threshold", strictly_positive=True), 4),
            "metricWeights": weights,
            "metricWeightsFitted": int(_number(kernel.get("metric_training_label_count"), "metric_training_label_count", minimum=0)) > 0,
            "analogRows": len(kernel.get("train_indices") or []),
            "trainEnd": _iso(kernel.get("train_end"), "kernel.train_end"),
        },
        "shadow": {
            "stepMinutes": int(_number(shadow.get("base_interval_minutes"), "base_interval_minutes", minimum=1)),
            "observations": int(_number(shadow.get("training_observation_count"), "training_observation_count", minimum=1)),
            "observationCutoff": _iso(shadow.get("observation_cutoff"), "observation_cutoff"),
            "ouEnabled": shadow.get("vwap_residual_ou_enabled") is True,
            "ouRejectionReasons": [_text(item, "ou rejection") for item in shadow.get("vwap_residual_ou_rejection_reasons") or []],
            "jumpEnabled": jump.get("enabled") is True,
            "jumpRejectionReasons": [_text(item, "jump rejection") for item in jump.get("rejection_reasons") or []],
            "policy": _text(shadow.get("research_policy"), "research_policy"),
        },
    }


def build_atlas(registry: dict[str, Any], registry_bytes: bytes, quant_root: Path) -> dict[str, Any]:
    if registry.get("schema_version") != "axio.frozen-universe-registry.v1" or registry.get("execution_enabled") is not False:
        raise ValueError("unsupported or execution-enabled model registry")
    entries = registry.get("entries") or []
    if not entries or len({entry.get("public_symbol") for entry in entries}) != len(entries):
        raise ValueError("registry must list unique public symbols")
    models = []
    for entry in entries:
        relative = _text(entry.get("artifact_path"), "artifact_path").replace("\\", "/")
        path = (quant_root / relative).resolve()
        if quant_root.resolve() not in path.parents:
            raise ValueError(f"{relative}: artifact path leaves the model directory")
        artifact_bytes = path.read_bytes()
        models.append(model_view(entry, json.loads(artifact_bytes), artifact_bytes, path.relative_to(PLATFORM).as_posix()))
    at_boundary = sum(model["selection"]["atBoundary"] for model in models)
    return {
        "schemaVersion": "astra-model-atlas.v1",
        "dataMode": "frozen_candidate_parameters_not_live",
        "registrySha256": sha256(registry_bytes).hexdigest(),
        "registryGeneratedAt": _iso(registry.get("generated_at"), "registry generated_at"),
        "featureSchemaVersion": FEATURE_SCHEMA_VERSION,
        "hmmStepMinutes": HMM_STEP_MINUTES,
        "features": {
            "hmm": [{"id": key, "label": label} for key, label in HMM_FEATURES],
            "kernel": [{"id": key, "label": label} for key, label in KERNEL_FEATURES],
        },
        "models": models,
        "limitations": [
            "These are frozen candidate parameters, not live readings. No current regime, price, or forecast is shown.",
            "No model is promoted and no calibration artifact exists, so no calibrated probability, expected return, or win rate is published.",
            "Regime numbers order states by HMM variance within one model. R3 for one symbol is not the same market condition as R3 for another.",
            "The SDE and OU layers are research-only shadow models. They have no decision authority and imply no trade.",
            *([f"{at_boundary} of {len(models)} state-count selections reached the largest count tested, so their best number of regimes is not established."] if at_boundary else []),
        ],
        "predictionEnabled": False,
        "executionEnabled": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    registry_bytes = args.registry.read_bytes()
    # registry artifact_path values are relative to quant_engine_rs/.
    result = build_atlas(json.loads(registry_bytes), registry_bytes, args.registry.resolve().parents[3])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=1) + "\n", encoding="utf8")
    print(f"Exported {len(result['models'])} frozen candidate models to {args.output}.")


if __name__ == "__main__":
    main()
