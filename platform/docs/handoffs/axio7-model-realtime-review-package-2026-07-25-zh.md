# AXIO7 模型与实时数据审查交接包

日期：2026-07-25（America/New_York）
接收方：外部模型/数据工程审查与竞标方
结论级别：代码审计；不是模型晋升批准
产品边界：非个性化市场研究；不下单；不把方向性 setup 称为无风险套利

## 1. 请接收方解决什么

目标不是继续堆静态 CSV、复制历史行情行，或把几百行样例数据写进代码。

目标是完成这一条可审计闭环：

```text
授权的历史数据 + 授权的实时流
  -> append-only point-in-time market store
  -> finalized-bar causal features
  -> immutable per-symbol model artifact
  -> realtime shadow inference
  -> prediction ledger
  -> automatic realized-outcome settlement
  -> repeated walk-forward + 60–90 trading-day forward shadow
  -> reviewed promotion registry
  -> public research API
```

每条数据至少保留：

- `event_at`：市场事件时间；
- `available_at`：当时首次可用于决策的时间；
- `recorded_at`：AXIO7 实际落库时间；
- provider、dataset、source hash、coverage、quality；
- license scope 和可核验的 license reference。

不允许：

- Yahoo、synthetic、延迟数据冒充实时数据；
- 用当前抓取时间替代历史可用时间；
- 把 raw analog frequency 写成 calibrated probability；
- 在 TypeScript、LLM 或 UI 中重新计算概率、Greeks、GEX、收益或风险；
- 为了“有输出”而绕过缺失、陈旧、覆盖率或授权门控。

## 2. 审计结论

AXIO7 已经具备研究系统的主要组件，但还不是可公开声称“实时预测已验证”的生产模型。

已有：

- Rust 线上定量引擎、严格查询合同、数据 freshness/coverage/license 门控；
- 约 357.8 万条分钟级股票历史记录的 append-only SQLite/PostgreSQL 存档；
- 九个目标/代理标的的 Rust frozen candidate artifacts；
- Massive 股票 WebSocket、期权 chain、增量特征和 shadow inference 代码；
- prediction ledger、settlement 数据结构和 promotion gate；
- Python/CUDA 离线候选模型及 untouched chronological test；
- 自动执行全局关闭。

当前不能公开激活：

- 当前 Massive 账户没有股票 WebSocket、SIP snapshot 或九个完整 OPRA chain entitlement；
- `data/live/massive_stream_status.json` 和 `massive_inference_status.json` 不存在，说明当前没有 Massive 实时推理运行收据；
- 九个 Rust artifacts 全部是 `CANDIDATE_NOT_PROMOTED`；
- 校准状态为 `UNAVAILABLE_FAIL_CLOSED`；
- neural candidates 也是 `CANDIDATE_NOT_PROMOTED`；
- 没有 60–90 个交易日的已结算 forward-shadow 证据；
- 没有可用的 pinned promotion registry artifact；
- 期权历史没有完整 NBBO、逐笔 trade、合约级 OI 及其 availability lineage。

正确的当前公开状态是 `DATA_UNAVAILABLE` 或 raw descriptive research，不是生产概率。

## 3. 当前模型与算法清单

