"""STUB — 见 ``intraday_quant/reports/__init__.py``。

签名由 ``intraday_quant/cli.py`` 反推：
    generate_report(config, stats, option_status)                    # cli.py:74（位置参数）
    generate_report(config, option_status=<str | None>)              # cli.py:134（关键字参数）
    -> 返回值被 str() 包装写进 JSON，且 run_all 直接返回它 -> Path
因此 stats 与 option_status 都必须有默认值。
"""

from __future__ import annotations

from pathlib import Path

from intraday_quant.config import AppConfig

from . import _STUB_REASON


def generate_report(
    config: AppConfig,
    stats: dict[str, object] | None = None,
    option_status: str | None = None,
) -> Path:
    """渲染 OOS 报告并返回落盘路径。"""
    raise NotImplementedError(f"generate_report: {_STUB_REASON}")
