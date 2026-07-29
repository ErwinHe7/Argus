"""RETIRED as of the M3 fix -- no longer called by walk_forward.py.

This was a from-scratch approximation of the production same-regime kernel
(engine::analog_engine::AnalogEngine in quant_engine_rs) that diverged from it
in at least eight independent ways: standardization (median/MAD vs mean/std),
distance metric (shrinkage Mahalanobis vs plain L2), feature set (fixed 12-dim
vs up to 51 columns), bandwidth rule, regime-posterior weighting, neighbor
eligibility (same-regime/same-bucket/one-per-day vs none of that), k, and
whether `median_return` was weighted. Any backtest number this class produced
measured that different estimator, not the one that ships.

walk_forward.py now calls `quantctl research analog-backtest`
(models/walk_forward.py::_run_analog_backtest) instead, which drives the
actual production kernel. Left here for reference and because
review-package/REMEDIATION-PLAN.zh-CN.md M3's other named option -- keep this
as an explicit research-toy comparison, deliberately excluded from
config.models -- is still legitimate; just do it on purpose, not by accident.
Do not wire this back into the default walk-forward path.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler


class AnalogKernelModel:
    def __init__(self, neighbors: int = 25, bandwidth: float = 1.0):
        self.neighbors = neighbors
        self.bandwidth = bandwidth
        self.imputer = SimpleImputer(strategy="median")
        self.scaler = StandardScaler()

    def fit(self, x: pd.DataFrame, y: pd.DataFrame, timestamps: pd.Series) -> "AnalogKernelModel":
        transformed = self.imputer.fit_transform(x)
        self.x_train = self.scaler.fit_transform(transformed)
        self.y_train = y.reset_index(drop=True)
        self.timestamps = pd.to_datetime(timestamps).reset_index(drop=True)
        return self

    def predict(self, x: pd.DataFrame, timestamps: pd.Series) -> pd.DataFrame:
        query = self.scaler.transform(self.imputer.transform(x))
        outputs: list[dict[str, object]] = []
        for vector, timestamp in zip(query, pd.to_datetime(timestamps), strict=False):
            # The caller already supplies prior-fold history; this guard also makes direct use safe.
            eligible = np.flatnonzero((self.timestamps < timestamp).to_numpy())
            if len(eligible) == 0:
                outputs.append(self._empty())
                continue
            distances = np.linalg.norm(self.x_train[eligible] - vector, axis=1) / np.sqrt(max(1, vector.size))
            order = np.argsort(distances)[: self.neighbors]
            idx = eligible[order]
            d = distances[order]
            weights = np.exp(-0.5 * (d / max(self.bandwidth, 1e-6)) ** 2)
            weights = weights / max(weights.sum(), 1e-12)
            returns = self.y_train.loc[idx, "return"].to_numpy(float)
            mfe = self.y_train.loc[idx, "mfe"].to_numpy(float)
            mae = self.y_train.loc[idx, "mae"].to_numpy(float)
            outputs.append({
                "expected_return": float(np.sum(weights * returns)),
                "median_return": float(np.median(returns)),
                "win_probability": float(np.sum(weights * (returns > 0))),
                "predicted_mfe": float(np.sum(weights * mfe)),
                "predicted_mae": float(np.sum(weights * mae)),
                "neighbor_count": int(len(idx)),
                "similarity_score": float(1 / (1 + np.average(d, weights=weights))),
                "uncertainty": float(np.sqrt(np.sum(weights * (returns - np.sum(weights * returns)) ** 2))),
                "neighbor_dates": "|".join(self.timestamps.iloc[idx].dt.strftime("%Y-%m-%d").tolist()),
            })
        return pd.DataFrame(outputs)

    @staticmethod
    def _empty() -> dict[str, object]:
        return {"expected_return": 0.0, "median_return": 0.0, "win_probability": 0.5,
                "predicted_mfe": 0.0, "predicted_mae": 0.0, "neighbor_count": 0,
                "similarity_score": 0.0, "uncertainty": 1.0, "neighbor_dates": ""}

