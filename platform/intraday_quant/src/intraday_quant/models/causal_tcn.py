from __future__ import annotations

from collections.abc import Sequence
from typing import NamedTuple

import torch
from torch import nn
from torch.nn import functional as F


class CausalConv1d(nn.Module):
    """One-dimensional convolution with explicit left-only padding."""

    def __init__(
        self,
        in_channels: int,
        out_channels: int,
        kernel_size: int,
        dilation: int = 1,
    ) -> None:
        super().__init__()
        if kernel_size < 1 or dilation < 1:
            raise ValueError("kernel_size and dilation must be positive")
        self.left_padding = (kernel_size - 1) * dilation
        self.convolution = nn.Conv1d(
            in_channels,
            out_channels,
            kernel_size=kernel_size,
            dilation=dilation,
        )

    def forward(self, values: torch.Tensor) -> torch.Tensor:
        return self.convolution(F.pad(values, (self.left_padding, 0)))


class CausalResidualBlock(nn.Module):
    def __init__(
        self,
        in_channels: int,
        out_channels: int,
        dilation: int,
        dropout: float,
    ) -> None:
        super().__init__()
        self.first = CausalConv1d(in_channels, out_channels, 3, dilation)
        self.second = CausalConv1d(out_channels, out_channels, 3, dilation)
        self.dropout = nn.Dropout(dropout)
        self.activation = nn.GELU()
        self.residual = (
            nn.Identity()
            if in_channels == out_channels
            else nn.Conv1d(in_channels, out_channels, kernel_size=1)
        )

    def forward(self, values: torch.Tensor) -> torch.Tensor:
        residual = self.residual(values)
        hidden = self.dropout(self.activation(self.first(values)))
        hidden = self.dropout(self.activation(self.second(hidden)))
        return self.activation(hidden + residual)


class MultiHorizonCausalTCN(nn.Module):
    """Shared causal encoder with symbol embeddings and four forecast heads."""

    def __init__(
        self,
        feature_count: int,
        symbol_count: int,
        horizons: Sequence[int],
        channels: int = 48,
        embedding_size: int = 8,
        dropout: float = 0.1,
    ) -> None:
        super().__init__()
        if feature_count < 1 or symbol_count < 1 or not horizons:
            raise ValueError("feature_count, symbol_count, and horizons are required")
        self.horizons = tuple(int(horizon) for horizon in horizons)
        blocks: list[nn.Module] = []
        input_channels = feature_count
        for dilation in (1, 2, 4, 8):
            blocks.append(
                CausalResidualBlock(input_channels, channels, dilation, dropout)
            )
            input_channels = channels
        self.encoder = nn.Sequential(*blocks)
        self.symbol_embedding = nn.Embedding(symbol_count, embedding_size)
        self.fusion = nn.Sequential(
            nn.Linear(channels + embedding_size, channels),
            nn.GELU(),
            nn.Dropout(dropout),
        )
        self.direction_head = nn.Linear(channels, len(self.horizons))
        self.return_head = nn.Linear(channels, len(self.horizons))

    def forward(
        self, sequences: torch.Tensor, symbol_ids: torch.Tensor
    ) -> tuple[torch.Tensor, torch.Tensor]:
        if sequences.ndim != 3:
            raise ValueError("sequences must have shape [batch, time, features]")
        encoded = self.encoder(sequences.transpose(1, 2))[:, :, -1]
        fused = self.fusion(
            torch.cat((encoded, self.symbol_embedding(symbol_ids)), dim=1)
        )
        return self.direction_head(fused), self.return_head(fused)


class RegimeGatedForecast(NamedTuple):
    """Tensor-only output contract suitable for immutable artifact export."""

    direction_logits: torch.Tensor
    return_location: torch.Tensor
    return_scale: torch.Tensor
    vwap_cross_logits: torch.Tensor
    favorable_excursion: torch.Tensor
    adverse_excursion: torch.Tensor
    regime_logits: torch.Tensor
    expert_weights: torch.Tensor


