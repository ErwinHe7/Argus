# Personal desktop web trading

The owner's September 5 follow-up changes the first milestone to their own
personal brokerage account through a desktop website, with at least one working
broker path. Implement moomoo OpenD first. Third-party partner onboarding is not
a prerequisite for this local personal integration. No mobile release is needed.

Inspect/reuse: official moomoo SDK and existing loopback gateway conventions;
the Leo investing workspace; current personal API documentation. Keep Rust model
and automated strategy execution gates unchanged.

Implementation: an opt-in loopback Python gateway with lazy SDK connection,
strict account selection, reads, immutable expiring order review and durable
single-submit confirmation; a local-only Next proxy and signed browser session;
web account/positions/order form; isolated SDK/runtime and startup script.
Secrets stay behind the proxy. Quantitative inference remains in Rust/Python.

Pass criteria: genuine SDK calls are wired; missing OpenD/login has a clear
recoverable state; exact account/environment, manual confirmation and persistent
unknown submission outcomes are enforced; tests never place real orders; the
browser can navigate connection, account and order review states. A user login
and any broker agreements must be completed by the owner. No fabricated account
data, automatic orders, public deployment or license-exemption claim.

Checks: SDK import, fake-provider service/journal safety tests, local proxy
origin/session/body allowlist tests, focused TypeScript, localhost API checks,
and browser verification. Real account status is reported only after the broker
returns it. Code readiness and a successful live login are distinct evidence.

## Use the personal webpage

The personal workspace runs at `http://127.0.0.1:3001/brokers`. Research and
the security directory remain available through the same navigation. The
existing port-3000 research preview stays separate from the personal process.

From `Argus/platform` in PowerShell:

```powershell
.\scripts\setup-personal-trading.ps1
.\scripts\start-personal-trading.ps1
```

The SDK setup is already complete on this computer. Install the official stable
[Windows OpenD GUI](https://www.moomoo.com/download/OpenAPI), sign in to the
owner's moomoo account, complete verification in OpenD, and keep its loopback
API running at `127.0.0.1:11111`. The ordinary moomoo desktop application alone
does not supply this OpenD endpoint. In the webpage, choose **Find my accounts**,
select an eligible account and its Paper/Real environment, then connect it.

Default startup permits paper trading and real-account reads. To enable the
owner's manually confirmed real orders, stop only this workspace and restart:

```powershell
.\scripts\stop-personal-trading.ps1
.\scripts\start-personal-trading.ps1 -AllowLiveTrading
```

Each ticket requires a symbol, Buy/Sell, whole-share quantity and a USD limit
price. Review the exact account and order, tick the review checkbox, then use
the explicit **Confirm paper order** or **Confirm real order** button yourself.
The default single-order notional cap is USD 500, excluding fees; configure it
at startup using `-MaxOrderNotional`. This version supports U.S. equity/ETF DAY
limit orders during regular hours, with long-position sells. Cancellation and
modification remain in moomoo's own interface.

Real submissions require any trading unlock requested by moomoo. Prefer its
OpenD unlock window; the webpage also offers a local password form. The model
does not submit trades automatically. A submitted response is not a fill.

The gateway journal and Windows-DPAPI-protected local key live under ignored
`platform/.quant-runtime/personal-moomoo/`. Keep both across restarts. The
webpage persists an opaque pending-review ID to recover uncertain submissions.
**Check order status** reads/reconciles the existing command without resubmitting.
When no command was ever claimed, **Discard unused review** atomically revokes
that preview before permitting another ticket. An unknown broker outcome stays
blocked if the available broker history cannot prove its disposition; this
version has no manual override.

## Verified on September 5, 2026

- Official stable `moomoo-api==10.9.6908` installed in an isolated Python 3.13
  environment; SDK import and dependency checks passed.
- Official stable OpenD 10.9.6918 downloaded with a valid Moomoo Technologies
  Inc. Authenticode signature. Windows reported installer startup cancelled.
  Installation/login is incomplete; no OpenD listener was present.
- 37 Python tests passed using an injected fake SDK, covering concurrent
  confirmation, durable unknown outcomes, account/environment validation,
  Decimal amounts, password-cache clearing and atomic preview discard.
- Four TypeScript boundary test groups and the focused TypeScript check passed.
- Runtime HTTP checks passed: page/frame protection, signed local session,
  SDK availability, rejected cross-site/missing-session/malformed-amount
  requests, and 404 on the non-personal port-3000 process.
- Browser verified SDK ready, account discovery and the actionable missing-OpenD
  response. Desktop 1440px, user 1280px and mobile 390px layouts were inspected
  without document-width overflow.
- Actual accounts, holdings and broker order acknowledgement remain unverified
  until the owner finishes OpenD login. No real or broker-paper order was sent.

IBKR and Webull remain follow-on personal API integrations. This milestone
implements the moomoo SDK path; it does not claim the other brokers are
connected or that a public multi-user deployment is ready.
