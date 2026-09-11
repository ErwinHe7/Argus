# Market Map data connections

The public connection targets U.S. AAPL/SPY daily observations from HF Data
Library, using the independent `PublicMarketMapSnapshot` contract and
`workers/public-market-map` scheduled service. It requires a free, verified
HF account's API key in the server-side `HF_DATA_API_KEY` secret. Source volume
covers IEX only. Prices are `source_adjusted_unverified`: upstream descriptions
and incremental adjustment code do not establish complete split/dividend
adjustment. Daily Parquet bytes and source receipts are retained.
Missing options IV stays null. Production activation has not yet been verified
because the key is not available. The earlier Taiwan universe is superseded.
See `workers/public-market-map/README.md` for ingestion, refresh, attribution and
`/status`; `docs/market-map-delivery.md` records actual deployment readiness.

The U.S. frontend rejects mixed-market metadata even when the symbol matches:
USD, America/New_York, asset type and listing exchange must match the public
catalog. Missing or expired core data hides navigation and returns 404. The
old synthetic preview URL redirects to this same gated entry.

For a genuine local AAPL review, run
`node --import tsx scripts/market-map-us-local-review.mjs --serve`, then start
Next with `PUBLIC_MARKET_MAP_DEV_ORIGIN=http://127.0.0.1:8790`. This uses EODHD
demo for personal local evaluation only, with VTI explicitly named as its
benchmark. Its files stay under ignored `.quant-runtime/us-local-review` and
must not be published as the public website feed.

The remainder of this document describes the separate **member US-equity data
connection** and its stricter required-input and provider-rights contract.

The website renders immutable Rust snapshots. The ordinary data path never falls
back to the separate, explicitly labeled synthetic review route. Daily research
snapshots expire after the next exchange close plus the configured vendor delay;
there is no seconds-level price poll.

## Refresh

From `platform`, run:

```powershell
node scripts/market-map-refresh.mjs --check
node --env-file=.env.local scripts/market-map-refresh.mjs --config .quant-runtime/market-map-config.json
```

The first command writes `artifacts/status.json` with missing inputs. A blocked
run exits 2. It never logs credentials, provider response text, or private rights
documents. Refresh requires `MASSIVE_API_KEY`, the existing Rust `quantctl` and
new `market-map` binaries, and Python with the project's existing
`exchange-calendars` dependency (or an explicitly supplied exchange calendar).

On the reviewed development machine, the compiled Rust toolchain and Market Map
binary are in WSL Ubuntu rather than the Windows executable search path. A
Windows refresh therefore still needs runnable native binaries configured through
`quantctl_binary` and `market_map_binary`, or the full refresh must run in a Linux
environment with the required binaries and paths. The illustrative website does
not require those executables at request time.

## Current readiness and remaining inputs

The reviewed local configuration contains no usable member-feed credentials
and no configured Supabase member-authentication credentials. The illustrative
preview works independently of those services. Serving real member snapshots
still requires:

- `MASSIVE_API_KEY` for the entitled historical stock/ETF data feed.
- A real, same-tenor historical ATM IV archive, plus the private asset/calendar
  refresh configuration and executable research runtime described below.
- Reviewed, pinned display-rights receipts for every data source. A working
  provider login or API key is not that evidence.
