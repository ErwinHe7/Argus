from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import subprocess
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd


DEFAULT_SYMBOLS = ("SPY", "QQQ", "NVDA", "AAPL", "MU", "SOXX", "NBIS", "BE", "IGV")
DEFAULT_HORIZONS = (1, 3, 6, 12)
FEATURE_COLUMNS = (
    "return_1",
    "return_3",
    "return_6",
    "bar_body",
    "bar_range",
    "close_location",
    "distance_vwap",
    "realized_vol_6",
    "volume_z_20",
    "relative_volume_20",
    "spy_return_1",
    "qqq_return_1",
    "soxx_return_1",
    "time_sin",
    "time_cos",
)


@dataclass(frozen=True)
class DateSplit:
    train_dates: tuple[date, ...]
    validation_dates: tuple[date, ...]
    test_dates: tuple[date, ...]
    embargo_sessions: int


@dataclass
class SymbolPanel:
    symbol: str
    timestamps: np.ndarray
    session_dates: np.ndarray
    features: np.ndarray
    direction_targets: np.ndarray
    return_targets_bps: np.ndarray
    prior_returns_bps: np.ndarray
    vwap_cross_targets: np.ndarray
    favorable_excursion_targets_bps: np.ndarray
    adverse_excursion_targets_bps: np.ndarray


def chronological_split(
    dates: Sequence[date],
    train_fraction: float = 0.70,
    validation_fraction: float = 0.15,
    embargo_sessions: int = 2,
) -> DateSplit:
    unique_dates = tuple(sorted(set(dates)))
    if len(unique_dates) < 20:
        raise ValueError("at least 20 sessions are required")
    train_end = max(1, int(len(unique_dates) * train_fraction))
    validation_end = max(
        train_end + embargo_sessions + 1,
        int(len(unique_dates) * (train_fraction + validation_fraction)),
    )
    validation_start = train_end + embargo_sessions
    test_start = validation_end + embargo_sessions
    if test_start >= len(unique_dates):
        raise ValueError("not enough sessions after applying embargoes")
    return DateSplit(
        train_dates=unique_dates[:train_end],
        validation_dates=unique_dates[validation_start:validation_end],
        test_dates=unique_dates[test_start:],
        embargo_sessions=embargo_sessions,
    )


def _last_non_null(values: pd.Series) -> float:
    return float(values.iloc[-1])


def aggregate_to_five_minutes(frame: pd.DataFrame) -> pd.DataFrame:
    required = {"symbol", "timestamp", "open", "high", "low", "close", "volume"}
    missing = required.difference(frame.columns)
    if missing:
        raise ValueError(f"minute bars are missing columns: {sorted(missing)}")
    bars = frame.copy()
    bars["timestamp"] = pd.to_datetime(bars["timestamp"], utc=True)
    bars["timestamp_et"] = bars["timestamp"].dt.tz_convert("America/New_York")
    local_time = bars["timestamp_et"].dt.time
    bars = bars[
        (local_time >= datetime.strptime("09:30", "%H:%M").time())
        & (local_time < datetime.strptime("16:00", "%H:%M").time())
    ].copy()
    bars["session_date"] = bars["timestamp_et"].dt.date
    bars["bucket"] = bars["timestamp_et"].dt.floor("5min")
    grouped = bars.sort_values(["symbol", "timestamp"]).groupby(
        ["symbol", "session_date", "bucket"], sort=True, observed=True
    )
    result = grouped.agg(
        open=("open", "first"),
        high=("high", "max"),
        low=("low", "min"),
        close=("close", _last_non_null),
        volume=("volume", "sum"),
        source_minutes=("timestamp", "count"),
    ).reset_index()
    # A partial bar is not interchangeable with a true five-minute observation.
    return result[result["source_minutes"] == 5].reset_index(drop=True)


