"""STUB — 见 ``intraday_quant/data/__init__.py``。

签名由 ``tests/test_core.py::test_timezone_dedup_and_invalid_volume`` 反推：
    clean, stats = clean_bars(raw_frame, "America/New_York")
    stats 至少含 "duplicates_removed" 与 "invalid_rows_removed"
    返回的 frame 的 timestamp 列被本地化到传入时区
"""

from __future__ import annotations

import pandas as pd

from . import _STUB_REASON


def clean_bars(frame: pd.DataFrame, timezone: str) -> tuple[pd.DataFrame, dict[str, int]]:
    """去重、时区本地化并剔除非法行，返回 (清洗后的 frame, 统计字典)。"""
    raise NotImplementedError(f"clean_bars: {_STUB_REASON}")
