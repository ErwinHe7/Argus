# Broker connection surface

`#/brokers` is a setup and reported-status view. It inherits the existing Strategy
Workspace and Research Desk design: aubergine surfaces, candle-gold actions, flat
rules, Inter typography, and the retained Leo Lion. No new visual system, billing
flow, browser-local trading engine, or broker OAuth flow is introduced.

The main navigation links directly to the page. moomoo setup leads to
`#/strategies?step=connect`; this chooses the Connect computer step on mount and
does not create a token, deployment, or order. Public instructions remain usable
when archived chart data is unavailable.

`useWorkspace` supplies server-verified, owner-matched evidence. The page never
reads localhost or requests a broker password. Unauthenticated and anonymous
visitors see no account evidence. Revoked devices are hidden. A report older than
15 seconds, future-dated report, or failed status request does not show the
computer as reporting. Retained account IDs are explicitly reported paper
accounts, not proof that a broker is currently connected or that a strategy may
execute. The page has no trading controls.

Windows tools links are gated by `BROKER_TOOLS_RELEASE.available` until a reviewed
package is staged at the declared path. The package remains a development
distribution; the parent delivery must describe its signing and runtime
prerequisites. IBKR is labeled developer preview: a local Client Portal paper
adapter and a read-only TWS inspector. Public automatic execution remains
unavailable pending required broker approval and broker-backed acceptance.

## Official setup references

- [moomoo OpenD download](https://www.moomoo.com/download/OpenAPI)
- [moomoo OpenD overview](https://openapi.moomoo.com/moomoo-api-doc/en/opend/opend-intro.html)
- [IBKR TWS or IB Gateway](https://www.interactivebrokers.com/docs/tws-api/doc/download-tws-or-ib-gateway/download-tws-or-ib-gateway)
- [IBKR TWS API installation and Read-Only configuration](https://www.interactivebrokers.com/campus/trading-lessons/installing-configuring-tws-for-the-api/)

## Verification

Build the research-desk static overlay, then run `browser.cjs` with Node's `tsx`
loader. `LEO_BROKER_TEST_BASE` sets the fixture server origin (default port 3221).
`LEO_PLAYWRIGHT_MODULE` can point at an existing Playwright installation. Every
external request is intercepted; this test never authenticates to Google or a
broker and never submits an order.

Five browser checks cover guest and keyboard setup, the existing Google PKCE
boundary, owner-scoped account rendering, stale-value preservation, expired and
future reports, revoked devices, anonymous access, and mismatched owner identity.
Desktop and 390px mobile captures plus reported and stale states are stored in
`platform/.impeccable/review/brokers/`. These injected fixtures are UI evidence,
not proof of a functioning broker session, execution, or profitability.

The mechanical design detector found only advisory type-ramp drift inherited
from the existing research desk's sizes; no hard findings. Existing design
documents remain unchanged. Final deployment review also needs the downloadable
package gate checked against the actual release artifacts.
