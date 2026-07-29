"""Compatibility entry point for the current intraday UI smoke test.

The original dashboard assertions targeted a retired component and could pass
without exercising the active Rust v4.4 forecast surface. Keep one canonical
smoke so this legacy command validates the same SDE/kernel/probability
semantics as the current /quant/intraday page.
"""

from __future__ import annotations

import runpy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
runpy.run_path(
    str(ROOT / "scripts" / "smoke-sde-kernel-interval-ui.py"),
    run_name="__main__",
)