| 模型/算法 | 实现位置 | 当前角色 | 审计结论 |
| --- | --- | --- | --- |
| Clock-time、momentum、reversal、VWAP baselines | Rust/Python/C++ | 必须击败的基准 | 保留；不能被复杂模型绕过 |
| Regularized Logistic classifier | Python、Rust、C++ | 方向基准 | 已实现；不是当前公开线上 ensemble |
| Ridge regression | Python | return/MFE/MAE baseline | 离线研究 |
| Histogram Gradient Boosting | Python | 分类和回归 challenger | 已实现；不是 LightGBM/XGBoost |
| Rust gradient-boosted heads | `quant_engine_rs/src/engine/models.rs` | native supervised research | 尚无已晋升线上 artifact |
| Diagonal-Gaussian HMM | Rust/C++ | causal regime filter | Rust frozen artifact 的核心在线组件 |
| Same-regime analog kernel | Rust (`quant_engine_rs/src/analog_engine/mod.rs`) | 历史条件分布、raw frequency、OOD | Rust frozen artifact 的核心在线组件；无校准时不能输出概率 |
| Legacy exploratory Euclidean analog | Python (`intraday_quant/models/analog_kernel.py`) | 显式 opt-in 的离线诊断 | 与 Rust 在缩放、度量、特征、带宽、regime/邻居约束和 `k` 上均不等价；默认关闭，禁止进入 trade blotter 或 promotion evidence |
| Markov-switching log-return diffusion | Rust | short-horizon shadow distribution | v2 artifact 中存在；decision-neutral |
| VWAP residual Ornstein-Uhlenbeck process | Rust | VWAP residual shadow head | v2 artifact 中存在；decision-neutral |
| Regime-conditioned momentum head | Rust | continuation/reversal shadow head | v2 artifact 中存在；decision-neutral |
| Causal TCN | Python/PyTorch/CUDA | 54,896 参数 challenger | 离线 candidate；未进入 Rust runtime |
| Regime-gated distributional TCN / 4-expert MoE | Python/PyTorch/CUDA | 160,224 参数 challenger | 离线 candidate；未进入 Rust runtime |
| Causal last-query attention | Python/PyTorch | MoE temporal pooling | 只在 candidate 中 |
| Student-t return distribution | Python/PyTorch；Rust regime competition 有 Student-t research | heavy-tail output/research | 未晋升 |
| Platt calibration | Rust/Python | validation-only calibration | 已实现；当前线上无匹配晋升 artifact |
| Isotonic calibration | Python | validation-only calibration | 已实现；当前线上无匹配晋升 artifact |
| TVTP-HMM | Rust | time-varying transition regime research | 未接入公开实时 API |
| Gaussian/Student-t/HSMM competition | Rust | regime family comparison | CLI/research，不是生产 committee |
| GMM | Rust | regime/cluster challenger | research/test |
| Pattern/motif discovery、matrix profile、FDR/negative controls | Rust | hypothesis discovery | 不能替代独立 OOS 和 forward shadow |
| Gamma convexity aggregation | Rust | unsigned exposure + explicit sign scenarios | 确定性研究计算，不是 squeeze probability |
| Closing short-cover hazard | Rust | causal hazard research | 未晋升为公开方向模型 |
| Kalman/OU/stat-arb、RSI、technical scores | TypeScript legacy | 旧研究/UI 路径 | 违反当前 runtime ownership，应隔离或迁移 |
| C++ Logistic/HMM/analog/paper OMS | `quant_core_cpp/` | native research prototype | 与 Rust 重复；需保留性能热点或退役 |

上述三个语言中的 analog 代码不是同一个估计量的等价重写。生产/冻结 artifact
所称的 same-regime analog 只指 Rust 实现；Python 旧实现的稳定标识为
`legacy_exploratory_euclidean_analog`，仅供显式离线探索。

明确不存在于实现代码：

- Bayesian/Naive Bayes production model；
- Bayesian online change-point implementation；
- LSTM；
- GRU；
- LightGBM；
- XGBoost；
- CatBoost。

这些名称有些出现在路线图或研究建议里，但不能对外说“已经实现并用于模型”。

## 4. 模型证据现状

### 4.1 Rust frozen universe

目标：

`SPX, QQQ, NVDA, AAPL, MU, SOXX, NBIS, BE, IGV`

其中 SPX 的方向和 VWAP 使用明确标注的 SPY proxy；不能把 SPY 静默写成 SPX cash index。

九个 v2 artifact：

- model family：`same-regime-kernel+cv-selected-hmm+regime-sde-shadow-frozen-v2`；
- horizons：5/15/30/60 分钟；
- 全部 `CANDIDATE_NOT_PROMOTED`；
- 全部选择 8-state HMM；
- 全部报告 `BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K`；
- 全部报告 `STATE_COUNT_OPTIMUM_IS_NOT_ESTABLISHED`；
- 全部 calibration 为 `UNAVAILABLE_FAIL_CLOSED`。

这意味着 8-state 是搜索边界结果，不是已证明的真实状态数。接收方必须用多 fold 稳定性、状态占比/持续时间、跨 seed 一致性和下游增量效用重新比较，不得根据最大 likelihood 直接晋升。