class CausalAttentionPool(nn.Module):
    """Pool an observed causal sequence without introducing future positions."""

    def __init__(self, channels: int, heads: int, dropout: float) -> None:
        super().__init__()
        if channels % heads:
            raise ValueError("channels must be divisible by attention heads")
        self.attention = nn.MultiheadAttention(
            channels,
            heads,
            dropout=dropout,
            batch_first=True,
        )
        self.normalization = nn.LayerNorm(channels)

    def forward(self, encoded_sequence: torch.Tensor) -> torch.Tensor:
        sequence = encoded_sequence.transpose(1, 2)
        last_observation = sequence[:, -1:, :]
        attended, _ = self.attention(
            last_observation,
            sequence,
            sequence,
            need_weights=False,
        )
        return self.normalization(last_observation + attended).squeeze(1)


class RegimeGatedDistributionalTCN(nn.Module):
    """Small mixture-of-experts model for causal intraday distribution forecasts.

    The latent gate is a research challenger. Production may provide separately
    validated filtered regime probabilities through ``regime_probabilities``.
    A deterministic causal drift/diffusion prior can be supplied through
    ``prior_returns``; every expert/horizon learns a bounded shrinkage weight
    for that prior plus a residual location.
    """

    OUTPUTS_PER_HORIZON = 6

    def __init__(
        self,
        feature_count: int,
        symbol_count: int,
        horizons: Sequence[int],
        channels: int = 64,
        embedding_size: int = 12,
        expert_count: int = 4,
        attention_heads: int = 4,
        dropout: float = 0.1,
        minimum_scale: float = 0.01,
    ) -> None:
        super().__init__()
        if feature_count < 1 or symbol_count < 1 or not horizons:
            raise ValueError("feature_count, symbol_count, and horizons are required")
        if expert_count < 2:
            raise ValueError("at least two regime experts are required")
        if minimum_scale <= 0:
            raise ValueError("minimum_scale must be positive")
        self.feature_count = feature_count
        self.symbol_count = symbol_count
        self.horizons = tuple(int(horizon) for horizon in horizons)
        self.channels = channels
        self.embedding_size = embedding_size
        self.expert_count = expert_count
        self.attention_heads = attention_heads
        self.dropout_rate = dropout
        self.minimum_scale = minimum_scale

        blocks: list[nn.Module] = []
        input_channels = feature_count
        for dilation in (1, 2, 4, 8, 16):
            blocks.append(
                CausalResidualBlock(input_channels, channels, dilation, dropout)
            )
            input_channels = channels
        self.encoder = nn.Sequential(*blocks)
        self.temporal_pool = CausalAttentionPool(channels, attention_heads, dropout)
        self.symbol_embedding = nn.Embedding(symbol_count, embedding_size)
        self.fusion = nn.Sequential(
            nn.Linear(channels + embedding_size, channels),
            nn.LayerNorm(channels),
            nn.GELU(),
            nn.Dropout(dropout),
        )
        self.regime_gate = nn.Linear(channels, expert_count)
        self.prior_weights = nn.Parameter(
            torch.full((expert_count, len(self.horizons)), 0.1)
        )
        output_size = len(self.horizons) * self.OUTPUTS_PER_HORIZON
        self.experts = nn.ModuleList(
            [
                nn.Sequential(
                    nn.Linear(channels, channels),
                    nn.GELU(),
                    nn.Dropout(dropout),
                    nn.Linear(channels, output_size),
                )
                for _ in range(expert_count)
            ]
        )

    def _validated_prior(
        self, fused: torch.Tensor, prior_returns: torch.Tensor | None
    ) -> torch.Tensor:
        expected_shape = (fused.shape[0], len(self.horizons))
        if prior_returns is None:
            return fused.new_zeros(expected_shape)
        if tuple(prior_returns.shape) != expected_shape:
            raise ValueError(
                "prior_returns must have shape [batch, number_of_horizons]"
            )
        return prior_returns

    def _expert_weights(
        self,
        regime_logits: torch.Tensor,
        regime_probabilities: torch.Tensor | None,
    ) -> torch.Tensor:
        if regime_probabilities is None:
            return torch.softmax(regime_logits, dim=-1)
        if tuple(regime_probabilities.shape) != tuple(regime_logits.shape):
            raise ValueError(
                "regime_probabilities must have shape [batch, expert_count]"
            )
        if torch.any(regime_probabilities < 0):
            raise ValueError("regime_probabilities cannot be negative")
        totals = regime_probabilities.sum(dim=-1, keepdim=True)
        if torch.any(totals <= 0):
            raise ValueError("regime_probabilities must have positive row sums")
        return regime_probabilities / totals

    def forward(
        self,
        sequences: torch.Tensor,
        symbol_ids: torch.Tensor,
        prior_returns: torch.Tensor | None = None,
        regime_probabilities: torch.Tensor | None = None,
    ) -> RegimeGatedForecast:
        if sequences.ndim != 3:
            raise ValueError("sequences must have shape [batch, time, features]")
        encoded_sequence = self.encoder(sequences.transpose(1, 2))
        encoded = self.temporal_pool(encoded_sequence)
        fused = self.fusion(
            torch.cat((encoded, self.symbol_embedding(symbol_ids)), dim=1)
        )
        regime_logits = self.regime_gate(fused)
        expert_weights = self._expert_weights(
            regime_logits, regime_probabilities
        )
        expert_outputs = torch.stack(
            [expert(fused) for expert in self.experts], dim=1
        ).reshape(
            fused.shape[0],
            self.expert_count,
            len(self.horizons),
            self.OUTPUTS_PER_HORIZON,
        )
        weights = expert_weights[:, :, None]
        prior = self._validated_prior(fused, prior_returns)[:, None, :]

        expert_direction_logits = expert_outputs[..., 0]
        prior_shrinkage = torch.tanh(self.prior_weights)[None, :, :]
        expert_locations = prior_shrinkage * prior + expert_outputs[..., 1]
        expert_scales = F.softplus(expert_outputs[..., 2]) + self.minimum_scale
        expert_vwap_logits = expert_outputs[..., 3]
        expert_favorable = F.softplus(expert_outputs[..., 4])
        expert_adverse = F.softplus(expert_outputs[..., 5])

        direction_logits = (weights * expert_direction_logits).sum(dim=1)
        return_location = (weights * expert_locations).sum(dim=1)
        second_moment = (
            weights * (expert_scales.square() + expert_locations.square())
        ).sum(dim=1)
        return_scale = (
            (second_moment - return_location.square()).clamp_min(1.0e-8).sqrt()
        )
        vwap_cross_logits = (weights * expert_vwap_logits).sum(dim=1)
        favorable_excursion = (weights * expert_favorable).sum(dim=1)
        adverse_excursion = (weights * expert_adverse).sum(dim=1)
        return RegimeGatedForecast(
            direction_logits=direction_logits,
            return_location=return_location,
            return_scale=return_scale,
            vwap_cross_logits=vwap_cross_logits,
            favorable_excursion=favorable_excursion,
            adverse_excursion=adverse_excursion,
            regime_logits=regime_logits,
            expert_weights=expert_weights,
        )


def student_t_negative_log_likelihood(
    target: torch.Tensor,
    location: torch.Tensor,
    scale: torch.Tensor,
    degrees_of_freedom: float = 5.0,
) -> torch.Tensor:
    """Mean Student-t NLL with a fixed heavy-tail parameter."""

    if degrees_of_freedom <= 2:
        raise ValueError("degrees_of_freedom must be greater than two")
    if target.shape != location.shape or target.shape != scale.shape:
        raise ValueError("target, location, and scale must have identical shapes")
    safe_scale = scale.clamp_min(1.0e-6)
    freedom = target.new_tensor(degrees_of_freedom)
    standardized = (target - location) / safe_scale
    log_normalizer = (
        torch.lgamma((freedom + 1) / 2)
        - torch.lgamma(freedom / 2)
        - 0.5 * (torch.log(freedom) + math_log_pi(target))
        - torch.log(safe_scale)
    )
    log_density = log_normalizer - ((freedom + 1) / 2) * torch.log1p(
        standardized.square() / freedom
    )
    return -log_density.mean()


def math_log_pi(reference: torch.Tensor) -> torch.Tensor:
    """Keep the scalar constant on the same device and dtype as the input."""

    return reference.new_tensor(3.141592653589793).log()
