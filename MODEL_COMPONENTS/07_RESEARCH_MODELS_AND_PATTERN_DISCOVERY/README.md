# 07 — Research models and automatic pattern discovery

## Included research components

- TVTP-HMM;
- Student-t HMM and HSMM comparisons;
- gamma convexity scenarios;
- closing short-cover hazard research;
- matrix profile, motif discovery, and FDR-controlled pattern research.

## Canonical code — edit here

- [`engine/tvtp_regime.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/tvtp_regime.rs)
- [`engine/regime_competition.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs)
- [`engine/gamma_convexity.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/gamma_convexity.rs)
- [`engine/closing_short_cover.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/closing_short_cover.rs)
- [`motif_discovery/mod.rs`](../../axio7-model-review/source/quant_engine_rs/src/motif_discovery/mod.rs)
- [`pattern_factory.rs`](../../axio7-model-review/source/quant_engine_rs/src/pattern_factory.rs)

## Status

Research-only. Gamma exposure remains unsigned/scenario-based when dealer-side
position sign is unavailable.
