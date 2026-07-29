from __future__ import annotations

import io
from datetime import date, timedelta

import numpy as np
import pandas as pd
import pytest

from intraday_quant.training.cuda_challenger import (
    FEATURE_COLUMNS,
    SymbolPanel,
    _source_hash,
    build_feature_frame,
    chronological_split,
    valid_sample_indices,
)


def test_chronological_split_has_session_embargoes() -> None:
    dates = [date(2026, 1, 1) + timedelta(days=index) for index in range(100)]
    split = chronological_split(dates, embargo_sessions=2)
    assert split.train_dates[-1] < split.validation_dates[0]
    assert split.validation_dates[-1] < split.test_dates[0]
    assert (split.validation_dates[0] - split.train_dates[-1]).days == 3
    assert (split.test_dates[0] - split.validation_dates[-1]).days == 3


def test_sequence_index_never_crosses_sessions() -> None:
    first = date(2026, 7, 20)
    second = date(2026, 7, 21)
    features = np.ones((8, len(FEATURE_COLUMNS)), dtype=np.float32)
    panel = SymbolPanel(
        symbol="SPY",
        timestamps=np.asarray([str(index) for index in range(8)]),
        session_dates=np.asarray([first] * 4 + [second] * 4),
        features=features,
        direction_targets=np.ones((8, 4), dtype=np.float32),
        return_targets_bps=np.ones((8, 4), dtype=np.float32),
        prior_returns_bps=np.ones((8, 4), dtype=np.float32),
        vwap_cross_targets=np.ones((8, 4), dtype=np.float32),
        favorable_excursion_targets_bps=np.ones((8, 4), dtype=np.float32),
        adverse_excursion_targets_bps=np.ones((8, 4), dtype=np.float32),
    )
    indices = valid_sample_indices([panel], [first, second], sequence_length=3)
    assert indices[:, 1].tolist() == [2, 3, 6, 7]


def test_feature_prefix_does_not_change_when_future_prices_change() -> None:
    buckets = pd.date_range(
        "2026-07-20 09:30", periods=20, freq="5min", tz="America/New_York"
    )
    bars = pd.DataFrame(
        {
            "symbol": "SPY",
            "session_date": date(2026, 7, 20),
            "bucket": buckets,
            "open": np.linspace(100, 101, 20),
            "high": np.linspace(100.1, 101.1, 20),
            "low": np.linspace(99.9, 100.9, 20),
            "close": np.linspace(100.05, 101.05, 20),
            "volume": np.linspace(1_000, 2_000, 20),
            "source_minutes": 5,
        }
    )
    baseline = build_feature_frame(bars)
    changed = bars.copy()
    changed.loc[changed.index >= 15, ["open", "high", "low", "close"]] *= 4
    recomputed = build_feature_frame(changed)
    pd.testing.assert_frame_equal(
        baseline.loc[:14, list(FEATURE_COLUMNS)],
        recomputed.loc[:14, list(FEATURE_COLUMNS)],
    )


def test_source_hash_binds_causal_market_values_not_only_metadata() -> None:
    timestamps = pd.date_range("2026-07-20 13:30", periods=2, freq="1min", tz="UTC")
    frame = pd.DataFrame(
        {
            "symbol": ["SPY", "SPY"],
            "timestamp": timestamps,
            "open": [100.0, 100.5],
            "high": [100.75, 101.0],
            "low": [99.75, 100.25],
            "close": [100.5, 100.75],
            "volume": [1_000, 1_100],
        }
    )
    batches = [
        {
            "batch_id": "batch-1",
            "provider": "MASSIVE",
            "source_file_sha256": "a" * 64,
        }
    ]

    original = _source_hash(frame, batches)
    reordered = _source_hash(frame.iloc[::-1], batches)
    changed = frame.copy()
    changed.loc[1, "close"] = 100.80

    assert reordered == original
    assert _source_hash(changed, batches) != original


def test_causal_convolution_prefix_is_future_invariant() -> None:
    torch = pytest.importorskip("torch")
    from intraday_quant.models.causal_tcn import CausalConv1d

    torch.manual_seed(7)
    layer = CausalConv1d(3, 5, kernel_size=3, dilation=2)
    baseline = torch.randn(2, 3, 12)
    changed = baseline.clone()
    changed[:, :, 8:] += 100
    with torch.no_grad():
        first = layer(baseline)
        second = layer(changed)
    assert torch.equal(first[:, :, :8], second[:, :, :8])


