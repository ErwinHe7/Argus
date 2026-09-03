from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.calendar import market_schedule
from intraday_quant.config import AppConfig
from intraday_quant.data.integrity import DataIntegrityError


def _empty_horizon(row: dict[str, object], horizon: int, status: str) -> None:
    row[f"forward_return_{horizon}m"] = np.nan
    row[f"MFE_{horizon}m"] = np.nan
    row[f"MAE_{horizon}m"] = np.nan
    row[f"time_to_MFE_{horizon}m"] = np.nan
    row[f"time_to_MAE_{horizon}m"] = np.nan
    row[f"forward_label_status_{horizon}m"] = status


def _empty_barrier(row: dict[str, object], status: str) -> None:
    row.update(
        {
            "hit_take_profit_first": pd.NA,
            "hit_stop_loss_first": pd.NA,
            "triple_barrier_return": np.nan,
            "triple_barrier_mfe": np.nan,
            "triple_barrier_mae": np.nan,
            "net_return_after_cost": np.nan,
            "profitable_after_cost": pd.NA,
            "barrier_label_status": status,
        }
    )


def _missing_window_status(
    expected: pd.DatetimeIndex,
    available_session_index: pd.DatetimeIndex,
) -> str:
    if not len(available_session_index) or expected[0] > available_session_index[-1]:
        return "excluded_insufficient_forward_bars"
    missing = expected.difference(available_session_index)
    if len(missing) and missing[0] <= available_session_index[-1]:
        return "excluded_non_contiguous_forward_bars"
    return "excluded_insufficient_forward_bars"