def build_feature_frame(five_minute_bars: pd.DataFrame) -> pd.DataFrame:
    frame = five_minute_bars.sort_values(
        ["symbol", "session_date", "bucket"]
    ).copy()
    group_keys = [frame["symbol"], frame["session_date"]]
    grouped = frame.groupby(["symbol", "session_date"], sort=False, group_keys=False)
    frame["return_1"] = grouped["close"].transform(
        lambda values: np.log(values / values.shift(1))
    )
    frame["return_3"] = grouped["close"].transform(
        lambda values: np.log(values / values.shift(3))
    )
    frame["return_6"] = grouped["close"].transform(
        lambda values: np.log(values / values.shift(6))
    )
    frame["bar_body"] = frame["close"] / frame["open"] - 1
    frame["bar_range"] = (frame["high"] - frame["low"]) / frame["close"]
    spread = (frame["high"] - frame["low"]).replace(0, np.nan)
    frame["close_location"] = (
        (frame["close"] - frame["low"]) - (frame["high"] - frame["close"])
    ) / spread
    typical = (frame["high"] + frame["low"] + frame["close"]) / 3
    cumulative_notional = (typical * frame["volume"]).groupby(group_keys).cumsum()
    cumulative_volume = frame["volume"].groupby(group_keys).cumsum()
    frame["distance_vwap"] = (
        frame["close"] / (cumulative_notional / cumulative_volume.replace(0, np.nan)) - 1
    )
    frame["realized_vol_6"] = grouped["return_1"].transform(
        lambda values: values.rolling(6, min_periods=3).std()
    )
    historical_volume_mean = grouped["volume"].transform(
        lambda values: values.rolling(20, min_periods=5).mean()
    )
    historical_volume_std = grouped["volume"].transform(
        lambda values: values.rolling(20, min_periods=5).std()
    )
    frame["volume_z_20"] = (
        frame["volume"] - historical_volume_mean
    ) / historical_volume_std.replace(0, np.nan)
    frame["relative_volume_20"] = frame["volume"] / historical_volume_mean.replace(
        0, np.nan
    )
    wide_returns = frame.pivot(index="bucket", columns="symbol", values="return_1")
    for symbol in ("SPY", "QQQ", "SOXX"):
        column = f"{symbol.lower()}_return_1"
        if symbol in wide_returns:
            frame[column] = frame["bucket"].map(wide_returns[symbol])
        else:
            frame[column] = np.nan
    minute_of_session = (
        frame["bucket"].dt.hour * 60 + frame["bucket"].dt.minute - (9 * 60 + 30)
    )
    frame["time_sin"] = np.sin(2 * np.pi * minute_of_session / 390)
    frame["time_cos"] = np.cos(2 * np.pi * minute_of_session / 390)
    return frame.replace([np.inf, -np.inf], np.nan)


def build_panels(
    feature_frame: pd.DataFrame,
    symbols: Sequence[str],
    horizons: Sequence[int],
    cost_bps: float,
) -> list[SymbolPanel]:
    panels: list[SymbolPanel] = []
    for symbol in symbols:
        values = feature_frame[feature_frame["symbol"] == symbol].copy()
        if values.empty:
            continue
        grouped = values.groupby("session_date", sort=False)
        direction_targets: list[np.ndarray] = []
        return_targets: list[np.ndarray] = []
        prior_returns: list[np.ndarray] = []
        vwap_cross_targets: list[np.ndarray] = []
        favorable_excursion_targets: list[np.ndarray] = []
        adverse_excursion_targets: list[np.ndarray] = []
        causal_drift_bps = grouped["return_1"].transform(
            lambda returns: returns.ewm(
                span=12, adjust=False, min_periods=6
            ).mean()
        ) * 10_000
        for horizon in horizons:
            future_return = grouped["close"].transform(
                lambda prices, h=horizon: (prices.shift(-h) / prices - 1) * 10_000
            )
            future_highs = pd.concat(
                [grouped["high"].shift(-step) for step in range(1, horizon + 1)],
                axis=1,
            )
            future_lows = pd.concat(
                [grouped["low"].shift(-step) for step in range(1, horizon + 1)],
                axis=1,
            )
            future_vwap_distances = pd.concat(
                [
                    grouped["distance_vwap"].shift(-step)
                    for step in range(1, horizon + 1)
                ],
                axis=1,
            )
            maximum_future_high = future_highs.max(axis=1, skipna=False)
            minimum_future_low = future_lows.min(axis=1, skipna=False)
            minimum_vwap_distance = future_vwap_distances.min(
                axis=1, skipna=False
            )
            maximum_vwap_distance = future_vwap_distances.max(
                axis=1, skipna=False
            )
            crosses_vwap = (
                ((values["distance_vwap"] > 0) & (minimum_vwap_distance <= 0))
                | (
                    (values["distance_vwap"] < 0)
                    & (maximum_vwap_distance >= 0)
                )
            ).astype(np.float32)
            return_targets.append(future_return.to_numpy(dtype=np.float32))
            direction_targets.append(
                (future_return > cost_bps).to_numpy(dtype=np.float32)
            )
            prior_returns.append(
                (causal_drift_bps * horizon).to_numpy(dtype=np.float32)
            )
            vwap_cross_targets.append(crosses_vwap.to_numpy(dtype=np.float32))
            favorable_excursion_targets.append(
                (
                    (maximum_future_high / values["close"] - 1) * 10_000
                )
                .clip(lower=0)
                .to_numpy(dtype=np.float32)
            )
            adverse_excursion_targets.append(
                (
                    (1 - minimum_future_low / values["close"]) * 10_000
                )
                .clip(lower=0)
                .to_numpy(dtype=np.float32)
            )
        panels.append(
            SymbolPanel(
                symbol=symbol,
                timestamps=values["bucket"].astype(str).to_numpy(),
                session_dates=values["session_date"].to_numpy(),
                features=values[list(FEATURE_COLUMNS)].to_numpy(dtype=np.float32),
                direction_targets=np.column_stack(direction_targets),
                return_targets_bps=np.column_stack(return_targets),
                prior_returns_bps=np.column_stack(prior_returns),
                vwap_cross_targets=np.column_stack(vwap_cross_targets),
                favorable_excursion_targets_bps=np.column_stack(
                    favorable_excursion_targets
                ),
                adverse_excursion_targets_bps=np.column_stack(
                    adverse_excursion_targets
                ),
            )
        )
    return panels


