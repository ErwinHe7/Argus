from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


def session_vwap(frame: pd.DataFrame) -> pd.Series:
    typical = (frame["high"] + frame["low"] + frame["close"]) / 3
    date = frame["timestamp"].dt.date
    numerator = (typical * frame["volume"]).groupby(date).cumsum()
    denominator = frame["volume"].groupby(date).cumsum()
    return numerator / denominator.replace(0, np.nan)


def same_minute_rvol(frame: pd.DataFrame, lookback_days: int = 20) -> pd.Series:
    df = frame[["timestamp", "volume"]].copy()
    df["session_date"] = df["timestamp"].dt.date
    df["minute_of_day"] = df["timestamp"].dt.hour * 60 + df["timestamp"].dt.minute
    df["cumulative_volume"] = df.groupby("session_date")["volume"].cumsum()
    history_mean = df.groupby("minute_of_day")["cumulative_volume"].transform(
        lambda s: s.shift(1).rolling(lookback_days, min_periods=3).mean()
    )
    return df["cumulative_volume"] / history_mean.replace(0, np.nan)


def _consecutive(values: pd.Series, positive: bool) -> pd.Series:
    flag = values.gt(0) if positive else values.lt(0)
    groups = (~flag).cumsum()
    return flag.groupby(groups).cumsum().astype(float)


