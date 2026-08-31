# AXIO7 narrow-universe data-source decision

Date: 2026-07-25
Universe: `SPX, QQQ, NVDA, AAPL, MU, SOXX, NBIS, BE, IGV`
Horizons: `5, 15, 30, 60` minutes
Product: public, impersonal market research; no order execution

## Decision

There is no professional, free, legally redistributable realtime consolidated
US-equity plus OPRA feed that can power the public AXIO7 product.

Use two distinct tracks:

1. **Research and development now**
   - Massive individual stock minute aggregates for the two-year equity
     backfill, stored as `RESEARCH_ONLY`.
   - SPY is the explicitly named price/volume/VWAP proxy for SPX research.
   - OCC's free Daily Open Interest download is a market-wide daily total by
     product class. It is useful as a slow market context series, but it is not
     contract-level OI and must never populate `option_open_interest`.
   - The current Massive Options Basic entitlement supplies two years of
     reference data and minute trade aggregates. These can support bounded,
     research-only option-price studies, but not historical NBBO/GEX.
   - No Yahoo, scraped Cboe pages, delayed-as-realtime, or synthetic fallback.

2. **Public launch**
   - First purchase: Databento `EQUS.MINI` live equities. Databento says this
     derived composite supports commercial applications and external
     redistribution without separate exchange licensing, and is included in
     Standard, Plus, and Unlimited. Current Standard list price is $199/month.
     Confirm the exact AXIO7 display/derived-output use in writing before
     changing the database batch license scope to `PUBLIC_REDISTRIBUTION`.
   - Gamma launch: obtain an OPRA Vendor Agreement/Exhibit A and a vendor plan
     that explicitly permits the AXIO7 external service. Databento's current
     generic pricing table reserves external distribution for Plus
     ($1,750/month in license fees, annual contract), while OPRA separately
     requires a Vendor Agreement for any external retransmission. Get a written
     quote; do not infer that a $199 personal/subscriber plan covers public
     gamma output.
   - SPX cash-index display is optional for v1. Keep the clearly labeled SPY
     direction/VWAP proxy until a commercial SPX index license is approved.

## Source matrix

| Need | Development source | Public-product source | Status |
| --- | --- | --- | --- |
| Equity 1m history | Massive individual plan | Databento EQUS.MINI historical or approved commercial archive | Massive backfill in progress; research-only |
| Realtime equity BBO/trades | none on the current entitlement | Databento EQUS.MINI Standard or written commercial equivalent | purchase required |
| SPX cash index | Massive probe returned 403 | commercial index entitlement | blocked; SPY proxy only |
| Realtime option quotes/trades | none | OPRA vendor-authorized feed | purchase + agreement required |
| Daily contract open interest | Massive Starter or another licensed option vendor | OPRA/vendor-authorized commercial path, with publication timestamp | current free OCC file is aggregate only |
| Market-wide option OI total | OCC Daily Open Interest report | OCC, subject to usage review | official aggregate context; not a contract chain |
| Greeks and IV | compute in Rust from complete eligible chain, or preserve vendor lineage | same | unavailable without chain |
| Earnings/filings | SEC actuals; point-in-time consensus still separate | licensed consensus for surprise features | partial |
| Macro vintages | ALFRED/FRED vintage data | same, subject to API terms | planned |

## Why the free alternatives are not production substitutes

- Massive's individual market-data terms grant personal, non-business,
  non-commercial use; research batches therefore fail the public-product
  license gate.
- Massive Options Basic exposes two years of minute aggregates at five API
  calls per minute. Starter is currently $29/month and adds flat files,
  snapshots, and daily OI; Developer is $79/month and adds trades; Advanced is
  $199/month and adds realtime data and quotes. These are individual-use plans,
  so none is assumed to authorize the public AXIO7 service.
- Alpaca states its API market data cannot simply be redistributed, and its
  free equity plan is IEX-only rather than consolidated SIP.
- Tradier's personal brokerage API is useful for individual development, but a
  fintech serving users must contact its business team.
- Cboe's delayed quote pages prohibit automated extraction. They are not an
  ingestion API.
- OPRA says delayed data still requires a Vendor Agreement and redistribution
  fee for an external service, even though delayed subscribers do not incur
  usage/device fees.

## Provider references

- Databento EQUS.MINI commercial-use announcement:
  <https://databento.com/blog/databento-us-equities-mini-now-available>
- Databento current pricing:
  <https://databento.com/pricing>
- OPRA access and vendor classification:
  <https://www.opraplan.com/access-quiz>
- OPRA overview and redistribution requirements:
  <https://www.opraplan.com/>
- OCC daily open interest:
  <https://www.theocc.com/market-data/market-data-reports/other-market-data-info/batch-processing/daily-open-interest>
- Massive individual market-data terms:
  <https://massive.com/legal/market-data-terms-of-service>
- Massive index pricing:
  <https://massive.com/pricing?product=indices>
- Alpaca redistribution policy:
  <https://alpaca.markets/support/redistribute-alpaca-api>
- Tradier business integration:
  <https://production.tradier.com/businesses/fintechs>

## Activation gates

The website remains fail closed until all of the following are true:

1. a server-side credential and signed usage scope are recorded;
2. a live entitlement probe succeeds for every required field;
3. each persisted batch has provider, dataset, source hash, event time,
   availability time, capture time, license scope, and license reference;
4. the Rust readiness receipt passes freshness and coverage;
5. per-target frozen artifacts pass untouched OOS validation, calibration, and
   immutable promotion;
6. the public Rust service has a stable authenticated HTTPS endpoint.

Purchasing a feed enables data access. It does not promote a model or create a
validated probability.
