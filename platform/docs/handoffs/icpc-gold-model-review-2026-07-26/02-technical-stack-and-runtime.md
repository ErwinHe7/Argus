# 02 — 技术栈与运行时

## 1. Rust：生产推理与实时数据边界

位置：`quant_engine_rs/`

核心版本与库：

- Rust 1.88，edition 2024；
- Axum 0.8：HTTP API；
- Tokio 1.49：异步运行时；
- tokio-tungstenite：实时 websocket；
- reqwest + rustls：HTTP/TLS；
- Databento Rust client；
- rusqlite：本地历史/研究档案；
- serde/serde_json/serde_yaml：合同与 artifact；
- chrono/chrono-tz：point-in-time 和交易时区；
- clap：`quantctl`；
- sha2：artifact、schema 和 evidence hash；
- tracing/tower-http：服务日志和 HTTP middleware。

Rust 应当唯一负责：

- 生产数据 freshness/coverage/entitlement validation；
- 生产特征计算；
- HMM、kernel、SDE/OU 与校准 artifact 推理；
- 模型/数据版本输出；
- fail-closed；
- forward prediction ledger 与 settlement。

当前技术债：

- crate 中没有 PostgreSQL driver；
- Massive live path 主要写 JSONL；
- Massive model 写入 pending prediction 后没有在同一 live loop 自动 settlement；

近期已修、仍需复核：

- Databento equities live supervisor 由 `quantd` 持有并监督；异常 return/panic 会使
  服务退出，`/ready` 对 stale/auth/entitlement/blocker 失败关闭；
- optional Massive SIP 与 OPRA 使用独立 readiness scope 和独立受监督子进程；
- prediction ledger 使用 schema v2 事务迁移、每 prediction 一个 settlement、
  业务语义幂等重试和不可变 payload 冲突检查；
- 单机容器通过共享持久 volume、`flock` singleton、`tini -g` 和完整 child wait
  防止静默多副本写入与孤儿进程；
- Massive 与 Moomoo live worker 已使用 `frozen_universe` exact-symbol loader；
- 每个缺失/损坏/target-mismatch artifact 会单独禁用对应 symbol；
- 不允许用 primary target 或 SPY artifact 给其他 symbol 兜底；
- registry path 已兼容 Windows 写入与 Linux container 读取。

## 2. Python：离线研究、训练和 artifact export

位置：`intraday_quant/`

核心版本与库：

- Python 3.11+；
- NumPy、pandas；
- PyArrow、Parquet；
- DuckDB；
- scikit-learn；
- Pydantic；
- exchange-calendars；
- FastAPI/Uvicorn（研究服务）；
- Matplotlib、tabulate；
- 可选 psycopg 3/PostgreSQL；
- PyTorch/CUDA 用于 TCN 与 MoE challenger。

Python 应当负责：

- point-in-time 数据构建；
- feature research；
- purged walk-forward；
- offline training/calibration；
- artifact export；
- neural challenger；
- OOS reports。

已修依赖边界：PyTorch 仅由显式 `neural` extra 安装；base 环境导入 neural
模块会给出明确的 missing-extra 错误，而不是把 Torch 伪装成基础依赖。

当前技术债：

- PostgreSQL 只是 optional dependency；
- 部分事件特征在 pipeline 中仍直接填 `False`，尚未接 point-in-time 日历；
- neural artifact 没有 Rust runtime；
- 单次 chronological split 不能替代 repeated purged walk-forward。

## 3. C++：独立 native research

位置：`quant_core_cpp/`

技术：

- C++20；
- CMake 3.24+；
- SQLite3；
- OpenSSL；
- warnings-as-errors；
- 原生 HMM、Logistic、kernel/paper OMS 研究组件。

边界：

- 不能在 TypeScript 中复制这些定量逻辑；
- 需要决定 C++ 是长期独立 benchmark，还是逐步退役；
- 当前存在与 Rust 重复的 HMM/Logistic/OMS，容易发生算法漂移。

## 4. TypeScript / Web

位置：`app/`、`components/`、`lib/`

技术：

- TypeScript 5.5；
- Next.js 14.2；
- React 18；
- Zod；
- Supabase；
- Redis/ioredis；
- LangGraph/LangChain/OpenAI；
- Sentry、PostHog；
- Paddle/Stripe；
- Tailwind CSS。

允许职责：

- UI；
- authentication/authorization；
- allow-listed natural-language query parsing；
- Rust API proxy；
- engine output explanation；
- telemetry 和 billing。

禁止职责：

- 在生产路径计算 probability、Greeks、GEX、expected return、risk 或套利经济学。

当前边界违规：

- TypeScript 中仍有 backtest、factor、stat-arb、ML long-short、web forecast 等
  定量模块被生产 route 调用；
- `/api/ask` 已走 Rust，但其他 route 仍需清理。

## 5. 数据栈

历史：

- append-only SQLite/PostgreSQL archive；
- CSV/JSONL/Parquet 研究输入与证据；
- 当前股票分钟档案约 3,577,530 bars；
- 时间范围约 2024-07-18 至 2026-07-24；
- 只能标记为 `RESEARCH_ONLY`，不能因为行数多就自动成为 production evidence。

实时：

- Massive websocket/REST adapter；
- Moomoo OpenD legacy feed；
- Databento historical adapter 与受监督 equities live adapter；
- JSONL spool/ledger；
- 目标持久层为 PostgreSQL。

必须统一的记录字段：

- source/provider；
- symbol 与 venue/schema；
- observed_at；
- available_at；
- received_at；
- freshness；
- coverage；
- entitlement；
- sequence/idempotency key；
- model/feature version；
- artifact SHA；
- material caveats。

## 6. 实时预测目标架构

```text
licensed live feed
        |
        v
normalized point-in-time record ----> append-only PostgreSQL
        |                                  ^
        v                                  |
Rust causal feature engine ---------- JSONL spool/WAL
        |
        +--> per-symbol immutable artifact registry
        |       |
        |       +--> HMM causal filter
        |       +--> same-regime kernel
        |       +--> SDE/OU shadow
        |       +--> promoted calibrator
        |
        v
versioned forecast + caveats + NO_TRADE reasons
        |
        v
pending prediction ledger
        |
        v
causal horizon settlement + forward OOS metrics
```

历史 replay 必须从 `normalized point-in-time record` 入口进入同一条路径。

## 7. 运行与验证

- Docker/container entrypoint；
- AWS 部署证据存在；
- Rust fmt/clippy/test；
- Python pytest；
- TypeScript typecheck/build；
- C++ CMake/CTest（本机 MSYS2 UCRT64 CMake/Ninja/GCC 与 VS Build Tools 均可用）。

Production promotion 必须同时需要代码检查、数据 readiness receipt 和 immutable
model/calibration receipt；单独 `health=200` 不足以证明模型进程正常。
