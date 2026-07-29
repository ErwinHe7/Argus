from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Iterable, Sequence
from datetime import date, datetime
from typing import Any, Mapping

import numpy as np
import pandas as pd


VALIDATION_SCHEMA_VERSION = "intraday_quant.validation.v2"
HOLDOUT_MANIFEST_SCHEMA_VERSION = "intraday_quant.untouched_holdout.v1"
MARKET_BASELINE_MANIFEST_SCHEMA_VERSION = "intraday_quant.market_baseline.v1"
DEFAULT_COST_GRID_BPS = (0.0, 1.0, 3.0, 5.0, 10.0, 20.0)


def _canonical_json_value(value: object) -> object:
    if isinstance(value, Mapping):
        return {
            str(key): _canonical_json_value(item)
            for key, item in sorted(value.items(), key=lambda pair: str(pair[0]))
        }
    if isinstance(value, (list, tuple)):
        return [_canonical_json_value(item) for item in value]
    if value is None or value is pd.NA or value is pd.NaT:
        return None
    if isinstance(value, (pd.Timestamp, datetime)):
        timestamp = pd.Timestamp(value)
        if timestamp.tzinfo is not None:
            timestamp = timestamp.tz_convert("UTC")
        return timestamp.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, (np.bool_, bool)):
        return bool(value)
    if isinstance(value, (np.integer, int)):
        return int(value)
    if isinstance(value, (np.floating, float)):
        numeric = float(value)
        if np.isnan(numeric):
            return {"__nonfinite_float__": "nan"}
        if np.isposinf(numeric):
            return {"__nonfinite_float__": "positive_infinity"}
        if np.isneginf(numeric):
            return {"__nonfinite_float__": "negative_infinity"}
        return 0.0 if numeric == 0 else numeric
    if isinstance(value, str):
        return value
    try:
        missing = bool(pd.isna(value))
    except (TypeError, ValueError):
        missing = False
    if missing:
        return None
    raise TypeError(
        f"unsupported value type in validation evidence: {type(value).__name__}"
    )


