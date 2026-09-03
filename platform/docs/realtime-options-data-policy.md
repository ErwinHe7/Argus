# Realtime options data policy

## Decision

AXIO7 does not use Yahoo as a production market-data dependency. A realtime
gamma-structure scan requires:

- consolidated realtime underlying observations;
- a complete OPRA option chain for every requested expiry;
- timestamped bid/ask, size, volume, daily open interest, IV, and Greeks;
- explicit quote, OI, and Greeks availability times;
- coverage and pagination receipts;
- redistribution rights appropriate for the website.

If any item is absent, delayed, stale, truncated, unentitled, or non-causal,
the Rust engine returns `DATA_UNAVAILABLE`.

## What Unusual Whales is doing

Unusual Whales documents that its flow covers trades executed across options
exchanges, that bid/ask values are derived from options NBBO, and that some
classification fields are calculated by its own system. It also explicitly
warns that ask/bid classification is only an estimate, that buy does not imply
buy-to-open, and that orders may be multi-leg. Its options pages require an
OPRA agreement.

AXIO7 follows the same important caution: public OI and trade prints do not
reveal dealer inventory sign, opening/closing intent, or complete OTC/multi-leg
exposure. We therefore publish unsigned gamma concentration plus explicit sign
scenarios, never “dealers are definitely short gamma.”

## Provider tiers

### Production realtime candidates

- Massive SIP + OPRA: existing native adapter, currently blocked because the
  configured account is not entitled to the stock WebSocket/realtime snapshot
  or full OPRA chains.
- Tradier Brokerage production API: consolidated realtime US equity/options
  data for eligible brokerage account holders; sandbox is delayed and Greeks
  are hourly. It can become a secondary adapter after a server-side token,
  entitlement receipt, timestamp/coverage validation, and redistribution
  review are in place.
- Licensed Databento/Cboe: appropriate for institutional historical/realtime
  archives when purchased and licensed.

### Context or historical only

- OCC's free Daily Open Interest CSV is a market-wide total by product class,
  not contract-level OI. OCC reference/listed-product files are still useful
  for lineage, but neither source supplies a point-in-time historical chain,
  realtime quotes, or Greeks.
- Massive Options Basic minute aggregates are genuine OPRA-derived qualifying
  trade bars, but contain no NBBO or contract OI. They are stored only in
  `option_minute_bars` with an end-of-day availability policy and never
  substituted into quote, trade-tick, or OI tables.
- Cboe delayed quote pages: official delayed context, not a live signal input.
- Alpaca Basic: IEX-only equities and an indicative options feed. Alpaca states
  that indicative option quotes are modified and trades are delayed, so Basic
  cannot satisfy the production OPRA/NBBO gate.
- Moomoo OpenD Nasdaq Basic/TotalView/ArcaBook: verified realtime underlying
  context in the local bridge, but not consolidated SIP NBBO.
- IBKR: useful for a user-authorized forward archive and snapshots, but it
  requires account subscriptions/a running client and has historical pacing
  and expired-options limitations. A Codex IBKR connector cannot be embedded as
  the website's production redistribution feed.

## Current runtime state

The repository has a professional fail-closed Massive adapter, complete-chain
pagination/coverage gates, an unsigned gamma aggregation module, and the new
market-query scanner. The latest readiness artifact is
`production_ready=false` because the current Massive plan lacks the required
SIP/OPRA entitlements. The former AXIO7 market options endpoint also returns
HTTP 410 and is not a usable data source.

No live gamma candidate should appear on the website until a provider passes
the native readiness contract.
