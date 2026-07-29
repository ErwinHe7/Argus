# axio7-market-mcp

Local MCP (Model Context Protocol) server that exposes AXIO7's market
intelligence and options analytics to any MCP client — Claude Desktop, Claude
Code, Codex, custom agents.

Read-only by default. Only one write tool (`ingest_manual_event`) which
accepts user-pasted public text. No vendor secrets touched. No live broker
execution exposed.

---

## What you get inside Claude

After install, ask Claude things like:

- "Use AXIO7 to pull NVDA — what's the max pain this Friday and where are the
   call/put walls?"
- "Search market news for tariff or export control headlines from the last 24h
   and tell me which semiconductor tickers are affected."
- "I just saw a Trump post saying X. Ingest it and tell me what to watch."
- "Give me the macro panel — what's the 10Y-2Y, Fed Funds, CPI right now?"
- "Are all data sources healthy? What's in fixture mode?"

Claude will call the matching tool, get real data from your AXIO7 backend,
and reason on it instead of hallucinating.

---

## Install

### 1. Build the server

```bash
cd scripts/mcp/axio7-market-mcp
npm install
npm run build
```

Output: `dist/index.js` (executable).

### 2. Decide which backend to point at

| Backend | Use when | Env |
|---|---|---|
| Local dev | You're editing AXIO7 and want to see your changes | `AXIO7_API_BASE_URL=http://localhost:3000` |
| Production | You want live signals | `AXIO7_API_BASE_URL=https://axio7.com` (default) |

### 3. Wire into Claude Desktop

Open `claude_desktop_config.json`:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

Add (or merge) this entry — replace the absolute path with where you cloned
the repo:

```json
{
  "mcpServers": {
    "axio7-market": {
      "command": "node",
      "args": [
        "C:\\Users\\hegua\\Desktop\\StartupProduct\\AgenticWorld\\Axio7\\scripts\\mcp\\axio7-market-mcp\\dist\\index.js"
      ],
      "env": {
        "AXIO7_API_BASE_URL": "https://axio7.com"
      }
    }
  }
}
```

Restart Claude Desktop. You should see `axio7-market` show up in the MCP
indicator. Click it to inspect the 10 tools.

### 4. Wire into Claude Code

Same idea — edit `~/.claude.json` (or workspace `.claude/config.json`):

```json
{
  "mcpServers": {
    "axio7-market": {
      "command": "node",
      "args": ["./scripts/mcp/axio7-market-mcp/dist/index.js"]
    }
  }
}
```

### 5. (Optional) Wire into Codex / VS Code agents

Codex CLI supports MCP via `~/.codex/config.toml`:

```toml
[mcp_servers.axio7_market]
command = "node"
args = ["/abs/path/to/Axio7/scripts/mcp/axio7-market-mcp/dist/index.js"]

  [mcp_servers.axio7_market.env]
  AXIO7_API_BASE_URL = "https://axio7.com"
```

---

## Tools

| Name | Type | Description |
|---|---|---|
| `search_market_news` | read | Ranked events across all 10 sources, filtered by query + watchlist. Returns sentiment, materiality, confidence, evidence URLs. |
| `get_market_signals` | read | Macro/breadth dashboard: VIX, F&G, indices, sectors, themes, composite bottom score. |
| `get_ticker_brief` | read | Full per-ticker view: price/RSI/SMA, news catalysts, SEC Form 4, options summary, lognormal distribution this week, model strategy candidates. |
| `get_options_chain` | read | Full options analytics: spot, provider, top 10 OI, top 10 calls, top 10 puts, max pain, gamma exposure, squeeze regime, flow pressure. |
| `get_max_pain_and_walls` | read | Tight projection of the chain — just max pain strike + call wall + put wall + squeeze label. |
| `get_news_pulse` | read | Free-tier news pulse: HN front-page + GDELT global index. No paid keys needed. |
| `get_macro_panel` | read | US macro from FRED: yield spread, Fed Funds, CPI, unemployment, M2, DXY, recession signals. |
| `get_insider_filings` | read | SEC Form 4 insider activity per ticker (last ~90 days). |
| `get_source_health` | read | Status of all 10+ sources: live/fixture/manual/disabled, X spend limits, monitored influencer handles. |
| `ingest_manual_event` | **write** | Paste an X/Truth/Reuters/SEC URL or text — AXIO7 normalizes, maps tickers, scores materiality, returns "next checks". |

### What's deliberately NOT exposed

- `POST /api/strategy/execute` (paper order placement)
- `POST /api/strategy/confirm-execute` (real broker routing)
- `GET/POST/DELETE /api/strategy/broker-keys` (BYO key management)

Reason: live execution and broker key management must go through the AXIO7 web
UI with explicit per-action confirmation. MCP is for research, not trading.

---

## Env vars

```env
# AXIO7 backend
AXIO7_API_BASE_URL=https://axio7.com     # or http://localhost:3000 for dev
AXIO7_API_TOKEN=                          # optional bearer for per-user routes
AXIO7_API_TIMEOUT_MS=25000                # default 25s
AXIO7_API_USER_AGENT=axio7-market-mcp/0.1.0
```

---

## Smoke test (without an MCP client)

```bash
# Build first
npm run build

# Manual stdio probe — sends ListTools, dumps the response, exits.
node -e "import('./dist/index.js')" &
PID=$!
sleep 1
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' > /proc/$PID/fd/0 2>/dev/null
kill $PID
```

Easier path: just install into Claude Desktop and ask Claude to "list the
axio7-market tools".

---

## Security posture

- stdio transport only. Server lifecycle owned by the MCP client (Claude
  Desktop spawns and kills it).
- No vendor API keys stored in this package. All Reuters/X/Polygon/etc. keys
  live in the AXIO7 backend's env; MCP only forwards HTTPS requests to it.
- One write endpoint, which accepts only user-supplied public text (no
  arbitrary SQL, no key rotation, no broker calls).
- Audit: every successful or failed AXIO7 HTTP call is logged on the backend
  side via `lib/market-intelligence/audit.ts`.

---

## Files

```
scripts/mcp/axio7-market-mcp/
├── package.json
├── tsconfig.json
├── .gitignore
├── README.md
└── src/
    ├── index.ts     stdio MCP entry
    ├── client.ts    HTTPS client → AXIO7 API
    └── tools.ts     10 tool definitions + handlers
```
