# AXIO7 Data Sources — Per-Source Owner's Manual

配套文档：`docs/market-intelligence-prd-architecture.md` §5 + §22。
本文件是十个 source 的逐个深度说明：每个 source 的 free tier 实际限额、paid tier 起步价、License 注意点、抽取字段、authentication 设置、坑、以及 free→paid 的迁移路径。

> **价格、限额、ToS 都会变化。** 本文件的数字基于 2026-05-24 公开报价。生产前必须以 vendor dashboard 为准；任何报价超过 $500/月的支出必须 founder 签字。

---

## 总览：决策矩阵

| # | Source | Tier | v1 默认 | 月成本 | 谁拿数据决策 | 阻塞？ |
|---|---|---|---|---:|---|---|
| 1 | Reuters / LSEG | S | 不接（fixture only） | $0 → bespoke $1K–$4K | founder（要付费） | 不阻塞 v1 |
| 2 | 主流财经新闻 | A | NewsAPI free + Polygon free + Finnhub free + GDELT + HN | $0 → $79+ | 工程师 | ✅ 已能跑 |
| 3 | 官方政府宏观 | S | FRED + 公共 RSS | $0 | 工程师 | ✅ 已能跑 |
| 4 | SEC EDGAR | S | 公共 API | $0 | 工程师 | ✅ 已能跑 |
| 5 | X 关键账号 | B | fixture / manual | $0 → $200+ | founder（要预算） | 决策见 §5 |
| 6 | Truth Social | B | manual paste | $0 → vendor | founder | 决策见 §6 |
| 7 | 美股行情 | A | Finnhub free / Polygon free（15min delayed） | $0 → $79+ | founder | ✅ 已能跑 |
| 8 | 期权链 / OPRA | A | Polygon snapshot free | $0 → $79+ → OPRA $3K+ | founder | ✅ 已能跑 |
| 9 | 券商上下文 | A | Alpaca paper / IBKR paper | $0 | user (BYO) | ✅ 已能跑 |
| 10 | 社区 / 另类信号 | C | Reddit OAuth + GDELT/HN | $0 → vendor | founder | ✅ 已能跑 |

---

## 1. Reuters / LSEG (Machine Readable News)

**Tier：S** | **Adapter：** `lib/market-intelligence/sources.ts` → `fetchLsegReutersNews` | **类别：** 机构新闻 wire

### Free tier 实况

**没有免费 tier。** LSEG Data Platform 是企业级授权产品，最便宜的合同往往要走 sales。没有"申个 dev key 试试"的路径。

### Paid tier

| 产品 | 月成本（估算）| 说明 |
|---|---|---|
| LSEG Data Library news headlines | $1,000–$4,000+ | bespoke pricing；按 entitlement 类别（real-time、tick history、selective）|
| Machine Readable News (MRN) real-time | $4,000–$10,000+ | 含 tick history，可机器消费 |
| MRN selective + 国家/板块限制 | 更低 | 谈判中可定制 |

### 我们抽取的字段

```text
headline, summary, storyId, versionCreated, firstCreated,
provider=LSEG, riskFlags=["Licensed Reuters/LSEG content; respect entitlements"]
```

### 替代方案（v1）

- **NewsAPI** 可拉 Reuters 已发表的网页（间接、延迟、不全）
- **Polygon news** 也常有 Reuters 转发
- **GDELT** 抓 Reuters 已 indexed 的 web 版（**不是** wire，延迟数分钟到小时）

### License 注意

LSEG 内容**严禁**：
- 公开 redistribution（即使付费给我们，也不能 forward 给非授权终端用户）
- 用于训练 LLM
- 缓存超过合同约定时间

`riskFlags` 已经在 adapter 里标了。生产部署前必须有法务一次过审。

### 迁移路径

P0–P2：跳过；用 NewsAPI + Polygon news 替代。
P3：如果产品已经验证有 paying users 想要 Reuters 真线，再走 LSEG 销售流程。

### 参考

- https://developers.lseg.com/en/article-catalog/article/lseg-data-library-for-python--news-pagination
- https://www.lseg.com.cn/content/dam/data-analytics/en_us/documents/fact-sheets/machine-readable-news-real-time-optimized-and-tick-history-factsheet.pdf

