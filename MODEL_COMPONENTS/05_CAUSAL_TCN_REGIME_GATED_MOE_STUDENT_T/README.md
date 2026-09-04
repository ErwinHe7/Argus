# 05 — Causal TCN, regime-gated MoE, and Student-t head

## What is implemented

- causal temporal convolutions;
- causal attention;
- four-expert regime-gated mixture of experts;
- Student-t distribution head and negative log-likelihood;
- CUDA-capable offline challenger training.

## Canonical code — edit here

- [`causal_tcn.py`](../../axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py)
- [`cuda_challenger.py`](../../axio7-model-review/source/intraday_quant/src/intraday_quant/training/cuda_challenger.py)

## Status

Offline candidate only. Directional results are unstable and there is no
promoted Rust inference artifact.
