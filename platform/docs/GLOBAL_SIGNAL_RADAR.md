# Global Quant Signal Radar

## Objective

Build a professional-source event-driven risk radar for global markets.

The system does not try to predict every black swan. It detects observable fragility and triggers:

```txt
Crowded positioning + macro shock + liquidity stress + mega-cap event + global lead-lag
```

Output is a risk regime, scored drivers, affected assets, and defensive action. It is not an automatic trading instruction.

## Production Data Policy

No delayed retail data can be a primary intraday alert source.

Every event must preserve:

- `sourceId`
- `sourceTier`
- `publishedAt`
- `receivedAt`
- `latencyMs`
- `confirmationStatus`
- `affectedAssets`
- `severity`
- `confidence`

Source tiers:

```txt
T0 = official / exchange / SEC / company wire
T1 = professional realtime vendor
T2 = broker feed / account truth
T3 = social / retail / rumor discovery
T4 = delayed retail fallback
```

Hard rules:

- T3/T4 cannot trigger RED alerts by themselves.
- Rumors must remain `reported_not_confirmed` until T0/T1 confirms.
- IBKR is used for broker-side quote/account/margin/execution truth, not as the only news or OPRA source.
- Yahoo-style data is disabled for intraday alerts and reserved for backtests/historical context only.

## MVP Providers

Critical first wave:

- SEC EDGAR official polling
- sec-api.io Stream API
- Company wire APIs: BusinessWire / PRNewswire / GlobeNewswire
- Benzinga News API
- Trading Economics or Econoday
- OPRA options vendor: Intrinio / Cboe LiveVol / Databento
- IBKR Client Portal or TWS API
- Databento or Polygon/Massive websocket tape
- Coinglass plus exchange websockets

## Public First-Source Mesh

Public sources are split into two groups:

```txt
Official first-source = can confirm the event
Public media / aggregator = can discover or contextualize, but cannot confirm alone
```

Wired in `/api/quant/global-signals`:

| Source | Tier | Role | Alert role |
|---|---:|---|---|
| SEC EDGAR | T0 | filings, offerings, insider forms, 8-K/S-3/424B5 | can confirm |
| Federal Reserve RSS | T0 | FOMC, speeches, supervision, official Fed communications | can confirm |
| Federal Register API | T0 | rules, notices, tariffs, export controls, public-inspection docs | can confirm |
| BLS Public Data API | T0 | CPI, payrolls, wages, employment series | official data, needs consensus feed for surprise |
| BEA API | T0 | GDP, PCE, income/spending, profits | official data |
| EIA API | T0 | crude/gas/electricity/inventory data | official energy data |
| Treasury / OFAC | T0 | sanctions, debt, Treasury announcements | can confirm when stable feed is configured |
| White House | T0 | executive statements/orders and policy | can confirm when stable feed is configured |
| USTR | T0 | tariffs and trade-policy actions | can confirm when stable feed is configured |
| Company IR feeds | T0 | issuer press releases / IR feeds | can confirm when issuer-owned |
| New York Times API | T3 | quality public journalism and geopolitical context | context only |
| GDELT | T3 | global news discovery / velocity | discovery only |
| Jin10 | T3 | fast Chinese-language market headline aggregation | discovery only |

Environment:

```txt
PUBLIC_OFFICIAL_RSS_FEEDS=https://issuer-or-agency-feed.example/rss
TREASURY_OFFICIAL_FEED_URL=
WHITE_HOUSE_FEED_URL=
USTR_FEED_URL=
BLS_PUBLIC_API_ENABLED=false
BLS_API_KEY=
BEA_API_KEY=
EIA_API_KEY=
NYT_API_KEY=
NYT_SIGNAL_QUERY="Federal Reserve OR Treasury OR sanctions OR tariffs OR Iran OR China OR Nvidia OR Meta OR semiconductors OR oil OR dollar"
JIN10_API_KEY=
JIN10_FEED_URL=
```

The agent now adds `impactAssessment` to each normalized event:

- `bias`: bullish / bearish / mixed / neutral
- `horizon`: intraday / 1-3d / multi-week
- `reasoning`: why the event is likely positive or negative
- `historicalAnalogs`: same-type historical reaction templates and what to check next

Examples:

- Equity financing / convertible / offering: usually bearish first for issuer due to supply/dilution unless proceeds de-risk the company.
- Fed / CPI / payrolls: bullish or bearish depends on whether the path lowers or raises front-end yields; DXY + 2Y up together is rate/liquidity pressure.
- Sanctions / Iran / military escalation: usually risk-off for high beta, supportive for oil/defense/USD/gold if tape confirms.
- Tariff / export controls: usually first-order bearish for exposed supply chains, semis, China beta, autos, retailers, or affected industrials.

## Scoring

