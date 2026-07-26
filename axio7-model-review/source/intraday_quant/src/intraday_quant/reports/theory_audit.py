"""STUB — 见 ``intraday_quant/reports/__init__.py``。

签名由 ``tests/test_theory_audit.py`` 反推：
    audit = theory_performance_audit(trades).set_index("setup")
    -> 返回 DataFrame，含 setup 列（含一行 "ALL" 汇总）
    -> 列至少包含 win_rate / payoff_ratio / expectancy / verdict
    -> 样本不足时 verdict == "insufficient_sample"
输入 trades 至少含 setup、net_return 两列。
"""

from __future__ import annotations

import pandas as pd

from . import _STUB_REASON


def theory_performance_audit(trades: pd.DataFrame) -> pd.DataFrame:
    """按 setup 分组统计胜率、盈亏比、期望值，并给出样本量裁决。"""
    raise NotImplementedError(f"theory_performance_audit: {_STUB_REASON}")
