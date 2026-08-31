# AXIO7 Strategy Agents

AXIO7 is now a market strategy signal system. The live surface is `/market`; the strategy API is `/api/strategy/run`; the cron runner is `/api/cron/market-strategy`.

## Strategy Boundary

Allowed:
- Reuters/LSEG News API with valid commercial entitlements.
- Official X API v2 recent search / filtered stream credentials.
- Truth Social only through a licensed vendor or explicit webhook provider.
- Market tape from licensed providers such as Finnhub, Polygon, IEX, Databento, or equivalent.
- Public SEC EDGAR filings.
- Paper/live-signal generation with source links, evidence quality, invalidation rules, and audit logs.

Blocked:
- Material non-public information.
- Private direct messages, private groups, leaked documents, credentials, or confidential sources.
- Login, paywall, CAPTCHA, robots.txt, or API-term bypass.
- Broker order execution, account connection, portfolio-specific advice, or guaranteed returns.

## Production Connectors

```env
LSEG_CLIENT_ID=
LSEG_CLIENT_SECRET=
LSEG_NEWS_QUERY=
X_BEARER_TOKEN=
TRUTH_SOCIAL_PROVIDER_URL=
TRUTH_SOCIAL_PROVIDER_KEY=
FINNHUB_API_KEY=
NEWSAPI_KEY=
OPTIONS_FLOW_API_KEY=
MARKET_STRATEGY_WATCHLIST=NVDA,AMD,TSLA,PLTR,COIN,MSFT,AVGO
MARKET_STRATEGY_QUERY="Reuters breaking news, X influencer posts, Truth Social provider events, AI chips, Tesla, crypto, Fed rates, unusual market tape"
MARKET_CRON_SECRET=
```

Influencer exact-handle config:

```env
INFLUENCER_SERENITY_X=
INFLUENCER_SERENITY_TRUTH=
INFLUENCER_BREAD_X=
INFLUENCER_BREAD_TRUTH=
INFLUENCER_LABUBU_X=
INFLUENCER_LABUBU_TRUTH=
INFLUENCER_ELON_X=elonmusk
INFLUENCER_ELON_TRUTH=
```

## Runtime Modules

- `app/market/page.tsx`: production strategy console.
- `components/market/MarketIntelligenceConsole.tsx`: dense client-side strategy workbench.
- `app/api/strategy/run/route.ts`: strategy run API alias (POST).
- `app/api/strategy/execute/route.ts`: paper-mode execution (POST). Requires `acknowledgePaper: true`. Live broker is hard-disabled.
- `app/api/strategy/account/route.ts`: paper account, positions, and recent trade log (GET).
- `app/api/market/research/route.ts`: underlying research/strategy API (POST). Rate-limited and audited.
- `app/api/cron/market-strategy/route.ts`: cron-safe live-signal run. Validates `MARKET_CRON_SECRET` / `CRON_SECRET`.
- `app/api/health/route.ts`: production health check — broker mode, provider coverage, supabase reachability.
- `lib/market-intelligence/compliance.ts`: request gate and disclaimer.
- `lib/market-intelligence/sources.ts`: Reuters/LSEG, X, Truth vendor, tape, SEC, and news adapters.
- `lib/market-intelligence/engine.ts`: event ranking, strategy signal generation, agent findings, and risk frame.
- `lib/market-intelligence/broker.ts`: `BrokerAdapter` interface, `PaperBrokerAdapter`, `DisabledLiveBrokerAdapter`, and `resolveBrokerAdapter` selector.
- `lib/market-intelligence/brokers/alpaca.ts`: Alpaca paper + live REST adapter (BYO `APCA-API-KEY-ID` / `APCA-API-SECRET-KEY`).
- `lib/market-intelligence/brokers/ibkr.ts`: IBKR Client Portal Web API adapter (BYO `baseUrl` + `accountId` + optional session token).
- `lib/market-intelligence/broker-keys.ts`: per-user BYO key store. AES-256-GCM, master key in `BROKER_ENCRYPTION_KEY`. Persisted in Supabase `user_broker_keys` (see `supabase/migrations/014_user_broker_keys.sql`), encrypted at rest, RLS-scoped to the owning user.
- `lib/market-intelligence/sources.ts`: 10 providers — SEC EDGAR (public), X v2, Reuters/LSEG, Finnhub, NewsAPI, market tape, Truth vendor, options flow vendor, Polygon.io, Reddit OAuth.
- `app/api/strategy/broker-keys/route.ts`: GET/POST/DELETE BYO key. Live keys refused unless `LIVE_EXECUTION_ENABLED=true`.
- `app/api/strategy/confirm-execute/route.ts`: non-discretionary execution. Body must include `userConfirmedThesis` and `acknowledgeNotAdvice: true`. Routes user-confirmed orders into the user's own broker account; AXIO7 never custodies funds and never pools orders.
- `lib/market-intelligence/audit.ts`: append-only audit log. In-memory + optional Redis (`REDIS_URL`).
- `lib/market-intelligence/rate-limit.ts`: per-IP per-route rate buckets.

## Production Deployment

1. Set the env vars from `.env.example`. Required: Supabase trio + OpenAI compatible LLM. Optional but recommended for live signal coverage: `X_BEARER_TOKEN`, `FINNHUB_API_KEY`, `LSEG_CLIENT_ID/SECRET`, `NEWSAPI_KEY`, `REDIS_URL`, `MARKET_CRON_SECRET`.
2. Run `node scripts/check-market-env.mjs` to verify wiring before deploy.
3. `vercel.json` already schedules `/api/cron/market-strategy` every 15 minutes. Provide `MARKET_CRON_SECRET` and Vercel will pass it via `Authorization: Bearer ...`.
4. `.github/workflows/ci.yml` runs `typecheck` and `build` on every PR/push to `main`.
5. Hit `/api/health` after deploy to confirm broker mode, provider readiness, and Supabase reach.

## Output Contract

The API returns:
- `compliance`: allowed/blocked/caution assessment.
- `brief`: concise strategy summary.
- `decisionFrame`: monitor/investigate/stand down, confidence, rationale, and next checks.
- `signals`: paper/live-signal calls with action, score, confidence, thesis, invalidation, and source event ids.
- `agents`: source auditor, catalyst mapper, sentiment reader, and risk officer findings.
- `events`: ranked event list with source links, tickers, sentiment, confidence, materiality, verification, and evidence.
- `sources`: provider mesh and production credential status.
- `influencers`: Serenity, bread, 3x long labubu, and Elon Musk monitor configuration.
- `audit`: collection and reasoning trail.
