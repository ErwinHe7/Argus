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

