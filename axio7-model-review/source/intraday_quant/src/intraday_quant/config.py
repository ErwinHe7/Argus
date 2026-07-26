from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SessionConfig(StrictModel):
    start: str = "09:30"
    end: str = "16:00"


class DataConfig(StrictModel):
    adapter: str = "synthetic"
    input_path: str | None = None
    synthetic_seed: int = 7
    synthetic_sessions: int = 60
    price_ffill_limit: int = 2
    output_dir: str = "data"


class ModelConfig(StrictModel):
    analog_neighbors: int = 25
    analog_bandwidth: float = 1.0
    calibration: str = "isotonic"
    score_threshold_quantile: float = 0.60


class ScoringConfig(StrictModel):
    """Validation-locked candidate utility function coefficients."""

    return_weight: float = 1.0
    probability_base: float = 0.5
    mfe_weight: float = 0.25
    uncertainty_weight: float = 1.0


class WalkForwardConfig(StrictModel):
    train_sessions: int = 30
    validation_sessions: int = 10
    test_sessions: int = 10
    step_sessions: int = 10
    expanding: bool = True
    purge_minutes: int = 60
    embargo_minutes: int = 15


class PortfolioConfig(StrictModel):
    max_trades_per_day: int = 2
    max_open_positions: int = 1
    cooldown_minutes: int = 30
    max_same_direction_per_day: int = 1
    risk_floor_bps: float = 5.0


class CostConfig(StrictModel):
    commission_per_trade: float = 1.0
    underlying_slippage_bps: float = 1.0
    estimated_spread_bps: float = 1.0
    option_slippage: float = 0.05


class RiskConfig(StrictModel):
    stop_type: str = "atr"
    take_profit_type: str = "atr"
    stop_value: float = 1.0
    take_profit_value: float = 1.5
    max_holding_minutes: int = 60


class OptionExecutionConfig(StrictModel):
    enabled: bool = False
    quotes_path: str | None = None
    dte: list[int] = Field(default_factory=lambda: [0, 1])
    delta_min: float = 0.35
    delta_max: float = 0.60
    max_spread_pct: float = 0.20
    max_quote_age_seconds: int = 90
    min_bid_size: int = 1


class AppConfig(StrictModel):
    target: str = "SPX"
    bar_frequency: str = "1min"
    timezone: str = "America/New_York"
    start_date: str
    end_date: str
    session: SessionConfig = Field(default_factory=SessionConfig)
    data: DataConfig = Field(default_factory=DataConfig)
    symbols: list[str]
    forecast_horizons: list[int] = Field(default_factory=lambda: [5, 15, 30, 60])
    opening_range_minutes: int = 15
    setups: list[str]
    models: list[str]
    model: ModelConfig = Field(default_factory=ModelConfig)
    scoring: ScoringConfig = Field(default_factory=ScoringConfig)
    walk_forward: WalkForwardConfig = Field(default_factory=WalkForwardConfig)
    portfolio: PortfolioConfig = Field(default_factory=PortfolioConfig)
    costs: CostConfig = Field(default_factory=CostConfig)
    risk: RiskConfig = Field(default_factory=RiskConfig)
    option_execution: OptionExecutionConfig = Field(default_factory=OptionExecutionConfig)
    config_path: Path | None = None

    @model_validator(mode="after")
    def validate_values(self) -> "AppConfig":
        if self.target not in self.symbols:
            raise ValueError("target must be included in symbols")
        if not self.forecast_horizons or any(
            horizon not in {5, 15, 30, 60} for horizon in self.forecast_horizons
        ):
            raise ValueError("forecast_horizons must contain only 5, 15, 30, or 60 minutes")
        if len(set(self.forecast_horizons)) != len(self.forecast_horizons):
            raise ValueError("forecast_horizons must be unique")
        if not 0 <= self.model.score_threshold_quantile <= 1:
            raise ValueError("score_threshold_quantile must be within [0, 1]")
        if self.portfolio.max_trades_per_day < 0:
            raise ValueError("max_trades_per_day must be non-negative")
        return self

    @property
    def project_dir(self) -> Path:
        return (self.config_path.parent.parent if self.config_path else Path.cwd()).resolve()

    @property
    def output_dir(self) -> Path:
        value = Path(self.data.output_dir)
        return value if value.is_absolute() else self.project_dir / value


def load_config(path: str | Path) -> AppConfig:
    config_path = Path(path).resolve()
    with config_path.open("r", encoding="utf-8") as handle:
        raw: dict[str, Any] = yaml.safe_load(handle)
    return AppConfig(**raw, config_path=config_path)
