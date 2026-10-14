from __future__ import annotations

import math

from pydantic import BaseModel, ConfigDict, Field

from intraday_quant.config import AppConfig


class FillCosts(BaseModel):
    """Dollar costs for one fixed-quantity fill, priced at its raw reference."""

    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    fill_price: float = Field(gt=0)
    spread_cost: float = Field(ge=0)
    slippage_cost: float = Field(ge=0)
    impact_cost: float = Field(ge=0)
    commission_cost: float = Field(ge=0)
    participation_rate: float | None = Field(default=None, ge=0)

    @property
    def total(self) -> float:
        return self.spread_cost + self.slippage_cost + self.impact_cost + self.commission_cost


class CapacityUnavailable(ValueError):
    pass


def spread_per_side_bps(config: AppConfig) -> float:
    full = config.execution_costs.full_spread_bps
    # Preserve the older estimated_spread_bps per-side convention.
    return config.costs.estimated_spread_bps if full is None else full / 2


def commission_per_side(config: AppConfig) -> float:
    amount = config.execution_costs.commission_per_side
    return config.costs.commission_per_trade if amount is None else amount


def minimum_round_trip_cost_return(config: AppConfig) -> float:
    """Pre-trade baseline at equal entry/exit prices, excluding unknown impact."""
    return (
        2 * (spread_per_side_bps(config) + config.costs.underlying_slippage_bps) / 10_000
        + 2 * commission_per_side(config) / config.execution_costs.trade_notional
    )


def fill_costs(
    raw_price: float, quantity: float, side: int, config: AppConfig,
    prior_volume: float | None = None,
) -> FillCosts:
    """Use completed prior-bar volume only; capacity is a research proxy."""
    if side not in {-1, 1}:
        raise ValueError("fill side must be -1 or 1")
    if not math.isfinite(raw_price) or raw_price <= 0 or not math.isfinite(quantity) or quantity <= 0:
        raise ValueError("fill price and quantity must be finite and positive")
    execution = config.execution_costs
    participation = None
    impact_bps = 0.0
    if execution.require_volume_capacity:
        if prior_volume is None or not math.isfinite(prior_volume) or prior_volume <= 0:
            raise CapacityUnavailable("missing_positive_prior_same_symbol_volume")
        participation = quantity / prior_volume
        if participation > execution.max_participation_rate:
            raise CapacityUnavailable("participation_limit_exceeded")
        impact_bps = execution.impact_bps_at_full_participation * participation
    spread_bps = spread_per_side_bps(config)
    slippage_bps = config.costs.underlying_slippage_bps
    notional = raw_price * quantity
    spread = notional * spread_bps / 10_000
    slippage = notional * slippage_bps / 10_000
    impact = notional * impact_bps / 10_000
    return FillCosts(
        fill_price=raw_price * (1 + side * (spread_bps + slippage_bps + impact_bps) / 10_000),
        spread_cost=spread, slippage_cost=slippage, impact_cost=impact,
        commission_cost=commission_per_side(config), participation_rate=participation,
    )
