from __future__ import annotations

import math

import numpy as np


class SplitConformalReturnInterval:
    """Frozen absolute-residual intervals for offline return challengers.

    Nominal coverage is a requested level, not a market-data guarantee: serial
    dependence and regime changes can invalidate exchangeability assumptions.
    """

    method = "split_conformal_absolute_residual"

    def __init__(self, coverage: float = 0.90):
        self.coverage = coverage
        self.radius: float | None = None
        self.sample_count = 0

    @staticmethod
    def _values(values: np.ndarray) -> np.ndarray:
        values = np.asarray(values, dtype=float)
        if values.ndim != 1 or not np.isfinite(values).all():
            raise ValueError("return evidence must be a finite 1D array")
        return values

    def fit(self, predictions: np.ndarray, outcomes: np.ndarray) -> "SplitConformalReturnInterval":
        self.radius = None
        self.sample_count = 0
        if not np.isfinite(self.coverage) or not 0 < self.coverage < 1:
            raise ValueError("interval coverage must lie strictly between 0 and 1")
        predictions, outcomes = self._values(predictions), self._values(outcomes)
        if not len(outcomes) or len(predictions) != len(outcomes):
            raise ValueError("return calibration requires matching nonempty arrays")
        rank = math.ceil((len(outcomes) + 1) * self.coverage)
        if rank > len(outcomes):
            raise ValueError("insufficient calibration rows for a finite return interval")
        with np.errstate(over="ignore"):
            residuals = np.abs(outcomes - predictions)
        if not np.isfinite(residuals).all():
            raise ValueError("return calibration residuals must be finite")
        self.radius = float(np.partition(residuals, rank - 1)[rank - 1])
        self.sample_count = len(outcomes)
        return self

    def predict(self, predictions: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        if self.radius is None:
            raise ValueError("return interval must be fit before prediction")
        predictions = self._values(predictions)
        with np.errstate(over="ignore"):
            lower, upper = predictions - self.radius, predictions + self.radius
        if not np.isfinite(lower).all() or not np.isfinite(upper).all():
            raise ValueError("return interval bounds must be finite")
        return lower, upper