def build_features(bars: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    target = bars.loc[bars["symbol"] == config.target].copy().sort_values("timestamp")
    if target.empty:
        raise ValueError(f"target {config.target} has no bars")
    target["session_date"] = target["timestamp"].dt.date
    target["minute_of_day"] = target["timestamp"].dt.hour * 60 + target["timestamp"].dt.minute
    target["minutes_from_open"] = target["minute_of_day"] - 570
    target["minutes_to_close"] = 960 - target["minute_of_day"]
    g = target.groupby("session_date", group_keys=False)
    for n in (1, 3, 5, 15, 30):
        target[f"ret_{n}m"] = g["close"].pct_change(n, fill_method=None)
    prev_close = g["close"].last().shift(1)
    session_open = g["open"].transform("first")
    target["prev_close"] = target["session_date"].map(prev_close)
    target["overnight_gap"] = session_open / target["prev_close"] - 1
    target["gap_from_prev_close"] = target["close"] / target["prev_close"] - 1
    target["dist_session_open"] = target["close"] / session_open - 1
    target["target_session_open"] = session_open
    target["session_vwap"] = session_vwap(target)
    target["dist_vwap"] = target["close"] / target["session_vwap"] - 1
    opening_mask = target["minutes_from_open"] < config.opening_range_minutes
    opening_high = target["high"].where(opening_mask).groupby(target["session_date"]).transform("max")
    opening_low = target["low"].where(opening_mask).groupby(target["session_date"]).transform("min")
    available = target["minutes_from_open"] >= config.opening_range_minutes
    target["opening_range_high"] = opening_high.where(available)
    target["opening_range_low"] = opening_low.where(available)
    target["dist_opening_range_high"] = target["close"] / target["opening_range_high"] - 1
    target["dist_opening_range_low"] = target["close"] / target["opening_range_low"] - 1
    daily_high = g["high"].max().shift(1)
    daily_low = g["low"].min().shift(1)
    target["prev_day_high"] = target["session_date"].map(daily_high)
    target["prev_day_low"] = target["session_date"].map(daily_low)
    target["dist_prev_day_high"] = target["close"] / target["prev_day_high"] - 1
    target["dist_prev_day_low"] = target["close"] / target["prev_day_low"] - 1
    cum_high = g["high"].cummax()
    cum_low = g["low"].cummin()
    target["session_range_position"] = (target["close"] - cum_low) / (cum_high - cum_low).replace(0, np.nan)
    target["rolling_realized_vol"] = g["ret_1m"].transform(lambda s: s.rolling(30, min_periods=10).std())
    prev = g["close"].shift(1)
    true_range = pd.concat([(target["high"] - target["low"]), (target["high"] - prev).abs(), (target["low"] - prev).abs()], axis=1).max(axis=1)
    target["rolling_atr"] = true_range.groupby(target["session_date"]).transform(lambda s: s.rolling(14, min_periods=5).mean())
    ranges = (target["high"] - target["low"]) / target["close"]
    mean_range = ranges.groupby(target["session_date"]).transform(lambda s: s.rolling(30, min_periods=10).mean())
    std_range = ranges.groupby(target["session_date"]).transform(lambda s: s.rolling(30, min_periods=10).std())
    target["high_low_range_zscore"] = (ranges - mean_range) / std_range.replace(0, np.nan)
    target["consecutive_up_bars"] = g["ret_1m"].transform(lambda s: _consecutive(s, True))
    target["consecutive_down_bars"] = g["ret_1m"].transform(lambda s: _consecutive(s, False))

    # SPY volume is the primary volume proxy for SPX.
    proxy_symbol = "SPY" if "SPY" in set(bars["symbol"]) else config.target
    proxy = bars.loc[bars["symbol"] == proxy_symbol].sort_values("timestamp").copy()
    proxy["session_date"] = proxy["timestamp"].dt.date
    proxy["volume_1m"] = proxy["volume"]
    proxy["proxy_session_open"] = proxy.groupby("session_date")["open"].transform("first")
    proxy["proxy_session_vwap"] = session_vwap(proxy)
    proxy["cumulative_volume"] = proxy.groupby("session_date")["volume"].cumsum()
    proxy["rvol_same_minute"] = same_minute_rvol(proxy)
    vol_mean = proxy.groupby("session_date")["volume"].transform(lambda s: s.rolling(30, min_periods=10).mean())
    vol_std = proxy.groupby("session_date")["volume"].transform(lambda s: s.rolling(30, min_periods=10).std())
    proxy["volume_zscore"] = (proxy["volume"] - vol_mean) / vol_std.replace(0, np.nan)
    proxy["volume_acceleration"] = proxy.groupby("session_date")["volume"].pct_change(fill_method=None).replace([np.inf, -np.inf], np.nan)
    proxy_ret = proxy.groupby("session_date")["close"].pct_change(fill_method=None)
    proxy["up_volume_ratio"] = proxy["volume"].where(proxy_ret > 0, 0).groupby(proxy["session_date"]).cumsum() / proxy["cumulative_volume"].replace(0, np.nan)
    proxy["down_volume_ratio"] = proxy["volume"].where(proxy_ret < 0, 0).groupby(proxy["session_date"]).cumsum() / proxy["cumulative_volume"].replace(0, np.nan)
    proxy_volume_change = proxy.groupby("session_date")["volume"].pct_change(fill_method=None)
    proxy["price_volume_divergence"] = proxy_ret.groupby(proxy["session_date"]).transform(
        lambda returns: returns.rolling(10, min_periods=5).corr(
            proxy_volume_change.loc[returns.index]
        )
    )
    volume_cols = ["timestamp", "volume_1m", "cumulative_volume", "rvol_same_minute", "volume_zscore", "volume_acceleration", "up_volume_ratio", "down_volume_ratio", "price_volume_divergence", "proxy_session_open", "proxy_session_vwap"]
    target = target.merge(proxy[volume_cols], on="timestamp", how="left")
    inferred_target_vwap = target["target_session_open"] * target["proxy_session_vwap"] / target["proxy_session_open"]
    target["session_vwap"] = target["session_vwap"].fillna(inferred_target_vwap)
    target["dist_vwap"] = target["close"] / target["session_vwap"] - 1

    wide = bars.pivot(index="timestamp", columns="symbol", values="close").sort_index()
    cross = pd.DataFrame(index=wide.index)
    for symbol in ["SPY", "QQQ", "SOXX", "IWM", "ES"]:
        cross[f"{symbol.lower()}_ret_5m"] = wide[symbol].pct_change(5, fill_method=None) if symbol in wide else np.nan
    if "VIX" in wide:
        cross["vix_change_5m"] = wide["VIX"].pct_change(5, fill_method=None)
        cross["vix_change_15m"] = wide["VIX"].pct_change(15, fill_method=None)
    else:
        cross[["vix_change_5m", "vix_change_15m"]] = np.nan
    cross["spx_minus_qqq"] = cross.get("spy_ret_5m", np.nan) - cross.get("qqq_ret_5m", np.nan)
    cross["spx_minus_soxx"] = cross.get("spy_ret_5m", np.nan) - cross.get("soxx_ret_5m", np.nan)
    cross["qqq_minus_soxx"] = cross.get("qqq_ret_5m", np.nan) - cross.get("soxx_ret_5m", np.nan)
    if "ES" in wide and "SPX" in wide:
        cross["es_spx_basis"] = wide["ES"] / wide["SPX"] - 1
    else:
        cross["es_spx_basis"] = np.nan
    breadth_cols = [c for c in ["spy_ret_5m", "qqq_ret_5m", "soxx_ret_5m", "iwm_ret_5m", "es_ret_5m"] if c in cross]
    cross["cross_asset_breadth_score"] = np.sign(cross[breadth_cols]).mean(axis=1)
    cross["market_confirmation_score"] = cross[breadth_cols].mean(axis=1) / (cross[breadth_cols].std(axis=1) + 1e-8)
    target = target.merge(cross.reset_index(), on="timestamp", how="left")

    target["opening_15m"] = target["minutes_from_open"].between(0, 14)
    target["opening_30m"] = target["minutes_from_open"].between(0, 29)
    target["lunch_period"] = target["minute_of_day"].between(720, 810)
    target["power_hour"] = target["minute_of_day"] >= 900
    target["closing_10m"] = target["minute_of_day"] >= 950
    target["ret_from_1550"] = target.groupby("session_date")["close"].transform(
        lambda s: s / s.where(target.loc[s.index, "minute_of_day"] == 950).ffill() - 1
    ).fillna(0.0)
    bar_range = (target["high"] - target["low"]).replace(0, np.nan)
    target["close_location_value"] = ((target["close"] - target["low"]) - (target["high"] - target["close"])) / bar_range
    target["buy_pressure_proxy"] = target["close_location_value"] * target["volume_zscore"].clip(lower=0).fillna(0)
    target["closing_short_cover_score"] = np.where(
        target["closing_10m"],
        target["ret_5m"].clip(lower=0).fillna(0) * 10_000
        + target["buy_pressure_proxy"].clip(lower=0)
        + target["cross_asset_breadth_score"].clip(lower=0).fillna(0),
        0.0,
    )
    target["day_of_week"] = target["timestamp"].dt.dayofweek
    target["month_end"] = target["timestamp"].dt.is_month_end
    target["quarter_end"] = target["timestamp"].dt.is_quarter_end
    for col in ["opex_day", "monthly_opex", "cpi_day", "fomc_day", "nfp_day", "major_event_within_30m"]:
        target[col] = False
    target["time_sin"] = np.sin(2 * np.pi * target["minutes_from_open"] / 390)
    target["time_cos"] = np.cos(2 * np.pi * target["minutes_from_open"] / 390)
    target["feature_quality"] = np.where(target.isna().mean(axis=1) > 0.35, "insufficient_history", "ok")
    return target.sort_values("timestamp").reset_index(drop=True)


def save_features(features: pd.DataFrame, config: AppConfig) -> None:
    path = config.output_dir / "features" / "features.parquet"
    path.parent.mkdir(parents=True, exist_ok=True)
    features.to_parquet(path, index=False)
