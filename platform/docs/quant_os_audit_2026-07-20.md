# Quant OS audit — 2026-07-20

## Evidence inspected

- Rust reference engine: `quant_engine_rs/src`, its 14-test suite, production config and four stored research runs.
- SQLite: `quant_engine_rs/data/state/quant_runs.sqlite3` (165 MB WAL database).
- Normalized market bars: 1,521,361 rows, 214,681,270 bytes.
- Frozen baseline and behavioral reports under `quant_engine_rs/data/reports`.

## Data audit

The normalized CSV contains SPY (426,290), QQQ (445,016), IWM (380,138) and the frozen legacy SOXX series (269,917), from 2024-07-18 through 2026-07-17. It has zero duplicate `(symbol,timestamp)` keys, zero invalid OHLC rows and zero negative volumes. Every row lacks bid and ask. The file includes extended hours; the C++ feature engine admits only finalized 09:30–16:00 ET bars and handles U.S. DST.

Production configuration names SPY/QQQ/IWM/TLT/HYG/UUP/GLD, but the normalized file does not yet contain TLT/HYG/UUP/GLD. Raw Massive chunks for TLT and HYG exist; they were not silently treated as aligned features. SOXX is retained as frozen evidence but excluded by the C++ adapter whitelist.

The source is Massive aggregate bars, not Nasdaq. A real Nasdaq QBBO 2.1 binary decoder is implemented, but no licensed Nasdaq capture or transport URL exists in `.env.local`. Nasdaq exchange BBO is always tagged `NASDAQ_BBO`; it is never called NBBO. SPX and SPXW are not supplied by this feed.

## Old-model failure causes

1. The candidate layer generated 27/28 trades from a broad VWAP condition, so the apparent setup universe was one correlated rule family.
2. Fixed 18/30 bps barriers ignored volatility and time of day; average adverse excursion was almost twice favorable excursion.
3. The old `dist_vwap` used `bar.vwap.unwrap_or(session_vwap)`. Massive's aggregate `vw` is a per-bar volume-weighted price, not cumulative session VWAP. The new engine derives session VWAP incrementally from finalized bars.
4. The old analog model used all `MarketState::FEATURE_COUNT` dimensions with marginal z-scales, fixed bandwidth and up to five overlapping minutes from the same day. It had no day block, effective-sample gate or episode-concentration penalty.
5. The old walk-forward helper split row indices, not trading-day blocks. Its purge/embargo structure was not a full nested, frozen-holdout protocol.
6. Platt calibration used a chronological validation tail, but candidate selection and repeated inspection contaminated the historical final test. The reported 76.36% mean probability versus 14.29% realized wins is a failed calibration and selection pipeline, not evidence that a more complex classifier is needed.
7. SQLite stored only `research_runs`; it did not contain event, prediction, risk, order, fill or balanced ledger facts.

## Leakage findings

- Forward labels correctly enter at the next bar and keep response windows inside a session.
- Incremental Rust price/volume features generally use the current and prior bars only; same-minute RVOL is accumulated from prior days.
- No direct future high/low feature was found.
- The research protocol was still insufficient: row-based folds, overlapping analog observations, reused/inspected test history and no complete lineage registry make the existing period unsuitable as a frozen final holdout.

## Decision

Both old models remain rejected. The 2024-07-18–2026-07-17 period is now marked `CONTAMINATED_EXISTING_HISTORY_EXPLORATORY_OOS_ONLY`. Any deployable promotion requires a new, untouched future interval or separately licensed history that has not been inspected.