def build_labels(candidates: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    if candidates.empty:
        return candidates.copy()
    if "timestamp" not in features:
        raise ValueError("features must contain timestamp")
    if features.empty:
        raise DataIntegrityError("cannot construct labels from an empty feature frame")
    bars_frame = features.copy()
    bars_frame["timestamp"] = pd.to_datetime(bars_frame["timestamp"], errors="raise")
    if bars_frame["timestamp"].dt.tz is None:
        raise DataIntegrityError("label construction requires timezone-aware feature bars")
    if bars_frame.duplicated("timestamp").any():
        raise DataIntegrityError(
            "duplicate feature timestamps make forward labels ambiguous"
        )
    minute_aligned = (
        bars_frame["timestamp"].dt.second.eq(0)
        & bars_frame["timestamp"].dt.microsecond.eq(0)
        & bars_frame["timestamp"].dt.nanosecond.eq(0)
    )
    if not minute_aligned.all():
        raise DataIntegrityError(
            "forward labels require exact minute-aligned feature timestamps"
        )
    bars_frame["_session_date"] = bars_frame["timestamp"].dt.date
    session_indexes = {
        session_date: pd.DatetimeIndex(group["timestamp"].sort_values())
        for session_date, group in bars_frame.groupby(
            "_session_date",
            sort=False,
            observed=True,
        )
    }
    bars = bars_frame.set_index("timestamp").sort_index()
    candidate_times = pd.to_datetime(candidates["timestamp"], errors="raise")
    if candidate_times.dt.tz is None:
        raise DataIntegrityError("label construction requires timezone-aware candidate timestamps")
    candidate_minute_aligned = (
        candidate_times.dt.second.eq(0)
        & candidate_times.dt.microsecond.eq(0)
        & candidate_times.dt.nanosecond.eq(0)
    )
    if not candidate_minute_aligned.all():
        raise DataIntegrityError(
            "label construction requires exact minute-aligned candidate timestamps"
        )
    first_date = min(candidate_times.min().date(), bars.index.min().date())
    last_date = max(candidate_times.max().date(), bars.index.max().date())
    schedule = market_schedule(str(first_date), str(last_date), config.timezone)
    session_opens = schedule["open"].to_dict()
    session_closes = schedule["close"].to_dict()

    rows: list[dict[str, object]] = []
    max_h = max(config.forecast_horizons)
    for candidate in candidates.itertuples(index=False):
        row = candidate._asdict()
        signal_time = pd.Timestamp(candidate.timestamp)
        session_date = signal_time.date()
        session_open = session_opens.get(session_date)
        session_close = session_closes.get(session_date)
        expected_entry = signal_time + pd.Timedelta(minutes=1)
        session_index = session_indexes.get(session_date, pd.DatetimeIndex([]))
        entry_status = "eligible"
        if session_open is None or session_close is None:
            entry_status = "excluded_cross_session"
        elif (
            signal_time < session_open
            or signal_time >= session_close
            or expected_entry >= session_close
        ):
            entry_status = "excluded_insufficient_forward_bars"
        elif expected_entry not in bars.index:
            entry_status = "excluded_missing_exact_next_minute_entry"
        row.update(
            {
                "signal_time": signal_time,
                "earliest_entry": pd.NaT,
                "label_entry_price": np.nan,
                "entry_status": entry_status,
            }
        )

        if row["entry_status"] != "eligible":
            for horizon in config.forecast_horizons:
                _empty_horizon(row, horizon, str(row["entry_status"]))
            _empty_barrier(row, str(row["entry_status"]))
            row.update(
                {
                    "eligible_forward_horizon_count": 0,
                    "excluded_forward_horizon_count": len(config.forecast_horizons),
                    "all_forward_labels_eligible": False,
                    "label_exclusion_reasons": str(row["entry_status"]),
                }
            )
            rows.append(row)
            continue

        entry_time = expected_entry
        entry_bar = bars.loc[entry_time]
        entry = float(entry_bar["open"])
        if not np.isfinite(entry) or entry <= 0:
            row["entry_status"] = "excluded_entry_unavailable"
            for horizon in config.forecast_horizons:
                _empty_horizon(row, horizon, "excluded_entry_unavailable")
            _empty_barrier(row, "excluded_entry_unavailable")
            row.update(
                {
                    "eligible_forward_horizon_count": 0,
                    "excluded_forward_horizon_count": len(config.forecast_horizons),
                    "all_forward_labels_eligible": False,
                    "label_exclusion_reasons": "excluded_entry_unavailable",
                }
            )
            rows.append(row)
            continue

        row.update(
            {
                "earliest_entry": entry_time,
                "label_entry_price": entry,
                "entry_status": "eligible",
            }
        )
        direction = int(candidate.direction)
        for horizon in config.forecast_horizons:
            expected = pd.date_range(entry_time, periods=horizon, freq="1min")
            if expected[-1] >= session_close:
                _empty_horizon(
                    row,
                    horizon,
                    "excluded_insufficient_forward_bars",
                )
                continue
            missing = expected.difference(session_index)
            if len(missing):
                _empty_horizon(
                    row,
                    horizon,
                    _missing_window_status(expected, session_index),
                )
                continue
            window = bars.loc[expected]
            signed_close = direction * (float(window.iloc[-1]["close"]) / entry - 1)
            favorable = direction * (window["high" if direction == 1 else "low"] / entry - 1)
            adverse = direction * (window["low" if direction == 1 else "high"] / entry - 1)
            row[f"forward_return_{horizon}m"] = signed_close
            row[f"MFE_{horizon}m"] = max(0.0, float(favorable.max()))
            row[f"MAE_{horizon}m"] = abs(min(0.0, float(adverse.min())))
            row[f"time_to_MFE_{horizon}m"] = int(np.argmax(favorable.to_numpy())) + 1
            row[f"time_to_MAE_{horizon}m"] = int(np.argmin(adverse.to_numpy())) + 1
            row[f"forward_label_status_{horizon}m"] = "eligible"

        raw_atr = entry_bar.get("rolling_atr", np.nan)
        try:
            atr = float(raw_atr)
        except (TypeError, ValueError):
            atr = np.nan
        if not np.isfinite(atr):
            _empty_barrier(row, "excluded_missing_atr")
            barrier_window = pd.DataFrame()
        elif atr <= 0:
            _empty_barrier(row, "excluded_invalid_atr")
            barrier_window = pd.DataFrame()
        else:
            tp = config.risk.take_profit_value * atr / entry
            sl = config.risk.stop_value * atr / entry
            requested_barrier_minutes = min(
                config.risk.max_holding_minutes,
                max_h,
            )
            session_minutes_remaining = max(
                0,
                int((session_close - entry_time) / pd.Timedelta(minutes=1)),
            )
            barrier_minutes = min(
                requested_barrier_minutes,
                session_minutes_remaining,
            )
            barrier_expected = pd.date_range(
                entry_time,
                periods=barrier_minutes,
                freq="1min",
            )
            if not barrier_minutes:
                _empty_barrier(row, "excluded_insufficient_forward_bars")
                barrier_window = pd.DataFrame()
            elif len(barrier_expected.difference(session_index)):
                _empty_barrier(
                    row,
                    _missing_window_status(barrier_expected, session_index),
                )
                barrier_window = pd.DataFrame()
            else:
                barrier_window = bars.loc[barrier_expected]

        hit_tp = False
        hit_sl = False
        barrier_return = np.nan
        barrier_mfe = 0.0
        barrier_mae = 0.0
        for quote in barrier_window.itertuples():
            high_ret = direction * (getattr(quote, "high" if direction == 1 else "low") / entry - 1)
            low_ret = direction * (getattr(quote, "low" if direction == 1 else "high") / entry - 1)
            barrier_mfe = max(barrier_mfe, high_ret)
            barrier_mae = max(barrier_mae, -low_ret)
            this_tp = high_ret >= tp
            this_sl = low_ret <= -sl
            if this_sl:  # conservative ordering when both occur in one minute
                hit_sl, barrier_return = True, -sl
                break
            if this_tp:
                hit_tp, barrier_return = True, tp
                break
        if len(barrier_window) and not hit_tp and not hit_sl:
            barrier_return = direction * (float(barrier_window.iloc[-1]["close"]) / entry - 1)
        cost_return = (2 * (config.costs.underlying_slippage_bps + config.costs.estimated_spread_bps)) / 10_000
        if len(barrier_window):
            row.update(
                {
                    "hit_take_profit_first": hit_tp,
                    "hit_stop_loss_first": hit_sl,
                    "triple_barrier_return": barrier_return,
                    "triple_barrier_mfe": max(0.0, barrier_mfe),
                    "triple_barrier_mae": max(0.0, barrier_mae),
                    "net_return_after_cost": (
                        barrier_return - cost_return
                        if np.isfinite(barrier_return)
                        else np.nan
                    ),
                    "profitable_after_cost": bool(
                        np.isfinite(barrier_return)
                        and barrier_return > cost_return
                    ),
                    "barrier_label_status": (
                        "eligible"
                        if barrier_minutes == requested_barrier_minutes
                        else "eligible_truncated_at_session_close"
                    ),
                }
            )

        statuses = [
            str(row[f"forward_label_status_{horizon}m"])
            for horizon in config.forecast_horizons
        ]
        eligible_count = statuses.count("eligible")
        exclusions = sorted({status for status in statuses if status != "eligible"})
        if str(row.get("barrier_label_status", "")).startswith("excluded_"):
            exclusions.append(str(row["barrier_label_status"]))
        row.update(
            {
                "eligible_forward_horizon_count": eligible_count,
                "excluded_forward_horizon_count": (
                    len(config.forecast_horizons) - eligible_count
                ),
                "all_forward_labels_eligible": (
                    eligible_count == len(config.forecast_horizons)
                ),
                "label_exclusion_reasons": "|".join(sorted(set(exclusions))),
            }
        )
        rows.append(row)
    return pd.DataFrame(rows)


def save_labels(labels: pd.DataFrame, config: AppConfig) -> None:
    path = config.output_dir / "features" / "labels.parquet"
    path.parent.mkdir(parents=True, exist_ok=True)
    labels.to_parquet(path, index=False)
