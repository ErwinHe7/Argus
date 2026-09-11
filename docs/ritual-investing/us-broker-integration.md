# US broker connection implementation

Updated 2026-09-05. Launch scope is US users trading manually in their own
brokerage accounts. Existing personal broker accounts are not evidence that
the platform has third-party authorization. No live account is connected by
the provider catalog, and automatic execution remains disabled.

## What the implementation exposes

`GET /v1/brokerage/providers` uses the existing member bearer authentication and
rate limit, returns an explicit `BrokerageProviderCatalogResponse`, and performs
no broker or database access. The pure `getBrokerageProviderCatalog()` export is
also available for server-rendered setup pages. `connection_available` and
`manual_orders_available` are false for all three brokers. Presence of a secret
or environment variable cannot change either field.

| Broker | Existing implementation | Next dependency |
| --- | --- | --- |
| IBKR | No retained third-party account/order adapter. Legacy personal gateway code is a separate product surface. | Apply for third-party access, receive the registered application's integration details, implement the approved adapter, and verify paper trading. |
| moomoo | OAuth contract groundwork is separate from a live connection or order adapter. | Register the application and callback for OAuth 2.1 with PKCE; verify US account eligibility and trading scopes, secure token custody, and test account/order behavior. The cited public setup page does not establish a partner-approval prerequisite. |
| Webull | Fixture-validated OAuth state, encrypted token/account custody, refresh/disconnect lifecycle, reads, manual preview/confirm/cancel/reconciliation, and Flutter screens. Production binds blocked providers. | Obtain Webull Connect approval and resolve the versioned contract requirements, then bind the provider and pass hosted sandbox checks. |

Official setup references: [IBKR Web API](https://www.interactivebrokers.com/docs/web-api/getting-started),
[moomoo getting started](https://open.moomoo.com/api/overview/getting-started),
[Webull Connect](https://developer.webull.com/apis/docs/connect-api/about-connect-api/).
Webull's exact outstanding protocol and fixture requirements are in
[webull-connect-contract.md](webull-connect-contract.md).

## Existing contracts to reuse

The retained Webull route names below are deliberately unchanged. Do not route
IBKR or moomoo into them by substituting a provider string: their connection
tables, completion return targets, and account capabilities are Webull-specific.
Generalize owner-scoped connection identity and adapters only when implementing
the next broker's approved contract, preserving the existing custody and replay
protections.

| Operation | Existing route | Input and guarantees |
| --- | --- | --- |
| Start Webull authorization | `POST /v1/brokerage/connections/start` | `{ "return_target": "webull_https" }` or `webull_native`. Validates provider contract before persisting hashed, session-bound one-use state. |
| Redeem callback completion | `POST /v1/brokerage/connections/completions/redeem` | `{ "completion": "opaque_handle" }`. Expires after five minutes and is bound to the originating user and session. |
| Review a manual order | `POST /v1/brokerage/accounts/{account_id}/orders/previews` | `{ "instrument_id": "owned_instrument_uuid", "side": "buy", "order_type": "limit", "time_in_force": "day", "quantity": "1", "limit_price": "100.00" }`. Whole shares; market/limit; day only. Market orders require `limit_price: null`. |
| Confirm a reviewed order | `POST /v1/brokerage/accounts/{account_id}/orders` | `Idempotency-Key` header plus `{ "preview_id": "review_uuid", "confirmed": true, "intent": { ...the_same_reviewed_intent } }`. Checks current capabilities/restrictions and matching review, persists before one submission, and reconciles ambiguous outcomes without blind retry. |
| Inspect command state | `GET /v1/brokerage/order-commands/{command_id}` | Owner-scoped redacted state; accepted acknowledgement is distinct from a fill. |

The reusable service boundary is `BrokerageOrderProvider` in
`ritual-investing-api/src/domains/brokerage-orders/service.ts`: `preview`,
`execute`, `detail`, and `list`. Its repository and fresh account authority must
remain scoped to the same user, connection, account, and instrument as the
review. Research outputs may preselect a symbol for the user; they do not create
order intent or imply confirmation. Account restrictions, stale capabilities,
expired reviews, and ambiguous provider responses fail closed.

The catalog is an additive API contract. Its generated Dart client must be
regenerated together with the other pending Market Map API additions before a
mobile API release. The current Next setup surface imports the pure catalog
and does not depend on generated Dart types.