---

## 2. 主流财经新闻聚合

**Tier：A** | **Adapter：** 多个 (`fetchFinnhubNews`, `fetchOtherNews`, `fetchPolygonNews`) | **类别：** 二级新闻聚合

实际上是**四个独立 source 的组合**：NewsAPI、Finnhub、Polygon、GDELT/HN。每个都有自己的 free tier。

### 2a. NewsAPI

- **Free tier**：100 req/day（**dev only**，禁止生产）+ 文章只有 24h 内
- **Developer plan**：$0（同上）
- **Business**：$449/月，250K req/月，无延迟
- 限制：免费 tier 文章末尾会被 NewsAPI 截断
- **Adapter：** `fetchOtherNews`，env：`NEWSAPI_KEY` + `MARKET_NEWS_QUERY`
- 参考：https://newsapi.org/pricing

### 2b. Finnhub

- **Free tier**：60 req/min，无月限；company-news 端点免费
- **Starter**：$50/月，30 req/min（**更低**？看官方文档；historicals 增加）
- **Pro**：$200/月，websocket + 高频
- **Enterprise**：bespoke
- **Adapter：** `fetchFinnhubNews`，env：`FINNHUB_API_KEY`
- 参考：https://finnhub.io/pricing

### 2c. Polygon news

- **Basic free**：5 req/min，无 historicals
- **Stocks Starter**：$79/月，无限 req/min，含 news 端点
- **Stocks Advanced**：$199/月，含 WebSocket
- **Adapter：** `fetchPolygonNews`，env：`POLYGON_API_KEY`
- 参考：https://polygon.io/pricing

### 2d. GDELT + HackerNews（news-pulse）

- **GDELT**：完全免费，无 key，世界级新闻索引（含 Reuters / AP / WSJ 转载页）
- **HackerNews**：完全免费，无 key，技术圈关注的事件
- **Adapter：** `lib/market-intelligence/news-pulse.ts`
- 参考：https://blog.gdeltproject.org/  +  https://github.com/HackerNews/API

### 推荐 v1 组合

NewsAPI free + Polygon free + Finnhub free + GDELT + HN = **$0**，覆盖：
- 30 分钟内的全球财经头条
- 公司层面新闻（per-ticker）
- 技术圈关注事件
- 不含 Reuters wire 的延迟版

升级触发：当 free tier rate limit 在生产时段持续触发 → 升 Polygon Starter $79，干掉 Polygon free 的 5 req/min 瓶颈。

---

## 3. 官方政府 / 宏观

**Tier：S** | **Adapter：** `lib/market-intelligence/macro.ts`（部分）| **类别：** 完全公开

全部免费。子源：

| 源 | 内容 | 接入 | env |
|---|---|---|---|
| FRED (St. Louis Fed) | 全美宏观指标（CPI、失业、GDP、Fed Funds 等） | REST API，需 free key | `FRED_API_KEY` |
| Federal Reserve (Fed.gov) | FOMC statements、minutes、speeches | RSS | none |
| White House | Executive orders、briefings | RSS / press feed | none |
| US Treasury | yield curve、auctions | data.treasury.gov public | none |
| BLS | CPI、PPI、jobs report | api.bls.gov free key | `BLS_API_KEY` |
| BEA | GDP 详细 | api.bea.gov free key | `BEA_API_KEY` |
| EIA | 能源价格、库存 | api.eia.gov free key | `EIA_API_KEY` |
| CME FedWatch | rate cut probabilities | public widget; scrape 风险，建议看 page only | n/a |

### v1 推荐

FRED + Fed RSS + Treasury → **$0**。其他按需补。FedWatch 不要 scrape，作为 manual reference link 即可。

### 参考

- FRED API: https://fred.stlouisfed.org/docs/api/fred/
- BLS API: https://www.bls.gov/developers/
- BEA API: https://apps.bea.gov/api/signup/
- EIA API: https://www.eia.gov/opendata/

---

## 4. SEC EDGAR

