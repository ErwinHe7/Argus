"""STUB — 见 ``intraday_quant/data/__init__.py``。

签名由 ``intraday_quant/cli.py`` 反推：
    _, stats = ingest(config)          # cli.py:68
    result = ingest(config)[1]         # cli.py:119  -> 返回 2-tuple，[1] 是统计字典
    features = build_features(load_cleaned(config), config)   # cli.py:23 -> 返回 DataFrame
"""

from __future__ import annotations

import pandas as pd

from intraday_quant.config import AppConfig

from . import _STUB_REASON


def ingest(config: AppConfig) -> tuple[pd.DataFrame, dict[str, object]]:
    """按 point-in-time 约束拉取并落盘原始 bar，返回 (frame, 统计字典)。"""
    raise NotImplementedError(f"ingest: {_STUB_REASON}")


def load_cleaned(config: AppConfig) -> pd.DataFrame:
    """读取已清洗的 bar 数据。"""
    raise NotImplementedError(f"load_cleaned: {_STUB_REASON}")
