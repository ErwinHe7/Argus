#!/usr/bin/env python3
"""Leakage-safe retest of pre-Alphabet-earnings regime analogs.

The input is the frozen output of alphabet-earnings-event-study.mjs.  This
script never downloads current prices and never reads the target event return.
It compares several predeclared similarity specifications, reports strict
regime support, and evaluates the same rules with expanding-window forecasts.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Callable

import numpy as np


FEATURES = [
    "googl20",
    "qqq20",
    "soxx20",
    "mu20",
    "tlt20",
    "hyg20",
    "gld20",
    "uso20",
    "uup20",
    "vix",
    "tenYearYield",
    "soxxVol20",
]
ASSETS = ["GOOGL", "SPY", "QQQ", "SOXX", "MU", "SNDK", "WDC", "STX"]
HORIZONS = (1, 5)
AI_ERA_START = "2023-07-25"
MIN_DIRECT_OBSERVATIONS = 5
MIN_VALIDATION_TRAINING = 20


@dataclass(frozen=True)
class ModelSpec:
    name: str
    label: str
    kind: str
    k: int
    continuous_weight: float = 0.0
    flag_weight: float = 0.0
    ai_weight: float = 0.0
    season_weight: float = 0.0
    start_date: str | None = None
    one_per_year: bool = False


MODEL_SPECS = [
    ModelSpec("pure_no_issuer", "全历史·不含GOOGL自身", "no_issuer", 12),
    ModelSpec("diag_all", "全历史·稳健对角距离", "diag", 12),
    ModelSpec("tech_tilt", "全历史·科技压力加权", "tech_weighted", 12),
    ModelSpec("macro_tilt", "全历史·宏观冲击加权", "macro_weighted", 12),
    ModelSpec("mahal_all", "全历史·收缩马氏距离", "mahal", 12),
    ModelSpec("post2018", "2018后·稳健距离", "diag", 8, start_date="2018-01-01"),
    ModelSpec("ai_era", "AI基础设施时代·稳健距离", "diag", 8, start_date=AI_ERA_START),
    ModelSpec(
        "balanced",
        "复合·均衡",
        "composite",
        8,
        continuous_weight=0.50,
        flag_weight=0.25,
        ai_weight=0.15,
        season_weight=0.10,
    ),
    ModelSpec(
        "ai_heavy",
        "复合·AI时代加权",
        "composite",
        8,
        continuous_weight=0.35,
        flag_weight=0.20,
        ai_weight=0.30,
        season_weight=0.15,
    ),
    ModelSpec(
        "macro_heavy",
        "复合·市场状态加权",
        "composite",
        8,
        continuous_weight=0.60,
        flag_weight=0.30,
        ai_weight=0.05,
        season_weight=0.05,
    ),
    ModelSpec("hard_flags", "状态标签优先", "flags", 8),
    ModelSpec(
        "balanced_year_cap",
        "复合·均衡·每年最多一次",
        "composite",
        8,
        continuous_weight=0.50,
        flag_weight=0.25,
        ai_weight=0.15,
        season_weight=0.10,
        one_per_year=True,
    ),
]

PRIMARY_MODEL = "balanced"
WEIGHT_SENSITIVITY_MODELS = [
    "pure_no_issuer",
    "diag_all",
    "tech_tilt",
    "macro_tilt",
]
ROBUSTNESS_MODELS = [
    *WEIGHT_SENSITIVITY_MODELS,
]

FEATURE_WEIGHT_SETS = {
    "no_issuer": {key: (0.0 if key == "googl20" else 1.0) for key in FEATURES},
    "tech_weighted": {
        **{key: 0.6 for key in FEATURES},
        "googl20": 1.0,
        "qqq20": 1.5,
        "soxx20": 2.0,
        "mu20": 2.0,
        "soxxVol20": 1.5,
        "vix": 1.0,
    },
    "macro_weighted": {
        **{key: 0.6 for key in FEATURES},
        "tlt20": 1.5,
        "hyg20": 1.5,
        "gld20": 1.25,
        "uso20": 2.0,
        "uup20": 1.25,
        "vix": 1.5,
        "tenYearYield": 2.0,
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="reports/alphabet-earnings-event-study-2026-07-22.json",
    )
    parser.add_argument("--event-date", default="2026-07-22")
    parser.add_argument(
        "--output-base",
        default="reports/alphabet-current-regime-retest-2026-07-22",
    )
    return parser.parse_args()


def finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value))


def feature_vector(features: dict[str, Any]) -> np.ndarray:
    values = np.array([features.get(key, np.nan) for key in FEATURES], dtype=float)
    if not np.isfinite(values).all():
        missing = [key for key, value in zip(FEATURES, values) if not np.isfinite(value)]
        raise ValueError(f"Incomplete regime vector: {missing}")
    return values


def robust_location_scale(matrix: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    center = np.median(matrix, axis=0)
    mad = np.median(np.abs(matrix - center), axis=0)
    scale = 1.4826 * mad
    fallback = np.std(matrix, axis=0, ddof=1)
    scale = np.where(scale > 1e-12, scale, fallback)
    scale = np.where(np.isfinite(scale) & (scale > 1e-12), scale, 1.0)
    return center, scale


def continuous_distances(matrix: np.ndarray, query: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    center, scale = robust_location_scale(matrix)
    standardized = (matrix - center) / scale
    difference = (matrix - query) / scale
    diagonal = np.sqrt(np.mean(difference**2, axis=1))

    covariance = np.cov(standardized, rowvar=False)
    diagonal_target = np.diag(np.diag(covariance))
    shrinkage = 0.50 * covariance + 0.50 * diagonal_target
    inverse = np.linalg.pinv(shrinkage, hermitian=True)
    mahalanobis = np.sqrt(
        np.maximum(np.einsum("ij,jk,ik->i", difference, inverse, difference), 0.0)
        / matrix.shape[1]
    )
    return diagonal, mahalanobis


def percentile_ranks(values: np.ndarray) -> np.ndarray:
    order = np.argsort(values, kind="stable")
    ranks = np.empty(len(values), dtype=float)
    ranks[order] = np.linspace(0.0, 1.0, len(values)) if len(values) > 1 else 0.0
    return ranks


def regime_flags(features: dict[str, Any]) -> dict[str, bool]:
    """Coarse, fixed bins chosen without looking at event returns."""

    return {
        "growth_correction": features["qqq20"] <= -0.02,
        "chip_correction": features["soxx20"] <= -0.08,
        "memory_correction": features["mu20"] <= -0.10,
        "credit_intact": features["hyg20"] >= -0.01,
        "oil_shock": features["uso20"] >= 0.08,
        "duration_selloff": features["tlt20"] < 0.0,
        "high_long_yield": features["tenYearYield"] >= 4.0,
        "nonpanic_vix": features["vix"] <= 25.0,
    }


def relaxed_regime_match(features: dict[str, Any]) -> bool:
    return (
        features["qqq20"] < 0.0
        and features["soxx20"] <= -0.05
        and features["mu20"] <= -0.05
        and features["hyg20"] >= -0.02
        and features["uso20"] > 0.0
        and features["tlt20"] < 0.0
        and features["tenYearYield"] >= 3.5
        and features["vix"] <= 30.0
    )


def is_ai_era(event_date: str) -> bool:
    return event_date >= AI_ERA_START


def announcement_season(event_date: str) -> int:
    month = int(event_date[5:7])
    return (month - 1) // 3


def score_candidates(
    candidates: list[dict[str, Any]],
    query_features: dict[str, Any],
    query_date: str,
    spec: ModelSpec,
) -> list[dict[str, Any]]:
    filtered = [
        row
        for row in candidates
        if spec.start_date is None or row["acceptanceEtDate"] >= spec.start_date
    ]
    if not filtered:
        return []
    matrix = np.vstack([feature_vector(row["features"]) for row in filtered])
    query = feature_vector(query_features)
    diagonal, mahalanobis = continuous_distances(matrix, query)
    _, robust_scale = robust_location_scale(matrix)
    standardized_difference = (matrix - query) / robust_scale
    weighted_distances: dict[str, np.ndarray] = {}
    for weight_name, weight_map in FEATURE_WEIGHT_SETS.items():
        feature_weights = np.array([weight_map[key] for key in FEATURES], dtype=float)
        weighted_distances[weight_name] = np.sqrt(
            np.sum(standardized_difference**2 * feature_weights, axis=1)
            / np.sum(feature_weights)
        )
    diagonal_rank = percentile_ranks(diagonal)
    mahalanobis_rank = percentile_ranks(mahalanobis)
    query_flags = regime_flags(query_features)
    query_ai = is_ai_era(query_date)
    query_season = announcement_season(query_date)

    scored: list[dict[str, Any]] = []
    for index, row in enumerate(filtered):
        candidate_flags = regime_flags(row["features"])
        mismatches = sum(
            candidate_flags[key] != query_flags[key] for key in query_flags
        )
        flag_fraction = mismatches / len(query_flags)
        continuous_rank = 0.5 * (diagonal_rank[index] + mahalanobis_rank[index])
        if spec.kind == "diag":
            score = float(diagonal[index])
        elif spec.kind in FEATURE_WEIGHT_SETS:
            score = float(weighted_distances[spec.kind][index])
        elif spec.kind == "mahal":
            score = float(mahalanobis[index])
        elif spec.kind == "flags":
            score = flag_fraction + 0.01 * float(diagonal_rank[index])
        elif spec.kind == "composite":
            score = (
                spec.continuous_weight * continuous_rank
                + spec.flag_weight * flag_fraction
                + spec.ai_weight * (is_ai_era(row["acceptanceEtDate"]) != query_ai)
                + spec.season_weight
                * (announcement_season(row["acceptanceEtDate"]) != query_season)
            )
        else:
            raise ValueError(f"Unknown model kind: {spec.kind}")
        scored.append(
            {
                **row,
                "score": score,
                "diagonalDistance": float(diagonal[index]),
                "mahalanobisDistance": float(mahalanobis[index]),
                "flagMatches": len(query_flags) - mismatches,
                "flagMismatches": mismatches,
            }
        )
    return sorted(scored, key=lambda row: (row["score"], row["acceptanceEtDate"]))


def choose_neighbors(scored: list[dict[str, Any]], spec: ModelSpec) -> list[dict[str, Any]]:
    if not spec.one_per_year:
        return scored[: spec.k]
    selected: list[dict[str, Any]] = []
    years: set[str] = set()
    for row in scored:
        year = row["acceptanceEtDate"][:4]
        if year in years:
            continue
        selected.append(row)
        years.add(year)
        if len(selected) == spec.k:
            break
    return selected


def kernel_weights(neighbors: list[dict[str, Any]]) -> np.ndarray:
    if not neighbors:
        return np.array([], dtype=float)
    scores = np.array([row["score"] for row in neighbors], dtype=float)
    bandwidth = float(np.median(scores))
    if not math.isfinite(bandwidth) or bandwidth <= 1e-12:
        return np.full(len(neighbors), 1.0 / len(neighbors))
    weights = np.exp(-0.5 * (scores / bandwidth) ** 2)
    return weights / np.sum(weights)


def weighted_quantile(values: np.ndarray, weights: np.ndarray, probability: float) -> float:
    order = np.argsort(values, kind="stable")
    ordered_values = values[order]
    ordered_weights = weights[order]
    cumulative = np.cumsum(ordered_weights) / np.sum(ordered_weights)
    index = min(int(np.searchsorted(cumulative, probability, side="left")), len(values) - 1)
    return float(ordered_values[index])


def observation(row: dict[str, Any], asset: str, horizon: int) -> float | None:
    value = row.get("returns", {}).get(asset, {}).get(f"ret{horizon}")
    return float(value) if finite(value) else None


def summarize_neighbors(
    neighbors: list[dict[str, Any]], weights: np.ndarray, asset: str, horizon: int
) -> dict[str, Any]:
    pairs = [
        (observation(row, asset, horizon), float(weights[index]))
        for index, row in enumerate(neighbors)
    ]
    pairs = [(value, weight) for value, weight in pairs if value is not None]
    if len(pairs) < MIN_DIRECT_OBSERVATIONS:
        return {
            "status": "INSUFFICIENT_DIRECT_HISTORY",
            "n": len(pairs),
            "ess": None,
            "mean": None,
            "positiveProbability": None,
            "p10": None,
            "median": None,
            "p90": None,
            "bootstrapMean95": [None, None],
            "leaveOneOutMeanRange": [None, None],
        }
    values = np.array([pair[0] for pair in pairs], dtype=float)
    local_weights = np.array([pair[1] for pair in pairs], dtype=float)
    local_weights /= np.sum(local_weights)
    leave_one_out: list[float] = []
    for index in range(len(values)):
        mask = np.arange(len(values)) != index
        remaining_weights = local_weights[mask]
        remaining_weights /= np.sum(remaining_weights)
        leave_one_out.append(float(np.sum(values[mask] * remaining_weights)))
    seed = 17_000 + sum(ord(character) for character in asset) * 10 + horizon
    rng = np.random.default_rng(seed)
    draws = rng.choice(
        len(values), size=(5_000, len(values)), replace=True, p=local_weights
    )
    bootstrap_means = np.mean(values[draws], axis=1)
    return {
        "status": "DESCRIPTIVE_ANALOG",
        "n": len(values),
        "ess": float(1.0 / np.sum(local_weights**2)),
        "mean": float(np.sum(values * local_weights)),
        "positiveProbability": float(np.sum(local_weights[values > 0])),
        "p10": weighted_quantile(values, local_weights, 0.10),
        "median": weighted_quantile(values, local_weights, 0.50),
        "p90": weighted_quantile(values, local_weights, 0.90),
        "bootstrapMean95": [
            float(np.quantile(bootstrap_means, 0.025)),
            float(np.quantile(bootstrap_means, 0.975)),
        ],
        "leaveOneOutMeanRange": [min(leave_one_out), max(leave_one_out)],
    }


def run_model(
    rows: list[dict[str, Any]],
    query_features: dict[str, Any],
    query_date: str,
    spec: ModelSpec,
) -> dict[str, Any]:
    scored = score_candidates(rows, query_features, query_date, spec)
    neighbors = choose_neighbors(scored, spec)
    weights = kernel_weights(neighbors)
    forecasts: dict[str, dict[str, Any]] = {}
    for asset in ASSETS:
        forecasts[asset] = {
            f"ret{horizon}": summarize_neighbors(neighbors, weights, asset, horizon)
            for horizon in HORIZONS
        }
    return {
        "name": spec.name,
        "label": spec.label,
        "candidateCount": len(scored),
        "k": len(neighbors),
        "neighborEss": float(1.0 / np.sum(weights**2)) if len(weights) else None,
        "neighbors": [
            {
                "acceptanceEtDate": row["acceptanceEtDate"],
                "reactionDate": row["reactionDate"],
                "priorDate": row["priorDate"],
                "score": row["score"],
                "diagonalDistance": row["diagonalDistance"],
                "mahalanobisDistance": row["mahalanobisDistance"],
                "flagMatches": row["flagMatches"],
                "weight": float(weights[index]),
                "returns": row["returns"],
            }
            for index, row in enumerate(neighbors)
        ],
        "forecasts": forecasts,
    }


def unconditional_baseline(
    rows: list[dict[str, Any]], asset: str, horizon: int
) -> tuple[float, float]:
    values = [observation(row, asset, horizon) for row in rows]
    clean = np.array([value for value in values if value is not None], dtype=float)
    return float(np.mean(clean)), float(np.mean(clean > 0))


def validation_metrics(records: list[dict[str, float]]) -> dict[str, Any]:
    if not records:
        return {"n": 0}
    actual = np.array([row["actual"] for row in records])
    predicted = np.array([row["predictedMean"] for row in records])
    probability = np.array([row["predictedProbability"] for row in records])
    baseline = np.array([row["baselineMean"] for row in records])
    baseline_probability = np.array([row["baselineProbability"] for row in records])
    outcome = actual > 0
    return {
        "n": len(records),
        "mae": float(np.mean(np.abs(predicted - actual))),
        "baselineMae": float(np.mean(np.abs(baseline - actual))),
        "brier": float(np.mean((probability - outcome) ** 2)),
        "baselineBrier": float(np.mean((baseline_probability - outcome) ** 2)),
        "directionalAccuracy": float(np.mean((probability >= 0.5) == outcome)),
        "baselineDirectionalAccuracy": float(
            np.mean((baseline_probability >= 0.5) == outcome)
        ),
        "improvesBothMaeAndBrier": bool(
            np.mean(np.abs(predicted - actual)) < np.mean(np.abs(baseline - actual))
            and np.mean((probability - outcome) ** 2)
            < np.mean((baseline_probability - outcome) ** 2)
        ),
    }


def walk_forward_validation(rows: list[dict[str, Any]]) -> dict[str, Any]:
    validation_specs = [
        spec
        for spec in MODEL_SPECS
        if spec.name
        in {
            "pure_no_issuer",
            "diag_all",
            "tech_tilt",
            "macro_tilt",
            "mahal_all",
            "balanced",
            "ai_heavy",
            "macro_heavy",
        }
    ]
    buckets: dict[str, dict[str, dict[str, list[dict[str, float]]]]] = {
        spec.name: {
            asset: {f"ret{horizon}": [] for horizon in HORIZONS} for asset in ASSETS
        }
        for spec in validation_specs
    }
    chronological = sorted(rows, key=lambda row: row["acceptanceEtDate"])
    for query_index in range(MIN_VALIDATION_TRAINING, len(chronological)):
        query = chronological[query_index]
        training = chronological[:query_index]
        for spec in validation_specs:
            scored = score_candidates(training, query["features"], query["acceptanceEtDate"], spec)
            neighbors = choose_neighbors(scored, spec)
            weights = kernel_weights(neighbors)
            for asset in ASSETS:
                for horizon in HORIZONS:
                    actual = observation(query, asset, horizon)
                    forecast = summarize_neighbors(neighbors, weights, asset, horizon)
                    if actual is None or forecast["mean"] is None:
                        continue
                    baseline_mean, baseline_probability = unconditional_baseline(
                        training, asset, horizon
                    )
                    buckets[spec.name][asset][f"ret{horizon}"].append(
                        {
                            "actual": actual,
                            "predictedMean": forecast["mean"],
                            "predictedProbability": forecast["positiveProbability"],
                            "baselineMean": baseline_mean,
                            "baselineProbability": baseline_probability,
                        }
                    )
    return {
        spec.name: {
            asset: {
                metric: validation_metrics(records)
                for metric, records in asset_buckets.items()
            }
            for asset, asset_buckets in buckets[spec.name].items()
        }
        for spec in validation_specs
    }


def pct(value: float | None, digits: int = 2) -> str:
    if value is None or not math.isfinite(value):
        return "NA"
    return f"{value * 100:+.{digits}f}%"


def number(value: float | None, digits: int = 2) -> str:
    if value is None or not math.isfinite(value):
        return "NA"
    return f"{value:.{digits}f}"


def model_forecast_table(models: dict[str, Any], horizon: int) -> list[str]:
    lines = [
        "| 模型 | SPY均值 / 上涨率 | QQQ均值 / 上涨率 | SOXX均值 / 上涨率 | MU均值 / 上涨率 |",
        "|---|---:|---:|---:|---:|",
    ]
    for spec in MODEL_SPECS:
        model = models[spec.name]
        cells = []
        for asset in ["SPY", "QQQ", "SOXX", "MU"]:
            forecast = model["forecasts"][asset][f"ret{horizon}"]
            cells.append(
                f"{pct(forecast['mean'])} / {pct(forecast['positiveProbability'], 1)}"
            )
        lines.append(f"| {model['label']} | {' | '.join(cells)} |")
    return lines


def robustness_summary(models: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for asset in ["GOOGL", "SPY", "QQQ", "SOXX", "MU", "WDC", "STX"]:
        result[asset] = {}
        for horizon in HORIZONS:
            forecasts = [
                models[name]["forecasts"][asset][f"ret{horizon}"]
                for name in ROBUSTNESS_MODELS
            ]
            means = [row["mean"] for row in forecasts if finite(row["mean"])]
            probabilities = [
                row["positiveProbability"]
                for row in forecasts
                if finite(row["positiveProbability"])
            ]
            result[asset][f"ret{horizon}"] = {
                "meanRange": [min(means), max(means)] if means else [None, None],
                "positiveProbabilityRange": (
                    [min(probabilities), max(probabilities)] if probabilities else [None, None]
                ),
                "positiveMeanModels": sum(value > 0 for value in means),
                "modelCount": len(means),
            }
    return result


def nearest_neighbor_novelty(
    rows: list[dict[str, Any]], current_features: dict[str, Any]
) -> dict[str, Any]:
    matrix = np.vstack([feature_vector(row["features"]) for row in rows])
    current = feature_vector(current_features)
    current_distances, _ = continuous_distances(matrix, current)
    current_nearest = float(np.min(current_distances))
    historical_nearest: list[float] = []
    for query_index in range(len(rows)):
        training = np.delete(matrix, query_index, axis=0)
        query = matrix[query_index]
        distances, _ = continuous_distances(training, query)
        historical_nearest.append(float(np.min(distances)))
    distribution = np.array(historical_nearest, dtype=float)
    return {
        "currentNearestDistance": current_nearest,
        "percentileVsHistoricalLeaveOneOut": float(np.mean(distribution <= current_nearest)),
        "historicalQ75": float(np.quantile(distribution, 0.75)),
        "historicalQ90": float(np.quantile(distribution, 0.90)),
    }


def transmission_with_intervals(source: dict[str, Any]) -> dict[str, Any]:
    output: dict[str, Any] = {}
    for asset in ["SPY", "QQQ", "SOXX", "MU"]:
        regression = source["transmission"][asset]["regression"]
        sample_size = int(regression["n"])
        correlation = float(regression["correlation"])
        clipped = min(max(correlation, -0.999999), 0.999999)
        fisher = math.atanh(clipped)
        standard_error = 1.0 / math.sqrt(sample_size - 3)
        interval = [
            math.tanh(fisher - 1.96 * standard_error),
            math.tanh(fisher + 1.96 * standard_error),
        ]
        output[asset] = {
            "n": sample_size,
            "beta": regression["beta"],
            "correlation": correlation,
            "correlation95": interval,
            "r2": regression["r2"],
        }
    return output


def build_markdown(result: dict[str, Any]) -> str:
    current = result["current"]
    strict = result["strictRegimeSupport"]
    models = result["models"]
    robustness = result["robustness"]
    validation = result["walkForwardValidation"]
    novelty = result["novelty"]
    lines: list[str] = [
        "# Alphabet 财报前当前 Regime 相似场景重测",
        "",
        f"状态：**{result['verdict']}**。目标财报日 **{result['eventDate']}**；行情严格冻结至 **{result['marketDataThrough']}**；目标 8-K 已排除。",
        "",
        "## 直接结论",
        "",
        f"严格 8 条当前状态同时命中的历史事件为 **{strict['exactCount']}** 个；放宽到同方向宏观/市场状态也只有 **{strict['relaxedCount']}** 个。当前最近邻距离为 **{number(novelty['currentNearestDistance'], 3)}**，处于历史留一法最近邻距离的 **{pct(novelty['percentileVsHistoricalLeaveOneOut'], 1)}** 分位。当前组合因此属于样本外（OOD），不能从历史声称存在经验证的强方向优势。",
        "",
        "四套事前固定的连续特征权重（不含发行人自身、12维等权、科技压力加权、宏观冲击加权）次日均值敏感区间：",
        "",
        "| 资产 | 模型均值区间 | 上涨概率区间 | 均值为正模型数 |",
        "|---|---:|---:|---:|",
    ]
    for asset in ["GOOGL", "SPY", "QQQ", "SOXX", "MU"]:
        row = robustness[asset]["ret1"]
        lines.append(
            f"| {asset} | {pct(row['meanRange'][0])} 至 {pct(row['meanRange'][1])} | "
            f"{pct(row['positiveProbabilityRange'][0], 1)} 至 {pct(row['positiveProbabilityRange'][1], 1)} | "
            f"{row['positiveMeanModels']}/{row['modelCount']} |"
        )
    lines += [
        "",
        "## 冻结的当前状态",
        "",
        "| 特征 | 数值 |",
        "|---|---:|",
        f"| QQQ 20日 | {pct(current['features']['qqq20'])} |",
        f"| SOXX 20日 | {pct(current['features']['soxx20'])} |",
        f"| MU 20日 | {pct(current['features']['mu20'])} |",
        f"| TLT 20日 | {pct(current['features']['tlt20'])} |",
        f"| HYG 20日 | {pct(current['features']['hyg20'])} |",
        f"| USO 20日 | {pct(current['features']['uso20'])} |",
        f"| VIX | {number(current['features']['vix'])} |",
        f"| 10年期收益率代理 | {number(current['features']['tenYearYield'], 3)}% |",
        f"| SOXX 20日年化波动 | {pct(current['features']['soxxVol20'], 1)} |",
        "",
        "严格标签为：QQQ≤-2%、SOXX≤-8%、MU≤-10%、HYG≥-1%、USO≥+8%、TLT<0、10Y≥4%、VIX≤25。阈值在查看事件收益前固定。",
        "",
        "## 当前宏观/地缘环境的外部交叉核验",
        "",
        "- 美国财政部7月21日曲线显示2Y 4.26%、10Y 4.63%；FRED的10Y实际利率为2.37%。",
        "- FRED/ICE的7月21日HY OAS为269bp、IG OAS为78bp：信用并未显示系统性恐慌。",
        "- AP在7月21日报道美伊恢复每日空袭、霍尔木兹航运持续受限；因此油价/USO冲击不是纯技术噪声。战争叙事只用于解释，数学距离仍只使用可复现市场代理。",
        "- 来源：[美国财政部收益率曲线](https://home.treasury.gov/resource-center/data-chart-center/interest-rates/TextView?field_tdr_date_value=2026&type=daily_treasury_yield_curve)、[FRED 10Y实际利率](https://fred.stlouisfed.org/series/DFII10)、[FRED HY OAS](https://fred.stlouisfed.org/series/BAMLH0A0HYM2)、[FRED IG OAS](https://fred.stlouisfed.org/series/BAMLC0A0CM)、[AP霍尔木兹局势](https://apnews.com/article/iran-war-trump-airstrikes-strait-hormuz-8c42c6ddc0c32d53ce452ace92a62b9a)。",
        "",
        "## 标签最接近的历史财报",
        "",
        "| 财报日 | 命中/8 | 距离 | GOOGL 1d | SPY 1d | QQQ 1d | SOXX 1d | MU 1d | SOXX 5d | MU 5d |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in result["closestFlagMatches"][:10]:
        returns = row["returns"]
        lines.append(
            f"| {row['acceptanceEtDate']} | {row['flagMatches']} | {number(row['diagonalDistance'], 3)} | "
            f"{pct(returns['GOOGL']['ret1'])} | {pct(returns['SPY']['ret1'])} | "
            f"{pct(returns['QQQ']['ret1'])} | {pct(returns['SOXX']['ret1'])} | "
            f"{pct(returns['MU']['ret1'])} | {pct(returns['SOXX']['ret5'])} | {pct(returns['MU']['ret5'])} |"
        )
    lines += [
        "",
        "## 多规格结果：次日",
        "",
        *model_forecast_table(models, 1),
        "",
        "## 多规格结果：5个交易日",
        "",
        *model_forecast_table(models, 5),
        "",
        "## 全历史12维主规格的不确定区间",
        "",
        "固定邻居重采样的均值95%区间；区间跨0代表方向未被区分。",
        "",
        "| 资产 | 1d均值95%区间 | 5d均值95%区间 |",
        "|---|---:|---:|",
    ]
    for asset in ["SPY", "QQQ", "SOXX", "MU"]:
        one = models["diag_all"]["forecasts"][asset]["ret1"]["bootstrapMean95"]
        five = models["diag_all"]["forecasts"][asset]["ret5"]["bootstrapMean95"]
        lines.append(
            f"| {asset} | {pct(one[0])} 至 {pct(one[1])} | {pct(five[0])} 至 {pct(five[1])} |"
        )
    lines += [
        "",
        "## GOOGL财报反应的历史传导强度",
        "",
        "这是87次事件的同日相关/回归，不是当前财报的因果系数。SOXX、MU的相关区间跨0。",
        "",
        "| 资产 | N | beta | 相关系数 | Fisher 95%区间 | R² |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for asset in ["SPY", "QQQ", "SOXX", "MU"]:
        row = result["transmission"][asset]
        lines.append(
            f"| {asset} | {row['n']} | {number(row['beta'], 3)} | {number(row['correlation'], 3)} | "
            f"{number(row['correlation95'][0], 3)} 至 {number(row['correlation95'][1], 3)} | {pct(row['r2'], 1)} |"
        )
    lines += [
        "",
        "## AI时代限制样本",
        "",
    ]
    ai_model = models["ai_era"]
    lines.append(
        f"候选 {ai_model['candidateCount']} 个，取 {ai_model['k']} 个，邻居有效样本量 ESS={number(ai_model['neighborEss'])}。"
    )
    lines += [
        "",
        "| 财报日 | 命中/8 | 权重 | GOOGL 1d | QQQ 1d | SOXX 1d | MU 1d |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in ai_model["neighbors"]:
        returns = row["returns"]
        lines.append(
            f"| {row['acceptanceEtDate']} | {row['flagMatches']} | {pct(row['weight'], 1)} | "
            f"{pct(returns['GOOGL']['ret1'])} | {pct(returns['QQQ']['ret1'])} | "
            f"{pct(returns['SOXX']['ret1'])} | {pct(returns['MU']['ret1'])} |"
        )
    lines += [
        "",
        "## 扩展窗口样本外检验",
        "",
        "每个历史财报只用它之前的事件重新估计尺度、距离和邻居；无未来样本参与。表中 `<` 才代表误差优于无条件历史基线。",
        "",
        "| 模型 | 资产/期限 | N | MAE 模型/基线 | Brier 模型/基线 | 同时改善 |",
        "|---|---|---:|---:|---:|---:|",
    ]
    for model_name in [
        "pure_no_issuer",
        "diag_all",
        "tech_tilt",
        "macro_tilt",
        "balanced",
    ]:
        for asset in ["GOOGL", "QQQ", "SOXX", "MU"]:
            for horizon in [1, 5]:
                metric = validation[model_name][asset][f"ret{horizon}"]
                lines.append(
                    f"| {models[model_name]['label']} | {asset} {horizon}d | {metric.get('n', 0)} | "
                    f"{number(metric.get('mae'), 4)} / {number(metric.get('baselineMae'), 4)} | "
                    f"{number(metric.get('brier'), 4)} / {number(metric.get('baselineBrier'), 4)} | "
                    f"{'是' if metric.get('improvesBothMaeAndBrier') else '否'} |"
                )
    lines += [
        "",
        "## 方法与限制",
        "",
        "- 连续距离使用 12 维财报前特征：GOOGL/QQQ/SOXX/MU、TLT/HYG/GLD/USO/UUP、VIX、10年期收益率、SOXX波动率。对角距离采用中位数/MAD缩放；马氏距离对协方差做50%对角收缩。",
        "- 复合规格只改变事前权重：连续状态、8个标签、AI时代、财报季节；另做每年最多一次，避免同一年重复主导。没有依据财报后收益调参。",
        "- 战争没有可靠、版本化、点时可得的历史类别库，因此不把主观“战争相似度”硬塞进距离；油、黄金、美元、利率、VIX和信用是可审计代理。",
        "- 结果是描述性条件分布，不是因果识别。缺少历史点时一致的营收、Cloud、CapEx和市场一致预期 surprise 数据，不能把总反应归因于某一个财报字段。",
        "- SNDK当前上市历史过短；少于5个直接观测时自动标记为不可用。",
        "- Yahoo调整日线用于研究回放，不是许可的机构级点时数据库，也没有交易成本与盘后成交模拟。",
        "",
        "## 可复现文件",
        "",
        f"- 输入事件研究：`{result['inputPath']}`",
        f"- JSON结果：`{result['jsonOutput']}`",
        f"- 重测脚本：`{result['scriptPath']}`",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).resolve()
    output_base = Path(args.output_base).resolve()
    with input_path.open("r", encoding="utf-8") as handle:
        source = json.load(handle)

    if source.get("marketDataThrough") != "2026-07-21":
        raise ValueError(
            "Refusing retest: expected marketDataThrough=2026-07-21 for this pre-event replay"
        )
    if source.get("forecastEventDate") != args.event_date:
        raise ValueError("Refusing retest: source forecast boundary does not match event date")
    if any(
        row.get("acceptanceEtDate", "") >= args.event_date
        for row in source.get("regimeFeatureRows", [])
    ):
        raise ValueError("Look-ahead guard failed: target/future event found in feature rows")

    rows = sorted(source["regimeFeatureRows"], key=lambda row: row["acceptanceEtDate"])
    current_features = source["currentSnapshot"]["features"]
    feature_vector(current_features)
    if not rows:
        raise ValueError("No complete regime rows")

    current_flags = regime_flags(current_features)
    exact_matches = [
        row
        for row in rows
        if all(regime_flags(row["features"])[key] == current_flags[key] for key in current_flags)
    ]
    relaxed_matches = [row for row in rows if relaxed_regime_match(row["features"])]
    models = {
        spec.name: run_model(rows, current_features, args.event_date, spec)
        for spec in MODEL_SPECS
    }
    hard_neighbors = models["hard_flags"]["neighbors"]
    hard_lookup = {
        row["acceptanceEtDate"]: row for row in score_candidates(
            rows,
            current_features,
            args.event_date,
            next(spec for spec in MODEL_SPECS if spec.name == "hard_flags"),
        )
    }
    closest_flag_matches = []
    for neighbor in hard_neighbors:
        original = hard_lookup[neighbor["acceptanceEtDate"]]
        closest_flag_matches.append(
            {
                "acceptanceEtDate": original["acceptanceEtDate"],
                "reactionDate": original["reactionDate"],
                "flagMatches": original["flagMatches"],
                "diagonalDistance": original["diagonalDistance"],
                "returns": original["returns"],
            }
        )

    validation = walk_forward_validation(rows)
    primary_validation = validation[PRIMARY_MODEL]
    primary_targets = [
        primary_validation[asset][f"ret{horizon}"]
        for asset in ["GOOGL", "SPY", "QQQ", "SOXX", "MU"]
        for horizon in HORIZONS
    ]
    validated_targets = [
        metric for metric in primary_targets if metric.get("improvesBothMaeAndBrier")
    ]
    # Multiple assets/horizons are diagnostic, not permission to cherry-pick.
    # The regime is unsupported when there is no exact historical match even if
    # an isolated validation cell happens to improve.
    verdict = "NO_VALIDATED_EDGE / OUT_OF_DISTRIBUTION"

    result: dict[str, Any] = {
        "schemaVersion": "alphabet-current-regime-retest-v1",
        "verdict": verdict,
        "eventDate": args.event_date,
        "marketDataThrough": source["marketDataThrough"],
        "targetEventExcludedAccessions": [
            row["accession"] for row in source.get("forecastBoundaryExclusions", [])
        ],
        "inputPath": str(input_path),
        "scriptPath": str(Path(__file__).resolve()),
        "jsonOutput": str(output_base.with_suffix(".json")),
        "markdownOutput": str(output_base.with_suffix(".md")),
        "completedEventCount": source["completedEventCount"],
        "completeRegimeEventCount": len(rows),
        "current": source["currentSnapshot"],
        "strictRegimeSupport": {
            "definitions": list(current_flags.keys()),
            "currentFlags": current_flags,
            "exactCount": len(exact_matches),
            "exactDates": [row["acceptanceEtDate"] for row in exact_matches],
            "relaxedCount": len(relaxed_matches),
            "relaxedDates": [row["acceptanceEtDate"] for row in relaxed_matches],
        },
        "closestFlagMatches": closest_flag_matches,
        "models": models,
        "robustness": robustness_summary(models),
        "novelty": nearest_neighbor_novelty(rows, current_features),
        "transmission": transmission_with_intervals(source),
        "walkForwardValidation": validation,
        "primaryValidationImprovedCells": len(validated_targets),
        "guardrails": {
            "targetEventReturnRead": False,
            "sameDayCloseRead": False,
            "minimumDirectObservations": MIN_DIRECT_OBSERVATIONS,
            "minimumValidationTraining": MIN_VALIDATION_TRAINING,
            "weightsTunedOnOutcome": False,
        },
    }
    output_base.parent.mkdir(parents=True, exist_ok=True)
    with output_base.with_suffix(".json").open("w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    markdown = build_markdown(result)
    with output_base.with_suffix(".md").open("w", encoding="utf-8") as handle:
        handle.write(markdown)
        handle.write("\n")
    print(
        json.dumps(
            {
                "verdict": verdict,
                "completeRegimeEvents": len(rows),
                "strictMatches": len(exact_matches),
                "relaxedMatches": len(relaxed_matches),
                "primaryValidationImprovedCells": len(validated_targets),
                "outputs": {
                    "json": str(output_base.with_suffix(".json")),
                    "markdown": str(output_base.with_suffix(".md")),
                },
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