```txt
MarketRiskScore =
  0.25 * MacroHawkScore
+ 0.20 * LeverageUnwindScore
+ 0.15 * GlobalContagionScore
+ 0.15 * MegaCapShockScore
+ 0.10 * OptionsStressScore
+ 0.10 * LiquidityStressScore
+ 0.05 * NewsVelocityScore
```

Risk levels:

```txt
0-30   GREEN
30-50  LIGHT_YELLOW
50-70  YELLOW
70-85  ORANGE
85-100 RED
```

RED is capped below 85 unless there is at least one high-confidence T0/T1 or market-confirmed T2 source.

## Routes

- Dashboard: `/quant/global-signals`
- API: `/api/quant/global-signals`
- Price anomaly API: `/api/quant/price-anomalies`
- Alert cron: `/api/cron/global-signal-alerts`

API options:

```txt
/api/quant/global-signals?replay=false
/api/quant/global-signals?tickers=NVDA,META,AVGO,MU,QQQ
/api/quant/price-anomalies?tickers=META,NVDA,AVGO,MU,SMH,SOXX,QQQ
```

## Price-Led Anomaly Engine

The station now starts with abnormal tape, not headlines.

```txt
Price/flow anomaly -> cause attribution -> historical analog -> paper/recommendation action
```

Inputs:

- Nasdaq TotalView / direct depth for Nasdaq order-book imbalance and depth depletion.
- Databento for normalized equities/futures/options when entitled.
- Polygon or Massive for an executable MVP feed: last trade, NBBO, large prints, and premarket US equities.
- Moomoo OpenAPI / OpenD as an optional familiar quote/trade gateway.
- IBKR for broker-side quote/account/margin confirmation and user-owned execution bridge.

Yahoo-style delayed retail data is blocked from this engine. If none of the professional feeds are configured, the station returns `provider_missing` or replay examples instead of pretending it has live tape.

Environment:

```txt
PRICE_ANOMALY_ENABLED=true
PRICE_ANOMALY_WATCHLIST=META,NVDA,AVGO,MU,SNDK,SMH,SOXX,QQQ
NASDAQ_TOTALVIEW_ENABLED=false
NASDAQ_TOTALVIEW_WS_URL=
NASDAQ_TOTALVIEW_API_KEY=
DATABENTO_API_KEY=
POLYGON_API_KEY=
MASSIVE_API_KEY=
IBKR_MARKET_DATA_ENABLED=false
EXECUTION_PRIMARY_PLATFORM=moomoo
MOOMOO_OPEND_HOST=127.0.0.1
MOOMOO_OPEND_PORT=11111
MOOMOO_MARKET_DATA_ENABLED=false
MOOMOO_TRADE_ENABLED=false
ANOMALY_AUTO_PAPER_ENABLED=false
ANOMALY_LIVE_ORDER_ENABLED=false
```

Scoring:

```txt
AnomalyScore =
  price displacement vs previous close
+ VWAP distance
+ relative move vs QQQ/SMH/SOXX/SPY
+ NBBO spread / depth imbalance / print pressure
+ confirmed event match from SEC, company wire, newswire, macro, or public official feed
```

Interpretation:

- `ORANGE/RED` with no headline = price-led unknown. Check SEC, company IR, company wires, Benzinga/newswire, options skew, and peers before acting.
- `ORANGE/RED` with T0/T1 event match = headline-confirmed anomaly. Compare to same-type history such as offering shock, macro surprise, sanctions/tariff shock, or Korea semiconductor contagion.
- Replay examples never trigger alerts.

## Nasdaq Order Book / TotalView

Yes, the system can connect Nasdaq depth, but not through a generic public website. You need one of:

- Nasdaq TotalView direct-feed entitlement and a licensed handler/vendor endpoint.
- A vendor that redistributes Nasdaq depth under your entitlement.
- Databento/Polygon/Massive/IBKR as lower-friction stepping stones, depending on plan and exchange permissions.

For production, prefer:

```txt
Nasdaq TotalView/ITCH or vendor depth -> anomaly engine
Databento/Polygon/Massive -> MVP US tape confirmation
IBKR -> account, margin, quote sanity check, and user-confirmed order route
```

## Execution Boundary

The price anomaly engine does not submit live orders by itself.

Current behavior:

- Moomoo manual execution mode by default.
- Each anomaly signal generates a manual order ticket: ticker, side, order style, trigger, invalidation, size hint, checklist, and warnings.
- Paper automation can be enabled separately with `ANOMALY_AUTO_PAPER_ENABLED=true`.
- Live execution remains locked unless `LIVE_EXECUTION_ENABLED=true`, broker keys are stored, compliance review is complete, and the existing user-confirmed `/api/strategy/confirm-execute` route is used.

This keeps the system useful for fast reaction while avoiding silent discretionary live trading.

### Moomoo vs IBKR Practical Read

Use the platform you can operate cleanly under stress.

