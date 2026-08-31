# HYP-LIQ-001 — liquidity sweep and reclaim

**Hypothesis.** A price excursion through a visible level followed by rapid reclaim, falling price impact and restored liquidity may indicate exhaustion rather than continuation.

**Measurable proxy.** Prior level break, lower/upper wick, close location, abnormal volume, return acceleration, session VWAP distance, spread normalization and quote age. Nasdaq QBBO measurements are exchange-specific and are never interpreted as consolidated depth.

**Labels.** Next-bar entry with direct 1/5/15/30-minute return, MFE and MAE.

**Controlled experiment.** Day-block walk-forward comparison to unconditional reversal and momentum baselines, with multiple-hypothesis registry and cost-aware confidence bounds.

**Current OOS result.** The Rust candidate produced 3/3 wins, which is insufficient for promotion and remains `CANDIDATE_SAMPLE_TOO_SMALL`.

**Limitation.** One-minute aggregates cannot prove a depth sweep. Full validation needs quote/trade sequencing and a licensed market-depth source.
