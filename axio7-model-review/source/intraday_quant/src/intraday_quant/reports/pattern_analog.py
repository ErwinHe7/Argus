"""STUB — 见 ``intraday_quant/reports/__init__.py``。

签名由 ``intraday_quant/cli.py:81`` 与 ``intraday_quant/service.py:108`` 反推：
    analogs = closing_state_analogs(features, target_date)
    -> 返回 DataFrame，列至少含 return_1550_to_close / date_string / rank
    -> 目标日期不可用时抛 ValueError（service.py:109 捕获它并返回 None）
"""

from __future__ import annotations

import pandas as pd

from . import _STUB_REASON


def closing_state_analogs(features: pd.DataFrame, target_date: str) -> pd.DataFrame:
    """检索与 target_date 尾盘状态最相似的历史交易日。"""
    raise NotImplementedError(f"closing_state_analogs: {_STUB_REASON}")
