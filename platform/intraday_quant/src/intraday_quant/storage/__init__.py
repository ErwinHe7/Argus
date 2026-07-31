"""Storage adapters with lazy loading for optional runtime dependencies."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from intraday_quant.storage.repository import ResearchRepository

__all__ = ["ResearchRepository"]


def __getattr__(name: str) -> Any:
    if name == "ResearchRepository":
        from intraday_quant.storage.repository import ResearchRepository

        return ResearchRepository
    raise AttributeError(name)
