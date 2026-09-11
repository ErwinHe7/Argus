# U.S. broker connections and stock discovery

Owner request: U.S. users connect IBKR, moomoo, and Webull, inspect model research,
and submit their own reviewed orders. The owner currently has personal brokerage
accounts, not approved third-party applications. This request authorizes building
manual order integration; it does not authorize autonomous trading, a real test
order, or production activation without the corresponding broker configuration.

## Implementation plan

- Inspect the existing Webull encrypted connection lifecycle, account capabilities,
  manual preview/confirm/reconciliation service, Market Map publication validator,
  and current U.S. data pipeline.
- Add an authenticated three-provider readiness contract to the retained API.
  Preserve the existing Webull security and command lifecycle. Add tested moomoo
  OAuth 2.1/PKCE request construction using its current official specification.
- Add official Nasdaq-listed and other-exchange-listed security directories,
  source receipts, freshness checks, bounded symbol/name search, and explicit
  research coverage. Nasdaq listings are not Nasdaq-100 constituents. S&P 500
  membership is not inferred from SPY or a Nasdaq listing.
- Extend the existing Leo research UI with a searchable security directory and
  broker setup screen, linked from Market Map. Preserve its visual language.
- Verify provider contract/authentication/no-egress tests, OAuth safety tests,
  directory parsing/freshness/query tests, TypeScript, and desktop/mobile UI.

Pass criteria: a real directory can be searched; only valid authorized snapshots
open research; three brokers have truthful setup states; unconfigured connections
and orders stay unavailable; credentials never enter browser bundles or logs.

## External prerequisites

- IBKR: third-party onboarding and broker-issued authentication configuration.
- moomoo: an actual registered OAuth client/callback, user authorization, and
  verified U.S. account permissions. Its current public OAuth documentation does
  not state a partner-approval prerequisite.
- Webull: approved Connect application and sandbox evidence. Existing unresolved
  partner contract questions remain recorded in `webull-connect-contract.md`.
- Broad research: entitled historical/current prices and corporate-action data
  plus appropriate display rights. Listing metadata alone is not market data.
- Predictive ranking: separately validated model coverage and promotion evidence.
  Existing symbol-specific frozen candidates are not promoted by adding symbols.

No broker registration, email, order, payment, permission grant, or production
deployment is performed by this implementation. API/MCP availability alone does
not determine the platform's regulatory obligations.

## Sources checked September 5, 2026

- https://www.interactivebrokers.com/docs/web-api/getting-started
- https://www.interactivebrokers.com/docs/web-api/authentication/oauth-1a/third-party-oauth/third-party-o-auth-workflow
- https://open.moomoo.com/api/overview/getting-started
- https://developer.webull.com/apis/docs/connect-api/about-connect-api/
- https://developer.webull.com/apis/docs/connect-api/authentication/
- https://www.nasdaqtrader.com/trader.aspx?id=symboldirdefs
- https://www.sec.gov/about/divisions-offices/division-trading-markets/division-trading-markets-compliance-guides/guide-broker-dealer-registration

## Delivered locally

- `/discover/stocks`: search and paginate 13,155 official non-test U.S.
  exchange-listed securities, including 5,584 Nasdaq listings. Filter by venue,
  ETF classification, and current research coverage. The underlying files are
  dated September 4, imported September 5, and expire conservatively September 11.
- `/brokers`: setup requirements for IBKR, moomoo, and Webull, with keyboard
  navigation and explicit unavailable connection/order states. Market Map links
  to both new pages. A symbol can be carried to setup without creating an order.
- `/api/market-universe`: no-store, bounded listing queries; rejects duplicate or
  unknown query fields. Exact-symbol fresh research coverage comes from validated
  Market Map snapshots. Only AAPL currently has a local current snapshot; the
  other listings are not presented as analyzed or ranked.
- `/v1/brokerage/providers`: authenticated provider readiness metadata and updated
  OpenAPI contract. moomoo has tested OAuth 2.1/PKCE contract helpers; Webull's
  existing custody and manual-order lifecycle remains gated. IBKR's live adapter
  remains pending.

This is a local preview, not a deployed or connected brokerage product. The
listing catalog is under the ignored `.quant-runtime/market-universe/` directory;
production needs catalog storage and refresh appropriate to its hosting runtime.
The local AAPL evaluation feed is not authority to redistribute a full-market feed.

## Verification

- Directory and discovery tests: 11/11 passed, including source truncation,
  freshness, bounded queries, exact-symbol matching, and rejection of expired,
  future or misdirected analysis.
- moomoo OAuth and brokerage readiness tests: 35/35 passed. Existing brokerage
  lifecycle and OpenAPI tests: 39/39 passed; API TypeScript and OpenAPI checks
  passed. These are mocked/contract checks, not broker sandbox evidence.
- Focused strict platform TypeScript over the new routes, UI, directory and
  transitive imports passed with the existing Cloudflare environment declaration.
  The unrestricted whole-platform check was interrupted after it continued
  scanning the existing mixed source/build workspace without completing; no
  whole-workspace pass is claimed.
- Live localhost API checks passed for the full count, Nasdaq count, current AAPL
  coverage, NVDA without substituted research, empty results, pagination and
  invalid-query rejection. Desktop and 390px phone layouts inspected; broker
  arrow/Home/End keyboard selection works. UI detector returned no findings.
- Independent UI finish review: `ship` at the local setup/discovery scope, no
  material fixes. This verdict does not cover external broker activation or
  broader research. Captures are in `.impeccable/review/broker-universe/`.

## Next activation work

1. Establish the platform's legal applicant details and registered HTTPS callback
   URLs. Obtain IBKR third-party access and Webull Connect onboarding details;
   register the moomoo OAuth client and verify supported US scopes/accounts.
2. Implement and bind each approved account/order adapter. For moomoo, add atomic
   one-use callback consumption, encrypted verifier/token custody, refresh and
   disconnect lifecycle around the pure contract helpers. Complete broker sandbox
   checks before enabling any connection or manual order control.
3. Provision entitled symbol-specific OHLCV, corporate-action and benchmark data
   with display rights. Classify instruments before broad Rust intake. The
   current Rust Market Map already accepts supplied per-symbol observations;
   training and predictive model promotion remain separate acceptance steps.

Developer credentials belong in the deployment secret store, never in chat or
client-side environment variables. No customer password is collected by these
setup pages. Regenerate the Dart API client before a mobile API release.