**Tier：S** | **Adapter：** `lib/market-intelligence/sources.ts` → `fetchSecFilings` | **类别：** 完全公开

完全免费。SEC 要求每个调用方在 User-Agent header 标识 contact email（fair-access policy）：

```env
SEC_USER_AGENT=AXIO7 Market Intelligence <contact@axio7.com>
```

### 当前覆盖

`KNOWN_CIKS` 在 `sources.ts` 里硬编码 13 个大票：AAPL、AMD、AMZN、AVGO、COIN、GOOGL、META、MSFT、NFLX、NVDA、PLTR、SMCI、TSLA。

### 抽取

```text
Material forms only: 8-K, 10-Q, 10-K, S-1, S-3, 424B5, DEF 14A, SC 13G, SC 13D
title = "{ticker} filed {form}"
url   = https://www.sec.gov/Archives/edgar/data/{cik}/{accession}/{primaryDoc}
```

### v1 缺口

1. CIK 表硬编码——需要扩到 watchlist 任意 ticker（SEC 提供 `company_tickers.json` 全量表）
2. 只查最近 24 条；Form 4 insider 在 `insider.ts` 单独处理
3. 没有 8-K item-level 细分（item 1.01 vs 7.01 vs 8.01 是完全不同的信号）

### 速率限制

SEC 公共 API：**10 req/sec per IP**。超过会被 ban。当前 adapter 串行处理 8 个 ticker，安全。

### 参考

- SEC EDGAR APIs: https://www.sec.gov/search-filings/edgar-application-programming-interfaces
- Fair access: https://www.sec.gov/about/developer-resources
- Company tickers: https://www.sec.gov/files/company_tickers.json

---

## 5. X 关键账号 — 含 Trump

**Tier：B** | **Adapter：** `lib/market-intelligence/sources.ts` → `fetchXInfluencerAndKeywordEvents` | **类别：** 社交

### Free tier 实况

X API 是 pay-per-use 模式（2024 年改革后）。"免费 tier" 现在叫 **Free**：

- **Free**：1,500 reads/月 + 500 posts/月 + **1 个 app**。读取计数严格。
- **Basic**：$200/月，10K reads/月。
- **Pro**：$5,000/月，1M reads/月 + filtered stream。
- **Enterprise**：bespoke，> $42K/月起。

**注意**：免费 1500 reads 算的是 **resource**，不是请求。一次 `recent search` 返回 25 条 tweet = 25 reads。所以免费 tier 实际上够看 ~60 次 search calls/月。完全不适合生产，但能跑 demo。

### 四模式（在主文档 §5.3 已详细列）

| Mode | env | 适用 |
|---|---|---|
| `fixture` | 不需要 token | Day-0 dev |
| `manual` | 不需要 token | UI 粘贴 |
| `search_adapter` | 不需要 token | 通过 NewsAPI/Polygon 搜引用页 |
| `official_api` | `X_BEARER_TOKEN` | 生产；必须配预算 |

### Trump 账号专项

`@realDonaldTrump` 现在活跃于 X（也在 Truth Social）。在 X 上：

- 是公开账号，X API 可读
- 高 engagement，会消耗 quota 快
- 与 Truth 内容会重复发——AXIO7 需要 dedupe（用 `payload_hash` 或 text similarity > 0.85）

### 预算硬上限机制

实际实现在主文档 §5.3，简述：

```text
preflight: estimated_cost > limit ? block
request: call → store ids → dedupe
reconcile: query usage endpoint → update provider_usage → alert at 50/80/95%
```

新增 `provider_usage` 表（已在主文档 §5.3 给出 schema）。

### v1 推荐

1. **Week 1**：`X_SOURCE_MODE=fixture`，跑 demo
2. **Week 2**：切 `manual`，让 founder 粘贴 Trump 几条历史 tweet 测整链路
3. **Week 3**：申请 X Free tier dev account，切 `official_api`，`X_SPEND_LIMIT_USD=10` 硬上限
4. **Month 2 if 有效**：升 Basic $200/月，watchlist 扩到 10–20 个 handles

### License 注意

