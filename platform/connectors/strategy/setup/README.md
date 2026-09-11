# Local broker prerequisites

Run `python broker_readiness.py --json` from this directory for a read-only local
report. It checks fixed loopback TCP endpoints, SDK package metadata and Windows
broker uninstall records. It does not read broker configuration, credentials,
logs, account IDs, balances or orders. A listening port is never labeled as an
authenticated broker or paper account. Portable installs and custom ports may
not be detected. Run the native package's offline self-check and then Leo's
account discovery separately.

For moomoo, install [OpenD](https://www.moomoo.com/download/OpenAPI) separately
from the moomoo desktop app. The connector pins `moomoo-api==10.10.7008` and the
vendor lists OpenD 10.10.7008 as the minimum for that SDK. Log into OpenD locally
and bind it to `127.0.0.1:11111`. Version 10.10 provides interactive login; do not
put a broker password in a script, command argument or website.

For IBKR execution, use the separate [Client Portal Gateway](https://download2.interactivebrokers.com/portal/clientportal.gw.zip)
with Java. Configure it for local-only access and provide a verified local TLS
certificate or an explicitly verified certificate fingerprint to Leo. The vendor
default certificate is not publicly trusted; disabling TLS verification is not a
setup step. Start the gateway, then sign into a paper account through
`https://localhost:5000`. IBKR requires manual browser reauthentication daily.
Leo must verify the broker's `isPaper` response before account discovery or orders.

On Windows, `start_clientportal.ps1 -GatewayDirectory 'C:\absolute\gateway'`
restarts an already prepared installation. It requires the local IP/TLS validation
receipt and checks the configuration, certificate and gateway JAR hashes before
launching. It refuses a duplicate listener. It does not create a certificate,
modify system trust or authenticate the user. Each computer needs its own verified
configuration and certificate; do not copy a paired or authenticated profile.

TWS and IB Gateway socket connections are different from Client Portal Gateway.
For optional socket inspection, select Paper Trading in TWS/IB Gateway and enable
the socket API for local connections. The default paper ports are 7497 (TWS) and
4002 (IB Gateway). Port numbers do not verify paper identity. Keep any live
environment disconnected from Leo.

The user must sign into the vendor application and approve the Leo device and
strategy mandate. Installing software does not connect a brokerage account or
start trading. Computer, vendor gateway and network must remain running for
local paper execution and software stops. A VPS is an optional always-on host,
not a replacement for broker authentication or supported OS credential storage.

Official references checked on 2026-09-11:

- [OpenD setup](https://openapi.moomoo.com/moomoo-api-doc/en/quick/opend-base.html)
- [OpenD interactive login](https://openapi.moomoo.com/moomoo-api-doc/en/opend/opend-cmd.html)
- [IBKR API settings and paper ports](https://www.interactivebrokers.com/campus/trading-lessons/installing-configuring-tws-for-the-api/)
- [Client Portal Gateway setup](https://www.interactivebrokers.com/campus/trading-lessons/launching-and-authenticating-the-gateway/)
- [Client Portal TLS and daily login](https://www.interactivebrokers.com/docs/web-api/authentication/cpgw/client-portal-gateway-faq)

Validation: `python -m unittest discover -s . -p 'test_*.py'`.