def valid_sample_indices(
    panels: Sequence[SymbolPanel],
    eligible_dates: Iterable[date],
    sequence_length: int,
) -> np.ndarray:
    date_set = set(eligible_dates)
    samples: list[tuple[int, int]] = []
    for panel_id, panel in enumerate(panels):
        for row in range(sequence_length - 1, len(panel.timestamps)):
            start = row - sequence_length + 1
            if panel.session_dates[row] not in date_set:
                continue
            if panel.session_dates[start] != panel.session_dates[row]:
                continue
            if not np.isfinite(panel.features[start : row + 1]).all():
                continue
            if not np.isfinite(panel.return_targets_bps[row]).all():
                continue
            if not np.isfinite(panel.prior_returns_bps[row]).all():
                continue
            if not np.isfinite(panel.vwap_cross_targets[row]).all():
                continue
            if not np.isfinite(
                panel.favorable_excursion_targets_bps[row]
            ).all():
                continue
            if not np.isfinite(panel.adverse_excursion_targets_bps[row]).all():
                continue
            samples.append((panel_id, row))
    return np.asarray(samples, dtype=np.int32).reshape((-1, 2))


def normalize_panels(
    panels: Sequence[SymbolPanel],
    train_dates: Iterable[date],
) -> tuple[np.ndarray, np.ndarray]:
    date_set = set(train_dates)
    training_rows = np.concatenate(
        [
            panel.features[
                np.fromiter(
                    (session_date in date_set for session_date in panel.session_dates),
                    dtype=bool,
                )
            ]
            for panel in panels
        ],
        axis=0,
    )
    means = np.nanmean(training_rows, axis=0)
    standard_deviations = np.nanstd(training_rows, axis=0)
    standard_deviations = np.where(standard_deviations < 1e-8, 1.0, standard_deviations)
    for panel in panels:
        panel.features = (panel.features - means) / standard_deviations
    return means.astype(np.float32), standard_deviations.astype(np.float32)


def load_postgres_minutes(
    database_url: str,
    symbols: Sequence[str],
    event_start: str,
    event_end: str,
    decision_cutoff: str,
) -> tuple[pd.DataFrame, list[dict[str, Any]]]:
    import psycopg

    query = """
        SELECT symbol, event_at AS timestamp, open, high, low, close, volume
        FROM market_data.equity_minute_bars_asof(
            %s::text[], %s::timestamptz, %s::timestamptz, %s::timestamptz
        )
        ORDER BY symbol, event_at
    """
    with psycopg.connect(database_url) as connection:
        with connection.cursor(name="cuda_training_market_bars") as cursor:
            cursor.itersize = 50_000
            cursor.execute(
                query, (list(symbols), event_start, event_end, decision_cutoff)
            )
            chunks: list[pd.DataFrame] = []
            while rows := cursor.fetchmany(50_000):
                chunks.append(
                    pd.DataFrame(
                        rows,
                        columns=[
                            "symbol",
                            "timestamp",
                            "open",
                            "high",
                            "low",
                            "close",
                            "volume",
                        ],
                    )
                )
        batches = [
            {
                "batch_id": row[0],
                "provider": row[1],
                "dataset": row[2],
                "captured_at": row[3].isoformat(),
                "license_scope": row[4],
                "source_file_sha256": row[5],
            }
            for row in connection.execute(
                """
                SELECT batch_id, provider, dataset, captured_at, license_scope,
                       source_file_sha256
                FROM market_data.batches
                WHERE provider = 'MASSIVE' AND dataset LIKE 'STOCKS_AGG_1M%'
                ORDER BY captured_at
                """
            )
        ]
    if not chunks:
        raise RuntimeError("PostgreSQL returned no eligible minute bars")
    return pd.concat(chunks, ignore_index=True), batches


def _source_hash(frame: pd.DataFrame, batches: Sequence[dict[str, Any]]) -> str:
    digest = hashlib.sha256()
    digest.update(
        json.dumps(list(batches), sort_keys=True, separators=(",", ":")).encode()
    )
    digest.update(str(len(frame)).encode())
    for symbol, count in frame.groupby("symbol").size().items():
        digest.update(f"{symbol}:{count}".encode())
    digest.update(str(frame["timestamp"].min()).encode())
    digest.update(str(frame["timestamp"].max()).encode())
    return digest.hexdigest()


