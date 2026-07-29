# AXIO7 public context API

AXIO7 exposes a narrow, read-only context API for impersonal market research.
It never proxies Databento bars, Rust control-plane paths, API keys, orders, or
raw licensed vendor feeds.

## AXIO7 endpoints

Production URLs:

- Source and license catalog:
  `https://axio7.com/api/context/v1/sources`
- SEC NVDA example:
  `https://axio7.com/api/context/v1/sec?symbol=NVDA&limit=10`
- All connected public macro series:
  `https://axio7.com/api/context/v1/macro?series=CPI_US_ALL_SA,UNEMPLOYMENT_RATE_US,PAYROLL_EMPLOYMENT_US,UST_CMT_2Y,UST_CMT_10Y,UST_10Y2Y_SPREAD,EFFR`
- BLS-only example:
  `https://axio7.com/api/context/v1/macro?series=CPI_US_ALL_SA,UNEMPLOYMENT_RATE_US,PAYROLL_EMPLOYMENT_US`
- Treasury and NY Fed example:
  `https://axio7.com/api/context/v1/macro?series=UST_CMT_2Y,UST_CMT_10Y,UST_10Y2Y_SPREAD,EFFR`
- OCC license status:
  `https://axio7.com/api/context/v1/occ-open-interest`
- Company-news license status:
  `https://axio7.com/api/context/v1/news?symbol=NVDA`

The routes are not an unrestricted bulk-download or market-data redistribution
API. The macro route is `no-store`; its adapter owns source-specific caching and
freshness checks.

Every successful data response includes source, observation cutoff,
availability/retrieval time, freshness, coverage, model/feature version, model
eligibility, and material caveats. Missing, stale, malformed, unallowlisted, or
unlicensed input fails closed. No Yahoo, stale-as-live, or synthetic substitute
is returned.

## Connected free official sources

### SEC EDGAR

Cost: free; no API key.

Required server setting:

```dotenv
SEC_USER_AGENT=AXIO7 Market Research monitored-contact@your-domain.com
```

Official links:

- API documentation:
  <https://www.sec.gov/search-filings/edgar-application-programming-interfaces>
- Ticker/CIK map: <https://www.sec.gov/files/company_tickers.json>
- NVDA submissions:
  <https://data.sec.gov/submissions/CIK0001045810.json>
- NVDA CompanyFacts:
  <https://data.sec.gov/api/xbrl/companyfacts/CIK0001045810.json>
- Fair-access guidance:
  <https://www.sec.gov/about/webmaster-frequently-asked-questions>

The endpoint returns material filing metadata and deterministic XBRL facts only
when they can be tied to an exact SEC acceptance timestamp. Duration facts are
separated into quarterly and annual periods; ambiguous YTD durations are
excluded. Public-route records remain `archive_verified=false` and
`model_eligible=false` until the separate immutable archive passes Rust
verification.

### BLS Public Data API v1

Cost: free; no key at current volume. A free v2 registration key raises the
official limit but is not needed by this route.

Connected mappings:

- `CPI_US_ALL_SA` -> `CUSR0000SA0`
- `UNEMPLOYMENT_RATE_US` -> `LNS14000000`
- `PAYROLL_EMPLOYMENT_US` -> `CES0000000001`

Official links:

- API: <https://www.bls.gov/developers/>
- Limits: <https://www.bls.gov/developers/api_faqs.htm>
- Terms: <https://www.bls.gov/developers/termsOfService.htm>
- Optional free v2 key: <https://data.bls.gov/registrationEngine/>

The no-key API is limited to 25 requests per day. AXIO7 requests all three
series together and caches the snapshot for six hours per process. The response
includes the BLS-required retrieval date and disclaimer. BLS current history is
revised history, not a point-in-time vintage.

### U.S. Treasury Daily Treasury Par Yield Curve

Cost: free; no key.

Connected fields:

- `UST_CMT_2Y` -> `BC_2YEAR`
- `UST_CMT_10Y` -> `BC_10YEAR`
- `UST_10Y2Y_SPREAD` -> transparent same-date `10Y - 2Y` arithmetic

Official XML documentation:
<https://home.treasury.gov/treasury-daily-interest-rate-xml-feed>

These are daily official curve observations, not real-time executable Treasury
quotes. AXIO7 records its first successful retrieval time rather than inventing
an upstream publication timestamp.

### New York Fed Markets API

Cost: free; no key.

Connected series: `EFFR` from the latest official reference-rate response.

Official links:

- API documentation:
  <https://markets.newyorkfed.org/static/docs/markets-api.html>
- Terms and required reference-rate notices:
  <https://www.newyorkfed.org/privacy/termsofuse.html>

The API response carries the required New York Fed notice and AXIO7
non-affiliation disclaimer. EFFR is a daily reference rate, not an intraday
executable rate.

### BEA

Cost: free; a server-side key is required. It is cataloged but not connected
until the owner supplies a key and the PCE schema contract is tested.

- Free key: <https://apps.bea.gov/api/signup/>
- Terms: <https://apps.bea.gov/API/_pdf/bea_api_tos.pdf>

## Point-in-time and scaling boundary

BLS, Treasury, and NY Fed return current official views rather than a unified
ALFRED-style vintage archive. Public responses therefore remain
`model_eligible=false`. AXIO7 must save immutable raw responses, first successful
retrieval time, source publication time when supplied, SHA-256, and revision
chains from the production start date before these observations can be evaluated
as causal model features.

The current caches are per process. A multi-instance deployment needs a shared
snapshot/cache layer before traffic is scaled, especially to preserve the BLS
v1 daily request limit.

## Sources intentionally blocked

### FRED / ALFRED

A free API key does not authorize AXIO7 software/model development or caching.
Current terms prohibit using FRED Services or Content for software or
machine-learning development/training and prohibit storage, caching, archiving,
or database incorporation. AXIO7 has removed the executable FRED sync path and
does not accept a FRED credential.

- Terms: <https://fred.stlouisfed.org/legal/terms/>
- Key page, reference only: <https://fredaccount.stlouisfed.org/apikeys>

### OCC Daily Open Interest

The existing offline importer remains `RESEARCH_ONLY`. The free file is a
market-wide aggregate by product class, not symbol-level or contract-level open
interest, OPRA, IV, Greeks, dealer positioning, or GEX. The customer endpoint
returns `SOURCE_LICENSE_REQUIRED` until OCC grants commercial rights in writing.

- Download documentation:
  <https://www.theocc.com/market-data/market-data-reports/other-market-data-info/batch-processing/daily-open-interest>
- Terms:
  <https://www.theocc.com/specialpages/legal/terms-and-conditions>

### Company IR / official RSS

There is no universal issuer API or universal commercial license. NVIDIA's RSS
terms limit the free feed to non-commercial use, so AXIO7 uses SEC 8-K filings
and their exhibits for the production-safe company-announcement path.

- NVIDIA RSS terms: <https://www.nvidia.com/en-us/about-nvidia/rss/>

### Benzinga

A free key or trial does not establish customer-facing redistribution rights.
AXIO7 enables Benzinga only after a commercial News API agreement and a recorded
license reference.

- News API documentation:
  <https://docs.benzinga.com/api-reference/news-api/overview>
- Terms: <https://www.benzinga.com/terms-and-conditions>