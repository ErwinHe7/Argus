from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal

import pandas as pd


BAR_COLUMNS = [
    "timestamp", "symbol", "open", "high", "low", "close", "volume",
    "vwap", "bid", "ask", "trade_count", "source", "data_quality",
]

OPTION_COLUMNS = [
    "timestamp", "underlying", "option_symbol", "expiry", "dte", "strike",
    "call_put", "bid", "ask", "bid_size", "ask_size", "mid", "last",
    "volume", "open_interest", "iv", "delta", "gamma", "theta", "vega",
    "underlying_price",
]


@dataclass(slots=True)
class CandidateRecord:
    candidate_id: str
    timestamp: pd.Timestamp
    setup_type: str
    direction: Literal[-1, 1]
    entry_reference: float
    feature_snapshot: dict[str, float | int | str | None] = field(default_factory=dict)
    reason_codes: list[str] = field(default_factory=list)


@dataclass(slots=True)
class PredictionRecord:
    candidate_id: str
    horizon_minutes: int
    model: str
    expected_return: float
    median_return: float
    win_probability: float
    predicted_mfe: float
    predicted_mae: float
    uncertainty: float
    neighbor_count: int = 0
    similarity_score: float = 0.0
    neighbor_dates: list[str] = field(default_factory=list)


@dataclass(slots=True)
class OptionFill:
    accepted: bool
    reason: str
    fill: float | None = None
    quote: dict[str, Any] | None = None