- 不要把 X 抓的 tweet 完整内容公开 redistribute（只在 UI 内显示给登录用户）
- 不要训练模型用 tweet 全文
- Tweet 删除后，AXIO7 在 7 天内必须从 cache 移除（X ToS 要求）

### 参考

- https://docs.x.com/x-api/introduction
- https://docs.x.com/x-api/getting-started/pricing
- https://docs.x.com/x-api/fundamentals/rate-limits
- ToS: https://x.com/en/tos

---

## 6. Truth Social — 含 Trump

**Tier：B** | **Adapter：** `lib/market-intelligence/sources.ts` → `fetchTruthVendorEvents` | **类别：** 社交

### 现实

**Truth Social 没有公开开发者 API。** v1 不假设能直接读。

### 三条可行路径

| 路径 | 状态 | v1 推荐 | 说明 |
|---|---|---|---|
| **A. Manual paste** | 永远可用 | ✅ **默认** | 用户 → manual event → 入 pipeline。完全合规 |
| **B. 公共 RSS**（`truthsocial.com/@user.rss`）| 不稳定 | ⚠️ 需调查 | 部分账号曾有 RSS；要逐个验证 ToS 允许且 endpoint 稳定 |
| **C. 授权 vendor** | 商业可行 | 🔜 P2 if 有需求 | Dataminr (instituional)、Bloomberg Terminal、专业政治情报 vendor |

### Path A — Manual（v1 走这个）

```env
TRUTH_SOURCE_MODE=manual
TRUTH_WATCHLIST=realDonaldTrump
```

实现：
1. 用户在 `/market/manual` 粘贴 URL 或文本
2. 服务端调用 `POST /api/market/events/manual`
3. 进 `market_raw_events` → 走和 X 一样的归一化 + entity extraction
4. 标 `source: truth_social`, `source_access: manual`

### Path B — RSS 调查清单

如果要试 RSS，**部署前**必须验证：

```text
☐ curl https://truthsocial.com/@realDonaldTrump.rss 返回 200 + 有效 XML
☐ 检查 Truth Social ToS (https://help.truthsocial.com/legal/terms-of-service/) 明确允许 feed reader 访问
☐ 测 7 天稳定性（每小时拉，记录 200/4xx/5xx 比例 ≥ 95% 成功）
☐ 法务审过 redistribution 边界
```

任一项失败 → 不上 RSS。

### Path C — Vendor 选项

| Vendor | 起步价 | 覆盖 | 备注 |
|---|---:|---|---|
| Dataminr | bespoke, $$$$ | 全 social + news real-time，含 Truth | 主要卖金融机构 |
| Bloomberg Terminal | $25K/年 user | Trump Truth 在 BBG `TRUM <GO>` | 单 user 贵但全套 |
| 专业政治情报 vendor (PolitiPro 等) | bespoke | 政治 social listening | 不够 fintech-focused |

**v1 推荐：跳过 vendor。** 用 manual paste，省 $1K–25K/年。等 P2 再评估。

### Trump on X vs Truth — 去重

`@realDonaldTrump` 经常同一条消息发两个平台。AXIO7 处理：

```ts
// lib/market-intelligence/dedupe.ts (待建)
// 同一个 influencer.id (= 'trump') 的两条 post：
//   - 时间相差 < 30 分钟
//   - 文本相似度 > 0.85 (使用简单 Jaccard 或 OpenAI embedding cosine)
// → 合并为一条 event, source = "x+truth"
```

### License 注意

Truth Social ToS 不允许批量抓取或 scraping。Path B (RSS) 是灰色，必须法务确认。Path A 完全干净（用户输入是公开授权）。

### 参考

- Truth Social terms: https://help.truthsocial.com/legal/terms-of-service/
- Truth Social help: https://help.truthsocial.com/

---

## 7. 美股行情

**Tier：A** | **Adapter：** `lib/market-intelligence/sources.ts` → `fetchMarketTape` + `lib/market-intelligence/order-flow.ts` | **类别：** market data

子源：

### 7a. Finnhub quote

- **Free**：60 req/min，real-time US stocks
- **Starter**：$50/月，30 req/sec（适合 watchlist 高频轮询）
- **Pro**：$200/月，websocket 推送
- **Adapter：** `fetchMarketTape`（已实现）

