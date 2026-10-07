from __future__ import annotations

import numpy as np
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression


class ProbabilityCalibrator:
    def __init__(self, method: str = "isotonic"):
        self.method = method
        self.model = None

    def fit(self, probabilities: np.ndarray, y: np.ndarray) -> "ProbabilityCalibrator":
        self.model = None
        self.__dict__.pop("constant", None)
        if self.method not in {"isotonic", "sigmoid", "platt"}:
            raise ValueError("unknown probability calibration method")
        probabilities = self._probabilities(probabilities)
        y = np.asarray(y, dtype=float)
        if y.ndim != 1 or not len(y) or len(y) != len(probabilities) or not np.isin(y, [0, 1]).all():
            raise ValueError("calibration labels must be nonempty, binary, and match probabilities")
        if len(np.unique(y)) < 2:
            self.constant = float(np.mean(y))
            return self
        if self.method == "isotonic" and len(y) >= 20:
            self.model = IsotonicRegression(out_of_bounds="clip").fit(probabilities, y)
        else:
            self.model = LogisticRegression().fit(probabilities.reshape(-1, 1), y)
        return self

    def predict(self, probabilities: np.ndarray) -> np.ndarray:
        if self.model is None and not hasattr(self, "constant"):
            raise ValueError("calibrator must be fit before prediction")
        probabilities = self._probabilities(probabilities)
        if not len(probabilities):
            return np.empty(0, dtype=float)
        if hasattr(self, "constant"):
            return np.full(len(probabilities), self.constant)
        if isinstance(self.model, IsotonicRegression):
            return self.model.predict(probabilities)
        return self.model.predict_proba(probabilities.reshape(-1, 1))[:, 1]

    @staticmethod
    def _probabilities(values: np.ndarray) -> np.ndarray:
        values = np.asarray(values, dtype=float)
        if values.ndim != 1 or not np.isfinite(values).all() or ((values < 0) | (values > 1)).any():
            raise ValueError("probabilities must be a finite 1D array in [0, 1]")
        return values