def canonical_frame_sha256(
    frame: pd.DataFrame,
    columns: Sequence[str] | None = None,
) -> str:
    """Hash a validation frame independent of row and column ordering.

    The hash binds duplicate rows and exact scalar values. Unsupported nested
    objects fail rather than being stringified into an ambiguous receipt.
    """

    if frame.columns.duplicated().any():
        raise ValueError("cannot hash a frame with duplicate column names")
    selected = list(columns) if columns is not None else list(frame.columns)
    if not selected or len(selected) != len(set(selected)):
        raise ValueError("dataset_columns must be non-empty and unique")
    missing = sorted(set(selected) - set(frame.columns))
    if missing:
        raise ValueError(f"dataset_columns are missing from frame: {missing}")
    ordered_columns = sorted(selected)
    serialized_rows = [
        json.dumps(
            {
                column: _canonical_json_value(value)
                for column, value in zip(ordered_columns, row, strict=True)
            },
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
        for row in frame.loc[:, ordered_columns].itertuples(index=False, name=None)
    ]
    serialized_rows.sort()
    payload = json.dumps(
        {
            "columns": ordered_columns,
            "row_count": len(serialized_rows),
            "rows": serialized_rows,
        },
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def canonical_evidence_sha256(value: object) -> str:
    """Hash a JSON-compatible evidence object using canonical scalar encoding."""

    payload = json.dumps(
        _canonical_json_value(value),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _is_sha256(value: object) -> bool:
    if not isinstance(value, str) or len(value) != 64:
        return False
    try:
        int(value, 16)
    except ValueError:
        return False
    return True


def _strict_utc(values: pd.Series) -> tuple[pd.Series, int]:
    parsed: list[pd.Timestamp | pd.NaT] = []
    invalid = 0
    for value in values:
        try:
            timestamp = pd.Timestamp(value)
        except (TypeError, ValueError):
            timestamp = pd.NaT
        if pd.isna(timestamp) or timestamp.tzinfo is None:
            parsed.append(pd.NaT)
            invalid += 1
        else:
            parsed.append(timestamp.tz_convert("UTC"))
    return pd.Series(parsed, index=values.index, dtype="datetime64[ns, UTC]"), invalid


def _manifest_columns(manifest: Mapping[str, object]) -> list[str] | None:
    raw_columns = manifest.get("dataset_columns")
    if (
        not isinstance(raw_columns, Sequence)
        or isinstance(raw_columns, (str, bytes))
        or not raw_columns
        or any(not isinstance(column, str) or not column for column in raw_columns)
    ):
        return None
    columns = list(raw_columns)
    return columns if len(columns) == len(set(columns)) else None


def _verified_manifest_hash(
    frame: pd.DataFrame,
    manifest: Mapping[str, object],
) -> tuple[bool, str, list[str] | None]:
    columns = _manifest_columns(manifest)
    expected = manifest.get("dataset_sha256")
    if columns is None:
        return False, "manifest_dataset_columns_invalid", None
    if not _is_sha256(expected):
        return False, "manifest_dataset_sha256_invalid", columns
    try:
        actual = canonical_frame_sha256(frame, columns)
    except (TypeError, ValueError) as exc:
        return False, f"dataset_hash_unavailable:{exc}", columns
    if actual != str(expected).lower():
        return False, "dataset_sha256_mismatch", columns
    return True, "dataset_sha256_verified", columns


def _finite(frame: pd.DataFrame, column: str) -> pd.Series:
    if column not in frame:
        return pd.Series(dtype=float)
    values = pd.to_numeric(frame[column], errors="coerce")
    return values[np.isfinite(values)]


def _date_values(values: Iterable[object]) -> list[object]:
    converted = pd.to_datetime(pd.Series(list(values)), errors="coerce")
    return converted.dropna().dt.date.tolist()


def _daily_returns(
    trades: pd.DataFrame,
    column: str,
    candidate_dates: Sequence[object] | None = None,
) -> pd.Series:
    if trades.empty or column not in trades or "date" not in trades:
        dates = sorted(set(_date_values(candidate_dates or [])))
        return pd.Series(0.0, index=dates, dtype=float)
    working = trades[["date", column]].copy()
    working["date"] = pd.to_datetime(working["date"], errors="coerce").dt.date
    working[column] = pd.to_numeric(working[column], errors="coerce")
    working = working.dropna(subset=["date", column])
    daily = working.groupby("date", sort=True)[column].sum().astype(float)
    dates = sorted(set(_date_values(candidate_dates or [])) | set(daily.index))
    return daily.reindex(dates, fill_value=0.0)


def _compound(daily_returns: pd.Series) -> float:
    if daily_returns.empty:
        return 0.0
    return float(np.prod(1.0 + daily_returns.to_numpy(dtype=float)) - 1.0)


def _interval(
    estimate: float | None, samples: np.ndarray, alpha: float
) -> dict[str, float | int | None]:
    finite = samples[np.isfinite(samples)]
    if estimate is None or not np.isfinite(estimate) or not len(finite):
        return {
            "estimate": estimate,
            "lower": None,
            "upper": None,
            "finite_resamples": int(len(finite)),
        }
    return {
        "estimate": float(estimate),
        "lower": float(np.quantile(finite, alpha / 2)),
        "upper": float(np.quantile(finite, 1 - alpha / 2)),
        "finite_resamples": int(len(finite)),
    }


def _session_bootstrap(
    trades: pd.DataFrame,
    *,
    candidate_dates: Sequence[object] | None,
    confidence_level: float,
    resamples: int,
    random_seed: int,
    block_length: int | None,
) -> dict[str, object]:
    required = {"date", "gross_return", "net_return"}
    if trades.empty or not required.issubset(trades):
        return {
            "status": "insufficient_data",
            "method": "moving_block_bootstrap_over_ordered_sessions",
            "confidence_level": confidence_level,
            "resamples": 0,
            "session_count": 0,
            "block_length_sessions": None,
        }
    working = trades[["date", "gross_return", "net_return"]].copy()
    working["date"] = pd.to_datetime(working["date"], errors="coerce").dt.date
    working["gross_return"] = pd.to_numeric(working["gross_return"], errors="coerce")
    working["net_return"] = pd.to_numeric(working["net_return"], errors="coerce")
    working = working.replace([np.inf, -np.inf], np.nan).dropna()
    if working.empty:
        return {
            "status": "insufficient_data",
            "method": "moving_block_bootstrap_over_ordered_sessions",
            "confidence_level": confidence_level,
            "resamples": 0,
            "session_count": 0,
            "block_length_sessions": None,
        }
    grouped = working.groupby("date", sort=True)
    sessions = pd.DataFrame(
        {
            "gross_sum": grouped["gross_return"].sum(),
            "net_sum": grouped["net_return"].sum(),
            "trade_count": grouped.size(),
            "win_count": grouped["net_return"].apply(lambda values: int((values > 0).sum())),
        }
    )
    all_dates = sorted(
        set(_date_values(candidate_dates or [])) | set(sessions.index)
    )
    sessions = sessions.reindex(all_dates, fill_value=0.0)
    session_count = len(sessions)
    if session_count < 2 or resamples <= 0:
        return {
            "status": "insufficient_sessions_lt_2",
            "method": "moving_block_bootstrap_over_ordered_sessions",
            "confidence_level": confidence_level,
            "resamples": 0,
            "session_count": session_count,
            "block_length_sessions": None,
        }
    chosen_block_length = block_length or max(1, int(round(math.sqrt(session_count))))
    chosen_block_length = min(max(1, chosen_block_length), session_count)
    blocks_per_sample = math.ceil(session_count / chosen_block_length)
    last_start = session_count - chosen_block_length
    rng = np.random.default_rng(random_seed)
    values = sessions.to_numpy(dtype=float)
    bootstrap = np.empty((resamples, 5), dtype=float)
    for sample_index in range(resamples):
        starts = rng.integers(0, last_start + 1, size=blocks_per_sample)
        indices = np.concatenate(
            [
                np.arange(start, start + chosen_block_length, dtype=int)
                for start in starts
            ]
        )[:session_count]
        sampled = values[indices]
        trade_count = sampled[:, 2].sum()
        bootstrap[sample_index, 0] = (
            sampled[:, 0].sum() / trade_count if trade_count else np.nan
        )
        bootstrap[sample_index, 1] = (
            sampled[:, 1].sum() / trade_count if trade_count else np.nan
        )
        bootstrap[sample_index, 2] = (
            sampled[:, 3].sum() / trade_count if trade_count else np.nan
        )
        bootstrap[sample_index, 3] = np.prod(1.0 + sampled[:, 1]) - 1.0
        bootstrap[sample_index, 4] = bootstrap[sample_index, 0] * 10_000
    gross = working["gross_return"].to_numpy(dtype=float)
    net = working["net_return"].to_numpy(dtype=float)
    alpha = 1.0 - confidence_level
    if session_count < 30 and len(working) < 30:
        status = "exploratory_small_sample_lt_30_sessions_and_trades"
    elif session_count < 30:
        status = "exploratory_small_sample_lt_30_sessions"
    elif len(working) < 30:
        status = "exploratory_small_sample_lt_30_trades"
    else:
        status = "reported"
    return {
        "status": status,
        "method": "moving_block_bootstrap_over_ordered_sessions",
        "confidence_level": confidence_level,
        "resamples": int(resamples),
        "random_seed": int(random_seed),
        "session_count": int(session_count),
        "trade_count": int(len(working)),
        "no_trade_session_count": int((sessions["trade_count"] == 0).sum()),
        "block_length_sessions": int(chosen_block_length),
        "mean_gross_return_per_trade": _interval(float(gross.mean()), bootstrap[:, 0], alpha),
        "mean_net_return_per_trade": _interval(float(net.mean()), bootstrap[:, 1], alpha),
        "net_win_rate": _interval(float((net > 0).mean()), bootstrap[:, 2], alpha),
        "compounded_net_return": _interval(
            _compound(sessions["net_sum"]), bootstrap[:, 3], alpha
        ),
        "breakeven_round_trip_cost_bps": _interval(
            float(gross.mean() * 10_000), bootstrap[:, 4], alpha
        ),
        "caveat": (
            "All observed sessions, including zero-return no-trade sessions, are resampled; "
            "contiguous session blocks preserve some serial and within-session dependence. "
            "This interval is not promotion evidence."
        ),
    }


def _effective_session_sample_size(daily_net_returns: pd.Series) -> dict[str, object]:
    values = daily_net_returns.to_numpy(dtype=float)
    values = values[np.isfinite(values)]
    count = len(values)
    if count < 3:
        return {
            "status": "not_estimable_lt_3_sessions",
            "raw_session_count": int(count),
            "effective_independent_sessions": None,
            "method": "initial_positive_autocorrelation_sequence",
        }
    centered = values - values.mean()
    denominator = float(np.dot(centered, centered))
    if denominator <= np.finfo(float).eps:
        return {
            "status": "not_estimable_zero_variance",
            "raw_session_count": int(count),
            "effective_independent_sessions": None,
            "method": "initial_positive_autocorrelation_sequence",
        }
    maximum_lag = min(10, count - 1)
    positive_sum = 0.0
    lags_used = 0
    autocorrelations: list[float] = []
    for lag in range(1, maximum_lag + 1):
        correlation = float(np.dot(centered[:-lag], centered[lag:]) / denominator)
        autocorrelations.append(correlation)
        if not np.isfinite(correlation) or correlation <= 0:
            break
        positive_sum += correlation
        lags_used = lag
    effective = count / (1.0 + 2.0 * positive_sum)
    effective = min(float(count), max(1.0, float(effective)))
    return {
        "status": "estimated",
        "raw_session_count": int(count),
        "effective_independent_sessions": effective,
        "method": "initial_positive_autocorrelation_sequence",
        "maximum_lag_considered": int(maximum_lag),
        "positive_lags_used": int(lags_used),
        "positive_autocorrelation_sum": float(positive_sum),
        "autocorrelations": autocorrelations,
        "caveat": "An ESS estimate is descriptive and does not make overlapping observations independent.",
        "series_scope": "all_observed_sessions_including_zero_return_no_trade_sessions",
    }


def _monthly_stability(
    trades: pd.DataFrame,
    *,
    candidate_dates: Sequence[object] | None,
    minimum_months: int,
) -> dict[str, object]:
    if minimum_months < 1:
        raise ValueError("monthly_stability_minimum_months must be positive")
    if not {"date", "gross_return", "net_return"}.issubset(trades):
        return {
            "status": "unavailable_missing_date_or_return_columns",
            "month_count": 0,
            "months": [],
        }
    trade_dates = pd.to_datetime(trades["date"], errors="coerce")
    raw_candidate_dates = (
        list(candidate_dates) if candidate_dates is not None else []
    )
    parsed_candidate_dates = pd.to_datetime(
        pd.Series(raw_candidate_dates, dtype=object), errors="coerce"
    )
    invalid_trade_dates = int(trade_dates.isna().sum())
    invalid_candidate_dates = int(parsed_candidate_dates.isna().sum())
    if invalid_trade_dates or invalid_candidate_dates:
        return {
            "status": "invalid_dates_fail_closed",
            "invalid_trade_date_rows": invalid_trade_dates,
            "invalid_candidate_dates": invalid_candidate_dates,
            "month_count": 0,
            "months": [],
        }
    observed_dates = sorted(
        set(trade_dates.dt.date)
        | set(parsed_candidate_dates.dropna().dt.date)
    )
    if not observed_dates:
        return {
            "status": "insufficient_data_no_observed_sessions",
            "month_count": 0,
            "months": [],
        }
    gross_daily = _daily_returns(trades, "gross_return", observed_dates)
    net_daily = _daily_returns(trades, "net_return", observed_dates)
    trade_frame = trades.copy()
    trade_frame["_date"] = trade_dates.dt.date
    trade_frame["_month"] = trade_dates.dt.to_period("M").astype(str)
    trade_frame["gross_return"] = pd.to_numeric(
        trade_frame["gross_return"], errors="coerce"
    )
    trade_frame["net_return"] = pd.to_numeric(
        trade_frame["net_return"], errors="coerce"
    )
    if not np.isfinite(trade_frame[["gross_return", "net_return"]]).all(axis=None):
        return {
            "status": "nonfinite_return_rows_fail_closed",
            "month_count": 0,
            "months": [],
        }
    session_frame = pd.DataFrame(
        {
            "date": observed_dates,
            "gross_return": gross_daily.reindex(observed_dates).to_numpy(dtype=float),
            "net_return": net_daily.reindex(observed_dates).to_numpy(dtype=float),
        }
    )
    session_frame["month"] = (
        pd.to_datetime(session_frame["date"]).dt.to_period("M").astype(str)
    )
    months: list[dict[str, object]] = []
    for month, sessions in session_frame.groupby("month", sort=True):
        month_trades = trade_frame.loc[trade_frame["_month"] == month]
        net_returns = month_trades["net_return"]
        traded_dates = set(month_trades["_date"])
        months.append(
            {
                "month": str(month),
                "observed_session_count": int(len(sessions)),
                "no_trade_session_count": int(
                    (~sessions["date"].isin(traded_dates)).sum()
                ),
                "trade_count": int(len(month_trades)),
                "gross_arithmetic_return_sum": float(
                    month_trades["gross_return"].sum()
                ),
                "net_arithmetic_return_sum": float(net_returns.sum()),
                "gross_compounded_return": _compound(sessions["gross_return"]),
                "net_compounded_return": _compound(sessions["net_return"]),
                "mean_net_return_per_trade": (
                    float(net_returns.mean()) if len(net_returns) else None
                ),
                "net_positive_trade_rate": (
                    float((net_returns > 0).mean()) if len(net_returns) else None
                ),
                "positive_net_session_rate": float(
                    (sessions["net_return"] > 0).mean()
                ),
            }
        )
    month_net = np.asarray(
        [float(row["net_compounded_return"]) for row in months], dtype=float
    )
    enough = len(months) >= minimum_months
    return {
        "status": (
            "reported_descriptive"
            if enough
            else f"exploratory_insufficient_months_lt_{minimum_months}"
        ),
        "month_count": int(len(months)),
        "minimum_months_for_stability_summary": int(minimum_months),
        "positive_month_count": int((month_net > 0).sum()),
        "negative_month_count": int((month_net < 0).sum()),
        "zero_month_count": int((month_net == 0).sum()),
        "positive_month_rate": float((month_net > 0).mean()),
        "best_month_net_compounded_return": float(month_net.max()),
        "worst_month_net_compounded_return": float(month_net.min()),
        "months": months,
        "scope": (
            "all supplied observed sessions including zero-return no-trade sessions; "
            "candidate_dates are not assumed to be a complete exchange calendar"
        ),
        "caveat": "Monthly stability is descriptive and is not promotion evidence.",
    }


def _regime_stability(
    trades: pd.DataFrame,
    *,
    regime_column: str,
    regime_observed_at_column: str,
    regime_model_version_column: str,
    regime_feature_version_column: str,
    minimum_trades_per_regime: int,
) -> dict[str, object]:
    if minimum_trades_per_regime < 1:
        raise ValueError("regime_stability_minimum_trades must be positive")
    signal_column = "signal_time" if "signal_time" in trades else "entry_time"
    required = {
        "gross_return",
        "net_return",
        signal_column,
        regime_column,
        regime_observed_at_column,
        regime_model_version_column,
        regime_feature_version_column,
    }
    missing = sorted(required - set(trades.columns))
    if missing or trades.empty:
        return {
            "status": (
                "unavailable_no_trades"
                if trades.empty
                else "unavailable_missing_point_in_time_regime_lineage"
            ),
            "missing_columns": missing,
            "regime_count": 0,
            "regimes": [],
        }
    signal_times, invalid_signal_times = _strict_utc(trades[signal_column])
    observed_times, invalid_observed_times = _strict_utc(
        trades[regime_observed_at_column]
    )
    regimes = trades[regime_column].fillna("").astype(str).str.strip()
    model_versions = (
        trades[regime_model_version_column].fillna("").astype(str).str.strip()
    )
    feature_versions = (
        trades[regime_feature_version_column].fillna("").astype(str).str.strip()
    )
    noncausal = int((observed_times > signal_times).fillna(False).sum())
    invalid_lineage_rows = int(
        regimes.eq("").sum()
        + model_versions.eq("").sum()
        + feature_versions.eq("").sum()
    )
    if (
        invalid_signal_times
        or invalid_observed_times
        or noncausal
        or invalid_lineage_rows
    ):
        return {
            "status": "invalid_or_noncausal_regime_rows_fail_closed",
            "invalid_signal_time_rows": int(invalid_signal_times),
            "invalid_regime_observed_at_rows": int(invalid_observed_times),
            "regime_observed_after_signal_rows": noncausal,
            "blank_lineage_value_count": invalid_lineage_rows,
            "regime_count": 0,
            "regimes": [],
        }
    lineage_pairs = set(zip(model_versions, feature_versions, strict=True))
    if len(lineage_pairs) != 1:
        return {
            "status": "mixed_regime_lineage_fail_closed",
            "lineage_pair_count": int(len(lineage_pairs)),
            "regime_count": 0,
            "regimes": [],
        }
    working = trades.copy()
    working["_regime"] = regimes
    working["_signal_time"] = signal_times
    working["_regime_observed_at"] = observed_times
    rows: list[dict[str, object]] = []
    for regime, group in working.groupby("_regime", sort=True):
        gross = pd.to_numeric(group["gross_return"], errors="coerce")
        net = pd.to_numeric(group["net_return"], errors="coerce")
        finite = np.isfinite(pd.DataFrame({"gross": gross, "net": net})).all(axis=1)
        if not finite.all():
            return {
                "status": "nonfinite_regime_return_rows_fail_closed",
                "invalid_return_rows": int((~finite).sum()),
                "regime_count": 0,
                "regimes": [],
            }
        session_count = (
            int(pd.Series(signal_times.loc[group.index].dt.date).nunique())
            if len(group)
            else 0
        )
        rows.append(
            {
                "regime": str(regime),
                "trade_count": int(len(group)),
                "session_count": session_count,
                "sample_status": (
                    "descriptive_sample"
                    if len(group) >= minimum_trades_per_regime
                    else f"insufficient_trades_lt_{minimum_trades_per_regime}"
                ),
                "mean_gross_return_per_trade": float(gross.mean()),
                "mean_net_return_per_trade": float(net.mean()),
                "median_net_return_per_trade": float(net.median()),
                "net_positive_trade_rate": float((net > 0).mean()),
                "net_arithmetic_return_sum": float(net.sum()),
                "first_signal_time": signal_times.loc[group.index].min().isoformat(),
                "last_signal_time": signal_times.loc[group.index].max().isoformat(),
            }
        )
    model_version, feature_version = next(iter(lineage_pairs))
    enough_regimes = len(rows) >= 2
    all_regimes_sufficient = all(
        row["sample_status"] == "descriptive_sample" for row in rows
    )
    regime_means = np.asarray(
        [float(row["mean_net_return_per_trade"]) for row in rows], dtype=float
    )
    return {
        "status": (
            "reported_descriptive"
            if enough_regimes and all_regimes_sufficient
            else "exploratory_insufficient_regime_coverage"
        ),
        "regime_count": int(len(rows)),
        "minimum_trades_per_regime": int(minimum_trades_per_regime),
        "regime_model_version": model_version,
        "regime_feature_version": feature_version,
        "positive_mean_net_regime_count": int((regime_means > 0).sum()),
        "nonpositive_mean_net_regime_count": int((regime_means <= 0).sum()),
        "mean_net_return_range_across_regimes": (
            float(regime_means.max() - regime_means.min())
            if len(regime_means)
            else None
        ),
        "causality_check": (
            f"{regime_observed_at_column} <= {signal_column} for every reported trade"
        ),
        "regimes": rows,
        "scope": "selected out-of-sample trades only",
        "caveat": (
            "Regime membership must have been frozen and available by signal time. "
            "These subgroup diagnostics are not model-selection or promotion evidence."
        ),
    }


def _session_sign_flip_placebo(
    trades: pd.DataFrame,
    *,
    resamples: int,
    random_seed: int,
    minimum_sessions: int,
) -> dict[str, object]:
    if resamples < 1:
        raise ValueError("placebo_resamples must be positive")
    if minimum_sessions < 2:
        raise ValueError("placebo_minimum_sessions must be at least two")
    required = {"date", "gross_return", "net_return"}
    if trades.empty or not required.issubset(trades):
        return {
            "status": "insufficient_data",
            "control_id": "session_clustered_gross_return_sign_flip",
            "resamples": 0,
        }
    dates = pd.to_datetime(trades["date"], errors="coerce")
    gross = pd.to_numeric(trades["gross_return"], errors="coerce")
    net = pd.to_numeric(trades["net_return"], errors="coerce")
    finite = np.isfinite(pd.DataFrame({"gross": gross, "net": net})).all(axis=1)
    if dates.isna().any() or not finite.all():
        return {
            "status": "invalid_dates_or_returns_fail_closed",
            "control_id": "session_clustered_gross_return_sign_flip",
            "invalid_date_rows": int(dates.isna().sum()),
            "invalid_return_rows": int((~finite).sum()),
            "resamples": 0,
        }
    inferred_cost = gross - net
    negative_cost_rows = int((inferred_cost < -1e-12).sum())
    if negative_cost_rows:
        return {
            "status": "gross_net_cost_inconsistency_fail_closed",
            "control_id": "session_clustered_gross_return_sign_flip",
            "negative_inferred_cost_rows": negative_cost_rows,
            "resamples": 0,
        }
    clustered = pd.DataFrame(
        {"date": dates.dt.date, "gross": gross, "trades": 1}
    ).groupby("date", sort=True).agg(
        gross_sum=("gross", "sum"),
        trade_count=("trades", "sum"),
    )
    session_count = len(clustered)
    if session_count < minimum_sessions:
        return {
            "status": f"insufficient_sessions_lt_{minimum_sessions}",
            "control_id": "session_clustered_gross_return_sign_flip",
            "session_count": int(session_count),
            "trade_count": int(len(trades)),
            "resamples": 0,
        }
    rng = np.random.default_rng(random_seed)
    session_gross = clustered["gross_sum"].to_numpy(dtype=float)
    placebo = np.empty(resamples, dtype=float)
    for index in range(resamples):
        signs = rng.choice(np.asarray([-1.0, 1.0]), size=session_count)
        placebo[index] = float(np.dot(signs, session_gross) / len(trades))
    observed = float(gross.mean())
    two_sided_p = float(
        (1 + int((np.abs(placebo) >= abs(observed)).sum())) / (resamples + 1)
    )
    return {
        "status": "reported_diagnostic_not_promotion_evidence",
        "control_id": "session_clustered_gross_return_sign_flip",
        "tested_statistic": "mean_gross_return_per_trade",
        "observed_statistic": observed,
        "null_mean": float(placebo.mean()),
        "null_median": float(np.median(placebo)),
        "null_q025": float(np.quantile(placebo, 0.025)),
        "null_q975": float(np.quantile(placebo, 0.975)),
        "two_sided_plus_one_p_value": two_sided_p,
        "session_count": int(session_count),
        "trade_count": int(len(trades)),
        "resamples": int(resamples),
        "random_seed": int(random_seed),
        "construction": (
            "one Rademacher sign per session applied to observed gross returns; "
            "within-session dependence and absolute magnitudes are preserved"
        ),
        "assumption": "session-cluster gross returns are sign-exchangeable under the null",
        "caveat": (
            "This placebo diagnoses directional alignment under a sign-exchangeability "
            "null. It is not proof of causality, calibration, or deployable edge."
        ),
    }


def benjamini_hochberg(
    hypotheses: pd.DataFrame | None,
    *,
    alpha: float = 0.05,
) -> dict[str, object]:
    """Apply deterministic BH correction separately within declared families."""

    if not np.isfinite(alpha) or not 0 < alpha < 1:
        raise ValueError("fdr_alpha must be strictly between zero and one")
    if hypotheses is None or hypotheses.empty:
        return {
            "status": "not_supplied",
            "method": "benjamini_hochberg_within_declared_family",
            "alpha": float(alpha),
            "hypothesis_count": 0,
            "families": [],
        }
    required = {
        "hypothesis_id",
        "family",
        "p_value",
        "test_kind",
        "pre_registered",
    }
    missing = sorted(required - set(hypotheses.columns))
    if missing:
        return {
            "status": "invalid_contract_fail_closed",
            "method": "benjamini_hochberg_within_declared_family",
            "alpha": float(alpha),
            "missing_columns": missing,
            "hypothesis_count": int(len(hypotheses)),
            "families": [],
        }
    frame = hypotheses.loc[:, sorted(required)].copy()
    frame["hypothesis_id"] = frame["hypothesis_id"].fillna("").astype(str).str.strip()
    frame["family"] = frame["family"].fillna("").astype(str).str.strip()
    frame["test_kind"] = frame["test_kind"].fillna("").astype(str).str.strip()
    frame["p_value"] = pd.to_numeric(frame["p_value"], errors="coerce")
    valid_kinds = {"primary", "negative_control", "placebo"}
    preregistered_values = set(frame["pre_registered"].dropna().map(type))
    invalid_boolean_contract = not preregistered_values.issubset({bool, np.bool_})
    invalid_contract = (
        frame["hypothesis_id"].eq("").any()
        or frame["hypothesis_id"].duplicated().any()
        or frame["family"].eq("").any()
        or (~frame["test_kind"].isin(valid_kinds)).any()
        or frame["pre_registered"].isna().any()
        or invalid_boolean_contract
    )
    if invalid_contract:
        return {
            "status": "invalid_contract_fail_closed",
            "method": "benjamini_hochberg_within_declared_family",
            "alpha": float(alpha),
            "hypothesis_count": int(len(frame)),
            "families": [],
        }
    families: list[dict[str, object]] = []
    any_invalid_family = False
    for family, group in frame.groupby("family", sort=True):
        invalid_p = ~np.isfinite(group["p_value"]) | group["p_value"].lt(0) | group[
            "p_value"
        ].gt(1)
        if invalid_p.any():
            any_invalid_family = True
            families.append(
                {
                    "family": str(family),
                    "status": "invalid_p_values_fail_closed",
                    "hypothesis_count": int(len(group)),
                    "invalid_p_value_count": int(invalid_p.sum()),
                    "results": [],
                }
            )
            continue
        ordered = group.sort_values(
            ["p_value", "hypothesis_id"], kind="mergesort"
        ).reset_index(drop=True)
        count = len(ordered)
        adjusted = np.empty(count, dtype=float)
        running_minimum = 1.0
        for reverse_index in range(count - 1, -1, -1):
            rank = reverse_index + 1
            candidate = float(ordered.loc[reverse_index, "p_value"]) * count / rank
            running_minimum = min(running_minimum, candidate)
            adjusted[reverse_index] = min(1.0, running_minimum)
        results = []
        for row_index, row in ordered.iterrows():
            adjusted_p = float(adjusted[row_index])
            results.append(
                {
                    "hypothesis_id": str(row["hypothesis_id"]),
                    "test_kind": str(row["test_kind"]),
                    "pre_registered": bool(row["pre_registered"]),
                    "raw_p_value": float(row["p_value"]),
                    "adjusted_p_value": adjusted_p,
                    "rejected_at_alpha": bool(adjusted_p <= alpha),
                    "evidence_scope": (
                        "pre_registered"
                        if bool(row["pre_registered"])
                        else "exploratory_not_pre_registered"
                    ),
                }
            )
        families.append(
            {
                "family": str(family),
                "status": "reported_descriptive",
                "hypothesis_count": int(count),
                "invalid_p_value_count": 0,
                "results": results,
            }
        )
    return {
        "status": (
            "partial_fail_closed_invalid_families"
            if any_invalid_family
            else "reported_descriptive_not_promotion_evidence"
        ),
        "method": "benjamini_hochberg_within_declared_family",
        "alpha": float(alpha),
        "hypothesis_count": int(len(frame)),
        "family_count": int(len(families)),
        "families": families,
        "caveat": (
            "Correction controls the expected false-discovery proportion only within "
            "each declared family under BH assumptions; it does not repair data leakage "
            "or convert exploratory tests into promotion evidence."
        ),
    }


def _trade_interval_overlap(trades: pd.DataFrame) -> dict[str, object]:
    start_column = "entry_time" if "entry_time" in trades else "signal_time"
    required = {start_column, "exit_time"}
    if trades.empty or not required.issubset(trades):
        return {
            "status": "unavailable_missing_trade_intervals",
            "overlapping_trade_pairs": None,
            "trades_in_any_overlap": None,
            "maximum_concurrent_trades": None,
        }
    working = trades[[start_column, "exit_time"]].copy()
    working["start"] = pd.to_datetime(working[start_column], errors="coerce", utc=True)
    working["end"] = pd.to_datetime(working["exit_time"], errors="coerce", utc=True)
    invalid = working["start"].isna() | working["end"].isna() | (
        working["end"] < working["start"]
    )
    valid = (
        working.loc[~invalid, ["start", "end"]]
        .sort_values(["start", "end"])
        .reset_index(drop=True)
    )
    active: list[tuple[pd.Timestamp, int]] = []
    involved: set[int] = set()
    pair_count = 0
    maximum_concurrent = 0
    for row_index, row in valid.iterrows():
        active = [(end, index) for end, index in active if end > row["start"]]
        pair_count += len(active)
        if active:
            involved.add(int(row_index))
            involved.update(index for _, index in active)
        active.append((row["end"], int(row_index)))
        maximum_concurrent = max(maximum_concurrent, len(active))
    return {
        "status": "overlap_detected" if pair_count else "no_interval_overlap_detected",
        "interval_start_field": start_column,
        "valid_interval_rows": int(len(valid)),
        "invalid_interval_rows": int(invalid.sum()),
        "overlapping_trade_pairs": int(pair_count),
        "trades_in_any_overlap": int(len(involved)),
        "maximum_concurrent_trades": int(maximum_concurrent),
    }


def _prediction_fold_overlap(predictions: pd.DataFrame) -> dict[str, object]:
    required = {"candidate_id", "horizon_minutes", "fold", "timestamp"}
    if predictions.empty or not required.issubset(predictions):
        return {
            "status": "unavailable_missing_prediction_assignments",
            "candidate_horizon_assignments_in_multiple_test_folds": None,
            "horizon_sessions_in_multiple_test_folds": None,
            "training_vs_display_window_overlap": (
                "not_assessable_without_frozen_training_window_metadata"
            ),
        }
    projected = predictions[
        ["candidate_id", "horizon_minutes", "fold", "timestamp"]
    ].copy()
    projected["timestamp"] = pd.to_datetime(
        projected["timestamp"], errors="coerce", utc=True
    )
    valid_projection = projected.dropna()
    invalid_rows = len(projected) - len(valid_projection)
    assignments = valid_projection.drop_duplicates().copy()
    duplicate_rows = len(valid_projection) - len(assignments)
    candidate_fold_counts = assignments.groupby(
        ["candidate_id", "horizon_minutes"], dropna=False
    )["fold"].nunique()
    assignments["session_date"] = assignments["timestamp"].dt.date
    session_fold_counts = assignments.groupby(
        ["horizon_minutes", "session_date"], dropna=False
    )["fold"].nunique()
    candidate_collisions = int((candidate_fold_counts > 1).sum())
    session_collisions = int((session_fold_counts > 1).sum())
    return {
        "status": (
            "test_fold_overlap_detected"
            if candidate_collisions or session_collisions
            else "no_test_fold_assignment_overlap_detected"
        ),
        "distinct_candidate_horizon_assignments": int(len(candidate_fold_counts)),
        "candidate_horizon_assignments_in_multiple_test_folds": candidate_collisions,
        "distinct_horizon_sessions": int(len(session_fold_counts)),
        "horizon_sessions_in_multiple_test_folds": session_collisions,
        "duplicate_model_family_rows_ignored": int(duplicate_rows),
        "invalid_assignment_rows_ignored": int(invalid_rows),
        "training_vs_display_window_overlap": (
            "not_assessable_without_frozen_training_window_metadata"
        ),
        "caveat": (
            "This detects duplicate OOS fold assignment only. Training/replay date overlap "
            "requires immutable artifact train/validation/test boundaries."
        ),
    }


def _label_accounting(
    candidates: pd.DataFrame,
    labels: pd.DataFrame,
    predictions: pd.DataFrame,
    forecast_horizons: Sequence[int],
) -> dict[str, object]:
    candidate_ids = (
        candidates["candidate_id"].dropna().astype(str)
        if "candidate_id" in candidates
        else pd.Series(dtype=str)
    )
    label_ids = (
        labels["candidate_id"].dropna().astype(str)
        if "candidate_id" in labels
        else pd.Series(dtype=str)
    )
    detected_ids = set(candidate_ids)
    present_label_ids = set(label_ids)
    entry_status_counts = (
        {
            str(key): int(value)
            for key, value in labels["entry_status"]
            .fillna("status_missing")
            .astype(str)
            .value_counts(dropna=False)
            .items()
        }
        if "entry_status" in labels
        else {}
    )
    barrier_status_counts = (
        {
            str(key): int(value)
            for key, value in labels["barrier_label_status"]
            .fillna("status_missing")
            .astype(str)
            .value_counts(dropna=False)
            .items()
        }
        if "barrier_label_status" in labels
        else {}
    )
    aggregate_exclusion_counts: dict[str, int] = {}
    if "label_exclusion_reasons" in labels:
        for raw_reasons in labels["label_exclusion_reasons"].fillna("").astype(str):
            for reason in {item for item in raw_reasons.split("|") if item}:
                aggregate_exclusion_counts[reason] = (
                    aggregate_exclusion_counts.get(reason, 0) + 1
                )
    horizon_rows: list[dict[str, object]] = []
    explicit_status_seen = False
    late_status_markers = (
        "insufficient_forward",
        "cross_session",
        "entry_unavailable",
        "missing_exact_next_minute_entry",
    )
    for horizon in forecast_horizons:
        return_column = f"forward_return_{horizon}m"
        status_column = f"forward_label_status_{horizon}m"
        if return_column in labels:
            values = pd.to_numeric(labels[return_column], errors="coerce")
            finite = np.isfinite(values)
        else:
            finite = pd.Series(False, index=labels.index)
        reason_counts: dict[str, int] = {}
        late_or_boundary = 0
        status_value_mismatch = 0
        if status_column in labels:
            explicit_status_seen = True
            statuses = labels[status_column].fillna("status_missing").astype(str)
            reason_counts = {
                str(key): int(value)
                for key, value in statuses.value_counts(dropna=False).items()
            }
            late_or_boundary = int(
                statuses.str.contains("|".join(late_status_markers), regex=True).sum()
            )
            status_value_mismatch = int((statuses.eq("eligible") != finite).sum())
        elif len(labels):
            reason_counts = {
                "eligible": int(finite.sum()),
                "reason_unavailable_in_legacy_artifact": int((~finite).sum()),
            }
        predicted = 0
        if {"candidate_id", "horizon_minutes"}.issubset(predictions):
            horizon_predictions = predictions.loc[
                pd.to_numeric(predictions["horizon_minutes"], errors="coerce") == horizon,
                "candidate_id",
            ]
            predicted = int(horizon_predictions.dropna().astype(str).nunique())
        usable = int(finite.sum())
        finite_candidate_count = (
            int(
                labels.loc[finite, "candidate_id"]
                .dropna()
                .astype(str)
                .nunique()
            )
            if "candidate_id" in labels
            else 0
        )
        horizon_rows.append(
            {
                "horizon_minutes": int(horizon),
                "detected_candidate_count": int(len(detected_ids)),
                "label_row_count": int(len(labels)),
                "candidate_count_missing_entire_label_row": int(
                    len(detected_ids - present_label_ids)
                ),
                "finite_forward_label_count": usable,
                "distinct_candidates_with_finite_forward_label": finite_candidate_count,
                "nonfinite_forward_label_count": int(len(labels) - usable),
                "late_or_session_boundary_exclusion_count": late_or_boundary,
                "status_value_mismatch_count": status_value_mismatch,
                "distinct_candidates_with_oos_prediction": predicted,
                "finite_label_coverage_rate": (
                    float(finite_candidate_count / len(detected_ids))
                    if detected_ids
                    else None
                ),
                "status_counts": reason_counts,
            }
        )
    caveat = (
        "Per-horizon exclusion statuses are counted before model selection."
        if explicit_status_seen
        else (
            "Legacy label artifacts cannot distinguish late-session loss from a "
            "missing or non-contiguous forward window."
        )
    )
    return {
        "status": (
            "explicit_exclusion_reasons_reported"
            if explicit_status_seen
            else "legacy_artifact_missing_explicit_exclusion_reasons"
        ),
        "candidate_input_rows": int(len(candidates)),
        "detected_candidate_rows": int(len(candidate_ids)),
        "candidate_rows_missing_id": int(len(candidates) - len(candidate_ids)),
        "distinct_detected_candidates": int(len(detected_ids)),
        "duplicate_candidate_id_rows": int(len(candidate_ids) - candidate_ids.nunique()),
        "label_rows": int(len(labels)),
        "label_rows_missing_candidate_id": int(len(labels) - len(label_ids)),
        "distinct_labeled_candidates": int(len(present_label_ids)),
        "candidates_dropped_before_label_row": int(len(detected_ids - present_label_ids)),
        "entry_status_counts": entry_status_counts,
        "barrier_label_status_counts": barrier_status_counts,
        "all_forward_labels_eligible_count": (
            int(labels["all_forward_labels_eligible"].eq(True).sum())
            if "all_forward_labels_eligible" in labels
            else None
        ),
        "eligible_forward_horizon_count_total": (
            int(
                pd.to_numeric(
                    labels["eligible_forward_horizon_count"], errors="coerce"
                )
                .fillna(0)
                .sum()
            )
            if "eligible_forward_horizon_count" in labels
            else None
        ),
        "excluded_forward_horizon_count_total": (
            int(
                pd.to_numeric(
                    labels["excluded_forward_horizon_count"], errors="coerce"
                )
                .fillna(0)
                .sum()
            )
            if "excluded_forward_horizon_count" in labels
            else None
        ),
        "aggregate_exclusion_reason_counts": aggregate_exclusion_counts,
        "horizons": horizon_rows,
        "caveat": caveat,
    }


def _unconditional_baselines(
    labels: pd.DataFrame,
    forecast_horizons: Sequence[int],
    configured_round_trip_cost_bps: float,
) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    cost_return = configured_round_trip_cost_bps / 10_000
    for horizon in forecast_horizons:
        returns = _finite(labels, f"forward_return_{horizon}m")
        net = returns - cost_return
        rows.append(
            {
                "horizon_minutes": int(horizon),
                "observation_count": int(len(returns)),
                "mean_gross_return": float(returns.mean()) if len(returns) else None,
                "median_gross_return": float(returns.median()) if len(returns) else None,
                "gross_positive_rate": float((returns > 0).mean()) if len(returns) else None,
                "mean_net_return_at_configured_cost": (
                    float(net.mean()) if len(net) else None
                ),
                "net_positive_rate_at_configured_cost": (
                    float((net > 0).mean()) if len(net) else None
                ),
            }
        )
    return {
        "cash_zero_return": 0.0,
        "candidate_universe_no_model_selection": rows,
        "candidate_baseline_scope": (
            "all finite direction-signed candidate labels before score/model selection"
        ),
        "market_unconditional_baseline_status": (
            "not_available_from_candidate_only_label_artifact"
        ),
        "caveat": (
            "The candidate-universe baseline is model-free but still conditioned on the "
            "candidate generator; it is not an unconditional full-market benchmark."
        ),
    }


def _manifest_timestamp(value: object) -> pd.Timestamp | None:
    try:
        timestamp = pd.Timestamp(value)
    except (TypeError, ValueError):
        return None
    if pd.isna(timestamp):
        return None
    if timestamp.tzinfo is None:
        return None
    return timestamp.tz_convert("UTC")


def _untouched_holdout_report(
    primary_trades: pd.DataFrame,
    holdout_trades: pd.DataFrame | None,
    manifest: Mapping[str, object] | None,
) -> dict[str, object]:
    if holdout_trades is None or manifest is None:
        return {
            "status": "not_supplied",
            "manifest_schema_version": HOLDOUT_MANIFEST_SCHEMA_VERSION,
            "holdout_trade_count": 0,
        }
    if manifest.get("schema_version") != HOLDOUT_MANIFEST_SCHEMA_VERSION:
        return {
            "status": "manifest_schema_mismatch_fail_closed",
            "manifest_schema_version": HOLDOUT_MANIFEST_SCHEMA_VERSION,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    required_columns = {"date", "gross_return", "net_return"}
    missing_columns = sorted(required_columns - set(holdout_trades.columns))
    if holdout_trades.empty or missing_columns:
        return {
            "status": (
                "insufficient_data_empty_holdout"
                if holdout_trades.empty
                else "invalid_holdout_contract_fail_closed"
            ),
            "missing_columns": missing_columns,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    hash_verified, hash_status, bound_columns = _verified_manifest_hash(
        holdout_trades, manifest
    )
    if not hash_verified:
        return {
            "status": "holdout_dataset_receipt_invalid_fail_closed",
            "hash_status": hash_status,
            "bound_columns": bound_columns,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    influential_columns = set(required_columns)
    if "trade_id" in holdout_trades:
        influential_columns.add("trade_id")
    unbound_columns = sorted(influential_columns - set(bound_columns or []))
    if unbound_columns:
        return {
            "status": "holdout_dataset_receipt_invalid_fail_closed",
            "hash_status": "influential_columns_not_hash_bound",
            "unbound_columns": unbound_columns,
            "bound_columns": bound_columns,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    forbidden_uses = (
        "used_for_model_selection",
        "used_for_threshold_selection",
        "used_for_calibration",
    )
    invalid_usage_flags = [
        field for field in forbidden_uses if manifest.get(field) is not False
    ]
    if invalid_usage_flags:
        return {
            "status": "holdout_not_untouched_fail_closed",
            "invalid_or_missing_false_flags": invalid_usage_flags,
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    if not _is_sha256(manifest.get("artifact_sha256")):
        return {
            "status": "artifact_receipt_invalid_fail_closed",
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    training_end = _manifest_timestamp(manifest.get("training_end"))
    validation_end = _manifest_timestamp(manifest.get("validation_end"))
    holdout_start = _manifest_timestamp(manifest.get("holdout_start"))
    holdout_end = _manifest_timestamp(manifest.get("holdout_end"))
    selection_completed_at = _manifest_timestamp(
        manifest.get("selection_completed_at")
    )
    holdout_sealed_at = _manifest_timestamp(manifest.get("holdout_sealed_at"))
    evaluation_started_at = _manifest_timestamp(
        manifest.get("evaluation_started_at")
    )
    if (
        training_end is None
        or validation_end is None
        or holdout_start is None
        or holdout_end is None
        or selection_completed_at is None
        or holdout_sealed_at is None
        or evaluation_started_at is None
        or training_end > validation_end
        or training_end >= holdout_start
        or validation_end >= holdout_start
        or holdout_start > holdout_end
        or selection_completed_at > holdout_sealed_at
        or holdout_sealed_at > evaluation_started_at
    ):
        return {
            "status": "invalid_or_overlapping_manifest_boundaries_fail_closed",
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    holdout_dates = pd.to_datetime(
        holdout_trades["date"], errors="coerce", utc=True
    ).dt.normalize()
    if holdout_dates.isna().any():
        return {
            "status": "invalid_holdout_dates_fail_closed",
            "invalid_holdout_date_rows": int(holdout_dates.isna().sum()),
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    outside_bounds = (holdout_dates < holdout_start.normalize()) | (
        holdout_dates > holdout_end.normalize()
    )
    if outside_bounds.any():
        return {
            "status": "holdout_rows_outside_manifest_window_fail_closed",
            "outside_manifest_window_rows": int(outside_bounds.sum()),
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    if "trade_id" in holdout_trades and holdout_trades["trade_id"].duplicated().any():
        return {
            "status": "duplicate_holdout_trade_ids_fail_closed",
            "duplicate_trade_id_rows": int(
                holdout_trades["trade_id"].duplicated(keep=False).sum()
            ),
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    if not primary_trades.empty:
        if "date" not in primary_trades:
            return {
                "status": "primary_holdout_separation_not_verifiable_fail_closed",
                "reason": "primary_trades_missing_date",
                "hash_status": hash_status,
                "holdout_trade_count": int(len(holdout_trades)),
            }
        primary_dates = pd.to_datetime(
            primary_trades["date"], errors="coerce", utc=True
        ).dt.normalize()
        if primary_dates.isna().any():
            return {
                "status": "primary_holdout_separation_not_verifiable_fail_closed",
                "reason": "invalid_primary_trade_dates",
                "hash_status": hash_status,
                "holdout_trade_count": int(len(holdout_trades)),
            }
        if (primary_dates >= holdout_start.normalize()).any():
            return {
                "status": "primary_holdout_date_overlap_fail_closed",
                "overlapping_primary_rows": int(
                    (primary_dates >= holdout_start.normalize()).sum()
                ),
                "hash_status": hash_status,
                "holdout_trade_count": int(len(holdout_trades)),
            }
        if {"trade_id"}.issubset(primary_trades) and "trade_id" in holdout_trades:
            overlapping_ids = set(
                primary_trades["trade_id"].dropna().astype(str)
            ) & set(holdout_trades["trade_id"].dropna().astype(str))
            if overlapping_ids:
                return {
                    "status": "primary_holdout_trade_id_overlap_fail_closed",
                    "overlapping_trade_id_count": int(len(overlapping_ids)),
                    "hash_status": hash_status,
                    "holdout_trade_count": int(len(holdout_trades)),
                }
    gross = pd.to_numeric(holdout_trades["gross_return"], errors="coerce")
    net = pd.to_numeric(holdout_trades["net_return"], errors="coerce")
    finite = np.isfinite(pd.DataFrame({"gross": gross, "net": net})).all(axis=1)
    if not finite.all():
        return {
            "status": "nonfinite_holdout_returns_fail_closed",
            "invalid_return_rows": int((~finite).sum()),
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    inferred_cost_bps = (gross - net) * 10_000
    if (inferred_cost_bps < -1e-8).any():
        return {
            "status": "holdout_gross_net_cost_inconsistency_fail_closed",
            "negative_inferred_cost_rows": int((inferred_cost_bps < -1e-8).sum()),
            "hash_status": hash_status,
            "holdout_trade_count": int(len(holdout_trades)),
        }
    holdout = holdout_trades.copy()
    holdout["date"] = holdout_dates.dt.date
    holdout["gross_return"] = gross
    holdout["net_return"] = net
    gross_daily = _daily_returns(holdout, "gross_return")
    net_daily = _daily_returns(holdout, "net_return")
    return {
        "status": "reported_separate_holdout_descriptive_not_promotion_evidence",
        "manifest_schema_version": HOLDOUT_MANIFEST_SCHEMA_VERSION,
        "hash_status": hash_status,
        "dataset_sha256": str(manifest["dataset_sha256"]).lower(),
        "artifact_sha256": str(manifest["artifact_sha256"]).lower(),
        "bound_columns": bound_columns,
        "training_end": training_end.isoformat(),
        "validation_end": validation_end.isoformat(),
        "holdout_start": holdout_start.isoformat(),
        "holdout_end": holdout_end.isoformat(),
        "selection_completed_at": selection_completed_at.isoformat(),
        "holdout_sealed_at": holdout_sealed_at.isoformat(),
        "evaluation_started_at": evaluation_started_at.isoformat(),
        "holdout_trade_count": int(len(holdout)),
        "holdout_session_count": int(len(net_daily)),
        "mean_gross_return_per_trade": float(gross.mean()),
        "mean_net_return_per_trade": float(net.mean()),
        "median_net_return_per_trade": float(net.median()),
        "net_positive_trade_rate": float((net > 0).mean()),
        "mean_inferred_round_trip_cost_bps": float(inferred_cost_bps.mean()),
        "breakeven_round_trip_cost_bps": float(gross.mean() * 10_000),
        "gross_compounded_total_return": _compound(gross_daily),
        "net_compounded_total_return": _compound(net_daily),
        "selection_use_flags": {
            field: bool(manifest[field]) for field in forbidden_uses
        },
        "caveat": (
            "The checksum and temporal boundaries verify separation from the supplied "
            "primary trades. Operational proof that nobody inspected the holdout before "
            "sealing remains an external governance requirement."
        ),
    }


def _direction_shift_placebo(
    matched: pd.DataFrame,
    *,
    minimum_observations: int,
) -> list[dict[str, object]]:
    results: list[dict[str, object]] = []
    if matched.empty:
        return results
    for horizon, group in matched.groupby("horizon_minutes", sort=True):
        ordered = group.sort_values(
            ["timestamp", "_match_order"], kind="mergesort"
        )
        returns = ordered["forward_return"].to_numpy(dtype=float)
        directions = ordered["direction"].to_numpy(dtype=float)
        if len(ordered) < minimum_observations or len(np.unique(directions)) < 2:
            results.append(
                {
                    "horizon_minutes": int(horizon),
                    "status": "insufficient_observations_or_direction_variation",
                    "observation_count": int(len(ordered)),
                }
            )
            continue
        observed = float(np.mean(directions * returns))
        shifted = np.asarray(
            [
                float(np.mean(np.roll(directions, offset) * returns))
                for offset in range(1, len(directions))
            ],
            dtype=float,
        )
        p_value = float(
            (1 + int((np.abs(shifted) >= abs(observed)).sum()))
            / (len(shifted) + 1)
        )
        results.append(
            {
                "horizon_minutes": int(horizon),
                "status": "reported_diagnostic_not_promotion_evidence",
                "control_id": "cyclic_direction_label_shift",
                "observation_count": int(len(ordered)),
                "observed_mean_direction_signed_return": observed,
                "placebo_shift_count": int(len(shifted)),
                "placebo_mean": float(shifted.mean()),
                "placebo_q025": float(np.quantile(shifted, 0.025)),
                "placebo_q975": float(np.quantile(shifted, 0.975)),
                "two_sided_plus_one_p_value": p_value,
                "construction": (
                    "cyclically shift candidate directions across ordered point-in-time "
                    "market outcomes within the same horizon"
                ),
                "caveat": (
                    "A cyclic label-shift is a negative-control diagnostic and depends "
                    "on the ordering/exchangeability assumption."
                ),
            }
        )
    return results


def _time_matched_market_rows(
    events: pd.DataFrame,
    grid: pd.DataFrame,
    *,
    event_timestamp_column: str,
    forecast_horizons: Sequence[int],
    configured_round_trip_cost_bps: float,
    minimum_match_rate: float,
    placebo_minimum_observations: int,
    scope: str,
) -> dict[str, object]:
    if events.empty:
        return {
            "status": "not_available_no_events",
            "scope": scope,
            "requested_event_horizon_rows": 0,
            "matched_event_horizon_rows": 0,
            "direction_shift_placebos": [],
        }
    required = {event_timestamp_column, "direction"}
    missing = sorted(required - set(events.columns))
    if missing:
        return {
            "status": "unavailable_missing_event_contract",
            "scope": scope,
            "missing_columns": missing,
            "requested_event_horizon_rows": 0,
            "matched_event_horizon_rows": 0,
            "direction_shift_placebos": [],
        }
    timestamps, invalid_timestamps = _strict_utc(events[event_timestamp_column])
    directions = pd.to_numeric(events["direction"], errors="coerce")
    invalid_directions = ~directions.isin([-1, 1])
    if invalid_timestamps or invalid_directions.any():
        return {
            "status": "invalid_event_times_or_directions_fail_closed",
            "scope": scope,
            "invalid_timestamp_rows": int(invalid_timestamps),
            "invalid_direction_rows": int(invalid_directions.sum()),
            "requested_event_horizon_rows": 0,
            "matched_event_horizon_rows": 0,
            "direction_shift_placebos": [],
        }
    event_frame = pd.DataFrame(
        {
            "timestamp": timestamps,
            "direction": directions.astype(int),
            "_match_order": np.arange(len(events), dtype=int),
        }
    )
    if "horizon_minutes" in events:
        horizons = pd.to_numeric(events["horizon_minutes"], errors="coerce")
        invalid_horizons = ~horizons.isin([int(value) for value in forecast_horizons])
        if invalid_horizons.any():
            return {
                "status": "invalid_event_horizons_fail_closed",
                "scope": scope,
                "invalid_horizon_rows": int(invalid_horizons.sum()),
                "requested_event_horizon_rows": 0,
                "matched_event_horizon_rows": 0,
                "direction_shift_placebos": [],
            }
        event_frame["horizon_minutes"] = horizons.astype(int)
    else:
        event_frame = event_frame.merge(
            pd.DataFrame(
                {"horizon_minutes": [int(value) for value in forecast_horizons]}
            ),
            how="cross",
        )
    grid_symbols = sorted(grid["symbol"].unique())
    if len(grid_symbols) != 1:
        return {
            "status": "ambiguous_multi_symbol_baseline_fail_closed",
            "scope": scope,
            "grid_symbols": grid_symbols,
            "requested_event_horizon_rows": int(len(event_frame)),
            "matched_event_horizon_rows": 0,
            "direction_shift_placebos": [],
        }
    eligible_grid = grid.loc[
        grid["label_status"].eq("eligible"),
        ["timestamp", "horizon_minutes", "forward_return"],
    ]
    matched = event_frame.merge(
        eligible_grid,
        on=["timestamp", "horizon_minutes"],
        how="left",
        validate="many_to_one",
    )
    matched_rows = matched["forward_return"].notna()
    match_rate = float(matched_rows.mean()) if len(matched) else 0.0
    observed = matched.loc[matched_rows].copy()
    signed = observed["direction"] * observed["forward_return"]
    status = (
        "reported_descriptive"
        if len(observed) and match_rate >= minimum_match_rate
        else "insufficient_exact_time_match_coverage"
    )
    return {
        "status": status,
        "scope": scope,
        "baseline_symbol": grid_symbols[0],
        "requested_event_horizon_rows": int(len(matched)),
        "matched_event_horizon_rows": int(matched_rows.sum()),
        "unmatched_event_horizon_rows": int((~matched_rows).sum()),
        "exact_match_rate": match_rate,
        "minimum_match_rate": float(minimum_match_rate),
        "mean_raw_market_return": (
            float(observed["forward_return"].mean()) if len(observed) else None
        ),
        "mean_event_direction_signed_market_return": (
            float(signed.mean()) if len(signed) else None
        ),
        "mean_event_direction_signed_net_return_at_configured_cost": (
            float((signed - configured_round_trip_cost_bps / 10_000).mean())
            if len(signed)
            else None
        ),
        "direction_shift_placebos": _direction_shift_placebo(
            observed,
            minimum_observations=placebo_minimum_observations,
        ),
        "caveat": (
            "Exact time matching controls for the sampled timestamps but remains "
            "conditioned on the supplied event set."
        ),
    }


def _point_in_time_market_baseline(
    grid: pd.DataFrame | None,
    manifest: Mapping[str, object] | None,
    *,
    candidates: pd.DataFrame,
    trades: pd.DataFrame,
    forecast_horizons: Sequence[int],
    configured_round_trip_cost_bps: float,
    minimum_observations: int,
    minimum_sessions: int,
    minimum_match_rate: float,
    placebo_minimum_observations: int,
) -> dict[str, object]:
    if minimum_observations < 1 or minimum_sessions < 1:
        raise ValueError("market baseline minimum counts must be positive")
    if not 0 <= minimum_match_rate <= 1:
        raise ValueError("market_baseline_minimum_match_rate must be in [0, 1]")
    if grid is None or manifest is None:
        return {
            "status": "not_available_without_verified_point_in_time_grid",
            "manifest_schema_version": MARKET_BASELINE_MANIFEST_SCHEMA_VERSION,
            "full_market_by_horizon": [],
            "candidate_time_matched": {
                "status": "not_available_without_verified_point_in_time_grid"
            },
            "selected_trade_time_matched": {
                "status": "not_available_without_verified_point_in_time_grid"
            },
        }
    if manifest.get("schema_version") != MARKET_BASELINE_MANIFEST_SCHEMA_VERSION:
        return {
            "status": "manifest_schema_mismatch_fail_closed",
            "manifest_schema_version": MARKET_BASELINE_MANIFEST_SCHEMA_VERSION,
            "full_market_by_horizon": [],
        }
    required_manifest = {
        "point_in_time_data": True,
        "regular_grid": True,
        "synthetic": False,
        "bar_interval_minutes": 1,
        "entry_lag_minutes": 1,
        "return_convention": "entry_open_t_plus_1_to_close_t_plus_h",
    }
    invalid_manifest_fields = [
        field
        for field, expected in required_manifest.items()
        if manifest.get(field) != expected
    ]
    integrity_receipt = manifest.get("integrity_receipt")
    receipt_hash = manifest.get("integrity_receipt_sha256")
    receipt_hash_valid = (
        isinstance(integrity_receipt, Mapping)
        and _is_sha256(receipt_hash)
        and canonical_evidence_sha256(integrity_receipt)
        == str(receipt_hash).lower()
    )
    required_receipt = {
        "status": "complete_point_in_time_grid",
        "synthetic": False,
        "duplicate_rows": 0,
        "conflicting_rows": 0,
        "incomplete_sessions": 0,
        "causality_violations": 0,
    }
    invalid_receipt_fields = (
        [
            field
            for field, expected in required_receipt.items()
            if integrity_receipt.get(field) != expected
        ]
        if isinstance(integrity_receipt, Mapping)
        else sorted(required_receipt)
    )
    if invalid_manifest_fields or invalid_receipt_fields or not receipt_hash_valid:
        return {
            "status": "point_in_time_grid_manifest_invalid_fail_closed",
            "invalid_or_missing_manifest_fields": invalid_manifest_fields,
            "invalid_or_missing_integrity_receipt_fields": invalid_receipt_fields,
            "integrity_receipt_sha256_valid": bool(receipt_hash_valid),
            "full_market_by_horizon": [],
        }
    required_columns = {
        "timestamp",
        "symbol",
        "horizon_minutes",
        "forward_return",
        "label_status",
        "source",
    }
    missing_columns = sorted(required_columns - set(grid.columns))
    if grid.empty or missing_columns:
        return {
            "status": (
                "insufficient_data_empty_grid"
                if grid.empty
                else "point_in_time_grid_contract_invalid_fail_closed"
            ),
            "missing_columns": missing_columns,
            "full_market_by_horizon": [],
        }
    hash_verified, hash_status, bound_columns = _verified_manifest_hash(
        grid, manifest
    )
    if not hash_verified:
        return {
            "status": "point_in_time_grid_receipt_invalid_fail_closed",
            "hash_status": hash_status,
            "bound_columns": bound_columns,
            "full_market_by_horizon": [],
        }
    unbound_columns = sorted(required_columns - set(bound_columns or []))
    if unbound_columns:
        return {
            "status": "point_in_time_grid_receipt_invalid_fail_closed",
            "hash_status": "influential_columns_not_hash_bound",
            "unbound_columns": unbound_columns,
            "bound_columns": bound_columns,
            "full_market_by_horizon": [],
        }
    working = grid.copy()
    timestamps, invalid_timestamps = _strict_utc(working["timestamp"])
    working["timestamp"] = timestamps
    minute_aligned = (
        working["timestamp"].dt.second.eq(0)
        & working["timestamp"].dt.microsecond.eq(0)
        & working["timestamp"].dt.nanosecond.eq(0)
    )
    working["symbol"] = working["symbol"].fillna("").astype(str).str.strip()
    working["source"] = working["source"].fillna("").astype(str).str.strip()
    working["label_status"] = (
        working["label_status"].fillna("").astype(str).str.strip()
    )
    working["horizon_minutes"] = pd.to_numeric(
        working["horizon_minutes"], errors="coerce"
    )
    working["forward_return"] = pd.to_numeric(
        working["forward_return"], errors="coerce"
    )
    eligible = working["label_status"].eq("eligible")
    finite_returns = np.isfinite(working["forward_return"])
    infinite_returns = np.isinf(working["forward_return"])
    valid_label_status = eligible | working["label_status"].str.startswith(
        "excluded_"
    )
    requested_horizons = {int(value) for value in forecast_horizons}
    invalid_horizons = (
        working["horizon_minutes"].isna()
        | (working["horizon_minutes"] <= 0)
        | (working["horizon_minutes"] % 1 != 0)
        | (~working["horizon_minutes"].isin(requested_horizons))
    )
    duplicate_keys = working.duplicated(
        ["symbol", "timestamp", "horizon_minutes"], keep=False
    )
    manifest_source = manifest.get("source")
    source_mismatch = (
        not isinstance(manifest_source, str)
        or not manifest_source
        or set(working["source"]) != {manifest_source}
    )
    receipt_count_mismatch = (
        integrity_receipt.get("source") != manifest_source
        or integrity_receipt.get("observed_rows") != len(working)
        or integrity_receipt.get("expected_rows") != len(working)
        or integrity_receipt.get("session_count")
        != int(working["timestamp"].dt.date.nunique())
    )
    invalid_rows = (
        invalid_timestamps
        or not minute_aligned.all()
        or working["symbol"].eq("").any()
        or working["source"].eq("").any()
        or not valid_label_status.all()
        or invalid_horizons.any()
        or duplicate_keys.any()
        or infinite_returns.any()
        or (eligible != finite_returns).any()
        or source_mismatch
        or receipt_count_mismatch
    )
    if invalid_rows:
        return {
            "status": "point_in_time_grid_rows_invalid_fail_closed",
            "invalid_timestamp_rows": int(invalid_timestamps),
            "non_minute_aligned_rows": int((~minute_aligned.fillna(False)).sum()),
            "blank_symbol_rows": int(working["symbol"].eq("").sum()),
            "invalid_label_status_rows": int((~valid_label_status).sum()),
            "invalid_horizon_rows": int(invalid_horizons.sum()),
            "duplicate_key_rows": int(duplicate_keys.sum()),
            "infinite_return_rows": int(infinite_returns.sum()),
            "label_status_return_mismatch_rows": int(
                (eligible != finite_returns).sum()
            ),
            "source_mismatch": bool(source_mismatch),
            "integrity_receipt_count_mismatch": bool(receipt_count_mismatch),
            "hash_status": hash_status,
            "full_market_by_horizon": [],
        }
    working["horizon_minutes"] = working["horizon_minutes"].astype(int)
    full_market: list[dict[str, object]] = []
    all_horizons_sufficient = True
    for horizon in sorted(requested_horizons):
        horizon_rows = working.loc[working["horizon_minutes"].eq(horizon)]
        horizon_eligible = horizon_rows.loc[
            horizon_rows["label_status"].eq("eligible")
        ]
        session_count = int(horizon_eligible["timestamp"].dt.date.nunique())
        sufficient = (
            len(horizon_eligible) >= minimum_observations
            and session_count >= minimum_sessions
        )
        all_horizons_sufficient = all_horizons_sufficient and sufficient
        returns = horizon_eligible["forward_return"]
        full_market.append(
            {
                "horizon_minutes": int(horizon),
                "status": (
                    "reported_descriptive"
                    if sufficient
                    else "insufficient_point_in_time_observations"
                ),
                "grid_row_count": int(len(horizon_rows)),
                "eligible_observation_count": int(len(horizon_eligible)),
                "excluded_observation_count": int(
                    len(horizon_rows) - len(horizon_eligible)
                ),
                "eligible_coverage_rate": (
                    float(len(horizon_eligible) / len(horizon_rows))
                    if len(horizon_rows)
                    else 0.0
                ),
                "session_count": session_count,
                "mean_gross_return": (
                    float(returns.mean()) if len(returns) else None
                ),
                "median_gross_return": (
                    float(returns.median()) if len(returns) else None
                ),
                "gross_positive_rate": (
                    float((returns > 0).mean()) if len(returns) else None
                ),
                "mean_long_only_net_return_at_configured_cost": (
                    float(
                        (
                            returns
                            - configured_round_trip_cost_bps / 10_000
                        ).mean()
                    )
                    if len(returns)
                    else None
                ),
            }
        )
    selected_timestamp_column = (
        "signal_time"
        if "signal_time" in trades
        else "entry_time"
        if "entry_time" in trades
        else "signal_time"
    )
    return {
        "status": (
            "reported_descriptive"
            if all_horizons_sufficient
            else "insufficient_point_in_time_coverage"
        ),
        "manifest_schema_version": MARKET_BASELINE_MANIFEST_SCHEMA_VERSION,
        "hash_status": hash_status,
        "dataset_sha256": str(manifest["dataset_sha256"]).lower(),
        "integrity_receipt_sha256": str(
            manifest["integrity_receipt_sha256"]
        ).lower(),
        "integrity_receipt_status": str(integrity_receipt["status"]),
        "bound_columns": bound_columns,
        "source": manifest_source,
        "symbols": sorted(working["symbol"].unique()),
        "return_convention": str(manifest["return_convention"]),
        "minimum_observations_per_horizon": int(minimum_observations),
        "minimum_sessions_per_horizon": int(minimum_sessions),
        "full_market_by_horizon": full_market,
        "candidate_time_matched": _time_matched_market_rows(
            candidates,
            working,
            event_timestamp_column="timestamp",
            forecast_horizons=forecast_horizons,
            configured_round_trip_cost_bps=configured_round_trip_cost_bps,
            minimum_match_rate=minimum_match_rate,
            placebo_minimum_observations=placebo_minimum_observations,
            scope="all_candidates_before_model_selection",
        ),
        "selected_trade_time_matched": _time_matched_market_rows(
            trades,
            working,
            event_timestamp_column=selected_timestamp_column,
            forecast_horizons=forecast_horizons,
            configured_round_trip_cost_bps=configured_round_trip_cost_bps,
            minimum_match_rate=minimum_match_rate,
            placebo_minimum_observations=placebo_minimum_observations,
            scope="selected_out_of_sample_trades",
        ),
        "caveat": (
            "The full-market benchmark is available only because the supplied regular "
            "point-in-time grid and integrity receipt passed exact contract checks. "
            "It remains descriptive and cannot promote a model."
        ),
    }


def _cost_analysis(
    trades: pd.DataFrame,
    *,
    candidate_dates: Sequence[object] | None,
    configured_round_trip_cost_bps: float,
    cost_grid_bps: Sequence[float] | None,
    commission_per_round_trip_currency: float | None,
) -> dict[str, object]:
    valid = trades.copy()
    if {"gross_return", "net_return"}.issubset(valid):
        valid["gross_return"] = pd.to_numeric(valid["gross_return"], errors="coerce")
        valid["net_return"] = pd.to_numeric(valid["net_return"], errors="coerce")
        valid = valid.replace([np.inf, -np.inf], np.nan).dropna(
            subset=["gross_return", "net_return"]
        )
    else:
        valid = pd.DataFrame(columns=["date", "gross_return", "net_return"])
    inferred_cost_bps = (
        (valid["gross_return"] - valid["net_return"]) * 10_000
        if not valid.empty
        else pd.Series(dtype=float)
    )
    mean_gross = float(valid["gross_return"].mean()) if not valid.empty else None
    breakeven = mean_gross * 10_000 if mean_gross is not None else None
    mean_inferred_cost = (
        float(inferred_cost_bps.mean()) if len(inferred_cost_bps) else None
    )
    grid_values = set(DEFAULT_COST_GRID_BPS)
    grid_values.add(float(configured_round_trip_cost_bps))
    if cost_grid_bps is not None:
        grid_values.update(float(value) for value in cost_grid_bps)
    if len(inferred_cost_bps):
        grid_values.add(float(max(0.0, inferred_cost_bps.mean())))
    scenarios: list[dict[str, object]] = []
    for cost_bps in sorted(value for value in grid_values if np.isfinite(value) and value >= 0):
        scenario = valid.copy()
        scenario["scenario_net_return"] = scenario["gross_return"] - cost_bps / 10_000
        daily = _daily_returns(
            scenario.rename(columns={"scenario_net_return": "return"}),
            "return",
            candidate_dates,
        )
        scenario_returns = scenario["scenario_net_return"]
        scenarios.append(
            {
                "round_trip_cost_bps": float(cost_bps),
                "mean_net_return_per_trade": (
                    float(scenario_returns.mean()) if len(scenario_returns) else None
                ),
                "median_net_return_per_trade": (
                    float(scenario_returns.median()) if len(scenario_returns) else None
                ),
                "positive_trade_rate": (
                    float((scenario_returns > 0).mean()) if len(scenario_returns) else None
                ),
                "compounded_total_return": _compound(daily),
            }
        )
    return {
        "configured_round_trip_market_cost_bps": float(
            configured_round_trip_cost_bps
        ),
        "commission_per_round_trip_currency": commission_per_round_trip_currency,
        "mean_inferred_realized_round_trip_cost_bps": mean_inferred_cost,
        "median_inferred_realized_round_trip_cost_bps": (
            float(inferred_cost_bps.median()) if len(inferred_cost_bps) else None
        ),
        "breakeven_round_trip_cost_bps": breakeven,
        "breakeven_status": (
            "positive_gross_cost_budget"
            if breakeven is not None and breakeven > 0
            else "no_nonnegative_cost_budget"
            if breakeven is not None
            else "unavailable_no_trades"
        ),
        "remaining_cost_headroom_bps_at_realized_cost": (
            float(valid["net_return"].mean() * 10_000) if not valid.empty else None
        ),
        "observed_net_edge_status": (
            "positive_mean_net_return"
            if not valid.empty and float(valid["net_return"].mean()) > 0
            else "no_positive_mean_net_edge_observed"
            if not valid.empty
            else "unavailable_no_trades"
        ),
        "configured_minus_inferred_cost_bps": (
            float(configured_round_trip_cost_bps - mean_inferred_cost)
            if mean_inferred_cost is not None
            else None
        ),
        "cost_contract_status": (
            "configured_and_inferred_costs_match_within_0_1_bps"
            if mean_inferred_cost is not None
            and abs(configured_round_trip_cost_bps - mean_inferred_cost) <= 0.1
            else "configured_and_inferred_costs_differ"
            if mean_inferred_cost is not None
            else "unavailable_no_trades"
        ),
        "sensitivity": scenarios,
        "unmodeled_or_unmeasured_costs": [
            "latency",
            "market_impact",
            "capacity",
            "size_dependent_fills",
            "borrow_or_financing_where_applicable",
        ],
        "status": "incomplete_without_historical_executable_quotes_and_order_size",
    }


def build_validation_metrics(
    trades: pd.DataFrame,
    *,
    candidates: pd.DataFrame | None = None,
    labels: pd.DataFrame | None = None,
    predictions: pd.DataFrame | None = None,
    hypothesis_tests: pd.DataFrame | None = None,
    untouched_holdout_trades: pd.DataFrame | None = None,
    untouched_holdout_manifest: Mapping[str, object] | None = None,
    point_in_time_market_grid: pd.DataFrame | None = None,
    point_in_time_market_manifest: Mapping[str, object] | None = None,
    forecast_horizons: Sequence[int] = (5, 15, 30, 60),
    candidate_dates: Sequence[object] | None = None,
    configured_round_trip_cost_bps: float = 0.0,
    commission_per_round_trip_currency: float | None = None,
    cost_grid_bps: Sequence[float] | None = None,
    bootstrap_resamples: int = 2_000,
    bootstrap_confidence_level: float = 0.95,
    bootstrap_block_length: int | None = None,
    random_seed: int = 7,
    monthly_stability_minimum_months: int = 6,
    regime_column: str = "regime",
    regime_observed_at_column: str = "regime_observed_at",
    regime_model_version_column: str = "regime_model_version",
    regime_feature_version_column: str = "regime_feature_version",
    regime_stability_minimum_trades: int = 20,
    placebo_resamples: int = 2_000,
    placebo_minimum_sessions: int = 20,
    fdr_alpha: float = 0.05,
    market_baseline_minimum_observations: int = 30,
    market_baseline_minimum_sessions: int = 20,
    market_baseline_minimum_match_rate: float = 0.9,
    direction_placebo_minimum_observations: int = 20,
) -> dict[str, Any]:
    """Build a descriptive validation envelope without making promotion claims."""

    normalized_horizons = tuple(int(value) for value in forecast_horizons)
    if (
        not normalized_horizons
        or len(normalized_horizons) != len(set(normalized_horizons))
        or any(value <= 0 for value in normalized_horizons)
    ):
        raise ValueError("forecast_horizons must be unique positive integers")
    candidates = candidates if candidates is not None else pd.DataFrame()
    labels = labels if labels is not None else pd.DataFrame()
    predictions = predictions if predictions is not None else pd.DataFrame()
    paired_trades = pd.DataFrame(columns=trades.columns)
    excluded_nonfinite_return_rows = int(len(trades))
    if {"gross_return", "net_return"}.issubset(trades):
        paired = trades[["gross_return", "net_return"]].apply(
            pd.to_numeric, errors="coerce"
        )
        paired_mask = np.isfinite(paired).all(axis=1)
        paired_trades = trades.loc[paired_mask].copy()
        paired_trades[["gross_return", "net_return"]] = paired.loc[paired_mask]
        excluded_nonfinite_return_rows = int((~paired_mask).sum())
    gross_daily = _daily_returns(paired_trades, "gross_return", candidate_dates)
    net_daily = _daily_returns(paired_trades, "net_return", candidate_dates)
    gross = _finite(paired_trades, "gross_return")
    net = _finite(paired_trades, "net_return")
    point_in_time_baseline = _point_in_time_market_baseline(
        point_in_time_market_grid,
        point_in_time_market_manifest,
        candidates=candidates,
        trades=paired_trades,
        forecast_horizons=normalized_horizons,
        configured_round_trip_cost_bps=configured_round_trip_cost_bps,
        minimum_observations=market_baseline_minimum_observations,
        minimum_sessions=market_baseline_minimum_sessions,
        minimum_match_rate=market_baseline_minimum_match_rate,
        placebo_minimum_observations=direction_placebo_minimum_observations,
    )
    baselines = _unconditional_baselines(
        labels, normalized_horizons, configured_round_trip_cost_bps
    )
    baselines["point_in_time_market"] = point_in_time_baseline
    if point_in_time_baseline.get("status") == "reported_descriptive":
        baselines["market_unconditional_baseline_status"] = (
            "available_from_verified_point_in_time_grid"
        )
    elif point_in_time_market_grid is not None:
        baselines["market_unconditional_baseline_status"] = (
            "point_in_time_grid_supplied_but_failed_or_insufficient"
        )
    sign_flip_placebo = _session_sign_flip_placebo(
        paired_trades,
        resamples=placebo_resamples,
        random_seed=random_seed,
        minimum_sessions=placebo_minimum_sessions,
    )
    candidate_direction_placebos = point_in_time_baseline.get(
        "candidate_time_matched", {}
    ).get("direction_shift_placebos", [])
    selected_direction_placebos = point_in_time_baseline.get(
        "selected_trade_time_matched", {}
    ).get("direction_shift_placebos", [])
    generated_hypotheses: list[dict[str, object]] = []
    if sign_flip_placebo.get("status") == (
        "reported_diagnostic_not_promotion_evidence"
    ):
        generated_hypotheses.append(
            {
                "hypothesis_id": "auto:session_clustered_gross_return_sign_flip",
                "family": "auto:gross_return_placebo",
                "p_value": sign_flip_placebo["two_sided_plus_one_p_value"],
                "test_kind": "placebo",
                "pre_registered": False,
            }
        )
    for scope, rows in (
        ("candidate", candidate_direction_placebos),
        ("selected_trade", selected_direction_placebos),
    ):
        for row in rows:
            if row.get("status") != "reported_diagnostic_not_promotion_evidence":
                continue
            horizon = int(row["horizon_minutes"])
            generated_hypotheses.append(
                {
                    "hypothesis_id": (
                        f"auto:{scope}:cyclic_direction_label_shift:{horizon}m"
                    ),
                    "family": f"auto:{scope}:direction_shift_placebos",
                    "p_value": row["two_sided_plus_one_p_value"],
                    "test_kind": "placebo",
                    "pre_registered": False,
                }
            )
    correction_input_frames: list[pd.DataFrame] = []
    if hypothesis_tests is not None:
        correction_input_frames.append(hypothesis_tests.copy())
    if generated_hypotheses:
        correction_input_frames.append(pd.DataFrame(generated_hypotheses))
    correction_input = (
        pd.concat(correction_input_frames, ignore_index=True, sort=False)
        if correction_input_frames
        else None
    )
    multiple_testing = benjamini_hochberg(
        correction_input,
        alpha=fdr_alpha,
    )
    multiple_testing["user_supplied_hypothesis_count"] = int(
        len(hypothesis_tests) if hypothesis_tests is not None else 0
    )
    multiple_testing["generated_placebo_hypothesis_count"] = int(
        len(generated_hypotheses)
    )
    return {
        "schema_version": VALIDATION_SCHEMA_VERSION,
        "evidence_status": "descriptive_not_promotion_evidence",
        "return_metrics": {
            "gross_compounded_total_return": _compound(gross_daily),
            "net_compounded_total_return": _compound(net_daily),
            "gross_arithmetic_return_sum": float(gross.sum()) if len(gross) else 0.0,
            "net_arithmetic_return_sum": float(net.sum()) if len(net) else 0.0,
            "mean_gross_return_per_trade": float(gross.mean()) if len(gross) else None,
            "mean_net_return_per_trade": float(net.mean()) if len(net) else None,
            "median_gross_return_per_trade": (
                float(gross.median()) if len(gross) else None
            ),
            "median_net_return_per_trade": float(net.median()) if len(net) else None,
            "gross_positive_trade_rate": float((gross > 0).mean()) if len(gross) else None,
            "net_positive_trade_rate": float((net > 0).mean()) if len(net) else None,
            "input_trade_row_count": int(len(trades)),
            "paired_finite_trade_count": int(len(paired_trades)),
            "excluded_nonfinite_return_rows": excluded_nonfinite_return_rows,
            "observed_session_count": int(len(net_daily)),
        },
        "cost_analysis": _cost_analysis(
            paired_trades,
            candidate_dates=candidate_dates,
            configured_round_trip_cost_bps=configured_round_trip_cost_bps,
            cost_grid_bps=cost_grid_bps,
            commission_per_round_trip_currency=commission_per_round_trip_currency,
        ),
        "confidence_intervals": _session_bootstrap(
            paired_trades,
            candidate_dates=candidate_dates,
            confidence_level=bootstrap_confidence_level,
            resamples=bootstrap_resamples,
            random_seed=random_seed,
            block_length=bootstrap_block_length,
        ),
        "effective_sample_size": _effective_session_sample_size(net_daily),
        "stability": {
            "monthly": _monthly_stability(
                paired_trades,
                candidate_dates=candidate_dates,
                minimum_months=monthly_stability_minimum_months,
            ),
            "regime": _regime_stability(
                paired_trades,
                regime_column=regime_column,
                regime_observed_at_column=regime_observed_at_column,
                regime_model_version_column=regime_model_version_column,
                regime_feature_version_column=regime_feature_version_column,
                minimum_trades_per_regime=regime_stability_minimum_trades,
            ),
        },
        "negative_controls": {
            "session_clustered_sign_flip": sign_flip_placebo,
            "candidate_direction_label_shift": candidate_direction_placebos,
            "selected_trade_direction_label_shift": selected_direction_placebos,
        },
        "multiple_testing": multiple_testing,
        "untouched_holdout": _untouched_holdout_report(
            trades,
            untouched_holdout_trades,
            untouched_holdout_manifest,
        ),
        "baselines": baselines,
        "overlap_accounting": {
            "executed_trade_intervals": _trade_interval_overlap(trades),
            "oos_prediction_fold_assignments": _prediction_fold_overlap(predictions),
        },
        "label_exclusion_accounting": _label_accounting(
            candidates, labels, predictions, normalized_horizons
        ),
        "limitations": [
            "No metric in this envelope promotes or calibrates a model.",
            "Bootstrap intervals remain exploratory and are never substituted for the separately sealed holdout.",
            "A full-market baseline is reported only after a hash-bound regular point-in-time grid passes its contract.",
            "Training versus displayed-replay overlap requires immutable artifact window metadata.",
            "Regime subgroup results require causal per-trade regime lineage and remain descriptive.",
            "Negative controls and FDR correction do not repair leakage, non-causal inputs, or data-snooping.",
        ],
    }