def test_regime_gated_distributional_model_contract() -> None:
    torch = pytest.importorskip("torch")
    from intraday_quant.models.causal_tcn import RegimeGatedDistributionalTCN

    torch.manual_seed(11)
    model = RegimeGatedDistributionalTCN(
        feature_count=5,
        symbol_count=3,
        horizons=(1, 3, 6, 12),
        channels=16,
        embedding_size=4,
        expert_count=4,
        attention_heads=4,
        dropout=0.0,
    ).eval()
    sequences = torch.randn(6, 24, 5)
    symbol_ids = torch.tensor([0, 1, 2, 0, 1, 2])
    prior_returns = torch.randn(6, 4) * 0.01
    with torch.no_grad():
        output = model(sequences, symbol_ids, prior_returns)

    assert output.direction_logits.shape == (6, 4)
    assert output.return_location.shape == (6, 4)
    assert output.return_scale.shape == (6, 4)
    assert output.vwap_cross_logits.shape == (6, 4)
    assert output.favorable_excursion.shape == (6, 4)
    assert output.adverse_excursion.shape == (6, 4)
    assert output.expert_weights.shape == (6, 4)
    assert torch.allclose(output.expert_weights.sum(dim=1), torch.ones(6))
    assert torch.all(output.return_scale > 0)
    assert torch.all(output.favorable_excursion >= 0)
    assert torch.all(output.adverse_excursion >= 0)


def test_validated_regime_probabilities_override_latent_gate() -> None:
    torch = pytest.importorskip("torch")
    from intraday_quant.models.causal_tcn import RegimeGatedDistributionalTCN

    model = RegimeGatedDistributionalTCN(
        feature_count=3,
        symbol_count=1,
        horizons=(1, 3),
        channels=8,
        embedding_size=2,
        expert_count=2,
        attention_heads=2,
        dropout=0.0,
    ).eval()
    external_regimes = torch.tensor([[4.0, 1.0], [1.0, 3.0]])
    with torch.no_grad():
        output = model(
            torch.randn(2, 12, 3),
            torch.zeros(2, dtype=torch.long),
            prior_returns=torch.zeros(2, 2),
            regime_probabilities=external_regimes,
        )
    expected = external_regimes / external_regimes.sum(dim=1, keepdim=True)
    assert torch.allclose(output.expert_weights, expected)


def test_student_t_loss_is_finite_and_prefers_correct_location() -> None:
    torch = pytest.importorskip("torch")
    from intraday_quant.models.causal_tcn import (
        student_t_negative_log_likelihood,
    )

    target = torch.tensor([[0.2, -0.1], [0.05, 0.4]])
    scale = torch.full_like(target, 0.2)
    correct = student_t_negative_log_likelihood(target, target, scale)
    shifted = student_t_negative_log_likelihood(target, target + 1.0, scale)
    assert torch.isfinite(correct)
    assert correct < shifted


def test_regime_gated_checkpoint_round_trip_is_deterministic() -> None:
    torch = pytest.importorskip("torch")
    from intraday_quant.models.causal_tcn import RegimeGatedDistributionalTCN

    kwargs = {
        "feature_count": 3,
        "symbol_count": 2,
        "horizons": (1, 3),
        "channels": 8,
        "embedding_size": 2,
        "expert_count": 2,
        "attention_heads": 2,
        "dropout": 0.0,
    }
    torch.manual_seed(13)
    source = RegimeGatedDistributionalTCN(**kwargs).eval()
    sequences = torch.randn(3, 12, 3)
    symbol_ids = torch.tensor([0, 1, 0])
    prior_returns = torch.randn(3, 2) * 0.01
    with torch.no_grad():
        expected = source(sequences, symbol_ids, prior_returns)

    checkpoint = io.BytesIO()
    torch.save(
        {
            "model_class": "RegimeGatedDistributionalTCN",
            "model_kwargs": kwargs,
            "model_state_dict": source.state_dict(),
        },
        checkpoint,
    )
    checkpoint.seek(0)
    payload = torch.load(checkpoint, weights_only=True)
    restored = RegimeGatedDistributionalTCN(**payload["model_kwargs"]).eval()
    restored.load_state_dict(payload["model_state_dict"], strict=True)
    with torch.no_grad():
        actual = restored(sequences, symbol_ids, prior_returns)

    for expected_tensor, actual_tensor in zip(expected, actual, strict=True):
        assert torch.equal(expected_tensor, actual_tensor)
