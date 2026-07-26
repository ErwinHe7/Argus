from __future__ import annotations

import numpy as np
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression


class ProbabilityCalibrator:
    def __init__(self, method: str = "isotonic"):
        self.method = method
        self.model = None

    def fit(self, probabilities: np.ndarray, y: np.ndarray) -> "ProbabilityCalibrator":
        if len(np.unique(y)) < 2:
            self.constant = float(np.mean(y)) if len(y) else 0.5
            return self
        if self.method == "isotonic" and len(y) >= 20:
            self.model = IsotonicRegression(out_of_bounds="clip").fit(probabilities, y)
        else:
            self.model = LogisticRegression().fit(probabilities.reshape(-1, 1), y)
        return self

    def predict(self, probabilities: np.ndarray) -> np.ndarray:
        if hasattr(self, "constant"):
            return np.full(len(probabilities), self.constant)
        if isinstance(self.model, IsotonicRegression):
            return self.model.predict(probabilities)
        return self.model.predict_proba(probabilities.reshape(-1, 1))[:, 1]