Moomoo is a reasonable execution front end if that is where your funds and muscle memory are. Moomoo/Futu OpenAPI uses a local OpenD gateway plus SDKs and exposes market data and trading services, so AXIO7 can prepare for a Moomoo-first workflow without forcing an IBKR migration.

IBKR has advantages for institutional-style workflows:

- broader multi-asset/global broker infrastructure
- mature API ecosystem across TWS, Client Portal/Web API, FIX, and account/margin endpoints
- useful broker-side truth for account, margin, positions, and routing

But switching broker UI during a fast market is its own risk. The current production workflow is therefore:

```txt
AXIO7 signal -> Moomoo manual ticket -> you verify in Moomoo -> you decide/enter order
IBKR optional -> data/account/execution research once you are comfortable
```

Do not use IBKR for live execution until you have practiced in paper/small size and understand order entry, extended-hours behavior, buying power, margin, and cancel/replace flow.

## Korea Memory / US Semiconductor Premarket Playbook

The first production checklist is the Korea memory lead-lag chain:

- SK Hynix open performance
- Samsung confirmation
- KOSPI / KOSDAQ breadth
- KRW / USDKRW stress
- Hynix limit-down or near limit-down behavior
- NQ futures
- SOXX / SMH premarket tape
- MU / SNDK / AVGO premarket tape
- SMH / SOXX put skew and options stress

Interpretation:

- If Korea does not collapse, US semiconductors may repair into the US session.
- If Korea opens directly into liquidation and Hynix/Samsung cannot hold, MU/SNDK/SMH/SOXX/NQ likely face pressure.
- If buying the semiconductor dip, do not rush the first wave. Better confirmation is: no second-leg Korea liquidation, US semis do not break the prior low, put skew starts mean-reverting, and NQ/SMH reclaim the key trend line or overnight VWAP.
- If shorting, do not chase the low. Wait for key structure to break. Prefer defined-risk structures such as put spread, bear call spread, small SMH/SOXX put spread, or waiting for a rebound to short. Naked puts after IV expansion can be hurt by rebound plus IV crush.

Professional sources to wire for this checklist:

- `KRX_API_KEY`, `KOREA_MARKET_FEED_URL`, or `IBKR_KOREA_MARKET_DATA_ENABLED=true`
- `CME_FUTURES_FEED_URL` or `DATABENTO_API_KEY` for NQ futures
- `NASDAQ_TOTALVIEW_API_KEY`, `DATABENTO_API_KEY`, `POLYGON_API_KEY`, `MASSIVE_API_KEY`, or `IBKR_MARKET_DATA_ENABLED=true` for US premarket semis
- `OPRA_VENDOR`, `INTRINIO_API_KEY`, `CBOE_LIVEVOL_API_KEY`, or `DATABENTO_API_KEY` for options skew

## Automatic Alerts

Alerts are disabled by default. Turn them on only after delivery targets and professional feeds are configured.

Environment:

```txt
GLOBAL_SIGNAL_ALERTS_ENABLED=true
GLOBAL_SIGNAL_ALERT_MIN_LEVEL=ORANGE
GLOBAL_SIGNAL_ALERT_MIN_SCORE=70
GLOBAL_SIGNAL_ALERT_COOLDOWN_MINUTES=30
GLOBAL_SIGNAL_ALERT_SECRET=<random secret>
GLOBAL_SIGNAL_ALERT_WEBHOOK_URL=<optional webhook>
TELEGRAM_BOT_TOKEN=<optional telegram bot token>
TELEGRAM_CHAT_ID=<optional telegram chat id>
REDIS_URL=<optional cooldown persistence>
```

Behavior:

- Vercel Cron runs a daily weekday heartbeat on Hobby accounts. Vercel Pro can change this to every 5 minutes.
- GitHub Actions workflow `.github/workflows/global-signal-alerts.yml` calls `/api/cron/global-signal-alerts` every 5 minutes on weekdays as the deployable low-cost scheduler.
- Alerts only use live events, not replay casebook events.
- A live alert requires the configured minimum level and score, unless a high-severity live event is present.
- Redis enables persistent cooldown dedupe. Without Redis, the route can still send but cannot persist cooldown across instances.
- `?force=true&secret=...` can be used for a delivery test.

GitHub Secrets for the 5-minute scheduler:

```txt
GLOBAL_SIGNAL_ALERT_URL=https://axio7.com/api/cron/global-signal-alerts
GLOBAL_SIGNAL_ALERT_SECRET=<same value as Vercel GLOBAL_SIGNAL_ALERT_SECRET>
```

## Next Implementation Steps

1. Add websocket ingestion for Databento/Polygon/Benzinga/sec-api.
2. Store normalized events in Supabase or Redis.
3. Add Vercel Cron polling for SEC and macro calendar if webhooks are unavailable.
4. Add email / push notification targets next to Telegram and webhook.
5. Add postmortem labels so model scores can be evaluated after each session.
