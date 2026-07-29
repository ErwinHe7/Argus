# AXIO7 PostgreSQL market store

PostgreSQL is the continuous-ingestion and website market database. The
existing SQLite files remain immutable source/research receipts and are not
deleted after migration.

## Local service

Set a local password in the shell, then start the loopback-only service:

```powershell
$env:MARKET_POSTGRES_PASSWORD = "<local-secret>"
docker compose -f infra/market-data/postgres/compose.yaml up -d
$env:MARKET_DATABASE_URL = "postgresql://axio7:<local-secret>@127.0.0.1:55432/axio7_market"
```

Do not commit either value. Production must use a managed secret and TLS.

## Migrate the immutable SQLite archive

```powershell
Push-Location intraday_quant
.\.venv-cuda\Scripts\python.exe -m intraday_quant.storage.postgres_migration `
  --sqlite ..\quant_engine_rs\data\state\market_data.sqlite3 `
  --schema ..\infra\market-data\postgres\schema.sql
Pop-Location
```

The command uses chunked PostgreSQL `COPY`, creates monthly partitions, and
fails if the final PostgreSQL count differs from SQLite.

## Point-in-time extraction

The query must supply both the market interval and the information cutoff:

```sql
SELECT *
FROM market_data.equity_minute_bars_asof(
    ARRAY['SPY', 'QQQ', 'NVDA'],
    '2026-07-20 13:30:00+00',
    '2026-07-20 20:00:00+00',
    '2026-07-25 16:00:00+00'
)
ORDER BY event_at, symbol;
```

Rows with `available_at > decision_cutoff` are excluded. Current Massive
backfill batches are `RESEARCH_ONLY` and were marked available when ingested;
migration does not convert them into public-display data.

## Options and IBKR

The schema separates option minute trade aggregates, NBBO quotes, individual
trades, and daily contract open interest. Do not write one dataset into
another table merely because a field is unavailable.

The current Massive Options Basic entitlement is allowed only for
`RESEARCH_ONLY` end-of-day minute aggregates. A bounded expiration/strike slice
can be archived with:

```powershell
Push-Location intraday_quant
$env:MARKET_DATABASE_URL = "postgresql://axio7:<local-secret>@127.0.0.1:55432/axio7_market"
.\.venv\Scripts\python.exe -m intraday_quant.storage.massive_options `
  --underlying NVDA --expiration 2026-07-24 `
  --strike-min 210 --strike-max 210 `
  --start 2026-07-24 --end 2026-07-24
Pop-Location
```

The key is read from `MASSIVE_API_KEY`; it is never written to the raw
manifest. Basic aggregates become point-in-time eligible only at conservative
noon ET on the next calendar day, and remain ineligible for realtime gamma.
The NBBO, tick-trade, and contract-OI tables remain empty until a genuine
entitled source is connected.

IBKR is appropriate for forward snapshots/archive and account-side
verification after TWS or IB Gateway is running. It cannot reconstruct a
complete expired-option OPRA history and does not grant website redistribution
rights.