- The existing Supabase authentication configuration:
  `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and server-only
  `SUPABASE_SERVICE_ROLE_KEY`, with a real member session and existing paid
  research-access record. No new authentication or billing system is introduced.
- An entitled trade archive if the observed-trade volume-by-price panel is needed
  in the real snapshot.

Market Map's `--check` report covers its data-pipeline inputs. It does not verify
Supabase membership authentication or certify an entire production deployment.

The private configuration has this shape; replace every placeholder with actual
asset identity, reviewed rights receipt pins, and a real IV archive:

```json
{
  "asset": {
    "asset_id": "actual-asset-uuid",
    "symbol": "SPY",
    "name": "SPDR S&P 500 ETF Trust",
    "asset_type": "etf",
    "exchange": "ARCX",
    "currency": "USD",
    "market_timezone": "America/New_York"
  },
  "sector": {
    "sector_id": "broad-market",
    "sector_name": "US broad market",
    "benchmark_symbol": "SPY"
  },
  "history_sessions": 126,
  "delay_minutes": 60,
  "iv_history_path": ".quant-runtime/SPY-atm30-iv.json",
  "python_binary": "python",
  "quantctl_binary": "quantctl",
  "market_map_binary": "market-map",
  "rights": [
    {
      "data_root": "private-rights-directory-for-this-feed",
      "provider": "massive",
      "product": "actual-reviewed-provider-product",
      "receipt_sha256": "actual-64-lowercase-hex-receipt-pin",
      "source_ids": ["ohlcv", "corporate-actions", "sector"]
    },
    {
      "data_root": "private-rights-directory-for-iv",
      "provider": "actual-iv-provider",
      "product": "actual-reviewed-iv-product",
      "receipt_sha256": "actual-64-lowercase-hex-receipt-pin",
      "source_ids": ["options-iv"]
    }
  ]
}
```

Each rights directory must contain `rights/market_data_rights_receipt.json` in
the existing `axio.market_data_rights.v2` contract. The refresh invokes the
canonical Rust rights validator, binds sources to the correct provider, and
limits publication to the earlier of the next data refresh or rights expiry.
Possessing an API key does not produce a rights receipt.

The IV archive shape is:

```json
{
  "symbol": "SPY",
  "tenor_days": 30,
  "moneyness": "atm",
  "methodology": "constant_tenor_atm",
  "source": {
    "id": "options-iv",
    "provider": "actual-iv-provider",
    "dataset": "actual constant-tenor ATM dataset",
    "observed_at": "actual-observation-time",
    "available_at": "actual-availability-time",
    "retrieved_at": "actual-retrieval-time",
    "delay_minutes": 15
  },
  "series": [{ "observed_at": "actual-observation-time", "percent": 20.0 }]
}
```

The numeric row above documents units only; it is not a market observation.
Supply at least six consecutive completed market sessions with consistent tenor,
ATM definition, and sampling time. A 15:45 observation can align with that day's
16:00 close. A current options-chain snapshot alone cannot fill this history.

Optional `trades_path` references `{symbol,source,trades}` where
`source.id` is `trades`, and each trade is `{observed_at,price,volume}`. Its real
rights receipt must include the `trades` source. This powers the observed-trade
volume profile. Without it, refresh reports the missing optional profile and
does not manufacture price-level volume from daily bars.

## Data treatment

- Massive minute aggregates are filtered through the XNYS exchange calendar in
  the offline Python research layer. Extended-hours trades never enter bars
  labeled `regular`. Missing regular minutes fail coverage for the initial
  liquid-stock/ETF scope.
- Historical prices are split-adjusted. Cash dividends are retrieved and retained
  as corporate actions; returns are price returns without dividend reinvestment.
- The same completed session window drives the asset and benchmark. IV must cover
  the latest six market sessions. The Rust engine calculates all indicators,
  simulation paths, densities, levels, scenarios, and evidence-backed THE READ.
- All four horizons are validated against the website serialization and freshness
  contract before `artifacts/snapshots.json` and `publication.json` are written.
  The manifest is written last, so interrupted refreshes cannot validate mismatched
  snapshot hashes. This command publishes one configured asset per bundle.
- The website serves valid artifacts only to authenticated users with existing
  paid research access. Anonymous free-preview configuration does not authorize
  real market-data access. Synthetic review artifacts use a separate route.

Run the normal Cloudflare build/release after a successful refresh to ship the
new server bundle. Refresh does not deploy, purchase data, or change secrets.

Provider references: [Massive extended hours](https://massive.com/knowledge-base/article/market-data-outside-of-normal-hours),
[Massive aggregate adjustment semantics](https://massive.com/docs/rest/stocks/aggregates/custom-bars).