### 7b. Polygon stocks

- **Free**：5 req/min，**15 分钟延迟**
- **Stocks Starter**：$79/月，real-time NBBO，无限 req
- **Stocks Advanced**：$199/月，+ WebSocket
- **Stocks Business**：$1,499/月，全套 + tick-level
- **Adapter：** 在 `order-flow.ts` 间接使用

### 7c. Yahoo Finance（unofficial）

- **Free**：通过 `yfinance` 或 RapidAPI Yahoo 包；**non-official**
- **限制**：rate-limit 严格，可能突然 ban
- **生产警告**：不要靠 Yahoo 做生产，只做 fallback

### 7d. IBKR（用户自带）

- **成本**：$0 if 用户已有 IBKR 账户
- **限制**：要 Client Portal Web API + session
- **Broker adapter：** `lib/market-intelligence/brokers/ibkr.ts`
- **Market-data connector：** `lib/market-intelligence/ibkr-client-portal.ts`
- **Env：** `IBKR_BASE_URL`, `IBKR_MARKET_DATA_ENABLED=true`, optional `IBKR_SESSION_TOKEN`, `IBKR_ALLOW_INSECURE_TLS=true`
- **API routes：** `/api/market/ibkr/health`, `/api/market/order-flow`, `/api/market/options`
- **Reality check：** Client Portal 适合 conid lookup、股票 quote、期权 top-of-book bid/ask；逐合约 OI/Max Pain/GEX 仍需要 Polygon/OPRA/Databento/ORATS 这类 OI-capable feed。
- 适合：BYO key 高级用户

### 7e. Databento（institutional）

- **起步**：$30/月 historical sample；real-time tick $200+/月
- 适合 P3，不是 v1

### v1 推荐

Finnhub free + Polygon free + Yahoo fallback → **$0**。日成交时段 quote 延迟 1–5 秒，能接受。

升级触发：当需要 OPRA tape 或 dealer hedging 信号时（P3 决策）。

### 参考

- Finnhub: https://finnhub.io/pricing
- Polygon: https://polygon.io/pricing
- Databento: https://databento.com/pricing
- IBKR Client Portal: https://www.interactivebrokers.com/api/doc.html

---

## 8. 期权链 / OPRA

**Tier：A** | **Adapter：** `lib/market-intelligence/options.ts` | **类别：** options data

### Free tier

- **Polygon Free**：5 req/min，**unified snapshot 端点免费但有延迟**。每次 snapshot 返回完整 chain（per-expiry）
- **Yahoo Finance**：unofficial，免费 but unreliable
- **CBOE delayed**：网页可看，无 API

### Paid tier

| 产品 | 月成本 | 说明 |
|---|---:|---|
| Polygon Options Starter | $79 | unified snapshot + history，real-time delayed 15min |
| Polygon Options Advanced | $199 | real-time NBBO + WebSocket |
| Databento OPRA equity options | $200–$2,000+ | full OPRA tape |
| ORATS | $99–$499 | 期权波动率分析（IV surface、HV）专项 |
| LiveVol Pro | $500+ | 期权策略专项 |
| Cboe DataShop | bespoke | 历史 + real-time |

### 我们要抽取

```text
per-contract: strike, expiry, kind, bid, ask, mid, volume, OI, IV, delta, gamma, theta, vega
derived:      total_oi, call_put_ratio, max_pain, call_wall, put_wall,
              atm_iv, expected_move, IV_rank, term_structure
```

Max pain / call wall / put wall 在 `options.ts` 应该已实现（need to verify）。

### v1 推荐

Polygon free unified snapshot 一天拉几次 + Yahoo fallback。延迟 15min 对 swing trading 够用。

升级触发：
- 想做日内 IV crush 分析 → Polygon Options Starter $79
- 想做 gamma squeeze 实时探测 → Polygon Options Advanced $199 或 Databento OPRA

### License 注意

Polygon 重新打包 OPRA 数据；非生产环境无 license 要求，生产前看 ToS。Databento 直发 OPRA，受 OPRA SIPC 协议约束（$3K+/月 OPRA fees 隐含成本，不在 vendor 报价里）。

