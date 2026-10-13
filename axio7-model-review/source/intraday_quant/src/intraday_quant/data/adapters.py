from __future__ import annotations

from abc import ABC, abstractmethod
import json
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

import numpy as np
import pandas as pd

from intraday_quant.calendar import market_schedule, session_minutes
from intraday_quant.config import AppConfig


class DataAdapter(ABC):
    @abstractmethod
    def load(self) -> pd.DataFrame:
        raise NotImplementedError


class CSVAdapter(DataAdapter):
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> pd.DataFrame:
        return pd.read_csv(self.path)


class ParquetAdapter(DataAdapter):
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> pd.DataFrame:
        return pd.read_parquet(self.path)


class APIAdapter(DataAdapter, ABC):
    """Implement for a licensed provider; credentials remain provider-specific."""


class YahooChartAdapter(DataAdapter):
    """Recent unofficial Yahoo 1-minute bars; research use only, not production."""

    SYMBOL_MAP = {
        "SPX": "^GSPC", "ES": "ES=F", "SPY": "SPY", "QQQ": "QQQ",
        "SOXX": "SOXX", "IWM": "IWM", "VIX": "^VIX",
    }

    def __init__(self, config: AppConfig):
        self.config = config

    @staticmethod
    def _epoch(value: pd.Timestamp) -> int:
        return int(value.tz_localize("UTC").timestamp())

    def _fetch_chunk(self, yahoo_symbol: str, start: pd.Timestamp, end: pd.Timestamp) -> pd.DataFrame:
        url = (
            f"https://query1.finance.yahoo.com/v8/finance/chart/{quote(yahoo_symbol, safe='')}"
            f"?period1={self._epoch(start)}&period2={self._epoch(end)}"
            "&interval=1m&includePrePost=false&events=div%2Csplits"
        )
        request = Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; AXIO7-intraday/1.0)"})
        with urlopen(request, timeout=30) as response:
            payload = json.load(response)
        root = payload.get("chart", {}).get("result", [None])[0]
        if not root:
            error = payload.get("chart", {}).get("error", {})
            raise RuntimeError(f"Yahoo chart error for {yahoo_symbol}: {error}")
        quote_data = root.get("indicators", {}).get("quote", [{}])[0]
        timestamps = root.get("timestamp", [])
        return pd.DataFrame({
            "timestamp": pd.to_datetime(timestamps, unit="s", utc=True).tz_convert(self.config.timezone),
            "open": quote_data.get("open", []), "high": quote_data.get("high", []),
            "low": quote_data.get("low", []), "close": quote_data.get("close", []),
            "volume": quote_data.get("volume", []),
        })

    def load(self) -> pd.DataFrame:
        start = pd.Timestamp(self.config.start_date)
        final_end = pd.Timestamp(self.config.end_date) + pd.Timedelta(days=1)
        all_symbols: list[pd.DataFrame] = []
        for symbol in self.config.symbols:
            yahoo_symbol = self.SYMBOL_MAP.get(symbol, symbol)
            chunks: list[pd.DataFrame] = []
            cursor = start
            while cursor < final_end:
                chunk_end = min(cursor + pd.Timedelta(days=7), final_end)
                chunks.append(self._fetch_chunk(yahoo_symbol, cursor, chunk_end))
                cursor = chunk_end
            # Preserve chunk overlaps for the canonical cleaner. Exact copies
            # may be collapsed there; conflicting observations must never be
            # resolved by an arbitrary keep-first/keep-last rule.
            frame = pd.concat(chunks, ignore_index=True)
            local_dates = frame["timestamp"].dt.date
            frame = frame[(local_dates >= start.date()) & (local_dates <= pd.Timestamp(self.config.end_date).date())]
            frame["symbol"] = symbol
            frame["volume"] = pd.to_numeric(frame["volume"], errors="coerce")
            frame["vwap"] = (frame["high"] + frame["low"] + frame["close"]) / 3
            frame["bid"] = np.nan
            frame["ask"] = np.nan
            frame["trade_count"] = 0
            frame["source"] = "yahoo_chart_unofficial"
            frame["data_quality"] = "recent_1m_no_nbbo_research_only"
            all_symbols.append(frame)
        if not all_symbols:
            raise ValueError("Yahoo adapter returned no data")
        return pd.concat(all_symbols, ignore_index=True).sort_values(["timestamp", "symbol"])