### 4.2 Neural candidates

原始 causal TCN untouched test：

| Horizon | AUC | Brier gain vs validation-prevalence baseline | Return IC |
| --- | ---: | ---: | ---: |
| 5m | 0.5603 | +0.00314 | +0.0423 |
| 15m | 0.5298 | +0.00085 | -0.0140 |
| 30m | 0.5080 | -0.00023 | +0.0378 |
| 60m | 0.5080 | +0.00001 | +0.0258 |

Regime-gated MoE TCN untouched test：

| Horizon | Direction AUC | Direction Brier gain | Return IC | VWAP-cross AUC |
| --- | ---: | ---: | ---: | ---: |
| 5m | 0.5542 | +0.00237 | +0.0285 | 0.8480 |
| 15m | 0.5242 | -0.00003 | +0.0185 | 0.8491 |
| 30m | 0.5005 | -0.00136 | +0.0078 | 0.8365 |
| 60m | 0.4940 | -0.00154 | +0.0255 | 0.8021 |

结论：

- 方向模型没有形成跨 horizon 的稳定优势；
- MoE 更像 VWAP-event challenger，不是通用方向预测器；
- 单一 chronological split 不能替代 repeated purged walk-forward；
- 在完成多 fold、多 seed、成本、drift 和 forward shadow 之前，不要花时间把 neural checkpoint 接到生产 Rust。

### 4.3 Gamma

当前可确认的历史 options 数据只支持非常有限的研究：

- 一次 NVDA 到期切片；
- 210 Call 和 Put 各 390 个一分钟 aggregate，共 780 行；
- 没有 historical consolidated NBBO；
- 没有逐笔 trade；
- 没有 contract-level OI；
- OCC 免费文件只进入 market-total context table，不能写入 contract OI 表。

所以当前 gamma 只能是 fail-closed 的结构计算代码，不能做可信 historical gamma replay，更不能输出 squeeze probability。

## 5. 历史 + 实时架构现状

### 历史层

- SQLite 和 PostgreSQL 已有 append-only minute-bar schema；
- equity minute bars 约 357.8 万行；
- coverage 约 2024-07-18 至 2026-07-24；
- 数据 license scope 为 `RESEARCH_ONLY`；
- Python neural training从 PostgreSQL 读取 point-in-time cutoff；
- Rust frozen artifacts 当前仍从 normalized CSV/market store materialization 生成。

### 实时层

代码支持：

- Massive authenticated WebSocket；
- finalized one-minute `AM` bar；
- stale/delayed rejection；
- synchronized context；
- incremental causal features；
- frozen Rust inference；
- optional point-in-time option chain；
- SLA gate；
- prediction ledger。

实际运行状态：

- Massive stock WebSocket：`NOT_ENTITLED`；
- Massive SIP snapshot：HTTP 403；
- 九个 OPRA full-chain probe：HTTP 403；
- `production_ready=false`；
- 没有当前 Massive stream/inference status；
- 旧 Moomoo 只证明 Nasdaq Basic/TotalView/ArcaBook quote protocol，不是 consolidated SIP NBBO。

## 6. 必须交付的高价值问题

### AXIO7-MODEL-01 — P0：用 universe registry 替换单标的旧 artifact 实时路径

证据：

- `massive-model` 默认只加载 `data/models/frozen_predictor_latest.json`；
- 该文件是 SPY、v1、10-state、无 short-horizon head；
- 当前九标的 registry 是 v2、8-state；
- `massive-model` 只使用 `config.research.target=SPY`；
- per-target registry 目前只被 API 展示，没有被实时推理编排器消费。

要求：

- 按 public/model/price/options/VWAP mapping 创建 per-target runtime；
- 每个标的加载 registry 指定 artifact，校验文件 hash、model hash、config hash、feature schema、training cutoff；
- 同一个 synchronized finalized-bar cutoff 生成该标的 5/15/30/60 分钟 contract；
- SPX/ SPY proxy 必须显式保留；
- 任一标的缺 artifact、错 hash、错 config、缺 context 时只对该标的 fail closed，不可回退到 SPY 或旧 latest 文件。

