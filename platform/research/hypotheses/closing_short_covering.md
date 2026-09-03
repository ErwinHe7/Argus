# HYP-CLOSE-001 — closing short-covering

**Hypothesis.** After an extended intraday decline, a concentrated late-session rise with abnormal volume and cross-asset confirmation can represent inventory unwind/short covering and may have a different next-bar distribution from an ordinary bounce.

**Measurable proxy.** Prior 60-minute negative return; current 5/15-minute positive acceleration; same-minute RVOL; session range position; SPY residual versus QQQ/IWM; minutes to close; spread if Nasdaq QBBO is present.

**Labels.** Direct 1, 5, 15 and 30-minute log-return distributions, MFE and MAE beginning at the next bar. A future SPXW mapping is prohibited without OPRA NBBO.

**Controlled experiment.** Fit thresholds and model weights inside train/validation only. Compare against same-time unconditional return, momentum and mean-reversion baselines. Purge response overlap and block analogs/bootstrap by day.

**Current OOS result.** Not independently validated. The existing 2024-07-18–2026-07-17 interval has been inspected and is marked contaminated for final promotion.

**Limitation.** Aggregate bars cannot identify actual short positions or closing-auction imbalance. "Short covering" remains a proxy label until order-flow/auction data is licensed.
