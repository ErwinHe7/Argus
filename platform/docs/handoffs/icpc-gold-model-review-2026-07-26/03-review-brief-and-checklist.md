# 03 — 给审查者的任务说明

## 审查原则

请优先判断系统是否数学正确、因果、可重现、可实时运行。不要先重写 UI，不要复制
历史数据行，不要先加更多模型，也不要把候选模型描述成已上线能力。

## P0：必须先查

### HMM / Baum–Welch

- [ ] log-space forward/backward 与独立实现是否在极端密度下保持一致；
- [ ] `gamma` 和 `xi` 是否归一化且与 transition denominator 一致；
- [ ] 每次 EM 后 likelihood 是否非下降；
- [ ] variance floor 是否会制造假状态；
- [ ] deterministic initialization/restarts 是否覆盖足够的局部最优；
- [ ] state canonicalization 后 artifact hash 与语义是否稳定；
- [ ] 统一 selector 的 fit/validation occupancy gate 与全局评分模式是否正确；
- [ ] 为什么所有 9 个历史 v2 artifact 都在旧最大候选 `K=8`，以及 v3 重训后
  是否出现内部最优；
- [ ] online code 是否完全没有使用 smoother/Viterbi future information。

### Kernel regression

- [ ] train-only median/MAD/covariance/OOD threshold 是否无泄漏；
- [ ] shrinkage covariance inversion 是否数值稳定；
- [ ] identity fallback 是否真的 fail closed，而不是继续发布；
- [ ] same-regime、posterior cosine、same bucket、one-day-one-neighbor 是否全部执行；
- [ ] label `available_at` 是否严格早于 query；
- [ ] adaptive bandwidth 在 distance concentration 时是否稳定；
- [ ] raw probability、ESS、weighted quantile 与 local-linear intercept 是否正确；
- [ ] exact search 的时间/内存复杂度以及 ANN 的安全替代方案。

### Markov-switching SDE / OU

- [ ] regime-weighted drift/variance estimator 是否偏差可接受；
- [ ] posterior 权重依赖是否会夸大有效样本；
- [ ] transition Dirichlet prior 是否合理；
- [ ] 多步矩传播方程是否正确；
- [ ] OU 从 AR(1) 到 `theta/kappa/sigma²` 的换算是否正确；
- [ ] irregular/missing intervals 是否被错误当成固定 `dt`；
- [ ] SDE/OU 是否在任何 production decision path 中意外产生影响；
- [ ] 是否需要 bootstrap/parameter uncertainty，而不是只报告点估计。

### 实时系统

- [ ] 复核已加入的 exact-symbol universe loader 和 failure isolation；
- [ ] 用测试证明缺失某个 artifact 时不会回退到 SPY 或影响其他 symbol；
- [ ] equity/options/setup readiness 解耦及 v1 receipt fallback；
- [ ] feed reconnect、dedupe、out-of-order、gap detection 和 sequence recovery；
- [ ] normalized live record 持续写 PostgreSQL；
- [ ] JSONL 只作为 spool/WAL；
- [ ] pending predictions 到期自动 causal settlement；
- [ ] restart 后 pending ledger 可恢复；
- [ ] model/options 子进程退出会使 supervisor/container 退出；`/health` 仅表示
  控制面存活，`/ready` 对 fresh/authenticated/unblocked supervisor 失败关闭；
- [ ] 任一缺失、过期、无权限或 incomplete 数据都 fail closed。

## P1：模型证据

- [ ] repeated purged walk-forward，而不是单次 split；
- [ ] untouched final OOS；
- [ ] per-symbol、per-horizon、per-regime；
- [ ] no-HMM、no-kernel、no-SDE 和简单 baseline ablation；
- [ ] costs/slippage/latency 明示；
- [ ] Brier、log loss、AUC、IC、coverage、calibration curve；
- [ ] forward-shadow 样本量和稳定性；
- [ ] calibration artifact 与 model/data/schema hash 绑定；
- [ ] neural TCN/MoE 在方向任务无增量时不得 promotion；
- [ ] VWAP-event head 单独验证，不与方向 head 的失败互相掩盖。

## P1：数据

- [ ] 股票实时 feed 有公开产品允许的 entitlement；
- [ ] consolidated/SIP、exchange-specific 和 delayed 数据明确区分；
- [ ] options 使用 point-in-time NBBO/trades/OI；
- [ ] OI 只表示市场总量，不推断 dealer 身份或方向；
- [ ] gamma 默认 unsigned，dealer sign 必须作为显式 scenario；
- [ ] event/macro/earnings 特征有 published_at 和 available_at；
- [ ] 当前硬编码为 `False` 的事件特征被替换或彻底禁用；
- [ ] 禁止 Yahoo/synthetic 静默 fallback。

## P2：工程治理

- [ ] 决定 C++ 研究核心保留或退役；
- [ ] 清理 `.orig`、重复算法与无法重现的 artifact；
- [ ] 把 PyTorch/CUDA 依赖固定进环境清单；
- [ ] TypeScript production route 移除定量计算；
- [ ] artifact registry、promotion registry 和 rollback receipt 自动校验；
- [ ] 给关键数值路径加 property tests、golden tests 和 benchmark。

## 希望收到的输出格式

每个发现请给：

1. 严重度：P0/P1/P2；
2. 类型：bug / causality / numerical / performance / evidence / data / ops；
3. 代码位置；
4. 最小复现；
5. 为什么有影响；
6. 最小修复；
7. 必须新增的测试；
8. 是否阻塞 production promotion。

请优先提交小而可验证的补丁，不要一次性重构整个仓库。