### 参考

- Polygon options: https://www.polygon.io/docs/options
- Polygon options unified snapshot: https://polygon.io/docs/rest/options/snapshots/unified-snapshot
- Databento OPRA pricing: https://databento.com/blog/introducing-new-opra-pricing-plans
- OPRA: https://www.opraplan.com/

---

## 9. Broker Context

**Tier：A** | **Adapter：** `lib/market-intelligence/broker.ts` + `brokers/alpaca.ts` + `brokers/ibkr.ts` | **类别：** account state

### 已实现

| Broker | 模式 | 状态 |
|---|---|---|
| Alpaca paper | paper-only | ✅ |
| Alpaca live | live (BYO key) | ✅ but `LIVE_EXECUTION_ENABLED` 默认 false |
| IBKR Client Portal | read + paper + (live BYO) | ✅ 同上 |
| TastyTrade | – | 未实现 |
| Schwab | – | 未实现 |
| Tradier | – | 未实现 |

### 安全模型

`lib/market-intelligence/broker-keys.ts`：
- AES-256-GCM，master key in env `BROKER_ENCRYPTION_KEY`
- 持久化在 `user_broker_keys` 表（migration 014）
- RLS 限定 `auth.uid() = user_id`
- live key **被拒绝**，除非 `LIVE_EXECUTION_ENABLED=true`

### 实盘执行流

`POST /api/strategy/confirm-execute`：
- 必传 `userConfirmedThesis: string`
- 必传 `acknowledgeNotAdvice: true`
- 服务端**不**汇总订单
- 服务端**不**托管资金
- 仅做 routing：把用户的订单送到**用户自己的** broker 账户

### v1 推荐

Alpaca paper 自带 → 默认。
用户 BYO IBKR key → 用 read-only mode 看持仓 + paper。
**不开 live execution**，除非有明确审计和创始人书面授权。

### License

- Alpaca API 免费（含 paper + live）
- IBKR Client Portal 免费 if 用户已是 IBKR 客户
- Schwab/TastyTrade 要 OAuth + developer enrollment

### 参考

- Alpaca: https://docs.alpaca.markets/
- IBKR Client Portal: https://www.interactivebrokers.com/api/doc.html

---

## 10. 社区 / 另类信号

**Tier：C** | **Adapter：** `lib/market-intelligence/sources.ts` → `fetchRedditPosts` 等 | **类别：** social listening

### 子源

| 源 | 接入 | 月成本 | 状态 |
|---|---|---:|---|
| Reddit | OAuth | $0 | ✅ 已实现 (`REDDIT_CLIENT_ID/SECRET/USER_AGENT`) |
| HackerNews | public | $0 | ✅ (`news-pulse.ts`) |
| GDELT | public | $0 | ✅ (`news-pulse.ts`) |
| Substack | RSS per author | $0 | ❌ 待建 |
| YouTube | YT Data API v3 | $0 (10K quota/day) | ❌ 待建 |
| Stocktwits | 公开 API | $0 (deprecated/限制) | ❌ |
| Google Trends | unofficial via pytrends | $0 (rate limited) | ❌ |
| Bluesky | AT Protocol public | $0 | ❌ 可能值得加 |

### Reddit subs（当前）

```env
REDDIT_SUBS=wallstreetbets,options,stocks,investing,SPACs,cryptocurrency
```

### Tier C 处理规则

所有 C 源的事件：
- 默认 `confidence ≤ 65`
- `riskFlags` 必有 "Retail social signal; corroborate with filings/news before escalating"
- 不进推送 alert，除非有 S/A 源同时命中
- materiality 默认低；高 engagement (score + comments) 才会拉到 ≥ 50

### v1 推荐

Reddit + HN + GDELT 已能用。
Substack / YouTube 在 P2 加（要影响特定 KOL 时再说）。
Stocktwits / Google Trends 跳过（前者基本死了，后者不稳定）。

### 参考

