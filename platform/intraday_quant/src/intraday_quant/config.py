from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator

from intraday_quant.models.constants import RETIRED_PYTHON_ANALOG_MODEL_NAME


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
    return_interval_coverage: float = Field(default=0.90, gt=0, lt=1)


class ScoringConfig(StrictModel):
    """Validation-locked candidate utility function coefficients."""

    return_weight: float = 1.0
    probability_base: float = 0.5
    mfe_weight: float = 0.25
    uncertainty_weight: float = 1.0


class WalkForwardConfig(StrictModel):
    train_sessions: int = Field(default=30, ge=1)
    validation_sessions: int = Field(default=10, ge=2)
    test_sessions: int = Field(default=10, ge=1)
    step_sessions: int = Field(default=10, ge=1)
    expanding: bool = True
    purge_minutes: int = Field(default=60, ge=0)
    embargo_minutes: int = Field(default=15, ge=0)

    @model_validator(mode="after")
    def validate_test_windows(self) -> "WalkForwardConfig":
        if self.step_sessions < self.test_sessions:
            raise ValueError("step_sessions must prevent overlapping test windows")
        return self


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


class ValidationEvidenceConfig(StrictModel):
    """Optional sealed evidence consumed by the descriptive report.

    Paths are resolved relative to the intraday project directory.  A dataset
    that requires a manifest must be configured as a complete pair so the
    report cannot silently treat an incomplete receipt as absent.
    """

    hypothesis_tests_path: str | None = None
    untouched_holdout_trades_path: str | None = None
    untouched_holdout_manifest_path: str | None = None
    point_in_time_market_grid_path: str | None = None
    point_in_time_market_manifest_path: str | None = None

    @model_validator(mode="after")
    def validate_receipt_pairs(self) -> "ValidationEvidenceConfig":
        pairs = (
            (
                "untouched_holdout_trades_path",
                self.untouched_holdout_trades_path,
                "untouched_holdout_manifest_path",
                self.untouched_holdout_manifest_path,
            ),
            (
                "point_in_time_market_grid_path",
                self.point_in_time_market_grid_path,
                "point_in_time_market_manifest_path",
                self.point_in_time_market_manifest_path,
            ),
        )
        for data_name, data_path, manifest_name, manifest_path in pairs:
            if bool(data_path) != bool(manifest_path):
                raise ValueError(
                    f"{data_name} and {manifest_name} must be supplied together"
                )
        return self


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
    validation_evidence: ValidationEvidenceConfig = Field(
        default_factory=ValidationEvidenceConfig
    )
    config_path: Path | None = None

    @model_validator(mode="after")
    def validate_values(self) -> "AppConfig":
        if self.target not in self.symbols:
            raise ValueError("target must be included in symbols")
        if self.bar_frequency != "1min":
            raise ValueError(
                "the primary pipeline requires exact 1min bars; validated "
                "5min observations must be derived from five contiguous "
                "one-minute bars"
            )
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
        if RETIRED_PYTHON_ANALOG_MODEL_NAME in self.models:
            raise ValueError(
                "model name 'analog_kernel' is retired because the Python estimator "
                "is not equivalent to the canonical Rust analog engine; use "
                "'legacy_exploratory_euclidean_analog' only for explicit, "
                "non-promotion research"
            )
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
