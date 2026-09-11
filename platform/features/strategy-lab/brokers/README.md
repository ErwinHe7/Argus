# Broker connection surface

`#/brokers` is a setup and reported-status view. It inherits the existing Strategy
Workspace and Research Desk design: aubergine surfaces, candle-gold actions, flat
rules, Inter typography, and the retained Leo Lion. The owner-authorized extension
adds an isolated read-only moomoo REST account link. Billing, the browser-local
research records, and the local paper mandate remain separate.

The main navigation links directly to the page. moomoo setup leads to
`#/strategies?step=connect`; this chooses the Connect computer step on mount and
does not create a token, deployment, or order. Public instructions remain usable
when archived chart data is unavailable.

Google sign-in returns to the exact `/#/brokers` allowlisted destination after
PKCE completes. Query-bearing, nested, encoded, external, and otherwise modified
return paths fall back to home. Broker callback text is only a completion hint;
it cannot establish account access.

## Direct moomoo account link

`DirectMoomooLink.tsx` checks the fixed `leo-broker-link.axio7.workers.dev` service
with the current non-anonymous Leo account's bearer token. The strict
`broker-link/v1` response contains masked account labels and read-only metadata;
full identifiers, balances, and token fields are rejected. A connected label
requires the server's successful account check and an observation under five
minutes old. An outage retains prior masked details, removes the connected claim,
and offers refresh. Switching Leo accounts remounts and clears private UI state;
pending responses are aborted and guarded against late delivery.

When the service reports `configured: true`, an explicit click posts the Google
access token in a top-level HTML form to `/oauth/moomoo/start`. The token is never
put into a URL or newly stored by this feature. The worker owns provider consent,
state/cookie verification, encrypted token storage, and scope checks. The UI asks
for read-only access to individual accounts and exposes no trading control.
Unconfigured service status leaves the local OpenD instructions usable.

`POST /disconnect` removes Leo's server-side link. It does not revoke all provider
permissions or stop a separate OpenD runner; those limits are stated beside the
action. Link status is independent of the computer heartbeat below.

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
The expanded local setup includes PowerShell 7 installation, using the installed
pair/start commands, hidden token entry, and review before the runner starts.
OpenD's detailed steps are collapsed so the IBKR choice remains visible without
reading the entire OpenD guide. IBKR's collapsed instructions identify Client Portal Gateway, the supported Java
runtime, localhost certificate verification, explicit `-EnableIbkrPaper`, exact
account binding, and its separate profile/history directory. Example paths and
account identifiers are clearly labeled and must be replaced.

## Official setup references

- [moomoo OpenD download](https://www.moomoo.com/download/OpenAPI)
- [moomoo OpenD overview](https://openapi.moomoo.com/moomoo-api-doc/en/opend/opend-intro.html)
- [IBKR TWS or IB Gateway](https://www.interactivebrokers.com/docs/tws-api/doc/download-tws-or-ib-gateway/download-tws-or-ib-gateway)
- [IBKR TWS API installation and Read-Only configuration](https://www.interactivebrokers.com/campus/trading-lessons/installing-configuring-tws-for-the-api/)

## Verification

Build the research-desk static overlay, then run `browser.cjs` with Node's `tsx`
loader. `LEO_BROKER_TEST_BASE` sets the fixture server origin (default port 3221).
`LEO_PLAYWRIGHT_MODULE` can point at an existing Playwright installation and
`LEO_BROKER_TEST_OUTPUT` overrides the receipt directory. Every
external request is intercepted; this test never authenticates to Google or a
broker and never submits an order.

Eleven browser groups cover guest and keyboard setup, Google PKCE, owner-scoped
computer rendering, expired and future reports, revoked devices, anonymous and
mismatched identity, expanded mobile IBKR commands, unconfigured linking, callback
non-authority, masked fresh/stale account rendering, reauthorization, explicit
top-level consent POST, disconnect isolation, and focus during a delayed
disconnect. Four `direct-link.test.ts`
unit checks cover schema and identity rejection, freshness, request destinations,
and aborted/failed calls. The final auth suite passed eleven groups, including
the broker callback and hostile return-path rejection.

Desktop and 390px mobile captures plus receipts are stored in
`platform/.impeccable/review/broker-link/`. The earlier `brokers/` directory is
historical evidence for the local-only surface. These injected fixtures establish
UI behavior; they do not prove hosted consent, broker operation, execution, or
profitability. Scoped TypeScript and the research-desk build passed.

The mechanical design detector found only advisory type-ramp drift inherited
from the existing research desk's sizes; no hard findings. Existing design
documents remain unchanged. Final deployment review also needs the downloadable
package gate checked against the actual release artifacts.
