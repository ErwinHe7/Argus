# Intraday Quant

Leakage-safe, minute-by-minute SPX research and walk-forward backtesting framework. It evaluates every market minute as state, generates a small set of interpretable candidates, and permits zero-trade days. The bundled default run is **synthetic software validation only**, not a claim of historical or expected profitability.

## Quick start

```powershell
cd intraday_quant
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[dev]"
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m intraday_quant.cli run-all --config configs/default.yaml
```

## Full product: frontend + backend + database

From the repository root, one command starts the FastAPI research service, initializes/imports the DuckDB registry, and starts the Next.js dashboard:

```powershell
npm run quant:dev
```

Open `http://127.0.0.1:3000/quant/intraday`. API documentation is at `http://127.0.0.1:8001/docs`. Stop both managed processes with `npm run quant:stop`.

The product boundary is:

- Next.js research console and server-only API gateway
- FastAPI run queue and artifact API
- DuckDB experiment registry at `state/research.duckdb`
- Python point-in-time feature/model/backtest pipeline

See `../docs/intraday-quant-architecture.md` and `../docs/intraday-quant-mathematics.md` for the block contracts and executable equations.

Individual stages use `ingest`, `features`, `candidates`, `labels`, `train`, `backtest`, and `report` with the same `--config` argument. Artifacts are written beneath `data/`: cleaned/features/models/reports plus `market.duckdb` with a `bars` view.

Recent unofficial Yahoo price-only check and a leakage-safe 15:50 analog query:

```powershell
.\.venv\Scripts\python.exe -m intraday_quant.cli run-all --config configs\yahoo_recent.yaml
.\.venv\Scripts\python.exe -m intraday_quant.cli analog --config configs\yahoo_recent.yaml --date 2026-07-16
```

The Yahoo configuration is limited to the provider's recent one-minute window and has no executable NBBO. Its annualized statistics are suppressed when fewer than 60 sessions are observed.

## Real minute data

Set `data.adapter` to `csv` or `parquet` and `data.input_path` to a file containing:

`timestamp, symbol, open, high, low, close, volume, vwap, bid, ask, trade_count, source, data_quality`

Timestamps may be timezone-aware or naive ET. Include SPX plus ES, SPY, QQQ, SOXX, IWM and VIX/VIX1D for full feature coverage. SPY/ES volume is used because SPX has no centralized equity volume. Corporate-action-adjusted equity inputs must be point-in-time adjusted by the provider; the pipeline does not retroactively rewrite historical bars. Extended-session ES or premarket data is required for genuine overnight high/low features; otherwise those values remain unavailable.

## Real options NBBO

Enable `option_execution.enabled` and provide `option_execution.quotes_path` as CSV/Parquet with:

`timestamp, underlying, option_symbol, expiry, dte, strike, call_put, bid, ask, bid_size, ask_size, mid, last, volume, open_interest, iv, delta, gamma, theta, vega, underlying_price`

Quotes must be historical point-in-time NBBO. Open interest must represent the value known at the session open. Entries use ask plus slippage and exits use bid minus slippage; crossed, zero-bid, stale/unliquid, overly wide, wrong-DTE and wrong-Delta quotes are rejected. Without this file, options performance is not calculated. Black-Scholes is intentionally not used as a fill substitute.

## PostgreSQL and CUDA challenger

PostgreSQL is the canonical continuous-ingestion/research store. After running
`../scripts/setup-cuda-training.ps1` and setting `MARKET_DATABASE_URL`, train
the research-only regime-gated distributional TCN with:

```powershell
.\.venv-cuda\Scripts\python.exe -m intraday_quant.training.cuda_challenger `
  --output-dir data\models\cuda_challenger
```

It reads the append-only point-in-time SQL view, builds complete five-minute
bars, and uses 24-bar causal sequences for the configured nine-symbol/proxy
universe. Four latent experts are combined by a balanced regime gate; a
separately validated Rust regime posterior can replace that latent gate at
inference. The heads predict 5/15/30/60-minute direction, heavy-tailed return
location/scale, VWAP-cross probability, and favorable/adverse excursions. The
return location combines a neural residual with an expert/horizon-specific,
bounded shrinkage weight on a causal EWMA drift prior.
Normalization is fit on training sessions only; validation and test are
chronological with session embargoes. Every output is
`CANDIDATE_NOT_PROMOTED` until separate forward-shadow evidence and a verified
Rust artifact runtime pass the production policy.

Massive Options Basic minute aggregates and official OCC market-wide daily OI
totals have dedicated ingestors in `intraday_quant.storage`. Neither dataset
contains historical NBBO or contract-level OI, so neither can make a gamma
report eligible.

## Research controls

- Signals are known only after bar `t`; entry starts at `t+1`.
- Walk-forward splits are chronological with purge and embargo.
- Scaling, fitting, calibration and thresholds use train/validation only.
- Same-minute stop/target ambiguity resolves to the stop first.
- A dedicated `closing_short_cover` setup scores the final 10 minutes using upside acceleration, close-location/volume buy-pressure proxies and cross-asset confirmation, then reports prior analog dates and their forward distributions.
- The default daily limit is two trades, one open position and one trade per direction.
- All rejected candidates retain a machine-readable reason.

The photos supplied with the request motivated the public concepts of historical analogs, momentum and reversal. This project does not reproduce or claim access to any proprietary institutional model.