class SyntheticDataAdapter(DataAdapter):
    """Deterministic correlated minute bars for pipeline validation only."""

    def __init__(self, config: AppConfig):
        self.config = config

    def load(self) -> pd.DataFrame:
        cfg = self.config
        schedule = market_schedule(cfg.start_date, cfg.end_date, cfg.timezone)
        if len(schedule) > cfg.data.synthetic_sessions:
            schedule = schedule.iloc[: cfg.data.synthetic_sessions]
        minutes = session_minutes(schedule)
        rng = np.random.default_rng(cfg.data.synthetic_seed)
        n = len(minutes)
        session_dates = pd.Series(minutes.date, index=minutes)
        session_open_by_date = schedule["open"].to_dict()
        session_opens = pd.DatetimeIndex(
            [session_open_by_date[value] for value in session_dates.to_numpy()]
        )
        minute_of_day = (
            (minutes - session_opens).total_seconds() / 60
        ).astype(int)
        u_shape = 0.65 + 1.8 * ((minute_of_day - 195) / 195) ** 2
        shared = rng.normal(0, 0.00018 * u_shape, n)
        # Persistent but non-guaranteed regimes create testable candidates.
        regime_by_date = dict(
            zip(
                schedule.index,
                rng.normal(0, 0.000025, len(schedule)),
                strict=True,
            )
        )
        regime = np.asarray(
            [regime_by_date[value] for value in session_dates.to_numpy()]
        )
        rows: list[pd.DataFrame] = []
        bases = {"SPX": 5100.0, "ES": 5110.0, "SPY": 510.0, "QQQ": 440.0,
                 "SOXX": 220.0, "IWM": 205.0, "VIX": 16.0}
        betas = {"SPX": 1.0, "ES": 1.02, "SPY": 1.0, "QQQ": 1.15,
                 "SOXX": 1.30, "IWM": 0.85, "VIX": -7.0}
        for symbol in cfg.symbols:
            idio = rng.normal(0, 0.00008 if symbol != "VIX" else 0.0012, n)
            returns = betas.get(symbol, 1.0) * shared + regime + idio
            close = bases.get(symbol, 100.0) * np.exp(np.cumsum(returns))
            open_ = np.r_[close[0], close[:-1]]
            spread = np.abs(rng.normal(0.00012, 0.00004, n))
            high = np.maximum(open_, close) * (1 + spread)
            low = np.minimum(open_, close) * (1 - spread)
            volume_base = 0 if symbol in {"SPX", "VIX"} else 500_000
            volume = (volume_base * u_shape * rng.lognormal(0, 0.35, n)).astype(int)
            typical = (high + low + close) / 3
            frame = pd.DataFrame({
                "timestamp": minutes, "symbol": symbol, "open": open_, "high": high,
                "low": low, "close": close, "volume": volume, "vwap": typical,
                "bid": close * (1 - spread / 2), "ask": close * (1 + spread / 2),
                "trade_count": np.maximum(0, (volume / 200).astype(int)),
                "source": "synthetic", "data_quality": "synthetic_validation_only",
            })
            rows.append(frame)
        return pd.concat(rows, ignore_index=True).sort_values(["timestamp", "symbol"])


def build_adapter(config: AppConfig) -> DataAdapter:
    name = config.data.adapter.lower()
    if name == "synthetic":
        return SyntheticDataAdapter(config)
    if name == "yahoo":
        return YahooChartAdapter(config)
    if not config.data.input_path:
        raise ValueError(f"data.input_path is required for adapter={name}")
    if name == "csv":
        return CSVAdapter(config.data.input_path)
    if name == "parquet":
        return ParquetAdapter(config.data.input_path)
    raise ValueError(f"unknown data adapter: {name}")