验收：

- 九标的 integration test；
- artifact/config mismatch test；
- missing-symbol/context-skew test；
- registry hash tamper test；
- 每个输出带正确 symbol、source、cutoff、availability、model/feature/data hashes。

### AXIO7-DATA-02 — P0：拆分 equity、options 和 setup-specific readiness

证据：

- container entrypoint 只有 `massive-check` 全部通过才启动 `massive-model`；
- 当前 `production_ready` 同时要求股票实时和所有 OPRA chain；
- 这会让只需 equities 的 momentum/VWAP 因 OPRA 未授权而无法运行。

要求：

- 独立 readiness：`equity_realtime_ready`、`options_realtime_ready`、
  `options_ready_by_underlying`；gamma 仍由完整 chain/OI/Greeks 的专项 gate 单独判定；
- momentum/VWAP/opening/closing 只依赖 equities + context；
- gamma 单独依赖完整 OPRA/definitions/OI/Greeks/underlying；
- 不允许一个标的的 options 缺口拖垮无关标的的 equity shadow capture。

验收：

- equity-only entitlement 可以运行 equity shadow，gamma 返回 `DATA_UNAVAILABLE`；
- OPRA 缺失不会停止 equity archive；
- 每个 setup 返回自己的 blocker 和 coverage。

### AXIO7-DATA-03 — P0：接入具有公开使用授权的实时 equities provider

证据：

- 当前 Massive individual credential 不具备所需 entitlement/redistribution；
- 数据决策建议先采购 Databento EQUS.MINI；
- 仓库只有 Databento historical download/DBN decode，没有 live stream adapter。

要求：

- 在采购和书面许可确认后，实现 provider-neutral live adapter；
- 先支持 finalized minute bar 所需的 trade/BBO/aggregate 字段；
- 保存 raw provider event 和 normalized event；
- 记录 source sequence、event/receive/finalize 时间、gap/correction；
- 不把 derived composite、single-venue 或 indicative feed写成 SIP/OPRA。

验收：

- entitlement receipt；
- reconnect、duplicate、out-of-order、gap、late correction、stale、clock-skew tests；
- 真实开市 smoke receipt；
- 数据许可 reference 和 coverage 写入每次 prediction。

### AXIO7-DATA-04 — P0：把实时 archive 持续写入 PostgreSQL

证据：

- Massive live 当前写 JSONL 和 prediction ledger；
- PostgreSQL 是历史/连续 ingestion 的目标数据库；
- live runtime 尚未把 normalized bars、NBBO、option events 和 readiness receipts 写入该 schema。

要求：

- JSONL 保留为原始审计段，但 PostgreSQL 成为连续 point-in-time store；
- append-only、idempotent、partitioned；
- 实时和 backfill 使用相同 normalized contract；
- correction 写新版本，不 UPDATE 历史事实；
- training panel 由 immutable cutoff/materialization receipt 生成，不从活动表随意读取。

验收：

- restart/replay 不重复；
- row count、hash、coverage receipt 一致；
- as-of query 不读取未来 availability；
- research-only license 不会被升级为 public eligible。

### AXIO7-MODEL-05 — P0：自动结算 Massive forward predictions

证据：

- Massive loop调用 `append_prediction`；
- 旧 Moomoo loop调用 `settle_pending`；
- Massive loop没有调用自动 settlement；
- 未结算 prediction 无法形成 forward-shadow promotion evidence。

要求：

- 为 provider-neutral normalized bars 实现 settlement worker；
- 在 horizon 到期后计算 realized return、MFE、MAE、data gap 和 source bar IDs；
- gap/outage 必须标记 invalid，不能当 0 return；
- 支持 restart 后幂等追补；
- 分离 reference-close research outcome 与 executable BBO cost outcome。

验收：

- 5/15/30/60 分钟自动结算；
- duplicate settlement 被数据库拒绝或幂等忽略；
- incomplete window 不生成有效标签；
- dashboard/receipt 展示 eligible、invalid、pending 数量和 forward-shadow 起始日。

### AXIO7-MODEL-06 — P0：完成不可变 promotion 与 calibration 闭环