- Reddit OAuth: https://github.com/reddit-archive/reddit/wiki/OAuth2
- HN API: https://github.com/HackerNews/API
- GDELT: https://blog.gdeltproject.org/
- Bluesky AT Protocol: https://atproto.com/

---

## 附录 A：v1 启动包（4 周内完整跑通的免费组合）

按下面这套 env 启动，**月成本 < $50**，能跑完整 demo：

```env
# Required
OPENAI_API_KEY=
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
REDIS_URL=
BROKER_ENCRYPTION_KEY=

# Source — free tier all
FINNHUB_API_KEY=                  # 申请 finnhub.io free key
NEWSAPI_KEY=                      # 申请 newsapi.org free key  
POLYGON_API_KEY=                  # 申请 polygon.io free key
FRED_API_KEY=                     # 申请 fred.stlouisfed.org/docs/api/api_key.html
REDDIT_CLIENT_ID=
REDDIT_CLIENT_SECRET=
REDDIT_USER_AGENT=AXIO7-MarketIntel/1.0
SEC_USER_AGENT=AXIO7 Market Intelligence <你的邮箱>

# X — Day 1 用 fixture
X_SOURCE_MODE=fixture

# Truth — Day 1 用 manual
TRUTH_SOURCE_MODE=manual

# Watchlist
MARKET_STRATEGY_WATCHLIST=NVDA,AMD,AVGO,MSFT,GOOGL,META,TSLA,PLTR,COIN,IBM

# Cron
MARKET_CRON_SECRET=<随机 64 字符>

# 不开 live
LIVE_EXECUTION_ENABLED=false
```

申请所有 free key 大约 1 小时（每个网站填 email + 用途）。SEC / FRED / Reddit 都立即发 key；NewsAPI / Finnhub / Polygon 即时。

---

## 附录 B：Tier 升级触发条件

不要凭感觉付费。每个升级要有明确触发：

| Source | 触发升级的条件 | 升级到 |
|---|---|---|
| NewsAPI free → paid | 单日 > 100 req（free 上限） | Polygon Starter $79 替代 |
| Polygon free → Starter | 5 req/min 在交易时段持续触发 rate limit | $79/月 |
| Finnhub free → Starter | 60 req/min 在 watchlist > 30 票时触发 | $50/月 |
| X fixture → Basic | manual mode 验证有效 + founder 同意月预算 ≥ $200 | $200/月 |
| Truth manual → vendor | manual paste 频率 > 5次/天 + founder 同意 $1K+/月 | Dataminr |
| Polygon options free → Starter | 想做日内 IV 分析 | $79/月 |
| 全套升 Pro | 日活用户 ≥ 50 | $2K+/月 |
| OPRA full | trading desk 级别需求 | $10K+/月，启 P3 |

每条都进 `docs/PRD.md` §25 决策表（创始人需签字）。

---

## 附录 C：合规快速参考

| Source | 公共 / 授权 | redistribute? | LLM train OK? | 缓存上限 |
|---|---|---|---|---|
| SEC | 公共 | 是 | 是 | 无限 |
| FRED / 政府 | 公共 | 是 | 是 | 无限 |
| Reddit OAuth | 授权 | 部分（attribution） | 看 ToS | 30 天 |
| HN / GDELT | 公共 | 是 | 是 | 无限 |
| NewsAPI | 授权 | **不** | **不** | 24h |
| Polygon | 授权 | **不**（终端用户限定）| **不** | 看合同 |
| Finnhub | 授权 | **不** | **不** | 看合同 |
| LSEG / Reuters | 授权 | **严格禁止** | **严格禁止** | 严格按合同 |
| X | 授权 | **限内部 UI** | **不** | 7 天 if 删除 |
| Truth (manual) | 用户输入 | 看输入来源 | 看输入来源 | 用户自定 |
| Truth (vendor) | 授权 | **不** | **不** | 看合同 |

任何 "redistribute? = 不" 的 source，AXIO7 UI 只能给登录用户看。public 页面（如 marketing site）不可显示原文。

---

## 附录 D：变更日志

| 日期 | 变更 |
|---|---|
| 2026-05-24 | 初版。配合 `market-intelligence-prd-architecture.md` v1.0 |
