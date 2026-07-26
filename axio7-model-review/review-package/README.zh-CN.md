# AXIO7 模型与实时推理代码审查包

日期：2026-07-26  
接收对象：由项目所有者自行转发给 ICPC 金牌级工程师/算法工程师  
审查性质：代码、数值方法、因果性、实时系统与模型晋升审查  
系统边界：只做市场研究、回测、解释和监控；自动交易始终关闭

## 一句话架构

AXIO7 的目标不是把历史行情写进代码，而是让历史回放和授权实时行情经过同一份
标准化记录、同一套 Rust 特征逻辑和同一套冻结模型推理路径；Python 只负责离线
训练/验证，TypeScript 只负责 UI、鉴权和 Rust API 代理。

## 请先看清楚的结论

1. 当前核心组合是：
   **对角高斯 HMM + Baum–Welch + causal forward filter + same-regime
   kernel regression + decision-neutral Markov-switching SDE/OU shadow head**。
2. 9 个 universe v2 artifact 都是候选，尚未 promotion；它们的 HMM 都选到当前
   搜索边界 `K=8`，所以最优状态数没有被证明。
3. 2026-07-26 已加入 exact-symbol universe loader：Massive 与 Moomoo live
   worker 现在按 `model_symbol` 读取 registry，不再用单一 SPY artifact 兜底。
   这项应由审查者复核测试与 failure isolation，而不是当成尚未修复的问题。
4. Massive 的实时股票与期权 entitlement 当前不足；期权 point-in-time
   历史也不完整。
5. Massive 实时预测还缺自动 outcome settlement、持续 PostgreSQL 归档、不可变
   calibration/promotion receipt。
6. Python 中存在 TCN 和 regime-gated Mixture-of-Experts，但它们是离线候选，
   没有 Rust production runtime，也不应被宣传为已经上线。
7. 仓库没有实现 Bayesian/PyMC/Stan、Naive Bayes、LSTM/GRU、LightGBM、
   XGBoost 或 CatBoost。Baum–Welch 不是 Bayesian 算法。

## 包内文件

- 仓库根目录 `REVIEWER_START_HERE.zh-CN.md`：如何 clone、定位和直接修改源码。
- 仓库根目录 `MODEL_SOURCE_MAP.zh-CN.md`：本清单每一项到实际代码文件的映射。
- `01-model-algorithm-inventory.md`：模型、数学方法、训练与在线用途。
- `02-technical-stack-and-runtime.md`：Rust/Python/C++/TypeScript、数据与部署栈。
- `03-review-brief-and-checklist.md`：希望审查者真正检查和修复的内容。
- `04-evidence-index.md`：关键代码、artifact、测试与已知阻塞证据。
- `inventory.csv`：可排序的模型清单。
- `../source/`：Rust、Python、C++ 模型实现和测试，不是只有说明文档。
- `../model-artifacts/`：9 个未晋升候选 artifact、registry 和 legacy 对照。

## 希望审查者交付什么

- 对 HMM/EM、kernel、SDE/OU 的数值正确性和因果性结论；
- 对状态数选择、校准、purged walk-forward 和 OOS 证据的结论；
- 对实时流、持久化、重启恢复、多标的模型路由的补丁建议；
- 对性能热点的 benchmark，尤其是 exact analog search；
- 按 P0/P1/P2 排序的最小补丁集与相应测试；
- 明确区分“代码 bug”“证据不足”“数据权限不足”和“模型没有增量”。

请不要通过增加新模型名字来掩盖现有证据缺口，也不要把历史数据行复制进源代码。