证据：

- 代码已有 pinned promotion gate；
- 当前没有 `predictor_promotion_latest.json`；
- `MODEL_PROMOTION_REGISTRY_SHA256` 无可批准 artifact；
- 九个 Rust artifacts 校准均 fail closed；
- neural manifests 明确列出 promotion blockers。

要求：

- registry 绑定：
  `data manifest + feature schema + label + model + calibration + costs + code commit`；
- approval 必须包含 reviewer、approval ID、validity window、minimum settled predictions；
- raw analog frequency 与 calibrated probability 使用不同字段和 UI 标签；
- registry 过期、hash 不匹配、settled sample 不足时自动降级为 raw research/abstain。

验收：

- forged/expired/overlapping calibration registry tests；
- public API 在无 registry 时永不返回 calibrated probability；
- rollback 可恢复前一已验证 immutable tuple，而不是使用 mutable latest。

### AXIO7-MODEL-07 — P1：重新做 repeated purged walk-forward 和模型消融

要求：

- 至少多 fold、多 seed、whole-session purge/embargo；
- 每个 symbol/horizon 单独报告；
- 对比 unconditional、clock-time、momentum、reversal、VWAP、Logistic；
- 比较 HMM state count、no-regime、analog-only、GBDT、TCN、MoE；
- 报告 AUC、log loss、Brier、calibration、return IC、MFE/MAE、cost-adjusted expectancy、block-bootstrap lower bound；
- 做 feature ablation、regime/year concentration、parameter perturbation、missingness sensitivity；
- 不用同一个 untouched test反复选架构。

验收：

- 方向模型必须稳定击败透明 baseline；
- 如果只有 VWAP event task有效，拆成独立 task，不用多任务平均掩盖方向失败；
- `REJECTED_NO_DEPLOYABLE_EDGE` 是允许的正式结论。

### AXIO7-OPTIONS-08 — P1：完整 options/Gamma point-in-time 数据合同

要求：

- point-in-time contract definitions；
- consolidated NBBO、sizes、trades；
- contract-level daily OI、`oi_observation_date` 和 `oi_available_at`；
- underlying snapshot、IV/Greeks lineage；
- coverage、staleness、spread、corporate action、expiration/calendar；
- 显式 dealer-sign scenarios，不推断 dealer identity 或 opening/closing intent。

验收：

- 任一 required field/coverage 不足，整份 gamma report `DATA_UNAVAILABLE`；
- aggregate minute trade bar 永不写入 NBBO/trade/OI 表；
- historical replay只使用当时已 available 的 definitions/OI/quotes。

### AXIO7-ARCH-09 — P0：清除 TypeScript 定量计算生产路径

证据：

- `lib/quant/backtest.ts`、`factors.ts`、`ml-ls.ts`、`stat-arb.ts`、`web-forecast.ts`、`technical.ts`、`price-anomalies.ts` 仍执行定量计算；
- `/api/quant/backtest`、`/api/quant/stat-arb`、`/api/quant/ml-ls` 等生产路由仍导入这些模块；
- `lib/forecast-chat.ts` 仍导入 TypeScript web forecast；
- 这违反 Rust-only production inference boundary。

要求：

- 迁移仍需保留的研究计算到 Rust API 或明确 offline research；
- 退役/隔离旧 TypeScript quant routes；
- UI 只渲染 Rust evidence；
- 添加 CI dependency-boundary test，阻止 `app/`、production `lib/` 导入 quant math。

验收：

- production bundle 中没有 TypeScript probability、Greeks、expected return、risk、backtest economics；
- `/api/ask` 和其他市场页面无 Yahoo/synthetic/TS fallback；
- legacy 页面要么删除，要么明确标为离线 demo 且不进入产品答案。

### AXIO7-OPS-10 — P1：实时子进程监督与健康检查

证据：

- entrypoint 后台启动 model/options watcher，但主进程只等待 `quantd`；
- Docker healthcheck 只检查 `/health`；
- model/stream/options 子进程退出后，API container 仍可能显示 healthy。

要求：