def _git_revision(root: Path) -> str | None:
    try:
        return subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def train_challenger(
    database_url: str,
    output_dir: Path,
    symbols: Sequence[str] = DEFAULT_SYMBOLS,
    horizons: Sequence[int] = DEFAULT_HORIZONS,
    event_start: str = "2024-07-18T00:00:00Z",
    event_end: str = "2026-07-25T00:00:00Z",
    decision_cutoff: str = "2026-07-25T16:00:00Z",
    sequence_length: int = 24,
    epochs: int = 6,
    batch_size: int = 512,
    learning_rate: float = 8e-4,
    cost_bps: float = 2.0,
    seed: int = 7,
) -> dict[str, Any]:
    import torch
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import accuracy_score, brier_score_loss, roc_auc_score
    from torch import nn
    from torch.utils.data import DataLoader, Dataset

    from intraday_quant.models.causal_tcn import (
        RegimeGatedDistributionalTCN,
        student_t_negative_log_likelihood,
    )

    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is required for this challenger training entry point")
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

    minute_frame, batches = load_postgres_minutes(
        database_url, symbols, event_start, event_end, decision_cutoff
    )
    five_minute = aggregate_to_five_minutes(minute_frame)
    feature_frame = build_feature_frame(five_minute)
    panels = build_panels(feature_frame, symbols, horizons, cost_bps)
    available_symbols = tuple(panel.symbol for panel in panels)
    missing_symbols = sorted(set(symbols).difference(available_symbols))
    if missing_symbols:
        raise RuntimeError(f"symbols have no usable observations: {missing_symbols}")
    split = chronological_split(feature_frame["session_date"].tolist())
    feature_means, feature_standard_deviations = normalize_panels(
        panels, split.train_dates
    )
    sample_sets = {
        "train": valid_sample_indices(panels, split.train_dates, sequence_length),
        "validation": valid_sample_indices(
            panels, split.validation_dates, sequence_length
        ),
        "test": valid_sample_indices(panels, split.test_dates, sequence_length),
    }
    if any(len(indices) == 0 for indices in sample_sets.values()):
        raise RuntimeError(
            f"an empty causal split was produced: "
            f"{ {name: len(indices) for name, indices in sample_sets.items()} }"
        )

    class PanelDataset(Dataset):
        def __init__(self, indices: np.ndarray) -> None:
            self.indices = indices

        def __len__(self) -> int:
            return len(self.indices)

        def __getitem__(
            self, item: int
        ) -> tuple[
            torch.Tensor,
            torch.Tensor,
            torch.Tensor,
            torch.Tensor,
            torch.Tensor,
            torch.Tensor,
            torch.Tensor,
            torch.Tensor,
        ]:
            panel_id, end = self.indices[item]
            panel = panels[int(panel_id)]
            start = int(end) - sequence_length + 1
            return (
                torch.from_numpy(panel.features[start : int(end) + 1]),
                torch.tensor(int(panel_id), dtype=torch.long),
                torch.from_numpy(panel.direction_targets[int(end)]),
                torch.from_numpy(panel.return_targets_bps[int(end)] / 100.0),
                torch.from_numpy(panel.prior_returns_bps[int(end)] / 100.0),
                torch.from_numpy(panel.vwap_cross_targets[int(end)]),
                torch.from_numpy(
                    panel.favorable_excursion_targets_bps[int(end)] / 100.0
                ),
                torch.from_numpy(
                    panel.adverse_excursion_targets_bps[int(end)] / 100.0
                ),
            )

    loaders = {
        name: DataLoader(
            PanelDataset(indices),
            batch_size=batch_size,
            shuffle=name == "train",
            num_workers=0,
            pin_memory=True,
            drop_last=False,
        )
        for name, indices in sample_sets.items()
    }
    device = torch.device("cuda:0")
    model = RegimeGatedDistributionalTCN(
        feature_count=len(FEATURE_COLUMNS),
        symbol_count=len(panels),
        horizons=horizons,
    ).to(device)
    optimizer = torch.optim.AdamW(
        model.parameters(), lr=learning_rate, weight_decay=1e-4
    )
    classifier_loss = nn.BCEWithLogitsLoss()
    vwap_cross_loss = nn.BCEWithLogitsLoss()
    regression_loss = nn.SmoothL1Loss(beta=0.25)
    use_bfloat16 = bool(torch.cuda.is_bf16_supported())
    autocast_dtype = torch.bfloat16 if use_bfloat16 else torch.float16

    def run_epoch(name: str, training: bool) -> float:
        model.train(training)
        total_loss = 0.0
        total_rows = 0
        context = torch.enable_grad() if training else torch.no_grad()
        with context:
            for (
                sequences,
                symbol_ids,
                directions,
                returns,
                prior_returns,
                vwap_crosses,
                favorable_excursions,
                adverse_excursions,
            ) in loaders[name]:
                sequences = sequences.to(device, non_blocking=True)
                symbol_ids = symbol_ids.to(device, non_blocking=True)
                directions = directions.to(device, non_blocking=True)
                returns = returns.to(device, non_blocking=True)
                prior_returns = prior_returns.to(device, non_blocking=True)
                vwap_crosses = vwap_crosses.to(device, non_blocking=True)
                favorable_excursions = favorable_excursions.to(
                    device, non_blocking=True
                )
                adverse_excursions = adverse_excursions.to(
                    device, non_blocking=True
                )
                if training:
                    optimizer.zero_grad(set_to_none=True)
                with torch.autocast(
                    device_type="cuda", dtype=autocast_dtype, enabled=True
                ):
                    output = model(sequences, symbol_ids, prior_returns)
                    direction_objective = classifier_loss(
                        output.direction_logits, directions
                    )
                    distribution_objective = student_t_negative_log_likelihood(
                        returns.clamp(-5.0, 5.0),
                        output.return_location,
                        output.return_scale,
                    )
                    vwap_objective = vwap_cross_loss(
                        output.vwap_cross_logits, vwap_crosses
                    )
                    excursion_objective = regression_loss(
                        output.favorable_excursion,
                        favorable_excursions.clamp(0.0, 10.0),
                    ) + regression_loss(
                        output.adverse_excursion,
                        adverse_excursions.clamp(0.0, 10.0),
                    )
                    mean_expert_weight = output.expert_weights.mean(dim=0)
                    balance_objective = (
                        mean_expert_weight - (1.0 / model.expert_count)
                    ).square().mean()
                    gate_entropy = -(
                        output.expert_weights
                        * output.expert_weights.clamp_min(1.0e-8).log()
                    ).sum(dim=1).mean()
                    loss = (
                        direction_objective
                        + 0.35 * distribution_objective
                        + 0.15 * vwap_objective
                        + 0.05 * excursion_objective
                        + 0.10 * balance_objective
                        + 0.01 * gate_entropy
                    )
                if training:
                    loss.backward()
                    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                    optimizer.step()
                total_loss += float(loss.detach()) * len(sequences)
                total_rows += len(sequences)
        return total_loss / total_rows

    best_state: dict[str, Any] | None = None
    best_validation_loss = math.inf
    epoch_history: list[dict[str, float]] = []
    for epoch in range(1, epochs + 1):
        train_loss = run_epoch("train", True)
        validation_loss = run_epoch("validation", False)
        epoch_result = {
            "epoch": epoch,
            "train_loss": train_loss,
            "validation_loss": validation_loss,
        }
        epoch_history.append(epoch_result)
        print(json.dumps({"training_progress": epoch_result}), flush=True)
        if validation_loss < best_validation_loss:
            best_validation_loss = validation_loss
            best_state = {
                key: value.detach().cpu().clone()
                for key, value in model.state_dict().items()
            }
    if best_state is None:
        raise RuntimeError("training did not produce a checkpoint")
    model.load_state_dict(best_state)

    def predict(name: str) -> dict[str, np.ndarray]:
        model.eval()
        outputs: dict[str, list[np.ndarray]] = {
            "direction_logits": [],
            "return_location_bps": [],
            "return_scale_bps": [],
            "vwap_cross_logits": [],
            "favorable_excursion_bps": [],
            "adverse_excursion_bps": [],
            "expert_weights": [],
            "direction_targets": [],
            "return_targets_bps": [],
            "vwap_cross_targets": [],
            "favorable_excursion_targets_bps": [],
            "adverse_excursion_targets_bps": [],
            "symbol_ids": [],
        }
        with torch.no_grad():
            for (
                sequences,
                symbol_ids,
                directions,
                returns,
                prior_returns,
                vwap_crosses,
                favorable_excursions,
                adverse_excursions,
            ) in loaders[name]:
                prediction = model(
                    sequences.to(device, non_blocking=True),
                    symbol_ids.to(device, non_blocking=True),
                    prior_returns.to(device, non_blocking=True),
                )
                outputs["direction_logits"].append(
                    prediction.direction_logits.float().cpu().numpy()
                )
                outputs["return_location_bps"].append(
                    prediction.return_location.float().cpu().numpy() * 100
                )
                outputs["return_scale_bps"].append(
                    prediction.return_scale.float().cpu().numpy() * 100
                )
                outputs["vwap_cross_logits"].append(
                    prediction.vwap_cross_logits.float().cpu().numpy()
                )
                outputs["favorable_excursion_bps"].append(
                    prediction.favorable_excursion.float().cpu().numpy() * 100
                )
                outputs["adverse_excursion_bps"].append(
                    prediction.adverse_excursion.float().cpu().numpy() * 100
                )
                outputs["expert_weights"].append(
                    prediction.expert_weights.float().cpu().numpy()
                )
                outputs["direction_targets"].append(directions.numpy())
                outputs["return_targets_bps"].append(returns.numpy() * 100)
                outputs["vwap_cross_targets"].append(vwap_crosses.numpy())
                outputs["favorable_excursion_targets_bps"].append(
                    favorable_excursions.numpy() * 100
                )
                outputs["adverse_excursion_targets_bps"].append(
                    adverse_excursions.numpy() * 100
                )
                outputs["symbol_ids"].append(symbol_ids.numpy())
        return {key: np.concatenate(values) for key, values in outputs.items()}

    validation = predict("validation")
    test = predict("test")
    calibration: dict[str, list[dict[str, float | str]]] = {
        "direction": [],
        "vwap_cross": [],
    }
    test_probabilities = np.zeros_like(
        test["direction_logits"], dtype=np.float64
    )
    test_vwap_probabilities = np.zeros_like(
        test["vwap_cross_logits"], dtype=np.float64
    )
    metrics: dict[str, dict[str, Any]] = {}

    def calibrate(
        validation_logits: np.ndarray,
        validation_labels: np.ndarray,
        test_logits: np.ndarray,
    ) -> tuple[np.ndarray, dict[str, float | str]]:
        unique_labels = np.unique(validation_labels)
        if len(unique_labels) < 2:
            prevalence = float(np.clip(validation_labels.mean(), 0.01, 0.99))
            return (
                np.full_like(test_logits, prevalence, dtype=np.float64),
                {
                    "method": "validation_prevalence",
                    "coefficient": 0.0,
                    "intercept": float(np.log(prevalence / (1 - prevalence))),
                },
            )
        calibrator = LogisticRegression(random_state=seed)
        calibrator.fit(validation_logits.reshape(-1, 1), validation_labels)
        probability = calibrator.predict_proba(test_logits.reshape(-1, 1))[:, 1]
        return (
            np.clip(probability, 0.01, 0.99),
            {
                "method": "platt_logistic",
                "coefficient": float(calibrator.coef_[0, 0]),
                "intercept": float(calibrator.intercept_[0]),
            },
        )

    def calculate_metrics(
        actual_direction: np.ndarray,
        probability: np.ndarray,
        actual_return: np.ndarray,
        predicted_return: np.ndarray,
        predicted_scale: np.ndarray,
        actual_vwap_cross: np.ndarray,
        vwap_probability: np.ndarray,
        actual_favorable_excursion: np.ndarray,
        predicted_favorable_excursion: np.ndarray,
        actual_adverse_excursion: np.ndarray,
        predicted_adverse_excursion: np.ndarray,
        baseline_prevalence: float,
        baseline_vwap_prevalence: float,
    ) -> dict[str, float | int | None]:
        from scipy import stats

        try:
            auc = float(roc_auc_score(actual_direction, probability))
        except ValueError:
            auc = None
        try:
            vwap_auc = float(
                roc_auc_score(actual_vwap_cross, vwap_probability)
            )
        except ValueError:
            vwap_auc = None
        return_ic = (
            float(np.corrcoef(actual_return, predicted_return)[0, 1])
            if np.std(actual_return) > 0 and np.std(predicted_return) > 0
            else None
        )
        baseline_probability = np.full_like(
            actual_direction, baseline_prevalence, dtype=float
        )
        brier = float(brier_score_loss(actual_direction, probability))
        baseline_brier = float(
            brier_score_loss(actual_direction, baseline_probability)
        )
        baseline_direction = np.full_like(
            actual_direction, baseline_prevalence >= 0.5
        )
        baseline_vwap_probability = np.full_like(
            actual_vwap_cross, baseline_vwap_prevalence, dtype=float
        )
        safe_scale = np.clip(predicted_scale, 1.0e-6, None)
        standardized = (actual_return - predicted_return) / safe_scale
        student_t_nll = float(
            -np.mean(stats.t.logpdf(standardized, df=5) - np.log(safe_scale))
        )
        interval_multiplier = float(stats.t.ppf(0.9, df=5))
        interval_low = predicted_return - interval_multiplier * safe_scale
        interval_high = predicted_return + interval_multiplier * safe_scale
        return {
            "test_rows": int(len(actual_direction)),
            "positive_rate": float(actual_direction.mean()),
            "accuracy": float(
                accuracy_score(actual_direction, probability >= 0.5)
            ),
            "validation_prevalence_baseline_accuracy": float(
                accuracy_score(actual_direction, baseline_direction)
            ),
            "roc_auc": auc,
            "brier": brier,
            "validation_prevalence_baseline_brier": baseline_brier,
            "brier_improvement_over_baseline": baseline_brier - brier,
            "return_mae_bps": float(
                np.mean(np.abs(actual_return - predicted_return))
            ),
            "return_information_coefficient": return_ic,
            "return_student_t_nll": student_t_nll,
            "return_scale_median_bps": float(np.median(safe_scale)),
            "return_80pct_interval_coverage": float(
                np.mean(
                    (actual_return >= interval_low)
                    & (actual_return <= interval_high)
                )
            ),
            "vwap_cross_rate": float(actual_vwap_cross.mean()),
            "vwap_cross_roc_auc": vwap_auc,
            "vwap_cross_brier": float(
                brier_score_loss(actual_vwap_cross, vwap_probability)
            ),
            "vwap_cross_baseline_brier": float(
                brier_score_loss(
                    actual_vwap_cross, baseline_vwap_probability
                )
            ),
            "favorable_excursion_mae_bps": float(
                np.mean(
                    np.abs(
                        actual_favorable_excursion
                        - predicted_favorable_excursion
                    )
                )
            ),
            "adverse_excursion_mae_bps": float(
                np.mean(
                    np.abs(
                        actual_adverse_excursion
                        - predicted_adverse_excursion
                    )
                )
            ),
        }

    for index, horizon in enumerate(horizons):
        probability, direction_calibration = calibrate(
            validation["direction_logits"][:, index],
            validation["direction_targets"][:, index],
            test["direction_logits"][:, index],
        )
        test_probabilities[:, index] = probability
        calibration["direction"].append(direction_calibration)
        vwap_probability, vwap_calibration = calibrate(
            validation["vwap_cross_logits"][:, index],
            validation["vwap_cross_targets"][:, index],
            test["vwap_cross_logits"][:, index],
        )
        test_vwap_probabilities[:, index] = vwap_probability
        calibration["vwap_cross"].append(vwap_calibration)

        actual_direction = test["direction_targets"][:, index]
        actual_return = test["return_targets_bps"][:, index]
        predicted_return = test["return_location_bps"][:, index]
        predicted_scale = test["return_scale_bps"][:, index]
        actual_vwap_cross = test["vwap_cross_targets"][:, index]
        actual_favorable = test["favorable_excursion_targets_bps"][:, index]
        predicted_favorable = test["favorable_excursion_bps"][:, index]
        actual_adverse = test["adverse_excursion_targets_bps"][:, index]
        predicted_adverse = test["adverse_excursion_bps"][:, index]
        prevalence = float(
            validation["direction_targets"][:, index].mean()
        )
        vwap_prevalence = float(
            validation["vwap_cross_targets"][:, index].mean()
        )
        horizon_metrics: dict[str, Any] = calculate_metrics(
            actual_direction,
            probability,
            actual_return,
            predicted_return,
            predicted_scale,
            actual_vwap_cross,
            vwap_probability,
            actual_favorable,
            predicted_favorable,
            actual_adverse,
            predicted_adverse,
            prevalence,
            vwap_prevalence,
        )
        horizon_metrics["mean_expert_weights"] = (
            test["expert_weights"].mean(axis=0).tolist()
        )
        horizon_metrics["by_symbol"] = {}
        for symbol_id, symbol in enumerate(available_symbols):
            mask = test["symbol_ids"] == symbol_id
            if not mask.any():
                continue
            horizon_metrics["by_symbol"][symbol] = calculate_metrics(
                actual_direction[mask],
                probability[mask],
                actual_return[mask],
                predicted_return[mask],
                predicted_scale[mask],
                actual_vwap_cross[mask],
                vwap_probability[mask],
                actual_favorable[mask],
                predicted_favorable[mask],
                actual_adverse[mask],
                predicted_adverse[mask],
                prevalence,
                vwap_prevalence,
            )
        metrics[f"{int(horizon) * 5}m"] = horizon_metrics

    output_dir.mkdir(parents=True, exist_ok=True)
    feature_schema_hash = hashlib.sha256(
        json.dumps(FEATURE_COLUMNS, separators=(",", ":")).encode()
    ).hexdigest()
    data_hash = _source_hash(minute_frame, batches)
    checkpoint_payload = {
        "model_state_dict": best_state,
        "feature_columns": FEATURE_COLUMNS,
        "symbols": available_symbols,
        "horizons_five_minute_bars": tuple(horizons),
        "sequence_length": sequence_length,
        "feature_means": torch.from_numpy(feature_means.copy()),
        "feature_standard_deviations": torch.from_numpy(
            feature_standard_deviations.copy()
        ),
        "calibration": calibration,
        "model_class": "RegimeGatedDistributionalTCN",
        "model_kwargs": {
            "feature_count": model.feature_count,
            "symbol_count": model.symbol_count,
            "horizons": model.horizons,
            "channels": model.channels,
            "embedding_size": model.embedding_size,
            "expert_count": model.expert_count,
            "attention_heads": model.attention_heads,
            "dropout": model.dropout_rate,
            "minimum_scale": model.minimum_scale,
        },
        "return_distribution": {
            "family": "student_t_moment_matched_expert_mixture",
            "degrees_of_freedom": 5.0,
            "unit": "return_bps_divided_by_100",
        },
        "return_prior": {
            "family": "causal_ewma_drift",
            "combination": "expert_horizon_specific_tanh_shrinkage_plus_residual",
        },
        "regime_gate": {
            "training_mode": "latent_balanced_mixture",
            "production_override_supported": True,
            "production_override_requirement": (
                "filtered point-in-time probabilities from a separately "
                "validated Rust regime artifact"
            ),
        },
    }
    temporary_checkpoint = output_dir / "challenger.tmp.pt"
    torch.save(checkpoint_payload, temporary_checkpoint)
    checkpoint_sha256 = hashlib.sha256(temporary_checkpoint.read_bytes()).hexdigest()
    checkpoint_path = (
        output_dir / f"regime-gated-tcn-{checkpoint_sha256[:16]}.pt"
    )
    temporary_checkpoint.replace(checkpoint_path)
    repository_root = Path(__file__).resolve().parents[4]
    manifest = {
        "artifact_status": "CANDIDATE_NOT_PROMOTED",
        "automatic_execution": False,
        "research_scope": "RETROSPECTIVE_RESEARCH_ONLY",
        "license_scope": "RESEARCH_ONLY",
        "created_at": datetime.now(UTC).isoformat(),
        "model": {
            "family": "regime_gated_multi_expert_distributional_tcn",
            "version": "cuda-challenger-v2",
            "checkpoint": checkpoint_path.name,
            "checkpoint_sha256": checkpoint_sha256,
            "feature_schema_sha256": feature_schema_hash,
            "parameter_count": sum(parameter.numel() for parameter in model.parameters()),
            "expert_count": model.expert_count,
            "gate": "latent_balanced_with_validated_external_override",
            "temporal_pooling": "causal_last_query_attention",
            "distribution": {
                "family": "student_t",
                "degrees_of_freedom": 5.0,
                "mixture_reduction": "moment_matched",
            },
            "return_prior_combination": (
                "expert_horizon_specific_tanh_shrinkage_plus_residual"
            ),
        },
        "universe": {
            "requested": list(symbols),
            "trained": list(available_symbols),
            "display_mapping": {"SPX": "SPY_PRICE_VOLUME_VWAP_PROXY"},
        },
        "forecast_horizons_minutes": [int(value) * 5 for value in horizons],
        "label": {
            "direction": f"future underlying return > {cost_bps} bps",
            "return": "future underlying close-to-close return in basis points",
            "return_prior": (
                "causal 12-observation EWMA log-return drift multiplied by horizon"
            ),
            "vwap_cross": (
                "session-causal VWAP residual changes sign at least once "
                "inside the forecast horizon"
            ),
            "favorable_excursion": (
                "maximum future high relative to decision close in basis points"
            ),
            "adverse_excursion": (
                "maximum future downside from decision close in basis points"
            ),
            "not_an_option_pnl_label": True,
        },
        "data": {
            "provider": "MASSIVE",
            "dataset": "STOCKS_AGG_1M_BACKFILL",
            "observation_start": str(minute_frame["timestamp"].min()),
            "observation_end": str(minute_frame["timestamp"].max()),
            "decision_cutoff": decision_cutoff,
            "minute_rows": int(len(minute_frame)),
            "five_minute_rows": int(len(five_minute)),
            "source_hash": data_hash,
            "source_batches": batches,
            "availability_caveat": (
                "The archive was captured after the historical events. This artifact "
                "may test temporal feature causality but is not an untouched live trial."
            ),
        },
        "split": {
            "method": "chronological_sessions_with_purge_embargo_never_shuffled",
            "embargo_sessions": split.embargo_sessions,
            "train": [str(split.train_dates[0]), str(split.train_dates[-1])],
            "validation": [
                str(split.validation_dates[0]),
                str(split.validation_dates[-1]),
            ],
            "test": [str(split.test_dates[0]), str(split.test_dates[-1])],
            "sample_counts": {
                name: int(len(indices)) for name, indices in sample_sets.items()
            },
            "normalization_fit": "training rows only",
            "probability_calibration_fit": (
                "validation logits only for direction and VWAP-cross tasks"
            ),
        },
        "training": {
            "seed": seed,
            "epochs": epochs,
            "batch_size": batch_size,
            "learning_rate": learning_rate,
            "sequence_length_five_minute_bars": sequence_length,
            "epoch_history": epoch_history,
            "best_validation_loss": best_validation_loss,
            "device": torch.cuda.get_device_name(device),
            "cuda_version": torch.version.cuda,
            "torch_version": torch.__version__,
            "mixed_precision": "bfloat16" if use_bfloat16 else "float16",
            "objective": {
                "direction_bce_weight": 1.0,
                "student_t_nll_weight": 0.35,
                "vwap_cross_bce_weight": 0.15,
                "excursion_smooth_l1_weight": 0.05,
                "expert_balance_weight": 0.10,
                "gate_entropy_weight": 0.01,
            },
        },
        "untouched_test_metrics": metrics,
        "promotion_blockers": [
            "No forward live shadow evaluation",
            "No licensed realtime equity feed",
            "No complete point-in-time option NBBO/OI archive",
            "No transaction-cost validation against executable quotes",
            "No probability stability evidence across multiple walk-forward folds",
            "No verified Rust runtime for this immutable neural artifact",
            "Latent gate is not yet aligned to a promoted Rust regime artifact",
        ],
        "git_revision": _git_revision(repository_root),
    }
    manifest_bytes = json.dumps(
        manifest, indent=2, sort_keys=True, allow_nan=False
    ).encode()
    manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
    manifest_path = output_dir / f"manifest-{manifest_sha256[:16]}.json"
    manifest_path.write_bytes(manifest_bytes)
    return {
        "status": "CANDIDATE_NOT_PROMOTED",
        "checkpoint": str(checkpoint_path),
        "manifest": str(manifest_path),
        "metrics": metrics,
        "sample_counts": manifest["split"]["sample_counts"],
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Train the research-only AXIO7 causal TCN challenger on CUDA."
    )
    parser.add_argument(
        "--database-url-env", default="MARKET_DATABASE_URL", help="DSN env var name"
    )
    parser.add_argument(
        "--output-dir", type=Path, default=Path("data/models/cuda_challenger")
    )
    parser.add_argument("--symbols", nargs="+", default=list(DEFAULT_SYMBOLS))
    parser.add_argument("--epochs", type=int, default=6)
    parser.add_argument("--batch-size", type=int, default=512)
    parser.add_argument("--sequence-length", type=int, default=24)
    parser.add_argument("--event-start", default="2024-07-18T00:00:00Z")
    parser.add_argument("--event-end", default="2026-07-25T00:00:00Z")
    parser.add_argument("--decision-cutoff", default="2026-07-25T16:00:00Z")
    return parser


def main() -> int:
    arguments = _parser().parse_args()
    database_url = os.environ.get(arguments.database_url_env)
    if not database_url:
        raise SystemExit(f"{arguments.database_url_env} is not configured")
    result = train_challenger(
        database_url=database_url,
        output_dir=arguments.output_dir,
        symbols=tuple(symbol.upper() for symbol in arguments.symbols),
        epochs=arguments.epochs,
        batch_size=arguments.batch_size,
        sequence_length=arguments.sequence_length,
        event_start=arguments.event_start,
        event_end=arguments.event_end,
        decision_cutoff=arguments.decision_cutoff,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