- 拆成独立 services 或使用能重启子进程的 supervisor；
- readiness 需要 fresh stream status、fresh inference status、last finalized bar、last prediction、settlement lag；
- 启动失败和运行中死亡要进入 container health/alert；
- readiness receipt 本身要有 TTL，不能永久相信旧文件。

验收：

- kill model process 后健康状态在 bounded time 内失败；
- 自动重启且不重复数据/预测；
- market closed 与 outage 使用不同状态；
- stale status file 不能成为 ready。

### AXIO7-CONTEXT-11 — P1：补齐 point-in-time event/macro context

证据：

- production config 的 context ingestion 当前 disabled；
- earnings、FOMC、CPI、NFP、OPEX 等缺失会显著影响 intraday regimes；
- 缺失不能被编码成“事件不存在”。

要求：

- SEC acceptance-time 和 ALFRED vintage 先进入可审计 archive；
- consensus/surprise 特征只能来自有历史 vintage 和许可的来源；
- `UNKNOWN`、`NOT_APPLICABLE`、`OBSERVED_FALSE` 分开；
- 做 context/no-context ablation 后才允许进入 model。

### AXIO7-NATIVE-12 — P2：决定 C++ 去留

要求：

- 只保留明确性能热点，例如 decoder 或 feature kernel，并添加 Rust parity test；
- 或退役重复的 Logistic/HMM/analog/paper OMS；
- 安装 CMake 后运行 build/ctest；
- 不允许 Rust、C++、TypeScript 三套同名模型各自漂移。

## 7. 推荐执行顺序

第一批必须同时推进：

1. `AXIO7-MODEL-01` multi-target registry runtime；
2. `AXIO7-DATA-02` setup-specific readiness；
3. `AXIO7-DATA-03` licensed realtime equities adapter；
4. `AXIO7-DATA-04` live PostgreSQL archive；
5. `AXIO7-MODEL-05` automatic settlement；
6. `AXIO7-ARCH-09` TypeScript runtime boundary。

第二批在真实流开始后：

1. `AXIO7-OPS-10` supervisor/health；
2. `AXIO7-MODEL-07` repeated walk-forward；
3. `AXIO7-CONTEXT-11` point-in-time context；
4. 开始 60–90 trading-day forward shadow。

第三批：

1. `AXIO7-MODEL-06` reviewed promotion；
2. 只有 options 数据和许可齐全后才做 `AXIO7-OPTIONS-08`；
3. `AXIO7-NATIVE-12` C++ 清理。

## 8. 接收方不要做的事

- 不要把历史行情逐行硬编码到源码；
- 不要重新下载一份 Yahoo CSV 当“修复”；
- 不要先接 LSTM/Transformer 再补数据 lineage；
- 不要用测试集持续挑结构；
- 不要把当前 TCN 的 5m AUC 当成生产 edge；
- 不要把高 VWAP-cross AUC包装成涨跌预测；
- 不要把期权 minute aggregate 当 NBBO；
- 不要把 OCC market total OI 当合约级 OI；
- 不要根据 OI 假定 dealer short gamma；
- 不要为了上线绕过 fail-closed。

## 9. 当前检查收据

在本次审计时：

- `npm run typecheck`：通过；
- `npm run build`：通过，存在与本模型交接无关的现有 lint/Sentry warnings；
- `cargo fmt --check`：通过；
- `cargo clippy --all-targets -- -D warnings`：通过；
- Rust：222 library + 5 CLI + 12 integration tests 通过；
- Python：26 passed、5 optional-dependency skips；
- C++：未检查，当前机器没有 CMake。

测试通过只说明现有合同按代码预期运行，不证明数据 entitlement、模型 edge、forward evidence 或公开使用许可已经成立。

## 10. 完成交付定义

接收方完成工作时必须交付：

- 代码和测试；
- provider entitlement/readiness receipt；
- 一份真实开市日 live capture receipt；
- PostgreSQL coverage/hash receipt；
- per-target model/artifact loading receipt；
- prediction + automatic settlement receipt；
- repeated walk-forward report；
- 60–90 trading-day forward-shadow report；
- promotion 或正式 rejection artifact；
- rollback runbook；
- 没有任何 automatic execution enablement。
